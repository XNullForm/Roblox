-- ServerScriptService.Save: keeps each player's money and the owner's hotel between visits.
-- DataStore "RAH_Save_v1", key "u_<UserId>":
--   { v = 1, cash, earned, cleaned, spent, rooms = { 104, 105 }, items = { {i = itemId, x, z, r = quarter turns, c = core, rm = room,
--     a = yaw in degrees (when not a quarter turn), y = height above the floor, s = {x,y,z} / col = hex / m = material / g = walk-through (shapes)} },
--   research = the hotel's Research JSON (round 9), quests / reviews = the hotel's Quests / Reviews JSON (round 10c),
--     staff = { janitor = 2, doorman = 1 }, tiers = { ["101"] = 2 } }
-- Every player's own hotel (Plots: player attribute Home) is loaded from and saved to their save.
-- Furniture x is stored relative to the plot's Origin, so a hotel loads onto whichever plot you get.
-- Work done in a co-op friend's hotel is saved in the friend's save. Everyone's cash is their own.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Build = require(Shared:WaitForChild("Build"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Notify = Shared.Remotes:WaitForChild("Notify")
local ITEMS = Shared:WaitForChild("Items")
local PLOTS = workspace:WaitForChild("Plots")
local SIGNALS = game.ServerStorage:WaitForChild("Signals")
local ItemsChanged = SIGNALS:WaitForChild("ItemsChanged")
local RoomAdded = SIGNALS:WaitForChild("RoomAdded")
local Builder = require(game.ServerStorage:WaitForChild("HotelBuilder"))
local RoomScan = require(game.ServerStorage:WaitForChild("Rooms"))

local VERSION = 1
local store = DataStoreService:GetDataStore("RAH_Save_v1")
local STATS = { "Cash", "Earned", "Cleaned", "Spent", "Tut" }

-- a player's own hotel, once Plots and its sim have set it up (nil if they have none)
local function homeOf(player, wait)
	local t0 = os.clock()
	repeat
		local name = player:GetAttribute("Home")
		local h = name and PLOTS:FindFirstChild(name)
		if h and h:GetAttribute("HotelReady") and h:GetAttribute("BuildReady") then return h end
		if not wait then return nil end
		task.wait(0.1)
	until os.clock() - t0 > 20 or not player.Parent
	return nil
end

-- round 12: the player's settings (client attributes, sent through Remotes.Prefs) save with their profile.
-- Only these keys, only booleans and numbers in range. They come back as server-set player attributes at join.
local PREF_KEYS = {
	MusicVol = { 0, 100 }, SfxVol = { 0, 100 }, MusicOff = true, SfxOff = true, UiSfxOff = true,
	Sprint = true, HideQuests = true, HideReviews = true, HideBubbles = true, HideRoomSigns = true,
	HideDaySummary = true, HidePops = true, FOV = { 55, 100 }, ShadowsOff = true,
	PromptSize = { 60, 140 }, LookSens = { 25, 200 }, LookInvert = true,
}
local prefs = {} -- player -> { key = value }
local function cleanPrefs(t)
	if type(t) ~= "table" then return nil end
	local out, n = {}, 0
	for k, rule in pairs(PREF_KEYS) do
		local v = t[k]
		if rule == true and type(v) == "boolean" then
			out[k] = v
			n += 1
		elseif type(rule) == "table" and type(v) == "number" and v == v then
			out[k] = math.clamp(v, rule[1], rule[2])
			n += 1
		end
	end
	return out, n
end
local function applyPrefs(player, t)
	for k, v in pairs(t) do player:SetAttribute(k, v) end
end
local prefsRemote = Shared.Remotes:FindFirstChild("Prefs") or Instance.new("RemoteEvent")
prefsRemote.Name = "Prefs"
prefsRemote.Parent = Shared.Remotes
local lastPrefs = {}
prefsRemote.OnServerEvent:Connect(function(player, t)
	if os.clock() - (lastPrefs[player] or 0) < 0.5 then return end
	lastPrefs[player] = os.clock()
	local clean = cleanPrefs(t)
	if clean then prefs[player] = clean end
end)

local loaded = {} -- player -> true once their save is in (we never save over data we haven't read)
local hotelDirty = false
local changes = 0 -- bumped on every hotel change, so a save only clears hotelDirty if nothing changed while it ran

-- round 10: one save per player. It lives in what used to be save file 1, so nobody loses their hotel
local function key(player)
	return "u_" .. player.UserId .. "_s1"
end
local wiping = {} -- player -> true while a reset is deleting their save (a new game waits for it)

local function retry(fn)
	for i = 1, 3 do
		local ok, res = pcall(fn)
		if ok then return true, res end
		warn("Shared save: " .. tostring(res))
		task.wait(i * 1.5)
	end
	return false
end

---------------------------------------------------------------- hotel <-> table

local function snapshot(HOTEL)
	local PLACED = HOTEL.Placed
	local ox = (HOTEL:GetAttribute("Origin") or Vector3.zero).X
	local rooms = {}
	local land = {} -- round 10d: bought land (a wing with no built-in room)
	for _, slot in ipairs(C.ROOM_SLOTS) do
		if HOTEL.Rooms:FindFirstChild("Room" .. slot.id) then
			table.insert(rooms, slot.id)
		elseif HOTEL.Shell:FindFirstChild("Wing" .. slot.id) then
			table.insert(land, slot.id)
		end
	end
	local items = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		local id = m:GetAttribute("Item")
		if id then
			local cf = m:GetPivot()
			local yaw = Build.yawOf(cf)
			local e = {
				i = id,
				x = math.floor((cf.Position.X - ox) * 20 + 0.5) / 20,
				z = math.floor(cf.Position.Z * 20 + 0.5) / 20,
				r = math.floor(yaw / 90 + 0.5) % 4,
				c = m:GetAttribute("Core"),
				rm = m:GetAttribute("Room"),
			}
			-- round 9: a turn that isn't a quarter, a height above the floor, a shape's make
			local a = math.floor(yaw + 0.5) % 360
			if a % 90 ~= 0 then e.a = a end
			local y = math.floor((cf.Position.Y - Build.FY) * 20 + 0.5) / 20
			if y > 0 then e.y = y end
			local size = m:GetAttribute("Size")
			if typeof(size) == "Vector3" then
				e.s = { size.X, size.Y, size.Z }
				local col = m:GetAttribute("Color")
				if typeof(col) == "Color3" then e.col = col:ToHex() end
				e.m = m:GetAttribute("Mat")
				if m:GetAttribute("Ghost") then e.g = true end
			end
			table.insert(items, e)
		end
	end
	local staff = {}
	for _, def in ipairs(C.STAFF) do staff[def.id] = HOTEL:GetAttribute(def.attr) or 0 end
	local tiers = {}
	for _, m in ipairs(HOTEL.Rooms:GetChildren()) do
		local t = m:GetAttribute("Tier")
		if t and t > 1 then tiers[tostring(m:GetAttribute("RoomId"))] = t end
	end
	-- the reception desk's spot (it's movable in build mode)
	local desk
	local dm = HOTEL.Lobby:FindFirstChild("Desk")
	if dm then
		local cf = dm:GetPivot()
		local _, yaw = cf:ToEulerAnglesYXZ()
		desk = {
			x = math.floor((cf.Position.X - ox) * 10 + 0.5) / 10,
			z = math.floor(cf.Position.Z * 10 + 0.5) / 10,
			r = math.floor(yaw / (math.pi / 2) + 0.5) % 4,
		}
	end
	return rooms, items, staff, tiers, desk, land, RoomScan.hints(HOTEL)
end

local function cfOf(e, ox)
	local yaw = type(e.a) == "number" and e.a or 90 * (tonumber(e.r) or 0)
	local y = type(e.y) == "number" and math.clamp(e.y, 0, Build.CEIL - Build.FY) or 0
	return Build.pivot(e.x + ox, y, e.z, yaw)
end

-- a saved shape's size / colour / finish
local function optsOf(e)
	if type(e.s) ~= "table" then return {} end
	local ok, col = pcall(Color3.fromHex, tostring(e.col or ""))
	return {
		size = Vector3.new(tonumber(e.s[1]) or 4, tonumber(e.s[2]) or 4, tonumber(e.s[3]) or 4),
		color = ok and col or nil,
		mat = type(e.m) == "string" and e.m or nil,
		ghost = e.g == true,
	}
end

local function known(id)
	local it = Catalog.ITEMS[id]
	return it ~= nil and (it.shape ~= nil or ITEMS:FindFirstChild(id) ~= nil)
end

local function restoreHotel(data, HOTEL)
	local PLACED = HOTEL.Placed
	if type(data.name) == "string" and data.name ~= "" then
		HOTEL:SetAttribute("HotelName", data.name:sub(1, 24))
	end
	-- research first: it decides which items and finishes the save may bring back
	if type(data.research) == "string" then HOTEL:SetAttribute("Research", data.research) end
	-- round 10c: chapter goals and the guests' reviews
	if type(data.quests) == "string" then HOTEL:SetAttribute("Quests", data.quests) end
	if type(data.reviews) == "string" then HOTEL:SetAttribute("Reviews", data.reviews) end
	if type(data.staffxp) == "string" then HOTEL:SetAttribute("StaffXP", data.staffxp) end -- round 10e
	-- round 13: staff looks and jobs
	if type(data.stafflooks) == "string" then HOTEL:SetAttribute("StaffLooks", data.stafflooks) end
	if type(data.staffjobs) == "string" then HOTEL:SetAttribute("StaffJobs", data.staffjobs) end
	if type(data.staffprofiles) == "string" then HOTEL:SetAttribute("StaffProfiles", data.staffprofiles) end
	if type(data.dirty) == "string" and data.dirty ~= "[]" then HOTEL:SetAttribute("DirtyRestore", data.dirty) end
	-- round 11: the hotel grade (the roof is rebuilt to match; land restored below rebuilds it again)
	if type(data.grade) == "number" and data.grade > 1 then
		HOTEL:SetAttribute("Grade", math.clamp(math.floor(data.grade), 1, 5))
		Builder.roof(HOTEL)
	end
	-- round 10: the hotel level
	if type(data.level) == "number" then
		local Levels = require(Shared:WaitForChild("Levels"))
		local lv = math.clamp(math.floor(data.level), 1, Levels.MAX)
		HOTEL:SetAttribute("Level", lv)
		HOTEL:SetAttribute("XP", math.max(0, math.floor(tonumber(data.xp) or 0)))
		HOTEL:SetAttribute("XPNeed", Levels.need(lv))
	end
	local ox = (HOTEL:GetAttribute("Origin") or Vector3.zero).X
	-- 1. rooms, in slot order (each needs the one before it)
	local want = {}
	for _, id in ipairs(data.rooms or {}) do want[id] = true end
	local land = {}
	for _, id in ipairs(type(data.land) == "table" and data.land or {}) do land[id] = true end
	local built = 0
	for _, slot in ipairs(C.ROOM_SLOTS) do
		if want[slot.id] then
			if not HOTEL.Rooms:FindFirstChild("Room" .. slot.id) then
				local room = Builder.buildWing(HOTEL, slot)
				RoomAdded:Fire(room)
				built += 1
			end
		elseif land[slot.id] then
			if not HOTEL.Shell:FindFirstChild("Wing" .. slot.id) then Builder.buildLand(HOTEL, slot) end
		else
			break
		end
	end
	-- 2. furniture: core items move to their saved spots; everything else is replaced by the save
	if data.items then
		for _, m in ipairs(PLACED:GetChildren()) do
			if not m:GetAttribute("Core") then m:Destroy() end
		end
		for _, e in ipairs(data.items) do
			if type(e) == "table" and type(e.x) == "number" and type(e.z) == "number" and known(tostring(e.i)) then
				local cf = cfOf(e, ox)
				if e.c then
					-- the room's own bed/shower/toilet: move it if the room came with one,
					-- otherwise (an unfurnished wing) bring it back from the save
					local found = false
					for _, m in ipairs(PLACED:GetChildren()) do
						if m:GetAttribute("Core") == e.c and m:GetAttribute("Room") == e.rm then
							m:PivotTo(cf)
							found = true
						end
					end
					if not found then
						local zone = Build.zoneAt(cf.Position)
						if zone then
							local m = Build.make(e.i, cf)
							m:SetAttribute("Item", e.i)
							m:SetAttribute("Zone", zone.Name)
							m:SetAttribute("Core", e.c)
							m:SetAttribute("Room", e.rm)
							m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8))
							m.Parent = PLACED
						end
					end
				else
					local zone = Build.zoneAt(cf.Position)
					if zone then
						local m = Build.make(e.i, cf, optsOf(e))
						m:SetAttribute("Item", e.i)
						m:SetAttribute("Zone", zone.Name)
						m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8))
						m.Parent = PLACED
					end
				end
			end
		end
		for _, m in ipairs(PLACED:GetChildren()) do
			local zone = Build.zoneAt(m:GetPivot().Position)
			if zone then m:SetAttribute("Zone", zone.Name) end
			if not m:GetAttribute("Uid") then m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8)) end
		end
	end
	-- 2b. rooms made with walls come back with their old numbers
	pcall(RoomScan.scan, HOTEL, type(data.custom) == "table" and data.custom or nil)
	-- 3. room upgrades (Hotel redresses a room when its Tier changes)
	if type(data.tiers) == "table" then
		for id, t in pairs(data.tiers) do
			local m = HOTEL.Rooms:FindFirstChild("Room" .. tostring(id))
			if m and type(t) == "number" then m:SetAttribute("Tier", math.clamp(math.floor(t), 1, #C.ROOM_TIERS)) end
		end
	end
	-- 4. staff (Hotel hires them when the attributes change)
	if type(data.staff) == "table" then
		for _, def in ipairs(C.STAFF) do
			local n = data.staff[def.id]
			if type(n) == "number" then HOTEL:SetAttribute(def.attr, math.clamp(math.floor(n), 0, def.max)) end
		end
	end
	-- 5. the reception desk (queue spots and the receptionist's post move with it)
	if type(data.desk) == "table" and type(data.desk.x) == "number" and type(data.desk.z) == "number" then
		Build.moveDesk(HOTEL, cfOf(data.desk, ox))
	end
	local slot = Builder.nextSlot(HOTEL)
	HOTEL:SetAttribute("NextRoom", slot and slot.id or nil)
	HOTEL:SetAttribute("NextRoomPrice", slot and slot.price or nil)
	ItemsChanged:Fire()
	return built
end

---------------------------------------------------------------- save / load

local saving = {} -- player -> true while their save is being written (a reset waits for this to clear)
local function save(player)
	if not loaded[player] or wiping[player] then return end
	saving[player] = true
	local home = homeOf(player)
	local ownsLayout = home ~= nil
	local rooms, items, staff, tiers, desk, land, custom
	local seen = changes
	if ownsLayout then rooms, items, staff, tiers, desk, land, custom = snapshot(home) end
	local ok = retry(function()
		store:UpdateAsync(key(player), function(old)
			local d = type(old) == "table" and old or {}
			d.v = VERSION
			for _, s in ipairs(STATS) do d[string.lower(s)] = player:GetAttribute(s) or 0 end
			if prefs[player] then d.prefs = prefs[player] end
			if ownsLayout then
				d.rooms = rooms
				d.items = items
				d.staff = staff
				d.tiers = tiers
				d.desk = desk
				d.land = land
				d.custom = custom
				d.name = home:GetAttribute("HotelName")
				d.research = home:GetAttribute("Research")
				d.level = home:GetAttribute("Level") or 1
				d.xp = home:GetAttribute("XP") or 0
				d.quests = home:GetAttribute("Quests")
				d.reviews = home:GetAttribute("Reviews")
				d.staffxp = home:GetAttribute("StaffXP")
				d.stafflooks = home:GetAttribute("StaffLooks")
				d.staffjobs = home:GetAttribute("StaffJobs")
				d.staffprofiles = home:GetAttribute("StaffProfiles") -- round 14 (2026-11-09)
				d.dirty = home:GetAttribute("DirtyRooms")
				d.grade = home:GetAttribute("Grade") -- round 11
			end
			d.saved = os.time()
			return d
		end)
	end)
	if ok and ownsLayout and changes == seen then hotelDirty = false end
	saving[player] = nil
	return ok
end

-- a toast a few seconds in, once the player's UI is listening
local function hello(player, d)
	task.spawn(function()
		local t0 = os.clock()
		while player.Parent and not player.Character and os.clock() - t0 < 20 do task.wait(0.2) end
		task.wait(5)
		if player.Parent then Notify:FireClient(player, "toast", d) end
	end)
end

local function load(player)
	while wiping[player] and player.Parent do task.wait(0.1) end
	local ok, data = retry(function() return store:GetAsync(key(player)) end)
	if not player.Parent then return end
	if not ok then
		-- keep the session going, but never overwrite a save we couldn't read
		hello(player, { text = "Couldn't load your save. Progress won't be saved this visit.", icon = "close", bad = true })
		return
	end
	data = type(data) == "table" and data or nil
	if data then
		for _, s in ipairs(STATS) do
			local v = data[string.lower(s)]
			if type(v) == "number" then player:SetAttribute(s, v) end
		end
	end
	-- offline earnings: the hotel kept making money while the owner was away
	local away = ""
	if data and type(data.saved) == "number" and type(data.rooms) == "table" and #data.rooms > 0 then
		local hours = math.clamp((os.time() - data.saved) / 3600, 0, C.OFFLINE_MAX_HOURS)
		if hours >= 0.25 then
			local rate = 0
			for _, id in ipairs(data.rooms) do
				local t = data.tiers and data.tiers[tostring(id)] or 1
				local bonus = C.ROOM_TIERS[math.clamp(t, 1, #C.ROOM_TIERS)].bonus
				rate += C.ROOM_PRICE + bonus
			end
			-- saved furniture's appeal raises the nightly rate
			if type(data.items) == "table" then
				for _, e in ipairs(data.items) do
					if type(e) == "table" then
						local it = Catalog.ITEMS[e.i]
						if it and it.appeal then rate += it.appeal * Catalog.PRICE_PER_APPEAL end
					end
				end
			end
			-- a receptionist keeps the desk moving: a touch more turnover
			if type(data.staff) == "table" and (data.staff.receptionist or 0) > 0 then rate *= 1.15 end
			local earned = math.floor(rate * C.OFFLINE_TURNOVER * C.OFFLINE_SHARE * hours)
			if earned > 0 then
				player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + earned)
				player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + earned)
				away = " It earned $" .. earned .. " while you were away!"
			end
		end
	end
	-- your own hotel comes back onto your plot
	local home = homeOf(player, true)
	if home and data and (data.rooms or data.items or data.staff or data.tiers or data.desk or data.research or data.level or data.quests) then
		local ok2, err = pcall(restoreHotel, data, home)
		if not ok2 then warn("Shared restore: " .. tostring(err)) end
	end
	-- round 11: no "welcome back" toast; only news of money made while away
	if data and away ~= "" then
		hello(player, { text = "Your hotel" .. away:gsub("^ It", ""), icon = "cash" })
	end
	loaded[player] = true
	player:SetAttribute("Loaded", true)
end

-- the save loads when the player presses Play on the title screen. After a reset they're back on the title
-- screen (Slot cleared) and the next Play loads again, which is a brand-new hotel by then
local function onLoad(player)
	while player.Parent do
		while player.Parent and not player:GetAttribute("Slot") do task.wait(0.25) end
		if not player.Parent then return end
		load(player)
		while player.Parent and player:GetAttribute("Slot") do task.wait(0.25) end
	end
end
-- round 10d: the player list shows everyone's cash (leaderstats.Cash follows the Cash attribute)
local function leaderstats(player)
	local ls = player:FindFirstChild("leaderstats") or Instance.new("Folder")
	ls.Name = "leaderstats"
	local v = ls:FindFirstChild("Cash") or Instance.new("IntValue")
	v.Name = "Cash"
	v.Value = player:GetAttribute("Cash") or 0
	v.Parent = ls
	ls.Parent = player
	player:GetAttributeChangedSignal("Cash"):Connect(function() v.Value = math.floor(player:GetAttribute("Cash") or 0) end)
end
Players.PlayerAdded:Connect(leaderstats)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(leaderstats, p) end
Players.PlayerAdded:Connect(onLoad)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onLoad, p) end

-- title screen: a summary of the player's save ({ [1] = summary } or {} for a new player)
local menuRemote = Shared.Remotes:FindFirstChild("Menu") or Instance.new("RemoteEvent")
menuRemote.Name = "Menu"
menuRemote.Parent = Shared.Remotes
menuRemote.OnServerEvent:Connect(function(player, action)
	if action ~= "slots" or player:GetAttribute("Slot") then return end
	task.spawn(function()
		local out = {}
		while wiping[player] and player.Parent do task.wait(0.1) end
		local ok, data = retry(function() return store:GetAsync(key(player)) end)
		local d = ok and type(data) == "table" and data or nil
		if d and not prefs[player] then
			local p = cleanPrefs(d.prefs)
			if p and next(p) then
				prefs[player] = p
				applyPrefs(player, p)
			end
		end
		-- a save that's only stats (no hotel yet) still counts as a fresh start
		if d and (type(d.rooms) == "table" or type(d.items) == "table") then
			out[1] = {
				name = type(d.name) == "string" and d.name ~= "" and d.name or "New Hotel",
				cash = type(d.cash) == "number" and d.cash or 0,
				rooms = C.BASE_ROOMS + (type(d.rooms) == "table" and #d.rooms or 0), -- saved rooms are the extra wings
				level = type(d.level) == "number" and d.level or 1,
				items = type(d.items) == "table" and #d.items or 0,
			}
			-- round 10e: the title screen's save card shows the rating too
			local okR, revs = pcall(function() return game:GetService("HttpService"):JSONDecode(d.reviews) end)
			if okR and type(revs) == "table" and #revs > 0 then
				local sum = 0
				for _, r in ipairs(revs) do sum += math.clamp(tonumber(type(r) == "table" and r.stars) or 3, 1, 5) end
				out[1].stars = sum / #revs
			end
		end
		if player.Parent then menuRemote:FireClient(player, "slots", out) end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	local t0 = os.clock()
	while saving[player] and os.clock() - t0 < 15 do task.wait(0.1) end
	saving[player] = nil
	prefs[player] = nil
	lastPrefs[player] = nil
	loaded[player] = nil
	wiping[player] = nil
end)

ItemsChanged.Event:Connect(function() hotelDirty = true; changes += 1 end)

-- Settings "Reset progress": wipe the save and zero the stats. Plots frees the plot and sends the player back
-- to the title screen; their next Play starts a brand-new hotel
local ResetSave = SIGNALS:FindFirstChild("ResetSave") or Instance.new("BindableEvent")
ResetSave.Name = "ResetSave"
ResetSave.Parent = SIGNALS
ResetSave.Event:Connect(function(player)
	loaded[player] = nil -- nothing to save until the new hotel loads
	wiping[player] = true
	task.spawn(function()
		-- wait out any save that's mid-write, so it can't recreate the data after the wipe
		local t0 = os.clock()
		while saving[player] and os.clock() - t0 < 15 do task.wait(0.1) end
		retry(function() store:RemoveAsync(key(player)) end)
		wiping[player] = nil
	end)
	player:SetAttribute("Cash", C.START_CASH)
	for _, s in ipairs(STATS) do
		if s ~= "Cash" then player:SetAttribute(s, 0) end
	end
end)

-- autosave: a full pass every 5 minutes (with a toast so players know it happened),
-- or 8 s after the hotel changes (a silent safety save)
local AUTOSAVE_SECS = 300
local saveWarned = {} -- player -> true once they've been told their save is failing (no spam while it retries)
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(2)
		local full = os.clock() - last > AUTOSAVE_SECS
		local due = full
		if hotelDirty and os.clock() - last > 8 then due = true end
		if due then
			last = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					local ok = save(p)
					if ok then
						saveWarned[p] = nil
						if full and p.Parent then
							Notify:FireClient(p, "toast", { text = "Game autosaved", icon = "checkmark", kind = "good" })
						end
					elseif p.Parent then
						-- a failed save used to be silent: players lost progress without ever knowing why
						if not saveWarned[p] then
							saveWarned[p] = true
							Notify:FireClient(p, "toast", { text = "Couldn't save! Retrying — check your connection", icon = "close", bad = true })
						end
					end
				end)
			end
		end
	end
end)

game:BindToClose(function()
	local left = 0
	for _, p in ipairs(Players:GetPlayers()) do
		left += 1
		task.spawn(function() save(p); left -= 1 end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 25 do task.wait(0.1) end
end)
