-- ReplicatedFirst.Loading (round 21, 2026-11-12): the loading screen, remade plain and calm.
-- A dark slate screen: the OVERBOOKED wordmark, one thin progress line, what is loading and a tip. No clouds, no
-- island, no bouncing. It runs before ReplicatedStorage has arrived, so it builds everything itself. It waits for the
-- game to load, preloads the HUD glyphs and icons, stays at least MIN_SECS, then fades onto the title screen that is
-- already running underneath (MainMenu keeps a gui called "Loading" on top of it).
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
local BG_TOP, BG_BOT = Color3.fromRGB(24, 30, 42), Color3.fromRGB(12, 15, 22)
local BRAND = Color3.fromRGB(20, 132, 246)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(140, 150, 170)
local TRACK = Color3.fromRGB(44, 52, 68)

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

local gui = new("ScreenGui", {
	Name = "Loading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = pgui,
})
local canvas = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = gui })
new("UIGradient", { Color = ColorSequence.new(BG_TOP, BG_BOT), Rotation = 90, Parent = canvas })

-- everything sits in one column in the middle, scaled to the screen
local col = new("Frame", { Size = UDim2.fromOffset(640, 300), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = canvas })
local scale = new("UIScale", { Parent = col })
local cam = workspace.CurrentCamera
local function fit()
	local vp = cam.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.3)
end
fit()
cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

local mark = text(col, "OVERBOOKED", 64, Enum.FontWeight.ExtraBold, WHITE, { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 40), TextTransparency = 1 })
local tag = text(col, "S E A S I D E   H O T E L   T Y C O O N", 14, Enum.FontWeight.Bold, MUTED, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 112), TextTransparency = 1 })
local track = new("Frame", { Size = UDim2.fromOffset(360, 4), Position = UDim2.new(0.5, 0, 0, 176), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = TRACK, BackgroundTransparency = 1, Parent = col })
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BRAND, Parent = track })
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
local status = text(col, "", 15, Enum.FontWeight.Bold, WHITE, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 192), TextTransparency = 1 })
local tip = text(canvas, "", 15, Enum.FontWeight.Medium, MUTED, { Size = UDim2.new(1, -80, 0, 20), Position = UDim2.new(0.5, 0, 1, -54), AnchorPoint = Vector2.new(0.5, 0), TextTransparency = 1 })

tween(mark, 0.5, { TextTransparency = 0 })
tween(tag, 0.7, { TextTransparency = 0 })
tween(track, 0.5, { BackgroundTransparency = 0 })
tween(status, 0.5, { TextTransparency = 0.1 })
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
end
task.spawn(function()
	local rng = Random.new()
	local j = rng:NextInteger(1, #TIPS)
	tip.Text = "Tip: " .. TIPS[j]
	local n = 0
	while gui.Parent do
		status.Text = progress >= 1 and "Ready" or STEPS[math.clamp(math.floor(progress * #STEPS) + 1, 1, #STEPS)]
		task.wait(0.25)
		n += 1
		if n % 20 == 0 then
			j = j % #TIPS + 1
			tween(tip, 0.2, { TextTransparency = 1 })
			task.wait(0.2)
			tip.Text = "Tip: " .. TIPS[j]
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
