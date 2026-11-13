-- ServerStorage.GuestEvents: special guests (round 9). HotelSim asks roll() when a guest arrives;
-- an event guest gets a look (props welded to the body), wants something in their room, does an extra
-- activity during the stay and pays more when the hotel had what they needed (less when it didn't).
-- Most events are unlocked by research (Shared.Research node with event = id); `gate` names the node.
-- ctx (built by HotelSim per hotel): HOTEL, PLACED, rng, walkTo, status, timed, say, faceTo, play, stop, sfx, tell.
local RS = game:GetService("ReplicatedStorage")
local C = require(RS.Shared.Config)
local Catalog = require(RS.Shared.Catalog)
local Research = require(RS.Shared.Research)
local Levels = require(RS.Shared.Levels)

local E = {}

E.CHANCE = 0.32 -- share of arrivals that are special, once any event is unlocked

-- need: a Catalog tag the guest wants. where: "room" (their room) or "any" (their room or the lobby).
-- pay: multiplier when the need is met (unmet pays MISS).
E.MISS = 0.6
E.DEFS = {
	baby = {
		gate = "ev_family", weight = 10, icon = "ev_baby", label = "Family with a baby",
		need = "baby", where = "room", pay = 1.35, missing = "a crib",
		arrive = "arrived with a baby", act = "Rocking the baby", actIcon = "ev_baby", secs = { 6, 9 },
		lines = { "Shh, the baby's asleep.", "Do you have a crib?", "Long trip with this one!" },
		happy = { "The crib was perfect!", "Baby slept all night!" },
		sad = { "No crib? We barely slept.", "The baby cried all night..." },
	},
	access = {
		gate = "ev_access", weight = 10, icon = "ev_access", label = "Guest with access needs",
		need = "access", where = "room", pay = 1.35, missing = "a shower chair or grab bar", slow = 0.7,
		arrive = "needs an accessible room", act = "Getting settled", actIcon = "ev_access", secs = { 5, 7 },
		lines = { "Is the room easy to get around?", "I hope there's a grab bar." },
		happy = { "Everything was easy to reach!", "So thoughtful, thank you!" },
		sad = { "The bathroom was hard to use.", "Not very accessible..." },
	},
	pet = {
		gate = "ev_pets", weight = 9, icon = "ev_pet", label = "Guest with a dog",
		need = "pet", where = "room", pay = 1.4, missing = "a pet bed",
		arrive = "brought their dog", act = "Settling the dog", actIcon = "ev_pet", secs = { 5, 7 },
		lines = { "Say hi, Biscuit!", "He's very well behaved.", "Are dogs allowed?" },
		happy = { "Biscuit loved the pet bed!", "Best dog-friendly hotel!" },
		sad = { "Nowhere for the dog to sleep.", "Biscuit slept on my feet..." },
	},
	allnighter = {
		gate = "ev_night", weight = 8, nightWeight = 22, icon = "ev_night", label = "Night owl",
		need = "tv", need2 = "snack", where = "any", pay = 1.5, missing = "a TV and a snack spot", noBed = true,
		arrive = "wants to stay up all night", act = "Watching TV", actIcon = "ev_night", secs = { 12, 16 },
		lines = { "Who needs sleep?", "Any late-night TV?", "I'm a night person." },
		happy = { "What a night!", "Best all-nighter ever." },
		sad = { "So boring. No TV, no snacks.", "Nothing to do all night..." },
	},
	birthday = {
		gate = "ev_party", weight = 8, icon = "ev_party", label = "Birthday guest",
		need = "party", where = "room", pay = 1.6, missing = "a party kit",
		arrive = "is here for their birthday", act = "Party time!", actIcon = "ev_party", secs = { 8, 10 },
		lines = { "It's my birthday!", "Party in my room tonight!", "Guess who's a year older?" },
		happy = { "Best birthday ever!", "What a party!" },
		sad = { "No party stuff? Sad birthday.", "Not much of a party..." },
	},
	business = {
		gate = "rooms2", weight = 9, icon = "ev_business", label = "Business traveller",
		need = "work", where = "room", pay = 1.5, missing = "a work desk",
		arrive = "is on a work trip", act = "Working late", actIcon = "ev_business", secs = { 8, 11 },
		lines = { "Big meeting tomorrow.", "Is there a desk in the room?", "Just here for work." },
		happy = { "Got so much done!", "I'll book here again." },
		sad = { "No desk. Worked on the bed.", "Hard to work in there." },
	},
	honeymoon = {
		gate = "ev_romance", weight = 6, icon = "ev_romance", label = "Newlyweds",
		need = "romance", where = "room", pay = 2, missing = "a champagne bucket",
		arrive = "just got married", act = "Champagne toast", actIcon = "ev_romance", secs = { 7, 9 },
		lines = { "We just got married!", "Our honeymoon starts here!", "Something special, please." },
		happy = { "So romantic!", "A perfect honeymoon night." },
		sad = { "Not very romantic...", "We expected more." },
	},
	sick = {
		gate = "safety", weight = 6, icon = "ev_sick", label = "Guest feeling unwell",
		need = "firstaid", where = "any", pay = 1.2, missing = "a first-aid kit",
		arrive = "isn't feeling well", act = "Using the first-aid kit", actIcon = "ev_firstaid", secs = { 4, 6 },
		lines = { "I don't feel so good...", "Is there a first-aid kit?", "Achoo!" },
		happy = { "Feeling much better now!", "Thanks for the first aid." },
		sad = { "No first aid? I'm going home.", "I feel worse..." },
	},
	inspector = {
		gate = "ev_inspector", weight = 4, icon = "ev_inspector", label = "Hotel inspector",
		arrive = "is here to inspect the hotel", act = "Inspecting", actIcon = "ev_inspector",
		lines = { "Hotel inspection.", "Let's see how you run things.", "Clipboard ready." },
	},
	tour = {
		gate = "ev_tour", weight = 4, icon = "ev_tour", label = "Tour group", pay = 1.25,
		arrive = "arrived with a tour group", act = "Taking photos", actIcon = "ev_tour", secs = { 4, 6 },
		lines = { "Smile for the photo!", "What a view!", "Stay with the group!" },
		happy = { "Great stop on the tour!", "Five stars from the group!" },
	},
	celebrity = {
		gate = "ev_vip", weight = 3, icon = "ev_vip", label = "Celebrity",
		minStars = 4, pay = 3, missing = "a 4-star room", miss = 1,
		arrive = "is staying at your hotel!", act = "Posing for photos", actIcon = "ev_vip", secs = { 5, 7 },
		lines = { "No photos, please.", "I only stay in the best.", "Is this the famous hotel?" },
		happy = { "Stunning! I'll tell everyone.", "Simply fabulous." },
		sad = { "Hmm. I've seen better.", "Not quite star quality." },
	},
	-- round 37: guests for the fun stuff. `feature` names a Levels.FEATURE: they come from that level, no research.
	-- Nice-to-haves, so a miss only costs 15% (miss = 0.85).
	backpacker = {
		feature = "guest_backpacker", weight = 9, icon = "walk", label = "Backpacker",
		need = "snack", where = "any", pay = 1.25, missing = "a snack machine", miss = 0.85,
		arrive = "is backpacking round the world", act = "Snack run", actIcon = "food", secs = { 4, 6 },
		lines = { "Cheapest room you've got!", "Just passing through.", "Anything to eat round here?" },
		happy = { "Snacks AND a bed? Five stars.", "Fuelled up for tomorrow!" },
		sad = { "Not even a vending machine...", "Went to bed hungry." },
	},
	fitness = {
		feature = "guest_fitness", weight = 8, icon = "run", label = "Fitness fan",
		need = "gym", where = "any", pay = 1.4, missing = "a treadmill", miss = 0.85,
		arrive = "never skips a workout", act = "Working out", actIcon = "run", secs = { 7, 10 },
		lines = { "Where's the gym?", "Gotta hit my steps!", "Leg day tomorrow." },
		happy = { "Great workout!", "New personal best!" },
		sad = { "No gym? Push-ups on the floor, then.", "There goes my streak." },
	},
	gamer = {
		feature = "guest_gamer", weight = 8, icon = "catFun", label = "Gamer",
		need = "play", where = "any", pay = 1.4, missing = "games to play", miss = 0.85,
		arrive = "came here to play", act = "Going for the high score", actIcon = "catFun", secs = { 7, 10 },
		lines = { "Got any games here?", "I'm on a winning streak.", "Just one more round!" },
		happy = { "NEW HIGH SCORE!", "GG! Best hotel ever." },
		sad = { "Nothing to play. So bored.", "Zero fun. Literally zero." },
	},
	spa = {
		feature = "guest_spa", weight = 6, icon = "shower", label = "Spa lover",
		need = "bath", where = "any", pay = 1.7, missing = "a bathtub or hot tub", miss = 0.85,
		arrive = "is here to relax", act = "A long hot soak", actIcon = "shower", secs = { 8, 11 },
		lines = { "I need to unwind.", "Is there a hot tub?", "Total relaxation, please." },
		happy = { "Ahh, I feel brand new.", "So relaxing!" },
		sad = { "No bath? Not relaxing at all.", "I'm still so tense..." },
	},
}
-- round 15: star guests. Named people, one at a time, from the Town Hotel grade or level 6. A cutscene plays as
-- they walk up (client Cutscene), they take the best room, and they pay well (plus a gift) when it's good enough.
E.STAR_CHANCE = 0.07
E.STAR_GAP = 300
E.DEFS.rockstar = {
	star = true, who = "Jett Vega", title = "Rock star on a world tour", icon = "ev_party", label = "Star guest: rock star",
	minStars = 3, pay = 3.5, miss = 1.2, gift = 800,
	arrive = "the rock star, just pulled up!", act = "Shredding a guitar solo", actIcon = "ev_party", secs = { 7, 9 },
	lines = { "Is this where the after-party is?", "Keep it down? Never heard of it.", "One night, one show, one hotel." },
	happy = { "Rock on! Best stop on the tour.", "I'm writing a song about this place." },
	sad = { "This room is not rock and roll.", "My roadies had better rooms." },
}
E.DEFS.royal = {
	star = true, who = "Duchess Wilhelmina", title = "Royalty, travelling quietly", icon = "ev_vip", label = "Star guest: royalty",
	minStars = 4, pay = 5, miss = 1, gift = 1500,
	arrive = "the Duchess, has arrived!", act = "Taking afternoon tea", actIcon = "ev_vip", secs = { 6, 8 },
	lines = { "One would like your finest room.", "Do curtsy, darling. Only joking.", "The palace is being repainted." },
	happy = { "Simply splendid. One is delighted.", "Fit for a queen. Well, a duchess." },
	sad = { "One has slept in better stables.", "How very... ordinary." },
}
E.DEFS.critic = {
	star = true, who = "Margaux Fontaine", title = "The city's toughest critic", icon = "ev_inspector", label = "Star guest: critic",
	minStars = 3, pay = 3, miss = 0.8, gift = 600,
	arrive = "the famous critic, is here. Impress her!", act = "Taking notes", actIcon = "ev_inspector", secs = { 6, 8 },
	lines = { "I'll be writing about this.", "Hmm. Interesting choice of carpet.", "Don't mind me. Just observing." },
	happy = { "Five stars. Write that down.", "I was ready to hate it. I don't." },
	sad = { "This will make a short review.", "Disappointing. Truly." },
}
E.DEFS.mystery = {
	star = true, who = "Mystery Guest", title = "Who is that in the trench coat?", icon = "ev_inspector", label = "Star guest: mystery guest",
	pay = 2.5, miss = 1, gift = 1200,
	arrive = "slipped in. Nobody knows who they are...", act = "Peeking around", actIcon = "ev_inspector", secs = { 5, 7 },
	lines = { "I'm nobody. Just a regular guest.", "You didn't see me.", "Nice place. Very... normal." },
	happy = { "I'm the secret reviewer. You passed!", "Surprise! Hotel Weekly. Top marks." },
	sad = { "I'm the secret reviewer. Not great.", "Hotel Weekly will hear about this." },
}
E.DEFS.tycoon = {
	star = true, who = "Sir Reginald Goldworth", title = "Owns forty hotels. Wants yours?", icon = "ev_business", label = "Star guest: tycoon",
	minStars = 4, pay = 6, miss = 1, gift = 2500,
	arrive = "the hotel tycoon, is checking you out!", act = "Counting his money", actIcon = "ev_business", secs = { 6, 8 },
	lines = { "I own forty hotels, you know.", "Show me what you've built, kid.", "Time is money. Chop chop." },
	happy = { "You've got a real business here.", "I'd invest. Here's a little something." },
	sad = { "Amateur hour.", "I'd have knocked this one down." },
}
for id, d in pairs(E.DEFS) do d.id = id end

-- inspector: what they grade
E.INSPECT = { safety = 2, lobbyAppeal = 18, stars = 3, reward = 500, boost = 600 }

---------------------------------------------------------------- picking

local function unlocked(hotel, d)
	if d.feature then return Levels.featureOk(hotel, d.feature) end
	return Research.has(hotel, d.gate)
end

function E.anyUnlocked(hotel)
	for _, d in pairs(E.DEFS) do
		if not d.star and unlocked(hotel, d) then return true end
	end
	return false
end

-- an arriving guest: which event (or nil)
function E.roll(hotel, rng)
	-- Studio test hook: hotel attribute TestEvent = an event id forces the next arrival
	local forced = hotel:GetAttribute("TestEvent") -- round 20: also set by the /event commands
	if forced and E.DEFS[forced] then
		hotel:SetAttribute("TestEvent", nil)
		return E.DEFS[forced]
	end
	-- round 15: a star guest now and then (never two close together)
	do
		local okG, gr = pcall(function() return require(RS.Shared.Grades).of(hotel) end)
		local okL, lv = pcall(function() return require(RS.Shared.Levels).of(hotel) end)
		local ready = (okG and (gr or 1) >= 2) or (okL and (lv or 1) >= 6)
		if ready and os.clock() - (hotel:GetAttribute("StarAt") or -1e9) > E.STAR_GAP and rng:NextNumber() < E.STAR_CHANCE then
			local list = {}
			for _, d in pairs(E.DEFS) do
				if d.star then table.insert(list, d) end
			end
			table.sort(list, function(a, b) return a.id < b.id end)
			hotel:SetAttribute("StarAt", os.clock())
			return list[rng:NextInteger(1, #list)]
		end
	end
	-- round 11: from grade 3 (City Hotel) VIPs visit without the research, and from grade 4 they pay more
	local Grades = require(RS.Shared.Grades)
	local g = Grades.of(hotel)
	if rng:NextNumber() < Grades.vipChance(g) then
		local vip = table.clone(E.DEFS.celebrity)
		vip.pay = vip.pay * (1 + 0.25 * (g - 3))
		return vip
	end
	if rng:NextNumber() > E.CHANCE then return nil end
	local night = RS.Shared:GetAttribute("Night")
	local total, list = 0, {}
	for _, d in pairs(E.DEFS) do
		if not d.star and unlocked(hotel, d) then
			local w = night and d.nightWeight or d.weight
			total += w
			table.insert(list, { d, w })
		end
	end
	if total <= 0 then return nil end
	local r = rng:NextNumber() * total
	for _, e in ipairs(list) do
		r -= e[2]
		if r <= 0 then return e[1] end
	end
	return list[#list][1]
end

---------------------------------------------------------------- what's where

local function hasTag(m, tag)
	local id = m:GetAttribute("Item")
	if tag == "firstaid" then return id == "FirstAid" end
	return Catalog.hasTag(id, tag)
end

-- placed items with this tag in a zone ("Lobby" or a room model's name)
function E.items(placed, zone, tag)
	local out = {}
	for _, m in ipairs(placed:GetChildren()) do
		if m:GetAttribute("Zone") == zone and hasTag(m, tag) then table.insert(out, m) end
	end
	return out
end

-- the nearest thing a guest can use for `tag`, by the event's rules
function E.find(ctx, d, room, tag)
	local list = E.items(ctx.PLACED, room.model.Name, tag)
	if #list == 0 and d.where == "any" then list = E.items(ctx.PLACED, "Lobby", tag) end
	return list[1]
end

-- is this room (and lobby, when allowed) good enough for the event?
function E.roomOK(ctx, d, room)
	if d.minStars then return (room.model:GetAttribute("Stars") or 1) >= d.minStars end
	if not d.need then return true end
	if not E.find(ctx, d, room, d.need) then return false end
	if d.need2 and not E.find(ctx, d, room, d.need2) then return false end
	return true
end

-- how many event items a room holds (plain guests take the plainest room, keeping special ones free)
local SPECIAL = { "baby", "access", "pet", "party", "romance", "work" }
function E.special(placed, zone)
	local n = 0
	for _, m in ipairs(placed:GetChildren()) do
		if m:GetAttribute("Zone") == zone then
			for _, t in ipairs(SPECIAL) do
				if hasTag(m, t) then n += 1 break end
			end
		end
	end
	return n
end

-- of the ready rooms, the one this guest would pick (the first that meets the need, best stars for VIPs)
function E.pickRoom(ctx, d, ready)
	if #ready == 0 then return nil end
	if not d then
		local best, bestN = ready[1], math.huge
		for _, r in ipairs(ready) do
			local n = E.special(ctx.PLACED, r.model.Name)
			if n < bestN then best, bestN = r, n end
		end
		return best
	end
	if d.minStars then
		table.sort(ready, function(a, b) return (a.model:GetAttribute("Stars") or 1) > (b.model:GetAttribute("Stars") or 1) end)
		return ready[1]
	end
	for _, r in ipairs(ready) do
		if E.roomOK(ctx, d, r) then return r end
	end
	return ready[1]
end

---------------------------------------------------------------- looks

local function part(model, size, color, mat, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0
	w.Parent = b
	return w
end

-- a prop model: parts placed relative to a root part, the root welded to a body part
local function prop(g, name, bodyPart, offset, build)
	local bp = g.model:FindFirstChild(bodyPart)
	if not bp then return end
	local m = Instance.new("Model")
	m.Name = "EventProp_" .. name
	local root = part(m, Vector3.new(0.1, 0.1, 0.1), Color3.new(), nil)
	root.Transparency = 1
	m.PrimaryPart = root
	build(m, function(size, color, cf, mat, shape)
		local p = part(m, size, color, mat, shape)
		weld(root, p, cf)
		return p
	end)
	weld(bp, root, offset)
	m.Parent = g.model
	return m
end

local GRIP = CFrame.new(0, -0.35, -0.15) -- just under the right hand's palm

-- a balloon on a string, tied to the left hand
local function balloon(g, col)
	local hand = g.model:FindFirstChild("LeftHand")
	if not hand then return end
	local b = prop(g, "Balloon", "LeftHand", CFrame.new(0, 3.4, 0), function(m, add)
		add(Vector3.new(1.2, 1.4, 1.2), col, CFrame.new(), Enum.Material.Glass, Enum.PartType.Ball).Name = "Ball"
	end)
	local ball = b and b:FindFirstChild("Ball")
	if not ball then return end
	ball.Transparency = 0.08
	local a0 = Instance.new("Attachment", hand)
	local a1 = Instance.new("Attachment", ball)
	a1.Position = Vector3.new(0, -0.68, 0)
	local str = Instance.new("RopeConstraint")
	str.Attachment0, str.Attachment1 = a0, a1
	str.Length = 3
	str.Visible = true
	str.Thickness = 0.03
	str.Color = BrickColor.new("Institutional white")
	str.Parent = b
end

local LOOKS = {}
LOOKS.baby = function(g)
	-- a baby carrier: a padded basket with a sleeping baby under a blanket, held by its handle
	prop(g, "Carrier", "RightHand", GRIP * CFrame.new(0, -0.85, 0), function(m, add)
		add(Vector3.new(0.9, 0.7, 1.5), Color3.fromRGB(196, 214, 236), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.74, 0.12, 1.3), Color3.fromRGB(250, 250, 252), CFrame.new(0, 0.38, 0.1), Enum.Material.Fabric)
		add(Vector3.new(0.5, 0.5, 0.5), Color3.fromRGB(246, 212, 186), CFrame.new(0, 0.48, -0.45), nil, Enum.PartType.Ball)
		add(Vector3.new(0.08, 0.08, 1.3), Color3.fromRGB(150, 160, 180), CFrame.new(0, 0.85, 0), Enum.Material.Metal)
		add(Vector3.new(0.08, 0.6, 0.08), Color3.fromRGB(150, 160, 180), CFrame.new(0, 0.55, 0.64), Enum.Material.Metal)
		add(Vector3.new(0.08, 0.6, 0.08), Color3.fromRGB(150, 160, 180), CFrame.new(0, 0.55, -0.64), Enum.Material.Metal)
	end)
end
LOOKS.access = function(g)
	-- a walking cane with a crook handle; they walk a little slower
	prop(g, "Cane", "RightHand", GRIP, function(m, add)
		add(Vector3.new(2.6, 0.14, 0.14), Color3.fromRGB(70, 46, 32), CFrame.new(0, -1.2, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Wood, Enum.PartType.Cylinder)
		add(Vector3.new(0.16, 0.16, 0.5), Color3.fromRGB(70, 46, 32), CFrame.new(0, 0.08, -0.1), Enum.Material.Wood)
		add(Vector3.new(0.2, 0.12, 0.2), Color3.fromRGB(40, 40, 44), CFrame.new(0, -2.5, 0.1), Enum.Material.Rubber)
	end)
	g.hum.WalkSpeed *= E.DEFS.access.slow
	g.model:SetAttribute("WalkSpeedMul", (g.baseMul or 1) * E.DEFS.access.slow)
end
LOOKS.pet = function(g)
	-- a little dog trotting at their side, on a leash
	local root = g.root
	local hip = g.hum.HipHeight + root.Size.Y / 2
	local coat = ({ Color3.fromRGB(196, 150, 96), Color3.fromRGB(240, 236, 226), Color3.fromRGB(60, 50, 44), Color3.fromRGB(150, 96, 60) })[math.random(1, 4)]
	local dark = coat:Lerp(Color3.new(0, 0, 0), 0.35)
	local dog = prop(g, "Dog", "HumanoidRootPart", CFrame.new(1.9, -hip + 0.95, -0.8), function(m, add)
		add(Vector3.new(0.8, 0.7, 1.5), coat, CFrame.new(0, 0, 0), Enum.Material.Fabric)
		add(Vector3.new(0.7, 0.66, 0.7), coat, CFrame.new(0, 0.42, -0.86), Enum.Material.Fabric)
		add(Vector3.new(0.42, 0.32, 0.4), coat:Lerp(Color3.new(1, 1, 1), 0.3), CFrame.new(0, 0.3, -1.3), Enum.Material.Fabric)
		add(Vector3.new(0.16, 0.14, 0.12), Color3.fromRGB(30, 26, 26), CFrame.new(0, 0.4, -1.5))
		add(Vector3.new(0.12, 0.12, 0.06), Color3.fromRGB(20, 20, 24), CFrame.new(0.18, 0.56, -1.22))
		add(Vector3.new(0.12, 0.12, 0.06), Color3.fromRGB(20, 20, 24), CFrame.new(-0.18, 0.56, -1.22))
		add(Vector3.new(0.18, 0.4, 0.3), dark, CFrame.new(0.36, 0.62, -0.8) * CFrame.Angles(0, 0, math.rad(-20)), Enum.Material.Fabric)
		add(Vector3.new(0.18, 0.4, 0.3), dark, CFrame.new(-0.36, 0.62, -0.8) * CFrame.Angles(0, 0, math.rad(20)), Enum.Material.Fabric)
		for _, x in ipairs({ -0.26, 0.26 }) do
			for _, z in ipairs({ -0.5, 0.5 }) do
				add(Vector3.new(0.22, 0.6, 0.22), coat, CFrame.new(x, -0.55, z), Enum.Material.Fabric)
			end
		end
		add(Vector3.new(0.14, 0.14, 0.6), coat, CFrame.new(0, 0.32, 0.86) * CFrame.Angles(math.rad(-40), 0, 0), Enum.Material.Fabric)
		local collar = add(Vector3.new(0.74, 0.14, 0.12), Color3.fromRGB(220, 60, 70), CFrame.new(0, 0.3, -0.56))
		collar.Name = "Collar"
	end)
	if dog then
		dog:SetAttribute("Bob", true) -- Client bobs it while the owner walks
		local hand = g.model:FindFirstChild("LeftHand")
		local collar = dog:FindFirstChild("Collar")
		if hand and collar then
			local a0 = Instance.new("Attachment", hand)
			a0.Position = Vector3.new(0, -0.3, 0)
			local a1 = Instance.new("Attachment", collar)
			local rope = Instance.new("RopeConstraint")
			rope.Attachment0 = a0
			rope.Attachment1 = a1
			rope.Length = 3.4
			rope.Visible = true
			rope.Thickness = 0.06
			rope.Color = BrickColor.new("Really red")
			rope.Parent = dog
		end
	end
end
LOOKS.allnighter = function(g)
	-- a big takeaway coffee
	prop(g, "Coffee", "RightHand", GRIP, function(m, add)
		add(Vector3.new(0.7, 0.42, 0.42), Color3.fromRGB(250, 248, 244), CFrame.new(0, -0.05, -0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		add(Vector3.new(0.3, 0.44, 0.44), Color3.fromRGB(150, 96, 60), CFrame.new(0, -0.05, -0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.08, 0.46, 0.46), Color3.fromRGB(40, 36, 36), CFrame.new(0, 0.32, -0.1) * CFrame.Angles(0, 0, math.rad(90)), nil, Enum.PartType.Cylinder)
	end)
end
LOOKS.birthday = function(g)
	-- a striped party hat and a balloon on a string
	prop(g, "Hat", "Head", CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(8)), function(m, add)
		local cols = { Color3.fromRGB(255, 92, 140), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 200, 255) }
		for i = 1, 5 do
			local r = 0.75 - i * 0.13
			add(Vector3.new(0.18, r, r), cols[(i - 1) % 3 + 1], CFrame.new(0, (i - 1) * 0.17, 0) * CFrame.Angles(0, 0, math.rad(90)), nil, Enum.PartType.Cylinder)
		end
		add(Vector3.new(0.2, 0.2, 0.2), Color3.fromRGB(255, 255, 255), CFrame.new(0, 0.9, 0), Enum.Material.Fabric, Enum.PartType.Ball)
	end)
	balloon(g, ({ Color3.fromRGB(255, 80, 120), Color3.fromRGB(110, 190, 255), Color3.fromRGB(255, 200, 60) })[math.random(1, 3)])
end
LOOKS.business = function(g)
	-- a leather briefcase
	prop(g, "Briefcase", "RightHand", GRIP * CFrame.new(0, -0.55, 0), function(m, add)
		add(Vector3.new(0.4, 1, 1.5), Color3.fromRGB(70, 44, 30), CFrame.new(), Enum.Material.Leather)
		add(Vector3.new(0.44, 0.08, 1.54), Color3.fromRGB(196, 160, 90), CFrame.new(0, 0.3, 0), Enum.Material.Metal)
		add(Vector3.new(0.12, 0.3, 0.5), Color3.fromRGB(50, 32, 22), CFrame.new(0, 0.6, 0), Enum.Material.Leather)
	end)
end
LOOKS.honeymoon = function(g)
	-- a red rose and a pink heart balloon
	prop(g, "Rose", "RightHand", GRIP, function(m, add)
		add(Vector3.new(0.08, 1.1, 0.08), Color3.fromRGB(60, 120, 60), CFrame.new(0, 0.2, -0.1))
		add(Vector3.new(0.36, 0.36, 0.36), Color3.fromRGB(210, 30, 60), CFrame.new(0, 0.8, -0.1), Enum.Material.Fabric, Enum.PartType.Ball)
	end)
	balloon(g, Color3.fromRGB(255, 120, 170))
end
LOOKS.sick = function(g)
	-- a scarf and a flushed face: a warm red scarf round the neck
	prop(g, "Scarf", "UpperTorso", CFrame.new(0, 0.85, 0), function(m, add)
		add(Vector3.new(0.4, 1.3, 1.3), Color3.fromRGB(180, 60, 60), CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.3, 0.9, 0.12), Color3.fromRGB(180, 60, 60), CFrame.new(0.25, -0.5, -0.6), Enum.Material.Fabric)
	end)
end
LOOKS.inspector = function(g)
	-- a clipboard with a checklist
	prop(g, "Clipboard", "LeftHand", CFrame.new(0, -0.4, -0.3) * CFrame.Angles(math.rad(-60), 0, 0), function(m, add)
		add(Vector3.new(0.9, 1.2, 0.06), Color3.fromRGB(140, 100, 64), CFrame.new(), Enum.Material.Wood)
		add(Vector3.new(0.8, 1, 0.02), Color3.fromRGB(250, 250, 246), CFrame.new(0, -0.05, -0.04))
		add(Vector3.new(0.4, 0.14, 0.1), Color3.fromRGB(180, 180, 190), CFrame.new(0, 0.58, -0.04), Enum.Material.Metal)
		for i = 0, 3 do
			add(Vector3.new(0.5, 0.04, 0.01), Color3.fromRGB(90, 96, 120), CFrame.new(0.05, 0.3 - i * 0.2, -0.055))
		end
	end)
	g.hum.WalkSpeed *= 0.85
end
LOOKS.tour = function(g)
	-- a camera on the chest and a sun hat
	prop(g, "Camera", "UpperTorso", CFrame.new(0, -0.1, -0.62), function(m, add)
		add(Vector3.new(0.8, 0.5, 0.3), Color3.fromRGB(30, 30, 34), CFrame.new(), Enum.Material.SmoothPlastic)
		add(Vector3.new(0.3, 0.32, 0.32), Color3.fromRGB(60, 64, 72), CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Glass, Enum.PartType.Cylinder)
		add(Vector3.new(0.18, 0.1, 0.1), Color3.fromRGB(230, 60, 60), CFrame.new(0.28, 0.27, 0))
	end)
	prop(g, "SunHat", "Head", CFrame.new(0, 0.62, 0), function(m, add)
		add(Vector3.new(0.08, 2.2, 2.2), Color3.fromRGB(236, 214, 160), CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.5, 1.15, 1.15), Color3.fromRGB(236, 214, 160), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.14, 1.18, 1.18), Color3.fromRGB(220, 90, 80), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
end
LOOKS.celebrity = function(g)
	-- dark sunglasses and a gold shimmer
	prop(g, "Shades", "Head", CFrame.new(0, 0.12, -0.6), function(m, add)
		add(Vector3.new(0.42, 0.26, 0.06), Color3.fromRGB(16, 16, 20), CFrame.new(-0.22, 0, 0), Enum.Material.Glass)
		add(Vector3.new(0.42, 0.26, 0.06), Color3.fromRGB(16, 16, 20), CFrame.new(0.22, 0, 0), Enum.Material.Glass)
		add(Vector3.new(1.1, 0.05, 0.05), Color3.fromRGB(220, 180, 90), CFrame.new(0, 0.1, 0), Enum.Material.Metal)
	end)
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Shimmer"
	sp.Texture = C.ICONS.sparkle
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.8, 1.2)
	sp.Rate = 4
	sp.Speed = NumberRange.new(0.5, 1.2)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 0.8
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sp.Parent = g.root
end

-- round 15: the star guests' looks
local function shimmer(g, col)
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Shimmer"
	sp.Texture = C.ICONS.sparkle
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.8, 1.2)
	sp.Rate = 3
	sp.Speed = NumberRange.new(0.4, 1)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 0.8
	sp.Color = ColorSequence.new(col)
	sp.Parent = g.model:FindFirstChild("UpperTorso") or g.root
end
local function shades(g, lens, frame)
	prop(g, "Shades", "Head", CFrame.new(0, 0.12, -0.62), function(m, add)
		for _, x in ipairs({ -0.22, 0.22 }) do
			-- each lens turns back a little at its outer edge so it follows the round face
			local turn = CFrame.Angles(0, -x * 0.6, 0)
			add(Vector3.new(0.4, 0.24, 0.06), lens, CFrame.new(x, 0, 0) * turn, Enum.Material.Glass).Transparency = 0.05
			add(Vector3.new(0.44, 0.04, 0.07), frame, CFrame.new(x, 0.12, 0) * turn, Enum.Material.Metal)
		end
		add(Vector3.new(0.12, 0.04, 0.05), frame, CFrame.new(0, 0.08, 0), Enum.Material.Metal)
		for _, x in ipairs({ -0.62, 0.62 }) do add(Vector3.new(0.04, 0.04, 0.6), frame, CFrame.new(x, 0.1, 0.3), Enum.Material.Metal) end
	end)
end
-- a coat over the torso: front panels, back, sides and a hem below the waist
local function coat(g, col, len, open, collar)
	local ut = g.model:FindFirstChild("UpperTorso")
	if not ut then return end
	local s = ut.Size
	prop(g, "Coat", "UpperTorso", CFrame.new(), function(m, add)
		local d = s.Z / 2 + 0.04
		if open then
			for _, x in ipairs({ -1, 1 }) do add(Vector3.new(s.X * 0.36, s.Y + 0.04, 0.08), col, CFrame.new(x * s.X * 0.33, 0, -d), Enum.Material.Fabric) end
		else
			add(Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), col, CFrame.new(0, 0, -d), Enum.Material.Fabric)
		end
		add(Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), col, CFrame.new(0, 0, d), Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do add(Vector3.new(0.08, s.Y + 0.04, s.Z + 0.16), col, CFrame.new(x * (s.X / 2 + 0.04), 0, 0), Enum.Material.Fabric) end
		if len > 0 then
			local y = -s.Y / 2 - len / 2 - 0.02
			add(Vector3.new(s.X + 0.1, len, 0.08), col, CFrame.new(0, y, d + 0.02), Enum.Material.Fabric)
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(s.X * 0.42, len, 0.08), col, CFrame.new(x * s.X * 0.3, y, -d - 0.02), Enum.Material.Fabric)
				add(Vector3.new(0.08, len, s.Z + 0.2), col, CFrame.new(x * (s.X / 2 + 0.06), y, 0), Enum.Material.Fabric)
			end
		end
		if collar then
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(0.34, 0.5, 0.1), collar, CFrame.new(x * 0.34, s.Y / 2 - 0.15, -d - 0.05) * CFrame.Angles(0, 0, x * math.rad(-24)), Enum.Material.Fabric)
			end
		end
	end)
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local a = g.model:FindFirstChild(n)
		if a then
			prop(g, "Sleeve", n, CFrame.new(), function(m, add)
				add(a.Size + Vector3.new(0.08, 0.02, 0.08), col, CFrame.new(), Enum.Material.Fabric)
			end)
		end
	end
end
-- a hat that sits on the head hides the hair under it (big hair poked through the beret and hats)
local function noHair(g)
	for _, a in ipairs(g.model:GetChildren()) do
		if a:IsA("Accessory") then
			local t = a.AccessoryType
			if t == Enum.AccessoryType.Hair or t == Enum.AccessoryType.Hat then
				local h = a:FindFirstChild("Handle")
				if h then h.Transparency = 1 end
			end
		end
	end
	for _, d in ipairs(g.model:GetChildren()) do
		if d.Name == "Gear" then d:Destroy() end
	end
	g.model:SetAttribute("Hat", nil)
end
-- round 37
LOOKS.backpacker = function(g)
	noHair(g)
	prop(g, "BucketHat", "Head", CFrame.new(0, 0.6, 0), function(m, add)
		local c = Color3.fromRGB(196, 170, 110)
		add(Vector3.new(0.08, 1.7, 1.7), c, CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.5, 1.25, 1.25), c, CFrame.new(0, 0.16, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
	prop(g, "Map", "LeftHand", CFrame.new(0, -0.35, -0.25) * CFrame.Angles(math.rad(-65), 0, 0), function(m, add)
		add(Vector3.new(1.1, 0.8, 0.04), Color3.fromRGB(236, 226, 196), CFrame.new())
		add(Vector3.new(0.5, 0.06, 0.05), Color3.fromRGB(80, 160, 90), CFrame.new(-0.2, 0.1, -0.01))
		add(Vector3.new(0.06, 0.5, 0.05), Color3.fromRGB(70, 130, 210), CFrame.new(0.25, -0.05, -0.01))
		add(Vector3.new(0.12, 0.12, 0.05), Color3.fromRGB(220, 60, 60), CFrame.new(0.1, 0.2, -0.02), nil, Enum.PartType.Ball)
	end)
end
LOOKS.fitness = function(g)
	local h = g.model:FindFirstChild("Head")
	if not h then return end
	local band = Color3.fromRGB(240, 70, 90)
	prop(g, "Headband", "Head", CFrame.new(0, h.Size.Y * 0.22, 0), function(m, add)
		local d = math.max(h.Size.X, h.Size.Z) + 0.08
		add(Vector3.new(0.22, d, d), band, CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
	for _, n in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local a = g.model:FindFirstChild(n)
		if a then
			prop(g, "Wristband", n, CFrame.new(0, -a.Size.Y / 2 + 0.16, 0), function(m, add)
				add(Vector3.new(a.Size.X + 0.08, 0.22, a.Size.Z + 0.08), band, CFrame.new(), Enum.Material.Fabric)
			end)
		end
	end
	local s = g.model.UpperTorso.Size
	prop(g, "Towel", "UpperTorso", CFrame.new(0, s.Y / 2 - 0.04, 0), function(m, add)
		local w = Color3.fromRGB(248, 248, 250)
		add(Vector3.new(s.X * 0.7, 0.16, s.Z + 0.16), w, CFrame.new(), Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do add(Vector3.new(0.26, 0.8, 0.06), w, CFrame.new(x * 0.26, -0.42, -s.Z / 2 - 0.1), Enum.Material.Fabric) end
	end)
end
LOOKS.gamer = function(g)
	local h = g.model:FindFirstChild("Head")
	if not h then return end
	local dark, glow = Color3.fromRGB(34, 34, 40), ({ Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 80, 200), Color3.fromRGB(120, 255, 120) })[math.random(1, 3)]
	prop(g, "Headphones", "Head", CFrame.new(), function(m, add)
		local R = h.Size.X / 2 + 0.1
		for k = -3, 3 do
			local a = math.rad(k * 25)
			add(Vector3.new(0.3, 0.12, 0.22), dark, CFrame.new(math.sin(a) * R, math.cos(a) * R + 0.05, 0) * CFrame.Angles(0, 0, -a))
		end
		for _, x in ipairs({ -1, 1 }) do
			add(Vector3.new(0.2, 0.55, 0.55), dark, CFrame.new(x * R, 0, 0), nil, Enum.PartType.Cylinder)
			add(Vector3.new(0.06, 0.38, 0.38), glow, CFrame.new(x * (R + 0.1), 0, 0), Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	end)
	coat(g, ({ Color3.fromRGB(60, 64, 90), Color3.fromRGB(110, 60, 140), Color3.fromRGB(40, 110, 90) })[math.random(1, 3)], 0.3, false)
end
LOOKS.spa = function(g)
	noHair(g)
	local robe = Color3.fromRGB(250, 250, 252)
	coat(g, robe, 1.3, false, Color3.fromRGB(236, 238, 244))
	prop(g, "Turban", "Head", CFrame.new(0, 0.5, 0.05), function(m, add)
		local c = Color3.fromRGB(176, 222, 226)
		add(Vector3.new(0.7, 1.3, 1.3), c, CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.9, 0.8, 0.9), c, CFrame.new(0, 0.34, 0.1), Enum.Material.Fabric, Enum.PartType.Ball)
	end)
	prop(g, "RobeBelt", "LowerTorso", CFrame.new(), function(m, add)
		local s = g.model.LowerTorso.Size
		add(Vector3.new(s.X + 0.24, 0.18, s.Z + 0.26), robe:Lerp(Color3.new(0.7, 0.7, 0.75), 0.3), CFrame.new(0, s.Y / 2 - 0.05, 0), Enum.Material.Fabric)
	end)
end
LOOKS.rockstar = function(g)
	shades(g, Color3.fromRGB(20, 20, 26), Color3.fromRGB(200, 204, 214))
	coat(g, Color3.fromRGB(26, 24, 28), 0, true, Color3.fromRGB(40, 38, 44))
	prop(g, "Studs", "UpperTorso", CFrame.new(), function(m, add)
		local s = g.model.UpperTorso.Size
		for i = 0, 5 do
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(0.09, 0.09, 0.09), Color3.fromRGB(214, 216, 224), CFrame.new(x * s.X * 0.18, s.Y * 0.42 - i * 0.24, -s.Z / 2 - 0.1), Enum.Material.Metal, Enum.PartType.Ball)
			end
		end
	end)
	shimmer(g, Color3.fromRGB(255, 120, 200))
end
LOOKS.royal = function(g)
	prop(g, "Tiara", "Head", CFrame.new(0, 0.68, -0.15), function(m, add)
		add(Vector3.new(1.1, 0.1, 0.12), Color3.fromRGB(232, 196, 96), CFrame.new(0, 0, 0), Enum.Material.Metal)
		for i = -2, 2 do
			add(Vector3.new(0.1, 0.22 - math.abs(i) * 0.04, 0.08), Color3.fromRGB(232, 196, 96), CFrame.new(i * 0.2, 0.14, 0), Enum.Material.Metal)
		end
		add(Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(110, 170, 255), CFrame.new(0, 0.26, -0.02), Enum.Material.Glass, Enum.PartType.Ball)
		for _, x in ipairs({ -0.4, 0.4 }) do add(Vector3.new(0.1, 0.1, 0.1), Color3.fromRGB(220, 60, 90), CFrame.new(x, 0.12, -0.02), Enum.Material.Glass, Enum.PartType.Ball) end
	end)
	local s = g.model.UpperTorso.Size
	prop(g, "Sash", "UpperTorso", CFrame.new(0, 0, -s.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(-38)), function(m, add)
		add(Vector3.new(0.34, s.Y * 1.35, 0.06), Color3.fromRGB(44, 72, 170), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.3, 0.3, 0.08), Color3.fromRGB(232, 196, 96), CFrame.new(0, -0.15, -0.02), Enum.Material.Metal, Enum.PartType.Ball)
	end)
	prop(g, "Pearls", "UpperTorso", CFrame.new(0, s.Y / 2 - 0.12, -s.Z / 2 - 0.05), function(m, add)
		for i = -4, 4 do
			add(Vector3.new(0.11, 0.11, 0.11), Color3.fromRGB(246, 242, 232), CFrame.new(i * 0.1, -math.abs(i) * -0.03 - 0.16 + (i * i) * 0.012, 0), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end)
	prop(g, "Cape", "UpperTorso", CFrame.new(0, -0.05, s.Z / 2 + 0.08), function(m, add)
		add(Vector3.new(s.X + 0.3, s.Y + 2.1, 0.08), Color3.fromRGB(150, 24, 44), CFrame.new(0, -1.0, 0.08) * CFrame.Angles(math.rad(6), 0, 0), Enum.Material.Fabric)
		add(Vector3.new(s.X + 0.4, 0.22, 0.24), Color3.fromRGB(246, 244, 240), CFrame.new(0, s.Y / 2 + 0.02, 0), Enum.Material.Fabric)
	end)
	shimmer(g, Color3.fromRGB(255, 220, 120))
end
LOOKS.critic = function(g)
	noHair(g)
	prop(g, "Beret", "Head", CFrame.new(0.08, 0.66, 0.02) * CFrame.Angles(0, 0, math.rad(-10)), function(m, add)
		add(Vector3.new(1.35, 0.32, 1.3), Color3.fromRGB(28, 28, 34), CFrame.new(), Enum.Material.Fabric, Enum.PartType.Ball)
		add(Vector3.new(0.08, 0.14, 0.08), Color3.fromRGB(28, 28, 34), CFrame.new(0, 0.18, 0), Enum.Material.Fabric)
	end)
	prop(g, "Specs", "Head", CFrame.new(0, 0.12, -0.63), function(m, add)
		-- round red frames: a ring of short bars round a pale glass lens, a bridge and two arms
		local red = Color3.fromRGB(196, 40, 52)
		for _, x in ipairs({ -0.23, 0.23 }) do
			add(Vector3.new(0.02, 0.27, 0.27), Color3.fromRGB(230, 236, 246), CFrame.new(x, 0, 0.01) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.6
			for k = 0, 9 do
				local a = k / 10 * math.pi * 2
				add(Vector3.new(0.1, 0.035, 0.04), red, CFrame.new(x + math.cos(a) * 0.145, math.sin(a) * 0.145, 0) * CFrame.Angles(0, 0, a + math.pi / 2))
			end
		end
		add(Vector3.new(0.18, 0.035, 0.035), red, CFrame.new(0, 0.03, 0))
		for _, x in ipairs({ -0.58, 0.58 }) do add(Vector3.new(0.03, 0.03, 0.6), red, CFrame.new(x, 0.03, 0.3)) end
	end)
	local s = g.model.UpperTorso.Size
	prop(g, "Scarf", "UpperTorso", CFrame.new(0, s.Y / 2 - 0.05, 0), function(m, add)
		add(Vector3.new(s.X * 0.62, 0.3, s.Z + 0.16), Color3.fromRGB(196, 40, 52), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.3, 0.9, 0.1), Color3.fromRGB(196, 40, 52), CFrame.new(0.3, -0.5, -s.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(8)), Enum.Material.Fabric)
	end)
	coat(g, Color3.fromRGB(52, 54, 64), 0.5, true)
	prop(g, "Notebook", "LeftHand", CFrame.new(0, -0.35, -0.25) * CFrame.Angles(math.rad(-65), 0, 0), function(m, add)
		add(Vector3.new(0.7, 0.9, 0.1), Color3.fromRGB(30, 30, 36), CFrame.new(), Enum.Material.Leather)
		add(Vector3.new(0.62, 0.82, 0.04), Color3.fromRGB(250, 248, 240), CFrame.new(0, 0, -0.06))
	end)
	shimmer(g, Color3.fromRGB(255, 240, 200))
end
LOOKS.mystery = function(g)
	noHair(g)
	prop(g, "Fedora", "Head", CFrame.new(0, 0.66, 0), function(m, add)
		add(Vector3.new(0.1, 1.9, 1.9), Color3.fromRGB(58, 50, 44), CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.62, 1.22, 1.22), Color3.fromRGB(58, 50, 44), CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.16, 1.25, 1.25), Color3.fromRGB(26, 22, 20), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
	shades(g, Color3.fromRGB(14, 14, 18), Color3.fromRGB(30, 30, 34))
	coat(g, Color3.fromRGB(184, 150, 104), 1.4, false, Color3.fromRGB(160, 128, 86))
	prop(g, "Belt", "LowerTorso", CFrame.new(), function(m, add)
		local s = g.model.LowerTorso.Size
		add(Vector3.new(s.X + 0.2, 0.2, s.Z + 0.24), Color3.fromRGB(150, 118, 78), CFrame.new(0, s.Y / 2 - 0.05, 0), Enum.Material.Fabric)
	end)
end
LOOKS.tycoon = function(g)
	noHair(g)
	prop(g, "TopHat", "Head", CFrame.new(0, 0.66, 0), function(m, add)
		add(Vector3.new(0.08, 1.75, 1.75), Color3.fromRGB(22, 20, 24), CFrame.new(0, -0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(1.25, 1.16, 1.16), Color3.fromRGB(22, 20, 24), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.24, 1.18, 1.18), Color3.fromRGB(150, 26, 40), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end)
	prop(g, "Monocle", "Head", CFrame.new(0.22, 0.12, -0.62), function(m, add)
		-- a gold ring round a glass lens, and a fine chain down to the lapel
		local gold = Color3.fromRGB(232, 196, 96)
		add(Vector3.new(0.02, 0.28, 0.28), Color3.fromRGB(236, 240, 248), CFrame.new(0, 0, 0.01) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.6
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			add(Vector3.new(0.085, 0.035, 0.045), gold, CFrame.new(math.cos(a) * 0.155, math.sin(a) * 0.155, 0) * CFrame.Angles(0, 0, a + math.pi / 2), Enum.Material.Metal)
		end
		add(Vector3.new(0.02, 0.6, 0.02), gold, CFrame.new(0.13, -0.44, 0.03), Enum.Material.Metal)
	end)
	coat(g, Color3.fromRGB(30, 30, 38), 1.0, true, Color3.fromRGB(20, 20, 24))
	local s = g.model.UpperTorso.Size
	prop(g, "Vest", "UpperTorso", CFrame.new(0, -0.05, -s.Z / 2 - 0.03), function(m, add)
		add(Vector3.new(s.X * 0.36, s.Y * 0.8, 0.04), Color3.fromRGB(140, 30, 44), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.5, 0.2, 0.08), Color3.fromRGB(20, 20, 24), CFrame.new(0, s.Y * 0.42, -0.03), Enum.Material.Fabric)
		add(Vector3.new(0.5, 0.04, 0.05), Color3.fromRGB(232, 196, 96), CFrame.new(-0.2, -0.1, -0.03) * CFrame.Angles(0, 0, math.rad(14)), Enum.Material.Metal)
	end)
	prop(g, "Cane", "RightHand", GRIP, function(m, add)
		add(Vector3.new(2.6, 0.12, 0.12), Color3.fromRGB(22, 20, 24), CFrame.new(0, -1.2, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		add(Vector3.new(0.26, 0.26, 0.26), Color3.fromRGB(232, 196, 96), CFrame.new(0, 0.1, 0.1), Enum.Material.Metal, Enum.PartType.Ball)
	end)
	shimmer(g, Color3.fromRGB(255, 220, 120))
end

function E.dress(g, d)
	g.baseSpeed = g.hum.WalkSpeed
	g.baseMul = g.model:GetAttribute("WalkSpeedMul")
	local f = LOOKS[d.id]
	if f then pcall(f, g) end
	g.model:SetAttribute("Event", d.id)
	-- the bubble shows the event's icon in a gold ring beside the card (Bubbles draws it)
	g.model:SetAttribute("BEvent", d.icon)
end

-- the street crowd takes a body back: strip the event look
function E.undress(g)
	if not g.event then return end
	for _, c in ipairs(g.model:GetChildren()) do
		if c.Name:sub(1, 10) == "EventProp_" then c:Destroy() end
	end
	for _, a in ipairs(g.model:GetDescendants()) do
		if a:IsA("Attachment") and a.Name == "Attachment" and a.Parent:IsA("BasePart") and a.Parent.Name:find("Hand") then a:Destroy() end
	end
	local sh = g.root and g.root:FindFirstChild("Shimmer")
	if sh then sh:Destroy() end
	if g.baseSpeed then g.hum.WalkSpeed = g.baseSpeed end
	g.model:SetAttribute("WalkSpeedMul", g.baseMul)
	g.model:SetAttribute("Event", nil)
	g.model:SetAttribute("BEvent", nil)
end

---------------------------------------------------------------- moments (particles at a spot)

local function burst(pos, kind, n)
	local a = Instance.new("Part")
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.Transparency = 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.Position = pos
	a.Parent = workspace
	local p = Instance.new("ParticleEmitter")
	p.Rate = 0
	p.LightEmission = 0.4
	if kind == "confetti" then
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 70)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 230, 120)),
		})
		p.Size = NumberSequence.new(0.35, 0.2)
		p.Speed = NumberRange.new(10, 16)
		p.SpreadAngle = Vector2.new(50, 50)
		p.Acceleration = Vector3.new(0, -18, 0)
		p.Drag = 2
		p.Lifetime = NumberRange.new(1.4, 2.2)
		p.Rotation = NumberRange.new(0, 360)
		p.RotSpeed = NumberRange.new(-300, 300)
		p.EmissionDirection = Enum.NormalId.Top
	elseif kind == "hearts" then
		p.Texture = C.ICONS.ev_romance
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) })
		p.Speed = NumberRange.new(2, 4)
		p.SpreadAngle = Vector2.new(30, 30)
		p.Acceleration = Vector3.new(0, 2, 0)
		p.Lifetime = NumberRange.new(1.4, 2)
		p.EmissionDirection = Enum.NormalId.Top
		p.LightEmission = 0
	elseif kind == "flash" then
		p.Texture = C.ICONS.sparkle
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
		p.Speed = NumberRange.new(0, 0.5)
		p.Lifetime = NumberRange.new(0.15, 0.25)
		p.LightEmission = 1
		local l = Instance.new("PointLight")
		l.Brightness = 6
		l.Range = 14
		l.Color = Color3.fromRGB(255, 250, 240)
		l.Parent = a
		task.delay(0.12, function() l.Enabled = false end)
	elseif kind == "sparkle" then
		p.Texture = C.ICONS.sparkle
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) })
		p.Speed = NumberRange.new(3, 6)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Lifetime = NumberRange.new(0.6, 1)
		p.LightEmission = 0.8
		p.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	end
	p.Parent = a
	p:Emit(n or 30)
	game:GetService("Debris"):AddItem(a, 3)
end
E.burst = burst

---------------------------------------------------------------- the stay

local function front(m, gy)
	local piv = m:GetPivot()
	local it = Catalog.ITEMS[m:GetAttribute("Item")]
	local reach = (it and it.wall) and 1.8 or 2.6
	local p = (piv * CFrame.new(0, 0, reach)).Position
	return Vector3.new(p.X, gy, p.Z), piv.Position
end

local function goUse(ctx, g, m)
	local spot, at = front(m, g.root.Position.Y)
	ctx.walkTo(g, spot)
	if not g.alive then return false end
	ctx.faceTo(g, at)
	return true, at
end

-- the event's own moment in the room (before bed). Returns whether the need was met.
function E.stay(ctx, g, room)
	local d = g.event
	if not d or d.id == "inspector" then return true end
	local rng = ctx.rng
	if d.id == "tour" then
		ctx.status(g, d.actIcon, d.act, "yellow")
		ctx.say(g, d.lines[rng:NextInteger(1, #d.lines)], 2.5)
		for _ = 1, 3 do
			if not g.alive then return true end
			burst(g.head.Position + g.root.CFrame.LookVector * 1.2, "flash", 1)
			task.wait(rng:NextNumber(1, 1.8))
		end
		return true
	end
	if d.id == "celebrity" then
		local ok = E.roomOK(ctx, d, room)
		ctx.status(g, d.actIcon, d.act, "purple")
		ctx.play(g, "wave")
		for _ = 1, 4 do
			if not g.alive then return ok end
			burst(g.head.Position + Vector3.new(rng:NextNumber(-2, 2), 0.5, rng:NextNumber(-2, 2)), "flash", 1)
			task.wait(0.5)
		end
		ctx.timed(g, rng:NextNumber(d.secs[1], d.secs[2]))
		return ok
	end
	-- needs that live in the room or the lobby
	local m = d.need and E.find(ctx, d, room, d.need)
	if d.id == "sick" then
		ctx.status(g, "ev_sick", "Feeling unwell", "red")
		ctx.say(g, "I don't feel so good...", 2.5)
		ctx.timed(g, 3)
	end
	if not m then
		ctx.status(g, d.icon, "Needs " .. (d.missing or "more"), "red")
		ctx.say(g, d.sad[rng:NextInteger(1, #d.sad)], 3)
		task.wait(2)
		return false
	end
	if not goUse(ctx, g, m) then return false end
	ctx.status(g, d.actIcon, d.act, d.id == "allnighter" and "purple" or "green")
	local at = m:GetPivot().Position + Vector3.new(0, 2.5, 0)
	if d.id == "birthday" then
		ctx.play(g, "cheer")
		ctx.sfx("fanfare", at)
		burst(at, "confetti", 70)
		task.delay(3, function() if g.alive then burst(at, "confetti", 50) end end)
	elseif d.id == "honeymoon" then
		burst(at, "hearts", 14)
		task.delay(3, function() if g.alive then burst(at, "hearts", 10) end end)
	elseif d.id == "sick" then
		ctx.sfx("sparkle", at)
	elseif d.id == "gamer" then
		ctx.play(g, "cheer")
		burst(at, "confetti", 25)
	elseif d.id == "spa" or d.id == "fitness" then
		burst(at, "sparkle", 18)
	end
	ctx.timed(g, rng:NextNumber(d.secs[1], d.secs[2]))
	if d.id == "sick" then burst(g.head.Position, "sparkle", 20) end
	-- night owls: TV first, then a snack run
	if d.need2 then
		local s = E.find(ctx, d, room, d.need2)
		if not s then return false end
		if not goUse(ctx, g, s) then return false end
		ctx.status(g, "cash", "Midnight snack", "green")
		ctx.timed(g, rng:NextNumber(4, 6))
	end
	ctx.say(g, d.happy[rng:NextInteger(1, #d.happy)], 3)
	return true
end

-- the inspector walks the lobby, looks at a few things, and grades the hotel
function E.inspect(ctx, g, room)
	local d = E.DEFS.inspector
	local rng = ctx.rng
	ctx.status(g, "ev_inspector", "Inspecting", "blue")
	local looked = 0
	for _, m in ipairs(ctx.PLACED:GetChildren()) do
		if looked >= 3 or not g.alive then break end
		if m:GetAttribute("Zone") == "Lobby" and rng:NextNumber() < 0.6 then
			if goUse(ctx, g, m) then
				looked += 1
				ctx.say(g, ({ "Hmm.", "Noted.", "Interesting...", "Let me check this." })[rng:NextInteger(1, 4)], 2)
				task.wait(rng:NextNumber(1.5, 2.5))
			end
		end
	end
	if not g.alive then return end
	local I = E.INSPECT
	local safety = #E.items(ctx.PLACED, "Lobby", "safety")
	local appeal = ctx.HOTEL:GetAttribute("LobbyAppeal") or 0
	local stars = ctx.HOTEL:GetAttribute("HotelStars") or 1
	local fails = {}
	if safety < I.safety then table.insert(fails, "more safety kit in the lobby") end
	if appeal < I.lobbyAppeal then table.insert(fails, "a nicer lobby") end
	if stars < I.stars then table.insert(fails, I.stars .. "-star rooms") end
	ctx.timed(g, 3)
	-- safety kit is a must; one other miss is forgiven
	if safety >= I.safety and #fails <= 1 then
		ctx.say(g, "Excellent. You pass!", 3)
		ctx.play(g, "cheer")
		burst(g.head.Position + Vector3.new(0, 1, 0), "confetti", 60)
		ctx.HOTEL:SetAttribute("InspectedUntil", os.time() + I.boost)
		ctx.tell("toast", { text = "Inspection passed! +$" .. I.reward .. " and more walk-ins for a while", icon = "ev_inspector" })
		return true, I.reward
	end
	ctx.say(g, "Needs work.", 3)
	ctx.tell("toast", { text = "Inspection failed. Needs " .. table.concat(fails, ", "), icon = "ev_inspector", bad = true })
	return false, 0
end

-- what the stay pays
function E.pay(d, met, base)
	if not d or not d.pay then return base end
	return math.floor(base * (met and d.pay or (d.miss or E.MISS)) + 0.5)
end

return E
