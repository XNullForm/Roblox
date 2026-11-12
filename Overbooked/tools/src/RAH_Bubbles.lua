-- StarterPlayerScripts.RAH_Bubbles (round 10c): the status bubbles over guests' and staff's heads.
-- The server publishes what each one says as attributes on the model (tag RAH_Bubble; see the status bubble
-- section of RAH_HotelSim); every client draws its own here. A bubble is an ink pill led by an icon disc whose
-- ring shows the timer (a patience timer runs green > yellow > red and the disc shivers when it's nearly out),
-- the name under it with a mood face (guests) or the job (staff), an event badge on the pill's corner, and
-- speech that pops up above with the words typing in. Only the nearest few show words; further off a bubble
-- shrinks to its disc, and past FAR it's gone. Player attributes RAH_HideBubbles (Settings) and RAH_Building hide them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local RS = game:GetService("ReplicatedStorage")

local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local BAR = { yellow = T.gold, blue = T.blue, purple = T.violet, green = T.green, red = T.red }
local NEAR = 34 -- words inside this
local FAR = 85 -- the disc alone out to here
local WORDS_MAX = 5 -- at most this many show words at once (the nearest)
local SAY_W = 230 -- speech wraps at this width
local INK_TEXT = Color3.fromRGB(34, 36, 52)

local bubbles = {} -- model -> b

local function hiddenAll()
	return player:GetAttribute("RAH_HideBubbles") == true or player:GetAttribute("RAH_Building") == true
end

local function patienceColor(k)
	if k > 0.5 then return T.green end
	if k > 0.25 then return T.gold end
	return T.red
end

---------------------------------------------------------------- one bubble

local function build(model)
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	if not head or not model.Parent then return end
	local b = { model = model, words = true }

	-- the gui's bottom edge sits just over the head; everything stacks up from there
	local bb = UI.new("BillboardGui", {
		Name = "RAH_Bubble", Size = UDim2.fromOffset(300, 220), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.3, 0),
		LightInfluence = 0, MaxDistance = FAR, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = head, Enabled = not hiddenAll(), Parent = pgui,
	})
	local root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local sc = Instance.new("UIScale")
	sc.Parent = root

	-- name (+ mood face, or the job for staff)
	local nameRow = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root })
	UI.list(nameRow, Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local mood = UI.icon(nameRow, "", 18, { LayoutOrder = 1, Visible = false })
	local name = UI.new("TextLabel", { Text = "", TextSize = 15, FontFace = UI.F.black, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 2, Parent = nameRow })
	UI.textStroke(name, 2, 0.25)
	local role = UI.new("TextLabel", { Text = "", TextSize = 13, FontFace = UI.F.heavy, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 3, Visible = false, Parent = nameRow })
	UI.textStroke(role, 2, 0.25)

	-- the status pill: [disc][words]
	local chip = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -26), Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, Parent = root,
	})
	UI.corner(chip, 18)
	local chipStroke = UI.stroke(chip, 1.5, T.gold, 0.6)
	local chipPad = UI.pad(chip, 0, 0, 14, 0)
	local inner = UI.new("Frame", { Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = chip })
	UI.list(inner, Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center)
	local disc = UI.new("Frame", { Size = UDim2.fromOffset(46, 46), BackgroundColor3 = T.ink, LayoutOrder = 1, Parent = inner })
	UI.corner(disc, UDim.new(0.5, 0))
	local track = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Parent = disc })
	UI.corner(track, UDim.new(0.5, 0))
	local trackStroke = UI.stroke(track, 3.5, T.line, 0.5)
	local _, setRing, ringStrokes = UI.ring(disc, 43, 3.5, T.gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local face = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = T.ink2, Parent = disc })
	UI.corner(face, UDim.new(0.5, 0))
	local icon = UI.icon(face, "", 26, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local words = UI.new("TextLabel", { Text = "", TextSize = 16, FontFace = UI.F.heavy, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2, Parent = inner })

	-- an event (VIP, birthday, inspector...) wears its icon on the pill's corner
	local badge = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 10, 0, 1), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = T.cream, Visible = false, ZIndex = 3, Parent = chip })
	UI.corner(badge, UDim.new(0.5, 0))
	UI.stroke(badge, 2, T.gold, 0)
	local badgeIcon = UI.icon(badge, "", 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })

	-- speech
	local sayBox = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.fromOffset(100, 34), BackgroundColor3 = T.cream, Visible = false, Parent = root })
	UI.corner(sayBox, 14)
	UI.stroke(sayBox, 1.5, T.goldDk, 0.35)
	local sayScale = Instance.new("UIScale")
	sayScale.Parent = sayBox
	local tail = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(13, 13), Rotation = 45, BackgroundColor3 = T.cream, ZIndex = 0, Parent = sayBox })
	local sayText = UI.new("TextLabel", {
		Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 1, -14), Text = "", TextSize = 16, FontFace = UI.F.bold,
		TextColor3 = INK_TEXT, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = sayBox,
	})

	b.bb, b.sc, b.chip, b.chipStroke, b.chipPad, b.words, b.icon, b.face, b.disc = bb, sc, chip, chipStroke, chipPad, words, icon, face, disc
	b.setRing, b.ringStrokes, b.track, b.trackStroke, b.nameRow = setRing, ringStrokes, track, trackStroke, nameRow
	b.sayBox, b.sayScale, b.sayText, b.tail = sayBox, sayScale, sayText, tail

	local function refreshName()
		name.Text = model:GetAttribute("BName") or model.Name
		local r = model:GetAttribute("BRole")
		role.Visible = r ~= nil
		role.Text = r or ""
		role.TextColor3 = model:GetAttribute("BRoleColor") or T.gold
		name.TextColor3 = T.cream
	end
	local function refreshMood()
		local m = model:GetAttribute("Mood")
		if model:GetAttribute("BRole") or not m then mood.Visible = false return end
		local img = (m >= 72 and ICON.happy) or (m <= 35 and ICON.angry) or nil
		if img and mood.Image ~= img then UI.pop(mood, 0.5, 0.35) end
		mood.Visible = img ~= nil
		mood.Image = img or ""
	end
	local function refreshStatus(first)
		local ic = ICON[model:GetAttribute("BIcon") or ""] or ICON.walk or ""
		local tx = model:GetAttribute("BText") or ""
		if not first and (ic ~= icon.Image or tx ~= words.Text) then
			UI.pop(face, 0.55, 0.4)
			words.TextTransparency = 0.6
			UI.tween(words, 0.25, { TextTransparency = 0 })
		end
		icon.Image = ic
		words.Text = tx
		chip.Visible = tx ~= "" or model:GetAttribute("BIcon") ~= nil
	end
	local function refreshEvent()
		local e = model:GetAttribute("BEvent")
		badge.Visible = e ~= nil
		badgeIcon.Image = e and ICON[e] or ""
		if e then UI.pop(badge, 0.3, 0.45) end
	end
	local function refreshSay()
		local line = model:GetAttribute("Say")
		if not line or line == "" then return end
		local secs = model:GetAttribute("SaySecs") or 3
		b.sayN = (b.sayN or 0) + 1
		local n = b.sayN
		-- fit the box to the line, wrapping at SAY_W
		local one = TextService:GetTextSize(line, 16, Enum.Font.BuilderSansBold, Vector2.new(10000, 100))
		local w = math.min(one.X, SAY_W)
		local fit = TextService:GetTextSize(line, 16, Enum.Font.BuilderSansBold, Vector2.new(w, 1000))
		sayBox.Size = UDim2.fromOffset(math.max(w, 30) + 26, fit.Y + 16)
		sayText.Text = line
		sayText.MaxVisibleGraphemes = 0
		sayBox.Visible = true
		sayScale.Scale = 0.4
		UI.tween(sayScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		UI.tween(sayText, math.clamp(#line * 0.022, 0.2, 1.1), { MaxVisibleGraphemes = utf8.len(line) or #line }, Enum.EasingStyle.Linear)
		task.delay(secs, function()
			if b.sayN ~= n or not sayBox.Parent then return end
			local tw = UI.tween(sayScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			tw.Completed:Wait()
			if b.sayN == n then sayBox.Visible = false end
		end)
	end

	refreshName()
	refreshMood()
	refreshStatus(true)
	refreshEvent()
	b.conns = {
		model:GetAttributeChangedSignal("BName"):Connect(refreshName),
		model:GetAttributeChangedSignal("BRole"):Connect(refreshName),
		model:GetAttributeChangedSignal("Mood"):Connect(refreshMood),
		model:GetAttributeChangedSignal("BIcon"):Connect(function() refreshStatus(false) end),
		model:GetAttributeChangedSignal("BText"):Connect(function() refreshStatus(false) end),
		model:GetAttributeChangedSignal("BEvent"):Connect(refreshEvent),
		model:GetAttributeChangedSignal("SayN"):Connect(refreshSay),
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then
				local x = bubbles[model]
				if x then
					bubbles[model] = nil
					for _, c in ipairs(x.conns) do c:Disconnect() end
					x.bb:Destroy()
				end
			end
		end),
	}

	-- arrive
	sc.Scale = 0
	UI.tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	return b
end

local function remove(model)
	local b = bubbles[model]
	if not b then return end
	bubbles[model] = nil
	for _, c in ipairs(b.conns) do c:Disconnect() end
	local tw = UI.tween(b.sc, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw.Completed:Wait()
	b.bb:Destroy()
end

local function add(model)
	if bubbles[model] or not model:IsA("Model") then return end
	bubbles[model] = true -- reserve while it builds
	local b = build(model)
	if bubbles[model] ~= true then
		if b then
			for _, c in ipairs(b.conns) do c:Disconnect() end
			b.bb:Destroy()
		end
		return
	end
	bubbles[model] = b
	if not b then bubbles[model] = nil end
end

CollectionService:GetInstanceAddedSignal("RAH_Bubble"):Connect(function(m) task.spawn(add, m) end)
CollectionService:GetInstanceRemovedSignal("RAH_Bubble"):Connect(function(m)
	if bubbles[m] == true then bubbles[m] = nil return end
	task.spawn(remove, m)
end)
for _, m in ipairs(CollectionService:GetTagged("RAH_Bubble")) do task.spawn(add, m) end

local function applyHidden()
	local off = hiddenAll()
	for _, b in pairs(bubbles) do
		if b ~= true then b.bb.Enabled = not off end
	end
end
player:GetAttributeChangedSignal("RAH_HideBubbles"):Connect(applyHidden)
player:GetAttributeChangedSignal("RAH_Building"):Connect(applyHidden)

---------------------------------------------------------------- every frame: timers, distance, who shows words

local function setWords(b, on)
	if b.wordsOn == on then return end
	b.wordsOn = on
	b.words.Visible = on
	b.nameRow.Visible = on
	b.chipPad.PaddingRight = UDim.new(0, on and 14 or 0)
	UI.tween(b.chip, 0.2, { BackgroundTransparency = on and 0.08 or 1 })
	UI.tween(b.chipStroke, 0.2, { Transparency = on and 0.6 or 1 })
end

local sortT = 0
local order = {}
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cpos = cam.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	sortT += dt
	local resort = sortT > 0.25
	if resort then
		sortT = 0
		table.clear(order)
	end
	for model, b in pairs(bubbles) do
		if b ~= true and b.bb.Adornee then
			local d = (b.bb.Adornee.Position - cpos).Magnitude
			b.dist = d
			b.sc.Scale = math.clamp(1.12 - d / 95, 0.6, 1.05)
			if resort then table.insert(order, b) end
			-- the timer ring
			local bar = model:GetAttribute("BBar")
			local t0, secs = model:GetAttribute("BT0"), model:GetAttribute("BSecs")
			if bar and t0 and secs and secs > 0 then
				local k = math.clamp((now - t0) / secs, 0, 1)
				if model:GetAttribute("BDrain") then k = 1 - k end
				b.setRing(k)
				local col = bar == "patience" and patienceColor(k) or BAR[bar] or T.gold
				for _, st in ipairs(b.ringStrokes) do st.Color = col end
				b.trackStroke.Transparency = 0.5
				-- nearly out of patience: the disc shivers
				if bar == "patience" and k < 0.25 then
					b.disc.Rotation = math.sin(clock * 30) * 7
				else
					b.disc.Rotation = 0
				end
			else
				b.setRing(0)
				b.trackStroke.Transparency = bar and 0.5 or 1
				b.disc.Rotation = 0
			end
		end
	end
	if resort then
		table.sort(order, function(a, c) return a.dist < c.dist end)
		for i, b in ipairs(order) do
			setWords(b, i <= WORDS_MAX and b.dist < NEAR)
		end
	end
end)
