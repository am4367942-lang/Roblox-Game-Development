local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Marketplace=game:GetService("MarketplaceService")
local Catalog=require(RS.Shared.MonetizationConfig)
local Config=require(RS.Shared.Config)
local Data=require(script.Parent.Modules.DataService)
local R=RS:WaitForChild("Remotes")
local action=R:WaitForChild("PremiumAction")
local state=R:WaitForChild("PremiumState")
local products,byKey={},{}
local passByKey,passById={},{}
for _,def in ipairs(Catalog.Passes) do passByKey[def.key]=def;if def.id>0 then passById[def.id]=def end end
for _,def in ipairs(Catalog.Products) do byKey[def.key]=def;if def.id>0 then products[def.id]=def end end
local last={}
local function badge(p)
 local d=Data.get(p);local head=p.Character and p.Character:FindFirstChild("Head");if not head then return end
 local old=head:FindFirstChild("VIPBadge");if old then old:Destroy() end
 if d and d.vip then
  local b=Instance.new("BillboardGui");b.Name="VIPBadge";b.Size=UDim2.fromOffset(80,24);b.StudsOffset=Vector3.new(0,3,0);b.MaxDistance=70;b.LightInfluence=0;b.Parent=head
  local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Font=Enum.Font.GothamBold;t.TextSize=16;t.Text="★ VIP";t.TextColor3=Color3.fromRGB(255,218,120);t.TextStrokeTransparency=.15;t.Parent=b
 end
end
local function send(p)
 local d=Data.get(p);if d then state:FireClient(p,{vip=d.vip==true,passes=d.passes or {},boosts=d.boosts,bankedSouls=d.bankedSouls or 0,paidEssence=d.paidEssence or 0}) end
end
local function refreshPasses(p)
 local d=Data.get(p);if not d then return end;d.passes=d.passes or {}
 for _,def in ipairs(Catalog.Passes) do
  if def.id>0 then
   local ok,owns=pcall(function() return Marketplace:UserOwnsGamePassAsync(p.UserId,def.id) end)
   if ok and p.Parent then if def.key=="VIP" then d.vip=owns else d.passes[def.key]=owns end end
  end
 end
 if p.Parent then badge(p);send(p);SS.HauntedRefresh:Fire(p);local e=SS:FindFirstChild("GhostRefresh");if e then e:Fire(p) end end
end
action.OnServerEvent:Connect(function(p,key)
 if typeof(key)~="string" or (last[p] or 0)+.7>os.clock() then return end;last[p]=os.clock()
 local d=Data.get(p);if not d or Data.inventoryBusy(p) or p:GetAttribute("TemporaryProfile") then return end
 if key=="State" then send(p);return end
 if key=="TransferSouls" then
  if p:GetAttribute("Refining") then R.Notify:FireClient(p,"Pause conversion at your Spirit Roost before filling your jar.","warn");return end
  local n=math.min(d.bankedSouls or 0,math.max(0,Config.capacityFor(d)-d.souls))
  if n<=0 then R.Notify:FireClient(p,"Equip storage with free space to transfer banked souls.","warn");return end
  d.bankedSouls-=n;d.souls+=n;d.carriedPaidSouls=(d.carriedPaidSouls or 0)+n
  SS.HauntedRefresh:Fire(p);send(p);R.Notify:FireClient(p,n.." souls transferred to your jar.","good");return
 end
 local pass=passByKey[key]
 if pass and pass.id>0 then local owned=key=="VIP" and d.vip or d.passes[key];if not owned then local ok=pcall(function() Marketplace:PromptGamePassPurchase(p,pass.id) end);if not ok then R.Notify:FireClient(p,"Purchase prompt unavailable. Please try again.","warn") end end;return end
 local def=byKey[key]
 if def and def.id>0 then
  local ok=pcall(function() Marketplace:PromptProductPurchase(p,def.id) end)
  if not ok then R.Notify:FireClient(p,"Roblox could not open this purchase. Please try again.","warn") end
 end
end)
Marketplace.ProcessReceipt=function(receipt)
 local p=Players:GetPlayerByUserId(receipt.PlayerId);local def=products[receipt.ProductId]
 if not p or not def then return Enum.ProductPurchaseDecision.NotProcessedYet end
 local ok=Data.applyReceipt(p,tostring(receipt.PurchaseId),function(d)
  if def.kind=="boost" then d.boosts[def.key]=math.max(os.time(),d.boosts[def.key] or 0)+def.duration
  elseif def.kind=="essence" then d.essence+=def.amount;d.paidEssence=(d.paidEssence or 0)+def.amount
  elseif def.kind=="souls" then d.bankedSouls=(d.bankedSouls or 0)+def.amount end
 end)
 if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
 send(p);SS.HauntedRefresh:Fire(p)
 local ghost=SS:FindFirstChild("GhostRefresh");if ghost then ghost:Fire(p) end
 return Enum.ProductPurchaseDecision.PurchaseGranted
end
Marketplace.PromptGamePassPurchaseFinished:Connect(function(p,id,purchased) if passById[id] and purchased then task.spawn(refreshPasses,p) end end)
Data.onLoaded(function(p) p.CharacterAdded:Connect(function() task.wait(.5);badge(p) end);send(p);task.spawn(refreshPasses,p) end)
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
task.spawn(function() while true do task.wait(10);for _,p in ipairs(Players:GetPlayers()) do send(p) end end end)
