-- ReplicatedStorage.RAH.Build: placement rules shared by the client (live ghost tint) and the server (the real check).
-- Zones are flat Parts in Hotel.BuildZones (Lobby, Room101..): an item's whole footprint must sit in one zone.
-- Hotel.BuildZones.NoBuild parts keep walkways, doorways and reception clear.
-- Every player's hotel is a model in workspace.Plots (attribute Origin = its offset along X, plots PLOT_W apart);
-- B.hotelAt(point) finds the hotel a point belongs to, so zone checks work on any plot.
local RAH = script.Parent
local Catalog = require(RAH:WaitForChild("Catalog"))

local B = {}
B.GRID = 1
B.FY = 1

B.PLOT_W = 220
local PLOTS = workspace:WaitForChild("Plots")
local ITEMS = RAH:WaitForChild("Items")

-- the hotel whose plot holds this point (nil between plots or on an empty plot)
function B.hotelAt(p)
	for _, h in ipairs(PLOTS:GetChildren()) do
		local o = h:GetAttribute("Origin")
		if o and math.abs(p.X - o.X) < B.PLOT_W / 2 then
			return h:FindFirstChild("BuildZones") and h or nil
		end
	end
	return nil
end

local boxCache = {}

-- footprint of an item in its pivot space: (offset CFrame, size)
function B.box(itemId)
	local c = boxCache[itemId]
	if c then return c[1], c[2] end
	local m = ITEMS:FindFirstChild(itemId)
	if not m then return CFrame.new(), Vector3.one end
	local cf, size = m:GetBoundingBox()
	local off = m:GetPivot():ToObjectSpace(cf)
	boxCache[itemId] = { off, size }
	return off, size
end

function B.zoneAt(p)
	local hotel = B.hotelAt(p)
	if not hotel then return nil end
	for _, z in ipairs(hotel.BuildZones:GetChildren()) do
		if z:IsA("BasePart") then
			local l = z.CFrame:PointToObjectSpace(p)
			if math.abs(l.X) <= z.Size.X / 2 and math.abs(l.Z) <= z.Size.Z / 2 then
				return z
			end
		end
	end
	return nil
end

function B.placedOf(part)
	local m = part
	while m and m.Parent and m.Parent.Name ~= "Placed" do
		m = m.Parent
		if m == workspace then return nil end
	end
	return (m and m.Parent and m.Parent.Name == "Placed") and m or nil
end

local function getBlockers(hotel)
	local blockers = {}
	for _, n in ipairs({ "Shell", "Rooms", "Lobby", "Doors", "Placed" }) do
		local f = hotel:FindFirstChild(n)
		if f then table.insert(blockers, f) end
	end
	table.insert(blockers, hotel.BuildZones.NoBuild)
	return blockers
end

-- snap a floor point + quarter turns to an item pivot
function B.snap(itemId, point, turns)
	local g = B.GRID
	local x = math.floor(point.X / g + 0.5) * g
	local z = math.floor(point.Z / g + 0.5) * g
	return CFrame.new(x, point.Y, z) * CFrame.Angles(0, math.rad(90 * (turns % 4)), 0)
end

-- ok, reason, zone. `ignore` is the placed model being moved (it doesn't block itself).
function B.validate(itemId, cf, ignore)
	local item = Catalog.ITEMS[itemId]
	if not item then return false, "Unknown item" end
	local off, size = B.box(itemId)
	local bcf = cf * off
	local zone
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local p = bcf * Vector3.new(sx * math.max(size.X / 2 - 0.15, 0), 0, sz * math.max(size.Z / 2 - 0.15, 0))
			local z = B.zoneAt(Vector3.new(p.X, cf.Position.Y, p.Z))
			if not z then return false, "Keep it inside the hotel" end
			if zone and z ~= zone then return false, "Keep it inside one room" end
			zone = z
		end
	end
	local hotel = zone.Parent.Parent
	local NOBUILD = hotel.BuildZones.NoBuild
	-- a room's bed/shower/toilet belongs in a guest room, never the lobby
	if (item.core or item.coreKind) and zone.Name == "Lobby" then
		return false, "That belongs in a guest room"
	end
	if (item.core or item.coreKind) and ignore and zone.Name ~= ignore:GetAttribute("Room") then
		return false, "This stays in its own room"
	end
	local y0 = cf.Position.Y
	local lo, hi
	if item.flat then
		lo, hi = y0 + 0.02, y0 + 0.3
	else
		lo, hi = y0 + 0.35, y0 + math.max(size.Y - 0.2, 0.7)
	end
	local checkCF = CFrame.new(bcf.Position.X, (lo + hi) / 2, bcf.Position.Z) * bcf.Rotation
	local checkSize = Vector3.new(math.max(size.X - 0.3, 0.2), hi - lo, math.max(size.Z - 0.3, 0.2))
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = getBlockers(hotel)
	for _, p in ipairs(workspace:GetPartBoundsInBox(checkCF, checkSize, params)) do
		local owner = B.placedOf(p)
		if owner then
			if owner ~= ignore then
				local other = Catalog.ITEMS[owner:GetAttribute("Item")]
				if (other and other.flat or false) == (item.flat or false) then
					return false, "Too close to the " .. string.lower(other and other.name or "furniture")
				end
			end
		elseif p:IsDescendantOf(NOBUILD) then
			-- a door never blocks anyone, so it may sit right in a doorway
			if not item.doorway then
				return false, p:GetAttribute("Reason") or "Keep the walkway clear"
			end
		elseif p:IsDescendantOf(hotel.Rooms) or p:IsDescendantOf(hotel.Shell) or p:IsDescendantOf(hotel.Doors) then
			return false, "Blocked by a wall"
		else
			return false, "Something is in the way"
		end
	end
	return true, nil, zone
end

-- appeal of every non-core item standing in a zone of a hotel
function B.appeal(zoneName, hotel)
	local a = 0
	for _, m in ipairs(hotel.Placed:GetChildren()) do
		if m:GetAttribute("Zone") == zoneName then
			local it = Catalog.ITEMS[m:GetAttribute("Item")]
			if it and it.appeal then a += it.appeal end
		end
	end
	return a
end

-- the reception desk roams its reception zone (the NoBuild part keeps furniture out of its way)
function B.deskOk(hotel, cf)
	local rec = hotel.BuildZones.NoBuild:FindFirstChild("Reception")
	if not rec then return false, "No reception area" end
	local off, size = B.box("Desk")
	local bcf = cf * off
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local p = bcf * Vector3.new(sx * size.X / 2, 0, sz * size.Z / 2)
			local l = rec.CFrame:PointToObjectSpace(p)
			if math.abs(l.X) > rec.Size.X / 2 or math.abs(l.Z) > rec.Size.Z / 2 then
				return false, "Keep the desk in its reception area"
			end
		end
	end
	return true
end

-- move the desk and everything tied to it: the check-in line, the check-out line and the receptionist's post
function B.moveDesk(hotel, cf)
	local lobby = hotel:FindFirstChild("Lobby")
	local desk = lobby and lobby:FindFirstChild("Desk")
	if desk then desk:PivotTo(cf) end
	local nav = hotel:FindFirstChild("Nav")
	if not nav then return end
	local function spot(name, off, lookOff)
		local s = nav:FindFirstChild(name)
		if s and s:IsA("BasePart") then
			s.CFrame = cf * off
			s:SetAttribute("Look", (cf * lookOff).Position)
		end
	end
	spot("DeskGuest", CFrame.new(0, 3, 3.4), CFrame.new(0, 3, 0))
	spot("DeskGuest2", CFrame.new(3, 3, 3.6), CFrame.new(0, 3, 0))
	spot("Receptionist", CFrame.new(0, 3, -3.2), CFrame.new(0, 3, 5))
end

return B
