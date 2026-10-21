-- DataService: owns ALL persistence. Gameplay code only touches the in-memory
-- table returned by DataService.get(player); it never calls DataStores itself.
--
-- Safety features: retry with backoff, UpdateAsync (no Get+Set races), session
-- locking (stops dupes across servers), autosave, save on leave, BindToClose.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "HauntedHarvest_v1"
local AUTOSAVE_SECONDS = 60
local LOCK_TTL = 150 -- a lock older than this is considered stale (crashed server)
local VERSION = 1
local IS_STUDIO = RunService:IsStudio()

local TEST_MODE = IS_STUDIO and script:GetAttribute("StudioQA") == true
local SESSION_ID = game.JobId ~= "" and game.JobId or game:GetService("HttpService"):GenerateGUID(false)
local store = DataStoreService:GetDataStore(TEST_MODE and (STORE_NAME.."_StudioQA") or STORE_NAME)

local Config=require(game.ReplicatedStorage.Shared.Config)
local DataService = {}
local profiles = {} -- [Player] = { data = table, key = string, temp = boolean? }
local tradeStore=DataStoreService:GetDataStore(TEST_MODE and "HauntedHarvest_Trades_StudioQA" or "HauntedHarvest_Trades_v1")
local loadedCallbacks = {}
local inflight = 0

local function defaultData()
	return {
		version = VERSION,
		pets={inventory={},equipped={}},
		rebirths=0,
		events={},
		equipment={tool="GraveVacuum",storage="ClayJar"},ownedStorage={ClayJar=true},eggs={},settings={vfx=true,volume=1,waypoints=true,holdCollect=true},codes={},boosts={},receipts={},
		souls = 0,
		essence = 0,
 paidEssence=0,bankedSouls=0,carriedPaidSouls=0,
        passes={},soulBatches={},consumables={},badges={},foods={SpiritTreat=5},royalEssence=0,eggLevels={},
		upgrades = { JarSize = 0, Refinement = 0, GreedyHands = 0, SpectralBoots = 0, Helpers = 0 },
		done = {}, -- completed quest ids -> true
		daily = { last = 0, streak = 0 },
		graphics = "auto",
		unlockedZones = {},
		tools = { GraveVacuum = true }, -- owned collecting tools -- zoneId -> true once the gate is open -- "auto" | "low" | "high"
		stats = { totalSouls = 0, totalEssence = 0 },
	}
end

-- Fill in any fields missing from older saves (cheap "migration")
local function reconcile(data)
	local d = defaultData()
	data.equipment=data.equipment or {tool="GraveVacuum",storage=Config.jarTier((data.upgrades and data.upgrades.JarSize) or 0).id}
	data.ownedStorage=data.ownedStorage or {ClayJar=true};data.ownedStorage[Config.jarTier((data.upgrades and data.upgrades.JarSize) or 0).id]=true
	for k, v in pairs(d) do
		if data[k] == nil then
			data[k] = v
		end
	end
	for k, v in pairs(d.upgrades) do
		if data.upgrades[k] == nil then data.upgrades[k] = v end
	end
	for k, v in pairs(d.stats) do
		if data.stats[k] == nil then data.stats[k] = v end
	end
	for k,v in pairs(d.settings) do if data.settings[k]==nil then data.settings[k]=v end end
	-- the Wisp Net was replaced by the Grave Vacuum
	data.tools = data.tools or {}
	data.tools.WispNet = nil
	data.tools.GraveVacuum = true
	data.version = VERSION
	return data
end

local function retry(attempts, fn)
	local delaySeconds = 1
	for attempt = 1, attempts do
		local ok, err = pcall(fn)
		if ok then
			return true
		end
		warn(("[DataService] attempt %d/%d failed: %s"):format(attempt, attempts, tostring(err)))
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 16)
		end
	end
	return false
end

-- Atomically claim the player's save for THIS server and load it.
-- Returns "ok", data | "locked" | "failed"
local function claim(key)
	local attempts = IS_STUDIO and 1 or 4
	for _ = 1, 4 do
		local outcome, loaded
		local ok = retry(attempts, function()
			store:UpdateAsync(key, function(old)
				local now = os.time()
				if old and old.lock and old.lock.job ~= SESSION_ID and (now - old.lock.t) < LOCK_TTL then
					outcome = "locked"
					return nil
				end
				outcome = "ok"
				loaded = reconcile((old and old.data) or defaultData())
				return { data = loaded, lock = { job = SESSION_ID, t = now } }
			end)
		end)
		if not ok then
			return "failed"
		end
		if outcome == "ok" then
			return "ok", loaded
		end
		task.wait(4) -- another server may be mid-release; try again shortly
	end
	return "locked"
end

local function copy(value)
	if type(value)~="table" then return value end
	local result={} for k,v in pairs(value) do result[k]=copy(v) end return result
end
local function save(profile, release)
	if profile.temp then return false end
	if profile.released then return false end
	inflight += 1
	while profile.saving do task.wait(.05) end
	if profile.released then inflight-=1;return false end
	profile.saving=true
	local snapshot=copy(profile.data)
	local wrote=false
	local ok = retry(IS_STUDIO and 2 or 5, function()
		store:UpdateAsync(profile.key, function(old)
			local now=os.time()
			if not old or not old.lock or old.lock.job~=SESSION_ID then
				wrote=false;return nil
			end
			wrote=true
			return {data=snapshot,lock=not release and {job=SESSION_ID,t=now} or nil}
		end)
	end)
	profile.saving=false
	if ok and wrote and release then profile.released=true end
	inflight-=1
	return ok and wrote
end

local function applyTrade(data, record, userId)
	local give,take
	if record.a==userId then give,take=record.giveA,record.giveB
	elseif record.b==userId then give,take=record.giveB,record.giveA
	else return false end
	local removing={}
	for _,pet in ipairs(give) do removing[pet.uid]=true end
	for i=#data.pets.inventory,1,-1 do if removing[data.pets.inventory[i].uid] then table.remove(data.pets.inventory,i) end end
	for i=#data.pets.equipped,1,-1 do if removing[data.pets.equipped[i]] then table.remove(data.pets.equipped,i) end end
	local owned={} for _,pet in ipairs(data.pets.inventory) do owned[pet.uid]=true end
	for _,pet in ipairs(take) do if not owned[pet.uid] then table.insert(data.pets.inventory,copy(pet));owned[pet.uid]=true end end
	return true
end
local function recoverTrade(profile,userId)
	local pending=profile.data.tradePending
	if not pending then return true end
	local record
	if not retry(IS_STUDIO and 2 or 5,function() record=tradeStore:UpdateAsync(pending.id,function(old) return old or {committed=false,aborted=true,time=os.time()} end) end) then return false end
	if record and record.committed then
		if not applyTrade(profile.data,record,userId) then return false end
	end
	profile.data.tradePending=nil
	return save(profile,false)
end

local function onPlayerAdded(player)
	local key = "P_" .. player.UserId
	local status, data = claim(key)

	if not player:IsDescendantOf(Players) then
		-- they left while we were loading; release the lock we just took
		if status == "ok" then
			save({ data = data, key = key }, true)
		end
		return
	end

	local profile
	if status == "ok" then
		profile = { data = data, key = key }
	elseif IS_STUDIO then
		warn("[DataService] Could not load saved data in Studio (" .. tostring(status) .. "). Using a TEMPORARY profile that will not be saved. To test saving, turn on Game Settings > Security > 'Enable Studio Access to API Services'.")
		profile = { data = defaultData(), key = key, temp = true }
	else
		-- NEVER let someone play on a blank profile over live data: their next save would wipe it
		player:Kick("Your data could not be loaded. Please rejoin in a moment.")
		return
	end

	if profile.data.tradePending and not recoverTrade(profile,player.UserId) then
		save(profile,true)
		player:Kick("Your pet exchange is still recovering. Please rejoin in a moment.")
		return
	end
	profiles[player] = profile
	player:SetAttribute("TemporaryProfile",profile.temp==true)
	player:SetAttribute("TestProfile",TEST_MODE)
	for _, cb in ipairs(loadedCallbacks) do
		task.spawn(cb, player, profile.data)
	end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function DataService.get(player)
	local p = profiles[player]
	return p and p.data or nil
end


function DataService.inventoryBusy(player)
	local p=profiles[player]
	return not p or p.busy==true or p.data.tradePending~=nil
end

-- Durable pet exchange: both inventories reserve their offers before one
-- committed ledger record is written. Pending exchanges recover on next load.
function DataService.trade(a,b,idsA,idsB)
	local pa,pb=profiles[a],profiles[b]
	if a==b or not pa or not pb or pa.temp or pb.temp or DataService.inventoryBusy(a) or DataService.inventoryBusy(b) then return false,"Profiles are unavailable or busy." end
	local function offer(profile,ids)
		if type(ids)~="table" or #ids>3 then return end
		local owned={} for _,pet in ipairs(profile.data.pets.inventory) do owned[pet.uid]=pet end
		local seen,result={},{}
		for _,id in ipairs(ids) do if type(id)~="string" or seen[id] or not owned[id] or owned[id].paid then return end;seen[id]=true;table.insert(result,copy(owned[id])) end
		return result
	end
	local giveA,giveB=offer(pa,idsA),offer(pb,idsB)
	if not giveA or not giveB or #giveA+#giveB==0 then return false,"Choose owned pets." end
	if #pa.data.pets.inventory-#giveA+#giveB>30 or #pb.data.pets.inventory-#giveB+#giveA>30 then return false,"An inventory is full." end
	pa.busy=true;pb.busy=true
	local id=game:GetService("HttpService"):GenerateGUID(false)
	local record={committed=true,a=a.UserId,b=b.UserId,giveA=giveA,giveB=giveB,time=os.time()}
	pa.data.tradePending={id=id};pb.data.tradePending={id=id}
	local preparedA=save(pa,false);local preparedB=preparedA and save(pb,false)
	if not preparedA or not preparedB then
		pa.data.tradePending=nil;pb.data.tradePending=nil
		save(pa,false);save(pb,false);pa.busy=false;pb.busy=false
		return false,"Saving failed; pets were not exchanged."
	end
	local committed=false
	local ok=retry(IS_STUDIO and 2 or 5,function()
		local stored=tradeStore:UpdateAsync(id,function(old) return old or record end)
		committed=stored and stored.committed==true
	end)
	if not ok or not committed then
		-- A timeout can happen after a successful write. Keep reservations
		-- until the ledger can resolve them; never guess the outcome.
		task.spawn(function()
			for _=1,12 do
				if recoverTrade(pa,a.UserId) and recoverTrade(pb,b.UserId) then pa.busy=false;pb.busy=false;return end
				task.wait(5)
			end
		end)
		return false,"The exchange is recovering. Rejoin if it remains pending."
	end
	applyTrade(pa.data,record,a.UserId);applyTrade(pb.data,record,b.UserId)
	pa.data.tradePending=nil;pb.data.tradePending=nil
	save(pa,false);save(pb,false)
	pa.busy=false;pb.busy=false
	return true
end

function DataService.applyReceipt(player,receiptId,grant)
	local profile=profiles[player]
	if not profile or profile.temp or DataService.inventoryBusy(player) or typeof(receiptId)~="string" then return false end
	profile.data.receipts=profile.data.receipts or {}
	if not profile.data.receipts[receiptId] then
		grant(profile.data)
		profile.data.receipts[receiptId]=true
	end
	return save(profile,false)
end

function DataService.saveNow(player)
	local profile=profiles[player]
	return profile and save(profile,false) or false
end

function DataService.onLoaded(callback)
	table.insert(loadedCallbacks, callback)
	for player, profile in pairs(profiles) do
		task.spawn(callback, player, profile.data)
	end
end

----------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = profiles[player]
	if not profile then return end
	profiles[player] = nil
	save(profile, true)
end)

-- Staggered autosave
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		local list = {}
		for _, profile in pairs(profiles) do
			table.insert(list, profile)
		end
		for _, profile in ipairs(list) do
			task.spawn(save, profile, false)
			task.wait(AUTOSAVE_SECONDS / math.max(#list, 1) / 2)
		end
	end
end)

game:BindToClose(function()
	for player, profile in pairs(profiles) do
		profiles[player] = nil
		task.spawn(save, profile, true)
	end
	local startedAt = os.clock()
	local maxWait = IS_STUDIO and 5 or 25
	task.wait() -- let the spawned saves begin
	while inflight > 0 and os.clock() - startedAt < maxWait do
		task.wait(0.2)
	end
end)

return DataService
