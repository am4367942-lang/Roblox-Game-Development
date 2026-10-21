local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local HTTP=game:GetService("HttpService")
local player=Players.LocalPlayer
local remotes=RS:WaitForChild("Remotes")
local action=remotes:WaitForChild("FeatureAction")
local state=remotes:WaitForChild("FeatureState")
local gui=Instance.new("ScreenGui");gui.Name="SpiritLodgeHUD";gui.ResetOnSpawn=false;gui.DisplayOrder=12;gui.Parent=player:WaitForChild("PlayerGui")
local function round(x) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,8);c.Parent=x end
local function button(parent,text,size,pos)
	local b=Instance.new("TextButton");b.Size=size;b.Position=pos;b.Text=text;b.Font=Enum.Font.GothamBold;b.TextSize=13;b.TextColor3=Color3.fromRGB(239,234,255);b.BackgroundColor3=Color3.fromRGB(60,47,81);b.BorderSizePixel=0;b.Parent=parent;round(b);return b
end
local open=button(gui,"Spirit Lodge",UDim2.fromOffset(128,34),UDim2.fromOffset(16,300))
local panel=Instance.new("Frame");panel.Size=UDim2.fromOffset(480,510);panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.BackgroundColor3=Color3.fromRGB(22,20,33);panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;round(panel)
local scale=Instance.new("UIScale");scale.Parent=panel
local function resize() local camera=workspace.CurrentCamera;if camera then scale.Scale=math.max(.1,math.min(1,(camera.ViewportSize.X-24)/480,(camera.ViewportSize.Y-32)/510)) end end
resize();if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
local title=Instance.new("TextLabel");title.Size=UDim2.new(1,-65,0,45);title.Position=UDim2.fromOffset(16,0);title.BackgroundTransparency=1;title.Text="SPIRIT LODGE";title.TextColor3=Color3.fromRGB(224,192,255);title.Font=Enum.Font.GothamBlack;title.TextSize=20;title.TextXAlignment=Enum.TextXAlignment.Left;title.Parent=panel
button(panel,"×",UDim2.fromOffset(32,32),UDim2.new(1,-42,0,7)).Activated:Connect(function() panel.Visible=false end)
local list=Instance.new("ScrollingFrame");list.Position=UDim2.fromOffset(14,91);list.Size=UDim2.new(1,-28,1,-105);list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.Parent=panel
local layout=Instance.new("UIListLayout");layout.Padding=UDim.new(0,7);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
local latest,tab,rebirthConfirm=nil,"Pets",false
local rebuild
local tabs={}
for i,name in ipairs({"Pets","Eggs","Care","Rebirth","Bloom","Ranks","Trade"}) do local b=button(panel,name,UDim2.fromOffset(62,30),UDim2.fromOffset(14+(i-1)*65,49));tabs[name]=b;b.Activated:Connect(function() tab=name;rebirthConfirm=false;if latest then rebuild() end;action:FireServer("State") end) end
local selectedGhost=nil;local royalConfirm=nil
local order=0
local function row(text,height,color)
	local t=Instance.new("TextLabel");t.Size=UDim2.new(1,-8,0,height or 40);t.BackgroundTransparency=1;t.Text=text;t.TextWrapped=true;t.TextXAlignment=Enum.TextXAlignment.Left;t.TextYAlignment=Enum.TextYAlignment.Top;t.Font=Enum.Font.Gotham;t.TextSize=14;t.TextColor3=color or Color3.fromRGB(216,213,230);order+=1;t.LayoutOrder=order;t.Parent=list;return t
end
local function choice(text,callback)
	local b=button(list,text,UDim2.new(1,-8,0,36),UDim2.new());order+=1;b.LayoutOrder=order;b.Activated:Connect(callback);return b
end
local function request(kind,value,revision) action:FireServer(kind,value,revision) end
rebuild=function()
	for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end;order=0
	for name,b in pairs(tabs) do b.BackgroundColor3=name==tab and Color3.fromRGB(95,66,124) or Color3.fromRGB(44,38,61) end
	local s=latest;if not s then row("Loading your lodge…");return end
	if s.busy then row("Your pet exchange is saving. Inventory actions will resume when it finishes.",54,Color3.fromRGB(255,217,145)) end
	if tab=="Pets" then
		row("Equip up to "..(s.maxEquipped or 3).." ghosts. Collectors gather souls, Guardians fight bosses, and every ghost helps refine. Buy beside your roost or a field outfitter.",62)
		row(("Refining: %d souls/sec · ×%.2f Essence · Ghosts: %d/30"):format(s.refineRate or 8,s.bonus,#s.inventory),36,Color3.fromRGB(152,235,210))
		for _,def in ipairs(s.pets) do local id=def.id
 row(("%s · %s\n%d souls/sec refining · %d boss damage per attack"):format(def.name,def.rarity or "Common",def.refine or 0,def.bossDamage or 0),46)
 if def.price>0 then choice(("Buy %s · %d Essence"):format(def.name,def.price),function() request("BuyPet",id) end) else row("Hatch from a Highland or Cavern Egg.",26) end
end
		row("YOUR SPIRITS",24,Color3.fromRGB(224,192,255))
		if #s.inventory==0 then row("Your first spirit awaits at the shop.") end
		for _,pet in ipairs(s.inventory) do local id=pet.uid;choice((pet.equipped and "Unequip · " or "Equip · ")..pet.name.." · Lv. "..(pet.level or 1)..(pet.paid and " · Not tradable" or ""),function() request("Equip",id) end) end
	elseif tab=="Eggs" then
 row("Ghost eggs come from quests or the lodge. Each hatch gives one ghost. Chances are shown below. Purchases use earned Essence only.",58)
 for _,egg in ipairs(s.eggCatalog or {}) do
 local id=egg.id;local count=(s.eggs or {})[id] or 0
 row(egg.name.." · Owned: "..count,25,Color3.fromRGB(255,217,145))
 local odds={} for _,roll in ipairs(egg.outcomes) do table.insert(odds,roll[1].." "..roll[2].."%") end
 row(table.concat(odds," · "),52)
 choice(("Buy egg · %d Essence"):format(egg.price),function() request("BuyEgg",id) end)
 if count>0 then choice("Hatch "..egg.name,function() request("HatchEgg",id) end) end
 end
  elseif tab=="Care" then
  row("YOUR SPIRIT ROOST · Food, egg training & Royal Essence",48,Color3.fromRGB(224,192,255))
  row("Stand at your own roost to use these actions. Each ghost level adds 10% of its base refining, collection and boss power. Maximum level: 20.",66)
  if #s.inventory==0 then row("Hatch an egg first to meet your first ghost.") end
  for _,pet in ipairs(s.inventory) do local uid=pet.uid;choice((selectedGhost==uid and "✓ " or "")..pet.name.." · Lv. "..(pet.level or 1).." · XP "..(pet.xp or 0).."/"..(pet.nextXP or 100),function() selectedGhost=uid;royalConfirm=nil;rebuild() end) end
  local careCatalog=require(RS.Shared.GhostCatalog)
  for _,food in ipairs(careCatalog.Foods) do local id=food.id
   row(food.name.." · Owned "..((s.foods or {})[id] or 0).." · +"..food.xp.." XP",30)
   choice("Buy "..food.name.." · "..food.price.." Essence",function() remotes.RoostAction:FireServer("BuyFood",id) end)
   if selectedGhost and ((s.foods or {})[id] or 0)>0 then choice("Feed selected ghost",function() remotes.RoostAction:FireServer("Feed",id,selectedGhost) end) end
  end
  row("ROYAL ESSENCE · Owned "..(s.royalEssence or 0),28,Color3.fromRGB(255,218,145))
  row("Transforms the selected ghost, keeping level and XP. Moss Sprite 40%, Guardian 30%, Crystal Spirit 20%, Spectral Knight 9%, Royal Phantom 1%. The same type can roll again.",92)
  choice("Buy Royal Essence · 12,000 earned Essence",function() remotes.RoostAction:FireServer("BuyRoyalEssence","RoyalEssence") end)
  if selectedGhost and (s.royalEssence or 0)>0 then choice(royalConfirm==selectedGhost and "CONFIRM · Transform selected ghost" or "Use Royal Essence on selected ghost",function()
   if royalConfirm==selectedGhost then remotes.RoostAction:FireServer("RoyalEssence","RoyalEssence",selectedGhost);royalConfirm=nil else royalConfirm=selectedGhost;rebuild() end
  end) end
  row("EGG MASTERY · Train an egg type you own. Hatches start at its mastery level; rarity chances stay the same.",64)
  for _,egg in ipairs(s.eggCatalog or {}) do local id=egg.id;local level=(s.eggLevels or {})[id] or 1
   row(egg.name.." · Mastery "..level.."/5",28)
   if level<5 and (s.eggs[id] or 0)>0 then choice("Train to Lv. "..(level+1).." · "..(egg.price*level*2).." earned Essence",function() remotes.RoostAction:FireServer("TrainEgg",id) end) end
  end

 elseif tab=="Rebirth" then
		row(("Rebirths: %d / %d\nEach rebirth adds a permanent +15%% refining bonus."):format(s.rebirths,s.rebirthMax),58,Color3.fromRGB(224,192,255))
		row("Rebirth resets your Essence, carried souls, tool purchases, upgrades, open gates and active quest. You keep ghosts, purchased currency, completed quests, journal discoveries and lifetime statistics.",94)
		row("Return to your roost or a field outfitter to rebirth.",42)
		if s.rebirths<s.rebirthMax then choice(rebirthConfirm and "Confirm reset and rebirth" or ("Rebirth · requires "..s.rebirthCost.." Essence"),function() if rebirthConfirm then rebirthConfirm=false;request("Rebirth","CONFIRM_RESET") else rebirthConfirm=true;rebuild() end end) else row("You have reached the final rebirth.") end
	elseif tab=="Bloom" then
		local e=s.event
		row("LANTERN BLOOM",28,Color3.fromRGB(255,217,145))
		row("A 15 minute expedition begins every hour. Collect souls in the featured region to earn 1000 Essence.",64)
		if e.active then
			row(("%s\n%d:%02d remaining\nSouls collected: %d / %d"):format(e.label,math.floor(e.remaining/60),e.remaining%60,e.progress,e.goal),92,Color3.fromRGB(152,235,210))
			if e.claimed then row("Reward collected. Return for the next Bloom.") elseif e.progress>=e.goal then choice("Claim 1000 Essence",function() request("ClaimEvent") end) end
		else row(("Next Bloom in %d:%02d"):format(math.floor(e.nextIn/60),e.nextIn%60),40) end
	elseif tab=="Ranks" then
		row("LIFETIME SOUL COLLECTORS",28,Color3.fromRGB(255,217,145));row("Rankings update about every two minutes.",30)
		if not s.ranksReady then row("Rankings are loading.") elseif #s.rankings==0 then row("The first collectors will appear here soon.") end
		for i,r in ipairs(s.rankings) do row(("%d. %s · %d souls"):format(i,r.name,r.souls),34) end
	elseif tab=="Trade" then
		row("PET EXCHANGE",28,Color3.fromRGB(224,192,255))
		if s.trade then
			local t=s.trade;row("Trading with "..t.partner..". Offer up to 3 pets. Any offer change clears both players' approval.",56)
			local offered={} for _,pet in ipairs(t.own) do offered[pet.uid]=true end
			row("YOUR OFFER",24,Color3.fromRGB(152,235,210))
			for _,pet in ipairs(s.inventory) do local id=pet.uid;choice((offered[id] and "Remove · " or "Offer · ")..pet.name.." · Lv. "..(pet.level or 1).." · XP "..(pet.xp or 0),function() request("Offer",id) end) end
			row("THEIR OFFER",24,Color3.fromRGB(255,217,145));if #t.other==0 then row("No pets offered.",26) end
			for _,pet in ipairs(t.other) do row(pet.name,28) end
			row((t.ownReady and "You are ready. " or "Review your offer. ")..(t.otherReady and "Partner is ready." or "Partner is reviewing."),40)
			if t.locked then row("Saving exchange…",32) elseif t.ownReady and t.otherReady then choice("Confirm this exact exchange",function() request("Confirm",nil,t.revision) end) else choice("Ready with this offer",function() request("Ready",nil,t.revision) end) end
			choice("Cancel exchange",function() request("Cancel") end)
		elseif s.request then
			row(s.request.name.." wants to trade pets with you. Stay within 35 studs.",52)
			choice("Accept request",function() request("AcceptTrade") end);choice("Decline",function() request("DeclineTrade") end)
		else
			row("Choose a nearby player. Both players review the pets, press Ready, then confirm the exchange.",60)
			if #s.people==0 then row("Another player must join this server to trade.",46) end
			for _,person in ipairs(s.people) do local id=person.id;choice("Request trade · "..person.name,function() request("RequestTrade",id) end) end
		end
	end
end
local function hideJournal()
	local expedition=player.PlayerGui:FindFirstChild("ExpeditionHUD")
	local journal=expedition and expedition:FindFirstChild("ExpeditionJournal")
	if journal then journal.Visible=false end
end
open.Activated:Connect(function() panel.Visible=not panel.Visible;if panel.Visible then hideJournal() end;if panel.Visible then request("State");rebuild() end end)
state.OnClientEvent:Connect(function(s)
	local newTrade=(s.request or s.trade) and (not latest or (not latest.request and not latest.trade))
	latest=s
	if newTrade then tab="Trade";panel.Visible=true;hideJournal() end
	if panel.Visible then local scroll=list.CanvasPosition;rebuild();list.CanvasPosition=scroll end
end)
request("State")
-- Client presentation; the server owns collection, damage and equipment.
local GhostVisuals=require(RS.Shared:WaitForChild("GhostVisuals"))
local visualFolder=Instance.new("Folder");visualFolder.Name="LocalSpiritCompanions";visualFolder.Parent=workspace
local visuals={}
local catalog=require(RS.Shared.GhostCatalog)
local function build(owner)
 if visuals[owner] then for _,rig in ipairs(visuals[owner]) do rig:destroy() end end
 visuals[owner]={}
 local ok,kinds=pcall(HTTP.JSONDecode,HTTP,owner:GetAttribute("EquippedSpiritPets") or "[]")
 if not ok or type(kinds)~="table" then return end
 for i,kind in ipairs(kinds) do
  local def=catalog.ById[kind]
  if i<=5 and def then
   local rig=GhostVisuals.create(visualFolder,kind,Color3.fromRGB(table.unpack(def.color)),.92)
   rig:hide();table.insert(visuals[owner],rig)
  end
 end
end
local watches={}
local function watch(p)
 build(p);watches[p]=p:GetAttributeChangedSignal("EquippedSpiritPets"):Connect(function() build(p) end)
end
for _,p in ipairs(Players:GetPlayers()) do watch(p) end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p)
 if watches[p] then watches[p]:Disconnect();watches[p]=nil end
 if visuals[p] then for _,rig in ipairs(visuals[p]) do rig:destroy() end;visuals[p]=nil end
end)
local elapsed=0
Run.RenderStepped:Connect(function(dt)
 elapsed+=dt
 local low=player:GetAttribute("ClientLowGraphics")
 if elapsed<(low and .1 or 1/30) then return end
 local step=elapsed;elapsed=0
 local localRoot=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local now=os.clock()
 for owner,rigs in pairs(visuals) do
  local root=owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
  for i,rig in ipairs(rigs) do
   if localRoot and root and (root.Position-localRoot.Position).Magnitude<140 then
    local goal=root.CFrame*CFrame.new((i-(#rigs+1)/2)*2.6,1.6+math.sin(now*2+i)*.26,3.8)
    local target=owner:GetAttribute("GhostCombatTarget")
    if typeof(target)=="Vector3" then
     goal=CFrame.lookAt(target+Vector3.new((i-(#rigs+1)/2)*2.7,3+math.sin(now*3+i)*.35,5),target)
    end
    local old=rig.model:GetPivot()
    rig:pose((old.Position-goal.Position).Magnitude>50 and goal or old:Lerp(goal,1-math.exp(-9*step)),now,i,low or player:GetAttribute("ClientVFX")==false)
   else rig:hide() end
  end
 end
end)

open.Visible=false
player.PlayerGui:WaitForChild("HarvestMenuOpen").Event:Connect(function(name)
 panel.Visible=false
 if name=="Ghosts" or name=="Eggs" or name=="GhostCare" then tab=name=="Eggs" and "Eggs" or name=="GhostCare" and "Care" or "Pets";panel.Visible=true;rebirthConfirm=false;if latest then rebuild() end;action:FireServer("State") end
end)

game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
 if game:GetService("CollectionService"):HasTag(prompt,"GhostCarePrompt") then local roost=prompt:FindFirstAncestorWhichIsA("Model");if roost and roost:GetAttribute("OwnerUserId")==player.UserId then player.PlayerGui.HarvestMenuOpen:Fire("GhostCare") end end
end)
