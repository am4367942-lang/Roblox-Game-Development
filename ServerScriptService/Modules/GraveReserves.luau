-- Server-owned, gradually replenishing soul reserves shared by all collectors.
local CollectionService = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Reserves = {}
local states = {}
local started = false
local function render(spot, s)
	local ratio = s.amount / s.capacity
	local ghost = spot:FindFirstChild("ReserveGhost")
	if ghost then
		for _,piece in ipairs(ghost:GetChildren()) do
			if piece:IsA("BasePart") then
				local base=piece:GetAttribute("FullTransparency") or 0
				piece.Transparency=base+(1-base)*(1-ratio)*0.95
			end
		end
	end
	spot:SetAttribute("SoulReserve", math.floor(s.amount))
	spot:SetAttribute("SoulCapacity", s.capacity)
	spot:SetAttribute("RechargePerSecond", s.rate)
	spot:SetAttribute("ReadyAt", nil)
	local wisp = spot:FindFirstChild("GraveWisp")
	if wisp and wisp:IsA("ParticleEmitter") then
		wisp.Enabled = s.amount >= 1
		wisp.Rate = 1 + ratio * 5
		wisp.LightEmission = 0.3 + ratio * 0.7
	end
	local rune = spot.Parent and spot.Parent:FindFirstChild("SoulRune")
	if rune and rune:IsA("BasePart") then rune.Transparency = 0.08 + (1-ratio)*0.85 end
	local light = spot:FindFirstChild("ReserveLight")
	if light then light.Brightness = ratio * 0.7 end
	local gui = spot:FindFirstChild("SoulReserveDisplay")
	if gui then
		gui.Panel.Amount.Text = ("%s · %d/%d%s"):format(spot:GetAttribute("SoulType") or "Souls",math.floor(s.amount), s.capacity,(spot:GetAttribute("Mutation") and spot:GetAttribute("Mutation")~="Pure") and (" · "..spot:GetAttribute("Mutation")) or "")
		gui.Panel.Track.Fill.Size = UDim2.fromScale(ratio, 1)
		gui.Panel.Amount.TextColor3 = ratio < 0.1 and Color3.fromRGB(180,170,195) or Color3.fromRGB(186,255,230)
	end
end
local function register(spot)
	if states[spot] or not spot:IsA("BasePart") or not spot:IsDescendantOf(workspace) then return end
	local tier = Config.GraveTiers[spot:GetAttribute("Zone")]
	if tier then
		spot:SetAttribute("SoulCapacity",tier.capacity)
		spot:SetAttribute("Reward",tier.reward)
		spot:SetAttribute("RechargePerSecond",tier.capacity/tier.refillSeconds)
	end
	local cap = math.max(1, spot:GetAttribute("SoulCapacity") or (spot:GetAttribute("Reward") or 5) * 8)
	local s = {capacity=cap, amount=cap, rate=math.max(0.05, spot:GetAttribute("RechargePerSecond") or cap/90), time=os.clock()}
	states[spot] = s
	if not spot:FindFirstChild("SoulReserveDisplay") then
		local gui = Instance.new("BillboardGui")
		gui.Name="SoulReserveDisplay";gui.Size=UDim2.fromOffset(280,48);gui.StudsOffset=Vector3.new(0,3,0)
		gui.MaxDistance=24;gui.AlwaysOnTop=false;gui.Parent=spot
		local panel=Instance.new("Frame");panel.Name="Panel";panel.Size=UDim2.fromScale(1,1);panel.BackgroundColor3=Color3.fromRGB(19,24,36);panel.BackgroundTransparency=.15;panel.BorderSizePixel=0;panel.Parent=gui
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,8);corner.Parent=panel
		local amount=Instance.new("TextLabel");amount.Name="Amount";amount.BackgroundTransparency=1;amount.Size=UDim2.new(1,-8,0,32);amount.Position=UDim2.fromOffset(4,0);amount.Font=Enum.Font.GothamMedium;amount.TextSize=11;amount.Parent=panel
		local track=Instance.new("Frame");track.Name="Track";track.Position=UDim2.new(0,9,0,37);track.Size=UDim2.new(1,-18,0,4);track.BackgroundColor3=Color3.fromRGB(56,57,73);track.BorderSizePixel=0;track.Parent=panel
		local fill=Instance.new("Frame");fill.Name="Fill";fill.BackgroundColor3=Color3.fromRGB(117,240,211);fill.BorderSizePixel=0;fill.Parent=track
	end
	render(spot,s)
end
local function update(spot)
	register(spot)
	local s=states[spot]
	if not s then return nil end
	local now=os.clock()
 local multiplier=1;local folder=game.ReplicatedStorage:FindFirstChild("GraveyardBoosts");local boost=folder and folder:FindFirstChild(spot:GetAttribute("Zone") or "Graveyard")
 if boost and (boost:GetAttribute("EndsAt") or 0)>os.time() then multiplier=boost:GetAttribute("Multiplier") or 1 end
 s.amount=math.min(s.capacity,s.amount+math.max(0,now-s.time)*s.rate*multiplier)
	s.time=now
	return s
end
function Reserves.take(spot, requested)
	local s=update(spot)
	if not s then return 0 end
	local amount=math.min(math.max(0,math.floor(requested)),math.floor(s.amount))
	s.amount-=amount
	render(spot,s)
	return amount
end
function Reserves.available(spot)
	local s=update(spot)
	return s and math.floor(s.amount) or 0
end
function Reserves.start()
	if started then return end
	started=true
	for _,spot in ipairs(CollectionService:GetTagged("DigSpot")) do register(spot) end
	CollectionService:GetInstanceAddedSignal("DigSpot"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("DigSpot"):Connect(function(spot) states[spot]=nil end)
	task.spawn(function()
		while true do
			task.wait(1)
			local count=0
			for spot in pairs(states) do
				if spot:IsDescendantOf(workspace) then
					local s=update(spot);render(spot,s)
				else states[spot]=nil end
				count+=1
				if count%80==0 then task.wait() end
			end
		end
	end)
end
return Reserves
