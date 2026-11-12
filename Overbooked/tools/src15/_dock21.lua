-- round 21 (2026-11-12): the bottom bar is one strip of dark glass. BUILD is the blue key on the left (green and
-- DONE while you build); each menu is a white glyph with its name under it that lights up in its own colour on
-- hover. Every menu opens on its own from here (the menu has no tab row any more), Upgrades included.
local btnWrap = wrapper("BuildButton", UDim2.fromOffset(720, 84), UDim2.new(0.5, 0, 1, -12), Vector2.new(0.5, 1))
local toggle -- forward
local bindPad -- forward (the controller block)
local dockHolder = UI.new("Frame", { Name = "Dock", Size = UDim2.fromOffset(0, 68), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = btnWrap })
local barRow = UI.new("Frame", { Name = "Row", Size = UDim2.fromOffset(0, 68), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.hud, BackgroundTransparency = 0.08, Parent = dockHolder })
UI.corner(barRow, 18)
do
	local st = Instance.new("UIStroke")
	st.Color = T.hudLine
	st.Transparency = 0.4
	st.Parent = barRow
end
local rowList = UI.new("Frame", { Name = "List", Size = UDim2.fromOffset(0, 68), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2, Parent = barRow })
UI.pad(rowList, 8, 0, 8, 0)
UI.list(rowList, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

local capN = 0

-- one button: spec = { img, color, big }
local function barButton(spec, key, label, onClick)
	capN += 1
	local big = spec.big
	local col = spec.color or T.brand
	local b = UI.new("TextButton", { Name = "Btn_" .. (key or label), Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(big and 132 or 68, 52), BackgroundTransparency = 1, LayoutOrder = capN, ZIndex = 2, Parent = rowList })
	local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromScale(1, 1), BackgroundColor3 = big and col or T.hud2, BackgroundTransparency = big and 0 or 1, ZIndex = 3, Parent = b })
	UI.corner(tile, 12)
	local tileRim = Instance.new("UIStroke")
	tileRim.Transparency = 1
	tileRim.Parent = tile
	local lipC = UI.new("Frame", { Name = "Lip", Visible = false, Parent = b })
	local lipRim = Instance.new("UIStroke")
	lipRim.Parent = lipC
	local ic, lab
	if big then
		ic = UI.new("ImageLabel", { Name = "Icon", Image = spec.img, ImageColor3 = T.white, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 5, Parent = b })
		lab = UI.label(b, string.upper(label), 17, { Name = "Label", FontFace = UI.F.black, TextColor3 = T.white, Position = UDim2.new(0, 52, 0, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 5 })
	else
		ic = UI.new("ImageLabel", { Name = "Icon", Image = spec.img, ImageColor3 = T.hudText, Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0.5, 0, 0, 7), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5, Parent = b })
		lab = UI.label(b, label, 11, { Name = "Label", FontFace = UI.F.bold, TextColor3 = T.hudMuted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -17), Size = UDim2.new(1, 0, 0, 13), ZIndex = 5 })
	end
	if key then
		local k = UI.new("TextLabel", {
			Name = "Cap", Text = key, TextSize = 10, FontFace = UI.F.heavy, TextColor3 = big and T.white or T.hudMuted, BackgroundColor3 = big and T.brandDk or T.hud2,
			Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), ZIndex = 6, Parent = b,
		})
		UI.corner(k, 5)
		local function showKey(isPadNow)
			local pk = UI.PAD_KEYS[key]
			k.Text = isPadNow and (pk or "") or key
			k.Size = UDim2.fromOffset(#k.Text > 1 and 32 or 16, 16)
			k.Visible = not (isPadNow and not pk) and not (UIS.TouchEnabled and not UIS.KeyboardEnabled and not isPadNow)
		end
		showKey(UI.gamepad())
		UI.PadChanged.Event:Connect(showKey)
	end
	b.MouseEnter:Connect(function()
		if big then
			UI.tween(tile, 0.12, { BackgroundTransparency = 0.12 })
		else
			UI.tween(tile, 0.12, { BackgroundTransparency = 0 })
			UI.tween(ic, 0.12, { ImageColor3 = col })
			UI.tween(lab, 0.12, { TextColor3 = T.hudText })
		end
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		if big then
			UI.tween(tile, 0.14, { BackgroundTransparency = 0 })
		else
			UI.tween(tile, 0.14, { BackgroundTransparency = 1 })
			UI.tween(ic, 0.14, { ImageColor3 = T.hudText })
			UI.tween(lab, 0.14, { TextColor3 = T.hudMuted })
		end
	end)
	local sc = UI.scaleOf(b)
	b.MouseButton1Down:Connect(function() UI.tween(sc, 0.06, { Scale = 0.95 }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Up:Connect(function() UI.tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Quad) end)
	if onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			onClick()
		end)
	end
	b:SetAttribute("Deep", col)
	return b, ic, tile, lab, tileRim, lipC, lipRim
end

local function openMenu(tab) player:SetAttribute("MenuWant", tab) end

local buildBtn, buildIcon, buildTile, buildLab, buildRim, buildLip, buildLipRim = barButton({ img = UI.G.hammer, color = T.brand, big = true }, "B", "Build", function() toggle() end)
do
	capN += 1
	local div = UI.new("Frame", { Name = "Div", Size = UDim2.fromOffset(9, 30), BackgroundTransparency = 1, LayoutOrder = capN, ZIndex = 2, Parent = rowList })
	UI.new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = T.hudLine, ZIndex = 2, Parent = div })
end
local menuBtns = {}
for _, m in ipairs({
	{ { img = UI.G.hotel, color = T.blue }, "M", "Hotel", "hotel" },
	{ { img = UI.G.staff, color = T.orange }, "T", "Staff", "staff" },
	{ { img = UI.G.research, color = T.green }, "R", "Research", "research" },
	{ { img = UI.G.upgrade, color = T.sun }, "U", "Upgrades", "upgrades" },
	{ { img = UI.G.trophy, color = T.violet }, "Y", "Awards", "achievements" },
	{ { img = UI.G.settings, color = T.hudMuted }, nil, "Settings", "settings" },
}) do
	menuBtns[#menuBtns + 1] = barButton(m[1], m[2], m[3], function() openMenu(m[4]) end)
end

local function setBuildButton(on)
	buildIcon.Image = on and UI.G.check or UI.G.hammer
	buildLab.Text = on and "DONE" or "BUILD"
	UI.tween(buildTile, 0.2, { BackgroundColor3 = on and T.green or T.brand })
end
