-- Displayed ghosts in EVERY player's Spirit Roost, with clear name + level plates.
-- Visual only: what is displayed is decided and saved by the server (cell attributes).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local player = Players.LocalPlayer
local Visuals = require(RS.Shared:WaitForChild("GhostVisuals"))
local Catalog = require(RS.Shared.GhostCatalog)
local roosts = workspace:WaitForChild("SpiritRoosts")
local folder = Instance.new("Folder"); folder.Name = "LocalRoostGhostPortraits"; folder.Parent = workspace
local RIG_RANGE, PLATE_RANGE, MAX_RIGS = 70, 42, 60
local RARITY = { Common = Color3.fromRGB(200, 205, 220), Uncommon = Color3.fromRGB(120, 235, 150), Rare = Color3.fromRGB(120, 180, 255), Legendary = Color3.fromRGB(255, 200, 90) }
local active = {}
local acc = 0

local function makePlate(cell, def)
	local anchor = Instance.new("Part")
	anchor.Name = "PlateAnchor"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
	anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 40); bb.StudsOffsetWorldSpace = Vector3.new(0, 1.35, 0)
	bb.MaxDistance = PLATE_RANGE; bb.LightInfluence = 0; bb.AlwaysOnTop = false; bb.Adornee = anchor; bb.Parent = anchor
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1; name.Size = UDim2.new(1, 0, 0.55, 0); name.Font = Enum.Font.GothamBlack; name.TextScaled = true
	name.TextStrokeTransparency = 0; name.TextStrokeColor3 = Color3.fromRGB(12, 6, 20); name.Parent = bb
	local level = name:Clone(); level.Position = UDim2.fromScale(0, 0.55); level.Size = UDim2.new(1, 0, 0.45, 0); level.Font = Enum.Font.GothamBold; level.Parent = bb
	return { anchor = anchor, name = name, level = level }
end

Run.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()
	local candidates = {}
	if root then
		for _, roost in ipairs(roosts:GetChildren()) do
			local cells = roost:FindFirstChild("SpiritCells")
			if cells and (roost:GetAttribute("OwnerUserId") or 0) ~= 0 then
				for _, cell in ipairs(cells:GetChildren()) do
					local body = cell:FindFirstChild("GhostBody")
					local kind = cell:GetAttribute("SpiritKind")
					if body and kind and Catalog.ById[kind] then
						local dist = (body.Position - root.Position).Magnitude
						if dist < RIG_RANGE then table.insert(candidates, { cell = cell, body = body, kind = kind, dist = dist }) end
					end
				end
			end
		end
	end
	-- featured pedestals: each owner's equipped team, readable by every visitor
	if root then
		local HTTP = game:GetService("HttpService")
		for _, roost in ipairs(roosts:GetChildren()) do
			local owner = Players:GetPlayerByUserId(roost:GetAttribute("OwnerUserId") or 0)
			local decor = roost:FindFirstChild("BlenderDecor")
			if owner and decor then
				local ok, kinds = pcall(HTTP.JSONDecode, HTTP, owner:GetAttribute("EquippedSpiritPets") or "[]")
				if ok and type(kinds) == "table" then
					for i = 1, 2 do
						local anchor = decor:FindFirstChild("FeatureAnchor" .. i)
						local kind = kinds[i]
						if anchor and kind and Catalog.ById[kind] then
							local dist = (anchor.Position - root.Position).Magnitude
							if dist < RIG_RANGE then
								table.insert(candidates, { cell = anchor, body = anchor, kind = kind, dist = dist, featured = owner.DisplayName })
							end
						end
					end
				end
			end
		end
	end
	table.sort(candidates, function(a, b) return a.dist < b.dist end)
	local keep = {}
	for i = 1, math.min(MAX_RIGS, #candidates) do
		local c = candidates[i]
		local def = Catalog.ById[c.kind]
		local entry = active[c.cell]
		if entry and entry.kind ~= c.kind then entry.rig:destroy(); entry.plate.anchor:Destroy(); entry = nil end
		if not entry then
			local rig = Visuals.create(folder, c.kind, Color3.fromRGB(table.unpack(def.color)), c.featured and 0.95 or 0.59, true)
			entry = { rig = rig, kind = c.kind, plate = makePlate(c.cell, def) }
			active[c.cell] = entry
		end
		local index = tonumber(c.cell.Name:match("%d+")) or i
		entry.rig:pose(c.featured and (c.body.CFrame * CFrame.new(0, math.sin(now * 1.5 + index) * 0.15, 0)) or (c.body.CFrame * CFrame.new(0, 0.18 + math.sin(now + index) * 0.04, -0.18)), now, index, true)
		entry.plate.anchor.CFrame = c.body.CFrame * CFrame.new(0, 0, -0.5)
		if c.featured then
			entry.plate.name.Text = def.name
			entry.plate.level.Text = c.featured .. "'s team"
		else
			entry.plate.name.Text = c.cell:GetAttribute("GhostName") or def.name
			entry.plate.level.Text = "Lv. " .. tostring(c.cell:GetAttribute("GhostLevel") or 1) .. (c.cell:GetAttribute("GhostEquipped") and "  ★ ACTIVE" or "")
		end
		entry.plate.name.TextColor3 = RARITY[def.rarity] or Color3.new(1, 1, 1)
		entry.plate.level.TextColor3 = Color3.fromRGB(240, 236, 255)
		keep[c.cell] = true
	end
	for cell, entry in pairs(active) do
		if not keep[cell] then entry.rig:destroy(); entry.plate.anchor:Destroy(); active[cell] = nil end
	end
end)
