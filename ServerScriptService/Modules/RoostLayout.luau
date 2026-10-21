-- Saved per-player roost display: data.roostLayout["1".."30"] = ghost uid.
local Layout = {}
Layout.CELLS = 30
local renderer
function Layout.setRenderer(fn) renderer = fn end
function Layout.render(p) if renderer then renderer(p) end end

local function inventory(d)
	local byUid = {}
	for _, pet in ipairs(d.pets and d.pets.inventory or {}) do byUid[pet.uid] = pet end
	return byUid
end

-- the layout exists, holds only owned ghosts, and has no duplicates
function Layout.ensure(d)
	d.pets = d.pets or { inventory = {}, equipped = {} }
	d.pets.inventory = d.pets.inventory or {}
	local byUid = inventory(d)
	if type(d.roostLayout) ~= "table" then
		d.roostLayout = {}
		for i, pet in ipairs(d.pets.inventory) do
			if i <= Layout.CELLS then d.roostLayout[tostring(i)] = pet.uid end
		end
	end
	for key in pairs(d.roostLayout) do
		local n = tonumber(key)
		if not n or n < 1 or n > Layout.CELLS or n % 1 ~= 0 or tostring(n) ~= key then d.roostLayout[key] = nil end
	end
	local seen = {}
	for i = 1, Layout.CELLS do
		local key = tostring(i)
		local uid = d.roostLayout[key]
		if uid ~= nil then
			if not byUid[uid] or seen[uid] then d.roostLayout[key] = nil else seen[uid] = true end
		end
	end
	return d.roostLayout
end

function Layout.petAt(d, i)
	local uid = Layout.ensure(d)[tostring(i)]
	if not uid then return nil end
	for _, pet in ipairs(d.pets.inventory) do
		if pet.uid == uid then return pet end
	end
	return nil
end

function Layout.cellOf(d, uid)
	for key, v in pairs(Layout.ensure(d)) do
		if v == uid then return tonumber(key) end
	end
	return nil
end

return Layout
