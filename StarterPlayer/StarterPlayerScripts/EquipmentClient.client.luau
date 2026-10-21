local P=game:GetService("Players").LocalPlayer
local R=game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local input=game:GetService("UserInputService")
local intent=R:WaitForChild("CollectIntent")
local hold=true;local active=nil;local watched=setmetatable({},{__mode="k"})
local function stop() if active then intent:FireServer(active,false);active=nil end end
R.ProfileState.OnClientEvent:Connect(function(s) hold=s.settings.holdCollect~=false;if not hold then stop() end end)
local function watch(tool)
 if not tool:IsA("Tool") or watched[tool] then return end;watched[tool]=true
 tool.Activated:Connect(function()
  local id=tool:GetAttribute("ToolId")
  if hold and typeof(id)=="string" and tool.Parent==P.Character and not input:GetFocusedTextBox() then active=id;intent:FireServer(id,true) end
 end)
 tool.Deactivated:Connect(stop);tool.Unequipped:Connect(stop)
end
local function character(c) stop();for _,t in c:GetChildren() do watch(t) end;c.ChildAdded:Connect(watch) end
P.CharacterAdded:Connect(character);if P.Character then character(P.Character) end
local bag=P:WaitForChild("Backpack");bag.ChildAdded:Connect(watch);for _,t in bag:GetChildren() do watch(t) end
input.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch or i.KeyCode==Enum.KeyCode.ButtonR2 then stop() end end)
input.WindowFocusReleased:Connect(stop)
P:GetAttributeChangedSignal("Refining"):Connect(function() if P:GetAttribute("Refining") then stop() end end)
task.spawn(function() while true do task.wait(1);if active then intent:FireServer(active,true) end end end)
