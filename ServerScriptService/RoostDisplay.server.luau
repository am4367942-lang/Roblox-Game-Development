-- Owner-only Spirit Roost display management. Every request is validated on the
-- server: a player can only ever change the roost whose OwnerUserId == their UserId.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local Data = require(script.Parent.Modules.DataService)
local Layout = require(script.Parent.Modules.RoostLayout)
local remotes = RS:WaitForChild("Remotes")
local remote = remotes:FindFirstChild("RoostDisplayAction") or Instance.new("RemoteEvent")
remote.Name = "RoostDisplayAction"
remote.Parent = remotes
local roosts = workspace:WaitForChild("SpiritRoosts")
local last = {}

local function ownRoost(p)
	for _, r in ipairs(roosts:GetChildren()) do
		if r:IsA("Model") and r:GetAttribute("OwnerUserId") == p.UserId then return r end
	end
	return nil
end
local function notify(p, text, kind)
	local n = remotes:FindFirstChild("Notify")
	if n then n:FireClient(p, text, kind or "info") end
end
local function validCell(n)
	return typeof(n) == "number" and n == n and n % 1 == 0 and n >= 1 and n <= Layout.CELLS
end
local function owns(d, uid)
	if typeof(uid) ~= "string" then return false end
	for _, pet in ipairs(d.pets.inventory) do
		if pet.uid == uid then return true end
	end
	return false
end

local function handle(p, op, a, b)
	if typeof(op) ~= "string" then return false, "bad request" end
	local now = os.clock()
	if now - (last[p] or 0) < 0.15 then return false, "slow down" end
	last[p] = now
	local d = Data.get(p)
	if not d or Data.inventoryBusy(p) then return false, "busy" end
	if not ownRoost(p) then return false, "no roost" end
	local layout = Layout.ensure(d)
	if op == "Place" then
		if not validCell(a) or not owns(d, b) then return false, "invalid" end
		local from = Layout.cellOf(d, b)
		if from then layout[tostring(from)] = layout[tostring(a)] end
		layout[tostring(a)] = b
	elseif op == "Remove" then
		if not validCell(a) then return false, "invalid" end
		layout[tostring(a)] = nil
	elseif op == "Move" then
		if not validCell(a) or not validCell(b) or a == b then return false, "invalid" end
		local ka, kb = tostring(a), tostring(b)
		layout[ka], layout[kb] = layout[kb], layout[ka]
	elseif op == "AutoFill" then
		for _, pet in ipairs(d.pets.inventory) do
			if not Layout.cellOf(d, pet.uid) then
				for i = 1, Layout.CELLS do
					if not layout[tostring(i)] then layout[tostring(i)] = pet.uid; break end
				end
			end
		end
	elseif op == "Clear" then
		for i = 1, Layout.CELLS do layout[tostring(i)] = nil end
	else
		return false, "unknown"
	end
	Layout.ensure(d)
	Layout.render(p)
	return true
end

remote.OnServerEvent:Connect(function(p, op, a, b)
	local ok, why = handle(p, op, a, b)
	if not ok and why == "no roost" then notify(p, "You can only arrange ghosts in your own Spirit Roost.", "warn") end
end)

-- Studio QA hook (server-only, not reachable by clients)
local hook = SS:FindFirstChild("RoostDisplayTest") or Instance.new("BindableFunction")
hook.Name = "RoostDisplayTest"
hook.Parent = SS
hook.OnInvoke = function(p, op, a, b)
	last[p] = 0
	return handle(p, op, a, b)
end

-- when an owner leaves, wipe their ghosts from the roost so the next owner starts clean
local KEYS = { "SpiritKind", "GhostUid", "GhostName", "GhostLevel", "GhostRarity", "GhostEquipped" }
local function clear(roost)
	local cells = roost:FindFirstChild("SpiritCells")
	if not cells then return end
	for i = 1, Layout.CELLS do
		local cell = cells:FindFirstChild("Cell" .. i)
		if cell then
			for _, k in ipairs(KEYS) do cell:SetAttribute(k, nil) end
			local tile = cell:FindFirstChild("Tile")
			local g = tile and tile:FindFirstChild("Label")
			local t = g and g:FindFirstChild("Text")
			if t then t.Text = "SPIRIT SLOT " .. i; t.TextColor3 = Color3.fromRGB(147, 142, 167) end
		end
	end
end
local function watch(roost)
	if not roost:IsA("Model") then return end
	roost:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		local id = roost:GetAttribute("OwnerUserId") or 0
		if id == 0 then
			clear(roost)
		else
			local p = Players:GetPlayerByUserId(id)
			if p then task.defer(Layout.render, p) end
		end
	end)
end
for _, r in ipairs(roosts:GetChildren()) do watch(r) end
roosts.ChildAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
