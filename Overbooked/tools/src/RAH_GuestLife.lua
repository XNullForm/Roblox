-- ServerStorage.RAH_GuestLife (round 10c): the little things guests do between the big ones, so no two stays
-- play out the same. RAH_HotelSim calls Life.outing(ctx, g, where) after check-in ("lobby") and between room
-- activities ("stay"); it picks something that fits (weather, the hotel's furniture, who's around, the guest's
-- mood) and plays it out:
--   sit     : rest on a lobby seat           photo : snap a picture of the decor (a camera flash)
--   chat    : talk with another guest         phone : take a call
--   staff   : ask a staff member something    walk  : a stroll outside (not in the rain)
--   player  : walk up to you with a compliment or a complaint (talk to them to answer it)
--   stretch : stretch / dance by the music    snack : vending machine, coffee bar or water cooler
--   eat     : order a meal at the serving counter, collect it, eat at a table (RAH_Kitchen, once per stay)
-- A guest who's sitting, admiring or on the phone can be chatted to (g.chatWith); Life.idle waits and joins in.
-- Life.queueChat has two people in the line outside swap a line.
local C = require(game:GetService("ReplicatedStorage"):WaitForChild("RAH"):WaitForChild("Config"))
local Life = {}

Life.CHATS = { -- guest to guest: opener, reply, closer
	{ "Is this your first time here?", "Yes! It's lovely, isn't it?", "I'll be back for sure." },
	{ "Did you see the lobby?", "So fancy! I took photos." },
	{ "Where are you from?", "Just up the road. You?", "Oh, much further away!" },
	{ "Have you tried the beds yet?", "Like sleeping on a cloud." },
	{ "The service here is quick!", "I know! In and out." },
	{ "Any plans for today?", "Just relaxing, honestly.", "Best plan there is." },
	{ "I love what they did with this place.", "Same! Very stylish." },
	{ "Nice shirt!", "Thanks! It was a gift." },
	{ "Is it me or is it busy today?", "Everyone wants a room here!" },
	{ "How's your room?", "Cozy! Yours?", "Same, I love it." },
	{ "Do you know a good place to eat?", "Ask the front desk!" },
}
Life.QUEUE = { -- the line outside: the one behind says, the one in front answers
	{ "Long line, huh?", "Worth it, I heard!" },
	{ "Have you stayed here before?", "First time! You?" },
	{ "I hope they have rooms left.", "Fingers crossed!" },
	{ "Nice day for it.", "Sure is!" },
	{ "What's taking so long?", "Patience, patience." },
}
Life.ASK = { -- guest to staff: question, answer
	receptionist = {
		{ "Could I get a late checkout?", "I'll see what I can do!" },
		{ "Any good food nearby?", "The cafe down the street is great." },
		{ "What's the wifi password?", "It's on the card in your room!" },
		{ "Can I get a wake-up call?", "Of course! What time?" },
	},
	janitor = {
		{ "Could I get extra towels?", "Right away!" },
		{ "You keep this place spotless!", "Just doing my job!" },
		{ "Is the floor wet here?", "Careful, just mopped it!" },
	},
	doorman = {
		{ "Lovely day, isn't it?", "Perfect for a walk!" },
		{ "Can you call me a taxi?", "One's on its way!" },
	},
}
Life.TO_PLAYER = {
	good = { "I just wanted to say I love it here!", "This hotel is wonderful, thank you!", "Best stay I've had in ages!", "Your staff are so lovely!" },
	bad = { "Excuse me, I have a complaint.", "Can we talk? I'm not very happy.", "Something's not right here..." },
}
Life.PHONE = { "Yes, Mom, the hotel's lovely.", "I'll call you back!", "No, I'm on holiday!", "You should see this place!", "Uh huh... uh huh..." }
Life.PHOTO = { "Gotta post this!", "Say cheese!", "So pretty!", "One more photo..." }
Life.WALK = { "Going for a walk!", "Some fresh air.", "Time to explore the town!" }
Life.WALK_BACK = { "What a nice town.", "Back already!", "My feet hurt." }
Life.RAIN = { "It's pouring out there!", "Not going out in this rain.", "Maybe later, it's wet out." }
Life.SNOW = { "Brr! Too cold for a walk.", "Look at the snow!" }
Life.SIT = { "Ahh, comfy.", "Just resting my feet.", "Nice spot to sit." }
Life.STRETCH = { "Long day...", "Need to stretch my legs." }
Life.DANCE = { "I love this song!", "Dance break!", "Woo!" }

-- seats on each lobby piece, relative to its pivot (floor centre, front = +Z): x, z, seat top, facing (degrees
-- about Y from +Z). Measured from the Blender builders (rah_props*.py).
local SEATS = {
	Sofa = { { -2.0, 0.3, 2.35 }, { 2.0, 0.3, 2.35 } }, -- two, not three: blocky shoulders need room
	Armchair = { { 0, 0.25, 2.1 } },
	Loveseat = { { -1.3, 0.3, 1.9 }, { 1.3, 0.3, 1.9 } },
	Sectional = { { -2.4, 0.35, 1.9 }, { 1.6, 0.35, 1.9 } },
	LoungeChair = { { 0, 0.15, 1.95 } },
	MassageChair = { { 0, 0.25, 2.0 } },
	Ottoman = { { 0, 0, 1.75 } },
	BarStool = { { 0, 0, 3.43 } },
	DiningSet = { { 3.1, 0, 2.1, -90 }, { 0, -3.1, 2.1, 0 }, { -3.1, 0, 2.1, 90 }, { 0, 3.1, 2.1, 180 } },
	CafeTable = { { -2.05, 0, 1.9, 90 }, { 2.05, 0, 1.9, -90 } }, -- the bistro chairs either side
	DiningChair = { { 0, 0, 2.3 } },
	ReadingNook = { { 0, 0.2, 2.35 } },
	LobbyBench = { { -2.1, 0, 2.2 }, { 0, 0, 2.2 }, { 2.1, 0, 2.2 } },
	Beanbag = { { 0, 0.2, 2.1 } },
	ParkBench = { { -1.6, 0.1, 1.95 }, { 1.6, 0.1, 1.95 } },
}
Life.SEATS = SEATS -- round 12: the sim gives players the same seats (DecorSeat<i>)
local TABLES = { CafeTable = true, DiningSet = true } -- seats with a table to eat at
local BESIDE = { CafeTable = true, DiningSet = true } -- chairs you step into from the side
local SIT_UP = 0.95 -- root above the seat top while sitting (the toilet's sit spot)
local MUSIC = { Jukebox = true, GrandPiano = true }
Life.ORDER = { "One %s, please!", "Could I get the %s?", "I'll have the %s, thanks.", "The %s sounds perfect.", "%s for me, please!" }
Life.HUNGRY = { "Smells amazing back there.", "I'm starving...", "Is my order nearly up?", "Can't wait to eat." }
Life.THANKS_FOOD = { "Thank you!", "Looks delicious!", "Oh, that smells great.", "Perfect, thanks!" }
Life.YUM = { "Wow, that was incredible!", "Best meal I've had all week!", "My compliments to the chef!" }
Life.FED = { "That hit the spot.", "Nice and filling.", "Mm, not bad at all." }

local SNACK = { VendingMachine = "Grabbing a snack", CoffeeBar = "Getting a coffee", WaterCooler = "Getting some water" }
local taken = {} -- seat key -> guest
local playerGap = {} -- player -> time a guest may next walk up to them

local function pick(rng, t) return t[rng:NextInteger(1, #t)] end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

local function weather()
	return game:GetService("ReplicatedStorage").RAH:GetAttribute("Weather") or "sun"
end
Life.weather = weather

-- a stable key per model (GetDebugId needs Plugin capability, so game scripts can't use it)
local modelKeys = setmetatable({}, { __mode = "k" })
local nextKey = 0
local function keyOf(m)
	local k = modelKeys[m]
	if not k then
		nextKey += 1
		k = tostring(nextKey)
		modelKeys[m] = k
	end
	return k
end

-- a free lobby seat: { cf = sit CFrame, stand = Vector3, key }
local function freeSeat(ctx, g, only)
	local list = {}
	for _, e in ipairs(ctx.lobbyItems()) do
		local id = e.model:GetAttribute("Item") or ""
		local seats = (not only or only[id]) and SEATS[id]
		if seats then
			local piv = e.model:GetPivot()
			for i, s in ipairs(seats) do
				local key = keyOf(e.model) .. ":" .. i
				local o = taken[key]
				local ps = e.model:FindFirstChild("DecorSeat" .. i)
				if not (o and o.alive) and not (ps and ps.Occupant) then
					-- the sit spot, and a spot a step in front of the seat (beside it, for dining chairs)
					local cf = piv * CFrame.new(s[1], s[3] + SIT_UP, s[2]) * CFrame.Angles(0, math.rad(s[4] or 0), 0) * CFrame.Angles(0, math.pi, 0)
					local stand = BESIDE[id] and cf * CFrame.new(-2.2, 0, 0) or cf * CFrame.new(0, 0, -2.4)
					table.insert(list, {
						key = key, id = id, cf = cf, model = e.model,
						stand = Vector3.new(stand.X, piv.Y + 3, stand.Z),
						d = (piv.Position - g.root.Position).Magnitude,
					})
				end
			end
		end
	end
	if #list == 0 then return nil end
	table.sort(list, function(a, b) return a.d < b.d end)
	return list[ctx.rng:NextInteger(1, math.min(3, #list))]
end

local function itemMatching(ctx, set)
	local out = {}
	for _, e in ipairs(ctx.lobbyItems()) do
		if set[e.model:GetAttribute("Item") or ""] then table.insert(out, e) end
	end
	return #out > 0 and out[ctx.rng:NextInteger(1, #out)] or nil
end

-- wait out `secs`; if another guest comes to chat, face them while they do
function Life.idle(ctx, g, secs)
	g.chatOK = true
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < secs do
		if g.chatWith then
			local other = g.chatWith
			if not g.posed and other.root then ctx.faceTo(g, other.root.Position) end
			while g.alive and g.chatWith == other and other.alive do task.wait(0.2) end
			g.chatWith = nil
			t0 += 1.5 -- linger a little after a chat
		end
		task.wait(0.2)
	end
	g.chatOK = false
end

-- someone in the lobby who'd like a chat (standing or sitting about, not busy)
local function chatPartner(ctx, g)
	local best, bd
	for other in pairs(ctx.guests) do
		if other ~= g and other.alive and other.chatOK and not other.chatWith and other.root then
			local d = (other.root.Position - g.root.Position).Magnitude
			if d < 60 and (not bd or d < bd) then best, bd = other, d end
		end
	end
	return best
end

-- a staff member nearby who's standing still (not mid-job across the hotel)
local function staffNear(ctx, g)
	local list = {}
	for _, s in ipairs(ctx.staff or {}) do
		local sg = s.g
		if sg and sg.alive and sg.root and s.def and Life.ASK[s.def.id] and not sg.busyTalk
			and (sg.root.Position - g.root.Position).Magnitude < 70
			and flat(sg.root.AssemblyLinearVelocity).Magnitude < 1 then
			table.insert(list, s)
		end
	end
	return #list > 0 and list[ctx.rng:NextInteger(1, #list)] or nil
end

-- a member of this hotel standing inside it, who hasn't been walked up to lately
local function playerNear(ctx, g)
	local now = os.clock()
	local inside = ctx.NAV.Inside.Position
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and ctx.isMember(p) and now >= (playerGap[p] or 0) and not p:GetAttribute("RAH_Building") then
			local d = flat(root.Position - inside).Magnitude
			if d < 55 and math.abs(root.Position.Y - inside.Y) < 9 and (root.Position - g.root.Position).Magnitude < 70 then
				return p, root
			end
		end
	end
end

---------------------------------------------------------------- the outings

local DO = {}

DO.sit = function(ctx, g)
	local seat = freeSeat(ctx, g)
	if not seat then return false end
	taken[seat.key] = g
	ctx.status(g, "walk", "Finding a seat")
	ctx.walkTo(g, Vector3.new(seat.stand.X, g.root.Position.Y, seat.stand.Z))
	if not g.alive then taken[seat.key] = nil return true end
	ctx.faceTo(g, seat.stand + flat(seat.cf.LookVector) * -3)
	ctx.status(g, "guest", seat.id == "MassageChair" and "Getting a massage" or "Relaxing")
	ctx.pose(g, seat.cf)
	ctx.play(g, "sit", 0.25)
	if seat.id == "MassageChair" then
		ctx.say(g, "Ohh, that's the spot...", 2.5)
		ctx.moodShift(g, 4, "The massage chair was heaven!", "Loved the massage chair.")
	elseif ctx.rng:NextNumber() < 0.6 then
		ctx.say(g, pick(ctx.rng, Life.SIT), 2.5)
	end
	Life.idle(ctx, g, ctx.rng:NextNumber(7, 13))
	ctx.stop(g, "sit", 0.2)
	ctx.unpose(g, CFrame.lookAt(seat.stand, seat.stand + flat(seat.cf.LookVector)))
	taken[seat.key] = nil
	return true
end

DO.chat = function(ctx, g)
	local other = chatPartner(ctx, g)
	if not other then return false end
	other.chatWith = g
	ctx.status(g, "chat", "Saying hi")
	-- walk up to them and stand a step away, face to face
	local to = flat(g.root.Position - other.root.Position)
	if to.Magnitude < 0.1 then to = Vector3.new(0, 0, 1) end
	local spot = other.root.Position + to.Unit * 3.2
	ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
	if not (g.alive and other.alive and other.chatWith == g) then other.chatWith = nil return true end
	ctx.faceTo(g, other.root.Position)
	ctx.status(g, "chat", "Chatting")
	local talk = pick(ctx.rng, Life.CHATS)
	for i, line in ipairs(talk) do
		if not (g.alive and other.alive) then break end
		ctx.say(i % 2 == 1 and g or other, line, 2.6)
		task.wait(2.4)
	end
	ctx.play(g, "wave_small")
	if not other.posed then ctx.play(other, "nod") end
	ctx.moodShift(g, 2)
	ctx.moodShift(other, 2)
	other.chatWith = nil
	task.wait(0.8)
	return true
end

DO.staff = function(ctx, g)
	local s = staffNear(ctx, g)
	if not s then return false end
	local sg = s.g
	sg.busyTalk = true
	ctx.status(g, "chat", "Asking the " .. string.lower(s.def.name or s.def.id))
	local to = flat(g.root.Position - sg.root.Position)
	if to.Magnitude < 0.1 then to = Vector3.new(0, 0, 1) end
	local spot = sg.root.Position + to.Unit * 3.4
	ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
	if not (g.alive and sg.alive) then sg.busyTalk = nil return true end
	ctx.faceTo(g, sg.root.Position)
	if not sg.posed then ctx.faceTo(sg, g.root.Position) end
	local qa = pick(ctx.rng, Life.ASK[s.def.id])
	ctx.say(g, qa[1], 2.8)
	task.wait(2.4)
	if sg.alive then
		ctx.say(sg, qa[2], 2.8)
		if not sg.posed then ctx.play(sg, "nod") end
	end
	task.wait(2)
	ctx.moodShift(g, 3, "The staff were really helpful.", "Helpful staff.")
	sg.busyTalk = nil
	return true
end

DO.player = function(ctx, g, forceKind)
	local mood = g.mood or 65
	local kind = forceKind or (mood >= 72 and "good") or (mood <= 44 and "bad") or nil
	if not kind then return false end
	local p, root = playerNear(ctx, g)
	if not p then return false end
	playerGap[p] = os.clock() + 45
	ctx.status(g, kind == "good" and "heart" or "angry", kind == "good" and "Wants to say thanks" or "Has a complaint")
	ctx.say(g, "Excuse me!", 2)
	-- follow them for a little while, stopping a few steps away
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < 10 do
		root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not root then break end
		local off = flat(g.root.Position - root.Position)
		if off.Magnitude < 5.5 then break end
		local spot = root.Position + (off.Magnitude > 0.1 and off.Unit or Vector3.new(0, 0, 1)) * 4
		g.hum:MoveTo(Vector3.new(spot.X, g.root.Position.Y, spot.Z))
		task.wait(0.25)
	end
	g.hum:Move(Vector3.zero)
	if not (g.alive and root) then return true end
	ctx.faceTo(g, root.Position)
	ctx.play(g, kind == "good" and "wave_small" or "arms_out")
	g.wantsWord = { kind = kind, t = os.clock(), player = p }
	local karen = kind == "bad" and g.gtype and g.gtype.id == "karen"
	ctx.say(g, pick(ctx.rng, karen and Life.KAREN_DEMAND or Life.TO_PLAYER[kind]), 4)
	if karen then ctx.play(g, "point_angry") end
	ctx.Notify:FireClient(p, "toast", { text = g.name .. (kind == "good" and " has a compliment for you" or " has a complaint. Talk to them!"), icon = kind == "good" and "heart" or "angry", bad = kind == "bad" })
	-- give them a moment to answer (the talk prompt clears wantsWord)
	local w0 = os.clock()
	while g.alive and g.wantsWord and os.clock() - w0 < 14 do
		if root.Parent and not g.posed then ctx.faceTo(g, root.Position) end
		task.wait(0.3)
	end
	if g.alive and g.wantsWord then
		g.wantsWord = nil
		if kind == "bad" and g.gtype and g.gtype.id == "karen" then
			Life.scene(ctx, g)
			ctx.moodShift(g, -5, "The owner IGNORED me.", "The owner ignored my complaint. Disgraceful.")
		elseif kind == "bad" then
			ctx.say(g, "Fine. I'll put it in my review.", 3)
			ctx.moodShift(g, -4, "Nobody listened to me.", "Staff ignored my complaint.")
		else
			ctx.say(g, "Anyway, have a nice day!", 2.5)
		end
		task.wait(1.5)
	end
	return true
end

-- the talk prompt calls this: answering a guest who came up to you
function Life.answered(ctx, g)
	local w = g.wantsWord
	if not w or os.clock() - w.t > 20 then return nil end
	g.wantsWord = nil
	if w.kind == "bad" and g.gtype and g.gtype.id == "karen" then
		ctx.moodShift(g, 3)
		g.talkNext = { ids = { "listen", "manager", "discount", "refuse", "bye" }, t = os.clock() }
		return "FINALLY. Are you the manager? I have a list."
	end
	if w.kind == "bad" then
		ctx.moodShift(g, 9, "They actually listened to my complaint!", "They listened to my complaint.")
		return "Thanks for listening. I feel better."
	end
	ctx.moodShift(g, 3)
	return "Keep up the great work!"
end

DO.photo = function(ctx, g)
	local items = ctx.lobbyItems()
	if #items == 0 then return false end
	local e = items[ctx.rng:NextInteger(1, #items)]
	local piv = e.model:GetPivot().Position
	local dir = flat(piv - g.root.Position)
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
	local spot = piv - dir.Unit * 4.5
	ctx.status(g, "walk", "Exploring")
	ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
	if not g.alive then return true end
	ctx.faceTo(g, piv)
	ctx.status(g, "star", "Taking photos")
	ctx.play(g, "@photo")
	task.wait(0.5)
	for i = 1, ctx.rng:NextInteger(1, 3) do
		task.wait(ctx.rng:NextNumber(0.8, 1.6))
		if not g.alive then return true end
		if ctx.burst then ctx.burst(g.head.Position + g.root.CFrame.LookVector * 0.8 + Vector3.new(0, 0.2, 0), "flash", 1) end
		ctx.sfx("camera", g.head.Position)
		if i == 1 then ctx.say(g, pick(ctx.rng, Life.PHOTO), 2.4) end
	end
	task.wait(0.6)
	ctx.stop(g, "@photo")
	Life.idle(ctx, g, ctx.rng:NextNumber(2, 4))
	return true
end

DO.phone = function(ctx, g)
	ctx.status(g, "chat", "On the phone")
	ctx.play(g, "@phone")
	ctx.say(g, pick(ctx.rng, Life.PHONE), 3)
	Life.idle(ctx, g, 3.5)
	if g.alive then ctx.say(g, pick(ctx.rng, Life.PHONE), 3) end
	Life.idle(ctx, g, ctx.rng:NextNumber(2.5, 5))
	ctx.stop(g, "@phone")
	return true
end

DO.walk = function(ctx, g)
	local w = weather()
	if w == "rain" or w == "storm" or w == "snow" then
		ctx.say(g, pick(ctx.rng, w == "snow" and Life.SNOW or Life.RAIN), 3)
		return false
	end
	ctx.status(g, "walk", "Out for a walk")
	ctx.say(g, pick(ctx.rng, Life.WALK), 2.5)
	ctx.walkTo(g, ctx.NAV.PathStart.Position)
	if not g.alive then return true end
	-- along the sidewalk a little way and back
	local side = (ctx.rng:NextNumber() < 0.5) and ctx.NAV.Street or ctx.NAV.StreetExit
	local p0 = ctx.NAV.PathStart.Position
	local to = p0 + (flat(side.Position - p0)).Unit * ctx.rng:NextNumber(14, 26)
	ctx.walkTo(g, to)
	if not g.alive then return true end
	ctx.status(g, "sun", "Enjoying the town")
	Life.idle(ctx, g, ctx.rng:NextNumber(4, 8))
	ctx.walkTo(g, p0)
	ctx.walkTo(g, ctx.NAV.Inside.Position)
	if g.alive and ctx.rng:NextNumber() < 0.5 then ctx.say(g, pick(ctx.rng, Life.WALK_BACK), 2.5) end
	return true
end

DO.stretch = function(ctx, g)
	local music = itemMatching(ctx, MUSIC)
	if music then
		local piv = music.model:GetPivot().Position
		local dir = flat(piv - g.root.Position)
		if dir.Magnitude > 6 then
			local spot = piv - dir.Unit * 5
			ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
		end
		if not g.alive then return true end
		ctx.faceTo(g, piv)
		ctx.status(g, "happy", "Dancing")
		ctx.say(g, pick(ctx.rng, Life.DANCE), 2.5)
		ctx.play(g, "@dance")
		task.wait(ctx.rng:NextNumber(5, 8))
		ctx.stop(g, "@dance")
		if g.alive then ctx.play(g, "cheer") end
		ctx.moodShift(g, 3, "Loved the music in the lobby!", "Great music in the lobby.")
		return true
	end
	ctx.status(g, "guest", "Stretching")
	ctx.say(g, pick(ctx.rng, Life.STRETCH), 2.5)
	ctx.play(g, "stretch")
	Life.idle(ctx, g, ctx.rng:NextNumber(2, 4))
	return true
end

DO.snack = function(ctx, g)
	local e = itemMatching(ctx, SNACK)
	if not e then return false end
	local id = e.model:GetAttribute("Item")
	local piv = e.model:GetPivot()
	local depth = e.model:GetExtentsSize().Z
	local spot = (piv * CFrame.new(0, 0, depth / 2 + 1.8)).Position
	ctx.status(g, "walk", SNACK[id])
	ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
	if not g.alive then return true end
	ctx.faceTo(g, piv.Position)
	ctx.status(g, "food", SNACK[id])
	ctx.sfx(id == "VendingMachine" and "vend" or "pour", piv.Position)
	Life.idle(ctx, g, ctx.rng:NextNumber(2.5, 4))
	if not g.alive then return true end
	ctx.say(g, id == "CoffeeBar" and "Mmm, good coffee." or (id == "WaterCooler" and "Refreshing!" or "Just what I needed."), 2.5)
	ctx.moodShift(g, 3, id == "CoffeeBar" and "The coffee bar is great!" or nil, id == "CoffeeBar" and "Great coffee in the lobby." or nil)
	Life.idle(ctx, g, ctx.rng:NextNumber(2, 4))
	return true
end

-- where a plate goes in front of a seat: on the table top, a little way in from the seat's edge
local function tableSpot(ctx, seat)
	local piv = seat.model:GetPivot()
	local sp = seat.cf.Position
	local p = piv.Position:Lerp(Vector3.new(sp.X, piv.Y, sp.Z), 0.42)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { seat.model }
	local hit = workspace:Raycast(Vector3.new(p.X, piv.Y + 9, p.Z), Vector3.new(0, -11, 0), rp)
	local y = hit and hit.Position.Y or piv.Y + 2.9
	return CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(sp.X, y, sp.Z))
end

-- a meal (round 10c): order at the serving counter, wait to one side, collect the plate when it's up,
-- then eat at a cafe or dining table (or standing, plate in hand) and pay. Once per stay.
DO.eat = function(ctx, g)
	local k = ctx.kitchen
	if g.ate or not (k and k:open()) then return false end
	local counter = k:counter(g.root.Position)
	if not counter then return false end
	g.ate = true
	ctx.status(g, "food", "Getting something to eat")
	ctx.walkTo(g, k:frontSpot(counter, 0, 1.2), 1.3)
	if not g.alive then return true end
	ctx.faceTo(g, counter:GetPivot().Position)
	local o = k:order(g)
	ctx.say(g, string.format(pick(ctx.rng, Life.ORDER), string.lower(o.dish.name)), 2.6)
	ctx.sfx("register", counter:GetPivot().Position)
	task.wait(1.2)
	-- step aside so the next guest can order
	local side = ctx.rng:NextNumber() < 0.5 and -1 or 1
	ctx.walkTo(g, k:frontSpot(counter, side * ctx.rng:NextNumber(2.8, 4.2), ctx.rng:NextNumber(2.6, 3.6)), 1.3)
	if g.alive then ctx.faceTo(g, counter:GetPivot().Position) end
	ctx.status(g, "food", o.cook and (o.dish.name .. " on the stove") or ("Waiting for the " .. string.lower(o.dish.name)))
	local mealWait = C.MEAL_WAIT * (ctx.rmul and ctx.rmul("mealWait") or 1) -- round 13: Table Service research
	ctx.barTimer(g, mealWait, true, true)
	local t0, nextLine = os.clock(), os.clock() + ctx.rng:NextNumber(14, 22)
	g.chatOK = true
	-- while someone is cooking it, they wait it out
	local limit = mealWait
	while g.alive and o.state == "new" and os.clock() - t0 < limit do
		if o.cook then limit = math.max(limit, os.clock() - t0 + 2) end
		if os.clock() > nextLine then
			nextLine = os.clock() + ctx.rng:NextNumber(16, 26)
			ctx.say(g, pick(ctx.rng, Life.HUNGRY), 2.4)
		end
		task.wait(0.3)
	end
	g.chatOK = false
	if not g.alive then k:cancel(o) return true end
	if o.state ~= "ready" then
		k:cancel(o)
		ctx.say(g, "I never got my food!", 3)
		ctx.moodShift(g, -8, "Waited ages for food that never came.", "Slow kitchen.")
		return true
	end
	-- collect it from the pass
	ctx.status(g, "food", "Collecting the " .. string.lower(o.dish.name))
	ctx.walkTo(g, k:frontSpot(o.counter, o.slotX, 0.9), 1.1)
	if not (g.alive and o.plate) then k:cancel(o) return true end
	ctx.faceTo(g, o.plate:GetPivot().Position)
	k:take(o, g)
	ctx.say(g, pick(ctx.rng, Life.THANKS_FOOD), 2.2)
	-- a seat at a table, if there's one free
	local seat = freeSeat(ctx, g, TABLES)
	if seat then
		taken[seat.key] = g
		ctx.status(g, "walk", "Finding a table")
		ctx.walkTo(g, Vector3.new(seat.stand.X, g.root.Position.Y, seat.stand.Z))
		if not g.alive then taken[seat.key] = nil k:cancel(o) return true end
		ctx.pose(g, seat.cf)
		ctx.play(g, "sit", 0.25)
		k:putDown(o, tableSpot(ctx, seat))
	end
	ctx.play(g, "@eat")
	ctx.status(g, "food", "Eating")
	ctx.barTimer(g, 12)
	Life.idle(ctx, g, ctx.rng:NextNumber(11, 14))
	if g.alive then
		ctx.say(g, pick(ctx.rng, (o.stars or 2) >= 3 and Life.YUM or Life.FED), 2.4)
		k:pay(o, g)
	else
		k:cancel(o)
	end
	ctx.stop(g, "@eat")
	if seat then
		ctx.stop(g, "sit", 0.2)
		ctx.unpose(g, CFrame.lookAt(seat.stand, seat.stand + flat(seat.cf.LookVector)))
		taken[seat.key] = nil
	end
	return true
end

---------------------------------------------------------------- round 14: who they are, what they need, the town

-- every guest is somebody: a persona (what they like doing, what they talk about) and a hometown
Life.PERSONAS = {
	{ id = "tourist", name = "Tourist", w = { photo = 3, town = 3, walk = 2, chat = 1.5 }, decay = { fun = 1.3 },
		towns = { "museum", "harbour", "market", "park", "beach" },
		about = { "First time in this town! I want to see everything.", "I'm backpacking round the whole country.", "I collect a fridge magnet from every town I visit.", "I've got a list of twenty sights. Twenty!" } },
	{ id = "business", name = "On business", w = { phone = 3, text = 3, read = 1.2, snack = 2, town = 0.6, sit = 1.4 }, decay = { energy = 1.35, social = 0.7 },
		towns = { "cafe", "restaurant" },
		about = { "Here for a conference. Three days of meetings.", "I sell office chairs. It's more exciting than it sounds.", "Work trip. The company's paying, thankfully.", "I'm closing a big deal tomorrow. Wish me luck." } },
	{ id = "foodie", name = "Foodie", w = { eat = 4, snack = 3, town = 2 }, decay = { hunger = 1.6 },
		towns = { "restaurant", "market", "cafe" },
		about = { "I travel for the food, honestly.", "I review restaurants on my blog. Be nice to me!", "I heard this town has the best pastries around.", "Ask me about cheese. Actually, don't. I'll never stop." } },
	{ id = "bookworm", name = "Bookworm", w = { read = 4, sit = 2, people = 1.5, chat = 0.6 }, decay = { social = 0.6, fun = 0.8 },
		towns = { "bookshop", "museum", "cafe" },
		about = { "I came here to finish my novel. Chapter twelve!", "I'm a librarian on holiday. I brought six books.", "Quiet hotel, good chair, good book. Perfect.", "I'm writing a mystery set in a hotel. Taking notes!" } },
	{ id = "social", name = "Social butterfly", w = { chat = 4, player = 2.5, photo = 2, stretch = 2, staff = 2 }, decay = { social = 1.7 },
		towns = { "concert", "cinema", "market" },
		about = { "I just love meeting people!", "I've made three friends since breakfast.", "I'm a wedding planner. I know everyone.", "Talk to me, I'll tell you my whole life story." } },
	{ id = "active", name = "Fitness fan", w = { stretch = 3, walk = 3, town = 2, snack = 0.6 }, decay = { energy = 0.8, fun = 1.2 },
		towns = { "park", "beach", "harbour" },
		about = { "I'm training for a marathon!", "Ten thousand steps a day, minimum.", "I cycled here. All the way.", "The stairs here are great for leg day." } },
	{ id = "relax", name = "Here to relax", w = { sit = 4, read = 2, snack = 1.2, people = 2, town = 1 }, decay = { fun = 0.7, energy = 1.2 },
		towns = { "spa", "beach", "park" },
		about = { "I just need a few days of doing nothing.", "No phone, no emails. Bliss.", "My doctor told me to relax. So here I am.", "First holiday in three years!" } },
	{ id = "shopper", name = "Shopaholic", w = { town = 4, text = 2, photo = 1.4 }, decay = { fun = 1.3 },
		towns = { "shops", "market", "bookshop" },
		about = { "I need a bigger suitcase. Already.", "I heard the shops here are amazing.", "Window shopping is my cardio.", "I promised myself one bag. Just one." } },
}
Life.PERSONA = {}
for _, p in ipairs(Life.PERSONAS) do Life.PERSONA[p.id] = p end
local HOMES = { "the coast", "up north", "the big city", "a tiny village", "overseas", "the mountains", "just down the road", "the countryside", "a farm out west", "an island down south" }
local HOME_LINE = { "I'm from %s. It's quiet there, so this is a treat.", "From %s! Long trip, but worth it.", "Born and raised in %s.", "%s. You've probably never heard of it." }

function Life.persona(g, id)
	if id and Life.PERSONA[id] then g.persona = Life.PERSONA[id] end
	if not g.persona then
		local rng = Random.new()
		g.persona = Life.PERSONAS[rng:NextInteger(1, #Life.PERSONAS)]
		g.hometown = HOMES[rng:NextInteger(1, #HOMES)]
	end
	g.hometown = g.hometown or HOMES[1]
	if g.model then g.model:SetAttribute("Persona", g.persona.name) end
	return g.persona
end

-- needs run down while they're here; doing things fills them back up
local NEEDS = { "hunger", "energy", "fun", "social" }
Life.NEED_WORD = { hunger = "Hungry", energy = "Tired", fun = "Bored", social = "Lonely" }
local DECAY = { hunger = 0.2, energy = 0.14, fun = 0.24, social = 0.18 } -- per second
local NEED_LINES = {
	hunger = { "I'm starving...", "My stomach is growling.", "Is there anywhere to eat around here?" },
	energy = { "I can barely keep my eyes open.", "So tired...", "I need to sit down." },
	fun = { "There's nothing to do here.", "So... bored...", "I wish there was something fun to do." },
	social = { "Nobody to talk to...", "It's a bit lonely here.", "I wish someone would chat." },
}
local NEED_REVIEW = {
	hunger = "Nowhere to get a bite to eat.", energy = "Nowhere comfy to rest.", fun = "Not much to do.", social = nil,
}
function Life.needs(g)
	local n = g.needs
	local now = os.clock()
	if not n then
		local rng = Random.new()
		n = { t = now }
		for _, k in ipairs(NEEDS) do n[k] = rng:NextNumber(55, 95) end
		g.needs = n
	end
	local dt = now - n.t
	n.t = now
	local p = g.persona
	for _, k in ipairs(NEEDS) do
		n[k] = math.clamp(n[k] - DECAY[k] * dt * (p and p.decay[k] or 1), 0, 100)
	end
	return n
end
function Life.fill(g, k, amt)
	local n = Life.needs(g)
	if n[k] then n[k] = math.clamp(n[k] + amt, 0, 100) end
end
function Life.lowest(g)
	local n = Life.needs(g)
	local bk, bv = "fun", 101
	for _, k in ipairs(NEEDS) do
		if n[k] < bv then bk, bv = k, n[k] end
	end
	return bk, bv
end
-- what the talk card says they're feeling (nil = fine)
function Life.feeling(g)
	local k, v = Life.lowest(g)
	return v < 38 and Life.NEED_WORD[k] or nil
end

-- the town: places a guest can go while their room stays theirs
Life.TOWN = {
	museum = { label = "the museum", fill = { fun = 45 }, wet = true,
		back = { "So much history in one building!", "My feet hurt, but wow." }, tell = { "The dinosaur bones were HUGE.", "I spent an hour in the gift shop.", "There's a painting of this street from a hundred years ago!" } },
	harbour = { label = "the old harbour", fill = { fun = 40, energy = -6 },
		back = { "The sea air was lovely.", "I watched the boats come in." }, tell = { "A seagull stole my chips!", "The fishing boats are so colourful.", "I saw a seal! I think. Maybe a rock." } },
	market = { label = "the market", fill = { fun = 30, hunger = 30 }, bag = true,
		back = { "Look what I found!", "Great bargains today." }, tell = { "I bought jam from a lady who makes it herself.", "So many stalls! I got lost twice.", "The cheese stall gave out free samples." } },
	park = { label = "the park", fill = { fun = 30, energy = 8 },
		back = { "Such a pretty park.", "I fed the ducks!" }, tell = { "The ducks are very demanding here.", "I had a nap under a tree. Perfect.", "There was a band playing by the fountain!" } },
	beach = { label = "the beach", fill = { fun = 50, energy = -10 },
		back = { "The water was perfect!", "I think I got a bit sunburnt..." }, tell = { "I built a sandcastle. A big one.", "The water was freezing but I went in anyway!", "I found a really nice shell." } },
	cafe = { label = "a little cafe", fill = { hunger = 45, social = 15 }, wet = true,
		back = { "Best croissant of my life.", "Lovely little cafe down the road." }, tell = { "The barista drew a heart in my coffee.", "Their cakes are dangerously good.", "I sat by the window and watched the town go by." } },
	restaurant = { label = "a restaurant", fill = { hunger = 80, social = 20 }, wet = true,
		back = { "I'm so full.", "What a meal!" }, tell = { "I had three courses. Three!", "The chef came out to say hello.", "Honestly the dessert was the best part." } },
	shops = { label = "the shops", fill = { fun = 35 }, bag = true, wet = true,
		back = { "I may have overspent...", "Retail therapy!" }, tell = { "I got shoes. And a hat. And another hat.", "Everything was on sale!", "Don't tell anyone how much I spent." } },
	cinema = { label = "the cinema", fill = { fun = 50 }, wet = true,
		back = { "What a movie!", "I need to talk about that ending." }, tell = { "The ending was wild. I won't spoil it.", "I cried. Twice.", "The popcorn was bigger than my head." } },
	concert = { label = "a concert", fill = { fun = 55, social = 30, energy = -10 }, wet = true,
		back = { "My ears are still ringing!", "Best show ever!" }, tell = { "I danced all night!", "They played my favourite song!", "I'm going to be humming that all week." } },
	bookshop = { label = "the bookshop", fill = { fun = 30 }, bag = true, wet = true,
		back = { "I bought more books than I can carry.", "The bookshop is a treasure." }, tell = { "They had a first edition of my favourite book!", "There's a cat that lives in the bookshop.", "I could have stayed there all day." } },
	spa = { label = "the day spa", fill = { energy = 40, fun = 20 }, wet = true,
		back = { "I feel ten years younger.", "So relaxed right now..." }, tell = { "The massage was heavenly.", "Cucumber on the eyes. Very fancy.", "I fell asleep in the sauna, oops." } },
}
local TOWN_GO = { "Off to %s!", "Heading to %s, back later!", "I'm going to check out %s.", "Time for %s!" }
local function wetOut()
	local w = weather()
	return w == "rain" or w == "storm" or w == "snow"
end
-- up to n places that suit them (their favourites first) and the weather
function Life.suggest(ctx, g, n)
	local p = Life.persona(g)
	local wet = wetOut()
	local out, seen = {}, {}
	local function add(id)
		local t = Life.TOWN[id]
		if t and not seen[id] and (t.wet or not wet) then seen[id] = true; table.insert(out, id) end
	end
	local favs = table.clone(p.towns)
	for i = #favs, 2, -1 do local j = ctx.rng:NextInteger(1, i); favs[i], favs[j] = favs[j], favs[i] end
	for _, id in ipairs(favs) do add(id) end
	local all = {}
	for id in pairs(Life.TOWN) do table.insert(all, id) end
	table.sort(all)
	for i = #all, 2, -1 do local j = ctx.rng:NextInteger(1, i); all[i], all[j] = all[j], all[i] end
	for _, id in ipairs(all) do add(id) end
	local res = {}
	for i = 1, math.min(n, #out) do res[i] = out[i] end
	return res
end

-- a paper shopping bag in the right hand (or none)
local BAG_COLS = { Color3.fromRGB(236, 226, 204), Color3.fromRGB(40, 52, 92), Color3.fromRGB(196, 72, 72), Color3.fromRGB(116, 176, 150), Color3.fromRGB(214, 168, 84) }
function Life.shoppingBag(g, on)
	local old = g.model and g.model:FindFirstChild("ShoppingBag")
	if old then old:Destroy() end
	if not on then
		-- (the luggage, if any, is down by the bed unless it's still welded on)
		if g.model and g.model:GetAttribute("Carry") == "bag" and not (g.bag and g.bag.weld) then g.model:SetAttribute("Carry", nil) end
		return
	end
	local hand = g.model:FindFirstChild("RightHand") or g.model:FindFirstChild("Right Arm")
	if not hand then return end
	local m = Instance.new("Model")
	m.Name = "ShoppingBag"
	local col = BAG_COLS[Random.new():NextInteger(1, #BAG_COLS)]
	local function bp(name, size, cf, c, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CastShadow = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CFrame = cf
		p.Parent = m
		return p
	end
	local top = hand.CFrame * CFrame.new(0, -0.32, 0) * CFrame.Angles(0, math.rad(90), 0)
	local body = bp("Body", Vector3.new(1.15, 1.25, 0.5), top * CFrame.new(0, -0.78, 0), col, Enum.Material.Fabric)
	bp("Fold", Vector3.new(1.17, 0.14, 0.52), top * CFrame.new(0, -0.22, 0), col:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Fabric)
	bp("Band", Vector3.new(1.17, 0.1, 0.52), top * CFrame.new(0, -0.62, 0), Color3.fromRGB(214, 176, 92), Enum.Material.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		bp("Handle", Vector3.new(0.06, 0.32, 0.06), top * CFrame.new(0.22 * s, -0.02, 0) * CFrame.Angles(0, 0, math.rad(-18 * s)), Color3.fromRGB(60, 46, 34))
	end
	bp("HandleTop", Vector3.new(0.4, 0.06, 0.06), top * CFrame.new(0, 0.13, 0), Color3.fromRGB(60, 46, 34))
	for _, p in ipairs(m:GetChildren()) do
		if p ~= body then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = body, p
			w.Parent = p
		end
	end
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = hand, body
	w.C0 = hand.CFrame:ToObjectSpace(body.CFrame)
	w.Parent = body
	m.PrimaryPart = body
	m.Parent = g.model
	g.model:SetAttribute("Carry", "bag")
end

local awayFolder
local function townFolder()
	if awayFolder and awayFolder.Parent then return awayFolder end
	awayFolder = game.ServerStorage:FindFirstChild("RAH_InTown") or Instance.new("Folder")
	awayFolder.Name = "RAH_InTown"
	awayFolder.Parent = game.ServerStorage
	return awayFolder
end

-- off into town: out the door and down the street, gone a while (the room stays theirs), back with stories
DO.town = function(ctx, g)
	if (g.townTrips or 0) >= 2 then return false end
	local id = g.townPlan
	local t = id and Life.TOWN[id]
	if t and wetOut() and not t.wet then
		ctx.say(g, "Too wet for " .. t.label .. ". Maybe tomorrow.", 3)
		g.townPlan, t = nil, nil
	end
	if not t then
		id = Life.suggest(ctx, g, 1)[1]
		t = id and Life.TOWN[id]
	end
	if not t then return false end
	g.townPlan, g.townSoon = nil, nil
	g.townTrips = (g.townTrips or 0) + 1
	ctx.status(g, "walk", "Heading to " .. t.label)
	ctx.say(g, string.format(pick(ctx.rng, TOWN_GO), t.label), 2.8)
	ctx.walkTo(g, ctx.NAV.PathStart.Position)
	if not g.alive then return true end
	local side = ctx.rng:NextNumber() < 0.5 and ctx.NAV.Street or ctx.NAV.StreetExit
	ctx.walkTo(g, side.Position)
	if not g.alive then return true end
	-- in town: off the map while their room waits for them
	local room = g.room
	g.inTown = id
	g.model:SetAttribute("InTown", t.label)
	g.model:SetAttribute("BWhat", "In town: " .. t.label)
	if room and room.model then room.model:SetAttribute("AwayAt", t.label) end
	g.model.Parent = townFolder()
	local secs = ctx.rng:NextNumber(35, 70) * (ctx.HOTEL:GetAttribute("TestLinger") or 1)
	local t0 = os.clock()
	while g.alive and ctx.running() and os.clock() - t0 < secs do task.wait(0.5) end
	if not g.alive or not ctx.running() then return true end
	g.model:PivotTo(side.CFrame)
	g.model.Parent = ctx.GUESTS
	g.inTown = nil
	g.model:SetAttribute("InTown", nil)
	if room and room.model then room.model:SetAttribute("AwayAt", nil) end
	g.lastTown = { id = id, t = os.clock() }
	for k, v in pairs(t.fill) do Life.fill(g, k, v) end
	if t.bag then Life.shoppingBag(g, true) end
	ctx.status(g, "walk", "Back from " .. t.label)
	ctx.walkTo(g, ctx.NAV.PathStart.Position)
	if not g.alive then return true end
	ctx.walkTo(g, ctx.NAV.Inside.Position)
	if not g.alive then return true end
	ctx.say(g, pick(ctx.rng, t.back), 3)
	ctx.play(g, t.bag and "present" or "stretch")
	ctx.moodShift(g, 3)
	task.wait(1.2)
	return true
end

Life.TEXT = { "Haha, look at this!", "Who keeps texting me?", "Just posting a photo...", "Group chat is wild today." }
Life.READ = { "Just one more chapter...", "Ooh, a plot twist!", "Such a good book." }
Life.PEOPLE = { "Everyone's in such a rush.", "I love watching people come and go.", "Ooh, look at that suitcase.", "This lobby is like a movie set." }

DO.text = function(ctx, g)
	ctx.status(g, "chat", "Texting")
	ctx.play(g, "@text")
	if ctx.rng:NextNumber() < 0.55 then ctx.say(g, pick(ctx.rng, Life.TEXT), 2.6) end
	Life.idle(ctx, g, ctx.rng:NextNumber(5, 9))
	ctx.stop(g, "@text")
	if g.alive and ctx.rng:NextNumber() < 0.4 then ctx.play(g, "laugh") task.wait(1.2) end
	return true
end

-- a seat, then something to do in it
local function seated(ctx, g, what, poseName, lines, lo, hi)
	local seat = freeSeat(ctx, g)
	if not seat then return false end
	taken[seat.key] = g
	ctx.status(g, "walk", "Finding a seat")
	ctx.walkTo(g, Vector3.new(seat.stand.X, g.root.Position.Y, seat.stand.Z))
	if not g.alive then taken[seat.key] = nil return true end
	ctx.faceTo(g, seat.stand + flat(seat.cf.LookVector) * -3)
	ctx.status(g, "guest", what)
	ctx.pose(g, seat.cf)
	ctx.play(g, "sit", 0.25)
	if poseName then ctx.play(g, poseName) end
	if lines and ctx.rng:NextNumber() < 0.6 then ctx.say(g, pick(ctx.rng, lines), 2.6) end
	Life.idle(ctx, g, ctx.rng:NextNumber(lo, hi))
	if poseName then ctx.stop(g, poseName) end
	ctx.stop(g, "sit", 0.2)
	ctx.unpose(g, CFrame.lookAt(seat.stand, seat.stand + flat(seat.cf.LookVector)))
	taken[seat.key] = nil
	return true
end
DO.read = function(ctx, g) return seated(ctx, g, "Reading", "@read", Life.READ, 10, 16) end
DO.people = function(ctx, g) return seated(ctx, g, "People-watching", nil, Life.PEOPLE, 8, 12) end

-- what each outing does for their needs
local NEED_FILL = {
	sit = { energy = 28 }, read = { energy = 16, fun = 20 }, people = { fun = 14, energy = 10 },
	chat = { social = 42 }, staff = { social = 24 }, player = { social = 22 }, phone = { social = 30 }, text = { social = 18, fun = 8 },
	photo = { fun = 28 }, walk = { fun = 22, energy = -4 }, stretch = { fun = 30, energy = -6 },
	snack = { hunger = 35 }, eat = { hunger = 78, social = 8 },
}
local NEED_OF = {
	sit = "energy", read = "energy", people = "fun", chat = "social", staff = "social", player = "social", phone = "social", text = "social",
	photo = "fun", walk = "fun", stretch = "fun", snack = "hunger", eat = "hunger", town = "fun",
}

local WEIGHTS = {
	lobby = { sit = 3, chat = 3, staff = 2, player = 2, photo = 2, phone = 1, text = 1.5, read = 1, people = 1, walk = 1, stretch = 1, snack = 2, eat = 4, complain = 2 },
	stay = { sit = 2, chat = 2, staff = 1.5, player = 2, photo = 1, phone = 1, text = 1, read = 1, people = 1, walk = 1, stretch = 1, snack = 2, eat = 4, town = 4, complain = 2 },
}

-- one outing, picked by what they like (persona) and what they need most. True if something happened.
function Life.outing(ctx, g, where)
	local p = Life.persona(g)
	local n = Life.needs(g)
	-- a need that's run right down gets said out loud (and costs a little mood)
	local lk, lv = Life.lowest(g)
	if g.model then g.model:SetAttribute("Need", lv < 38 and Life.NEED_WORD[lk] or nil) end
	if lv < 16 and os.clock() > (g.needGrumble or 0) then
		g.needGrumble = os.clock() + 70
		ctx.say(g, pick(ctx.rng, NEED_LINES[lk]), 3)
		ctx.moodShift(g, -3, nil, NEED_REVIEW[lk])
	end
	local w = WEIGHTS[where] or WEIGHTS.lobby
	local pool, total = {}, 0
	for k, base in pairs(w) do
		local need = NEED_OF[k] and n[NEED_OF[k]] or 60
		local tw = g.gtype and g.gtype.w and g.gtype.w[k]
		local wt = base * (p.w[k] or 1) * (tw or (k == "complain" and 0 or 1)) * (1 + (100 - need) / 35)
		if wt > 0 then
			table.insert(pool, { k = k, w = wt })
			total += wt
		end
	end
	table.sort(pool, function(a, b) return a.k < b.k end)
	local function roll()
		local r = ctx.rng:NextNumber() * total
		for _, e in ipairs(pool) do
			r -= e.w
			if r <= 0 then return e.k end
		end
		return pool[#pool].k
	end
	for try = 1, 5 do
		if not g.alive then return false end
		local kind = roll()
		local test = ctx.HOTEL:GetAttribute("TestOuting") -- Studio playtests: hotel attribute TestOuting = "eat" etc. goes first
		if try == 1 then
			-- something you suggested to them in a conversation comes first
			if g.wantKind and DO[g.wantKind] then kind = g.wantKind
			elseif g.townSoon and where == "stay" then kind = "town" end
			if test and DO[test] then kind = test end
		end
		if kind == "town" and where ~= "stay" then continue end
		if try == 1 then g.wantKind = nil end
		local ok, done = pcall(DO[kind], ctx, g)
		if not ok then warn("RAH_GuestLife " .. kind .. ": " .. tostring(done)) return false end
		if done then
			for k, v in pairs(NEED_FILL[kind] or {}) do Life.fill(g, k, v) end
			local k2, v2 = Life.lowest(g)
			if g.model then g.model:SetAttribute("Need", v2 < 38 and Life.NEED_WORD[k2] or nil) end
			return true
		end
	end
	return false
end

---------------------------------------------------------------- round 14: real conversations
-- RAH_HotelSim's Talk handler asks Life.talkReply first. A reply can lead somewhere: g.talkNext holds the
-- follow-up choices (Life.talkOptions shows them instead of the usual set for a little while).
local HOW_TEXT = {
	about = "Tell me about yourself", whereFrom = "Where are you from?", plans = "Any plans today?",
	goodChoice = "Great choice!", fixIt = "I'll sort it out now", discount = "25% off your bill",
	sorry = "I'm so sorry", eatHere = "Our kitchen's open!", restUp = "Take a seat, relax",
	chatMore = "I'm happy to chat!", hobby = "What do you do for fun?",
}
for k, v in pairs(HOW_TEXT) do Life.TALK_EXTRA = Life.TALK_EXTRA or {}; Life.TALK_EXTRA[k] = v end
local HOBBY = {
	tourist = { "Postcards! I send one home from everywhere.", "I'm learning a new language every trip." },
	business = { "Golf. Badly.", "Honestly? Spreadsheets. Don't laugh." },
	foodie = { "I bake. My sourdough has a name.", "I'm trying every dumpling in the country." },
	bookworm = { "Crosswords and crime novels.", "I write poems. Terrible ones." },
	social = { "Karaoke! Every Friday.", "Planning parties. For fun!" },
	active = { "Rock climbing, cycling, swimming...", "Morning runs. Five a.m.!" },
	relax = { "Napping. I'm a professional.", "Gardening. Tomatoes, mostly." },
	shopper = { "Thrift stores. The hunt is the fun part.", "Collecting sneakers. I own forty pairs." },
}

function Life.talkReply(ctx, g, option, player)
	local p = Life.persona(g)
	local rng = ctx.rng
	g.talkNext = nil
	local function nxt(ids) g.talkNext = { ids = ids, t = os.clock() } end
	local function once(key, d, sayN, rev)
		g.told = g.told or {}
		if g.told[key] then return false end
		g.told[key] = true
		ctx.moodShift(g, d, sayN, rev)
		return true
	end
	local tr = Life.typeReply and Life.typeReply(ctx, g, option, nxt, once)
	if tr then return tr end
	if option == "about" then
		once("about", 3)
		nxt({ "whereFrom", "hobby", "plans", "bye" })
		return pick(rng, p.about)
	elseif option == "whereFrom" then
		once("from", 2)
		nxt({ "hobby", "plans", "nice", "bye" })
		return string.format(pick(rng, HOME_LINE), g.hometown):gsub("^%l", string.upper)
	elseif option == "hobby" then
		once("hobby", 2)
		Life.fill(g, "social", 15)
		nxt({ "plans", "nice", "bye" })
		local h = HOBBY[p.id] or HOBBY.tourist
		return pick(rng, h)
	elseif option == "plans" or option == "recommend" then
		if option == "plans" and g.townPlan and Life.TOWN[g.townPlan] then
			nxt({ "goodChoice", "recommend", "bye" })
			return string.format(pick(rng, { "I'm off to %s later!", "Thinking of %s. Any good?", "%s, if the weather holds." }), Life.TOWN[g.townPlan].label):gsub("^%l", string.upper)
		end
		local ids = {}
		for _, id in ipairs(Life.suggest(ctx, g, 3)) do table.insert(ids, "rec_" .. id) end
		table.insert(ids, "bye")
		nxt(ids)
		return pick(rng, { "No plans yet! What's good around here?", "I was hoping you'd tell me!", "Not sure yet. Any tips?", "I'm open to ideas!" })
	elseif string.sub(option, 1, 4) == "rec_" then
		local id = string.sub(option, 5)
		local t = Life.TOWN[id]
		if not t then return nil end
		g.townPlan, g.townSoon = id, true
		local fav = table.find(p.towns, id) ~= nil
		once("rec", fav and 6 or 3, fav and "The staff knew exactly where I'd love to go!" or "Got a tip about the town.", fav and "Staff gave me the perfect local tip." or nil)
		nxt({ "nice", "bye" })
		if fav then
			return string.format(pick(rng, { "Oh, %s? That's exactly my kind of thing!", "%s! How did you know? Perfect." }), t.label):gsub("^%l", string.upper)
		end
		return string.format(pick(rng, { "Ooh, %s? I'll head there in a bit.", "%s? Sure, why not!", "Never would've thought of %s. Thanks!" }), t.label):gsub("^%l", string.upper)
	elseif option == "goodChoice" then
		once("good", 2)
		nxt({ "nice", "bye" })
		return pick(rng, { "Right? I can't wait.", "Glad you think so!" })
	elseif option == "howTown" then
		local lt = g.lastTown
		local t = lt and Life.TOWN[lt.id]
		once("howTown", 3)
		Life.fill(g, "social", 15)
		nxt({ "plans", "nice", "bye" })
		return t and pick(rng, t.tell) or "Lovely, thanks for asking!"
	elseif option == "whatsWrong" then
		local note = ctx.topNote and ctx.topNote(g, "say")
		local k, v = Life.lowest(g)
		nxt({ "fixIt", "discount", "sorry", "bye" })
		if note then return note.say end
		if v < 30 then return pick(rng, NEED_LINES[k]) end
		return pick(rng, { "Everything takes forever here!", "This place is a mess.", "I expected better, honestly." })
	elseif option == "fixIt" then
		if once("fixIt", 5) then
			nxt({ "sorry", "bye" })
			return pick(rng, { "Okay. I'll hold you to that.", "Fine. Thank you.", "Good. That's all I wanted." })
		end
		ctx.moodShift(g, -2)
		return "You said that already."
	elseif option == "discount" then
		local d = g.discount or 0
		if d >= 0.5 then return "You've already been more than generous." end
		g.discount = d + 0.25
		ctx.moodShift(g, d == 0 and 15 or 5, nil, d == 0 and "They took money off my bill when I complained. Fair." or nil)
		nxt({ "sorry", "bye" })
		return pick(rng, d == 0 and { "Oh. Well... that's fair. Thank you.", "Now THAT is customer service.", "Okay, you've won me over." } or { "Even more off? Okay, I feel better." })
	elseif option == "sorry" then
		if once("sorry", 3) then
			nxt({ "fixIt", "bye" })
			return pick(rng, { "I appreciate the apology.", "Thank you for saying that.", "...Okay. Apology accepted." })
		end
		return "Sorry doesn't fix it, though."
	elseif option == "need" then
		local k, v = Life.lowest(g)
		if v >= 40 then return nil end -- nothing pressing: the usual answer (their event, the lobby, the room)
		if k == "hunger" then
			nxt({ "eatHere", "rec_cafe", "rec_restaurant", "bye" })
			return pick(rng, { "I'm starving, honestly.", "Somewhere to eat would be amazing.", "Is there food anywhere?" })
		elseif k == "energy" then
			nxt({ "restUp", "bye" })
			return pick(rng, { "I'm exhausted. Long day.", "Just somewhere to sit down.", "A nap. I need a nap." })
		elseif k == "fun" then
			local ids = {}
			for _, id in ipairs(Life.suggest(ctx, g, 2)) do table.insert(ids, "rec_" .. id) end
			table.insert(ids, "bye")
			nxt(ids)
			return pick(rng, { "I'm a bit bored, to be honest.", "Anything fun to do around here?", "Something to do would be nice." })
		else
			nxt({ "chatMore", "bye" })
			return pick(rng, { "It's a bit lonely travelling alone.", "Just someone to talk to, really.", "Honestly? A friendly face." })
		end
	elseif option == "eatHere" then
		local k = ctx.kitchen
		if k and k:open() and not g.ate then
			g.wantKind = "eat"
			once("eatHere", 3)
			nxt({ "nice", "bye" })
			return pick(rng, { "Oh perfect, I'll grab something!", "Say no more, I'm going." })
		end
		ctx.moodShift(g, -2)
		nxt({ "rec_cafe", "bye" })
		return pick(rng, { "Is it? I couldn't find anything.", "Where? I don't see a kitchen." })
	elseif option == "restUp" then
		g.wantKind = "sit"
		once("rest", 2)
		nxt({ "bye" })
		return pick(rng, { "That sounds lovely.", "Don't mind if I do." })
	elseif option == "chatMore" then
		Life.fill(g, "social", 45)
		once("chatMore", 5, "The owner took time to chat with me!", "The owner stopped to chat. So sweet.")
		nxt({ "about", "hobby", "bye" })
		return pick(rng, { "Aww, thank you. That means a lot.", "You're so kind! So, how long have you run this place?", "Finally, a friendly face!" })
	end
	return nil
end

-- the extra choice texts (Life.TALK_TEXT lives in RAH_HotelSim; rec_ and howTown are made per guest)
function Life.optionText(g, id)
	if string.sub(id, 1, 4) == "rec_" then
		local t = Life.TOWN[string.sub(id, 5)]
		return t and ("Try " .. t.label .. "!") or id
	end
	if id == "howTown" and g.lastTown and Life.TOWN[g.lastTown.id] then
		return "How was " .. Life.TOWN[g.lastTown.id].label .. "?"
	end
	return Life.TALK_EXTRA[id]
end


---------------------------------------------------------------- round 14: guest types (attitudes), from day one
-- Rolled for every arrival without an event (no research needed). touchy scales bad mood shifts, patience the
-- wait outside and at the desk, payMul the bill. Each type has its own lines and a thing or two it does.
Life.TYPE_CHANCE = 0.5
Life.TYPES = {
	karen = {
		label = "Demanding guest", icon = "angry", weight = 10, mood = -12, patience = 0.6, touchy = 1.4,
		w = { complain = 3, player = 0.4, chat = 0.4 },
		arrive = { "This line is UNACCEPTABLE.", "I hope you know who I am.", "I've already got three complaints and I just got here." },
		toast = "A demanding guest just arrived. Brace yourself.",
	},
	bigspender = {
		label = "Big spender", icon = "cash", weight = 7, mood = 0, patience = 0.85, payMul = 1.7, touchy = 1.2,
		w = { eat = 1.5, snack = 1.4, town = 1.3 },
		arrive = { "Money is no object, darling.", "Your best room, please.", "I hope the champagne is cold." },
		toast = "A big spender is checking in. Give them a nice room!",
	},
	backpacker = {
		label = "Budget backpacker", icon = "suitcase", weight = 8, mood = 12, patience = 1.4, payMul = 0.75, touchy = 0.6,
		w = { walk = 2, town = 1.5, sit = 1.3 },
		arrive = { "Cheapest room you've got!", "I've slept in worse. Much worse.", "Do you do discounts for students?" },
	},
	influencer = {
		label = "Influencer", icon = "phone", weight = 6, mood = 0, payMul = 1.1, reviewW = 3,
		w = { photo = 4, text = 2.5, phone = 1.5 },
		arrive = { "Hi besties, we're at a new hotel!", "Is the lighting good in here?", "This better be aesthetic." },
		toast = "An influencer is staying! Their review counts three times.",
	},
	party = {
		label = "Party animal", icon = "happy", weight = 6, mood = 6, payMul = 1.2,
		w = { stretch = 3, chat = 2, town = 1.4 },
		arrive = { "Where's the party at?!", "Let's GO!", "I brought a speaker. Is that okay? It's okay." },
	},
	chatty = {
		label = "Chatty grandparent", icon = "chat", weight = 6, mood = 8, patience = 1.25, touchy = 0.85, walk = 0.74,
		w = { chat = 3, player = 3, staff = 2, sit = 2, people = 2 },
		arrive = { "Oh, what a lovely little place!", "In my day hotels didn't have all this.", "My knees aren't what they used to be." },
	},
	germ = {
		label = "Clean freak", icon = "clean", weight = 6, mood = 0, touchy = 1.5,
		w = { sit = 0.5, snack = 0.5 },
		arrive = { "Has this desk been wiped today?", "I brought my own pillowcase. Just in case.", "Is that a crumb?" },
	},
	sleepy = {
		label = "Exhausted traveller", icon = "sleep", weight = 6, mood = -3, patience = 0.7, energy = 6,
		w = { sit = 3, read = 1.5 },
		arrive = { "Twenty hours of travel... I need a bed.", "Please tell me the room's ready.", "*yawn* Sorry. Long flight." },
	},
	dasher = {
		label = "Shifty guest", icon = "run", weight = 4, mood = 0, dash = 0.8,
		w = { people = 2 },
		arrive = { "Nice hotel. Very... nice.", "Do you take IOUs? Kidding! Kidding.", "Where's the back door? For fire safety." },
	},
}
for id, t in pairs(Life.TYPES) do t.id = id end

-- an arrival: maybe a type (never on an event guest)
function Life.rollType(ctx, g, force)
	if g.gtype then return g.gtype end
	local test = game:GetService("RunService"):IsStudio() and ctx.HOTEL:GetAttribute("TestType")
	local t = force and Life.TYPES[force] or (test and Life.TYPES[test])
	if not t then
		if g.event or ctx.rng:NextNumber() > Life.TYPE_CHANCE then return nil end
		local total = 0
		for _, d in pairs(Life.TYPES) do total += d.weight end
		local ids = {}
		for id in pairs(Life.TYPES) do table.insert(ids, id) end
		table.sort(ids)
		local r = ctx.rng:NextNumber() * total
		for _, id in ipairs(ids) do
			r -= Life.TYPES[id].weight
			if r <= 0 then t = Life.TYPES[id] break end
		end
		t = t or Life.TYPES[ids[1]]
	end
	g.gtype = t
	g.patienceK = t.patience
	g.payMul = t.payMul
	g.model:SetAttribute("GuestType", t.label)
	if not g.model:GetAttribute("BEvent") then g.model:SetAttribute("BEvent", t.icon) end
	if t.mood and t.mood ~= 0 then ctx.moodShift(g, t.mood) end
	if t.energy then Life.needs(g).energy = t.energy end
	if t.walk then
		g.hum.WalkSpeed *= t.walk
		g.model:SetAttribute("WalkSpeedMul", (g.model:GetAttribute("WalkSpeedMul") or 1) * t.walk)
	end
	if t.id == "chatty" then Life.needs(g).social = 10 end
	return t
end

-- the talk set a type brings (nil = the usual)
Life.TYPE_SETS = {
	karen = { "listen", "manager", "discount", "refuse", "bye" },
	dash = { "caught", "bye" },
	party = { "keepDown", "about", "bye" },
}
function Life.typeContext(g)
	local t = g.gtype
	if not t then return nil end
	if g.dashing then return "dash" end
	if t.id == "karen" and (g.mood or 60) < 60 then return "karen" end
	if t.id == "party" and g.partying then return "party" end
	return nil
end

local KAREN_RANT = {
	"The carpet is the wrong shade of beige.", "My water was TOO wet.", "Why is the lobby music so... musical?",
	"I asked for a view of the ocean.", "The pillow is fluffier on one side.", "Someone SMILED at me in the hallway.",
	"The soap smells like soap. I wanted lavender.", "My room is 3 steps further than I'd like.", "The plant in the lobby is judging me.",
	"I could hear the bed creak. When I sat on it.",
}
local KAREN_SCENE = { "UNBELIEVABLE!", "I am going to write SUCH a review!", "Do you know how many followers my cousin has?!", "This is the WORST hotel in the WORLD!" }
Life.KAREN_DEMAND = { "I want to speak to the MANAGER.", "Excuse me! EXCUSE me!", "Are you in charge here? You'd better be.", "I have a complaint. Several, actually." }
Life.TALK_EXTRA.listen = "I'm listening"
Life.TALK_EXTRA.manager = "I AM the manager"
Life.TALK_EXTRA.refuse = "That's our policy"
Life.TALK_EXTRA.caught = "Hey! You didn't pay!"
Life.TALK_EXTRA.keepDown = "Please keep it down"

-- a Karen kicks off: stomping, pointing, and everyone nearby hears it
function Life.scene(ctx, g)
	ctx.say(g, pick(ctx.rng, KAREN_SCENE), 3)
	ctx.play(g, "stomp")
	task.delay(1.1, function() if g.alive then ctx.play(g, "point_angry") end end)
	for other in pairs(ctx.guests) do
		if other ~= g and other.alive and other.root and other.model and other.model:IsDescendantOf(workspace)
			and (other.root.Position - g.root.Position).Magnitude < 28 then
			ctx.moodShift(other, -3, nil, "A guest was screaming in the lobby.")
		end
	end
end

-- the type's own replies (before the general ones)
local function typeReply(ctx, g, option, nxt, once)
	local t = g.gtype
	if option == "caught" then
		if not g.dashing then return "Pay? I'm... going to the line now. Obviously." end
		g.caught = true
		ctx.moodShift(g, -2)
		nxt({ "bye" })
		return pick(ctx.rng, { "Oh! Ha... I was just getting some air.", "Pay? Right. Yes. I was coming right back.", "...You saw that, huh. Fine." })
	elseif option == "keepDown" then
		g.quieted = true
		ctx.moodShift(g, -2)
		nxt({ "bye" })
		return pick(ctx.rng, { "Aww, fine. Party's over, everyone.", "Okay, okay. Indoor voices.", "Buzzkill. But fair." })
	end
	if not t or t.id ~= "karen" then return nil end
	if option == "listen" then
		once("listen", 5)
		nxt({ "fixIt", "discount", "manager", "bye" })
		return pick(ctx.rng, KAREN_RANT)
	elseif option == "manager" then
		if once("manager", 4) then
			nxt({ "listen", "discount", "refuse", "bye" })
			return pick(ctx.rng, { "Oh. YOU'RE the manager? ...Then you should KNOW what's wrong.", "Finally. Someone with authority. Here's my list.", "Hm. You look very young to be a manager." })
		end
		return "Yes, yes, you said that."
	elseif option == "refuse" then
		if g.mood >= 45 or ctx.rng:NextNumber() < 0.4 then
			once("refuse", 4)
			nxt({ "bye" })
			return pick(ctx.rng, { "...Fine. FINE. I respect a firm hand.", "Hmph. Well. Rules are rules, I suppose.", "...Okay. That's actually fair." })
		end
		ctx.moodShift(g, -6)
		Life.scene(ctx, g)
		nxt({ "discount", "sorry", "bye" })
		return "POLICY?! I'll show you policy!"
	elseif option == "discount" then
		local d = g.discount or 0
		if d >= 0.5 then return "Don't think this makes us friends." end
		g.discount = d + 0.25
		ctx.moodShift(g, d == 0 and 20 or 6, nil, d == 0 and "Got money off my bill. As I should." or nil)
		nxt({ "bye" })
		return pick(ctx.rng, { "That's the LEAST you could do. ...Thank you.", "Well. Finally someone with sense.", "Hmph. Fine. I'll consider staying." })
	elseif option == "bye" and g.mood < 50 then
		ctx.moodShift(g, -3)
		return pick(ctx.rng, { "I'm NOT finished with you!", "Don't you walk away from me!", "I'll be talking to your boss!" })
	end
	return nil
end
Life.typeReply = typeReply

-- the desk, or you: a Karen goes and complains
DO.complain = function(ctx, g)
	if not (g.gtype and g.gtype.id == "karen") then return false end
	if g.mood >= 70 then return false end -- won over
	local p = playerNear(ctx, g)
	if p then return DO.player(ctx, g, "bad") end
	-- at the desk: a scene at whoever's behind it
	local NAV = ctx.NAV
	local a, b = NAV.DeskGuest.Position, NAV.Receptionist.Position
	local fwd = flat(b - a)
	fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-fwd.Z, 0, fwd.X)
	local spot = a + side * 3.6
	ctx.status(g, "angry", "Complaining at the desk")
	ctx.walkTo(g, Vector3.new(spot.X, g.root.Position.Y, spot.Z))
	if not g.alive then return true end
	ctx.faceTo(g, b)
	ctx.say(g, pick(ctx.rng, Life.KAREN_DEMAND), 3)
	ctx.play(g, "point_angry")
	task.wait(2.6)
	if not g.alive then return true end
	ctx.say(g, pick(ctx.rng, KAREN_RANT), 3.2)
	ctx.play(g, "stomp")
	task.wait(2.8)
	-- a receptionist on shift smooths it over
	local clerk
	for _, s in ipairs(ctx.staff or {}) do
		if s.def and s.def.id == "receptionist" and s.g and s.g.alive and s.g.root and not s.g.model:GetAttribute("OnBreak")
			and (s.g.root.Position - b).Magnitude < 6 then clerk = s break end
	end
	if clerk then
		ctx.say(clerk.g, pick(ctx.rng, { "I'm so sorry. Let me see what I can do.", "Of course. I'll sort that right away.", "I completely understand. Leave it with me." }), 3)
		ctx.play(clerk.g, "apologise")
		task.wait(2.4)
		ctx.moodShift(g, 6, nil, "The receptionist actually listened.")
		if g.alive then ctx.say(g, "Hmph. Well. See that you do.", 2.6) end
	else
		Life.scene(ctx, g)
		ctx.tell("toast", { text = g.name .. " is making a scene at the front desk!", icon = "angry", bad = true })
	end
	task.wait(1.4)
	return true
end

-- extra acts inside the room (RAH_HotelSim's stayIn runs them; Life.orderHook slots them in)
Life.STAY_ACTS = {}
Life.STAY_ACTS.Judge = function(ctx, g, room)
	local rs = room.model:GetAttribute("Stars") or 1
	ctx.status(g, "star", "Judging the room")
	ctx.play(g, "@inspect")
	task.wait(3)
	ctx.stop(g, "@inspect")
	if rs <= 2 then
		ctx.moodShift(g, -10, "I expected a suite. This is a shoebox.", "Paid top dollar for a tiny basic room.")
		ctx.say(g, "Is this... the whole room?", 3)
		ctx.play(g, "head_shake")
	elseif rs >= 4 then
		ctx.moodShift(g, 8, "Now THIS is a room!", "A room fit for royalty.")
		ctx.say(g, "Now THIS is more like it!", 3)
		ctx.play(g, "clap")
	else
		ctx.say(g, "It'll do. I suppose.", 2.6)
	end
	task.wait(1.2)
end
Life.STAY_ACTS.Wipe = function(ctx, g, room)
	ctx.status(g, "clean", "Wiping everything down")
	ctx.say(g, pick(ctx.rng, { "Let me just... wipe this down.", "Germs. Germs everywhere.", "I'll do it myself, thanks." }), 3)
	ctx.play(g, "@clean")
	task.wait(ctx.rng:NextNumber(6, 9))
	ctx.stop(g, "@clean")
	if room.model:GetAttribute("Stars") and room.model:GetAttribute("Stars") >= 3 then
		ctx.moodShift(g, 4, "Surprisingly clean, actually.", "Spotless room. I checked.")
	end
end
Life.STAY_ACTS.Party = function(ctx, g, room)
	g.partying = true
	g.quieted = false
	ctx.status(g, "happy", "Throwing a party")
	ctx.say(g, pick(ctx.rng, { "PARTY TIME!", "Turn it UP!", "Who wants to dance?!" }), 3)
	ctx.tell("toast", { text = "Room " .. room.id .. " is throwing a party! The neighbours won't like it", icon = "angry", bad = true })
	ctx.play(g, "@dance")
	local t0 = os.clock()
	local hit = {}
	while g.alive and not g.quieted and os.clock() - t0 < 22 do
		if ctx.burst then ctx.burst(g.head.Position + Vector3.new(0, 1.5, 0), "confetti", 18) end
		ctx.sfx("jingle", g.head.Position)
		-- the neighbours hear it
		for other in pairs(ctx.guests) do
			local r = other.room
			if other ~= g and other.alive and r and r.occupant == other and not hit[other]
				and (r.nav.Enter.Position - room.nav.Enter.Position).Magnitude < 45 then
				hit[other] = true
				ctx.moodShift(other, other.sleeping and -10 or -5, "Someone next door was partying all night!", "Noisy party next door.")
				ctx.say(other, pick(ctx.rng, { "Keep it DOWN in there!", "Some of us are trying to sleep!", "Is that a party?!" }), 3)
			end
		end
		task.wait(2.5)
	end
	ctx.stop(g, "@dance")
	g.partying = false
	ctx.moodShift(g, 6)
	if g.quieted then ctx.say(g, "Fine, fine. Quiet party.", 2.6) end
end
Life.STAY_ACTS.Nap = function(ctx, g, room) end -- (sleepy guests go straight to bed: see orderHook)

-- a type reshapes the stay's plan
function Life.orderHook(g, order)
	local t = g.gtype
	if not t then return end
	if t.id == "bigspender" then table.insert(order, 1, "Judge") end
	if t.id == "germ" then table.insert(order, 1, "Wipe") end
	if t.id == "party" then table.insert(order, math.max(1, #order), "Party") end
	if t.id == "sleepy" then
		local i = table.find(order, "Bed")
		if i then table.remove(order, i) end
		table.insert(order, 1, "Bed")
	end
end

-- at check-out a shifty guest tries to slip away. True when they got away with it.
function Life.tryDash(ctx, g)
	local t = g.gtype
	if not (t and t.dash) or g.caught or ctx.rng:NextNumber() > t.dash then return false end
	g.dashing = true
	ctx.status(g, "run", "Sneaking out")
	ctx.say(g, pick(ctx.rng, { "Nobody's looking...", "Just... gonna... go.", "Act natural. Act natural." }), 2.6)
	ctx.tell("toast", { text = g.name .. " is sneaking out without paying! Talk to them!", icon = "run", bad = true })
	ctx.walkTo(g, ctx.NAV.Inside.Position)
	if g.alive and not g.caught then ctx.walkTo(g, ctx.NAV.PathStart.Position) end
	-- a beat on the doorstep, looking back over their shoulder
	local t0 = os.clock()
	while g.alive and not g.caught and os.clock() - t0 < 2.5 do task.wait(0.2) end
	g.dashing = false
	if not g.alive then return true end
	if g.caught then
		ctx.play(g, "apologise")
		g.payMul = (g.payMul or 1) * 1.15 -- a guilty tip
		return false
	end
	ctx.tell("toast", { text = g.name .. " got away without paying!", icon = "run", bad = true })
	return true
end

-- two neighbours in the line outside swap a line
function Life.queueChat(ctx, back, front)
	if not (back.alive and front.alive) then return end
	local qa = pick(ctx.rng, Life.QUEUE)
	ctx.say(back, qa[1], 2.6)
	task.delay(2.2, function()
		if front.alive and front.slot and back.slot and front.slot < back.slot then
			ctx.say(front, qa[2], 2.6)
		end
	end)
end

function Life.playerLeft(p) playerGap[p] = nil end

return Life
