-- ReplicatedStorage.RAH.Config: shared numbers, art ids and the guest wardrobe.
local C = {}

C.ICONS = {
	bed = "rbxassetid://139797865495740",
	roomReady = "rbxassetid://87205670019133",
	roomBusy = "rbxassetid://104824386342205",
	roomDirty = "rbxassetid://128634316374763",
	shower = "rbxassetid://72349562514766",
	toilet = "rbxassetid://83331021644321",
	bell = "rbxassetid://136771114946336",
	cash = "rbxassetid://104865372157448",
	clean = "rbxassetid://114712473446788",
	sparkle = "rbxassetid://131174599344316",
	door = "rbxassetid://100945771493486",
	walk = "rbxassetid://79334673170155",
	star = "rbxassetid://78432499198183",
	guest = "rbxassetid://93367548270418",
	sleep = "rbxassetid://113835708407052",
	hammer = "rbxassetid://98094162580991",
	catAll = "rbxassetid://71710667458090",
	catFurniture = "rbxassetid://106476234219954",
	catDecor = "rbxassetid://74883026471570",
	catFun = "rbxassetid://82029092862292",
	rotate = "rbxassetid://125894486704316",
	move = "rbxassetid://101460190173180",
	sell = "rbxassetid://119107352689347",
	close = "rbxassetid://95430694735997",
	place = "rbxassetid://130320308762635",
	janitor = "rbxassetid://133479283599894",
	doorman = "rbxassetid://115807621012167",
	staff = "rbxassetid://100162627766867",
	roomDeluxe = "rbxassetid://110427200645504",
	roomSuite = "rbxassetid://126288617831860",
	starEmpty = "rbxassetid://97586159620240",
	upgrade = "rbxassetid://132834940139170",
	coop = "rbxassetid://107039478256997",
}

-- money
C.START_CASH = 300
C.ROOM_PRICE = 40 -- paid at check-out
-- rooms you can buy in build mode, in order: each one adds a wing (room + more lobby) on side 1 = east, -1 = west
C.ROOM_SLOTS = {
	{ id = 104, side = 1, k = 1, price = 400 },
	{ id = 105, side = -1, k = 1, price = 800 },
	{ id = 106, side = 1, k = 2, price = 1500 },
	{ id = 107, side = -1, k = 2, price = 2400 },
}
C.TIP = { 0, 18 } -- random extra
-- room upgrades (round 7): room model attribute Tier = 1..3. bonus = extra per stay, tip = tip multiplier,
-- price = cost to reach this tier. Stars = tier + 1 for appeal >= STAR_APPEAL[1] + 1 for appeal >= STAR_APPEAL[2] (max 5)
C.ROOM_TIERS = {
	{ name = "Standard", bonus = 0, tip = 1, icon = "bed" },
	{ name = "Deluxe", bonus = 25, tip = 1.25, price = 500, icon = "roomDeluxe" },
	{ name = "Suite", bonus = 60, tip = 1.6, price = 1400, icon = "roomSuite" },
}
C.STAR_APPEAL = { 8, 20 }
C.STAR_ARRIVALS = 0.12 -- each hotel star above 1 makes guests come this much sooner
C.BUNDLE_VALUE = 20 -- one cash bundle on the pile per this much
-- offline earnings: the hotel keeps making money while the owner is away
C.OFFLINE_TURNOVER = 14 -- room stays per hour at full pace
C.OFFLINE_SHARE = 0.5 -- offline earns this share of the live pace
C.OFFLINE_MAX_HOURS = 24 -- hours away that count
C.SAVE_SLOTS = 3 -- save files per player (the main menu picks one)

-- guest timings (seconds)
C.ARRIVE_EVERY = { 9, 16 }
C.FIRST_ARRIVAL = 4
C.QUEUE_MAX = 6
C.PED_EVERY = { 1.5, 4 } -- seconds between sidewalk pedestrians
C.PED_MAX = 20 -- pedestrians strolling at once (a busy street)
C.PED_BASE = 0.05 -- chance a passer-by becomes a guest at 1 star
C.PED_PER_STAR = 0.11 -- added chance per hotel star (5 stars = 50%)
C.PATIENCE = 75 -- waiting outside before they give up
C.CHECK_IN = 2.5
C.CHECK_OUT = 2
C.ACTIVITY = {
	Toilet = { 6, 8 },
	Shower = { 8, 11 },
	Bed = { 16, 22 },
	Wander = { 3, 5 },
}
C.WALK_SPEED = 11

-- the game day (one day/night cycle for the whole map; RAH_DayNight)
C.DAY_LENGTH = 480 -- seconds per game day
C.DAY_START = 7 -- ClockTime the day begins at (summaries fire at rollover)
C.NIGHT = { 19, 6.5 } -- night falls between these ClockTime hours
C.NIGHT_TRAFFIC = 0.35 -- walk-in chance multiplier at night

-- cleaning
C.CLEAN_HOLD = 1.1
C.TASKS = { "Bed", "Shower", "Toilet", "Floor" }
C.TASK_ICON = { Bed = "bed", Shower = "shower", Toilet = "toilet", Floor = "clean" }
-- cleaning minigames: the client plays, the server only trusts completions that
-- took at least MIN seconds and arrived before the session expired
C.MINIGAME_MIN = 1.5
C.MINIGAME_TIMEOUT = 60

-- staff you hire in build mode (Staff tab). Hotel attribute `attr` = how many are hired; prices[n] is the n-th hire
C.STAFF = {
	{ id = "janitor", name = "Janitor", attr = "Janitors", icon = "janitor", max = 3, prices = { 350, 750, 1200 }, blurb = "Cleans dirty rooms" },
	{ id = "doorman", name = "Doorman", attr = "Doormen", icon = "doorman", max = 1, prices = { 600 }, blurb = "Lets guests in" },
	{ id = "receptionist", name = "Receptionist", attr = "Receptionists", icon = "guest", max = 1, prices = { 250 }, blurb = "Greets guests at the desk" },
}
C.STAFF_CLEAN = 2.6 -- seconds a janitor spends on each cleaning job
C.STAFF_WALK = 13
C.DOORMAN_DELAY = 1.5 -- a guest waits this long before the doorman lets them in

-- guest look (Roblox catalog items)
C.NAMES = {
	"Emily", "James", "Ryan", "Olivia", "Adam", "Mia", "Lucas", "Sofia", "Noah", "Ava", "Ethan", "Chloe",
	"Leo", "Grace", "Mason", "Lily", "Owen", "Zoe", "Eric", "Hannah", "Liam", "Ella", "Jack", "Ruby",
	"Theo", "Nora", "Max", "Ivy", "Sam", "Maya", "Ben", "Aria", "Kai", "Luna", "Finn", "Rosa",
}
C.SHIRTS = {
	382538059, 144076358, 398633584, 4047884046, 144076436, 382538295, 382537702, 4047884939,
	855777286, 855766176, 607785314, 398635081,
	301807898, 301809497, 301810204, -- Serena / Casey / Oakley outfit shirts
	855768342, 855776103, 855778084, 855779323, -- Roblox orange / red / teal / yellow shirts
	6553199, 58608768, 129458686, -- Golden Shirt of Bling Bling / RoGo jacket / Bricksmith
}
C.PANTS = {
	382537569, 144076760, 398633812, 382538503, 382537806, 382537950, 855782781, 398635338, 398634487,
	301810602, 301811027, 301811432, -- Serena / Casey / Oakley outfit pants
	855781078, 855781508, 855783877, 855784936, 855785499, -- Roblox colored shorts
	6553208, 3372792, -- Golden Pants of Bling Bling / black jeans
}
C.HAIR = {
	63690008, 376548738, 451221329, 451220849, 16630147, 62234425, 80922374, 20573078, 62724852, 26658141, 48474294, 398673196,
	13655562, 301818464, 301818806, 301819154, 301819935, -- Brooding Black / Lin / Serena / Casey / Oakley
	376524487, 376526888, 376527350, -- Blonde Spiked / Straight Blonde / Black Ponytail
	93843948443802, -- Short Messy Wolfcut (red)
}
C.HATS = { 48474313, 1028606, 607702162, 607700713, 4047554959 }
C.FACES = { 144075659, 7074786, 7074764, 7074814 } -- Smile / Check It / Chill / Existential Angst
C.SKIN = {
	Color3.fromRGB(255, 220, 186), Color3.fromRGB(241, 194, 150), Color3.fromRGB(224, 172, 128),
	Color3.fromRGB(198, 140, 96), Color3.fromRGB(160, 104, 70), Color3.fromRGB(116, 74, 50), Color3.fromRGB(255, 204, 170),
}

-- R15 animations (Roblox's own)
C.ANIM = {
	idle = "rbxassetid://507766666",
	idle2 = "rbxassetid://507766951",
	walk = "rbxassetid://507777826",
	sit = "rbxassetid://2506281703",
	wave = "rbxassetid://507770239",
	cheer = "rbxassetid://507770677",
}

C.LINES = {
	arrive = { "Do you have a room?", "One night please!", "Heard this place is nice.", "Finally, a bed!", "Knock knock!" },
	wait = { "Still waiting...", "Is anyone there?", "Hellooo?", "I can't wait to see my room!" },
	checkin = { "Hi! One room please.", "Booking for one!", "Here's my card." },
	room = { "Ooh, nice room!", "Cozy!", "Love the plants.", "This bed looks comfy." },
	checkout = { "Great stay, thanks!", "I'll be back!", "Five stars!", "Slept like a baby." },
	angry = { "Too slow. I'm leaving!", "Forget this place.", "No rooms? Ugh." },
	lobby = { "What a lovely lobby!", "Nice decor in here.", "Check out this plant!", "So cozy in here.", "This place has style.", "Ooh, fancy!" },
	chat = { "Lovely weather today!", "How's your stay?", "Nice hotel, right?", "Have you tried the pillows?", "Great place, isn't it?", "Enjoying your visit?", "Cheers!" },
}

return C
