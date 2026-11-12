-- ServerScriptService.BuildServer: buying, moving and selling furniture (build mode).
-- Remotes.Build (RemoteFunction): ("place", itemId, cframe, opts) / ("move", uid, cframe, opts) / ("paint", uid, opts) / ("sell", uid)
--   / ("room", id) / ("hire", staffId) -> ok, message. opts (shapes): { size = Vector3, color = Color3, mat = "Marble", ghost = bool }.
-- Round 9: any yaw in 15 degree steps, a height above the floor (stacking), research-gated items and finishes.
-- You build in the hotel you work in (player attribute Plot: your own, or a co-op friend's).
-- Every placement is re-checked with Shared.Build.validate, and must land in that hotel.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Build = require(Shared:WaitForChild("Build"))
local Research = require(Shared:WaitForChild("Research"))
local Levels = require(Shared:WaitForChild("Levels"))
local Grades = require(Shared:WaitForChild("Grades"))
local Notify = Shared.Remotes.Notify
local ITEMS = Shared:WaitForChild("Items")

local PLOTS = workspace:WaitForChild("Plots")
local ItemsChanged = game.ServerStorage:WaitForChild("Signals"):WaitForChild("ItemsChanged")

local Builder = require(game.ServerStorage:WaitForChild("HotelBuilder"))
local RoomAdded = game.ServerStorage.Signals:WaitForChild("RoomAdded")
local QuestSig = game.ServerStorage.Signals:WaitForChild("Quest", 10)

-- the next room for sale, for clients (attributes NextRoom / NextRoomPrice; nil when all are built)
local function publishNext(hotel)
	local slot = Builder.nextSlot(hotel)
	hotel:SetAttribute("NextRoom", slot and slot.id or nil)
	hotel:SetAttribute("NextRoomPrice", slot and slot.price or nil)
	if slot and not hotel:FindFirstChild("ForSale") then Builder.forSale(hotel) end
end

-- everyone in a hotel hears about its news
local function tell(hotel, kind, data)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == hotel.Name then Notify:FireClient(p, kind, data) end
	end
end

local remote = Shared.Remotes:FindFirstChild("Build") or Instance.new("RemoteFunction")
remote.Name = "Build"
remote.Parent = Shared.Remotes

local function newUid() return string.sub(HttpService:GenerateGUID(false), 1, 8) end

local function byUid(uid, PLACED)
	if typeof(uid) ~= "string" then return nil end
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Uid") == uid then return m end
	end
end

-- the client sends a full CFrame; keep only what build mode can make
-- (a 0.05-stud spot, a height above the floor, an upright turn in 15 degree steps)
local function clean(itemId, cf)
	if typeof(cf) ~= "CFrame" then return nil end
	local p = cf.Position
	if p.X ~= p.X or p.Z ~= p.Z or p.Y ~= p.Y then return nil end
	local function r(v) return math.floor(v * 20 + 0.5) / 20 end
	local yaw = (math.floor(Build.yawOf(cf) / Build.YAW_STEP + 0.5) * Build.YAW_STEP) % 360
	local y = math.clamp(r(p.Y - Build.FY), 0, Build.CEIL - Build.FY)
	if Build.floorOnly(itemId) then y = 0 end
	return Build.pivot(r(p.X), y, r(p.Z), yaw)
end

-- what a client may ask for when making a shape; finishes need their research
local function cleanOpts(itemId, o, HOTEL)
	local item = Catalog.ITEMS[itemId]
	if not item or not item.shape then return {} end
	o = type(o) == "table" and o or {}
	local mat = typeof(o.mat) == "string" and Catalog.MAT_BY_ID[o.mat] and o.mat or "SmoothPlastic"
	local need = Catalog.MAT_BY_ID[mat].research
	if need and not Research.has(HOTEL, need) then return nil, "Research " .. Research.BY_ID[need].name .. " first" end
	return {
		size = Build.shapeSize(itemId, o.size),
		color = typeof(o.color) == "Color3" and o.color or Catalog.SWATCHES[1],
		mat = mat,
		ghost = o.ghost == true,
	}
end

local lastCall = {}

-- round 14 (2026-11-09): hiring picks a person. Hotel attribute StaffCands holds three candidates per role (Shared.Hiring),
-- refreshed every Hiring.REFRESH seconds; StaffProfiles keeps who each hire is (HotelSim reads it).
local Hiring = require(Shared:WaitForChild("Hiring"))
local function readJSON(hotel, attr)
	local ok, t = pcall(function() return HttpService:JSONDecode(hotel:GetAttribute(attr) or "{}") end)
	return ok and type(t) == "table" and t or {}
end
local function candidates(hotel, force)
	local t = readJSON(hotel, "StaffCands")
	if force or not t.roles or os.time() - (t.at or 0) >= Hiring.REFRESH then
		local counts = {}
		for _, d in ipairs(C.STAFF) do counts[d.id] = hotel:GetAttribute(d.attr) or 0 end
		t = { at = os.time(), roles = Hiring.roll(C.STAFF, counts, os.time() + math.random(1, 1e6)) }
		hotel:SetAttribute("StaffCands", HttpService:JSONEncode(t))
	end
	return t
end
task.spawn(function()
	while true do
		for _, h in ipairs(PLOTS:GetChildren()) do
			if h:GetAttribute("BuildReady") then pcall(candidates, h) end
		end
		task.wait(10)
	end
end)

local function handle(player, action, a, b, c, inner)
	local now = os.clock()
	if not inner then -- inner = one step of a placeMany / sellMany (already rate limited as one call)
		if lastCall[player] and now - lastCall[player] < 0.12 then return false, "Slow down" end
		lastCall[player] = now
	end
	local HOTEL = PLOTS:FindFirstChild(player:GetAttribute("Plot") or "")
	if not HOTEL or not HOTEL:GetAttribute("BuildReady") then return false, "You don't have a hotel to build in" end
	local PLACED = HOTEL.Placed
	-- round 10e: building in someone else's hotel spends the owner's cash, not the helper's
	local payer = Players:GetPlayerByUserId(HOTEL:GetAttribute("Owner") or 0) or player
	local cash = payer:GetAttribute("Cash") or 0

	-- round 11: drag building. placeMany = one item at each spot in a list; sellMany = undo a dragged row.
	-- Each step runs as a normal place / sell; ItemsChanged fires once at the end.
	if action == "placeMany" or action == "sellMany" then
		local list = action == "placeMany" and b or a
		if typeof(list) ~= "table" or #list == 0 or #list > 40 then return false, "Too many at once" end
		local done, why = {}, nil
		for _, v in ipairs(list) do
			local ok, r
			if action == "placeMany" then ok, r = handle(player, "place", a, v, c, true) else ok, r = handle(player, "sell", v, nil, nil, true) end
			if ok then table.insert(done, action == "placeMany" and r or v) else why = why or r end
		end
		if #done == 0 then return false, why end
		ItemsChanged:Fire()
		return true, done, why
	end

	if action == "place" then
		local item = typeof(a) == "string" and Catalog.ITEMS[a]
		if not item or (not item.shape and not ITEMS:FindFirstChild(a)) then return false, "You can't buy that" end
		if item.research and not Research.has(HOTEL, item.research) then
			return false, "Research " .. Research.BY_ID[item.research].name .. " first"
		end
		if not Levels.itemOk(HOTEL, a) then return false, "Reach hotel level " .. Levels.itemLevel(a) .. " first" end
		local cf = clean(a, b)
		if not cf then return false, "Bad spot" end
		local opts, why0 = cleanOpts(a, c, HOTEL)
		if not opts then return false, why0 end
		local price = Catalog.price(a, opts.size)
		if cash < price then return false, "Not enough cash" end
		local ok, why, zone = Build.validate(a, cf, nil, opts)
		if not ok then return false, why end
		if not zone:IsDescendantOf(HOTEL) then return false, "Keep it inside your hotel" end
		local m = Build.make(a, cf, opts)
		m:SetAttribute("Item", a)
		m:SetAttribute("Zone", zone.Name)
		m:SetAttribute("Uid", newUid())
		-- a room's bed/shower/toilet (basic or an upgrade) belongs to the room it's placed in;
		-- the old one turns back into plain furniture you can move or sell
		local kind = item.core or item.coreKind
		if kind then
			if zone.Name == "Lobby" then
				m:Destroy()
				return false, "That belongs in a guest room"
			end
			for _, o in ipairs(PLACED:GetChildren()) do
				if o:GetAttribute("Core") == kind and o:GetAttribute("Room") == zone.Name then
					o:SetAttribute("Core", nil)
				end
			end
			m:SetAttribute("Core", kind)
			m:SetAttribute("Room", zone.Name)
		end
		-- round 10e: undo (selling it within UNDO_SECS) gives the whole price back
		m:SetAttribute("PlacedAt", os.clock())
		m:SetAttribute("PlacedPrice", price)
		m.Parent = PLACED
		payer:SetAttribute("Cash", cash - price)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + price)
		if not inner then ItemsChanged:Fire() end
		Notify:FireClient(player, "built", { kind = "place", item = a, pos = cf.Position, amount = price })
		if QuestSig then
			QuestSig:Fire(HOTEL, "place", 1)
			if zone.Name == "Lobby" then QuestSig:Fire(HOTEL, "placeLobby", 1) end
		end
		return true, m:GetAttribute("Uid")

	elseif action == "move" then
		local m = byUid(a, PLACED)
		if not m then return false, "That's gone" end
		local id = m:GetAttribute("Item")
		local cf = clean(id, b)
		if not cf then return false, "Bad spot" end
		local item = Catalog.ITEMS[id]
		-- a shape may be resized as it moves: pay the difference, or get back the usual share of it
		local opts, diff = {}, 0
		if item and item.shape then
			local o = Build.optsOf(m)
			if type(c) == "table" and typeof(c.size) == "Vector3" then o.size = c.size end
			local why0
			opts, why0 = cleanOpts(id, o, HOTEL)
			if not opts then return false, why0 end
			local before, after = Catalog.price(id, m:GetAttribute("Size")), Catalog.price(id, opts.size)
			diff = after > before and (after - before) or -math.floor((before - after) * Catalog.SELL_BACK)
			if diff > cash then return false, "Not enough cash" end
		end
		local roomName = m:GetAttribute("Room")
		if roomName then
			local room = HOTEL.Rooms:FindFirstChild(roomName)
			if room and room:GetAttribute("State") == "Booked" then return false, "A guest is using this room" end
		end
		local ok, why, zone = Build.validate(id, cf, m, opts)
		if not ok then return false, why end
		if not zone:IsDescendantOf(HOTEL) then return false, "Keep it inside your hotel" end
		if item and item.shape then
			-- rebuild the shape at its new size, keeping its identity
			local newM = Build.make(id, cf, opts)
			for k, v in pairs(m:GetAttributes()) do
				if newM:GetAttribute(k) == nil and k ~= "Ghost" then newM:SetAttribute(k, v) end
			end
			m:Destroy()
			m = newM
			m.Parent = PLACED
			if diff ~= 0 then
				payer:SetAttribute("Cash", cash - diff)
				if diff > 0 then payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + diff) end
			end
		else
			m:PivotTo(cf)
		end
		m:SetAttribute("Zone", zone.Name)
		ItemsChanged:Fire()
		Notify:FireClient(player, "built", { kind = "move", item = id, pos = cf.Position })
		return true

	elseif action == "paint" then
		-- recolour a shape, change its finish or let guests walk through it (free)
		local m = byUid(a, PLACED)
		if not m then return false, "That's gone" end
		local id = m:GetAttribute("Item")
		local item = Catalog.ITEMS[id]
		if not item or not item.shape then return false, "Only shapes can be painted" end
		local o = Build.optsOf(m)
		if type(b) == "table" then
			if typeof(b.color) == "Color3" then o.color = b.color end
			if typeof(b.mat) == "string" then o.mat = b.mat end
			if type(b.ghost) == "boolean" then o.ghost = b.ghost end
		end
		local opts, why0 = cleanOpts(id, o, HOTEL)
		if not opts then return false, why0 end
		local cf = m:GetPivot()
		local ok, why, zone = Build.validate(id, cf, m, opts)
		if not ok then return false, why end
		local newM = Build.make(id, cf, opts)
		for k, v in pairs(m:GetAttributes()) do
			if newM:GetAttribute(k) == nil and k ~= "Ghost" then newM:SetAttribute(k, v) end
		end
		m:Destroy()
		newM:SetAttribute("Zone", zone.Name)
		newM.Parent = PLACED
		ItemsChanged:Fire()
		return true

	elseif action == "desk" then
		-- the reception desk moves inside its zone, taking its queue spots with it
		local cf = clean("Desk", a)
		if not cf then return false, "Bad spot" end
		local ok, why = Build.deskOk(HOTEL, cf)
		if not ok then return false, why end
		Build.moveDesk(HOTEL, cf)
		ItemsChanged:Fire()
		Notify:FireClient(player, "built", { kind = "move", item = "Desk", pos = cf.Position })
		return true

	elseif action == "sell" then
		local m = byUid(a, PLACED)
		if not m then return false, "That's gone" end
		local id = m:GetAttribute("Item")
		if m:GetAttribute("Core") then
			-- selling a room's bed/shower/toilet is fine if another one can take over
			local kind = m:GetAttribute("Core")
			local roomName = m:GetAttribute("Room")
			local heir
			for _, o in ipairs(PLACED:GetChildren()) do
				if o ~= m and o:GetAttribute("Room") == roomName then
					local oi = Catalog.ITEMS[o:GetAttribute("Item")]
					if oi and (oi.core == kind or oi.coreKind == kind) then heir = o end
				end
			end
			if not heir then
				local it = Catalog.ITEMS[kind]
				return false, "Every room needs its " .. string.lower(it and it.name or kind)
			end
			heir:SetAttribute("Core", kind)
		end
		local value = Catalog.sellValue(id, m:GetAttribute("Size"))
		if os.clock() - (m:GetAttribute("PlacedAt") or -1e9) < 60 then value = m:GetAttribute("PlacedPrice") or value end
		local pos = m:GetPivot().Position
		m:Destroy()
		payer:SetAttribute("Cash", cash + value)
		if not inner then ItemsChanged:Fire() end
		Notify:FireClient(player, "built", { kind = "sell", item = id, pos = pos, amount = value })
		return true, value

	elseif action == "room" then
		local slot = Builder.nextSlot(HOTEL)
		if not slot then return false, "You own all the land" end
		if a ~= slot.id then return false, "Buy the next plot first" end
		if Levels.of(HOTEL) < Levels.roomLevel(slot.id) then return false, "Reach hotel level " .. Levels.roomLevel(slot.id) .. " first" end
		if cash < slot.price then return false, "Not enough cash" end
		-- round 10d: you buy land now; rooms are made on it with walls and a door
		Builder.buildLand(HOTEL, slot) -- charge only once it's built
		payer:SetAttribute("Cash", cash - slot.price)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + slot.price)
		for _, m in ipairs(PLACED:GetChildren()) do
			if not m:GetAttribute("Uid") then m:SetAttribute("Uid", newUid()) end
		end
		ItemsChanged:Fire()
		publishNext(HOTEL)
		local _, _, _, cx = Builder.wingGeom(slot)
		local o = HOTEL:GetAttribute("Origin") or Vector3.zero
		Notify:FireAllClients("roomBuilt", { id = slot.id, pos = o + Vector3.new(cx, Build.FY, -15), price = slot.price, hotel = HOTEL.Name })
		tell(HOTEL, "toast", { text = "New land! Wall off a room and give it a door", icon = "hammer" })
		Levels.award(HOTEL, Levels.XP.room, "New land", o + Vector3.new(cx, Build.FY + 6, -15))
		return true, slot.id

	elseif action == "grade" then
		-- round 11: buy the next hotel grade (owner only); the building grows to match
		if HOTEL:GetAttribute("Owner") ~= player.UserId then return false, "Only the owner can upgrade the hotel" end
		local list, ok, def = Grades.check(HOTEL, cash)
		if not def then return false, "Your hotel is already a Palace Hotel" end
		if not ok then
			for _, e in ipairs(list) do
				if not e.ok then return false, (e.money and "Not enough cash" or "Still needed: " .. e.text) end
			end
		end
		local g = Grades.of(HOTEL) + 1
		payer:SetAttribute("Cash", cash - def.price)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + def.price)
		HOTEL:SetAttribute("Grade", g)
		Builder.roof(HOTEL)
		ItemsChanged:Fire() -- so the save picks it up
		local o = HOTEL:GetAttribute("Origin") or Vector3.zero
		Notify:FireAllClients("gradeUp", { grade = g, name = def.name, hotel = HOTEL.Name, pos = o + Vector3.new(0, 24, 34) })
		tell(HOTEL, "toast", { text = "Your hotel is now a " .. def.name .. "!", icon = "star" })
		Levels.award(HOTEL, 120 * g, "New grade", o + Vector3.new(0, 20, 32))
		return true, g

	elseif action == "hire" then
		local def
		for _, d in ipairs(C.STAFF) do if d.id == a then def = d end end
		if not def then return false, "Nobody to hire" end
		local n = HOTEL:GetAttribute(def.attr) or 0
		if n >= def.max then return false, "You have every " .. string.lower(def.name) end
		-- round 14: staff need somewhere to keep their things before anyone is hired
		-- round 18: a real staff room (walled in, with lockers, a table and a drink) before anyone is hired
		local roomOk, missing, tip = Build.staffRoom(HOTEL)
		if not roomOk then return false, "Staff room needed. " .. tip .. ". Missing: " .. table.concat(missing, ", ") end
		if def.id == "receptionist" and n + 1 > #Build.desks(HOTEL) then
			return false, "Each receptionist needs a desk: buy one in build mode"
		end
		if not Levels.staffOk(HOTEL, def.id, n + 1) then
			return false, "Reach hotel level " .. Levels.staffLevel(def.id, n + 1) .. " first"
		end
		local cands = candidates(HOTEL)
		local list = cands.roles[def.id] or {}
		local ci = tonumber(b) or 1
		local cand = list[ci]
		if not cand then return false, "That person took another job" end
		local price = Hiring.priceFor(def, n + 1, cand.skill)
		if cash < price then return false, "Not enough cash" end
		payer:SetAttribute("Cash", cash - price)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + price)
		local profiles = readJSON(HOTEL, "StaffProfiles")
		profiles[def.id .. (n + 1)] = { name = cand.name, surname = cand.surname, voice = cand.voice, deep = cand.deep,
			skill = cand.skill, pro = cand.pro, con = cand.con, wage = cand.wage, seed = cand.seed }
		HOTEL:SetAttribute("StaffProfiles", HttpService:JSONEncode(profiles))
		-- they're off the list; someone new turns up in their place
		local rng = Random.new(os.time() + ci)
		local taken = {}
		for _, l in pairs(cands.roles) do for _, c in ipairs(l) do taken[c.name] = true end end
		local new = Hiring.make(def, rng, taken)
		new.price = Hiring.priceFor(def, n + 2, new.skill)
		list[ci] = new
		for _, c in ipairs(list) do c.price = Hiring.priceFor(def, n + 2, c.skill) end
		HOTEL:SetAttribute("StaffCands", HttpService:JSONEncode(cands))
		HOTEL:SetAttribute(def.attr, n + 1) -- Hotel spawns them
		ItemsChanged:Fire() -- so the save picks it up
		tell(HOTEL, "toast", { text = cand.name .. " joined as your " .. string.lower(def.name) .. "!", icon = def.icon })
		Notify:FireClient(player, "hired", { id = def.id, count = n + 1, amount = price })
		return true, n + 1

	elseif action == "cands" then
		return true, candidates(HOTEL)

	elseif action == "reroll" then
		if cash < Hiring.REROLL_PRICE then return false, "Not enough cash" end
		payer:SetAttribute("Cash", cash - Hiring.REROLL_PRICE)
		payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + Hiring.REROLL_PRICE)
		return true, candidates(HOTEL, true)
	end
	return false, "Unknown action"
end

remote.OnServerInvoke = function(player, action, a, b, c)
	local ok, r1, r2, r3 = pcall(handle, player, action, a, b, c)
	if not ok then
		warn("Shared build: " .. tostring(r1))
		return false, "Something went wrong"
	end
	return r1, r2, r3
end

Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)

