-- Haunted Harvest client UI. This script only RENDERS state and REQUESTS actions;
-- the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateRE = Remotes:WaitForChild("State")
local NotifyRE = Remotes:WaitForChild("Notify")
local OpenShopRE = Remotes:WaitForChild("OpenShop")
local DialogueRE = Remotes:WaitForChild("Dialogue")
local RequestStateRE = Remotes:WaitForChild("RequestState")
local BuyUpgradeRE = Remotes:WaitForChild("BuyUpgrade")
local NpcActionRE = Remotes:WaitForChild("NpcAction")

local C = {
	bg = Color3.fromRGB(22, 15, 38),
	panel = Color3.fromRGB(34, 24, 56),
	deep = Color3.fromRGB(12, 8, 22),
	teal = Color3.fromRGB(0, 255, 220),
	purple = Color3.fromRGB(165, 95, 255),
	text = Color3.fromRGB(240, 235, 255),
	dim = Color3.fromRGB(165, 155, 195),
	red = Color3.fromRGB(255, 95, 115),
	gold = Color3.fromRGB(255, 205, 95),
}

local state = nil

----------------------------------------------------------------------
-- Small UI helpers
----------------------------------------------------------------------
local function make(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

local function corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness, transparency)
	return make("UIStroke", { Color = color, Thickness = thickness or 1.5, Transparency = transparency or 0.35 })
end

local function fmt(n)
	local s = tostring(math.floor(n))
	local reversed = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (reversed:gsub("^,", ""))
end

local function label(props)
	local base = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do base[k] = v end
	return make("TextLabel", base)
end

local function panel(props)
	local base = { BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0 }
	for k, v in pairs(props) do base[k] = v end
	local f = make("Frame", base)
	corner(14).Parent = f
	stroke(C.purple, 1.5, 0.35).Parent = f
	return f
end

local function popIn(frame)
	local scale = frame:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = frame })
	scale.Scale = 0.88
	frame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local gui = make("ScreenGui", {
	Name = "HauntedHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
	Parent = player:WaitForChild("PlayerGui"),
})

----------------------------------------------------------------------
-- Currency HUD (top-left)
----------------------------------------------------------------------
local hud = panel({ Name = "Currency", Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(0, 270, 0, 116), Parent = gui })

label({ Text = "SOUL JAR", TextSize = 12, TextColor3 = C.dim, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(0, 120, 0, 16), Parent = hud })
local jarValue = label({ Text = "0 / 100", TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 8), Size = UDim2.new(0, 150, 0, 18), Parent = hud })
local barBack = make("Frame", { BackgroundColor3 = C.deep, BorderSizePixel = 0, Position = UDim2.new(0, 14, 0, 32), Size = UDim2.new(1, -28, 0, 14), Parent = hud }, { corner(7) })
local barFill = make("Frame", { BackgroundColor3 = C.teal, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = barBack }, {
	corner(7),
	make("UIGradient", { Color = ColorSequence.new(C.teal, Color3.fromRGB(120, 160, 255)) }),
})
local jarHint = label({ Text = "", TextSize = 11, TextColor3 = C.red, Position = UDim2.new(0, 14, 0, 50), Size = UDim2.new(1, -28, 0, 14), Parent = hud })

label({ Text = "ESSENCE", TextSize = 12, TextColor3 = C.dim, Position = UDim2.new(0, 14, 0, 76), Size = UDim2.new(0, 100, 0, 16), Parent = hud })
local essenceValue = label({ Text = "0", TextSize = 24, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 68), Size = UDim2.new(0, 160, 0, 30), Parent = hud })

----------------------------------------------------------------------
-- Quest tracker (top-right)
----------------------------------------------------------------------
local quest = panel({ Name = "QuestTracker", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 290, 0, 104), Parent = gui })
label({ Text = "QUEST", TextSize = 12, TextColor3 = C.dim, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(0, 100, 0, 16), Parent = quest })
local questTitle = label({ Text = "No active quest", TextSize = 16, TextColor3 = C.teal, Position = UDim2.new(0, 14, 0, 26), Size = UDim2.new(1, -28, 0, 20), Parent = quest })
local questDesc = label({ Text = "Find Morty the Gravekeeper near the graveyard gate.", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 14, 0, 48), Size = UDim2.new(1, -28, 0, 32), Parent = quest })
local qBack = make("Frame", { BackgroundColor3 = C.deep, BorderSizePixel = 0, Position = UDim2.new(0, 14, 1, -20), Size = UDim2.new(1, -28, 0, 8), Visible = false, Parent = quest }, { corner(4) })
local qFill = make("Frame", { BackgroundColor3 = C.gold, BorderSizePixel = 0, Size = UDim2.new(0, 0, 1, 0), Parent = qBack }, { corner(4) })

----------------------------------------------------------------------
-- Toasts (bottom-center)
----------------------------------------------------------------------
local toastHolder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.new(0, 460, 0, 220), Parent = gui }, {
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}),
})
local toastColors = { info = C.teal, good = C.gold, warn = C.red }
local toastOrder = 0

local function toast(text, kind)
	toastOrder += 1
	local color = toastColors[kind] or C.teal
	local t = make("TextLabel", {
		LayoutOrder = toastOrder,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = color,
		Text = text,
		Parent = toastHolder,
	}, {
		corner(10),
		stroke(color, 1.2, 0.5),
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }),
	})
	task.delay(3.6, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(t, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		for _, d in ipairs(t:GetDescendants()) do
			if d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.45)
		t:Destroy()
	end)
end

----------------------------------------------------------------------
-- Shop panel
----------------------------------------------------------------------
local shop = panel({ Name = "Shop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 440, 0, 400), Visible = false, Parent = gui })
label({ Text = "SOUL JAR UPGRADES", TextSize = 18, TextColor3 = C.teal, Position = UDim2.new(0, 18, 0, 14), Size = UDim2.new(1, -80, 0, 24), Parent = shop })
local shopEssence = label({ Text = "Essence: 0", TextSize = 13, TextColor3 = C.gold, Position = UDim2.new(0, 18, 0, 40), Size = UDim2.new(1, -36, 0, 18), Parent = shop })
local closeShop = make("TextButton", { Text = "X", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.new(0, 34, 0, 34), Parent = shop }, { corner(8) })
local list = make("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 68), Size = UDim2.new(1, -24, 1, -80), CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = shop }, {
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local rows = {}
for i, u in ipairs(Config.Upgrades) do
	local row = make("Frame", { LayoutOrder = i, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 78), Parent = list }, { corner(10) })
	label({ Text = u.name, TextSize = 16, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(0.55, 0, 0, 20), Parent = row })
	label({ Text = u.desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(0.58, 0, 0, 34), Parent = row })
	local lvl = label({ Text = "Lv 0", TextSize = 12, TextColor3 = C.purple, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.new(0, 100, 0, 16), Parent = row })
	local buy = make("TextButton", { Text = "Buy", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.deep, BackgroundColor3 = C.teal, BorderSizePixel = 0, AutoButtonColor = true, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.new(0, 132, 0, 32), Parent = row }, { corner(8) })
	buy.Activated:Connect(function()
		BuyUpgradeRE:FireServer(u.id)
	end)
	rows[u.id] = { level = lvl, button = buy }
end

local function renderShop()
	if not state then return end
	shopEssence.Text = "Essence: " .. fmt(state.essence)
	for _, u in ipairs(Config.Upgrades) do
		local level = state.upgrades[u.id] or 0
		local r = rows[u.id]
		r.level.Text = ("Lv %d / %d"):format(level, u.maxLevel)
		local cost = Config.upgradeCost(u.id, level)
		if not cost then
			r.button.Text = "MAX"
			r.button.BackgroundColor3 = C.dim
		elseif state.essence >= cost then
			r.button.Text = ("Buy: %s"):format(fmt(cost))
			r.button.BackgroundColor3 = C.teal
		else
			r.button.Text = ("Need: %s"):format(fmt(cost))
			r.button.BackgroundColor3 = Color3.fromRGB(90, 80, 115)
		end
	end
end

----------------------------------------------------------------------
-- Dialogue panel
----------------------------------------------------------------------
local dialogue = panel({ Name = "Dialogue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0, 540, 0, 150), Visible = false, Parent = gui })
local dName = label({ Text = "", TextSize = 18, TextColor3 = C.teal, Position = UDim2.new(0, 18, 0, 12), Size = UDim2.new(1, -60, 0, 24), Parent = dialogue })
local dText = label({ Text = "", Font = Enum.Font.Gotham, TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 18, 0, 40), Size = UDim2.new(1, -36, 0, 62), Parent = dialogue })
local dAction = make("TextButton", { Text = "", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.deep, BackgroundColor3 = C.gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -12), Size = UDim2.new(0, 260, 0, 32), Visible = false, Parent = dialogue }, { corner(8) })
local dClose = make("TextButton", { Text = "Leave", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -12), Size = UDim2.new(0, 90, 0, 32), Parent = dialogue }, { corner(8) })

local currentNpc = nil
local typeToken = 0
local dialogueOrigin, shopOrigin = nil, nil

local function rootPosition()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function typeText(text)
	typeToken += 1
	local token = typeToken
	dText.Text = text
	dText.MaxVisibleGraphemes = 0
	task.spawn(function()
		for i = 1, utf8.len(text) or #text do
			if token ~= typeToken then return end
			dText.MaxVisibleGraphemes = i
			task.wait(0.012)
		end
		dText.MaxVisibleGraphemes = -1
	end)
end

local function closeDialogue()
	typeToken += 1
	currentNpc = nil
	dialogue.Visible = false
end

local function showDialogue(npcId, name, text, action)
	if not name then return end
	local wasOpen = dialogue.Visible
	currentNpc = npcId
	dialogueOrigin = rootPosition()
	dName.Text = name
	typeText(text)
	dAction.Visible = action ~= nil
	dAction.Text = action or ""
	if not wasOpen then popIn(dialogue) end
end

dAction.Activated:Connect(function()
	if currentNpc then NpcActionRE:FireServer(currentNpc) end
end)
dClose.Activated:Connect(closeDialogue)

local function closeShopPanel()
	shop.Visible = false
end
closeShop.Activated:Connect(closeShopPanel)

-- auto-close panels if the player walks away
task.spawn(function()
	while true do
		task.wait(0.4)
		local pos = rootPosition()
		if pos then
			if dialogue.Visible and dialogueOrigin and (pos - dialogueOrigin).Magnitude > 22 then closeDialogue() end
			if shop.Visible and shopOrigin and (pos - shopOrigin).Magnitude > 30 then closeShopPanel() end
		end
	end
end)

----------------------------------------------------------------------
-- Rendering state
----------------------------------------------------------------------
local function render()
	if not state then return end
	local pct = math.clamp(state.souls / math.max(state.capacity, 1), 0, 1)
	TweenService:Create(barFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	jarValue.Text = ("%s / %s"):format(fmt(state.souls), fmt(state.capacity))
	essenceValue.Text = fmt(state.essence)

	if state.souls >= state.capacity then
		barFill.BackgroundColor3 = C.red
		jarHint.Text = "JAR FULL - convert at your own roost"
	else
		barFill.BackgroundColor3 = C.teal
		jarHint.Text = ""
	end

	local q = state.quest
	if q then
		questTitle.Text = q.title
		qBack.Visible = true
		TweenService:Create(qFill, TweenInfo.new(0.2), { Size = UDim2.new(math.clamp(q.progress / q.goal, 0, 1), 0, 1, 0) }):Play()
		if q.ready then
			questDesc.Text = "Done! Return to " .. q.npc
			questDesc.TextColor3 = C.gold
		else
			questDesc.Text = ("%s  (%d/%d)"):format(q.desc, q.progress, q.goal)
			questDesc.TextColor3 = C.text
		end
	else
		questTitle.Text = "No active quest"
		questDesc.Text = "Talk to the villagers (look for the Talk prompt) to get quests."
		questDesc.TextColor3 = C.text
		qBack.Visible = false
	end

	renderShop()
end

StateRE.OnClientEvent:Connect(function(newState)
	state = newState
	render()
end)

NotifyRE.OnClientEvent:Connect(function(text, kind)
	if typeof(text) == "string" then
		toast(text, kind)
	end
end)

OpenShopRE.OnClientEvent:Connect(function()
	shopOrigin = rootPosition()
	renderShop()
	popIn(shop)
end)

DialogueRE.OnClientEvent:Connect(function(npcId, name, text, action)
	showDialogue(npcId, name, text, action)
end)

----------------------------------------------------------------------
-- Quest log (button + Q key) and helpers counter
----------------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local HelperFXRE = Remotes:WaitForChild("HelperFX")

local logButton = make("TextButton", {
	Text = "QUESTS  [Q]", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text,
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0,
	Position = UDim2.new(0, 16, 0, 140), Size = UDim2.new(0, 136, 0, 32), Parent = gui,
}, { corner(10), stroke(C.purple, 1.2, 0.4) })

local helperBadge = panel({ Name = "HelperBadge", Position = UDim2.new(0, 16, 0, 180), Size = UDim2.new(0, 136, 0, 32), Parent = gui })
local helperText = label({ Text = "HELPERS  0 / 10", TextSize = 13, TextColor3 = C.teal, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = helperBadge })

local logPanel = panel({ Name = "QuestLog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 470, 0, 430), Visible = false, Parent = gui })
label({ Text = "QUEST LOG", TextSize = 20, TextColor3 = C.teal, Position = UDim2.new(0, 18, 0, 14), Size = UDim2.new(0.6, 0, 0, 26), Parent = logPanel })
local logCount = label({ Text = "", TextSize = 13, TextColor3 = C.gold, Position = UDim2.new(0, 18, 0, 42), Size = UDim2.new(1, -36, 0, 18), Parent = logPanel })
local logClose = make("TextButton", { Text = "X", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.new(0, 34, 0, 34), Parent = logPanel }, { corner(8) })
local logList = make("ScrollingFrame", {
	BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 12, 0, 68), Size = UDim2.new(1, -24, 1, -80),
	CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, Parent = logPanel,
}, { make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local lastLog = nil
local statusInfo = {
	done = { text = "DONE", color = C.gold },
	active = { text = "IN PROGRESS", color = C.teal },
	available = { text = "AVAILABLE", color = C.text },
	locked = { text = "LOCKED", color = C.dim },
}

local function renderLog()
	if not lastLog then return end
	for _, child in ipairs(logList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local done = 0
	for i, q in ipairs(lastLog) do
		if q.status == "done" then done += 1 end
		local info = statusInfo[q.status]
		local row = make("Frame", { LayoutOrder = i, BackgroundColor3 = C.panel, BackgroundTransparency = q.status == "locked" and 0.5 or 0, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 62), Parent = logList }, { corner(10) })
		if q.status == "active" then stroke(C.teal, 1.5, 0.2).Parent = row end
		label({ Text = q.title, TextSize = 15, TextColor3 = q.status == "locked" and C.dim or C.text, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(0.62, 0, 0, 18), Parent = row })
		label({ Text = q.npc .. "  -  " .. q.desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.dim, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 12, 0, 26), Size = UDim2.new(1, -24, 0, 16), Parent = row })
		label({ Text = "+" .. q.reward .. " Essence", TextSize = 12, TextColor3 = C.gold, Position = UDim2.new(0, 12, 0, 42), Size = UDim2.new(0.5, 0, 0, 16), Parent = row })
		label({ Text = info.text, TextSize = 12, TextColor3 = info.color, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.new(0.35, 0, 0, 16), Parent = row })
	end
	logCount.Text = (" %d / %d quests complete"):format(done, #lastLog)
end

local function toggleLog()
	if logPanel.Visible then
		logPanel.Visible = false
	else
		renderLog()
		popIn(logPanel)
	end
end
logButton.Activated:Connect(toggleLog)
logClose.Activated:Connect(function() logPanel.Visible = false end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then toggleLog() end
end)

----------------------------------------------------------------------
-- Poltergeist helper ghosts (visual only; the server does the collecting)
----------------------------------------------------------------------
local helperFolder = workspace:FindFirstChild("MyHelpers") or Instance.new("Folder")
helperFolder.Name = "MyHelpers"
helperFolder.Parent = workspace
local ghosts = {}
local dashIndex = 0

local function ghostPart(name, shape, size, color, transparency, material)
	return make("Part", {
		Name = name, Shape = shape, Size = size, Color = color, Transparency = transparency, Material = material or Enum.Material.Neon,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = helperFolder,
	})
end

local GhostVisuals = require(ReplicatedStorage.Shared:WaitForChild("GhostVisuals"))
local function makeGhost()
 return { rig=GhostVisuals.create(helperFolder,"Poltergeist",Color3.fromRGB(180,234,227),1),pos=nil,dash=nil }
end

local function syncGhosts(count)
	count = math.clamp(count or 0, 0, 10)
	while #ghosts < count do table.insert(ghosts, makeGhost()) end
	while #ghosts > count do
		local g = table.remove(ghosts)
		g.rig:destroy()
	end
	helperText.Text = ("HELPERS  %d / 10"):format(count)
end

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then for _,g in ipairs(ghosts) do g.rig:hide() end;return end
	if #ghosts == 0 then return end
	local t = os.clock()
	for i, g in ipairs(ghosts) do
		-- trail behind the player in rows of three, behind the equipped team ghosts
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local yaw = CFrame.lookAt(root.Position, root.Position + flat)
		-- V formation behind the player: alternating left/right wings, centre lane left clear for the camera
		local side = (i % 2 == 1) and -1 or 1
		local k = math.ceil(i / 2)
		local target = (yaw * CFrame.new(side * (2.6 + k * 1.1), 2.4 + math.sin(t * 2 + i) * 0.3, 2.5 + k * 1.9)).Position
		if g.dash and t < g.dash.untilTime then
			target = g.dash.pos
		end
		g.pos = g.pos and g.pos:Lerp(target, 1-math.exp(-10*dt)) or target
		local lookAt = (g.dash and t < g.dash.untilTime) and g.dash.pos or (g.pos + flat * 10)
		local targetLook = Vector3.new(lookAt.X, g.pos.Y, lookAt.Z)
		local cf = (targetLook-g.pos).Magnitude > 0.01 and CFrame.lookAt(g.pos, targetLook) or CFrame.new(g.pos)
		g.rig:pose(cf,t,i,player:GetAttribute("ClientLowGraphics") or player:GetAttribute("ClientVFX")==false)
		if g.rig.model then
			local camPos = workspace.CurrentCamera.CFrame.Position
			local fade = math.clamp((7 - (g.pos - camPos).Magnitude) / 4, 0, 0.85)
			if fade ~= g.fade then
				g.fade = fade
				for _, d in ipairs(g.rig.model:GetDescendants()) do if d:IsA("BasePart") then d.LocalTransparencyModifier = fade end end
			end
		end
	end
end)

HelperFXRE.OnClientEvent:Connect(function(orbPosition)
	if typeof(orbPosition) ~= "Vector3" or #ghosts == 0 then return end
	dashIndex = dashIndex % #ghosts + 1
	ghosts[dashIndex].dash = { pos = orbPosition, untilTime = os.clock() + 0.5 }
end)

StateRE.OnClientEvent:Connect(function(newState)
	lastLog = newState.questLog
	syncGhosts(newState.helpers)
	if logPanel.Visible then renderLog() end
end)

----------------------------------------------------------------------
-- Graphics mode: Low turns off shadows, bloom, dynamic lights, particles and
-- all tagged fine detail. Remembered on the server; phones default to Low.
----------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local GraphicsRE = Remotes:WaitForChild("SetGraphics")

local lowMode = false
local graphicsApplied = false
local origRate = setmetatable({}, { __mode = "k" })     -- emitter -> original Rate
local lightsOff = setmetatable({}, { __mode = "k" })    -- lights we switched off
local savedLighting = nil

local graphicsButton = make("TextButton", {
	Text = "GRAPHICS: HIGH", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
	BackgroundColor3 = C.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0,
	Position = UDim2.new(0, 16, 0, 220), Size = UDim2.new(0, 136, 0, 32), Parent = gui,
}, { corner(10), stroke(C.purple, 1.2, 0.4) })

local function insideSoul(inst)
	local parent = inst.Parent
	return parent ~= nil and parent:GetAttribute("Zone") ~= nil
end

local function lowerInstance(d)
	if d:IsA("ParticleEmitter") then
		if d.Name ~= "Burst" and d.Name ~= "Sparks" and origRate[d] == nil then
			origRate[d] = d.Rate
			d.Rate = 0
		end
	elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
		if not insideSoul(d) and d.Enabled then
			lightsOff[d] = true
			d.Enabled = false
		end
	end
end

local function setDetail(part, visible)
	part.LocalTransparencyModifier = visible and 0 or 1
end

local function setLow(low)
	lowMode = low
	player:SetAttribute("ClientLowGraphics", low)
	graphicsButton.Text = low and "GRAPHICS: LOW" or "GRAPHICS: HIGH"

	if low then
		if not savedLighting then
			savedLighting = { shadows = Lighting.GlobalShadows, specular = Lighting.EnvironmentSpecularScale, effects = {} }
			for _, e in ipairs(Lighting:GetChildren()) do
				if e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect") then
					savedLighting.effects[e] = e.Enabled
				end
			end
		end
		Lighting.GlobalShadows = false
		Lighting.EnvironmentSpecularScale = 0
		for e in pairs(savedLighting.effects) do e.Enabled = false end
		pcall(function() workspace.Terrain.WaterWaveSize = 0; workspace.Terrain.WaterReflectance = 0 end)
		for _, d in ipairs(workspace:GetDescendants()) do lowerInstance(d) end
		for _, p in ipairs(CollectionService:GetTagged("FineDetail")) do setDetail(p, false) end
	else
		if savedLighting then
			Lighting.GlobalShadows = savedLighting.shadows
			Lighting.EnvironmentSpecularScale = savedLighting.specular
			for e, was in pairs(savedLighting.effects) do e.Enabled = was end
		end
		pcall(function() workspace.Terrain.WaterWaveSize = 0.12; workspace.Terrain.WaterReflectance = 0.25 end)
		for emitter, rate in pairs(origRate) do
			if emitter.Parent then emitter.Rate = rate end
		end
		table.clear(origRate)
		for light in pairs(lightsOff) do
			if light.Parent then light.Enabled = true end
		end
		table.clear(lightsOff)
		for _, p in ipairs(CollectionService:GetTagged("FineDetail")) do setDetail(p, true) end
	end
end

-- things that stream in while Low is on get lowered too
workspace.DescendantAdded:Connect(function(d)
	if lowMode then lowerInstance(d) end
end)
CollectionService:GetInstanceAddedSignal("FineDetail"):Connect(function(p)
	if lowMode and p:IsA("BasePart") then setDetail(p, false) end
end)

graphicsButton.Activated:Connect(function()
	setLow(not lowMode)
	GraphicsRE:FireServer(lowMode and "low" or "high")
	toast(lowMode and "Low graphics: faster, simpler visuals" or "High graphics restored", "info")
end)

StateRE.OnClientEvent:Connect(function(newState)
	if graphicsApplied then return end
	graphicsApplied = true
	local choice = newState.graphics
	local weakDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if choice == "low" or (choice ~= "high" and weakDevice) then
		setLow(true)
		if choice ~= "low" then toast("Low graphics enabled for your device. Tap GRAPHICS to change.", "info") end
	end
end)

----------------------------------------------------------------------
-- Zones: gate panel, veil walls, and "entering" banner
----------------------------------------------------------------------
local ZoneInfoRE = Remotes:WaitForChild("ZoneInfo")
local UnlockZoneRE = Remotes:WaitForChild("UnlockZone")
local ZoneEnterRE = Remotes:WaitForChild("ZoneEnter")

local gatePanel = panel({ Name = "GatePanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 470, 0, 340), Visible = false, Parent = gui })
local gateTitle = label({ Text = "", TextSize = 20, TextColor3 = C.teal, Position = UDim2.new(0, 18, 0, 14), Size = UDim2.new(1, -80, 0, 26), Parent = gatePanel })
local gateStatus = label({ Text = "", TextSize = 14, TextColor3 = C.red, Position = UDim2.new(0, 18, 0, 42), Size = UDim2.new(1, -36, 0, 18), Parent = gatePanel })
label({ Text = "To enter, you need:", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.dim, Position = UDim2.new(0, 18, 0, 72), Size = UDim2.new(1, -36, 0, 18), Parent = gatePanel })
local gateClose = make("TextButton", { Text = "X", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text, BackgroundColor3 = C.panel, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.new(0, 34, 0, 34), Parent = gatePanel }, { corner(8) })
local gateRows = make("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 96), Size = UDim2.new(1, -28, 0, 170), Parent = gatePanel }, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local gateButton = make("TextButton", { Text = "", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = C.deep, BackgroundColor3 = C.gold, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(0, 300, 0, 38), Visible = false, Parent = gatePanel }, { corner(10) })

local currentGate = nil
local function renderGate(info)
	currentGate = info.id
	gateTitle.Text = string.upper(info.label)
	gateStatus.Text = info.unlocked and "UNLOCKED - you may pass" or "LOCKED"
	gateStatus.TextColor3 = info.unlocked and C.teal or C.red
	for _, child in ipairs(gateRows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for i, req in ipairs(info.reqs) do
		local row = make("Frame", { LayoutOrder = i, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, -4, 0, 32), Parent = gateRows }, { corner(8) })
		label({ Text = req.met and "DONE" or "NEED", TextSize = 12, TextColor3 = req.met and C.teal or C.red, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 48, 1, 0), Parent = row })
		label({ Text = req.text, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = req.met and C.text or C.dim, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 62, 0, 0), Size = UDim2.new(1, -72, 1, 0), Parent = row })
	end
	if info.pay and not info.unlocked then
		gateButton.Visible = true
		gateButton.Text = ("Unlock for %s Essence"):format(fmt(info.pay))
		gateButton.BackgroundColor3 = info.canUnlock and C.gold or Color3.fromRGB(90, 80, 115)
		gateButton.TextColor3 = info.canUnlock and C.deep or C.dim
	else
		gateButton.Visible = false
	end
end
ZoneInfoRE.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then return end
	local wasOpen = gatePanel.Visible
	renderGate(info)
	if not wasOpen then popIn(gatePanel) end
end)
gateButton.Activated:Connect(function()
	if currentGate then UnlockZoneRE:FireServer(currentGate) end
end)
gateClose.Activated:Connect(function() gatePanel.Visible = false end)

-- veil walls: visible only while the zone is still locked for you
local zoneOpen = {}
local function applyVeil(part)
	if not part:IsA("BasePart") then return end
	local locked = zoneOpen[part:GetAttribute("Zone")] ~= true
	part.LocalTransparencyModifier = locked and 0 or 1
	for _, e in ipairs(part:GetChildren()) do
		if e:IsA("ParticleEmitter") then e.Enabled = locked end
	end
end
CollectionService:GetInstanceAddedSignal("ZoneVeil"):Connect(applyVeil)
StateRE.OnClientEvent:Connect(function(newState)
	if typeof(newState.zones) ~= "table" then return end
	for _, z in ipairs(newState.zones) do zoneOpen[z.id] = z.unlocked end
	for _, p in ipairs(CollectionService:GetTagged("ZoneVeil")) do applyVeil(p) end
end)

-- "Entering ..." banner
local banner = label({
	Text = "", Font = Enum.Font.GothamBlack, TextSize = 34, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.new(0, 640, 0, 50),
	TextTransparency = 1, TextStrokeTransparency = 1, TextStrokeColor3 = C.deep, Parent = gui,
})
local bannerToken = 0
ZoneEnterRE.OnClientEvent:Connect(function(name)
	if typeof(name) ~= "string" then return end
	bannerToken += 1
	local token = bannerToken
	banner.Text = name
	TweenService:Create(banner, TweenInfo.new(0.35), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	task.delay(2.6, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

----------------------------------------------------------------------
-- Collecting tools: shop section, soul-pull effect, jar tier name
----------------------------------------------------------------------
local BuyToolRE = Remotes:WaitForChild("BuyTool")
local EquipToolRE=Remotes:WaitForChild("EquipTool")
local EquipStorageRE=Remotes:WaitForChild("EquipStorage")
local SoulPullRE = Remotes:WaitForChild("SoulPull")

local toolHeader = label({ LayoutOrder = 90, Text = "COLLECTORS · Equip one tool, then hold click to absorb", TextSize = 13, TextColor3 = C.gold, TextWrapped = true, Size = UDim2.new(1, -6, 0, 34), Parent = list })
local toolRows = {}
for i, t in ipairs(Config.Tools) do
	local tint = Color3.fromRGB(table.unpack(t.color))
	local row = make("Frame", { LayoutOrder = 100 + i, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 100), Parent = list }, { corner(10), stroke(tint, 1.2, 0.6) })
	label({ Text = t.name, TextSize = 16, TextColor3 = tint, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(0.6, 0, 0, 20), Parent = row })
	label({ Text = t.desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -164, 0, 36), Parent = row })
	label({
		Text = ("Reach %d · One grave · %.2fs pulse · %.1f pulses/sec"):format(t.range,t.cooldown,1/t.cooldown),
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.text, Position = UDim2.new(0, 12, 1, -26), Size = UDim2.new(1, -24, 0, 18), Parent = row,
	})
	local buy = make("TextButton", { Text = "Buy", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.deep, BackgroundColor3 = C.teal, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 128, 0, 30), Parent = row }, { corner(8) })
	buy.Activated:Connect(function()
 if state and state.tools and state.tools[t.id] then local selected=t.id;if state.equipment and state.equipment.tool==t.id then selected=false end;EquipToolRE:FireServer(selected) else BuyToolRE:FireServer(t.id) end
end)
	toolRows[t.id] = buy
end

local function renderTools(newState)
	if typeof(newState.tools) ~= "table" then return end
	for _, t in ipairs(Config.Tools) do
		local btn = toolRows[t.id]
		btn.TextSize = 13
		if newState.tools[t.id] then
			btn.Text = newState.equipment and newState.equipment.tool==t.id and "UNEQUIP" or "EQUIP"
			btn.BackgroundColor3 = C.dim
			btn.TextColor3 = C.deep
		elseif t.requiresTool and not newState.tools[t.requiresTool] then
			btn.Text = "PRIOR TOOL NEEDED"
			btn.TextSize = 10
			btn.BackgroundColor3 = Color3.fromRGB(90,80,115)
			btn.TextColor3 = C.text
		elseif newState.essence >= t.price then
			btn.Text = ("Buy: %s"):format(fmt(t.price))
			btn.BackgroundColor3 = C.teal
			btn.TextColor3 = C.deep
		else
			btn.Text = ("Need: %s"):format(fmt(t.price))
			btn.BackgroundColor3 = Color3.fromRGB(90, 80, 115)
			btn.TextColor3 = C.text
		end
	end
end

-- the HUD container label shows the jar's tier name
local jarTitleLabel
for _, c in ipairs(hud:GetChildren()) do
	if c:IsA("TextLabel") and c.Text == "SOUL JAR" then jarTitleLabel = c end
end

StateRE.OnClientEvent:Connect(function(newState)
	renderTools(newState)
	if jarTitleLabel and newState.upgrades then
		jarTitleLabel.Text = string.upper(newState.storageName or "NO STORAGE")
	end
end)

-- caught souls arc into your jar
local motes = {}
SoulPullRE.OnClientEvent:Connect(function(position, color)
	if typeof(position) ~= "Vector3" then return end
	local part = ghostPart("SoulMote", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), typeof(color) == "Color3" and color or Color3.new(1, 1, 1), 0.1)
	table.insert(motes, { part = part, start = position, t0 = os.clock() })
end)
RunService.RenderStepped:Connect(function()
	if #motes == 0 then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	for i = #motes, 1, -1 do
		local m = motes[i]
		local a = (os.clock() - m.t0) / 0.5
		if a >= 1 or not root then
			m.part:Destroy()
			table.remove(motes, i)
		else
			local target = root.Position + Vector3.new(0, 0.6, 0) + root.CFrame.LookVector * 1.2
			m.part.Position = m.start:Lerp(target, a * a) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
			local s2 = 0.9 * (1 - a * 0.6)
			m.part.Size = Vector3.new(s2, s2, s2)
		end
	end
end)

----------------------------------------------------------------------
-- Spirit Emporium: tabbed shop (Tools / Storage / Upgrades)
----------------------------------------------------------------------
local BuyStorageRE = Remotes:WaitForChild("BuyStorage")

shop.Size = UDim2.new(0, 560, 0, 480)
for _, c in ipairs(shop:GetChildren()) do
	if c:IsA("TextLabel") and c.Text == "SOUL JAR UPGRADES" then c.Text = string.upper(Config.ShopName) end
	if c:IsA("ScrollingFrame") then
		c.Position = UDim2.new(0, 12, 0, 108)
		c.Size = UDim2.new(1, -24, 1, -120)
	end
end

-- section headers inside the tools tab
toolHeader.Text = "SOUL VACUUMS  -  aim at a glowing grave and click"
toolHeader.LayoutOrder = 100
for _, child in ipairs(list:GetChildren()) do
	if child:IsA("Frame") and child.LayoutOrder >= 101 and child.LayoutOrder < 200 then
		local t = Config.Tools[child.LayoutOrder - 100]
		if t and t.kind == "dig" then child.LayoutOrder += 1 end
	end
end
local digIndex = 0
for i, t in ipairs(Config.Tools) do if t.kind == "dig" and digIndex == 0 then digIndex = i end end
label({ LayoutOrder = 100 + digIndex, Text = "DIGGING TOOLS  -  stand next to a grave and click to dig souls out", TextSize = 13, TextColor3 = C.gold, TextWrapped = true, Size = UDim2.new(1, -6, 0, 34), Parent = list })

-- storage rows
local storageRows = {}
local tierColors = {
	ClayJar = Color3.fromRGB(205, 140, 100), GlassJar = Color3.fromRGB(160, 215, 255), LanternJar = Color3.fromRGB(255, 205, 120),
	CrystalVessel = Color3.fromRGB(120, 255, 225), VoidUrn = Color3.fromRGB(200, 130, 255), AbyssCoffin = Color3.fromRGB(255, 90, 120),
}
label({ LayoutOrder = 200, Text = "STORAGE  -  bigger containers hold more souls and open new realms", TextSize = 13, TextColor3 = C.gold, TextWrapped = true, Size = UDim2.new(1, -6, 0, 34), Parent = list })
for i, item in ipairs(Config.JarTiers) do
	local tint = tierColors[item.id] or C.teal
	local row = make("Frame", { LayoutOrder = 200 + i, BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 86), Parent = list }, { corner(10) })
	local rowStroke = stroke(tint, 1.2, 0.6)
	rowStroke.Parent = row
	label({ Text = item.name, TextSize = 16, TextColor3 = tint, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(0.6, 0, 0, 20), Parent = row })
	label({ Text = item.desc, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.dim, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, 12, 0, 30), Size = UDim2.new(1, -168, 0, 32), Parent = row })
	label({ Text = ("Holds %s souls"):format(fmt(item.capacity)), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, Position = UDim2.new(0, 12, 1, -24), Size = UDim2.new(0.5, 0, 0, 18), Parent = row })
	local buy = make("TextButton", { Text = "Buy", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.deep, BackgroundColor3 = C.teal, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 132, 0, 30), Parent = row }, { corner(8) })
	buy.Activated:Connect(function()
 if state and state.ownedStorage and state.ownedStorage[item.id] then local selected=item.id;if state.equipment and state.equipment.storage==item.id then selected=false end;EquipStorageRE:FireServer(selected) else BuyStorageRE:FireServer(item.id) end
end)
	storageRows[item.id] = { button = buy, stroke = rowStroke }
end

local function renderStorage(newState)
	if not newState.upgrades then return end
	local level = newState.upgrades.JarSize or 0
	local current = Config.jarTier(level)
	for _, item in ipairs(Config.JarTiers) do
		local r = storageRows[item.id]
		r.button.TextSize = 13
		if newState.equipment and newState.equipment.storage==item.id then
			r.button.Text = "UNEQUIP"
			r.button.BackgroundColor3 = C.teal
			r.button.TextColor3 = C.deep
			r.stroke.Transparency = 0
		elseif newState.ownedStorage and newState.ownedStorage[item.id] then
			r.button.Text = "EQUIP"
			r.button.BackgroundColor3 = C.dim
			r.button.TextColor3 = C.deep
			r.stroke.Transparency = 0.6
		elseif item.requiresStorage and not (newState.ownedStorage and newState.ownedStorage[item.requiresStorage]) then
			r.button.Text = "PRIOR JAR NEEDED"
			r.button.TextSize = 10
			r.button.BackgroundColor3 = Color3.fromRGB(90,80,115)
			r.button.TextColor3 = C.text
			r.stroke.Transparency = .6
		elseif newState.essence >= item.price then
			r.button.Text = ("Buy: %s"):format(fmt(item.price))
			r.button.BackgroundColor3 = C.gold
			r.button.TextColor3 = C.deep
			r.stroke.Transparency = 0.6
		else
			r.button.Text = ("Need: %s"):format(fmt(item.price))
			r.button.BackgroundColor3 = Color3.fromRGB(90, 80, 115)
			r.button.TextColor3 = C.text
			r.stroke.Transparency = 0.6
		end
	end
end
StateRE.OnClientEvent:Connect(renderStorage)

-- tabs
local tabNames = { "TOOLS", "STORAGE", "UPGRADES" }
local tabButtons = {}
local currentTab = "TOOLS"
local function showTab(name)
	currentTab = name
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then
			local lo = child.LayoutOrder
			child.Visible = (name == "UPGRADES" and lo < 90) or (name == "TOOLS" and lo >= 90 and lo < 200) or (name == "STORAGE" and lo >= 200)
		end
	end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and C.purple or C.panel
		b.TextColor3 = (n == name) and C.text or C.dim
	end
	list.CanvasPosition = Vector2.new(0, 0)
end
for i, n in ipairs(tabNames) do
	local b = make("TextButton", {
		Text = n, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.dim, BackgroundColor3 = C.panel, BorderSizePixel = 0,
		Position = UDim2.new(0, 18 + (i - 1) * 140, 0, 66), Size = UDim2.new(0, 130, 0, 32), Parent = shop,
	}, { corner(8) })
	b.Activated:Connect(function() showTab(n) end)
	tabButtons[n] = b
end
showTab("TOOLS")
OpenShopRE.OnClientEvent:Connect(function() showTab(currentTab) end)

-- Fit every modal to small windows without overlapping its own controls.
local modalSizes = {[shop]=Vector2.new(560,480),[dialogue]=Vector2.new(540,150),[logPanel]=Vector2.new(470,430),[gatePanel]=Vector2.new(470,340)}
local function fitPanels()
	local camera=workspace.CurrentCamera
	if not camera then return end
	for frame,size in pairs(modalSizes) do
		local scale=frame:FindFirstChild("ResponsiveScale") or Instance.new("UIScale")
		scale.Name="ResponsiveScale";scale.Parent=frame
		scale.Scale=math.min(1,(camera.ViewportSize.X-24)/size.X,(camera.ViewportSize.Y-60)/size.Y)
	end
	questTitle.TextTruncate=Enum.TextTruncate.AtEnd
	dAction.TextTruncate=Enum.TextTruncate.AtEnd
end
fitPanels()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanels) end
----------------------------------------------------------------------
-- Boss health bar (top centre)
----------------------------------------------------------------------
local BossStateRE = Remotes:WaitForChild("BossState")
local bossBar = panel({ Name = "BossBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(0, 480, 0, 72), Visible = false, Parent = gui })
stroke(C.red, 2, 0.2).Parent = bossBar
local bossName = label({ Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(255, 120, 140), Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(0.68, 0, 0, 22), Parent = bossBar })
local bossArea = label({ Text = "", TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.new(0.4, 0, 0, 16), Parent = bossBar })
local hpBack = make("Frame", { BackgroundColor3 = C.deep, BorderSizePixel = 0, Position = UDim2.new(0, 16, 0, 38), Size = UDim2.new(1, -32, 0, 20), Parent = bossBar }, { corner(6) })
local hpFill = make("Frame", { BackgroundColor3 = Color3.fromRGB(255, 110, 130), BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0), Parent = hpBack }, { corner(6) })
local hpText = label({ Text = "", TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = hpBack })

BossStateRE.OnClientEvent:Connect(function(s)
	if typeof(s) ~= "table" or not s.active then
		bossBar.Visible = false
		return
	end
	if not bossBar.Visible then popIn(bossBar) end
	bossName.Text = "BOSS: " .. tostring(s.name) .. (s.enraged and "  (ENRAGED)" or "")
	bossArea.Text = tostring(s.area) .. "  " .. string.rep("*", s.tier or 1)
	local pct = math.clamp((s.hp or 0) / math.max(s.maxHp or 1, 1), 0, 1)
	TweenService:Create(hpFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
	hpFill.BackgroundColor3 = s.enraged and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 110, 130)
	hpText.Text = ("%s / %s"):format(fmt(s.hp or 0), fmt(s.maxHp or 0))
end)

RequestStateRE:FireServer()

Remotes:WaitForChild("ProfileState").OnClientEvent:Connect(function(profile)
 if typeof(profile)~="table" then return end
 local g=profile.graphics or "auto"
 setLow(g=="low" or (g=="auto" and game:GetService("UserInputService").TouchEnabled))
 graphicsButton.Visible=false
 player:SetAttribute("VFXRefresh",os.clock())
end)
graphicsButton.Visible=false

-- Unified menu routes; local bindable events never grant gameplay rewards.
logButton.Visible=false
local menuBus=player.PlayerGui:WaitForChild("HarvestMenuOpen")
menuBus.Event:Connect(function(name)
 shop.Visible=false;logPanel.Visible=false
 if name=="Quests" then toggleLog()
 elseif name=="Equipment" then shopOrigin=nil;shop.Visible=true;showTab("TOOLS");RequestStateRE:FireServer() end
end)
local function menuHudFit()
 local camera=workspace.CurrentCamera;if not camera then return end
 local w=camera.ViewportSize.X;local width=math.min(270,(w-40)/2)
 hud.Position=UDim2.fromOffset(16,16);hud.Size=UDim2.fromOffset(width,116)
 quest.Position=UDim2.new(1,-16,0,16);quest.Size=UDim2.fromOffset(math.min(290,(w-40)/2),104)
 helperBadge.Visible=false
 bossBar.AnchorPoint=Vector2.new(.5,1);bossBar.Position=UDim2.new(.5,0,1,-28);bossBar.Size=UDim2.fromOffset(math.min(480,w-24),72)
end
menuHudFit();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(menuHudFit) end
