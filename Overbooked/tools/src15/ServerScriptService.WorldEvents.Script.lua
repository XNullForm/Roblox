-- ServerScriptService.WorldEvents (round 35): some days something happens in Harbour View.
-- Each new game day (Shared attribute Day) there is a chance of one event for that day. It publishes Shared attributes
-- Event (id), EventName, EventText, EventIcon (a C.ICONS key), EventDemand and EventPrice; Clock.seasonData() folds
-- the multipliers into the season's, so HotelSim's arrivals and room prices follow without knowing about events.
-- A storm or a heatwave also sets the weather (Weather's TestWeather hook). Clients show the banner (EventBanner).
-- Studio: set Shared attribute TestEvent to an id to start one now.
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local rng = Random.new()

local EVENTS = {
	{ id = "festival", name = "Harbour Festival", icon = "ev_party", demand = 1.6, price = 1.15, w = 3,
		text = "The town is packed for the festival. Expect a full house!" },
	{ id = "cruise", name = "Cruise Ship in Port", icon = "ev_tour", demand = 1.8, price = 1.0, w = 2,
		text = "A cruise ship just docked. Tourists are looking for rooms." },
	{ id = "conference", name = "Business Conference", icon = "ev_business", demand = 1.25, price = 1.3, w = 2,
		text = "A conference in town: guests pay more for a good room." },
	{ id = "surf", name = "Surf Contest", icon = "ev_party", demand = 1.4, price = 1.1, w = 2, weather = "clear",
		text = "Surfers from all over the coast are in town." },
	{ id = "heatwave", name = "Heatwave", icon = "sun", demand = 1.3, price = 1.05, w = 2, weather = "clear",
		text = "Scorching sun! Everyone wants a seaside room today." },
	{ id = "storm", name = "Big Storm", icon = "storm", demand = 0.65, price = 1.25, w = 2, weather = "storm",
		text = "A storm rolls in. Fewer arrivals, but stranded travellers pay extra." },
	{ id = "inspector", name = "Inspector in Town", icon = "ev_inspector", demand = 1.0, price = 1.2, w = 1,
		text = "Word is a hotel inspector is about. Keep every room spotless!" },
}

local function clear()
	for _, k in ipairs({ "Event", "EventName", "EventText", "EventIcon", "EventDemand", "EventPrice" }) do Shared:SetAttribute(k, nil) end
end

local function start(e)
	Shared:SetAttribute("EventName", e.name)
	Shared:SetAttribute("EventText", e.text)
	Shared:SetAttribute("EventIcon", e.icon)
	Shared:SetAttribute("EventDemand", e.demand)
	Shared:SetAttribute("EventPrice", e.price)
	Shared:SetAttribute("Event", e.id) -- last: clients react to this one
	if e.weather then Shared:SetAttribute("TestWeather", e.weather) end
end

local last
local function newDay()
	clear()
	local day = Shared:GetAttribute("Day") or 1
	if day < 3 or rng:NextNumber() > 0.45 then return end
	local total = 0
	for _, e in ipairs(EVENTS) do if e.id ~= last then total += e.w end end
	local r = rng:NextNumber() * total
	for _, e in ipairs(EVENTS) do
		if e.id ~= last then
			r -= e.w
			if r <= 0 then last = e.id start(e) return end
		end
	end
end

Shared:GetAttributeChangedSignal("Day"):Connect(newDay)
Shared:GetAttributeChangedSignal("TestEvent"):Connect(function()
	local id = Shared:GetAttribute("TestEvent")
	if not id then return end
	Shared:SetAttribute("TestEvent", nil)
	for _, e in ipairs(EVENTS) do if e.id == id then clear() start(e) end end
end)

-- round 35: now and then something gets spilled in a busy lobby (ServerStorage.Mess); busier days spill more
local Mess = require(game:GetService("ServerStorage"):WaitForChild("Mess"))
local Players = game:GetService("Players")
local Clock = require(Shared:WaitForChild("Clock"))
local U = require(Shared:WaitForChild("Upgrades"))
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(70, 140))
		local t = Clock.now()
		if t > 8 and t < 22 then
			local chance = 0.35 * math.clamp(Shared:GetAttribute("EventDemand") or 1, 0.6, 1.6)
			local plots = workspace:FindFirstChild("Plots")
			for _, plot in ipairs(plots and plots:GetChildren() or {}) do
				local here = false
				for _, p in ipairs(Players:GetPlayers()) do if p:GetAttribute("Plot") == plot.Name then here = true break end end
				local mats = U.BY.mats.mul ^ U.level(plot, "mats") -- round 36: the Doormats upgrade
				if here and (plot:GetAttribute("RoomsBusy") or 0) > 0 and rng:NextNumber() < chance * mats then pcall(Mess.spill, plot) end
				if here and rng:NextNumber() < 0.22 then pcall(Mess.lost, plot) end -- round 36: lost property
			end
		end
	end
end)
