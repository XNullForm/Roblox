-- ServerScriptService.Weather (round 10c): the city's weather.
-- Publishes Shared attributes Weather (clear / cloudy / fog / rain / storm / snow), WeatherName (for the HUD) and,
-- in a storm, Lightning (a serial that ticks on each strike, with LightningAt = server time). Spells last a few
-- in-game hours; the next one is picked from what can follow (rain clears through cloud, a storm calms to rain).
-- Readers: Lighting and WeatherFX (sky, rain, sound), Crowds (fewer walkers, umbrellas, hurrying),
-- HotelSim (walk-ins rise in bad weather), GuestLife (what guests do and say).
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")

local NAMES = { clear = "Clear", cloudy = "Cloudy", fog = "Foggy", rain = "Rain", storm = "Thunderstorm", snow = "Snow" }
-- what can come next, with weights
local NEXT = {
	clear = { clear = 3, cloudy = 4, fog = 1 },
	cloudy = { clear = 3, cloudy = 1, rain = 3, snow = 0.6, fog = 0.6 },
	fog = { clear = 2, cloudy = 2 },
	rain = { cloudy = 3, rain = 1, storm = 1.4 },
	storm = { rain = 3, cloudy = 1 },
	snow = { cloudy = 2, snow = 1, clear = 1 },
}
-- how long a spell lasts (real seconds)
local LASTS = { clear = { 200, 360 }, cloudy = { 120, 220 }, fog = { 90, 160 }, rain = { 140, 240 }, storm = { 90, 150 }, snow = { 140, 240 } }

local rng = Random.new()
local Clock = require(Shared:WaitForChild("Clock"))
local function pick(t)
	-- round 19: the season biases the forecast -- snow sticks around in winter, spring showers
	local bias = Clock.seasonData().weather
	local total = 0
	for k, w in pairs(t) do total += w * (bias[k] or 1) end
	local r = rng:NextNumber() * total
	for k, w in pairs(t) do
		r -= w * (bias[k] or 1)
		if r <= 0 then return k end
	end
	return next(t)
end

local function set(w)
	Shared:SetAttribute("Weather", w)
	Shared:SetAttribute("WeatherName", NAMES[w])
end

-- Studio: set Shared attribute TestWeather to force one (it clears itself)
Shared:GetAttributeChangedSignal("TestWeather"):Connect(function()
	local w = Shared:GetAttribute("TestWeather")
	if w and NAMES[w] then
		Shared:SetAttribute("TestWeather", nil)
		set(w)
	end
end)

-- lightning while it storms
task.spawn(function()
	local n = 0
	while true do
		task.wait(rng:NextNumber(7, 18))
		if Shared:GetAttribute("Weather") == "storm" then
			n += 1
			Shared:SetAttribute("LightningAt", workspace:GetServerTimeNow())
			Shared:SetAttribute("Lightning", n)
		end
	end
end)

set("clear")
local w = "clear"
while true do
	local span = LASTS[w]
	local untilT = os.clock() + rng:NextNumber(span[1], span[2])
	while os.clock() < untilT do
		task.wait(2)
		if Shared:GetAttribute("Weather") ~= w then -- forced by the test hook
			w = Shared:GetAttribute("Weather")
			untilT = os.clock() + rng:NextNumber(LASTS[w][1], LASTS[w][2])
		end
	end
	w = pick(NEXT[w])
	set(w)
end
