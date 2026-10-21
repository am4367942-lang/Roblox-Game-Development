-- Dresses every Spirit Roost with the Blender roost set (gateway, braziers, fences,
-- featured-ghost pedestals). Imported models named Roost_* are picked up from
-- Workspace or ServerStorage automatically; until then, simple stand-in pedestals
-- keep the featured-ghost display working.
local SS = game:GetService("ServerStorage")
local Look = require(script.Parent.Modules.BlenderLook)
local roosts = workspace:WaitForChild("SpiritRoosts")

local assets = SS:FindFirstChild("BlenderAssets") or Instance.new("Folder")
assets.Name = "BlenderAssets"; assets.Parent = SS
local function collect()
	for _, place in ipairs({ workspace, SS }) do
		for _, m in ipairs(place:GetChildren()) do
			if m:IsA("Model") and m.Name:match("^Roost_") and m.Parent ~= assets then m.Parent = assets end
		end
	end
end
collect()
local function template(name, axis, size)
	local t = assets:FindFirstChild(name)
	if not t then return nil end
	if not t:GetAttribute("Prepared") then
		Look.apply(t); Look.fit(t, axis, size); t:SetAttribute("Prepared", true)
	end
	return t
end

-- local layout (relative to RoostPlatform: +Z is the slot wall, -Z the entrance)
local PLACES = {
	{ "Roost_Gateway", "Y", 10, CFrame.new(0, 0, -10.4) },
	{ "Roost_Brazier", "Y", 4, CFrame.new(-11.6, 0, -9.0) },
	{ "Roost_Brazier", "Y", 4, CFrame.new(11.6, 0, -9.0) },
}
for _, side in ipairs({ -1, 1 }) do
	for k = 0, 3 do
		table.insert(PLACES, { "Roost_Fence", "X", 4, CFrame.new(side * 12.9, 0, -6.5 + k * 4) * CFrame.Angles(0, math.rad(90), 0) })
	end
end
local PEDESTALS = { CFrame.new(-4.9, 0, -7.2), CFrame.new(4.9, 0, -7.2) }

local function standIn(parent, cf)
	local m = Instance.new("Model"); m.Name = "Roost_Pedestal"
	local function p(name, size, off, color, mat, shape)
		local x = Instance.new("Part"); x.Name = name; x.Anchored = true; x.Size = size; x.Color = color; x.Material = mat
		x.Shape = shape or Enum.PartType.Block; x.CFrame = cf * off; x.Parent = m; return x
	end
	local UP = CFrame.Angles(0, 0, math.rad(90))
	p("RoostTrim", Vector3.new(0.6, 2.4, 2.4), CFrame.new(0, 0.3, 0) * UP, Color3.fromRGB(84, 70, 115), Enum.Material.Slate, Enum.PartType.Cylinder)
	p("RoostStone", Vector3.new(1.6, 1.0, 1.0), CFrame.new(0, 1.4, 0) * UP, Color3.fromRGB(128, 118, 158), Enum.Material.Slate, Enum.PartType.Cylinder)
	p("RoostStone", Vector3.new(0.3, 1.8, 1.8), CFrame.new(0, 2.3, 0) * UP, Color3.fromRGB(128, 118, 158), Enum.Material.Slate, Enum.PartType.Cylinder)
	p("SpiritFlame", Vector3.new(0.06, 1.3, 1.3), CFrame.new(0, 2.47, 0) * UP, Color3.fromRGB(90, 255, 229), Enum.Material.Neon, Enum.PartType.Cylinder)
	m.Parent = parent
	return m
end

local function dress(roost)
	if not roost:IsA("Model") then return end
	local platform = roost:FindFirstChild("RoostPlatform")
	if not platform then return end
	local decor = roost:FindFirstChild("BlenderDecor")
	if decor then decor:Destroy() end
	decor = Instance.new("Folder"); decor.Name = "BlenderDecor"; decor.Parent = roost
	local base = platform.CFrame * CFrame.new(0, platform.Size.Y / 2, 0)
	for _, spec in ipairs(PLACES) do
		local t = template(spec[1], spec[2], spec[3])
		if t then
			local c = t:Clone()
			local T = base * spec[4]
			c:PivotTo(CFrame.new(c:GetPivot().Position) * T.Rotation)
			local cf, size = c:GetBoundingBox()
			c:PivotTo(c:GetPivot() + (T.Position - Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)))
			c.Parent = decor
		end
	end
	-- featured-ghost pedestals with an anchor on top for the client to show the owner's team
	for i, off in ipairs(PEDESTALS) do
		local t = template("Roost_Pedestal", "Y", 2.5)
		local ped
		if t then
			ped = t:Clone()
			local cf, size = ped:GetBoundingBox()
			ped:PivotTo(ped:GetPivot() + ((base * off).Position - Vector3.new(cf.X, cf.Y - size.Y / 2, cf.Z)))
			ped.Parent = decor
		else
			ped = standIn(decor, base * off)
		end
		local cf, size = ped:GetBoundingBox()
		local anchor = Instance.new("Part")
		anchor.Name = "FeatureAnchor" .. i; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
		anchor.Transparency = 1; anchor.Size = Vector3.new(0.4, 0.4, 0.4)
		anchor.CFrame = CFrame.new(cf.X, cf.Y + size.Y / 2 + 2.0, cf.Z) * (base - base.Position)
		anchor.Parent = decor
	end
end

for _, r in ipairs(roosts:GetChildren()) do dress(r) end
roosts.ChildAdded:Connect(function(r) task.defer(dress, r) end)
