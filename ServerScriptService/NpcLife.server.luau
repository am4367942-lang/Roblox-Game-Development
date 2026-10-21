-- Creatures: ghost hunter AI, plus animations for hunters and quest NPCs.
-- Animation IDs are Roblox's default R15 set (read from the built-in Animate script).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local V = Vector3.new

local ANIM = {
	idle = "rbxassetid://507766388",
	walk = "rbxassetid://913402848",
	run = "rbxassetid://913376220",
	wave = "rbxassetid://507770239",
	point = "rbxassetid://507770453",
	cheer = "rbxassetid://507770677",
	laugh = "rbxassetid://507770818",
	dance = "rbxassetid://507771019",
	swing = "rbxassetid://522635514",
}
local PRIORITY = {
	idle = Enum.AnimationPriority.Idle,
	walk = Enum.AnimationPriority.Movement,
	run = Enum.AnimationPriority.Movement,
}

----------------------------------------------------------------------
-- Tiny animation controller: one looping "base" animation + one-shot gestures
----------------------------------------------------------------------
local function newAnimController(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	local ctl = { current = nil }

	local function get(name)
		if tracks[name] == nil then
			local a = Instance.new("Animation")
			a.AnimationId = ANIM[name]
			local ok, t = pcall(function() return animator:LoadAnimation(a) end)
			if ok and t then
				t.Priority = PRIORITY[name] or Enum.AnimationPriority.Action
				tracks[name] = t
			else
				tracks[name] = false
			end
		end
		return tracks[name] or nil
	end

	function ctl.loop(name, speed)
		local t = get(name)
		if not t then return end
		if ctl.current ~= name then
			local old = ctl.current and get(ctl.current)
			if old then old:Stop(0.25) end
			t.Looped = true
			t:Play(0.25)
			ctl.current = name
		end
		if speed then t:AdjustSpeed(speed) end
	end

	function ctl.once(name, duration)
		local t = get(name)
		if not t then return nil end
		t.Looped = duration ~= nil
		t:Play(0.15)
		if duration then
			task.delay(duration, function() t:Stop(0.4) end)
		end
		return t
	end

	return ctl
end

local function nearestPlayer(position, radius)
	local best, bestDist = nil, radius
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - position).Magnitude
			if d < bestDist then best, bestDist = root, d end
		end
	end
	return best, bestDist
end

----------------------------------------------------------------------
-- Quest NPCs: idle, turn to face nearby players, personality gestures
----------------------------------------------------------------------
local npcGestures = {
	Morty = { "wave", "point" },
	Vex = { "laugh", "laugh", "wave" },
	Gourd = { "dance", "cheer", "wave" },
	Fern = { "wave", "point" },
	Bog = { "wave", "laugh" },
	Bones = { "point", "cheer" },
}

local function npcLife(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local id = model:GetAttribute("NpcId")
	local anim = newAnimController(hum)
	anim.loop("idle")
	local home = root.CFrame
	local nextGesture = os.clock() + math.random(3, 7)
	local greeted = {}

	task.spawn(function()
		while model.Parent do
			task.wait(0.1)
			local target = nearestPlayer(root.Position, 22)
			local desired
			if target then
				local look=V(target.Position.X, root.Position.Y, target.Position.Z)
				desired = (look-root.Position).Magnitude > 0.05 and CFrame.lookAt(root.Position, look) or home
			else
				desired = home
			end
			root.CFrame = root.CFrame:Lerp(desired, 0.12)

			-- wave the first time someone walks up, then gesture now and then while they stay
			if target then
				local player = Players:GetPlayerFromCharacter(target.Parent)
				if player and not greeted[player] then
					greeted[player] = true
					anim.once("wave")
					nextGesture = os.clock() + math.random(6, 10)
				end
			end
			if os.clock() > nextGesture then
				if target then
					local list = npcGestures[id] or { "wave" }
					local g = list[math.random(1, #list)]
					anim.once(g, g == "dance" and 4 or nil)
				end
				nextGesture = os.clock() + math.random(7, 13)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) greeted[p] = nil end)
end

for _, m in ipairs(CollectionService:GetTagged("QuestNPC")) do
	task.spawn(npcLife, m)
end
CollectionService:GetInstanceAddedSignal("QuestNPC"):Connect(npcLife)

