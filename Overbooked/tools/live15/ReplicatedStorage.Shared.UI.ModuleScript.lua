-- ReplicatedStorage.Shared.UI (round 15, 2026-11-09): the shared look and motion of every screen.
-- "Key card": clean white cards on soft real shadows, flat colour, no outlines. One violet brand colour,
-- a warm yellow for money and stars, mint / coral / sky for states. One family (Montserrat): Black for
-- titles and numbers, Bold for labels, SemiBold for sentences.
-- The token names stayed from the older looks so every screen follows:
--   ink = card, ink2 = rows, ink3 = hover, line = hairlines, cream = text, muted = quiet text,
--   gold = the brand colour (violet now), outline = text-dark.
-- Everything that moves goes through UI.tween so timings feel the same everywhere.
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local UI = {}

UI.T = {
	ink = Color3.fromRGB(255, 255, 255),
	ink2 = Color3.fromRGB(243, 242, 250),
	ink3 = Color3.fromRGB(229, 227, 244),
	line = Color3.fromRGB(216, 213, 236),
	cream = Color3.fromRGB(31, 27, 69),
	muted = Color3.fromRGB(128, 124, 164),
	gold = Color3.fromRGB(108, 76, 241),
	goldDk = Color3.fromRGB(76, 48, 196),
	green = Color3.fromRGB(26, 188, 140),
	greenDk = Color3.fromRGB(16, 140, 104),
	red = Color3.fromRGB(255, 82, 102),
	redDk = Color3.fromRGB(206, 46, 70),
	blue = Color3.fromRGB(47, 155, 255),
	blueDk = Color3.fromRGB(26, 112, 210),
	violet = Color3.fromRGB(240, 80, 178),
	violetDk = Color3.fromRGB(190, 46, 136),
	shadow = Color3.fromRGB(23, 20, 58),
	outline = Color3.fromRGB(31, 27, 69),
	white = Color3.fromRGB(255, 255, 255),
	paper = Color3.fromRGB(255, 255, 255),
	-- round 15
	brand = Color3.fromRGB(108, 76, 241),
	brandDk = Color3.fromRGB(76, 48, 196),
	brandSoft = Color3.fromRGB(236, 231, 255),
	sun = Color3.fromRGB(255, 190, 40),
	sunDk = Color3.fromRGB(226, 146, 12),
	night = Color3.fromRGB(24, 21, 56),
}
local T = UI.T

UI.IMG = {
	shadow = "rbxassetid://78051640519258", tail = "rbxassetid://124364212363691", dots = "rbxassetid://95622236790827",
	stripes = "rbxassetid://137063489975609", scallop = "rbxassetid://113383597310418", tag = "rbxassetid://128468592600796",
	soft = "rbxassetid://129504296492014", vignette = "rbxassetid://118910638739528",
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

-- button colour sets: face, lip (the edge that shows under the face), text
UI.KIND = {
	gold = { T.brand, T.brandDk, T.white },
	green = { T.green, T.greenDk, T.white },
	red = { T.red, T.redDk, T.white },
	blue = { T.blue, T.blueDk, T.white },
	violet = { T.violet, T.violetDk, T.white },
	sun = { T.sun, T.sunDk, T.cream },
	ink = { T.white, T.line, T.cream },
	ghost = { T.ink2, T.ink3, T.cream },
	night = { T.night, Color3.fromRGB(10, 8, 30), T.white },
}

local FAMILY = "rbxasset://fonts/families/Montserrat.json"
function UI.font(weight)
	return Font.new(FAMILY, weight or Enum.FontWeight.Bold)
end
UI.F = {
	body = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	black = Font.new(FAMILY, Enum.FontWeight.Heavy),
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

-- round 15: nothing wears a heavy outline any more. A stroke asked for in the old outline colour becomes a hairline.
function UI.stroke(o, th, col, tr)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if col == nil or col == T.outline then
		s.Thickness = math.min(th or 1, 1.25)
		s.Color = T.line
		s.Transparency = math.max(tr or 0, 0)
	else
		s.Thickness = math.min(th or 1.5, 2)
		s.Color = col
		s.Transparency = tr or 0
	end
	s.Parent = o
	return s
end

-- a soft rim round text that sits over the 3D world (dark words get a white rim, light words a dark one)
function UI.textStroke(o, th, tr)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Thickness = math.min(th or 1.5, 1.5)
	s.Transparency = math.max(tr or 0.35, 0.3)
	local function fit()
		local ok, c = pcall(function() return o.TextColor3 end)
		s.Color = (ok and UI.isLight(c)) and T.shadow or T.white
	end
	fit()
	pcall(function() o:GetPropertyChangedSignal("TextColor3"):Connect(fit) end)
	s.Parent = o
	return s
end

-- kept for the older screens: white words on a colour needed a rim; now it's a whisper
function UI.wordRim(o, th)
	local s = Instance.new("UIStroke")
	s.Name = "Rim"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Thickness = 1
	s.Color = T.shadow
	s.Transparency = 0.8
	s.Parent = o
	return s
end

-- the soft drop shadow under a card. `holder` must be a transparent, non-clipping frame the card fills.
function UI.shadow(holder, opts)
	opts = opts or {}
	local sp = opts.spread or 0
	return UI.new("ImageLabel", {
		Name = "Shadow", Image = UI.IMG.shadow, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(48, 48, 80, 80),
		Size = UDim2.new(1, 56 + sp * 2, 1, 56 + sp * 2),
		Position = UDim2.fromOffset(-28 - sp, -28 - sp + (opts.drop or 8)),
		ImageColor3 = opts.color or T.shadow, ImageTransparency = opts.transparency or 0.74, ZIndex = 0, Parent = holder,
	})
end

-- a white card on a shadow: returns holder (position / size this), body (put things in this)
function UI.card(parent, props, opts)
	opts = opts or {}
	local holder = UI.new("Frame", { Name = opts.name or "Card", BackgroundTransparency = 1, Parent = parent })
	for k, v in pairs(props or {}) do holder[k] = v end
	if opts.shadow ~= false then UI.shadow(holder, opts) end
	local body = UI.new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 1), BackgroundColor3 = opts.color or T.ink, ClipsDescendants = opts.clip == true, Parent = holder })
	UI.corner(body, opts.radius or 16)
	return holder, body
end

-- a small coloured label: UI.chip(parent, "LV 3", color, props)
function UI.chip(parent, text, color, props)
	local c = UI.new("TextLabel", {
		Name = "Chip", Text = text, TextSize = 12, FontFace = UI.F.heavy, TextColor3 = UI.isLight(color or T.brand) and T.cream or T.white,
		BackgroundColor3 = color or T.brand, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), Parent = parent,
	})
	UI.corner(c, 6)
	UI.pad(c, 7, 0, 7, 0)
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
		local s = UI.stroke(c, th, col, 0)
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

-- springy pop (scale only)
function UI.pop(o, from, t)
	local s = UI.scaleOf(o)
	s.Scale = from or 0.85
	UI.tween(s, t or 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- a panel arrives: rises a little, scales up and fades in (CanvasGroup) or just pops (Frame)
function UI.open(o, opts)
	opts = opts or {}
	o.Visible = true
	local s = UI.scaleOf(o)
	s.Scale = opts.from or 0.9
	UI.tween(s, opts.t or 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
	if o:IsA("CanvasGroup") then
		o.GroupTransparency = 1
		UI.tween(o, 0.22, { GroupTransparency = 0 })
	end
	local base = o:GetAttribute("BasePos")
	if not base then
		base = o.Position
		o:SetAttribute("BasePos", base)
	end
	o.Position = base + UDim2.fromOffset(0, opts.rise or 18)
	UI.tween(o, opts.t or 0.42, { Position = base }, Enum.EasingStyle.Quint)
	UI.sound("Open")
	if not opts.noSelect then UI.padSelect(o) end
end

function UI.close(o, cb)
	local sel = GuiService.SelectedObject
	if sel and sel:IsDescendantOf(o) then GuiService.SelectedObject = nil end
	local s = UI.scaleOf(o)
	UI.tween(s, 0.16, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local done = function()
		o.Visible = false
		s.Scale = 1
		if o:IsA("CanvasGroup") then o.GroupTransparency = 0 end
		if cb then cb() end
	end
	if o:IsA("CanvasGroup") then
		UI.tween(o, 0.16, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(done)
	else
		task.delay(0.16, done)
	end
	UI.sound("Close")
end

-- children of a list arrive one after another
function UI.stagger(container, step)
	local kids = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible then table.insert(kids, c) end
	end
	table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i, c in ipairs(kids) do
		local s = UI.scaleOf(c)
		s.Scale = 0.6
		UI.tween(s, 0.38, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, math.min(i - 1, 14) * (step or 0.025))
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

-- a panel: a white card on a soft shadow. With a title it gets a header: a coloured icon tile, the title in
-- big dark letters, a quiet subtitle and a hairline under it. Returns holder, body.
function UI.panel(parent, size, pos, opts)
	opts = opts or {}
	local radius = math.min(opts.radius or 18, 18)
	local holder = UI.new(opts.canvas and "CanvasGroup" or "Frame", {
		Name = opts.name or "Panel",
		Size = size,
		Position = pos or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	UI.shadow(holder, { drop = 10, transparency = 0.7 })
	local body = UI.new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.ink,
		BackgroundTransparency = math.min(opts.transparency or 0, 0.02),
		ClipsDescendants = opts.clip ~= false,
		Parent = holder,
	})
	UI.corner(body, radius)
	if opts.title then
		local col = opts.headColor or T.brand
		local head = UI.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = T.ink, BackgroundTransparency = 1, ZIndex = 2, Parent = body })
		UI.new("Frame", { Name = "Rule", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = T.line, ZIndex = 2, Parent = head })
		UI.pad(head, 18, 0, 60, 0)
		-- the icon tile: the panel's own colour, dotted
		local tile = UI.new("Frame", { Name = "Tile", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = col, ClipsDescendants = true, ZIndex = 2, Parent = head })
		UI.corner(tile, 12)
		if opts.icon then
			UI.icon(tile, opts.icon, 28, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
		else
			UI.dot(tile, 12, T.white, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
		end
		local x = 52
		UI.label(head, opts.title, 24, {
			Name = "Title", FontFace = UI.F.black, Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(1, -x, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = T.cream, ZIndex = 3,
		})
		if opts.subtitle then
			head.Title.Position = UDim2.new(0, x, 0.5, -9)
			UI.label(head, opts.subtitle, 13, {
				Name = "Sub", FontFace = UI.F.bold, TextColor3 = T.muted, ZIndex = 3,
				Position = UDim2.new(0, x, 0.5, 13), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -x, 0, 16),
			})
		end
		if opts.onClose then
			UI.closeButton(body, opts.onClose)
		end
	end
	return holder, body
end

-- hover lift + press squash for any button
function UI.animate(btn, opts)
	opts = opts or {}
	local s = UI.scaleOf(btn)
	local hover = opts.hover or 1.04
	local over = false
	btn.MouseEnter:Connect(function()
		over = true
		UI.tween(s, 0.18, { Scale = hover }, Enum.EasingStyle.Back)
		if opts.sound ~= false then UI.sound("Hover") end
	end)
	btn.MouseLeave:Connect(function()
		over = false
		UI.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint)
	end)
	btn.MouseButton1Down:Connect(function()
		UI.tween(s, 0.08, { Scale = 0.93 }, Enum.EasingStyle.Quad)
	end)
	btn.MouseButton1Up:Connect(function()
		UI.tween(s, 0.3, { Scale = over and hover or 1 }, Enum.EasingStyle.Back)
	end)
end

-- a button: a flat coloured face on a darker lip; the face sinks onto the lip when pressed.
-- { text, icon, kind = "gold", size, pos, anchor, onClick, key = "B", textSize, radius }
function UI.button(parent, o)
	local kindName = o.kind or "gold"
	local kind = UI.KIND[kindName] or UI.KIND.gold
	local b = UI.new("TextButton", {
		Name = o.name or "Button",
		Text = "",
		Size = o.size or UDim2.fromOffset(180, 48),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = o.order or 0,
		Parent = parent,
	})
	b:SetAttribute("Kind", kindName)
	local r = math.min(o.radius or 12, 14)
	local base = UI.new("Frame", { Name = "Base", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = kind[2], ZIndex = 1, Parent = b })
	UI.corner(base, r)
	local face = UI.new("Frame", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundColor3 = kind[1], ZIndex = 2, Parent = b })
	UI.corner(face, r)
	local rim = UI.stroke(face, 1.25, T.line, (kindName == "ink") and 0 or 1)
	rim.Name = "FaceRim"
	b.MouseButton1Down:Connect(function() UI.tween(face, 0.06, { Position = UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Up:Connect(function() UI.tween(face, 0.2, { Position = UDim2.new() }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() UI.tween(face, 0.2, { Position = UDim2.new() }, Enum.EasingStyle.Back) end)
	local row = UI.new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3, Parent = b })
	UI.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if o.icon then
		UI.icon(row, o.icon, o.iconSize or 24, { Name = "Icon", LayoutOrder = 1 })
	end
	local t
	if o.text then
		t = UI.new("TextLabel", {
			Name = "Label", Text = o.text, TextSize = math.floor((o.textSize or 20) * 0.9 + 0.5), FontFace = UI.F.heavy,
			TextColor3 = kind[3], AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = row,
		})
	end
	b.MouseButton1Down:Connect(function() UI.tween(row, 0.06, { Position = UDim2.fromOffset(0, 3) }, Enum.EasingStyle.Quad) end)
	b.MouseButton1Up:Connect(function() UI.tween(row, 0.2, { Position = UDim2.new() }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() UI.tween(row, 0.2, { Position = UDim2.new() }, Enum.EasingStyle.Back) end)
	if o.key and (not UIS.TouchEnabled or UIS.KeyboardEnabled or UIS.GamepadEnabled) then
		local k = UI.new("TextLabel", {
			Name = "Key", Text = o.key, TextSize = 12, FontFace = UI.F.heavy, TextColor3 = T.cream,
			BackgroundColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -4, 0, -4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = b,
		})
		UI.corner(k, 6)
		UI.stroke(k, 1.25, T.line, 0)
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
	UI.animate(b, { hover = o.hover or 1.03, sound = o.sound })
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
		if rim then rim.Transparency = kindName == "ink" and 0 or 1 end
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
	if b:FindFirstChild("Face") then UI.tween(b.Face, 0.2, { BackgroundTransparency = off and 0.55 or 0 }) end
	if b:FindFirstChild("Base") then UI.tween(b.Base, 0.2, { BackgroundTransparency = off and 0.7 or 0 }) end
	local row = b:FindFirstChild("Row")
	if row then
		for _, c in ipairs(row:GetChildren()) do
			if c:IsA("TextLabel") then UI.tween(c, 0.2, { TextTransparency = off and 0.45 or 0 }) end
			if c:IsA("ImageLabel") then UI.tween(c, 0.2, { ImageTransparency = off and 0.5 or 0 }) end
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

-- a square icon button with a tooltip
function UI.iconButton(parent, o)
	local b = UI.new("ImageButton", {
		Name = o.name or "IconButton",
		Size = o.size or UDim2.fromOffset(46, 46),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		BackgroundColor3 = o.color or T.ink2,
		BackgroundTransparency = o.transparency or 0,
		LayoutOrder = o.order or 0,
		Parent = parent,
	})
	UI.corner(b, math.min(o.radius or 12, 14))
	if o.icon then
		UI.icon(b, o.icon, o.iconSize or 28, { Name = "Icon", Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	end
	if o.text then
		UI.label(b, o.text, o.textSize or 18, {
			Name = "Label", FontFace = UI.F.heavy, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = UI.isLight(o.color or T.ink2) and T.cream or T.white,
		})
	end
	UI.animate(b, { hover = 1.07 })
	if o.tip then UI.tooltip(b, o.tip) end
	if o.onClick then
		b.Activated:Connect(function()
			UI.sound("Click")
			o.onClick(b)
		end)
	end
	return b
end

-- the X in a panel's corner: a quiet circle that turns coral and spins a quarter when you reach for it
function UI.closeButton(parent, onClose)
	local b = UI.iconButton(parent, {
		name = "Close", text = "", size = UDim2.fromOffset(36, 36), pos = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0), color = T.ink2, radius = 18,
		onClick = onClose,
	})
	UI.corner(b, UDim.new(0.5, 0))
	b.ZIndex = 6
	table.insert(UI.closers, { b = b, fn = onClose })
	local bars = {}
	for _, r in ipairs({ 45, -45 }) do
		local bar = UI.new("Frame", {
			Size = UDim2.fromOffset(16, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = r, BackgroundColor3 = T.muted, ZIndex = 7, Parent = b,
		})
		UI.corner(bar, 2)
		table.insert(bars, bar)
	end
	b.MouseEnter:Connect(function()
		UI.tween(b, 0.18, { BackgroundColor3 = T.red, Rotation = 90 })
		for _, bar in ipairs(bars) do UI.tween(bar, 0.15, { BackgroundColor3 = T.white }) end
	end)
	b.MouseLeave:Connect(function()
		UI.tween(b, 0.22, { BackgroundColor3 = T.ink2, Rotation = 0 })
		for _, bar in ipairs(bars) do UI.tween(bar, 0.2, { BackgroundColor3 = T.muted }) end
	end)
	return b
end

---------------------------------------------------------------- tabs, toggles, sliders, segments

---------------------------------------------------------------- tabs, toggles, sliders, segments

-- tabs: list of { id, text, icon }; returns { select(id), buttons }. A violet bar slides under the active tab.
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
		UI.corner(b, 10)
		UI.pad(b, 12, 0, 12, 0)
		local tst = UI.stroke(b, 2.5, T.outline, 1)
		tst.Name = "TabRim"
		local inner = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Parent = b })
		UI.list(inner, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
		if it.icon then UI.icon(inner, it.icon, 22, { Name = "Icon", LayoutOrder = 1 }) end
		local tl = UI.new("TextLabel", {
			Name = "Label", Text = it.text, TextSize = math.floor((opts.textSize or 17) * 0.88 + 0.5), FontFace = UI.F.heavy, TextColor3 = T.muted,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = inner,
		})
		local rim = UI.wordRim(tl, 2)
		rim.Enabled = false
		b.MouseEnter:Connect(function()
			if api.current ~= it.id then UI.tween(b, 0.15, { BackgroundTransparency = 0 }) end
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
				l.TextColor3 = on and T.brand or T.muted
				local rim = l:FindFirstChild("Rim")
				if rim then rim.Enabled = false end
			end
			UI.tween(b, 0.2, { BackgroundTransparency = on and 0 or 1, BackgroundColor3 = on and T.brandSoft or T.ink2 })
			local tr = b:FindFirstChild("TabRim")
			if tr then tr.Transparency = 1 end
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

-- an on/off switch; returns frame, set(on)
function UI.toggle(parent, on, onChange, opts)
	opts = opts or {}
	local b = UI.new("TextButton", {
		Name = opts.name or "Toggle", Text = "", Size = UDim2.fromOffset(52, 30),
		Position = opts.pos or UDim2.new(), AnchorPoint = opts.anchor or Vector2.new(),
		BackgroundColor3 = on and T.green or T.ink3, LayoutOrder = opts.order or 0, Parent = parent,
	})
	UI.corner(b, 15)
	local knob = UI.new("Frame", {
		Size = UDim2.fromOffset(24, 24), Position = on and UDim2.new(1, -27, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.white, Parent = b,
	})
	UI.corner(knob, 12)
	local state = on
	local function set(v, silent)
		state = v
		UI.tween(b, 0.22, { BackgroundColor3 = v and T.green or T.ink3 })
		UI.tween(knob, 0.32, { Position = v and UDim2.new(1, -27, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
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
		Name = opts.name or "Segmented", Size = opts.size or UDim2.new(1, 0, 0, 34), Position = opts.pos or UDim2.new(),
		BackgroundColor3 = T.ink2, LayoutOrder = opts.order or 0, Parent = parent,
	})
	UI.corner(f, 10)
	local pill = UI.new("Frame", { Name = "Pill", BackgroundColor3 = T.brand, Size = UDim2.new(1 / #items, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = f })
	UI.corner(pill, 8)
	local btns = {}
	local api = {}
	function api.set(id, silent)
		for i, it in ipairs(items) do
			local on = it.id == id
			if on then UI.tween(pill, 0.3, { Position = UDim2.new((i - 1) / #items, 3, 0, 3) }, Enum.EasingStyle.Back) end
			UI.tween(btns[i], 0.2, { TextColor3 = on and T.white or T.muted })
		end
		api.current = id
		if not silent and onChange then onChange(id) end
	end
	for i, it in ipairs(items) do
		local b = UI.new("TextButton", {
			Text = it.text, TextSize = math.floor((opts.textSize or 15) * 0.9 + 0.5), FontFace = UI.F.heavy, TextColor3 = T.muted,
			Size = UDim2.new(1 / #items, 0, 1, 0), Position = UDim2.fromScale((i - 1) / #items, 0), ZIndex = 3, Parent = f,
		})
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
	local track = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 6), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink3, Parent = f })
	UI.corner(track, 3)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.gold, Parent = track })
	UI.corner(fill, 3)
	local knob = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = T.white, Parent = track })
	UI.corner(knob, 9)
	local ks = Instance.new("UIStroke") ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border ks.Thickness = 4 ks.Color = T.brand ks.Parent = knob
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
				TextSize = 13, FontFace = UI.F.bold, BackgroundColor3 = T.night, BackgroundTransparency = 0, TextColor3 = T.white,
				AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), AnchorPoint = Vector2.new(0.5, 1), Visible = false, Parent = tipGui,
			})
			UI.corner(tipLabel, 8)
			UI.pad(tipLabel, 10, 6, 10, 6)
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

-- UI.toast("Room 104 is open!", icon, "good"|"bad"|nil): a white slip slides in at the top right, stacking down
local toastGui, toastList
function UI.toast(text, icon, kind)
	if not toastGui then
		local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
		toastGui = UI.new("ScreenGui", { Name = "Toasts", DisplayOrder = 40, ResetOnSpawn = false, Parent = pg })
		toastList = UI.new("Frame", {
			Size = UDim2.fromOffset(360, 300), Position = UDim2.new(1, -18, 0, 86), AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1, Parent = toastGui,
		})
		UI.list(toastList, nil, 10, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
		UI.autoScale(toastList)
	end
	local accent = kind == "bad" and T.red or kind == "good" and T.green or T.brand
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(340, 54), BackgroundTransparency = 1, LayoutOrder = os.clock() * 100, Parent = toastList })
	local slip = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(400, 0), BackgroundTransparency = 1, Parent = holder })
	UI.shadow(slip, { drop = 6, transparency = 0.78 })
	local card = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.paper, Parent = slip })
	UI.corner(card, 14)
	local tile = UI.new("Frame", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = accent, Parent = card })
	UI.corner(tile, 11)
	if icon then
		UI.icon(tile, icon, 26, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	else
		UI.dot(tile, 10, T.white, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	end
	UI.label(card, text, 15, {
		Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -68, 1, 0), TextWrapped = true, FontFace = UI.F.bold,
		TextColor3 = T.cream,
	})
	local bar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, -3), BackgroundColor3 = accent, Parent = card })
	UI.tween(slip, 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	UI.pop(tile, 0.3, 0.5)
	UI.tween(bar, 3.6, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	task.delay(3.6, function()
		UI.tween(slip, 0.3, { Position = UDim2.fromOffset(400, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.tween(card, 0.3, { GroupTransparency = 1 })
		task.wait(0.3)
		UI.tween(holder, 0.2, { Size = UDim2.fromOffset(340, 0) })
		task.wait(0.2)
		holder:Destroy()
	end)
	UI.sound(kind == "bad" and "Error" or "Toast")
end

return UI
