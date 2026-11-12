-- ReplicatedStorage.Shared.Faces (round 16, 2026-11-10): faces that move, now with real variety.
-- Every NPC (except a player's friend wearing their own avatar) gets a drawn face in decal layers on its
-- ClassicHead (made by Run a Hotel tools/faces16.py):
--   FaceUpper  eyes: 10 styles x 11 states. Women fa (round, blue, lashes), fb (almond, green, winged liner),
--              fc (doe, brown, lower lashes), fd (bean with lashes); men ma (round, brown), mb (narrow, blue-grey),
--              mc (bean), md (hooded, hazel); kids ka (big shiny); elders ea (small, crow's feet)
--   FaceBrow   white brows tinted to the hair (Decal.Color3): thin, soft, straight, bushy, kid x 7 kinds
--   FaceMouth  13 shapes in two sets: m (ink line) and f (rose lips)
--   FaceNose   1..3;  FaceMark  freckles / freckles2 / mole / wrinkles / rosy;  FaceHair (tinted) stubble /
--              moustache / goatee / beard / handlebar;  FaceExtra  the emotional blush
-- Model attributes: FaceStyle (eyes), FaceBrow, FaceLips ("m"|"f"), BrowColor, Female, Kind.
-- Server: Faces.apply(classicHead, model, rng, opts) puts the layers on. Client (NPCAnim): Faces.pick(...) says
-- what to show each frame: the feel of the last line (model attribute Feel = "feel:n"), else their mood, plus
-- blinks and lip sync (Speech sets SpeakT0 / SpeakDur / SpeakText on the model while they talk).
local F = {}

F.EYES = {
	ea = { angry = 80274679950691, blink = 139791857331112, happy = 73617686823912, joy = 96194963005865, neutral = 116039524854189, sad = 99122850058665, smug = 75057632172388, think = 106664674842227, tired = 80067832842529, wide = 96677161075999, worried = 131060767717515 },
	fa = { angry = 137217201212754, blink = 74467033914828, happy = 102243019057787, joy = 103644526693434, neutral = 107381232119369, sad = 84506209748450, smug = 117431278866775, think = 132903262537875, tired = 135161997287095, wide = 110731535989886, worried = 135426212674328 },
	fb = { angry = 140534091848881, blink = 131570575574946, happy = 84556756721427, joy = 103147235804913, neutral = 93158419531191, sad = 81360176815064, smug = 100459027227963, think = 97431191245412, tired = 128833060795352, wide = 110500930284047, worried = 84151284870141 },
	fc = { angry = 90811913864327, blink = 84647755365913, happy = 87698358298420, joy = 128583740796738, neutral = 98415960363291, sad = 91757589739221, smug = 122677606991046, think = 131480853085189, tired = 133323121916840, wide = 79792038679477, worried = 86510157112038 },
	fd = { angry = 82627953379042, blink = 140653540515964, happy = 78458340521361, joy = 90087134893922, neutral = 113767851616662, sad = 72254887247484, smug = 104323612585397, think = 127962115966084, tired = 105483119316057, wide = 105503519413265, worried = 135615123170724 },
	ka = { angry = 106380959134223, blink = 79684931864928, happy = 80584891017994, joy = 108775676267057, neutral = 70610612289229, sad = 134072904434355, smug = 73542613307475, think = 113413223370905, tired = 71347424171140, wide = 126967623252096, worried = 91864183973846 },
	ma = { angry = 77978469911879, blink = 103843503529340, happy = 79253008441025, joy = 104478909692868, neutral = 77230768039794, sad = 114390198169946, smug = 97777767476158, think = 125047159058058, tired = 123767042819199, wide = 130192647325297, worried = 105970021709970 },
	mb = { angry = 132970502356192, blink = 81059633773127, happy = 127164952062664, joy = 101427889568829, neutral = 75603741969372, sad = 136654098184149, smug = 126438876193480, think = 83870356563542, tired = 76905563160351, wide = 72523449623107, worried = 112379544529559 },
	mc = { angry = 99474084348586, blink = 135475264780661, happy = 118461111540042, joy = 90087134893922, neutral = 99032502804931, sad = 73981470966858, smug = 119338876940579, think = 118571238092784, tired = 105841122994761, wide = 94596323823000, worried = 86983800785847 },
	md = { angry = 117283529017593, blink = 102317164336749, happy = 133802022603703, joy = 128583740796738, neutral = 75678347735909, sad = 114629511940656, smug = 101700315420395, think = 83571423825184, tired = 96374007157388, wide = 123826867250301, worried = 95571835589066 },
}
F.BROWS = {
	bushy = { angry = 123616004663216, flat = 110534247895364, high = 77984680491626, neutral = 137772734904655, raised = 111284533460832, sad = 100872419963714, worried = 101041772770192 },
	kid = { angry = 121451122872422, flat = 116878846546660, high = 114712022005488, neutral = 102409464416501, raised = 104990711628372, sad = 134060582574031, worried = 139731302291689 },
	soft = { angry = 98963747901500, flat = 121394110807736, high = 73235995577304, neutral = 70433755180563, raised = 85428603118785, sad = 117588308176624, worried = 81717544705386 },
	straight = { angry = 102937550349711, flat = 70422388136483, high = 91128579543228, neutral = 130069359604949, raised = 98318448248428, sad = 119431658413393, worried = 96227595169889 },
	thin = { angry = 131078857597857, flat = 114190646366207, high = 83987531193757, neutral = 115438254638606, raised = 88957354972838, sad = 137649058489793, worried = 72047157652671 },
}
F.MOUTHS = {
	f = { flat = 120716569699053, frown = 89012115130341, grin = 87855718185121, grit = 84716942800612, laugh = 72884865844954, o = 81797254583916, smallO = 140138297876035, smile = 99004042995153, smirk = 110805229803772, talkA = 110964578119411, talkE = 86387298614632, talkO = 97303749736171, wavy = 127251790096391 },
	m = { flat = 137719886112804, frown = 73473048977552, grin = 136900257576921, grit = 94217769485940, laugh = 98890445232257, o = 71237129281692, smallO = 119728435164649, smile = 138041603623649, smirk = 84735980161970, talkA = 123237663944947, talkE = 77305468447082, talkO = 112571530682251, wavy = 139203131971947 },
}
F.NOSE = { 116763676954357, 130037934839772, 88110604664174 }
F.MARK = { freckles = 84110724541280, mole = 87046699976235, wrinkles = 131751887289667, rosy = 89056679090193, freckles2 = 127677593229832 }
F.FHAIR = { stubble = 107852073310054, moustache = 122546190710792, goatee = 112289618133166, beard = 131160367364727, handlebar = 96965193305479 }
F.BLUSH16 = 107840866515962

F.U = F.EYES
-- old saves and staff looks used styles a / b / c
F.U.a, F.U.b, F.U.c = F.EYES.mc, F.EYES.fd, F.EYES.ma
F.M = F.MOUTHS.m
F.BLUSH = F.BLUSH16
F.FRECKLES = F.MARK.freckles

local function id(n) return "rbxassetid://" .. tostring(n) end
F.id = id

F.FEMALE_EYES = { "fa", "fb", "fc", "fd" }
F.MALE_EYES = { "ma", "mb", "mc", "md" }
-- brow colours by hair tone
F.TONES = {
	black = Color3.fromRGB(34, 28, 28), brown = Color3.fromRGB(70, 46, 32), chestnut = Color3.fromRGB(104, 62, 38),
	red = Color3.fromRGB(150, 70, 40), blonde = Color3.fromRGB(176, 136, 84), grey = Color3.fromRGB(166, 164, 160),
}
local NATURAL = { "black", "brown", "brown", "chestnut", "black" }

-- which brow goes with each eye state
F.BROW_OF = {
	neutral = "neutral", happy = "raised", joy = "raised", sad = "sad", angry = "angry", wide = "high", tired = "flat",
	blink = "neutral", worried = "worried", think = "raised", smug = "flat",
}

-- feel -> { upper, mouth, blush }
F.EXPR = {
	happy = { "happy", "grin" }, laugh = { "joy", "laugh" }, excited = { "wide", "laugh" }, joy = { "joy", "grin" },
	sad = { "sad", "frown" }, angry = { "angry", "grit" }, grump = { "angry", "frown" }, surprised = { "wide", "o" },
	shy = { "joy", "smile", true }, think = { "think", "smirk" }, tired = { "tired", "flat" }, proud = { "smug", "smirk" },
	grateful = { "joy", "smile", true }, nervous = { "worried", "wavy" }, ask = { "happy", "smile" }, shrug = { "neutral", "flat" },
	worried = { "worried", "wavy" }, love = { "joy", "smile", true },
}

-- their resting face from mood (0..100) and energy
function F.moodExpr(m, energy)
	if energy and energy < 22 then return "tired", "flat" end
	if not m then return "neutral", "smile" end
	if m >= 82 then return "happy", "grin" end
	if m >= 62 then return "neutral", "smile" end
	if m >= 44 then return "neutral", "flat" end
	if m >= 28 then return "sad", "frown" end
	return "angry", "grit"
end

function F.mouthTex(lips, shape)
	local set = F.MOUTHS[lips or "m"] or F.MOUTHS.m
	return id(set[shape] or set.smile)
end

function F.eyeTex(style, state)
	local U = F.EYES[style or "ma"] or F.EYES.ma
	return id(U[state] or U.neutral)
end

function F.browTex(style, state)
	local B = F.BROWS[style or "straight"] or F.BROWS.straight
	return id(B[F.BROW_OF[state] or "neutral"] or B.neutral)
end

---------------------------------------------------------------- server

local function pick(rng, t) return t[rng:NextInteger(1, #t)] end
local function wpick(rng, w)
	local tot = 0
	for _, e in ipairs(w) do tot += e[2] end
	local r = rng:NextNumber() * tot
	for _, e in ipairs(w) do r -= e[2] if r <= 0 then return e[1] end end
	return w[1][1]
end

-- a whole face: { eyes, brow, lips, nose, mark, fhair, tone }.  opts = { female, kind, tone }
function F.roll(rng, opts)
	opts = opts or {}
	local female, kind = opts.female, opts.kind
	local f = {}
	if kind == "kid" then
		f.eyes = wpick(rng, { { "ka", 6 }, { female and "fd" or "mc", 2 }, { female and "fa" or "ma", 1 } })
		f.brow = "kid"
		f.mark = wpick(rng, { { "rosy", 5 }, { "freckles", 2 }, { false, 3 } })
	elseif kind == "elder" then
		f.eyes = wpick(rng, { { "ea", 6 }, { female and "fc" or "md", 2 } })
		f.brow = female and "thin" or "bushy"
		f.mark = wpick(rng, { { "wrinkles", 7 }, { false, 3 } })
	else
		f.eyes = pick(rng, female and F.FEMALE_EYES or F.MALE_EYES)
		f.brow = female and (rng:NextNumber() < 0.55 and "thin" or "soft") or (rng:NextNumber() < 0.6 and "straight" or "bushy")
		f.mark = wpick(rng, { { "freckles", 13 }, { "freckles2", 6 }, { "mole", female and 10 or 4 }, { false, 70 } })
	end
	f.lips = female and "f" or "m"
	f.nose = wpick(rng, female and { { 1, 4 }, { 2, 4 }, { 3, 2 } } or { { 1, 4 }, { 2, 2 }, { 3, 4 } })
	f.fhair = false
	if not female and kind ~= "kid" then
		if kind == "elder" then
			f.fhair = wpick(rng, { { "moustache", 3 }, { "beard", 3 }, { "handlebar", 2 }, { false, 4 } })
		else
			f.fhair = wpick(rng, { { "stubble", 16 }, { "goatee", 9 }, { "beard", 9 }, { "moustache", 7 }, { "handlebar", 3 }, { false, 56 } })
		end
	end
	f.tone = opts.tone or (kind == "elder" and rng:NextNumber() < 0.75 and "grey") or pick(rng, NATURAL)
	return f
end

local function dec(ch, name, tex, z, color)
	local d = Instance.new("Decal")
	d.Name = name
	d.Face = Enum.NormalId.Front
	d.Texture = tex
	d.ZIndex = z
	if color then d.Color3 = color end
	d.Parent = ch
	return d
end

-- put a rolled (or given) face on a ClassicHead
function F.wear(ch, model, f)
	for _, d in ipairs(ch:GetChildren()) do
		if d:IsA("Decal") then d:Destroy() end
	end
	local tone = F.TONES[f.tone or "brown"] or F.TONES.brown
	dec(ch, "FaceNose", id(F.NOSE[f.nose or 1] or F.NOSE[1]), 1)
	dec(ch, "FaceMark", f.mark and id(F.MARK[f.mark]) or "", 1)
	dec(ch, "FaceExtra", "", 1)
	local fh = dec(ch, "FaceHair", f.fhair and id(F.FHAIR[f.fhair]) or "", 2, tone)
	fh.Transparency = (f.fhair == "beard" or f.fhair == "stubble") and 0.25 or 0.08
	dec(ch, "FaceUpper", F.eyeTex(f.eyes, "neutral"), 3)
	dec(ch, "FaceBrow", F.browTex(f.brow, "neutral"), 4, tone)
	dec(ch, "FaceMouth", F.mouthTex(f.lips, "smile"), 4)
	model:SetAttribute("FaceStyle", f.eyes)
	model:SetAttribute("FaceBrow", f.brow)
	model:SetAttribute("FaceLips", f.lips)
	model:SetAttribute("BrowColor", tone)
	model:SetAttribute("FaceFreckles", nil)
end

function F.apply(ch, model, rng, opts)
	rng = rng or Random.new()
	opts = opts or {}
	if opts.female == nil then opts.female = model:GetAttribute("Female") == true end
	opts.kind = opts.kind or model:GetAttribute("Kind")
	opts.tone = opts.tone or model:GetAttribute("HairTone")
	local f = F.roll(rng, opts)
	F.wear(ch, model, f)
	return f.eyes
end

---------------------------------------------------------------- client

local VOWEL = { a = "talkA", o = "talkO", u = "talkO", w = "talkO", e = "talkE", i = "talkE", y = "talkE" }
local CLOSED = { m = true, b = true, p = true, f = true, v = true }

-- the mouth for this moment of a line: k = 0..1 through it
function F.lipShape(text, k, base, tick)
	local n = #text
	if n == 0 then return base end
	local i = math.clamp(math.floor(k * n) + 1, 1, n)
	local c = string.lower(string.sub(text, i, i))
	local v = VOWEL[c]
	if v then
		if base == "grin" or base == "laugh" then return v == "talkA" and "laugh" or "grin" end
		if base == "grit" then return v == "talkE" and "grit" or "talkE" end
		return v
	end
	if CLOSED[c] or not c:match("%a") then
		return (base == "laugh" or base == "grin") and "grin" or (base == "o" and "smallO" or "flat")
	end
	return tick % 2 == 0 and "talkE" or "smallO"
end

return F
