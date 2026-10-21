-- Expedition features share the existing profile; all rewards and movement are server-owned.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local CS=game:GetService("CollectionService")
local Data=require(SS.Parent.ServerScriptService.Modules.DataService)
local Config=require(RS.Shared.Config)
local folder=RS:WaitForChild("Remotes")
local action=folder:WaitForChild("ExpeditionAction")
local state=folder:WaitForChild("ExpeditionState")
local sessions={}
local waypoints={
	Home={name="Mansion",position=Vector3.new(0,4.8,40.5)},
	Moonveil={name="Moonveil Memorial",position=Vector3.new(0,12,-338)},
	Briarwatch={name="Briarwatch Heights",position=Vector3.new(-335,70,-408)},
	Starfall={name="Starfall Necropolis",position=Vector3.new(335,112,-408)},
	Crownrest={name="Crownrest Summit",position=Vector3.new(0,170,-733)},
	HollowCaverns={name="Hollow Caverns",position=Vector3.new(0,11,-614)},
}
local lore={
	FirstLantern={title="The First Lantern",text="Morty lit the first lantern to guide lost souls home. Each grave holds a memory; give it time, and its light returns.",reward=60},
	BrokenChapel={title="The Broken Chapel",text="The chapel bell once rang for every released spirit. Its keepers now watch over the memorial gardens.",reward=75},
	MoonveilArchive={title="Moonveil Archive",text="Captain Hale founded Moonveil as a place where hunters could listen before they collected.",reward=100},
	BriarwatchOath={title="The Ranger's Oath",text="Rowan's rangers keep the high trails open. Their green lanterns mean shelter is near.",reward=140},
	StarfallChart={title="The Starfall Chart",text="Lyra charts the drifting lights above these cliffs. They follow the same paths as the stars.",reward=180},
	CrownrestVigil={title="The Summit Vigil",text="Orion keeps the summit watch. The brightest spirits rest where the mountain meets the sky.",reward=220},
	HuntersPromise={title="A Hunter's Promise",text="Take only what your jar can hold. A depleted grave is resting, and patient hunters let its reserve recover.",reward=100},
	EchosSong={title="Echo's Song",text="Echo hears a different note in every soul. Together, their voices turn the silent mountain into a choir.",reward=250},
}
local function profile(player)
	local data=Data.get(player)
	if not data then return end
	data.expedition=data.expedition or {}
	local e=data.expedition
	e.waypoints=e.waypoints or {Home=true};e.waypoints.Home=true
	e.lore=e.lore or {};e.caches=e.caches or {}
	return data,e
end
local function notify(player,text,kind)
	local remotes=RS:FindFirstChild("Remotes")
	local remote=remotes and remotes:FindFirstChild("Notify")
	if remote then remote:FireClient(player,text,kind or "info") end
end
local function refresh(player)
	local bind=SS:FindFirstChild("HauntedRefresh")
	if bind then bind:Fire(player) end
end
local function send(player,open,movementOnly)
	local data,e=profile(player);local s=sessions[player]
	if not data or not s then return end
	if movementOnly then
		state:FireClient(player,{partial=true,stamina=math.floor(s.stamina),sprinting=s.sprinting,speed=(player:GetAttribute("AdminWalkSpeed") or Config.walkSpeed(data.upgrades.SpectralBoots))})
		return
	end
	local discovered={}
	for id,def in pairs(lore) do if e.lore[id] then table.insert(discovered,{id=id,title=def.title,text=def.text}) end end
	table.sort(discovered,function(a,b) return a.title<b.title end)
	state:FireClient(player,{stamina=math.floor(s.stamina),sprinting=s.sprinting,speed=(player:GetAttribute("AdminWalkSpeed") or Config.walkSpeed(data.upgrades.SpectralBoots)),waypoints=e.waypoints,lore=discovered,checkpoint=e.checkpoint or "Home",open=open})
end
local function reward(player,data,amount)
	data.essence+=amount;data.stats.totalEssence+=amount;refresh(player)
end
local function near(player,part)
	local ch=player.Character;local root=ch and ch:FindFirstChild("HumanoidRootPart");local hum=ch and ch:FindFirstChildOfClass("Humanoid")
	return root and hum and hum.Health>0 and (root.Position-part.Position).Magnitude<=14
end
local function travel(player,id)
	local data,e=profile(player);local s=sessions[player]
	local destination=waypoints[id]
	if not data or not s or not destination or not e.waypoints[id] then return end
	local now=os.clock()
	if now-s.travelAt<8 then notify(player,"The waystone is recharging. Wait a moment.");return end
	local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 then return end
	s.travelAt=now;s.sprinting=false;e.checkpoint=id
	root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
	player.Character:PivotTo(CFrame.new(destination.position))
	notify(player,"Travelled to "..destination.name..". Checkpoint set.","good");send(player)
end
local function setupWaypoint(stone)
	local id=stone:GetAttribute("WaypointId")
	if not waypoints[id] then return end
	local prompt=stone:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		if not near(player,stone) then return end
		local data,e=profile(player);if not data then return end
		if not e.waypoints[id] then
			e.waypoints[id]=true
			reward(player,data,100)
			notify(player,waypoints[id].name.." discovered! +100 Essence and fast travel unlocked.","good")
		end
		e.checkpoint=id
		send(player,true)
	end)
end
local function setupLore(stone)
	local id=stone:GetAttribute("LoreId");local entry=lore[id]
	if not entry then return end
	local prompt=stone:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		if not near(player,stone) then return end
		local data,e=profile(player);if not data then return end
		if not e.lore[id] then e.lore[id]=true;reward(player,data,entry.reward);notify(player,entry.title.." discovered! +"..entry.reward.." Essence.","good") end
		send(player,true)
	end)
end
local function setupCache(chest)
	local id=chest:GetAttribute("CacheId");local amount=chest:GetAttribute("CacheReward")
	local prompt=chest:FindFirstChildOfClass("ProximityPrompt")
	if typeof(id)~="string" or typeof(amount)~="number" or not prompt then return end
	prompt.Triggered:Connect(function(player)
		if not near(player,chest) then return end
		local data,e=profile(player);if not data then return end
		local today=math.floor(os.time()/86400)
		if e.caches[id]==today then notify(player,"You collected this field cache today. Come back tomorrow.");return end
		e.caches[id]=today;reward(player,data,amount);notify(player,"Field cache: +"..amount.." Essence!","good")
	end)
end
for tag,setup in pairs({ExpeditionWaypoint=setupWaypoint,ExpeditionLore=setupLore,ExpeditionCache=setupCache}) do
	for _,obj in ipairs(CS:GetTagged(tag)) do setup(obj) end
	CS:GetInstanceAddedSignal(tag):Connect(setup)
end
local function setupPlayer(player)
	if sessions[player] then return end
	sessions[player]={stamina=100,sprinting=false,lastAction=0,travelAt=-20}
	player.CharacterAdded:Connect(function(character)
		local root=character:WaitForChild("HumanoidRootPart",10)
		if not root then return end
		local _,e=profile(player);local destination=e and waypoints[e.checkpoint or "Home"]
		if destination and e.waypoints[e.checkpoint or "Home"] then
			task.wait(.2);if character.Parent then character:PivotTo(CFrame.new(destination.position)) end
		end
		local s=sessions[player];if s then s.stamina=100;s.sprinting=false end
	end)
end
Players.PlayerAdded:Connect(setupPlayer)
for _,p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
Data.onLoaded(function(player)
	setupPlayer(player)
	local _,e=profile(player)
	local character=player.Character
	local destination=e and waypoints[e.checkpoint or "Home"]
	if character and destination and e.waypoints[e.checkpoint or "Home"] then
		local root=character:WaitForChild("HumanoidRootPart",10)
		if root then
			task.wait(.2)
			if character.Parent then character:PivotTo(CFrame.new(destination.position)) end
		end
	end
	send(player)
end)
action.OnServerEvent:Connect(function(player,kind,value)
	local s=sessions[player]
	if not s or (kind~="Sprint" and kind~="Travel" and kind~="State") then return end
	local now=os.clock()
	s.lastActions=s.lastActions or {}
	if now-(s.lastActions[kind] or -1)<.12 and not (kind=="Sprint" and value==false) then return end
	s.lastActions[kind]=now
	if kind=="Sprint" and typeof(value)=="boolean" then
		s.sprinting=value and s.stamina>15
	elseif kind=="Travel" and typeof(value)=="string" then travel(player,value)
	elseif kind=="State" then send(player) end
end)
task.spawn(function()
	local last=os.clock()
	while true do
		task.wait(.25);local now=os.clock();local dt=math.min(now-last,1);last=now
		for _,player in ipairs(Players:GetPlayers()) do
			local data=Data.get(player);local s=sessions[player]
			local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if data and s and hum then
				local root=player.Character:FindFirstChild("HumanoidRootPart")
				local velocity=root and root.AssemblyLinearVelocity or Vector3.zero
				local moving=Vector3.new(velocity.X,0,velocity.Z).Magnitude>1
				if s.sprinting and moving and hum.Health>0 then
					s.stamina=math.max(0,s.stamina-dt*10)
					if s.stamina<=0 then s.sprinting=false end
				else s.stamina=math.min(100,s.stamina+dt*16) end
				local desired=(player:GetAttribute("AdminWalkSpeed") or Config.walkSpeed(data.upgrades.SpectralBoots))+(s.sprinting and 8 or 0)
				if hum.WalkSpeed~=desired then hum.WalkSpeed=desired end
				player:SetAttribute("SprintActive",s.sprinting)
				send(player,false,true)
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
