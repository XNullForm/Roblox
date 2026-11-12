-- ReplicatedStorage.RAH.Clock: the game clock, shared by server and clients (round 9).
-- Clock.now() -> ClockTime (0..24) from server time and the RAH attribute CycleStart.
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
	local start = RS.RAH:GetAttribute("CycleStart")
	if not start then return C.DAY_START_HOUR end
	return Clock.at(workspace:GetServerTimeNow() - start)
end

-- night = between C.NIGHT_FROM and C.NIGHT_TO (wraps past midnight)
function Clock.isNight(t)
	return t >= C.NIGHT_FROM or t < C.NIGHT_TO
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
