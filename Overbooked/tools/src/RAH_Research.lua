-- ReplicatedStorage.RAH.Research: the research tree (round 9).
-- Each node costs cash and takes real time; one runs at a time (Lab Coats makes them faster).
-- A node unlocks build items (Catalog item.research = node id), shape materials, guest events (RAH.Events) or perks.
-- The hotel owns its research: hotel attribute "Research" = JSON { done = { [id] = true }, cur = id, ends = serverTime }.
local HttpService = game:GetService("HttpService")

local R = {}

R.BRANCHES = {
	{ id = "build", name = "Build Tools", color = Color3.fromRGB(232, 190, 106) },
	{ id = "decor", name = "Decor", color = Color3.fromRGB(240, 140, 170) },
	{ id = "comfort", name = "Comfort", color = Color3.fromRGB(110, 200, 170) },
	{ id = "fun", name = "Fun", color = Color3.fromRGB(150, 140, 255) },
	{ id = "service", name = "Service", color = Color3.fromRGB(104, 172, 255) },
	{ id = "guests", name = "Guest Events", color = Color3.fromRGB(255, 170, 90) },
	{ id = "perks", name = "Upgrades", color = Color3.fromRGB(150, 220, 110) },
	-- round 13: paths into the rest of the hotel
	{ id = "staff", name = "Staff Training", color = Color3.fromRGB(90, 200, 220) },
	{ id = "stay", name = "Guest Experience", color = Color3.fromRGB(255, 120, 120) },
	{ id = "market", name = "Marketing", color = Color3.fromRGB(255, 206, 80) },
	{ id = "dining", name = "Dining", color = Color3.fromRGB(240, 150, 80) },
	{ id = "upkeep", name = "Maintenance", color = Color3.fromRGB(160, 170, 190) },
}

-- row places a node on its branch's board (row 1 = first tier)
R.NODES = {
	-- build tools
	{ id = "shapes1", branch = "build", row = 1, name = "Builder's Kit", cost = 120, time = 25, desc = "Blocks, wedges and cylinders you can size, paint and stack." },
	{ id = "shapes2", branch = "build", row = 2, req = { "shapes1" }, name = "Sculptor's Kit", cost = 600, time = 75, desc = "Balls and corner wedges, plus marble, granite, brick and wood finishes." },
	{ id = "glassneon", branch = "build", row = 3, req = { "shapes2" }, name = "Glass & Neon", cost = 1800, time = 150, desc = "See-through glass and glowing neon for your shapes." },
	-- decor
	{ id = "decor1", branch = "decor", row = 1, name = "Interior Styling", cost = 180, time = 30, desc = "Wall art, a sunburst mirror, a blossom vase and table lamps." },
	{ id = "decor2", branch = "decor", row = 2, req = { "decor1" }, name = "Boutique Look", cost = 700, time = 70, desc = "Sculptures, flower stands, arc lamps, sconces and snake plants." },
	{ id = "decor3", branch = "decor", row = 3, req = { "decor2" }, name = "Grand Lobby", cost = 2200, time = 140, desc = "A fireplace, a grandfather clock, indoor palms, an aquarium and console tables." },
	{ id = "decor4", branch = "decor", row = 4, req = { "decor3" }, name = "Five-Star Finish", cost = 6000, time = 240, desc = "A grand piano, a desk globe and a coat rack for the lobby." },
	-- comfort
	{ id = "comfort1", branch = "comfort", row = 1, name = "Lounge Seating", cost = 220, time = 30, desc = "Velvet loveseats, poufs and swivel lounge chairs." },
	{ id = "rooms1", branch = "comfort", row = 1, name = "Room Essentials", cost = 260, time = 35, desc = "Dressers, luggage racks and mini fridges for guest rooms." },
	{ id = "comfort2", branch = "comfort", row = 2, req = { "comfort1" }, name = "Dining Corner", cost = 800, time = 80, desc = "A round dining set and brass bar stools." },
	{ id = "rooms2", branch = "comfort", row = 2, req = { "rooms1" }, name = "Work Trips", cost = 900, time = 90, desc = "Work desks for rooms. Business travellers start to book." },
	{ id = "comfort3", branch = "comfort", row = 3, req = { "comfort2" }, name = "Big Comfy", cost = 2600, time = 160, desc = "A huge corner sofa and a massage chair." },
	-- fun
	{ id = "fun1", branch = "fun", row = 1, name = "Game Room", cost = 600, time = 60, desc = "Arcade cabinets and foosball." },
	{ id = "fun2", branch = "fun", row = 2, req = { "fun1" }, name = "Amusements", cost = 1500, time = 110, desc = "A claw machine and a glowing jukebox." },
	{ id = "fun3", branch = "fun", row = 3, req = { "fun2" }, name = "Billiards Lounge", cost = 3600, time = 200, desc = "A full-size pool table." },
	-- service (the necessities)
	{ id = "safety", branch = "service", row = 1, name = "Safety First", cost = 150, time = 25, desc = "Fire extinguishers, first-aid kits and lobby bins. Inspectors check for these." },
	{ id = "service1", branch = "service", row = 2, req = { "safety" }, name = "Guest Services", cost = 550, time = 60, desc = "A coffee bar, a water cooler and a brochure stand." },
	{ id = "service2", branch = "service", row = 3, req = { "service1" }, name = "Concierge", cost = 1500, time = 120, desc = "Brass luggage carts and an ATM." },
	-- guest events
	{ id = "ev_family", branch = "guests", row = 1, name = "Family Friendly", cost = 650, time = 60, event = "baby", desc = "Cribs for rooms. Families with a baby start to visit." },
	{ id = "ev_access", branch = "guests", row = 1, name = "Accessible Rooms", cost = 650, time = 60, event = "access", desc = "Shower chairs and grab bars. Guests with access needs can stay." },
	{ id = "ev_pets", branch = "guests", row = 2, req = { "ev_family" }, name = "Pet Friendly", cost = 900, time = 80, event = "pet", desc = "Pet beds. Guests can bring their dogs." },
	{ id = "ev_night", branch = "guests", row = 2, req = { "ev_access" }, name = "Night Owls", cost = 1000, time = 90, event = "allnighter", desc = "All-night stays: guests who stay up and want a TV and a snack." },
	{ id = "ev_party", branch = "guests", row = 3, req = { "ev_pets" }, name = "Celebrations", cost = 1200, time = 100, event = "birthday", desc = "Party kits. Birthday guests throw a party in their room." },
	{ id = "ev_inspector", branch = "guests", row = 3, req = { "ev_night", "safety" }, name = "Hotel Inspector", cost = 2400, time = 140, event = "inspector", desc = "Inspectors rate your lobby and safety kit. Pass for a big star boost." },
	{ id = "ev_romance", branch = "guests", row = 4, req = { "ev_party" }, name = "Honeymoon Suites", cost = 1800, time = 130, event = "honeymoon", desc = "Champagne buckets. Newlyweds pay double for a lovely room." },
	{ id = "ev_tour", branch = "guests", row = 4, req = { "ev_inspector", "service1" }, name = "Tour Groups", cost = 3000, time = 170, event = "tour", desc = "Tour buses drop off four guests at once." },
	{ id = "ev_vip", branch = "guests", row = 5, req = { "ev_romance", "decor3" }, name = "Celebrity Guests", cost = 7000, time = 260, event = "celebrity", desc = "Famous guests who pay triple, if the room is stunning." },
	-- perks
	{ id = "up_street", branch = "perks", row = 1, name = "Street Signage", cost = 500, time = 50, perk = "walkins", desc = "More people on the street turn into your hotel." },
	{ id = "up_clean", branch = "perks", row = 1, name = "Better Mops", cost = 600, time = 60, perk = "clean", desc = "Janitors clean 30% faster." },
	{ id = "up_speed", branch = "perks", row = 2, req = { "up_street" }, name = "Speedy Check-In", cost = 900, time = 80, perk = "checkin", desc = "Check-ins at the desk take a third less time." },
	{ id = "up_lab", branch = "perks", row = 2, req = { "up_clean" }, name = "Lab Coats", cost = 1200, time = 90, perk = "research", desc = "All research finishes 25% faster." },
	{ id = "up_tips", branch = "perks", row = 3, req = { "up_speed" }, name = "Tip Jar", cost = 1600, time = 120, perk = "tips", desc = "Happy guests leave a tip when they check out." },
	{ id = "up_price", branch = "perks", row = 4, req = { "up_tips", "up_lab" }, name = "Premium Pricing", cost = 3200, time = 200, perk = "price", desc = "Every room earns 15% more a night." },

	-- round 13. `bonus` = { stat = multiplier } and `add` = { stat = amount }, read by R.mul / R.add.
	-- Stats: janitorTime, doormanTime, deskTime, cookTime, handymanTime (job time), staffXP, wages, walkins, price,
	-- tips, patience, breakEvery (time between breakdowns), mealPrice, mealWait; add: mood (at check-out)
	-- staff training: one start, then a path per job, joining up at the top
	{ id = "st_onboard", branch = "staff", row = 1, name = "Onboarding", cost = 400, time = 45, bonus = { staffXP = 1.25 }, desc = "A proper first day. Staff earn 25% more experience." },
	{ id = "st_janitor", branch = "staff", row = 2, req = { "st_onboard" }, name = "Cleaning Crew", cost = 700, time = 70, bonus = { janitorTime = 0.85 }, desc = "Janitors learn a room routine and clean 15% faster." },
	{ id = "st_door", branch = "staff", row = 2, req = { "st_onboard" }, name = "Door Etiquette", cost = 700, time = 70, bonus = { doormanTime = 0.8 }, desc = "Doormen spot guests sooner and let them in 20% faster." },
	{ id = "st_desk", branch = "staff", row = 2, req = { "st_onboard" }, name = "Front Desk Training", cost = 800, time = 75, bonus = { deskTime = 0.85 }, desc = "Receptionists check guests in and out 15% faster." },
	{ id = "st_janitor2", branch = "staff", row = 3, req = { "st_janitor" }, name = "Deep Clean Method", cost = 1800, time = 130, bonus = { janitorTime = 0.85 }, desc = "Another 15% off every clean." },
	{ id = "st_door2", branch = "staff", row = 3, req = { "st_door" }, name = "Valet Welcome", cost = 1600, time = 120, bonus = { patience = 1.12 }, desc = "Doormen chat to the line. Guests wait 12% longer before giving up." },
	{ id = "st_desk2", branch = "staff", row = 3, req = { "st_desk" }, name = "Express Check-Out", cost = 1900, time = 130, bonus = { deskTime = 0.85 }, desc = "Another 15% off every check-in and check-out." },
	{ id = "st_uniforms", branch = "staff", row = 3, req = { "st_onboard", "decor1" }, name = "Tailored Uniforms", cost = 1200, time = 90, perk = "uniforms", add = { mood = 2 }, desc = "Premium uniform styles in the staff wardrobe. Smart staff cheer guests up a little." },
	{ id = "st_happy", branch = "staff", row = 4, req = { "st_uniforms", "st_janitor2" }, name = "Happy Staff", cost = 3000, time = 180, bonus = { wages = 0.9 }, desc = "Perks and a team lunch. Wages cost 10% less." },
	{ id = "st_kitchen", branch = "staff", row = 4, req = { "st_desk2" }, name = "Kitchen Brigade", cost = 2600, time = 160, bonus = { cookTime = 0.85 }, desc = "Cooks work as a team: 15% faster at the stove." },
	{ id = "st_fixer", branch = "staff", row = 4, req = { "st_door2" }, name = "Handy Training", cost = 2400, time = 150, bonus = { handymanTime = 0.85 }, desc = "Handymen fix things 15% faster." },
	{ id = "st_master", branch = "staff", row = 5, req = { "st_happy", "st_kitchen", "st_fixer" }, name = "Master Staff", cost = 9000, time = 300, bonus = { staffXP = 1.5, janitorTime = 0.9, doormanTime = 0.9, deskTime = 0.9, cookTime = 0.9, handymanTime = 0.9 }, desc = "The best team in town: everyone 10% faster and 50% more experience." },
	-- guest experience: two paths (comfort and service) that meet in luxury
	{ id = "g_pillow", branch = "stay", row = 1, name = "Pillow Menu", cost = 500, time = 50, add = { mood = 3 }, desc = "Soft, firm or feather. Guests leave a little happier." },
	{ id = "g_welcome", branch = "stay", row = 2, req = { "g_pillow" }, name = "Welcome Gifts", cost = 1100, time = 90, add = { mood = 3 }, desc = "Chocolates on the pillow. Guests leave happier." },
	{ id = "g_quiet", branch = "stay", row = 2, req = { "g_pillow" }, name = "Soundproofing", cost = 1300, time = 100, bonus = { patience = 1.1 }, add = { mood = 2 }, desc = "Quiet rooms and a calmer lobby: guests are more patient." },
	{ id = "g_turndown", branch = "stay", row = 3, req = { "g_welcome", "st_janitor" }, name = "Turndown Service", cost = 2600, time = 160, add = { mood = 4 }, bonus = { tips = 1.15 }, desc = "Janitors turn the beds down at night. Happier guests and better tips." },
	{ id = "g_lounge", branch = "stay", row = 3, req = { "g_quiet", "comfort2" }, name = "Residents' Lounge", cost = 2800, time = 170, bonus = { patience = 1.15 }, desc = "A quiet place to wait. Guests in line wait 15% longer." },
	{ id = "g_concierge", branch = "stay", row = 4, req = { "g_turndown", "service2" }, name = "Personal Concierge", cost = 4500, time = 220, add = { mood = 4 }, bonus = { tips = 1.2 }, desc = "Tables booked, taxis called. Even happier guests and bigger tips." },
	{ id = "g_luxury", branch = "stay", row = 5, req = { "g_concierge", "g_lounge" }, name = "Luxury Standard", cost = 10000, time = 320, add = { mood = 5 }, bonus = { price = 1.12 }, desc = "Your hotel is officially luxury. Rooms earn 12% more and guests love it." },
	-- marketing: walk-ins on one side, money on the other
	{ id = "m_flyers", branch = "market", row = 1, name = "Flyers", cost = 300, time = 40, bonus = { walkins = 1.15 }, desc = "Flyers all over town. 15% more people walk in." },
	{ id = "m_online", branch = "market", row = 2, req = { "m_flyers" }, name = "Online Listing", cost = 900, time = 80, bonus = { walkins = 1.15 }, desc = "You're on the map. Another 15% more walk-ins." },
	{ id = "m_reviews", branch = "market", row = 2, req = { "m_flyers" }, name = "Review Cards", cost = 900, time = 80, add = { mood = 2 }, desc = "A thank-you card at check-out nudges reviews up." },
	{ id = "m_social", branch = "market", row = 3, req = { "m_online" }, name = "Social Buzz", cost = 2400, time = 150, bonus = { walkins = 1.2 }, desc = "People post your lobby online. 20% more walk-ins." },
	{ id = "m_loyalty", branch = "market", row = 3, req = { "m_reviews", "up_tips" }, name = "Loyalty Club", cost = 2200, time = 140, bonus = { tips = 1.25 }, desc = "Members tip 25% more." },
	{ id = "m_rates", branch = "market", row = 4, req = { "m_social", "up_price" }, name = "Smart Rates", cost = 5000, time = 220, bonus = { price = 1.1 }, desc = "Prices follow demand. Rooms earn 10% more." },
	{ id = "m_events", branch = "market", row = 4, req = { "m_loyalty", "ev_party" }, name = "Event Bookings", cost = 4200, time = 200, bonus = { walkins = 1.1, price = 1.05 }, desc = "Weddings and parties book your hotel." },
	{ id = "m_brand", branch = "market", row = 5, req = { "m_rates", "m_events" }, name = "Famous Brand", cost = 12000, time = 340, bonus = { walkins = 1.25, price = 1.1 }, desc = "Everyone knows your name. Many more guests, and they pay more." },
	-- dining (the kitchen opens at hotel level 3)
	{ id = "k_menu", branch = "dining", row = 1, name = "Bigger Menu", cost = 800, time = 70, bonus = { mealPrice = 1.15 }, desc = "More dishes on the board. Meals earn 15% more." },
	{ id = "k_fast", branch = "dining", row = 2, req = { "k_menu" }, name = "Line Cooking", cost = 1500, time = 110, bonus = { cookTime = 0.85 }, desc = "Prep ahead. Cooks are 15% faster." },
	{ id = "k_gourmet", branch = "dining", row = 2, req = { "k_menu" }, name = "Gourmet Plating", cost = 1700, time = 120, bonus = { mealPrice = 1.2 }, desc = "Pretty plates. Meals earn 20% more." },
	{ id = "k_service", branch = "dining", row = 3, req = { "k_fast" }, name = "Table Service", cost = 2600, time = 160, bonus = { mealWait = 1.3 }, desc = "Guests wait 30% longer for their food." },
	{ id = "k_chef", branch = "dining", row = 3, req = { "k_gourmet", "st_kitchen" }, name = "Signature Dishes", cost = 3800, time = 200, bonus = { mealPrice = 1.2 }, add = { mood = 2 }, desc = "A dish people come back for. Meals earn 20% more." },
	{ id = "k_star", branch = "dining", row = 4, req = { "k_service", "k_chef" }, name = "Star Restaurant", cost = 9000, time = 300, bonus = { mealPrice = 1.25, walkins = 1.1 }, desc = "A famous restaurant. Meals earn 25% more and diners book rooms." },
	-- maintenance
	{ id = "u_check", branch = "upkeep", row = 1, name = "Daily Checks", cost = 500, time = 50, bonus = { breakEvery = 1.25 }, desc = "A walk-round every morning. Things break less often." },
	{ id = "u_tools", branch = "upkeep", row = 2, req = { "u_check" }, name = "Better Tools", cost = 1200, time = 90, bonus = { handymanTime = 0.8 }, desc = "Handymen fix things 20% faster." },
	{ id = "u_parts", branch = "upkeep", row = 2, req = { "u_check" }, name = "Spare Parts", cost = 1200, time = 90, bonus = { breakEvery = 1.25 }, desc = "Worn parts swapped early. Even fewer breakdowns." },
	{ id = "u_plumb", branch = "upkeep", row = 3, req = { "u_parts" }, name = "Modern Plumbing", cost = 2600, time = 160, bonus = { breakEvery = 1.3 }, desc = "Showers and toilets break much less." },
	{ id = "u_eco", branch = "upkeep", row = 3, req = { "u_tools" }, name = "Energy Saver", cost = 2400, time = 150, bonus = { wages = 0.95 }, desc = "Lower bills leave more for wages: 5% off the wage bill." },
	{ id = "u_smart", branch = "upkeep", row = 4, req = { "u_plumb", "u_eco", "up_lab" }, name = "Smart Building", cost = 7000, time = 260, bonus = { breakEvery = 1.5, handymanTime = 0.8 }, desc = "Sensors spot trouble early. Far fewer breakdowns, faster fixes." },
}

R.BY_ID = {}
for i, n in ipairs(R.NODES) do
	n.order = i
	R.BY_ID[n.id] = n
end

-- which node unlocks a given perk / event (for "needs research" messages)
R.PERK = {}
R.EVENT = {}
for _, n in ipairs(R.NODES) do
	if n.perk then R.PERK[n.perk] = n.id end
	if n.event then R.EVENT[n.event] = n.id end
end

function R.decode(s)
	if type(s) ~= "string" or s == "" then return { done = {} } end
	local ok, t = pcall(function() return HttpService:JSONDecode(s) end)
	if not ok or type(t) ~= "table" then return { done = {} } end
	t.done = type(t.done) == "table" and t.done or {}
	return t
end

function R.encode(t)
	return HttpService:JSONEncode(t)
end

function R.state(hotel)
	return R.decode(hotel and hotel:GetAttribute("Research"))
end

function R.has(hotel, id)
	if not id then return true end
	return R.state(hotel).done[id] == true
end

function R.hasPerk(hotel, perk)
	local id = R.PERK[perk]
	return id ~= nil and R.has(hotel, id)
end

function R.available(state, id)
	local n = R.BY_ID[id]
	if not n or state.done[id] then return false end
	for _, r in ipairs(n.req or {}) do
		if not state.done[r] then return false end
	end
	return true
end

-- round 13: the combined effect of every finished node on a stat (multipliers multiply, adds add).
-- Cached per hotel until its Research attribute changes, so it's cheap to call often.
local cache = setmetatable({}, { __mode = "k" })
local function totals(hotel)
	local raw = hotel and hotel:GetAttribute("Research") or ""
	local c = cache[hotel]
	if c and c.raw == raw then return c end
	c = { raw = raw, mul = {}, add = {} }
	local done = R.decode(raw).done
	for _, n in ipairs(R.NODES) do
		if done[n.id] then
			for k, v in pairs(n.bonus or {}) do c.mul[k] = (c.mul[k] or 1) * v end
			for k, v in pairs(n.add or {}) do c.add[k] = (c.add[k] or 0) + v end
		end
	end
	if hotel then cache[hotel] = c end
	return c
end
function R.mul(hotel, stat) return totals(hotel).mul[stat] or 1 end
function R.add(hotel, stat) return totals(hotel).add[stat] or 0 end

-- seconds a node takes for this hotel (Lab Coats: 25% faster)
function R.duration(state, id)
	local n = R.BY_ID[id]
	local t = (n and n.time or 60) * (require(script.Parent:WaitForChild("Config")).RESEARCH_TIME_MUL or 1)
	if state.done.up_lab then t *= 0.75 end
	return math.floor(t + 0.5)
end

return R
