-- ServerStorage.Nav: the walk grid for one hotel plot (round 10). It replaces PathfindingService for
-- guests and staff.
-- How it works:
--   1. The plot is cut into 1-stud cells. A cell is blocked when anything stands in the body band
--      (furniture, walls, glass, plants, lamps, lot decor) or the ground there is raised lawn.
--   2. A clearance cost keeps walkers in the middle of corridors and doorways.
--   3. A* runs with no corner cutting.
--   4. The path is string-pulled into straight runs that never get closer to things than the raw path did.
--   5. If furniture walls a spot off completely, a second search may cross furniture (never walls), so
--      nobody is ever left without a route.
-- NPCs don't collide with furniture (collision group NPCSolid), so a walker can always finish a path.
-- API: Nav.new(hotel, origin) -> grid; grid:rebuild() (yields; call again after edits);
-- grid:path(from, to) -> { Vector3 } or nil; grid:free(pos) -> bool; grid.ready.
local Nav = {}
Nav.__index = Nav

local CS = 1 -- cell size (studs)
local MIN_X, MAX_X, MIN_Z, MAX_Z = -110, 110, -40, 78 -- plot-relative bounds
local BAND_LO, BAND_HI = 1.5, 5.4 -- the body band above the plot base (feet stand at about 0.5..1.1)
local INFLATE = 1.05 -- body radius: a cell is blocked when its centre is this close to a part
local LAWN = 1.55 -- terrain higher than this above the base is lawn, not walkway
local CLEAR_CAP = 4
local PEN = { 1.6, 0.5, 0.12 } -- extra step cost near things, by clearance 1, 2, 3
local SQRT2 = math.sqrt(2)
local MAX_POPS = 70000
local TALL = 8 -- parts reaching this high above the base are structure (walls, glass): never walked through
local SOFT = 9 -- extra cost per furniture cell when no clean route exists

local SKIP_NAMES = { Nav = true, BuildZones = true, Guests = true, Mess = true, Slide = true, NeedCleaning = true, Vacant = true }

-- static city parts near the street, collected once (the city doesn't change at runtime)
local cityParts
local function collectCity()
	if cityParts then return cityParts end
	cityParts = {}
	local city = workspace:FindFirstChild("City")
	if not city then return cityParts end
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and d.Position.Z > -90 and d.Position.Z < 95 then table.insert(cityParts, d) end
	end
	return cityParts
end

function Nav.new(hotel, origin)
	local self = setmetatable({}, Nav)
	self.hotel = hotel
	self.O = origin or Vector3.zero
	self.x0 = self.O.X + MIN_X
	self.z0 = self.O.Z + MIN_Z
	self.W = math.floor((MAX_X - MIN_X) / CS)
	self.H = math.floor((MAX_Z - MIN_Z) / CS)
	self.N = self.W * self.H
	self.ready = false
	self.stamp = 0
	self.seen = table.create(self.N, 0)
	self.g = table.create(self.N, 0)
	self.came = table.create(self.N, 0)
	self.shut = table.create(self.N, 0)
	return self
end

---------------------------------------------------------------- cells

function Nav:cellOf(pos)
	local cx = math.floor((pos.X - self.x0) / CS)
	local cz = math.floor((pos.Z - self.z0) / CS)
	if cx < 0 or cz < 0 or cx >= self.W or cz >= self.H then return nil end
	return cz * self.W + cx + 1, cx, cz
end

function Nav:centre(i, y)
	local cx = (i - 1) % self.W
	local cz = (i - 1) // self.W
	return Vector3.new(self.x0 + (cx + 0.5) * CS, y, self.z0 + (cz + 0.5) * CS)
end

function Nav:free(pos)
	local i = self:cellOf(pos)
	return i ~= nil and self.ready and self.blocked[i] == 0
end

---------------------------------------------------------------- building the grid

-- parts that never block: helpers, people, doors that open, room clutter that comes and goes
function Nav:_skip(part)
	if part.Transparency >= 0.95 and not part.CanCollide then return true end
	if part:GetAttribute("NavOpen") then return true end
	local a = part.Parent
	while a and a ~= workspace and a ~= game do
		if SKIP_NAMES[a.Name] or a:GetAttribute("NavOpen") then return true end
		if a.Name == "Doors" and a.Parent == self.hotel then return true end
		if a:IsA("Model") and a:FindFirstChildOfClass("Humanoid") then return true end
		if a == self.hotel then return false end
		a = a.Parent
	end
	return false
end

-- mark the cells under one part (its footprint, grown by the body radius)
function Nav:_stamp(part, blocked)
	local cf, s = part.CFrame, part.Size
	local rv, uv, lv = cf.RightVector, cf.UpVector, cf.LookVector
	local hy = 0.5 * (math.abs(rv.Y) * s.X + math.abs(uv.Y) * s.Y + math.abs(lv.Y) * s.Z)
	local base = self.O.Y
	if cf.Y + hy < base + BAND_LO or cf.Y - hy > base + BAND_HI then return end
	local kind = (cf.Y + hy > base + TALL and part.Size.Magnitude > 6) and 2 or 1
	-- the footprint: the two box axes that lie flattest, flattened onto the ground
	local axes = { { rv, s.X }, { uv, s.Y }, { lv, s.Z } }
	table.sort(axes, function(a, b) return math.abs(a[1].Y) < math.abs(b[1].Y) end)
	local a1 = Vector3.new(axes[1][1].X, 0, axes[1][1].Z)
	local a2 = Vector3.new(axes[2][1].X, 0, axes[2][1].Z)
	local h1 = 0.5 * axes[1][2] * a1.Magnitude + INFLATE
	local h2 = 0.5 * axes[2][2] * a2.Magnitude + INFLATE
	if a1.Magnitude < 1e-3 or a2.Magnitude < 1e-3 then return end
	a1, a2 = a1.Unit, a2.Unit
	local px, pz = cf.X, cf.Z
	local ex = math.abs(a1.X) * h1 + math.abs(a2.X) * h2
	local ez = math.abs(a1.Z) * h1 + math.abs(a2.Z) * h2
	local W, H = self.W, self.H
	local cx0 = math.max(0, math.floor((px - ex - self.x0) / CS))
	local cx1 = math.min(W - 1, math.floor((px + ex - self.x0) / CS))
	local cz0 = math.max(0, math.floor((pz - ez - self.z0) / CS))
	local cz1 = math.min(H - 1, math.floor((pz + ez - self.z0) / CS))
	if cx0 > cx1 or cz0 > cz1 then return end
	for cz = cz0, cz1 do
		local wz = self.z0 + (cz + 0.5) * CS - pz
		local row = cz * W + 1
		for cx = cx0, cx1 do
			local wx = self.x0 + (cx + 0.5) * CS - px
			if math.abs(wx * a1.X + wz * a1.Z) <= h1 and math.abs(wx * a2.X + wz * a2.Z) <= h2 then
				if blocked[row + cx] < kind then blocked[row + cx] = kind end
			end
		end
	end
end

-- raised lawn (terrain) is not walkway. Done once: the ground doesn't change
function Nav:_lawns()
	if self.lawn then return self.lawn end
	local lawn = table.create(self.N, 0)
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local base = self.O.Y
	for i = 1, self.N do
		local hit = workspace:Raycast(self:centre(i, base + 14), Vector3.new(0, -30, 0), terrainOnly)
		if hit and hit.Position.Y > base + LAWN then lawn[i] = 1 end
		if i % 3000 == 0 then task.wait() end
	end
	self.lawn = lawn
	return lawn
end

function Nav:rebuild()
	if self.building then self.again = true return end
	self.building = true
	repeat
		self.again = false
		local lawn = self:_lawns()
		local blocked = table.clone(lawn)
		local count = 0
		for _, d in ipairs(self.hotel:GetDescendants()) do
			if d:IsA("BasePart") and not self:_skip(d) then
				self:_stamp(d, blocked)
				count += 1
				if count % 600 == 0 then task.wait() end
			end
		end
		local xMin, xMax = self.x0 - 6, self.x0 + self.W * CS + 6
		for _, d in ipairs(collectCity()) do
			if d.Parent and d.Position.X > xMin and d.Position.X < xMax and not self:_skip(d) then
				self:_stamp(d, blocked)
			end
		end
		-- clearance: how many cells to the nearest blocked cell (or the grid edge), capped
		local W, H, N = self.W, self.H, self.N
		local clear = table.create(N, CLEAR_CAP)
		local frontier = {}
		for i = 1, N do
			local cx, cz = (i - 1) % W, (i - 1) // W
			if blocked[i] ~= 0 then
				clear[i] = 0
				table.insert(frontier, i)
			elseif cx == 0 or cz == 0 or cx == W - 1 or cz == H - 1 then
				clear[i] = 1
			end
		end
		for d = 1, CLEAR_CAP - 1 do
			local nextF = {}
			for _, i in ipairs(frontier) do
				local cx, cz = (i - 1) % W, (i - 1) // W
				for dz = -1, 1 do
					local z = cz + dz
					if z >= 0 and z < H then
						for dx = -1, 1 do
							local x = cx + dx
							if x >= 0 and x < W then
								local j = z * W + x + 1
								if clear[j] > d then
									clear[j] = d
									table.insert(nextF, j)
								end
							end
						end
					end
				end
			end
			frontier = nextF
			task.wait()
		end
		self.blocked, self.clear = blocked, clear
		self.ready = true
	until not self.again
	self.building = false
end

---------------------------------------------------------------- search

-- the nearest open cell to a blocked one (start or goal tucked into furniture)
function Nav:_nearestFree(i, pos)
	if self.blocked[i] == 0 then return i end
	local W, H = self.W, self.H
	local cx, cz = (i - 1) % W, (i - 1) // W
	for r = 1, 8 do
		local best, bestD = nil, math.huge
		for dz = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dz)) == r then
					local x, z = cx + dx, cz + dz
					if x >= 0 and z >= 0 and x < W and z < H then
						local j = z * W + x + 1
						if self.blocked[j] == 0 then
							local c = self:centre(j, 0)
							local d = (c.X - pos.X) ^ 2 + (c.Z - pos.Z) ^ 2 - self.clear[j] * 0.3
							if d < bestD then best, bestD = j, d end
						end
					end
				end
			end
		end
		if best then return best end
	end
	return nil
end

local DIRS = { { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 }, { 1, 1, SQRT2 }, { 1, -1, SQRT2 }, { -1, 1, SQRT2 }, { -1, -1, SQRT2 } }

function Nav:_astar(si, gi, soft)
	local W, H = self.W, self.H
	local blocked, clear = self.blocked, self.clear
	self.stamp += 1
	local st = self.stamp
	local seen, g, came, shut = self.seen, self.g, self.came, self.shut
	local gx, gz = (gi - 1) % W, (gi - 1) // W
	local hk, hv, n = {}, {}, 0
	local function push(i, f)
		n += 1
		local k = n
		while k > 1 do
			local p = k // 2
			if hk[p] <= f then break end
			hk[k], hv[k] = hk[p], hv[p]
			k = p
		end
		hk[k], hv[k] = f, i
	end
	local function pop()
		local top = hv[1]
		local lk, lv = hk[n], hv[n]
		hk[n], hv[n] = nil, nil
		n -= 1
		if n > 0 then
			local k = 1
			while true do
				local c = k * 2
				if c > n then break end
				if c < n and hk[c + 1] < hk[c] then c += 1 end
				if hk[c] >= lk then break end
				hk[k], hv[k] = hk[c], hv[c]
				k = c
			end
			hk[k], hv[k] = lk, lv
		end
		return top
	end
	local function h(i)
		local dx = math.abs((i - 1) % W - gx)
		local dz = math.abs((i - 1) // W - gz)
		return dx + dz + (SQRT2 - 2) * math.min(dx, dz)
	end
	seen[si], g[si], came[si] = st, 0, 0
	push(si, h(si))
	local pops = 0
	while n > 0 do
		local i = pop()
		if shut[i] ~= st then
			shut[i] = st
			if i == gi then break end
			pops += 1
			if pops > MAX_POPS then return nil end
			local cx, cz = (i - 1) % W, (i - 1) // W
			local gi0 = g[i]
			for _, d in ipairs(DIRS) do
				local x, z = cx + d[1], cz + d[2]
				if x >= 0 and z >= 0 and x < W and z < H then
					local j = z * W + x + 1
					local b = blocked[j]
					if shut[j] ~= st and (b == 0 or (soft and b == 1))
						-- no corner cutting: a diagonal needs both sides open
						and (d[3] == 1 or soft or (blocked[cz * W + x + 1] == 0 and blocked[z * W + cx + 1] == 0)) then
						local c = clear[j]
						local cost = gi0 + d[3] * (1 + (b == 1 and SOFT or (PEN[c] or 0)))
						if seen[j] ~= st or cost < g[j] then
							seen[j], g[j], came[j] = st, cost, i
							push(j, cost + h(j))
						end
					end
				end
			end
		end
	end
	if shut[gi] ~= st then return nil end
	local cells = {}
	local i = gi
	while i ~= 0 do
		table.insert(cells, 1, i)
		i = came[i]
	end
	return cells
end

-- every cell along a straight line is open and at least `need` cells from anything
function Nav:_line(a, b, need)
	local d = b - a
	local len = math.sqrt(d.X * d.X + d.Z * d.Z)
	local steps = math.max(1, math.ceil(len / (CS * 0.34)))
	local blocked, clear = self.blocked, self.clear
	for k = 0, steps do
		local t = k / steps
		local i = self:cellOf(a + d * t)
		if not i or blocked[i] ~= 0 or clear[i] < need then return false end
	end
	return true
end

function Nav:path(from, to)
	if not self.ready then return nil end
	local si = self:cellOf(from)
	local gi = self:cellOf(to)
	if not si or not gi then return nil end
	si = self:_nearestFree(si, from)
	gi = self:_nearestFree(gi, to)
	if not si or not gi then return nil end
	local y = to.Y
	if si == gi then return { from, to } end
	local cells = self:_astar(si, gi) or self:_astar(si, gi, true)
	if not cells then return nil end
	local clear = self.clear
	local pts, need = {}, {}
	for k, i in ipairs(cells) do
		pts[k] = self:centre(i, y)
		need[k] = math.min(2, clear[i])
	end
	-- string pulling: from each anchor, jump to the furthest cell in plain sight that keeps at least the
	-- clearance the raw path had over the skipped stretch
	local out = { from }
	local a = 1
	local n = #pts
	while a < n do
		local best = a + 1
		local runMin = math.min(need[a], need[a + 1])
		local misses = 0
		for k = a + 2, n do
			runMin = math.min(runMin, need[k])
			if self:_line(pts[a], pts[k], runMin) then
				best = k
				misses = 0
			else
				misses += 1
				if misses > 4 then break end
			end
		end
		if best < n then table.insert(out, pts[best]) end
		a = best
	end
	table.insert(out, Vector3.new(to.X, y, to.Z))
	return out
end

return Nav
