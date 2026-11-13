-- ServerScriptService.QuestServer (round 10c): tracks every hotel's chapter goals (defs in Shared.Quests).
-- Other server scripts report what happens with  Signals.Quest:Fire(hotel, stat, n)  (letin, checkin,
-- clean, collect, place, placeLobby, talk, earn, review5, guests, research). State goals (level, rating,
-- rooms, staff) are read off the hotel every second. Progress is the hotel attribute Quests (JSON, saved by
-- Save). A finished goal pays its cash to the hotel's owner and its XP to the hotel, and tells the members
-- (Notify "quest"); a finished chapter moves on to the next a moment later (Notify "chapter").
-- Achievements (round 10c, Q.ACHIEVEMENTS): every signal also adds to the lifetime totals (state.life); the
-- owner claims each reached tier through Remotes.Achieve ("claim", id), and claimed tiers go in state.ach.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Q = require(Shared:WaitForChild("Quests"))
local Levels = require(Shared:WaitForChild("Levels"))
local Notify = Shared.Remotes:WaitForChild("Notify")
local SIGNALS = game.ServerStorage:WaitForChild("Signals")
local PLOTS = workspace:WaitForChild("Plots")

local Sig = SIGNALS:FindFirstChild("Quest") or Instance.new("BindableEvent")
Sig.Name = "Quest"
Sig.Parent = SIGNALS

local STAFF_ATTR = {}
for _, def in ipairs(C.STAFF) do STAFF_ATTR[def.id] = def.attr end

local function tell(hotel, kind, data)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == hotel.Name then Notify:FireClient(p, kind, data) end
	end
end

-- the hotel's progress (re-read whenever the attribute changes, e.g. when a save loads)
local cache = {} -- hotel -> { json, state }
local function stateOf(hotel)
	local json = hotel:GetAttribute("Quests")
	local c = cache[hotel]
	if c and c.json == json then return c.state end
	local st
	if type(json) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(t) == "table" then st = t end
	end
	st = st or {}
	st.ch = tonumber(st.ch) or 1
	st.p = type(st.p) == "table" and st.p or {}
	st.done = type(st.done) == "table" and st.done or {}
	st.life = type(st.life) == "table" and st.life or {}
	st.ach = type(st.ach) == "table" and st.ach or {}
	cache[hotel] = { json = json, state = st }
	return st
end

local function write(hotel, st)
	local json = HttpService:JSONEncode(st)
	cache[hotel] = { json = json, state = st }
	hotel:SetAttribute("Quests", json)
end

local function stateValue(hotel, q)
	return Q.stateValue(hotel, q.state, STAFF_ATTR)
end

local advancing = {}
local function complete(hotel, st, q)
	st.done[q.id] = true
	st.p[q.id] = q.goal
	local owner = Players:GetPlayerByUserId(hotel:GetAttribute("Owner") or 0)
	if owner and q.cash and q.cash > 0 then
		owner:SetAttribute("Cash", (owner:GetAttribute("Cash") or 0) + q.cash)
		owner:SetAttribute("Earned", (owner:GetAttribute("Earned") or 0) + q.cash)
	end
	tell(hotel, "quest", { id = q.id, cash = q.cash, xp = q.xp })
	if q.xp and q.xp > 0 then task.defer(Levels.award, hotel, q.xp, "Goal complete") end
	-- the whole chapter done: the next one starts a moment later
	local ch = Q.CHAPTERS[st.ch]
	local all = true
	for _, x in ipairs(ch.quests) do
		if not st.done[x.id] then all = false break end
	end
	if all and not advancing[hotel] then
		advancing[hotel] = true
		task.delay(2.6, function()
			advancing[hotel] = nil
			if not hotel.Parent then return end
			local s2 = stateOf(hotel)
			if s2.ch ~= q.chapter then return end
			s2.ch += 1
			write(hotel, s2)
			local nxt = Q.CHAPTERS[s2.ch]
			tell(hotel, "chapter", { ch = s2.ch, title = nxt and nxt.title, done = ch.title })
		end)
	end
end

-- round 38: an odd job done: pay it, count it (achievement "jobs") and free its slot; the loop below fills it again.
-- The last few finished ids stay in done/p so the client can play the card's "complete" moment.
local function completeSide(hotel, st, q)
	st.done[q.id] = true
	st.p[q.id] = q.goal
	local owner = Players:GetPlayerByUserId(hotel:GetAttribute("Owner") or 0)
	if owner and q.cash and q.cash > 0 then
		owner:SetAttribute("Cash", (owner:GetAttribute("Cash") or 0) + q.cash)
		owner:SetAttribute("Earned", (owner:GetAttribute("Earned") or 0) + q.cash)
	end
	tell(hotel, "quest", { id = q.id, cash = q.cash, xp = q.xp })
	if q.xp and q.xp > 0 then task.defer(Levels.award, hotel, q.xp, "Odd job done") end
	st.life.jobs = (tonumber(st.life.jobs) or 0) + 1
	for i, x in ipairs(st.sq) do
		if x.id == q.id then table.remove(st.sq, i) break end
	end
	st.sold = type(st.sold) == "table" and st.sold or {}
	table.insert(st.sold, q.id)
	while #st.sold > 3 do
		local old = table.remove(st.sold, 1)
		st.done[old], st.p[old] = nil, nil
	end
end

local sideRng = Random.new()
local function fillSide(hotel, st)
	st.sq = type(st.sq) == "table" and st.sq or {}
	local added = false
	while #st.sq < Q.SIDE_SLOTS do
		st.sn = (tonumber(st.sn) or 0) + 1
		table.insert(st.sq, Q.rollSide(Levels.of(hotel), st.sq, st.sn, sideRng))
		added = true
	end
	return added
end

-- a counted thing happened in a hotel
Sig.Event:Connect(function(hotel, stat, n)
	if typeof(hotel) ~= "Instance" or not hotel.Parent then return end
	local st = stateOf(hotel)
	st.life[stat] = (tonumber(st.life[stat]) or 0) + (n or 1)
	local changed = true
	local ch = Q.CHAPTERS[st.ch]
	for _, q in ipairs(ch and ch.quests or {}) do
		if q.stat == stat and not st.done[q.id] then
			st.p[q.id] = math.min(q.goal, (st.p[q.id] or 0) + (n or 1))
			changed = true
			if st.p[q.id] >= q.goal then complete(hotel, st, q) end
		end
	end
	for _, q in ipairs(type(st.sq) == "table" and table.clone(st.sq) or {}) do
		if q.stat == stat and not st.done[q.id] then
			st.p[q.id] = math.min(q.goal, (st.p[q.id] or 0) + (n or 1))
			if st.p[q.id] >= q.goal then completeSide(hotel, st, q) end
		end
	end
	if changed then write(hotel, st) end
end)

-- state goals, checked every second in every claimed hotel
task.spawn(function()
	while true do
		for _, hotel in ipairs(PLOTS:GetChildren()) do
			if hotel:GetAttribute("Owner") and hotel:FindFirstChild("Rooms") then
				local st = stateOf(hotel)
				local ch = Q.CHAPTERS[st.ch]
				if fillSide(hotel, st) and hotel:GetAttribute("Quests") ~= nil then write(hotel, st) end -- round 38
				if ch then
					local changed = hotel:GetAttribute("Quests") == nil
					for _, q in ipairs(ch.quests) do
						if q.state and not st.done[q.id] then
							local v = math.min(q.goal, stateValue(hotel, q))
							if v ~= st.p[q.id] then
								st.p[q.id] = v
								changed = true
							end
							if v >= q.goal then complete(hotel, st, q) changed = true end
						end
					end
					if changed then write(hotel, st) end
				end
			end
		end
		for h in pairs(cache) do
			if not h.Parent then cache[h] = nil end
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------- achievements: the owner claims each tier

local Achieve = Shared.Remotes:FindFirstChild("Achieve")
if not Achieve then
	Achieve = Instance.new("RemoteFunction")
	Achieve.Name = "Achieve"
	Achieve.Parent = Shared.Remotes
end
local claimGap = {}
Achieve.OnServerInvoke = function(player, action, id)
	if action == "tag" and type(id) == "string" then -- round 39: wear a tag ("" takes it off)
		local hotel = PLOTS:FindFirstChild(player:GetAttribute("Plot") or "")
		if not hotel or hotel:GetAttribute("Owner") ~= player.UserId then return false, "Tags come from your own hotel" end
		local st = stateOf(hotel)
		if id == "" then
			st.title = nil
		elseif Q.TITLES[id] and (tonumber(st.ach[id]) or 0) > 0 then
			st.title = id
		else
			return false, "Claim its first tier to unlock it"
		end
		write(hotel, st)
		return true
	end
	if action ~= "claim" or type(id) ~= "string" then return false, "?" end
	local now = os.clock()
	if now < (claimGap[player] or 0) then return false, "Slow down" end
	claimGap[player] = now + 0.3
	local a = Q.ACH_BY_ID[id]
	local hotel = PLOTS:FindFirstChild(player:GetAttribute("Plot") or "")
	if not a or not hotel then return false, "?" end
	if hotel:GetAttribute("Owner") ~= player.UserId then return false, "Only the hotel's owner can claim rewards" end
	local st = stateOf(hotel)
	local v = a.state and Q.stateValue(hotel, a.state, STAFF_ATTR) or (tonumber(st.life[a.stat]) or 0)
	local have = tonumber(st.ach[id]) or 0
	local tier = have + 1
	if tier > #a.tiers or Q.tierOf(a, v) < tier then return false, "Not yet!" end
	st.ach[id] = tier
	local newTag = tier == 1 and Q.TITLES[id] or nil
	if newTag and not st.title then st.title = id end -- the first tag goes straight on
	write(hotel, st)
	local cash = a.cash[tier] or 0
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + cash)
	player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + cash)
	local xp = a.xp and a.xp[tier] or 0
	if xp > 0 then task.defer(Levels.award, hotel, xp, "Achievement") end
	return true, { tier = tier, cash = cash, xp = xp, tag = newTag }
end
Players.PlayerRemoving:Connect(function(p) claimGap[p] = nil end)

---------------------------------------------------------------- round 39: minigame extras
-- HotelSim reports every finished minigame on Signals.Minigame (hotel, player, kind, stars, secs, bonus). Three
-- stars in a row builds a hot streak (player attribute MGStreak) that pays from x2; a grabbed bonus coin pays
-- Q.mgCoin(level); the hotel keeps each game's best time in state.best (the result card shows it).
local MG_KINDS = { Floor = true, Bed = true, Shower = true, Toilet = true, CheckIn = true, CheckOut = true, Cook = true, Repair = true }
local MGSig = SIGNALS:FindFirstChild("Minigame") or Instance.new("BindableEvent")
MGSig.Name = "Minigame"
MGSig.Parent = SIGNALS
MGSig.Event:Connect(function(hotel, player, kind, stars, secs, bonus)
	if not MG_KINDS[kind] or not player.Parent then return end
	local streak = stars >= 3 and (player:GetAttribute("MGStreak") or 0) + 1 or 0
	player:SetAttribute("MGStreak", streak)
	local pay = (streak >= 2 and math.min(streak, Q.MG.cap) * Q.MG.streak or 0) + (bonus and Q.mgCoin(hotel:GetAttribute("Level")) or 0)
	if pay > 0 then
		player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + pay)
		player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + pay)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then Notify:FireClient(player, "paid", { amount = pay, pos = root.Position + Vector3.new(0, 3, 0) }) end
	end
	if secs and secs >= C.MINIGAME_MIN and secs <= C.MINIGAME_TIMEOUT then
		local st = stateOf(hotel)
		st.best = type(st.best) == "table" and st.best or {}
		secs = math.floor(secs * 10 + 0.5) / 10
		local b = tonumber(st.best[kind])
		if not b or secs < b then
			st.best[kind] = secs
			write(hotel, st)
		end
	end
end)

---------------------------------------------------------------- round 39: tags over the head
-- The owner's worn tag (state.title) goes on the player as attributes Tag / TagTier (Bubbles prints it in front
-- of their chat) and as a pill just above their name. A co-op member away from their own hotel keeps theirs.
local TAG_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local function tagOf(player)
	for _, hotel in ipairs(PLOTS:GetChildren()) do
		if hotel:GetAttribute("Owner") == player.UserId and hotel:FindFirstChild("Rooms") then
			local st = stateOf(hotel)
			local tier = st.title and math.clamp(tonumber(st.ach[st.title]) or 0, 0, 3) or 0
			if tier > 0 and Q.TITLES[st.title] then return true, Q.TITLES[st.title], tier end
			return true, nil, nil
		end
	end
	return false
end
local function wearTag(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	local text, tier = player:GetAttribute("Tag"), player:GetAttribute("TagTier") or 1
	local bb = head:FindFirstChild("TagGui")
	local key = text and (text .. tier)
	if bb and bb:GetAttribute("Key") == key then return end
	if bb then bb:Destroy() end
	if not text then return end
	bb = Instance.new("BillboardGui")
	bb.Name = "TagGui"
	bb:SetAttribute("Key", key)
	bb.Size = UDim2.fromOffset(240, 24)
	bb.StudsOffset = Vector3.new(0, 1.55, 0)
	bb.SizeOffset = Vector2.new(0, 1.45) -- pixels above the name, so it never slides onto it far away
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	local col = Q.TAG_COL[tier] or Q.TAG_COL[1]
	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(0, 22)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = col
	pill.Text = string.upper(text)
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.TextSize = 15
	pill.FontFace = TAG_FONT
	pill.Parent = bb
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = pill
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Thickness = 2
	rim.Color = col:Lerp(Color3.new(0, 0, 0), 0.4)
	rim.Parent = pill
	local ts = Instance.new("UIStroke")
	ts.Thickness = 1.5
	ts.Color = col:Lerp(Color3.new(0, 0, 0), 0.55)
	ts.Parent = pill
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	g.Rotation = 90
	g.Parent = pill
	bb.Parent = head
end
task.spawn(function()
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			local owns, text, tier = tagOf(p)
			if owns then
				if p:GetAttribute("Tag") ~= text then p:SetAttribute("Tag", text) end
				if p:GetAttribute("TagTier") ~= tier then p:SetAttribute("TagTier", tier) end
			end
			pcall(wearTag, p)
		end
		task.wait(1)
	end
end)
