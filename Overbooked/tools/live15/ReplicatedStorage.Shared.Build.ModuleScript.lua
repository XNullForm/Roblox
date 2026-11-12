-- ReplicatedStorage.Shared.Build: placement rules shared by the client (live ghost tint) and the server (the real check).
-- Zones are flat Parts in Hotel.BuildZones (Lobby, Room101..): an item's whole footprint must sit in one zone.
-- Hotel.BuildZones.NoBuild parts keep walkways, doorways and reception clear.
-- Every player's hotel is a model in workspace.Plots (attribute Origin = its offset along X, plots PLOT_W apart);
-- B.hotelAt(point) finds the hotel a point belongs to, so zone checks work on any plot.
-- Round 9: items can turn freely (any yaw), stand on other furniture or float (pivot Y above the floor,
-- top under the ceiling), hang on walls (Catalog item.wall), and shapes are built from a size, colour and
-- material (B.make). opts = { size = Vector3, color = Color3, mat = "Marble", ghost = true (guests walk through) }.
local Shared = script.Parent
local Catalog = require(Shared:WaitForChild("Catalog"))

local B = {}
B.GRID = 1
B.FY = 1
B.CEIL = 14.6 -- the underside of the ceiling: nothing may poke through it (round 10: walls 14 high)
B.HEAD = 8 -- anything whose bottom is this high above the floor hangs over the walkways
B.YAW_STEP = 15 -- the finest turn build mode allows, in degrees
B.SHAPE_APPEAL, B.SHAPE_APPEAL_MAX = 1, 12 -- each shape adds a little appeal, capped per room

B.PLOT_W = 220
local PLOTS = workspace:WaitForChild("Plots")
local ITEMS = Shared:WaitForChild("Items")

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

-- a shape's real size: clamped, rounded to 0.1, balls round and cylinders circular
function B.shapeSize(itemId, s)
	local it = Catalog.ITEMS[itemId]
	s = typeof(s) == "Vector3" and s or Catalog.SHAPE_DEFAULT
	local function c(v) return math.clamp(math.floor(v * 10 + 0.5) / 10, Catalog.SHAPE_MIN, Catalog.SHAPE_MAX) end
	local x, y, z = c(s.X), c(s.Y), c(s.Z)
	if it and it.shape == "Ball" then y, z = x, x end
	if it and it.shape == "Cylinder" then z = x end
	return Vector3.new(x, y, z)
end

local boxCache = {}

-- footprint of an item in its pivot space: (offset CFrame, size). Shapes pass their size.
function B.box(itemId, size)
	local it = Catalog.ITEMS[itemId]
	if it and it.shape then
		local s = B.shapeSize(itemId, size)
		return CFrame.new(0, s.Y / 2, 0), s
	end
	local c = boxCache[itemId]
	if c then return c[1], c[2] end
	local m = ITEMS:FindFirstChild(itemId)
	if not m then return CFrame.new(), Vector3.one end
	local cf, sz = m:GetBoundingBox()
	local off = m:GetPivot():ToObjectSpace(cf)
	if it and it.structure then
		-- round 14: a wall or door is its wall body (the 4-stud unit), not its casings and cornices, which
		-- lie on the next wall's face. Ends then meet exactly when they snap together.
		local lo, hi
		local piv = m:GetPivot()
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and not p:FindFirstAncestor("Trim") and not p:FindFirstAncestor("Swing") then
				local c = piv:ToObjectSpace(p.CFrame)
				local e = Vector3.new(
					math.abs(c.RightVector.X) * p.Size.X + math.abs(c.UpVector.X) * p.Size.Y + math.abs(c.LookVector.X) * p.Size.Z,
					math.abs(c.RightVector.Y) * p.Size.X + math.abs(c.UpVector.Y) * p.Size.Y + math.abs(c.LookVector.Y) * p.Size.Z,
					math.abs(c.RightVector.Z) * p.Size.X + math.abs(c.UpVector.Z) * p.Size.Y + math.abs(c.LookVector.Z) * p.Size.Z) / 2
				local a, b = c.Position - e, c.Position + e
				lo = lo and lo:Min(a) or a
				hi = hi and hi:Max(b) or b
			end
		end
		if lo then
			off, sz = CFrame.new((lo + hi) / 2), hi - lo
		end
	end
	boxCache[itemId] = { off, sz }
	return off, sz
end

-- the size/colour/material a placed model was made with (shapes only)
function B.optsOf(m)
	return {
		size = m:GetAttribute("Size"),
		color = m:GetAttribute("Color"),
		mat = m:GetAttribute("Mat"),
		ghost = m:GetAttribute("Ghost") or nil,
	}
end

local SHAPE_CLASS = { Block = "Part", Ball = "Part", Cylinder = "Part", Wedge = "WedgePart", CornerWedge = "CornerWedgePart" }

-- a placed-item model at `cf`: a clone of the catalogue template, or a freshly built shape
function B.make(itemId, cf, opts)
	opts = opts or {}
	local it = Catalog.ITEMS[itemId]
	local m
	if it and it.shape then
		local size = B.shapeSize(itemId, opts.size)
		m = Instance.new("Model")
		m.Name = itemId
		local p = Instance.new(SHAPE_CLASS[it.shape] or "Part")
		p.Name = "Shape"
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local rot = CFrame.new()
		if it.shape == "Ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = size
		elseif it.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.X)
			rot = CFrame.Angles(0, 0, math.pi / 2)
		else
			p.Size = size
		end
		local mat = Catalog.MAT_BY_ID[opts.mat or ""] and opts.mat or "SmoothPlastic"
		p.Material = Enum.Material[mat]
		p.Color = typeof(opts.color) == "Color3" and opts.color or Catalog.SWATCHES[1]
		if mat == "Glass" then
			p.Transparency = 0.45
			p.Reflectance = 0.08
		end
		p.CanCollide = not opts.ghost
		p.CFrame = cf * CFrame.new(0, size.Y / 2, 0) * rot
		p.Parent = m
		m.PrimaryPart = p
		m.WorldPivot = cf
		m:SetAttribute("Size", size)
		m:SetAttribute("Color", p.Color)
		m:SetAttribute("Mat", mat)
		if opts.ghost then m:SetAttribute("Ghost", true) end
	else
		m = ITEMS[itemId]:Clone()
		m:PivotTo(cf)
	end
	return m
end

-- yaw of a pivot in degrees (0..360)
function B.yawOf(cf)
	local look = cf.LookVector
	return math.deg(math.atan2(-look.X, -look.Z)) % 360
end

-- a pivot from a floor spot, a height above the floor and a yaw in degrees
function B.pivot(x, y, z, yaw)
	return CFrame.new(x, B.FY + (y or 0), z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

function B.zoneAt(p)
	local hotel = B.hotelAt(p)
	if not hotel then return nil end
	-- a room wins over the lobby (rooms made with walls sit on top of lobby floor)
	local lobby
	for _, z in ipairs(hotel.BuildZones:GetChildren()) do
		if z:IsA("BasePart") then
			local l = z.CFrame:PointToObjectSpace(p)
			if math.abs(l.X) <= z.Size.X / 2 and math.abs(l.Z) <= z.Size.Z / 2 then
				if z.Name ~= "Lobby" then return z end
				lobby = lobby or z
			end
		end
	end
	return lobby
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

-- snap a floor point + quarter turns to an item pivot (the old grid build; still used for the desk)
function B.snap(itemId, point, turns)
	local g = B.GRID
	local x = math.floor(point.X / g + 0.5) * g
	local z = math.floor(point.Z / g + 0.5) * g
	return CFrame.new(x, point.Y, z) * CFrame.Angles(0, math.rad(90 * (turns % 4)), 0)
end

-- what may stand on the floor only (beds, walls, doors, the desk)
function B.floorOnly(itemId)
	local it = Catalog.ITEMS[itemId]
	return it == nil or it.core ~= nil or it.coreKind ~= nil or it.structure == true or itemId == "Desk"
end

-- round 18: the staff room. Before anyone can be hired the hotel needs a proper room for its staff: walls on
-- every side (placed walls or the hotel's own) with Staff Lockers, a Staff Table and something to drink (a
-- Water Cooler or a Coffee Bar) inside. Returns ok, the list of what's still missing, and a short tip.
B.STAFF_ROOM_NEEDS = {
	{ name = "Staff Lockers", tags = { "staffroom" } },
	{ name = "Staff Table", tags = { "staffbreak" } },
	{ name = "Water Cooler or Coffee Bar", ids = { "WaterCooler", "CoffeeBar" } },
}
local function walledIn(hotel, pos, walls)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = walls
	-- shut in on all four sides, and at least two of those sides are walls the player built (so the open
	-- lobby, boxed in only by the hotel's own walls, doesn't count)
	local own = 0
	for _, d in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local hit = workspace:Raycast(pos, d * 40, rp)
		if not hit then return false end
		if hit.Instance:IsDescendantOf(hotel.Placed) then own += 1 end
	end
	local z = B.zoneAt(pos)
	return own >= 2 or (z ~= nil and z.Name ~= "Lobby")
end
function B.staffRoom(hotel)
	local placed = hotel and hotel:FindFirstChild("Placed")
	if not placed then return false, { "a hotel" }, "" end
	local walls = {}
	for _, n in ipairs({ "Shell", "Rooms" }) do
		local f = hotel:FindFirstChild(n)
		if f then table.insert(walls, f) end
	end
	for _, m in ipairs(placed:GetChildren()) do
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		if it and it.structure then table.insert(walls, m) end
	end
	local function find(need)
		local best
		for _, m in ipairs(placed:GetChildren()) do
			local id = m:GetAttribute("Item") or ""
			local it = Catalog.ITEMS[id]
			local hit = false
			if it and need.tags and it.tags then
				for _, t in ipairs(need.tags) do if table.find(it.tags, t) then hit = true end end
			end
			if need.ids and table.find(need.ids, id) then hit = true end
			if hit then
				local p = m:GetPivot().Position + Vector3.new(0, 3, 0)
				if walledIn(hotel, p, walls) then return m, p end
				best = best or m
			end
		end
		return nil, nil, best
	end
	local missing, anchor = {}, nil
	local loose = false
	for _, need in ipairs(B.STAFF_ROOM_NEEDS) do
		local m, p, outside = find(need)
		if m then
			if anchor and (p - anchor).Magnitude > 34 then table.insert(missing, need.name) loose = true end
			anchor = anchor or p
		else
			table.insert(missing, need.name)
			if outside then loose = true end
		end
	end
	local tip = loose and "Everything has to be inside one walled-off room" or "Wall off a small room and furnish it"
	return #missing == 0, missing, tip
end

-- round 14: may a wall/door at `cf` touch the placed wall `other`? In line: only end to end (a little overlap
-- at the joint). At an angle: only where one of them ends (an L or a T), never crossing both middles.
function B.wallJoin(itemId, cf, other)
	local _, sa = B.box(itemId)
	local _, sb = B.box(other:GetAttribute("Item"))
	local ocf = other:GetPivot()
	local ha, hb = sa.X / 2, sb.X / 2
	local ta, tb = sa.Z / 2, sb.Z / 2
	local a, b = cf.RightVector, ocf.RightVector
	local pa, pb = cf.Position, ocf.Position
	local d = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
	local dot = math.abs(a:Dot(b))
	if dot > 0.97 then
		-- parallel: side by side is fine if they don't share the same line; on one line they may only overlap a hair
		local across = math.abs(d:Dot(cf.LookVector))
		if across >= ta + tb - 0.05 then return true end
		local along = math.abs(d:Dot(a))
		if along >= ha + hb - 0.35 then return true end
		return false, "There's already a wall there"
	end
	-- at an angle: where the two centre lines cross, along each wall
	local denom = a.X * b.Z - a.Z * b.X
	if math.abs(denom) < 1e-4 then return true end
	local s = (d.X * b.Z - d.Z * b.X) / denom -- along this wall
	local u = (d.X * a.Z - d.Z * a.X) / denom -- along the other one
	local nearEndA = math.abs(s) >= ha - tb - 0.6
	local nearEndB = math.abs(u) >= hb - ta - 0.6
	if math.abs(s) > ha + tb + 0.2 or math.abs(u) > hb + ta + 0.2 then return true end
	if nearEndA or nearEndB then return true end
	return false, "Walls can't cross through each other"
end

-- ok, reason, zone. `ignore` is the placed model being moved (it doesn't block itself).
function B.validate(itemId, cf, ignore, opts)
	local item = Catalog.ITEMS[itemId]
	if not item then return false, "Unknown item" end
	opts = opts or {}
	local off, size = B.box(itemId, opts.size)
	local bcf = cf * off
	local y0 = cf.Position.Y
	local lift = y0 - B.FY
	if lift < -0.05 then return false, "Keep it above the floor" end
	if lift > 0.05 and B.floorOnly(itemId) then return false, "That stands on the floor" end
	if not item.structure and bcf.Position.Y + size.Y / 2 > B.CEIL + 0.05 then return false, "Too tall for the ceiling" end
	local zone
	-- walls and doors are checked along their centre line, a little in from each end, so one can butt into the
	-- hotel's own walls (whose thickness lies outside the build zones) and close off a room
	local ex = item.structure and math.max(size.X / 2 - 1, 0) or math.max(size.X / 2 - 0.15, 0)
	local ez = item.structure and 0 or math.max(size.Z / 2 - 0.15, 0)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local p = bcf * Vector3.new(sx * ex, 0, sz * ez)
			local z = B.zoneAt(Vector3.new(p.X, y0, p.Z))
			if not z then return false, item.wall and "Hang it on a wall inside" or "Keep it inside the hotel" end
			-- walls and doors are what make rooms, so they may stand on a room's edge
			if zone and z.Name ~= zone.Name and not item.structure then return false, "Keep it inside one room" end
			if not zone or (item.structure and z.Name == "Lobby") then zone = z end
		end
	end
	local hotel = zone.Parent.Parent
	local NOBUILD = hotel.BuildZones.NoBuild
	-- round 10e: the car park out front takes parking spots, and only those
	if zone.Name == "Parking" and not item.outdoor then return false, "That goes inside the hotel" end
	if item.outdoor and zone.Name ~= "Parking" then return false, "Put it in the car park out front" end
	-- a room's bed/shower/toilet belongs in a guest room, never the lobby
	if (item.core or item.coreKind or item.room) and zone.Name == "Lobby" then
		return false, "That belongs in a guest room"
	end
	if (item.core or item.coreKind) and ignore and zone.Name ~= ignore:GetAttribute("Room") then
		return false, "This stays in its own room"
	end
	local lo, hi
	if item.flat then
		lo, hi = y0 + 0.02, y0 + 0.3
	elseif lift > 0.05 then
		-- standing on something: only its own height counts
		lo, hi = y0 + 0.1, y0 + math.max(size.Y - 0.1, 0.2)
	else
		lo, hi = y0 + 0.35, y0 + math.max(size.Y - 0.2, 0.7)
	end
	local overhead = lo - B.FY >= B.HEAD
	local depth = math.max(size.Z - 0.3, 0.2)
	local fwd = 0
	if item.wall then
		-- wall items sit flush: their back may touch the wall
		depth = math.max(size.Z - 0.6, 0.1)
		fwd = 0.15
	end
	local checkCF = CFrame.new(bcf.Position.X, (lo + hi) / 2, bcf.Position.Z) * bcf.Rotation * CFrame.new(0, 0, fwd)
	local checkSize = Vector3.new(math.max(size.X - 0.3, 0.2), hi - lo, depth)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = getBlockers(hotel)
	local wallsSeen = {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(checkCF, checkSize, params)) do
		local owner = B.placedOf(p)
		if owner then
			if owner ~= ignore then
				local other = Catalog.ITEMS[owner:GetAttribute("Item")]
				-- round 14: shapes are free-form decor, but only among themselves (they used to pass through
				-- furniture). Walls and doors join at their ends, never through each other's middles.
				local bothShapes = item.shape and other and other.shape
				local bothWalls = item.structure and other and other.structure
				if bothWalls then
					if not wallsSeen[owner] then
						wallsSeen[owner] = true
						local okJoin, why = B.wallJoin(itemId, cf, owner)
						if not okJoin then return false, why end
					end
				elseif not bothShapes and (other and other.flat or false) == (item.flat or false) then
					return false, "Too close to the " .. string.lower(other and other.name or "furniture")
				end
			end
		elseif p:IsDescendantOf(NOBUILD) then
			-- a door never blocks anyone, so it may sit right in a doorway; nor does anything guests walk under or through.
			-- Walls may cross the hallway (guests walk round them): what has to stay open is the room doors (below)
			local wallInHall = item.structure and p.Name == "Hallway"
			if not item.doorway and not overhead and not opts.ghost and not wallInHall then
				return false, p:GetAttribute("Reason") or "Keep the walkway clear"
			end
		elseif item.structure and (p:IsDescendantOf(hotel.Rooms) or p:IsDescendantOf(hotel.Shell)) then
			-- new walls join the hotel's own walls and the starter rooms' walls
		elseif p:IsDescendantOf(hotel.Rooms) or p:IsDescendantOf(hotel.Shell) or p:IsDescendantOf(hotel.Doors) then
			return false, "Blocked by a wall"
		else
			return false, "Something is in the way"
		end
	end
	-- a wall in the hallway must not shut a room's door: keep a lane open from each doorway across the hallway
	if item.structure and not item.doorway then
		local hall = NOBUILD:FindFirstChild("Hallway")
		for _, d in ipairs(NOBUILD:GetChildren()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Doorway" then
				local reach = hall and (hall.Position.Z + hall.Size.Z / 2 - (d.Position.Z + d.Size.Z / 2)) or 0
				if reach > 0 then
					local laneCF = CFrame.new(d.Position.X, d.Position.Y, d.Position.Z + d.Size.Z / 2 + reach / 2)
					local laneSize = Vector3.new(d.Size.X - 1, d.Size.Y, reach)
					-- the wall's ends and middle against the lane (walls are 4 studs, the lane wider)
					local inside = false
					for _, cx in ipairs({ -1, 0, 1 }) do
						local wp = checkCF * Vector3.new(cx * checkSize.X / 2, 0, 0)
						local lp = laneCF:PointToObjectSpace(wp)
						if math.abs(lp.X) < laneSize.X / 2 and math.abs(lp.Z) < laneSize.Z / 2 then inside = true end
					end
					if inside then return false, "Keep the way into the room clear" end
				end
			end
		end
	end
	return true, nil, zone
end

-- appeal of every non-core item standing in a zone of a hotel (shapes add a little each, capped)
function B.appeal(zoneName, hotel)
	local a, shapes = 0, 0
	for _, m in ipairs(hotel.Placed:GetChildren()) do
		if m:GetAttribute("Zone") == zoneName then
			local it = Catalog.ITEMS[m:GetAttribute("Item")]
			if it and it.shape then
				shapes += B.SHAPE_APPEAL
			elseif it and it.appeal then
				a += it.appeal
			end
		end
	end
	return a + math.min(shapes, B.SHAPE_APPEAL_MAX)
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
	spot("Receptionist", CFrame.new(0, 3, -2.4), CFrame.new(0, 3, 5))
end

-- round 10b: one receptionist per desk (the lobby desk plus every Desk bought in build mode)
function B.desks(hotel)
	local list = {}
	local lobby = hotel:FindFirstChild("Lobby")
	if lobby and lobby:FindFirstChild("Desk") then table.insert(list, lobby.Desk) end
	local placed = hotel:FindFirstChild("Placed")
	if placed then
		for _, m in ipairs(placed:GetChildren()) do
			if m:GetAttribute("Item") == "Desk" then table.insert(list, m) end
		end
	end
	return list
end

return B
