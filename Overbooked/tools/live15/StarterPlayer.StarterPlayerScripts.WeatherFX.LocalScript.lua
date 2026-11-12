-- StarterPlayerScripts.WeatherFX (round 10c): what the weather looks and sounds like on this client.
-- Reads Shared attributes Weather and Lightning (Weather). Rain and snow fall from a sheet that follows the
-- camera, rain splashes on the street round it, the clouds thicken, and the rain loop plays (muffled indoors);
-- a storm's lightning brings thunder a beat later. The sky itself (darker, hazier) is Lighting's job.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = RS:WaitForChild("Shared")
local Street = require(Shared:WaitForChild("Street"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TEX = { rain = "rbxassetid://121142287419380", snow = "rbxassetid://134437018607647", splash = "rbxassetid://84023424081823" }
local RAIN_LOOP = "rbxassetid://9112857054"
local THUNDER = { "rbxassetid://9120016037", "rbxassetid://9120016256", "rbxassetid://9120016241" }

-- per weather: rain and snow rates, splash rate, rain volume, cloud cover and density
local LOOK = {
	clear = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.45, dens = 0.25, wind = 0.1, mist = 0, cloud = Color3.fromRGB(255, 255, 255) },
	cloudy = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.8, dens = 0.45, wind = 0.3, mist = 0, cloud = Color3.fromRGB(214, 218, 228) },
	fog = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.9, dens = 0.5, wind = 0.1, mist = 14, cloud = Color3.fromRGB(200, 204, 212) },
	rain = { rain = 700, snow = 0, splash = 220, vol = 0.55, cover = 0.92, dens = 0.62, wind = 0.5, mist = 4, cloud = Color3.fromRGB(150, 156, 170) },
	storm = { rain = 1300, snow = 0, splash = 420, vol = 0.85, cover = 0.98, dens = 0.78, wind = 1.2, mist = 8, cloud = Color3.fromRGB(96, 100, 116) },
	snow = { rain = 0, snow = 420, splash = 0, vol = 0, cover = 0.9, dens = 0.55, wind = 0.6, mist = 3, cloud = Color3.fromRGB(226, 230, 238) },
}

---------------------------------------------------------------- the sheets

local fx = Instance.new("Folder")
fx.Name = "WeatherFX"
fx.Parent = camera

local function sheet(name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Parent = fx
	return p
end
local sky = sheet("Sky", Vector3.new(130, 1, 130))
local ground = sheet("Ground", Vector3.new(70, 0.2, 70))

local rain = Instance.new("ParticleEmitter")
rain.Name = "Rain"
rain.Texture = TEX.rain
rain.EmissionDirection = Enum.NormalId.Bottom
rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
rain.Speed = NumberRange.new(120, 140)
rain.SpreadAngle = Vector2.new(4, 4)
rain.Acceleration = Vector3.new(6, 0, 3)
rain.Lifetime = NumberRange.new(0.55, 0.7)
rain.Size = NumberSequence.new(1.1)
rain.Squash = NumberSequence.new(2.6) -- tall and thin
rain.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.62), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.65) })
rain.Color = ColorSequence.new(Color3.fromRGB(226, 234, 248))
rain.LightEmission = 0.4
rain.LightInfluence = 0.8
rain.Rate = 0
rain.Parent = sky

local snow = Instance.new("ParticleEmitter")
snow.Name = "Snow"
snow.Texture = TEX.snow
snow.EmissionDirection = Enum.NormalId.Bottom
snow.Speed = NumberRange.new(9, 14)
snow.SpreadAngle = Vector2.new(25, 25)
snow.Lifetime = NumberRange.new(5, 7)
snow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.42) })
snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.85, 0.25), NumberSequenceKeypoint.new(1, 1) })
snow.RotSpeed = NumberRange.new(-60, 60)
snow.Acceleration = Vector3.new(2, 0, 1)
snow.Drag = 0.4
snow.LightInfluence = 0.9
snow.Rate = 0
snow.Parent = sky

local splash = Instance.new("ParticleEmitter")
splash.Name = "Splash"
splash.Texture = TEX.splash
splash.EmissionDirection = Enum.NormalId.Top
splash.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
splash.Speed = NumberRange.new(0.5, 1.5)
splash.Lifetime = NumberRange.new(0.18, 0.28)
splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(1, 0.4) })
splash.Squash = NumberSequence.new(-0.6)
splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
splash.Color = ColorSequence.new(Color3.fromRGB(220, 230, 245))
splash.LightInfluence = 0.8
splash.Rate = 0
splash.Parent = ground

-- round 14: depth and wind. A second, closer rain layer (big faint streaks right by the camera), drifting
-- low mist puffs in fog and rain, and gusts that swing the slant of the rain and snow about.
local near = sheet("Near", Vector3.new(34, 1, 34))
local rainNear = rain:Clone()
rainNear.Name = "RainNear"
rainNear.Speed = NumberRange.new(85, 105)
rainNear.Lifetime = NumberRange.new(0.22, 0.3)
rainNear.Size = NumberSequence.new(1.2)
rainNear.Squash = NumberSequence.new(3.4)
rainNear.LightEmission = 0.1
rainNear.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.5, 0.86), NumberSequenceKeypoint.new(1, 0.95) })
rainNear.Parent = near

local mist = Instance.new("ParticleEmitter")
mist.Name = "Mist"
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.EmissionDirection = Enum.NormalId.Top
mist.Speed = NumberRange.new(0.5, 1.5)
mist.Lifetime = NumberRange.new(6, 9)
mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 7), NumberSequenceKeypoint.new(1, 13) })
mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
mist.Color = ColorSequence.new(Color3.fromRGB(214, 220, 230))
mist.RotSpeed = NumberRange.new(-8, 8)
mist.Rotation = NumberRange.new(0, 360)
mist.LightInfluence = 1
mist.Rate = 0
mist.Parent = ground

-- particle budget: follows the player's graphics quality (Automatic counts as mid)
local UGS = UserSettings():GetService("UserGameSettings")
local function budget()
	local ok, q = pcall(function() return UGS.SavedQualityLevel.Value end)
	q = (ok and q and q > 0) and q or 6
	return math.clamp(q / 8, 0.3, 1)
end

---------------------------------------------------------------- sound

local function sound(id, vol, looped)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.Looped = looped or false
	s.SoundGroup = SoundService:FindFirstChild("SFX")
	s.Parent = SoundService
	return s
end
local rainLoop = sound(RAIN_LOOP, 0, true)
local muffle = Instance.new("EqualizerSoundEffect")
muffle.HighGain, muffle.MidGain, muffle.LowGain = 0, 0, 0
muffle.Parent = rainLoop

Shared:GetAttributeChangedSignal("Lightning"):Connect(function()
	-- the flash is now (Lighting); the thunder rolls in a moment later
	task.delay(math.random() * 1.4 + 0.3, function()
		local s = sound(THUNDER[math.random(#THUNDER)], 0.55 + math.random() * 0.3)
		s.PlaybackSpeed = 0.9 + math.random() * 0.2
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
	end)
end)

---------------------------------------------------------------- indoors (the same test Lighting uses)

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
				and h:GetAttribute("RoofHidden") ~= true then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------- every frame

local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
if not clouds then
	clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
end
local cur = { rain = 0, snow = 0, splash = 0, vol = 0, cover = LOOK.clear.cover, dens = LOOK.clear.dens, wind = 0.1, mist = 0 }
local q, qAt = budget(), 0
local cloudCol = LOOK.clear.cloud
local inside, lastCheck = false, 0

RunService.RenderStepped:Connect(function(dt)
	local want = LOOK[Shared:GetAttribute("Weather") or "clear"] or LOOK.clear
	local e = math.min(1, dt * 0.4)
	for k, v in pairs(cur) do cur[k] = v + (want[k] - v) * e end
	cloudCol = cloudCol:Lerp(want.cloud, e)

	local now = os.clock()
	if now - lastCheck > 0.2 then
		lastCheck = now
		inside = cameraIndoors()
	end

	local cf = camera.CFrame
	local pos = cf.Position
	-- the sheet sits above the camera, a little ahead of where it's looking
	local ahead = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z) * 25
	sky.CFrame = CFrame.new(pos + ahead + Vector3.new(0, 55, 0))
	ground.CFrame = CFrame.new(pos.X + ahead.X * 0.6, Street.Y + 0.15, pos.Z + ahead.Z * 0.6)

	near.CFrame = CFrame.new(pos + ahead * 0.3 + Vector3.new(0, 16, 0))
	if now - qAt > 3 then qAt = now; q = budget() end

	local out = (inside and 0 or 1) * q
	rain.Rate = cur.rain * out
	rainNear.Rate = cur.rain * 0.1 * out
	snow.Rate = cur.snow * out
	-- splashes only where the street is near the camera
	splash.Rate = (math.abs(pos.Y - Street.Y) < 70) and cur.splash * out or 0
	mist.Rate = (math.abs(pos.Y - Street.Y) < 90) and cur.mist * (inside and 0 or 1) or 0
	-- gusts: slow noise swings the slant; storms gust hard
	local gx = math.noise(now * 0.23, 1.7) * 2
	local gz = math.noise(now * 0.19, 8.3) * 2
	local w = cur.wind
	rain.Acceleration = Vector3.new(6 + gx * 46 * w, 0, 3 + gz * 30 * w)
	rainNear.Acceleration = rain.Acceleration * 1.4
	snow.Acceleration = Vector3.new(2 + gx * 9 * w, 0, 1 + gz * 7 * w)
	mist.Acceleration = Vector3.new(1.2 + gx * 2 * w, 0, 0.6 + gz * 1.5 * w)

	local vol = cur.vol * (inside and 0.35 or 1)
	rainLoop.Volume = vol
	muffle.HighGain = inside and -24 or 0
	muffle.MidGain = inside and -8 or 0
	if vol > 0.01 and not rainLoop.IsPlaying then
		rainLoop:Play()
	elseif vol <= 0.01 and rainLoop.IsPlaying then
		rainLoop:Stop()
	end

	clouds.Cover = cur.cover
	clouds.Density = cur.dens
	clouds.Color = cloudCol
end)
