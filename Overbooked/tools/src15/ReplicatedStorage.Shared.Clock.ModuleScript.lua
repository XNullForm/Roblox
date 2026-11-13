-- ReplicatedStorage.Shared.Clock: the game clock, shared by server and clients (round 9).
-- Clock.now() -> ClockTime (0..24) from server time and the Shared attribute CycleStart.
-- The cycle starts at dawn (C.DAWN). Daytime (DAWN..DUSK) runs for C.DAY_SHARE of C.CYCLE seconds,
-- night for the rest, so days feel long and nights pass quickly.
local RS = game:GetService("ReplicatedStorage")
local C = require(script.Parent:WaitForChild("Config"))

local Clock = {}

local DAY_HOURS = (C.DUSK - C.DAWN)
local NIGHT_HOURS = 24 - DAY_HOURS
local DAY_SECS = C.CYCLE * C.DAY_SHARE

-- seconds into the cycle -> clock hour
function Clock.at(secs)
	secs = secs % C.CYCLE
	if secs < DAY_SECS then
		return C.DAWN + DAY_HOURS * secs / DAY_SECS
	end
	return (C.DUSK + NIGHT_HOURS * (secs - DAY_SECS) / (C.CYCLE - DAY_SECS)) % 24
end

-- clock hour -> seconds into the cycle
function Clock.secondsAt(hour)
	local h = (hour - C.DAWN) % 24
	if h < DAY_HOURS then
		return DAY_SECS * h / DAY_HOURS
	end
	return DAY_SECS + (C.CYCLE - DAY_SECS) * (h - DAY_HOURS) / NIGHT_HOURS
end

function Clock.now()
	local start = RS.Shared:GetAttribute("CycleStart")
	if not start then return C.DAY_START_HOUR end
	return Clock.at(workspace:GetServerTimeNow() - start)
end

-- night = between C.NIGHT_FROM and C.NIGHT_TO (wraps past midnight)
function Clock.isNight(t)
	return t >= C.NIGHT_FROM or t < C.NIGHT_TO
end

-- ---------------------------------------------------------------- the calendar (round 19)
-- 12 months of C.DAYS_PER_MONTH game days, 4 seasons of 3 months. The year starts in spring,
-- so month 1 is March: seasons land where players expect them (summer holidays, winter snow).
local MONTHS = { "March", "April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February" }
local DOW = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" }
local SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }

-- the full date of a game day (defaults to today): day number, weekday, week, month and season
function Clock.date(day)
	day = math.max(1, day or RS.Shared:GetAttribute("Day") or 1)
	local i = day - 1
	local month = math.floor(i / C.DAYS_PER_MONTH) % 12 + 1
	local season = math.floor((month - 1) / 3) + 1
	season = RS.Shared:GetAttribute("SeasonForce") or season -- round 20: the /season commands
	return {
		day = day,
		dow = i % 7 + 1,
		dowName = DOW[i % 7 + 1],
		week = math.floor(i / 7) + 1,
		month = month,
		monthName = MONTHS[month],
		season = season,
		seasonName = SEASON_NAMES[season],
	}
end

Clock.monthName = function(m) return MONTHS[m] end
Clock.seasonName = function(s) return SEASON_NAMES[s] end

-- ---------------------------------------------------------------- season gameplay (round 19)
-- What each season does to the hotel, shared by the server sim and the client HUD so both stay in sync.
-- demand  = arrival rate multiplier (busy summer, quiet winter)
-- price   = room rate multiplier (summer holidays and the winter break charge more)
-- upkeep  = daily upkeep cost per built room (winter heating, spring gardening)
-- weather = weights that bias the weather spell picker (snow in winter, rain in spring)
-- types   = extra weight for guest types that favour the season (backpackers in summer...)
Clock.SEASON_DATA = {
	{ name = "Spring", demand = 1.1, price = 1.0, upkeep = 2,
		weather = { rain = 2, cloudy = 1.5 }, types = { chatty = 2, germ = 1.5 } },
	{ name = "Summer", demand = 1.35, price = 1.25, upkeep = 1,
		weather = { clear = 1.5, storm = 1.5 }, types = { party = 2.5, backpacker = 2, influencer = 1.5 } },
	{ name = "Autumn", demand = 1.0, price = 1.05, upkeep = 1.5,
		weather = { fog = 2, rain = 1.5 }, types = { bigspender = 2, karen = 1.5 } },
	{ name = "Winter", demand = 0.8, price = 1.15, upkeep = 3,
		weather = { snow = 4, fog = 1.5 }, types = { sleepy = 2, chatty = 1.5 } },
}

-- the season data of a game day (defaults to today)
-- round 35: today's world event (ServerScriptService.WorldEvents) scales demand and price on top of the season
function Clock.seasonData(day)
	local sd = Clock.SEASON_DATA[Clock.date(day).season]
	local sh = RS.Shared
	if not sh:GetAttribute("Event") or (day and day ~= sh:GetAttribute("Day")) then return sd end
	return setmetatable({ demand = sd.demand * (sh:GetAttribute("EventDemand") or 1), price = sd.price * (sh:GetAttribute("EventPrice") or 1),
		event = sh:GetAttribute("EventName") }, { __index = sd })
end

-- "7:45 PM"
function Clock.format(t)
	local h = math.floor(t)
	local m = math.floor((t - h) * 60 / 15) * 15
	local ampm = h >= 12 and "PM" or "AM"
	local h12 = h % 12
	if h12 == 0 then h12 = 12 end
	return string.format("%d:%02d %s", h12, m, ampm)
end

return Clock
