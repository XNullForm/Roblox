-- ReplicatedStorage.Shared.BuildKit (round 42): build mode's shop, tools, selection and advanced placement.
-- BuildClient keeps the camera, the ghost (snapping, stacking, walls), drag rows and the Room Builder, and hands this
-- module an `api` table; require(BuildKit)(api) builds everything here and returns K. Coop restarts BuildClient (and
-- clears its children), so every bit of state lives inside the call.
--   Shop (right): tabs and sub-tabs from Catalog.TABS / TAB_OF, search, a Recent tab, 3-wide cards, hotel styles, land.
--   Tool rail (left): 1 Select, 2 Box select, 3 Delete, 4 Paint, 5 Pick (eyedropper), 6 Room, Undo, View (roof/walls/zones).
--   Selection: click / Shift+click / box; a bar with Move, Turn, Copy, All like this, Paint, Sell. Groups move, turn
--   and copy together (BuildServer moveMany / placeBatch); arrows nudge, Delete sells, Ctrl+A picks every one alike.
--   Placement panel: exact X / Z / height / angle, nudge pad, grid and turn steps, wall snap, hug walls, stacking,
--   keep placing, lock spot.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Build = require(Shared:WaitForChild("Build"))
local Research = require(Shared:WaitForChild("Research"))
local Levels = require(Shared:WaitForChild("Levels"))
local Up = require(Shared:WaitForChild("Upgrades"))
local UI = require(Shared:WaitForChild("UI"))
local T = UI.T
local ICON = C.ICONS
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(170, 186, 212)
local CHIP = Color3.fromRGB(44, 58, 84)
local CHIP_ON = Color3.fromRGB(62, 120, 230)
local GOOD = Color3.fromRGB(110, 235, 140)
local BAD = Color3.fromRGB(255, 96, 96)
local TEAL = Color3.fromRGB(32, 176, 168)

return function(api)
	local K = { tool = "select", sel = {}, selSet = {}, recent = {}, tab = "all", sub = nil, query = "" }
	local S, HOTEL, PLACED, Remote = api.S, api.HOTEL, api.PLACED, api.Remote
	local O = HOTEL:GetAttribute("Origin") or Vector3.zero
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local commas = UI.commas
	local toast = api.toast
	local pgui = player:WaitForChild("PlayerGui")
	-- a restarted BuildClient (Coop) leaves the last kit's bits behind
	if workspace:FindFirstChild("BuildKitLocal") then workspace.BuildKitLocal:Destroy() end
	if pgui:FindFirstChild("KitTip") then pgui.KitTip:Destroy() end
	local kitFolder = Instance.new("Folder")
	kitFolder.Name = "BuildKitLocal"
	kitFolder.Parent = workspace
	local function shift() return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) end
	local function ctrl() return UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl) end
	local function pushUndo(u)
		u.t = os.clock()
		table.insert(S.undo, u)
		if #S.undo > 20 then table.remove(S.undo, 1) end
	end

	-- dark glass, the look of every bar and panel here
	local function glass(f, r)
		f.BackgroundColor3 = WHITE
		f.BackgroundTransparency = 0.02
		UI.corner(f, r or 18)
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(40, 54, 80), Color3.fromRGB(20, 28, 44)), Parent = f })
		UI.stroke(f, 1.5, Color3.fromRGB(74, 94, 128), 0.05)
	end
	local function txt(parent, text, size, props)
		props = props or {}
		props.FontFace = props.FontFace or UI.F.heavy
		props.TextColor3 = props.TextColor3 or WHITE
		props.BackgroundTransparency = 1
		return UI.label(parent, text, size, props)
	end
	-- a small dark chip button; returns the button and a setter for its "on" look
	local function chip(parent, text, w, order, onClick, tip)
		local b = UI.new("TextButton", {
			Name = "Chip_" .. string.gsub(text, " ", ""), Text = text, TextSize = 15, FontFace = UI.F.heavy, TextColor3 = MUTED, AutoButtonColor = false,
			Size = UDim2.fromOffset(w, 34), BackgroundColor3 = CHIP, LayoutOrder = order or 0, Parent = parent,
		})
		UI.corner(b, 10)
		local st = UI.stroke(b, 1.5, Color3.fromRGB(80, 100, 136), 0.2)
		local on = false
		local function set(v)
			on = v
			b.BackgroundColor3 = v and CHIP_ON or CHIP
			b.TextColor3 = v and WHITE or MUTED
			st.Color = v and Color3.fromRGB(140, 180, 255) or Color3.fromRGB(80, 100, 136)
		end
		b.MouseEnter:Connect(function() if not on then b.BackgroundColor3 = Color3.fromRGB(56, 72, 102) end UI.sound("Hover") end)
		b.MouseLeave:Connect(function() set(on) end)
		b.Activated:Connect(function()
			UI.sound("Tick")
			UI.pop(b, 0.9, 0.2)
			onClick()
		end)
		if tip then UI.tooltip(b, tip) end
		return b, set
	end

	------------------------------------------------------------------ the shop (right)

	local SHOP_W = 440
	local shopWrap = api.wrapper("Shop", UDim2.fromOffset(SHOP_W, 760), UDim2.new(1, -16, 1, -14), Vector2.new(1, 1))
	shopWrap.Visible = false
	local shopHolder, shopBody = UI.panel(shopWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
		name = "Catalog", radius = 18, title = "Build Shop", subtitle = "Pick something, then click to place it", icon = ICON.hammer,
	})
	shopHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	K.shopWrap, K.shopHolder, K.SHOP_W = shopWrap, shopHolder, SHOP_W

	local cashText
	do
		local pill = UI.new("Frame", {
			Name = "Cash", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), Position = UDim2.new(1, -16, 0, 15),
			AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(228, 250, 236), ZIndex = 5, Parent = shopBody,
		})
		UI.corner(pill, 16)
		UI.pad(pill, 12, 0, 12, 0)
		cashText = UI.new("TextLabel", {
			Text = "$0", TextSize = 17, FontFace = UI.F.heavy, TextColor3 = T.greenDk, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 6, Parent = pill,
		})
	end

	local searchBox = UI.new("Frame", { Name = "Search", Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 68), BackgroundColor3 = T.ink2, Parent = shopBody })
	UI.corner(searchBox, 12)
	local searchStroke = UI.stroke(searchBox, 1.5, T.line, 0)
	UI.icon(searchBox, ICON.search, 20, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local searchInput = UI.new("TextBox", {
		Text = "", PlaceholderText = "Search " .. #Catalog.ORDER .. " items", PlaceholderColor3 = T.muted, TextSize = 16, FontFace = UI.F.bold,
		TextColor3 = T.cream, BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(40, 0), Parent = searchBox,
	})
	searchInput.Focused:Connect(function() UI.tween(searchStroke, 0.15, { Color = T.brand }) end)
	searchInput.FocusLost:Connect(function() UI.tween(searchStroke, 0.15, { Color = T.line }) end)
	K.search = searchInput

	-- tabs: two rows of icon tiles
	local tabGrid = UI.new("Frame", { Name = "Tabs", Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 120), BackgroundTransparency = 1, Parent = shopBody })
	do
		local g = Instance.new("UIGridLayout")
		g.CellSize = UDim2.new(1 / 7, -5, 0, 58)
		g.CellPadding = UDim2.fromOffset(5, 4)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = tabGrid
	end
	local tabBtns = {}
	local subRow = UI.new("ScrollingFrame", {
		Name = "Subs", Position = UDim2.fromOffset(16, 242), Size = UDim2.new(1, -32, 0, 36), BackgroundTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
		ScrollBarThickness = 0, Parent = shopBody,
	})
	UI.list(subRow, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)

	local list = UI.new("ScrollingFrame", {
		Name = "Items", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 284), Size = UDim2.new(1, -24, 1, -294),
		ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollBarThickness = 5, ScrollBarImageColor3 = T.muted, ScrollBarImageTransparency = 0.3, Parent = shopBody,
	})
	do
		local g = Instance.new("UIGridLayout")
		g.CellSize = UDim2.new(1 / 3, -8, 0, 164)
		g.CellPadding = UDim2.fromOffset(8, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = list
		UI.pad(list, 4, 4, 10, 10)
	end
	K.list = list
	local emptyNote = UI.label(shopBody, "Nothing here yet", 16, {
		FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 320), Size = UDim2.new(1, -32, 0, 22), Visible = false,
	})

	local thumb = api.thumb -- a 3D thumbnail of an item (BuildClient's; the Room Builder uses it too)
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

	local TAB_INDEX = {}
	for i, t in ipairs(Catalog.TABS) do TAB_INDEX[t.id] = i end
	local ORDER_INDEX = {}
	for i, id in ipairs(Catalog.ORDER) do ORDER_INDEX[id] = i end
	local function tabOf(id)
		local t = Catalog.TAB_OF[id]
		if t then return t[1], t[2], t[3] end
		local it = Catalog.ITEMS[id]
		return Catalog.TAB_ALIAS[it and it.cat or ""] or (it and it.cat) or "decor", nil, ORDER_INDEX[id] or 0
	end
	local function lockText(id)
		local it = Catalog.ITEMS[id]
		local lock = api.lockOf(id)
		if lock == "level" then return "Hotel level " .. Levels.itemLevel(id) end
		if lock == "research" then return "Research: " .. Research.BY_ID[it.research].name end
		return nil
	end

	local cards = {}
	local function makeCard(id)
		local item = Catalog.ITEMS[id]
		local b = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, Parent = list })
		UI.corner(b, 14)
		local rim = UI.stroke(b, 2, Color3.fromRGB(222, 230, 242), 0)
		local well = UI.new("Frame", { Name = "Well", Size = UDim2.new(1, -10, 1, -58), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = WHITE, ClipsDescendants = true, Parent = b })
		UI.corner(well, 10)
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(244, 248, 253), Color3.fromRGB(222, 231, 243)), Parent = well })
		UI.label(b, item.name, 14, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		local price = UI.label(b, "", 15, { FontFace = UI.F.black, TextColor3 = T.greenDk, Position = UDim2.new(0, 8, 1, -29), Size = UDim2.new(0.62, 0, 0, 20) })
		local appeal = item.shape and Build.SHAPE_APPEAL or item.appeal or 0
		if appeal > 0 then
			UI.icon(b, UI.G.star, 14, { ImageColor3 = T.sun, Position = UDim2.new(1, -30, 1, -19), AnchorPoint = Vector2.new(1, 0.5) })
			UI.label(b, "+" .. appeal, 14, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -8, 1, -29), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(22, 20) })
		end
		local tagText = item.wall and "ON WALLS" or item.room and "ROOMS" or item.shape and "CUSTOM" or item.coreKind and "UPGRADE" or item.flat and "FLAT" or nil
		if tagText then
			local tag = UI.new("TextLabel", {
				Text = tagText, TextSize = 11, FontFace = UI.F.heavy, TextColor3 = WHITE, BackgroundColor3 = T.brand,
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), Position = UDim2.fromOffset(6, 6), ZIndex = 3, Parent = well,
			})
			UI.corner(tag, 6)
			UI.pad(tag, 6, 0, 6, 0)
		end
		local lockF = UI.new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.18, ZIndex = 4, Visible = false, Parent = well })
		UI.icon(lockF, UI.G.lock, 24, { ImageColor3 = T.muted, Position = UDim2.fromScale(0.5, 0.34), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
		local lockName = UI.label(lockF, "", 13, {
			FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
			Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(1, -8, 0.5, -2), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
		})
		local hover = false
		b.MouseEnter:Connect(function()
			hover = true
			UI.tween(b, 0.12, { BackgroundColor3 = Color3.fromRGB(240, 246, 255) })
			rim.Color = T.brand
			UI.sound("Hover")
		end)
		b.MouseLeave:Connect(function()
			hover = false
			UI.tween(b, 0.15, { BackgroundColor3 = WHITE })
			local c = cards[id]
			rim.Color = c and c.sel and T.brand or Color3.fromRGB(222, 230, 242)
		end)
		UI.tooltip(b, function()
			local l = lockText(id)
			return item.name .. (appeal > 0 and ("  (+" .. appeal .. " appeal)") or "") .. (l and ("  -  " .. l) or "")
		end)
		b.Activated:Connect(function()
			local lock = api.lockOf(id)
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
			if api.cash() < api.itemPrice(id, item.shape and S.shape) then
				UI.shake(b)
				toast("Not enough cash for the " .. string.lower(item.name), "cash", true)
				return
			end
			UI.sound("Click")
			UI.pop(b, 0.92, 0.25)
			if K.tool ~= "select" then K.setTool("select") end
			api.startPlacing(id)
		end)
		local tab, sub, n = tabOf(id)
		cards[id] = { id = id, button = b, well = well, rim = rim, price = price, lock = lockF, lockName = lockName, hover = function() return hover end, tab = tab, sub = sub, n = n }
	end
	for _, id in ipairs(Catalog.ORDER) do
		local item = Catalog.ITEMS[id]
		if item and not item.hidden and (item.shape or Shared.Items:FindFirstChild(id)) then makeCard(id) end
	end

	-- more land (Build > Land, and All)
	local room = { armed = 0 }
	do
		local b = UI.new("TextButton", { Name = "RoomCard", Text = "", AutoButtonColor = false, BackgroundColor3 = T.brandSoft, LayoutOrder = -100, Parent = list })
		UI.corner(b, 14)
		UI.stroke(b, 2, T.brand, 0.3)
		UI.icon(b, UI.G.plus, 40, { ImageColor3 = T.brand, Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0) })
		local note = UI.label(b, "+26 x 60 studs", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(1, 0, 0, 16) })
		local title = UI.label(b, "More land", 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.new(0, 8, 1, -52), Size = UDim2.new(1, -16, 0, 20) })
		local price = UI.label(b, "$400", 15, { FontFace = UI.F.black, TextColor3 = T.greenDk, Position = UDim2.new(0, 8, 1, -29), Size = UDim2.new(1, -16, 0, 20) })
		room.button, room.title, room.price, room.note = b, title, price, note
		b.MouseEnter:Connect(function() UI.sound("Hover") end)
		b.Activated:Connect(function()
			local id = HOTEL:GetAttribute("NextRoom")
			if not id then return end
			if Levels.of(HOTEL) < Levels.roomLevel(id) then
				UI.shake(b)
				toast("More land unlocks at hotel level " .. Levels.roomLevel(id), "star", true)
				return
			end
			if api.cash() < (HOTEL:GetAttribute("NextRoomPrice") or 0) then
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
			api.buyRoom(id)
			room.refresh()
		end)
	end
	function room.refresh()
		local id = HOTEL:GetAttribute("NextRoom")
		local price = HOTEL:GetAttribute("NextRoomPrice") or 0
		room.button.Visible = id ~= nil and K.query == "" and (K.tab == "all" or (K.tab == "build" and (K.sub == nil or K.sub == "land")))
		if not id then return end
		local armed = os.clock() - room.armed < 4
		local need = Levels.roomLevel(id)
		local locked = Levels.of(HOTEL) < need
		room.title.Text = armed and "Click again to buy" or "More land"
		room.price.Text = locked and ("Hotel level " .. need) or ("$" .. commas(price))
		room.price.TextColor3 = locked and T.muted or (api.cash() >= price and T.greenDk or T.red)
		room.button.BackgroundColor3 = armed and Color3.fromRGB(228, 250, 236) or T.brandSoft
	end
	HOTEL:GetAttributeChangedSignal("NextRoom"):Connect(room.refresh)

	-- Build > Styles: the hotel's floors, walls and roof (free; they left the Upgrades page)
	local styles = UI.new("ScrollingFrame", {
		Name = "Styles", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 284), Size = UDim2.new(1, -24, 1, -294), Visible = false,
		ScrollingDirection = Enum.ScrollingDirection.Y, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollBarThickness = 5, ScrollBarImageColor3 = T.muted, Parent = shopBody,
	})
	UI.list(styles, nil, 8)
	UI.pad(styles, 4, 4, 10, 10)
	local styleBtns = {}
	do
		local upRemote = Shared.Remotes:WaitForChild("Upgrade")
		for gi, g in ipairs(Up.STYLES) do
			UI.label(styles, string.upper(g.name), 15, { FontFace = UI.F.black, TextColor3 = T.muted, LayoutOrder = gi * 10, Size = UDim2.new(1, 0, 0, 20) })
			local grid = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = gi * 10 + 1, Parent = styles })
			local gl = Instance.new("UIGridLayout")
			gl.CellSize = UDim2.new(1 / 2, -4, 0, 44)
			gl.CellPadding = UDim2.fromOffset(8, 6)
			gl.SortOrder = Enum.SortOrder.LayoutOrder
			gl.Parent = grid
			for ei, e in ipairs(g.list) do
				local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = T.ink2, LayoutOrder = ei, Parent = grid })
				UI.corner(b, 12)
				local st = UI.stroke(b, 2, T.brand, 1)
				local sw = UI.new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = e[3], Parent = b })
				UI.corner(sw, UDim.new(0.5, 0))
				UI.stroke(sw, 1.5, UI.shade(e[3], -0.3), 0)
				UI.label(b, e[2], 15, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -50, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
				b.MouseEnter:Connect(function() UI.sound("Hover") end)
				b.Activated:Connect(function()
					UI.sound("Click")
					UI.pop(b, 0.9, 0.2)
					task.spawn(function()
						local ok, why = upRemote:InvokeServer("style", g.key, e[1])
						if not ok then toast(why or "Can't change that", nil, true) end
					end)
				end)
				table.insert(styleBtns, { key = g.key, id = e[1], stroke = st })
			end
		end
		local function paintStyles()
			local cur = Up.style(HOTEL)
			for _, s in ipairs(styleBtns) do s.stroke.Transparency = cur[s.key] == s.id and 0 or 1 end
		end
		HOTEL:GetAttributeChangedSignal("Style"):Connect(paintStyles)
		paintStyles()
	end

	local function refreshCards(arrive)
		local money = api.cash()
		local shown = 0
		local g = api.ghost()
		local recentAt = {}
		for i, id in ipairs(K.recent) do recentAt[id] = i end
		local isStyles = K.tab == "build" and K.sub == "styles" and K.query == ""
		styles.Visible = isStyles
		list.Visible = not isStyles
		for id, c in pairs(cards) do
			local item = Catalog.ITEMS[id]
			local vis
			if K.query ~= "" then
				vis = string.find(string.lower(item.name), K.query, 1, true) ~= nil
			elseif K.tab == "recent" then
				vis = recentAt[id] ~= nil
			else
				vis = (K.tab == "all" or c.tab == K.tab) and (K.sub == nil or c.sub == K.sub)
			end
			c.button.Visible = vis and not isStyles
			local open = api.lockOf(id) == nil
			local p = api.itemPrice(id, item.shape and S.shape)
			if vis then
				shown += 1
				if S.building then wantThumb(c) end
				c.price.Text = "$" .. commas(p)
				c.price.TextColor3 = money >= p and T.greenDk or T.red
				c.lock.Visible = not open
				if not open then c.lockName.Text = lockText(id) or "" end
			end
			-- what you can use comes first, in tab order
			c.button.LayoutOrder = K.tab == "recent" and (recentAt[id] or 0) or ((open and 0 or 100000) + (TAB_INDEX[c.tab] or 0) * 1000 + (c.n or 0))
			c.sel = g and not g.moving and g.id == id
			if not c.hover() then c.rim.Color = c.sel and T.brand or Color3.fromRGB(222, 230, 242) end
		end
		room.refresh()
		if room.button.Visible then shown += 1 end
		emptyNote.Text = K.tab == "recent" and "Things you place show up here" or "Nothing matches that search"
		emptyNote.Visible = shown == 0 and not isStyles
		if arrive then list.CanvasPosition = Vector2.zero end
	end
	K.refreshCards = refreshCards

	-- the sub-tab chips of the open tab
	local function buildSubs()
		for _, c in ipairs(subRow:GetChildren()) do if c:IsA("GuiButton") then c:Destroy() end end
		local def
		for _, t in ipairs(Catalog.TABS) do if t.id == K.tab then def = t end end
		local subs = def and def.subs
		subRow.Visible = subs ~= nil and K.query == ""
		local y = subRow.Visible and 284 or 246
		list.Position = UDim2.fromOffset(12, y)
		list.Size = UDim2.new(1, -24, 1, -(y + 10))
		styles.Position, styles.Size = list.Position, list.Size
		if not subs then return end
		local all = { { nil, "All" } }
		for _, s in ipairs(subs) do table.insert(all, s) end
		for i, s in ipairs(all) do
			local on = K.sub == s[1]
			local b = UI.new("TextButton", {
				Name = "Sub_" .. (s[1] or "all"), Text = s[2], TextSize = 15, FontFace = UI.F.heavy, AutoButtonColor = false,
				TextColor3 = on and WHITE or T.cream, BackgroundColor3 = on and T.brand or T.ink2,
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 32), LayoutOrder = i, Parent = subRow,
			})
			UI.corner(b, 16)
			UI.pad(b, 14, 0, 14, 0)
			b.Activated:Connect(function()
				UI.sound("Tab")
				K.sub = s[1]
				buildSubs()
				refreshCards(true)
			end)
		end
	end

	local function selectTab(id, silent)
		id = Catalog.TAB_ALIAS[id] or id
		if not TAB_INDEX[id] then id = "all" end
		K.tab = id
		K.sub = nil
		for tid, tb in pairs(tabBtns) do
			local on = tid == id
			tb.b.BackgroundColor3 = on and T.brand or T.ink2
			tb.t.TextColor3 = on and WHITE or T.muted
			tb.st.Transparency = on and 0 or 1
		end
		buildSubs()
		if not silent then refreshCards(true) end
	end
	for i, t in ipairs(Catalog.TABS) do
		local b = UI.new("TextButton", { Name = "Tab_" .. t.id, Text = "", AutoButtonColor = false, BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = tabGrid })
		UI.corner(b, 12)
		local st = UI.stroke(b, 2, T.brandDk, 1)
		local ic = UI.icon(b, ICON[t.icon] or ICON.catAll, 28, { Position = UDim2.new(0.5, 0, 0, 5), AnchorPoint = Vector2.new(0.5, 0) })
		local lb = UI.new("TextLabel", {
			Text = t.name, TextScaled = true, FontFace = UI.F.heavy, TextColor3 = T.muted, BackgroundTransparency = 1,
			Position = UDim2.new(0, 2, 1, -20), Size = UDim2.new(1, -4, 0, 16), Parent = b,
		})
		UI.new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = lb })
		b.MouseEnter:Connect(function() if K.tab ~= t.id then b.BackgroundColor3 = T.ink3 end UI.sound("Hover") end)
		b.MouseLeave:Connect(function() if K.tab ~= t.id then b.BackgroundColor3 = T.ink2 end end)
		b.Activated:Connect(function()
			UI.sound("Tab")
			UI.pop(ic, 0.7, 0.3)
			if searchInput.Text ~= "" then searchInput.Text = "" end
			selectTab(t.id)
		end)
		UI.tooltip(b, t.name)
		tabBtns[t.id] = { b = b, t = lb, i = ic, st = st }
	end
	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		K.query = string.lower(searchInput.Text)
		buildSubs()
		refreshCards(true)
	end)
	K.tabs = { select = selectTab }
	function K.openTab(id)
		if searchInput.Text ~= "" then searchInput.Text = "" end
		selectTab(id)
	end

	local function refreshCash()
		if api.cash() == math.huge then
			cashText.Text = "Infinite"
		else
			UI.countTo(cashText, api.cash(), function(v) return "$" .. commas(v) end, 0.45)
		end
		refreshCards()
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refreshCash)
	HOTEL:GetAttributeChangedSignal("Research"):Connect(function() refreshCards() end)
	HOTEL:GetAttributeChangedSignal("Level"):Connect(function() refreshCards() end)
	selectTab("all", true)
	task.defer(refreshCash)

	-- what you placed lately (the Recent tab)
	function K.placed(id)
		local i = table.find(K.recent, id)
		if i then table.remove(K.recent, i) end
		table.insert(K.recent, 1, id)
		if #K.recent > 12 then table.remove(K.recent) end
		if K.tab == "recent" then refreshCards() end
	end

	------------------------------------------------------------------ hints per tool

	local HINTS = {
		select = { { "Click", "Select" }, { "Shift+Click", "Add more" }, { "Drag item", "Move it" }, { "Drag floor", "Pan" }, { "1-6", "Tools" }, { "B", "Done" } },
		box = { { "Drag", "Box select" }, { "Shift+Drag", "Add to it" }, { "Middle drag", "Pan" }, { "1", "Select tool" } },
		delete = { { "Click", "Sell it" }, { "Drag", "Sell everything you sweep" }, { "Z", "Undo (buys it back)" }, { "1", "Select tool" } },
		paint = { { "Click a shape", "Paint it" }, { "", "Pick a colour and finish on the left" }, { "1", "Select tool" } },
		pick = { { "Click", "Take another one of it" }, { "1", "Select tool" } },
		group = { { "Click", "Drop here" }, { "R", "Turn the group" }, { "X", "Cancel" } },
	}
	local function applyHints()
		local set = HINTS[K.tool] or HINTS.select
		if api.HINTS_IDLE then
			table.clear(api.HINTS_IDLE)
			for _, h in ipairs(set) do table.insert(api.HINTS_IDLE, h) end
		end
		if S.building and not api.ghost() and not S.roomMode then api.setHints(K.group and HINTS.group or set) end
	end
	K.applyHints = applyHints

	------------------------------------------------------------------ the tool rail (left)

	local railWrap = api.wrapper("Tools", UDim2.fromOffset(92, 640), UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5))
	railWrap.Visible = false
	local rail = UI.new("Frame", {
		Name = "Rail", Size = UDim2.fromOffset(88, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5), Parent = railWrap,
	})
	glass(rail, 24)
	UI.pad(rail, 8, 10, 8, 10)
	UI.list(rail, nil, 6, Enum.HorizontalAlignment.Center)
	K.railWrap, K.rail = railWrap, rail
	local TOOLS = {
		{ id = "select", name = "Select", icon = ICON.move, key = "1", tip = "Select: click things to pick them, Shift+click for more" },
		{ id = "box", name = "Box", icon = ICON.grid, key = "2", tip = "Box select: drag a box round everything you want" },
		{ id = "delete", name = "Delete", icon = UI.G.trash, key = "3", tip = "Delete: click to sell, drag to sell a whole sweep" },
		{ id = "paint", name = "Paint", icon = ICON.paint, key = "4", tip = "Paint: click a block or shape to colour it" },
		{ id = "pick", name = "Pick", icon = ICON.copy, key = "5", tip = "Pick: click something to take another one of it" },
		{ id = "room", name = "Room", icon = ICON.roomReady, key = "6", tip = "Room Builder: drag out a room's walls and door (F)" },
	}
	local TOOL_COL = { select = T.brand, box = T.brand, delete = T.red, paint = T.violet, pick = TEAL, room = T.green }
	local railBtns = {}
	local function railBtn(spec, order, onClick)
		local b = UI.new("TextButton", { Name = "Tool_" .. spec.id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(70, 66), BackgroundColor3 = CHIP, LayoutOrder = order, Parent = rail })
		UI.corner(b, 16)
		local st = UI.stroke(b, 2, Color3.fromRGB(140, 180, 255), 1)
		local ic = UI.icon(b, spec.icon, 32, { Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0) })
		local lb = txt(b, spec.name, 14, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 18), TextColor3 = MUTED })
		if spec.key and not (UIS.TouchEnabled and not UIS.KeyboardEnabled) then
			local k = UI.new("TextLabel", {
				Text = spec.key, TextSize = 12, FontFace = UI.F.heavy, TextColor3 = WHITE, BackgroundColor3 = Color3.fromRGB(16, 22, 36),
				Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -3, 0, 3), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, Parent = b,
			})
			UI.corner(k, 6)
		end
		b.MouseEnter:Connect(function()
			UI.sound("Hover")
			UI.tween(ic, 0.15, { Rotation = -8 }, Enum.EasingStyle.Back)
			if not b:GetAttribute("On") then b.BackgroundColor3 = Color3.fromRGB(58, 76, 108) end
		end)
		b.MouseLeave:Connect(function()
			UI.tween(ic, 0.15, { Rotation = 0 })
			if not b:GetAttribute("On") then b.BackgroundColor3 = CHIP end
		end)
		b.Activated:Connect(function()
			UI.sound("Click")
			UI.pop(ic, 0.7, 0.3)
			onClick()
		end)
		if spec.tip then UI.tooltip(b, spec.tip) end
		local r = { b = b, st = st, ic = ic, lb = lb, id = spec.id }
		function r.set(on, col)
			b:SetAttribute("On", on or nil)
			b.BackgroundColor3 = on and (col or T.brand) or CHIP
			lb.TextColor3 = on and WHITE or MUTED
			st.Transparency = on and 0 or 1
		end
		return r
	end
	for i, t in ipairs(TOOLS) do
		railBtns[t.id] = railBtn(t, i, function() K.setTool(t.id) end)
	end
	UI.new("Frame", { Name = "Div", Size = UDim2.fromOffset(52, 2), BackgroundColor3 = Color3.fromRGB(74, 94, 128), BorderSizePixel = 0, LayoutOrder = 20, Parent = rail })
	railBtn({ id = "undo", name = "Undo", icon = ICON.rotate, key = "Z", tip = "Undo the last thing you did (Z)" }, 21, function() S.doUndo() end)
	local viewBtn = railBtn({ id = "view", name = "View", icon = ICON.roof, tip = "Roof, walls and room colours" }, 22, function() K.toggleView() end)

	-- the View flyout: roof, cut-away walls, room colours
	local viewWrap = api.wrapper("ViewMenu", UDim2.fromOffset(250, 170), UDim2.new(0, 120, 1, -14), Vector2.new(0, 1))
	viewWrap.Visible = false
	local viewCard = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Parent = viewWrap })
	glass(viewCard, 18)
	UI.pad(viewCard, 12, 10, 12, 10)
	UI.list(viewCard, nil, 8)
	local function viewRow(order, label, options, get, setv)
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = order, Parent = viewCard })
		txt(row, label, 15, { Size = UDim2.new(0, 70, 1, 0) })
		local holder = UI.new("Frame", { Size = UDim2.new(1, -72, 1, 0), Position = UDim2.fromOffset(72, 0), BackgroundTransparency = 1, Parent = row })
		UI.list(holder, Enum.FillDirection.Horizontal, 4, nil, Enum.VerticalAlignment.Center)
		local sets = {}
		local function paint() for v, f in pairs(sets) do f(get() == v) end end
		for i, o in ipairs(options) do
			local _, set = chip(holder, o[2], 50, i, function() setv(o[1]) paint() end)
			sets[o[1]] = set
		end
		paint()
	end
	viewRow(1, "Roof", { { "auto", "Auto" }, { "show", "On" }, { "hide", "Off" } }, function() return S.roof end, function(v) S.roof = v player:SetAttribute("RoofMode", v) end)
	viewRow(2, "Walls", { { "cut", "Cut" }, { "full", "Full" } }, function() return S.walls end, function(v) S.walls = v end)
	viewRow(3, "Rooms", { { true, "Colour" }, { false, "Plain" } }, function() return S.zones end, function(v) S.zones = v S.applyZones() end)
	function K.toggleView(force)
		local on = force
		if on == nil then on = not viewWrap.Visible end
		viewWrap.Visible = on and S.building
		viewBtn.set(viewWrap.Visible, T.brand)
		if viewWrap.Visible then UI.pop(viewCard, 0.9, 0.25) end
	end

	------------------------------------------------------------------ the paint palette (beside the rail, Paint tool)

	local paintWrap = api.wrapper("PaintMenu", UDim2.fromOffset(280, 330), UDim2.new(0, 120, 0.5, 0), Vector2.new(0, 0.5))
	paintWrap.Visible = false
	local paintCard = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Parent = paintWrap })
	glass(paintCard, 18)
	txt(paintCard, "PAINT", 16, { FontFace = UI.F.black, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 20) })
	txt(paintCard, "Click a block or shape", 14, { TextColor3 = MUTED, FontFace = UI.F.bold, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -28, 0, 18) })
	local paintSw, paintMat = {}, {}
	do
		local sw = UI.new("Frame", { Position = UDim2.fromOffset(14, 56), Size = UDim2.new(1, -28, 0, 120), BackgroundTransparency = 1, Parent = paintCard })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(1 / 6, -6, 0, 32)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.Parent = sw
		for i, col in ipairs(Catalog.SWATCHES) do
			local b = UI.new("TextButton", { Text = "", BackgroundColor3 = col, AutoButtonColor = false, LayoutOrder = i, Parent = sw })
			UI.corner(b, 9)
			local st = UI.stroke(b, 3, WHITE, 1)
			b.Activated:Connect(function() UI.sound("Click") S.shape.color = col K.paintRefresh() end)
			paintSw[i] = { color = col, stroke = st }
		end
		local mats = UI.new("Frame", { Position = UDim2.fromOffset(14, 184), Size = UDim2.new(1, -28, 0, 140), BackgroundTransparency = 1, Parent = paintCard })
		local ml = Instance.new("UIGridLayout")
		ml.CellSize = UDim2.new(1 / 3, -6, 0, 30)
		ml.CellPadding = UDim2.fromOffset(6, 5)
		ml.Parent = mats
		for i, m in ipairs(Catalog.MATERIALS) do
			local b, set = chip(mats, m.name, 80, i, function()
				if m.research and not Research.has(HOTEL, m.research) then
					toast(m.name .. " needs Research: " .. Research.BY_ID[m.research].name, "research", true)
					return
				end
				S.shape.mat = m.id
				K.paintRefresh()
			end)
			b.TextSize = 14
			paintMat[i] = { mat = m, set = set, b = b }
		end
	end
	function K.paintRefresh()
		for _, s in ipairs(paintSw) do s.stroke.Transparency = s.color == S.shape.color and 0 or 1 end
		for _, m in ipairs(paintMat) do
			m.set(m.mat.id == S.shape.mat)
			local locked = m.mat.research and not Research.has(HOTEL, m.mat.research)
			m.b.TextTransparency = locked and 0.5 or 0
		end
	end
	K.paintRefresh()

	------------------------------------------------------------------ selection

	local selBoxes = {}
	local function sbox(m, col)
		local sb = Instance.new("SelectionBox")
		sb.Adornee = m
		sb.LineThickness = 0.07
		sb.Color3 = col
		sb.SurfaceColor3 = col
		sb.SurfaceTransparency = 0.86
		sb.Transparency = 0.05
		sb.Parent = kitFolder
		return sb
	end
	local refreshSelBar, refreshAdv -- forward

	local function syncSel()
		for i = #K.sel, 1, -1 do
			if not K.sel[i].Parent then K.selSet[K.sel[i]] = nil table.remove(K.sel, i) end
		end
		for m, sb in pairs(selBoxes) do
			if not K.selSet[m] then sb:Destroy() selBoxes[m] = nil end
		end
		for _, m in ipairs(K.sel) do
			if not selBoxes[m] then selBoxes[m] = sbox(m, T.sun) end
		end
		api.setSelected(K.sel[1])
		local p = #K.sel == 1 and K.sel[1]
		local it = p and p ~= api.desk and Catalog.ITEMS[p:GetAttribute("Item") or ""]
		if it and it.shape then api.ED.open("target", p) elseif api.ED.mode == "target" then api.ED.close() end
		refreshSelBar()
		refreshAdv()
	end
	function K.select(m, add)
		if not add then table.clear(K.sel) table.clear(K.selSet) end
		if m then
			if add and K.selSet[m] then
				K.selSet[m] = nil
				table.remove(K.sel, table.find(K.sel, m))
			else
				-- the reception desk is only ever picked on its own
				if m == api.desk or K.selSet[api.desk] then table.clear(K.sel) table.clear(K.selSet) end
				if #K.sel < 40 then
					table.insert(K.sel, m)
					K.selSet[m] = true
				end
			end
			UI.sound("Select")
		end
		syncSel()
	end
	function K.selectMany(list, add)
		if not add then table.clear(K.sel) table.clear(K.selSet) end
		for _, m in ipairs(list) do
			if not K.selSet[m] and m ~= api.desk and #K.sel < 40 then
				table.insert(K.sel, m)
				K.selSet[m] = true
			end
		end
		if #list > 0 then UI.sound("Select") end
		syncSel()
	end
	function K.clear()
		if #K.sel == 0 then return end
		table.clear(K.sel)
		table.clear(K.selSet)
		syncSel()
	end
	-- a shape the server rebuilt (resize) is a new model with the same uid
	function K.replace(old, new)
		if not K.selSet[old] then return end
		K.selSet[old] = nil
		K.selSet[new] = true
		K.sel[table.find(K.sel, old)] = new
		syncSel()
	end

	local function itemOf(m) return m == api.desk and "Desk" or m:GetAttribute("Item") end
	local function bookedRoom(m)
		local r = m ~= api.desk and m:GetAttribute("Room") and HOTEL.Rooms:FindFirstChild(m:GetAttribute("Room"))
		return r and r:GetAttribute("State") == "Booked"
	end
	local function sellValue(m)
		if m == api.desk then return 0 end
		return Catalog.sellValue(m:GetAttribute("Item"), m:GetAttribute("Size"))
	end
	local function heightOf(cf) return math.max(cf.Position.Y - Build.FY, 0) end

	------------------------------------------------------------------ the selection bar (bottom)

	local selWrap = api.wrapper("SelectBar", UDim2.fromOffset(900, 76), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
	selWrap.Visible = false
	local selBar = UI.new("Frame", {
		Name = "Bar", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 70), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = selWrap,
	})
	glass(selBar, 20)
	UI.pad(selBar, 12, 0, 10, 0)
	UI.list(selBar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local selInfo = UI.new("Frame", { Name = "Info", Size = UDim2.fromOffset(190, 54), BackgroundTransparency = 1, LayoutOrder = 0, Parent = selBar })
	local selTitle = txt(selInfo, "", 18, { FontFace = UI.F.black, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
	local selSub = txt(selInfo, "", 14, { FontFace = UI.F.bold, TextColor3 = MUTED, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, 0, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	local selBtns = {}
	K.act = {}
	local function selBtn(key, text, icon, kind, order, hotkey, w)
		local b = UI.button(selBar, {
			name = key, text = text, icon = icon, kind = kind, key = hotkey, textSize = 16, iconSize = 20,
			size = UDim2.fromOffset(w or (text and 104 or 50), 48), order = order, radius = 12,
			onClick = function() K.act[key]() end,
		})
		selBtns[key] = b
		return b
	end
	selBtn("move", "Move", ICON.move, "gold", 1, "M")
	selBtn("turn", "Turn", ICON.rotate, "ink", 2, "R")
	selBtn("copy", "Copy", ICON.copy, "ink", 3, "C")
	selBtn("same", "All alike", ICON.grid, "ink", 4, nil, 132)
	selBtn("paint", "Paint", ICON.paint, "violet", 5)
	selBtn("sell", "Sell", ICON.sell, "green", 6, "Del", 140)
	selBtn("close", nil, ICON.close, "ink", 7, "X")
	local sellArmed = 0

	local function setSell(text, kind)
		local l = selBtns.sell:FindFirstChild("Row") and selBtns.sell.Row:FindFirstChild("Label")
		if l then l.Text = text end
		UI.setKind(selBtns.sell, kind)
	end
	refreshSelBar = function()
		local n = #K.sel
		local show = n > 0 and S.building and not K.group
		if show ~= selWrap.Visible then
			selWrap.Visible = show
			if show then UI.open(selBar, { rise = 14, from = 0.85 }) end
			if api.layout then api.layout() end
		end
		if n == 0 then return end
		local total, appeal, shapes, desk, ids = 0, 0, 0, false, {}
		for _, m in ipairs(K.sel) do
			if m == api.desk then desk = true end
			local id = itemOf(m)
			local it = Catalog.ITEMS[id]
			ids[id] = true
			total += sellValue(m)
			appeal += it and it.appeal or 0
			if it and it.shape then shapes += 1 end
		end
		local kinds = 0
		for _ in pairs(ids) do kinds += 1 end
		local first = Catalog.ITEMS[itemOf(K.sel[1])]
		if desk then
			selTitle.Text = "Reception Desk"
			selSub.Text = "Part of the hotel: move or turn it"
		elseif n == 1 then
			local zone = K.sel[1]:GetAttribute("Zone") or "Lobby"
			selTitle.Text = first and first.name or "Item"
			selSub.Text = (zone == "Lobby" and "In the lobby" or ("In room " .. string.gsub(zone, "Room", ""))) .. (appeal > 0 and ("  +" .. appeal .. " appeal") or "")
		else
			selTitle.Text = n .. " things" .. (kinds == 1 and (" (" .. (first and first.name or "") .. ")") or "")
			selSub.Text = "Worth $" .. commas(total) .. (appeal > 0 and ("  +" .. appeal .. " appeal") or "")
		end
		selBtns.copy.Visible = not desk
		selBtns.same.Visible = not desk
		selBtns.paint.Visible = n == 1 and shapes == 1
		local core = n == 1 and not desk and K.sel[1]:GetAttribute("Core") ~= nil
		if os.clock() - sellArmed < 3 then
			setSell("Sure? $" .. commas(total), "red")
		elseif desk then
			setSell("Built in", "ghost")
		elseif core then
			setSell("Needed", "ghost")
		else
			setSell("Sell $" .. commas(total), "green")
		end
	end

	------------------------------------------------------------------ actions on the selection

	local busy = false
	local function call(...)
		if busy then return false, "Busy" end
		busy = true
		local r = table.pack(pcall(Remote.InvokeServer, Remote, ...))
		busy = false
		if not r[1] then return false, "Try again" end
		return table.unpack(r, 2, r.n)
	end

	-- the whole selection, minus the desk (groups)
	local function groupList()
		local out = {}
		for _, m in ipairs(K.sel) do if m ~= api.desk and m.Parent then table.insert(out, m) end end
		return out
	end

	local function copyOne(m)
		local id = itemOf(m)
		if not id or m == api.desk then return end
		if api.lockOf(id) then toast("Unlock it first", "research", true) return end
		local it = Catalog.ITEMS[id]
		if it and it.hidden then toast("That isn't sold any more", "close", true) return end
		if it and it.shape then
			local o = Build.optsOf(m)
			S.shape.size, S.shape.color, S.shape.mat, S.shape.ghost = o.size or S.shape.size, o.color or S.shape.color, o.mat or S.shape.mat, o.ghost or false
		end
		local yaw, dy = Build.yawOf(m:GetPivot()), heightOf(m:GetPivot())
		api.makeGhost(id)
		local g = api.ghost()
		if g then
			g.yaw = yaw
			g.dy = dy
		end
		UI.sound("Click")
	end

	function K.act.move()
		local list = groupList()
		if #K.sel == 1 then
			local m = K.sel[1]
			if bookedRoom(m) then toast("A guest is using this room", "guest", true) return end
			api.makeGhost(itemOf(m), m)
		elseif #list > 0 then
			K.groupBegin(false)
		end
	end
	function K.act.turn(dir)
		dir = dir or 1
		local step = S.yawStep * dir
		if #K.sel == 1 then
			local m = K.sel[1]
			local from = m:GetPivot()
			local p = from.Position
			local cf = Build.pivot(p.X, p.Y - Build.FY, p.Z, (Build.yawOf(from) + step) % 360)
			local ok, why
			if m == api.desk then ok, why = call("desk", cf) else ok, why = call("move", m:GetAttribute("Uid"), cf) end
			if ok then
				pushUndo({ move = (m ~= api.desk and m:GetAttribute("Uid")) or "desk", cf = from })
				local v = Instance.new("CFrameValue")
				v.Value = from
				v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
				UI.tween(v, 0.35, { Value = cf }, Enum.EasingStyle.Back).Completed:Connect(function() v:Destroy() end)
				UI.sound("Turn")
			else
				toast(why or "No room to turn it", "close", true)
			end
			return
		end
		-- a group turns round its middle
		local list = groupList()
		if #list == 0 then return end
		local c = Vector3.zero
		for _, m in ipairs(list) do c += m:GetPivot().Position end
		c /= #list
		local pivot = CFrame.new(c.X, Build.FY, c.Z)
		local rot = pivot * CFrame.Angles(0, math.rad(step), 0) * pivot:Inverse()
		local moves, back = {}, {}
		for _, m in ipairs(list) do
			local from = m:GetPivot()
			local to = rot * from
			table.insert(moves, { m:GetAttribute("Uid"), Build.pivot(to.Position.X, to.Position.Y - Build.FY, to.Position.Z, Build.yawOf(to)) })
			table.insert(back, { m:GetAttribute("Uid"), from })
		end
		local ok, done, why = call("moveMany", moves)
		if ok then
			pushUndo({ moves = back })
			UI.sound("Turn")
			if why then toast("Some didn't fit: " .. why, "close", true) end
		else
			toast(done or why or "No room to turn them", "close", true)
		end
	end
	function K.act.copy()
		if #K.sel == 1 then copyOne(K.sel[1]) elseif #K.sel > 1 then K.groupBegin(true) end
	end
	function K.act.same()
		local m = K.sel[1]
		if not m or m == api.desk then return end
		local id = m:GetAttribute("Item")
		local out = {}
		for _, o in ipairs(PLACED:GetChildren()) do
			if o:GetAttribute("Item") == id then table.insert(out, o) end
		end
		K.selectMany(out)
		toast(#K.sel .. " " .. string.lower(Catalog.ITEMS[id] and Catalog.ITEMS[id].name or id) .. (#K.sel == 1 and "" or "s") .. " selected", "copy")
	end
	function K.act.paint()
		local m = K.sel[1]
		if m and Catalog.ITEMS[itemOf(m)] and Catalog.ITEMS[itemOf(m)].shape then api.ED.open("target", m) end
	end
	function K.act.close() K.clear() end

	-- sell a list of models; Undo buys them back
	local function sellList(models)
		local uids, back, worth = {}, {}, 0
		for _, m in ipairs(models) do
			if m ~= api.desk and m.Parent and m:GetAttribute("Uid") then
				local id = m:GetAttribute("Item")
				local it = Catalog.ITEMS[id]
				table.insert(uids, m:GetAttribute("Uid"))
				back[m:GetAttribute("Uid")] = { id, m:GetPivot(), it and it.shape and Build.optsOf(m) or nil }
				worth += sellValue(m)
			end
		end
		if #uids == 0 then
			toast(#models == 1 and models[1] == api.desk and "The reception desk is part of the hotel" or "Nothing to sell", "close", true)
			return
		end
		local pos = models[1]:GetPivot().Position
		local ok, done, why = call("sellMany", uids)
		if ok then
			local rebuy = {}
			for _, uid in ipairs(done) do if back[uid] then table.insert(rebuy, back[uid]) end end
			pushUndo({ rebuy = rebuy })
			UI.sound("Sell", pos)
			if #done > 1 then toast("Sold " .. #done .. " things (Z puts them back)", "sell") end
			if why and #done < #uids then toast(why, "close", true) end
			K.clear()
		else
			toast(done or why or "Can't sell that", "close", true)
		end
	end
	function K.act.sell()
		if #K.sel == 0 then return end
		if K.sel[1] == api.desk then toast("The reception desk is part of the hotel", "close", true) return end
		if os.clock() - sellArmed > 3 then
			sellArmed = os.clock()
			refreshSelBar()
			UI.pop(selBtns.sell, 1.15)
			task.delay(3.05, refreshSelBar)
			return
		end
		sellArmed = 0
		sellList(table.clone(K.sel))
	end

	------------------------------------------------------------------ groups: move and copy many at once

	local groupModel = Instance.new("Model")
	groupModel.Name = "GroupGhost"
	groupModel.Parent = kitFolder
	local groupHL = UI.new("Highlight", { Name = "GroupHL", FillTransparency = 0.7, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Adornee = groupModel, Parent = kitFolder })
	local tipGui = UI.new("BillboardGui", { Name = "KitTip", Size = UDim2.fromOffset(320, 40), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = pgui })
	local tipFrame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(20, 28, 44), BackgroundTransparency = 0.06, Parent = tipGui })
	UI.corner(tipFrame, 12)
	local tipStroke = UI.stroke(tipFrame, 1.5, GOOD, 0.1)
	UI.pad(tipFrame, 14, 0, 14, 0)
	local tipText = UI.new("TextLabel", { Text = "", TextSize = 16, FontFace = UI.F.heavy, TextColor3 = WHITE, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Parent = tipFrame })
	local tipAnchor = Instance.new("Part")
	tipAnchor.Anchored = true; tipAnchor.CanCollide = false; tipAnchor.CanQuery = false; tipAnchor.CanTouch = false; tipAnchor.Transparency = 1
	tipAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	tipAnchor.Parent = kitFolder
	tipGui.Adornee = tipAnchor
	local function tip(text, col, at)
		if not text then tipGui.Enabled = false return end
		tipText.Text = text
		tipStroke.Color = col or GOOD
		tipText.TextColor3 = col == BAD and Color3.fromRGB(255, 190, 180) or Color3.fromRGB(210, 255, 220)
		tipAnchor.Position = at
		tipGui.Enabled = true
	end

	local function ghostify(m)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
				d.Transparency = math.max(d.Transparency, 0.25)
			elseif d:IsA("Light") then
				d.Enabled = false
			end
		end
		local messy = m:FindFirstChild("Messy")
		if messy then messy:Destroy() end
		return m
	end
	local function setHidden(m, on)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 1 or 0 end
		end
	end
	local function snap(v)
		if S.grid <= 0 then return math.floor(v * 20 + 0.5) / 20 end
		return math.floor(v / S.grid + 0.5) * S.grid
	end

	function K.groupBegin(copy, grabAt)
		local ms = groupList()
		if #ms == 0 then return end
		local cost = 0
		for _, m in ipairs(ms) do
			local id = m:GetAttribute("Item")
			if copy then
				if api.lockOf(id) then toast("Unlock the " .. string.lower(Catalog.ITEMS[id].name) .. " first", "research", true) return end
				if Catalog.ITEMS[id] and Catalog.ITEMS[id].hidden then toast("The " .. string.lower(Catalog.ITEMS[id].name) .. " isn't sold any more", "close", true) return end
				cost += Catalog.price(id, m:GetAttribute("Size"))
			elseif bookedRoom(m) then
				toast("A guest is using one of those rooms", "guest", true)
				return
			end
		end
		if copy and api.cash() < cost then toast("Copies cost $" .. commas(cost) .. ": not enough cash", "cash", true) return end
		K.cancelGroup()
		api.clearGhost()
		local c = Vector3.zero
		for _, m in ipairs(ms) do c += m:GetPivot().Position end
		c /= #ms
		local anchor = CFrame.new(snap(c.X), Build.FY, snap(c.Z))
		local G = { copy = copy, items = {}, yaw = 0, cost = cost, grab = grabAt ~= nil }
		for _, m in ipairs(ms) do
			local id = m:GetAttribute("Item")
			local it = Catalog.ITEMS[id]
			local opts = it and it.shape and Build.optsOf(m) or nil
			local gm = ghostify(Build.make(id, m:GetPivot(), opts))
			gm.Parent = groupModel
			if not copy then setHidden(m, true) end
			table.insert(G.items, { m = m, id = id, opts = opts, rel = anchor:ToObjectSpace(m:GetPivot()), ghost = gm })
		end
		if grabAt then G.off = Vector3.new(anchor.X - grabAt.X, 0, anchor.Z - grabAt.Z) end
		K.group = G
		groupHL.Enabled = true
		refreshSelBar()
		applyHints()
		UI.sound("Click")
	end
	function K.cancelGroup()
		local G = K.group
		if not G then return false end
		K.group = nil
		for _, it in ipairs(G.items) do
			it.ghost:Destroy()
			if not G.copy and it.m.Parent then setHidden(it.m, false) end
		end
		groupHL.Enabled = false
		tip(nil)
		refreshSelBar()
		applyHints()
		return true
	end
	local function groupStep()
		local G = K.group
		local p = api.floorPoint()
		if not p then return end
		if G.off then p += G.off end
		local base = CFrame.new(snap(p.X), Build.FY, snap(p.Z)) * CFrame.Angles(0, math.rad(G.yaw), 0)
		local set = nil
		if not G.copy then
			set = {}
			for _, it in ipairs(G.items) do set[it.m] = true end
		end
		local bad, why = 0, nil
		local top = -math.huge
		for _, it in ipairs(G.items) do
			local cf = base * it.rel
			cf = Build.pivot(cf.Position.X, cf.Position.Y - Build.FY, cf.Position.Z, Build.yawOf(cf))
			it.target = cf
			it.ghost:PivotTo(cf)
			if set then set.main = it.m end
			local ok, w = Build.validate(it.id, cf, set, it.opts)
			if not ok then bad += 1 why = why or w end
			top = math.max(top, cf.Position.Y)
		end
		G.ok, G.why = bad == 0, why
		local col = G.ok and GOOD or BAD
		groupHL.FillColor, groupHL.OutlineColor = col, col
		local label = G.ok and ((G.copy and ("Copy " .. #G.items .. " for $" .. commas(G.cost))) or ("Move " .. #G.items .. " here"))
			or (bad .. " won't fit: " .. (why or "in the way"))
		tip(label, col, base.Position + Vector3.new(0, top - Build.FY + 8, 0))
	end
	function K.groupCommit()
		local G = K.group
		if not G then return end
		if not G.ok then
			UI.pop(tipFrame, 1.2, 0.3)
			toast(G.why or "Some of them don't fit there", "close", true)
			return
		end
		if G.copy then
			local list = {}
			for _, it in ipairs(G.items) do table.insert(list, { it.id, it.target, it.opts }) end
			local ok, done, why = call("placeBatch", list)
			if ok then
				pushUndo({ uids = done })
				for _, it in ipairs(G.items) do K.placed(it.id) end
				UI.sound("Place")
				if why and #done < #list then toast(#done .. " of " .. #list .. " placed: " .. why, "close", true) end
				if shift() and api.cash() >= G.cost then return end -- Shift keeps the copies in hand
			else
				toast(done or why or "Couldn't copy those", "close", true)
				return
			end
		else
			local list, back = {}, {}
			for _, it in ipairs(G.items) do
				table.insert(list, { it.m:GetAttribute("Uid"), it.target })
				table.insert(back, { it.m:GetAttribute("Uid"), it.m:GetPivot() })
			end
			local ok, done, why = call("moveMany", list)
			if ok then
				pushUndo({ moves = back })
				UI.sound("Place")
				if why and #done < #list then toast(#done .. " of " .. #list .. " moved: " .. why, "close", true) end
			else
				toast(done or why or "Couldn't move those", "close", true)
			end
		end
		K.cancelGroup()
	end
	-- dragging one of a selected group drags them all
	function K.grab(m, at)
		if K.tool ~= "select" or #K.sel < 2 or not K.selSet[m] or m == api.desk then return false end
		K.groupBegin(false, at)
		return K.group ~= nil
	end
	function K.groupRelease()
		if K.group and K.group.grab then
			K.groupCommit()
			K.cancelGroup()
		end
	end
	function K.groupActive() return K.group ~= nil end

	------------------------------------------------------------------ box select and delete sweeps

	local marquee = UI.new("Frame", { Name = "Marquee", BackgroundColor3 = T.brand, BackgroundTransparency = 0.82, Visible = false, ZIndex = 20, Parent = api.gui })
	UI.stroke(marquee, 2, Color3.fromRGB(140, 180, 255), 0)
	local drag -- { kind = "box"|"sweep", from = Vector2, marked = { [m] = sb } }
	function K.dragBegin(from)
		if api.ghost() or K.group then return false end
		if K.tool == "box" then
			drag = { kind = "box", from = from }
			marquee.Visible = true
			return true
		elseif K.tool == "delete" then
			drag = { kind = "sweep", marked = {}, n = 0 }
			return true
		end
		return false
	end
	local function dragStep()
		if not drag then return end
		local p = UIS:GetMouseLocation()
		if drag.kind == "box" then
			local a, b = drag.from, p
			marquee.Position = UDim2.fromOffset(math.min(a.X, b.X), math.min(a.Y, b.Y))
			marquee.Size = UDim2.fromOffset(math.abs(a.X - b.X), math.abs(a.Y - b.Y))
		else
			local m = api.placedAt()
			if m and m ~= api.desk and not drag.marked[m] and drag.n < 40 then
				drag.marked[m] = sbox(m, BAD)
				drag.n += 1
				UI.sound("Tick")
			end
			tip(drag.n > 0 and ("Sell " .. drag.n .. ": let go") or nil, BAD, api.floorPoint() and (api.floorPoint() + Vector3.new(0, 6, 0)) or Vector3.zero)
		end
	end
	function K.dragEnd()
		local d = drag
		drag = nil
		marquee.Visible = false
		if not d then return end
		if d.kind == "box" then
			local a, b = d.from, UIS:GetMouseLocation()
			local x0, x1, y0, y1 = math.min(a.X, b.X), math.max(a.X, b.X), math.min(a.Y, b.Y), math.max(a.Y, b.Y)
			local out = {}
			if x1 - x0 > 4 and y1 - y0 > 4 then
				for _, m in ipairs(PLACED:GetChildren()) do
					local v, on = camera:WorldToViewportPoint(m:GetPivot().Position)
					if on and v.X >= x0 and v.X <= x1 and v.Y >= y0 and v.Y <= y1 then table.insert(out, m) end
				end
			end
			K.selectMany(out, shift())
			if #out > 0 then toast(#K.sel .. " selected", "copy") end
		else
			tip(nil)
			local list = {}
			for m, sb in pairs(d.marked) do
				sb:Destroy()
				if m.Parent then table.insert(list, m) end
			end
			if #list > 0 then sellList(list) end
		end
	end
	function K.dragging() return drag ~= nil end

	------------------------------------------------------------------ the placement panel (advanced placement)

	local advWrap = api.wrapper("Placement", UDim2.fromOffset(300, 500), UDim2.new(0, 120, 0.5, 0), Vector2.new(0, 0.5))
	advWrap.Visible = false
	local adv = UI.new("Frame", { Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = advWrap })
	glass(adv, 20)
	UI.pad(adv, 14, 12, 14, 14)
	UI.list(adv, nil, 8)
	S.advMin = false
	local advHead = UI.new("TextButton", { Name = "Head", Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 0, Parent = adv })
	txt(advHead, "PLACEMENT", 16, { FontFace = UI.F.black, Size = UDim2.new(1, -30, 1, 0) })
	local advArrow = UI.icon(advHead, ICON.down, 18, { Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
	UI.tooltip(advHead, "Show or hide the placement tools")
	local advBody = UI.new("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = adv })
	UI.list(advBody, nil, 8)
	advHead.Activated:Connect(function()
		S.advMin = not S.advMin
		advBody.Visible = not S.advMin
		advArrow.Rotation = S.advMin and 180 or 0
		UI.sound("Tick")
	end)

	-- exact numbers: X / Z (from the hotel's middle), height, angle
	local fields = {}
	local applyFields -- forward
	local fieldRow
	for r, pair in ipairs({ { { "x", "X" }, { "z", "Z" } }, { { "h", "Height" }, { "a", "Angle" } } }) do
		fieldRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = r, Parent = advBody })
		for i, f in ipairs(pair) do
			local cell = UI.new("Frame", { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0), BackgroundColor3 = Color3.fromRGB(14, 20, 32), Parent = fieldRow })
			UI.corner(cell, 10)
			local st = UI.stroke(cell, 1.5, Color3.fromRGB(74, 94, 128), 0)
			txt(cell, f[2], 14, { TextColor3 = MUTED, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 56, 1, 0) })
			local box = UI.new("TextBox", {
				Text = "0", TextSize = 17, FontFace = UI.F.heavy, TextColor3 = WHITE, BackgroundTransparency = 1, ClearTextOnFocus = false,
				TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0, 60, 0, 0), Size = UDim2.new(1, -70, 1, 0), Parent = cell,
			})
			box.Focused:Connect(function() st.Color = T.brand end)
			box.FocusLost:Connect(function(enter)
				st.Color = Color3.fromRGB(74, 94, 128)
				if enter then applyFields(f[1]) end
			end)
			fields[f[1]] = box
		end
	end

	-- the nudge pad: arrows move by one grid step (camera-relative), the round ones turn
	local function nudge(dx, dz) K.nudge(dx, dz) end
	do
		local pad = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1, LayoutOrder = 3, Parent = advBody })
		local function nb(icon, rot, x, y, fn, tipText)
			local b = UI.new("ImageButton", { Image = "", AutoButtonColor = false, Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(x, y), BackgroundColor3 = CHIP, Parent = pad })
			UI.corner(b, 10)
			UI.stroke(b, 1.5, Color3.fromRGB(80, 100, 136), 0.2)
			UI.icon(b, icon, 22, { Rotation = rot, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
			b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(58, 76, 108) end)
			b.MouseLeave:Connect(function() b.BackgroundColor3 = CHIP end)
			b.Activated:Connect(function() UI.sound("Tick") UI.pop(b, 0.85, 0.15) fn() end)
			UI.tooltip(b, tipText)
		end
		nb(ICON.up, 0, 46, 0, function() nudge(0, 1) end, "Nudge away (Up arrow)")
		nb(ICON.down, 0, 46, 46, function() nudge(0, -1) end, "Nudge closer (Down arrow)")
		nb(ICON.up, -90, 0, 46, function() nudge(-1, 0) end, "Nudge left (Left arrow)")
		nb(ICON.up, 90, 92, 46, function() nudge(1, 0) end, "Nudge right (Right arrow)")
		nb(ICON.rotate, 0, 160, 0, function() K.turn(-1) end, "Turn left (Shift+R)")
		nb(ICON.rotate, 180, 206, 0, function() K.turn(1) end, "Turn right (R)")
		nb(ICON.up, 0, 160, 46, function() K.raise(1) end, "Raise (T)")
		nb(ICON.down, 0, 206, 46, function() K.raise(-1) end, "Lower (G)")
	end

	-- steps
	local function stepRow(order, label, options, get, setv)
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = order, Parent = advBody })
		txt(row, label, 14, { TextColor3 = MUTED, Size = UDim2.new(1, 0, 0, 16) })
		local holder = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 18), BackgroundTransparency = 1, Parent = row })
		UI.list(holder, Enum.FillDirection.Horizontal, 4, nil, Enum.VerticalAlignment.Center)
		local sets = {}
		local function paint() for v, f in pairs(sets) do f(get() == v) end end
		local w = math.floor((272 - 4 * (#options - 1)) / #options)
		for i, o in ipairs(options) do
			local _, set = chip(holder, o[2], w, i, function() setv(o[1]) paint() end)
			sets[o[1]] = set
		end
		paint()
		return paint
	end
	stepRow(4, "GRID SNAP (STUDS)", { { 0, "Off" }, { 0.25, ".25" }, { 0.5, ".5" }, { 1, "1" }, { 2, "2" }, { 4, "4" } }, function() return S.grid end, function(v) S.grid = v end)
	stepRow(5, "TURN STEP (DEGREES)", { { 5, "5" }, { 15, "15" }, { 45, "45" }, { 90, "90" } }, function() return S.yawStep end, function(v) S.yawStep = v end)

	-- switches
	local lockSet
	do
		local grid = UI.new("Frame", { Name = "Switches", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 6, Parent = advBody })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.new(0.5, -3, 0, 34)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid
		local function sw(order, text, key, tipText, after)
			local set
			local _, s = chip(grid, text, 100, order, function()
				S[key] = not S[key]
				set(S[key])
				if after then after() end
				local g = api.ghost()
				if g and g.validate then api.reaim() end
			end, tipText)
			set = s
			set(S[key])
			return s
		end
		sw(1, "Wall snap", "wallSnap", "Walls and doors lock onto the ends of walls already there")
		sw(2, "Hug walls", "hug", "Furniture backs up flat against the nearest wall")
		sw(3, "Stack", "stack", "Put things on top of other things (tables, shelves)")
		sw(4, "Keep placing", "keep", "Keep the item in hand after you place it")
		lockSet = sw(5, "Lock spot", "lockSpot", "The item stays put: move it with the arrows and the numbers", function()
			local g = api.ghost()
			if g then g.locked = S.lockSpot or nil end
		end)
	end

	local function round(v, d) return math.floor(v * d + 0.5) / d end
	local function primaryCF()
		local g = api.ghost()
		if g and g.target then return g.target, g end
		if #K.sel == 1 and K.sel[1].Parent then return K.sel[1]:GetPivot(), nil end
		return nil
	end
	local function showFields()
		local cf = primaryCF()
		if not cf then return end
		local p = cf.Position
		local vals = { x = round(p.X - O.X, 100), z = round(p.Z - O.Z, 100), h = round(p.Y - Build.FY, 100), a = round(Build.yawOf(cf), 10) }
		for k, box in pairs(fields) do
			if not box:IsFocused() then box.Text = tostring(vals[k]) end
		end
	end
	-- move the selection to a spot (one item: a plain move; the desk has its own call)
	local function moveSelTo(cf)
		local m = K.sel[1]
		if not m then return end
		local from = m:GetPivot()
		local ok, why
		if m == api.desk then ok, why = call("desk", cf) else ok, why = call("move", m:GetAttribute("Uid"), cf) end
		if ok then
			pushUndo({ move = (m ~= api.desk and m:GetAttribute("Uid")) or "desk", cf = from })
			UI.sound("Place")
		else
			toast(why or "Can't go there", "close", true)
		end
	end
	applyFields = function()
		local cf, g = primaryCF()
		if not cf then return end
		local p = cf.Position
		local x = tonumber(fields.x.Text) or (p.X - O.X)
		local z = tonumber(fields.z.Text) or (p.Z - O.Z)
		local h = math.clamp(tonumber(fields.h.Text) or (p.Y - Build.FY), 0, Build.CEIL - Build.FY)
		local a = (tonumber(fields.a.Text) or Build.yawOf(cf)) % 360
		local id = g and g.id or itemOf(K.sel[1])
		if Build.floorOnly(id) or (g and g.moving == api.desk) or K.sel[1] == api.desk then h = 0 end
		local to = Build.pivot(O.X + x, h, O.Z + z, a)
		if g then
			S.lockSpot = true
			lockSet(true)
			g.locked = true
			g.yaw = a
			g.target = to
			g.validate()
		else
			moveSelTo(to)
		end
	end

	-- one grid step (or a fine 0.05 with Shift), along the camera's nearest axis
	local nudgeAcc
	function K.nudge(dx, dz)
		local step = shift() and 0.05 or (S.grid > 0 and S.grid or 0.25)
		local look = camera.CFrame.LookVector
		local fwd = math.abs(look.X) > math.abs(look.Z) and Vector3.new(math.sign(look.X), 0, 0) or Vector3.new(0, 0, math.sign(look.Z))
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local d = (right * dx + fwd * dz) * step
		local g = api.ghost()
		if g and g.target then
			S.lockSpot = true
			lockSet(true)
			g.locked = true
			g.target = g.target + d
			g.validate()
			return
		end
		local list = #K.sel == 1 and K.sel or groupList()
		if #list == 0 then return end
		-- move them on screen now, send once the keys settle
		nudgeAcc = nudgeAcc or { d = Vector3.zero, from = {}, n = 0 }
		nudgeAcc.d += d
		nudgeAcc.n += 1
		local n = nudgeAcc.n
		for _, m in ipairs(list) do
			if not nudgeAcc.from[m] then nudgeAcc.from[m] = m:GetPivot() end
			m:PivotTo(nudgeAcc.from[m] + nudgeAcc.d)
		end
		task.delay(0.35, function()
			if not nudgeAcc or nudgeAcc.n ~= n then return end
			local acc = nudgeAcc
			nudgeAcc = nil
			local moves, back = {}, {}
			for m, from in pairs(acc.from) do
				local to = from + acc.d
				if m == api.desk then
					local ok, why = call("desk", Build.pivot(to.Position.X, 0, to.Position.Z, Build.yawOf(to)))
					if ok then pushUndo({ move = "desk", cf = from }) else m:PivotTo(from) toast(why or "Can't go there", "close", true) end
					return
				end
				table.insert(moves, { m:GetAttribute("Uid"), Build.pivot(to.Position.X, to.Position.Y - Build.FY, to.Position.Z, Build.yawOf(to)) })
				table.insert(back, { m:GetAttribute("Uid"), from })
			end
			local ok, done, why = call("moveMany", moves)
			if ok then
				pushUndo({ moves = back })
				if why and #done < #moves then toast(why, "close", true) end
			else
				toast(done or why or "Can't go there", "close", true)
			end
			-- anything that didn't move snaps back
			for m, from in pairs(acc.from) do
				if m.Parent and (m:GetPivot().Position - (from.Position + acc.d)).Magnitude < 0.01 and not (ok and done) then m:PivotTo(from) end
			end
		end)
	end
	function K.turn(dir)
		if api.ghost() then api.turnGhost(dir) elseif K.group then K.group.yaw = (K.group.yaw + S.yawStep * dir) % 360 UI.sound("Turn") else K.act.turn(dir) end
	end
	function K.raise(dir)
		local g = api.ghost()
		if g then api.raiseGhost(dir) return end
		if #K.sel ~= 1 or K.sel[1] == api.desk then return end
		local m = K.sel[1]
		local cf = m:GetPivot()
		local step = S.grid > 0 and math.max(S.grid, 0.5) or 0.5
		local h = math.clamp(cf.Position.Y - Build.FY + dir * step, 0, Build.CEIL - Build.FY)
		moveSelTo(Build.pivot(cf.Position.X, h, cf.Position.Z, Build.yawOf(cf)))
	end

	refreshAdv = function()
		local g = api.ghost()
		local show = S.building and not S.roomMode and not K.group and K.tool ~= "paint" and ((g ~= nil) or #K.sel == 1)
		if show ~= advWrap.Visible then
			advWrap.Visible = show
			if show then UI.pop(adv, 0.92, 0.25) end
		end
		if lockSet then lockSet(g ~= nil and g.locked == true) end
		if show then showFields() end
	end
	K.refreshAdv = refreshAdv

	------------------------------------------------------------------ hugging walls (Placement > Hug walls)

	local hugParams = RaycastParams.new()
	hugParams.FilterType = Enum.RaycastFilterType.Include
	-- a model's back is its -Z side: it turns so its LookVector points into the wall, as wall items hang (aimGhost)
	function S.hugWall(id, cf)
		local list = {}
		for _, n in ipairs({ "Shell", "Rooms", "Doors" }) do
			local f = HOTEL:FindFirstChild(n)
			if f then table.insert(list, f) end
		end
		table.insert(list, PLACED)
		hugParams.FilterDescendantsInstances = list
		local off, size = Build.box(id)
		local p = cf.Position + Vector3.new(0, 2.5, 0)
		local reach = math.max(size.X, size.Z) / 2 + 2.5
		local best
		for k = 0, 3 do
			local dir = CFrame.Angles(0, math.rad(k * 90), 0).LookVector
			local r = workspace:Raycast(p, dir * reach, hugParams)
			if r and math.abs(r.Normal.Y) < 0.3 and r.Instance.Transparency < 0.9 then
				local owner = Build.placedOf(r.Instance)
				local it = owner and Catalog.ITEMS[owner:GetAttribute("Item") or ""]
				if (not owner or (it and it.structure)) and (not best or r.Distance < best.Distance) then best = r end
			end
		end
		if not best then return cf end
		local n = Vector3.new(best.Normal.X, 0, best.Normal.Z)
		if n.Magnitude < 0.5 then return cf end
		n = n.Unit
		local yaw = Build.yawOf(CFrame.lookAt(Vector3.zero, -n))
		local back = off.Position.Z - size.Z / 2 -- the back face, along the model's +Z
		local onWall = cf.Position - n * (cf.Position - best.Position):Dot(n)
		local pos = onWall + n * (0.05 - back)
		return Build.pivot(pos.X, cf.Position.Y - Build.FY, pos.Z, yaw)
	end

	------------------------------------------------------------------ tools

	local hoverHL = UI.new("Highlight", { Name = "KitHover", FillTransparency = 0.7, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = kitFolder })
	local function refreshTools()
		for id, r in pairs(railBtns) do
			r.set(id == "room" and S.roomMode or (id == K.tool and not S.roomMode), TOOL_COL[id])
		end
	end
	S.toolsRefresh = refreshTools
	function K.setTool(id)
		if id == "room" then
			if S.toggleRoom then S.toggleRoom() end
			refreshTools()
			return
		end
		if S.roomMode and S.closeBuilder then S.closeBuilder() end
		K.cancelGroup()
		if id ~= "select" and api.ghost() then api.clearGhost() end
		if id ~= "select" and id ~= "box" then K.clear() end
		K.tool = id
		hoverHL.Enabled = false
		tip(nil)
		paintWrap.Visible = id == "paint" and S.building
		if paintWrap.Visible then UI.pop(paintCard, 0.9, 0.25) K.toggleView(false) end
		refreshTools()
		refreshAdv()
		applyHints()
	end

	-- the cursor over a placed thing (nil: nothing). True when the tool drew its own hover.
	function K.hover(m)
		if K.tool == "select" or K.tool == "box" or drag then
			if hoverHL.Enabled then hoverHL.Enabled = false tip(nil) end
			return false
		end
		local col, label
		if m and m ~= api.desk then
			local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
			if K.tool == "delete" then
				col = BAD
				label = m:GetAttribute("Core") and "Needed by its room" or ("Sell $" .. commas(sellValue(m)))
			elseif K.tool == "paint" then
				col = it and it.shape and T.violet or nil
				label = it and it.shape and "Paint it" or nil
			elseif K.tool == "pick" then
				col = TEAL
				label = "Take another " .. string.lower(it and it.name or "one")
			end
		end
		hoverHL.Adornee = col and m or nil
		hoverHL.Enabled = col ~= nil
		if col then
			hoverHL.FillColor, hoverHL.OutlineColor = col, col
			local cf, size = m:GetBoundingBox()
			tip(label, col == BAD and BAD or GOOD, cf.Position + Vector3.new(0, size.Y / 2 + 1.8, 0))
		else
			tip(nil)
		end
		return true
	end

	-- a click in the world with nothing in hand. False: let BuildClient handle it (an item in hand).
	function K.worldClick(pos)
		if K.group then K.groupCommit() return true end
		if api.ghost() then return false end
		local m = api.placedAt(pos)
		if K.tool == "select" or K.tool == "box" then
			if m then
				if shift() or ctrl() then K.select(m, true)
				elseif #K.sel == 1 and K.sel[1] == m then K.clear()
				else K.select(m) end
			elseif not (shift() or ctrl()) then
				K.clear()
			end
		elseif K.tool == "delete" then
			if m then sellList({ m }) end
		elseif K.tool == "paint" then
			local it = m and Catalog.ITEMS[m:GetAttribute("Item") or ""]
			if not (it and it.shape) then
				if m then toast("Only blocks and shapes take paint", "paint", true) end
				return true
			end
			local o = Build.optsOf(m)
			local ok, why = call("paint", m:GetAttribute("Uid"), { color = S.shape.color, mat = S.shape.mat, ghost = o.ghost or false })
			if ok then UI.sound("Place", m:GetPivot().Position) else toast(why or "Can't paint that", "close", true) end
		elseif K.tool == "pick" then
			if m and m ~= api.desk then
				K.setTool("select")
				copyOne(m)
			end
		end
		return true
	end

	-- keys; true when the key was used here
	local TOOL_KEYS = {
		[Enum.KeyCode.One] = "select", [Enum.KeyCode.Two] = "box", [Enum.KeyCode.Three] = "delete",
		[Enum.KeyCode.Four] = "paint", [Enum.KeyCode.Five] = "pick", [Enum.KeyCode.Six] = "room", [Enum.KeyCode.V] = "select",
	}
	local ARROWS = { [Enum.KeyCode.Up] = { 0, 1 }, [Enum.KeyCode.Down] = { 0, -1 }, [Enum.KeyCode.Left] = { -1, 0 }, [Enum.KeyCode.Right] = { 1, 0 } }
	function K.key(kc)
		if TOOL_KEYS[kc] then K.setTool(TOOL_KEYS[kc]) return true end
		local g = api.ghost()
		if ARROWS[kc] and ((g and g.locked) or (not g and #K.sel > 0 and not K.group)) then
			nudge(ARROWS[kc][1], ARROWS[kc][2])
			return true
		end
		if K.group then
			if kc == Enum.KeyCode.R then K.turn(shift() and -1 or 1) return true end
			if kc == Enum.KeyCode.X or kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Backspace then K.cancelGroup() return true end
			return false
		end
		if g then return false end
		if kc == Enum.KeyCode.A and ctrl() then K.act.same() return true end
		if #K.sel == 0 then return false end
		if kc == Enum.KeyCode.R then K.act.turn(shift() and -1 or 1) return true end
		if kc == Enum.KeyCode.M then K.act.move() return true end
		if kc == Enum.KeyCode.C then K.act.copy() return true end
		if kc == Enum.KeyCode.Delete then K.act.sell() return true end
		if kc == Enum.KeyCode.T or kc == Enum.KeyCode.PageUp then K.raise(1) return true end
		if kc == Enum.KeyCode.G or kc == Enum.KeyCode.PageDown then K.raise(-1) return true end
		return false
	end
	-- right-click / X: drop what the kit is doing. True when it did something.
	function K.cancel()
		if drag then
			if drag.marked then for _, sb in pairs(drag.marked) do sb:Destroy() end end
			drag = nil
			marquee.Visible = false
			tip(nil)
			return true
		end
		return K.cancelGroup()
	end

	------------------------------------------------------------------ show / hide, layout, per frame

	K.blockers = { railWrap, selWrap, advWrap, paintWrap, viewWrap }
	function K.show(on)
		if on then
			railWrap.Visible = true
			rail.Position = UDim2.new(0, -120, 0.5, 0)
			UI.tween(rail, 0.45, { Position = UDim2.fromScale(0, 0.5) }, Enum.EasingStyle.Quint)
			paintWrap.Visible = K.tool == "paint"
			refreshTools()
			applyHints()
		else
			K.cancel()
			K.clear()
			railWrap.Visible = false
			viewWrap.Visible = false
			paintWrap.Visible = false
			advWrap.Visible = false
			selWrap.Visible = false
			hoverHL.Enabled = false
			tip(nil)
		end
	end
	function K.layout(vp, rightPx, cx, bottomY)
		local k = api.kOf(railWrap)
		local x = 16 + 96 * k
		advWrap.Position = UDim2.new(0, x, 0.5, 0)
		paintWrap.Position = UDim2.new(0, x, 0.5, 0)
		viewWrap.Position = UDim2.new(0, x, 1, -14)
		selWrap.Position = UDim2.new(0, cx, 1, bottomY)
	end
	function K.leftEdge() return 16 + 96 * api.kOf(railWrap) + 10 end

	local fieldClock = 0
	function K.step(dt)
		if K.group then groupStep() end
		dragStep()
		if #K.sel > 0 then
			local any = false
			for _, m in ipairs(K.sel) do if not m.Parent then any = true end end
			if any then syncSel() end
		end
		fieldClock += dt
		if fieldClock > 0.12 then
			fieldClock = 0
			refreshAdv()
		end
	end

	return K
end
