-- StarterPlayerScripts.RAH_Coop: the Menu (round 10c remake) and the left dock.
-- One window (fitted between the dock and the HUD's top bar) with a tab per page: Hotel (name, rating, lifetime
-- numbers, level road, right-now tiles, play together with people in the server, guest reviews), Staff (hire
-- cards and your team), Research (RAH_ResearchUI builds the lab into Page_research), Achievements (RAH.Quests
-- ACHIEVEMENTS, claimed through Remotes.Achieve) and Settings (sound, gameplay, display, controls, save).
-- It closes only on its X or M. Other scripts open a page with the player attribute RAH_MenuWant (a tab id, or
-- "close"); RAH_ResearchOpen is set while the Research tab shows. Invites pop up as cards under the top bar.
-- When you move to another hotel (player attribute RAH_Plot changes) it restarts RAH_Client and RAH_BuildClient
-- so the HUD and build mode follow you there. Server side: RAH_Plots (Remotes.Coop), hiring via Remotes.Build.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local PPS = game:GetService("ProximityPromptService")
local StarterPlayer = game:GetService("StarterPlayer")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local Research = require(RAH:WaitForChild("Research"))
local Levels = require(RAH:WaitForChild("Levels"))
local Q = require(RAH:WaitForChild("Quests"))
local Notify = RAH.Remotes:WaitForChild("Notify")
local Coop = RAH.Remotes:WaitForChild("Coop")
local Build = RAH.Remotes:WaitForChild("Build")
local PLOTS = workspace:WaitForChild("Plots")
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local ps = player:WaitForChild("PlayerScripts")

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
	local k = player:GetAttribute("RAH_Plot")
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

local gui = pgui:FindFirstChild("RAH_Coop")
if gui then gui:Destroy() end
gui = UI.new("ScreenGui", {
	Name = "RAH_Coop", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
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
	local dg = pgui:FindFirstChild("RAH_Dock")
	local dk = dg and dg:FindFirstChild("Dock")
	if dk and dk.Visible then left = 16 + dk.AbsoluteSize.X + 12 end
	local top = 8 + 70 * k + 8
	local availW, availH = size.X - left - 14, size.Y - top - 12
	fitScale.Scale = math.clamp(math.min(availW / W, availH / H), 0.4, 1.15)
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
	{ id = "achievements", text = "Achievements", icon = ICON.trophy, title = "Achievements", sub = "Milestones for your hotel. Claim each tier for cash and XP" },
	{ id = "settings", text = "Settings", icon = ICON.settings, title = "Settings", sub = "Sound, gameplay, controls and your save" },
}
local pages = {}
for _, t in ipairs(TABS) do
	local p
	if t.id == "research" then
		-- RAH_ResearchUI builds the lab in here (its layout starts 64 px down, right under our tab bar)
		p = UI.new("Frame", { Name = "Page_research", Size = UDim2.fromOffset(W, 780), Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, Visible = false, Parent = body })
	else
		p = UI.new("ScrollingFrame", {
			Name = "Page_" .. t.id, Size = UDim2.new(1, -44, 1, -128), Position = UDim2.fromOffset(22, 114), BackgroundTransparency = 1,
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
UI.new("Frame", { Size = UDim2.new(1, -44, 0, 1), Position = UDim2.fromOffset(22, 106), BackgroundColor3 = T.line, BackgroundTransparency = 0.5, Parent = body })

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
	UI.grad(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 216, 232), 90)
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

local P = pages.hotel

-- the hero card: name, level, rating and lifetime numbers
local hero = UI.new("Frame", { Name = "Hero", Size = UDim2.new(1, 0, 0, 176), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, Parent = P })
UI.corner(hero, 18)
UI.grad(hero, Color3.fromRGB(64, 54, 40), Color3.fromRGB(30, 30, 46), 90)
UI.stroke(hero, 2, T.gold, 0.35)
local heroArt = UI.new("Frame", { Size = UDim2.fromOffset(132, 132), Position = UDim2.new(0, 20, 0, 22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = hero })
UI.corner(heroArt, 66)
UI.grad(heroArt, Color3.fromRGB(255, 232, 160), T.goldDk, 90)
UI.stroke(heroArt, 4, Color3.fromRGB(255, 244, 210), 0.15)
UI.icon(heroArt, ICON.hotel, 96, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local heroLevel = UI.new("Frame", { Size = UDim2.fromOffset(96, 30), Position = UDim2.new(0.5, 0, 1, 4), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.ink, Parent = heroArt })
UI.corner(heroLevel, 15)
UI.stroke(heroLevel, 2, T.gold, 0)
local heroLevelText = UI.label(heroLevel, "LEVEL 1", 14, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
local nameBox = UI.new("TextBox", {
	Size = UDim2.new(1, -690, 0, 48), Position = UDim2.fromOffset(170, 24), BackgroundColor3 = T.ink, BackgroundTransparency = 1, Text = "",
	PlaceholderText = "Name your hotel...", PlaceholderColor3 = T.muted, TextSize = 34, FontFace = UI.F.black, TextColor3 = T.cream,
	TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = hero,
})
UI.corner(nameBox, 10)
local nameBoxStroke = UI.stroke(nameBox, 1.5, T.gold, 1)
UI.pad(nameBox, 8, 0, 8, 0)
local nameBtn
nameBox.Focused:Connect(function()
	UI.tween(nameBox, 0.2, { BackgroundTransparency = 0.2 })
	UI.tween(nameBoxStroke, 0.2, { Transparency = 0 })
end)
local function saveName()
	local name = nameBox.Text:gsub("%s+", " "):match("^%s*(.-)%s*$")
	if name == "" then mtoast("Type a name first!", "close", true) return end
	local h = workHotel()
	if h and name == h:GetAttribute("HotelName") then return end
	Coop:FireServer("rename", name)
end
nameBox.FocusLost:Connect(function(enter)
	UI.tween(nameBox, 0.2, { BackgroundTransparency = 1 })
	UI.tween(nameBoxStroke, 0.2, { Transparency = 1 })
	if enter then saveName() end
end)
nameBtn = UI.button(hero, {
	text = "Rename", icon = ICON.paint, iconSize = 20, kind = "ink", size = UDim2.fromOffset(130, 38), pos = UDim2.new(1, -378, 0, 30), anchor = Vector2.new(1, 0), textSize = 15, radius = 11,
	onClick = function()
		if nameBox:IsFocused() then nameBox:ReleaseFocus(true) saveName() else nameBox:CaptureFocus() end
	end,
})
local heroStars = stars(hero, 30, UDim2.fromOffset(176, 84))
local heroRating = UI.label(hero, "", 26, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(336, 82), Size = UDim2.fromOffset(60, 34) })
local heroReviews = UI.label(hero, "", 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(392, 90), Size = UDim2.fromOffset(240, 20) })
local heroLine = UI.label(hero, "", 15, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(176, 126), Size = UDim2.new(1, -560, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
-- lifetime numbers on the right of the hero
local heroTiles = UI.new("Frame", { Size = UDim2.fromOffset(350, 140), Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = hero })
local heroGrid = Instance.new("UIGridLayout")
heroGrid.CellSize = UDim2.fromOffset(170, 64)
heroGrid.CellPadding = UDim2.fromOffset(10, 10)
heroGrid.SortOrder = Enum.SortOrder.LayoutOrder
heroGrid.Parent = heroTiles
local life = {}
for i, d in ipairs({
	{ key = "guests", icon = "guest", text = "guests served" }, { key = "earn", icon = "cash", text = "earned from stays", money = true },
	{ key = "clean", icon = "clean", text = "rooms cleaned" }, { key = "review5", icon = "star", text = "five-star reviews" },
}) do
	local v = tile(heroTiles, d.icon, d.text, i, d.money and Color3.fromRGB(160, 240, 150) or nil)
	life[d.key] = { label = v, money = d.money }
end

---------------------------------------------------------------- round 11: the hotel's grade (RAH.Grades)
local Grades = require(RAH:WaitForChild("Grades"))
local grade = row(P, 186, 2)
UI.grad(grade, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 216, 232), 90)
local gPips = UI.new("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Parent = grade })
-- five floors of a little building, lit up to the current grade
local gFloors = {}
for i = 1, 5 do
	local w = 70 + (5 - i) * 10
	local f = UI.new("Frame", { Size = UDim2.fromOffset(w, 22), Position = UDim2.new(0.5, 0, 1, -(i - 1) * 27), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.ink, Parent = gPips })
	UI.corner(f, 6)
	UI.stroke(f, 1.5, T.line, 0.4)
	local lbl = UI.label(f, tostring(i), 13, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	gFloors[i] = { frame = f, label = lbl }
end
UI.label(grade, "HOTEL GRADE", 13, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(186, 18), Size = UDim2.fromOffset(300, 16) })
local gName = UI.label(grade, "", 28, { FontFace = UI.F.black, Position = UDim2.fromOffset(186, 36), Size = UDim2.fromOffset(420, 34) })
local gLook = UI.label(grade, "", 15, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(186, 72), Size = UDim2.fromOffset(420, 18), TextTruncate = Enum.TextTruncate.AtEnd })
local gNextTitle = UI.label(grade, "", 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(186, 104), Size = UDim2.fromOffset(420, 18) })
local gNextLook = UI.label(grade, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(186, 126), Size = UDim2.fromOffset(420, 36), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
local gReqs = UI.new("Frame", { Size = UDim2.new(1, -820, 0, 150), Position = UDim2.fromOffset(620, 18), BackgroundTransparency = 1, Parent = grade })
UI.list(gReqs, nil, 4)
local gBtn, gBtnText = UI.button(grade, {
	text = "Upgrade", icon = ICON.upgrade, iconSize = 22, kind = "green", size = UDim2.fromOffset(170, 54), pos = UDim2.new(1, -18, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 19, radius = 14,
	onClick = function()
		local ok, r = Build:InvokeServer("grade")
		if not ok then mtoast(r or "Can't upgrade yet", "close", true) end
	end,
})
local function refreshGrade(h)
	local g = Grades.of(h)
	local def = Grades.LIST[g]
	gName.Text = def.name
	gLook.Text = "Grade " .. g .. " of " .. Grades.MAX .. "  -  " .. def.look
	for i, f in ipairs(gFloors) do
		local on = i <= g
		f.frame.BackgroundColor3 = on and T.gold or T.ink
		f.label.TextColor3 = on and Color3.fromRGB(70, 46, 12) or T.muted
	end
	local owner = Players:GetPlayerByUserId(h:GetAttribute("Owner") or 0)
	local list, all, nextDef = Grades.check(h, owner and owner:GetAttribute("Cash") or 0)
	-- redraw the checklist only when it changed (this runs every second while the page is open)
	local key = g .. ":"
	for _, e in ipairs(list) do key ..= e.have .. (e.ok and "+" or "-") end
	if key == gReqs:GetAttribute("Key") then return end
	gReqs:SetAttribute("Key", key)
	for _, c in ipairs(gReqs:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	if not nextDef then
		gNextTitle.Text = "The finest hotel in town"
		gNextLook.Text = "Every grade is unlocked."
		gBtn.Visible = false
		return
	end
	gNextTitle.Text = "Next: " .. nextDef.name
	gNextLook.Text = nextDef.look .. ". " .. nextDef.perk .. "."
	for i, e in ipairs(list) do
		local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i, Parent = gReqs })
		local dot = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = e.ok and T.green or T.ink, Parent = r })
		UI.corner(dot, 8)
		UI.stroke(dot, 1.5, e.ok and T.green or T.line, 0.2)
		UI.label(r, e.text, 15, { FontFace = UI.F.heavy, TextColor3 = e.ok and T.cream or T.muted, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -110, 1, 0) })
		UI.label(r, e.have, 14, { FontFace = UI.F.heavy, TextColor3 = e.ok and T.green or T.red, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1) })
	end
	local mine = h:GetAttribute("Owner") == player.UserId
	gBtn.Visible = mine
	UI.setKind(gBtn, all and "green" or "ghost")
	gBtnText.Text = all and "Upgrade" or "Not yet"
end

local L, R = columns(P, 3, 0.5)

-- the hotel level: medal, XP bar and the road of what the next levels unlock
heading(L, "Hotel level", 1)
local lvRow = row(L, 196, 2)
local lvMedal = UI.new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(16, 14), BackgroundColor3 = Color3.new(1, 1, 1), Parent = lvRow })
UI.corner(lvMedal, 48)
UI.grad(lvMedal, Color3.fromRGB(255, 232, 160), T.goldDk, 90)
UI.stroke(lvMedal, 4, Color3.fromRGB(255, 244, 210), 0.1)
UI.label(lvMedal, "LEVEL", 12, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(80, 50, 12), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 14) })
local lvNum = UI.label(lvMedal, "1", 44, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 50) })
UI.textStroke(lvNum, 3, 0.1).Color = Color3.fromRGB(110, 66, 14)
local lvTitle = UI.label(lvRow, "", 20, { FontFace = UI.F.black, Position = UDim2.fromOffset(128, 18), Size = UDim2.new(1, -144, 0, 24) })
UI.label(lvRow, "Guests, clean rooms, research and goals all give XP", 14, {
	FontFace = UI.F.body, TextColor3 = T.muted, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(128, 44), Size = UDim2.new(1, -144, 0, 18),
})
local lvTrack = UI.new("Frame", { Size = UDim2.new(1, -144, 0, 20), Position = UDim2.fromOffset(128, 74), BackgroundColor3 = T.ink, Parent = lvRow })
UI.corner(lvTrack, 10)
UI.stroke(lvTrack, 1, T.line, 0.4)
local lvFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = lvTrack })
UI.corner(lvFill, 10)
UI.grad(lvFill, Color3.fromRGB(206, 182, 255), T.violetDk, 90)
local lvXP = UI.label(lvTrack, "", 13, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
UI.textStroke(lvXP, 1.5, 0.3)
local road = UI.new("ScrollingFrame", {
	Name = "Road", Size = UDim2.new(1, -32, 0, 76), Position = UDim2.fromOffset(16, 112), BackgroundTransparency = 1,
	ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	ScrollBarThickness = 3, ScrollBarImageColor3 = T.gold, ScrollBarImageTransparency = 0.4, Parent = lvRow,
})
UI.list(road, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Top)

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
			local step = UI.new("Frame", { Name = "L" .. Lv, Size = UDim2.fromOffset(0, 64), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.ink, LayoutOrder = Lv, Parent = road })
			UI.corner(step, 12)
			UI.stroke(step, 1.5, shown == 1 and T.gold or T.line, shown == 1 and 0.2 or 0.45)
			UI.pad(step, 8, 0, 12, 0)
			UI.list(step, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
			local tag = UI.new("Frame", { Size = UDim2.fromOffset(50, 48), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 0, Parent = step })
			UI.corner(tag, 10)
			UI.grad(tag, shown == 1 and Color3.fromRGB(255, 226, 150) or T.ink3, shown == 1 and T.goldDk or T.ink2, 90)
			UI.label(tag, "LV", 11, { FontFace = UI.F.black, TextColor3 = shown == 1 and Color3.fromRGB(70, 46, 12) or T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 12) })
			UI.label(tag, tostring(Lv), 22, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 28) })
			for j = 1, math.min(#u, 4) do
				UI.icon(step, ICON[u[j].icon] or ICON.star, 40, { LayoutOrder = j })
			end
			if #u > 4 then
				UI.new("TextLabel", { Text = "+" .. (#u - 4), TextSize = 16, FontFace = UI.F.black, TextColor3 = T.gold, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 9, Parent = step })
			end
			local names = {}
			for _, x in ipairs(u) do table.insert(names, x.name) end
			UI.tooltip(step, "Level " .. Lv .. ": " .. table.concat(names, ", "))
			if shown >= 10 then break end
		end
	end
	if shown == 0 then
		UI.label(road, "Everything is unlocked. You run a legendary hotel!", 15, { FontFace = UI.F.heavy, TextColor3 = T.gold, Size = UDim2.new(1, 0, 0, 40) })
	end
end

local function refreshLevel(h)
	local lv = h:GetAttribute("Level") or 1
	local xp = h:GetAttribute("XP") or 0
	local need = h:GetAttribute("XPNeed") or Levels.need(lv)
	lvNum.Text = tostring(lv)
	heroLevelText.Text = "LEVEL " .. lv
	if lv >= Levels.MAX then
		lvTitle.Text = "Top level reached"
		lvXP.Text = "MAX LEVEL"
	else
		lvTitle.Text = UI.commas(math.max(need - xp, 0)) .. " XP to level " .. (lv + 1)
		lvXP.Text = UI.commas(xp) .. " / " .. UI.commas(need) .. " XP"
	end
	local k = lv >= Levels.MAX and 1 or math.clamp(xp / math.max(need, 1), 0, 1)
	UI.tween(lvFill, 0.4, { Size = UDim2.fromScale(k, 1) })
	if roadFor ~= lv then buildRoad(lv) end
end

-- right now: the live numbers
heading(L, "Right now", 3)
local nowRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 4, Parent = L })
UI.list(nowRow, Enum.FillDirection.Horizontal, 12)
local nowVals = {}
nowVals.ready = tile(nowRow, "roomReady", "rooms ready", 1, T.green)
nowVals.dirty = tile(nowRow, "roomDirty", "to clean", 2, T.red)
nowVals.waiting = tile(nowRow, "door", "in line", 3, T.gold)
nowVals.appeal = tile(nowRow, "sparkle", "lobby appeal", 4, T.blue)

-- play together (round 10c: was its own Co-op page)
heading(L, "Play together", 5, "Run your hotel with friends")
local away = row(L, 70, 6)
away.BackgroundColor3 = Color3.fromRGB(58, 50, 34)
away:FindFirstChildOfClass("UIStroke").Color = T.gold
rowIcon(away, "coop", 36)
local awayText = UI.label(away, "", 17, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(72, 0), Size = UDim2.new(1, -250, 1, 0), TextWrapped = true })
local homeBtn = UI.button(away, {
	text = "My hotel", kind = "green", size = UDim2.fromOffset(150, 44), pos = UDim2.new(1, -14, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 17, radius = 12,
	onClick = function() Coop:FireServer("leave") end,
})
local coopList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 7, Parent = L })
UI.list(coopList, nil, 8)
local empty = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = T.ink2, BackgroundTransparency = 0.3, LayoutOrder = 999, Parent = coopList })
UI.corner(empty, 14)
UI.icon(empty, ICON.coop, 44, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ImageTransparency = 0.3 })
UI.label(empty, "Nobody else is here yet. Invite friends to this server from the Roblox menu, then invite them to your hotel here.", 14, {
	FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(30, 62), Size = UDim2.new(1, -60, 0, 40),
})

local rows = {} -- player -> row
local invited = {} -- userId -> time we invited them

local function makeRow(p)
	local f = row(coopList, 76, 10)
	f.Name = "Row_" .. p.UserId
	local face = UI.new("ImageLabel", { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 11, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink3, BackgroundTransparency = 0, Parent = f })
	UI.corner(face, 27)
	UI.stroke(face, 2, T.gold, 0.4)
	task.spawn(function() face.Image = headshot(p.UserId) end)
	UI.label(f, p.DisplayName, 18, { FontFace = UI.F.black, Position = UDim2.fromOffset(78, 14), Size = UDim2.new(1, -470, 0, 22) })
	local where = UI.label(f, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(78, 40), Size = UDim2.new(1, -470, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local r = { frame = f, where = where, mode = "invite" }
	-- round 10e: go and look at their hotel, or ask to help there
	UI.button(f, {
		text = "Visit", kind = "ink", size = UDim2.fromOffset(92, 44), pos = UDim2.new(1, -312, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 12,
		onClick = function() Coop:FireServer("visit", p.UserId) setOpen(false) end,
	})
	r.askBtn, r.askText = UI.button(f, {
		text = "Ask to join", kind = "ink", size = UDim2.fromOffset(128, 44), pos = UDim2.new(1, -174, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 12,
		onClick = function()
			if r.asked and os.clock() - r.asked < 60 then return end
			r.asked = os.clock()
			Coop:FireServer("request", p.UserId)
			r.askText.Text = "Asked"
			UI.setKind(r.askBtn, "ghost")
			task.delay(60, function() if r.askText then r.askText.Text = "Ask to join" UI.setKind(r.askBtn, "ink") end end)
		end,
	})
	r.btn, r.text = UI.button(f, {
		text = "Invite", kind = "green", size = UDim2.fromOffset(150, 44), pos = UDim2.new(1, -14, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 17, radius = 12,
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
		local mine = player:GetAttribute("RAH_Home")
		local theirPlot = p:GetAttribute("RAH_Plot")
		local theirHome = p:GetAttribute("RAH_Home")
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
	p:GetAttributeChangedSignal("RAH_Plot"):Connect(r.refresh)
end

local function refreshAll()
	local mine, here = player:GetAttribute("RAH_Home"), player:GetAttribute("RAH_Plot")
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
for _, a in ipairs({ "RAH_Plot", "RAH_Home" }) do player:GetAttributeChangedSignal(a):Connect(refreshAll) end
refreshAll()

-- guest reviews (hotel attribute Reviews, newest first): a summary, a filter and the cards
heading(R, "Guest reviews", 1)
local revTop = row(R, 132, 2)
local revAvg = UI.label(revTop, "-", 52, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(120, 60) })
local revStars = stars(revTop, 22, UDim2.fromOffset(19, 78))
local revCount = UI.label(revTop, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(14, 104), Size = UDim2.fromOffset(120, 16) })
local distBars = {}
for s = 5, 1, -1 do
	local y = 14 + (5 - s) * 21
	UI.label(revTop, tostring(s), 13, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(154, y), Size = UDim2.fromOffset(12, 16) })
	UI.icon(revTop, ICON.star, 14, { Position = UDim2.fromOffset(168, y + 1) })
	local track = UI.new("Frame", { Size = UDim2.new(1, -250, 0, 10), Position = UDim2.fromOffset(190, y + 3), BackgroundColor3 = T.ink, Parent = revTop })
	UI.corner(track, 5)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = s >= 4 and T.gold or s == 3 and T.muted or T.red, Parent = track })
	UI.corner(fill, 5)
	local n = UI.label(revTop, "0", 13, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -48, 0, y), Size = UDim2.fromOffset(34, 16) })
	distBars[s] = { fill = fill, n = n }
end
local revFilter = "all"
local refreshReviews -- forward
local _, revSeg = UI.segmented(R, { { id = "all", text = "All" }, { id = "good", text = "Praise" }, { id = "bad", text = "Complaints" } }, "all", function(id)
	revFilter = id
	refreshReviews(true)
end, { order = 3, size = UDim2.new(1, 0, 0, 36) })
local revList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = R })
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
			local accent = s >= 4 and T.gold or s <= 2 and T.red or T.line
			local card = row(revList, 0, i)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card:FindFirstChildOfClass("UIStroke").Color = accent
			UI.pad(card, 16, 12, 16, 12)
			local inner = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card })
			UI.list(inner, nil, 4)
			local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = 1, Parent = inner })
			local st = stars(top, 18)
			st.set(s, true)
			UI.label(top, (r.name or "A guest") .. (r.room and (", room " .. r.room) or ""), 13, {
				FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(1, 1),
			})
			UI.label(inner, "\"" .. tostring(r.text or "") .. "\"", 16, {
				FontFace = UI.F.heavy, TextColor3 = T.cream, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
			})
			if shown >= 12 then break end
		end
	end
	if shown == 0 then
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = T.ink2, BackgroundTransparency = 0.3, Parent = revList })
		UI.corner(f, 14)
		UI.icon(f, ICON.chat, 40, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ImageTransparency = 0.3 })
		UI.label(f, #list == 0 and "No reviews yet. Guests leave one when they check out." or "Nothing here yet.", 14, {
			FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 20),
		})
	end
end

local function refreshHotel()
	local h = workHotel()
	if not h then return end
	local s = h:GetAttribute("HotelStars") or 1
	heroStars.set(s)
	heroRating.Text = string.format("%.1f", s)
	local rs = h:GetAttribute("ReviewStars")
	heroReviews.Text = rs and ("reviews average " .. string.format("%.1f", rs)) or "no reviews yet"
	local total = (h:GetAttribute("RoomsReady") or 0) + (h:GetAttribute("RoomsBusy") or 0) + (h:GetAttribute("RoomsDirty") or 0)
	local staffN = 0
	for _, def in ipairs(C.STAFF) do staffN += h:GetAttribute(def.attr) or 0 end
	heroLine.Text = total .. (total == 1 and " guest room" or " guest rooms") .. ", " .. staffN .. (staffN == 1 and " staff member" or " staff") .. ", day " .. (RAH:GetAttribute("Day") or 1)
	local st = hotelQuests(h)
	for key, v in pairs(life) do
		local n = tonumber(st.life[key]) or 0
		v.label.Text = (v.money and "$" or "") .. UI.commas(n)
	end
	nowVals.ready.Text = tostring(h:GetAttribute("RoomsReady") or 0)
	nowVals.dirty.Text = tostring(h:GetAttribute("RoomsDirty") or 0)
	nowVals.waiting.Text = tostring(h:GetAttribute("Waiting") or 0)
	nowVals.appeal.Text = tostring(h:GetAttribute("LobbyAppeal") or 0)
	local mine = player:GetAttribute("RAH_Home")
	local isMine = mine ~= nil and h.Name == mine
	nameBox.TextEditable = isMine
	nameBtn.Visible = isMine
	if not nameBox:IsFocused() then nameBox.Text = h:GetAttribute("HotelName") or "My Hotel" end
	refreshLevel(h)
	refreshReviews()
	refreshGrade(h)
end

---------------------------------------------------------------- staff page (hiring goes through the Build remote)

P = pages.staff
-- round 14 remake: a staff room banner (hiring needs one), a team summary, the hire cards, and a card per
-- staff member with their level, what they're doing, an energy bar, and Edit / Break / Fire.
local STAFF_ART = {
	janitor = { Color3.fromRGB(146, 234, 140), Color3.fromRGB(38, 156, 80), "Keeps rooms spotless", { "Cleans dirty rooms on their own", "Dusts the decor between jobs" } },
	doorman = { Color3.fromRGB(136, 204, 255), Color3.fromRGB(44, 110, 212), "Runs the front door", { "Walks out to greet each guest", "Takes their bags and shows them in" } },
	receptionist = { Color3.fromRGB(255, 220, 132), Color3.fromRGB(204, 138, 42), "Works the front desk", { "Checks guests in and out", "One guest at a time, in order" } },
	cook = { Color3.fromRGB(255, 176, 132), Color3.fromRGB(214, 84, 52), "Runs the kitchen", { "Cooks every order on a stove", "Needs a Stove and a Serving Counter" } },
	handyman = { Color3.fromRGB(255, 208, 110), Color3.fromRGB(214, 120, 40), "Keeps things running", { "Fixes broken showers and machines", "Nothing stays broken for long" } },
}
local StaffEdit = RAH.Remotes:WaitForChild("StaffEdit", 10)
local Catalog = require(RAH:WaitForChild("Catalog"))
local function hasStaffRoom(h)
	local placed = h and h:FindFirstChild("Placed")
	if not placed then return false end
	for _, m in ipairs(placed:GetChildren()) do
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		if it and it.tags and table.find(it.tags, "staffroom") then return true end
	end
	return false
end

-- the staff room banner + team numbers
local roomCard = row(P, 104, 0)
local roomGrad = UI.grad(roomCard, Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 212, 230), 90)
local roomBall = UI.new("Frame", { Size = UDim2.fromOffset(76, 76), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = roomCard })
UI.corner(roomBall, 38)
local roomBallG = UI.grad(roomBall, Color3.fromRGB(150, 230, 160), Color3.fromRGB(40, 140, 80), 90)
UI.stroke(roomBall, 3, T.ink, 0.2)
UI.icon(roomBall, ICON.staff, 52, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local roomTitle = UI.label(roomCard, "", 22, { FontFace = UI.F.black, Position = UDim2.fromOffset(104, 16), Size = UDim2.new(1, -470, 0, 26) })
local roomText = UI.label(roomCard, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(104, 46), Size = UDim2.new(1, -470, 0, 48) })
local roomBtn = UI.button(roomCard, { text = "Build a staff room", kind = "gold", size = UDim2.fromOffset(200, 44), pos = UDim2.new(1, -16, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 12, onClick = function()
	player:SetAttribute("RAH_BuildWant", "staff")
	if setOpen then setOpen(false) end
end })
-- three number chips (team, wages, on break)
local chips = UI.new("Frame", { Size = UDim2.fromOffset(330, 64), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, Parent = roomCard })
UI.list(chips, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Right)
local function chip(label, order)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(102, 64), BackgroundColor3 = T.ink, LayoutOrder = order, Parent = chips })
	UI.corner(f, 12)
	UI.stroke(f, 1.5, T.line, 0.4)
	local v = UI.label(f, "0", 22, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 26) })
	UI.label(f, label, 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 16) })
	return v
end
local chipTeam, chipWage, chipBreak = chip("TEAM", 1), chip("WAGES / DAY", 2), chip("ON A BREAK", 3)

heading(P, "Hire your team", 1, "Staff work by themselves, all day and night")
local hireRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, LayoutOrder = 2, Parent = P })
UI.list(hireRow, Enum.FillDirection.Horizontal, 14)
local hireCards = {}
local refreshHire -- forward
for i, def in ipairs(C.STAFF) do
	local art = STAFF_ART[def.id] or STAFF_ART.janitor
	local f = UI.new("Frame", { Size = UDim2.new(1 / #C.STAFF, -12, 1, 0), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = hireRow })
	UI.corner(f, 18)
	UI.stroke(f, 1.5, T.line, 0.4)
	UI.grad(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 212, 230), 90)
	local banner = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	UI.corner(banner, 18)
	UI.grad(banner, art[1]:Lerp(T.ink, 0.35), art[2]:Lerp(T.ink, 0.55), 90)
	local ball = UI.new("Frame", { Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0, 14, 0, 10), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	UI.corner(ball, 40)
	UI.grad(ball, art[1], art[2], 90)
	UI.stroke(ball, 3, art[2]:Lerp(Color3.new(0, 0, 0), 0.5), 0)
	UI.icon(ball, ICON[def.icon], 58, { Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5) })
	UI.label(f, def.name, 21, { FontFace = UI.F.black, Position = UDim2.fromOffset(104, 22), Size = UDim2.new(1, -112, 0, 26), TextTruncate = Enum.TextTruncate.AtEnd })
	UI.label(f, art[3], 13, { FontFace = UI.F.heavy, TextColor3 = T.cream, TextTransparency = 0.2, Position = UDim2.fromOffset(104, 50), Size = UDim2.new(1, -112, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local perks = UI.new("Frame", { Size = UDim2.new(1, -28, 0, 56), Position = UDim2.fromOffset(14, 110), BackgroundTransparency = 1, Parent = f })
	UI.list(perks, nil, 6)
	for k, line in ipairs(art[4]) do
		local pr = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = k, Parent = perks })
		UI.icon(pr, ICON.checkmark, 16, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		UI.label(pr, line, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	end
	local pips = UI.new("Frame", { Size = UDim2.new(1, -28, 0, 10), Position = UDim2.fromOffset(14, 180), BackgroundTransparency = 1, Parent = f })
	UI.list(pips, Enum.FillDirection.Horizontal, 5)
	local pipList = {}
	for k = 1, def.max do
		local pip = UI.new("Frame", { Size = UDim2.fromOffset(20, 10), BackgroundColor3 = T.ink3, LayoutOrder = k, Parent = pips })
		UI.corner(pip, 5)
		pipList[k] = pip
	end
	local count = UI.label(f, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 196), Size = UDim2.new(1, -28, 0, 18) })
	local wage = UI.label(f, "$" .. def.wage .. " a day", 13, { FontFace = UI.F.heavy, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(14, 196), Size = UDim2.new(1, -28, 0, 18) })
	local _ = wage
	local btn, txt = UI.button(f, {
		text = "Hire", kind = "green", size = UDim2.new(1, -28, 0, 48), pos = UDim2.new(0.5, 0, 1, -14), anchor = Vector2.new(0.5, 1), textSize = 17, radius = 13,
		onClick = function(b)
			local ok, res, msg = pcall(Build.InvokeServer, Build, "hire", def.id)
			if ok and res == false and msg then mtoast(msg, def.icon, true) UI.shake(b) end
			if ok and res ~= false then UI.sound("Register") UI.pop(f, 1.04) end
			task.delay(0.2, refreshHire)
		end,
	})
	hireCards[def.id] = { def = def, btn = btn, text = txt, pips = pipList, count = count, n = -1, frame = f }
end

-- your team: a card each
heading(P, "Your team", 3, "Edit their look and job, send them on a break, or let them go")
local teamList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 4, Parent = P })
local teamGrid = Instance.new("UIGridLayout")
teamGrid.CellSize = UDim2.new(0.5, -7, 0, 132)
teamGrid.CellPadding = UDim2.fromOffset(14, 12)
teamGrid.SortOrder = Enum.SortOrder.LayoutOrder
teamGrid.Parent = teamList
local teamRows = {} -- model -> card bits
local teamEmpty = UI.label(P, "Nobody hired yet. A receptionist is a great first hire.", 15, { FontFace = UI.F.heavy, TextColor3 = T.muted, LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 30) })
local ROLE_ORDER = {}
for i, d in ipairs(C.STAFF) do ROLE_ORDER[d.id] = i end
local function send(m, action)
	local k = m:GetAttribute("StaffKey")
	if k and StaffEdit then StaffEdit:FireServer(action, k, {}) end
end
local function makeCard(m, def)
	local art = STAFF_ART[def and def.id or "janitor"] or STAFF_ART.janitor
	local f = row(teamList, 132, 0)
	UI.grad(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 216, 232), 90)
	local ball = UI.new("Frame", { Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	UI.corner(ball, 32)
	UI.grad(ball, art[1], art[2], 90)
	UI.stroke(ball, 2.5, art[2]:Lerp(Color3.new(0, 0, 0), 0.5), 0)
	UI.icon(ball, ICON[def and def.icon or "staff"], 44, { Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5) })
	local lv = UI.new("Frame", { Size = UDim2.fromOffset(44, 20), Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.gold, Parent = ball })
	UI.corner(lv, 10)
	local lvText = UI.label(lv, "LV 1", 12, { FontFace = UI.F.black, TextColor3 = T.ink, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	local nm = UI.label(f, m.Name, 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(92, 12), Size = UDim2.new(1, -104, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
	local role = UI.label(f, def and def.name or "Staff", 13, { FontFace = UI.F.heavy, TextColor3 = art[1], Position = UDim2.fromOffset(92, 36), Size = UDim2.new(1, -104, 0, 16) })
	local doing = UI.label(f, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(92, 54), Size = UDim2.new(1, -104, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	-- energy
	local track = UI.new("Frame", { Size = UDim2.new(1, -230, 0, 10), Position = UDim2.fromOffset(92, 80), BackgroundColor3 = T.ink, Parent = f })
	UI.corner(track, 5)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.corner(fill, 5)
	local fillG = UI.grad(fill, Color3.fromRGB(150, 236, 150), Color3.fromRGB(46, 160, 86), 90)
	local eText = UI.label(f, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -130, 0, 76), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(100, 18) })
	-- buttons
	local bar = UI.new("Frame", { Size = UDim2.new(1, -104, 0, 30), Position = UDim2.new(0, 92, 1, -10), AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Parent = f })
	UI.list(bar, Enum.FillDirection.Horizontal, 8)
	local editB = UI.button(bar, { text = "Edit", kind = "gold", size = UDim2.fromOffset(78, 30), textSize = 14, radius = 9, onClick = function()
		local k = m:GetAttribute("StaffKey")
		if k then player:SetAttribute("RAH_StaffEdit", k) end
	end })
	editB.LayoutOrder = 1
	local brk, brkT = UI.button(bar, { text = "Break", kind = "blue", size = UDim2.fromOffset(98, 30), textSize = 14, radius = 9, onClick = function(b)
		send(m, "break")
		UI.pop(b, 1.06)
	end })
	brk.LayoutOrder = 2
	local armed = 0
	local fireB, fireT
	fireB, fireT = UI.button(bar, { text = "Let go", kind = "ghost", size = UDim2.fromOffset(84, 30), textSize = 14, radius = 9, onClick = function(b)
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
	fireB.LayoutOrder = 3
	return { frame = f, name = nm, role = role, doing = doing, lv = lvText, fill = fill, fillG = fillG, eText = eText, brkT = brkT, brk = brk, def = def }
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
					local def
					for _, d in ipairs(C.STAFF) do if d.id == kind then def = d end end
					r = makeCard(m, def)
					teamRows[m] = r
				end
				local key = m:GetAttribute("StaffKey") or ""
				r.frame.LayoutOrder = (ROLE_ORDER[kind] or 9) * 10 + (tonumber(key:match("%d+$")) or 0)
				r.name.Text = m.Name
				local brole = m:GetAttribute("BRole") or ""
				r.lv.Text = "LV " .. (brole:match("LV (%d+)") or "1")
				local what = (m:GetAttribute("BWhat") or m:GetAttribute("BText")) or ""
				r.doing.Text = what ~= "" and what or "Getting ready"
				local e = m:GetAttribute("Energy") or 100
				local br = m:GetAttribute("OnBreak")
				if br then onBreak += 1 end
				UI.tween(r.fill, 0.4, { Size = UDim2.fromScale(math.clamp(e / 100, 0.02, 1), 1) })
				r.fillG.Color = e < 25 and ColorSequence.new(Color3.fromRGB(255, 150, 120), Color3.fromRGB(200, 60, 50))
					or (e < 55 and ColorSequence.new(Color3.fromRGB(255, 226, 130), Color3.fromRGB(210, 150, 40))
					or ColorSequence.new(Color3.fromRGB(150, 236, 150), Color3.fromRGB(46, 160, 86)))
				r.eText.Text = br and "On a break" or ("Energy " .. math.floor(e) .. "%")
				r.brkT.Text = br and "Back to work" or "Break"
			end
		end
	end
	for m, r in pairs(teamRows) do
		if not seen[m] then r.frame:Destroy() teamRows[m] = nil end
	end
	teamEmpty.Visible = n == 0
	chipTeam.Text = tostring(n)
	chipWage.Text = "$" .. UI.commas(h and h:GetAttribute("WageBill") or 0)
	chipBreak.Text = tostring(onBreak)
	-- the banner
	local ok = hasStaffRoom(h)
	roomBtn.Visible = not ok
	chips.Visible = ok
	if ok then
		roomTitle.Text = "Staff room ready"
		roomText.Text = "Your team keeps their things in the lockers and takes breaks there. Tired staff work slower, so send them on a break now and then."
		roomBallG.Color = ColorSequence.new(Color3.fromRGB(150, 230, 160), Color3.fromRGB(40, 140, 80))
		roomGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 212, 230))
	else
		roomTitle.Text = "You need a staff room"
		roomText.Text = "Before you can hire, wall off a small room and put Staff Lockers in it (Build, Staff tab). A Break Table makes it even better."
		roomBallG.Color = ColorSequence.new(Color3.fromRGB(255, 220, 130), Color3.fromRGB(210, 130, 40))
		roomGrad.Color = ColorSequence.new(Color3.fromRGB(255, 244, 220), Color3.fromRGB(230, 206, 170))
	end
end

refreshHire = function()
	local h = workHotel()
	local cash = player:GetAttribute("Cash") or 0
	local roomOk = hasStaffRoom(h)
	for _, card in pairs(hireCards) do
		local def = card.def
		local n = h and (h:GetAttribute(def.attr) or 0) or 0
		for k, pip in ipairs(card.pips) do
			local on = k <= n
			pip.BackgroundColor3 = on and T.green or T.ink3
			if on and k > card.n and card.n >= 0 then UI.pop(pip, 1.8) end
		end
		card.n = n
		card.count.Text = n .. " of " .. def.max .. " hired"
		if n >= def.max then
			card.text.Text = "Team full"
			UI.setKind(card.btn, "ghost")
		elseif not roomOk then
			card.text.Text = "Needs a staff room"
			UI.setKind(card.btn, "ghost")
		elseif h and not Levels.staffOk(h, def.id, n + 1) then
			card.text.Text = "Unlocks at level " .. Levels.staffLevel(def.id, n + 1)
			UI.setKind(card.btn, "ghost")
		else
			local price = def.prices[n + 1]
			card.text.Text = "Hire for $" .. UI.commas(price)
			UI.setKind(card.btn, cash >= price and "green" or "ghost")
		end
	end
	refreshTeam()
end

---------------------------------------------------------------- achievements page

P = pages.achievements
local TIER_COL = {
	{ Color3.fromRGB(240, 176, 120), Color3.fromRGB(150, 86, 40) }, -- bronze
	{ Color3.fromRGB(232, 238, 248), Color3.fromRGB(130, 144, 168) }, -- silver
	{ Color3.fromRGB(255, 226, 130), Color3.fromRGB(196, 136, 30) }, -- gold
}
local achHead = row(P, 96, 0)
UI.grad(achHead, Color3.fromRGB(255, 240, 200), Color3.fromRGB(200, 190, 210), 90)
rowIcon(achHead, "trophy", 62)
local achTitle = UI.label(achHead, "", 24, { FontFace = UI.F.black, Position = UDim2.fromOffset(98, 16), Size = UDim2.new(1, -340, 0, 28) })
UI.label(achHead, "Every tier you reach pays out. Claim it here.", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(98, 48), Size = UDim2.new(1, -340, 0, 18) })
local achTrack = UI.new("Frame", { Size = UDim2.fromOffset(220, 16), Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.ink, Parent = achHead })
UI.corner(achTrack, 8)
local achFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = achTrack })
UI.corner(achFill, 8)
UI.grad(achFill, Color3.fromRGB(255, 226, 140), T.goldDk, 90)
local achPct = UI.label(achHead, "", 13, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0.5, -26), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(220, 16) })
local achGridF = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = P })
local achGrid = Instance.new("UIGridLayout")
achGrid.CellSize = UDim2.new(0.5, -7, 0, 132)
achGrid.CellPadding = UDim2.fromOffset(14, 14)
achGrid.SortOrder = Enum.SortOrder.LayoutOrder
achGrid.Parent = achGridF
local Achieve = RAH.Remotes:WaitForChild("Achieve", 10)
local achCards = {}
local refreshAch -- forward
for i, a in ipairs(Q.ACHIEVEMENTS) do
	local f = row(achGridF, 132, i)
	local stroke = f:FindFirstChildOfClass("UIStroke")
	-- the medal: its colour shows the tier you've claimed
	local medal = UI.new("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
	UI.corner(medal, 42)
	local mGrad = UI.grad(medal, T.ink3, T.ink2, 90)
	local mStroke = UI.stroke(medal, 3, T.line, 0.2)
	local mIcon = UI.icon(medal, ICON[a.icon] or ICON.star, 54, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	local pips = UI.new("Frame", { Size = UDim2.fromOffset(54, 12), Position = UDim2.new(0.5, 0, 1, 2), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = medal })
	UI.list(pips, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center)
	local pipList = {}
	for k = 1, 3 do
		local pip = UI.new("Frame", { Size = UDim2.fromOffset(14, 12), BackgroundColor3 = T.ink, LayoutOrder = k, Parent = pips })
		UI.corner(pip, 6)
		UI.stroke(pip, 1.5, T.shadow, 0.2)
		pipList[k] = pip
	end
	local name = UI.label(f, a.name, 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(116, 14), Size = UDim2.new(1, -132, 0, 24) })
	local tierTag = UI.label(f, "", 12, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -16, 0, 18), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(120, 16) })
	local desc = UI.label(f, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(116, 40), Size = UDim2.new(1, -132, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local track = UI.new("Frame", { Size = UDim2.new(1, -292, 0, 20), Position = UDim2.fromOffset(116, 80), BackgroundColor3 = T.ink, Parent = f })
	UI.corner(track, 10)
	UI.stroke(track, 1, T.line, 0.4)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.corner(fill, 10)
	local fGrad = UI.grad(fill, Color3.fromRGB(255, 226, 140), T.goldDk, 90)
	local prog = UI.label(track, "", 12, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	UI.textStroke(prog, 1.5, 0.25)
	local btn, btnText = UI.button(f, {
		text = "Claim", kind = "ghost", size = UDim2.fromOffset(154, 46), pos = UDim2.new(1, -14, 1, -14), anchor = Vector2.new(1, 1), textSize = 15, radius = 12,
		onClick = function(b)
			local c = achCards[a.id]
			if not c.ready then UI.shake(b) return end
			local ok, res, info = pcall(Achieve.InvokeServer, Achieve, "claim", a.id)
			if ok and res then
				UI.sound("Fanfare")
				UI.pop(medal, 1.4, 0.5)
				UI.pop(f, 1.04, 0.3)
				mtoast(a.name .. " " .. Q.TIER_NAMES[info.tier] .. "! +$" .. UI.commas(info.cash), "trophy")
			else
				mtoast(ok and tostring(info) or "Try again", "close", true)
				UI.shake(b)
			end
			task.delay(0.3, refreshAch)
		end,
	})
	achCards[a.id] = { a = a, frame = f, stroke = stroke, mGrad = mGrad, mStroke = mStroke, mIcon = mIcon, pips = pipList, tierTag = tierTag, desc = desc, fill = fill, fGrad = fGrad, prog = prog, btn = btn, btnText = btnText, claimed = -1 }
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
		-- the medal takes the colour of the best claimed tier
		if claimed ~= c.claimed then
			local col = TIER_COL[claimed]
			if col then
				c.mGrad.Color = ColorSequence.new(col[1], col[2])
				c.mStroke.Color = col[1]:Lerp(Color3.new(1, 1, 1), 0.4)
				c.mIcon.ImageTransparency = 0
			else
				c.mGrad.Color = ColorSequence.new(T.ink3, T.ink2)
				c.mStroke.Color = T.line
				c.mIcon.ImageTransparency = 0.35
			end
			for k, pip in ipairs(c.pips) do
				pip.BackgroundColor3 = k <= claimed and TIER_COL[k][1] or T.ink
			end
			if c.claimed >= 0 and claimed > c.claimed then UI.pop(c.frame, 1.05, 0.3) end
			c.claimed = claimed
		end
		local nextTier = claimed + 1
		if nextTier > 3 then
			c.tierTag.Text = "COMPLETE"
			c.tierTag.TextColor3 = T.gold
			c.desc.Text = string.format(a.text, Q.fmt(a, a.tiers[3]))
			c.prog.Text = "All tiers claimed"
			c.fill.Size = UDim2.fromScale(1, 1)
			c.fGrad.Color = ColorSequence.new(Color3.fromRGB(170, 250, 170), T.greenDk)
			c.btnText.Text = "Done"
			UI.setKind(c.btn, "ghost")
			c.ready = false
			c.stroke.Color = T.gold
			c.stroke.Transparency = 0.3
		else
			local goal = a.tiers[nextTier]
			c.tierTag.Text = string.upper(Q.TIER_NAMES[nextTier])
			c.tierTag.TextColor3 = TIER_COL[nextTier][1]
			c.desc.Text = string.format(a.text, Q.fmt(a, goal))
			c.prog.Text = Q.fmt(a, math.min(v, goal)) .. " / " .. Q.fmt(a, goal)
			UI.tween(c.fill, 0.5, { Size = UDim2.fromScale(math.clamp(v / goal, 0, 1), 1) }, Enum.EasingStyle.Quint)
			c.fGrad.Color = ColorSequence.new(Color3.fromRGB(255, 226, 140), T.goldDk)
			c.ready = reached >= nextTier and isOwner
			local cash = a.cash[nextTier] or 0
			if reached >= nextTier then
				ready += 1
				c.btnText.Text = isOwner and ("Claim $" .. UI.commas(cash)) or "Owner claims"
				UI.setKind(c.btn, isOwner and "green" or "ghost")
				c.stroke.Color = T.green
				c.stroke.Transparency = 0.1
			else
				c.btnText.Text = "$" .. UI.commas(cash)
				UI.setKind(c.btn, "ghost")
				c.stroke.Color = T.line
				c.stroke.Transparency = 0.45
			end
		end
	end
	achTitle.Text = claimedTiers .. " of " .. totalTiers .. " tiers claimed"
	achPct.Text = math.floor(claimedTiers / totalTiers * 100 + 0.5) .. "% COMPLETE"
	UI.tween(achFill, 0.5, { Size = UDim2.fromScale(claimedTiers / totalTiers, 1) })
	local badge = dock.badges.achievements
	if badge then
		if ready > 0 and not badge.Visible then UI.pop(badge, 0.4) end
		badge.Visible = ready > 0
		badge.Text = tostring(ready)
	end
end

---------------------------------------------------------------- settings page

P = pages.settings
local SET_CATS = {
	{ id = "sound", text = "Sound" }, { id = "gameplay", text = "Gameplay" }, { id = "display", text = "Display" },
	{ id = "controls", text = "Controls" }, { id = "save", text = "Save" },
}
local setGroups = {}
local _, setSeg = UI.segmented(P, SET_CATS, "sound", function(id)
	for k, g in pairs(setGroups) do g.Visible = k == id end
	UI.stagger(setGroups[id], 0.03)
end, { order = 0, size = UDim2.new(1, 0, 0, 40), textSize = 16 })
for i, c in ipairs(SET_CATS) do
	local g = UI.new("Frame", { Name = "Set_" .. c.id, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 + i, Visible = c.id == "sound", Parent = P })
	UI.list(g, nil, 10)
	setGroups[c.id] = g
end

local function settingBase(group, icon, text, sub, order)
	local f = row(group, 70, order)
	rowIcon(f, icon, 36)
	UI.label(f, text, 17, { FontFace = UI.F.black, Position = UDim2.fromOffset(74, 12), Size = UDim2.new(1, -420, 0, 22) })
	UI.label(f, sub, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(74, 36), Size = UDim2.new(1, -420, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	return f
end
local function settingToggle(group, icon, text, sub, on, callback, order)
	local f = settingBase(group, icon, text, sub, order)
	local _, set = UI.toggle(f, on, callback, { pos = UDim2.new(1, -18, 0.5, 0), anchor = Vector2.new(1, 0.5) })
	return set
end
local function settingSlider(group, icon, text, sub, value, callback, order)
	local f = settingBase(group, icon, text, sub, order)
	local num = UI.label(f, tostring(value) .. "%", 15, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(50, 20) })
	UI.slider(f, 0, 100, value, function(v)
		num.Text = math.floor(v) .. "%"
		callback(v)
	end, { size = UDim2.fromOffset(300, 28), pos = UDim2.new(1, -78, 0.5, 0), step = 5 }).AnchorPoint = Vector2.new(1, 0.5)
end

-- round 12: a slider with its own range and a formatted readout
local function settingRange(group, icon, text, sub, min, max, step, value, fmt, callback, order)
	local f = settingBase(group, icon, text, sub, order)
	local num = UI.label(f, fmt(value), 15, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -18, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(56, 20) })
	UI.slider(f, min, max, value, function(v)
		num.Text = fmt(v)
		callback(v)
	end, { size = UDim2.fromOffset(300, 28), pos = UDim2.new(1, -84, 0.5, 0), step = step }).AnchorPoint = Vector2.new(1, 0.5)
end
local function pct(v) return math.floor(v + 0.5) .. "%" end

-- sound: volumes (RAH_Audio reads RAH_MusicVol / RAH_SfxVol, 0..100) and the old on/off switches
local function vol(attr, offAttr)
	local v = player:GetAttribute(attr)
	if v == nil then v = player:GetAttribute(offAttr) and 0 or 100 end
	return v
end
settingSlider(setGroups.sound, "bell", "Music", "The hotel's background music", vol("RAH_MusicVol", "RAH_MusicOff"), function(v)
	player:SetAttribute("RAH_MusicVol", v)
	player:SetAttribute("RAH_MusicOff", v <= 0 or nil)
end, 1)
settingSlider(setGroups.sound, "sparkle", "Sound effects", "Bells, cash, doors and footsteps", vol("RAH_SfxVol", "RAH_SfxOff"), function(v)
	player:SetAttribute("RAH_SfxVol", v)
	player:SetAttribute("RAH_SfxOff", v <= 0 or nil)
end, 2)
settingToggle(setGroups.sound, "chat", "Menu sounds", "Clicks and whooshes on buttons", player:GetAttribute("RAH_UiSfxOff") ~= true, function(on)
	player:SetAttribute("RAH_UiSfxOff", not on or nil)
end, 3)

-- gameplay
if player:GetAttribute("RAH_Sprint") == nil then player:SetAttribute("RAH_Sprint", true) end
settingToggle(setGroups.gameplay, "walk", "Sprint", "Hold Shift to run", player:GetAttribute("RAH_Sprint") ~= false, function(on)
	player:SetAttribute("RAH_Sprint", on)
end, 1)
settingToggle(setGroups.gameplay, "quest", "Chapter goals", "The goals panel on the right of the screen", player:GetAttribute("RAH_HideQuests") ~= true, function(on)
	player:SetAttribute("RAH_HideQuests", not on or nil)
end, 2)
settingToggle(setGroups.gameplay, "chat", "Review pop-ups", "A card when a guest leaves a review", player:GetAttribute("RAH_HideReviews") ~= true, function(on)
	player:SetAttribute("RAH_HideReviews", not on or nil)
end, 3)
-- round 12
settingToggle(setGroups.gameplay, "stats", "End of day report", "The summary card when a day ends", player:GetAttribute("RAH_HideDaySummary") ~= true, function(on)
	player:SetAttribute("RAH_HideDaySummary", not on or nil)
end, 4)
settingToggle(setGroups.gameplay, "cash", "Money pop-ups", "+$ and XP numbers that float up", player:GetAttribute("RAH_HidePops") ~= true, function(on)
	player:SetAttribute("RAH_HidePops", not on or nil)
end, 5)
do
	local tutRow = settingBase(setGroups.gameplay, "quest", "Tutorial", "Play the guided first day again", 6)
	UI.button(tutRow, {
		text = "Replay", kind = "gold", size = UDim2.fromOffset(140, 42), pos = UDim2.new(1, -14, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 12,
		onClick = function()
			RAH.Remotes.TutSkip:FireServer("replay")
			player:SetAttribute("RAH_MenuWant", "close")
		end,
	})
end

-- display: client-side only
settingToggle(setGroups.display, "guest", "Guest bubbles", "Status cards over guests' heads", true, function(on)
	player:SetAttribute("RAH_HideBubbles", not on)
end, 1)
local pedCon
settingToggle(setGroups.display, "walk", "Sidewalk walkers", "People strolling past outside", true, function(on)
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
settingToggle(setGroups.display, "sparkle", "Room signs", "The floating signs over rooms that need you", player:GetAttribute("RAH_HideRoomSigns") ~= true, function(on)
	player:SetAttribute("RAH_HideRoomSigns", not on or nil)
end, 3)
-- round 12
settingRange(setGroups.display, "search", "Field of view", "How wide the camera sees", 55, 100, 1, player:GetAttribute("RAH_FOV") or 70,
	function(v) return tostring(math.floor(v + 0.5)) end, function(v) player:SetAttribute("RAH_FOV", v) end, 4)
settingToggle(setGroups.display, "sun", "Shadows", "Turn off for a smoother game on slow devices", player:GetAttribute("RAH_ShadowsOff") ~= true, function(on)
	player:SetAttribute("RAH_ShadowsOff", not on or nil)
end, 5)
settingRange(setGroups.display, "bell", "Button size", "The size of the E / tap buttons over things", 60, 140, 5, player:GetAttribute("RAH_PromptSize") or 100,
	pct, function(v) player:SetAttribute("RAH_PromptSize", v) end, 6)

-- controls: what every key does
local KEYS = {
	{ "W A S D", "Walk" }, { "Shift", "Sprint" }, { "E", "Use what's in front of you" }, { "F", "Talk to a guest" },
	{ "B", "Build mode" }, { "M", "Menu" }, { "R", "Research" }, { "Q / E", "Turn things in build mode" },
	{ "Right drag", "Turn the camera (build mode)" }, { "1 - 5", "Answer in a conversation" },
	{ "F", "Sit on chairs and the desk" }, { "Click + drag", "Lay a row of walls (build mode)" },
}
local keyGrid = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = setGroups.controls })
local kg = Instance.new("UIGridLayout")
kg.CellSize = UDim2.new(0.5, -6, 0, 52)
kg.CellPadding = UDim2.fromOffset(12, 10)
kg.SortOrder = Enum.SortOrder.LayoutOrder
kg.Parent = keyGrid
for i, k in ipairs(KEYS) do
	local f = row(keyGrid, 52, i)
	local cap = UI.new("TextLabel", {
		Text = k[1], TextSize = 15, FontFace = UI.F.black, TextColor3 = T.cream, BackgroundColor3 = T.ink,
		Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = f,
	})
	UI.corner(cap, 8)
	UI.pad(cap, 12, 0, 12, 0)
	UI.stroke(cap, 1.5, T.gold, 0.3)
	UI.label(f, k[2], 15, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -14, 0, 0), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.6, 0, 1, 0) })
end

-- round 12: the build camera
settingRange(setGroups.controls, "rotate", "Build camera speed", "How fast right-drag (or twisting) turns the view", 25, 200, 5, player:GetAttribute("RAH_LookSens") or 100,
	pct, function(v) player:SetAttribute("RAH_LookSens", v) end,-2)
settingToggle(setGroups.controls, "up", "Invert build camera", "Drag up to look down", player:GetAttribute("RAH_LookInvert") == true, function(on)
	player:SetAttribute("RAH_LookInvert", on or nil)
end,-1)

-- save: how saving works, and starting over
settingBase(setGroups.save, "hotel", "Saving", "Your hotel saves by itself every minute and when you leave", 1)
local resetRow = settingBase(setGroups.save, "close", "Reset progress", "Start this save over from scratch. This can't be undone", 2)
resetRow.BackgroundColor3 = Color3.fromRGB(58, 34, 42)
resetRow:FindFirstChildOfClass("UIStroke").Color = T.red
UI.button(resetRow, {
	text = "Reset", kind = "red", size = UDim2.fromOffset(160, 44), pos = UDim2.new(1, -14, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 12,
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

---------------------------------------------------------------- tabs + open/close

local activeTab = "hotel"
local headTitle, headSub, headIcon = body.Head:FindFirstChild("Title"), body.Head:FindFirstChild("Sub"), body.Head:FindFirstChildOfClass("ImageLabel")
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
	-- the lab (RAH_ResearchUI) runs while its tab is showing
	player:SetAttribute("RAH_ResearchOpen", (open and id == "research") or nil)
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
		player:SetAttribute("RAH_MenuOpen", true)
	else
		UI.tween(dim, 0.25, { BackgroundTransparency = 1 }).Completed:Connect(function() if not open then dim.Visible = false end end)
		UI.blur(false)
		UI.close(holder, function() if not open then wrap.Visible = false end end)
		player:SetAttribute("RAH_MenuOpen", nil)
		player:SetAttribute("RAH_ResearchOpen", nil)
	end
end
UIS.InputBegan:Connect(function(input, processed)
	if processed or (input.KeyCode ~= Enum.KeyCode.M and input.KeyCode ~= Enum.KeyCode.DPadLeft) then return end
	if player:GetAttribute("RAH_Building") or not player:GetAttribute("RAH_Slot") then return end
	setOpen(not open)
end)

---------------------------------------------------------------- the left dock (round 10: replaces the Menu button)

local dockGui = pgui:FindFirstChild("RAH_Dock")
if dockGui then dockGui:Destroy() end
-- above the Menu (20) and Research (30) screens so it stays usable while they're open
dockGui = UI.new("ScreenGui", {
	Name = "RAH_Dock", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
	DisplayOrder = 32, Parent = pgui,
})
local DOCK = {
	{ id = "hotel", text = "Hotel", icon = "hotel", top = Color3.fromRGB(255, 220, 132), bot = Color3.fromRGB(204, 138, 42), tip = "Your hotel and its level  (M)" },
	{ id = "staff", text = "Staff", icon = "staff", top = Color3.fromRGB(146, 234, 140), bot = Color3.fromRGB(38, 156, 80), tip = "Hire staff" },
	{ id = "research", text = "Research", icon = "research", top = Color3.fromRGB(200, 174, 255), bot = Color3.fromRGB(108, 72, 212), tip = "Research  (R)" },
	{ id = "achievements", text = "Awards", icon = "trophy", top = Color3.fromRGB(255, 196, 120), bot = Color3.fromRGB(196, 96, 40), tip = "Achievements" },
	{ id = "phone", text = "Phone", icon = "phone", top = Color3.fromRGB(140, 214, 255), bot = Color3.fromRGB(46, 100, 200), tip = "Your phone  (P)" },
	{ id = "shop", text = "Store", icon = "shop", top = Color3.fromRGB(255, 186, 214), bot = Color3.fromRGB(196, 64, 124), tip = "Store" },
	{ id = "settings", text = "Settings", icon = "settings", top = Color3.fromRGB(184, 192, 220), bot = Color3.fromRGB(82, 92, 126), tip = "Settings" },
}
local SLOT_W, SLOT_H, GAP, PAD = 66, 74, 2, 8 -- round 10e: more compact
local dockWrap = UI.new("Frame", { Name = "Dock", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -200, 0.5, 0), BackgroundTransparency = 1, Visible = false, Parent = dockGui })
local dockScale = Instance.new("UIScale")
dockScale.Name = "AutoScale"
dockScale.Parent = dockWrap
local pill = UI.new("Frame", { Name = "Pill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, BackgroundTransparency = 0.1, Parent = dockWrap })
UI.corner(pill, 34)
UI.grad(pill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 206, 228), 90)
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
	-- round 10e: the phone and the store live in RAH_Phone
	if id == "phone" or id == "shop" then
		if open then setOpen(false) end
		player:SetAttribute("RAH_PhoneWant", id == "shop" and "store" or "toggle")
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

-- other scripts open a page by setting the player attribute RAH_MenuWant (the HUD's top bar does)
player:GetAttributeChangedSignal("RAH_MenuWant"):Connect(function()
	local want = player:GetAttribute("RAH_MenuWant")
	if not want then return end
	player:SetAttribute("RAH_MenuWant", nil)
	if want == "close" then setOpen(false) return end
	if player:GetAttribute("RAH_Building") or not player:GetAttribute("RAH_Slot") or not pages[want] then return end
	if not (open and activeTab == want) then dockPress(want) end
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
	UI.textStroke(label, 3, 0).Color = Color3.fromRGB(18, 14, 28)
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
		UI.stroke(bar, 1.5, Color3.fromRGB(18, 14, 28), 0)
		local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
		UI.corner(fill, 4)
		UI.grad(fill, Color3.fromRGB(220, 200, 255), T.violetDk, 90)
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
			local n = player:GetAttribute("RAH_PhoneUnread")
			badge.Visible = n ~= nil
			badge.Text = n and tostring(math.min(n, 9)) or ""
		end
		player:GetAttributeChangedSignal("RAH_PhoneUnread"):Connect(unread)
		unread()
	end
end

-- which page is open: its ball gets the brass ring
function dock.mark(id)
	if player:GetAttribute("RAH_ResearchOpen") and not id then id = "research" end
	for bid, b in pairs(dock.buttons) do
		UI.tween(b.glow, 0.2, { Transparency = bid == id and 0 or 1 })
	end
end
player:GetAttributeChangedSignal("RAH_ResearchOpen"):Connect(function()
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
	-- round 12 phones: start below the top bar (RAH_Client's phoneLayout publishes its bottom) and stay small
	local phoneBar = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and dockGui.Parent and dockGui.Parent:FindFirstChild("RAH_HUD")
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
	local h = pgui:WaitForChild("RAH_HUD", 30)
	if h then h:GetAttributeChangedSignal("PhoneBarBottom"):Connect(layoutDock) end
end)

-- the dock hides while building (build mode has its own Done button) and on the title screen
local function refreshDock()
	local show = not player:GetAttribute("RAH_Building") and player:GetAttribute("RAH_Slot") ~= nil and player:GetAttribute("RAH_Plot") ~= nil
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
for _, a in ipairs({ "RAH_Building", "RAH_Slot", "RAH_Plot" }) do player:GetAttributeChangedSignal(a):Connect(refreshDock) end
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
