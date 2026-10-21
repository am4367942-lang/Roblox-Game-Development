local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local CS=game:GetService("CollectionService")
local C=require(RS.Shared.WorldCatalog)
local Config=require(RS.Shared.Config)
local Data=require(script.Parent.Modules.DataService)
local Ledger=require(script.Parent.Modules.SoulLedger)
local R=RS:WaitForChild("Remotes")
local action=R:WaitForChild("WorldAction");local state=R:WaitForChild("WorldState")
local status=Instance.new("Folder");status.Name="WorldWeather";status.Parent=RS
local boosts=Instance.new("Folder");boosts.Name="GraveyardBoosts";boosts.Parent=RS
local rng=Random.new();local override;local weather=C.WeatherById.Clear;local ends=0
local function choose(now)
 local hour=math.floor(now/3600);local total=0;for _,v in ipairs(C.Weather) do total+=v.weight end;local roll=Random.new(hour+10770526598):NextNumber(0,total);local sum=0
 for _,w in ipairs(C.Weather) do sum+=w.weight;if roll<=sum then return w,hour*3600+w.duration end end
 return C.WeatherById.Clear,hour*3600
end
local function setWeather(w,untilTime)
 weather=w;ends=untilTime;status:SetAttribute("Id",w.id);status:SetAttribute("EndsAt",ends);status:SetAttribute("NextAt",(math.floor(os.time()/3600)+1)*3600)
end
local admin=Instance.new("BindableFunction");admin.Name="SetWorldWeather";admin.Parent=SS
admin.OnInvoke=function(id,duration)
 local w=C.WeatherById[id];if not w then return false end;override={w=w,ends=os.time()+math.clamp(tonumber(duration) or 600,30,3600)};setWeather(w,override.ends);return true
end
local function send(p)
 local d=Data.get(p);if not d then return end
 local active={} for _,f in ipairs(boosts:GetChildren()) do active[f.Name]={multiplier=f:GetAttribute("Multiplier"),ends=f:GetAttribute("EndsAt")} end
 state:FireClient(p,{souls=Ledger.view(d),consumables=d.consumables or {},badges=d.badges or {},stats=d.stats,boosts=active,essence=d.essence,unlockedZones=d.unlockedZones})
end
local last={}
action.OnServerEvent:Connect(function(p,kind,id,zone)
 if typeof(kind)~="string" or (last[p] or 0)+.25>os.clock() then return end;last[p]=os.clock()
 local d=Data.get(p);if not d then return end
 if kind=="State" then send(p);return end
 if Data.inventoryBusy(p) or p:GetAttribute("TemporaryProfile") then return end
 d.consumables=d.consumables or {};d.badges=d.badges or {}
 if kind=="BuyBoost" then
  local b=typeof(id)=="string" and C.BoostById[id];if not b or (d.consumables[id] or 0)>=99 then return end
  if not Config.spendEssence(d,b.price) then R.Notify:FireClient(p,"Not enough Essence.","warn");return end
  d.consumables[id]=(d.consumables[id] or 0)+1
 elseif kind=="UseBoost" then
  local b=typeof(id)=="string" and C.BoostById[id];local z=typeof(zone)=="string" and Config.Zones[zone]
  if not b or not C.Souls[zone] or (z and z.requires and not d.unlockedZones[zone]) or (d.consumables[id] or 0)<=0 then return end
  local f=boosts:FindFirstChild(zone);local now=os.time()
  if f and (f:GetAttribute("EndsAt") or 0)>now then R.Notify:FireClient(p,"This graveyard already has an active boost. Wait until it finishes.","info");return end
  d.consumables[id]-=1;f=f or Instance.new("Folder");f.Name=zone;f:SetAttribute("Multiplier",b.multiplier);f:SetAttribute("EndsAt",now+b.duration);f.Parent=boosts
  R.Notify:FireAllClients(p.DisplayName.." boosted "..zone.." recharge to "..b.multiplier.."×!","good")
 elseif kind=="ClaimBadge" then
  for _,b in ipairs(C.Badges) do if b.id==id and not d.badges[id] and (d.stats[b.stat] or 0)>=b.goal then d.badges[id]=true;d.essence+=b.reward;R.Notify:FireClient(p,b.name.." earned! +"..b.reward.." Essence","good");break end end
 else return end
 send(p);SS.HauntedRefresh:Fire(p)
end)
local function style(spot)
 local def=C.Souls[spot:GetAttribute("Zone") or "Graveyard"] or C.Souls.Graveyard
 local mutation=spot:GetAttribute("Mutation") or "Pure";local m=C.Mutations[mutation] or C.Mutations.Pure
 local color=Color3.fromRGB(table.unpack(mutation=="Pure" and def.color or m.color))
 spot:SetAttribute("SoulType",def.name);spot:SetAttribute("MutationValue",m.value)
 local ghost=spot:FindFirstChild("ReserveGhost")
 if ghost then for _,part in ipairs(ghost:GetChildren()) do if part:IsA("BasePart") and part.Name~="Eye" and not part.Name:find("Eye") then part.Color=color end end end
 local w=spot:FindFirstChild("GraveWisp");if w and w:IsA("ParticleEmitter") then w.Color=ColorSequence.new(color) end
 local light=spot:FindFirstChild("ReserveLight");if light and light:IsA("PointLight") then light.Color=color end
end
local mutate=Instance.new("BindableFunction");mutate.Name="MutateGraveyard";mutate.Parent=SS
mutate.OnInvoke=function(zone,mutation)
 if not C.Souls[zone] or not C.Mutations[mutation] then return false end
 for _,spot in ipairs(CS:GetTagged("DigSpot")) do if spot:GetAttribute("Zone")==zone then spot:SetAttribute("Mutation",mutation);spot:SetAttribute("MutationUntil",os.time()+1800);style(spot) end end;return true
end
for _,spot in ipairs(CS:GetTagged("DigSpot")) do style(spot) end
CS:GetInstanceAddedSignal("DigSpot"):Connect(style)
Data.onLoaded(send);Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
task.spawn(function()
 local previous="";local mutationAt=0
 while true do
  local now=os.time();local w,expires=choose(now)
  if override and override.ends>now then w=override.w;expires=override.ends else override=nil;if now>=expires then w=C.WeatherById.Clear end end
  setWeather(w,expires)
  if previous~=w.id then previous=w.id;if w.id~="Clear" then R.Notify:FireAllClients(w.name.." · Graves may become "..w.mutation.."!","good") end end
  if now>=mutationAt then
   mutationAt=now+90
   for i,spot in ipairs(CS:GetTagged("DigSpot")) do
    if (spot:GetAttribute("MutationUntil") or 0)<=now then spot:SetAttribute("Mutation","Pure") end
    local old=C.Mutations[spot:GetAttribute("Mutation") or "Pure"] or C.Mutations.Pure
    if w.value>=old.value and rng:NextNumber()<w.chance then spot:SetAttribute("Mutation",w.mutation);spot:SetAttribute("MutationUntil",now+1800) end
    style(spot);if i%80==0 then task.wait() end
   end
  end
  for _,f in ipairs(boosts:GetChildren()) do if (f:GetAttribute("EndsAt") or 0)<=now then f:Destroy() end end
  for _,p in ipairs(Players:GetPlayers()) do send(p) end
  task.wait(5)
 end
end)

