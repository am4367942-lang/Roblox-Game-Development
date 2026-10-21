-- QuestService: quest state machine. Works on the in-memory data table only.
-- One quest can be active at a time: data.quest = { id = string, progress = number }
-- Completed quests live in data.done[id] = true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local QuestService = {}
local ctx -- { notify = fn, grantEssence = fn }

function QuestService.init(context)
	ctx = context
end

-- First quest from this NPC that isn't done yet (nil if the NPC has nothing left)
local function nextQuestFor(data, npcId)
	for _, q in ipairs(Config.QuestsByNpc[npcId] or {}) do
		if not data.done[q.id] then
			return q
		end
	end
	return nil
end

-- What the quest tracker UI shows (nil when no quest active)
function QuestService.view(data,player)
	local a = data.quest
	if not a then return nil end
	local q = Config.QuestById[a.id]
	if not q then
		data.quest = nil -- quest was removed from the game; drop it
		return nil
	end
	local ready=a.progress>=q.goal
	local targetPosition,targetLabel
	if ready then
		for _,npc in ipairs(game.CollectionService:GetTagged("QuestNPC")) do if npc:GetAttribute("NpcId")==q.npc then local root=npc:FindFirstChild("HumanoidRootPart");if root then targetPosition=root.Position;targetLabel="Return to "..Config.Npcs[q.npc].name end;break end end
	elseif q.kind=="collect" then
		local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local closest=math.huge
		for _,grave in ipairs(game.CollectionService:GetTagged("DigSpot")) do
			local zone=grave:GetAttribute("Zone") or "Graveyard";local def=Config.Zones[zone]
 if grave:IsDescendantOf(workspace) and (not q.zone or zone==q.zone) and (not def or not def.requires or data.unlockedZones[zone]) and (grave:GetAttribute("SoulReserve") or 1)>0 then
				local distance=root and (root.Position-grave.Position).Magnitude or 0
				if distance<closest then closest=distance;targetPosition=grave.Position end
			end
		end
		targetLabel="Collect souls · "..(Config.Zones[q.zone or "Graveyard"] and Config.Zones[q.zone or "Graveyard"].label or "Graveyard")
	else
		local tag=q.kind=="earn" and "ConvertPad" or "ShopCounter"
		local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local closest=math.huge
		for _,part in ipairs(game.CollectionService:GetTagged(tag)) do
			local owner=part:FindFirstAncestorWhichIsA("Model")
			if part:IsDescendantOf(workspace) and (not part:GetAttribute("OwnerOnly") or (player and owner and owner:GetAttribute("OwnerUserId")==player.UserId)) then
				local distance=root and (root.Position-part.Position).Magnitude or 0
				if distance<closest then closest=distance;targetPosition=part.Position end
			end
		end
		targetLabel=q.kind=="earn" and "Convert at your Spirit Roost" or "Visit the Spirit Emporium"
	end
	return {
		targetPosition=targetPosition,targetLabel=targetLabel,npcId=q.npc,
		id = q.id,
		title = q.title,
		desc = q.desc,
		progress = a.progress,
		goal = q.goal,
		ready = a.progress >= q.goal,
		npc = Config.Npcs[q.npc].name,
	}
end

-- Dialogue the NPC shows right now: returns npcName, text, actionLabel|nil
function QuestService.dialogue(data, npcId)
	local npc = Config.Npcs[npcId]
	if not npc then return nil end

	local a = data.quest
	if a then
		local q = Config.QuestById[a.id]
		if q and q.npc == npcId then
			if a.progress >= q.goal then
				return npc.name, q.doneText, ("Claim reward (+%d Essence)"):format(q.reward)
			end
			return npc.name, ("%s (%d/%d)"):format(q.progressText, a.progress, q.goal), nil
		elseif q then
			return npc.name, ("You're already helping %s. Finish \"%s\" first!"):format(Config.Npcs[q.npc].name, q.title), nil
		end
	end

	local q = nextQuestFor(data, npcId)
	if not q then
		return npc.name, npc.idle, nil
	end
	if q.requires and not data.done[q.requires] then
		return npc.name, npc.locked, nil
	end
	return npc.name, q.intro, "Accept quest: " .. q.title
end

-- Player pressed the action button. Returns true if something changed.
function QuestService.action(player, data, npcId)
	local a = data.quest
	if a then
		local q = Config.QuestById[a.id]
		if q and q.npc == npcId and a.progress >= q.goal then
			data.quest = nil
			data.done[q.id] = true
			ctx.grantEssence(player, data, q.reward)
            data.foods=data.foods or {};data.foods.SpiritTreat=(data.foods.SpiritTreat or 0)+3
            if q.reward>=1000 then data.royalEssence=(data.royalEssence or 0)+1;ctx.notify(player,"Bonus: 1 Royal Essence and 3 Spirit Treats!","good") end
			if q.eggReward then
				data.eggs=data.eggs or {};data.eggs[q.eggReward]=(data.eggs[q.eggReward] or 0)+1
				ctx.notify(player,"Quest bonus: "..require(game.ReplicatedStorage.Shared.GhostCatalog).EggById[q.eggReward].name.."! Open it in Ghost Lodge.","good")
				local refresh=game.ServerStorage:FindFirstChild("GhostRefresh");if refresh then refresh:Fire(player) end
			end
			local ghostRefresh=game.ServerStorage:FindFirstChild("GhostRefresh");if ghostRefresh then ghostRefresh:Fire(player) end
			ctx.notify(player, ("Quest complete: %s  (+%d Essence)"):format(q.title, q.reward), "good")
			return true
		end
		return false
	end

	local q = nextQuestFor(data, npcId)
	if q and (not q.requires or data.done[q.requires]) then
		data.quest = { id = q.id, progress = 0 }
		ctx.notify(player, "Quest started: " .. q.title, "info")
		return true
	end
	return false
end

----------------------------------------------------------------------
-- Progress events (called by gameplay code)
----------------------------------------------------------------------
local function bump(player, data, kind, amount, zone)
	local a = data.quest
	if not a then return end
	local q = Config.QuestById[a.id]
	if not q or q.kind ~= kind then return end
	if q.zone and q.zone ~= zone then return end
	if a.progress >= q.goal then return end

	a.progress = math.min(q.goal, a.progress + amount)
	if a.progress >= q.goal then
		ctx.notify(player, ("Quest ready! Return to %s"):format(Config.Npcs[q.npc].name), "good")
	end
end

function QuestService.onCollect(player, data, amount, zone)
	bump(player, data, "collect", amount, zone)
	local signal=game.ServerStorage:FindFirstChild("HarvestCollected")
	if signal then signal:Fire(player,amount,zone) end
end

function QuestService.onEarn(player, data, amount)
	bump(player, data, "earn", amount)
end

function QuestService.onBuy(player, data)
	bump(player, data, "buy", 1)
end

-- "reach"/"helpers" quests track a stat rather than an event
function QuestService.refresh(player, data)
	local a = data.quest
	if not a then return end
	local q = Config.QuestById[a.id]
	if not q then return end
	local value
	if q.kind == "reach" then
		value = data.upgrades.JarSize
	elseif q.kind == "helpers" then
		value = data.upgrades.Helpers or 0
	end
	if value and a.progress < q.goal then
		a.progress = math.min(q.goal, value)
		if a.progress >= q.goal then
			ctx.notify(player, ("Quest ready! Return to %s"):format(Config.Npcs[q.npc].name), "good")
		end
	end
end

-- Everything the quest log panel needs
function QuestService.log(data)
	local out = {}
	for _, q in ipairs(Config.Quests) do
		local status = "locked"
		if data.done[q.id] then
			status = "done"
		elseif data.quest and data.quest.id == q.id then
			status = "active"
		elseif not q.requires or data.done[q.requires] then
			status = "available"
		end
		table.insert(out, { id = q.id, title = q.title, desc = q.desc, npc = Config.Npcs[q.npc].name, reward = q.reward, eggReward=q.eggReward, status = status })
	end
	return out
end

return QuestService
