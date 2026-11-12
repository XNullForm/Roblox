-- ServerStorage.Conversations (round 15, 2026-11-09): real conversations with guests and staff.
-- HotelSim's Talk handler asks Conversations first, then GuestLife, then its own old replies.
-- A talk starts on a menu: a few quick replies that fit the moment, then topics (small talk, getting to know
-- them, their stay, fun, offers / for staff: work, them, morale, feedback). A topic opens its own list of
-- questions; asked questions drop off, so a conversation moves on instead of looping. Every answer depends on
-- who they are (persona, guest type, role), how they feel (mood) and what's going on (weather, night, the
-- hotel), and comes back with a feel (face + gesture): happy, laugh, sad, angry, surprised, shy, think, tired,
-- proud, grateful, excited, nervous, ask, plain.
--   Conv.guestOptions(c, g, base) -> { {id, text, kind} }      Conv.guestReply(c, g, option, player) -> line, feel, act | nil
--   Conv.staffOptions(c, s)       -> { {id, text, kind} }      Conv.staffReply(c, s, option, player) -> line, feel, act | nil
--   Conv.feelOf(before, after, line) -> feel (for replies from elsewhere)
-- c = HotelSim's evCtx plus: pick, weather, isNight, lobbyAppeal(), charge(player, $), staffGain, staffLevel,
-- needsStaffRoom, guestList(), staffList(), Life
local Conv = {}

local TOPIC_LIFE = 40 -- seconds a topic stays open without an answer

local function pick(c, t) return t[c.rng:NextInteger(1, #t)] end
local function band(g)
	local m = g.mood or 65
	return m >= 66 and "good" or (m >= 40 and "ok" or "bad")
end
local function cap(s) return (s:gsub("^%l", string.upper)) end
-- a line table can be a list, or { good = {}, ok = {}, bad = {} } by mood, or a function
local function lineOf(c, g, t, ...)
	if type(t) == "function" then return t(c, g, ...) end
	if type(t) == "string" then return t end
	if t[1] then return pick(c, t) end
	local b = band(g)
	local l = t[b] or t.ok or t.good or t.bad
	return l and pick(c, l)
end
local function feelOf(c, g, f)
	if type(f) == "table" then return f[band(g)] or f.ok or "plain" end
	return f
end
local function told(g, key)
	g.told = g.told or {}
	return g.told[key]
end
local function markTold(g, key)
	g.told = g.told or {}
	g.told[key] = true
end

-- the gestures that go with a feel (Shared.NPCAnimLib acts)
Conv.FEEL_ACTS = {
	happy = { "talk_excited", "nod", "thumbs", "talk1" },
	laugh = { "laugh", "laugh", "clap" },
	sad = { "head_shake", "neck_rub", "talk_polite" },
	angry = { "talk_grumble", "point_angry", "arms_cross", "stomp" },
	surprised = { "arms_out", "talk_excited" },
	shy = { "scratch_head", "neck_rub" },
	think = { "think_chin", "scratch_head" },
	tired = { "yawn", "stretch", "neck_rub" },
	proud = { "hands_hips", "straighten", "thumbs" },
	grateful = { "bow", "talk_polite", "nod" },
	excited = { "cheer", "clap", "talk_excited" },
	nervous = { "neck_rub", "scratch_head", "look_around" },
	ask = { "talk_ask", "talk2" },
	shrug = { "shrug" },
	plain = { "talk1", "talk2", "talk3", "talk_explain" },
}
function Conv.actFor(c, feel)
	local p = Conv.FEEL_ACTS[feel] or Conv.FEEL_ACTS.plain
	return pick(c, p)
end

-- a reply from somewhere else (GuestLife, the old chain): read its feel from the mood change and the line
function Conv.feelOf(before, after, line)
	local d = (after or 0) - (before or 0)
	line = line or ""
	if d >= 6 then return "grateful" end
	if d >= 2 then return "happy" end
	if d <= -3 then return (after or 50) < 40 and "angry" or "sad" end
	if line:find("%?") then return "ask" end
	if line:find("[Hh]aha") or line:find("[Ll]ol") then return "laugh" end
	if line:find("!") then return (after or 60) >= 50 and "happy" or "angry" end
	if line:find("%.%.%.") then return "think" end
	return "plain"
end

---------------------------------------------------------------- guests

local G = {} -- option id -> def
Conv.G = G

-- topics (the menu): the id opens the list; intro is what they say
local G_TOPICS = {
	{ id = "t_small", text = "Make small talk", ids = { "st_day", "st_weather", "st_sleep", "st_food", "st_music", "st_pets", "st_sport", "st_town" },
		intro = { good = { "Sure! I love a good chat.", "Oh, go on then!", "Always happy to chat." }, ok = { "Sure, what's up?", "Okay, I've got a minute.", "Mm? Go on." }, bad = { "If you must.", "I'm not really in the mood, but fine.", "Make it quick." } } },
	{ id = "t_know", text = "Get to know them", ids = { "about", "whereFrom", "hobby", "p_job", "p_family", "p_dream", "p_first", "p_secret" },
		intro = { good = { "Oh, you want to know about me? How sweet.", "Ask me anything!", "Ha, an interview! Go on." }, ok = { "About me? Sure.", "Okay, what do you want to know?" }, bad = { "Why do you want to know?", "Hm. Fine. Ask away." } } },
	{ id = "t_stay", text = "Ask about their stay", ids = { "stay", "need", "s_room", "s_bed", "s_clean", "s_staff", "s_price", "s_improve" },
		intro = { good = { "So far? Lovely!", "Ask away, I'm happy to help.", "Feedback time? Sure!" }, ok = { "Sure, ask away.", "Feedback? Okay." }, bad = { "Oh, I have things to say.", "Where do I even start?", "You really want to know?" } } },
	{ id = "t_fun", text = "Have some fun", ids = { "f_joke", "f_tellJoke", "f_highfive", "f_dance", "f_style", "f_fact", "f_guess", "f_rate" },
		intro = { good = { "Ooh, fun! I'm in.", "Now you're talking!", "Yes please, I'm bored!" }, ok = { "Fun? Alright, surprise me.", "Okay, okay. What've you got?" }, bad = { "I'm not in a fun mood.", "Fun. Right. Sure." } } },
	{ id = "t_offer", text = "Offer them something", ids = { "freeDrink", "o_snack", "luggage", "o_pillow", "o_map", "o_umbrella", "o_wake", "o_upgrade", "discount" },
		intro = { good = { "Ooh, what are you offering?", "Spoil me!", "You're too kind. What is it?" }, ok = { "Oh? Like what?", "I'm listening." }, bad = { "It better be good.", "Trying to make it up to me?", "Go on." } } },
}
Conv.G_TOPICS = G_TOPICS
local G_TOPIC = {}
for _, t in ipairs(G_TOPICS) do G_TOPIC[t.id] = t end

-- the questions. text: button; say: line table; feel; mood: shift (once per guest, key = id); fill: needs;
-- cond(c, g): shown only when true; run(c, g, player) -> line, feel, act (does it all itself)
G.st_day = { text = "How's your day going?", feel = { good = "happy", ok = "plain", bad = "sad" }, mood = 1,
	say = { good = { "Honestly? Great! Best day in ages.", "Really good, thanks for asking!", "Wonderful. I had a lovely lie-in.", "Perfect so far. Don't jinx it!" },
		ok = { "Not bad, not bad.", "Same as always, you know.", "It's fine. Could be worse!", "Getting there, thanks." },
		bad = { "Don't ask.", "Long. Very long.", "It's been one thing after another.", "I've had better, honestly." } } }
G.st_weather = { text = "Crazy weather, huh?", feel = "plain",
	run = function(c, g)
		local w = c.weather()
		local L = {
			sun = { "Gorgeous out there! Not a cloud.", "Perfect weather for exploring.", "I think I'm getting a tan already." },
			rain = { "It's pouring! Glad I'm inside.", "I forgot my umbrella. Of course.", "I like the rain, actually. Very cosy." },
			snow = { "Snow! I feel like a kid again.", "So pretty, but my toes are frozen.", "I nearly slipped on the step!" },
			storm = { "That thunder made me jump!", "Wild out there. I'm staying put.", "Did the lights flicker, or was that me?" },
			fog = { "I can't see past the door!", "Spooky fog. Very mysterious hotel vibes.", "Like walking through soup out there." },
		}
		local list = L[w] or L.sun
		return pick(c, list), (w == "storm" and "nervous" or (w == "sun" and "happy" or "plain"))
	end }
G.st_sleep = { text = "Did you sleep well?", feel = "plain",
	run = function(c, g)
		if not g.room then return pick(c, { "Sleep? I haven't even got a room yet!", "Ask me once I've got a bed.", "Not yet. Is my room nearly ready?" }), "sad" end
		local stars = g.room.model and g.room.model:GetAttribute("Stars") or 1
		if stars >= 3 and (g.mood or 60) >= 50 then
			return pick(c, { "Like a baby! That bed is heaven.", "Best sleep I've had all year.", "Out like a light. Didn't hear a thing." }), "happy"
		elseif stars >= 2 then
			return pick(c, { "Pretty well, thanks.", "Not bad! Pillow's a bit flat.", "Woke up once, but okay." }), "plain"
		end
		return pick(c, { "The mattress is like a rock.", "I could hear the pipes all night.", "Barely. The bed squeaks." }), "tired"
	end }
G.st_food = { text = "Had anything good to eat?", feel = "plain",
	run = function(c, g)
		if g.ate then return pick(c, { "Yes! The food here is really good.", "I ate way too much. No regrets.", "That meal was something else." }), "happy" end
		local k, v = c.Life.lowest(g)
		if k == "hunger" and v < 45 then return pick(c, { "Not yet, and I'm starving.", "No! Where can I get food?", "My stomach's been growling for an hour." }), "sad" end
		return pick(c, { "Not yet. Any tips?", "Just a cereal bar. Very glamorous.", "I'm saving myself for dinner." }), "ask"
	end }
G.st_music = { text = "What music are you into?", feel = "happy", mood = 1,
	run = function(c, g)
		local p = g.persona and g.persona.id
		local L = {
			business = { "Jazz. Helps me think.", "Podcasts, mostly. Is that music?", "Classical. On my commute." },
			social = { "Pop! Anything I can sing along to.", "Whatever's on at the party!", "Karaoke classics. All of them." },
			active = { "Fast stuff for running. The faster the better.", "Workout playlists. Three hours long." },
			relax = { "Rain sounds. And whale songs.", "Soft acoustic. Very chill.", "Anything slow and dreamy." },
			bookworm = { "Piano. Quiet piano.", "Movie soundtracks. Epic ones." },
			foodie = { "Italian opera while I cook.", "Whatever the restaurant's playing." },
		}
		local list = L[p] or { "A bit of everything, honestly.", "Old rock songs. My dad's fault.", "Whatever's on the radio!", "I'm obsessed with one song right now. On repeat." }
		return pick(c, list), "happy", "talk_excited"
	end }
G.st_pets = { text = "Got any pets?", feel = "happy", mood = 1,
	say = { "Two cats. They hate me. I love them.", "A dog called Biscuit! Want a photo?", "A goldfish. He's very calm.", "No, but I want a parrot so bad.",
		"A tortoise. She's older than me.", "Three dogs and a very angry hamster.", "My neighbour's cat visits. Does that count?", "A rabbit named Sir Hops-a-lot." } }
G.st_sport = { text = "Watch any sports?", feel = "plain",
	say = { "Football, every weekend. Don't ask about my team.", "Tennis! I play badly too.", "Not really. I like the snacks, though.", "Basketball. I'm too short to play.",
		"I watch golf to fall asleep.", "Only when my family makes me.", "Racing! The faster the better." } }
G.st_town = { text = "Seen much of the town?", feel = "plain",
	run = function(c, g)
		local lt = g.lastTown and c.Life.TOWN[g.lastTown.id]
		if lt then return cap(string.format(pick(c, { "I went to %s! Loved it.", "Just got back from %s.", "%s, earlier. Very nice." }), lt.label)), "happy" end
		return pick(c, { "Not yet! Where should I start?", "Only the walk from the station.", "I've been too comfy in here." }), "ask"
	end, next = { "plans", "recommend" } }

G.p_job = { text = "What do you do for work?", feel = "plain", mood = 1,
	run = function(c, g)
		local p = g.persona and g.persona.id
		local L = {
			business = { "Sales. Office chairs. Don't fall asleep.", "I'm an accountant. I see numbers when I close my eyes.", "Management. Lots of meetings about meetings." },
			foodie = { "I'm a chef! Well, a sous chef.", "I write a food blog. Ten readers! Nine are my mum." },
			bookworm = { "Librarian. Shh.", "I teach English at a high school.", "Editor. I can't stop fixing typos on menus." },
			social = { "Wedding planner! Weddings every weekend.", "Event host. I talk for a living." },
			active = { "Personal trainer. Drop and give me twenty! Kidding.", "I'm a lifeguard back home." },
			relax = { "Nurse. Hence the holiday.", "I work in a call centre. This is my escape." },
			tourist = { "Travel photographer. Dream job!", "I'm between jobs. Travelling first!" },
			shopper = { "Fashion buyer. Shopping IS my work.", "I run a little vintage store." },
		}
		return pick(c, L[p] or { "I fix computers. Have you tried turning it off and on?", "Retired! Best job ever.", "I'm a student. Broke, but happy." }), "plain", "talk_explain"
	end }
G.p_family = { text = "Travelling with anyone?", feel = "plain",
	run = function(c, g)
		if g.buddy then return pick(c, { "With my partner! We've been planning this for ages.", "My other half. Over there, somewhere.", "Yes! Our first trip together." }), "shy" end
		return pick(c, { "Just me! Solo trip.", "Alone. It's nice to have some peace.", "My family's at home. I needed a break, ha.", "Just me, myself and my suitcase." }), "plain"
	end }
G.p_dream = { text = "What's your dream holiday?", feel = "excited", mood = 1,
	say = { "A beach hut with no wifi. Bliss.", "Seeing the northern lights. One day!", "A road trip with no plan at all.", "Somewhere with mountains and hot chocolate.",
		"Honestly? This is pretty close!", "A cruise. With an all-you-can-eat buffet.", "Somewhere nobody knows my name." } }
G.p_first = { text = "First time staying with us?", feel = "plain",
	run = function(c, g)
		if (g.mood or 60) >= 60 and c.rng:NextNumber() < 0.35 then return pick(c, { "No, my second! I came back for the service.", "Third time! You're my favourite hotel." }), "happy" end
		return pick(c, { "First time! I picked it from a photo.", "Yes! A friend told me about it.", "First time. So far, so good.", "Yes, I just walked past and came in!" }), "plain"
	end }
G.p_secret = { text = "Tell me a secret", feel = "shy", mood = 2,
	say = { good = { "I took two mints from the desk. Shh.", "I sing in the shower. Loudly. Sorry, neighbours.", "I'm actually scared of pigeons.", "I've never seen a full movie without falling asleep.", "I named my car. It's Gerald." },
		ok = { "A secret? I hardly know you!", "Hmm... I hate pineapple on pizza.", "I'm only pretending to understand art." },
		bad = { "My secret is I'm not enjoying this.", "No. Next question." } } }

G.s_room = { text = "How's the room?", feel = "plain",
	run = function(c, g)
		local r = g.room
		if not r then return pick(c, { "What room? I'm still waiting.", "I'll tell you once I've seen it." }), "sad" end
		local stars = r.model and r.model:GetAttribute("Stars") or 1
		if stars >= 4 then return pick(c, { "It's stunning! I feel like royalty.", "Fancier than my flat. By a lot.", "I took fifty photos of it." }), "excited" end
		if stars >= 3 then return pick(c, { "Really nice, thanks!", "Comfy and clean. Love it.", "Cosy! Just my style." }), "happy" end
		if stars >= 2 then return pick(c, { "It's fine. A bit plain.", "Does the job.", "Small, but it's okay." }), "plain" end
		return pick(c, { "It's... basic. Very basic.", "Is it meant to be that empty?", "A bed and a wall. That's it." }), "sad"
	end, next = { "s_improve" } }
G.s_bed = { text = "Is the bed comfy?", feel = "plain",
	run = function(c, g)
		if not g.room then return "Can't say. No bed yet!", "sad" end
		local stars = g.room.model and g.room.model:GetAttribute("Stars") or 1
		if stars >= 3 then return pick(c, { "Like sleeping on a cloud!", "I never want to get up.", "Too comfy. I'll miss breakfast." }), "happy" end
		return pick(c, { "It's a bit lumpy, honestly.", "I've slept on worse. Camping.", "My back has opinions about it." }), "tired"
	end }
G.s_clean = { text = "Is everything clean enough?", feel = "plain",
	run = function(c, g)
		local germ = g.gtype and g.gtype.id == "germ"
		local dirty = c.HOTEL:GetAttribute("DirtyRooms") or 0
		if germ then
			return pick(c, { "I've wiped my room twice. It's... acceptable.", "There's a smudge on my window. A SMUDGE.", "Cleaner than most. I'll give you that." }), "nervous", "arms_cross"
		end
		if (g.mood or 60) >= 55 then return pick(c, { "Spotless! Your cleaners are great.", "Very clean, yes!", "Sparkling. I checked under the bed." }), "happy" end
		return pick(c, { "I found a hair in the sink.", "The lobby floor could use a mop.", "Not quite, no." }), "sad"
	end }
G.s_staff = { text = "Are the staff treating you well?", feel = "plain",
	run = function(c, g)
		local n = #c.staffList()
		if n == 0 then return pick(c, { "What staff? It's just you!", "You're doing everything yourself?!" }), "surprised" end
		if (g.mood or 60) >= 60 then return pick(c, { "Everyone's been lovely!", "Your team is fantastic.", "The doorman waved at me. I felt famous." }), "happy" end
		return pick(c, { "They seem a bit busy.", "Nobody's really talked to me.", "They're trying their best, I suppose." }), "plain"
	end }
G.s_price = { text = "Is the price fair?", feel = "plain",
	run = function(c, g)
		local t = g.gtype and g.gtype.id
		if t == "bigspender" then return pick(c, { "Price? I never look at prices, darling.", "Cheap! Charge more, honestly." }), "proud", "hands_hips" end
		if t == "backpacker" then return pick(c, { "Any discount for students? Please?", "It's... a lot for my budget, ha." }), "nervous" end
		if (g.mood or 60) >= 60 then return pick(c, { "Worth every penny!", "Very fair for what you get.", "Bargain, honestly." }), "happy" end
		return pick(c, { "For this? It's a bit steep.", "I expected more for the money.", "Hmm. We'll see at checkout." }), "sad"
	end, next = { "discount" } }
G.s_improve = { text = "What should we improve?", feel = "think",
	run = function(c, g)
		-- a real tip: the weakest thing they've seen
		local note = c.topNote and c.topNote(g, "say")
		if note and note.d < 0 and note.say then return note.say, "sad" end
		if c.lobbyAppeal() < 8 then return pick(c, { "The lobby needs more decor. Plants, lamps, a rug!", "Make the lobby cosier. It feels empty.", "A few nice chairs in the lobby?" }), "think" end
		if not (c.kitchen and c.kitchen:open()) then return pick(c, { "A place to eat would be amazing.", "A kitchen! I'd pay for breakfast.", "Food. Please. Somewhere to eat." }), "think" end
		if g.room and (g.room.model:GetAttribute("Stars") or 1) < 3 then return pick(c, { "Comfier rooms. More furniture!", "A nicer bed and a lamp in the room?", "The rooms could be fancier." }), "think" end
		local k, v = c.Life.lowest(g)
		if k == "fun" and v < 50 then return pick(c, { "Something fun to do! Games, music, anything.", "An arcade machine? Please?" }), "think" end
		return pick(c, { "Honestly? Keep doing what you're doing.", "Nothing! Maybe free cookies.", "More of the same, please!" }), "happy"
	end }

G.f_joke = { text = "Want to hear a joke?", feel = "laugh", mood = 3,
	run = function(c, g)
		local good = (g.mood or 60) >= 45 or c.rng:NextNumber() < 0.3
		if good then
			return pick(c, { "Hahaha! Oh, that's terrible. I love it.", "Ha! I'm stealing that one.", "Pfft! Okay, that got me.", "Hahaha, stop! My stomach!", "Oh no. Oh no, that's so bad. Haha!" }), "laugh", "laugh"
		end
		return pick(c, { "...I don't get it.", "Was that the joke?", "Ha. Ha. Very funny." }), "plain", "arms_cross"
	end }
G.f_tellJoke = { text = "Tell me a joke!", feel = "laugh", mood = 2,
	say = { "Why don't hotels ever get lonely? They've got lots of suites. Ha!", "What did the pillow say to the bed? Sheet happens!",
		"I asked the receptionist for a wake-up call. They said: life's short!", "Why did the scarecrow get a promotion? Outstanding in his field!",
		"How do you make a tissue dance? Put a little boogie in it!", "Why did the suitcase go to therapy? Too much emotional baggage.",
		"What do you call a sleeping bull? A bulldozer!", "I told my suitcase there's no holiday this year. Now I'm dealing with emotional baggage." }, act = "laugh" }
G.f_highfive = { text = "High five!", feel = "excited", mood = 2,
	run = function(c, g)
		if (g.mood or 60) < 35 then return pick(c, { "I'm not high-fiving you.", "Not now." }), "angry", "arms_cross" end
		return pick(c, { "Yeah! Up top!", "Ha! Nice one!", "Woo! Too slow! Kidding.", "Boom! High five!" }), "excited", "clap"
	end }
G.f_dance = { text = "Show me your dance moves!", feel = "excited", mood = 2,
	run = function(c, g)
		if g.gtype and g.gtype.id == "party" then return pick(c, { "You asked for it! Woo!", "Watch THIS!", "I was born ready!" }), "excited", "cheer" end
		if (g.mood or 60) < 40 then return "Absolutely not.", "angry", "arms_cross" end
		return pick(c, { "Here? Now? Oh, fine!", "I only know one move. Here it is!", "Don't film this!" }), "shy", "arms_out"
	end }
G.f_style = { text = "I love your style!", feel = "shy", mood = 3,
	say = { good = { "Aww, thank you! I picked it myself.", "Stop it, you're making me blush!", "Really? It was a sale!", "Thank you! This is my lucky outfit." },
		ok = { "Oh! Thanks. Hah.", "This old thing?", "Thank you, that's kind." }, bad = { "...Thanks, I guess.", "Flattery won't fix my room." } } }
G.f_fact = { text = "Want a fun fact?", feel = "surprised", mood = 1,
	say = { "No way! Is that really true?", "Wait, really?! I'm telling everyone.", "Huh! I did not know that.", "That can't be right! ...Is it?", "My mind is blown. Truly." } }
G.f_guess = { text = "Guess my favourite colour!", feel = "think", mood = 1,
	run = function(c, g)
		local col = pick(c, { "Blue", "Green", "Purple", "Red", "Yellow", "Orange", "Pink" })
		return pick(c, { col .. "! Am I right? I'm right.", "Hmm... " .. col .. "? Final answer.", "You look like a " .. string.lower(col) .. " person!" }), "think", "think_chin"
	end }
G.f_rate = { text = "Rate the hotel out of ten!", feel = "think",
	run = function(c, g)
		local n = math.clamp(math.floor((g.mood or 60) / 10 + 0.5), 1, 10)
		if n >= 9 then return "A " .. n .. "! Easy. Nearly perfect.", "excited", "thumbs" end
		if n >= 7 then return "Solid " .. n .. ". Really good!", "happy" end
		if n >= 5 then return "Hmm... a " .. n .. "? It's okay.", "think" end
		return "A " .. n .. ". Sorry, but you asked.", "sad", "head_shake"
	end }

G.o_snack = { text = "Have a snack on us ($5)", kind = "cost", feel = "grateful",
	run = function(c, g, player)
		if told(g, "o_snack") then return "I've had one, thanks! Any more and I'll pop.", "laugh" end
		if not c.charge(player, 5) then return "Oh, don't worry about it.", "plain" end
		markTold(g, "o_snack")
		c.Life.fill(g, "hunger", 35)
		c.moodShift(g, 5, "They gave me a free snack. Sweet!", "Free snacks from the owner!")
		return pick(c, { "Ooh, thank you! Yum.", "A free snack? Best hotel ever.", "You read my mind!" }), "grateful", "bow"
	end }
G.o_pillow = { text = "Want an extra pillow?", feel = "grateful", mood = 3, cond = function(c, g) return g.room ~= nil end,
	say = { "Yes please! I'm a two-pillow person.", "Oh, that'd be lovely.", "How did you know? Thank you!" }, fill = { energy = 15 } }
G.o_map = { text = "Here's a map of the town", feel = "happy", mood = 3,
	run = function(c, g)
		local sug = c.Life.suggest(c, g, 1)
		local t = sug[1] and c.Life.TOWN[sug[1]]
		if t then
			g.townPlan, g.townSoon = sug[1], true
			return cap(string.format(pick(c, { "Ooh, %s is on here! I'm going.", "A map! I'll try %s first.", "Thanks! %s looks fun." }), t.label)), "happy"
		end
		return "Thanks! I'll have a look.", "happy"
	end }
G.o_umbrella = { text = "Borrow an umbrella", feel = "grateful", mood = 5,
	cond = function(c, g) local w = c.weather() return w == "rain" or w == "storm" or w == "snow" end,
	say = { "You're a lifesaver!", "Oh, thank you! I'll bring it back.", "Finally, I can go out!" } }
G.o_wake = { text = "Want a wake-up call?", feel = "plain", mood = 2, cond = function(c, g) return g.room ~= nil end,
	say = { "Yes! Eight, please. Okay, nine.", "Ooh, good idea. Not too early!", "No thanks, I'm sleeping in!" } }
G.o_upgrade = { text = "Free room upgrade ($25)", kind = "cost", feel = "excited",
	cond = function(c, g) return g.room ~= nil and (g.room.model:GetAttribute("Stars") or 1) < 4 end,
	run = function(c, g, player)
		if told(g, "o_upgrade") then return "You already spoiled me!", "shy" end
		if not c.charge(player, 25) then return "That's sweet, but no need.", "plain" end
		markTold(g, "o_upgrade")
		c.Life.fill(g, "energy", 25)
		c.moodShift(g, 12, "They upgraded my room for free!", "Got a free upgrade. Amazing service.")
		return pick(c, { "An upgrade?! You're the best!", "No way! Thank you so much!", "I'm telling all my friends!" }), "excited", "cheer"
	end }

-- topics and back
local function guestTopic(c, g, id)
	local t = G_TOPIC[id]
	if not t then return nil end
	g.convNext = { ids = t.ids, t = os.clock(), topic = id }
	g.talkNext = nil
	return lineOf(c, g, t.intro), (band(g) == "bad" and "plain" or "happy")
end

-- the option list for the talk card
function Conv.guestOptions(c, g, base)
	local out = {}
	local function add(id, text, kind) table.insert(out, { id = id, text = text, kind = kind }) end
	local cn = g.convNext
	if cn and os.clock() - cn.t < TOPIC_LIFE then
		local n = 0
		for _, id in ipairs(cn.ids) do
			local d = G[id]
			local shown = true
			if d and d.cond and not d.cond(c, g) then shown = false end
			if told(g, "q_" .. id) then shown = false end
			if shown then
				local text = (d and d.text) or c.Life.TALK_TEXT[id] or c.Life.optionText(g, id) or id
				if id == "freeDrink" and (g.mood or 60) >= 60 then text = "Have a drink on us ($10)" end
				if id == "discount" and (g.mood or 60) >= 55 then shown = false end
				if shown then
					add(id, text, (d and d.kind) or (id == "freeDrink" and "cost") or nil)
					n += 1
				end
			end
			if n >= 6 then break end
		end
		if n == 0 then
			g.convNext = nil
		else
			add("back", "Talk about something else", "back")
			add("bye", "Goodbye", "bye")
			return out
		end
	end
	-- GuestLife's follow-ups (a reply that leads somewhere) keep their own list
	if g.talkNext and os.clock() - g.talkNext.t < 25 then
		for _, o in ipairs(base) do
			if o.id ~= "bye" then add(o.id, o.text) end
		end
		add("back", "Talk about something else", "back")
		add("bye", "Goodbye", "bye")
		return out
	end
	-- the menu: what fits the moment, then the topics
	local q = 0
	for _, o in ipairs(base) do
		if o.id ~= "bye" and q < 3 and not told(g, "q_" .. o.id) then
			add(o.id, o.text, "quick")
			q += 1
		end
	end
	for _, t in ipairs(G_TOPICS) do add(t.id, t.text, "topic") end
	add("bye", "Goodbye", "bye")
	return out
end

-- -> line, feel, act (nil: not ours)
function Conv.guestReply(c, g, option, player)
	if option == "back" then
		g.convNext, g.talkNext = nil, nil
		return pick(c, band(g) == "bad" and { "What now?", "Mhm?", "Yes?" } or { "Sure! What else?", "Mhm?", "Go on!", "What's on your mind?" }), "ask"
	end
	if G_TOPIC[option] then return guestTopic(c, g, option) end
	local d = G[option]
	-- a question asked inside a topic drops off the list (theirs or GuestLife's)
	if g.convNext then
		for _, id in ipairs(g.convNext.ids) do
			if id == option then markTold(g, "q_" .. option) g.convNext.t = os.clock() break end
		end
	end
	if not d then return nil end
	local line, feel, act
	if d.run then
		line, feel, act = d.run(c, g, player)
	else
		line = lineOf(c, g, d.say)
		feel = feelOf(c, g, d.feel)
		act = d.act
	end
	if not line then return nil end
	if d.mood and not told(g, "m_" .. option) then
		markTold(g, "m_" .. option)
		c.moodShift(g, d.mood)
	end
	if d.fill then
		for k, v in pairs(d.fill) do c.Life.fill(g, k, v) end
	end
	c.Life.fill(g, "social", 6)
	if d.next then
		g.talkNext = { ids = d.next, t = os.clock() }
		local ok = true
		for _, id in ipairs(d.next) do if told(g, "q_" .. id) then ok = false end end
		if not ok then g.talkNext = nil end
	end
	return line, feel or "plain", act
end

---------------------------------------------------------------- staff

local S = {}
Conv.S = S

local S_TOPICS = {
	{ id = "t_work", text = "Talk about work", ids = { "w_busy", "w_tip", "w_best", "w_worst", "w_guests", "w_skill", "w_team" },
		intro = { "Work talk? Sure, boss.", "Shop talk! Go on.", "What do you want to know?" } },
	{ id = "t_them", text = "Get to know them", ids = { "sp_about", "sp_why", "sp_weekend", "sp_snack", "sp_dream", "sp_pet", "sp_secret" },
		intro = { "Oh, about me? Okay!", "Aw, you want to know me? Sure.", "Ha, a chat with the boss. Go on." } },
	{ id = "t_morale", text = "Boost their morale", ids = { "nice", "m_pep", "m_bonus", "m_coffee", "m_highfive", "m_joke", "m_proud" },
		intro = { "Ooh, I like where this is going.", "Morale? Mine's... fine. Why?", "Is this about my raise?" } },
	{ id = "t_feedback", text = "Give feedback", ids = { "fb_faster", "fb_careful", "fb_guests", "fb_tidy", "fb_late" },
		intro = { "Uh oh. Feedback?", "Okay... I'm listening.", "Is this a performance review?" } },
}
Conv.S_TOPICS = S_TOPICS
local S_TOPIC = {}
for _, t in ipairs(S_TOPICS) do S_TOPIC[t.id] = t end

local ROLE = function(s) return s.def and s.def.id or "janitor" end

-- morale: 0..100 (76 at rest; no staff room -25; praise, perks and feedback move it, slowly back to rest)
function Conv.morale(c, s)
	local now = os.clock()
	local adj = s.moraleAdj or 0
	if s.moraleT then adj *= math.exp(-(now - s.moraleT) / 600) end -- fades over ~10 minutes
	s.moraleAdj, s.moraleT = adj, now
	local base = c.needsStaffRoom() and 50 or 76
	if s.praisedAt and now - s.praisedAt < 300 then base += 12 end
	if (s.energy or 100) < 30 then base -= 10 end
	return math.clamp(math.floor(base + adj + 0.5), 0, 100)
end
local function moraleShift(c, s, d)
	Conv.morale(c, s)
	s.moraleAdj = math.clamp((s.moraleAdj or 0) + d, -45, 30)
	local m = Conv.morale(c, s)
	if s.g.model then s.g.model:SetAttribute("Mood", m) end
end
Conv.moraleShift = moraleShift
local function sband(c, s)
	local m = Conv.morale(c, s)
	return m >= 66 and "good" or (m >= 40 and "ok" or "bad")
end
local function cool(s, key, secs)
	s.cool = s.cool or {}
	local now = os.clock()
	if s.cool[key] and now < s.cool[key] then return false end
	s.cool[key] = now + secs
	return true
end

S.w_busy = { text = "Busy today?", run = function(c, s)
	local n = 0
	for _ in pairs(c.guestList()) do n += 1 end
	if n >= 8 then return pick(c, { "Busy? I haven't sat down since breakfast!", "Packed! It's a good problem to have.", "We're flat out, boss. Love it." }), "excited" end
	if n >= 3 then return pick(c, { "Steady. Nice pace.", "Busy enough to keep me awake!", "A few guests in. All under control." }), "plain" end
	return pick(c, { "Quiet. Too quiet.", "Hardly anyone in. More guests, boss!", "I've polished the same spot three times." }), "tired"
end }
S.w_tip = { text = "Any tips for the hotel?", run = function(c, s)
	if c.needsStaffRoom() then return pick(c, { "A staff room! Lockers, a table, anything.", "Honestly? Somewhere to take a break.", "Staff lockers would make us all happier." }), "think" end
	local tips = {
		janitor = { "More janitors when it gets busy. I'm one person!", "Rugs hide footprints. Just saying.", "Put bins in the lobby. Please." },
		doorman = { "A nicer lobby keeps the line patient.", "More rooms! People keep asking at the door.", "A bench outside for the queue?" },
		receptionist = { "A second desk would cut the queue in half.", "Nicer rooms, happier check-ins.", "A plant on my desk. For morale." },
		cook = { "More tables! People eat standing up.", "A second stove and I'll feed an army.", "Put the kitchen near the lobby. Smell sells." },
		handyman = { "Old machines break more. Upgrade them!", "Keep an eye on the vending machine. It's plotting.", "A workshop corner would be lovely." },
	}
	return pick(c, tips[ROLE(s)] or tips.janitor), "think", "talk_explain"
end }
S.w_best = { text = "Best part of the job?", feel = "happy", run = function(c, s)
	local L = {
		janitor = { "That squeaky-clean floor shine. Every time.", "Finding lost coins under the beds!", "Peace and quiet with my mop." },
		doorman = { "When guests smile walking in. Gets me every time.", "The tips! And the people. Mostly the tips." },
		receptionist = { "Handing over the keys. It's like giving a present!", "I meet people from all over!" },
		cook = { "Empty plates coming back. Best feeling ever.", "The smell of the kitchen in the morning." },
		handyman = { "Fixing something nobody else could.", "The click when a machine starts again." },
	}
	return pick(c, L[ROLE(s)] or L.janitor), "happy"
end }
S.w_worst = { text = "Hardest part of the job?", run = function(c, s)
	local L = {
		janitor = { "Room service trays. Don't ask what I've seen.", "Glitter. Who brings glitter to a hotel?" },
		doorman = { "Standing all day. My feet!", "Rainy days. I'm soaked by lunch." },
		receptionist = { "Angry guests. I just smile and nod.", "When everyone arrives at once!" },
		cook = { "The dinner rush. It's chaos!", "That one guest who wants everything off the menu." },
		handyman = { "Things breaking at 3 a.m.", "The vending machine. We have history." },
	}
	return pick(c, L[ROLE(s)] or L.janitor), "tired", "neck_rub"
end }
S.w_guests = { text = "Any interesting guests?", run = function(c, s)
	local list = {}
	for g in pairs(c.guestList()) do if g.alive and g.name and g ~= s.g then table.insert(list, g) end end
	if #list == 0 then return pick(c, { "None right now. It's just us!", "Ask me when we've got some guests, boss." }), "shrug", "shrug" end
	local g = list[c.rng:NextInteger(1, #list)]
	local first = string.match(g.name, "^(%S+)") or g.name
	local t = g.gtype and g.gtype.id
	local p = g.persona and g.persona.id
	if t == "karen" then return string.format(pick(c, { "%s asked for the manager three times. I said that's you.", "Watch out for %s. Very... particular." }), first), "nervous" end
	if t == "influencer" then return string.format("%s keeps filming the lobby. We're going viral, boss!", first), "excited" end
	if t == "party" then return string.format("%s brought a speaker. A big one.", first), "laugh" end
	if t == "dasher" then return string.format("Keep an eye on %s. Shifty.", first), "think" end
	if p == "foodie" then return string.format("%s asked me to rate the menu. Out of a hundred.", first), "laugh" end
	if p == "bookworm" then return string.format("%s hasn't looked up from that book all day.", first), "plain" end
	if (g.mood or 60) >= 70 then return string.format("%s is having the best time. Said so twice!", first), "happy" end
	if (g.mood or 60) < 40 then return string.format("%s looks pretty grumpy. Maybe go say hi?", first), "think" end
	return string.format("%s seems nice! Quiet type.", first), "plain"
end }
S.w_skill = { text = "How's the training going?", run = function(c, s)
	local lv = c.staffLevel(s)
	if lv >= 5 then return pick(c, { "Top level, boss. I could teach this.", "I'm a legend at this point. A humble legend." }), "proud", "hands_hips" end
	if lv >= 3 then return pick(c, { "Getting really good at this!", "I'm faster every day. Notice?" }), "proud" end
	return pick(c, { "Still learning! Give me time.", "Every shift I get a bit better.", "I only broke one thing this week!" }), "shy"
end }
S.w_team = { text = "How's the team?", run = function(c, s)
	local n = #c.staffList()
	if n <= 1 then return pick(c, { "What team? It's just me!", "Me, myself and I. Hire someone, boss!" }), "laugh" end
	return pick(c, { "We're a good bunch. Like a family.", "Everyone pulls their weight. Mostly.", "The cook keeps feeding us. Best team ever.", "We have a group chat. It's chaos." }), "happy"
end }

S.sp_about = { text = "Tell me about yourself", feel = "happy", say = {
	"Grew up two streets away. Always wanted to work here!", "I used to work at a fancy hotel. This one's better.", "I'm saving up to travel. Ironic, right?",
	"I'm the oldest of six. Chaos is my normal.", "I paint on my days off. Badly, but happily.", "I moved here last year. This town grew on me." } }
S.sp_why = { text = "Why did you take this job?", run = function(c, s)
	local L = {
		janitor = { "I like making things clean. It's calming.", "Honestly? The mop called to me." },
		doorman = { "I love people. And I love doors.", "It's the best seat in the house. Well, standing." },
		receptionist = { "I'm good with names and better with smiles.", "I like knowing everything that's going on." },
		cook = { "My grandma taught me to cook. This is for her.", "Feeding people makes me happy." },
		handyman = { "If it's broken, I want to fix it. Always been that way.", "Tools are my love language." },
	}
	return pick(c, L[ROLE(s)] or L.janitor), "proud"
end }
S.sp_weekend = { text = "Plans for your day off?", feel = "excited", say = {
	"Sleeping. All day. Don't call.", "My cousin's wedding. I'm doing a speech!", "Hiking up the hill. Want to come?", "Movie marathon and pizza.", "Visiting my mum. She'll ask about you, boss." } }
S.sp_snack = { text = "Favourite snack?", feel = "happy", say = {
	"Crisps. Salt and vinegar. No debate.", "The cook's cookies. Don't tell them.", "Popcorn! Anytime, anywhere.", "Cheese on toast. Simple. Perfect.", "Chocolate. Any kind. All of it." } }
S.sp_dream = { text = "Big dreams?", feel = "think", say = {
	"Running my own hotel one day. No offence!", "Being the best at my job in the whole town.", "Travel the world. Then come back here.", "Honestly? Just a nice garden.", "Employee of the month. Every month." } }
S.sp_pet = { text = "Any pets?", feel = "happy", say = {
	"A cat called Mop. Fitting, right?", "Two budgies. They sing all morning.", "A dog! He'd love it here.", "A cactus. He's low maintenance.", "No, but I feed the pigeons outside." } }
S.sp_secret = { text = "Tell me a secret", feel = "shy", say = {
	"I nap in the linen closet sometimes. Two minutes!", "I eat the guest mints. Only the green ones.", "I talk to the plants when nobody's around.", "I've named every lobby chair." } }

S.m_pep = { text = "Pep talk! You've got this!", kind = "boost", run = function(c, s)
	if not cool(s, "pep", 180) then return pick(c, { "I'm already pumped, boss!", "Any more pep and I'll explode!" }), "laugh" end
	s.restedAt = os.clock() -- a burst of speed for a few minutes (like after a break)
	moraleShift(c, s, 8)
	return pick(c, { "YES! Let's GO!", "I've got this! I've totally got this!", "You're right! Watch me work!" }), "excited", "cheer"
end }
S.m_bonus = { text = "Here's a bonus ($20)", kind = "cost", run = function(c, s, player)
	if not cool(s, "bonus", 300) then return pick(c, { "You already gave me one! You're spoiling me.", "Save it, boss. I'm good!" }), "shy" end
	if not c.charge(player, 20) then s.cool.bonus = 0 return "That's kind, boss, but keep it for the hotel.", "plain" end
	c.staffGain(s, 12)
	moraleShift(c, s, 16)
	return pick(c, { "A bonus?! Boss, you're the best!", "No way! Thank you!", "I'm treating myself to something nice!" }), "excited", "cheer"
end }
S.m_coffee = { text = "Coffee's on me ($5)", kind = "cost", run = function(c, s, player)
	if not cool(s, "coffee", 120) then return "One more coffee and I'll see through time.", "laugh" end
	if not c.charge(player, 5) then s.cool.coffee = 0 return "I'm okay, thanks boss!", "plain" end
	s.energy = math.min(100, (s.energy or 100) + 30)
	if s.g.model then s.g.model:SetAttribute("Energy", math.floor(s.energy)) end
	moraleShift(c, s, 5)
	return pick(c, { "Ahh, coffee. My one true love.", "You're a lifesaver, boss.", "Caffeine! Now we're cooking." }), "grateful", "sip"
end }
S.m_highfive = { text = "High five!", feel = "excited", run = function(c, s)
	if cool(s, "hi5", 60) then moraleShift(c, s, 3) end
	return pick(c, { "Up top, boss!", "Ha! Team work!", "Boom! Let's go!" }), "excited", "clap"
end }
S.m_joke = { text = "Tell me a joke", feel = "laugh", say = {
	"Why did the mop quit? It was tired of being pushed around!", "What's a hotel's favourite music? Suite melodies!", "I'd tell you a joke about the lift, but it works on so many levels.",
	"Why are hotel towels so smug? They've been through a lot of spin.", "I told the boiler a joke. It didn't get warm to it." }, act = "laugh" }
S.m_proud = { text = "I'm proud of you", run = function(c, s)
	if cool(s, "proud", 240) then
		moraleShift(c, s, 10)
		c.staffGain(s, 3)
		return pick(c, { "Boss... that means a lot. Really.", "Oh! I... thank you. I'm proud to work here.", "You're going to make me cry. In a good way." }), "grateful", "bow"
	end
	return pick(c, { "Aw, you said that already!", "I know, boss! Ha." }), "shy"
end }

S.fb_faster = { text = "Pick up the pace!", kind = "warn", run = function(c, s)
	s.restedAt = os.clock()
	moraleShift(c, s, -10)
	if sband(c, s) == "bad" then return pick(c, { "I'm going as fast as I can!", "Wow. Okay. Fine.", "Maybe hire more staff then?" }), "angry", "talk_grumble" end
	return pick(c, { "Yes boss! On it!", "Faster. Right. Got it.", "Sorry, boss! Speeding up." }), "nervous", "straighten"
end }
S.fb_careful = { text = "Be a bit more careful", kind = "warn", run = function(c, s)
	moraleShift(c, s, -3)
	return pick(c, { "Sorry, boss. I'll slow down a bit.", "You saw that? Oops.", "Careful. Got it. Very careful." }), "shy", "scratch_head"
end }
S.fb_guests = { text = "Be friendlier to guests", kind = "warn", run = function(c, s)
	moraleShift(c, s, -4)
	return pick(c, { "I'm always friendly! ...Mostly.", "Smile more. Got it.", "Okay, I'll put on my best smile." }), "shy"
end }
S.fb_tidy = { text = "Keep the place tidier", kind = "warn", run = function(c, s)
	moraleShift(c, s, -3)
	if ROLE(s) == "janitor" then return pick(c, { "Tidier?! I mopped that twice!", "Okay, okay. I'll go round again." }), "angry", "talk_grumble" end
	return pick(c, { "That's not really my job, boss... but okay.", "I'll pick up what I see!" }), "plain"
end }
S.fb_late = { text = "You were late this morning", kind = "warn", run = function(c, s)
	moraleShift(c, s, -6)
	return pick(c, { "The bus! It was the bus, I swear.", "Sorry, boss. Won't happen again.", "Me? Late? ...Yeah, sorry." }), "nervous", "neck_rub"
end }

S.s_break = { text = "Take a break, you've earned it", kind = "boost", run = function(c, s)
	if s.onBreak then return "I'm already on one, boss!", "laugh" end
	if (s.energy or 100) > 85 then return pick(c, { "I'm fine, boss! Full of beans.", "A break? I only just started!" }), "proud" end
	if c.sendBreak then c.sendBreak(s, true) end
	moraleShift(c, s, 6)
	return pick(c, { "Oh, thank you! My feet needed that.", "Coffee time! Thanks, boss.", "Five minutes. I'll be back fresh!" }), "grateful", "stretch"
end }

function Conv.staffOptions(c, s)
	local out = {}
	local function add(id, text, kind) table.insert(out, { id = id, text = text, kind = kind }) end
	local cn = s.convNext
	if cn and os.clock() - cn.t < TOPIC_LIFE then
		local n = 0
		for _, id in ipairs(cn.ids) do
			local d = S[id]
			local text = (d and d.text) or (id == "nice" and "Great job!") or id
			add(id, text, d and d.kind)
			n += 1
			if n >= 6 then break end
		end
		add("back", "Talk about something else", "back")
		add("bye", "Goodbye", "bye")
		return out
	end
	add("stay", "How's work?", "quick")
	add("need", "Need anything?", "quick")
	if (s.energy or 100) < 70 and not s.onBreak then add("s_break", S.s_break.text, "boost") end
	for _, t in ipairs(S_TOPICS) do add(t.id, t.text, "topic") end
	add("bye", "Goodbye", "bye")
	return out
end

function Conv.staffReply(c, s, option, player)
	if option == "back" then
		s.convNext = nil
		return pick(c, { "Something else, boss?", "Mhm?", "What's up?" }), "ask"
	end
	local t = S_TOPIC[option]
	if t then
		s.convNext = { ids = t.ids, t = os.clock(), topic = option }
		return pick(c, t.intro), option == "t_feedback" and "nervous" or "happy"
	end
	if s.convNext then s.convNext.t = os.clock() end
	local d = S[option]
	if not d then return nil end
	local line, feel, act
	if d.run then
		line, feel, act = d.run(c, s, player)
	else
		line = pick(c, d.say)
		feel, act = d.feel or "plain", d.act
	end
	if not line then return nil end
	return line, feel or "plain", act
end

return Conv
