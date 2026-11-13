-- ReplicatedStorage.Shared.VoiceFX (round 16, 2026-11-10): the beeps and boops people talk in.
-- Every speaker keeps one voice: a pitch hashed from their name (deep voices sit lower, women a little higher).
-- A line plays one short synth blip per syllable, and the vowel picks the note: "a" sits high, "e" / "i" bright,
-- "o" / "u" drop to a round boop, so a line has a little tune that follows the words. A statement drifts down,
-- the end of a question lifts, "!" is louder and quicker, CAPS shout, "..." trails off slow and low, commas and
-- full stops leave small pauses. speak() returns how long the line takes; opts.dur stretches the beeps over a
-- set time (round 41: Speech only stretches long lines a little; it is the only voice now).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local V = {}

local BEEP = "rbxassetid://6467449877" -- "Talk Blip Beep Noise", 0.115 s
local BOOP = "rbxassetid://9120232166" -- the old soft blip, pitched low, for round vowels

task.spawn(function()
	local list = {}
	for _, id in ipairs({ BEEP, BOOP }) do
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Parent = SoundService
		table.insert(list, s)
	end
	pcall(function() ContentProvider:PreloadAsync(list) end)
	for _, s in ipairs(list) do s:Destroy() end
end)

local function hash(s)
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 9973 end
	return h
end

-- the base pitch of a speaker (playback speed of the beep)
function V.voiceOf(name, deep, female)
	local base = 0.86 + (hash(tostring(name or "?")) % 40) / 100
	if female then base += 0.14 end
	if deep then base -= 0.22 end
	return math.max(0.55, base)
end

-- note offsets per vowel (in playback-speed steps) and whether it's a round "boop"
local NOTE = { a = { 0.1, false }, e = { 0.16, false }, i = { 0.22, false }, y = { 0.12, false }, o = { -0.1, true }, u = { -0.16, true } }

-- syllables: each run of vowels in a word is one beep (short words get one, long ones up to 4)
local function plan(line)
	local out = {}
	for word, punct in line:gmatch("([%w']+)([^%w']*)") do
		local caps = #word > 1 and word:upper() == word and word:find("%a") ~= nil
		local lw = word:lower()
		local syl = {}
		for v in lw:gmatch("[aeiouy]+") do table.insert(syl, v:sub(1, 1)) end
		if #syl == 0 then syl = { "e" } end
		while #syl > 4 do table.remove(syl, 3) end
		for k, v in ipairs(syl) do
			table.insert(out, { v = v, caps = caps, first = k == 1 })
		end
		local last = out[#out]
		if punct:find("%?") then last.q = true end
		if punct:find("!") then last.ex = true end
		if punct:find("%.%.") then
			last.trail = true
		elseif punct:find(",") then
			last.pause = 0.1
		elseif punct:find("[%.;:]") then
			last.pause = 0.18
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

local GAP = 0.082

-- the beats a line will play (thinned to at most 60) and how long they take
local function shape(line, rate)
	local beats = plan(line)
	local seq = {}
	local step = math.max(1, #beats / 60) -- round 32: was 30, long lines ran out of beeps
	local i = 1
	while i <= #beats do
		table.insert(seq, beats[math.floor(i)])
		i += step
	end
	local excited = line:find("!") ~= nil
	local gap = GAP * (excited and 0.86 or 1) * (rate or 1)
	local d = 0
	for _, b in ipairs(seq) do d += gap + (b.pause or 0) + (b.trail and 0.22 or 0) end
	return seq, gap, excited, d
end

function V.duration(line, rate)
	if type(line) ~= "string" then return 0 end
	local _, _, _, d = shape(line, rate)
	return d
end

-- opts: rate (slower > 1), volume, dur (stretch to this long)
function V.speak(part, line, base, opts)
	opts = opts or {}
	if not part or not part.Parent or type(line) ~= "string" then return 0 end
	local seq, gap, excited, d = shape(line, opts.rate)
	local n = #seq
	if n == 0 then return 0 end
	local stretch = 1
	if opts.dur and d > 0 then stretch = math.clamp(opts.dur / d, 0.6, 1.4) end
	local pool = {}
	local sg = group()
	for k = 1, 4 do
		local s = Instance.new("Sound")
		s.Name = "Voice"
		s.SoundId = k <= 3 and BEEP or BOOP
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 30
		s.RollOffMaxDistance = 120
		s.Volume = 0
		if sg then s.SoundGroup = sg end
		-- a touch of low-pass so the beeps are round, not shrill
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain, eq.MidGain, eq.LowGain = -7, 0, 2
		eq.Parent = s
		s.Parent = part
		pool[k] = s
	end
	local endQ, endTrail = seq[n].q, seq[n].trail
	task.spawn(function()
		local rng = Random.new()
		local bi = 0
		for k, b in ipairs(seq) do
			if not part.Parent then break end
			local tail = n - k
			local note = NOTE[b.v] or NOTE.e
			local p = base * (1.04 - 0.08 * (k / n)) + note[1] * base
			local vol = 0.85
			if b.first then vol *= 1.1 end
			if b.caps then vol *= 1.5; p += 0.08 end
			if excited then vol *= 1.15; p += 0.05 end
			if endQ and tail < 3 then p += (3 - tail) * 0.09 end
			if b.trail or (endTrail and tail < 3) then p -= 0.1; vol *= 0.6 end
			local s
			if note[2] then
				s = pool[4]
				p *= 1.25 -- the boop sample sits lower
				vol *= 1.3
			else
				bi = bi % 3 + 1
				s = pool[bi]
			end
			s.PlaybackSpeed = math.max(0.4, p + rng:NextNumber(-0.03, 0.03))
			s.Volume = vol * (opts.volume or 1) * 0.55 -- round 21: quieter
			s.TimePosition = 0
			s:Play()
			local w = (gap * rng:NextNumber(0.88, 1.14) + (b.pause or 0) + (b.trail and 0.22 or 0)) * stretch
			task.wait(w)
		end
		task.wait(0.5)
		for _, s in ipairs(pool) do s:Destroy() end
	end)
	return d * stretch
end

return V
