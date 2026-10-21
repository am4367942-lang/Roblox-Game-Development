local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Lighting=game:GetService("Lighting")
local P=game.Players.LocalPlayer
local C=require(RS.Shared.WorldCatalog)
local status=RS:WaitForChild("WorldWeather")
local root=Instance.new("Folder");root.Name="LocalWeather";root.Parent=workspace
local tone=Instance.new("ColorCorrectionEffect");tone.Name="WeatherGrade";tone.Parent=Lighting
local bloom=Instance.new("BloomEffect");bloom.Name="WeatherBloom";bloom.Intensity=.15;bloom.Size=32;bloom.Threshold=1.6;bloom.Parent=Lighting
local gui=Instance.new("ScreenGui");gui.Name="WeatherHUD";gui.ResetOnSpawn=false;gui.DisplayOrder=8;gui.Parent=P:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(1,0);label.Position=UDim2.new(1,-16,0,224);label.Size=UDim2.fromOffset(230,58);label.BackgroundColor3=Color3.fromRGB(24,27,43);label.BackgroundTransparency=.18;label.BorderSizePixel=0;label.TextColor3=Color3.fromRGB(227,237,255);label.Font=Enum.Font.GothamMedium;label.TextSize=12;label.TextWrapped=true;label.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=label
local stroke=Instance.new("UIStroke");stroke.Color=Color3.fromRGB(110,140,170);stroke.Transparency=.45;stroke.Parent=label
local baseClock=Lighting.ClockTime
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
local baseDensity=atmosphere and atmosphere.Density or .25
local rng=Random.new();local objects={};local ribbons={};local w=C.WeatherById.Clear;local graphics="auto";local enabled=true;local elapsed=0;local flashAt=0;local coverAt=0;local sheltered=false
local function part(name,size,color)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Color=color;p.Size=size;p.Transparency=.3;p.Parent=root;return p
end
local function rebuild()
 root:ClearAllChildren();objects={};ribbons={}
 w=C.WeatherById[status:GetAttribute("Id")] or C.WeatherById.Clear
 local color=Color3.fromRGB(table.unpack(w.color));local visible=enabled and graphics~="low" and w.id~="Clear"
 Tween:Create(tone,TweenInfo.new(4),{TintColor=visible and Color3.new(.85+color.R*.15,.85+color.G*.15,.85+color.B*.15) or Color3.new(1,1,1),Saturation=visible and .08 or 0,Brightness=visible and (w.effect=="eclipse" and -.1 or 0) or 0}):Play()
 if not visible then Tween:Create(Lighting,TweenInfo.new(3),{ClockTime=baseClock}):Play();if atmosphere then Tween:Create(atmosphere,TweenInfo.new(3),{Density=baseDensity}):Play() end;return end
 local night=w.effect=="aurora" or w.effect=="cosmic" or w.effect=="meteor" or w.effect=="eclipse" or w.effect=="moonbeams" or w.effect=="spirits" or w.effect=="fireflies"
 Tween:Create(Lighting,TweenInfo.new(5),{ClockTime=night and 0 or baseClock}):Play()
 if atmosphere then Tween:Create(atmosphere,TweenInfo.new(5),{Density=w.effect=="fog" and .45 or w.effect=="storm" and .36 or baseDensity}):Play() end
 local count=graphics=="high" and 110 or 60
 local rain=w.effect=="rain" or w.effect=="storm"
 for i=1,count do
  local size=rain and Vector3.new(.045,rng:NextNumber(1.2,2.5),.045) or Vector3.new(.16,.16,.16)
  if w.effect=="snow" or w.effect=="blizzard" then size=Vector3.new(.2,.08,.2) end
  if w.effect=="petals" or w.effect=="leaves" then size=Vector3.new(.36,.06,.22) end
  if w.effect=="meteor" then size=Vector3.new(.12,.12,8) end
  local p=part("WeatherMote",size,color)
  if w.effect=="fireflies" or w.effect=="motes" or w.effect=="spirits" then p.Shape=Enum.PartType.Ball end
  if w.effect=="spirits" then p.Shape=Enum.PartType.Block;local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.new(1,1.6,1);mesh.Parent=p;p.Size=Vector3.new(.65,.65,.65) end
  if w.effect=="crystals" then p.Size=Vector3.new(.15,.45,.15) end
  table.insert(objects,{part=p,offset=Vector3.new(rng:NextNumber(-55,55),rng:NextNumber(-5,48),rng:NextNumber(-55,55)),phase=rng:NextNumber(0,6.28),speed=rng:NextNumber(.7,1.3)})
 end
 if w.effect=="aurora" or w.effect=="cosmic" or w.effect=="rainbow" or w.effect=="moonbeams" or w.effect=="eclipse" then
  for i=1,18 do
   local a=part("SkyAnchor",Vector3.new(.1,.1,.1),color);a.Transparency=1
   local at=Instance.new("Attachment");at.Parent=a;local bt=Instance.new("Attachment");bt.Position=Vector3.new(20,0,0);bt.Parent=a
   local beam=Instance.new("Beam");beam.Attachment0=at;beam.Attachment1=bt;beam.Width0=18;beam.Width1=18;beam.FaceCamera=true;beam.Segments=16;beam.LightEmission=.6;beam.LightInfluence=0
   beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.4),NumberSequenceKeypoint.new(.7,.4),NumberSequenceKeypoint.new(1,1)})
   beam.Color=ColorSequence.new(color,Color3.fromHSV((i/30+.45)%1,.6,1));beam.Parent=a;table.insert(ribbons,{part=a,beam=beam,index=i})
  end
 end
 -- Soft layered haze stays outside the walking space and never blocks vision.
 if w.effect=="fog" or w.effect=="blizzard" then
  for i=1,7 do local p=part("MistBank",Vector3.new(90,10,35),color);p.Transparency=.96;local m=Instance.new("SpecialMesh");m.MeshType=Enum.MeshType.Sphere;m.Parent=p;table.insert(ribbons,{part=p,index=i,mist=true}) end
 end
end
status:GetAttributeChangedSignal("Id"):Connect(rebuild)
RS.Remotes.ProfileState.OnClientEvent:Connect(function(s) local nextEnabled=s.settings.vfx~=false;local nextGraphics=s.graphics or "auto";if nextEnabled~=enabled or nextGraphics~=graphics then enabled=nextEnabled;graphics=nextGraphics;rebuild() end end)
local function lightning(center)
 local start=center+Vector3.new(rng:NextNumber(-100,100),100,rng:NextNumber(-100,100));local previous=start
 for i=1,7 do local finish=start+Vector3.new(rng:NextNumber(-8,8),-i*12,rng:NextNumber(-8,8));local delta=finish-previous;local p=part("DistantLightning",Vector3.new(.18,.18,delta.Magnitude),Color3.fromRGB(215,225,255));p.CFrame=CFrame.lookAt((previous+finish)/2,finish);game.Debris:AddItem(p,.18);previous=finish end
end
Run.RenderStepped:Connect(function(dt)
 dt=math.min(dt,.1);elapsed+=dt;local camera=workspace.CurrentCamera;if not camera then return end
 local center=camera.CFrame.Position
 if elapsed>=coverAt then
  coverAt=elapsed+1;local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances={root,P.Character or root};sheltered=workspace:Raycast(center,Vector3.new(0,100,0),rp)~=nil
  local remaining=math.max(0,(status:GetAttribute(w.id=="Clear" and "NextAt" or "EndsAt") or os.time())-os.time())
  label.Text=w.name.."  ·  "..string.format("%02d:%02d",math.floor(remaining/60),remaining%60).."\n"..(w.id=="Clear" and "Next hourly weather roll" or (w.mutation.." souls · "..w.value.."× Essence"))
 end
 local rain=w.effect=="rain" or w.effect=="storm";local snow=w.effect=="snow" or w.effect=="blizzard"
 for i,o in ipairs(objects) do
  local speed=rain and 50 or snow and 6 or w.effect=="meteor" and 36 or 2.5
  o.offset-=Vector3.new((rain or w.effect=="blizzard") and 8*dt or 0,speed*dt*o.speed,0)
  if o.offset.Y< -8 then o.offset=Vector3.new(rng:NextNumber(-55,55),48,rng:NextNumber(-55,55)) end
  local offset=o.offset+Vector3.new(math.sin(elapsed*.5+o.phase)*2,0,math.cos(elapsed*.4+o.phase)*2)
  local p=o.part;p.Transparency=sheltered and 1 or (rain and .6 or .25+.15*math.sin(elapsed+o.phase))
  p.CFrame=CFrame.new(center+offset)*CFrame.Angles(rain and .15 or elapsed*.4+o.phase,0,w.effect=="meteor" and -.6 or .2)
 end
 for _,r in ipairs(ribbons) do
  local i=r.index
  if r.mist then r.part.Position=center+Vector3.new(math.sin(elapsed*.04+i)*60,-6+i*2,math.cos(elapsed*.03+i)*60);r.part.Transparency=sheltered and 1 or .96
  else local forward=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z);if forward.Magnitude<.01 then forward=Vector3.new(0,0,-1) else forward=forward.Unit end;local right=forward:Cross(Vector3.yAxis);local pos=center+forward*110+right*((i-9)*18)+Vector3.new(0,42+math.sin(i*.45+elapsed*.2)*12,0);r.part.CFrame=CFrame.lookAt(pos,pos+forward)*CFrame.Angles(0,0,math.sin(i*.3)*.3);r.beam.CurveSize0=math.sin(elapsed*.3+i)*12;r.beam.CurveSize1=-r.beam.CurveSize0;r.beam.Enabled=not sheltered end
 end
 if enabled and graphics~="low" and w.effect=="storm" and elapsed>flashAt then flashAt=elapsed+rng:NextNumber(9,17);if not sheltered then lightning(center) end end
end)
rebuild()

