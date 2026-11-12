---------------------------------------------------------------- key hints (top centre)
-- round 23: build mode's UI, made new. Panels are light cards (the catalog on the left, the editors on the right);
-- bars are dark glass (the key strip on top, the tools and the place bar at the bottom, the pill over a selection).

local hintWrap = wrapper("Hints", UDim2.fromOffset(1000, 34), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
hintWrap.Visible = false
local hintRow = UI.new("Frame", {
	Name = "Strip", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = T.hud, BackgroundTransparency = 0.1, Parent = hintWrap,
})
UI.corner(hintRow, 17)
UI.stroke(hintRow, 1, T.hudLine, 0.2)
UI.pad(hintRow, 14, 0, 14, 0)
UI.list(hintRow, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local function setHints(list)
	for _, c in ipairs(hintRow:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, h in ipairs(list) do
		local item = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, LayoutOrder = i, Parent = hintRow })
		UI.list(item, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
		if h[1] ~= "" then
			local k = UI.new("TextLabel", {
				Text = h[1], TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.hudText, BackgroundColor3 = T.hud2,
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), Parent = item,
			})
			UI.corner(k, 5)
			UI.stroke(k, 1, T.hudLine, 0)
			UI.pad(k, 6, 0, 6, 0)
		end
		UI.new("TextLabel", {
			Text = h[2], TextSize = 13, FontFace = UI.F.bold, TextColor3 = T.hudMuted, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = item,
		})
	end
end
local HINTS_IDLE = TOUCH and { { "", "Drag to move around" }, { "", "Pinch to zoom, twist to turn" }, { "", "Tap something to edit it" } }
	or { { "WASD", "Move" }, { "Q E", "Orbit" }, { "Right drag", "Turn" }, { "Scroll", "Zoom" }, { "Click", "Edit an item" }, { "B", "Done" } }
local HINTS_GHOST = TOUCH and { { "", "Tap the floor to aim" }, { "", "Use the buttons to turn and place" } }
	or { { "Click", "Place" }, { "Drag", "Place a row" }, { "R", "Turn" }, { "T G", "Raise / lower" }, { "Shift", "Keep placing" }, { "X", "Cancel" } }
local HINTS_ROOM = { { "Drag", "Draw a room" }, { "R", "Move the door" }, { "Right drag", "Turn" }, { "Z", "Undo" }, { "F", "Close" } }
local PAD_IDLE = { { "LS", "Move" }, { "RS", "Look" }, { "LT RT", "Zoom" }, { "A", "Edit an item" }, { "Y", "Browse items" }, { "B", "Done" } }
local PAD_GHOST = { { "A", "Place" }, { "X", "Turn" }, { "LB RB", "Raise / lower" }, { "Y", "Browse items" }, { "B", "Cancel" } }
local function hintsFor(set)
	if UI.gamepad() then return set == HINTS_GHOST and PAD_GHOST or PAD_IDLE end
	return set
end

---------------------------------------------------------------- the catalog (left)
-- A tall card down the left edge: search on top, categories on a rail, items in a two-wide grid.

local shopWrap = wrapper("Shop", UDim2.fromOffset(404, 760), UDim2.new(0, 16, 1, -14), Vector2.new(0, 1))
shopWrap.Visible = false
local shopHolder, shopBody = UI.panel(shopWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
	name = "Catalog", radius = 14, title = "Catalog", subtitle = "Pick something, then click the floor", icon = ICON.hammer,
})
shopHolder.AnchorPoint = Vector2.new(0.5, 0.5)

local refreshCards -- forward
local cashText
do
	local pill = UI.new("Frame", {
		Name = "Cash", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(228, 250, 236), ZIndex = 5, Parent = shopBody,
	})
	UI.corner(pill, 15)
	UI.pad(pill, 12, 0, 12, 0)
	cashText = UI.new("TextLabel", {
		Text = "$0", TextSize = 16, FontFace = UI.F.heavy, TextColor3 = T.greenDk, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 6, Parent = pill,
	})
end

local searchBox = UI.new("Frame", { Name = "Search", Size = UDim2.new(1, -32, 0, 38), Position = UDim2.fromOffset(16, 68), BackgroundColor3 = T.ink2, Parent = shopBody })
UI.corner(searchBox, 10)
local searchStroke = UI.stroke(searchBox, 1.5, T.line, 0)
UI.icon(searchBox, ICON.search, 20, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
local searchInput = UI.new("TextBox", {
	Text = "", PlaceholderText = "Search items", PlaceholderColor3 = T.muted, TextSize = 15, FontFace = UI.F.bold,
	TextColor3 = T.cream, BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(38, 0), Parent = searchBox,
})
searchInput.Focused:Connect(function() UI.tween(searchStroke, 0.15, { Color = T.brand }) end)
searchInput.FocusLost:Connect(function() UI.tween(searchStroke, 0.15, { Color = T.line }) end)

-- the category rail
local catRail = UI.new("ScrollingFrame", {
	Name = "Cats", Position = UDim2.fromOffset(10, 116), Size = UDim2.new(0, 64, 1, -126), BackgroundTransparency = 1,
	ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = shopBody,
})
UI.list(catRail, nil, 4)
local catBtns = {}
local tabsApi = {}
function tabsApi.select(id, silent)
	if not catBtns[id] then id = "all" end
	for cid, cb in pairs(catBtns) do
		local on = cid == id
		cb.b.BackgroundColor3 = on and T.brandSoft or T.ink
		cb.b.BackgroundTransparency = on and 0 or 1
		cb.t.TextColor3 = on and T.brand or T.muted
	end
	if not silent then
		S.cat = id
		refreshCards(true)
	end
end
for i, c in ipairs(Catalog.CATS) do
	local b = UI.new("TextButton", { Name = "Cat_" .. c.id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = T.ink, BackgroundTransparency = 1, LayoutOrder = i, Parent = catRail })
	UI.corner(b, 12)
	UI.icon(b, ICON[c.icon], 26, { Position = UDim2.new(0.5, 0, 0, 7), AnchorPoint = Vector2.new(0.5, 0) })
	local t = UI.label(b, c.name, 10, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -19), Size = UDim2.new(1, 0, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
	b.MouseEnter:Connect(function() if S.cat ~= c.id then b.BackgroundTransparency = 0 b.BackgroundColor3 = T.ink2 end end)
	b.MouseLeave:Connect(function() if S.cat ~= c.id then b.BackgroundTransparency = 1 end end)
	b.Activated:Connect(function()
		UI.sound("Tab")
		tabsApi.select(c.id)
	end)
	catBtns[c.id] = { b = b, t = t }
end
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	S.query = string.lower(searchInput.Text)
	if S.query ~= "" and S.cat ~= "all" then tabsApi.select("all", true) S.cat = "all" end
	refreshCards(true)
end)

local list = UI.new("ScrollingFrame", {
	Name = "Items", BackgroundTransparency = 1, Position = UDim2.fromOffset(80, 116), Size = UDim2.new(1, -90, 1, -126),
	ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollBarThickness = 4, ScrollBarImageColor3 = T.muted, ScrollBarImageTransparency = 0.4, Parent = shopBody,
})
do
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.new(0.5, -8, 0, 158)
	g.CellPadding = UDim2.fromOffset(8, 8)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = list
	UI.pad(list, 2, 2, 8, 8)
end
local emptyNote = UI.label(shopBody, "Nothing matches that search", 15, {
	FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(80, 190), Size = UDim2.new(1, -90, 0, 20), Visible = false,
})

-- a 3D thumbnail of an item
local function thumb(parent, id)
	local vf = UI.new("ViewportFrame", {
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(163, 166, 170), LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(-1, -2, -1.4), Parent = parent,
	})
	local m = Build.make(id, CFrame.new(), Catalog.ITEMS[id].shape and { color = Catalog.SWATCHES[8] } or nil)
	m.Parent = vf
	local messy = m:FindFirstChild("Messy")
	if messy then messy:Destroy() end
	local cf, size = m:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local r = size.Magnitude / 2
	local dir = Vector3.new(0.75, 0.62, 1).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * (r / math.tan(math.rad(15)) * 0.92), cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf
end

local cards = {}
local startPlacing -- forward

-- thumbnails are made a few a frame, and only for tiles that have been on show (the catalog opens at once)
local thumbQueue, thumbBusy = {}, false
local function wantThumb(c)
	if c.vf or c.queued then return end
	c.queued = true
	table.insert(thumbQueue, c)
	if thumbBusy then return end
	thumbBusy = true
	task.spawn(function()
		while #thumbQueue > 0 do
			for _ = 1, 4 do
				local q = table.remove(thumbQueue, 1)
				if not q then break end
				local ok, vf = pcall(thumb, q.well, q.id)
				if ok then
					vf.Size = UDim2.fromScale(1, 1)
					vf.ZIndex = 2
					q.vf = vf
				end
			end
			task.wait()
		end
		thumbBusy = false
	end)
end

local function makeCard(id, order)
	local item = Catalog.ITEMS[id]
	local b = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = list })
	UI.corner(b, 14)
	local st = UI.stroke(b, 2, T.brand, 1)
	local well = UI.new("Frame", { Name = "Well", Size = UDim2.new(1, -12, 1, -62), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = T.white, ClipsDescendants = true, Parent = b })
	UI.corner(well, 10)
	UI.label(b, item.name, 14, { FontFace = UI.F.bold, Position = UDim2.new(0, 10, 1, -52), Size = UDim2.new(1, -20, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local price = UI.label(b, "", 15, { FontFace = UI.F.heavy, TextColor3 = T.greenDk, Position = UDim2.new(0, 10, 1, -30), Size = UDim2.new(0.6, 0, 0, 20) })
	local appeal = item.shape and Build.SHAPE_APPEAL or item.appeal or 0
	if appeal > 0 then
		UI.icon(b, UI.G.star, 12, { ImageColor3 = T.muted, Position = UDim2.new(1, -36, 1, -20), AnchorPoint = Vector2.new(1, 0.5) })
		UI.label(b, "+" .. appeal, 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -10, 1, -29), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(24, 18) })
	end
	local tagText = item.wall and "WALL" or item.room and "ROOMS" or item.shape and "CUSTOM" or (item.coreKind and "UPGRADE") or nil
	if tagText then
		local tag = UI.new("TextLabel", {
			Text = tagText, TextSize = 10, FontFace = UI.F.heavy, TextColor3 = T.muted, BackgroundColor3 = T.ink2,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), Position = UDim2.fromOffset(6, 6), ZIndex = 3, Parent = well,
		})
		UI.corner(tag, 5)
		UI.pad(tag, 5, 0, 5, 0)
	end
	-- a level or research lock
	local lockF = UI.new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.white, BackgroundTransparency = 0.2, ZIndex = 4, Visible = false, Parent = well })
	UI.icon(lockF, UI.G.lock, 22, { ImageColor3 = T.muted, Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
	local lockName = UI.label(lockF, "", 11, {
		FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
		Position = UDim2.new(0, 4, 0.5, 2), Size = UDim2.new(1, -8, 0.5, -4), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
	})
	local function lockText()
		if lockOf(id) == "level" then
			lockName.Text = "Hotel level " .. Levels.itemLevel(id)
		elseif item.research then
			lockName.Text = "Research: " .. Research.BY_ID[item.research].name
		end
	end
	lockText()
	local hover = false
	b.MouseEnter:Connect(function()
		hover = true
		b.BackgroundColor3 = T.ink3
		st.Transparency = 0.4
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		hover = false
		b.BackgroundColor3 = T.ink2
		local c = cards[id]
		st.Transparency = c and c.sel and 0 or 1
	end)
	b.Activated:Connect(function()
		local lock = lockOf(id)
		if lock == "level" then
			UI.shake(b)
			toast("The " .. string.lower(item.name) .. " unlocks at hotel level " .. Levels.itemLevel(id), "star", true)
			return
		elseif lock then
			UI.shake(b)
			toast("Unlock the " .. string.lower(item.name) .. " in Research: " .. Research.BY_ID[item.research].name, "research", true)
			player:SetAttribute("OpenResearch", item.research)
			return
		end
		if cash() < itemPrice(id, item.shape and S.shape) then
			UI.shake(b)
			toast("Not enough cash for the " .. string.lower(item.name), "cash", true)
			return
		end
		UI.sound("Click")
		startPlacing(id)
	end)
	cards[id] = { id = id, button = b, card = b, well = well, stroke = st, price = price, lock = lockF, lockText = lockText, hover = function() return hover end, order = order }
end

for i, id in ipairs(Catalog.ORDER) do
	local item = Catalog.ITEMS[id]
	if item and (item.shape or ITEMS:FindFirstChild(id)) and item.cat then
		makeCard(id, i)
	end
end

-- more land: the first tile in All, Rooms and Structure (click twice to buy)
local buyRoom -- forward
local room = { armed = 0 }
do
	local b = UI.new("TextButton", { Name = "RoomCard", Text = "", AutoButtonColor = false, BackgroundColor3 = T.brandSoft, LayoutOrder = -100, Parent = list })
	UI.corner(b, 14)
	UI.stroke(b, 2, T.brand, 0.5)
	UI.icon(b, UI.G.plus, 40, { ImageColor3 = T.brand, Position = UDim2.new(0.5, 0, 0, 26), AnchorPoint = Vector2.new(0.5, 0) })
	local note = UI.label(b, "+26 x 60 studs", 11, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 74), Size = UDim2.new(1, 0, 0, 14) })
	local title = UI.label(b, "More land", 14, { FontFace = UI.F.bold, Position = UDim2.new(0, 10, 1, -52), Size = UDim2.new(1, -20, 0, 18) })
	local price = UI.label(b, "$400", 15, { FontFace = UI.F.heavy, TextColor3 = T.greenDk, Position = UDim2.new(0, 10, 1, -30), Size = UDim2.new(1, -20, 0, 20) })
	room.button, room.card, room.title, room.price, room.note = b, b, title, price, note
	b.MouseEnter:Connect(function() UI.sound("Hover") end)
	b.Activated:Connect(function()
		local id = HOTEL:GetAttribute("NextRoom")
		if not id then return end
		if Levels.of(HOTEL) < Levels.roomLevel(id) then
			UI.shake(b)
			toast("More land unlocks at hotel level " .. Levels.roomLevel(id), "star", true)
			return
		end
		if cash() < (HOTEL:GetAttribute("NextRoomPrice") or 0) then
			UI.shake(b)
			toast("Not enough cash for more land", "cash", true)
			return
		end
		if os.clock() - room.armed > 4 then
			room.armed = os.clock()
			UI.sound("Click")
			room.refresh()
			task.delay(4.1, room.refresh)
			return
		end
		room.armed = 0
		buyRoom(id)
		room.refresh()
	end)
end

function room.refresh()
	local id = HOTEL:GetAttribute("NextRoom")
	local price = HOTEL:GetAttribute("NextRoomPrice") or 0
	room.button.Visible = id ~= nil and S.query == "" and (S.cat == "all" or S.cat == "rooms" or S.cat == "structure")
	if not id then return end
	local armed = os.clock() - room.armed < 4
	local need = Levels.roomLevel(id)
	local locked = Levels.of(HOTEL) < need
	room.title.Text = armed and "Click again to buy" or "More land"
	room.price.Text = locked and ("Hotel level " .. need) or ("$" .. commas(price))
	room.price.TextColor3 = locked and T.muted or (cash() >= price and T.greenDk or T.red)
	room.button.BackgroundColor3 = armed and Color3.fromRGB(228, 250, 236) or T.brandSoft
end
HOTEL:GetAttributeChangedSignal("NextRoom"):Connect(room.refresh)

refreshCards = function(arrive)
	local money = cash()
	local shown = 0
	for id, c in pairs(cards) do
		local item = Catalog.ITEMS[id]
		local vis = (S.cat == "all" or item.cat == S.cat)
		if S.query ~= "" then vis = string.find(string.lower(item.name), S.query, 1, true) ~= nil end
		c.button.Visible = vis
		if vis then
			shown += 1
			if S.building then wantThumb(c) end
		end
		local p = itemPrice(id, item.shape and S.shape)
		c.price.Text = "$" .. commas(p)
		local open = unlocked(id)
		-- what you can use comes first, locked items after (catalogue order inside each group)
		c.button.LayoutOrder = (open and 0 or 1000) + (c.order or 0)
		c.lock.Visible = not open
		if not open then c.lockText() end
		c.price.TextColor3 = money >= p and T.greenDk or T.red
		c.sel = ghost and not ghost.moving and ghost.id == id
		if not c.hover() then c.stroke.Transparency = c.sel and 0 or 1 end
	end
	room.refresh()
	emptyNote.Visible = shown == 0
	if arrive then list.CanvasPosition = Vector2.zero end
end

local function refreshCash()
	if cash() == math.huge then -- the /mmoney command
		cashText.Text = "Infinite"
	else
		UI.countTo(cashText, cash(), function(v) return "$" .. commas(v) end, 0.45)
	end
	refreshCards()
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
HOTEL:GetAttributeChangedSignal("Research"):Connect(function() refreshCards() end)
HOTEL:GetAttributeChangedSignal("Level"):Connect(function() refreshCards() end)
tabsApi.select("all", true)
refreshCash()

---------------------------------------------------------------- the tool bar (bottom)
-- One dark bar: the Room Builder, then a chip per setting (click to step through its choices), then Undo.

local toolWrap = wrapper("Tools", UDim2.fromOffset(1040, 64), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
toolWrap.Visible = false
local toolHolder = UI.new("Frame", {
	Name = "Bar", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 64), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.hud, BackgroundTransparency = 0.08, Parent = toolWrap,
})
UI.corner(toolHolder, 18)
UI.stroke(toolHolder, 1, T.hudLine, 0.2)
UI.pad(toolHolder, 8, 0, 8, 0)
UI.list(toolHolder, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
S.rbRailBtn = UI.button(toolHolder, {
	name = "RoomBuilder", text = "Room Builder", icon = ICON.roomReady, iconSize = 24, kind = "gold", key = "F",
	size = UDim2.fromOffset(196, 48), textSize = 16, radius = 12, order = 1,
	onClick = function() if S.toggleRoom then S.toggleRoom() end end,
})
UI.new("Frame", { Name = "Div", Size = UDim2.fromOffset(1, 28), BackgroundColor3 = T.hudLine, BorderSizePixel = 0, LayoutOrder = 2, Parent = toolHolder })
-- options = { { value, text }, ... }; a click moves on to the next one
local function toolChip(label, options, current, order, tip, cb)
	local b = UI.new("TextButton", { Name = "Chip_" .. label, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(#label > 9 and 104 or 84, 48), BackgroundColor3 = T.hud2, LayoutOrder = order, Parent = toolHolder })
	UI.corner(b, 12)
	UI.label(b, label, 10, { FontFace = UI.F.heavy, TextColor3 = T.hudMuted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 12) })
	local v = UI.label(b, "", 15, { FontFace = UI.F.heavy, TextColor3 = T.hudText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 20) })
	local idx = 1
	for i, o in ipairs(options) do if o[1] == current then idx = i end end
	local function show()
		local o = options[idx]
		v.Text = o[2]
		v.TextColor3 = o[1] == true and T.green or (o[1] == false or o[1] == 0) and T.hudMuted or T.hudText
	end
	show()
	b.MouseEnter:Connect(function() b.BackgroundColor3 = T.hudLine end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = T.hud2 end)
	b.Activated:Connect(function()
		idx = idx % #options + 1
		show()
		UI.sound("Tick")
		cb(options[idx][1])
	end)
	if tip then UI.tooltip(b, tip) end
	return function(value)
		for i, o in ipairs(options) do if o[1] == value then idx = i end end
		show()
	end
end
local ONOFF = { { true, "On" }, { false, "Off" } }
toolChip("GRID", { { 0, "Off" }, { 0.5, "0.5" }, { 1, "1" }, { 2, "2" }, { 4, "4" } }, S.grid, 3, "How far things snap, in studs", function(v) S.grid = v end)
toolChip("TURN", { { 90, "90" }, { 45, "45" }, { 15, "15" } }, S.yawStep, 4, "How far R turns something, in degrees", function(v) S.yawStep = v end)
toolChip("ROOF", { { "auto", "Auto" }, { "show", "Show" }, { "hide", "Hide" } }, S.roof, 5, "Show or hide the roof while you build", function(v)
	S.roof = v
	player:SetAttribute("RoofMode", v)
end)
S.setZones = toolChip("ZONES", ONOFF, S.zones, 6, "Colour each room's floor", function(on)
	S.zones = on
	S.applyZones()
end)
S.wallSnap = true
S.keep = false
toolChip("WALL SNAP", ONOFF, true, 7, "Walls lock onto wall ends", function(on) S.wallSnap = on end)
toolChip("KEEP PLACING", ONOFF, false, 8, "Keep the item in hand after you place it", function(on) S.keep = on end)
UI.new("Frame", { Name = "Div2", Size = UDim2.fromOffset(1, 28), BackgroundColor3 = T.hudLine, BorderSizePixel = 0, LayoutOrder = 9, Parent = toolHolder })
S.undo = {} -- uids you placed, newest last
UI.button(toolHolder, {
	name = "Undo", text = "Undo", icon = ICON.rotate, iconSize = 18, kind = "ink", textSize = 15, key = "Z",
	size = UDim2.fromOffset(116, 48), radius = 12, order = 10, onClick = function() S.doUndo() end,
})

---------------------------------------------------------------- place bar (over the tool bar, while something is in hand)

local barWrap = wrapper("PlaceBar", UDim2.fromOffset(820, 64), UDim2.new(0.5, 0, 1, -88), Vector2.new(0.5, 1))
barWrap.Visible = false
local bar = UI.new("Frame", {
	Name = "Bar", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 64), Position = UDim2.fromScale(0.5, 0.5),
	AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.hud, BackgroundTransparency = 0.08, Parent = barWrap,
})
UI.corner(bar, 18)
UI.stroke(bar, 1, T.hudLine, 0.2)
UI.pad(bar, 8, 0, 8, 0)
UI.list(bar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local commit, turnGhost, raiseGhost, clearGhost -- forward
local heightPill = UI.new("Frame", { Name = "Height", Size = UDim2.fromOffset(84, 48), BackgroundColor3 = T.hud2, LayoutOrder = 0, Parent = bar })
UI.corner(heightPill, 12)
UI.label(heightPill, "HEIGHT", 10, { FontFace = UI.F.heavy, TextColor3 = T.hudMuted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 12) })
local heightText = UI.label(heightPill, "0.0", 15, { FontFace = UI.F.heavy, TextColor3 = T.hudText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 20) })
local barBtns = {}
barBtns.room = UI.button(bar, { text = "Room", icon = ICON.roomReady, kind = "ink", key = "F", size = UDim2.fromOffset(118, 48), radius = 12, order = 0, onClick = function() if S.toggleRoom then S.toggleRoom() end end })
barBtns.turn = UI.button(bar, { text = "Turn", icon = ICON.rotate, iconSize = 20, kind = "ink", key = "R", size = UDim2.fromOffset(116, 48), radius = 12, textSize = 15, order = 1, onClick = function() turnGhost(1) end })
barBtns.up = UI.button(bar, { icon = ICON.up, iconSize = 20, kind = "ink", key = "T", size = UDim2.fromOffset(54, 48), radius = 12, order = 2, onClick = function() raiseGhost(1) end })
barBtns.down = UI.button(bar, { icon = ICON.down, iconSize = 20, kind = "ink", key = "G", size = UDim2.fromOffset(54, 48), radius = 12, order = 3, onClick = function() raiseGhost(-1) end })
barBtns.place = UI.button(bar, { text = "Place", icon = ICON.place, iconSize = 20, kind = "green", size = UDim2.fromOffset(140, 48), radius = 12, textSize = 16, order = 4, onClick = function() commit() end })
barBtns.cancel = UI.button(bar, { text = "Cancel", icon = ICON.close, iconSize = 18, kind = "red", key = "X", size = UDim2.fromOffset(124, 48), radius = 12, textSize = 15, order = 5, onClick = function() clearGhost() end })

--@@B
---------------------------------------------------------------- selection pill (floats over the item)

local cardWrap = wrapper("ItemCard", UDim2.fromOffset(540, 104), UDim2.new(), Vector2.new(0.5, 1))
cardWrap.Visible = false
local cardHolder = UI.new("Frame", {
	Name = "Card", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = T.hud, BackgroundTransparency = 0.06, Parent = cardWrap,
})
UI.corner(cardHolder, 18)
UI.stroke(cardHolder, 1, T.hudLine, 0.2)
local cardBody = cardHolder
local cardTitle = UI.label(cardBody, "", 16, { FontFace = UI.F.heavy, TextColor3 = T.hudText, Position = UDim2.fromOffset(18, 11), Size = UDim2.new(0.45, -18, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
local cardSub = UI.label(cardBody, "", 12, { FontFace = UI.F.bold, TextColor3 = T.hudMuted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.45, 0, 0, 12), Size = UDim2.new(0.55, -18, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
local cardRow = UI.new("Frame", { Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 46), BackgroundTransparency = 1, Parent = cardBody })
UI.list(cardRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local cardBtns = {}
local cardActions = {} -- forward table of functions
local function cardBtn(key, text, iconKey, kind, order, hotkey)
	local b = UI.button(cardRow, {
		name = key, text = text, icon = ICON[iconKey], kind = kind, key = hotkey, textSize = 15, iconSize = 20,
		size = UDim2.fromOffset(text and 92 or 46, 42), order = order, radius = 12,
		onClick = function() cardActions[key]() end,
	})
	cardBtns[key] = b
	return b
end
cardBtn("move", "Move", "move", "gold", 1, "M")
cardBtn("turn", "Turn", "rotate", "ink", 2, "R")
cardBtn("copy", "Copy", "copy", "ink", 3, "C")
cardBtn("paint", "Paint", "paint", "ink", 4)
cardBtn("sell", "Sell", "sell", "green", 5)
cardBtn("close", nil, "close", "ink", 6)

---------------------------------------------------------------- layout

local function layout()
	local vp = camera.ViewportSize
	local k = kOf(shopWrap)
	-- the catalog runs down the left edge, under the hotel plate
	shopWrap.Size = UDim2.fromOffset(404, math.clamp((vp.Y - 150) / k, 380, 900))
	shopWrap.Position = UDim2.new(0, 16, 1, -14)
	-- the bars sit in the middle of what's left
	local left = 32 + 404 * k
	local cx = left + math.max(vp.X - left - 16, 300) / 2
	toolWrap.Position = UDim2.new(0, cx, 1, -14)
	barWrap.Position = UDim2.new(0, cx, 1, -14 - 72 * kOf(toolWrap))
	if S.building then
		btnWrap.AnchorPoint = Vector2.new(1, 0)
		btnWrap.Position = UDim2.new(1, -18, 0, 12)
		dockHolder.AnchorPoint = Vector2.new(1, 0)
		dockHolder.Position = UDim2.new(1, 0, 0, 0)
	else
		btnWrap.AnchorPoint = Vector2.new(0.5, 1)
		btnWrap.Position = UDim2.new(0.5, 0, 1, -16)
		dockHolder.AnchorPoint = Vector2.new(0.5, 1)
		dockHolder.Position = UDim2.new(0.5, 0, 1, 0)
	end
	for _, b in ipairs(menuBtns) do b.Visible = not S.building end
	local div = rowList:FindFirstChild("Div")
	if div then div.Visible = not S.building end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(layout) end)

