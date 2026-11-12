-- ServerScriptService.ChatCommands: chat commands, handled on the server via TextChatCommands.
-- /cash [amount]   (admin) add cash        /research            (admin) unlock all research
-- /mmoney           (admin) infinite cash (toggle) — the HUD shows "Infinite"
-- /preset           (admin) max out your hotel: research, level, grade, plots, staff, decor
-- /goto <player>    teleport to a player    /bring <player>      (admin) teleport a player to you
-- Admins: the game creator, anyone in Studio, or any player with the Admin attribute.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")

local Research = require(RS.Shared.Research)
local Builder = require(game.ServerStorage:WaitForChild("HotelBuilder"))
local Build = require(RS.Shared.Build)
local C = require(RS.Shared.Config)
local Levels = require(RS.Shared.Levels)
local SIGNALS = game.ServerStorage:FindFirstChild("Signals")
local RoomAdded = SIGNALS and SIGNALS:FindFirstChild("RoomAdded")
local ItemsChanged = SIGNALS and SIGNALS:FindFirstChild("ItemsChanged")
local Notify = RS.Shared.Remotes.Notify

local function isAdmin(player)
	return player:GetAttribute("Admin") == true
		or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
		or RunService:IsStudio()
end

local function tell(player, text, bad)
	Notify:FireClient(player, "toast", { text = text, icon = bad and "error" or "cash", bad = bad or nil })
end

-- find a player by (part of) their name, case-insensitive; nil if nobody or several match
local function findPlayer(name)
	name = name:lower()
	local found, partial
	for _, p in ipairs(Players:GetPlayers()) do
		local n = p.Name:lower()
		if n == name then return p end
		if n:sub(1, #name) == name then
			if partial then return nil, "Several players match '" .. name .. "'" end
			partial = p
		end
	end
	if not partial then return nil, "No player called '" .. name .. "'" end
	return partial
end

local function rootOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function hotelOf(player)
	local plots = workspace:FindFirstChild("Plots")
	local plot = player:GetAttribute("Plot")
	return plot and plots and plots:FindFirstChild(plot) or nil
end

-- /preset: the works. Every research node, the top level and grade, a wing on every plot,
-- suite-tier rooms, a furnished staff room, a kitchen with dining, desks for the
-- receptionists, decor in every room and the lobby, and the full staff team hired.
local function applyPreset(player)
	local hotel = hotelOf(player)
	if not hotel then return false, "Join your hotel first" end
	local placed = hotel:FindFirstChild("Placed")
	local rooms = hotel:FindFirstChild("Rooms")
	local zoneFolder = hotel:FindFirstChild("BuildZones")
	if not (placed and rooms and zoneFolder) then return false, "Your hotel isn't ready yet" end

	-- every research node, done
	local state = Research.state(hotel)
	for _, node in ipairs(Research.NODES) do state.done[node.id] = true end
	hotel:SetAttribute("Research", HttpService:JSONEncode(state))

	-- the top level
	hotel:SetAttribute("Level", Levels.MAX)
	hotel:SetAttribute("XP", 0)
	hotel:SetAttribute("XPNeed", Levels.need(Levels.MAX))

	-- five stars: the Palace Hotel shell
	hotel:SetAttribute("Grade", 5)
	pcall(Builder.roof, hotel)

	-- a wing room on every plot, every room a suite
	for _, slot in ipairs(C.ROOM_SLOTS) do
		if not rooms:FindFirstChild("Room" .. slot.id) then
			local ok, room = pcall(Builder.buildWing, hotel, slot)
			if ok and room and RoomAdded then RoomAdded:Fire(room) end
		end
	end
	for _, room in ipairs(rooms:GetChildren()) do
		if room:IsA("Model") then room:SetAttribute("Tier", #C.ROOM_TIERS) end
	end

	-- the zones: the lobby, and one per room
	local lobby, roomZones = nil, {}
	for _, z in ipairs(zoneFolder:GetChildren()) do
		if z:IsA("BasePart") and z.Name ~= "NoBuild" then
			if z.Name == "Lobby" then
				lobby = lobby or z
			elseif rooms:FindFirstChild(z.Name) then
				table.insert(roomZones, z)
			end
		end
	end

	-- place an item somewhere free in a zone (grid search, validated like a real build)
	local function put(zone, itemId)
		local hx = math.max(zone.Size.X / 2 - 2, 2)
		local hz = math.max(zone.Size.Z / 2 - 2, 2)
		for zo = -hz, hz, 4 do
			for xo = -hx, hx, 4 do
				local p = (zone.CFrame * CFrame.new(xo, 0, zo)).Position
				for _, yaw in ipairs({ 0, 180, 90, 270 }) do
					local cf = Build.pivot(p.X, 0, p.Z, yaw)
					local ok, _, z = Build.validate(itemId, cf)
					if ok then
						local m = Build.make(itemId, cf)
						m:SetAttribute("Item", itemId)
						m:SetAttribute("Zone", z and z.Name or zone.Name)
						m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8))
						m.Parent = placed
						return m
					end
				end
			end
		end
		return nil
	end

	-- round 14: a real staff room, walled off in a corner of the lobby (two of the hotel's own walls, two built
	-- ones with a door), then lockers, a table and both kinds of drinks inside. Skipped if one already works.
	local function placeAt(itemId, cf)
		local ok, _, z = Build.validate(itemId, cf)
		if not ok then return nil end
		local m = Build.make(itemId, cf)
		m:SetAttribute("Item", itemId)
		m:SetAttribute("Zone", z and z.Name or "Lobby")
		m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8))
		m.Parent = placed
		return m
	end
	local function staffRoom()
		if Build.staffRoom(hotel) then return true end
		if not lobby then return false end
		local S = 12
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ 1, -1 }) do
				local corner = lobby.CFrame * Vector3.new(sx * lobby.Size.X / 2, 0, sz * lobby.Size.Z / 2)
				local cx, cz = corner.X, corner.Z
				local made, fail = {}, false
				local pieces = {}
				for i, o in ipairs({ 2, 6, 10 }) do
					-- the side running along Z (a door in its middle) and the side running along X
					table.insert(pieces, { i == 2 and "Door" or "Wall", Build.pivot(cx - sx * S, 0, cz - sz * o, 90) })
					table.insert(pieces, { "Wall", Build.pivot(cx - sx * o, 0, cz - sz * S, 0) })
				end
				for _, pc in ipairs(pieces) do
					local m = placeAt(pc[1], pc[2])
					if not m then fail = true break end
					table.insert(made, m)
				end
				if not fail then
					-- furnish it: the first free spot for each, on a 2-stud grid inside
					for _, id in ipairs({ "StaffLocker", "StaffLocker", "StaffTable", "WaterCooler", "CoffeeBar" }) do
						local done = false
						for a = 2, S - 2, 2 do
							for b = 2, S - 2, 2 do
								for _, yaw in ipairs({ 0, 90, 180, 270 }) do
									if not done and placeAt(id, Build.pivot(cx - sx * a, 0, cz - sz * b, yaw)) then done = true end
								end
							end
						end
					end
					if Build.staffRoom(hotel) then return true end
				end
				-- didn't fit here: take it all down and try the next corner
				for _, m in ipairs(made) do m:Destroy() end
				for _, m in ipairs(placed:GetChildren()) do
					local id = m:GetAttribute("Item")
					local p = m:GetPivot().Position
					if (id == "StaffLocker" or id == "StaffTable" or id == "WaterCooler" or id == "CoffeeBar")
						and math.abs(p.X - (cx - sx * S / 2)) < S / 2 and math.abs(p.Z - (cz - sz * S / 2)) < S / 2 then
						m:Destroy()
					end
				end
			end
		end
		return false
	end
	local staffOk = staffRoom()

	-- the restaurant: a kitchen and tables to eat at
	local dineZone = roomZones[#roomZones]
	if dineZone then
		for _, id in ipairs({ "Stove", "PrepCounter", "KitchenFridge", "ServingCounter", "CafeTable", "CafeTable", "CafeTable" }) do
			put(dineZone, id)
		end
	end

	-- a desk for every receptionist
	if lobby then
		while #Build.desks(hotel) < 3 do
			if not put(lobby, "Desk") then break end
		end
	end

	-- decor: the lobby dressed up, and a little style in every room
	if lobby then
		for _, id in ipairs({ "Sofa", "CoffeeTable", "Armchair", "Plant", "IndoorPalm", "SnakePlant", "PottedTree", "FloorLamp", "FloorLamp", "Rug", "Bookshelf", "FloorVase" }) do
			put(lobby, id)
		end
	end
	for _, z in ipairs(roomZones) do
		for _, id in ipairs({ "Plant", "FloorLamp", "Rug", "CoffeeTable" }) do
			put(z, id)
		end
	end

	-- the full team: five-star hires with their own names, voices, pros and cons
	local okH, Hiring = pcall(require, RS.Shared.Hiring)
	if okH then
		local profs = {}
		local okJ, cur = pcall(HttpService.JSONDecode, HttpService, hotel:GetAttribute("StaffProfiles") or "{}")
		if okJ and type(cur) == "table" then profs = cur end
		local rng, taken = Random.new(), {}
		for _, def in ipairs(C.STAFF) do
			for i = 1, def.max do
				local key = def.id .. i
				if not profs[key] then
					local okM, p = pcall(Hiring.make, def, rng, taken)
					if okM and p then
						p.skill = 5
						local okW, w = pcall(Hiring.wageFor, def, 5, p.pro, p.con)
						if okW and w then p.wage = w end
						profs[key] = p
						taken[p.name or ""] = true
					end
				end
			end
		end
		hotel:SetAttribute("StaffProfiles", HttpService:JSONEncode(profs))
	end
	for _, def in ipairs(C.STAFF) do
		hotel:SetAttribute(def.attr, def.max)
	end
	-- and money to build with
	if not player:GetAttribute("InfiniteCash") then
		player:SetAttribute("Cash", math.max(player:GetAttribute("Cash") or 0, 250000))
	end
	if not staffOk then tell(player, "No lobby corner was free for the staff room", true) end

	-- the car park, and the "next room" sign off (there is no next room)
	pcall(Builder.parking, hotel)
	local slot = Builder.nextSlot(hotel)
	hotel:SetAttribute("NextRoom", slot and slot.id or nil)
	hotel:SetAttribute("NextRoomPrice", slot and slot.price or nil)

	if ItemsChanged then ItemsChanged:Fire() end
	return true
end

-- teleport one character to a spot just in front of another
local function teleportTo(mover, anchorRoot)
	local char = mover.Character
	if not char then return end
	char:PivotTo(anchorRoot.CFrame * CFrame.new(0, 0, -4))
end

local function runCommand(player, text)
	local cmd, arg = text:match("^/(%a+)%s*(.-)%s*$")
	if not cmd then return false end
	cmd = cmd:lower()

	if cmd == "cash" then
		if not isAdmin(player) then tell(player, "/cash is an admin command", true) return true end
		local amount = math.floor(tonumber(arg) or 1000)
		if amount <= 0 or amount > 100000000 then tell(player, "Pick an amount between 1 and 100,000,000", true) return true end
		player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
		player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + amount)
		tell(player, "Added $" .. amount)
		return true

	elseif cmd == "mmoney" then
		if not isAdmin(player) then tell(player, "/mmoney is an admin command", true) return true end
		if player:GetAttribute("InfiniteCash") then
			player:SetAttribute("InfiniteCash", nil)
			player:SetAttribute("Cash", player:GetAttribute("CashBackup") or 0)
			player:SetAttribute("CashBackup", nil)
			tell(player, "Infinite money off")
		else
			player:SetAttribute("CashBackup", player:GetAttribute("Cash") or 0)
			player:SetAttribute("InfiniteCash", true)
			player:SetAttribute("Cash", math.huge)
			tell(player, "Infinite money on")
		end
		return true

	elseif cmd == "research" then
		if not isAdmin(player) then tell(player, "/research is an admin command", true) return true end
		local hotel = hotelOf(player)
		if not hotel then tell(player, "Join your hotel first", true) return true end
		local state = Research.state(hotel)
		for _, node in ipairs(Research.NODES) do state.done[node.id] = true end
		hotel:SetAttribute("Research", HttpService:JSONEncode(state))
		tell(player, "All research unlocked")
		return true

	elseif cmd == "preset" then
		if not isAdmin(player) then tell(player, "/preset is an admin command", true) return true end
		local ok, err = applyPreset(player)
		if ok then tell(player, "Maxed-out hotel ready!") else tell(player, err, true) end
		return true

	elseif cmd == "goto" then
		if arg == "" then tell(player, "Usage: /goto <player>", true) return true end
		local target, err = findPlayer(arg)
		if not target then tell(player, err, true) return true end
		local myRoot, theirRoot = rootOf(player), rootOf(target)
		if not (myRoot and theirRoot) then tell(player, "Both players need a character", true) return true end
		teleportTo(player, theirRoot)
		tell(player, "Teleported to " .. target.Name)
		return true

	elseif cmd == "bring" then
		if not isAdmin(player) then tell(player, "/bring is an admin command", true) return true end
		if arg == "" then tell(player, "Usage: /bring <player>", true) return true end
		local target, err = findPlayer(arg)
		if not target then tell(player, err, true) return true end
		local myRoot, theirRoot = rootOf(player), rootOf(target)
		if not (myRoot and theirRoot) then tell(player, "Both players need a character", true) return true end
		teleportTo(target, myRoot)
		tell(player, "Brought " .. target.Name .. " to you")
		tell(target, player.Name .. " brought you to them")
		return true
	end

	return false
end

-- commands: created as TextChatCommands so the chat window knows them and never shows the raw text
local COMMANDS = { "cash", "mmoney", "research", "preset", "goto", "bring" }
for _, name in ipairs(COMMANDS) do
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "" .. name
	cmd.PrimaryAlias = "/" .. name
	cmd.Parent = TextChatService
	cmd.Triggered:Connect(function(originTextSource, unfilteredText)
		local player = Players:GetPlayerByUserId(originTextSource.UserId)
		if not player then return end
		local ok, err = pcall(runCommand, player, unfilteredText)
		if not ok then
			warn("ChatCommands:", err)
			tell(player, "That command failed", true)
		end
	end)
end
