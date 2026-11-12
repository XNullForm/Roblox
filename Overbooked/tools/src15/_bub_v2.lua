--@@HELPERS
-- text sizes for the bubble (Builder Sans; falls back to a Gotham estimate if the async measure fails)
local SAY_SIZE = 17
local function measure(text, width)
	local ok, v = pcall(function()
		local p = Instance.new("GetTextBoundsParams")
		p.Text = text
		p.Font = UI.F.bold
		p.Size = SAY_SIZE
		p.Width = width
		return TextService:GetTextBoundsAsync(p)
	end)
	if ok and v then return v end
	return TextService:GetTextSize(text, SAY_SIZE, Enum.Font.GothamBold, Vector2.new(width, 1000))
end
-- the bubble's size for a line: as wide as the line (up to SAY_W), as tall as it wraps
local function fitBubble(line)
	local one = measure(line, 10000)
	local w = math.clamp(math.ceil(one.X) + 4, 40, SAY_W)
	local fit = measure(line, w)
	return w + 32, math.ceil(fit.Y) + 22 + 14
end

local BUB_TOP = Color3.new(1, 1, 1)
local BUB_BOT = Color3.fromRGB(238, 234, 252)
local BUB_RIM = Color3.fromRGB(206, 198, 244)
-- a speech bubble: a glossy white card with a soft lavender rim, a curved tail (rim and fill images stacked so
-- the outline runs round it) and a name chip on its top-left corner. Returns the parts.
local function makeBubble(parent, order)
	local slot = UI.new("Frame", { Name = "Say", Size = UDim2.fromOffset(120, 50), BackgroundTransparency = 1, LayoutOrder = order or 10, Visible = false, Parent = parent })
	local pop = UI.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 1), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = slot })
	local scale = Instance.new("UIScale")
	scale.Parent = pop
	local sh = UI.shadow(pop, { drop = 6, transparency = 0.6 })
	sh.Size = UDim2.new(1, 56, 1, 42)
	local box = UI.new("Frame", { Name = "Box", Size = UDim2.new(1, 0, 1, -14), BackgroundColor3 = T.white, ZIndex = 2, Parent = pop })
	UI.corner(box, 18)
	local grad = UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(BUB_TOP, BUB_BOT), Parent = box })
	local rim = UI.rim(box, BUB_RIM, 2.5)
	local gl = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 3), BackgroundColor3 = T.white, BackgroundTransparency = 0.2, ZIndex = 2, Parent = box })
	UI.corner(gl, 8)
	local tailRim = UI.new("ImageLabel", { Image = UI.IMG.tailRim, ImageColor3 = BUB_RIM, Size = UDim2.fromOffset(32, 23), Position = UDim2.new(0.5, -24, 1, -17), ZIndex = 3, Parent = pop })
	local tailFill = UI.new("ImageLabel", { Image = UI.IMG.tailFill, ImageColor3 = BUB_BOT, Size = UDim2.fromOffset(32, 23), Position = UDim2.new(0.5, -24, 1, -17), ZIndex = 4, Parent = pop })
	local text = UI.new("TextLabel", {
		Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 1, -20), Text = "", TextSize = SAY_SIZE, FontFace = UI.F.bold,
		TextColor3 = T.cream, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = box,
	})
	local who = UI.chip(pop, "", T.brand, { TextSize = 14, Size = UDim2.fromOffset(0, 22), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(12, 0), ZIndex = 6 })
	-- the three dots while the voice loads
	local dots = UI.new("Frame", { Size = UDim2.fromOffset(42, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = box })
	local dotList = {}
	local DOTC = { T.brand, T.violet, T.blue }
	for i = 1, 3 do dotList[i] = UI.dot(dots, 10, DOTC[i], { Position = UDim2.fromOffset((i - 1) * 16, 1), ZIndex = 5 }) end
	return { slot = slot, pop = pop, scale = scale, box = box, grad = grad, rim = rim, tailRim = tailRim, tailFill = tailFill, text = text, who = who, dots = dots, dotList = dotList }
end
-- moods tint the bubble: a cross guest's goes rosy with a red rim, a delighted one golden
local MOODTINT = {
	angry = { Color3.fromRGB(255, 232, 234), Color3.fromRGB(240, 110, 124) },
	grump = { Color3.fromRGB(255, 238, 236), Color3.fromRGB(230, 150, 150) },
	happy = { Color3.fromRGB(255, 248, 222), Color3.fromRGB(250, 200, 90) },
}
local function tintBubble(b, mood)
	local t = MOODTINT[mood or ""]
	local bot, rim = t and t[1] or BUB_BOT, t and t[2] or BUB_RIM
	b.grad.Color = ColorSequence.new(BUB_TOP, bot)
	b.rim.Color = rim
	b.tailRim.ImageColor3 = rim
	b.tailFill.ImageColor3 = bot
end

--@@BUILD
	-- staff tag ------------------------------------------------------------
	-- a glossy name plate (name + level chip) with the job on a coloured ribbon under it
	local tag = UI.new("Frame", { Name = "Tag", Size = UDim2.fromOffset(0, 54), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 30, Visible = false, Parent = stack })
	UI.list(tag, Enum.FillDirection.Vertical, -4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
	local top = UI.new("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.white, LayoutOrder = 1, ZIndex = 2, Parent = tag })
	UI.corner(top, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 228, 250)), Parent = top })
	local topRim = UI.rim(top, T.brand, 2.5)
	UI.pad(top, 12, 0, 5, 0)
	UI.list(top, Enum.FillDirection.Horizontal, 7, nil, Enum.VerticalAlignment.Center)
	local tagName = UI.new("TextLabel", { Text = "", TextSize = 17, FontFace = UI.F.display, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 30), LayoutOrder = 1, ZIndex = 3, Parent = top })
	local tagLv = UI.chip(top, "LV 1", T.brand, { TextSize = 13, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, ZIndex = 3 })
	local ribbon = UI.new("Frame", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.brand, LayoutOrder = 2, ZIndex = 1, Parent = tag })
	UI.corner(ribbon, 7)
	UI.sheen(ribbon)
	local ribbonRim = UI.rim(ribbon, T.brandDk, 2)
	UI.pad(ribbon, 10, 4, 10, 0)
	local tagRole = UI.new("TextLabel", { Text = "", TextSize = 12, FontFace = UI.F.display, TextColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), ZIndex = 2, Parent = ribbon })
	local roleStroke = UI.textStroke(tagRole, 1.5, 0, T.brandDk)

	-- status disc ------------------------------------------------------------
	local discSlot = UI.new("Frame", { Name = "Status", Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, LayoutOrder = 20, Visible = false, Parent = stack })
	local discGlow = UI.glow(discSlot, 90, T.white, { ImageTransparency = 0.45 })
	local disc = UI.new("Frame", { Size = UDim2.fromOffset(50, 50), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.white, ZIndex = 2, Parent = discSlot })
	UI.corner(disc, UDim.new(0.5, 0))
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 222, 246)), Parent = disc })
	UI.rim(disc, BUB_RIM, 2)
	local track = UI.new("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2, Parent = disc })
	UI.corner(track, UDim.new(0.5, 0))
	UI.rim(track, Color3.fromRGB(230, 226, 248), 4)
	local _, setRing, ringStrokes = UI.ring(disc, 46, 4, T.green, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
	local icon = UI.icon(disc, "", 32, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	local badge = UI.badge(disc, 24, T.sun, nil, { Position = UDim2.new(1, 6, 0, -6), AnchorPoint = Vector2.new(1, 0), Visible = false, ZIndex = 5 })
	local badgeIcon = UI.icon(badge, "", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 8 })

	-- speech ------------------------------------------------------------
	local B = makeBubble(stack, 10)
	local saySlot, sayPop, sayScale, sayText, who, dots, dotList = B.slot, B.pop, B.scale, B.text, B.who, B.dots, B.dotList

--@@TAGCOL
		local col = model:GetAttribute("BRoleColor") or T.brand
		local deep = UI.shade(col, -0.42)
		tagLv.BackgroundColor3 = col
		if tagLv:FindFirstChild("Rim") then tagLv.Rim.Color = deep end
		for _, st in ipairs(tagLv:GetChildren()) do
			if st:IsA("UIStroke") and st.Name ~= "Rim" then st.Color = UI.shade(col, -0.45) end
		end
		tagLv.TextColor3 = T.white
		topRim.Color = col
		ribbon.BackgroundColor3 = col
		ribbonRim.Color = deep
		roleStroke.Color = deep
--@@SAYFIT
		who.Text = first
		local wc = model:GetAttribute("BRoleColor") or TAGS[hash(first) % #TAGS + 1]
		who.BackgroundColor3 = wc
		for _, st in ipairs(who:GetChildren()) do
			if st:IsA("UIStroke") then st.Color = UI.shade(wc, st.Name == "Rim" and -0.38 or -0.45) end
		end
		who.Visible = not m.staff -- staff already wear their name
		tintBubble(B, voiceOpts and voiceOpts.mood)
		-- fit the bubble to the line
		local w, h = fitBubble(line)
		saySlot.Size = UDim2.fromOffset(w, h)
--@@CHATREC
	if not rec or not rec.bb.Parent then
		local bb = UI.new("BillboardGui", {
			Name = "ChatBubble", Size = UDim2.fromOffset(360, 220), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.9, 0),
			LightInfluence = 0, MaxDistance = HEAR + 20, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = head, Parent = pgui,
		})
		local stack = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
		UI.list(stack, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
		local B = makeBubble(stack, 1)
		local nm = pl.DisplayName
		B.who.Text = nm
		local wc = TAGS[hash(nm) % #TAGS + 1]
		B.who.BackgroundColor3 = wc
		for _, st in ipairs(B.who:GetChildren()) do
			if st:IsA("UIStroke") then st.Color = UI.shade(wc, st.Name == "Rim" and -0.38 or -0.45) end
		end
		rec = { bb = bb, slot = B.slot, sc = B.scale, txt = B.text, n = 0 }
		chatBubbles[char] = rec
	end
