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

