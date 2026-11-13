-- StarterPlayerScripts.Coop: the Menu (round 10c remake) and the left dock.
-- One window (fitted between the dock and the HUD's top bar) with a tab per page: Hotel (name, rating, lifetime
-- numbers, level road, right-now tiles, play together with people in the server, guest reviews), Staff (hire
-- cards and your team), Research (ResearchUI builds the lab into Page_research), Achievements (Shared.Quests
-- ACHIEVEMENTS, claimed through Remotes.Achieve) and Settings (sound, gameplay, display, controls, save).
-- It closes only on its X or M. Other scripts open a page with the player attribute MenuWant (a tab id, or
-- "close"); ResearchOpen is set while the Research tab shows. Invites pop up as cards under the top bar.
-- When you move to another hotel (player attribute Plot changes) it restarts Client and BuildClient
-- so the HUD and build mode follow you there. Server side: Plots (Remotes.Coop), hiring via Remotes.Build.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local StarterPlayer = game:GetService("StarterPlayer")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Research = require(Shared:WaitForChild("Research"))
local Levels = require(Shared:WaitForChild("Levels"))
local Q = require(Shared:WaitForChild("Quests"))
local Notify = Shared.Remotes:WaitForChild("Notify")
local Coop = Shared.Remotes:WaitForChild("Coop")
local Build = Shared.Remotes:WaitForChild("Build")
local PLOTS = workspace:WaitForChild("Plots")
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local ps = player:WaitForChild("PlayerScripts")

---------------------------------------------------------------- follow the hotel you work in

local current = player:GetAttribute("Plot")

local function reboot()
	local b = ps:FindFirstChild("BuildClient")
	local leave = b and b:FindFirstChild("Leave")
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
	for _, n in ipairs({ "Client", "BuildClient" }) do
		local s = ps:FindFirstChild(n)
		if s then
			local copy = s:Clone()
			copy:ClearAllChildren() -- drop the old copy's runtime bits (toast / leave hooks)
			s:Destroy()
			copy.Parent = ps
		end
	end
end

player:GetAttributeChangedSignal("Plot"):Connect(function()
	local now = player:GetAttribute("Plot")
	if current and now and now ~= current then reboot() end
	current = now
end)

---------------------------------------------------------------- helpers

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

local function workHotel()
	local k = player:GetAttribute("Plot")
	return k and PLOTS:FindFirstChild(k)
end

local function mtoast(text, icon, bad)
	UI.toast(text, icon and ICON[icon], bad and "bad" or nil)
end

-- a raised row inside a page
local function row(parent, h, order)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = T.ink2, LayoutOrder = order or 0, Parent = parent })
	UI.corner(f, 14)
	UI.stroke(f, 1.5, T.line, 0.45)
	return f
end

local function rowIcon(f, icon, size)
	local bg = UI.new("Frame", { Size = UDim2.fromOffset(size + 12, size + 12), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink, Parent = f })
	UI.corner(bg, 12)
	UI.icon(bg, ICON[icon] or icon, size, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	return bg
end

local function sectionTitle(parent, text, order)
	return UI.label(parent, string.upper(text), 13, { FontFace = UI.F.black, TextColor3 = T.gold, LayoutOrder = order or 0, Size = UDim2.new(1, 0, 0, 20) })
end

---------------------------------------------------------------- the screen (round 10c: one window, Research is a tab)

local gui = pgui:FindFirstChild("Coop")
if gui then gui:Destroy() end
gui = UI.new("ScreenGui", {
	Name = "Coop", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 20, Parent = pgui,
})

-- the left dock is built further down (after the panel); its buttons and badges live here
local dock = { badges = {}, buttons = {} }

-- the dim only darkens the world and swallows clicks: the menu closes on its X (or M), nothing else
local dim = UI.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 1, Visible = false, Parent = gui })
local W, H = 1240, 838
local wrap = UI.new("Frame", { Name = "Screen", Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = gui })
local fitScale = Instance.new("UIScale")
fitScale.Name = "AutoScale"
fitScale.Parent = wrap
-- the window fits between the dock (left), the HUD's top bar and the screen edges
local function fit()
	local size = gui.AbsoluteSize
	if size.X < 10 then return end
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(vp.X / 1600, vp.Y / 900), UIS.TouchEnabled and 0.55 or 0.7, 1.25)
	local left = 12
	local dg = pgui:FindFirstChild("Dock")
	local dk = dg and dg:FindFirstChild("Dock")
	if dk and dk.Visible then left = 16 + dk.AbsoluteSize.X + 12 end
	local top = 8 + 70 * k + 8
	local availW, availH = size.X - left - 14, size.Y - top - 12
	fitScale.Scale = math.clamp(math.min(availW / W, availH / H, k * 0.82), 0.4, 1) -- round 34: no longer fills the screen
	wrap.Position = UDim2.fromOffset(left + availW / 2, top + availH / 2)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
local setOpen -- forward
local holder, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
	name = "Panel", title = "Hotel", subtitle = "", icon = ICON.hotel, onClose = function() setOpen(false) end, radius = 24,
})

local TABS = {
	{ id = "hotel", text = "Hotel", icon = ICON.hotel, title = "Your Hotel", sub = "How it's doing, what guests say and who you run it with" },
	{ id = "staff", text = "Staff", icon = ICON.staff, title = "Staff", sub = "Hire a team to run things while you build. More unlock as your hotel levels up" },
	{ id = "research", text = "Research", icon = ICON.research, title = "Research Lab", sub = "Discover new furniture, upgrades and new kinds of guests" },
	{ id = "upgrades", text = "Upgrades", icon = ICON.upgrade, title = "Upgrades", sub = "Fix up the Seabreeze and make it earn more" },
	{ id = "achievements", text = "Achievements", icon = ICON.trophy, title = "Achievements", sub = "Milestones for your hotel. Claim each tier for cash and XP" },
	{ id = "settings", text = "Settings", icon = ICON.settings, title = "Settings", sub = "Sound, gameplay, controls and your save" },
}
local pages = {}
for _, t in ipairs(TABS) do
	local p
	if t.id == "research" then
		-- ResearchUI builds the lab in here (its layout starts 64 px down, right under our tab bar)
		p = UI.new("Frame", { Name = "Page_research", Size = UDim2.fromOffset(W, 780), Position = UDim2.fromOffset(0, 8), BackgroundTransparency = 1, Visible = false, Parent = body })
	else
		p = UI.new("ScrollingFrame", {
			Name = "Page_" .. t.id, Size = UDim2.new(1, -44, 1, -86), Position = UDim2.fromOffset(22, 72), BackgroundTransparency = 1,
			ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
			ScrollBarThickness = 5, ScrollBarImageColor3 = T.gold, ScrollBarImageTransparency = 0.4, Visible = false, Parent = body,
		})
		UI.list(p, nil, 12)
		UI.pad(p, 2, 4, 12, 12)
	end
	pages[t.id] = p
end
local showTab -- forward
local tabs = UI.tabs(body, TABS, function(id) showTab(id) end, { pos = UDim2.fromOffset(22, 62), size = UDim2.new(1, -44, 0, 44), textSize = 18 })
do -- round 21: every menu opens on its own; the bottom bar is the way between them
	local tabsBar = body:FindFirstChild("Tabs")
	if tabsBar then tabsBar.Visible = false end
end
UI.new("Frame", { Size = UDim2.new(1, -44, 0, 1), Position = UDim2.fromOffset(22, 106), BackgroundColor3 = T.line, BackgroundTransparency = 0.5, Visible = false, Parent = body })

-- a heading with a short gold bar in front of it
local function heading(parent, text, order, right)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order or 0, Parent = parent })
	local bar = UI.new("Frame", { Size = UDim2.fromOffset(4, 18), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.gold, Parent = f })
	UI.corner(bar, 2)
	UI.label(f, string.upper(text), 14, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -12, 1, 0) })
	if right then
		UI.label(f, right, 13, { Name = "Right", FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
	end
	return f
end

-- two columns that grow with their content
local function columns(parent, order, leftShare)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local a = UI.new("Frame", { Name = "Left", Size = UDim2.new(leftShare or 0.5, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = f })
	local b = UI.new("Frame", { Name = "Right", Size = UDim2.new(1 - (leftShare or 0.5), -8, 0, 0), Position = UDim2.new(leftShare or 0.5, 8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = f })
	UI.list(a, nil, 12)
	UI.list(b, nil, 12)
	return a, b
end

-- a stat tile: icon, big number, caption
local function tile(parent, icon, caption, order, color)
	local f = UI.new("Frame", { Size = UDim2.new(0.25, -9, 1, 0), BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = parent })
	UI.corner(f, 14)
	UI.stroke(f, 1.5, T.line, 0.45)
	UI.grad(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 229, 232), 90)
	UI.icon(f, ICON[icon] or icon, 34, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local v = UI.label(f, "0", 24, { FontFace = UI.F.black, TextColor3 = color or T.cream, Position = UDim2.fromOffset(54, 10), Size = UDim2.new(1, -60, 0, 28), TextScaled = true })
	UI.new("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 12, Parent = v })
	UI.label(f, caption, 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(54, 38), Size = UDim2.new(1, -60, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	return v, f
end

local function hotelQuests(h)
	local json = h and h:GetAttribute("Quests")
	local st
	if type(json) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(t) == "table" then st = t end
	end
	st = st or {}
	st.life = type(st.life) == "table" and st.life or {}
	st.ach = type(st.ach) == "table" and st.ach or {}
	return st
end

local function stars(parent, size, pos)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(5 * size, size), Position = pos or UDim2.new(), BackgroundTransparency = 1, Parent = parent })
	local clips = {}
	for i = 1, 5 do
		local hh = UI.new("Frame", { Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset((i - 1) * size, 0), BackgroundTransparency = 1, Parent = f })
		UI.icon(hh, ICON.starEmpty, size, { ImageTransparency = 0.2 })
		local clip = UI.new("Frame", { Size = UDim2.fromOffset(0, size), BackgroundTransparency = 1, ClipsDescendants = true, Parent = hh })
		UI.icon(clip, ICON.star, size)
		clips[i] = clip
	end
	local api = { frame = f, shown = -1 }
	function api.set(v, instant)
		if math.abs(v - api.shown) < 0.01 then return end
		api.shown = v
		for i = 1, 5 do
			local goal = UDim2.fromOffset(size * math.clamp(v - (i - 1), 0, 1), size)
			if instant then clips[i].Size = goal else UI.tween(clips[i], 0.5, { Size = goal }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, (i - 1) * 0.05) end
		end
	end
	return api
end

---------------------------------------------------------------- hotel page
-- round 24: the Hotel, Staff, Achievements and Settings pages, laid out new. Each page is one root frame with its own
-- columns; cards are flat grey blocks with no rims or gradients; bars are thin and one colour.
local Grades = require(Shared:WaitForChild("Grades"))
local Hiring = require(Shared:WaitForChild("Hiring"))
local BuildMod = require(Shared:WaitForChild("Build"))
local refreshHotel, refreshAll, refreshHire, refreshAch -- forward
local ROUND = UDim.new(0.5, 0)
local Y = Enum.AutomaticSize.Y

local function block(parent, h, order)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = T.ink2, LayoutOrder = order or 0, Parent = parent })
	if h == 0 then f.AutomaticSize = Y end
	UI.corner(f, 14)
	return f
end
local function caps(parent, text, order, props)
	local l = UI.label(parent, string.upper(text), 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, LayoutOrder = order or 0, Size = UDim2.new(1, 0, 0, 16) })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function meter(parent, pos, size, color)
	local track = UI.new("Frame", { Size = size, Position = pos, BackgroundColor3 = T.ink3, Parent = parent })
	UI.corner(track, ROUND)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color or T.brand, Parent = track })
	UI.corner(fill, ROUND)
	return fill, track
end
local function pills(parent, items, current, order, onPick)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order or 0, Parent = parent })
	UI.list(f, Enum.FillDirection.Horizontal, 6)
	local btns = {}
	local function mark(id)
		for k, b in pairs(btns) do
			b.BackgroundColor3 = k == id and T.brand or T.ink2
			b.TextColor3 = k == id and T.white or T.muted
		end
	end
	for i, it in ipairs(items) do
		local b = UI.new("TextButton", { Text = it.text, TextSize = 14, FontFace = UI.F.heavy, AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), BackgroundColor3 = T.ink2, TextColor3 = T.muted, LayoutOrder = i, Parent = f })
		UI.corner(b, 16)
		UI.pad(b, 16, 0, 16, 0)
		b.Activated:Connect(function()
			UI.sound("Tab")
			mark(it.id)
			onPick(it.id)
		end)
		btns[it.id] = b
	end
	mark(current)
	return f
end
local function pageRoot(P)
	return UI.new("Frame", { Name = "Root", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = P })
end
local function column(root, pos, size, gap)
	local f = UI.new("Frame", { Size = size, Position = pos, AutomaticSize = Y, BackgroundTransparency = 1, Parent = root })
	UI.list(f, nil, gap or 10)
	return f
end
-- a big number over a small caption
local function figure(parent, caption, order, color, share)
	local f = block(parent, 78, order)
	f.Size = UDim2.new(share or 0.25, -8, 1, 0)
	local v = UI.label(f, "0", 26, { FontFace = UI.F.heavy, TextColor3 = color or T.cream, Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -20, 0, 30), TextScaled = true })
	UI.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12, Parent = v })
	UI.label(f, caption, 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -20, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	return v
end

do
	local P = pages.hotel
	local root = pageRoot(P)
	local A = column(root, UDim2.new(), UDim2.new(0, 330, 0, 0))
	local B = column(root, UDim2.fromOffset(346, 0), UDim2.new(1, -722, 0, 0))
	local Rv = column(root, UDim2.new(1, -360, 0, 0), UDim2.new(0, 360, 0, 0))

	-- round 41: open or closed. A closed hotel takes no new guests (the ones staying finish their stay)
	local oc = block(A, 92, 0)
	local ocTile = UI.new("Frame", { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.green, Parent = oc })
	UI.corner(ocTile, 16)
	UI.gloss(ocTile, 16, 0.35)
	UI.icon(ocTile, ICON.door or ICON.hotel, 44, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	local ocTitle = UI.label(oc, "OPEN", 24, { FontFace = UI.F.black, TextColor3 = T.greenDk, Position = UDim2.fromOffset(86, 16), Size = UDim2.new(1, -96, 0, 28) })
	local ocLine = UI.label(oc, "Guests are welcome", 15, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(86, 48), Size = UDim2.new(1, -200, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
	local ocBtn, ocText = UI.button(oc, {
		text = "Close", kind = "red", size = UDim2.fromOffset(104, 44), pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 17, radius = 12,
		onClick = function()
			local h = workHotel()
			if h then Coop:FireServer("closed", not h:GetAttribute("Closed")) end
		end,
	})
	local function refreshOpen(h)
		local closed = h:GetAttribute("Closed") == true
		ocTile.BackgroundColor3 = closed and T.red or T.green
		ocTitle.Text = closed and "CLOSED" or "OPEN"
		ocTitle.TextColor3 = closed and T.redDk or T.greenDk
		ocLine.Text = closed and "No new guests are let in" or "Guests are welcome"
		ocText.Text = closed and "Open" or "Close"
		UI.setKind(ocBtn, closed and "green" or "red")
		ocBtn.Visible = h:GetAttribute("Owner") == player.UserId
	end

	-- A: who you are. Name, rating, level, grade
	local me = block(A, 176, 1)
	caps(me, "Your hotel", 0, { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 16) })
	local nameBox = UI.new("TextBox", {
		Size = UDim2.new(1, -72, 0, 38), Position = UDim2.fromOffset(10, 36), BackgroundColor3 = T.ink, BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Name your hotel", PlaceholderColor3 = T.muted, TextSize = 24, FontFace = UI.F.heavy, TextColor3 = T.cream,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = me,
	})
	UI.corner(nameBox, 10)
	UI.pad(nameBox, 8, 0, 8, 0)
	nameBox.Focused:Connect(function() nameBox.BackgroundTransparency = 0 end)
	local function saveName()
		local name = nameBox.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
		if name == "" then mtoast("Type a name first!", "close", true) return end
		local h = workHotel()
		if h and name == h:GetAttribute("HotelName") then return end
		Coop:FireServer("rename", name)
	end
	nameBox.FocusLost:Connect(function(enter)
		nameBox.BackgroundTransparency = 1
		if enter then saveName() end
	end)
	local nameBtn = UI.button(me, {
		icon = ICON.paint, iconSize = 20, kind = "ink", size = UDim2.fromOffset(38, 38), pos = UDim2.new(1, -14, 0, 36), anchor = Vector2.new(1, 0), radius = 10,
		onClick = function()
			if nameBox:IsFocused() then nameBox:ReleaseFocus(true) saveName() else nameBox:CaptureFocus() end
		end,
	})
	UI.tooltip(nameBtn, "Rename your hotel")
	local heroStars = stars(me, 22, UDim2.fromOffset(18, 86))
	local heroRating = UI.label(me, "", 20, { FontFace = UI.F.heavy, TextColor3 = T.brand, Position = UDim2.fromOffset(138, 83), Size = UDim2.fromOffset(60, 28) })
	local heroReviews = UI.label(me, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 114), Size = UDim2.new(1, -36, 0, 16) })
	local heroLine = UI.label(me, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 136), Size = UDim2.new(1, -36, 0, 32), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })

	local lvCard = block(A, 146, 2)
	caps(lvCard, "Hotel level", 0, { Position = UDim2.fromOffset(18, 16), Size = UDim2.fromOffset(200, 16) })
	local lvNum = UI.label(lvCard, "1", 44, { FontFace = UI.F.heavy, TextColor3 = T.brand, Position = UDim2.fromOffset(18, 34), Size = UDim2.fromOffset(84, 52) })
	local lvTitle = UI.label(lvCard, "", 14, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(108, 44), Size = UDim2.new(1, -124, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local lvXP = UI.label(lvCard, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(108, 64), Size = UDim2.new(1, -124, 0, 16) })
	local lvFill = meter(lvCard, UDim2.fromOffset(18, 98), UDim2.new(1, -36, 0, 8))
	UI.label(lvCard, "Guests, clean rooms, research and goals give XP", 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 116), Size = UDim2.new(1, -36, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })

	local gCard = block(A, 0, 3)
	UI.pad(gCard, 18, 16, 18, 16)
	UI.list(gCard, nil, 6)
	caps(gCard, "Hotel grade", 1)
	local gName = UI.label(gCard, "", 20, { FontFace = UI.F.heavy, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 26) })
	local gSegs = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = 3, Parent = gCard })
	local gFloors = {}
	for i = 1, 5 do
		local s = UI.new("Frame", { Size = UDim2.new(0.2, -4, 1, 0), Position = UDim2.new((i - 1) * 0.2, 0, 0, 0), BackgroundColor3 = T.ink3, Parent = gSegs })
		UI.corner(s, ROUND)
		gFloors[i] = s
	end
	local gLook = UI.label(gCard, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, LayoutOrder = 4, TextWrapped = true, AutomaticSize = Y, Size = UDim2.new(1, 0, 0, 0) })
	local gNextTitle = UI.label(gCard, "", 14, { FontFace = UI.F.heavy, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 22), TextYAlignment = Enum.TextYAlignment.Bottom })
	local gNextLook = UI.label(gCard, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, LayoutOrder = 6, TextWrapped = true, AutomaticSize = Y, Size = UDim2.new(1, 0, 0, 0) })
	local gReqs = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 7, Parent = gCard })
	UI.list(gReqs, nil, 2)
	local gBtnRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, LayoutOrder = 8, Parent = gCard })
	local gBtn, gBtnText = UI.button(gBtnRow, {
		text = "Upgrade", kind = "green", size = UDim2.new(1, 0, 0, 44), pos = UDim2.fromOffset(0, 6), textSize = 16, radius = 12,
		onClick = function()
			local ok, r = Build:InvokeServer("grade")
			if not ok then mtoast(r or "Can't upgrade yet", "close", true) end
		end,
	})
	local function refreshGrade(h)
		local g = Grades.of(h)
		local def = Grades.LIST[g]
		gName.Text = def.name
		gLook.Text = "Grade " .. g .. " of " .. Grades.MAX .. ". " .. def.look .. "."
		for i, s in ipairs(gFloors) do s.BackgroundColor3 = i <= g and T.brand or T.ink3 end
		local owner = Players:GetPlayerByUserId(h:GetAttribute("Owner") or 0)
		local list, all, nextDef = Grades.check(h, owner and owner:GetAttribute("Cash") or 0)
		local key = g .. ":"
		for _, e in ipairs(list) do key ..= e.have .. (e.ok and "+" or "-") end
		if key == gReqs:GetAttribute("Key") then return end
		gReqs:SetAttribute("Key", key)
		for _, c in ipairs(gReqs:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		if not nextDef then
			gNextTitle.Text = "The finest hotel in town"
			gNextLook.Text = "Every grade is unlocked."
			gBtnRow.Visible = false
			return
		end
		gNextTitle.Text = "Next: " .. nextDef.name
		gNextLook.Text = nextDef.look .. ". " .. nextDef.perk .. "."
		for i, e in ipairs(list) do
			local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i, Parent = gReqs })
			local dot = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = e.ok and T.green or T.line, Parent = r })
			UI.corner(dot, ROUND)
			UI.label(r, e.text, 13, { FontFace = UI.F.bold, TextColor3 = e.ok and T.cream or T.muted, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -98, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
			UI.label(r, e.have, 13, { FontFace = UI.F.heavy, TextColor3 = e.ok and T.greenDk or T.red, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
		end
		gBtnRow.Visible = h:GetAttribute("Owner") == player.UserId
		UI.setKind(gBtn, all and "green" or "ghost")
		gBtnText.Text = all and "Upgrade" or "Not yet"
	end

	-- B: the numbers, what's coming, and friends
	caps(B, "Right now", 1)
	local nowRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = 2, Parent = B })
	UI.list(nowRow, Enum.FillDirection.Horizontal, 10)
	local nowVals = {
		ready = figure(nowRow, "rooms ready", 1, T.greenDk), dirty = figure(nowRow, "to clean", 2, T.red),
		waiting = figure(nowRow, "in line", 3), appeal = figure(nowRow, "lobby appeal", 4, T.brand),
	}
	caps(B, "All time", 3)
	local lifeRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = 4, Parent = B })
	UI.list(lifeRow, Enum.FillDirection.Horizontal, 10)
	local life = {}
	for i, d in ipairs({
		{ key = "guests", text = "guests served" }, { key = "earn", text = "earned", money = true },
		{ key = "clean", text = "rooms cleaned" }, { key = "review5", text = "5-star reviews" },
	}) do
		life[d.key] = { label = figure(lifeRow, d.text, i, d.money and T.greenDk or nil), money = d.money }
	end
	caps(B, "Coming up", 5)
	local road = block(B, 0, 6)
	UI.pad(road, 14, 10, 14, 10)
	UI.list(road, nil, 2)
	local roadFor = -1
	local function buildRoad(lv)
		roadFor = lv
		for _, c in ipairs(road:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		local shown = 0
		for Lv = lv + 1, Levels.MAX do
			local u = Levels.unlocksAt(Lv)
			if #u > 0 then
				shown += 1
				local step = UI.new("Frame", { Name = "L" .. Lv, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = Lv, Parent = road })
				UI.label(step, "Level " .. Lv, 13, { FontFace = UI.F.heavy, TextColor3 = shown == 1 and T.brand or T.muted, Size = UDim2.new(0, 70, 1, 0) })
				for j = 1, math.min(#u, 7) do
					UI.icon(step, ICON[u[j].icon] or ICON.star, 30, { Position = UDim2.new(0, 74 + (j - 1) * 36, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
				end
				if #u > 7 then
					UI.label(step, "+" .. (#u - 7), 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
				end
				local names = {}
				for _, x in ipairs(u) do table.insert(names, x.name) end
				UI.tooltip(step, "Level " .. Lv .. ": " .. table.concat(names, ", "))
				if shown >= 4 then break end
			end
		end
		if shown == 0 then
			UI.label(road, "Everything is unlocked. You run a legendary hotel!", 13, { FontFace = UI.F.bold, TextColor3 = T.muted, Size = UDim2.new(1, 0, 0, 28) })
		end
	end
	local function refreshLevel(h)
		local lv = h:GetAttribute("Level") or 1
		local xp = h:GetAttribute("XP") or 0
		local need = h:GetAttribute("XPNeed") or Levels.need(lv)
		lvNum.Text = tostring(lv)
		if lv >= Levels.MAX then
			lvTitle.Text = "Top level reached"
			lvXP.Text = "Nothing left to unlock"
		else
			lvTitle.Text = UI.commas(math.max(need - xp, 0)) .. " XP to level " .. (lv + 1)
			lvXP.Text = UI.commas(xp) .. " / " .. UI.commas(need) .. " XP"
		end
		local k = lv >= Levels.MAX and 1 or math.clamp(xp / math.max(need, 1), 0, 1)
		UI.tween(lvFill, 0.4, { Size = UDim2.fromScale(k, 1) })
		if roadFor ~= lv then buildRoad(lv) end
	end

	caps(B, "Play together", 7)
	local away = block(B, 60, 8)
	local awayText = UI.label(away, "", 14, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -160, 1, 0), TextWrapped = true })
	local homeBtn = UI.button(away, {
		text = "My hotel", kind = "green", size = UDim2.fromOffset(120, 38), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10,
		onClick = function() Coop:FireServer("leave") end,
	})
	local coopList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 9, Parent = B })
	UI.list(coopList, nil, 8)
	local empty = block(coopList, 64, 999)
	UI.label(empty, "Nobody else is here yet. Invite friends to this server from the Roblox menu, then invite them to your hotel here.", 13, {
		FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0),
	})
	local rows = {} -- player -> row
	local invited = {} -- userId -> time we invited them
	local function makeRow(p)
		local f = block(coopList, 104, 10)
		f.Name = "Row_" .. p.UserId
		local face = UI.new("ImageLabel", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(12, 10), BackgroundColor3 = T.ink3, Parent = f })
		UI.corner(face, ROUND)
		task.spawn(function() face.Image = headshot(p.UserId) end)
		UI.label(f, p.DisplayName, 15, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -74, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local where = UI.label(f, "", 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(62, 30), Size = UDim2.new(1, -74, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local bar = UI.new("Frame", { Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 60), BackgroundTransparency = 1, Parent = f })
		UI.list(bar, Enum.FillDirection.Horizontal, 8)
		local r = { frame = f, where = where, mode = "invite" }
		UI.button(bar, {
			text = "Visit", kind = "ink", size = UDim2.new(1 / 3, -6, 1, 0), textSize = 14, radius = 10, order = 1,
			onClick = function() Coop:FireServer("visit", p.UserId) setOpen(false) end,
		})
		r.askBtn, r.askText = UI.button(bar, {
			text = "Ask to join", kind = "ink", size = UDim2.new(1 / 3, -6, 1, 0), textSize = 14, radius = 10, order = 2,
			onClick = function()
				if r.asked and os.clock() - r.asked < 60 then return end
				r.asked = os.clock()
				Coop:FireServer("request", p.UserId)
				r.askText.Text = "Asked"
				UI.setKind(r.askBtn, "ghost")
				task.delay(60, function() if r.askText then r.askText.Text = "Ask to join" UI.setKind(r.askBtn, "ink") end end)
			end,
		})
		r.btn, r.text = UI.button(bar, {
			text = "Invite", kind = "green", size = UDim2.new(1 / 3, -6, 1, 0), textSize = 14, radius = 10, order = 3,
			onClick = function()
				if r.mode == "invite" then
					invited[p.UserId] = os.clock()
					Coop:FireServer("invite", p.UserId)
					mtoast("Invite sent to " .. p.DisplayName, "coop")
				elseif r.mode == "kick" then
					Coop:FireServer("kick", p.UserId)
				end
				task.delay(0.2, function() if rows[p] then rows[p].refresh() end end)
			end,
		})
		function r.refresh()
			local mine = player:GetAttribute("Home")
			local theirPlot = p:GetAttribute("Plot")
			local theirHome = p:GetAttribute("Home")
			if theirPlot and theirPlot == mine then
				where.Text = "Working in your hotel"
				r.mode = "kick"
				r.text.Text = "Send home"
				UI.setKind(r.btn, "red")
			else
				where.Text = (theirPlot and theirPlot == theirHome) and "Running their own hotel" or ("Helping at " .. hotelName(theirPlot))
				local pending = invited[p.UserId] and os.clock() - invited[p.UserId] < 60
				r.mode = (mine and not pending) and "invite" or "none"
				r.text.Text = pending and "Invited" or "Invite"
				UI.setKind(r.btn, r.mode == "invite" and "green" or "ghost")
			end
		end
		rows[p] = r
		r.refresh()
		p:GetAttributeChangedSignal("Plot"):Connect(r.refresh)
	end
	refreshAll = function()
		local mine, here = player:GetAttribute("Home"), player:GetAttribute("Plot")
		local isAway = here ~= nil and here ~= mine
		away.Visible = isAway
		if isAway then
			awayText.Text = "You're helping at " .. hotelName(here)
			homeBtn.Visible = mine ~= nil
		end
		local n = 0
		for _, r in pairs(rows) do
			n += 1
			r.refresh()
		end
		empty.Visible = n == 0
	end
	for _, p in ipairs(Players:GetPlayers()) do if p ~= player then makeRow(p) end end
	Players.PlayerAdded:Connect(function(p) makeRow(p) refreshAll() end)
	Players.PlayerRemoving:Connect(function(p)
		local r = rows[p]
		if r then r.frame:Destroy() rows[p] = nil end
		refreshAll()
	end)
	for _, a in ipairs({ "Plot", "Home" }) do player:GetAttributeChangedSignal(a):Connect(refreshAll) end
	refreshAll()

	-- Rv: what guests say
	caps(Rv, "Guest reviews", 1)
	local revTop = block(Rv, 122, 2)
	local revAvg = UI.label(revTop, "-", 40, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(96, 46) })
	local revStars = stars(revTop, 16, UDim2.fromOffset(18, 64))
	local revCount = UI.label(revTop, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 88), Size = UDim2.fromOffset(100, 16) })
	local distBars = {}
	for s = 5, 1, -1 do
		local y = 16 + (5 - s) * 19
		UI.label(revTop, tostring(s), 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(124, y), Size = UDim2.fromOffset(12, 14) })
		local fill = meter(revTop, UDim2.fromOffset(142, y + 4), UDim2.new(1, -196, 0, 6), s >= 4 and T.brand or s == 3 and T.muted or T.red)
		local n = UI.label(revTop, "0", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -46, 0, y), Size = UDim2.fromOffset(30, 14) })
		distBars[s] = { fill = fill, n = n }
	end
	local revFilter = "all"
	local refreshReviews -- forward
	pills(Rv, { { id = "all", text = "All" }, { id = "good", text = "Praise" }, { id = "bad", text = "Complaints" } }, "all", 3, function(id)
		revFilter = id
		refreshReviews(true)
	end)
	local revList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = Rv })
	UI.list(revList, nil, 8)
	local revJSON
	refreshReviews = function(force)
		local h = workHotel()
		local json = h and h:GetAttribute("Reviews")
		if json == revJSON and not force then return end
		revJSON = json
		local list = {}
		if type(json) == "string" then
			local ok, t = pcall(HttpService.JSONDecode, HttpService, json)
			if ok and type(t) == "table" then list = t end
		end
		local sum, counts = 0, { 0, 0, 0, 0, 0 }
		for _, r in ipairs(list) do
			local s = math.clamp(tonumber(r.stars) or 3, 1, 5)
			sum += s
			counts[s] += 1
		end
		revAvg.Text = #list > 0 and string.format("%.1f", sum / #list) or "-"
		revStars.set(#list > 0 and sum / #list or 0)
		revCount.Text = #list == 1 and "1 review" or (#list .. " reviews")
		for s = 1, 5 do
			UI.tween(distBars[s].fill, 0.5, { Size = UDim2.fromScale(#list > 0 and counts[s] / #list or 0, 1) }, Enum.EasingStyle.Quint)
			distBars[s].n.Text = tostring(counts[s])
		end
		for _, c in ipairs(revList:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
		local shown = 0
		for i, r in ipairs(list) do
			local s = math.clamp(tonumber(r.stars) or 3, 1, 5)
			if revFilter == "all" or (revFilter == "good" and s >= 4) or (revFilter == "bad" and s <= 2) then
				shown += 1
				local card = block(revList, 0, i)
				UI.pad(card, 14, 12, 14, 12)
				UI.list(card, nil, 6)
				local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
				stars(top, 14).set(s, true)
				UI.label(top, (r.name or "A guest") .. (r.room and (", room " .. r.room) or ""), 12, {
					FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1),
				})
				UI.label(card, tostring(r.text or ""), 14, {
					FontFace = UI.F.bold, TextColor3 = T.cream, TextWrapped = true, AutomaticSize = Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
				})
				if shown >= 12 then break end
			end
		end
		if shown == 0 then
			local f = block(revList, 56, 1)
			UI.label(f, #list == 0 and "No reviews yet. Guests leave one when they check out." or "Nothing here yet.", 13, {
				FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextWrapped = true,
			})
		end
	end

	refreshHotel = function()
		local h = workHotel()
		if not h then return end
		local s = h:GetAttribute("HotelStars") or 1
		heroStars.set(s)
		heroRating.Text = string.format("%.1f", s)
		local rs = h:GetAttribute("ReviewStars")
		heroReviews.Text = rs and ("Reviews average " .. string.format("%.1f", rs)) or "No reviews yet"
		local total = (h:GetAttribute("RoomsReady") or 0) + (h:GetAttribute("RoomsBusy") or 0) + (h:GetAttribute("RoomsDirty") or 0)
		local staffN = 0
		for _, def in ipairs(C.STAFF) do staffN += h:GetAttribute(def.attr) or 0 end
		heroLine.Text = total .. (total == 1 and " guest room" or " guest rooms") .. ", " .. staffN .. (staffN == 1 and " staff member" or " staff") .. ", day " .. (Shared:GetAttribute("Day") or 1)
		local st = hotelQuests(h)
		for key, v in pairs(life) do
			local n = tonumber(st.life[key]) or 0
			v.label.Text = (v.money and "$" or "") .. UI.commas(n)
		end
		nowVals.ready.Text = tostring(h:GetAttribute("RoomsReady") or 0)
		nowVals.dirty.Text = tostring(h:GetAttribute("RoomsDirty") or 0)
		nowVals.waiting.Text = tostring(h:GetAttribute("Waiting") or 0)
		nowVals.appeal.Text = tostring(h:GetAttribute("LobbyAppeal") or 0)
		local mine = player:GetAttribute("Home")
		local isMine = mine ~= nil and h.Name == mine
		nameBox.TextEditable = isMine
		nameBtn.Visible = isMine
		if not nameBox:IsFocused() then nameBox.Text = h:GetAttribute("HotelName") or "My Hotel" end
		refreshLevel(h)
		refreshReviews()
		refreshGrade(h)
		refreshOpen(h)
	end
end

---------------------------------------------------------------- staff page (hiring goes through the Build remote)
-- A status line on top. Left: pick a job, then one of the people who applied. Right: your team.
do
	local P = pages.staff
	local BLURB = {
		janitor = "Keeps rooms spotless", doorman = "Runs the front door", receptionist = "Works the front desk",
		cook = "Runs the kitchen", handyman = "Keeps things running",
	}
	local StaffEdit = Shared.Remotes:WaitForChild("StaffEdit", 10)
	local staffRoomMissing = {}
	local function hasStaffRoom(h)
		if not h then return false end
		local ok, missing = BuildMod.staffRoom(h)
		staffRoomMissing = missing or {}
		return ok
	end
	local STAFF_BY, ROLE_ORDER = {}, {}
	for i, d in ipairs(C.STAFF) do STAFF_BY[d.id] = d ROLE_ORDER[d.id] = i end
	local hireRole = STAFF_BY.receptionist and "receptionist" or C.STAFF[1].id

	local status = block(P, 56, 0)
	local statusDot = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.green, Parent = status })
	UI.corner(statusDot, ROUND)
	local statusText = UI.label(status, "", 14, { FontFace = UI.F.bold, RichText = true, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -470, 1, 0), TextWrapped = true })
	local statusNums = UI.label(status, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, RichText = true, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 400, 1, 0) })
	local roomBtn = UI.button(status, { text = "Build a staff room", kind = "gold", size = UDim2.fromOffset(190, 38), pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10, onClick = function()
		player:SetAttribute("BuildWant", "staff")
		if setOpen then setOpen(false) end
	end })

	local root = pageRoot(P)
	local Hr = column(root, UDim2.new(), UDim2.new(0.56, -8, 0, 0))
	local Tm = column(root, UDim2.new(0.56, 8, 0, 0), UDim2.new(0.44, -8, 0, 0), 8)

	local hireHead = caps(Hr, "Hire someone", 1)
	local hireTimer = UI.label(hireHead, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
	local hireWrap = UI.new("Frame", { Size = UDim2.new(1, 0, 0, Hiring.PER_ROLE * 126 - 8), BackgroundTransparency = 1, LayoutOrder = 2, Parent = Hr })
	local roleRail = UI.new("Frame", { Size = UDim2.new(0, 176, 1, 0), BackgroundTransparency = 1, Parent = hireWrap })
	UI.list(roleRail, nil, 6)
	local roleBtns = {}
	for i, def in ipairs(C.STAFF) do
		local b = UI.new("TextButton", { Name = "Role_" .. def.id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = roleRail })
		UI.corner(b, 12)
		UI.icon(b, ICON[def.icon] or ICON.staff, 28, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		local t = UI.label(b, def.name, 14, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -90, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		local n = UI.label(b, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -12, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 36, 1, 0) })
		b.Activated:Connect(function()
			if hireRole ~= def.id then hireRole = def.id UI.sound("Tab") refreshHire() end
		end)
		roleBtns[def.id] = { b = b, t = t, n = n }
	end
	local candCol = UI.new("Frame", { Size = UDim2.new(1, -188, 1, 0), Position = UDim2.fromOffset(188, 0), BackgroundTransparency = 1, Parent = hireWrap })
	UI.list(candCol, nil, 8)
	local STAR = ICON.star or ICON.rating or ICON.checkmark
	local function trait(parent, x, good)
		local f = UI.new("Frame", { Size = UDim2.new(0.5, -19, 0, 38), Position = x, BackgroundColor3 = good and Color3.fromRGB(228, 250, 236) or Color3.fromRGB(253, 232, 234), Parent = parent })
		UI.corner(f, 10)
		local name = UI.label(f, "", 12, { FontFace = UI.F.heavy, TextColor3 = good and T.greenDk or T.red, Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -16, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd })
		local text = UI.label(f, "", 11, { FontFace = UI.F.body, TextColor3 = T.cream, Position = UDim2.fromOffset(10, 19), Size = UDim2.new(1, -16, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
		return { name = name, text = text }
	end
	local candCards = {}
	for i = 1, Hiring.PER_ROLE do
		local f = block(candCol, 118, i)
		local face = UI.new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(14, 12), BackgroundColor3 = T.brandSoft, Parent = f })
		UI.corner(face, ROUND)
		local initials = UI.label(face, "", 16, { FontFace = UI.F.heavy, TextColor3 = T.brand, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
		local name = UI.label(f, "", 16, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(68, 10), Size = UDim2.new(1, -240, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local talk = UI.label(f, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(68, 30), Size = UDim2.new(1, -240, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local starList = {}
		for k = 1, 5 do
			starList[k] = UI.icon(f, STAR, 14, { Position = UDim2.fromOffset(68 + (k - 1) * 15, 48) })
		end
		local pro = trait(f, UDim2.fromOffset(14, 70), true)
		local con = trait(f, UDim2.new(0.5, 5, 0, 70), false)
		local btn, txt
		btn, txt = UI.button(f, { text = "Hire", kind = "green", size = UDim2.fromOffset(160, 40), pos = UDim2.new(1, -14, 0, 14), anchor = Vector2.new(1, 0), textSize = 14, radius = 10,
			onClick = function(b)
				local def = STAFF_BY[hireRole]
				local ok, res, msg = pcall(Build.InvokeServer, Build, "hire", def.id, i)
				if ok and res == false and msg then mtoast(msg, def.icon, true) UI.shake(b) end
				if ok and res ~= false then UI.sound("Register") end
				task.delay(0.2, function() refreshHire() end)
			end,
		})
		candCards[i] = { frame = f, initials = initials, name = name, talk = talk, stars = starList, pro = pro, con = con, btn = btn, text = txt }
	end
	local hireFoot = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 3, Parent = Hr })
	local hireInfo = UI.label(hireFoot, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Size = UDim2.new(1, -180, 1, 0), TextWrapped = true })
	UI.button(hireFoot, { text = "New faces  $" .. Hiring.REROLL_PRICE, kind = "ink", size = UDim2.fromOffset(164, 34), pos = UDim2.new(1, 0, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 13, radius = 10, onClick = function(b)
		local ok, res, msg = pcall(Build.InvokeServer, Build, "reroll")
		if ok and res == false and msg then mtoast(msg, "staff", true) UI.shake(b) end
		if ok and res ~= false then UI.sound("Open") end
		task.delay(0.15, function() refreshHire() end)
	end })
	local function readCands(h)
		if not h then return nil end
		local raw = h:GetAttribute("StaffCands")
		if not raw then return nil end
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		return ok and type(t) == "table" and t or nil
	end
	local askedCands = false
	local lastCandSig
	task.spawn(function()
		while true do
			task.wait(1)
			local h = workHotel()
			local c = readCands(h)
			if c and c.at then
				local left = math.max(0, Hiring.REFRESH - (os.time() - c.at))
				hireTimer.Text = string.format("New people in %d:%02d", left // 60, left % 60)
			end
			local sig = (h and h:GetAttribute("StaffCands") or "") .. hireRole
			if P.Visible and sig ~= lastCandSig then refreshHire() end
		end
	end)

	-- your team
	caps(Tm, "Your team", 1)
	local teamList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = Tm })
	UI.list(teamList, nil, 8)
	local teamRows = {} -- model -> card bits
	local teamEmpty = block(Tm, 56, 3)
	UI.label(teamEmpty, "Nobody hired yet. A receptionist is a great first hire.", 13, { FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextWrapped = true })
	local function send(m, action)
		local k = m:GetAttribute("StaffKey")
		if k and StaffEdit then StaffEdit:FireServer(action, k, {}) end
	end
	local function makeCard(m, def)
		local f = block(teamList, 94, 0)
		local sq = UI.new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.white, Parent = f })
		UI.corner(sq, 12)
		UI.icon(sq, ICON[def and def.icon or "staff"], 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		local nm = UI.label(f, m.Name, 15, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(68, 9), Size = UDim2.new(1, -140, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local lvText = UI.label(f, "LV 1", 12, { FontFace = UI.F.heavy, TextColor3 = T.brand, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -14, 0, 10), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(50, 16) })
		local role = UI.label(f, def and def.name or "Staff", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, RichText = true, Position = UDim2.fromOffset(68, 29), Size = UDim2.new(1, -82, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd })
		local doing = UI.label(f, "", 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(68, 44), Size = UDim2.new(1, -82, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd })
		local fill = meter(f, UDim2.fromOffset(14, 76), UDim2.new(1, -14 - 262, 0, 6), T.green)
		local eText = UI.label(f, "", 11, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -276, 0, 14) })
		local bar = UI.new("Frame", { Size = UDim2.fromOffset(240, 28), Position = UDim2.new(1, -12, 1, -10), AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Parent = f })
		UI.list(bar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
		UI.button(bar, { text = "Edit", kind = "ink", size = UDim2.fromOffset(58, 28), textSize = 13, radius = 8, order = 1, onClick = function()
			local k = m:GetAttribute("StaffKey")
			if k then player:SetAttribute("StaffEdit", k) end
		end })
		local brk, brkT = UI.button(bar, { text = "Break", kind = "ink", size = UDim2.fromOffset(102, 28), textSize = 13, radius = 8, order = 2, onClick = function() send(m, "break") end })
		local armed = 0
		local fireB, fireT
		fireB, fireT = UI.button(bar, { text = "Let go", kind = "ghost", size = UDim2.fromOffset(68, 28), textSize = 13, radius = 8, order = 3, onClick = function(b)
			if os.clock() - armed < 3 then
				armed = 0
				send(m, "fire")
				UI.sound("Close")
			else
				armed = os.clock()
				fireT.Text = "Sure?"
				UI.setKind(fireB, "red")
				UI.shake(b)
				task.delay(3, function()
					if os.clock() - armed >= 2.9 and fireB.Parent then fireT.Text = "Let go" UI.setKind(fireB, "ghost") end
				end)
			end
		end })
		return { frame = f, name = nm, role = role, doing = doing, lv = lvText, fill = fill, eText = eText, brkT = brkT, brk = brk, def = def }
	end
	local function refreshTeam()
		local h = workHotel()
		local seen = {}
		local n, onBreak = 0, 0
		if h then
			for _, m in ipairs(h:GetDescendants()) do
				local kind = m:IsA("Model") and m:GetAttribute("Staff")
				if kind then
					n += 1
					seen[m] = true
					local r = teamRows[m]
					if not r then
						r = makeCard(m, STAFF_BY[kind])
						teamRows[m] = r
					end
					local key = m:GetAttribute("StaffKey") or ""
					r.frame.LayoutOrder = (ROLE_ORDER[kind] or 9) * 10 + (tonumber(key:match("%d+$")) or 0)
					r.name.Text = m.Name
					local pro, con = Hiring.TRAITS[m:GetAttribute("TraitPro") or ""], Hiring.TRAITS[m:GetAttribute("TraitCon") or ""]
					local sk = m:GetAttribute("StaffSkill")
					r.role.Text = (r.def and r.def.name or "Staff") .. (sk and (", " .. sk .. " star") or "")
						.. (pro and ('  <font color="#148c4c">+' .. pro.name .. '</font>') or "")
						.. (con and ('  <font color="#d64552">-' .. con.name .. '</font>') or "")
					local brole = m:GetAttribute("BRole") or ""
					r.lv.Text = "LV " .. (brole:match("LV (%d+)") or "1")
					local what = (m:GetAttribute("BWhat") or m:GetAttribute("BText")) or ""
					r.doing.Text = what ~= "" and what or "Getting ready"
					local e = m:GetAttribute("Energy") or 100
					local br = m:GetAttribute("OnBreak")
					if br then onBreak += 1 end
					UI.tween(r.fill, 0.4, { Size = UDim2.fromScale(math.clamp(e / 100, 0.02, 1), 1) })
					r.fill.BackgroundColor3 = e < 25 and T.red or (e < 55 and Color3.fromRGB(240, 170, 50) or T.green)
					r.eText.Text = br and "On a break" or ("Energy " .. math.floor(e) .. "%")
					r.brkT.Text = br and "Back to work" or "Break"
				end
			end
		end
		for m, r in pairs(teamRows) do
			if not seen[m] then r.frame:Destroy() teamRows[m] = nil end
		end
		teamEmpty.Visible = n == 0
		local ok = hasStaffRoom(h)
		roomBtn.Visible = not ok
		statusNums.Visible = ok
		statusDot.BackgroundColor3 = ok and T.green or Color3.fromRGB(240, 170, 50)
		if ok then
			statusText.Text = "<b>Staff room ready.</b>  Tired staff work slower, so send them on a break now and then."
			statusNums.Text = n .. " on the team     $" .. UI.commas(h and h:GetAttribute("WageBill") or 0) .. " wages a day     " .. onBreak .. " on a break"
		else
			statusText.Text = "<b>You need a staff room before you can hire.</b>  Still missing: " .. table.concat(staffRoomMissing, ", ") .. "."
		end
	end

	refreshHire = function()
		local h = workHotel()
		local cash = player:GetAttribute("Cash") or 0
		local roomOk = hasStaffRoom(h)
		local def = STAFF_BY[hireRole]
		local n = h and (h:GetAttribute(def.attr) or 0) or 0
		for id, rb in pairs(roleBtns) do
			local d = STAFF_BY[id]
			local have = h and (h:GetAttribute(d.attr) or 0) or 0
			local on = id == hireRole
			rb.b.BackgroundColor3 = on and T.brandSoft or T.ink2
			rb.t.TextColor3 = on and T.brand or T.cream
			rb.n.Text = have .. "/" .. d.max
		end
		hireInfo.Text = def.name .. ": " .. string.lower(BLURB[def.id] or def.blurb or "") .. ". You have " .. n .. " of " .. def.max .. "."
		local cands = readCands(h)
		if h and not cands and not askedCands then
			askedCands = true
			task.spawn(function() pcall(Build.InvokeServer, Build, "cands") end)
		end
		local list = cands and cands.roles and cands.roles[def.id] or {}
		lastCandSig = (h and h:GetAttribute("StaffCands") or "") .. hireRole
		for i, card in ipairs(candCards) do
			local c = list[i]
			card.frame.Visible = c ~= nil
			if c then
				card.initials.Text = (c.name or "?"):sub(1, 1) .. (c.surname or ""):sub(1, 1)
				card.name.Text = (c.name or "") .. " " .. (c.surname or "")
				card.talk.Text = "Talks " .. string.lower(Hiring.VOICE_DESC[c.voice or ""] or "Normal") .. ", $" .. (c.wage or def.wage) .. " a day"
				for k, s in ipairs(card.stars) do
					s.ImageTransparency = k <= (c.skill or 1) and 0 or 0.8
				end
				local pro, con = Hiring.TRAITS[c.pro or ""], Hiring.TRAITS[c.con or ""]
				card.pro.name.Text = pro and ("+ " .. pro.name) or ""
				card.pro.text.Text = pro and pro.text or ""
				card.con.name.Text = con and ("- " .. con.name) or ""
				card.con.text.Text = con and con.text or ""
				local price = Hiring.priceFor(def, n + 1, c.skill or 2)
				if n >= def.max then
					card.text.Text = "Team full"
					UI.setKind(card.btn, "ghost")
				elseif not roomOk then
					card.text.Text = "Needs a staff room"
					UI.setKind(card.btn, "ghost")
				elseif h and not Levels.staffOk(h, def.id, n + 1) then
					card.text.Text = "Hotel level " .. Levels.staffLevel(def.id, n + 1)
					UI.setKind(card.btn, "ghost")
				else
					card.text.Text = "Hire  $" .. UI.commas(price)
					UI.setKind(card.btn, cash >= price and "green" or "ghost")
				end
			end
		end
		refreshTeam()
	end
end

---------------------------------------------------------------- achievements page
-- One line each: what it is, the three tiers, how far along, and the prize. What you can claim comes first.
do
	local P = pages.achievements
	local TIER_COL = { Color3.fromRGB(205, 127, 74), Color3.fromRGB(150, 160, 178), Color3.fromRGB(232, 176, 48) }
	local head = block(P, 64, 0)
	local achTitle = UI.label(head, "", 18, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(18, 11), Size = UDim2.new(1, -340, 0, 22) })
	UI.label(head, "Every tier you reach pays out. Claim it here.", 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 35), Size = UDim2.new(1, -340, 0, 16) })
	local achFill = meter(head, UDim2.new(1, -278, 0, 38), UDim2.fromOffset(260, 8))
	local achPct = UI.label(head, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.brand, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0, 14), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(260, 16) })
	local filter = "all"
	pills(P, { { id = "all", text = "All" }, { id = "ready", text = "Ready to claim" }, { id = "going", text = "In progress" }, { id = "done", text = "Complete" } }, "all", 1, function(id)
		filter = id
		refreshAch()
	end)
	local listF = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = P })
	UI.list(listF, nil, 8)
	local Achieve = Shared.Remotes:WaitForChild("Achieve", 10)
	local achCards = {}
	for i, a in ipairs(Q.ACHIEVEMENTS) do
		local f = block(listF, 68, i)
		local sq = UI.new("Frame", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.white, Parent = f })
		UI.corner(sq, 12)
		local mIcon = UI.icon(sq, ICON[a.icon] or ICON.star, 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		UI.label(f, a.name, 15, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(68, 13), Size = UDim2.fromOffset(300, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local desc = UI.label(f, "", 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(68, 35), Size = UDim2.fromOffset(300, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local pipList = {}
		for k = 1, 3 do
			local pip = UI.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 384 + (k - 1) * 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink3, Parent = f })
			UI.corner(pip, ROUND)
			pipList[k] = pip
		end
		local tierTag = UI.label(f, "", 11, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.new(0, 444, 0.5, -8), Size = UDim2.fromOffset(74, 16) })
		local fill = meter(f, UDim2.new(0, 524, 0.5, -4), UDim2.new(1, -524 - 316, 0, 8))
		local prog = UI.label(f, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.new(1, -304, 0.5, -9), Size = UDim2.fromOffset(128, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		local btn, btnText = UI.button(f, {
			text = "Claim", kind = "ghost", size = UDim2.fromOffset(150, 40), pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10,
			onClick = function(b)
				local c = achCards[a.id]
				if not c.ready then UI.shake(b) return end
				local ok, res, info = pcall(Achieve.InvokeServer, Achieve, "claim", a.id)
				if ok and res then
					UI.sound("Fanfare")
					mtoast(a.name .. " " .. Q.TIER_NAMES[info.tier] .. "! +$" .. UI.commas(info.cash) .. (info.tag and (". New tag: " .. info.tag) or ""), "trophy")
				else
					mtoast(ok and tostring(info) or "Try again", "close", true)
					UI.shake(b)
				end
				task.delay(0.3, refreshAch)
			end,
		})
		-- round 39: the tag this achievement unlocks; tap to wear it (or take it off)
		local tagChip = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(170, 18), Position = UDim2.fromOffset(384, 46), BackgroundColor3 = T.ink3, Parent = f })
		UI.corner(tagChip, 9)
		local tagText = UI.label(tagChip, "", 11, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextTruncate = Enum.TextTruncate.AtEnd })
		tagChip.Activated:Connect(function()
			local c = achCards[a.id]
			if not c.tagOk then UI.shake(tagChip) mtoast("Claim " .. a.name .. " Bronze to unlock this tag", "close", true) return end
			local ok, res, why = pcall(Achieve.InvokeServer, Achieve, "tag", c.wearing and "" or a.id)
			if ok and res then
				UI.sound("select")
				mtoast(c.wearing and "Tag taken off" or ("Now wearing " .. Q.TITLES[a.id]), "medal")
			else
				mtoast(ok and tostring(why) or "Try again", "close", true)
			end
			task.delay(0.3, refreshAch)
		end)
		achCards[a.id] = { a = a, frame = f, mIcon = mIcon, pips = pipList, tierTag = tierTag, desc = desc, fill = fill, prog = prog, btn = btn, btnText = btnText, order = i, tagChip = tagChip, tagText = tagText }
	end

	refreshAch = function()
		local h = workHotel()
		if not h then return end
		local st = hotelQuests(h)
		local isOwner = h:GetAttribute("Owner") == player.UserId
		local totalTiers, claimedTiers, ready = 0, 0, 0
		for _, a in ipairs(Q.ACHIEVEMENTS) do
			local c = achCards[a.id]
			local v = a.state and Q.stateValue(h, a.state) or (tonumber(st.life[a.stat]) or 0)
			local claimed = math.clamp(tonumber(st.ach[a.id]) or 0, 0, 3)
			local reached = Q.tierOf(a, v)
			totalTiers += 3
			claimedTiers += claimed
			for k, pip in ipairs(c.pips) do
				pip.BackgroundColor3 = k <= claimed and TIER_COL[k] or T.ink3
			end
			c.mIcon.ImageTransparency = claimed > 0 and 0 or 0.4
			local tagName = string.upper(Q.TITLES[a.id] or a.name)
			c.tagOk = claimed > 0 and isOwner
			c.wearing = st.title == a.id
			c.tagText.Text = c.wearing and ("WEARING: " .. tagName) or claimed > 0 and ("WEAR TAG: " .. tagName) or ("TAG: " .. tagName)
			c.tagText.TextColor3 = claimed > 0 and Color3.new(1, 1, 1) or T.muted
			c.tagChip.BackgroundColor3 = claimed > 0 and (Q.TAG_COL[claimed] or TIER_COL[claimed]) or T.ink3
			c.tagChip.BackgroundTransparency = (claimed > 0 and not c.wearing) and 0.35 or 0
			local nextTier = claimed + 1
			local kind
			if nextTier > 3 then
				kind = "done"
				c.tierTag.Text = "COMPLETE"
				c.tierTag.TextColor3 = T.greenDk
				c.desc.Text = string.format(a.text, Q.fmt(a, a.tiers[3]))
				c.prog.Text = "All claimed"
				c.fill.Size = UDim2.fromScale(1, 1)
				c.fill.BackgroundColor3 = T.green
				c.btnText.Text = "Done"
				UI.setKind(c.btn, "ghost")
				c.ready = false
			else
				local goal = a.tiers[nextTier]
				c.tierTag.Text = string.upper(Q.TIER_NAMES[nextTier])
				c.tierTag.TextColor3 = TIER_COL[nextTier]
				c.desc.Text = string.format(a.text, Q.fmt(a, goal))
				c.prog.Text = Q.fmt(a, math.min(v, goal)) .. " / " .. Q.fmt(a, goal)
				UI.tween(c.fill, 0.5, { Size = UDim2.fromScale(math.clamp(v / goal, 0, 1), 1) }, Enum.EasingStyle.Quint)
				c.ready = reached >= nextTier and isOwner
				local cash = a.cash[nextTier] or 0
				if reached >= nextTier then
					kind = "ready"
					ready += 1
					c.fill.BackgroundColor3 = T.green
					c.btnText.Text = isOwner and ("Claim $" .. UI.commas(cash)) or "Owner claims"
					UI.setKind(c.btn, isOwner and "green" or "ghost")
				else
					kind = "going"
					c.fill.BackgroundColor3 = T.brand
					c.btnText.Text = "$" .. UI.commas(cash)
					UI.setKind(c.btn, "ghost")
				end
			end
			c.frame.LayoutOrder = (kind == "ready" and 0 or kind == "going" and 100 or 200) + c.order
			c.frame.Visible = filter == "all" or filter == kind
		end
		achTitle.Text = claimedTiers .. " of " .. totalTiers .. " tiers claimed"
		achPct.Text = math.floor(claimedTiers / totalTiers * 100 + 0.5) .. "% complete"
		UI.tween(achFill, 0.5, { Size = UDim2.fromScale(claimedTiers / totalTiers, 1) })
		local badge = dock.badges.achievements
		if badge then
			if ready > 0 and not badge.Visible then UI.pop(badge, 0.4) end
			badge.Visible = ready > 0
			badge.Text = tostring(ready)
		end
	end
end

---------------------------------------------------------------- settings page
-- Categories down the left, the chosen one's rows on the right.
do
	local P = pages.settings
	local SET_CATS = {
		{ id = "sound", text = "Sound" }, { id = "gameplay", text = "Gameplay" }, { id = "display", text = "Display" },
		{ id = "controls", text = "Controls" }, { id = "save", text = "Save" },
	}
	local root = pageRoot(P)
	local nav = column(root, UDim2.new(), UDim2.new(0, 200, 0, 0), 4)
	local content = UI.new("Frame", { Size = UDim2.new(1, -216, 0, 0), Position = UDim2.fromOffset(216, 0), AutomaticSize = Y, BackgroundTransparency = 1, Parent = root })
	local setGroups, navBtns = {}, {}
	local function pick(id)
		for k, g in pairs(setGroups) do g.Visible = k == id end
		for k, b in pairs(navBtns) do
			b.BackgroundColor3 = k == id and T.brandSoft or T.ink
			b.BackgroundTransparency = k == id and 0 or 1
			b.TextColor3 = k == id and T.brand or T.muted
		end
	end
	for i, c in ipairs(SET_CATS) do
		local b = UI.new("TextButton", { Text = c.text, TextSize = 15, FontFace = UI.F.heavy, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.ink, LayoutOrder = i, Parent = nav })
		UI.corner(b, 12)
		UI.pad(b, 16, 0, 8, 0)
		b.Activated:Connect(function()
			UI.sound("Tab")
			pick(c.id)
		end)
		navBtns[c.id] = b
		local g = UI.new("Frame", { Name = "Set_" .. c.id, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, Visible = false, Parent = content })
		UI.list(g, nil, 6)
		setGroups[c.id] = g
	end
	pick("sound")

	local function settingBase(group, _, text, sub, order)
		local f = block(group, 58, order)
		UI.label(f, text, 15, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -420, 0, 20) })
		UI.label(f, sub, 12, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 31), Size = UDim2.new(1, -420, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		return f
	end
	local function settingToggle(group, icon, text, sub, on, callback, order)
		local f = settingBase(group, icon, text, sub, order)
		local _, set = UI.toggle(f, on, callback, { pos = UDim2.new(1, -18, 0.5, 0), anchor = Vector2.new(1, 0.5) })
		return set
	end
	local function settingRange(group, icon, text, sub, min, max, step, value, fmt, callback, order)
		local f = settingBase(group, icon, text, sub, order)
		local num = UI.label(f, fmt(value), 14, { FontFace = UI.F.heavy, TextColor3 = T.brand, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(56, 20) })
		UI.slider(f, min, max, value, function(v)
			num.Text = fmt(v)
			callback(v)
		end, { size = UDim2.fromOffset(300, 28), pos = UDim2.new(1, -84, 0.5, 0), step = step }).AnchorPoint = Vector2.new(1, 0.5)
	end
	local function pct(v) return math.floor(v + 0.5) .. "%" end
	local function settingSlider(group, icon, text, sub, value, callback, order)
		settingRange(group, icon, text, sub, 0, 100, 5, value, pct, callback, order)
	end

	-- sound: volumes (Audio reads MusicVol / SfxVol, 0..100) and the old on/off switches
	local function vol(attr, offAttr)
		local v = player:GetAttribute(attr)
		if v == nil then v = player:GetAttribute(offAttr) and 0 or 100 end
		return v
	end
	settingSlider(setGroups.sound, nil, "Music", "The hotel's background music", vol("MusicVol", "MusicOff"), function(v)
		player:SetAttribute("MusicVol", v)
		player:SetAttribute("MusicOff", v <= 0 or nil)
	end, 1)
	settingSlider(setGroups.sound, nil, "Sound effects", "Bells, cash, doors and footsteps", vol("SfxVol", "SfxOff"), function(v)
		player:SetAttribute("SfxVol", v)
		player:SetAttribute("SfxOff", v <= 0 or nil)
	end, 2)
	settingToggle(setGroups.sound, nil, "Menu sounds", "Clicks and whooshes on buttons", player:GetAttribute("UiSfxOff") ~= true, function(on)
		player:SetAttribute("UiSfxOff", not on or nil)
	end, 3)

	-- gameplay
	if player:GetAttribute("Sprint") == nil then player:SetAttribute("Sprint", true) end
	settingToggle(setGroups.gameplay, nil, "Sprint", "Hold Shift to run", player:GetAttribute("Sprint") ~= false, function(on)
		player:SetAttribute("Sprint", on)
	end, 1)
	settingToggle(setGroups.gameplay, nil, "Chapter goals", "The goals panel on the right of the screen", player:GetAttribute("HideQuests") ~= true, function(on)
		player:SetAttribute("HideQuests", not on or nil)
	end, 2)
	settingToggle(setGroups.gameplay, nil, "Review pop-ups", "A card when a guest leaves a review", player:GetAttribute("HideReviews") ~= true, function(on)
		player:SetAttribute("HideReviews", not on or nil)
	end, 3)
	settingToggle(setGroups.gameplay, nil, "End of day report", "The summary card when a day ends", player:GetAttribute("HideDaySummary") ~= true, function(on)
		player:SetAttribute("HideDaySummary", not on or nil)
	end, 4)
	settingToggle(setGroups.gameplay, nil, "Money pop-ups", "+$ and XP numbers that float up", player:GetAttribute("HidePops") ~= true, function(on)
		player:SetAttribute("HidePops", not on or nil)
	end, 5)
	do
		local tutRow = settingBase(setGroups.gameplay, nil, "Tutorial", "Play the guided first day again", 6)
		UI.button(tutRow, {
			text = "Replay", kind = "ink", size = UDim2.fromOffset(120, 36), pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10,
			onClick = function()
				Shared.Remotes.TutSkip:FireServer("replay")
				player:SetAttribute("MenuWant", "close")
			end,
		})
	end

	-- display: client-side only
	settingToggle(setGroups.display, nil, "Guest bubbles", "Status cards over guests' heads", true, function(on)
		player:SetAttribute("HideBubbles", not on)
	end, 1)
	local pedCon
	settingToggle(setGroups.display, nil, "Sidewalk walkers", "People strolling past outside", true, function(on)
		if pedCon then pedCon:Disconnect() pedCon = nil end
		local function apply(m)
			if m:IsA("Model") and m.Parent and m.Parent.Name == "Guests" and not m:GetAttribute("Guest") and not m:GetAttribute("Staff") then
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 0 or 1 end
				end
			end
		end
		for _, d in ipairs(workspace:GetDescendants()) do apply(d) end
		if not on then
			pedCon = workspace.DescendantAdded:Connect(function(d) task.defer(apply, d) end)
		end
	end, 2)
	settingToggle(setGroups.display, nil, "Room signs", "The floating signs over rooms that need you", player:GetAttribute("HideRoomSigns") ~= true, function(on)
		player:SetAttribute("HideRoomSigns", not on or nil)
	end, 3)
	settingRange(setGroups.display, nil, "Field of view", "How wide the camera sees", 55, 100, 1, player:GetAttribute("FOV") or 70,
		function(v) return tostring(math.floor(v + 0.5)) end, function(v) player:SetAttribute("FOV", v) end, 4)
	settingToggle(setGroups.display, nil, "Shadows", "Turn off for a smoother game on slow devices", player:GetAttribute("ShadowsOff") ~= true, function(on)
		player:SetAttribute("ShadowsOff", not on or nil)
	end, 5)
	settingRange(setGroups.display, nil, "Button size", "The size of the E / tap buttons over things", 60, 140, 5, player:GetAttribute("PromptSize") or 100,
		pct, function(v) player:SetAttribute("PromptSize", v) end, 6)

	-- controls: the build camera, then what every key does
	settingRange(setGroups.controls, nil, "Build camera speed", "How fast right-drag (or twisting) turns the view", 25, 200, 5, player:GetAttribute("LookSens") or 100,
		pct, function(v) player:SetAttribute("LookSens", v) end, 1)
	settingToggle(setGroups.controls, nil, "Invert build camera", "Drag up to look down", player:GetAttribute("LookInvert") == true, function(on)
		player:SetAttribute("LookInvert", on or nil)
	end, 2)
	local KEYS = {
		{ "W A S D", "Walk" }, { "Shift", "Sprint" }, { "E", "Use what's in front of you" }, { "F", "Talk to a guest, sit down" },
		{ "B", "Build mode" }, { "M", "Hotel menu" }, { "T", "Staff" }, { "R", "Research" }, { "U", "Upgrades" },
		{ "Q / E", "Orbit in build mode" }, { "Right drag", "Turn the build camera" }, { "1 - 5", "Answer in a conversation" },
		{ "Click + drag", "Lay a row of walls" }, { "/commands", "Every chat command" },
	}
	local keyCard = block(setGroups.controls, 0, 3)
	UI.pad(keyCard, 18, 12, 18, 12)
	local kg = Instance.new("UIGridLayout")
	kg.CellSize = UDim2.new(0.5, -10, 0, 30)
	kg.CellPadding = UDim2.fromOffset(20, 4)
	kg.SortOrder = Enum.SortOrder.LayoutOrder
	kg.Parent = keyCard
	for i, k in ipairs(KEYS) do
		local f = UI.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, Parent = keyCard })
		local cap = UI.new("TextLabel", {
			Text = k[1], TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.cream, BackgroundColor3 = T.white,
			Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = f,
		})
		UI.corner(cap, 6)
		UI.pad(cap, 8, 0, 8, 0)
		UI.stroke(cap, 1, T.line, 0)
		UI.label(f, k[2], 13, { FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
	end

	-- save: how saving works, and starting over
	settingBase(setGroups.save, nil, "Saving", "Your hotel saves by itself every 5 minutes and when you leave", 1)
	local resetRow = settingBase(setGroups.save, nil, "Reset progress", "Start this save over from scratch. This can't be undone", 2)
	UI.button(resetRow, {
		text = "Reset", kind = "red", size = UDim2.fromOffset(120, 36), pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10,
		onClick = function(b)
			if not b:GetAttribute("Armed") then
				b:SetAttribute("Armed", true)
				b.Row.Label.Text = "Sure?"
				UI.shake(b)
				task.delay(3, function() if b.Parent then b:SetAttribute("Armed", nil) b.Row.Label.Text = "Reset" end end)
				return
			end
			b:SetAttribute("Armed", nil)
			b.Row.Label.Text = "Reset"
			Coop:FireServer("reset")
			setOpen(false)
		end,
	})
end

---------------------------------------------------------------- tabs + open/close

local activeTab = "hotel"
local headTitle, headSub, headIcon = body.Head:FindFirstChild("Title"), body.Head:FindFirstChild("Sub"), body.Head:FindFirstChildWhichIsA("ImageLabel", true)
local open = false
showTab = function(id)
	local was = activeTab
	activeTab = id
	for _, t in ipairs(TABS) do
		if t.id == id then
			if headTitle then headTitle.Text = t.title end
			if headSub then headSub.Text = t.sub end
			if headIcon then headIcon.Image = t.icon end
		end
	end
	if dock.mark then dock.mark(id) end
	for k, p in pairs(pages) do p.Visible = k == id end
	-- the lab (ResearchUI) runs while its tab is showing
	player:SetAttribute("ResearchOpen", (open and id == "research") or nil)
	local page = pages[id]
	if page:IsA("ScrollingFrame") then
		page.CanvasPosition = Vector2.zero
		UI.stagger(page, 0.03)
	end
	-- the page slides in from the side it's on
	if was ~= id then
		local from = 1
		for i, t in ipairs(TABS) do
			if t.id == was then from = i end
		end
		local to = 1
		for i, t in ipairs(TABS) do
			if t.id == id then to = i end
		end
		local base = page:GetAttribute("Home") or page.Position
		page:SetAttribute("Home", base)
		page.Position = base + UDim2.fromOffset(to > from and 40 or -40, 0)
		UI.tween(page, 0.3, { Position = base }, Enum.EasingStyle.Quint)
	end
	if id == "hotel" then refreshHotel() refreshAll() end
	if id == "staff" then refreshHire() end
	if id == "achievements" then refreshAch() end
end

task.spawn(function()
	while true do
		task.wait(1)
		refreshAll() -- invite buttons time out, partner counts change
		if open and activeTab == "hotel" then refreshHotel() end
		if open and activeTab == "staff" then refreshHire() end
		refreshAch() -- keeps the dock's badge honest too
	end
end)
player:GetAttributeChangedSignal("Cash"):Connect(function() if open and activeTab == "staff" then refreshHire() end end)

setOpen = function(on)
	if on == open then return end
	open = on
	if not on and dock.mark then dock.mark(nil) end
	if on then
		fit()
		dim.Visible = true
		UI.tween(dim, 0.3, { BackgroundTransparency = 0.5 })
		UI.blur(true, 12)
		wrap.Visible = true
		UI.open(holder, { rise = 24, from = 0.92 })
		tabs.select(activeTab, true)
		showTab(activeTab)
		player:SetAttribute("MenuOpen", true)
	else
		UI.tween(dim, 0.25, { BackgroundTransparency = 1 }).Completed:Connect(function() if not open then dim.Visible = false end end)
		UI.blur(false)
		UI.close(holder, function() if not open then wrap.Visible = false end end)
		player:SetAttribute("MenuOpen", nil)
		player:SetAttribute("ResearchOpen", nil)
	end
end
-- round 32: a click or tap outside the panel closes the menu (never one on the panel itself)
dim.InputBegan:Connect(function(input)
	if not open then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local p, a, s = input.Position, holder.AbsolutePosition, holder.AbsoluteSize
	if p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y then return end
	setOpen(false)
end)
UIS.InputBegan:Connect(function(input, processed)
	if processed or (input.KeyCode ~= Enum.KeyCode.M and input.KeyCode ~= Enum.KeyCode.DPadLeft) then return end
	if player:GetAttribute("Building") or not player:GetAttribute("Slot") or (not open and UI.locked("hotel")) then return end
	setOpen(not open)
end)

---------------------------------------------------------------- the left dock (round 10: replaces the Menu button)

local dockGui = pgui:FindFirstChild("Dock")
if dockGui then dockGui:Destroy() end
-- above the Menu (20) and Research (30) screens so it stays usable while they're open
dockGui = UI.new("ScreenGui", {
	Name = "Dock", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 32, Parent = pgui,
})
dockGui.Enabled = false -- round 15: the side dock is retired; the bottom bar in BuildClient holds the menu buttons now
local DOCK = {
	{ id = "hotel", text = "Hotel", icon = "hotel", top = Color3.fromRGB(255, 220, 132), bot = Color3.fromRGB(204, 138, 42), tip = "Your hotel and its level  (M)" },
	{ id = "staff", text = "Staff", icon = "staff", top = Color3.fromRGB(146, 234, 140), bot = Color3.fromRGB(38, 156, 80), tip = "Hire staff" },
	{ id = "research", text = "Research", icon = "research", top = Color3.fromRGB(227, 238, 255), bot = Color3.fromRGB(72, 141, 212), tip = "Research  (R)" },
	{ id = "achievements", text = "Awards", icon = "trophy", top = Color3.fromRGB(255, 196, 120), bot = Color3.fromRGB(196, 96, 40), tip = "Achievements" },
	{ id = "phone", text = "Phone", icon = "phone", top = Color3.fromRGB(140, 214, 255), bot = Color3.fromRGB(46, 100, 200), tip = "Your phone  (P)" },
	{ id = "shop", text = "Store", icon = "shop", top = Color3.fromRGB(255, 186, 214), bot = Color3.fromRGB(196, 64, 124), tip = "Store" },
	{ id = "settings", text = "Settings", icon = "settings", top = Color3.fromRGB(211, 215, 220), bot = Color3.fromRGB(111, 117, 126), tip = "Settings" },
}
local SLOT_W, SLOT_H, GAP, PAD = 66, 74, 2, 8 -- round 10e: more compact
local dockWrap = UI.new("Frame", { Name = "Dock", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -200, 0.5, 0), BackgroundTransparency = 1, Visible = false, Parent = dockGui })
local dockScale = Instance.new("UIScale")
dockScale.Name = "AutoScale"
dockScale.Parent = dockWrap
local pill = UI.new("Frame", { Name = "Pill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, BackgroundTransparency = 0.1, Parent = dockWrap })
UI.corner(pill, 34)
UI.grad(pill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(221, 224, 228), 90)
UI.stroke(pill, 2, T.gold, 0.5)
UI.pad(pill, PAD, PAD, PAD, PAD)
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(SLOT_W, SLOT_H)
grid.CellPadding = UDim2.fromOffset(GAP, GAP)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.FillDirection = Enum.FillDirection.Horizontal
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = pill

-- tooltips open to the right of the dock (it hugs the left edge)
local tipPill = UI.new("TextLabel", {
	Name = "Tip", TextSize = 15, FontFace = UI.F.heavy, BackgroundColor3 = T.ink, BackgroundTransparency = 0.05, AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(), AnchorPoint = Vector2.new(0, 0.5), Visible = false, ZIndex = 10, Parent = dockGui,
})
UI.corner(tipPill, 8)
UI.pad(tipPill, 10, 6, 10, 6)
UI.stroke(tipPill, 1, T.gold, 0.4)
function dock.tip(slot, text)
	if not slot then tipPill.Visible = false return end
	tipPill.Text = text
	-- AbsolutePosition doesn't count Roblox's top bar inset; measuring from the dock's own screen does
	local origin = dockGui.AbsolutePosition
	tipPill.Position = UDim2.fromOffset(dockWrap.AbsolutePosition.X - origin.X + dockWrap.AbsoluteSize.X + 10, slot.AbsolutePosition.Y - origin.Y + slot.AbsoluteSize.Y * 0.36)
	tipPill.Visible = true
	UI.pop(tipPill, 0.8, 0.2)
end

local function dockPress(id)
	-- round 10e: the phone and the store live in Phone
	if id == "phone" or id == "shop" then
		if open then setOpen(false) end
		player:SetAttribute("PhoneWant", id == "shop" and "store" or "toggle")
		return
	end
	if open and activeTab == id then setOpen(false) return end
	if open then
		tabs.select(id)
	else
		activeTab = id
		setOpen(true)
	end
end

-- other scripts open a page by setting the player attribute MenuWant (the HUD's top bar does)
player:GetAttributeChangedSignal("MenuWant"):Connect(function()
	local want = player:GetAttribute("MenuWant")
	if not want then return end
	player:SetAttribute("MenuWant", nil)
	if want == "close" then setOpen(false) return end
	-- the phone and the store live in Phone, not in these pages
	if want == "phone" or want == "shop" then
		if player:GetAttribute("Building") or not player:GetAttribute("Slot") then return end
		dockPress(want)
		return
	end
	if player:GetAttribute("Building") or not player:GetAttribute("Slot") or not pages[want] or UI.locked(want) then return end
	if not (open and activeTab == want) then dockPress(want) end
end)

-- round 15: T and Y open staff and rewards (the bottom bar shows them as key hints)
UIS.InputBegan:Connect(function(input, processed)
	local kc = input.KeyCode
	if processed or (kc ~= Enum.KeyCode.T and kc ~= Enum.KeyCode.Y) then return end
	if player:GetAttribute("Building") or not player:GetAttribute("Slot") or UI.locked(kc == Enum.KeyCode.T and "staff" or "achievements") then return end
	dockPress(kc == Enum.KeyCode.T and "staff" or "achievements")
end)

for i, d in ipairs(DOCK) do
	local slot = UI.new("TextButton", { Name = "Btn_" .. d.id, Text = "", BackgroundTransparency = 1, LayoutOrder = i, Parent = pill })
	-- the open page gets a brass ring round its ball
	local glow = UI.new("Frame", { Name = "Glow", Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0.5, 0, 0, -4), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = slot })
	UI.corner(glow, 33)
	local glowStroke = UI.stroke(glow, 3, T.gold, 1)
	local ball = UI.new("Frame", { Name = "Ball", Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = slot })
	UI.corner(ball, 28)
	UI.grad(ball, d.top, d.bot, 90)
	UI.stroke(ball, 3, d.bot:Lerp(Color3.new(0, 0, 0), 0.5), 0)
	local gloss = UI.new("Frame", { Size = UDim2.new(0.66, 0, 0.3, 0), Position = UDim2.fromScale(0.5, 0.07), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.68, Parent = ball })
	UI.corner(gloss, 20)
	local ic = UI.icon(ball, ICON[d.icon], 40, { Name = "Icon", Position = UDim2.fromScale(0.5, 0.54), AnchorPoint = Vector2.new(0.5, 0.5) })
	-- chunky outlined label over the bottom of the ball
	local label = UI.label(slot, d.text, 14, { Name = "Label", FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-8, 47), Size = UDim2.new(1, 16, 0, 20), ZIndex = 3 })
	UI.textStroke(label, 3, 0).Color = Color3.fromRGB(14, 21, 28)
	local badge = UI.new("TextLabel", {
		Name = "Badge", Text = "!", TextSize = 16, FontFace = UI.F.black, TextColor3 = T.cream, BackgroundColor3 = T.red,
		Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0.5, 22, 0, 6), AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 5, Parent = slot,
	})
	UI.corner(badge, 12)
	UI.stroke(badge, 2, Color3.fromRGB(110, 20, 34), 0)
	local bar
	if d.id == "research" then
		bar = UI.new("Frame", { Name = "Progress", Size = UDim2.fromOffset(48, 6), Position = UDim2.new(0.5, 0, 0, 67), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.ink2, Visible = false, Parent = slot })
		UI.corner(bar, 4)
		UI.stroke(bar, 1.5, Color3.fromRGB(14, 21, 28), 0)
		local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
		UI.corner(fill, 4)
		UI.grad(fill, Color3.fromRGB(241, 247, 255), T.violetDk, 90)
	end
	-- motion: the ball lifts and the icon wobbles on hover, squashes on press
	local sc = UI.scaleOf(ball)
	local over = false
	slot.MouseEnter:Connect(function()
		over = true
		dock.tip(slot, d.tip)
		UI.tween(sc, 0.2, { Scale = 1.1 }, Enum.EasingStyle.Back)
		UI.tween(ic, 0.1, { Rotation = -10 }, Enum.EasingStyle.Quad).Completed:Once(function()
			UI.tween(ic, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
		end)
		UI.sound("Hover")
	end)
	slot.MouseLeave:Connect(function()
		over = false
		dock.tip(nil)
		UI.tween(sc, 0.2, { Scale = 1 })
	end)
	slot.MouseButton1Down:Connect(function() UI.tween(sc, 0.08, { Scale = 0.88 }, Enum.EasingStyle.Quad) end)
	slot.MouseButton1Up:Connect(function() UI.tween(sc, 0.3, { Scale = over and 1.1 or 1 }, Enum.EasingStyle.Back) end)
	slot.Activated:Connect(function()
		UI.sound("Click")
		dockPress(d.id)
	end)
	dock.buttons[d.id] = { slot = slot, ball = ball, glow = glowStroke, icon = ic, bar = bar }
	dock.badges[d.id] = badge
	if d.id == "phone" then
		local function unread()
			local n = player:GetAttribute("PhoneUnread")
			badge.Visible = n ~= nil
			badge.Text = n and tostring(math.min(n, 9)) or ""
		end
		player:GetAttributeChangedSignal("PhoneUnread"):Connect(unread)
		unread()
	end
end

-- which page is open: its ball gets the brass ring
function dock.mark(id)
	if player:GetAttribute("ResearchOpen") and not id then id = "research" end
	for bid, b in pairs(dock.buttons) do
		UI.tween(b.glow, 0.2, { Transparency = bid == id and 0 or 1 })
	end
end
player:GetAttributeChangedSignal("ResearchOpen"):Connect(function()
	dock.mark(open and activeTab or nil)
end)

-- fit the left edge between Roblox's top bar and the toasts (bottom left): one column on PC,
-- two or three on short screens; never bigger than the rest of the HUD
local function layoutDock()
	local size = dockGui.AbsoluteSize
	if size.Y < 10 then return end
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(vp.X / 1600, vp.Y / 900), UIS.TouchEnabled and 0.55 or 0.7, 1.25) -- the HUD's own scale
	-- round 10c: the hotel card and cash moved to the top bar; toasts use the bottom-left corner
	local top = math.max(GuiService.TopbarInset.Height, 36) + 16
	-- round 12 phones: start below the top bar (Client's phoneLayout publishes its bottom) and stay small
	local phoneBar = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and dockGui.Parent and dockGui.Parent:FindFirstChild("HUD")
	phoneBar = phoneBar and phoneBar:GetAttribute("PhoneBarBottom")
	if phoneBar then
		top = math.max(top, phoneBar + 10)
		k = math.min(k, 0.45)
	end
	local bottom = size.Y - 16 - 132 * k
	-- phones: the thumbstick owns the bottom-left, so the dock stays in the upper part of the edge
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then bottom = math.min(bottom, size.Y * 0.6) end
	-- centred on the screen's height (phones: centred in the space above the thumbstick)
	local mid = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and (top + bottom) / 2 or size.Y / 2
	local avail = math.max(2 * math.min(mid - top, bottom - mid), 60)
	local pick
	for cols = 1, 3 do
		local rows = math.ceil(#DOCK / cols)
		local w = cols * SLOT_W + (cols - 1) * GAP + PAD * 2
		local h = rows * SLOT_H + (rows - 1) * GAP + PAD * 2
		local s = math.min(avail / h, k)
		if not pick or s > pick.s then pick = { cols = cols, w = w, h = h, s = s } end
		if s >= 0.85 * k then break end
	end
	grid.FillDirectionMaxCells = pick.cols
	dockWrap.Size = UDim2.fromOffset(pick.w, pick.h)
	dockScale.Scale = pick.s
	dock.home = UDim2.fromOffset(16, mid)
	dock.away = UDim2.fromOffset(-pick.w * pick.s - 30, mid)
	if dock.shown then dockWrap.Position = dock.home end
end
dockGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutDock)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutDock)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutDock)
layoutDock()
task.spawn(function()
	local h = pgui:WaitForChild("HUD", 30)
	if h then h:GetAttributeChangedSignal("PhoneBarBottom"):Connect(layoutDock) end
end)

-- the dock hides while building (build mode has its own Done button) and on the title screen
local function refreshDock()
	local show = not player:GetAttribute("Building") and player:GetAttribute("Slot") ~= nil and player:GetAttribute("Plot") ~= nil
	if show ~= dock.shown then
		dock.shown = show
		layoutDock()
		if show then
			dockWrap.Visible = true
			dockWrap.Position = dock.away
			UI.tween(dockWrap, 0.55, { Position = dock.home }, Enum.EasingStyle.Back)
			-- the screen can still be settling when the dock first shows (title screen, loading): fit it again
			task.delay(0.7, function() if dock.shown then layoutDock() end end)
			for i, d in ipairs(DOCK) do
				local s = UI.scaleOf(dock.buttons[d.id].ball)
				s.Scale = 0.4
				UI.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.12 + i * 0.05)
			end
		else
			UI.tween(dockWrap, 0.3, { Position = dock.away }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(function()
				if not dock.shown then dockWrap.Visible = false end
			end)
		end
	end
	if not show then setOpen(false) end
end
for _, a in ipairs({ "Building", "Slot", "Plot" }) do player:GetAttributeChangedSignal(a):Connect(refreshDock) end
refreshDock()

-- badges: Staff when you can hire someone, Research when the lab is idle and something is ready
local function setBadge(id, on)
	local b = dock.badges[id]
	if on ~= b.Visible then
		b.Visible = on
		if on then UI.pop(b, 0.3, 0.4) end
	end
end
local pulse = 0
task.spawn(function()
	while dockGui.Parent do
		task.wait(1)
		local h = workHotel()
		if h and dock.shown then
			local cash = player:GetAttribute("Cash") or 0
			local canHire = false
			for _, def in ipairs(C.STAFF) do
				local n = h:GetAttribute(def.attr) or 0
				if n < def.max and Levels.staffOk(h, def.id, n + 1) and cash >= def.prices[n + 1] then canHire = true end
			end
			setBadge("staff", canHire)
			local st = Research.state(h)
			local cur = st.cur and Research.BY_ID[st.cur]
			local ready = false
			if not cur then
				for _, node in ipairs(Research.NODES) do
					if Research.available(st, node.id) and Levels.researchOk(h, node.id) and cash >= node.cost then ready = true break end
				end
			end
			setBadge("research", ready)
			local bar = dock.buttons.research.bar
			bar.Visible = cur ~= nil
			if cur then
				local len = st.len or Research.duration(st, cur.id)
				local left = math.max((st.ends or os.time()) - os.time(), 0)
				UI.tween(bar.Fill, 0.9, { Size = UDim2.fromScale(math.clamp(1 - left / math.max(len, 1), 0, 1), 1) }, Enum.EasingStyle.Linear)
			end
			-- a little nudge now and then on anything waiting for you
			pulse += 1
			if pulse % 4 == 0 then
				for _, id in ipairs({ "staff", "research" }) do
					if dock.badges[id].Visible then UI.pop(dock.badges[id], 1.35, 0.4) end
				end
			end
		end
	end
end)

---------------------------------------------------------------- invite cards

local cards = UI.new("Frame", { Size = UDim2.fromOffset(400, 600), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
UI.list(cards, nil, 10, Enum.HorizontalAlignment.Center)
UI.autoScale(cards)

local function inviteCard(d, request)
	local f = UI.new("CanvasGroup", { Size = UDim2.fromOffset(380, 150), BackgroundColor3 = T.ink, Parent = cards })
	UI.corner(f, 18)
	UI.stroke(f, 2, T.gold, 0.2)
	local face = UI.new("ImageLabel", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(16, 16), BackgroundColor3 = T.ink3, BackgroundTransparency = 0, Parent = f })
	UI.corner(face, 32)
	UI.stroke(face, 2, T.gold, 0.2)
	task.spawn(function() face.Image = headshot(d.from) end)
	UI.label(f, (d.name or "Someone") .. (request and " wants to help!" or " invited you!"), 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(94, 18), Size = UDim2.fromOffset(270, 24) })
	UI.label(f, request and "Let them work at your hotel?" or ("Help run " .. (d.hotel or "their hotel")), 14, { FontFace = UI.F.body, TextColor3 = T.gold, Position = UDim2.fromOffset(94, 46), Size = UDim2.fromOffset(270, 18) })
	local done = false
	local function finish(accept)
		if done then return end
		done = true
		Coop:FireServer(request and "allow" or "respond", d.from, accept)
		UI.tween(f, 0.25, { GroupTransparency = 1 }).Completed:Connect(function() f:Destroy() end)
	end
	UI.button(f, { text = request and "Let in" or "Join", kind = "green", size = UDim2.fromOffset(166, 44), pos = UDim2.fromOffset(16, 92), textSize = 17, radius = 12, onClick = function() finish(true) end })
	UI.button(f, { text = "No thanks", kind = "ghost", size = UDim2.fromOffset(166, 44), pos = UDim2.fromOffset(196, 92), textSize = 17, radius = 12, onClick = function() finish(false) end })
	local bar = UI.new("Frame", { Size = UDim2.new(1, -36, 0, 3), Position = UDim2.new(0, 18, 1, -5), BackgroundColor3 = T.gold, Parent = f })
	UI.corner(bar, 2)
	UI.pop(f, 0.6)
	UI.tween(bar, 55, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	task.delay(55, function() if not done then done = true f:Destroy() end end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "coopInvite" then
		inviteCard(d or {})
		UI.sound("Bell")
	elseif kind == "coopRequest" then
		-- round 10e: someone asks to help at your hotel (the same card, answered with "allow")
		inviteCard(d or {}, true)
		UI.sound("Bell")
	elseif kind == "coopMoved" then
		setOpen(false)
	end
end)
