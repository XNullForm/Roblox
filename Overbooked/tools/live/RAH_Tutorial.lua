-- ServerScriptService.RAH_Tutorial: walks brand-new players through their first
-- day: place a room, welcome a guest, clean up, collect the cash. Progress is
-- saved as the player's `Tut` attribute (RAH_Save), so it only ever plays once.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Notify = RS.RAH.Remotes:WaitForChild("Notify")
local TutSkip = RS.RAH.Remotes:WaitForChild("TutSkip")
local RoomAdded = game.ServerStorage.RAH_Signals:WaitForChild("RoomAdded")

local STEPS = {
	{ icon = "hammer", text = "Open build mode (B) and place your first room" },
	{ icon = "guest", text = "Welcome your first guest at the front door" },
	{ icon = "clean", text = "Clean the room once the guest checks out" },
	{ icon = "cash", text = "Collect your earnings at the dropbox outside" },
}
local DONE = #STEPS + 1

local sessions = {} -- player -> { step, hotel, conns, cashMark }

local function send(player, step)
	if step >= DONE then
		Notify:FireClient(player, "tut", { done = true })
	else
		local s = STEPS[step]
		Notify:FireClient(player, "tut", { step = step, total = #STEPS, icon = s.icon, text = s.text })
	end
end

local function stop(player)
	local s = sessions[player]
	if not s then return end
	for _, c in ipairs(s.conns) do c:Disconnect() end
	sessions[player] = nil
end

local function advance(player)
	local s = sessions[player]
	if not s then return end
	s.step += 1
	if s.step == 4 then s.cashMark = player:GetAttribute("Cash") or 0 end
	send(player, s.step)
	if s.step >= DONE then
		player:SetAttribute("Tut", DONE)
		stop(player)
	end
end

local function watch(player, hotel)
	local s = sessions[player]
	-- step 1: the player's hotel gained a room
	table.insert(s.conns, RoomAdded.Event:Connect(function(room)
		local sess = sessions[player]
		if sess and sess.step == 1 and room and room:IsDescendantOf(hotel) then
			advance(player)
		end
	end))
	-- step 2: a guest moved into a room
	table.insert(s.conns, hotel:GetAttributeChangedSignal("RoomsBusy"):Connect(function()
		local sess = sessions[player]
		if sess and sess.step == 2 and (hotel:GetAttribute("RoomsBusy") or 0) > 0 then
			advance(player)
		end
	end))
	-- step 3: the player cleaned a room
	table.insert(s.conns, player:GetAttributeChangedSignal("Cleaned"):Connect(function()
		local sess = sessions[player]
		if sess and sess.step == 3 then advance(player) end
	end))
	-- step 4: the player collected cash at the dropbox
	table.insert(s.conns, player:GetAttributeChangedSignal("Cash"):Connect(function()
		local sess = sessions[player]
		if sess and sess.step == 4 and (player:GetAttribute("Cash") or 0) > sess.cashMark then
			advance(player)
		end
	end))
end

local function start(player)
	task.spawn(function()
		-- wait for the plot assignment (RAH_Plots) before judging anything
		while player.Parent and not player:GetAttribute("RAH_Plot") do
			player:GetAttributeChangedSignal("RAH_Plot"):Wait()
		end
		if not player.Parent then return end
		if (player:GetAttribute("Tut") or 0) >= DONE then return end -- already finished it
		local plots = workspace:FindFirstChild("Plots")
		local hotel = plots and plots:FindFirstChild(player:GetAttribute("RAH_Plot"))
		if not hotel then return end
		-- returning players whose hotel was restored from a save skip it entirely
		local rooms = (hotel:GetAttribute("RoomsReady") or 0)
			+ (hotel:GetAttribute("RoomsBusy") or 0)
			+ (hotel:GetAttribute("RoomsDirty") or 0)
		if rooms > 0 then
			player:SetAttribute("Tut", DONE)
			return
		end
		local s = { step = 1, hotel = hotel, conns = {}, cashMark = 0 }
		sessions[player] = s
		send(player, 1)
		watch(player, hotel)
	end)
end

TutSkip.OnServerEvent:Connect(function(player)
	if not sessions[player] then return end
	player:SetAttribute("Tut", DONE)
	stop(player)
	Notify:FireClient(player, "tut", { done = true, skipped = true })
end)

Players.PlayerRemoving:Connect(stop)
for _, p in ipairs(Players:GetPlayers()) do start(p) end
Players.PlayerAdded:Connect(start)
