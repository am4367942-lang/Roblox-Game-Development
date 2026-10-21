-- Shared presentation only. Never grants souls, damage, ownership or rewards.
local GhostVisuals = {}
local V, CF, RGB = Vector3.new, CFrame.new, Color3.fromRGB
local dark, ivory, gold = RGB(23,29,48), RGB(231,244,244), RGB(212,175,93)

function GhostVisuals.create(parent, kind, color, scale, quiet)
 scale = scale or 1
 local model = Instance.new("Model")
 model.Name = kind .. "Visual"
 local parts, tails, hands, eyes, orbiters = {}, {}, {}, {}, {}
 local template=script.Parent:FindFirstChild("GhostBodyTemplate")
 local sculpted=template~=nil
 local function scaled(cf) return CF(cf.Position*scale)*(cf-cf.Position) end
 local function piece(name, size, cf, tint, alpha, material, shape)
  local p = Instance.new("Part")
  p.Name=name; p.Size=size*scale; p.CFrame=scaled(cf); p.Color=tint
  p.Material=material or Enum.Material.SmoothPlastic; p.Transparency=alpha or 0
  p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false
  if shape~="block" then
   local mesh=Instance.new("SpecialMesh");mesh.MeshType=shape=="wedge" and Enum.MeshType.Wedge or Enum.MeshType.Sphere;mesh.Parent=p
  end
  p.Parent=model; table.insert(parts,{part=p,cf=cf}); return p
 end
 local root=piece("VisualRoot",V(.1,.1,.1),CF(),color,1)
 model.PrimaryPart=root
 local body=root
 if sculpted then
  for _,source in ipairs(template:GetChildren()) do
   if source:IsA("MeshPart") then
    local p=source:Clone();p.Name="SculptedEctoplasm"
    p.Size=source.Size*scale;p.CFrame=scaled(source.CFrame);p.Color=color:Lerp(ivory,.18)
    p.Material=Enum.Material.SmoothPlastic;p.Transparency=.12
    p.TextureID=""
    for _,v in ipairs(p:GetChildren()) do if v:IsA("SurfaceAppearance") then v:Destroy() end end
    p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
   end
  end
 else
  body=piece("EctoplasmMantle",V(1.9,2.25,1.5),CF(0,.18,0),color,.18)
  piece("SoftBrow",V(1.65,1.25,1.38),CF(0,.68,-.07),color:Lerp(ivory,.25),.14)
  for i=1,7 do
   local f=(i-1)/6
   local cf=CF(.35*f*f,-.82-i*.24,.13+i*.11)
   local p=piece("FlowingTail"..i,V(1.33*(1-f)+.1,.8,1.12*(1-f)+.1),cf,color,.2+f*.3)
   table.insert(tails,{part=p,cf=cf,index=i})
  end
 end
 for _,side in ipairs({-1,1}) do
  local cf=CF(side*.99,-.18,-.02)*CFrame.Angles(0,0,side*.35)
  if not sculpted then
   local hand=piece("WispHand",V(.42,.75,.42),cf,color,.2)
   table.insert(hands,{part=hand,cf=cf,side=side})
  end
  local eye=piece("ObsidianEye",V(sculpted and .13 or .27,sculpted and .22 or .4,.08),(sculpted and CF(side*.15,.78,-.40) or CF(side*.34,.53,-.755)),dark)
  table.insert(eyes,eye)
  piece("EyeCatchlight",V(.045,.06,.025),(sculpted and CF(side*.15-.025,.83,-.45) or CF(side*.34-.04,.62,-.824)),ivory,0,Enum.Material.Neon)
  piece("CheekGlow",V(.16,.06,.03),(sculpted and CF(side*.25,.63,-.37) or CF(side*.58,.24,-.69)),color:Lerp(ivory,.65),.4)
 end
 piece("Mouth",V(.13,.09,.06),(sculpted and CF(0,.61,-.44) or CF(0,.10,-.76)),dark)
 local function gem(name, pos, size, tint)
  return piece(name,size,CF(pos)*CFrame.Angles(0,0,math.rad(35)),tint,.1,Enum.Material.Glass,"wedge")
 end
 if kind=="LanternWisp" then
  piece("LanternFlame",V(.33,.55,.28),CF(0,-.5,-1.0),RGB(255,224,143),.1,Enum.Material.Neon)
  for _,y in ipairs({-.86,-.15}) do piece("LanternCap",V(.65,.12,.51),CF(0,y,-1),gold,0,Enum.Material.Metal,"block") end
  for _,x in ipairs({-.25,.25}) do piece("LanternFrame",V(.055,.64,.055),CF(x,-.5,-1.21),gold,0,Enum.Material.Metal,"block") end
  piece("LanternHandle",V(.34,.29,.06),CF(0,.04,-1),gold,0,Enum.Material.Metal)
 elseif kind=="MossSprite" then
  for i=1,7 do
   local a=i*math.pi*2/7
   piece("MossLeaf",V(.32,.12,.68),CF(math.cos(a)*.58,1.12,math.sin(a)*.47)*CFrame.Angles(.22,a,0),RGB(68+i*7,123+i*7,81),0,Enum.Material.Grass)
  end
  for i=1,3 do piece("Moonberry",V(.16,.19,.16),CF((i-2)*.24,1.23,-.46),RGB(194,162,239)) end
 elseif kind=="CrystalSpirit" then
  for i=1,5 do gem("AmethystSpire",V((i-3)*.28,1.15+(.3-math.abs(i-3)*.12),0),V(.28,.65,.32),color:Lerp(ivory,.2)) end
  for _,side in ipairs({-1,1}) do gem("CrystalShoulder",V(side*.94,.1,.06),V(.3,.55,.35),color) end
 elseif kind=="GuardianGhost" or kind=="SpectralKnight" then
  local steel=kind=="SpectralKnight" and RGB(75,93,121) or RGB(151,125,78)
  piece("Gorget",V(1.3,.28,1.0),CF(0,-.02,0),steel,0,Enum.Material.Metal)
  for _,side in ipairs({-1,1}) do piece("EngravedPauldron",V(.68,.37,.68),CF(side*.9,.1,0),steel,0,Enum.Material.Metal) end
  local shieldCF=CF(-1.05,-.35,-.45)*CFrame.Angles(0,0,-.15)
  piece("ShieldRim",V(.86,1.05,.2),shieldCF,gold,0,Enum.Material.Metal)
  piece("ShieldFace",V(.70,.88,.22),shieldCF*CF(0,0,-.04),steel,0,Enum.Material.Metal)
  gem("ShieldSoul",V(-1.05,-.35,-.61),V(.19,.32,.08),color)
  if kind=="SpectralKnight" then
   piece("HelmCrest",V(.20,.53,.9),CF(0,1.35,.08),steel,0,Enum.Material.Metal)
   piece("SpectralBlade",V(.17,1.25,.13),CF(1.12,.15,-.45)*CFrame.Angles(0,0,-.2),color,.12,Enum.Material.Neon,"wedge")
   piece("SwordGuard",V(.55,.10,.20),CF(1.25,-.45,-.45),gold,0,Enum.Material.Metal,"block")
  end
 elseif kind=="RoyalPhantom" then
  piece("RoyalCollar",V(1.65,.28,1.3),CF(0,-.05,.08),RGB(106,52,142),0,Enum.Material.Fabric)
  piece("CrownBand",V(1.48,.25,1.15),CF(0,1.13,.02),gold,0,Enum.Material.Metal)
  for i=1,5 do
   local a=i*math.pi*2/5
   gem("CrownPoint",V(math.cos(a)*.56,1.42,math.sin(a)*.43),V(.24,.57,.25),gold)
  end
  gem("RoyalJewel",V(0,1.16,-.58),V(.25,.33,.12),RGB(235,148,255))
 elseif kind=="Poltergeist" then
  for _,side in ipairs({-1,1}) do
   piece("SlyBrow",V(.17,.05,.06),(sculpted and CF(side*.15,.96,-.38) or CF(side*.34,.83,-.74))*CFrame.Angles(0,0,side*.25),dark)
  end
  for i=1,3 do
   local cf=CF(math.cos(i*2.1)*1.65,-.45,math.sin(i*2.1)*1.65)
   local p=piece("TelekineticRuneStone",V(.23,.33,.23),cf,RGB(100,112,127),0,Enum.Material.Slate,"wedge")
   table.insert(orbiters,{part=p,index=i})
  end
 end
 -- Scale head ornaments to the sculpted head, leaving equipment full size.
 if sculpted then
  local headDetails={MossLeaf=true,Moonberry=true,AmethystSpire=true,HelmCrest=true,CrownBand=true,CrownPoint=true,RoyalJewel=true}
  for _,p in ipairs(model:GetChildren()) do
   if p:IsA("BasePart") and headDetails[p.Name] then
    local pos=p.Position/scale
    p.Size*=.55;p.CFrame=CF(V(pos.X*.55,1.08+(pos.Y-1.08)*.65,pos.Z*.55)*scale)*(p.CFrame-p.Position)
   end
  end
 end
 local mist=Instance.new("ParticleEmitter")
 mist.Name="SpectralMist";mist.Texture="rbxasset://textures/particles/smoke_main.dds"
 mist.Color=ColorSequence.new(color);mist.LightEmission=.45;mist.Rate=quiet and 0 or 3
 mist.Lifetime=NumberRange.new(.65,1.2);mist.Speed=NumberRange.new(.12,.3)
 mist.SpreadAngle=Vector2.new(35,35);mist.Acceleration=V(0,.35,0)
 mist.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.45*scale),NumberSequenceKeypoint.new(1,1.2*scale)})
 mist.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.82),NumberSequenceKeypoint.new(1,1)})
 mist.Parent=body
 model.Parent=parent
 local rig={model=model,quiet=quiet}
 function rig:pose(cf,t,phase,lowFX)
  cf=cf*CFrame.Angles(math.sin(t*1.7+(phase or 0))*.025,0,math.sin(t*1.3+(phase or 0))*.035)
  model:PivotTo(cf)
  local motion=t*2.4+(phase or 0)
  for _,item in ipairs(tails) do
   local sway=math.sin(motion-item.index*.5)*item.index*.035
   item.part.CFrame=cf*scaled(item.cf*CF(sway,0,0)*CFrame.Angles(0,0,sway*.2))
  end
  for _,item in ipairs(hands) do item.part.CFrame=cf*scaled(item.cf*CF(0,math.sin(motion+item.side)*.09,0)*CFrame.Angles(.1*math.sin(motion),0,item.side*.1*math.sin(motion))) end
  local blink=(t+(phase or 0)*.6)%4.8<.12
  for _,eye in ipairs(eyes) do eye.Size=V(sculpted and .13 or .27,blink and .035 or (sculpted and .22 or .4),.08)*scale end
  for _,item in ipairs(orbiters) do
   local a=t*.85+item.index*math.pi*2/3
   item.part.CFrame=cf*scaled(CF(math.cos(a)*1.6,-.55+math.sin(a*2)*.2,math.sin(a)*1.6)*CFrame.Angles(t*.5,a,.25))
  end
  mist.Enabled=not lowFX and not self.quiet
 end
 function rig:hide() mist.Enabled=false;model:PivotTo(CF(0,-10000,0)) end
 function rig:destroy() model:Destroy() end
 return rig
end
return GhostVisuals

