-- StarterPlayerScripts.ResearchUI: the Research Lab (round 10 remake; round 10c: a tab of the Menu).
-- Builds into Coop's Page_research. Opens with R (outside build mode), the dock's Research button, or player
-- attribute OpenResearch (true, or a node id to focus it; false closes). Build mode sets it when you click a
-- locked item. Opening asks the menu for the tab (MenuWant = "research").
-- Top: the lab strip (what's running, a live bar, Stop). Under it, a tab per branch. Left: the branch's tree,
-- round nodes in tiers from left to right with lines from what each one needs. Right: the chosen node's card
-- with what it unlocks (furniture spins in 3D), its cost and time, and the Start button.
-- Talks to ResearchServer through Remotes.Research; reads the hotel attribute "Research" and the hotel
-- level (Shared.Levels: some nodes wait for a level). The menu sets player attribute ResearchOpen while it shows.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Research = require(Shared:WaitForChild("Research"))
local Levels = require(Shared:WaitForChild("Levels"))
local Build = require(Shared:WaitForChild("Build"))
local UI = require(Shared:WaitForChild("UI"))
local Remote = Shared.Remotes:WaitForChild("Research")
local ITEMS = Shared:WaitForChild("Items")
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local PLOTS = workspace:WaitForChild("Plots")

local old = pgui:FindFirstChild("Research")
if old then old:Destroy() end

local BRANCH_ICON = { build = "shapes", decor = "catDecor", comfort = "catFurniture", fun = "catFun", service = "bell", guests = "ev_party", perks = "upgrade",
	staff = "staff", stay = "guest", market = "walk", dining = "food", upkeep = "hammer" }
local NODE_ICON = {
	shapes1 = "shapes", shapes2 = "shapes", glassneon = "sparkle",
	rooms1 = "bed", rooms2 = "ev_business", safety = "ev_firstaid",
	ev_family = "ev_baby", ev_access = "ev_access", ev_pets = "ev_pet", ev_night = "ev_night", ev_party = "ev_party",
	ev_inspector = "ev_inspector", ev_romance = "ev_romance", ev_tour = "ev_tour", ev_vip = "ev_vip",
	up_street = "walk", up_clean = "clean", up_speed = "bell", up_lab = "research", up_tips = "cash", up_price = "star",
	decor2 = "lamp",
	st_janitor = "janitor", st_janitor2 = "clean", st_door = "doorman", st_door2 = "doorman", st_desk = "bell", st_desk2 = "bell",
	st_uniforms = "sparkle", st_happy = "guest", st_kitchen = "chef", st_fixer = "hammer", st_master = "trophy", st_onboard = "staff",
	g_pillow = "bed", g_welcome = "guest", g_quiet = "sleep", g_turndown = "bed", g_lounge = "catFurniture", g_concierge = "bell", g_luxury = "star",
	m_flyers = "walk", m_online = "chat", m_reviews = "star", m_social = "chat", m_loyalty = "cash", m_rates = "cash", m_events = "ev_party", m_brand = "trophy",
	k_menu = "food", k_fast = "chef", k_gourmet = "food", k_service = "bell", k_chef = "chef", k_star = "star",
	u_check = "search", u_tools = "hammer", u_parts = "hammer", u_plumb = "shower", u_eco = "lamp", u_smart = "research",
}
local function iconOf(n) return ICON[NODE_ICON[n.id] or BRANCH_ICON[n.branch]] end
local BRANCH = {}
for _, b in ipairs(Research.BRANCHES) do BRANCH[b.id] = b end

-- what a node unlocks: shop items (ids) and shape finishes (names)
local UNLOCK_ITEMS, UNLOCK_MATS = {}, {}
for _, id in ipairs(Catalog.ORDER) do
	local it = Catalog.ITEMS[id]
	if it and it.research then
		UNLOCK_ITEMS[it.research] = UNLOCK_ITEMS[it.research] or {}
		table.insert(UNLOCK_ITEMS[it.research], id)
	end
end
for _, m in ipairs(Catalog.MATERIALS) do
	if m.research then
		UNLOCK_MATS[m.research] = UNLOCK_MATS[m.research] or {}
		table.insert(UNLOCK_MATS[m.research], m.name)
	end
end

local function hotel()
	return PLOTS:FindFirstChild(player:GetAttribute("Plot") or "")
end
local function state()
	return Research.state(hotel())
end
local function clock(sec)
	sec = math.max(math.floor(sec + 0.5), 0)
	if sec < 60 then return sec .. "s" end
	local m, s = math.floor(sec / 60), sec % 60
	return s == 0 and (m .. "m") or (m .. "m " .. s .. "s")
end
local function toast(text, key, bad) UI.toast(text, key and ICON[key], bad and "bad" or nil) end

-- a node's state: done / running / open / level (waiting for a hotel level) / locked (needs other research)
local function nodeState(st, n)
	if st.done[n.id] then return "done" end
	if st.cur == n.id then return "running" end
	if Research.available(st, n.id) then
		return Levels.researchOk(hotel(), n.id) and "open" or "level"
	end
	return "locked"
end

---------------------------------------------------------------- the page (round 10c: the lab is the Menu's Research tab)

local W, H = 1240, 780
-- Coop owns the window and its tab bar; the lab builds into its Page_research frame (W x H, with the
-- first 64 px hidden under the menu's tabs), so switching tabs never closes and reopens a screen
local menuGui = pgui:WaitForChild("Coop")
local body = menuGui:WaitForChild("Screen"):WaitForChild("Panel"):WaitForChild("Body"):WaitForChild("Page_research")
local close -- forward

---------------------------------------------------------------- the lab strip

local strip = UI.new("Frame", { Name = "Lab", Size = UDim2.new(1, -44, 0, 92), Position = UDim2.fromOffset(22, 64), BackgroundColor3 = T.ink2, Parent = body })
UI.corner(strip, 18)
local stripStroke = UI.stroke(strip, 2, T.line, 0.3)
local stripGrad = UI.grad(strip, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 210, 236), 90)
local flaskBg = UI.new("Frame", { Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = false, Parent = strip })
UI.corner(flaskBg, 36)
UI.grad(flaskBg, Color3.fromRGB(200, 174, 255), T.violetDk, 90)
UI.stroke(flaskBg, 3, Color3.fromRGB(50, 30, 100), 0)
local flask = UI.icon(flaskBg, ICON.research, 54, { Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
local bubbles = UI.new("Frame", { Size = UDim2.fromOffset(72, 120), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = flaskBg })
local labTitle = UI.label(strip, "", 20, { FontFace = UI.F.black, Position = UDim2.fromOffset(100, 14), Size = UDim2.new(1, -420, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd })
local labSub = UI.label(strip, "", 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(100, 40), Size = UDim2.new(1, -420, 0, 18) })
local labBar = UI.new("Frame", { Size = UDim2.new(1, -420, 0, 16), Position = UDim2.fromOffset(100, 64), BackgroundColor3 = T.ink, ClipsDescendants = true, Parent = strip })
UI.corner(labBar, 8)
UI.stroke(labBar, 1, T.line, 0.4)
local labFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = labBar })
UI.corner(labFill, 8)
UI.grad(labFill, Color3.fromRGB(214, 194, 255), T.violetDk, 90)
local shine = UI.new("Frame", { Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.fromScale(-0.2, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 3, Parent = labFill })
UI.grad(shine, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
-- right side: time left (while running) or the total done
local labTime = UI.label(strip, "", 30, { FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -306, 0, 0), Size = UDim2.new(0, 150, 1, 0) })
local totalChip = UI.new("Frame", { Size = UDim2.fromOffset(150, 64), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.ink, Parent = strip })
UI.corner(totalChip, 14)
UI.stroke(totalChip, 1.5, T.line, 0.4)
local totalNum = UI.label(totalChip, "0 / 33", 22, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 26) })
UI.label(totalChip, "researched", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 16) })
local totalBar = UI.new("Frame", { Size = UDim2.new(1, -28, 0, 4), Position = UDim2.new(0, 14, 1, -10), BackgroundColor3 = T.ink3, Parent = totalChip })
UI.corner(totalBar, 2)
local totalFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.gold, Parent = totalBar })
UI.corner(totalFill, 2)
local stopBtn = UI.button(strip, {
	text = "Stop", kind = "red", size = UDim2.fromOffset(120, 46), pos = UDim2.new(1, -14, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 18, radius = 13,
	onClick = function(b)
		local st = state()
		local n = st.cur and Research.BY_ID[st.cur]
		if not n then return end
		if not b:GetAttribute("Armed") then
			b:SetAttribute("Armed", true)
			b.Row.Label.Text = "Sure?"
			UI.pop(b, 1.15)
			task.delay(3, function() if b.Parent then b:SetAttribute("Armed", nil) b.Row.Label.Text = "Stop" end end)
			return
		end
		b:SetAttribute("Armed", nil)
		b.Row.Label.Text = "Stop"
		local ok, res = Remote:InvokeServer("cancel")
		if ok then toast("Stopped " .. n.name .. ". $" .. UI.commas(res) .. " back", "cash") else toast(res, "close", true) end
	end,
})

---------------------------------------------------------------- branches (round 14: a sidebar in three groups)

-- left: every branch in a list grouped by what it's for, each with its own done count and a gold dot when
-- something in it can start now. Middle: the chosen branch's tree. Right: the node card.
local SIDE_W, CARD_W = 200, 326
local TREE_X = 22 + SIDE_W + 12
local CARD_X = W - 22 - CARD_W
local LEFT_W = CARD_X - 14 - TREE_X -- the tree's width
local GROUPS = {
	{ name = "BUILDING", ids = { "build", "decor", "comfort", "fun" } },
	{ name = "RUNNING THE HOTEL", ids = { "service", "perks", "upkeep", "dining" } },
	{ name = "GUESTS AND STAFF", ids = { "guests", "stay", "market", "staff" } },
}
do -- any branch not named above joins the last group
	local seen = {}
	for _, g in ipairs(GROUPS) do for _, id in ipairs(g.ids) do seen[id] = true end end
	for _, br in ipairs(Research.BRANCHES) do
		if not seen[br.id] then table.insert(GROUPS[#GROUPS].ids, br.id) end
	end
end

local side = UI.new("Frame", { Name = "Branches", Size = UDim2.new(0, SIDE_W, 1, -170 - 22), Position = UDim2.fromOffset(22, 170), BackgroundColor3 = T.ink, BackgroundTransparency = 0.3, Parent = body })
UI.corner(side, 18)
UI.stroke(side, 1.5, T.line, 0.5)
local sideList = UI.new("ScrollingFrame", {
	Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.gold, Parent = side,
})
UI.list(sideList, Enum.FillDirection.Vertical, 2)
local branchBtns = {}
local current = "build"
local showBranch -- forward

local function styleRow(bb, on, hover)
	UI.tween(bb.button, 0.18, {
		BackgroundTransparency = on and 0 or (hover and 0.45 or 1),
		BackgroundColor3 = on and bb.color:Lerp(T.ink2, 0.74) or T.ink3,
	})
	UI.tween(bb.stroke, 0.18, { Transparency = on and 0.15 or 1 })
	UI.tween(bb.accent, 0.18, { BackgroundTransparency = on and 0 or 1, Size = UDim2.fromOffset(4, on and 26 or 10) })
	UI.tween(bb.name, 0.18, { TextColor3 = (on or hover) and T.cream or T.muted })
end

local order = 0
for gi, g in ipairs(GROUPS) do
	order += 1
	local head = UI.label(sideList, g.name, 11, { FontFace = UI.F.black, TextColor3 = T.gold, TextYAlignment = Enum.TextYAlignment.Bottom, Size = UDim2.new(1, 0, 0, gi == 1 and 18 or 24), LayoutOrder = order })
	UI.pad(head, 10, 0, 0, 4)
	for _, id in ipairs(g.ids) do
		local br = BRANCH[id]
		if br then
			order += 1
			local btn = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -4, 0, 38), BackgroundColor3 = T.ink3, BackgroundTransparency = 1, LayoutOrder = order, Parent = sideList })
			UI.corner(btn, 11)
			local st = UI.stroke(btn, 1.5, br.color, 1)
			local accent = UI.new("Frame", { Size = UDim2.fromOffset(4, 10), Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = br.color, BackgroundTransparency = 1, Parent = btn })
			UI.corner(accent, 2)
			UI.icon(btn, ICON[BRANCH_ICON[id]], 28, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
			local name = UI.label(btn, br.name, 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(48, 3), Size = UDim2.new(1, -94, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			local count = UI.label(btn, "", 12, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -50, 0, 3), Size = UDim2.fromOffset(42, 18) })
			local bar = UI.new("Frame", { Size = UDim2.new(1, -58, 0, 4), Position = UDim2.fromOffset(48, 25), BackgroundColor3 = T.ink, Parent = btn })
			UI.corner(bar, 2)
			local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = br.color, Parent = bar })
			UI.corner(fill, 2)
			local ready = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(34, 6), BackgroundColor3 = T.gold, Visible = false, ZIndex = 3, Parent = btn })
			UI.corner(ready, 5)
			UI.stroke(ready, 1.5, T.ink, 0)
			local bb = { button = btn, stroke = st, accent = accent, name = name, count = count, fill = fill, ready = ready, color = br.color }
			branchBtns[id] = bb
			btn.MouseEnter:Connect(function() if current ~= id then styleRow(bb, false, true) UI.sound("Hover") end end)
			btn.MouseLeave:Connect(function() styleRow(bb, current == id, false) end)
			btn.Activated:Connect(function()
				if current ~= id then UI.sound("Tab") showBranch(id) end
			end)
		end
	end
end

---------------------------------------------------------------- the tree

local TREE_Y = 170
local HEAD_H = 56
local tree = UI.new("Frame", {
	Name = "Tree", Size = UDim2.new(0, LEFT_W, 1, -TREE_Y - 22), Position = UDim2.fromOffset(TREE_X, TREE_Y), BackgroundColor3 = T.ink,
	BackgroundTransparency = 0.3, ClipsDescendants = true, Parent = body,
})
UI.corner(tree, 18)
UI.stroke(tree, 1.5, T.line, 0.5)
-- faint blueprint grid behind the nodes
local gridImg = UI.new("ImageLabel", {
	Image = ICON.gridPlate, ImageTransparency = 0.93, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(160, 160),
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = tree,
})
-- the branch header: its name, how far along it is, and what the node colours mean
local tHead = UI.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, HEAD_H), BackgroundTransparency = 1, ZIndex = 4, Parent = tree })
local tHeadTint = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = tHead })
local tHeadGrad = UI.grad(tHeadTint, T.gold, T.ink, 0)
tHeadGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) })
UI.new("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 1, -1), BackgroundColor3 = T.line, BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 5, Parent = tHead })
local tHeadDisc = UI.new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = tHead })
UI.corner(tHeadDisc, 19)
local tHeadDiscGrad = UI.grad(tHeadDisc, T.gold, T.goldDk, 90)
UI.stroke(tHeadDisc, 2, T.ink, 0)
local tHeadIcon = UI.icon(tHeadDisc, ICON.research, 28, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 })
local tHeadName = UI.label(tHead, "", 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(60, 8), Size = UDim2.new(1, -330, 0, 22), ZIndex = 5, TextTruncate = Enum.TextTruncate.AtEnd })
local tHeadSub = UI.label(tHead, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(60, 31), Size = UDim2.new(1, -330, 0, 16), ZIndex = 5 })
local legend = UI.new("Frame", { Size = UDim2.fromOffset(260, 20), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundTransparency = 1, ZIndex = 5, Parent = tHead })
UI.list(legend, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
for i, l in ipairs({ { "Ready", T.gold }, { "In lab", T.blue }, { "Done", T.green }, { "Locked", T.line } }) do
	local it = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 5, Parent = legend })
	UI.list(it, Enum.FillDirection.Horizontal, 5, nil, Enum.VerticalAlignment.Center)
	local dot = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = T.ink2, LayoutOrder = 1, ZIndex = 5, Parent = it })
	UI.corner(dot, 5)
	UI.stroke(dot, 2.5, l[2], 0)
	UI.new("TextLabel", { Text = l[1], TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.muted, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, ZIndex = 5, Parent = it })
end
-- round 13: bigger branches scroll (drag or wheel) inside the tree panel
local treeCanvas = UI.new("ScrollingFrame", {
	Name = "Canvas", Size = UDim2.new(1, 0, 1, -HEAD_H), Position = UDim2.fromOffset(0, HEAD_H), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 6, ScrollBarImageColor3 = T.gold, ScrollBarImageTransparency = 0.35,
	ElasticBehavior = Enum.ElasticBehavior.Always, ZIndex = 2, Parent = tree,
})
local lineLayer = UI.new("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = treeCanvas })
local nodeLayer = UI.new("Frame", { Name = "Nodes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = treeCanvas })

local NODE = 84
local nodes = {} -- id -> node gui bits
local lines = {} -- { from, to, frame }
local selected

local select -- forward

-- a tick drawn with two bars (no glyph fonts)
local function tick(parent, size, color)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, ZIndex = 6, Parent = parent })
	UI.corner(f, size / 2)
	UI.stroke(f, 2, T.ink, 0)
	local a = UI.new("Frame", { Size = UDim2.fromOffset(size * 0.3, 3), Position = UDim2.fromScale(0.36, 0.56), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = T.cream, ZIndex = 7, Parent = f })
	UI.corner(a, 2)
	local b = UI.new("Frame", { Size = UDim2.fromOffset(size * 0.52, 3), Position = UDim2.fromScale(0.58, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -50, BackgroundColor3 = T.cream, ZIndex = 7, Parent = f })
	UI.corner(b, 2)
	return f
end

local function makeNode(n, x, y)
	local br = BRANCH[n.branch]
	local slot = UI.new("TextButton", { Name = n.id, Text = "", Size = UDim2.fromOffset(124, 136), Position = UDim2.fromOffset(x, y), AnchorPoint = Vector2.new(0.5, 0.36), BackgroundTransparency = 1, ZIndex = 3, Parent = nodeLayer })
	local halo = UI.new("Frame", { Name = "Halo", Size = UDim2.fromOffset(NODE + 22, NODE + 22), Position = UDim2.new(0.5, 0, 0, NODE / 2 + 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = br.color, BackgroundTransparency = 1, ZIndex = 3, Parent = slot })
	UI.corner(halo, (NODE + 22) / 2)
	local sel = UI.new("Frame", { Name = "Sel", Size = UDim2.fromOffset(NODE + 14, NODE + 14), Position = UDim2.new(0.5, 0, 0, NODE / 2 + 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3, Parent = slot })
	UI.corner(sel, (NODE + 14) / 2)
	local selStroke = UI.stroke(sel, 3, T.cream, 1)
	local disc = UI.new("Frame", { Name = "Disc", Size = UDim2.fromOffset(NODE, NODE), Position = UDim2.new(0.5, 0, 0, NODE / 2 + 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = slot })
	UI.corner(disc, NODE / 2)
	local grad = UI.grad(disc, br.color:Lerp(Color3.new(1, 1, 1), 0.25), br.color:Lerp(Color3.new(0, 0, 0), 0.35), 90)
	local ring = UI.stroke(disc, 3, T.line, 0)
	local gloss = UI.new("Frame", { Size = UDim2.new(0.64, 0, 0.28, 0), Position = UDim2.fromScale(0.5, 0.08), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, ZIndex = 5, Parent = disc })
	UI.corner(gloss, 20)
	local ic = UI.icon(disc, iconOf(n), 56, { Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 })
	local name = UI.label(slot, n.name, 14, {
		FontFace = UI.F.black, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, NODE + 14), Size = UDim2.new(1, 0, 0, 36), ZIndex = 4,
	})
	UI.textStroke(name, 2, 0.2)
	-- corner badges: a tick when done, a lock or the level it needs otherwise
	local tk = tick(disc, 26, T.green)
	tk.Position = UDim2.new(1, 4, 0, -4)
	tk.AnchorPoint = Vector2.new(1, 0)
	local lock = UI.icon(disc, ICON.lock, 30, { Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 7 })
	local lvChip = UI.new("TextLabel", {
		Text = "LV " .. Levels.researchLevel(n.id), TextSize = 13, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(60, 40, 10), BackgroundColor3 = T.gold,
		Size = UDim2.fromOffset(42, 22), Position = UDim2.new(1, 10, 0, -6), AnchorPoint = Vector2.new(1, 0), ZIndex = 7, Parent = disc,
	})
	UI.corner(lvChip, 8)
	UI.stroke(lvChip, 2, T.ink, 0)
	-- a ring that fills while running (a bar under the disc)
	local prog = UI.new("Frame", { Size = UDim2.fromOffset(64, 7), Position = UDim2.new(0.5, 0, 0, NODE + 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.ink, Visible = false, ZIndex = 7, Parent = slot })
	UI.corner(prog, 4)
	UI.stroke(prog, 1.5, T.ink, 0)
	local progFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.blue, ZIndex = 7, Parent = prog })
	UI.corner(progFill, 4)
	local sc = UI.scaleOf(disc)
	slot.MouseEnter:Connect(function()
		UI.tween(sc, 0.18, { Scale = 1.08 }, Enum.EasingStyle.Back)
		UI.sound("Hover")
	end)
	slot.MouseLeave:Connect(function() UI.tween(sc, 0.2, { Scale = 1 }) end)
	slot.MouseButton1Down:Connect(function() UI.tween(sc, 0.08, { Scale = 0.92 }) end)
	slot.Activated:Connect(function()
		UI.tween(sc, 0.3, { Scale = 1.08 }, Enum.EasingStyle.Back)
		if selected ~= n.id then UI.sound("Select") end
		select(n.id)
	end)
	nodes[n.id] = {
		node = n, slot = slot, halo = halo, sel = selStroke, disc = disc, grad = grad, ring = ring, icon = ic, name = name,
		tick = tk, lock = lock, lv = lvChip, prog = prog, progFill = progFill, x = x,
	}
end

local function lineBetween(a, b)
	local d = b - a
	local f = UI.new("Frame", {
		Size = UDim2.fromOffset(d.Magnitude, 5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		AnchorPoint = Vector2.new(0.5, 0.5), Rotation = math.deg(math.atan2(d.Y, d.X)), BackgroundColor3 = T.line, BorderSizePixel = 0, ZIndex = 2, Parent = lineLayer,
	})
	UI.corner(f, 3)
	return f
end

---------------------------------------------------------------- the node card (right)

local card = UI.new("Frame", { Name = "Card", Size = UDim2.new(0, CARD_W, 1, -170 - 22), Position = UDim2.fromOffset(CARD_X, 170), BackgroundColor3 = T.ink2, Parent = body })
UI.corner(card, 18)
local cardStroke = UI.stroke(card, 2, T.line, 0.3)
UI.grad(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(206, 210, 230), 90)
local cardTop = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
UI.corner(cardTop, 18)
local cardTopGrad = UI.grad(cardTop, T.gold, T.ink2, 90)
cardTopGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
local cDisc = UI.new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
UI.corner(cDisc, 48)
local cDiscGrad = UI.grad(cDisc, T.gold, T.goldDk, 90)
UI.stroke(cDisc, 3, T.ink, 0)
local cIcon = UI.icon(cDisc, ICON.research, 66, { Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5) })
local cBranch = UI.new("TextLabel", { Text = "", TextSize = 12, FontFace = UI.F.black, TextColor3 = T.outline or T.ink, BackgroundColor3 = T.gold, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Position = UDim2.fromOffset(128, 22), Parent = card })
UI.corner(cBranch, 6)
UI.pad(cBranch, 8, 0, 8, 0)
local cName = UI.label(card, "", 24, { FontFace = UI.F.black, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(128, 46), Size = UDim2.new(1, -144, 0, 56) })
local cStatus = UI.label(card, "", 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 126), Size = UDim2.new(1, -36, 0, 18) })
local cDesc = UI.label(card, "", 15, {
	FontFace = UI.F.body, TextColor3 = T.cream, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(18, 150), Size = UDim2.new(1, -36, 0, 58),
})
UI.label(card, "UNLOCKS", 13, { FontFace = UI.F.black, TextColor3 = T.goldDk, Position = UDim2.fromOffset(18, 212), Size = UDim2.new(1, -36, 0, 16) })
local unlockBox = UI.new("Frame", { Size = UDim2.new(1, -36, 0, 220), Position = UDim2.fromOffset(18, 232), BackgroundTransparency = 1, Parent = card })
local unlockGrid = Instance.new("UIGridLayout")
unlockGrid.CellSize = UDim2.new(0.5, -5, 0, 105)
unlockGrid.CellPadding = UDim2.fromOffset(10, 10)
unlockGrid.SortOrder = Enum.SortOrder.LayoutOrder
unlockGrid.Parent = unlockBox
-- footer: cost, time and the action
local foot = UI.new("Frame", { Size = UDim2.new(1, -36, 0, 104), Position = UDim2.new(0, 18, 1, -114), BackgroundTransparency = 1, Parent = card })
local costRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = foot })
UI.icon(costRow, ICON.cash, 30, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
local cCost = UI.label(costRow, "", 22, { FontFace = UI.F.black, TextColor3 = T.green, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(0.5, -36, 1, 0) })
UI.icon(costRow, ICON.clock, 26, { Position = UDim2.new(0.5, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
local cTime = UI.label(costRow, "", 18, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.new(0.5, 38, 0, 0), Size = UDim2.new(0.5, -38, 1, 0) })
local actBtn, actLabel = UI.button(foot, {
	text = "Start research", icon = ICON.research, iconSize = 26, kind = "gold", size = UDim2.new(1, 0, 0, 56), pos = UDim2.new(0, 0, 1, -4), anchor = Vector2.new(0, 1), textSize = 20, radius = 15,
	onClick = function(b)
		local n = selected and Research.BY_ID[selected]
		if not n then return end
		local s = nodeState(state(), n)
		if s ~= "open" then
			UI.shake(b)
			return
		end
		local ok, res = Remote:InvokeServer("start", n.id)
		if ok then
			UI.sound("Place")
			local nd = nodes[n.id]
			if nd then UI.pop(nd.disc, 1.3, 0.5) end
		else
			UI.shake(b)
			toast(res or "Can't research that yet", "close", true)
		end
	end,
})

-- 3D previews of unlocked furniture: a model turning slowly in a ViewportFrame
local spinning = {}
local function preview(parent, id)
	local it = Catalog.ITEMS[id]
	local src = it and (it.shape or ITEMS:FindFirstChild(id))
	local vf = UI.new("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -30), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(-1, -1.4, -0.8), Parent = parent,
	})
	if not src then
		UI.icon(parent, ICON.hammer, 54, { Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0) })
		return
	end
	local m = Build.make(id, CFrame.new(), { color = Catalog.SWATCHES[(#spinning % #Catalog.SWATCHES) + 1], mat = it.shape and "Marble" or nil })
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") or d:IsA("ProximityPrompt") or d:IsA("Sound") or d:IsA("ParticleEmitter") then d:Destroy() end
	end
	local cf, size = m:GetBoundingBox()
	m:PivotTo(cf:Inverse() * m:GetPivot()) -- its bounding box centred on the origin
	m.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local r = math.max(size.X, size.Y, size.Z)
	local dist = r * 0.9 / math.tan(math.rad(15))
	cam.CFrame = CFrame.lookAt(Vector3.new(0, r * 0.45, dist * 0.92), Vector3.new(0, 0, 0))
	cam.Parent = vf
	vf.CurrentCamera = cam
	table.insert(spinning, { model = m, base = m:GetPivot(), t = math.random() * 6 })
end

local function unlockTile(order, build)
	local t = UI.new("Frame", { BackgroundColor3 = T.ink, LayoutOrder = order, Parent = unlockBox })
	UI.corner(t, 14)
	UI.stroke(t, 1.5, T.line, 0.45)
	build(t)
	UI.pop(t, 0.7, 0.35)
	return t
end
local function tileLabel(t, text)
	UI.label(t, text, 13, { FontFace = UI.F.heavy, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 6, 1, -24), Size = UDim2.new(1, -12, 0, 18) })
end

local function fillUnlocks(n)
	table.clear(spinning)
	for _, c in ipairs(unlockBox:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local order = 0
	local items = UNLOCK_ITEMS[n.id] or {}
	local room = 4
	if n.event then
		order += 1
		room -= 1
		local ev = n.event
		unlockTile(order, function(t)
			UI.icon(t, iconOf(n), 54, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
			tileLabel(t, "New guests: " .. (ev == "allnighter" and "night owls" or ev))
		end)
	end
	if n.perk then
		order += 1
		room -= 1
		unlockTile(order, function(t)
			UI.icon(t, ICON.upgrade, 54, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
			tileLabel(t, "Upgrade")
		end)
	end
	local mats = UNLOCK_MATS[n.id]
	if mats and #mats > 0 then
		order += 1
		room -= 1
		unlockTile(order, function(t)
			UI.icon(t, ICON.paint, 54, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
			tileLabel(t, #mats .. " new finish" .. (#mats == 1 and "" or "es"))
			UI.tooltip(t, table.concat(mats, ", "))
		end)
	end
	local more = #items - room
	if more > 0 then room -= 1 end
	for i = 1, math.min(#items, math.max(room, 0)) do
		local id = items[i]
		order += 1
		unlockTile(order, function(t)
			preview(t, id)
			tileLabel(t, Catalog.ITEMS[id].name)
		end)
	end
	if more > 0 then
		order += 1
		unlockTile(order, function(t)
			local names = {}
			for i = math.max(room, 0) + 1, #items do table.insert(names, Catalog.ITEMS[items[i]].name) end
			UI.label(t, "+" .. (#items - math.max(room, 0)), 30, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 36) })
			tileLabel(t, "more items")
			UI.tooltip(t, table.concat(names, ", "))
		end)
	end
	if order == 0 then
		order += 1
		unlockTile(order, function(t)
			UI.icon(t, ICON.sparkle, 54, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
			tileLabel(t, "New options")
		end)
	end
end

---------------------------------------------------------------- refresh

local STATE_COLOR = { done = T.green, running = T.blue, open = T.gold, level = T.line, locked = T.line }

local function refresh()
	local st = state()
	local h = hotel()
	local now = os.time()
	local cash = player:GetAttribute("Cash") or 0
	-- branch tabs
	local total, doneN = 0, 0
	for _, b in ipairs(Research.BRANCHES) do
		local n, d, ready, open, waitLv = 0, 0, false, 0, 0
		for _, node in ipairs(Research.NODES) do
			if node.branch == b.id then
				n += 1
				local ns = nodeState(st, node)
				if ns == "done" then d += 1 end
				if ns == "open" then open += 1 end
				if ns == "level" then waitLv += 1 end
				if not st.cur and ns == "open" and cash >= node.cost then ready = true end
			end
		end
		total += n
		doneN += d
		local bb = branchBtns[b.id]
		if bb then
			UI.tween(bb.fill, 0.4, { Size = UDim2.fromScale(n > 0 and d / n or 0, 1) })
			bb.ready.Visible = ready
			bb.count.Text = d .. "/" .. n
			bb.count.TextColor3 = (d == n and n > 0) and T.green or T.muted
		end
		if b.id == current then
			local bits = { d .. " of " .. n .. " researched" }
			if d == n and n > 0 then bits = { "All " .. n .. " researched" } end
			if open > 0 then table.insert(bits, open .. " ready") end
			if waitLv > 0 then table.insert(bits, waitLv .. " need a higher level") end
			tHeadSub.Text = table.concat(bits, "   |   ")
		end
	end
	totalNum.Text = doneN .. " / " .. total
	UI.tween(totalFill, 0.4, { Size = UDim2.fromScale(total > 0 and doneN / total or 0, 1) })
	-- the lab strip
	local cur = st.cur and Research.BY_ID[st.cur]
	stopBtn.Visible = cur ~= nil
	labBar.Visible = cur ~= nil
	labTime.Visible = cur ~= nil
	totalChip.Visible = cur == nil
	if cur then
		local len = st.len or Research.duration(st, cur.id)
		local left = math.max((st.ends or now) - now, 0)
		flask.Image = iconOf(cur)
		labTitle.Text = "Researching " .. cur.name
		labSub.Text = BRANCH[cur.branch].name .. "  |  done in " .. clock(left)
		UI.tween(labFill, 0.5, { Size = UDim2.fromScale(math.clamp(1 - left / math.max(len, 1), 0, 1), 1) }, Enum.EasingStyle.Linear)
		labTime.Text = clock(left)
		stripStroke.Color = T.violet
	else
		flask.Image = ICON.research
		labTitle.Text = "The lab is free"
		local waiting = 0
		for _, node in ipairs(Research.NODES) do
			if nodeState(st, node) == "level" then waiting += 1 end
		end
		labSub.Text = waiting > 0 and ("Pick a glowing node to start. " .. waiting .. " more open as your hotel levels up") or "Pick a glowing node to start"
		stripStroke.Color = T.line
	end
	-- nodes
	for id, nd in pairs(nodes) do
		local n = nd.node
		local s = nodeState(st, n)
		local col = STATE_COLOR[s]
		local br = BRANCH[n.branch]
		local dark = s == "locked" or s == "level"
		nd.ring.Color = col
		nd.ring.Thickness = (s == "open" or s == "running") and 4 or 3
		nd.grad.Color = dark and ColorSequence.new(T.ink3, T.ink2) or ColorSequence.new(br.color:Lerp(Color3.new(1, 1, 1), 0.25), br.color:Lerp(Color3.new(0, 0, 0), 0.35))
		nd.icon.ImageTransparency = dark and 0.5 or 0
		nd.name.TextColor3 = dark and T.muted or T.cream
		nd.tick.Visible = s == "done"
		nd.lock.Visible = s == "locked"
		nd.lv.Visible = s == "level"
		nd.prog.Visible = s == "running"
		nd.halo.BackgroundColor3 = s == "running" and T.blue or T.gold
		nd.state = s
		if s == "running" then
			local len = st.len or Research.duration(st, id)
			nd.progFill.Size = UDim2.fromScale(math.clamp(1 - math.max((st.ends or now) - now, 0) / math.max(len, 1), 0, 1), 1)
		end
		nd.sel.Transparency = selected == id and 0 or 1
	end
	for _, l in ipairs(lines) do
		local lit = st.done[l.from]
		l.frame.BackgroundColor3 = lit and BRANCH[Research.BY_ID[l.to].branch].color or T.line
		l.frame.BackgroundTransparency = lit and 0.05 or 0.45
	end
	-- the card
	local n = selected and Research.BY_ID[selected]
	if n then
		local s = nodeState(st, n)
		cCost.Text = "$" .. UI.commas(n.cost)
		cCost.TextColor3 = (s == "done" and T.muted) or (cash >= n.cost and T.green) or T.red
		cTime.Text = clock(Research.duration(st, n.id))
		cardStroke.Color = STATE_COLOR[s]
		local need = {}
		for _, r in ipairs(n.req or {}) do
			if not st.done[r] then
				local rn = Research.BY_ID[r]
				table.insert(need, rn.name .. (rn.branch ~= n.branch and (" (" .. BRANCH[rn.branch].name .. ")") or ""))
			end
		end
		if s == "done" then
			cStatus.Text = "Researched"
			cStatus.TextColor3 = T.green
			actLabel.Text = "Researched"
			UI.setKind(actBtn, "green")
		elseif s == "running" then
			cStatus.Text = "In the lab now: " .. clock(math.max((st.ends or now) - now, 0)) .. " left"
			cStatus.TextColor3 = T.blue
			actLabel.Text = "Researching..."
			UI.setKind(actBtn, "blue")
		elseif s == "level" then
			cStatus.Text = "Reach hotel level " .. Levels.researchLevel(n.id) .. " to research this"
			cStatus.TextColor3 = T.gold
			actLabel.Text = "Hotel level " .. Levels.researchLevel(n.id)
			UI.setKind(actBtn, "ghost")
		elseif s == "locked" then
			cStatus.Text = "Needs " .. table.concat(need, " + ")
			cStatus.TextColor3 = T.muted
			actLabel.Text = "Locked"
			UI.setKind(actBtn, "ghost")
		elseif st.cur then
			cStatus.Text = "Ready once the lab is free"
			cStatus.TextColor3 = T.gold
			actLabel.Text = "Lab busy"
			UI.setKind(actBtn, "ghost")
		else
			cStatus.Text = cash >= n.cost and "Ready to research" or ("You need $" .. UI.commas(n.cost - cash) .. " more")
			cStatus.TextColor3 = cash >= n.cost and T.green or T.red
			actLabel.Text = "Start research"
			UI.setKind(actBtn, cash >= n.cost and "gold" or "ghost")
		end
	end
end

select = function(id, quiet)
	local n = Research.BY_ID[id]
	if not n then return end
	selected = id
	local br = BRANCH[n.branch]
	cDiscGrad.Color = ColorSequence.new(br.color:Lerp(Color3.new(1, 1, 1), 0.25), br.color:Lerp(Color3.new(0, 0, 0), 0.35))
	cardTopGrad.Color = ColorSequence.new(br.color, T.ink2)
	cIcon.Image = iconOf(n)
	cBranch.Text = string.upper(br.name)
	cBranch.BackgroundColor3 = br.color
	cName.Text = n.name
	cDesc.Text = n.desc
	fillUnlocks(n)
	refresh()
	if not quiet then
		UI.pop(cDisc, 0.6, 0.4)
	end
end

-- lay out a branch: tiers left to right, each tier's nodes stacked and centred
showBranch = function(id, focus)
	current = id
	for bid, bb in pairs(branchBtns) do styleRow(bb, bid == id, false) end
	local br = BRANCH[id]
	tHeadName.Text = br.name
	tHeadIcon.Image = ICON[BRANCH_ICON[id]] or ICON.research
	tHeadDiscGrad.Color = ColorSequence.new(br.color:Lerp(Color3.new(1, 1, 1), 0.25), br.color:Lerp(Color3.new(0, 0, 0), 0.35))
	tHeadGrad.Color = ColorSequence.new(br.color, T.ink)
	UI.pop(tHeadDisc, 0.7, 0.35)
	for _, c in ipairs(nodeLayer:GetChildren()) do c:Destroy() end
	for _, c in ipairs(lineLayer:GetChildren()) do c:Destroy() end
	table.clear(nodes)
	table.clear(lines)
	local tiers, maxTier = {}, 0
	for _, n in ipairs(Research.NODES) do
		if n.branch == id then
			tiers[n.row] = tiers[n.row] or {}
			table.insert(tiers[n.row], n)
			maxTier = math.max(maxTier, n.row)
		end
	end
	local tw, th = LEFT_W, H - TREE_Y - 22 - HEAD_H
	-- round 13: a fixed grid that grows the canvas instead of squeezing the nodes
	-- round 14: each tier is a labelled column (STEP 1, STEP 2...) so the order reads left to right
	local TOP = 34
	local colW, stack = 124, 1
	for r = 1, maxTier do stack = math.max(stack, #(tiers[r] or {})) end
	-- the rows squeeze a little so a four-tall column still fits without scrolling
	local rowH = math.clamp(math.floor((th - TOP - 8) / stack), 116, 128)
	local cw = math.max(tw, colW * maxTier + 24)
	local ch = math.max(th, rowH * stack + TOP + 8)
	treeCanvas.CanvasSize = UDim2.fromOffset(cw, ch)
	treeCanvas.CanvasPosition = Vector2.new(0, 0)
	local x0 = cw / 2 - colW * (maxTier - 1) / 2
	local midY = TOP + (ch - TOP) / 2
	for r = 1, maxTier do
		local cx = x0 + (r - 1) * colW
		local band = UI.new("Frame", { Name = "Step" .. r, Size = UDim2.new(0, colW - 12, 1, -12), Position = UDim2.fromOffset(cx, 6), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = r % 2 == 1 and 0.965 or 0.985, ZIndex = 1, Parent = lineLayer })
		UI.corner(band, 14)
		UI.label(band, "STEP " .. r, 11, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 16), ZIndex = 1 })
		local list = tiers[r] or {}
		for i, n in ipairs(list) do
			local y = midY + (i - (#list + 1) / 2) * rowH - 18
			makeNode(n, cx, y)
		end
	end
	-- lines from each requirement in this branch (centre to centre: the discs cover the ends)
	for _, nd in pairs(nodes) do
		for _, r in ipairs(nd.node.req or {}) do
			local from = nodes[r]
			if from then
				local a = Vector2.new(from.x, from.slot.Position.Y.Offset - 136 * 0.36 + NODE / 2 + 4)
				local b = Vector2.new(nd.x, nd.slot.Position.Y.Offset - 136 * 0.36 + NODE / 2 + 4)
				table.insert(lines, { from = r, to = nd.node.id, frame = lineBetween(a, b), a = a, b = b })
			end
		end
	end
	-- the first node to look at: the focus, the running one, the first open one, or the first
	local st = state()
	local pick = focus and nodes[focus] and focus
	if not pick then
		for _, n in ipairs(Research.NODES) do
			if n.branch == id and st.cur == n.id then pick = n.id end
		end
	end
	if not pick then
		for _, n in ipairs(Research.NODES) do
			if n.branch == id and nodes[n.id] and nodeState(st, n) == "open" then pick = n.id break end
		end
	end
	if not pick then
		for _, n in ipairs(Research.NODES) do
			if n.branch == id then pick = n.id break end
		end
	end
	select(pick, true)
	-- nodes arrive tier by tier
	for _, nd in pairs(nodes) do
		local s = UI.scaleOf(nd.slot)
		s.Scale = 0.4
		UI.tween(s, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, (nd.node.row - 1) * 0.07)
	end
	for _, l in ipairs(lines) do
		local full = l.frame.Size
		l.frame.Size = UDim2.fromOffset(0, 5)
		UI.tween(l.frame, 0.35, { Size = full }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0.15 + (Research.BY_ID[l.to].row - 1) * 0.07)
	end
	if focus and nodes[focus] then
		task.delay(0.35, function()
			local nd = nodes[focus]
			if nd then UI.pop(nd.disc, 1.35, 0.55) end
		end)
	end
end

---------------------------------------------------------------- open / close

-- the menu shows and hides the page; ResearchOpen says when it's on screen
local isOpen = player:GetAttribute("ResearchOpen") == true
player:GetAttributeChangedSignal("ResearchOpen"):Connect(function()
	local on = player:GetAttribute("ResearchOpen") == true
	if on == isOpen then return end
	isOpen = on
	if on then refresh() else table.clear(spinning) end
end)

local function open(focus)
	local h = hotel()
	if not h then toast("Get a hotel first", "research", true) return end
	local branch = current
	if typeof(focus) == "string" and Research.BY_ID[focus] then branch = Research.BY_ID[focus].branch else focus = nil end
	if isOpen and not focus then return end
	if not focus then
		-- open on the running node's branch
		local st = state()
		if st.cur and Research.BY_ID[st.cur] then branch = Research.BY_ID[st.cur].branch end
	end
	player:SetAttribute("MenuWant", "research")
	showBranch(branch, focus)
end

close = function()
	if isOpen then player:SetAttribute("MenuWant", "close") end
end

player:GetAttributeChangedSignal("OpenResearch"):Connect(function()
	local v = player:GetAttribute("OpenResearch")
	if v == nil then return end
	player:SetAttribute("OpenResearch", nil)
	if v == false then close() return end
	open(v ~= true and v or nil)
end)

UIS.InputBegan:Connect(function(io, gp)
	if gp then return end
	if (io.KeyCode == Enum.KeyCode.R or io.KeyCode == Enum.KeyCode.DPadRight) and not player:GetAttribute("Building") and player:GetAttribute("Slot") then
		if isOpen then close() else open() end
	end
end)
player:GetAttributeChangedSignal("Building"):Connect(function()
	if player:GetAttribute("Building") then close() end
end)

-- a node finishing: its disc celebrates with a burst of sparks
local function burst(nd)
	local cx, cy = nd.x, nd.slot.Position.Y.Offset - 136 * 0.36 + NODE / 2 + 4
	for k = 1, 14 do
		local a = k / 14 * math.pi * 2
		local p = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(cx, cy), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = k % 2 == 0 and T.gold or T.green, ZIndex = 8, Parent = nodeLayer })
		UI.corner(p, 5)
		UI.tween(p, 0.7, { Position = UDim2.fromOffset(cx + math.cos(a) * 90, cy + math.sin(a) * 90), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
		task.delay(0.75, function() p:Destroy() end)
	end
end
Shared.Remotes.Notify.OnClientEvent:Connect(function(kind, d)
	if kind ~= "researched" then return end
	refresh()
	local nd = d and nodes[d.id]
	if nd and isOpen then
		UI.sound("Fanfare")
		UI.pop(nd.disc, 1.4, 0.6)
		burst(nd)
	end
end)

---------------------------------------------------------------- keep it live

local function watchHotel()
	local h = hotel()
	if h then
		h:GetAttributeChangedSignal("Research"):Connect(function() if isOpen then refresh() end end)
		h:GetAttributeChangedSignal("Level"):Connect(function() if isOpen then refresh() end end)
	end
end
player:GetAttributeChangedSignal("Plot"):Connect(watchHotel)
watchHotel()
player:GetAttributeChangedSignal("Cash"):Connect(function() if isOpen then refresh() end end)

local acc, bubbleAcc, t = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
	if not isOpen then return end
	t += dt
	acc += dt
	if acc >= 0.5 then
		acc = 0
		refresh()
	end
	-- glowing halos: open nodes breathe gold, the running one pulses blue
	for _, nd in pairs(nodes) do
		if nd.state == "open" then
			nd.halo.BackgroundTransparency = 0.72 + math.sin(t * 3) * 0.12
		elseif nd.state == "running" then
			nd.halo.BackgroundTransparency = 0.6 + math.sin(t * 6) * 0.2
		else
			nd.halo.BackgroundTransparency = 1
		end
	end
	-- the lab strip: the shine runs along the bar, bubbles rise out of the flask
	local running = labBar.Visible
	shine.Position = UDim2.fromScale(((t * 0.6) % 1.6) - 0.3, 0)
	if running then
		bubbleAcc += dt
		if bubbleAcc > 0.28 then
			bubbleAcc = 0
			local s = math.random(6, 11)
			local x = math.random(22, 50)
			local b = UI.new("Frame", { Size = UDim2.fromOffset(s, s), Position = UDim2.new(0, x, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(220, 255, 230), BackgroundTransparency = 0.2, ZIndex = 3, Parent = bubbles })
			UI.corner(b, s / 2)
			UI.tween(b, 1.1, { Position = UDim2.new(0, x + math.random(-10, 10), 0, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
			task.delay(1.15, function() b:Destroy() end)
		end
		flask.Rotation = math.sin(t * 4) * 5
	else
		flask.Rotation = 0
	end
	-- furniture previews turn slowly
	for _, sp in ipairs(spinning) do
		sp.t += dt
		if sp.model.Parent then sp.model:PivotTo(CFrame.Angles(0, sp.t * 0.8, 0) * sp.base) end
	end
end)

showBranch("build")
refresh()
