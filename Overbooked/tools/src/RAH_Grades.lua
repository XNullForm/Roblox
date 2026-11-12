-- ReplicatedStorage.RAH.Grades (round 11): the hotel's grade, 1 (Roadside Inn) to 5 (Palace Hotel).
-- Every hotel starts as a modest one-storey inn. Each grade is bought from the Hotel page once its
-- requirements are met; it raises room prices and arrivals, and the building grows (HotelBuilder's B.roof
-- reads the hotel attribute Grade: a lit marquee, then a second and third storey, then the neon blade sign).
-- Grade 3+ brings VIP guests. Shared by the server (RAH_BuildServer "grade", RAH_HotelSim) and clients (RAH_Coop).
local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))

local G = {}

G.LIST = {
	{ name = "Roadside Inn", look = "A one-storey inn with a painted sign" },
	{ name = "Town Hotel", price = 3000, level = 4, rooms = 3, rating = 0, staff = 1,
		look = "A stone cornice and a marquee sign with bulbs", perk = "Rooms earn 12% more" },
	{ name = "City Hotel", price = 10000, level = 8, rooms = 4, rating = 3.0, staff = 2,
		look = "A second storey with curtained windows", perk = "VIP guests start to visit" },
	{ name = "Grand Hotel", price = 26000, level = 13, rooms = 6, rating = 3.5, staff = 4,
		look = "A third storey with balconies and flower boxes", perk = "More VIPs, and they pay more" },
	{ name = "Palace Hotel", price = 60000, level = 18, rooms = 8, rating = 4.0, staff = 6,
		look = "A neon HOTEL sign and a lit gold roof line", perk = "The best prices in town" },
}
G.MAX = #G.LIST

function G.of(hotel)
	return math.clamp(hotel and hotel:GetAttribute("Grade") or 1, 1, G.MAX)
end

-- what each grade does to the numbers
function G.priceMul(g) return 1 + 0.12 * (g - 1) end
function G.arrivalMul(g) return 1 + 0.08 * (g - 1) end
function G.vipChance(g) return g >= 3 and (0.05 + 0.03 * (g - 3)) or 0 end

-- open guest rooms (the sim's counts), hired staff, rating in stars
function G.rooms(hotel)
	return (hotel:GetAttribute("RoomsReady") or 0) + (hotel:GetAttribute("RoomsBusy") or 0) + (hotel:GetAttribute("RoomsDirty") or 0)
end
function G.staff(hotel)
	local n = 0
	for _, d in ipairs(C.STAFF) do n += hotel:GetAttribute(d.attr) or 0 end
	return n
end
function G.rating(hotel)
	return hotel:GetAttribute("HotelStars") or 0
end

local function money(n)
	local s = tostring(math.floor(n))
	while true do
		local k
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then return "$" .. s end
	end
end
G.money = money

-- the checklist for the next grade: { {text, ok}, ... }, allOk, def (nil at the top grade)
function G.check(hotel, cash)
	local g = G.of(hotel)
	local def = G.LIST[g + 1]
	if not def then return {}, false, nil end
	local lv = hotel:GetAttribute("Level") or 1
	local rooms, staff, rating = G.rooms(hotel), G.staff(hotel), G.rating(hotel)
	local list = {
		{ text = "Hotel level " .. def.level, have = "level " .. lv, ok = lv >= def.level },
		{ text = def.rooms .. " open guest rooms", have = tostring(rooms), ok = rooms >= def.rooms },
	}
	if def.staff > 0 then table.insert(list, { text = def.staff .. " staff hired", have = tostring(staff), ok = staff >= def.staff }) end
	if def.rating > 0 then table.insert(list, { text = string.format("Rating %.1f stars", def.rating), have = string.format("%.1f", rating), ok = rating >= def.rating }) end
	table.insert(list, { text = money(def.price), have = money(cash or 0), ok = (cash or 0) >= def.price, money = true })
	local all = true
	for _, e in ipairs(list) do if not e.ok then all = false end end
	return list, all, def
end

return G
