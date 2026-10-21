-- Consistent menu transitions without changing server actions or responsive layouts.
local Tween=game:GetService("TweenService")
local P=game.Players.LocalPlayer
local pg=P:WaitForChild("PlayerGui")
local allowed={HauntedHUD=true,HarvestMenu=true,SettingsAndRobux=true,SpiritLodgeHUD=true,ExpeditionHUD=true,QuestGuidance=true}
local bound=setmetatable({},{__mode="k"})
local active=setmetatable({},{__mode="k"})
local function insideClone(v)
 local a=v
 while a and a~=pg do if a:GetAttribute("MotionClone") then return true end;a=a.Parent end
 return false
end
local function tween(o,seconds,values,style)
 if active[o] then active[o]:Cancel() end
 local t=Tween:Create(o,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,Enum.EasingDirection.Out),values);active[o]=t;t:Play();return t
end
local function bind(v)
 if bound[v] or insideClone(v) then return end
 local screen=v:FindFirstAncestorOfClass("ScreenGui")
 if not screen or not allowed[screen.Name] then return end
 if v:IsA("GuiButton") then
  bound[v]=true;local scale=v:FindFirstChild("ButtonMotionScale") or Instance.new("UIScale");scale.Name="ButtonMotionScale";scale.Parent=v
  local hover=false;local down=false
  local function update() tween(scale,.12,{Scale=down and .94 or hover and 1.035 or 1}) end
  v.MouseEnter:Connect(function() hover=true;update() end)
  v.MouseLeave:Connect(function() hover=false;down=false;update() end)
  v.MouseButton1Down:Connect(function() down=true;update() end)
  v.MouseButton1Up:Connect(function() down=false;update() end)
  v.SelectionGained:Connect(function() hover=true;update() end)
  v.SelectionLost:Connect(function() hover=false;down=false;update() end)
  v.Activated:Connect(function() down=false;tween(scale,.2,{Scale=hover and 1.035 or 1},Enum.EasingStyle.Back) end)
 elseif v:IsA("Frame") and v.Parent==screen and v.Size.X.Offset>=300 and v.Size.Y.Offset>=180 then
  bound[v]=true
  local resting=v.Position
  local function changed()
   if v.Visible then
    if active[v] then active[v]:Cancel() end
    v.Position=resting+UDim2.fromOffset(0,18)
    tween(v,.23,{Position=resting},Enum.EasingStyle.Quart)
   else
    if active[v] then active[v]:Cancel() end
    local copy=v:Clone()
    if not copy then v.Position=resting;return end
    copy:SetAttribute("MotionClone",true);copy.Name="ClosingMenu";copy.Position=v.Position;copy.Visible=true
    for _,d in ipairs(copy:GetDescendants()) do
     if d:IsA("LuaSourceContainer") then d:Destroy()
     elseif d:IsA("GuiButton") then d.Active=false;d.Selectable=false
     elseif d:IsA("TextBox") then d.TextEditable=false;d.Active=false end
    end
    local group=Instance.new("CanvasGroup");group.Name="MenuExitAnimation";group:SetAttribute("MotionClone",true);group.BackgroundTransparency=1;group.Size=UDim2.fromScale(1,1);group.Active=false;group.Parent=screen
    copy.Parent=group;tween(copy,.14,{Position=resting+UDim2.fromOffset(0,10)})
    tween(group,.14,{GroupTransparency=1}).Completed:Once(function() group:Destroy() end)
    v.Position=resting
   end
  end
  v:GetPropertyChangedSignal("Visible"):Connect(changed)
 end
end
-- Defer until creator scripts have assigned sizes, names and children.
pg.DescendantAdded:Connect(function(v) task.defer(function() if v.Parent then bind(v) end end) end)
for _,v in ipairs(pg:GetDescendants()) do bind(v) end
