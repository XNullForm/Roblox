-- StarterPlayerScripts.RAH_Phone (round 14 remake): your phone and the store.
--   The phone (P, or the dock's Phone button) slides up in the bottom-right. Home is a lock-screen style page:
--   the time, the day and the weather, a live hotel widget (rating, rooms ready / busy / dirty, guests
--   waiting, wages), a grid of apps and a dock. Apps:
--     Messages: conversations by sender (tap one for the chat), from game events and other scripts
--     Guests:   everyone staying right now, live: who they are, their mood, what they're doing, who's in town
--     Reviews:  the average, a five-to-one star breakdown, a Praise / Complaints filter and every review
--     Reports:  a bar chart of the last days' earnings and one card per day (the "day" notify)
--     Tips:     how the hotel works, in short cards
--     Staff, Research, Hotel, Awards, Settings: open the Menu on that tab. Build: opens build mode.
--     Store:    opens the store panel (gamepasses, COMING SOON)
--   A message that arrives while the phone is up drops down from the island as a banner.
--   Other scripts: player attribute RAH_PhoneWant = "home" | "messages" | "guests" | "reviews" | "reports" |
--   "tips" | "store" | "toggle" | "close". Unread messages: player attribute RAH_PhoneUnread (the dock badge).
--   RAH_PhoneOpen is set while it's up. Messages from elsewhere: RS.RAH.PhoneMessage:Fire(from, text, icon).
--   Build mode puts the phone away (RAH_Building).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local PLOTS = workspace:WaitForChild("Plots")
local T = UI.T
local ICON = C.ICONS

local msgEvent = RAH:FindFirstChild("PhoneMessage")
if not msgEvent then
	msgEvent = Instance.new("BindableEvent")
	msgEvent.Name = "PhoneMessage"
	msgEvent.Parent = RAH
end

local gui = UI.new("ScreenGui", {
	Name = "RAH_Phone", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 8, Parent = pgui,
})

local function hotel()
	local k = player:GetAttribute("RAH_Plot")
	return k and PLOTS:FindFirstChild(k)
end

local function clockText()
	local t = Lighting.ClockTime
	local h = math.floor(t)
	local m = math.floor((t - h) * 60 / 5) * 5
	local ap = h >= 12 and "PM" or "AM"
	h = h % 12
	if h == 0 then h = 12 end
	return string.format("%d:%02d", h, m), ap
end
local function clockFull()
	local a, b = clockText()
	return a .. " " .. b
end

local WEATHER = { clear = { "Clear", "sun" }, cloudy = { "Cloudy", "cloudy" }, fog = { "Foggy", "cloudy" }, rain = { "Rain", "rain" }, storm = { "Storm", "storm" }, snow = { "Snow", "snow" } }
local TYPE_LABEL = {
	karen = "Demanding", bigspender = "Big spender", backpacker = "Backpacker", influencer = "Influencer", party = "Party animal",
	chatty = "Chatterbox", germ = "Germ-phobe", sleepy = "Sleepyhead", dasher = "Shifty",
}
local PERSONA_LABEL = {
	tourist = "Tourist", business = "On business", foodie = "Foodie", bookworm = "Bookworm", social = "Social butterfly",
	active = "Sporty", relax = "Here to relax", shopper = "Shopper",
}

local function glass(parent, props)
	local radius = props.radius or 18
	props.radius = nil
	local f = UI.new("Frame", props)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = props.BackgroundTransparency or 0.88
	f.Parent = parent
	UI.corner(f, radius)
	UI.stroke(f, 1, Color3.new(1, 1, 1), 0.78)
	return f
end

---------------------------------------------------------------- the phone body

local PW, PH = 360, 700
local wrap = UI.new("Frame", {
	Name = "PhoneWrap", Size = UDim2.fromOffset(PW, PH), AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, PH + 80), BackgroundTransparency = 1, Visible = false, Parent = gui,
})
UI.autoScale(wrap)
local shadow = UI.new("Frame", { Size = UDim2.new(1, 22, 1, 24), Position = UDim2.fromOffset(-11, 6), BackgroundColor3 = T.shadow, BackgroundTransparency = 0.45, Parent = wrap })
UI.corner(shadow, 58)
-- side buttons, drawn behind the case
for _, b in ipairs({ { -3, 150, 64 }, { -3, 226, 64 }, { PW - 3, 190, 92 } }) do
	local k = UI.new("Frame", { Size = UDim2.fromOffset(6, b[3]), Position = UDim2.fromOffset(b[1], b[2]), BackgroundColor3 = Color3.fromRGB(150, 118, 60), Parent = wrap })
	UI.corner(k, 3)
end
local case = UI.new("Frame", { Name = "Case", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = wrap })
UI.corner(case, 52)
UI.grad(case, Color3.fromRGB(84, 88, 118), Color3.fromRGB(22, 24, 36), 90)
UI.stroke(case, 3, T.gold, 0.1)
-- a thin inner bezel line
local bezel = UI.new("Frame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, Parent = case })
UI.corner(bezel, 48)
UI.stroke(bezel, 1.5, Color3.fromRGB(10, 10, 16), 0.2)
local screen = UI.new("Frame", {
	Name = "Screen", Size = UDim2.new(1, -22, 1, -22), Position = UDim2.fromOffset(11, 11), BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true, Parent = case,
})
UI.corner(screen, 42)
-- the wallpaper: deep navy into plum, two soft glows (brass up top, teal down low) and a faint skyline
UI.grad(screen, Color3.fromRGB(44, 52, 104), Color3.fromRGB(26, 18, 48), 90)
local function glow(color, size, pos, t0)
	local g = UI.new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, Parent = screen })
	UI.corner(g, size / 2)
	local gr = Instance.new("UIGradient")
	gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, t0), NumberSequenceKeypoint.new(1, 1) })
	gr.Parent = g
	return g
end
glow(T.gold, 420, UDim2.new(0.15, 0, 0, -40), 0.55)
glow(Color3.fromRGB(70, 200, 210), 380, UDim2.new(1, 0, 1, -60), 0.72)
do
	local sky = UI.new("Frame", { Name = "Skyline", Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 1, -90), BackgroundTransparency = 1, Parent = screen })
	local blocks = { { 0, 34, 50 }, { 30, 26, 70 }, { 52, 40, 44 }, { 88, 22, 82 }, { 108, 46, 56 }, { 150, 30, 74 }, { 176, 38, 48 }, { 210, 24, 88 }, { 230, 44, 60 }, { 270, 30, 76 }, { 296, 46, 52 } }
	for _, b in ipairs(blocks) do
		local f = UI.new("Frame", { Size = UDim2.fromOffset(b[2], b[3]), Position = UDim2.new(0, b[1], 1, 0), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromRGB(12, 10, 26), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = sky })
		for w = 0, 2 do
			if (b[1] + w * 7) % 3 ~= 0 then
				UI.new("Frame", { Size = UDim2.fromOffset(3, 3), Position = UDim2.fromOffset(6 + w * 9, 10 + (b[1] % 4) * 6), BackgroundColor3 = T.gold, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = f })
			end
		end
	end
end

-- status bar: time, the island, signal and battery
local status = UI.new("Frame", { Name = "Status", Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 20, Parent = screen })
local timeL = UI.label(status, clockFull(), 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(30, 12), Size = UDim2.fromOffset(90, 20), ZIndex = 20 })
for k = 1, 4 do
	local bar = UI.new("Frame", {
		Size = UDim2.fromOffset(4, 4 + k * 2.5), Position = UDim2.new(1, -90 + k * 6, 0, 29), AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = T.cream, ZIndex = 20, Parent = status,
	})
	UI.corner(bar, 1)
end
local batt = UI.new("Frame", { Size = UDim2.fromOffset(26, 13), Position = UDim2.new(1, -54, 0, 16), BackgroundTransparency = 1, ZIndex = 20, Parent = status })
UI.corner(batt, 4)
UI.stroke(batt, 1.5, T.cream, 0.1)
local fill = UI.new("Frame", { Size = UDim2.new(0.78, -2, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = T.green, ZIndex = 20, Parent = batt })
UI.corner(fill, 2)
-- the island: a black pill that grows into a notification banner
local island = UI.new("Frame", {
	Name = "Island", Size = UDim2.fromOffset(104, 30), Position = UDim2.new(0.5, 0, 0, 9), AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(4, 4, 8), ClipsDescendants = true, ZIndex = 40, Parent = screen,
})
UI.corner(island, 15)
local isIcon = UI.icon(island, ICON.chat, 30, { Position = UDim2.fromOffset(12, 12), ZIndex = 41, ImageTransparency = 1 })
local isFrom = UI.label(island, "", 14, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -64, 0, 18), ZIndex = 41, TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd })
local isText = UI.label(island, "", 13, { FontFace = UI.F.body, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -64, 0, 32), ZIndex = 41, TextTransparency = 1, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })
isText.TextYAlignment = Enum.TextYAlignment.Top

-- home bar at the bottom: tap it to go home (or close when already home)
local homeBar = UI.new("TextButton", {
	Name = "HomeBar", Text = "", Size = UDim2.fromOffset(140, 24), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1, ZIndex = 30, Parent = screen,
})
local hb = UI.new("Frame", { Size = UDim2.fromOffset(124, 5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.cream, BackgroundTransparency = 0.15, ZIndex = 30, Parent = homeBar })
UI.corner(hb, 3)

---------------------------------------------------------------- state

local messages = {} -- newest first: { from, text, icon, t }
local reports = {} -- newest first: day summaries
local unread = 0
local unreadFrom = {} -- sender -> count
local isOpen, current = false, "home"
local thread -- the sender whose chat is open
local pages = {}
local refreshers = {}
local go -- forward

local function setUnread(n)
	unread = n
	player:SetAttribute("RAH_PhoneUnread", n > 0 and n or nil)
	if refreshers.badges then refreshers.badges() end
end

-- the island banner
local bannerSerial = 0
local function banner(from, text, icon)
	bannerSerial += 1
	local my = bannerSerial
	isIcon.Image = ICON[icon] or ICON.chat
	isFrom.Text, isText.Text = from, text
	UI.tween(island, 0.45, { Size = UDim2.fromOffset(PW - 46, 70) }, Enum.EasingStyle.Back)
	UI.tween(island, 0.45, {}, Enum.EasingStyle.Back)
	local c = island:FindFirstChildOfClass("UICorner")
	if c then UI.tween(c, 0.3, { CornerRadius = UDim.new(0, 26) }) end
	task.delay(0.18, function()
		if my ~= bannerSerial then return end
		UI.tween(isIcon, 0.2, { ImageTransparency = 0 })
		UI.tween(isFrom, 0.2, { TextTransparency = 0 })
		UI.tween(isText, 0.2, { TextTransparency = 0 })
	end)
	task.delay(3.6, function()
		if my ~= bannerSerial then return end
		UI.tween(isIcon, 0.15, { ImageTransparency = 1 })
		UI.tween(isFrom, 0.15, { TextTransparency = 1 })
		UI.tween(isText, 0.15, { TextTransparency = 1 })
		task.wait(0.12)
		if my ~= bannerSerial then return end
		UI.tween(island, 0.35, { Size = UDim2.fromOffset(104, 30) }, Enum.EasingStyle.Quint)
		if c then UI.tween(c, 0.3, { CornerRadius = UDim.new(0, 15) }) end
	end)
end

local function addMessage(from, text, icon)
	table.insert(messages, 1, { from = from, text = text, icon = icon, t = clockFull() })
	if #messages > 60 then table.remove(messages) end
	if isOpen and current == "thread" and thread == from then
		refreshers.thread()
		return
	end
	unreadFrom[from] = (unreadFrom[from] or 0) + 1
	setUnread(unread + 1)
	UI.sound("Tab")
	if isOpen then
		banner(from, text, icon)
		if current == "messages" then refreshers.messages() end
		if current == "home" then refreshers.home() end
	end
end
msgEvent.Event:Connect(function(from, text, icon) addMessage(tostring(from or "Unknown"), tostring(text or ""), icon) end)

---------------------------------------------------------------- pages

local function page(id)
	local f = UI.new("Frame", { Name = "Page_" .. id, Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, Visible = false, Parent = screen })
	pages[id] = f
	return f
end

-- an app page header: a back chevron and the title, then a scrolling list
local function header(f, title, color, backTo)
	local back = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 4), BackgroundTransparency = 1, Parent = f })
	for _, r in ipairs({ { -45, -4 }, { 45, 4 } }) do
		local bar = UI.new("Frame", { Size = UDim2.fromOffset(14, 3), Position = UDim2.new(0.5, 0, 0.5, r[2]), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = r[1], BackgroundColor3 = color or T.gold, Parent = back })
		UI.corner(bar, 2)
	end
	back.Activated:Connect(function() UI.sound("Click") go(backTo or "home") end)
	local tl = UI.label(f, title, 26, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -70, 0, 32), TextTruncate = Enum.TextTruncate.AtEnd })
	local list = UI.new("ScrollingFrame", {
		Name = "List", Size = UDim2.new(1, -24, 1, -90), Position = UDim2.fromOffset(12, 52), BackgroundTransparency = 1,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0, Parent = f,
	})
	UI.list(list, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
	UI.pad(list, 2, 2, 6, 10)
	return list, tl
end

local function clear(list)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function card(list, order, h)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, h or 0), AutomaticSize = h and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, LayoutOrder = order, Parent = list })
	UI.corner(f, 16)
	UI.stroke(f, 1, Color3.new(1, 1, 1), 0.8)
	UI.pad(f, 12, 10, 12, 10)
	return f
end

local function empty(list, text, icon)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 170), BackgroundTransparency = 1, Parent = list })
	UI.icon(f, ICON[icon or "chat"], 64, { Position = UDim2.new(0.5, 0, 0, 20), AnchorPoint = Vector2.new(0.5, 0), ImageTransparency = 0.35 })
	UI.label(f, text, 15, { FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, Position = UDim2.fromOffset(10, 96), Size = UDim2.new(1, -20, 0, 50), TextXAlignment = Enum.TextXAlignment.Center })
	return f
end

-- a round avatar with an icon in it
local function avatar(parent, icon, color, size, pos)
	local a = UI.new("Frame", { Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent })
	UI.corner(a, size / 2)
	UI.grad(a, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	UI.icon(a, ICON[icon] or ICON.chat, size * 0.62, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	return a
end
local SENDER_COLORS = { Color3.fromRGB(90, 150, 240), Color3.fromRGB(230, 150, 70), Color3.fromRGB(110, 200, 130), Color3.fromRGB(200, 110, 190), Color3.fromRGB(230, 100, 100), Color3.fromRGB(120, 190, 210) }
local function senderColor(name)
	local h = 0
	for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 997 end
	return SENDER_COLORS[h % #SENDER_COLORS + 1]
end

local function starsRow(parent, n, pos, size)
	size = size or 16
	local row = UI.new("Frame", { Size = UDim2.fromOffset(size * 5.6, size), Position = pos, BackgroundTransparency = 1, Parent = parent })
	for k = 1, 5 do
		UI.icon(row, k <= n and ICON.star or ICON.starEmpty, size, { Position = UDim2.fromOffset((k - 1) * (size + 1), 0) })
	end
	return row
end

local function readReviews()
	local h = hotel()
	local json = h and h:GetAttribute("Reviews")
	if type(json) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(t) == "table" then return t end
	end
	return {}
end

---------------------------------------------------------------- home

local home = page("home")
local bigClock = UI.label(home, "", 64, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 70), TextXAlignment = Enum.TextXAlignment.Center })
local dayL = UI.label(home, "", 15, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center })
local wxIcon = UI.icon(home, ICON.sun, 20, { Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0) })

-- the hotel widget
local widget = glass(home, { Name = "Widget", Size = UDim2.new(1, -32, 0, 128), Position = UDim2.fromOffset(16, 134), BackgroundTransparency = 0.86, radius = 22 })
local wName = UI.label(widget, "", 17, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -120, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
local wStarsHolder = UI.new("Frame", { Size = UDim2.fromOffset(100, 18), Position = UDim2.new(1, -112, 0, 14), BackgroundTransparency = 1, Parent = widget })
local wRating = UI.label(widget, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.new(1, -112, 0, 32), Size = UDim2.fromOffset(100, 16), TextXAlignment = Enum.TextXAlignment.Right })
local pills = {}
for i, p in ipairs({ { "ready", "Ready", T.green, "roomReady" }, { "busy", "Busy", T.blue, "roomBusy" }, { "dirty", "Dirty", Color3.fromRGB(240, 160, 70), "roomDirty" } }) do
	local f = UI.new("Frame", { Size = UDim2.new(1 / 3, -10, 0, 52), Position = UDim2.new((i - 1) / 3, i == 1 and 14 or (i == 2 and 5 or -4), 0, 58), BackgroundColor3 = Color3.fromRGB(10, 12, 26), BackgroundTransparency = 0.45, Parent = widget })
	UI.corner(f, 14)
	UI.icon(f, ICON[p[4]], 22, { Position = UDim2.fromOffset(9, 6) })
	local n = UI.label(f, "0", 20, { FontFace = UI.F.black, TextColor3 = p[3], Position = UDim2.fromOffset(36, 4), Size = UDim2.new(1, -40, 0, 24) })
	UI.label(f, p[2], 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -14, 0, 16) })
	pills[p[1]] = n
end

-- the app grid and the dock
local APPS = {
	{ id = "reports", text = "Reports", icon = "stats", top = Color3.fromRGB(150, 240, 170), bot = Color3.fromRGB(34, 150, 84) },
	{ id = "staff", text = "Staff", icon = "staff", top = Color3.fromRGB(170, 236, 150), bot = Color3.fromRGB(60, 150, 70), menu = "staff" },
	{ id = "research", text = "Research", icon = "research", top = Color3.fromRGB(206, 180, 255), bot = Color3.fromRGB(110, 70, 210), menu = "research" },
	{ id = "build", text = "Build", icon = "hammer", top = Color3.fromRGB(255, 214, 140), bot = Color3.fromRGB(206, 128, 40), build = true },
	{ id = "hotelpage", text = "Hotel", icon = "hotel", top = Color3.fromRGB(255, 230, 160), bot = Color3.fromRGB(196, 140, 50), menu = "hotel" },
	{ id = "awards", text = "Awards", icon = "trophy", top = Color3.fromRGB(255, 200, 120), bot = Color3.fromRGB(200, 110, 40), menu = "achievements" },
	{ id = "tips", text = "Tips", icon = "quest", top = Color3.fromRGB(150, 220, 255), bot = Color3.fromRGB(40, 130, 200) },
	{ id = "settings", text = "Settings", icon = "settings", top = Color3.fromRGB(200, 206, 220), bot = Color3.fromRGB(96, 104, 126), menu = "settings" },
}
local DOCK = {
	{ id = "messages", text = "Messages", icon = "chat", top = Color3.fromRGB(140, 214, 255), bot = Color3.fromRGB(46, 116, 222) },
	{ id = "guests", text = "Guests", icon = "guest", top = Color3.fromRGB(255, 190, 150), bot = Color3.fromRGB(214, 96, 70) },
	{ id = "reviews", text = "Reviews", icon = "star", top = Color3.fromRGB(255, 226, 138), bot = Color3.fromRGB(214, 140, 40) },
	{ id = "store", text = "Store", icon = "shop", top = Color3.fromRGB(255, 180, 210), bot = Color3.fromRGB(200, 70, 130) },
}
local badges = {}
local function appButton(parent, a, order, label)
	local b = UI.new("TextButton", { Name = "App_" .. a.id, Text = "", BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b })
	UI.corner(tile, 16)
	UI.grad(tile, a.top, a.bot, 90)
	UI.stroke(tile, 1.5, Color3.new(1, 1, 1), 0.65)
	-- a soft shine across the top half
	local shine = UI.new("Frame", { Size = UDim2.new(1, -6, 0.48, 0), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Parent = tile })
	UI.corner(shine, 13)
	UI.icon(tile, ICON[a.icon], 38, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	if label then
		UI.label(b, a.text, 12, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(0, 61), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
	end
	local badge = UI.new("TextLabel", {
		Text = "", TextSize = 12, FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = T.red,
		Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0.5, 26, 0, -5), AnchorPoint = Vector2.new(0.5, 0), Visible = false, ZIndex = 3, Parent = b,
	})
	UI.corner(badge, 11)
	UI.stroke(badge, 1.5, Color3.new(1, 1, 1), 0.2)
	badges[a.id] = badge
	UI.animate(b, {})
	b.Activated:Connect(function()
		UI.sound("Click")
		if a.menu then
			player:SetAttribute("RAH_MenuWant", a.menu)
		elseif a.build then
			player:SetAttribute("RAH_BuildWant", "all")
		else
			go(a.id)
		end
	end)
	return b
end
local grid = UI.new("Frame", { Size = UDim2.new(1, -28, 0, 190), Position = UDim2.fromOffset(14, 274), BackgroundTransparency = 1, Parent = home })
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(0.25, 0, 0, 86)
gl.CellPadding = UDim2.fromOffset(0, 6)
gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = grid
for i, a in ipairs(APPS) do appButton(grid, a, i, true) end

-- the latest message, lock-screen style
local notice = glass(home, { Name = "Notice", Size = UDim2.new(1, -32, 0, 60), Position = UDim2.fromOffset(16, 460), BackgroundTransparency = 0.86, radius = 18 })
local nAv = UI.new("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = notice })
local nFrom = UI.label(notice, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -140, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
local nTime = UI.label(notice, "", 11, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.new(1, -80, 0, 11), Size = UDim2.fromOffset(68, 14), TextXAlignment = Enum.TextXAlignment.Right })
local nText = UI.label(notice, "", 13, { FontFace = UI.F.body, TextColor3 = T.cream, Position = UDim2.fromOffset(62, 28), Size = UDim2.new(1, -74, 0, 30), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })
nText.TextYAlignment = Enum.TextYAlignment.Top
local nBtn = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = notice })
nBtn.Activated:Connect(function()
	local m = messages[1]
	if m then thread = m.from; UI.sound("Click"); go("thread") end
end)

local dock = glass(home, { Name = "Dock", Size = UDim2.new(1, -24, 0, 80), Position = UDim2.new(0, 12, 1, -104), BackgroundTransparency = 0.8, radius = 28 })
local dl = Instance.new("UIGridLayout")
dl.CellSize = UDim2.new(0.25, 0, 0, 64)
dl.CellPadding = UDim2.new()
dl.HorizontalAlignment = Enum.HorizontalAlignment.Center
dl.VerticalAlignment = Enum.VerticalAlignment.Center
dl.SortOrder = Enum.SortOrder.LayoutOrder
dl.Parent = dock
for i, a in ipairs(DOCK) do appButton(dock, a, i, false) end

local function hotelStats()
	local h = hotel()
	if not h then return nil end
	return {
		name = h:GetAttribute("HotelName") or "Your hotel",
		stars = tonumber(h:GetAttribute("HotelStars")) or tonumber(h:GetAttribute("ReviewStars")) or 0,
		ready = h:GetAttribute("RoomsReady") or 0, busy = h:GetAttribute("RoomsBusy") or 0, dirty = h:GetAttribute("RoomsDirty") or 0,
		waiting = h:GetAttribute("Waiting") or 0,
	}
end

refreshers.badges = function()
	badges.messages.Text = unread > 9 and "9+" or tostring(unread)
	badges.messages.Visible = unread > 0
	local s = hotelStats()
	local w = s and s.waiting or 0
	badges.guests.Text = tostring(w)
	badges.guests.Visible = w > 0
end

refreshers.home = function()
	local a, b = clockText()
	bigClock.Text = a
	local wx = WEATHER[RAH:GetAttribute("Weather") or "clear"] or WEATHER.clear
	dayL.Text = b .. "   |   Day " .. tostring(RAH:GetAttribute("Day") or 1) .. "   |   " .. wx[1]
	wxIcon.Image = ICON[wx[2]] or ICON.sun
	wxIcon.Visible = false
	local s = hotelStats()
	if s then
		wName.Text = s.name
		wRating.Text = string.format("%.1f stars", s.stars)
		for _, c in ipairs(wStarsHolder:GetChildren()) do c:Destroy() end
		starsRow(wStarsHolder, math.floor(s.stars + 0.5), UDim2.new(), 17)
		pills.ready.Text, pills.busy.Text, pills.dirty.Text = tostring(s.ready), tostring(s.busy), tostring(s.dirty)
	end
	local m = messages[1]
	notice.Visible = m ~= nil
	if m then
		for _, c in ipairs(nAv:GetChildren()) do c:Destroy() end
		avatar(nAv, m.icon, senderColor(m.from), 40, UDim2.new())
		nFrom.Text = m.from
		nTime.Text = m.t
		nText.Text = m.text
	end
	refreshers.badges()
end

---------------------------------------------------------------- Messages: conversations, then a chat

local msgList = header(page("messages"), "Messages", T.blue)
refreshers.messages = function()
	clear(msgList)
	if #messages == 0 then empty(msgList, "No messages yet. People in town, guests and your staff will text you here.", "chat") return end
	local seen, order = {}, 0
	for _, m in ipairs(messages) do
		if not seen[m.from] then
			seen[m.from] = true
			order += 1
			local c = card(msgList, order, 70)
			avatar(c, m.icon, senderColor(m.from), 44, UDim2.fromOffset(-2, 1))
			local n = unreadFrom[m.from] or 0
			UI.label(c, m.from, 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -124, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			UI.label(c, m.t, 11, { FontFace = UI.F.body, TextColor3 = n > 0 and T.blue or T.muted, Position = UDim2.new(1, -70, 0, 2), Size = UDim2.fromOffset(70, 14), TextXAlignment = Enum.TextXAlignment.Right })
			local pv = UI.label(c, m.text, 13, { FontFace = n > 0 and UI.F.bold or UI.F.body, TextColor3 = n > 0 and T.cream or T.muted, Position = UDim2.fromOffset(52, 20), Size = UDim2.new(1, -84, 0, 30), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })
			pv.TextYAlignment = Enum.TextYAlignment.Top
			if n > 0 then
				local dot = UI.new("TextLabel", { Text = tostring(n), TextSize = 11, FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = T.blue, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -20, 0, 24), Parent = c })
				UI.corner(dot, 10)
			end
			local b = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = c })
			b.Activated:Connect(function() thread = m.from; UI.sound("Click"); go("thread") end)
		end
	end
end

local threadPage = page("thread")
local threadList, threadTitle = header(threadPage, "", T.blue, "messages")
threadList:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
refreshers.thread = function()
	clear(threadList)
	threadTitle.Text = thread or ""
	local mine = {}
	for _, m in ipairs(messages) do if m.from == thread then table.insert(mine, 1, m) end end
	for i, m in ipairs(mine) do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i, Parent = threadList })
		local bub = UI.new("Frame", { Size = UDim2.new(0.84, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Color3.fromRGB(56, 62, 98), Parent = row })
		UI.corner(bub, 16)
		UI.pad(bub, 12, 8, 12, 9)
		local body = UI.label(bub, m.text, 14, { FontFace = UI.F.body, TextColor3 = T.cream, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
		body.TextYAlignment = Enum.TextYAlignment.Top
		local ts = UI.label(row, m.t, 10, { FontFace = UI.F.body, TextColor3 = T.muted, Size = UDim2.fromOffset(80, 12), Position = UDim2.new(0.84, 6, 1, -14) })
		UI.pad(row, 0, 0, 0, 2)
		ts.ZIndex = 2
	end
	local n = unreadFrom[thread] or 0
	unreadFrom[thread] = nil
	if n > 0 then setUnread(math.max(0, unread - n)) end
	task.defer(function() threadList.CanvasPosition = Vector2.new(0, 1e5) end)
end

---------------------------------------------------------------- Guests: who's staying, live

local guestList = header(page("guests"), "Guests", Color3.fromRGB(255, 160, 120))
local function moodColor(m)
	if m >= 70 then return T.green elseif m >= 45 then return T.gold else return T.red end
end
refreshers.guests = function()
	clear(guestList)
	local h = hotel()
	local list = {}
	for _, m in ipairs(CollectionService:GetTagged("RAH_Bubble")) do
		if m:IsA("Model") and m:GetAttribute("Guest") and m:IsDescendantOf(workspace) and (not h or (m:GetPivot().Position - h:GetPivot().Position).Magnitude < 160) then
			table.insert(list, m)
		end
	end
	table.sort(list, function(a, b) return (a:GetAttribute("Mood") or 60) < (b:GetAttribute("Mood") or 60) end)
	-- who's out in town (their room says so)
	local away = 0
	if h and h:FindFirstChild("Rooms") then
		for _, r in ipairs(h.Rooms:GetChildren()) do if r:GetAttribute("AwayAt") then away += 1 end end
	end
	local s = hotelStats()
	local top = card(guestList, 0, 58)
	local function stat(i, n, label, col)
		local x = (i - 1) / 3
		UI.label(top, tostring(n), 20, { FontFace = UI.F.black, TextColor3 = col, Position = UDim2.new(x, 0, 0, -2), Size = UDim2.new(1 / 3, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
		UI.label(top, label, 11, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.new(x, 0, 0, 22), Size = UDim2.new(1 / 3, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center })
	end
	stat(1, #list, "Inside", T.cream)
	stat(2, away, "In town", T.blue)
	stat(3, s and s.waiting or 0, "Waiting", T.gold)
	if #list == 0 then empty(guestList, "No guests right now. Open the door and let some in!", "guest") return end
	for i, m in ipairs(list) do
		local mood = m:GetAttribute("Mood") or 60
		local c = card(guestList, i, 76)
		local gt = m:GetAttribute("GuestType")
		avatar(c, gt == "karen" and "angry" or (mood >= 70 and "happy" or (mood < 45 and "angry" or "guest")), moodColor(mood), 44, UDim2.fromOffset(-2, 4))
		UI.label(c, m:GetAttribute("BName") or m.Name, 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -150, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		local tag = TYPE_LABEL[gt or ""] or PERSONA_LABEL[m:GetAttribute("Persona") or ""] or "Guest"
		local tl = UI.label(c, string.upper(tag), 10, { FontFace = UI.F.black, TextColor3 = gt and Color3.fromRGB(255, 170, 140) or T.gold, Position = UDim2.new(1, -96, 0, 3), Size = UDim2.fromOffset(96, 12), TextXAlignment = Enum.TextXAlignment.Right })
		local what = m:GetAttribute("BWhat") or ""
		local need = m:GetAttribute("Need")
		UI.label(c, what .. (need and ("  -  " .. tostring(need)) or ""), 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(52, 20), Size = UDim2.new(1, -52, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local barBg = UI.new("Frame", { Size = UDim2.new(1, -52, 0, 7), Position = UDim2.fromOffset(52, 44), BackgroundColor3 = Color3.fromRGB(10, 12, 26), BackgroundTransparency = 0.3, Parent = c })
		UI.corner(barBg, 4)
		local fillB = UI.new("Frame", { Size = UDim2.fromScale(math.clamp(mood / 100, 0.04, 1), 1), BackgroundColor3 = moodColor(mood), Parent = barBg })
		UI.corner(fillB, 4)
		tl.ZIndex = 2
	end
end

---------------------------------------------------------------- Reviews: the average, a breakdown and a filter

local revPage = page("reviews")
local revList = header(revPage, "Reviews", T.gold)
local revFilter = "all"
refreshers.reviews = function()
	clear(revList)
	local list = readReviews()
	if #list == 0 then empty(revList, "No reviews yet. Guests write one when they check out.", "star") return end
	local sum, counts = 0, { 0, 0, 0, 0, 0 }
	for _, r in ipairs(list) do
		local s = math.clamp(tonumber(r.stars) or 3, 1, 5)
		sum += s
		counts[s] += 1
	end
	local avg = sum / #list
	local top = card(revList, 0, 124)
	UI.label(top, string.format("%.1f", avg), 44, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(96, 50), TextXAlignment = Enum.TextXAlignment.Center })
	starsRow(top, math.floor(avg + 0.5), UDim2.fromOffset(6, 58), 15)
	UI.label(top, #list .. (#list == 1 and " review" or " reviews"), 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(0, 78), Size = UDim2.fromOffset(96, 16), TextXAlignment = Enum.TextXAlignment.Center })
	local maxC = math.max(1, table.unpack(counts))
	for k = 5, 1, -1 do
		local y = (5 - k) * 19 + 2
		UI.label(top, tostring(k), 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(106, y), Size = UDim2.fromOffset(12, 16) })
		local bg = UI.new("Frame", { Size = UDim2.new(1, -150, 0, 8), Position = UDim2.fromOffset(122, y + 5), BackgroundColor3 = Color3.fromRGB(10, 12, 26), BackgroundTransparency = 0.3, Parent = top })
		UI.corner(bg, 4)
		local f = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = k >= 4 and T.gold or (k == 3 and T.cream or T.red), Parent = bg })
		UI.corner(f, 4)
		UI.tween(f, 0.5 + (5 - k) * 0.06, { Size = UDim2.fromScale(counts[k] / maxC, 1) }, Enum.EasingStyle.Quint)
		UI.label(top, tostring(counts[k]), 11, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.new(1, -24, 0, y), Size = UDim2.fromOffset(24, 16), TextXAlignment = Enum.TextXAlignment.Right })
	end
	-- the filter
	local seg = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(10, 12, 26), BackgroundTransparency = 0.4, LayoutOrder = 1, Parent = revList })
	UI.corner(seg, 12)
	for i, o in ipairs({ { "all", "All" }, { "good", "Praise" }, { "bad", "Complaints" } }) do
		local on = revFilter == o[1]
		local b = UI.new("TextButton", {
			Text = o[2], TextSize = 13, FontFace = UI.F.heavy, TextColor3 = on and T.ink or T.cream, AutoButtonColor = false,
			BackgroundColor3 = T.gold, BackgroundTransparency = on and 0 or 1, Size = UDim2.new(1 / 3, -6, 1, -6), Position = UDim2.new((i - 1) / 3, 3, 0, 3), Parent = seg,
		})
		UI.corner(b, 10)
		b.Activated:Connect(function()
			if revFilter == o[1] then return end
			revFilter = o[1]
			UI.sound("Tab")
			refreshers.reviews()
		end)
	end
	local shown = 0
	for i, r in ipairs(list) do
		local s = math.clamp(tonumber(r.stars) or 3, 1, 5)
		if revFilter == "all" or (revFilter == "good" and s >= 4) or (revFilter == "bad" and s <= 2) then
			shown += 1
			if shown > 30 then break end
			local c = card(revList, 1 + i)
			c:FindFirstChildOfClass("UIStroke").Color = s >= 4 and T.gold or s <= 2 and T.red or Color3.new(1, 1, 1)
			c:FindFirstChildOfClass("UIStroke").Transparency = s == 3 and 0.8 or 0.35
			UI.label(c, tostring(r.name or "Guest"), 14, { FontFace = UI.F.heavy, TextColor3 = T.cream, Size = UDim2.new(1, -96, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			if r.room then UI.label(c, "Room " .. tostring(r.room), 11, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, -96, 0, 14) }) end
			starsRow(c, s, UDim2.new(1, -88, 0, 1))
			local body = UI.label(c, '"' .. tostring(r.text or "") .. '"', 13, { FontFace = UI.F.body, TextColor3 = T.cream, Position = UDim2.fromOffset(0, r.room and 36 or 22), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
			body.TextYAlignment = Enum.TextYAlignment.Top
		end
	end
	if shown == 0 then empty(revList, revFilter == "good" and "No praise yet." or "No complaints. Keep it up!", revFilter == "good" and "happy" or "heart") end
end

---------------------------------------------------------------- Reports: a chart, then the days

local repList = header(page("reports"), "Reports", T.green)
refreshers.reports = function()
	clear(repList)
	if #reports == 0 then empty(repList, "Your first report arrives at dawn.", "stats") return end
	-- the last seven days' earnings as bars (oldest on the left)
	local chart = card(repList, 0, 150)
	UI.label(chart, "Earnings", 14, { FontFace = UI.F.heavy, TextColor3 = T.cream, Size = UDim2.new(1, 0, 0, 18) })
	local n = math.min(7, #reports)
	local maxE = 1
	for i = 1, n do maxE = math.max(maxE, reports[i].earned or 0) end
	local area = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Parent = chart })
	for k = 1, n do
		local d = reports[n - k + 1]
		local x = (k - 1) / 7
		local hgt = math.clamp((d.earned or 0) / maxE, 0.03, 1)
		local col = UI.new("Frame", { Size = UDim2.new(1 / 7, -8, hgt, 0), Position = UDim2.new(x, 4, 1, 0), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = area })
		UI.corner(col, 6)
		UI.grad(col, k == n and T.gold or Color3.fromRGB(150, 240, 170), k == n and T.goldDk or Color3.fromRGB(34, 150, 84), 90)
		col.Size = UDim2.new(1 / 7, -8, 0, 0)
		UI.tween(col, 0.45 + k * 0.05, { Size = UDim2.new(1 / 7, -8, hgt, 0) }, Enum.EasingStyle.Back)
		UI.label(chart, "D" .. tostring(d.day or "?"), 10, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.new(x, 0, 0, 120), Size = UDim2.new(1 / 7, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center })
	end
	for i, d in ipairs(reports) do
		local c = card(repList, i)
		UI.label(c, "Day " .. tostring(d.day or "?"), 18, { FontFace = UI.F.black, TextColor3 = T.cream, Size = UDim2.new(1, 0, 0, 22) })
		local net = (d.earned or 0) - (d.wages or 0)
		UI.label(c, (net >= 0 and "+$" or "-$") .. UI.commas(math.abs(net)), 16, { FontFace = UI.F.black, TextColor3 = net >= 0 and T.green or T.red, Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(0.5, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
		local rows = {
			{ "Earned", "$" .. UI.commas(d.earned or 0), T.green },
			{ "Guests", tostring(d.guests or 0), T.cream },
			{ "Rooms cleaned", tostring(d.cleans or 0), T.cream },
		}
		if (d.wages or 0) > 0 then table.insert(rows, { "Staff wages", "-$" .. UI.commas(d.wages), T.red }) end
		if (d.uncollected or 0) > 0 then table.insert(rows, { "Not collected", "$" .. UI.commas(d.uncollected), T.gold }) end
		for k, r in ipairs(rows) do
			local y = 28 + (k - 1) * 20
			UI.label(c, r[1], 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.6, 0, 0, 18) })
			UI.label(c, r[2], 13, { FontFace = UI.F.heavy, TextColor3 = r[3], Position = UDim2.new(0.6, 0, 0, y), Size = UDim2.new(0.4, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })
		end
		UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, 28 + #rows * 20), BackgroundTransparency = 1, Parent = c })
	end
end

---------------------------------------------------------------- Tips

local TIPS = {
	{ "roomDirty", "Clean rooms fast", "A dirty room can't take a guest. Make the bed, scrub the shower and toilet, pick up the trash." },
	{ "bell", "Work the desk", "Sit at the front desk to check guests in and out yourself. A receptionist does it for you." },
	{ "guest", "Talk to guests", "Walk up and talk. Ask how they are, recommend things to do in town, calm down an angry one." },
	{ "angry", "Demanding guests", "Some guests complain loudly. Listen, offer a discount or call the manager. Ignoring them hurts reviews." },
	{ "suitcase", "Carry the bags", "Take a guest's suitcase up to their room for a tip. Press G to put it down." },
	{ "staff", "Hire a team", "Staff need a staff room: wall off a small room and put Staff Lockers in it. Give them breaks." },
	{ "hammer", "Build rooms fast", "In build mode, pick a wall and press F (Room). Drag out a square and it builds the walls and a door." },
	{ "research", "Research", "Unlock new furniture, upgrades and new kinds of guests in the Research Lab." },
	{ "star", "Reviews", "Clean rooms, nice furniture and happy guests mean better reviews, and better reviews bring more guests." },
}
local tipList = header(page("tips"), "Tips", T.blue)
refreshers.tips = function()
	clear(tipList)
	for i, t in ipairs(TIPS) do
		local c = card(tipList, i)
		avatar(c, t[1], SENDER_COLORS[(i - 1) % #SENDER_COLORS + 1], 38, UDim2.fromOffset(-2, 0))
		UI.label(c, t[2], 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -46, 0, 18) })
		local b = UI.label(c, t[3], 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -46, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true })
		b.TextYAlignment = Enum.TextYAlignment.Top
	end
end

---------------------------------------------------------------- the store (gamepasses: UI only for now)

local PASSES = {
	{ name = "2x Cash", text = "Double cash from every guest, forever.", price = 399, icon = "cash", top = Color3.fromRGB(150, 240, 150), bot = Color3.fromRGB(36, 150, 80) },
	{ name = "VIP Guests", text = "Rich VIP guests visit who tip big.", price = 299, icon = "star", top = Color3.fromRGB(255, 226, 138), bot = Color3.fromRGB(214, 130, 30) },
	{ name = "Fast Research", text = "Research finishes twice as fast.", price = 249, icon = "research", top = Color3.fromRGB(206, 180, 255), bot = Color3.fromRGB(110, 70, 210) },
	{ name = "Speed Coil", text = "Run faster around your hotel.", price = 99, icon = "run", top = Color3.fromRGB(255, 196, 130), bot = Color3.fromRGB(216, 96, 40) },
	{ name = "Extra Land", text = "One more plot of land for free.", price = 199, icon = "hammer", top = Color3.fromRGB(150, 210, 255), bot = Color3.fromRGB(50, 110, 210) },
	{ name = "Golden Decor", text = "A set of gold furniture and decor.", price = 349, icon = "sparkle", top = Color3.fromRGB(255, 236, 160), bot = Color3.fromRGB(190, 140, 40) },
}

local storeWrap = UI.new("Frame", { Name = "StoreWrap", Size = UDim2.fromOffset(820, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
UI.autoScale(storeWrap)
local closeStore -- forward
local storePanel, storeBody = UI.panel(storeWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
	name = "Store", title = "Store", subtitle = "Passes for your hotel", icon = ICON.shop, onClose = function() closeStore() end,
})
storePanel.Visible = false
local soon = UI.new("TextLabel", {
	Text = "COMING SOON", TextSize = 13, FontFace = UI.F.black, TextColor3 = T.ink, BackgroundColor3 = T.gold,
	Size = UDim2.fromOffset(120, 26), Position = UDim2.new(1, -66, 0, 16), AnchorPoint = Vector2.new(1, 0), Parent = storeBody,
})
UI.corner(soon, 13)
local sgrid = UI.new("Frame", { Size = UDim2.new(1, -40, 1, -96), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1, Parent = storeBody })
local sgl = Instance.new("UIGridLayout")
sgl.CellSize = UDim2.new(1 / 3, -10, 0.5, -8)
sgl.CellPadding = UDim2.fromOffset(14, 14)
sgl.SortOrder = Enum.SortOrder.LayoutOrder
sgl.Parent = sgrid
for i, p in ipairs(PASSES) do
	local c = UI.new("Frame", { Name = p.name, BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = sgrid })
	UI.corner(c, 16)
	UI.stroke(c, 1.5, T.line, 0.3)
	local band = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Color3.new(1, 1, 1), Parent = c })
	UI.corner(band, 16)
	UI.grad(band, p.top, p.bot, 90)
	-- square off the band's lower corners
	local sq = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = band })
	UI.grad(sq, p.bot:Lerp(p.top, 0.1), p.bot, 90)
	UI.icon(band, ICON[p.icon], 70, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	UI.label(c, p.name, 19, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(14, 104), Size = UDim2.new(1, -28, 0, 24) })
	local d = UI.label(c, p.text, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 128), Size = UDim2.new(1, -28, 0, 34), TextWrapped = true })
	d.TextYAlignment = Enum.TextYAlignment.Top
	UI.button(c, {
		text = "R$ " .. p.price, kind = "gold", textSize = 16, size = UDim2.new(1, -28, 0, 34), pos = UDim2.new(0, 14, 1, -46), radius = 10,
		onClick = function() UI.toast(p.name .. " is coming soon", ICON.shop) end,
	})
end

local storeOpen = false
table.insert(UI.closers, { b = storePanel, fn = function() closeStore() end })
local function openStore()
	if storeOpen then return end
	storeOpen = true
	UI.open(storePanel)
	UI.blur(true)
end
closeStore = function()
	if not storeOpen then return end
	storeOpen = false
	UI.close(storePanel)
	UI.blur(false)
end


---------------------------------------------------------------- open / close / navigate

go = function(id)
	if id == "store" then openStore() return end
	if not pages[id] then id = "home" end
	if id == "thread" and not thread then id = "messages" end
	local was = current
	for k, f in pairs(pages) do
		if f.Visible and k ~= id then f.Visible = false end
	end
	local f = pages[id]
	if refreshers[id] then refreshers[id]() end
	if not f.Visible then
		f.Visible = true
		-- apps open from the right, going back slides in from the left
		local back = id == "home" or (id == "messages" and was == "thread")
		f.Position = UDim2.fromOffset(back and -40 or 40, 44)
		UI.tween(f, 0.28, { Position = UDim2.fromOffset(0, 44) }, Enum.EasingStyle.Quint)
	end
	current = id
end

local function setOpen(on)
	if on == isOpen then return end
	isOpen = on
	if on then
		wrap.Visible = true
		wrap.Rotation = 4
		UI.tween(wrap, 0.5, { Position = UDim2.new(1, -24, 1, -24), Rotation = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		UI.sound("Open")
	else
		UI.tween(wrap, 0.3, { Position = UDim2.new(1, -24, 1, PH + 80), Rotation = 3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.sound("Close")
		task.delay(0.32, function() if not isOpen then wrap.Visible = false end end)
	end
	player:SetAttribute("RAH_PhoneOpen", on or nil)
end
table.insert(UI.closers, { b = wrap, fn = function() setOpen(false) end })

homeBar.Activated:Connect(function()
	if current == "home" then setOpen(false) else UI.sound("Click") go("home") end
end)

player:GetAttributeChangedSignal("RAH_PhoneWant"):Connect(function()
	local want = player:GetAttribute("RAH_PhoneWant")
	if not want then return end
	player:SetAttribute("RAH_PhoneWant", nil)
	if want == "close" then setOpen(false) return end
	if want == "store" then openStore() return end
	if want == "toggle" then
		if isOpen then setOpen(false) return end
		want = current
	end
	setOpen(true)
	go(want)
end)

-- entering build mode puts the phone away
player:GetAttributeChangedSignal("RAH_Building"):Connect(function()
	if player:GetAttribute("RAH_Building") and isOpen then setOpen(false) end
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.P and not player:GetAttribute("RAH_Building") then
		if isOpen then setOpen(false) else setOpen(true) go(current) end
	end
end)

-- the clock ticks, the widget and the live guest list keep up while it's open
task.spawn(function()
	local n = 0
	while gui.Parent do
		timeL.Text = clockFull()
		n += 1
		if isOpen then
			if current == "home" then refreshers.home()
			elseif current == "guests" and n % 2 == 0 then refreshers.guests() end
		elseif n % 3 == 0 then
			refreshers.badges()
		end
		task.wait(1)
	end
end)

---------------------------------------------------------------- messages from the game

local CITY = { "Marta from the bakery", "City Tourism Board", "Old Pete next door", "Hotel Association", "Your mom" }
local function pick(t) return t[math.random(1, #t)] end

Notify.OnClientEvent:Connect(function(kind, d)
	d = type(d) == "table" and d or {}
	if kind == "day" then
		table.insert(reports, 1, d)
		if #reports > 30 then table.remove(reports) end
		if isOpen and current == "reports" then refreshers.reports() end
		local earned = d.earned or 0
		addMessage("Front desk", string.format("Day %s report is in: $%s earned from %d guests.", tostring(d.day or "?"), UI.commas(earned), d.guests or 0), "stats")
	elseif kind == "levelUp" then
		addMessage("Hotel Association", "Congratulations on reaching level " .. tostring(d.level or "?") .. "! Word is getting around town.", "medal")
	elseif kind == "review" then
		addMessage(tostring(d.name or "A guest"), tostring(d.text or "Left you a review."), (d.stars or 3) >= 4 and "happy" or "angry")
		if isOpen and current == "reviews" then refreshers.reviews() end
	elseif kind == "phone" then
		addMessage(tostring(d.from or "Unknown"), tostring(d.text or ""), d.icon)
	end
end)

-- a few hello messages so the phone isn't empty on day one
task.delay(12, function()
	addMessage("City Tourism Board", "Welcome to town! Visitors are already asking about your little hotel.", "hotel")
	task.wait(40)
	addMessage(pick(CITY), "Saw your sign go up. Keep the rooms clean and the reviews will follow!", "clean")
end)

refreshers.home()
