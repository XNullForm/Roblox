-- StarterPlayerScripts.RAH_MainMenu: the title screen. Home has Play / Tips / Settings;
-- Play leads to the save-file cards. The server (RAH_Plots / RAH_Save) claims your plot
-- and loads that save. Remotes.Menu: client fires ("slots") to ask for save summaries,
-- ("play", slot) to start; server fires ("slots", { [slot] = { name, cash, rooms } or nil }) back.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local Menu = RAH.Remotes:WaitForChild("Menu")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(46, 34, 58)
local FONT = Enum.Font.FredokaOne
local PURPLE = { Color3.fromRGB(196, 160, 255), Color3.fromRGB(120, 80, 220) }
local GREEN = { Color3.fromRGB(140, 240, 110), Color3.fromRGB(50, 180, 70) }
local GREY = { Color3.fromRGB(214, 208, 226), Color3.fromRGB(160, 150, 180) }
local GOLD = { Color3.fromRGB(255, 224, 130), Color3.fromRGB(255, 160, 60) }
local BLUE = { Color3.fromRGB(130, 200, 255), Color3.fromRGB(70, 130, 230) }

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = o
end
local function stroke(o, th, col)
	local s = Instance.new("UIStroke")
	s.Thickness = th or 3
	s.Color = col or INK
	s.Parent = o
	return s
end
local function grad(o, cols)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(cols[1], cols[2])
	g.Parent = o
	return g
end
local function label(parent, text, size, pos, txtColor, textSize, anchor)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.Text = text
	t.TextColor3 = txtColor or Color3.new(1, 1, 1)
	t.TextSize = textSize or 22
	t.Size = size
	t.Position = pos
	if anchor then t.AnchorPoint = anchor end
	t.Parent = parent
	return t
end
local function uiK()
	local vp = workspace.CurrentCamera.ViewportSize
	return math.clamp(math.min(vp.X / 1500, vp.Y / 850), 0.5, 1.15)
end
local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = o
	end
	return s
end

---------------------------------------------------------------- the screen

local old = pgui:FindFirstChild("RAH_MainMenu")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "RAH_MainMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- cover the whole screen, insets and all
gui.DisplayOrder = 50 -- on top of everything
gui.Parent = pgui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(34, 22, 52)
root.BorderSizePixel = 0
root.Parent = gui
grad(root, { Color3.fromRGB(46, 30, 70), Color3.fromRGB(24, 14, 38) })

-- decorative floating dots (a little life behind the cards)
for i = 1, 14 do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(math.random(6, 14), math.random(6, 14))
	dot.Position = UDim2.fromScale(math.random(), math.random())
	dot.BackgroundColor3 = (i % 3 == 0) and PURPLE[1] or GREY[1]
	dot.BackgroundTransparency = 0.75
	dot.BorderSizePixel = 0
	dot.Parent = root
	corner(dot)
	task.spawn(function()
		while dot.Parent do
			local x, y = math.random(), math.random() * 0.9
			tween(dot, 6 + math.random() * 6, { Position = UDim2.fromScale(x, y) }, Enum.EasingStyle.Sine)
			task.wait(6 + math.random() * 6)
		end
	end)
end

-- scale with the viewport, like the rest of the game's UI
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local function layout() rootScale.Scale = uiK() end
layout()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)

---------------------------------------------------------------- screens (home / play / tips / settings)

local screens = {}
local function screen(id)
	local f = Instance.new("Frame")
	f.Name = id
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.Parent = root
	screens[id] = f
	scaleOf(f).Scale = 1
	return f
end

local current = nil
local function show(id)
	if current == id then return end
	current = id
	for k, f in pairs(screens) do f.Visible = (k == id) end
	local sc = scaleOf(screens[id])
	sc.Scale = 0.92
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function bigButton(parent, text, cols, w, h)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w or 360, h or 88)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, UDim.new(0, 24))
	stroke(b, 4)
	grad(b, cols)
	label(b, text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), INK, 32)
	local s = scaleOf(b)
	b.MouseEnter:Connect(function() tween(s, 0.15, { Scale = 1.04 }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(s, 0.15, { Scale = 1 }, Enum.EasingStyle.Back) end)
	return b
end

local function backBtn(parent)
	local b = bigButton(parent, "<  BACK", GREY, 150, 58)
	b:FindFirstChildOfClass("TextLabel").TextSize = 24
	return b
end

---------------------------------------------------------------- home screen

local home = screen("home")
home.Visible = true
current = "home"

local title = label(home, "MY HOTEL", UDim2.fromOffset(900, 110), UDim2.new(0.5, 0, 0, 60), nil, 76, Vector2.new(0.5, 0))
stroke(title, 5)
grad(title, GOLD)
local sub = label(home, "Build  \u{2022}  Run  \u{2022}  Grow", UDim2.fromOffset(600, 40), UDim2.new(0.5, 0, 0, 172), GREY[1], 26, Vector2.new(0.5, 0))

local menu = Instance.new("Frame")
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.58)
menu.Size = UDim2.fromOffset(400, 340)
menu.BackgroundTransparency = 1
menu.Parent = home
local ml = Instance.new("UIListLayout")
ml.HorizontalAlignment = Enum.HorizontalAlignment.Center
ml.Padding = UDim.new(0, 22)
ml.SortOrder = Enum.SortOrder.LayoutOrder
ml.Parent = menu

local playBtn = bigButton(menu, "PLAY", GREEN)
playBtn.LayoutOrder = 1
local tipsBtn = bigButton(menu, "TIPS", BLUE)
tipsBtn.LayoutOrder = 2
local setBtn = bigButton(menu, "SETTINGS", PURPLE)
setBtn.LayoutOrder = 3

label(home, "Press  M  in game to open the menu", UDim2.fromOffset(700, 34), UDim2.new(0.5, 0, 1, -46), GREY[2], 20, Vector2.new(0.5, 1))

---------------------------------------------------------------- play screen (the save file cards)

local playScr = screen("play")
backBtn(playScr).Activated:Connect(function() show("home") end)
local head = label(playScr, "Choose a save file", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0, 30), nil, 40, Vector2.new(0.5, 0))
stroke(head, 4)

local cards = Instance.new("Frame")
cards.AnchorPoint = Vector2.new(0.5, 0.5)
cards.Position = UDim2.fromScale(0.5, 0.6)
cards.Size = UDim2.fromScale(0.92, 420)
cards.BackgroundTransparency = 1
cards.Parent = playScr
local cl = Instance.new("UIListLayout")
cl.FillDirection = Enum.FillDirection.Horizontal
cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cl.VerticalAlignment = Enum.VerticalAlignment.Center
cl.Padding = UDim.new(0, 26)
cl.Parent = cards

local pick = Instance.new("BindableEvent")

local function makeCard(slot)
	local card = Instance.new("TextButton")
	card.Name = "Slot" .. slot
	card.Text = ""
	card.AutoButtonColor = false
	card.Size = UDim2.fromOffset(300, 400)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.Parent = cards
	corner(card, UDim.new(0, 26))
	stroke(card, 4)
	local g = grad(card, GREY)

	local head2 = label(card, "SAVE " .. slot, UDim2.fromOffset(240, 44), UDim2.new(0.5, -120, 0, 22), nil, 30)
	stroke(head2, 3)
	local headBar = Instance.new("Frame")
	headBar.Size = UDim2.fromOffset(240, 6)
	headBar.Position = UDim2.new(0.5, -120, 0, 70)
	headBar.BackgroundColor3 = INK
	headBar.BorderSizePixel = 0
	headBar.Parent = card
	corner(headBar, UDim.new(1, 0))

	-- filled in when the save summaries arrive
	local info = label(card, "...", UDim2.fromOffset(260, 150), UDim2.new(0.5, -130, 0, 110), nil, 24)
	info.TextWrapped = true
	local action = label(card, "", UDim2.fromOffset(240, 54), UDim2.new(0.5, -120, 0, 300), nil, 32)
	stroke(action, 3)

	local function fill(d)
		if d then
			g.Color = ColorSequence.new(GREEN[1], GREEN[2])
			info.Text = d.name .. "\n$" .. string.format("%d", d.cash) .. "\n" .. d.rooms .. " rooms"
			action.Text = "PLAY"
			action.TextColor3 = INK
		else
			g.Color = ColorSequence.new(PURPLE[1], PURPLE[2])
			info.Text = "A fresh start\non an empty street"
			action.Text = "NEW GAME"
			action.TextColor3 = Color3.new(1, 1, 1)
		end
		info.TextColor3 = INK
	end

	card.Activated:Connect(function()
		if not card.Active then return end
		card.Active = false
		-- a little bounce, then pick this save
		local s = scaleOf(card)
		s.Scale = 1
		tween(s, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
		tween(s, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
		pick:Fire(slot)
	end)

	return { card = card, fill = fill }
end

local made = {}
for s = 1, C.SAVE_SLOTS do made[s] = makeCard(s) end

-- the cards pop in the first time the play screen opens
local cardsPopped = false
playBtn.Activated:Connect(function()
	show("play")
	if not cardsPopped then
		cardsPopped = true
		for s = 1, #made do
			local sc = scaleOf(made[s].card)
			sc.Scale = 0
			task.delay(0.08 * s, function() tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
		end
	end
end)

---------------------------------------------------------------- tips screen

local tipsScr = screen("tips")
backBtn(tipsScr).Activated:Connect(function() show("home") end)
local tipsHead = label(tipsScr, "Tips", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0, 30), nil, 40, Vector2.new(0.5, 0))
stroke(tipsHead, 4)

local scroll = Instance.new("ScrollingFrame")
scroll.AnchorPoint = Vector2.new(0.5, 0)
scroll.Position = UDim2.fromScale(0.5, 0.2)
scroll.Size = UDim2.fromScale(0.9, 0.66)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 10
scroll.ScrollBarImageColor3 = GREY[1]
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = tipsScr
local tl = Instance.new("UIListLayout")
tl.Padding = UDim.new(0, 12)
tl.SortOrder = Enum.SortOrder.LayoutOrder
tl.Parent = scroll

local TIPS = {
	{ icon = "bell", text = "Guests arrive at your hotel's door. Walk to the desk to check them in before they lose patience." },
	{ icon = "clean", text = "After a guest checks out, their room needs cleaning. Tap the task to grab your broom." },
	{ icon = "hammer", text = "Build mode adds rooms, furniture and decor. More rooms means more guests \u{2014} and more cash." },
	{ icon = "staff", text = "Hire a Janitor to clean for you, a Doorman to let guests in, and a Receptionist to greet them at the desk." },
	{ icon = "upgrade", text = "Upgrade rooms to Deluxe or Suite for richer guests, bigger payouts and fatter tips." },
	{ icon = "star", text = "Happy guests and lovely decor raise your hotel's appeal. Every star brings guests in faster." },
	{ icon = "coop", text = "Invite friends to co-op \u{2014} they can help you run your hotel." },
	{ icon = "walk", text = "Hold Shift to sprint around your hotel." },
	{ icon = "sleep", text = "Your hotel keeps earning while you're away. Come back and collect the cash!" },
}
for i, tip in ipairs(TIPS) do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -16, 0, 84)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.15
	f.LayoutOrder = i
	f.Parent = scroll
	corner(f, UDim.new(0, 18))
	stroke(f, 3)
	grad(f, GREY)
	local ic = Instance.new("ImageLabel")
	ic.BackgroundTransparency = 1
	ic.Position = UDim2.fromOffset(18, 18)
	ic.Size = UDim2.fromOffset(48, 48)
	ic.Image = C.ICONS[tip.icon] or C.ICONS.star
	ic.Parent = f
	local t = label(f, tip.text, UDim2.new(1, -110, 1, -20), UDim2.fromOffset(88, 10), INK, 20)
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
end

---------------------------------------------------------------- settings screen

local setScr = screen("settings")
backBtn(setScr).Activated:Connect(function() show("home") end)
local setHead = label(setScr, "Settings", UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0, 30), nil, 40, Vector2.new(0.5, 0))
stroke(setHead, 4)

local rows = Instance.new("Frame")
rows.AnchorPoint = Vector2.new(0.5, 0)
rows.Position = UDim2.fromScale(0.5, 0.26)
rows.Size = UDim2.fromOffset(460, 260)
rows.BackgroundTransparency = 1
rows.Parent = setScr
local rl = Instance.new("UIListLayout")
rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
rl.Padding = UDim.new(0, 18)
rl.SortOrder = Enum.SortOrder.LayoutOrder
rl.Parent = rows

-- a toggle that mutes one of the sound groups RAH_Audio sets up
local function toggleRow(text, attr, groupName, baseVol)
	local b = bigButton(rows, text, GREY, 440, 84)
	b.LayoutOrder = 1
	local txt = b:FindFirstChildOfClass("TextLabel")
	local function refresh()
		local off = player:GetAttribute(attr) == true
		local g = SoundService:FindFirstChild(groupName)
		if g then g.Volume = off and 0 or baseVol end
		txt.Text = text .. (off and ":  OFF" or ":  ON")
	end
	b.Activated:Connect(function()
		player:SetAttribute(attr, not (player:GetAttribute(attr) == true))
		refresh()
	end)
	refresh()
	return b
end
toggleRow("MUSIC", "RAH_MusicOff", "RAH_Music", 0.32)
toggleRow("SOUND EFFECTS", "RAH_SfxOff", "RAH_SFX", 0.9)

label(setScr, "Settings apply to this session", UDim2.fromOffset(700, 34), UDim2.new(0.5, 0, 1, -46), GREY[2], 20, Vector2.new(0.5, 1))

---------------------------------------------------------------- start playing

local function close(slot)
	Menu:FireServer("play", slot)
	-- fade the whole screen away
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			tween(d, 0.3, { TextTransparency = 1 })
			if d:IsA("TextButton") then tween(d, 0.3, { BackgroundTransparency = 1 }) end
		elseif d:IsA("Frame") then
			tween(d, 0.3, { BackgroundTransparency = 1 })
		end
	end
	local tw = tween(root, 0.45, { BackgroundTransparency = 1 })
	tw.Completed:Connect(function() gui:Destroy() end)
end

pick.Event:Connect(close)

-- already playing (the script restarted mid-session)? don't show the menu
if player:GetAttribute("RAH_Slot") then
	gui:Destroy()
	return
end

-- ask the server for this player's save summaries
Menu.OnClientEvent:Connect(function(action, data)
	if action ~= "slots" or player:GetAttribute("RAH_Slot") then return end
	for s = 1, C.SAVE_SLOTS do
		if made[s] then made[s].fill(type(data) == "table" and data[s] or nil) end
	end
end)
Menu:FireServer("slots")

-- home buttons pop in one after another
for i, b in ipairs({ playBtn, tipsBtn, setBtn }) do
	local s = scaleOf(b)
	s.Scale = 0
	task.delay(0.09 * i, function() tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
end