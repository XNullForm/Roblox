-- StarterPlayerScripts.UpgradesUI (round 25): the menu's Upgrades page, built into Coop's Page_upgrades.
-- Left: the comeback (Curb Appeal as a five-step track with its own buy button) and a two-wide grid of the other
-- upgrades (level tile, what it does, level bar, now -> next, price). Right: the hotel's style, a swatch grid per surface.
-- Remotes.Upgrade:InvokeServer(id) buys, ("style", key, id) restyles; redraws on the hotel's Upgrades / Grade / Style
-- attributes and the player's Cash.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local U = require(Shared:WaitForChild("Upgrades"))
local remote = Shared:WaitForChild("Remotes"):WaitForChild("Upgrade")
local T = UI.T
local Y = Enum.AutomaticSize.Y
local LEFT, RIGHT, TOP = Enum.TextXAlignment.Left, Enum.TextXAlignment.Right, Enum.TextYAlignment.Top

local pgui = player:WaitForChild("PlayerGui")
local page
repeat
	page = pgui:FindFirstChild("Page_upgrades", true)
	if not page then task.wait(0.5) end
until page

local function hotel()
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(player:GetAttribute("Plot") or "")
end

-- round 34: the chapter look: white glossy plates with a soft rim, a 3D icon per upgrade
local ICON = require(Shared:WaitForChild("Config")).ICONS
local UP_ICON = { curb = "hotel", ads = "phone", rates = "cash", tips = "gift", comfort = "bed", training = "medal", payroll = "staff", welcome = "bell" }
local function plateLook(f)
	f.BackgroundColor3 = T.ink
	UI.corner(f, 16)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = f })
	UI.rim(f, Color3.fromRGB(232, 237, 244), 2.5)
	return f
end
local function block(parent, h, order)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, h), LayoutOrder = order or 0, Parent = parent })
	if h == 0 then f.AutomaticSize = Y end
	return plateLook(f)
end
local function caps(parent, text, props)
	local l = UI.label(parent, string.upper(text), 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = LEFT })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function text(parent, str, size, props)
	local l = UI.label(parent, str, size, { TextXAlignment = LEFT })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local busy = false
local function buy(id)
	if busy then return end
	busy = true
	local ok, good, msg = pcall(function() return remote:InvokeServer(id) end)
	busy = false
	if ok and good then
		pcall(UI.sound, "coins")
	else
		UI.toast(ok and msg or "Couldn't buy that", "close", "bad")
	end
end

local root = UI.new("Frame", { Name = "Root", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = page })
local left = UI.new("Frame", { Name = "Left", Size = UDim2.new(0.64, -8, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, Parent = root })
UI.list(left, nil, 10)
local right = UI.new("Frame", { Name = "Right", Size = UDim2.new(0.36, -8, 0, 0), Position = UDim2.new(0.64, 8, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, Parent = root })
UI.list(right, nil, 10)

---------------------------------------------------------------- the comeback (Curb Appeal)
local curb = U.BY.curb
local STAGE_TEXT = {
	[0] = "Aunt Marigold's hotel is yours now, boards, weeds and all. Start here: nobody books a ruin.",
	[1] = "The boards are off and the doors open. A lick of paint would do wonders.",
	[2] = "White walls and red tiles again. Guests are starting to talk about the Seabreeze.",
	[3] = "Flowers, palms, a proper welcome. One more push and it's the pride of the coast.",
	[4] = "The grandest hotel in Harbour View. Marigold always said you'd do it.",
}
local story = {}
do
	local f = block(left, 176, 1)
	f.Name = "Comeback"
	UI.icon(f, ICON.hotel, 72, { Position = UDim2.fromOffset(12, 14), BackgroundTransparency = 1 })
	caps(f, "The Seabreeze comeback", { Position = UDim2.fromOffset(96, 16), Size = UDim2.new(1, -310, 0, 16), TextColor3 = T.brand, FontFace = UI.F.black })
	story.stage = text(f, "", 26, { FontFace = UI.F.black, Position = UDim2.fromOffset(96, 36), Size = UDim2.new(1, -310, 0, 30) })
	story.text = text(f, "", 15, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(96, 70), Size = UDim2.new(1, -310, 0, 40), TextWrapped = true, TextYAlignment = TOP })
	story.btn, story.btnText = UI.button(f, {
		name = "Buy", text = "Buy", kind = "green", size = UDim2.fromOffset(176, 50), pos = UDim2.new(1, -18, 0, 18), anchor = Vector2.new(1, 0), textSize = 19, radius = 12,
		onClick = function() buy("curb") end,
	})
	story.next = text(f, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 74), Size = UDim2.fromOffset(176, 34), TextXAlignment = RIGHT, TextWrapped = true, TextYAlignment = TOP })
	-- five steps: a dot each, joined by a thin line, the name underneath
	local track = UI.new("Frame", { Name = "Track", Size = UDim2.new(1, -36, 0, 44), Position = UDim2.fromOffset(18, 120), BackgroundTransparency = 1, Parent = f })
	local n = #curb.levels
	story.dots, story.links, story.names = {}, {}, {}
	for i = 1, n do
		local x = (i - 1) / (n - 1)
		if i < n then
			local link = UI.new("Frame", { Size = UDim2.new(1 / (n - 1), -64, 0, 3), Position = UDim2.new(x, 32, 0, 8), BackgroundColor3 = T.ink3, Parent = track })
			UI.corner(link, 2)
			story.links[i] = link
		end
		-- the ends hug the edges, the middle ones sit centred on their spot
		local ax = i == 1 and 0 or (i == n and 1 or 0.5)
		local dot = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(x, 0, 0, 0), BackgroundColor3 = T.ink3, Parent = track })
		UI.corner(dot, UDim.new(1, 0))
		story.dots[i] = dot
		story.names[i] = UI.label(track, curb.levels[i], 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, AnchorPoint = Vector2.new(ax, 0), Position = UDim2.new(x, 0, 0, 24), Size = UDim2.fromOffset(120, 16),
			TextXAlignment = i == 1 and LEFT or (i == n and RIGHT or Enum.TextXAlignment.Center) })
	end
end

---------------------------------------------------------------- the other upgrades (two wide)
local cards = {}
do
	local head = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 2, Parent = left })
	caps(head, "Upgrades", { Position = UDim2.fromOffset(4, 6), Size = UDim2.new(0.5, 0, 0, 16) })
	cards.count = caps(head, "", { Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.new(0.5, -4, 0, 16), TextXAlignment = RIGHT })
	local grid = UI.new("Frame", { Name = "Grid", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 3, Parent = left })
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(0.5, -5, 0, 138)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	cards.list = {}
	for i, def in ipairs(U.LIST) do
		if def.id ~= "curb" then
			local card = plateLook(UI.new("Frame", { Name = def.id, LayoutOrder = i, Parent = grid }))
			UI.icon(card, ICON[UP_ICON[def.id] or def.icon] or ICON.upgrade, 52, { Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1 })
			-- the level pill, top right
			local tile = UI.new("Frame", { Size = UDim2.fromOffset(58, 22), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), BackgroundColor3 = T.ink3, Parent = card })
			UI.corner(tile, 11)
			local num = UI.label(tile, "LV 0", 12, { FontFace = UI.F.black, TextColor3 = T.muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
			text(card, def.name, 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(72, 12), Size = UDim2.new(1, -150, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
			text(card, def.desc, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(72, 35), Size = UDim2.new(1, -86, 0, 32), TextWrapped = true, TextYAlignment = TOP })
			-- level bar: one slim piece per level
			local segs = {}
			for k = 1, def.max do
				local s = UI.new("Frame", { Size = UDim2.new(1 / def.max, -4, 0, 5), Position = UDim2.new((k - 1) / def.max, 14 + 2, 0, 76), BackgroundColor3 = T.ink3, Parent = card })
				UI.corner(s, 3)
				segs[k] = s
			end
			-- the bar's pieces are sized against the card, so pull the padding back out of each one
			for k, s in ipairs(segs) do
				s.Size = UDim2.new(1 / def.max, -4 - 28 / def.max, 0, 5)
				s.Position = UDim2.new((k - 1) / def.max, 14 - (k - 1) * 28 / def.max + 2, 0, 76)
			end
			local now = text(card, "", 17, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(14, 90), Size = UDim2.new(1, -160, 0, 20) })
			local nxt = text(card, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 111), Size = UDim2.new(1, -160, 0, 16) })
			local btn, btnText = UI.button(card, {
				name = "Buy", text = "Buy", kind = "green", size = UDim2.fromOffset(124, 40), pos = UDim2.new(1, -14, 1, -12), anchor = Vector2.new(1, 1), textSize = 17, radius = 10,
				onClick = function() buy(def.id) end,
			})
			cards.list[def.id] = { def = def, tile = tile, num = num, segs = segs, now = now, nxt = nxt, btn = btn, btnText = btnText }
		end
	end
end

---------------------------------------------------------------- hotel style (right)
local styleBtns = {}
do
	local head = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = right })
	UI.list(head, nil, 2)
	UI.pad(head, 4, 2, 4, 2)
	caps(head, "Hotel style")
	text(head, "Free to change. Floors and the roof are picked in build mode now.", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Size = UDim2.new(1, 0, 0, 16), TextWrapped = true, AutomaticSize = Y })
	for gi, g in ipairs(U.STYLES) do
		if g.key ~= "walls" then continue end -- round 41: floors and the roof live in build mode (the tool bar)
		local card = block(right, 0, 1 + gi)
		card.Name = "Style_" .. g.key
		UI.list(card, nil, 10)
		UI.pad(card, 16, 14, 16, 16)
		local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = card })
		text(top, g.name, 18, { FontFace = UI.F.black, Size = UDim2.new(0.5, 0, 1, 0) })
		local now = text(top, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), TextXAlignment = RIGHT })
		local sw = UI.new("Frame", { Name = "Swatches", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = card })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(44, 44)
		gl.CellPadding = UDim2.fromOffset(9, 9)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = sw
		styleBtns[g.key] = { now = now, list = {} }
		for i, e in ipairs(g.list) do
			local b = UI.new("TextButton", { Name = e[1], Text = "", AutoButtonColor = false, BackgroundColor3 = e[3], LayoutOrder = i, Parent = sw })
			UI.corner(b, 11)
			local ring = Instance.new("UIStroke")
			ring.Thickness = 1
			ring.Color = T.line
			ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			ring.Parent = b
			-- a white tick on the one in use
			local tick = UI.new("Frame", { Name = "On", Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 5, 1, 5), BackgroundColor3 = T.brand, Visible = false, Parent = b })
			UI.corner(tick, UDim.new(1, 0))
			UI.icon(tick, UI.G.check, 10, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = T.white })
			UI.tooltip(b, e[2])
			b.Activated:Connect(function()
				UI.sound("Click")
				local ok, good, msg = pcall(function() return remote:InvokeServer("style", g.key, e[1]) end)
				if not (ok and good) then UI.toast(ok and msg or "That didn't work", nil, "bad") end
			end)
			styleBtns[g.key].list[e[1]] = { ring = ring, tick = tick, name = e[2] }
		end
	end
end

---------------------------------------------------------------- refresh
local function price(btn, btnText, cost, cash)
	btnText.Text = cost and ("$" .. UI.commas(cost)) or "Maxed"
	pcall(UI.setKind, btn, (cost and cash >= cost) and "green" or "ink")
	pcall(UI.setDisabled, btn, cost == nil)
end

local function refresh()
	local h = hotel()
	local cash = player:GetAttribute("Cash") or 0
	local style = U.style(h)
	for key, sb in pairs(styleBtns) do
		for id, b in pairs(sb.list) do
			local on = style[key] == id
			b.ring.Thickness = on and 3 or 1
			b.ring.Color = on and T.brand or T.line
			b.tick.Visible = on
			if on then sb.now.Text = b.name end
		end
	end
	-- the comeback
	local stage = h and U.level(h, "curb") or 0
	story.stage.Text = curb.levels[stage + 1] or ""
	story.text.Text = STAGE_TEXT[stage] or STAGE_TEXT[0]
	for i, dot in ipairs(story.dots) do
		local done, here = i <= stage, i == stage + 1
		dot.BackgroundColor3 = (done or here) and T.brand or T.ink3
		story.names[i].TextColor3 = here and T.cream or T.muted
		if story.links[i] then story.links[i].BackgroundColor3 = i <= stage and T.brand or T.ink3 end
	end
	local curbCost = U.cost(curb, stage)
	price(story.btn, story.btnText, curbCost, cash)
	story.next.Text = curbCost and ("Next: " .. curb.levels[stage + 2]) or "As good as it gets"
	-- the grid
	local have, total = 0, 0
	for id, c in pairs(cards.list) do
		local def = c.def
		local lv = h and U.level(h, id) or 0
		have += lv
		total += def.max
		c.num.Text = "LV " .. lv .. "/" .. def.max
		c.num.TextColor3 = lv > 0 and T.brand or T.muted
		c.tile.BackgroundColor3 = lv > 0 and T.brandSoft or T.ink3
		for k, s in ipairs(c.segs) do s.BackgroundColor3 = k <= lv and T.brand or T.ink3 end
		local cost = U.cost(def, lv)
		c.now.Text = lv > 0 and U.effect(def, lv) or "Not bought yet"
		c.now.TextColor3 = lv > 0 and T.greenDk or T.muted
		c.nxt.Text = cost and ("Next: " .. U.effect(def, lv + 1)) or "Top level"
		price(c.btn, c.btnText, cost, cash)
	end
	cards.count.Text = have .. " OF " .. total .. " LEVELS"
end

local watched
local function watch()
	local h = hotel()
	if h and h ~= watched then
		watched = h
		h:GetAttributeChangedSignal("Upgrades"):Connect(refresh)
		h:GetAttributeChangedSignal("Grade"):Connect(refresh)
		h:GetAttributeChangedSignal("Style"):Connect(refresh)
	end
	refresh()
end
player:GetAttributeChangedSignal("Plot"):Connect(watch)
player:GetAttributeChangedSignal("Cash"):Connect(function() if page.Visible then refresh() end end)
page:GetPropertyChangedSignal("Visible"):Connect(function() if page.Visible then watch() end end)
watch()

-- U opens this page (the bottom bar shows the key)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.U then return end
	if player:GetAttribute("Building") or player:GetAttribute("InCutscene") or not player:GetAttribute("Slot") then return end
	player:SetAttribute("MenuWant", "upgrades")
end)
