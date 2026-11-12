-- ServerStorage.Voice (round 18): how people talk. Every guest and staff member gets a voice (a way of speaking)
-- on top of their persona (what they're into): model attribute "Voice". A voice has its own lines for every
-- situation, out loud (say) and in their head (think), plus small habits applied to any other line (flavor).
-- Voice.start(folder, sayFn) runs the background life: idle chatter, thoughts that fit what they're doing,
-- two people near each other striking up a little exchange, greeting a player who walks up.
-- Voice.bump(a, b) is two walkers knocking shoulders.
local Players = game:GetService("Players")
local V = {}
local rng = Random.new()

local function pick(t) return t and #t > 0 and t[rng:NextInteger(1, #t)] or nil end

-- deep = lower voice blips; rate = speaking pace for the blips (higher = slower)
V.STYLES = {
	sunny = { deep = false, rate = 0.9 },
	grump = { deep = true, rate = 1.1 },
	posh = { deep = false, rate = 1.05 },
	chill = { deep = true, rate = 1.15 },
	nervous = { deep = false, rate = 0.85 },
	chatter = { deep = false, rate = 0.8 },
	dry = { deep = true, rate = 1.05 },
	nan = { deep = false, rate = 1.2 },
	teen = { deep = false, rate = 0.95 },
	boss = { deep = true, rate = 0.9 },
}
V.ORDER = { "sunny", "grump", "posh", "chill", "nervous", "chatter", "dry", "nan", "teen", "boss" }

-- out loud, by situation
local SAY = {
	hello = {
		sunny = { "Hi! I'm %s!", "Hello hello! %s, nice to meet you!", "Oh hi! %s. I'm so excited to be here!" },
		grump = { "%s. Yes, I have a booking.", "Name's %s. Let's get this over with.", "%s. And before you ask, no, I'm not in a good mood." },
		posh = { "Good day. %s, if you'd be so kind.", "%s. I trust everything is in order?", "How do you do. The name is %s." },
		chill = { "Hey. I'm %s. No rush.", "%s. Cool place.", "Yo, %s here. Take your time." },
		nervous = { "Um, hi, I'm %s. I think I booked? Online?", "H-hello. %s. Sorry. Hi.", "Oh! Hi. I'm %s. Is this the right hotel?" },
		chatter = { "Hi! I'm %s, long drive, the traffic, don't even get me started!", "%s! That's me. You would not believe the morning I've had.", "Hello! %s. Lovely sign out front, did you paint it yourself?" },
		dry = { "%s. I'm told I have a room.", "I'm %s. Thrilled to be here. Truly.", "%s. I'll be your guest this evening." },
		nan = { "Hello, dear. I'm %s.", "Oh, aren't you lovely. I'm %s, love.", "%s, sweetheart. My grandson booked it for me." },
		teen = { "hey. %s.", "uh, %s? there's a booking i think", "hi. im %s. is there wifi" },
		boss = { "%s. I'm in a hurry.", "%s, booked under my company. Quick as you can.", "%s. I've got a call in ten minutes." },
	},
	waitLine = {
		sunny = { "Ooh, busy place! Good sign!", "I don't mind waiting. Look at that lobby!" },
		grump = { "Any day now.", "Is this line even moving?", "I could've built my own hotel by now." },
		posh = { "One does hope this won't take long.", "How quaint. A queue." },
		chill = { "No stress. I'll wait.", "Line's a line, man." },
		nervous = { "Am I in the right line? I think I'm in the right line.", "Should I... go ahead? No. I'll wait." },
		chatter = { "So anyway, my cousin says this town has the best ice cream...", "Long line! Reminds me of the airport. Don't get me started on the airport." },
		dry = { "Ah. A line. My favourite.", "I'm aging in real time here." },
		nan = { "I'll just rest my feet a moment.", "No hurry, dear. I've got all day." },
		teen = { "this is taking forever", "my phone's on 4 percent" },
		boss = { "Time is money, people.", "Can we speed this up?" },
	},
	waitLong = {
		sunny = { "Still smiling! Mostly.", "Okay, this is getting a little long." },
		grump = { "Unbelievable.", "I'm writing a review about this. In my head. Already.", "Ridiculous. Absolutely ridiculous." },
		posh = { "This is most irregular.", "I have never waited this long in my life." },
		chill = { "Bit of a wait, huh.", "Starting to feel it, not gonna lie." },
		nervous = { "Did they forget about me?", "Maybe I should just leave... no... maybe?" },
		chatter = { "Is there a problem? Is there a problem at the desk? Hello?", "I've told this lady my whole life story and we still haven't moved." },
		dry = { "I've seen glaciers move faster.", "I think I've grown a beard." },
		nan = { "Oh dear, my knees.", "Is somebody minding the desk, love?" },
		teen = { "bro", "literally been here for ages" },
		boss = { "I'm billing you for this time.", "Who's in charge here?" },
	},
	checkin = {
		sunny = { "Thank you so much!", "Yay! Room time!", "You're the best!" },
		grump = { "Finally.", "About time.", "Fine. Thanks. I suppose." },
		posh = { "Splendid. Thank you.", "Most efficient. Well done." },
		chill = { "Sweet, thanks.", "Nice one." },
		nervous = { "Oh! Thank you! Sorry, thank you.", "Is that all? Okay. Thank you!" },
		chatter = { "Wonderful! Now, which way is the room, and is there breakfast, and...", "Thanks a million! You've been lovely!" },
		dry = { "A key. How exciting.", "Thank you. I'll try to contain my joy." },
		nan = { "Thank you, dear. You're a treasure.", "Bless you, love." },
		teen = { "cool thx", "ok nice" },
		boss = { "Good. Moving on.", "Thanks. Efficient." },
	},
	roomGood = {
		sunny = { "Oh it's PERFECT!", "Look at this bed!" },
		grump = { "Hm. It'll do.", "Could be worse. Not much worse, but worse." },
		posh = { "Adequate. Rather charming, actually.", "The linens are acceptable." },
		chill = { "Nice. Comfy.", "Yeah, this is good." },
		nervous = { "It's really nice! Is it really all mine?", "Oh, it's lovely. I'm scared to touch anything." },
		chatter = { "Ooh, a view! Well, a view of a wall, but a nice wall!", "Clean towels! You know how rare that is?" },
		dry = { "A bed. With a pillow. Spoiling me.", "Room's fine. I'm shocked." },
		nan = { "Oh how lovely, just like home.", "Very cosy, dear." },
		teen = { "ok this is actually nice", "bed is big. good" },
		boss = { "Desk, bed, plug. Good.", "This works." },
	},
	roomDirty = {
		sunny = { "Oh... someone forgot to clean. That's okay!", "Eek. Is that a sock?" },
		grump = { "Is that a CRUMB? On my PILLOW?", "Disgusting. Just disgusting." },
		posh = { "I beg your pardon. This room is filthy.", "Good heavens. Housekeeping!" },
		chill = { "Uh. Bit messy, but whatever.", "Not ideal, man." },
		nervous = { "Should I... clean it myself?", "Oh no. Was it like this before? Did I do this?" },
		chatter = { "Well! Somebody had a party in here!", "I'm not saying it's dirty, but there's a towel on the lamp." },
		dry = { "Love the lived-in look.", "Someone left me a souvenir. On the floor." },
		nan = { "Oh my, this won't do at all.", "I'll have to give it a wipe myself." },
		teen = { "ew", "nah this is gross" },
		boss = { "Unacceptable.", "I want this cleaned. Now." },
	},
	hungry = {
		sunny = { "I could eat a horse! A small horse!", "Snack time? Snack time!" },
		grump = { "Is there food in this place or not?", "Starving. Nobody cares." },
		posh = { "I find myself rather peckish.", "Is there a dining room of any standard?" },
		chill = { "Kinda hungry, ngl.", "Could go for a sandwich." },
		nervous = { "Is it rude to ask about food?", "My stomach's being so loud. Sorry." },
		chatter = { "Do you know what I'd kill for right now? A pastry. Any pastry.", "I skipped lunch, then I skipped the snack after lunch..." },
		dry = { "My stomach is filing a complaint.", "I'll eat the welcome mat at this point." },
		nan = { "I could do with a nice cup of tea and a biscuit.", "A little something to eat, I think." },
		teen = { "im so hungry", "is there like. food" },
		boss = { "I need lunch. Something fast.", "Where's the nearest food?" },
	},
	tired = {
		sunny = { "Yawn! What a day!", "I'm pooped. Happy pooped!" },
		grump = { "I'm exhausted and nobody cares.", "I need a bed. Not a lecture." },
		posh = { "I believe I shall retire.", "Rather a long day." },
		chill = { "Gonna crash soon.", "Eyes are closing, man." },
		nervous = { "I'm so tired but I can't sleep in new places...", "Is it too early to go to bed?" },
		chatter = { "I'm falling asleep standing up! Did I tell you about my flight?", "I'm so tired I called my cat by my sister's name." },
		dry = { "I'm running on fumes and spite.", "Sleep. I remember sleep." },
		nan = { "Time for my nap, I think.", "These old bones need a lie down." },
		teen = { "so tired", "need sleep fr" },
		boss = { "Four hours of sleep. That's plenty.", "Coffee. I need coffee." },
	},
	bored = {
		sunny = { "What's there to do around here?", "Ooh, anyone up for a game?" },
		grump = { "Nothing to do. Typical.", "Bored out of my mind." },
		posh = { "One requires some entertainment.", "Is there nothing cultured to do here?" },
		chill = { "Kinda quiet. Not bad, just quiet.", "Wouldn't mind something to do." },
		nervous = { "Should I go somewhere? Where would I even go?", "I don't know what to do with myself." },
		chatter = { "Anybody want to hear about my holiday photos? All four hundred?", "I'm SO bored. Let's talk!" },
		dry = { "I've counted the floor tiles. Twice.", "Riveting. Truly riveting." },
		nan = { "I should have brought my knitting.", "Nothing on the telly, I suppose." },
		teen = { "boring", "theres nothing to do" },
		boss = { "I could be working right now.", "Waste of an afternoon." },
	},
	lonely = {
		sunny = { "Anyone wanna chat?", "It's nice to meet new people!" },
		grump = { "Don't talk to me. Unless you want to. Whatever.", "Nobody talks to anybody anymore." },
		posh = { "Not a soul to converse with.", "Would anyone care for conversation?" },
		chill = { "Kinda quiet without anyone around.", "Wouldn't mind some company." },
		nervous = { "Should I say hi to someone? What would I say?", "Everyone looks so busy." },
		chatter = { "Hello? Anyone? I've got stories!", "I've been quiet for TEN minutes. Personal record." },
		dry = { "Just me and my thoughts. Terrible company.", "Party of one." },
		nan = { "I do miss my grandchildren.", "Somebody come sit with me, dear." },
		teen = { "nobody to talk to", "kinda lonely ngl" },
		boss = { "Networking opportunity? No? Fine.", "Nobody here worth talking to." },
	},
	idle = {
		sunny = { "What a lovely day!", "I love this place already!", "Is it just me or is everyone so friendly here?", "I'm going to tell all my friends about this hotel!" },
		grump = { "Who picked this carpet?", "Noisy. Always noisy.", "Back in my day hotels had standards.", "I hate holidays." },
		posh = { "The decor is... brave.", "Charming little establishment.", "I usually stay somewhere with a doorman. Two doormen.", "Quite." },
		chill = { "Vibes are good here.", "Not a bad spot, honestly.", "Just taking it easy.", "Life's short, y'know?" },
		nervous = { "Did I lock my car? I think I locked my car.", "Everyone's looking at me. Are they? No.", "I hope I packed my charger.", "Is it okay to sit here?" },
		chatter = { "Did you know they used to make cheese in this town? Big wheels of it!", "My neighbour's dog had puppies. Seven of them!", "I once met a man who owned forty hats. Forty!", "So I said to my sister, I said, go on holiday, it'll be fun!" },
		dry = { "Another day, another hotel.", "I'm having the time of my life. Can't you tell?", "Nice plant. Probably fake.", "Living the dream." },
		nan = { "In my day this was all fields.", "Lovely young people working here.", "I must send a postcard.", "Oh, my hip." },
		teen = { "is the wifi password on the key card", "this place is kinda cute ngl", "my mom made me come", "whatever" },
		boss = { "Need to answer about forty emails.", "Deadline's tomorrow.", "Where's the business centre?", "Productivity, people." },
	},
	rain = {
		sunny = { "Rain! Puddle jumping time!", "I love the sound of rain!" },
		grump = { "Of course it's raining.", "Wet. Everything is wet." },
		posh = { "Dreadful weather.", "I've ruined my good shoes." },
		chill = { "Rainy day, cosy day.", "Nice weather for a nap." },
		nervous = { "I didn't bring an umbrella...", "Is that thunder? That's thunder." },
		chatter = { "Raining cats and dogs! Well, not literally, I had a dog once...", "Did you see that rain? Sideways!" },
		dry = { "Lovely day for a swim. Outside.", "And the sky opens. Perfect." },
		nan = { "Good for the garden, at least.", "Mind you don't catch a chill, love." },
		teen = { "ugh rain", "my hair" },
		boss = { "Rain won't stop me.", "Get me a taxi." },
	},
	leaveHappy = {
		sunny = { "Best stay ever! Bye!", "I'll be back! Promise!" },
		grump = { "Fine. It was fine. Don't tell anyone I said that.", "Better than I expected. Low bar." },
		posh = { "A most pleasant stay. Good day.", "I shall recommend you to my club." },
		chill = { "That was sick. Later!", "Good times. Peace." },
		nervous = { "Thank you for everything! Sorry for any trouble!", "That was really nice. Bye! Sorry. Bye!" },
		chatter = { "I'm telling EVERYONE about this place!", "Bye bye! I'll write! I won't, but I'll think about it!" },
		dry = { "Five stars. I don't say that lightly. I don't say it at all.", "I had fun. Write that down." },
		nan = { "Lovely stay, dears. Take care.", "I'll bring my sister next time." },
		teen = { "ok that was actually fun", "bye" },
		boss = { "Good service. I'll book again.", "Efficient. I like that." },
	},
	leaveAngry = {
		sunny = { "Well... that was disappointing.", "I really wanted to love it." },
		grump = { "Never again.", "Worst. Hotel. Ever.", "I'm telling everyone. Everyone." },
		posh = { "Simply dreadful.", "My solicitor will hear about this." },
		chill = { "Not my vibe, man.", "Kinda rough, honestly." },
		nervous = { "I don't want to complain but... it wasn't great.", "Maybe it was me? No. It wasn't me." },
		chatter = { "Wait till my book club hears about this!", "I've had better stays in a tent. In the rain." },
		dry = { "Well. That happened.", "Two stars. One for the door." },
		nan = { "I'm not angry, dear, just disappointed.", "My grandson will hear about this." },
		teen = { "worst place ever", "im leaving a bad review" },
		boss = { "I want a refund.", "Your manager will hear from me." },
	},
	bumpSorry = {
		sunny = { "Oops! Sorry!", "Whoops, my bad!" },
		grump = { "Watch it.", "Eyes open, pal.", "Hey!" },
		posh = { "I beg your pardon!", "Do mind yourself." },
		chill = { "Whoa, sorry man.", "My bad." },
		nervous = { "Sorry! Sorry sorry sorry!", "Oh! Sorry! My fault!" },
		chatter = { "Oh! Hello! Sorry! Lovely to bump into you, ha!", "Whoops! Busy in here, isn't it!" },
		dry = { "Ah. A collision.", "Personal space. Look it up." },
		nan = { "Ooh, careful, dear!", "Mind my hip, love." },
		teen = { "bruh", "watch where ur going" },
		boss = { "Excuse me. Busy.", "Move, please." },
	},
	greetPlayer = {
		sunny = { "Oh hi! Great hotel!", "Hello! Lovely day!" },
		grump = { "What do you want?", "Oh. It's you." },
		posh = { "Ah, the proprietor.", "Good day to you." },
		chill = { "Hey. Cool place.", "Sup." },
		nervous = { "Oh! Hi! Did I do something wrong?", "H-hello!" },
		chatter = { "Oh it's you! I was just saying to myself...", "Hello! Have you got a minute? Or ten?" },
		dry = { "The boss. Act natural.", "Hi. Yes. Still here." },
		nan = { "Hello, love. Have you eaten?", "There's the nice manager." },
		teen = { "oh hey", "hi" },
		boss = { "You run this place? We should talk.", "Quick question, actually, never mind." },
	},
	smallTalk = {
		sunny = { "Isn't this place great?", "Where are you visiting from?" },
		grump = { "Did you see the size of that line?", "Rooms are tiny, right?" },
		posh = { "Have you dined anywhere decent in town?", "Frightfully busy today." },
		chill = { "You staying long?", "Nice day, right?" },
		nervous = { "Um, do you know where the bathroom is?", "Sorry, is anyone sitting here?" },
		chatter = { "Hi! Have you been to the market? You HAVE to go!", "Where are you from? Wait, let me guess!" },
		dry = { "Here for the thrills too?", "Come here often?" },
		nan = { "Are you here on holiday, dear?", "You remind me of my nephew." },
		teen = { "do u know the wifi", "is this place always like this" },
		boss = { "What line of work are you in?", "Business or pleasure?" },
	},
	reply = {
		sunny = { "Yes! Love it!", "Oh, totally!" },
		grump = { "Mm.", "Don't get me started." },
		posh = { "Quite so.", "Indeed." },
		chill = { "Yeah, for sure.", "Pretty much." },
		nervous = { "Oh! Um, yes? I think so?", "Sorry, me? Yes!" },
		chatter = { "Oh absolutely, and let me tell you...", "Funny you should ask!" },
		dry = { "Something like that.", "If you say so." },
		nan = { "Oh, isn't that nice.", "That's lovely, dear." },
		teen = { "ya", "idk" },
		boss = { "Briefly.", "Can't talk long." },
	},
	-- staff
	work = {
		sunny = { "On it!", "Happy to help!", "Another one sparkling!" },
		grump = { "Who makes this much mess?", "Twenty years and still mopping.", "Nobody ever says thank you." },
		posh = { "Standards must be kept.", "A tidy hotel is a happy hotel." },
		chill = { "Easy does it.", "Just doing my thing." },
		nervous = { "Please let me do this right.", "Was it left or right? Left. Okay." },
		chatter = { "You'd not believe what I found under that bed!", "Busy busy busy!" },
		dry = { "Living the hospitality dream.", "Clean, rinse, repeat." },
		nan = { "There we go, nice and neat.", "A bit of elbow grease, that's all." },
		teen = { "is my shift over yet", "ok ok im going" },
		boss = { "Efficiency is everything.", "Next task." },
	},
	staffIdle = {
		sunny = { "Quiet moment! Nice.", "Who needs help?" },
		grump = { "Don't look at me. I'm on standby.", "My feet hurt." },
		posh = { "Awaiting instruction.", "All is in order." },
		chill = { "Slow day. I'm not complaining.", "Just chilling till something comes up." },
		nervous = { "Should I be doing something? I feel like I should be doing something.", "Is the boss watching?" },
		chatter = { "So did you hear about room 102? No? Neither did I, but I'm curious.", "Gossip break!" },
		dry = { "Standing. Professionally.", "Peak productivity." },
		nan = { "I'll put the kettle on in a minute.", "Nice to sit for a second." },
		teen = { "so bored", "can i go on break" },
		boss = { "Downtime is wasted time.", "Let's find something to fix." },
	},
	["break"] = {
		sunny = { "Break time! Back soon!", "Snack o'clock!" },
		grump = { "Finally. Five minutes of peace.", "Don't call me." },
		posh = { "A brief respite.", "Tea, I think." },
		chill = { "Taking five.", "Break? Don't mind if I do." },
		nervous = { "Is it okay if I take a break? It's okay? Okay.", "Just a short one, I promise!" },
		chatter = { "Break! Who wants to hear about my weekend?", "Ooh, I've got so much to tell the others." },
		dry = { "Off to stare at a wall. Different wall.", "Break. My favourite part of work." },
		nan = { "Time for a cuppa.", "Just resting my eyes." },
		teen = { "break finally", "brb" },
		boss = { "Quick break. Back in five. Exactly five.", "Recharging." },
	},
}

-- in their head, by situation (thoughts are quieter, more honest)
local THINK = {
	bedtime = {
		sunny = { "Big day tomorrow! Sleep!" }, grump = { "If the bed squeaks I'm complaining." }, posh = { "I do hope the sheets are cotton." },
		chill = { "Bed. Yes." }, nervous = { "What if there are noises at night..." }, chatter = { "I should call Mum before bed. And Auntie. And..." },
		dry = { "Sleep: my one true hobby." }, nan = { "Teeth in the glass, then bed." }, teen = { "one more video then sleep" }, boss = { "Six hours. Max." },
	},
	checkin = {
		sunny = { "Ooh, I wonder what my room looks like!" }, grump = { "This better be quick." }, posh = { "I do hope they have my preferences on file." },
		chill = { "Key, room, nap." }, nervous = { "Did I bring my ID? I brought my ID. Did I?" }, chatter = { "I'll ask about breakfast. And parking. And the pool!" },
		dry = { "The thrilling world of paperwork." }, nan = { "Where did I put my reading glasses..." }, teen = { "pls have good wifi" }, boss = { "Two minutes. That's all this should take." },
	},
	checkout = {
		sunny = { "Sad to go!" }, grump = { "Let's see what they charge me." }, posh = { "I shall settle the account." },
		chill = { "Back to reality, I guess." }, nervous = { "Did I leave anything? Charger. Got it. Socks?" }, chatter = { "I'll miss this place! And that nice plant!" },
		dry = { "Goodbye, bed. You were the best part." }, nan = { "I'll leave a little tip." }, teen = { "finally going home" }, boss = { "Expense it." },
	},
	hungry = {
		sunny = { "Mmm, I can smell food somewhere!" }, grump = { "I'd pay double for a sandwich right now." }, posh = { "Something light. With a garnish." },
		chill = { "Pizza. Pizza would hit." }, nervous = { "Is it weird to eat alone?" }, chatter = { "Croissant. Croissant croissant croissant." },
		dry = { "I'm hungry enough to eat the menu." }, nan = { "A nice scone would do me." }, teen = { "fries" }, boss = { "Protein bar. Desk. Done." },
	},
	tired = {
		sunny = { "Just a little rest..." }, grump = { "I'm too old for this." }, posh = { "A chaise longue would be ideal." },
		chill = { "Couch. Couch would be nice." }, nervous = { "Am I allowed to sit there?" }, chatter = { "My feet are TALKING to me." },
		dry = { "I could sleep on the floor. I might." }, nan = { "Where's a comfy chair..." }, teen = { "need to sit" }, boss = { "Push through. Push through." },
	},
	bored = {
		sunny = { "There must be something fun to do!" }, grump = { "I could be at home being bored for free." }, posh = { "A gallery would be nice." },
		chill = { "Maybe I'll wander." }, nervous = { "Should I go out? What if I get lost?" }, chatter = { "Who can I talk to?" },
		dry = { "I'm watching paint dry. Wait, that's a wall." }, nan = { "A crossword would be nice." }, teen = { "so bored rn" }, boss = { "I should be working." },
	},
	town = {
		sunny = { "Adventure time!" }, grump = { "Anywhere but here." }, posh = { "Let's see what culture this town offers." },
		chill = { "Let's see what's out there." }, nervous = { "Okay. Left at the corner. Then... I'll figure it out." }, chatter = { "I've heard SO much about this town!" },
		dry = { "Off to see the sights. All three of them." }, nan = { "A nice little stroll." }, teen = { "mom said go outside" }, boss = { "Meeting across town." },
	},
	waiting = {
		sunny = { "Patience! It'll be worth it." }, grump = { "Tick. Tock." }, posh = { "Most tedious." },
		chill = { "No rush." }, nervous = { "Should I say something?" }, chatter = { "I wonder what everyone else is here for." },
		dry = { "I'm becoming one with this spot." }, nan = { "I'll just stand here then." }, teen = { "hurry up" }, boss = { "Every minute here costs me." },
	},
	work = {
		sunny = { "Let's make it shine!" }, grump = { "Same mess, different day." }, posh = { "Precision. Always precision." },
		chill = { "One thing at a time." }, nervous = { "Don't mess up, don't mess up." }, chatter = { "I'll tell the others about this one later." },
		dry = { "Thrilling." }, nan = { "Nice and tidy." }, teen = { "ugh" }, boss = { "Fastest clean yet. Go." },
	},
	idle = {
		sunny = { "I love it here." }, grump = { "Why did I come here?" }, posh = { "One must make the best of things." },
		chill = { "This is nice." }, nervous = { "Did I leave the oven on?" }, chatter = { "I wonder what that person's story is." },
		dry = { "Riveting." }, nan = { "I should call my daughter." }, teen = { "what time is it" }, boss = { "Need to check my inbox." },
	},
}

-- status text (BWhat) -> a thought situation
local STATUS_KEY = {
	["Bedtime"] = "bedtime", ["Checking in"] = "checkin", ["At the desk"] = "checkin", ["Checking out"] = "checkout", ["Paying"] = "checkout",
	["Heading out"] = "town", ["Out for a walk"] = "town", ["Getting something to eat"] = "hungry", ["Midnight snack"] = "hungry",
	["Finding a seat"] = "tired", ["Exploring"] = "bored", ["Waiting for work"] = "idle", ["No clean rooms"] = "waiting", ["Waiting"] = "waiting",
	["Enjoying the lobby"] = "idle",
}

-- round 14 (2026-11-09): six more people to be. Each has its own lines for every situation below; anything
-- they have no line for, they keep to themselves.
do
	local NEW = {
		country = { deep = true, rate = 1.1 }, foodie = { deep = false, rate = 0.9 }, nerd = { deep = false, rate = 0.85 },
		dreamer = { deep = false, rate = 1.2 }, sporty = { deep = true, rate = 0.85 }, tourist = { deep = false, rate = 0.9 },
	}
	for k, v in pairs(NEW) do V.STYLES[k] = v table.insert(V.ORDER, k) end
	local L = {
		hello = {
			country = { "Howdy! Name's %s.", "Mornin'. %s, pleased to meet ya.", "Well hey there! %s. Drove in from the farm." },
			foodie = { "Hi! I'm %s. Quick question: is breakfast included?", "%s! Hello! Something smells amazing in here.", "Hey, I'm %s. I came for the restaurants, honestly." },
			nerd = { "Hello. %s. Fun fact: the word hotel comes from French.", "Hi, I'm %s. I read 214 reviews before booking.", "%s. Is the wifi 5 gigahertz? Asking for me." },
			dreamer = { "Hello... I'm %s. What a beautiful little place.", "%s. I hope the room has a window. I like to watch the clouds.", "Hi, I'm %s. I think I've dreamed about this lobby." },
			sporty = { "Hey! %s! Just ran here from the station!", "%s. Got a gym? Asking for a friend. The friend is me.", "What's up, I'm %s! Big race this weekend." },
			tourist = { "Hi! %s! First time in this city!", "Hello! I'm %s. Can I take a picture of the desk?", "%s here! Which way to the famous stuff?" },
		},
		waitLine = {
			country = { "Slow as molasses, this line.", "I've waited on cows that moved quicker." },
			foodie = { "Waiting makes me hungry. Everything makes me hungry.", "I packed a sandwich for exactly this." },
			nerd = { "Statistically, the other line is always faster.", "About four minutes per guest. I counted." },
			dreamer = { "Waiting is just a little pause in the song.", "Look how the light comes through the glass..." },
			sporty = { "Might do some lunges while I wait.", "Good time for a calf stretch." },
			tourist = { "Ooh, a line! Everyone wants to stay here!", "Let me get a photo of the line. For the memories." },
		},
		waitLong = {
			country = { "Gettin' a mite long now, partner.", "Sun's movin' faster than this line." },
			foodie = { "I've finished my sandwich. And my backup sandwich.", "If this takes longer I'm eating the brochures." },
			nerd = { "This is now officially above average wait time.", "I've calculated pi to twelve places while waiting." },
			dreamer = { "Maybe I'll just... live here. In the line.", "I've drifted off twice. Is it still today?" },
			sporty = { "My legs are getting cold. Not good.", "I could have done a 5K by now!" },
			tourist = { "My tour starts soon...", "Is the line part of the experience?" },
		},
		checkin = {
			country = { "Much obliged!", "Thank ya kindly.", "Well alright! That's mighty fine." },
			foodie = { "Thanks! Where's the nearest snack?", "Perfect! Now, about room service..." },
			nerd = { "Excellent. Room number noted.", "Thank you. Efficient process. Ten out of ten." },
			dreamer = { "Thank you... this key feels lucky.", "How lovely. Thank you." },
			sporty = { "Nice! Let's go!", "Thanks, champ!" },
			tourist = { "Thank you! Can you sign my guidebook?", "Yay! My first hotel key here!" },
		},
		roomGood = {
			country = { "Now that's a proper bed.", "Cosy as a barn in winter." },
			foodie = { "Is that a mini fridge? Please say yes.", "Good bed for eating crackers in. Not that I would." },
			nerd = { "Thread count looks above 300. Nice.", "Ideal room temperature. I checked." },
			dreamer = { "Oh, it's like a little cloud.", "I could write a poem in here." },
			sporty = { "Good firm mattress. Great for the back.", "Room for push-ups. Perfect." },
			tourist = { "Look at this! Taking a picture!", "So pretty! My friends will be jealous." },
		},
		roomDirty = {
			country = { "Looks like a pig pen in here.", "Somebody forgot their chores." },
			foodie = { "Are those crumbs? From WHAT though?", "Someone ate in here. Badly." },
			nerd = { "I'd estimate eleven separate stains.", "This violates at least three hygiene standards." },
			dreamer = { "Oh... the magic is a little dusty.", "Someone else's dream left a mess." },
			sporty = { "Gross. Not a great warm-up.", "Towel on the floor. Foul!" },
			tourist = { "Not putting this one on my photo wall.", "Is this... a local tradition?" },
		},
		hungry = {
			country = { "I could eat a whole pot of chili.", "Belly's rumblin' like a tractor." },
			foodie = { "What's the best thing on the menu? Bring me two.", "I've been thinking about lunch since breakfast.", "Snack o'clock!" },
			nerd = { "My blood sugar is approaching critical.", "Time to refuel. 600 calories at least." },
			dreamer = { "I'd love some warm bread and honey...", "Is there somewhere with candles to eat?" },
			sporty = { "Need protein. Lots of it.", "Carb loading time!" },
			tourist = { "I want to try the local food!", "Where do the locals eat?" },
		},
		tired = {
			country = { "Plum tuckered out.", "Time to hit the hay." },
			foodie = { "Food coma incoming.", "I ate too much. Need a nap." },
			nerd = { "Eight hours of sleep is optimal. I'm behind.", "My brain needs to defragment." },
			dreamer = { "Time to go dream somewhere new.", "So sleepy... the stars are out." },
			sporty = { "Recovery is part of training.", "Legs are toast. Bed time." },
			tourist = { "So much walking today!", "I saw twelve sights. I am exhausted." },
		},
		bored = {
			country = { "Not much to do 'round here, huh?", "Reckon I'll go whittle somethin'." },
			foodie = { "Bored. Hungry. Same thing really.", "Maybe I'll look at the menu again." },
			nerd = { "I've read every sign in this lobby twice.", "Is there a chess set anywhere?" },
			dreamer = { "I'll just look out the window for a while.", "Hmm. Do the paintings change at night?" },
			sporty = { "Need something to do. Anything active.", "Anyone up for a game?" },
			tourist = { "What else is there to see?", "I've photographed everything. Twice." },
		},
		idle = {
			country = { "Nice day for it.", "My pa would've liked this place.", "Smells like rain's comin'." },
			foodie = { "I wonder what the chef's special is.", "Do they do pancakes here? I hope they do pancakes.", "I can smell coffee somewhere." },
			nerd = { "That chandelier has 24 bulbs.", "Interesting floor tiling. Very efficient.", "Did you know the first hotel elevator was in 1859?" },
			dreamer = { "This place has a nice feeling.", "I wonder who stayed here before me.", "The plants look happy." },
			sporty = { "Stairs or elevator? Stairs. Always stairs.", "Ten thousand steps today, easy.", "Gotta stay hydrated." },
			tourist = { "I love this city!", "Must buy a postcard.", "Is that a famous building? It looks famous." },
		},
		rain = {
			country = { "Good rain for the crops.", "Comin' down like a cow on a flat rock." },
			foodie = { "Rainy days are soup days.", "Perfect weather for hot chocolate." },
			nerd = { "About two inches an hour, I'd say.", "Fun fact: rain smells because of bacteria." },
			dreamer = { "I love the sound of the rain...", "Every drop is a little song." },
			sporty = { "Running in the rain builds character.", "No rain day for me!" },
			tourist = { "Oh no, my tour!", "Rain photos can be pretty too, right?" },
		},
		leaveHappy = {
			country = { "Y'all take care now!", "Best stay I've had in years. Thank ya!" },
			foodie = { "Five stars. Mostly for the snacks.", "I'll be back. Hungry." },
			nerd = { "Rating: 4.9. I'm a tough grader.", "Excellent stay. I made a spreadsheet about it." },
			dreamer = { "I'll dream about this place.", "Goodbye, lovely little hotel." },
			sporty = { "Great stay! Gotta run. Literally.", "Thanks! Personal best sleep!" },
			tourist = { "Best trip ever! Thank you!", "I'm telling everyone about this place!" },
		},
		leaveAngry = {
			country = { "Well, that weren't right.", "I'll be tellin' folks back home about this." },
			foodie = { "Not even a mint on the pillow.", "Terrible. And I'm STILL hungry." },
			nerd = { "I'm writing a very detailed review.", "Two stars. And that's generous." },
			dreamer = { "That was more of a nightmare.", "I'll try to forget this one." },
			sporty = { "Worst warm-down ever.", "Not cool. Not cool at all." },
			tourist = { "Not in the guidebook for a reason.", "I'm deleting my photos." },
		},
		bumpSorry = {
			country = { "Whoa there!", "Pardon me, friend." },
			foodie = { "Oop! Almost dropped my snack!", "Sorry! Hungry and clumsy." },
			nerd = { "Sorry, my fault. Spatial awareness.", "Oh! Collision. Apologies." },
			dreamer = { "Oh! Sorry, I was miles away.", "Sorry... I was daydreaming." },
			sporty = { "My bad! Good reflexes though.", "Whoa, sorry, coming through!" },
			tourist = { "Sorry! I was looking at the map!", "Oops! Sorry, sorry!" },
		},
		greetPlayer = {
			country = { "Howdy, boss!", "Fine hotel you got here." },
			foodie = { "Hi! What's good to eat around here?", "Hey! Is there a kitchen? I need to know." },
			nerd = { "Hello! Did you design the floor plan?", "Hi! Your occupancy rate looks good." },
			dreamer = { "Oh, hello. You have a kind face.", "Hi... is it always this peaceful?" },
			sporty = { "Hey! Up top!", "Yo! Nice hustle running this place!" },
			tourist = { "Hello! Can I take a selfie with you?", "Hi! Are you the famous owner?" },
		},
		smallTalk = {
			country = { "You ever been to a county fair?", "Weather's been kind this year.", "Pie's better back home. Don't tell 'em I said that." },
			foodie = { "Have you tried the bakery down the street?", "I rate cities by their noodles.", "Sweet or savoury breakfast? Wrong. Both." },
			nerd = { "Have you read anything good lately?", "I'm building a robot at home. It's mostly wires right now.", "Did you know octopuses have three hearts?" },
			dreamer = { "Do you ever wonder where clouds go?", "I think every room has a story.", "I'd love to live by the sea one day." },
			sporty = { "Do you lift?", "Marathon next month. Wish me luck.", "Ever tried paddle boarding? So good." },
			tourist = { "Where should I go next?", "I've been to nine countries this year!", "Is the museum open on Sundays?" },
		},
		reply = {
			country = { "You don't say!", "Ain't that the truth.", "Well I'll be." },
			foodie = { "Ooh, that sounds delicious.", "Mmhm. Speaking of food..." },
			nerd = { "Fascinating.", "Statistically, yes.", "Actually... yes, you're right." },
			dreamer = { "Mm, that's beautiful.", "I like that." },
			sporty = { "Totally!", "Let's go!", "For real!" },
			tourist = { "Wow! Really?", "I'll write that down!" },
		},
		work = {
			country = { "Hard work never hurt nobody.", "Gettin' it done." },
			foodie = { "Work now, lunch after.", "This is going faster than my lunch break." },
			nerd = { "Optimising my route.", "Efficiency at ninety-something percent." },
			dreamer = { "Little by little, it gets lovely.", "I like making things shine." },
			sporty = { "Good cardio, this job.", "Speed run!" },
			tourist = { "I love working in a city like this!", "New job, new adventure!" },
		},
		staffIdle = {
			country = { "Quiet as a Sunday.", "Might sweep the porch." },
			foodie = { "Is it lunch yet?", "I brought leftovers." },
			nerd = { "I'll reorganise the supply shelf. Alphabetically.", "Downtime. Reading a manual." },
			dreamer = { "I like the hotel when it's quiet.", "Just watching the street for a bit." },
			sporty = { "Quick stretch break.", "I'll do some squats in the back." },
			tourist = { "I should explore the hotel more.", "Every corner here is cute." },
		},
	}
	for key, byVoice in pairs(L) do
		SAY[key] = SAY[key] or {}
		for v, list in pairs(byVoice) do SAY[key][v] = list end
	end
end

function V.of(model)
	if not model then return "chill" end
	local v = model:GetAttribute("Voice")
	if v and V.STYLES[v] then return v end
	v = V.ORDER[rng:NextInteger(1, #V.ORDER)]
	-- a Karen speaks like one
	if model:GetAttribute("GuestType") == "karen" then v = rng:NextNumber() < 0.6 and "grump" or "boss" end
	model:SetAttribute("Voice", v)
	local st = V.STYLES[v]
	local deep = st.deep
	if model:GetAttribute("Deep") == nil then model:SetAttribute("Deep", deep) end
	model:SetAttribute("VoiceRate", st.rate)
	return v
end

local function firstName(model)
	local n = model:GetAttribute("BName") or model.Name
	return n:match("^(%S+)") or n
end

function V.line(model, key)
	local bank = SAY[key]
	if not bank then return nil end
	local l = pick(bank[V.of(model)])
	if l and l:find("%%s") then l = l:format(firstName(model)) end
	return l
end

function V.thoughtKey(status)
	if not status then return nil end
	if STATUS_KEY[status] then return STATUS_KEY[status] end
	local s = status:lower()
	if s:find("clean") or s:find("mop") or s:find("cook") or s:find("fix") or s:find("serv") or s:find("carry") then return "work" end
	if s:find("wait") then return "waiting" end
	return nil
end

function V.thought(model, status)
	local key = V.thoughtKey(status)
	local bank = key and THINK[key]
	return bank and pick(bank[V.of(model)]) or nil
end

-- small habits on lines written elsewhere
function V.flavor(model, line)
	if type(line) ~= "string" or line == "" or not model then return line end
	local v = V.of(model)
	local r = rng:NextNumber()
	if v == "sunny" and r < 0.45 then line = line:gsub("%.$", "!")
	elseif v == "nervous" and r < 0.3 then line = "Um, " .. line:sub(1, 1):lower() .. line:sub(2)
	elseif v == "grump" and r < 0.2 then line = line .. " Typical."
	elseif v == "posh" then line = line:gsub("[Gg]reat", "splendid"):gsub("[Aa]wesome", "marvellous"):gsub("[Rr]eally", "terribly")
	elseif v == "nan" and r < 0.3 then line = line:gsub("[%.!]$", "") .. ", dear."
	elseif v == "teen" and r < 0.6 then line = line:lower():gsub("%.$", "")
	elseif v == "chill" and r < 0.2 then line = "Honestly? " .. line
	elseif v == "chatter" and r < 0.25 then line = line .. " Anyway!"
	elseif v == "dry" and r < 0.15 then line = line .. " Wonderful."
	elseif v == "country" and r < 0.25 then line = line:gsub("ing([%s%p])", "in'%1")
	elseif v == "sporty" and r < 0.2 then line = line .. " Let's go!"
	elseif v == "nerd" and r < 0.15 then line = "Technically, " .. line:sub(1, 1):lower() .. line:sub(2)
	elseif v == "dreamer" and r < 0.25 then line = line:gsub("[%.!]$", "...")
	elseif v == "tourist" and r < 0.2 then line = "Wow! " .. line
	elseif v == "foodie" and r < 0.12 then line = line .. " Also, I'm hungry."
	end
	return line
end

---------------------------------------------------------------- the background life

local lastSaid = setmetatable({}, { __mode = "k" })
local function free(model, gap)
	return os.clock() - (lastSaid[model] or -99) > (gap or 9)
end
local sayFn
function V.say(model, line, secs, mode)
	if not line or not model or not model.Parent then return end
	lastSaid[model] = os.clock()
	if sayFn then sayFn(model, line, secs, mode) end
end

local bumped = {}
function V.bump(a, b)
	if not (a and b) or a == b then return end
	local key = a.Name .. "|" .. b.Name
	if os.clock() - (bumped[key] or -99) < 7 then return end
	bumped[key] = os.clock()
	bumped[b.Name .. "|" .. a.Name] = os.clock()
	-- a little shove: the one walked into rocks back
	local ra, rb = a:FindFirstChild("HumanoidRootPart"), b:FindFirstChild("HumanoidRootPart")
	if ra and rb and not rb.Anchored and not Players:GetPlayerFromCharacter(b) then
		local d = rb.Position - ra.Position
		d = Vector3.new(d.X, 0, d.Z)
		if d.Magnitude > 0.01 then
			pcall(function() rb.AssemblyLinearVelocity += d.Unit * 9 + Vector3.new(0, 4, 0) end)
		end
	end
	a:SetAttribute("Bump", (a:GetAttribute("Bump") or 0) + 1)
	b:SetAttribute("Bump", (b:GetAttribute("Bump") or 0) + 1)
	if free(a, 3) and rng:NextNumber() < 0.75 then V.say(a, V.line(a, "bumpSorry"), 2.4) end
	if not Players:GetPlayerFromCharacter(b) and free(b, 3) and rng:NextNumber() < 0.5 then
		task.delay(0.7, function() V.say(b, V.line(b, "bumpSorry"), 2.4) end)
	end
end

local function isStaff(m) return m:GetAttribute("BRole") ~= nil end
local function root(m) return m:FindFirstChild("HumanoidRootPart") end

local function needKey(m)
	local f = m:GetAttribute("Feel")
	return (f == "Hungry" and "hungry") or (f == "Tired" and "tired") or (f == "Bored" and "bored") or (f == "Lonely" and "lonely") or nil
end

function V.start(folder, fn, weatherFn)
	sayFn = fn
	local greeted = setmetatable({}, { __mode = "k" })
	task.spawn(function()
		while folder.Parent do
			task.wait(rng:NextNumber(2.2, 3.6))
			local list = {}
			for _, m in ipairs(folder:GetChildren()) do
				local r = m:IsA("Model") and root(m)
				if r and m:GetAttribute("BName") and not r.Anchored then table.insert(list, m) end
			end
			if #list > 0 then
				local m = list[rng:NextInteger(1, #list)]
				local r = root(m)
				if free(m, 14) then
					local staff = isStaff(m)
					-- a player close by: say hello (once a visit)
					local near
					for _, p in ipairs(Players:GetPlayers()) do
						local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if pr and (pr.Position - r.Position).Magnitude < 9 then near = p end
					end
					local partner
					for _, o in ipairs(list) do
						if o ~= m and not isStaff(o) and (root(o).Position - r.Position).Magnitude < 8 and free(o, 6) then partner = o break end
					end
					local roll = rng:NextNumber()
					if near and not staff and not greeted[m] then
						greeted[m] = true
						V.say(m, rng:NextNumber() < 0.5 and V.line(m, "hello") or V.line(m, "greetPlayer"), 3.2)
					elseif partner and not staff and roll < 0.45 then
						V.say(m, V.line(m, "smallTalk"), 3)
						task.delay(2.4, function() V.say(partner, V.line(partner, "reply"), 2.6) end)
					elseif roll < 0.55 then
						-- a thought that fits what they're doing
						local t = V.thought(m, m:GetAttribute("BWhat")) or (rng:NextNumber() < 0.5 and pick(THINK.idle[V.of(m)]))
						if t then V.say(m, t, 3, "think") end
					else
						local key
						if staff then
							local w = (m:GetAttribute("BWhat") or ""):lower()
							key = (w:find("break") and "break") or (w:find("wait") and "staffIdle") or "work"
						else
							local wet = weatherFn and weatherFn()
							key = needKey(m) or ((wet == "rain" or wet == "storm") and rng:NextNumber() < 0.4 and "rain") or "idle"
						end
						V.say(m, V.line(m, key), 3)
					end
				end
			end
		end
	end)
end

return V
