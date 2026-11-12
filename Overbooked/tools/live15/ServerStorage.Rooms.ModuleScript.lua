-- ServerStorage.Rooms (round 10d): guest rooms the player makes with Wall and Door items.
-- Rooms.scan(hotel, hints?) looks at the hotel floor on a 1-stud grid:
--   1. Cells are blocked by Wall and Door items, by the shell's tall walls and by the built-in rooms.
--   2. A flood fill from the entrance marks the lobby. Every other open patch is a room candidate.
--   3. A candidate becomes a room when it is big enough (MIN_AREA, MIN_SIDE), roughly a rectangle (FILL)
--      and has a Door item with the lobby on one side and the patch on the other.
-- New rooms get ids from 201 up (hints = { [sig] = id } from the save keeps their old numbers) and are built
-- by HotelBuilder.customRoom, then RoomAdded fires. A room whose walls are gone is removed (RoomRemoved fires
-- first) once nobody is staying in it; until then the hotel carries RoomsPending and the sim scans again.
-- Furniture inside a room joins it (Zone; bed/shower/toilet become its core items); on removal it goes back
-- to the lobby. Fires ItemsChanged only when something changed. Returns the list of new room ids.
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local Builder = require(SS:WaitForChild("HotelBuilder"))
local Catalog = require(RS:WaitForChild("Shared"):WaitForChild("Catalog"))
local Build = require(RS.Shared:WaitForChild("Build"))

local SIG = SS:WaitForChild("Signals")
local RoomAdded = SIG:WaitForChild("RoomAdded")
local ItemsChanged = SIG:WaitForChild("ItemsChanged")
local RoomRemoved = SIG:FindFirstChild("RoomRemoved")
if not RoomRemoved then
	RoomRemoved = Instance.new("BindableEvent")
	RoomRemoved.Name = "RoomRemoved"
	RoomRemoved.Parent = SIG
end

local Rooms = {}
Rooms.FIRST_ID = 201
local MIN_AREA, MIN_SIDE, MAX_AREA, FILL = 40, 5, 1600, 0.8
local Z0, Z1 = -29.5, 29.6
local WALL_X, WALL_Z = 2.3, 0.85 -- a wall item blocks cells this close to its centre line (closes small gaps)
local SEED = Vector2.new(0, 20) -- in the lobby, between the entrance and reception
local FREE_STATES = { Ready = true, Unfurnished = true }

local function aabb(p, O)
	local cf, s = p.CFrame, p.Size / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z
	local hy = math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z
	local hz = math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	local c = cf.Position - O
	return c, hx, hy, hz
end

function Rooms.scan(hotel, hints)
	if not (hotel and hotel.Parent and hotel:FindFirstChild("Placed") and hotel:FindFirstChild("BuildZones")) then return {} end
	local O = hotel:GetAttribute("Origin") or Vector3.zero
	local FY = Build.FY
	local minX = math.floor(hotel:GetAttribute("MinX") or -39.5)
	local maxX = math.ceil(hotel:GetAttribute("MaxX") or 39.5)
	local nx, nz = maxX - minX, math.ceil(Z1 - Z0)
	local N = nx * nz
	local blocked = table.create(N, false)
	local function cellOf(x, z)
		local i, j = math.floor(x - minX) + 1, math.floor(z - Z0) + 1
		if i < 1 or j < 1 or i > nx or j > nz then return nil end
		return (j - 1) * nx + i
	end
	-- every cell whose centre lies inside [x0, x1] x [z0, z1]
	local function box(x0, x1, z0, z1)
		for j = math.max(1, math.ceil(z0 - Z0 + 0.5)), math.min(nz, math.floor(z1 - Z0 + 0.5)) do
			local row = (j - 1) * nx
			for i = math.max(1, math.ceil(x0 - minX + 0.5)), math.min(nx, math.floor(x1 - minX + 0.5)) do
				blocked[row + i] = true
			end
		end
	end
	-- 1a. the built-in rooms (101-107) are never part of the lobby or a new room
	for _, z in ipairs(hotel.BuildZones:GetChildren()) do
		if z:IsA("BasePart") and string.sub(z.Name, 1, 4) == "Room" and not z:GetAttribute("Custom") then
			local c, hx, _, hz = aabb(z, O)
			box(c.X - hx, c.X + hx, c.Z - hz, c.Z + hz)
		end
	end
	-- 1b. the shell's walls: tall, solid and thin (or small, like a column)
	for _, p in ipairs(hotel.Shell:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			local c, hx, hy, hz = aabb(p, O)
			if c.Y - hy <= FY + 2 and c.Y + hy >= FY + 7 and (math.min(hx, hz) <= 1.6 or hx * hz <= 9) then
				box(c.X - hx - 0.3, c.X + hx + 0.3, c.Z - hz - 0.3, c.Z + hz + 0.3)
			end
		end
	end
	-- 1c. walls and doors
	local doors = {}
	local doorCell = {}
	for _, m in ipairs(hotel.Placed:GetChildren()) do
		-- round 10e: every wall style counts as a Wall, every door style as a Door (Catalog wallKind)
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		local id = it and it.wallKind
		if id == "Wall" or id == "Door" then
			local cf = m:GetPivot()
			local pc = cf.Position - O
			local rel = CFrame.new(pc) * cf.Rotation
			for j = math.max(1, math.floor(pc.Z - Z0 - 3)), math.min(nz, math.ceil(pc.Z - Z0 + 3)) do
				for i = math.max(1, math.floor(pc.X - minX - 3)), math.min(nx, math.ceil(pc.X - minX + 3)) do
					local l = rel:PointToObjectSpace(Vector3.new(minX + i - 0.5, pc.Y, Z0 + j - 0.5))
					if math.abs(l.X) <= WALL_X and math.abs(l.Z) <= WALL_Z then
						local k = (j - 1) * nx + i
						blocked[k] = true
						if id == "Door" then doorCell[k] = m end
					end
				end
			end
			if id == "Door" then table.insert(doors, { m = m, rel = rel }) end
		end
	end
	-- 2. flood fill the open cells into patches
	local comp = table.create(N, 0)
	local info = {}
	local queue = table.create(N)
	local nc = 0
	for start = 1, N do
		if not blocked[start] and comp[start] == 0 then
			nc += 1
			local c = { n = 0, i0 = math.huge, i1 = -math.huge, j0 = math.huge, j1 = -math.huge }
			info[nc] = c
			comp[start] = nc
			local head, tail = 1, 1
			queue[1] = start
			while head <= tail do
				local k = queue[head]
				head += 1
				local i, j = (k - 1) % nx + 1, (k - 1) // nx + 1
				c.n += 1
				if i < c.i0 then c.i0 = i end
				if i > c.i1 then c.i1 = i end
				if j < c.j0 then c.j0 = j end
				if j > c.j1 then c.j1 = j end
				local function try(k2)
					if not blocked[k2] and comp[k2] == 0 then
						comp[k2] = nc
						tail += 1
						queue[tail] = k2
					end
				end
				if i > 1 then try(k - 1) end
				if i < nx then try(k + 1) end
				if j > 1 then try(k - nx) end
				if j < nz then try(k + nx) end
			end
		end
	end
	local seed = cellOf(SEED.X, SEED.Y)
	local lobby = seed and comp[seed] or 0
	-- 3. doors that join the lobby to a patch
	for _, d in ipairs(doors) do
		local a = d.rel * Vector3.new(0, 0, 1.8)
		local b = d.rel * Vector3.new(0, 0, -1.8)
		local ka, kb = cellOf(a.X, a.Z), cellOf(b.X, b.Z)
		local ca, cb = ka and comp[ka] or 0, kb and comp[kb] or 0
		local roomSide, n
		if ca == lobby and cb ~= lobby and cb > 0 then
			roomSide, n = cb, (b - a).Unit
		elseif cb == lobby and ca ~= lobby and ca > 0 then
			roomSide, n = ca, (a - b).Unit
		end
		if roomSide and lobby > 0 then
			local c = info[roomSide]
			-- the door nearest the patch's lower corner wins, so the choice doesn't depend on Placed order
			local key = d.rel.Position.X * 1000 + d.rel.Position.Z
			if not c.door or key < c.doorKey then
				c.door, c.doorKey, c.dcf, c.nrm = d.m, key, d.rel, Vector3.new(n.X, 0, n.Z).Unit
			end
		end
	end
	local want = {}
	for ci, c in ipairs(info) do
		if ci ~= lobby and c.door then
			local w, h = c.i1 - c.i0 + 1, c.j1 - c.j0 + 1
			if c.n >= MIN_AREA and c.n <= MAX_AREA and w >= MIN_SIDE and h >= MIN_SIDE and c.n / (w * h) >= FILL then
				c.x0, c.x1 = minX + c.i0 - 1, minX + c.i1
				c.z0, c.z1 = Z0 + c.j0 - 1, Z0 + c.j1
				c.sig = string.format("%d:%d:%d:%d:%d", c.x0, c.x1, math.floor(c.z0 * 2), math.floor(c.z1 * 2), c.n)
				table.insert(want, c)
			end
		end
	end
	table.sort(want, function(a, b) return a.x0 < b.x0 or (a.x0 == b.x0 and a.z0 < b.z0) end)

	-- 4. match with the rooms already made
	local changed = false
	local bySig = {}
	local taken = {}
	for _, m in ipairs(hotel.Rooms:GetChildren()) do
		taken[m:GetAttribute("RoomId") or 0] = true
		if m:GetAttribute("Custom") then bySig[m:GetAttribute("Sig") or ""] = m end
	end
	local keep = {}
	for _, c in ipairs(want) do
		local m = bySig[c.sig]
		if m then
			keep[m] = true
			c.existing = m
			local ref = m:FindFirstChild("DoorRef")
			if ref and ref.Value ~= c.door then ref.Value = c.door end
		end
	end
	local pending = false
	for _, m in ipairs(hotel.Rooms:GetChildren()) do
		if m:GetAttribute("Custom") and not keep[m] then
			if FREE_STATES[m:GetAttribute("State") or "Ready"] then
				local name = m.Name
				RoomRemoved:Fire(m)
				local z = hotel.BuildZones:FindFirstChild(name)
				if z then z:Destroy() end
				taken[m:GetAttribute("RoomId") or 0] = nil
				m:Destroy()
				for _, it in ipairs(hotel.Placed:GetChildren()) do
					if it:GetAttribute("Room") == name then
						it:SetAttribute("Core", nil)
						it:SetAttribute("Room", nil)
					end
					if it:GetAttribute("Zone") == name then
						local nz2 = Build.zoneAt(it:GetPivot().Position)
						it:SetAttribute("Zone", nz2 and nz2.Name or "Lobby")
					end
				end
				changed = true
			else
				pending = true
			end
		end
	end
	-- 5. build the new ones
	local made = {}
	for _, c in ipairs(want) do
		if not c.existing then
			local id = hints and tonumber(hints[c.sig])
			if not id or taken[id] or id < Rooms.FIRST_ID then
				id = Rooms.FIRST_ID
				while taken[id] do id += 1 end
			end
			taken[id] = true
			local m = Builder.customRoom(hotel, id, {
				x0 = c.x0, x1 = c.x1, z0 = c.z0, z1 = c.z1, door = c.door, dcf = c.dcf, n = c.nrm,
			})
			m:SetAttribute("Sig", c.sig)
			-- furniture already standing in there joins the room
			local name = m.Name
			local have = {}
			local inside = {}
			for _, it in ipairs(hotel.Placed:GetChildren()) do
				local iid = it:GetAttribute("Item")
				if not (Catalog.ITEMS[iid or ""] and Catalog.ITEMS[iid or ""].wallKind) then
					local z = Build.zoneAt(it:GetPivot().Position)
					if z and z.Name == name then
						it:SetAttribute("Zone", name)
						table.insert(inside, it)
						if it:GetAttribute("Core") and it:GetAttribute("Room") == name then have[it:GetAttribute("Core")] = true end
					end
				end
			end
			for _, it in ipairs(inside) do
				local item = Catalog.ITEMS[it:GetAttribute("Item")]
				local kind = item and (item.core or item.coreKind)
				if kind and not have[kind] and it:GetAttribute("Room") ~= name then
					it:SetAttribute("Core", kind)
					it:SetAttribute("Room", name)
					have[kind] = true
				end
			end
			RoomAdded:Fire(m)
			table.insert(made, id)
			changed = true
		end
	end
	hotel:SetAttribute("RoomsPending", pending or nil)
	if changed then ItemsChanged:Fire() end
	return made
end

-- the save's hint table: { [sig] = id } for every room made with walls
function Rooms.hints(hotel)
	local out = {}
	for _, m in ipairs(hotel.Rooms:GetChildren()) do
		if m:GetAttribute("Custom") and m:GetAttribute("Sig") then out[m:GetAttribute("Sig")] = m:GetAttribute("RoomId") end
	end
	return out
end

-- the Swing model of a room's door: its own (built rooms) or the Door item's (rooms made with walls)
function Rooms.door(roomModel)
	local d = roomModel:FindFirstChild("Door")
	if d then return d end
	local ref = roomModel:FindFirstChild("DoorRef")
	return ref and ref.Value and ref.Value:FindFirstChild("Swing")
end

return Rooms
