-- ReplicatedStorage.Shared.RoomPlan (round 15): lays a room kit out inside a walled rectangle.
-- A small search: every bed spot along the walls is tried, the rest goes in greedily (bathroom in the corners,
-- nightstands beside the bed's head, lamps and plants in the corners, the TV facing the bed, the rug under the
-- bed's foot) and the layout that fits the most pieces, then looks best, wins. It is pure 2D (rooms are always
-- square to the world), so build mode can run it live while a room is being dragged out.
--   P.interior(hotel, rect)          -> B {x0,x1,z0,z1}: where footprints may go (walls measured, thick ones too)
--   P.obstacles(hotel, B)            -> boxes of furniture already standing in there
--   P.plan(slots, rect, B, fixed)    -> res {spots = {[i] = spot}, score, max, alt(i, blocked)}
--   P.pivot(id, spot, y)             -> the item's pivot CFrame for a spot
-- slots = { {role, id}, ... }; roles: bed, bath, night, corner, side, center. rect = the build tool's room rect
-- (sides[0..3] = {c, n (inward), t, L}, side = the door's side, door = the door's CFrame).
local Shared = script.Parent
local Build = require(Shared:WaitForChild("Build"))
local Catalog = require(Shared:WaitForChild("Catalog"))

local P = {}

P.EDGE = 0.95 -- a wall's half thickness (skirting included) plus a hair
local GAP = { night = 0.2, corner = 0.35 } -- room between two pieces (the smaller of the two counts); default 0.5
local CLEAR = { bed = 1.0, bath = 2.2, side = 1.8, center = 1.1 } -- the floor kept free in front, to use it
local WEIGHT = { bed = 100, bath = 20, side = 6, center = 5, night = 4, corner = 4 }
local ORDER = { bed = 1, night = 2, bath = 3, side = 4, center = 5, corner = 6 } -- nightstands belong to the bed

local function overlap(a, b, pad)
	pad = pad or 0
	return math.abs(a.x - b.x) < a.hx + b.hx + pad - 1e-3 and math.abs(a.z - b.z) < a.hz + b.hz + pad - 1e-3
end
local function area(a, b)
	local w = math.min(a.x + a.hx, b.x + b.hx) - math.max(a.x - a.hx, b.x - b.hx)
	local h = math.min(a.z + a.hz, b.z + b.hz) - math.max(a.z - a.hz, b.z - b.hz)
	return (w > 0 and h > 0) and w * h or 0
end

-- the free floor inside the walls. Our own walls are EDGE thick; the hotel's walls and older rooms' can be
-- thicker, so each side is also measured with a few rays from the middle.
function P.interior(hotel, rect)
	local s = rect.sides
	local x0, x1 = math.min(s[3].c.X, s[1].c.X), math.max(s[3].c.X, s[1].c.X)
	local z0, z1 = math.min(s[0].c.Z, s[2].c.Z), math.max(s[0].c.Z, s[2].c.Z)
	local B = { x0 = x0 + P.EDGE, x1 = x1 - P.EDGE, z0 = z0 + P.EDGE, z1 = z1 - P.EDGE }
	if not hotel then return B end
	local inc = {}
	for _, n in ipairs({ "Shell", "Rooms" }) do
		local f = hotel:FindFirstChild(n)
		if f then table.insert(inc, f) end
	end
	local placed = hotel:FindFirstChild("Placed")
	if placed then
		for _, m in ipairs(placed:GetChildren()) do
			local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
			if it and it.structure then
				local p = m:GetPivot().Position
				if p.X > x0 - 3 and p.X < x1 + 3 and p.Z > z0 - 3 and p.Z < z1 + 3 then table.insert(inc, m) end
			end
		end
	end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = inc
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local y = Build.FY + (rect.y or 0)
	for _, h in ipairs({ 0.45, 2.5 }) do
		for _, f in ipairs({ -0.38, 0, 0.38 }) do
			local zz, xx = cz + f * (z1 - z0), cx + f * (x1 - x0)
			local hit = workspace:Raycast(Vector3.new(cx, y + h, zz), Vector3.new(x0 - cx - 2, 0, 0), rp)
			if hit then B.x0 = math.max(B.x0, hit.Position.X + 0.12) end
			hit = workspace:Raycast(Vector3.new(cx, y + h, zz), Vector3.new(x1 - cx + 2, 0, 0), rp)
			if hit then B.x1 = math.min(B.x1, hit.Position.X - 0.12) end
			hit = workspace:Raycast(Vector3.new(xx, y + h, cz), Vector3.new(0, 0, z0 - cz - 2), rp)
			if hit then B.z0 = math.max(B.z0, hit.Position.Z + 0.12) end
			hit = workspace:Raycast(Vector3.new(xx, y + h, cz), Vector3.new(0, 0, z1 - cz + 2), rp)
			if hit then B.z1 = math.min(B.z1, hit.Position.Z - 0.12) end
		end
	end
	return B
end

-- furniture already standing inside B (world boxes)
function P.obstacles(hotel, B)
	local list = {}
	local placed = hotel and hotel:FindFirstChild("Placed")
	if not placed then return list end
	for _, m in ipairs(placed:GetChildren()) do
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		if it and not it.structure and not it.wall then
			local cf, sz = m:GetBoundingBox()
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local hx = (math.abs(r.X) * sz.X + math.abs(u.X) * sz.Y + math.abs(l.X) * sz.Z) / 2
			local hz = (math.abs(r.Z) * sz.X + math.abs(u.Z) * sz.Y + math.abs(l.Z) * sz.Z) / 2
			local p = cf.Position
			if p.X + hx > B.x0 and p.X - hx < B.x1 and p.Z + hz > B.z0 and p.Z - hz < B.z1 then
				table.insert(list, { x = p.X, z = p.Z, hx = hx, hz = hz, flat = it.flat or false, gap = 0.4, fixed = true })
			end
		end
	end
	return list
end

-- the pivot that puts an item's footprint on a spot
function P.pivot(id, sp, y)
	local off = Build.box(id)
	local o = off.Position
	local w = CFrame.Angles(0, math.rad(sp.yaw), 0):VectorToWorldSpace(Vector3.new(o.X, 0, o.Z))
	return Build.pivot(sp.x - w.X, y or 0, sp.z - w.Z, sp.yaw % 360)
end

function P.plan(slots, rect, B, fixed)
	fixed = fixed or {}
	local d = rect.side or 0
	local dn, dt = rect.sides[d].n, rect.sides[d].t
	local dp = rect.door and rect.door.Position or rect.sides[d].c
	-- the way in through the door: 5 wide, 4 deep from the wall line; nothing that stands may block it
	local lane = {
		x = dp.X + dn.X * 2, z = dp.Z + dn.Z * 2,
		hx = math.abs(dn.X) * 2 + math.abs(dt.X) * 2.5, hz = math.abs(dn.Z) * 2 + math.abs(dt.Z) * 2.5,
	}
	local walls = {}
	for _, n in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
		local w = { n = n, yaw = math.deg(math.atan2(n.X, n.Z)) % 360 }
		w.door, w.back = n:Dot(dn) > 0.5, n:Dot(dn) < -0.5
		if n.X ~= 0 then w.t0, w.t1 = B.z0, B.z1 else w.t0, w.t1 = B.x0, B.x1 end
		table.insert(walls, w)
	end
	local cxB, czB = (B.x0 + B.x1) / 2, (B.z0 + B.z1) / 2

	-- the slots, with what the search needs to know about each piece
	local info, max = {}, 0
	for i, s in ipairs(slots) do
		local id = s[2] or s.id
		local role = s[1] or s.role
		if id and Catalog.ITEMS[id] then
			local _, size = Build.box(id)
			local it = Catalog.ITEMS[id]
			table.insert(info, {
				i = i, id = id, role = role, sx = size.X, sz = size.Z, flat = it.flat or false,
				gap = GAP[role] or 0.5, clear = it.flat and 0 or (CLEAR[role] or 0),
			})
			max += WEIGHT[role] or 3
		end
	end
	table.sort(info, function(a, b)
		if a.flat ~= b.flat then return not a.flat end
		local oa, ob = ORDER[a.role] or 9, ORDER[b.role] or 9
		if oa ~= ob then return oa < ob end
		return a.sx * a.sz > b.sx * b.sz
	end)

	local function inside(b, slack)
		slack = (slack or 0) + 1e-3
		return b.x - b.hx >= B.x0 - slack and b.x + b.hx <= B.x1 + slack and b.z - b.hz >= B.z0 - slack and b.z + b.hz <= B.z1 + slack
	end
	local function box(x, z, n, sx, sz)
		if n.X ~= 0 then return { x = x, z = z, hx = sz / 2, hz = sx / 2 } end
		return { x = x, z = z, hx = sx / 2, hz = sz / 2 }
	end
	local function wallSpot(w, t, sx, sz)
		local b
		if w.n.X ~= 0 then
			b = box(0, t, w.n, sx, sz)
			b.x = w.n.X > 0 and B.x0 + b.hx or B.x1 - b.hx
		else
			b = box(t, 0, w.n, sx, sz)
			b.z = w.n.Z > 0 and B.z0 + b.hz or B.z1 - b.hz
		end
		b.yaw, b.w, b.t = w.yaw, w, t
		return b
	end
	local function frontOf(sp, c)
		if c <= 0 then return nil end
		if not sp.w then return { x = sp.x, z = sp.z, hx = sp.hx + c, hz = sp.hz + c } end
		local n = sp.w.n
		local dh = n.X ~= 0 and sp.hx or sp.hz
		local x, z = sp.x + n.X * (dh + c / 2), sp.z + n.Z * (dh + c / 2)
		if n.X ~= 0 then return { x = x, z = z, hx = c / 2, hz = sp.hz } end
		return { x = x, z = z, hx = sp.hx, hz = c / 2 }
	end
	local function cornerDist(sp)
		local best = math.huge
		for _, x in ipairs({ B.x0, B.x1 }) do
			for _, z in ipairs({ B.z0, B.z1 }) do
				local ex = math.max(math.abs(sp.x - x) - sp.hx, 0)
				local ez = math.max(math.abs(sp.z - z) - sp.hz, 0)
				best = math.min(best, ex + ez)
			end
		end
		return best
	end
	local function mid(w) return (w.t0 + w.t1) / 2 end

	local function cost(s, sp, ctx)
		local role, w = s.role, sp.w
		if role == "bed" then
			return (w.back and 0 or w.door and 9 or 2.5) + math.abs(sp.t - mid(w)) * 0.3
		elseif role == "bath" then
			local c = cornerDist(sp) * 0.6
			if ctx.bed and ctx.bed.w == w then c += 2.5 end
			if ctx.bath then c += math.sqrt((sp.x - ctx.bath.x) ^ 2 + (sp.z - ctx.bath.z) ^ 2) * 0.15 end
			return c
		elseif role == "night" then
			local b = ctx.bed
			if b and b.w == w then
				local g = b.sx / 2 + s.sx / 2 + 0.25
				return math.min(math.abs(sp.t - (b.t + g)), math.abs(sp.t - (b.t - g))) * 3
			end
			return 15 + cornerDist(sp)
		elseif role == "corner" then
			local c = cornerDist(sp)
			if ctx.bed then c += math.sqrt((sp.x - ctx.bed.x) ^ 2 + (sp.z - ctx.bed.z) ^ 2) * 0.03 end
			return c
		elseif role == "side" then
			if s.id == "TVStand" and ctx.bed then
				return (w.n:Dot(ctx.bed.w.n) < -0.5 and 0 or 4) + math.abs(sp.t - ctx.bed.t) * 0.25
			end
			return math.abs(sp.t - mid(w)) * 0.25 + ((ctx.bed and ctx.bed.w == w) and 2 or 0) + (w.door and 1.5 or 0)
		end
		return 0
	end

	-- every spot a piece could take, cheapest first
	local function candidates(s, ctx, placed, step)
		local list = {}
		if s.role == "center" then
			local ref = ctx.bed and ctx.bed.w or nil
			if not ref then
				for _, w in ipairs(walls) do if w.back then ref = w end end
			end
			local tx, tz = cxB, czB
			if s.flat and ctx.bed then
				-- the rug: across the bed's foot, a little under it
				local b = ctx.bed
				local dh = b.w.n.X ~= 0 and b.hx or b.hz
				local reach = dh + (s.sz / 2) - 1.2
				tx, tz = b.x + b.w.n.X * reach, b.z + b.w.n.Z * reach
			end
			for _, turn in ipairs({ 0, 90 }) do
				local n = turn == 0 and ref.n or Vector3.new(ref.n.Z, 0, -ref.n.X)
				local yaw = (math.deg(math.atan2(n.X, n.Z)) + 0) % 360
				local proto = box(0, 0, n, s.sx, s.sz)
				local g = s.flat and 0.5 or 1
				for x = B.x0 + proto.hx, B.x1 - proto.hx + 1e-3, g do
					for z = B.z0 + proto.hz, B.z1 - proto.hz + 1e-3, g do
						local sp = { x = x, z = z, hx = proto.hx, hz = proto.hz, yaw = yaw }
						local c = math.sqrt((x - tx) ^ 2 + (z - tz) ^ 2) * 0.5 + (turn == 0 and 0 or 1.5)
						if s.flat then
							local under, rugA = 0, 4 * sp.hx * sp.hz
							for _, o in ipairs(placed) do
								if not o.flat then under += area(sp, o) end
							end
							if under > rugA * 0.45 then c = math.huge else c += under / rugA * 6 end
						end
						if c < math.huge then
							sp.cost = c
							table.insert(list, sp)
						end
					end
				end
			end
		else
			for _, w in ipairs(walls) do
				local lo, hi = w.t0 + s.sx / 2, w.t1 - s.sx / 2
				if hi >= lo then
					local ts = { lo, hi, (lo + hi) / 2 }
					for t = lo + step, hi - 1e-3, step do table.insert(ts, t) end
					if s.role == "night" and ctx.bed and ctx.bed.w == w then
						local g = ctx.bed.sx / 2 + s.sx / 2 + 0.25
						table.insert(ts, ctx.bed.t + g)
						table.insert(ts, ctx.bed.t - g)
					end
					for _, t in ipairs(ts) do
						if t >= lo - 1e-3 and t <= hi + 1e-3 then
							local sp = wallSpot(w, t, s.sx, s.sz)
							sp.cost = cost(s, sp, ctx)
							table.insert(list, sp)
						end
					end
				end
			end
		end
		table.sort(list, function(a, b) return a.cost < b.cost end)
		return list
	end

	local function fits(sp, s, placed)
		if not inside(sp) then return false end
		if not s.flat and overlap(sp, lane) then return false end
		local fr = frontOf(sp, s.clear)
		if fr and not inside(fr, s.role == "center" and 1.2 or 0.3) then return false end
		for _, o in ipairs(placed) do
			if s.flat then
				if o.flat and overlap(sp, o, 0.1) then return false end
			elseif not o.flat then
				if overlap(sp, o, math.min(s.gap, o.gap or 0.5)) then return false end
				if o.front and overlap(sp, o.front) then return false end
				if fr and overlap(fr, o) then return false end
			end
		end
		return true
	end
	local function put(sp, s, placed, ctx)
		sp.flat, sp.gap, sp.front, sp.sx, sp.slot = s.flat, s.gap, frontOf(sp, s.clear), s.sx, s.i
		table.insert(placed, sp)
		if s.role == "bed" then ctx.bed = sp end
		if s.role == "bath" then ctx.bath = sp end
	end
	local function fill(list, placed, ctx, out)
		local score, c = 0, 0
		for _, s in ipairs(list) do
			for _, sp in ipairs(candidates(s, ctx, placed, 0.5)) do
				if fits(sp, s, placed) then
					put(sp, s, placed, ctx)
					out[s.i] = sp
					score += WEIGHT[s.role] or 3
					c += sp.cost
					break
				end
			end
		end
		return score, c
	end
	local function base()
		local placed = {}
		for _, f in ipairs(fixed) do table.insert(placed, f) end
		return placed
	end

	-- rugs never block anything, so the search runs on the standing pieces and the rugs go in last
	local solid, flats, flatMax = {}, {}, 0
	for _, s in ipairs(info) do
		if s.flat then
			table.insert(flats, s)
			flatMax += WEIGHT[s.role] or 3
		else
			table.insert(solid, s)
		end
	end
	local best, bestS, bestC, bestPlaced, bestCtx = {}, -1, math.huge, nil, nil
	if solid[1] and solid[1].role == "bed" then
		local bedS = solid[1]
		local rest = { table.unpack(solid, 2) }
		local tried = 0
		for _, bsp in ipairs(candidates(bedS, {}, base(), 1)) do
			local placed = base()
			if fits(bsp, bedS, placed) then
				tried += 1
				local ctx, out = {}, {}
				put(bsp, bedS, placed, ctx)
				out[bedS.i] = bsp
				local sc, c = fill(rest, placed, ctx, out)
				sc += WEIGHT.bed
				c += bsp.cost
				if sc > bestS or (sc == bestS and c < bestC) then
					best, bestS, bestC, bestPlaced, bestCtx = out, sc, c, placed, ctx
				end
				if tried >= 40 or (bestS == max - flatMax and tried >= 14) then break end
			end
		end
	end
	if bestS < 0 then
		bestPlaced, bestCtx = base(), {}
		local sc, c = fill(solid, bestPlaced, bestCtx, best)
		bestS, bestC = sc, c
	end
	bestS += (fill(flats, bestPlaced, bestCtx, best))

	local res = { spots = best, score = math.max(bestS, 0), max = max, lane = lane, count = 0, total = #info }
	for _ in pairs(best) do res.count += 1 end
	-- other spots for slot i if its planned one turns out blocked (blocked = extra boxes to keep off)
	function res.alt(i, blocked)
		local s
		for _, x in ipairs(info) do if x.i == i then s = x end end
		if not s then return {} end
		local placed, ctx = base(), {}
		for _, b in ipairs(blocked or {}) do table.insert(placed, b) end
		for j, sp in pairs(best) do
			if j ~= i then
				table.insert(placed, sp)
				if sp.w and slots[j] and (slots[j][1] or slots[j].role) == "bed" then ctx.bed = sp end
				if slots[j] and (slots[j][1] or slots[j].role) == "bath" then ctx.bath = sp end
			end
		end
		local list = {}
		for _, sp in ipairs(candidates(s, ctx, placed, 0.5)) do
			if fits(sp, s, placed) then table.insert(list, sp) end
		end
		return list
	end
	return res
end

return P
