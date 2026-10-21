local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Run=game:GetService("RunService")
local CS=game:GetService("CollectionService")
local player=Players.LocalPlayer
local remotes=RS:WaitForChild("Remotes")
local action=remotes:WaitForChild("ExpeditionAction")
local state=remotes:WaitForChild("ExpeditionState")
local gui=Instance.new("ScreenGui");gui.Name="ExpeditionHUD";gui.ResetOnSpawn=false;gui.DisplayOrder=8;gui.Parent=player:WaitForChild("PlayerGui")
local function rounded(obj)
	local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,9);c.Parent=obj
end
local function button(parent,text,size,pos)
	local b=Instance.new("TextButton");b.Size=size;b.Position=pos;b.Text=text;b.Font=Enum.Font.GothamBold;b.TextSize=13;b.TextColor3=Color3.fromRGB(220,250,239);b.BackgroundColor3=Color3.fromRGB(34,52,61);b.BorderSizePixel=0;b.Parent=parent;rounded(b);return b
end
local journalButton=button(gui,"Journal  [J]",UDim2.fromOffset(136,34),UDim2.new(1,-152,.5,70))
local sprint=button(gui,"Sprint  [Shift]",UDim2.fromOffset(136,34),UDim2.new(1,-152,.5,110))
local bar=Instance.new("Frame");bar.Position=UDim2.new(1,-152,.5,150);bar.Size=UDim2.fromOffset(136,5);bar.BackgroundColor3=Color3.fromRGB(32,36,49);bar.BorderSizePixel=0;bar.Parent=gui;rounded(bar)
local fill=Instance.new("Frame");fill.Size=UDim2.fromScale(1,1);fill.BackgroundColor3=Color3.fromRGB(125,231,192);fill.BorderSizePixel=0;fill.Parent=bar;rounded(fill)
local speedLabel=Instance.new("TextLabel");speedLabel.BackgroundTransparency=1;speedLabel.Size=UDim2.fromOffset(136,24);speedLabel.Position=UDim2.new(1,-152,.5,155);speedLabel.Text="";speedLabel.TextSize=11;speedLabel.Font=Enum.Font.Gotham;speedLabel.TextColor3=Color3.fromRGB(213,226,239);speedLabel.Parent=gui
local panel=Instance.new("Frame");panel.Name="ExpeditionJournal";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(430,490);panel.BackgroundColor3=Color3.fromRGB(21,28,39);panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;rounded(panel)
local scale=Instance.new("UIScale");scale.Parent=panel
local function resize()
	local cam=workspace.CurrentCamera
	if cam then scale.Scale=math.min(1,(cam.ViewportSize.X-24)/430,(cam.ViewportSize.Y-40)/490) end
end
resize()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local title=Instance.new("TextLabel");title.Size=UDim2.new(1,-70,0,46);title.Position=UDim2.fromOffset(18,0);title.BackgroundTransparency=1;title.Text="EXPLORER'S JOURNAL";title.Font=Enum.Font.GothamBold;title.TextSize=19;title.TextXAlignment=Enum.TextXAlignment.Left;title.TextColor3=Color3.fromRGB(182,244,217);title.Parent=panel
local close=button(panel,"×",UDim2.fromOffset(32,32),UDim2.new(1,-42,0,8));close.Activated:Connect(function() panel.Visible=false end)
local list=Instance.new("ScrollingFrame");list.Size=UDim2.new(1,-28,1,-62);list.Position=UDim2.fromOffset(14,50);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
local latest=nil
local renderedKey=""
local sprintWanted=false
local function requestSprint(wanted)
	sprintWanted=wanted
	action:FireServer("Sprint",wanted)
end
sprint.Activated:Connect(function() requestSprint(not sprintWanted) end)
CAS:BindAction("HighlandSprint",function(_,inputState)
	if inputState==Enum.UserInputState.Begin and UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if inputState==Enum.UserInputState.Begin then requestSprint(true)
	elseif inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then requestSprint(false) end
	return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.LeftShift)
CAS:BindAction("HighlandControllerSprint",function(_,inputState)
	if inputState==Enum.UserInputState.Begin then requestSprint(not sprintWanted) end
	return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.ButtonL3)
UIS.WindowFocusReleased:Connect(function() requestSprint(false) end)
local function toggle()
	panel.Visible=not panel.Visible
	if panel.Visible then action:FireServer("State") end
end
journalButton.Activated:Connect(toggle)
UIS.InputBegan:Connect(function(input,processed)
	if not processed and input.KeyCode==Enum.KeyCode.J then toggle() end
end)
local destinations={{"Home","Mansion"},{"Moonveil","Moonveil Memorial"},{"Briarwatch","Briarwatch Heights"},{"Starfall","Starfall Necropolis"},{"Crownrest","Crownrest Summit"},{"HollowCaverns","Hollow Caverns"}}
local function textRow(text,height,color)
	local t=Instance.new("TextLabel");t.Size=UDim2.new(1,-8,0,height);t.BackgroundTransparency=1;t.Text=text;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Top;t.Font=Enum.Font.Gotham;t.TextSize=13;t.TextColor3=color or Color3.fromRGB(200,211,221);t.Parent=list;return t
end
local function rebuild(s)
	local key=tostring(s.checkpoint)..":"..#s.lore
	for _,d in ipairs(destinations) do key..=tostring(s.waypoints[d[1]]) end
	if renderedKey==key then return end
	renderedKey=key
	for _,c in ipairs(list:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local order=0
	local function orderRow(obj) order+=1;obj.LayoutOrder=order;return obj end
	orderRow(textRow("WAYSTONES\nActivate a waystone in each region to unlock travel and set your respawn checkpoint.",48,Color3.fromRGB(166,235,210)))
	for _,d in ipairs(destinations) do
		local unlocked=s.waypoints[d[1]]==true
		local b=button(list,(unlocked and "Travel · " or "Locked · ")..d[2]..(s.checkpoint==d[1] and "  [checkpoint]" or ""),UDim2.new(1,-8,0,34),UDim2.new())
		orderRow(b);b.AutoButtonColor=unlocked
		if not unlocked then b.BackgroundColor3=Color3.fromRGB(42,44,52);b.TextColor3=Color3.fromRGB(136,141,153) end
		b.Activated:Connect(function() if unlocked then action:FireServer("Travel",d[1]);panel.Visible=false end end)
	end
	orderRow(textRow(("MEMORY ARCHIVE · %d / 8\nFind inscribed stones near chapels, crypts and hunter camps."):format(#s.lore),48,Color3.fromRGB(211,183,244)))
	for _,entry in ipairs(s.lore) do
		orderRow(textRow(entry.title,22,Color3.fromRGB(243,211,153)))
		orderRow(textRow(entry.text,70))
	end
	orderRow(textRow("FIELD NOTES\nGraves refill gradually. Upgrade Spectral Boots at a Field Outfitter. Sprint lasts 10 seconds; rest to recover. Field caches can be opened once each day.",85))
end
state.OnClientEvent:Connect(function(s)
	if s.partial then
		if not latest then action:FireServer("State");return end
		for k,v in pairs(s) do if k~="partial" then latest[k]=v end end
		latest.open=false;s=latest
	else latest=s end
	sprintWanted=s.sprinting
	fill.Size=UDim2.fromScale(math.clamp(s.stamina/100,0,1),1)
	sprint.Text=s.sprinting and "Sprinting · Stop" or (UIS.TouchEnabled and "Tap to sprint" or "Sprint  [Shift]")
	speedLabel.Text=("Speed %d  ·  Energy %d%%"):format(s.speed+(s.sprinting and 8 or 0),s.stamina)
	rebuild(s)
	if s.open then panel.Visible=true end
end)
action:FireServer("State")
-- Nearby grave spirits bob gently; distant models remain still.
local ghosts={}
local function add(m)
	if m:IsA("Model") then ghosts[m]=m:GetAttribute("RestPivot") or m:GetPivot() end
end
for _,m in ipairs(CS:GetTagged("GraveSoulVisual")) do add(m) end
CS:GetInstanceAddedSignal("GraveSoulVisual"):Connect(add)
CS:GetInstanceRemovedSignal("GraveSoulVisual"):Connect(function(m) ghosts[m]=nil end)
local elapsed=0
Run.RenderStepped:Connect(function(dt)
	elapsed+=dt;if elapsed<(player:GetAttribute("ClientLowGraphics") and .1 or 1/30) then return end;elapsed=0
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local now=os.clock()
	for m,base in pairs(ghosts) do
		if m.Parent and (base.Position-root.Position).Magnitude<90 then
			local phase=base.Position.X*.11+base.Position.Z*.07
			m:PivotTo(base*CFrame.new(0,math.sin(now*1.8+phase)*.19,0)*CFrame.Angles(0,math.sin(now+phase)*.12,0))
		end
	end
end)

-- Keep reserve labels readable in dense graveyards.
local graveParts={}
local function trackGrave(part) if part:IsA("BasePart") then graveParts[part]=true end end
for _,part in ipairs(CS:GetTagged("DigSpot")) do trackGrave(part) end
CS:GetInstanceAddedSignal("DigSpot"):Connect(trackGrave)
CS:GetInstanceRemovedSignal("DigSpot"):Connect(function(part) graveParts[part]=nil end)
task.spawn(function()
	while gui.Parent do
		task.wait(.5)
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local nearby={}
		if root then
			for part in pairs(graveParts) do
				if part.Parent then
					local distance=(part.Position-root.Position).Magnitude
					if distance<=24 then table.insert(nearby,{part=part,distance=distance}) end
				end
			end
		end
		table.sort(nearby,function(a,b) return a.distance<b.distance end)
		local visible={}
		for i=1,math.min(4,#nearby) do visible[nearby[i].part]=true end
		for part in pairs(graveParts) do
			local display=part:FindFirstChild("SoulReserveDisplay")
			if display then display.Enabled=visible[part]==true end
		end
	end
end)
