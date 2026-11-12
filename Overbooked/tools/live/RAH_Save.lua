-- ServerScriptService.RAH_Save: keeps each player's money and the owner's hotel between visits.
-- DataStore "RAH_Save_v1", key "u_<UserId>":
--   { v = 1, cash, earned, cleaned, spent, rooms = { 104, 105 }, items = { {i = itemId, x, z, r = quarter turns, c = core, rm = room} },
--     staff = { janitor = 2, doorman = 1 }, tiers = { ["101"] = 2 } }
-- Every player's own hotel (RAH_Plots: player attribute RAH_Home) is loaded from and saved to their save.
-- Furniture x is stored relative to the plot's Origin, so a hotel loads onto whichever plot you get.
-- Work done in a co-op friend's hotel is saved in the friend's save. Everyone's cash is their own.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Build = require(RAH:WaitForChild("Build"))
local Catalog = require(RAH:WaitForChild("Catalog"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local ITEMS = RAH:WaitForChild("Items")
local PLOTS = workspace:WaitForChild("Plots")
local SIGNALS = game.ServerStorage:WaitForChild("RAH_Signals")
local ItemsChanged = SIGNALS:WaitForChild("ItemsChanged")
local RoomAdded = SIGNALS:WaitForChild("RoomAdded")
local Builder = require(game.ServerStorage:WaitForChild("RAH_HotelBuilder"))

local VERSION = 1
local store = DataStoreService:GetDataStore("RAH_Save_v1")
local STATS = { "Cash", "Earned", "Cleaned", "Spent", "Tut" }

-- a player's own hotel, once RAH_Plots and its sim have set it up (nil if they have none)
local function homeOf(player, wait)
	local t0 = os.clock()
	repeat
		local name = player:GetAttribute("RAH_Home")
		local h = name and PLOTS:FindFirstChild(name)
		if h and h:GetAttribute("HotelReady") and h:GetAttribute("BuildReady") then return h end
		if not wait then return nil end
		task.wait(0.1)
	until os.clock() - t0 > 20 or not player.Parent
	return nil
end

local loaded = {} -- player -> true once their save is in (we never save over data we haven't read)
local hotelDirty = false
local changes = 0 -- bumped on every hotel change, so a save only clears hotelDirty if nothing changed while it ran

local function key(player)
	return "u_" .. player.UserId .. "_s" .. (player:GetAttribute("RAH_Slot") or 1)
end

local function retry(fn)
	for i = 1, 3 do
		local ok, res = pcall(fn)
		if ok then return true, res end
		warn("RAH save: " .. tostring(res))
		task.wait(i * 1.5)
	end
	return false
end

---------------------------------------------------------------- hotel <-> table

local function snapshot(HOTEL)
	local PLACED = HOTEL.Placed
	local ox = (HOTEL:GetAttribute("Origin") or Vector3.zero).X
	local rooms = {}
	for _, slot in ipairs(C.ROOM_SLOTS) do
		if HOTEL.Rooms:FindFirstChild("Room" .. slot.id) then table.insert(rooms, slot.id) end
	end
	local items = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		local id = m:GetAttribute("Item")
		if id then
			local cf = m:GetPivot()
			local _, yaw = cf:ToEulerAnglesYXZ()
			table.insert(items, {
				i = id,
				x = math.floor((cf.Position.X - ox) * 10 + 0.5) / 10,
				z = math.floor(cf.Position.Z * 10 + 0.5) / 10,
				r = math.floor(yaw / (math.pi / 2) + 0.5) % 4,
				c = m:GetAttribute("Core"),
				rm = m:GetAttribute("Room"),
			})
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
	return rooms, items, staff, tiers, desk
end

local function cfOf(e, ox)
	return CFrame.new(e.x + ox, Build.FY, e.z) * CFrame.Angles(0, math.rad(90 * (e.r or 0)), 0)
end

local function restoreHotel(data, HOTEL)
	local PLACED = HOTEL.Placed
	if type(data.name) == "string" and data.name ~= "" then
		HOTEL:SetAttribute("HotelName", data.name:sub(1, 24))
	end
	local ox = (HOTEL:GetAttribute("Origin") or Vector3.zero).X
	-- 1. rooms, in slot order (each needs the one before it)
	local want = {}
	for _, id in ipairs(data.rooms or {}) do want[id] = true end
	local built = 0
	for _, slot in ipairs(C.ROOM_SLOTS) do
		if not want[slot.id] then break end
		if not HOTEL.Rooms:FindFirstChild("Room" .. slot.id) then
			local room = Builder.buildWing(HOTEL, slot)
			RoomAdded:Fire(room)
			built += 1
		end
	end
	-- 2. furniture: core items move to their saved spots; everything else is replaced by the save
	if data.items then
		for _, m in ipairs(PLACED:GetChildren()) do
			if not m:GetAttribute("Core") then m:Destroy() end
		end
		for _, e in ipairs(data.items) do
			if type(e) == "table" and type(e.x) == "number" and type(e.z) == "number" and ITEMS:FindFirstChild(tostring(e.i)) then
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
							local m = ITEMS[e.i]:Clone()
							m:PivotTo(cf)
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
						local m = ITEMS[e.i]:Clone()
						m:PivotTo(cf)
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
	-- 3. room upgrades (RAH_Hotel redresses a room when its Tier changes)
	if type(data.tiers) == "table" then
		for id, t in pairs(data.tiers) do
			local m = HOTEL.Rooms:FindFirstChild("Room" .. tostring(id))
			if m and type(t) == "number" then m:SetAttribute("Tier", math.clamp(math.floor(t), 1, #C.ROOM_TIERS)) end
		end
	end
	-- 4. staff (RAH_Hotel hires them when the attributes change)
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

local function save(player)
	if not loaded[player] then return end
	local home = homeOf(player)
	local ownsLayout = home ~= nil
	local rooms, items, staff, tiers, desk
	local seen = changes
	if ownsLayout then rooms, items, staff, tiers, desk = snapshot(home) end
	local ok = retry(function()
		store:UpdateAsync(key(player), function(old)
			local d = type(old) == "table" and old or {}
			d.v = VERSION
			for _, s in ipairs(STATS) do d[string.lower(s)] = player:GetAttribute(s) or 0 end
			if ownsLayout then
				d.rooms = rooms
				d.items = items
				d.staff = staff
				d.tiers = tiers
				d.desk = desk
				d.name = home:GetAttribute("HotelName")
			end
			d.saved = os.time()
			return d
		end)
	end)
	if ok and ownsLayout and changes == seen then hotelDirty = false end
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
	if home and data and (data.rooms or data.items or data.staff or data.tiers or data.desk) then
		local ok2, err = pcall(restoreHotel, data, home)
		if not ok2 then warn("RAH restore: " .. tostring(err)) end
		hello(player, { text = "Welcome back! Your hotel is just how you left it." .. away, icon = "star" })
	elseif data then
		hello(player, { text = "Welcome back!" .. away, icon = "star" })
	end
	loaded[player] = true
	player:SetAttribute("RAH_Loaded", true)
end

-- the save loads once the player picks a save file in the main menu
local function onLoad(player)
	local t0 = os.clock()
	while player.Parent and not player:GetAttribute("RAH_Slot") and os.clock() - t0 < 600 do task.wait(0.25) end
	if player.Parent and player:GetAttribute("RAH_Slot") then load(player) end
end
Players.PlayerAdded:Connect(onLoad)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onLoad, p) end

-- main menu: summaries of the player's save files (nil = empty slot)
local menuRemote = RAH.Remotes:FindFirstChild("Menu") or Instance.new("RemoteEvent")
menuRemote.Name = "Menu"
menuRemote.Parent = RAH.Remotes
menuRemote.OnServerEvent:Connect(function(player, action)
	if action ~= "slots" or player:GetAttribute("RAH_Slot") then return end
	task.spawn(function()
		local out = {}
		for s = 1, C.SAVE_SLOTS do
			local ok, data = retry(function() return store:GetAsync("u_" .. player.UserId .. "_s" .. s) end)
			local d = ok and type(data) == "table" and data or nil
			out[s] = d and {
				name = type(d.name) == "string" and d.name ~= "" and d.name or "New Hotel",
				cash = type(d.cash) == "number" and d.cash or 0,
				rooms = type(d.rooms) == "table" and #d.rooms or 0,
			} or nil
		end
		if player.Parent then menuRemote:FireClient(player, "slots", out) end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	save(player)
	loaded[player] = nil
end)

ItemsChanged.Event:Connect(function() hotelDirty = true; changes += 1 end)

-- Settings "Reset progress": wipe the save and zero the stats (RAH_Plots rebuilds the hotel)
local ResetSave = SIGNALS:FindFirstChild("ResetSave") or Instance.new("BindableEvent")
ResetSave.Name = "ResetSave"
ResetSave.Parent = SIGNALS
ResetSave.Event:Connect(function(player)
	loaded[player] = true
	task.spawn(function() retry(function() store:RemoveAsync(key(player)) end) end)
	player:SetAttribute("Cash", C.START_CASH)
	for _, s in ipairs(STATS) do
		if s ~= "Cash" then player:SetAttribute(s, 0) end
	end
end)

-- autosave: every 60 s, or 8 s after the hotel changes
task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(2)
		local due = os.clock() - last > 60
		if hotelDirty and os.clock() - last > 8 then due = true end
		if due then
			last = os.clock()
			for _, p in ipairs(Players:GetPlayers()) do task.spawn(save, p) end
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
