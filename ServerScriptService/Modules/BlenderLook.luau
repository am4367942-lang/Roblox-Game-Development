-- Gives imported Blender meshes their Roblox look, based on the mesh/part name
-- (each Blender object is named after its material).
local Look = {}
local M = Enum.Material
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
Look.TABLE = {
	Stone = { M.Slate, rgb(98, 94, 118) }, DarkStone = { M.Slate, rgb(78, 72, 96) },
	RoostStone = { M.Slate, rgb(128, 118, 158) }, RoostTrim = { M.Slate, rgb(84, 70, 115) },
	Moss = { M.Grass, rgb(58, 112, 66) }, Dirt = { M.Ground, rgb(86, 62, 48) }, Rune = { M.Neon, rgb(90, 255, 229) },
	Metal = { M.Metal, rgb(158, 162, 184) }, DarkMetal = { M.Metal, rgb(44, 42, 56) }, Iron = { M.Metal, rgb(34, 32, 44) },
	Brass = { M.Metal, rgb(206, 158, 76) }, Gold = { M.Metal, rgb(240, 186, 70) }, Silver = { M.Metal, rgb(214, 218, 230) },
	Glass = { M.Glass, rgb(170, 225, 255), 0.55 }, Crystal = { M.Glass, rgb(190, 165, 255), 0.4 },
	Neon = { M.Neon, rgb(90, 255, 229) }, SpiritFlame = { M.Neon, rgb(90, 255, 229) }, Purple = { M.Neon, rgb(170, 90, 255) }, Violet = { M.Neon, rgb(170, 90, 255) },
	Wood = { M.Wood, rgb(104, 70, 46) }, CoffinWood = { M.WoodPlanks, rgb(52, 32, 30) }, Leather = { M.Fabric, rgb(70, 40, 30) },
	Rubber = { M.SmoothPlastic, rgb(56, 112, 100) }, Rust = { M.CorrodedMetal, rgb(126, 72, 44) }, Bone = { M.SmoothPlastic, rgb(230, 222, 200) },
	Clay = { M.Sandstone, rgb(170, 92, 60) }, Cork = { M.Wood, rgb(150, 108, 68) }, Rope = { M.Fabric, rgb(186, 156, 104) },
	VoidStone = { M.Marble, rgb(40, 24, 58) },
}
function Look.key(name)
	return (name:match("^([%a]+)") or name)
end
function Look.apply(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") or d:IsA("BasePart") then
			local spec = Look.TABLE[Look.key(d.Name)]
			if spec then
				d.Material = spec[1]; d.Color = spec[2]; d.Transparency = spec[3] or 0
				if spec[1] == M.Neon then d.CastShadow = false end
			end
			if d:IsA("MeshPart") then d.TextureID = "" end
			d.Anchored = true
		end
	end
	return model
end
-- scale a model so its height (Y) or width (X) matches the target, keeping proportions
function Look.fit(model, axis, target)
	local _, size = model:GetBoundingBox()
	local current = axis == "X" and math.max(size.X, size.Z) or size.Y
	if current > 0.01 then model:ScaleTo(model:GetScale() * target / current) end
	return model
end
return Look
