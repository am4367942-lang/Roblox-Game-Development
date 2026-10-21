local C=require(game.ReplicatedStorage.Shared.WorldCatalog)
local Ledger={}
function Ledger.normalize(d)
 d.soulBatches=d.soulBatches or {}
 local target=math.max(0,d.souls-(d.carriedPaidSouls or 0));local total=0
 for key,b in pairs(d.soulBatches) do
  if type(b)~="table" or not C.Souls[b.zone] or not C.Mutations[b.mutation] or type(b.count)~="number" or b.count<=0 then d.soulBatches[key]=nil
  else b.count=math.floor(b.count);total+=b.count end
 end
 if total>target then
  local excess=total-target
  for key,b in pairs(d.soulBatches) do local n=math.min(excess,b.count);b.count-=n;excess-=n;if b.count<=0 then d.soulBatches[key]=nil end;if excess<=0 then break end end
 elseif total<target then
  local key="Graveyard:Pure";local b=d.soulBatches[key] or {zone="Graveyard",mutation="Pure",count=0};b.count+=target-total;d.soulBatches[key]=b
 end
end
function Ledger.add(d,n,zone,mutation)
 Ledger.normalize(d);n=math.max(0,math.floor(n));zone=C.Souls[zone] and zone or "Graveyard";mutation=C.Mutations[mutation] and mutation or "Pure"
 local key=zone..":"..mutation;local b=d.soulBatches[key] or {zone=zone,mutation=mutation,count=0};b.count+=n;d.soulBatches[key]=b;d.souls+=n
 if mutation~="Pure" then d.stats.mutatedSouls=(d.stats.mutatedSouls or 0)+n end
end
function Ledger.consume(d,n,earnedOnly)
 Ledger.normalize(d);n=math.min(math.max(0,math.floor(n)),d.souls)
 local paid=earnedOnly and 0 or math.min(n,d.carriedPaidSouls or 0);d.carriedPaidSouls=(d.carriedPaidSouls or 0)-paid
 local remaining=n-paid;local value=0;local taken=paid
 local keys={} for k in pairs(d.soulBatches) do table.insert(keys,k) end;table.sort(keys)
 for _,key in ipairs(keys) do local b=d.soulBatches[key];local take=math.min(remaining,b.count);value+=take*C.Mutations[b.mutation].value;b.count-=take;remaining-=take;taken+=take;if b.count<=0 then d.soulBatches[key]=nil end;if remaining<=0 then break end end
 d.souls-=taken;return value,paid,taken
end
function Ledger.view(d)
 Ledger.normalize(d);local result={}
 for _,b in pairs(d.soulBatches) do table.insert(result,{zone=b.zone,name=C.Souls[b.zone].name,mutation=b.mutation,count=b.count,multiplier=C.Mutations[b.mutation].value,color=b.mutation=="Pure" and C.Souls[b.zone].color or C.Mutations[b.mutation].color}) end
 table.sort(result,function(a,b) if a.zone==b.zone then return a.mutation<b.mutation end return a.zone<b.zone end)
 return result
end
return Ledger

