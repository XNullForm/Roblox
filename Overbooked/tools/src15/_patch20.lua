--@@CUT_INTRO
---------------------------------------------------------------- the intro story (round 20)
-- Notify "cutscene" { kind = "intro" }: four shots that tell how you came to own the Seabreeze (the sea front, the
-- boulevard, the run-down hotel, its door), each with a title card. Sent by Tutorial to first-time players and by
-- the /intro command; when it ends (or can't play) the client fires TutSkip "introDone" so the tutorial can start.
local introSerial = 0
local function runIntro(d)
	local plots = workspace:FindFirstChild("Plots")
	local hotel = plots and plots:FindFirstChild(player:GetAttribute("Plot") or "")
	local hx = 0
	if hotel and hotel:IsA("Model") then
		local door = hotel:FindFirstChild("Doors")
		hx = (door and door:IsA("Model") and door:GetBoundingBox() or hotel:GetBoundingBox()).Position.X
	end
	subject = nil
	local V = Vector3.new
	local function glide(a, b, la, lb, fov)
		return function(t, k)
			local e = ease(k)
			return CFrame.lookAt(a:Lerp(b, e), la:Lerp(lb, e)), fov
		end
	end
	local shots = {
		{ 6.0, glide(V(hx - 230, 34, 350), V(hx - 120, 26, 330), V(hx - 40, 6, 150), V(hx + 20, 8, 110), 52), cut = true, follow = 2.5 },
		{ 6.4, glide(V(hx - 150, 7, 96), V(hx - 60, 9, 99), V(hx + 20, 14, 70), V(hx + 30, 12, 40), 58), cut = true, follow = 3 },
		{ 7.2, function(t, k)
			local a = math.rad(-52 + 74 * ease(k))
			local look = V(hx, 9, 22)
			return CFrame.lookAt(look + V(math.sin(a) * 66, 17 - 5 * ease(k), math.cos(a) * 66), look), 46
		end, cut = true, follow = 3 },
		{ 5.6, glide(V(hx + 20, 10, 80), V(hx + 7, 7, 50), V(hx, 9, 30), V(hx, 8, 28), 44), cut = true, follow = 3 },
	}
	local CARDS = {
		{ 0.9, "HARBOUR VIEW", "A sleepy seaside town", "Sun, sand, and one very old hotel." },
		{ 6.9, "A LETTER ARRIVES", "Great-aunt Marigold's will", "\"To my favourite relative I leave the Seabreeze. Be kind to her.\"" },
		{ 13.3, "THE SEABREEZE HOTEL", "She has seen better days", "Boarded windows. Weeds at the door. Not one guest in years." },
		{ 20.4, "YOUR TURN", "Bring her back to life", "Check guests in, fix her up, and make her the grandest hotel on the coast." },
	}
	introSerial += 1
	local my = introSerial
	play(shots, function()
		for i, c in ipairs(CARDS) do
			if i > 1 then
				task.delay(c[1] - 0.7, function() if my == introSerial and busy and not skipped then hideCard() end end)
			end
			task.delay(c[1], function()
				if my == introSerial and busy and not skipped then showCard(c[2], c[3], c[4], nil) end
			end)
		end
	end)
	introSerial += 1
end

--@@COMMANDS
	-- round 20: testing commands for the seasons, the weather, special guests, the story and the hotel's look
	local SEASONS = { seasonspr = 1, seasonsum = 2, seasonfal = 3, seasonal = 3, seasonaut = 3, seasonwin = 4 }
	local SEASON_NAMES = { "Spring", "Summer", "Autumn", "Winter" }
	local WEATHERS = { weatherclear = "clear", weathersun = "clear", weathercloud = "cloudy", weatherfog = "fog", weatherrain = "rain", weatherstorm = "storm", weathersnow = "snow" }
	local isEvent = cmd:sub(1, 5) == "event" and #cmd > 5
	if SEASONS[cmd] or WEATHERS[cmd] or isEvent or cmd == "seasonauto" or cmd == "intro" or cmd == "look" or cmd == "upgrades" or cmd == "commands" then
		if not isAdmin(player) then tell(player, "/" .. cmd .. " is an admin command", true) return true end
		local Shared = RS.Shared
		if SEASONS[cmd] then
			Shared:SetAttribute("SeasonForce", SEASONS[cmd])
			tell(player, "Season set to " .. SEASON_NAMES[SEASONS[cmd]] .. " (/seasonauto to let the calendar run)")
		elseif cmd == "seasonauto" then
			Shared:SetAttribute("SeasonForce", nil)
			tell(player, "Season follows the calendar again")
		elseif WEATHERS[cmd] then
			Shared:SetAttribute("TestWeather", WEATHERS[cmd])
			tell(player, "Weather set to " .. WEATHERS[cmd])
		elseif isEvent then
			local id = cmd:sub(6)
			local hotel = hotelOf(player)
			local okE, Events = pcall(require, game.ServerStorage.GuestEvents)
			if not hotel then
				tell(player, "Join your hotel first", true)
			elseif not (okE and Events.DEFS[id]) then
				local names = {}
				if okE then for k in pairs(Events.DEFS) do table.insert(names, k) end end
				table.sort(names)
				tell(player, "Events: " .. table.concat(names, ", "), true)
			else
				hotel:SetAttribute("TestEvent", id)
				hotel:SetAttribute("TestSpawn", true)
				tell(player, "The next guest will be: " .. id)
			end
		elseif cmd == "intro" then
			Notify:FireClient(player, "cutscene", { kind = "intro" })
		elseif cmd == "look" or cmd == "upgrades" then
			local hotel = hotelOf(player)
			if not hotel then tell(player, "Join your hotel first", true) return true end
			local Up = require(RS.Shared.Upgrades)
			local lv = Up.levels(hotel)
			if cmd == "look" then
				local n = math.clamp(math.floor(tonumber(arg) or 0), 0, Up.BY.curb.max)
				lv.curb = n
				tell(player, "Hotel look: " .. Up.BY.curb.levels[n + 1])
			else
				for _, d in ipairs(Up.LIST) do lv[d.id] = d.max end
				tell(player, "Every upgrade maxed")
			end
			hotel:SetAttribute("Upgrades", Up.encode(lv))
		else
			tell(player, "/seasonspr /seasonsum /seasonal /seasonwin /seasonauto, /weatherclear /weathercloud /weatherfog /weatherrain /weatherstorm /weathersnow, /event<name>, /intro, /look 0-4, /upgrades")
		end
		return true
	end

