--@@BUILDING
-- [R16A] round 16c: the far side of the street is a seaside resort now. Past the far sidewalk: a stone promenade
-- with palms, globe lamps and little pavilions, a balustrade with steps down to a sand beach, then the sea
-- (a pier, boats, a lighthouse and far islands: see skyline()). Shared.Street's numbers are untouched, so the
-- crowds, traffic and plots work as before. Most models are AI-generated textured meshes kept in
-- ServerStorage.CityProps (DevTools.Gen16 adopts them); the balustrade is rah_props_r16.py.
local SKIN = {
	brick = { Mat.Brick, "R16_Brick" }, stucco = { Mat.Plaster, "R16_Stucco" }, stone = { Mat.Limestone, "R16_Stone" },
	roof = { Mat.Slate, "R16_Roof" }, asphalt = { Mat.Asphalt, "R16_Asphalt" }, paver = { Mat.Pavement, "R16_Paver" },
	tower = { Mat.Metal, "R16_Tower" }, leaf = { Mat.LeafyGrass, "R16_Leaf" },
}
local function skin(p, kind, color)
	p.Material = SKIN[kind][1]
	p.MaterialVariant = SKIN[kind][2]
	if color then p.Color = color end
	return p
end

-- a kit piece at cf; kx stretches it along its length; tints = { group = Color3 }
local function kit(parent, name, cf, kx, tints)
	local src = PROPS:FindFirstChild(name)
	if not src then warn("missing kit " .. name) return nil end
	local m = src:Clone()
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			if kx and math.abs(kx - 1) > 0.01 then p.Size = p.Size * Vector3.new(kx, 1, 1) end
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			local c = tints and tints[p:GetAttribute("Group")]
			if c then p.Color = c end
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

COLLIDE.PalmS = { r = 0.8, h = 5 }
COLLIDE.GlobeLamp = { r = 0.6, h = 15 }
COLLIDE.UmbrellaSet = { r = 0.3, h = 7 }
local PROM_Z = 150 -- the sea edge of the promenade
local SEA_Y = -5
local SAND = rgb(246, 226, 178)
local STONE = rgb(240, 228, 206)
local function beachY(z)
	if z <= 152 then return 0 end
	if z <= 232 then return -8 * (z - 152) / 80 end
	return math.max(-20, -8 - 12 * (z - 232) / 68)
end
-- where the balustrade opens: steps down to the sand, and the pier
local PIER_X = S.CROSS[2]
local STAIRS = {}
for x = S.X0 + 150, S.X1 - 100, 230 do
	if math.abs(x - PIER_X) > 60 then table.insert(STAIRS, x) end
end
local function nearGap(x, pad)
	if math.abs(x - PIER_X) < 9 + pad then return true end
	for _, sx in ipairs(STAIRS) do
		if math.abs(x - sx) < 8 + pad then return true end
	end
	return false
end

local function beach()
	local T = workspace.Terrain
	T.WaterColor = rgb(38, 168, 188)
	T.WaterTransparency = 0.55
	T.WaterWaveSize = 0.12
	T.WaterWaveSpeed = 8
	T.WaterReflectance = 0.6
	T:SetMaterialColor(Mat.Sand, SAND)
	for x = -1600, 1600, 400 do
		local cx = x + 200
		-- under the promenade deck: clear ground (terrain smooths up to y = 2 and would cover the deck)
		T:FillBlock(CFrame.new(cx, 4, 139), Vector3.new(400, 16, 26), Mat.Air)
		T:FillBlock(CFrame.new(cx, -8, 139), Vector3.new(400, 8, 26), Mat.Concrete)
		-- open sea over a sand floor. Everything is cleared to air first: a water fill doesn't push out the turf,
		-- and grass blades grew up through the waves
		for _, zz in ipairs({ { 396, 400 }, { 796, 400 }, { 1096, 200 } }) do
			T:FillBlock(CFrame.new(cx, 36, zz[1]), Vector3.new(400, 128, zz[2]), Mat.Air)
			T:FillBlock(CFrame.new(cx, -26, zz[1]), Vector3.new(400, 8, zz[2]), Mat.Sand)
			T:FillBlock(CFrame.new(cx, -13.5, zz[1]), Vector3.new(400, 17, zz[2]), Mat.Water)
		end
		-- the beach falls from the promenade into the water
		for z = 152, 296, 4 do
			local top = beachY(z + 2)
			T:FillBlock(CFrame.new(cx, (top + 70) / 2, z + 2), Vector3.new(400, 70 - top, 4), Mat.Air)
			T:FillBlock(CFrame.new(cx, (top - 26) / 2, z + 2), Vector3.new(400, top + 26, 4), Mat.Sand)
			if top < SEA_Y - 1 then
				T:FillBlock(CFrame.new(cx, (top + SEA_Y) / 2, z + 2), Vector3.new(400, SEA_Y - top, 4), Mat.Water)
			end
		end
		task.wait()
	end
	-- the headlands over the tunnels (the sea fill cut into them) and their bores
	for _, x in ipairs({ S.X0, S.X1 }) do
		local s = x < 0 and -1 or 1
		T:FillBall(Vector3.new(x + s * 90, 10, 90), 120, Mat.Rock)
		T:FillBall(Vector3.new(x + s * 130, 30, 200), 120, Mat.Grass)
		T:FillBall(Vector3.new(x + s * 150, -10, 300), 90, Mat.Rock)
		T:FillBlock(CFrame.new(x + s * 80, 20, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(160, 40, S.FAR.z1 - S.NEAR.z0 + 6), Mat.Air)
		T:FillBlock(CFrame.new(x + s * 80, -2, (S.NEAR.z0 + S.FAR.z1) / 2), Vector3.new(160, 4, S.FAR.z1 - S.NEAR.z0 + 6), Mat.Pavement)
	end
	-- far islands on the horizon, and the lighthouse rock
	for i = 1, 7 do
		local x = -1300 + i * 380 + rng:NextNumber(-80, 80)
		local z = rng:NextNumber(640, 760)
		local r = rng:NextNumber(60, 110)
		T:FillBall(Vector3.new(x, -r * 0.45, z), r, Mat.Rock)
		T:FillBall(Vector3.new(x + rng:NextNumber(-20, 20), -r * 0.3, z + 10), r * 0.8, Mat.Grass)
	end
	T:FillBall(Vector3.new(-560, -26, 470), 36, Mat.Rock)
	T:FillBall(Vector3.new(-538, -22, 486), 22, Mat.Rock)
end

local function onSand(parent, name, x, z, yaw, scale)
	return prop(parent, name, Vector3.new(x, beachY(z) - 0.25, z), yaw, nil, scale)
end

local function shops()
	beach()
	local f = folder(CITY, "Shops")
	local za = S.FAR.z1
	local zc, zw = (za + PROM_Z) / 2, PROM_Z - za
	local xa, xb = S.X0 + 24, S.X1 - 24
	local xm = (xa + xb) / 2
	-- the deck (two parts: one would pass the 2048 stud limit), with terracotta bands along both edges
	for _, h in ipairs({ { xa, xm }, { xm, xb } }) do
		local cx, w = (h[1] + h[2]) / 2, h[2] - h[1]
		skin(P(f, "Deck", Vector3.new(w, 1, zw), Vector3.new(cx, 0, zc), rgb(246, 232, 206)), "paver")
		for _, z in ipairs({ za + 1.2, PROM_Z - 2.6 }) do
			skin(P(f, "DeckBand", Vector3.new(w, 1, 1.2), Vector3.new(cx, 0.03, z), rgb(226, 150, 112)), "paver")
		end
		skin(P(f, "SeaWall", Vector3.new(w, 8, 1.8), Vector3.new(cx, -3.5, PROM_Z + 0.5), STONE), "stone")
	end
	-- balustrade, open at the steps and the pier
	for x = xa + 4, xb - 4, 8 do
		if not nearGap(x, 4) then
			kit(f, "Balustrade", CFrame.new(x, 0.5, PROM_Z + 0.4), 1, { trim = STONE })
		end
	end
	for _, sx in ipairs(STAIRS) do
		for k = 0, 9 do
			local top = 0.5 - k * 0.5
			skin(P(f, "Step", Vector3.new(16, 3, 2), Vector3.new(sx, top - 1.5, PROM_Z + 1 + k * 2), STONE), "stone")
		end
		for _, s in ipairs({ -1, 1 }) do
			skin(P(f, "StepCheek", Vector3.new(1.4, 5, 21), Vector3.new(sx + s * 8.7, -1.6, PROM_Z + 10.5), STONE), "stone")
		end
	end
	-- pavilions along the promenade, each with its own little setting
	local kinds = { "BeachCafe", "IceCream", "SurfShack", "Gazebo" }
	local pav = {}
	local i = 0
	for x = xa + 90, xb - 60, 176 do
		i += 1
		local px = nearGap(x, 14) and x + 30 or x
		local kind = kinds[(i - 1) % #kinds + 1]
		table.insert(pav, px)
		prop(f, kind, Vector3.new(px, S.Y, zc + 1), 180)
		for _, s in ipairs({ -1, 1 }) do
			prop(f, "PlanterUrn", Vector3.new(px + s * 15, S.Y, za + 4), rng:NextNumber(0, 360))
		end
		if kind == "BeachCafe" or kind == "IceCream" then
			for _, s in ipairs({ -1, 1 }) do
				prop(f, "CafeTable", Vector3.new(px + s * 19, S.Y, zc - 4), rng:NextNumber(0, 360), nil, 0.62)
			end
		end
	end
	local function nearPav(x, pad)
		for _, px in ipairs(pav) do
			if math.abs(x - px) < pad then return true end
		end
		return false
	end
	-- two rows of palms, lamps between them, benches looking out to sea
	local palms = { "TreeA", "TreeB", "TreeA" }
	i = 0
	for x = xa + 12, xb - 12, 15 do
		i += 1
		local sea = i % 2 == 0
		local z = sea and PROM_Z - 4.2 or za + 4
		if not nearPav(x, 15) and not (sea and nearGap(x, 3)) then
			if i % 4 == 1 then
				local l = prop(f, "GlobeLamp", Vector3.new(x, S.Y, z), rng:NextNumber(0, 360))
				if l then
					local g = P(l, "LampLight", Vector3.new(1, 1, 1), Vector3.new(x, S.Y + 14.5, z), nil, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
					local pl = Instance.new("PointLight")
					pl.Range = 22; pl.Brightness = 0.55; pl.Color = rgb(255, 232, 196); pl.Enabled = false; pl.Parent = g
					CS:AddTag(l, "NightLight")
				end
			else
				prop(f, palms[rng:NextInteger(1, #palms)], Vector3.new(x, S.Y, z), rng:NextNumber(0, 360), nil, rng:NextNumber(0.85, 1.12))
			end
		elseif sea and not nearGap(x, 3) and nearPav(x, 15) and not nearPav(x, 9) then
			prop(f, "Bench", Vector3.new(x, S.Y, PROM_Z - 3), 0)
		end
	end
	-- the beach: parasols in two loose rows, lifeguard towers, boats pulled up on the sand
	for x = xa + 20, xb - 20, 21 do
		for _, z in ipairs({ 166, 184 }) do
			if rng:NextNumber() < 0.62 and not nearGap(x, 6) then
				onSand(f, "UmbrellaSet", x + rng:NextNumber(-5, 5), z + rng:NextNumber(-4, 4), rng:NextNumber(-25, 25), rng:NextNumber(0.92, 1.08))
			end
		end
	end
	for x = xa + 260, xb - 100, 520 do
		onSand(f, "Lifeguard", x, 176, 0)
	end
	for n = 1, 10 do
		local x = rng:NextNumber(xa + 40, xb - 40)
		onSand(f, "RowBoat", x, 198 + rng:NextNumber(-3, 3), rng:NextNumber(-40, 40) + (rng:NextNumber() < 0.5 and 0 or 180))
	end
end

--@@SKYLINE
local function skyline()
	local f = folder(CITY, "Skyline")
	-- the pier: plank deck on timber piles, rails, lamps, a bandstand on the head
	local WOOD, WOOD_DK = rgb(190, 150, 108), rgb(112, 84, 62)
	local WHITE_P = rgb(244, 240, 232)
	local pier = model(f, "Pier")
	local z0, z1 = PROM_Z - 1, 440
	local len = z1 - z0
	local zm = (z0 + z1) / 2
	P(pier, "PierDeck", Vector3.new(16, 1, len), Vector3.new(PIER_X, 0, zm), WOOD, Mat.WoodPlanks)
	P(pier, "PierHead", Vector3.new(56, 1, 56), Vector3.new(PIER_X, 0, z1 + 28), WOOD, Mat.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		P(pier, "Beam", Vector3.new(1, 1.6, len), Vector3.new(PIER_X + s * 7.6, -1, zm), WOOD_DK, Mat.Wood)
		P(pier, "Rail", Vector3.new(0.5, 0.4, len - 2), Vector3.new(PIER_X + s * 7.6, 3.9, zm + 1), WHITE_P, Mat.Wood)
		P(pier, "RailLow", Vector3.new(0.3, 0.3, len - 2), Vector3.new(PIER_X + s * 7.6, 2.3, zm + 1), WHITE_P, Mat.Wood)
		for z = z0 + 6, z1, 8 do
			P(pier, "RailPost", Vector3.new(0.5, 3.8, 0.5), Vector3.new(PIER_X + s * 7.6, 2.3, z), WHITE_P, Mat.Wood)
		end
		for z = z0 + 18, z1 + 50, 24 do
			local wide = z > z1 and 27 or 7
			P(pier, "Pile", Vector3.new(26, 1.8, 1.8), CFrame.new(PIER_X + s * wide, -12.5, z) * CFrame.Angles(0, 0, math.pi / 2), WOOD_DK, Mat.Wood, { Shape = Enum.PartType.Cylinder })
		end
	end
	for _, c in ipairs({ { -1, 0 }, { 1, 0 }, { 0, 1 } }) do -- rails round the pier head
		local along = c[1] ~= 0
		P(pier, "Rail", along and Vector3.new(0.5, 0.4, 56) or Vector3.new(56, 0.4, 0.5),
			Vector3.new(PIER_X + c[1] * 27.6, 3.9, z1 + 28 + c[2] * 27.6), WHITE_P, Mat.Wood)
		for k = -3, 3 do
			P(pier, "RailPost", Vector3.new(0.5, 3.8, 0.5),
				Vector3.new(PIER_X + c[1] * 27.6 + (along and 0 or k * 9), 2.3, z1 + 28 + c[2] * 27.6 + (along and k * 9 or 0)), WHITE_P, Mat.Wood)
		end
	end
	for z = z0 + 30, z1, 60 do
		for _, s in ipairs({ -1, 1 }) do
			local l = prop(pier, "GlobeLamp", Vector3.new(PIER_X + s * 6.4, 0.5, z), 0, nil, 0.8)
			if l then
				local g = P(l, "LampLight", Vector3.new(1, 1, 1), Vector3.new(PIER_X + s * 6.4, 12, z), nil, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
				local pl = Instance.new("PointLight")
				pl.Range = 20; pl.Brightness = 0.5; pl.Color = rgb(255, 232, 196); pl.Enabled = false; pl.Parent = g
				CS:AddTag(l, "NightLight")
			end
		end
	end
	prop(pier, "Gazebo", Vector3.new(PIER_X, 0.5, z1 + 28), 0, nil, 1.7)
	for _, s in ipairs({ -1, 1 }) do
		prop(pier, "Bench", Vector3.new(PIER_X + s * 20, 0.5, z1 + 50), 0)
		prop(pier, "PlanterUrn", Vector3.new(PIER_X + s * 24, 0.5, z1 + 6), 0)
	end
	-- boats at anchor
	for n = 1, 11 do
		local x = rng:NextNumber(S.X0 + 60, S.X1 - 60)
		if math.abs(x - PIER_X) < 60 then x += 140 end
		prop(f, "Sailboat", Vector3.new(x, SEA_Y - 0.8, rng:NextNumber(300, 600)), rng:NextNumber(0, 360), nil, rng:NextNumber(0.9, 1.5))
	end
	for _, p in ipairs({ { PIER_X - 70, 372, 20 }, { PIER_X + 84, 420, 200 }, { -700, 340, 90 }, { 900, 380, -70 } }) do
		prop(f, "Yacht", Vector3.new(p[1], SEA_Y - 1.2, p[2]), p[3])
	end
	-- the lighthouse on its rock; the lamp comes on at night
	local lh = prop(f, "Lighthouse", Vector3.new(-560, 6, 470), 0)
	if lh then
		local lamp = P(lh, "Beacon", Vector3.new(5, 5, 5), Vector3.new(-560, 6 + 82, 470), rgb(120, 110, 90), Mat.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false, Transparency = 0.2 })
		lamp:SetAttribute("LitColor", rgb(255, 236, 170))
		local pl = Instance.new("PointLight")
		pl.Range = 50; pl.Brightness = 1.6; pl.Color = rgb(255, 236, 170); pl.Enabled = false; pl.Parent = lamp
		CS:AddTag(lh, "NightLight")
	end
	-- marker buoys off the beach
	for x = S.X0 + 120, S.X1 - 120, 150 do
		P(f, "Buoy", Vector3.new(3, 3, 3), Vector3.new(x, SEA_Y + 0.4, 262), rgb(226, 60, 50), Mat.SmoothPlastic, { Shape = Enum.PartType.Ball, CanCollide = false })
		P(f, "BuoyTop", Vector3.new(0.4, 3, 0.4), Vector3.new(x, SEA_Y + 2.6, 262), rgb(240, 240, 236), Mat.Metal, { CanCollide = false })
	end
end

--@@RESTYLE
-- [R16C] round 16c: warm resort surfaces, a planted median down the road, and palms on the hills
local function restyle()
	local function each(folderName, fn)
		local f = CITY:FindFirstChild(folderName)
		if not f then return end
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") and not d:IsA("MeshPart") then fn(d) end
		end
	end
	each("Road", function(p)
		if p.Name == "Asphalt" then skin(p, "asphalt", rgb(138, 132, 130)) end
	end)
	for _, w in ipairs({ "NearWalk", "FarWalk" }) do
		each(w, function(p)
			if p.Name == "Walk" then skin(p, "paver", rgb(246, 232, 206))
			elseif p.Name == "Band" then skin(p, "paver", rgb(226, 150, 112))
			elseif p.Name == "Curb" then skin(p, "stone", rgb(232, 222, 204)) end
		end)
	end
	each("Tunnels", function(p)
		if p.Material == Mat.Concrete then skin(p, "stone", p.Color:Lerp(rgb(255, 244, 224), 0.4)) end
	end)
	-- grass blades poked up through the sidewalks: the turf under them becomes plain ground
	for _, w in ipairs({ S.NEAR, S.FAR }) do
		local r = Region3.new(Vector3.new(S.X0 - 8, -8, w.z0 - 2), Vector3.new(S.X1 + 8, 4, w.z1 + 4)):ExpandToGrid(4)
		workspace.Terrain:ReplaceMaterial(r, 4, Mat.Grass, Mat.Ground)
		workspace.Terrain:ReplaceMaterial(r, 4, Mat.LeafyGrass, Mat.Ground)
	end
	each("Lots", function(p)
		if p.Material == Mat.Pavement or p.Name == "Apron" then
			skin(p, "paver", p.Color:Lerp(rgb(255, 240, 214), 0.5))
		elseif p.Material == Mat.LeafyGrass then
			skin(p, "leaf", rgb(128, 204, 104))
		end
	end)
	-- the median: stone kerbs round a planted strip with short palms, open at the crossings
	local road = CITY.Road
	for x = S.X0 + 30, S.X1 - 70, 40 do
		local cx = x + 18
		if not nearCross(cx, 34) then
			skin(P(road, "Median", Vector3.new(36, 0.9, 2.7), Vector3.new(cx, 0.45, S.CENTRE_LINE), rgb(232, 222, 204)), "stone")
			skin(P(road, "MedianBed", Vector3.new(34.6, 0.3, 1.5), Vector3.new(cx, 0.86, S.CENTRE_LINE), rgb(120, 200, 100)), "leaf")
			prop(CITY.Props, "PalmS", Vector3.new(cx, 0.9, S.CENTRE_LINE), rng:NextNumber(0, 360), nil, rng:NextNumber(0.85, 1.1))
		end
	end
	-- palms and flame trees up the hills behind the hotels
	local back = folder(CITY, "Backdrop")
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	local kinds = { "TreeA", "TreeB", "TreeC", "TreeA" }
	for n = 1, 90 do
		local x, z = rng:NextNumber(S.X0 - 100, S.X1 + 100), rng:NextNumber(-470, -190)
		local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -600, 0), rp)
		if hit then
			local t = PROPS:FindFirstChild(kinds[rng:NextInteger(1, #kinds)])
			if t then
				local m = t:Clone()
				m:ScaleTo(rng:NextNumber(1.5, 2.4))
				m:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanQuery = false p.CastShadow = false end
				end
				m.Parent = back
			end
		end
	end
end

