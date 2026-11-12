---------------------------------------------------------------- custom prompts (round 15 v2)
-- A glossy white capsule on a deep shadow, floating over the thing: a big shaded key disc in the prompt's colour
-- on the left (a ring round it fills while you hold), the action in fat letters with what it's for under it, and
-- the icon in a soft tinted disc on the right. A little tail points down at the spot. It springs in, bobs, glows
-- its colour on hover, sinks when pressed, and when it fires a shine sweeps it, sparkles pop and the icon flips
-- to a tick. Prompts carry attributes Icon (a C.ICONS key) and Color (yellow / green / blue / red).

local COLORS = {
	yellow = { T.sun, T.sunDk },
	green = { T.green, T.greenDk },
	blue = { T.blue, T.blueDk },
	red = { T.red, T.redDk },
	violet = { T.brand, T.brandDk },
}

local shown = {}

local function keyText(prompt)
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then return nil end
	if UIS.GamepadEnabled and not UIS.KeyboardEnabled then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local PS = (player:GetAttribute("PromptSize") or 100) / 100
player:GetAttributeChangedSignal("PromptSize"):Connect(function()
	PS = (player:GetAttribute("PromptSize") or 100) / 100
end)
local CAP_RIM = Color3.fromRGB(204, 196, 244)
local function buildPrompt(prompt)
	local cols = COLORS[prompt:GetAttribute("Color") or "yellow"] or COLORS.yellow
	local hold = prompt.HoldDuration > 0
	local key = keyText(prompt)
	local H = 64

	local bb = UI.new("BillboardGui", { Name = "Prompt", Size = UDim2.fromOffset(680 * PS, 170 * PS), AlwaysOnTop = true, LightInfluence = 0, Active = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = prompt.Parent, Parent = pgui })
	local root = UI.new("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 16), Size = UDim2.fromScale(1 / PS, 1 / PS), BackgroundTransparency = 1, Parent = bb })
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = root
	-- the float wrapper carries the idle bob so no other animation ever fights over Position
	local float = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

	local wrap = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, H), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = float })
	UI.shadow(wrap, { drop = 9, transparency = 0.52, spread = 2 })
	-- the tail: a white wedge under the capsule pointing at the spot
	local tail = UI.new("ImageLabel", { Name = "Tail", Image = UI.IMG.tail, ImageColor3 = Color3.fromRGB(234, 230, 250), Size = UDim2.fromOffset(26, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -3), ZIndex = 1, Parent = wrap })
	local card = UI.new("Frame", { Name = "Card", Size = UDim2.fromOffset(0, H), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, ZIndex = 2, Parent = wrap })
	UI.corner(card, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 228, 250)), Parent = card })
	local baseRim = UI.rim(card, CAP_RIM, 2.5)
	baseRim.Name = "BaseRim"
	-- the colour glow ring (hover / hold)
	local hi = UI.new("Frame", { Name = "Hi", Size = UDim2.new(1, 8, 1, 8), Position = UDim2.fromOffset(-4, -4), BackgroundTransparency = 1, ZIndex = 1, Parent = card })
	UI.corner(hi, UDim.new(0.5, 0))
	local cardStroke = UI.rim(hi, cols[1], 3.5)
	cardStroke.Transparency = 1
	local gl = UI.new("Frame", { Name = "Gloss", Size = UDim2.new(1, -24, 0.42, 0), Position = UDim2.fromOffset(12, 3), BackgroundColor3 = T.white, BackgroundTransparency = 0.25, ZIndex = 2, Parent = card })
	UI.corner(gl, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1), Parent = gl })

	local content = UI.new("Frame", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 3, Parent = card })
	UI.list(content, Enum.FillDirection.Horizontal, 12, nil, Enum.VerticalAlignment.Center)
	local contentPad = UI.pad(content, 7, 0, 10, 0)

	-- the key: a shaded disc in the prompt's colour inside a ring that fills clockwise while you hold
	local kc = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 3, Parent = content })
	local ringTrack = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3, Parent = kc })
	UI.corner(ringTrack, UDim.new(0.5, 0))
	UI.rim(ringTrack, Color3.fromRGB(226, 222, 246), 4)
	local track = UI.badge(kc, 42, cols[1], nil, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
	local _, setRingRaw, ringStrokes = UI.ring(kc, 52, 4, cols[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 })
	local dsc = Instance.new("UIScale")
	dsc.Parent = kc
	local iconImg = ICON[prompt:GetAttribute("Icon") or "star"] or ICON.star
	if key then
		local kl = UI.new("TextLabel", {
			Name = "Key", Text = key, TextSize = #key > 1 and 14 or 24, FontFace = UI.F.display, TextColor3 = T.white,
			Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = track,
		})
		UI.textStroke(kl, 2, 0, cols[2])
	end

	-- the words
	local col = UI.new("Frame", { Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 3, Parent = content })
	UI.list(col, nil, 0, nil, Enum.VerticalAlignment.Center)
	local title = UI.new("TextLabel", { Text = prompt.ActionText, TextSize = 23, FontFace = UI.F.display, TextColor3 = T.cream, TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 4, Parent = col })
	local sub = UI.new("TextLabel", { Text = string.upper(prompt.ObjectText), TextSize = 13, FontFace = UI.F.heavy, TextColor3 = T.muted, TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 4, Parent = col })
	sub.Visible = prompt.ObjectText ~= ""
	if hold then
		sub.Visible = true
		sub.Text = (prompt.ObjectText ~= "" and (string.upper(prompt.ObjectText) .. "  -  ") or "") .. "HOLD"
	end

	-- the icon in a soft disc of the prompt's colour on the right
	local badge = UI.new("Frame", { Size = UDim2.fromOffset(48, 48), BackgroundColor3 = UI.shade(cols[1], 0.72), LayoutOrder = 3, ZIndex = 3, Parent = content })
	UI.corner(badge, UDim.new(0.5, 0))
	UI.rim(badge, UI.shade(cols[1], 0.2), 2)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 210, 228)), Parent = badge })
	local icon = UI.icon(badge, iconImg, 38, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	if not key then
		-- touch: the key disc has nothing to say, so the icon lives there instead and the right disc goes
		badge.Parent = track
		badge.Size = UDim2.fromScale(1, 1)
		badge.BackgroundTransparency = 1
		if badge:FindFirstChild("Rim") then badge.Rim.Enabled = false end
		icon.Size = UDim2.fromOffset(32, 32)
		icon.ZIndex = 8
		contentPad.PaddingRight = UDim.new(0, 22)
	end
	local playShine = UI.shine(card, 32)

	local function setRing(k)
		setRingRaw(math.clamp(k, 0, 1))
	end
	setRing(0)

	-- click / tap anywhere on the capsule = press the prompt
	local hit = UI.new("TextButton", { Text = "", Position = UDim2.fromOffset(-8, -8), Size = UDim2.new(1, 16, 1, 16), BackgroundTransparency = 1, ZIndex = 9, Parent = card })
	hit.MouseButton1Down:Connect(function() prompt:InputHoldBegin() end)
	hit.MouseButton1Up:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseLeave:Connect(function() prompt:InputHoldEnd() end)
	hit.MouseEnter:Connect(function()
		UI.tween(sc, 0.2, { Scale = 1.07 * PS }, Enum.EasingStyle.Back)
		UI.tween(cardStroke, 0.15, { Transparency = 0.15 })
		playShine()
	end)
	hit.MouseLeave:Connect(function()
		UI.tween(sc, 0.2, { Scale = PS }, Enum.EasingStyle.Quint)
		UI.tween(cardStroke, 0.2, { Transparency = 1 })
	end)

	-- arrive: springs up from the spot, the key lands a beat later, the words fade in, a shine crosses
	UI.tween(sc, 0.46, { Scale = PS }, Enum.EasingStyle.Back)
	UI.tween(root, 0.46, { Position = UDim2.new(0.5, 0, 0.5, 0) }, Enum.EasingStyle.Quint)
	dsc.Scale = 0.2
	UI.tween(dsc, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.08)
	UI.tween(title, 0.22, { TextTransparency = 0 }, nil, nil, 0.1)
	UI.tween(sub, 0.22, { TextTransparency = 0 }, nil, nil, 0.16)
	task.delay(0.25, playShine)

	local s = { bb = bb, scale = sc, dsc = dsc, setRing = setRing, ringStrokes = ringStrokes, icon = icon, iconImg = iconImg, cols = cols, title = title, sub = sub, float = float, card = card, cardStroke = cardStroke, badge = badge, hold = hold, shine = playShine, wrap = wrap }
	s.conn = RunService.RenderStepped:Connect(function(dt)
		s.bob = (s.bob or 0) + dt
		s.float.Position = UDim2.fromScale(0.5, 0.5) - UDim2.fromOffset(0, math.sin(s.bob * 2.2) * 3)
		if s.holdT0 then
			setRing((os.clock() - s.holdT0) / math.max(prompt.HoldDuration, 0.01))
		end
	end)
	local c1 = prompt:GetPropertyChangedSignal("ActionText"):Connect(function() title.Text = prompt.ActionText end)
	local c2 = prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		sub.Text = (prompt.ObjectText ~= "" and string.upper(prompt.ObjectText) or "") .. (hold and (prompt.ObjectText ~= "" and "  -  HOLD" or "HOLD") or "")
		sub.Visible = sub.Text ~= ""
	end)
	s.extra = { c1, c2 }
	return s
end

-- round 12: the desk buttons on guests (tag DeskPrompt) only show while you sit in a front desk chair
-- (a Seat named DeskSeat); the server checks it too. Prompts are switched locally, Busy = a game is running.
do
	local CS = game:GetService("CollectionService")
	local function seated()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local sp = hum and hum.SeatPart
		return sp ~= nil and sp.Name == "DeskSeat"
	end
	task.spawn(function()
		while true do
			local on = seated()
			for _, pr in ipairs(CS:GetTagged("DeskPrompt")) do
				local want = on and not pr:GetAttribute("Busy")
				if pr.Enabled ~= want then pr.Enabled = want end
			end
			task.wait(0.2)
		end
	end)
end

PPS.PromptShown:Connect(function(prompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	-- other people's hotels: no buttons (the server turns their prompts down too)
	if prompt:IsDescendantOf(PLOTS) and not prompt:IsDescendantOf(HOTEL) then return end
	if shown[prompt] then return end
	shown[prompt] = buildPrompt(prompt)
end)

-- prompts that land on top of each other on screen (Talk on a guest at the desk and Check In) stack upwards
do
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		local cam = workspace.CurrentCamera
		local list = {}
		for prompt, s in pairs(shown) do
			local ad = s.bb.Adornee
			local pos = ad and (ad:IsA("Attachment") and ad.WorldPosition or ad:IsA("BasePart") and ad.Position)
			if pos then
				local v, on = cam:WorldToViewportPoint(pos)
				if on then table.insert(list, { s = s, x = v.X, y = v.Y, key = prompt:GetFullName() }) end
			end
		end
		table.sort(list, function(a, b) return a.y > b.y or (a.y == b.y and a.key < b.key) end)
		local placed = {}
		for _, e in ipairs(list) do
			local lift = 0
			for _, o in ipairs(placed) do
				if math.abs(o.x - e.x) < 300 * PS and math.abs((o.y - o.lift * 76 * PS) - (e.y - lift * 76 * PS)) < 70 * PS then lift = o.lift + 1 end
			end
			e.lift = lift
			table.insert(placed, e)
			local want = Vector2.new(0, lift * 0.46)
			if e.s.bb.SizeOffset ~= want then e.s.bb.SizeOffset = want end
		end
	end)
end

PPS.PromptHidden:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	shown[prompt] = nil
	s.conn:Disconnect()
	for _, c in ipairs(s.extra) do c:Disconnect() end
	UI.tween(s.title, 0.12, { TextTransparency = 1 })
	UI.tween(s.sub, 0.12, { TextTransparency = 1 })
	local tw = UI.tween(s.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0.04)
	tw.Completed:Wait()
	s.bb:Destroy()
end)

PPS.PromptButtonHoldBegan:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	if prompt.HoldDuration > 0 then s.holdT0 = os.clock() end
	UI.tween(s.dsc, 0.12, { Scale = 0.88 })
	UI.tween(s.cardStroke, 0.12, { Transparency = 0 })
end)

PPS.PromptButtonHoldEnded:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.holdT0 = nil
	if not s.flash then s.setRing(0) end
	UI.tween(s.dsc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(s.cardStroke, 0.25, { Transparency = 1 })
end)

PPS.PromptTriggered:Connect(function(prompt)
	local s = shown[prompt]
	if not s then return end
	s.holdT0 = nil
	s.flash = (s.flash or 0) + 1
	local n = s.flash
	-- the ring closes, the capsule flashes its colour and jumps, the icon flips to a tick, then it settles
	s.setRing(1)
	s.dsc.Scale = 1.3
	UI.tween(s.dsc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	s.scale.Scale = 1.14 * PS
	UI.tween(s.scale, 0.4, { Scale = PS }, Enum.EasingStyle.Back)
	s.icon.Image = ICON.checkmark
	s.badge.Rotation = -90
	UI.tween(s.badge, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	s.card.BackgroundColor3 = s.cols[1]:Lerp(Color3.new(1, 1, 1), 0.5)
	UI.tween(s.card, 0.5, { BackgroundColor3 = T.white })
	if s.shine then s.shine(0.45) end
	UI.sparkles(s.wrap, 5, s.cols[1], 1.1)
	task.delay(0.6, function()
		if s.flash ~= n then return end
		s.flash = nil
		s.icon.Image = s.iconImg
		UI.pop(s.icon, 0.6, 0.3)
		s.setRing(0)
	end)
end)
