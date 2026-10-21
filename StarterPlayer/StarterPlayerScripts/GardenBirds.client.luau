-- Local articulated ravens: feathered wings, gliding flight, perching and head motion.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local P=Players.LocalPlayer
local anchors=workspace:WaitForChild("BirdPerches",30)
if not anchors then return end
local folder=Instance.new("Folder");folder.Name="AnimatedRavens";folder.Parent=workspace
local birds={}
local V=Vector3.new;local CF=CFrame.new
local function piece(model,name,size,cf,color,group,shape)
 local p=Instance.new(shape=="wedge" and "WedgePart" or "Part");p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 if shape~="wedge" then local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p end
 p.Parent=model;table.insert(group,{part=p,offset=cf});return p
end
for i,anchor in ipairs(anchors:GetChildren()) do if anchor:IsA("BasePart") then
 local model=Instance.new("Model");model.Name="GardenRaven";model.Parent=folder
 local b={model=model,anchor=anchor,index=i,body={},head={},left={},right={}}
 local black=Color3.fromRGB(25,29,40);local sheen=Color3.fromRGB(42,51,67)
 piece(model,"Body",V(.58,.66,1.05),CF(),black,b.body)
 piece(model,"Breast",V(.49,.52,.7),CF(0,-.08,-.25),sheen,b.body)
 piece(model,"Head",V(.48,.46,.53),CF(),black,b.head)
 piece(model,"Beak",V(.2,.2,.42),CF(0,-.03,-.37)*CFrame.Angles(math.pi/2,0,0),Color3.fromRGB(51,52,57),b.head,"wedge")
 for _,side in ipairs({-1,1}) do
  piece(model,"Eye",V(.07,.07,.055),CF(side*.22,.06,-.17),Color3.fromRGB(6,7,9),b.head)
  piece(model,"EyeGlint",V(.023,.023,.02),CF(side*.247,.075,-.183),Color3.fromRGB(190,201,205),b.head)
  piece(model,"Leg",V(.055,.28,.055),CF(side*.16,-.42,.05),Color3.fromRGB(67,63,60),b.body)
  for k=-1,1 do piece(model,"Claw",V(.04,.04,.24),CF(side*.16+k*.045,-.55,-.02)*CFrame.Angles(0,k*.2,0),Color3.fromRGB(67,63,60),b.body) end
  local wing=side<0 and b.left or b.right
  piece(model,"WingCoverts",V(.8,.17,.68),CF(side*.35,0,.05)*CFrame.Angles(0,side*.13,0),black,wing)
  for j=1,6 do piece(model,"FlightFeather",V(.23,.085,.85-j*.055),CF(side*(.55+j*.105),-.02,.25+(j-3)*.11)*CFrame.Angles(0,side*(-.25+j*.1),0),j%2==0 and black or sheen,wing) end
 end
 for j=-1,1 do piece(model,"TailFeather",V(.19,.09,.65),CF(j*.13,-.1,.68)*CFrame.Angles(-.18,j*.15,0),black,b.body) end
 table.insert(birds,b)
end end
local function pose(parts,base) for _,p in ipairs(parts) do p.part.CFrame=base*p.offset end end
local timer=0
Run.Heartbeat:Connect(function(dt)
 timer+=dt;if timer<1/30 then return end;timer=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local now=workspace:GetServerTimeNow()
 for _,b in ipairs(birds) do
  local home=b.anchor.Position+V(0,.58,0)
  if (camera.CFrame.Position-home).Magnitude<200 then
   if b.model.Parent==nil then b.model.Parent=folder end
   local phase=(now+b.index*7)%38;local flying=phase>12
   local root,flap
   if flying then
    local t=(phase-12)/26
    local rise=math.sin(math.pi*t)^.65;local theta=t*math.pi*4+b.index
    local radius=rise*(10+b.index*2)
    local pos=home+V(math.cos(theta)*radius,7*rise+math.sin(theta*2)*.3*rise,math.sin(theta)*radius)
    local nextT=math.min(.9999,t+.002);local nextRise=math.sin(math.pi*nextT)^.65;local nextAngle=nextT*math.pi*4+b.index
    local nextPos=home+V(math.cos(nextAngle)*nextRise*(10+b.index*2),7*nextRise,math.sin(nextAngle)*nextRise*(10+b.index*2))
    root=(nextPos-pos).Magnitude>.01 and CFrame.lookAt(pos,nextPos) or CF(pos)
    local glide=math.sin(now*.7+b.index)>.5
    flap=glide and .08 or math.sin(now*17+b.index)*.58
   else
    root=CF(home)*CFrame.Angles(0,b.index*.8,0);flap=-1.15
   end
   pose(b.body,root)
   pose(b.head,root*CF(0,.27,-.46)*CFrame.Angles(0,not flying and math.sin(now*.7+b.index)*.3 or 0,0))
   pose(b.left,root*CF(-.23,.1,0)*CFrame.Angles(0,flying and 0 or -.35,-flap))
   pose(b.right,root*CF(.23,.1,0)*CFrame.Angles(0,flying and 0 or .35,flap))
  else b.model.Parent=nil end
 end
end)
script.Destroying:Connect(function() for _,b in ipairs(birds) do b.model:Destroy() end;folder:Destroy() end)
