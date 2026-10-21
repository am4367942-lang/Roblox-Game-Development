-- Owner identity is checked on every request, before parsing client data.
local OWNER=3373220410
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Data=require(script.Parent.Modules.DataService)
local Config=require(RS.Shared.Config)
local Ghost=require(RS.Shared.GhostCatalog)
local World=require(RS.Shared.WorldCatalog)
local Ledger=require(script.Parent.Modules.SoulLedger)
local R=RS:WaitForChild("Remotes")
local action=R:WaitForChild("AdminAction");local state=R:WaitForChild("AdminState")
local last={};local flight={}
local function refresh(p) SS.HauntedRefresh:Fire(p);local e=SS:FindFirstChild("GhostRefresh");if e then e:Fire(p) end end
local function stopFlight(p)
 local f=flight[p];if f then if f.velocity then f.velocity:Destroy() end;if f.attachment then f.attachment:Destroy() end;flight[p]=nil end
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid");if h then h.PlatformStand=false end;p:SetAttribute("AdminFlying",false)
end
local function send(p,message)
 local people={} for _,v in ipairs(Players:GetPlayers()) do table.insert(people,{id=v.UserId,name=v.DisplayName.." (@"..v.Name..")"}) end
 state:FireClient(p,{people=people,message=message,owner=OWNER})
end
action.OnServerEvent:Connect(function(p,kind,args)
 if p.UserId~=OWNER then return end
 if typeof(kind)~="string" or typeof(args)~="table" then return end
 if kind=="FlyMove" then
  local f=flight[p];local dir=args.direction
  if f and typeof(dir)=="Vector3" and dir.X==dir.X and dir.Y==dir.Y and dir.Z==dir.Z and dir.Magnitude<2 then f.direction=dir;f.updated=os.clock() end
  return
 end
 if (last[p] or 0)+.2>os.clock() then return end;last[p]=os.clock()
 if kind=="State" then send(p);return end
 local target=Players:GetPlayerByUserId(tonumber(args.target) or OWNER);if not target then send(p,"Player must be in this server.");return end
 local d=Data.get(target);if not d or Data.inventoryBusy(target) or target:GetAttribute("TemporaryProfile") then send(p,"Player profile is unavailable or busy.");return end
 local id=typeof(args.id)=="string" and args.id or "";local n=tonumber(args.amount) or 1
 if n~=n or n==math.huge or n== -math.huge then return end;n=math.clamp(math.floor(n),1,1000000)
 local ok=true
 if kind=="Essence" then d.essence=math.min(1e12,d.essence+n)
 elseif kind=="Souls" then Ledger.add(d,math.min(n,math.max(0,Config.capacityFor(d)-d.souls)),World.Souls[id] and id or "Graveyard","Pure")
 elseif kind=="Egg" and Ghost.EggById[id] then d.eggs[id]=math.min(999,(d.eggs[id] or 0)+n)
 elseif kind=="Ghost" and Ghost.ById[id] then for _=1,math.min(n,30-#d.pets.inventory) do table.insert(d.pets.inventory,{uid=game.HttpService:GenerateGUID(false),kind=id}) end
 elseif kind=="Tool" and Config.ToolById[id] then d.tools[id]=true
 elseif kind=="Storage" and Config.StorageById[id] then d.ownedStorage[id]=true;d.upgrades.JarSize=math.max(d.upgrades.JarSize,Config.StorageById[id].level)
 elseif kind=="Upgrade" and Config.UpgradeById[id] then d.upgrades[id]=math.min(n,Config.UpgradeById[id].maxLevel)
 elseif kind=="Consumable" and World.BoostById[id] then d.consumables[id]=math.min(99,(d.consumables[id] or 0)+n)
 elseif kind=="Food" and Ghost.FoodById[id] then d.foods[id]=math.min(999,(d.foods[id] or 0)+n)
 elseif kind=="RoyalEssence" then d.royalEssence=math.min(999,(d.royalEssence or 0)+n)
 elseif kind=="GhostLevel" then local found=false;for _,pet in ipairs(d.pets.inventory) do if pet.uid==id or pet.kind==id then pet.level=math.clamp(n,1,20);pet.xp=0;found=true end end;ok=found
 elseif kind=="EggMastery" and Ghost.EggById[id] then d.eggLevels[id]=math.clamp(n,1,5)
 elseif kind=="UnlockZone" and World.Souls[id] then d.unlockedZones[id]=true
 elseif kind=="Teleport" and World.Souls[id] then
  local spots={} for _,g in ipairs(game.CollectionService:GetTagged("DigSpot")) do if g:GetAttribute("Zone")==id then table.insert(spots,g) end end
  if #spots>0 and target.Character then target.Character:PivotTo(CFrame.new(spots[1].Position+Vector3.new(0,7,0))) else ok=false end
 elseif kind=="Weather" and World.WeatherById[id] then local f=SS:FindFirstChild("SetWorldWeather");ok=f and f:Invoke(id,math.min(n,3600)) or false
 elseif kind=="Mutation" and World.Souls[id] and World.Mutations[args.mutation] then local f=SS:FindFirstChild("MutateGraveyard");ok=f and f:Invoke(id,args.mutation) or false
 elseif kind=="Boss" and Config.BossById[id] then local f=SS:FindFirstChild("BossDebugSpawn");if f then f:Invoke(id) else ok=false end
 elseif kind=="Heal" then local h=target.Character and target.Character:FindFirstChildOfClass("Humanoid");if h then h.Health=h.MaxHealth end
 elseif kind=="Speed" then local h=target.Character and target.Character:FindFirstChildOfClass("Humanoid");if h then target:SetAttribute("AdminWalkSpeed",math.clamp(n,8,150));h.WalkSpeed=math.clamp(n,8,150) end
 elseif kind=="Fly" and target==p then
  if flight[p] then stopFlight(p) else
   local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
   if root and hum then local a=Instance.new("Attachment");a.Name="AdminFlight";a.Parent=root;local v=Instance.new("LinearVelocity");v.Attachment0=a;v.RelativeTo=Enum.ActuatorRelativeTo.World;v.MaxForce=math.huge;v.VectorVelocity=Vector3.zero;v.Parent=root;hum.PlatformStand=true;flight[p]={attachment=a,velocity=v,direction=Vector3.zero,updated=os.clock()};p:SetAttribute("AdminFlying",true) end
  end
 else ok=false end
 if ok then refresh(target);send(p,kind.." applied to "..target.DisplayName..".") else send(p,"Choose a valid item or action. No change made.") end
end)
game:GetService("RunService").Heartbeat:Connect(function()
 for p,f in pairs(flight) do if not f.velocity.Parent or not p.Character or not p.Character:FindFirstChildOfClass("Humanoid") or p.Character.Humanoid.Health<=0 then stopFlight(p)
 else f.velocity.VectorVelocity=os.clock()-f.updated<.5 and f.direction*55 or Vector3.zero end end
end)
Players.PlayerRemoving:Connect(function(p) stopFlight(p);last[p]=nil end)

