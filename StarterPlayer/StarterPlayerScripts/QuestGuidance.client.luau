local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local R=game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local P=Players.LocalPlayer
local gui=Instance.new("ScreenGui");gui.Name="QuestGuidance";gui.ResetOnSpawn=false;gui.DisplayOrder=8;gui.Parent=P:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.Name="Waypoint";label.AnchorPoint=Vector2.new(.5,.5);label.Size=UDim2.fromOffset(240,56);label.BackgroundColor3=Color3.fromRGB(22,26,39);label.BackgroundTransparency=.15;label.BorderSizePixel=0;label.Font=Enum.Font.GothamBold;label.TextColor3=Color3.fromRGB(255,226,139);label.TextSize=14;label.TextWrapped=true;label.Visible=false;label.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=label
local stroke=Instance.new("UIStroke");stroke.Color=label.TextColor3;stroke.Transparency=.3;stroke.Parent=label
local target=nil;local enabled=true;local elapsed=0
R.State.OnClientEvent:Connect(function(s) target=s.quest end)
R.ProfileState.OnClientEvent:Connect(function(s) enabled=s.settings.waypoints~=false end)
Run.RenderStepped:Connect(function(dt)
 elapsed+=dt;if elapsed<.05 then return end;elapsed=0
 local c=workspace.CurrentCamera;local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart")
 if not enabled or not target or typeof(target.targetPosition)~="Vector3" or not c or not root then label.Visible=false;return end
 local goal=target.targetPosition+Vector3.new(0,5,0);local p,onScreen=c:WorldToViewportPoint(goal);local view=c.ViewportSize
 local center=Vector2.new(view.X/2,view.Y/2)
 local point=Vector2.new(p.X,p.Y);local dir=point-center;if p.Z<0 then dir=-dir end
 if not onScreen or p.X<130 or p.X>view.X-130 or p.Y<100 or p.Y>view.Y-120 then
  if dir.Magnitude<.01 then dir=Vector2.new(0,1) end
  local t=math.min((view.X/2-130)/math.max(math.abs(dir.X),.01),(view.Y/2-120)/math.max(math.abs(dir.Y),.01))
  point=center+dir*t
 end
 label.Position=UDim2.fromOffset(math.clamp(point.X,125,math.max(125,view.X-125)),math.clamp(point.Y,90,math.max(90,view.Y-115)))
 local distance=math.floor((target.targetPosition-root.Position).Magnitude)
 local direction=onScreen and "◆ " or (math.abs(dir.X)>math.abs(dir.Y) and (dir.X>0 and "→ " or "← ") or (dir.Y>0 and "↓ " or "↑ "))
 label.Text=direction..(target.targetLabel or "Quest destination").."\n"..distance.." studs";label.Visible=true
end)
