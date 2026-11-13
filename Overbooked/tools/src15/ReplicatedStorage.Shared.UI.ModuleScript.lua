-- ReplicatedStorage.Shared.UI (round 21, 2026-11-12): the shared look and motion of every screen.
-- "Clean": flat white cards with hairlines and soft shadows, one blue accent, Builder Sans throughout, no gloss,
-- rims or sparkles; the HUD (top bar, bottom bar, toasts, prompts) is dark glass (T.hud). UI.G holds the flat white
-- glyph set. The API is unchanged from round 15, so every screen follows.
-- "Grand": glossy, deep and bouncy. Every coloured surface is shaded (light top, deeper bottom), wears a crisp
-- rim in its own darker colour and a soft gloss on its upper half; buttons stand on a lip and sink when pressed,
-- and a shine sweeps across them on hover. Panels are white-to-lavender cards with a coloured, patterned header
-- band, a round icon badge and a fat white title. Fredoka One for titles, numbers and buttons; Builder Sans for
-- everything you read.
-- The token names stayed from the older looks so every screen follows:
--   ink = card, ink2 = rows, ink3 = hover, line = hairlines, cream = text, muted = quiet text,
--   gold = the brand colour (violet), outline = deep rim colour.
-- Everything that moves goes through UI.tween so timings feel the same everywhere.
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = {}

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

UI.IMG = {
	shadow = "rbxassetid://78051640519258", tail = "rbxassetid://124364212363691", dots = "rbxassetid://95622236790827",
	stripes = "rbxassetid://137063489975609", scallop = "rbxassetid://113383597310418", tag = "rbxassetid://128468592600796",
	soft = "rbxassetid://129504296492014", vignette = "rbxassetid://118910638739528",
	glow = "rbxassetid://114527952451235", sparkle = "rbxassetid://115492568987572", star = "rbxassetid://102000026991193",
	starLine = "rbxassetid://98096591891760", starGloss = "rbxassetid://134136398495530", inner = "rbxassetid://85684542798768",
	plus = "rbxassetid://77945589749326", rays = "rbxassetid://88969029590342",
	tailFill = "rbxassetid://84068413827098", tailRim = "rbxassetid://93109228859970",
}

---------------------------------------------------------------- gamepad (round 10c: PS5 / Xbox)
-- UI.gamepad() is true while the last input came from a controller. Key hints swap to the controller's button
-- (UI.PAD_KEYS), panels select their first button when they open, and B closes the topmost panel
-- (UI.closeTopmost, wired by Gamepad).
local GuiService = game:GetService("GuiService")
UI.PAD_KEYS = { B = "UP", M = "LEFT", R = "RIGHT", X = "B", T = "RB", G = "LB", E = "X", F = "Y", Q = "Y" }
local function isPad(t)
	return t == Enum.UserInputType.Gamepad1 or t == Enum.UserInputType.Gamepad2
		or t == Enum.UserInputType.Gamepad3 or t == Enum.UserInputType.Gamepad4
end
UI.isPadInput = isPad
function UI.gamepad() return isPad(UIS:GetLastInputType()) end
UI.PadChanged = Instance.new("BindableEvent") -- fires (isPad) when the player switches between controller and mouse/touch
local lastPad = UI.gamepad()
UIS.LastInputTypeChanged:Connect(function(t)
	local now = isPad(t)
	if now ~= lastPad then
		lastPad = now
		UI.PadChanged:Fire(now)
	end
end)

-- every panel's close button, newest last, so a controller's B can close whatever is on top
UI.closers = {}
local function onScreen(o)
	if not o:IsDescendantOf(game) then return false end
	local p = o
	while p and not p:IsA("LayerCollector") do
		if p:IsA("GuiObject") and not p.Visible then return false end
		p = p.Parent
	end
	return p == nil or p.Enabled
end
function UI.closeTopmost()
	for i = #UI.closers, 1, -1 do
		local c = UI.closers[i]
		if not c.b.Parent then
			table.remove(UI.closers, i)
		elseif onScreen(c.b) then
			c.fn()
			return true
		end
	end
	return false
end

-- give a controller something to move between when a panel opens
function UI.padSelect(root)
	if not UI.gamepad() or not root then return end
	task.delay(0.05, function()
		if root.Parent and onScreen(root) then pcall(function() GuiService:Select(root) end) end
	end)
end

-- button colour sets: face (the light top), lip (the edge under the face, and the rim), text
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

-- is a colour light (needs dark words) or dark (needs light words)?
function UI.isLight(c) return (c.R * 0.299 + c.G * 0.587 + c.B * 0.114) > 0.6 end

---------------------------------------------------------------- building blocks

function UI.new(class, props, children)
	local o = Instance.new(class)
	if class == "Frame" or class == "TextLabel" or class == "TextButton" or class == "ImageLabel" or class == "ImageButton" or class == "ScrollingFrame" or class == "CanvasGroup" then
		o.BorderSizePixel = 0
	end
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		o.FontFace = UI.F.bold
		o.TextColor3 = T.cream
		o.BackgroundTransparency = 1
	end
	if class == "TextButton" or class == "ImageButton" then o.AutoButtonColor = false end
	-- children draw over their parents (a ScreenGui made by script defaults to Global order)
	if class == "ScreenGui" then o.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end
	-- a coloured text chip: giving a BackgroundColor3 means "show the background"
	if props and props.BackgroundColor3 and props.BackgroundTransparency == nil and (class == "TextLabel" or class == "TextButton" or class == "TextBox") then
		o.BackgroundTransparency = 0
	end
	if class == "ImageLabel" or class == "ImageButton" then o.BackgroundTransparency = 1 end
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

function UI.corner(o, r)
	local c = o:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = typeof(r) == "UDim" and r or UDim.new(0, r or 12)
	c.Parent = o
	return c
end

-- tint toward white (k > 0) or black (k < 0)
function UI.shade(c, k)
	if k >= 0 then return c:Lerp(Color3.new(1, 1, 1), k) end
	return c:Lerp(Color3.new(0, 0, 0), -k)
end

-- the shading every coloured surface wears: its colour at the top, deeper toward the bottom
local SHEEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 246)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 192, 214)),
})
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

-- slowly turning light rays (behind a reward); returns the image (destroy it to stop)
function UI.rays(parent, size, color, props)
	local r = UI.new("ImageLabel", {
		Name = "Rays", Image = UI.IMG.rays, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = color or T.sun, ImageTransparency = 0.25, ZIndex = 0, Parent = parent,
	})
	for k, v in pairs(props or {}) do r[k] = v end
	task.spawn(function()
		while r.Parent do
			r.Rotation = (r.Rotation + RunService.Heartbeat:Wait() * 24) % 360
		end
	end)
	return r
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

-- a round dot or pill made of one frame
function UI.dot(parent, size, color, props)
	local d = UI.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, Parent = parent })
	UI.corner(d, UDim.new(0.5, 0))
	for k, v in pairs(props or {}) do d[k] = v end
	return d
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

function UI.pad(o, l, t, r, b)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l or 0)
	p.PaddingTop = UDim.new(0, t or l or 0)
	p.PaddingRight = UDim.new(0, r or l or 0)
	p.PaddingBottom = UDim.new(0, b or t or l or 0)
	p.Parent = o
	return p
end

function UI.list(o, dir, gap, halign, valign)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if halign then l.HorizontalAlignment = halign end
	if valign then l.VerticalAlignment = valign end
	l.Parent = o
	return l
end

function UI.grad(o, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b or a)
	g.Rotation = rot or 90
	g.Parent = o
	return g
end

function UI.label(parent, text, size, props)
	local l = UI.new("TextLabel", {
		Text = text or "",
		TextSize = size or 18,
		Size = UDim2.new(1, 0, 0, (size or 18) + 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

function UI.icon(parent, image, size, props)
	local i = UI.new("ImageLabel", {
		Image = image or "",
		Size = UDim2.fromOffset(size or 28, size or 28),
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	})
	for k, v in pairs(props or {}) do i[k] = v end
	return i
end

-- a round progress ring that fills clockwise from the top: two clipped halves of a stroked circle, each with a
-- hard-edged gradient turned to the fill angle. Returns the holder, set(k) for 0..1 and the two strokes (to recolour).
local HALF = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0),
})
function UI.ring(parent, size, th, col, props)
	local holder = UI.new("Frame", { Name = "Ring", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent })
	for k, v in pairs(props or {}) do holder[k] = v end
	local grads, strokes = {}, {}
	for i = 1, 2 do
		local right = i == 1
		local half = UI.new("Frame", {
			Position = UDim2.fromScale(right and 0.5 or 0, 0), Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = holder.ZIndex, Parent = holder,
		})
		local c = UI.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(right and 0 or 1, 0.5),
			Size = UDim2.fromOffset(size - th * 2, size - th * 2), BackgroundTransparency = 1, ZIndex = holder.ZIndex, Parent = half,
		})
		UI.corner(c, UDim.new(0.5, 0))
		local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Thickness = th s.Color = col s.Parent = c
		local g = Instance.new("UIGradient")
		g.Transparency = HALF
		g.Parent = s
		grads[i], strokes[i] = g, s
	end
	local function set(k)
		local a = math.clamp(k, 0, 1) * 360
		grads[1].Rotation = math.clamp(a, 0, 180) - 180
		grads[2].Rotation = math.clamp(a, 180, 360) - 180
	end
	set(0)
	return holder, set, strokes
end

---------------------------------------------------------------- motion

function UI.tween(o, t, props, style, dir, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

function UI.scaleOf(o)
	local s = o:FindFirstChild("PopScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = o
	end
	return s
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

-- a number label that counts to its new value
local counting = setmetatable({}, { __mode = "k" })
function UI.commas(n)
	local s = tostring(math.floor(n + 0.5))
	local neg = s:sub(1, 1) == "-"
	if neg then s = s:sub(2) end
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (neg and "-" or "") .. s
end
function UI.countTo(label, value, fmt, t)
	fmt = fmt or function(v) return UI.commas(v) end
	local from = counting[label] or value
	counting[label] = value
	if from == value then label.Text = fmt(value) return end
	local nv = Instance.new("NumberValue")
	nv.Value = from
	nv.Changed:Connect(function(v) label.Text = fmt(v) end)
	local tw = UI.tween(nv, t or 0.6, { Value = value }, Enum.EasingStyle.Quart)
	tw.Completed:Connect(function() label.Text = fmt(value); nv:Destroy() end)
end

---------------------------------------------------------------- sound

local playEvent
function UI.sound(name, pos, pitch)
	-- Settings > Menu sounds switches off the clicks and whooshes (positional sounds still play);
	-- pitch (a {lo, hi} range) overrides the sound's own, for steady per-speaker voices (the bubble blips)
	if not pos and Players.LocalPlayer and Players.LocalPlayer:GetAttribute("UiSfxOff") then return end
	if not playEvent then
		local ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")
		local a = ps and ps:FindFirstChild("Audio")
		playEvent = a and a:FindFirstChild("Play")
	end
	if playEvent then playEvent:Fire(name, pos, pitch) end
end

---------------------------------------------------------------- panels + buttons

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
	-- round 32: a click or tap outside an open panel closes it (not one on the panel, and not one on another
	-- screen's button; build-mode panels stay, the world under them is where you build)
	if opts.onClose and opts.outsideClose ~= false and RunService:IsClient() then
		local lp = Players.LocalPlayer
		UIS.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if not holder.Parent or lp:GetAttribute("Building") then return end
			local sg = holder:FindFirstAncestorWhichIsA("LayerCollector")
			if not (sg and sg.Enabled) then return end
			local o = holder
			while o and o ~= sg do
				if o:IsA("GuiObject") and not o.Visible then return end
				o = o.Parent
			end
			local p, a, s = input.Position, holder.AbsolutePosition, holder.AbsoluteSize
			if s.X < 2 or (p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y) then return end
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1e4, 1e4)
			if a.X > vp.X or a.Y > vp.Y or a.X + s.X < 0 or a.Y + s.Y < 0 then return end -- parked off screen
			local pg = lp:FindFirstChildOfClass("PlayerGui")
			for _, g in ipairs(pg and pg:GetGuiObjectsAtPosition(p.X, p.Y) or {}) do
				if not g:IsDescendantOf(sg) and (g:IsA("GuiButton") or g:IsA("TextBox")) then return end
			end
			opts.onClose()
		end)
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

-- a quick side-to-side wiggle (no money, blocked spot...)
function UI.shake(o)
	local base = o:GetAttribute("ShakeBase") or o.Position
	o:SetAttribute("ShakeBase", base)
	task.spawn(function()
		for _, dx in ipairs({ 8, -7, 5, -3, 0 }) do
			o.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.035)
		end
		o.Position = base
	end)
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

---------------------------------------------------------------- tabs, toggles, sliders, segments

---------------------------------------------------------------- tabs, toggles, sliders, segments

-- tabs: list of { id, text, icon }; returns { select(id), buttons }. A brass bar slides under the active tab.
function UI.tabs(parent, items, onSelect, opts)
	opts = opts or {}
	local bar = UI.new("Frame", { Name = "Tabs", Size = opts.size or UDim2.new(1, 0, 0, 44), Position = opts.pos or UDim2.new(), BackgroundTransparency = 1, Parent = parent })
	-- opts.scroll: more tabs than fit slide sideways (drag, swipe or the wheel), and the picked one scrolls into view
	local row
	if opts.scroll then
		row = UI.new("ScrollingFrame", {
			Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(),
			ScrollBarThickness = 0, ElasticBehavior = Enum.ElasticBehavior.Always, ClipsDescendants = true, Parent = bar,
		})
	else
		row = UI.new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bar })
	end
	UI.list(row, Enum.FillDirection.Horizontal, opts.gap or 6, opts.align or Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local under = UI.new("Frame", { Name = "Under", Size = UDim2.fromOffset(40, 3), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = T.gold, BackgroundTransparency = 1, ZIndex = 3, Parent = bar })
	UI.corner(under, 2)
	local api = { buttons = {}, current = nil }
	-- soft fades on the edges that still hide tabs
	local fades = {}
	if opts.scroll then
		for _, side in ipairs({ 0, 1 }) do
			local f = UI.new("Frame", {
				Name = "Fade", Size = UDim2.new(0, 46, 1, 0), Position = UDim2.fromScale(side, 0), AnchorPoint = Vector2.new(side, 0),
				BackgroundColor3 = opts.fadeColor or T.ink, BorderSizePixel = 0, ZIndex = 4, Visible = false, Parent = bar,
			})
			UI.new("UIGradient", {
				Rotation = side == 0 and 180 or 0,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.05) }),
				Parent = f,
			})
			local arrow = UI.new("TextButton", {
				Text = side == 0 and "<" or ">", TextSize = 20, FontFace = UI.F.black, TextColor3 = T.gold,
				BackgroundTransparency = 1, Size = UDim2.new(0, 26, 1, 0), Position = UDim2.fromScale(side, 0),
				AnchorPoint = Vector2.new(side, 0), ZIndex = 5, Parent = f,
			})
			arrow.Activated:Connect(function()
				local step = row.AbsoluteSize.X * 0.6 * (side == 0 and -1 or 1)
				UI.tween(row, 0.35, { CanvasPosition = Vector2.new(math.clamp(row.CanvasPosition.X + step, 0, math.max(0, row.AbsoluteCanvasSize.X - row.AbsoluteSize.X)), 0) }, Enum.EasingStyle.Quint)
			end)
			fades[side] = f
		end
		local function edges()
			local maxX = row.AbsoluteCanvasSize.X - row.AbsoluteSize.X
			fades[0].Visible = row.CanvasPosition.X > 4
			fades[1].Visible = maxX > 4 and row.CanvasPosition.X < maxX - 4
		end
		row:GetPropertyChangedSignal("CanvasPosition"):Connect(edges)
		row:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(edges)
		row:GetPropertyChangedSignal("AbsoluteSize"):Connect(edges)
		task.defer(edges)
	end
	local function moveUnder(b, instant)
		if opts.scroll then
			-- the bar scrolls, so the line rides inside the picked tab instead
			under.Parent = b
			under.Position = UDim2.new(0.12, 0, 1, -1)
			if instant then under.Size = UDim2.new(0.76, 0, 0, 3) else
				under.Size = UDim2.new(0, 0, 0, 3)
				under.Position = UDim2.new(0.5, 0, 1, -1)
				UI.tween(under, 0.3, { Size = UDim2.new(0.76, 0, 0, 3), Position = UDim2.new(0.12, 0, 1, -1) }, Enum.EasingStyle.Quint)
			end
			-- bring it fully into view
			local left = b.AbsolutePosition.X - row.AbsolutePosition.X
			local right = left + b.AbsoluteSize.X
			local cx = row.CanvasPosition.X
			local goal = cx
			if left < 30 then goal = cx + left - 40 elseif right > row.AbsoluteSize.X - 30 then goal = cx + right - row.AbsoluteSize.X + 40 end
			goal = math.clamp(goal, 0, math.max(0, row.AbsoluteCanvasSize.X - row.AbsoluteSize.X))
			if goal ~= cx then
				if instant then row.CanvasPosition = Vector2.new(goal, 0) else UI.tween(row, 0.35, { CanvasPosition = Vector2.new(goal, 0) }, Enum.EasingStyle.Quint) end
			end
			return
		end
		-- in fractions of the bar, so a UIScale above us doesn't throw the offsets off
		local bw = math.max(bar.AbsoluteSize.X, 1)
		local x = b.AbsolutePosition.X - bar.AbsolutePosition.X
		local w = b.AbsoluteSize.X
		local goal = { Position = UDim2.new((x + w * 0.12) / bw, 0, 1, -2), Size = UDim2.new(w * 0.76 / bw, 0, 0, 3) }
		if instant then under.Position = goal.Position under.Size = goal.Size else UI.tween(under, 0.32, goal, Enum.EasingStyle.Quint) end
	end
	for i, it in ipairs(items) do
		local b = UI.new("TextButton", {
			Name = it.id, Text = "", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, -8),
			BackgroundColor3 = T.ink3, BackgroundTransparency = 1, LayoutOrder = i, Parent = row,
		})
		UI.corner(b, 12)
		UI.sheen(b, 0.8)
		UI.pad(b, 14, 0, 14, 0)
		local tst = UI.stroke(b, 2.5, T.outline, 1)
		tst.Name = "TabRim"
		local inner = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Parent = b })
		UI.list(inner, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
		if it.icon then UI.icon(inner, it.icon, 22, { Name = "Icon", LayoutOrder = 1 }) end
		local tl = UI.new("TextLabel", {
			Name = "Label", Text = it.text, TextSize = math.floor((opts.textSize or 17) * 1.06 + 0.5), FontFace = UI.F.display, TextColor3 = T.muted,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = inner,
		})
		local rim = UI.wordRim(tl, 2)
		rim.Enabled = false
		b.MouseEnter:Connect(function()
			if api.current ~= it.id then UI.tween(b, 0.15, { BackgroundTransparency = 0.3 }) end
		end)
		b.MouseLeave:Connect(function()
			if api.current ~= it.id then UI.tween(b, 0.2, { BackgroundTransparency = 1 }) end
		end)
		b.Activated:Connect(function()
			if api.current ~= it.id then UI.sound("Tab") end
			api.select(it.id)
		end)
		api.buttons[it.id] = b
	end
	function api.select(id, silent)
		api.current = id
		for bid, b in pairs(api.buttons) do
			local on = bid == id
			local l = b:FindFirstChild("Label", true)
			if l then
				l.TextColor3 = on and T.white or T.muted
				local rim = l:FindFirstChild("Rim")
				if rim then rim.Enabled = on end
			end
			UI.tween(b, 0.2, { BackgroundTransparency = on and 0 or 1, BackgroundColor3 = on and T.gold or T.ink3 })
			local tr = b:FindFirstChild("TabRim")
			if tr then tr.Transparency = on and 0 or 1 tr.Color = T.brandDk tr.Thickness = 2.5 end
			if on then UI.pop(b, 0.9, 0.3) end
			local ic = b:FindFirstChild("Icon", true)
			if ic then UI.tween(ic, 0.2, { ImageTransparency = on and 0 or 0.35 }) end
		end
		local b = api.buttons[id]
		if b then
			task.defer(function() moveUnder(b, silent) end)
		end
		if onSelect and not silent then onSelect(id) end
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if api.current and api.buttons[api.current] then moveUnder(api.buttons[api.current], true) end
	end)
	return api, bar
end

-- an on/off switch: a shaded track with a glossy white knob; returns frame, set(on)
function UI.toggle(parent, on, onChange, opts)
	opts = opts or {}
	local OFF = Color3.fromRGB(206, 200, 236)
	local b = UI.new("TextButton", {
		Name = opts.name or "Toggle", Text = "", Size = UDim2.fromOffset(60, 32),
		Position = opts.pos or UDim2.new(), AnchorPoint = opts.anchor or Vector2.new(),
		BackgroundColor3 = on and T.green or OFF, LayoutOrder = opts.order or 0, Parent = parent,
	})
	UI.corner(b, UDim.new(0.5, 0))
	UI.new("UIGradient", { Name = "Sheen", Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(200, 196, 214), Color3.new(1, 1, 1)), Parent = b })
	local rim = UI.rim(b, on and T.greenDk or Color3.fromRGB(170, 162, 214), 2)
	local knob = UI.new("Frame", {
		Size = UDim2.fromOffset(26, 26), Position = on and UDim2.new(1, -29, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.white, ZIndex = 3, Parent = b,
	})
	UI.corner(knob, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 240)), Parent = knob })
	local kr = UI.rim(knob, on and T.greenDk or Color3.fromRGB(170, 162, 214), 2)
	local state = on
	local function set(v, silent)
		state = v
		UI.tween(b, 0.22, { BackgroundColor3 = v and T.green or OFF })
		UI.tween(rim, 0.22, { Color = v and T.greenDk or Color3.fromRGB(170, 162, 214) })
		UI.tween(kr, 0.22, { Color = v and T.greenDk or Color3.fromRGB(170, 162, 214) })
		UI.tween(knob, 0.34, { Position = v and UDim2.new(1, -29, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
		UI.pop(knob, 0.8, 0.3)
		if not silent and onChange then onChange(v) end
	end
	b.Activated:Connect(function()
		UI.sound("Click")
		set(not state)
	end)
	return b, set
end

-- a row of choices (grid sizes, rotation steps); items = { {id, text} }
function UI.segmented(parent, items, current, onChange, opts)
	opts = opts or {}
	local f = UI.new("Frame", {
		Name = opts.name or "Segmented", Size = opts.size or UDim2.new(1, 0, 0, 38), Position = opts.pos or UDim2.new(),
		BackgroundColor3 = Color3.fromRGB(230, 226, 250), LayoutOrder = opts.order or 0, Parent = parent,
	})
	UI.corner(f, 12)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(206, 202, 222), Color3.new(1, 1, 1)), Parent = f })
	UI.rim(f, Color3.fromRGB(200, 192, 238), 2)
	local pill = UI.new("Frame", { Name = "Pill", BackgroundColor3 = T.brand, Size = UDim2.new(1 / #items, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 2, Parent = f })
	UI.corner(pill, 10)
	UI.sheen(pill)
	UI.rim(pill, T.brandDk, 2)
	UI.gloss(pill, 10, 0.35)
	local btns = {}
	local api = {}
	function api.set(id, silent)
		for i, it in ipairs(items) do
			local on = it.id == id
			if on then UI.tween(pill, 0.32, { Position = UDim2.new((i - 1) / #items, 3, 0, 3) }, Enum.EasingStyle.Back) end
			UI.tween(btns[i], 0.2, { TextColor3 = on and T.white or T.muted })
			local s = btns[i]:FindFirstChild("Rim")
			if s then s.Enabled = on end
		end
		api.current = id
		if not silent and onChange then onChange(id) end
	end
	for i, it in ipairs(items) do
		local b = UI.new("TextButton", {
			Text = it.text, TextSize = math.floor((opts.textSize or 15) * 1.02 + 0.5), FontFace = UI.F.display, TextColor3 = T.muted,
			Size = UDim2.new(1 / #items, 0, 1, 0), Position = UDim2.fromScale((i - 1) / #items, 0), ZIndex = 4, Parent = f,
		})
		UI.wordRim(b, 1.5, T.brandDk)
		b.Activated:Connect(function() UI.sound("Tab") api.set(it.id) end)
		btns[i] = b
	end
	api.set(current, true)
	return f, api
end

-- a slider; returns frame, set(v)
function UI.slider(parent, min, max, value, onChange, opts)
	opts = opts or {}
	local f = UI.new("Frame", {
		Name = opts.name or "Slider", Size = opts.size or UDim2.new(1, 0, 0, 28), Position = opts.pos or UDim2.new(),
		BackgroundTransparency = 1, LayoutOrder = opts.order or 0, Parent = parent,
	})
	local track = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink3, Parent = f })
	UI.corner(track, 5)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(190, 184, 216), Color3.new(1, 1, 1)), Parent = track })
	UI.rim(track, Color3.fromRGB(198, 190, 238), 1.5)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.gold, Parent = track })
	UI.corner(fill, 5)
	UI.sheen(fill)
	local knob = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.white, Parent = track })
	UI.corner(knob, 12)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 240)), Parent = knob })
	UI.rim(knob, T.brandDk, 3)
	UI.animate(knob, { hover = 1.15, sound = false })
	local step = opts.step
	local v = value
	local function set(nv, silent)
		nv = math.clamp(nv, min, max)
		if step then nv = math.floor(nv / step + 0.5) * step end
		v = nv
		local a = (nv - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		if not silent and onChange then onChange(nv) end
	end
	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + a * (max - min))
	end
	knob.MouseButton1Down:Connect(function() dragging = true end)
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	set(value, true)
	return f, set
end

---------------------------------------------------------------- tooltips

local tipGui, tipLabel
function UI.tooltip(gui, text)
	gui.MouseEnter:Connect(function()
		if not tipGui then
			local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
			tipGui = UI.new("ScreenGui", { Name = "Tooltip", DisplayOrder = 100, IgnoreGuiInset = true, ResetOnSpawn = false, Parent = pg })
			tipLabel = UI.new("TextLabel", {
				TextSize = 15, FontFace = UI.F.heavy, BackgroundColor3 = T.night, BackgroundTransparency = 0.04, TextColor3 = T.white,
				AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), AnchorPoint = Vector2.new(0.5, 1), Visible = false, Parent = tipGui,
			})
			UI.corner(tipLabel, 8)
			UI.pad(tipLabel, 10, 6, 10, 6)
			UI.rim(tipLabel, T.nightDk, 2)
		end
		tipLabel.Text = typeof(text) == "function" and text() or text
		-- AbsolutePosition doesn't count Roblox's top bar inset; measuring from the tooltip's own screen fixes the offset
		local p = gui.AbsolutePosition - tipGui.AbsolutePosition
		-- near the top of the screen there's no room above, so it hangs underneath
		if p.Y < 90 then
			tipLabel.AnchorPoint = Vector2.new(0.5, 0)
			tipLabel.Position = UDim2.fromOffset(p.X + gui.AbsoluteSize.X / 2, p.Y + gui.AbsoluteSize.Y + 8)
		else
			tipLabel.AnchorPoint = Vector2.new(0.5, 1)
			tipLabel.Position = UDim2.fromOffset(p.X + gui.AbsoluteSize.X / 2, p.Y - 6)
		end
		tipLabel.Visible = true
		UI.pop(tipLabel, 0.8, 0.2)
	end)
	gui.MouseLeave:Connect(function()
		if tipLabel then tipLabel.Visible = false end
	end)
end

---------------------------------------------------------------- screen scale + blur

-- one UIScale per ScreenGui root frame: 1 at 1600x900, smaller on small screens (phones get a floor)
function UI.autoScale(frame, base)
	local s = frame:FindFirstChild("AutoScale") or Instance.new("UIScale")
	s.Name = "AutoScale"
	s.Parent = frame
	local cam = workspace.CurrentCamera
	local function upd()
		local vp = cam.ViewportSize
		local k = math.min(vp.X / (base and base.X or 1600), vp.Y / (base and base.Y or 900))
		s.Scale = math.clamp(k, UIS.TouchEnabled and 0.55 or 0.7, 1.25)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
	upd()
	return s
end

local blur
function UI.blur(on, size)
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "UIBlur"
		blur:SetAttribute("Keep", true)
		blur.Size = 0
		blur.Parent = workspace.CurrentCamera
	end
	UI.tween(blur, 0.35, { Size = on and (size or 14) or 0 })
end

---------------------------------------------------------------- toasts

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

return UI
