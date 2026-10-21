local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Data=require(script.Parent.Modules.DataService)
local R=RS:WaitForChild("Remotes")
local action=R:WaitForChild("ProfileAction")
local state=R:WaitForChild("ProfileState")
local last={}
local function send(p,message)
 local d=Data.get(p);if d then state:FireClient(p,{settings=d.settings,graphics=d.graphics,message=message}) end
end
action.OnServerEvent:Connect(function(p,kind,key,value)
 if typeof(kind)~="string" or (last[p] or 0)+.15>os.clock() then return end;last[p]=os.clock()
 local d=Data.get(p);if not d or Data.inventoryBusy(p) then return end
 if kind=="Set" then
  if key=="volume" and typeof(value)=="number" and value==value then d.settings.volume=math.clamp(value,0,1)
  elseif (key=="vfx" or key=="waypoints" or key=="holdCollect") and typeof(value)=="boolean" then d.settings[key]=value
  elseif key=="graphics" and (value=="auto" or value=="low" or value=="high") then d.graphics=value
  else return end
 elseif kind=="Redeem" then
  if typeof(key)~="string" or #key>30 then return end
  local code=string.upper(key):gsub("%s","")
  if d.codes[code] then send(p,"You already redeemed this code.");return end
  if code=="WELCOME" then d.eggs.LanternEgg=(d.eggs.LanternEgg or 0)+1
  elseif code=="HAUNTED" then d.essence+=100;d.stats.totalEssence+=100
  else send(p,"That code does not exist.");return end
  d.codes[code]=true;SS.HauntedRefresh:Fire(p)
  local refresh=SS:FindFirstChild("GhostRefresh");if refresh then refresh:Fire(p) end
  send(p,"Code redeemed!");return
 elseif kind~="State" then return end
 send(p)
end)
Data.onLoaded(function(p) send(p) end)
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
