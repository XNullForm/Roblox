-- StarterPlayerScripts.RAH_BuildClient: build mode. B (or the hammer button) toggles it.
-- A free orbit camera over the hotel, a shop bar, a ghost you drop onto the floor, and a card
-- on placed furniture to move, turn or sell it. The server (RAH_BuildServer) re-checks everything.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Catalog = require(RAH:WaitForChild("Catalog"))
local Build = require(RAH:WaitForChild("Build"))
local Remote = RAH.Remotes:WaitForChild("Build")
local ITEMS = RAH:WaitForChild("Items")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
-- the hotel you work in (player attribute RAH_Plot, set by RAH_Plots). RAH_Coop restarts this script when it changes.
local PLOTS = workspace:WaitForChild("Plots")
while not player:GetAttribute("RAH_Plot") do player:GetAttributeChangedSignal("RAH_Plot"):Wait() end
local HOTEL = PLOTS:WaitForChild(player:GetAttribute("RAH_Plot"))
local O = HOTEL:GetAttribute("Origin") or Vector3.zero
-- a restart leaves the last copy's bits behind
for _, n in ipairs({ "RAH_Build", "RAH_Hover", "RAH_Selected" }) do
	local old = pgui:FindFirstChild(n)
	if old then old:Destroy() end
end
for _, n in ipairs({ "RAH_BuildLocal", "RAH_Ghost" }) do
	local old = workspace:FindFirstChild(n)
	if old then old:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("RAH_BuildCam") end)
local PLACED = HOTEL:WaitForChild("Placed")
local ZONES = HOTEL:WaitForChild("BuildZones")
-- the built-in reception desk (movable in build mode, unlike placed furniture)
local deskModel = HOTEL:WaitForChild("Lobby"):WaitForChild("Desk")

local INK = Color3.fromRGB(46, 34, 58)
local FONT = Enum.Font.FredokaOne
local GOOD = Color3.fromRGB(110, 235, 120)
local BAD = Color3.fromRGB(255, 90, 90)
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- sounds go through RAH_Audio's Play event (it may load after us)
local function sfx(name, pos)
	local a = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("RAH_Audio")
	local ev = a and a:FindFirstChild("Play")
	if ev then ev:Fire(name, pos) end
end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function stroke(o, th, col)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 3
	s.Color = col or INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

local function textStroke(o, th)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 2.5
	s.Color = INK
	s.Parent = o
	return s
end

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = o
	return c
end

local function grad(o, a, b)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(a, b)
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
	if outline ~= false then textStroke(t) end
	return t
end

local function icon(parent, key, size, pos, anchor)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = C.ICONS[key] or ""
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = size
	i.Position = pos or UDim2.new()
	i.AnchorPoint = anchor or Vector2.zero
	i.Parent = parent
	return i
end

local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then s = Instance.new("UIScale"); s.Parent = o end
	return s
end

local function pop(o, from)
	local s = scaleOf(o)
	s.Scale = from or 1.2
	tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function toast(text, key, bad)
	local ev = player.PlayerScripts:FindFirstChild("RAH_Client")
	ev = ev and ev:FindFirstChild("RAH_Toast")
	if ev then ev:Fire(text, key, bad) end
	if bad then sfx("error") end
end

local function cash() return player:GetAttribute("Cash") or 0 end

local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

---------------------------------------------------------------- state

local building = false
local cat = "all"
local ghost -- { id, model, turns, target, shown, ok, why, moving = placed model or nil, hl, tip }
local selected -- placed model with the action card open
local hovered
local busy = false

---------------------------------------------------------------- gui

local gui = Instance.new("ScreenGui")
gui.Name = "RAH_Build"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.DisplayOrder = 5
gui.Parent = pgui

local function uiK()
	local vp = camera.ViewportSize
	return math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.6, 1.15)
end

-- the hammer button, bottom centre
local buildBtn = Instance.new("TextButton")
buildBtn.Name = "BuildButton"
buildBtn.Text = ""
buildBtn.AutoButtonColor = false
buildBtn.AnchorPoint = Vector2.new(0.5, 1)
buildBtn.Position = UDim2.new(0.5, 0, 1, -18)
buildBtn.Size = UDim2.fromOffset(176, 64)
buildBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
buildBtn.Parent = gui
corner(buildBtn)
stroke(buildBtn, 3.5)
local buildGrad = grad(buildBtn, Color3.fromRGB(255, 226, 92), Color3.fromRGB(246, 168, 30))
local buildIcon = icon(buildBtn, "hammer", UDim2.fromOffset(74, 74), UDim2.new(0, -16, 0.5, 0), Vector2.new(0, 0.5))
local buildText = label(buildBtn, "Build", UDim2.fromOffset(84, 40), UDim2.fromOffset(60, 12))
buildText.TextXAlignment = Enum.TextXAlignment.Left
local keyChip = Instance.new("Frame")
keyChip.AnchorPoint = Vector2.new(0.5, 0.5)
keyChip.Position = UDim2.new(1, -6, 0, 6)
keyChip.Size = UDim2.fromOffset(30, 30)
keyChip.BackgroundColor3 = Color3.fromRGB(236, 242, 255)
keyChip.Visible = not TOUCH
keyChip.Parent = buildBtn
corner(keyChip, UDim.new(0.3, 0))
stroke(keyChip, 2.5)
local keyLbl = label(keyChip, "B", UDim2.fromScale(0.8, 0.8), UDim2.fromScale(0.1, 0.1), INK, false)
local buildScale = scaleOf(buildBtn)

-- shop panel
local shop = Instance.new("Frame")
shop.Name = "Shop"
shop.AnchorPoint = Vector2.new(0.5, 1)
shop.Size = UDim2.fromOffset(900, 196)
shop.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
shop.Visible = false
shop.Parent = gui
corner(shop, UDim.new(0, 26))
stroke(shop, 3.5)
grad(shop, Color3.fromRGB(250, 246, 255), Color3.fromRGB(218, 210, 236))
local shopScale = scaleOf(shop)

local tabs = Instance.new("Frame")
tabs.Name = "Tabs"
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(18, -26)
tabs.Size = UDim2.fromOffset(640, 48)
tabs.Parent = shop
local tl = Instance.new("UIListLayout")
tl.FillDirection = Enum.FillDirection.Horizontal
tl.Padding = UDim.new(0, 8)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = tabs

local list = Instance.new("ScrollingFrame")
list.Name = "Items"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(12, 30)
list.Size = UDim2.new(1, -24, 1, -36)
list.ScrollingDirection = Enum.ScrollingDirection.X
list.AutomaticCanvasSize = Enum.AutomaticSize.X
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.ScrollBarImageColor3 = INK
list.ScrollBarImageTransparency = 0.6
list.ElasticBehavior = Enum.ElasticBehavior.Always
list.Parent = shop
local ll = Instance.new("UIListLayout")
ll.FillDirection = Enum.FillDirection.Horizontal
ll.Padding = UDim.new(0, 10)
ll.SortOrder = Enum.SortOrder.LayoutOrder
ll.VerticalAlignment = Enum.VerticalAlignment.Center
ll.Parent = list
local lp = Instance.new("UIPadding")
lp.PaddingLeft = UDim.new(0, 6); lp.PaddingRight = UDim.new(0, 6)
lp.Parent = list

-- hint line above the shop (keys) and the placing bar (rotate / place / cancel)
local hint = label(gui, "", UDim2.fromOffset(700, 26), UDim2.new(), Color3.fromRGB(255, 255, 255))
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Visible = false

local bar = Instance.new("Frame")
bar.Name = "PlaceBar"
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Size = UDim2.fromOffset(300, 96)
bar.Visible = false
bar.Parent = gui
local barScale = scaleOf(bar)
local bl = Instance.new("UIListLayout")
bl.FillDirection = Enum.FillDirection.Horizontal
bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
bl.Padding = UDim.new(0, 16)
bl.SortOrder = Enum.SortOrder.LayoutOrder
bl.Parent = bar

local uiClicked = 0 -- when a build button last took a click
local function watchButtons(root)
	local function hook(d)
		if d:IsA("GuiButton") then d.Activated:Connect(function() uiClicked = os.clock() end) end
	end
	for _, d in ipairs(root:GetDescendants()) do hook(d) end
	root.DescendantAdded:Connect(hook)
end
local uiHover = {} -- round buttons under the mouse (BillboardGui buttons don't show up in GetGuiObjectsAtPosition)

local function roundButton(parent, key, text, colors, order)
	local b = Instance.new("TextButton")
	b.Name = text
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = order or 0
	b.Size = UDim2.fromOffset(78, 96)
	b.BackgroundTransparency = 1
	b.Parent = parent
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.fromScale(0.5, 0)
	disc.Size = UDim2.fromOffset(68, 68)
	disc.BackgroundColor3 = Color3.new(1, 1, 1)
	disc.Parent = b
	corner(disc)
	stroke(disc, 3.5)
	local g = grad(disc, colors[1], colors[2])
	local im = icon(disc, key, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local t = label(b, text, UDim2.new(1, 16, 0, 26), UDim2.new(0, -8, 0, 70))
	local s = scaleOf(disc)
	b.MouseEnter:Connect(function() uiHover[b] = true; tween(s, 0.25, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() uiHover[b] = nil; tween(s, 0.25, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(s, 0.08, { Scale = 0.9 }) end)
	b.MouseButton1Up:Connect(function() tween(s, 0.3, { Scale = 1.1 }, Enum.EasingStyle.Back) end)
	return b, t, g, im
end

local YELLOW = { Color3.fromRGB(255, 232, 80), Color3.fromRGB(250, 180, 30) }
local GREEN = { Color3.fromRGB(140, 240, 110), Color3.fromRGB(50, 180, 70) }
local BLUE = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 130, 230) }
local RED = { Color3.fromRGB(255, 140, 130), Color3.fromRGB(220, 60, 60) }
local GREY = { Color3.fromRGB(220, 216, 230), Color3.fromRGB(160, 154, 176) }

local rotBtn = roundButton(bar, "rotate", "Turn", BLUE, 1)
local placeBtn, placeLbl, placeGrad = roundButton(bar, "place", "Place", GREEN, 2)
local cancelBtn = roundButton(bar, "close", "Cancel", RED, 3)

---------------------------------------------------------------- thumbnails

local function thumb(parent, id)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(170, 160, 190)
	vf.LightColor = Color3.fromRGB(255, 246, 230)
	vf.LightDirection = Vector3.new(-1, -2, -1.4)
	vf.Parent = parent
	local m = ITEMS[id]:Clone()
	m:PivotTo(CFrame.new())
	m.Parent = vf
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local r = size.Magnitude / 2
	local dir = Vector3.new(0.75, 0.62, 1).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * (r / math.tan(math.rad(15)) * 0.95), cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

---------------------------------------------------------------- shop cards

local cards = {}
local startPlacing -- forward

local refreshRoomCard -- forward (the room card)
local function refreshCards()
	local money = cash()
	for id, c in pairs(cards) do
		local item = Catalog.ITEMS[id]
		c.frame.Visible = cat == "all" or item.cat == cat
		local afford = money >= item.price
		c.price.TextColor3 = afford and Color3.fromRGB(150, 255, 130) or Color3.fromRGB(255, 130, 120)
		c.shade.Visible = not afford
		local sel = ghost and not ghost.moving and ghost.id == id
		c.stroke.Color = sel and Color3.fromRGB(255, 196, 40) or INK
		c.stroke.Thickness = sel and 5 or 3
	end
	if refreshRoomCard then refreshRoomCard() end
end

for i, id in ipairs(Catalog.ORDER) do
	local item = Catalog.ITEMS[id]
	if ITEMS:FindFirstChild(id) then
		local b = Instance.new("TextButton")
		b.Name = id
		b.Text = ""
		b.AutoButtonColor = false
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(132, 146)
		b.BackgroundTransparency = 1
		b.Parent = list
		local f = Instance.new("Frame")
		f.Name = "Card"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Parent = b
		corner(f, UDim.new(0, 18))
		local st = stroke(f, 3)
		grad(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(230, 224, 244))
		local vf = thumb(f, id)
		vf.Size = UDim2.new(1, -10, 0, 84)
		vf.Position = UDim2.fromOffset(5, 4)
		local name = label(f, item.name, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 86), Color3.fromRGB(70, 60, 84), false)
		local pill = Instance.new("Frame")
		pill.Position = UDim2.new(0, 8, 1, -34)
		pill.Size = UDim2.new(1, -16, 0, 26)
		pill.BackgroundColor3 = Color3.fromRGB(70, 56, 92)
		pill.Parent = f
		corner(pill)
		local price = label(pill, "$" .. commas(item.price), UDim2.new(0.6, 0, 1, -4), UDim2.fromOffset(8, 2), Color3.fromRGB(150, 255, 130))
		price.TextXAlignment = Enum.TextXAlignment.Left
		icon(pill, "star", UDim2.fromOffset(26, 26), UDim2.new(1, -54, 0.5, 0), Vector2.new(0, 0.5))
		local ap = label(pill, "+" .. item.appeal, UDim2.new(0, 28, 1, -6), UDim2.new(1, -30, 0, 3), Color3.fromRGB(255, 226, 120))
		ap.TextXAlignment = Enum.TextXAlignment.Left
		local shade = Instance.new("Frame")
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundColor3 = Color3.fromRGB(40, 30, 56)
		shade.BackgroundTransparency = 0.55
		shade.Visible = false
		shade.ZIndex = 5
		shade.Parent = f
		corner(shade, UDim.new(0, 18))
		local s = scaleOf(f)
		b.MouseEnter:Connect(function()
			tween(s, 0.25, { Scale = 1.06 }, Enum.EasingStyle.Back)
			tween(f, 0.25, { Position = UDim2.fromOffset(0, -6) })
		end)
		b.MouseLeave:Connect(function()
			tween(s, 0.25, { Scale = 1 })
			tween(f, 0.25, { Position = UDim2.new() })
		end)
		b.Activated:Connect(function()
			pop(f, 0.9)
			if cash() < item.price then
				toast("Not enough cash for the " .. string.lower(item.name), "cash", true)
				return
			end
			startPlacing(id)
		end)
		cards[id] = { frame = b, card = f, stroke = st, price = price, shade = shade }
	end
end

-- the next room for sale (Hotel attributes NextRoom / NextRoomPrice): first card in All and Rooms
local buyRoom -- forward
local roomCard = Instance.new("TextButton")
roomCard.Name = "RoomCard"
roomCard.Text = ""
roomCard.AutoButtonColor = false
roomCard.LayoutOrder = -100
roomCard.Size = UDim2.fromOffset(200, 146)
roomCard.BackgroundTransparency = 1
roomCard.Parent = list
local rc = Instance.new("Frame")
rc.Name = "Card"
rc.Size = UDim2.fromScale(1, 1)
rc.BackgroundColor3 = Color3.new(1, 1, 1)
rc.Parent = roomCard
corner(rc, UDim.new(0, 18))
local rcStroke = stroke(rc, 3)
local rcGrad = grad(rc, Color3.fromRGB(255, 244, 200), Color3.fromRGB(255, 214, 120))
icon(rc, "bed", UDim2.fromOffset(92, 92), UDim2.new(0.5, 0, 0, -4), Vector2.new(0.5, 0))
local rcNew = Instance.new("Frame")
rcNew.AnchorPoint = Vector2.new(1, 0)
rcNew.Position = UDim2.new(1, -6, 0, 6)
rcNew.Size = UDim2.fromOffset(58, 24)
rcNew.Rotation = 8
rcNew.BackgroundColor3 = Color3.fromRGB(240, 70, 80)
rcNew.Parent = rc
corner(rcNew)
stroke(rcNew, 2.5)
label(rcNew, "NEW", UDim2.fromScale(0.86, 0.86), UDim2.fromScale(0.07, 0.07))
local rcName = label(rc, "Room 104", UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 84), Color3.fromRGB(255, 255, 255))
local rcPill = Instance.new("Frame")
rcPill.Position = UDim2.new(0, 8, 1, -34)
rcPill.Size = UDim2.new(1, -16, 0, 26)
rcPill.BackgroundColor3 = Color3.fromRGB(70, 56, 92)
rcPill.Parent = rc
corner(rcPill)
local rcPrice = label(rcPill, "$400", UDim2.new(0.6, 0, 1, -4), UDim2.fromOffset(8, 2), Color3.fromRGB(150, 255, 130))
rcPrice.TextXAlignment = Enum.TextXAlignment.Left
local rcHint = label(rcPill, "+1 room", UDim2.new(0.42, 0, 1, -6), UDim2.new(0.56, 0, 0, 3), Color3.fromRGB(255, 226, 120))
rcHint.TextXAlignment = Enum.TextXAlignment.Right
local rcShade = Instance.new("Frame")
rcShade.Size = UDim2.fromScale(1, 1)
rcShade.BackgroundColor3 = Color3.fromRGB(40, 30, 56)
rcShade.BackgroundTransparency = 0.55
rcShade.Visible = false
rcShade.ZIndex = 5
rcShade.Parent = rc
corner(rcShade, UDim.new(0, 18))
local rcArmed = 0 -- time of the first click; a second click within 4 s buys

refreshRoomCard = function()
	local id = HOTEL:GetAttribute("NextRoom")
	local price = HOTEL:GetAttribute("NextRoomPrice") or 0
	roomCard.Visible = id ~= nil and (cat == "all" or cat == "rooms")
	if not id then return end
	local armed = os.clock() - rcArmed < 4
	rcName.Text = armed and "Click again to buy" or ("Room " .. id)
	rcPrice.Text = "$" .. commas(price)
	local afford = cash() >= price
	rcPrice.TextColor3 = afford and Color3.fromRGB(150, 255, 130) or Color3.fromRGB(255, 130, 120)
	rcShade.Visible = not afford
	rcStroke.Color = armed and Color3.fromRGB(255, 255, 255) or INK
	rcStroke.Thickness = armed and 5 or 3
	rcGrad.Color = armed and ColorSequence.new(Color3.fromRGB(170, 250, 140), Color3.fromRGB(60, 190, 80))
		or ColorSequence.new(Color3.fromRGB(255, 226, 120), Color3.fromRGB(246, 160, 40))
end
HOTEL:GetAttributeChangedSignal("NextRoom"):Connect(refreshRoomCard)

do
	local s = scaleOf(rc)
	roomCard.MouseEnter:Connect(function()
		tween(s, 0.25, { Scale = 1.06 }, Enum.EasingStyle.Back)
		tween(rc, 0.25, { Position = UDim2.fromOffset(0, -6) })
	end)
	roomCard.MouseLeave:Connect(function()
		tween(s, 0.25, { Scale = 1 })
		tween(rc, 0.25, { Position = UDim2.new() })
	end)
	roomCard.Activated:Connect(function()
		pop(rc, 0.9)
		local id = HOTEL:GetAttribute("NextRoom")
		if not id then return end
		if cash() < (HOTEL:GetAttribute("NextRoomPrice") or 0) then
			toast("Not enough cash for Room " .. id, "cash", true)
			return
		end
		if os.clock() - rcArmed > 4 then
			rcArmed = os.clock()
			refreshRoomCard()
			task.delay(4.1, refreshRoomCard)
			return
		end
		rcArmed = 0
		buyRoom(id)
		refreshRoomCard()
	end)
end

local tabButtons = {}
local function setCat(id)
	cat = id
	for cid, t in pairs(tabButtons) do
		local on = cid == id
		t.grad.Color = on and ColorSequence.new(YELLOW[1], YELLOW[2]) or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 208, 230))
		t.text.TextColor3 = on and Color3.new(1, 1, 1) or Color3.fromRGB(90, 78, 110)
		t.textStroke.Enabled = on
	end
	refreshCards()
	list.CanvasPosition = Vector2.zero
end

for i, c in ipairs(Catalog.CATS) do
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(c.id == "furniture" and 150 or 112, 46)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Parent = tabs
	corner(b)
	stroke(b, 3)
	local g = grad(b, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	icon(b, c.icon, UDim2.fromOffset(46, 46), UDim2.new(0, -4, 0.5, 0), Vector2.new(0, 0.5))
	local t = label(b, c.name, UDim2.new(1, -52, 0, 28), UDim2.fromOffset(42, 9))
	t.TextXAlignment = Enum.TextXAlignment.Left
	tabButtons[c.id] = { grad = g, text = t, textStroke = t:FindFirstChildOfClass("UIStroke") }
	b.Activated:Connect(function()
		pop(b, 0.85)
		setCat(c.id)
	end)
end
setCat("all")

-- cash readout on the shop's top-right corner
local shopCash = Instance.new("Frame")
shopCash.AnchorPoint = Vector2.new(1, 0)
shopCash.Position = UDim2.new(1, -18, 0, -24)
shopCash.Size = UDim2.fromOffset(170, 44)
shopCash.BackgroundColor3 = Color3.fromRGB(70, 56, 92)
shopCash.Parent = shop
corner(shopCash)
stroke(shopCash, 3)
icon(shopCash, "cash", UDim2.fromOffset(52, 52), UDim2.new(0, -12, 0.5, 0), Vector2.new(0, 0.5))
local shopCashText = label(shopCash, "$0", UDim2.new(1, -52, 0, 30), UDim2.fromOffset(42, 7), Color3.fromRGB(150, 255, 130))
shopCashText.TextXAlignment = Enum.TextXAlignment.Left

local function refreshCash()
	shopCashText.Text = "$" .. commas(cash())
	refreshCards()
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
refreshCash()

---------------------------------------------------------------- layout

local function layout()
	local vp = camera.ViewportSize
	local k = uiK()
	buildScale.Scale = k
	barScale.Scale = k
	shopScale.Scale = k
	-- keep clear of the cash stack on the bottom left (about 340 px wide)
	local left = 20 + 350 * k
	local span = vp.X - left - 20
	local w = math.min(span / k, 1000)
	shop.Size = UDim2.fromOffset(w, 196)
	shop.Position = UDim2.new(0, left + span / 2, 1, -14)
	bar.Position = UDim2.new(0, left + span / 2, 1, -14 - 230 * k)
	hint.Position = UDim2.new(0, left + span / 2, 1, -14 - (bar.Visible and 372 or 228) * k)
	hint.Size = UDim2.fromOffset(700 * k, 26 * k)
	if building then
		buildBtn.AnchorPoint = Vector2.new(1, 0)
		buildBtn.Position = UDim2.new(1, -24, 0, 22)
	else
		buildBtn.AnchorPoint = Vector2.new(0.5, 1)
		buildBtn.Position = UDim2.new(0.5, 0, 1, -18)
	end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

---------------------------------------------------------------- zone overlays + room labels (local only)

-- local-only build visuals live here (parts under the camera don't show in Studio captures)
local localFolder = Instance.new("Folder")
localFolder.Name = "RAH_BuildLocal"
localFolder.Parent = workspace

local overlay = Instance.new("Folder")
overlay.Name = "RAH_BuildOverlay"
local labels = {}

local function flatPlate(src, color, transp, outline)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transp
	p.Size = Vector3.new(src.Size.X, 0.06, src.Size.Z)
	p.CFrame = CFrame.new(src.Position.X, Build.FY + 0.13, src.Position.Z)
	p.Parent = overlay
	if outline then
		local sb = Instance.new("SelectionBox")
		sb.Adornee = p
		sb.Color3 = color
		sb.LineThickness = 0.08
		sb.SurfaceTransparency = 1
		sb.Transparency = 0.25
		sb.Parent = p
	end
	return p
end

local function roomLabel(zone)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RAH_ZoneLabel"
	bb.Size = UDim2.fromOffset(230, 96)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Adornee = zone
	bb.StudsOffsetWorldSpace = Vector3.new(0, 11, zone.Name == "Lobby" and 6 or 0)
	bb.Enabled = false
	bb.Parent = pgui
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Parent = bb
	local title = label(f, "", UDim2.new(1, 0, 0, 36), UDim2.new(), Color3.fromRGB(255, 236, 170))
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 42)
	pill.Size = UDim2.fromOffset(212, 44)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = f
	corner(pill)
	stroke(pill, 3)
	grad(pill, Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 236))
	icon(pill, "star", UDim2.fromOffset(46, 46), UDim2.new(0, -8, 0.5, 0), Vector2.new(0, 0.5))
	local info = label(pill, "", UDim2.new(1, -50, 0, 28), UDim2.fromOffset(40, 8), Color3.fromRGB(70, 60, 84), false)
	info.TextXAlignment = Enum.TextXAlignment.Left
	labels[zone.Name] = { bb = bb, title = title, info = info, frame = f }
end

local function refreshLabels()
	for name, l in pairs(labels) do
		if name == "Lobby" then
			l.title.Text = "LOBBY"
			l.info.Text = "Appeal " .. (HOTEL:GetAttribute("LobbyAppeal") or 0) .. "  ·  happier queue"
		else
			local room = HOTEL.Rooms:FindFirstChild(name)
			if room then
				l.title.Text = "ROOM " .. (room:GetAttribute("RoomId") or "")
				l.info.Text = "Appeal " .. (room:GetAttribute("Appeal") or 0) .. "  ·  $" .. (room:GetAttribute("Price") or C.ROOM_PRICE) .. " a night"
			end
		end
	end
end

-- built on entering build mode: with streaming, the zone parts may not be here at startup
local function makeOverlay()
	overlay:ClearAllChildren()
	for _, z in ipairs(ZONES:GetChildren()) do
		if z:IsA("BasePart") then
			flatPlate(z, Color3.fromRGB(150, 230, 255), 0.88, true)
			if not labels[z.Name] then
				roomLabel(z)
				local room = HOTEL.Rooms:FindFirstChild(z.Name)
				if room then
					room:GetAttributeChangedSignal("Appeal"):Connect(refreshLabels)
					room:GetAttributeChangedSignal("Price"):Connect(refreshLabels)
				end
			end
		end
	end
	for _, z in ipairs(ZONES.NoBuild:GetChildren()) do
		if z:IsA("BasePart") then
			local p = flatPlate(z, Color3.fromRGB(255, 110, 100), 0.7, true)
			p.Position += Vector3.new(0, 0.02, 0)
		end
	end
end
HOTEL:GetAttributeChangedSignal("LobbyAppeal"):Connect(refreshLabels)
refreshLabels()

---------------------------------------------------------------- build camera

local cam = { focus = Vector3.new(0, Build.FY, 0), yaw = 0, pitch = math.rad(52), dist = 62 }
local goal = { focus = cam.focus, yaw = 0, pitch = cam.pitch, dist = cam.dist }
local BOUNDS = { -46, 46, -38, 40 }
local held = {}
local rightDown, rightMoved = false, 0
local touches = {}
local controls

local function camCF(s)
	local rot = CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(-s.pitch, 0, 0)
	return CFrame.new(s.focus) * rot * CFrame.new(0, 0, s.dist)
end

local function stepCamera(dt)
	local pan = Vector3.zero
	local fwd = Vector3.new(-math.sin(goal.yaw), 0, -math.cos(goal.yaw))
	local right = Vector3.new(math.cos(goal.yaw), 0, -math.sin(goal.yaw))
	if held[Enum.KeyCode.W] or held[Enum.KeyCode.Up] then pan += fwd end
	if held[Enum.KeyCode.S] or held[Enum.KeyCode.Down] then pan -= fwd end
	if held[Enum.KeyCode.D] or held[Enum.KeyCode.Right] then pan += right end
	if held[Enum.KeyCode.A] or held[Enum.KeyCode.Left] then pan -= right end
	if pan.Magnitude > 0 then goal.focus += pan.Unit * dt * (24 + goal.dist * 0.6) end
	if held[Enum.KeyCode.Q] then goal.yaw += dt * 1.8 end
	if held[Enum.KeyCode.E] then goal.yaw -= dt * 1.8 end
	local x0 = O.X + math.min(BOUNDS[1], (HOTEL:GetAttribute("MinX") or -40) - 6)
	local x1 = O.X + math.max(BOUNDS[2], (HOTEL:GetAttribute("MaxX") or 40) + 6)
	goal.focus = Vector3.new(math.clamp(goal.focus.X, x0, x1), Build.FY, math.clamp(goal.focus.Z, BOUNDS[3], BOUNDS[4]))
	goal.dist = math.clamp(goal.dist, 22, 105)
	local a = 1 - math.exp(-dt * 10)
	cam.focus = cam.focus:Lerp(goal.focus, a)
	cam.yaw += (goal.yaw - cam.yaw) * a
	cam.pitch += (goal.pitch - cam.pitch) * a
	cam.dist += (goal.dist - cam.dist) * a
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camCF(cam)
end

---------------------------------------------------------------- picking

local function mouseRay(pos)
	pos = pos or UIS:GetMouseLocation()
	return camera:ViewportPointToRay(pos.X, pos.Y)
end

local function floorPoint(pos)
	local r = mouseRay(pos)
	if math.abs(r.Direction.Y) < 1e-4 then return nil end
	local t = (Build.FY - r.Origin.Y) / r.Direction.Y
	if t < 0 then return nil end
	return r.Origin + r.Direction * t
end

local pickParams = RaycastParams.new()
pickParams.FilterType = Enum.RaycastFilterType.Include
local function placedAt(pos)
	local r = mouseRay(pos)
	pickParams.FilterDescendantsInstances = { PLACED, deskModel }
	local hit = workspace:Raycast(r.Origin, r.Direction * 500, pickParams)
	if not hit then return nil end
	if deskModel and hit.Instance:IsDescendantOf(deskModel) then return deskModel end
	return Build.placedOf(hit.Instance)
end

local function overGui(pos)
	if not pos and next(uiHover) then return true end
	pos = pos or UIS:GetMouseLocation()
	for _, o in ipairs(pgui:GetGuiObjectsAtPosition(pos.X, pos.Y - game:GetService("GuiService"):GetGuiInset().Y)) do
		if o:IsDescendantOf(gui) and o.Visible and (o:IsA("GuiButton") or o == shop or o:IsDescendantOf(shop)) then return true end
		if o:FindFirstAncestorWhichIsA("BillboardGui") and o:FindFirstAncestorWhichIsA("BillboardGui").Name == "RAH_ItemCard" then return true end
	end
	return false
end

---------------------------------------------------------------- highlights

local hoverHL = Instance.new("Highlight")
hoverHL.Name = "RAH_Hover"
hoverHL.FillTransparency = 0.85
hoverHL.FillColor = Color3.new(1, 1, 1)
hoverHL.OutlineColor = Color3.new(1, 1, 1)
hoverHL.DepthMode = Enum.HighlightDepthMode.Occluded
hoverHL.Enabled = false
hoverHL.Parent = pgui

local selHL = Instance.new("Highlight")
selHL.Name = "RAH_Selected"
selHL.FillTransparency = 0.75
selHL.FillColor = Color3.fromRGB(255, 210, 60)
selHL.OutlineColor = Color3.fromRGB(255, 220, 90)
selHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
selHL.Enabled = false
selHL.Parent = pgui

local function setLocalHidden(model, on)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 1 or 0 end
	end
end

---------------------------------------------------------------- the item card (move / turn / sell)

local function anchorPart()
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	return p
end
local cardWorld = Vector3.zero -- the card floats over this point, drawn in screen space each frame

local cardRoot = Instance.new("Frame")
cardRoot.Name = "ItemCard"
cardRoot.BackgroundTransparency = 1
cardRoot.AnchorPoint = Vector2.new(0.5, 1)
cardRoot.Size = UDim2.fromOffset(330, 150)
cardRoot.Visible = false
cardRoot.Parent = gui
local cardTitle = label(cardRoot, "", UDim2.new(1, 0, 0, 30), UDim2.new(), Color3.fromRGB(255, 236, 170))
local cardRow = Instance.new("Frame")
cardRow.BackgroundTransparency = 1
cardRow.Position = UDim2.fromOffset(0, 36)
cardRow.Size = UDim2.new(1, 0, 0, 100)
cardRow.Parent = cardRoot
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.Padding = UDim.new(0, 6)
cl.SortOrder = Enum.SortOrder.LayoutOrder
cl.Parent = cardRow
local moveBtn = roundButton(cardRow, "move", "Move", YELLOW, 1)
local turnBtn = roundButton(cardRow, "rotate", "Turn", BLUE, 2)
local sellBtn, sellLbl, sellGrad = roundButton(cardRow, "sell", "Sell", GREEN, 3)
local closeBtn = roundButton(cardRow, "close", "Close", RED, 4)
local sellArmed = false

local function cardScale()
	local v = camera:WorldToViewportPoint(cardWorld)
	cardRoot.Position = UDim2.fromOffset(v.X, v.Y)
end

local function closeCard()
	selected = nil
	sellArmed = false
	cardRoot.Visible = false
	selHL.Enabled = false
end

local function openCard(m)
	if m == deskModel then
		-- the reception desk: move and turn only, it's part of the hotel
		if selected ~= m then sfx("select") end
		selected = m
		sellArmed = false
		cardTitle.Text = "Reception Desk"
		sellLbl.Text = "Built-in"
		sellGrad.Color = ColorSequence.new(GREY[1], GREY[2])
		local _, size = Build.box("Desk")
		cardWorld = m:GetPivot().Position + Vector3.new(0, size.Y + 1, 0)
		cardScale()
		cardRoot.Visible = true
		local s = scaleOf(cardRoot)
		s.Scale = uiK() * 0.6
		tween(s, 0.4, { Scale = uiK() }, Enum.EasingStyle.Back)
		selHL.Adornee = m
		selHL.Enabled = true
		return
	end
	if selected ~= m then sfx("select") end
	selected = m
	sellArmed = false
	local id = m:GetAttribute("Item")
	local item = Catalog.ITEMS[id]
	cardTitle.Text = item and item.name or id
	local isCore = m:GetAttribute("Core") ~= nil
	sellLbl.Text = isCore and "Needed" or ("Sell $" .. Catalog.sellValue(id))
	sellGrad.Color = isCore and ColorSequence.new(GREY[1], GREY[2]) or ColorSequence.new(GREEN[1], GREEN[2])
	local _, size = Build.box(id)
	cardWorld = m:GetPivot().Position + Vector3.new(0, size.Y + 1, 0)
	cardScale()
	cardRoot.Visible = true
	local s = scaleOf(cardRoot)
	s.Scale = uiK() * 0.6
	tween(s, 0.4, { Scale = uiK() }, Enum.EasingStyle.Back)
	selHL.Adornee = m
	selHL.Enabled = true
end

---------------------------------------------------------------- ghost

local ghostParams = OverlapParams.new()

local function clearGhost()
	if not ghost then return end
	if ghost.model then ghost.model:Destroy() end
	if ghost.tip then ghost.tip:Destroy() end
	ghost.hl:Destroy()
	ghost.tipAnchor:Destroy()
	if ghost.moving and ghost.moving.Parent then setLocalHidden(ghost.moving, false) end
	ghost = nil
	bar.Visible = false
	layout()
	refreshCards()
end

local function makeGhost(id, turns, moving)
	clearGhost()
	closeCard()
	local m = ITEMS[id]:Clone()
	m.Name = "RAH_Ghost"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
			d.Transparency = math.max(d.Transparency, 0.25)
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	-- the bed ghost is just the made bed
	local messy = m:FindFirstChild("Messy")
	if messy then messy:Destroy() end
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = m
	hl.Parent = pgui
	local tipAnchor = anchorPart()
	tipAnchor.Parent = localFolder
	local tip = Instance.new("BillboardGui")
	tip.Size = UDim2.fromOffset(320, 40)
	tip.AlwaysOnTop = true
	tip.LightInfluence = 0
	tip.Parent = pgui
	local tt = label(tip, "", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1))
	local start = moving and moving:GetPivot() or nil
	ghost = {
		id = id, model = m, turns = turns or 0, moving = moving, hl = hl, tip = tip, tipText = tt, tipAnchor = tipAnchor,
		target = start, shown = start, ok = false, spin = 0,
	}
	local p = floorPoint()
	if start then
		m:PivotTo(start)
	elseif p then
		local cf = Build.snap(id, p, ghost.turns)
		ghost.target, ghost.shown = cf, cf
		m:PivotTo(cf)
	end
	m.Parent = localFolder
	tip.Adornee = tipAnchor
	if moving then setLocalHidden(moving, true) end
	placeLbl.Text = moving and "Drop" or "Place"
	bar.Visible = true
	pop(bar, 0.7)
	layout()
	refreshCards()
end

startPlacing = function(id)
	makeGhost(id, ghost and ghost.turns or 0)
end

local function validateGhost()
	if not ghost or not ghost.target then return end
	local ok, why
	if ghost.moving == deskModel then
		ok, why = Build.deskOk(HOTEL, ghost.target)
	else
		ok, why = Build.validate(ghost.id, ghost.target, ghost.moving)
	end
	local item = Catalog.ITEMS[ghost.id]
	if ok and not ghost.moving and cash() < (item.price or 0) then ok, why = false, "Not enough cash" end
	ghost.ok, ghost.why = ok, why
	local col = ok and GOOD or BAD
	ghost.hl.FillColor = col
	ghost.hl.OutlineColor = col
	if ok then
		ghost.tipText.Text = ghost.moving and "Drop it here" or ("$" .. commas(item.price) .. "  ·  +" .. item.appeal .. " appeal")
		ghost.tipText.TextColor3 = Color3.fromRGB(190, 255, 170)
	else
		ghost.tipText.Text = why or "Can't go here"
		ghost.tipText.TextColor3 = Color3.fromRGB(255, 160, 150)
	end
	placeGrad.Color = ok and ColorSequence.new(GREEN[1], GREEN[2]) or ColorSequence.new(GREY[1], GREY[2])
end

local function aimGhost(pos)
	if not ghost then return end
	local p = floorPoint(pos)
	if not p then return end
	local cf = Build.snap(ghost.id, p, ghost.turns)
	if not ghost.target or (cf.Position - ghost.target.Position).Magnitude > 0.01 or not cf.Rotation:FuzzyEq(ghost.target.Rotation, 1e-3) then
		ghost.target = cf
		if not ghost.shown then ghost.shown = cf end
		validateGhost()
	end
end

local function turnGhost()
	if not ghost then return end
	ghost.turns = (ghost.turns + 1) % 4
	ghost.spin = 1
	sfx("turn")
	if ghost.target then
		ghost.target = Build.snap(ghost.id, ghost.target.Position, ghost.turns)
		validateGhost()
	end
end

-- a little bounce + dust ring where something lands
local function landFX(m, cf)
	if not m or not m.Parent then return end
	local v = Instance.new("CFrameValue")
	v.Value = cf * CFrame.new(0, 1.6, 0)
	v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
	m:PivotTo(v.Value)
	local tw = tween(v, 0.35, { Value = cf }, Enum.EasingStyle.Bounce)
	tw.Completed:Connect(function() v:Destroy() end)
	local a = Instance.new("Part")
	a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
	a.Size = Vector3.one
	a.Position = cf.Position + Vector3.new(0, 0.4, 0)
	a.Parent = localFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 248, 236))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(1, 2.4)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(10, 14)
	e.Drag = 6
	e.SpreadAngle = Vector2.new(0, 180)
	e.EmissionDirection = Enum.NormalId.Right
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Parent = a
	task.delay(0.18, function() e:Emit(18) end)
	game:GetService("Debris"):AddItem(a, 1.5)
end

local function commit()
	if not ghost or busy then return end
	if not ghost.target then return end
	if not ghost.ok then
		pop(ghost.tipText, 1.3)
		toast(ghost.why or "Can't go here", "close", true)
		return
	end
	busy = true
	local g = ghost
	local cf = g.target
	local ok, res
	if g.moving == deskModel then
		ok, res = Remote:InvokeServer("desk", cf)
	elseif g.moving then
		ok, res = Remote:InvokeServer("move", g.moving:GetAttribute("Uid"), cf)
	else
		ok, res = Remote:InvokeServer("place", g.id, cf)
	end
	busy = false
	if not ok then
		toast(res or "Can't go here", "close", true)
		return
	end
	if g.moving then
		local m = g.moving
		clearGhost()
		landFX(m, cf)
	else
		-- find the new item and give it a landing
		local new
		for _, m in ipairs(PLACED:GetChildren()) do
			if m:GetAttribute("Uid") == res then new = m end
		end
		local keep = (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift))
			and cash() >= (Catalog.ITEMS[g.id].price or 0)
		if keep then
			validateGhost()
		else
			clearGhost()
		end
		if new then landFX(new, cf) end
	end
end

---------------------------------------------------------------- card buttons

moveBtn.Activated:Connect(function()
	local m = selected
	if not m then return end
	if m == deskModel then
		local _, yaw = m:GetPivot():ToEulerAnglesYXZ()
		makeGhost("Desk", math.floor(yaw / (math.pi / 2) + 0.5) % 4, m)
		return
	end
	local room = m:GetAttribute("Room") and HOTEL.Rooms:FindFirstChild(m:GetAttribute("Room"))
	if room and room:GetAttribute("State") == "Booked" then
		toast("A guest is using this room", "guest", true)
		return
	end
	local _, yaw = m:GetPivot():ToEulerAnglesYXZ()
	makeGhost(m:GetAttribute("Item"), math.floor(yaw / (math.pi / 2) + 0.5) % 4, m)
end)

turnBtn.Activated:Connect(function()
	local m = selected
	if not m or busy then return end
	busy = true
	local cf = m:GetPivot() * CFrame.Angles(0, math.rad(90), 0)
	local ok, why
	if m == deskModel then
		ok, why = Remote:InvokeServer("desk", cf)
	else
		ok, why = Remote:InvokeServer("move", m:GetAttribute("Uid"), cf)
	end
	busy = false
	if ok then
		local v = Instance.new("CFrameValue")
		v.Value = cf * CFrame.Angles(0, math.rad(-90), 0)
		v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
		local tw = tween(v, 0.35, { Value = cf }, Enum.EasingStyle.Back)
		tw.Completed:Connect(function() v:Destroy() end)
	else
		toast(why or "No room to turn it", "close", true)
	end
end)

sellBtn.Activated:Connect(function()
	local m = selected
	if not m or busy then return end
	if m == deskModel then
		toast("The reception desk is part of the hotel", "close", true)
		return
	end
	if m:GetAttribute("Core") then
		toast("Every room needs its " .. string.lower(Catalog.ITEMS[m:GetAttribute("Item")].name), "bed", true)
		return
	end
	if not sellArmed then
		sellArmed = true
		sellLbl.Text = "Sure?"
		sellGrad.Color = ColorSequence.new(RED[1], RED[2])
		pop(sellBtn, 1.2)
		return
	end
	busy = true
	local ok, why = Remote:InvokeServer("sell", m:GetAttribute("Uid"))
	busy = false
	if ok then
		closeCard()
	else
		toast(why or "Can't sell that", "close", true)
	end
end)

closeBtn.Activated:Connect(closeCard)
rotBtn.Activated:Connect(turnGhost)
placeBtn.Activated:Connect(commit)
cancelBtn.Activated:Connect(clearGhost)

watchButtons(gui)

---------------------------------------------------------------- enter / leave

-- the character stands still while you build (PlayerModule may not exist, so hold the humanoid too)
local saved
local function setControls(on)
	if not controls then
		local pmod = player.PlayerScripts:FindFirstChild("PlayerModule")
		local ok, pm = pcall(function() return pmod and require(pmod) end)
		if ok and pm then controls = pm:GetControls() end
	end
	if controls then
		if on then controls:Enable() else controls:Disable() end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if not on then
		saved = saved or { hum.WalkSpeed, hum.JumpPower, hum.JumpHeight }
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
		hum:Move(Vector3.zero)
	elseif saved then
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = saved[1], saved[2], saved[3]
		saved = nil
	end
end

-- the glass front, sign and canopy hide the lobby from above: fade them while building
local facade
local function setFacade(on)
	if on or not facade then
		facade = {}
		for _, f in ipairs({ HOTEL:FindFirstChild("Shell"), HOTEL:FindFirstChild("Doors") }) do
			for _, d in ipairs(f and f:GetDescendants() or {}) do
				if d:IsA("BasePart") and d.Position.Z > 28.5 and d.Size.Y > 0.6 then table.insert(facade, d) end
			end
		end
	end
	for _, d in ipairs(facade) do d.LocalTransparencyModifier = on and 0.92 or 0 end
	for _, d in ipairs(HOTEL.Shell:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") and d.Parent.Position.Z > 28.5 then d.Enabled = not on end
	end
end

---------------------------------------------------------------- new rooms

-- walls, floor and furniture of a new wing rise out of the ground, front to back, with a confetti pop
local function riseWing(id, pos)
	task.wait(0.15)
	local parts = {}
	local function grab(root)
		if not root then return end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(parts, d) end
		end
	end
	grab(HOTEL.Shell:FindFirstChild("Wing" .. id))
	grab(HOTEL.Rooms:FindFirstChild("Room" .. id))
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Zone") == "Room" .. id then grab(m) end
	end
	for _, p in ipairs(parts) do
		local cf = p.CFrame
		local delay = math.clamp((30 - p.Position.Z) / 60, 0, 1) * 0.9 + math.clamp(p.Position.Y / 14, 0, 1) * 0.35
		p.CFrame = cf * CFrame.new(0, -16, 0)
		task.delay(delay, function()
			if p.Parent then tween(p, 0.55, { CFrame = cf }, Enum.EasingStyle.Back) end
		end)
	end
	task.delay(1.4, function()
		local a = Instance.new("Part")
		a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
		a.Size = Vector3.one
		a.Position = pos + Vector3.new(0, 14, 0)
		a.Parent = localFolder
		local e = Instance.new("ParticleEmitter")
		e.Texture = C.ICONS.star
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 240, 120)),
		})
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 1.6), NumberSequenceKeypoint.new(1, 0.3) })
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(26, 40)
		e.SpreadAngle = Vector2.new(70, 70)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Drag = 1.5
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 0.3
		e.Rate = 0
		e.Parent = a
		e:Emit(70)
		game:GetService("Debris"):AddItem(a, 3)
	end)
end

RAH.Remotes.Notify.OnClientEvent:Connect(function(kind, d)
	if kind ~= "roomBuilt" or d.hotel ~= HOTEL.Name then return end
	if building then
		goal.focus = Vector3.new(d.pos.X, Build.FY, d.pos.Z + 8)
		goal.dist = 72
		goal.pitch = math.rad(55)
		makeOverlay()
		refreshLabels()
		for _, l in pairs(labels) do l.bb.Enabled = true end
		setFacade(true)
	end
	riseWing(d.id, d.pos)
end)

buyRoom = function(id)
	if busy then return end
	busy = true
	clearGhost()
	closeCard()
	local ok, why = Remote:InvokeServer("room", id)
	busy = false
	if not ok then toast(why or "Couldn't buy that room", "close", true) end
end

local function enter()
	if player:GetAttribute("RAH_Plot") ~= HOTEL.Name then
		toast("You can only build in your own hotel", "hammer", true)
		return
	end
	building = true
	player:SetAttribute("RAH_Building", true)
	setControls(false)
	PPS.Enabled = false
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local look = camera.CFrame.LookVector
	goal.yaw = math.atan2(-look.X, -look.Z)
	local inside = hrp and math.abs(hrp.Position.X - O.X) < 40 and math.abs(hrp.Position.Z) < 30
	goal.focus = inside and Vector3.new(hrp.Position.X, Build.FY, hrp.Position.Z) or (O + Vector3.new(0, Build.FY, 2))
	if not inside then goal.yaw = 0 end
	goal.dist, goal.pitch = 70, math.rad(55)
	setFacade(true)
	-- start from where the play camera is, then glide up
	cam.focus = goal.focus
	cam.yaw = goal.yaw
	cam.pitch = math.rad(20)
	cam.dist = 18
	makeOverlay()
	overlay.Parent = localFolder
	for _, l in pairs(labels) do l.bb.Enabled = true end
	refreshLabels()
	buildText.Text = "Done"
	buildIcon.Image = C.ICONS.place
	buildGrad.Color = ColorSequence.new(GREEN[1], GREEN[2])
	shop.Visible = true
	layout()
	pop(buildBtn, 0.6)
	local s = scaleOf(shop)
	local k = uiK()
	s.Scale = k * 0.85
	tween(s, 0.45, { Scale = k }, Enum.EasingStyle.Back)
	hint.Text = TOUCH and "Drag to look around  ·  Pinch to zoom  ·  Tap furniture to edit"
		or "WASD move  ·  Q/E turn  ·  Scroll zoom  ·  R rotate  ·  Shift keeps placing  ·  Click furniture to edit"
	hint.Visible = true
	refreshCards()
	RunService:BindToRenderStep("RAH_BuildCam", Enum.RenderPriority.Camera.Value + 1, stepCamera)
end

local function leave()
	building = false
	player:SetAttribute("RAH_Building", nil)
	clearGhost()
	closeCard()
	hoverHL.Enabled = false
	hovered = nil
	RunService:UnbindFromRenderStep("RAH_BuildCam")
	camera.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	setControls(true)
	PPS.Enabled = true
	overlay.Parent = nil
	setFacade(false)
	for _, l in pairs(labels) do l.bb.Enabled = false end
	shop.Visible = false
	hint.Visible = false
	buildText.Text = "Build"
	buildIcon.Image = C.ICONS.hammer
	buildGrad.Color = ColorSequence.new(YELLOW[1], YELLOW[2])
	layout()
	pop(buildBtn, 0.6)
	table.clear(held)
end

local function toggle()
	if building then leave() else enter() end
end
buildBtn.Activated:Connect(toggle)
buildBtn.MouseEnter:Connect(function() tween(buildScale, 0.25, { Scale = uiK() * 1.07 }, Enum.EasingStyle.Back) end)
buildBtn.MouseLeave:Connect(function() tween(buildScale, 0.25, { Scale = uiK() }) end)

---------------------------------------------------------------- input

local clickDown
local function worldClick()
	if ghost then
		commit()
	else
		local m = placedAt()
		if m then
			if m == selected then closeCard() else openCard(m) end
		else
			closeCard()
		end
	end
end

local PAN_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Q] = true, [Enum.KeyCode.E] = true,
}

UIS.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.B and not gp then toggle() return end
	if not building then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if gp then return end
		if PAN_KEYS[input.KeyCode] then held[input.KeyCode] = true end
		if input.KeyCode == Enum.KeyCode.R then turnGhost() end
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Backspace then
			if ghost then clearGhost() else closeCard() end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if gp or overGui() then return end
		clickDown = UIS:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightDown, rightMoved = true, 0
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local down = clickDown
		clickDown = nil
		if not building or not down or (UIS:GetMouseLocation() - down).Magnitude > 8 then return end
		-- world clicks land on release, a beat later, unless a button took this click
		task.delay(0.05, function()
			if os.clock() - uiClicked < 0.25 then return end
			worldClick()
		end)
	elseif input.UserInputType == Enum.UserInputType.Keyboard then
		held[input.KeyCode] = nil
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if building and rightDown and rightMoved < 6 then
			if ghost then clearGhost() else closeCard() end
		end
		rightDown = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UIS.InputChanged:Connect(function(input, gp)
	if not building then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if gp or overGui() then return end
		goal.dist *= (1 - input.Position.Z * 0.12)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		if rightDown then
			rightMoved += math.abs(input.Delta.X) + math.abs(input.Delta.Y)
			if rightMoved >= 6 then UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end
			goal.yaw -= input.Delta.X * 0.008
			goal.pitch = math.clamp(goal.pitch + input.Delta.Y * 0.006, math.rad(25), math.rad(80))
		end
	end
end)

-- touch: one finger pans (or drags the ghost), two fingers pinch-zoom and twist
UIS.TouchStarted:Connect(function(t, gp)
	if not building or gp then return end
	touches[t] = { start = t.Position, last = t.Position, moved = 0 }
end)
UIS.TouchMoved:Connect(function(t)
	if not building or not touches[t] then return end
	local rec = touches[t]
	local d = t.Position - rec.last
	rec.moved += d.Magnitude
	local n = 0
	for _ in pairs(touches) do n += 1 end
	if n >= 2 then
		local a, b
		for tt, r in pairs(touches) do if not a then a = { tt, r } elseif not b then b = { tt, r } end end
		local pa, pb = a[1].Position, b[1].Position
		local la, lb = a[2].last, b[2].last
		local before = (Vector2.new(la.X, la.Y) - Vector2.new(lb.X, lb.Y)).Magnitude
		local after = (Vector2.new(pa.X, pa.Y) - Vector2.new(pb.X, pb.Y)).Magnitude
		if before > 10 then goal.dist *= before / math.max(after, 1) end
	elseif ghost and rec.moved > 8 then
		aimGhost(Vector2.new(t.Position.X, t.Position.Y + game:GetService("GuiService"):GetGuiInset().Y))
	else
		local k = goal.dist / 900
		local fwd = Vector3.new(-math.sin(goal.yaw), 0, -math.cos(goal.yaw))
		local right = Vector3.new(math.cos(goal.yaw), 0, -math.sin(goal.yaw))
		goal.focus += (-right * d.X + fwd * d.Y) * k
	end
	rec.last = t.Position
end)
UIS.TouchEnded:Connect(function(t)
	local rec = touches[t]
	touches[t] = nil
	if not building or not rec or rec.moved > 12 then return end
	local pos = Vector2.new(t.Position.X, t.Position.Y + game:GetService("GuiService"):GetGuiInset().Y)
	if overGui(pos) then return end
	if ghost then
		aimGhost(pos)
	else
		local m = placedAt(pos)
		if m then openCard(m) else closeCard() end
	end
end)

---------------------------------------------------------------- per frame

RunService.RenderStepped:Connect(function(dt)
	if not building then return end
	if ghost then
		if not TOUCH and not overGui() then aimGhost() end
		if ghost.target and ghost.model then
			local a = 1 - math.exp(-dt * 22)
			ghost.shown = ghost.shown and ghost.shown:Lerp(ghost.target, a) or ghost.target
			ghost.spin = math.max(ghost.spin - dt * 4, 0)
			local lift = math.sin(ghost.spin * math.pi) * 0.8 + 0.15 + math.sin(os.clock() * 4) * 0.08
			ghost.model:PivotTo(ghost.shown * CFrame.new(0, lift, 0))
			local _, size = Build.box(ghost.id)
			ghost.tipAnchor.Position = ghost.shown.Position + Vector3.new(0, size.Y + 2.2, 0)
		end
		hoverHL.Enabled = false
	else
		local m = not TOUCH and not overGui() and placedAt() or nil
		if m ~= hovered then
			hovered = m
			hoverHL.Adornee = m
			hoverHL.Enabled = m ~= nil and m ~= selected
		end
	end
	if selected then
		if not selected.Parent then closeCard() else cardScale() end
	end
end)

player.CharacterAdded:Connect(function()
	if building then leave() end
end)

layout()

-- RAH_Coop calls this before it restarts the script (you moved to another hotel): leave build mode cleanly
local leaveFn = Instance.new("BindableFunction")
leaveFn.Name = "RAH_Leave"
leaveFn.OnInvoke = function() if building then leave() end end
leaveFn.Parent = script
