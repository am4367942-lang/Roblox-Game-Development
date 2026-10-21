-- RoostView: every Spirit Roost is visible to everyone. The owner gets an
-- "Arrange Ghosts" prompt at their own roost and a marker when they wander away.
-- All changes go through server-validated remotes (RoostDisplay / Progression / GhostCare).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local folder = workspace:WaitForChild("SpiritRoosts")
local remotes = RS:WaitForChild("Remotes")
local Catalog = require(RS.Shared:WaitForChild("GhostCatalog"))
local MARKER_DISTANCE = 45

local function isMine(roost) return roost:IsA("Model") and roost:GetAttribute("OwnerUserId") == player.UserId end
local function myRoost()
	for _, r in ipairs(folder:GetChildren()) do if isMine(r) then return r end end
	return nil
end

----------------------------------------------------------------------
-- marker toward your own roost when you are away
----------------------------------------------------------------------
local anchor = Instance.new("Part")
anchor.Name = "MyRoostMarkerAnchor"; anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false
anchor.Transparency = 1; anchor.Size = Vector3.new(0.2, 0.2, 0.2); anchor.Parent = workspace.CurrentCamera
local gui = player:WaitForChild("PlayerGui")
local marker = Instance.new("BillboardGui")
marker.Name = "MyRoostMarker"; marker.Size = UDim2.fromOffset(170, 64); marker.AlwaysOnTop = true; marker.LightInfluence = 0
marker.Adornee = anchor; marker.Enabled = false; marker.ResetOnSpawn = false; marker.Parent = gui
do
	local pin = Instance.new("Frame"); pin.Size = UDim2.fromOffset(16, 16); pin.Position = UDim2.new(0.5, -8, 1, -16)
	pin.BackgroundColor3 = Color3.fromRGB(87, 255, 229); pin.Rotation = 45; pin.BorderSizePixel = 0; pin.Parent = marker
	local box = Instance.new("Frame"); box.Size = UDim2.new(1, 0, 0, 44); box.BackgroundColor3 = Color3.fromRGB(22, 15, 38); box.BorderSizePixel = 0; box.Parent = marker
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke", box); st.Color = Color3.fromRGB(87, 255, 229); st.Thickness = 2
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.new(1, -10, 0, 22); t.Position = UDim2.fromOffset(5, 2)
	t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.Text = "YOUR SPIRIT ROOST"; t.TextColor3 = Color3.fromRGB(255, 214, 120); t.Parent = box
	local dl = t:Clone(); dl.Name = "Dist"; dl.Size = UDim2.new(1, -10, 0, 16); dl.Position = UDim2.fromOffset(5, 25); dl.Font = Enum.Font.GothamBold
	dl.TextColor3 = Color3.fromRGB(235, 230, 255); dl.Text = ""; dl.Parent = box
end
task.spawn(function()
	while true do
		task.wait(0.25)
		local roost = myRoost()
		local beacon = roost and (roost:FindFirstChild("SoulBeacon", true) or roost.PrimaryPart)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pos = beacon and beacon.Position + Vector3.new(0, 6, 0) or player:GetAttribute("SpiritRoostPosition")
		if typeof(pos) == "Vector3" and root then
			anchor.CFrame = CFrame.new(pos)
			local d = (root.Position - pos).Magnitude
			marker.Enabled = d > MARKER_DISTANCE
			marker:FindFirstChild("Dist", true).Text = ("%d studs away"):format(math.floor(d))
		else
			marker.Enabled = false
		end
	end
end)

----------------------------------------------------------------------
-- Arrange Ghosts panel (owner only)
----------------------------------------------------------------------
local displayRemote = remotes:WaitForChild("RoostDisplayAction")
local featureAction = remotes:WaitForChild("FeatureAction")
local featureState = remotes:WaitForChild("FeatureState")
local roostAction = remotes:WaitForChild("RoostAction")
local inventory, foods = {}, {}
featureState.OnClientEvent:Connect(function(s)
	if type(s) == "table" then inventory = s.inventory or inventory; foods = s.foods or foods end
end)

local screen = Instance.new("ScreenGui"); screen.Name = "RoostArrange"; screen.ResetOnSpawn = false; screen.Enabled = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screen.DisplayOrder = 50; screen.Parent = gui
local panel = Instance.new("Frame"); panel.Size = UDim2.fromOffset(760, 470); panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(20, 13, 34); panel.Parent = screen
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local ps = Instance.new("UIStroke", panel); ps.Color = Color3.fromRGB(150, 110, 255); ps.Thickness = 2
local scale = Instance.new("UIScale", panel)
local function fit() local v = workspace.CurrentCamera.ViewportSize; scale.Scale = math.clamp(math.min(v.X / 800, v.Y / 520), 0.45, 1) end
fit(); workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
local function label(parent, text, size, pos, font, color, align)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Size = size; l.Position = pos; l.Font = font or Enum.Font.GothamBold
	l.TextScaled = true; l.Text = text; l.TextColor3 = color or Color3.new(1, 1, 1); l.TextXAlignment = align or Enum.TextXAlignment.Left; l.Parent = parent
	return l
end
local function button(parent, text, size, pos, color)
	local b = Instance.new("TextButton"); b.Size = size; b.Position = pos; b.BackgroundColor3 = color or Color3.fromRGB(60, 40, 100)
	b.Font = Enum.Font.GothamBold; b.TextScaled = true; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1); b.AutoButtonColor = true; b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", b); pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6); pad.PaddingTop = UDim.new(0, 4); pad.PaddingBottom = UDim.new(0, 4)
	return b
end
label(panel, "ARRANGE YOUR SPIRIT ROOST", UDim2.new(0, 460, 0, 30), UDim2.fromOffset(18, 12), Enum.Font.GothamBlack, Color3.fromRGB(255, 214, 120))
local hint = label(panel, "Pick a slot, then choose what to do with it.", UDim2.new(0, 460, 0, 18), UDim2.fromOffset(18, 44), Enum.Font.Gotham, Color3.fromRGB(200, 190, 230))
local close = button(panel, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 12), Color3.fromRGB(120, 40, 70))
close.MouseButton1Click:Connect(function() screen.Enabled = false end)
local grid = Instance.new("Frame"); grid.BackgroundTransparency = 1; grid.Size = UDim2.fromOffset(460, 390); grid.Position = UDim2.fromOffset(18, 70); grid.Parent = panel
local side = Instance.new("ScrollingFrame"); side.Size = UDim2.fromOffset(260, 340); side.Position = UDim2.fromOffset(490, 70)
side.BackgroundColor3 = Color3.fromRGB(30, 20, 50); side.ScrollBarThickness = 6; side.AutomaticCanvasSize = Enum.AutomaticSize.Y; side.CanvasSize = UDim2.new(); side.Parent = panel
Instance.new("UICorner", side).CornerRadius = UDim.new(0, 10)
local list = Instance.new("UIListLayout", side); list.Padding = UDim.new(0, 6); list.SortOrder = Enum.SortOrder.LayoutOrder
local sp = Instance.new("UIPadding", side); sp.PaddingTop = UDim.new(0, 8); sp.PaddingLeft = UDim.new(0, 8); sp.PaddingRight = UDim.new(0, 8)
local fill = button(panel, "Auto-fill", UDim2.fromOffset(125, 40), UDim2.fromOffset(490, 418), Color3.fromRGB(40, 110, 100))
local clearAll = button(panel, "Clear all", UDim2.fromOffset(125, 40), UDim2.fromOffset(625, 418), Color3.fromRGB(110, 50, 70))
fill.MouseButton1Click:Connect(function() displayRemote:FireServer("AutoFill") end)
clearAll.MouseButton1Click:Connect(function() displayRemote:FireServer("Clear") end)

local selected, moving = nil, nil
local tiles = {}
local function cellsOf(roost) return roost and roost:FindFirstChild("SpiritCells") end
local function cellAt(roost, i) local c = cellsOf(roost); return c and c:FindFirstChild("Cell" .. i) end
local function invByUid(uid) for _, pet in ipairs(inventory) do if pet.uid == uid then return pet end end end

local refreshPanel
local function sideButton(text, color, order, fn)
	local b = button(side, text, UDim2.new(1, 0, 0, 36), UDim2.new(), color); b.LayoutOrder = order
	b.MouseButton1Click:Connect(fn)
	return b
end
local function sideLabel(text, order, color)
	local l = label(side, text, UDim2.new(1, 0, 0, 22), UDim2.new(), Enum.Font.GothamBold, color or Color3.fromRGB(230, 225, 255)); l.LayoutOrder = order
	return l
end

function refreshPanel()
	local roost = myRoost()
	if not roost or not screen.Enabled then return end
	-- grid laid out like the wall: rows top to bottom, columns left to right
	local entries = {}
	for i = 1, 30 do
		local cell = cellAt(roost, i)
		local tile = cell and cell:FindFirstChild("Tile")
		if tile then table.insert(entries, { i = i, cell = cell, y = tile.Position.Y, x = tile.Position.X }) end
	end
	table.sort(entries, function(a, b) if math.abs(a.y - b.y) > 1 then return a.y > b.y end return a.x < b.x end)
	for k, e in ipairs(entries) do
		local row, col = math.floor((k - 1) / 5), (k - 1) % 5
		local t = tiles[e.i]
		if not t then
			t = button(grid, "", UDim2.fromOffset(86, 58), UDim2.new(), Color3.fromRGB(45, 32, 72)); tiles[e.i] = t
			t.MouseButton1Click:Connect(function()
				if moving and moving ~= e.i then displayRemote:FireServer("Move", moving, e.i); moving = nil; selected = e.i
				else selected = e.i; moving = nil end
				refreshPanel()
			end)
		end
		t.Position = UDim2.fromOffset(col * 92, row * 64)
		local kind = e.cell:GetAttribute("SpiritKind")
		local def = kind and Catalog.ById[kind]
		t.Text = def and ((e.cell:GetAttribute("GhostName") or def.name) .. "\nLv. " .. (e.cell:GetAttribute("GhostLevel") or 1) .. (e.cell:GetAttribute("GhostEquipped") and " ★" or "")) or ("Slot " .. e.i)
		t.BackgroundColor3 = def and Color3.fromRGB(table.unpack(def.color)):Lerp(Color3.fromRGB(20, 12, 40), 0.55) or Color3.fromRGB(45, 32, 72)
		local stroke = t:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", t)
		stroke.Thickness = (selected == e.i or moving == e.i) and 3 or 0
		stroke.Color = moving == e.i and Color3.fromRGB(255, 214, 120) or Color3.fromRGB(87, 255, 229)
	end
	for _, c in ipairs(side:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	if moving then hint.Text = "Moving: pick the slot to swap with." elseif selected then hint.Text = "Slot " .. selected .. " selected." else hint.Text = "Pick a slot, then choose what to do with it." end
	if not selected then sideLabel("Select a slot on the left.", 1); return end
	local cell = cellAt(roost, selected)
	local uid = cell and cell:GetAttribute("GhostUid")
	if uid then
		local pet = invByUid(uid)
		sideLabel((cell:GetAttribute("GhostName") or "Ghost") .. "  ·  Lv. " .. (cell:GetAttribute("GhostLevel") or 1), 1, Color3.fromRGB(255, 214, 120))
		sideButton("Move to another slot", Color3.fromRGB(70, 60, 140), 2, function() moving = selected; refreshPanel() end)
		sideButton("Remove from display", Color3.fromRGB(120, 50, 70), 3, function() displayRemote:FireServer("Remove", selected) end)
		local eq = pet and pet.equipped or cell:GetAttribute("GhostEquipped")
		sideButton(eq and "Unequip from team" or "Equip to team", Color3.fromRGB(40, 110, 100), 4, function() featureAction:FireServer("Equip", uid) end)
		local order = 5
		for _, f in ipairs(Catalog.Foods) do
			local n = foods[f.id] or 0
			if n > 0 then
				sideButton(("Feed %s (+%d XP) ×%d"):format(f.name, f.xp, n), Color3.fromRGB(150, 100, 40), order, function() roostAction:FireServer("Feed", f.id, uid) end)
				order += 1
			end
		end
		if order == 5 then sideLabel("Buy treats at the feeding table to level up.", order, Color3.fromRGB(190, 180, 220)) end
	else
		sideLabel("Place a ghost here:", 1, Color3.fromRGB(255, 214, 120))
		local displayed = {}
		for i = 1, 30 do local c = cellAt(roost, i); local u = c and c:GetAttribute("GhostUid"); if u then displayed[u] = true end end
		local order = 2
		for _, pet in ipairs(inventory) do
			if not displayed[pet.uid] then
				local def = Catalog.ById[pet.kind]
				sideButton(("%s  ·  Lv. %d%s"):format(pet.name or pet.kind, pet.level or 1, pet.equipped and " ★" or ""), def and Color3.fromRGB(table.unpack(def.color)):Lerp(Color3.fromRGB(20, 12, 40), 0.5) or nil, order, function()
					displayRemote:FireServer("Place", selected, pet.uid)
				end)
				order += 1
			end
		end
		if order == 2 then sideLabel("All your ghosts are already on display.", 2, Color3.fromRGB(190, 180, 220)) end
	end
end

local function open()
	if not myRoost() then return end
	featureAction:FireServer("State")
	screen.Enabled = true
	selected, moving = nil, nil
	refreshPanel()
end
featureState.OnClientEvent:Connect(function() task.defer(refreshPanel) end)

-- prompt only on your own roost (visitors never get it; the server rejects them anyway)
local prompt
local watched = {}
local function hookCells(roost)
	if watched[roost] then return end
	watched[roost] = true
	local cells = cellsOf(roost)
	if cells then for _, c in ipairs(cells:GetChildren()) do c.AttributeChanged:Connect(function() if isMine(roost) then task.defer(refreshPanel) end end) end end
end
local function placePrompt()
	local roost = myRoost()
	if prompt and (not roost or not prompt:IsDescendantOf(roost)) then prompt:Destroy(); prompt = nil end
	if roost and not prompt then
		local host = roost:FindFirstChild("SoulBeacon", true) or roost:FindFirstChild("RoostConvertPad", true) or roost.PrimaryPart
		if host then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ArrangeGhostsPrompt"; prompt.ActionText = "Arrange Ghosts"; prompt.ObjectText = "Your Spirit Roost"
			prompt.KeyboardKeyCode = Enum.KeyCode.R; prompt.HoldDuration = 0; prompt.MaxActivationDistance = 14; prompt.RequiresLineOfSight = false
			prompt.Parent = host
			prompt.Triggered:Connect(open)
		end
		hookCells(roost)
	end
end
for _, r in ipairs(folder:GetChildren()) do if r:IsA("Model") then r:GetAttributeChangedSignal("OwnerUserId"):Connect(placePrompt) end end
folder.ChildAdded:Connect(function(r) if r:IsA("Model") then r:GetAttributeChangedSignal("OwnerUserId"):Connect(placePrompt); placePrompt() end end)
placePrompt()
local function visitorPrompts()
	for _, r in ipairs(folder:GetChildren()) do
		if r:IsA("Model") then
			for _, d in ipairs(r:GetDescendants()) do
				if d:IsA("ProximityPrompt") and d.Name == "GhostCarePrompt" then d.Enabled = isMine(r) end
			end
		end
	end
end
visitorPrompts()
task.spawn(function() while true do task.wait(3); placePrompt(); visitorPrompts() end end)
