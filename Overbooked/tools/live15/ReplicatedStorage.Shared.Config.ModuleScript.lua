-- ReplicatedStorage.Shared.Config: shared numbers, art ids and the guest wardrobe.
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
	hammer = "rbxassetid://112862427856094", -- round 14: a rendered claw hammer (icon_hammer14.py)
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
	-- round 9 (ui_icons_r9.py)
	lamp = "rbxassetid://88901375027058",
	shapes = "rbxassetid://120412506302721",
	research = "rbxassetid://120303201851974",
	lock = "rbxassetid://108941414057788",
	copy = "rbxassetid://81577814037093",
	paint = "rbxassetid://133579562666541",
	up = "rbxassetid://76360191115103",
	down = "rbxassetid://101360760604264",
	grid = "rbxassetid://137744187577114",
	roof = "rbxassetid://117657850588764",
	search = "rbxassetid://97003619836666",
	clock = "rbxassetid://91716894765693",
	ev_baby = "rbxassetid://116404636832411",
	ev_access = "rbxassetid://106569248798304",
	ev_pet = "rbxassetid://110198067896990",
	ev_night = "rbxassetid://89157326612005",
	ev_party = "rbxassetid://87079306272629",
	ev_romance = "rbxassetid://113788979062485",
	ev_business = "rbxassetid://83669091316121",
	ev_inspector = "rbxassetid://132701163737708",
	ev_tour = "rbxassetid://71373269895702",
	ev_vip = "rbxassetid://70603539682280",
	ev_firstaid = "rbxassetid://86888030725196",
	ev_sick = "rbxassetid://86502508394108",
	gridPlate = "rbxassetid://96728197501656", -- 16x16 cells, fades out at the edge (build mode's grid)
	-- round 10 (ui_icons_r10.py)
	settings = "rbxassetid://132118302225821",
	stats = "rbxassetid://96688217689983",
	food = "rbxassetid://125741880200225",
	chef = "rbxassetid://107364444107804",
	medal = "rbxassetid://92402537107744",
	hotel = "rbxassetid://74108785610861",
	pot = "rbxassetid://114241891764932",
	-- round 10c (ui_icons_r10c.py)
	quest = "rbxassetid://111710464685413",
	trophy = "rbxassetid://83470636828231",
	chat = "rbxassetid://100298919005344",
	sun = "rbxassetid://91633200435244",
	cloudy = "rbxassetid://99878446960697",
	rain = "rbxassetid://103629554692297",
	snow = "rbxassetid://113928640219592",
	storm = "rbxassetid://135311986927089",
	gift = "rbxassetid://75789728395357",
	heart = "rbxassetid://140144886382920",
	angry = "rbxassetid://79867888724553",
	happy = "rbxassetid://138121478012531",
	plus = "rbxassetid://102339889424851",
	checkmark = "rbxassetid://130669270530599",
	phone = "rbxassetid://72714472375708",
	shop = "rbxassetid://100989855340066",
	run = "rbxassetid://73349023097265",
	-- round 11 (ui_icons_r11.py)
	wrench = "rbxassetid://115357896806209",
	suitcase = "rbxassetid://127741794920219",
	teddy = "rbxassetid://84389179917609",
	spark = "rbxassetid://80293140623482",
	grade = "rbxassetid://133028730989541",
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
C.SAVE_SLOTS = 1 -- round 10: one save per player (the title screen has a single Play)
C.BASE_ROOMS = 3 -- rooms every hotel starts with (saves list only the wings bought after them)

-- guest timings (seconds)
C.ARRIVE_EVERY = { 9, 16 }
C.FIRST_ARRIVAL = 4
C.QUEUE_MAX = 6
C.QUEUE_GAP = 3.2 -- studs between guests in the line outside
C.PED_EVERY = { 1.5, 4 } -- seconds between sidewalk pedestrians
C.PED_MAX = 20 -- pedestrians strolling at once (a busy street)
C.PED_BASE = 0.2 -- chance a passer-by turns in at 1 star (x1.6 while a room is free)
C.PED_PER_STAR = 0.08 -- added chance per hotel star
C.WALKIN_GAP = 4 -- seconds between walk-ins at one hotel
C.CROWD = 56 -- round 10d: was 76 (performance). People on the sidewalks by day (about half at night), gathered round the players
C.PATIENCE = 75 -- waiting outside before they give up
-- round 10: quicker desk and shorter stays, so rooms free up sooner and the line outside moves
C.CHECK_IN = 1.5
C.CHECK_OUT = 1.2
C.CLERK_SLOW = 4 -- round 13: a receptionist takes this many times longer than the desk numbers above (6 s to check in)
C.ACTIVITY = {
	Toilet = { 6, 9 },
	Shower = { 8, 11 },
	Bed = { 24, 34 }, -- round 10e: guests stay longer
	Wander = { 4, 8 },
}
-- round 10e: staff wages are paid every game day at dawn (C.STAFF[i].wage per person); research takes longer
C.RESEARCH_TIME_MUL = 3
-- what a stay is worth to a guest: (room stars + lobby extras - STAY_PAR) * STAY_MOOD lands on their mood at check-out
C.STAY_PAR = 4
C.STAY_MOOD = 8
C.WALK_SPEED = 11

-- the game day (one day/night cycle for the whole map; DayNight + Shared.Clock, round 9)
C.CYCLE = 420 -- real seconds per game day (round 10e: was 900)
C.DAY_SHARE = 0.68 -- share of the cycle spent between DAWN and DUSK (long days, quick nights)
C.DAWN = 5.8 -- ClockTime a cycle starts at (day summaries fire here)
C.DUSK = 20.2
C.DAY_START_HOUR = 8.5 -- the clock when a server starts
C.NIGHT_FROM = 19.6 -- night (lamps on, fewer walk-ins) from this hour...
C.NIGHT_TO = 6.2 -- ...to this one
C.NIGHT_TRAFFIC = 0.35 -- walk-in chance multiplier at night

-- the calendar (round 19): game days per month; 12 months and 4 seasons a year
C.DAYS_PER_MONTH = 3 -- a month passes every 3 game days, a season every 9 (~1 hour of play)

-- cleaning
C.CLEAN_HOLD = 1.1
C.TASKS = { "Bed", "Shower", "Toilet", "Floor" }
C.TASK_ICON = { Bed = "bed", Shower = "shower", Toilet = "toilet", Floor = "clean" }
-- cleaning minigames: the client plays, the server only trusts completions that
-- took at least MIN seconds and arrived before the session expired
C.MINIGAME_MIN = 1.5
C.MINIGAME_TIMEOUT = 120
C.DESK_GAME_MIN = 1.2 -- a front desk minigame can't be finished faster than this
-- the kitchen (round 10c): what guests order. items = the three ingredients the Cook minigame asks for;
-- pan = what sizzles in the pan (the doneness meter)
C.DISHES = {
	{ id = "burger", name = "Cheeseburger", price = 18, items = { "bun", "patty", "cheese" }, pan = "patty" },
	{ id = "omelette", name = "Omelette", price = 14, items = { "egg", "cheese", "pepper" }, pan = "egg" },
	{ id = "pancakes", name = "Pancakes", price = 12, items = { "flour", "egg", "berries" }, pan = "batter" },
	{ id = "steak", name = "Steak and Veg", price = 26, items = { "steak", "carrot", "broccoli" }, pan = "steak" },
	{ id = "pasta", name = "Tomato Pasta", price = 16, items = { "pasta", "tomato", "basil" }, pan = "sauce" },
}
C.MEAL_WAIT = 75 -- seconds a guest waits at the counter for their plate
C.COOK_SECS = 16 -- round 13: was 9.
-- seconds a Cook spends at the stove per dish
C.MINIGAME_PAR = { Floor = 14, Bed = 13, Shower = 12, Toilet = 11 } -- seconds for three stars (and a small XP bonus)

-- staff you hire in build mode (Staff tab). Hotel attribute `attr` = how many are hired; prices[n] is the n-th hire
-- round 10: several of each. More receptionists check guests in faster, more doormen open the door sooner
C.STAFF = {
	{ id = "janitor", name = "Janitor", attr = "Janitors", icon = "janitor", max = 6, prices = { 1200, 2200, 3400, 4800, 6500, 8500 }, wage = 45, blurb = "Cleans dirty rooms" },
	{ id = "doorman", name = "Doorman", attr = "Doormen", icon = "doorman", max = 2, prices = { 2000, 4500 }, wage = 55, blurb = "Lets guests in" },
	{ id = "receptionist", name = "Receptionist", attr = "Receptionists", icon = "guest", max = 3, prices = { 900, 2600, 5200 }, wage = 50, blurb = "Checks guests in and out" },
	{ id = "cook", name = "Cook", attr = "Cooks", icon = "chef", max = 3, prices = { 1800, 4000, 7000 }, wage = 60, blurb = "Cooks meals for guests" },
	{ id = "handyman", name = "Handyman", attr = "Handymen", icon = "wrench", max = 2, prices = { 2600, 5600 }, wage = 55, blurb = "Fixes broken things" },
}
C.STAFF_CLEAN = 6.5 -- round 13: was 2.6.
-- seconds a janitor spends on each cleaning job
C.STAFF_WALK = 13
C.DOORMAN_DELAY = 3 -- round 13: was 0.6 (instant).
C.DOORMAN_WORK = 6 -- round 13: seconds the doorman spends greeting a guest and taking their bags (after walking out to them)
-- a guest waits this long before the doorman lets them in (shared by the doormen)

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
	63690008, 376548738, 451221329, 451220849, 16630147, 80922374, 20573078, 62724852, 26658141, 48474294, 398673196,
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
	run = "rbxassetid://507767714", -- round 10: blended with walk by speed, like a default Roblox character
	sit = "rbxassetid://2506281703",
	-- round 14: wave, cheer and point are hand-keyed now (Shared.NPCAnimLib); the rest stay Roblox emotes
	-- round 10e: the default Roblox emotes, for playing with the fun items
	laugh = "rbxassetid://507770818",
	dance = "rbxassetid://507771019",
}

C.LINES = {
	arrive = { "Do you have a room?", "One night please!", "Heard this place is nice.", "Finally, a bed!", "Knock knock!",
		"My feet are killing me.", "A friend said this place is great.", "Long drive. I need a nap.", "Is this the place?", "I booked online. I think." },
	wait = { "Still waiting...", "Is anyone there?", "Hellooo?", "I can't wait to see my room!", "Any minute now...",
		"Should've called ahead.", "This line better be worth it.", "I hope they have pillows." },
	checkin = { "Hi! One room please.", "Booking for one!", "Here's my card.", "Room with a view, please!", "Just the one night." },
	room = { "Ooh, nice room!", "Cozy!", "Love the plants.", "This bed looks comfy.", "Better than the photos!",
		"Smells fresh in here.", "Where's the remote?", "I'm never leaving." },
	checkout = { "Great stay, thanks!", "I'll be back!", "Five stars!", "Slept like a baby.", "Telling all my friends!", "Best night's sleep in ages." },
	angry = { "Too slow. I'm leaving!", "Forget this place.", "No rooms? Ugh.", "I'll try across the street.", "Unbelievable." },
	lobby = { "What a lovely lobby!", "Nice decor in here.", "Check out this plant!", "So cozy in here.", "This place has style.", "Ooh, fancy!",
		"Who picked these colours? Love it.", "I need a lamp like that.", "Comfy sofa!" },
	chat = { "Lovely weather today!", "How's your stay?", "Nice hotel, right?", "Have you tried the pillows?", "Great place, isn't it?", "Enjoying your visit?", "Cheers!",
		"Where are you from?", "Did you see the pinball?", "I'm here for a wedding.", "The staff are so nice.", "Is the food any good?" },
}

-- round 10c: guest moods, door knocks, talking and reviews
C.MOOD_START = { 46, 60 } -- a new guest's mood (0..100); reviews are mood / 20 stars
C.LET_IN_SECS = 25 -- how long a guest's door stays open after "Come in!"
C.DND_CHANCE = 0.15 -- guests who hang a Do Not Disturb sign for their stay (round 10e: was 0.3)
C.MOOD_WORDS = { { 85, "Delighted" }, { 70, "Happy" }, { 50, "Okay" }, { 30, "Unhappy" }, { 0, "Furious" } }
C.KNOCK = {
	sleep = { "Zzz... huh?! I was SLEEPING!", "It's the middle of the night!", "Let me sleep, please!" },
	dnd = { "Can't you read the sign?!", "Do NOT disturb. It's on the door!", "Not now. The sign says it all." },
	again = { "Stop knocking!", "Seriously? Again?", "I heard you the first time!" },
	yes = { "Come in!", "It's open, come on in!", "Oh, hello! Come in.", "Sure, come in!" },
	no = { "Not right now, thanks!", "I'm busy, sorry!", "Can you come back later?", "Just a minute... actually, no." },
}
C.TALK = {
	hi = {
		"Oh, hi there!", "Hello!", "Hey! You work here?", "Good to see you!", "Hi! Lovely place.",
		"Oh! Hello again.", "Hey, boss person!", "Well, this looks promising.", "Hi! I've heard good things.",
		"Good morning! Or... afternoon? I just woke up.", "Hi there! Cute lobby.", "Hello! Do you have a minute?",
		"Hey! My friend recommended this place.", "Hi! Big day ahead.", "Oh good, someone who works here!",
	},
	-- round 10e: what a guest opens with depends on what they're doing
	hiQueue = {
		"Are we nearly in?", "How long's the wait?", "Do you have rooms left?", "Is it always this busy?", "My bags are heavy...",
		"Is the line moving?", "I've been standing here forever.", "Any chance of skipping ahead? No? Fair.",
		"Do you do discounts for patience?", "My feet are killing me.", "The queue's longer than my drive here.",
		"Should I come back later?", "Wow, popular place!", "I nearly walked past with this line.",
	},
	hiRoom = {
		"Just settling in!", "Love the room!", "Is the minibar free?", "Can I get extra towels?", "I'm about to take a nap.",
		"The bed is heavenly.", "That view! Amazing.", "Best shower I've had in years.", "I could get used to this.",
		"Room service works already? Impressive.", "The wifi is fast. I'm staying forever.", "I love the little soaps.",
		"It's so quiet up here.", "I took the best nap of my life.", "Housekeeping was just here, spotless!",
	},
	hiNight = {
		"It's late, I'm off to bed.", "Shh, people are sleeping!", "Night owl, are you?", "Yawn... long day.",
		"Don't mind me, just getting some water.", "The town looks so pretty at night.", "I shouldn't be up this late...",
		"One more episode and I'll sleep. Probably.", "The hall lights are so cosy.", "Late check-in, early flight. Story of my life.",
	},
	hiLeaving = {
		"Heading home now!", "Checking out, sadly.", "Already leaving. Time flies!", "Thanks for having me!",
		"I'll be back, guaranteed.", "Don't forget me!", "Say, which way's the station?", "Keep a room free for me next month.",
		"This stay went too fast.", "Checking out with a smile. That's rare!",
	},
	hiGrumpy = {
		"What do you want?", "Not in the mood.", "This place needs work.", "I want to speak to the manager. Oh. It's you.",
		"Hmph.", "Do I look happy to you?", "Fix the wifi first, chat later.", "I've written down my complaints. All of them.",
		"Let me guess: 'how's my stay'. Take a guess.", "This is not what the photos showed.", "I've stayed in better. Much better.",
	},
	hiCouple = {
		"We're on our honeymoon!", "Our anniversary trip!", "We needed a weekend away.", "My partner picked this place.",
		"First trip just the two of us!", "We got engaged last month!", "He proposed right outside. Right there!",
		"Ten years married, still travelling.", "We're eloping. Don't tell anyone.", "The babysitter's gone, we're free!",
	},
	hiBags = {
		"Where do I drop my bags?", "Is there a porter?", "I overpacked. Again.",
		"These bags weigh a ton.", "I brought everything. Help.", "Carry-on only. I'm proud of myself.",
		"Careful, the big one's souvenirs.", "Is there a luggage cart anywhere?",
	},
	nice = {
		"Aw, thank you!", "You're so kind!", "Thanks, I will!", "What great service!",
		"That's sweet of you.", "You've made my day!", "I'll remember this place because of you.",
		"You're good at this, you know.", "Five stars. Right now. Done.",
	},
	niceAgain = {
		"Yes... you said that.", "Thanks again, I guess.", "Okay, okay, I'm enjoying it!",
		"You really like me, huh?", "Save some compliments for the other guests!",
	},
	allSet = {
		"Nothing, I'm all set!", "No thanks, everything's great.", "I'm fine, thank you!",
		"All good here!", "Just enjoying the calm.", "Honestly? I'm pampered enough.",
		"Nothing yet. Ask me at breakfast!",
	},
	bye = { "Bye!", "See you around!", "Take care!", "Catch you later!", "Thanks again, bye!", "Off I go!" },
	stayGood = {
		"Loving it here!", "Best hotel on the street.", "I could stay forever.",
		"Ten out of ten. No notes.", "I already left you a glowing review.", "I've told everyone back home about this place.",
		"The little touches make all the difference.", "I slept like a rock. A happy rock.",
	},
	stayOk = {
		"It's fine. Nothing special yet.", "Not bad so far.", "It's okay, I suppose.",
		"Decent. Room for improvement.", "I've had nicer, but this'll do.", "Ask me again after breakfast.",
		"It's... a hotel. It works.",
	},
	stayBad = {
		"Honestly? Not great.", "I've had better stays.", "I'm not impressed.",
		"I'm checking the reviews I read. They lied.", "There were ants. ANTS.", "The room was cold all night.",
		"I'd rather sleep in my car. Almost.", "Don't ask. You don't want to know.",
	},
	-- the weather outside, right now (Shared attribute Weather)
	hiWeather = {
		clear = { "Gorgeous day out there!", "Not a cloud in the sky!", "Perfect weather for a stroll.", "You picked a great day to run a hotel!" },
		cloudy = { "Looks like rain later, maybe.", "Grey old day, isn't it?", "Cozy weather, honestly.", "The clouds match the lobby. I like it." },
		fog = { "I could barely see the road!", "Spooky fog out there.", "I felt like I was in a mystery novel on the way here.", "Is the whole town always this foggy?" },
		rain = { "Made it before the downpour!", "I'm drenched. Towels?", "Rain's good for the plants, I guess.", "Perfect napping weather, honestly." },
		storm = { "That thunder shook my windows!", "I'm not going back out in THAT.", "The storm knocked my plans sideways.", "Can you hear that rain on the roof? Lovely." },
		snow = { "It's snowing! I love snow!", "I built a tiny snowman outside. His name's Gerald.", "The whole street looks like a postcard.", "Brr! Crank the heating, would you?" },
	},
	-- guests passing the time: little remarks about the hotel and town
	idleChatter = {
		"The coffee here beats the place across town.", "I heard the penthouse has a hot tub.", "Your staff work hard. Tell them I said so.",
		"That music is stuck in my head now.", "I keep getting lost in these hallways. In a nice way.",
		"Somebody's cooking something amazing.", "The lobby plants are so healthy looking!",
		"I read three brochures by the door. Very informative.",
	},
}
-- round 10e: what guests think out loud during a stay
C.THOUGHTS = {
	"I should call home.", "I should try the pinball.", "I should grab a snack.", "I should really unpack...",
	"I wonder what's for breakfast.", "I should go for a walk.", "Is it check-out already?", "This pillow is perfect.",
	"I should leave a good review.", "I should come back next year.", "I should take a selfie.", "I could live here.",
	"Did I lock the car? ...I took a train. I'm fine.", "The towels here are softer than mine at home.",
	"I should try that fancy shower.", "A nap. A nap is what I need.", "This is way nicer than the photos online.",
	"I wonder if they do room service.", "My feet could use a rest.", "I should text my sister about this place.",
	"One more coffee won't hurt.", "The hallway smells like fresh flowers.", "I should've booked an extra night.",
	"Nobody knows where I am. It's wonderful.", "I could get used to this bed.", "Is that music coming from downstairs?",
	"I should check out the arcade downstairs.", "This is the best pillow fort foundation ever.",
}
-- the opening of a review, by stars (the guest's biggest reason follows it)
C.REVIEW_OPEN = {
	[1] = { "Awful stay.", "Never again.", "Terrible." },
	[2] = { "Disappointing.", "Not worth it.", "Meh." },
	[3] = { "It was okay.", "Decent enough.", "Average stay." },
	[4] = { "Really nice stay!", "Lovely hotel.", "Would come back." },
	[5] = { "Perfect stay!", "Absolutely wonderful!", "Best hotel in town!" },
}

return C
