---------------------------------------------------------------- the bottom dock: build + the menu buttons

-- round 15 v2 (2026-11-09): one glossy tray on a deep shadow. BUILD is the big violet key on the left (it stands
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
	local lab = UI.label(b, string.upper(label), big and 14 or 12, {
		Name = "Label", FontFace = UI.F.display, TextColor3 = big and T.brandDk or T.cream, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -14), Size = UDim2.new(1, 0, 0, 14), ZIndex = 5,
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
	{ { img = "rbxassetid://77567187013170", color = T.blue }, "M", "Hotel", "hotel" },
	{ { img = "rbxassetid://112752899117499", color = T.orange }, "T", "Staff", "staff" },
	{ { img = "rbxassetid://111953023418308", color = T.green }, "R", "Research", "research" },
	{ { img = "rbxassetid://72065626098144", color = T.violet }, "Y", "Awards", "achievements" },
	{ { img = "rbxassetid://95707331138329", color = Color3.fromRGB(142, 150, 196) }, nil, "Settings", "settings" },
}) do
	menuBtns[#menuBtns + 1] = barButton(m[1], m[2], m[3], function() openMenu(m[4]) end)
end

local function setBuildButton(on)
	buildIcon.Image = on and ICON.checkmark or ICON.hammer
	buildLab.Text = on and "DONE" or "BUILD"
	UI.tween(buildTile, 0.25, { BackgroundColor3 = on and T.green or T.brand })
	UI.tween(buildRim, 0.25, { Color = on and T.greenDk or T.brandDk })
	UI.tween(buildLip, 0.25, { BackgroundColor3 = on and T.greenDk or T.brandDk })
	UI.tween(buildLipRim, 0.25, { Color = UI.shade(on and T.greenDk or T.brandDk, -0.25) })
	buildLab.TextColor3 = on and T.greenDk or T.brandDk
	UI.pop(buildBtn, 0.9, 0.35)
	UI.sparkles(buildTile, 4, T.white, 1)
end

