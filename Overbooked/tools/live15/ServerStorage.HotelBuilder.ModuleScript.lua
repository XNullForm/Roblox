-- Run a Hotel edit-time builder: the hotel shell, lobby, three rooms and their nav spots.
-- Round 10 remake: a classic boutique hotel. Outside: red brick and limestone, steel-framed windows, a
-- striped awning over the door, a cornice and a marquee sign on the roof. Inside: a checkered marble lobby,
-- emerald panelling with brass rails under wallpaper, a coffered ceiling, oak chevron rooms with hex-tiled
-- bathrooms, and real plank doors on hinges (Doors swings them on each client).
-- Surfaces use MaterialVariants (B.materials: Checker, Chevron, Brick, Paper, Hex, Carpet).
-- Run from execute_luau: loadstring(HttpService:GetAsync("http://127.0.0.1:8791/HotelBuilder.lua"))().remodel()
-- Floor top is y = 1. Lobby z 0..30 (the street front at z 30), rooms z -30..-2, x -40..40, walls 14 high.
-- At run time Plots clones this hotel onto each plot; wings are built at the plot's Origin.
local B = {}

local CS = game:GetService("CollectionService")
local PROPS = game.ServerStorage:WaitForChild("HotelProps")
local FY = 1 -- floor top
-- every part, prop and spot is shifted by OX: the plot's Origin while building a wing at run time (zero in Edit)
local OX = Vector3.zero
local function useOrigin(hotel) OX = hotel and hotel:GetAttribute("Origin") or Vector3.zero end

local C = {
	paper = Color3.fromRGB(248, 236, 212), -- lobby wallpaper tint
	paperRoom = Color3.fromRGB(226, 230, 216), -- room wallpaper tint (soft sage)
	panel = Color3.fromRGB(36, 82, 68), -- emerald panelling
	panelDk = Color3.fromRGB(26, 64, 52),
	trim = Color3.fromRGB(250, 246, 236), -- crown, room skirting
	wood = Color3.fromRGB(176, 122, 76),
	woodDk = Color3.fromRGB(78, 50, 34), -- walnut
	door = Color3.fromRGB(156, 102, 62),
	doorDk = Color3.fromRGB(116, 72, 44),
	brick = Color3.fromRGB(255, 255, 255), -- the brick map shows as painted
	lime = Color3.fromRGB(230, 220, 198), -- limestone
	frame = Color3.fromRGB(30, 32, 36), -- blackened steel
	gold = Color3.fromRGB(218, 178, 98),
	green = Color3.fromRGB(24, 84, 64),
	cream = Color3.fromRGB(244, 236, 218),
	marbleDk = Color3.fromRGB(30, 56, 48),
	ceiling = Color3.fromRGB(248, 244, 236),
	roof = Color3.fromRGB(96, 98, 104),
	glass = Color3.fromRGB(176, 204, 214),
	warm = Color3.fromRGB(255, 226, 180),
	plinth = Color3.fromRGB(226, 220, 210),
	stone = Color3.fromRGB(58, 60, 66),
}
B.C = C

---------------------------------------------------------------- surfaces (MaterialVariants)
-- colour, normal and roughness maps made by tex_r10.py
B.TEX = {
	Checker = { base = "Marble", spt = 8, maps = { "124418745848185", "79295398520480", "93111898977371" } },
	Chevron = { base = "WoodPlanks", spt = 16, maps = { "94959979123839", "128500345173934", "101881038345035" } },
	Brick = { base = "Brick", spt = 12, maps = { "83001779844606", "136702499718256", "136172908442445" } },
	Paper = { base = "Plaster", spt = 8, maps = { "90479590356407", "117418952187604", "90972860652119" } },
	Hex = { base = "Marble", spt = 4, maps = { "97564287577914", "75509781436636", "129619415355392" } },
	Carpet = { base = "Fabric", spt = 6, maps = { "72464914302016", "101404558197204", "123547546400976" } },
}
function B.materials()
	local MS = game:GetService("MaterialService")
	for name, t in pairs(B.TEX) do
		-- already made in Edit: game servers can't write a variant's BaseMaterial, so leave it alone
		if MS:FindFirstChild("" .. name) and game:GetService("RunService"):IsRunning() then continue end
		local v = MS:FindFirstChild("" .. name) or Instance.new("MaterialVariant")
		v.Name = "" .. name
		v.BaseMaterial = Enum.Material[t.base]
		v.ColorMap = "rbxassetid://" .. t.maps[1]
		v.NormalMap = "rbxassetid://" .. t.maps[2]
		v.RoughnessMap = "rbxassetid://" .. t.maps[3]
		v.StudsPerTile = t.spt
		v.Parent = MS
	end
end

local function tex(p, name)
	p.Material = Enum.Material[B.TEX[name].base]
	p.MaterialVariant = "" .. name
	return p
end

---------------------------------------------------------------- helpers

local function part(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf + OX
	p.Color = color or C.trim
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = parent
	return p
end

-- axis-aligned block from min/max corners
local function block(parent, name, a, b, color, mat, extra)
	local lo = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return part(parent, name, hi - lo, CFrame.new((lo + hi) / 2), color, mat, extra)
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function place(name, parent, cf, rename)
	local m = PROPS[name]:Clone()
	m.Name = rename or name
	m:PivotTo(cf + OX)
	m.Parent = parent
	return m
end

local function spot(parent, name, cf, attrs)
	local p = part(parent, name, Vector3.new(1, 1, 1), cf, Color3.new(0, 1, 0), nil, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	if attrs then for k, v in pairs(attrs) do p:SetAttribute(k, v) end end
	return p
end

local function quiet(m)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	return m
end

local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

local function textSign(p, face, text, opts)
	opts = opts or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.pps or 50
	g.LightInfluence = opts.light or 0.4
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = opts.font or Enum.Font.FredokaOne
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = opts.color or Color3.new(1, 1, 1)
	t.Parent = g
	if opts.stroke then
		local s = Instance.new("UIStroke")
		s.Thickness = opts.stroke
		s.Color = opts.strokeColor or Color3.fromRGB(40, 30, 50)
		s.Parent = t
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0); pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = t
	return g, t
end

-- a framed "painting": a soft gradient canvas in a gilt frame; cf looks out of the wall
local function painting(parent, cf, w, h, c1, c2, c3)
	local m = model(parent, "Painting")
	part(m, "Frame", Vector3.new(w + 0.7, h + 0.7, 0.25), cf, C.gold, Enum.Material.Metal)
	part(m, "Inner", Vector3.new(w + 0.3, h + 0.3, 0.3), cf, C.woodDk, Enum.Material.Wood)
	local canvas = part(m, "Canvas", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.14), Color3.new(1, 1, 1))
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.LightInfluence = 0.6
	g.Parent = canvas
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ClipsDescendants = true
	f.Parent = g
	local gr = Instance.new("UIGradient")
	gr.Rotation = 90
	gr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(0.55, c2), ColorSequenceKeypoint.new(1, c3) })
	gr.Parent = f
	-- a sun and two hills
	local sun = Instance.new("Frame")
	sun.AnchorPoint = Vector2.new(0.5, 0.5)
	sun.Position = UDim2.fromScale(0.68, 0.36)
	sun.Size = UDim2.fromScale(0.22, 0.22)
	sun.SizeConstraint = Enum.SizeConstraint.RelativeYY
	sun.BackgroundColor3 = Color3.fromRGB(255, 236, 190)
	sun.BorderSizePixel = 0
	sun.Parent = f
	Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)
	for i, d in ipairs({ { 0.3, 0.78, 0.9, Color3.fromRGB(90, 130, 120) }, { 0.75, 0.86, 1.1, Color3.fromRGB(60, 100, 96) } }) do
		local hill = Instance.new("Frame")
		hill.AnchorPoint = Vector2.new(0.5, 0)
		hill.Position = UDim2.fromScale(d[1], d[2])
		hill.Size = UDim2.fromScale(d[3], 0.8)
		hill.BackgroundColor3 = d[4]
		hill.BorderSizePixel = 0
		hill.ZIndex = 1 + i
		hill.Parent = f
		Instance.new("UICorner", hill).CornerRadius = UDim.new(0.5, 0)
	end
	return m
end

-- a brass wall sconce with a frosted shade; `n` = the wall's outward normal (into the room)
local function sconce(parent, pos, n)
	local m = model(parent, "Sconce")
	local cf = CFrame.lookAt(pos, pos + n)
	part(m, "Plate", Vector3.new(0.7, 1.3, 0.12), cf * CFrame.new(0, 0, -0.06), C.gold, Enum.Material.Metal)
	part(m, "Arm", Vector3.new(0.14, 0.14, 0.7), cf * CFrame.new(0, -0.1, -0.4), C.gold, Enum.Material.Metal)
	part(m, "Shade", Vector3.new(1.1, 0.75, 0.75), cf * CFrame.new(0, 0.2, -0.85) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 244, 226), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.25 })
	local bulb = part(m, "Bulb", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 0.2, -0.85), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball })
	local l = Instance.new("PointLight")
	l.Color = C.warm; l.Range = 9; l.Brightness = 0.55
	l.Parent = bulb
	return quiet(m)
end

---------------------------------------------------------------- walls

local WALL_H = 14
local CEIL = FY + WALL_H - 0.4 -- the ceiling's underside
local RY = FY + WALL_H + 1.3 -- roof top
local DOOR_HALF, DOOR_H = 2.3, 7.9 -- room doorways: 4.6 wide, 7.9 tall (about one and a half guests)
local SKIN = 0.05
local RAIL = 4.3 -- lobby panelling height
B.WALL_H, B.CEIL, B.DOOR_HALF, B.DOOR_H = WALL_H, CEIL, DOOR_HALF, DOOR_H

-- the dressing on one inside face of a wall. lo/hi: the wall's nominal box, f: the face's normal (Vector2).
-- kind "lobby": wallpaper over emerald panelling with a brass rail, a walnut skirting and a marble border on
-- the floor; kind "room": wallpaper and a plain skirting. Both get a crown moulding at the ceiling.
local function dress(m, lo, hi, f, kind, y0, lift)
	lift = lift or 0
	local n3 = Vector3.new(f.X, 0, f.Y)
	local alongX = f.X == 0
	local a0, a1 = alongX and lo.X or lo.Z, alongX and hi.X or hi.Z
	local len = a1 - a0
	local plane = f.X > 0 and hi.X or f.X < 0 and lo.X or f.Y > 0 and hi.Z or lo.Z
	local mid = alongX and Vector3.new((a0 + a1) / 2, FY, plane) or Vector3.new(plane, FY, (a0 + a1) / 2)
	local base = CFrame.lookAt(mid, mid + n3) -- -Z points into the room, X runs along the wall
	-- a strip of length w, height from ya to yb (above the floor), from depth d0 to d1 off the face
	local function strip(name, w, ya, yb, d0, d1, color, mat, x)
		return part(m, name, Vector3.new(w, yb - ya, d1 - d0), base * CFrame.new(x or 0, (ya + yb) / 2, -(d0 + d1) / 2), color, mat)
	end
	local lobby = kind == "lobby"
	local yb0 = y0 - FY
	tex(strip("Paper", len, yb0, CEIL - FY, -SKIN, 0, lobby and C.paper or C.paperRoom, Enum.Material.Plaster), "Paper")
	-- crown: two cream steps under the ceiling
	strip("Crown", len, CEIL - FY - 0.45, CEIL - FY, 0, 0.32, C.trim, Enum.Material.Plaster)
	strip("Crown", len, CEIL - FY - 0.8, CEIL - FY - 0.45, 0, 0.16, C.trim, Enum.Material.Plaster)
	if yb0 > 1 then return end
	if not lobby then
		strip("Skirting", len, 0, 0.6, 0, 0.16, C.trim, Enum.Material.Wood)
		return
	end
	strip("Skirting", len, 0, 0.7, 0, 0.24, C.woodDk, Enum.Material.Wood)
	strip("Panel", len, 0.7, RAIL, 0, 0.12, C.panel, Enum.Material.Wood)
	strip("PanelRail", len, 0.95, 1.2, 0, 0.18, C.panelDk, Enum.Material.Wood)
	strip("PanelRail", len, RAIL - 0.55, RAIL - 0.3, 0, 0.18, C.panelDk, Enum.Material.Wood)
	local count = math.max(1, math.floor(len / 3.2 + 0.5))
	for i = 0, count do
		local x = -len / 2 + len * i / count
		x = math.clamp(x, -len / 2 + 0.2, len / 2 - 0.2)
		strip("Stile", 0.4, 1.2, RAIL - 0.55, 0, 0.18, C.panelDk, Enum.Material.Wood, x)
	end
	strip("Cap", len, RAIL - 0.05, RAIL + 0.2, 0, 0.24, C.panelDk, Enum.Material.Wood)
	strip("Rail", len, RAIL + 0.2, RAIL + 0.32, 0, 0.2, C.gold, Enum.Material.Metal)
	-- the marble border on the floor in front of it, with a brass line (lift keeps crossing borders apart)
	strip("Border", len, 0, 0.02 + lift, 0, 1.3, C.marbleDk, Enum.Material.Marble)
	strip("Inlay", len, 0, 0.03 + lift, 1.3, 1.42, C.gold, Enum.Material.Metal)
end

-- the outside skin of a wall: brick from below the plinth to the roof, a limestone base band and a string
-- course. ext = { start, finish }: how far the skin runs past the wall's ends (to wrap corners)
local function facade(m, lo, hi, out, ext)
	ext = ext or { 0, 0 }
	local alongX = out.X == 0
	local function slab(name, y0, y1, d0, d1, color, mat)
		local a0 = (alongX and lo.X or lo.Z) - ext[1]
		local a1 = (alongX and hi.X or hi.Z) + ext[2]
		local plane = out.X > 0 and hi.X or out.X < 0 and lo.X or out.Y > 0 and hi.Z or lo.Z
		local s = out.X + out.Y -- +1 or -1
		local p0, p1 = plane + s * d0, plane + s * d1
		local a, b
		if alongX then
			a, b = Vector3.new(a0, y0, p0), Vector3.new(a1, y1, p1)
		else
			a, b = Vector3.new(p0, y0, a0), Vector3.new(p1, y1, a1)
		end
		return block(m, name, a, b, color, mat)
	end
	tex(slab("Brick", FY - 2, FY + WALL_H + 0.5, 0, 0.3, C.brick), "Brick")
	slab("BaseBand", FY - 2, FY + 2, 0, 0.55, C.lime, Enum.Material.Limestone)
	slab("BaseCap", FY + 2, FY + 2.3, 0, 0.45, C.lime, Enum.Material.Limestone)
	slab("Course", FY + 10.4, FY + 11.0, 0, 0.62, C.lime, Enum.Material.Limestone)
end

-- limestone quoins up a corner: blocks alternating long and short on its two faces
local function quoins(m, corner, sx, sz)
	for i = 0, 12 do
		local y0 = FY + 2.3 + i * 0.95
		if y0 + 0.8 > FY + WALL_H + 0.5 then break end
		local long = i % 2 == 0
		local ax, az = long and 2.2 or 1.3, long and 1.3 or 2.2
		block(m, "Quoin", Vector3.new(corner.X + sx * 0.18, y0, corner.Z - sz * az), Vector3.new(corner.X - sx * 0.02, y0 + 0.8, corner.Z + sz * 0.18), C.lime, Enum.Material.Limestone)
		block(m, "Quoin", Vector3.new(corner.X - sx * ax, y0, corner.Z + sz * 0.18), Vector3.new(corner.X + sx * 0.18, y0 + 0.8, corner.Z - sz * 0.02), C.lime, Enum.Material.Limestone)
	end
end

-- a wall from a to b (x/z corners). Its parts go in a Model called `name` (a wing knocks a whole wall out
-- by name). inner = { { normal, "lobby" | "room" }, ... } dresses those faces (default: both long faces
-- as rooms); outside = the outward normal of a street-facing face. opts.y0 starts the wall higher (lintels);
-- opts.ext wraps the facade past the ends.
local function wall(parent, name, a, b, outside, inner, opts)
	opts = opts or {}
	local y0 = opts.y0 or FY
	local m = model(parent, name)
	local lo = Vector3.new(math.min(a.X, b.X), y0, math.min(a.Y, b.Y))
	local hi = Vector3.new(math.max(a.X, b.X), FY + WALL_H, math.max(a.Y, b.Y))
	local thinX = (hi.X - lo.X) < (hi.Z - lo.Z)
	if not inner then
		inner = thinX and { { Vector2.new(1, 0), "room" }, { Vector2.new(-1, 0), "room" } }
			or { { Vector2.new(0, 1), "room" }, { Vector2.new(0, -1), "room" } }
	end
	-- the core is pulled back SKIN from each dressed face; the wallpaper skins bring it back to the plane
	local cl, ch = lo, hi
	for _, e in ipairs(inner) do
		local f = e[1]
		if f.X > 0 then ch = Vector3.new(ch.X - SKIN, ch.Y, ch.Z) end
		if f.X < 0 then cl = Vector3.new(cl.X + SKIN, cl.Y, cl.Z) end
		if f.Y > 0 then ch = Vector3.new(ch.X, ch.Y, ch.Z - SKIN) end
		if f.Y < 0 then cl = Vector3.new(cl.X, cl.Y, cl.Z + SKIN) end
	end
	block(m, "Core", cl, ch, C.cream, Enum.Material.Plaster)
	-- a walnut cap on top (it outlines the floor plan from above while the roof is hidden)
	block(m, "Top", Vector3.new(lo.X - 0.05, FY + WALL_H, lo.Z - 0.05), Vector3.new(hi.X + 0.05, FY + WALL_H + 0.4, hi.Z + 0.05), C.woodDk, Enum.Material.Wood)
	for _, e in ipairs(inner) do dress(m, lo, hi, e[1], e[2], y0, opts.lift) end
	if outside then facade(m, lo, hi, outside, opts.ext) end
	return m
end

---------------------------------------------------------------- the street front

-- the street front between xa and xb (xa < xb): brick piers, steel-framed windows over limestone knee walls,
-- a limestone band with keystones above them, brick up to the roof. opts.wa / opts.wb: end pier widths.
local ZI, ZO = 29.7, 30.9 -- the front's inner and outer faces
local ZG = 30.2 -- the glass line: plaster reveals inside it, brick outside
local BAND0, BAND1 = FY + 10.4, FY + 11.0

local function steelWindow(m, b0, b1, g0, g1, opts)
	opts = opts or {}
	local w = b1 - b0
	block(m, "Glass", Vector3.new(b0, g0, 30.26), Vector3.new(b1, g1, 30.34), C.glass, Enum.Material.Glass, { Transparency = 0.6, Reflectance = 0.15, CastShadow = false })
	local function bar(name, a, b2, t)
		block(m, name, a, b2, C.frame, Enum.Material.Metal)
	end
	bar("Steel", Vector3.new(b0, g0, 30.16), Vector3.new(b0 + 0.22, g1, 30.44))
	bar("Steel", Vector3.new(b1 - 0.22, g0, 30.16), Vector3.new(b1, g1, 30.44))
	bar("Steel", Vector3.new(b0, g1 - 0.22, 30.16), Vector3.new(b1, g1, 30.44))
	bar("Steel", Vector3.new(b0, g0, 30.16), Vector3.new(b1, g0 + 0.22, 30.44))
	local cols = opts.cols or math.max(2, math.floor(w / 3.2 + 0.5))
	for j = 1, cols - 1 do
		local x = b0 + w * j / cols
		bar("Mullion", Vector3.new(x - 0.08, g0, 30.2), Vector3.new(x + 0.08, g1, 30.4))
	end
	for _, y in ipairs(opts.rows or {}) do
		bar("Transom", Vector3.new(b0, y - 0.08, 30.2), Vector3.new(b1, y + 0.08, 30.4))
	end
end

local function frontRun(parent, xa, xb, opts)
	opts = opts or {}
	local m = model(parent, "Front")
	local P = 1.6
	local wa, wb = opts.wa or P, opts.wb or P
	local L = xb - xa
	local k = math.max(1, math.floor((L - wa - wb + P) / (9.4 + P) + 0.5))
	local bay = (L - wa - wb - P * (k - 1)) / k
	local piers = { { xa, xa + wa } }
	for i = 1, k - 1 do
		local p0 = xa + wa + bay * i + P * (i - 1)
		table.insert(piers, { p0, p0 + P })
	end
	table.insert(piers, { xb - wb, xb })
	for _, pr in ipairs(piers) do
		tex(block(m, "Pier", Vector3.new(pr[1], FY - 2, ZG), Vector3.new(pr[2], BAND0, ZO), C.brick), "Brick")
		tex(block(m, "PierIn", Vector3.new(pr[1], FY, ZI), Vector3.new(pr[2], BAND0, ZG), C.paper, Enum.Material.Plaster), "Paper")
		block(m, "PierBase", Vector3.new(pr[1] - 0.05, FY - 2, ZO), Vector3.new(pr[2] + 0.05, FY + 2, ZO + 0.3), C.lime, Enum.Material.Limestone)
		block(m, "PierCap", Vector3.new(pr[1] - 0.05, FY + 2, ZO), Vector3.new(pr[2] + 0.05, FY + 2.3, ZO + 0.22), C.lime, Enum.Material.Limestone)
		block(m, "Skirting", Vector3.new(pr[1], FY, ZI - 0.24), Vector3.new(pr[2], FY + 0.7, ZI), C.woodDk, Enum.Material.Wood)
	end
	for i = 1, k do
		local b0 = xa + wa + (bay + P) * (i - 1)
		local b1 = b0 + bay
		local bc = (b0 + b1) / 2
		-- limestone knee wall with a sill outside and a walnut window seat inside
		block(m, "Knee", Vector3.new(b0, FY - 2, 29.85), Vector3.new(b1, FY + 0.8, 30.75), C.lime, Enum.Material.Limestone)
		block(m, "KneeIn", Vector3.new(b0, FY, 29.8), Vector3.new(b1, FY + 0.8, 29.85), C.panel, Enum.Material.Wood)
		block(m, "Sill", Vector3.new(b0 - 0.3, FY + 0.8, 30.3), Vector3.new(b1 + 0.3, FY + 1.06, 31.2), C.lime, Enum.Material.Limestone)
		block(m, "Seat", Vector3.new(b0, FY + 0.8, 29.3), Vector3.new(b1, FY + 1.02, 30.2), C.woodDk, Enum.Material.Wood)
		steelWindow(m, b0, b1, FY + 1.06, BAND0, { rows = { FY + 4.6, FY + 8.1, FY + 9.25 } })
		block(m, "Keystone", Vector3.new(bc - 0.55, BAND0 - 0.35, ZO), Vector3.new(bc + 0.55, BAND1 + 0.3, ZO + 0.55), C.lime, Enum.Material.Limestone)
	end
	block(m, "Band", Vector3.new(xa, BAND0, ZO), Vector3.new(xb, BAND1, ZO + 0.4), C.lime, Enum.Material.Limestone)
	tex(block(m, "Header", Vector3.new(xa, BAND0, ZG), Vector3.new(xb, FY + WALL_H + 0.5, ZO), C.brick), "Brick")
	tex(block(m, "HeaderIn", Vector3.new(xa, BAND0, ZI), Vector3.new(xb, FY + WALL_H + 0.5, ZG), C.paper, Enum.Material.Plaster), "Paper")
	block(m, "Crown", Vector3.new(xa, CEIL - 0.45, ZI - 0.32), Vector3.new(xb, CEIL, ZI), C.trim, Enum.Material.Plaster)
	block(m, "Crown", Vector3.new(xa, CEIL - 0.8, ZI - 0.16), Vector3.new(xb, CEIL - 0.45, ZI), C.trim, Enum.Material.Plaster)
	block(m, "Border", Vector3.new(xa, FY, ZI - 1.3), Vector3.new(xb, FY + 0.06, ZI), C.marbleDk, Enum.Material.Marble)
	block(m, "Inlay", Vector3.new(xa, FY, ZI - 1.42), Vector3.new(xb, FY + 0.07, ZI - 1.3), C.gold, Enum.Material.Metal)
	return m
end

-- the lobby end of a side wall: sconces either side of a big gilt-framed painting
local function sideDecor(wm, x, s, palette)
	local n = Vector3.new(-s, 0, 0)
	for _, z in ipairs({ 8, 24 }) do
		sconce(wm, Vector3.new(x, FY + 8.2, z), n)
	end
	painting(wm, CFrame.new(x - s * 0.15, FY + 8.4, 16) * CFrame.Angles(0, math.rad(s > 0 and 90 or -90), 0), 8, 4.4, palette[1], palette[2], palette[3])
end
local PAL_A = { Color3.fromRGB(150, 196, 220), Color3.fromRGB(246, 214, 176), Color3.fromRGB(214, 150, 140) }
local PAL_B = { Color3.fromRGB(236, 196, 150), Color3.fromRGB(196, 214, 190), Color3.fromRGB(96, 140, 120) }

-- an outer side wall whose inner face is at x = xin, running outward (s = +1 east, -1 west): a room
-- segment and a lobby segment (both Models named `name`), quoins on both corners, sconces and a painting
local function sideWall(parent, name, xin, s, palette)
	local xa, xb = xin, xin + s
	local out = Vector2.new(s, 0)
	local rw = wall(parent, name, Vector2.new(xa, -29.5), Vector2.new(xb, -2.5), out, { { Vector2.new(-s, 0), "room" } }, { ext = { 1, 0 } })
	local lw = wall(parent, name, Vector2.new(xa, -2.5), Vector2.new(xb, ZI), out, { { Vector2.new(-s, 0), "lobby" } }, { ext = { 0, 0.05 } })
	local xo = xin + s * 1.3
	quoins(rw, Vector3.new(xo, 0, -30.8), s, -1)
	quoins(lw, Vector3.new(xo, 0, ZO), s, 1)
	sideDecor(lw, xin, s, palette)
	return rw, lw
end

-- a brass carriage lantern on a bracket, on the street face at (x, y)
local function lantern(parent, x, y)
	local m = model(parent, "Lantern")
	local z = ZO + 0.3
	block(m, "Plate", Vector3.new(x - 0.3, y - 0.6, ZO), Vector3.new(x + 0.3, y + 0.6, ZO + 0.12), C.frame, Enum.Material.Metal)
	block(m, "Arm", Vector3.new(x - 0.07, y + 0.3, ZO), Vector3.new(x + 0.07, y + 0.44, z + 0.9), C.frame, Enum.Material.Metal)
	local c = Vector3.new(x, y - 0.3, z + 0.9)
	part(m, "Cap", Vector3.new(1.1, 0.25, 1.1), CFrame.new(c + Vector3.new(0, 1.1, 0)), C.frame, Enum.Material.Metal)
	part(m, "Finial", Vector3.new(0.3, 0.3, 0.3), CFrame.new(c + Vector3.new(0, 1.35, 0)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	part(m, "Glass", Vector3.new(0.8, 1.6, 0.8), CFrame.new(c + Vector3.new(0, 0.2, 0)), Color3.fromRGB(255, 240, 210), Enum.Material.Glass, { Transparency = 0.45 })
	for _, o in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(m, "Post", Vector3.new(0.1, 1.7, 0.1), CFrame.new(c + Vector3.new(o[1] * 0.42, 0.2, o[2] * 0.42)), C.gold, Enum.Material.Metal)
	end
	part(m, "Base", Vector3.new(0.95, 0.2, 0.95), CFrame.new(c + Vector3.new(0, -0.7, 0)), C.frame, Enum.Material.Metal)
	local flame = part(m, "Flame", Vector3.new(0.35, 0.6, 0.35), CFrame.new(c + Vector3.new(0, 0.1, 0)), Color3.fromRGB(255, 236, 200), Enum.Material.SmoothPlastic, { CastShadow = false })
	flame:SetAttribute("LitColor", Color3.fromRGB(255, 206, 130))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 200, 140); l.Range = 14; l.Brightness = 1.2; l.Enabled = false
	l.Parent = flame
	CS:AddTag(m, "NightLight")
	return quiet(m)
end

-- the striped awning over the front door (x -w..w), falling from the wall out to z = 36.4
local function awning(parent, w)
	local m = model(parent, "Awning")
	local top, low, z0, z1 = FY + 12.7, FY + 11.0, ZO + 0.05, 36.4
	local d = Vector3.new(0, low - top, z1 - z0)
	local n = 12
	local sw = 2 * w / n
	local colors = { C.green, Color3.fromRGB(244, 236, 216) }
	for i = 1, n do
		local x = -w + sw * (i - 0.5)
		local col = colors[(i - 1) % 2 + 1]
		local a = Vector3.new(x, top, z0)
		part(m, "Stripe", Vector3.new(sw, 0.12, d.Magnitude), CFrame.lookAt(a + d / 2, a + d), col, Enum.Material.Fabric)
		part(m, "Valance", Vector3.new(sw, 0.8, 0.1), CFrame.new(x, low - 0.36, z1 + 0.02), col, Enum.Material.Fabric)
		part(m, "Scallop", Vector3.new(0.1, sw, sw), CFrame.new(x, low - 0.76, z1 + 0.02) * CFrame.Angles(0, math.rad(90), 0), col, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	end
	for _, sx in ipairs({ -1, 1 }) do
		local a = Vector3.new(sx * (w + 0.02), top - 0.3, z0)
		part(m, "Side", Vector3.new(0.1, 0.7, d.Magnitude), CFrame.lookAt(a + d / 2, a + d), C.green, Enum.Material.Fabric)
		local p0 = Vector3.new(sx * (w - 0.2), FY + 10.2, ZO)
		local p1 = Vector3.new(sx * (w - 0.2), low - 0.05, z1 - 0.3)
		part(m, "Rod", Vector3.new(0.12, 0.12, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2, p1), C.gold, Enum.Material.Metal)
	end
	part(m, "FrontBar", Vector3.new(2 * w, 0.14, 0.14), CFrame.new(0, low, z1), C.gold, Enum.Material.Metal)
	-- warm lights under it at night
	local lights = model(m, "Lights")
	for _, x in ipairs({ -w * 0.5, w * 0.5 }) do
		local p = part(lights, "Light", Vector3.new(0.3, 0.3, 0.3), CFrame.new(x, low - 0.2, (z0 + z1) / 2), C.warm, Enum.Material.SmoothPlastic, { Transparency = 1, CastShadow = false })
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom; l.Angle = 90; l.Range = 16; l.Brightness = 1.4; l.Color = C.warm; l.Enabled = false
		l.Parent = p
	end
	CS:AddTag(lights, "NightLight")
	return quiet(m)
end

---------------------------------------------------------------- rooms

local ROOMS = {
	{ id = 101, cx = -26.5 },
	{ id = 102, cx = 0 },
	{ id = 103, cx = 26.5 },
}
B.ROOMS = ROOMS

-- a room's door: walnut casing on both faces, a brass threshold, and a plank leaf on a hinge (left as you
-- face it from the corridor) that swings into the room. The Door model is tagged SwingDoor (Doors
-- turns its Leaf about the Hinge on each client) and NavOpen (the walk grid ignores it); the leaf never collides.
local function plankLeaf(leaf, hinge, w, h, t, number)
	-- hinge: CFrame at the hinge line, floor level, X along the leaf, +Z out of the corridor face
	local function piece(name, x0, x1, y0, y1, z0, z1, color, mat)
		return part(leaf, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), hinge * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2) - OX, color, mat or Enum.Material.Wood)
	end
	local st = 0.42
	piece("Stile", 0, st, 0, h, 0, t, C.doorDk)
	piece("Stile", w - st, w, 0, h, 0, t, C.doorDk)
	piece("Rail", st, w - st, h - 0.5, h, 0, t, C.doorDk)
	piece("Rail", st, w - st, 0, 0.7, 0, t, C.doorDk)
	piece("Core", st, w - st, 0.7, h - 0.5, 0.07, t - 0.07, Color3.fromRGB(70, 42, 26))
	local n = 9
	local gap = 0.05
	local ph = (h - 1.2 - gap * (n + 1)) / n
	for i = 1, n do
		local y = 0.7 + gap + (i - 1) * (ph + gap)
		local k = 1 + ((i * 37) % 7 - 3) * 0.025
		local col = Color3.new(math.min(C.door.R * k, 1), math.min(C.door.G * k, 1), math.min(C.door.B * k, 1))
		piece("Plank", st, w - st, y, y + ph, 0.03, t - 0.03, col)
	end
	-- the dark number plate on the corridor face, and the brass furniture on the latch side
	if number then
		local plate = piece("NumberPlate", w / 2 - 0.85, w / 2 + 0.85, h - 2.05, h - 1.2, t, t + 0.06, Color3.fromRGB(34, 36, 40), Enum.Material.Slate)
		local g, tl = textSign(plate, Enum.NormalId.Back, tostring(number), { color = Color3.fromRGB(236, 200, 120), pps = 80, light = 0.3 })
		tl.FontFace = SERIF
		piece("PlateEdge", w / 2 - 0.92, w / 2 + 0.92, h - 2.12, h - 1.13, t - 0.01, t + 0.04, C.gold, Enum.Material.Metal)
	end
	for _, side in ipairs({ 1, -1 }) do
		local z0 = side > 0 and t or -0.04
		local z1 = side > 0 and t + 0.04 or 0
		piece("Escutcheon", w - 0.62, w - 0.3, 2.9, 4.4, z0, z1, C.gold, Enum.Material.Metal)
		local kz = side > 0 and t + 0.22 or -0.22
		part(leaf, "Knob", Vector3.new(0.38, 0.38, 0.38), hinge * CFrame.new(w - 0.46, 3.55, kz) - OX, C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
		part(leaf, "Neck", Vector3.new(0.12, 0.12, 0.2), hinge * CFrame.new(w - 0.46, 3.55, side > 0 and t + 0.1 or -0.1) - OX, C.gold, Enum.Material.Metal)
	end
	for _, y in ipairs({ 1.0, h - 1.0 }) do
		part(leaf, "Hinge", Vector3.new(0.5, 0.16, 0.16), hinge * CFrame.new(-0.02, y, -0.02) * CFrame.Angles(0, 0, math.rad(90)) - OX, C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
end

local function swingDoor(parent, hingeCF, w, h, t, swing, number)
	local door = model(parent, "Door")
	local hinge = part(door, "Pivot", Vector3.new(0.2, 0.2, 0.2), hingeCF, C.gold, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	door.PrimaryPart = hinge
	local leaf = model(door, "Leaf")
	plankLeaf(leaf, hingeCF + OX, w, h, t, number)
	quiet(leaf)
	door:SetAttribute("Swing", swing)
	door:SetAttribute("NavOpen", true)
	CS:AddTag(door, "SwingDoor")
	return door
end

local function roomDoor(m, cx, number)
	local fr = model(m, "DoorFrame")
	local z0, z1 = -2.5, -1.5
	local xl, xr, top = cx - DOOR_HALF, cx + DOOR_HALF, FY + DOOR_H
	local lin = 0.12
	block(fr, "Jamb", Vector3.new(xl, FY, z0), Vector3.new(xl + lin, top, z1), C.woodDk, Enum.Material.Wood)
	block(fr, "Jamb", Vector3.new(xr - lin, FY, z0), Vector3.new(xr, top, z1), C.woodDk, Enum.Material.Wood)
	block(fr, "Head", Vector3.new(xl, top - lin, z0), Vector3.new(xr, top, z1), C.woodDk, Enum.Material.Wood)
	block(fr, "Stop", Vector3.new(xl + lin, top - lin - 0.08, z0 + 0.32), Vector3.new(xr - lin, top - lin, z0 + 0.42), C.woodDk, Enum.Material.Wood)
	for _, side in ipairs({ 1, -1 }) do
		local zf = side > 0 and z1 or z0
		local zo = zf + side * 0.3
		local cw = 0.55
		block(fr, "Casing", Vector3.new(xl - cw, FY + 0.75, zf), Vector3.new(xl, top + cw, zo), C.woodDk, Enum.Material.Wood)
		block(fr, "Casing", Vector3.new(xr, FY + 0.75, zf), Vector3.new(xr + cw, top + cw, zo), C.woodDk, Enum.Material.Wood)
		block(fr, "Casing", Vector3.new(xl - cw, top, zf), Vector3.new(xr + cw, top + cw, zo), C.woodDk, Enum.Material.Wood)
		block(fr, "Plinth", Vector3.new(xl - cw - 0.04, FY, zf), Vector3.new(xl + 0.02, FY + 0.75, zo + side * 0.06), C.woodDk, Enum.Material.Wood)
		block(fr, "Plinth", Vector3.new(xr - 0.02, FY, zf), Vector3.new(xr + cw + 0.04, FY + 0.75, zo + side * 0.06), C.woodDk, Enum.Material.Wood)
		if side > 0 then
			-- a small cornice over the corridor side
			block(fr, "Cornice", Vector3.new(xl - cw - 0.25, top + cw, zf), Vector3.new(xr + cw + 0.25, top + cw + 0.3, zf + 0.5), C.woodDk, Enum.Material.Wood)
			block(fr, "CorniceBead", Vector3.new(xl - cw - 0.3, top + cw + 0.3, zf), Vector3.new(xr + cw + 0.3, top + cw + 0.4, zf + 0.56), C.gold, Enum.Material.Metal)
			-- round 19: the status lamp is gone — RoomStatus hangs a "Please tidy" hanger on the door instead
		end
	end
	block(fr, "Threshold", Vector3.new(xl, FY - 0.02, z0), Vector3.new(xr, FY + 0.05, z1), C.gold, Enum.Material.Metal)
	-- the leaf: shut against the room face of the opening, hinge on the left (seen from the corridor), it
	-- swings +92 degrees into the room
	local t = 0.26
	local hingeCF = CFrame.new(xl + lin, FY + 0.03, z0 + 0.04)
	swingDoor(m, hingeCF, (xr - lin) - (xl + lin), DOOR_H - lin - 0.06, t, 92, number)
	return fr
end

-- a room's front wall: either side of its doorway, and the lintel over it (panelled on the lobby face)
local FRONTS = { { Vector2.new(0, 1), "lobby" }, { Vector2.new(0, -1), "room" } }
local function roomFront(parent, id, cx, xa, xb)
	xa, xb = math.min(xa, xb), math.max(xa, xb)
	wall(parent, "Front" .. id .. "L", Vector2.new(xa, -2.5), Vector2.new(cx - DOOR_HALF, -1.5), nil, FRONTS, { lift = 0.02 })
	wall(parent, "Front" .. id .. "R", Vector2.new(cx + DOOR_HALF, -2.5), Vector2.new(xb, -1.5), nil, FRONTS, { lift = 0.02 })
	wall(parent, "Lintel" .. id, Vector2.new(cx - DOOR_HALF, -2.5), Vector2.new(cx + DOOR_HALF, -1.5), nil, FRONTS, { y0 = FY + DOOR_H })
end

-- the corridor runner in front of the rooms (z 0..4), brass edged; each wing adds its own stretch
local HALL_END = 32.75
local function hallCarpet(parent, xa, xb)
	local lo, hi = math.min(xa, xb), math.max(xa, xb)
	tex(block(parent, "CarpetHall", Vector3.new(lo, FY, 0), Vector3.new(hi, FY + 0.08, 4), Color3.fromRGB(255, 255, 255)), "Carpet")
	for _, z in ipairs({ 3.85, 0.15 }) do
		block(parent, "CarpetEdge", Vector3.new(lo, FY + 0.05, z - 0.15), Vector3.new(hi, FY + 0.1, z + 0.15), C.gold, Enum.Material.Metal)
	end
end

-- the bathroom half wall, tiled
local function partition(m, cx)
	local p = tex(block(m, "Partition", Vector3.new(cx + 5.2, FY, -29), Vector3.new(cx + 5.8, FY + 8, -21), Color3.fromRGB(255, 255, 255)), "Hex")
	block(m, "PartitionCap", Vector3.new(cx + 5.1, FY + 8, -29), Vector3.new(cx + 5.9, FY + 8.3, -20.9), Color3.fromRGB(240, 236, 228), Enum.Material.Marble)
	return p
end

-- bare = true: an empty shell (walls, floor, nav + clean spots) with no furniture at all;
-- the player furnishes it in build mode and it opens for guests once it has a bed, shower and toilet
local function buildRoom(hotel, r, bare)
	local cx = r.cx
	local m = model(hotel.Rooms, "Room" .. r.id)
	m:SetAttribute("RoomId", r.id)
	m:SetAttribute("State", bare and "Unfurnished" or "Ready")
	local x0, x1 = cx - 12.5, cx + 12.5
	-- floors: oak chevron for the bedroom (it runs under the walls), white hex tile for the bathroom corner
	tex(block(m, "Floor", Vector3.new(cx - 13.25, FY - 0.4, -29.5), Vector3.new(cx + 13.25, FY, -2.5), Color3.fromRGB(255, 255, 255)), "Chevron")
	tex(block(m, "BathFloor", Vector3.new(cx + 5.5, FY - 0.35, -29.5), Vector3.new(cx + 12.75, FY + 0.06, -14), Color3.fromRGB(255, 255, 255)), "Hex")
	partition(m, cx)
	roomDoor(m, cx, r.id)
	-- props (skipped for a bare room: the player buys the furniture themselves)
	if not bare then
		local props = model(m, "Props")
		place("Bed", props, CFrame.new(cx - 4, FY, -24.25))
		local messy = place("BedMessy", props, CFrame.new(cx - 4, FY, -24.25))
		messy:SetAttribute("DirtyOnly", true)
		place("Nightstand", props, CFrame.new(cx - 9.3, FY, -27.6))
		place("Shower", props, CFrame.new(x1 - 2.6, FY + 0.06, -26.4))
		place("Toilet", props, CFrame.new(x1 - 1.9, FY + 0.06, -17.5) * CFrame.Angles(0, math.rad(-90), 0))
		place("Rug", props, CFrame.new(cx - 4, FY + 0.01, -15.5))
		place("FloorLamp", props, CFrame.new(x0 + 1.6, FY, -12.5))
		place("Plant", props, CFrame.new(x0 + 2.4, FY, -5.5) * CFrame.Angles(0, math.rad(40), 0))
		painting(props, CFrame.new(cx - 4, FY + 9.4, -29.45) * CFrame.Angles(0, math.pi, 0), 6, 3.2,
			Color3.fromRGB(255, 196, 160), Color3.fromRGB(250, 160, 140), Color3.fromRGB(200, 140, 170))
	end
	-- mess shown only when the room is dirty
	local mess = model(m, "Mess")
	mess:SetAttribute("DirtyOnly", true)
	place("Towel", mess, CFrame.new(cx + 8.5, FY + 0.07, -21.5) * CFrame.Angles(0, 0.6, 0))
	place("Trash", mess, CFrame.new(cx - 9.5, FY, -18) * CFrame.Angles(0, 1.2, 0))
	place("Trash", mess, CFrame.new(cx + 1.5, FY, -12) * CFrame.Angles(0, -0.4, 0))
	-- nav spots
	local nav = folder(m, "Nav")
	spot(nav, "Door", CFrame.new(cx, FY + 3, 1.5))
	spot(nav, "Enter", CFrame.new(cx, FY + 3, -7))
	spot(nav, "BedSide", CFrame.new(cx + 0.4, FY + 3, -22.5), { Look = Vector3.new(cx - 4, FY + 3, -22.5) })
	-- lying: face up, head toward the headboard (-Z); BedLie is the HumanoidRootPart CFrame
	spot(nav, "BedLie", CFrame.fromMatrix(Vector3.new(cx - 4, FY + 3.3, -24.6), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)))
	spot(nav, "ShowerIn", CFrame.new(x1 - 2.8, FY + 3.4, -26.2), { Look = Vector3.new(x1 - 2.8, FY + 3.4, -20) })
	spot(nav, "ShowerFront", CFrame.new(x1 - 2.6, FY + 3, -20.5))
	spot(nav, "ToiletFront", CFrame.new(x1 - 5.6, FY + 3, -17.5))
	-- seat: HRP faces -X (away from the wall)
	spot(nav, "ToiletSit", CFrame.lookAt(Vector3.new(x1 - 2.25, FY + 2.55, -17.5), Vector3.new(x1 - 10, FY + 2.55, -17.5)))
	spot(nav, "Wander", CFrame.new(cx - 4, FY + 3, -11), { Look = Vector3.new(cx - 4, FY + 3, -20) })
	-- clean spots carry the prompts (made by the server)
	local clean = folder(m, "CleanSpots")
	spot(clean, "Bed", CFrame.new(cx - 4, FY + 3.2, -20.5), { Task = "Bed", Label = "Make the bed" })
	spot(clean, "Shower", CFrame.new(x1 - 2.6, FY + 3.2, -23.4), { Task = "Shower", Label = "Scrub the shower" })
	spot(clean, "Toilet", CFrame.new(x1 - 3.9, FY + 2.6, -17.5), { Task = "Toilet", Label = "Clean the toilet" })
	spot(clean, "Floor", CFrame.new(cx - 2, FY + 1.5, -12), { Task = "Floor", Label = "Pick up trash" })
	return m
end

-- Edit-time: give an existing room the round 10 floors, partition and door (keeps its furniture and spots)
function B.refitRoom(room)
	local f = room:FindFirstChild("Floor")
	if not f then return end
	local cx = f.Position.X - OX.X
	for _, n in ipairs({ "DoorFrame", "Door", "Partition", "PartitionCap" }) do
		local o = room:FindFirstChild(n)
		while o do o:Destroy(); o = room:FindFirstChild(n) end
	end
	f.Color = Color3.fromRGB(255, 255, 255)
	f.Size = Vector3.new(26.5, 0.4, 27)
	f.CFrame = CFrame.new(cx, FY - 0.2, -16) + OX
	tex(f, "Chevron")
	local bf = room:FindFirstChild("BathFloor")
	if bf then
		bf.Color = Color3.fromRGB(255, 255, 255)
		bf.Size = Vector3.new(7.25, 0.41, 15.5)
		bf.CFrame = CFrame.new(cx + 9.125, FY - 0.145, -21.75) + OX
		tex(bf, "Hex")
	end
	partition(room, cx)
	roomDoor(room, cx, room:GetAttribute("RoomId"))
	-- round 10b: the wet-floor board is gone (the door's status lamp says a room needs cleaning)
	local mess = room:FindFirstChild("Mess")
	local board = mess and mess:FindFirstChild("NeedCleaning")
	if board then board:Destroy() end
end

---------------------------------------------------------------- lobby + shell

-- a downlight disc (flat cylinder) facing down; opts.night = a night-only fixture (tagged NightLight)
local function downlight(parent, pos, dia, opts)
	opts = opts or {}
	local m = model(parent, opts.name or "Downlight")
	part(m, "Trim", Vector3.new(0.08, dia + 0.35, dia + 0.35), CFrame.new(pos + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), opts.trim or C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local lens = part(m, "Lens", Vector3.new(0.1, dia, dia), CFrame.new(pos - Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Transparency = 0.15, CastShadow = false })
	if opts.night then
		lens.Material = Enum.Material.SmoothPlastic
		lens.Color = Color3.fromRGB(236, 232, 222)
		lens:SetAttribute("LitColor", C.warm)
		CS:AddTag(m, "NightLight")
	end
	if opts.light then
		local l = Instance.new(opts.light.class or "PointLight")
		l.Color = C.warm
		l.Range = opts.light.range or 14
		l.Brightness = opts.light.brightness or 0.7
		l.Shadows = opts.light.shadows or false
		if l:IsA("SpotLight") then l.Face = Enum.NormalId.Left; l.Angle = opts.light.angle or 80 end
		l.Parent = lens
	end
	return quiet(m)
end

local function buildShell(hotel)
	local sh = model(hotel, "Shell")
	block(sh, "Plinth", Vector3.new(-41.5, -1, -31.5), Vector3.new(41.5, FY - 0.4, 31.5), C.lime, Enum.Material.Limestone)
	tex(block(sh, "LobbyFloor", Vector3.new(-40.5, FY - 0.4, -2.5), Vector3.new(40.5, FY, 30), Color3.fromRGB(255, 255, 255)), "Checker")
	-- the teal runner: door to the room corridor, then along it, brass edged (wings carry it on)
	tex(block(sh, "Carpet", Vector3.new(-4, FY, 4), Vector3.new(4, FY + 0.08, 33), Color3.fromRGB(255, 255, 255)), "Carpet")
	hallCarpet(sh, -HALL_END, HALL_END)
	for _, x in ipairs({ -3.85, 3.85 }) do
		block(sh, "CarpetEdge", Vector3.new(x - 0.15, FY + 0.05, 4), Vector3.new(x + 0.15, FY + 0.1, 33), C.gold, Enum.Material.Metal)
	end
	-- perimeter walls: brick and limestone outside, wallpaper over emerald panelling in the lobby
	wall(sh, "WallBack", Vector2.new(-40.5, -30.5), Vector2.new(40.5, -29.5), Vector2.new(0, -1), { { Vector2.new(0, 1), "room" } }, { ext = { 0.3, 0.3 } })
	sideWall(sh, "WallLeft", -39.5, -1, PAL_B)
	sideWall(sh, "WallRight", 39.5, 1, PAL_A)
	-- room dividers + room front walls with doorways
	for _, x in ipairs({ -13.25, 13.25 }) do
		wall(sh, "Divider", Vector2.new(x - 0.5, -29.5), Vector2.new(x + 0.5, -2.5))
	end
	for _, r in ipairs(ROOMS) do
		roomFront(sh, r.id, r.cx, math.max(r.cx - 13.25, -39.5), math.min(r.cx + 13.25, 39.5))
	end
	-- the street front: two runs of windows either side of the door; the door's sliding leaves
	-- slide into the wide piers beside it
	frontRun(sh, -40.8, -5, { wb = 5 })
	frontRun(sh, 5, 40.8, { wa = 5 })
	local dh = model(sh, "DoorHead")
	block(dh, "Band", Vector3.new(-5, BAND0, ZO), Vector3.new(5, BAND1, ZO + 0.4), C.lime, Enum.Material.Limestone)
	tex(block(dh, "Header", Vector3.new(-5, BAND0, ZG), Vector3.new(5, FY + WALL_H + 0.5, ZO), C.brick), "Brick")
	tex(block(dh, "HeaderIn", Vector3.new(-5, BAND0, ZI), Vector3.new(5, FY + WALL_H + 0.5, ZG), C.paper, Enum.Material.Plaster), "Paper")
	block(dh, "Crown", Vector3.new(-5, CEIL - 0.45, ZI - 0.32), Vector3.new(5, CEIL, ZI), C.trim, Enum.Material.Plaster)
	block(dh, "Crown", Vector3.new(-5, CEIL - 0.8, ZI - 0.16), Vector3.new(5, CEIL - 0.45, ZI), C.trim, Enum.Material.Plaster)
	steelWindow(dh, -5, 5, FY + 9.6, BAND0, { cols = 3 })
	block(dh, "Threshold", Vector3.new(-5, FY - 0.4, 29.6), Vector3.new(5, FY + 0.02, 31.2), C.gold, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		block(dh, "Surround", Vector3.new(sx * 5, FY + 2.3, ZO), Vector3.new(sx * 5.6, BAND0, ZO + 0.3), C.lime, Enum.Material.Limestone)
		block(dh, "DoorPost", Vector3.new(sx * 5 - sx * 0.25, FY, 30.0), Vector3.new(sx * 5, FY + 9.6, 30.6), C.gold, Enum.Material.Metal)
		lantern(dh, sx * 7.8, FY + 7.2)
	end
	block(dh, "DoorHeadBar", Vector3.new(-5, FY + 9.6, 30.0), Vector3.new(5, FY + 9.85, 30.6), C.gold, Enum.Material.Metal)
	awning(sh, 7.4)
	-- sliding doors in brass frames (the server slides them open for anyone near)
	local doors = model(hotel, "Doors")
	local z = 30.3
	for _, sx in ipairs({ -1, 1 }) do
		local d = model(doors, sx < 0 and "DoorL" or "DoorR")
		local cfx = sx * 2.5
		local fr = block(d, "Frame", Vector3.new(cfx - 2.5, FY, z - 0.15), Vector3.new(cfx + 2.5, FY + 9.6, z + 0.15), C.gold, Enum.Material.Metal)
		block(d, "Pane", Vector3.new(cfx - 2.2, FY + 0.5, z - 0.06), Vector3.new(cfx + 2.2, FY + 9.3, z + 0.06), C.glass, Enum.Material.Glass, { Transparency = 0.5, Reflectance = 0.2, CanCollide = false })
		fr.Transparency = 1
		fr.CanCollide = true
		block(d, "Handle", Vector3.new(cfx - sx * 1.9 - 0.1, FY + 2.6, z - 0.4), Vector3.new(cfx - sx * 1.9 + 0.1, FY + 6.8, z + 0.4), C.gold, Enum.Material.Metal)
		for _, e in ipairs({ { -2.5, -2.2 }, { 2.2, 2.5 } }) do
			block(d, "Edge", Vector3.new(cfx + e[1], FY, z - 0.12), Vector3.new(cfx + e[2], FY + 9.6, z + 0.12), C.gold, Enum.Material.Metal)
		end
		block(d, "Rail", Vector3.new(cfx - 2.5, FY, z - 0.12), Vector3.new(cfx + 2.5, FY + 0.5, z + 0.12), C.gold, Enum.Material.Metal)
		block(d, "Rail", Vector3.new(cfx - 2.5, FY + 9.3, z - 0.12), Vector3.new(cfx + 2.5, FY + 9.6, z + 0.12), C.gold, Enum.Material.Metal)
		block(d, "Kick", Vector3.new(cfx - 2.2, FY + 0.5, z - 0.08), Vector3.new(cfx + 2.2, FY + 1.3, z + 0.08), C.gold, Enum.Material.Metal)
		d:SetAttribute("Closed", d:GetPivot())
		d:SetAttribute("Side", sx)
		d.PrimaryPart = fr
	end
	-- round 11: the hotel's name sits on the roof now (B.roof -> marquee)
end

-- a globe pendant hanging from the ceiling at (x, z), bottom at y
local function pendant(parent, x, z, y, r)
	local m = model(parent, "Pendant")
	local top = CEIL
	part(m, "Rose", Vector3.new(0.15, 0.7, 0.7), CFrame.new(x, top - 0.08, z) * CFrame.Angles(0, 0, math.rad(90)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Cord", Vector3.new(top - y - r * 2, 0.06, 0.06), CFrame.new(x, (top + y + r * 2) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), C.frame, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part(m, "Cap", Vector3.new(0.35, 0.5, 0.5), CFrame.new(x, y + r * 2 - 0.05, z) * CFrame.Angles(0, 0, math.rad(90)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Globe", Vector3.new(r * 2, r * 2, r * 2), CFrame.new(x, y + r, z), Color3.fromRGB(255, 240, 220), Enum.Material.Glass, { Shape = Enum.PartType.Ball, Transparency = 0.3, CastShadow = false })
	local core = part(m, "Core", Vector3.new(r, r, r), CFrame.new(x, y + r, z), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CastShadow = false })
	local l = Instance.new("PointLight")
	l.Color = C.warm; l.Range = 12; l.Brightness = 0.7
	l.Parent = core
	return quiet(m)
end

-- a two-tier brass chandelier with candle bulbs and hanging crystals
local function chandelier(parent, x, z)
	local m = model(parent, "Chandelier")
	local top = CEIL
	local y = top - 3.2
	part(m, "Rose", Vector3.new(0.2, 1.4, 1.4), CFrame.new(x, top - 0.1, z) * CFrame.Angles(0, 0, math.rad(90)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Rod", Vector3.new(top - y, 0.14, 0.14), CFrame.new(x, (top + y) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Hub", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, y, z), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	local function ring(rad, yy, n, thick)
		for i = 0, n - 1 do
			local a0, a1 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
			local p0 = Vector3.new(x + math.cos(a0) * rad, yy, z + math.sin(a0) * rad)
			local p1 = Vector3.new(x + math.cos(a1) * rad, yy, z + math.sin(a1) * rad)
			part(m, "Ring", Vector3.new(thick, thick, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), C.gold, Enum.Material.Metal)
		end
	end
	ring(2.9, y, 22, 0.16)
	ring(1.7, y + 1.1, 16, 0.12)
	ring(1.5, y - 0.7, 14, 0.1)
	for tier, spec in ipairs({ { 2.9, y, 8 }, { 1.7, y + 1.1, 6 } }) do
		local rad, yy, n = spec[1], spec[2], spec[3]
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2 + tier * 0.3
			local p = Vector3.new(x + math.cos(a) * rad, yy, z + math.sin(a) * rad)
			part(m, "Spoke", Vector3.new(0.1, 0.1, rad), CFrame.lookAt(Vector3.new(x, yy, z):Lerp(p, 0.5), p), C.gold, Enum.Material.Metal)
			part(m, "Cup", Vector3.new(0.18, 0.42, 0.42), CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			part(m, "Candle", Vector3.new(0.6, 0.22, 0.22), CFrame.new(p + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 246, 238), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
			part(m, "Flame", Vector3.new(0.26, 0.26, 0.26), CFrame.new(p + Vector3.new(0, 0.92, 0)), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Ball, CastShadow = false })
		end
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local q = Vector3.new(x + math.cos(a) * 1.5, y - 0.7, z + math.sin(a) * 1.5)
		part(m, "Crystal", Vector3.new(0.12, 0.42, 0.12), CFrame.new(q - Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, a, 0), Color3.fromRGB(236, 246, 255), Enum.Material.Glass, { Transparency = 0.45, Reflectance = 0.35, CastShadow = false })
	end
	part(m, "Drop", Vector3.new(0.4, 0.9, 0.4), CFrame.new(x, y - 0.9, z) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(240, 248, 255), Enum.Material.Glass, { Transparency = 0.2, Reflectance = 0.3, CastShadow = false })
	local l = Instance.new("PointLight")
	l.Color = C.warm; l.Range = 24; l.Brightness = 1; l.Shadows = true
	l.Parent = m.Hub
	return quiet(m)
end

---------------------------------------------------------------- the reception desk (round 10b)
-- One station for one receptionist: a walnut desk with an emerald front and a marble ledge for the guests,
-- one monitor, a keyboard, a banker's lamp, a bell and an office chair. Pivot at floor centre, guests on +Z.
-- SeatSpot is the HumanoidRootPart CFrame for the receptionist sitting in the chair (HotelSim).
local function monitorScreen(screen)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.CanvasSize = Vector2.new(390, 225)
	g.LightInfluence = 0
	g.Brightness = 1.6
	g.Parent = screen
	local function fr(parent, pos, size, col, r)
		local f = Instance.new("Frame")
		f.Position = pos
		f.Size = size
		f.BackgroundColor3 = col
		f.BorderSizePixel = 0
		f.Parent = parent
		if r then Instance.new("UICorner", f).CornerRadius = UDim.new(0, r) end
		return f
	end
	local bg = fr(g, UDim2.new(), UDim2.fromScale(1, 1), Color3.fromRGB(18, 24, 44))
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 190))
	gr.Rotation = 90
	gr.Parent = bg
	local head = fr(bg, UDim2.new(), UDim2.new(1, 0, 0, 34), Color3.fromRGB(30, 40, 70))
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(12, 0)
	t.Size = UDim2.new(1, -24, 1, 0)
	t.Text = "OVERBOOKED  |  FRONT DESK"
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = Color3.fromRGB(236, 200, 120)
	t.TextSize = 16
	t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	t.Parent = head
	-- a booking grid: rooms down, nights across
	local cols = { Color3.fromRGB(90, 200, 140), Color3.fromRGB(240, 190, 90), Color3.fromRGB(110, 160, 250), Color3.fromRGB(230, 110, 120) }
	for r = 0, 4 do
		fr(bg, UDim2.fromOffset(12, 46 + r * 34), UDim2.fromOffset(46, 24), Color3.fromRGB(40, 52, 86), 5)
		for c = 0, 6 do
			if (r * 7 + c * 3) % 5 ~= 0 then
				fr(bg, UDim2.fromOffset(66 + c * 44, 48 + r * 34), UDim2.fromOffset(40, 20), cols[(r + c) % 4 + 1], 5).BackgroundTransparency = 0.15
			end
		end
	end
end

function B.receptionDesk()
	useOrigin(nil)
	local m = model(nil, "Desk")
	local W2, D0, D1, TOP = 3.0, -1.2, 1.0, 2.85
	local metal, wood, gold = Enum.Material.Metal, Enum.Material.Wood, C.gold
	local dark = Color3.fromRGB(32, 34, 40)
	local marble = Color3.fromRGB(240, 236, 228)
	local body = model(m, "Body")
	-- the carcass: top, sides and a drawer pedestal on the receptionist's side
	block(body, "Top", Vector3.new(-W2 - 0.1, TOP, D0 - 0.1), Vector3.new(W2 + 0.1, TOP + 0.18, D1 + 0.05), C.woodDk, wood)
	block(body, "TopEdge", Vector3.new(-W2 - 0.12, TOP + 0.05, D0 - 0.13), Vector3.new(W2 + 0.12, TOP + 0.12, D0 - 0.09), gold, metal)
	for _, sx in ipairs({ -1, 1 }) do
		block(body, "Side", Vector3.new(sx * (W2 - 0.2), 0, D0 - 0.05), Vector3.new(sx * W2, TOP, D1), C.woodDk, wood)
	end
	block(body, "Pedestal", Vector3.new(-W2 + 0.2, 0.1, D0 + 0.05), Vector3.new(-1.45, TOP, D1), C.woodDk, wood)
	for i = 0, 2 do
		local yb = 0.24 + i * 0.86
		block(body, "Drawer", Vector3.new(-W2 + 0.28, yb, D0 - 0.02), Vector3.new(-1.53, yb + 0.76, D0 + 0.05), Color3.fromRGB(104, 68, 44), wood)
		block(body, "Pull", Vector3.new(-2.45, yb + 0.34, D0 - 0.1), Vector3.new(-1.95, yb + 0.43, D0 - 0.02), gold, metal)
	end
	-- the guest face: a raised walnut front with an emerald inset, a brass frame and the word RECEPTION in gilt
	local FZ0, FZ1, FH = D1, D1 + 0.22, 3.55
	block(body, "Front", Vector3.new(-W2 - 0.1, 0, FZ0), Vector3.new(W2 + 0.1, FH, FZ1), C.woodDk, wood)
	block(body, "Plinth", Vector3.new(-W2 - 0.16, 0, FZ0 - 0.05), Vector3.new(W2 + 0.16, 0.35, FZ1 + 0.08), Color3.fromRGB(28, 30, 34), Enum.Material.Marble)
	local x0, x1, y0, y1 = -W2 + 0.35, W2 - 0.35, 0.65, FH - 0.45
	block(body, "Inset", Vector3.new(x0, y0, FZ1), Vector3.new(x1, y1, FZ1 + 0.04), C.panel, Enum.Material.SmoothPlastic)
	local function bar(a, b2) block(body, "Brass", a, b2, gold, metal) end
	bar(Vector3.new(x0 - 0.07, y0 - 0.07, FZ1), Vector3.new(x1 + 0.07, y0, FZ1 + 0.08))
	bar(Vector3.new(x0 - 0.07, y1, FZ1), Vector3.new(x1 + 0.07, y1 + 0.07, FZ1 + 0.08))
	bar(Vector3.new(x0 - 0.07, y0, FZ1), Vector3.new(x0, y1, FZ1 + 0.08))
	bar(Vector3.new(x1, y0, FZ1), Vector3.new(x1 + 0.07, y1, FZ1 + 0.08))
	local word = block(body, "Word", Vector3.new(x0 + 0.3, 1.55, FZ1 + 0.04), Vector3.new(x1 - 0.3, 2.35, FZ1 + 0.05), C.panel, Enum.Material.SmoothPlastic, { Transparency = 1 })
	local _, tl = textSign(word, Enum.NormalId.Back, "RECEPTION", { color = Color3.fromRGB(236, 200, 120), pps = 60, light = 0.5 })
	tl.FontFace = SERIF
	-- the marble ledge guests lean on, with a brass bead under its edge
	block(body, "Ledge", Vector3.new(-W2 - 0.22, FH, FZ0 - 0.3), Vector3.new(W2 + 0.22, FH + 0.14, FZ1 + 0.42), marble, Enum.Material.Marble)
	block(body, "LedgeBead", Vector3.new(-W2 - 0.18, FH - 0.08, FZ1 + 0.3), Vector3.new(W2 + 0.18, FH, FZ1 + 0.38), gold, metal)
	-- on the desk: one monitor (its screen faces the receptionist), a keyboard and mouse, a banker's lamp,
	-- a letter tray and a pen cup
	local kit = model(m, "Kit")
	local dy = TOP + 0.18
	local mx, mz = 0.3, 0.1
	part(kit, "MonitorFoot", Vector3.new(0.06, 0.95, 0.95), CFrame.new(mx, dy + 0.03, mz) * CFrame.Angles(0, 0, math.rad(90)), dark, metal, { Shape = Enum.PartType.Cylinder })
	block(kit, "MonitorNeck", Vector3.new(mx - 0.08, dy, mz + 0.06), Vector3.new(mx + 0.08, dy + 0.9, mz + 0.2), dark, metal)
	local scy = dy + 0.9 + 0.52
	part(kit, "Monitor", Vector3.new(2.15, 1.32, 0.12), CFrame.new(mx, scy, mz), Color3.fromRGB(22, 24, 28), Enum.Material.SmoothPlastic)
	local screen = part(kit, "Screen", Vector3.new(2.0, 1.15, 0.02), CFrame.new(mx, scy + 0.03, mz - 0.07), Color3.fromRGB(30, 40, 70), Enum.Material.SmoothPlastic)
	monitorScreen(screen)
	block(kit, "Keyboard", Vector3.new(mx - 0.85, dy, -0.95), Vector3.new(mx + 0.65, dy + 0.07, -0.47), dark, Enum.Material.SmoothPlastic)
	for r = 0, 2 do
		block(kit, "Keys", Vector3.new(mx - 0.78, dy + 0.07, -0.88 + r * 0.14), Vector3.new(mx + 0.58, dy + 0.1, -0.8 + r * 0.14), Color3.fromRGB(200, 204, 214), Enum.Material.SmoothPlastic)
	end
	block(kit, "Mouse", Vector3.new(mx + 0.95, dy, -0.85), Vector3.new(mx + 1.2, dy + 0.1, -0.5), dark, Enum.Material.SmoothPlastic)
	-- banker's lamp: brass foot and stem, an emerald glass shade, warm light pooled on the desk
	local lx, lz = -2.1, -0.15
	part(kit, "LampFoot", Vector3.new(0.08, 0.62, 0.62), CFrame.new(lx, dy + 0.04, lz) * CFrame.Angles(0, 0, math.rad(90)), gold, metal, { Shape = Enum.PartType.Cylinder })
	block(kit, "LampStem", Vector3.new(lx - 0.04, dy, lz - 0.04), Vector3.new(lx + 0.04, dy + 1.0, lz + 0.04), gold, metal)
	part(kit, "LampShade", Vector3.new(1.05, 0.4, 0.4), CFrame.new(lx, dy + 1.1, lz - 0.1), Color3.fromRGB(30, 120, 80), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.15 })
	local bulb = part(kit, "LampBulb", Vector3.new(0.8, 0.18, 0.18), CFrame.new(lx, dy + 1.0, lz - 0.1), C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder })
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Color = C.warm; sl.Range = 7; sl.Brightness = 1.4; sl.Angle = 110
	sl.Parent = bulb
	block(kit, "Tray", Vector3.new(1.75, dy, -0.75), Vector3.new(2.65, dy + 0.12, -0.05), C.woodDk, wood)
	block(kit, "Papers", Vector3.new(1.82, dy + 0.04, -0.68), Vector3.new(2.58, dy + 0.16, -0.12), Color3.fromRGB(248, 246, 240), Enum.Material.SmoothPlastic)
	part(kit, "PenCup", Vector3.new(0.45, 0.3, 0.3), CFrame.new(2.3, dy + 0.22, 0.45) * CFrame.Angles(0, 0, math.rad(90)), gold, metal, { Shape = Enum.PartType.Cylinder })
	for i, c in ipairs({ Color3.fromRGB(30, 30, 34), Color3.fromRGB(200, 60, 60), Color3.fromRGB(40, 90, 200) }) do
		part(kit, "Pen", Vector3.new(0.05, 0.62, 0.05), CFrame.new(2.3 + (i - 2) * 0.07, dy + 0.5, 0.45 + (i % 2) * 0.05) * CFrame.Angles(0, 0, math.rad((i - 2) * 8)), c, Enum.Material.SmoothPlastic)
	end
	-- on the ledge: the service bell and a brochure stand
	local ly = FH + 0.14
	part(kit, "BellBase", Vector3.new(0.06, 0.5, 0.5), CFrame.new(-1.9, ly + 0.03, FZ1 + 0.12) * CFrame.Angles(0, 0, math.rad(90)), C.woodDk, wood, { Shape = Enum.PartType.Cylinder })
	part(kit, "Bell", Vector3.new(0.36, 0.36, 0.36), CFrame.new(-1.9, ly + 0.06, FZ1 + 0.12), gold, metal, { Shape = Enum.PartType.Ball, Reflectance = 0.15 })
	part(kit, "BellButton", Vector3.new(0.06, 0.08, 0.08), CFrame.new(-1.9, ly + 0.27, FZ1 + 0.12) * CFrame.Angles(0, 0, math.rad(90)), gold, metal, { Shape = Enum.PartType.Cylinder })
	block(kit, "BrochureStand", Vector3.new(1.6, ly, FZ1 - 0.05), Vector3.new(2.5, ly + 0.08, FZ1 + 0.3), Color3.fromRGB(220, 230, 236), Enum.Material.Glass, { Transparency = 0.4 })
	for i, c in ipairs({ Color3.fromRGB(230, 120, 90), Color3.fromRGB(80, 160, 200), Color3.fromRGB(240, 200, 90) }) do
		local bx0 = 1.62 + (i - 1) * 0.3
		part(kit, "Brochure", Vector3.new(0.26, 0.5, 0.04), CFrame.new(bx0 + 0.13, ly + 0.3, FZ1 + 0.12) * CFrame.Angles(math.rad(-14), 0, 0), c, Enum.Material.SmoothPlastic)
	end
	-- the chair: five spokes on casters, a gas lift, a leather seat and back, armrests
	local ch = model(m, "Chair")
	local cz = -2.15
	local chrome = Color3.fromRGB(170, 174, 182)
	local leather = Color3.fromRGB(46, 40, 38)
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5 + 0.3
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local hub = Vector3.new(0, 0.36, cz)
		local tip = hub + dir * 0.85
		part(ch, "Spoke", Vector3.new(0.14, 0.1, 0.86), CFrame.lookAt((hub + tip) / 2, tip) * CFrame.Angles(math.rad(6), 0, 0), dark, metal)
		part(ch, "Caster", Vector3.new(0.14, 0.24, 0.24), CFrame.new(tip.X, 0.12, tip.Z) * CFrame.Angles(0, a, 0), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	end
	part(ch, "Lift", Vector3.new(1.05, 0.17, 0.17), CFrame.new(0, 0.9, cz) * CFrame.Angles(0, 0, math.rad(90)), chrome, metal, { Shape = Enum.PartType.Cylinder })
	block(ch, "SeatPan", Vector3.new(-0.72, 1.38, cz - 0.7), Vector3.new(0.72, 1.46, cz + 0.7), dark, metal)
	block(ch, "Seat", Vector3.new(-0.85, 1.46, cz - 0.8), Vector3.new(0.85, 1.74, cz + 0.8), leather, Enum.Material.Leather)
	block(ch, "SeatRoll", Vector3.new(-0.85, 1.5, cz + 0.72), Vector3.new(0.85, 1.76, cz + 0.86), leather, Enum.Material.Leather)
	block(ch, "Spine", Vector3.new(-0.12, 1.4, cz - 1.0), Vector3.new(0.12, 2.3, cz - 0.86), dark, metal)
	part(ch, "Back", Vector3.new(1.62, 1.85, 0.3), CFrame.new(0, 3.0, cz - 0.98) * CFrame.Angles(math.rad(-8), 0, 0), leather, Enum.Material.Leather)
	part(ch, "BackTop", Vector3.new(1.62, 0.2, 0.36), CFrame.new(0, 3.93, cz - 1.1) * CFrame.Angles(math.rad(-8), 0, 0), leather, Enum.Material.Leather)
	for _, sx in ipairs({ -1, 1 }) do
		block(ch, "ArmPost", Vector3.new(sx * 0.86, 1.46, cz - 0.2), Vector3.new(sx * 0.96, 2.25, cz - 0.08), dark, metal)
		block(ch, "Arm", Vector3.new(sx * 0.8, 2.25, cz - 0.5), Vector3.new(sx * 1.0, 2.37, cz + 0.4), Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
	end
	local seat = spot(m, "SeatSpot", CFrame.lookAt(Vector3.new(0, 2.62, cz + 0.12), Vector3.new(0, 2.62, cz + 10)))
	seat.Size = Vector3.new(0.4, 0.4, 0.4)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if not d:IsDescendantOf(body) then d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
		end
	end
	m.WorldPivot = CFrame.new()
	return m
end

-- put the new desk in the prop and catalogue templates (both pivot at floor centre)
function B.deskProp()
	local d = B.receptionDesk()
	local props = game.ServerStorage.HotelProps
	if props:FindFirstChild("Desk") then props.Desk:Destroy() end
	d.Parent = props
	local items = game.ReplicatedStorage.Shared.Items
	if items:FindFirstChild("Desk") then items.Desk:Destroy() end
	d:Clone().Parent = items
	return d
end

-- the hotel safe beside the reception desk: a steel vault with its door swung open. HotelSim stacks
-- CashBundles on the safe's floor (Lobby.CashPile) and puts the Collect prompt on the open door
-- (Lobby.CashStand), so the money is always on show through the doorway.
local function cashSafe(lb, x, z)
	local m = model(lb, "CashSafe")
	local metal = Enum.Material.Metal
	local steel = Color3.fromRGB(70, 74, 80)
	local steelDk = Color3.fromRGB(50, 54, 60)
	local y0 = FY -- floor top
	local H, wall, w, d = 5.4, 0.4, 4.4, 3.8 -- body height, wall thickness, width (x), depth (z)
	-- shell: plinth, back, sides and top; the front (+z, toward the entrance) stays open as the doorway
	block(m, "Plinth", Vector3.new(x - w / 2 - 0.15, y0 - 0.3, z - d / 2 - 0.15), Vector3.new(x + w / 2 + 0.15, y0 + 0.4, z + d / 2 + 0.15), steelDk, metal)
	block(m, "Back", Vector3.new(x - w / 2, y0, z - d / 2), Vector3.new(x + w / 2, y0 + H, z - d / 2 + wall), steel, metal)
	block(m, "Side", Vector3.new(x - w / 2, y0, z - d / 2), Vector3.new(x - w / 2 + wall, y0 + H, z + d / 2), steel, metal)
	block(m, "Side", Vector3.new(x + w / 2 - wall, y0, z - d / 2), Vector3.new(x + w / 2, y0 + H, z + d / 2), steel, metal)
	block(m, "Top", Vector3.new(x - w / 2 - 0.15, y0 + H, z - d / 2 - 0.15), Vector3.new(x + w / 2 + 0.15, y0 + H + 0.45, z + d / 2 + 0.15), steelDk, metal)
	-- gold bands wrap the body; emerald velvet lines the inside of the back wall
	block(m, "Band", Vector3.new(x - w / 2 - 0.08, y0 + 0.4, z - d / 2 - 0.08), Vector3.new(x + w / 2 + 0.08, y0 + 0.62, z + d / 2 + 0.08), C.gold, metal)
	block(m, "Band", Vector3.new(x - w / 2 - 0.08, y0 + H - 0.62, z - d / 2 - 0.08), Vector3.new(x + w / 2 + 0.08, y0 + H - 0.4, z + d / 2 + 0.08), C.gold, metal)
	block(m, "Velvet", Vector3.new(x - w / 2 + wall, y0 + 0.4, z - d / 2 + wall), Vector3.new(x + w / 2 - wall, y0 + H - 0.62, z - d / 2 + wall + 0.1), C.panel, Enum.Material.Fabric)
	-- a warm light inside so the cash glows through the doorway
	local lamp = part(m, "Lamp", Vector3.new(0.6, 0.1, 0.6), CFrame.new(x, y0 + H - 0.75, z - d / 2 + 0.75), C.warm, Enum.Material.Neon)
	local pl = Instance.new("PointLight")
	pl.Color = C.warm; pl.Range = 7; pl.Brightness = 1.4
	pl.Parent = lamp
	-- the vault door, hinged on the right jamb and swung open toward the lounge
	local doorW, doorH = w - 2 * wall, H - 1.05
	local hinge = CFrame.new(x + w / 2 - wall, y0 + 0.4 + doorH / 2, z + d / 2)
	local swing = hinge * CFrame.Angles(0, math.rad(118), 0)
	local door = part(lb, "CashStand", Vector3.new(doorW, doorH, 0.26), swing * CFrame.new(-doorW / 2, 0, 0), steelDk, metal)
	part(m, "DoorPlate", Vector3.new(doorW - 0.7, doorH - 0.7, 0.08), swing * CFrame.new(-doorW / 2, 0, 0.17), C.gold, metal)
	-- spokes dial and handle on the door's outer face
	local dial = swing * CFrame.new(-doorW / 2 + 1.0, 0.5, 0.3)
	part(m, "DialRing", Vector3.new(0.1, 1.0, 1.0), dial * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, math.rad(90), 0), steel, metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Dial", Vector3.new(0.28, 0.72, 0.72), dial * CFrame.Angles(0, math.rad(90), 0), C.gold, metal, { Shape = Enum.PartType.Cylinder })
	for a = 0, 240, 120 do
		part(m, "Spoke", Vector3.new(0.1, 0.52, 0.1), dial * CFrame.Angles(0, 0, math.rad(a)) * CFrame.new(0, 0.62, 0), steel, metal)
	end
	part(m, "Handle", Vector3.new(0.16, 1.7, 0.16), swing * CFrame.new(-doorW / 2 + 0.45, 0, 0.24), C.gold, metal)
	for _, sy in ipairs({ -1, 1 }) do
		part(m, "Hinge", Vector3.new(0.5, 0.22, 0.22), hinge * CFrame.new(0, sy * doorH / 3, 0.16) * CFrame.Angles(0, 0, math.rad(90)), steel, metal, { Shape = Enum.PartType.Cylinder })
	end
	-- SAFE plaque on the top's front edge, facing the entrance
	local sign = block(m, "Sign", Vector3.new(x - 1.4, y0 + H + 0.02, z + d / 2 + 0.13), Vector3.new(x + 1.4, y0 + H + 0.43, z + d / 2 + 0.3), Color3.fromRGB(24, 84, 64), Enum.Material.SmoothPlastic)
	local _, tl = textSign(sign, Enum.NormalId.Back, "SAFE", { color = Color3.fromRGB(240, 206, 130), pps = 60, light = 0.3 })
	tl.FontFace = SERIF
	quiet(m)
	door.CanCollide = false; door.CanQuery = false; door.CanTouch = false -- the open leaf never blocks a walkway
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Plinth" or p.Name == "Back" or p.Name == "Side" or p.Name == "Top") then
			p.CanCollide = true
		end
	end
	local pile = model(lb, "CashPile")
	pile:SetAttribute("Origin", CFrame.new(x, y0 + 0.57, z - 0.15)) -- bundles stack on the safe's floor, behind the doorway
	return m
end

-- fixtures only (desk, cash stand, lights, nav); the movable furniture lives in Hotel.Placed
local function buildLobby(hotel)
	local lb = model(hotel, "Lobby")
	local dx, dz = -22, 15
	B.deskProp()
	place("Desk", lb, CFrame.new(dx, FY, dz))
	-- one globe pendant over the desk, chandeliers over the entrance and the lounge
	pendant(lb, dx + 0.3, dz - 0.2, FY + 8.2, 0.75)
	chandelier(lb, 0, 18.5)
	chandelier(lb, 22.6, 18.5)
	-- sconces between the room doors
	for _, sx in ipairs({ -1, 1 }) do
		sconce(lb, Vector3.new(sx * 13.25, FY + 7.6, -1.5), Vector3.new(0, 0, 1))
	end
	-- the safe sits inside the lobby, right beside the reception desk
	cashSafe(lb, -16, 15)
	-- nav
	local nav = folder(hotel, "Nav")
	spot(nav, "Street", CFrame.new(-70, FY + 3, 66))
	spot(nav, "StreetExit", CFrame.new(70, FY + 3, 66))
	spot(nav, "PathStart", CFrame.new(0, FY + 3, 62))
	for i = 1, 6 do
		spot(nav, "Queue" .. i, CFrame.new(0, FY + 3, 40 + (i - 1) * 3.2), { Look = Vector3.new(0, FY + 3, 20) }) -- one straight line (HotelSim.queueGo)
	end
	spot(nav, "Inside", CFrame.new(0, FY + 3, 24))
	spot(nav, "DeskGuest", CFrame.new(dx, FY + 3, dz + 3.4), { Look = Vector3.new(dx, FY + 3, dz) })
	spot(nav, "DeskGuest2", CFrame.new(dx + 3, FY + 3, dz + 3.6), { Look = Vector3.new(dx, FY + 3, dz) })
	spot(nav, "Receptionist", CFrame.new(dx, FY + 3, dz - 2.4), { Look = Vector3.new(dx, FY + 3, dz + 5) })
	spot(nav, "DoorPrompt", CFrame.new(0, FY + 4.5, 32.5))
end

-- the starting lobby furniture (only for a from-scratch build; convertPlaced turns it into Placed items)
local function lobbyFurniture(lb)
	local dx, dz = -22, 15
	place("Sofa", lb, CFrame.new(37.2, FY, 16) * CFrame.Angles(0, math.rad(-90), 0))
	place("Sofa", lb, CFrame.new(28.5, FY, 23.6) * CFrame.Angles(0, math.rad(180), 0))
	place("CoffeeTable", lb, CFrame.new(29.5, FY, 16))
	place("FloorLamp", lb, CFrame.new(37.6, FY, 23))
	place("FloorLamp", lb, CFrame.new(37.6, FY, 9))
	place("Plant", lb, CFrame.new(37, FY, 27.4))
	place("Plant", lb, CFrame.new(-37, FY, 27.4) * CFrame.Angles(0, 2, 0))
end

---------------------------------------------------------------- roof + ceiling
-- Hotel.Roof holds the Ceiling (inside) and the Top (slab, cornice, parapet, rooftop kit). It spans the hotel's
-- current width (MinX..MaxX), so B.roof runs again after every wing. Clients hide it (Roof) while
-- you're inside or building; RoofY tells Lighting where indoors ends.
local function waterTower(top, x, z, base)
	local m = model(top, "WaterTower")
	local y0 = (base or RY) + 0.12
	local legH = 6.5
	local steel = Color3.fromRGB(46, 50, 56)
	for _, o in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		block(m, "Leg", Vector3.new(x + o[1] * 2.5 - 0.2, y0, z + o[2] * 2.5 - 0.2), Vector3.new(x + o[1] * 2.5 + 0.2, y0 + legH, z + o[2] * 2.5 + 0.2), steel, Enum.Material.Metal)
	end
	for _, f in ipairs({ { Vector3.new(-2.5, 0, -2.5), Vector3.new(2.5, 0, -2.5) }, { Vector3.new(-2.5, 0, 2.5), Vector3.new(2.5, 0, 2.5) },
		{ Vector3.new(-2.5, 0, -2.5), Vector3.new(-2.5, 0, 2.5) }, { Vector3.new(2.5, 0, -2.5), Vector3.new(2.5, 0, 2.5) } }) do
		local a = Vector3.new(x, y0 + 0.6, z) + f[1]
		local b2 = Vector3.new(x, y0 + legH - 0.4, z) + f[2]
		part(m, "Brace", Vector3.new(0.12, 0.12, (b2 - a).Magnitude), CFrame.lookAt((a + b2) / 2, b2), steel, Enum.Material.Metal)
	end
	local py = y0 + legH
	part(m, "Deck", Vector3.new(0.3, 7.6, 7.6), CFrame.new(x, py, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(112, 86, 62), Enum.Material.WoodPlanks, { Shape = Enum.PartType.Cylinder })
	part(m, "Tank", Vector3.new(5.6, 6.6, 6.6), CFrame.new(x, py + 2.95, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(136, 96, 64), Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	for _, h in ipairs({ 0.7, 2.3, 3.9, 5.2 }) do
		part(m, "Hoop", Vector3.new(0.2, 6.75, 6.75), CFrame.new(x, py + h, z) * CFrame.Angles(0, 0, math.rad(90)), steel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	local roofCol = Color3.fromRGB(70, 74, 80)
	for i, spec in ipairs({ { 7.2, 0.4 }, { 5.4, 0.5 }, { 3.6, 0.55 }, { 1.8, 0.55 }, { 0.6, 0.5 } }) do
		local yy = py + 5.75 + (i - 1) * 0.45
		part(m, "Roof", Vector3.new(spec[2], spec[1], spec[1]), CFrame.new(x, yy, z) * CFrame.Angles(0, 0, math.rad(90)), roofCol, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	part(m, "Finial", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, py + 8.1, z), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	-- a ladder up the side
	local lz = z + 3.45
	for _, sx in ipairs({ -0.45, 0.45 }) do
		block(m, "LadderRail", Vector3.new(x + sx - 0.06, y0, lz - 0.06), Vector3.new(x + sx + 0.06, py + 5.6, lz + 0.06), steel, Enum.Material.Metal)
	end
	for y = y0 + 0.8, py + 5.2, 0.9 do
		block(m, "Rung", Vector3.new(x - 0.45, y - 0.04, lz - 0.04), Vector3.new(x + 0.45, y + 0.04, lz + 0.04), steel, Enum.Material.Metal)
	end
	return m
end


---------------------------------------------------------------- round 11: upper storeys, the marquee and a blade sign
-- Two brick storeys over the lobby (part of Roof, so they fade with it in build mode): limestone-framed windows
-- with curtains (about half glow warm at night), balconies and flower boxes on the street front, a string course
-- per floor, quoins, a dentil cornice and a parapet. The hotel's name marquee stands on top, and a tall neon
-- HOTEL blade sign hangs off the front corner.
local FH = 9 -- one upper storey
local UP_H = FH * 2
B.UP_H = UP_H
local LIT = Color3.fromRGB(236, 150, 72)
local DARKPANE = Color3.fromRGB(46, 56, 70)
local CURTAINS = { Color3.fromRGB(240, 228, 206), Color3.fromRGB(226, 196, 160), Color3.fromRGB(196, 214, 204), Color3.fromRGB(232, 206, 196) }
local FLOWERS = { Color3.fromRGB(232, 86, 110), Color3.fromRGB(250, 196, 70), Color3.fromRGB(246, 140, 170), Color3.fromRGB(186, 110, 220) }

-- a window on a wall face. (u, y) = centre along the wall and sill height; the face is at `plane` looking `s`
-- (+1 / -1) along Z (alongX) or X. opts.rich adds curtains and a keystone, opts.tall makes a french door.
local function upperWindow(m, lit, alongX, plane, s, u, y, w, h, rng, opts)
	opts = opts or {}
	local function box(name, u0, u1, y0, y1, d0, d1, color, mat, extra)
		local a, b
		if alongX then
			a, b = Vector3.new(u0, y0, plane + s * d0), Vector3.new(u1, y1, plane + s * d1)
		else
			a, b = Vector3.new(plane + s * d0, y0, u0), Vector3.new(plane + s * d1, y1, u1)
		end
		return block(m, name, a, b, color, mat, extra)
	end
	local u0, u1 = u - w / 2, u + w / 2
	-- the pane behind: dark by day; lit ones glow warm at night (Lighting reads LitColor)
	local pane = box("Pane", u0, u1, y, y + h, 0, 0.04, DARKPANE, Enum.Material.Glass, { Reflectance = 0.18, CastShadow = false })
	if lit then pane:SetAttribute("LitColor", LIT) pane.Parent = lit end
	if opts.rich then
		local cc = CURTAINS[rng:NextInteger(1, #CURTAINS)]
		local cw = w * rng:NextNumber(0.18, 0.3)
		box("Curtain", u0, u0 + cw, y, y + h, 0.04, 0.1, cc, Enum.Material.Fabric, { CastShadow = false })
		box("Curtain", u1 - cw, u1, y, y + h, 0.04, 0.1, cc, Enum.Material.Fabric, { CastShadow = false })
		box("Valance", u0, u1, y + h - 0.5, y + h, 0.04, 0.12, cc, Enum.Material.Fabric, { CastShadow = false })
	end
	box("Glass", u0, u1, y, y + h, 0.14, 0.18, C.glass, Enum.Material.Glass, { Transparency = 0.7, Reflectance = 0.2, CastShadow = false })
	-- muntins: one upright and one cross bar
	box("Muntin", u - 0.07, u + 0.07, y, y + h, 0.12, 0.22, C.trim, Enum.Material.SmoothPlastic)
	box("Muntin", u0, u1, y + h * 0.62 - 0.07, y + h * 0.62 + 0.07, 0.12, 0.22, C.trim, Enum.Material.SmoothPlastic)
	-- limestone surround: jambs, a lintel with a keystone, a sill
	box("Jamb", u0 - 0.45, u0, y, y + h, 0, 0.3, C.lime, Enum.Material.Limestone)
	box("Jamb", u1, u1 + 0.45, y, y + h, 0, 0.3, C.lime, Enum.Material.Limestone)
	box("Lintel", u0 - 0.6, u1 + 0.6, y + h, y + h + 0.7, 0, 0.36, C.lime, Enum.Material.Limestone)
	if opts.rich then box("Keystone", u - 0.45, u + 0.45, y + h - 0.2, y + h + 0.95, 0, 0.5, C.lime, Enum.Material.Limestone) end
	if not opts.tall then box("Sill", u0 - 0.55, u1 + 0.55, y - 0.3, y, 0, 0.55, C.lime, Enum.Material.Limestone) end
end

-- a balcony under a window at (u, y): a limestone slab on brackets and a black iron railing
local function balcony(m, plane, u, y, w)
	local d = 1.7
	block(m, "Balcony", Vector3.new(u - w / 2, y - 0.4, plane), Vector3.new(u + w / 2, y, plane + d), C.lime, Enum.Material.Limestone)
	for _, sx in ipairs({ -1, 1 }) do
		block(m, "Bracket", Vector3.new(u + sx * (w / 2 - 0.6) - 0.25, y - 1.3, plane), Vector3.new(u + sx * (w / 2 - 0.6) + 0.25, y - 0.4, plane + d - 0.3), C.lime, Enum.Material.Limestone)
	end
	local iron = C.frame
	local top = y + 2.6
	block(m, "Rail", Vector3.new(u - w / 2 + 0.1, top - 0.14, plane + d - 0.22), Vector3.new(u + w / 2 - 0.1, top, plane + d - 0.08), iron, Enum.Material.Metal)
	block(m, "Rail", Vector3.new(u - w / 2 + 0.1, y + 0.3, plane + d - 0.2), Vector3.new(u + w / 2 - 0.1, y + 0.4, plane + d - 0.1), iron, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		block(m, "Rail", Vector3.new(u + sx * (w / 2 - 0.1) - 0.07, y + 0.3, plane + 0.1), Vector3.new(u + sx * (w / 2 - 0.1) + 0.07, top, plane + d - 0.08), iron, Enum.Material.Metal)
	end
	local n = math.floor(w / 0.55)
	for i = 1, n - 1 do
		local x = u - w / 2 + 0.1 + (w - 0.2) * i / n
		block(m, "Baluster", Vector3.new(x - 0.04, y, plane + d - 0.18), Vector3.new(x + 0.04, top, plane + d - 0.12), iron, Enum.Material.Metal)
	end
	-- a pot plant on each balcony
	local pot = part(m, "Pot", Vector3.new(0.9, 0.8, 0.8), CFrame.new(u + w / 2 - 0.7, y + 0.4, plane + 0.7) * CFrame.Angles(0, 0, math.rad(90)) + Vector3.zero, Color3.fromRGB(176, 96, 66), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
	part(m, "Leaves", Vector3.new(1.4, 1.2, 1.4), pot.CFrame - OX + Vector3.new(0, 0.9, 0), Color3.fromRGB(70, 140, 70), Enum.Material.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
end

-- a flower box under a window sill at (u, y) on the front
local function flowerBox(m, plane, u, y, w, rng)
	block(m, "FlowerBox", Vector3.new(u - w / 2, y - 0.85, plane + 0.2), Vector3.new(u + w / 2, y - 0.3, plane + 0.95), Color3.fromRGB(40, 70, 56), Enum.Material.Wood)
	block(m, "Foliage", Vector3.new(u - w / 2 + 0.1, y - 0.3, plane + 0.3), Vector3.new(u + w / 2 - 0.1, y + 0.05, plane + 0.85), Color3.fromRGB(70, 136, 66), Enum.Material.Grass, { CanCollide = false })
	local c = FLOWERS[rng:NextInteger(1, #FLOWERS)]
	for k = 0, 3 do
		local x = u - w / 2 + 0.5 + (w - 1) * k / 3
		part(m, "Bloom", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, y + 0.15, plane + 0.6 + (k % 2) * 0.12), c, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, CastShadow = false })
	end
end

local function upperFloors(top, x0, x1, zb, zf, floors, fancy)
	local UP_H = FH * floors
	local up = model(top, "Upper")
	local lit = model(up, "Lit")
	CS:AddTag(lit, "NightLight")
	local rng = Random.new(math.floor(x1 * 7 + x0 * 3))
	local xa, xb = x0 - 0.3, x1 + 0.3
	local y0, y1 = RY + 0.08, RY + UP_H
	local T = 0.8
	-- the walls
	tex(block(up, "Brick", Vector3.new(xa, y0, zf - T), Vector3.new(xb, y1, zf), C.brick), "Brick")
	tex(block(up, "Brick", Vector3.new(xa, y0, zb), Vector3.new(xb, y1, zb + T), C.brick), "Brick")
	tex(block(up, "Brick", Vector3.new(xa, y0, zb + T), Vector3.new(xa + T, y1, zf - T), C.brick), "Brick")
	tex(block(up, "Brick", Vector3.new(xb - T, y0, zb + T), Vector3.new(xb, y1, zf - T), C.brick), "Brick")
	block(up, "Floor", Vector3.new(xa + T, y0, zb + T), Vector3.new(xb - T, y0 + 0.2, zf - T), C.roof, Enum.Material.Concrete)
	-- a string course at each upper floor
	for f = 1, floors - 1 do
		local y = RY + f * FH
		block(up, "Course", Vector3.new(xa - 0.35, y - 0.35, zf), Vector3.new(xb + 0.35, y + 0.2, zf + 0.4), C.lime, Enum.Material.Limestone)
		block(up, "Course", Vector3.new(xa - 0.4, y - 0.35, zb - 0.4), Vector3.new(xa, y + 0.2, zf + 0.4), C.lime, Enum.Material.Limestone)
		block(up, "Course", Vector3.new(xb, y - 0.35, zb - 0.4), Vector3.new(xb + 0.4, y + 0.2, zf + 0.4), C.lime, Enum.Material.Limestone)
		block(up, "Course", Vector3.new(xa, y - 0.35, zb - 0.4), Vector3.new(xb, y + 0.2, zb), C.lime, Enum.Material.Limestone)
	end
	-- quoins up the four corners
	for _, cx in ipairs({ { xa, -1 }, { xb, 1 } }) do
		for _, cz in ipairs({ { zf, 1 }, { zb, -1 } }) do
			for i = 0, math.floor(UP_H / 0.95) - 1 do
				local y = y0 + 0.1 + i * 0.95
				local long = i % 2 == 0
				local ax, az = long and 2.0 or 1.2, long and 1.2 or 2.0
				local sx, sz = cx[2], cz[2]
				block(up, "Quoin", Vector3.new(cx[1] - sx * ax, y, cz[1]), Vector3.new(cx[1] + sx * 0.15, y + 0.8, cz[1] + sz * 0.15), C.lime, Enum.Material.Limestone)
				block(up, "Quoin", Vector3.new(cx[1], y, cz[1] - sz * az), Vector3.new(cx[1] + sx * 0.15, y + 0.8, cz[1] + sz * 0.15), C.lime, Enum.Material.Limestone)
			end
		end
	end
	-- the street front: evenly spaced bays; the one over the door gets french doors and the biggest balcony
	local n = math.max(3, math.floor((xb - xa - 6) / 7.6))
	local w = 3.4
	for i = 1, n do
		local u = xa + 3 + (xb - xa - 6) * (i - 0.5) / n
		local centre = math.abs(u) < (xb - xa - 6) / n / 2
		for f = 0, floors - 1 do
			local base = RY + f * FH
			local isLit = rng:NextNumber() < 0.55
			if fancy and f == 0 and (centre or i % 2 == 0) then
				-- balcony bay: a french door
				upperWindow(up, isLit and lit, true, zf, 1, u, base + 0.45, centre and 4.4 or w, 6.9, rng, { rich = true, tall = true })
				balcony(up, zf, u, base + 0.45, centre and 7.0 or 5.0)
			else
				upperWindow(up, isLit and lit, true, zf, 1, u, base + 1.8, w, 5.2, rng, { rich = true })
				if fancy and f == floors - 1 and i % 2 == 1 then flowerBox(up, zf, u, base + 1.5, w + 0.6, rng) end
			end
		end
	end
	-- the sides and back: plainer windows
	local function sideRun(plane, s, alongX, a0, a1)
		local k = math.max(2, math.floor((a1 - a0 - 6) / 9))
		for i = 1, k do
			local u = a0 + 3 + (a1 - a0 - 6) * (i - 0.5) / k
			for f = 0, floors - 1 do
				local isLit = rng:NextNumber() < 0.45
				upperWindow(up, isLit and lit, alongX, plane, s, u, RY + f * FH + 1.8, 3.2, 5.0, rng, { rich = alongX == false })
			end
		end
	end
	sideRun(xa, -1, false, zb, zf)
	sideRun(xb, 1, false, zb, zf)
	sideRun(zb, -1, true, xa, xb)
	return up
end

-- the hotel's name: a marquee on the roof, green with a brass frame and a ring of bulbs (HotelSim sets the text)
local function marquee(parent, hotel, base, zFront)
	local sy0, sy1 = base + 2.7, base + 8.5
	local zs = zFront - 0.75 -- the board's back face
	local signBoard = block(parent, "HotelSign", Vector3.new(-15, sy0, zs), Vector3.new(15, sy1, zs + 0.5), C.green, Enum.Material.SmoothPlastic)
	local _, st = textSign(signBoard, Enum.NormalId.Back, string.upper(hotel and hotel:GetAttribute("HotelName") or "MY HOTEL"), { pps = 30, light = 0 })
	st.FontFace = SERIF
	st.TextColor3 = Color3.fromRGB(255, 236, 196)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(120, 84, 30)
	stroke.Parent = st
	signBoard:SetAttribute("HotelName", true)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Range = 12
	glow.Brightness = 0.6
	glow.Color = Color3.fromRGB(255, 220, 170)
	glow.Parent = signBoard
	local fw = 0.45
	local zf0, zf1 = zs + 0.45, zs + 0.7
	for _, e in ipairs({
		{ Vector3.new(-15 - fw, sy0 - fw, zf0), Vector3.new(15 + fw, sy0, zf1) },
		{ Vector3.new(-15 - fw, sy1, zf0), Vector3.new(15 + fw, sy1 + fw, zf1) },
		{ Vector3.new(-15 - fw, sy0, zf0), Vector3.new(-15, sy1, zf1) },
		{ Vector3.new(15, sy0, zf0), Vector3.new(15 + fw, sy1, zf1) },
	}) do
		block(parent, "SignFrame", e[1], e[2], C.gold, Enum.Material.Metal)
	end
	block(parent, "SignBack", Vector3.new(-15 - fw, sy0 - fw, zs - 0.25), Vector3.new(15 + fw, sy1 + fw, zs), C.frame, Enum.Material.Metal)
	local bulbs = model(parent, "SignBulbs")
	local function bulbLine(a, b2)
		local n = math.floor((b2 - a).Magnitude / 1.15)
		for i = 0, n do
			local p = part(bulbs, "Bulb", Vector3.new(0.3, 0.3, 0.3), CFrame.new(a:Lerp(b2, i / n)), Color3.fromRGB(246, 236, 214), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, CastShadow = false })
			p:SetAttribute("LitColor", Color3.fromRGB(255, 214, 140))
		end
	end
	local bz = zs + 0.77
	bulbLine(Vector3.new(-15 - fw / 2, sy0 - fw / 2, bz), Vector3.new(15 + fw / 2, sy0 - fw / 2, bz))
	bulbLine(Vector3.new(-15 - fw / 2, sy1 + fw / 2, bz), Vector3.new(15 + fw / 2, sy1 + fw / 2, bz))
	bulbLine(Vector3.new(-15 - fw / 2, sy0 + 0.9, bz), Vector3.new(-15 - fw / 2, sy1 - 0.4, bz))
	bulbLine(Vector3.new(15 + fw / 2, sy0 + 0.9, bz), Vector3.new(15 + fw / 2, sy1 - 0.4, bz))
	quiet(bulbs)
	CS:AddTag(bulbs, "NightLight")
	for _, x in ipairs({ -11, 0, 11 }) do
		block(parent, "SignPost", Vector3.new(x - 0.3, base - 0.2, zs - 0.85), Vector3.new(x + 0.3, sy0, zs - 0.25), C.frame, Enum.Material.Metal)
		local a, b2 = Vector3.new(x, base + 0.1, zs - 4.6), Vector3.new(x, sy0 + 1.5, zs - 0.3)
		part(parent, "SignBrace", Vector3.new(0.25, 0.25, (b2 - a).Magnitude), CFrame.lookAt((a + b2) / 2, b2), C.frame, Enum.Material.Metal)
	end
	return signBoard
end

-- grade 1: a plain painted board on two posts at the roof's front edge (no bulbs, no light)
local function innSign(parent, hotel, base, zFront)
	local y0, y1 = base + 2.2, base + 6.2
	local zs = zFront - 0.75
	local board = block(parent, "HotelSign", Vector3.new(-10, y0, zs), Vector3.new(10, y1, zs + 0.4), Color3.fromRGB(240, 230, 206), Enum.Material.WoodPlanks)
	local _, st = textSign(board, Enum.NormalId.Back, string.upper(hotel and hotel:GetAttribute("HotelName") or "MY HOTEL"), { pps = 30, light = 0.6 })
	st.FontFace = SERIF
	st.TextColor3 = Color3.fromRGB(70, 52, 40)
	board:SetAttribute("HotelName", true)
	block(parent, "SignTrim", Vector3.new(-10.2, y0 - 0.2, zs + 0.35), Vector3.new(10.2, y0, zs + 0.5), Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
	block(parent, "SignTrim", Vector3.new(-10.2, y1, zs + 0.35), Vector3.new(10.2, y1 + 0.2, zs + 0.5), Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
	for _, x in ipairs({ -7, 7 }) do
		block(parent, "SignPost", Vector3.new(x - 0.25, base - 0.2, zs - 0.5), Vector3.new(x + 0.25, y0, zs), Color3.fromRGB(110, 78, 52), Enum.Material.Wood)
	end
	return board
end

-- a tall HOTEL blade sign hung off the street front near a corner (x), from y0 up `h` studs
local function bladeSign(parent, x, y0, h, zf)
	local m = model(parent, "BladeSign")
	local d0, d1 = zf + 0.6, zf + 4.4
	local red = Color3.fromRGB(176, 36, 48)
	local body = block(m, "Blade", Vector3.new(x - 0.5, y0, d0), Vector3.new(x + 0.5, y0 + h, d1), Color3.fromRGB(248, 240, 222), Enum.Material.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 24
		g.LightInfluence = 0.15
		g.Parent = body
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = g
		for _, ch in ipairs({ "H", "O", "T", "E", "L" }) do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(0.86, 0, 0.17, 0)
			t.FontFace = SERIF
			t.Text = ch
			t.TextScaled = true
			t.TextColor3 = red
			t.Parent = g
		end
	end
	-- a red neon edge and caps, brackets back to the wall
	local edge = model(m, "Edge")
	for _, z in ipairs({ d0 - 0.15, d1 + 0.15 }) do
		block(edge, "Tube", Vector3.new(x - 0.62, y0, z - 0.15), Vector3.new(x + 0.62, y0 + h, z + 0.15), red, Enum.Material.SmoothPlastic, { CastShadow = false }):SetAttribute("LitColor", Color3.fromRGB(255, 70, 80))
	end
	for _, y in ipairs({ y0 - 0.15, y0 + h + 0.15 }) do
		block(edge, "Tube", Vector3.new(x - 0.62, y - 0.15, d0 - 0.3), Vector3.new(x + 0.62, y + 0.15, d1 + 0.3), red, Enum.Material.SmoothPlastic, { CastShadow = false }):SetAttribute("LitColor", Color3.fromRGB(255, 70, 80))
	end
	quiet(edge)
	CS:AddTag(edge, "NightLight")
	part(m, "Finial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, y0 + h + 0.75, (d0 + d1) / 2), C.gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	for _, y in ipairs({ y0 + 1.5, y0 + h - 1.5 }) do
		block(m, "Bracket", Vector3.new(x - 0.15, y - 0.15, zf), Vector3.new(x + 0.15, y + 0.15, d0), C.frame, Enum.Material.Metal)
	end
	return m
end

function B.roof(hotel)
	useOrigin(hotel)
	local old = hotel:FindFirstChild("Roof")
	if old then old:Destroy() end
	local rf = model(hotel, "Roof")
	local ceil = model(rf, "Ceiling")
	local top = model(rf, "Top")
	local minX = hotel:GetAttribute("MinX") or -39.5
	local maxX = hotel:GetAttribute("MaxX") or 39.5
	local x0, x1 = minX - 1, maxX + 1
	hotel:SetAttribute("RoofY", CEIL + 0.2)
	-- ceiling: plaster, coffered over the lobby (beams on a fixed 11.3 grid, so wings line up)
	block(ceil, "Ceiling", Vector3.new(minX, CEIL, -29.5), Vector3.new(maxX, CEIL + 0.4, ZI), C.ceiling, Enum.Material.Plaster)
	local function beam(a, b2)
		block(ceil, "Beam", a, b2, C.ceiling, Enum.Material.Plaster)
		block(ceil, "BeamBead", Vector3.new(a.X + (b2.X - a.X > 1 and 0 or 0.3), a.Y - 0.06, a.Z + (b2.Z - a.Z > 1 and 0 or 0.3)), Vector3.new(b2.X - (b2.X - a.X > 1 and 0 or 0.3), a.Y, b2.Z - (b2.Z - a.Z > 1 and 0 or 0.3)), C.gold, Enum.Material.Metal)
	end
	local G = 11.3
	local xs = {}
	for k = -20, 20 do
		local x = G / 2 + G * k
		if x > minX + 1 and x < maxX - 1 then
			table.insert(xs, x)
			beam(Vector3.new(x - 0.45, CEIL - 0.75, -1.5), Vector3.new(x + 0.45, CEIL, ZI))
		end
	end
	for _, z in ipairs({ 6.5, 14.5, 22.5 }) do
		beam(Vector3.new(minX, CEIL - 0.75, z - 0.45), Vector3.new(maxX, CEIL, z + 0.45))
	end
	-- a downlight in each coffer (not where a chandelier hangs)
	local edges = { minX }
	for _, x in ipairs(xs) do table.insert(edges, x) end
	table.insert(edges, maxX)
	for i = 1, #edges - 1 do
		local x = (edges[i] + edges[i + 1]) / 2
		for _, z in ipairs({ 2.5, 10.5, 18.5, 26.1 }) do
			local chand = z == 18.5 and (math.abs(x) < 2 or math.abs(x - 22.6) < 2)
			if not chand then downlight(ceil, Vector3.new(x, CEIL - 0.06, z), 1.0) end
		end
	end
	for _, room in ipairs(hotel.Rooms:GetChildren()) do
		local f = room:FindFirstChild("Floor")
		if f then
			local c = f.Position - OX
			downlight(ceil, Vector3.new(c.X - 3, CEIL - 0.06, -14), 1.4, { light = { range = 20, brightness = 0.6 } })
		end
	end
	-- the roof: slab and gravel, a stepped limestone cornice with dentils, a brick parapet with a coping
	local zb, zf = -31.1, ZO
	block(top, "Slab", Vector3.new(x0 - 0.3, FY + WALL_H + 0.5, zb), Vector3.new(x1 + 0.3, RY, zf), C.roof, Enum.Material.Concrete)
	-- round 11: the building grows with the hotel's grade (Shared.Grades): 3 = a second storey, 4 = a third with
	-- balconies, 5 = the neon blade sign. The old cornice becomes the belt course over the ground floor.
	local grade = math.clamp(hotel:GetAttribute("Grade") or 1, 1, 5)
	local floors = grade >= 4 and 2 or grade >= 3 and 1 or 0
	if floors > 0 then upperFloors(top, x0, x1, zb, zf, floors, grade >= 4) end
	local RY0 = RY
	local function cornice(a0, a1, plane, s, alongX, dentils)
		local function slab(name, y0, y1, d, mat)
			local p0, p1 = plane, plane + s * d
			if alongX then
				return block(top, name, Vector3.new(a0, y0, p0), Vector3.new(a1, y1, p1), C.lime, mat or Enum.Material.Limestone)
			end
			return block(top, name, Vector3.new(p0, y0, a0), Vector3.new(p1, y1, a1), C.lime, mat or Enum.Material.Limestone)
		end
		slab("Cornice", RY - 1.1, RY - 0.65, 0.3)
		slab("Cornice", RY - 0.65, RY - 0.25, 0.62)
		slab("Cornice", RY - 0.25, RY + 0.08, 1.0)
		if dentils and grade >= 2 then
			for t = a0 + 0.5, a1 - 0.4, 0.9 do
				local p0, p1 = plane, plane + s * 0.24
				if alongX then
					block(top, "Dentil", Vector3.new(t, RY - 1.55, p0), Vector3.new(t + 0.42, RY - 1.1, p1), C.lime, Enum.Material.Limestone)
				else
					block(top, "Dentil", Vector3.new(p0, RY - 1.55, t), Vector3.new(p1, RY - 1.1, t + 0.42), C.lime, Enum.Material.Limestone)
				end
			end
		end
	end
	cornice(x0 - 0.3 - 1.0, x1 + 0.3 + 1.0, zf, 1, true, true)
	cornice(zb, zf + 1.0, x0 - 0.3, -1, false, true)
	cornice(zb, zf + 1.0, x1 + 0.3, 1, false, true)
	cornice(x0 - 0.3, x1 + 0.3, zb, -1, true, false)
	-- and again at the new roof line
	local RY = RY0 + floors * FH
	local function topCornice(a0, a1, plane, s, alongX)
		local function slab(name, y0, y1, d)
			local p0, p1 = plane, plane + s * d
			if alongX then return block(top, name, Vector3.new(a0, y0, p0), Vector3.new(a1, y1, p1), C.lime, Enum.Material.Limestone) end
			return block(top, name, Vector3.new(p0, y0, a0), Vector3.new(p1, y1, a1), C.lime, Enum.Material.Limestone)
		end
		slab("Cornice", RY - 1.1, RY - 0.65, 0.35)
		slab("Cornice", RY - 0.65, RY - 0.25, 0.7)
		slab("Cornice", RY - 0.25, RY + 0.08, 1.1)
		for t = a0 + 0.5, a1 - 0.4, 1.1 do
			local p0, p1 = plane, plane + s * 0.26
			if alongX then
				block(top, "Dentil", Vector3.new(t, RY - 1.6, p0), Vector3.new(t + 0.5, RY - 1.1, p1), C.lime, Enum.Material.Limestone)
			else
				block(top, "Dentil", Vector3.new(p0, RY - 1.6, t), Vector3.new(p1, RY - 1.1, t + 0.5), C.lime, Enum.Material.Limestone)
			end
		end
	end
	if floors > 0 then
		topCornice(x0 - 0.3 - 1.1, x1 + 0.3 + 1.1, zf, 1, true)
		topCornice(zb - 1.1, zf + 1.1, x0 - 0.3, -1, false)
		topCornice(zb - 1.1, zf + 1.1, x1 + 0.3, 1, false)
		topCornice(x0 - 0.3, x1 + 0.3, zb, -1, true)
		block(top, "RoofSlab", Vector3.new(x0 - 0.3, RY - 0.4, zb), Vector3.new(x1 + 0.3, RY, zf), C.roof, Enum.Material.Concrete)
	end
	if grade >= 5 then
		-- a gold-lit roof line: a strip under the top cornice that glows at night
		local strip = model(top, "RoofGlow")
		block(strip, "Glow", Vector3.new(x0 - 0.3, RY - 1.75, zf), Vector3.new(x1 + 0.3, RY - 1.6, zf + 0.12), C.gold, Enum.Material.Metal, { CastShadow = false }):SetAttribute("LitColor", Color3.fromRGB(255, 214, 140))
		quiet(strip)
		CS:AddTag(strip, "NightLight")
	end
	block(top, "Gravel", Vector3.new(x0 + 1.2, RY, zb + 1.2), Vector3.new(x1 - 1.2, RY + 0.12, zf - 1.2), Color3.fromRGB(128, 126, 120), Enum.Material.Pebble)
	local function parapet(a, b2)
		tex(block(top, "Parapet", Vector3.new(a.X, RY, a.Y), Vector3.new(b2.X, RY + 2.0, b2.Y), C.brick), "Brick")
		block(top, "Coping", Vector3.new(a.X - 0.15, RY + 2.0, a.Y - 0.15), Vector3.new(b2.X + 0.15, RY + 2.3, b2.Y + 0.15), C.lime, Enum.Material.Limestone)
	end
	parapet(Vector2.new(x0 - 0.3, zb), Vector2.new(x1 + 0.3, zb + 0.8))
	parapet(Vector2.new(x0 - 0.3, zf - 0.8), Vector2.new(x1 + 0.3, zf))
	parapet(Vector2.new(x0 - 0.3, zb + 0.8), Vector2.new(x0 + 0.5, zf - 0.8))
	parapet(Vector2.new(x1 - 0.5, zb + 0.8), Vector2.new(x1 + 0.3, zf - 0.8))
	-- rooftop kit: a wooden water tower, AC units, vents, a hatch
	waterTower(top, x0 + 9, -19, RY)
	if grade >= 2 then marquee(top, hotel, RY, zf) else innSign(top, hotel, RY, zf) end
	if grade >= 5 then bladeSign(top, x1 - 3, RY0 + 0.6, floors * FH + 3.2, zf) end
	local n = math.max(2, math.floor((x1 - x0) / 28))
	for i = 1, n do
		local x = x0 + (x1 - x0) * (i - 0.5) / n + 6
		local ac = model(top, "AC")
		local z = -8 + (i % 2) * 6
		block(ac, "Body", Vector3.new(x - 2.6, RY + 0.12, z - 2), Vector3.new(x + 2.6, RY + 3, z + 2), Color3.fromRGB(206, 208, 212), Enum.Material.Metal)
		block(ac, "Lid", Vector3.new(x - 2.7, RY + 3, z - 2.1), Vector3.new(x + 2.7, RY + 3.2, z + 2.1), Color3.fromRGB(176, 178, 184), Enum.Material.Metal)
		part(ac, "Fan", Vector3.new(0.1, 2.8, 2.8), CFrame.new(x, RY + 3.25, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(52, 54, 60), Enum.Material.DiamondPlate, { Shape = Enum.PartType.Cylinder })
		for k = -3, 3 do
			block(ac, "Louvre", Vector3.new(x - 2.2, RY + 1.6 + k * 0.18, z + 2), Vector3.new(x + 2.2, RY + 1.68 + k * 0.18, z + 2.08), Color3.fromRGB(120, 122, 128), Enum.Material.Metal)
		end
		block(ac, "Pipe", Vector3.new(x + 2.6, RY + 0.4, z - 0.3), Vector3.new(x + 4.2, RY + 0.7, z), Color3.fromRGB(150, 152, 156), Enum.Material.Metal)
		part(top, "Vent", Vector3.new(1.8, 0.8, 0.8), CFrame.new(x + 7, RY + 1, 8) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 172, 178), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		part(top, "VentCap", Vector3.new(0.2, 1.3, 1.3), CFrame.new(x + 7, RY + 1.95, 8) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 122, 128), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	block(top, "Hatch", Vector3.new(x1 - 12, RY + 0.12, -22), Vector3.new(x1 - 9, RY + 0.9, -19), Color3.fromRGB(150, 152, 156), Enum.Material.Metal)
	for _, d in ipairs(rf:GetDescendants()) do
		if d:IsA("BasePart") then d.CanTouch = false end
	end
	return rf
end

-- Edit-time: remake the template hotel's shell, lobby fixtures, rooms' doors and floors, and roof in place.
-- Keeps Rooms (their furniture and spots), Placed (the movable furniture, refreshed from the current
-- item templates) and BuildZones. Drops the old for-sale lot.
function B.remodel()
	useOrigin(nil)
	B.materials()
	local hotel = workspace.Hotel
	for _, n in ipairs({ "Shell", "Doors", "Lobby", "Nav", "Roof", "ForSale" }) do
		local o = hotel:FindFirstChild(n)
		if o then o:Destroy() end
	end
	buildShell(hotel)
	task.wait()
	buildLobby(hotel)
	task.wait()
	for _, room in ipairs(hotel.Rooms:GetChildren()) do
		B.refitRoom(room)
		local up = room:FindFirstChild("Upgrade")
		if up then up:Destroy() end
	end
	B.roof(hotel)
	B.refreshPlaced(hotel)
	return hotel
end

-- swap every placed item for a fresh copy of its current template (same spot, same attributes)
function B.refreshPlaced(hotel)
	local items = game.ReplicatedStorage.Shared.Items
	for _, m in ipairs(hotel.Placed:GetChildren()) do
		local id = m:GetAttribute("Item")
		local tpl = id and items:FindFirstChild(id)
		if tpl and not m:GetAttribute("Shape") then
			local n = tpl:Clone()
			n:PivotTo(m:GetPivot())
			for k, v in pairs(m:GetAttributes()) do n:SetAttribute(k, v) end
			n.Parent = hotel.Placed
			m:Destroy()
		end
	end
end

---------------------------------------------------------------- outside

local function buildOutside(hotel)
	local out = model(workspace, "Outside")
	local t = workspace.Terrain
	t:Clear()
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(220, 12, 420), Enum.Material.LeafyGrass)
	t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(104, 168, 72))
	-- no terrain (or grass blades) under the building, path or road: carve to air, floor it with concrete well below
	t:FillBlock(CFrame.new(0, 0, 0), Vector3.new(96, 8, 76), Enum.Material.Air)
	t:FillBlock(CFrame.new(0, 0, 46), Vector3.new(16, 8, 30), Enum.Material.Air)
	t:FillBlock(CFrame.new(0, 0, 80), Vector3.new(220, 8, 44), Enum.Material.Air)
	t:FillBlock(CFrame.new(0, -6, 0), Vector3.new(96, 4, 76), Enum.Material.Concrete)
	t:FillBlock(CFrame.new(0, -6, 80), Vector3.new(220, 4, 44), Enum.Material.Concrete)
	t:FillBlock(CFrame.new(0, -6, 46), Vector3.new(16, 4, 30), Enum.Material.Concrete)
	-- the plinth skirt and road bed hide the carved gaps
	block(out, "Apron", Vector3.new(-48, -4, -38), Vector3.new(48, 0, 38), Color3.fromRGB(214, 210, 202), Enum.Material.Pavement)
	block(out, "PathBed", Vector3.new(-8, -4, 31), Vector3.new(8, -0.2, 61), Color3.fromRGB(150, 156, 120), Enum.Material.Ground)
	block(out, "RoadBed", Vector3.new(-110, -4, 58), Vector3.new(110, -0.4, 102), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
	-- path, sidewalk, road
	block(out, "Path", Vector3.new(-5, -0.2, 31.5), Vector3.new(5, 0.25, 60), Color3.fromRGB(226, 220, 210), Enum.Material.Pavement)
	for _, sx in ipairs({ -1, 1 }) do
		block(out, "PathEdge", Vector3.new(sx * 5 - 0.3, -0.2, 31.5), Vector3.new(sx * 5 + 0.3, 0.45, 60), Color3.fromRGB(180, 176, 168), Enum.Material.Concrete)
	end
	block(out, "Sidewalk", Vector3.new(-110, -0.2, 60), Vector3.new(110, 0.3, 72), Color3.fromRGB(214, 210, 202), Enum.Material.Pavement)
	block(out, "Curb", Vector3.new(-110, -0.2, 71.6), Vector3.new(110, 0.5, 72.4), Color3.fromRGB(170, 168, 162), Enum.Material.Concrete)
	block(out, "Road", Vector3.new(-110, -0.4, 72.4), Vector3.new(110, 0.05, 100), Color3.fromRGB(58, 60, 66), Enum.Material.Asphalt)
	for x = -104, 104, 16 do
		block(out, "Dash", Vector3.new(x, 0.05, 85.8), Vector3.new(x + 8, 0.1, 86.6), Color3.fromRGB(240, 230, 190), Enum.Material.SmoothPlastic)
	end
	-- ramp up onto the plinth at the door
	local ramp = part(out, "Step", Vector3.new(14, 1, 3), CFrame.new(0, 0.5, 33), C.plinth, Enum.Material.Concrete)
	-- street lamps along the path
	for _, z in ipairs({ 42, 54 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local lm = model(out, "Lamp")
			local x = sx * 7
			block(lm, "Base", Vector3.new(x - 0.6, 0, z - 0.6), Vector3.new(x + 0.6, 0.8, z + 0.6), C.frame, Enum.Material.Metal)
			part(lm, "Pole", Vector3.new(0.4, 9, 0.4), CFrame.new(x, 5, z), C.frame, Enum.Material.Metal)
			local head = part(lm, "Head", Vector3.new(1.4, 1.8, 1.4), CFrame.new(x, 10.2, z), Color3.fromRGB(255, 236, 196), Enum.Material.Neon)
			part(lm, "Cap", Vector3.new(1.9, 0.4, 1.9), CFrame.new(x, 11.3, z), C.frame, Enum.Material.Metal)
			local l = Instance.new("PointLight")
			l.Range = 18; l.Brightness = 1; l.Color = Color3.fromRGB(255, 220, 170)
			l.Parent = head
		end
	end
	-- hedges + planters along the facade
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 3 do
			local x = sx * (12 + i * 7.5)
			local box = part(out, "Planter", Vector3.new(6.5, 1.6, 3), CFrame.new(x, 0.8, 34), Color3.fromRGB(226, 220, 210), Enum.Material.Concrete)
			part(out, "Hedge", Vector3.new(6, 2.6, 2.6), CFrame.new(x, 2.6, 34), Color3.fromRGB(86, 150, 70), Enum.Material.LeafyGrass)
		end
	end
end

---------------------------------------------------------------- lighting

function B.lighting()
	local L = game.Lighting
	L.ClockTime = 14.2
	L.GeographicLatitude = 35
	L.Brightness = 3
	L.Ambient = Color3.fromRGB(70, 66, 80)
	L.OutdoorAmbient = Color3.fromRGB(150, 146, 160)
	L.EnvironmentDiffuseScale = 1
	L.EnvironmentSpecularScale = 1
	L.ShadowSoftness = 0.25
	L.ExposureCompensation = 0.1
	local function get(cls, name)
		local e = L:FindFirstChild(name) or Instance.new(cls)
		e.Name = name
		e.Parent = L
		return e
	end
	local cc = get("ColorCorrectionEffect", "Grade")
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 250, 244)
	local bl = get("BloomEffect", "Bloom")
	bl.Intensity = 0.5; bl.Size = 24; bl.Threshold = 1.6
	local at = get("Atmosphere", "Atmosphere")
	at.Density = 0.28; at.Offset = 0.2; at.Haze = 0.6; at.Glare = 0.3
	at.Color = Color3.fromRGB(200, 220, 240); at.Decay = Color3.fromRGB(120, 150, 190)
	local sr = get("SunRaysEffect", "SunRays")
	sr.Intensity = 0.04
	local dof = L:FindFirstChild("DepthOfField")
	if dof then dof.Enabled = false end
end

---------------------------------------------------------------- build mode setup (round 2)

local GLOWS = {
	Nightstand = { Color3.fromRGB(255, 226, 186), 14, 0.8 },
	FloorLamp = { Color3.fromRGB(255, 226, 186), 16, 0.9 },
	TVStand = { Color3.fromRGB(110, 190, 240), 8, 0.4 },
	VendingMachine = { Color3.fromRGB(140, 255, 170), 6, 0.3 },
}
local SHOP = { "Shower", "Toilet", "Sofa", "Armchair", "CoffeeTable", "SideTable", "Nightstand", "Wardrobe", "Bookshelf", "TVStand",
	"Plant", "PottedTree", "FloorLamp", "Rug", "PingPongTable", "VendingMachine" }
local SOFT = { Shower = true, Plant = true, FloorLamp = true, Rug = true }

-- ReplicatedStorage.Shared.Items: one template per catalog item (pivot = floor centre)
function B.makeItems()
	local shared = game.ReplicatedStorage:WaitForChild("Shared")
	local old = shared:FindFirstChild("Items")
	if old then old:Destroy() end
	local items = Instance.new("Folder")
	items.Name = "Items"
	for _, id in ipairs(SHOP) do
		local m = PROPS[id]:Clone()
		m.Name = id
		local g = m:FindFirstChild("Glow")
		local spec = GLOWS[id]
		if g and spec then
			g.Material = Enum.Material.Neon
			g.Color = spec[1]
			g.Transparency = 0.15
			local l = Instance.new("PointLight")
			l.Color = spec[1]; l.Range = spec[2]; l.Brightness = spec[3]
			l.Parent = g
		end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = true
				if SOFT[id] then p.CollisionGroup = "NPCSolid" end
				if p.Name == "Glass" then p.CanCollide = false end
			end
		end
		m.WorldPivot = CFrame.new()
		m.Parent = items
	end
	-- the bed carries its own clean and messy versions
	local bed = Instance.new("Model")
	bed.Name = "Bed"
	local clean = PROPS.Bed:Clone(); clean.Name = "Clean"; clean.Parent = bed
	local messy = PROPS.BedMessy:Clone(); messy.Name = "Messy"; messy.Parent = bed
	for _, p in ipairs(bed:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			if p:IsDescendantOf(messy) or p.Name == "Glass" then p.CanCollide = false end
		end
	end
	bed.WorldPivot = CFrame.new()
	bed.Parent = items
	items.Parent = shared
	return items
end

-- round 9: add (or replace) catalogue templates for these props without touching the others.
-- Glow parts turn into lit neon; soft items (Catalog item.soft) let guests walk through them.
local GLOWS9 = {
	TableLamp = { Color3.fromRGB(255, 222, 176), 12, 0.8 },
	ArcLamp = { Color3.fromRGB(255, 222, 176), 16, 0.9 },
	WallSconce = { Color3.fromRGB(255, 214, 160), 12, 0.8 },
	Fireplace = { Color3.fromRGB(255, 140, 60), 18, 1.2 },
	Aquarium = { Color3.fromRGB(120, 200, 255), 10, 0.6 },
	Arcade = { Color3.fromRGB(140, 170, 255), 8, 0.5 },
	Jukebox = { Color3.fromRGB(255, 170, 120), 10, 0.6 },
	ClawMachine = { Color3.fromRGB(255, 190, 230), 8, 0.5 },
	ATM = { Color3.fromRGB(140, 220, 255), 6, 0.3 },
	KitchenFridge = { Color3.fromRGB(120, 220, 255), 5, 0.3 },
	ServingCounter = { Color3.fromRGB(255, 170, 90), 10, 0.7 }, -- the heat lamps over the pass
	Stove = { Color3.fromRGB(255, 120, 60), 4, 0.3 },
	Candelabra = { Color3.fromRGB(255, 196, 120), 14, 0.9 },
	-- round 12
	ReadingNook = { Color3.fromRGB(255, 222, 176), 12, 0.8 },
	Chandelier = { Color3.fromRGB(255, 220, 170), 24, 1.2 },
	PendantLamp = { Color3.fromRGB(255, 214, 160), 14, 0.9 },
	LanternPost = { Color3.fromRGB(255, 200, 130), 16, 1.0 },
	NeonSign = { Color3.fromRGB(255, 90, 170), 10, 0.8 },
	DJBooth = { Color3.fromRGB(150, 110, 255), 12, 0.8 },
	VRPod = { Color3.fromRGB(110, 210, 255), 8, 0.6 },
	IceMachine = { Color3.fromRGB(140, 220, 255), 5, 0.3 },
	PhoneBooth = { Color3.fromRGB(255, 236, 200), 8, 0.6 },
	RoomSafe = { Color3.fromRGB(120, 255, 160), 3, 0.2 },
}
function B.addItems(ids)
	local shared = game.ReplicatedStorage:WaitForChild("Shared")
	local Catalog = require(shared:WaitForChild("Catalog"):Clone())
	local items = shared:WaitForChild("Items")
	local out = {}
	for _, id in ipairs(ids) do
		local src = PROPS:FindFirstChild(id)
		if src then
			local old = items:FindFirstChild(id)
			if old then old:Destroy() end
			local m = src:Clone()
			m.Name = id
			local it = Catalog.ITEMS[id]
			local soft = it and it.soft
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = p.Name ~= "Glass" and p.Name ~= "Glow"
					if soft then p.CollisionGroup = "NPCSolid" end
					if p.Name == "Glow" then
						local spec = GLOWS9[id] or { Color3.fromRGB(255, 226, 190), 8, 0.4 }
						p.Material = Enum.Material.Neon
						p.Color = spec[1]
						p.Transparency = 0.1
						p.CastShadow = false
						local l = Instance.new("PointLight")
						l.Color = spec[1]; l.Range = spec[2]; l.Brightness = spec[3]; l.Shadows = spec[2] >= 12
						l.Parent = p
					end
				end
			end
			m.WorldPivot = CFrame.new()
			-- round 10e: beds carry a Clean and a Messy version (HotelSim showBed). The classic bed uses
			-- BedMessy; the others get a copy of themselves with the covers in a heap
			if id == "Bed" or (it and it.coreKind == "Bed") then
				local clean = Instance.new("Model")
				clean.Name = "Clean"
				for _, c in ipairs(m:GetChildren()) do c.Parent = clean end
				clean.Parent = m
				local messy
				if id == "Bed" and PROPS:FindFirstChild("BedMessy") then
					messy = PROPS.BedMessy:Clone()
				else
					messy = clean:Clone()
					local cf, size = clean:GetBoundingBox()
					local heap = Instance.new("Part")
					heap.Name = "Heap"
					heap.Shape = Enum.PartType.Ball
					heap.Size = Vector3.new(2.6, 2.6, 2.6)
					heap.Color = Color3.fromRGB(240, 226, 204)
					heap.Material = Enum.Material.Fabric
					heap.CFrame = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2 + 2.4, cf.Position.Z + size.Z * 0.15)
					heap.Parent = messy
				end
				messy.Name = "Messy"
				for _, p in ipairs(messy:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
				end
				messy.Parent = m
			end
			m.Parent = items
			table.insert(out, id)
		end
	end
	return out
end

local function zonePart(parent, name, a, b, reason)
	local p = block(parent, name, Vector3.new(a.X, FY, a.Y), Vector3.new(b.X, FY + 10, b.Y), Color3.fromRGB(255, 80, 80), nil, {
		Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = reason ~= nil, CastShadow = false,
	})
	if reason then p:SetAttribute("Reason", reason) end
	return p
end

function B.makeZones(hotel)
	local old = hotel:FindFirstChild("BuildZones")
	if old then old:Destroy() end
	local z = folder(hotel, "BuildZones")
	local lob = zonePart(z, "Lobby", Vector2.new(-39.5, -1.5), Vector2.new(39.5, 29.6))
	lob.Size = Vector3.new(lob.Size.X, 0.2, lob.Size.Z)
	lob.Position = Vector3.new(lob.Position.X, FY, lob.Position.Z)
	local bounds = { [101] = { -39.5, -13.75 }, [102] = { -12.75, 12.75 }, [103] = { 13.75, 39.5 } }
	for _, r in ipairs(ROOMS) do
		local bx = bounds[r.id]
		local p = zonePart(z, "Room" .. r.id, Vector2.new(bx[1], -29.5), Vector2.new(bx[2], -2.5))
		p.Size = Vector3.new(p.Size.X, 0.2, p.Size.Z)
		p.Position = Vector3.new(p.Position.X, FY, p.Position.Z)
	end
	local nb = folder(z, "NoBuild")
	for _, r in ipairs(ROOMS) do
		zonePart(nb, "Doorway" .. r.id, Vector2.new(r.cx - 4, -10.5), Vector2.new(r.cx + 4, -2.5), "Keep the doorway clear")
	end
	zonePart(nb, "Entrance", Vector2.new(-5.5, 4), Vector2.new(5.5, 29.6), "Keep the entrance clear")
	zonePart(nb, "Hallway", Vector2.new(-39.5, -1.5), Vector2.new(39.5, 4.5), "Keep the hallway clear")
	zonePart(nb, "Reception", Vector2.new(-31.5, 7.5), Vector2.new(-9.5, 20.5), "Reception needs this space")
end

local function zoneNameAt(hotel, p)
	for _, z in ipairs(hotel.BuildZones:GetChildren()) do
		if z:IsA("BasePart") then
			local l = z.CFrame:PointToObjectSpace(p)
			if math.abs(l.X) <= z.Size.X / 2 and math.abs(l.Z) <= z.Size.Z / 2 then return z.Name end
		end
	end
end

-- turns the furniture the builder placed into Hotel.Placed items (movable/sellable in build mode)
local function putPlaced(hotel, id, cf, attrs)
	local m = game.ReplicatedStorage.Shared.Items[id]:Clone()
	m:PivotTo(cf)
	m:SetAttribute("Item", id)
	m:SetAttribute("Zone", zoneNameAt(hotel, cf.Position))
	if attrs then for k, v in pairs(attrs) do m:SetAttribute(k, v) end end
	m.Parent = hotel.Placed
	return m
end

-- one room's builder furniture -> Placed items (bed/shower/toilet become its core items)
function B.convertRoom(hotel, room)
	local items = game.ReplicatedStorage.Shared.Items
	local props = room:FindFirstChild("Props")
	if props then
		for _, m in ipairs(props:GetChildren()) do
			local id = m.Name
			if id == "Bed" then
				putPlaced(hotel, "Bed", m:GetPivot(), { Core = "Bed", Room = room.Name })
				m:Destroy()
			elseif id == "BedMessy" then
				m:Destroy()
			elseif id == "Shower" or id == "Toilet" then
				putPlaced(hotel, id, m:GetPivot(), { Core = id, Room = room.Name })
				m:Destroy()
			elseif items:FindFirstChild(id) then
				putPlaced(hotel, id, m:GetPivot())
				m:Destroy()
			end
		end
	end
	local mess = room:FindFirstChild("Mess")
	if mess then
		for _, p in ipairs(mess:GetDescendants()) do if p:IsA("BasePart") then p.CanQuery = false end end
	end
end

function B.convertPlaced(hotel)
	local items = game.ReplicatedStorage.Shared.Items
	local old = hotel:FindFirstChild("Placed")
	if old then old:Destroy() end
	local placed = folder(hotel, "Placed")
	local function put(id, cf, attrs) return putPlaced(hotel, id, cf, attrs) end
	for _, room in ipairs(hotel.Rooms:GetChildren()) do
		B.convertRoom(hotel, room)
	end
	for _, m in ipairs(hotel.Lobby:GetChildren()) do
		local id = m.Name
		if m:IsA("Model") and items:FindFirstChild(id) and id ~= "Desk" then
			put(id, m:GetPivot())
			m:Destroy()
		end
	end
	return placed
end

function B.setupBuild()
	local hotel = workspace.Hotel
	B.makeItems()
	B.makeZones(hotel)
	B.convertPlaced(hotel)
	B.forSale(hotel)
end

---------------------------------------------------------------- the car park (round 10e)
-- Two tarmac lots in front of the hotel, either side of the entrance path, each 44 x 22 studs, with kerbs.
-- BuildZones parts named "Parking" let build mode place ParkingSpot items there (Catalog `outdoor`), and
-- nothing else. Lot decor (trees, bushes, planters, benches) standing on them is cleared away.
B.PARKING = { { -60, -16 }, { 16, 60 } } -- x ranges; z from 33 to 55
B.PARK_Z = { 33, 55 }
function B.parking(hotel)
	useOrigin(hotel)
	local zones = hotel:FindFirstChild("BuildZones")
	if not zones or zones:FindFirstChild("Parking") then return end
	local o = hotel:GetAttribute("Origin") or Vector3.zero
	local z0, z1 = B.PARK_Z[1], B.PARK_Z[2]
	local lots = model(hotel, "CarPark")
	for _, xr in ipairs(B.PARKING) do
		local x0, x1 = xr[1], xr[2]
		-- dig the ground away above it, then tarmac level with the hotel floor and a stone kerb round it
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		-- the lawn terrain's surface sits a stud above the floor: dig it out like the hotel's footprint
		workspace.Terrain:FillBlock(CFrame.new(o + Vector3.new(cx, FY - 1, cz)), Vector3.new(x1 - x0 + 2, 8, z1 - z0 + 2), Enum.Material.Air)
		workspace.Terrain:FillBlock(CFrame.new(o + Vector3.new(cx, FY - 7, cz)), Vector3.new(x1 - x0 + 2, 4, z1 - z0 + 2), Enum.Material.Concrete)
		block(lots, "Tarmac", Vector3.new(x0, FY - 5, z0), Vector3.new(x1, FY - 0.02, z1), Color3.fromRGB(58, 60, 66), Enum.Material.Asphalt)
		block(lots, "Kerb", Vector3.new(x0 - 0.6, FY - 5, z0 - 0.6), Vector3.new(x1 + 0.6, FY + 1.1, z0), C.plinth, Enum.Material.Concrete)
		block(lots, "Kerb", Vector3.new(x0 - 0.6, FY - 5, z1), Vector3.new(x1 + 0.6, FY + 1.1, z1 + 0.6), C.plinth, Enum.Material.Concrete)
		block(lots, "Kerb", Vector3.new(x0 - 0.6, FY - 5, z0), Vector3.new(x0, FY + 1.1, z1), C.plinth, Enum.Material.Concrete)
		block(lots, "Kerb", Vector3.new(x1, FY - 5, z0), Vector3.new(x1 + 0.6, FY + 1.1, z1), C.plinth, Enum.Material.Concrete)
		local zp = zonePart(zones, "Parking", Vector2.new(x0, z0), Vector2.new(x1, z1))
		zp.Size = Vector3.new(zp.Size.X, 0.2, zp.Size.Z)
		zp.Position = Vector3.new(zp.Position.X, FY, zp.Position.Z)
		zp:SetAttribute("Outdoor", true)
		-- clear the lot's decor off it
		local city = workspace:FindFirstChild("City")
		local cityLots = city and city:FindFirstChild("Lots")
		for _, lot in ipairs(cityLots and cityLots:GetChildren() or {}) do
			for _, d in ipairs(lot:GetChildren()) do
				if d:IsA("Model") and d.Name ~= "Vacant" then
					local p = d:GetPivot().Position - o
					if p.X > x0 - 2 and p.X < x1 + 2 and p.Z > z0 - 2 and p.Z < z1 + 2 then d:Destroy() end
				end
			end
		end
	end
	for _, p in ipairs(lots:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	return lots
end

---------------------------------------------------------------- build-mode walls and doors (round 10)
-- Items.Wall: a 4-wide wallpapered partition up to the ceiling. Items.Door: the same with a doorway and a
-- plank door on a hinge (the Swing model is tagged SwingDoor like the room doors). Pivots at floor centre.
function B.structureItems()
	useOrigin(nil)
	B.materials()
	local items = game.ReplicatedStorage.Shared.Items
	local H = CEIL - FY -- 13.6: from the floor to the ceiling
	local T = 1
	local function skins(m, x0, x1, y0)
		for _, sz in ipairs({ 1, -1 }) do
			local zf = sz * T / 2
			tex(block(m, "Paper", Vector3.new(x0, y0, zf - sz * SKIN), Vector3.new(x1, H, zf), C.paper, Enum.Material.Plaster), "Paper")
			if y0 < 1 then
				block(m, "Skirting", Vector3.new(x0, 0, zf), Vector3.new(x1, 0.7, zf + sz * 0.2), C.woodDk, Enum.Material.Wood)
			end
			block(m, "Crown", Vector3.new(x0, H - 0.45, zf), Vector3.new(x1, H, zf + sz * 0.3), C.trim, Enum.Material.Plaster)
			block(m, "Crown", Vector3.new(x0, H - 0.8, zf), Vector3.new(x1, H - 0.45, zf + sz * 0.15), C.trim, Enum.Material.Plaster)
		end
	end
	-- the wall
	local old = items:FindFirstChild("Wall")
	local w = model(nil, "Wall")
	block(w, "Panel", Vector3.new(-2, 0, -T / 2 + SKIN), Vector3.new(2, H, T / 2 - SKIN), C.cream, Enum.Material.Plaster)
	skins(w, -2, 2, 0)
	-- the door: posts, a lintel, casing, and the swinging leaf
	local d = model(nil, "Door")
	local half, top, lin = 1.65, DOOR_H, 0.1
	block(d, "PostL", Vector3.new(-2, 0, -T / 2 + SKIN), Vector3.new(-half, H, T / 2 - SKIN), C.cream, Enum.Material.Plaster)
	block(d, "PostR", Vector3.new(half, 0, -T / 2 + SKIN), Vector3.new(2, H, T / 2 - SKIN), C.cream, Enum.Material.Plaster)
	block(d, "Lintel", Vector3.new(-half, top, -T / 2 + SKIN), Vector3.new(half, H, T / 2 - SKIN), C.cream, Enum.Material.Plaster)
	skins(d, -2, -half, 0)
	skins(d, half, 2, 0)
	skins(d, -half, half, top)
	local trim = model(d, "Trim")
	block(trim, "Jamb", Vector3.new(-half, 0, -T / 2), Vector3.new(-half + lin, top, T / 2), C.woodDk, Enum.Material.Wood)
	block(trim, "Jamb", Vector3.new(half - lin, 0, -T / 2), Vector3.new(half, top, T / 2), C.woodDk, Enum.Material.Wood)
	block(trim, "Head", Vector3.new(-half, top - lin, -T / 2), Vector3.new(half, top, T / 2), C.woodDk, Enum.Material.Wood)
	for _, sz in ipairs({ 1, -1 }) do
		local zf = sz * T / 2
		local zo = zf + sz * 0.26
		block(trim, "Casing", Vector3.new(-half - 0.35, 0.75, zf), Vector3.new(-half, top + 0.4, zo), C.woodDk, Enum.Material.Wood)
		block(trim, "Casing", Vector3.new(half, 0.75, zf), Vector3.new(half + 0.35, top + 0.4, zo), C.woodDk, Enum.Material.Wood)
		block(trim, "Casing", Vector3.new(-half - 0.35, top, zf), Vector3.new(half + 0.35, top + 0.4, zo), C.woodDk, Enum.Material.Wood)
		block(trim, "Plinth", Vector3.new(-half - 0.39, 0, zf), Vector3.new(-half + 0.02, 0.75, zo + sz * 0.05), C.woodDk, Enum.Material.Wood)
		block(trim, "Plinth", Vector3.new(half - 0.02, 0, zf), Vector3.new(half + 0.39, 0.75, zo + sz * 0.05), C.woodDk, Enum.Material.Wood)
	end
	block(trim, "Threshold", Vector3.new(-half, -0.02, -T / 2), Vector3.new(half, 0.05, T / 2), C.gold, Enum.Material.Metal)
	local sw = swingDoor(d, CFrame.new(-half + lin, 0.03, -T / 2 + 0.04), 2 * (half - lin), top - lin - 0.06, 0.24, 92)
	sw.Name = "Swing"
	for _, m in ipairs({ w, d }) do
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanQuery = false
				if p:IsDescendantOf(trim) or (sw and p:IsDescendantOf(sw)) then p.CanCollide = false end
			end
		end
		m.WorldPivot = CFrame.new()
		local prev = items:FindFirstChild(m.Name)
		if prev then prev:Destroy() end
		m.Parent = items
	end
	return w, d
end

---------------------------------------------------------------- more walls, windows and doors (round 10e)
-- Same 4 x ceiling x 1 footprint as Items.Wall / Items.Door, so they snap and close rooms the same way
-- (Catalog `wallKind`). Styles: brick, wood (walnut panelling under a dado rail), sage paper, and a
-- brass-framed glass partition. WallWindow* have a 2.8 x 5 window with mullions and a sill.
-- DoorWhite: a white panelled leaf; DoorGlass: a brass-framed glass leaf. HalfWall: a counter-height
-- divider with a marble cap (it doesn't close rooms).
local STYLES = {
	paper = { mat = "Paper", color = C.paper },
	brick = { mat = "Brick", color = C.brick },
	wood = { color = Color3.fromRGB(96, 60, 38), plain = Enum.Material.Wood, wood = true },
	sage = { mat = "Paper", color = C.paperRoom },
}
function B.structureVariants()
	useOrigin(nil)
	B.materials()
	local items = game.ReplicatedStorage.Shared.Items
	local H = CEIL - FY
	local T = 1
	local function face(m, st, x0, x1, y0, y1)
		for _, sz in ipairs({ 1, -1 }) do
			local zf = sz * T / 2
			local p = block(m, "Paper", Vector3.new(x0, y0, zf - sz * SKIN), Vector3.new(x1, y1, zf), st.color, st.plain or Enum.Material.Plaster)
			if st.mat then tex(p, st.mat) end
			if st.wood and y0 < 1 then
				-- walnut panels under a dado rail, paper above
				local top = math.min(y1, 4.2)
				for k = 0, 1 do
					local px0 = x0 + 0.25 + k * (x1 - x0) / 2
					local px1 = px0 + (x1 - x0) / 2 - 0.5
					if px1 > px0 then block(m, "WoodPanel", Vector3.new(px0, 1.0, zf), Vector3.new(px1, top - 0.4, zf + sz * 0.08), Color3.fromRGB(120, 78, 50), Enum.Material.Wood) end
				end
				block(m, "Dado", Vector3.new(x0, top - 0.25, zf), Vector3.new(x1, top, zf + sz * 0.18), C.woodDk, Enum.Material.Wood)
				if y1 > top then tex(block(m, "Paper", Vector3.new(x0, top, zf - sz * SKIN), Vector3.new(x1, y1, zf + sz * 0.01), C.paper, Enum.Material.Plaster), "Paper") end
			end
			if y0 < 1 then block(m, "Skirting", Vector3.new(x0, 0, zf), Vector3.new(x1, 0.7, zf + sz * 0.2), C.woodDk, Enum.Material.Wood) end
			if y1 >= H - 0.01 then
				block(m, "Crown", Vector3.new(x0, H - 0.45, zf), Vector3.new(x1, H, zf + sz * 0.3), C.trim, Enum.Material.Plaster)
				block(m, "Crown", Vector3.new(x0, H - 0.8, zf), Vector3.new(x1, H - 0.45, zf + sz * 0.15), C.trim, Enum.Material.Plaster)
			end
		end
	end
	local function core(m, x0, x1, y0, y1)
		block(m, "Panel", Vector3.new(x0, y0, -T / 2 + SKIN), Vector3.new(x1, y1, T / 2 - SKIN), C.cream, Enum.Material.Plaster)
	end
	local made = {}
	local function finish(m)
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanQuery = false
				if p:FindFirstAncestor("Trim") or p:FindFirstAncestor("Swing") then p.CanCollide = false end
			end
		end
		m.WorldPivot = CFrame.new()
		local prev = items:FindFirstChild(m.Name)
		if prev then prev:Destroy() end
		m.Parent = items
		table.insert(made, m.Name)
	end
	-- plain walls in each style
	for name, st in pairs({ WallBrick = STYLES.brick, WallWood = STYLES.wood, WallSage = STYLES.sage }) do
		local w = model(nil, name)
		core(w, -2, 2, 0, H)
		face(w, st, -2, 2, 0, H)
		finish(w)
	end
	-- window walls: a 2.8 wide, 5 tall opening from 3.6 up, mullions, a sill and pale glass
	local WX, WY0, WY1 = 1.4, 3.6, 8.6
	for name, st in pairs({ WallWindow = STYLES.paper, WallWindowBrick = STYLES.brick }) do
		local w = model(nil, name)
		core(w, -2, 2, 0, WY0)
		core(w, -2, 2, WY1, H)
		core(w, -2, -WX, WY0, WY1)
		core(w, WX, 2, WY0, WY1)
		face(w, st, -2, 2, 0, WY0)
		face(w, st, -2, 2, WY1, H)
		face(w, st, -2, -WX, WY0, WY1)
		face(w, st, WX, 2, WY0, WY1)
		local fr = model(w, "Trim")
		local f = 0.16
		block(fr, "Jamb", Vector3.new(-WX, WY0, -0.2), Vector3.new(-WX + f, WY1, 0.2), C.woodDk, Enum.Material.Wood)
		block(fr, "Jamb", Vector3.new(WX - f, WY0, -0.2), Vector3.new(WX, WY1, 0.2), C.woodDk, Enum.Material.Wood)
		block(fr, "Head", Vector3.new(-WX, WY1 - f, -0.2), Vector3.new(WX, WY1, 0.2), C.woodDk, Enum.Material.Wood)
		block(fr, "Mullion", Vector3.new(-0.06, WY0, -0.12), Vector3.new(0.06, WY1, 0.12), C.woodDk, Enum.Material.Wood)
		block(fr, "Transom", Vector3.new(-WX, WY0 + 3.3, -0.12), Vector3.new(WX, WY0 + 3.42, 0.12), C.woodDk, Enum.Material.Wood)
		for _, sz in ipairs({ 1, -1 }) do
			local z1 = sz * (T / 2 + 0.35)
			block(fr, "Sill", Vector3.new(-WX - 0.3, WY0 - 0.18, math.min(0, z1)), Vector3.new(WX + 0.3, WY0 + 0.06, math.max(0, z1)), C.trim, Enum.Material.Marble)
			local c0, c1 = sz * T / 2, sz * (T / 2 + 0.12)
			local za, zb = math.min(c0, c1), math.max(c0, c1)
			block(fr, "Casing", Vector3.new(-WX - 0.3, WY0, za), Vector3.new(-WX, WY1 + 0.3, zb), C.trim, Enum.Material.Plaster)
			block(fr, "Casing", Vector3.new(WX, WY0, za), Vector3.new(WX + 0.3, WY1 + 0.3, zb), C.trim, Enum.Material.Plaster)
			block(fr, "Casing", Vector3.new(-WX - 0.3, WY1, za), Vector3.new(WX + 0.3, WY1 + 0.3, zb), C.trim, Enum.Material.Plaster)
		end
		block(w, "Glass", Vector3.new(-WX + f, WY0 + 0.06, -0.04), Vector3.new(WX - f, WY1 - f, 0.04), Color3.fromRGB(196, 222, 232), Enum.Material.Glass, { Transparency = 0.55, CastShadow = false })
		finish(w)
	end
	-- a frosted glass partition in a brass frame
	do
		local w = model(nil, "WallGlass")
		local b = 0.18
		block(w, "Base", Vector3.new(-2, 0, -0.3), Vector3.new(2, 0.6, 0.3), C.woodDk, Enum.Material.Wood)
		block(w, "Top", Vector3.new(-2, H - 0.3, -0.3), Vector3.new(2, H, 0.3), C.gold, Enum.Material.Metal)
		for _, x in ipairs({ -2, 2 - b }) do block(w, "Post", Vector3.new(x, 0, -0.2), Vector3.new(x + b, H, 0.2), C.gold, Enum.Material.Metal) end
		block(w, "Rail", Vector3.new(-2, 4.0, -0.16), Vector3.new(2, 4.15, 0.16), C.gold, Enum.Material.Metal)
		block(w, "Glass", Vector3.new(-2 + b, 0.6, -0.06), Vector3.new(2 - b, H - 0.3, 0.06), Color3.fromRGB(226, 236, 240), Enum.Material.Glass, { Transparency = 0.35 })
		finish(w)
	end
	-- a counter-height divider
	do
		local w = model(nil, "HalfWall")
		block(w, "Body", Vector3.new(-2, 0, -0.45), Vector3.new(2, 3.8, 0.45), C.cream, Enum.Material.Plaster)
		for _, sz in ipairs({ 1, -1 }) do
			local a0, a1 = sz * 0.45, sz * 0.52
			block(w, "WoodPanel", Vector3.new(-1.7, 0.9, math.min(a0, a1)), Vector3.new(1.7, 3.2, math.max(a0, a1)), Color3.fromRGB(120, 78, 50), Enum.Material.Wood)
			local b0, b1 = sz * 0.45, sz * 0.62
			block(w, "Skirting", Vector3.new(-2, 0, math.min(b0, b1)), Vector3.new(2, 0.6, math.max(b0, b1)), C.woodDk, Enum.Material.Wood)
		end
		block(w, "Cap", Vector3.new(-2.1, 3.8, -0.7), Vector3.new(2.1, 4.1, 0.7), Color3.fromRGB(232, 228, 220), Enum.Material.Marble)
		finish(w)
	end
	-- doors: the classic, recoloured; the glass one gets a see-through leaf
	local base = items:FindFirstChild("Door")
	if base then
		for name, look in pairs({ DoorWhite = "white", DoorGlass = "glass" }) do
			local d = base:Clone()
			d.Name = name
			local sw = d:FindFirstChild("Swing")
			for _, p in ipairs(sw and sw:GetDescendants() or {}) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local small = math.max(p.Size.X, p.Size.Y, p.Size.Z) < 1.6
					if look == "white" then
						if p.Material == Enum.Material.Wood then
							p.Color = p.Name == "Plank" and Color3.fromRGB(246, 242, 234) or Color3.fromRGB(230, 224, 212)
							p.Material = Enum.Material.SmoothPlastic
						end
					elseif not small then
						if p.Name == "Plank" or p.Name == "Core" then
							p.Material = Enum.Material.Glass
							p.Color = Color3.fromRGB(210, 230, 238)
							p.Transparency = p.Name == "Core" and 1 or 0.45
						else
							p.Material = Enum.Material.Metal
							p.Color = C.gold
						end
					end
				end
			end
			finish(d)
		end
	end
	-- round 13: hotel room doors (the same 4-wide footprint, so they close rooms like Door). Each gets a cornice
	-- with a brass bead on both faces, a kick plate, a peephole and a keycard reader by the latch; the custom
	-- room adds its number plate and status lamp above. RoomDoor = walnut planks like the starter rooms,
	-- RoomDoorSuite = cream with gilt mouldings, RoomDoorModern = charcoal with a steel bar pull and an LED strip.
	if base then
		local half, top, lin, t = 1.65, DOOR_H, 0.1, 0.24
		local lz0, lz1 = -T / 2 + 0.04, -T / 2 + 0.04 + t -- the leaf's two faces (shut)
		local lx0, lx1 = -half + lin, half - lin
		local looks = {
			RoomDoor = { leaf = nil, trim = C.woodDk, metal = C.gold, cornice = C.woodDk },
			RoomDoorSuite = { leaf = Color3.fromRGB(242, 236, 222), mat = Enum.Material.SmoothPlastic, trim = Color3.fromRGB(236, 230, 216), metal = C.gold, cornice = Color3.fromRGB(236, 230, 216), gilt = true },
			RoomDoorModern = { leaf = Color3.fromRGB(46, 48, 56), mat = Enum.Material.SmoothPlastic, trim = Color3.fromRGB(34, 36, 42), metal = Color3.fromRGB(196, 202, 212), cornice = Color3.fromRGB(34, 36, 42), modern = true },
		}
		for name, lk in pairs(looks) do
			local d = base:Clone()
			d.Name = name
			local sw = d:FindFirstChild("Swing")
			local leaf = sw and sw:FindFirstChild("Leaf")
			local trim = d:FindFirstChild("Trim")
			for _, p in ipairs(d:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 and p.Material == Enum.Material.Wood then
					if trim and p:IsDescendantOf(trim) then
						p.Color = lk.trim
						if lk.mat then p.Material = lk.mat end
					elseif lk.leaf and leaf and p:IsDescendantOf(leaf) then
						p.Color = p.Name == "Plank" and lk.leaf or lk.leaf:Lerp(Color3.new(0, 0, 0), 0.08)
						p.Material = lk.mat
					end
				end
				if p:IsA("BasePart") and (p.Name == "Knob" or p.Name == "Neck" or p.Name == "Escutcheon" or p.Name == "Hinge") then p.Color = lk.metal end
			end
			if trim then
				for _, sz in ipairs({ 1, -1 }) do
					local zf = sz * T / 2
					local function zr(a, b) return math.min(zf + sz * a, zf + sz * b), math.max(zf + sz * a, zf + sz * b) end
					-- the cornice over the casing, and its bead
					local a0, a1 = zr(0, 0.48)
					block(trim, "Cornice", Vector3.new(-half - 0.6, top + 0.4, a0), Vector3.new(half + 0.6, top + 0.72, a1), lk.cornice, lk.mat or Enum.Material.Wood)
					local b0, b1 = zr(0, 0.54)
					block(trim, "CorniceBead", Vector3.new(-half - 0.66, top + 0.72, b0), Vector3.new(half + 0.66, top + 0.8, b1), lk.metal, Enum.Material.Metal)
					-- the keycard reader on the post by the latch, with a green light
					local r0, r1 = zr(0, 0.12)
					local rx = half + 0.6
					block(trim, "CardReader", Vector3.new(rx - 0.2, 3.1, r0), Vector3.new(rx + 0.2, 3.85, r1), Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic)
					local l0, l1 = zr(0.12, 0.15)
					block(trim, "CardLight", Vector3.new(rx - 0.08, 3.62, l0), Vector3.new(rx + 0.08, 3.72, l1), Color3.fromRGB(90, 230, 130), Enum.Material.Neon)
					local s0, s1 = zr(0.12, 0.14)
					block(trim, "CardSlot", Vector3.new(rx - 0.14, 3.2, s0), Vector3.new(rx + 0.14, 3.45, s1), lk.metal, Enum.Material.Metal)
					if lk.gilt then
						-- fluted pilasters on the casing
						for _, x in ipairs({ -half - 0.18, half + 0.18 }) do
							local p0, p1 = zr(0.26, 0.34)
							block(trim, "Pilaster", Vector3.new(x - 0.1, 0.8, p0), Vector3.new(x + 0.1, top + 0.3, p1), lk.metal, Enum.Material.Metal)
						end
					end
					if lk.modern then
						local e0, e1 = zr(0.48, 0.52)
						block(trim, "LEDStrip", Vector3.new(-half - 0.4, top + 0.45, e0), Vector3.new(half + 0.4, top + 0.55, e1), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
					end
				end
			end
			if leaf then
				for _, side in ipairs({ 1, -1 }) do
					local zf = side > 0 and lz1 or lz0
					local function zr(a, b) return math.min(zf + side * a, zf + side * b), math.max(zf + side * a, zf + side * b) end
					-- a brushed kick plate along the bottom
					local k0, k1 = zr(0, 0.03)
					block(leaf, "KickPlate", Vector3.new(lx0 + 0.1, 0.12, k0), Vector3.new(lx1 - 0.1, 0.9, k1), lk.metal, Enum.Material.Metal)
					-- the peephole at eye height
					local h0, h1 = zr(0, 0.05)
					block(leaf, "Peephole", Vector3.new(-0.09, 5.55, h0), Vector3.new(0.09, 5.73, h1), lk.metal, Enum.Material.Metal)
					if lk.gilt then
						-- two gilt moulded panels per face
						for _, yy in ipairs({ { 1.2, 3.6 }, { 4.1, 7.1 } }) do
							local m0, m1 = zr(0, 0.035)
							local x0, x1, y0, y1 = lx0 + 0.45, lx1 - 0.45, yy[1], yy[2]
							block(leaf, "Moulding", Vector3.new(x0, y0, m0), Vector3.new(x1, y0 + 0.07, m1), lk.metal, Enum.Material.Metal)
							block(leaf, "Moulding", Vector3.new(x0, y1 - 0.07, m0), Vector3.new(x1, y1, m1), lk.metal, Enum.Material.Metal)
							block(leaf, "Moulding", Vector3.new(x0, y0, m0), Vector3.new(x0 + 0.07, y1, m1), lk.metal, Enum.Material.Metal)
							block(leaf, "Moulding", Vector3.new(x1 - 0.07, y0, m0), Vector3.new(x1, y1, m1), lk.metal, Enum.Material.Metal)
						end
					end
					if lk.modern then
						-- a tall steel bar pull on the latch side, and a thin inlay line
						local p0, p1 = zr(0.14, 0.24)
						block(leaf, "BarPull", Vector3.new(lx1 - 0.55, 2.4, p0), Vector3.new(lx1 - 0.43, 5.2, p1), lk.metal, Enum.Material.Metal)
						for _, y in ipairs({ 2.4, 5.08 }) do
							local q0, q1 = zr(0, 0.16)
							block(leaf, "BarPost", Vector3.new(lx1 - 0.53, y, q0), Vector3.new(lx1 - 0.45, y + 0.12, q1), lk.metal, Enum.Material.Metal)
						end
						local i0, i1 = zr(0, 0.02)
						block(leaf, "Inlay", Vector3.new(lx0 + 0.6, 1.0, i0), Vector3.new(lx0 + 0.66, 7.0, i1), lk.metal, Enum.Material.Metal)
					end
				end
				-- the modern leaf hides its knobs (the bar pull does the job)
				if lk.modern then
					for _, p in ipairs(leaf:GetDescendants()) do
						if p:IsA("BasePart") and (p.Name == "Knob" or p.Name == "Neck" or p.Name == "Escutcheon") then p:Destroy() end
					end
				end
			end
			finish(d)
		end
	end
	return made
end

---------------------------------------------------------------- wings: rooms you buy (round 3)
-- Wing k on side s (1 = east, -1 = west) sits outside the current side wall: interior |x| from
-- e = 40.5 + 26.5 (k - 1) to o = e + 25.5, outer wall o..o + 1. Room at the back, more lobby in front.

local function wingGeom(slot)
	local s = slot.side
	local e = 40.5 + 26.5 * (slot.k - 1)
	local o = e + 25.5
	return s, e, o, s * (e + 12.75)
end
B.wingGeom = wingGeom

-- the next room you can buy (slots go in order)
function B.nextSlot(hotel)
	for _, slot in ipairs(require(game.ReplicatedStorage.Shared.Config).ROOM_SLOTS) do
		if not hotel.Rooms:FindFirstChild("Room" .. slot.id) and not hotel.Shell:FindFirstChild("Wing" .. slot.id) then return slot end
	end
end

function B.buildWing(hotel, slot)
	useOrigin(hotel)
	B.materials()
	local s, e, o, cx = wingGeom(slot)
	local sh = hotel.Shell
	local wm = model(sh, "Wing" .. slot.id)
	-- knock out the old outer wall on this side (both segments, with their quoins and decor); its room
	-- part comes back as a divider, and a short panelled join closes the corridor wall
	local old = s > 0 and "WallRight" or "WallLeft"
	for _, d in ipairs(sh:GetDescendants()) do
		local legacy = d:IsA("BasePart") and (d.Name == old .. "Cap" or d.Name == old .. "Base" or d.Name == old .. "Brick")
		if (d.Name == old and (d:IsA("Model") or d:IsA("BasePart"))) or legacy then d:Destroy() end
	end
	wall(wm, "Divider", Vector2.new(s * (e - 1), -29.5), Vector2.new(s * e, -2.5))
	wall(wm, "FrontJoin", Vector2.new(s * (e - 1), -2.5), Vector2.new(s * e, -1.5), nil, { { Vector2.new(0, 1), "lobby" } }, { lift = 0.02 })
	-- plinth, lobby floor, back wall, the new outer wall
	block(wm, "Plinth", Vector3.new(s * (e + 1), -1, -31.5), Vector3.new(s * (o + 2), FY - 0.4, 31.5), C.lime, Enum.Material.Limestone)
	tex(block(wm, "LobbyFloor", Vector3.new(s * e, FY - 0.4, -2.5), Vector3.new(s * (o + 1), FY, 30), Color3.fromRGB(255, 255, 255)), "Checker")
	wall(wm, "WallBack", Vector2.new(s * e, -30.5), Vector2.new(s * (o + 1), -29.5), Vector2.new(0, -1), { { Vector2.new(0, 1), "room" } },
		{ ext = s > 0 and { -0.3, 0.3 } or { 0.3, -0.3 } })
	sideWall(wm, old, s * o, s, slot.k % 2 == 1 and PAL_B or PAL_A)
	roomFront(wm, slot.id, cx, s * e, s * o)
	-- the corridor runner carries on to the new door
	hallCarpet(wm, s * (e - 7.75), s * (e + 18.75))
	-- the street front: more windows
	local fa, fb = s * (e + 0.3), s * (o + 1.3)
	if s > 0 then frontRun(wm, fa, fb, { wa = 0.2 }) else frontRun(wm, fb, fa, { wb = 0.2 }) end
	-- outside: no grass under the wing, paving round it, planters in front
	local t = workspace.Terrain
	local mid = s * (e + o) / 2
	t:FillBlock(CFrame.new(mid, 0, 0) + OX, Vector3.new(o - e + 20, 8, 76), Enum.Material.Air)
	t:FillBlock(CFrame.new(mid, -6, 0) + OX, Vector3.new(o - e + 20, 4, 76), Enum.Material.Concrete)
	-- outdoor bits belong to the hotel, so they go when the plot is freed
	local out = hotel:FindFirstChild("Outdoor") or model(hotel, "Outdoor")
	block(out, "Apron" .. slot.id, Vector3.new(s * (e - 2), -4, -38), Vector3.new(s * (o + 8), 0, 38), Color3.fromRGB(214, 210, 202), Enum.Material.Pavement)
	local kit = game.ServerStorage:FindFirstChild("CityProps")
	for _, dx in ipairs({ -8, 0, 8 }) do
		if kit and kit:FindFirstChild("Planter") then
			local pl = kit.Planter:Clone()
			pl:PivotTo(CFrame.new(cx + dx, 0, 34) + OX)
			pl.Parent = out
		else
			part(out, "Planter", Vector3.new(6.5, 1.6, 3), CFrame.new(cx + dx, 0.8, 34), Color3.fromRGB(226, 220, 210), Enum.Material.Concrete)
		end
	end
	-- build zones: the room, its doorway, and the lobby/hallway stretched to the new width
	local zones = hotel.BuildZones
	local rz = zonePart(zones, "Room" .. slot.id, Vector2.new(s * e, -29.5), Vector2.new(s * o, -2.5))
	rz.Size = Vector3.new(rz.Size.X, 0.2, rz.Size.Z)
	rz.Position = Vector3.new(rz.Position.X, FY + OX.Y, rz.Position.Z)
	zonePart(zones.NoBuild, "Doorway" .. slot.id, Vector2.new(cx - 4, -10.5), Vector2.new(cx + 4, -2.5), "Keep the doorway clear")
	local minX = s < 0 and -o or (hotel:GetAttribute("MinX") or -39.5)
	local maxX = s > 0 and o or (hotel:GetAttribute("MaxX") or 39.5)
	hotel:SetAttribute("MinX", minX)
	hotel:SetAttribute("MaxX", maxX)
	for _, zp in ipairs({ zones.Lobby, zones.NoBuild.Hallway }) do
		zp.Size = Vector3.new(maxX - minX, zp.Size.Y, zp.Size.Z)
		zp.Position = Vector3.new((minX + maxX) / 2 + OX.X, zp.Position.Y, zp.Position.Z)
	end
	-- the room itself: an unfurnished shell the player dresses with bought furniture
	local room = buildRoom(hotel, { id = slot.id, cx = cx }, true)
	B.convertRoom(hotel, room)
	B.roof(hotel)
	return room
end

---------------------------------------------------------------- land you buy (round 10d)
-- A land plot is a wing with no room in it: open floor from the back wall to the street, part of the lobby.
-- The player makes rooms on it with Wall and Door items (Rooms finds the enclosed spaces).
function B.buildLand(hotel, slot)
	useOrigin(hotel)
	B.materials()
	local s, e, o, cx = wingGeom(slot)
	local sh = hotel.Shell
	local wm = model(sh, "Wing" .. slot.id)
	wm:SetAttribute("Land", true)
	local old = s > 0 and "WallRight" or "WallLeft"
	for _, d in ipairs(sh:GetDescendants()) do
		local legacy = d:IsA("BasePart") and (d.Name == old .. "Cap" or d.Name == old .. "Base" or d.Name == old .. "Brick")
		if (d.Name == old and (d:IsA("Model") or d:IsA("BasePart"))) or legacy then d:Destroy() end
	end
	-- a divider only where a guest room is next door (open floor carries straight on into earlier land)
	local prevRoom = slot.k == 1
	if not prevRoom then
		for _, ps in ipairs(require(game.ReplicatedStorage.Shared.Config).ROOM_SLOTS) do
			if ps.side == slot.side and ps.k == slot.k - 1 then prevRoom = hotel.Rooms:FindFirstChild("Room" .. ps.id) ~= nil end
		end
	end
	if prevRoom then
		wall(wm, "Divider", Vector2.new(s * (e - 1), -29.5), Vector2.new(s * e, -2.5))
		wall(wm, "FrontJoin", Vector2.new(s * (e - 1), -2.5), Vector2.new(s * e, -1.5), nil, { { Vector2.new(0, 1), "lobby" } }, { lift = 0.02 })
	else
		tex(block(wm, "LandJoin", Vector3.new(s * (e - 1.2), FY - 0.4, -29.5), Vector3.new(s * (e + 0.2), FY, 30), Color3.fromRGB(255, 255, 255)), "Checker")
	end
	block(wm, "Plinth", Vector3.new(s * (e + 1), -1, -31.5), Vector3.new(s * (o + 2), FY - 0.4, 31.5), C.lime, Enum.Material.Limestone)
	tex(block(wm, "LobbyFloor", Vector3.new(s * e, FY - 0.4, -29.5), Vector3.new(s * (o + 1), FY, 30), Color3.fromRGB(255, 255, 255)), "Checker")
	wall(wm, "WallBack", Vector2.new(s * e, -30.5), Vector2.new(s * (o + 1), -29.5), Vector2.new(0, -1), { { Vector2.new(0, 1), "lobby" } },
		{ ext = s > 0 and { -0.3, 0.3 } or { 0.3, -0.3 } })
	sideWall(wm, old, s * o, s, slot.k % 2 == 1 and PAL_B or PAL_A)
	local fa, fb = s * (e + 0.3), s * (o + 1.3)
	if s > 0 then frontRun(wm, fa, fb, { wa = 0.2 }) else frontRun(wm, fb, fa, { wb = 0.2 }) end
	local t = workspace.Terrain
	local mid = s * (e + o) / 2
	t:FillBlock(CFrame.new(mid, 0, 0) + OX, Vector3.new(o - e + 20, 8, 76), Enum.Material.Air)
	t:FillBlock(CFrame.new(mid, -6, 0) + OX, Vector3.new(o - e + 20, 4, 76), Enum.Material.Concrete)
	local out = hotel:FindFirstChild("Outdoor") or model(hotel, "Outdoor")
	block(out, "Apron" .. slot.id, Vector3.new(s * (e - 2), -4, -38), Vector3.new(s * (o + 8), 0, 38), Color3.fromRGB(214, 210, 202), Enum.Material.Pavement)
	local kit = game.ServerStorage:FindFirstChild("CityProps")
	for _, dx in ipairs({ -8, 0, 8 }) do
		if kit and kit:FindFirstChild("Planter") then
			local pl = kit.Planter:Clone()
			pl:PivotTo(CFrame.new(cx + dx, 0, 34) + OX)
			pl.Parent = out
		else
			part(out, "Planter", Vector3.new(6.5, 1.6, 3), CFrame.new(cx + dx, 0.8, 34), Color3.fromRGB(226, 220, 210), Enum.Material.Concrete)
		end
	end
	-- build zones: the back of the land joins the lobby (also named Lobby, so things can straddle the seam)
	local zones = hotel.BuildZones
	local xa, xb = s * (prevRoom and e or e - 1), s * o
	local lz = zonePart(zones, "Lobby", Vector2.new(math.min(xa, xb), -29.5), Vector2.new(math.max(xa, xb), -1.5))
	lz.Size = Vector3.new(lz.Size.X, 0.2, lz.Size.Z)
	lz.Position = Vector3.new(lz.Position.X, FY + OX.Y, lz.Position.Z)
	lz:SetAttribute("Land", slot.id)
	local minX = s < 0 and -o or (hotel:GetAttribute("MinX") or -39.5)
	local maxX = s > 0 and o or (hotel:GetAttribute("MaxX") or 39.5)
	hotel:SetAttribute("MinX", minX)
	hotel:SetAttribute("MaxX", maxX)
	for _, zp in ipairs(zones:GetChildren()) do
		if zp.Name == "Lobby" and zp:GetAttribute("Land") == nil then
			zp.Size = Vector3.new(maxX - minX, zp.Size.Y, zp.Size.Z)
			zp.Position = Vector3.new((minX + maxX) / 2 + OX.X, zp.Position.Y, zp.Position.Z)
		end
	end
	B.roof(hotel)
	return wm
end

-- a guest room the player walled off (Rooms finds it). info: x0, x1, z0, z1 (plot space, the floor
-- inside the walls), door (the Placed Door item), dcf (its pivot, plot space), n (plot-space unit vector from
-- the lobby into the room). Same parts as a built room: Floor, Nav, CleanSpots, Mess, DoorFrame, plus DoorRef.
function B.customRoom(hotel, id, info)
	useOrigin(hotel)
	B.materials()
	local m = model(nil, "Room" .. id)
	m:SetAttribute("RoomId", id)
	m:SetAttribute("State", "Unfurnished")
	m:SetAttribute("Custom", true)
	local x0, x1, z0, z1 = info.x0, info.x1, info.z0, info.z1
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local f = tex(block(m, "Floor", Vector3.new(x0 - 0.5, FY - 0.02, z0 - 0.5), Vector3.new(x1 + 0.5, FY + 0.03, z1 + 0.5), Color3.fromRGB(255, 255, 255)), "Chevron")
	f.CanCollide, f.CanQuery, f.CanTouch = false, false, false
	local n = info.n
	local dp = info.dcf.Position
	local dpf = Vector3.new(dp.X, FY, dp.Z)
	local nav = folder(m, "Nav")
	local mid = CFrame.new(cx, FY + 3, cz)
	spot(nav, "Door", CFrame.new(dpf - n * 2.6 + Vector3.new(0, 3, 0)))
	spot(nav, "Enter", CFrame.new(dpf + n * 3 + Vector3.new(0, 3, 0)))
	for _, k in ipairs({ "BedSide", "BedLie", "ShowerIn", "ShowerFront", "ToiletFront", "ToiletSit" }) do spot(nav, k, mid) end
	spot(nav, "Wander", mid, { Look = Vector3.new(cx, FY + 3, cz) + n * 4 })
	local clean = folder(m, "CleanSpots")
	spot(clean, "Bed", mid, { Task = "Bed", Label = "Make the bed" })
	spot(clean, "Shower", mid, { Task = "Shower", Label = "Scrub the shower" })
	spot(clean, "Toilet", mid, { Task = "Toilet", Label = "Clean the toilet" })
	spot(clean, "Floor", CFrame.new(cx + (x1 - x0) * 0.15, FY + 1.5, cz), { Task = "Floor", Label = "Pick up trash" })
	local mess = model(m, "Mess")
	mess:SetAttribute("DirtyOnly", true)
	local w, d = math.max((x1 - x0) / 2 - 1.5, 0), math.max((z1 - z0) / 2 - 1.5, 0)
	place("Towel", mess, CFrame.new(cx - w * 0.5, FY + 0.07, cz + d * 0.4) * CFrame.Angles(0, 0.6, 0))
	place("Trash", mess, CFrame.new(cx + w * 0.6, FY, cz - d * 0.5) * CFrame.Angles(0, 1.2, 0))
	place("Trash", mess, CFrame.new(cx + w * 0.15, FY, cz + d * 0.1) * CFrame.Angles(0, -0.4, 0))
	for _, p in ipairs(mess:GetDescendants()) do if p:IsA("BasePart") then p.CanQuery = false end end
	-- the frame bits the sim needs: a threshold in the doorway and the number over it
	-- round 19: the status lamp is gone — RoomStatus hangs a "Please tidy" hanger on the door instead
	local fr = model(m, "DoorFrame")
	part(fr, "Threshold", Vector3.new(3.3, 0.07, 1), CFrame.new(dpf) * info.dcf.Rotation, C.gold, nil, { Transparency = 1 })
	local face = dpf - n * 0.55
	local starterDoor = info.door and info.door:GetAttribute("StarterDoor")
	local ly = FY + DOOR_H + (starterDoor and 1.33 or 0.95)
	local look = CFrame.lookAt(Vector3.new(face.X, ly, face.Z), Vector3.new(face.X, ly, face.Z) - n)
	if not (starterDoor and B.leafNumber and B.leafNumber(info.door, id, -n)) then
		local plate = part(fr, "NumberPlate", Vector3.new(1.9, 0.95, 0.08), look * CFrame.new(0, 1.25, -0.06), Color3.fromRGB(34, 36, 40), Enum.Material.Slate)
		local _, tl = textSign(plate, Enum.NormalId.Front, tostring(id), { color = Color3.fromRGB(236, 200, 120), pps = 80, light = 0.3 })
		tl.FontFace = SERIF
		part(fr, "PlateEdge", Vector3.new(2.04, 1.09, 0.05), look * CFrame.new(0, 1.25, -0.02), C.gold, Enum.Material.Metal)
	end
	quiet(fr)
	local ref = Instance.new("ObjectValue")
	ref.Name = "DoorRef"
	ref.Value = info.door
	ref.Parent = m
	local rz = zonePart(hotel.BuildZones, "Room" .. id, Vector2.new(x0 - 0.6, z0 - 0.6), Vector2.new(x1 + 0.6, z1 + 0.6))
	rz.Size = Vector3.new(rz.Size.X, 0.2, rz.Size.Z)
	rz.Position = Vector3.new(rz.Position.X, FY + OX.Y, rz.Position.Z)
	rz:SetAttribute("Custom", true)
	m.Parent = hotel.Rooms
	return m
end

-- round 10: no more fenced "for sale" lot; the next room is bought from build mode. Clears an old one.
function B.forSale(hotel)
	local old = hotel:FindFirstChild("ForSale")
	if old then old:Destroy() end
end

function B.build()
	useOrigin(nil)
	local old = workspace:FindFirstChild("Hotel")
	if old then old:Destroy() end
	local o2 = workspace:FindFirstChild("Outside")
	if o2 then o2:Destroy() end
	for _, n in ipairs({ "Baseplate", "SpawnLocation" }) do
		local p = workspace:FindFirstChild(n)
		if p then p.Parent = nil end
	end
	local hotel = model(workspace, "Hotel")
	folder(hotel, "Rooms")
	buildShell(hotel)
	task.wait()
	buildLobby(hotel)
	lobbyFurniture(hotel.Lobby)
	task.wait()
	for _, r in ipairs(ROOMS) do
		buildRoom(hotel, r)
		task.wait()
	end
	buildOutside(hotel)
	local sp = Instance.new("SpawnLocation")
	sp.Name = "Spawn"
	sp.Anchored = true
	sp.Size = Vector3.new(6, 0.2, 6)
	sp.CFrame = CFrame.new(0, 0.35, 48)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Neutral = true
	sp.Duration = 0
	sp.Parent = workspace
	B.lighting()
	B.setupBuild()
	B.roof(hotel)
	return hotel
end


---------------------------------------------------------------- round 14: the plain starter look
-- The shell was a boutique hotel (marble, emerald panelling, brass, chandeliers). A first hotel should look
-- like a roadside inn: painted plaster, a pine wainscot, a plank floor, carpeted rooms, plain ceiling lights.
-- B.starterStyle(hotel) restyles the built parts by name (idempotent, skips Placed: the player's furniture).
-- B.roof and B.customRoom run it, so new wings and custom rooms match.
B.PLAIN = {
	wallLobby = Color3.fromRGB(236, 226, 204), wallRoom = Color3.fromRGB(226, 228, 216),
	pine = Color3.fromRGB(196, 156, 108), pineDk = Color3.fromRGB(146, 104, 68),
	floor = Color3.fromRGB(170, 128, 86), carpet = Color3.fromRGB(118, 124, 134), runner = Color3.fromRGB(126, 64, 58),
	tile = Color3.fromRGB(226, 226, 220), nickel = Color3.fromRGB(172, 174, 178), ceiling = Color3.fromRGB(242, 240, 234),
	laminate = Color3.fromRGB(198, 160, 114), counter = Color3.fromRGB(234, 230, 220),
}
local function isGold(c)
	return math.abs(c.R - C.gold.R) + math.abs(c.G - C.gold.G) + math.abs(c.B - C.gold.B) < 0.25
end
local function flushLight(parent, pos)
	local P = B.PLAIN
	local m = model(parent, "CeilingLight")
	local down = CFrame.Angles(0, 0, math.rad(90))
	part(m, "Base", Vector3.new(0.16, 2.7, 2.7), CFrame.new(pos - Vector3.new(0, 0.08, 0)) * down, P.nickel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	part(m, "Shade", Vector3.new(0.5, 2.3, 2.3), CFrame.new(pos - Vector3.new(0, 0.4, 0)) * down, Color3.fromRGB(250, 244, 230), Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.12, CastShadow = false })
	local core = part(m, "Core", Vector3.new(0.3, 1.7, 1.7), CFrame.new(pos - Vector3.new(0, 0.42, 0)) * down, C.warm, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CastShadow = false })
	part(m, "Knob", Vector3.new(0.14, 0.3, 0.3), CFrame.new(pos - Vector3.new(0, 0.72, 0)) * down, P.nickel, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local l = Instance.new("PointLight")
	l.Color = C.warm; l.Range = 26; l.Brightness = 1; l.Shadows = true
	l.Parent = core
	return quiet(m)
end
B.flushLight = flushLight
function B.starterStyle(hotel)
	hotel = hotel or workspace.Hotel
	local origin = hotel:GetAttribute("Origin") or Vector3.zero
	local saved = OX
	OX = Vector3.zero
	local P = B.PLAIN
	local placed = hotel:FindFirstChild("Placed")
	-- chandeliers become plain flush lights (same spot under the ceiling)
	for _, m in ipairs(hotel:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Chandelier" and not (placed and m:IsDescendantOf(placed)) then
			local rose = m:FindFirstChild("Rose")
			local pos = rose and rose.Position or m:GetPivot().Position
			flushLight(m.Parent, Vector3.new(pos.X, origin.Y + CEIL, pos.Z))
			m:Destroy()
		end
	end
	local kill = {}
	for _, d in ipairs(hotel:GetDescendants()) do
		if not d:IsA("BasePart") or (placed and d:IsDescendantOf(placed)) then continue end
		local n = d.Name
		local rel = d.Position - origin
		local lobby = rel.Z > -2.2
		local mv = d.MaterialVariant
		local inShell = d:FindFirstAncestor("Shell") ~= nil
		local inDesk = d:FindFirstAncestor("Desk") ~= nil
		if mv == "Paper" then
			d.Material, d.MaterialVariant = Enum.Material.Plaster, ""
			d.Color = lobby and P.wallLobby or P.wallRoom
		elseif n == "LobbyFloor" or mv == "Checker" then
			d.Material, d.MaterialVariant = Enum.Material.WoodPlanks, ""
			d.Color = P.floor
		elseif mv == "Chevron" then
			d.Material, d.MaterialVariant = Enum.Material.Fabric, ""
			d.Color = P.carpet
		elseif mv == "Hex" then
			d.Material, d.MaterialVariant = Enum.Material.CeramicTiles, ""
			d.Color = P.tile
		elseif mv == "Carpet" then
			d.Material, d.MaterialVariant = Enum.Material.Fabric, ""
			d.Color = P.runner
		elseif n == "PartitionCap" then
			d.Material, d.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(240, 240, 236)
		elseif n == "CarpetEdge" or n == "Border" or n == "Inlay" or n == "PanelRail" or n == "Beam" or n == "BeamBead" then
			table.insert(kill, d)
		elseif inShell and n == "Stile" and d.Material == Enum.Material.Wood then
			table.insert(kill, d)
		elseif inShell and n == "Rail" and d.Material == Enum.Material.Metal then
			table.insert(kill, d)
		elseif inShell and n == "Crown" and math.min(d.Size.X, d.Size.Z) < 0.2 then
			table.insert(kill, d)
		elseif inShell and n == "Panel" and d.Material == Enum.Material.Wood then
			d.Color = P.pine
		elseif inShell and (n == "Cap" or n == "Skirting") and d.Material == Enum.Material.Wood then
			d.Color = lobby and P.pineDk or Color3.fromRGB(240, 236, 226)
		elseif n == "Ceiling" and d.Material == Enum.Material.Plaster then
			d.Color = P.ceiling
		elseif inDesk and d:FindFirstAncestor("Body") then
			if n == "Top" or n == "Ledge" then
				d.Material, d.Color, d.Reflectance = Enum.Material.SmoothPlastic, P.counter, 0
			elseif n == "Front" or n == "Side" or n == "Pedestal" then
				d.Material, d.Color = Enum.Material.Wood, P.laminate
			elseif n == "Inset" or n == "Panel" then
				d.Material, d.Color = Enum.Material.Wood, P.pine
			elseif n == "Plinth" then
				d.Material, d.Color = Enum.Material.SmoothPlastic, Color3.fromRGB(70, 64, 58)
			elseif n == "Drawer" then
				d.Color = Color3.fromRGB(176, 138, 96)
			end
		elseif inDesk and n == "LampShade" then
			d.Color = Color3.fromRGB(236, 222, 190)
		end
		-- brass everywhere becomes plain brushed nickel
		if d.Material == Enum.Material.Metal and isGold(d.Color) and (n == "Trim" or not d:FindFirstAncestor("Roof")) then
			d.Color = P.nickel
			d.Reflectance = math.min(d.Reflectance, 0.1)
		end
	end
	for _, d in ipairs(kill) do d:Destroy() end
	OX = saved
	return hotel
end
do
	local roof0 = B.roof
	B.roof = function(hotel, ...)
		local r = roof0(hotel, ...)
		pcall(B.starterStyle, hotel)
		return r
	end
	local custom0 = B.customRoom
	B.customRoom = function(hotel, ...)
		local r = custom0(hotel, ...)
		pcall(B.starterStyle, hotel)
		return r
	end
end

-- round 14: the starter furniture, thinned out to what a first inn has (run in Edit on the template hotel)
function B.starterLayout(hotel)
	hotel = hotel or workspace.Hotel
	local placed = hotel.Placed
	local function at(id, zone)
		local out = {}
		for _, m in ipairs(placed:GetChildren()) do
			if m:GetAttribute("Item") == id and m:GetAttribute("Zone") == zone then table.insert(out, m) end
		end
		table.sort(out, function(a, b) return a:GetPivot().X < b:GetPivot().X end)
		return out
	end
	local removed = {}
	local function drop(m)
		if m then table.insert(removed, m.Name .. "@" .. tostring(m:GetAttribute("Zone"))); m:Destroy() end
	end
	-- lobby: one sofa, one plant, one floor lamp, no potted trees
	local sofas = at("Sofa", "Lobby")
	if #sofas >= 2 then drop(sofas[#sofas]) end
	for _, m in ipairs(at("PottedTree", "Lobby")) do drop(m) end
	local plants = at("Plant", "Lobby")
	if #plants >= 2 then drop(plants[1]) end
	local lamps = at("FloorLamp", "Lobby")
	if #lamps >= 2 then
		table.sort(lamps, function(a, b) return a:GetPivot().X > b:GetPivot().X end)
		drop(lamps[1])
	end
	-- rooms: the bed, one nightstand, the wardrobe and the bathroom
	for _, zone in ipairs(hotel.BuildZones:GetChildren()) do
		if zone:IsA("BasePart") and string.match(zone.Name, "^Room%d+$") then
			local z = zone.Name
			for _, id in ipairs({ "Plant", "FloorLamp", "Rug" }) do
				for _, m in ipairs(at(id, z)) do drop(m) end
			end
			local bed = at("Bed", z)[1]
			local ns = at("Nightstand", z)
			if bed and #ns >= 1 then
				local bp = bed:GetPivot()
				local keep = ns[1] -- the one on the low-X side (away from the bathroom)
				for i = 2, #ns do drop(ns[i]) end
				local piv = keep:GetPivot()
				keep:PivotTo(CFrame.new(bp.X - 4.3, piv.Y, piv.Z) * piv.Rotation)
			end
		end
	end
	return removed
end


-- round 14: the build-mode Room Door is the starter rooms' door exactly: the same walnut plank leaf (knob,
-- escutcheons, hinges), the same jambs, wide casings on plinth blocks, a cornice over the corridor face and a
-- threshold, in the same plain nickel. +Z is the corridor face; the leaf swings 92 degrees into the room.
-- The custom room then puts the number plate on the leaf and the status lamp over the cornice, as the
-- starter rooms have them (B.customRoom).
function B.matchRoomDoor()
	useOrigin(nil)
	local items = game.ReplicatedStorage.Shared.Items
	local base = items:FindFirstChild("Door")
	if not base then return false end
	local NICKEL = B.PLAIN.nickel
	local d = base:Clone()
	d.Name = "RoomDoor"
	for _, n in ipairs({ "Trim", "Swing" }) do
		local o = d:FindFirstChild(n)
		if o then o:Destroy() end
	end
	local T = 1
	local half, lin, cw = 1.65, 0.12, 0.55
	local xl, xr, top = -half, half, DOOR_H
	local z0, z1 = -T / 2, T / 2
	local fr = model(d, "Trim")
	local wood, dk = Enum.Material.Wood, C.woodDk
	block(fr, "Jamb", Vector3.new(xl, 0, z0), Vector3.new(xl + lin, top, z1), dk, wood)
	block(fr, "Jamb", Vector3.new(xr - lin, 0, z0), Vector3.new(xr, top, z1), dk, wood)
	block(fr, "Head", Vector3.new(xl, top - lin, z0), Vector3.new(xr, top, z1), dk, wood)
	block(fr, "Stop", Vector3.new(xl + lin, top - lin - 0.08, z0 + 0.32), Vector3.new(xr - lin, top - lin, z0 + 0.42), dk, wood)
	for _, side in ipairs({ 1, -1 }) do
		local zf = side > 0 and z1 or z0
		local zo = zf + side * 0.3
		local function zz(a, b) return math.min(a, b), math.max(a, b) end
		local c0, c1 = zz(zf, zo)
		block(fr, "Casing", Vector3.new(xl - cw, 0.75, c0), Vector3.new(xl, top + cw, c1), dk, wood)
		block(fr, "Casing", Vector3.new(xr, 0.75, c0), Vector3.new(xr + cw, top + cw, c1), dk, wood)
		block(fr, "Casing", Vector3.new(xl - cw, top, c0), Vector3.new(xr + cw, top + cw, c1), dk, wood)
		local p0, p1 = zz(zf, zo + side * 0.06)
		block(fr, "Plinth", Vector3.new(xl - cw - 0.04, 0, p0), Vector3.new(xl + 0.02, 0.75, p1), dk, wood)
		block(fr, "Plinth", Vector3.new(xr - 0.02, 0, p0), Vector3.new(xr + cw + 0.04, 0.75, p1), dk, wood)
		do -- the cornice on both faces (a door may be turned either way round)
			local k0, k1 = zz(zf, zf + side * 0.5)
			block(fr, "Cornice", Vector3.new(xl - cw - 0.25, top + cw, k0), Vector3.new(xr + cw + 0.25, top + cw + 0.3, k1), dk, wood)
			local b0, b1 = zz(zf, zf + side * 0.56)
			block(fr, "CorniceBead", Vector3.new(xl - cw - 0.3, top + cw + 0.3, b0), Vector3.new(xr + cw + 0.3, top + cw + 0.4, b1), NICKEL, Enum.Material.Metal)
		end
	end
	block(fr, "Threshold", Vector3.new(xl, -0.02, z0), Vector3.new(xr, 0.05, z1), NICKEL, Enum.Material.Metal)
	-- the leaf, shut against the room face (-Z), hinged on the left as seen from the corridor
	local t = 0.26
	local hingeCF = CFrame.new(xl + lin, 0.03, z0 + 0.04)
	local sw = model(d, "Swing")
	local hinge = part(sw, "Pivot", Vector3.new(0.2, 0.2, 0.2), hingeCF, NICKEL, nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	sw.PrimaryPart = hinge
	local leaf = model(sw, "Leaf")
	local w, h = (xr - lin) - (xl + lin), DOOR_H - lin - 0.06
	plankLeaf(leaf, hingeCF, w, h, t, nil)
	sw:SetAttribute("Swing", 92)
	sw:SetAttribute("NavOpen", true)
	sw:SetAttribute("LeafW", w)
	sw:SetAttribute("LeafH", h)
	sw:SetAttribute("LeafT", t)
	CS:AddTag(sw, "SwingDoor")
	d:SetAttribute("StarterDoor", true)
	for _, p in ipairs(d:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanQuery = false
			if p:FindFirstAncestor("Trim") or p:FindFirstAncestor("Swing") then p.CanCollide = false end
			if p.Material == Enum.Material.Metal and isGold(p.Color) then p.Color = NICKEL end
		end
	end
	d.WorldPivot = CFrame.new()
	local prev = items:FindFirstChild("RoomDoor")
	if prev then prev:Destroy() end
	d.Parent = items
	B.plainItems()
	return true
end

-- round 14: the build-mode walls and doors wear the starter hotel's plain painted plaster, not the old wallpaper
function B.plainItems()
	local items = game.ReplicatedStorage.Shared.Items
	for _, m in ipairs(items:GetChildren()) do
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.MaterialVariant == "Paper" then
				p.Material, p.MaterialVariant = Enum.Material.Plaster, ""
				p.Color = B.PLAIN.wallLobby
			end
		end
	end
end

-- the starter door's number plate, on the corridor face of a Room Door item's leaf (custom rooms)
function B.leafNumber(doorItem, number, outward)
	local sw = doorItem and doorItem:FindFirstChild("Swing")
	local leaf = sw and sw:FindFirstChild("Leaf")
	local pivot = sw and sw:FindFirstChild("Pivot")
	local w, h, t = sw and sw:GetAttribute("LeafW"), sw and sw:GetAttribute("LeafH"), sw and sw:GetAttribute("LeafT")
	if not (leaf and pivot and w) then return false end
	local old = leaf:FindFirstChild("NumberPlate")
	if old then old:Destroy() end
	local old2 = leaf:FindFirstChild("PlateEdge")
	if old2 then old2:Destroy() end
	local saved = OX
	OX = Vector3.zero
	local hinge = pivot.CFrame
	-- the leaf's +Z face is the corridor one unless the door was turned the other way round
	local out = (not outward or (-hinge.LookVector):Dot(outward) >= 0)
	local zp, ze = out and t + 0.03 or -0.03, out and t + 0.015 or -0.015
	local plate = part(leaf, "NumberPlate", Vector3.new(1.7, 0.85, 0.06), hinge * CFrame.new(w / 2, h - 1.625, zp), Color3.fromRGB(34, 36, 40), Enum.Material.Slate)
	local _, tl = textSign(plate, out and Enum.NormalId.Back or Enum.NormalId.Front, tostring(number), { color = Color3.fromRGB(236, 200, 120), pps = 80, light = 0.3 })
	tl.FontFace = SERIF
	part(leaf, "PlateEdge", Vector3.new(1.84, 0.99, 0.05), hinge * CFrame.new(w / 2, h - 1.625, ze), B.PLAIN.nickel, Enum.Material.Metal)
	for _, p in ipairs({ plate, leaf.PlateEdge }) do p.CanCollide = false; p.CanQuery = false; p.CanTouch = false end
	OX = saved
	return true
end

return B
