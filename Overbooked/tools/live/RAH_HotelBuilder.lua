-- Run a Hotel edit-time builder: the hotel shell, lobby, three rooms and their nav spots.
-- Run from execute_luau: loadstring(HttpService:GetAsync("http://127.0.0.1:8791/HotelBuilder.lua"))().build()
-- Floor top is y = 1. Lobby z 0..30 (glass front at z = 30), rooms z -30..-2, x -40..40.
-- At run time RAH_Plots clones this hotel onto each plot; wings and the for-sale lot are built at the plot's Origin.
local B = {}

local PROPS = game.ServerStorage:WaitForChild("HotelProps")
local FY = 1 -- floor top
-- every part, prop and spot is shifted by OX: the plot's Origin while building a wing or lot at run time (zero in Edit)
local OX = Vector3.zero
local function useOrigin(hotel) OX = hotel and hotel:GetAttribute("Origin") or Vector3.zero end

local C = {
	wall = Color3.fromRGB(196, 178, 234),
	wallRoom = Color3.fromRGB(206, 190, 238),
	trim = Color3.fromRGB(250, 248, 244),
	wood = Color3.fromRGB(204, 120, 70),
	woodDk = Color3.fromRGB(122, 72, 44),
	brick = Color3.fromRGB(176, 84, 70),
	frame = Color3.fromRGB(38, 42, 52),
	carpet = Color3.fromRGB(214, 40, 48),
	tile = Color3.fromRGB(150, 156, 164),
	plinth = Color3.fromRGB(226, 220, 210),
}

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

-- a framed "painting": a soft gradient canvas in a wood frame, on a wall facing `n`
local function painting(parent, cf, w, h, c1, c2, c3)
	local m = model(parent, "Painting")
	part(m, "Frame", Vector3.new(w + 0.5, h + 0.5, 0.25), cf, C.woodDk, Enum.Material.Wood)
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

-- wall segment with lavender inside face, brick outside skin when `outside` is a unit vector
local WALL_H = 12
local function wall(parent, name, a, b, color, outside)
	local w = block(parent, name, Vector3.new(a.X, FY, a.Y), Vector3.new(b.X, FY + WALL_H, b.Y), color or C.wall, Enum.Material.Plaster)
	-- cap trim
	block(parent, name .. "Cap", Vector3.new(a.X - 0.15, FY + WALL_H, a.Y - 0.15), Vector3.new(b.X + 0.15, FY + WALL_H + 0.5, b.Y + 0.15), C.trim)
	-- baseboard both sides
	block(parent, name .. "Base", Vector3.new(a.X - 0.12, FY, a.Y - 0.12), Vector3.new(b.X + 0.12, FY + 0.6, b.Y + 0.12), C.trim)
	if outside then
		local lo = Vector3.new(math.min(a.X, b.X), FY - 1, math.min(a.Y, b.Y))
		local hi = Vector3.new(math.max(a.X, b.X), FY + WALL_H, math.max(a.Y, b.Y))
		if outside.X > 0 then lo = Vector3.new(hi.X, lo.Y, lo.Z); hi = Vector3.new(hi.X + 0.3, hi.Y, hi.Z) end
		if outside.X < 0 then hi = Vector3.new(lo.X, hi.Y, hi.Z); lo = Vector3.new(lo.X - 0.3, lo.Y, lo.Z) end
		if outside.Y > 0 then lo = Vector3.new(lo.X, lo.Y, hi.Z); hi = Vector3.new(hi.X, hi.Y, hi.Z + 0.3) end
		if outside.Y < 0 then hi = Vector3.new(hi.X, hi.Y, lo.Z); lo = Vector3.new(lo.X, lo.Y, lo.Z - 0.3) end
		block(parent, name .. "Brick", lo, hi, C.brick, Enum.Material.Brick)
	end
	return w
end

---------------------------------------------------------------- rooms

local ROOMS = {
	{ id = 101, cx = -26.5 },
	{ id = 102, cx = 0 },
	{ id = 103, cx = 26.5 },
}
B.ROOMS = ROOMS

-- bare = true: an empty shell (walls, floor, nav + clean spots) with no furniture at all;
-- the player furnishes it in build mode and it opens for guests once it has a bed, shower and toilet
local function buildRoom(hotel, r, bare)
	local cx = r.cx
	local m = model(hotel.Rooms, "Room" .. r.id)
	m:SetAttribute("RoomId", r.id)
	m:SetAttribute("State", bare and "Unfurnished" or "Ready")
	local x0, x1 = cx - 12.5, cx + 12.5
	-- floors: wood for the bedroom, grey tile for the bathroom corner
	block(m, "Floor", Vector3.new(x0, FY - 0.4, -29), Vector3.new(x1, FY, -2.5), C.wood, Enum.Material.WoodPlanks)
	block(m, "BathFloor", Vector3.new(cx + 5.5, FY - 0.35, -29), Vector3.new(x1, FY + 0.06, -14), C.tile, Enum.Material.Slate)
	-- bathroom half wall
	local pw = block(m, "Partition", Vector3.new(cx + 5.2, FY, -29), Vector3.new(cx + 5.8, FY + 8, -21), C.trim, Enum.Material.Plaster)
	block(m, "PartitionCap", Vector3.new(cx + 5.1, FY + 8, -29), Vector3.new(cx + 5.9, FY + 8.3, -20.9), C.woodDk, Enum.Material.Wood)
	-- door frame + number plaque
	local fr = model(m, "DoorFrame")
	for _, sx in ipairs({ -1, 1 }) do
		block(fr, "Jamb", Vector3.new(cx + sx * 3.5 - 0.4, FY, -2.8), Vector3.new(cx + sx * 3.5 + 0.4, FY + 9.4, -1.2), C.woodDk, Enum.Material.Wood)
	end
	block(fr, "Head", Vector3.new(cx - 3.9, FY + 9, -2.8), Vector3.new(cx + 3.9, FY + 9.8, -1.2), C.woodDk, Enum.Material.Wood)
	local plaque = part(fr, "Plaque", Vector3.new(3.4, 1.5, 0.2), CFrame.new(cx + 6, FY + 7.4, -1.38), C.frame)
	textSign(plaque, Enum.NormalId.Back, tostring(r.id), { color = Color3.fromRGB(255, 236, 190), pps = 60 })
	-- props (skipped for a bare room: the player buys the furniture themselves)
	if not bare then
		local props = model(m, "Props")
		local bed = place("Bed", props, CFrame.new(cx - 4, FY, -24.25))
		local messy = place("BedMessy", props, CFrame.new(cx - 4, FY, -24.25))
		messy:SetAttribute("DirtyOnly", true)
		place("Nightstand", props, CFrame.new(cx - 9.3, FY, -27.6))
		place("Shower", props, CFrame.new(x1 - 2.6, FY + 0.06, -26.4))
		place("Toilet", props, CFrame.new(x1 - 1.9, FY + 0.06, -17.5) * CFrame.Angles(0, math.rad(-90), 0))
		place("Rug", props, CFrame.new(cx - 4, FY + 0.01, -15.5))
		place("FloorLamp", props, CFrame.new(x0 + 1.6, FY, -12.5))
		place("Plant", props, CFrame.new(x0 + 2.4, FY, -5.5) * CFrame.Angles(0, math.rad(40), 0))
		painting(props, CFrame.new(cx - 4, FY + 8.6, -29.6) * CFrame.Angles(0, math.pi, 0), 6, 3.2,
			Color3.fromRGB(255, 196, 160), Color3.fromRGB(250, 160, 140), Color3.fromRGB(200, 140, 170))
		-- lights (soft) so the room still reads at dusk
		for _, p in ipairs({ props.Nightstand:FindFirstChild("Glow"), props.FloorLamp:FindFirstChild("Glow") }) do
			if p then
				p.Material = Enum.Material.Neon
				p.Color = Color3.fromRGB(255, 226, 186)
				p.Transparency = 0.15
				local l = Instance.new("PointLight")
				l.Range = 14
				l.Brightness = 0.8
				l.Color = Color3.fromRGB(255, 214, 170)
				l.Shadows = true
				l.Parent = p
			end
		end
	end
	-- mess shown only when the room is dirty
	local mess = model(m, "Mess")
	mess:SetAttribute("DirtyOnly", true)
	place("Towel", mess, CFrame.new(cx + 8.5, FY + 0.07, -21.5) * CFrame.Angles(0, 0.6, 0))
	place("Trash", mess, CFrame.new(cx - 9.5, FY, -18) * CFrame.Angles(0, 1.2, 0))
	place("Trash", mess, CFrame.new(cx + 1.5, FY, -12) * CFrame.Angles(0, -0.4, 0))
	local sign = place("WetSign", mess, CFrame.new(cx, FY, -5.2) * CFrame.Angles(0, math.rad(8), 0), "NeedCleaning")
	local face = Instance.new("Part")
	face.Name = "SignFace"
	face.Size = Vector3.new(2, 2.6, 0.05)
	face.Transparency = 1
	face.CanCollide = false
	face.Anchored = true
	face.CFrame = sign:GetPivot() * CFrame.new(0, 1.75, 0.46) * CFrame.Angles(math.rad(-12), 0, 0)
	face.Parent = sign
	local g, t = textSign(face, Enum.NormalId.Front, "NEED\nCLEANING", { color = Color3.fromRGB(30, 30, 30), light = 1, pps = 80 })
	t.Font = Enum.Font.GothamBlack
	t.Size = UDim2.fromScale(1, 0.55)
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

---------------------------------------------------------------- lobby + shell

local function buildShell(hotel)
	local sh = model(hotel, "Shell")
	block(sh, "Plinth", Vector3.new(-41.5, -1, -31.5), Vector3.new(41.5, FY - 0.4, 31.5), C.plinth, Enum.Material.Concrete)
	block(sh, "LobbyFloor", Vector3.new(-40, FY - 0.4, -2.5), Vector3.new(40, FY, 30), C.wood, Enum.Material.WoodPlanks)
	-- red carpet: door to the room corridor, then along it
	block(sh, "Carpet", Vector3.new(-4, FY, 4), Vector3.new(4, FY + 0.08, 33), C.carpet, Enum.Material.Fabric)
	block(sh, "CarpetHall", Vector3.new(-33, FY, -0.5), Vector3.new(33, FY + 0.08, 4), C.carpet, Enum.Material.Fabric)
	for _, z in ipairs({ 3.85, -0.35 }) do
		block(sh, "CarpetEdge", Vector3.new(-33, FY + 0.05, z - 0.15), Vector3.new(33, FY + 0.1, z + 0.15), Color3.fromRGB(232, 186, 90), Enum.Material.Fabric)
	end
	-- perimeter walls (brick outside)
	wall(sh, "WallBack", Vector2.new(-40.5, -30.5), Vector2.new(40.5, -29.5), C.wallRoom, Vector2.new(0, -1))
	wall(sh, "WallLeft", Vector2.new(-40.5, -29.5), Vector2.new(-39.5, 30), C.wall, Vector2.new(-1, 0))
	wall(sh, "WallRight", Vector2.new(39.5, -29.5), Vector2.new(40.5, 30), C.wall, Vector2.new(1, 0))
	-- room dividers + room front walls with doorways
	for _, x in ipairs({ -13.25, 13.25 }) do
		wall(sh, "Divider", Vector2.new(x - 0.5, -29.5), Vector2.new(x + 0.5, -2.5), C.wallRoom)
	end
	for _, r in ipairs(ROOMS) do
		local a, b = r.cx - 12.75, r.cx + 12.75
		wall(sh, "Front" .. r.id .. "L", Vector2.new(math.max(a, -39.5), -2.5), Vector2.new(r.cx - 3.5, -1.5), C.wall)
		wall(sh, "Front" .. r.id .. "R", Vector2.new(r.cx + 3.5, -2.5), Vector2.new(math.min(b, 39.5), -1.5), C.wall)
		block(sh, "Lintel" .. r.id, Vector3.new(r.cx - 3.5, FY + 9.8, -2.5), Vector3.new(r.cx + 3.5, FY + WALL_H, -1.5), C.wall, Enum.Material.Plaster)
	end
	-- glass front: frame grid with a sliding door gap at x -5..5
	local gf = model(sh, "GlassFront")
	local z = 30.2
	local H = WALL_H + 1
	block(gf, "Sill", Vector3.new(-40.5, FY - 0.4, z - 0.6), Vector3.new(40.5, FY + 0.5, z + 0.6), C.frame, Enum.Material.Metal)
	block(gf, "Header", Vector3.new(-40.5, FY + H - 1, z - 0.7), Vector3.new(40.5, FY + H + 0.6, z + 0.7), C.frame, Enum.Material.Metal)
	local posts = { -40, -32, -24, -16, -8, -5, 5, 8, 16, 24, 32, 40 }
	for _, x in ipairs(posts) do
		block(gf, "Mullion", Vector3.new(x - 0.45, FY, z - 0.5), Vector3.new(x + 0.45, FY + H, z + 0.5), C.frame, Enum.Material.Metal)
	end
	for i = 1, #posts - 1 do
		local a, b = posts[i], posts[i + 1]
		if not (a == -5 and b == 5) then
			block(gf, "Transom", Vector3.new(a, FY + 9.6, z - 0.35), Vector3.new(b, FY + 10.2, z + 0.35), C.frame, Enum.Material.Metal)
			block(gf, "Glass", Vector3.new(a + 0.4, FY + 0.5, z - 0.1), Vector3.new(b - 0.4, FY + H - 1, z + 0.1), Color3.fromRGB(170, 214, 232), Enum.Material.Glass, { Transparency = 0.55, Reflectance = 0.15 })
		end
	end
	block(gf, "DoorHead", Vector3.new(-5, FY + 9.6, z - 0.5), Vector3.new(5, FY + H - 1, z + 0.5), C.frame, Enum.Material.Metal)
	block(gf, "DoorGlassTop", Vector3.new(-5, FY + 10.2, z - 0.1), Vector3.new(5, FY + H - 1, z + 0.1), Color3.fromRGB(170, 214, 232), Enum.Material.Glass, { Transparency = 0.55 })
	-- sliding doors (server slides them open for anyone near)
	local doors = model(hotel, "Doors")
	for _, sx in ipairs({ -1, 1 }) do
		local d = model(doors, sx < 0 and "DoorL" or "DoorR")
		local cfx = sx * 2.5
		local fr = block(d, "Frame", Vector3.new(cfx - 2.5, FY, z - 0.25), Vector3.new(cfx + 2.5, FY + 9.6, z + 0.25), C.frame, Enum.Material.Metal)
		fr.Transparency = 0
		block(d, "Pane", Vector3.new(cfx - 2.15, FY + 0.35, z - 0.12), Vector3.new(cfx + 2.15, FY + 9.25, z + 0.12), Color3.fromRGB(170, 214, 232), Enum.Material.Glass, { Transparency = 0.45, CanCollide = false })
		-- a hollow look: the frame part is only the border, so hide its middle with the pane
		fr.Size = Vector3.new(5, 9.6, 0.3)
		block(d, "Handle", Vector3.new(cfx - sx * 1.9 - 0.12, FY + 3.4, z - 0.45), Vector3.new(cfx - sx * 1.9 + 0.12, FY + 6, z + 0.45), Color3.fromRGB(220, 222, 226), Enum.Material.Metal)
		fr.Transparency = 1
		fr.CanCollide = true
		d:SetAttribute("Closed", d:GetPivot())
		d:SetAttribute("Side", sx)
		d.PrimaryPart = fr
		-- visible border strips
		for _, s in ipairs({ { -2.5, -2.15 }, { 2.15, 2.5 } }) do
			block(d, "Edge", Vector3.new(cfx + s[1], FY, z - 0.2), Vector3.new(cfx + s[2], FY + 9.6, z + 0.2), C.frame, Enum.Material.Metal)
		end
		block(d, "Rail", Vector3.new(cfx - 2.5, FY, z - 0.2), Vector3.new(cfx + 2.5, FY + 0.35, z + 0.2), C.frame, Enum.Material.Metal)
		block(d, "Rail", Vector3.new(cfx - 2.5, FY + 9.25, z - 0.2), Vector3.new(cfx + 2.5, FY + 9.6, z + 0.2), C.frame, Enum.Material.Metal)
	end
	-- entrance canopy + hotel sign
	local can = model(sh, "Canopy")
	block(can, "Roof", Vector3.new(-8, FY + 10.6, 30.7), Vector3.new(8, FY + 11.4, 38), C.frame, Enum.Material.Metal)
	for i = 0, 7 do
		local x0 = -8 + i * 2
		block(can, "Stripe", Vector3.new(x0, FY + 10.0, 30.7), Vector3.new(x0 + 2, FY + 10.6, 38.1), i % 2 == 0 and Color3.fromRGB(214, 40, 48) or C.trim, Enum.Material.Fabric)
	end
	for _, x in ipairs({ -7.4, 7.4 }) do
		block(can, "Post", Vector3.new(x - 0.3, FY, 37.2), Vector3.new(x + 0.3, FY + 10.6, 37.8), Color3.fromRGB(212, 176, 96), Enum.Material.Metal)
	end
	local signBoard = block(sh, "HotelSign", Vector3.new(-17, FY + H + 0.6, 29.6), Vector3.new(17, FY + H + 6, 30.4), C.frame, Enum.Material.Metal)
	local _, st = textSign(signBoard, Enum.NormalId.Back, "MY HOTEL", { stroke = 4, strokeColor = Color3.fromRGB(120, 40, 60), pps = 30, light = 0 })
	st.TextColor3 = Color3.fromRGB(255, 232, 160)
	signBoard:SetAttribute("HotelName", true)
	local glow = Instance.new("SurfaceLight")
	glow.Face = Enum.NormalId.Back
	glow.Range = 10
	glow.Brightness = 0.6
	glow.Color = Color3.fromRGB(255, 220, 160)
	glow.Parent = signBoard
	for _, x in ipairs({ -16.6, 16.6 }) do
		block(sh, "SignPost", Vector3.new(x - 0.3, FY + H - 0.4, 29.7), Vector3.new(x + 0.3, FY + H + 0.6, 30.3), C.frame, Enum.Material.Metal)
	end
end

local function buildLobby(hotel)
	local lb = model(hotel, "Lobby")
	-- reception: slatted wood backdrop with sign, desk in front
	local dx, dz = -22, 15
	local back = block(lb, "Backdrop", Vector3.new(dx - 8, FY, dz - 6.6), Vector3.new(dx + 8, FY + 10.5, dz - 5.8), C.trim, Enum.Material.Plaster)
	for i = 0, 25 do
		local x = dx - 7.5 + i * 0.6
		block(lb, "Slat", Vector3.new(x - 0.2, FY + 0.4, dz - 5.8), Vector3.new(x + 0.2, FY + 10.2, dz - 5.5), C.wood, Enum.Material.Wood)
	end
	local rs = block(lb, "ReceptionSign", Vector3.new(dx - 5.5, FY + 7, dz - 5.5), Vector3.new(dx + 5.5, FY + 9.2, dz - 5.3), C.frame, Enum.Material.Metal)
	textSign(rs, Enum.NormalId.Back, "RECEPTION", { color = Color3.fromRGB(255, 232, 160), pps = 40, light = 0 })
	place("Desk", lb, CFrame.new(dx, FY, dz))
	place("Plant", lb, CFrame.new(dx - 11, FY, dz - 4) * CFrame.Angles(0, 1.1, 0))
	place("Plant", lb, CFrame.new(dx + 11, FY, dz - 4) * CFrame.Angles(0, 2.6, 0))
	-- waiting area
	place("Rug", lb, CFrame.new(29, FY + 0.01, 16) * CFrame.Angles(0, math.rad(90), 0))
	place("Sofa", lb, CFrame.new(37.2, FY, 16) * CFrame.Angles(0, math.rad(-90), 0))
	place("Sofa", lb, CFrame.new(28.5, FY, 23.6) * CFrame.Angles(0, math.rad(180), 0))
	place("CoffeeTable", lb, CFrame.new(29.5, FY, 16))
	place("FloorLamp", lb, CFrame.new(37.6, FY, 23))
	place("FloorLamp", lb, CFrame.new(37.6, FY, 9))
	place("Plant", lb, CFrame.new(37, FY, 27.4))
	place("Plant", lb, CFrame.new(-37, FY, 27.4) * CFrame.Angles(0, 2, 0))
	place("Plant", lb, CFrame.new(10, FY, 6.5) * CFrame.Angles(0, 0.5, 0))
	place("Plant", lb, CFrame.new(-10, FY, 6.5) * CFrame.Angles(0, 3, 0))
	for _, p in ipairs(lb:GetDescendants()) do
		if p.Name == "Glow" and p:IsA("BasePart") then
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 226, 186)
			p.Transparency = 0.15
			local l = Instance.new("PointLight")
			l.Range = 16
			l.Brightness = 0.9
			l.Color = Color3.fromRGB(255, 214, 170)
			l.Parent = p
		end
	end
	painting(lb, CFrame.new(39.35, FY + 7.5, 16) * CFrame.Angles(0, math.rad(90), 0), 8, 4,
		Color3.fromRGB(150, 210, 240), Color3.fromRGB(255, 210, 170), Color3.fromRGB(240, 150, 150))
	-- desk screen glows
	local screen = lb.Desk:FindFirstChild("Glow")
	if screen then
		screen.Material = Enum.Material.Neon
		screen.Color = Color3.fromRGB(110, 210, 230)
		screen.Transparency = 0.2
	end
	-- cash pile on a stand right of the desk (server stacks CashBundles in CashPile)
	local stand = block(lb, "CashStand", Vector3.new(dx + 7.4, FY, dz - 1.4), Vector3.new(dx + 11.4, FY + 2.6, dz + 1.4), C.frame, Enum.Material.Metal)
	block(lb, "CashTop", Vector3.new(dx + 7.2, FY + 2.6, dz - 1.6), Vector3.new(dx + 11.6, FY + 2.8, dz + 1.6), Color3.fromRGB(212, 176, 96), Enum.Material.Metal)
	local pile = model(lb, "CashPile")
	pile:SetAttribute("Origin", CFrame.new(dx + 9.4, FY + 2.8, dz))
	-- nav
	local nav = folder(hotel, "Nav")
	spot(nav, "Street", CFrame.new(-70, FY + 3, 66))
	spot(nav, "StreetExit", CFrame.new(70, FY + 3, 66))
	spot(nav, "PathStart", CFrame.new(0, FY + 3, 62))
	for i = 1, 6 do
		spot(nav, "Queue" .. i, CFrame.new((i % 2 == 0) and 1.2 or -1.2, FY + 3, 40 + (i - 1) * 3.6), { Look = Vector3.new(0, FY + 3, 20) })
	end
	spot(nav, "Inside", CFrame.new(0, FY + 3, 24))
	spot(nav, "DeskGuest", CFrame.new(dx, FY + 3, dz + 3.4), { Look = Vector3.new(dx, FY + 3, dz) })
	spot(nav, "DeskGuest2", CFrame.new(dx + 3, FY + 3, dz + 3.6), { Look = Vector3.new(dx, FY + 3, dz) })
	spot(nav, "Receptionist", CFrame.new(dx, FY + 3, dz - 3.2), { Look = Vector3.new(dx, FY + 3, dz + 5) })
	spot(nav, "DoorPrompt", CFrame.new(0, FY + 4.5, 32.5))
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

-- ReplicatedStorage.RAH.Items: one template per catalog item (pivot = floor centre)
function B.makeItems()
	local rah = game.ReplicatedStorage:WaitForChild("RAH")
	local old = rah:FindFirstChild("Items")
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
				p.CanCollide = not SOFT[id]
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
	items.Parent = rah
	return items
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
	local m = game.ReplicatedStorage.RAH.Items[id]:Clone()
	m:PivotTo(cf)
	m:SetAttribute("Item", id)
	m:SetAttribute("Zone", zoneNameAt(hotel, cf.Position))
	if attrs then for k, v in pairs(attrs) do m:SetAttribute(k, v) end end
	m.Parent = hotel.Placed
	return m
end

-- one room's builder furniture -> Placed items (bed/shower/toilet become its core items)
function B.convertRoom(hotel, room)
	local items = game.ReplicatedStorage.RAH.Items
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
	local items = game.ReplicatedStorage.RAH.Items
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
	for _, slot in ipairs(require(game.ReplicatedStorage.RAH.Config).ROOM_SLOTS) do
		if not hotel.Rooms:FindFirstChild("Room" .. slot.id) then return slot end
	end
end

function B.buildWing(hotel, slot)
	useOrigin(hotel)
	local s, e, o, cx = wingGeom(slot)
	local sh = hotel.Shell
	local wm = model(sh, "Wing" .. slot.id)
	-- knock out the old outer wall on this side; its room part comes back as a divider
	local old = s > 0 and "WallRight" or "WallLeft"
	for _, d in ipairs(sh:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == old or d.Name == old .. "Cap" or d.Name == old .. "Base" or d.Name == old .. "Brick") then
			d:Destroy()
		end
	end
	wall(wm, "Divider", Vector2.new(s * (e - 1), -29.5), Vector2.new(s * e, -2.5), C.wallRoom)
	-- plinth, lobby floor, back wall, new outer wall
	block(wm, "Plinth", Vector3.new(s * (e - 1.5), -1, -31.5), Vector3.new(s * (o + 2), FY - 0.4, 31.5), C.plinth, Enum.Material.Concrete)
	block(wm, "LobbyFloor", Vector3.new(s * (e - 1.1), FY - 0.4, -2.5), Vector3.new(s * o, FY, 30), C.wood, Enum.Material.WoodPlanks)
	wall(wm, "WallBack", Vector2.new(s * (e - 1), -30.5), Vector2.new(s * (o + 1), -29.5), C.wallRoom, Vector2.new(0, -1))
	wall(wm, old, Vector2.new(s * o, -29.5), Vector2.new(s * (o + 1), 30), C.wall, Vector2.new(s, 0))
	-- room front wall with its doorway
	wall(wm, "FrontL", Vector2.new(s * e, -2.5), Vector2.new(cx - s * 3.5, -1.5), C.wall)
	wall(wm, "FrontR", Vector2.new(cx + s * 3.5, -2.5), Vector2.new(s * o, -1.5), C.wall)
	block(wm, "Lintel", Vector3.new(cx - 3.5, FY + 9.8, -2.5), Vector3.new(cx + 3.5, FY + WALL_H, -1.5), C.wall, Enum.Material.Plaster)
	-- the red carpet runs on to the new door
	local c0, c1 = s * 33, cx + s * 6
	block(wm, "CarpetHall", Vector3.new(c0, FY, -0.5), Vector3.new(c1, FY + 0.08, 4), C.carpet, Enum.Material.Fabric)
	for _, z in ipairs({ 3.85, -0.35 }) do
		block(wm, "CarpetEdge", Vector3.new(c0, FY + 0.05, z - 0.15), Vector3.new(c1, FY + 0.1, z + 0.15), Color3.fromRGB(232, 186, 90), Enum.Material.Fabric)
	end
	-- glass front for the new bay
	local gf = model(wm, "GlassFront")
	local z = 30.2
	local H = WALL_H + 1
	block(gf, "Sill", Vector3.new(s * (e - 1), FY - 0.4, z - 0.6), Vector3.new(s * (o + 1), FY + 0.5, z + 0.6), C.frame, Enum.Material.Metal)
	block(gf, "Header", Vector3.new(s * (e - 1), FY + H - 1, z - 0.7), Vector3.new(s * (o + 1), FY + H + 0.6, z + 0.7), C.frame, Enum.Material.Metal)
	local posts = { e - 0.5, e + 8.2, e + 16.9, o + 0.5 }
	for _, x in ipairs(posts) do
		block(gf, "Mullion", Vector3.new(s * x - 0.45, FY, z - 0.5), Vector3.new(s * x + 0.45, FY + H, z + 0.5), C.frame, Enum.Material.Metal)
	end
	for i = 1, #posts - 1 do
		local a, b = s * posts[i], s * posts[i + 1]
		local lo, hi = math.min(a, b), math.max(a, b)
		block(gf, "Transom", Vector3.new(lo, FY + 9.6, z - 0.35), Vector3.new(hi, FY + 10.2, z + 0.35), C.frame, Enum.Material.Metal)
		block(gf, "Glass", Vector3.new(lo + 0.4, FY + 0.5, z - 0.1), Vector3.new(hi - 0.4, FY + H - 1, z + 0.1), Color3.fromRGB(170, 214, 232), Enum.Material.Glass, { Transparency = 0.55, Reflectance = 0.15 })
	end
	painting(wm, CFrame.new(s * (o - 0.15), FY + 7.5, 14) * CFrame.Angles(0, math.rad(s > 0 and 90 or -90), 0), 7, 3.6,
		Color3.fromRGB(180, 220, 250), Color3.fromRGB(255, 220, 180), Color3.fromRGB(250, 170, 170))
	-- outside: no grass under the wing, paving round it, planters in front
	local t = workspace.Terrain
	local mid = s * (e + o) / 2
	t:FillBlock(CFrame.new(mid, 0, 0) + OX, Vector3.new(o - e + 20, 8, 76), Enum.Material.Air)
	t:FillBlock(CFrame.new(mid, -6, 0) + OX, Vector3.new(o - e + 20, 4, 76), Enum.Material.Concrete)
	-- outdoor bits belong to the hotel, so they go when the plot is freed
	local out = hotel:FindFirstChild("Outdoor") or model(hotel, "Outdoor")
	block(out, "Apron" .. slot.id, Vector3.new(s * (e - 2), -4, -38), Vector3.new(s * (o + 8), 0, 38), Color3.fromRGB(214, 210, 202), Enum.Material.Pavement)
	for _, dx in ipairs({ -8, 0, 8 }) do
		part(out, "Planter", Vector3.new(6.5, 1.6, 3), CFrame.new(cx + dx, 0.8, 34), Color3.fromRGB(226, 220, 210), Enum.Material.Concrete)
		part(out, "Hedge", Vector3.new(6, 2.6, 2.6), CFrame.new(cx + dx, 2.6, 34), Color3.fromRGB(86, 150, 70), Enum.Material.LeafyGrass)
	end
	-- build zones: the room, its doorway, and the lobby/hallway stretched to the new width
	local zones = hotel.BuildZones
	local rz = zonePart(zones, "Room" .. slot.id, Vector2.new(s * e, -29.5), Vector2.new(s * o, -2.5))
	rz.Size = Vector3.new(rz.Size.X, 0.2, rz.Size.Z)
	rz.Position = Vector3.new(rz.Position.X, FY, rz.Position.Z)
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
	B.forSale(hotel)
	return room
end

-- a fenced lot with a price sign where the next room will go
function B.forSale(hotel)
	useOrigin(hotel)
	local old = hotel:FindFirstChild("ForSale")
	if old then old:Destroy() end
	local slot = B.nextSlot(hotel)
	if not slot then return end
	local s, e, o, cx = wingGeom(slot)
	local fs = model(hotel, "ForSale")
	fs:SetAttribute("RoomId", slot.id)
	fs:SetAttribute("Price", slot.price)
	local lo, hi = math.min(s * (e + 0.5), s * (o + 0.5)), math.max(s * (e + 0.5), s * (o + 0.5))
	local wood = Color3.fromRGB(236, 226, 206)
	-- picket fence round the lot
	local function fence(a, b)
		block(fs, "Rail", Vector3.new(a.X, 1.3, a.Y), Vector3.new(b.X, 1.6, b.Y), wood, Enum.Material.Wood)
		block(fs, "Rail", Vector3.new(a.X, 2.5, a.Y), Vector3.new(b.X, 2.8, b.Y), wood, Enum.Material.Wood)
		local n = math.max(math.floor((b - a).Magnitude / 2.4), 1)
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			part(fs, "Picket", Vector3.new(0.45, 3.4, 0.45), CFrame.new(p.X, 1.7, p.Y), wood, Enum.Material.Wood)
		end
	end
	fence(Vector2.new(lo, -29.6), Vector2.new(hi, -29.4))
	fence(Vector2.new(lo, 29.4), Vector2.new(hi, 29.6))
	local far = s > 0 and hi or lo
	fence(Vector2.new(far - 0.1, -29.5), Vector2.new(far + 0.1, 29.5))
	-- orange stakes marking out where the room goes
	for _, z in ipairs({ -28.5, -3 }) do
		for _, x in ipairs({ lo + 1, hi - 1 }) do
			part(fs, "Stake", Vector3.new(0.35, 1.6, 0.35), CFrame.new(x, 0.8, z), Color3.fromRGB(255, 150, 50), Enum.Material.Wood)
		end
	end
	-- the sign, facing the street
	local sign = model(fs, "Sign")
	for _, dx in ipairs({ -4.6, 4.6 }) do
		block(sign, "Post", Vector3.new(cx + dx - 0.3, 0, 26.2), Vector3.new(cx + dx + 0.3, 8.6, 26.8), Color3.fromRGB(122, 72, 44), Enum.Material.Wood)
	end
	local board = block(sign, "Board", Vector3.new(cx - 6, 3.2, 26.8), Vector3.new(cx + 6, 8.8, 27.3), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0.3
	g.Parent = board
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.Parent = g
	local gr = Instance.new("UIGradient")
	gr.Rotation = 90
	gr.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(246, 160, 30))
	gr.Parent = bg
	local function line(text, y, h, col)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.05, y)
		t.Size = UDim2.fromScale(0.9, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = col or Color3.new(1, 1, 1)
		t.Parent = bg
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = Color3.fromRGB(46, 34, 58)
		st.Parent = t
	end
	line("ROOM " .. slot.id .. " FOR SALE", 0.06, 0.34)
	line("$" .. slot.price, 0.42, 0.3, Color3.fromRGB(170, 255, 150))
	line("Buy it in Build mode", 0.76, 0.17)
	return fs
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
	return hotel
end

return B
