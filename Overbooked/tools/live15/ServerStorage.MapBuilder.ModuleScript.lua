-- ServerStorage.MapBuilder: builds the whole city in Edit (round 9). Run from execute_luau:
--   require(game.ServerStorage.MapBuilder:Clone()).build()
-- Makes workspace.City (Road, Walks, Lots, Shops, Skyline, Props, Tunnels, Parked) and reshapes the
-- terrain. Layout numbers come from Shared.Street. Street props are ServerStorage.CityProps meshes.
-- Lamps and lit windows are tagged NightLight (Lighting turns them on at dusk).
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local S = require(RS.Shared.Street)
local PROPS = game.ServerStorage:WaitForChild("CityProps")

local M = {}
local rng = Random.new(2611)
local CITY

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local Mat = Enum.Material

local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color or rgb(200, 200, 200)
	p.Material = mat or Mat.SmoothPlastic
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = parent
	return p
end

local function wedge(parent, name, size, cf, color, mat)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Mat.SmoothPlastic
	p.Parent = parent
	return p
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

-- a CityProps mesh at a spot; yaw in degrees (0 = the prop's own front faces +Z)
local OBST = { TreeA = 1.2, TreeB = 1.0, TreeC = 1.1, StreetLamp = 1.0, TrashBin = 1.4, Hydrant = 1.0, Mailbox = 1.3,
	Bench = 3.4, BusStop = 7.6, CafeTable = 3.0, Planter = 4.2, TrafficLight = 1.2 }
-- props whose one hull is far bigger than what you'd bump into: trunk / pole radius and height (studs)
local COLLIDE = {
	TreeA = { r = 0.95, h = 9 }, TreeB = { r = 0.75, h = 9 }, TreeC = { r = 0.85, h = 8 },
	StreetLamp = { r = 0.45, h = 18 }, TrafficLight = { r = 0.5, h = 16 }, CafeTable = { r = 1.7, h = 3.2 },
}
pcall(function() game:GetService("PhysicsService"):RegisterCollisionGroup("NPCSolid") end)
local function prop(parent, name, pos, yaw, color, scale)
	local src = PROPS:FindFirstChild(name)
	if not src then warn("missing prop " .. name) return nil end
	local m = src:Clone()
	if scale and scale ~= 1 then m:ScaleTo(scale) end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			if color and p:GetAttribute("Group") == "paint" then p.Color = color end
		end
	end
	m.Parent = parent
	-- round 10c: a single hull round a whole tree (or a lamp's arm) was an invisible wall; the mesh goes
	-- non-solid and a plain cylinder stands in for the trunk or pole, for players and walkers alike
	local col = COLLIDE[name]
	if col then
		local k = scale or 1
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanTouch = false
			end
		end
		local c = Instance.new("Part")
		c.Name = "Collider"
		c.Shape = Enum.PartType.Cylinder
		c.Size = Vector3.new(col.h * k, col.r * 2 * k, col.r * 2 * k)
		c.CFrame = CFrame.new(pos) * CFrame.new(0, col.h * k / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		c.Anchored = true
		c.Transparency = 1
		c.CanTouch = false
		c.CastShadow = false
		pcall(function() c.CollisionGroup = "NPCSolid" end)
		c.Parent = m
	end
	local onWalk =(pos.Z > S.NEAR.z0 - 1 and pos.Z < S.NEAR.z1 + 1) or (pos.Z > S.FAR.z0 - 1 and pos.Z < S.FAR.z1 + 1)
	if OBST[name] and onWalk then
		m:SetAttribute("WalkRadius", OBST[name] * (scale or 1))
		CS:AddTag(m, "WalkObstacle")
	end
	return m
end

local function signText(part, face, text, color, bg, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.6
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	if bg then t.BackgroundColor3 = bg end
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Parent = sg
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0); pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = t
	return t
end

local function nightLight(m, part, litColor)
	part:SetAttribute("LitColor", litColor)
	CS:AddTag(m, "NightLight")
end

---------------------------------------------------------------- terrain

-- the ground cut for one hotel lot (also used by Plots when a plot is released)
function M.digLot(cx)
	local T = workspace.Terrain
	T:FillBlock(CFrame.new(cx, -4, -9), Vector3.new(S.PLOT_W, 8, 134), Mat.LeafyGrass)
	T:FillBlock(CFrame.new(cx, 0, 0), Vector3.new(96, 8, 76), Mat.Air)
	T:FillBlock(CFrame.new(cx, -6, 0), Vector3.new(96, 4, 76), Mat.Concrete)
	T:FillBlock(CFrame.new(cx, 0, (S.PATH_Z0 + S.NEAR.z0) / 2 + 2), Vector3.new(S.PATH_HALF * 2 + 6, 8, S.NEAR.z0 - S.PATH_Z0 + 4), Mat.Air)
	T:FillBlock(CFrame.new(cx, -6, (S.PATH_Z0 + S.NEAR.z0) / 2 + 2), Vector3.new(S.PATH_HALF * 2 + 6, 4, S.NEAR.z0 - S.PATH_Z0 + 4), Mat.Concrete)
end

local function terrain()
	local T = workspace.Terrain
	-- wipe the old ground in chunks (FillBlock has a size limit)
	for x = -1400, 1600, 400 do
		for z = -800, 800, 400 do
			T:FillBlock(CFrame.new(x, 40, z), Vector3.new(400, 160, 400), Mat.Air)
		end
	end
	-- the base: grass everywhere, top at y = 0
	for x = -1400, 1600, 400 do
		for z = -800, 800, 400 do
			T:FillBlock(CFrame.new(x, -12, z), Vector3.new(400, 24, 400), Mat.Grass)
		end
	end
	local len = S.X1 - S.X0 + 400
	local midX = (S.X0 + S.X1) / 2
	for x = midX - len / 2, midX + len / 2, 400 do
		-- shops and skyline stand on pavers (no grass blades through their floors)
		T:FillBlock(CFrame.new(x + 200, -2, 263), Vector3.new(400, 4, 274), Mat.Pavement)
		-- the street and both sidewalks: dug out; the road and walk parts are the surface
		T:FillBlock(CFrame.new(x + 200, 2, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(400, 12, S.FAR.z1 - S.NEAR.z0), Mat.Air)
		T:FillBlock(CFrame.new(x + 200, -6, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(400, 4, S.FAR.z1 - S.NEAR.z0), Mat.Concrete)
	end
	-- each hotel's core footprint and front path (the same cut HotelBuilder makes; wings dig their own)
	for k = 1, S.PLOT_COUNT do
		M.digLot(S.centre(k))
	end
	-- rolling hills behind the hotels
	for i = 1, 26 do
		local x = rng:NextNumber(S.X0 - 200, S.X1 + 200)
		local z = rng:NextNumber(-520, -230)
		local r = rng:NextNumber(70, 150)
		T:FillBall(Vector3.new(x, -r * 0.45, z), r, Mat.Grass)
	end
	for i = 1, 10 do
		local x = rng:NextNumber(S.X0, S.X1)
		local z = rng:NextNumber(-600, -480)
		local r = rng:NextNumber(120, 200)
		T:FillBall(Vector3.new(x, -r * 0.3, z), r, Mat.Grass)
	end
	-- mountains over the tunnels at both ends of the street
	for _, x in ipairs({ S.X0, S.X1 }) do
		local s = x < 0 and -1 or 1
		T:FillBall(Vector3.new(x + s * 90, 10, 90), 120, Mat.Rock)
		T:FillBall(Vector3.new(x + s * 130, 30, -10), 110, Mat.Grass)
		T:FillBall(Vector3.new(x + s * 130, 30, 200), 120, Mat.Grass)
		T:FillBall(Vector3.new(x + s * 200, 60, 90), 130, Mat.Grass)
		-- the tunnel bore
		T:FillBlock(CFrame.new(x + s * 80, 20, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(160, 40, S.FAR.z1 - S.NEAR.z0 + 6), Mat.Air)
		T:FillBlock(CFrame.new(x + s * 80, -2, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(160, 4, S.FAR.z1 - S.NEAR.z0 + 6), Mat.Pavement)
	end
end

---------------------------------------------------------------- road and sidewalks

local ASPHALT = rgb(58, 60, 66)
local WALK = rgb(206, 202, 194)
local WALK_DK = rgb(176, 170, 162)
local CURB = rgb(186, 184, 180)
local WHITE = rgb(240, 240, 236)
local YELLOW = rgb(246, 200, 60)

local function strip(parent, name, x0, x1, z, w, y, h, color, mat)
	-- long parts are capped at 2048 studs: split if needed
	local len = x1 - x0
	local n = math.ceil(len / 2000)
	for i = 0, n - 1 do
		local a = x0 + len * i / n
		local b = x0 + len * (i + 1) / n
		P(parent, name, Vector3.new(b - a, h, w), Vector3.new((a + b) / 2, y, z), color, mat)
	end
end

local function road()
	local f = folder(CITY, "Road")
	local x0, x1 = S.X0 - 160, S.X1 + 160
	local R = S.ROAD
	strip(f, "Asphalt", x0, x1, (R.z0 + R.z1) / 2, R.z1 - R.z0, -2, 4, ASPHALT, Mat.Asphalt)
	-- double yellow centre line
	for _, dz in ipairs({ -0.45, 0.45 }) do
		strip(f, "CentreLine", x0, x1, S.CENTRE_LINE + dz, 0.4, 0.02, 0.06, YELLOW, Mat.SmoothPlastic)
	end
	-- solid white edge lines between the driving lanes and the parking lanes
	for _, z in ipairs({ 80.5, 104.5 }) do
		strip(f, "EdgeLine", x0, x1, z, 0.45, 0.02, 0.06, WHITE, Mat.SmoothPlastic)
	end
	-- parking bay ticks
	local ticks = model(f, "ParkingTicks")
	for x = x0, x1, 26 do
		for _, z in ipairs({ S.PARK[1], S.PARK[2] }) do
			P(ticks, "Tick", Vector3.new(0.4, 0.06, 3), Vector3.new(x, 0.02, z + (z < 92 and 2 or -2)), WHITE)
		end
	end
	-- crosswalks: zebra stripes and stop lines
	for _, cx in ipairs(S.CROSS) do
		local cw = model(f, "Crosswalk")
		for z = R.z0 + 1.5, R.z1 - 1.5, 3 do
			P(cw, "Zebra", Vector3.new(S.CROSS_W, 0.06, 1.6), Vector3.new(cx, 0.02, z), WHITE)
		end
		P(cw, "StopLine", Vector3.new(0.9, 0.06, 11), Vector3.new(cx + S.CROSS_W / 2 + 3, 0.02, S.LANES[1].z), WHITE)
		P(cw, "StopLine", Vector3.new(0.9, 0.06, 11), Vector3.new(cx - S.CROSS_W / 2 - 3, 0.02, S.LANES[2].z), WHITE)
	end
	-- manholes
	for x = x0 + 40, x1, 130 do
		local m = P(f, "Manhole", Vector3.new(0.12, 3.6, 3.6), CFrame.new(x, 0.02, S.LANES[rng:NextInteger(1, 2)].z + rng:NextNumber(-2, 2)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 70, 74), Mat.DiamondPlate)
		m.Shape = Enum.PartType.Cylinder
	end
end

local function sidewalk(side)
	local f = folder(CITY, side.name)
	local x0, x1 = S.X0 - 160, S.X1 + 160
	local w = side.z1 - side.z0
	strip(f, "Walk", x0, x1, (side.z0 + side.z1) / 2, w, -1.75, 4.5, WALK, Mat.Pavement)
	-- the curb toward the road
	local cz = side.curbZ
	strip(f, "Curb", x0, x1, cz, 1.2, 0.3, 0.62, CURB, Mat.Concrete)
	-- a darker band of pavers along the property side, and the furniture strip by the curb
	strip(f, "Band", x0, x1, side.bandZ, 1.6, 0.52, 0.06, WALK_DK, Mat.Pavement)
	strip(f, "Furniture", x0, x1, side.furnZ, 4.2, 0.52, 0.06, rgb(190, 184, 176), Mat.Cobblestone)
	-- curb ramps at the crosswalks
	for _, cx in ipairs(S.CROSS) do
		P(f, "Ramp", Vector3.new(S.CROSS_W, 0.1, 1.4), Vector3.new(cx, 0.55, cz), rgb(240, 200, 70), Mat.DiamondPlate)
	end
end

---------------------------------------------------------------- street furniture

local LAMP_LIT = rgb(255, 222, 170)

local function streetLamp(parent, x, z, facing)
	local m = prop(parent, "StreetLamp", Vector3.new(x, S.Y, z), facing)
	if not m then return end
	m.Name = "StreetLamp"
	local glow = m:FindFirstChild("Glow")
	if glow then
		glow.Material = Mat.SmoothPlastic
		glow.Color = rgb(200, 196, 186)
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Angle = 120
		l.Range = 34
		l.Brightness = 2.4
		l.Color = LAMP_LIT
		l.Shadows = false
		l.Enabled = false
		l.Parent = glow
		nightLight(m, glow, LAMP_LIT)
	end
	return m
end

local CAR_COLORS = { rgb(220, 60, 60), rgb(60, 120, 220), rgb(240, 240, 240), rgb(40, 42, 48), rgb(150, 156, 164),
	rgb(250, 200, 60), rgb(70, 170, 120), rgb(240, 130, 60), rgb(120, 80, 170), rgb(180, 210, 230), rgb(140, 30, 40), rgb(30, 60, 110) }
M.CAR_COLORS = CAR_COLORS

local function nearHotelPath(x)
	for k = 1, S.PLOT_COUNT do
		if math.abs(x - S.centre(k)) < S.PATH_HALF + 9 then return true end
	end
	return false
end
local function nearCross(x, pad)
	for _, cx in ipairs(S.CROSS) do
		if math.abs(x - cx) < S.CROSS_W / 2 + (pad or 6) then return true end
	end
	return false
end

local function furniture()
	local f = folder(CITY, "Props")
	local x0, x1 = S.X0 + 20, S.X1 - 20
	-- near side (hotels): trees and lamps alternate along the curb strip
	local trees = { "TreeA", "TreeA", "TreeB", "TreeC" }
	local i = 0
	for x = x0, x1, 22 do
		i += 1
		if not nearCross(x, 8) and not nearHotelPath(x) then
			if i % 2 == 0 then
				local t = prop(f, trees[rng:NextInteger(1, #trees)], Vector3.new(x, S.Y, S.NEAR.z1 - 3.6), rng:NextNumber(0, 360), nil, rng:NextNumber(0.85, 1.1))
				P(f, "Grate", Vector3.new(5, 0.08, 5), Vector3.new(x, 0.56, S.NEAR.z1 - 3.6), rgb(60, 62, 66), Mat.DiamondPlate)
			else
				streetLamp(f, x, S.NEAR.z1 - 2.2, 0)
			end
		end
	end
	i = 0
	for x = x0 + 11, x1, 22 do
		i += 1
		if not nearCross(x, 8) then
			if i % 2 == 0 then
				prop(f, trees[rng:NextInteger(1, #trees)], Vector3.new(x, S.Y, S.FAR.z0 + 3.6), rng:NextNumber(0, 360), nil, rng:NextNumber(0.85, 1.1))
				P(f, "Grate", Vector3.new(5, 0.08, 5), Vector3.new(x, 0.56, S.FAR.z0 + 3.6), rgb(60, 62, 66), Mat.DiamondPlate)
			else
				streetLamp(f, x, S.FAR.z0 + 2.2, 180)
			end
		end
	end
	-- benches, bins, hydrants, mailboxes: a few per block on each side
	for x = x0 + 30, x1, 66 do
		if not nearCross(x, 10) and not nearHotelPath(x) then
			local r = rng:NextNumber()
			if r < 0.4 then
				prop(f, "Bench", Vector3.new(x, S.Y, S.NEAR.z0 + 1.6), 0)
			elseif r < 0.7 then
				prop(f, "TrashBin", Vector3.new(x, S.Y, S.NEAR.z1 - 3.2), 0)
			elseif r < 0.85 then
				prop(f, "Hydrant", Vector3.new(x, S.Y, S.NEAR.z1 - 2.6), 90)
			else
				prop(f, "Mailbox", Vector3.new(x, S.Y, S.NEAR.z1 - 3.0), 180)
			end
		end
	end
	for x = x0 + 50, x1, 58 do
		if not nearCross(x, 10) then
			local r = rng:NextNumber()
			if r < 0.35 then
				prop(f, "TrashBin", Vector3.new(x, S.Y, S.FAR.z0 + 3.0), 0)
			elseif r < 0.6 then
				prop(f, "Hydrant", Vector3.new(x, S.Y, S.FAR.z0 + 2.4), -90)
			elseif r < 0.8 then
				prop(f, "Planter", Vector3.new(x, S.Y, S.FAR.z0 + 3.4), 0)
			else
				prop(f, "Mailbox", Vector3.new(x, S.Y, S.FAR.z0 + 3.0), 0)
			end
		end
	end
	-- bus stops, one each way
	local stops = folder(CITY, "BusStops")
	local b1 = prop(stops, "BusStop", Vector3.new(-200, S.Y, S.NEAR.z1 - 4.0), 0)
	local b2 = prop(stops, "BusStop", Vector3.new(380, S.Y, S.FAR.z0 + 4.0), 180)
	for _, b in ipairs({ b1, b2 }) do
		if b then
			local face = b:FindFirstChild("Glow")
			if face then nightLight(b, face, rgb(255, 240, 220)) end
		end
	end
	-- traffic signals at each crosswalk: one on each side of the road, mast arms over their lanes
	local sig = folder(CITY, "Signals")
	for _, cx in ipairs(S.CROSS) do
		local a = prop(sig, "TrafficLight", Vector3.new(cx + S.CROSS_W / 2 + 4, S.Y, S.NEAR.z1 - 2.5), 0)
		local b = prop(sig, "TrafficLight", Vector3.new(cx - S.CROSS_W / 2 - 4, S.Y, S.FAR.z0 + 2.5), 180)
		for _, m in ipairs({ a, b }) do
			if m then
				m.Name = "TrafficLight"
				m:SetAttribute("CrossX", cx)
				CS:AddTag(m, "Signal")
				-- lenses: red / amber / green on both faces of each signal head (the client lights them)
				local base = m:GetPivot()
				for hi, y in ipairs({ -7.0, -14.0 }) do
					for li, col in ipairs({ "Red", "Amber", "Green" }) do
						for _, sx in ipairs({ -1, 1 }) do
							local lens = P(m, "Lens" .. col, Vector3.new(0.2, 0.9, 0.9),
								base * CFrame.new(sx * 0.68, 15.0 - (li - 1) * 1.15, -y),
								rgb(40, 40, 44), Mat.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CanCollide = false })
							lens:SetAttribute("Lens", col)
						end
					end
				end
				-- the walk / don't walk light on the pole
				local walk = P(m, "WalkLight", Vector3.new(0.82, 0.82, 0.1), base * CFrame.new(0, 9.0, -1.06), rgb(40, 40, 44), Mat.SmoothPlastic, { CanCollide = false })
				walk:SetAttribute("Lens", "Walk")
			end
		end
	end
end

---------------------------------------------------------------- the hotel lots

local function lots()
	local f = folder(CITY, "Lots")
	for k = 1, S.PLOT_COUNT do
		local cx = S.centre(k)
		local lot = model(f, "Lot" .. k)
		lot:SetAttribute("Plot", k)
		-- front path: pavers with a granite edge, widening into a little plaza at the sidewalk
		local z0, z1 = S.PATH_Z0, S.NEAR.z0
		P(lot, "Apron", Vector3.new(96, 4, 76), Vector3.new(cx, -2, 0), rgb(196, 190, 182), Mat.Concrete)
		P(lot, "Path", Vector3.new(S.PATH_HALF * 2 + 6, 4.5, z1 - z0 + 4), Vector3.new(cx, -1.75, (z0 + z1) / 2 + 2), rgb(226, 218, 204), Mat.Pavement)
		for _, s in ipairs({ -1, 1 }) do
			P(lot, "PathEdge", Vector3.new(0.8, 0.62, z1 - z0), Vector3.new(cx + s * (S.PATH_HALF + 0.4), 0.31, (z0 + z1) / 2), rgb(150, 146, 140), Mat.Granite)
			-- path lights (bollards)
			for z = z0 + 5, z1 - 3, 7 do
				local b = prop(lot, "Bollard", Vector3.new(cx + s * (S.PATH_HALF + 1.6), 0.2, z), 0)
				if b then
					local top = P(b, "Light", Vector3.new(0.7, 0.3, 0.7), Vector3.new(cx + s * (S.PATH_HALF + 1.6), 3.0, z), rgb(200, 196, 186))
					local l = Instance.new("PointLight")
					l.Range = 9; l.Brightness = 1.2; l.Color = LAMP_LIT; l.Enabled = false; l.Parent = top
					nightLight(b, top, LAMP_LIT)
				end
			end
		end
		P(lot, "Plaza", Vector3.new(S.PATH_HALF * 2 + 14, 0.5, 6), Vector3.new(cx, 0.27, z1 - 3), rgb(226, 218, 204), Mat.Pavement)
		-- flower beds and planters along the front lawn
		for _, s in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				prop(lot, "Planter", Vector3.new(cx + s * (16 + i * 11), 0.1, S.NEAR.z0 - 3.2), 0)
			end
			prop(lot, "TreeC", Vector3.new(cx + s * 52, 0, 48), rng:NextNumber(0, 360))
			prop(lot, "TreeA", Vector3.new(cx + s * 78, 0, 44), rng:NextNumber(0, 360))
			prop(lot, "Bush", Vector3.new(cx + s * 30, 0, 40), rng:NextNumber(0, 360))
			prop(lot, "Bush", Vector3.new(cx + s * 64, 0, 40), rng:NextNumber(0, 360))
			prop(lot, "Bench", Vector3.new(cx + s * 12, 0.25, 48), s * 90)
		end
		-- low hedges between plots and along the back
		for _, s in ipairs({ -1, 1 }) do
			local hx = cx + s * (S.PLOT_W / 2 - 1.5)
			P(lot, "Hedge", Vector3.new(3, 3.4, 120), Vector3.new(hx, 1.7, -8), rgb(74, 138, 66), Mat.LeafyGrass)
		end
		P(lot, "BackHedge", Vector3.new(S.PLOT_W - 6, 3.4, 3), Vector3.new(cx, 1.7, -70), rgb(74, 138, 66), Mat.LeafyGrass)
		-- back garden trees
		for i = 1, 7 do
			local tx = cx + rng:NextNumber(-100, 100)
			local tz = rng:NextNumber(-64, -42)
			prop(lot, ({ "TreeA", "TreeB", "TreeA" })[rng:NextInteger(1, 3)], Vector3.new(tx, 0, tz), rng:NextNumber(0, 360), nil, rng:NextNumber(0.9, 1.25))
		end
		-- the "free plot" board, shown while nobody owns the plot (Plots parents it)
		M.vacant(lot, cx, k)
	end
end

-- round 10e: a smarter empty lot. A navy and gold billboard (the game's colours) on steel legs with lamps,
-- a velvet-rope line of brass posts where the hotel's front would be, a few cones and a "coming soon" A-frame
function M.vacant(lot, cx, k)
	local old = lot:FindFirstChild("Vacant")
	if old then old:Destroy() end
	local vac = model(lot, "Vacant")
	local NAVY, GOLD, CREAM, STEEL = rgb(24, 32, 58), rgb(226, 182, 92), rgb(250, 242, 224), rgb(64, 66, 74)
	-- billboard
	for _, sx in ipairs({ -1, 1 }) do
		P(vac, "Leg", Vector3.new(0.9, 12, 0.9), Vector3.new(cx + sx * 9, 6, 50), STEEL, Mat.Metal)
		P(vac, "Brace", Vector3.new(0.4, 0.4, 3.2), Vector3.new(cx + sx * 9, 1.4, 50.8), STEEL, Mat.Metal)
	end
	P(vac, "Frame", Vector3.new(22, 9.4, 0.7), Vector3.new(cx, 11, 50.2), GOLD, Mat.Metal)
	local board = P(vac, "Board", Vector3.new(21, 8.4, 0.5), Vector3.new(cx, 11, 50.5), NAVY, Mat.SmoothPlastic)
	local top = P(vac, "Line1", Vector3.new(19, 3.6, 0.1), Vector3.new(cx, 12.7, 50.8), NAVY, Mat.SmoothPlastic, { Transparency = 1, CanCollide = false })
	signText(top, Enum.NormalId.Back, "PRIME HOTEL LOT", GOLD, nil, Enum.Font.GothamBlack)
	local mid = P(vac, "Line2", Vector3.new(16, 2.2, 0.1), Vector3.new(cx, 9.6, 50.8), NAVY, Mat.SmoothPlastic, { Transparency = 1, CanCollide = false })
	signText(mid, Enum.NormalId.Back, "PLOT " .. k .. "  -  AVAILABLE", CREAM, nil, Enum.Font.GothamBold)
	P(vac, "Rule", Vector3.new(14, 0.15, 0.1), Vector3.new(cx, 11, 50.8), GOLD, Mat.SmoothPlastic, { CanCollide = false })
	-- two little lamps over the board
	for _, sx in ipairs({ -1, 1 }) do
		P(vac, "LampArm", Vector3.new(0.3, 0.3, 2.2), Vector3.new(cx + sx * 6, 16.1, 51.4), STEEL, Mat.Metal)
		local head = P(vac, "LampHead", Vector3.new(1.4, 0.5, 0.9), Vector3.new(cx + sx * 6, 16, 52.4), STEEL, Mat.Metal)
		local glow = P(vac, "Glow", Vector3.new(1.1, 0.12, 0.6), Vector3.new(cx + sx * 6, 15.72, 52.4), rgb(255, 236, 190), Mat.Neon, { CanCollide = false })
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Angle = 70
		l.Range = 12
		l.Brightness = 2
		l.Color = rgb(255, 230, 180)
		l.Parent = glow
		nightLight(vac, glow, rgb(255, 236, 190))
	end
	-- velvet rope along the front of the build site
	local posts = {}
	for x = cx - 44, cx + 44, 11 do
		P(vac, "PostBase", Vector3.new(1.3, 0.3, 1.3), Vector3.new(x, 0.4, 34), GOLD, Mat.Metal)
		P(vac, "Post", Vector3.new(0.35, 3, 0.35), Vector3.new(x, 1.95, 34), GOLD, Mat.Metal)
		P(vac, "PostCap", Vector3.new(0.6, 0.6, 0.6), Vector3.new(x, 3.6, 34), GOLD, Mat.Metal, { Shape = Enum.PartType.Ball })
		table.insert(posts, x)
	end
	for i = 1, #posts - 1 do
		local a, b = posts[i], posts[i + 1]
		-- a gentle sag in three straight pieces
		local pts = { Vector3.new(a, 3.2, 34), Vector3.new(a + (b - a) * 0.33, 2.55, 34), Vector3.new(a + (b - a) * 0.67, 2.55, 34), Vector3.new(b, 3.2, 34) }
		for j = 1, 3 do
			local p0, p1 = pts[j], pts[j + 1]
			local len = (p1 - p0).Magnitude
			P(vac, "Rope", Vector3.new(len, 0.22, 0.22), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.rad(90), 0), rgb(150, 30, 46), Mat.Fabric, { CanCollide = false })
		end
	end
	-- cones and a coming-soon sign
	for i, off in ipairs({ -30, -24, 24, 30 }) do
		local base = P(vac, "ConeBase", Vector3.new(1.4, 0.2, 1.4), Vector3.new(cx + off, 0.35, 38 + (i % 2) * 2), rgb(40, 40, 44), Mat.SmoothPlastic)
		local cone = Instance.new("Part")
		cone.Name = "Cone"
		cone.Anchored = true
		cone.Size = Vector3.new(1, 2.2, 1)
		cone.Color = rgb(250, 120, 40)
		cone.Material = Mat.SmoothPlastic
		cone.CFrame = CFrame.new(base.Position + Vector3.new(0, 1.2, 0))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = "rbxassetid://1033714"
		mesh.Scale = Vector3.new(0.55, 1.1, 0.55)
		mesh.Parent = cone
		cone.Parent = vac
		P(vac, "ConeStripe", Vector3.new(0.75, 0.3, 0.75), base.Position + Vector3.new(0, 1.3, 0), rgb(250, 250, 250), Mat.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(base.Position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	end
	for _, sz in ipairs({ -1, 1 }) do
		local panel = P(vac, "AFrame", Vector3.new(3.4, 4.2, 0.2), CFrame.new(cx + 16, 2.1, 40) * CFrame.Angles(math.rad(sz * 14), 0, 0) * CFrame.new(0, 0, sz * 0.5), CREAM, Mat.SmoothPlastic)
		if sz == 1 then
			signText(panel, Enum.NormalId.Back, "COMING\nSOON", NAVY, nil, Enum.Font.GothamBlack)
		end
	end
end

---------------------------------------------------------------- shops across the street

local FACADES = { rgb(236, 214, 180), rgb(214, 128, 96), rgb(160, 186, 160), rgb(132, 158, 196), rgb(234, 176, 176),
	rgb(196, 188, 176), rgb(246, 232, 200), rgb(176, 120, 96), rgb(120, 136, 150), rgb(220, 196, 150) }
local AWNINGS = { { rgb(220, 70, 70), rgb(250, 246, 240) }, { rgb(40, 120, 90), rgb(250, 246, 240) }, { rgb(50, 90, 170), rgb(250, 246, 240) },
	{ rgb(240, 170, 50), rgb(250, 246, 240) }, { rgb(150, 70, 140), rgb(250, 230, 240) }, { rgb(30, 30, 34), rgb(240, 200, 80) } }
local SHOPS = { "BEAN THERE CAFE", "PIXEL ARCADE", "FRESH MARKET", "BLOOM FLORIST", "GOLDEN CRUST", "THE BOOK NOOK", "STARLIGHT CINEMA",
	"SUDS LAUNDRY", "NOODLE HOUSE", "IRON GYM", "PET PALACE", "SCOOP DREAMS", "CITY PHARMACY", "TECH HUB", "PIZZA CORNER", "BARBER & CO",
	"SUSHI GO", "VINYL RECORDS", "TOY BOX", "CORNER DELI", "SPICE ROUTE", "BIKE SHOP", "NAIL STUDIO", "TACO TOWN" }
local WIN_LIT = { rgb(255, 214, 150), rgb(255, 230, 190), rgb(250, 200, 140), rgb(210, 230, 255) }

local function building(parent, x0, width, idx)
	local m = model(parent, "Building")
	local depth = rng:NextNumber(36, 52)
	local floors = rng:NextInteger(2, 6)
	local GF = 15 -- ground floor height
	local FH = 11
	local h = GF + floors * FH
	local zf = S.FAR.z1 -- the facade line
	local cx = x0 + width / 2
	local col = FACADES[rng:NextInteger(1, #FACADES)]
	local mat = rng:NextNumber() < 0.45 and Mat.Brick or Mat.SmoothPlastic
	local body = P(m, "Body", Vector3.new(width, h - GF, depth), Vector3.new(cx, GF + (h - GF) / 2, zf + depth / 2), col, mat)
	P(m, "Rear", Vector3.new(width, GF, depth - 7), Vector3.new(cx, GF / 2, zf + 7 + (depth - 7) / 2), col, mat)
	for _, sx in ipairs({ -1, 1 }) do
		P(m, "SideWall", Vector3.new(1, GF, 7), Vector3.new(cx + sx * (width / 2 - 0.5), GF / 2, zf + 3.5), col, mat)
	end
	P(m, "ShopFloor", Vector3.new(width - 2, 0.6, 7), Vector3.new(cx, 1.0, zf + 3.5), rgb(160, 120, 90), Mat.WoodPlanks)
	P(m, "Ceiling", Vector3.new(width - 2, 0.6, 7), Vector3.new(cx, GF - 0.3, zf + 3.5), rgb(240, 236, 228), Mat.SmoothPlastic)
	P(m, "Counter", Vector3.new(math.min(10, width / 3), 3.4, 2.4), Vector3.new(cx - width / 5, 3.0, zf + 4.4), rgb(120, 84, 60), Mat.Wood)
	for i = 0, 2 do
		P(m, "Shelf", Vector3.new(width / 3, 0.4, 1.2), Vector3.new(cx + width / 6, 4 + i * 3, zf + 6.3), rgb(150, 110, 80), Mat.Wood)
		for j = 0, 4 do
			P(m, "Goods", Vector3.new(1.2, 1.6, 0.9), Vector3.new(cx + width / 6 - width / 7 + j * width / 14, 5 + i * 3, zf + 6.2),
				FACADES[rng:NextInteger(1, #FACADES)], Mat.SmoothPlastic)
		end
	end
	-- ground floor: shop front
	local trim = col:Lerp(Color3.new(1, 1, 1), 0.55)
	P(m, "Base", Vector3.new(width + 0.4, 1.4, 1.2), Vector3.new(cx, 0.7, zf - 0.1), rgb(90, 86, 82), Mat.Granite)
	local glassW = width - 6
	P(m, "ShopGlass", Vector3.new(glassW, GF - 6, 0.4), Vector3.new(cx, 1.4 + (GF - 6) / 2, zf - 0.05), rgb(150, 190, 210), Mat.Glass, { Transparency = 0.35, Reflectance = 0.2 })
	local lamp = P(m, "ShopLight", Vector3.new(width - 6, 0.3, 1), Vector3.new(cx, GF - 0.75, zf + 3.5), rgb(240, 236, 226), Mat.SmoothPlastic)
	local pl = Instance.new("PointLight")
	pl.Range = 16; pl.Brightness = 1.4; pl.Color = rgb(255, 226, 180); pl.Enabled = false; pl.Parent = lamp
	nightLight(m, lamp, rgb(255, 236, 200))
	for gx = cx - glassW / 2, cx + glassW / 2 + 0.01, glassW / math.max(1, math.floor(glassW / 8)) do
		P(m, "Mullion", Vector3.new(0.5, GF - 6, 0.6), Vector3.new(gx, 1.4 + (GF - 6) / 2, zf - 0.2), rgb(40, 42, 46), Mat.Metal)
	end
	P(m, "Door", Vector3.new(4.5, 9, 0.5), Vector3.new(cx + glassW / 2 - 3.5, 5.9, zf - 0.3), rgb(50, 46, 44), Mat.Wood)
	-- sign band and awning
	local band = P(m, "SignBand", Vector3.new(width, 4, 1.2), Vector3.new(cx, GF - 2.2, zf - 0.5), trim, Mat.SmoothPlastic)
	local name = SHOPS[(idx - 1) % #SHOPS + 1]
	local aw = AWNINGS[rng:NextInteger(1, #AWNINGS)]
	local sign = P(m, "Sign", Vector3.new(math.min(width - 4, 30), 3, 0.3), Vector3.new(cx, GF - 2.2, zf - 1.2), aw[1], Mat.SmoothPlastic)
	signText(sign, Enum.NormalId.Front, name, aw[2])
	-- striped awning out over the sidewalk
	local stripes = math.floor((width - 4) / 3)
	local sw = (width - 4) / stripes
	for i = 0, stripes - 1 do
		local c = (i % 2 == 0) and aw[1] or aw[2]
		local sx = cx - (width - 4) / 2 + sw * (i + 0.5)
		P(m, "Awning", Vector3.new(sw, 0.25, 5.6), CFrame.new(sx, GF - 5.4, zf - 2.5) * CFrame.Angles(math.rad(-24), 0, 0), c, Mat.Fabric)
		P(m, "Valance", Vector3.new(sw, 1.1, 0.15), Vector3.new(sx, GF - 7.1, zf - 5.1), c, Mat.Fabric)
	end
	-- cornice between the shop and the floors above
	P(m, "Cornice", Vector3.new(width + 0.8, 0.9, 1.8), Vector3.new(cx, GF + 0.1, zf - 0.6), trim, Mat.SmoothPlastic)
	-- upper windows, lit at random at night
	local cols = math.max(2, math.floor(width / 9))
	local step = width / cols
	for f = 0, floors - 1 do
		local wy = GF + f * FH + FH / 2 + 0.4
		for c = 0, cols - 1 do
			local wx = x0 + step * (c + 0.5)
			local frame = P(m, "WinFrame", Vector3.new(5.2, 6.6, 0.5), Vector3.new(wx, wy, zf - 0.1), trim, Mat.SmoothPlastic)
			local glass = P(m, "Window", Vector3.new(4.4, 5.8, 0.3), Vector3.new(wx, wy, zf - 0.3), rgb(70, 96, 124), Mat.Glass, { Reflectance = 0.25 })
			if rng:NextNumber() < 0.5 then
				glass:SetAttribute("LitColor", WIN_LIT[rng:NextInteger(1, #WIN_LIT)])
			end
			P(m, "Sill", Vector3.new(5.8, 0.4, 1.0), Vector3.new(wx, wy - 3.5, zf - 0.5), trim, Mat.SmoothPlastic)
			if rng:NextNumber() < 0.12 then
				-- a balcony now and then
				P(m, "Balcony", Vector3.new(6.4, 0.5, 3), Vector3.new(wx, wy - 3.4, zf - 1.6), trim, Mat.SmoothPlastic)
				P(m, "Rail", Vector3.new(6.4, 2.4, 0.2), Vector3.new(wx, wy - 2.0, zf - 3.0), rgb(40, 42, 46), Mat.Metal, { Transparency = 0.1 })
			end
		end
	end
	CS:AddTag(m, "NightLight")
	-- roof: parapet and kit
	P(m, "Parapet", Vector3.new(width + 0.6, 1.6, 1.0), Vector3.new(cx, h + 0.8, zf - 0.2), trim, Mat.SmoothPlastic)
	if rng:NextNumber() < 0.6 then
		P(m, "AC", Vector3.new(5, 3, 4), Vector3.new(cx + rng:NextNumber(-width / 3, width / 3), h + 1.5, zf + depth / 2), rgb(190, 192, 196), Mat.Metal)
	end
	if rng:NextNumber() < 0.3 then
		local t = P(m, "WaterTank", Vector3.new(7, 7, 7), Vector3.new(cx, h + 7, zf + depth * 0.6), rgb(140, 100, 70), Mat.WoodPlanks, { Shape = Enum.PartType.Cylinder })
		t.CFrame = CFrame.new(t.Position) * CFrame.Angles(0, 0, math.rad(90))
		for _, sx in ipairs({ -2.5, 2.5 }) do
			P(m, "TankLeg", Vector3.new(0.5, 4, 0.5), Vector3.new(cx + sx, h + 2, zf + depth * 0.6), rgb(50, 50, 54), Mat.Metal)
		end
	end
	return m, h
end

local function shops()
	local f = folder(CITY, "Shops")
	local x = S.X0 + 40
	local idx = 1
	while x < S.X1 - 40 do
		local w = rng:NextNumber(30, 56)
		if x + w > S.X1 - 40 then break end
		building(f, x, w, idx)
		idx += 1
		x += w + rng:NextNumber(0, 1) * (rng:NextNumber() < 0.25 and 8 or 0)
	end
	-- café tables in front of a few shops
	for i = 1, 6 do
		local cx = rng:NextNumber(S.X0 + 80, S.X1 - 80)
		if not nearCross(cx, 16) then
			prop(f, "CafeTable", Vector3.new(cx, S.Y, S.FAR.z1 - 2.6), 0, nil, 0.62)
		end
	end
end

local function skyline()
	local f = folder(CITY, "Skyline")
	local x = S.X0 - 100
	while x < S.X1 + 100 do
		local w = rng:NextNumber(50, 110)
		local h = rng:NextNumber(90, 260)
		local z = rng:NextNumber(220, 330)
		local d = rng:NextNumber(50, 90)
		local tone = rng:NextNumber(0.75, 1)
		local col = ({ rgb(150, 170, 196), rgb(196, 200, 210), rgb(170, 186, 200), rgb(214, 206, 196), rgb(120, 140, 170) })[rng:NextInteger(1, 5)]
		local m = model(f, "Tower")
		P(m, "Body", Vector3.new(w, h, d), Vector3.new(x + w / 2, h / 2, z), col, Mat.SmoothPlastic)
		-- window bands on the street face (lit at night)
		for y = 14, h - 8, 10 do
			local band = P(m, "Band", Vector3.new(w - 6, 4.2, 0.6), Vector3.new(x + w / 2, y, z - d / 2 - 0.2), rgb(80, 104, 136), Mat.Glass, { Reflectance = 0.3 })
			if rng:NextNumber() < 0.55 then band:SetAttribute("LitColor", WIN_LIT[rng:NextInteger(1, #WIN_LIT)]:Lerp(rgb(255, 255, 255), 0.1)) end
		end
		if rng:NextNumber() < 0.4 then
			local cap = P(m, "Crown", Vector3.new(w * 0.6, 14, d * 0.6), Vector3.new(x + w / 2, h + 7, z), col:Lerp(Color3.new(1, 1, 1), 0.2), Mat.SmoothPlastic)
			local beacon = P(m, "Beacon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(x + w / 2, h + 15, z), rgb(120, 30, 30), Mat.SmoothPlastic)
			beacon:SetAttribute("LitColor", rgb(255, 60, 60))
		end
		CS:AddTag(m, "NightLight")
		x += w + rng:NextNumber(4, 30)
	end
end

---------------------------------------------------------------- tunnels at both ends

local function tunnels()
	local f = folder(CITY, "Tunnels")
	local z0, z1 = S.NEAR.z0 - 4, S.FAR.z1 + 4
	local zc, zw = (z0 + z1) / 2, z1 - z0
	for _, x in ipairs({ S.X0, S.X1 }) do
		local s = x < 0 and -1 or 1
		local m = model(f, "Tunnel")
		local CONC = rgb(196, 190, 180)
		-- portal face: two piers, a lintel with the city name, and a dark bore
		P(m, "Lintel", Vector3.new(8, 12, zw + 16), Vector3.new(x, 32, zc), CONC, Mat.Concrete)
		for _, z in ipairs({ z0 - 4, z1 + 4 }) do
			P(m, "Pier", Vector3.new(8, 38, 8), Vector3.new(x, 19, z), CONC, Mat.Concrete)
		end
		local name = P(m, "NamePlate", Vector3.new(0.4, 6, 40), Vector3.new(x - s * 4.2, 32, zc), rgb(40, 60, 90), Mat.SmoothPlastic)
		signText(name, s < 0 and Enum.NormalId.Right or Enum.NormalId.Left, "HARBOUR VIEW", rgb(255, 236, 190))
		P(m, "Ceiling", Vector3.new(150, 2, zw), Vector3.new(x + s * 79, 27, zc), rgb(70, 70, 74), Mat.Concrete)
		for _, z in ipairs({ z0, z1 }) do
			P(m, "Wall", Vector3.new(150, 28, 2), Vector3.new(x + s * 79, 13, z), rgb(150, 146, 140), Mat.Concrete)
		end
		-- a black curtain deep inside hides where cars and people pop in and out
		P(m, "Dark", Vector3.new(2, 28, zw), Vector3.new(x + s * 150, 13, zc), Color3.new(0, 0, 0), Mat.SmoothPlastic)
		-- tunnel lights
		for d = 10, 140, 18 do
			local l = P(m, "TunnelLight", Vector3.new(3, 0.4, 1.2), Vector3.new(x + s * d, 25.8, zc), rgb(255, 214, 150), Mat.Neon)
			local pl = Instance.new("PointLight")
			pl.Range = 22; pl.Brightness = 1.6; pl.Color = rgb(255, 210, 150); pl.Parent = l
		end
	end
end

---------------------------------------------------------------- parked cars (static)

local function parked()
	local f = folder(CITY, "Parked")
	local kinds = { "Sedan", "Hatch", "SUV", "Sedan", "Hatch", "Pickup", "Van" }
	for _, side in ipairs({ { z = S.PARK[1], yaw = 180 }, { z = S.PARK[2], yaw = 0 } }) do
		for x = S.X0 + 40, S.X1 - 40, 26 do
			if rng:NextNumber() < 0.38 and not nearCross(x, 22) and not (side.z < 92 and nearHotelPath(x)) then
				local kind = kinds[rng:NextInteger(1, #kinds)]
				local car = prop(f, kind, Vector3.new(x + 13, 0, side.z), side.yaw, CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
				if car then
					local wheelX = ({ Sedan = 4.75, Hatch = 3.9, SUV = 5.1, Pickup = 5.4, Van = 5.6 })[kind]
					local wheelR = ({ Sedan = 1.35, Hatch = 1.3, SUV = 1.6, Pickup = 1.55, Van = 1.45 })[kind]
					local hw = ({ Sedan = 3.2, Hatch = 3.0, SUV = 3.5, Pickup = 3.4, Van = 3.5 })[kind]
					local base = car:GetPivot()
					for _, wx in ipairs({ -wheelX, wheelX }) do
						for _, s in ipairs({ -1, 1 }) do
							local w = PROPS.CarWheel:Clone()
							w:ScaleTo(wheelR / 1.35)
							w:PivotTo(base * CFrame.new(wx, 0, s * (hw - 0.55)) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0))
							for _, p in ipairs(w:GetDescendants()) do
								if p:IsA("BasePart") then p.Parent = car end
							end
							w:Destroy()
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- build

function M.build()
	local old = workspace:FindFirstChild("City")
	if old then old:Destroy() end
	CITY = Instance.new("Folder")
	CITY.Name = "City"
	CITY.Parent = workspace
	rng = Random.new(2611)
	terrain()
	road()
	sidewalk({ name = "NearWalk", z0 = S.NEAR.z0, z1 = S.NEAR.z1, curbZ = S.NEAR.z1 - 0.6, bandZ = S.NEAR.z0 + 0.8, furnZ = S.NEAR.z1 - 3.4 })
	sidewalk({ name = "FarWalk", z0 = S.FAR.z0, z1 = S.FAR.z1, curbZ = S.FAR.z0 + 0.6, bandZ = S.FAR.z1 - 0.8, furnZ = S.FAR.z0 + 3.4 })
	furniture()
	lots()
	shops()
	skyline()
	tunnels()
	parked()
	-- the old per-plot street goes away (Plots no longer clones it)
	local outside = workspace:FindFirstChild("Outside")
	if outside then outside.Parent = game.ServerStorage.DevTools end
	local n = 0
	for _, d in ipairs(CITY:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

M.prop = prop
return M
