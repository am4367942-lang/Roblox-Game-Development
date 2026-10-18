-- PlayerProgression.server.luau
-- Place this Script in ServerScriptService.
-- Enable Studio API access for DataStore testing in a published experience.
-- Award XP from trusted server-side game logic using AwardXP(player, amount).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("PlayerProgression_v1")
local BASE_XP = 100
local XP_GROWTH = 1.25
local COINS_PER_LEVEL = 50

local sessionData = {}

local function xpNeeded(level)
	return math.floor(BASE_XP * (XP_GROWTH ^ (level - 1)))
end

local function sanitize(data)
	if type(data) ~= "table" then
		return { Level = 1, XP = 0, Coins = 0 }
	end
	return {
		Level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, 10000),
		XP = math.max(0, math.floor(tonumber(data.XP) or 0)),
		Coins = math.max(0, math.floor(tonumber(data.Coins) or 0)),
	}
end

local function syncStats(player)
	local data = sessionData[player]
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then return end
	stats.Level.Value = data.Level
	stats.Coins.Value = data.Coins
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeeded", xpNeeded(data.Level))
end

local function awardXP(player, amount)
	local data = sessionData[player]
	if not data or type(amount) ~= "number" or amount ~= amount then return end
	amount = math.floor(amount)
	if amount <= 0 or amount > 100000 then return end

	data.XP += amount
	while data.Level < 10000 and data.XP >= xpNeeded(data.Level) do
		data.XP -= xpNeeded(data.Level)
		data.Level += 1
		data.Coins += COINS_PER_LEVEL
	end
	syncStats(player)
end

local function savePlayer(player)
	local data = sessionData[player]
	if not data then return end
	local snapshot = table.clone(data)
	local success, err = pcall(function()
		STORE:UpdateAsync(tostring(player.UserId), function()
			return snapshot
		end)
	end)
	if not success then
		warn("Failed to save progression for " .. player.Name .. ": " .. tostring(err))
	end
end

local function onPlayerAdded(player)
	local success, result = pcall(function()
		return STORE:GetAsync(tostring(player.UserId))
	end)
	if not success then
		warn("Could not load progression for " .. player.Name .. ": " .. tostring(result))
		player:Kick("Your data could not be loaded. Please rejoin to protect your progress.")
		return
	end
	if not player.Parent then return end

	sessionData[player] = sanitize(result)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = stats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	syncStats(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	sessionData[player] = nil
end)

-- Example of a server-only XP reward. Replace this with your own quest,
-- combat, or minigame completion logic. Never trust client-submitted XP amounts.
local awardXPEvent = Instance.new("BindableEvent")
awardXPEvent.Name = "AwardPlayerXP"
awardXPEvent.Parent = script
awardXPEvent.Event:Connect(awardXP)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)
