-- StarterPlayerScripts.Lighting: the look of the world, every frame (round 9).
-- ClockTime comes from Shared.Clock (server time), so the sun moves smoothly. The sky, ambient light,
-- fog, colour grade, bloom and sun rays blend between hand-tuned KEYS (night, sunrise, morning,
-- noon, golden hour, sunset, dusk). While the camera is inside a hotel, an INDOOR profile is eased in
-- on top (and eased back out as you leave). Anything tagged NightLight turns on at night:
-- its Light descendants enable and parts with attribute LitColor glow Neon.
-- Round 41: remade. Nights are a readable moonlit blue instead of near-black, and the hotel has its own warm
-- interior light (its own ambient and brightness, whatever the hour), eased in when the camera is inside it and
-- partly when it looks down on it with the roof hidden, so the lobby and rooms are never dark at night.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Clock = require(Shared:WaitForChild("Clock"))
local camera = workspace.CurrentCamera

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- one entry per time of day; every field is blended between the two keys around the clock
local NIGHT = {
	amb = rgb(72, 80, 118), out = rgb(86, 100, 150), bright = 1.15, expo = -0.04, top = rgb(120, 140, 210), bottom = rgb(30, 34, 56),
	dens = 0.3, haze = 0.9, glare = 0, offset = 0.1, aCol = rgb(80, 94, 150), aDec = rgb(40, 48, 96),
	tint = rgb(214, 224, 255), sat = 0.04, con = 0.08, cBright = 0.01, bloom = 0.55, bSize = 24, bThr = 1.35, rays = 0, stars = 1,
}
local function night(t)
	local k = table.clone(NIGHT)
	k.t = t
	return k
end
local KEYS = {
	night(0),
	night(4.9),
	{ t = 6.1, -- sunrise
		amb = rgb(124, 106, 126), out = rgb(168, 138, 150), bright = 2.2, expo = 0.1, top = rgb(255, 182, 136), bottom = rgb(64, 46, 66),
		dens = 0.3, haze = 1.5, glare = 0.6, offset = 0.15, aCol = rgb(255, 200, 172), aDec = rgb(170, 116, 144),
		tint = rgb(255, 234, 218), sat = 0.12, con = 0.06, cBright = 0.01, bloom = 0.65, bSize = 26, bThr = 1.4, rays = 0.12, stars = 0.2 },
	{ t = 8.2, -- morning
		amb = rgb(118, 118, 132), out = rgb(148, 150, 166), bright = 2.8, expo = 0.02, top = rgb(255, 244, 226), bottom = rgb(44, 44, 54),
		dens = 0.25, haze = 0.8, glare = 0.25, offset = 0.2, aCol = rgb(206, 222, 242), aDec = rgb(130, 152, 192),
		tint = rgb(255, 251, 246), sat = 0.16, con = 0.05, cBright = 0.0, bloom = 0.4, bSize = 24, bThr = 1.6, rays = 0.06, stars = 0 },
	{ t = 13, -- noon
		amb = rgb(116, 116, 128), out = rgb(140, 142, 156), bright = 3.0, expo = -0.03, top = rgb(255, 250, 240), bottom = rgb(44, 44, 50),
		dens = 0.23, haze = 0.45, glare = 0.15, offset = 0.22, aCol = rgb(210, 226, 246), aDec = rgb(120, 150, 196),
		tint = rgb(255, 252, 248), sat = 0.14, con = 0.05, cBright = 0.0, bloom = 0.32, bSize = 24, bThr = 1.7, rays = 0.04, stars = 0 },
	{ t = 16.6, -- golden hour
		amb = rgb(124, 108, 106), out = rgb(160, 140, 128), bright = 2.6, expo = 0.04, top = rgb(255, 214, 166), bottom = rgb(54, 44, 44),
		dens = 0.27, haze = 1.1, glare = 0.45, offset = 0.2, aCol = rgb(255, 218, 178), aDec = rgb(190, 142, 122),
		tint = rgb(255, 240, 220), sat = 0.18, con = 0.06, cBright = 0.0, bloom = 0.48, bSize = 25, bThr = 1.5, rays = 0.1, stars = 0 },
	{ t = 18.6, -- sunset
		amb = rgb(116, 94, 112), out = rgb(160, 116, 126), bright = 2.0, expo = 0.08, top = rgb(255, 150, 112), bottom = rgb(62, 40, 54),
		dens = 0.3, haze = 1.7, glare = 0.8, offset = 0.15, aCol = rgb(255, 176, 152), aDec = rgb(150, 92, 134),
		tint = rgb(255, 222, 210), sat = 0.18, con = 0.07, cBright = 0.01, bloom = 0.7, bSize = 27, bThr = 1.35, rays = 0.14, stars = 0 },
	{ t = 19.7, -- dusk
		amb = rgb(86, 86, 124), out = rgb(102, 104, 152), bright = 1.45, expo = 0.0, top = rgb(140, 132, 210), bottom = rgb(36, 32, 58),
		dens = 0.32, haze = 1.3, glare = 0.2, offset = 0.12, aCol = rgb(130, 128, 196), aDec = rgb(76, 66, 128),
		tint = rgb(214, 214, 255), sat = 0.08, con = 0.08, cBright = 0.01, bloom = 0.65, bSize = 26, bThr = 1.3, rays = 0, stars = 0.7 },
	night(20.8),
	night(24),
}

-- indoors: no outdoor fog, gentle bloom, a warm lobby grade, and its own warm light (blended by `inside`)
local INDOOR = { dens = 0.02, haze = 0, glare = 0, expo = 0.06, bloom = 0.28, bThr = 1.8, rays = 0,
	tint = rgb(255, 242, 226), sat = 0.12, con = 0.04,
	amb = rgb(158, 146, 132), out = rgb(170, 160, 148), bright = 2.2 }

local function lerp(a, b, n) return a + (b - a) * n end
local function mix(a, b, n)
	if typeof(a) == "Color3" then return a:Lerp(b, n) end
	return lerp(a, b, n)
end

local function sample(t)
	local a, b = KEYS[1], KEYS[2]
	for i = 1, #KEYS - 1 do
		if t >= KEYS[i].t and t <= KEYS[i + 1].t then
			a, b = KEYS[i], KEYS[i + 1]
			break
		end
	end
	local n = (t - a.t) / math.max(b.t - a.t, 1e-3)
	n = n * n * (3 - 2 * n) -- smoothstep: no visible kinks at the keys
	local out = {}
	for k, v in pairs(a) do
		if k ~= "t" then out[k] = mix(v, b[k], n) end
	end
	return out
end

---------------------------------------------------------------- effects (made if missing)

local function get(cls, name)
	local e = Lighting:FindFirstChild(name)
	if not e or not e:IsA(cls) then
		e = Instance.new(cls)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end
local atmos = get("Atmosphere", "Atmosphere")
local grade = get("ColorCorrectionEffect", "Grade")
local bloom = get("BloomEffect", "Bloom")
local rays = get("SunRaysEffect", "SunRays")
local sky = Lighting:FindFirstChildOfClass("Sky") or get("Sky", "Sky")
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then dof.Enabled = false end
-- leftovers from older lighting scripts must never stick on screen
for _, e in ipairs(Lighting:GetChildren()) do
	if e:IsA("PostEffect") and e ~= grade and e ~= bloom and e ~= rays and e:GetAttribute("Keep") ~= true then
		if e:IsA("BlurEffect") or e:IsA("ColorCorrectionEffect") then e.Enabled = false end
	end
end
Lighting.GeographicLatitude = 28
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.ShadowSoftness = 0.2
Lighting.GlobalShadows = true
sky.CelestialBodiesShown = true
sky.SunAngularSize = 14
sky.MoonAngularSize = 11
sky.StarCount = 0

---------------------------------------------------------------- indoors

local inside = 0 -- 0 outdoors .. 1 indoors, eased
-- 1 with the camera inside a hotel, 0.6 looking down on one with its roof hidden, else 0
local function cameraIndoors()
	local p = camera.CFrame.Position
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return 0 end
	for _, h in ipairs(plots:GetChildren()) do
		local o = h:GetAttribute("Origin")
		if o then
			local x0 = o.X + (h:GetAttribute("MinX") or -40) - 1
			local x1 = o.X + (h:GetAttribute("MaxX") or 40) + 1
			local roofY = h:GetAttribute("RoofY") or 18
			if p.X > x0 and p.X < x1 and p.Z > o.Z - 31 and p.Z < o.Z + 30.5 and p.Y > -2 then
				if h:GetAttribute("RoofHidden") == true then
					if p.Y < roofY + 80 then return 0.6 end
				elseif p.Y < roofY then
					return 1
				end
			end
		end
	end
	return 0
end

---------------------------------------------------------------- night lights

local lit = nil
local function setNightLight(m, on)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Light") then
			-- Perf switches far lights off (Culled); it puts this back when they're in range again
			d:SetAttribute("NightOn", on)
			d.Enabled = on and not d:GetAttribute("Culled")
		elseif d:IsA("BasePart") and d:GetAttribute("LitColor") then
			if d:GetAttribute("OffColor") == nil then
				d:SetAttribute("OffColor", d.Color)
				d:SetAttribute("OffMat", d.Material.Name)
			end
			d.Color = on and d:GetAttribute("LitColor") or d:GetAttribute("OffColor")
			d.Material = on and Enum.Material.Neon or Enum.Material[d:GetAttribute("OffMat")]
		end
	end
end
CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(m)
	if lit ~= nil then setNightLight(m, lit) end
end)
local function lightsOn(t)
	-- lamps come on a little before night and go off a little after dawn; staggered per lamp
	return t >= C.NIGHT_FROM - 1.2 or t < C.NIGHT_TO + 0.4
end
local staggerQueue = {}
local function switchAll(on)
	lit = on
	table.clear(staggerQueue)
	for _, m in ipairs(CollectionService:GetTagged("NightLight")) do
		table.insert(staggerQueue, m)
	end
	-- shuffle so the street flickers on lamp by lamp
	for i = #staggerQueue, 2, -1 do
		local j = math.random(i)
		staggerQueue[i], staggerQueue[j] = staggerQueue[j], staggerQueue[i]
	end
	task.spawn(function()
		local want = on
		local n = 0
		while #staggerQueue > 0 and lit == want do
			setNightLight(table.remove(staggerQueue), want)
			n += 1
			if n % 6 == 0 then task.wait(0.03) end
		end
	end)
end

---------------------------------------------------------------- weather (round 10c: Weather)
-- each weather leans the day's look: darker, hazier, greyer, no sun rays. Eased so a change rolls in.
local WX = {
	clear = { dark = 0, dens = 0, haze = 0, sat = 0, rays = 1, tint = 0 },
	cloudy = { dark = 0.14, dens = 0.05, haze = 0.7, sat = -0.06, rays = 0.35, tint = 0.15 },
	fog = { dark = 0.08, dens = 0.22, haze = 2.2, sat = -0.12, rays = 0, tint = 0.3 },
	rain = { dark = 0.28, dens = 0.14, haze = 1.8, sat = -0.14, rays = 0, tint = 0.45 },
	storm = { dark = 0.42, dens = 0.2, haze = 2.2, sat = -0.2, rays = 0, tint = 0.6 },
	snow = { dark = 0.1, dens = 0.18, haze = 2, sat = -0.18, rays = 0.1, tint = 0.4 },
}
local WET_TINT = rgb(196, 210, 232)
local wx = table.clone(WX.clear)
local flash = 0
local buildK = 0

---------------------------------------------------------------- seasons (round 19)
-- each season leans the whole look on top of the time-of-day keys: spring fresh, summer
-- golden, autumn amber, winter cool. Eased in over a few seconds when the season turns.
local SEASON = {
	Spring = { tint = rgb(230, 246, 224), sat = 0.05, bright = 1.03, dens = 0.01, expo = 0.02, mix = 0.22 },
	Summer = { tint = rgb(255, 243, 212), sat = 0.03, bright = 1.1, dens = -0.01, expo = 0.04, mix = 0.25 },
	Autumn = { tint = rgb(255, 230, 198), sat = -0.02, bright = 0.96, dens = 0.03, expo = 0, mix = 0.28 },
	Winter = { tint = rgb(220, 233, 255), sat = -0.08, bright = 0.92, dens = 0.05, expo = -0.02, mix = 0.3 },
}
local sn = { tint = rgb(255, 255, 255), sat = 0, bright = 1, dens = 0, expo = 0, mix = 0 }

-- the city's hedges: the one bit of foliage that changes with the seasons
local HEDGE = {
	Spring = rgb(118, 172, 88), Summer = rgb(80, 146, 62), Autumn = rgb(184, 130, 56), Winter = rgb(172, 188, 176),
}
local hedges = {}
do
	local lots = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Lots")
	if lots then
		for _, d in ipairs(lots:GetDescendants()) do
			if d:IsA("BasePart") and d.Material == Enum.Material.LeafyGrass then
				table.insert(hedges, { part = d, base = d.Color })
			end
		end
	end
end
local hedgeGoal = nil
Shared:GetAttributeChangedSignal("Lightning"):Connect(function()
	-- a double flicker
	flash = 0.55
	task.delay(0.12, function() flash = 0.1 end)
	task.delay(0.2, function() flash = 0.75 end)
end)

---------------------------------------------------------------- every frame

local lastCheck = 0
local indoorTarget = 0
RunService.RenderStepped:Connect(function(dt)
	local t = Clock.now()
	Lighting.ClockTime = t

	local now = os.clock()
	if now - lastCheck > 0.15 then
		lastCheck = now
		indoorTarget = cameraIndoors()
		local want = lightsOn(t)
		if want ~= lit then switchAll(want) end
		-- hedge colour follows the season, eased in over a few checks
		if #hedges > 0 then
			hedgeGoal = HEDGE[Clock.date(Shared:GetAttribute("Day") or 1).seasonName] or HEDGE.Spring
			for _, h in ipairs(hedges) do
				local c = h.part.Color
				if (c - hedgeGoal).Magnitude > 0.004 then
					h.part.Color = c:Lerp(hedgeGoal, 0.25)
				end
			end
		end
	end
	inside += (indoorTarget - inside) * math.min(1, dt * 3.2)
	if math.abs(indoorTarget - inside) < 0.002 then inside = indoorTarget end

	local k = sample(t)
	local i = inside
	local goal = WX[Shared:GetAttribute("Weather") or "clear"] or WX.clear
	local e = math.min(1, dt * 0.35)
	for key, v in pairs(goal) do wx[key] += (v - wx[key]) * e end
	local sGoal = SEASON[Clock.date(Shared:GetAttribute("Day") or 1).seasonName] or SEASON.Spring
	for key, v in pairs(sGoal) do
		local c = sn[key]
		if typeof(v) == "Color3" then sn[key] = (typeof(c) == "Color3" and c or v):Lerp(v, e)
		elseif type(c) == "number" then sn[key] = c + (v - c) * e
		else sn[key] = v end
	end
	flash = math.max(0, flash - dt * 2.6)
	local o = 1 - i -- weather is mostly an outdoor thing
	-- build mode looks down from high up through a lot of air: thin the weather so the hotel stays readable
	buildK += ((game:GetService("Players").LocalPlayer:GetAttribute("Building") and 1 or 0) - buildK) * math.min(1, dt * 2.5)
	o *= 1 - 0.7 * buildK
	-- round 32: build mode at night lifts the light so you can still see what you place
	local bn = buildK * k.stars
	-- round 41: the hotel's own warm light (only ever lifts: a bright noon lobby isn't dimmed to it)
	local amb = k.amb:Lerp(INDOOR.amb, i * 0.8):Lerp(rgb(140, 140, 152), bn * 0.6)
	local outA = k.out:Lerp(INDOOR.out, i * 0.7):Lerp(rgb(158, 160, 174), bn * 0.6)
	Lighting.Ambient = amb
	Lighting.OutdoorAmbient = outA
	local kb = k.bright * (1 - wx.dark * 0.8 * o) * sn.bright
	Lighting.Brightness = lerp(kb, math.max(kb, INDOOR.bright), i) + bn * 1.0
	Lighting.ColorShift_Top = k.top
	Lighting.ColorShift_Bottom = k.bottom
	Lighting.ExposureCompensation = lerp(k.expo, INDOOR.expo, i) - wx.dark * 0.45 * o + flash * 1.4 * o + sn.expo + bn * 0.25
	atmos.Density = lerp(k.dens, INDOOR.dens, i) + wx.dens * o + sn.dens * (1 - i * 0.5)
	atmos.Haze = lerp(k.haze, INDOOR.haze, i) + wx.haze * o
	atmos.Glare = lerp(k.glare, INDOOR.glare, i)
	atmos.Offset = k.offset
	atmos.Color = k.aCol
	atmos.Decay = k.aDec
	grade.Enabled = true
	grade.TintColor = k.tint:Lerp(WET_TINT, wx.tint * 0.5 * o):Lerp(INDOOR.tint, i * 0.7):Lerp(sn.tint, sn.mix * (1 - i * 0.6))
	grade.Saturation = lerp(k.sat, INDOOR.sat, i) + wx.sat * (0.4 + 0.6 * o) + sn.sat
	grade.Contrast = lerp(k.con, INDOOR.con, i)
	grade.Brightness = k.cBright + flash * 0.25
	bloom.Enabled = true
	bloom.Intensity = lerp(k.bloom, INDOOR.bloom, i)
	bloom.Size = k.bSize
	bloom.Threshold = lerp(k.bThr, INDOOR.bThr, i)
	rays.Intensity = lerp(k.rays * wx.rays, 0, i)
	rays.Spread = 0.6
	sky.StarCount = math.floor(3000 * k.stars)
end)
