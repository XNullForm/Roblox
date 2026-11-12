-- StarterPlayerScripts.Client: the HUD (round 15 remake), custom prompt buttons, money popups and toasts.
-- Draws only; every number comes from server attributes (player Cash; hotel Level/XP/XPNeed, HotelStars,
-- Rooms*, Quests; Shared.Day, Shared.Clock, Shared.Weather). Top centre: one bar of pills (level star + XP, cash with +,
-- rating, guests/rooms with OPEN/FULL and a rooms-to-clean chip, day/time/weather); the tutorial card hangs
-- under it. Right: the chapter goals (Shared.Quests, Q.SHOW at a time, collapsible). Level-ups and finished
-- chapters get full-screen moments. The whole HUD steps aside while you build (player attribute Building).
-- The bar's buttons open the menu through the player attribute MenuWant (Coop).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PPS = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Clock = require(Shared:WaitForChild("Clock"))
local Levels = require(Shared:WaitForChild("Levels"))
local Q = require(Shared:WaitForChild("Quests"))
local Notify = Shared.Remotes:WaitForChild("Notify")
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
-- the hotel you work in (player attribute Plot, set by Plots). Coop restarts this script when it changes.
local PLOTS = workspace:WaitForChild("Plots")
while not player:GetAttribute("Plot") do player:GetAttributeChangedSignal("Plot"):Wait() end
local HOTEL = PLOTS:WaitForChild(player:GetAttribute("Plot"))
for _, g in ipairs(pgui:GetChildren()) do
	if g.Name == "HUD" or g.Name == "Prompt" or g.Name == "Pop" then g:Destroy() end
end

local hud = UI.new("ScreenGui", {
	Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 4, Parent = pgui,
})

-- round 15 v2 (2026-11-09): the HUD is glossy white pills on deep shadows, each led by a round shaded badge.
--   Corner (top left, under Roblox's buttons): your hotel: the level badge, its name, the stars, the XP bar
--   Top (top centre): the money, with the guests beside it and the rooms-to-clean flag hanging under
--   Clock (top right): the time, the day and the weather
-- Each is a group with its own AutoScale that slides off its edge when the HUD hides.
local groups = {}
local PHONE = UIS.TouchEnabled and not UIS.KeyboardEnabled
local function group(name, size, pos, anchor, away)
	local f = UI.new("Frame", { Name = name, Size = size, Position = pos, AnchorPoint = anchor, BackgroundTransparency = 1, Parent = hud })
	if PHONE then
		local sc = Instance.new("UIScale")
		sc.Name = "AutoScale"
		sc.Scale = 0.5
		sc.Parent = f
	else
		UI.autoScale(f)
	end
	groups[name] = { frame = f, home = pos, away = away }
	return f
end

-- a glossy white plate with a soft rim (the goals panel and the tutorial card use it)
local function plate(parent, props)
	local radius = props.radius
	props.radius = nil
	local f = UI.new("Frame", props)
	f.BackgroundColor3 = props.BackgroundColor3 or T.ink
	f.BackgroundTransparency = 0
	f.Parent = parent
	UI.corner(f, radius or 18)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(236, 232, 252)), Parent = f })
	UI.rim(f, Color3.fromRGB(206, 198, 244), 2.5)
	return f
end

local CARD_RIM = Color3.fromRGB(204, 196, 244)
-- a clickable glossy card on a deep shadow: returns the button (scale / tooltips go on it) and its body
local function hudCard(parent, name, size, pos, onClick, radius)
	local b = UI.new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = size, Position = pos, BackgroundTransparency = 1, Parent = parent })
	UI.shadow(b, { drop = 7, transparency = 0.6 })
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, Parent = b })
	UI.corner(body, radius or 20)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 228, 250)), Parent = body })
	UI.rim(body, CARD_RIM, 2.5)
	local g = UI.gloss(body, radius or 20, 0.6)
	g.Size = UDim2.new(1, -8, 0.45, 0)
	g.Position = UDim2.fromOffset(4, 3)
	local sc = UI.scaleOf(b)
	b.MouseEnter:Connect(function() UI.tween(sc, 0.2, { Scale = 1.04 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() UI.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Quint) end)
	if onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			UI.pop(b, 0.94, 0.3)
			onClick()
		end)
	end
	return b, body
end
-- a round shaded badge that sits over the card's left end (overlapping it a little)
local function tile(parent, size, color, pos, icon, iconSize)
	local t = UI.badge(parent, size, color, nil, { Name = "Tile", Position = pos, AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local ic
	if icon then ic = UI.icon(t, icon, iconSize or math.floor(size * 0.72), { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 }) end
	return t, ic
end
-- a recessed track (the XP bar, the day bar)
local function track(parent, props, color)
	local tr = UI.new("Frame", props)
	tr.BackgroundColor3 = Color3.fromRGB(226, 222, 246)
	tr.Parent = parent
	UI.corner(tr, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(196, 190, 222), Color3.new(1, 1, 1)), Parent = tr })
	UI.rim(tr, Color3.fromRGB(196, 188, 236), 1.5)
	local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, ClipsDescendants = true, ZIndex = tr.ZIndex + 1, Parent = tr })
	UI.corner(fill, UDim.new(0.5, 0))
	UI.sheen(fill)
	local hl = UI.new("Frame", { Size = UDim2.new(1, -6, 0.4, 0), Position = UDim2.fromOffset(3, 1), BackgroundColor3 = T.white, BackgroundTransparency = 0.55, ZIndex = tr.ZIndex + 2, Parent = fill })
	UI.corner(hl, UDim.new(0.5, 0))
	return tr, fill
end

local function openMenu(tab) player:SetAttribute("MenuWant", tab) end

local cornerGroup = group("Corner", UDim2.fromOffset(356, 104), PHONE and UDim2.new(0, 16, 1, -18) or UDim2.fromOffset(16, 64), PHONE and Vector2.new(0, 1) or Vector2.new(0, 0), PHONE and UDim2.new(0, -460, 1, -18) or UDim2.fromOffset(-440, 64))
local topGroup = group("Top", UDim2.fromOffset(484, 80), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -130))
local clockGroup = group("Clock", UDim2.fromOffset(236, 80), UDim2.new(1, -16, 0, 10), Vector2.new(1, 0), UDim2.new(1, 280, 0, 10))

---------------------------------------------------------------- your hotel: level, name, stars, XP

local lvSlot, lvBody = hudCard(cornerGroup, "Level", UDim2.new(1, -30, 0, 88), UDim2.fromOffset(30, 6), function() openMenu("hotel") end, 22)
-- the level badge: a big glossy violet disc hanging off the card's left end, glowing softly
local lvHolder = UI.new("Frame", { Name = "LvHolder", Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0, 0, 0, 8), BackgroundTransparency = 1, ZIndex = 3, Parent = cornerGroup })
UI.glow(lvHolder, 150, T.brand, { ImageTransparency = 0.55 })
local lvTile = UI.badge(lvHolder, 84, T.brand, nil, { Name = "Lv", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
local lvPat = UI.new("ImageLabel", { Image = UI.IMG.plus, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(28, 28), Size = UDim2.fromScale(1, 1), ImageTransparency = 0.86, ZIndex = 4, Parent = lvTile })
UI.corner(lvPat, UDim.new(0.5, 0))
local lvCap = UI.label(lvTile, "LEVEL", 12, { FontFace = UI.F.display, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 0, 13), ZIndex = 7 })
UI.textStroke(lvCap, 1.5, 0, T.brandDk)
local levelNum = UI.label(lvTile, "1", 36, { FontFace = UI.F.display, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 40), ZIndex = 7 })
UI.textStroke(levelNum, 3, 0, T.brandDk)
local starBadge = lvTile
local hotelName = UI.label(lvBody, "", 21, { FontFace = UI.F.display, TextColor3 = T.cream, Position = UDim2.fromOffset(66, 10), Size = UDim2.new(1, -80, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
-- the stars: five glossy ones filled to the rating, the number after them
local STAR = 21
local rateSlot = UI.new("Frame", { Name = "Rating", Size = UDim2.fromOffset(190, STAR), Position = UDim2.fromOffset(66, 36), BackgroundTransparency = 1, ZIndex = 4, Parent = lvBody })
local starClips = {}
for i = 1, 5 do
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(STAR, STAR), Position = UDim2.fromOffset((i - 1) * (STAR + 2), 0), BackgroundTransparency = 1, ZIndex = 4, Parent = rateSlot })
	UI.new("ImageLabel", { Image = UI.IMG.star, ImageColor3 = Color3.fromRGB(222, 216, 244), Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = holder })
	local clip = UI.new("Frame", { Size = UDim2.fromOffset(0, STAR), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = holder })
	UI.new("ImageLabel", { Image = UI.IMG.star, ImageColor3 = T.sun, Size = UDim2.fromOffset(STAR, STAR), ZIndex = 5, Parent = clip })
	UI.new("ImageLabel", { Image = UI.IMG.starGloss, ImageColor3 = T.white, ImageTransparency = 0.25, Size = UDim2.fromOffset(STAR, STAR), ZIndex = 6, Parent = clip })
	starClips[i] = clip
end
local starNum = UI.label(rateSlot, "1.0", 17, { FontFace = UI.F.display, TextColor3 = T.sunDk, Position = UDim2.fromOffset(5 * (STAR + 2) + 4, 0), Size = UDim2.fromOffset(50, STAR), ZIndex = 5 })
local xpTrack, xpFill = track(lvBody, { Name = "XP", Size = UDim2.new(1, -80, 0, 14), Position = UDim2.fromOffset(66, 63), ZIndex = 4 }, T.brand)
local xpText = UI.label(xpTrack, "", 11, { FontFace = UI.F.display, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 8 })
UI.textStroke(xpText, 1.5, 0, T.brandDk)
local levelLbl = xpText -- (older code wrote the level here)
UI.tooltip(lvSlot, "Your hotel: check guests in, give great stays, clean and research to earn XP")
-- a slow shine crawls along the XP bar now and then
local xpSweep = UI.new("Frame", { Name = "Sweep", Size = UDim2.new(0, 26, 1, 0), Position = UDim2.fromOffset(-30, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, Rotation = 14, ZIndex = 7, Parent = xpFill })
task.spawn(function()
	while xpSweep.Parent do
		xpSweep.Position = UDim2.fromOffset(-30, 0)
		UI.tween(xpSweep, 1.2, { Position = UDim2.new(1, 30, 0, 0) }, Enum.EasingStyle.Sine).Completed:Wait()
		task.wait(3.5)
	end
end)

---------------------------------------------------------------- the money and the guests

local cashSlot, cashBody = hudCard(topGroup, "Cash", UDim2.fromOffset(268, 58), UDim2.fromOffset(18, 8), function() openMenu("hotel") end, 29)
local cashTile, cashIcon = tile(topGroup, 70, T.sun, UDim2.new(0, 0, 0, 37), ICON.cash, 50)
UI.glow(cashTile, 120, T.sun, { ImageTransparency = 0.5, ZIndex = 2 })
local cashText = UI.label(cashBody, "$0", 30, {
	FontFace = UI.F.display, TextColor3 = T.cream, TextScaled = true, ZIndex = 4,
	Position = UDim2.fromOffset(60, 9), Size = UDim2.new(1, -112, 1, -18),
})
UI.new("UITextSizeConstraint", { MaxTextSize = 31, MinTextSize = 14, Parent = cashText })
local plusBtn = UI.new("TextButton", { Name = "Plus", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.green, ZIndex = 4, Parent = cashBody })
plusBtn.BackgroundTransparency = 0
UI.corner(plusBtn, UDim.new(0.5, 0))
UI.sheen(plusBtn)
UI.rim(plusBtn, T.greenDk, 2.5)
UI.gloss(plusBtn, 19, 0.45)
for _, r in ipairs({ 0, 90 }) do
	local bar = UI.new("Frame", { Size = UDim2.fromOffset(18, 6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = r, BackgroundColor3 = T.white, ZIndex = 7, Parent = plusBtn })
	UI.corner(bar, 3)
	UI.rim(bar, T.greenDk, 1.5)
end
UI.animate(plusBtn, { hover = 1.15 })
plusBtn.Activated:Connect(function()
	UI.sound("Click")
	openMenu("hotel")
end)
UI.tooltip(plusBtn, "Earnings and upgrades")
local flyLayer = UI.new("Frame", { Name = "Fly", Size = UDim2.fromOffset(220, 80), Position = UDim2.fromOffset(66, 58), BackgroundTransparency = 1, ZIndex = 8, Parent = cashSlot })

local roomSlot, roomBody = hudCard(topGroup, "Rooms", UDim2.fromOffset(170, 58), UDim2.fromOffset(314, 8), function() openMenu("hotel") end, 29)
local roomTile = tile(topGroup, 62, T.blue, UDim2.new(0, 300, 0, 37), ICON.guest, 44)
local roomNum = UI.label(roomBody, "0/0", 27, { FontFace = UI.F.display, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 5), Size = UDim2.fromOffset(110, 30), ZIndex = 4 })
UI.label(roomBody, "GUESTS", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(53, 33), Size = UDim2.fromOffset(110, 15), ZIndex = 4 })
UI.tooltip(roomSlot, "Guests staying / your guest rooms")
-- the rooms waiting for a clean hang under it on a glossy coral flag
local dirtyChip = UI.new("Frame", { Name = "Dirty", BackgroundColor3 = T.red, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(18, 66), Visible = false, ZIndex = 5, Parent = roomSlot })
UI.corner(dirtyChip, UDim.new(0.5, 0))
UI.sheen(dirtyChip)
local dirtyStroke = UI.rim(dirtyChip, T.redDk, 2.5)
UI.pad(dirtyChip, 6, 0, 12, 0)
UI.list(dirtyChip, Enum.FillDirection.Horizontal, 5, nil, Enum.VerticalAlignment.Center)
UI.icon(dirtyChip, ICON.clean, 24, { LayoutOrder = 1, ZIndex = 6 })
local dirtyText = UI.new("TextLabel", { Text = "", TextSize = 14, FontFace = UI.F.display, TextColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, ZIndex = 6, Parent = dirtyChip })
UI.textStroke(dirtyText, 1.5, 0, T.redDk)
local openTag = UI.new("Frame", { Visible = false, Parent = roomBody }) -- (the old OPEN / FULL tag: the count says it)
local openText = UI.label(openTag, "", 10, {})

---------------------------------------------------------------- the time, the day and the weather

local clockSlot, clockBody = hudCard(clockGroup, "Clock", UDim2.fromOffset(212, 58), UDim2.fromOffset(24, 8), nil, 29)
local skyTile, skyIcon = tile(clockGroup, 66, T.blue, UDim2.new(0, 0, 0, 37), ICON.sun, 46)
local clockText = UI.label(clockBody, "", 25, { FontFace = UI.F.display, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 5), Size = UDim2.new(1, -62, 0, 28), ZIndex = 4 })
local dayLbl = UI.label(clockBody, "MON  -  SPRING", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(53, 31), Size = UDim2.new(1, -62, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
local dateLbl = dayLbl
-- the day runs along the bottom of the card
local dayTrack, dayFill = track(clockBody, { Size = UDim2.new(1, -66, 0, 6), Position = UDim2.new(0, 52, 1, -11), ZIndex = 4 }, T.sun)
UI.tooltip(clockSlot, function()
	local w = Shared:GetAttribute("WeatherName")
	return w and ("Weather: " .. w) or "Guests check out in the morning and arrive all day"
end)

-- the tutorial card hangs under the top cards
local tutWrap = UI.new("Frame", { Name = "Tutorial", Size = UDim2.fromOffset(540, 96), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = topGroup })

local shownStars = -1
local function refreshCard()
	hotelName.Text = HOTEL:GetAttribute("HotelName") or "My Hotel"
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	starNum.Text = string.format("%.1f", stars)
	if math.abs(stars - shownStars) > 0.01 then
		local up = stars > shownStars and shownStars >= 0
		shownStars = stars
		for i = 1, 5 do
			local k = math.clamp(stars - (i - 1), 0, 1)
			UI.tween(starClips[i], 0.6, { Size = UDim2.fromOffset(STAR * k, STAR) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, (i - 1) * 0.06)
		end
		if up then UI.pop(rateSlot, 1.15) UI.sparkles(rateSlot, 4, T.sun, 1.2) end
	end
end
for _, a in ipairs({ "HotelName", "HotelStars" }) do HOTEL:GetAttributeChangedSignal(a):Connect(refreshCard) end
refreshCard()

-- level and XP (hotel attributes Level / XP / XPNeed, written by Shared.Levels on the server)
local shownLevel = HOTEL:GetAttribute("Level") or 1
local function refreshXP()
	local lv = HOTEL:GetAttribute("Level") or 1
	local xp = HOTEL:GetAttribute("XP") or 0
	local need = HOTEL:GetAttribute("XPNeed") or Levels.need(lv)
	levelNum.Text = tostring(lv)
	levelNum.TextSize = lv >= 100 and 26 or 36
	xpText.Text = lv >= Levels.MAX and "MAX LEVEL" or (UI.commas(xp) .. " / " .. UI.commas(need) .. " XP")
	local k = lv >= Levels.MAX and 1 or math.clamp(xp / math.max(need, 1), 0, 1)
	if lv > shownLevel then
		-- fill to the end, then start the new level from empty; the level tile flips over
		UI.tween(xpFill, 0.35, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad).Completed:Once(function()
			xpFill.Size = UDim2.fromScale(0, 1)
			UI.tween(xpFill, 0.5, { Size = UDim2.fromScale(k, 1) })
		end)
		lvTile.Rotation = -180
		UI.tween(lvTile, 0.8, { Rotation = 0 }, Enum.EasingStyle.Back)
		UI.pop(lvTile, 1.4, 0.5)
		local rays = UI.rays(lvHolder, 200, T.sun, { ImageTransparency = 0.2 })
		UI.sparkles(lvHolder, 8, T.sun, 1.6)
		task.delay(2.2, function() UI.tween(rays, 0.5, { ImageTransparency = 1 }) task.wait(0.5) rays:Destroy() end)
	else
		UI.tween(xpFill, 0.5, { Size = UDim2.fromScale(k, 1) })
	end
	shownLevel = lv
end
for _, a in ipairs({ "Level", "XP", "XPNeed" }) do HOTEL:GetAttributeChangedSignal(a):Connect(refreshXP) end
refreshXP()

local lastClock = ""
local DOW = { Monday = "MON", Tuesday = "TUE", Wednesday = "WED", Thursday = "THU", Friday = "FRI", Saturday = "SAT", Sunday = "SUN" }
local function refreshClock()
	local t = Clock.now()
	local night = Clock.isNight(t)
	local d = Clock.date()
	local s = Clock.format(t)
	if s ~= lastClock then
		lastClock = s
		clockText.Text = s
		dayLbl.Text = (DOW[d.dowName] or string.upper(d.dowName)) .. "  -  " .. string.upper(d.seasonName) .. "  -  DAY " .. d.day
	end
	dayFill.Size = UDim2.fromScale(math.clamp(t / 24, 0, 1), 1)
	local w = Shared:GetAttribute("Weather")
	local img = (w and w ~= "clear" and ICON[w]) or (night and ICON.ev_night) or ICON.sun
	if skyIcon.Image ~= img then
		skyIcon.Image = img
		UI.pop(skyIcon, 0.6, 0.4)
		local sky = night and Color3.fromRGB(78, 64, 170) or ((w == "rain" or w == "storm" or w == "fog" or w == "cloudy") and Color3.fromRGB(130, 146, 184) or T.blue)
		UI.tween(skyTile, 0.6, { BackgroundColor3 = sky })
		if skyTile:FindFirstChild("Rim") then UI.tween(skyTile.Rim, 0.6, { Color = UI.shade(sky, -0.4) }) end
	end
end

-- cash: big numbers shorten so the card never overflows; infinite cash (the /mmoney command) shows as "Infinite"
local function money(n)
	if n == math.huge then return "Infinite" end
	n = math.floor(n + 0.5)
	if math.abs(n) >= 1e7 then return string.format("$%.2fM", n / 1e6) end
	return "$" .. UI.commas(n)
end
local shownCash = player:GetAttribute("Cash") or 0
local lastCash = shownCash
cashText.Text = money(shownCash)
local cashFrom, cashTo, cashT = shownCash, shownCash, 1
local function flyDelta(d)
	local up = d > 0
	local l = UI.chip(flyLayer, (up and "+" or "-") .. money(math.abs(d)), up and T.green or T.red, { TextSize = 18, Size = UDim2.fromOffset(0, 30), Position = UDim2.fromOffset(0, -6), ZIndex = 9 })
	UI.pop(l, 0.4, 0.4)
	if up then UI.sparkles(l, 3, T.white, 1.4) end
	UI.tween(l, 1.3, { Position = UDim2.fromOffset(0, 30) }, Enum.EasingStyle.Quint)
	UI.tween(l, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1)
	for _, st in ipairs(l:GetChildren()) do
		if st:IsA("UIStroke") then UI.tween(st, 0.4, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1) end
	end
	task.delay(1.45, function() l:Destroy() end)
end
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local now = player:GetAttribute("Cash") or 0
	local d = now - lastCash
	lastCash = now
	cashFrom, cashTo, cashT = shownCash, now, 0
	if math.abs(d) >= 1 and d == d and math.abs(d) ~= math.huge then
		flyDelta(d)
		UI.pop(cashSlot, d > 0 and 1.08 or 0.96, 0.3)
		if d > 0 then
			cashIcon.Rotation = -18
			UI.tween(cashIcon, 0.6, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		end
	end
end)

local shown = { busy = -1, total = -1, dirty = -1 }
local function refreshRooms()
	local ready = HOTEL:GetAttribute("RoomsReady") or 0
	local busy = HOTEL:GetAttribute("RoomsBusy") or 0
	local dirty = HOTEL:GetAttribute("RoomsDirty") or 0
	local total = ready + busy + dirty
	if busy ~= shown.busy or total ~= shown.total then
		roomNum.Text = busy .. "/" .. total
		if shown.busy >= 0 then UI.pop(roomSlot, 1.08, 0.3) end
	end
	if dirty ~= shown.dirty then
		dirtyText.Text = dirty == 1 and "1 ROOM TO CLEAN" or (dirty .. " ROOMS TO CLEAN")
		if dirty > 0 and not dirtyChip.Visible then
			dirtyChip.Visible = true
			UI.pop(dirtyChip, 0.5, 0.4)
		elseif dirty > shown.dirty and shown.dirty >= 0 then
			UI.pop(dirtyChip, 1.15, 0.3)
		end
		dirtyChip.Visible = dirty > 0
	end
	shown.busy, shown.total, shown.dirty = busy, total, dirty
end
for _, k in ipairs({ "RoomsReady", "RoomsBusy", "RoomsDirty" }) do
	HOTEL:GetAttributeChangedSignal(k):Connect(refreshRooms)
end
refreshRooms()

---------------------------------------------------------------- sprint (hold Shift)

local StarterPlayer = game:GetService("StarterPlayer")
local BASE_SPEED = StarterPlayer.CharacterWalkSpeed
local SPRINT_SPEED = BASE_SPEED * 1.65
local sprinting = false
local function applySprint()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.WalkSpeed == 0 then return end -- never fight build mode's freeze
	hum.WalkSpeed = sprinting and player:GetAttribute("Sprint") ~= false and SPRINT_SPEED or BASE_SPEED
end
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		applySprint()
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = false
		applySprint()
	end
end)
player.CharacterAdded:Connect(function()
	task.defer(function()
		sprinting = false
		applySprint()
	end)
end)

-- round 10e: phones get a sprint toggle that sits just left of Roblox's jump button
if UIS.TouchEnabled then
	local sg = UI.new("ScreenGui", { Name = "SprintBtn", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Parent = pgui })
	local btn = UI.new("ImageButton", {
		Name = "Sprint", Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.ink, BackgroundTransparency = 0.15, AutoButtonColor = false, Image = "", Parent = sg,
	})
	UI.corner(btn, 32)
	local st = UI.stroke(btn, 2, T.gold, 0.2)
	local lbl = UI.icon(btn, ICON.run, 40, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	local function paint()
		btn.BackgroundColor3 = sprinting and T.gold or T.ink
		lbl.ImageTransparency = sprinting and 0 or 0.15
		st.Transparency = sprinting and 0 or 0.2
	end
	btn.Activated:Connect(function()
		sprinting = not sprinting
		applySprint()
		paint()
	end)
	player.CharacterAdded:Connect(function() task.defer(paint) end)
	task.spawn(function()
		while sg.Parent do
			local tg = pgui:FindFirstChild("TouchGui")
			local jump = tg and tg:FindFirstChild("JumpButton", true)
			if jump and jump.AbsoluteSize.X > 0 then
				local inset = game:GetService("GuiService"):GetGuiInset()
				local c = jump.AbsolutePosition + jump.AbsoluteSize / 2 + inset
				local d = jump.AbsoluteSize.X * 0.95
				btn.Size = UDim2.fromOffset(d * 0.72, d * 0.72)
				btn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
				btn.Position = UDim2.fromOffset(c.X - d * 1.05, c.Y - d * 0.35)
				btn.Visible = tg.Enabled and player:GetAttribute("Building") ~= true
			else
				btn.Visible = false
			end
			task.wait(0.5)
		end
	end)
end

local layoutGroups -- forward (the quest panel follows the bar)
-- keep the top bar clear of Roblox's own buttons: if its scaled width reaches into the top-left inset,
-- it drops below it
do
	local GuiService = game:GetService("GuiService")
	local home = groups.Top.home
	local function fit()
		if PHONE then return end -- phoneLayout owns the phone HUD
		local inset = GuiService.TopbarInset
		local vw = hud.AbsoluteSize.X
		local w = groups.Top.frame.AbsoluteSize.X
		local left = (vw - w) / 2
		local clash = inset.Max.X > 0 and left < inset.Max.X + 8
		groups.Top.home = clash and UDim2.new(0.5, 0, 0, inset.Max.Y + 4) or home
		if groups.Top.frame.Position.Y.Offset >= 0 then groups.Top.frame.Position = groups.Top.home end
		if layoutGroups then layoutGroups() end
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.delay(1, fit)
end

---------------------------------------------------------------- toasts (Shared.UI.toast; build mode and the menu borrow it too)

-- round 20: only the important stuff toasts: confirmations and flavor (autosaved, visiting, invites
-- sent, renames...) stay quiet; errors, research, level-ups and real news still show
local QUIET = {
	"Game autosaved", "Visiting ", "Invite sent to", "said no thanks", "said not right now",
	"went back to their hotel", "Hotel renamed", "is coming to stay", "helping at", "Asked ",
	"That invite ran out",
}

local function toast(text, icon, bad, good)
	if type(text) == "string" then
		for _, q in ipairs(QUIET) do
			if text:find(q, 1, true) then return end
		end
	end
	UI.toast(text, icon and (ICON[icon] or icon) or nil, bad and "bad" or good and "good" or nil)
end

---------------------------------------------------------------- world popups (+$45)

local function worldPop(pos, text, color, icon)
	if player:GetAttribute("HidePops") then return end -- Settings > Money pop-ups (round 12)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = pos
	part.Parent = workspace.CurrentCamera
	local bb = UI.new("BillboardGui", { Name = "Pop", Size = UDim2.fromOffset(240, 64), AlwaysOnTop = true, Adornee = part, LightInfluence = 0, Parent = pgui })
	local row = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	UI.list(row, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if icon then UI.icon(row, ICON[icon] or icon, 44, { LayoutOrder = 1 }) end
	local t = UI.new("TextLabel", {
		Text = text, TextSize = 34, FontFace = UI.F.black, TextColor3 = color or Color3.fromRGB(160, 250, 140),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = row,
	})
	UI.textStroke(t, 3, 0.1)
	UI.pop(row, 0.3, 0.4)
	UI.tween(bb, 1.4, { StudsOffset = Vector3.new(0, 4.5, 0) }, Enum.EasingStyle.Quint)
	task.delay(0.85, function()
		UI.tween(t, 0.5, { TextTransparency = 1 })
		for _, d in ipairs(row:GetDescendants()) do
			if d:IsA("ImageLabel") then UI.tween(d, 0.5, { ImageTransparency = 1 }) end
			if d:IsA("UIStroke") then UI.tween(d, 0.5, { Transparency = 1 }) end
		end
	end)
	task.delay(1.45, function()
		bb:Destroy()
		part:Destroy()
	end)
end

---------------------------------------------------------------- day summary

local summaryOpen = false
local function daySummary(d)
	if summaryOpen or player:GetAttribute("HideDaySummary") then return end
	summaryOpen = true
	local layer = UI.new("Frame", { Name = "DaySummary", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hud })
	local dim = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 1, Parent = layer })
	UI.tween(dim, 0.3, { BackgroundTransparency = 0.5 })
	local wrap = UI.new("Frame", { Size = UDim2.fromOffset(560, 380), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = layer })
	UI.autoScale(wrap)
	local holder, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { name = "Card" })
	UI.icon(body, ICON.star, 64, { Position = UDim2.new(0.5, 0, 0, 18), AnchorPoint = Vector2.new(0.5, 0) })
	UI.label(body, "Day " .. d.day .. " complete", 30, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 34) })
	UI.label(body, "Here's how your hotel did", 15, { FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 18) })
	local tiles = UI.new("Frame", { Size = UDim2.new(1, -48, 0, 120), Position = UDim2.fromOffset(24, 150), BackgroundTransparency = 1, Parent = body })
	UI.list(tiles, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	local stats = {
		{ icon = "guest", value = d.guests or 0, text = "guests served", color = T.cream },
		{ icon = "sparkle", value = d.cleans or 0, text = "rooms cleaned", color = T.blue },
		{ icon = "cash", value = d.earned or 0, text = "earned", color = T.green, money = true },
	}
	if (d.wages or 0) > 0 then
		table.insert(stats, { icon = "staff", value = d.wages, text = "staff wages", color = T.red, money = true })
	end
	if (d.upkeep or 0) > 0 then
		table.insert(stats, { icon = "hammer", value = d.upkeep, text = "season upkeep", color = T.red, money = true })
	end
	for i, s in ipairs(stats) do
		local tile = UI.new("Frame", { Size = UDim2.fromOffset(160, 120), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = tiles })
		UI.corner(tile, 14)
		UI.stroke(tile, 1.5, T.line, 0.4)
		UI.icon(tile, ICON[s.icon], 38, { Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0) })
		local v = UI.label(tile, "0", 30, { FontFace = UI.F.black, TextColor3 = s.color, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 34) })
		UI.label(tile, s.text, 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 18) })
		task.delay(0.35 + i * 0.15, function()
			UI.countTo(v, s.value, function(x) return (s.money and "$" or "") .. UI.commas(x) end, 0.9)
			UI.pop(tile, 1.1)
		end)
	end
	UI.stagger(tiles, 0.08)
	if d.uncollected and d.uncollected > 0 then
		UI.label(body, "Your safe still holds $" .. UI.commas(d.uncollected) .. ". Go and collect it!", 15, {
			FontFace = UI.F.heavy, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 282), Size = UDim2.new(1, 0, 0, 18),
		})
	end
	local close
	local btn = UI.button(body, {
		text = "Continue", kind = "gold", size = UDim2.fromOffset(200, 46), pos = UDim2.new(0.5, 0, 1, -22), anchor = Vector2.new(0.5, 1),
		onClick = function() close() end,
	})
	UI.open(holder, { from = 0.7, rise = 30 })
	UI.sound("Fanfare")
	close = function()
		if not layer.Parent or not summaryOpen then return end
		summaryOpen = false
		UI.tween(dim, 0.25, { BackgroundTransparency = 1 })
		UI.close(holder, function() layer:Destroy() end)
	end
	dim.Activated:Connect(close)
	task.delay(9, close)
end

---------------------------------------------------------------- tutorial card

local TutSkip = Shared.Remotes:WaitForChild("TutSkip")
local tutCard

local function showTut(d)
	if tutCard then
		local old = tutCard
		tutCard = nil
		UI.close(old, function() old:Destroy() end)
	end
	if d.done then
		if not d.skipped then toast("You're all set! Your hotel is open for business", "star", false, true) end
		return
	end
	local f = plate(tutWrap, { Name = "Card", Size = UDim2.fromScale(1, 1), radius = 18, Visible = false })
	f.BackgroundTransparency = 0.15
	f:FindFirstChildOfClass("UIStroke").Color = T.gold
	local ib = UI.new("Frame", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink2, Parent = f })
	UI.corner(ib, 16)
	local ic = UI.icon(ib, ICON[d.icon] or ICON.star, 50, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	task.spawn(function()
		while ic.Parent do
			UI.tween(ic, 0.9, { Rotation = 6 }, Enum.EasingStyle.Sine)
			task.wait(0.9)
			UI.tween(ic, 0.9, { Rotation = -6 }, Enum.EasingStyle.Sine)
			task.wait(0.9)
		end
	end)
	UI.label(f, "TUTORIAL  " .. d.step .. " / " .. d.total, 13, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(94, 12), Size = UDim2.new(1, -150, 0, 16) })
	UI.label(f, d.text, 18, {
		FontFace = UI.F.heavy, TextColor3 = T.cream, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(94, 32), Size = UDim2.new(1, -150, 0, 44),
	})
	-- progress dots
	local dots = UI.new("Frame", { Size = UDim2.new(1, -150, 0, 6), Position = UDim2.new(0, 94, 1, -14), BackgroundTransparency = 1, Parent = f })
	UI.list(dots, Enum.FillDirection.Horizontal, 4)
	for i = 1, d.total do
		local dot = UI.new("Frame", { Size = UDim2.new(1 / d.total, -4, 1, 0), BackgroundColor3 = i <= d.step and T.gold or T.ink3, LayoutOrder = i, Parent = dots })
		UI.corner(dot, 3)
	end
	local x = UI.closeButton(f, function()
		TutSkip:FireServer()
		if tutCard == f then
			tutCard = nil
			UI.close(f, function() f:Destroy() end)
		end
	end)
	x.Position = UDim2.new(1, -12, 0.5, 0)
	x.AnchorPoint = Vector2.new(1, 0.5)
	tutCard = f
	UI.open(f, { from = 0.8, rise = -14 })
end

---------------------------------------------------------------- level up (round 10c remake)

local levelGui = UI.new("ScreenGui", { Name = "LevelUp", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 35, Parent = pgui })
for _, g in ipairs(pgui:GetChildren()) do
	if g.Name == "LevelUp" and g ~= levelGui then g:Destroy() end
end
local levelQueue, levelShowing = {}, false

local function confetti(layer, n)
	local colors = { T.gold, T.green, T.blue, T.violet, T.red, T.cream }
	for _ = 1, n do
		local x = math.random()
		local c = UI.new("Frame", {
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)), Position = UDim2.new(x, 0, -0.05, 0),
			Rotation = math.random(0, 360), BackgroundColor3 = colors[math.random(1, #colors)], ZIndex = 2, Parent = layer,
		})
		UI.corner(c, 3)
		local t = math.random(22, 36) / 10
		UI.tween(c, t, { Position = UDim2.new(x + (math.random() - 0.5) * 0.25, 0, 1.08, 0), Rotation = c.Rotation + math.random(-540, 540) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, math.random() * 0.6)
		task.delay(t + 0.8, function() c:Destroy() end)
	end
end

-- a gold rule either side of a heading
local function ruled(parent, text, y, width)
	local row = UI.new("Frame", { Size = UDim2.fromOffset(width, 24), Position = UDim2.new(0.5, 0, 0, y), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = parent })
	local l = UI.label(row, text, 18, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	for side = 0, 1 do
		local r = UI.new("Frame", { Size = UDim2.new(0.5, -100, 0, 2), Position = UDim2.new(side * 0.5, side == 0 and 0 or 100, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.gold, BorderSizePixel = 0, Parent = row })
		UI.grad(r, T.gold, T.gold, 0).Transparency = NumberSequence.new(side == 0 and 1 or 0.1, side == 0 and 0.1 or 1)
	end
	return row, l
end

local UNLOCK_KIND = { feature = "NEW FEATURE", room = "NEW ROOM", staff = "NEW HIRE", research = "RESEARCH", item = "BUILD SHOP" }

local showLevelUp
showLevelUp = function(d)
	levelShowing = true
	local list = d.unlocks or {}
	local layer = UI.new("Frame", { Name = "LevelUp", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = levelGui })
	-- the dim catches clicks so nothing behind it gets pressed; only AWESOME! closes the card
	local dim = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 1, Parent = layer })
	UI.tween(dim, 0.35, { BackgroundTransparency = 0.28 })
	local shownTiles = math.min(#list, 5)
	local H = shownTiles > 0 and 736 or 520
	local wrap = UI.new("Frame", { Size = UDim2.fromOffset(860, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3, Parent = layer })
	UI.autoScale(wrap)
	-- slow rays and a soft glow behind the star
	local rays = UI.new("Frame", { Size = UDim2.fromOffset(700, 700), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = wrap })
	for i = 1, 12 do
		local r = UI.new("Frame", { Size = UDim2.fromOffset(46, 700), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = i * 15, BackgroundColor3 = T.gold, BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = rays })
		UI.grad(r, T.gold, T.gold, 90).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(1, 1) })
	end
	-- a soft round glow: rings that fade outwards
	local glows = {}
	for i, r in ipairs({ 430, 340, 260, 190 }) do
		local g = UI.new("Frame", { Size = UDim2.fromOffset(r, r), Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 214, 120), BackgroundTransparency = 0.93 - i * 0.03, Parent = wrap })
		UI.corner(g, r / 2)
		glows[i] = g
	end
	-- the star with the new level
	local star = UI.icon(wrap, ICON.star, 250, { Position = UDim2.new(0.5, 0, 0, 150), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	local num = UI.label(star, tostring(d.level), 92, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 12), ZIndex = 5 })
	UI.textStroke(num, 5, 0).Color = Color3.fromRGB(130, 70, 8)
	-- twinkles round the star
	local twinkles = {}
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2 + 0.4
		local tw = UI.icon(wrap, ICON.sparkle, math.random(26, 40), {
			Position = UDim2.new(0.5, math.cos(a) * 170, 0, 150 + math.sin(a) * 120), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 1, ZIndex = 5,
		})
		twinkles[i] = tw
	end
	local title = UI.label(wrap, "LEVEL UP!", 70, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 270), Size = UDim2.new(1, 0, 0, 78), TextTransparency = 1, ZIndex = 4 })
	UI.grad(title, Color3.fromRGB(255, 250, 226), Color3.fromRGB(255, 196, 78), 90)
	local titleStroke = UI.textStroke(title, 5, 1)
	titleStroke.Color = Color3.fromRGB(100, 54, 8)
	local sub = UI.label(wrap, "Your hotel reached Level " .. d.level .. "!", 25, { FontFace = UI.F.heavy, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 346), Size = UDim2.new(1, 0, 0, 30), TextTransparency = 1, ZIndex = 4 })
	local subStroke = UI.textStroke(sub, 2, 1)
	-- the cash reward
	local reward = UI.new("Frame", { Size = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 0, 386), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.ink, BackgroundTransparency = 0.1, Visible = false, ZIndex = 4, Parent = wrap })
	UI.corner(reward, 22)
	UI.stroke(reward, 1.5, T.green, 0.3)
	UI.pad(reward, 8, 0, 18, 0)
	UI.list(reward, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center)
	UI.icon(reward, ICON.cash, 34, { LayoutOrder = 1, ZIndex = 5 })
	UI.new("TextLabel", {
		Text = "+$" .. UI.commas(d.cash or 0) .. " reward", TextSize = 22, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(160, 245, 150),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, ZIndex = 5, Parent = reward,
	})
	-- what just unlocked: cards with a NEW badge
	local tiles = {}
	local header
	if shownTiles > 0 then
		header = ruled(wrap, "NEW UNLOCKS", 448, 760)
		header.Visible = false
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromOffset(0, 484), BackgroundTransparency = 1, Parent = wrap })
		UI.list(row, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
		for i = 1, shownTiles do
			local u = list[i]
			local holder = UI.new("Frame", { Size = UDim2.fromOffset(142, 150), BackgroundTransparency = 1, LayoutOrder = i, Visible = false, Parent = row })
			local tile = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, BackgroundTransparency = 0.04, Parent = holder })
			UI.corner(tile, 18)
			UI.grad(tile, Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 202, 226), 90)
			UI.stroke(tile, 2, T.gold, 0.25)
			local bg = UI.new("Frame", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.ink2, Parent = tile })
			UI.corner(bg, 40)
			UI.icon(bg, ICON[u.icon] or ICON.star, 62, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
			UI.label(tile, UNLOCK_KIND[u.kind] or "UNLOCKED", 11, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 13) })
			UI.label(tile, u.name, 15, { FontFace = UI.F.heavy, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 110), Size = UDim2.new(1, -16, 0, 36) })
			local badge = UI.new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(52, 26), Position = UDim2.new(1, -4, 0, 4),
				AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 12, ZIndex = 4, Parent = holder,
			})
			UI.corner(badge, 8)
			UI.grad(badge, Color3.fromRGB(255, 120, 120), T.redDk, 90)
			UI.stroke(badge, 2, Color3.fromRGB(110, 20, 34), 0)
			UI.label(badge, "NEW", 15, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
			table.insert(tiles, holder)
		end
		if #list > shownTiles then
			local more = UI.new("Frame", { Size = UDim2.fromOffset(96, 150), BackgroundColor3 = T.ink, LayoutOrder = 99, Visible = false, Parent = row })
			UI.corner(more, 18)
			UI.stroke(more, 2, T.line, 0.3)
			UI.label(more, "+" .. (#list - shownTiles) .. "\nmore", 22, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
			table.insert(tiles, more)
		end
	else
		local hint = UI.label(wrap, "Keep going: something new unlocks every few levels", 16, {
			FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 444), Size = UDim2.new(1, 0, 0, 20),
		})
		table.insert(tiles, hint)
		hint.Visible = false
	end
	local closed = false
	local close
	local btn = UI.button(wrap, {
		text = "AWESOME!", kind = "green", size = UDim2.fromOffset(270, 62), textSize = 27, pos = UDim2.new(0.5, 0, 1, -10), anchor = Vector2.new(0.5, 1),
		onClick = function() close() end,
	})
	btn.Visible = false
	-- in it comes
	local sc = UI.scaleOf(star)
	sc.Scale = 0.15
	star.Rotation = -40
	UI.tween(sc, 0.65, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(star, 0.8, { Rotation = 0 }, Enum.EasingStyle.Back)
	-- round 11: no UI fanfare here, Audio plays the level-up sting
	confetti(layer, 90)
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 10
		local t = os.clock()
		for i, g in ipairs(glows) do
			if not closed then g.BackgroundTransparency = 0.93 - i * 0.03 + math.sin(t * 2 + i * 0.5) * 0.02 end
		end
		for i, tw in ipairs(twinkles) do
			local k = (math.sin(t * 2.4 + i * 1.7) + 1) / 2
			if not closed then tw.ImageTransparency = 1 - k * 0.9 end
			tw.Rotation = t * 40 + i * 30
		end
	end)
	task.delay(0.25, function()
		title.Position = UDim2.fromOffset(0, 296)
		UI.tween(title, 0.5, { TextTransparency = 0, Position = UDim2.fromOffset(0, 270) }, Enum.EasingStyle.Back)
		UI.tween(titleStroke, 0.5, { Transparency = 0 })
	end)
	task.delay(0.45, function()
		UI.tween(sub, 0.4, { TextTransparency = 0 })
		UI.tween(subStroke, 0.4, { Transparency = 0.3 })
	end)
	task.delay(0.65, function()
		if (d.cash or 0) > 0 then
			reward.Visible = true
			UI.pop(reward, 0.5, 0.4)
			UI.sound("Coins")
		end
	end)
	task.delay(0.85, function()
		if header then
			header.Visible = true
			UI.pop(header, 0.7, 0.3)
		end
		for i, t in ipairs(tiles) do
			task.delay((i - 1) * 0.1, function()
				t.Visible = true
				UI.pop(t, 0.4, 0.45)
				UI.sound("Tick")
			end)
		end
	end)
	task.delay(1.1 + #tiles * 0.1, function()
		btn.Visible = true
		UI.pop(btn, 0.5, 0.4)
	end)
	close = function()
		if closed then return end
		closed = true
		UI.tween(dim, 0.3, { BackgroundTransparency = 1 })
		UI.tween(sc, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, x in ipairs(wrap:GetDescendants()) do
			if x:IsA("TextLabel") then UI.tween(x, 0.25, { TextTransparency = 1 }) end
			if x:IsA("ImageLabel") then UI.tween(x, 0.25, { ImageTransparency = 1 }) end
			if (x:IsA("Frame") or x:IsA("TextLabel")) and x.BackgroundTransparency < 1 then UI.tween(x, 0.25, { BackgroundTransparency = 1 }) end
			if x:IsA("UIStroke") then UI.tween(x, 0.25, { Transparency = 1 }) end
		end
		task.delay(0.35, function()
			spin:Disconnect()
			layer:Destroy()
			levelShowing = false
			local nextD = table.remove(levelQueue, 1)
			if nextD then showLevelUp(nextD) end
		end)
	end
end

---------------------------------------------------------------- chapter goals (round 10c): the right side

local QW = 344
local questWrap = group("Quests", UDim2.fromOffset(QW, 330), UDim2.new(1, -16, 0.5, -120), Vector2.new(1, 0), UDim2.new(1, QW + 60, 0.5, -120))

if PHONE then
	local function phoneLayout()
		local vp = workspace.CurrentCamera.ViewportSize
		local ti = GuiService.TopbarInset
		local rowH = math.max(ti.Height, 36)
		local topY = rowH + 4
		local k = math.min((vp.X - 24) / 460, 0.5)
		local tb = groups.Top
		tb.frame.AutoScale.Scale = k
		tb.home = UDim2.fromOffset(vp.X / 2, topY)
		tb.frame.Position = tb.home
		tb.away = tb.home - UDim2.fromOffset(0, 160)
		local ck = groups.Clock
		ck.frame.AutoScale.Scale = k
		ck.home = UDim2.fromOffset(vp.X - 10, topY)
		ck.frame.Position = ck.home
		ck.away = ck.home + UDim2.fromOffset(240, 0)
		local cn = groups.Corner
		cn.frame.AutoScale.Scale = k
		cn.home = UDim2.fromOffset(10, vp.Y - 10)
		cn.frame.Position = cn.home
		cn.away = cn.home - UDim2.fromOffset(440, 0)
		local barBottom = topY + 76 * k
		local qg = groups.Quests
		local qk = math.clamp(vp.Y / 900, 0.36, 0.48)
		qg.frame.AutoScale.Scale = qk
		qg.home = UDim2.new(1, -10, 0.5, -120)
		qg.away = UDim2.new(1, QW + 60, 0.5, -120)
		qg.frame.Position = qg.home
		hud:SetAttribute("PhoneBarBottom", barBottom)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(phoneLayout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(phoneLayout)
	task.defer(phoneLayout)
end

-- the header: clipboard badge, chapter and title, how many are done, a collapse arrow
local qHead = UI.new("TextButton", { Name = "Header", Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = questWrap })
local qHeadPill = plate(qHead, { Name = "Pill", Size = UDim2.new(1, -22, 0, 52), Position = UDim2.fromOffset(22, 3), radius = 18 })
qHeadPill.BackgroundTransparency = 0.15
qHeadPill:FindFirstChildOfClass("UIStroke").Color = T.gold
local qBadge = UI.icon(qHead, ICON.quest, 64, { Position = UDim2.fromOffset(-8, -3), ZIndex = 3 })
local qChapter = UI.label(qHeadPill, "CHAPTER 1", 12, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(46, 7), Size = UDim2.new(1, -130, 0, 14) })
local qTitle = UI.label(qHeadPill, "", 19, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(46, 21), Size = UDim2.new(1, -120, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
local qCount = UI.label(qHeadPill, "0/5", 15, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -48, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(50, 52) })
local qArrowBg = UI.new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.ink2, Parent = qHeadPill })
UI.corner(qArrowBg, 15)
local qArrow = UI.icon(qArrowBg, ICON.up, 22, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
-- a thin bar under the title: the chapter's progress
local chTrack = UI.new("Frame", { Size = UDim2.new(1, -60, 0, 4), Position = UDim2.new(0, 46, 1, -6), BackgroundColor3 = T.ink2, BorderSizePixel = 0, Parent = qHeadPill })
UI.corner(chTrack, 2)
local chFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.gold, BorderSizePixel = 0, Parent = chTrack })
UI.corner(chFill, 2)

local qList = UI.new("Frame", { Name = "List", Size = UDim2.new(1, 0, 0, 3 * 88), Position = UDim2.fromOffset(0, 66), BackgroundTransparency = 1, Parent = questWrap })
UI.list(qList, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)

local cards = {} -- quest id -> card bits
local completing = 0
local shownCh = nil
local collapsed = false
local renderQuests

local function questState()
	local json = HOTEL:GetAttribute("Quests")
	local st
	if type(json) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(t) == "table" then st = t end
	end
	st = st or {}
	st.ch = tonumber(st.ch) or 1
	st.p = type(st.p) == "table" and st.p or {}
	st.done = type(st.done) == "table" and st.done or {}
	return st
end

local function makeCard(q)
	local holder = UI.new("Frame", { Name = q.id, Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1, LayoutOrder = q.order, Parent = qList })
	local card = UI.new("CanvasGroup", { Name = "Card", Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(22, 0), BackgroundColor3 = T.paper or T.ink, Parent = holder })
	UI.corner(card, 16)
	local stroke = UI.stroke(card, 2.5, T.outline or T.line, 0)
	local tile = UI.new("Frame", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink2, Parent = card })
	UI.corner(tile, 14)
	UI.stroke(tile, 1.5, T.line, 0.4)
	local ic = UI.icon(tile, ICON[q.icon] or ICON.star, 44, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	UI.label(card, q.text, 16, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(80, 10), Size = UDim2.new(1, -90, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
	local track = UI.new("Frame", { Size = UDim2.new(1, -172, 0, 20), Position = UDim2.fromOffset(80, 44), BackgroundColor3 = T.ink2, Parent = card })
	UI.corner(track, 10)
	UI.stroke(track, 1, T.line, 0.4)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.corner(fill, 10)
	local fillGrad = UI.grad(fill, Color3.fromRGB(255, 226, 140), T.goldDk, 90)
	local prog = UI.label(track, "", 13, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	UI.textStroke(prog, 1.5, 0.2)
	-- the reward: cash on top, XP under it
	local rew = UI.new("Frame", { Size = UDim2.fromOffset(84, 50), Position = UDim2.new(1, -8, 0, 26), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Parent = card })
	UI.list(rew, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Right)
	local cashRow = UI.new("Frame", { Size = UDim2.fromOffset(84, 24), BackgroundTransparency = 1, LayoutOrder = 1, Parent = rew })
	UI.list(cashRow, Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	UI.icon(cashRow, ICON.cash, 22, { LayoutOrder = 1 })
	UI.new("TextLabel", { Text = "+$" .. UI.commas(q.cash or 0), TextSize = 16, FontFace = UI.F.black, TextColor3 = T.greenDk, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = cashRow })
	if (q.xp or 0) > 0 then
		UI.label(rew, "+" .. q.xp .. " XP", 12, { FontFace = UI.F.black, TextColor3 = T.violetDk, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(84, 16), LayoutOrder = 2 })
	end
	local c = { q = q, holder = holder, card = card, stroke = stroke, tile = tile, ic = ic, fill = fill, fillGrad = fillGrad, prog = prog, shown = -1 }
	cards[q.id] = c
	return c
end

local function setProgress(c, n)
	n = math.min(n or 0, c.q.goal)
	if n == c.shown then return end
	local grew = c.shown >= 0 and n > c.shown
	c.shown = n
	c.prog.Text = Q.progressText(c.q, n)
	UI.tween(c.fill, 0.5, { Size = UDim2.fromScale(math.clamp(n / c.q.goal, 0, 1), 1) }, Enum.EasingStyle.Quint)
	if grew then
		UI.pop(c.tile, 1.15, 0.3)
		UI.sound("Tick")
	end
end

local function completeCard(id)
	local c = cards[id]
	if not c or c.completing then return end
	c.completing = true
	completing += 1
	setProgress(c, c.q.goal)
	c.prog.Text = "COMPLETE!"
	c.fillGrad.Color = ColorSequence.new(Color3.fromRGB(170, 250, 170), T.greenDk)
	c.stroke.Color = T.green
	c.stroke.Transparency = 0
	c.ic.ImageTransparency = 0.55
	local chk = UI.icon(c.tile, ICON.checkmark, 46, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
	UI.pop(chk, 0.2, 0.45)
	UI.pop(c.holder, 1.07, 0.35)
	UI.sound("Coins")
	-- a shine sweeps across the card
	local shine = UI.new("Frame", { Size = UDim2.new(0, 70, 1, 0), Position = UDim2.new(0, -80, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.4, BorderSizePixel = 0, Rotation = 0, ZIndex = 6, Parent = c.card })
	UI.grad(shine, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	UI.tween(shine, 0.7, { Position = UDim2.new(1, 10, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.1)
	task.delay(1.8, function()
		UI.tween(c.card, 0.35, { Position = UDim2.fromOffset(QW + 40, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.35)
		c.card.Visible = false
		UI.tween(c.holder, 0.25, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quad)
		task.wait(0.27)
		c.holder:Destroy()
		cards[id] = nil
		completing -= 1
		renderQuests()
	end)
end

renderQuests = function()
	local st = questState()
	local ch = Q.CHAPTERS[st.ch]
	if st.ch ~= shownCh then
		local first = shownCh == nil
		shownCh = st.ch
		qChapter.Text = ch and ("CHAPTER " .. st.ch) or "ALL CHAPTERS DONE"
		qTitle.Text = ch and ch.title or "More goals coming soon"
		if not first then UI.pop(qHeadPill, 1.1, 0.4) end
		-- a new chapter: the old cards go (any still finishing play out first)
		for id, c in pairs(cards) do
			if not c.completing then
				c.holder:Destroy()
				cards[id] = nil
			end
		end
	end
	local done = 0
	if ch then
		for _, q in ipairs(ch.quests) do
			if st.done[q.id] then done += 1 end
		end
		qCount.Text = done .. "/" .. #ch.quests
		UI.tween(chFill, 0.5, { Size = UDim2.fromScale(done / #ch.quests, 1) })
	else
		qCount.Text = ""
		chFill.Size = UDim2.fromScale(1, 1)
	end
	-- finished cards celebrate before they leave
	for id, c in pairs(cards) do
		if st.done[id] then
			completeCard(id)
		else
			setProgress(c, st.p[id])
		end
	end
	-- new cards wait until the finished ones have gone
	if completing > 0 then return end
	local want = Q.visible(st)
	local wantSet = {}
	for _, q in ipairs(want) do wantSet[q.id] = true end
	for id, c in pairs(cards) do
		if not wantSet[id] then
			c.holder:Destroy()
			cards[id] = nil
		end
	end
	local delay = 0
	for _, q in ipairs(want) do
		if not cards[q.id] then
			local c = makeCard(q)
			setProgress(c, st.p[q.id])
			-- slide in from the right
			c.card.Position = UDim2.fromOffset(QW + 40, 0)
			c.card.GroupTransparency = 1
			UI.tween(c.card, 0.5, { Position = UDim2.fromOffset(22, 0), GroupTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, delay)
			delay += 0.08
		end
	end
end
HOTEL:GetAttributeChangedSignal("Quests"):Connect(renderQuests)
renderQuests()

-- the header folds the list away (and back)
local function setCollapsed(on)
	collapsed = on
	UI.tween(qArrow, 0.3, { Rotation = on and 180 or 0 }, Enum.EasingStyle.Back)
	if on then
		local i = 0
		for _, c in pairs(cards) do
			UI.tween(c.card, 0.25, { Position = UDim2.fromOffset(QW + 40, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, i * 0.04)
			i += 1
		end
		task.delay(0.3, function() if collapsed then qList.Visible = false end end)
	else
		qList.Visible = true
		local i = 0
		for _, c in pairs(cards) do
			if not c.completing then
				UI.tween(c.card, 0.4, { Position = UDim2.fromOffset(22, 0), GroupTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, i * 0.05)
			end
			i += 1
		end
	end
end
qHead.Activated:Connect(function()
	UI.sound("Click")
	setCollapsed(not collapsed)
end)
local qSc = UI.scaleOf(qHead)
qHead.MouseEnter:Connect(function() UI.tween(qSc, 0.18, { Scale = 1.03 }, Enum.EasingStyle.Back) end)
qHead.MouseLeave:Connect(function() UI.tween(qSc, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint) end)
UI.tooltip(qHead, "Chapter goals: finish them for cash and XP")

-- a chapter done: a banner across the middle, then the next chapter's name
local function chapterBanner(d)
	local layer = UI.new("Frame", { Name = "Chapter", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = levelGui })
	local wrap = UI.new("Frame", { Size = UDim2.fromOffset(700, 170), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = layer })
	UI.autoScale(wrap)
	local ribbon = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, BackgroundTransparency = 0.04, Parent = wrap })
	UI.corner(ribbon, 24)
	UI.grad(ribbon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(196, 202, 226), 90)
	UI.stroke(ribbon, 3, T.gold, 0)
	UI.icon(wrap, ICON.quest, 110, { Position = UDim2.new(0, -30, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local top = UI.label(ribbon, "CHAPTER " .. ((d.ch or 2) - 1) .. " COMPLETE", 18, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(60, 22), Size = UDim2.new(1, -80, 0, 22) })
	local big = UI.label(ribbon, d.done or "", 46, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(60, 48), Size = UDim2.new(1, -80, 0, 56) })
	UI.textStroke(big, 3, 0.2)
	local low = UI.label(ribbon, "Rewards paid. Nice work!", 17, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(60, 112), Size = UDim2.new(1, -80, 0, 22) })
	UI.open(ribbon, { from = 0.5, rise = -20 })
	UI.pop(wrap, 0.6, 0.5)
	-- round 11: Audio plays the chapter sting
	confetti(layer, 60)
	task.delay(2.2, function()
		if not d.title then return end
		for _, l in ipairs({ top, big, low }) do UI.tween(l, 0.2, { TextTransparency = 1 }) end
		task.wait(0.22)
		top.Text = "CHAPTER " .. d.ch
		big.Text = d.title
		low.Text = "New goals on the right"
		for _, l in ipairs({ top, big, low }) do UI.tween(l, 0.3, { TextTransparency = 0 }) end
		UI.pop(ribbon, 1.1, 0.35)
		UI.sound("Open")
	end)
	task.delay(5, function()
		UI.close(ribbon, function() layer:Destroy() end)
	end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "quest" then
		completeCard(d.id)
	elseif kind == "chapter" then
		chapterBanner(d)
	end
end)

---------------------------------------------------------------- show / hide (build mode) and arrival

-- the quest panel sits mid-right, whatever its scale
local hidden = false
function layoutGroups()
	if PHONE then return end -- phoneLayout owns the phone HUD
	local s = groups.Quests.frame:FindFirstChild("AutoScale")
	local k = s and s.Scale or 1
	groups.Quests.home = UDim2.new(1, -16, 0.5, -120)
	groups.Quests.away = UDim2.new(1, QW * k + 60, 0.5, -120)
	if not hidden and not (player:GetAttribute("HideQuests") == true or player:GetAttribute("MenuOpen") == true) then groups.Quests.frame.Position = groups.Quests.home end
end
layoutGroups()
-- the goals step aside when switched off in Settings and while the menu window is open
local function questsOff()
	return player:GetAttribute("HideQuests") == true or player:GetAttribute("MenuOpen") == true
end
local function setHidden(h)
	if h == hidden then return end
	hidden = h
	for name, g in pairs(groups) do
		local away = h or (name == "Quests" and questsOff())
		UI.tween(g.frame, h and 0.3 or 0.45, { Position = away and g.away or g.home }, h and Enum.EasingStyle.Quad or Enum.EasingStyle.Back, h and Enum.EasingDirection.In or Enum.EasingDirection.Out)
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	task.defer(function()
		layoutGroups()
		if not hidden and not questsOff() then groups.Quests.frame.Position = groups.Quests.home end
	end)
end)
player:GetAttributeChangedSignal("Building"):Connect(function() setHidden(player:GetAttribute("Building") == true) end)
setHidden(player:GetAttribute("Building") == true)

-- Settings > Chapter goals hides the panel; so does the menu
local function applyQuestSetting()
	local g = groups.Quests
	UI.tween(g.frame, 0.35, { Position = (questsOff() or hidden) and g.away or g.home }, Enum.EasingStyle.Quint)
end
player:GetAttributeChangedSignal("HideQuests"):Connect(applyQuestSetting)
player:GetAttributeChangedSignal("MenuOpen"):Connect(applyQuestSetting)

-- the HUD arrives: each group slides in from its edge, the bar's pills one after another
for _, g in pairs(groups) do
	g.frame.Position = g.away
	UI.tween(g.frame, 0.6, { Position = g.home }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.15)
end
if questsOff() then applyQuestSetting() end
for i, s in ipairs({ lvSlot, cashSlot, rateSlot, roomSlot, clockSlot }) do
	local sc = UI.scaleOf(s)
	sc.Scale = 0.3
	UI.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.2 + i * 0.06)
end

-- per frame: the counting cash, the clock, the dirty-rooms chip's slow glow
local clockAcc = 1
RunService.RenderStepped:Connect(function(dt)
	if cashT < 1 then
		cashT = math.min(1, cashT + dt / 0.9)
		local e = 1 - (1 - cashT) ^ 3
		shownCash = cashFrom + (cashTo - cashFrom) * e
		cashText.Text = money(shownCash)
	end
	clockAcc += dt
	if clockAcc > 0.5 then
		clockAcc = 0
		refreshClock()
	end
	if dirtyChip.Visible then
		local k = (math.sin(os.clock() * 3) + 1) / 2
		dirtyStroke.Transparency = 0.75 - k * 0.6
	end
end)

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "levelUp" then
		if levelShowing then table.insert(levelQueue, d) else showLevelUp(d) end
	elseif kind == "xp" then
		if d.pos then worldPop(d.pos + Vector3.new(0, 2.5, 0), "+" .. d.amount .. " XP", Color3.fromRGB(206, 182, 255), "star") end
		UI.pop(xpTrack, 1.08)
	elseif kind == "toast" then
		toast(d.text, d.icon, d.bad, d.kind == "good")
	elseif kind == "tut" then
		showTut(d)
	elseif kind == "day" then
		daySummary(d)
	elseif kind == "paid" or kind == "collect" then
		worldPop(d.pos, "+$" .. d.amount, nil, "cash")
	elseif kind == "cleaned" then
		worldPop(d.pos + Vector3.new(0, 1.5, 0), "Clean!", Color3.fromRGB(150, 220, 255), "sparkle")
	elseif kind == "plateUp" then
		worldPop(d.pos + Vector3.new(0, 2, 0), "Order up!", Color3.fromRGB(255, 200, 120), "food")
	elseif kind == "built" then
		if d.kind == "place" then
			worldPop(d.pos + Vector3.new(0, 4, 0), "-$" .. d.amount, Color3.fromRGB(255, 150, 130), "cash")
		elseif d.kind == "sell" then
			worldPop(d.pos + Vector3.new(0, 4, 0), "+$" .. d.amount, nil, "cash")
		end
	end
end)

-- round 12 settings: field of view (FOV) while walking about, and shadows (ShadowsOff, local only)
task.spawn(function()
	local Lighting = game:GetService("Lighting")
	while true do
		local cam = workspace.CurrentCamera
		if cam.CameraType == Enum.CameraType.Custom and player:GetAttribute("Building") ~= true and player:GetAttribute("Slot") then
			local want = player:GetAttribute("FOV") or 70
			if math.abs(cam.FieldOfView - want) > 0.5 then cam.FieldOfView += (want - cam.FieldOfView) * 0.35 end
		end
		local shadows = player:GetAttribute("ShadowsOff") ~= true
		if Lighting.GlobalShadows ~= shadows then Lighting.GlobalShadows = shadows end
		task.wait(0.05)
	end
end)

-- other scripts (the menu) borrow the toasts: Client.Toast:Fire(text, iconKey, bad)
local localToast = Instance.new("BindableEvent")
localToast.Name = "Toast"
localToast.Event:Connect(toast)
localToast.Parent = script

---------------------------------------------------------------- custom prompts (round 15 v2)
-- A glossy white capsule on a deep shadow, floating over the thing: a big shaded key disc in the prompt's colour
-- on the left (a ring round it fills while you hold), the action in fat letters with what it's for under it, and
-- the icon in a soft tinted disc on the right. A little tail points down at the spot. It springs in, bobs, glows
-- its colour on hover, sinks when pressed, and when it fires a shine sweeps it, sparkles pop and the icon flips
-- to a tick. Prompts carry attributes Icon (a C.ICONS key) and Color (yellow / green / blue / red).

local COLORS = {
	yellow = { T.sun, T.sunDk },
	green = { T.green, T.greenDk },
	blue = { T.blue, T.blueDk },
	red = { T.red, T.redDk },
	violet = { T.brand, T.brandDk },
}

local shown = {}

local function keyText(prompt)
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return nil end
	if UIS.GamepadEnabled and not UIS.KeyboardEnabled then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local PS = (player:GetAttribute("PromptSize") or 100) / 100
player:GetAttributeChangedSignal("PromptSize"):Connect(function()
	PS = (player:GetAttribute("PromptSize") or 100) / 100
end)
local CAP_RIM = Color3.fromRGB(204, 196, 244)
local function buildPrompt(prompt)
	local cols = COLORS[prompt:GetAttribute("Color") or "yellow"] or COLORS.yellow
	local hold = prompt.HoldDuration > 0
	local key = keyText(prompt)
	local H = 64

	local bb = UI.new("BillboardGui", { Name = "Prompt", Size = UDim2.fromOffset(680 * PS, 170 * PS), AlwaysOnTop = true, LightInfluence = 0, Active = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = prompt.Parent, Parent = pgui })
	local root = UI.new("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 16), Size = UDim2.fromScale(1 / PS, 1 / PS), BackgroundTransparency = 1, Parent = bb })
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = root
	-- the float wrapper carries the idle bob so no other animation ever fights over Position
	local float = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

	local wrap = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, H), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = float })
	UI.shadow(wrap, { drop = 9, transparency = 0.52, spread = 2 })
	-- the tail: a white wedge under the capsule pointing at the spot
	local tail = UI.new("ImageLabel", { Name = "Tail", Image = UI.IMG.tail, ImageColor3 = Color3.fromRGB(234, 230, 250), Size = UDim2.fromOffset(26, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -3), ZIndex = 1, Parent = wrap })
	local card = UI.new("Frame", { Name = "Card", Size = UDim2.fromOffset(0, H), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, ZIndex = 2, Parent = wrap })
	UI.corner(card, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 228, 250)), Parent = card })
	local baseRim = UI.rim(card, CAP_RIM, 2.5)
	baseRim.Name = "BaseRim"
	-- the colour glow ring (hover / hold)
	local hi = UI.new("Frame", { Name = "Hi", Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), BackgroundTransparency = 1, ZIndex = 1, Parent = card })
	UI.corner(hi, UDim.new(0.5, 0))
	local cardStroke = UI.rim(hi, cols[1], 3.5)
	cardStroke.Transparency = 1
	local gl = UI.new("Frame", { Name = "Gloss", Size = UDim2.new(1, -24, 0.42, 0), Position = UDim2.fromOffset(12, 3), BackgroundColor3 = T.white, BackgroundTransparency = 0.25, ZIndex = 2, Parent = card })
	UI.corner(gl, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1), Parent = gl })

	local content = UI.new("Frame", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3, Parent = card })
	UI.list(content, Enum.FillDirection.Horizontal, 12, nil, Enum.VerticalAlignment.Center)
	local contentPad = UI.pad(content, 7, 0, 10, 0)

	-- the key: a shaded disc in the prompt's colour inside a ring that fills clockwise while you hold
	local kc = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 3, Parent = content })
	local ringTrack = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3, Parent = kc })
	UI.corner(ringTrack, UDim.new(0.5, 0))
	UI.rim(ringTrack, Color3.fromRGB(226, 222, 246), 4)
	local track = UI.badge(kc, 42, cols[1], nil, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	local _, setRingRaw, ringStrokes = UI.ring(kc, 52, 4, cols[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 })
	local dsc = Instance.new("UIScale")
	dsc.Parent = kc
	local iconImg = ICON[prompt:GetAttribute("Icon") or "star"] or ICON.star
	if key then
		local kl = UI.new("TextLabel", {
			Name = "Key", Text = key, TextSize = #key > 1 and 14 or 24, FontFace = UI.F.display, TextColor3 = T.white,
			Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = track,
		})
		UI.textStroke(kl, 2, 0, cols[2])
	end

	-- the words
	local col = UI.new("Frame", { Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 3, Parent = content })
	UI.list(col, nil, 0, nil, Enum.VerticalAlignment.Center)
	local title = UI.new("TextLabel", { Text = prompt.ActionText, TextSize = 23, FontFace = UI.F.display, TextColor3 = T.cream, TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 4, Parent = col })
	local sub = UI.new("TextLabel", { Text = string.upper(prompt.ObjectText), TextSize = 13, FontFace = UI.F.heavy, TextColor3 = T.muted, TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 4, Parent = col })
	sub.Visible = prompt.ObjectText ~= ""
	if hold then
		sub.Visible = true
		sub.Text = (prompt.ObjectText ~= "" and (string.upper(prompt.ObjectText) .. "  -  ") or "") .. "HOLD"
	end

	-- the icon in a soft disc of the prompt's colour on the right
	local badge = UI.new("Frame", { Size = UDim2.fromOffset(48, 48), BackgroundColor3 = UI.shade(cols[1], 0.72), LayoutOrder = 3, ZIndex = 3, Parent = content })
	UI.corner(badge, UDim.new(0.5, 0))
	UI.rim(badge, UI.shade(cols[1], 0.2), 2)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 210, 228)), Parent = badge })
	local icon = UI.icon(badge, iconImg, 38, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	if not key then
		-- touch: the key disc has nothing to say, so the icon lives there instead and the right disc goes
		badge.Parent = track
		badge.Size = UDim2.fromScale(1, 1)
		badge.BackgroundTransparency = 1
		if badge:FindFirstChild("Rim") then badge.Rim.Enabled = false end
		icon.Size = UDim2.fromOffset(32, 32)
		icon.ZIndex = 8
		contentPad.PaddingRight = UDim.new(0, 22)
	end
	local playShine = UI.shine(card, 32)

	local function setRing(k)
		setRingRaw(math.clamp(k, 0, 1))
	end
	setRing(0)

	-- click / tap anywhere on the capsule = press the prompt
	local hit = UI.new("TextButton", { Text = "", Position = UDim2.fromOffset(-8, -8), Size = UDim2.new(1, 16, 1, 16), BackgroundTransparency = 1, ZIndex = 9, Parent = card })
	hit.MouseButton1Down:Connect(function() prompt:InputHoldBegin() end)
	hit.MouseButton1Up:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseLeave:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseEnter:Connect(function()
		UI.tween(sc, 0.2, { Scale = 1.07 * PS }, Enum.EasingStyle.Back)
		UI.tween(cardStroke, 0.15, { Transparency = 0.15 })
		playShine()
	end)
	hit.MouseLeave:Connect(function()
		UI.tween(sc, 0.2, { Scale = PS }, Enum.EasingStyle.Quint)
		UI.tween(cardStroke, 0.2, { Transparency = 1 })
	end)

	-- arrive: springs up from the spot, the key lands a beat later, the words fade in, a shine crosses
	UI.tween(sc, 0.46, { Scale = PS }, Enum.EasingStyle.Back)
	UI.tween(root, 0.46, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint)
	dsc.Scale = 0.2
	UI.tween(dsc, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.08)
	UI.tween(title, 0.22, { TextTransparency = 0 }, nil, nil, 0.1)
	UI.tween(sub, 0.22, { TextTransparency = 0 }, nil, nil, 0.16)
	task.delay(0.25, playShine)

	local s = { bb = bb, scale = sc, dsc = dsc, setRing = setRing, ringStrokes = ringStrokes, icon = icon, iconImg = iconImg, cols = cols, title = title, sub = sub, float = float, card = card, cardStroke = cardStroke, badge = badge, hold = hold, shine = playShine, wrap = wrap }
	s.conn = RunService.RenderStepped:Connect(function(dt)
		s.bob = (s.bob or 0) + dt
		s.float.Position = UDim2.fromScale(0.5, 0.5) - UDim2.fromOffset(0, math.sin(s.bob * 2.2) * 3)
		if s.holdT0 then
			setRing((os.clock() - s.holdT0) / math.max(prompt.HoldDuration, 0.01))
		end
	end)
	local c1 = prompt:GetPropertyChangedSignal("ActionText"):Connect(function() title.Text = prompt.ActionText end)
	local c2 = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		sub.Text = (prompt.ObjectText ~= "" and string.upper(prompt.ObjectText) or "") .. (hold and (prompt.ObjectText ~= "" and "  -  HOLD" or "HOLD") or "")
		sub.Visible = sub.Text ~= ""
	end)
	s.extra = { c1, c2 }
	return s
end

-- round 12: the desk buttons on guests (tag DeskPrompt) only show while you sit in a front desk chair
-- (a Seat named DeskSeat); the server checks it too. Prompts are switched locally, Busy = a game is running.
do
	local CS = game:GetService("CollectionService")
	local function seated()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local sp = hum and hum.SeatPart
		return sp ~= nil and sp.Name == "DeskSeat"
	end
	task.spawn(function()
		while true do
			local on = seated()
			for _, pr in ipairs(CS:GetTagged("DeskPrompt")) do
				local want = on and not pr:GetAttribute("Busy")
				if pr.Enabled ~= want then pr.Enabled = want end
			end
			task.wait(0.2)
		end
	end)
end

PPS.PromptShown:Connect(function(prompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	-- other people's hotels: no buttons (the server turns their prompts down too)
	if prompt:IsDescendantOf(PLOTS) and not prompt:IsDescendantOf(HOTEL) then return end
	if shown[prompt] then return end
	shown[prompt] = buildPrompt(prompt)
end)

-- prompts that land on top of each other on screen (Talk on a guest at the desk and Check In) stack upwards
do
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		local cam = workspace.CurrentCamera
		local list = {}
		for prompt, s in pairs(shown) do
			local ad = s.bb.Adornee
			local pos = ad and (ad:IsA("Attachment") and ad.WorldPosition or ad:IsA("BasePart") and ad.Position)
			if pos then
				local v, on = cam:WorldToViewportPoint(pos)
				if on then table.insert(list, { s = s, x = v.X, y = v.Y, key = prompt:GetFullName() }) end
			end
		end
		table.sort(list, function(a, b) return a.y > b.y or (a.y == b.y and a.key < b.key) end)
		local placed = {}
		for _, e in ipairs(list) do
			local lift = 0
			for _, o in ipairs(placed) do
				if math.abs(o.x - e.x) < 300 * PS and math.abs((o.y - o.lift * 76 * PS) - (e.y - lift * 76 * PS)) < 70 * PS then lift = o.lift + 1 end
			end
			e.lift = lift
			table.insert(placed, e)
			local want = Vector2.new(0, lift * 0.46)
			if e.s.bb.SizeOffset ~= want then e.s.bb.SizeOffset = want end
		end
	end)
end

PPS.PromptHidden:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	shown[prompt] = nil
	s.conn:Disconnect()
	for _, c in ipairs(s.extra) do c:Disconnect() end
	UI.tween(s.title, 0.12, { TextTransparency = 1 })
	UI.tween(s.sub, 0.12, { TextTransparency = 1 })
	local tw = UI.tween(s.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0.04)
	tw.Completed:Wait()
	s.bb:Destroy()
end)

PPS.PromptButtonHoldBegan:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	if prompt.HoldDuration > 0 then s.holdT0 = os.clock() end
	UI.tween(s.dsc, 0.12, { Scale = 0.88 })
	UI.tween(s.cardStroke, 0.12, { Transparency = 0 })
end)

PPS.PromptButtonHoldEnded:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.holdT0 = nil
	if not s.flash then s.setRing(0) end
	UI.tween(s.dsc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(s.cardStroke, 0.25, { Transparency = 1 })
end)

PPS.PromptTriggered:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.holdT0 = nil
	s.flash = (s.flash or 0) + 1
	local n = s.flash
	-- the ring closes, the capsule flashes its colour and jumps, the icon flips to a tick, then it settles
	s.setRing(1)
	s.dsc.Scale = 1.3
	UI.tween(s.dsc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	s.scale.Scale = 1.14 * PS
	UI.tween(s.scale, 0.4, { Scale = PS }, Enum.EasingStyle.Back)
	s.icon.Image = ICON.checkmark
	s.badge.Rotation = -90
	UI.tween(s.badge, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	s.card.BackgroundColor3 = s.cols[1]:Lerp(Color3.new(1, 1, 1), 0.5)
	UI.tween(s.card, 0.5, { BackgroundColor3 = T.white })
	if s.shine then s.shine(0.45) end
	UI.sparkles(s.wrap, 5, s.cols[1], 1.1)
	task.delay(0.6, function()
		if s.flash ~= n then return end
		s.flash = nil
		s.icon.Image = s.iconImg
		UI.pop(s.icon, 0.6, 0.3)
		s.setRing(0)
	end)
end)
