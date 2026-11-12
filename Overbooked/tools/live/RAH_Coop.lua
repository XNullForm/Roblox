-- StarterPlayerScripts.RAH_Coop: the Menu button (top right, or press M) opens a tabbed menu -- Stats,
-- Staff (hire help), Co-op (invite people to work in your hotel) and Settings. Invites pop up as a card.
-- When you move to another hotel (player attribute RAH_Plot changes) it restarts RAH_Client and RAH_BuildClient
-- so the HUD and build mode follow you there. Server side: RAH_Plots (Remotes.Coop).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local StarterPlayer = game:GetService("StarterPlayer")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local Coop = RAH.Remotes:WaitForChild("Coop")
local Build = RAH.Remotes:WaitForChild("Build")
local SoundService = game:GetService("SoundService")
local PLOTS = workspace:WaitForChild("Plots")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local ps = player:WaitForChild("PlayerScripts")

local INK = Color3.fromRGB(46, 34, 58)
local FONT = Enum.Font.FredokaOne
local GREEN = { Color3.fromRGB(140, 240, 110), Color3.fromRGB(50, 180, 70) }
local RED = { Color3.fromRGB(255, 140, 130), Color3.fromRGB(220, 70, 70) }
local GREY = { Color3.fromRGB(214, 208, 226), Color3.fromRGB(160, 150, 180) }
local PURPLE = { Color3.fromRGB(196, 160, 255), Color3.fromRGB(120, 80, 220) }

---------------------------------------------------------------- follow the hotel you work in

local current = player:GetAttribute("RAH_Plot")

local function reboot()
	local b = ps:FindFirstChild("RAH_BuildClient")
	local leave = b and b:FindFirstChild("RAH_Leave")
	if leave then pcall(function() leave:Invoke() end) end
	-- belt and braces: camera, prompts and walking back to normal
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
		if hum.WalkSpeed == 0 then
			hum.WalkSpeed = StarterPlayer.CharacterWalkSpeed
			hum.JumpPower = StarterPlayer.CharacterJumpPower
			hum.JumpHeight = StarterPlayer.CharacterJumpHeight
		end
	end
	PPS.Enabled = true
	for _, n in ipairs({ "RAH_Client", "RAH_BuildClient" }) do
		local s = ps:FindFirstChild(n)
		if s then
			local copy = s:Clone()
			copy:ClearAllChildren() -- drop the old copy's runtime bits (toast / leave hooks)
			s:Destroy()
			copy.Parent = ps
		end
	end
end

player:GetAttributeChangedSignal("RAH_Plot"):Connect(function()
	local now = player:GetAttribute("RAH_Plot")
	if current and now and now ~= current then reboot() end
	current = now
end)

---------------------------------------------------------------- ui helpers

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function stroke(o, th, col)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 3
	s.Color = col or INK
	s.ApplyStrokeMode = o:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = o
end
local function grad(o, cols)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(cols[1], cols[2])
	g.Parent = o
	return g
end
local function label(parent, text, size, pos, color, outline)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Size = size
	t.Position = pos or UDim2.new()
	t.Parent = parent
	if outline ~= false then stroke(t, 3) end
	return t
end
local function image(parent, img, size, pos, anchor)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = C.ICONS[img] or img
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = size
	i.Position = pos or UDim2.new()
	i.AnchorPoint = anchor or Vector2.zero
	i.Parent = parent
	return i
end
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = o
	return s
end
local function pop(o, from)
	local s = scaleOf(o)
	s.Scale = from or 1.15
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end
-- a chunky pill button with a gradient
local function button(parent, text, cols, size, pos)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Size = size
	b.Position = pos or UDim2.new()
	b.Parent = parent
	corner(b)
	stroke(b, 3)
	local g = grad(b, cols)
	local t = label(b, text, UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5))
	b.MouseEnter:Connect(function() tween(scaleOf(b), 0.2, { Scale = 1.06 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(scaleOf(b), 0.2, { Scale = 1 }) end)
	return b, t, g
end

local function headshot(userId)
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	return ok and img or ""
end

local function hotelName(name)
	local h = name and PLOTS:FindFirstChild(name)
	return h and h:GetAttribute("HotelName") or "a hotel"
end

---------------------------------------------------------------- the screen

local gui = pgui:FindFirstChild("RAH_Coop")
if gui then gui:Destroy() end
gui = Instance.new("ScreenGui")
gui.Name = "RAH_Coop"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.DisplayOrder = 20
gui.Parent = pgui

local function uiK()
	local vp = workspace.CurrentCamera.ViewportSize
	return math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.62, 1.15)
end

-- the Menu button, top right (pressing M opens it too)
local openBtn = Instance.new("TextButton")
openBtn.Name = "MenuButton"
openBtn.Text = ""
openBtn.AutoButtonColor = false
openBtn.AnchorPoint = Vector2.new(1, 0)
openBtn.Position = UDim2.new(1, -18, 0, 16)
openBtn.Size = UDim2.fromOffset(178, 62)
openBtn.BackgroundColor3 = Color3.new(1, 1, 1)
openBtn.Parent = gui
corner(openBtn)
stroke(openBtn, 3.5)
grad(openBtn, PURPLE)
for i = 0, 2 do -- a chunky hamburger: three white bars
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(20, 15 + i * 15)
	bar.Size = UDim2.fromOffset(34, 9)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.Parent = openBtn
	corner(bar, UDim.new(1, 0))
end
local openText = label(openBtn, "Menu", UDim2.fromOffset(100, 40), UDim2.fromOffset(62, 11))
local openScale = scaleOf(openBtn)
-- partner count badge
local badge = Instance.new("Frame")
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(1, -4, 0, 4)
badge.Size = UDim2.fromOffset(30, 30)
badge.BackgroundColor3 = Color3.fromRGB(255, 80, 96)
badge.Visible = false
badge.Parent = openBtn
corner(badge)
stroke(badge, 2.5)
local badgeText = label(badge, "1", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1))

-- the panel
local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Text = ""
dim.AutoButtonColor = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(20, 12, 34)
dim.BackgroundTransparency = 0.45
dim.Visible = false
dim.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(700, 700)
panel.BackgroundColor3 = Color3.new(1, 1, 1)
panel.Visible = false
panel.Parent = gui
corner(panel, UDim.new(0, 28))
stroke(panel, 4)
grad(panel, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(232, 224, 248) })
local panelScale = scaleOf(panel)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 92)
header.BackgroundColor3 = Color3.new(1, 1, 1)
header.Parent = panel
corner(header, UDim.new(0, 28))
grad(header, PURPLE)
local headerFix = Instance.new("Frame") -- square off the header's bottom corners
headerFix.Position = UDim2.new(0, 0, 1, -28)
headerFix.Size = UDim2.new(1, 0, 0, 28)
headerFix.BorderSizePixel = 0
headerFix.BackgroundColor3 = Color3.new(1, 1, 1)
headerFix.Parent = header
grad(headerFix, { PURPLE[2]:Lerp(PURPLE[1], 0.3), PURPLE[2] })
image(header, "star", UDim2.fromOffset(96, 96), UDim2.fromOffset(10, -14))
label(header, "MENU", UDim2.fromOffset(330, 44), UDim2.fromOffset(104, 10))
local sub = label(header, "Manage, staff, co-op, stats and settings", UDim2.fromOffset(420, 22), UDim2.fromOffset(104, 56), Color3.fromRGB(255, 236, 200))
sub.TextXAlignment = Enum.TextXAlignment.Left

-- the tab row and one page per tab
local TABS = {
	{ id = "management", text = "Manage" }, { id = "staff", text = "Staff" },
	{ id = "coop", text = "Co-op" }, { id = "stats", text = "Stats" },
	{ id = "settings", text = "Settings" },
}
local tabRow = Instance.new("Frame")
tabRow.Position = UDim2.fromOffset(18, 100)
tabRow.Size = UDim2.new(1, -36, 0, 52)
tabRow.BackgroundTransparency = 1
tabRow.Parent = panel
local tll = Instance.new("UIListLayout", tabRow)
tll.FillDirection = Enum.FillDirection.Horizontal
tll.Padding = UDim.new(0, 8)
local tabBtns, pages = {}, {}
for i, t in ipairs(TABS) do
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(122, 52)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Parent = tabRow
	corner(b, UDim.new(0, 16))
	stroke(b, 3)
	local g = grad(b, GREY)
	label(b, t.text, UDim2.new(1, -10, 1, -8), UDim2.fromOffset(5, 4))
	tabBtns[t.id] = { btn = b, grad = g }
	local page = Instance.new("Frame")
	page.Name = "Page_" .. t.id
	page.Position = UDim2.fromOffset(18, 162)
	page.Size = UDim2.new(1, -36, 1, -178)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = panel
	pages[t.id] = page
end

local close = Instance.new("TextButton")
close.Text = ""
close.AutoButtonColor = false
close.AnchorPoint = Vector2.new(0.5, 0.5)
close.Position = UDim2.new(1, -14, 0, 14)
close.Size = UDim2.fromOffset(52, 52)
close.BackgroundColor3 = Color3.new(1, 1, 1)
close.ZIndex = 3
close.Parent = panel
corner(close)
stroke(close, 3)
grad(close, RED)
image(close, "close", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1)).ZIndex = 3

-- "you're helping at X" banner (only while you work in someone else's hotel)
local away = Instance.new("Frame")
away.Position = UDim2.fromOffset(0, 0)
away.Size = UDim2.new(1, 0, 0, 64)
away.BackgroundColor3 = Color3.fromRGB(255, 244, 200)
away.Visible = false
away.Parent = pages.coop
corner(away, UDim.new(0, 18))
stroke(away, 3)
local awayText = label(away, "", UDim2.new(1, -200, 0, 30), UDim2.fromOffset(14, 17), Color3.fromRGB(70, 60, 84), false)
awayText.TextXAlignment = Enum.TextXAlignment.Left
local homeBtn = button(away, "My hotel", GREEN, UDim2.fromOffset(170, 46), UDim2.new(1, -180, 0, 9))

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 0)
list.Size = UDim2.new(1, 0, 1, 0)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = INK
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = pages.coop
local ll = Instance.new("UIListLayout")
ll.Padding = UDim.new(0, 10)
ll.SortOrder = Enum.SortOrder.LayoutOrder
ll.Parent = list
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingLeft = UDim.new(0, 4)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = list

local empty = label(list, "Nobody else is here yet.\nInvite friends to this server from the Roblox menu, then invite them here!",
	UDim2.new(1, -10, 0, 80), nil, Color3.fromRGB(110, 96, 132), false)
empty.LayoutOrder = 999

---------------------------------------------------------------- rows

local rows = {} -- player -> row
local invited = {} -- userId -> time we invited them

local function makeRow(p)
	local f = Instance.new("Frame")
	f.Name = "Row_" .. p.UserId
	f.Size = UDim2.new(1, -4, 0, 78)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = list
	corner(f, UDim.new(0, 18))
	stroke(f, 3)
	grad(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 232, 250) })
	local face = Instance.new("ImageLabel")
	face.Position = UDim2.fromOffset(10, 9)
	face.Size = UDim2.fromOffset(60, 60)
	face.BackgroundColor3 = Color3.fromRGB(200, 186, 236)
	face.Parent = f
	corner(face)
	stroke(face, 3)
	task.spawn(function() face.Image = headshot(p.UserId) end)
	local name = label(f, p.DisplayName, UDim2.new(1, -250, 0, 30), UDim2.fromOffset(82, 10), Color3.fromRGB(70, 60, 84), false)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local where = label(f, "", UDim2.new(1, -250, 0, 20), UDim2.fromOffset(82, 44), Color3.fromRGB(130, 116, 150), false)
	where.TextXAlignment = Enum.TextXAlignment.Left
	local b, bt, bg = button(f, "Invite", GREEN, UDim2.fromOffset(150, 50), UDim2.new(1, -162, 0, 14))
	local row = { frame = f, where = where, btn = b, text = bt, grad = bg, mode = "invite" }
	b.Activated:Connect(function()
		pop(b, 0.9)
		if row.mode == "invite" then
			invited[p.UserId] = os.clock()
			Coop:FireServer("invite", p.UserId)
		elseif row.mode == "kick" then
			Coop:FireServer("kick", p.UserId)
		end
		task.delay(0.2, function() if rows[p] then rows[p].refresh() end end)
	end)
	function row.refresh()
		local mine = player:GetAttribute("RAH_Home")
		local theirPlot = p:GetAttribute("RAH_Plot")
		local theirHome = p:GetAttribute("RAH_Home")
		if theirPlot and theirPlot == mine then
			where.Text = "Working in your hotel"
			row.mode = "kick"
			bt.Text = "Send home"
			bg.Color = ColorSequence.new(RED[1], RED[2])
		else
			where.Text = (theirPlot and theirPlot == theirHome) and "Running their own hotel" or ("Helping at " .. hotelName(theirPlot))
			local pending = invited[p.UserId] and os.clock() - invited[p.UserId] < 60
			row.mode = (mine and not pending) and "invite" or "none"
			bt.Text = pending and "Invited" or "Invite"
			local cols = (row.mode == "invite") and GREEN or GREY
			bg.Color = ColorSequence.new(cols[1], cols[2])
		end
	end
	rows[p] = row
	row.refresh()
	p:GetAttributeChangedSignal("RAH_Plot"):Connect(row.refresh)
end

local function refreshAll()
	local mine, here = player:GetAttribute("RAH_Home"), player:GetAttribute("RAH_Plot")
	local isAway = here ~= nil and here ~= mine
	away.Visible = isAway
	if isAway then
		awayText.Text = "You're helping at " .. hotelName(here)
		homeBtn.Visible = mine ~= nil
	end
	list.Position = UDim2.fromOffset(0, isAway and 74 or 0)
	list.Size = UDim2.new(1, 0, 1, isAway and -74 or 0)
	local n, partners = 0, 0
	for p, row in pairs(rows) do
		n += 1
		row.refresh()
		if mine and p:GetAttribute("RAH_Plot") == mine then partners += 1 end
	end
	empty.Visible = n == 0
	badge.Visible = partners > 0
	badgeText.Text = tostring(partners)
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= player then makeRow(p) end end
Players.PlayerAdded:Connect(function(p) makeRow(p); refreshAll() end)
Players.PlayerRemoving:Connect(function(p)
	local row = rows[p]
	if row then row.frame:Destroy(); rows[p] = nil end
	refreshAll()
end)
for _, a in ipairs({ "RAH_Plot", "RAH_Home" }) do player:GetAttributeChangedSignal(a):Connect(refreshAll) end
task.spawn(function()
	while true do
		task.wait(1)
		refreshAll() -- invite buttons time out, partner counts change
	end
end)
refreshAll()

homeBtn.Activated:Connect(function()
	pop(homeBtn, 0.9)
	Coop:FireServer("leave")
end)

---------------------------------------------------------------- stats page

local function workHotel()
	local k = player:GetAttribute("RAH_Plot")
	return k and PLOTS:FindFirstChild(k)
end

local sll = Instance.new("UIListLayout", pages.stats)
sll.Padding = UDim.new(0, 6)
local statVals = {}
local function statRow(key, icon, text)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 44)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = pages.stats
	corner(f, UDim.new(0, 14))
	stroke(f, 3)
	grad(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 232, 250) })
	image(f, icon, UDim2.fromOffset(34, 34), UDim2.fromOffset(6, 5))
	local t = label(f, text, UDim2.new(1, -250, 0, 26), UDim2.fromOffset(50, 9), Color3.fromRGB(70, 60, 84), false)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local v = label(f, "", UDim2.fromOffset(190, 30), UDim2.new(1, -198, 0, 7), Color3.fromRGB(70, 60, 84), false)
	v.TextXAlignment = Enum.TextXAlignment.Right
	statVals[key] = v
end
statRow("stars", "star", "Star rating")
statRow("ready", "roomReady", "Clean rooms")
statRow("busy", "roomBusy", "Rooms with guests")
statRow("dirty", "roomDirty", "Rooms to clean")
statRow("waiting", "door", "Guests waiting")
statRow("appeal", "sparkle", "Lobby appeal")
statRow("staffCount", "staff", "Staff")
statRow("nextRoom", "bed", "Next room")
statRow("cash", "cash", "Your cash")

local function refreshStats()
	local h = workHotel()
	if not h then return end
	local stars = h:GetAttribute("HotelStars") or 1
	statVals.stars.Text = string.format("%.1f", stars) .. " / 5"
	statVals.ready.Text = tostring(h:GetAttribute("RoomsReady") or 0)
	statVals.busy.Text = tostring(h:GetAttribute("RoomsBusy") or 0)
	statVals.dirty.Text = tostring(h:GetAttribute("RoomsDirty") or 0)
	statVals.waiting.Text = tostring(h:GetAttribute("Waiting") or 0)
	statVals.appeal.Text = tostring(h:GetAttribute("LobbyAppeal") or 0)
	local parts = {}
	for _, def in ipairs(C.STAFF) do
		local n = h:GetAttribute(def.attr) or 0
		parts[#parts + 1] = n .. " " .. string.lower(def.name) .. (n == 1 and "" or "s")
	end
	statVals.staffCount.Text = table.concat(parts, ", ")
	local nextRoom = h:GetAttribute("NextRoom")
	statVals.nextRoom.Text = nextRoom and ("Room " .. nextRoom .. " - $" .. (h:GetAttribute("NextRoomPrice") or 0)) or "All built"
	statVals.cash.Text = "$" .. tostring(math.floor(player:GetAttribute("Cash") or 0))
end

---------------------------------------------------------------- staff page (hiring goes through the Build remote)

local function mtoast(text, icon, bad)
	local c = ps:FindFirstChild("RAH_Client")
	local t = c and c:FindFirstChild("RAH_Toast")
	if t then t:Fire(text, icon, bad) end
end

local stl = Instance.new("UIListLayout", pages.staff)
stl.Padding = UDim.new(0, 10)
local refreshHire -- forward
local hireCards = {}
for _, def in ipairs(C.STAFF) do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 96)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = pages.staff
	corner(f, UDim.new(0, 18))
	stroke(f, 3)
	grad(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 232, 250) })
	image(f, def.icon, UDim2.fromOffset(64, 64), UDim2.fromOffset(10, 16))
	local nm = label(f, def.name .. "s", UDim2.fromOffset(200, 30), UDim2.fromOffset(84, 12), Color3.fromRGB(70, 60, 84), false)
	nm.TextXAlignment = Enum.TextXAlignment.Left
	local bl = label(f, def.blurb, UDim2.fromOffset(250, 22), UDim2.fromOffset(84, 44), Color3.fromRGB(130, 116, 150), false)
	bl.TextXAlignment = Enum.TextXAlignment.Left
	local cnt = label(f, "", UDim2.fromOffset(250, 20), UDim2.fromOffset(84, 68), Color3.fromRGB(130, 116, 150), false)
	cnt.TextXAlignment = Enum.TextXAlignment.Left
	local hireBtn, hireText, hireGrad = button(f, "Hire", GREEN, UDim2.fromOffset(160, 56), UDim2.new(1, -172, 0, 20))
	local card = { def = def, btn = hireBtn, text = hireText, grad = hireGrad, count = cnt }
	hireCards[def.id] = card
	hireBtn.Activated:Connect(function()
		pop(hireBtn, 0.9)
		local ok, res, msg = pcall(Build.InvokeServer, Build, "hire", def.id)
		if ok and res == false and msg then mtoast(msg, def.icon, true) end
		refreshHire()
	end)
end

refreshHire = function()
	local h = workHotel()
	for _, card in pairs(hireCards) do
		local def = card.def
		local n = h and (h:GetAttribute(def.attr) or 0) or 0
		card.count.Text = n .. " of " .. def.max .. " hired"
		if n >= def.max then
			card.text.Text = "Full"
			card.grad.Color = ColorSequence.new(GREY[1], GREY[2])
		else
			local price = def.prices[n + 1]
			local cash = player:GetAttribute("Cash") or 0
			card.text.Text = "Hire  $" .. price
			local cols = cash >= price and GREEN or GREY
			card.grad.Color = ColorSequence.new(cols[1], cols[2])
		end
	end
end

---------------------------------------------------------------- management page

local mll = Instance.new("UIListLayout", pages.management)
mll.Padding = UDim.new(0, 10)

local function manageCard(h)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, h)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = pages.management
	corner(f, UDim.new(0, 18))
	stroke(f, 3)
	grad(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 232, 250) })
	return f
end

-- hotel name: edit and save (your own hotel only)
local nameCard = manageCard(120)
local nameTitle = label(nameCard, "Hotel name", UDim2.fromOffset(200, 26), UDim2.fromOffset(14, 10), Color3.fromRGB(70, 60, 84), false)
nameTitle.TextXAlignment = Enum.TextXAlignment.Left
local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.fromOffset(360, 52)
nameBox.Position = UDim2.fromOffset(14, 42)
nameBox.BackgroundColor3 = Color3.fromRGB(246, 244, 252)
nameBox.Font = FONT
nameBox.Text = ""
nameBox.PlaceholderText = "Type a name..."
nameBox.PlaceholderColor3 = Color3.fromRGB(160, 150, 180)
nameBox.TextColor3 = Color3.fromRGB(70, 60, 84)
nameBox.TextSize = 24
nameBox.TextXAlignment = Enum.TextXAlignment.Left
nameBox.ClearTextOnFocus = false
nameBox.Parent = nameCard
corner(nameBox, UDim.new(0, 14))
stroke(nameBox, 3)
local namePad = Instance.new("UIPadding", nameBox)
namePad.PaddingLeft = UDim.new(0, 14); namePad.PaddingRight = UDim.new(0, 14)
local nameBtn = button(nameCard, "Save name", GREEN, UDim2.fromOffset(170, 52), UDim2.new(1, -184, 0, 42))
local nameNote = label(nameCard, "", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 96), Color3.fromRGB(130, 116, 150), false)
nameNote.TextXAlignment = Enum.TextXAlignment.Left
nameBtn.Activated:Connect(function()
	pop(nameBtn, 0.9)
	local name = nameBox.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then
		mtoast("Type a name first!", "close", true)
		return
	end
	Coop:FireServer("rename", name)
end)

-- star rating: gold stars fill left to right
local starCard = manageCard(118)
local starTitle = label(starCard, "Star rating", UDim2.fromOffset(200, 26), UDim2.fromOffset(14, 10), Color3.fromRGB(70, 60, 84), false)
starTitle.TextXAlignment = Enum.TextXAlignment.Left
local starHint = label(starCard, "More stars bring more guests", UDim2.fromOffset(340, 20), UDim2.fromOffset(14, 88), Color3.fromRGB(130, 116, 150), false)
starHint.TextXAlignment = Enum.TextXAlignment.Left
local starRowM = Instance.new("Frame")
starRowM.BackgroundTransparency = 1
starRowM.Position = UDim2.fromOffset(14, 40)
starRowM.Size = UDim2.fromOffset(5 * 44, 44)
starRowM.Parent = starCard
local mStarFills = {}
for i = 1, 5 do
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(44, 44)
	holder.Position = UDim2.fromOffset((i - 1) * 44, 0)
	holder.Parent = starRowM
	image(holder, "starEmpty", UDim2.fromOffset(44, 44))
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromOffset(0, 44)
	clip.Parent = holder
	image(clip, "star", UDim2.fromOffset(44, 44))
	mStarFills[i] = clip
end
local starNum = label(starCard, "1.0", UDim2.fromOffset(150, 44), UDim2.new(1, -164, 0, 40))
starNum.TextColor3 = Color3.fromRGB(255, 200, 40)

local function manageRow(icon, text)
	local f = manageCard(64)
	image(f, icon, UDim2.fromOffset(44, 44), UDim2.fromOffset(10, 10))
	local t = label(f, text, UDim2.new(1, -250, 0, 26), UDim2.fromOffset(64, 19), Color3.fromRGB(70, 60, 84), false)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local v = label(f, "", UDim2.fromOffset(190, 30), UDim2.new(1, -204, 0, 17), Color3.fromRGB(70, 60, 84), false)
	v.TextXAlignment = Enum.TextXAlignment.Right
	return v
end
local mRooms = manageRow("bed", "Rooms built")
local mAppeal = manageRow("sparkle", "Lobby appeal")
local mWaiting = manageRow("door", "Guests waiting")

local function refreshManage()
	local h = workHotel()
	if not h then return end
	local stars = h:GetAttribute("HotelStars") or 1
	for i = 1, 5 do
		mStarFills[i].Size = UDim2.fromOffset(44 * math.clamp(stars - (i - 1), 0, 1), 44)
	end
	starNum.Text = string.format("%.1f", stars) .. " / 5"
	mRooms.Text = tostring((h:GetAttribute("RoomsReady") or 0) + (h:GetAttribute("RoomsBusy") or 0) + (h:GetAttribute("RoomsDirty") or 0))
	mAppeal.Text = tostring(h:GetAttribute("LobbyAppeal") or 0)
	mWaiting.Text = tostring(h:GetAttribute("Waiting") or 0)
	local mine = player:GetAttribute("RAH_Home")
	local isMine = mine ~= nil and h.Name == mine
	nameBox.Visible = isMine
	nameBtn.Visible = isMine
	if isMine then
		nameNote.Text = "The sign out front updates when you save."
		if not nameBox.Focused then nameBox.Text = h:GetAttribute("HotelName") or "My Hotel" end
	else
		nameNote.Text = "You can only rename your own hotel."
	end
end

---------------------------------------------------------------- settings page

local sel = Instance.new("UIListLayout", pages.settings)
sel.Padding = UDim.new(0, 10)

local function settingRow(icon, text, callback)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 70)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = pages.settings
	corner(f, UDim.new(0, 18))
	stroke(f, 3)
	grad(f, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 232, 250) })
	image(f, icon, UDim2.fromOffset(48, 48), UDim2.fromOffset(10, 11))
	local t = label(f, text, UDim2.fromOffset(230, 34), UDim2.fromOffset(70, 18), Color3.fromRGB(70, 60, 84), false)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local state = true
	local b, bt, bg = button(f, "On", GREEN, UDim2.fromOffset(130, 50), UDim2.new(1, -142, 0, 10))
	b.Activated:Connect(function()
		pop(b, 0.9)
		state = not state
		bt.Text = state and "On" or "Off"
		bg.Color = ColorSequence.new(state and GREEN[1] or GREY[1], state and GREEN[2] or GREY[2])
		callback(state)
	end)
end

settingRow("bell", "Music", function(on)
	local g = SoundService:FindFirstChild("RAH_Music")
	if g then TweenService:Create(g, TweenInfo.new(0.6), { Volume = on and 0.32 or 0 }):Play() end
end)
settingRow("sparkle", "Sound effects", function(on)
	local g = SoundService:FindFirstChild("RAH_SFX")
	if g then g.Volume = on and 0.9 or 0 end
end)
local setOpen -- forward: the reset button closes the menu
settingRow("walk", "Sprint (hold Shift)", function(on)
	player:SetAttribute("RAH_Sprint", on)
end)
player:SetAttribute("RAH_Sprint", true)

-- guest bubbles: hide or show the NPCs' status cards (client-side only)
local bubbleCon
settingRow("guest", "Guest bubbles", function(on)
	if bubbleCon then bubbleCon:Disconnect(); bubbleCon = nil end
	local function apply(d)
		if d:IsA("BillboardGui") and d.Name == "Status" then d.Enabled = on end
	end
	for _, d in ipairs(workspace:GetDescendants()) do apply(d) end
	if not on then
		bubbleCon = workspace.DescendantAdded:Connect(function(d)
			task.defer(apply, d)
		end)
	end
end)

-- sidewalk walkers: hide the passers-by strolling outside (client-side only)
local pedCon
settingRow("walk", "Sidewalk walkers", function(on)
	if pedCon then pedCon:Disconnect(); pedCon = nil end
	local function apply(m)
		if m:IsA("Model") and m.Parent and m.Parent.Name == "Guests"
			and not m:GetAttribute("Guest") and not m:GetAttribute("Staff") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 0 or 1 end
			end
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do apply(d) end
	if not on then
		pedCon = workspace.DescendantAdded:Connect(function(d)
			task.defer(apply, d)
		end)
	end
end)

-- reset progress: a red button that asks twice
local resetCard = Instance.new("Frame")
resetCard.Size = UDim2.new(1, 0, 0, 70)
resetCard.BackgroundColor3 = Color3.new(1, 1, 1)
resetCard.Parent = pages.settings
corner(resetCard, UDim.new(0, 18))
stroke(resetCard, 3)
grad(resetCard, { Color3.fromRGB(255, 240, 240), Color3.fromRGB(255, 224, 224) })
image(resetCard, "close", UDim2.fromOffset(48, 48), UDim2.fromOffset(10, 11))
local rt = label(resetCard, "Reset progress", UDim2.fromOffset(230, 34), UDim2.fromOffset(70, 18), Color3.fromRGB(70, 60, 84), false)
rt.TextXAlignment = Enum.TextXAlignment.Left
local rbtn, rbt = button(resetCard, "Reset", RED, UDim2.fromOffset(130, 50), UDim2.new(1, -142, 0, 10))
local armed = false
rbtn.Activated:Connect(function()
	pop(rbtn, 0.9)
	if not armed then
		armed = true
		rbt.Text = "Sure?"
		task.delay(3, function()
			if armed then armed = false; rbt.Text = "Reset" end
		end)
		return
	end
	armed = false
	rbt.Text = "Reset"
	Coop:FireServer("reset")
	setOpen(false)
end)

---------------------------------------------------------------- tabs + open/close

local activeTab = "management"
local function showTab(id)
	activeTab = id
	for k, p in pairs(pages) do p.Visible = k == id end
	for k, t in pairs(tabBtns) do
		local on = k == id
		t.grad.Color = ColorSequence.new(on and PURPLE[1] or GREY[1], on and PURPLE[2] or GREY[2])
	end
	-- the page pops in and its tab gives a little bounce
	local page = pages[id]
	if page then
		local s = scaleOf(page)
		s.Scale = 0.94
		tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	local tb = tabBtns[id]
	if tb then pop(tb.btn, 1.1) end
	if id == "management" then refreshManage() end
	if id == "stats" then refreshStats() end
	if id == "staff" then refreshHire() end
	if id == "coop" then refreshAll() end
end
for k in pairs(tabBtns) do
	tabBtns[k].btn.Activated:Connect(function() showTab(k) end)
end

-- keep the live pages fresh while the menu is open
local open = false
task.spawn(function()
	while true do
		task.wait(1)
		if open and activeTab == "management" then refreshManage() end
		if open and activeTab == "stats" then refreshStats() end
		if open and activeTab == "staff" then refreshHire() end
	end
end)

setOpen = function(on)
	open = on
	if on then
		dim.Visible = true
		panel.Visible = true
		showTab(activeTab)
		dim.BackgroundTransparency = 1
		tween(dim, 0.25, { BackgroundTransparency = 0.45 })
		panel.Position = UDim2.fromScale(0.5, 0.53)
		tween(panel, 0.4, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
		panelScale.Scale = uiK() * 0.85
		tween(panelScale, 0.4, { Scale = uiK() }, Enum.EasingStyle.Back)
		-- the tab buttons pop in one after another
		for i, t in ipairs(TABS) do
			local s = scaleOf(tabBtns[t.id].btn)
			s.Scale = 0
			task.delay(0.04 * i, function() tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	else
		tween(dim, 0.2, { BackgroundTransparency = 1 })
		local tw = tween(panelScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not open then
				panel.Visible = false
				dim.Visible = false
				panelScale.Scale = uiK()
			end
		end)
	end
end
openBtn.Activated:Connect(function() pop(openBtn, 0.9); setOpen(not open) end)
openBtn.MouseEnter:Connect(function() tween(openScale, 0.2, { Scale = uiK() * 1.06 }, Enum.EasingStyle.Back) end)
openBtn.MouseLeave:Connect(function() tween(openScale, 0.2, { Scale = uiK() }) end)
close.Activated:Connect(function() setOpen(false) end)
dim.Activated:Connect(function() setOpen(false) end)
UIS.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.M then return end
	setOpen(not open)
end)

local function layout()
	openScale.Scale = uiK()
	if open then panelScale.Scale = uiK() end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
layout()
-- hide the Co-op button while building (build mode has its own top-right Done button)
player:GetAttributeChangedSignal("RAH_Building"):Connect(function()
	openBtn.Visible = not player:GetAttribute("RAH_Building")
	if player:GetAttribute("RAH_Building") then setOpen(false) end
end)

---------------------------------------------------------------- invite cards

local cards = Instance.new("Frame")
cards.AnchorPoint = Vector2.new(1, 0)
cards.Position = UDim2.new(1, -18, 0, 96)
cards.Size = UDim2.fromOffset(400, 600)
cards.BackgroundTransparency = 1
cards.Parent = gui
local cl = Instance.new("UIListLayout")
cl.Padding = UDim.new(0, 10)
cl.HorizontalAlignment = Enum.HorizontalAlignment.Right
cl.Parent = cards
scaleOf(cards).Scale = uiK()

local function inviteCard(d)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(390, 150)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Parent = cards
	corner(f, UDim.new(0, 22))
	stroke(f, 4)
	grad(f, { Color3.fromRGB(255, 250, 230), Color3.fromRGB(255, 226, 160) })
	local face = Instance.new("ImageLabel")
	face.Position = UDim2.fromOffset(14, 14)
	face.Size = UDim2.fromOffset(70, 70)
	face.BackgroundColor3 = Color3.fromRGB(200, 186, 236)
	face.Parent = f
	corner(face)
	stroke(face, 3)
	task.spawn(function() face.Image = headshot(d.from) end)
	local t1 = label(f, d.name .. " invited you!", UDim2.fromOffset(282, 32), UDim2.fromOffset(96, 14), Color3.fromRGB(255, 255, 255))
	t1.TextXAlignment = Enum.TextXAlignment.Left
	local t2 = label(f, "Help run " .. (d.hotel or "their hotel"), UDim2.fromOffset(282, 22), UDim2.fromOffset(96, 52), Color3.fromRGB(110, 80, 40), false)
	t2.TextXAlignment = Enum.TextXAlignment.Left
	local yes = button(f, "Join", GREEN, UDim2.fromOffset(170, 48), UDim2.fromOffset(14, 92))
	local no = button(f, "No thanks", GREY, UDim2.fromOffset(170, 48), UDim2.fromOffset(196, 92))
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 22, 1, -6)
	bar.Size = UDim2.new(1, -44, 0, 4)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = Color3.fromRGB(240, 140, 40)
	bar.Parent = f
	corner(bar)
	pop(f, 0.6)
	local done = false
	local function finish(accept)
		if done then return end
		done = true
		Coop:FireServer("respond", d.from, accept)
		tween(scaleOf(f), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		f:Destroy()
	end
	yes.Activated:Connect(function() finish(true) end)
	no.Activated:Connect(function() finish(false) end)
	tween(bar, 55, { Size = UDim2.new(0, 0, 0, 4) }, Enum.EasingStyle.Linear)
	task.delay(55, function() if not done then done = true; f:Destroy() end end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "coopInvite" then
		inviteCard(d or {})
		local audio = ps:FindFirstChild("RAH_Audio")
		local play = audio and audio:FindFirstChild("Play")
		if play then play:Fire("bell") end
	elseif kind == "coopMoved" then
		setOpen(false)
	end
end)
