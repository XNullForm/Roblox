-- ServerScriptService.RAH_DayNight: the game's clock (round 9 rewrite).
-- The clock is a pure function of server time, so every client runs it smoothly on its own
-- (RAH_Lighting) and the server only publishes the anchor: RAH attributes CycleStart (server time
-- when the current day began at dawn), Day (day number) and Night (bool, for the hotel sims).
-- DayEnded fires at every dawn so each hotel hands out its day summary.
-- One cycle = C.CYCLE seconds: the day (C.DAWN .. C.DUSK) takes C.DAY_SHARE of it, the night the rest.
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")

local C = require(RS.RAH.Config)
local Clock = require(RS.RAH.Clock)
local shared = RS.RAH
local DayEnded = game.ServerStorage.RAH_Signals:WaitForChild("DayEnded")

-- start the first day mid-morning
local start = workspace:GetServerTimeNow() - Clock.secondsAt(C.DAY_START_HOUR)
shared:SetAttribute("CycleStart", start)
shared:SetAttribute("Day", 1)
shared:SetAttribute("Night", false)

local day = 1
while true do
	local now = workspace:GetServerTimeNow()
	local into = now - shared:GetAttribute("CycleStart")
	if into >= C.CYCLE then
		shared:SetAttribute("CycleStart", shared:GetAttribute("CycleStart") + C.CYCLE)
		day += 1
		shared:SetAttribute("Day", day)
		DayEnded:Fire(day)
	end
	local t = Clock.now()
	Lighting.ClockTime = t -- the server's copy (clients drive their own every frame)
	shared:SetAttribute("Night", Clock.isNight(t))
	task.wait(0.5)
end
