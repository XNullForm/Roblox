-- ServerScriptService.LevelCommands: testing commands anyone can use.
-- /level  -> the hotel goes up one level (no level-up popups)
-- /mlevel -> the hotel jumps to max level, unlocking everything (no level-up popups)
local Players = game:GetService("Players")
local Levels = require(game.ReplicatedStorage.Shared:WaitForChild("Levels"))

local function hotelOf(player)
	local plots = workspace:FindFirstChild("Plots")
	local id = player:GetAttribute("Plot")
	return id and plots and plots:FindFirstChild(id)
end

local function handle(player, msg)
	local cmd = msg and msg:match("^/(%a+)")
	if cmd ~= "level" and cmd ~= "mlevel" then return end
	local hotel = hotelOf(player)
	if not hotel then return end
	if cmd == "level" then
		local lv = hotel:GetAttribute("Level") or 1
		if lv >= Levels.MAX then return end
		local need = Levels.need(lv) - (hotel:GetAttribute("XP") or 0)
		Levels.award(hotel, need, "command", nil, true)
	else
		-- to max: keep topping up the XP bar until the level caps out
		for _ = 1, Levels.MAX do
			local lv = hotel:GetAttribute("Level") or 1
			if lv >= Levels.MAX then break end
			Levels.award(hotel, Levels.need(lv) - (hotel:GetAttribute("XP") or 0), "command", nil, true)
		end
	end
end

local function onPlayer(player)
	player.Chatted:Connect(function(msg) handle(player, msg) end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end