-- ServerScriptService.Tutorial (round 12 remake): the guided first day now runs on the client
-- (StarterPlayerScripts.TutorialClient). This script only decides who gets it and pays the reward.
-- A player whose saved `Tut` stat is below DONE gets Notify "tut2" { start = true } once their save has loaded
-- (Loaded). Remotes.TutSkip from the client: ("done") finishes it (REWARD cash, once ever), ("skip") stops
-- it for good, ("replay") plays it again from Settings (no second reward). `Tut` is saved by Save.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Notify = RS.Shared.Remotes:WaitForChild("Notify")
local TutSkip = RS.Shared.Remotes:WaitForChild("TutSkip")

local DONE = 5 -- the old four-step tutorial finished at 5, so anyone who did it isn't asked again
local REWARD = 500

local introDone = {} -- round 20: player -> true once their intro story ended
local offered = {} -- player -> true once this session's tutorial was sent

local function offer(player)
	if offered[player] or (player:GetAttribute("Tut") or 0) >= DONE then return end
	offered[player] = true
	-- round 14: a hotel already past level 2 knows the ropes (older saves never stored Tut): no first-day tour
	local plot = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
	if plot and (plot:GetAttribute("Level") or 1) >= 3 then
		player:SetAttribute("Tut", DONE)
		return
	end
	-- round 35: Aunt Marigold left the place in a state: the first job is cleaning it up
	pcall(function() require(game:GetService("ServerStorage"):WaitForChild("Mess")).spawn(plot) end)
	-- round 20: the story plays first; the client says when it is over (or 40 s pass)
	introDone[player] = nil
	Notify:FireClient(player, "cutscene", { kind = "intro" })
	task.spawn(function()
		local t0 = os.clock()
		while player.Parent and not introDone[player] and os.clock() - t0 < 40 do task.wait(0.5) end
		if player.Parent then Notify:FireClient(player, "tut2", { start = true }) end
	end)
end

local function watch(player)
	local function check()
		if player:GetAttribute("Loaded") and player:GetAttribute("Slot") then
			task.delay(1, function() if player.Parent then offer(player) end end)
		end
	end
	player:GetAttributeChangedSignal("Loaded"):Connect(check)
	player:GetAttributeChangedSignal("Slot"):Connect(function()
		-- after "Reset progress" the next Play is a brand-new hotel: offer it again
		if not player:GetAttribute("Slot") then offered[player] = nil end
		check()
	end)
	check()
end

local lastReplay = {}
TutSkip.OnServerEvent:Connect(function(player, action)
	if action == "introDone" then
		introDone[player] = true
	elseif action == "done" then
		if (player:GetAttribute("Tut") or 0) < DONE then
			player:SetAttribute("Tut", DONE)
			player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + REWARD)
			player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + REWARD)
			Notify:FireClient(player, "toast", { text = "Tutorial done! +$" .. REWARD, icon = "cash", kind = "good" })
		end
	elseif action == "replay" then
		if os.clock() - (lastReplay[player] or 0) < 3 then return end
		lastReplay[player] = os.clock()
		Notify:FireClient(player, "tut2", { start = true, replay = true })
	else
		-- "skip" (and the old HUD card's plain FireServer())
		if (player:GetAttribute("Tut") or 0) < DONE then player:SetAttribute("Tut", DONE) end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	offered[p] = nil
	lastReplay[p] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(watch, p) end
Players.PlayerAdded:Connect(watch)
