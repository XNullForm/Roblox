-- ServerScriptService.RAH_BuildServer: buying, moving and selling furniture (build mode).
-- Remotes.Build (RemoteFunction): ("place", itemId, cframe) / ("move", uid, cframe) / ("sell", uid) / ("room", id) / ("hire", staffId) -> ok, message
-- You build in the hotel you work in (player attribute RAH_Plot: your own, or a co-op friend's).
-- Every placement is re-checked with RAH.Build.validate, and must land in that hotel.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Catalog = require(RAH:WaitForChild("Catalog"))
local Build = require(RAH:WaitForChild("Build"))
local Notify = RAH.Remotes.Notify
local ITEMS = RAH:WaitForChild("Items")

local PLOTS = workspace:WaitForChild("Plots")
local ItemsChanged = game.ServerStorage:WaitForChild("RAH_Signals"):WaitForChild("ItemsChanged")

local Builder = require(game.ServerStorage:WaitForChild("RAH_HotelBuilder"))
local RoomAdded = game.ServerStorage.RAH_Signals:WaitForChild("RoomAdded")

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
		if p:GetAttribute("RAH_Plot") == hotel.Name then Notify:FireClient(p, kind, data) end
	end
end

local remote = RAH.Remotes:FindFirstChild("Build") or Instance.new("RemoteFunction")
remote.Name = "Build"
remote.Parent = RAH.Remotes

local function newUid() return string.sub(HttpService:GenerateGUID(false), 1, 8) end

local function byUid(uid, PLACED)
	if typeof(uid) ~= "string" then return nil end
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Uid") == uid then return m end
	end
end

-- the client sends a full CFrame; keep only what build mode can make (grid spot, floor height, quarter turn)
local function clean(itemId, cf)
	if typeof(cf) ~= "CFrame" then return nil end
	local _, yaw = cf:ToEulerAnglesYXZ()
	local turns = math.floor(yaw / (math.pi / 2) + 0.5) % 4
	return Build.snap(itemId, Vector3.new(cf.Position.X, Build.FY, cf.Position.Z), turns)
end

local lastCall = {}

local function handle(player, action, a, b)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.12 then return false, "Slow down" end
	lastCall[player] = now
	local HOTEL = PLOTS:FindFirstChild(player:GetAttribute("RAH_Plot") or "")
	if not HOTEL or not HOTEL:GetAttribute("BuildReady") then return false, "You don't have a hotel to build in" end
	local PLACED = HOTEL.Placed
	local cash = player:GetAttribute("Cash") or 0

	if action == "place" then
		local item = Catalog.ITEMS[a]
		if typeof(a) ~= "string" or not item or not ITEMS:FindFirstChild(a) then return false, "You can't buy that" end
		local cf = clean(a, b)
		if not cf then return false, "Bad spot" end
		if cash < item.price then return false, "Not enough cash" end
		local ok, why, zone = Build.validate(a, cf)
		if not ok then return false, why end
		if not zone:IsDescendantOf(HOTEL) then return false, "Keep it inside your hotel" end
		local m = ITEMS[a]:Clone()
		m:PivotTo(cf)
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
		m.Parent = PLACED
		player:SetAttribute("Cash", cash - item.price)
		player:SetAttribute("Spent", (player:GetAttribute("Spent") or 0) + item.price)
		ItemsChanged:Fire()
		Notify:FireClient(player, "built", { kind = "place", item = a, pos = cf.Position, amount = item.price })
		return true, m:GetAttribute("Uid")

	elseif action == "move" then
		local m = byUid(a, PLACED)
		if not m then return false, "That's gone" end
		local id = m:GetAttribute("Item")
		local cf = clean(id, b)
		if not cf then return false, "Bad spot" end
		local roomName = m:GetAttribute("Room")
		if roomName then
			local room = HOTEL.Rooms:FindFirstChild(roomName)
			if room and room:GetAttribute("State") == "Booked" then return false, "A guest is using this room" end
		end
		local ok, why, zone = Build.validate(id, cf, m)
		if not ok then return false, why end
		if not zone:IsDescendantOf(HOTEL) then return false, "Keep it inside your hotel" end
		m:PivotTo(cf)
		m:SetAttribute("Zone", zone.Name)
		ItemsChanged:Fire()
		Notify:FireClient(player, "built", { kind = "move", item = id, pos = cf.Position })
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
		local value = Catalog.sellValue(id)
		local pos = m:GetPivot().Position
		m:Destroy()
		player:SetAttribute("Cash", cash + value)
		ItemsChanged:Fire()
		Notify:FireClient(player, "built", { kind = "sell", item = id, pos = pos, amount = value })
		return true, value

	elseif action == "room" then
		local slot = Builder.nextSlot(HOTEL)
		if not slot then return false, "Every room is built" end
		if a ~= slot.id then return false, "Buy Room " .. slot.id .. " first" end
		if cash < slot.price then return false, "Not enough cash" end
		local room = Builder.buildWing(HOTEL, slot) -- charge only once it's built
		player:SetAttribute("Cash", cash - slot.price)
		player:SetAttribute("Spent", (player:GetAttribute("Spent") or 0) + slot.price)
		for _, m in ipairs(PLACED:GetChildren()) do
			if not m:GetAttribute("Uid") then m:SetAttribute("Uid", newUid()) end
		end
		RoomAdded:Fire(room)
		ItemsChanged:Fire()
		publishNext(HOTEL)
		local _, _, _, cx = Builder.wingGeom(slot)
		local o = HOTEL:GetAttribute("Origin") or Vector3.zero
		Notify:FireAllClients("roomBuilt", { id = slot.id, pos = o + Vector3.new(cx, Build.FY, -15), price = slot.price, hotel = HOTEL.Name })
		tell(HOTEL, "toast", { text = "Room " .. slot.id .. " is open!", icon = "roomReady" })
		return true, slot.id

	elseif action == "hire" then
		local def
		for _, d in ipairs(C.STAFF) do if d.id == a then def = d end end
		if not def then return false, "Nobody to hire" end
		local n = HOTEL:GetAttribute(def.attr) or 0
		if n >= def.max then return false, "You have every " .. string.lower(def.name) end
		local price = def.prices[n + 1]
		if cash < price then return false, "Not enough cash" end
		player:SetAttribute("Cash", cash - price)
		player:SetAttribute("Spent", (player:GetAttribute("Spent") or 0) + price)
		HOTEL:SetAttribute(def.attr, n + 1) -- RAH_Hotel spawns them
		ItemsChanged:Fire() -- so the save picks it up
		tell(HOTEL, "toast", { text = def.name .. " hired!", icon = def.icon })
		Notify:FireClient(player, "hired", { id = def.id, count = n + 1, amount = price })
		return true, n + 1
	end
	return false, "Unknown action"
end

remote.OnServerInvoke = function(player, action, a, b)
	local ok, r1, r2 = pcall(handle, player, action, a, b)
	if not ok then
		warn("RAH build: " .. tostring(r1))
		return false, "Something went wrong"
	end
	return r1, r2
end

Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)

