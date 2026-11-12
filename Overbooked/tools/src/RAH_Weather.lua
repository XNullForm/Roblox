-- ServerScriptService.RAH_Weather (round 10c): the city's weather.
-- Publishes RAH attributes Weather (clear / cloudy / fog / rain / storm / snow), WeatherName (for the HUD) and,
-- in a storm, Lightning (a serial that ticks on each strike, with LightningAt = server time). Spells last a few
-- in-game hours; the next one is picked from what can follow (rain clears through cloud, a storm calms to rain).
-- Readers: RAH_Lighting and RAH_WeatherFX (sky, rain, sound), RAH_Crowds (fewer walkers, umbrellas, hurrying),
-- RAH_HotelSim (walk-ins rise in bad weather), RAH_GuestLife (what guests do and say).
local RS = game:GetService("ReplicatedStorage")
local RAH = RS:WaitForChild("RAH")

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
local function pick(t)
	local total = 0
	for _, w in pairs(t) do total += w end
	local r = rng:NextNumber() * total
	for k, w in pairs(t) do
		r -= w
		if r <= 0 then return k end
	end
	return next(t)
end

local function set(w)
	RAH:SetAttribute("Weather", w)
	RAH:SetAttribute("WeatherName", NAMES[w])
end

-- Studio: set RAH attribute TestWeather to force one (it clears itself)
RAH:GetAttributeChangedSignal("TestWeather"):Connect(function()
	local w = RAH:GetAttribute("TestWeather")
	if w and NAMES[w] then
		RAH:SetAttribute("TestWeather", nil)
		set(w)
	end
end)

-- lightning while it storms
task.spawn(function()
	local n = 0
	while true do
		task.wait(rng:NextNumber(7, 18))
		if RAH:GetAttribute("Weather") == "storm" then
			n += 1
			RAH:SetAttribute("LightningAt", workspace:GetServerTimeNow())
			RAH:SetAttribute("Lightning", n)
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
		if RAH:GetAttribute("Weather") ~= w then -- forced by the test hook
			w = RAH:GetAttribute("Weather")
			untilT = os.clock() + rng:NextNumber(LASTS[w][1], LASTS[w][2])
		end
	end
	w = pick(NEXT[w])
	set(w)
end
