local Players=game:GetService("Players")
local CollectionService=game:GetService("CollectionService")
local cooldown={}
local function setup(stone)
	local prompt=stone:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end
	prompt.Triggered:Connect(function(player)
		local character=player.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		local hum=character and character:FindFirstChildOfClass("Humanoid")
		local destination=stone:GetAttribute("Destination")
		if not root or not hum or hum.Health<=0 or typeof(destination)~="Vector3" then return end
		if (root.Position-stone.Position).Magnitude>12 then return end
		local now=os.clock()
		if now-(cooldown[player] or -10)<3 then return end
		cooldown[player]=now
		root.AssemblyLinearVelocity=Vector3.zero
		root.AssemblyAngularVelocity=Vector3.zero
		character:PivotTo(CFrame.new(destination))
	end)
end
for _,stone in ipairs(CollectionService:GetTagged("HighlandTravel")) do setup(stone) end
CollectionService:GetInstanceAddedSignal("HighlandTravel"):Connect(setup)
Players.PlayerRemoving:Connect(function(player) cooldown[player]=nil end)
