-- TreeBuilder: realistic-ish trees from parts. Fine detail is tagged "FineDetail"
-- so the Low Graphics mode can hide it on weak devices.
local CS = game:GetService("CollectionService")
local V, CF = Vector3.new, CFrame.new
local ROT = CFrame.Angles(0, 0, math.rad(90))
local rad = math.rad
local TB = {}

local barkCols = { Color3.fromRGB(66, 50, 48), Color3.fromRGB(58, 44, 46), Color3.fromRGB(76, 58, 52), Color3.fromRGB(50, 42, 50) }
local oakLeaf = { Color3.fromRGB(36, 92, 62), Color3.fromRGB(28, 80, 64), Color3.fromRGB(46, 104, 60), Color3.fromRGB(34, 74, 82), Color3.fromRGB(58, 76, 112) }
local pineLeaf = { Color3.fromRGB(22, 68, 58), Color3.fromRGB(28, 80, 62), Color3.fromRGB(20, 58, 66) }

local function mk(parent, name, shape, size, cf, color, mat, collide, fine)
	local p = Instance.new("Part")
	p.Name = name; p.Shape = shape or Enum.PartType.Block
	if shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
		p.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
	end
	p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true; p.CanCollide = collide or false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	if fine then CS:AddTag(p, "FineDetail") end
	return p
end

-- tapered, gently bending trunk; returns the CFrame at the end of every segment
local function trunk(parent, base, height, dia, segs, taperTo, color, rng, bend)
	local levels = { base }
	local cur = base
	local tx, tz = 0, 0
	for i = 1, segs do
		local seg = height / segs
		local d0 = dia * (1 - (1 - taperTo) * (i - 1) / segs)
		local d1 = dia * (1 - (1 - taperTo) * i / segs)
		tx += rng:NextNumber(-bend, bend); tz += rng:NextNumber(-bend, bend)
		local segCF = cur * CFrame.Angles(rad(tx), 0, rad(tz))
		mk(parent, "Trunk", Enum.PartType.Cylinder, V(seg * 1.05, (d0 + d1) / 2, (d0 + d1) / 2), segCF * CF(0, seg / 2, 0) * ROT, color, Enum.Material.Wood, i <= 2)
		cur = segCF * CF(0, seg * 0.98, 0)
		if i < segs then
			mk(parent, "BarkRing", Enum.PartType.Cylinder, V(0.35, d1 * 1.12, d1 * 1.12), cur * ROT, color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Wood, false, true)
		end
		levels[#levels + 1] = cur
	end
	return levels
end

local function branch(parent, from, len, pitch, yaw, thick, color, rng, fine)
	local br = from * CFrame.Angles(0, rad(yaw), 0) * CFrame.Angles(0, 0, rad(pitch))
	mk(parent, "Branch", nil, V(len, thick, thick), br * CF(len / 2, 0, 0), color, Enum.Material.Wood, false, fine)
	return br * CF(len, 0, 0)
end

local function cluster(parent, pos, size, leafCol, rng, n, mat)
	for i = 1, n do
		local s = size * rng:NextNumber(0.7, 1.2)
		local off = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.9), rng:NextNumber(-1, 1)) * size * 0.45
		local col = leafCol:Lerp(rng:NextNumber() < 0.5 and Color3.new(0, 0.05, 0.08) or Color3.new(0.3, 0.5, 0.3), rng:NextNumber(0, 0.28))
		mk(parent, "Leaves", Enum.PartType.Ball, V(s, s * 0.78, s), CF(pos + off), col, mat or Enum.Material.Grass, false, i > 2)
	end
end

local function roots(parent, base, dia, count, color, rng)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local rb = base * CFrame.Angles(0, a, 0)
		mk(parent, "Root", nil, V(dia * 1.3, 0.9, 0.9), rb * CFrame.Angles(0, 0, rad(-16)) * CF(dia * 0.75, 0.35, 0), color, Enum.Material.Wood, false)
		mk(parent, "RootTip", nil, V(dia * 0.9, 0.55, 0.55), rb * CFrame.Angles(0, 0, rad(-34)) * CF(dia * 1.6, 0.05, 0), color, Enum.Material.Wood, false, true)
	end
end

local function litter(parent, pos, rng, n)
	for i = 1, n do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(2, 7)
		mk(parent, "LeafLitter", Enum.PartType.Cylinder, V(0.08, rng:NextNumber(1.2, 2.6), rng:NextNumber(1.2, 2.6)), CF(pos + V(math.cos(a) * r, 0.05, math.sin(a) * r)) * ROT,
			Color3.fromRGB(70 + rng:NextInteger(0, 40), 50 + rng:NextInteger(0, 20), 40), Enum.Material.Fabric, false, true)
	end
end

function TB.oak(parent, pos, rng, scale, glowFruit)
	scale = scale or 1
	local H = rng:NextNumber(17, 24) * scale
	local D = rng:NextNumber(2.2, 3.2) * scale
	local base = CF(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local bark = barkCols[rng:NextInteger(1, #barkCols)]
	local levels = trunk(parent, base, H * 0.6, D, 6, 0.55, bark, rng, 2.2)
	roots(parent, base, D, 5, bark, rng)
	local leaf = oakLeaf[rng:NextInteger(1, #oakLeaf)]
	local nb = TB.lite and 4 or rng:NextInteger(6, 8)
	for i = 1, nb do
		local from = levels[rng:NextInteger(4, #levels)]
		local len = rng:NextNumber(6, 10) * scale
		local e = branch(parent, from, len, rng:NextInteger(28, 52), i * (360 / nb) + rng:NextInteger(-20, 20), 0.9 * scale, bark, rng)
		for f = 1, (TB.lite and 0 or 2) do
			local e2 = branch(parent, e, len * 0.55, rng:NextInteger(15, 40), rng:NextInteger(-70, 70), 0.45, bark, rng, true)
			cluster(parent, e2.Position, 3.2 * scale, leaf, rng, 4)
		end
		cluster(parent, e.Position, 4.2 * scale, leaf, rng, TB.lite and 3 or 5)
		if glowFruit and i == 1 then
			local fruit = mk(parent, "GlowFruit", Enum.PartType.Ball, V(0.8, 0.8, 0.8), CF(e.Position + V(0, -1.6, 0)), Color3.fromRGB(120, 255, 210), Enum.Material.Neon)
			local l = Instance.new("PointLight"); l.Color = fruit.Color; l.Range = 12; l.Brightness = 0.8; l.Parent = fruit
		end
	end
	cluster(parent, levels[#levels].Position + V(0, 1.5 * scale, 0), 6 * scale, leaf, rng, TB.lite and 4 or 5)
	litter(parent, pos, rng, 4)
end

function TB.pine(parent, pos, rng, scale)
	scale = scale or 1
	local H = rng:NextNumber(22, 32) * scale
	local D = rng:NextNumber(1.5, 2.2) * scale
	local base = CF(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local bark = barkCols[rng:NextInteger(1, #barkCols)]
	trunk(parent, base, H * 0.9, D, 5, 0.25, bark, rng, 0.8)
	roots(parent, base, D, 4, bark, rng)
	local leaf = pineLeaf[rng:NextInteger(1, #pineLeaf)]
	local tiers = TB.lite and 6 or 9
	local maxR = rng:NextNumber(5.5, 7.5) * scale
	for t = 0, tiers - 1 do
		local f = t / tiers
		local y = H * 0.2 + f * H * 0.8
		local r = maxR * (1 - f) ^ 0.9 + 0.7
		local col = leaf:Lerp(Color3.new(0.05, 0.12, 0.1), f * 0.2 + rng:NextNumber(0, 0.1))
		mk(parent, "PineTier", Enum.PartType.Ball, V(r * 2, 1.9, r * 2), base * CF(0, y, 0), col, Enum.Material.Grass, false)
		mk(parent, "PineSkirt", Enum.PartType.Ball, V(r * 2.25, 0.9, r * 2.25), base * CF(0, y - 0.9, 0), col:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Grass, false, true)
	end
	litter(parent, pos, rng, 3)
end

function TB.dead(parent, pos, rng, scale, crow)
	scale = scale or 1
	local H = rng:NextNumber(14, 20) * scale
	local D = rng:NextNumber(2, 2.8) * scale
	local base = CF(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local bark = Color3.fromRGB(48, 38, 44)
	local levels = trunk(parent, base, H * 0.7, D, 6, 0.3, bark, rng, 6)
	roots(parent, base, D, 5, bark, rng)
	local function twig(from, len, depth)
		local nb = depth == 0 and (TB.lite and 4 or rng:NextInteger(6, 8)) or (TB.lite and 1 or 2)
		for i = 1, nb do
			local e = branch(parent, from, len, rng:NextInteger(25, 60), i * (360 / nb) + rng:NextInteger(-25, 25), math.max(0.25, 0.7 * (1 - depth * 0.35)) * scale, bark, rng, depth > 0)
			if depth < 2 then twig(e, len * 0.6, depth + 1) end
		end
	end
	for k = 4, #levels, (TB.lite and 2 or 1) do twig(levels[k], rng:NextNumber(5, 8) * scale, k == #levels and 0 or 1) end
	for i = 1, 6 do
		local len = rng:NextNumber(3, 6)
		local lv = levels[rng:NextInteger(4, #levels)]
		mk(parent, "HangingMoss", nil, V(0.3, len, 0.3), lv * CF(rng:NextNumber(-2, 2), -len / 2, rng:NextNumber(-2, 2)), Color3.fromRGB(110, 130, 96), Enum.Material.Fabric, false, true)
	end
	if crow then
		local c = levels[#levels - 1] * CF(3.5, 1.5, 0)
		local black = Color3.fromRGB(14, 12, 20)
		mk(parent, "CrowBody", Enum.PartType.Ball, V(0.9, 0.7, 1.4), c, black, Enum.Material.SmoothPlastic, false, true)
		mk(parent, "CrowHead", Enum.PartType.Ball, V(0.5, 0.5, 0.5), c * CF(0, 0.4, -0.6), black, Enum.Material.SmoothPlastic, false, true)
		mk(parent, "CrowBeak", nil, V(0.12, 0.12, 0.4), c * CF(0, 0.35, -1), Color3.fromRGB(230, 170, 50), Enum.Material.SmoothPlastic, false, true)
		mk(parent, "CrowEye", Enum.PartType.Ball, V(0.12, 0.12, 0.1), c * CF(0.15, 0.5, -0.8), Color3.fromRGB(255, 70, 70), Enum.Material.Neon, false, true)
	end
end

function TB.cypress(parent, pos, rng, scale)
	scale = scale or 1
	local H = rng:NextNumber(16, 24) * scale
	local D = rng:NextNumber(3.6, 4.8) * scale
	local base = CF(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local bark = barkCols[rng:NextInteger(1, #barkCols)]
	local levels = trunk(parent, base, H, D, 6, 0.38, bark, rng, 1.5)
	roots(parent, base, D * 1.1, 6, bark, rng)
	for i = 1, 4 do
		local a = rad(i * 90 + rng:NextInteger(-25, 25))
		mk(parent, "CypressKnee", Enum.PartType.Cylinder, V(rng:NextNumber(1.5, 3), 0.9, 0.9), base * CFrame.Angles(0, a, 0) * CF(D * 1.1 + 1, 0.9, 0) * ROT, bark, Enum.Material.Wood, false, true)
	end
	local topCF = levels[#levels]
	local leaf = Color3.fromRGB(34, 78, 60)
	for i = 1, 6 do
		local a = rad(i * 60)
		local r = rng:NextNumber(3, 6) * scale
		local s = rng:NextNumber(7, 11) * scale
		mk(parent, "Canopy", Enum.PartType.Ball, V(s, s * 0.34, s), topCF * CF(math.cos(a) * r, rng:NextNumber(-2.5, 1.5), math.sin(a) * r), leaf:Lerp(Color3.new(0, 0.1, 0.1), rng:NextNumber(0, 0.3)), Enum.Material.Grass, false)
	end
	mk(parent, "Canopy", Enum.PartType.Ball, V(11 * scale, 3.4 * scale, 11 * scale), topCF * CF(0, 1.4, 0), leaf, Enum.Material.Grass, false)
	for i = 1, 18 do
		local a = rad(i * 20 + rng:NextInteger(-8, 8))
		local len = rng:NextNumber(3, 7)
		local r = rng:NextNumber(3.5, 7) * scale
		mk(parent, "Moss", nil, V(0.3, len, 0.3), topCF * CF(math.cos(a) * r, -1.5 - len / 2, math.sin(a) * r), Color3.fromRGB(100 + rng:NextInteger(0, 20), 134, 94), Enum.Material.Fabric, false, true)
	end
end

return TB
