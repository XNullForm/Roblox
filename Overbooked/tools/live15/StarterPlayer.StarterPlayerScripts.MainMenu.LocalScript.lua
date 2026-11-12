-- StarterPlayerScripts.MainMenu: the title screen (round 12 remake).
-- A slow cinematic camera flies over the street behind a frosted ink side panel. The panel holds the brass
-- hotel-sign logo (a bell rings in, OVERBOOKED rises, a neon HOTEL TYCOON sign flickers on) and the menu:
-- PLAY / CONTINUE, then Tutorial, Tips, Settings and Credits as rows that light up with a brass bar on hover.
-- Bottom right: your save card with your avatar's headshot, level, rooms, cash and rating. Light rays and
-- drifting dust motes float over the film. Panels slide in on the right. Playing closes a pair of hotel doors
-- over the screen, the server (Plots / Save) claims your plot and loads it, then the doors open on
-- your hotel. Tutorial plays too, then asks for the guided tutorial (Remotes.TutSkip "replay").
-- After "Reset progress" the server clears Slot and the title screen comes back.
-- Remotes.Menu: client fires ("slots") to ask for the save summary, ("play", 1) to start;
-- server fires ("slots", { [1] = { name, cash, rooms, level, stars } or nil }) back.
-- Round 12 also: the player's settings (* attributes in PREF_KEYS) are sent to the server (Remotes.Prefs)
-- whenever they change, so they save with the profile (Save restores them at join).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Menu = Shared.Remotes:WaitForChild("Menu")
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

---------------------------------------------------------------- settings sync (round 12)

do
	local PREF_KEYS = {
		"MusicVol", "SfxVol", "MusicOff", "SfxOff", "UiSfxOff", "Sprint", "HideQuests",
		"HideReviews", "HideBubbles", "HideRoomSigns", "HideDaySummary", "HidePops", "FOV",
		"ShadowsOff", "PromptSize", "LookSens", "LookInvert",
	}
	local Prefs = Shared.Remotes:WaitForChild("Prefs", 10)
	local pending = false
	local function send()
		if pending or not Prefs then return end
		pending = true
		task.delay(1.5, function()
			pending = false
			local t = {}
			for _, k in ipairs(PREF_KEYS) do
				local v = player:GetAttribute(k)
				-- a switched-off flag is sent as false so turning it back on saves too
				if v == nil and (k:find("Hide") or k:find("Off") or k == "LookInvert") then v = false end
				if v ~= nil then t[k] = v end
			end
			Prefs:FireServer(t)
		end)
	end
	for _, k in ipairs(PREF_KEYS) do player:GetAttributeChangedSignal(k):Connect(send) end
end

---------------------------------------------------------------- the title screen

-- builds and runs the whole title screen; called at join and again whenever the server sends the player back
-- to it (Reset progress clears Slot)
local running = false
local function run()
	local cons = {} -- cut when the title screen closes
	local gui
	local function teardown()
		for _, c in ipairs(cons) do c:Disconnect() end
		table.clear(cons)
		if gui then gui:Destroy() end
	end
	local old = pgui:FindFirstChild("MainMenu")
	if old then old:Destroy() end
	gui = UI.new("ScreenGui", {
		Name = "MainMenu", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 50, Parent = pgui,
	})

	---------------------------------------------------------------- other screens hide while the title is up

	local KEEP = { MainMenu = true, Toasts = true, Loading = true }
	local hidden = {}
	local function hideGui(g)
		if g:IsA("ScreenGui") and not KEEP[g.Name] and g.Enabled then
			hidden[g] = true
			g.Enabled = false
		end
	end
	for _, g in ipairs(pgui:GetChildren()) do hideGui(g) end
	local hideCon = pgui.ChildAdded:Connect(function(g) task.defer(hideGui, g) end)
	local function restoreGuis()
		hideCon:Disconnect()
		for g in pairs(hidden) do if g.Parent then g.Enabled = true end end
		table.clear(hidden)
	end

	---------------------------------------------------------------- the camera: slow shots along the street

	local SHOTS = {
		{ from = Vector3.new(-330, 60, 112), to = Vector3.new(-150, 52, 108), lookA = Vector3.new(-220, 8, 10), lookB = Vector3.new(-40, 8, 10), secs = 13 },
		{ from = Vector3.new(-60, 16, 122), to = Vector3.new(90, 16, 122), lookA = Vector3.new(20, 9, 20), lookB = Vector3.new(170, 9, 20), secs = 12 },
		{ from = Vector3.new(320, 9, 96), to = Vector3.new(320, 95, 112), lookA = Vector3.new(320, 14, 10), lookB = Vector3.new(320, 6, 10), secs = 12 },
		{ from = Vector3.new(-470, 17, 90), to = Vector3.new(-320, 22, 90), lookA = Vector3.new(-220, 6, 96), lookB = Vector3.new(-60, 6, 96), secs = 12 },
		{ from = Vector3.new(560, 40, 30), to = Vector3.new(440, 46, 112), lookA = Vector3.new(400, 8, 30), lookB = Vector3.new(330, 8, 40), secs = 13 },
	}
	local cam = workspace.CurrentCamera
	local filmOn = true
	local shotIndex, shotT = 1, 0
	local black = UI.new("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 50, Parent = gui })
	local function ease(a) return a * a * (3 - 2 * a) end
	local function streamAround(pos)
		task.spawn(function() pcall(function() player:RequestStreamAroundAsync(pos, 4) end) end)
	end
	streamAround(SHOTS[1].from)
	local filmCon = RunService.RenderStepped:Connect(function(dt)
		if not filmOn then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local s = SHOTS[shotIndex]
		shotT += dt
		local a = ease(math.clamp(shotT / s.secs, 0, 1))
		cam.FieldOfView = 52 + 4 * a -- a slow breath outwards over each shot
		cam.CFrame = CFrame.lookAt(s.from:Lerp(s.to, a), s.lookA:Lerp(s.lookB, a))
		if shotT > s.secs - 0.5 and not black:GetAttribute("Cutting") then
			black:SetAttribute("Cutting", true)
			UI.tween(black, 0.45, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			streamAround(SHOTS[shotIndex % #SHOTS + 1].from)
		end
		if shotT >= s.secs then
			shotIndex = shotIndex % #SHOTS + 1
			shotT = 0
			black:SetAttribute("Cutting", nil)
			if filmOn then UI.tween(black, 0.7, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad) end
		end
	end)

	---------------------------------------------------------------- framing: a soft vignette, light rays and dust

	local fx = UI.new("Frame", { Name = "FX", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local vig = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, Parent = fx })
	UI.grad(vig, T.shadow, T.shadow, 90).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.25, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.25),
	})
	-- two broad warm rays from the top right that sway slowly
	local rays = {}
	for i = 1, 2 do
		local r = UI.new("Frame", {
			Size = UDim2.new(0, 260 + i * 120, 2, 0), Position = UDim2.new(0.78 + i * 0.06, 0, -0.4, 0), AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(255, 220, 160), Rotation = 28 + i * 6, Parent = fx,
		})
		UI.grad(r, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 1),
		})
		rays[i] = r
	end
	-- dust motes drifting up
	local motes = {}
	local rng = Random.new()
	for i = 1, 26 do
		local s = rng:NextNumber(2, 5)
		local m = UI.new("Frame", { Size = UDim2.fromOffset(s, s), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.cream, BackgroundTransparency = 0.6, Parent = fx })
		UI.corner(m, 3)
		motes[i] = { f = m, x = rng:NextNumber(), y = rng:NextNumber(), sp = rng:NextNumber(0.01, 0.04), sway = rng:NextNumber(0, 6.28) }
	end
	table.insert(cons, RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i, r in ipairs(rays) do
			r.Rotation = 28 + i * 6 + math.sin(t * 0.25 + i) * 3
			r.BackgroundTransparency = 0.5 + 0.2 * math.sin(t * 0.4 + i * 2)
		end
		for _, m in ipairs(motes) do
			m.y -= m.sp * dt
			if m.y < -0.05 then m.y = 1.05; m.x = rng:NextNumber() end
			m.f.Position = UDim2.fromScale(m.x + math.sin(t * 0.6 + m.sway) * 0.01, m.y)
		end
	end))

	---------------------------------------------------------------- design space: 1600 x 900, stretched to the screen's shape

	local root = UI.new("Frame", { Name = "Root", Size = UDim2.fromOffset(1600, 900), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	local rootScale = UI.new("UIScale", { Name = "AutoScale", Parent = root })
	local function layout()
		local vp = cam.ViewportSize
		local k = math.min(vp.X / 1600, vp.Y / 900)
		if TOUCH then k = math.max(k, math.min(vp.X / 1100, vp.Y / 620)) end -- phones: bigger, the panel can crowd
		rootScale.Scale = k
		root.Size = UDim2.fromOffset(vp.X / k, vp.Y / k)
	end
	layout()
	table.insert(cons, cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout))

	---------------------------------------------------------------- the side panel

	local SW = 560
	-- round 14 (2026-11-09): the lobby wall. Striped cream wallpaper, a walnut wainscot and a thick trim on the edge
	local side = UI.new("Frame", { Name = "Side", Size = UDim2.new(0, SW, 1, 0), Position = UDim2.fromOffset(-SW - 12, 0), BackgroundColor3 = T.paper or T.ink, BorderSizePixel = 0, Parent = root })
	for i = 0, math.floor(SW / 36) do
		UI.new("Frame", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.fromOffset(i * 36 + 8, 0), BackgroundColor3 = T.ink3, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = side })
	end
	local wain = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 116), Position = UDim2.new(0, 0, 1, -116), BackgroundColor3 = Color3.fromRGB(122, 78, 50), BorderSizePixel = 0, Parent = side })
	UI.new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = T.outline, BorderSizePixel = 0, Parent = wain })
	UI.new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = Color3.fromRGB(176, 120, 76), BorderSizePixel = 0, Parent = wain })
	for i = 0, 4 do
		local pnl = UI.new("Frame", { Size = UDim2.new(0.2, -16, 1, -36), Position = UDim2.new(i * 0.2, 8, 0, 22), BackgroundColor3 = Color3.fromRGB(106, 66, 42), Parent = wain })
		UI.corner(pnl, 6)
		UI.stroke(pnl, 2, T.outline, 0.25)
	end
	local edge = UI.new("Frame", { Size = UDim2.new(0, 12, 1, 0), Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.outline, BorderSizePixel = 0, Parent = side })
	UI.new("Frame", { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromOffset(4, 0), BackgroundColor3 = T.gold, BorderSizePixel = 0, Parent = edge })
	local edgeShade = UI.new("Frame", { Size = UDim2.new(0, 26, 1, 0), Position = UDim2.new(1, 12, 0, 0), BackgroundColor3 = T.shadow, BorderSizePixel = 0, Parent = side })
	UI.grad(edgeShade, T.shadow, T.shadow, 0).Transparency = NumberSequence.new(0.55, 1)
	local LX = 64

	-- the logo: bell on a brass bar, OVERBOOKED with a sweeping shine, a neon HOTEL TYCOON sign
	local logo = UI.new("Frame", { Name = "Logo", Size = UDim2.fromOffset(470, 250), Position = UDim2.fromOffset(LX, 70), BackgroundTransparency = 1, Parent = side })
	local bell = UI.icon(logo, ICON.bell, 60, { Name = "Bell", ImageTransparency = 1 })
	local bellBar = UI.new("Frame", { Size = UDim2.fromOffset(0, 3), Position = UDim2.fromOffset(74, 36), BackgroundColor3 = T.gold, Parent = logo })
	UI.corner(bellBar, 2)
	local welcome = UI.label(logo, "WELCOME TO", 18, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(76, 8), Size = UDim2.fromOffset(300, 22), TextTransparency = 1 })
	local word = UI.label(logo, "OVERBOOKED", 82, { FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(-2, 58), Size = UDim2.fromOffset(500, 86), TextTransparency = 1 })
	local wordStroke = UI.textStroke(word, 5, 1)
	wordStroke.Color = T.outline
	local wordShadow = UI.label(logo, "OVERBOOKED", 82, { FontFace = UI.F.black, TextColor3 = T.outline, Position = UDim2.fromOffset(2, 64), Size = UDim2.fromOffset(500, 86), TextTransparency = 1, ZIndex = 0 })
	local wordShadowS = UI.textStroke(wordShadow, 5, 1)
	wordShadowS.Color = T.outline
	UI.grad(word, Color3.fromRGB(255, 246, 214), Color3.fromRGB(226, 160, 64), 90)
	local shineL = UI.label(logo, "OVERBOOKED", 82, { FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(-2, 58), Size = UDim2.fromOffset(500, 86), TextTransparency = 1, ZIndex = 3 })
	local shineG = UI.grad(shineL, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 20)
	shineG.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
	})
	-- a screwed-on brass room plaque (was a pink neon sign)
	local neon = UI.new("Frame", { Name = "Plaque", Size = UDim2.fromOffset(262, 46), Position = UDim2.fromOffset(6, 154), BackgroundColor3 = T.outline, BackgroundTransparency = 1, Parent = logo })
	UI.corner(neon, 10)
	local neonStroke = UI.stroke(neon, 3, T.gold, 1)
	local neonText = UI.label(neon, "HOTEL  TYCOON", 21, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(255, 222, 140), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextTransparency = 1 })
	local screws = {}
	for k, x in ipairs({ 0, 1 }) do
		local sc = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(x, x == 0 and 10 or -18, 0.5, -4), BackgroundColor3 = T.gold, BackgroundTransparency = 1, Parent = neon })
		UI.corner(sc, 4)
		screws[k] = sc
	end
	local function neonOn(k)
		neon.BackgroundTransparency = 1 - k
		neonStroke.Transparency = 1 - k
		neonText.TextTransparency = 1 - k
		for _, sc in ipairs(screws) do sc.BackgroundTransparency = 1 - k end
	end
	neonOn(0)
	local tagline = UI.label(logo, "Build it. Run it. Keep every bed full.", 19, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(2, 210), Size = UDim2.fromOffset(460, 24), TextTransparency = 1 })

	---------------------------------------------------------------- the menu

	local openPanel, start -- forward
	local busy = false
	local menu = UI.new("Frame", { Name = "Menu", Size = UDim2.fromOffset(440, 420), Position = UDim2.fromOffset(LX, 360), BackgroundTransparency = 1, Parent = side })
	local playBtn, playLabel = UI.button(menu, {
		name = "Btn_play", text = "PLAY", icon = ICON.bell, iconSize = 36, kind = "gold", size = UDim2.fromOffset(432, 82), textSize = 32, radius = 18,
		onClick = function() if not busy then start(false) end end,
	})
	playBtn.Visible = false
	-- a slow brass shimmer runs over PLAY
	local playShine = UI.new("Frame", { Size = UDim2.new(0, 90, 1, 0), Position = UDim2.new(-0.3, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, ZIndex = 4, Parent = playBtn:FindFirstChild("Face") })
	UI.grad(playShine, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1),
	})
	playBtn.Face.ClipsDescendants = true

	local rows = {}
	local selectedRow
	local function menuRow(order, id, text, sub, icon)
		local b = UI.new("TextButton", { Name = "Row_" .. id, Text = "", Size = UDim2.fromOffset(432, 64), Position = UDim2.fromOffset(0, 100 + (order - 1) * 72), BackgroundTransparency = 1, Visible = false, Parent = menu })
		local shade = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = T.shadow, BackgroundTransparency = 0.7, Parent = b })
		UI.corner(shade, 14)
		local plate = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink2, Parent = b })
		UI.corner(plate, 14)
		local st = UI.stroke(plate, 3, T.outline, 0)
		local bar = UI.new("Frame", { Size = UDim2.new(0, 4, 0, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.gold, Parent = plate })
		UI.corner(bar, 2)
		local content = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = plate })
		local TILE = { tutorial = T.blue, tips = T.gold, settings = Color3.fromRGB(150, 160, 178), credits = T.red }
		local ib = UI.new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = TILE[id] or T.gold, Parent = content })
		UI.corner(ib, 12)
		UI.stroke(ib, 2.5, T.outline, 0)
		UI.icon(ib, ICON[icon] or ICON.star, 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		local tl = UI.label(content, text, 21, { FontFace = UI.F.black, Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -110, 0, 24) })
		UI.label(content, sub, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(70, 35), Size = UDim2.new(1, -110, 0, 16) })
		local chev = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -24, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundTransparency = 1, Parent = content })
		local chevS = UI.stroke(chev, 2.5, T.muted, 0)
		chev.BorderSizePixel = 0
		-- only the top and right edges of the box show: clip a little frame
		local function light(on)
			UI.tween(bar, 0.22, { Size = UDim2.new(0, 4, on and 0.6 or 0, 0) }, Enum.EasingStyle.Back)
			UI.tween(content, 0.22, { Position = UDim2.fromOffset(on and 8 or 0, 0) })
			UI.tween(plate, 0.22, { BackgroundColor3 = on and Color3.fromRGB(255, 232, 180) or T.ink2, Position = UDim2.fromOffset(0, on and -3 or 0) })
			UI.tween(tl, 0.22, { TextColor3 = on and T.goldDk or T.cream })
			UI.tween(chevS, 0.22, { Color = on and T.goldDk or T.muted })
			UI.tween(chev, 0.22, { Position = UDim2.new(1, on and -18 or -24, 0.5, 0) })
		end
		local over = false
		b.MouseEnter:Connect(function() over = true light(true) UI.sound("Hover") end)
		b.MouseLeave:Connect(function() over = false light(selectedRow == id) end)
		b.Activated:Connect(function()
			if busy then return end
			UI.sound("Click")
			UI.pop(plate, 0.96)
			if id == "tutorial" then start(true) else openPanel(id) end
		end)
		rows[id] = { b = b, light = light, isOver = function() return over end }
		b:SetAttribute("Home", b.Position)
		return b
	end
	menuRow(1, "tutorial", "Tutorial", "Learn the ropes, step by step", "quest")
	menuRow(2, "tips", "Tips", "How to run a great hotel", "sparkle")
	menuRow(3, "settings", "Settings", "Sound, display and controls", "settings")
	menuRow(4, "credits", "Credits", "Who made Overbooked", "heart")

	local hint = UI.label(side, TOUCH and "Tap the buttons on the left in game for your hotel, staff and phone" or "In game: B to build, M for the menu, F to sit and talk", 14, {
		FontFace = UI.F.bold, TextColor3 = Color3.fromRGB(255, 232, 196), Position = UDim2.new(0, LX, 1, -52), Size = UDim2.fromOffset(440, 18), TextTransparency = 1, TextWrapped = true,
	})

	---------------------------------------------------------------- the save card (bottom right) with your avatar

	local saveCard = UI.new("CanvasGroup", { Name = "SaveCard", Size = UDim2.fromOffset(440, 150), Position = UDim2.new(1, -48, 1, -48), AnchorPoint = Vector2.new(1, 1), BackgroundColor3 = T.paper or T.ink, GroupTransparency = 1, Visible = false, Parent = root })
	UI.corner(saveCard, 22)
	UI.stroke(saveCard, 3, T.outline, 0)
	local saveTab = UI.new("Frame", { Size = UDim2.new(0, 10, 1, -40), Position = UDim2.new(1, -18, 0, 20), BackgroundColor3 = T.gold, Parent = saveCard })
	UI.corner(saveTab, 5)
	local avatarRing = UI.new("Frame", { Size = UDim2.fromOffset(104, 104), Position = UDim2.new(0, 22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = saveCard })
	UI.corner(avatarRing, 52)
	UI.grad(avatarRing, Color3.fromRGB(255, 222, 140), Color3.fromRGB(196, 126, 40), 90)
	local avatar = UI.new("ImageLabel", { Size = UDim2.fromOffset(94, 94), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.ink2, BackgroundTransparency = 0, Image = ICON.hotel, Parent = avatarRing })
	UI.corner(avatar, 47)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and img and avatar.Parent then avatar.Image = img end
	end)
	local lvlPill = UI.new("TextLabel", {
		Text = "LV 1", TextSize = 14, FontFace = UI.F.black, TextColor3 = T.ink, BackgroundColor3 = T.cream,
		Size = UDim2.fromOffset(56, 22), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0.5), Parent = avatarRing,
	})
	UI.corner(lvlPill, 11)
	UI.stroke(lvlPill, 2, Color3.fromRGB(110, 64, 18), 0)
	local hello = UI.label(saveCard, "WELCOME BACK, " .. string.upper(player.DisplayName), 13, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(146, 20), Size = UDim2.new(1, -164, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	local saveName = UI.label(saveCard, "", 26, { FontFace = UI.F.black, Position = UDim2.fromOffset(146, 40), Size = UDim2.new(1, -164, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd })
	local saveSub = UI.label(saveCard, "", 16, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(146, 76), Size = UDim2.new(1, -164, 0, 20) })
	local starRow = UI.new("Frame", { Size = UDim2.fromOffset(240, 24), Position = UDim2.fromOffset(146, 106), BackgroundTransparency = 1, Parent = saveCard })
	local starIcons = {}
	for k = 1, 5 do starIcons[k] = UI.icon(starRow, ICON.starEmpty, 22, { Position = UDim2.fromOffset((k - 1) * 25, 0) }) end
	local starText = UI.label(starRow, "", 16, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(132, 1), Size = UDim2.fromOffset(100, 22) })

	local function showSave(d)
		if d then
			playLabel.Text = "CONTINUE"
			saveName.Text = d.name or "Your hotel"
			saveSub.Text = (d.rooms or 0) .. ((d.rooms == 1) and " room" or " rooms") .. "   |   $" .. UI.commas(d.cash or 0)
			lvlPill.Text = "LV " .. tostring(d.level or 1)
			local r = d.stars
			for k = 1, 5 do starIcons[k].Image = r and k <= math.floor(r + 0.5) and ICON.star or ICON.starEmpty end
			starText.Text = r and string.format("%.1f", r) or ""
			if not r then
				for k = 1, 5 do starIcons[k].Visible = false end
				starText.Position = UDim2.fromOffset(0, 1)
				starText.Size = UDim2.fromOffset(240, 22)
				starText.Text = "No reviews yet"
			end
		else
			playLabel.Text = "OPEN YOUR HOTEL"
			hello.Text = "WELCOME, " .. string.upper(player.DisplayName)
			saveName.Text = "An empty lot"
			saveSub.Text = "Your first hotel is waiting on the street"
			lvlPill.Text = "NEW"
			for k = 1, 5 do starIcons[k].Visible = false end
			starText.Text = ""
		end
		saveCard.Visible = true
		saveCard.Position = UDim2.new(1, 20, 1, -48)
		UI.tween(saveCard, 0.7, { Position = UDim2.new(1, -48, 1, -48), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
	end

	---------------------------------------------------------------- right-hand panels

	local panels = {}
	local current
	local function makePanel(id, title, sub, icon, height)
		local wrap = UI.new("Frame", {
			Name = "P_" .. id, Size = UDim2.fromOffset(640, height), Position = UDim2.new(0.5, SW / 2, 0.5, -40), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1, Visible = false, Parent = root,
		})
		local holder, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
			name = "Panel", title = title, subtitle = sub, icon = icon, radius = 22, canvas = true,
			onClose = function() openPanel(nil) end,
		})
		local content = UI.new("Frame", { Name = "Content", Size = UDim2.new(1, -44, 1, -86), Position = UDim2.fromOffset(22, 72), BackgroundTransparency = 1, Parent = body })
		panels[id] = { wrap = wrap, holder = holder, content = content }
		return content
	end
	local function panelHome() return UDim2.new(0.5, SW / 2, 0.5, -30) end
	openPanel = function(id)
		if id == current then id = nil end
		local was = current and panels[current]
		if was then
			local w = was.wrap
			UI.tween(w, 0.22, { Position = panelHome() + UDim2.fromOffset(60, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			UI.close(was.holder, function() if current ~= w.Name:sub(3) then w.Visible = false end end)
		end
		current = id
		selectedRow = id
		for rid, r in pairs(rows) do r.light(rid == id or r.isOver()) end
		local p = id and panels[id]
		if p then
			p.wrap.Visible = true
			p.wrap.Position = panelHome() + UDim2.fromOffset(80, 0)
			UI.tween(p.wrap, 0.5, { Position = panelHome() }, Enum.EasingStyle.Quint)
			UI.open(p.holder, { from = 0.94, rise = 0 })
			UI.stagger(p.list or p.content, 0.04)
			UI.tween(saveCard, 0.3, { GroupTransparency = 0.85 })
		else
			UI.tween(saveCard, 0.3, { GroupTransparency = 0 })
		end
	end

	-- tips
	local TIPS = {
		{ icon = "bell", head = "Sit at the desk", text = "Guests check in and out at the front desk. Sit in its chair (F) to serve them." },
		{ icon = "clean", head = "Clean up", text = "When a guest leaves, the room needs cleaning before the next one." },
		{ icon = "hammer", head = "Build", text = "Rooms, furniture and decor. Click and drag to lay whole rows of walls." },
		{ icon = "chat", head = "Talk to guests", text = "What you say depends on what they're doing, and it changes their mood." },
		{ icon = "staff", head = "Hire staff", text = "Janitors clean, a doorman lets guests in, a receptionist runs the desk." },
		{ icon = "star", head = "Earn stars", text = "Nice rooms and a lovely lobby bring more stars and more guests." },
		{ icon = "guest", head = "Familiar faces", text = "Your Roblox friends might turn up and check in as guests." },
		{ icon = "research", head = "Research", text = "Unlock new furniture, upgrades and special guests." },
		{ icon = "coop", head = "Play together", text = "Invite friends from the menu to help run your hotel." },
		{ icon = "phone", head = "Your phone", text = "Messages, reviews and daily reports, all in your pocket." },
	}
	local tipsC = makePanel("tips", "Tips", "How to run a great hotel", ICON.sparkle, 640)
	local tipsScroll = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.gold, Parent = tipsC,
	})
	UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -7, 0, 108), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tipsScroll })
	panels.tips.list = tipsScroll
	for i, tip in ipairs(TIPS) do
		local f = UI.new("Frame", { BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = tipsScroll })
		UI.corner(f, 16)
		UI.stroke(f, 1.5, T.line, 0.45)
		local ib = UI.new("Frame", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.ink, Parent = f })
		UI.corner(ib, 13)
		UI.icon(ib, ICON[tip.icon] or ICON.star, 34, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		UI.label(f, tip.head, 18, { FontFace = UI.F.black, Position = UDim2.fromOffset(72, 14), Size = UDim2.new(1, -84, 0, 22) })
		UI.label(f, tip.text, 13, {
			FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -84, 1, -44),
		})
	end

	-- settings (the same player attributes as the in-game Settings page; they save with your profile)
	local setC = makePanel("settings", "Settings", "Saved with your profile", ICON.settings, 620)
	local setScroll = UI.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4, ScrollBarImageColor3 = T.gold, Parent = setC,
	})
	UI.list(setScroll, nil, 10)
	UI.pad(setScroll, 0, 2, 8, 6)
	panels.settings.list = setScroll
	local function settingBase(order, icon, text, sub)
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = setScroll })
		UI.corner(f, 16)
		UI.stroke(f, 1.5, T.line, 0.45)
		local ib = UI.new("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink, Parent = f })
		UI.corner(ib, 12)
		UI.icon(ib, ICON[icon] or ICON.settings, 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		UI.label(f, text, 18, { FontFace = UI.F.black, Position = UDim2.fromOffset(72, 12), Size = UDim2.new(1, -300, 0, 22) })
		UI.label(f, sub, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(72, 36), Size = UDim2.new(1, -300, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		return f
	end
	local function toggleRow(order, icon, text, sub, on, cb)
		local f = settingBase(order, icon, text, sub)
		UI.toggle(f, on, cb, { pos = UDim2.new(1, -16, 0.5, 0), anchor = Vector2.new(1, 0.5) })
	end
	local function rangeRow(order, icon, text, sub, min, max, step, value, fmt, cb)
		local f = settingBase(order, icon, text, sub)
		local num = UI.label(f, fmt(value), 15, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(50, 20) })
		UI.slider(f, min, max, value, function(v) num.Text = fmt(v) cb(v) end, { size = UDim2.fromOffset(190, 28), pos = UDim2.new(1, -72, 0.5, 0), step = step }).AnchorPoint = Vector2.new(1, 0.5)
	end
	local function pct(v) return math.floor(v + 0.5) .. "%" end
	local function vol(attr, offAttr)
		local v = player:GetAttribute(attr)
		if v == nil then v = player:GetAttribute(offAttr) and 0 or 100 end
		return v
	end
	rangeRow(1, "bell", "Music", "The hotel's background music", 0, 100, 5, vol("MusicVol", "MusicOff"), pct, function(v)
		player:SetAttribute("MusicVol", v)
		player:SetAttribute("MusicOff", v <= 0 or nil)
	end)
	rangeRow(2, "sparkle", "Sound effects", "Bells, cash, doors and footsteps", 0, 100, 5, vol("SfxVol", "SfxOff"), pct, function(v)
		player:SetAttribute("SfxVol", v)
		player:SetAttribute("SfxOff", v <= 0 or nil)
	end)
	toggleRow(3, "chat", "Menu sounds", "Clicks and whooshes on buttons", player:GetAttribute("UiSfxOff") ~= true, function(on) player:SetAttribute("UiSfxOff", not on or nil) end)
	if player:GetAttribute("Sprint") == nil then player:SetAttribute("Sprint", true) end
	toggleRow(4, "walk", "Sprint", "Hold Shift to run", player:GetAttribute("Sprint") ~= false, function(on) player:SetAttribute("Sprint", on) end)
	rangeRow(5, "search", "Field of view", "How wide the camera sees", 55, 100, 1, player:GetAttribute("FOV") or 70, function(v) return tostring(math.floor(v + 0.5)) end, function(v) player:SetAttribute("FOV", v) end)
	toggleRow(6, "sun", "Shadows", "Turn off for a smoother game on slow devices", player:GetAttribute("ShadowsOff") ~= true, function(on) player:SetAttribute("ShadowsOff", not on or nil) end)
	rangeRow(7, "bell", "Button size", "The size of the buttons over things", 60, 140, 5, player:GetAttribute("PromptSize") or 100, pct, function(v) player:SetAttribute("PromptSize", v) end)
	toggleRow(8, "cash", "Money pop-ups", "+$ and XP numbers that float up", player:GetAttribute("HidePops") ~= true, function(on) player:SetAttribute("HidePops", not on or nil) end)
	rangeRow(9, "rotate", "Build camera speed", "How fast the build camera turns", 25, 200, 5, player:GetAttribute("LookSens") or 100, pct, function(v) player:SetAttribute("LookSens", v) end)
	UI.label(setScroll, "More settings are in the game menu.", 13, { FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 22) })

	-- credits
	local credC = makePanel("credits", "Credits", "Thanks for checking in", ICON.heart, 420)
	UI.list(credC, nil, 10)
	panels.credits.list = credC
	for i, c in ipairs({
		{ "hotel", "Overbooked", "A hotel tycoon about running the desk, cleaning up and building the place of your dreams." },
		{ "hammer", "Made with", "Roblox Studio and Blender. Every model, icon and sound picked for this game." },
		{ "heart", "You", "Thanks for playing. Invite your friends: they might even end up as your guests." },
	}) do
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = credC })
		UI.corner(f, 16)
		UI.stroke(f, 1.5, T.line, 0.45)
		local ib = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink, Parent = f })
		UI.corner(ib, 14)
		UI.icon(ib, ICON[c[1]], 36, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		UI.label(f, c[2], 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(80, 14), Size = UDim2.new(1, -96, 0, 22) })
		UI.label(f, c[3], 14, { FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(80, 40), Size = UDim2.new(1, -96, 0, 40) })
	end

	---------------------------------------------------------------- the doors: the trip into the game

	local doors = UI.new("Frame", { Name = "Doors", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Visible = false, Parent = gui })
	local function doorPanel(left)
		local d = UI.new("Frame", {
			Size = UDim2.fromScale(0.5, 1), Position = left and UDim2.fromScale(-0.5, 0) or UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 60, Parent = doors,
		})
		UI.grad(d, Color3.fromRGB(96, 58, 44), Color3.fromRGB(46, 26, 22), left and 0 or 180)
		-- two raised panes and a brass handle
		for k = 0, 1 do
			local pane = UI.new("Frame", { Size = UDim2.new(0.7, 0, 0.36, 0), Position = UDim2.new(0.15, 0, 0.08 + k * 0.46, 0), BackgroundColor3 = Color3.fromRGB(70, 42, 34), ZIndex = 61, Parent = d })
			UI.corner(pane, 10)
			UI.stroke(pane, 3, Color3.fromRGB(130, 86, 60), 0.2)
		end
		local handle = UI.new("Frame", { Size = UDim2.fromOffset(14, 90), Position = left and UDim2.new(1, -36, 0.5, 0) or UDim2.new(0, 22, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 62, Parent = d })
		UI.corner(handle, 7)
		UI.grad(handle, Color3.fromRGB(255, 226, 150), T.goldDk, 0)
		return d
	end
	local doorL, doorR = doorPanel(true), doorPanel(false)
	local doorSign = UI.label(doors, "WELCOME", 46, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 0.5, -28), TextTransparency = 1, ZIndex = 63 })
	UI.textStroke(doorSign, 4, 1).Color = Color3.fromRGB(40, 22, 8)
	local function closeDoors()
		doors.Visible = true
		UI.tween(doorL, 0.55, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		UI.tween(doorR, 0.55, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		task.delay(0.45, function()
			UI.sound("Door")
			UI.tween(doorSign, 0.3, { TextTransparency = 0 })
			local st = doorSign:FindFirstChildOfClass("UIStroke")
			if st then UI.tween(st, 0.3, { Transparency = 0 }) end
		end)
	end
	local function openDoors()
		UI.tween(doorSign, 0.2, { TextTransparency = 1 })
		local st = doorSign:FindFirstChildOfClass("UIStroke")
		if st then UI.tween(st, 0.2, { Transparency = 1 }) end
		UI.tween(doorL, 0.8, { Position = UDim2.fromScale(-0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		return UI.tween(doorR, 0.8, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
	end

	---------------------------------------------------------------- the intro

	task.spawn(function()
		UI.tween(black, 1.4, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		UI.tween(side, 0.8, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
		task.wait(0.45)
		local bsc = UI.scaleOf(bell)
		bsc.Scale = 1.8
		bell.Rotation = -30
		UI.tween(bell, 0.35, { ImageTransparency = 0 })
		UI.tween(bsc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.tween(bell, 0.5, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		task.wait(0.2)
		UI.sound("Bell")
		UI.tween(bellBar, 0.5, { Size = UDim2.fromOffset(260, 3) }, Enum.EasingStyle.Quint)
		UI.tween(welcome, 0.5, { TextTransparency = 0 })
		task.wait(0.15)
		word.Position = UDim2.fromOffset(-2, 90)
		wordShadow.Position = UDim2.fromOffset(2, 96)
		UI.tween(word, 0.6, { TextTransparency = 0, Position = UDim2.fromOffset(-2, 58) }, Enum.EasingStyle.Back)
		UI.tween(wordShadow, 0.6, { TextTransparency = 0, Position = UDim2.fromOffset(2, 65) }, Enum.EasingStyle.Back)
		UI.tween(wordStroke, 0.6, { Transparency = 0 })
		UI.tween(wordShadowS, 0.6, { Transparency = 0 })
		task.wait(0.5)
		-- the plaque swings down onto its screws
		neon.Rotation = -14
		neon.Position = UDim2.fromOffset(6, 128)
		for _, k in ipairs({ 0.35, 0.7, 1 }) do neonOn(k) task.wait(0.03) end
		UI.tween(neon, 0.7, { Rotation = 0, Position = UDim2.fromOffset(6, 154) }, Enum.EasingStyle.Elastic)
		UI.sound("Place")
		UI.tween(tagline, 0.5, { TextTransparency = 0 })
		-- the menu arrives row by row
		playBtn.Visible = true
		playBtn.Position = UDim2.fromOffset(-40, 0)
		UI.tween(playBtn, 0.55, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
		UI.pop(playBtn, 0.85)
		for _, id in ipairs({ "tutorial", "tips", "settings", "credits" }) do
			task.wait(0.07)
			local b = rows[id].b
			b.Visible = true
			local home = b:GetAttribute("Home")
			b.Position = home - UDim2.fromOffset(50, 0)
			UI.tween(b, 0.5, { Position = home }, Enum.EasingStyle.Back)
		end
		UI.tween(hint, 0.6, { TextTransparency = 0.2 })
		-- the shine sweeps the logo and PLAY now and then; the neon blinks once in a while
		local n = 0
		while gui.Parent do
			shineL.TextTransparency = 0
			shineG.Offset = Vector2.new(-1, 0)
			UI.tween(shineG, 1.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			playShine.Position = UDim2.new(-0.3, 0, 0, 0)
			UI.tween(playShine, 1.1, { Position = UDim2.new(1.2, 0, 0, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0.4)
			task.wait(1.3)
			shineL.TextTransparency = 1
			n += 1
			if n % 2 == 0 then
				UI.tween(neon, 0.15, { Rotation = -3 }) task.wait(0.15) UI.tween(neon, 0.9, { Rotation = 0 }, Enum.EasingStyle.Elastic)
			end
			task.wait(4.2)
		end
	end)

	---------------------------------------------------------------- start playing

	start = function(withTutorial)
		if busy then return end
		busy = true
		UI.sound("Bell")
		openPanel(nil)
		Menu:FireServer("play", 1)
		closeDoors()
		task.wait(0.7)
		filmOn = false
		filmCon:Disconnect()
		local t0 = os.clock()
		while os.clock() - t0 < 8 and not (player:GetAttribute("Slot") and player:GetAttribute("Plot")) do task.wait(0.1) end
		task.wait(0.6) -- the server moves the character to the plot
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		cam.CameraType = Enum.CameraType.Custom
		if hum then cam.CameraSubject = hum end
		cam.FieldOfView = player:GetAttribute("FOV") or 70
		for _, f in ipairs({ root, fx }) do f.Visible = false end
		black.BackgroundTransparency = 1
		restoreGuis()
		if withTutorial then
			task.spawn(function()
				local t1 = os.clock()
				while not player:GetAttribute("Loaded") and os.clock() - t1 < 15 do task.wait(0.2) end
				Shared.Remotes.TutSkip:FireServer("replay")
			end)
		end
		openDoors().Completed:Connect(function() teardown() end)
	end

	table.insert(cons, Menu.OnClientEvent:Connect(function(action, data)
		if action ~= "slots" or player:GetAttribute("Slot") then return end
		showSave(type(data) == "table" and data[1] or nil)
	end))
	Menu:FireServer("slots")

	-- if something else starts the game (tests, a co-op move), get out of the way
	table.insert(cons, player:GetAttributeChangedSignal("Slot"):Connect(function()
		if player:GetAttribute("Slot") and not busy then
			busy = true
			filmOn = false
			filmCon:Disconnect()
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			if hum then cam.CameraSubject = hum end
			cam.FieldOfView = player:GetAttribute("FOV") or 70
			restoreGuis()
			teardown()
		end
	end))
end

local function maybeRun()
	if running or player:GetAttribute("Slot") then return end
	running = true
	run()
end
maybeRun()
player:GetAttributeChangedSignal("Slot"):Connect(function()
	if not player:GetAttribute("Slot") then
		task.defer(maybeRun)
	else
		running = false
	end
end)
