-- ReplicatedStorage.Shared.Speech (round 15, 2026-11-09): people really talk.
-- Round 16 (2026-11-10): they talk in beeps and boops now. The words still run underneath, but pitched up,
-- squeezed through a narrow band and chopped by a fast tremolo (robot(): you can just about make them out),
-- with a synth blip per syllable on top (Shared.VoiceFX) stretched over the same time.
-- Lines are spoken with Roblox's text-to-speech (AudioTextToSpeech): every guest, staff member and player keeps
-- one voice (one of eight, with their own pitch and pace), and what's said is what you hear, word for word.
-- Mood shapes the delivery (angry: lower, quicker, louder; sleepy: slow; excited: brighter and faster).
-- The speech service is rate limited, so a small budget decides who gets a real voice (whoever you're talking
-- to always does, then whoever is closest); everyone else falls back to the soft babble (Shared.VoiceFX).
-- Client only.  Speech.speak(part, text, voice, opts) -> handle;  opts = { volume, mood, important, onStart(dur), range }
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local VoiceFX = require(script.Parent:WaitForChild("VoiceFX"))

local S = {}

local MALE = { "1", "3", "5", "7" }
local FEMALE = { "2", "4", "6", "8" }

local function hash(s)
	local h = 11
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000003 end
	return h
end

-- voice = { id, pitch, speed, babble }
function S.voiceOf(name, deep, female)
	name = tostring(name or "?")
	local h = hash(name)
	local male
	if deep then male = true elseif female ~= nil then male = not female else male = h % 2 == 0 end
	local pool = male and MALE or FEMALE
	return {
		id = pool[(h // 2) % #pool + 1],
		pitch = ((h // 8) % 7 - 3) * 0.6 + (deep and -1.5 or 0),
		speed = 1.02 + ((h // 64) % 5 - 2) * 0.04,
		babble = VoiceFX.voiceOf(name, deep, not male),
	}
end

-- a model's voice (cached on the model): guests and staff carry Deep / Female when the server knows
local cache = setmetatable({}, { __mode = "k" })
function S.voiceFor(model)
	local v = cache[model]
	if not v then
		local pl = Players:GetPlayerFromCharacter(model)
		local name = pl and ("u" .. pl.UserId) or (model:GetAttribute("BName") or model.Name)
		v = S.voiceOf(name, model:GetAttribute("Deep"), model:GetAttribute("Female"))
		local pick = pl and pl:GetAttribute("VoicePick")
		if pick and tonumber(pick) and tonumber(pick) >= 1 and tonumber(pick) <= 8 then v.id = tostring(math.floor(tonumber(pick))) end
		cache[model] = v
	end
	return v
end

local MOOD = {
	angry = { pitch = -1.6, speed = 1.12, volume = 1.25 },
	grump = { pitch = -1.2, speed = 1.04, volume = 1.1 },
	happy = { pitch = 0.9, speed = 1.05, volume = 1.05 },
	excited = { pitch = 1.6, speed = 1.14, volume = 1.2 },
	sad = { pitch = -0.8, speed = 0.9, volume = 0.85 },
	sleepy = { pitch = -0.6, speed = 0.84, volume = 0.8 },
	shy = { pitch = 0.4, speed = 0.96, volume = 0.75 },
	posh = { pitch = 0.2, speed = 0.94, volume = 1 },
}

-- what TTS can say: plain words (no emoji, no markup), not too long
local function clean(text)
	text = tostring(text or ""):gsub("<[^>]+>", ""):gsub("[%c]", " ")
	text = text:gsub("[^%w%s%.%,%!%?%'%-%:%;%$%%]", "")
	text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 240 then text = text:sub(1, 240) end
	return text
end

-- the budget: a bucket that refills slowly; important lines may dip into a small reserve
local tokens, reserve, lastFill = 7, 4, os.clock()
local function take(important)
	local now = os.clock()
	local gain = (now - lastFill) / 5
	if gain >= 1 then
		local n = math.floor(gain)
		lastFill += n * 5
		tokens = math.min(7, tokens + n)
		if tokens >= 7 then reserve = math.min(4, reserve + 1) end
	end
	if tokens > 0 then tokens -= 1 return true end
	if important and reserve > 0 then reserve -= 1 return true end
	return false
end

local out
local function device()
	if not out or not out.Parent then
		out = Instance.new("AudioDeviceOutput")
		out.Name = "SpeechOut"
		out.Parent = SoundService
	end
	return out
end

local function sfxVolume()
	local pl = Players.LocalPlayer
	if not pl then return 1 end
	if pl:GetAttribute("SfxOff") or pl:GetAttribute("VoicesOff") then return 0 end
	return (pl:GetAttribute("SfxVol") or 100) / 100 * (pl:GetAttribute("VoiceVol") or 100) / 100
end

local function falloff(part, range)
	local cam = workspace.CurrentCamera
	if not (part and part.Parent and cam) then return 0 end
	local d = (part.Position - cam.CFrame.Position).Magnitude
	local near = 10
	if d <= near then return 1 end
	return math.clamp(1 - (d - near) / math.max(range - near, 1), 0, 1) ^ 1.6
end

local playing = {} -- part -> handle (one line at a time per mouth)

-- the robot chain: TTS -> pitch up -> band-pass -> a little grit -> fast tremolo chop. Returns the last node.
local function robot(tts, voice)
	local last = tts
	local function add(class, props)
		local ok, fx = pcall(Instance.new, class)
		if not ok then return end
		for k, v in pairs(props) do pcall(function() fx[k] = v end) end
		fx.Parent = tts
		local w = Instance.new("Wire")
		w.SourceInstance = last
		w.TargetInstance = fx
		w.Parent = fx
		last = fx
	end
	add("AudioPitchShifter", { Pitch = 1.22 + ((voice.babble or 1) - 1) * 0.3 })
	add("AudioFilter", { FilterType = Enum.AudioFilterType.Bandpass, Frequency = 1250, Q = 0.75 })
	add("AudioDistortion", { Level = 0.22 })
	add("AudioTremolo", { Frequency = 17, Depth = 0.7, Shape = 1, Duty = 0.55 })
	add("AudioFilter", { FilterType = Enum.AudioFilterType.Lowpass12dB, Frequency = 3600, Q = 0.7 })
	return last
end
local ttsOK = true

function S.stop(part)
	local h = playing[part]
	if h then h.stop() end
end

function S.speak(part, text, voice, opts)
	opts = opts or {}
	voice = voice or S.voiceOf("someone")
	local line = clean(text)
	local handle = { done = false }
	function handle.stop()
		if handle.done then return end
		handle.done = true
		if handle.tts then handle.tts:Destroy() handle.tts = nil end
		if handle.conn then handle.conn:Disconnect() handle.conn = nil end
		if playing[part] == handle then playing[part] = nil end
	end
	if not part or not part.Parent or line == "" then
		if opts.onStart then task.defer(opts.onStart, 0.3) end
		handle.done = true
		return handle
	end
	S.stop(part)
	playing[part] = handle
	local range = opts.range or 60
	local mood = MOOD[opts.mood or ""] or {}
	local shout = line:find("!") ~= nil or (#line > 4 and line == line:upper() and line:find("%a") ~= nil)
	-- round 15: the speaker's model learns when it's talking and what (NPCAnim moves their mouth with it)
	local function mark(dur)
		local mdl = part:FindFirstAncestorOfClass("Model")
		if not mdl then return end
		mdl:SetAttribute("SpeakText", line)
		mdl:SetAttribute("SpeakDur", dur)
		mdl:SetAttribute("SpeakT0", os.clock())
	end
	local function babble()
		local dur = VoiceFX.speak(part, line, voice.babble or 0.7, { volume = (opts.volume or 1) * (mood.volume or 1), rate = 1 / (mood.speed or 1) })
		dur = math.clamp(dur, 0.3, 3.4)
		mark(math.max(dur, S.estimate(line) * 0.8))
		if opts.onStart then opts.onStart(dur) end
		task.delay(dur + 0.2, handle.stop)
	end
	local vol = sfxVolume()
	if not ttsOK or vol <= 0 or not take(opts.important) then
		babble()
		return handle
	end
	task.spawn(function()
		local tts = Instance.new("AudioTextToSpeech")
		tts.Text = line
		tts.VoiceId = voice.id
		pcall(function() tts.Pitch = math.clamp((voice.pitch or 0) + (mood.pitch or 0) + (shout and 0.6 or 0), -6, 6) end)
		pcall(function() tts.Speed = math.clamp((voice.speed or 1) * (mood.speed or 1) * (shout and 1.05 or 1), 0.7, 1.5) end)
		tts.Volume = 0
		tts.Parent = SoundService
		local w = Instance.new("Wire")
		w.SourceInstance = robot(tts, voice)
		w.TargetInstance = device()
		w.Parent = tts
		handle.tts = tts
		local ok, status = pcall(function() return tts:LoadAsync() end)
		if handle.done then return end
		if not ok or status ~= Enum.AssetFetchStatus.Success or tts.TimeLength <= 0 then
			-- no voice this time (rate limit, offline...): babble instead, and back off for a while if it keeps failing
			tts:Destroy()
			handle.tts = nil
			S.fails = (S.fails or 0) + 1
			if S.fails >= 4 then
				ttsOK = false
				task.delay(45, function() ttsOK = true S.fails = 0 end)
			end
			babble()
			return
		end
		S.fails = 0
		local dur = tts.TimeLength
		local base = (opts.volume or 1) * (mood.volume or 1) * (shout and 1.15 or 1) * 0.8
		tts.Volume = base * vol * (opts.flat and 1 or falloff(part, range))
		tts:Play()
		mark(dur)
		-- the beeps ride on top, over the same time
		VoiceFX.speak(part, line, voice.babble or 1, { volume = (opts.volume or 1) * (mood.volume or 1) * vol, dur = dur })
		if opts.onStart then opts.onStart(dur) end
		handle.conn = RunService.Heartbeat:Connect(function()
			if not tts.Parent then return end
			tts.Volume = base * sfxVolume() * (opts.flat and 1 or falloff(part, range))
		end)
		task.delay(dur + 0.25, handle.stop)
	end)
	return handle
end

-- how long a line would take to say, roughly (for bubbles that can't wait for the voice)
function S.estimate(text)
	local n = #clean(text)
	return math.clamp(0.35 + n * 0.062, 0.5, 9)
end

return S
