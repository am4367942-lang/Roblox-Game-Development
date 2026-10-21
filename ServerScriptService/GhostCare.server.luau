local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Data=require(script.Parent.Modules.DataService)
local Config=require(RS.Shared.Config)
local C=require(RS.Shared.GhostCatalog)
local Layout=require(script.Parent.Modules.RoostLayout)
local R=RS:WaitForChild("Remotes")
local action=R:WaitForChild("RoostAction")
local refresh=SS:WaitForChild("GhostRefresh")
local last={}
local function ownRoost(p)
 for _,r in ipairs(workspace.SpiritRoosts:GetChildren()) do if r:IsA("Model") and r:GetAttribute("OwnerUserId")==p.UserId then return r end end
end
local function render(p)
 local d=Data.get(p);local r=ownRoost(p);if not d or not r then return end
 local cells=r:FindFirstChild("SpiritCells");if not cells then return end
 for i=1,30 do
  local cell=cells:FindFirstChild("Cell"..i);local pet=Layout.petAt(d,i)
  if cell then
   local def=pet and C.ById[pet.kind];local color=def and Color3.fromRGB(table.unpack(def.color)) or Color3.fromRGB(74,66,97)
   local body=cell:FindFirstChild("GhostBody");if body then body.Color=color;body.Transparency=1 end
   cell:SetAttribute("SpiritKind",def and pet.kind or nil);cell:SetAttribute("GhostUid",def and pet.uid or nil);cell:SetAttribute("GhostName",def and def.name or nil);cell:SetAttribute("GhostLevel",def and (pet.level or 1) or nil);cell:SetAttribute("GhostRarity",def and def.rarity or nil);cell:SetAttribute("GhostEquipped",def and table.find(d.pets.equipped,pet.uid)~=nil or nil)
   for _,v in ipairs(cell:GetChildren()) do if v.Name:find("Eye") then v.Transparency=1 end end
   local tile=cell:FindFirstChild("Tile");local g=tile and tile:FindFirstChild("Label");local t=g and g:FindFirstChild("Text")
   if t then t.Text=def and (def.name.."\nLv. "..(pet.level or 1)..(table.find(d.pets.equipped,pet.uid) and " · ACTIVE" or "")) or ("SPIRIT SLOT "..i);t.TextColor3=def and color or Color3.fromRGB(147,142,167) end
  end
 end
 local egg=r:FindFirstChild("NestEgg",true);if egg then local count=0;for _,n in pairs(d.eggs) do count+=n end;egg.Transparency=count>0 and .1 or .75 end
end
action.OnServerEvent:Connect(function(p,kind,id,uid)
 if typeof(kind)~="string" or typeof(id)~="string" or (last[p] or 0)+.3>os.clock() then return end;last[p]=os.clock()
 local d=Data.get(p);if not d or Data.inventoryBusy(p) or p:GetAttribute("TemporaryProfile") then return end
 local roost=ownRoost(p);local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart");local altar=roost and roost:FindFirstChild("RoostConvertPad",true)
 local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 if not altar or not root or not hum or hum.Health<=0 or (root.Position-altar.Position).Magnitude>26 then R.Notify:FireClient(p,"Care for ghosts at your own Spirit Roost.","warn");return end
 d.foods=d.foods or {};d.eggLevels=d.eggLevels or {};d.royalEssence=d.royalEssence or 0
 local pet;for _,v in ipairs(d.pets.inventory) do if v.uid==uid then pet=v;break end end
 if kind=="BuyFood" then
  local f=C.FoodById[id];if not f or (d.foods[id] or 0)>=999 then return end
  if not Config.spendEssence(d,f.price) then R.Notify:FireClient(p,"Not enough Essence.","warn");return end;d.foods[id]=(d.foods[id] or 0)+1
 elseif kind=="Feed" then
  local f=C.FoodById[id];if not f or not pet or (d.foods[id] or 0)<1 then return end
  if (pet.level or 1)>=20 then R.Notify:FireClient(p,"This ghost is already level 20.","info");return end
  d.foods[id]-=1;local before=pet.level or 1;C.addXP(pet,f.xp);R.Notify:FireClient(p,pet.level>before and (C.ById[pet.kind].name.." reached level "..pet.level.."!") or ("+"..f.xp.." ghost XP"),"good")
 elseif kind=="TrainEgg" then
  local egg=C.EggById[id];local level=d.eggLevels[id] or 1;if not egg or level>=5 or (d.eggs[id] or 0)<1 then return end
  local cost=egg.price*level*2;if not Config.spendEssence(d,cost,true) then R.Notify:FireClient(p,"Egg training needs "..cost.." earned Essence.","warn");return end
  d.eggLevels[id]=level+1;R.Notify:FireClient(p,egg.name.." mastery is level "..(level+1)..". Future hatches of this egg start at that level.","good")
 elseif kind=="BuyRoyalEssence" then
  if d.royalEssence>=999 or not Config.spendEssence(d,12000,true) then R.Notify:FireClient(p,"Royal Essence costs 12,000 earned Essence.","warn");return end;d.royalEssence+=1
 elseif kind=="RoyalEssence" then
  if not pet or d.royalEssence<1 then return end
  local roll=Random.new():NextNumber(0,100);local kind=roll<40 and "MossSprite" or roll<70 and "GuardianGhost" or roll<90 and "CrystalSpirit" or roll<99 and "SpectralKnight" or "RoyalPhantom"
  d.royalEssence-=1;pet.kind=kind;R.Notify:FireClient(p,"Royal Essence transformed your ghost into "..C.ById[kind].name.."! Level and XP kept.","good")
 else return end
 refresh:Fire(p);SS.HauntedRefresh:Fire(p);render(p)
end)
refresh.Event:Connect(render)
Layout.setRenderer(render)
Data.onLoaded(function(p) task.defer(render,p);p:GetAttributeChangedSignal("SpiritRoost"):Connect(function() render(p) end) end)
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
task.spawn(function() while true do task.wait(5);for _,p in ipairs(Players:GetPlayers()) do render(p) end end end)

