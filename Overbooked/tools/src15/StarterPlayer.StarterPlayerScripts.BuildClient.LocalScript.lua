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
	rb = { kit = "empty", wall = "Wall", door = "RoomDoor", furnish = false }, -- the Room Builder's choices (round 32: walls only)
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

---------------------------------------------------------------- the bottom dock: build + the menu buttons

-- round 34: back to round 15 v2's bar (the player wanted the 3D icons back): one glossy tray on a deep shadow. BUILD is the big violet key on the left (it stands
-- on a lip and turns green as DONE while building); the menu pages sit beside it as shaded colour tiles with
-- their icons, names under them and a small key cap. Tiles hop up and tilt their icon on hover.
local btnWrap = wrapper("BuildButton", UDim2.fromOffset(660, 120), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
local toggle -- forward
local bindPad -- forward (the controller block)
local dockHolder = UI.new("Frame", { Name = "Dock", Size = UDim2.fromOffset(0, 98), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = btnWrap })
UI.shadow(dockHolder, { drop = 10, transparency = 0.55, spread = 4 })
local barRow = UI.new("Frame", { Name = "Row", Size = UDim2.fromOffset(0, 98), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, Parent = dockHolder })
UI.corner(barRow, 30)
UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(230, 226, 250)), Parent = barRow })
UI.rim(barRow, Color3.fromRGB(204, 196, 244), 3)
do
	local g = UI.new("Frame", { Name = "Gloss", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 4), BackgroundColor3 = T.white, BackgroundTransparency = 0.3, Parent = barRow })
	UI.corner(g, 16)
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1), Parent = g })
end
local rowList = UI.new("Frame", { Name = "List", Size = UDim2.fromOffset(0, 98), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2, Parent = barRow })
UI.pad(rowList, 12, 0, 14, 0)
UI.list(rowList, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

local capN = 0

-- one button: spec = { img, color, big }
local function barButton(spec, key, label, onClick)
	capN += 1
	local big = spec.big
	local col = spec.color or T.brand
	local deep = spec.deep or UI.shade(col, -0.42)
	local TW, TH = big and 74 or 56, big and 62 or 56
	local Y0 = big and 2 or 4
	local b = UI.new("TextButton", { Name = "Btn_" .. (key or label), Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(big and 90 or 70, 84), BackgroundTransparency = 1, LayoutOrder = capN, ZIndex = 2, Parent = rowList })
	-- the lip under every tile; the build key's is deeper
	local lipC = UI.new("Frame", { Name = "Lip", Size = UDim2.fromOffset(TW, TH), Position = UDim2.new(0.5, 0, 0, Y0 + (big and 6 or 4)), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = deep, ZIndex = 2, Parent = b })
	UI.corner(lipC, big and 20 or 17)
	local lipRim = UI.rim(lipC, UI.shade(deep, -0.25), 2)
	local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(TW, TH), Position = UDim2.new(0.5, 0, 0, Y0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = col, ZIndex = 3, Parent = b })
	UI.corner(tile, big and 20 or 17)
	UI.sheen(tile)
	local tileRim = UI.rim(tile, deep, 2.5)
	UI.gloss(tile, big and 20 or 17, 0.45)
	local playShine = UI.shine(tile, big and 20 or 17)
	local ic = UI.icon(tile, spec.img, big and 48 or 42, { Name = "Icon", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7 })
	local lab = UI.label(b, string.upper(label), big and 16 or 14, {
		Name = "Label", FontFace = UI.F.display, TextColor3 = big and T.brandDk or T.cream, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, -6, 1, -15), Size = UDim2.new(1, 12, 0, 16), ZIndex = 5,
	})
	local k
	if key then
		k = UI.new("TextLabel", {
			Name = "Cap", Text = key, TextSize = 12, FontFace = UI.F.display, TextColor3 = T.cream, BackgroundColor3 = T.white,
			Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, TW / 2 - 4, 0, Y0 - 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 9, Parent = b,
		})
		UI.corner(k, 7)
		UI.sheen(k, 0.5)
		UI.rim(k, deep, 2)
		local function showKey(isPadNow)
			local pk = UI.PAD_KEYS[key]
			k.Text = isPadNow and (pk or "") or key
			k.Size = UDim2.fromOffset(#k.Text > 1 and 36 or 20, 20)
			k.Visible = not (isPadNow and not pk) and not (UIS.TouchEnabled and not UIS.KeyboardEnabled and not isPadNow)
		end
		showKey(UI.gamepad())
		UI.PadChanged.Event:Connect(showKey)
	end
	local sc = UI.scaleOf(b)
	local isc = UI.scaleOf(ic)
	b.MouseEnter:Connect(function()
		UI.tween(tile, 0.2, { Position = UDim2.new(0.5, 0, 0, Y0 - 5) }, Enum.EasingStyle.Back)
		UI.tween(lipC, 0.2, { Position = UDim2.new(0.5, 0, 0, Y0 + (big and 6 or 4) - 3) }, Enum.EasingStyle.Back)
		UI.tween(isc, 0.22, { Scale = 1.16 }, Enum.EasingStyle.Back)
		UI.tween(ic, 0.22, { Rotation = -9 }, Enum.EasingStyle.Back)
		playShine()
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		UI.tween(tile, 0.22, { Position = UDim2.new(0.5, 0, 0, Y0) }, Enum.EasingStyle.Quint)
		UI.tween(lipC, 0.22, { Position = UDim2.new(0.5, 0, 0, Y0 + (big and 6 or 4)) }, Enum.EasingStyle.Quint)
		UI.tween(isc, 0.22, { Scale = 1 }, Enum.EasingStyle.Quint)
		UI.tween(ic, 0.22, { Rotation = 0 })
	end)
	b.MouseButton1Down:Connect(function() UI.tween(tile, 0.06, { Position = UDim2.new(0.5, 0, 0, Y0 + (big and 5 or 3)) }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Up:Connect(function() UI.tween(tile, 0.24, { Position = UDim2.new(0.5, 0, 0, Y0) }, Enum.EasingStyle.Back) end)
	if onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			UI.pop(ic, 0.7, 0.4)
			UI.sparkles(tile, 3, T.white, 1)
			onClick()
		end)
	end
	-- arrival: the buttons hop in one after another
	sc.Scale = 0
	UI.tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.25 + 0.05 * (capN - 1))
	b:SetAttribute("Deep", deep)
	return b, ic, tile, lab, tileRim, lipC, lipRim
end

local function openMenu(tab) player:SetAttribute("MenuWant", tab) end

local buildBtn, buildIcon, buildTile, buildLab, buildRim, buildLip, buildLipRim = barButton({ img = ICON.hammer, color = T.brand, deep = T.brandDk, big = true }, "B", "Build", function() toggle() end)
-- a soft groove between BUILD and the menu pages
do
	capN += 1
	local div = UI.new("Frame", { Name = "Div", Size = UDim2.fromOffset(14, 58), BackgroundTransparency = 1, LayoutOrder = capN, ZIndex = 2, Parent = rowList })
	local line = UI.new("Frame", { Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.fromRGB(210, 204, 242), ZIndex = 2, Parent = div })
	UI.corner(line, 2)
end
local menuBtns = {}
for _, m in ipairs({
	{ { img = ICON.hotel, color = T.blue }, "M", "Hotel", "hotel" },
	{ { img = "rbxassetid://112752899117499", color = T.orange }, "T", "Staff", "staff" },
	{ { img = "rbxassetid://111953023418308", color = T.green }, "R", "Research", "research" },
	{ { img = ICON.upgrade, color = T.sun }, "U", "Upgrades", "upgrades" },
	{ { img = "rbxassetid://72065626098144", color = T.violet }, "Y", "Awards", "achievements" },
	{ { img = "rbxassetid://95707331138329", color = Color3.fromRGB(142, 150, 196) }, nil, "Settings", "settings" },
}) do
	menuBtns[#menuBtns + 1] = barButton(m[1], m[2], m[3], function() openMenu(m[4]) end)
	menuBtns[#menuBtns]:SetAttribute("Page", m[4])
end
buildBtn:SetAttribute("Page", "build")
-- round 41: during the tutorial a page's button only shows once the tutorial has unlocked it (UI.locked)
do
	local function applyLocks()
		for _, b in ipairs({ buildBtn, table.unpack(menuBtns) }) do
			local show = not UI.locked(b:GetAttribute("Page"))
			if b.Visible ~= show then
				b.Visible = show
				if show then
					UI.pop(b, 0.3, 0.5)
					UI.sparkles(b, 6, T.sun, 1)
				end
			end
		end
		local div = rowList:FindFirstChild("Div")
		if div then div.Visible = not S.building and not UI.locked("build") end
	end
	player:GetAttributeChangedSignal("TutLock"):Connect(applyLocks)
	applyLocks()
end

local function setBuildButton(on)
	buildIcon.Image = on and ICON.checkmark or ICON.hammer
	buildLab.Text = on and "DONE" or "BUILD"
	UI.tween(buildTile, 0.25, { BackgroundColor3 = on and T.green or T.brand })
	UI.tween(buildRim, 0.25, { Color = on and T.greenDk or T.brandDk })
	UI.tween(buildLip, 0.25, { BackgroundColor3 = on and T.greenDk or T.brandDk })
end
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
	or { { "Drag", "Pan, or move an item" }, { "Right drag", "Turn" }, { "Scroll", "Zoom" }, { "Click", "Edit an item" }, { "Z", "Undo" }, { "B", "Done" } }
local HINTS_GHOST = TOUCH and { { "", "Tap the floor to aim" }, { "", "Use the buttons to turn and place" } }
	or { { "Click", "Place" }, { "Drag", "Place a row" }, { "R", "Turn" }, { "T G", "Raise / lower" }, { "Middle drag", "Pan" }, { "X", "Cancel" } }
local HINTS_ROOM = { { "Drag", "Draw a room" }, { "R", "Move the door" }, { "Right drag", "Turn" }, { "Z", "Undo" }, { "F", "Close" } }
local PAD_IDLE = { { "LS", "Move" }, { "RS", "Look" }, { "LT RT", "Zoom" }, { "A", "Edit an item" }, { "Y", "Browse items" }, { "B", "Done" } }
local PAD_GHOST = { { "A", "Place" }, { "X", "Turn" }, { "LB RB", "Raise / lower" }, { "Y", "Browse items" }, { "B", "Cancel" } }
local function hintsFor(set)
	if UI.gamepad() then return set == HINTS_GHOST and PAD_GHOST or PAD_IDLE end
	return set
end

---------------------------------------------------------------- the shop, tools, selection, placement
-- round 42: all in Shared.BuildKit, made further down once the ghost and the camera exist

local Kit -- the BuildKit (set up before enter / leave)
local function refreshCards(arrive) if Kit then Kit.refreshCards(arrive) end end
local startPlacing, buyRoom -- forward

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

S.walls = "cut" -- round 28: the walls between you and what you look at go see-through
S.wallSnap = true
S.keep = false
S.stack = true -- round 42: Placement panel switches (BuildKit)
S.hug = false
S.undo = {} -- uids you placed, newest last

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

---------------------------------------------------------------- shape editor (right)

local edWrap = wrapper("ShapeEditor", UDim2.fromOffset(290, 530), UDim2.new(0, 18, 0, 140), Vector2.new(0, 0)) -- round 33: left (the catalog took the right)
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

---------------------------------------------------------------- layout

local function layout()
	if not Kit then return end
	local vp = camera.ViewportSize
	local shopWrap = Kit.shopWrap
	local k = kOf(shopWrap)
	-- round 33: the shop runs down the right edge, under the build button; round 42: the tool rail down the left
	shopWrap.Size = UDim2.fromOffset(Kit.SHOP_W, math.clamp((vp.Y - 150) / k, 380, 900))
	shopWrap.Position = UDim2.new(1, -16, 1, -14)
	local right = 32 + Kit.SHOP_W * k
	local left = Kit.leftEdge()
	-- the bars sit in the middle of what's left; the block editor sits beside the shop
	local cx = left + math.max(vp.X - right - left, 300) / 2
	barWrap.Position = UDim2.new(0, cx, 1, -14)
	edWrap.AnchorPoint = Vector2.new(1, 0)
	edWrap.Position = UDim2.new(1, -(right - 8), 0, 140)
	Kit.layout(vp, right, cx, -14)
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
	if div then div.Visible = not S.building and not UI.locked("build") end
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
	if zone.Name ~= "Lobby" then
		-- round 33: click the room's name to renumber it
		bb.Active = true
		title:Destroy()
		title = UI.new("TextBox", { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 4), BackgroundColor3 = T.ink2, BackgroundTransparency = 0.4,
			FontFace = UI.F.black, TextSize = 15, TextColor3 = T.gold, PlaceholderText = "Type a number", ClearTextOnFocus = true, Text = "", Parent = f })
		UI.corner(title, 6)
		title.FocusLost:Connect(function(enter)
			local n = tonumber(string.match(title.Text, "%d+") or "")
			local r = HOTEL.Rooms:FindFirstChild(zone.Name)
			local shown = r and (r:GetAttribute("Label") or r:GetAttribute("RoomId")) or ""
			if enter and n then
				local ok, why = Remote:InvokeServer("label", zone.Name, n)
				if ok then shown = why else toast(why or "Can't rename that room", nil, true) end
			end
			title.Text = "ROOM " .. tostring(shown)
		end)
	end
	-- round 33: floors and the roof are picked here (click to cycle through Shared.Upgrades.STYLES)
	local Up = require(Shared:WaitForChild("Upgrades"))
	local upRemote = Shared.Remotes:WaitForChild("Upgrade")
	bb.Active = true
	bb.Size = UDim2.fromOffset(196, 84)
	local function cycler(x, w, key, list, current)
		local b = UI.new("TextButton", { Position = UDim2.fromOffset(x, 52), Size = UDim2.fromOffset(w, 24), BackgroundColor3 = T.ink2, AutoButtonColor = true,
			FontFace = UI.F.bold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "", Parent = f })
		UI.corner(b, 6)
		UI.new("UITextSizeConstraint", { MaxTextSize = 12, Parent = b })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = b })
		local function show()
			local cur = current()
			for _, e in ipairs(list) do
				if e[1] == cur then b.Text = (key == "roof" and "Roof: " or "Floor: ") .. e[2] end
			end
		end
		show()
		b.Activated:Connect(function()
			local cur, nxt = current(), list[1]
			for i, e in ipairs(list) do
				if e[1] == cur then nxt = list[i % #list + 1] end
			end
			local ok, why = upRemote:InvokeServer("style", key, nxt[1])
			if ok then UI.sound("Turn") else toast(why or "Can't change that", nil, true) end
			show()
		end)
	end
	if zone.Name == "Lobby" then
		cycler(8, 88, "lobby", Up.STYLES[1].list, function() return Up.style(HOTEL).lobby end)
		cycler(100, 88, "roof", Up.STYLES[4].list, function() return Up.style(HOTEL).roof end)
	else
		cycler(8, 180, "room:" .. zone.Name, Up.STYLES[2].list, function()
			return Up.decode(HOTEL:GetAttribute("RoomFloors"))[zone.Name] or Up.style(HOTEL).rooms
		end)
	end
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
				if not l.title:IsA("TextBox") or not l.title:IsFocused() then l.title.Text = "ROOM " .. (r:GetAttribute("Label") or r:GetAttribute("RoomId") or "") end
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
			-- round 41: the room cards are gone (the floors and roof moved to the tool bar)
			if false and not labels[z.Name] and (z.Name == "Lobby" or HOTEL.Rooms:FindFirstChild(z.Name)) then
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

-- round 43: a faint grid over the whole plot (the Grounds zone) while building. 4-stud cells: finer lines
-- fade out at build-camera distance. Every snap step (.25 to 4) lands on them.
local groundGrid = gridPlate:Clone()
groundGrid.Name = "GroundGrid"
local groundTex = groundGrid:FindFirstChildOfClass("Texture")
groundTex.Color3, groundTex.Transparency = Color3.fromRGB(30, 60, 100), 0.45
groundTex.StudsPerTileU, groundTex.StudsPerTileV = 64, 64
function S.groundGrid()
	local zone = ZONES:FindFirstChild("Grounds")
	if not S.building or S.grid <= 0 or not zone then groundGrid.Parent = nil return end
	if not groundGrid.Parent then
		local function e(v) return math.floor(v / 4 + 0.5) * 4 end
		local x0, x1 = e(zone.Position.X - zone.Size.X / 2), e(zone.Position.X + zone.Size.X / 2)
		local z0, z1 = e(zone.Position.Z - zone.Size.Z / 2), e(zone.Position.Z + zone.Size.Z / 2)
		groundGrid.Size = Vector3.new(x1 - x0, 0.05, z1 - z0)
		groundGrid.CFrame = CFrame.new((x0 + x1) / 2, Build.FY + 0.03, (z0 + z1) / 2)
		groundGrid.Parent = localFolder
	end
end

---------------------------------------------------------------- build camera

local cam = { focus = Vector3.new(0, Build.FY, 0), yaw = 0, pitch = math.rad(52), dist = 62 }
local goal = { focus = cam.focus, yaw = 0, pitch = cam.pitch, dist = cam.dist }
local BOUNDS = { -157, 157, -198, 58 } -- round 43: the whole lot (round 10e: reached the car park)
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
	local origin = r.Origin
	local cut -- round 33: a cut-away wall still takes the click when nothing solid is behind it, so built walls can be edited
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, r.Direction * 500, pickParams)
		if not hit then return cut end
		-- round 28: a wall that is cut away (or the thing in hand) doesn't take the click
		if hit.Instance.LocalTransparencyModifier < 0.5 then
			if deskModel and hit.Instance:IsDescendantOf(deskModel) then return deskModel end
			return Build.placedOf(hit.Instance)
		end
		if not cut and not (ghost and ghost.moving and hit.Instance:IsDescendantOf(ghost.moving)) then cut = Build.placedOf(hit.Instance) end
		origin = hit.Position + r.Direction * 0.05
	end
	return cut
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

local blockers = { btnWrap, barWrap, edWrap } -- + BuildKit's (below)
local function overGui(pos)
	pos = pos or padAim() or UIS:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	for _, o in ipairs(pgui:GetGuiObjectsAtPosition(pos.X, pos.Y - inset.Y)) do
		for _, root in ipairs(blockers) do
			if root.Visible and o ~= root and o:IsDescendantOf(root) then return true end
		end
	end
	return false
end

---------------------------------------------------------------- highlights

local hoverHL = UI.new("Highlight", {
	Name = "Hover", FillTransparency = 0.88, FillColor = Color3.new(1, 1, 1), OutlineColor = T.cream,
	DepthMode = Enum.HighlightDepthMode.Occluded, Enabled = false, Parent = pgui,
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

local function closeCard() if Kit then Kit.clear() end end

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

-- round 28: the space the thing takes, drawn flat on the floor under it, and a red outline on whatever is in the way
S.foot = Instance.new("Part")
S.foot.Name = "Footprint"
S.foot.Anchored = true; S.foot.CanCollide = false; S.foot.CanQuery = false; S.foot.CanTouch = false; S.foot.CastShadow = false
S.foot.Material = Enum.Material.Neon
S.foot.Transparency = 0.6
S.foot.Color = GOOD
S.blockHL = UI.new("Highlight", { Name = "Blocker", FillColor = BAD, OutlineColor = BAD, FillTransparency = 0.72, OutlineTransparency = 0,
	DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = pgui })

rebuildGhostModel = function()
	if not ghost then return end
	if ghost.model then ghost.model:Destroy() end
	local m = ghostify(Build.make(ghost.id, ghost.shown or CFrame.new(), ghostOpts()))
	m.Parent = localFolder
	ghost.model = m
	ghost.boxOff, ghost.boxSize = Build.box(ghost.id, ghostOpts().size)
	ghostHL.Adornee = m
	ghostHL.Enabled = true
	if ghost.target then ghost.validate() end
end

clearGhost = function()
	if S.roomMode and not S.keepRoom and S.closeBuilder then S.closeBuilder() return end
	if not ghost then return end
	if ghost.model then ghost.model:Destroy() end
	if ghost.moving and ghost.moving.Parent then setLocalHidden(ghost.moving, false) end
	ghost = nil
	ghostHL.Enabled = false
	tipGui.Enabled = false
	gridPlate.Parent = nil
	S.foot.Parent = nil
	S.blockHL.Enabled = false
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
	S.lockSpot = false
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
		Build.lastBlocker = nil
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
		ghostHL.FillTransparency = ok and 0.84 or 0.6
		S.foot.Color = col
		local blocker = (not ok and not S.roomMode) and Build.lastBlocker or nil
		S.blockHL.Adornee = blocker
		S.blockHL.Enabled = blocker ~= nil
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
		if S.roomMode then
			ghostHL.FillColor, ghostHL.OutlineColor, tipStroke.Color = GOOD, GOOD, GOOD
			tipText.Text = "Hold and drag to draw a room"
			tipText.TextColor3 = Color3.fromRGB(200, 255, 210)
		end
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
	if not ghost or ghost.locked then return end
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
		if S.stack ~= false and hit and hit.Normal.Y > 0.7 and Build.placedOf(hit.Instance) then
			-- stack onto the top of the thing under the cursor
			base = hit.Position.Y - Build.FY
			point = hit.Position
		else
			point = floorPoint(pos)
		end
		if not point then return end
		if ghost.off then point += ghost.off end
		local y = floorOnly and 0 or math.max(base + ghost.dy, 0)
		cf = Build.pivot(snap(point.X), y, snap(point.Z), ghost.yaw)
		if item and item.structure and S.wallSnap then
			local raw = Build.pivot(point.X, y, point.Z, ghost.yaw)
			local snapped = snapStructure(ghost.id, raw)
			if snapped ~= raw then cf = snapped end
		end
		if S.hug and S.hugWall and item and not item.structure and not item.shape and not item.flat and not floorOnly then
			cf = S.hugWall(ghost.id, cf)
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
	if S.roomMode then toast("Hold the mouse and drag to draw the room", "roomReady") return end
	if not ghost.ok then
		UI.pop(tipFrame, 1.25, 0.3)
		UI.shake(barBtns.place)
		toast(ghost.why or "Can't go here", "close", true)
		return
	end
	S.busy = true
	local g = ghost
	local cf = g.target
	local from = g.moving and g.moving:GetPivot()
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
		-- round 28: Undo puts a moved thing back
		if from and (from.Position - cf.Position).Magnitude + math.abs(Build.yawOf(from) - Build.yawOf(cf)) > 0.05 then
			table.insert(S.undo, { move = uid or "desk", cf = from, t = os.clock() })
			if #S.undo > 20 then table.remove(S.undo, 1) end
		end
		clearGhost()
		-- a resized shape is a fresh model with the same uid
		if uid and not m.Parent then m = findUid(uid) end
		landFX(m, cf)
	else
		local new = findUid(res)
		if Kit then Kit.placed(g.id) end
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
		if S.roomPlate then S.roomPlate.Parent = nil end
		if S.rbPreviewClear then S.rbPreviewClear() end
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
		if S.roomMode then D.from = floorPoint(nil, ghost.target.Position.Y) end
	end

	-- round 15: the Room Builder's room. The drag draws a rectangle of 4-stud wall units (2 to 12 a side) from the
	-- corner where it began, snapped onto the floor's edges and onto the ends of walls already there. Sides that
	-- already have a wall (the hotel's own, a starter room's or one you built) stay as they are and cost nothing.
	-- The door goes in the open piece nearest the middle of the side closest to the lobby; R moves it round.
	-- Every new piece is checked with Build.validate like any drag.
	local U, ROOM_MIN, ROOM_MAX = 4, 2, 12
	local function isPlainWall(id)
		local it = Catalog.ITEMS[id]
		return it and it.structure and not it.doorway and it.wallKind == "Wall"
	end
	S.isPlainWall = isPlainWall
	local roomPlate = Instance.new("Part")
	roomPlate.Name = "RoomPlate"
	roomPlate.Anchored, roomPlate.CanCollide, roomPlate.CanQuery, roomPlate.CanTouch, roomPlate.CastShadow = true, false, false, false, false
	roomPlate.Material = Enum.Material.Neon
	roomPlate.Transparency = 0.72
	roomPlate.Color = GOOD
	S.roomPlate = roomPlate
	-- is there a wall along this 4-stud piece already?
	local function sharedWall(cf)
		local f = {}
		for _, n in ipairs({ "Shell", "Rooms", "Placed" }) do
			local x = HOTEL:FindFirstChild(n)
			if x then table.insert(f, x) end
		end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = f
		local r = cf.RightVector
		-- round 33: 1.4 deep so walls just off the line (shell walls past the floor edge) are reused
		-- round 41: 2.2 deep (was 1.4): thick and skirted walls sit up to a stud off the line
		for _, p in ipairs(workspace:GetPartBoundsInBox(cf * CFrame.new(0, 4, 0), Vector3.new(2.4, 3, 2.2), params)) do
			local owner = Build.placedOf(p)
			if owner then
				local it = Catalog.ITEMS[owner:GetAttribute("Item") or ""]
				if it and it.structure and math.abs(owner:GetPivot().RightVector:Dot(r)) > 0.97 then return true end
			elseif p.CanCollide and p.Size.Y >= 6 then
				local pc = p.CFrame
				local along = math.abs(r:Dot(pc.RightVector)) * p.Size.X + math.abs(r:Dot(pc.UpVector)) * p.Size.Y + math.abs(r:Dot(pc.LookVector)) * p.Size.Z
				if along >= 2.4 then return true end
			end
		end
		return false
	end
	-- the first corner sits on a floor edge or a wall end when one is close, else on the 1-stud grid
	local function cornerSnap(p)
		local bx, bz, dx, dz = p.X, p.Z, 1.6, 1.6
		local function tryX(x) local d = math.abs(p.X - x) if d < dx then bx, dx = x, d end end
		local function tryZ(z) local d = math.abs(p.Z - z) if d < dz then bz, dz = z, d end end
		for _, z in ipairs(ZONES:GetChildren()) do
			if z:IsA("BasePart") and z.Name ~= "Parking" then
				local c, h = z.Position, z.Size / 2
				tryX(c.X - h.X) tryX(c.X + h.X) tryZ(c.Z - h.Z) tryZ(c.Z + h.Z)
			end
		end
		for _, m in ipairs(PLACED:GetChildren()) do
			local iid = m:GetAttribute("Item")
			local it = iid and Catalog.ITEMS[iid]
			if it and it.structure then
				local _, sz = Build.box(iid)
				local cf = m:GetPivot()
				for _, e in ipairs({ -1, 1 }) do
					local q = cf.Position + cf.RightVector * e * sz.X / 2
					if Vector2.new(q.X - p.X, q.Z - p.Z).Magnitude < 1.4 then tryX(q.X) tryZ(q.Z) end
				end
			end
		end
		-- round 41: and onto the line of any wall that runs past (placed walls, the shell, room partitions), so a new
		-- room starts flush with the walls already there and reuses them
		local function line(cx, cz, ex, ez)
			if ex > ez * 2 and ez < 3 then
				if p.X > cx - ex / 2 - 2 and p.X < cx + ex / 2 + 2 then tryZ(cz) end
			elseif ez > ex * 2 and ex < 3 then
				if p.Z > cz - ez / 2 - 2 and p.Z < cz + ez / 2 + 2 then tryX(cx) end
			end
		end
		for _, m in ipairs(PLACED:GetChildren()) do
			local iid = m:GetAttribute("Item")
			local it = iid and Catalog.ITEMS[iid]
			if it and it.structure then
				local _, sz = Build.box(iid)
				local cf = m:GetPivot()
				local rx = math.abs(cf.RightVector.X)
				line(cf.X, cf.Z, rx * sz.X + (1 - rx) * 1, (1 - rx) * sz.X + rx * 1)
			end
		end
		for _, n in ipairs({ "Shell", "Rooms" }) do
			local f = HOTEL:FindFirstChild(n)
			for _, q in ipairs(f and f:GetDescendants() or {}) do
				if q:IsA("BasePart") and q.CanCollide and q.Size.Y >= 6 then
					local c = q.CFrame
					local ex = math.abs(c.RightVector.X) * q.Size.X + math.abs(c.LookVector.X) * q.Size.Z
					local ez = math.abs(c.RightVector.Z) * q.Size.X + math.abs(c.LookVector.Z) * q.Size.Z
					line(c.X, c.Z, ex, ez)
				end
			end
		end
		if dx >= 1.6 then bx = math.floor(p.X + 0.5) end
		if dz >= 1.6 then bz = math.floor(p.Z + 0.5) end
		return Vector3.new(bx, p.Y, bz)
	end
	local function roomRect()
		local cur = D.devCur or floorPoint(nil, D.start.Position.Y)
		if not cur then return nil end
		if not D.corner then D.corner = cornerSnap(D.from or D.start.Position) end
		local p0 = D.corner
		local d = cur - p0
		local nx = math.clamp(math.floor(math.abs(d.X) / U + 0.5), ROOM_MIN, ROOM_MAX)
		local nz = math.clamp(math.floor(math.abs(d.Z) / U + 0.5), ROOM_MIN, ROOM_MAX)
		local sx, sz = d.X >= 0 and 1 or -1, d.Z >= 0 and 1 or -1
		local x0, z0 = p0.X, p0.Z
		local x1, z1 = x0 + sx * nx * U, z0 + sz * nz * U
		local y = p0.Y - Build.FY
		-- every piece round the edge by side: 0 = the first row, 1 = the far column, 2 = the far row, 3 = the first column
		local segs = { [0] = {}, [1] = {}, [2] = {}, [3] = {} }
		for i = 1, nx do
			local x = x0 + sx * (i - 0.5) * U
			table.insert(segs[0], { x = x, z = z0, yaw = 0, door = sz > 0 and 180 or 0 })
			table.insert(segs[2], { x = x, z = z1, yaw = 0, door = sz > 0 and 0 or 180 })
		end
		for j = 1, nz do
			local z = z0 + sz * (j - 0.5) * U
			table.insert(segs[3], { x = x0, z = z, yaw = 90, door = sx > 0 and 270 or 90 })
			table.insert(segs[1], { x = x1, z = z, yaw = 90, door = sx > 0 and 90 or 270 })
		end
		local shapeKey = nx .. ":" .. nz .. ":" .. sx .. ":" .. sz
		if D.shapeKey ~= shapeKey then
			D.shapeKey = shapeKey
			D.shared = {}
			for s = 0, 3 do
				for i, g in ipairs(segs[s]) do
					D.shared[s .. ":" .. i] = sharedWall(Build.pivot(g.x, y, g.z, g.yaw))
				end
			end
		end
		local function doorOn(s)
			local best, bestD
			local mid = (#segs[s] + 1) / 2
			for i in ipairs(segs[s]) do
				if not D.shared[s .. ":" .. i] and (not bestD or math.abs(i - mid) < bestD) then best, bestD = i, math.abs(i - mid) end
			end
			return best
		end
		local side
		if D.doorSide ~= nil then
			for k = 0, 3 do
				local s = (D.doorSide + k) % 4
				if doorOn(s) then side = s break end
			end
		else
			-- the side nearest the lobby
			local seed = O + Vector3.new(0, 0, 20)
			local bestD
			for s = 0, 3 do
				local i = doorOn(s)
				if i then
					local g = segs[s][i]
					local dd = Vector2.new(g.x - seed.X, g.z - seed.Z).Magnitude
					if not bestD or dd < bestD then side, bestD = s, dd end
				end
			end
		end
		D.side = side
		local di = side and doorOn(side)
		local list, ids, shared = {}, {}, 0
		local doorCF
		for s = 0, 3 do
			for i, g in ipairs(segs[s]) do
				if D.shared[s .. ":" .. i] then
					shared += 1
				else
					local isDoor = s == side and i == di
					local cf = Build.pivot(g.x, y, g.z, isDoor and g.door or g.yaw)
					if isDoor then doorCF = cf end
					table.insert(list, cf)
					table.insert(ids, isDoor and S.rb.door or D.id)
				end
			end
		end
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		local hx, hz = nx * U / 2, nz * U / 2
		D.room = { w = nx * U, d = nz * U, nx = nx, nz = nz, shared = shared }
		D.rect = {
			cx = cx, cz = cz, y = y, side = side, door = doorCF,
			sides = {
				[0] = { c = Vector3.new(cx, 0, z0), n = Vector3.new(0, 0, sz), t = Vector3.new(1, 0, 0), L = hx },
				[2] = { c = Vector3.new(cx, 0, z1), n = Vector3.new(0, 0, -sz), t = Vector3.new(1, 0, 0), L = hx },
				[3] = { c = Vector3.new(x0, 0, cz), n = Vector3.new(sx, 0, 0), t = Vector3.new(0, 0, 1), L = hz },
				[1] = { c = Vector3.new(x1, 0, cz), n = Vector3.new(-sx, 0, 0), t = Vector3.new(0, 0, 1), L = hz },
			},
		}
		roomPlate.Size = Vector3.new(nx * U - 0.8, 0.1, nz * U - 0.8)
		roomPlate.CFrame = CFrame.new(cx, p0.Y + 0.07, cz)
		return list, ids
	end
	function S.toggleRoom()
		if not S.building then return end
		if S.roomMode then S.closeBuilder() else S.openBuilder() end
	end
	function S.refreshRoomBtn()
		barBtns.room.Visible = false -- the Room Builder lives on the tool rail now
		if S.roomMode then
			setHints(hintsFor(HINTS_ROOM))
		end
	end
	-- R while drawing a room moves its door round to the next side
	function S.roomCycle()
		if not (D and D.active and D.ids) then return false end
		D.doorSide = ((D.side or 0) + 1) % 4
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
		-- the button is tracked from the input events (IsMouseButtonPressed can miss a press the window didn't see)
		if not input.clickDown or not ghost or ghost.id ~= D.id or ghost.moving then
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
		if ids and S.roomPlate then S.roomPlate.Parent = localFolder end
		if list and #list == 0 then
			trim(1)
			D.list, D.oks, D.count, D.total, D.why, D.key = list, {}, 0, 0, "Those walls are already there", nil
			D.tipAt = Vector3.new(D.rect.cx, Build.FY + 16, D.rect.cz)
		elseif list then
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
				if ids and D.rect then
					D.tipAt = Vector3.new(D.rect.cx, Build.FY + 16, D.rect.cz)
					D.fit = S.rbPreview and S.rbPreview(D.rect) or nil
				end
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
				local hasDoor = D.rect and D.rect.door ~= nil
				local all = D.count == #D.list and #D.list > 0 and hasDoor
				ok = all
				tipStroke.Color = ok and GOOD or BAD
				tipText.TextColor3 = ok and Color3.fromRGB(200, 255, 210) or Color3.fromRGB(255, 180, 170)
				if S.roomPlate then S.roomPlate.Color = ok and GOOD or BAD end
				local kit = S.rbKitCost and S.rbKitCost() or 0
				local fit = D.fit
				local fitText = ""
				if fit and fit.total > 0 then
					fitText = fit.count == fit.total and "   All furniture fits"
						or ("   " .. fit.count .. " of " .. fit.total .. " pieces fit, try " .. (S.rbKitBest() or "bigger"))
				end
				tipText.Text = all and ((S.rbKitName and S.rbKitName() or "Room") .. "  " .. D.room.w .. " x " .. D.room.d .. "   $" .. commas(D.total + kit)
					.. (D.room.shared > 0 and ("   " .. D.room.shared .. " walls already there") or "") .. fitText .. "   R moves the door")
					or (not hasDoor and "No free wall for the door" or D.why or "The room doesn't fit here")
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
			if d.count ~= #d.list or #d.list == 0 or not (d.rect and d.rect.door) then
				finish()
				toast((d.rect and not d.rect.door) and "No free wall for the door" or d.why or "The room doesn't fit there", "close", true)
				return true
			end
			d.rect.kit, d.rect.furnish = S.rb.kit, S.rb.furnish
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
				local entry = { uids = all, t = os.clock() }
				table.insert(S.undo, entry)
				if #S.undo > 20 then table.remove(S.undo, 1) end
				for i, uid in ipairs(all) do
					task.delay(0.03 * (i - 1), function()
						local m = findUid(uid)
						if m then landFX(m, m:GetPivot()) end
					end)
				end
				if why then
					toast(why, "close", true)
				else
					toast("Walls up: " .. d.room.w .. " x " .. d.room.d .. ((d.rect.furnish and S.rbKitCost and S.rbKitCost() > 0) and ". Furnishing..." or ""), "roomReady")
					if S.furnish then task.spawn(S.furnish, d.rect, entry) end
				end
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
	-- Studio only: draw a room without the mouse, for playtest probes (simulated drags can miss the window).
	-- PlayerScripts.BuildDev:Invoke("room", fromV3, toV3) -> the tip text while drawn, whether it was built.
	if RunService:IsStudio() then
		local bf = Instance.new("BindableFunction")
		bf.Name = "BuildDev"
		bf.OnInvoke = function(action, a, b)
			if action ~= "room" then return "unknown action" end
			if not S.building then return "not in build mode" end
			if not S.roomMode then S.openBuilder() end
			task.wait(0.2)
			if not ghost then return "no ghost" end
			D = { id = ghost.id, start = Build.pivot(a.X, 0, a.Z, 0), down = Vector2.new(-1e4, -1e4), from = Vector3.new(a.X, Build.FY, a.Z), devCur = Vector3.new(b.X, Build.FY, b.Z) }
			input.clickDown = Vector2.zero
			task.wait(0.4)
			local tip = tipText.Text
			input.clickDown = nil
			return tip, S.dragEnd()
		end
		bf.Parent = script.Parent
	end
end

---------------------------------------------------------------- the Room Builder (round 15)
-- F, or the gold button on the tool rail, opens it. Pick what the room is for (Guest Room, Deluxe Room, Suite,
-- Staff Room or just walls), a wall and a door, then drag on the floor: the walls go up all round with the door on
-- the side nearest the lobby, and once the server has made it a room (Rooms.scan) its furniture is placed for you:
-- the bed against the far wall, the bathroom by the door, lamps and plants in the corners, a rug in the middle.
-- Undo takes the whole room back, furniture and all.
do
	local RB = S.rb
	local RoomPlan = require(Shared:WaitForChild("RoomPlan"))
	-- round 32: no presets, the Room Builder only puts up walls and a door (the old kits stay below, unused)
	local KITS = {
		{ id = "guest", name = "Guest Room", icon = "bed", color = T.blue, best = "4 x 4",
			items = { { "bed", { "Bed" } }, { "bath", { "Shower" } }, { "bath", { "Toilet" } }, { "night", { "Nightstand" } }, { "corner", { "FloorLamp" } }, { "center", { "Rug" } } } },
		{ id = "deluxe", name = "Deluxe Room", icon = "roomDeluxe", color = T.orange, best = "5 x 4",
			items = { { "bed", { "BedDeluxe", "Bed" } }, { "bath", { "ShowerRain", "Shower" } }, { "bath", { "ToiletDeluxe", "Toilet" } }, { "night", { "Nightstand" } }, { "night", { "Nightstand" } },
				{ "corner", { "Wardrobe" } }, { "corner", { "FloorLamp" } }, { "corner", { "Plant" } }, { "center", { "Rug" } } } },
		{ id = "suite", name = "Suite", icon = "roomSuite", color = T.violet, best = "6 x 5",
			items = { { "bed", { "BedSuite", "BedCanopy", "BedDeluxe", "Bed" } }, { "bath", { "ShowerRain", "Shower" } }, { "bath", { "ToiletDeluxe", "Toilet" } }, { "night", { "Nightstand" } }, { "night", { "Nightstand" } },
				{ "side", { "TVStand" } }, { "side", { "Sofa", "Armchair" } }, { "corner", { "Wardrobe" } }, { "corner", { "ArcLamp", "FloorLamp" } }, { "corner", { "IndoorPalm", "Plant" } }, { "center", { "Rug" } } } },
		{ id = "staff", name = "Staff Room", icon = "staff", color = T.green, best = "4 x 4",
			items = { { "side", { "StaffLocker" } }, { "center", { "StaffTable" } }, { "corner", { "CoffeeBar", "WaterCooler" } }, { "corner", { "Plant" } } } },
	}
	KITS = { { id = "empty", name = "Just Walls", icon = "hammer", color = Color3.fromRGB(177, 185, 196), items = {} } }
	local WALLS = { "Wall", "WallSage", "WallBrick", "WallWood", "WallWindow", "WallWindowBrick", "WallGlass" }
	local DOORS = { "RoomDoor", "RoomDoorModern", "RoomDoorSuite", "DoorWhite", "Door", "DoorGlass" }

	local function pick(opts)
		for _, id in ipairs(opts) do
			if Catalog.ITEMS[id] and ITEMS:FindFirstChild(id) and unlocked(id) then return id end
		end
		return nil
	end
	local function kitOf(id)
		for _, k in ipairs(KITS) do if k.id == id then return k end end
		return KITS[1]
	end
	local function kitCost(k)
		local n = 0
		for _, s in ipairs(k.items) do
			local id = pick(s[2])
			if id then n += itemPrice(id) end
		end
		return n
	end
	S.rbKitCost = function() return RB.furnish and kitCost(kitOf(RB.kit)) or 0 end
	S.rbKitName = function() return kitOf(RB.kit).name end

	S.rbKitBest = function() return kitOf(RB.kit).best end

	-- the kit's pieces as RoomPlan slots ({role, id}); id is nil when nothing in that slot is unlocked yet
	local function kitSlots(k)
		local slots = {}
		for i, slot in ipairs(k.items) do slots[i] = { slot[1], pick(slot[2]) } end
		return slots
	end

	-- the live preview while a room is dragged out: the kit, laid out by RoomPlan, as see-through furniture
	local prev = Instance.new("Model")
	prev.Name = "RoomPreview"
	local prevHL = Instance.new("Highlight")
	prevHL.FillColor = Color3.fromRGB(255, 255, 255)
	prevHL.FillTransparency = 0.8
	prevHL.OutlineColor = Color3.fromRGB(255, 244, 214)
	prevHL.OutlineTransparency = 0.25
	prevHL.DepthMode = Enum.HighlightDepthMode.Occluded
	prevHL.Adornee = prev
	prevHL.Parent = prev
	local prevPool = {}
	function S.rbPreview(rect)
		local k = kitOf(RB.kit)
		if not RB.furnish or #k.items == 0 or not rect or not rect.door then
			S.rbPreviewClear()
			return nil
		end
		local slots = kitSlots(k)
		local B = RoomPlan.interior(HOTEL, rect)
		local res = RoomPlan.plan(slots, rect, B, RoomPlan.obstacles(HOTEL, B))
		for i, s in ipairs(slots) do
			local sp, id = res.spots[i], s[2]
			local m = prevPool[i]
			if m and (not sp or m:GetAttribute("Id") ~= id) then
				m:Destroy()
				m, prevPool[i] = nil, nil
			end
			if sp and id then
				if not m then
					m = ghostify(Build.make(id, CFrame.new(), {}))
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then d.Transparency = math.max(d.Transparency, 0.45) end
					end
					m:SetAttribute("Id", id)
					m.Parent = prev
					prevPool[i] = m
				end
				m:PivotTo(RoomPlan.pivot(id, sp, rect.y) * CFrame.new(0, 0.04, 0))
			end
		end
		for i, m in pairs(prevPool) do
			if i > #slots then
				m:Destroy()
				prevPool[i] = nil
			end
		end
		prev.Parent = localFolder
		return res
	end
	function S.rbPreviewClear()
		prev.Parent = nil
	end

	-- after the walls are up: wait for the room to exist, then place the planned kit one piece at a time. A piece
	-- whose planned spot turns out blocked tries the planner's next best spots for it.
	function S.furnish(rect, entry)
		local k = kitOf(rect.kit)
		if not rect.furnish or #k.items == 0 then return end
		local center = Vector3.new(rect.cx, Build.FY + 0.5, rect.cz)
		local zone
		local t0 = os.clock()
		while os.clock() - t0 < 8 do
			task.wait(0.3)
			local z = Build.zoneAt(center)
			if z and z.Name ~= "Lobby" then zone = z break end
		end
		if not zone then
			toast("The door has to open onto the lobby before the room can be furnished", "door", true)
			return
		end
		local slots = kitSlots(k)
		local B = RoomPlan.interior(HOTEL, rect)
		local res = RoomPlan.plan(slots, rect, B, RoomPlan.obstacles(HOTEL, B))
		local done, missed, poor = 0, 0, false
		local blocked = {}
		for i, s in ipairs(slots) do
			local id = s[2]
			if id then
				local put = false
				if cash() < itemPrice(id) then
					poor = true
				else
					local tries = res.spots[i] and { res.spots[i] } or {}
					local alts = false
					local n = 0
					while n < 16 do
						n += 1
						if not tries[n] and not alts then
							alts = true
							for _, a in ipairs(res.alt(i, blocked)) do table.insert(tries, a) end
						end
						local sp = tries[n]
						if not sp then break end
						local cf = RoomPlan.pivot(id, sp, rect.y)
						local ok, _, z = Build.validate(id, cf, nil, {})
						if ok and z and z.Name == zone.Name then
							local ok2, uid = Remote:InvokeServer("place", id, cf)
							if ok2 then
								put = true
								res.spots[i] = sp
								table.insert(entry.uids, 1, uid) -- undo sells the furniture before the walls
								entry.t = os.clock()
								local t1, m = os.clock(), nil
								repeat
									task.wait(0.05)
									m = findUid(uid)
								until m or os.clock() - t1 > 2
								if m then landFX(m, m:GetPivot()) end
								task.wait(0.08)
								break
							end
						end
						table.insert(blocked, { x = sp.x, z = sp.z, hx = sp.hx * 0.6, hz = sp.hz * 0.6, flat = sp.flat, gap = 0 })
					end
					if not put then res.spots[i] = nil end
				end
				if put then done += 1 else missed += 1 end
			end
		end
		if poor then
			toast(k.name .. ": ran out of cash for some furniture", "cash", true)
		elseif missed > 0 then
			toast(k.name .. " furnished. " .. missed .. (missed == 1 and " piece didn't" or " pieces didn't") .. " fit, try " .. (k.best or "a bigger room"), "roomReady", true)
		else
			toast(k.name .. " ready! " .. done .. " pieces placed", "roomReady")
		end
	end

	---------------------------------------------------------------- the panel (right)

	local wrap = wrapper("RoomBuilder", UDim2.fromOffset(330, 372), UDim2.new(1, -18, 0, 84), Vector2.new(1, 0))
	wrap.Visible = false
	local holder, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), {
		name = "Builder", radius = 20, title = "Room Builder", subtitle = "Drag on the floor to build", icon = ICON.roomReady,
		onClose = function() S.closeBuilder() end,
	})
	local content = UI.new("Frame", { Name = "Content", Size = UDim2.new(1, -28, 1, -84), Position = UDim2.fromOffset(14, 76), BackgroundTransparency = 1, Parent = body })
	UI.list(content, nil, 6)
	local function section(text, order)
		UI.label(content, text, 13, { FontFace = UI.F.display, TextColor3 = T.muted, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 16) })
	end
	local typeRows = {}
	for i, k in ipairs(KITS) do
		local b = UI.new("TextButton", { Name = "Kit_" .. k.id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = T.ink2, LayoutOrder = 1 + i, Visible = false, Parent = content })
		UI.corner(b, 14)
		local rim = UI.rim(b, T.line, 2)
		UI.badge(b, 38, k.color, ICON[k.icon] or ICON.roomReady, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		UI.label(b, k.name, 16, { FontFace = UI.F.display, Position = UDim2.fromOffset(54, 4), Size = UDim2.new(1, -130, 0, 20) })
		local sub = UI.label(b, "", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(54, 25), Size = UDim2.new(1, -62, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
		local price = UI.label(b, "", 14, { FontFace = UI.F.display, TextColor3 = T.greenDk, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -10, 0, 8), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(76, 18) })
		local check = UI.badge(b, 22, T.brand, ICON.checkmark, { Position = UDim2.new(1, -8, 0, 7), AnchorPoint = Vector2.new(1, 0), Visible = false })
		b.MouseEnter:Connect(function()
			UI.sound("Hover")
			UI.tween(b, 0.15, { BackgroundColor3 = T.ink3 })
		end)
		b.MouseLeave:Connect(function() UI.tween(b, 0.15, { BackgroundColor3 = RB.kit == k.id and T.brandSoft or T.ink2 }) end)
		b.Activated:Connect(function()
			RB.kit = k.id
			UI.sound("Tick")
			UI.pop(b, 0.95, 0.25)
			S.rbRefresh()
		end)
		typeRows[k.id] = { b = b, rim = rim, sub = sub, price = price, check = check }
	end

	local tiles = {}
	local function tileRow(order, ids, field)
		local sc = UI.new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, LayoutOrder = order, ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollBarThickness = 4, ScrollBarImageColor3 = T.brand, Parent = content,
		})
		UI.list(sc, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Top)
		UI.pad(sc, 2, 3, 2, 6)
		for i, id in ipairs(ids) do
			local it = Catalog.ITEMS[id]
			if it and ITEMS:FindFirstChild(id) then
				local b = UI.new("TextButton", { Name = id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(64, 70), BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = sc })
				UI.corner(b, 12)
				local rim = UI.rim(b, T.line, 2)
				local well = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 46), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = T.white, Parent = b })
				UI.corner(well, 9)
				UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(248, 246, 255), Color3.fromRGB(229, 233, 240)), Parent = well })
				local vf = thumb(well, id)
				vf.Size = UDim2.fromScale(1, 1)
				UI.label(b, "$" .. commas(itemPrice(id)), 12, { FontFace = UI.F.display, TextColor3 = T.greenDk, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 14) })
				local lock = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.nightDk, BackgroundTransparency = 0.35, ZIndex = 4, Visible = false, Parent = b })
				UI.corner(lock, 12)
				UI.icon(lock, ICON.lock, 24, { Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
				UI.tooltip(b, it.name)
				b.Activated:Connect(function()
					if not unlocked(id) then
						UI.shake(b)
						local why = lockOf(id) == "level" and ("unlocks at hotel level " .. Levels.itemLevel(id))
							or ("needs research: " .. (it.research and Research.BY_ID[it.research] and Research.BY_ID[it.research].name or "?"))
						toast("The " .. string.lower(it.name) .. " " .. why, "lock", true)
						return
					end
					UI.sound("Tick")
					UI.pop(b, 0.9, 0.25)
					RB[field] = id
					if field == "wall" and S.roomMode then S.rbGhost() end
					S.rbRefresh()
				end)
				tiles[id] = { b = b, rim = rim, lock = lock, field = field }
			end
		end
	end
	section("WALLS", 10)
	tileRow(11, WALLS, "wall")
	section("DOOR", 12)
	tileRow(13, DOORS, "door")

	local fRow = UI.new("Frame", { Name = "Furnish", Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.ink2, LayoutOrder = 20, Visible = false, Parent = content })
	UI.corner(fRow, 14)
	UI.rim(fRow, T.line, 2)
	UI.label(fRow, "Furnish it for me", 16, { FontFace = UI.F.display, Position = UDim2.fromOffset(14, 7), Size = UDim2.new(1, -90, 0, 20) })
	UI.label(fRow, "Places the room's furniture too", 12, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -90, 0, 16) })
	UI.toggle(fRow, RB.furnish, function(on)
		RB.furnish = on
		S.rbRefresh()
	end, { pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5) })
	local totalLbl = UI.label(content, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextWrapped = true, LayoutOrder = 21, Size = UDim2.new(1, 0, 0, 34) })

	function S.rbRefresh()
		for _, k in ipairs(KITS) do
			local r = typeRows[k.id]
			local on = RB.kit == k.id
			r.check.Visible = on
			r.price.Visible = not on
			r.rim.Color = on and T.brand or T.line
			r.rim.Thickness = on and 3 or 2
			r.b.BackgroundColor3 = on and T.brandSoft or T.ink2
			local n = 0
			for _, s in ipairs(k.items) do if pick(s[2]) then n += 1 end end
			r.sub.Text = #k.items == 0 and "Walls and a door" or (n .. " pieces" .. (k.best and (", " .. k.best .. " or bigger") or ""))
			r.price.Text = #k.items == 0 and "" or ("+$" .. commas(kitCost(k)))
		end
		for id, t in pairs(tiles) do
			local on = RB[t.field] == id
			t.rim.Color = on and T.brand or T.line
			t.rim.Thickness = on and 3 or 2
			t.b.BackgroundColor3 = on and T.brandSoft or T.ink2
			t.lock.Visible = not unlocked(id)
		end
		local k = kitOf(RB.kit)
		totalLbl.Text = "Walls $" .. commas(itemPrice(RB.wall)) .. " a piece, door $" .. commas(itemPrice(RB.door))
			.. ((RB.furnish and #k.items > 0) and (", furniture $" .. commas(kitCost(k))) or "") .. ". Walls already there are free."
	end

	-- a wall ghost marks the corner under the cursor while the builder is open
	function S.rbGhost()
		S.keepRoom = true
		startPlacing(RB.wall)
		S.keepRoom = false
		barWrap.Visible = false
		setHints(hintsFor(HINTS_ROOM))
	end
	function S.openBuilder()
		if TOUCH then
			toast("The Room Builder needs a mouse for now: place walls and a door from the drawer", "roomReady", true)
			return
		end
		if not S.building or S.roomMode then return end
		if not unlocked(RB.wall) then RB.wall = "Wall" end
		if not unlocked(RB.door) then RB.door = unlocked("RoomDoor") and "RoomDoor" or "Door" end
		closeCard()
		S.roomMode = true
		S.rbGhost()
		S.rbRefresh()
		wrap.Visible = true
		holder.Position = UDim2.new(0.5, 380, 0.5, 0)
		UI.tween(holder, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
		UI.stagger(content, 0.025)
		UI.tween(Kit.shopHolder, 0.3, { Position = UDim2.new(0.5, 460, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.3, function() if S.roomMode then Kit.shopWrap.Visible = false end end)
		if S.toolsRefresh then S.toolsRefresh() end
		UI.sound("Open")
	end
	function S.closeBuilder()
		if not S.roomMode then return end
		S.roomMode = false
		clearGhost()
		UI.tween(holder, 0.25, { Position = UDim2.new(0.5, 380, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			if not S.roomMode then wrap.Visible = false end
		end)
		if S.building then
			Kit.shopWrap.Visible = true
			Kit.shopHolder.Position = UDim2.new(0.5, 460, 0.5, 0)
			UI.tween(Kit.shopHolder, 0.5, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
		end
		if S.toolsRefresh then S.toolsRefresh() end
		if Kit then Kit.applyHints() end
		setHints(hintsFor(ghost and HINTS_GHOST or HINTS_IDLE))
		UI.sound("Close")
	end
	player:GetAttributeChangedSignal("Cash"):Connect(function() if S.roomMode then S.rbRefresh() end end)
end

-- undo: sell the newest thing you placed that's still there (full price back within a minute)
function S.doUndo()
	if S.busy then return end
	while #S.undo > 0 do
		local u = table.remove(S.undo)
		if u.moves then
			-- round 42: a group moved, turned or nudged goes back together
			local live = {}
			for _, mv in ipairs(u.moves) do
				if findUid(mv[1]) then table.insert(live, mv) end
			end
			if #live == 0 then continue end
			closeCard()
			S.busy = true
			local ok, done, why = Remote:InvokeServer("moveMany", live)
			S.busy = false
			if ok then
				UI.sound("Turn")
				toast("Moved back", "rotate")
			else
				toast(done or why or "Can't move them back", "close", true)
			end
			return
		end
		if u.rebuy then
			-- round 42: things sold with Delete are bought back where they stood
			if #u.rebuy == 0 then continue end
			S.busy = true
			local ok, done, why = Remote:InvokeServer("placeBatch", u.rebuy)
			S.busy = false
			if ok then
				UI.sound("Place")
				toast("Bought back " .. #done .. (#done == 1 and " thing" or " things"), "rotate")
			else
				toast(done or why or "Can't buy that back", "close", true)
			end
			return
		end
		if u.move then
			local ok, why
			if u.move == "desk" then
				S.busy = true
				ok, why = Remote:InvokeServer("desk", u.cf)
			elseif findUid(u.move) then
				if selected then closeCard() end
				S.busy = true
				ok, why = Remote:InvokeServer("move", u.move, u.cf)
			else
				continue -- it was sold since
			end
			S.busy = false
			if ok then
				UI.sound("Turn")
				toast("Moved back", "rotate")
			else
				toast(why or "Can't move it back", "close", true)
			end
			return
		end
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
	if cur and cur ~= m then
		if Kit then Kit.replace(m, cur) end
		if ED.target == m then ED.target = cur end
	end
	if cur then
		local o2 = Build.optsOf(cur)
		S.shape.size, S.shape.color, S.shape.mat, S.shape.ghost = o2.size, o2.color, o2.mat, o2.ghost or false
		ED.sync()
	end
end

---------------------------------------------------------------- BuildKit (round 42)

Kit = require(Shared:WaitForChild("BuildKit"))({
	S = S, HOTEL = HOTEL, PLACED = PLACED, Remote = Remote, gui = gui, desk = deskModel, ED = ED,
	HINTS_IDLE = not TOUCH and HINTS_IDLE or nil,
	toast = toast, wrapper = wrapper, kOf = kOf, layout = layout, cash = cash, itemPrice = itemPrice, lockOf = lockOf,
	setHints = function(set) setHints(hintsFor(set)) end,
	startPlacing = function(id) startPlacing(id) end,
	buyRoom = function(id) buyRoom(id) end,
	ghost = function() return ghost end,
	makeGhost = function(id, moving) makeGhost(id, moving) end,
	clearGhost = function() clearGhost() end,
	turnGhost = function(dir) turnGhost(dir) end,
	raiseGhost = function(dir) raiseGhost(dir) end,
	reaim = function() if ghost and ghost.validate then ghost.validate() end end,
	floorPoint = function() return floorPoint() end,
	placedAt = function(pos) return placedAt(pos) end,
	setSelected = function(m) selected = m end,
	thumb = thumb,
})
table.insert(blockers, Kit.shopWrap)
for _, w in ipairs(Kit.blockers) do table.insert(blockers, w) end

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
	Kit.shopWrap.Visible = true
	slideIn(Kit.shopHolder, Vector2.new(460, 0))
	Kit.show(true)
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
	input.mode, input.downOn, S.pan = nil, nil, nil
	S.cutRestore()
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
	slideOut(Kit.shopWrap, Kit.shopHolder, Vector2.new(460, 0))
	Kit.show(false)
	hintWrap.Visible = false
	setBuildButton(false)
	layout()
	UI.sound("Close")
	table.clear(held)
	if Kit.search:IsFocused() then Kit.search:ReleaseFocus() end
end

toggle = function()
	if S.building then leave() elseif not UI.locked("build") then enter() end
end

---------------------------------------------------------------- input

local function worldClick(pos)
	-- round 42: the active tool takes the click (select, delete, paint, pick, drop a group); else place what's in hand
	if Kit.worldClick(pos) then return end
	if ghost then commit() end
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
			if ghost then clearGhost() elseif Kit.cancel() then return Enum.ContextActionResult.Sink elseif selected then closeCard() elseif not UI.closeTopmost() then toggle() end
		elseif kc == Enum.KeyCode.ButtonX then
			if ghost then turnGhost(1) elseif selected then Kit.act.turn() end
		elseif kc == Enum.KeyCode.ButtonY then
			if selected then Kit.act.move() else UI.padSelect(Kit.list) end
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
		-- round 42: tools (1-6), nudging (arrows) and the selection's keys come first
		local used = Kit.key(io.KeyCode)
		if PAN_KEYS[io.KeyCode] and not used then held[io.KeyCode] = true end
		if used then
			-- done
		elseif io.KeyCode == Enum.KeyCode.R and S.roomCycle and S.roomCycle() then
			-- the room's door moved round
		elseif io.KeyCode == Enum.KeyCode.F and S.toggleRoom then
			S.toggleRoom()
		elseif io.KeyCode == Enum.KeyCode.R then
			if ghost then turnGhost(shift and -1 or 1) end
		elseif io.KeyCode == Enum.KeyCode.T or io.KeyCode == Enum.KeyCode.PageUp then raiseGhost(1)
		elseif io.KeyCode == Enum.KeyCode.G or io.KeyCode == Enum.KeyCode.PageDown then raiseGhost(-1)
		elseif io.KeyCode == Enum.KeyCode.Z then S.doUndo()
		elseif io.KeyCode == Enum.KeyCode.X or io.KeyCode == Enum.KeyCode.Backspace or io.KeyCode == Enum.KeyCode.Escape then
			if ghost then clearGhost() elseif not Kit.cancel() then closeCard() end
		end
	elseif io.UserInputType == Enum.UserInputType.MouseButton1 then
		if gp or overGui() then return end
		input.clickDown = UIS:GetMouseLocation()
		-- round 28: a press on an item can turn into dragging it, a press on the floor into panning
		input.mode = nil
		input.downOn = (not ghost and not TOUCH) and placedAt() or nil
		if S.building then S.dragBegin() end
	elseif io.UserInputType == Enum.UserInputType.MouseButton2 then
		input.rightDown, input.rightMoved = true, 0
		input.rightLast = UIS:GetMouseLocation()
	elseif io.UserInputType == Enum.UserInputType.MouseButton3 then
		if gp or overGui() then return end
		S.pan = { anchor = floorPoint(), mid = true }
	end
end)

-- round 28: direct handling. Hold the left button on an item and drag: it comes with the cursor and drops where
-- you let go (back where it was if it doesn't fit). Hold it on the floor and drag: the view pans, the floor
-- staying under the cursor. The middle button pans any time, also with something in hand.
function S.beginDrag()
	if Kit.dragBegin(input.clickDown) then input.mode = "kit" return end
	local m = input.downOn
	if Kit.tool ~= "select" or Kit.groupActive() then m = nil end -- only the Select tool picks things up
	if m and m.Parent and Kit.grab(m, floorPoint(input.clickDown)) then
		input.mode = "group"
		return
	end
	if m and m.Parent then
		input.mode = "grab"
		local r = m ~= deskModel and m:GetAttribute("Room") and HOTEL.Rooms:FindFirstChild(m:GetAttribute("Room"))
		if r and r:GetAttribute("State") == "Booked" then
			input.mode = "none"
			toast("A guest is using this room", "guest", true)
			return
		end
		local pv = m:GetPivot().Position
		local fp = floorPoint(input.clickDown)
		makeGhost(m == deskModel and "Desk" or m:GetAttribute("Item"), m)
		if ghost then
			ghost.grab = true
			if fp then ghost.off = Vector3.new(pv.X - fp.X, 0, pv.Z - fp.Z) end
		end
		UI.sound("Click")
	else
		input.mode = "pan"
		S.pan = { anchor = floorPoint(input.clickDown) }
	end
end

UIS.WindowFocusReleased:Connect(function()
	input.clickDown = nil
	S.pan = nil
	if input.mode == "grab" and ghost and ghost.grab then clearGhost() end
	if input.mode == "kit" or input.mode == "group" then Kit.cancel() end
	input.mode, input.downOn = nil, nil
end)
UIS.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton3 then
		if S.pan and S.pan.mid then S.pan = nil end
		return
	end
	if io.UserInputType == Enum.UserInputType.MouseButton1 and input.mode then
		local mode = input.mode
		input.mode, input.downOn, input.clickDown = nil, nil, nil
		if mode == "pan" then
			S.pan = nil
		elseif mode == "kit" then
			Kit.dragEnd()
		elseif mode == "group" then
			Kit.groupRelease()
		elseif mode == "grab" and ghost and ghost.grab then
			if ghost.ok and ghost.target then
				commit()
			else
				toast(ghost.why or "Can't go here", "close", true)
			end
			if ghost and ghost.grab then clearGhost() end -- it didn't fit: back where it was
		end
		return
	end
	if io.UserInputType == Enum.UserInputType.MouseButton1 then
		local down = input.clickDown
		input.clickDown = nil
		input.downOn = nil
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
			if ghost then clearGhost() elseif not Kit.cancel() then closeCard() end
		end
		input.rightDown = false
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end)

UIS.InputChanged:Connect(function(io, gp)
	if not S.building then return end
	if io.UserInputType == Enum.UserInputType.MouseWheel then
		if gp or overGui() then return end
		-- round 28: the floor under the cursor stays put while you zoom
		local old = goal.dist
		local new = math.clamp(old * (1 - io.Position.Z * 0.12), 16, 105)
		-- (zooming in only: zooming out about the cursor throws the view sideways)
		-- round 32: while right-dragging (turning) it zooms straight in from the centre
		local p = new < old and not UI.gamepad() and not input.rightDown and floorPoint() or nil
		if p and (p - goal.focus).Magnitude < 160 then goal.focus = p + (goal.focus - p) * (new / old) end
		goal.dist = new
	end
end)

-- round 12 fix: right-drag turns the view. It no longer locks the mouse (a locked mouse read as no move at
-- all on some setups); the turn is read once a frame, after the camera scripts, from the cursor's own move.
-- Half a screen's drag is more than a full turn, so the screen edge never gets in the way.
S.cut = { parts = {}, at = 0 }
function S.cutScan()
	local list = {}
	for _, n in ipairs({ "Shell", "Rooms", "Doors" }) do
		local f = HOTEL:FindFirstChild(n)
		for _, d in ipairs(f and f:GetDescendants() or {}) do
			-- walls and pillars behind the glass front (the front itself is faded by setFacade)
			if d:IsA("BasePart") and d.Size.Y > 5 and math.min(d.Size.X, d.Size.Z) < 3 and d.Position.Z <= 28.5 and d.Transparency < 0.9 then
				list[#list + 1] = d
			end
		end
	end
	for _, m in ipairs(PLACED:GetChildren()) do
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		if it and it.structure then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then list[#list + 1] = d end
			end
		end
	end
	-- anything that left the list goes solid again
	local keep = {}
	for _, p in ipairs(list) do keep[p] = true end
	for _, p in ipairs(S.cut.parts) do
		if not keep[p] and p.Parent and not (ghost and ghost.moving and p:IsDescendantOf(ghost.moving)) then p.LocalTransparencyModifier = 0 end
	end
	S.cut.parts = list
end
function S.cutRestore()
	for _, p in ipairs(S.cut.parts) do
		if p.Parent then p.LocalTransparencyModifier = 0 end
	end
	S.cut.parts, S.cut.at = {}, 0
end
-- every wall on the camera's side of the spot you look at fades out, so rooms are open to you from any angle
function S.cutStep(dt)
	local c = S.cut
	local now = os.clock()
	if now > c.at then
		c.at = now + 1.5
		S.cutScan()
	end
	local on = S.walls == "cut"
	local f = cam.focus
	local tx, tz = math.sin(cam.yaw), math.cos(cam.yaw)
	local k = math.min(dt * 9, 1)
	local moving = ghost and ghost.moving
	for _, p in ipairs(c.parts) do
		if p.Parent and not (moving and p:IsDescendantOf(moving)) then
			local rel = p.Position - f
			local want = (on and rel.X * tx + rel.Z * tz > 1.5) and 0.9 or 0
			local cur = p.LocalTransparencyModifier
			if cur ~= want then
				p.LocalTransparencyModifier = math.abs(cur - want) < 0.02 and want or cur + (want - cur) * k
			end
		end
	end
end

RunService:BindToRenderStep("BuildLook", Enum.RenderPriority.Camera.Value + 2, function()
	if S.building and S.pan then
		if S.pan.mid and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) then
			S.pan = nil
		elseif S.pan.anchor then
			-- keep the floor point that was grabbed under the cursor
			local p = floorPoint()
			if p then
				local shift = S.pan.anchor - p
				if shift.Magnitude < 60 then
					cam.focus += shift
					goal.focus = cam.focus
					camera.CFrame = camCF(cam)
				end
			end
		else
			S.pan.anchor = floorPoint()
		end
	end
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
		worldClick(pos)
	end
end)

---------------------------------------------------------------- per frame

RunService.RenderStepped:Connect(function(dt)
	S.groundGrid()
	if not S.building then return end
	S.cutStep(dt)
	if input.clickDown and not input.mode and not ghost and not TOUCH and (UIS:GetMouseLocation() - input.clickDown).Magnitude > 7 then
		S.beginDrag()
	end
	-- the player camera scripts can drop the lock mid-drag: hold it while the right button turns the view
	if ghost then
		if not TOUCH and not overGui() then aimGhost() end
		if ghost.target and ghost.model then
			local a = 1 - math.exp(-dt * 22)
			ghost.shown = ghost.shown and ghost.shown:Lerp(ghost.target, a) or ghost.target
			ghost.spin = math.max(ghost.spin - dt * 4, 0)
			-- round 28: it sits where it will land (no bobbing); a turn still gives a small hop
			local lift = math.sin(ghost.spin * math.pi) * 0.45 + (ghost.grab and 0.35 or 0.04)
			ghost.model:PivotTo(ghost.shown * CFrame.new(0, lift, 0))
			if ghost.boxSize and not ghost.wall and not S.roomMode and ghost.model.Parent then
				local bc = ghost.shown * ghost.boxOff
				S.foot.Size = Vector3.new(ghost.boxSize.X, 0.08, ghost.boxSize.Z)
				S.foot.CFrame = CFrame.new(bc.Position.X, ghost.shown.Position.Y + 0.07, bc.Position.Z) * ghost.shown.Rotation
				S.foot.Parent = localFolder
			else
				S.foot.Parent = nil
			end
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
		local m = not TOUCH and not Kit.groupActive() and not overGui() and placedAt() or nil
		if Kit.hover(m) then
			hovered = nil
			hoverHL.Enabled = false
		elseif m ~= hovered then
			hovered = m
			hoverHL.Adornee = m
			hoverHL.Enabled = m ~= nil and not Kit.selSet[m]
		end
	end
	Kit.step(dt)
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
		Kit.openTab(want)
	end)
end)

-- Coop calls this before it restarts the script (you moved to another hotel): leave build mode cleanly
local leaveFn = Instance.new("BindableFunction")
leaveFn.Name = "Leave"
leaveFn.OnInvoke = function() if S.building then leave() end end
leaveFn.Parent = script
