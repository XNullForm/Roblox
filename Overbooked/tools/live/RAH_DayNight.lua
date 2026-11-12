-- ServerScriptService.RAH_DayNight: the game's clock. One full day/night cycle
-- every C.DAY_LENGTH seconds. Street lamps glow at dusk, guest traffic thins at
-- night (RAH_HotelSim reads the Night attribute), and DayEnded fires at every
-- rollover so each hotel can hand out its day summary.
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local C = require(RS.RAH.Config)
local shared = RS.RAH
local DayEnded = game.ServerStorage.RAH_Signals:WaitForChild("DayEnded")

-- lighting presets: `day` is captured from the authored scene, `night` is the
-- dusk look; everything blends smoothly by `nightness` (0 = day, 1 = night)
local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")

local day = {
	ambient = Lighting.Ambient,
	outdoor = Lighting.OutdoorAmbient,
	atmosDensity = atmos and atmos.Density or 0,
	atmosColor = atmos and atmos.Color or Color3.new(),
	atmosDecay = atmos and atmos.Decay or Color3.new(),
	bloom = bloom and bloom.Intensity or 0,
	rays = rays and rays.Intensity or 0,
	gradeBright = grade and grade.Brightness or 0,
	gradeContrast = grade and grade.Contrast or 0,
	gradeTint = grade and grade.TintColor or Color3.new(1, 1, 1),
}
local night = {
	ambient = Color3.fromRGB(26, 28, 42),
	outdoor = Color3.fromRGB(36, 38, 56),
	atmosDensity = (day.atmosDensity > 0 and day.atmosDensity or 0.3) + 0.13,
	atmosColor = Color3.fromRGB(120, 128, 168),
	atmosDecay = Color3.fromRGB(70, 76, 110),
	bloom = day.bloom + 0.35,
	rays = 0,
	gradeBright = day.gradeBright - 0.04,
	gradeContrast = day.gradeContrast + 0.06,
	gradeTint = Color3.fromRGB(198, 208, 255),
}

-- 0 during the day, 1 at night, ramping across dusk (19->20h) and dawn (5.5->6.5h)
local function nightness(t)
	if t >= C.NIGHT[1] + 1 or t < C.NIGHT[2] - 1 then
		return 1
	elseif t >= C.NIGHT[1] then
		return t - C.NIGHT[1]
	elseif t >= C.NIGHT[2] - 1 then
		return 1 - (t - (C.NIGHT[2] - 1))
	end
	return 0
end

---------------------------------------------------------------- street lamps

local LAMP_OFF = Color3.fromRGB(90, 88, 78)
local lamps = {} -- model -> { head, light, on }

local function trackLamp(model)
	if lamps[model] then return end
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	local light = head:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Color = head.Color
		light.Range = 17
		light.Brightness = 1.4
		light.Shadows = true
		light.Parent = head
	end
	light.Enabled = false
	lamps[model] = { head = head, light = light, on = head.Color }
end

local function scanLamps(parent)
	for _, d in ipairs(parent:GetDescendants()) do
		if d:IsA("Model") and d.Name == "Lamp" then trackLamp(d) end
	end
end
scanLamps(workspace)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") and d.Name == "Lamp" then
		task.defer(scanLamps, d)
	end
end)

local function setLamps(n)
	for _, l in pairs(lamps) do
		l.head.Color = LAMP_OFF:Lerp(l.on, n)
		l.light.Enabled = n > 0.2
		l.light.Brightness = 1.4 * n
	end
end

---------------------------------------------------------------- the clock

local dayN = 1
local clock = C.DAY_START
shared:SetAttribute("Day", dayN)
shared:SetAttribute("Night", false)

local function lerp(a, b, n)
	return a + (b - a) * n
end

local lastNight = -1
local function apply(n)
	Lighting.Ambient = day.ambient:Lerp(night.ambient, n)
	Lighting.OutdoorAmbient = day.outdoor:Lerp(night.outdoor, n)
	if atmos then
		atmos.Density = lerp(day.atmosDensity, night.atmosDensity, n)
		atmos.Color = day.atmosColor:Lerp(night.atmosColor, n)
		atmos.Decay = day.atmosDecay:Lerp(night.atmosDecay, n)
	end
	if bloom then bloom.Intensity = lerp(day.bloom, night.bloom, n) end
	if rays then rays.Intensity = lerp(day.rays, night.rays, n) end
	if grade then
		grade.Brightness = lerp(day.gradeBright, night.gradeBright, n)
		grade.Contrast = lerp(day.gradeContrast, night.gradeContrast, n)
		grade.TintColor = day.gradeTint:Lerp(night.gradeTint, n)
	end
	setLamps(n)
end

local rate = 24 / C.DAY_LENGTH -- clock hours per real second
local last = os.clock()
while true do
	local now = os.clock()
	local dt = now - last
	last = now
	clock += dt * rate
		if clock >= C.DAY_START + 24 then
		clock -= 24
		dayN += 1
		shared:SetAttribute("Day", dayN)
		DayEnded:Fire(dayN)
	end
	Lighting.ClockTime = clock
	local n = nightness(clock)
	-- only touch lighting/lamps when the blend actually moved
	if math.abs(n - lastNight) > 0.01 then
		lastNight = n
		apply(n)
		shared:SetAttribute("Night", n > 0.5)
	end
	task.wait(0.1)
end