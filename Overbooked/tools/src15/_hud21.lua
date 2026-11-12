-- round 21 (2026-11-12): the top of the HUD, rebuilt as dark glass. Left: the hotel plate (level tile, name, stars,
-- XP line). Centre: cash and guests. Right: a real clock: a white dial with ticks and two hands that turns navy at
-- night, with the weather and the digital time inside it, and the day and season on a tab beside it.
local cornerGroup = group("Corner", UDim2.fromOffset(330, 66), PHONE and UDim2.new(0, 16, 1, -18) or UDim2.fromOffset(16, 58), PHONE and Vector2.new(0, 1) or Vector2.new(0, 0), PHONE and UDim2.new(0, -460, 1, -18) or UDim2.fromOffset(-440, 58))
local topGroup = group("Top", UDim2.fromOffset(484, 80), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -130))
local clockGroup = group("Clock", UDim2.fromOffset(264, 104), UDim2.new(1, -16, 0, 8), Vector2.new(1, 0), UDim2.new(1, 300, 0, 8))

local G = UI.G
-- a dark glass plate you can click: returns the button and its body
local function glass(parent, name, size, pos, onClick, radius)
	local b = UI.new("TextButton", { Name = name, Text = "", AutoButtonColor = false, Size = size, Position = pos, BackgroundTransparency = 1, Parent = parent })
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.hud, BackgroundTransparency = 0.08, Parent = b })
	UI.corner(body, radius or 12)
	local st = Instance.new("UIStroke")
	st.Color = T.hudLine
	st.Transparency = 0.4
	st.Parent = body
	if onClick then
		b.MouseEnter:Connect(function() UI.tween(body, 0.12, { BackgroundColor3 = T.hud2 }) end)
		b.MouseLeave:Connect(function() UI.tween(body, 0.14, { BackgroundColor3 = T.hud }) end)
		b.Activated:Connect(function()
			UI.sound("Click")
			onClick()
		end)
	end
	return b, body
end
-- a rounded colour tile with a white glyph in it
local function glyphTile(parent, size, color, pos, image, glyphSize)
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
local hotelName = UI.label(lvBody, "", 17, { FontFace = UI.F.black, TextColor3 = T.hudText, Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -78, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
local STAR = 14
local rateSlot = UI.new("Frame", { Name = "Rating", Size = UDim2.fromOffset(120, STAR), Position = UDim2.fromOffset(66, 30), BackgroundTransparency = 1, ZIndex = 4, Parent = lvBody })
local starClips = {}
for i = 1, 5 do
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(STAR, STAR), Position = UDim2.fromOffset((i - 1) * (STAR + 2), 0), BackgroundTransparency = 1, ZIndex = 4, Parent = rateSlot })
	UI.new("ImageLabel", { Image = G.star, ImageColor3 = T.hudLine, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = holder })
	local clip = UI.new("Frame", { Size = UDim2.fromOffset(0, STAR), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = holder })
	UI.new("ImageLabel", { Image = G.star, ImageColor3 = T.sun, Size = UDim2.fromOffset(STAR, STAR), ZIndex = 5, Parent = clip })
	starClips[i] = clip
end
local starNum = UI.label(rateSlot, "1.0", 13, { FontFace = UI.F.heavy, TextColor3 = T.sun, Position = UDim2.fromOffset(5 * (STAR + 2) + 3, -1), Size = UDim2.fromOffset(36, STAR + 2), ZIndex = 5 })
local xpTrack = UI.new("Frame", { Name = "XP", Size = UDim2.new(1, -78, 0, 5), Position = UDim2.fromOffset(66, 51), BackgroundColor3 = T.hud2, ZIndex = 4, Parent = lvBody })
UI.corner(xpTrack, 3)
local xpFill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.brand, ZIndex = 5, Parent = xpTrack })
UI.corner(xpFill, 3)
local xpText = UI.label(lvBody, "", 11, { FontFace = UI.F.bold, TextColor3 = T.hudMuted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -12, 0, 31), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(140, 13), ZIndex = 5 })
local levelLbl = xpText
local xpSweep = UI.new("Frame", { Visible = false, Parent = xpFill })
UI.tooltip(lvSlot, "Your hotel: check guests in, give great stays, clean and research to earn XP")

---------------------------------------------------------------- the money and the guests

local TOP_X = 38
local cashSlot, cashBody = glass(topGroup, "Cash", UDim2.fromOffset(240, 46), UDim2.fromOffset(TOP_X, 6), function() openMenu("hotel") end)
local cashTile, cashIcon = glyphTile(cashBody, 34, T.green, UDim2.fromOffset(6, 6), G.cash, 22)
local cashText = UI.label(cashBody, "$0", 22, {
	FontFace = UI.F.black, TextColor3 = T.hudText, TextScaled = true, ZIndex = 4,
	Position = UDim2.fromOffset(50, 9), Size = UDim2.new(1, -96, 1, -18),
})
UI.new("UITextSizeConstraint", { MaxTextSize = 23, MinTextSize = 12, Parent = cashText })
local plusBtn = UI.new("TextButton", { Name = "Plus", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.hud2, ZIndex = 4, Parent = cashBody })
plusBtn.BackgroundTransparency = 0
UI.corner(plusBtn, 8)
UI.new("ImageLabel", { Image = G.upgrade, ImageColor3 = T.green, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = plusBtn })
plusBtn.MouseEnter:Connect(function() UI.tween(plusBtn, 0.12, { BackgroundColor3 = T.hudLine }) end)
plusBtn.MouseLeave:Connect(function() UI.tween(plusBtn, 0.14, { BackgroundColor3 = T.hud2 }) end)
plusBtn.Activated:Connect(function()
	UI.sound("Click")
	openMenu("upgrades")
end)
UI.tooltip(plusBtn, "Upgrades")
local flyLayer = UI.new("Frame", { Name = "Fly", Size = UDim2.fromOffset(220, 80), Position = UDim2.fromOffset(50, 48), BackgroundTransparency = 1, ZIndex = 8, Parent = cashSlot })

local roomSlot, roomBody = glass(topGroup, "Rooms", UDim2.fromOffset(160, 46), UDim2.fromOffset(TOP_X + 248, 6), function() openMenu("hotel") end)
local roomTile = glyphTile(roomBody, 34, T.brand, UDim2.fromOffset(6, 6), G.guest, 20)
local roomNum = UI.label(roomBody, "0/0", 20, { FontFace = UI.F.black, TextColor3 = T.hudText, Position = UDim2.fromOffset(50, 4), Size = UDim2.fromOffset(100, 22), ZIndex = 4 })
UI.label(roomBody, "GUESTS", 10, { FontFace = UI.F.heavy, TextColor3 = T.hudMuted, Position = UDim2.fromOffset(51, 26), Size = UDim2.fromOffset(100, 12), ZIndex = 4 })
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
local dayLbl = UI.label(clockBody, "MONDAY", 15, { FontFace = UI.F.black, TextColor3 = T.hudText, Position = UDim2.fromOffset(14, 7), Size = UDim2.fromOffset(120, 18), ZIndex = 4 })
local dateLbl = UI.label(clockBody, "Spring, day 1", 12, { FontFace = UI.F.bold, TextColor3 = T.hudMuted, Position = UDim2.fromOffset(14, 25), Size = UDim2.fromOffset(120, 15), ZIndex = 4 })
local dayTrack = UI.new("Frame", { Size = UDim2.fromOffset(104, 3), Position = UDim2.fromOffset(14, 43), BackgroundColor3 = T.hud2, ZIndex = 4, Parent = clockBody })
UI.corner(dayTrack, 2)
local dayFill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.sun, ZIndex = 5, Parent = dayTrack })
UI.corner(dayFill, 2)
-- the dial
local DIAL_DAY, DIAL_NIGHT = Color3.fromRGB(250, 251, 253), Color3.fromRGB(30, 38, 62)
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
	rain = { G.rain, Color3.fromRGB(64, 148, 240) }, storm = { G.storm, Color3.fromRGB(120, 108, 190) },
	snow = { G.snow, Color3.fromRGB(96, 178, 240) },
}
local function refreshClock()
	local t = Clock.now()
	local night = Clock.isNight(t)
	local s = Clock.format(t)
	if s ~= lastClock then
		lastClock = s
		clockText.Text = s
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
		skyIcon.ImageColor3 = sky and sky[2] or (night and Color3.fromRGB(170, 190, 255) or T.sun)
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
