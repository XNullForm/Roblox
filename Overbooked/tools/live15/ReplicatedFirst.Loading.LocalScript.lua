-- ReplicatedFirst.Loading (round 12 remake): the loading screen. Self-contained (it runs before
-- ReplicatedStorage has arrived), so it builds its own UI in the house style: ink navy, cream and brass.
-- A hotel at night: stars twinkle, the moon glows, and as the game loads the hotel's windows light up one by one
-- (the percentage sits on a brass plaque over the door). An OVERBOOKED neon sign flickers on over the roof, the
-- street lamps glow and little chores tick by underneath with a tip card. When everything's in (and at least
-- MIN_SECS has passed) every window flashes on, the front doors swing open and the screen pushes in through
-- them onto the title screen, which is already running underneath.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local MIN_SECS = 3.6
local MAX_SECS = 25
local FAMILY = "rbxasset://fonts/families/FredokaOne.json" -- round 14: the house fonts (FredokaOne heads, Nunito body)
local BODY = "rbxasset://fonts/families/Nunito.json"
local OUTLINE = Color3.fromRGB(78, 50, 34)
local PAPER = Color3.fromRGB(255, 249, 236)
local WALNUT = Color3.fromRGB(64, 42, 30)
local INK = Color3.fromRGB(22, 25, 38)
local INK2 = Color3.fromRGB(32, 36, 54)
local CREAM = Color3.fromRGB(250, 244, 232)
local MUTED = Color3.fromRGB(168, 172, 196)
local GOLD = Color3.fromRGB(232, 190, 106)
local GOLD_DK = Color3.fromRGB(176, 128, 52)
local WARM = Color3.fromRGB(255, 214, 128)
local BELL = "rbxassetid://136771114946336"

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r), Parent = o }) end
local function grad(o, a, b, rot) return new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = o }) end
local function tween(o, t, props, style, dir, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end
local function font(w) return Font.new(FAMILY, w) end
local function label(parent, text, size, props)
	local l = new("TextLabel", { Text = text, TextSize = size, FontFace = font(Enum.FontWeight.Bold), TextColor3 = CREAM, BackgroundTransparency = 1, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local gui = new("ScreenGui", { Name = "Loading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ScreenInsets = Enum.ScreenInsets.None, Parent = pgui })
local canvas = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })

---------------------------------------------------------------- the night sky

local sky = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = canvas })
grad(sky, Color3.fromRGB(44, 56, 118), Color3.fromRGB(248, 156, 118), 90) -- dusk, not midnight
-- a warm glow rising off the street
local glow = new("Frame", { Size = UDim2.fromScale(1, 0.55), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromRGB(255, 150, 90), Parent = canvas })
new("UIGradient", { Transparency = NumberSequence.new(1, 0.72), Rotation = 90, Parent = glow })
-- stars
local rng = Random.new(7)
local stars = {}
for i = 1, 70 do
	local s = rng:NextNumber(2, 4.5)
	local st = new("Frame", {
		Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber() * 0.6), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = CREAM, BackgroundTransparency = 0.3, Parent = canvas,
	})
	corner(st, UDim.new(0.5, 0))
	stars[i] = { f = st, phase = rng:NextNumber(0, math.pi * 2), speed = rng:NextNumber(0.8, 2.4), base = rng:NextNumber(0.1, 0.5) }
end
-- the moon and its halo
local moon = new("Frame", { Size = UDim2.fromOffset(110, 110), Position = UDim2.new(0.82, 0, 0.17, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 246, 222), Parent = canvas })
corner(moon, UDim.new(0.5, 0))
local halo = new("Frame", { Size = UDim2.fromOffset(320, 320), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 236, 190), ZIndex = 0, Parent = moon })
corner(halo, UDim.new(0.5, 0))
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) }), Parent = halo }).Rotation = 0
local haloG = halo:FindFirstChildOfClass("UIGradient")
haloG.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) })
-- a full moon: soft shading and a few faint craters (a sky-coloured "bite" showed its edge against the gradient)
new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 214, 190)), Rotation = 50, Parent = moon })
for _, c in ipairs({ { 0.32, 0.36, 22 }, { 0.62, 0.3, 14 }, { 0.55, 0.64, 26 }, { 0.28, 0.7, 10 }, { 0.76, 0.56, 9 } }) do
	local cr = new("Frame", { Size = UDim2.fromOffset(c[3], c[3]), Position = UDim2.fromScale(c[1], c[2]), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(214, 200, 172), BackgroundTransparency = 0.45, Parent = moon })
	corner(cr, UDim.new(0.5, 0))
end
moon.ClipsDescendants = false

---------------------------------------------------------------- the hotel, in a 1600 x 900 design box

local box = new("Frame", { Size = UDim2.fromOffset(1600, 900), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = canvas })
local boxScale = new("UIScale", { Parent = box })
local cam = workspace.CurrentCamera
local zoom = 1
local function fit()
	local vp = cam.ViewportSize
	boxScale.Scale = math.max(vp.X / 1600, vp.Y / 900) * zoom
end
fit()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- distant skyline silhouettes
for i, b in ipairs({ { 0, 300, 170 }, { 150, 220, 120 }, { 1150, 260, 150 }, { 1330, 340, 190 }, { 1480, 230, 140 }, { 260, 180, 90 } }) do
	local f = new("Frame", { Size = UDim2.fromOffset(b[3], b[2]), Position = UDim2.fromOffset(b[1], 760 - b[2]), BackgroundColor3 = Color3.fromRGB(96, 74, 120), Parent = box })
	corner(f, 6)
	for k = 1, 5 do
		new("Frame", {
			Size = UDim2.fromOffset(10, 12), Position = UDim2.fromOffset(rng:NextInteger(10, b[3] - 20), rng:NextInteger(16, b[2] - 30)),
			BackgroundColor3 = WARM, BackgroundTransparency = rng:NextNumber(0.3, 0.8), Parent = f,
		})
	end
	f.ZIndex = 1
end

-- the street
local street = new("Frame", { Size = UDim2.fromOffset(1600, 160), Position = UDim2.fromOffset(0, 760), BackgroundColor3 = Color3.fromRGB(30, 28, 44), Parent = box })
grad(street, Color3.fromRGB(96, 90, 108), Color3.fromRGB(62, 58, 74), 90)
new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(214, 192, 168), Parent = street })
new("Frame", { Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 22), BackgroundColor3 = OUTLINE, Parent = street })

-- the hotel
local HX, HW, HH = 800, 600, 470
local hotel = new("Frame", { Size = UDim2.fromOffset(HW, HH), Position = UDim2.fromOffset(HX, 760), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = box })
grad(hotel, Color3.fromRGB(240, 196, 148), Color3.fromRGB(204, 140, 100), 90)
corner(hotel, 8)
new("UIStroke", { Thickness = 5, Color = OUTLINE, Parent = hotel })
-- brick courses
for k = 1, 22 do
	new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, k * 21), BackgroundColor3 = Color3.fromRGB(180, 118, 84), BackgroundTransparency = 0.55, ZIndex = 2, Parent = hotel })
end
-- a cornice and a roof ledge
local ledge = new("Frame", { Size = UDim2.fromOffset(HW + 40, 26), Position = UDim2.new(0.5, 0, 0, -12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(110, 80, 70), ZIndex = 3, Parent = hotel })
corner(ledge, 6)
grad(ledge, Color3.fromRGB(196, 126, 86), Color3.fromRGB(150, 90, 60), 90)
new("UIStroke", { Thickness = 4, Color = OUTLINE, Parent = ledge })
for k = 0, 1 do
	new("Frame", { Size = UDim2.fromOffset(HW, 10), Position = UDim2.fromOffset(0, 150 + k * 140), BackgroundColor3 = Color3.fromRGB(150, 96, 66), ZIndex = 2, Parent = hotel })
end

-- the windows: 6 x 4 grid; each lights up as loading goes on
local windows = {}
local COLS, ROWS = 6, 4
local WW, WH = 58, 66
local gapX = (HW - 60 - COLS * WW) / (COLS - 1)
for r = 1, ROWS do
	for c = 1, COLS do
		local x = 30 + (c - 1) * (WW + gapX)
		local y = 42 + (r - 1) * 80
		local frame = new("Frame", { Size = UDim2.fromOffset(WW, WH), Position = UDim2.fromOffset(x, y), BackgroundColor3 = Color3.fromRGB(70, 66, 104), ZIndex = 3, Parent = hotel })
		corner(frame, 8)
		new("UIStroke", { Thickness = 3.5, Color = OUTLINE, Parent = frame })
		local sill = new("Frame", { Size = UDim2.new(1, 12, 0, 8), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = PAPER, ZIndex = 6, Parent = frame })
		corner(sill, 3)
		new("UIStroke", { Thickness = 2.5, Color = OUTLINE, Parent = sill })
		local lit = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = frame })
		corner(lit, 6)
		grad(lit, Color3.fromRGB(255, 236, 170), Color3.fromRGB(240, 150, 70), 90)
		-- a cross bar and a curtain edge so they read as windows
		new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = OUTLINE, ZIndex = 5, Parent = frame })
		new("Frame", { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = OUTLINE, ZIndex = 5, Parent = frame })
		local shine = new("Frame", { Size = UDim2.fromOffset(WW + 26, WH + 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WARM, BackgroundTransparency = 1, ZIndex = 2, Parent = frame })
		corner(shine, 16)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) }), Parent = shine })
		table.insert(windows, { lit = lit, shine = shine, on = false })
	end
end
-- shuffled, so they light up all over the building
for i = #windows, 2, -1 do
	local j = rng:NextInteger(1, i)
	windows[i], windows[j] = windows[j], windows[i]
end

-- the entrance: an awning, a brass plaque with the percentage, and two doors
local door = new("Frame", { Size = UDim2.fromOffset(150, 120), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 150), ZIndex = 3, Parent = hotel })
grad(door, Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 180, 90), 90)
local doorL = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.fromRGB(70, 40, 34), ZIndex = 4, Parent = door })
local doorR = new("Frame", { Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(70, 40, 34), ZIndex = 4, Parent = door })
for _, d in ipairs({ doorL, doorR }) do
	grad(d, Color3.fromRGB(110, 66, 50), Color3.fromRGB(58, 32, 28), 0)
	new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(30, 16, 14), Parent = d })
	local pane = new("Frame", { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 12), BackgroundColor3 = WARM, BackgroundTransparency = 0.25, ZIndex = 5, Parent = d })
	corner(pane, 4)
end
new("Frame", { Size = UDim2.fromOffset(6, 22), Position = UDim2.new(1, -12, 0.55, 0), BackgroundColor3 = GOLD, ZIndex = 6, Parent = doorL })
new("Frame", { Size = UDim2.fromOffset(6, 22), Position = UDim2.new(0, 6, 0.55, 0), BackgroundColor3 = GOLD, ZIndex = 6, Parent = doorR })
local awning = new("Frame", { Size = UDim2.fromOffset(230, 34), Position = UDim2.new(0.5, 0, 1, -126), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(176, 40, 54), ZIndex = 5, Parent = hotel })
corner(awning, 8)
new("UIStroke", { Thickness = 4, Color = OUTLINE, Parent = awning })
local stripesA = new("UIGradient", { Parent = awning })
do
	local kps = {}
	for k = 0, 9 do
		local a = k / 10
		local col = k % 2 == 0 and Color3.fromRGB(196, 46, 60) or Color3.fromRGB(250, 236, 220)
		table.insert(kps, ColorSequenceKeypoint.new(a, col))
		table.insert(kps, ColorSequenceKeypoint.new(k == 9 and 1 or a + 0.0999, col))
	end
	stripesA.Color = ColorSequence.new(kps)
end
local plaque = new("Frame", { Size = UDim2.fromOffset(150, 46), Position = UDim2.new(0.5, 0, 1, -168), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6, Parent = hotel })
corner(plaque, 10)
grad(plaque, Color3.fromRGB(255, 226, 150), GOLD_DK, 90)
new("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(110, 64, 18), Parent = plaque })
local pct = label(plaque, "0%", 28, { FontFace = font(Enum.FontWeight.Heavy), TextColor3 = Color3.fromRGB(60, 34, 10), Size = UDim2.fromScale(1, 1), ZIndex = 7 })

-- street lamps either side
local lamps = {}
for _, x in ipairs({ HX - HW / 2 - 90, HX + HW / 2 + 90 }) do
	local post = new("Frame", { Size = UDim2.fromOffset(8, 190), Position = UDim2.fromOffset(x, 760), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(20, 18, 30), ZIndex = 3, Parent = box })
	local head = new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, 0, 0, -18), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = WARM, ZIndex = 4, Parent = post })
	corner(head, UDim.new(0.5, 0))
	-- a soft glow: rings that get stronger towards the bulb (a gradient on a disc read as a flat band)
	local rings = {}
	for k, d in ipairs({ 230, 170, 118, 74 }) do
		local r = new("Frame", { Size = UDim2.fromOffset(d, d), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WARM, BackgroundTransparency = 1, ZIndex = 1, Parent = head })
		corner(r, UDim.new(0.5, 0))
		rings[k] = r
	end
	table.insert(lamps, { head = head, rings = rings })
end

-- the neon sign on the roof
local sign = new("Frame", { Size = UDim2.fromOffset(700, 150), Position = UDim2.fromOffset(HX, 760 - HH - 22), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = box })
local word = label(sign, "OVERBOOKED", 118, { FontFace = font(Enum.FontWeight.Heavy), TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), TextTransparency = 1, ZIndex = 7 })
grad(word, Color3.fromRGB(255, 246, 214), Color3.fromRGB(226, 160, 64), 90)
local ws = new("UIStroke", { Thickness = 7, Color = OUTLINE, Transparency = 1, Parent = word })
local wordGlow = label(sign, "OVERBOOKED", 118, { FontFace = font(Enum.FontWeight.Heavy), TextColor3 = WARM, Size = UDim2.fromScale(1, 1), TextTransparency = 1, ZIndex = 6 })
local wgs = new("UIStroke", { Thickness = 7, Color = Color3.fromRGB(255, 170, 70), Transparency = 1, Parent = wordGlow })
local bell = new("ImageLabel", { Image = BELL, Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, -50), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ImageTransparency = 1, ZIndex = 7, Parent = sign })
-- a brass plaque under the name (it was a pink neon line)
local tag = label(sign, "HOTEL  TYCOON", 22, { FontFace = font(Enum.FontWeight.Heavy), TextColor3 = Color3.fromRGB(255, 222, 140), BackgroundColor3 = OUTLINE, BackgroundTransparency = 1,
	Size = UDim2.fromOffset(270, 38), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 0), TextTransparency = 1, ZIndex = 7 })
corner(tag, 10)
local tagS = new("UIStroke", { Thickness = 3, Color = GOLD, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tag })

---------------------------------------------------------------- status line and tip card (screen space, bottom)

local foot = new("Frame", { Size = UDim2.fromOffset(820, 120), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = canvas })
local footScale = new("UIScale", { Parent = foot })
local function fitFoot()
	local vp = cam.ViewportSize
	footScale.Scale = math.clamp(math.min(vp.X / 1500, vp.Y / 860), 0.5, 1.15)
end
fitFoot()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fitFoot)
local status = label(foot, "Unlocking the front door", 24, { FontFace = font(Enum.FontWeight.Heavy), Size = UDim2.new(1, 0, 0, 28) })
new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = status })
local barBack = new("Frame", { Size = UDim2.new(0.62, 0, 0, 16), Position = UDim2.new(0.19, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(96, 64, 46), Parent = foot })
corner(barBack, 8)
new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = barBack })
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barBack })
corner(barFill, 8)
grad(barFill, Color3.fromRGB(255, 226, 120), Color3.fromRGB(240, 150, 40), 90)
local barShine = new("Frame", { Size = UDim2.new(1, -8, 0, 4), Position = UDim2.fromOffset(4, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, Parent = barFill })
corner(barShine, 2)
local tipCard = new("Frame", { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, 62), BackgroundColor3 = PAPER, Parent = foot })
corner(tipCard, 16)
new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = tipCard })
local tipShade = new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = Color3.fromRGB(58, 36, 24), BackgroundTransparency = 0.6, ZIndex = 0, Parent = tipCard })
corner(tipShade, 16)
local tipHead = label(tipCard, "TIP", 15, { FontFace = font(Enum.FontWeight.Heavy), TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(250, 186, 56), Size = UDim2.fromOffset(48, 28), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
corner(tipHead, 9)
new("UIStroke", { Thickness = 2.5, Color = OUTLINE, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tipHead })
local tip = label(tipCard, "", 17, { FontFace = Font.new(BODY, Enum.FontWeight.Bold), TextColor3 = WALNUT, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(76, 0), Size = UDim2.new(1, -92, 1, 0), TextWrapped = true })

foot.ZIndex = 30
for _, d in ipairs(foot:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 30 end end

local CHORES = {
	"Unlocking the front door", "Fluffing the pillows", "Polishing the lobby floor", "Waking up the staff",
	"Folding the towels", "Watering the plants", "Ringing the desk bell", "Counting the room keys", "Switching on the lights",
}
local TIPS = {
	"Sit at the front desk to check guests in and out.",
	"A dirty room can't be booked. Clean it fast to keep the line moving.",
	"In build mode, click and drag to lay a whole row of walls at once.",
	"Fun things in the lobby keep guests happy and bring better reviews.",
	"Talk to guests: what you say changes their mood and their review.",
	"Sit on any chair or sofa with F. Guests use them too.",
	"Hold right mouse in build mode to turn the camera.",
	"Your friends might check in as guests!",
}

---------------------------------------------------------------- the intro

task.spawn(function()
	tween(bell, 0.5, { ImageTransparency = 0, Position = UDim2.new(0.5, 0, 0, -60) }, Enum.EasingStyle.Back)
	task.wait(0.3)
	-- the neon stutters on
	for _, k in ipairs({ 0.6, 0, 0.85, 0.15, 1, 0.4, 1 }) do
		word.TextTransparency = 1 - k
		ws.Transparency = 1 - k
		wordGlow.TextTransparency = 1 - 0.25 * k
		wgs.Transparency = 1 - 0.22 * k
		task.wait(0.05 + math.random() * 0.06)
	end
	task.wait(0.15)
	tag.Rotation = -12
	for _, k in ipairs({ 0.4, 0.8, 1 }) do
		tag.TextTransparency = 1 - k
		tag.BackgroundTransparency = 1 - k
		tagS.Transparency = 1 - k
		task.wait(0.03)
	end
	tween(tag, 0.8, { Rotation = 0 }, Enum.EasingStyle.Elastic)
end)

---------------------------------------------------------------- per frame: stars, lamps, a gentle push-in

-- round 14: guests with suitcases stroll in through the door, and cars go by
local walkers, cars = {}, {}
local SHIRTS = { Color3.fromRGB(240, 108, 84), Color3.fromRGB(86, 170, 232), Color3.fromRGB(122, 200, 92), Color3.fromRGB(176, 120, 222), Color3.fromRGB(250, 190, 64), Color3.fromRGB(236, 120, 170) }
local SKINS = { Color3.fromRGB(255, 214, 170), Color3.fromRGB(226, 170, 120), Color3.fromRGB(170, 112, 76), Color3.fromRGB(110, 70, 50) }
local function walker()
	local fromLeft = rng:NextNumber() < 0.5
	local p = new("Frame", { Size = UDim2.fromOffset(30, 62), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, ZIndex = 8, Parent = box })
	local body = new("Frame", { Size = UDim2.fromOffset(22, 30), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = SHIRTS[rng:NextInteger(1, #SHIRTS)], ZIndex = 9, Parent = p })
	corner(body, 8)
	new("UIStroke", { Thickness = 2.5, Color = OUTLINE, Parent = body })
	local head = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = SKINS[rng:NextInteger(1, #SKINS)], ZIndex = 10, Parent = p })
	corner(head, UDim.new(0.5, 0))
	new("UIStroke", { Thickness = 2.5, Color = OUTLINE, Parent = head })
	local legs = {}
	for k = 0, 1 do
		legs[k + 1] = new("Frame", { Size = UDim2.fromOffset(8, 12), Position = UDim2.new(0.5, k == 0 and -6 or 6, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(60, 64, 96), ZIndex = 8, Parent = p })
		corner(legs[k + 1], 3)
	end
	local case = new("Frame", { Size = UDim2.fromOffset(16, 20), Position = UDim2.new(0.5, fromLeft and -18 or 18, 1, -4), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(176, 110, 70), ZIndex = 11, Parent = p })
	corner(case, 4)
	new("UIStroke", { Thickness = 2, Color = OUTLINE, Parent = case })
	if rng:NextNumber() < 0.45 then
		local hat = new("Frame", { Size = UDim2.fromOffset(28, 7), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(236, 200, 120), ZIndex = 11, Parent = p })
		corner(hat, 3)
		new("UIStroke", { Thickness = 2, Color = OUTLINE, Parent = hat })
	end
	local x = fromLeft and -40 or 1640
	table.insert(walkers, { f = p, legs = legs, x = x, dir = fromLeft and 1 or -1, speed = rng:NextNumber(70, 105), phase = rng:NextNumber(0, 6) })
end
local function car()
	local fromLeft = rng:NextNumber() < 0.5
	local c = new("Frame", { Size = UDim2.fromOffset(130, 56), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, ZIndex = 12, Parent = box })
	local col = SHIRTS[rng:NextInteger(1, #SHIRTS)]
	local cab = new("Frame", { Size = UDim2.fromOffset(70, 28), Position = UDim2.new(0.5, fromLeft and -6 or 6, 0, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = col:Lerp(Color3.new(1, 1, 1), 0.2), ZIndex = 12, Parent = c })
	corner(cab, 10)
	new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = cab })
	local glass = new("Frame", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = Color3.fromRGB(170, 220, 250), ZIndex = 13, Parent = cab })
	corner(glass, 5)
	local body = new("Frame", { Size = UDim2.fromOffset(130, 28), Position = UDim2.new(0, 0, 1, -12), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = col, ZIndex = 14, Parent = c })
	corner(body, 10)
	new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = body })
	for k = 0, 1 do
		local w = new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(k == 0 and 0.22 or 0.78, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(46, 40, 50), ZIndex = 15, Parent = c })
		corner(w, UDim.new(0.5, 0))
		new("UIStroke", { Thickness = 3, Color = OUTLINE, Parent = w })
		local hub = new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(220, 220, 230), ZIndex = 16, Parent = w })
		corner(hub, UDim.new(0.5, 0))
	end
	local lane = fromLeft and 868 or 820
	table.insert(cars, { f = c, x = fromLeft and -120 or 1720, dir = fromLeft and 1 or -1, y = lane, speed = rng:NextNumber(260, 380) })
end
-- the road's lane lines
for k = 0, 15 do
	local dash = new("Frame", { Size = UDim2.fromOffset(56, 6), Position = UDim2.fromOffset(k * 110 + 20, 838), BackgroundColor3 = Color3.fromRGB(250, 222, 120), BackgroundTransparency = 0.25, ZIndex = 2, Parent = box })
	corner(dash, 3)
end
local nextWalker, nextCar = 0.3, 1.2
local lastT = os.clock()

local t0 = os.clock()
local hb = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	local dt = math.min(0.1, os.clock() - lastT)
	lastT = os.clock()
	nextWalker -= dt
	if nextWalker <= 0 then nextWalker = rng:NextNumber(0.9, 1.9) walker() end
	nextCar -= dt
	if nextCar <= 0 then nextCar = rng:NextNumber(1.6, 3.2) car() end
	for i = #walkers, 1, -1 do
		local w = walkers[i]
		w.x += w.dir * w.speed * dt
		local bob = math.abs(math.sin(t * 9 + w.phase)) * 3
		w.f.Position = UDim2.fromOffset(w.x, 766 - bob)
		w.legs[1].Rotation = math.sin(t * 9 + w.phase) * 25
		w.legs[2].Rotation = -math.sin(t * 9 + w.phase) * 25
		if (w.dir > 0 and w.x >= HX) or (w.dir < 0 and w.x <= HX) then
			w.f:Destroy()
			table.remove(walkers, i)
		end
	end
	for i = #cars, 1, -1 do
		local c = cars[i]
		c.x += c.dir * c.speed * dt
		c.f.Position = UDim2.fromOffset(c.x, c.y + math.sin(t * 20 + i) * 0.6)
		if c.x < -200 or c.x > 1800 then c.f:Destroy() table.remove(cars, i) end
	end
	for _, s in ipairs(stars) do
		s.f.BackgroundTransparency = s.base + (1 - s.base) * 0.5 * (1 + math.sin(t * s.speed + s.phase))
	end
	for i, l in ipairs(lamps) do
		local f = 0.04 * math.sin(t * 3 + i)
		for k, r in ipairs(l.rings) do r.BackgroundTransparency = 0.95 - k * 0.035 + f end
	end
	bell.Rotation = math.sin(t * 9) * 14 * math.max(0, math.sin(t * 1.1)) ^ 8
	-- a very slow push towards the door
	zoom = 1 + math.min(t, 20) * 0.004
	fit()
end)

---------------------------------------------------------------- what has to load

local progress = 0
local function lightWindows()
	local want = math.floor(progress * #windows + 0.5)
	for i = 1, want do
		local w = windows[i]
		if not w.on then
			w.on = true
			tween(w.lit, 0.25, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			tween(w.shine, 0.5, { BackgroundTransparency = 0.2 })
		end
	end
end
local function show(k)
	progress = math.max(progress, k)
	tween(barFill, 0.4, { Size = UDim2.fromScale(progress, 1) })
	pct.Text = math.floor(progress * 100 + 0.5) .. "%"
	lightWindows()
end
task.spawn(function()
	local i, j = 1, rng:NextInteger(1, #TIPS)
	tip.Text = TIPS[j]
	while gui.Parent do
		status.Text = progress >= 1 and "Your hotel is ready" or CHORES[i]
		task.wait(1.3)
		i = i % #CHORES + 1
		if i % 3 == 0 then
			j = j % #TIPS + 1
			tween(tip, 0.2, { TextTransparency = 1 })
			task.wait(0.2)
			tip.Text = TIPS[j]
			tween(tip, 0.3, { TextTransparency = 0 })
		end
	end
end)

local started = os.clock()
if not game:IsLoaded() then
	local t = os.clock()
	while not game:IsLoaded() and os.clock() - t < MAX_SECS do
		show(math.min(0.45, 0.05 + (os.clock() - t) * 0.06))
		task.wait(0.1)
	end
end
show(0.5)
local ok, assets = pcall(function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local cfg = Shared and Shared:FindFirstChild("Config")
	local C = cfg and require(cfg)
	local list = {}
	for _, id in pairs(C and C.ICONS or {}) do
		local img = Instance.new("ImageLabel")
		img.Image = id
		table.insert(list, img)
	end
	return list
end)
if ok and #assets > 0 then
	local done, total = 0, #assets
	local finished = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assets, function()
				done += 1
				show(0.5 + 0.45 * done / total)
			end)
		end)
		finished = true
	end)
	local t = os.clock()
	while not finished and os.clock() - t < 12 do task.wait(0.1) end
end
-- the last windows come on a little more slowly, for the feel of it
while progress < 1 and os.clock() - started < MIN_SECS do
	show(math.min(1, progress + 0.04))
	task.wait(0.08)
end
show(1)
status.Text = "Your hotel is ready"
while os.clock() - started < MIN_SECS do task.wait(0.1) end
-- Studio only: workspace attribute HoldLoading keeps it up for screenshots
while RunService:IsStudio() and workspace:GetAttribute("HoldLoading") do task.wait(0.2) end
task.wait(0.3)

---------------------------------------------------------------- out: the doors swing open and we push in through them

hb:Disconnect()
for _, w in ipairs(windows) do tween(w.shine, 0.3, { BackgroundTransparency = 0 }) end
tween(foot, 0.4, { Position = UDim2.new(0.5, 0, 1, 80) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
task.wait(0.25)
tween(doorL, 0.55, { Size = UDim2.fromScale(0.04, 1) }, Enum.EasingStyle.Quart)
tween(doorR, 0.55, { Size = UDim2.fromScale(0.04, 1) }, Enum.EasingStyle.Quart)
task.wait(0.2)
-- push in: grow about the doorway until it fills the screen
local vp = cam.ViewportSize
local s0 = boxScale.Scale
local doorCentre = Vector2.new(HX, 760 - 60) -- the doorway in design space
local anchor = Vector2.new(doorCentre.X / 1600, doorCentre.Y / 900)
box.AnchorPoint = anchor
box.Position = UDim2.new(0.5, (anchor.X - 0.5) * 1600 * s0, 0.5, (anchor.Y - 0.5) * 900 * s0)
tween(boxScale, 0.9, { Scale = s0 * 9 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
tween(box, 0.9, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
task.wait(0.55)
tween(canvas, 0.4, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
task.wait(0.45)
gui:Destroy()
