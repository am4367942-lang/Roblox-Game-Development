-- Assign each server player one of the seven Spirit Roosts.
-- Roost ownership is session-based; player progress remains in DataService.
local Players = game:GetService("Players")
local plotsFolder = workspace:WaitForChild("SpiritRoosts")

local roosts={} for _,r in ipairs(plotsFolder:GetChildren()) do if r:IsA("Model") and r:GetAttribute("Slot") then table.insert(roosts,r) end end
table.sort(roosts, function(a, b)
	return (a:GetAttribute("Slot") or 0) < (b:GetAttribute("Slot") or 0)
end)

local ownerByPlayer = {}
local playerBySlot = {}

local function refreshSign(roost, player)
	local slot = roost:GetAttribute("Slot") or 0
	local sign = roost:FindFirstChild("OwnerSign", true)
	local label = sign and sign:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		if player then
			label.Text = ("SPIRIT ROOST %02d\n%s's haunt"):format(slot, player.DisplayName)
		else
			label.Text = ("SPIRIT ROOST %02d\nOPEN - A ghost's home"):format(slot)
		end
	end
	roost:SetAttribute("OwnerUserId", player and player.UserId or 0)
	roost:SetAttribute("OwnerName", player and player.Name or "")
end

local function claim(player)
	if ownerByPlayer[player] then return end
	for _, roost in ipairs(roosts) do
		local slot = roost:GetAttribute("Slot")
		if slot and not playerBySlot[slot] then
			ownerByPlayer[player] = roost
			playerBySlot[slot] = player
			player:SetAttribute("SpiritRoost", slot)
			local beacon=roost:FindFirstChild("SoulBeacon",true) or roost.PrimaryPart
			player:SetAttribute("SpiritRoostPosition",beacon and beacon.Position or roost:GetPivot().Position)
			refreshSign(roost, player)
			return
		end
	end
	-- Overflow plots preserve a unique home even when server capacity exceeds seven.
 local template=game.ServerStorage:FindFirstChild("SpiritRoostTemplate")
 if template then
  local slot=#roosts+1;local roost=template:Clone();roost.Name=string.format("SpiritRoost%02d",slot);roost:SetAttribute("Slot",slot)
  local col=(slot-1)%7;local row=math.floor((slot-1)/7)
  roost:PivotTo(CFrame.new((col-3)*28.8,.72,133.2+row*32));roost.Parent=plotsFolder;local pad=roost:FindFirstChild("RoostConvertPad",true);if pad then game:GetService("CollectionService"):AddTag(pad,"ConvertPad") end;table.insert(roosts,roost)
  local path=Instance.new("Part");path.Name="OverflowRoostWalk";path.Anchored=true;path.Material=Enum.Material.Cobblestone;path.Color=Color3.fromRGB(92,95,112);path.Size=Vector3.new(26.4,1.2,12);path.Position=Vector3.new((col-3)*28.8,.72,117.2+row*32);path.Parent=plotsFolder
  claim(player)
 end
end

local function release(player)
	local roost = ownerByPlayer[player]
	if roost then
		playerBySlot[roost:GetAttribute("Slot")] = nil
		ownerByPlayer[player] = nil
		refreshSign(roost, nil)
		player:SetAttribute("SpiritRoostPosition",nil)
		for _,waiting in ipairs(Players:GetPlayers()) do if waiting~=player and not ownerByPlayer[waiting] then claim(waiting) end end
	end
end

Players.PlayerAdded:Connect(claim)
Players.PlayerRemoving:Connect(release)
for _, player in ipairs(Players:GetPlayers()) do
	claim(player)
end
