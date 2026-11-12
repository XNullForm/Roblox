-- StarterPlayerScripts.RAH_Minigames: client-side cleaning minigames.
-- The server opens one with Notify "minigame" when a clean prompt is pressed;
-- this script plays it and reports the result through CleanDone.
-- The server validates timing itself, so finishing here is the only way to score.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))
local Remotes = RS.RAH:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local CleanDone = Remotes:WaitForChild("CleanDone")

local DARK = Color3.fromRGB(46, 34, 58)
local CREAM = Color3.fromRGB(250, 244, 234)
local YELLOW = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 210, 100)
local RED = Color3.fromRGB(240, 80, 80)

local TITLES = {
	Bed = "Make the Bed",
	Shower = "Rinse the Shower",
	Toilet = "Scrub the Toilet",
	Floor = "Tidy the Floor",
}

local gui -- the open minigame's ScreenGui
local conns = {} -- live connections, cut on close
local rng = Random.new()

local function cut()
	for _, c in ipairs(conns) do c:Disconnect() end
	table.clear(conns)
end

local function close(cancel)
	if not gui then return end
	cut()
	if cancel then CleanDone:FireServer(true) end
	gui:Destroy()
	gui = nil
end

local function round(parent, r)
	local u = Instance.new("UICorner")
	u.CornerRadius = UDim.new(0, r)
	u.Parent = parent
	return u
	end

local function label(parent, text, size)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = CREAM
	t.Text = text
	t.Parent = parent
	return t
end

-- builds the shared minigame shell; returns the play area + progress setter
local function shell(kind)
	local sg = Instance.new("ScreenGui")
	sg.Name = "RAH_Minigame"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 50
	sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.45
	dim.Parent = sg

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 380)
	panel.BackgroundColor3 = DARK
	panel.Parent = dim
	round(panel, 18)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, -70, 0, 40)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = CREAM
	title.Text = TITLES[kind] or "Clean"
	title.Parent = panel

	local x = Instance.new("ImageButton")
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -14, 0, 14)
	x.Size = UDim2.fromOffset(34, 34)
	x.BackgroundTransparency = 1
	x.Image = C.ICONS.close
	x.ImageColor3 = CREAM
	x.Parent = panel
	x.Activated:Connect(function() close(true) end)

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 30, 0, 58)
	track.Size = UDim2.new(1, -60, 0, 14)
	track.BackgroundColor3 = Color3.fromRGB(30, 22, 40)
	track.Parent = panel
	round(track, 7)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GREEN
	fill.Parent = track
	round(fill, 7)

	local area = Instance.new("Frame")
	area.Position = UDim2.new(0, 30, 0, 86)
	area.Size = UDim2.new(1, -60, 1, -116)
	area.BackgroundColor3 = Color3.fromRGB(58, 44, 74)
	area.ClipsDescendants = true
	area.Parent = panel
	round(area, 14)

	local function setProgress(k)
		fill:TweenSize(UDim2.fromScale(k, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.25, true)
	end
	return sg, area, setProgress
end

-- a touch / click that works on every device
local function pressable(item, fn)
	table.insert(conns, item.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			fn()
		end
	end))
end

-- drag an item around its area; calls dropped(item) on release
local function draggable(item, area, dropped)
	local dragging = false
	local grab = Vector2.zero
	table.insert(conns, item.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			grab = Vector2.new(item.AbsolutePosition.X, item.AbsolutePosition.Y) - io.Position
			item.ZIndex = 20
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			dropped(item)
		end
	end))
	table.insert(conns, UIS.InputChanged:Connect(function(io)
		if dragging and (io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch) then
			local p = io.Position + grab
			local ap = area.AbsolutePosition
			item.Position = UDim2.fromOffset(
				math.clamp(p.X - ap.X, 2, area.AbsoluteSize.X - item.AbsoluteSize.X - 2),
				math.clamp(p.Y - ap.Y, 2, area.AbsoluteSize.Y - item.AbsoluteSize.Y - 2))
		end
	end))
end

-- is an item's centre inside a target frame (with slack)?
local function over(item, target, slack)
	local ic = item.AbsolutePosition + item.AbsoluteSize / 2
	local tp, ts = target.AbsolutePosition, target.AbsoluteSize
	local s = slack or 14
	return ic.X > tp.X - s and ic.X < tp.X + ts.X + s
		and ic.Y > tp.Y - s and ic.Y < tp.Y + ts.Y + s
end

local function pop(item)
	item:TweenSize(UDim2.fromOffset(0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.18, true)
	task.delay(0.2, function() item:Destroy() end)
end

-- the "Sparkling!" flash, then report the win
local function finish(area)
	local flash = Instance.new("TextLabel")
	flash.AnchorPoint = Vector2.new(0.5, 0.5)
	flash.Position = UDim2.fromScale(0.5, 0.5)
	flash.Size = UDim2.fromScale(0.7, 0.3)
	flash.BackgroundTransparency = 1
	flash.Font = Enum.Font.FredokaOne
	flash.TextScaled = true
	flash.TextColor3 = YELLOW
	flash.Text = "Sparkling!"
	flash.ZIndex = 30
	flash.Parent = area
	task.delay(0.55, function()
		CleanDone:FireServer()
		close(false)
	end)
end

---------------------------------------------------------------- the minigames

-- Floor: drag every piece of trash into the bin
local function playFloor(sg, area, setProgress)
	local bin = Instance.new("Frame")
	bin.AnchorPoint = Vector2.new(1, 0.5)
	bin.Position = UDim2.new(1, -10, 0.5, 0)
	bin.Size = UDim2.fromOffset(84, 110)
	bin.BackgroundColor3 = Color3.fromRGB(96, 102, 118)
	bin.ZIndex = 5
	bin.Parent = area
	round(bin, 10)
	label(bin, "BIN")
	local lid = Instance.new("Frame")
	lid.AnchorPoint = Vector2.new(0.5, 0)
	lid.Position = UDim2.new(0.5, 0, 0, -8)
	lid.Size = UDim2.new(1, 10, 0, 14)
	lid.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
	lid.ZIndex = 5
	lid.Parent = bin
	round(lid, 6)

	local total, done = 6, 0
	for i = 1, total do
		local trash = Instance.new("Frame")
		trash.Size = UDim2.fromOffset(30, 30)
		trash.Position = UDim2.fromOffset(
			rng:NextInteger(10, math.max(11, area.AbsoluteSize.X - 160)),
			rng:NextInteger(10, math.max(11, area.AbsoluteSize.Y - 40)))
		trash.BackgroundColor3 = Color3.fromRGB(150, 120, 90)
		trash.ZIndex = 10
		trash.Parent = area
		round(trash, 12)
		draggable(trash, area, function(item)
			if over(item, bin) and item.Parent then
				pop(item)
			done += 1
				setProgress(done / total)
				if done == total then finish(area) end
		end
		end)
	end
end

-- Bed: drag the blanket up over the bed, then smooth it out
local function playBed(sg, area, setProgress)
	local bed = Instance.new("Frame")
	bed.AnchorPoint = Vector2.new(0, 0.5)
	bed.Position = UDim2.fromOffset(20, 0.5)
	bed.Size = UDim2.fromOffset(240, 190)
	bed.BackgroundColor3 = CREAM
	bed.ZIndex = 2
	bed.Parent = area
	round(bed, 12)
	local pillow = Instance.new("Frame")
	pillow.AnchorPoint = Vector2.new(0, 0)
	pillow.Position = UDim2.fromOffset(16, 12)
	pillow.Size = UDim2.new(1, -32, 0, 44)
	pillow.BackgroundColor3 = Color3.new(1, 1, 1)
	pillow.ZIndex = 3
	pillow.Parent = bed
	round(pillow, 14)
	-- where the blanket belongs
	local target = Instance.new("Frame")
	target.Position = UDim2.fromOffset(20, 12)
	target.Size = UDim2.fromOffset(240, 60)
	target.BackgroundTransparency = 1
	target.ZIndex = 1
	target.Parent = area

	local blanket = Instance.new("Frame")
	blanket.Size = UDim2.fromOffset(220, 120)
	blanket.Position = UDim2.fromOffset(30, area.AbsoluteSize.Y - 130)
	blanket.BackgroundColor3 = Color3.fromRGB(80, 130, 210)
	blanket.ZIndex = 10
	blanket.Parent = area
	round(blanket, 10)
	for i = 0, 2 do
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(1, 0, 0, 10)
		stripe.Position = UDim2.new(0, 0, 0.3 + i * 0.3, 0)
		stripe.BackgroundColor3 = Color3.fromRGB(60, 100, 170)
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 11
		stripe.Parent = blanket
	end

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 270, 0, 0)
	hint.Size = UDim2.new(1, -280, 1, 0)
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = CREAM
	hint.TextWrapped = true
	hint.Text = "Drag the blanket up over the bed!"
	hint.Parent = area

	draggable(blanket, area, function(item)
		if over(item, target) then
			setProgress(1)
			TweenService:Create(item, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(28, 52), Size = UDim2.fromOffset(224, 132) }):Play()
			task.delay(0.35, function() finish(area) end)
		end
	end)
end

-- Shower: tap each soap scum spot to rinse it away
local function playShower(sg, area, setProgress)
	local total, done = 8, 0
	for i = 1, total do
		local spot = Instance.new("Frame")
		local size = rng:NextInteger(34, 52)
		spot.Size = UDim2.fromOffset(size, size)
		spot.Position = UDim2.fromOffset(
			rng:NextInteger(10, math.max(11, area.AbsoluteSize.X - size - 10)),
			rng:NextInteger(10, math.max(11, area.AbsoluteSize.Y - size - 10)))
		spot.BackgroundColor3 = Color3.fromRGB(210, 226, 240)
		spot.BackgroundTransparency = 0.25
		spot.ZIndex = 10
		spot.Parent = area
		round(spot, 100)
		local shine = Instance.new("Frame")
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(0.3, 0.3)
		shine.Size = UDim2.fromOffset(8, 8)
		shine.BackgroundColor3 = Color3.new(1, 1, 1)
		shine.ZIndex = 11
		shine.Parent = spot
		round(shine, 100)
		pressable(spot, function()
			if not spot.Parent then return end
			pop(spot)
			done += 1
			setProgress(done / total)
			if done == total then finish(area) end
		end)
	end
end

-- Toilet: scrub off each grime patch
local function playToilet(sg, area, setProgress)
	local bowl = Instance.new("Frame")
	bowl.AnchorPoint = Vector2.new(0.5, 0.5)
	bowl.Position = UDim2.fromScale(0.5, 0.5)
	bowl.Size = UDim2.fromOffset(220, 170)
	bowl.BackgroundColor3 = CREAM
	bowl.ZIndex = 2
	bowl.Parent = area
	round(bowl, 40)
	local seat = Instance.new("Frame")
	seat.AnchorPoint = Vector2.new(0.5, 0)
	seat.Position = UDim2.new(0.5, 0, 0, -16)
	seat.Size = UDim2.fromOffset(150, 40)
	seat.BackgroundColor3 = Color3.new(1, 1, 1)
	seat.ZIndex = 3
	seat.Parent = bowl
	round(seat, 20)

	local total, done = 6, 0
	for i = 1, total do
		local grime = Instance.new("Frame")
		local size = rng:NextInteger(30, 46)
		grime.Size = UDim2.fromOffset(size, size)
		grime.Position = UDim2.fromOffset(
			rng:NextInteger(30, math.max(31, area.AbsoluteSize.X - size - 30)),
			rng:NextInteger(20, math.max(21, area.AbsoluteSize.Y - size - 20)))
		grime.BackgroundColor3 = Color3.fromRGB(139, 105, 74)
		grime.ZIndex = 10
		grime.Parent = area
		round(grime, 100)
		pressable(grime, function()
			if not grime.Parent then return end
			local wig = TweenService:Create(grime, TweenInfo.new(0.12, Enum.EasingStyle.Quad),
				{ Rotation = rng:NextInteger(-25, 25) })
			wig:Play()
			pop(grime)
			done += 1
			setProgress(done / total)
			if done == total then finish(area) end
		end)
	end
end

local GAMES = { Floor = playFloor, Bed = playBed, Shower = playShower, Toilet = playToilet }

local function open(kind)
	if gui or not GAMES[kind] then return end
	local sg, area, setProgress = shell(kind)
	gui = sg
	-- one frame later the area has its real size, so the layouts can use it
	task.defer(function()
		if gui == sg then GAMES[kind](sg, area, setProgress) end
	end)
end

Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "minigame" and data and data.task then
		open(data.task)
	elseif kind == "minigameEnd" then
		close(false)
	end
end)
