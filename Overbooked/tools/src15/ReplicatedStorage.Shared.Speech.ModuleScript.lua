-- ReplicatedStorage.Shared.Speech (round 15, 2026-11-09): people really talk.
-- Round 16 (2026-11-10): they talk in beeps and boops (Shared.VoiceFX: a synth blip per syllable).
-- Round 41: beeps only. The muffled text-to-speech voice that ran underneath sounded human and doubled up with
-- the beeps, so it's gone; every guest, staff member and player keeps one beep voice (pitch from their name).
-- Mood shapes the delivery (angry: quicker and louder; sleepy: slow; excited: brighter and faster).
-- Client only.  Speech.speak(part, text, voice, opts) -> handle;  opts = { volume, mood, important, onStart(dur), range, flat }
local Players = game:GetService("Players")

local VoiceFX = require(script.Parent:WaitForChild("VoiceFX"))

local S = {}

-- voice = { babble } (the beep pitch)
function S.voiceOf(name, deep, female)
	return { babble = VoiceFX.voiceOf(tostring(name or "?"), deep, female) }
end

-- a model's voice (cached on the model): guests and staff carry Deep / Female when the server knows
local cache = setmetatable({}, { __mode = "k" })
function S.voiceFor(model)
	local v = cache[model]
	if not v then
		local pl = Players:GetPlayerFromCharacter(model)
		local name = pl and ("u" .. pl.UserId) or (model:GetAttribute("BName") or model.Name)
		v = S.voiceOf(name, model:GetAttribute("Deep"), model:GetAttribute("Female"))
		-- a player's voice pick (1..8, Settings) picks one of eight evenly spread pitches
		local pick = pl and tonumber(pl:GetAttribute("VoicePick"))
		if pick and pick >= 1 and pick <= 8 then v.babble = 0.72 + (math.floor(pick) - 1) * 0.08 end
		cache[model] = v
	end
	return v
end

local MOOD = {
	angry = { speed = 1.12, volume = 1.2 },
	grump = { speed = 1.04, volume = 1.1 },
	happy = { speed = 1.05, volume = 1.05 },
	excited = { speed = 1.14, volume = 1.15 },
	sad = { speed = 0.9, volume = 0.85 },
	sleepy = { speed = 0.84, volume = 0.8 },
	shy = { speed = 0.96, volume = 0.75 },
	posh = { speed = 0.94, volume = 1 },
}

-- plain words (no emoji, no markup), not too long
local function clean(text)
	text = tostring(text or ""):gsub("<[^>]+>", ""):gsub("[%c]", " ")
	text = text:gsub("[^%w%s%.%,%!%?%'%-%:%;%$%%]", "")
	text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 240 then text = text:sub(1, 240) end
	return text
end

local function sfxVolume()
	local pl = Players.LocalPlayer
	if not pl then return 1 end
	if pl:GetAttribute("SfxOff") or pl:GetAttribute("VoicesOff") then return 0 end
	return (pl:GetAttribute("SfxVol") or 100) / 100 * (pl:GetAttribute("VoiceVol") or 100) / 100
end

local playing = {} -- part -> handle (one line at a time per mouth)

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
		if playing[part] == handle then playing[part] = nil end
	end
	if not part or not part.Parent or line == "" then
		if opts.onStart then task.defer(opts.onStart, 0.3) end
		handle.done = true
		return handle
	end
	S.stop(part)
	playing[part] = handle
	local mood = MOOD[opts.mood or ""] or {}
	local vol = sfxVolume()
	local rate = 1 / (mood.speed or 1)
	-- beeps at their own pace; only long lines are stretched a little so the voice doesn't stop mid-sentence
	local natural = VoiceFX.duration(line, rate)
	local want = S.estimate(line)
	local dur = natural
	if vol > 0 then
		dur = VoiceFX.speak(part, line, voice.babble or 1, { volume = (opts.volume or 1) * (mood.volume or 1) * vol, rate = rate, dur = want > natural * 1.25 and math.min(want, natural * 1.4) or nil })
	end
	dur = math.clamp(dur, 0.3, 9)
	-- round 15: the speaker's model learns when it's talking and what (NPCAnim moves their mouth with it)
	local mdl = part:FindFirstAncestorOfClass("Model")
	if mdl then
		mdl:SetAttribute("SpeakText", line)
		mdl:SetAttribute("SpeakDur", math.max(dur, want * 0.8))
		mdl:SetAttribute("SpeakT0", os.clock())
	end
	if opts.onStart then opts.onStart(math.max(dur, want * 0.8)) end
	task.delay(dur + 0.2, handle.stop)
	return handle
end

-- how long a line would take to say, roughly (for bubbles that can't wait for the voice)
function S.estimate(text)
	local n = #clean(text)
	return math.clamp(0.35 + n * 0.062, 0.5, 9)
end

return S
