-- ServerScriptService.RAH_QuestServer (round 10c): tracks every hotel's chapter goals (defs in RAH.Quests).
-- Other server scripts report what happens with  RAH_Signals.Quest:Fire(hotel, stat, n)  (letin, checkin,
-- clean, collect, place, placeLobby, talk, earn, review5, guests, research). State goals (level, rating,
-- rooms, staff) are read off the hotel every second. Progress is the hotel attribute Quests (JSON, saved by
-- RAH_Save). A finished goal pays its cash to the hotel's owner and its XP to the hotel, and tells the members
-- (Notify "quest"); a finished chapter moves on to the next a moment later (Notify "chapter").
-- Achievements (round 10c, Q.ACHIEVEMENTS): every signal also adds to the lifetime totals (state.life); the
-- owner claims each reached tier through Remotes.Achieve ("claim", id), and claimed tiers go in state.ach.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Q = require(RAH:WaitForChild("Quests"))
local Levels = require(RAH:WaitForChild("Levels"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local SIGNALS = game.ServerStorage:WaitForChild("RAH_Signals")
local PLOTS = workspace:WaitForChild("Plots")

local Sig = SIGNALS:FindFirstChild("Quest") or Instance.new("BindableEvent")
Sig.Name = "Quest"
Sig.Parent = SIGNALS

local STAFF_ATTR = {}
for _, def in ipairs(C.STAFF) do STAFF_ATTR[def.id] = def.attr end

local function tell(hotel, kind, data)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("RAH_Plot") == hotel.Name then Notify:FireClient(p, kind, data) end
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
	if changed then write(hotel, st) end
end)

-- state goals, checked every second in every claimed hotel
task.spawn(function()
	while true do
		for _, hotel in ipairs(PLOTS:GetChildren()) do
			if hotel:GetAttribute("Owner") and hotel:FindFirstChild("Rooms") then
				local st = stateOf(hotel)
				local ch = Q.CHAPTERS[st.ch]
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

local Achieve = RAH.Remotes:FindFirstChild("Achieve")
if not Achieve then
	Achieve = Instance.new("RemoteFunction")
	Achieve.Name = "Achieve"
	Achieve.Parent = RAH.Remotes
end
local claimGap = {}
Achieve.OnServerInvoke = function(player, action, id)
	if action ~= "claim" or type(id) ~= "string" then return false, "?" end
	local now = os.clock()
	if now < (claimGap[player] or 0) then return false, "Slow down" end
	claimGap[player] = now + 0.3
	local a = Q.ACH_BY_ID[id]
	local hotel = PLOTS:FindFirstChild(player:GetAttribute("RAH_Plot") or "")
	if not a or not hotel then return false, "?" end
	if hotel:GetAttribute("Owner") ~= player.UserId then return false, "Only the hotel's owner can claim rewards" end
	local st = stateOf(hotel)
	local v = a.state and Q.stateValue(hotel, a.state, STAFF_ATTR) or (tonumber(st.life[a.stat]) or 0)
	local have = tonumber(st.ach[id]) or 0
	local tier = have + 1
	if tier > #a.tiers or Q.tierOf(a, v) < tier then return false, "Not yet!" end
	st.ach[id] = tier
	write(hotel, st)
	local cash = a.cash[tier] or 0
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + cash)
	player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + cash)
	local xp = a.xp and a.xp[tier] or 0
	if xp > 0 then task.defer(Levels.award, hotel, xp, "Achievement") end
	return true, { tier = tier, cash = cash, xp = xp }
end
Players.PlayerRemoving:Connect(function(p) claimGap[p] = nil end)
