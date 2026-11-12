-- ServerScriptService.RAH_Plots: every player gets their own hotel plot, and friends can co-op.
-- Plots sit side by side along X, PLOT_W apart (one long street). The Edit-time workspace.Hotel is the template:
-- it moves to ServerStorage and a copy is made for each player who joins (workspace.Plots.Hotel<k>), with
-- attributes Origin, Plot, Owner, HotelName. RAH_HotelSim runs each one.
-- Player attributes: RAH_Home = your own hotel's name (nil if every plot was taken), RAH_Plot = the hotel you work in
-- (your own, or a friend's while in co-op). Members of a hotel (RAH_Plot = its name) can build, clean, collect and let
-- guests in there.
-- Remotes.Coop (RemoteEvent): ("invite", userId) / ("respond", hostUserId, accept) / ("leave") / ("kick", userId).
-- Notify to clients: "coopInvite" {from, name, hotel}, "coopMoved" {hotel}.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Build = require(RAH:WaitForChild("Build"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local Sim = require(game.ServerStorage:WaitForChild("RAH_HotelSim"))
local Builder = require(game.ServerStorage:WaitForChild("RAH_HotelBuilder"))

local PLOT_COUNT = 6
local MAX_MEMBERS = 4 -- owner + 3 partners
local INVITE_TIME = 60
local PLOTS = workspace:WaitForChild("Plots")
-- middle plots first, so a small server stays close together
local ORDER = { 3, 4, 2, 5, 1, 6 }
-- plot 3 sits at X=0 (where the Edit-time street and terrain live); the rest clone out from it
local function originOf(k) return Vector3.new((k - math.floor((PLOT_COUNT + 1) / 2)) * Build.PLOT_W, 0, 0) end

---------------------------------------------------------------- the world: template, streets, ground

local template = workspace:WaitForChild("Hotel")
for _, a in ipairs({ "Owner", "HotelName", "LayoutOwner", "HotelReady", "BuildReady", "Pending", "NextRoom", "NextRoomPrice" }) do
	template:SetAttribute(a, nil)
end
template.Name = "RAH_HotelTemplate"
template.Parent = game.ServerStorage

-- the street and gardens (static), one copy per plot; the Edit copy is the middle one
local streets = Instance.new("Folder")
streets.Name = "Streets"
streets.Parent = workspace
local outside = workspace:WaitForChild("Outside")
for k = 1, PLOT_COUNT do
	local o = originOf(k)
	local s = (o.X == 0) and outside or outside:Clone()
	s.Name = "Street" .. k
	if o.X ~= 0 then s:PivotTo(outside:GetPivot() + o) end
	s.Parent = streets
end

-- the ground: copy the Edit terrain round the middle plot onto every other plot (and keep it for resets)
local terrain = workspace.Terrain
local REGION = Region3int16.new(Vector3int16.new(-110 // 4, -64 // 4, -240 // 4), Vector3int16.new(110 // 4 - 1, 32 // 4 - 1, 240 // 4 - 1))
local ground = terrain:CopyRegion(REGION)
local function pasteGround(k)
	local o = originOf(k)
	terrain:PasteRegion(ground, Vector3int16.new((o.X - 110) // 4, -64 // 4, -240 // 4), true)
end
for k = 1, PLOT_COUNT do
	if originOf(k).X ~= 0 then pasteGround(k) end
end

---------------------------------------------------------------- collision groups (players walk through guests)

pcall(function() PhysicsService:RegisterCollisionGroup("Guests") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
local function setGroup(model, group)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end)
end

---------------------------------------------------------------- plots

local plots = {} -- k -> { hotel, sim, owner }

local function hotelByName(name)
	return name and PLOTS:FindFirstChild(name) or nil
end

local function membersOf(hotel)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("RAH_Plot") == hotel.Name then table.insert(list, p) end
	end
	return list
end

local function frontOf(hotel)
	local o = hotel:GetAttribute("Origin")
	return CFrame.lookAt(o + Vector3.new(0, 4, 50), o + Vector3.new(0, 4, 0))
end

local function sendTo(player, cf)
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if root then
		ch:PivotTo(cf * CFrame.new(math.random(-4, 4), 0, 0))
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function claim(player)
	for _, k in ipairs(ORDER) do
		if not plots[k] then
			local o = originOf(k)
			local hotel = template:Clone()
			hotel.Name = "Hotel" .. k
			hotel:SetAttribute("Origin", o)
			hotel:SetAttribute("Plot", k)
			hotel:SetAttribute("Owner", player.UserId)
			hotel:SetAttribute("HotelName", player.DisplayName .. "'s Hotel")
			hotel:PivotTo(template:GetPivot() + o)
			for _, m in ipairs(hotel.Placed:GetChildren()) do
				if not m:GetAttribute("Uid") then m:SetAttribute("Uid", string.sub(HttpService:GenerateGUID(false), 1, 8)) end
			end
			hotel.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
			hotel.Parent = PLOTS
			pcall(function() hotel:AddPersistentPlayer(player) end)
			local slot = Builder.nextSlot(hotel)
			hotel:SetAttribute("NextRoom", slot and slot.id or nil)
			hotel:SetAttribute("NextRoomPrice", slot and slot.price or nil)
			local plot = { k = k, hotel = hotel, owner = player }
			plots[k] = plot
			plot.sim = Sim.start(hotel)
			hotel:SetAttribute("BuildReady", true)
			return hotel
		end
	end
end

local function release(k)
	local plot = plots[k]
	if not plot then return end
	plots[k] = nil
	pcall(plot.sim.stop)
	plot.hotel:Destroy()
	pasteGround(k) -- undoes the ground dug out for wings
end

-- the hotel with the fewest workers (for a player who couldn't get a plot)
local function quietestHotel(except)
	local best, n
	for _, plot in pairs(plots) do
		if plot.hotel ~= except then
			local m = #membersOf(plot.hotel)
			if m < MAX_MEMBERS and (not n or m < n) then best, n = plot.hotel, m end
		end
	end
	return best
end

-- move a player to work in a hotel (their own, or a friend's)
local function moveTo(player, hotel, quiet)
	local old = hotelByName(player:GetAttribute("RAH_Plot"))
	if old and old ~= hotel and old.Name ~= player:GetAttribute("RAH_Home") then
		pcall(function() old:RemovePersistentPlayer(player) end)
	end
	hotel:AddPersistentPlayer(player)
	player:SetAttribute("RAH_Building", nil)
	player:SetAttribute("RAH_Plot", hotel.Name)
	sendTo(player, frontOf(hotel))
	if not quiet then Notify:FireClient(player, "coopMoved", { hotel = hotel.Name }) end
end

local function goHome(player, why)
	local home = hotelByName(player:GetAttribute("RAH_Home"))
	local dest = home or quietestHotel(hotelByName(player:GetAttribute("RAH_Plot")))
	if not dest then return end
	moveTo(player, dest)
	if why then Notify:FireClient(player, "toast", { text = why, icon = "door" }) end
end

local function tellHotel(hotel, data)
	for _, p in ipairs(membersOf(hotel)) do Notify:FireClient(p, "toast", data) end
end

-- the player's hotel (or a friend's, when every plot is taken) once they pick a save file
local function startSession(player)
	local hotel = claim(player)
	if hotel then
		player:SetAttribute("RAH_Home", hotel.Name)
		player:SetAttribute("RAH_Plot", hotel.Name)
	else
		-- every plot is taken: help out in someone's hotel instead
		local h = quietestHotel()
		if h then
			h:AddPersistentPlayer(player)
			player:SetAttribute("RAH_Plot", h.Name)
			task.delay(6, function()
				if player.Parent then
					Notify:FireClient(player, "toast", { text = "Every plot is taken, so you're helping at " .. (h:GetAttribute("HotelName") or "a hotel"), icon = "staff" })
				end
			end)
		end
	end
end

local function onPlayer(player)
	player:SetAttribute("Cash", player:GetAttribute("Cash") or C.START_CASH)
	-- the plot is claimed when the player picks a save file in the main menu
	local function onCharacter(ch)
		setGroup(ch, "Players")
		local h = hotelByName(player:GetAttribute("RAH_Plot"))
		if h then
			ch:WaitForChild("HumanoidRootPart", 10)
			task.wait()
			sendTo(player, frontOf(h))
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

Players.PlayerRemoving:Connect(function(player)
	local home = player:GetAttribute("RAH_Home")
	for k, plot in pairs(plots) do
		if plot.hotel.Name == home then
			-- partners working here go back to their own hotels
			for _, p in ipairs(membersOf(plot.hotel)) do
				if p ~= player then
					task.spawn(goHome, p, player.DisplayName .. " left, so you're back at your hotel")
				end
			end
			-- RAH_Save snapshots the hotel straight away; free the plot a moment later
			task.delay(3, release, k)
		end
	end
end)

---------------------------------------------------------------- co-op

local remote = RAH.Remotes:FindFirstChild("Coop") or Instance.new("RemoteEvent")
remote.Name = "Coop"
remote.Parent = RAH.Remotes

---------------------------------------------------------------- main menu (save files)

local menuRemote = RAH.Remotes:FindFirstChild("Menu") or Instance.new("RemoteEvent")
menuRemote.Name = "Menu"
menuRemote.Parent = RAH.Remotes

-- the main menu fires ("play", slot) when the player picks a save file
menuRemote.OnServerEvent:Connect(function(player, action, slot)
	if action ~= "play" then return end
	if player:GetAttribute("RAH_Slot") then return end -- already playing a save
	if type(slot) ~= "number" then return end
	player:SetAttribute("RAH_Slot", math.clamp(math.floor(slot), 1, C.SAVE_SLOTS))
	startSession(player)
end)

local invites = {} -- [target] = { [host] = time }
local lastCall = {}

remote.OnServerEvent:Connect(function(player, action, a, b)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.3 then return end
	lastCall[player] = now

	if action == "invite" then
		local target = typeof(a) == "number" and Players:GetPlayerByUserId(a)
		local home = hotelByName(player:GetAttribute("RAH_Home"))
		if not target or target == player then return end
		if not home then
			Notify:FireClient(player, "toast", { text = "You need your own hotel to invite friends", icon = "close", bad = true })
			return
		end
		if target:GetAttribute("RAH_Plot") == home.Name then return end
		if #membersOf(home) >= MAX_MEMBERS then
			Notify:FireClient(player, "toast", { text = "Your hotel is full (" .. MAX_MEMBERS .. " players max)", icon = "staff", bad = true })
			return
		end
		invites[target] = invites[target] or {}
		invites[target][player] = now
		Notify:FireClient(target, "coopInvite", { from = player.UserId, name = player.DisplayName, hotel = home:GetAttribute("HotelName") })
		Notify:FireClient(player, "toast", { text = "Invite sent to " .. target.DisplayName, icon = "staff" })

	elseif action == "respond" then
		local host = typeof(a) == "number" and Players:GetPlayerByUserId(a)
		local t = host and invites[player] and invites[player][host]
		if invites[player] and host then invites[player][host] = nil end
		if not t or now - t > INVITE_TIME then
			if b then Notify:FireClient(player, "toast", { text = "That invite ran out", icon = "close", bad = true }) end
			return
		end
		if not b then
			Notify:FireClient(host, "toast", { text = player.DisplayName .. " said no thanks", icon = "staff" })
			return
		end
		local hotel = hotelByName(host:GetAttribute("RAH_Home"))
		if not hotel then return end
		if #membersOf(hotel) >= MAX_MEMBERS then
			Notify:FireClient(player, "toast", { text = "That hotel is full now", icon = "staff", bad = true })
			return
		end
		moveTo(player, hotel)
		tellHotel(hotel, { text = player.DisplayName .. " joined the hotel!", icon = "staff" })

	elseif action == "leave" then
		local home = player:GetAttribute("RAH_Home")
		if not home then
			Notify:FireClient(player, "toast", { text = "Every plot is taken, so you can't go back yet", icon = "close", bad = true })
			return
		end
		if player:GetAttribute("RAH_Plot") == home then return end
		local was = hotelByName(player:GetAttribute("RAH_Plot"))
		goHome(player, "Back at your hotel")
		if was then tellHotel(was, { text = player.DisplayName .. " went back to their hotel", icon = "door" }) end

	elseif action == "kick" then
		local target = typeof(a) == "number" and Players:GetPlayerByUserId(a)
		local home = player:GetAttribute("RAH_Home")
		if not target or not home or target == player then return end
		if target:GetAttribute("RAH_Plot") ~= home then return end
		goHome(target, player.DisplayName .. " sent you back to your hotel")
		Notify:FireClient(player, "toast", { text = target.DisplayName .. " went back to their hotel", icon = "door" })

	elseif action == "rename" then
		-- Manage tab: rename your own hotel (the sign follows the HotelName attribute)
		local home = hotelByName(player:GetAttribute("RAH_Home"))
		if not home or player:GetAttribute("RAH_Plot") ~= home.Name then return end
		local name = typeof(a) == "string" and (a:gsub("%s+", " "):match("^%s*(.-)%s*$")) or ""
		if name == "" then return end
		name = name:sub(1, 24)
		home:SetAttribute("HotelName", name)
		Notify:FireClient(player, "toast", { text = "Hotel renamed to " .. name .. "!", icon = "star" })

	elseif action == "reset" then
		-- Settings: wipe the save and start the hotel over
		local home = hotelByName(player:GetAttribute("RAH_Home"))
		if not home then return end
		for k, plot in pairs(plots) do
			if plot.hotel == home then
				for _, p in ipairs(membersOf(home)) do
					if p ~= player then task.spawn(goHome, p, player.DisplayName .. " reset their hotel") end
				end
				release(k)
				local fresh = claim(player)
				if fresh then
					player:SetAttribute("RAH_Home", fresh.Name)
					moveTo(player, fresh, true)
					local signals = game.ServerStorage:FindFirstChild("RAH_Signals")
					local reset = signals and signals:FindFirstChild("ResetSave")
					if reset then reset:Fire(player) end
					Notify:FireClient(player, "toast", { text = "Progress reset. A fresh start!", icon = "star" })
				end
				break
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	invites[p] = nil
	lastCall[p] = nil
	for _, list in pairs(invites) do list[p] = nil end
end)

---------------------------------------------------------------- Studio-only test hook (one real player can't co-op alone)
-- ServerStorage.RAH_PlotsTest:Invoke("fake", "Sam") claims a plot for a pretend owner; ("move", player, hotelName),
-- ("home", player), ("release", k). Not made in live servers.
if game:GetService("RunService"):IsStudio() then
	local f = game.ServerStorage:FindFirstChild("RAH_PlotsTest") or Instance.new("BindableFunction")
	f.Name = "RAH_PlotsTest"
	f.OnInvoke = function(action, a, b)
		if action == "fake" then
			local h = claim({ UserId = -math.random(1, 9999), DisplayName = a or "Sam" })
			return h and h.Name
		elseif action == "move" then
			moveTo(a, hotelByName(b))
			return a:GetAttribute("RAH_Plot")
		elseif action == "home" then
			goHome(a, "Back at your hotel")
			return a:GetAttribute("RAH_Plot")
		elseif action == "release" then
			release(a)
			return true
		end
	end
	f.Parent = game.ServerStorage
end
