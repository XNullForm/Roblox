-- ReplicatedStorage.Shared.Upgrades (round 20, 2026-11-11): simple hotel upgrades bought with cash in the menu's
-- Upgrades tab. A hotel's levels live in its attribute Upgrades (JSON { id = level }), saved by Save.
-- Most upgrades feed a stat that Shared.Research already hands out (Research.mul / Research.add fold these in), so
-- HotelSim needs no extra code: price, tips, patience, staffXP, wages, mood, and arrivals (guest spawn rate).
-- Curb Appeal is the hotel's look: Upgrades.look(hotel) = 0 (run-down) .. 4 (grand), read by ServerStorage.HotelSkin.
local HttpService = game:GetService("HttpService")
local U = {}

U.LIST = {
	{ id = "curb", name = "Curb Appeal", icon = "hotel", max = 4, base = 300, grow = 3.6, stat = "arrivals", mul = 1.04,
		desc = "Fix up the old place. Every level makes the whole hotel look better, inside and out.",
		levels = { "Run-down", "Patched up", "Fresh paint", "Charming", "Grand" } },
	{ id = "ads", name = "Billboard Ads", icon = "star", max = 5, base = 400, grow = 2.6, stat = "arrivals", mul = 1.08,
		desc = "Put the hotel on billboards down the coast. Guests show up faster." },
	{ id = "rates", name = "Better Rates", icon = "cash", max = 5, base = 600, grow = 2.7, stat = "price", mul = 1.05,
		desc = "Nicer soap, softer towels, a higher bill. Every stay pays more." },
	{ id = "tips", name = "Tip Jar", icon = "cash", max = 5, base = 350, grow = 2.5, stat = "tips", mul = 1.1,
		desc = "A shiny jar on the desk and a smile. Guests tip more." },
	{ id = "comfort", name = "Comfy Lobby", icon = "hotel", max = 5, base = 450, grow = 2.5, stat = "patience", mul = 1.08,
		desc = "Fans, music and cold water. Guests wait longer before they give up." },
	{ id = "training", name = "Staff Training", icon = "staff", max = 5, base = 500, grow = 2.6, stat = "staffXP", mul = 1.15,
		desc = "Weekly lessons from the old manager. Staff level up faster." },
	{ id = "payroll", name = "Smart Payroll", icon = "staff", max = 5, base = 700, grow = 2.7, stat = "wages", mul = 0.96,
		desc = "Sort out the paperwork. Wages cost a little less." },
	{ id = "welcome", name = "Welcome Gifts", icon = "star", max = 5, base = 550, grow = 2.6, stat = "mood", add = 1,
		desc = "A shell and a sweet on every pillow. Guests start their stay happier." },
	{ id = "mats", name = "Doormats", icon = "clean", max = 5, base = 300, grow = 2.4, stat = "spills", mul = 0.85,
		desc = "Big mats at every door and a mop by the desk. Fewer spills in the lobby." },
}
U.BY = {}
for _, d in ipairs(U.LIST) do U.BY[d.id] = d end

-- what Aunt Marigold's old manager says as the hotel comes back to life
U.STORY = {
	"The boards are off the windows. Aunt Marigold would have cried. Happy tears, mostly.",
	"Fresh paint! The Seabreeze is white again, like in the old postcards.",
	"Flowers by the door. People are stopping on the promenade to look.",
	"Lamps, a red carpet... this is the hotel your aunt always dreamed of.",
}

-- round 22: finishes the owner can pick for free in the Upgrades tab (hotel attribute Style, JSON { key = id }).
-- ServerStorage.HotelSkin paints them. The third value is the colour of the button.
U.STYLE_DEFAULT = { lobby = "stone", rooms = "oak", walls = "white", roof = "terracotta" }
local rgb = Color3.fromRGB
local FLOORS = {
	{ "stone", "Sandstone", rgb(238, 228, 208) }, { "oak", "Oak planks", rgb(204, 160, 110) }, { "walnut", "Walnut planks", rgb(124, 88, 62) },
	{ "marble", "Checker marble", rgb(210, 226, 216) }, { "terracotta", "Terracotta tile", rgb(224, 140, 102) },
	{ "concrete", "Concrete", rgb(178, 180, 184) }, { "carpet", "Teal carpet", rgb(66, 112, 124) },
}
U.STYLES = {
	{ key = "lobby", name = "Lobby floor", list = FLOORS },
	{ key = "rooms", name = "Room floors", list = FLOORS },
	{ key = "walls", name = "Walls", list = {
		{ "white", "White", rgb(250, 246, 238) }, { "sand", "Sand", rgb(238, 224, 198) }, { "sage", "Sage", rgb(208, 222, 206) },
		{ "sky", "Sky", rgb(208, 226, 240) }, { "blush", "Blush", rgb(242, 216, 208) }, { "charcoal", "Charcoal", rgb(78, 82, 92) },
	} },
	{ key = "roof", name = "Roof", list = {
		{ "terracotta", "Terracotta tile", rgb(208, 110, 74) }, { "slate", "Slate", rgb(84, 92, 104) },
		{ "white", "White", rgb(238, 236, 230) }, { "copper", "Green copper", rgb(72, 146, 124) },
	} },
}
function U.style(hotel)
	local t = {}
	for k, v in pairs(U.STYLE_DEFAULT) do t[k] = v end
	local raw = hotel and hotel:GetAttribute("Style")
	if type(raw) == "string" and raw ~= "" then
		local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(d) == "table" then
			for _, g in ipairs(U.STYLES) do
				for _, e in ipairs(g.list) do
					if d[g.key] == e[1] then t[g.key] = e[1] end
				end
			end
		end
	end
	return t
end

function U.decode(raw)
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(t) == "table" and t or {}
end
function U.encode(t) return HttpService:JSONEncode(t) end
function U.levels(hotel) return U.decode(hotel and hotel:GetAttribute("Upgrades")) end
function U.level(hotel, id)
	local n = U.levels(hotel)[id]
	return type(n) == "number" and math.clamp(math.floor(n), 0, U.BY[id] and U.BY[id].max or 0) or 0
end
-- the price of the next level (nil at max)
function U.cost(def, level)
	if level >= def.max then return nil end
	return math.floor(def.base * def.grow ^ level / 50 + 0.5) * 50
end
-- "+16% guests" style text for a level
function U.effect(def, level)
	if def.add then return string.format("+%d mood", def.add * level) end
	local k = def.mul ^ level
	local pct = math.floor(math.abs(k - 1) * 100 + 0.5)
	local what = ({ arrivals = "guests", price = "income", tips = "tips", patience = "patience", staffXP = "staff XP", wages = "wages", spills = "spills" })[def.stat] or def.stat
	return (k >= 1 and "+" or "-") .. pct .. "% " .. what
end
-- folds every bought level into a Research totals table { mul = {}, add = {} }
function U.fold(hotel, c)
	local lv = U.levels(hotel)
	for _, d in ipairs(U.LIST) do
		local n = math.clamp(tonumber(lv[d.id]) or 0, 0, d.max)
		if n > 0 then
			if d.mul then c.mul[d.stat] = (c.mul[d.stat] or 1) * d.mul ^ n end
			if d.add then c.add[d.stat] = (c.add[d.stat] or 0) + d.add * n end
		end
	end
end
-- the hotel's look stage: 0 run-down, 1 patched, 2 fresh, 3 charming, 4 grand. Higher grades lift it too.
function U.look(hotel)
	local grade = hotel and hotel:GetAttribute("Grade") or 1
	return math.clamp(U.level(hotel, "curb") + math.max(0, grade - 1), 0, 4)
end

return U
