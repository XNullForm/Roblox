-- StarterPlayerScripts.Talk (round 15, 2026-11-09): face-to-face conversations, in first person.
-- The Talk prompt on a guest or staff member (server: HotelSim talkTo / talkStaff) sends Notify "talk" with who
-- they are, how they feel and what you can say. The camera glides from behind you into your own eyes, looking
-- at their face (your body hidden, depth of field on them, letterbox bars, the HUD out of the way), and you
-- can't walk off by accident. Their lines come up in the dialogue box, typed in step with their real voice
-- (Shared.Speech). Your replies sit in a column on the right (keys 1-9): quick replies that fit the moment,
-- then topics that open more questions. Picking one: you say it out loud first, then they answer
-- (Remotes.Talk (model, option) -> Notify "talkReply"), with a face and a gesture to match (model attribute
-- Feel, drawn by NPCAnim). Goodbye, the X, or walking out of range ends it; walking away sends "leave" so the
-- server lets them go at once (they no longer stare after you).
-- The model carries the local attribute LocalTalk while you talk (Bubbles hides their bubble; NPCAnim keeps
-- their eyes on you). Notify "review" (a guest checked out) slides a review card in at the bottom left.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Speech = require(Shared:WaitForChild("Speech"))
local T = UI.T
local Remotes = Shared:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local Talk = Remotes:WaitForChild("Talk", 30)

local playerGui = player:WaitForChild("PlayerGui")
local gui = UI.new("ScreenGui", { Name = "Talk", DisplayOrder = 30, ResetOnSpawn = false, IgnoreGuiInset = true, Parent = playerGui })

local CF, V3 = CFrame.new, Vector3.new
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function hex(c) return string.format("#%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255) end

local MOOD_COL = {
	Delighted = Color3.fromRGB(70, 222, 120),
	Happy = Color3.fromRGB(150, 220, 90),
	Okay = Color3.fromRGB(255, 196, 64),
	Unhappy = Color3.fromRGB(255, 140, 64),
	Furious = Color3.fromRGB(255, 82, 96),
}
local FEEL_VOICE = { angry = "angry", happy = "happy", grateful = "happy", proud = "happy", excited = "excited", laugh = "excited",
	sad = "sad", tired = "sleepy", shy = "shy", nervous = "shy" }
local ROLE_COL = {
	Janitor = T.teal, Doorman = T.orange, Receptionist = T.blue, Cook = T.red, Handyman = T.sun,
}

-- option looks: kind / topic -> colour, icon
local I = C.ICONS
local OPT_LOOK = {
	t_small = { T.blue, I.chat }, t_know = { T.violet, I.heart }, t_stay = { T.teal, I.bed }, t_fun = { T.sun, I.happy }, t_offer = { T.green, I.gift },
	t_work = { T.blue, I.wrench }, t_them = { T.violet, I.heart }, t_morale = { T.sun, I.star }, t_feedback = { T.orange, I.quest },
	cost = { T.green, I.cash }, back = { Color3.fromRGB(178, 185, 196), I.rotate }, bye = { T.red, I.door }, warn = { T.orange, I.angry },
	boost = { T.green, I.spark }, quick = { T.brand, I.chat }, plain = { T.brand, I.chat },
}

---------------------------------------------------------------- the cinematic frame (letterbox, vignette)

local bars = {}
for i, side in ipairs({ "Top", "Bottom" }) do
	local b = UI.new("Frame", {
		Name = "Bar" .. side, Size = UDim2.new(1, 0, 0.085, 0), Position = i == 1 and UDim2.new(0, 0, -0.09, 0) or UDim2.new(0, 0, 1.005, 0),
		AnchorPoint = Vector2.new(0, i == 1 and 0 or 0), BackgroundColor3 = Color3.fromRGB(6, 16, 26), Visible = false, ZIndex = 1, Parent = gui,
	})
	bars[i] = b
end
-- a soft darkening at the screen's edges (gradients, so no image to load)
local vignette = UI.new("Frame", { Name = "Vignette", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 0, Parent = gui })
local vigParts = {}
for i, rot in ipairs({ 0, 90, 180, 270 }) do
	local f = UI.new("Frame", { Size = (rot % 180 == 0) and UDim2.new(0.22, 0, 1, 0) or UDim2.new(1, 0, 0.26, 0),
		Position = (rot == 0) and UDim2.new() or (rot == 180 and UDim2.new(0.78, 0, 0, 0) or (rot == 90 and UDim2.new() or UDim2.new(0, 0, 0.74, 0))),
		BackgroundColor3 = Color3.fromRGB(8, 22, 36), BackgroundTransparency = 0, ZIndex = 0, Parent = vignette })
	local g = UI.new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new(0.35, 1), Parent = f })
	vigParts[i] = f
end

---------------------------------------------------------------- the dialogue box

local BASE = Vector2.new(1880, 1080) -- round 21: a smaller conversation UI
local DW, DH = 880, 196
local dWrap = UI.new("Frame", { Name = "Dialogue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -150, 1, -84), Size = UDim2.fromOffset(DW, DH + 40), BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = gui })
UI.autoScale(dWrap, BASE)
local dGroup = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = dWrap })
local dSc = UI.scaleOf(dGroup)
-- round 34: the chapter look: a white plate, the speaker's 3D icon (or your headshot) over its left edge, a coloured
-- label over their name in dark ink
-- round 41: remade. A dark glass panel; the speaker's portrait in a ring on its left edge; their name on a tab in their
-- colour sticking up over the top; the line in big white type; mood and rating in the band along the bottom
local INK = Color3.fromRGB(18, 28, 44)
local dHolder = UI.new("Frame", { Name = "Holder", Size = UDim2.new(1, -40, 0, DH), Position = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Parent = dGroup })
UI.shadow(dHolder, { drop = 8, transparency = 0.45, spread = 8 })
local box = UI.new("Frame", { Name = "Box", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = dHolder })
UI.corner(box, 24)
UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(36, 50, 76), Color3.fromRGB(16, 24, 38)), Parent = box })
local boxRim = UI.rim(box, T.violet, 3)
local ring = UI.new("Frame", { Name = "Ring", Size = UDim2.fromOffset(116, 116), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(62, 96), BackgroundColor3 = Color3.fromRGB(236, 241, 248), ZIndex = 7, Parent = dGroup })
UI.corner(ring, UDim.new(0.5, 0))
local ringRim = UI.rim(ring, T.violet, 5)
local who = UI.icon(dGroup, I.guest, 124, { Name = "Who", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(62, 96), BackgroundTransparency = 1, ZIndex = 8 })
local plate = UI.new("Frame", { Name = "Plate", Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(86, -21), BackgroundColor3 = T.violet, ZIndex = 6, Parent = box })
UI.corner(plate, 14)
UI.gloss(plate, 14, 0.3)
UI.new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = plate })
local nameLbl = UI.label(plate, "Guest", 24, { FontFace = UI.F.black, TextColor3 = T.white, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 7 })
UI.textStroke(nameLbl, 2, 0.4, INK)
local subChip = UI.label(box, "", 15, { Name = "Sub", FontFace = UI.F.black, TextColor3 = Color3.fromRGB(150, 170, 200), Position = UDim2.fromOffset(96, 28), Size = UDim2.new(1, -150, 0, 18), ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd })

-- what they say
local lineLbl = UI.label(box, "", 26, {
	FontFace = UI.F.heavy, TextColor3 = T.white, Position = UDim2.fromOffset(96, 52), Size = UDim2.new(1, -140, 0, 86),
	TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, RichText = true, LineHeight = 1.08,
})
-- the little "more" arrow when the line is done
local nextArrow = UI.new("ImageLabel", { Image = I.down, ImageColor3 = T.sun, Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -46, 1, -42), ZIndex = 6, ImageTransparency = 1, Parent = box })

-- the bottom strip: mood meter, the rating they'd give / staff level and energy
local strip = UI.new("Frame", { Name = "Strip", Size = UDim2.new(1, -130, 0, 34), Position = UDim2.new(0, 96, 1, -46), BackgroundTransparency = 1, ZIndex = 5, Parent = box })
UI.list(strip, Enum.FillDirection.Horizontal, 14, nil, Enum.VerticalAlignment.Center)
local moodBadge = UI.badge(strip, 30, T.green, I.happy, { LayoutOrder = 1, ZIndex = 6 })
local moodCol = UI.new("Frame", { Size = UDim2.fromOffset(228, 34), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 5, Parent = strip })
local moodWord = UI.label(moodCol, "HAPPY", 14, { FontFace = UI.F.display, TextColor3 = Color3.fromRGB(150, 170, 200), Size = UDim2.new(1, 0, 0, 16), ZIndex = 6 })
local track = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = Color3.fromRGB(44, 58, 84), ZIndex = 6, Parent = moodCol })
UI.corner(track, 6)
UI.rim(track, Color3.fromRGB(60, 76, 104), 1.5)
local fill = UI.new("Frame", { Size = UDim2.fromScale(0.6, 1), BackgroundColor3 = T.green, ZIndex = 7, Parent = track })
UI.corner(fill, 6)
UI.sheen(fill, 0.7)
local knob = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.6, 0.5), BackgroundColor3 = T.white, ZIndex = 8, Parent = track })
UI.corner(knob, UDim.new(0.5, 0))
local knobRim = UI.rim(knob, T.greenDk, 3)
local sep = UI.new("Frame", { Size = UDim2.fromOffset(3, 26), BackgroundColor3 = Color3.fromRGB(52, 66, 92), LayoutOrder = 3, ZIndex = 5, Parent = strip })
UI.corner(sep, 2)
local rateCol = UI.new("Frame", { Size = UDim2.fromOffset(170, 34), BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 5, Parent = strip })
local rateLbl = UI.label(rateCol, "WOULD RATE YOU", 13, { FontFace = UI.F.display, TextColor3 = Color3.fromRGB(150, 170, 200), Size = UDim2.new(1, 0, 0, 15), ZIndex = 6 })
local starRow = UI.new("Frame", { Size = UDim2.fromOffset(150, 20), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 1, ZIndex = 6, Parent = rateCol })
UI.list(starRow, Enum.FillDirection.Horizontal, 3)
local stars = {}
for i = 1, 5 do
	stars[i] = UI.new("ImageLabel", { Image = UI.IMG.star, ImageColor3 = T.sun, Size = UDim2.fromOffset(20, 20), LayoutOrder = i, ZIndex = 7, Parent = starRow })
end
local energyBar = UI.new("Frame", { Size = UDim2.fromOffset(150, 12), Position = UDim2.fromOffset(0, 19), BackgroundColor3 = Color3.fromRGB(44, 58, 84), ZIndex = 6, Visible = false, Parent = rateCol })
UI.corner(energyBar, 6)
local energyFill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.blue, ZIndex = 7, Parent = energyBar })
UI.corner(energyFill, 6)
UI.sheen(energyFill, 0.7)
local infoLbl = UI.label(strip, "", 14, { FontFace = UI.F.bold, TextColor3 = Color3.fromRGB(170, 186, 210), Size = UDim2.fromOffset(220, 34), LayoutOrder = 5, ZIndex = 6, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })

---------------------------------------------------------------- the replies (right side)

local oWrap = UI.new("Frame", { Name = "Replies", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -36, 0.53, 0), Size = UDim2.fromOffset(392, 560), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = gui })
UI.autoScale(oWrap, BASE)
local oGroup = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = oWrap })
local oList = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = oGroup })
UI.list(oList, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
local hintLbl = UI.label(oGroup, "", 13, { FontFace = UI.F.display, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 0, 1, -16), ZIndex = 4 })
UI.textStroke(hintLbl, 2, 0.2, T.night)

local closeBtn -- the X on the box

---------------------------------------------------------------- state

local current -- { guest, info, head, staff }
local shown = { key = "", list = {} }
local typingN = 0
local busy = false -- waiting on your line / their answer
local closing = false
local saved -- the camera / controls / HUD before the talk
local camT0, camFrom, camFov0 = 0, nil, 70
local dof, cc
local lastPick = 0
local lastSayN

-- hold still while talking (the Humanoid is yours, so this is local and instant)
local frozen
local function freeze(on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on then
		if hum and not frozen then
			frozen = { hum = hum, ws = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight }
			hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
		end
	elseif frozen then
		local f = frozen
		frozen = nil
		if f.hum.Parent then f.hum.WalkSpeed, f.hum.JumpPower, f.hum.JumpHeight = f.ws, f.jp, f.jh end
	end
end

local function setSelfHidden(on)
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = on and 1 or 0 end
	end
end

---------------------------------------------------------------- lines

local TextService = game:GetService("TextService")
local function textW(text, size)
	local ok, v = pcall(function() return TextService:GetTextSize(text, size, Enum.Font.FredokaOne, Vector2.new(2000, 200)).X end)
	return ok and v or #text * size * 0.55
end
local function setPlate(name, sub, col, img)
	nameLbl.Text = name
	subChip.Text = sub or ""
	plate.BackgroundColor3 = col
	ringRim.Color = col
	boxRim.Color = col
	UI.pop(plate, 0.85, 0.25)
	who.Image = img or I.guest
	local head = who.Image:find("rbxthumb", 1, true) ~= nil -- your headshot fills its square; the 3D icons are padded
	who.Size = UDim2.fromOffset(head and 84 or 124, head and 84 or 124)
	UI.pop(who, 0.8, 0.3)
end

-- types the line out over `dur` (the voice's length); call with dur nil to start now at a reading pace
local function typeLine(text, dur, italic)
	typingN += 1
	local id = typingN
	local shownText = italic and ("<i>" .. text .. "</i>") or text
	lineLbl.Text = shownText
	lineLbl.MaxVisibleGraphemes = 0
	nextArrow.ImageTransparency = 1
	local n = utf8.len(text) or #text
	dur = math.clamp(dur or (0.3 + n * 0.035), 0.25, 8)
	task.spawn(function()
		local t0 = os.clock()
		while typingN == id do
			local k = math.clamp((os.clock() - t0) / (dur * 0.9), 0, 1)
			lineLbl.MaxVisibleGraphemes = math.floor(k * n + 0.5)
			if k >= 1 then break end
			task.wait()
		end
		if typingN ~= id then return end
		lineLbl.MaxVisibleGraphemes = -1
		nextArrow.ImageTransparency = 0
		nextArrow.Position = UDim2.new(1, -46, 1, -48)
		UI.tween(nextArrow, 0.5, { Position = UDim2.new(1, -46, 1, -42) }, Enum.EasingStyle.Bounce)
	end)
end

local function voiceMood(feel, model)
	local v = feel and FEEL_VOICE[feel]
	if v then return v end
	if model and model:GetAttribute("Voice") == "grump" then return "grump" end
	local m = model and model:GetAttribute("Mood")
	if type(m) == "number" then
		if m <= 30 then return "angry" elseif m >= 78 then return "happy" end
	end
	return nil
end

-- they say it (plate in their colour, their voice, typed in step)
local function npcSays(line)
	if not current then return end
	local info = current.info
	local model = current.guest
	local col, deep = current.col, current.deep
	setPlate(info.name or "Guest", current.sub, col, current.staff and I.staff or I.guest)
	local started = false
	local function go(dur)
		if started or not current then return end
		started = true
		typeLine(line, dur)
	end
	Speech.speak(current.head, line, Speech.voiceFor(model), { important = true, flat = true, mood = voiceMood(current.feel, model), onStart = go })
	task.delay(1.2, function() go(nil) end)
end

-- you say it (your plate, your voice), then `after` once you're done talking
local function youSay(text, after)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	setPlate(player.DisplayName, "YOU", T.brand, "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150")
	local fired = false
	local function fire()
		if fired then return end
		fired = true
		after()
	end
	local started = false
	local function go(dur)
		if started then return end
		started = true
		typeLine('"' .. text .. '"', dur, true)
		task.delay(math.max(0.35, dur * 0.88), fire)
	end
	if head then
		Speech.speak(head, text, Speech.voiceFor(char), { important = true, flat = true, volume = 0.75, onStart = go })
	end
	task.delay(1.1, function() go(Speech.estimate(text)) end)
	task.delay(3.2, fire)
end

---------------------------------------------------------------- mood strip

local function moodFace(m)
	if m >= 66 then return I.happy, T.green elseif m >= 40 then return I.chat, T.sun end
	return I.angry, T.red
end

local function setMood(info, animate)
	local m = math.clamp(info.mood or 60, 0, 100)
	local col = MOOD_COL[info.moodWord] or T.sun
	local k = m / 100
	local t = animate and 0.5 or 0
	UI.tween(fill, t, { Size = UDim2.fromScale(math.max(k, 0.06), 1), BackgroundColor3 = col }, Enum.EasingStyle.Quint)
	UI.tween(knob, t, { Position = UDim2.fromScale(k, 0.5) }, Enum.EasingStyle.Back)
	UI.tween(knobRim, t, { Color = UI.shade(col, -0.4) })
	moodWord.Text = string.upper(info.staff and ("MORALE  -  " .. (info.moodWord or "")) or ("MOOD  -  " .. (info.moodWord or "")))
	moodWord.TextColor3 = col
	local img, bc = moodFace(m)
	local ic = moodBadge:FindFirstChild("Icon", true) or moodBadge:FindFirstChildWhichIsA("ImageLabel", true)
	if ic then ic.Image = img end
	UI.tween(moodBadge, t, { BackgroundColor3 = bc })
	local mbRim = moodBadge:FindFirstChild("Rim")
	if mbRim then UI.tween(mbRim, t, { Color = UI.shade(bc, -0.4) }) end
	if animate then UI.pop(moodBadge, 1.35, 0.4) end
	if info.staff then
		rateLbl.Text = "LEVEL " .. tostring(info.level or info.stars or 1) .. "  -  ENERGY"
		starRow.Visible = false
		energyBar.Visible = true
		local e = math.clamp((info.energy or 100) / 100, 0, 1)
		UI.tween(energyFill, t, { Size = UDim2.fromScale(math.max(e, 0.05), 1), BackgroundColor3 = e < 0.3 and T.red or (e < 0.6 and T.sun or T.blue) })
	else
		rateLbl.Text = "WOULD RATE YOU"
		starRow.Visible = true
		energyBar.Visible = false
		local n = info.stars or 3
		for i = 1, 5 do
			stars[i].Image = i <= n and UI.IMG.star or UI.IMG.starLine
			stars[i].ImageColor3 = i <= n and T.sun or Color3.fromRGB(70, 84, 108)
		end
	end
	local extra = info.staff and (info.review or "") or (info.want and ("Wants " .. info.want) or (info.feel and "" or (info.doing or "")))
	if not info.staff and info.review and not info.want then extra = info.review end
	infoLbl.Text = extra or ""
end

---------------------------------------------------------------- options

local function lookOf(o)
	local l = OPT_LOOK[o.id] or OPT_LOOK[o.kind or "plain"] or OPT_LOOK.plain
	if o.id == "bye" then l = OPT_LOOK.bye end
	if o.id == "back" then l = OPT_LOOK.back end
	return l[1], l[2]
end

local choose -- forward

local function optionButton(o, i, n)
	local col, img = lookOf(o)
	local deep = UI.shade(col, -0.42)
	local isTopic = o.kind == "topic"
	local topic = false -- round 34: every reply is a white plate; topics get an accent stripe
	local b = UI.new("TextButton", { Name = "Opt" .. i, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(384, 52), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = oList })
	local lip = UI.new("Frame", { Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = topic and deep or Color3.fromRGB(6, 12, 22), ZIndex = 3, Parent = b })
	UI.corner(lip, 18)
	local face = UI.new("Frame", { Name = "Face", Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(8, 0), BackgroundColor3 = topic and col or Color3.new(1, 1, 1), ZIndex = 4, Parent = b })
	UI.corner(face, 18)
	if topic then UI.sheen(face) else UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 56, 84), Color3.fromRGB(20, 30, 48)), Parent = face }) end
	local rim = UI.rim(face, topic and deep or Color3.fromRGB(64, 80, 110), 2.5)
	UI.gloss(face, 18, topic and 0.4 or 0.08)
	local playShine = UI.shine(face, 18)
	-- the key number
	local cap = UI.new("TextLabel", { Name = "Key", Text = tostring(i), TextSize = 17, FontFace = UI.F.display, TextColor3 = topic and deep or T.white,
		BackgroundColor3 = topic and T.white or col, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 6, Parent = face })
	UI.corner(cap, 10)
	UI.sheen(cap, 0.5)
	UI.rim(cap, topic and UI.shade(col, -0.2) or deep, 2)
	cap.Visible = not (UIS.TouchEnabled and not UIS.KeyboardEnabled)
	local lbl = UI.label(face, o.text, 20, {
		FontFace = UI.F.display, TextColor3 = T.white, Position = UDim2.fromOffset(cap.Visible and 54 or 18, 0), Size = UDim2.new(1, -(cap.Visible and 54 or 18) - 52, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6,
	})
	if topic then UI.textStroke(lbl, 2, 0.1, deep) end
	-- the badge on the right
	UI.icon(face, img, 40, { Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, ZIndex = 6 })
	if isTopic then
		local stripe = UI.new("Frame", { Size = UDim2.new(0, 5, 1, -16), Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = col, ZIndex = 6, Parent = face })
		UI.corner(stripe, 3)
	end
	b.MouseEnter:Connect(function()
		if busy then return end
		UI.tween(face, 0.18, { Position = UDim2.fromOffset(-4, -2) }, Enum.EasingStyle.Back)
		UI.tween(lip, 0.18, { Position = UDim2.fromOffset(-4, 4) }, Enum.EasingStyle.Back)
		UI.tween(rim, 0.18, { Color = topic and UI.shade(deep, -0.2) or col })
		playShine()
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		UI.tween(face, 0.2, { Position = UDim2.fromOffset(8, 0) }, Enum.EasingStyle.Quint)
		UI.tween(lip, 0.2, { Position = UDim2.fromOffset(8, 6) }, Enum.EasingStyle.Quint)
		UI.tween(rim, 0.2, { Color = topic and deep or Color3.fromRGB(64, 80, 110) })
	end)
	b.MouseButton1Down:Connect(function() if not busy then UI.tween(face, 0.06, { Position = UDim2.fromOffset(-2, 4) }) end end)
	b.Activated:Connect(function() choose(i) end)
	-- arrive: slide in from the right, one after another
	face.Position = UDim2.fromOffset(440, 0)
	lip.Position = UDim2.fromOffset(440, 6)
	UI.tween(face, 0.42, { Position = UDim2.fromOffset(8, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.035 * i)
	UI.tween(lip, 0.42, { Position = UDim2.fromOffset(8, 6) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.035 * i)
	return b
end

local function setOptions(info, force)
	local list = info.options or { { id = "bye", text = "Goodbye", kind = "bye" } }
	local key = ""
	for _, o in ipairs(list) do key ..= o.id .. "," end
	if key == shown.key and not force then return end
	for _, c in ipairs(oList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	shown = { key = key, list = list }
	for i, o in ipairs(list) do
		if i > 9 then break end
		optionButton(o, i, #list)
	end
	hintLbl.Text = UI.gamepad() and "" or (UIS.TouchEnabled and not UIS.KeyboardEnabled) and "TAP A REPLY" or "PRESS 1 - " .. math.min(#list, 9) .. " TO REPLY"
	if UI.gamepad() then
		local first = oList:FindFirstChild("Opt1")
		if first then GuiService.SelectedObject = first end
	end
end

local function setBusy(on)
	busy = on
	UI.tween(oGroup, 0.2, { GroupTransparency = on and 0.55 or 0 })
end

---------------------------------------------------------------- camera

local function camStep(dt)
	if not current then return end
	local cam = workspace.CurrentCamera
	local char = player.Character
	local myHead = char and char:FindFirstChild("Head")
	local head = current.head
	if not (cam and myHead and head and head.Parent) then return end
	if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
	local face = head.Position + V3(0, 0.12, 0)
	local eye = myHead.Position + V3(0, 0.3, 0)
	local dir = face - eye
	local dist = dir.Magnitude
	if dist < 0.5 then return end
	-- step in a little if they stand far off (a conversation, not a shout across the lobby)
	if dist > 6.2 then eye = face - dir.Unit * 6.2 + V3(0, (eye.Y - face.Y) * 0.3, 0) end
	-- and back off a touch if they are right in our face (head and shoulders, not a hat filling the screen)
	if dist < 4.8 then eye = face - dir.Unit * 4.8 end
	-- eyes level with theirs (a tall player shouldn't look down on the top of their hat)
	eye = V3(eye.X, face.Y + math.clamp(eye.Y - face.Y, -0.3, 0.45), eye.Z)
	dir = face - eye
	dist = dir.Magnitude
	local flatD = V3(dir.X, 0, dir.Z)
	flatD = flatD.Magnitude > 0.01 and flatD.Unit or V3(0, 0, -1)
	local right = flatD:Cross(Vector3.yAxis)
	-- frame them left of centre (the replies sit on the right), eyes on the upper third
	-- (aiming below the face lifts it above the dialogue box)
	local target = face + right * (dist * 0.2) - V3(0, dist * 0.17, 0)
	local now = os.clock()
	local sway = CFrame.Angles(math.sin(now * 0.83) * 0.0035, math.sin(now * 0.61 + 1) * 0.005, math.sin(now * 0.47) * 0.002)
	local want = CFrame.lookAt(eye, target) * sway
	local k = smooth((now - camT0) / 0.85)
	if closing then
		cam.CFrame = want
	else
		cam.CFrame = camFrom and camFrom:Lerp(want, k) or want
		cam.FieldOfView = camFov0 + (46 - camFov0) * k
	end
	if dof then dof.FocusDistance = dist end
	setSelfHidden(k > 0.55)
end

local hidden = {} -- ScreenGuis switched off for the talk
local hiddenConn

local function enterCinematic()
	local cam = workspace.CurrentCamera
	saved = { type = cam.CameraType, fov = cam.FieldOfView }
	camFrom, camFov0, camT0 = cam.CFrame, cam.FieldOfView, os.clock()
	closing = false
	RunService:BindToRenderStep("TalkCam", Enum.RenderPriority.Camera.Value + 5, camStep)
	freeze(true)
	player:SetAttribute("InTalk", true)
	-- face them (you own your character, so this shows for everyone)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local groot = current.guest:FindFirstChild("HumanoidRootPart")
	if root and groot then
		local d = groot.Position - root.Position
		d = V3(d.X, 0, d.Z)
		if d.Magnitude > 0.1 then root.CFrame = CFrame.lookAt(root.Position, root.Position + d) end
	end
	-- the HUD steps aside
	table.clear(hidden)
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g ~= gui and g.Enabled and not g:GetAttribute("KeepInTalk") and g.Name ~= "Chat" then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	if hiddenConn then hiddenConn:Disconnect() end
	hiddenConn = playerGui.ChildAdded:Connect(function(g)
		task.defer(function()
			if current and g:IsA("ScreenGui") and g ~= gui and g.Enabled and not g:GetAttribute("KeepInTalk") then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end)
	end)
	-- depth of field on them, a touch richer colour
	dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "TalkDOF"
	dof.FarIntensity, dof.NearIntensity, dof.InFocusRadius, dof.FocusDistance = 0, 0, 3.2, 6
	dof.Parent = cam
	UI.tween(dof, 0.8, { FarIntensity = 0.55 })
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TalkCC"
	cc.Parent = cam
	UI.tween(cc, 0.8, { Contrast = 0.06, Saturation = 0.1 })
	-- letterbox and vignette
	for i, b in ipairs(bars) do
		b.Visible = true
		b.Position = i == 1 and UDim2.new(0, 0, -0.09, 0) or UDim2.new(0, 0, 1.005, 0)
		UI.tween(b, 0.6, { Position = i == 1 and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0.915, 0) }, Enum.EasingStyle.Quint)
	end
	vignette.Visible = true
	for _, f in ipairs(vigParts) do f.BackgroundTransparency = 1 UI.tween(f, 0.8, { BackgroundTransparency = 0 }) end
	UI.sound("Open")
end

local function leaveCinematic()
	local cam = workspace.CurrentCamera
	closing = true
	-- hand the camera back, blending from where we are into the normal camera over half a second
	local fromCF, fromFov = cam.CFrame, cam.FieldOfView
	RunService:UnbindFromRenderStep("TalkCam")
	cam.CameraType = (saved and saved.type ~= Enum.CameraType.Scriptable) and saved.type or Enum.CameraType.Custom
	local t0 = os.clock()
	local fov1 = saved and saved.fov or 70
	RunService:BindToRenderStep("TalkCamOut", Enum.RenderPriority.Camera.Value + 5, function()
		local k = smooth((os.clock() - t0) / 0.6)
		cam.CFrame = fromCF:Lerp(cam.CFrame, k)
		cam.FieldOfView = fromFov + (fov1 - fromFov) * k
		if k >= 1 then RunService:UnbindFromRenderStep("TalkCamOut") end
	end)
	setSelfHidden(false)
	freeze(false)
	player:SetAttribute("InTalk", nil)
	if hiddenConn then hiddenConn:Disconnect() hiddenConn = nil end
	for _, g in ipairs(hidden) do if g.Parent then g.Enabled = true end end
	table.clear(hidden)
	if dof then
		local d = dof
		UI.tween(d, 0.4, { FarIntensity = 0 })
		task.delay(0.45, function() d:Destroy() end)
		dof = nil
	end
	if cc then
		local e = cc
		UI.tween(e, 0.4, { Contrast = 0, Saturation = 0 })
		task.delay(0.45, function() e:Destroy() end)
		cc = nil
	end
	for i, b in ipairs(bars) do
		UI.tween(b, 0.45, { Position = i == 1 and UDim2.new(0, 0, -0.09, 0) or UDim2.new(0, 0, 1.005, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	end
	for _, f in ipairs(vigParts) do UI.tween(f, 0.45, { BackgroundTransparency = 1 }) end
	task.delay(0.5, function()
		if current then return end
		for _, b in ipairs(bars) do b.Visible = false end
		vignette.Visible = false
	end)
end

---------------------------------------------------------------- open / close

local function close(how)
	if not current then return end
	local c = current
	current = nil
	typingN += 1
	busy = false
	GuiService.SelectedObject = nil
	if c.guest and c.guest.Parent then
		c.guest:SetAttribute("LocalTalk", nil)
		if c.head then Speech.stop(c.head) end
	end
	-- let them go at once (the X, walking away); "bye" was already sent
	if how ~= "bye" and Talk and c.guest and c.guest.Parent then Talk:FireServer(c.guest, "leave") end
	if c.sayConn then c.sayConn:Disconnect() end
	UI.sound("Close")
	UI.tween(dSc, 0.25, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UI.tween(dGroup, 0.25, { GroupTransparency = 1 })
	UI.tween(oGroup, 0.25, { GroupTransparency = 1 })
	task.delay(0.27, function()
		if current then return end
		dWrap.Visible = false
		oWrap.Visible = false
	end)
	leaveCinematic()
end

choose = function(i)
	if not current or busy then return end
	local o = shown.list and shown.list[i]
	if not o then return end
	if os.clock() - lastPick < 0.35 then return end
	lastPick = os.clock()
	UI.sound("Click")
	local btn = oList:FindFirstChild("Opt" .. i)
	if btn then
		local face = btn:FindFirstChild("Face")
		if face then UI.sparkles(face, 4, T.white, 1) end
		UI.pop(btn, 0.92, 0.3)
	end
	setBusy(true)
	local c = current
	c.expect = os.clock() + 6
	local line = o.text:gsub("%s*%(%$%d+%)", "")
	youSay(line, function()
		if current ~= c then return end
		c.expect = os.clock() + 4
		if Talk then Talk:FireServer(c.guest, o.id) end
		if o.id == "bye" then c.bye = true end
		-- never get stuck waiting
		task.delay(4, function() if current == c and busy then setBusy(false) end end)
	end)
end

local function subOf(info)
	if info.staff then
		return string.upper((info.role or "Staff") .. "  -  LV " .. tostring(info.level or info.stars or 1))
	end
	local bits = {}
	if info.gtype then table.insert(bits, info.gtype) end
	if info.persona then table.insert(bits, info.persona) end
	if #bits == 0 then table.insert(bits, "Guest") end
	local s = table.concat(bits, "  -  ")
	if info.room then s ..= "  -  ROOM " .. info.room end
	return string.upper(s)
end

local function open(info)
	local model = info.guest
	if not model or not model.Parent then return end
	local head = model:FindFirstChild("Head")
	if not head then return end
	if current and current.guest ~= model then close() end
	local first = not current
	if first then
		current = { guest = model, info = info, head = head, staff = info.staff }
		lastSayN = model:GetAttribute("SayN")
		model:SetAttribute("LocalTalk", true)
		-- their lines while we talk come through here, not their bubble
		current.sayConn = model:GetAttributeChangedSignal("SayN"):Connect(function()
			local c = current
			if not c or c.guest ~= model then return end
			if model:GetAttribute("SayMode") == "think" then return end
			if not c.expect or os.clock() > c.expect then return end -- chatter of their own, not an answer
			c.expect = nil
			local line = tostring(model:GetAttribute("Say") or "")
			if line ~= "" then npcSays(line) end
		end)
	else
		current.info = info
	end
	local c = current
	c.feel = info.feel
	if info.staff then
		local col = ROLE_COL[info.role] or T.teal
		c.col, c.deep = col, UI.shade(col, -0.42)
	else
		local col = (info.mood or 60) < 35 and T.red or T.violet
		c.col, c.deep = col, UI.shade(col, -0.42)
	end
	c.sub = subOf(info)
	setMood(info, false)
	setOptions(info, true)
	setBusy(false)
	if first then
		enterCinematic()
		dWrap.Visible, oWrap.Visible = true, true
		dGroup.GroupTransparency, oGroup.GroupTransparency = 1, 1
		dSc.Scale = 0.9
		UI.tween(dGroup, 0.4, { GroupTransparency = 0 })
		UI.tween(dSc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.tween(oGroup, 0.4, { GroupTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.15)
		-- the greeting they just said: Bubbles started it, so take it over and say it here
		Speech.stop(head)
		npcSays(info.line or "Hi!")
	end
end

if not closeBtn then
	closeBtn = UI.closeButton(dGroup, function() close() end)
	closeBtn.Position = UDim2.new(1, -16, 0, 50)
	closeBtn.ZIndex = 9
end

-- keys 1-9 pick a reply; Backspace closes
local KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9 }
UIS.InputBegan:Connect(function(io, gp)
	if not current then return end
	if io.KeyCode == Enum.KeyCode.Backspace or io.KeyCode == Enum.KeyCode.ButtonB then close() return end
	if gp then return end
	local n = KEYS[io.KeyCode]
	if n then choose(n) end
end)

-- walk away (they wander off, or you get moved) and the conversation ends
RunService.Heartbeat:Connect(function()
	if not current then return end
	local g = current.guest
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local groot = g and g.Parent and g:FindFirstChild("HumanoidRootPart")
	if not groot or not root or (groot.Position - root.Position).Magnitude > 20 then close() end
end)
player.CharacterRemoving:Connect(function() if current then close() end end)

---------------------------------------------------------------- review cards (a guest checked out)

-- reviews live at the bottom left (the toasts took the bottom right)
local reviewList = UI.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -22), Size = UDim2.fromOffset(360, 420), BackgroundTransparency = 1, Parent = gui })
UI.list(reviewList, nil, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
UI.autoScale(reviewList, BASE)

local function reviewCard(d)
	local n = d.stars or 3
	local accent = n >= 4 and T.sun or (n <= 2 and T.red or T.brand)
	local slot = UI.new("Frame", { Size = UDim2.fromOffset(350, 108), BackgroundTransparency = 1, LayoutOrder = math.floor(os.clock() * 100), Parent = reviewList })
	local card = UI.new("CanvasGroup", { Size = UDim2.new(1, 0, 1, -6), Position = UDim2.fromOffset(-400, 0), BackgroundColor3 = T.white, Parent = slot })
	UI.corner(card, 18)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(247, 249, 252)), Parent = card })
	UI.rim(card, UI.shade(accent, -0.3), 3)
	local band = UI.new("Frame", { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = accent, Parent = card })
	UI.sheen(band)
	UI.label(card, "NEW REVIEW", 13, { FontFace = UI.F.display, TextColor3 = UI.shade(accent, -0.35), Position = UDim2.fromOffset(24, 10), Size = UDim2.fromOffset(140, 16) })
	local row = UI.new("Frame", { Size = UDim2.fromOffset(120, 20), Position = UDim2.new(1, -132, 0, 8), BackgroundTransparency = 1, Parent = card })
	UI.list(row, Enum.FillDirection.Horizontal, 2)
	for i = 1, 5 do UI.new("ImageLabel", { Image = i <= n and UI.IMG.star or UI.IMG.starLine, ImageColor3 = i <= n and T.sun or Color3.fromRGB(220, 224, 230), Size = UDim2.fromOffset(20, 20), LayoutOrder = i, Parent = row }) end
	UI.label(card, '"' .. (d.text or "") .. '"', 17, {
		FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(24, 30), Size = UDim2.new(1, -40, 0, 44),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	UI.label(card, (d.name or "A guest") .. (d.room and (", room " .. d.room) or ""), 13, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(24, 78), Size = UDim2.new(1, -40, 0, 16) })
	UI.tween(card, 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	if n >= 5 then task.delay(0.35, function() UI.sparkles(card, 5, T.sun, 1) end) end
	UI.sound(n >= 5 and "sparkle" or (n <= 2 and "error" or "toast"))
	task.delay(5, function()
		UI.tween(card, 0.3, { Position = UDim2.fromOffset(-400, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.3)
		UI.tween(slot, 0.2, { Size = UDim2.fromOffset(350, 0) })
		task.wait(0.22)
		slot:Destroy()
	end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "talk" and d then
		open(d)
	elseif kind == "talkReply" and d and current and current.guest == d.guest then
		local before = current.info.mood or 60
		current.info = d
		current.feel = d.feel
		current.sub = subOf(d)
		setMood(d, d.mood ~= before)
		if (d.mood or 60) < before - 1 then UI.shake(moodBadge) end
		if current.bye then
			-- they say goodbye, then the camera comes back
			local c = current
			task.delay(math.clamp(Speech.estimate(d.line or "") + 0.5, 1.2, 3.2), function()
				if current == c then close("bye") end
			end)
			return
		end
		-- the replies come back once they've started answering
		task.delay(0.5, function()
			if not current or current.info ~= d then return end
			setOptions(d)
			setBusy(false)
		end)
	elseif kind == "review" and d then
		if player:GetAttribute("HideReviews") then return end
		reviewCard(d)
	end
end)

---------------------------------------------------------------- dropping what you carry
-- A bag (Bag) or a lost thing (Found): G or the button puts it down in front of you (Remotes.Drop).
local Drop = Remotes:WaitForChild("Drop", 30)
local dropWrap = UI.new("Frame", { Name = "DropHint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Size = UDim2.fromOffset(250, 54), BackgroundTransparency = 1, Visible = false, Parent = gui })
UI.autoScale(dropWrap, BASE)
local dropBtn = UI.button(dropWrap, {
	text = "Drop", kind = "ink", key = "G", size = UDim2.fromScale(1, 1), textSize = 18, radius = 16,
	onClick = function() if Drop then Drop:FireServer() end end,
})
local function carryName()
	if player:GetAttribute("Bag") then return "Drop the bag" end
	local f = player:GetAttribute("Found")
	if f then return "Drop the " .. string.lower(tostring(f)) end
	return nil
end
local function refreshDrop()
	local n = carryName()
	if n and not current then
		local lbl = dropBtn:FindFirstChild("Label", true)
		if lbl then lbl.Text = n end
		if not dropWrap.Visible then
			dropWrap.Visible = true
			local sc = UI.scaleOf(dropBtn)
			sc.Scale = 0.7
			UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	else
		dropWrap.Visible = false
	end
end
player:GetAttributeChangedSignal("Bag"):Connect(refreshDrop)
player:GetAttributeChangedSignal("Found"):Connect(refreshDrop)
player:GetAttributeChangedSignal("InTalk"):Connect(refreshDrop)
refreshDrop()
UIS.InputBegan:Connect(function(io, gp)
	if gp or io.KeyCode ~= Enum.KeyCode.G or player:GetAttribute("Building") or current then return end
	if carryName() and Drop then
		UI.sound("Click")
		Drop:FireServer()
	end
end)
