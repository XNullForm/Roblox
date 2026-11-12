-- ReplicatedStorage.Shared.Looks: what NPCs look like and how they walk (round 9).
-- Round 10c: the user wants plain Roblox looks: Roblox's own classic shirts and pants, Roblox hair and Roblox
-- faces, and no other accessories (no hats, glasses, scarves or layered clothing). Every id below was checked
-- with MarketplaceService on 2026-11-03: creator Roblox, the right asset type.
-- Looks.description(rng, kind?) -> HumanoidDescription; Looks.walkStyle(rng, kind?) -> style table.
-- kind: nil (anyone), "elder", "kid", "business", "party", "parent" (guest events pick a matching look).
local Looks = {}

Looks.FIRST = {
	"Emily", "James", "Ryan", "Olivia", "Adam", "Mia", "Lucas", "Sofia", "Noah", "Ava", "Ethan", "Chloe", "Leo", "Grace", "Mason",
	"Lily", "Owen", "Zoe", "Eric", "Hannah", "Liam", "Ella", "Jack", "Ruby", "Theo", "Nora", "Max", "Ivy", "Sam", "Maya", "Ben",
	"Aria", "Kai", "Luna", "Finn", "Rosa", "Oscar", "Isla", "Hugo", "Freya", "Arlo", "Elsie", "Felix", "Poppy", "Jude", "Willow",
	"Ezra", "Hazel", "Miles", "Clara", "Rowan", "Iris", "Jasper", "Daisy", "Silas", "Mabel", "Otis", "Violet", "Beau", "Stella",
	"Ari", "Nina", "Omar", "Leila", "Ravi", "Priya", "Kenji", "Yuki", "Mateo", "Lucia", "Diego", "Elena", "Tariq", "Amira", "Kofi",
	"Ama", "Sven", "Astrid", "Lars", "Ingrid", "Pablo", "Carmen", "Marco", "Giulia", "Hiro", "Mei", "Chen", "Lin", "Dev", "Anika",
	"Kwame", "Zara", "Malik", "Sana", "Ivan", "Olga", "Nico", "Alba", "Rafael", "Inês", "Dmitri", "Katya", "Jonah", "Tess", "Reid",
	"Quinn", "Blake", "Sage", "River", "Skye", "Dylan", "Harper", "Logan", "Avery", "Parker", "Riley", "Jordan", "Casey", "Morgan",
	"Wes", "June", "Abe", "Maeve", "Cole", "Fern", "Gus", "Olive", "Hank", "Pearl", "Walt", "Edna", "Frank", "Dot", "Harold", "Bea",
	"Lionel", "Marigold", "Percy", "Winnie", "Stan", "Lorraine", "Vince", "Gloria", "Bruno", "Agnes", "Calvin", "Opal", "Duke", "Ruth",
	"Zeke", "Tilly", "Archie", "Nell", "Ozzy", "Lulu", "Rocco", "Gigi", "Taj", "Noor", "Emeka", "Ada", "Bao", "Thu", "Arjun", "Diya",
}
Looks.LAST = {
	"Smith", "Garcia", "Chen", "Patel", "Kim", "Nguyen", "Johnson", "Silva", "Müller", "Rossi", "Okafor", "Haddad", "Novak", "Larsen",
	"Tanaka", "Lopez", "Brown", "Wilson", "Moreau", "Kowalski", "Singh", "Ali", "Cohen", "Murphy", "O'Brien", "Dubois", "Ivanova",
	"Costa", "Mendes", "Park", "Wright", "Hughes", "Baker", "Turner", "Price", "Bennett", "Hayes", "Reyes", "Flores", "Sato",
}

-- classic clothing (always worn underneath so nobody shows up blank)
Looks.SHIRTS = {
	144076358, 607785314, 398633584, 144076436, 398634295, 3670737444, 382538059, 398635081, 382537702, 382537085, 382538295,
	4047884939, 4047884046, 4047886060, 301807898, 301809497, 301810204, 855768342, 855776103, 855778084, 855779323, 855777286,
	855766176, 129458686,
}
Looks.PANTS = {
	144076760, 398634487, 398633812, 398635338, 382537806, 129459077, 382538503, 382537569, 129458426, 382537950, 7231091126,
	301810602, 301811027, 301811432, 855781078, 855781508, 855783877, 855784936, 855785499, 855782781,
}
Looks.HAIR = {
	2956239660, 63690008, 451221329, 1103003368, 16630147, 376526888, 376524487, 376548738, 376527350, 451220849, 13745548, 14815761,
	553722174, 398673196, 727320877, 191101707, 323476364, 17877340, 398672920, 456225312, 1708329071, 11913660, 20573078, 76059443,
	13476917, 29952810, 398673423, 417457139, 1772372988, 293316608, 15913837, 3814474927, 233615637, 878922157, 212967757, 221175027,
	295456068, 32278814, 3185830268, 564449640, 2588168421, 15469944, 3814476174, 1360044714, 2042026822, 846803597, 24939052,
	439984886, 430063008, 387255459, 156486009, 77359955, 376809157, 62246484, 20372960, 417457909, 17424092, 19327469, 638100095,
	365632597, 1180432690, 7193442167, 145310635, 185812332, 20010032, 1744033107, 26658141, 80921949, 1513252656, 1033117580, 24910539,
	376805560, 25517576, 164482409, 6993754725, 169444294, 553917533, 64082730, 7193448258, 151786902, 727320511, 398672568,
	8760841633, 293316132, 553892446, 3814450142, 188003563, 9244111257, 2566043868, 283748528, 1191145114, 248286896, 3814496544,
	2934014598, 835065519, 15913848, 553859958, 168167316, 9174355709, 835065199, 185812297, 376806770, 13477818, 121390915, 9243987340,
	154818848, 158066100, 2606178351, 1213432315, 212961935, 164482468, 241671246, 564451259, 2804642677, 77799954, 80922251, 161246757,
	20980138, 301818464, 301818806, 301819154, 301819935, 13655562, 48474294, 80922374, 62724852,
}
-- Roblox faces (0 = the default smile)
Looks.FACES = { 0, 0, 144075659, 7074786, 7074764, 7074814, 7074729, 7074836, 7074893, 7074944, 7075142, 7075434, 7076224, 7131361,
	7317773, 7699174, 8329679, 9250660, 12145366, 7506136, 7699193, 8560971, 15432080 }
Looks.SKIN = {
	Color3.fromRGB(255, 224, 196), Color3.fromRGB(246, 204, 168), Color3.fromRGB(234, 184, 140), Color3.fromRGB(214, 160, 116),
	Color3.fromRGB(186, 128, 88), Color3.fromRGB(150, 98, 66), Color3.fromRGB(118, 74, 50), Color3.fromRGB(92, 58, 40),
}

-- walk styles. Round 10: the user wants every NPC on Roblox's own default walk ("just use the robloxian walk
-- animation for all of the npcs"), so there is one style. Elders keep a slower pace on the same animation.
Looks.WALKS = {
	{ id = "default", walk = 507777826, idle = 507766666, weight = 1, speed = 1 },
}
local ELDER = { id = "default", walk = 507777826, idle = 507766666, weight = 1, speed = 0.8 }

local function pick(rng, t) return t[rng:NextInteger(1, #t)] end

-- Roblox's own R15 Animate blend: its walk is made for 8 studs/s and its run for 16. Below 8 only the walk plays
-- (slowed down), from 8 to 16 the two cross-fade at normal speed, above 16 only the run plays (sped up).
-- -> walk weight, run weight, walk speed, run speed
Looks.RUN_ANIM = 507767714
function Looks.moveBlend(speed)
	local r = speed / 16
	if r <= 0.5 then return 1, 0.0001, r / 0.5, 1 end
	if r < 1 then
		local f = (r - 0.5) / 0.5
		return 1 - f, f, 1, 1
	end
	return 0.0001, 1, 1, r
end

function Looks.walkStyle(rng, kind)
	if kind == "elder" then return ELDER end
	return Looks.WALKS[1]
end

function Looks.name(rng)
	return pick(rng, Looks.FIRST)
end

-- round 14 (2026-11-09): friendly faces only, natural hair (no neon, fire or galaxy), and part-built gear
-- (straw hats, caps, beanies, bucket hats, fedoras, sunglasses, backpacks, crossbody bags) made by Bodies.dress.
Looks.FACES = { 144075659, 144075659, 7074786, 7074764, 7074729, 7075434, 7699174, 12145366, 15432080, 86487700, 209995366,
	209995366, 616380929, 25321961, 7317773 }
Looks.HAIR = {
	2956239660, 63690008, 16630147, 376526888, 376524487, 376548738, 376527350, 13745548, 398673196, 17877340, 398672920,
	1708329071, 11913660, 20573078, 13476917, 29952810, 417457139, 1772372988, 15913837, 3814474927, 233615637, 212967757,
	221175027, 295456068, 1360044714, 2042026822, 62246484, 20372960, 7193442167, 185812332, 20010032, 26658141, 80921949,
	1513252656, 25517576, 6993754725, 553917533, 7193448258, 3814450142, 188003563, 9244111257, 3814496544, 835065519,
	9174355709, 835065199, 376806770, 13477818, 9243987340, 212961935, 164482468, 77799954, 80922251, 301818464, 301818806,
	301819154, 301819935, 13655562, 48474294, 80922374, 62724852, 3814476174, 8760841633, 1103003368,
}
Looks.ELDER_HAIR = { 15913848, 24939052, 15913848, 80922251, 62724852, 13477818 }

-- gear: Looks.gear(rng, kind) -> { hat = id?, hatColor, bandColor, glasses = bool, bag = "backpack"|"cross"|nil, bagColor }
Looks.HAT_W = { straw = 4, cap = 4, beanie = 3, bucket = 2, fedora = 2 }
Looks.HAT_COLORS = {
	cap = { Color3.fromRGB(196, 52, 46), Color3.fromRGB(38, 70, 140), Color3.fromRGB(46, 120, 74), Color3.fromRGB(240, 236, 226), Color3.fromRGB(34, 34, 40), Color3.fromRGB(232, 168, 48) },
	beanie = { Color3.fromRGB(176, 58, 52), Color3.fromRGB(60, 84, 128), Color3.fromRGB(216, 196, 160), Color3.fromRGB(86, 120, 82), Color3.fromRGB(230, 140, 60), Color3.fromRGB(70, 66, 70) },
	bucket = { Color3.fromRGB(214, 200, 168), Color3.fromRGB(120, 140, 96), Color3.fromRGB(70, 92, 140), Color3.fromRGB(236, 226, 206) },
	fedora = { Color3.fromRGB(86, 64, 48), Color3.fromRGB(54, 54, 60), Color3.fromRGB(150, 128, 100), Color3.fromRGB(196, 180, 150) },
	straw = { Color3.fromRGB(226, 194, 126), Color3.fromRGB(214, 180, 112), Color3.fromRGB(232, 206, 150) },
}
Looks.BAND_COLORS = { Color3.fromRGB(190, 40, 44), Color3.fromRGB(40, 52, 96), Color3.fromRGB(30, 30, 34), Color3.fromRGB(70, 120, 80) }
Looks.BAG_COLORS = { Color3.fromRGB(58, 62, 74), Color3.fromRGB(140, 92, 56), Color3.fromRGB(176, 64, 56), Color3.fromRGB(64, 96, 150),
	Color3.fromRGB(92, 120, 80), Color3.fromRGB(222, 206, 180), Color3.fromRGB(110, 70, 120) }
local function wpick(rng, w)
	local tot = 0
	for _, v in pairs(w) do tot += v end
	local r = rng:NextNumber() * tot
	for k, v in pairs(w) do r -= v if r <= 0 then return k end end
	return next(w)
end
function Looks.gear(rng, kind)
	local g = {}
	local hatChance = kind == "business" and 0.3 or kind == "party" and 0.2 or kind == "elder" and 0.6 or 0.42
	if rng:NextNumber() < hatChance then
		local w = Looks.HAT_W
		if kind == "business" then w = { fedora = 1 } elseif kind == "kid" then w = { cap = 3, beanie = 2, bucket = 1 }
		elseif kind == "elder" then w = { straw = 2, fedora = 2, bucket = 2, beanie = 1 } end
		g.hat = wpick(rng, w)
		local cols = Looks.HAT_COLORS[g.hat]
		g.hatColor = cols[rng:NextInteger(1, #cols)]
		g.bandColor = Looks.BAND_COLORS[rng:NextInteger(1, #Looks.BAND_COLORS)]
	end
	g.glasses = rng:NextNumber() < (kind == "elder" and 0.3 or 0.12)
	local bagChance = kind == "kid" and 0.55 or kind == "business" and 0.35 or 0.38
	if rng:NextNumber() < bagChance then
		g.bag = (kind == "kid" or rng:NextNumber() < 0.5) and "backpack" or "cross"
		if kind == "business" then g.bag = "cross" end
		g.bagColor = Looks.BAG_COLORS[rng:NextInteger(1, #Looks.BAG_COLORS)]
	end
	return g
end

function Looks.description(rng, kind)
	local d = Instance.new("HumanoidDescription")
	d.Shirt = pick(rng, Looks.SHIRTS)
	d.Pants = pick(rng, Looks.PANTS)
	-- hair is the only catalog accessory (nearly everyone has some); hats and bags are part-built (Bodies.dress)
	if rng:NextNumber() < 0.95 then d.HairAccessory = tostring(pick(rng, kind == "elder" and rng:NextNumber() < 0.6 and Looks.ELDER_HAIR or Looks.HAIR)) end
	local face = pick(rng, Looks.FACES)
	if face > 0 then d.Face = face end
	local skin = pick(rng, Looks.SKIN)
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin
	local h = rng:NextNumber(0.9, 1.08)
	if kind == "kid" then h = rng:NextNumber(0.62, 0.74) end
	if kind == "elder" then h = rng:NextNumber(0.88, 0.98) end
	d.HeightScale = h
	d.WidthScale = rng:NextNumber(0.86, 1.06)
	d.DepthScale = d.WidthScale
	d.HeadScale = 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	return d
end

return Looks
