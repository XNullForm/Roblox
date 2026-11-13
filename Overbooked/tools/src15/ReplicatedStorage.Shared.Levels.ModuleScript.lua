-- ReplicatedStorage.Shared.Levels: the hotel level (round 10).
-- The hotel earns XP from running it: check-ins, happy stays, cleaning, research, special guests, new rooms
-- and meals. Every level unlocks something: shop items, research, staff hires and features (the kitchen,
-- room wings), plus a cash reward.
-- Hotel attributes (server-owned, saved by Save): Level, XP (progress into this level), XPNeed.
-- Notify: "xp" { amount, reason, pos } and "levelUp" { level, cash, unlocks = { { kind, name, icon } } }.
-- Levels.award(hotel, amount, reason, pos) is server-only. Pass silent = true to skip the
-- XP and level-up popups (used by the /level and /mlevel chat commands).
local Levels = {}

Levels.MAX = 30
Levels.XP = { checkin = 6, stay = 12, clean = 4, research = 25, event = 20, room = 40, meal = 5 }

-- XP from this level to the next
function Levels.need(level)
	return math.floor(140 + 110 * (math.max(1, level) - 1) ^ 1.45) -- round 10e: harder
end

function Levels.reward(level)
	return 20 * level + 30 -- round 10e: was 100 x level
end

-- shop items without research (research items open with their research node's level)
Levels.ITEM = {
	Sofa = 2, PottedTree = 2, Bookshelf = 2, Wardrobe = 2,
	TVStand = 3,
	VendingMachine = 4, ToiletDeluxe = 4,
	PingPongTable = 5, ShowerRain = 5,
	BedDeluxe = 6,
	BedSuite = 9,
}

Levels.RESEARCH = {
	shapes1 = 1, shapes2 = 4, glassneon = 8,
	decor1 = 2, decor2 = 4, decor3 = 7, decor4 = 12,
	comfort1 = 2, rooms1 = 2, comfort2 = 5, rooms2 = 5, comfort3 = 9,
	fun1 = 3, fun2 = 6, fun3 = 10,
	safety = 1, service1 = 4, service2 = 7,
	ev_family = 3, ev_access = 3, ev_pets = 5, ev_night = 5, ev_party = 7, ev_inspector = 8,
	ev_romance = 10, ev_tour = 11, ev_vip = 15,
	up_street = 2, up_clean = 3, up_speed = 4, up_lab = 6, up_tips = 8, up_price = 12,
	-- round 13
	st_onboard = 2, st_janitor = 3, st_door = 3, st_desk = 3, st_janitor2 = 6, st_door2 = 6, st_desk2 = 6, st_uniforms = 4,
	st_happy = 9, st_kitchen = 8, st_fixer = 8, st_master = 14,
	g_pillow = 2, g_welcome = 4, g_quiet = 4, g_turndown = 7, g_lounge = 7, g_concierge = 10, g_luxury = 15,
	m_flyers = 1, m_online = 3, m_reviews = 3, m_social = 6, m_loyalty = 8, m_rates = 12, m_events = 10, m_brand = 16,
	k_menu = 3, k_fast = 5, k_gourmet = 5, k_service = 7, k_chef = 9, k_star = 13,
	u_check = 3, u_tools = 5, u_parts = 5, u_plumb = 7, u_eco = 7, u_smart = 12,
}

-- the level each hire needs: STAFF[id][n] = level for the n-th one
Levels.STAFF = {
	janitor = { 1, 3, 5, 8, 11, 14 },
	doorman = { 2, 7 },
	receptionist = { 1, 4, 9 },
	cook = { 3, 6, 10 },
	handyman = { 4, 11 },
}

-- room wings, by room id
Levels.ROOM = { [104] = 2, [105] = 4, [106] = 6, [107] = 9, [108] = 12, [109] = 15, [110] = 18, [111] = 21 }

-- whole features
Levels.FEATURE = {
	kitchen = { level = 3, name = "The Kitchen", icon = "food" },
	-- round 37: new kinds of guest (GuestEvents defs with feature = these ids)
	guest_backpacker = { level = 3, name = "Backpacker guests", icon = "walk" },
	guest_fitness = { level = 4, name = "Fitness fan guests", icon = "run" },
	guest_gamer = { level = 5, name = "Gamer guests", icon = "catFun" },
	guest_spa = { level = 7, name = "Spa lover guests", icon = "shower" },
}

local function catalog()
	return require(script.Parent:WaitForChild("Catalog"))
end
local function research()
	return require(script.Parent:WaitForChild("Research"))
end

function Levels.of(hotel)
	return hotel and hotel:GetAttribute("Level") or 1
end

-- the level a shop item needs (its own, or its research node's)
function Levels.itemLevel(id)
	local it = catalog().ITEMS[id]
	if not it then return 1 end
	if it.level then return it.level end
	if it.research then return Levels.RESEARCH[it.research] or 1 end
	return Levels.ITEM[id] or 1
end

function Levels.itemOk(hotel, id) return Levels.of(hotel) >= Levels.itemLevel(id) end
function Levels.researchLevel(id) return Levels.RESEARCH[id] or 1 end
function Levels.researchOk(hotel, id) return Levels.of(hotel) >= Levels.researchLevel(id) end

function Levels.staffLevel(id, n)
	local t = Levels.STAFF[id]
	return t and t[n] or 1
end
function Levels.staffOk(hotel, id, n) return Levels.of(hotel) >= Levels.staffLevel(id, n) end

function Levels.roomLevel(id) return Levels.ROOM[id] or 1 end

function Levels.featureOk(hotel, id)
	local f = Levels.FEATURE[id]
	return not f or Levels.of(hotel) >= f.level
end

local ORDINAL = { "1st", "2nd", "3rd", "4th", "5th", "6th" }

-- everything that opens at exactly this level (for the level-up card and the level road)
function Levels.unlocksAt(level)
	local out = {}
	for id, f in pairs(Levels.FEATURE) do
		if f.level == level then table.insert(out, { kind = "feature", id = id, name = f.name, icon = f.icon }) end
	end
	for id, lv in pairs(Levels.ROOM) do
		if lv == level then table.insert(out, { kind = "room", id = id, name = "Room " .. id, icon = "bed" }) end
	end
	local staffNames = { janitor = "Janitor", doorman = "Doorman", receptionist = "Receptionist", cook = "Cook", handyman = "Handyman" }
	local staffIcons = { janitor = "janitor", doorman = "doorman", receptionist = "bell", cook = "chef", handyman = "wrench" }
	for id, list in pairs(Levels.STAFF) do
		for n, lv in ipairs(list) do
			if lv == level and n > 1 then
				table.insert(out, { kind = "staff", id = id, name = ORDINAL[n] .. " " .. staffNames[id], icon = staffIcons[id] })
			elseif lv == level and n == 1 and level > 1 then
				table.insert(out, { kind = "staff", id = id, name = staffNames[id], icon = staffIcons[id] })
			end
		end
	end
	local R = research()
	for _, n in ipairs(R.NODES) do
		if Levels.researchLevel(n.id) == level and level > 1 then
			table.insert(out, { kind = "research", id = n.id, name = n.name, icon = "research" })
		end
	end
	local Cat = catalog()
	for _, id in ipairs(Cat.ORDER) do
		local it = Cat.ITEMS[id]
		if it and not it.research and Levels.itemLevel(id) == level and level > 1 then
			table.insert(out, { kind = "item", id = id, name = it.name, icon = "hammer" })
		end
	end
	return out
end

---------------------------------------------------------------- server: awarding XP

function Levels.award(hotel, amount, reason, pos, silent)
	if not hotel or not hotel.Parent or not amount or amount <= 0 then return end
	local Players = game:GetService("Players")
	local Notify = script.Parent:WaitForChild("Remotes"):WaitForChild("Notify")
	local level = hotel:GetAttribute("Level") or 1
	local xp = (hotel:GetAttribute("XP") or 0) + math.floor(amount)
	local ups = {}
	while level < Levels.MAX and xp >= Levels.need(level) do
		xp -= Levels.need(level)
		level += 1
		table.insert(ups, level)
	end
	if level >= Levels.MAX then xp = math.min(xp, Levels.need(Levels.MAX)) end
	hotel:SetAttribute("Level", level)
	hotel:SetAttribute("XP", xp)
	hotel:SetAttribute("XPNeed", Levels.need(level))
	local members = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == hotel.Name then table.insert(members, p) end
	end
	for _, p in ipairs(members) do
		if not silent then
			Notify:FireClient(p, "xp", { amount = math.floor(amount), reason = reason, pos = pos })
		end
	end
	for _, lv in ipairs(ups) do
		local cash = Levels.reward(lv)
		-- the reward goes to the owner (co-op partners see the celebration too)
		local owner = Players:GetPlayerByUserId(hotel:GetAttribute("Owner") or 0)
		if owner then
			owner:SetAttribute("Cash", (owner:GetAttribute("Cash") or 0) + cash)
			owner:SetAttribute("Earned", (owner:GetAttribute("Earned") or 0) + cash)
		end
		local unlocks = Levels.unlocksAt(lv)
		for _, p in ipairs(members) do
			if not silent then
				Notify:FireClient(p, "levelUp", { level = lv, cash = cash, unlocks = unlocks })
			end
		end
	end
	if #ups > 0 then
		local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
		local changed = signals and signals:FindFirstChild("ItemsChanged")
		if changed then changed:Fire() end -- so the save picks it up
	end
end

return Levels
