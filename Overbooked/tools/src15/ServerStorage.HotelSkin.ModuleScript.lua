-- ServerStorage.HotelSkin (round 20, 2026-11-11): how a hotel looks for its look stage (Shared.Upgrades.look):
--   0 run-down (grey cracked walls, boarded windows, weeds, rubbish)   1 patched up   2 fresh white resort
--   3 charming (flower urns and palms by the door)   4 grand (lamps and a red carpet too)
-- HotelBuilder still builds its old brick-and-emerald hotel; this pass re-dresses every part of the Shell, Roof,
-- Doors, Lobby and Rooms by what KIND of surface it is (found once, kept in the part's attribute SK), so a hotel
-- can be re-dressed for any stage at any time. Furniture (Placed) and people are never touched.
-- apply(root, stage) dresses what is there; watch(hotel) keeps a live hotel right: new parts (wings, new floors)
-- and stage changes (its Upgrades or Grade attribute). The door-side props live in <hotel>.LookDecor.
local Skin = {}
local rgb = Color3.fromRGB
local Mat = Enum.Material
local U = require(game.ReplicatedStorage.Shared:WaitForChild("Upgrades"))

local function key(c)
	return string.format("%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- colour -> { kind, brightness }: the builder's colours, and the ones the first resort pass left behind
local KEYS = {
	["24,84,64"] = { "teal", 1 }, ["36,82,68"] = { "teal", 0.9 }, ["26,64,52"] = { "teal", 0.7 }, ["30,56,48"] = { "teal", 0.62 },
	["16,142,152"] = { "teal", 1 }, ["22,128,140"] = { "teal", 0.9 }, ["14,98,110"] = { "teal", 0.7 }, ["18,88,100"] = { "teal", 0.62 },
	["78,50,34"] = { "wood", 1 }, ["116,72,44"] = { "wood", 1.14 }, ["150,108,74"] = { "wood", 1 }, ["170,122,82"] = { "wood", 1.14 },
	["96,98,104"] = { "roof", 1 }, ["196,104,72"] = { "roof", 1 },
	["70,74,80"] = { "flat", 1 }, ["206,196,180"] = { "flat", 1 },
	["226,220,210"] = { "plinth", 1 }, ["250,244,232"] = { "plinth", 1 },
	["244,236,216"] = { "keep", 1 }, ["244,236,218"] = { "keep", 1 }, ["226,228,216"] = { "keep", 1 }, ["236,226,204"] = { "keep", 1 },
	["248,236,212"] = { "keep", 1 }, ["250,246,236"] = { "keep", 1 }, ["218,178,98"] = { "keep", 1 }, ["176,204,214"] = { "keep", 1 },
}
local TILE_NAMES = { Coping = true, Cornice = true, Course = true }
local SKIP = { Placed = true, Guests = true, Nav = true, BuildZones = true, Mess = true, CleanSpots = true, LookDecor = true }

-- per stage: kind -> { material, variant, colour }. "keep" parts hold their own colour, dulled by `grime`.
local LOOKS = {
	[0] = { brick = { Mat.Concrete, "", rgb(166, 158, 140) }, stone = { Mat.Concrete, "", rgb(138, 132, 120) }, tile = { Mat.Slate, "", rgb(104, 84, 74) },
		teal = rgb(92, 104, 98), wood = rgb(96, 88, 80), roof = rgb(108, 98, 92), flat = rgb(120, 116, 108), plinth = rgb(150, 144, 132), grime = 0.42 },
	[1] = { brick = { Mat.Plaster, "", rgb(222, 212, 190) }, stone = { Mat.Limestone, "R16_Stone", rgb(212, 202, 184) }, tile = { Mat.Slate, "", rgb(150, 100, 80) },
		teal = rgb(58, 126, 126), wood = rgb(128, 100, 76), roof = rgb(156, 104, 84), flat = rgb(168, 160, 148), plinth = rgb(214, 206, 190), grime = 0.16 },
	[2] = { brick = { Mat.Plaster, "R16_Stucco", rgb(254, 250, 242) }, stone = { Mat.Limestone, "R16_Stone", rgb(248, 240, 222) }, tile = { Mat.ClayRoofTiles, "", rgb(208, 110, 74) },
		teal = rgb(16, 142, 152), wood = rgb(150, 108, 74), roof = rgb(196, 104, 72), flat = rgb(206, 196, 180), plinth = rgb(250, 244, 232), grime = 0 },
}
LOOKS[3] = LOOKS[2]
LOOKS[4] = { brick = { Mat.Plaster, "R16_Stucco", rgb(255, 253, 248) }, stone = { Mat.Marble, "", rgb(250, 246, 238) }, tile = { Mat.ClayRoofTiles, "", rgb(198, 94, 62) },
	teal = rgb(10, 112, 128), wood = rgb(160, 112, 72), roof = rgb(198, 94, 62), flat = rgb(214, 204, 188), plinth = rgb(252, 248, 240), grime = 0 }
local GRIME = rgb(120, 110, 90)

-- round 22: the finishes the owner picks (Shared.Upgrades.STYLES; hotel attribute Style). Floors and walls are
-- found by part name, the roof by its tile / roof kind.
local FLOOR = {
	stone = { Mat.Limestone, "R16_Stone", rgb(238, 228, 208) }, oak = { Mat.WoodPlanks, "", rgb(204, 160, 110) },
	walnut = { Mat.WoodPlanks, "", rgb(124, 88, 62) }, marble = { Mat.Marble, "Checker", rgb(255, 255, 255) },
	terracotta = { Mat.Pavement, "R16_Paver", rgb(224, 140, 102) }, concrete = { Mat.Concrete, "", rgb(178, 180, 184) },
	carpet = { Mat.Fabric, "", rgb(66, 112, 124) },
}
local WALLC = {
	white = rgb(250, 246, 238), sand = rgb(238, 224, 198), sage = rgb(208, 222, 206), sky = rgb(208, 226, 240),
	blush = rgb(242, 216, 208), charcoal = rgb(78, 82, 92),
}
local ROOFC = {
	terracotta = { Mat.ClayRoofTiles, rgb(208, 110, 74) }, slate = { Mat.Slate, rgb(84, 92, 104) },
	white = { Mat.Concrete, rgb(238, 236, 230) }, copper = { Mat.Metal, rgb(72, 146, 124) },
}
local WALL_NAMES = { Paper = true, PierIn = true, HeaderIn = true }
local styleOf = setmetatable({}, { __mode = "k" }) -- hotel -> its style table (refreshed with the look)

local function skipped(p, root)
	local a = p.Parent
	while a and a ~= root do
		if SKIP[a.Name] then return true end
		a = a.Parent
	end
	return false
end

-- what kind of surface a part is (worked out once)
local function kindOf(p)
	local k = p:GetAttribute("SK3")
	if k then return k ~= "-" and k or nil end
	local mv = p.MaterialVariant
	local n = p.Name
	if n == "LobbyFloor" then
		k = "s_lobby"
	elseif n == "Floor" and p.Parent and p.Parent.Parent and p.Parent.Parent.Name == "Rooms" then
		k = "s_rooms"
	elseif WALL_NAMES[n] or (n == "Core" and p.Material == Mat.Plaster) then
		k = "s_wall"
	elseif mv == "Brick" or mv == "R16_Stucco" then
		k = "brick"
	elseif p.Material == Mat.ClayRoofTiles then
		k = "tile"
	elseif p.Material == Mat.Limestone and (mv == "" or mv == "R16_Stone") then
		k = TILE_NAMES[p.Name] and "tile" or "stone"
	else
		local e = KEYS[key(p.Color)]
		if e then
			k = e[1]
			p:SetAttribute("SF", e[2])
			if k == "keep" then p:SetAttribute("SC", p.Color) end
		end
	end
	p:SetAttribute("SK3", k or "-")
	return k
end

function Skin.dress(p, stage, style)
	local k = kindOf(p)
	if not k then return end
	local L = LOOKS[stage] or LOOKS[2]
	style = style or U.STYLE_DEFAULT
	if k == "s_lobby" or k == "s_rooms" then
		local v = FLOOR[k == "s_lobby" and style.lobby or style.rooms] or FLOOR.stone
		p.Material, p.MaterialVariant, p.Color = v[1], v[2], v[3]:Lerp(GRIME, L.grime)
		return
	elseif k == "s_wall" then
		p.Material, p.MaterialVariant = Mat.Plaster, ""
		p.Color = (WALLC[style.walls] or WALLC.white):Lerp(GRIME, L.grime)
		return
	elseif (k == "tile" or k == "roof") and stage >= 2 then
		local r = ROOFC[style.roof] or ROOFC.terracotta
		p.Material, p.MaterialVariant, p.Color = r[1], "", r[2]
		return
	end
	if k == "keep" then
		local c = p:GetAttribute("SC")
		if c then p.Color = c:Lerp(GRIME, L.grime) end
		return
	end
	local v = L[k]
	if typeof(v) == "Color3" then
		local f = p:GetAttribute("SF") or 1
		p.Color = rgb(math.min(255, v.R * 255 * f), math.min(255, v.G * 255 * f), math.min(255, v.B * 255 * f))
	elseif v then
		p.Material = v[1]
		p.MaterialVariant = v[2]
		p.Color = v[3]
	end
end

function Skin.apply(root, stage, style)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not skipped(d, root) then Skin.dress(d, stage, style) end
	end
end

---------------------------------------------------------------- props by the door

local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = mat or Mat.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then for k, v in pairs(extra) do p[k] = v end end
	p.Parent = parent
	return p
end

local function prop(parent, name, cf, scale)
	local lib = game.ServerStorage:FindFirstChild("CityProps")
	local src = lib and lib:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	if scale then m:ScaleTo(scale) end
	m:PivotTo(cf)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true p.CanCollide = false p.CanQuery = false p.CanTouch = false end
	end
	m.Parent = parent
	return m
end

function Skin.decor(hotel, stage)
	local old = hotel:FindFirstChild("LookDecor")
	if old then old:Destroy() end
	local doors = hotel:FindFirstChild("Doors")
	if not doors or not doors:IsA("Model") then return end
	local dcf, dsz = doors:GetBoundingBox()
	local cx, y0, zf = dcf.Position.X, dcf.Position.Y - dsz.Y / 2, dcf.Position.Z
	local f = Instance.new("Folder")
	f.Name = "LookDecor"
	f.Parent = hotel
	local rng = Random.new(math.floor(cx) + 77)
	-- props stand on whatever is really under them (the path steps down from the door: a fixed height floated)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { f, hotel:FindFirstChild("Guests"), hotel:FindFirstChild("Placed") }
	local function gy(x, z)
		local hit = workspace:Raycast(Vector3.new(x, y0 + 6, z), Vector3.new(0, -16, 0), rp)
		return hit and hit.Position.Y or y0
	end
	if stage <= 1 then
		local WEED = rgb(96, 124, 70)
		for i = 1, stage == 0 and 16 or 5 do
			local x = cx + rng:NextNumber(7, 36) * (rng:NextNumber() < 0.5 and -1 or 1)
			local z = zf + rng:NextNumber(0.9, 2.6)
			local col = WEED:Lerp(rgb(150, 150, 90), rng:NextNumber(0, 0.5))
			for b = 1, rng:NextInteger(5, 8) do -- a tuft: thin blades fanned out from one root
				local h = rng:NextNumber(1.4, 3.6)
				local lean = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(rng:NextNumber(0.05, 0.5), 0, 0)
				P(f, "Weed", Vector3.new(0.34, h, 0.08), CFrame.new(x, y0 - 0.1, z) * lean * CFrame.new(0, h / 2, 0), col:Lerp(rgb(70, 110, 60), rng:NextNumber(0, 0.4)), Mat.Grass, { CastShadow = false })
			end
		end
		for i = 1, stage == 0 and 9 or 2 do -- damp stains down the front
			local x = cx + rng:NextNumber(8, 36) * (rng:NextNumber() < 0.5 and -1 or 1)
			P(f, "Stain", Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(4, 9), 0.1), Vector3.new(x, y0 + rng:NextNumber(6, 11), zf + 0.42),
				rgb(64, 58, 46), Mat.Concrete, { Transparency = rng:NextNumber(0.62, 0.8), CastShadow = false })
		end
	end
	if stage == 0 then
		local PLANK = rgb(118, 96, 72)
		for _, s in ipairs({ -1, 1 }) do
			for _, x in ipairs({ 13, 26 }) do -- boards nailed over the windows
				for j, a in ipairs({ 14, -11, 3 }) do
					P(f, "Board", Vector3.new(11.5, 1.1, 0.3), CFrame.new(cx + s * x, y0 + 3.4 + j * 1.9, zf + 0.55 + j * 0.05) * CFrame.Angles(0, 0, math.rad(a + rng:NextNumber(-4, 4))),
						PLANK:Lerp(rgb(84, 72, 60), rng:NextNumber(0, 0.6)), Mat.WoodPlanks)
				end
			end
		end
		for i = 1, 4 do -- rubbish by the door
			local r = rng:NextNumber(1.5, 2.3)
			P(f, "BinBag", Vector3.new(r, r * 0.85, r), Vector3.new(cx + 8.5 + i * 1.5, y0 + r * 0.4, zf + 2 + rng:NextNumber(0, 2)), rgb(34, 36, 40), Mat.SmoothPlastic, { Shape = Enum.PartType.Ball })
		end
		P(f, "Box", Vector3.new(2.4, 1.8, 2.2), CFrame.new(cx - 9, y0 + 0.9, zf + 2.6) * CFrame.Angles(0, 0.4, 0), rgb(172, 136, 96), Mat.Cardboard)
		P(f, "Box", Vector3.new(1.8, 1.3, 1.6), CFrame.new(cx - 8.6, y0 + 2.4, zf + 2.4) * CFrame.Angles(0, -0.3, 0.12), rgb(160, 126, 88), Mat.Cardboard)
		local note = P(f, "ClosedSign", Vector3.new(4.2, 2.6, 0.2), CFrame.new(cx - 7.4, y0 + 6, zf + 0.6) * CFrame.Angles(0, 0, math.rad(-7)), rgb(232, 222, 196), Mat.Cardboard)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(210, 130)
		sg.Parent = note
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "ROOMS\n(sort of)"
		tl.TextScaled = true
		tl.Font = Enum.Font.PermanentMarker
		tl.TextColor3 = rgb(120, 40, 34)
		tl.Parent = sg
	end
	if stage >= 3 then
		for _, s in ipairs({ -1, 1 }) do
			prop(f, "PlanterUrn", CFrame.new(cx + s * 8, gy(cx + s * 8, zf + 3), zf + 3) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
			prop(f, "PalmS", CFrame.new(cx + s * 17, gy(cx + s * 17, zf + 3.5), zf + 3.5) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 0.9)
			prop(f, "PlanterUrn", CFrame.new(cx + s * 27, gy(cx + s * 27, zf + 3), zf + 3) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 0.85)
		end
	end
	if stage >= 4 then
		-- the red carpet is laid in short lengths so it follows the path down its steps
		for k = 0, 5 do
			local z = zf + 3.5 + k * 4
			local y = gy(cx, z) + 0.06
			P(f, "Carpet", Vector3.new(8, 0.12, 4), Vector3.new(cx, y, z), rgb(152, 22, 38), Mat.Fabric)
			for _, s in ipairs({ -1, 1 }) do
				P(f, "CarpetEdge", Vector3.new(0.4, 0.14, 4), Vector3.new(cx + s * 4.1, y, z), rgb(226, 186, 100), Mat.Metal)
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			for _, z in ipairs({ 9, 22 }) do
				local ly = gy(cx + s * 7.6, zf + z)
				local l = prop(f, "GlobeLamp", CFrame.new(cx + s * 7.6, ly, zf + z), 0.6)
				if l then
					local g = P(l, "LampLight", Vector3.new(1, 1, 1), Vector3.new(cx + s * 7.6, ly + 9, zf + z), rgb(255, 232, 196), nil, { Transparency = 1 })
					local pl = Instance.new("PointLight")
					pl.Range = 18; pl.Brightness = 0.6; pl.Color = rgb(255, 232, 196); pl.Enabled = false; pl.Parent = g
					game:GetService("CollectionService"):AddTag(l, "NightLight")
				end
			end
		end
	end
end

function Skin.stage(hotel) return U.look(hotel) end

function Skin.refresh(hotel)
	local stage = U.look(hotel)
	hotel:SetAttribute("Look", stage)
	local style = U.style(hotel)
	styleOf[hotel] = style
	Skin.apply(hotel, stage, style)
	if hotel:GetAttribute("DecorStage") ~= stage or not hotel:FindFirstChild("LookDecor") then
		hotel:SetAttribute("DecorStage", stage)
		Skin.decor(hotel, stage)
	end
end

function Skin.watch(hotel)
	Skin.refresh(hotel)
	local busy = false
	local function later()
		if busy then return end
		busy = true
		task.delay(0.3, function()
			busy = false
			if hotel.Parent then Skin.refresh(hotel) end
		end)
	end
	hotel:GetAttributeChangedSignal("Upgrades"):Connect(later)
	hotel:GetAttributeChangedSignal("Grade"):Connect(later)
	hotel:GetAttributeChangedSignal("Style"):Connect(later)
	-- HotelBuilder restyles its own parts now and then (a new grade, a custom room): lay the look back over it
	task.spawn(function()
		local first = true
		while hotel.Parent do
			task.wait(first and 3 or 25)
			first = false
			if hotel.Parent then Skin.apply(hotel, hotel:GetAttribute("Look") or 2, styleOf[hotel]) end
		end
	end)
	hotel.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(function()
				if d.Parent and not skipped(d, hotel) then Skin.dress(d, hotel:GetAttribute("Look") or 2, styleOf[hotel]) end
			end)
		end
	end)
	-- the doors arrive a moment after the shell on a fresh build
	task.delay(2, function() if hotel.Parent and not hotel:FindFirstChild("LookDecor") then Skin.refresh(hotel) end end)
end

return Skin
