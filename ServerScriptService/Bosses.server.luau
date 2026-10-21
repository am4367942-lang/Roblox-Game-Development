-- Bosses: one rises every few minutes near the players. Each area's boss is stronger.
-- Players damage bosses with their tools (Main calls ServerStorage.BossHit).
-- Rewards are paid through Main's ServerStorage.BossReward hook.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local V, CF = Vector3.new, CFrame.new
local rad = math.rad

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BossStateRE = Remotes:WaitForChild("BossState", 60)
local NotifyRE = Remotes:WaitForChild("Notify", 60)
local rewardFn = ServerStorage:WaitForChild("BossReward", 60)
if not (BossStateRE and NotifyRE and rewardFn) then
	warn("[Bosses] Main's boss hooks are missing; bosses disabled")
	return
end

local ANIM = {
	idle = "rbxassetid://507766388", walk = "rbxassetid://913402848", run = "rbxassetid://913376220",
	swing = "rbxassetid://522635514", lunge = "rbxassetid://522638767", roar = "rbxassetid://507770677",
	laugh = "rbxassetid://507770818", point = "rbxassetid://507770453", fall = "rbxassetid://507767968",
}
local PRIORITY = { idle = Enum.AnimationPriority.Idle, walk = Enum.AnimationPriority.Movement, run = Enum.AnimationPriority.Movement }

local folder = workspace:FindFirstChild("Bosses") or Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace
folder:ClearAllChildren()

local active = nil      -- the boss currently alive (only one at a time)
local defeat            -- forward declaration

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function newAnimController(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks, ctl = {}, { current = nil }
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
			if old then old:Stop(0.3) end
			t.Looped = true
			t:Play(0.3)
			ctl.current = name
		end
		if speed then t:AdjustSpeed(speed) end
	end
	function ctl.once(name, speed)
		local t = get(name)
		if not t then return nil end
		t.Looped = false
		t:Play(0.15)
		if speed then t:AdjustSpeed(speed) end
		return t
	end
	function ctl.stopAll()
		for _, t in pairs(tracks) do if t then t:Stop(0.3) end end
		ctl.current = nil
	end
	return ctl
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.IgnoreWater = false
local function refreshGroundFilter()
	local list = { workspace.Terrain }
	local gy = workspace:FindFirstChild("Graveyard")
	local ground = gy and gy:FindFirstChild("GraveyardGround")
	if ground then table.insert(list, ground) end
	groundParams.FilterDescendantsInstances = list
end
refreshGroundFilter()
local function groundY(x, z)
	if active and active.def.floorY then return active.def.floorY end
	local r = workspace:Raycast(V(x, 300, z), V(0, -600, 0), groundParams)
	return r and r.Position.Y or 0
end

local function effectPart(name, shape, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Name = name; p.Shape = shape or Enum.PartType.Block; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = Enum.Material.Neon; p.Transparency = transparency or 0
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Parent = folder
	return p
end

local function burst(position, color, count, size, speed)
	local p = effectPart("Burst", nil, V(1, 1, 1), CF(position), color, 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size or 1.2, 0)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new((speed or 14) * 0.5, speed or 14)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = p
	e:Emit(count or 30)
	Debris:AddItem(p, 2)
end

local function dust(position, radius)
	local p = effectPart("Dust", nil, V(1, 1, 1), CF(position), Color3.new(1, 1, 1), 1)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 130, 120))
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Size = NumberSequence.new(radius * 0.25, radius * 0.6)
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(radius * 0.6, radius * 1.1)
	e.SpreadAngle = Vector2.new(80, 180)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	e:Emit(40)
	Debris:AddItem(p, 2.5)
end

-- expanding/fading ring on the ground
local function ring(center, fromRadius, toRadius, color, duration, startTransparency)
	local r = effectPart("Ring", Enum.PartType.Cylinder, V(0.3, fromRadius * 2, fromRadius * 2), CF(center) * CFrame.Angles(0, 0, rad(90)), color, startTransparency or 0.3)
	TweenService:Create(r, TweenInfo.new(duration), { Size = V(0.3, toRadius * 2, toRadius * 2), Transparency = 1 }):Play()
	Debris:AddItem(r, duration + 0.1)
	return r
end

local function playersInArena(b, extra)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local flat = V(root.Position.X - b.center.X, 0, root.Position.Z - b.center.Z)
			if flat.Magnitude <= b.def.radius + (extra or 14) and math.abs(root.Position.Y - groundY(root.Position.X, root.Position.Z)) < 22 then
				table.insert(list, { player = player, root = root, hum = hum })
			end
		end
	end
	return list
end

local function hurtPlayersNear(b, position, radius, damage)
	if b.dead then return end
	for _, t in ipairs(playersInArena(b, 40)) do
		local flat = V(t.root.Position.X - position.X, 0, t.root.Position.Z - position.Z)
		if flat.Magnitude <= radius and math.abs(t.root.Position.Y - position.Y) < 14 then
			t.hum:TakeDamage(damage)
		end
	end
end

local function broadcast(b, player)
	local payload
	if b and not b.dead then
		payload = {
			active = true, name = b.def.name, area = (Config.Zones[b.def.zone] and Config.Zones[b.def.zone].label) or b.def.zone,
			zone=b.def.zone,center=b.center,radius=b.def.radius, tier = b.def.tier, hp = math.max(0, math.floor(b.hp)), maxHp = b.def.hp, enraged = b.enraged,
		}
	else
		payload = { active = false }
	end
	local function sendTo(p)
 local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 local near=b and not b.dead and root and (Vector3.new(root.Position.X,0,root.Position.Z)-Vector3.new(b.center.X,0,b.center.Z)).Magnitude<=b.def.radius+12 and math.abs(root.Position.Y-b.root.Position.Y)<35
 BossStateRE:FireClient(p,near and payload or {active=false})
 end
 if player then sendTo(player) else for _,p in ipairs(Players:GetPlayers()) do sendTo(p) end end
end
Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	broadcast(active, player)
end)

----------------------------------------------------------------------
-- Costumes (offsets are in unscaled studs; `w` scales them to the boss size)
----------------------------------------------------------------------
local function makeWearer(model, s)
	return function(attach, name, shape, size, offset, color, material, transparency)
		local p = Instance.new("Part")
		p.Name = name; p.Size = size * s; p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic; p.Transparency = transparency or 0
		if shape == "egg" then
			local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
		elseif shape then
			p.Shape = shape
		end
		p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = attach.CFrame * CF(offset.Position * s) * (offset - offset.Position)
		p.Parent = model
		local wc = Instance.new("WeldConstraint"); wc.Part0 = attach; wc.Part1 = p; wc.Parent = p
		return p
	end
end
local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness; l.Parent = p
end
local UP = CFrame.Angles(0, 0, rad(90))
local NEON, METAL, FABRIC, WOOD, SLATE = Enum.Material.Neon, Enum.Material.Metal, Enum.Material.Fabric, Enum.Material.Wood, Enum.Material.Slate
local gold, iron = Color3.fromRGB(226, 186, 92), Color3.fromRGB(40, 38, 50)

local looks = {
	GraveWarden = { skin = Color3.fromRGB(150, 155, 165), torso = Color3.fromRGB(64, 56, 76), legs = Color3.fromRGB(44, 40, 54), accent = Color3.fromRGB(110, 255, 230) },
	HarvestKing = { skin = Color3.fromRGB(230, 190, 140), torso = Color3.fromRGB(150, 70, 30), legs = Color3.fromRGB(70, 50, 40), accent = Color3.fromRGB(255, 170, 50) },
	HollowTreant = { skin = Color3.fromRGB(110, 80, 60), torso = Color3.fromRGB(92, 66, 48), legs = Color3.fromRGB(80, 58, 42), accent = Color3.fromRGB(120, 255, 140) },
	MireHag = { skin = Color3.fromRGB(120, 160, 110), torso = Color3.fromRGB(50, 72, 60), legs = Color3.fromRGB(40, 52, 46), accent = Color3.fromRGB(190, 255, 110) },
	LichKing = { skin = Color3.fromRGB(232, 226, 206), torso = Color3.fromRGB(70, 40, 110), legs = Color3.fromRGB(56, 32, 90), accent = Color3.fromRGB(200, 120, 255) },
}

looks.CavernKeeper={skin=Color3.fromRGB(146,173,189),torso=Color3.fromRGB(52,70,96),legs=Color3.fromRGB(39,49,68),accent=Color3.fromRGB(148,214,255)}
local costumes = {}
costumes.GraveWarden = function(w, m, hs, accent)
	local head, torso = m.Head, m.UpperTorso
	w(head, "Hood", "egg", V(hs.X * 1.4, hs.Y * 1.45, hs.Z * 1.55), CF(0, hs.Y * 0.12, hs.Z * 0.14), Color3.fromRGB(46, 40, 58), FABRIC)
	glow(w(head, "Eyes", nil, V(hs.X * 0.55, hs.Y * 0.12, 0.1), CF(0, hs.Y * 0.05, -hs.Z * 0.62), accent, NEON), accent, 12, 1)
	w(torso, "Cape", nil, V(2.2, 3.4, 0.2), CF(0, -0.9, 0.62), Color3.fromRGB(40, 34, 52), FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		w(torso, "ShoulderStone", "egg", V(1.0, 0.75, 1.1), CF(side * 1.15, 0.55, 0), Color3.fromRGB(120, 118, 132), SLATE)
	end
	w(torso, "Chain", nil, V(2.5, 0.18, 0.18), CF(0, 0.1, -0.56) * CFrame.Angles(0, 0, rad(35)), Color3.fromRGB(120, 120, 135), METAL)
	w(m.RightHand, "ShovelHandle", nil, V(0.25, 5.2, 0.25), CF(0, -1.6, -0.3), Color3.fromRGB(110, 80, 56), WOOD)
	w(m.RightHand, "ShovelBlade", nil, V(1.3, 1.6, 0.15), CF(0, -4.6, -0.3), Color3.fromRGB(150, 150, 168), METAL)
	w(m.RightHand, "ShovelEdge", nil, V(1.35, 0.15, 0.2), CF(0, -5.4, -0.3), accent, NEON)
	glow(w(m.LeftHand, "Lantern", nil, V(0.7, 0.9, 0.7), CF(0, -0.8, -0.2), accent, NEON, 0.1), accent, 20, 1.6)
	w(m.LeftHand, "LanternCap", nil, V(0.85, 0.15, 0.85), CF(0, -0.3, -0.2), iron, METAL)
end
costumes.HarvestKing = function(w, m, hs, accent)
	local head, torso = m.Head, m.UpperTorso
	w(head, "PumpkinHead", "egg", V(hs.X * 2.4, hs.Y * 2.1, hs.Z * 2.4), CF(0, hs.Y * 0.15, 0), Color3.fromRGB(240, 120, 25), Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		w(head, "Eyes", nil, V(0.45, 0.45, 0.1), CF(side * hs.X * 0.42, hs.Y * 0.4, -hs.Z * 1.18) * CFrame.Angles(0, 0, rad(45)), Color3.fromRGB(255, 220, 80), NEON)
	end
	glow(w(head, "Mouth", nil, V(hs.X * 1.2, 0.28, 0.1), CF(0, -hs.Y * 0.25, -hs.Z * 1.16), Color3.fromRGB(255, 220, 80), NEON), accent, 16, 1.4)
	w(head, "Stem", Enum.PartType.Cylinder, V(0.6, 0.45, 0.45), CF(0, hs.Y * 1.2, 0) * UP, Color3.fromRGB(70, 110, 50), WOOD)
	w(head, "CrownBand", Enum.PartType.Cylinder, V(0.3, hs.X * 1.5, hs.X * 1.5), CF(0, hs.Y * 1.05, 0) * UP, gold, METAL)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		w(head, "CrownSpike", nil, V(0.22, 0.55, 0.22), CF(math.cos(a) * hs.X * 0.7, hs.Y * 1.35, math.sin(a) * hs.X * 0.7), gold, METAL)
	end
	w(torso, "Cape", nil, V(2.3, 3.6, 0.2), CF(0, -0.9, 0.62), Color3.fromRGB(150, 30, 40), FABRIC)
	for _, arm in ipairs({ m.RightUpperArm, m.LeftUpperArm }) do
		w(arm, "Vines", "egg", V(1.05, 1.3, 1.05), CF(0, 0, 0), Color3.fromRGB(70, 140, 60), Enum.Material.Grass)
	end
	w(m.RightHand, "ScythePole", nil, V(0.25, 6.2, 0.25), CF(0, 0.6, -0.3), Color3.fromRGB(70, 50, 36), WOOD)
	for i, seg in ipairs({ { 1.2, 0, 3.6, 0 }, { 1.1, 1.0, 3.45, -25 }, { 0.9, 1.8, 3.0, -55 } }) do
		w(m.RightHand, "ScytheBlade" .. i, nil, V(seg[1], 0.3, 0.12), CF(seg[2] + 0.5, seg[3], -0.3) * CFrame.Angles(0, 0, rad(seg[4])), Color3.fromRGB(190, 190, 205), METAL)
	end
	w(m.RightHand, "ScytheEdge", nil, V(2.2, 0.1, 0.15), CF(1.4, 3.15, -0.3) * CFrame.Angles(0, 0, rad(-25)), accent, NEON)
end
costumes.HollowTreant = function(w, m, hs, accent)
	local head, torso = m.Head, m.UpperTorso
	local bark = Color3.fromRGB(96, 70, 52)
	w(head, "Stump", Enum.PartType.Cylinder, V(hs.Y * 1.7, hs.X * 1.5, hs.X * 1.5), CF(0, hs.Y * 0.2, 0) * UP, bark, WOOD)
	w(head, "Hollow", "egg", V(hs.X * 0.7, hs.Y * 0.45, 0.2), CF(0, -hs.Y * 0.25, -hs.X * 0.74), Color3.fromRGB(20, 14, 12))
	for _, side in ipairs({ -1, 1 }) do
		glow(w(head, "Eyes", "egg", V(0.32, 0.4, 0.15), CF(side * hs.X * 0.3, hs.Y * 0.3, -hs.X * 0.75), accent, NEON), accent, 10, 1)
		local br = w(head, "Antler", nil, V(0.35, 2.6, 0.35), CF(side * hs.X * 0.6, hs.Y * 1.6, 0) * CFrame.Angles(0, 0, rad(side * -30)), bark, WOOD)
		w(head, "AntlerTwig", nil, V(0.22, 1.2, 0.22), CF(side * hs.X * 1.2, hs.Y * 2.2, 0) * CFrame.Angles(0, 0, rad(side * 35)), bark, WOOD)
		w(head, "Leaves", "egg", V(1.4, 1.0, 1.4), CF(side * hs.X * 1.5, hs.Y * 2.6, 0), Color3.fromRGB(46, 130, 70), Enum.Material.Grass)
		w(torso, "ShoulderLeaves", "egg", V(1.6, 1.0, 1.5), CF(side * 1.15, 0.75, 0), Color3.fromRGB(40, 112, 64), Enum.Material.Grass)
	end
	w(torso, "Moss", "egg", V(1.6, 0.9, 0.3), CF(0.2, -0.2, -0.55), Color3.fromRGB(70, 140, 70), Enum.Material.Grass)
	w(torso, "BarkPlate", nil, V(2.1, 1.7, 1.1), CF(0, 0, 0), bark, WOOD)
	w(m.RightHand, "Club", Enum.PartType.Cylinder, V(4.6, 1.1, 1.1), CF(0, -2.1, -0.3) * UP, Color3.fromRGB(84, 60, 44), WOOD)
	w(m.RightHand, "ClubKnot", "egg", V(1.3, 1.0, 1.3), CF(0, -4.2, -0.3), Color3.fromRGB(70, 50, 36), WOOD)
end
costumes.MireHag = function(w, m, hs, accent)
	local head, torso = m.Head, m.UpperTorso
	w(head, "Hood", "egg", V(hs.X * 1.45, hs.Y * 1.5, hs.Z * 1.6), CF(0, hs.Y * 0.15, hs.Z * 0.15), Color3.fromRGB(40, 60, 46), FABRIC)
	w(head, "Nose", "egg", V(0.25, 0.25, 0.7), CF(0, -hs.Y * 0.05, -hs.Z * 0.75) * CFrame.Angles(rad(-20), 0, 0), Color3.fromRGB(110, 150, 100))
	for _, side in ipairs({ -1, 1 }) do
		glow(w(head, "Eyes", "egg", V(0.3, 0.22, 0.12), CF(side * hs.X * 0.22, hs.Y * 0.15, -hs.Z * 0.6), Color3.fromRGB(255, 230, 80), NEON), Color3.fromRGB(255, 230, 80), 8, 0.8)
		for k = 1, 3 do
			w(head, "Hair", nil, V(0.18, 2.2, 0.14), CF(side * (hs.X * 0.35 + k * 0.12), -hs.Y * 0.9, -hs.Z * 0.3 + k * 0.1), Color3.fromRGB(70, 80, 70), FABRIC)
		end
	end
	w(torso, "Drape", nil, V(2.4, 3.8, 1.4), CF(0, -1.0, 0.05), Color3.fromRGB(46, 66, 52), FABRIC)
	w(torso, "Moss", "egg", V(2.4, 0.6, 1.4), CF(0, 0.75, 0), Color3.fromRGB(90, 140, 80), Enum.Material.Grass)
	w(m.RightHand, "Staff", nil, V(0.25, 6.4, 0.25), CF(0, 0.8, -0.3), Color3.fromRGB(80, 64, 50), WOOD)
	w(m.RightHand, "StaffSkull", "egg", V(0.8, 0.75, 0.75), CF(0, 4.0, -0.3), Color3.fromRGB(226, 220, 200))
	glow(w(m.RightHand, "StaffOrb", Enum.PartType.Ball, V(0.7, 0.7, 0.7), CF(0, 4.6, -0.3), accent, NEON), accent, 20, 1.8)
end
costumes.LichKing = function(w, m, hs, accent)
	local head, torso = m.Head, m.UpperTorso
	for _, side in ipairs({ -1, 1 }) do
		glow(w(head, "Eyes", "egg", V(0.3, 0.3, 0.12), CF(side * hs.X * 0.22, hs.Y * 0.1, -hs.Z * 0.6), accent, NEON), accent, 10, 1.2)
		w(torso, "Pauldron", "egg", V(1.2, 0.8, 1.3), CF(side * 1.2, 0.6, 0), gold, METAL)
	end
	w(head, "Jaw", nil, V(hs.X * 0.6, hs.Y * 0.2, hs.Z * 0.4), CF(0, -hs.Y * 0.45, -hs.Z * 0.2), Color3.fromRGB(220, 214, 194))
	w(head, "CrownBand", Enum.PartType.Cylinder, V(0.3, hs.X * 1.15, hs.X * 1.15), CF(0, hs.Y * 0.6, 0) * UP, gold, METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		w(head, "CrownSpike", nil, V(0.2, 0.7, 0.2), CF(math.cos(a) * hs.X * 0.55, hs.Y * 0.95, math.sin(a) * hs.X * 0.55), gold, METAL)
	end
	w(head, "CrownGem", "egg", V(0.3, 0.3, 0.15), CF(0, hs.Y * 0.62, -hs.X * 0.58), accent, NEON)
	w(torso, "Collar", nil, V(2.4, 1.0, 0.25), CF(0, 0.9, 0.5) * CFrame.Angles(rad(-20), 0, 0), Color3.fromRGB(56, 30, 92), FABRIC)
	w(torso, "Cape", nil, V(2.4, 3.8, 0.2), CF(0, -1.0, 0.62), Color3.fromRGB(56, 30, 92), FABRIC)
	w(m.LowerTorso, "Robe", nil, V(2.6, 3.4, 1.8), CF(0, -1.6, 0), Color3.fromRGB(70, 40, 110), FABRIC)
	w(m.LowerTorso, "RobeTrim", nil, V(2.7, 0.3, 1.9), CF(0, -3.2, 0), gold, METAL)
	w(m.RightHand, "Staff", nil, V(0.28, 6.6, 0.28), CF(0, 0.9, -0.3), Color3.fromRGB(40, 30, 50), WOOD)
	w(m.RightHand, "StaffHead", Enum.PartType.Cylinder, V(0.3, 1.2, 1.2), CF(0, 4.25, -0.3) * CFrame.Angles(0, rad(90), 0), gold, METAL)
	glow(w(m.RightHand, "StaffOrb", Enum.PartType.Ball, V(0.8, 0.8, 0.8), CF(0, 4.25, -0.3), accent, NEON), accent, 24, 2)
end

----------------------------------------------------------------------
-- Build a boss
----------------------------------------------------------------------
costumes.CavernKeeper=function(w,m,hs,accent)
	costumes.GraveWarden(w,m,hs,accent)
	for i=-1,1 do
		w(m.Head,"CrystalCrown",nil,V(.22,.85,.22),CF(i*.45,hs.Y*.9,0)*CFrame.Angles(0,0,rad(i*18)),accent,NEON)
	end
	for _,side in ipairs({-1,1}) do
		w(m.UpperTorso,"CrystalPauldrons","egg",V(.9,.65,.9),CF(side*1.15,.7,0),Color3.fromRGB(93,125,151),SLATE)
		w(m.UpperTorso,"CrystalSeam",nil,V(.15,1.6,.12),CF(side*.6,-.15,-.65)*CFrame.Angles(0,0,rad(side*22)),accent,NEON)
	end
end

local function buildBoss(def)
	local look = looks[def.id] or looks.GraveWarden
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = look.skin; d.TorsoColor = look.torso; d.LeftArmColor = look.torso; d.RightArmColor = look.torso
	d.LeftLegColor = look.legs; d.RightLegColor = look.legs
	local model = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	model.Name = "Boss_" .. def.id
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local root = model:FindFirstChild("HumanoidRootPart")
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = (p == root)
			p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		end
	end
	model:PivotTo(CF(def.center[1], 600, def.center[2]))
	model.Parent = folder
	pcall(function() model:ScaleTo(def.scale) end)

	local s = def.scale
	local w = makeWearer(model, s)
	local hs = model.Head.Size / s
	local ok, err = pcall(costumes[def.id] or costumes.GraveWarden, w, model, hs, look.accent)
	if not ok then warn("[Bosses] costume error: " .. tostring(err)) end

	-- name plate with a health bar
	local bb = Instance.new("BillboardGui")
	bb.Name = "BossPlate"; bb.Size = UDim2.fromOffset(280, 58); bb.StudsOffsetWorldSpace = V(0, 3 * s, 0)
	bb.MaxDistance = 220; bb.AlwaysOnTop = true; bb.Adornee = model.Head; bb.Parent = model.Head
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1; title.Size = UDim2.new(1, 0, 0, 30); title.Font = Enum.Font.GothamBlack; title.TextScaled = true
	title.Text = def.name .. "  " .. string.rep("*", def.tier); title.TextColor3 = look.accent; title.TextStrokeTransparency = 0.2; title.Parent = bb
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 16); back.Position = UDim2.new(0, 0, 0, 36); back.BackgroundColor3 = Color3.fromRGB(20, 12, 24); back.BorderSizePixel = 0; back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Name = "Fill"; fill.Size = UDim2.fromScale(1, 1); fill.BackgroundColor3 = Color3.fromRGB(255, 70, 90); fill.BorderSizePixel = 0; fill.Parent = back

	-- how high the root sits above the feet
	local bbCF, bbSize = model:GetBoundingBox()
	local rootHeight = root.Position.Y - (bbCF.Position.Y - bbSize.Y / 2)
	return model, hum, root, rootHeight, fill, look.accent
end

----------------------------------------------------------------------
-- Player hits on the boss (called by Main through ServerStorage.BossHit)
----------------------------------------------------------------------
local function hitFeedback(b, damage)
	b.hpBar.Size = UDim2.fromScale(math.clamp(b.hp / b.def.hp, 0, 1), 1)
	local now = os.clock()
	if now - (b.lastNumber or 0) > 0.15 then
		b.lastNumber = now
		local at = b.root.Position + V(math.random(-20, 20) / 10 * b.s, 2 * b.s, math.random(-20, 20) / 10 * b.s)
		local anchor = effectPart("DamageNumber", nil, V(0.2, 0.2, 0.2), CF(at), Color3.new(1, 1, 1), 1)
		local gui = Instance.new("BillboardGui"); gui.Size = UDim2.fromOffset(90, 36); gui.AlwaysOnTop = true; gui.MaxDistance = 160; gui.Parent = anchor
		local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Font = Enum.Font.GothamBlack; t.TextScaled = true
		t.Text = "-" .. math.floor(damage); t.TextColor3 = Color3.fromRGB(255, 230, 120); t.TextStrokeTransparency = 0.2; t.Parent = gui
		TweenService:Create(gui, TweenInfo.new(0.8), { StudsOffset = V(0, 4, 0) }):Play()
		TweenService:Create(t, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(anchor, 0.9)
		burst(b.root.Position + V(0, b.s, 0), b.accent, 8, 0.8, 10)
	end
	if now - (b.lastBroadcast or 0) > 0.25 then
		b.lastBroadcast = now
		broadcast(b)
	end
end

local hitFn = ServerStorage:FindFirstChild("BossHit") or Instance.new("BindableFunction")
hitFn.Name = "BossHit"
hitFn.Parent = ServerStorage
hitFn.OnInvoke = function(player, origin, aim, range, arc, damage)
	local b = active
	if not b or b.dead or b.rising or not b.root.Parent then return false end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if typeof(origin) ~= "Vector3" or typeof(aim) ~= "Vector3" then return false end
	if math.abs(origin.Y - groundY(origin.X, origin.Z)) > 22 then return false end
	local offset = b.root.Position - origin
	local flat = V(offset.X, 0, offset.Z)
	if flat.Magnitude > (tonumber(range) or 0) + b.radius then return false end
	arc = tonumber(arc) or 0
	if arc < 360 and flat.Magnitude > b.radius and aim.Magnitude > 0.01 then
		if flat.Unit:Dot(aim.Unit) < math.cos(rad(arc / 2)) - 0.2 then return false end
	end
	damage = math.clamp(tonumber(damage) or 0, 0, 100000)
	if damage <= 0 then return false end
	b.hp -= damage
	b.damageBy[player] = (b.damageBy[player] or 0) + damage
	hitFeedback(b, damage)
	if b.hp <= 0 then task.spawn(defeat, b) end
	return true
end

----------------------------------------------------------------------
-- Attacks
----------------------------------------------------------------------
local function faceToward(b, position)
	local p = b.root.Position
	local dir = V(position.X - p.X, 0, position.Z - p.Z)
	if dir.Magnitude > 0.1 then b.root.CFrame = CFrame.lookAt(p, p + dir.Unit) end
end

local function swipe(b, target)
	b.action = "swipe"
	faceToward(b, target.root.Position)
	b.anim.once((math.random() < 0.5) and "swing" or "lunge", 0.9)
	task.wait(0.45)
	if b.dead then return end
	local reach = 4 + 1.8 * b.s
	local look = V(b.root.CFrame.LookVector.X, 0, b.root.CFrame.LookVector.Z).Unit
	for _, t in ipairs(playersInArena(b, 20)) do
		local flat = V(t.root.Position.X - b.root.Position.X, 0, t.root.Position.Z - b.root.Position.Z)
		if flat.Magnitude <= reach and (flat.Magnitude < 2 or flat.Unit:Dot(look) > 0.2) then
			t.hum:TakeDamage(b.def.damage)
		end
	end
	local front = b.root.Position + look * reach * 0.6
	ring(V(front.X, groundY(front.X, front.Z) + 0.3, front.Z), 1, reach * 0.7, b.accent, 0.3, 0.4)
	b.nextSwipe = os.clock() + 2.0 * b.cd
	task.wait(0.5)
	b.action = nil
end

local function slam(b, target)
	b.action = "slam"
	local radius = 9 + 2 * b.def.tier
	local tp = target.root.Position
	local landing = V(tp.X, groundY(tp.X, tp.Z), tp.Z)
	local fromC = V(landing.X - b.center.X, 0, landing.Z - b.center.Z)
	if fromC.Magnitude > b.def.radius then
		local c = V(b.center.X, 0, b.center.Z) + fromC.Unit * b.def.radius
		landing = V(c.X, groundY(c.X, c.Z), c.Z)
	end
	faceToward(b, landing)
	b.anim.once("roar")
	-- telegraph: a red circle grows where the boss will land
	local warn = effectPart("SlamWarning", Enum.PartType.Cylinder, V(0.25, 1, 1), CF(landing + V(0, 0.25, 0)) * CFrame.Angles(0, 0, rad(90)), Color3.fromRGB(255, 60, 60), 0.55)
	TweenService:Create(warn, TweenInfo.new(1.3), { Size = V(0.25, radius * 2, radius * 2) }):Play()
	task.wait(1.3)
	if b.dead then warn:Destroy() return end
	-- leap in an arc
	local start = b.root.Position
	local finish = landing + V(0, b.rootHeight, 0)
	local peak = b.def.floorY and 3 or (10 + 3 * b.s)
	b.anim.once("lunge", 0.8)
	local t0 = os.clock()
	while true do
		local a = math.min((os.clock() - t0) / 0.55, 1)
		local pos = start:Lerp(finish, a) + V(0, math.sin(a * math.pi) * peak, 0)
		b.root.CFrame = CFrame.lookAt(pos, pos + V(b.root.CFrame.LookVector.X, 0, b.root.CFrame.LookVector.Z))
		if a >= 1 then break end
		task.wait()
	end
	warn:Destroy()
	dust(landing + V(0, 0.5, 0), radius)
	ring(landing + V(0, 0.4, 0), 2, radius, Color3.fromRGB(255, 240, 220), 0.45, 0.2)
	ring(landing + V(0, 0.5, 0), 1, radius * 0.7, b.accent, 0.35, 0.1)
	hurtPlayersNear(b, landing, radius, b.def.damage * 1.4)
	b.nextSlam = os.clock() + 9 * b.cd
	task.wait(0.6)
	b.action = nil
end

local function bolt(b, from, to, damage)
	local orb = effectPart("SoulBolt", Enum.PartType.Ball, V(1.6, 1.6, 1.6), CF(from), b.accent, 0.1)
	glow(orb, b.accent, 10, 1.4)
	local tween = TweenService:Create(orb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CF(to) })
	tween:Play()
	tween.Completed:Connect(function()
		burst(to, b.accent, 20, 1.3, 12)
		ring(to + V(0, 0.3, 0), 1, 6, b.accent, 0.35, 0.3)
		hurtPlayersNear(b, to, 6, damage)
		orb:Destroy()
	end)
end

local function bolts(b)
	b.action = "bolts"
	b.anim.once("point")
	task.wait(0.45)
	local targets = playersInArena(b, 14)
	local hand = b.model:FindFirstChild("RightHand")
	local from = hand and hand.Position or (b.root.Position + V(0, 2 * b.s, 0))
	for i = 1, b.def.tier + 1 do
		local t = targets[(i - 1) % math.max(#targets, 1) + 1]
		if t then
			local p = t.root.Position + V(math.random(-4, 4), 0, math.random(-4, 4))
			bolt(b, from, V(p.X, groundY(p.X, p.Z) + 1, p.Z), b.def.damage * 0.7)
			task.wait(0.15)
		end
	end
	b.nextBolts = os.clock() + 6 * b.cd
	task.wait(0.6)
	b.action = nil
end

local function storm(b)
	b.action = "storm"
	b.anim.once("roar")
	local c = b.root.Position
	ring(V(c.X, groundY(c.X, c.Z) + 0.3, c.Z), 2, 8, Color3.fromRGB(255, 60, 60), 1.0, 0.4)
	task.wait(1.0)
	if b.dead then return end
	for i = 0, 11 do
		local a = i * math.pi / 6
		local to = V(c.X + math.cos(a) * 26, 0, c.Z + math.sin(a) * 26)
		bolt(b, c + V(0, 2 * b.s, 0), V(to.X, groundY(to.X, to.Z) + 1, to.Z), b.def.damage * 0.8)
	end
	b.nextStorm = os.clock() + 14 * b.cd
	task.wait(0.8)
	b.action = nil
end

local function enrage(b)
	b.enraged = true
	b.cd = 0.7
	b.anim.once("roar")
	for _, p in ipairs(b.model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Eyes" then p.Color = Color3.fromRGB(255, 40, 40) end
	end
	burst(b.root.Position + V(0, 2 * b.s, 0), Color3.fromRGB(255, 60, 60), 40, 1.6, 18)
	NotifyRE:FireAllClients(b.def.name .. " is ENRAGED!", "warn")
	broadcast(b)
end

----------------------------------------------------------------------
-- Death / retreat
----------------------------------------------------------------------
local function sinkAway(b, duration)
	b.anim.stopAll()
	b.anim.once("fall")
	local start = b.root.CFrame
	local parts = {}
	for _, p in ipairs(b.model:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 then table.insert(parts, { p, p.Transparency }) end
	end
	local t0 = os.clock()
	while os.clock() - t0 < duration do
		local a = (os.clock() - t0) / duration
		b.root.CFrame = start * CF(0, -a * b.rootHeight * 1.6, 0)
		for _, e in ipairs(parts) do e[1].Transparency = e[2] + (1 - e[2]) * a end
		task.wait()
	end
end

defeat = function(b)
	if b.dead then return end
	b.dead = true
	b.hp = 0
	broadcast(nil)
	NotifyRE:FireAllClients(b.def.name .. " has been defeated!", "good")
	burst(b.root.Position + V(0, 2 * b.s, 0), b.accent, 70, 2, 24)
	for player, dealt in pairs(b.damageBy) do
		if player.Parent then
			local share = math.clamp(dealt / b.def.hp, 0, 1)
			local mult = 0.4 + 0.6 * math.min(1, share * 2)
			local essence = math.floor(b.def.reward.essence * mult)
			local souls = math.floor(b.def.reward.souls * mult)
			pcall(function() rewardFn:Invoke(player, essence, souls, b.def.name) end)
		end
	end
	sinkAway(b, 2.5)
	b.model:Destroy()
	if active == b then active = nil end
end

----------------------------------------------------------------------
-- Spawn + brain
----------------------------------------------------------------------
local function runBoss(def)
	local model, hum, root, rootHeight, hpBar, accent = buildBoss(def)
	local center = V(def.center[1], 0, def.center[2])
	local b = {
		def = def, model = model, root = root, rootHeight = rootHeight, hpBar = hpBar, accent = accent,
		s = def.scale, radius = 1.4 * def.scale, center = center, hp = def.hp, damageBy = {},
		anim = newAnimController(hum), cd = 1, enraged = false, dead = false, rising = true, action = nil,
		nextSwipe = 0, nextSlam = os.clock() + 4, nextBolts = os.clock() + 6, nextStorm = os.clock() + 10,
		expires = os.clock() + Config.BossLifetime,
	}
	active = b

	-- rise out of the ground
	local gy = groundY(center.X, center.Z)
	local top = V(center.X, gy + rootHeight, center.Z)
	local bottom = top - V(0, rootHeight * 2.2, 0)
	root.CFrame = CF(bottom)
	dust(V(center.X, gy + 0.5, center.Z), 12)
	ring(V(center.X, gy + 0.3, center.Z), 2, 16, accent, 1.5, 0.2)
	b.anim.once("roar")
	NotifyRE:FireAllClients(("BOSS: %s has risen in the %s!"):format(def.name, (Config.Zones[def.zone] and Config.Zones[def.zone].label) or def.zone), "warn")
	broadcast(b)
	local t0 = os.clock()
	while os.clock() - t0 < 2.5 do
		local a = (os.clock() - t0) / 2.5
		root.CFrame = CF(bottom:Lerp(top, 1 - (1 - a) ^ 3))
		task.wait()
	end
	b.rising = false
	b.anim.loop("idle")

	local wanderGoal = center
	local nextWander = 0
	local last = os.clock()
	while not b.dead and model.Parent do
		task.wait(1 / 15)
		local now = os.clock()
		local dt = math.min(now - last, 0.2)
		last = now

		if now > b.expires then
			b.dead = true
			broadcast(nil)
			NotifyRE:FireAllClients(def.name .. " retreats into the shadows...", "info")
			sinkAway(b, 2.5)
			model:Destroy()
			break
		end
		if not b.enraged and b.hp <= def.hp * 0.35 then enrage(b) end

		if not b.action then
			local targets = playersInArena(b, 14)
			local target, dist = nil, math.huge
			for _, t in ipairs(targets) do
				local d = (V(t.root.Position.X, 0, t.root.Position.Z) - V(root.Position.X, 0, root.Position.Z)).Magnitude
				if d < dist then target, dist = t, d end
			end
			local reach = 4 + 1.8 * b.s
			local goal
			if target then
				if def.attacks.storm and now >= b.nextStorm and dist < 26 then
					task.spawn(storm, b)
				elseif def.attacks.slam and now >= b.nextSlam and dist < 34 then
					task.spawn(slam, b, target)
				elseif def.attacks.bolts and now >= b.nextBolts and dist > 10 then
					task.spawn(bolts, b)
				elseif dist <= reach and now >= b.nextSwipe then
					task.spawn(swipe, b, target)
				end
				goal = (dist > reach * 0.8) and target.root.Position or nil
				if not goal then faceToward(b, target.root.Position) end
			else
				if now > nextWander then
					local a = math.random() * math.pi * 2
					local r = math.random() * def.radius * 0.6
					wanderGoal = center + V(math.cos(a) * r, 0, math.sin(a) * r)
					nextWander = now + math.random(4, 7)
				end
				goal = wanderGoal
			end

			-- move (anchored root, moved by CFrame so nothing on the map can trap the boss)
			local moved = 0
			if goal and not b.action then
				local pos = root.Position
				local flat = V(goal.X - pos.X, 0, goal.Z - pos.Z)
				if flat.Magnitude > 0.6 then
					local speed = def.speed * (b.enraged and 1.35 or 1) * (target and 1 or 0.45)
					local step = math.min(speed * dt, flat.Magnitude)
					local nxz = V(pos.X, 0, pos.Z) + flat.Unit * step
					local fromC = nxz - center
					if fromC.Magnitude > def.radius then nxz = center + fromC.Unit * def.radius end
					local y = groundY(nxz.X, nxz.Z) + rootHeight
					local newPos = V(nxz.X, y, nxz.Z)
					local look = root.CFrame.LookVector:Lerp(flat.Unit, 0.25)
					root.CFrame = CFrame.lookAt(newPos, newPos + V(look.X, 0, look.Z))
					moved = step / math.max(dt, 0.001)
				end
			end
			if not b.action then
				if moved < 0.5 then
					b.anim.loop("idle")
				elseif moved > 11 then
					b.anim.loop("run", math.clamp(moved / (5 * b.s), 0.4, 1.3))
				else
					b.anim.loop("walk", math.clamp(moved / (3.5 * b.s), 0.4, 1.3))
				end
			end
		end
	end
	if active == b then active = nil end
	broadcast(nil)
end

local function pickBoss()
	local candidates = {}
	for _, def in ipairs(Config.Bosses) do
		local c = V(def.center[1], 0, def.center[2])
		for _, player in ipairs(Players:GetPlayers()) do
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r and (not def.floorY or math.abs(r.Position.Y-def.floorY)<18) and (V(r.Position.X, 0, r.Position.Z) - c).Magnitude < def.radius + 70 then
				table.insert(candidates, def)
				break
			end
		end
	end
	if #candidates == 0 then return Config.BossById.GraveWarden end
	return candidates[math.random(1, #candidates)]
end

-- server-only test hook (clients cannot reach ServerStorage)
local debugSpawn = Instance.new("BindableFunction")
debugSpawn.Name = "BossDebugSpawn"
debugSpawn.Parent = ServerStorage
debugSpawn.OnInvoke = function(id)
	if active then return false end
	local def = Config.BossById[id] or Config.BossById.GraveWarden
	task.spawn(runBoss, def)
	return true
end

task.spawn(function()
	task.wait(Config.BossFirstDelay)
	while true do
		if #Players:GetPlayers() > 0 and not active then
			local ok, err = pcall(runBoss, pickBoss())
			if not ok then warn("[Bosses] boss error: " .. tostring(err)) end
			active = nil
			broadcast(nil)
		end
		task.wait(Config.BossInterval)
	end
end)

print("[Bosses] ready")

task.spawn(function() while true do task.wait(.5);broadcast(active) end end)
