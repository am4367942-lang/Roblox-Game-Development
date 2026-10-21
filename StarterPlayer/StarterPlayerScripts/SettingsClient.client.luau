local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Sound=game:GetService("SoundService")
local Run=game:GetService("RunService")
local P=Players.LocalPlayer
local R=RS:WaitForChild("Remotes")
local Shop=require(RS.Shared.MonetizationConfig)
local M=game:GetService("MarketplaceService")
local profile={settings={vfx=true,volume=1,holdCollect=true,waypoints=true},graphics="auto"}
local premium={vip=false,boosts={},bankedSouls=0}
local prices={}
local iconImages={}
local gui=Instance.new("ScreenGui");gui.Name="SettingsAndRobux";gui.ResetOnSpawn=false;gui.DisplayOrder=25;gui.Parent=P:WaitForChild("PlayerGui")
local function round(p) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,9);c.Parent=p end
local function button(parent,text,size,pos,callback)
 local b=Instance.new("TextButton");b.Size=size;b.Position=pos or UDim2.new();b.BackgroundColor3=Color3.fromRGB(75,48,103);b.TextColor3=Color3.fromRGB(245,237,255);b.Text=text;b.Font=Enum.Font.GothamBold;b.TextSize=14;b.TextWrapped=true;b.BorderSizePixel=0;b.Parent=parent;round(b)
 if callback then b.Activated:Connect(callback) end;return b
end
local panel=Instance.new("Frame");panel.Name="Menu";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(480,500);panel.BackgroundColor3=Color3.fromRGB(22,19,32);panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;round(panel)
local scale=Instance.new("UIScale");scale.Parent=panel
local title=Instance.new("TextLabel");title.BackgroundTransparency=1;title.Size=UDim2.new(1,-70,0,50);title.Position=UDim2.fromOffset(16,0);title.TextXAlignment=Enum.TextXAlignment.Left;title.Font=Enum.Font.GothamBold;title.TextSize=22;title.TextColor3=Color3.fromRGB(245,211,139);title.Parent=panel
button(panel,"×",UDim2.fromOffset(34,34),UDim2.new(1,-44,0,8),function() panel.Visible=false end)
local list=Instance.new("ScrollingFrame");list.BackgroundTransparency=1;list.BorderSizePixel=0;list.Position=UDim2.fromOffset(16,58);list.Size=UDim2.new(1,-32,1,-72);list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.ScrollBarThickness=4;list.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,8);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
local tab="Settings";local order=0;local render
local function text(value,height)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.new(1,-8,0,height or 40);t.Text=value;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Center;t.Font=Enum.Font.Gotham;t.TextSize=14;t.TextColor3=Color3.fromRGB(221,220,234);order+=1;t.LayoutOrder=order;t.Parent=list;return t
end
local function choice(value,callback) local b=button(list,value,UDim2.new(1,-8,0,38),nil,callback);order+=1;b.LayoutOrder=order;return b end
local function set(key,value) R.ProfileAction:FireServer("Set",key,value) end
local settingsButton=button(gui,"Settings",UDim2.fromOffset(136,32),UDim2.fromOffset(16,220),function() tab="Settings";panel.Visible=not panel.Visible;render();R.ProfileAction:FireServer("State") end)
local robuxButton=button(gui,"Robux Shop",UDim2.fromOffset(136,32),UDim2.fromOffset(16,260),function() tab="Robux Shop";panel.Visible=not panel.Visible;render();R.PremiumAction:FireServer("State") end)
local function price(def) return prices[def.id] and (prices[def.id].." Robux") or "Loading price…" end
render=function()
 for _,v in list:GetChildren() do if v:IsA("GuiObject") then v:Destroy() end end;order=0;title.Text=string.upper(tab)
 if tab=="Settings" then
  local s=profile.settings
  text("GRAPHICS & EFFECTS",24)
  choice("Graphics: "..string.upper(profile.graphics or "auto"),function() local nextMode=profile.graphics=="auto" and "low" or profile.graphics=="low" and "high" or "auto";set("graphics",nextMode) end)
  choice("Visual effects: "..(s.vfx and "ON" or "OFF"),function() set("vfx",not s.vfx) end)
  text(("SOUND · %d%%"):format(math.floor((s.volume or 1)*100)),25)
  local bar=Instance.new("Frame");bar.Size=UDim2.new(1,-8,0,38);bar.BackgroundTransparency=1;order+=1;bar.LayoutOrder=order;bar.Parent=list
  button(bar,"−",UDim2.fromOffset(90,34),UDim2.new(),function() set("volume",math.max(0,(s.volume or 1)-.1)) end)
  button(bar,"Mute",UDim2.fromOffset(110,34),UDim2.fromOffset(110,0),function() set("volume",0) end)
  button(bar,"+",UDim2.fromOffset(90,34),UDim2.fromOffset(240,0),function() set("volume",math.min(1,(s.volume or 0)+.1)) end)
  text("GAMEPLAY",24)
  choice("Welcome guide",function() P.PlayerGui.HarvestMenuOpen:Fire("Welcome") end)
  choice("Quest waypoints: "..(s.waypoints and "ON" or "OFF"),function() set("waypoints",not s.waypoints) end)
  choice("Hold to collect: "..(s.holdCollect and "ON" or "OFF"),function() set("holdCollect",not s.holdCollect) end)
  text("Equip a tool in the shop, then click, tap or press R2 near a glowing grave. Use E or the on-screen prompt to interact. Shift sprints on PC. J opens the expedition journal.",80)
  text("REDEEM A CODE",24)
  local box=Instance.new("TextBox");box.Name="Code";box.PlaceholderText="Enter code";box.ClearTextOnFocus=false;box.Text="";box.Font=Enum.Font.Gotham;box.TextSize=15;box.TextColor3=Color3.new(1,1,1);box.BackgroundColor3=Color3.fromRGB(48,41,63);box.Size=UDim2.new(1,-8,0,38);order+=1;box.LayoutOrder=order;box.Parent=list;round(box)
  choice("Redeem",function() R.ProfileAction:FireServer("Redeem",box.Text) end)
  if profile.message then text(profile.message,42) end
 else
  text("Optional purchases. Boost time starts when the purchase is granted and continues while you are offline.",58)
  text("PERMANENT PASSES",24)
  for _,def in ipairs(Shop.Passes) do
   local key=def.key;local owned=key=="VIP" and premium.vip or (premium.passes and premium.passes[key])
   local b=choice(def.name.." · "..(owned and "OWNED" or price(def)),function() if not owned then R.PremiumAction:FireServer(key) end end)
   b.Size=UDim2.new(1,-8,0,62)
   local icon=Instance.new("ImageLabel");icon.Size=UDim2.fromOffset(54,54);icon.Position=UDim2.fromOffset(4,4);icon.BackgroundTransparency=1;icon.Image=iconImages[def.id] or "";icon.Parent=b
   local padding=Instance.new("UIPadding");padding.PaddingLeft=UDim.new(0,62);padding.Parent=b
   text(def.description,54)
  end
  text("TIMED BOOSTS & CURRENCY",24)
  for _,def in ipairs(Shop.Products) do
   local key=def.key
   if def.id>0 then choice(def.name.." · "..price(def),function() R.PremiumAction:FireServer(key) end) else text(def.name.." · Store setup pending",32) end
   local remaining=math.max(0,(premium.boosts[key] or 0)-os.time())
   text(def.description..(remaining>0 and (" Active: %d:%02d"):format(math.floor(remaining/60),remaining%60) or ""),48)
  end
  text(("SOUL BANK · %d souls\nBanked souls stay safe until you transfer them. Purchased souls do not count towards collection quests or ranks."):format(premium.bankedSouls or 0),72)
  if (premium.bankedSouls or 0)>0 then choice("Fill equipped jar from bank",function() R.PremiumAction:FireServer("TransferSouls") end) end
 end
end
-- Scale each sound locally without changing its authored group/effects.
local sounds=setmetatable({},{__mode="k"})
local function watchSound(s)
 if not s:IsA("Sound") or sounds[s] then return end
 local record={base=s.Volume,changing=false};sounds[s]=record
 local function apply() record.changing=true;record.expected=record.base*(profile.settings.volume or 1);s.Volume=record.expected;record.changing=false end
 record.apply=apply
 s:GetPropertyChangedSignal("Volume"):Connect(function() if not record.changing and math.abs(s.Volume-(record.expected or -1))>.0001 then record.base=s.Volume;apply() end end)
 apply()
end
local effects=setmetatable({},{__mode="k"})
local function watchEffect(e)
 if not (e:IsA("ParticleEmitter") or e:IsA("Trail") or e:IsA("Beam")) or effects[e] then return end
 local rec={enabled=e.Enabled,changing=false};effects[e]=rec
 local function apply()
  rec.changing=true;rec.expected=rec.enabled and profile.settings.vfx~=false;e.Enabled=rec.expected;rec.changing=false
 end
 rec.apply=apply
 e:GetPropertyChangedSignal("Enabled"):Connect(function() if not rec.changing and e.Enabled~=rec.expected then rec.enabled=e.Enabled;apply() end end);apply()
end
for _,v in game:GetDescendants() do watchSound(v);watchEffect(v) end
game.DescendantAdded:Connect(function(v) watchSound(v);watchEffect(v) end)
R.ProfileState.OnClientEvent:Connect(function(s)
 profile=s;for e,r in pairs(effects) do if e.Parent then r.apply() end end;for sound,r in pairs(sounds) do if sound.Parent then r.apply() end end
 P:SetAttribute("ClientVFX",s.settings.vfx)
 if panel.Visible and tab=="Settings" then local scroll=list.CanvasPosition;render();list.CanvasPosition=scroll end
end)
R.PremiumState.OnClientEvent:Connect(function(s) premium=s;if panel.Visible and tab=="Robux Shop" then local scroll=list.CanvasPosition;render();list.CanvasPosition=scroll end end)
R.RefineState.OnClientEvent:Connect(function(s)
 local g=P.PlayerGui:FindFirstChild("HauntedHUD")
 if not g then return end
 -- Full state updates keep the jar HUD in sync once per second.
end)
local function fit() local c=workspace.CurrentCamera;if c then scale.Scale=math.min(1,(c.ViewportSize.X-24)/480,(c.ViewportSize.Y-40)/500) end end
fit();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
task.spawn(function()
 local defs={};for _,d in ipairs(Shop.Passes) do table.insert(defs,d) end;for _,d in ipairs(Shop.Products) do table.insert(defs,d) end
 for _,def in ipairs(defs) do if def.id>0 then
  local ok,info=pcall(function() return M:GetProductInfo(def.id,def.kind=="pass" and Enum.InfoType.GamePass or Enum.InfoType.Product) end)
  if ok and info.PriceInRobux then prices[def.id]=info.PriceInRobux;if info.IconImageAssetId then iconImages[def.id]="rbxassetid://"..info.IconImageAssetId end end
 end end
 if panel.Visible and tab=="Robux Shop" then render() end
end)
R.ProfileAction:FireServer("State");R.PremiumAction:FireServer("State")

settingsButton.Visible=false;robuxButton.Visible=false
P.PlayerGui:WaitForChild("HarvestMenuOpen").Event:Connect(function(name)
 panel.Visible=false
 if name=="Settings" or name=="Robux Shop" then tab=name;panel.Visible=true;render();R.ProfileAction:FireServer("State");R.PremiumAction:FireServer("State") end
end)
