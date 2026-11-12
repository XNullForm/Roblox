-- StarterPlayerScripts.ResearchUI (round 26 layout): the Research page of the menu, built into Coop's Page_research.
-- Opens with R (outside build mode), the bottom bar, or player attribute OpenResearch (true, or a node id to
-- focus it; false closes). Build mode sets it when you click a locked item.
-- Top: the lab bar (what's running, a thin bar, the time left, Stop). Left: the branches in three groups.
-- Middle: the chosen branch as steps from left to right, one flat card per project, joined by elbow lines.
-- Right: the chosen project (what it unlocks, cost, time, Start).
-- Talks to ResearchServer through Remotes.Research; reads the hotel attribute "Research" and the hotel level
-- (Shared.Levels). The menu sets player attribute ResearchOpen while the page shows.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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
local LEFT, RIGHT, CENTER, TOP = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextXAlignment.Center, Enum.TextYAlignment.Top

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

-- what a project unlocks: shop items (ids) and shape finishes (names)
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

-- done / running / open / level (waiting for a hotel level) / locked (needs other research)
local function nodeState(st, n)
	if st.done[n.id] then return "done" end
	if st.cur == n.id then return "running" end
	if Research.available(st, n.id) then
		return Levels.researchOk(hotel(), n.id) and "open" or "level"
	end
	return "locked"
end

local function text(parent, str, size, props)
	local l = UI.label(parent, str, size, { TextXAlignment = LEFT })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function caps(parent, str, props)
	local l = text(parent, string.upper(str), 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Size = UDim2.new(1, 0, 0, 16) })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function border(o, th, col, tr)
	local s = Instance.new("UIStroke")
	s.Thickness, s.Color, s.Transparency = th, col, tr or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

---------------------------------------------------------------- the page
local W, H = 1240, 830
local M = 22 -- side margin
local TOP_Y, BAR_H = 64, 64
local MAIN_Y = TOP_Y + BAR_H + 12
local MAIN_H = H - M - MAIN_Y
local SIDE_W, CARD_W = 208, 320
local TREE_X = M + SIDE_W + 14
local CARD_X = W - M - CARD_W
local TREE_W = CARD_X - 14 - TREE_X
local HEAD_H = 52

local menuGui = pgui:WaitForChild("Coop")
local body = menuGui:WaitForChild("Screen"):WaitForChild("Panel"):WaitForChild("Body"):WaitForChild("Page_research")
for _, c in ipairs(body:GetChildren()) do c:Destroy() end
local close, select, showBranch -- forward
local selected
local current = "build"
local nodes = {} -- id -> { node, card, ... }
local lines = {} -- { from, to, frames }

---------------------------------------------------------------- the lab bar
local lab = {}
do
	local bar = UI.new("Frame", { Name = "Lab", Size = UDim2.new(1, -M * 2, 0, BAR_H), Position = UDim2.fromOffset(M, TOP_Y), BackgroundColor3 = T.ink2, Parent = body })
	UI.corner(bar, 14)
	caps(bar, "The lab", { Position = UDim2.fromOffset(18, 13), Size = UDim2.fromOffset(300, 16) })
	lab.title = text(bar, "", 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(18, 30), Size = UDim2.fromOffset(330, 22), TextTruncate = Enum.TextTruncate.AtEnd })
	lab.hint = text(bar, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(360, 0), Size = UDim2.new(1, -360 - 230, 1, 0) })
	-- running: a thin bar, the time left and Stop
	lab.track = UI.new("Frame", { Size = UDim2.new(1, -360 - 260, 0, 6), Position = UDim2.new(0, 360, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink3, Parent = bar })
	UI.corner(lab.track, 3)
	lab.fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.brand, Parent = lab.track })
	UI.corner(lab.fill, 3)
	lab.time = text(bar, "", 20, { FontFace = UI.F.black, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -128, 0.5, 0), Size = UDim2.fromOffset(116, 24), TextXAlignment = RIGHT })
	lab.stop = UI.button(bar, {
		name = "Stop", text = "Stop", kind = "red", size = UDim2.fromOffset(100, 40), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 16, radius = 10,
		onClick = function(b)
			local st = state()
			local n = st.cur and Research.BY_ID[st.cur]
			if not n then return end
			if not b:GetAttribute("Armed") then
				b:SetAttribute("Armed", true)
				b.Row.Label.Text = "Sure?"
				task.delay(3, function() if b.Parent then b:SetAttribute("Armed", nil) b.Row.Label.Text = "Stop" end end)
				return
			end
			b:SetAttribute("Armed", nil)
			b.Row.Label.Text = "Stop"
			local ok, res = Remote:InvokeServer("cancel")
			if ok then toast("Stopped " .. n.name .. ". $" .. UI.commas(res) .. " back", "cash") else toast(res, "close", true) end
		end,
	})
	-- idle: how much of everything is done
	lab.total = UI.new("Frame", { Size = UDim2.fromOffset(190, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0), BackgroundTransparency = 1, Parent = bar })
	lab.totalNum = text(lab.total, "", 15, { FontFace = UI.F.heavy, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = RIGHT })
	local tt = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 28), BackgroundColor3 = T.ink3, Parent = lab.total })
	UI.corner(tt, 3)
	lab.totalFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.brand, Parent = tt })
	UI.corner(lab.totalFill, 3)
end

---------------------------------------------------------------- branches (left)
local GROUPS = {
	{ name = "Building", ids = { "build", "decor", "comfort", "fun" } },
	{ name = "Running the hotel", ids = { "service", "perks", "upkeep", "dining" } },
	{ name = "Guests and staff", ids = { "guests", "stay", "market", "staff" } },
}
do -- any branch not named above joins the last group
	local seen = {}
	for _, g in ipairs(GROUPS) do for _, id in ipairs(g.ids) do seen[id] = true end end
	for _, br in ipairs(Research.BRANCHES) do
		if not seen[br.id] then table.insert(GROUPS[#GROUPS].ids, br.id) end
	end
end
local branchBtns = {}
local function styleRow(bb, on, hover)
	bb.button.BackgroundColor3 = on and T.brandSoft or T.ink3
	bb.button.BackgroundTransparency = (on or hover) and 0 or 1
	bb.name.TextColor3 = on and T.brand or T.cream
end
do
	local side = UI.new("Frame", { Name = "Branches", Size = UDim2.fromOffset(SIDE_W, MAIN_H), Position = UDim2.fromOffset(M, MAIN_Y), BackgroundColor3 = T.ink2, Parent = body })
	UI.corner(side, 14)
	local list = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = T.muted, Parent = side,
	})
	UI.list(list, Enum.FillDirection.Vertical, 2)
	local order = 0
	for gi, g in ipairs(GROUPS) do
		order += 1
		local head = caps(list, g.name, { Size = UDim2.new(1, 0, 0, gi == 1 and 22 or 34), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order })
		UI.pad(head, 10, 0, 0, 6)
		for _, id in ipairs(g.ids) do
			local br = BRANCH[id]
			if br then
				order += 1
				local btn = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -4, 0, 36), BackgroundColor3 = T.ink3, BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
				UI.corner(btn, 9)
				UI.icon(btn, ICON[BRANCH_ICON[id]], 22, { Position = UDim2.new(0, 9, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
				local name = text(btn, br.name, 13, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -78, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
				local count = text(btn, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = RIGHT, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 34, 1, 0) })
				local ready = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0), BackgroundColor3 = T.brand, Visible = false, Parent = btn })
				UI.corner(ready, UDim.new(1, 0))
				local bb = { button = btn, name = name, count = count, ready = ready }
				branchBtns[id] = bb
				btn.MouseEnter:Connect(function() if current ~= id then styleRow(bb, false, true) end end)
				btn.MouseLeave:Connect(function() styleRow(bb, current == id, false) end)
				btn.Activated:Connect(function()
					if current ~= id then UI.sound("Tab") showBranch(id) end
				end)
			end
		end
	end
end

---------------------------------------------------------------- the steps (middle)
local tree = UI.new("Frame", { Name = "Tree", Size = UDim2.fromOffset(TREE_W, MAIN_H), Position = UDim2.fromOffset(TREE_X, MAIN_Y), BackgroundTransparency = 1, Parent = body })
local tHeadName = text(tree, "", 22, { FontFace = UI.F.black, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -4, 0, 26) })
local tHeadSub = text(tree, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(2, 28), Size = UDim2.new(1, -4, 0, 16) })
local treeCanvas = UI.new("ScrollingFrame", {
	Name = "Canvas", Size = UDim2.new(1, 0, 1, -HEAD_H), Position = UDim2.fromOffset(0, HEAD_H), BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = T.muted, ScrollingDirection = Enum.ScrollingDirection.XY, Parent = tree,
})
local lineLayer = UI.new("Frame", { Name = "Lines", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = treeCanvas })
local nodeLayer = UI.new("Frame", { Name = "Nodes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = treeCanvas })
local NODE_H = 74

local function makeNode(n, cx, cy, cw)
	local b = UI.new("TextButton", { Name = n.id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(cw, NODE_H), Position = UDim2.fromOffset(cx, cy), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.ink2, ZIndex = 3, Parent = nodeLayer })
	UI.corner(b, 12)
	local stroke = border(b, 1.5, T.line, 1)
	local icon = UI.icon(b, iconOf(n), 22, { Position = UDim2.fromOffset(9, 8) })
	local sub = text(b, "", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.fromOffset(37, 11), Size = UDim2.new(1, -62, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	local badge = UI.icon(b, UI.G.lock, 13, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 12), ImageColor3 = T.muted })
	local name = text(b, n.name, 13, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -18, 0, 30), TextWrapped = true, TextYAlignment = TOP, TextTruncate = Enum.TextTruncate.AtEnd })
	local prog = UI.new("Frame", { Size = UDim2.new(1, -20, 0, 3), Position = UDim2.new(0, 10, 1, -6), BackgroundColor3 = T.white, Visible = false, Parent = b })
	UI.corner(prog, 2)
	local progFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.brand, Parent = prog })
	UI.corner(progFill, 2)
	for _, d in ipairs(b:GetDescendants()) do
		if d:IsA("GuiObject") then d.ZIndex = 4 end
	end
	nodes[n.id] = { node = n, card = b, stroke = stroke, icon = icon, name = name, sub = sub, badge = badge, prog = prog, progFill = progFill, x = cx, y = cy, w = cw }
	b.Activated:Connect(function()
		UI.sound("Click")
		select(n.id)
	end)
end

local function seg(x, y, w, h)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(math.max(w, 2), math.max(h, 2)), Position = UDim2.fromOffset(x, y), BackgroundColor3 = T.line, BorderSizePixel = 0, ZIndex = 2, Parent = lineLayer })
	return f
end
-- an elbow from the right edge of one card to the left edge of the next
local function lineBetween(a, b)
	local x1, y1 = a.x + a.w / 2, a.y
	local x2, y2 = b.x - b.w / 2, b.y
	local mx = math.floor(x2 - 8)
	return {
		seg(x1, y1 - 1, mx - x1, 2),
		seg(mx - 1, math.min(y1, y2) - 1, 2, math.abs(y2 - y1) + 2),
		seg(mx, y2 - 1, x2 - mx, 2),
	}
end

---------------------------------------------------------------- the chosen project (right)
local card = UI.new("Frame", { Name = "Card", Size = UDim2.fromOffset(CARD_W, MAIN_H), Position = UDim2.fromOffset(CARD_X, MAIN_Y), BackgroundColor3 = T.ink2, Parent = body })
UI.corner(card, 14)
local info = UI.new("Frame", { Name = "Info", Size = UDim2.new(1, -36, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Parent = card })
UI.list(info, Enum.FillDirection.Vertical, 6)
local cBranchRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1, Parent = info })
local cDot = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = T.brand, Parent = cBranchRow })
UI.corner(cDot, UDim.new(1, 0))
local cBranch = caps(cBranchRow, "", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 0, 16) })
local function flow(size, order, props)
	local l = text(info, "", size, { TextWrapped = true, TextYAlignment = TOP, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order })
	for k, v in pairs(props) do l[k] = v end
	return l
end
local cName = flow(24, 2, { FontFace = UI.F.black })
local cStatus = flow(14, 3, { FontFace = UI.F.heavy, TextColor3 = T.muted })
local cDesc = flow(14, 4, { FontFace = UI.F.body, TextColor3 = T.muted })
caps(info, "What you get", { Size = UDim2.new(1, 0, 0, 30), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = 5 })
local unlockBox = UI.new("Frame", { Name = "Unlocks", Size = UDim2.new(1, 0, 0, 216), BackgroundTransparency = 1, LayoutOrder = 6, Parent = info })
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -5, 0, 103)
	g.CellPadding = UDim2.fromOffset(10, 10)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = unlockBox
end
-- footer: cost, time and the action
local foot = UI.new("Frame", { Size = UDim2.new(1, -36, 0, 116), Position = UDim2.new(0, 18, 1, -132), BackgroundTransparency = 1, Parent = card })
local function figure(x, caption)
	local f = UI.new("Frame", { Size = UDim2.new(0.5, -5, 0, 52), Position = UDim2.new(x, x > 0 and 5 or 0, 0, 0), BackgroundColor3 = T.ink, Parent = foot })
	UI.corner(f, 10)
	caps(f, caption, { Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 14), TextSize = 11 })
	return text(f, "", 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(12, 23), Size = UDim2.new(1, -24, 0, 22) })
end
local cCost = figure(0, "Cost")
local cTime = figure(0.5, "Takes")
local actBtn, actLabel = UI.button(foot, {
	name = "Start", text = "Start research", kind = "green", size = UDim2.new(1, 0, 0, 52), pos = UDim2.new(0, 0, 1, 0), anchor = Vector2.new(0, 1), textSize = 19, radius = 12,
	onClick = function(b)
		local n = selected and Research.BY_ID[selected]
		if not n then return end
		if nodeState(state(), n) ~= "open" then
			UI.shake(b)
			return
		end
		local ok, res = Remote:InvokeServer("start", n.id)
		if ok then
			UI.sound("Place")
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
	if not src then
		UI.icon(parent, ICON.hammer, 44, { Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0) })
		return
	end
	local vf = UI.new("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -28), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(160, 162, 165), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(-1, -1.4, -0.8), Parent = parent,
	})
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
	UI.corner(t, 10)
	build(t)
	return t
end
local function tileLabel(t, str)
	UI.label(t, str, 12, { FontFace = UI.F.heavy, TextXAlignment = CENTER, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.new(0, 6, 1, -22), Size = UDim2.new(1, -12, 0, 16) })
end
local function tileIcon(t, image)
	UI.icon(t, image, 44, { Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0) })
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
			tileIcon(t, iconOf(n))
			tileLabel(t, "New guests: " .. (ev == "allnighter" and "night owls" or ev))
		end)
	end
	if n.perk then
		order += 1
		room -= 1
		unlockTile(order, function(t)
			tileIcon(t, ICON.upgrade)
			tileLabel(t, "A hotel perk")
		end)
	end
	local mats = UNLOCK_MATS[n.id]
	if mats and #mats > 0 then
		order += 1
		room -= 1
		unlockTile(order, function(t)
			tileIcon(t, ICON.paint)
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
			UI.label(t, "+" .. (#items - math.max(room, 0)), 28, { FontFace = UI.F.black, TextColor3 = T.brand, TextXAlignment = CENTER, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 34) })
			tileLabel(t, "more items")
			UI.tooltip(t, table.concat(names, ", "))
		end)
	end
	if order == 0 then
		order += 1
		unlockTile(order, function(t)
			tileIcon(t, ICON.sparkle)
			tileLabel(t, "New options")
		end)
	end
end

---------------------------------------------------------------- refresh
local function refresh()
	local st = state()
	local now = os.time()
	local cash = player:GetAttribute("Cash") or 0
	-- branches
	local total, doneN, waiting = 0, 0, 0
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
		waiting += waitLv
		local bb = branchBtns[b.id]
		if bb then
			bb.ready.Visible = ready
			bb.count.Text = d .. "/" .. n
			bb.count.TextColor3 = (d == n and n > 0) and T.greenDk or T.muted
		end
		if b.id == current then
			local bits = { (d == n and n > 0) and ("All " .. n .. " done") or (d .. " of " .. n .. " done") }
			if open > 0 then table.insert(bits, open .. " ready") end
			if waitLv > 0 then table.insert(bits, waitLv .. " need a higher hotel level") end
			tHeadSub.Text = table.concat(bits, ", ")
		end
	end
	-- the lab bar
	local cur = st.cur and Research.BY_ID[st.cur]
	lab.stop.Visible = cur ~= nil
	lab.track.Visible = cur ~= nil
	lab.time.Visible = cur ~= nil
	lab.total.Visible = cur == nil
	lab.hint.Visible = cur == nil
	if cur then
		local len = st.len or Research.duration(st, cur.id)
		local left = math.max((st.ends or now) - now, 0)
		lab.title.Text = cur.name
		lab.fill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(len, 1), 0, 1), 1)
		lab.time.Text = clock(left)
	else
		lab.title.Text = "Nothing running"
		lab.hint.Text = waiting > 0 and ("Pick a project to start. " .. waiting .. " more open as your hotel levels up.") or "Pick a project to start."
		lab.totalNum.Text = doneN .. " of " .. total .. " done"
		lab.totalFill.Size = UDim2.fromScale(total > 0 and doneN / total or 0, 1)
	end
	-- project cards
	for id, nd in pairs(nodes) do
		local n = nd.node
		local s = nodeState(st, n)
		local dark = s == "locked" or s == "level"
		nd.state = s
		nd.card.BackgroundColor3 = (s == "running" and T.brandSoft) or (s == "open" and T.ink) or T.ink2
		nd.icon.ImageTransparency = dark and 0.55 or 0
		nd.name.TextColor3 = dark and T.muted or T.cream
		nd.prog.Visible = s == "running"
		nd.badge.Visible = s ~= "open" and s ~= "running"
		nd.badge.Image = s == "done" and UI.G.check or UI.G.lock
		nd.badge.ImageColor3 = s == "done" and T.greenDk or T.muted
		if s == "done" then
			nd.sub.Text, nd.sub.TextColor3 = "Done", T.greenDk
		elseif s == "running" then
			local len = st.len or Research.duration(st, id)
			local left = math.max((st.ends or now) - now, 0)
			nd.sub.Text, nd.sub.TextColor3 = clock(left) .. " left", T.brand
			nd.progFill.Size = UDim2.fromScale(math.clamp(1 - left / math.max(len, 1), 0, 1), 1)
		elseif s == "open" then
			nd.sub.Text, nd.sub.TextColor3 = "$" .. UI.commas(n.cost), cash >= n.cost and T.greenDk or T.muted
		elseif s == "level" then
			nd.sub.Text, nd.sub.TextColor3 = "Level " .. Levels.researchLevel(n.id), T.muted
		else
			nd.sub.Text, nd.sub.TextColor3 = "Locked", T.muted
		end
		if selected == id then
			nd.stroke.Color, nd.stroke.Thickness, nd.stroke.Transparency = T.brand, 2.5, 0
		elseif s == "open" then
			nd.stroke.Color, nd.stroke.Thickness, nd.stroke.Transparency = T.line, 1.5, 0
		else
			nd.stroke.Transparency = 1
		end
	end
	for _, l in ipairs(lines) do
		local lit = st.done[l.from]
		for _, f in ipairs(l.frames) do f.BackgroundColor3 = lit and T.brand or T.line end
	end
	-- the chosen project
	local n = selected and Research.BY_ID[selected]
	if n then
		local s = nodeState(st, n)
		cCost.Text = "$" .. UI.commas(n.cost)
		cCost.TextColor3 = (s == "done" and T.muted) or (cash >= n.cost and T.greenDk) or T.red
		cTime.Text = clock(Research.duration(st, n.id))
		local need = {}
		for _, r in ipairs(n.req or {}) do
			if not st.done[r] then
				local rn = Research.BY_ID[r]
				table.insert(need, rn.name .. (rn.branch ~= n.branch and (" (" .. BRANCH[rn.branch].name .. ")") or ""))
			end
		end
		if s == "done" then
			cStatus.Text, cStatus.TextColor3 = "Done", T.greenDk
			actLabel.Text = "Done"
			UI.setKind(actBtn, "ghost")
		elseif s == "running" then
			cStatus.Text, cStatus.TextColor3 = "In the lab now, " .. clock(math.max((st.ends or now) - now, 0)) .. " left", T.brand
			actLabel.Text = "Researching"
			UI.setKind(actBtn, "ghost")
		elseif s == "level" then
			cStatus.Text, cStatus.TextColor3 = "Reach hotel level " .. Levels.researchLevel(n.id) .. " to research this", T.muted
			actLabel.Text = "Hotel level " .. Levels.researchLevel(n.id)
			UI.setKind(actBtn, "ghost")
		elseif s == "locked" then
			cStatus.Text, cStatus.TextColor3 = "First research " .. table.concat(need, " and "), T.muted
			actLabel.Text = "Locked"
			UI.setKind(actBtn, "ghost")
		elseif st.cur then
			cStatus.Text, cStatus.TextColor3 = "Ready once the lab is free", T.muted
			actLabel.Text = "Lab busy"
			UI.setKind(actBtn, "ghost")
		else
			cStatus.Text = cash >= n.cost and "Ready to research" or ("You need $" .. UI.commas(n.cost - cash) .. " more")
			cStatus.TextColor3 = cash >= n.cost and T.greenDk or T.red
			actLabel.Text = "Start research"
			UI.setKind(actBtn, cash >= n.cost and "green" or "ghost")
		end
	end
end

select = function(id)
	local n = Research.BY_ID[id]
	if not n then return end
	selected = id
	local br = BRANCH[n.branch]
	cDot.BackgroundColor3 = br.color
	cBranch.Text = string.upper(br.name)
	cName.Text = n.name
	cDesc.Text = n.desc
	fillUnlocks(n)
	refresh()
end

-- lay out a branch: steps from left to right, each step's projects stacked and centred
showBranch = function(id, focus)
	current = id
	for bid, bb in pairs(branchBtns) do styleRow(bb, bid == id, false) end
	tHeadName.Text = BRANCH[id].name
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
	local tw, th = TREE_W, MAIN_H - HEAD_H
	local LABEL = 28
	local colW, stack = math.clamp(math.floor(tw / math.max(maxTier, 1)), 128, 200), 1
	for r = 1, maxTier do stack = math.max(stack, #(tiers[r] or {})) end
	local rowH = math.clamp(math.floor((th - LABEL - 8) / stack), NODE_H + 10, NODE_H + 20)
	local cw = math.max(tw, colW * maxTier)
	local ch = math.max(th, rowH * stack + LABEL + 8)
	treeCanvas.CanvasSize = UDim2.fromOffset(cw > tw and cw or 0, ch > th and ch or 0)
	treeCanvas.CanvasPosition = Vector2.new(0, 0)
	local nodeW = colW - 16
	-- columns start at the left edge; the stack sits in the top part of the panel, not floating in the middle
	local blockH = rowH * stack
	local midY = LABEL + math.min(blockH, ch - LABEL) / 2 + 4
	for r = 1, maxTier do
		local cx = (r - 1) * colW + nodeW / 2 + 2
		local lbl = caps(lineLayer, "Step " .. r, { Position = UDim2.fromOffset(cx - nodeW / 2 + 2, 2), Size = UDim2.fromOffset(nodeW, 16) })
		lbl.ZIndex = 2
		local list = tiers[r] or {}
		for i, n in ipairs(list) do
			makeNode(n, cx, midY + (i - (#list + 1) / 2) * rowH, nodeW)
		end
	end
	for _, nd in pairs(nodes) do
		for _, r in ipairs(nd.node.req or {}) do
			local from = nodes[r]
			if from then
				table.insert(lines, { from = r, to = nd.node.id, frames = lineBetween(from, nd) })
			end
		end
	end
	-- the first project to look at: the focus, the running one, the first open one, or the first
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
	select(pick)
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
		-- open on the running project's branch
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

Shared.Remotes.Notify.OnClientEvent:Connect(function(kind, d)
	if kind ~= "researched" then return end
	refresh()
	local nd = d and nodes[d.id]
	if nd and isOpen then
		UI.sound("Fanfare")
		UI.pop(nd.card, 1.12, 0.4)
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

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if not isOpen then return end
	acc += dt
	if acc >= 0.5 then
		acc = 0
		refresh()
	end
	-- furniture previews turn slowly
	for _, sp in ipairs(spinning) do
		sp.t += dt
		if sp.model.Parent then sp.model:PivotTo(CFrame.Angles(0, sp.t * 0.8, 0) * sp.base) end
	end
end)

showBranch("build")
refresh()
