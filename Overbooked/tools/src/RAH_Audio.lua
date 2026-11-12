-- StarterPlayerScripts.RAH_Audio: every sound in the game, played locally.
-- Listens to Notify (toast, paid, collect, cleaned, built, hired, upgraded, roomBuilt, sfx), the shower water emitters,
-- build mode (player attribute RAH_Building) and every GuiButton in PlayerGui.
-- Other client scripts play sounds with  RAH_Audio.Play:Fire(name, worldPos?)
-- Sounds are licensed library audio (Pro Sound Effects, APM, Roblox music), so they play in any experience.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RAH = RS:WaitForChild("RAH")
local Notify = RAH:WaitForChild("Remotes"):WaitForChild("Notify")

local function group(name, vol)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Volume = vol
	g.Parent = SoundService
	return g
end
local SFX = group("RAH_SFX", 0.9)
local MUSIC = group("RAH_Music", 0.32)

-- Settings: on/off (RAH_MusicOff / RAH_SfxOff) and volumes (RAH_MusicVol / RAH_SfxVol, 0..100) via player attributes
local MUSIC_VOL, SFX_VOL = 0.32, 0.9
local function applyAudioSettings()
	local mv = (player:GetAttribute("RAH_MusicVol") or 100) / 100
	local sv = (player:GetAttribute("RAH_SfxVol") or 100) / 100
	MUSIC.Volume = player:GetAttribute("RAH_MusicOff") == true and 0 or MUSIC_VOL * mv
	SFX.Volume = player:GetAttribute("RAH_SfxOff") == true and 0 or SFX_VOL * sv
end
for _, a in ipairs({ "RAH_MusicOff", "RAH_SfxOff", "RAH_MusicVol", "RAH_SfxVol" }) do
	player:GetAttributeChangedSignal(a):Connect(applyAudioSettings)
end
applyAudioSettings()

-- name = { id, volume, pitch range, optional playback region {from, to}, optional fade-out at }
local DEFS = {
	click    = { 9120232166, 0.45, { 1.15, 1.25 } },
	hover    = { 9120232166, 0.12, { 1.6, 1.7 } },
	select   = { 9126073318, 0.25, { 1.35, 1.4 } },
	turn     = { 9120972321, 0.35, { 1.1, 1.25 } },
	open     = { 9125648149, 0.4, { 1, 1 } },
	close    = { 9125648149, 0.3, { 0.8, 0.8 } },
	place    = { 9113481039, 0.55, { 1.15, 1.3 } },
	move     = { 9113481039, 0.4, { 1.3, 1.45 } },
	sell     = { 9113728756, 0.6, { 1, 1.05 } },
	error    = { 9126073001, 0.45, { 0.5, 0.5 } },
	ready    = { 9126073001, 0.55, { 1, 1 } },
	dirty    = { 9126073318, 0.3, { 0.75, 0.75 } },
	coins    = { 9113704038, 0.55, { 1, 1.1 } },
	jingle   = { 9113849492, 0.5, { 1, 1.1 } },
	register = { 9113728042, 0.7, { 1, 1 } },
	broom    = { 9113592940, 0.8, { 0.95, 1.1 } },
	spray    = { 9119519807, 0.7, { 1, 1.1 } },
	scrub    = { 9119519807, 0.6, { 0.8, 0.85 } },
	sheets   = { 9120972321, 0.6, { 0.55, 0.62 } },
	sparkle  = { 9126073318, 0.2, { 1.5, 1.6 } },
	flush    = { 9126104501, 0.8, { 1, 1 }, nil, 5 },
	bell     = { 9114058690, 0.6, { 1, 1 }, nil, 1.6 },
	arrive   = { 9126073318, 0.3, { 1.1, 1.1 } },
	knock    = { 9120918417, 0.9, { 1, 1.05 } },
	door     = { 9119122478, 0.7, { 1.05, 1.1 } },
	hammer   = { 9114753781, 0.6, { 1, 1 }, nil, 2.6 },
	fanfare  = { 9113849492, 0.5, { 1.18, 1.24 } }, -- round 11: the old loud song is gone for good (a soft chime; big moments use STINGS)
	tab      = { 9120232166, 0.35, { 1.35, 1.45 } },
	tick     = { 9120232166, 0.3, { 1.7, 1.8 } },
	toast    = { 9126073318, 0.28, { 1.2, 1.25 } },
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
}
local MUSIC_NIGHT = { 116784539951494, 119374889049308, 88120440731435, 101443293051695, 140349625136896, 115115619185822 }
-- stings for big moments (the music ducks under them)
local STINGS = { levelUp = 85130118995016, chapter = 1848342733, gradeUp = 1848342733 }

local holder = Instance.new("Folder")
holder.Name = "RAH_AudioLocal"
holder.Parent = workspace

local rng = Random.new()
local lastAt = {}

local function fadeStop(s, t)
	local tw = TweenService:Create(s, TweenInfo.new(t), { Volume = 0 })
	tw:Play()
	tw.Completed:Connect(function() s:Destroy() end)
end

-- plays a named sound; with pos it comes from that spot in the world
local function play(name, pos)
	-- RAH.UI sends capitalised names ("Click"); the same sound twice within 0.06 s plays once
	name = string.lower(tostring(name))
	local d = DEFS[name]
	if not d then return end
	local now = os.clock()
	if lastAt[name] and now - lastAt[name] < 0.06 then return end
	lastAt[name] = now
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. d[1]
	s.Volume = d[2]
	s.PlaybackSpeed = rng:NextNumber(d[3][1], d[3][2])
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

player:GetAttributeChangedSignal("RAH_Building"):Connect(function()
	play(player:GetAttribute("RAH_Building") and "open" or "close")
end)

local hooked = setmetatable({}, { __mode = "k" })
local lastHover = 0
local function hook(b)
	if hooked[b] or not b:IsA("GuiButton") then return end
	hooked[b] = true
	b.Activated:Connect(function() play("click") end)
	b.MouseEnter:Connect(function()
		if UIS.TouchEnabled and not UIS.MouseEnabled then return end
		if os.clock() - lastHover > 0.05 then lastHover = os.clock(); play("hover") end
	end)
end
local pgui = player:WaitForChild("PlayerGui")
for _, b in ipairs(pgui:GetDescendants()) do hook(b) end
pgui.DescendantAdded:Connect(hook)

---------------------------------------------------------------- music (a shuffled lounge playlist; the menu's Settings tab mutes it)

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local Clock = require(RAH:WaitForChild("Clock"))
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
local Clock = require(RAH:WaitForChild("Clock"))
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
