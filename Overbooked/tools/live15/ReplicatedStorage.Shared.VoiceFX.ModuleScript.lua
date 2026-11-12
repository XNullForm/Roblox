-- ReplicatedStorage.Shared.VoiceFX: the sound of people talking (guests, staff and players' chat).
-- Every speaker keeps one voice: a pitch hashed from their name (deep voices sit lower). A line plays a blip
-- per chunk of each word, shaped by how it's written: a statement drifts down, the end of a question lifts,
-- "!" is louder, brighter and quicker, CAPS shout, "..." trails off slow and low, commas and full stops leave
-- small pauses, and long lines are thinned so nobody babbles. speak() returns how long the line takes, so
-- the bubble's words type in at the same pace. Thoughts are silent.
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local V = {}

local BLIP = "rbxassetid://9120232166"

-- preload the blip once, on the client, before anyone speaks: without this the first
-- line of a session can be lost entirely to async loading (the sounds play into a not-yet-
-- loaded asset and come out silent)
task.spawn(function()
	local s = Instance.new("Sound")
	s.SoundId = BLIP
	s.Parent = SoundService
	ContentProvider:PreloadAsync({ s })
	s:Destroy()
end)

local function hash(s)
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 9973 end
	return h
end

function V.voiceOf(name, deep)
	-- round 26: the voice sits low (0.5-0.85x) so a blip reads as a soft "wuh", not a shrill ding;
	-- deep voices sit lower still
	local base = 0.52 + (hash(tostring(name or "?")) % 56) / 160
	if deep then base -= 0.18 end
	return math.max(0.3, base)
end

local function plan(line)
	local out = {}
	for word, punct in line:gmatch("([%w']+)([^%w']*)") do
		local n = math.clamp(math.ceil(#word / 4), 1, 3)
		local caps = #word > 1 and word:upper() == word and word:find("%a") ~= nil
		for _ = 1, n do table.insert(out, { caps = caps }) end
		local last = out[#out]
		if punct:find("%?") then last.q = true end
		if punct:find("!") then last.ex = true end
		if punct:find("%.%.") then
			last.trail = true
		elseif punct:find(",") then
			last.pause = 0.09
		elseif punct:find("[%.;:]") then
			last.pause = 0.17
		end
	end
	return out
end

local function group()
	for _, n in ipairs({ "SFX", "Sfx", "Effects" }) do
		local g = SoundService:FindFirstChild(n)
		if g and g:IsA("SoundGroup") then return g end
	end
end

local GAP = 0.074

-- the beats a line will play (thinned to at most 22) and how long they take
local function shape(line, rate)
	local beats = plan(line)
	local seq = {}
	local step = math.max(1, #beats / 22)
	local i = 1
	while i <= #beats do
		table.insert(seq, beats[math.floor(i)])
		i += step
	end
	local excited = line:find("!") ~= nil
	local gap = GAP * (excited and 0.85 or 1) * (rate or 1)
	local d = 0
	for _, b in ipairs(seq) do d += gap + (b.pause or 0) + (b.trail and 0.22 or 0) end
	return seq, gap, excited, d
end

function V.duration(line, rate)
	if type(line) ~= "string" then return 0 end
	local _, _, _, d = shape(line, rate)
	return d
end

-- opts: rate (slower > 1), volume
function V.speak(part, line, base, opts)
	opts = opts or {}
	if not part or not part.Parent or type(line) ~= "string" then return 0 end
	local seq, gap, excited, d = shape(line, opts.rate)
	local n = #seq
	if n == 0 then return 0 end
	local pool = {}
	local sg = group()
	for k = 1, 3 do
		local s = Instance.new("Sound")
		s.Name = "Voice"
		s.SoundId = BLIP
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 40
		s.RollOffMaxDistance = 130
		s.Volume = 0
		if sg then s.SoundGroup = sg end
		s.Parent = part
		pool[k] = s
	end
	local endQ, endTrail = seq[n].q, seq[n].trail
	task.spawn(function()
		local rng = Random.new()
		for k, b in ipairs(seq) do
			if not part.Parent then break end
			local tail = n - k
			local p = base * (1.02 - 0.07 * (k / n))
			local vol = 1.35
			if b.caps then vol *= 1.7; p += 0.06 end
			if excited then vol *= 1.25; p += 0.05 end
			if endQ and tail < 3 then p += (3 - tail) * 0.075 end
			if b.trail or (endTrail and tail < 3) then p -= 0.09; vol *= 0.65 end
			local s = pool[(k - 1) % 3 + 1]
			s.PlaybackSpeed = math.max(0.4, p + rng:NextNumber(-0.04, 0.04))
			s.Volume = vol * (opts.volume or 1)
			s.TimePosition = 0
			s:Play()
			local w = gap * rng:NextNumber(0.85, 1.18) + (b.pause or 0) + (b.trail and 0.22 or 0)
			task.wait(w)
		end
		task.wait(0.5)
		for _, s in ipairs(pool) do s:Destroy() end
	end)
	return d
end

return V
