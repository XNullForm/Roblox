-- StarterPlayerScripts.RAH_Lighting: the look of the world, every frame (round 9).
-- ClockTime comes from RAH.Clock (server time), so the sun moves smoothly. The sky, ambient light,
-- fog, colour grade, bloom and sun rays blend between hand-tuned KEYS (night, sunrise, morning,
-- noon, golden hour, sunset, dusk). While the camera is inside a hotel, an INDOOR profile is eased in
-- on top (and eased back out as you leave). Anything tagged RAH_NightLight turns on at night:
-- its Light descendants enable and parts with attribute LitColor glow Neon.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Clock = require(RAH:WaitForChild("Clock"))
local camera = workspace.CurrentCamera

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- one entry per time of day; every field is blended between the two keys around the clock
local KEYS = {
	{ t = 0, -- deep night
		amb = rgb(46, 52, 84), out = rgb(70, 80, 128), bright = 1.6, expo = 0.15, top = rgb(90, 110, 180), bottom = rgb(20, 24, 40),
		dens = 0.34, haze = 1.1, glare = 0, offset = 0.1, aCol = rgb(64, 76, 128), aDec = rgb(30, 36, 80),
		tint = rgb(196, 210, 255), sat = 0.05, con = 0.12, cBright = 0.0, bloom = 0.9, bSize = 28, bThr = 1.2, rays = 0, stars = 1 },
	{ t = 4.9,
		amb = rgb(46, 52, 84), out = rgb(70, 80, 128), bright = 1.6, expo = 0.15, top = rgb(90, 110, 180), bottom = rgb(20, 24, 40),
		dens = 0.34, haze = 1.1, glare = 0, offset = 0.1, aCol = rgb(64, 76, 128), aDec = rgb(30, 36, 80),
		tint = rgb(196, 210, 255), sat = 0.05, con = 0.12, cBright = 0.0, bloom = 0.9, bSize = 28, bThr = 1.2, rays = 0, stars = 1 },
	{ t = 6.1, -- sunrise
		amb = rgb(112, 92, 112), out = rgb(160, 126, 136), bright = 2.1, expo = 0.12, top = rgb(255, 176, 128), bottom = rgb(60, 40, 60),
		dens = 0.33, haze = 1.7, glare = 0.7, offset = 0.15, aCol = rgb(255, 196, 166), aDec = rgb(170, 112, 140),
		tint = rgb(255, 230, 212), sat = 0.12, con = 0.08, cBright = 0.01, bloom = 0.7, bSize = 26, bThr = 1.4, rays = 0.14, stars = 0.2 },
	{ t = 8.2, -- morning
		amb = rgb(106, 104, 120), out = rgb(140, 142, 158), bright = 2.7, expo = 0.0, top = rgb(255, 242, 222), bottom = rgb(40, 40, 50),
		dens = 0.27, haze = 0.9, glare = 0.25, offset = 0.2, aCol = rgb(206, 222, 242), aDec = rgb(130, 152, 192),
		tint = rgb(255, 250, 244), sat = 0.16, con = 0.06, cBright = 0.0, bloom = 0.42, bSize = 24, bThr = 1.6, rays = 0.06, stars = 0 },
	{ t = 13, -- noon
		amb = rgb(104, 104, 116), out = rgb(132, 134, 148), bright = 3.0, expo = -0.05, top = rgb(255, 250, 240), bottom = rgb(40, 40, 46),
		dens = 0.25, haze = 0.5, glare = 0.15, offset = 0.22, aCol = rgb(210, 226, 246), aDec = rgb(120, 150, 196),
		tint = rgb(255, 252, 248), sat = 0.14, con = 0.06, cBright = 0.0, bloom = 0.35, bSize = 24, bThr = 1.7, rays = 0.04, stars = 0 },
	{ t = 16.6, -- golden hour
		amb = rgb(112, 98, 98), out = rgb(152, 132, 122), bright = 2.6, expo = 0.02, top = rgb(255, 212, 162), bottom = rgb(50, 40, 40),
		dens = 0.29, haze = 1.2, glare = 0.5, offset = 0.2, aCol = rgb(255, 218, 178), aDec = rgb(190, 142, 122),
		tint = rgb(255, 238, 216), sat = 0.2, con = 0.07, cBright = 0.0, bloom = 0.5, bSize = 25, bThr = 1.5, rays = 0.1, stars = 0 },
	{ t = 18.6, -- sunset
		amb = rgb(104, 80, 100), out = rgb(156, 108, 118), bright = 1.9, expo = 0.1, top = rgb(255, 142, 104), bottom = rgb(60, 36, 50),
		dens = 0.33, haze = 2.0, glare = 0.9, offset = 0.15, aCol = rgb(255, 172, 150), aDec = rgb(150, 90, 132),
		tint = rgb(255, 218, 206), sat = 0.2, con = 0.08, cBright = 0.01, bloom = 0.75, bSize = 27, bThr = 1.35, rays = 0.16, stars = 0 },
	{ t = 19.7, -- dusk
		amb = rgb(64, 62, 98), out = rgb(86, 86, 134), bright = 1.4, expo = 0.1, top = rgb(126, 116, 196), bottom = rgb(30, 26, 50),
		dens = 0.35, haze = 1.6, glare = 0.2, offset = 0.12, aCol = rgb(124, 122, 192), aDec = rgb(72, 62, 124),
		tint = rgb(208, 208, 255), sat = 0.1, con = 0.1, cBright = 0.0, bloom = 0.85, bSize = 28, bThr = 1.25, rays = 0, stars = 0.7 },
	{ t = 20.8,
		amb = rgb(46, 52, 84), out = rgb(70, 80, 128), bright = 1.6, expo = 0.15, top = rgb(90, 110, 180), bottom = rgb(20, 24, 40),
		dens = 0.34, haze = 1.1, glare = 0, offset = 0.1, aCol = rgb(64, 76, 128), aDec = rgb(30, 36, 80),
		tint = rgb(196, 210, 255), sat = 0.05, con = 0.12, cBright = 0.0, bloom = 0.9, bSize = 28, bThr = 1.2, rays = 0, stars = 1 },
}
table.insert(KEYS, (function()
	local k = table.clone(KEYS[1])
	k.t = 24
	return k
end)())

-- indoors: no outdoor fog, gentler exposure and bloom, a warm lobby grade (blended by `inside`)
local INDOOR = { dens = 0.02, haze = 0, glare = 0, expo = -0.12, bloom = 0.25, bThr = 1.9, rays = 0,
	tint = rgb(255, 244, 232), sat = 0.12, con = 0.05 }

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
	if e:IsA("PostEffect") and e ~= grade and e ~= bloom and e ~= rays and e:GetAttribute("RAH_Keep") ~= true then
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
sky.MoonAngularSize = 9
sky.StarCount = 0

---------------------------------------------------------------- indoors

local inside = 0 -- 0 outdoors .. 1 indoors, eased
local function cameraIndoors()
	local p = camera.CFrame.Position
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return false end
	for _, h in ipairs(plots:GetChildren()) do
		local o = h:GetAttribute("Origin")
		if o then
			local x0 = o.X + (h:GetAttribute("MinX") or -40) - 1
			local x1 = o.X + (h:GetAttribute("MaxX") or 40) + 1
			local roofY = h:GetAttribute("RoofY") or 18
			if p.X > x0 and p.X < x1 and p.Z > o.Z - 31 and p.Z < o.Z + 30.5 and p.Y < roofY and p.Y > -2
				and h:GetAttribute("RAH_RoofHidden") ~= true then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------- night lights

local lit = nil
local function setNightLight(m, on)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Light") then
			-- RAH_Perf switches far lights off (Culled); it puts this back when they're in range again
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
CollectionService:GetInstanceAddedSignal("RAH_NightLight"):Connect(function(m)
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
	for _, m in ipairs(CollectionService:GetTagged("RAH_NightLight")) do
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

---------------------------------------------------------------- weather (round 10c: RAH_Weather)
-- each weather leans the day's look: darker, hazier, greyer, no sun rays. Eased so a change rolls in.
local WX = {
	clear = { dark = 0, dens = 0, haze = 0, sat = 0, rays = 1, tint = 0 },
	cloudy = { dark = 0.16, dens = 0.06, haze = 0.8, sat = -0.06, rays = 0.35, tint = 0.15 },
	fog = { dark = 0.1, dens = 0.24, haze = 2.4, sat = -0.14, rays = 0, tint = 0.3 },
	rain = { dark = 0.34, dens = 0.16, haze = 2, sat = -0.16, rays = 0, tint = 0.45 },
	storm = { dark = 0.52, dens = 0.22, haze = 2.4, sat = -0.24, rays = 0, tint = 0.6 },
	snow = { dark = 0.12, dens = 0.2, haze = 2.2, sat = -0.2, rays = 0.1, tint = 0.4 },
}
local WET_TINT = rgb(196, 210, 232)
local wx = table.clone(WX.clear)
local flash = 0
local buildK = 0
RAH:GetAttributeChangedSignal("Lightning"):Connect(function()
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
		indoorTarget = cameraIndoors() and 1 or 0
		local want = lightsOn(t)
		if want ~= lit then switchAll(want) end
	end
	inside += (indoorTarget - inside) * math.min(1, dt * 3.2)
	if math.abs(indoorTarget - inside) < 0.002 then inside = indoorTarget end

	local k = sample(t)
	local i = inside
	local goal = WX[RAH:GetAttribute("Weather") or "clear"] or WX.clear
	local e = math.min(1, dt * 0.35)
	for key, v in pairs(goal) do wx[key] += (v - wx[key]) * e end
	flash = math.max(0, flash - dt * 2.6)
	local o = 1 - i -- weather is mostly an outdoor thing
	-- build mode looks down from high up through a lot of air: thin the weather so the hotel stays readable
	buildK += ((game:GetService("Players").LocalPlayer:GetAttribute("RAH_Building") and 1 or 0) - buildK) * math.min(1, dt * 2.5)
	o *= 1 - 0.7 * buildK
	Lighting.Ambient = k.amb
	Lighting.OutdoorAmbient = k.out
	Lighting.Brightness = k.bright * (1 - wx.dark * 0.8)
	Lighting.ColorShift_Top = k.top
	Lighting.ColorShift_Bottom = k.bottom
	Lighting.ExposureCompensation = lerp(k.expo, INDOOR.expo + k.expo * 0.5, i) - wx.dark * 0.55 * o + flash * 1.4 * o
	atmos.Density = lerp(k.dens, INDOOR.dens, i) + wx.dens * o
	atmos.Haze = lerp(k.haze, INDOOR.haze, i) + wx.haze * o
	atmos.Glare = lerp(k.glare, INDOOR.glare, i)
	atmos.Offset = k.offset
	atmos.Color = k.aCol
	atmos.Decay = k.aDec
	grade.Enabled = true
	grade.TintColor = k.tint:Lerp(WET_TINT, wx.tint * 0.5 * o):Lerp(INDOOR.tint, i * 0.7)
	grade.Saturation = lerp(k.sat, INDOOR.sat, i) + wx.sat * (0.4 + 0.6 * o)
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
