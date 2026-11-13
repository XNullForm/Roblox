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
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(247, 249, 252)), Parent = f })
	UI.rim(f, Color3.fromRGB(233, 237, 244), 2.5)
	return f
end

local CARD_RIM = Color3.fromRGB(232, 237, 244)
-- a clickable glossy card on a deep shadow: returns the button (scale / tooltips go on it) and its body
local function hudCard(parent, name, size, pos, onClick, radius)
	local b = UI.new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = size, Position = pos, BackgroundTransparency = 1, Parent = parent })
	UI.shadow(b, { drop = 7, transparency = 0.6 })
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, Parent = b })
	UI.corner(body, radius or 20)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = body })
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
	tr.BackgroundColor3 = Color3.fromRGB(240, 242, 246)
	tr.Parent = parent
	UI.corner(tr, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(214, 217, 222), Color3.new(1, 1, 1)), Parent = tr })
	UI.rim(tr, Color3.fromRGB(224, 229, 236), 1.5)
	local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, ClipsDescendants = true, ZIndex = tr.ZIndex + 1, Parent = tr })
	UI.corner(fill, UDim.new(0.5, 0))
	UI.sheen(fill)
	local hl = UI.new("Frame", { Size = UDim2.new(1, -6, 0.4, 0), Position = UDim2.fromOffset(3, 1), BackgroundColor3 = T.white, BackgroundTransparency = 0.55, ZIndex = tr.ZIndex + 2, Parent = fill })
	UI.corner(hl, UDim.new(0.5, 0))
	return tr, fill
end

local function openMenu(tab) player:SetAttribute("MenuWant", tab) end

-- round 34: the plates are white and glossy like the chapter goals, with 3D icons, and the top sits at the very top.
-- round 21 (2026-11-12): the top of the HUD. Left: the hotel plate (level tile, name, stars,
-- XP line). Centre: cash and guests. Right: a real clock: a white dial with ticks and two hands that turns navy at
-- night, with the weather and the digital time inside it, and the day and season on a tab beside it.
local cornerGroup = group("Corner", UDim2.fromOffset(330, 66), PHONE and UDim2.new(0, 16, 1, -18) or UDim2.fromOffset(16, 58), PHONE and Vector2.new(0, 1) or Vector2.new(0, 0), PHONE and UDim2.new(0, -460, 1, -18) or UDim2.fromOffset(-440, 58))
local topGroup = group("Top", UDim2.fromOffset(484, 80), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -130))
local clockGroup = group("Clock", UDim2.fromOffset(264, 104), UDim2.new(1, -16, 0, 8), Vector2.new(1, 0), UDim2.new(1, 300, 0, 8))

local G = UI.G
-- a glossy white plate you can click (the chapter goals' look): returns the button and its body
local function glass(parent, name, size, pos, onClick, radius)
	local b = UI.new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = size, Position = pos, BackgroundTransparency = 1, Parent = parent })
	UI.shadow(b, { drop = 5, transparency = 0.7 })
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, Parent = b })
	UI.corner(body, (radius or 12) + 4)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = body })
	UI.rim(body, CARD_RIM, 2.5)
	if onClick then
		local sc = UI.scaleOf(b)
		b.MouseEnter:Connect(function() UI.tween(sc, 0.18, { Scale = 1.04 }, Enum.EasingStyle.Back) end)
		b.MouseLeave:Connect(function() UI.tween(sc, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint) end)
		b.Activated:Connect(function()
			UI.sound("Click")
			onClick()
		end)
	end
	return b, body
end
-- a rounded colour tile with a white glyph in it; round 34: cash and guests get their 3D icon instead
local ICON3D = { [G.cash] = ICON.cash, [G.guest] = ICON.guest }
local function glyphTile(parent, size, color, pos, image, glyphSize)
	if ICON3D[image] then
		local t = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(size, size), Position = pos, BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
		return t, UI.icon(t, ICON3D[image], math.floor(size * 1.3), { Name = "Icon", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	end
	local t = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = color, ZIndex = 3, Parent = parent })
	UI.corner(t, math.floor(size * 0.28))
	local ic = UI.new("ImageLabel", { Name = "Icon", Image = image, ImageColor3 = T.white, Size = UDim2.fromOffset(glyphSize, glyphSize), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = t })
	return t, ic
end

---------------------------------------------------------------- your hotel: level, name, stars, XP

local lvSlot, lvBody = glass(cornerGroup, "Level", UDim2.fromScale(1, 1), UDim2.new(), function() openMenu("hotel") end, 14)
local lvHolder = UI.new("Frame", { Name = "LvHolder", Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 3, Parent = cornerGroup })
local lvTile = UI.new("Frame", { Name = "Lv", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.brand, ZIndex = 3, Parent = lvHolder })
UI.corner(lvTile, 12)
local lvPat = UI.new("Frame", { Visible = false, Parent = lvTile })
local lvCap = UI.label(lvTile, "LEVEL", 9, { FontFace = UI.F.heavy, TextColor3 = T.white, TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 10), ZIndex = 4 })
local levelNum = UI.label(lvTile, "1", 24, { FontFace = UI.F.black, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 28), ZIndex = 4 })
local starBadge = lvTile
local hotelName = UI.label(lvBody, "", 17, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -78, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
local STAR = 14
local rateSlot = UI.new("Frame", { Name = "Rating", Size = UDim2.fromOffset(120, STAR), Position = UDim2.fromOffset(66, 30), BackgroundTransparency = 1, ZIndex = 4, Parent = lvBody })
local starClips = {}
for i = 1, 5 do
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(STAR, STAR), Position = UDim2.fromOffset((i - 1) * (STAR + 2), 0), BackgroundTransparency = 1, ZIndex = 4, Parent = rateSlot })
	UI.new("ImageLabel", { Image = G.star, ImageColor3 = T.line, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = holder })
	local clip = UI.new("Frame", { Size = UDim2.fromOffset(0, STAR), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = holder })
	UI.new("ImageLabel", { Image = G.star, ImageColor3 = T.sun, Size = UDim2.fromOffset(STAR, STAR), ZIndex = 5, Parent = clip })
	starClips[i] = clip
end
local starNum = UI.label(rateSlot, "1.0", 13, { FontFace = UI.F.heavy, TextColor3 = T.sun, Position = UDim2.fromOffset(5 * (STAR + 2) + 3, -1), Size = UDim2.fromOffset(36, STAR + 2), ZIndex = 5 })
local xpTrack = UI.new("Frame", { Name = "XP", Size = UDim2.new(1, -78, 0, 5), Position = UDim2.fromOffset(66, 51), BackgroundColor3 = T.ink2, ZIndex = 4, Parent = lvBody })
UI.corner(xpTrack, 3)
local xpFill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.brand, ZIndex = 5, Parent = xpTrack })
UI.corner(xpFill, 3)
local xpText = UI.label(lvBody, "", 11, { FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -12, 0, 31), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 13), ZIndex = 5 })
local levelLbl = xpText
local xpSweep = UI.new("Frame", { Visible = false, Parent = xpFill })
UI.tooltip(lvSlot, "Your hotel: check guests in, give great stays, clean and research to earn XP")

---------------------------------------------------------------- the money and the guests

local TOP_X = 38
local cashSlot, cashBody = glass(topGroup, "Cash", UDim2.fromOffset(240, 46), UDim2.fromOffset(TOP_X, 6), function() openMenu("hotel") end)
local cashTile, cashIcon = glyphTile(cashBody, 34, T.green, UDim2.fromOffset(6, 6), G.cash, 22)
local cashText = UI.label(cashBody, "$0", 22, {
	FontFace = UI.F.black, TextColor3 = T.cream, TextScaled = true, ZIndex = 4,
	Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -96, 1, -18),
})
UI.new("UITextSizeConstraint", { MaxTextSize = 23, MinTextSize = 12, Parent = cashText })
local plusBtn = UI.new("TextButton", { Name = "Plus", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.ink2, ZIndex = 4, Parent = cashBody })
plusBtn.BackgroundTransparency = 0
UI.corner(plusBtn, 8)
UI.icon(plusBtn, ICON.upgrade, 26, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
plusBtn.MouseEnter:Connect(function() UI.tween(plusBtn, 0.12, { BackgroundColor3 = T.line }) end)
plusBtn.MouseLeave:Connect(function() UI.tween(plusBtn, 0.14, { BackgroundColor3 = T.ink2 }) end)
plusBtn.Activated:Connect(function()
	UI.sound("Click")
	openMenu("upgrades")
end)
UI.tooltip(plusBtn, "Upgrades")
local flyLayer = UI.new("Frame", { Name = "Fly", Size = UDim2.fromOffset(220, 80), Position = UDim2.fromOffset(50, 48), BackgroundTransparency = 1, ZIndex = 8, Parent = cashSlot })

local roomSlot, roomBody = glass(topGroup, "Rooms", UDim2.fromOffset(160, 46), UDim2.fromOffset(TOP_X + 248, 6), function() openMenu("hotel") end)
local roomTile = glyphTile(roomBody, 34, T.brand, UDim2.fromOffset(6, 6), G.guest, 20)
local roomNum = UI.label(roomBody, "0/0", 20, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(50, 4), Size = UDim2.fromOffset(100, 22), ZIndex = 4 })
UI.label(roomBody, "GUESTS", 10, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(51, 26), Size = UDim2.fromOffset(100, 12), ZIndex = 4 })
UI.tooltip(roomSlot, "Guests staying / your guest rooms")
-- rooms waiting for a clean: a red tab under the guests plate
local dirtyChip = UI.new("Frame", { Name = "Dirty", BackgroundColor3 = T.red, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(0, 52), Visible = false, ZIndex = 5, Parent = roomSlot })
UI.corner(dirtyChip, 8)
local dirtyStroke = Instance.new("UIStroke")
dirtyStroke.Transparency = 1
dirtyStroke.Parent = dirtyChip
UI.pad(dirtyChip, 8, 0, 10, 0)
UI.list(dirtyChip, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
UI.new("ImageLabel", { Image = G.clean, ImageColor3 = T.white, Size = UDim2.fromOffset(14, 14), LayoutOrder = 1, ZIndex = 6, Parent = dirtyChip })
local dirtyText = UI.new("TextLabel", { Text = "", TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, ZIndex = 6, Parent = dirtyChip })
local openTag = UI.new("Frame", { Visible = false, Parent = roomBody })
local openText = UI.label(openTag, "", 10, {})

---------------------------------------------------------------- the clock: an actual one

local FACE = 96
-- the day tab tucks under the dial's left side
local clockSlot, clockBody = glass(clockGroup, "Clock", UDim2.fromOffset(196, 50), UDim2.fromOffset(0, 23), nil, 14)
local dayLbl = UI.label(clockBody, "MONDAY", 15, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(14, 7), Size = UDim2.fromOffset(120, 18), ZIndex = 4 })
local dateLbl = UI.label(clockBody, "Spring, day 1", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 25), Size = UDim2.fromOffset(120, 15), ZIndex = 4 })
local dayTrack = UI.new("Frame", { Size = UDim2.fromOffset(104, 3), Position = UDim2.fromOffset(14, 43), BackgroundColor3 = T.ink2, ZIndex = 4, Parent = clockBody })
UI.corner(dayTrack, 2)
local dayFill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.sun, ZIndex = 5, Parent = dayTrack })
UI.corner(dayFill, 2)
-- the dial
local DIAL_DAY, DIAL_NIGHT = Color3.fromRGB(250, 251, 253), Color3.fromRGB(30, 46, 62)
local INK_DAY, INK_NIGHT = Color3.fromRGB(34, 40, 52), Color3.fromRGB(236, 240, 250)
local skyTile = UI.new("Frame", { Name = "Dial", Size = UDim2.fromOffset(FACE, FACE), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = DIAL_DAY, ZIndex = 6, Parent = clockGroup })
UI.corner(skyTile, UDim.new(0.5, 0))
local bezel = Instance.new("UIStroke")
bezel.Thickness = 4
bezel.Color = T.hud
bezel.Parent = skyTile
local inkParts = {} -- everything drawn in the dial's ink colour
local function spoke(angle, length, width, inset, z)
	-- a thin bar from the rim (inset) toward the centre, turned to `angle` (0 = 12 o'clock)
	local h = UI.new("Frame", { Size = UDim2.fromOffset(FACE, FACE), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Rotation = angle, ZIndex = z or 7, Parent = skyTile })
	local bar = UI.new("Frame", { Size = UDim2.fromOffset(width, length), Position = UDim2.new(0.5, 0, 0, inset), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = INK_DAY, ZIndex = z or 7, Parent = h })
	UI.corner(bar, UDim.new(0.5, 0))
	table.insert(inkParts, bar)
	return h, bar
end
for i = 0, 11 do
	local major = i % 3 == 0
	local _, bar = spoke(i * 30, major and 9 or 5, major and 3 or 2, 5)
	if not major then bar.BackgroundTransparency = 0.45 end
end
-- what the dial tells you besides the time: the weather above the centre, the digital time below it
local skyIcon = UI.new("ImageLabel", { Name = "Weather", Image = G.sun, ImageColor3 = T.sun, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, 0, 0.5, -24), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = skyTile })
local clockText = UI.label(skyTile, "", 12, { FontFace = UI.F.black, TextColor3 = INK_DAY, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0.5, 14), Size = UDim2.new(1, 0, 0, 14), ZIndex = 7 })
local hourHand = spoke(0, FACE / 2 - 24, 5, 24, 8)
local minuteHand = spoke(0, FACE / 2 - 12, 3, 12, 9)
local cap = UI.new("Frame", { Size = UDim2.fromOffset(9, 9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.brand, ZIndex = 10, Parent = skyTile })
UI.corner(cap, UDim.new(0.5, 0))
local dialHit = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11, Parent = skyTile })
UI.corner(dialHit, UDim.new(0.5, 0))
local function clockTip()
	local w = Shared:GetAttribute("WeatherName")
	local sd = Clock.seasonData and Clock.seasonData()
	local s = (w and (w .. ". ") or "") .. (sd and (sd.name .. ": " .. (sd.demand >= 1.1 and "busy season" or sd.demand < 1 and "quiet season" or "steady season")) or "")
	return s ~= "" and s or "Guests check out in the morning and arrive all day"
end
UI.tooltip(dialHit, clockTip)
UI.tooltip(clockSlot, clockTip)

-- the tutorial card hangs under the top plates
local tutWrap = UI.new("Frame", { Name = "Tutorial", Size = UDim2.fromOffset(540, 96), Position = UDim2.new(0.5, 0, 0, 66), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = topGroup })

local shownStars = -1
local function refreshCard()
	hotelName.Text = HOTEL:GetAttribute("HotelName") or "My Hotel"
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	starNum.Text = string.format("%.1f", stars)
	if math.abs(stars - shownStars) > 0.01 then
		shownStars = stars
		for i = 1, 5 do
			local k = math.clamp(stars - (i - 1), 0, 1)
			UI.tween(starClips[i], 0.4, { Size = UDim2.fromOffset(STAR * k, STAR) }, Enum.EasingStyle.Quint)
		end
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
	levelNum.TextSize = lv >= 100 and 18 or 24
	xpText.Text = lv >= Levels.MAX and "MAX LEVEL" or (UI.commas(xp) .. " / " .. UI.commas(need) .. " XP")
	local k = lv >= Levels.MAX and 1 or math.clamp(xp / math.max(need, 1), 0, 1)
	if lv > shownLevel then
		UI.tween(xpFill, 0.3, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Quad).Completed:Once(function()
			xpFill.Size = UDim2.fromScale(0, 1)
			UI.tween(xpFill, 0.4, { Size = UDim2.fromScale(k, 1) })
		end)
		UI.pop(lvTile, 1.5, 0.3)
		lvTile.BackgroundColor3 = T.sun
		UI.tween(lvTile, 1.2, { BackgroundColor3 = T.brand })
	else
		UI.tween(xpFill, 0.4, { Size = UDim2.fromScale(k, 1) })
	end
	shownLevel = lv
end
for _, a in ipairs({ "Level", "XP", "XPNeed" }) do HOTEL:GetAttributeChangedSignal(a):Connect(refreshXP) end
refreshXP()

local lastClock = ""
local lastSky = ""
local DOW = {}
local SKY = {
	cloudy = { G.cloud, Color3.fromRGB(128, 140, 160) }, fog = { G.fog, Color3.fromRGB(140, 150, 168) },
	rain = { G.rain, Color3.fromRGB(64, 148, 240) }, storm = { G.storm, Color3.fromRGB(161, 173, 190) },
	snow = { G.snow, Color3.fromRGB(96, 178, 240) },
}
local function refreshClock()
	local t = Clock.now()
	local night = Clock.isNight(t)
	local s = Clock.format(t)
	if s ~= lastClock then
		lastClock = s
		clockText.Text = (s:gsub("%s*[AP]M$", ""))
		local d = Clock.date()
		dayLbl.Text = string.upper(d.dowName)
		dateLbl.Text = d.seasonName .. ", day " .. d.day
	end
	hourHand.Rotation = (t % 12) / 12 * 360
	minuteHand.Rotation = (t * 60 % 60) / 60 * 360
	dayFill.Size = UDim2.fromScale(math.clamp(t / 24, 0, 1), 1)
	local w = Shared:GetAttribute("Weather") or "clear"
	local key = w .. (night and "N" or "D")
	if key ~= lastSky then
		lastSky = key
		local sky = SKY[w]
		skyIcon.Image = sky and sky[1] or (night and G.moon or G.sun)
		skyIcon.ImageColor3 = sky and sky[2] or (night and Color3.fromRGB(225, 237, 255) or T.sun)
		UI.tween(skyTile, 0.8, { BackgroundColor3 = night and DIAL_NIGHT or DIAL_DAY })
		local ink = night and INK_NIGHT or INK_DAY
		for _, p in ipairs(inkParts) do UI.tween(p, 0.8, { BackgroundColor3 = ink }) end
		UI.tween(clockText, 0.8, { TextColor3 = ink })
	end
end

-- cash: big numbers shorten so the plate never overflows; infinite cash (the /mmoney command) shows as "Infinite"
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
	local l = UI.chip(flyLayer, (up and "+" or "-") .. money(math.abs(d)), up and T.green or T.red, { TextSize = 15, Size = UDim2.fromOffset(0, 26), Position = UDim2.fromOffset(0, -4), ZIndex = 9 })
	UI.tween(l, 1.1, { Position = UDim2.fromOffset(0, 22) }, Enum.EasingStyle.Quint)
	UI.tween(l, 0.35, { TextTransparency = 1, BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.9)
	task.delay(1.3, function() l:Destroy() end)
end
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local now = player:GetAttribute("Cash") or 0
	local d = now - lastCash
	lastCash = now
	cashFrom, cashTo, cashT = shownCash, now, 0
	if math.abs(d) >= 1 and d == d and math.abs(d) ~= math.huge then
		flyDelta(d)
		UI.pop(cashTile, d > 0 and 1.3 or 0.8, 0.25)
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
	end
	if dirty ~= shown.dirty then
		dirtyText.Text = dirty == 1 and "1 ROOM TO CLEAN" or (dirty .. " ROOMS TO CLEAN")
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
		BackgroundColor3 = Color3.fromRGB(20, 24, 32), BackgroundTransparency = 0.45, AutoButtonColor = false, Image = "", Parent = sg,
	})
	-- round 34: looks like Roblox's own touch buttons (dark glass, white ring); blue with a RUN tag while on
	UI.corner(btn, 32)
	local st = UI.stroke(btn, 2.5, Color3.new(1, 1, 1), 0.45)
	local lbl = UI.icon(btn, ICON.run, 40, { Size = UDim2.fromScale(0.66, 0.66), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 })
	local tag = UI.label(btn, "RUN", 11, { FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, 0, 0.24, 0), TextScaled = true })
	local function paint()
		UI.tween(btn, 0.15, { BackgroundColor3 = sprinting and T.brand or Color3.fromRGB(20, 24, 32), BackgroundTransparency = sprinting and 0.08 or 0.45 })
		UI.tween(st, 0.15, { Transparency = sprinting and 0 or 0.45 })
		lbl.ImageTransparency = sprinting and 0 or 0.1
		tag.TextTransparency = sprinting and 0 or 0.35
	end
	btn.Activated:Connect(function()
		sprinting = not sprinting
		applySprint()
		paint()
		UI.pop(btn, sprinting and 1.15 or 0.9, 0.2)
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
				btn.Size = UDim2.fromOffset(d * 0.8, d * 0.8)
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
		-- round 34: TopbarInset is the FREE strip between Roblox's buttons, so clash = we reach past its edges
		local clash = inset.Max.X > 0 and (left < inset.Min.X + 8 or left + w > inset.Max.X - 8)
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
-- round 34: the day's report, remade in the chapter goals' look: a white card with the sun badge on top, the day's
-- profit big in the middle, a line per figure (in green, out in red), the rating and what tomorrow brings.
local function daySummary(d)
	if summaryOpen or player:GetAttribute("HideDaySummary") then return end
	summaryOpen = true
	local layer = UI.new("Frame", { Name = "DaySummary", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hud })
	local dim = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 1, Parent = layer })
	UI.tween(dim, 0.3, { BackgroundTransparency = 0.45 })
	local wrap = UI.new("Frame", { Size = UDim2.fromOffset(520, 600), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = layer })
	UI.autoScale(wrap)
	local holder = UI.new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = wrap })
	UI.shadow(holder, { drop = 10, transparency = 0.5 })
	local body = plate(holder, { Name = "Body", Size = UDim2.fromScale(1, 1), radius = 26 })
	UI.icon(holder, ICON.sun, 96, { Position = UDim2.new(0.5, 0, 0, -46), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5 })
	UI.label(body, "DAY " .. (d.day or 1) .. " COMPLETE", 14, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 16) })
	local earned, wages, upkeep = d.earned or 0, d.wages or 0, d.upkeep or 0
	local profit = earned - wages - upkeep
	local big = UI.label(body, "$0", 46, { FontFace = UI.F.black, TextColor3 = profit >= 0 and T.greenDk or T.red, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 52) })
	UI.label(body, profit >= 0 and "profit today" or "loss today", 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 16) })
	task.delay(0.3, function()
		UI.countTo(big, math.abs(profit), function(x) return (profit >= 0 and "+$" or "-$") .. UI.commas(x) end, 1.1)
	end)

	-- the figures, one line each
	local list = UI.new("Frame", { Size = UDim2.new(1, -56, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(28, 156), BackgroundTransparency = 1, Parent = body })
	UI.list(list, Enum.FillDirection.Vertical, 6)
	local rows = {
		{ "guest", "Guests served", tostring(d.guests or 0), T.cream },
		{ "clean", "Rooms cleaned", tostring(d.cleans or 0), T.cream },
		{ "cash", "Money from guests", "+$" .. UI.commas(earned), T.greenDk },
	}
	if wages > 0 then table.insert(rows, { "staff", "Staff wages", "-$" .. UI.commas(wages), T.red }) end
	if upkeep > 0 then table.insert(rows, { "hammer", "Season upkeep", "-$" .. UI.commas(upkeep), T.red }) end
	for i, r in ipairs(rows) do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = list })
		UI.corner(row, 12)
		UI.icon(row, ICON[r[1]] or ICON.star, 34, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		UI.label(row, r[2], 16, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -160, 1, 0) })
		UI.label(row, r[3], 18, { FontFace = UI.F.black, TextColor3 = r[4], TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -14, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(120, 44) })
	end
	UI.stagger(list, 0.07)

	-- the rating and tomorrow
	local foot = UI.new("Frame", { Size = UDim2.new(1, -56, 0, 64), Position = UDim2.new(0, 28, 1, -182), BackgroundTransparency = 1, Parent = body })
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	UI.label(foot, "RATING", 11, { FontFace = UI.F.black, TextColor3 = T.muted, Size = UDim2.fromOffset(120, 14) })
	for i = 1, 5 do
		local k = math.clamp(stars - (i - 1), 0, 1)
		UI.new("ImageLabel", { Image = G.star, ImageColor3 = k >= 0.5 and T.sun or T.line, BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset((i - 1) * 24, 18), Parent = foot })
	end
	UI.label(foot, string.format("%.1f", stars), 16, { FontFace = UI.F.black, TextColor3 = T.sun, Position = UDim2.fromOffset(124, 18), Size = UDim2.fromOffset(40, 22) })
	local sd = Clock.seasonData and Clock.seasonData()
	local w = Shared:GetAttribute("WeatherName")
	local tomorrow = sd and (sd.name .. ", " .. (sd.demand >= 1.1 and "a busy season" or sd.demand < 1 and "a quiet season" or "a steady season")) or "Guests arrive all day"
	UI.label(foot, "TOMORROW", 11, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(240, 14) })
	UI.label(foot, tomorrow .. (w and (". " .. w) or ""), 14, { FontFace = UI.F.heavy, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = true, Position = UDim2.new(1, 0, 0, 18), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(260, 40) })
	if d.uncollected and d.uncollected > 0 then
		local tip = UI.new("Frame", { Size = UDim2.new(1, -56, 0, 30), Position = UDim2.new(0, 28, 1, -88), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromRGB(255, 244, 214), Parent = body })
		UI.corner(tip, 10)
		UI.label(tip, "Your safe still holds $" .. UI.commas(d.uncollected) .. ". Go and collect it!", 14, { FontFace = UI.F.heavy, TextColor3 = Color3.fromRGB(150, 96, 20), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	end
	local close
	UI.button(body, {
		text = "Continue", kind = "gold", size = UDim2.fromOffset(220, 48), pos = UDim2.new(0.5, 0, 1, -20), anchor = Vector2.new(0.5, 1),
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
	task.delay(12, close)
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
			UI.grad(tile, Color3.fromRGB(255, 255, 255), Color3.fromRGB(218, 221, 226), 90)
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
	UI.grad(ribbon, Color3.fromRGB(255, 255, 255), Color3.fromRGB(218, 221, 226), 90)
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
		if d.pos then worldPop(d.pos + Vector3.new(0, 2.5, 0), "+" .. d.amount .. " XP", Color3.fromRGB(229, 240, 255), "star") end
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

local PS = (player:GetAttribute("PromptSize") or 100) / 100 * 0.72 -- round 21: smaller prompts
player:GetAttributeChangedSignal("PromptSize"):Connect(function()
	PS = (player:GetAttribute("PromptSize") or 100) / 100 * 0.72
end)
local CAP_RIM = Color3.fromRGB(232, 237, 244)
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
	local tail = UI.new("ImageLabel", { Name = "Tail", Image = UI.IMG.tail, ImageColor3 = Color3.fromRGB(245, 247, 250), Size = UDim2.fromOffset(26, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -3), ZIndex = 1, Parent = wrap })
	local card = UI.new("Frame", { Name = "Card", Size = UDim2.fromOffset(0, H), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, ZIndex = 2, Parent = wrap })
	UI.corner(card, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = card })
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
	UI.rim(ringTrack, Color3.fromRGB(240, 242, 246), 4)
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
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(224, 225, 228)), Parent = badge })
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
