-- ReplicatedStorage.Shared.Quests (round 10c): the goals, in chapters. Shared by the server (QuestServer
-- tracks them) and the HUD (Client draws the current chapter on the right, Q.SHOW at a time).
-- A quest either counts a stat (the server's Signals.Quest:Fire(hotel, stat, n) adds n) or reads the
-- hotel's state (state = "level" / "rating" / "rooms" / "staff:<id>", checked every second).
-- Progress lives in the hotel attribute Quests (JSON { ch = chapter, p = { [id] = n }, done = { [id] = true } })
-- and is saved with the hotel. Rewards (cash to the owner, XP to the hotel) are paid as each one completes.
local Q = {}

Q.SHOW = 3 -- quests on screen at once

Q.CHAPTERS = {
	{
		title = "Opening Day",
		quests = {
			{ id = "c1_letin", text = "Let 3 guests in", icon = "door", stat = "letin", goal = 3, cash = 100, xp = 15 },
			{ id = "c1_checkin", text = "Check in 3 guests", icon = "bell", stat = "checkin", goal = 3, cash = 100, xp = 15 },
			{ id = "c1_clean", text = "Clean 2 rooms", icon = "clean", stat = "clean", goal = 2, cash = 120, xp = 20 },
			{ id = "c1_collect", text = "Collect cash from the safe", icon = "cash", stat = "collect", goal = 1, cash = 80, xp = 10 },
			{ id = "c1_decor", text = "Place 2 things in the lobby", icon = "hammer", stat = "placeLobby", goal = 2, cash = 150, xp = 20 },
		},
	},
	{
		title = "Word Gets Around",
		quests = {
			{ id = "c2_talk", text = "Talk to 3 guests", icon = "guest", stat = "talk", goal = 3, cash = 200, xp = 25 },
			{ id = "c2_earn", text = "Earn $1,000 from stays", icon = "cash", stat = "earn", goal = 1000, cash = 250, xp = 30, money = true },
			{ id = "c2_review", text = "Get a 5-star review", icon = "star", stat = "review5", goal = 1, cash = 300, xp = 35 },
			{ id = "c2_desk", text = "Hire a receptionist", icon = "bell", state = "staff:receptionist", goal = 1, cash = 250, xp = 30 },
			{ id = "c2_level", text = "Reach hotel level 3", icon = "medal", state = "level", goal = 3, cash = 300, xp = 0 },
		},
	},
	{
		title = "Growing Pains",
		quests = {
			{ id = "c3_guests", text = "Serve 15 guests", icon = "guest", stat = "guests", goal = 15, cash = 450, xp = 50 },
			{ id = "c3_research", text = "Finish a research", icon = "research", stat = "research", goal = 1, cash = 400, xp = 40 },
			{ id = "c3_rooms", text = "Open 4 guest rooms", icon = "bed", state = "rooms", goal = 4, cash = 600, xp = 60 },
			{ id = "c3_clean", text = "Clean 10 rooms", icon = "clean", stat = "clean", goal = 10, cash = 450, xp = 50 },
			{ id = "c3_rating", text = "Reach a 3.5-star rating", icon = "star", state = "rating", goal = 35, cash = 600, xp = 60, tenths = true },
		},
	},
	{
		title = "Five-Star Service",
		quests = {
			{ id = "c4_janitor", text = "Hire a janitor", icon = "janitor", state = "staff:janitor", goal = 1, cash = 800, xp = 80 },
			{ id = "c4_reviews", text = "Get 5 five-star reviews", icon = "star", stat = "review5", goal = 5, cash = 1000, xp = 90 },
			{ id = "c4_place", text = "Place 10 things in your hotel", icon = "hammer", stat = "place", goal = 10, cash = 800, xp = 80 },
			{ id = "c4_earn", text = "Earn $10,000 from stays", icon = "cash", stat = "earn", goal = 10000, cash = 1200, xp = 100, money = true },
			{ id = "c4_level", text = "Reach hotel level 6", icon = "medal", state = "level", goal = 6, cash = 1200, xp = 0 },
		},
	},
	{
		title = "The Grand Hotel",
		quests = {
			{ id = "c5_guests", text = "Serve 60 guests", icon = "guest", stat = "guests", goal = 60, cash = 2000, xp = 150 },
			{ id = "c5_rooms", text = "Open 6 guest rooms", icon = "bed", state = "rooms", goal = 6, cash = 2500, xp = 160 },
			{ id = "c5_desk", text = "Hire 3 receptionists", icon = "bell", state = "staff:receptionist", goal = 3, cash = 2000, xp = 150 },
			{ id = "c5_rating", text = "Reach a 4.5-star rating", icon = "star", state = "rating", goal = 45, cash = 3000, xp = 200, tenths = true },
			{ id = "c5_level", text = "Reach hotel level 10", icon = "medal", state = "level", goal = 10, cash = 3000, xp = 0 },
		},
	},
}

Q.BY_ID = {}
for ci, ch in ipairs(Q.CHAPTERS) do
	for qi, q in ipairs(ch.quests) do
		q.chapter, q.order = ci, qi
		Q.BY_ID[q.id] = q
	end
end

-- "1,000 / 3" style progress text
function Q.progressText(q, n)
	n = math.min(n or 0, q.goal)
	if q.tenths then return string.format("%.1f / %.1f", n / 10, q.goal / 10) end
	local function f(x)
		local s = tostring(math.floor(x))
		while true do
			local k
			s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			if k == 0 then break end
		end
		return s
	end
	return (q.money and "$" or "") .. f(n) .. " / " .. (q.money and "$" or "") .. f(q.goal)
end

-- the hotel's value for a state goal or achievement (level, rating in tenths, open guest rooms, staff)
function Q.stateValue(hotel, s, staffAttr)
	if s == "level" then return hotel:GetAttribute("Level") or 1 end
	if s == "rating" then return math.floor((hotel:GetAttribute("HotelStars") or 1) * 10 + 0.5) end
	if s == "rooms" then
		local n = 0
		local rf = hotel:FindFirstChild("Rooms")
		if rf then
			for _, r in ipairs(rf:GetChildren()) do
				if r:GetAttribute("State") and r:GetAttribute("State") ~= "Unfurnished" then n += 1 end
			end
		end
		return n
	end
	local staff = s and s:match("^staff:(%a+)$")
	if staff and staffAttr then return hotel:GetAttribute(staffAttr[staff] or "") or 0 end
	return 0
end

-- achievements (round 10c): lifetime milestones in three tiers. A stat one counts the same signals as the
-- chapter goals (kept for good in the Quests state's `life` table); a state one reads the hotel. Each tier is
-- claimed for its cash (and XP) on the menu's Achievements page; claimed tiers are in the state's `ach`.
Q.TIER_NAMES = { "Bronze", "Silver", "Gold" }
Q.ACHIEVEMENTS = {
	{ id = "greeter", name = "Warm Welcome", text = "Let %s guests in", icon = "door", stat = "letin", tiers = { 10, 50, 200 }, cash = { 150, 600, 2000 }, xp = { 20, 60, 160 } },
	{ id = "desk", name = "Front Desk Pro", text = "Check in %s guests", icon = "bell", stat = "checkin", tiers = { 10, 50, 200 }, cash = { 150, 600, 2000 }, xp = { 20, 60, 160 } },
	{ id = "served", name = "Full House", text = "Serve %s guests", icon = "guest", stat = "guests", tiers = { 25, 100, 500 }, cash = { 250, 1000, 4000 }, xp = { 30, 90, 240 } },
	{ id = "spotless", name = "Spotless", text = "Clean %s rooms", icon = "clean", stat = "clean", tiers = { 10, 60, 250 }, cash = { 150, 700, 2500 }, xp = { 20, 70, 180 } },
	{ id = "earner", name = "Big Earner", text = "Earn %s from stays", icon = "cash", stat = "earn", tiers = { 5000, 50000, 500000 }, cash = { 300, 1500, 6000 }, xp = { 30, 100, 300 }, money = true },
	{ id = "collector", name = "Cash Collector", text = "Collect from the safe %s times", icon = "cash", stat = "collect", tiers = { 10, 50, 200 }, cash = { 120, 500, 1600 }, xp = { 15, 50, 140 } },
	{ id = "fivestar", name = "Five-Star Host", text = "Get %s five-star reviews", icon = "star", stat = "review5", tiers = { 5, 25, 100 }, cash = { 250, 1200, 5000 }, xp = { 30, 100, 280 } },
	{ id = "chatty", name = "People Person", text = "Talk to %s guests", icon = "chat", stat = "talk", tiers = { 10, 50, 150 }, cash = { 120, 500, 1600 }, xp = { 15, 50, 140 } },
	{ id = "designer", name = "Interior Designer", text = "Place %s things", icon = "hammer", stat = "place", tiers = { 25, 120, 400 }, cash = { 200, 900, 3000 }, xp = { 25, 80, 220 } },
	{ id = "scientist", name = "Mad Scientist", text = "Finish %s research", icon = "research", stat = "research", tiers = { 3, 12, 30 }, cash = { 200, 900, 3000 }, xp = { 25, 80, 220 } },
	{ id = "hotelier", name = "Hotelier", text = "Reach hotel level %s", icon = "medal", state = "level", tiers = { 5, 10, 20 }, cash = { 400, 2000, 8000 }, xp = { 0, 0, 0 } },
	{ id = "rated", name = "Critics' Choice", text = "Reach a %s-star rating", icon = "trophy", state = "rating", tiers = { 30, 40, 48 }, cash = { 300, 1500, 6000 }, xp = { 30, 100, 300 }, tenths = true },
	-- round 38
	{ id = "jobs", name = "Odd Job Hero", text = "Finish %s odd jobs", icon = "quest", stat = "jobs", tiers = { 5, 30, 100 }, cash = { 250, 1000, 4000 }, xp = { 30, 90, 240 } },
	{ id = "finder", name = "Lost and Found", text = "Return %s lost items", icon = "teddy", stat = "lost", tiers = { 3, 15, 50 }, cash = { 200, 800, 2500 }, xp = { 20, 60, 160 } },
	{ id = "wrangler", name = "Critter Catcher", text = "Catch %s runaway animals", icon = "ev_pet", stat = "critter", tiers = { 3, 15, 50 }, cash = { 200, 800, 2500 }, xp = { 20, 60, 160 } },
	{ id = "tipped", name = "Tip Collector", text = "Pick up %s tips", icon = "cash", stat = "tip", tiers = { 10, 50, 200 }, cash = { 150, 600, 2000 }, xp = { 15, 50, 140 } },
	{ id = "tidy", name = "Tidy Lobby", text = "Clean up %s lobby spills", icon = "clean", stat = "spill", tiers = { 5, 25, 100 }, cash = { 150, 600, 2000 }, xp = { 15, 50, 140 } },
}

-- round 38: odd jobs. Three side goals are always on (state.sq, kept by QuestServer); a finished one pays and a
-- new one takes its place, so there is always something to do, even after the last chapter. Each pool entry:
-- key, text (%d = goal), icon, stat (a Signals.Quest stat), goal range, base cash. `moment` ones depend on lobby
-- moments (spills, lost items, tips, critters), so only one of those is on at a time.
Q.SIDE_SLOTS = 3
Q.SIDE = {
	{ key = "checkin", text = "Check in %d guests", icon = "bell", stat = "checkin", goal = { 4, 8 }, cash = 60 },
	{ key = "clean", text = "Clean %d rooms", icon = "clean", stat = "clean", goal = { 3, 6 }, cash = 70 },
	{ key = "letin", text = "Let %d guests in", icon = "door", stat = "letin", goal = { 4, 8 }, cash = 50 },
	{ key = "talk", text = "Talk to %d guests", icon = "chat", stat = "talk", goal = { 2, 4 }, cash = 60 },
	{ key = "review5", text = "Get %d five-star reviews", icon = "star", stat = "review5", goal = { 2, 4 }, cash = 90 },
	{ key = "guests", text = "Serve %d guests", icon = "guest", stat = "guests", goal = { 4, 8 }, cash = 80 },
	{ key = "collect", text = "Empty the safe %d times", icon = "cash", stat = "collect", goal = { 2, 3 }, cash = 40 },
	{ key = "place", text = "Place %d new things", icon = "hammer", stat = "place", goal = { 3, 5 }, cash = 60 },
	{ key = "spill", text = "Clean up %d lobby spills", icon = "clean", stat = "spill", goal = { 2, 3 }, cash = 70, moment = true },
	{ key = "lost", text = "Return %d lost items", icon = "teddy", stat = "lost", goal = { 1, 2 }, cash = 90, moment = true },
	{ key = "tip", text = "Pick up %d tips", icon = "cash", stat = "tip", goal = { 3, 5 }, cash = 60, moment = true },
	{ key = "critter", text = "Catch %d runaway animals", icon = "ev_pet", stat = "critter", goal = { 1, 2 }, cash = 100, moment = true },
}

-- a new odd job for a hotel at `level`, not one of the `active` keys (and no second moment one)
function Q.rollSide(level, active, n, rng)
	local busy, moment = {}, false
	for _, q in ipairs(active) do
		busy[q.key] = true
		for _, d in ipairs(Q.SIDE) do if d.key == q.key and d.moment then moment = true end end
	end
	local pool = {}
	for _, d in ipairs(Q.SIDE) do
		if not busy[d.key] and not (moment and d.moment) then table.insert(pool, d) end
	end
	local d = pool[rng:NextInteger(1, #pool)]
	local goal = rng:NextInteger(d.goal[1], d.goal[2])
	local k = 1 + 0.12 * math.max(0, (level or 1) - 1)
	return {
		id = "s" .. n .. "_" .. d.key, key = d.key, side = true, order = 10 + n,
		text = d.text:format(goal):gsub("^Return 1 lost items", "Return a lost item"):gsub("^Catch 1 runaway animals", "Catch a runaway animal"),
		icon = d.icon, stat = d.stat, goal = goal,
		cash = math.floor(d.cash * k * (0.8 + goal / d.goal[2] * 0.4) / 5 + 0.5) * 5, xp = 8 + math.min(40, level or 1),
	}
end
Q.ACH_BY_ID = {}
for _, a in ipairs(Q.ACHIEVEMENTS) do Q.ACH_BY_ID[a.id] = a end

local function commas(x)
	local s = tostring(math.floor(x))
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return s
end

-- a goal number as players read it ("$5,000", "4.0", "200")
function Q.fmt(a, n)
	if a.tenths then return string.format("%.1f", n / 10) end
	return (a.money and "$" or "") .. commas(n)
end

-- how many tiers a value reaches (0..3)
function Q.tierOf(a, v)
	local t = 0
	for i, goal in ipairs(a.tiers) do
		if v >= goal then t = i end
	end
	return t
end

-- the quests to show: the chapter's first unfinished ones (2 when odd jobs are on, else Q.SHOW), then the odd jobs,
-- at most Q.SHOW + 1 cards in all (round 38)
function Q.visible(state)
	local ch = Q.CHAPTERS[state.ch or 1]
	local side = type(state.sq) == "table" and state.sq or {}
	local done = state.done or {}
	local out = {}
	if ch then
		local cap = #side > 0 and 2 or Q.SHOW
		for _, q in ipairs(ch.quests) do
			if #out >= cap then break end
			if not done[q.id] then table.insert(out, q) end
		end
	end
	for _, q in ipairs(side) do
		if #out >= Q.SHOW + 1 then break end
		if not done[q.id] then table.insert(out, q) end
	end
	return out
end

return Q
