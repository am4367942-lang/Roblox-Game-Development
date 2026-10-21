-- Main server script for Haunted Harvest.
-- Server owns all state. Clients only REQUEST things; every request is validated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local GhostCatalog=require(ReplicatedStorage.Shared.GhostCatalog)
local DataService = require(ServerScriptService.Modules.DataService)
local QuestService = require(ServerScriptService.Modules.QuestService)

----------------------------------------------------------------------
-- Remotes (created by the server only)
----------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then remotes:Destroy() end
remotes = Instance.new("Folder")
remotes.Name = "Remotes"
-- Parent the folder after its complete remote set is created.

local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local StateRE = newRemote("State")               -- server -> client: full state
local NotifyRE = newRemote("Notify")             -- server -> client: toast message
local OpenShopRE = newRemote("OpenShop")         -- server -> client: open shop panel
local DialogueRE = newRemote("Dialogue")         -- server -> client: show NPC dialogue
local RequestStateRE = newRemote("RequestState") -- client -> server
local BuyUpgradeRE = newRemote("BuyUpgrade")     -- client -> server
local NpcActionRE = newRemote("NpcAction")
local HelperFXRE = newRemote("HelperFX")
local GraphicsRE = newRemote("SetGraphics")
local ZoneInfoRE = newRemote("ZoneInfo")             -- server -> client: gate requirements
local UnlockZoneRE = newRemote("UnlockZone")         -- client -> server: pay to open a gate
local ZoneEnterRE = newRemote("ZoneEnter")
local BuyToolRE = newRemote("BuyTool")               -- client -> server: buy a collecting tool
local SoulPullRE = newRemote("SoulPull")
local BuyStorageRE = newRemote("BuyStorage")
local EquipToolRE=newRemote("EquipTool")
local EquipStorageRE=newRemote("EquipStorage")
local CollectIntentRE=newRemote("CollectIntent")
local RefineStateRE=newRemote("RefineState")
newRemote("ProfileAction")
newRemote("ProfileState")
newRemote("PremiumAction")
newRemote("PremiumState")
newRemote("GhostCombatFX")
newRemote("FeatureAction")
newRemote("FeatureState")
newRemote("ExpeditionAction")
newRemote("ExpeditionState")
newRemote("WorldAction")
newRemote("WorldState")
newRemote("AdminAction")
newRemote("AdminState")
newRemote("RoostAction")
local RefineActionRE=newRemote("RefineAction")
remotes.Parent=ReplicatedStorage
local BossStateRE = newRemote("BossState")           -- server -> client: boss health bar         -- client -> server: buy a bigger container             -- server -> client: a soul flies into your jar           -- server -> client: "entering X" banner           -- client -> server: remember the graphics choice             -- server -> client: helper picked up an orb       -- client -> server

----------------------------------------------------------------------
-- Helpers: rate limiting, reach checks, notifications
----------------------------------------------------------------------
local buckets = {}
local function allow(player, key, ratePerSec, burst)
	local now = os.clock()
	local pb = buckets[player]
	if not pb then
		pb = {}
		buckets[player] = pb
	end
	local b = pb[key]
	if not b then
		b = { tokens = burst, last = now }
		pb[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * ratePerSec)
	b.last = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

local function canReach(player, part, maxDistance)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not part or not hum or hum.Health <= 0 then return false end
	return (root.Position - part.Position).Magnitude <= maxDistance
end

local function notify(player, text, kind)
	NotifyRE:FireClient(player, text, kind or "info")
end

local lastNotice = {} -- throttle repeated "jar is full" style messages
local function throttledNotify(player, key, text, kind)
	local now = os.clock()
	lastNotice[player] = lastNotice[player] or {}
	if (lastNotice[player][key] or 0) + 2.5 > now then return end
	lastNotice[player][key] = now
	notify(player, text, kind)
end

----------------------------------------------------------------------
-- State sync
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Zones: requirements, unlocking, and collision gates
----------------------------------------------------------------------
local SoulLedger=require(ServerScriptService.Modules.SoulLedger)
local refiners={}
local heldCollectors={}
local giveTools, updateJarVisual
local PhysicsService = game:GetService("PhysicsService")

local function zoneReqs(data, zoneId)
	local z = Config.Zones[zoneId]
	local r = z and z.requires
	local list, allMet = {}, true
	if not r then return list, true end
	if r.jar then
		local met = data.upgrades.JarSize >= r.jar
		table.insert(list, { text = ("Carry a %s or better  (you have: %s)"):format(Config.jarTier(r.jar).name, Config.jarTier(data.upgrades.JarSize).name), met = met })
		allMet = allMet and met
	end
	if r.quest then
		local q = Config.QuestById[r.quest]
		local met = data.done[r.quest] == true
		table.insert(list, { text = "Complete quest: " .. (q and q.title or r.quest), met = met })
		allMet = allMet and met
	end
	if r.helpers then
		local have = data.upgrades.Helpers or 0
		local met = have >= r.helpers
		table.insert(list, { text = ("Own %d Poltergeist Helpers  (you: %d)"):format(r.helpers, have), met = met })
		allMet = allMet and met
	end
	return list, allMet
end

local function zoneUnlocked(data, zoneId)
	local z = Config.Zones[zoneId]
	if not z or not z.requires then return true end
	return data.unlockedZones[zoneId] == true
end

local function zoneMask(data)
	local mask = 0
	for i, zoneId in ipairs(Config.ZoneOrder) do
		if zoneUnlocked(data, zoneId) then mask += 2 ^ (i - 1) end
	end
	return mask
end

-- one collision group per combination of unlocked gates; barriers only block locked combos
do
	local ok, err = pcall(function()
		for _, zoneId in ipairs(Config.ZoneOrder) do
			if not PhysicsService:IsCollisionGroupRegistered("Barrier_" .. zoneId) then PhysicsService:RegisterCollisionGroup("Barrier_" .. zoneId) end
			PhysicsService:CollisionGroupSetCollidable("Barrier_" .. zoneId, "Default", false)
		end
		for mask = 0, 2 ^ #Config.ZoneOrder - 1 do
			local name = "Players_" .. mask
			if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
			for i, zoneId in ipairs(Config.ZoneOrder) do
				local unlocked = bit32.band(mask, 2 ^ (i - 1)) ~= 0
				PhysicsService:CollisionGroupSetCollidable(name, "Barrier_" .. zoneId, not unlocked)
			end
		end
	end)
	if not ok then warn("[Zones] collision group setup failed: " .. tostring(err)) end
end

local function setupBarrier(part)
	local zoneId = part:GetAttribute("Zone")
	if part:IsA("BasePart") and zoneId then
		part.CollisionGroup = "Barrier_" .. zoneId
		part.CanCollide = true
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then return end
			local data = DataService.get(player)
			if data and not zoneUnlocked(data, zoneId) then
				throttledNotify(player, "gate_" .. zoneId, ("%s is locked. Inspect the gate shrine on the road to see what you need."):format(Config.Zones[zoneId].label), "warn")
			end
		end)
	end
end
for _, b in ipairs(CollectionService:GetTagged("ZoneBarrier")) do setupBarrier(b) end
CollectionService:GetInstanceAddedSignal("ZoneBarrier"):Connect(setupBarrier)

local function applyZoneCollision(player)
	local data = DataService.get(player)
	local character = player.Character
	if not data or not character then return end
	local group = "Players_" .. zoneMask(data)
	player:SetAttribute("CollisionGroupName", group)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
end

-- zones whose requirements have no payment open automatically the moment you qualify
local function refreshZones(player, data)
	local changed = false
	for _, zoneId in ipairs(Config.ZoneOrder) do
		local z = Config.Zones[zoneId]
		if not zoneUnlocked(data, zoneId) and not z.requires.pay then
			local _, allMet = zoneReqs(data, zoneId)
			if allMet then
				data.unlockedZones[zoneId] = true
				changed = true
				notify(player, ("%s unlocked!"):format(z.label), "good")
			end
		end
	end
	if changed then applyZoneCollision(player) end
end

local function zoneStates(data)
	local out = {}
	for _, zoneId in ipairs(Config.ZoneOrder) do
		table.insert(out, { id = zoneId, label = Config.Zones[zoneId].label, unlocked = zoneUnlocked(data, zoneId) })
	end
	return out
end

local function pushState(player)
	local data = DataService.get(player)
	if not data then return end

	-- leaderstats mirror (display only; the real values live in `data`)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Souls.Value = data.souls
		ls.Essence.Value = data.essence
		local nDone = 0
		for _ in pairs(data.done) do nDone += 1 end
		ls.Quests.Value = nDone
	end

	refreshZones(player, data)
	QuestService.refresh(player, data)
	if updateJarVisual then updateJarVisual(player, data) end
	StateRE:FireClient(player, {
		questLog = QuestService.log(data),
		zones = zoneStates(data),
		tools = data.tools,
		graphics = data.graphics,
		helpers = data.upgrades.Helpers or 0,
		souls = data.souls,
        soulTypes=SoulLedger.view(data),
		essence = data.essence,
		capacity = Config.capacityFor(data),
		upgrades = data.upgrades,
		quest = QuestService.view(data,player),
		equipment=data.equipment,ownedStorage=data.ownedStorage,storageName=Config.storageFor(data) and Config.storageFor(data).name or "NO STORAGE",
		settings=data.settings,refining=refiners[player] and {active=true,rate=GhostCatalog.refineRate(data),converted=refiners[player].converted} or {active=false},
		stats = data.stats,
	})
end

local collectionSignal=Instance.new("BindableEvent")
collectionSignal.Name="HarvestCollected";collectionSignal.Parent=game:GetService("ServerStorage")
local refreshSignal = Instance.new("BindableEvent")
refreshSignal.Name = "HauntedRefresh"
refreshSignal.Parent = game:GetService("ServerStorage")
refreshSignal.Event:Connect(function(player)
	if player and player.Parent == Players then pushState(player) end
end)

local function grantEssence(player, data, amount)
	data.essence += amount
	data.stats.totalEssence += amount
end

QuestService.init({ notify = notify, grantEssence = grantEssence })

local function applyWalkSpeed(player)
	local data = DataService.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Config.walkSpeed(data.upgrades.SpectralBoots)
	end
end

DataService.onLoaded(function(player, data)
	while not giveTools or not updateJarVisual do task.wait() end
	if player.Parent ~= Players then return end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Souls", "Essence", "Quests" }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player

	local function hookCharacter(character)
		character.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then d.CollisionGroup = player:GetAttribute("CollisionGroupName") or "Default" end
		end)
	end
	player.CharacterAdded:Connect(function(character)
		hookCharacter(character)
		task.wait()
		applyWalkSpeed(player)
		applyZoneCollision(player)
		giveTools(player)
		local d = DataService.get(player)
		if d then updateJarVisual(player, d) end
	end)
	if player.Character then hookCharacter(player.Character) end
	applyWalkSpeed(player)
	applyZoneCollision(player)
	giveTools(player)
	pushState(player)
	notify(player, "Equip your Grave Vacuum (press 1), aim at a glowing grave and click to pull its souls out!", "info")
end)

RequestStateRE.OnServerEvent:Connect(function(player)
	if not allow(player, "RequestState", 1, 3) then return end
	pushState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
	lastNotice[player] = nil
end)

----------------------------------------------------------------------
-- Poltergeist helpers: each owned helper drains a nearby grave every few seconds
task.spawn(function()
	local Reserves = require(ServerScriptService.Modules.GraveReserves)
	while true do
		task.wait(Config.HelperInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = DataService.get(player)
			local helperCount = data and (data.upgrades.Helpers or 0) or 0
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if helperCount > 0 and root and humanoid and humanoid.Health>0 and not player:GetAttribute("Refining") then
				local capacity = Config.capacityFor(data)
				local candidates = {}
				for _, spot in ipairs(CollectionService:GetTagged("DigSpot")) do
					if spot:IsA("BasePart") and spot:IsDescendantOf(workspace) then
						local d = spot.Position - root.Position
						if math.abs(d.Y) <= 12 and d.Magnitude <= Config.HelperRadius
							and zoneUnlocked(data, spot:GetAttribute("Zone") or "Graveyard") and Reserves.available(spot) >= 1 then
							table.insert(candidates, { spot = spot, dist = d.Magnitude })
						end
					end
				end
				table.sort(candidates, function(a, b) return a.dist < b.dist end)
				local gained = 0
				for i = 1, math.min(helperCount, #candidates) do
					if data.souls >= capacity then break end
					local spot = candidates[i].spot
					local amount = Reserves.take(spot, math.min(2 + data.upgrades.GreedyHands, capacity - data.souls))
					if amount > 0 then
						SoulLedger.add(data,amount,spot:GetAttribute("Zone"),spot:GetAttribute("Mutation"))
						data.stats.totalSouls += amount
						QuestService.onCollect(player, data, amount, spot:GetAttribute("Zone") or "Graveyard")
						HelperFXRE:FireClient(player, spot.Position + Vector3.new(0, 1.5, 0))
						gained += amount
					end
				end
				if gained > 0 then pushState(player) end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Convert pad (any part tagged "ConvertPad"): Souls -> Essence
----------------------------------------------------------------------
local function beginRefining(player,pad)
 if not player or not pad or not pad:IsA("BasePart") or not CollectionService:HasTag(pad,"ConvertPad") or not canReach(player,pad,16) then return end
 local roost=pad:FindFirstAncestorWhichIsA("Model")
 if not roost or not roost:IsDescendantOf(workspace.SpiritRoosts) or roost:GetAttribute("OwnerUserId")~=player.UserId then return end
 local data=DataService.get(player);if not data or DataService.inventoryBusy(player) then return end
 if refiners[player] then refiners[player]=nil;player:SetAttribute("Refining",false);RefineStateRE:FireClient(player,{active=false});pushState(player);return end
 if data.souls<=0 then throttledNotify(player,"empty","Your jar is empty. Collect from a grave first.","info");return end
 refiners[player]={pad=pad,credit=0,converted=0,lastState=0}
 heldCollectors[player]=nil;player:SetAttribute("Refining",true)
 notify(player,"Refining started. Stay nearby. Press Convert again to pause.","info")
end
local function setupPad(pad)
 if not pad:IsA("BasePart") then return end
 local prompt=pad:FindFirstChild("ConvertPrompt") or Instance.new("ProximityPrompt")
 prompt.Name="ConvertPrompt";prompt.ActionText="Convert / Pause";prompt.ObjectText="Soul Refinery";prompt.MaxActivationDistance=14;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt.Parent=pad
 prompt.Triggered:Connect(function(player) beginRefining(player,pad) end)
end
local refineRequestAt={}
RefineActionRE.OnServerEvent:Connect(function(player)
 if (refineRequestAt[player] or 0)+.4>os.clock() then return end;refineRequestAt[player]=os.clock()
 local nearest,dist=nil,16
 for _,pad in ipairs(CollectionService:GetTagged("ConvertPad")) do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if root and pad:IsA("BasePart") then local n=(root.Position-pad.Position).Magnitude
   local roost=pad:FindFirstAncestorWhichIsA("Model")
   if n<dist and (roost and roost:IsDescendantOf(workspace.SpiritRoosts) and roost:GetAttribute("OwnerUserId")==player.UserId) then nearest=pad;dist=n end
  end
 end
 beginRefining(player,nearest)
end)
Players.PlayerRemoving:Connect(function(p) refineRequestAt[p]=nil end)
for _,pad in ipairs(CollectionService:GetTagged("ConvertPad")) do setupPad(pad) end
CollectionService:GetInstanceAddedSignal("ConvertPad"):Connect(setupPad)
task.spawn(function()
	local last=os.clock()
	while true do
		task.wait(.25);local now=os.clock();local dt=math.min(now-last,1);last=now
		for player,session in pairs(refiners) do
			local data=DataService.get(player)
			if not data or not session.pad.Parent or not session.pad:FindFirstAncestorWhichIsA("Model") or session.pad:FindFirstAncestorWhichIsA("Model"):GetAttribute("OwnerUserId")~=player.UserId or not canReach(player,session.pad,18) or data.souls<=0 or DataService.inventoryBusy(player) then
				refiners[player]=nil
				if player.Parent then player:SetAttribute("Refining",false);RefineStateRE:FireClient(player,{active=false});pushState(player) end
			else
				local rate=GhostCatalog.refineRate(data);session.credit+=rate*dt
				local count=math.min(math.floor(session.credit),data.souls)
				if count>0 then
					session.credit-=count;session.converted+=count
                    local soulValue,paidCount=SoulLedger.consume(data,count)
 local multiplier=Config.essencePerSoul(data.upgrades.Refinement)*Config.progressionMultiplier(data)
 data.refineRemainder=(data.refineRemainder or 0)+soulValue*multiplier
 data.paidRefineRemainder=(data.paidRefineRemainder or 0)+paidCount*multiplier
 local earned=math.floor(data.refineRemainder+1e-6);data.refineRemainder-=earned
 local paid=math.floor(data.paidRefineRemainder+1e-6);data.paidRefineRemainder-=paid
 if earned+paid>0 then grantEssence(player,data,earned+paid);data.paidEssence=(data.paidEssence or 0)+paid;if earned>0 then QuestService.onEarn(player,data,earned) end end
				end
				RefineStateRE:FireClient(player,{active=true,souls=data.souls,essence=data.essence,rate=rate,converted=session.converted})
				if now-session.lastState>=1 then session.lastState=now;pushState(player) end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Upgrade shop
----------------------------------------------------------------------
local shopFolder = workspace:FindFirstChild("Shop")
local shopPart = shopFolder and shopFolder:FindFirstChild("JarUpgrade")

local function nearShop(player)
	if shopPart and canReach(player, shopPart, Config.ShopReach) then return true end
	for _, counter in ipairs(CollectionService:GetTagged("ShopCounter")) do
		if canReach(player, counter, Config.ShopReach) then return true end
	end
	return false
end

local function setupCounter(part)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Browse Wares"
	prompt.ObjectText = Config.ShopName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if not allow(player, "OpenShop", 2, 3) then return end
		if not DataService.get(player) then return end
		OpenShopRE:FireClient(player)
	end)
end
for _, counter in ipairs(CollectionService:GetTagged("ShopCounter")) do setupCounter(counter) end
CollectionService:GetInstanceAddedSignal("ShopCounter"):Connect(setupCounter)

BuyUpgradeRE.OnServerEvent:Connect(function(player, upgradeId)
	if not allow(player, "BuyUpgrade", 4, 6) then return end

	-- 1. type, 2. existence, 3. permission/plausibility
	if typeof(upgradeId) ~= "string" then return end
	local upgrade = Config.UpgradeById[upgradeId]
	if not upgrade then return end
	if not nearShop(player) then return end

	local data = DataService.get(player)
	if not data then return end

	local level = data.upgrades[upgradeId]
	local cost = Config.upgradeCost(upgradeId, level)
	if not cost then
		notify(player, upgrade.name .. " is already maxed out!", "info")
		return
	end
	if data.essence < cost then
		notify(player, ("Not enough Essence (need %d)"):format(cost), "warn")
		return
	end

	Config.spendEssence(data,cost)
	data.upgrades[upgradeId] = level + 1
	QuestService.onBuy(player, data)
	if upgradeId == "SpectralBoots" then
		applyWalkSpeed(player)
	end
	pushState(player)
	notify(player, ("%s upgraded to level %d!"):format(upgrade.name, level + 1), "good")
end)

----------------------------------------------------------------------
-- Quest NPCs (models in Workspace.NPCs tagged "QuestNPC" with an NpcId attribute)
----------------------------------------------------------------------
local function npcRoot(model)
	return model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
end

local function findNpc(npcId)
	for _, model in ipairs(CollectionService:GetTagged("QuestNPC")) do
		if model:GetAttribute("NpcId") == npcId then
			return model
		end
	end
	return nil
end

local function setupNpc(model)
	local id = model:GetAttribute("NpcId")
	if typeof(id) ~= "string" or not Config.Npcs[id] then return end
	local root = npcRoot(model)
	if not root then return end

	local prompt = root:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = Config.Npcs[id].name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player)
		if not allow(player, "Talk", 2, 3) or not canReach(player, root, 14) then return end
		local data = DataService.get(player)
		if not data then return end
		local name, text, action = QuestService.dialogue(data, id)
		DialogueRE:FireClient(player, id, name, text, action)
	end)
end

for _, model in ipairs(CollectionService:GetTagged("QuestNPC")) do
	setupNpc(model)
end
CollectionService:GetInstanceAddedSignal("QuestNPC"):Connect(setupNpc)

NpcActionRE.OnServerEvent:Connect(function(player, npcId)
	if not allow(player, "NpcAction", 2, 3) then return end
	if typeof(npcId) ~= "string" or not Config.Npcs[npcId] then return end

	local model = findNpc(npcId)
	if not model or not canReach(player, npcRoot(model), Config.MaxReach) then return end

	local data = DataService.get(player)
	if not data then return end

	if QuestService.action(player, data, npcId) then
		pushState(player)
		local name, text, action = QuestService.dialogue(data, npcId)
		DialogueRE:FireClient(player, npcId, name, text, action)
	end
end)

----------------------------------------------------------------------
-- Ghost hunter hook: the Hunters script asks us to steal souls from a player
----------------------------------------------------------------------
local ServerStorage = game:GetService("ServerStorage")
local stealFn = Instance.new("BindableFunction")
stealFn.Name = "StealSouls"
stealFn.Parent = ServerStorage
stealFn.OnInvoke = function(player, fraction)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return 0 end
	local data = DataService.get(player)
	if not data or data.souls <= 0 then return 0 end
	local lost = math.max(1, math.floor(data.souls * math.clamp(tonumber(fraction) or 0.25, 0, 0.5)))
	lost=math.min(lost,math.max(0,data.souls-(data.carriedPaidSouls or 0)))
 SoulLedger.consume(data,lost,true)
	pushState(player)
	notify(player, ("A ghost hunter stole %d souls!"):format(lost), "warn")
	return lost
end

----------------------------------------------------------------------
-- Daily gift chest (parts tagged "DailyChest")
----------------------------------------------------------------------
local function setupChest(chest)
	local prompt = chest:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim Daily Gift"
	prompt.ObjectText = "Spirit Chest"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest

	prompt.Triggered:Connect(function(player)
		if not allow(player, "Daily", 1, 2) or not canReach(player, chest, 16) then return end
		local data = DataService.get(player)
		if not data then return end
		local now = os.time()
		local daily = data.daily
		local since = now - daily.last
		if since < 20 * 3600 then
			local left = 20 * 3600 - since
			notify(player, ("Come back in %dh %dm for your next gift"):format(left // 3600, (left % 3600) // 60), "info")
			return
		end
		if daily.last > 0 and since <= 48 * 3600 then
			daily.streak = math.min(daily.streak + 1, 30)
		else
			daily.streak = 1
		end
		daily.last = now
		local reward = math.floor((60 + 40 * math.min(daily.streak, 14)) * (1 + data.upgrades.JarSize * 0.25))
		grantEssence(player, data, reward)
		pushState(player)
		notify(player, ("Daily gift: +%d Essence  (day %d streak!)"):format(reward, daily.streak), "good")
	end)
end
for _, chest in ipairs(CollectionService:GetTagged("DailyChest")) do
	setupChest(chest)
end
CollectionService:GetInstanceAddedSignal("DailyChest"):Connect(setupChest)

GraphicsRE.OnServerEvent:Connect(function(player, mode)
	if not allow(player, "Graphics", 1, 3) then return end
	if mode ~= "low" and mode ~= "high" then return end
	local data = DataService.get(player)
	if data then data.graphics = mode end
end)

----------------------------------------------------------------------
-- Gate shrines (parts tagged "ZoneShrine"), paying to unlock, and area banners
----------------------------------------------------------------------
local shrineByZone = {}

local function zoneInfo(data, zoneId)
	local z = Config.Zones[zoneId]
	local reqs, allMet = zoneReqs(data, zoneId)
	local unlocked = zoneUnlocked(data, zoneId)
	local info = { id = zoneId, label = z.label, unlocked = unlocked, reqs = reqs, pay = z.requires.pay, canUnlock = false }
	if z.requires.pay then
		table.insert(reqs, { text = ("Pay %d Essence at this gate  (you have: %d)"):format(z.requires.pay, data.essence), met = unlocked })
		info.canUnlock = (not unlocked) and allMet and data.essence >= z.requires.pay
	end
	return info
end

local function setupShrine(part)
	local zoneId = part:GetAttribute("Zone")
	if typeof(zoneId) ~= "string" or not Config.Zones[zoneId] then return end
	shrineByZone[zoneId] = part
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Inspect Gate"
	prompt.ObjectText = Config.Zones[zoneId].label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if not allow(player, "ZoneInfo", 2, 3) then return end
		local data = DataService.get(player)
		if data then ZoneInfoRE:FireClient(player, zoneInfo(data, zoneId)) end
	end)
end
for _, s in ipairs(CollectionService:GetTagged("ZoneShrine")) do setupShrine(s) end
CollectionService:GetInstanceAddedSignal("ZoneShrine"):Connect(setupShrine)

UnlockZoneRE.OnServerEvent:Connect(function(player, zoneId)
	if not allow(player, "UnlockZone", 2, 3) then return end
	if typeof(zoneId) ~= "string" then return end
	local z = Config.Zones[zoneId]
	if not z or not z.requires or not z.requires.pay then return end
	local shrine = shrineByZone[zoneId]
	if not shrine or not canReach(player, shrine, 40) then return end
	local data = DataService.get(player)
	if not data then return end
	local info = zoneInfo(data, zoneId)
	if not info.canUnlock then return end

	Config.spendEssence(data,z.requires.pay)
	data.unlockedZones[zoneId] = true
	applyZoneCollision(player)
	pushState(player)
	notify(player, ("%s unlocked!"):format(z.label), "good")
	ZoneInfoRE:FireClient(player, zoneInfo(data, zoneId))
end)

local areas = {
	{ "Haunted Forest", -188, -74, -44, 72 }, { "Whispering Swamp", -188, -74, -190, -74 }, { "Sunken Crypt", -52, 52, -220, -122 },
	{ "Pumpkin Patch", 76, 164, -28, 54 }, { "Graveyard", -78, 78, -78, -12 }, { "Village", -44, 48, 16, 76 },
}
local function areaAt(p)
	if p.Y > 65 and p.Y < 105 and p.X > -75 and p.X < 75 and p.Z < -630 and p.Z > -970 then return "Hollowlight Catacombs" end
	if p.X > -165 and p.X < 165 and p.Z < -725 and p.Z > -955 and p.Y > 150 then return "Crownrest Summit" end
	if p.X > -460 and p.X < -210 and p.Z < -400 and p.Z > -620 then return "Briarwatch Heights" end
	if p.X > 210 and p.X < 460 and p.Z < -400 and p.Z > -620 then return "Starfall Necropolis" end
	if p.X > -160 and p.X < 160 and p.Z < -350 and p.Z > -570 then return "Moonveil Memorial" end
	for _, a in ipairs(areas) do
		if p.X > a[2] and p.X < a[3] and p.Z > a[4] and p.Z < a[5] then return a[1] end
	end
	if (p.X - 110) ^ 2 + (p.Z - 125) ^ 2 < 50 ^ 2 then return "Spirit Lake" end
	return "The Wilds"
end
local lastArea = {}
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local area = areaAt(root.Position)
				if lastArea[player] ~= area then
					lastArea[player] = area
					ZoneEnterRE:FireClient(player, area)
				end
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) lastArea[player] = nil end)

----------------------------------------------------------------------
-- Collecting tools, the visible Soul Jar, and buying tools
----------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local lastSwing = {}
Players.PlayerRemoving:Connect(function(player) lastSwing[player] = nil end)

local function swingEffects(character, root, def)
	local ring = Instance.new("Part")
	ring.Name = "SwingRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(table.unpack(def.color))
	ring.Transparency = 0.45
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(0.2, def.range * 2, def.range * 2), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.6)

	local hum = character:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://522635514"
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		anim:Destroy()
		if ok and track then track:Play(); task.delay(3, function() track:Destroy() end) end
	end
end

local GraveReserves = require(ServerScriptService.Modules.GraveReserves)
GraveReserves.start()

local function dirtBurst(position, rare)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1; p.Size = Vector3.new(1, 1, 1); p.CFrame = CFrame.new(position)
	p.Parent = workspace
	local dirt = Instance.new("ParticleEmitter")
	dirt.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dirt.Color = ColorSequence.new(Color3.fromRGB(96, 70, 52))
	dirt.Size = NumberSequence.new(1.3, 0.2)
	dirt.Lifetime = NumberRange.new(0.5, 0.9)
	dirt.Speed = NumberRange.new(8, 14)
	dirt.SpreadAngle = Vector2.new(40, 40)
	dirt.Acceleration = Vector3.new(0, -30, 0)
	dirt.EmissionDirection = Enum.NormalId.Top
	dirt.Rate = 0
	dirt.Parent = p
	dirt:Emit(26)
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(rare and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(190, 150, 255))
	glow.Size = NumberSequence.new(rare and 1.4 or 0.8, 0)
	glow.Lifetime = NumberRange.new(0.8, 1.4)
	glow.Speed = NumberRange.new(4, 9)
	glow.SpreadAngle = Vector2.new(60, 60)
	glow.EmissionDirection = Enum.NormalId.Top
	glow.LightEmission = 1
	glow.Rate = 0
	glow.Parent = p
	glow:Emit(rare and 45 or 14)
	Debris:AddItem(p, 2.5)
end

local function digWith(player, data, character, root, def, silent, limit)
	local spots = {}
	for _, spot in ipairs(CollectionService:GetTagged("DigSpot")) do
		if spot:IsA("BasePart") and spot:IsDescendantOf(workspace) then
			local delta = spot.Position - root.Position
			local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
			-- Vertical limit prevents harvesting a cemetery through a mountain.
			if math.abs(delta.Y) <= 9 and flat <= def.range + math.min(4, math.max(spot.Size.X, spot.Size.Z) / 2) then
				table.insert(spots, {spot=spot, dist=delta.Magnitude})
			end
		end
	end
	table.sort(spots, function(a,b) return a.dist < b.dist end)
	if #spots == 0 then
		if not silent then throttledNotify(player, "dig", "Stand beside a glowing grave and click to extract its souls.", "info") end
		return 0
	end
	local dug, depleted = 0, false
	for _,entry in ipairs(spots) do
		if dug >= (limit or def.targets) then break end
		local spot=entry.spot
		local zone=spot:GetAttribute("Zone") or "Graveyard"
		if not zoneUnlocked(data,zone) then
			if not silent then throttledNotify(player,"zone","Visit this region's gate shrine to unlock it first.","warn") end
		else
			local capacity=Config.capacityFor(data)
			if data.souls >= capacity then
				throttledNotify(player,"full","Your jar is full! Return to your own Spirit Roost and press Convert.","warn")
				break
			end
			local requested=math.max(1,math.floor(((spot:GetAttribute("Reward") or 5)+data.upgrades.GreedyHands)*def.power+.5))
			local rare=math.random()<.06
			if rare then requested*=3 end
			local amount=GraveReserves.take(spot, math.min(requested,capacity-data.souls))
			if amount > 0 then
				SoulLedger.add(data,amount,spot:GetAttribute("Zone"),spot:GetAttribute("Mutation"))
				data.stats.totalSouls+=amount
				QuestService.onCollect(player,data,amount,zone)
				dirtBurst(spot.Position,rare)
				SoulPullRE:FireClient(player,spot.Position+Vector3.new(0,1,0),rare and Color3.fromRGB(255,215,90) or Color3.fromRGB(140,255,220))
				if rare then notify(player,("RARE SOUL! +%d souls extracted"):format(amount),"good") end
				dug+=1
			else depleted=true end
		end
	end
	if dug > 0 then
		if not silent then
			local hum=character:FindFirstChildOfClass("Humanoid")
			local animator=hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://522638767"
				local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
				anim:Destroy()
				if ok and track then track:Play();task.delay(3,function() track:Destroy() end) end
			end
		end
		pushState(player)
	elseif depleted then
		throttledNotify(player,"dug","These graves are recharging. Try another row, or wait for the soul bar to refill.","info")
	end
	return dug
end

-- Grave vacuums: aim at graves in a cone and pull their souls out with a visible beam
local function vacuumBeam(character, spot, color)
	local tool = character:FindFirstChildOfClass("Tool")
	local from = tool and (tool:FindFirstChild("Nozzle") or tool:FindFirstChild("Handle"))
	if not from then return end
	local a0 = Instance.new("Attachment"); a0.Parent = from
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 0.5, 0); a1.Parent = spot
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0; beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	beam.Width0 = 0.5; beam.Width1 = 1.6; beam.LightEmission = 1; beam.FaceCamera = true; beam.CurveSize0 = 1.5; beam.CurveSize1 = -1.5
	beam.Segments = 12; beam.TextureSpeed = -3
	beam.Parent = from
	Debris:AddItem(beam, 0.45); Debris:AddItem(a0, 0.45); Debris:AddItem(a1, 0.45)
end

local function vacuumWith(player, data, character, root, def)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local cosHalf = math.cos(math.rad(def.arc / 2))
	local spots = {}
	for _, spot in ipairs(CollectionService:GetTagged("DigSpot")) do
		if spot:IsA("BasePart") and spot:IsDescendantOf(workspace) then
			local delta = spot.Position - root.Position
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if math.abs(delta.Y) <= 10 and flat.Magnitude <= def.range + 2 then
				if def.arc >= 360 or flat.Magnitude < 3 or flat.Unit:Dot(look) >= cosHalf then
					table.insert(spots, { spot = spot, dist = flat.Magnitude })
				end
			end
		end
	end
	table.sort(spots, function(a, b) return a.dist < b.dist end)
	if #spots == 0 then
		throttledNotify(player, "vac", "Aim at a glowing grave nearby and click to pull its souls out.", "info")
		return 0
	end
	local color = Color3.fromRGB(table.unpack(def.color or { 110, 255, 230 }))
	local capacity = Config.capacityFor(data)
	local drained, depleted = 0, false
	for _, entry in ipairs(spots) do
		if drained >= def.targets then break end
		local spot = entry.spot
		local zone = spot:GetAttribute("Zone") or "Graveyard"
		if not zoneUnlocked(data, zone) then
			throttledNotify(player, "zone", "Visit this region's gate shrine to unlock it first.", "warn")
		elseif data.souls >= capacity then
			throttledNotify(player, "full", "Your jar is full! Return to your own Spirit Roost and press Convert.", "warn")
			break
		else
			local requested = math.max(1, math.floor(((spot:GetAttribute("Reward") or 5) * 0.6 + data.upgrades.GreedyHands) * def.power + 0.5))
			local amount = GraveReserves.take(spot, math.min(requested, capacity - data.souls))
			if amount > 0 then
				SoulLedger.add(data,amount,spot:GetAttribute("Zone"),spot:GetAttribute("Mutation"))
				data.stats.totalSouls += amount
				QuestService.onCollect(player, data, amount, zone)
				vacuumBeam(character, spot, color)
				SoulPullRE:FireClient(player, spot.Position + Vector3.new(0, 1, 0), color)
				drained += 1
			else
				depleted = true
			end
		end
	end
	if drained > 0 then
		pushState(player)
	elseif depleted then
		throttledNotify(player, "dug", "These graves are recharging. Try another row, or wait for the soul bar to refill.", "info")
	end
	return drained
end

local function useTool(player, tool)
	local id = tool:GetAttribute("ToolId")
	local def = id and Config.ToolById[id]
	if not def then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then return end
	local data = DataService.get(player)
	if not data or data.tools[id] ~= true or not data.equipment or data.equipment.tool~=id or player:GetAttribute("Refining") then return end
	if Config.capacityFor(data)<=0 then throttledNotify(player,"storage","Equip a storage jar before collecting souls.","warn");return end

	local now = os.clock()
	if now < (lastSwing[player] or 0) then return end
	lastSwing[player] = now + def.cooldown

	-- every tool also hurts a boss in reach (the Bosses script owns boss health)
	local bossHit = ServerStorage:FindFirstChild("BossHit")
	if bossHit then
		local damage = math.floor(Config.BossToolDamage * Config.combatMultiplier(data) * def.power * (1 + 0.1 * (data.upgrades.GreedyHands + data.upgrades.Refinement)))
		local aim = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		pcall(function() bossHit:Invoke(player, root.Position, aim, def.range + 4, def.arc, damage) end)
	end
	if def.kind == "dig" then
		digWith(player, data, character, root, def)
		return
	end
	vacuumWith(player, data, character, root, def)
end

giveTools = function(player,equipNow)
	local data=DataService.get(player);local backpack=player:FindFirstChildOfClass("Backpack")
	local template=ServerStorage:FindFirstChild("SoulTools")
	if not data or not backpack or not template then return end
	local selected=data.equipment and data.equipment.tool
	for _,container in ipairs({backpack,player.Character}) do for _,tool in ipairs(container:GetChildren()) do if tool:IsA("Tool") and tool:GetAttribute("ToolId") and tool:GetAttribute("ToolId")~=selected then tool:Destroy() end end end
	local def=selected and Config.ToolById[selected]
	if not def or not data.tools[selected] then return end
	local tool=backpack:FindFirstChild(def.name) or (player.Character and player.Character:FindFirstChild(def.name))
	if not tool and template:FindFirstChild(def.name) then
		tool=template[def.name]:Clone();tool.Activated:Connect(function() useTool(player,tool) end);tool.Parent=backpack
	end
	if equipNow and tool and player.Character then local hum=player.Character:FindFirstChildOfClass("Humanoid");if hum and hum.Health>0 then hum:EquipTool(tool) end end
end
EquipToolRE.OnServerEvent:Connect(function(player,id)
	if not allow(player,"EquipTool",3,5) or (typeof(id)~="string" and id~=false) then return end
	local data=DataService.get(player);if not data or (id and not data.tools[id]) then return end
	data.equipment=data.equipment or {};data.equipment.tool=id;heldCollectors[player]=nil
	giveTools(player,true);pushState(player)
end)
EquipStorageRE.OnServerEvent:Connect(function(player,id)
	if not allow(player,"EquipStorage",3,5) or (typeof(id)~="string" and id~=false) then return end
	local data=DataService.get(player);if not data or (id and not data.ownedStorage[id]) then return end
	local tier=id and Config.StorageById[id]
	if data.souls>(tier and tier.capacity*((data.passes and data.passes.DoubleStorage) and 2 or 1) or 0) then notify(player,"Refine your souls before switching to smaller storage or unequipping it.","warn");return end
	data.equipment.storage=id;pushState(player)
end)
CollectIntentRE.OnServerEvent:Connect(function(player,id,holding)
	if holding==false then heldCollectors[player]=nil;return end
	if holding~=true or typeof(id)~="string" or not allow(player,"CollectIntent",3,5) then return end
	local data=DataService.get(player)
	if not data or data.equipment.tool~=id or not data.tools[id] or player:GetAttribute("Refining") then return end
	heldCollectors[player]={id=id,expires=os.clock()+3}
end)
task.spawn(function()
	while true do task.wait(.05)
		for player,held in pairs(heldCollectors) do
			local character=player.Character;local tool=character and character:FindFirstChildOfClass("Tool")
			if os.clock()>held.expires or not tool or tool:GetAttribute("ToolId")~=held.id then heldCollectors[player]=nil
			else useTool(player,tool) end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) refiners[player]=nil;heldCollectors[player]=nil end)

BuyToolRE.OnServerEvent:Connect(function(player, toolId)
	if not allow(player, "BuyTool", 3, 5) then return end
	if typeof(toolId) ~= "string" then return end
	local def = Config.ToolById[toolId]
	if not def then return end
	if not nearShop(player) then return end
	local data = DataService.get(player)
	if not data then return end
	if data.tools[toolId] then
		notify(player, def.name .. " is already yours. Check your hotbar!", "info")
		return
	end
	if def.requiresTool and not data.tools[def.requiresTool] then
		notify(player,"First buy "..Config.ToolById[def.requiresTool].name..".","warn");return
	end
	if data.essence < def.price then
		notify(player, ("Not enough Essence (need %d)"):format(def.price), "warn")
		return
	end
	Config.spendEssence(data,def.price)
	data.tools[toolId] = true
	data.equipment.tool=toolId
	QuestService.onBuy(player, data)
	giveTools(player,true)
	pushState(player)
	notify(player, ("%s bought and equipped!"):format(def.name), "good")
end)

BuyStorageRE.OnServerEvent:Connect(function(player, storageId)
	if not allow(player, "BuyStorage", 3, 5) then return end
	if typeof(storageId) ~= "string" then return end
	local item = Config.StorageById[storageId]
	if not item then return end
	if not nearShop(player) then return end
	local data = DataService.get(player)
	if not data then return end
	if data.ownedStorage[storageId] then
		notify(player, "You already own this storage. Use Equip to carry it.", "info")
		return
	end
	if item.requiresStorage and not data.ownedStorage[item.requiresStorage] then
		notify(player,"First buy "..Config.StorageById[item.requiresStorage].name..".","warn");return
	end
	if data.essence < item.price then
		notify(player, ("Not enough Essence (need %d)"):format(item.price), "warn")
		return
	end
	Config.spendEssence(data,item.price)
	data.upgrades.JarSize = math.max(data.upgrades.JarSize,item.level)
	data.ownedStorage[storageId]=true;data.equipment.storage=storageId
	QuestService.onBuy(player, data)
	pushState(player)
	notify(player, ("You now carry a %s (holds %d souls)!"):format(item.name, item.capacity), "good")
end)

-- the Soul Jar you wear on your back; it fills up as you collect
----------------------------------------------------------------------
-- The detailed Soul Jar you wear on your back (one design per storage tier)
----------------------------------------------------------------------
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local UPR = CFrame.Angles(0, 0, math.rad(90))
local JAR_BASE = CFrame.new(0, -0.15, 1.25)

local function jarPart(model, torso, name, size, offset, color, mat, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0; p.Shape = shape or Enum.PartType.Block
	if p.Shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
	end
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	local w = Instance.new("Weld")
	w.Part0 = torso; w.Part1 = p; w.C0 = offset
	w.Parent = p
	return p
end

local function harness(model, torso, strap, metal)
	for _, side in ipairs({ -1, 1 }) do
		jarPart(model, torso, "StrapFront", Vector3.new(0.28, 1.9, 0.1), CFrame.new(side * 0.52, 0.02, -0.53) * CFrame.Angles(0, 0, math.rad(side * 7)), strap, Enum.Material.Fabric)
		jarPart(model, torso, "StrapShoulder", Vector3.new(0.3, 0.12, 1.15), CFrame.new(side * 0.6, 0.86, 0), strap, Enum.Material.Fabric)
		jarPart(model, torso, "StrapBack", Vector3.new(0.28, 1.5, 0.1), CFrame.new(side * 0.55, 0.15, 0.55), strap, Enum.Material.Fabric)
		jarPart(model, torso, "Buckle", Vector3.new(0.36, 0.28, 0.08), CFrame.new(side * 0.55, -0.25, -0.6), metal, Enum.Material.Metal)
	end
	jarPart(model, torso, "ChestStrap", Vector3.new(1.25, 0.22, 0.1), CFrame.new(0, -0.32, -0.56), strap, Enum.Material.Fabric)
	jarPart(model, torso, "ChestClasp", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0, -0.32, -0.62), metal, Enum.Material.Metal)
end

local leather, gold, iron = Color3.fromRGB(86, 56, 38), Color3.fromRGB(226, 186, 92), Color3.fromRGB(38, 36, 48)
local jarBuilders = {}

jarBuilders["Clay Jar"] = function(m, t)
	local B, clay = JAR_BASE, Color3.fromRGB(178, 112, 80)
	jarPart(m, t, "Body", Vector3.new(1.55, 1.85, 1.55), B, clay, Enum.Material.Slate, 0, BALL)
	jarPart(m, t, "Neck", Vector3.new(0.6, 0.85, 0.85), B * CFrame.new(0, 0.95, 0) * UPR, clay, Enum.Material.Slate, 0, CYL)
	jarPart(m, t, "Lip", Vector3.new(0.18, 1.05, 1.05), B * CFrame.new(0, 1.25, 0) * UPR, Color3.fromRGB(150, 92, 66), Enum.Material.Slate, 0, CYL)
	jarPart(m, t, "PaintBandLow", Vector3.new(0.12, 1.6, 1.6), B * CFrame.new(0, -0.2, 0) * UPR, Color3.fromRGB(120, 50, 40), Enum.Material.Slate, 0, CYL)
	jarPart(m, t, "PaintBandHigh", Vector3.new(0.1, 1.42, 1.42), B * CFrame.new(0, 0.38, 0) * UPR, Color3.fromRGB(60, 40, 70), Enum.Material.Slate, 0, CYL)
	jarPart(m, t, "Cork", Vector3.new(0.4, 0.7, 0.7), B * CFrame.new(0, 1.5, 0) * UPR, Color3.fromRGB(150, 110, 70), Enum.Material.Wood, 0, CYL)
	jarPart(m, t, "Twine", Vector3.new(0.08, 0.9, 0.9), B * CFrame.new(0, 1.1, 0) * UPR, Color3.fromRGB(210, 190, 140), Enum.Material.Fabric, 0, CYL)
	jarPart(m, t, "Crack", Vector3.new(0.06, 0.55, 0.04), B * CFrame.new(0.3, 0.1, 0.77) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(70, 40, 30), Enum.Material.Slate)
	jarPart(m, t, "Fill", Vector3.new(0.06, 0.62, 0.62), B * CFrame.new(0, 1.71, 0) * UPR, Color3.fromRGB(110, 190, 255), Enum.Material.Neon, 0.9, CYL)
	harness(m, t, leather, Color3.fromRGB(150, 120, 80))
	return { mode = "glow" }
end

jarBuilders["Glass Jar"] = function(m, t)
	local B = JAR_BASE
	jarPart(m, t, "Body", Vector3.new(2.0, 1.35, 1.35), B * UPR, Color3.fromRGB(200, 235, 255), Enum.Material.Glass, 0.55, CYL)
	jarPart(m, t, "BandLow", Vector3.new(0.2, 1.45, 1.45), B * CFrame.new(0, -0.95, 0) * UPR, Color3.fromRGB(150, 156, 176), Enum.Material.Metal, 0, CYL)
	jarPart(m, t, "BandHigh", Vector3.new(0.2, 1.45, 1.45), B * CFrame.new(0, 0.95, 0) * UPR, Color3.fromRGB(150, 156, 176), Enum.Material.Metal, 0, CYL)
	jarPart(m, t, "Neck", Vector3.new(0.35, 0.95, 0.95), B * CFrame.new(0, 1.2, 0) * UPR, Color3.fromRGB(200, 235, 255), Enum.Material.Glass, 0.5, CYL)
	jarPart(m, t, "Cork", Vector3.new(0.45, 0.85, 0.85), B * CFrame.new(0, 1.55, 0) * UPR, Color3.fromRGB(150, 110, 70), Enum.Material.Wood, 0, CYL)
	jarPart(m, t, "WaxSeal", Vector3.new(0.35, 0.35, 0.2), B * CFrame.new(0, 1.55, 0.43), Color3.fromRGB(170, 30, 40), Enum.Material.SmoothPlastic, 0, BALL)
	local label = jarPart(m, t, "Label", Vector3.new(0.9, 0.7, 0.05), B * CFrame.new(0, 0.1, 0.69), Color3.fromRGB(235, 222, 190), Enum.Material.SmoothPlastic)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 60; sg.Parent = label
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = "SOULS"; tl.TextScaled = true
	tl.Font = Enum.Font.Antique; tl.TextColor3 = Color3.fromRGB(60, 40, 40); tl.Parent = sg
	harness(m, t, leather, Color3.fromRGB(180, 186, 206))
	return { mode = "level", bottom = -0.9, height = 1.75, dia = 1.12, color = Color3.fromRGB(110, 200, 255) }
end

jarBuilders["Lantern Jar"] = function(m, t)
	local B = JAR_BASE
	jarPart(m, t, "Body", Vector3.new(1.9, 1.3, 1.3), B * UPR, Color3.fromRGB(255, 230, 170), Enum.Material.Glass, 0.6, CYL)
	jarPart(m, t, "BasePlate", Vector3.new(0.25, 1.55, 1.55), B * CFrame.new(0, -1.05, 0) * UPR, iron, Enum.Material.Metal, 0, CYL)
	for i = 0, 2 do
		local d = 1.6 * (1 - i / 3.2)
		jarPart(m, t, "Roof" .. i, Vector3.new(0.22, d, d), B * CFrame.new(0, 1.05 + i * 0.2, 0) * UPR, iron, Enum.Material.Metal, 0, CYL)
	end
	jarPart(m, t, "HandleRing", Vector3.new(0.08, 0.6, 0.6), B * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, 0, CYL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		jarPart(m, t, "CagePost", Vector3.new(0.09, 2.0, 0.09), B * CFrame.new(math.cos(a) * 0.68, 0, math.sin(a) * 0.68), iron, Enum.Material.Metal)
	end
	jarPart(m, t, "CageBand", Vector3.new(0.12, 1.45, 1.45), B * CFrame.new(0, 0, 0) * UPR, iron, Enum.Material.Metal, 0, CYL)
	harness(m, t, Color3.fromRGB(60, 44, 40), gold)
	return { mode = "level", bottom = -0.85, height = 1.65, dia = 1.0, color = Color3.fromRGB(255, 200, 110) }
end

jarBuilders["Crystal Vessel"] = function(m, t)
	local B = JAR_BASE
	for i = 0, 3 do
		jarPart(m, t, "Facet" .. i, Vector3.new(1.0, 2.0, 1.0), B * CFrame.Angles(0, math.rad(i * 22.5), 0), Color3.fromRGB(150, 255, 235), Enum.Material.Glass, 0.55)
	end
	jarPart(m, t, "Cap", Vector3.new(0.3, 1.2, 1.2), B * CFrame.new(0, 1.15, 0) * UPR, gold, Enum.Material.Metal, 0, CYL)
	jarPart(m, t, "CapGem", Vector3.new(0.45, 0.45, 0.45), B * CFrame.new(0, 1.45, 0), Color3.fromRGB(110, 255, 220), Enum.Material.Neon, 0, BALL)
	jarPart(m, t, "Base", Vector3.new(0.3, 1.2, 1.2), B * CFrame.new(0, -1.15, 0) * UPR, gold, Enum.Material.Metal, 0, CYL)
	for i = 0, 4 do
		local a = i * (math.pi * 2 / 5)
		jarPart(m, t, "Shard", Vector3.new(0.18, 0.55, 0.18), B * CFrame.new(math.cos(a) * 1.0, -0.4 + (i % 2) * 0.8, math.sin(a) * 1.0) * CFrame.Angles(math.rad(20), a, math.rad(15)), Color3.fromRGB(150, 255, 235), Enum.Material.Neon, 0.2)
	end
	harness(m, t, Color3.fromRGB(40, 70, 80), gold)
	return { mode = "level", bottom = -0.85, height = 1.7, dia = 0.85, color = Color3.fromRGB(110, 255, 220) }
end

jarBuilders["Void Urn"] = function(m, t)
	local B, glass = JAR_BASE, Color3.fromRGB(70, 40, 110)
	jarPart(m, t, "Foot", Vector3.new(0.25, 1.0, 1.0), B * CFrame.new(0, -1.05, 0) * UPR, gold, Enum.Material.Metal, 0, CYL)
	jarPart(m, t, "Belly", Vector3.new(1.65, 1.6, 1.65), B * CFrame.new(0, -0.2, 0), glass, Enum.Material.Glass, 0.35, BALL)
	jarPart(m, t, "BellyRing", Vector3.new(0.12, 1.66, 1.66), B * CFrame.new(0, -0.2, 0) * UPR, gold, Enum.Material.Metal, 0, CYL)
	jarPart(m, t, "Shoulder", Vector3.new(0.4, 1.15, 1.15), B * CFrame.new(0, 0.55, 0) * UPR, glass, Enum.Material.Glass, 0.3, CYL)
	jarPart(m, t, "Neck", Vector3.new(0.55, 0.7, 0.7), B * CFrame.new(0, 0.95, 0) * UPR, glass, Enum.Material.Glass, 0.3, CYL)
	jarPart(m, t, "Lip", Vector3.new(0.15, 1.05, 1.05), B * CFrame.new(0, 1.25, 0) * UPR, gold, Enum.Material.Metal, 0, CYL)
	for _, side in ipairs({ -1, 1 }) do
		jarPart(m, t, "UrnHandle", Vector3.new(0.12, 0.8, 0.12), B * CFrame.new(side * 0.7, 0.75, 0) * CFrame.Angles(0, 0, math.rad(side * -35)), gold, Enum.Material.Metal)
	end
	harness(m, t, Color3.fromRGB(40, 26, 56), gold)
	return { mode = "level", bottom = -0.85, height = 1.5, dia = 0.95, color = Color3.fromRGB(200, 120, 255) }
end

jarBuilders["Abyss Coffin"] = function(m, t)
	local B, wood = JAR_BASE, Color3.fromRGB(28, 22, 36)
	jarPart(m, t, "CoffinLower", Vector3.new(1.15, 1.7, 0.75), B * CFrame.new(0, -0.35, 0), wood, Enum.Material.Slate)
	jarPart(m, t, "CoffinShoulders", Vector3.new(1.55, 0.75, 0.75), B * CFrame.new(0, 0.75, 0), wood, Enum.Material.Slate)
	jarPart(m, t, "CoffinHead", Vector3.new(1.15, 0.45, 0.75), B * CFrame.new(0, 1.3, 0), wood, Enum.Material.Slate)
	jarPart(m, t, "LidTrim", Vector3.new(1.6, 0.1, 0.8), B * CFrame.new(0, 1.12, 0), gold, Enum.Material.Metal)
	for _, y in ipairs({ -0.6, 0.35 }) do
		jarPart(m, t, "Chain", Vector3.new(1.62, 0.12, 0.82), B * CFrame.new(0, y, 0), Color3.fromRGB(90, 90, 104), Enum.Material.Metal)
	end
	jarPart(m, t, "Fill", Vector3.new(0.16, 1.4, 0.05), B * CFrame.new(0, 0.2, 0.39), Color3.fromRGB(255, 80, 110), Enum.Material.Neon, 0.5)
	jarPart(m, t, "CrossBar", Vector3.new(0.75, 0.16, 0.05), B * CFrame.new(0, 0.45, 0.39), Color3.fromRGB(255, 80, 110), Enum.Material.Neon, 0.5)
	harness(m, t, Color3.fromRGB(30, 22, 30), gold)
	return { mode = "glow" }
end

-- Expedition storage: four distinct shells around a visible soul reservoir.
local expeditionJars={
 {"Moonstone Reliquary",Color3.fromRGB(130,220,255),"moon"},
 {"Astral Reservoir",Color3.fromRGB(175,150,255),"astral"},
 {"Eclipse Reactor",Color3.fromRGB(255,140,100),"reactor"},
 {"Sovereign Vault",Color3.fromRGB(255,225,130),"vault"},
}
for _,entry in ipairs(expeditionJars) do
 local name,tint,style=entry[1],entry[2],entry[3]
 jarBuilders[name]=function(m,t)
  local B=JAR_BASE
  harness(m,t,Color3.fromRGB(32,30,48),style=="vault" and gold or iron)
  jarPart(m,t,"SoulChamber",Vector3.new(2.15,1.45,1.45),B*UPR,tint,Enum.Material.Glass,.62,CYL)
  for _,y in ipairs({-1.15,1.15}) do
   jarPart(m,t,"EndCap",Vector3.new(.18,1.65,1.65),B*CFrame.new(0,y,0)*UPR,style=="vault" and gold or iron,Enum.Material.Metal,0,CYL)
  end
  if style=="moon" then
   for i=0,5 do local a=i*math.pi/3
    jarPart(m,t,"ReliquaryPillar",Vector3.new(.1,2.2,.1),B*CFrame.new(math.cos(a)*.78,0,math.sin(a)*.78),gold,Enum.Material.Metal)
   end
   jarPart(m,t,"Moonstone",Vector3.new(.6,.85,.6),B*CFrame.new(0,1.6,0)*CFrame.Angles(0,0,math.rad(45)),tint,Enum.Material.Glass,.2)
  elseif style=="astral" then
   for i=0,7 do local a=i*math.pi/4
    jarPart(m,t,"OrbitalRune",Vector3.new(.18,.4,.18),B*CFrame.new(math.cos(a),math.sin(a),.5)*CFrame.Angles(0,0,a),tint,Enum.Material.Neon)
   end
   for _,side in ipairs({-1,1}) do
    jarPart(m,t,"CrystalWing",Vector3.new(.35,1.65,.4),B*CFrame.new(side*.95,.1,0)*CFrame.Angles(0,0,side*.3),tint,Enum.Material.Glass,.25)
   end
  elseif style=="reactor" then
   for _,side in ipairs({-1,1}) do
    jarPart(m,t,"ReactorCoil",Vector3.new(1.8,.45,.45),B*CFrame.new(side*.93,0,0)*UPR,iron,Enum.Material.Metal,0,CYL)
    for i=0,4 do
     jarPart(m,t,"CoolingFin",Vector3.new(.08,.65,.65),B*CFrame.new(side*.93,-.75+i*.37,0)*UPR,tint,Enum.Material.Neon,0,CYL)
    end
   end
   jarPart(m,t,"WarningPlate",Vector3.new(.55,.45,.07),B*CFrame.new(0,.7,.76),gold,Enum.Material.Metal)
  else
   for _,side in ipairs({-1,1}) do
    jarPart(m,t,"VaultPillar",Vector3.new(.24,2.35,.5),B*CFrame.new(side*.83,0,0),gold,Enum.Material.Metal)
   end
   for i=-2,2 do
    jarPart(m,t,"CrownPoint",Vector3.new(.18,.4+(.2*(2-math.abs(i))),.18),B*CFrame.new(i*.32,1.45,0),gold,Enum.Material.Metal)
   end
   jarPart(m,t,"RoyalSeal",Vector3.new(.45,.45,.12),B*CFrame.new(0,0,.8)*CFrame.Angles(0,0,math.pi/4),tint,Enum.Material.Neon)
  end
  return {mode="level",bottom=-1.02,height=2.04,dia=1.16,color=tint}
 end
end

updateJarVisual = function(player, data)
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if not torso then return end
	local tier=Config.storageFor(data)
	if not tier then local old=character:FindFirstChild("SoulJarVisual");if old then old:Destroy() end;return end
	local ratio = math.clamp(data.souls / math.max(Config.capacityFor(data), 1), 0, 1)

	local model = character:FindFirstChild("SoulJarVisual")
	if model and model:GetAttribute("Tier") ~= tier.name then model:Destroy(); model = nil end
	if not model then
		model = Instance.new("Model")
		model.Name = "SoulJarVisual"
		model:SetAttribute("Tier", tier.name)
		local spec = (jarBuilders[tier.name] or jarBuilders["Clay Jar"])(model, torso)
		-- Blender jar mesh (if imported): replaces the part-built jar body, keeps the harness and the soul fill
		local blender = game:GetService("ServerStorage"):FindFirstChild("BlenderAssets")
		local jarMesh = blender and blender:FindFirstChild("Jar_" .. tostring(tier.id))
		if jarMesh then
			local HARNESS = { Buckle = true, ChestClasp = true, ChestStrap = true, StrapBack = true, StrapFront = true, StrapShoulder = true, Fill = true }
			local mn, mx
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") and not HARNESS[p.Name] then
					local weld = p:FindFirstChildOfClass("Weld")
					local rel = weld and (weld.C0 * weld.C1:Inverse()) or torso.CFrame:ToObjectSpace(p.CFrame)
					local s = p.Size
					for _, cx in ipairs({ -1, 1 }) do for _, cy in ipairs({ -1, 1 }) do for _, cz in ipairs({ -1, 1 }) do
						local w = rel:PointToWorldSpace(Vector3.new(cx * s.X / 2, cy * s.Y / 2, cz * s.Z / 2))
						mn = mn and mn:Min(w) or w; mx = mx and mx:Max(w) or w
					end end end
					p.Transparency = 1
					for _, d in ipairs(p:GetChildren()) do if d:IsA("Decal") or d:IsA("SurfaceGui") then d:Destroy() end end
					if p.Name == "CrossBar" then p.Name = "CrossBarHidden" end
				end
			end
			if mn then
				local clone = jarMesh:Clone()
				local _, size = clone:GetBoundingBox()
				clone:ScaleTo(clone:GetScale() * (mx.Y - mn.Y) / size.Y)
				clone:PivotTo(CFrame.identity)
				local centre = (mn + mx) / 2
				local _, size2 = clone:GetBoundingBox()
				-- pivot (jar base) in torso space, jar front turned away from the back
				local pivotLocal = CFrame.new(centre.X, centre.Y - size2.Y / 2, centre.Z) * CFrame.Angles(0, math.pi, 0)
				local seeThrough = { GlassJar = true, LanternJar = true, CrystalVessel = true }
				for _, p in ipairs(clone:GetDescendants()) do
					if p:IsA("BasePart") then
						local offset = p.CFrame
						p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
						if seeThrough[tier.id] and p.Name:match("^Neon") then p.Transparency = 1 end
						local w = Instance.new("Weld"); w.Part0 = torso; w.Part1 = p; w.C0 = pivotLocal * offset; w.Parent = p
						p.Parent = model
					end
				end
				clone:Destroy()
				model:SetAttribute("BlenderJar", true)
			end
		end
		local fill = model:FindFirstChild("Fill")
		if spec.mode == "level" and not fill then
			fill = jarPart(model, torso, "Fill", Vector3.new(0.1, spec.dia, spec.dia), JAR_BASE * UPR, spec.color, Enum.Material.Neon, 0.15, CYL)
		end
		model:SetAttribute("FillMode", spec.mode)
		model:SetAttribute("FillBottom", spec.bottom or 0)
		model:SetAttribute("FillHeight", spec.height or 0)
		model:SetAttribute("FillDia", spec.dia or 0)
		local light = Instance.new("PointLight"); light.Name = "JarGlow"; light.Color = fill.Color; light.Range = 9; light.Brightness = 0; light.Parent = fill
		local swirl = Instance.new("ParticleEmitter"); swirl.Name = "SoulSwirl"
		swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"; swirl.Color = ColorSequence.new(fill.Color); swirl.LightEmission = 1
		swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		swirl.Lifetime = NumberRange.new(0.6, 1.2); swirl.Speed = NumberRange.new(0.3, 0.9); swirl.SpreadAngle = Vector2.new(180, 180)
		swirl.Rate = 0; swirl.Parent = fill
		model.Parent = character
	end

	local fill = model:FindFirstChild("Fill")
	if not fill then return end
 local strongest;for _,batch in ipairs(SoulLedger.view(data)) do if not strongest or batch.count>strongest.count then strongest=batch end end
 if strongest then fill.Color=Color3.fromRGB(table.unpack(strongest.color)) end
	if model:GetAttribute("FillMode") == "level" then
		local h = math.max(0.08, model:GetAttribute("FillHeight") * ratio)
		local dia = model:GetAttribute("FillDia")
		fill.Size = Vector3.new(h, dia, dia)
		local weld = fill:FindFirstChildOfClass("Weld")
		if weld then weld.C0 = JAR_BASE * CFrame.new(0, model:GetAttribute("FillBottom") + h / 2, 0) * UPR end
		fill.Transparency = ratio <= 0.001 and 1 or 0.15
	else
		fill.Transparency = 0.9 - 0.8 * ratio
		local bar = model:FindFirstChild("CrossBar")
		if bar then bar.Transparency = fill.Transparency end
	end
	local light = fill:FindFirstChild("JarGlow")
	if light then light.Brightness = ratio * 1.6 end
	local swirl = fill:FindFirstChild("SoulSwirl")
	if swirl then swirl.Rate = ratio > 0 and (2 + ratio * 14) or 0 end
end

----------------------------------------------------------------------
-- Boss reward hook: the Bosses script calls this for every player who helped
----------------------------------------------------------------------
local bossRewardFn = Instance.new("BindableFunction")
bossRewardFn.Name = "BossReward"
bossRewardFn.Parent = ServerStorage
bossRewardFn.OnInvoke = function(player, essence, souls, bossName)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	local data = DataService.get(player)
	if not data then return false end
	essence = math.max(0, math.floor(tonumber(essence) or 0))
	souls = math.max(0, math.floor(tonumber(souls) or 0))
	grantEssence(player, data, essence)
	local room = math.max(0, Config.capacityFor(data) - data.souls)
	local added = math.min(souls, room)
	SoulLedger.add(data,added,"Graveyard","Pure")
	data.stats.bossKills = (data.stats.bossKills or 0) + 1
	pushState(player)
	notify(player, ("%s defeated! +%d Essence, +%d souls"):format(tostring(bossName or "Boss"), essence, added), "good")
	return true
end

print("[Haunted Harvest] Server ready.")
