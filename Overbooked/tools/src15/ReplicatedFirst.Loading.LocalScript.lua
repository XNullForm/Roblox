-- ReplicatedFirst.Loading (round 34 remake; round 21 logic): the loading screen in the game's daytime look.
-- A seaside sky, a white glossy card (the chapter goals' style) with the OVERBOOKED wordmark, a thick progress bar
-- with the percent, what is loading, and a tip on a pill at the bottom. It runs before ReplicatedStorage has arrived,
-- so it builds everything itself. It waits for the game to load, preloads the HUD glyphs and icons, stays at least
-- MIN_SECS, then fades onto the title screen that is already running underneath.
-- Studio only: workspace attribute HoldLoading keeps it up for screenshots.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local MIN_SECS = 2.5
local MAX_SECS = 25
local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
local SKY_TOP, SKY_BOT = Color3.fromRGB(86, 170, 236), Color3.fromRGB(196, 230, 250)
local SEA, SAND = Color3.fromRGB(64, 176, 214), Color3.fromRGB(246, 228, 186)
local BRAND = Color3.fromRGB(20, 132, 246)
local INK = Color3.fromRGB(26, 32, 44)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(110, 120, 138)
local TRACK = Color3.fromRGB(232, 237, 244)

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function text(parent, str, size, weight, color, props)
	local l = new("TextLabel", {
		Text = str, TextSize = size, FontFace = Font.new(FAMILY, weight), TextColor3 = color, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function round(o, r) new("UICorner", { CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r), Parent = o }) end

local gui = new("ScreenGui", {
	Name = "Loading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pgui,
})
local canvas = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
-- (a UIGradient on the CanvasGroup itself would tint everything in it, so the sky is its own frame)
local sky = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = canvas })
new("UIGradient", { Color = ColorSequence.new(SKY_TOP, SKY_BOT), Rotation = 90, Parent = sky })
-- the sun's glow, the sea and the beach along the bottom
local sun = new("Frame", { Size = UDim2.fromOffset(300, 300), Position = UDim2.new(0.8, 0, 0.2, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 248, 220), BackgroundTransparency = 0.35, Parent = canvas })
round(sun, UDim.new(0.5, 0))
new("UIStroke", { Color = Color3.fromRGB(255, 248, 220), Thickness = 18, Transparency = 0.75, Parent = sun })
local sea = new("Frame", { Size = UDim2.new(1, 0, 0.2, 0), Position = UDim2.fromScale(0, 0.8), BackgroundColor3 = SEA, Parent = canvas })
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(90, 196, 228), Color3.fromRGB(40, 140, 196)), Rotation = 90, Parent = sea })
new("Frame", { Size = UDim2.new(1, 0, 0.06, 0), Position = UDim2.fromScale(0, 0.94), BackgroundColor3 = SAND, Parent = canvas })
local foam = new("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.94, -3), BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, Parent = canvas })
task.spawn(function()
	while foam.Parent do
		tween(foam, 2.2, { Position = UDim2.new(0, 0, 0.94, -7) }, Enum.EasingStyle.Sine)
		task.wait(2.2)
		tween(foam, 2.2, { Position = UDim2.new(0, 0, 0.94, -3) }, Enum.EasingStyle.Sine)
		task.wait(2.2)
	end
end)

-- the card in the middle, scaled to the screen
local col = new("Frame", { Size = UDim2.fromOffset(560, 248), Position = UDim2.fromScale(0.5, 0.44), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = canvas })
local scale = new("UIScale", { Parent = col })
local tipScale = new("UIScale", {})
local cam = workspace.CurrentCamera
local function fit()
	local vp = cam.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.3)
	tipScale.Scale = scale.Scale
end
fit()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
local shadow = new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = Color3.fromRGB(20, 60, 110), BackgroundTransparency = 0.75, Parent = col })
round(shadow, 30)
local card = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = col })
round(card, 30)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(244, 247, 250)), Parent = card })
new("UIStroke", { Color = TRACK, Thickness = 3, Parent = card })
local bell = new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0.5, 0, 0, -30), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = BRAND, Parent = card })
round(bell, 20)
new("UIStroke", { Color = WHITE, Thickness = 4, Parent = bell })
text(bell, "OB", 28, Enum.FontWeight.Heavy, WHITE, { Size = UDim2.fromScale(1, 1) })
local mark = text(card, "OVERBOOKED", 60, Enum.FontWeight.Heavy, INK, { Size = UDim2.new(1, 0, 0, 66), Position = UDim2.fromOffset(0, 48), TextTransparency = 1 })
local tag = text(card, "SEASIDE HOTEL TYCOON", 15, Enum.FontWeight.Heavy, BRAND, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 116), TextTransparency = 1 })
local track = new("Frame", { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0.5, 0, 0, 176), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = TRACK, Parent = card })
round(track, UDim.new(1, 0))
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BRAND, ClipsDescendants = true, Parent = track })
round(fill, UDim.new(1, 0))
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(80, 170, 255), BRAND), Parent = fill })
local shine = new("Frame", { Size = UDim2.new(0, 60, 1, 0), Position = UDim2.fromScale(-0.3, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, Parent = fill })
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = shine })
task.spawn(function()
	while shine.Parent do
		shine.Position = UDim2.fromScale(-0.3, 0)
		tween(shine, 1.2, { Position = UDim2.fromScale(1.1, 0) }, Enum.EasingStyle.Sine)
		task.wait(1.6)
	end
end)
local status = text(card, "", 15, Enum.FontWeight.Bold, MUTED, { Size = UDim2.new(1, -80, 0, 18), Position = UDim2.new(0, 40, 0, 204), TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1 })
local pct = text(card, "0%", 15, Enum.FontWeight.Heavy, BRAND, { Size = UDim2.fromOffset(80, 18), Position = UDim2.new(1, -40, 0, 204), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right })
local tipPill = new("Frame", { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = WHITE, Parent = canvas })
round(tipPill, 20)
new("UIStroke", { Color = TRACK, Thickness = 2, Parent = tipPill })
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18), Parent = tipPill })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tipPill })
local chip = text(tipPill, "TIP", 13, Enum.FontWeight.Heavy, WHITE, { Size = UDim2.fromOffset(44, 26), BackgroundTransparency = 0, BackgroundColor3 = BRAND, LayoutOrder = 1 })
round(chip, 13)
local tip = text(tipPill, "", 16, Enum.FontWeight.Bold, INK, { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, TextTransparency = 1 })
tipScale.Parent = tipPill

tween(mark, 0.5, { TextTransparency = 0 })
tween(tag, 0.7, { TextTransparency = 0 })
tween(status, 0.5, { TextTransparency = 0 })
tween(tip, 0.9, { TextTransparency = 0 })

local TIPS = {
	"Clean rooms fill faster. A dirty room earns nothing.",
	"Guests who wait too long at the desk walk out.",
	"Staff run the hotel while you build. Hire a receptionist first.",
	"Curb Appeal in Upgrades turns the old hotel into a grand one.",
	"Summer is the busy season. Winter is quiet but pays more per night.",
	"Happy guests leave better reviews, and stars bring more guests.",
}
local STEPS = { "Loading the game", "Loading the town", "Loading the hotel", "Almost there" }
local progress = 0
local function show(k)
	progress = math.max(progress, k)
	tween(fill, 0.35, { Size = UDim2.fromScale(progress, 1) })
	pct.Text = math.floor(progress * 100 + 0.5) .. "%"
end
task.spawn(function()
	local rng = Random.new()
	local j = rng:NextInteger(1, #TIPS)
	tip.Text = TIPS[j]
	local n = 0
	while gui.Parent do
		status.Text = progress >= 1 and "Ready" or STEPS[math.clamp(math.floor(progress * #STEPS) + 1, 1, #STEPS)]
		task.wait(0.25)
		n += 1
		if n % 20 == 0 then
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
	local list = {}
	local function add(id)
		local img = Instance.new("ImageLabel")
		img.Image = id
		table.insert(list, img)
	end
	local ui = Shared and Shared:FindFirstChild("UI")
	local UI = ui and require(ui)
	for _, id in pairs(UI and UI.G or {}) do add(id) end
	local cfg = Shared and Shared:FindFirstChild("Config")
	local C = cfg and require(cfg)
	for _, id in pairs(C and C.ICONS or {}) do add(id) end
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
show(1)
while os.clock() - started < MIN_SECS do task.wait(0.1) end
while RunService:IsStudio() and workspace:GetAttribute("HoldLoading") do task.wait(0.2) end
task.wait(0.3)

tween(canvas, 0.45, { GroupTransparency = 1 })
task.wait(0.5)
gui:Destroy()
