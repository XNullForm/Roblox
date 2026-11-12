-- StarterPlayerScripts.RAH_WeatherFX (round 10c): what the weather looks and sounds like on this client.
-- Reads RAH attributes Weather and Lightning (RAH_Weather). Rain and snow fall from a sheet that follows the
-- camera, rain splashes on the street round it, the clouds thicken, and the rain loop plays (muffled indoors);
-- a storm's lightning brings thunder a beat later. The sky itself (darker, hazier) is RAH_Lighting's job.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local RAH = RS:WaitForChild("RAH")
local Street = require(RAH:WaitForChild("Street"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TEX = { rain = "rbxassetid://121142287419380", snow = "rbxassetid://134437018607647", splash = "rbxassetid://84023424081823" }
local RAIN_LOOP = "rbxassetid://9112857054"
local THUNDER = { "rbxassetid://9120016037", "rbxassetid://9120016256", "rbxassetid://9120016241" }

-- per weather: rain and snow rates, splash rate, rain volume, cloud cover and density
local LOOK = {
	clear = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.45, dens = 0.25, cloud = Color3.fromRGB(255, 255, 255) },
	cloudy = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.8, dens = 0.45, cloud = Color3.fromRGB(214, 218, 228) },
	fog = { rain = 0, snow = 0, splash = 0, vol = 0, cover = 0.9, dens = 0.5, cloud = Color3.fromRGB(200, 204, 212) },
	rain = { rain = 700, snow = 0, splash = 220, vol = 0.55, cover = 0.92, dens = 0.62, cloud = Color3.fromRGB(150, 156, 170) },
	storm = { rain = 1300, snow = 0, splash = 420, vol = 0.85, cover = 0.98, dens = 0.78, cloud = Color3.fromRGB(96, 100, 116) },
	snow = { rain = 0, snow = 420, splash = 0, vol = 0, cover = 0.9, dens = 0.55, cloud = Color3.fromRGB(226, 230, 238) },
}

---------------------------------------------------------------- the sheets

local fx = Instance.new("Folder")
fx.Name = "RAH_WeatherFX"
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

---------------------------------------------------------------- sound

local function sound(id, vol, looped)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.Looped = looped or false
	s.SoundGroup = SoundService:FindFirstChild("RAH_SFX")
	s.Parent = SoundService
	return s
end
local rainLoop = sound(RAIN_LOOP, 0, true)
local muffle = Instance.new("EqualizerSoundEffect")
muffle.HighGain, muffle.MidGain, muffle.LowGain = 0, 0, 0
muffle.Parent = rainLoop

RAH:GetAttributeChangedSignal("Lightning"):Connect(function()
	-- the flash is now (RAH_Lighting); the thunder rolls in a moment later
	task.delay(math.random() * 1.4 + 0.3, function()
		local s = sound(THUNDER[math.random(#THUNDER)], 0.55 + math.random() * 0.3)
		s.PlaybackSpeed = 0.9 + math.random() * 0.2
		s:Play()
		s.Ended:Connect(function() s:Destroy() end)
	end)
end)

---------------------------------------------------------------- indoors (the same test RAH_Lighting uses)

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

---------------------------------------------------------------- every frame

local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
if not clouds then
	clouds = Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
end
local cur = { rain = 0, snow = 0, splash = 0, vol = 0, cover = LOOK.clear.cover, dens = LOOK.clear.dens }
local cloudCol = LOOK.clear.cloud
local inside, lastCheck = false, 0

RunService.RenderStepped:Connect(function(dt)
	local want = LOOK[RAH:GetAttribute("Weather") or "clear"] or LOOK.clear
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

	local out = inside and 0 or 1
	rain.Rate = cur.rain * out
	snow.Rate = cur.snow * out
	-- splashes only where the street is near the camera
	splash.Rate = (math.abs(pos.Y - Street.Y) < 70) and cur.splash * out or 0

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
