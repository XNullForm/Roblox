-- StarterPlayerScripts.Audio: every sound in the game, played locally.
-- Listens to Notify (toast, paid, collect, cleaned, built, hired, upgraded, roomBuilt, sfx), the shower water emitters,
-- build mode (player attribute Building) and every GuiButton in PlayerGui.
-- Other client scripts play sounds with  Audio.Play:Fire(name, worldPos?)
-- Sounds are licensed library audio (Pro Sound Effects, APM, Roblox music), so they play in any experience.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local Notify = Shared:WaitForChild("Remotes"):WaitForChild("Notify")

local function group(name, vol)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Volume = vol
	g.Parent = SoundService
	return g
end
local SFX = group("SFX", 0.9)
local MUSIC = group("Music", 0.32)

-- Settings: on/off (MusicOff / SfxOff) and volumes (MusicVol / SfxVol, 0..100) via player attributes
local MUSIC_VOL, SFX_VOL = 0.32, 0.9
local function applyAudioSettings()
	local mv = (player:GetAttribute("MusicVol") or 100) / 100
	local sv = (player:GetAttribute("SfxVol") or 100) / 100
	MUSIC.Volume = player:GetAttribute("MusicOff") == true and 0 or MUSIC_VOL * mv
	SFX.Volume = player:GetAttribute("SfxOff") == true and 0 or SFX_VOL * sv
end
for _, a in ipairs({ "MusicOff", "SfxOff", "MusicVol", "SfxVol" }) do
	player:GetAttributeChangedSignal(a):Connect(applyAudioSettings)
end
applyAudioSettings()

-- name = { id, volume, pitch range, optional playback region {from, to}, optional fade-out at }
local DEFS = {
	click    = { 9120232166, 0.5, { 0.8, 0.9 } },
	hover    = { 9120232166, 0.08, { 0.55, 0.6 } },
	select   = { 9126073318, 0.3, { 0.78, 0.84 } },
	turn     = { 9120972321, 0.35, { 1.1, 1.25 } },
	open     = { 9125648149, 0.4, { 1, 1 } },
	close    = { 9125648149, 0.3, { 0.8, 0.8 } },
	place    = { 9113481039, 0.55, { 1.15, 1.3 } },
	move     = { 9113481039, 0.4, { 1.3, 1.45 } },
	sell     = { 9113728756, 0.6, { 1, 1.05 } },
	error    = { 9126073001, 0.45, { 0.5, 0.5 } },
	ready    = { 9126073001, 0.55, { 0.85, 0.9 } },
	dirty    = { 9126073318, 0.32, { 0.48, 0.52 } },
	coins    = { 9113704038, 0.55, { 1, 1.1 } },
	jingle   = { 9113849492, 0.5, { 1, 1.1 } },
	register = { 9113728042, 0.7, { 1, 1 } },
	broom    = { 9113592940, 0.8, { 0.95, 1.1 } },
	spray    = { 9119519807, 0.7, { 1, 1.1 } },
	scrub    = { 9119519807, 0.6, { 0.8, 0.85 } },
	sheets   = { 9120972321, 0.6, { 0.55, 0.62 } },
	sparkle  = { 9126073318, 0.2, { 0.95, 1.05 } },
	flush    = { 9126104501, 0.8, { 1, 1 }, nil, 5 },
	bell     = { 9114058690, 0.6, { 1, 1 }, nil, 1.6 },
	arrive   = { 9126073318, 0.35, { 0.66, 0.72 } },
	knock    = { 9120918417, 0.9, { 0.94, 1.08 } },
	door     = { { 9119122478, 9120839581, 9120839848 }, 0.75, { 1.0, 1.1 }, nil, 2 },
	-- round 20: the swing doors' own set -- a creak as the leaf starts to move, a latch as it settles shut
	-- round 14: variants (a list of ids: one is picked at random, never the same twice in a row)
	doorCreak = { { 9114150997, 9120839010, 9120839174, 9120839359, 9120839193, 9120839212, 9120839368 }, 0.6, { 0.94, 1.08 }, nil, 1.3 },
	doorLatch = { { 9114142431, 9114142587, 9114142582 }, 0.55, { 0.95, 1.08 }, nil, 0.9 },
	doorSoft  = { { 9120839581, 9120839870, 9120839848, 9120839871 }, 0.6, { 0.95, 1.06 }, nil, 1.8 },
	handle    = { { 9114138313, 9114138392, 9114138479 }, 0.45, { 1.05, 1.2 }, { 0, 0.4 }, 0.4 },
	patter    = { { 9118031958, 9118032245, 9118032134, 9118032216 }, 0.16, { 0.9, 1.15 } },
	hammer   = { 9114753781, 0.6, { 1, 1 }, nil, 2.6 },
	fanfare  = { 9113849492, 0.5, { 1.18, 1.24 } }, -- round 11: the old loud song is gone for good (a soft chime; big moments use STINGS)
	tab      = { 9120232166, 0.35, { 0.68, 0.74 } },
	tick     = { 9120232166, 0.22, { 0.58, 0.64 } },
	toast    = { 9126073318, 0.3, { 0.7, 0.76 } },
	-- round 17: the voice blip (a bubble's words type in to this; the caller sets the pitch so each
	-- speaker keeps their own voice, and longer lines blip more -- see Bubbles)
	blip     = { 9120232166, 0.5, { 0.5, 0.8 } },
	-- the kitchen (round 10c)
	sizzle   = { 9114542867, 0.5, { 0.95, 1.05 }, { 3, 6 }, 1.6 },
	chop     = { 9120918417, 0.5, { 1.55, 1.75 } },
	flip     = { 9126015450, 0.35, { 1.15, 1.3 } },
	-- upkeep (round 11)
	zap      = { 9126073001, 0.35, { 1.9, 2.3 }, nil, 1.4 },
	leak     = { 9119519807, 0.55, { 0.55, 0.65 }, nil, 1.6 },
	fixed    = { 9113849492, 0.5, { 1.2, 1.3 } },
	pickup   = { 9120972321, 0.45, { 0.9, 1 } },
}
-- round 10e: a bigger shuffled playlist, bossa and swing by day, slow piano jazz at night (licensed library music)
local MUSIC_DAY = {
	110279110219332, 127251981695845, 92231860808362, 1837070127, 1845764031, 112264709514001,
	135242814447458, 105647451905847, 135535869409208, 79463407625396,
	-- round 14: more of it (bossa, lounge, a little funk)
	134985092052325, 136984059275458, 137573587477809, 94378181487716, 122899294507694,
}
local MUSIC_NIGHT = { 116784539951494, 119374889049308, 88120440731435, 101443293051695, 140349625136896, 115115619185822,
	93026235220380, 132981957360812, 83199167653761, 81972581156700, 71043771180087 }
-- stings for big moments (the music ducks under them)
local STINGS = { levelUp = 85130118995016, chapter = 1848342733, gradeUp = 1848342733 }

local holder = Instance.new("Folder")
holder.Name = "AudioLocal"
holder.Parent = workspace

local rng = Random.new()
local lastAt = {}
local lastPick = {}

local function fadeStop(s, t)
	local tw = TweenService:Create(s, TweenInfo.new(t), { Volume = 0 })
	tw:Play()
	tw.Completed:Connect(function() s:Destroy() end)
end

-- plays a named sound; with pos it comes from that spot in the world. pitch (a {lo, hi} range) overrides
-- the def's own, so callers can give a speaker a steady voice (the blips above).
local function play(name, pos, pitch)
	-- Shared.UI sends capitalised names ("Click"); the same sound twice within 0.06 s plays once
	name = string.lower(tostring(name))
	local d = DEFS[name]
	if not d then return end
	local now = os.clock()
	if lastAt[name] and now - lastAt[name] < 0.06 then return end
	lastAt[name] = now
	local pr = (typeof(pitch) == "table" and #pitch == 2) and pitch or d[3]
	local id = d[1]
	if type(id) == "table" then
		local n = #id
		local k = rng:NextInteger(1, n)
		if n > 1 and k == lastPick[name] then k = k % n + 1 end
		lastPick[name] = k
		id = id[k]
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = d[2] * rng:NextNumber(0.85, 1.05)
	s.PlaybackSpeed = rng:NextNumber(pr[1], pr[2])
	s.SoundGroup = SFX
	local carrier
	if typeof(pos) == "Vector3" then
		carrier = Instance.new("Attachment")
		carrier.WorldPosition = pos
		carrier.Parent = workspace.Terrain
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 14
		s.RollOffMaxDistance = 160
		s.Parent = carrier
	else
		s.Parent = holder
	end
	if d[4] then
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(d[4][1], d[4][2])
	end
	s:Play()
	if d[5] then task.delay(d[5], function() if s.Parent then fadeStop(s, 0.6) end end) end
	local life = (d[5] and d[5] + 1) or 14
	task.delay(life, function()
		if carrier then carrier:Destroy() elseif s.Parent then s:Destroy() end
	end)
	s.Ended:Connect(function()
		if carrier then carrier:Destroy() else s:Destroy() end
	end)
end

local ev = Instance.new("BindableEvent")
ev.Name = "Play"
ev.Event:Connect(play)
ev.Parent = script

---------------------------------------------------------------- server events

local CLEAN = { Bed = "sheets", Shower = "spray", Toilet = "scrub", Floor = "broom" }

Notify.OnClientEvent:Connect(function(kind, d)
	d = d or {}
	if kind == "sfx" then
		play(d.name, d.pos)
	elseif kind == "toast" then
		if d.bad then play("error")
		elseif d.icon == "roomReady" or d.icon == "star" then play("ready")
		elseif d.icon == "roomDirty" then play("dirty") end
	elseif kind == "paid" then
		play("coins", d.pos)
	elseif kind == "collect" then
		play("register")
		task.delay(0.15, play, "jingle")
	elseif kind == "cleaned" then
		play(CLEAN[d.task] or "broom", d.pos)
		task.delay(0.25, play, "sparkle")
	elseif kind == "built" then
		if d.kind == "place" then play("place", d.pos)
		elseif d.kind == "move" then play("move", d.pos)
		elseif d.kind == "sell" then play("sell"); task.delay(0.12, play, "jingle") end
	elseif kind == "levelUp" or kind == "chapter" or kind == "gradeUp" then
		-- round 10e: a sting over ducked music
		local id = STINGS[kind]
		if id then
			local st = Instance.new("Sound")
			st.SoundId = "rbxassetid://" .. id
			st.Volume = 0.7
			st.SoundGroup = SFX
			st.Parent = holder
			local back = MUSIC.Volume
			TweenService:Create(MUSIC, TweenInfo.new(0.4), { Volume = back * 0.15 }):Play()
			st:Play()
			task.delay(7, function()
				TweenService:Create(MUSIC, TweenInfo.new(2), { Volume = back }):Play()
				fadeStop(st, 1.5)
			end)
		end
	elseif kind == "hired" then
		play("bell")
		task.delay(0.35, play, "ready")
	elseif kind == "upgraded" then
		play("hammer", d.pos)
		task.delay(0.9, play, "fanfare")
		task.delay(1.1, play, "sparkle")
	elseif kind == "roomBuilt" then
		play("hammer", d.pos)
		task.delay(1.35, play, "fanfare")
	end
end)

---------------------------------------------------------------- showers (loop while the water runs)

local function watchShower(att)
	local water = att:WaitForChild("Water", 10)
	if not water then return end
	local loop
	local function update()
		if water.Enabled and not loop then
			loop = Instance.new("Sound")
			loop.SoundId = "rbxassetid://9119121899"
			loop.Volume = 0
			loop.Looped = true
			loop.PlaybackRegionsEnabled = true
			loop.LoopRegion = NumberRange.new(8, 48)
			loop.RollOffMode = Enum.RollOffMode.InverseTapered
			loop.RollOffMinDistance = 8
			loop.RollOffMaxDistance = 70
			loop.SoundGroup = SFX
			loop.Parent = att
			loop.TimePosition = 6
			loop:Play()
			TweenService:Create(loop, TweenInfo.new(0.5), { Volume = 0.5 }):Play()
		elseif not water.Enabled and loop then
			fadeStop(loop, 0.5)
			loop = nil
		end
	end
	water:GetPropertyChangedSignal("Enabled"):Connect(update)
	update()
end

for _, a in ipairs(workspace.Terrain:GetChildren()) do
	if a.Name == "ShowerHead" then task.spawn(watchShower, a) end
end
workspace.Terrain.ChildAdded:Connect(function(a)
	if a.Name == "ShowerHead" then task.spawn(watchShower, a) end
end)

---------------------------------------------------------------- build mode + buttons

player:GetAttributeChangedSignal("Building"):Connect(function()
	play(player:GetAttribute("Building") and "open" or "close")
end)

-- round 26: no hover sound any more -- a ding on every button the pointer crossed was the loudest,
-- shrillest thing in the game. Buttons speak when pressed; that's all they need.
local hooked = setmetatable({}, { __mode = "k" })
local function hook(b)
	if hooked[b] or not b:IsA("GuiButton") then return end
	hooked[b] = true
	b.Activated:Connect(function() play("click") end)
end
local pgui = player:WaitForChild("PlayerGui")
for _, b in ipairs(pgui:GetDescendants()) do hook(b) end
pgui.DescendantAdded:Connect(hook)

---------------------------------------------------------------- music (a shuffled lounge playlist; the menu's Settings tab mutes it)

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local Clock = require(Shared:WaitForChild("Clock"))
	local decks = {}
	local function nextTrack(night)
		-- a shuffled deck per mood; reshuffled when it runs out (never the same track twice in a row)
		local key = night and "night" or "day"
		local d = decks[key]
		if not d or d.i >= #d.list then
			local list = {}
			for i, id in ipairs(night and MUSIC_NIGHT or MUSIC_DAY) do list[i] = id end
			for i = #list, 2, -1 do local j = rng:NextInteger(1, i); list[i], list[j] = list[j], list[i] end
			if d and list[1] == d.list[#d.list] then list[1], list[#list] = list[#list], list[1] end
			d = { list = list, i = 0 }
			decks[key] = d
		end
		d.i += 1
		return d.list[d.i]
	end
	while true do
		local night = Clock.isNight(Clock.now())
		local s = Instance.new("Sound")
		s.Name = "Music"
		s.SoundId = "rbxassetid://" .. nextTrack(night)
		s.Volume = 0
		s.SoundGroup = MUSIC
		s.Parent = holder
		s:Play()
		TweenService:Create(s, TweenInfo.new(3), { Volume = 0.8 }):Play()
		local t0 = os.clock()
		while s.Parent and (not s.IsLoaded or s.TimePosition < s.TimeLength - 3) and os.clock() - t0 < 400 do
			-- dusk or dawn: move on to the other mood's music
			if os.clock() - t0 > 20 and Clock.isNight(Clock.now()) ~= night then break end
			task.wait(0.5)
		end
		if s.Parent then fadeStop(s, 3) end
		task.wait(2)
	end
end)

---------------------------------------------------------------- street ambience (round 9): the city hums outside

-- two licensed loops, crossfaded by the in-game clock: a day mix (distant city, birds, wind) and a night mix
-- (distant traffic, crickets). Loudest out by the road, softer up on the lots, quiet indoors (a roof overhead).
local Clock = require(Shared:WaitForChild("Clock"))
local ROAD_Z = 92 -- the avenue's centre line
local function loop(id)
	local s = Instance.new("Sound")
	s.Name = "Ambience"
	s.SoundId = "rbxassetid://" .. id
	s.Looped = true
	s.Volume = 0
	s.SoundGroup = SFX
	s.Parent = holder
	return s
end
local dayLoop, nightLoop = loop(9112784918), loop(9112772108)
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	dayLoop:Play()
	nightLoop:Play()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local indoor, nightMix = 0, Clock.isNight(Clock.now()) and 1 or 0
	while true do
		local cam = workspace.CurrentCamera
		local pos = cam.CFrame.Position
		params.FilterDescendantsInstances = { player.Character, holder }
		local roof = workspace:Raycast(pos, Vector3.new(0, 40, 0), params)
		indoor += ((roof and 1 or 0) - indoor) * 0.25
		nightMix += ((Clock.isNight(Clock.now()) and 1 or 0) - nightMix) * 0.08
		local near = math.clamp(1 - (math.abs(pos.Z - ROAD_Z) - 20) / 160, 0.25, 1)
		local vol = 0.55 * near * (1 - 0.75 * indoor)
		dayLoop.Volume = vol * (1 - nightMix)
		nightLoop.Volume = vol * nightMix * 0.9
		task.wait(0.25)
	end
end)

-- round 14 (hotel): rain pattering on the umbrellas near you
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local crowd = workspace:WaitForChild("StreetCrowd", 60)
	while crowd do
		local w = Shared:GetAttribute("Weather")
		if w == "rain" or w == "storm" then
			local cam = workspace.CurrentCamera
			local cpos = cam and cam.CFrame.Position or Vector3.zero
			local n = 0
			for _, m in ipairs(crowd:GetChildren()) do
				local u = m:FindFirstChild("Umbrella")
				local c = u and u:FindFirstChild("Canopy")
				if c and (c.Position - cpos).Magnitude < 38 and rng:NextNumber() < 0.55 then
					play("patter", c.Position)
					lastAt.patter = nil
					n += 1
					if n >= 3 then break end
				end
			end
			task.wait(rng:NextNumber(0.3, 0.55))
		else
			task.wait(2)
		end
	end
end)

-- round 15/26: footsteps for everyone near you -- hotel guests and staff (tagged Bubble) and the street
-- crowd outside. Each walker carries one looped step sound on its root, paced by how fast it's really
-- moving (physics velocity, or the ground covered since the last look for tweened walkers), softer on
-- carpet and rugs.
do
	local CS = game:GetService("CollectionService")
	local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
	local SOFT = { [Enum.Material.Fabric] = 0.45, [Enum.Material.Grass] = 0.6, [Enum.Material.Wood] = 1.1, [Enum.Material.WoodPlanks] = 1.1 }
	local steps = {}
	local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
	local down = RaycastParams.new()
	down.FilterType = Enum.RaycastFilterType.Exclude
	local lastAt = {}
	task.spawn(function()
		while true do
			local cam = workspace.CurrentCamera
			local cpos = cam and cam.CFrame.Position or Vector3.zero
			local seen = {}
			local walkers = {}
			for _, m in ipairs(CS:GetTagged("Bubble")) do table.insert(walkers, m) end
			local crowd = workspace:FindFirstChild("StreetCrowd")
			if crowd then
				for _, m in ipairs(crowd:GetChildren()) do table.insert(walkers, m) end
			end
			for _, m in ipairs(walkers) do
				local root = m:IsA("Model") and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
				if root and root:IsDescendantOf(workspace) and (root.Position - cpos).Magnitude < 70 then
					seen[m] = true
					local st = steps[m]
					if not st or not st.s.Parent then
						local s = Instance.new("Sound")
						s.Name = "NPCSteps"
						s.SoundId = STEP
						s.Looped = true
						s.Volume = 0
						s.RollOffMinDistance = 8
						s.RollOffMaxDistance = 55
						s.SoundGroup = sfx
						s.Parent = root
						s:Play()
						st = { s = s, pitch = rng:NextNumber(0.88, 1.12), mat = 1, n = 0 }
						steps[m] = st
					end
					local v = root.AssemblyLinearVelocity
					local sp = Vector3.new(v.X, 0, v.Z).Magnitude
					local last = lastAt[m]
					if last then
						sp = math.max(sp, (Vector3.new(root.Position.X, 0, root.Position.Z) - last).Magnitude / 0.12)
					end
					lastAt[m] = Vector3.new(root.Position.X, 0, root.Position.Z)
					st.n += 1
					if st.n % 4 == 1 then
						down.FilterDescendantsInstances = { m }
						local hit = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), down)
						st.mat = hit and (SOFT[hit.Material] or (hit.Instance.Name:lower():find("rug") and 0.4) or 0.85) or 0.8
					end
					local want = (sp > 1.2) and math.clamp(sp / 14, 0.4, 1) * 0.8 * st.mat or 0
					st.s.Volume += (want - st.s.Volume) * 0.6
					st.s.PlaybackSpeed = math.clamp(sp / 15, 0.6, 1.5) * st.pitch
				end
			end
			for m, st in pairs(steps) do
				if not seen[m] then
					lastAt[m] = nil
					if st.s then st.s:Destroy() end
					steps[m] = nil
				end
			end
			task.wait(0.12)
		end
	end)
end
