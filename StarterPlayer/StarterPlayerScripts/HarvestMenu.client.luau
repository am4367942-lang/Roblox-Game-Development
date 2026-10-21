local P=game.Players.LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local CS=game:GetService("CollectionService")
local C=require(RS.Shared.WorldCatalog)
local Config=require(RS.Shared.Config)
local Ghost=require(RS.Shared.GhostCatalog)
local R=RS:WaitForChild("Remotes")
local pg=P:WaitForChild("PlayerGui")
local bus=pg:FindFirstChild("HarvestMenuOpen") or Instance.new("BindableEvent");bus.Name="HarvestMenuOpen";bus.Parent=pg
local gui=Instance.new("ScreenGui");gui.Name="HarvestMenu";gui.ResetOnSpawn=false;gui.DisplayOrder=30;gui.Parent=pg
local function corner(o,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 9);c.Parent=o end
local function button(parent,text,callback)
 local b=Instance.new("TextButton");b.BackgroundColor3=Color3.fromRGB(64,47,90);b.TextColor3=Color3.fromRGB(250,240,215);b.Font=Enum.Font.GothamBold;b.TextSize=14;b.TextWrapped=true;b.BorderSizePixel=0;b.Text=text;b.Size=UDim2.new(1,-8,0,40);b.Parent=parent;corner(b);if callback then b.Activated:Connect(callback) end;return b
end
local bar=Instance.new("Frame");bar.Name="MenuGrid";bar.AnchorPoint=Vector2.new(0,0);bar.Position=UDim2.fromOffset(16,148);bar.Size=UDim2.fromOffset(120,184);bar.BackgroundTransparency=1;bar.Parent=gui
local bs=Instance.new("UIScale");bs.Parent=bar
local names={"Inventory","Quests","Ghosts","Badges","Settings","Robux Shop"};local icons={"◒","?","◕","★","⚙","$"}
for i,name in ipairs(names) do
 local b=button(bar,"",function() bus:Fire(name) end);b.Name=name;b.Size=UDim2.fromOffset(56,56);b.Position=UDim2.fromOffset(((i-1)%2)*64,math.floor((i-1)/2)*64);b.BackgroundColor3=Color3.fromRGB(235,225,192);b.Rotation=(i%2==0) and 2 or -2
 local icon=Instance.new("TextLabel");icon.Size=UDim2.new(1,0,0,38);icon.BackgroundTransparency=1;icon.Text=icons[i];icon.TextColor3=Color3.fromRGB(55,51,38);icon.Font=Enum.Font.GothamBlack;icon.TextSize=32;icon.Parent=b
 if name=="Ghosts" then icon.Text="";local body=Instance.new("Frame");body.Size=UDim2.fromOffset(26,28);body.Position=UDim2.fromOffset(15,5);body.BackgroundColor3=Color3.fromRGB(55,51,38);body.BorderSizePixel=0;body.Parent=icon;corner(body,12);for j=1,2 do local e=Instance.new("Frame");e.Size=UDim2.fromOffset(4,6);e.Position=UDim2.fromOffset(5+j*6,8);e.BackgroundColor3=b.BackgroundColor3;e.BorderSizePixel=0;e.Parent=body;corner(e,3) end end
 local t=Instance.new("TextLabel");t.Size=UDim2.new(1,8,0,18);t.Position=UDim2.fromOffset(-4,37);t.BackgroundTransparency=1;t.Text=name=="Robux Shop" and "Shop" or name;t.TextColor3=Color3.fromRGB(55,51,38);t.Font=Enum.Font.GothamBold;t.TextSize=10;t.Parent=b
 local st=Instance.new("UIStroke");st.Color=Color3.fromRGB(143,127,91);st.Thickness=1.5;st.Parent=b
end
local panel=Instance.new("Frame");panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.53);panel.Size=UDim2.fromOffset(510,490);panel.BackgroundColor3=Color3.fromRGB(25,23,36);panel.Visible=false;panel.BorderSizePixel=0;panel.Parent=gui;corner(panel,14)
local scale=Instance.new("UIScale");scale.Parent=panel
local title=Instance.new("TextLabel");title.Position=UDim2.fromOffset(18,8);title.Size=UDim2.new(1,-70,0,38);title.BackgroundTransparency=1;title.TextColor3=Color3.fromRGB(255,220,155);title.Font=Enum.Font.GothamBlack;title.TextSize=21;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=panel
local close=button(panel,"×",function() panel.Visible=false end);close.Size=UDim2.fromOffset(32,32);close.Position=UDim2.new(1,-42,0,9)
local list=Instance.new("ScrollingFrame");list.Position=UDim2.fromOffset(16,56);list.Size=UDim2.new(1,-32,1,-72);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=4;list.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
local tab="Inventory";local s={souls={},consumables={},badges={},stats={},boosts={},unlockedZones={}};local gameState={};local order=0;local zone="Graveyard";local render;local admin={people={}};local target=P.UserId
local function text(value,height,color) local t=Instance.new("TextLabel");t.Text=value;t.TextColor3=color or Color3.fromRGB(221,223,236);t.TextSize=14;t.Font=Enum.Font.Gotham;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.BackgroundTransparency=1;t.Size=UDim2.new(1,-8,0,height or 36);order+=1;t.LayoutOrder=order;t.Parent=list;return t end
local function choice(value,fn) local b=button(list,value,fn);order+=1;b.LayoutOrder=order;return b end
local function zones() local result={} for id in pairs(C.Souls) do local z=Config.Zones[id];if not z or not z.requires or s.unlockedZones[id] then table.insert(result,id) end end;table.sort(result);return result end
local function openBoosts() tab="Field Supplies";panel.Visible=true;render();R.WorldAction:FireServer("State") end
local adminId="LanternWisp";local adminAmount="1";local adminMutation="Prismatic"
local function input(value,hint,changed)
 local box=Instance.new("TextBox");box.Text=value;box.PlaceholderText=hint;box.ClearTextOnFocus=false;box.Size=UDim2.new(1,-8,0,36);box.BackgroundColor3=Color3.fromRGB(48,44,63);box.TextColor3=Color3.new(1,1,1);box.Font=Enum.Font.Gotham;box.TextSize=14;order+=1;box.LayoutOrder=order;box.Parent=list;corner(box);box.FocusLost:Connect(function() changed(box.Text) end);return box
end
render=function()
 for _,v in ipairs(list:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end;order=0;title.Text=string.upper(tab)
 if tab=="Welcome" then
  text("WELCOME TO HAUNTED HARVEST",42,Color3.fromRGB(255,218,145))
  text("A little ghost, a big adventure.",32)
  text("1. Equip your Grave Vacuum from Inventory → Tools & storage, or press 1.",52)
  text("2. Find a glowing grave inside a graveyard. Click or hold to absorb souls. Empty graves slowly recharge.",62)
  text("3. Follow YOUR SPIRIT ROOST marker home and press Convert. Only you can refine there. Your ghosts make it faster.",70)
  text("4. Spend Essence on faster tools, larger jars, boots and other upgrades at the Spirit Emporium.",58)
  text("5. Hatch ghost eggs at your roost. Feed ghosts to level them up, train eggs, and use Royal Essence to transform them.",70)
  text("Talk to Morty and the other ghost hunters for quests. Quest waypoints lead you to the next objective. Explore the mountain graveyards and Hollow Caverns.",80)
  text("Bosses rise around the map. Their health bar appears at the bottom when you enter their arena. Weather rolls every hour and can mutate graves for bonus Essence.",88)
  text("Left menu: Inventory · Quests · Ghosts · Badges · Settings · Robux Shop. Settings has graphics, effects, sound, controls and codes.",72)
  choice("Start harvesting",function() panel.Visible=false end)
 elseif tab=="Inventory" then
  text("YOUR SOUL JAR",24);if #s.souls==0 then text("Collect souls from a glowing grave. Every graveyard holds a different soul type.",48) end
  for _,b in ipairs(s.souls) do text(b.count.." × "..b.name.." · "..b.mutation.." · "..b.multiplier.."× Essence",40,Color3.fromRGB(table.unpack(b.color))) end
  choice("Tools & storage · Equip / Unequip",function() bus:Fire("Equipment") end)
  choice("Ghost eggs",function() bus:Fire("Eggs") end)
  choice("Spirit Roost · Feed & train ghosts",function() bus:Fire("GhostCare") end)
  choice("Welcome guide",function() bus:Fire("Welcome") end)
  choice("Field Supplies · Recharge boosts",openBoosts)
  text("CONSUMABLES",24);for _,b in ipairs(C.Boosts) do text(b.name.." × "..(s.consumables[b.id] or 0),28) end
  text("Visit your own Spirit Roost and press Convert. Leaving pauses refining; mutations keep their bonus in your jar.",54)
 elseif tab=="Field Supplies" then
  choice("Graveyard: "..zone.."  →",function() local all=zones();local i=table.find(all,zone) or 0;zone=all[i%#all+1];render() end)
  local active=s.boosts[zone];if active then text(("Active: %s× recharge · %d seconds remaining"):format(active.multiplier,math.max(0,active.ends-os.time())),42) end
  for _,b in ipairs(C.Boosts) do local id=b.id;text(b.name.." · Owned "..(s.consumables[id] or 0),28,Color3.fromRGB(180,240,210));text(b.desc,48);choice("Buy · "..b.price.." Essence",function() R.WorldAction:FireServer("BuyBoost",id) end);if (s.consumables[id] or 0)>0 then choice("Use in "..zone,function() R.WorldAction:FireServer("UseBoost",id,zone) end) end end
 elseif tab=="Badges" then
  text("Harvest achievements reward earned Essence. Claim each once.",42)
  for _,b in ipairs(C.Badges) do local id=b.id;local progress=s.stats[b.stat] or 0;text(b.name.." · "..math.min(progress,b.goal).." / "..b.goal,30);choice(s.badges[id] and "★ Earned" or progress>=b.goal and ("Claim "..b.reward.." Essence") or ("Reward: "..b.reward.." Essence"),function() R.WorldAction:FireServer("ClaimBadge",id) end) end
 elseif tab=="Admin" and P.UserId==3373220410 then
  text("OWNER CONTROLS · Current server only",28,Color3.fromRGB(255,210,130));if admin.message then text(admin.message,42) end
  local selected="Yourself";for _,v in ipairs(admin.people) do if v.id==target then selected=v.name end end
  choice("Target: "..selected.." →",function() local idx=0;for i,v in ipairs(admin.people) do if v.id==target then idx=i end end;if #admin.people>0 then target=admin.people[idx%#admin.people+1].id end;render() end)
  input(adminId,"Item / zone / weather / boss ID",function(v) adminId=v end)
  input(adminAmount,"Amount, upgrade level, or weather duration (seconds)",function(v) adminAmount=v end)
  input(adminMutation,"Mutation name",function(v) adminMutation=v end)
  for _,kind in ipairs({"Essence","Souls","Egg","Ghost","Tool","Storage","Upgrade","Consumable","Food","RoyalEssence","GhostLevel","EggMastery","UnlockZone","Teleport","Weather","Mutation","Boss","Heal","Speed","Fly"}) do choice(kind,function() R.AdminAction:FireServer(kind,{target=kind=="Fly" and P.UserId or target,id=adminId,amount=tonumber(adminAmount) or 1,mutation=adminMutation}) end) end
  local ids={};for _,g in ipairs(Ghost.Pets) do table.insert(ids,g.id) end;text("Ghost IDs: "..table.concat(ids,", "),84)
  text("Food: SpiritTreat, Moonberry, StarBiscuit · GhostLevel accepts a ghost kind or UID.",58)
  text("Eggs: LanternEgg, HighlandEgg, CavernEgg\nTools: GraveVacuum, SpiritLantern, ReaperScythe, SoulSiphon, RustySpade, SilverShovel, NecroSpade",100)
  local weatherIds={} for _,w in ipairs(C.Weather) do table.insert(weatherIds,w.id) end;text("Weather IDs: "..table.concat(weatherIds,", "),90)
  local zoneIds={} for id in pairs(C.Souls) do table.insert(zoneIds,id) end;table.sort(zoneIds);text("Zone IDs: "..table.concat(zoneIds,", "),80)
  text("Boss IDs: GraveWarden, HarvestKing, HollowTreant, MireHag, LichKing, CavernKeeper\nStorage: ClayJar, GlassJar, LanternJar, CrystalVessel, VoidUrn, AbyssCoffin",100)
  text("Upgrades: Refinement, GreedyHands, SpectralBoots, Helpers\nConsumables: RechargeTonic, SpiritFertilizer, MoonwellElixir\nFlight: WASD + Space / Ctrl; mobile uses the joystick and ↑ / ↓.",110)
 end
end
bus.Event:Connect(function(name)
 panel.Visible=false
 if name=="Welcome" or name=="Inventory" or name=="Badges" or name=="Field Supplies" or (name=="Admin" and P.UserId==3373220410) then tab=name;panel.Visible=true;render();R.WorldAction:FireServer("State");if name=="Admin" then R.AdminAction:FireServer("State",{}) end end
end)
R.WorldState.OnClientEvent:Connect(function(nextState) s=nextState;if panel.Visible and tab~="Admin" then local pos=list.CanvasPosition;render();list.CanvasPosition=pos end end)
R.State.OnClientEvent:Connect(function(v) gameState=v end)
R.AdminState.OnClientEvent:Connect(function(v) if P.UserId~=3373220410 then return end;admin=v;if panel.Visible and tab=="Admin" then render() end end)
local convert=button(gui,"CONVERT",function() R.RefineAction:FireServer() end);convert.AnchorPoint=Vector2.new(.5,1);convert.Position=UDim2.new(.5,0,1,-100);convert.Size=UDim2.fromOffset(260,46);convert.Visible=false
local flyingUp=0
if P.UserId==3373220410 then
 local b=button(gui,"OWNER",function() bus:Fire("Admin") end);b.Size=UDim2.fromOffset(82,28);b.Position=UDim2.new(0,16,1,-50)
 for i,v in ipairs({{ "↑",1},{"↓",-1}}) do local f=button(gui,v[1]);f.Size=UDim2.fromOffset(42,42);f.Position=UDim2.new(1,-50,1,-140-i*48);f.Visible=false;f.MouseButton1Down:Connect(function() flyingUp=v[2] end);f.MouseButton1Up:Connect(function() flyingUp=0 end);P:GetAttributeChangedSignal("AdminFlying"):Connect(function() f.Visible=P:GetAttribute("AdminFlying")==true end) end
end
local accumulator=0;local scan=0
Run.Heartbeat:Connect(function(dt)
 accumulator+=dt;scan+=dt
 if scan>.3 then
  scan=0;local root=P.Character and P.Character:FindFirstChild("HumanoidRootPart");local nearest
  if root then for _,pad in ipairs(CS:GetTagged("ConvertPad")) do local model=pad:FindFirstAncestorWhichIsA("Model");if pad:IsA("BasePart") and (pad.Position-root.Position).Magnitude<16 and (model and model:IsDescendantOf(workspace.SpiritRoosts) and model:GetAttribute("OwnerUserId")==P.UserId) then nearest=pad;break end end end
  convert.Visible=nearest~=nil;local refining=gameState.refining or {};convert.Text=refining.active and ("PAUSE · "..(refining.rate or 8).." souls/sec") or "CONVERT SOULS → ESSENCE"
 end
 if P.UserId==3373220410 and P:GetAttribute("AdminFlying") and accumulator>.08 then
  accumulator=0;local cam=workspace.CurrentCamera;local h=P.Character and P.Character:FindFirstChildOfClass("Humanoid");if not cam or not h then return end
  local direction=h.MoveDirection
  if not Input:GetFocusedTextBox() then
   if Input:IsKeyDown(Enum.KeyCode.W) then direction+=cam.CFrame.LookVector end;if Input:IsKeyDown(Enum.KeyCode.S) then direction-=cam.CFrame.LookVector end
   if Input:IsKeyDown(Enum.KeyCode.A) then direction-=cam.CFrame.RightVector end;if Input:IsKeyDown(Enum.KeyCode.D) then direction+=cam.CFrame.RightVector end
   local y=flyingUp+(Input:IsKeyDown(Enum.KeyCode.Space) and 1 or 0)-(Input:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0);direction+=Vector3.new(0,y,0)
  end
  if direction.Magnitude>1 then direction=direction.Unit end;R.AdminAction:FireServer("FlyMove",{direction=direction})
 end
end)
local function fit() local camera=workspace.CurrentCamera;if camera then bs.Scale=math.min(1,math.max(.78,(camera.ViewportSize.Y-150)/440));bar.Position=UDim2.fromOffset(16,148);scale.Scale=math.min(1,(camera.ViewportSize.X-24)/510,(camera.ViewportSize.Y-100)/490) end end
fit();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
for _,prompt in ipairs(CS:GetTagged("FieldSupplyPrompt")) do if prompt:IsA("ProximityPrompt") then prompt.Triggered:Connect(openBoosts) end end
R.WorldAction:FireServer("State")


task.delay(3,function() if not panel.Visible then bus:Fire("Welcome") end end)
