-- StarterPlayerScripts.RAH_Client: HUD, custom prompt buttons, money popups and toasts.
-- Draws only; every number comes from server attributes (player Cash, Hotel Rooms*/Waiting).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PPS = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))
local Notify = RS.RAH.Remotes:WaitForChild("Notify")
local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
-- the hotel you work in (player attribute RAH_Plot, set by RAH_Plots). RAH_Coop restarts this script when it changes.
local PLOTS = workspace:WaitForChild("Plots")
while not player:GetAttribute("RAH_Plot") do player:GetAttributeChangedSignal("RAH_Plot"):Wait() end
local HOTEL = PLOTS:WaitForChild(player:GetAttribute("RAH_Plot"))
local O = HOTEL:GetAttribute("Origin") or Vector3.zero
for _, g in ipairs(pgui:GetChildren()) do
	if g.Name == "RAH_HUD" or g.Name == "RAH_Prompt" then g:Destroy() end
end

local INK = Color3.fromRGB(46, 34, 58)
local FONT = Enum.Font.FredokaOne

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function stroke(o, th, col, tr)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 3
	s.Color = col or INK
	s.Transparency = tr or 0
	s.Parent = o
	return s
end

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = o
	return c
end

local function label(parent, text, size, pos, anchor)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Size = size
	t.Position = pos or UDim2.new()
	t.AnchorPoint = anchor or Vector2.zero
	t.Parent = parent
	stroke(t, 3)
	return t
end

local function image(parent, icon, size, pos, anchor)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Image = C.ICONS[icon] or icon
	i.ScaleType = Enum.ScaleType.Fit
	i.Size = size
	i.Position = pos or UDim2.new()
	i.AnchorPoint = anchor or Vector2.zero
	i.Parent = parent
	return i
end

local function pop(o, from)
	local s = o:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", o)
	s.Scale = from or 1.25
	tween(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end

---------------------------------------------------------------- HUD

local hud = Instance.new("ScreenGui")
hud.Name = "RAH_HUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
hud.Parent = pgui

-- bottom-left stack: room chips, then cash
local stack = Instance.new("Frame")
stack.Name = "Stack"
stack.BackgroundTransparency = 1
stack.AnchorPoint = Vector2.new(0, 1)
stack.Position = UDim2.new(0, 18, 1, -16)
stack.Size = UDim2.fromOffset(330, 150)
stack.Parent = hud
local uis = Instance.new("UIScale", stack)

local chips = {}
local function chip(key, icon, x, tip)
	local f = Instance.new("Frame")
	f.Name = key
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(100, 66)
	f.Position = UDim2.fromOffset(x, 0)
	f.Parent = stack
	local im = image(f, icon, UDim2.fromOffset(66, 66))
	local n = label(f, "0", UDim2.fromOffset(40, 46), UDim2.fromOffset(62, 12))
	n.TextXAlignment = Enum.TextXAlignment.Left
	f:SetAttribute("Tip", tip)
	chips[key] = { frame = f, num = n, icon = im }
	return f
end
chip("Ready", "roomReady", 0, "Clean rooms")
chip("Busy", "roomBusy", 106, "Rooms with guests")
chip("Dirty", "roomDirty", 212, "Rooms to clean")

local cashRow = Instance.new("Frame")
cashRow.Name = "Cash"
cashRow.BackgroundTransparency = 1
cashRow.Position = UDim2.fromOffset(0, 74)
cashRow.Size = UDim2.fromOffset(320, 66)
cashRow.Parent = stack
image(cashRow, "cash", UDim2.fromOffset(70, 70), UDim2.fromOffset(-4, -4))
local cashText = label(cashRow, "$0", UDim2.fromOffset(240, 54), UDim2.fromOffset(70, 6))
cashText.TextXAlignment = Enum.TextXAlignment.Left
cashText.TextColor3 = Color3.fromRGB(160, 255, 140)
local cg = Instance.new("UIGradient", cashText)
cg.Rotation = 90
cg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 230, 190))

-- top-centre: guests waiting pill (the hotel name and stars now live in the Menu's Manage tab)
local top = Instance.new("Frame")
top.Name = "Top"
top.BackgroundTransparency = 1
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 14)
top.Size = UDim2.fromOffset(420, 128)
top.Parent = hud
local topScale = Instance.new("UIScale", top)

local waitPill = Instance.new("Frame")
waitPill.Name = "Waiting"
waitPill.AnchorPoint = Vector2.new(0.5, 0)
waitPill.Position = UDim2.fromOffset(210, 0)
waitPill.Size = UDim2.fromOffset(250, 40)
waitPill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
waitPill.Visible = false
waitPill.Parent = top
corner(waitPill)
stroke(waitPill, 3)
local wg = Instance.new("UIGradient", waitPill)
wg.Rotation = 90
wg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 220, 234))
image(waitPill, "door", UDim2.fromOffset(46, 46), UDim2.fromOffset(-8, -4))
local waitText = Instance.new("TextLabel")
waitText.BackgroundTransparency = 1
waitText.Font = FONT
waitText.TextScaled = true
waitText.TextColor3 = Color3.fromRGB(70, 60, 84)
waitText.Position = UDim2.fromOffset(42, 6)
waitText.Size = UDim2.fromOffset(196, 28)
waitText.Parent = waitPill

local function layoutScale()
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.62, 1.15)
	uis.Scale = k
	topScale.Scale = k
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutScale)
layoutScale()

-- counting cash animation
local shownCash = player:GetAttribute("Cash") or 0
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
cashText.Text = "$" .. commas(shownCash)
-- counted per frame (a tween on a loose NumberValue could stall partway, e.g. after a save loaded)
local cashFrom, cashTo, cashT = shownCash, shownCash, 1
player:GetAttributeChangedSignal("Cash"):Connect(function()
	cashFrom, cashTo, cashT = shownCash, player:GetAttribute("Cash") or 0, 0
	pop(cashRow, 1.18)
end)
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if cashT >= 1 then return end
	cashT = math.min(1, cashT + dt / 0.9)
	local e = 1 - (1 - cashT) ^ 3
	shownCash = cashFrom + (cashTo - cashFrom) * e
	cashText.Text = "$" .. commas(shownCash)
end)

local function refreshRooms()
	for key, ch in pairs(chips) do
		local n = HOTEL:GetAttribute("Rooms" .. key) or 0
		if ch.num.Text ~= tostring(n) then
			ch.num.Text = tostring(n)
			pop(ch.frame, 1.2)
		end
		ch.frame.Visible = key == "Ready" or n > 0 or key == "Busy"
	end
	local w = HOTEL:GetAttribute("Waiting") or 0
	if w > 0 then
		waitText.Text = w .. (w == 1 and " guest waiting" or " guests waiting")
		if not waitPill.Visible then
			waitPill.Visible = true
			pop(waitPill, 0.6)
		end
	else
		waitPill.Visible = false
	end
end
for _, k in ipairs({ "RoomsReady", "RoomsBusy", "RoomsDirty", "Waiting" }) do
	HOTEL:GetAttributeChangedSignal(k):Connect(refreshRooms)
end
refreshRooms()

---------------------------------------------------------------- sprint (hold Shift; replaces shift lock)

local StarterPlayer = game:GetService("StarterPlayer")
local BASE_SPEED = StarterPlayer.CharacterWalkSpeed
local SPRINT_SPEED = BASE_SPEED * 1.65
local sprinting = false
local function applySprint()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.WalkSpeed == 0 then return end -- never fight build mode's freeze
	hum.WalkSpeed = sprinting and player:GetAttribute("RAH_Sprint") ~= false and SPRINT_SPEED or BASE_SPEED
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

---------------------------------------------------------------- toasts

local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.AnchorPoint = Vector2.new(0.5, 0)
toastHolder.Position = UDim2.new(0.5, 0, 0, 118)
toastHolder.Size = UDim2.fromOffset(460, 240)
toastHolder.Parent = hud
Instance.new("UIScale", toastHolder)
local tl = Instance.new("UIListLayout", toastHolder)
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
tl.Padding = UDim.new(0, 8)
tl.SortOrder = Enum.SortOrder.LayoutOrder
local toastN = 0

local function toast(text, icon, bad)
	toastN += 1
	local f = Instance.new("Frame")
	f.LayoutOrder = toastN
	f.Size = UDim2.fromOffset(0, 46)
	f.AutomaticSize = Enum.AutomaticSize.X
	f.BackgroundColor3 = bad and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 255, 255)
	f.Parent = toastHolder
	corner(f)
	local st = stroke(f, 3)
	local g = Instance.new("UIGradient", f)
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 216, 232))
	local pad = Instance.new("UIPadding", f)
	pad.PaddingLeft = UDim.new(0, 52); pad.PaddingRight = UDim.new(0, 18)
	local im = image(f, icon or "star", UDim2.fromOffset(50, 50), UDim2.new(0, -54, 0.5, 0), Vector2.new(0, 0.5))
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextSize = 26
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, 46)
	t.TextColor3 = bad and Color3.new(1, 1, 1) or Color3.fromRGB(70, 60, 84)
	t.Text = text
	t.Parent = f
	if bad then stroke(t, 2) end
	pop(f, 0.5)
	task.delay(3.2, function()
		local s = f:FindFirstChildOfClass("UIScale")
		tween(s, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.32)
		f:Destroy()
	end)
	while #toastHolder:GetChildren() > 6 do
		for _, c in ipairs(toastHolder:GetChildren()) do
			if c:IsA("Frame") then c:Destroy(); break end
		end
	end
end

---------------------------------------------------------------- world popups (+$45)

local function worldPop(pos, text, color, icon)
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.CanQuery = false; part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = pos
	part.Parent = workspace.CurrentCamera
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 70)
	bb.AlwaysOnTop = true
	bb.Adornee = part
	bb.LightInfluence = 0
	bb.Parent = pgui
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = bb
	local t = label(row, text, UDim2.fromScale(0.72, 0.8), UDim2.fromScale(0.28, 0.1))
	t.TextColor3 = color or Color3.fromRGB(150, 255, 130)
	t.TextXAlignment = Enum.TextXAlignment.Left
	if icon then image(row, icon, UDim2.fromScale(0.3, 1), UDim2.fromScale(0, 0)) end
	pop(row, 0.3)
	tween(bb, 1.4, { StudsOffset = Vector3.new(0, 4, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.9, function()
		tween(t, 0.5, { TextTransparency = 1 })
		for _, d in ipairs(row:GetDescendants()) do
			if d:IsA("ImageLabel") then tween(d, 0.5, { ImageTransparency = 1 }) end
			if d:IsA("UIStroke") then tween(d, 0.5, { Transparency = 1 }) end
		end
	end)
	task.delay(1.5, function()
		bb:Destroy()
		part:Destroy()
	end)
end

---------------------------------------------------------------- day summary

local summaryOpen = false
local function daySummary(d)
	if summaryOpen then return end
	summaryOpen = true

	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = hud
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(470, 320)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.Parent = dim
	corner(card, UDim.new(0, 26))
	stroke(card, 4)
	local g = Instance.new("UIGradient", card)
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(225, 222, 240))

	local title = label(card, "Day " .. d.day .. " complete!", UDim2.fromScale(0.9, 0.17), UDim2.fromScale(0.05, 0.05))
	title.TextColor3 = INK
	title:FindFirstChildOfClass("UIStroke").Transparency = 1

	local rows = {
		{ icon = "guest", text = d.guests .. (d.guests == 1 and " guest served" or " guests served") },
		{ icon = "sparkle", text = d.cleans .. (d.cleans == 1 and " room cleaned" or " rooms cleaned") },
		{ icon = "cash", text = "$" .. d.earned .. " earned", green = true },
	}
	for i, r in ipairs(rows) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0.05, 0, 0.28, (i - 1) * 62)
		row.Size = UDim2.fromScale(0.9, 54)
		row.Parent = card
		image(row, r.icon, UDim2.fromOffset(52, 52), UDim2.fromOffset(0, 0))
		local t = label(row, r.text, UDim2.fromScale(0.72, 0.7), UDim2.fromScale(0.14, 0.15))
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = r.green and Color3.fromRGB(90, 170, 80) or INK
		t:FindFirstChildOfClass("UIStroke").Transparency = 1
	end

	if d.uncollected and d.uncollected > 0 then
		local tip = label(card, "The dropbox still holds $" .. d.uncollected .. "!", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.85))
		tip.TextColor3 = Color3.fromRGB(200, 120, 60)
		tip:FindFirstChildOfClass("UIStroke").Transparency = 1
	end

	local close = function()
		if not dim.Parent then return end
		local s = card:FindFirstChildOfClass("UIScale")
		if s then tween(s, 0.28, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In) end
		tween(dim, 0.28, { BackgroundTransparency = 1 })
		task.delay(0.32, function()
			dim:Destroy()
			summaryOpen = false
		end)
	end
	dim.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then close() end
	end)
	pop(card, 0.6)
	task.delay(6, close)
end

---------------------------------------------------------------- tutorial card

local TutSkip = RS.RAH.Remotes:WaitForChild("TutSkip")
local tutCard

local function showTut(d)
	if tutCard then tutCard:Destroy() tutCard = nil end
	if d.done then
		if not d.skipped then
			toast("You're all set! Your hotel is open for business", "star")
		end
		return
	end
	tutCard = Instance.new("Frame")
	tutCard.AnchorPoint = Vector2.new(0.5, 0)
	tutCard.Position = UDim2.new(0.5, 0, 0, 64)
	tutCard.Size = UDim2.fromOffset(460, 88)
	tutCard.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tutCard.Parent = hud
	corner(tutCard, UDim.new(0, 22))
	stroke(tutCard, 4)
	local grad = Instance.new("UIGradient", tutCard)
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(228, 225, 242))

	image(tutCard, d.icon, UDim2.fromOffset(62, 62), UDim2.fromOffset(12, 13))

	local step = label(tutCard, "Tutorial  " .. d.step .. "/" .. d.total, UDim2.fromOffset(340, 22), UDim2.fromOffset(88, 12))
	step.TextXAlignment = Enum.TextXAlignment.Left
	step.TextColor3 = Color3.fromRGB(150, 120, 60)
	step.TextSize = 18
	step:FindFirstChildOfClass("UIStroke").Transparency = 1

	local text = label(tutCard, d.text, UDim2.fromOffset(340, 40), UDim2.fromOffset(88, 38))
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = INK
	text:FindFirstChildOfClass("UIStroke").Transparency = 1

	local close = Instance.new("TextButton")
	close.BackgroundTransparency = 1
	close.Size = UDim2.fromOffset(36, 36)
	close.Position = UDim2.new(1, -42, 0, 8)
	close.Text = ""
	close.Parent = tutCard
	image(close, "close", UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.15, 0.15))
	close.MouseButton1Click:Connect(function()
		TutSkip:FireServer()
		if tutCard then tutCard:Destroy() tutCard = nil end
	end)

	pop(tutCard, 0.7)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "toast" then
		toast(d.text, d.icon, d.bad)
	elseif kind == "tut" then
		showTut(d)
	elseif kind == "day" then
		daySummary(d)
	elseif kind == "paid" then
		worldPop(d.pos, "+$" .. d.amount, nil, "cash")
	elseif kind == "collect" then
		worldPop(d.pos, "+$" .. d.amount, nil, "cash")
	elseif kind == "cleaned" then
		worldPop(d.pos + Vector3.new(0, 1.5, 0), "Clean!", Color3.fromRGB(150, 230, 255), "sparkle")
	elseif kind == "built" then
		if d.kind == "place" then
			worldPop(d.pos + Vector3.new(0, 4, 0), "-$" .. d.amount, Color3.fromRGB(255, 150, 130), "cash")
		elseif d.kind == "sell" then
			worldPop(d.pos + Vector3.new(0, 4, 0), "+$" .. d.amount, nil, "cash")
		end
	end
end)

-- build mode (RAH_BuildClient) borrows the toasts
local localToast = Instance.new("BindableEvent")
localToast.Name = "RAH_Toast"
localToast.Event:Connect(toast)
localToast.Parent = script

---------------------------------------------------------------- custom prompts: round icon buttons

local COLORS = {
	yellow = { Color3.fromRGB(255, 232, 80), Color3.fromRGB(250, 180, 30) },
	green = { Color3.fromRGB(140, 240, 110), Color3.fromRGB(50, 180, 70) },
	blue = { Color3.fromRGB(120, 210, 255), Color3.fromRGB(40, 130, 230) },
}

local shown = {}

local function keyText(prompt)
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return nil end
	if UIS.GamepadEnabled and not UIS.KeyboardEnabled then return "X" end
	return prompt.KeyboardKeyCode.Name
end

local function buildPrompt(prompt)
	local cols = COLORS[prompt:GetAttribute("Color") or "yellow"] or COLORS.yellow
	local bb = Instance.new("BillboardGui")
	bb.Name = "RAH_Prompt"
	bb.Size = UDim2.fromOffset(170, 190)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Active = true
	bb.Adornee = prompt.Parent
	bb.Parent = pgui
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = bb
	local sc = Instance.new("UIScale", root)
	sc.Scale = 0

	local title = label(root, prompt.ActionText, UDim2.fromOffset(170, 40), UDim2.fromOffset(0, 0))
	title.TextColor3 = Color3.fromRGB(255, 240, 160)
	local sub = label(root, prompt.ObjectText, UDim2.fromOffset(170, 22), UDim2.fromOffset(0, 38))
	sub.TextColor3 = Color3.new(1, 1, 1)
	stroke(sub, 2).Thickness = 2

	-- the round button (a CanvasGroup so the hold fill is clipped to the circle)
	local btn = Instance.new("CanvasGroup")
	btn.Name = "Button"
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.Position = UDim2.fromOffset(85, 64)
	btn.Size = UDim2.fromOffset(112, 112)
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.Parent = root
	corner(btn)
	local grad = Instance.new("UIGradient", btn)
	grad.Rotation = 90
	grad.Color = ColorSequence.new(cols[1], cols[2])
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BackgroundTransparency = 0.55
	fill.BorderSizePixel = 0
	fill.Parent = btn
	local gloss = Instance.new("Frame")
	gloss.AnchorPoint = Vector2.new(0.5, 0)
	gloss.Position = UDim2.fromScale(0.5, 0.07)
	gloss.Size = UDim2.fromScale(0.7, 0.28)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.7
	gloss.Parent = btn
	corner(gloss)
	image(btn, prompt:GetAttribute("Icon") or "star", UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
	-- ring drawn outside the canvas so it isn't clipped
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.fromOffset(85, 64)
	ring.Size = UDim2.fromOffset(112, 112)
	ring.BackgroundTransparency = 1
	ring.Parent = root
	corner(ring)
	stroke(ring, 5)

	local key = keyText(prompt)
	if key then
		local k = Instance.new("TextLabel")
		k.AnchorPoint = Vector2.new(0.5, 0.5)
		k.Position = UDim2.fromOffset(134, 160)
		k.Size = UDim2.fromOffset(40, 40)
		k.BackgroundColor3 = Color3.fromRGB(236, 242, 255)
		k.Font = FONT
		k.TextSize = 26
		k.Text = key
		k.TextColor3 = INK
		k.Parent = root
		corner(k, UDim.new(0.25, 0))
		stroke(k, 3)
	end

	-- click / tap = press the prompt
	local hit = Instance.new("TextButton")
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Position = UDim2.fromOffset(29, 64)
	hit.Size = UDim2.fromOffset(112, 112)
	hit.Parent = root
	hit.MouseButton1Down:Connect(function() prompt:InputHoldBegin() end)
	hit.MouseButton1Up:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseLeave:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseEnter:Connect(function() tween(sc, 0.2, { Scale = 1.08 }) end)
	hit.MouseLeave:Connect(function() tween(sc, 0.2, { Scale = 1 }) end)

	tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	-- idle bob
	local bob = 0
	local conn = RunService.RenderStepped:Connect(function(dt)
		bob += dt
		btn.Position = UDim2.fromOffset(85, 64 + math.sin(bob * 3) * 3)
		ring.Position = btn.Position
	end)

	local s = { bb = bb, scale = sc, fill = fill, title = title, sub = sub, conn = conn, holding = false }
	local c1 = prompt:GetPropertyChangedSignal("ActionText"):Connect(function() title.Text = prompt.ActionText end)
	local c2 = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function() sub.Text = prompt.ObjectText end)
	s.extra = { c1, c2 }
	return s
end

PPS.PromptShown:Connect(function(prompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	-- other people's hotels: no buttons (the server turns their prompts down too)
	if prompt:IsDescendantOf(PLOTS) and not prompt:IsDescendantOf(HOTEL) then return end
	if shown[prompt] then return end
	shown[prompt] = buildPrompt(prompt)
end)

PPS.PromptHidden:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	shown[prompt] = nil
	s.conn:Disconnect()
	for _, c in ipairs(s.extra) do c:Disconnect() end
	local tw = tween(s.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw.Completed:Wait()
	s.bb:Destroy()
end)

PPS.PromptButtonHoldBegan:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.fill.Size = UDim2.fromScale(1, 0)
	s.holdTween = tween(s.fill, prompt.HoldDuration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	tween(s.scale, 0.15, { Scale = 0.92 })
end)

PPS.PromptButtonHoldEnded:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	if s.holdTween then s.holdTween:Cancel() end
	tween(s.fill, 0.2, { Size = UDim2.fromScale(1, 0) })
	tween(s.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end)

PPS.PromptTriggered:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.scale.Scale = 1.25
	tween(s.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end)
