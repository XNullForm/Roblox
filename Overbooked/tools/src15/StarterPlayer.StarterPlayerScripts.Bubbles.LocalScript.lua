-- StarterPlayerScripts.Bubbles (round 15 v2, 2026-11-09): what floats over people's heads (glossy style).
-- * Speech is back over the speaker: a white bubble with a curved tail pops up above their head, three dots
--   bounce while the voice loads, then the words type in at the pace they're spoken (Shared.Speech: real
--   text-to-speech, or the soft babble when the speech budget is spent). Thoughts stay in their heads.
-- * Staff wear a tag: their name, a level chip and their job in the job's colour. Guests wear no name.
-- * A status disc (icon + timer ring, the event badge) shows only while someone is waiting on something.
-- * Players' chat is spoken at their head too.
-- Server contract is unchanged (tag Bubble; BName, BRole "Janitor  LV 2", BRoleColor, BIcon, BBar, BT0, BSecs,
-- BDrain, BEvent, Say, SaySecs, SayN, SayMode, Mood, Voice). Player attributes HideBubbles (Settings) and
-- Building hide it all. A model with the local attribute LocalTalk is in a face-to-face talk (Talk owns it).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Speech = require(Shared:WaitForChild("Speech"))
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

for _, g in ipairs(pgui:GetChildren()) do
	if g.Name == "Captions" or g.Name == "Mark" or g.Name == "Bubble" then g:Destroy() end
end

local HEAR = 48 -- you hear (and read) people within this many studs
local TAG_FAR = 46 -- staff tags
local FAR = 80 -- status discs
local SAY_W = 310 -- round 32: bigger bubbles
local TAGS = {
	Color3.fromRGB(240, 96, 86), Color3.fromRGB(47, 155, 255), Color3.fromRGB(26, 188, 140), Color3.fromRGB(244, 150, 40),
	Color3.fromRGB(98, 166, 236), Color3.fromRGB(20, 170, 180), Color3.fromRGB(240, 80, 178), Color3.fromRGB(76, 157, 241),
}
local BAR = { yellow = T.sun, blue = T.blue, purple = T.brand, green = T.green, red = T.red }

local function hiddenAll()
	return player:GetAttribute("HideBubbles") == true or player:GetAttribute("Building") == true
end
local function hash(s)
	local h = 5
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 100003 end
	return h
end
local function moodOf(model)
	if model:GetAttribute("Voice") == "grump" then return "grump" end
	local m = model:GetAttribute("Mood")
	if type(m) == "number" then
		if m <= 30 then return "angry" elseif m >= 78 then return "happy" end
	end
	return nil
end

-- text sizes for the bubble (Builder Sans; falls back to a Gotham estimate if the async measure fails)
local SAY_SIZE = 22
local function measure(text, width)
	local ok, v = pcall(function()
		local p = Instance.new("GetTextBoundsParams")
		p.Text = text
		p.Font = UI.F.bold
		p.Size = SAY_SIZE
		p.Width = width
		return TextService:GetTextBoundsAsync(p)
	end)
	if ok and v then return v end
	return TextService:GetTextSize(text, SAY_SIZE, Enum.Font.GothamBold, Vector2.new(width, 1000))
end
-- the bubble's size for a line: as wide as the line (up to SAY_W), as tall as it wraps
local function fitBubble(line)
	local one = measure(line, 10000)
	local w = math.clamp(math.ceil(one.X) + 4, 40, SAY_W)
	local fit = measure(line, w)
	return w + 32, math.ceil(fit.Y) + 22 + 14
end

local BUB_TOP = Color3.new(1, 1, 1)
local BUB_BOT = Color3.fromRGB(248, 249, 252)
local BUB_RIM = Color3.fromRGB(233, 237, 244)
-- a speech bubble: a glossy white card with a soft lavender rim, a curved tail (rim and fill images stacked so
-- the outline runs round it) and a name chip on its top-left corner. Returns the parts.
local function makeBubble(parent, order)
	local slot = UI.new("Frame", { Name = "Say", Size = UDim2.fromOffset(120, 50), BackgroundTransparency = 1, LayoutOrder = order or 10, Visible = false, Parent = parent })
	local pop = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 1), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = slot })
	local scale = Instance.new("UIScale")
	scale.Parent = pop
	local sh = UI.shadow(pop, { drop = 6, transparency = 0.6 })
	sh.Size = UDim2.new(1, 56, 1, 42)
	local box = UI.new("Frame", { Name = "Box", Size = UDim2.new(1, 0, 1, -14), BackgroundColor3 = T.white, ZIndex = 2, Parent = pop })
	UI.corner(box, 18)
	local grad = UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(BUB_TOP, BUB_BOT), Parent = box })
	local rim = UI.rim(box, BUB_RIM, 2.5)
	local gl = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 3), BackgroundColor3 = T.white, BackgroundTransparency = 0.2, ZIndex = 2, Parent = box })
	UI.corner(gl, 8)
	local tailRim = UI.new("ImageLabel", { Image = UI.IMG.tailRim, ImageColor3 = BUB_RIM, Size = UDim2.fromOffset(32, 23), Position = UDim2.new(0.5, -24, 1, -17), ZIndex = 3, Parent = pop })
	local tailFill = UI.new("ImageLabel", { Image = UI.IMG.tailFill, ImageColor3 = BUB_BOT, Size = UDim2.fromOffset(32, 23), Position = UDim2.new(0.5, -24, 1, -17), ZIndex = 4, Parent = pop })
	local text = UI.new("TextLabel", {
		Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 1, -20), Text = "", TextSize = SAY_SIZE, FontFace = UI.F.bold,
		TextColor3 = T.cream, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = box,
	})
	local who = UI.chip(pop, "", T.brand, { TextSize = 14, Size = UDim2.fromOffset(0, 22), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(12, 0), ZIndex = 6 })
	-- the three dots while the voice loads
	local dots = UI.new("Frame", { Size = UDim2.fromOffset(42, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = box })
	local dotList = {}
	local DOTC = { T.brand, T.violet, T.blue }
	for i = 1, 3 do dotList[i] = UI.dot(dots, 10, DOTC[i], { Position = UDim2.fromOffset((i - 1) * 16, 1), ZIndex = 5 }) end
	return { slot = slot, pop = pop, scale = scale, box = box, grad = grad, rim = rim, tailRim = tailRim, tailFill = tailFill, text = text, who = who, dots = dots, dotList = dotList }
end
-- moods tint the bubble: a cross guest's goes rosy with a red rim, a delighted one golden
local MOODTINT = {
	angry = { Color3.fromRGB(255, 232, 234), Color3.fromRGB(240, 110, 124) },
	grump = { Color3.fromRGB(255, 238, 236), Color3.fromRGB(230, 150, 150) },
	happy = { Color3.fromRGB(255, 248, 222), Color3.fromRGB(250, 200, 90) },
}
local function tintBubble(b, mood)
	local t = MOODTINT[mood or ""]
	local bot, rim = t and t[1] or BUB_BOT, t and t[2] or BUB_RIM
	b.grad.Color = ColorSequence.new(BUB_TOP, bot)
	b.rim.Color = rim
	b.tailRim.ImageColor3 = rim
	b.tailFill.ImageColor3 = bot
end


local marks = {} -- model -> m

-- round 32: a capital first letter, and names, rooms and money in colour + underlined (RichText)
local function hl(s) return '<font color="#6C4BF4"><u>' .. s .. '</u></font>' end
local function tidy(line)
	return (line:gsub("^(%W*)(%l)", function(a, b) return a .. b:upper() end))
end
local function richLine(line)
	local s = line:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	s = s:gsub("%$[%d,%.]+", hl)
	s = s:gsub("[Rr]oom %d+", hl)
	local names = {}
	for mm, mk in pairs(marks) do
		local n = type(mk) == "table" and mm:GetAttribute("BName")
		local f = n and n:match("^(%a+)")
		if f and #f > 2 then names[f] = true end
	end
	for _, p in ipairs(Players:GetPlayers()) do names[p.DisplayName] = true end
	for f in pairs(names) do
		s = s:gsub("%f[%w]" .. f:gsub("%p", "%%%0") .. "%f[%W]", hl)
	end
	return s
end

local function build(model)
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	if not head or not model.Parent then return end
	local m = { model = model, head = head }
	-- the gui's bottom edge sits just over the head; everything stacks up from there
	local bb = UI.new("BillboardGui", {
		Name = "Bubble", Size = UDim2.fromOffset(400, 300), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.9, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = FAR, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = head,
		Enabled = not hiddenAll(), Parent = pgui,
	})
	local root = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	m.fade = root
	local sc = Instance.new("UIScale")
	sc.Parent = root
	local stack = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
	UI.list(stack, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	-- staff tag ------------------------------------------------------------
	-- a glossy name plate (name + level chip) with the job on a coloured ribbon under it
	local tag = UI.new("Frame", { Name = "Tag", Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 30, Visible = false, Parent = stack })
	UI.list(tag, Enum.FillDirection.Vertical, -4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	local top = UI.new("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, LayoutOrder = 1, ZIndex = 2, Parent = tag })
	UI.corner(top, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = top })
	local topRim = UI.rim(top, T.brand, 2.5)
	UI.pad(top, 12, 0, 5, 0)
	UI.list(top, Enum.FillDirection.Horizontal, 7, nil, Enum.VerticalAlignment.Center)
	local tagName = UI.new("TextLabel", { Text = "", TextSize = 17, FontFace = UI.F.display, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1, ZIndex = 3, Parent = top })
	local tagLv = UI.chip(top, "LV 1", T.brand, { TextSize = 13, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, ZIndex = 3 })
	local ribbon = UI.new("Frame", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.brand, LayoutOrder = 2, ZIndex = 1, Parent = tag })
	UI.corner(ribbon, 7)
	UI.sheen(ribbon)
	local ribbonRim = UI.rim(ribbon, T.brandDk, 2)
	UI.pad(ribbon, 10, 4, 10, 0)
	local tagRole = UI.new("TextLabel", { Text = "", TextSize = 12, FontFace = UI.F.display, TextColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), ZIndex = 2, Parent = ribbon })
	local roleStroke = UI.textStroke(tagRole, 1.5, 0, T.brandDk)

	-- status disc ------------------------------------------------------------
	local discSlot = UI.new("Frame", { Name = "Status", Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, LayoutOrder = 20, Visible = false, Parent = stack })
	local discGlow = UI.glow(discSlot, 90, T.white, { ImageTransparency = 0.45 })
	local disc = UI.new("Frame", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.white, ZIndex = 2, Parent = discSlot })
	UI.corner(disc, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(240, 242, 246)), Parent = disc })
	UI.rim(disc, BUB_RIM, 2)
	local track = UI.new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2, Parent = disc })
	UI.corner(track, UDim.new(0.5, 0))
	UI.rim(track, Color3.fromRGB(243, 245, 248), 4)
	local _, setRing, ringStrokes = UI.ring(disc, 46, 4, T.green, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local icon = UI.icon(disc, "", 32, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	local badge = UI.badge(disc, 24, T.sun, nil, { Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), Visible = false, ZIndex = 5 })
	local badgeIcon = UI.icon(badge, "", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 8 })

	-- speech ------------------------------------------------------------
	local B = makeBubble(stack, 10)
	local saySlot, sayPop, sayScale, sayText, who, dots, dotList = B.slot, B.pop, B.scale, B.text, B.who, B.dots, B.dotList

	m.bb, m.sc, m.tag, m.discSlot, m.disc, m.setRing, m.ringStrokes, m.icon, m.dots, m.dotList = bb, sc, tag, discSlot, disc, setRing, ringStrokes, icon, dots, dotList

	local function isStaff() return model:GetAttribute("BRole") ~= nil end
	local function refreshTag()
		local r = model:GetAttribute("BRole")
		if not r then tag.Visible = false m.staff = false return end
		m.staff = true
		local name = model:GetAttribute("BName") or model.Name
		local role, lv = tostring(r):match("^(.-)%s+LV%s*(%d+)")
		tagName.Text = name
		tagLv.Text = "LV " .. (lv or "1")
		tagRole.Text = string.upper(role or tostring(r))
		local col = model:GetAttribute("BRoleColor") or T.brand
		local deep = UI.shade(col, -0.42)
		tagLv.BackgroundColor3 = col
		if tagLv:FindFirstChild("Rim") then tagLv.Rim.Color = deep end
		for _, st in ipairs(tagLv:GetChildren()) do
			if st:IsA("UIStroke") and st.Name ~= "Rim" then st.Color = UI.shade(col, -0.45) end
		end
		tagLv.TextColor3 = T.white
		topRim.Color = col
		ribbon.BackgroundColor3 = col
		ribbonRim.Color = deep
		roleStroke.Color = deep
	end
	local function refreshStatus()
		local ic = model:GetAttribute("BIcon")
		local show = m.staff and ic ~= nil and ICON[ic] ~= nil -- round 32: guests show no status disc
		if show and not discSlot.Visible then UI.pop(disc, 0.4, 0.4) end
		discSlot.Visible = show
		icon.Image = show and ICON[ic] or ""
		local e = model:GetAttribute("BEvent")
		badge.Visible = e ~= nil and ICON[e] ~= nil
		badgeIcon.Image = e and ICON[e] or ""
	end
	local function hideSay(n)
		if m.sayN ~= n or not saySlot.Parent then return end
		local tw = UI.tween(sayScale, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw.Completed:Wait()
		if m.sayN == n then saySlot.Visible = false end
	end
	local function say(line, secs, voiceOpts)
		line = tidy(line)
		m.sayN = (m.sayN or 0) + 1
		local n = m.sayN
		local name = model:GetAttribute("BName") or model.Name
		local first = name:match("^(%S+)") or name
		who.Text = first
		local wc = model:GetAttribute("BRoleColor") or TAGS[hash(first) % #TAGS + 1]
		who.BackgroundColor3 = wc
		for _, st in ipairs(who:GetChildren()) do
			if st:IsA("UIStroke") then st.Color = UI.shade(wc, st.Name == "Rim" and -0.38 or -0.45) end
		end
		who.Visible = not m.staff -- staff already wear their name
		tintBubble(B, voiceOpts and voiceOpts.mood)
		-- fit the bubble to the line
		local w, h = fitBubble(line)
		saySlot.Size = UDim2.fromOffset(w, h)
		sayText.Text = richLine(line)
		sayText.MaxVisibleGraphemes = 0
		dots.Visible = true
		saySlot.Visible = true
		sayScale.Scale = 0.3
		sayPop.Rotation = -6
		UI.tween(sayScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.tween(sayPop, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
		local started = false
		local function start(dur)
			if started or m.sayN ~= n then return end
			started = true
			dots.Visible = false
			dur = math.clamp(dur, 0.3, 9)
			m.talkUntil = os.clock() + dur
			UI.tween(sayText, dur * 0.92, { MaxVisibleGraphemes = utf8.len(line) or #line }, Enum.EasingStyle.Linear)
			task.delay(math.max(secs or 3, dur + 1.6), hideSay, n)
		end
		voiceOpts = voiceOpts or {}
		voiceOpts.onStart = start
		Speech.speak(head, line, voiceOpts.voice or Speech.voiceFor(model), voiceOpts)
		-- never leave the dots hanging if the voice is slow
		task.delay(1.4, function() start(Speech.estimate(line)) end)
	end
	m.say = say
	local function refreshSay()
		local line = model:GetAttribute("Say")
		if not line or line == "" or model:GetAttribute("SayMode") == "think" then return end
		if hiddenAll() or model:GetAttribute("LocalTalk") then return end
		local cam = workspace.CurrentCamera
		local char = player.Character
		local from = (char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position) or (cam and cam.CFrame.Position)
		if not from then return end
		local d = (head.Position - from).Magnitude
		if d > HEAR then return end
		say(line, model:GetAttribute("SaySecs") or 3, { mood = moodOf(model), important = d < 14 })
	end
	refreshTag()
	refreshStatus()
	m.conns = {
		model:GetAttributeChangedSignal("BRole"):Connect(refreshTag),
		model:GetAttributeChangedSignal("BName"):Connect(refreshTag),
		model:GetAttributeChangedSignal("BRoleColor"):Connect(refreshTag),
		model:GetAttributeChangedSignal("BIcon"):Connect(refreshStatus),
		model:GetAttributeChangedSignal("BEvent"):Connect(refreshStatus),
		model:GetAttributeChangedSignal("SayN"):Connect(refreshSay),
		model:GetAttributeChangedSignal("LocalTalk"):Connect(function()
			if model:GetAttribute("LocalTalk") then m.sayN = (m.sayN or 0) + 1 saySlot.Visible = false end
		end),
	}
	sc.Scale = 0
	UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	return m
end

local function remove(model)
	local m = marks[model]
	marks[model] = nil
	if type(m) ~= "table" then return end
	for _, c in ipairs(m.conns) do c:Disconnect() end
	m.bb:Destroy()
end

local function add(model)
	if marks[model] or not model:IsA("Model") then return end
	marks[model] = true
	local m = build(model)
	if marks[model] ~= true then
		if m then for _, c in ipairs(m.conns) do c:Disconnect() end m.bb:Destroy() end
		return
	end
	marks[model] = m
	if m then
		table.insert(m.conns, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then remove(model) end
		end))
	end
end

CollectionService:GetInstanceAddedSignal("Bubble"):Connect(function(mm) task.spawn(add, mm) end)
CollectionService:GetInstanceRemovedSignal("Bubble"):Connect(function(mm)
	if marks[mm] == true then marks[mm] = nil return end
	remove(mm)
end)
for _, mm in ipairs(CollectionService:GetTagged("Bubble")) do task.spawn(add, mm) end

local function applyHidden()
	local off = hiddenAll()
	for _, m in pairs(marks) do
		if type(m) == "table" then m.bb.Enabled = not off end
	end
end
player:GetAttributeChangedSignal("HideBubbles"):Connect(applyHidden)
player:GetAttributeChangedSignal("Building"):Connect(applyHidden)

---------------------------------------------------------------- players talk too
-- A chat message is spoken at the sender's head in their own voice, with a bubble over them (Roblox's own chat
-- bubbles are switched off so there's only one).
local chatBubbles = {} -- character -> { bb, n }
local function playerBubble(pl, text)
	local char = pl.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local cam = workspace.CurrentCamera
	local d = cam and (head.Position - cam.CFrame.Position).Magnitude or 0
	if d > HEAR + 20 then return end
	local rec = chatBubbles[char]
	if not rec or not rec.bb.Parent then
		local bb = UI.new("BillboardGui", {
			Name = "ChatBubble", Size = UDim2.fromOffset(400, 300), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.9, 0),
			LightInfluence = 0, MaxDistance = HEAR + 20, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = head, Parent = pgui,
		})
		local stack = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
		UI.list(stack, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
		local B = makeBubble(stack, 1)
		local nm = pl.DisplayName
		B.who.Text = nm
		local wc = TAGS[hash(nm) % #TAGS + 1]
		B.who.BackgroundColor3 = wc
		for _, st in ipairs(B.who:GetChildren()) do
			if st:IsA("UIStroke") then st.Color = UI.shade(wc, st.Name == "Rim" and -0.38 or -0.45) end
		end
		rec = { bb = bb, slot = B.slot, sc = B.scale, txt = B.text, n = 0 }
		chatBubbles[char] = rec
	end
	rec.n += 1
	local n = rec.n
	local shown = #text > 140 and (text:sub(1, 137) .. "...") or text
	local w, h = fitBubble(shown)
	rec.slot.Size = UDim2.fromOffset(w, h)
	rec.txt.Text = richLine(shown)
	rec.txt.MaxVisibleGraphemes = 0
	rec.slot.Visible = true
	rec.sc.Scale = 0.3
	UI.tween(rec.sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local started = false
	local function start(dur)
		if started or rec.n ~= n then return end
		started = true
		dur = math.clamp(dur, 0.3, 10)
		UI.tween(rec.txt, dur * 0.92, { MaxVisibleGraphemes = utf8.len(shown) or #shown }, Enum.EasingStyle.Linear)
		task.delay(dur + 3, function()
			if rec.n ~= n or not rec.bb.Parent then return end
			UI.tween(rec.sc, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
			if rec.n == n then rec.slot.Visible = false end
		end)
	end
	Speech.speak(head, text, Speech.voiceFor(char), { important = pl == player or d < 16, volume = pl == player and 0.8 or 1, onStart = start, range = HEAR + 20 })
	task.delay(1.4, function() start(Speech.estimate(text)) end)
end
pcall(function()
	local cfg = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if cfg then cfg.Enabled = false end
end)
pcall(function()
	TextChatService.MessageReceived:Connect(function(msg)
		local src = msg.TextSource
		local pl = src and Players:GetPlayerByUserId(src.UserId)
		if pl and msg.Text and msg.Text ~= "" and msg.Text:sub(1, 1) ~= "/" then
			playerBubble(pl, msg.Text)
		end
	end)
end)
-- round 39: a player's worn tag (attributes Tag / TagTier, QuestServer) goes in front of their name in chat
pcall(function()
	local TAG_COL = require(Shared:WaitForChild("Quests")).TAG_COL
	TextChatService.OnIncomingMessage = function(msg)
		local src = msg.TextSource
		local pl = src and Players:GetPlayerByUserId(src.UserId)
		local tag = pl and pl:GetAttribute("Tag")
		if not tag then return nil end
		local props = Instance.new("TextChatMessageProperties")
		props.PrefixText = string.format('<font color="#%s"><b>[%s]</b></font> %s', (TAG_COL[pl:GetAttribute("TagTier") or 1] or TAG_COL[1]):ToHex(), tag, msg.PrefixText)
		return props
	end
end)

---------------------------------------------------------------- every frame: rings, the loading dots, size by distance

-- is anything solid (not a person) between the camera and this head?
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function blocked(from, head, model)
	local ignore = { model }
	if player.Character then table.insert(ignore, player.Character) end
	local to = head.Position + Vector3.new(0, 1, 0)
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = ignore
		local r = workspace:Raycast(from, to - from, rayParams)
		if not r then return false end
		local hit = r.Instance
		local mdl = hit:FindFirstAncestorOfClass("Model")
		if (mdl and mdl:FindFirstChildOfClass("Humanoid")) or hit.Transparency > 0.6 or not hit.CanQuery or (hit:IsA("BasePart") and hit.Size.Magnitude < 3) then
			table.insert(ignore, mdl and mdl:FindFirstChildOfClass("Humanoid") and mdl or hit)
		else
			return true
		end
	end
	return false
end

local function patienceColor(k)
	if k > 0.5 then return T.green end
	if k > 0.25 then return T.sun end
	return T.red
end
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cpos = cam.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, m in pairs(marks) do
		if type(m) == "table" and m.bb.Adornee then
			local d = (m.bb.Adornee.Position - cpos).Magnitude
			-- drawn on top, so hide it while a wall stands between you and them (checked a few times a second)
			if clock >= (m.nextRay or 0) then
				m.nextRay = clock + 0.2 + math.random() * 0.1
				local hidden = blocked(cpos, m.bb.Adornee, model)
				if hidden ~= m.blocked then
					m.blocked = hidden
					local want = hidden and 0 or 1
					if not hidden then m.fade.Visible = true end
					UI.tween(m.fade, 0.2, { GroupTransparency = 1 - want })
					if hidden then task.delay(0.22, function() if m.blocked then m.fade.Visible = false end end) end
				end
			end
			m.sc.Scale = math.clamp(1.14 - d / 100, 0.6, 1.05) * 0.72 -- round 21: smaller name tags
			if m.staff then
				local on = d < TAG_FAR and not model:GetAttribute("LocalTalk")
				if m.tag.Visible ~= on then m.tag.Visible = on end
			end
			if m.dots.Visible then
				for i, dd in ipairs(m.dotList) do
					dd.Position = UDim2.fromOffset((i - 1) * 16, 2 - math.max(0, math.sin(clock * 9 - i * 0.9)) * 6)
				end
			end
			if m.discSlot.Visible then
				local bar = model:GetAttribute("BBar")
				local t0, secs = model:GetAttribute("BT0"), model:GetAttribute("BSecs")
				if bar and t0 and secs and secs > 0 then
					local k = math.clamp((now - t0) / secs, 0, 1)
					if model:GetAttribute("BDrain") then k = 1 - k end
					m.setRing(k)
					local col = bar == "patience" and patienceColor(k) or BAR[bar] or T.sun
					for _, st in ipairs(m.ringStrokes) do st.Color = col end
					m.disc.Rotation = (bar == "patience" and k < 0.25) and math.sin(clock * 30) * 7 or 0
				else
					m.setRing(0)
					m.disc.Rotation = 0
				end
			end
		end
	end
end)
