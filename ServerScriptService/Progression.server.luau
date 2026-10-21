-- Server-owned pets, rebirths, recurring expeditions, rankings and pet trades.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local CS=game:GetService("CollectionService")
local HTTP=game:GetService("HttpService")
local Data=require(script.Parent.Modules.DataService)
local Config=require(RS.Shared.Config)
local Quest=require(script.Parent.Modules.QuestService)
local Reserves=require(script.Parent.Modules.GraveReserves)
local remotes=RS:WaitForChild("Remotes")
local action=remotes:WaitForChild("FeatureAction")
local state=remotes:WaitForChild("FeatureState")
local SoulLedger=require(script.Parent.Modules.SoulLedger)
local notify=remotes:WaitForChild("Notify")
local refresh=SS:WaitForChild("HauntedRefresh")
local collected=SS:WaitForChild("HarvestCollected")
local trades,requests,lastAction={}, {}, {}
local rankings={}
local ranksReady=false
local rankingStore=game:GetService("DataStoreService"):GetOrderedDataStore(script.Parent.Modules.DataService:GetAttribute("StudioQA") and game:GetService("RunService"):IsStudio() and "HauntedHarvest_Ranks_StudioQA" or "HauntedHarvest_Ranks_v1")
local regions={"Graveyard","Moonveil","Briarwatch","Starfall","HollowCaverns","Crownrest"}
local GhostCatalog=require(RS.Shared.GhostCatalog)
local pets=GhostCatalog.Pets
local byId={} for _,def in ipairs(pets) do byId[def.id]=def end
local function event()
	local now=os.time()
	local qaTime=script:GetAttribute("QATime")
	if game:GetService("RunService"):IsStudio() and script.Parent.Modules.DataService:GetAttribute("StudioQA") and typeof(qaTime)=="number" then now=qaTime end
	local period=math.floor(now/3600);local remaining=900-now%3600
	return {id=tostring(period),active=remaining>0,remaining=math.max(0,remaining),nextIn=3600-now%3600,zone=regions[period%#regions+1],goal=250,reward=1000}
end
local function init(d)
	d.pets=d.pets or {inventory={},equipped={}};d.pets.inventory=d.pets.inventory or {};d.pets.equipped=d.pets.equipped or {}
	d.rebirths=d.rebirths or 0;d.events=d.events or {};d.eggs=d.eggs or {}
end
local function findPet(d,id)
	for _,pet in ipairs(d.pets.inventory) do if pet.uid==id then return pet end end
end
local function note(p,text,kind) if p.Parent then notify:FireClient(p,text,kind or "info") end end
local function syncPets(p,d)
	local equipped={}
	for _,uid in ipairs(d.pets.equipped) do local pet=findPet(d,uid);if pet and byId[pet.kind] then table.insert(equipped,pet.kind) end end
	p:SetAttribute("EquippedSpiritPets",HTTP:JSONEncode(equipped))
	local bonus=0 for _,kind in ipairs(equipped) do bonus+=byId[kind].bonus end
	p:SetAttribute("PetRefiningBonus",bonus)
	p:SetAttribute("Rebirths",d.rebirths)
end
local function offerView(d,ids)
	local r={} for _,id in ipairs(ids) do local pet=findPet(d,id);if pet then table.insert(r,{uid=pet.uid,kind=pet.kind,name=(byId[pet.kind] and byId[pet.kind].name or pet.kind).." · Lv. "..(pet.level or 1).." · XP "..(pet.xp or 0)}) end end return r
end
local function send(p)
	local d=Data.get(p);if not d then return end;init(d)
	local ev=event();local progress=d.events.period==ev.id and (d.events.progress or 0) or 0
	ev.progress=progress;ev.claimed=d.events.period==ev.id and d.events.claimed==true;ev.label=Config.Zones[ev.zone].label
	local people={} for _,other in ipairs(Players:GetPlayers()) do if other~=p then table.insert(people,{id=other.UserId,name=other.DisplayName}) end end
	local trade=trades[p];local view
	if trade then
		local other=trade.a==p and trade.b or trade.a;local od=Data.get(other)
		view={partner=other.DisplayName,revision=trade.revision,own=offerView(d,trade.offers[p]),other=od and offerView(od,trade.offers[other]) or {},ownReady=trade.ready[p]==true,otherReady=trade.ready[other]==true,locked=trade.locked==true}
	end
	local inventory={} for _,pet in ipairs(d.pets.inventory) do
		local equipped=table.find(d.pets.equipped,pet.uid)~=nil
		table.insert(inventory,{uid=pet.uid,kind=pet.kind,name=byId[pet.kind] and byId[pet.kind].name or pet.kind,equipped=equipped,paid=pet.paid==true,level=pet.level or 1,xp=pet.xp or 0,nextXP=GhostCatalog.xpToLevel(pet.level or 1)})
	end
	state:FireClient(p,{pets=pets,maxEquipped=GhostCatalog.maxEquipped(d),inventory=inventory,eggs=d.eggs,foods=d.foods or {},royalEssence=d.royalEssence or 0,eggLevels=d.eggLevels or {},eggCatalog=GhostCatalog.Eggs,refineRate=GhostCatalog.refineRate(d),rebirths=d.rebirths,rebirthCost=math.floor(50000*1.75^d.rebirths),rebirthMax=10,bonus=Config.progressionMultiplier(d),event=ev,people=people,trade=view,request=requests[p] and {id=requests[p].UserId,name=requests[p].DisplayName} or nil,rankings=rankings,ranksReady=ranksReady,busy=Data.inventoryBusy(p)})
end
-- Confirm the actual species and progression each player reviewed, not only UIDs.
local function tradeSignature(t)
 local offers={}
 for _,p in ipairs({t.a,t.b}) do
  local d=Data.get(p)
  if not d then return nil end
  local items={}
  for _,uid in ipairs(t.offers[p]) do
   local pet=findPet(d,uid)
   if not pet then return nil end
   table.insert(items,{pet.uid,pet.kind,pet.level or 1,pet.xp or 0,pet.paid==true})
  end
  table.insert(offers,items)
 end
 return HTTP:JSONEncode(offers)
end
local function invalidateChangedOffer(t)
 local current=tradeSignature(t)
 if current and (not t.approvedSignature or current==t.approvedSignature) then return false end
 t.ready={};t.confirmed={};t.approvedSignature=nil;t.revision+=1
 for _,p in ipairs({t.a,t.b}) do
  note(p,"An offered ghost changed. Review the updated exchange and press Ready again.","warn")
  send(p)
 end
 return true
end
local function closeTrade(t,message)
	if not t then return end
	trades[t.a]=nil;trades[t.b]=nil
	for _,p in ipairs({t.a,t.b}) do if p.Parent then local d=Data.get(p);if d then syncPets(p,d);refresh:Fire(p);send(p);if message then note(p,message) end end end end
end
local function nearLodge(p)
	local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 then return false end
	for _,counter in ipairs(CS:GetTagged("ShopCounter")) do if (root.Position-counter.Position).Magnitude<=45 then return true end end
	local home=p:GetAttribute("SpiritRoostPosition")
	return typeof(home)=="Vector3" and (root.Position-home).Magnitude<=45
end
local function closeEnough(a,b)
	local ar=a.Character and a.Character:FindFirstChild("HumanoidRootPart");local br=b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	local ah=a.Character and a.Character:FindFirstChildOfClass("Humanoid");local bh=b.Character and b.Character:FindFirstChildOfClass("Humanoid")
	return ar and br and ah and bh and ah.Health>0 and bh.Health>0 and (ar.Position-br.Position).Magnitude<=35
end
local allowed={State=true,BuyPet=true,BuyEgg=true,HatchEgg=true,Equip=true,Rebirth=true,ClaimEvent=true,RequestTrade=true,AcceptTrade=true,DeclineTrade=true,Offer=true,Ready=true,Confirm=true,Cancel=true}
action.OnServerEvent:Connect(function(p,kind,value,revision)
	if not allowed[kind] then return end
	local now=os.clock();if now-(lastAction[p] or -2)<.2 then return end;lastAction[p]=now
	local d=Data.get(p);if not d then return end;init(d)
	if kind=="State" then send(p);return end
	if Data.inventoryBusy(p) then note(p,"Your inventory is saving an exchange. Please wait.");return end
	if kind=="BuyPet" then
		local def=typeof(value)=="string" and byId[value]
		if not def or def.price<=0 or not nearLodge(p) or #d.pets.inventory>=30 then return end
		if d.essence<def.price then note(p,"You need "..def.price.." Essence.","warn");return end
		local paidPurchase=(d.paidEssence or 0)>0;Config.spendEssence(d,def.price);local pet={uid=HTTP:GenerateGUID(false),kind=def.id,paid=paidPurchase};table.insert(d.pets.inventory,pet)
		if #d.pets.equipped<GhostCatalog.maxEquipped(d) then table.insert(d.pets.equipped,pet.uid) end
		note(p,def.name.." joined your team!","good")
	elseif kind=="BuyEgg" then
		local egg=typeof(value)=="string" and GhostCatalog.EggById[value]
		if not egg or not nearLodge(p) or (d.eggs[egg.id] or 0)>=999 then return end
		if not Config.spendEssence(d,egg.price,true) then note(p,"Eggs require "..egg.price.." earned Essence. Purchased Essence cannot buy random eggs.","warn");return end
		d.eggs[egg.id]=(d.eggs[egg.id] or 0)+1
		note(p,egg.name.." bought. Open it from the Eggs tab.","good")
	elseif kind=="HatchEgg" then
		local egg=typeof(value)=="string" and GhostCatalog.EggById[value]
		if not egg or (d.eggs[egg.id] or 0)<1 then return end
        local own=p:GetAttribute("SpiritRoostPosition");local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");if typeof(own)~="Vector3" or not root or (root.Position-own).Magnitude>26 then note(p,"Hatch eggs at your own Spirit Roost.","warn");return end
		if #d.pets.inventory>=30 then note(p,"Your ghost inventory is full. Trade a ghost to make room.","warn");return end
		local roll=Random.new():NextNumber(0,100);local total=0;local kind=egg.outcomes[#egg.outcomes][1]
		for _,outcome in ipairs(egg.outcomes) do total+=outcome[2];if roll<total then kind=outcome[1];break end end
		d.eggs[egg.id]-=1;local pet={uid=HTTP:GenerateGUID(false),kind=kind,level=math.clamp((d.eggLevels or {})[egg.id] or 1,1,5),xp=0};table.insert(d.pets.inventory,pet)
		if #d.pets.equipped<GhostCatalog.maxEquipped(d) then table.insert(d.pets.equipped,pet.uid) end
		note(p,"Hatched "..byId[kind].name.."! ("..byId[kind].rarity..")","good")
	elseif kind=="Equip" then
		if typeof(value)~="string" or not findPet(d,value) then return end
		local i=table.find(d.pets.equipped,value)
		if i then table.remove(d.pets.equipped,i) elseif #d.pets.equipped<GhostCatalog.maxEquipped(d) then table.insert(d.pets.equipped,value) else note(p,"Your equipped ghost slots are full.");return end
	elseif kind=="Rebirth" then
		if value~="CONFIRM_RESET" or d.rebirths>=10 or not nearLodge(p) or trades[p] then return end
		local cost=math.floor(50000*1.75^d.rebirths)
		if d.essence<cost then note(p,"You need "..cost.." Essence to rebirth.","warn");return end
		Config.spendEssence(d,cost);d.rebirths+=1;d.essence=d.paidEssence or 0;d.bankedSouls=(d.bankedSouls or 0)+(d.carriedPaidSouls or 0);d.carriedPaidSouls=0;d.souls=0;d.soulBatches={};d.upgrades={JarSize=0,Refinement=0,GreedyHands=0,SpectralBoots=0,Helpers=0};d.tools={GraveVacuum=true};d.ownedStorage={ClayJar=true};d.equipment={tool="GraveVacuum",storage="ClayJar"};d.unlockedZones={};d.quest=nil
		for _,container in ipairs({p.Backpack,p.Character}) do for _,tool in ipairs(container:GetChildren()) do if tool:IsA("Tool") and tool:GetAttribute("ToolId")~="GraveVacuum" then tool:Destroy() end end end
		p:LoadCharacterAsync();note(p,"Rebirth complete! Permanent refining bonus increased by 15%.","good")
	elseif kind=="ClaimEvent" then
		local ev=event()
		if not ev.active or d.events.period~=ev.id or d.events.claimed or (d.events.progress or 0)<ev.goal then return end
		d.events.claimed=true;d.essence+=ev.reward;d.stats.totalEssence+=ev.reward;note(p,"Lantern Bloom complete! +1000 Essence.","good")
	elseif kind=="RequestTrade" then
		if typeof(value)~="number" or value~=value or value%1~=0 or trades[p] then return end
		local other=Players:GetPlayerByUserId(value)
		if not other or other==p or trades[other] or requests[other] or not Data.get(other) or Data.inventoryBusy(other) or not closeEnough(p,other) then return end
		requests[other]=p;note(p,"Trade request sent to "..other.DisplayName..".");send(other)
		task.delay(30,function() if requests[other]==p then requests[other]=nil;if other.Parent then send(other) end end end)
	elseif kind=="AcceptTrade" then
		local other=requests[p];requests[p]=nil
		if not other or not other.Parent or trades[p] or trades[other] or not Data.get(other) or Data.inventoryBusy(other) or not closeEnough(p,other) then send(p);return end
		local t={a=p,b=other,offers={[p]={},[other]={}},ready={},revision=1}
		trades[p]=t;trades[other]=t;send(other)
	elseif kind=="DeclineTrade" then requests[p]=nil
	elseif kind=="Cancel" then local t=trades[p];if t and not t.locked then closeTrade(t,"Trade cancelled.") end;return
	elseif kind=="Offer" then
		local t=trades[p];if not t or t.locked or typeof(value)~="string" or not findPet(d,value) then return end
		if findPet(d,value).paid then note(p,"Ghosts bought with purchased Essence cannot be traded.","warn");return end
 local offer=t.offers[p];local i=table.find(offer,value)
		if i then table.remove(offer,i) elseif #offer<3 then table.insert(offer,value) else return end
		t.ready={};t.confirmed={};t.approvedSignature=nil;t.revision+=1;send(t.a);send(t.b);return
	elseif kind=="Ready" then
		local t=trades[p];if not t or t.locked or revision~=t.revision or not closeEnough(t.a,t.b) then return end
		if invalidateChangedOffer(t) then return end
		t.approvedSignature=tradeSignature(t);t.ready[p]=true;send(t.a);send(t.b);return
	elseif kind=="Confirm" then
		local t=trades[p];if not t or t.locked or revision~=t.revision or not t.ready[t.a] or not t.ready[t.b] or not closeEnough(t.a,t.b) then return end
		if invalidateChangedOffer(t) then return end
		t.confirmed=t.confirmed or {};t.confirmed[p]=true
		if not t.confirmed[t.a] or not t.confirmed[t.b] then note(p,"Confirmed. Waiting for your partner.");return end
		t.locked=true;send(t.a);send(t.b)
		local ok,message=Data.trade(t.a,t.b,t.offers[t.a],t.offers[t.b]);closeTrade(t,ok and "Pet exchange complete!" or message);return
	end
	syncPets(p,d);refresh:Fire(p);send(p)
end)
collected.Event:Connect(function(p,amount,zone)
	local d=Data.get(p);if not d then return end;init(d);local ev=event()
	if not ev.active or ev.zone~=zone then return end
	if d.events.period~=ev.id then d.events={period=ev.id,progress=0,claimed=false} end
	if d.events.claimed then return end
	local before=d.events.progress;d.events.progress=math.min(ev.goal,before+amount)
	if before<ev.goal and d.events.progress==ev.goal then note(p,"Lantern Bloom ready! Claim your reward in Spirit Lodge.","good");send(p) end
end)
local ghostRefresh=Instance.new("BindableEvent");ghostRefresh.Name="GhostRefresh";ghostRefresh.Parent=SS
ghostRefresh.Event:Connect(function(p) local d=Data.get(p);if d then init(d);syncPets(p,d);send(p) end end)
Data.onLoaded(function(p,d)
	init(d)
	if not d.ghostStarterGranted then d.ghostStarterGranted=true;d.eggs.LanternEgg=(d.eggs.LanternEgg or 0)+1;note(p,"Welcome gift: a Lantern Ghost Egg! Open Ghost Lodge to hatch it.","good") end
	syncPets(p,d);send(p)
end)
Players.PlayerRemoving:Connect(function(p)
	local t=trades[p];if t and not t.locked then closeTrade(t,"Your trade partner left.") end
	requests[p]=nil;lastAction[p]=nil
	for receiver,sender in pairs(requests) do if sender==p then requests[receiver]=nil;if receiver.Parent then send(receiver) end end end
end)
task.spawn(function()
	while true do
		task.wait(3)
		for _,p in ipairs(Players:GetPlayers()) do
			local d=Data.get(p);local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if d and root and hum and hum.Health>0 and not Data.inventoryBusy(p) then
				init(d);local candidates={}
				for _,g in ipairs(CS:GetTagged("DigSpot")) do local z=Config.Zones[g:GetAttribute("Zone") or "Graveyard"]
					if g:IsA("BasePart") and g:IsDescendantOf(workspace) and (not z or not z.requires or d.unlockedZones[g:GetAttribute("Zone")]) and math.abs(g.Position.Y-root.Position.Y)<12 and (g.Position-root.Position).Magnitude<=30 and Reserves.available(g)>=1 then table.insert(candidates,g) end
				end
				table.sort(candidates,function(a,b) return (a.Position-root.Position).Magnitude<(b.Position-root.Position).Magnitude end)
				local total=0;local collectorIndex=0
				for _,uid in ipairs(d.pets.equipped) do local pet=findPet(d,uid);local def=pet and GhostCatalog.stats(pet)
					if def and def.power>0 then collectorIndex+=1 end
					local grave=def and def.power>0 and candidates[collectorIndex] or nil
					if def and def.power>0 and grave and not p:GetAttribute("Refining") then local n=Reserves.take(grave,math.min(def.power,math.max(0,Config.capacityFor(d)-d.souls)));if n>0 then SoulLedger.add(d,n,grave:GetAttribute("Zone"),grave:GetAttribute("Mutation"));d.stats.totalSouls+=n;total+=n;Quest.onCollect(p,d,n,grave:GetAttribute("Zone") or "Graveyard");remotes.HelperFX:FireClient(p,grave.Position) end end
				end
				if total>0 then refresh:Fire(p) end
				local bossFolder=workspace:FindFirstChild("Bosses");local boss=bossFolder and bossFolder:FindFirstChildWhichIsA("Model")
				local bossRoot=boss and boss:FindFirstChild("HumanoidRootPart")
				local hit=SS:FindFirstChild("BossHit")
				if bossRoot and hit and (bossRoot.Position-root.Position).Magnitude<=42 then
					p:SetAttribute("GhostCombatTarget",bossRoot.Position)
					for _,def in ipairs(GhostCatalog.equipped(d)) do if def.bossDamage>0 then
						local success=hit:Invoke(p,root.Position,Vector3.new(0,0,-1),36,360,def.bossDamage*Config.combatMultiplier(d))
						if success then remotes.GhostCombatFX:FireAllClients(p,bossRoot.Position,Color3.fromRGB(table.unpack(def.color))) end
					end end
				else p:SetAttribute("GhostCombatTarget",nil) end
			end
		end
	end
end)
task.spawn(function()
	while true do
		for _,p in ipairs(Players:GetPlayers()) do local d=Data.get(p)
			if d and not p:GetAttribute("TemporaryProfile") then local ok,err=pcall(function() rankingStore:UpdateAsync(tostring(p.UserId),function(old) return math.max(old or 0,math.floor(d.stats.totalSouls)) end) end);if not ok then warn("[Rankings] "..tostring(err)) end;task.wait(1) end
		end
		local ok,page=pcall(function() return rankingStore:GetSortedAsync(false,10):GetCurrentPage() end)
		if ok then local nextRanks={} for _,row in ipairs(page) do local userId=tonumber(row.key);local name=row.key;pcall(function() name=Players:GetNameFromUserIdAsync(userId) end);table.insert(nextRanks,{name=name,souls=row.value}) end;rankings=nextRanks;ranksReady=true end
		for _,p in ipairs(Players:GetPlayers()) do send(p) end
		task.wait(120)
	end
end)
task.spawn(function() while true do task.wait(10);for _,p in ipairs(Players:GetPlayers()) do send(p) end end end)
