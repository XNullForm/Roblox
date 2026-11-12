-- StarterPlayerScripts.BuildClient: build mode (round 9 rewrite on Shared.UI). B (or the BUILD button) toggles it.
-- An orbit camera over the hotel; a shop drawer (categories, search, research locks, the next room);
-- a tool rail (grid snap, turn step, roof, zone overlay); a ghost that snaps to the grid, turns in any step,
-- stacks onto furniture, hangs on walls and rises or lowers; a card on placed things (move, turn, copy,
-- paint, sell); and a shape editor (size, colour, finish, walk-through). BuildServer re-checks everything.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Build = require(Shared:WaitForChild("Build"))
local Research = require(Shared:WaitForChild("Research"))
local Levels = require(Shared:WaitForChild("Levels"))
local UI = require(Shared:WaitForChild("UI"))
local Remote = Shared.Remotes:WaitForChild("Build")
local ITEMS = Shared:WaitForChild("Items")
local T = UI.T

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
-- the hotel you work in (player attribute Plot, set by Plots). Coop restarts this script when it changes.
local PLOTS = workspace:WaitForChild("Plots")
while not player:GetAttribute("Plot") do player:GetAttributeChangedSignal("Plot"):Wait() end
local HOTEL = PLOTS:WaitForChild(player:GetAttribute("Plot"))
local O = HOTEL:GetAttribute("Origin") or Vector3.zero
-- a restart leaves the last copy's bits behind
for _, n in ipairs({ "Build", "Hover", "Selected", "GhostTip", "GhostHL" }) do
	local old = pgui:FindFirstChild(n)
	if old then old:Destroy() end
end
for _, d in ipairs(pgui:GetChildren()) do
	if d.Name == "ZoneLabel" then d:Destroy() end
end
for _, n in ipairs({ "BuildLocal", "Ghost" }) do
	local old = workspace:FindFirstChild(n)
	if old then old:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("BuildCam") end)
local PLACED = HOTEL:WaitForChild("Placed")
local ZONES = HOTEL:WaitForChild("BuildZones")
-- the built-in reception desk (movable in build mode, unlike placed furniture)
local deskModel = HOTEL:WaitForChild("Lobby"):WaitForChild("Desk")

local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local GOOD = Color3.fromRGB(110, 235, 140)
local BAD = Color3.fromRGB(255, 96, 96)
local ICON = C.ICONS

local function toast(text, key, bad)
	UI.toast(text, key and ICON[key] or nil, bad and "bad" or nil)
end
local function cash() return player:GetAttribute("Cash") or 0 end
local commas = UI.commas

---------------------------------------------------------------- state

local S = {
	building = false,
	cat = "all",
	query = "",
	grid = 1, -- 0 = free
	yawStep = 90,
	roof = player:GetAttribute("RoofMode") or "auto",
	zones = true,
	busy = false,
	sellArmed = false,
	shape = { size = Catalog.SHAPE_DEFAULT, color = Catalog.SWATCHES[8], mat = "SmoothPlastic", ghost = false },
}
local ghost -- { id, model, yaw, dy, target, shown, ok, why, moving, spin, opts }
local selected -- placed model (or the desk) with the card open
local hovered

local function itemPrice(id, opts)
	return Catalog.price(id, opts and opts.size)
end

-- nil when the item can be bought, else "level" (the hotel level is too low) or "research"
local function lockOf(id)
	local it = Catalog.ITEMS[id]
	if not Levels.itemOk(HOTEL, id) then return "level" end
	if it and it.research and not Research.has(HOTEL, it.research) then return "research" end
	return nil
end
local function unlocked(id) return lockOf(id) == nil end

---------------------------------------------------------------- gui root

local gui = UI.new("ScreenGui", {
	Name = "Build", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
	ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, Parent = pgui,
})

-- each piece sits in a wrapper that carries the screen scale (one UIScale per object: the wrapper's
-- AutoScale; the piece inside keeps its own PopScale for the open/pop motion)
local function wrapper(name, size, pos, anchor)
	local w = UI.new("Frame", { Name = name, Size = size, Position = pos, AnchorPoint = anchor, BackgroundTransparency = 1, Parent = gui })
	UI.autoScale(w)
	return w
end
local function kOf(w) return w.AutoScale.Scale end

---------------------------------------------------------------- the bottom bar: build + the menu buttons

-- round 15c: big borderless buttons — icon only, keycaps with a real cap-on-skirt look,
-- each cap tilted a hair like stickers on a well-used board, and the row bounces in on arrival
local btnWrap = wrapper("BuildButton", UDim2.fromOffset(840, 140), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
local toggle -- forward
local bindPad -- forward (the controller block)
local barRow = UI.new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = btnWrap })
UI.list(barRow, Enum.FillDirection.Horizontal, 18, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

local capN = 0

-- round 18: rendered icons — the little 3D models in Shared.IconModels, shown live in a viewport
-- like the shop's item thumbnails, so they match the hammer's rendered look
local function micon(parent, name, px)
	local vf = UI.new("ViewportFrame", {
		Name = "MIcon", Size = UDim2.fromOffset(px, px), BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 170), LightColor = Color3.fromRGB(255, 244, 226),
		LightDirection = Vector3.new(-1, -2, -1.4), Parent = parent,
	})
	local src = Shared:FindFirstChild("IconModels") and Shared.IconModels:FindFirstChild(name)
	if src then
		local m = src:Clone()
		m.Parent = vf
		local cf, size = m:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local r = size.Magnitude / 2
		local dir = Vector3.new(0.75, 0.62, 1).Unit
		cam.CFrame = CFrame.lookAt(cf.Position + dir * (r / math.tan(math.rad(15)) * 0.92), cf.Position)
		cam.Parent = vf
		vf.CurrentCamera = cam
	end
	return vf
end

-- one button: a flat icon, a white keycap with a black letter riding its top-left corner, and a label underneath
local function barButton(spec, key, label, onClick)
	capN += 1
	local b = UI.new("TextButton", { Name = "Btn_" .. (key or label), Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(104, 124), BackgroundTransparency = 1, Parent = barRow })
	-- round 14: a chunky tile in the button's own colour (walnut rim, solid shadow, a glossy lip), the icon
	-- popping out over its top edge and a walnut name plate across its foot
	local col = spec.color or T.gold
	local tileSh = UI.new("Frame", { Name = "TileShadow", Size = UDim2.fromOffset(88, 84), Position = UDim2.new(0.5, 0, 0, 38), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.shadow, BackgroundTransparency = 0.45, ZIndex = 0, Parent = b })
	UI.corner(tileSh, 20)
	local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(88, 84), Position = UDim2.new(0.5, 0, 0, 32), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = b })
	UI.corner(tile, 20)
	UI.grad(tile, col:Lerp(Color3.new(1, 1, 1), 0.35), col, 90)
	UI.stroke(tile, 3, T.outline, 0)
	local lip = UI.new("Frame", { Size = UDim2.new(1, -22, 0, 6), Position = UDim2.fromOffset(11, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.4, ZIndex = 1, Parent = tile })
	UI.corner(lip, 3)
	-- a soft burst behind the icon
	local glow = UI.new("Frame", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, ZIndex = 1, Parent = tile })
	UI.corner(glow, UDim.new(0.5, 0))
	local ic
	if spec.img then
		ic = UI.icon(b, spec.img, 92, { Name = "Icon", Position = UDim2.new(0.5, 0, 0, 58), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
	elseif spec.model then
		ic = micon(b, spec.model, 84)
		ic.Position = UDim2.new(0.5, 0, 0.42, 0)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	-- the name plate across the tile's foot
	local plate = UI.new("Frame", { Name = "Plate", Size = UDim2.fromOffset(96, 26), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Color3.fromRGB(92, 60, 40), ZIndex = 4, Parent = b })
	UI.corner(plate, 9)
	UI.stroke(plate, 2.5, T.outline, 0)
	UI.grad(plate, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 180, 172), 90)
	local lab = UI.label(plate, string.upper(label), 15, {
		Name = "Label", FontFace = UI.F.black, TextColor3 = T.white, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), ZIndex = 5,
	})
	UI.wordRim(lab, 2)
	-- a clean white keycap with a black letter, pinned to the icon's top-left corner
	local cap, face, k
	if key then
		cap = UI.new("Frame", {
			Name = "Cap", Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 0, 0, 22),
			BackgroundTransparency = 1, ZIndex = 5, Parent = b,
		})
		local skirt = UI.new("Frame", {
			Name = "Skirt", Size = UDim2.new(1, 0, 1, 3), Position = UDim2.fromOffset(0, 1),
			BackgroundColor3 = Color3.fromRGB(196, 200, 214), ZIndex = 5, Parent = cap,
		})
		UI.corner(skirt, 8)
		face = UI.new("Frame", {
			Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 6, Parent = cap,
		})
		UI.corner(face, 8)
		k = UI.label(face, key, 16, {
			Name = "Legend", FontFace = UI.F.heavy, TextColor3 = Color3.fromRGB(24, 26, 38),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
		})
		-- the controller's button while a controller is in use (hidden if it has none)
		local function showKey(isPadNow)
			local pk = UI.PAD_KEYS[key]
			k.Text = isPadNow and (pk or "") or key
			cap.Visible = not (isPadNow and not pk)
		end
		showKey(UI.gamepad())
		UI.PadChanged.Event:Connect(showKey)
	end
	-- the cap sinks like a real key when poked; the icon leans in with it
	local sc = UI.scaleOf(b)
	b.MouseEnter:Connect(function()
		UI.tween(sc, 0.18, { Scale = 1.12 }, Enum.EasingStyle.Back)
		if face then UI.tween(face, 0.1, { Position = UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Quad) end
		UI.tween(ic, 0.18, { Rotation = -6 })
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		UI.tween(sc, 0.22, { Scale = 1 }, Enum.EasingStyle.Quint)
		if face then UI.tween(face, 0.16, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back) end
		UI.tween(ic, 0.2, { Rotation = 0 })
	end)
	if onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			UI.pop(b, 0.9, 0.3)
			-- a real key click: the face bottoms out and comes back up
			if face then
				UI.tween(face, 0.06, { Position = UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Quad)
			task.delay(0.08, function() UI.tween(face, 0.22, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back) end)
			end
			onClick()
		end)
	end
	-- arrival: the row bounces in one key at a time
	sc.Scale = 0
	UI.tween(sc, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.06 * (capN - 1))
	return b, ic
end

local function openMenu(tab) player:SetAttribute("MenuWant", tab) end

local buildBtn, buildIcon = barButton({ img = ICON.hammer, color = Color3.fromRGB(240, 108, 84) }, "B", "Build", function() toggle() end)
local menuBtns = {}
-- round 14: Blender-rendered icons in the hammer's style (icon_bar14.py)
for _, m in ipairs({
	{ { img = "rbxassetid://77567187013170", color = Color3.fromRGB(86, 170, 232) }, "M", "Hotel", "hotel" },
	{ { img = "rbxassetid://112752899117499", color = Color3.fromRGB(250, 190, 64) }, "T", "Staff", "staff" },
	{ { img = "rbxassetid://111953023418308", color = Color3.fromRGB(122, 200, 92) }, "R", "Research", "research" },
	{ { img = "rbxassetid://72065626098144", color = Color3.fromRGB(176, 120, 222) }, "Y", "Awards", "achievements" },
	{ { img = "rbxassetid://95707331138329", color = Color3.fromRGB(150, 160, 178) }, nil, "Settings", "settings" },
}) do
	menuBtns[#menuBtns + 1] = barButton(m[1], m[2], m[3], function() openMenu(m[4]) end)
end

local function setBuildButton(on)
	buildIcon.Image = on and ICON.checkmark or ICON.hammer
	UI.pop(buildBtn, 0.94, 0.3)
end

---------------------------------------------------------------- key hints (top centre)

local hintWrap = wrapper("Hints", UDim2.fromOffset(900, 34), UDim2.new(0.5, 0, 0, 18), Vector2.new(0.5, 0))
hintWrap.Visible = false
local hintRow = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hintWrap })
UI.list(hintRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local function setHints(list)
	for _, c in ipairs(hintRow:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, h in ipairs(list) do
		local chip = UI.new("Frame", {
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 30), BackgroundColor3 = T.ink,
			BackgroundTransparency = 0.18, LayoutOrder = i, Parent = hintRow,
		})
		UI.corner(chip, 9)
		UI.pad(chip, 6, 0, 10, 0)
		UI.list(chip, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
		if h[1] ~= "" then
			local k = UI.new("TextLabel", {
				Text = h[1], TextSize = 13, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(40, 28, 10),
				BackgroundColor3 = T.gold, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), Parent = chip,
			})
			UI.corner(k, 6)
			UI.pad(k, 6, 0, 6, 0)
		end
		UI.new("TextLabel", {
			Text = h[2], TextSize = 14, FontFace = UI.F.bold, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = chip,
		})
	end
end
local HINTS_IDLE = TOUCH and { { "", "Drag to move around" }, { "", "Pinch to zoom, twist to turn" }, { "", "Tap something to edit it" } }
	or { { "WASD", "Move" }, { "Q E", "Orbit" }, { "Right drag", "Turn" }, { "Scroll", "Zoom" }, { "Click", "Edit an item" }, { "B", "Done" } }
local HINTS_GHOST = TOUCH and { { "", "Tap the floor to aim" }, { "", "Use the buttons to turn and place" } }
	or { { "Click", "Place" }, { "Drag", "Place a row" }, { "R", "Turn" }, { "T G", "Raise / lower" }, { "Shift", "Keep placing" }, { "X", "Cancel" } }
local HINTS_ROOM = { { "Drag", "Draw the room" }, { "R", "Move the door" }, { "F", "Room mode off" }, { "X", "Cancel" } }
-- a controller (round 10c): the screen's centre is the cursor
local PAD_IDLE = { { "LS", "Move" }, { "RS", "Look" }, { "LT RT", "Zoom" }, { "A", "Edit an item" }, { "Y", "Browse items" }, { "B", "Done" } }
local PAD_GHOST = { { "A", "Place" }, { "X", "Turn" }, { "LB RB", "Raise / lower" }, { "Y", "Browse items" }, { "B", "Cancel" } }
local function hintsFor(set)
	if UI.gamepad() then return set == HINTS_GHOST and PAD_GHOST or PAD_IDLE end
	return set
end

---------------------------------------------------------------- the shop drawer

local shopWrap = wrapper("Shop", UDim2.fromOffset(1100, 250), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
shopWrap.Visible = false
local shopHolder, shopBody = UI.panel(shopWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { name = "Drawer", radius = 20 })
shopHolder.AnchorPoint = Vector2.new(0.5, 0.5)

local refreshCards -- forward
local catTabs = {}
for _, c in ipairs(Catalog.CATS) do
	table.insert(catTabs, { id = c.id, text = c.name, icon = ICON[c.icon] })
end
local tabsApi = UI.tabs(shopBody, catTabs, function(id)
	S.cat = id
	refreshCards(true)
end, { pos = UDim2.fromOffset(12, 8), size = UDim2.new(1, -240, 0, 44), textSize = 16, gap = 0, scroll = true })

-- search box
local searchBox = UI.new("Frame", {
	Name = "Search", Size = UDim2.fromOffset(200, 36), Position = UDim2.new(1, -16, 0, 12), AnchorPoint = Vector2.new(1, 0),
	BackgroundColor3 = T.ink2, Parent = shopBody,
})
UI.corner(searchBox, 10)
local searchStroke = UI.stroke(searchBox, 1.5, T.line, 0.3)
UI.icon(searchBox, ICON.search, 22, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
local searchInput = UI.new("TextBox", {
	Text = "", PlaceholderText = "Search", PlaceholderColor3 = T.muted, TextSize = 16, FontFace = UI.F.bold,
	TextColor3 = T.cream, BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -42, 1, 0), Position = UDim2.fromOffset(36, 0), Parent = searchBox,
})
searchInput.Focused:Connect(function() UI.tween(searchStroke, 0.2, { Color = T.gold, Transparency = 0 }) end)
searchInput.FocusLost:Connect(function() UI.tween(searchStroke, 0.2, { Color = T.line, Transparency = 0.3 }) end)
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
	S.query = string.lower(searchInput.Text)
	if S.query ~= "" and S.cat ~= "all" then tabsApi.select("all", true) S.cat = "all" end
	refreshCards(true)
end)

-- cash readout
local cashPill = UI.new("Frame", {
	Size = UDim2.fromOffset(170, 40), Position = UDim2.new(0, 24, 0, -8), AnchorPoint = Vector2.new(0, 1),
	BackgroundColor3 = T.ink, Parent = shopHolder,
})
UI.corner(cashPill, 12)
UI.stroke(cashPill, 1.5, T.gold, 0.4)
UI.icon(cashPill, ICON.cash, 30, { Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
local cashText = UI.label(cashPill, "$0", 19, {
	FontFace = UI.F.black, TextColor3 = T.green, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -46, 1, 0),
})

local list = UI.new("ScrollingFrame", {
	Name = "Items", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 1, -68),
	ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
	ScrollBarThickness = 5, ScrollBarImageColor3 = T.gold, ScrollBarImageTransparency = 0.4,
	ElasticBehavior = Enum.ElasticBehavior.Always, Parent = shopBody,
})
UI.list(list, Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center)
UI.pad(list, 6, 0, 6, 6)
local emptyNote = UI.label(shopBody, "Nothing matches that search", 18, {
	TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 120), Visible = false,
})

-- a 3D thumbnail of an item
local function thumb(parent, id)
	local vf = UI.new("ViewportFrame", {
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 150, 170), LightColor = Color3.fromRGB(255, 244, 226),
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

local function makeCard(id, order)
	local item = Catalog.ITEMS[id]
	local b = UI.new("TextButton", { Name = id, Text = "", Size = UDim2.fromOffset(138, 166), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	local f = UI.new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink2, Parent = b })
	UI.corner(f, 14)
	local st = UI.stroke(f, 1.5, T.line, 0.35)
	-- a soft spotlight behind the thumbnail
	local well = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 96), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = T.ink3, Parent = f })
	UI.corner(well, 11)
	local wg = UI.grad(well, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 156, 190), 90)
	wg.Transparency = NumberSequence.new(0.55, 0.85)
	local vf = thumb(well, id)
	vf.Size = UDim2.fromScale(1, 1)
	local name = UI.label(f, item.name, 15, {
		FontFace = UI.F.heavy, Position = UDim2.fromOffset(10, 106), Size = UDim2.new(1, -20, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local price = UI.label(f, "", 17, { FontFace = UI.F.black, TextColor3 = T.green, Position = UDim2.fromOffset(10, 132), Size = UDim2.new(0.6, 0, 0, 22) })
	local chip = UI.new("Frame", {
		Size = UDim2.fromOffset(52, 22), Position = UDim2.new(1, -10, 0, 133), AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = T.ink, Parent = f,
	})
	UI.corner(chip, 11)
	UI.icon(chip, ICON.star, 18, { Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	UI.label(chip, "+" .. (item.shape and Build.SHAPE_APPEAL or item.appeal or 0), 13, {
		FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -24, 1, 0),
	})
	-- tags in the corner: where it goes
	local tagText = item.wall and "WALL" or item.room and "ROOMS" or item.shape and "CUSTOM" or nil
	if tagText then
		local tag = UI.new("TextLabel", {
			Text = tagText, TextSize = 11, FontFace = UI.F.black, TextColor3 = T.ink, BackgroundColor3 = item.shape and T.violet or T.blue,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 16), Position = UDim2.fromOffset(10, 10), ZIndex = 3, Parent = f,
		})
		UI.corner(tag, 5)
		UI.pad(tag, 5, 0, 5, 0)
	end
	-- research lock
	local lockF = UI.new("Frame", { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 0.28, ZIndex = 5, Visible = false, Parent = f })
	UI.corner(lockF, 14)
	UI.icon(lockF, ICON.lock, 40, { Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 6 })
	local lockHead = UI.label(lockF, "RESEARCH", 12, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 78), ZIndex = 6 })
	local lockName = UI.label(lockF, "", 14, {
		FontFace = UI.F.heavy, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 36),
		TextWrapped = true, ZIndex = 6,
	})
	-- round 10: a level lock comes first, then research
	local function lockText()
		if lockOf(id) == "level" then
			lockHead.Text = "HOTEL LEVEL " .. Levels.itemLevel(id)
			lockName.Text = "Level up to unlock"
		elseif item.research then
			lockHead.Text = "RESEARCH"
			lockName.Text = Research.BY_ID[item.research].name
		end
	end
	lockText()
	local hover = false
	b.MouseEnter:Connect(function()
		hover = true
		UI.tween(f, 0.22, { Position = UDim2.fromOffset(0, -6), BackgroundColor3 = T.ink3 }, Enum.EasingStyle.Back)
		UI.tween(st, 0.2, { Color = T.gold, Transparency = 0 })
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		hover = false
		UI.tween(f, 0.25, { Position = UDim2.new(), BackgroundColor3 = T.ink2 })
		local c = cards[id]
		UI.tween(st, 0.2, { Color = c and c.sel and T.gold or T.line, Transparency = c and c.sel and 0 or 0.35 })
	end)
	b.MouseButton1Down:Connect(function() UI.pop(f, 0.94, 0.25) end)
	b.Activated:Connect(function()
		local lock = lockOf(id)
		if lock == "level" then
			UI.shake(f)
			toast("The " .. string.lower(item.name) .. " unlocks at hotel level " .. Levels.itemLevel(id), "star", true)
			return
		elseif lock then
			UI.shake(f)
			toast("Unlock the " .. string.lower(item.name) .. " in Research: " .. Research.BY_ID[item.research].name, "research", true)
			player:SetAttribute("OpenResearch", item.research)
			return
		end
		if cash() < itemPrice(id, item.shape and S.shape) then
			UI.shake(f)
			toast("Not enough cash for the " .. string.lower(item.name), "cash", true)
			return
		end
		UI.sound("Click")
		startPlacing(id)
	end)
	cards[id] = { button = b, card = f, stroke = st, price = price, lock = lockF, lockText = lockText, hover = function() return hover end, order = order }
end

for i, id in ipairs(Catalog.ORDER) do
	local item = Catalog.ITEMS[id]
	if item and (item.shape or ITEMS:FindFirstChild(id)) and item.cat then
		makeCard(id, i)
	end
end

-- the next room for sale: the first card in All and Rooms (click twice to buy)
local buyRoom -- forward
local room = { armed = 0 }
do
	local b = UI.new("TextButton", { Name = "RoomCard", Text = "", Size = UDim2.fromOffset(190, 166), BackgroundTransparency = 1, LayoutOrder = -100, Parent = list })
	local f = UI.new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b })
	UI.corner(f, 14)
	local g = UI.grad(f, T.gold, T.goldDk, 90)
	local st = UI.stroke(f, 2, Color3.fromRGB(255, 236, 190), 0.3)
	UI.icon(f, ICON.hammer, 86, { Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0) })
	local newTag = UI.new("TextLabel", {
		Text = "MORE LAND", TextSize = 11, FontFace = UI.F.black, TextColor3 = T.cream, BackgroundColor3 = T.redDk,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 18), Position = UDim2.fromOffset(10, 10), Rotation = -4, Parent = f,
	})
	UI.corner(newTag, 6)
	UI.pad(newTag, 6, 0, 6, 0)
	local title = UI.label(f, "Land plot", 18, {
		FontFace = UI.F.black, TextColor3 = Color3.fromRGB(40, 28, 10), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 94),
	})
	local pill = UI.new("Frame", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 1, -40), BackgroundColor3 = T.ink, Parent = f })
	UI.corner(pill, 10)
	local price = UI.label(pill, "$400", 17, { FontFace = UI.F.black, TextColor3 = T.green, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0) })
	local note = UI.label(pill, "+26 x 60", 13, {
		FontFace = UI.F.heavy, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -10, 1, 0),
	})
	room.button, room.card, room.title, room.price, room.note, room.grad, room.stroke = b, f, title, price, note, g, st
	b.MouseEnter:Connect(function() UI.tween(f, 0.22, { Position = UDim2.fromOffset(0, -6) }, Enum.EasingStyle.Back) UI.sound("Hover") end)
	b.MouseLeave:Connect(function() UI.tween(f, 0.25, { Position = UDim2.new() }) end)
	b.Activated:Connect(function()
		local id = HOTEL:GetAttribute("NextRoom")
		if not id then return end
		if Levels.of(HOTEL) < Levels.roomLevel(id) then
			UI.shake(f)
			toast("More land unlocks at hotel level " .. Levels.roomLevel(id), "star", true)
			return
		end
		if cash() < (HOTEL:GetAttribute("NextRoomPrice") or 0) then
			UI.shake(f)
			toast("Not enough cash for more land", "cash", true)
			return
		end
		UI.pop(f, 0.9)
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
	room.title.Text = armed and "Click again to buy" or "Land plot"
	room.price.Text = locked and ("Level " .. need) or ("$" .. commas(price))
	room.price.TextColor3 = locked and T.gold or (cash() >= price and T.green or T.red)
	room.grad.Color = armed and ColorSequence.new(T.green, T.greenDk) or ColorSequence.new(T.gold, T.goldDk)
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
		if vis then shown += 1 end
		local p = itemPrice(id, item.shape and S.shape)
		c.price.Text = "$" .. commas(p)
		local open = unlocked(id)
		-- round 10e: what you can use comes first, locked items after (catalogue order inside each group)
		c.button.LayoutOrder = (open and 0 or 1000) + (c.order or 0)
		c.lock.Visible = not open
		if not open then c.lockText() end
		c.price.TextColor3 = money >= p and T.green or T.red
		c.sel = ghost and not ghost.moving and ghost.id == id
		if not c.hover() then
			c.stroke.Color = c.sel and T.gold or T.line
			c.stroke.Transparency = c.sel and 0 or 0.35
		end
	end
	room.refresh()
	emptyNote.Visible = shown == 0
	if arrive then
		list.CanvasPosition = Vector2.zero
		UI.stagger(list, 0.018)
	end
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

-- the mouse wheel scrolls the drawer sideways
list.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		local maxX = math.max(list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X, 0)
		local x = math.clamp(list.CanvasPosition.X - input.Position.Z * 160, 0, maxX)
		UI.tween(list, 0.25, { CanvasPosition = Vector2.new(x, 0) })
	end
end)

---------------------------------------------------------------- tool rail (left)

local toolWrap = wrapper("Tools", UDim2.fromOffset(250, 470), UDim2.new(0, 18, 0.46, 0), Vector2.new(0, 0.5))
toolWrap.Visible = false
local toolHolder, toolBody = UI.panel(toolWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { name = "Rail", radius = 18 })
UI.pad(toolBody, 16, 14, 16, 14)
UI.list(toolBody, nil, 8)
local function railTitle(text, iconKey, order)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order, Parent = toolBody })
	UI.icon(row, ICON[iconKey], 20, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	UI.label(row, text, 14, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0) })
end
railTitle("GRID SNAP", "grid", 1)
local gridSeg, gridApi = UI.segmented(toolBody, {
	{ id = 0, text = "Off" }, { id = 0.5, text = "0.5" }, { id = 1, text = "1" }, { id = 2, text = "2" }, { id = 4, text = "4" },
}, S.grid, function(v) S.grid = v end, { order = 2 })
railTitle("TURN STEP", "rotate", 3)
local _, yawApi = UI.segmented(toolBody, {
	{ id = 90, text = "90" }, { id = 45, text = "45" }, { id = 15, text = "15" },
}, S.yawStep, function(v) S.yawStep = v end, { order = 4 })
railTitle("ROOF", "roof", 5)
local _, roofApi = UI.segmented(toolBody, {
	{ id = "auto", text = "Auto" }, { id = "show", text = "Show" }, { id = "hide", text = "Hide" },
}, S.roof, function(v)
	S.roof = v
	player:SetAttribute("RoofMode", v)
end, { order = 6 })
do
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 7, Parent = toolBody })
	UI.icon(row, ICON.place, 20, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	UI.label(row, "ROOM ZONES", 14, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -90, 1, 0) })
	S.setZones = select(2, UI.toggle(row, S.zones, function(on)
		S.zones = on
		S.applyZones()
	end, { pos = UDim2.new(1, 0, 0.5, 0), anchor = Vector2.new(1, 0.5) }))
end
-- round 10e: more tools. Wall snap (walls lock onto wall ends), keep placing (the ghost stays after you
-- place, like holding Shift; walls always do) and undo (takes back what you just placed for the full price)
S.wallSnap = true
S.keep = false
local function railToggle(text, iconKey, order, on, cb)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Parent = toolBody })
	UI.icon(row, ICON[iconKey], 20, { Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	UI.label(row, text, 14, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -90, 1, 0) })
	UI.toggle(row, on, cb, { pos = UDim2.new(1, 0, 0.5, 0), anchor = Vector2.new(1, 0.5) })
end
railToggle("WALL SNAP", "door", 8, true, function(on) S.wallSnap = on end)
railToggle("KEEP PLACING", "copy", 9, false, function(on) S.keep = on end)
S.undo = {} -- uids you placed, newest last
local undoRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 10, Parent = toolBody })
local undoBtn = UI.button(undoRow, {
	name = "Undo", text = "Undo", icon = ICON.rotate, iconSize = 20, kind = "ink", textSize = 16, key = "Z",
	size = UDim2.new(1, -8, 0, 38), pos = UDim2.fromOffset(0, 10), radius = 12, onClick = function() S.doUndo() end,
})
local railNote = UI.label(toolBody, TOUCH and "Tap a room's floor to aim. Shapes stack on anything." or "Hover furniture to stack on it. Walls lock onto wall ends.", 13, {
	FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 11,
})

---------------------------------------------------------------- place bar (bottom centre, over the drawer)

local barWrap = wrapper("PlaceBar", UDim2.fromOffset(640, 66), UDim2.new(0.5, 0, 1, -280), Vector2.new(0.5, 1))
barWrap.Visible = false
local bar = UI.new("Frame", { Name = "Bar", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = barWrap })
UI.list(bar, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local commit, turnGhost, raiseGhost, clearGhost -- forward
local heightPill = UI.new("Frame", { Size = UDim2.fromOffset(104, 52), BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, LayoutOrder = 0, Parent = bar })
UI.corner(heightPill, 14)
UI.stroke(heightPill, 1.5, T.line, 0.3)
UI.label(heightPill, "HEIGHT", 11, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 13) })
local heightText = UI.label(heightPill, "0.0", 20, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 20) })
local barBtns = {}
barBtns.turn = UI.button(bar, { text = "Turn", icon = ICON.rotate, kind = "blue", key = "R", size = UDim2.fromOffset(118, 52), order = 1, onClick = function() turnGhost(1) end })
barBtns.up = UI.button(bar, { icon = ICON.up, kind = "ink", key = "T", size = UDim2.fromOffset(56, 52), order = 2, onClick = function() raiseGhost(1) end })
barBtns.down = UI.button(bar, { icon = ICON.down, kind = "ink", key = "G", size = UDim2.fromOffset(56, 52), order = 3, onClick = function() raiseGhost(-1) end })
barBtns.place = UI.button(bar, { text = "Place", icon = ICON.place, kind = "green", size = UDim2.fromOffset(136, 52), order = 4, onClick = function() commit() end })
-- round 14: the room tool. With a plain wall in hand, Room mode turns a drag into a square room: walls all
-- round, a Room Door in the middle of one side (R while dragging moves the door to the next side).
barBtns.room = UI.button(bar, { text = "Room", icon = ICON.roomReady, kind = "ink", key = "F", size = UDim2.fromOffset(122, 52), order = 0, onClick = function() if S.toggleRoom then S.toggleRoom() end end })
barBtns.cancel = UI.button(bar, { text = "Cancel", icon = ICON.close, kind = "red", key = "X", size = UDim2.fromOffset(124, 52), order = 5, onClick = function() clearGhost() end })

---------------------------------------------------------------- shape editor (right)

local edWrap = wrapper("ShapeEditor", UDim2.fromOffset(290, 530), UDim2.new(1, -18, 0, 82), Vector2.new(1, 0))
edWrap.Visible = false
local edHolder, edBody = UI.panel(edWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
	name = "Editor", radius = 18, title = "Block", subtitle = "Size, colour and finish", icon = ICON.shapes,
})
local ED = { mode = nil, target = nil, pending = nil }
local edContent = UI.new("Frame", { Size = UDim2.new(1, -32, 1, -70), Position = UDim2.fromOffset(16, 62), BackgroundTransparency = 1, Parent = edBody })
UI.list(edContent, nil, 5)

local function edSection(text, order)
	return UI.label(edContent, text, 13, { FontFace = UI.F.black, TextColor3 = T.muted, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 16) })
end
edSection("SIZE (STUDS)", 1)
ED.sliders = {}
for i, axis in ipairs({ "X", "Y", "Z" }) do
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1 + i, Parent = edContent })
	local name = UI.label(row, axis == "X" and "Width" or axis == "Y" and "Height" or "Depth", 14, {
		FontFace = UI.F.heavy, Size = UDim2.new(0, 60, 1, 0),
	})
	local val = UI.label(row, "4.0", 14, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -40, 0, 0), Size = UDim2.new(0, 40, 1, 0) })
	local sf, set = UI.slider(row, Catalog.SHAPE_MIN, 16, 4, function(v)
		local s = S.shape.size
		local n = { X = s.X, Y = s.Y, Z = s.Z }
		n[axis] = v
		S.shape.size = Vector3.new(n.X, n.Y, n.Z)
		ED.changed("size")
	end, { step = 0.2, size = UDim2.new(1, -104, 1, 0), pos = UDim2.fromOffset(60, 0) })
	ED.sliders[axis] = { row = row, name = name, val = val, set = set }
end
edSection("COLOUR", 5)
local swGrid = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 4 * 30), BackgroundTransparency = 1, LayoutOrder = 6, Parent = edContent })
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(1 / 6, -7, 0, 24)
gl.CellPadding = UDim2.fromOffset(8, 6)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = swGrid
ED.swatches = {}
for i, col in ipairs(Catalog.SWATCHES) do
	local b = UI.new("TextButton", { Text = "", BackgroundColor3 = col, LayoutOrder = i, Parent = swGrid })
	UI.corner(b, 8)
	local st = UI.stroke(b, 2, T.cream, 1)
	UI.animate(b, { hover = 1.12, sound = false })
	b.Activated:Connect(function()
		UI.sound("Click")
		S.shape.color = col
		ED.changed("paint")
	end)
	ED.swatches[i] = { button = b, stroke = st, color = col }
end
edSection("FINISH", 7)
local matGrid = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 4 * 29), BackgroundTransparency = 1, LayoutOrder = 8, Parent = edContent })
local ml = Instance.new("UIGridLayout")
ml.CellSize = UDim2.new(1 / 4, -6, 0, 25)
ml.CellPadding = UDim2.fromOffset(8, 4)
ml.SortOrder = Enum.SortOrder.LayoutOrder
ml.Parent = matGrid
ED.mats = {}
for i, m in ipairs(Catalog.MATERIALS) do
	local b = UI.new("TextButton", { Text = m.name, TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.cream, BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = matGrid })
	UI.corner(b, 8)
	local st = UI.stroke(b, 1.5, T.gold, 1)
	local lk = UI.icon(b, ICON.lock, 16, { Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), Visible = false })
	b.Activated:Connect(function()
		if m.research and not Research.has(HOTEL, m.research) then
			UI.shake(b)
			toast(m.name .. " needs Research: " .. Research.BY_ID[m.research].name, "research", true)
			player:SetAttribute("OpenResearch", m.research)
			return
		end
		UI.sound("Click")
		S.shape.mat = m.id
		ED.changed("paint")
	end)
	ED.mats[i] = { button = b, stroke = st, lock = lk, mat = m }
end
do
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = 9, Parent = edContent })
	UI.label(row, "Guests walk through it", 14, { FontFace = UI.F.heavy, Size = UDim2.new(1, -60, 1, 0) })
	local _, set = UI.toggle(row, false, function(on)
		S.shape.ghost = on
		ED.changed("paint")
	end, { pos = UDim2.new(1, 0, 0.5, 0), anchor = Vector2.new(1, 0.5) })
	ED.setGhost = set
end
ED.price = UI.label(edContent, "", 16, { FontFace = UI.F.black, TextColor3 = T.green, LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 22) })

---------------------------------------------------------------- selection card (floats over the item)

local cardWrap = wrapper("ItemCard", UDim2.fromOffset(560, 116), UDim2.new(), Vector2.new(0.5, 1))
cardWrap.Visible = false
local cardHolder, cardBody = UI.panel(cardWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { name = "Card", radius = 16 })
local cardTitle = UI.label(cardBody, "", 19, { FontFace = UI.F.black, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 22) })
local cardSub = UI.label(cardBody, "", 13, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -36, 0, 16) })
local cardRow = UI.new("Frame", { Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 56), BackgroundTransparency = 1, Parent = cardBody })
UI.list(cardRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
local cardBtns = {}
local cardActions = {} -- forward table of functions
local function cardBtn(key, text, iconKey, kind, order, hotkey)
	local b = UI.button(cardRow, {
		name = key, text = text, icon = ICON[iconKey], kind = kind, key = hotkey, textSize = 16, iconSize = 22,
		size = UDim2.fromOffset(text and 92 or 50, 44), order = order, radius = 12,
		onClick = function() cardActions[key]() end,
	})
	cardBtns[key] = b
	return b
end
cardBtn("move", "Move", "move", "gold", 1, "M")
cardBtn("turn", "Turn", "rotate", "blue", 2, "R")
cardBtn("copy", "Copy", "copy", "violet", 3, "C")
cardBtn("paint", "Paint", "paint", "ink", 4)
cardBtn("sell", "Sell", "sell", "green", 5)
cardBtn("close", nil, "close", "ink", 6)

---------------------------------------------------------------- layout

local function layout()
	local vp = camera.ViewportSize
	local k = kOf(shopWrap)
	-- the drawer fills the bottom, clear of the cash stack on the bottom left (about 340 px)
	local left = 20 + 350 * k
	local span = math.max(vp.X - left - 20, 400)
	local w = math.min(span / k, 1240)
	shopWrap.Size = UDim2.fromOffset(w, 250)
	shopWrap.Position = UDim2.new(0, left + span / 2, 1, -14)
	local shift = edWrap.Visible and 150 * k or 0
	barWrap.Position = UDim2.new(0, left + span / 2 - shift, 1, -14 - 262 * k)
	local barList = barRow:FindFirstChildOfClass("UIListLayout")
	if S.building then
		btnWrap.AnchorPoint = Vector2.new(1, 0)
		btnWrap.Position = UDim2.new(1, -20, 0, 18)
		if barList then barList.HorizontalAlignment = Enum.HorizontalAlignment.Right end
	else
		btnWrap.AnchorPoint = Vector2.new(0.5, 1)
		btnWrap.Position = UDim2.new(0.5, 0, 1, -18)
		if barList then barList.HorizontalAlignment = Enum.HorizontalAlignment.Center end
	end
	for _, b in ipairs(menuBtns) do b.Visible = not S.building end
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.defer(layout) end)

---------------------------------------------------------------- zone overlays + room labels (local only)

local localFolder = Instance.new("Folder")
localFolder.Name = "BuildLocal"
localFolder.Parent = workspace

local overlay = Instance.new("Folder")
overlay.Name = "BuildOverlay"
local labels = {}

local function flatPlate(src, color, transp, outline)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transp
	p.Size = Vector3.new(src.Size.X, 0.06, src.Size.Z)
	p.CFrame = CFrame.new(src.Position.X, Build.FY + 0.13, src.Position.Z)
	p.Parent = overlay
	if outline then
		local sb = Instance.new("SelectionBox")
		sb.Adornee = p
		sb.Color3 = color
		sb.LineThickness = 0.06
		sb.SurfaceTransparency = 1
		sb.Transparency = 0.3
		sb.Parent = p
	end
	return p
end

local function roomLabel(zone)
	local bb = UI.new("BillboardGui", {
		Name = "ZoneLabel", Size = UDim2.fromOffset(176, 54), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 400,
		Adornee = zone, StudsOffsetWorldSpace = Vector3.new(0, 11, zone.Name == "Lobby" and 6 or 0), Enabled = false, Parent = pgui,
	})
	local f = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.ink, BackgroundTransparency = 0.12, Parent = bb })
	UI.corner(f, 11)
	UI.stroke(f, 1.5, T.gold, 0.35)
	local title = UI.label(f, "", 15, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6) })
	local info = UI.label(f, "", 12, { FontFace = UI.F.bold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 29) })
	labels[zone.Name] = { bb = bb, title = title, info = info }
end

local function refreshLabels()
	for name, l in pairs(labels) do
		if name == "Lobby" then
			l.title.Text = "LOBBY"
			l.info.Text = "Appeal " .. (HOTEL:GetAttribute("LobbyAppeal") or 0) .. "   Happier queue"
		else
			local r = HOTEL.Rooms:FindFirstChild(name)
			if r then
				l.title.Text = "ROOM " .. (r:GetAttribute("RoomId") or "")
				l.info.Text = "Appeal " .. (r:GetAttribute("Appeal") or 0) .. "   $" .. (r:GetAttribute("Price") or C.ROOM_PRICE) .. " a night"
			else
				-- the room is gone (sold or never built): drop the card instead of showing a blank one
				labels[name] = nil
				l.bb:Destroy()
			end
		end
	end
end

-- built on entering build mode: with streaming, the zone parts may not be here at startup
local function makeOverlay()
	overlay:ClearAllChildren()
	for _, z in ipairs(ZONES:GetChildren()) do
		if z:IsA("BasePart") then
			flatPlate(z, Color3.fromRGB(150, 210, 255), 0.9, true)
			-- only zones that hold a real room (or the lobby) get a card, so empty land stays clean
			if not labels[z.Name] and (z.Name == "Lobby" or HOTEL.Rooms:FindFirstChild(z.Name)) then
				roomLabel(z)
				local r = HOTEL.Rooms:FindFirstChild(z.Name)
				if r then
					r:GetAttributeChangedSignal("Appeal"):Connect(refreshLabels)
					r:GetAttributeChangedSignal("Price"):Connect(refreshLabels)
				end
			end
		end
	end
	for _, z in ipairs(ZONES.NoBuild:GetChildren()) do
		if z:IsA("BasePart") then
			local p = flatPlate(z, Color3.fromRGB(255, 110, 100), 0.72, true)
			p.Position += Vector3.new(0, 0.02, 0)
		end
	end
end
HOTEL:GetAttributeChangedSignal("LobbyAppeal"):Connect(refreshLabels)

function S.applyZones()
	overlay.Parent = (S.building and S.zones) and localFolder or nil
	for _, l in pairs(labels) do l.bb.Enabled = S.building and S.zones end
end

-- the grid under the ghost: a faded 16x16 cell plate that follows it
local gridPlate = Instance.new("Part")
gridPlate.Name = "GridPlate"
gridPlate.Anchored = true; gridPlate.CanCollide = false; gridPlate.CanQuery = false; gridPlate.CanTouch = false; gridPlate.CastShadow = false
gridPlate.Transparency = 1
gridPlate.Size = Vector3.new(16, 0.05, 16)
local gridTex = Instance.new("Texture")
gridTex.Texture = ICON.gridPlate
gridTex.Face = Enum.NormalId.Top
gridTex.Color3 = Color3.fromRGB(255, 226, 150)
gridTex.Transparency = 0.25
gridTex.Parent = gridPlate

---------------------------------------------------------------- build camera

local cam = { focus = Vector3.new(0, Build.FY, 0), yaw = 0, pitch = math.rad(52), dist = 62 }
local goal = { focus = cam.focus, yaw = 0, pitch = cam.pitch, dist = cam.dist }
local BOUNDS = { -46, 46, -38, 58 } -- round 10e: reaches the car park
local held = {}
local pad = { move = Vector2.zero, look = Vector2.zero, zin = 0, zout = 0 } -- controller sticks and triggers
local input = { rightDown = false, rightMoved = 0, touches = {}, clickDown = nil, uiClicked = 0 }
local controls

local function camCF(s)
	local rot = CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(-s.pitch, 0, 0)
	return CFrame.new(s.focus) * rot * CFrame.new(0, 0, s.dist)
end

local function stepCamera(dt)
	local pan = Vector3.zero
	local fwd = Vector3.new(-math.sin(goal.yaw), 0, -math.cos(goal.yaw))
	local right = Vector3.new(math.cos(goal.yaw), 0, -math.sin(goal.yaw))
	if held[Enum.KeyCode.W] or held[Enum.KeyCode.Up] then pan += fwd end
	if held[Enum.KeyCode.S] or held[Enum.KeyCode.Down] then pan -= fwd end
	if held[Enum.KeyCode.D] or held[Enum.KeyCode.Right] then pan += right end
	if held[Enum.KeyCode.A] or held[Enum.KeyCode.Left] then pan -= right end
	if pan.Magnitude > 0 then goal.focus += pan.Unit * dt * (24 + goal.dist * 0.6) end
	if held[Enum.KeyCode.Q] then goal.yaw += dt * 1.8 end
	if held[Enum.KeyCode.E] then goal.yaw -= dt * 1.8 end
	-- a controller: left stick pans, right stick looks, the triggers zoom
	local mv, lk = pad.move, pad.look
	if mv.Magnitude > 0.18 then goal.focus += (right * mv.X + fwd * mv.Y) * dt * (24 + goal.dist * 0.6) * math.min(mv.Magnitude, 1) end
	if lk.Magnitude > 0.18 then
		goal.yaw -= lk.X * dt * 2.4
		goal.pitch = math.clamp(goal.pitch - lk.Y * dt * 1.6, math.rad(20), math.rad(82))
	end
	if pad.zin + pad.zout > 0.05 then goal.dist *= 1 + (pad.zout - pad.zin) * dt * 1.4 end
	local x0 = O.X + math.min(BOUNDS[1], (HOTEL:GetAttribute("MinX") or -40) - 6)
	local x1 = O.X + math.max(BOUNDS[2], (HOTEL:GetAttribute("MaxX") or 40) + 6)
	goal.focus = Vector3.new(math.clamp(goal.focus.X, x0, x1), Build.FY, math.clamp(goal.focus.Z, BOUNDS[3], BOUNDS[4]))
	goal.dist = math.clamp(goal.dist, 16, 105)
	local a = 1 - math.exp(-dt * 10)
	cam.focus = cam.focus:Lerp(goal.focus, a)
	cam.yaw += (goal.yaw - cam.yaw) * a
	cam.pitch += (goal.pitch - cam.pitch) * a
	cam.dist += (goal.dist - cam.dist) * a
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camCF(cam)
end

---------------------------------------------------------------- picking

local function padAim() return UI.gamepad() and camera.ViewportSize / 2 or nil end
local function mouseRay(pos)
	pos = pos or padAim() or UIS:GetMouseLocation()
	return camera:ViewportPointToRay(pos.X, pos.Y)
end

local function floorPoint(pos, y)
	local r = mouseRay(pos)
	y = y or Build.FY
	if math.abs(r.Direction.Y) < 1e-4 then return nil end
	local t = (y - r.Origin.Y) / r.Direction.Y
	if t < 0 then return nil end
	return r.Origin + r.Direction * t
end

local pickParams = RaycastParams.new()
pickParams.FilterType = Enum.RaycastFilterType.Include
local function placedAt(pos)
	local r = mouseRay(pos)
	pickParams.FilterDescendantsInstances = { PLACED, deskModel }
	local hit = workspace:Raycast(r.Origin, r.Direction * 500, pickParams)
	if not hit then return nil end
	if deskModel and hit.Instance:IsDescendantOf(deskModel) then return deskModel end
	return Build.placedOf(hit.Instance)
end

-- what the cursor rests on for the ghost: furniture tops and walls (faded facade and the item being moved don't count)
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Include
local function aimHit(pos)
	local r = mouseRay(pos)
	local list = { PLACED }
	for _, n in ipairs({ "Shell", "Rooms", "Doors" }) do
		local f = HOTEL:FindFirstChild(n)
		if f then table.insert(list, f) end
	end
	aimParams.FilterDescendantsInstances = list
	local origin, dir = r.Origin, r.Direction * 400
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, dir, aimParams)
		if not hit then return nil end
		local p = hit.Instance
		local skip = p.LocalTransparencyModifier > 0.5 or p.Transparency > 0.95
			or (ghost and ghost.moving and p:IsDescendantOf(ghost.moving))
		if not skip then return hit end
		origin = hit.Position + r.Direction * 0.05
	end
	return nil
end

local blockers = { btnWrap, shopWrap, toolWrap, barWrap, edWrap, cardWrap }
local function overGui(pos)
	pos = pos or padAim() or UIS:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	for _, o in ipairs(pgui:GetGuiObjectsAtPosition(pos.X, pos.Y - inset.Y)) do
		for _, root in ipairs(blockers) do
			if root.Visible and o:IsDescendantOf(root) then return true end
		end
	end
	return false
end

---------------------------------------------------------------- highlights

local hoverHL = UI.new("Highlight", {
	Name = "Hover", FillTransparency = 0.88, FillColor = Color3.new(1, 1, 1), OutlineColor = T.cream,
	DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false, Parent = pgui,
})
local selHL = UI.new("Highlight", {
	Name = "Selected", FillTransparency = 0.78, FillColor = T.gold, OutlineColor = T.gold,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = pgui,
})

local function setLocalHidden(model, on)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 1 or 0 end
	end
end

local function yawOfModel(m)
	return Build.yawOf(m:GetPivot())
end

---------------------------------------------------------------- shape editor logic

local function isShape(id) local it = Catalog.ITEMS[id] return it and it.shape ~= nil end

function ED.sync()
	local id = ED.mode == "ghost" and ghost and ghost.id or (ED.target and ED.target:GetAttribute("Item"))
	local it = id and Catalog.ITEMS[id]
	if not it then return end
	edBody.Head.Title.Text = it.name
	edBody.Head.Sub.Text = ED.mode == "ghost" and "Set it up, then place it" or "Changes save as you go"
	local s = S.shape.size
	local kind = it.shape
	ED.sliders.X.name.Text = (kind == "Ball") and "Size" or (kind == "Cylinder") and "Across" or "Width"
	ED.sliders.Y.row.Visible = kind ~= "Ball"
	ED.sliders.Z.row.Visible = kind ~= "Ball" and kind ~= "Cylinder"
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local v = s[axis]
		ED.sliders[axis].set(v, true)
		ED.sliders[axis].val.Text = string.format("%.1f", v)
	end
	for _, sw in ipairs(ED.swatches) do
		local on = sw.color == S.shape.color
		UI.tween(sw.stroke, 0.15, { Transparency = on and 0 or 1 })
	end
	for _, m in ipairs(ED.mats) do
		local on = m.mat.id == S.shape.mat
		local locked = m.mat.research and not Research.has(HOTEL, m.mat.research)
		m.lock.Visible = locked or false
		UI.tween(m.stroke, 0.15, { Transparency = on and 0 or 1 })
		UI.tween(m.button, 0.15, { BackgroundColor3 = on and T.ink3 or T.ink2, TextTransparency = locked and 0.5 or 0 })
	end
	ED.setGhost(S.shape.ghost, true)
	local p = Catalog.price(id, s)
	if ED.mode == "ghost" then
		ED.price.Text = "$" .. commas(p) .. "  each"
		ED.price.TextColor3 = cash() >= p and T.green or T.red
	else
		local before = Catalog.price(id, ED.target:GetAttribute("Size"))
		local d = p - before
		ED.price.Text = d > 0 and ("Bigger: $" .. commas(d) .. " more") or d < 0 and ("Smaller: $" .. commas(math.floor(-d * Catalog.SELL_BACK)) .. " back") or ("Worth $" .. commas(p))
		ED.price.TextColor3 = d > 0 and T.gold or T.green
	end
end

local rebuildGhostModel -- forward
local applyToTarget -- forward
function ED.changed(what)
	S.shape.size = Build.shapeSize(ghost and ghost.id or (ED.target and ED.target:GetAttribute("Item")) or "ShapeBlock", S.shape.size)
	ED.sync()
	if ED.mode == "ghost" and ghost then
		rebuildGhostModel()
		refreshCards()
	elseif ED.mode == "target" and ED.target then
		-- debounce: send once the sliders settle
		ED.pending = (ED.pending or 0) + 1
		local n = ED.pending
		task.delay(what == "size" and 0.45 or 0.15, function()
			if ED.pending == n then applyToTarget() end
		end)
	end
end

function ED.open(mode, target)
	ED.mode, ED.target = mode, target
	if target then
		local o = Build.optsOf(target)
		S.shape.size = o.size or S.shape.size
		S.shape.color = o.color or S.shape.color
		S.shape.mat = o.mat or S.shape.mat
		S.shape.ghost = o.ghost or false
	end
	ED.sync()
	if not edWrap.Visible then
		edWrap.Visible = true
		layout()
		UI.open(edHolder, { rise = 0 })
		edHolder.Position = UDim2.new(0.5, 40, 0.5, 0)
		UI.tween(edHolder, 0.4, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
	end
end

function ED.close()
	ED.mode, ED.target = nil, nil
	if edWrap.Visible then
		UI.tween(edHolder, 0.2, { Position = UDim2.new(0.5, 40, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.close(edHolder, function() edWrap.Visible = false edHolder.Position = UDim2.fromScale(0.5, 0.5) layout() end)
	end
end

---------------------------------------------------------------- the item card

local cardWorld = Vector3.zero

local function placeCard()
	local v, onScreen = camera:WorldToViewportPoint(cardWorld)
	local vp = camera.ViewportSize
	local k = kOf(cardWrap)
	local w, h = 560 * k, 116 * k
	local x = math.clamp(v.X, w / 2 + 10, vp.X - w / 2 - 10)
	local y = math.clamp(v.Y - 10, h + 70, vp.Y - 280 * k)
	cardWrap.Position = UDim2.fromOffset(x, y)
	cardWrap.Visible = onScreen or v.Z > 0
end

local function closeCard()
	if selected and ED.mode == "target" then ED.close() end
	selected = nil
	S.sellArmed = false
	selHL.Enabled = false
	if cardWrap.Visible then
		UI.close(cardHolder, function()
			if not selected then cardWrap.Visible = false end
		end)
	end
end

local function setSellButton(armed, text, kind)
	cardBtns.sell.Row.Label.Text = text
	UI.setKind(cardBtns.sell, kind)
	if armed then UI.pop(cardBtns.sell, 1.15) end
end

local function openCard(m)
	if selected ~= m then UI.sound("Select") end
	local isDesk = m == deskModel
	local id = isDesk and "Desk" or m:GetAttribute("Item")
	local item = Catalog.ITEMS[id]
	selected = m
	S.sellArmed = false
	cardTitle.Text = isDesk and "Reception Desk" or (item and item.name or id)
	local isCore = not isDesk and m:GetAttribute("Core") ~= nil
	local zone = not isDesk and m:GetAttribute("Zone") or "Lobby"
	local where = zone == "Lobby" and "In the lobby" or ("In room " .. string.gsub(zone, "Room", ""))
	cardSub.Text = isDesk and "Part of the hotel: move or turn it" or (where .. ((item and item.appeal and item.appeal > 0) and ("   +" .. item.appeal .. " appeal") or ""))
	cardBtns.copy.Visible = not isDesk and not isCore and item ~= nil and not item.core
	cardBtns.paint.Visible = item ~= nil and item.shape ~= nil
	cardBtns.sell.Visible = true
	if isDesk then
		setSellButton(false, "Built in", "ghost")
	elseif isCore then
		setSellButton(false, "Needed", "ghost")
	else
		setSellButton(false, "$" .. commas(Catalog.sellValue(id, m:GetAttribute("Size"))), "green")
	end
	local cf, size = m:GetBoundingBox()
	cardWorld = cf.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
	placeCard()
	cardWrap.Visible = true
	UI.open(cardHolder, { rise = 12, from = 0.8 })
	selHL.Adornee = m
	selHL.Enabled = true
	if item and item.shape then ED.open("target", m) elseif ED.mode == "target" then ED.close() end
end

---------------------------------------------------------------- ghost

local function ghostify(m)
	m.Name = "Ghost"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
			d.Transparency = math.max(d.Transparency, 0.2)
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
	-- the bed ghost is just the made bed
	local messy = m:FindFirstChild("Messy")
	if messy then messy:Destroy() end
	return m
end

local tipGui = UI.new("BillboardGui", { Name = "GhostTip", Size = UDim2.fromOffset(300, 40), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = pgui })
local tipFrame = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 34), BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, Parent = tipGui })
UI.corner(tipFrame, 12)
local tipStroke = UI.stroke(tipFrame, 1.5, GOOD, 0.2)
UI.pad(tipFrame, 14, 0, 14, 0)
local tipText = UI.new("TextLabel", { Text = "", TextSize = 16, FontFace = UI.F.heavy, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Parent = tipFrame })
local tipAnchor = Instance.new("Part")
tipAnchor.Anchored = true; tipAnchor.CanCollide = false; tipAnchor.CanQuery = false; tipAnchor.CanTouch = false; tipAnchor.Transparency = 1
tipAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
tipAnchor.Parent = localFolder
tipGui.Adornee = tipAnchor

local ghostHL = UI.new("Highlight", { Name = "GhostHL", FillTransparency = 0.62, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = pgui })

local function ghostOpts()
	return ghost and isShape(ghost.id) and S.shape or {}
end

rebuildGhostModel = function()
	if not ghost then return end
	if ghost.model then ghost.model:Destroy() end
	local m = ghostify(Build.make(ghost.id, ghost.shown or CFrame.new(), ghostOpts()))
	m.Parent = localFolder
	ghost.model = m
	ghostHL.Adornee = m
	ghostHL.Enabled = true
	if ghost.target then ghost.validate() end
end

clearGhost = function()
	if not ghost then return end
	if ghost.model then ghost.model:Destroy() end
	if ghost.moving and ghost.moving.Parent then setLocalHidden(ghost.moving, false) end
	ghost = nil
	ghostHL.Enabled = false
	tipGui.Enabled = false
	gridPlate.Parent = nil
	if ED.mode == "ghost" then ED.close() end
	if barWrap.Visible then UI.close(bar, function() if not ghost then barWrap.Visible = false end end) end
	setHints(hintsFor(HINTS_IDLE))
	refreshCards()
end

local function heightStep()
	return S.grid > 0 and math.max(S.grid, 0.5) or 0.5
end

local function makeGhost(id, moving)
	local keepYaw = ghost and ghost.yaw
	clearGhost()
	closeCard()
	local start = moving and moving:GetPivot() or nil
	ghost = {
		id = id, moving = moving, yaw = start and Build.yawOf(start) or keepYaw or 0, dy = 0,
		target = start, shown = start, ok = false, spin = 0, wall = false,
	}
	if start then ghost.dy = math.max(start.Position.Y - Build.FY, 0) end
	function ghost.validate()
		local g = ghost
		if not g or not g.target then return end
		local ok, why
		local item = Catalog.ITEMS[g.id]
		local opts = ghostOpts()
		if g.moving == deskModel then
			ok, why = Build.deskOk(HOTEL, g.target)
		else
			ok, why = Build.validate(g.id, g.target, g.moving, opts)
		end
		local price = itemPrice(g.id, opts)
		if ok and not g.moving and cash() < price then ok, why = false, "Not enough cash" end
		g.ok, g.why = ok, why
		local col = ok and GOOD or BAD
		ghostHL.FillColor = col
		ghostHL.OutlineColor = col
		tipStroke.Color = col
		if ok then
			tipText.Text = g.moving and "Drop it here" or ("$" .. commas(price) .. ((item and item.appeal and item.appeal > 0) and ("   +" .. item.appeal .. " appeal") or ""))
			tipText.TextColor3 = Color3.fromRGB(200, 255, 210)
		else
			tipText.Text = why or "Can't go here"
			tipText.TextColor3 = Color3.fromRGB(255, 180, 170)
		end
		UI.setDisabled(barBtns.place, not ok)
		heightText.Text = string.format("%.1f", g.target.Position.Y - Build.FY)
	end
	if isShape(id) and moving then
		local o = Build.optsOf(moving)
		S.shape.size, S.shape.color, S.shape.mat, S.shape.ghost = o.size or S.shape.size, o.color or S.shape.color, o.mat or S.shape.mat, o.ghost or false
	end
	rebuildGhostModel()
	if moving then setLocalHidden(moving, true) end
	barBtns.place.Row.Label.Text = moving and "Drop" or "Place"
	local floorOnly = Build.floorOnly(id) or moving == deskModel
	barBtns.up.Visible = not floorOnly
	barBtns.down.Visible = not floorOnly
	heightPill.Visible = not floorOnly
	if S.refreshRoomBtn then S.refreshRoomBtn() end
	barWrap.Visible = true
	UI.open(bar, { rise = 16, from = 0.85 })
	tipGui.Enabled = true
	gridPlate.Parent = localFolder
	setHints(hintsFor(HINTS_GHOST))
	if isShape(id) then ED.open("ghost") end
	refreshCards()
end

startPlacing = function(id)
	makeGhost(id)
	if UI.gamepad() then GuiService.SelectedObject = nil end -- back to aiming with the reticle
end

local function snap(v)
	if S.grid <= 0 then return math.floor(v * 20 + 0.5) / 20 end
	return math.floor(v / S.grid + 0.5) * S.grid
end

-- round 10e: walls and doors lock onto the ends of the walls already there, so rooms close up without gaps.
-- In line: end to end. At right angles: an L corner, the new wall's end tucked against the old one's end face.
local WALL_SNAP = 2.6
local function snapStructure(id, cf)
	local placed = HOTEL:FindFirstChild("Placed")
	if not placed then return cf end
	local _, gsize = Build.box(id)
	local gl = gsize.X / 2
	local g = cf.RightVector
	local here = cf.Position
	local best, bestD = nil, WALL_SNAP
	for _, m in ipairs(placed:GetChildren()) do
		local mid = m:GetAttribute("Item")
		local it = mid and Catalog.ITEMS[mid]
		if it and it.structure and m ~= (ghost and ghost.moving) then
			local mcf = m:GetPivot()
			if (mcf.Position - here).Magnitude < 14 then
				local _, msize = Build.box(mid)
				local a = mcf.RightVector
				local hl, th = msize.X / 2, msize.Z / 2
				local dot = g:Dot(a)
				for _, sgn in ipairs({ 1, -1 }) do
					local tip = mcf.Position + a * sgn * hl
					local cands = {}
					if math.abs(dot) > 0.95 then
						table.insert(cands, tip + a * sgn * gl)
					elseif math.abs(dot) < 0.05 then
						local p = tip - a * sgn * th
						table.insert(cands, p + g * gl)
						table.insert(cands, p - g * gl)
					end
					for _, c in ipairs(cands) do
						local flat = Vector3.new(c.X, here.Y, c.Z)
						local d = (flat - here).Magnitude
						if d < bestD then best, bestD = flat, d end
					end
				end
			end
		end
	end
	if not best then return cf end
	return CFrame.new(best) * cf.Rotation
end

local function aimGhost(pos)
	if not ghost then return end
	local item = Catalog.ITEMS[ghost.id]
	local floorOnly = Build.floorOnly(ghost.id) or ghost.moving == deskModel
	local hit = not floorOnly and aimHit(pos) or nil
	local cf
	ghost.wall = false
	if item and item.wall and hit and math.abs(hit.Normal.Y) < 0.35 and not Build.placedOf(hit.Instance) then
		-- hang it flush on the wall it points at, facing out, sliding along the wall on the grid
		local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
		local off, size = Build.box(ghost.id)
		local back = off.Position.Z - size.Z / 2
		local p = hit.Position + n * (-back + 0.03)
		local along = Vector3.new(-n.Z, 0, n.X)
		local t = snap(p:Dot(along))
		local base = p - along * p:Dot(along) + along * t
		local yaw = Build.yawOf(CFrame.lookAt(base, base - n))
		local y = math.clamp((item.mount or 4) + ghost.dy, 0, Build.CEIL - Build.FY - size.Y)
		cf = Build.pivot(base.X, y, base.Z, yaw)
		ghost.wall = true
	else
		local base, point = 0, nil
		if hit and hit.Normal.Y > 0.7 and Build.placedOf(hit.Instance) then
			-- stack onto the top of the thing under the cursor
			base = hit.Position.Y - Build.FY
			point = hit.Position
		else
			point = floorPoint(pos)
		end
		if not point then return end
		local y = floorOnly and 0 or math.max(base + ghost.dy, 0)
		cf = Build.pivot(snap(point.X), y, snap(point.Z), ghost.yaw)
		if item and item.structure and S.wallSnap then
			local raw = Build.pivot(point.X, y, point.Z, ghost.yaw)
			local snapped = snapStructure(ghost.id, raw)
			if snapped ~= raw then cf = snapped end
		end
	end
	if not ghost.target or (cf.Position - ghost.target.Position).Magnitude > 0.01 or not cf.Rotation:FuzzyEq(ghost.target.Rotation, 1e-3) then
		ghost.target = cf
		if not ghost.shown then ghost.shown = cf end
		ghost.validate()
	end
end

turnGhost = function(dir)
	if not ghost then return end
	ghost.yaw = (ghost.yaw + (dir or 1) * S.yawStep) % 360
	ghost.spin = 1
	UI.sound("Turn")
	if ghost.target and not ghost.wall then
		local p = ghost.target.Position
		ghost.target = Build.pivot(p.X, p.Y - Build.FY, p.Z, ghost.yaw)
		ghost.validate()
	end
end

raiseGhost = function(dir)
	if not ghost or Build.floorOnly(ghost.id) or ghost.moving == deskModel then return end
	ghost.dy = math.max(ghost.dy + dir * heightStep(), -8)
	UI.sound("Tick")
	UI.pop(heightPill, 1.15, 0.25)
	if ghost.target then
		local p = ghost.target.Position
		local y = math.clamp(p.Y - Build.FY + dir * heightStep(), 0, Build.CEIL - Build.FY)
		ghost.target = Build.pivot(p.X, y, p.Z, Build.yawOf(ghost.target))
		ghost.validate()
	end
end

-- a little bounce + dust ring where something lands
local function landFX(m, cf)
	if not m or not m.Parent then return end
	local v = Instance.new("CFrameValue")
	v.Value = cf * CFrame.new(0, 1.6, 0)
	v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
	m:PivotTo(v.Value)
	local tw = UI.tween(v, 0.38, { Value = cf }, Enum.EasingStyle.Bounce)
	tw.Completed:Connect(function() v:Destroy() end)
	local a = Instance.new("Part")
	a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
	a.Size = Vector3.one
	a.Position = cf.Position + Vector3.new(0, 0.4, 0)
	a.Parent = localFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 248, 236))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(1, 2.4)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(10, 14)
	e.Drag = 6
	e.SpreadAngle = Vector2.new(0, 180)
	e.EmissionDirection = Enum.NormalId.Right
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	e.Parent = a
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = ICON.sparkle
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.5, 0.9)
	sp.Speed = NumberRange.new(6, 12)
	sp.SpreadAngle = Vector2.new(60, 60)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Acceleration = Vector3.new(0, -12, 0)
	sp.LightEmission = 0.4
	sp.Rate = 0
	sp.Parent = a
	task.delay(0.18, function() e:Emit(18) sp:Emit(8) end)
	game:GetService("Debris"):AddItem(a, 1.6)
	UI.sound("Place", cf.Position)
end

local function findUid(uid)
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Uid") == uid then return m end
	end
end

commit = function()
	if not ghost or S.busy or not ghost.target then return end
	if not ghost.ok then
		UI.pop(tipFrame, 1.25, 0.3)
		UI.shake(barBtns.place)
		toast(ghost.why or "Can't go here", "close", true)
		return
	end
	S.busy = true
	local g = ghost
	local cf = g.target
	local opts = isShape(g.id) and { size = S.shape.size, color = S.shape.color, mat = S.shape.mat, ghost = S.shape.ghost } or nil
	local ok, res
	if g.moving == deskModel then
		ok, res = Remote:InvokeServer("desk", cf)
	elseif g.moving then
		ok, res = Remote:InvokeServer("move", g.moving:GetAttribute("Uid"), cf, opts)
	else
		ok, res = Remote:InvokeServer("place", g.id, cf, opts)
	end
	S.busy = false
	if not ok then
		toast(res or "Can't go here", "close", true)
		return
	end
	if g.moving then
		local m = g.moving
		local uid = m ~= deskModel and m:GetAttribute("Uid")
		clearGhost()
		-- a resized shape is a fresh model with the same uid
		if uid and not m.Parent then m = findUid(uid) end
		landFX(m, cf)
	else
		local new = findUid(res)
		table.insert(S.undo, { uid = res, t = os.clock() })
		if #S.undo > 20 then table.remove(S.undo, 1) end
		local it = Catalog.ITEMS[g.id]
		local keep = (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift) or S.keep or (it and it.structure))
			and cash() >= itemPrice(g.id, opts)
		if keep then g.validate() else clearGhost() end
		if new then landFX(new, cf) end
	end
end

---------------------------------------------------------------- drag to place (round 11)
-- With something in hand, hold the left button and drag: a straight row (along X or Z) of copies follows the
-- cursor. Walls, windows and doors turn to run along the drag, end to end; furniture lines up on the grid.
-- Let go to place every copy that fits (one server call); Undo takes the whole row back.
do
	local MAX = 30
	local pool = {}
	local function box(name, col)
		local m = Instance.new("Model")
		m.Name = name
		local hl = UI.new("Highlight", { Name = name, FillColor = col, OutlineColor = col, FillTransparency = 0.62, OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Adornee = m, Parent = pgui })
		return m, hl
	end
	local goodBox, goodHL = box("DragGood", GOOD)
	local badBox, badHL = box("DragBad", BAD)
	local D

	local function trim(from)
		for i = #pool, from, -1 do
			pool[i]:Destroy()
			pool[i] = nil
		end
	end
	local function finish()
		trim(1)
		goodHL.Enabled, badHL.Enabled = false, false
		goodBox.Parent, badBox.Parent = nil, nil
		if D and D.active and ghost and ghost.model then
			ghost.model.Parent = localFolder
			ghostHL.Enabled = true
			ghost.validate()
		end
		D = nil
	end

	function S.dragBegin()
		if TOUCH or not ghost or ghost.moving or ghost.wall or not ghost.target then return end
		D = {
			id = ghost.id, start = ghost.target, down = UIS:GetMouseLocation(),
			opts = isShape(ghost.id) and { size = S.shape.size, color = S.shape.color, mat = S.shape.mat, ghost = S.shape.ghost } or nil,
		}
	end

	-- round 14: the room tool's square: walls all round from the corner where the drag began to the cursor,
	-- 4-stud wall units (2 to 10 a side), a door in the middle of side D.doorSide (0 near, 1 right, 2 far, 3 left)
	local U, ROOM_MIN, ROOM_MAX = 4, 2, 10
	local function isPlainWall(id)
		local it = Catalog.ITEMS[id]
		return it and it.structure and not it.doorway and it.wallKind == "Wall"
	end
	S.isPlainWall = isPlainWall
	local function roomRect()
		local p0 = D.start.Position
		local cur = floorPoint(nil, p0.Y)
		if not cur then return nil end
		local d = cur - p0
		local nx = math.clamp(math.floor(math.abs(d.X) / U + 0.5), ROOM_MIN, ROOM_MAX)
		local nz = math.clamp(math.floor(math.abs(d.Z) / U + 0.5), ROOM_MIN, ROOM_MAX)
		local sx, sz = d.X >= 0 and 1 or -1, d.Z >= 0 and 1 or -1
		local x0, z0 = p0.X, p0.Z
		local x1, z1 = x0 + sx * nx * U, z0 + sz * nz * U
		local y = p0.Y - Build.FY
		local side = (D.doorSide or 0) % 4
		local doorId = Catalog.ITEMS.RoomDoor and "RoomDoor" or "Door"
		local list, ids = {}, {}
		for i = 1, nx do
			local x = x0 + sx * (i - 0.5) * U
			for k, z in ipairs({ z0, z1 }) do
				local s = k == 1 and 0 or 2
				local out = (k == 1) and -sz or sz
				local door = side == s and i == math.ceil(nx / 2)
				table.insert(list, Build.pivot(x, y, z, door and (out > 0 and 0 or 180) or 0))
				table.insert(ids, door and doorId or D.id)
			end
		end
		for j = 1, nz do
			local z = z0 + sz * (j - 0.5) * U
			for k, x in ipairs({ x0, x1 }) do
				local s = k == 1 and 3 or 1
				local out = (k == 1) and -sx or sx
				local door = side == s and j == math.ceil(nz / 2)
				table.insert(list, Build.pivot(x, y, z, door and (out > 0 and 90 or 270) or 90))
				table.insert(ids, door and doorId or D.id)
			end
		end
		D.room = { w = nx * U, d = nz * U }
		return list, ids
	end
	function S.toggleRoom()
		if not ghost or not isPlainWall(ghost.id) then return end
		S.roomMode = not S.roomMode
		UI.sound("Tick")
		S.refreshRoomBtn()
		toast(S.roomMode and "Room tool: drag out a room" or "Room tool off", "roomReady")
	end
	function S.refreshRoomBtn()
		local show = ghost ~= nil and not ghost.moving and not TOUCH and isPlainWall(ghost.id)
		barBtns.room.Visible = show
		UI.setKind(barBtns.room, (show and S.roomMode) and "gold" or "ink")
		setHints(hintsFor((show and S.roomMode) and HINTS_ROOM or (ghost and HINTS_GHOST or HINTS_IDLE)))
	end
	-- R while drawing a room moves its door round to the next side
	function S.roomCycle()
		if not (D and D.active and D.ids) then return false end
		D.doorSide = ((D.doorSide or 0) + 1) % 4
		D.key = nil
		UI.sound("Turn")
		return true
	end

	-- the row's spots, from where the drag began to the cursor
	local function row()
		if S.roomMode and isPlainWall(D.id) then return roomRect() end
		local s0 = D.start
		local p0 = s0.Position
		local cur = floorPoint(nil, p0.Y)
		if not cur then return nil end
		local d = cur - p0
		local ax, az = math.abs(d.X), math.abs(d.Z)
		if math.max(ax, az) < 0.5 then return { s0 } end
		local dir = ax >= az and Vector3.new(math.sign(d.X), 0, 0) or Vector3.new(0, 0, math.sign(d.Z))
		local item = Catalog.ITEMS[D.id]
		local first = s0
		if item and item.structure and math.abs(s0.RightVector:Dot(dir)) < 0.5 then
			first = Build.pivot(p0.X, p0.Y - Build.FY, p0.Z, (Build.yawOf(s0) + 90) % 360)
		end
		local _, size = Build.box(D.id, D.opts and D.opts.size)
		local len = math.abs(first.RightVector:Dot(dir)) * size.X + math.abs(first.LookVector:Dot(dir)) * size.Z
		if not (item and item.structure) then
			len = S.grid > 0 and math.ceil(len / S.grid - 1e-3) * S.grid or len + 0.05
		end
		len = math.max(len, 0.5)
		local n = math.clamp(math.floor(d:Dot(dir) / len + 0.5) + 1, 1, MAX)
		local list = {}
		for i = 1, n do list[i] = first + dir * len * (i - 1) end
		return list
	end

	function S.dragStep()
		if not D then return end
		if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or not ghost or ghost.id ~= D.id or ghost.moving then
			if not D.sending then finish() end
			return
		end
		if not D.active then
			if (UIS:GetMouseLocation() - D.down).Magnitude < 8 then return end
			D.active = true
			if ghost.model then ghost.model.Parent = nil end
			ghostHL.Enabled = false
			goodBox.Parent, badBox.Parent = localFolder, localFolder
			goodHL.Enabled, badHL.Enabled = true, true
		end
		local list, ids = row()
		D.ids = ids
		if list then
			local last = list[#list]
			local key = #list .. tostring(list[1]) .. tostring(last.Position) .. tostring(D.doorSide)
			if key ~= D.key then
				D.key, D.list, D.oks = key, list, {}
				local price = itemPrice(D.id, D.opts)
				local left = cash()
				D.count, D.total, D.why = 0, 0, nil
				for i, cf in ipairs(list) do
					local pid = ids and ids[i] or D.id
					local pprice = pid == D.id and price or itemPrice(pid, nil)
					local m = pool[i]
					if m and m.Name ~= pid then
						m:Destroy()
						m = nil
					end
					if not m then
						m = ghostify(Build.make(pid, cf, pid == D.id and D.opts or {}))
						m.Name = pid
						pool[i] = m
					end
					m:PivotTo(cf * CFrame.new(0, 0.12, 0))
					local ok, why = Build.validate(pid, cf, nil, pid == D.id and D.opts or {})
					if ok and left < pprice then ok, why = false, "Not enough cash" end
					if ok then
						left -= pprice
						D.count += 1
						D.total += pprice
					else
						D.why = D.why or why
					end
					D.oks[i] = ok
					m.Parent = ok and goodBox or badBox
				end
				trim(#list + 1)
				D.price = price
				local _, size = Build.box(D.id, D.opts and D.opts.size)
				D.tipAt = (ids and (list[1].Position + last.Position) / 2 or last.Position) + Vector3.new(0, size.Y + 1.8, 0)
			end
		end
		-- the tip shows the row: how many fit and what they cost
		if D.list then
			tipAnchor.Position = D.tipAt
			local item = Catalog.ITEMS[D.id]
			local ok = D.count > 0
			tipStroke.Color = ok and GOOD or BAD
			tipText.TextColor3 = ok and Color3.fromRGB(200, 255, 210) or Color3.fromRGB(255, 180, 170)
			if D.ids and D.room then
				local all = D.count == #D.list
				ok = all
				tipStroke.Color = ok and GOOD or BAD
				tipText.TextColor3 = ok and Color3.fromRGB(200, 255, 210) or Color3.fromRGB(255, 180, 170)
				tipText.Text = all and ("Room " .. D.room.w .. " x " .. D.room.d .. "   $" .. commas(D.total) .. "   (R moves the door)")
					or (D.why or "The room doesn't fit here")
			else
				tipText.Text = ok and (D.count .. " x " .. (item and item.name or D.id) .. "   $" .. commas(D.count * D.price))
					or (cash() < D.price and "Not enough cash" or "Nothing fits here")
			end
		end
	end

	-- on release: true when this was a drag (the click is used up)
	function S.dragEnd()
		if not D then return false end
		if not D.active then
			D = nil
			return false
		end
		local d = D
		if d.ids and d.list then
			if d.count ~= #d.list then
				finish()
				toast(d.why or "The room doesn't fit there", "close", true)
				return true
			end
			local walls, doors = {}, {}
			for i, cf in ipairs(d.list) do
				if d.ids[i] == d.id then table.insert(walls, cf) else table.insert(doors, { d.ids[i], cf }) end
			end
			d.sending = true
			task.spawn(function()
				S.busy = true
				local ok, uids, why = Remote:InvokeServer("placeMany", d.id, walls, d.opts)
				local all = ok and table.clone(uids) or {}
				for _, dr in ipairs(doors) do
					task.wait(0.15)
					local ok2, uid = Remote:InvokeServer("place", dr[1], dr[2])
					if ok2 then table.insert(all, uid) else why = why or uid end
				end
				S.busy = false
				if D == d then finish() end
				if #all == 0 then
					toast((not ok and uids) or why or "Can't go here", "close", true)
					return
				end
				table.insert(S.undo, { uids = all, t = os.clock() })
				if #S.undo > 20 then table.remove(S.undo, 1) end
				for i, uid in ipairs(all) do
					task.delay(0.03 * (i - 1), function()
						local m = findUid(uid)
						if m then landFX(m, m:GetPivot()) end
					end)
				end
				if why then toast(why, "close", true) else toast("Room built: " .. d.room.w .. " x " .. d.room.d, "roomReady") end
				if ghost and cash() < itemPrice(ghost.id, d.opts) then clearGhost() end
			end)
			return true
		end
		local list = {}
		for i, cf in ipairs(d.list or {}) do
			if d.oks[i] then table.insert(list, cf) end
		end
		if #list == 0 then
			finish()
			toast(cash() < (d.price or 0) and "Not enough cash" or "Nothing fits there", "close", true)
			return true
		end
		d.sending = true
		task.spawn(function()
			S.busy = true
			local ok, uids, why = Remote:InvokeServer("placeMany", d.id, list, d.opts)
			S.busy = false
			if D == d then finish() end
			if not ok then
				toast(uids or "Can't go here", "close", true)
				return
			end
			table.insert(S.undo, { uids = uids, t = os.clock() })
			if #S.undo > 20 then table.remove(S.undo, 1) end
			for i, uid in ipairs(uids) do
				task.delay(0.035 * (i - 1), function()
					local m = findUid(uid)
					if m then landFX(m, m:GetPivot()) end
				end)
			end
			if why and #uids < #list then toast(#uids .. " placed. " .. why, "close", true) end
			if ghost and cash() < itemPrice(ghost.id, d.opts) then clearGhost() end
		end)
		return true
	end
end

---------------------------------------------------------------- card actions

local function selectedYaw() return selected and yawOfModel(selected) or 0 end

function cardActions.move()
	local m = selected
	if not m then return end
	if m == deskModel then makeGhost("Desk", m) return end
	local r = m:GetAttribute("Room") and HOTEL.Rooms:FindFirstChild(m:GetAttribute("Room"))
	if r and r:GetAttribute("State") == "Booked" then
		toast("A guest is using this room", "guest", true)
		return
	end
	makeGhost(m:GetAttribute("Item"), m)
end

function cardActions.turn()
	local m = selected
	if not m or S.busy then return end
	S.busy = true
	local from = m:GetPivot()
	local p = from.Position
	local cf = Build.pivot(p.X, p.Y - Build.FY, p.Z, (selectedYaw() + S.yawStep) % 360)
	local ok, why
	if m == deskModel then
		ok, why = Remote:InvokeServer("desk", cf)
	else
		ok, why = Remote:InvokeServer("move", m:GetAttribute("Uid"), cf)
	end
	S.busy = false
	if ok then
		local v = Instance.new("CFrameValue")
		v.Value = from
		v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
		local tw = UI.tween(v, 0.38, { Value = cf }, Enum.EasingStyle.Back)
		tw.Completed:Connect(function() v:Destroy() end)
		UI.sound("Turn")
	else
		toast(why or "No room to turn it", "close", true)
	end
end

function cardActions.copy()
	local m = selected
	if not m or m == deskModel then return end
	local id = m:GetAttribute("Item")
	if not unlocked(id) then toast("Research it first", "research", true) return end
	local yaw = yawOfModel(m)
	local dy = math.max(m:GetPivot().Position.Y - Build.FY, 0)
	if isShape(id) then
		local o = Build.optsOf(m)
		S.shape.size, S.shape.color, S.shape.mat, S.shape.ghost = o.size or S.shape.size, o.color or S.shape.color, o.mat or S.shape.mat, o.ghost or false
	end
	makeGhost(id)
	ghost.yaw = yaw
	ghost.dy = dy
	UI.sound("Click")
end

function cardActions.paint()
	if selected and isShape(selected:GetAttribute("Item")) then ED.open("target", selected) end
end

function cardActions.sell()
	local m = selected
	if not m or S.busy then return end
	if m == deskModel then
		toast("The reception desk is part of the hotel", "close", true)
		return
	end
	if m:GetAttribute("Core") then
		toast("Every room needs its " .. string.lower(Catalog.ITEMS[m:GetAttribute("Item")].name), "bed", true)
		return
	end
	if not S.sellArmed then
		S.sellArmed = true
		setSellButton(true, "Sure?", "red")
		task.delay(3, function()
			if S.sellArmed and selected == m then
				S.sellArmed = false
				setSellButton(false, "$" .. commas(Catalog.sellValue(m:GetAttribute("Item"), m:GetAttribute("Size"))), "green")
			end
		end)
		return
	end
	S.busy = true
	local pos = m:GetPivot().Position
	local ok, why = Remote:InvokeServer("sell", m:GetAttribute("Uid"))
	S.busy = false
	if ok then
		closeCard()
		UI.sound("Sell", pos)
	else
		toast(why or "Can't sell that", "close", true)
	end
end

function cardActions.close() closeCard() end

-- undo: sell the newest thing you placed that's still there (full price back within a minute)
function S.doUndo()
	if S.busy then return end
	while #S.undo > 0 do
		local u = table.remove(S.undo)
		if u.uids then
			-- a dragged row comes back all at once
			local live = {}
			for _, uid in ipairs(u.uids) do
				local m = findUid(uid)
				if m then
					if selected == m then closeCard() end
					table.insert(live, uid)
				end
			end
			if #live > 0 then
				S.busy = true
				local ok, done, why = Remote:InvokeServer("sellMany", live)
				S.busy = false
				if ok then
					UI.sound("Sell")
					toast("Undone " .. #done .. (os.clock() - u.t < 60 and ", full refund" or ""), "rotate")
				else
					toast(done or why or "Can't undo that", "close", true)
				end
				return
			end
		end
		local m = u.uid and findUid(u.uid)
		if m and not m:GetAttribute("Core") then
			S.busy = true
			local pos = m:GetPivot().Position
			if selected == m then closeCard() end
			local ok, why = Remote:InvokeServer("sell", u.uid)
			S.busy = false
			if ok then
				UI.sound("Sell", pos)
				toast(os.clock() - u.t < 60 and "Undone, full refund" or "Undone", "rotate")
			else
				toast(why or "Can't undo that", "close", true)
			end
			return
		end
	end
	toast("Nothing to undo", "close", true)
end

-- the shape editor's changes on a placed shape: colour/finish/walk-through (free), size (pay the difference)
applyToTarget = function()
	local m = ED.target
	if not m or not m.Parent or S.busy then return end
	local uid = m:GetAttribute("Uid")
	local o = Build.optsOf(m)
	S.busy = true
	local ok, why = true, nil
	if o.color ~= S.shape.color or o.mat ~= S.shape.mat or (o.ghost or false) ~= S.shape.ghost then
		ok, why = Remote:InvokeServer("paint", uid, { color = S.shape.color, mat = S.shape.mat, ghost = S.shape.ghost })
	end
	if ok and (o.size - S.shape.size).Magnitude > 0.01 then
		local cur = findUid(uid)
		ok, why = Remote:InvokeServer("move", uid, cur and cur:GetPivot() or m:GetPivot(), { size = S.shape.size })
	end
	S.busy = false
	if not ok then toast(why or "That doesn't fit", "close", true) end
	-- the server rebuilds the shape: follow the new model
	local cur = findUid(uid)
	if cur and selected == m then
		selected = cur
		selHL.Adornee = cur
		ED.target = cur
	end
	if cur then
		local o2 = Build.optsOf(cur)
		S.shape.size, S.shape.color, S.shape.mat, S.shape.ghost = o2.size, o2.color, o2.mat, o2.ghost or false
		ED.sync()
	end
end

---------------------------------------------------------------- enter / leave

-- the character stands still while you build (PlayerModule may not exist, so hold the humanoid too)
local saved
local function setControls(on)
	if not controls then
		local pmod = player.PlayerScripts:FindFirstChild("PlayerModule")
		local ok, pm = pcall(function() return pmod and require(pmod) end)
		if ok and pm then controls = pm:GetControls() end
	end
	if controls then
		if on then controls:Enable() else controls:Disable() end
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if not on then
		saved = saved or { hum.WalkSpeed, hum.JumpPower, hum.JumpHeight }
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
		hum:Move(Vector3.zero)
	elseif saved then
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = saved[1], saved[2], saved[3]
		saved = nil
	end
end

-- the glass front, sign and canopy hide the lobby from above: fade them while building
local facade
local function setFacade(on)
	if on or not facade then
		facade = {}
		for _, f in ipairs({ HOTEL:FindFirstChild("Shell"), HOTEL:FindFirstChild("Doors") }) do
			for _, d in ipairs(f and f:GetDescendants() or {}) do
				if d:IsA("BasePart") and d.Position.Z > 28.5 and d.Size.Y > 0.6 then table.insert(facade, d) end
			end
		end
	end
	for _, d in ipairs(facade) do d.LocalTransparencyModifier = on and 0.92 or 0 end
	for _, d in ipairs(HOTEL.Shell:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") and d.Parent.Position.Z > 28.5 then d.Enabled = not on end
	end
end

-- walls, floor and furniture of a new wing rise out of the ground, front to back, with a confetti pop
local function riseWing(id, pos)
	task.wait(0.15)
	local parts = {}
	local function grab(r)
		if not r then return end
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(parts, d) end
		end
	end
	grab(HOTEL.Shell:FindFirstChild("Wing" .. id))
	grab(HOTEL.Rooms:FindFirstChild("Room" .. id))
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Zone") == "Room" .. id then grab(m) end
	end
	for _, p in ipairs(parts) do
		local cf = p.CFrame
		local delay = math.clamp((30 - p.Position.Z) / 60, 0, 1) * 0.9 + math.clamp(p.Position.Y / 14, 0, 1) * 0.35
		p.CFrame = cf * CFrame.new(0, -16, 0)
		task.delay(delay, function()
			if p.Parent then UI.tween(p, 0.55, { CFrame = cf }, Enum.EasingStyle.Back) end
		end)
	end
	task.delay(1.4, function()
		local a = Instance.new("Part")
		a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
		a.Size = Vector3.one
		a.Position = pos + Vector3.new(0, 14, 0)
		a.Parent = localFolder
		local e = Instance.new("ParticleEmitter")
		e.Texture = ICON.star
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 140)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 90)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 240, 120)),
		})
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 1.6), NumberSequenceKeypoint.new(1, 0.3) })
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(26, 40)
		e.SpreadAngle = Vector2.new(70, 70)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -40, 0)
		e.Drag = 1.5
		e.RotSpeed = NumberRange.new(-300, 300)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 0.3
		e.Rate = 0
		e.Parent = a
		e:Emit(70)
		game:GetService("Debris"):AddItem(a, 3)
	end)
end

Shared.Remotes.Notify.OnClientEvent:Connect(function(kind, d)
	if kind ~= "roomBuilt" or d.hotel ~= HOTEL.Name then return end
	if S.building then
		goal.focus = Vector3.new(d.pos.X, Build.FY, d.pos.Z + 8)
		goal.dist = 72
		goal.pitch = math.rad(55)
		makeOverlay()
		refreshLabels()
		S.applyZones()
		setFacade(true)
	end
	riseWing(d.id, d.pos)
end)

buyRoom = function(id)
	if S.busy then return end
	S.busy = true
	clearGhost()
	closeCard()
	local ok, why = Remote:InvokeServer("room", id)
	S.busy = false
	if not ok then toast(why or "Couldn't buy that room", "close", true) end
end

-- panels slide in from their edges
local function slideIn(holder, from)
	holder.Position = UDim2.new(0.5, from.X, 0.5, from.Y)
	UI.tween(holder, 0.5, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
end
local function slideOut(wrap, holder, to)
	UI.tween(holder, 0.25, { Position = UDim2.new(0.5, to.X, 0.5, to.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		if not S.building then wrap.Visible = false end
		holder.Position = UDim2.fromScale(0.5, 0.5)
	end)
end

local function enter()
	if player:GetAttribute("Plot") ~= HOTEL.Name then
		toast("You can only build in your own hotel", "hammer", true)
		return
	end
	S.building = true
	player:SetAttribute("Building", true)
	setControls(false)
	bindPad(true)
	PPS.Enabled = false
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local look = camera.CFrame.LookVector
	goal.yaw = math.atan2(-look.X, -look.Z)
	local inside = hrp and math.abs(hrp.Position.X - O.X) < 40 and math.abs(hrp.Position.Z) < 30
	goal.focus = inside and Vector3.new(hrp.Position.X, Build.FY, hrp.Position.Z) or (O + Vector3.new(0, Build.FY, 2))
	if not inside then goal.yaw = 0 end
	goal.dist, goal.pitch = 70, math.rad(55)
	setFacade(true)
	-- start from where the play camera is, then glide up
	cam.focus = goal.focus
	cam.yaw = goal.yaw
	cam.pitch = math.rad(20)
	cam.dist = 18
	makeOverlay()
	refreshLabels()
	S.applyZones()
	setBuildButton(true)
	layout()
	shopWrap.Visible = true
	slideIn(shopHolder, Vector2.new(0, 300))
	toolWrap.Visible = true
	slideIn(toolHolder, Vector2.new(-300, 0))
	hintWrap.Visible = true
	setHints(hintsFor(HINTS_IDLE))
	UI.sound("Open")
	refreshCards(true)
	RunService:BindToRenderStep("BuildCam", Enum.RenderPriority.Camera.Value + 1, stepCamera)
end

local function leave()
	S.building = false
	player:SetAttribute("Building", nil)
	bindPad(false)
	clearGhost()
	closeCard()
	ED.close()
	hoverHL.Enabled = false
	hovered = nil
	RunService:UnbindFromRenderStep("BuildCam")
	camera.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	setControls(true)
	PPS.Enabled = true
	S.applyZones()
	setFacade(false)
	slideOut(shopWrap, shopHolder, Vector2.new(0, 300))
	slideOut(toolWrap, toolHolder, Vector2.new(-300, 0))
	hintWrap.Visible = false
	setBuildButton(false)
	layout()
	UI.sound("Close")
	table.clear(held)
	if searchInput:IsFocused() then searchInput:ReleaseFocus() end
end

toggle = function()
	if S.building then leave() else enter() end
end

---------------------------------------------------------------- input

local function worldClick()
	if ghost then
		commit()
	else
		local m = placedAt()
		if m then
			if m == selected then closeCard() else openCard(m) end
		else
			closeCard()
		end
	end
end

---------------------------------------------------------------- controller (round 10c)
-- While building, a controller's sticks drive the camera and its buttons place, turn and edit; the centre of the
-- screen is the cursor (a reticle marks it). Y hands the controller to the item drawer; B steps back.
local CAS = game:GetService("ContextActionService")
local PAD_BIND = {
	Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2,
	Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1,
}
local reticleGui = UI.new("ScreenGui", { Name = "PadReticle", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, Enabled = false, Parent = pgui })
local reticle = UI.new("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = reticleGui })
UI.corner(reticle, UDim.new(0.5, 0))
UI.stroke(reticle, 3, T.gold, 0.05)
local reticleDot = UI.new("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.cream, Parent = reticle })
UI.corner(reticleDot, UDim.new(0.5, 0))
local function refreshPad()
	reticleGui.Enabled = S.building and UI.gamepad() and not GuiService.SelectedObject
	if S.building then setHints(hintsFor(ghost and HINTS_GHOST or HINTS_IDLE)) end
end
UI.PadChanged.Event:Connect(refreshPad)
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(refreshPad)

local function padAction(_, state, io)
	local kc = io.KeyCode
	local ended = state ~= Enum.UserInputState.Begin and state ~= Enum.UserInputState.Change
	-- browsing the drawer: the UI has the controller (B hands it back)
	if GuiService.SelectedObject then
		if kc == Enum.KeyCode.ButtonB and state == Enum.UserInputState.Begin then
			GuiService.SelectedObject = nil
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	if kc == Enum.KeyCode.Thumbstick1 then
		pad.move = ended and Vector2.zero or Vector2.new(io.Position.X, io.Position.Y)
	elseif kc == Enum.KeyCode.Thumbstick2 then
		pad.look = ended and Vector2.zero or Vector2.new(io.Position.X, io.Position.Y)
	elseif kc == Enum.KeyCode.ButtonR2 then
		pad.zin = ended and 0 or io.Position.Z
	elseif kc == Enum.KeyCode.ButtonL2 then
		pad.zout = ended and 0 or io.Position.Z
	elseif state == Enum.UserInputState.Begin then
		if kc == Enum.KeyCode.ButtonA then
			if not overGui() then worldClick() end
		elseif kc == Enum.KeyCode.ButtonB then
			if ghost then clearGhost() elseif selected then closeCard() elseif not UI.closeTopmost() then toggle() end
		elseif kc == Enum.KeyCode.ButtonX then
			if ghost then turnGhost(1) elseif selected then cardActions.turn() end
		elseif kc == Enum.KeyCode.ButtonY then
			if selected then cardActions.move() else UI.padSelect(list) end
		elseif kc == Enum.KeyCode.ButtonR1 then
			raiseGhost(1)
		elseif kc == Enum.KeyCode.ButtonL1 then
			raiseGhost(-1)
		end
	end
	return Enum.ContextActionResult.Sink
end
bindPad = function(on)
	if on then
		CAS:BindActionAtPriority("BuildPad", padAction, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(PAD_BIND))
	else
		CAS:UnbindAction("BuildPad")
		pad.move, pad.look, pad.zin, pad.zout = Vector2.zero, Vector2.zero, 0, 0
	end
	refreshPad()
end

local PAN_KEYS = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Q] = true, [Enum.KeyCode.E] = true,
}

-- any button in build mode marks the click as taken (the world click waits a beat to see)
for _, root in ipairs(blockers) do
	local function hook(d) if d:IsA("GuiButton") then d.Activated:Connect(function() input.uiClicked = os.clock() end) end end
	for _, d in ipairs(root:GetDescendants()) do hook(d) end
	root.DescendantAdded:Connect(hook)
end

UIS.InputBegan:Connect(function(io, gp)
	if (io.KeyCode == Enum.KeyCode.B and not gp) or (io.KeyCode == Enum.KeyCode.DPadUp and not GuiService.SelectedObject
		and (S.building or not player:GetAttribute("MenuOpen"))) then
		toggle()
		return
	end
	if not S.building then return end
	if io.UserInputType == Enum.UserInputType.Keyboard then
		if gp then return end
		local shift = UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
		if PAN_KEYS[io.KeyCode] then held[io.KeyCode] = true end
		if io.KeyCode == Enum.KeyCode.R and S.roomCycle and S.roomCycle() then
			-- the room's door moved round
		elseif io.KeyCode == Enum.KeyCode.F and ghost and S.toggleRoom then
			S.toggleRoom()
		elseif io.KeyCode == Enum.KeyCode.R then
			if ghost then turnGhost(shift and -1 or 1) elseif selected then cardActions.turn() end
		elseif io.KeyCode == Enum.KeyCode.T or io.KeyCode == Enum.KeyCode.PageUp then raiseGhost(1)
		elseif io.KeyCode == Enum.KeyCode.G or io.KeyCode == Enum.KeyCode.PageDown then raiseGhost(-1)
		elseif io.KeyCode == Enum.KeyCode.C and selected then cardActions.copy()
		elseif io.KeyCode == Enum.KeyCode.M and selected then cardActions.move()
		elseif io.KeyCode == Enum.KeyCode.Delete and selected then cardActions.sell()
		elseif io.KeyCode == Enum.KeyCode.Z then S.doUndo()
		elseif io.KeyCode == Enum.KeyCode.X or io.KeyCode == Enum.KeyCode.Backspace then
			if ghost then clearGhost() else closeCard() end
		end
	elseif io.UserInputType == Enum.UserInputType.MouseButton1 then
		if gp or overGui() then return end
		input.clickDown = UIS:GetMouseLocation()
		if S.building then S.dragBegin() end
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
		input.rightDown, input.rightMoved = true, 0
		input.rightLast = UIS:GetMouseLocation()
	end
end)

UIS.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 then
		local down = input.clickDown
		input.clickDown = nil
		if S.dragEnd() then return end
		if not S.building or not down or (UIS:GetMouseLocation() - down).Magnitude > 8 then return end
		-- world clicks land on release, a beat later, unless a button took this click
		task.delay(0.05, function()
			if os.clock() - input.uiClicked < 0.25 then return end
			worldClick()
		end)
	elseif io.UserInputType == Enum.UserInputType.Keyboard then
		held[io.KeyCode] = nil
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
		if S.building and input.rightDown and input.rightMoved < 6 then
			if ghost then clearGhost() else closeCard() end
		end
		input.rightDown = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UIS.InputChanged:Connect(function(io, gp)
	if not S.building then return end
	if io.UserInputType == Enum.UserInputType.MouseWheel then
		if gp or overGui() then return end
		goal.dist *= (1 - io.Position.Z * 0.12)
	end
end)

-- round 12 fix: right-drag turns the view. It no longer locks the mouse (a locked mouse read as no move at
-- all on some setups); the turn is read once a frame, after the camera scripts, from the cursor's own move.
-- Half a screen's drag is more than a full turn, so the screen edge never gets in the way.
RunService:BindToRenderStep("BuildLook", Enum.RenderPriority.Camera.Value + 2, function()
	if not S.building or not input.rightDown then return end
	if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		input.rightDown = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		return
	end
	local p = UIS:GetMouseLocation()
	local d = p - (input.rightLast or p)
	input.rightLast = p
	input.rightMoved += math.abs(d.X) + math.abs(d.Y)
	if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then UIS.MouseBehavior = Enum.MouseBehavior.Default end
	-- Settings > Controls: build camera speed and invert (round 12)
	local sens = (player:GetAttribute("LookSens") or 100) / 100
	local inv = player:GetAttribute("LookInvert") and -1 or 1
	goal.yaw -= d.X * 0.008 * sens
	goal.pitch = math.clamp(goal.pitch + d.Y * 0.006 * sens * inv, math.rad(20), math.rad(82))
end)

-- touch: one finger pans (or drags the ghost), two fingers pinch-zoom
UIS.TouchStarted:Connect(function(t, gp)
	if not S.building then return end
	if gp and overGui(Vector2.new(t.Position.X, t.Position.Y + GuiService:GetGuiInset().Y)) then return end
	input.touches[t] = { start = t.Position, last = t.Position, moved = 0 }
end)
UIS.TouchMoved:Connect(function(t)
	if not S.building or not input.touches[t] then return end
	local rec = input.touches[t]
	local d = t.Position - rec.last
	rec.moved += d.Magnitude
	local n = 0
	for _ in pairs(input.touches) do n += 1 end
	if n >= 2 then
		input.twoFinger = true
		local a, b
		for tt, r in pairs(input.touches) do if not a then a = { tt, r } elseif not b then b = { tt, r } end end
		local pa, pb = a[1].Position, b[1].Position
		local la, lb = a[2].last, b[2].last
		local before = (Vector2.new(la.X, la.Y) - Vector2.new(lb.X, lb.Y)).Magnitude
		local after = (Vector2.new(pa.X, pa.Y) - Vector2.new(pb.X, pb.Y)).Magnitude
		if before > 10 then goal.dist *= before / math.max(after, 1) end
		-- round 12: twisting two fingers turns the view, sliding both up or down tilts it
		local va, vb = Vector2.new(la.X - lb.X, la.Y - lb.Y), Vector2.new(pa.X - pb.X, pa.Y - pb.Y)
		if before > 30 and after > 30 then
			local turn = math.atan2(va.X * vb.Y - va.Y * vb.X, va:Dot(vb))
			goal.yaw -= turn * (player:GetAttribute("LookSens") or 100) / 100
		end
		if t == a[1] or t == b[1] then
			local other = (t == a[1]) and b or a
			local od = other[1].Position - other[2].last
			-- both fingers moving the same way vertically
			if d.Y * od.Y > 0 then
				goal.pitch = math.clamp(goal.pitch + (d.Y + od.Y) * 0.5 * 0.006, math.rad(20), math.rad(82))
			end
		end
		a[2].last, b[2].last = pa, pb -- both lasts move on, so neither finger's motion counts twice
	elseif input.twoFinger then
		-- a finger left over from a pinch doesn't pan until it lifts
	elseif ghost and rec.moved > 8 then
		aimGhost(Vector2.new(t.Position.X, t.Position.Y + GuiService:GetGuiInset().Y))
	else
		local k = goal.dist / 900
		local fwd = Vector3.new(-math.sin(goal.yaw), 0, -math.cos(goal.yaw))
		local right = Vector3.new(math.cos(goal.yaw), 0, -math.sin(goal.yaw))
		goal.focus += (-right * d.X + fwd * d.Y) * k
	end
	rec.last = t.Position
end)
UIS.TouchEnded:Connect(function(t)
	local rec = input.touches[t]
	input.touches[t] = nil
	if input.twoFinger then
		if next(input.touches) == nil then input.twoFinger = false end
		return
	end
	if not S.building or not rec or rec.moved > 12 then return end
	local pos = Vector2.new(t.Position.X, t.Position.Y + GuiService:GetGuiInset().Y)
	if overGui(pos) then return end
	if ghost then
		aimGhost(pos)
	else
		local m = placedAt(pos)
		if m then openCard(m) else closeCard() end
	end
end)

---------------------------------------------------------------- per frame

RunService.RenderStepped:Connect(function(dt)
	if not S.building then return end
	-- the player camera scripts can drop the lock mid-drag: hold it while the right button turns the view
	if ghost then
		if not TOUCH and not overGui() then aimGhost() end
		if ghost.target and ghost.model then
			local a = 1 - math.exp(-dt * 22)
			ghost.shown = ghost.shown and ghost.shown:Lerp(ghost.target, a) or ghost.target
			ghost.spin = math.max(ghost.spin - dt * 4, 0)
			local lift = math.sin(ghost.spin * math.pi) * 0.8 + 0.12 + math.sin(os.clock() * 4) * 0.06
			ghost.model:PivotTo(ghost.shown * CFrame.new(0, lift, 0))
			local cf, size = ghost.model:GetBoundingBox()
			tipAnchor.Position = cf.Position + Vector3.new(0, size.Y / 2 + 1.8, 0)
			-- the grid plate sits under the ghost, lined up with the snap grid
			if S.grid > 0 and not ghost.wall then
				local g = S.grid
				local p = ghost.target.Position
				gridPlate.Size = Vector3.new(16 * g, 0.05, 16 * g)
				gridTex.StudsPerTileU, gridTex.StudsPerTileV = 16 * g, 16 * g
				local gx = math.floor(p.X / g + 0.5) * g
				local gz = math.floor(p.Z / g + 0.5) * g
				gridPlate.CFrame = CFrame.new(gx, p.Y + 0.04, gz)
				gridPlate.Parent = localFolder
			else
				gridPlate.Parent = nil
			end
		end
		hoverHL.Enabled = false
		S.dragStep()
	else
		local m = not TOUCH and not overGui() and placedAt() or nil
		if m ~= hovered then
			hovered = m
			hoverHL.Adornee = m
			hoverHL.Enabled = m ~= nil and m ~= selected
		end
	end
	if selected then
		if not selected.Parent then closeCard() else placeCard() end
	end
end)

player.CharacterAdded:Connect(function()
	if S.building then leave() end
end)

layout()

-- round 14: other screens can open build mode on a tab (player attribute BuildWant = a category id)
player:GetAttributeChangedSignal("BuildWant"):Connect(function()
	local want = player:GetAttribute("BuildWant")
	if not want then return end
	player:SetAttribute("BuildWant", nil)
	if not S.building then enter() end
	task.defer(function()
		pcall(function() tabsApi.select(want, true) end)
		S.cat = want
		refreshCards(true)
	end)
end)

-- Coop calls this before it restarts the script (you moved to another hotel): leave build mode cleanly
local leaveFn = Instance.new("BindableFunction")
leaveFn.Name = "Leave"
leaveFn.OnInvoke = function() if S.building then leave() end end
leaveFn.Parent = script
