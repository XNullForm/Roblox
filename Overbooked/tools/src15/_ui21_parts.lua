--@@TOKENS
UI.T = {
	ink = Color3.fromRGB(255, 255, 255),
	ink2 = Color3.fromRGB(245, 247, 250),
	ink3 = Color3.fromRGB(233, 237, 243),
	line = Color3.fromRGB(220, 225, 233),
	cream = Color3.fromRGB(26, 32, 44),
	muted = Color3.fromRGB(110, 120, 138),
	gold = Color3.fromRGB(20, 132, 246),
	goldDk = Color3.fromRGB(12, 98, 198),
	green = Color3.fromRGB(34, 187, 105),
	greenDk = Color3.fromRGB(20, 140, 76),
	red = Color3.fromRGB(238, 72, 84),
	redDk = Color3.fromRGB(188, 44, 58),
	blue = Color3.fromRGB(56, 152, 255),
	blueDk = Color3.fromRGB(28, 108, 208),
	violet = Color3.fromRGB(236, 96, 160),
	violetDk = Color3.fromRGB(188, 58, 120),
	shadow = Color3.fromRGB(12, 16, 26),
	outline = Color3.fromRGB(22, 28, 40),
	white = Color3.fromRGB(255, 255, 255),
	paper = Color3.fromRGB(255, 255, 255),
	brand = Color3.fromRGB(20, 132, 246),
	brandDk = Color3.fromRGB(12, 98, 198),
	brandSoft = Color3.fromRGB(228, 240, 255),
	sun = Color3.fromRGB(255, 188, 40),
	sunDk = Color3.fromRGB(204, 132, 8),
	night = Color3.fromRGB(24, 28, 38),
	nightDk = Color3.fromRGB(12, 14, 20),
	teal = Color3.fromRGB(24, 186, 180),
	tealDk = Color3.fromRGB(12, 134, 134),
	orange = Color3.fromRGB(255, 140, 56),
	orangeDk = Color3.fromRGB(204, 96, 20),
	-- the HUD's dark glass (top bar, bottom bar, toasts, prompts)
	hud = Color3.fromRGB(20, 24, 32),
	hud2 = Color3.fromRGB(38, 44, 56),
	hudLine = Color3.fromRGB(70, 78, 94),
	hudText = Color3.fromRGB(255, 255, 255),
	hudMuted = Color3.fromRGB(160, 170, 188),
}
local T = UI.T

-- flat white glyphs (Run a Hotel tools/ui21.py), tinted with ImageColor3
UI.G = {}
for k, id in pairs({
	cash = 111383426618117, guest = 123759167366566, staff = 134693526132453, hotel = 88477970155752, hammer = 80629712202212,
	check = 75576400524801, research = 72850683502250, upgrade = 83333717570759, trophy = 93244091128933, phone = 123305054325194,
	shop = 76937410758706, settings = 71057839938178, plus = 88314883882501, clean = 78115931212878, sun = 102003301435271,
	moon = 97574894240497, cloud = 78372859159975, rain = 72113176760788, storm = 112590961622808, snow = 71301641640290,
	fog = 74111319703074, save = 139449239982814, play = 82248749803104, trash = 89904753128553, bell = 128890707847756,
	star = 131955361780539, lock = 99514014609222, close = 139720762395643, bed = 102987021259705,
}) do
	UI.G[k] = "rbxassetid://" .. id
end
--@@KIND
UI.KIND = {
	gold = { T.brand, T.brandDk, T.white },
	green = { T.green, T.greenDk, T.white },
	red = { T.red, T.redDk, T.white },
	blue = { T.blue, T.blueDk, T.white },
	violet = { T.violet, T.violetDk, T.white },
	sun = { T.sun, T.sunDk, T.cream },
	teal = { T.teal, T.tealDk, T.white },
	orange = { T.orange, T.orangeDk, T.white },
	ink = { T.ink2, T.line, T.cream },
	ghost = { T.ink3, T.line, T.cream },
	night = { T.night, T.nightDk, T.white },
}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
function UI.font(weight)
	return Font.new(FAMILY, weight or Enum.FontWeight.Bold)
end
UI.F = {
	body = Font.new(FAMILY, Enum.FontWeight.Medium),
	bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	black = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	display = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	italic = Font.new(FAMILY, Enum.FontWeight.SemiBold, Enum.FontStyle.Italic),
}
--@@FUNCS
-- round 21: surfaces are flat. sheen is a barely-there shade so a surface still reads as a surface
function UI.sheen(o, strength)
	local g = o:FindFirstChild("Sheen") or Instance.new("UIGradient")
	g.Name = "Sheen"
	g.Rotation = 90
	g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 245, 248))
	g.Parent = o
	return g
end

-- round 21: no gloss any more; the (hidden) frame is still returned for older callers
function UI.gloss(o, radius, strength)
	return UI.new("Frame", { Name = "Gloss", Size = UDim2.new(), BackgroundTransparency = 1, Visible = false, Parent = o })
end

-- round 21: no shine sweep; returns a do-nothing play()
function UI.shine(o, radius)
	return function() end
end

-- outlines are hairlines
function UI.stroke(o, th, col, tr)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = 1
	if col == nil or col == T.outline then
		s.Color = T.line
		s.Transparency = math.max(tr or 0, 0)
	else
		s.Color = col
		s.Transparency = tr or 0
	end
	s.Parent = o
	return s
end

-- a hairline in the surface's deeper colour (buttons, chips, badges)
function UI.rim(o, col, th)
	local s = o:FindFirstChild("Rim") or Instance.new("UIStroke")
	s.Name = "Rim"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = 1
	s.Color = col
	s.Transparency = 0.35
	s.Parent = o
	return s
end

-- a thin soft edge so words over the 3D world stay readable; flat on buttons
function UI.textStroke(o, th, tr, col)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Thickness = 1
	s.Transparency = math.max(tr or 0, 0.6)
	s.Color = col or T.shadow
	s.Parent = o
	return s
end

-- round 21: words on a colour carry no rim (kept so callers can still toggle it)
function UI.wordRim(o, th, col)
	local s = Instance.new("UIStroke")
	s.Name = "Rim"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Thickness = 0
	s.Color = col or T.outline
	s.Transparency = 1
	s.Parent = o
	return s
end

-- the soft drop shadow under a card. `holder` must be a transparent, non-clipping frame the card fills.
function UI.shadow(holder, opts)
	opts = opts or {}
	local sp = opts.spread or 0
	return UI.new("ImageLabel", {
		Name = "Shadow", Image = UI.IMG.shadow, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(48, 48, 80, 80),
		Size = UDim2.new(1, 48 + sp * 2, 1, 48 + sp * 2),
		Position = UDim2.fromOffset(-24 - sp, -24 - sp + math.min(opts.drop or 6, 8)),
		ImageColor3 = T.shadow, ImageTransparency = math.max(opts.transparency or 0.8, 0.8), ZIndex = 0, Parent = holder,
	})
end

-- a faint radial glow (kept very quiet)
function UI.glow(parent, size, color, props)
	local g = UI.new("ImageLabel", {
		Name = "Glow", Image = UI.IMG.glow, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = color or T.white, ImageTransparency = 0.9, ZIndex = 0, Parent = parent,
	})
	for k, v in pairs(props or {}) do g[k] = v end
	g.ImageTransparency = math.max(g.ImageTransparency, 0.88)
	return g
end

-- round 21: no sparkles
function UI.sparkles(parent, n, color, spread)
end

-- a card on a soft shadow: returns holder (position / size this), body (put things in this)
function UI.card(parent, props, opts)
	opts = opts or {}
	local holder = UI.new("Frame", { Name = opts.name or "Card", BackgroundTransparency = 1, Parent = parent })
	for k, v in pairs(props or {}) do holder[k] = v end
	if opts.shadow == true then UI.shadow(holder, opts) end
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = opts.color or T.ink, ClipsDescendants = opts.clip == true, Parent = holder })
	UI.corner(body, math.min(opts.radius or 12, 14))
	if opts.rim ~= false then UI.rim(body, T.line, 1).Transparency = 0 end
	return holder, body
end

-- a small coloured label: UI.chip(parent, "LV 3", color, props)
function UI.chip(parent, text, color, props)
	color = color or T.brand
	local light = UI.isLight(color)
	local c = UI.new("TextLabel", {
		Name = "Chip", Text = text, TextSize = 13, FontFace = UI.F.heavy, TextColor3 = light and T.cream or T.white,
		BackgroundColor3 = color, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), Parent = parent,
	})
	UI.corner(c, 6)
	UI.pad(c, 8, 0, 8, 0)
	for k, v in pairs(props or {}) do c[k] = v end
	return c
end

-- a round badge: a flat coloured disc holding an icon
function UI.badge(parent, size, color, image, props)
	local b = UI.new("Frame", { Name = "Badge", Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, Parent = parent })
	UI.corner(b, UDim.new(0.5, 0))
	if image then
		UI.icon(b, image, math.floor(size * 0.62), { Name = "Icon", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = b.ZIndex + 2 })
	end
	for k, v in pairs(props or {}) do b[k] = v end
	return b
end

-- a quick, calm pop (scale only)
function UI.pop(o, from, t)
	local s = UI.scaleOf(o)
	s.Scale = 1 + ((from or 0.85) - 1) * 0.5
	UI.tween(s, math.min(t or 0.2, 0.22), { Scale = 1 }, Enum.EasingStyle.Quad)
end

-- a panel arrives: a short rise and fade (CanvasGroup) or a small scale-up (Frame)
function UI.open(o, opts)
	opts = opts or {}
	o.Visible = true
	local s = UI.scaleOf(o)
	s.Scale = 0.97
	UI.tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Quad)
	if o:IsA("CanvasGroup") then
		o.GroupTransparency = 1
		UI.tween(o, 0.16, { GroupTransparency = 0 })
	end
	local base = o:GetAttribute("BasePos")
	if not base then
		base = o.Position
		o:SetAttribute("BasePos", base)
	end
	o.Position = base + UDim2.fromOffset(0, 8)
	UI.tween(o, 0.2, { Position = base }, Enum.EasingStyle.Quint)
	UI.sound("Open")
	if not opts.noSelect then UI.padSelect(o) end
end

function UI.close(o, cb)
	local sel = GuiService.SelectedObject
	if sel and sel:IsDescendantOf(o) then GuiService.SelectedObject = nil end
	local s = UI.scaleOf(o)
	UI.tween(s, 0.12, { Scale = 0.98 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local done = function()
		o.Visible = false
		s.Scale = 1
		if o:IsA("CanvasGroup") then o.GroupTransparency = 0 end
		if cb then cb() end
	end
	if o:IsA("CanvasGroup") then
		UI.tween(o, 0.12, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(done)
	else
		task.delay(0.12, done)
	end
	UI.sound("Close")
end

-- children of a list arrive one after another (a short fade-up, no bounce)
function UI.stagger(container, step)
	local kids = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible then table.insert(kids, c) end
	end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i, c in ipairs(kids) do
		local s = UI.scaleOf(c)
		s.Scale = 0.94
		UI.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, math.min(i - 1, 10) * 0.015)
	end
end

-- a panel: a flat white card with a hairline and a soft shadow. With a title it gets a header row: a small
-- coloured icon tile, the title in heavy dark type, an optional quiet subtitle and a square close button.
-- Returns holder, body. (Head, Tile, Disc, Title, Sub, Foot and Rule keep their names for the screens that restyle them.)
function UI.panel(parent, size, pos, opts)
	opts = opts or {}
	local radius = math.min(opts.radius or 14, 14)
	local holder = UI.new(opts.canvas and "CanvasGroup" or "Frame", {
		Name = opts.name or "Panel",
		Size = size,
		Position = pos or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UI.shadow(holder, { drop = 8, transparency = 0.72, spread = 6 })
	local col = opts.headColor or T.brand
	local body = UI.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = math.min(opts.transparency or 0, 0.02),
		ClipsDescendants = opts.clip ~= false,
		Parent = holder,
	})
	UI.corner(body, radius)
	local rim = UI.rim(body, T.line, 1)
	rim.Name = "PanelRim"
	rim.Transparency = 0
	if opts.title then
		local head = UI.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.ink, BackgroundTransparency = 1, ZIndex = 2, Parent = body })
		UI.new("Frame", { Name = "Foot", Size = UDim2.new(), BackgroundTransparency = 1, Visible = false, Parent = head })
		UI.new("Frame", { Name = "Rule", Size = UDim2.new(1, -36, 0, 1), Position = UDim2.new(0, 18, 1, -1), BackgroundColor3 = T.line, ZIndex = 4, Parent = head })
		local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 18, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ZIndex = 5, Parent = head })
		local disc = UI.new("Frame", { Name = "Disc", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UI.shade(col, 0.86), ZIndex = 5, Parent = tile })
		UI.corner(disc, 11)
		if opts.icon then
			UI.icon(disc, opts.icon, 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 })
		else
			UI.new("ImageLabel", { Image = UI.G.star, ImageColor3 = col, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = disc })
		end
		local x = 72
		local title = UI.label(head, opts.title, 24, {
			Name = "Title", FontFace = UI.F.black, Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(1, -x - 64, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = T.cream, ZIndex = 6,
		})
		if opts.subtitle then
			title.Position = UDim2.new(0, x, 0.5, -10)
			title.TextSize = 22
			UI.label(head, opts.subtitle, 14, {
				Name = "Sub", FontFace = UI.F.body, TextColor3 = T.muted, ZIndex = 6,
				Position = UDim2.new(0, x, 0.5, 13), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -x - 64, 0, 18),
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
		end
		if opts.onClose then
			local c = UI.closeButton(body, opts.onClose)
			c.Position = UDim2.new(1, -15, 0, 15)
		end
	end
	return holder, body
end

-- a small hover grow and press shrink for any button
function UI.animate(btn, opts)
	opts = opts or {}
	local s = UI.scaleOf(btn)
	local hover = 1 + ((opts.hover or 1.05) - 1) * 0.5
	local over = false
	btn.MouseEnter:Connect(function()
		over = true
		UI.tween(s, 0.12, { Scale = hover }, Enum.EasingStyle.Quad)
		if opts.sound ~= false then UI.sound("Hover") end
	end)
	btn.MouseLeave:Connect(function()
		over = false
		UI.tween(s, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Down:Connect(function()
		UI.tween(s, 0.06, { Scale = 0.97 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		UI.tween(s, 0.12, { Scale = over and hover or 1 }, Enum.EasingStyle.Quad)
	end)
end

-- a button: one flat rounded face in its kind's colour with heavy words. It darkens a touch on hover and more
-- when pressed. { text, icon, kind = "gold", size, pos, anchor, onClick, key = "B", textSize, radius }
function UI.button(parent, o)
	local kindName = o.kind or "gold"
	local kind = UI.KIND[kindName] or UI.KIND.gold
	local b = UI.new("TextButton", {
		Name = o.name or "Button",
		Text = "",
		Size = o.size or UDim2.fromOffset(180, 50),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = o.order or 0,
		Parent = parent,
	})
	b:SetAttribute("Kind", kindName)
	local r = math.min(o.radius or 10, 10)
	-- (Base and its rim are never drawn: older screens still look them up)
	local base = UI.new("Frame", { Name = "Base", Size = UDim2.fromScale(1, 1), BackgroundColor3 = kind[2], BackgroundTransparency = 1, ZIndex = 1, Parent = b })
	local baseRim = UI.rim(base, kind[2], 1)
	baseRim.Name = "BaseRim"
	baseRim.Transparency = 1
	local face = UI.new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = kind[1], ZIndex = 2, Parent = b })
	UI.corner(face, r)
	local rim = UI.rim(face, kind[2], 1)
	rim.Name = "FaceRim"
	rim.Transparency = UI.isLight(kind[1]) and 0 or 1
	local row = UI.new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = b })
	UI.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local function tone(k)
		local now = (UI.KIND[b:GetAttribute("Kind")] or kind)[1]
		UI.tween(face, 0.1, { BackgroundColor3 = k == 0 and now or UI.shade(now, -k) }, Enum.EasingStyle.Quad)
	end
	local over = false
	b.MouseEnter:Connect(function() over = true if not b:GetAttribute("Disabled") then tone(0.07) end end)
	b.MouseLeave:Connect(function() over = false tone(0) end)
	b.MouseButton1Down:Connect(function() if not b:GetAttribute("Disabled") then tone(0.16) end end)
	b.MouseButton1Up:Connect(function() tone(over and 0.07 or 0) end)
	if o.icon then
		UI.icon(row, o.icon, o.iconSize or 24, { Name = "Icon", LayoutOrder = 1, ZIndex = 6 })
	end
	local t
	if o.text then
		t = UI.new("TextLabel", {
			Name = "Label", Text = o.text, TextSize = math.floor((o.textSize or 20) * 0.92 + 0.5), FontFace = UI.F.black,
			TextColor3 = kind[3], AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, ZIndex = 6, Parent = row,
		})
		local s = UI.wordRim(t, 0, kind[2])
		s.Name = "LabelRim"
	end
	if o.key and (not UIS.TouchEnabled or UIS.KeyboardEnabled or UIS.GamepadEnabled) then
		local k = UI.new("TextLabel", {
			Name = "Key", Text = o.key, TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.white,
			BackgroundColor3 = T.night, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -4, 0, -4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Parent = b,
		})
		UI.corner(k, 6)
		local pad = UI.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = k })
		local function show(isPadNow)
			local pk = UI.PAD_KEYS[o.key]
			k.Text = isPadNow and (pk or "") or o.key
			k.Visible = not (isPadNow and not pk) and not (UIS.TouchEnabled and not UIS.KeyboardEnabled and not isPadNow)
			pad.PaddingLeft = UDim.new(0, #k.Text > 1 and 4 or 0)
			pad.PaddingRight = pad.PaddingLeft
		end
		show(UI.gamepad())
		UI.PadChanged.Event:Connect(show)
	end
	UI.animate(b, { hover = 1.04, sound = o.sound })
	if o.onClick then
		b.Activated:Connect(function()
			if b:GetAttribute("Disabled") then UI.sound("Error") UI.shake(b) return end
			UI.sound(o.clickSound or "Click")
			o.onClick(b)
		end)
	end
	return b, t
end

function UI.setKind(b, kindName)
	local kind = UI.KIND[kindName] or UI.KIND.gold
	local face = b:FindFirstChild("Face")
	if face then
		face.BackgroundColor3 = kind[1]
		local rim = face:FindFirstChild("FaceRim")
		if rim then rim.Color = kind[2] rim.Transparency = UI.isLight(kind[1]) and 0 or 1 end
	end
	local base = b:FindFirstChild("Base")
	if base then base.BackgroundColor3 = kind[2] end
	local row = b:FindFirstChild("Row")
	local l = row and row:FindFirstChild("Label")
	if l then l.TextColor3 = kind[3] end
	b:SetAttribute("Kind", kindName)
end

function UI.setDisabled(b, off)
	b:SetAttribute("Disabled", off or nil)
	if b:FindFirstChild("Face") then UI.tween(b.Face, 0.15, { BackgroundTransparency = off and 0.6 or 0 }) end
	local row = b:FindFirstChild("Row")
	if row then
		for _, c in ipairs(row:GetChildren()) do
			if c:IsA("TextLabel") then UI.tween(c, 0.15, { TextTransparency = off and 0.45 or 0 }) end
			if c:IsA("ImageLabel") then UI.tween(c, 0.15, { ImageTransparency = off and 0.5 or 0 }) end
		end
	end
end

-- a square icon button with a tooltip: a flat tile with a hairline
function UI.iconButton(parent, o)
	local col = o.color or T.ink2
	local b = UI.new("ImageButton", {
		Name = o.name or "IconButton",
		Size = o.size or UDim2.fromOffset(48, 48),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		BackgroundColor3 = col,
		BackgroundTransparency = o.transparency or 0,
		LayoutOrder = o.order or 0,
		Parent = parent,
	})
	UI.corner(b, math.min(o.radius or 10, 12))
	if UI.isLight(col) then UI.rim(b, T.line, 1).Transparency = 0 end
	if o.icon then
		UI.icon(b, o.icon, o.iconSize or 28, { Name = "Icon", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	end
	if o.text then
		UI.label(b, o.text, o.textSize or 18, {
			Name = "Label", FontFace = UI.F.black, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = UI.isLight(col) and T.cream or T.white,
		})
	end
	UI.animate(b, { hover = 1.06 })
	if o.tip then UI.tooltip(b, o.tip) end
	if o.onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			o.onClick(b)
		end)
	end
	return b
end

-- the X in a panel's corner: a quiet grey square that turns red when you reach for it
function UI.closeButton(parent, onClose)
	local b = UI.new("ImageButton", {
		Name = "Close", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -15, 0, 15), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 0,
		BackgroundColor3 = T.ink3, ZIndex = 8, Parent = parent,
	})
	UI.corner(b, 9)
	table.insert(UI.closers, { b = b, fn = onClose })
	local x = UI.new("ImageLabel", {
		Name = "X", Image = UI.G.close, ImageColor3 = T.muted, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9, Parent = b,
	})
	b.MouseEnter:Connect(function()
		UI.tween(b, 0.12, { BackgroundColor3 = T.red })
		UI.tween(x, 0.12, { ImageColor3 = T.white })
		UI.sound("Hover")
	end)
	b.MouseLeave:Connect(function()
		UI.tween(b, 0.14, { BackgroundColor3 = T.ink3 })
		UI.tween(x, 0.14, { ImageColor3 = T.muted })
	end)
	b.Activated:Connect(function()
		UI.sound("Close")
		onClose(b)
	end)
	return b
end

-- UI.toast("Room 104 is open!", icon, "good"|"bad"|nil): notifications drop in under the top bar as dark pills:
-- a coloured icon tile, the words, and a thin line that runs out as it expires. The same message again doesn't
-- stack: its pill counts up (x2, x3) and its timer restarts. At most four show; click one to dismiss it.
local toastGui, toastList
local liveToasts = {}
function UI.toast(text, icon, kind)
	text = tostring(text or "")
	if not toastGui then
		local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
		toastGui = UI.new("ScreenGui", { Name = "Toasts", DisplayOrder = 40, ResetOnSpawn = false, Parent = pg })
		toastList = UI.new("Frame", {
			Size = UDim2.fromOffset(560, 300), Position = UDim2.new(0.5, 0, 0, 84), AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1, Parent = toastGui,
		})
		UI.list(toastList, nil, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
		UI.autoScale(toastList)
	end
	local LIFE = 4.2
	for _, t in ipairs(liveToasts) do
		if t.text == text and t.alive then
			t.count += 1
			t.badge.Text = "x" .. t.count
			t.badge.Visible = true
			t.restart()
			return
		end
	end
	local accent = kind == "bad" and T.red or kind == "good" and T.green or T.brand
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = math.floor(os.clock() * 100), Parent = toastList })
	local card = UI.new("CanvasGroup", { Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.hud, BackgroundTransparency = 0.06, GroupTransparency = 1, Position = UDim2.fromOffset(0, -12), Parent = holder })
	UI.corner(card, 12)
	local st = Instance.new("UIStroke")
	st.Color = T.hudLine
	st.Transparency = 0.3
	st.Parent = card
	local row = UI.new("Frame", { Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = card })
	UI.pad(row, 8, 0, 16, 0)
	UI.list(row, Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center)
	local tile = UI.new("Frame", { Size = UDim2.fromOffset(30, 30), BackgroundColor3 = accent, LayoutOrder = 1, Parent = row })
	UI.corner(tile, 8)
	UI.new("ImageLabel", {
		Image = icon or (kind == "bad" and UI.G.close or kind == "good" and UI.G.check or UI.G.bell),
		ImageColor3 = icon and Color3.new(1, 1, 1) or T.white, Size = UDim2.fromOffset(icon and 24 or 16, icon and 24 or 16),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = tile,
	})
	local label = UI.new("TextLabel", {
		Text = text, TextSize = 16, FontFace = UI.F.bold, TextColor3 = T.hudText, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 46), LayoutOrder = 2, Parent = row,
	})
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(440, 46), Parent = label })
	label.TextTruncate = Enum.TextTruncate.AtEnd
	local badge = UI.new("TextLabel", {
		Text = "", TextSize = 13, FontFace = UI.F.heavy, TextColor3 = T.hudText, BackgroundColor3 = T.hud2, Visible = false,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), LayoutOrder = 3, Parent = row,
	})
	UI.corner(badge, 6)
	UI.pad(badge, 6, 0, 6, 0)
	local bar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = accent, Parent = card })
	local hit = UI.new("TextButton", { Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = card })
	local me = { text = text, alive = true, count = 1, badge = badge }
	local serial = 0
	local barTween
	local function leave()
		if not me.alive then return end
		me.alive = false
		local i = table.find(liveToasts, me)
		if i then table.remove(liveToasts, i) end
		UI.tween(card, 0.18, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -8) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.2, function() holder:Destroy() end)
	end
	function me.restart()
		serial += 1
		local mine = serial
		if barTween then barTween:Cancel() end
		bar.Size = UDim2.new(1, 0, 0, 2)
		barTween = UI.tween(bar, LIFE, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
		task.delay(LIFE, function() if mine == serial then leave() end end)
	end
	me.leave = leave
	hit.Activated:Connect(leave)
	table.insert(liveToasts, me)
	while #liveToasts > 4 do liveToasts[1].leave() end
	UI.tween(card, 0.22, { GroupTransparency = 0, Position = UDim2.new() }, Enum.EasingStyle.Quint)
	me.restart()
	UI.sound(kind == "bad" and "Error" or "Toast")
end
