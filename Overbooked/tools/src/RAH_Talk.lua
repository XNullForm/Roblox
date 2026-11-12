-- StarterPlayerScripts.RAH_Talk (round 10c): talking to guests, and the reviews they leave.
-- The Talk prompt on a guest (server: RAH_HotelSim talkTo) sends Notify "talk" with who they are, their mood
-- and the review they'd leave right now. This draws a conversation card at the bottom of the screen with their
-- portrait (a ViewportFrame copy of the guest), what they say (typed out), their mood and four replies.
-- A reply goes back on Remotes.Talk (guest model, option); the server answers with Notify "talkReply".
-- Notify "review" (a guest checked out) slides a review card in at the bottom right.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local T = UI.T
local Remotes = RAH:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local Talk = Remotes:WaitForChild("Talk", 30)

local gui = UI.new("ScreenGui", { Name = "RAH_Talk", DisplayOrder = 30, ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })

local MOOD_COL = {
	Delighted = Color3.fromRGB(96, 214, 128),
	Happy = Color3.fromRGB(150, 220, 110),
	Okay = Color3.fromRGB(232, 190, 106),
	Unhappy = Color3.fromRGB(240, 150, 80),
	Furious = Color3.fromRGB(240, 96, 96),
}

local function starRow(parent, size, pos)
	local row = UI.new("Frame", { Size = UDim2.fromOffset(size * 5 + 8, size), Position = pos, BackgroundTransparency = 1, Parent = parent })
	UI.list(row, Enum.FillDirection.Horizontal, 2)
	local icons = {}
	for i = 1, 5 do icons[i] = UI.icon(row, C.ICONS.starEmpty, size, { LayoutOrder = i }) end
	return row, function(n)
		for i = 1, 5 do icons[i].Image = i <= n and C.ICONS.star or C.ICONS.starEmpty end
	end
end

---------------------------------------------------------------- the conversation card

local W, H = 980, 256
local wrap = UI.new("Frame", { Name = "TalkWrap", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, Parent = gui })
UI.autoScale(wrap, Vector2.new(1500, 860))
local holder, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { name = "Talk", radius = 22 })

-- portrait
local frameP = UI.new("Frame", { Position = UDim2.fromOffset(20, 22), Size = UDim2.fromOffset(196, 196), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body })
UI.corner(frameP, 20)
UI.grad(frameP, Color3.fromRGB(62, 70, 104), Color3.fromRGB(28, 32, 50), 90)
UI.stroke(frameP, 2.5, T.gold, 0.15)
local vp = UI.new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 150, 165), LightColor = Color3.fromRGB(255, 244, 228), LightDirection = Vector3.new(-0.6, -0.8, -1), Parent = frameP })
local cam = Instance.new("Camera")
cam.FieldOfView = 26
cam.Parent = vp
vp.CurrentCamera = cam
-- mood chip over the portrait's lower edge
local chip = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(118, 218), Size = UDim2.fromOffset(150, 34), BackgroundColor3 = T.ink2, ZIndex = 4, Parent = body })
UI.corner(chip, 17)
local chipStroke = UI.stroke(chip, 2, T.gold, 0.05)
local dot = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.gold, ZIndex = 5, Parent = chip })
UI.corner(dot, 6)
local moodLbl = UI.label(chip, "Happy", 17, { FontFace = UI.F.black, Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -40, 1, 0), ZIndex = 5, TextColor3 = T.cream })

-- header
local X0 = 238
local nameLbl = UI.label(body, "Guest", 30, { FontFace = UI.F.black, Position = UDim2.fromOffset(X0, 16), Size = UDim2.new(1, -X0 - 250, 0, 34), TextTruncate = Enum.TextTruncate.AtEnd })
local subLbl = UI.label(body, "", 15, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(X0, 50), Size = UDim2.new(1, -X0 - 280, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
nameLbl.RichText = true
local rateLbl = UI.label(body, "WOULD RATE YOU", 12, { FontFace = UI.F.heavy, TextColor3 = T.muted, Position = UDim2.new(1, -258, 0, 20), Size = UDim2.fromOffset(150, 14) })
local _, setStars = starRow(body, 22, UDim2.new(1, -258, 0, 38))

-- what they say
local speech = UI.new("Frame", { Position = UDim2.fromOffset(X0, 78), Size = UDim2.new(1, -X0 - 22, 0, 70), BackgroundColor3 = T.ink2, Parent = body })
UI.corner(speech, 14)
UI.stroke(speech, 1.5, T.line, 0.35)
local bar = UI.new("Frame", { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(0, 4, 1, -24), BackgroundColor3 = T.gold, Parent = speech })
UI.corner(bar, 2)
local lineLbl = UI.label(speech, "", 21, { FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -40, 1, 0), TextWrapped = true })
-- the review they'd write right now
local reviewLbl = UI.label(body, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(X0, 152), Size = UDim2.new(1, -X0 - 22, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })

-- replies
local opts = UI.new("Frame", { Position = UDim2.fromOffset(X0, 196), Size = UDim2.new(1, -X0 - 22, 0, 44), BackgroundTransparency = 1, Parent = body })
UI.list(opts, Enum.FillDirection.Horizontal, 10)

local current -- { guest, info }
local typing = 0

local function typeOut(text)
	typing += 1
	local id = typing
	lineLbl.Text = '"' .. text .. '"'
	lineLbl.MaxVisibleGraphemes = 0
	task.spawn(function()
		local n = utf8.len(lineLbl.Text) or #lineLbl.Text
		for i = 1, n do
			if typing ~= id then return end
			lineLbl.MaxVisibleGraphemes = i
			if i % 4 == 0 then UI.sound("hover") end
			task.wait(0.018)
		end
		lineLbl.MaxVisibleGraphemes = -1
	end)
end

local function setMood(info, animate)
	local col = MOOD_COL[info.moodWord] or T.gold
	moodLbl.Text = info.moodWord .. "  " .. tostring(info.mood)
	if animate then
		UI.tween(dot, 0.3, { BackgroundColor3 = col })
		UI.tween(chipStroke, 0.3, { Color = col })
		UI.pop(chip, 1.25, 0.4)
	else
		dot.BackgroundColor3 = col
		chipStroke.Color = col
	end
	setStars(info.stars or 3)
	reviewLbl.Text = info.staff and (info.review or "") or (info.review and ("Review so far:  " .. info.review) or "")
end

local function clearPortrait()
	for _, c in ipairs(vp:GetChildren()) do
		if c ~= cam then c:Destroy() end
	end
end

local function portrait(model)
	clearPortrait()
	if not model or not model.Parent then return end
	local ok, copy = pcall(function()
		local was = model.Archivable
		model.Archivable = true
		local c = model:Clone()
		model.Archivable = was
		return c
	end)
	if not ok or not copy then return end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("ParticleEmitter") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local head = copy:FindFirstChild("Head")
	if not head then copy:Destroy() return end
	-- face the camera straight on, from just above eye level
	local hcf = head.CFrame
	local look = Vector3.new(hcf.LookVector.X, 0, hcf.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local target = hcf.Position - Vector3.new(0, 0.3, 0)
	cam.CFrame = CFrame.lookAt(target + look * 8 + Vector3.new(0, 0.6, 0) + hcf.RightVector * 0.7, target)
	copy.Parent = vp
end

local function close()
	if not current then return end
	current = nil
	typing += 1
	UI.close(holder, function()
		wrap.Visible = false
		clearPortrait()
	end)
end

local OPTIONS = {
	{ id = "stay", text = "How's your stay?", staffText = "How's work?", kind = "ink", key = "1" },
	{ id = "need", text = "Need anything?", staffText = "Need anything?", kind = "ink", key = "2" },
	{ id = "nice", text = "Enjoy your stay!", staffText = "Great job!", kind = "green", key = "3" },
	{ id = "bye", text = "Goodbye", staffText = "Goodbye", kind = "ghost", key = "4" },
}
local function choose(id)
	if not current then return end
	if Talk then Talk:FireServer(current.guest, id) end
	if id == "bye" then task.delay(0.9, close) end
end
-- round 12: the replies change with what the guest is doing (the server sends info.options = { {id, text} });
-- staff keep the fixed four. Buttons pop in one after another; keys 1-5 pick them.
local shownOpts = {}
local function setOptions(info)
	local list = info.options
	if info.staff or not list then
		list = {}
		for _, o in ipairs(OPTIONS) do table.insert(list, { id = o.id, text = info.staff and o.staffText or o.text }) end
	end
	local key = ""
	for _, o in ipairs(list) do key ..= o.id .. "," end
	if key == shownOpts.key then return end
	for _, c in ipairs(opts:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	shownOpts = { key = key, list = list }
	local n = #list
	local gap = 10
	local avail = W - X0 - 22
	for i, o in ipairs(list) do
		local bye = o.id == "bye"
		local w = bye and 104 or math.floor((avail - 104 - gap * (n - 1)) / math.max(n - 1, 1))
		local b = UI.button(opts, {
			text = o.text, kind = bye and "ghost" or (i == 1 and "green" or "ink"), key = tostring(i), order = i, textSize = n > 4 and 14 or 16, radius = 12,
			size = UDim2.fromOffset(w, 40),
			onClick = function() choose(o.id) end,
		})
		local sc = UI.scaleOf(b)
		sc.Scale = 0.6
		UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.05 * i)
	end
end
UI.closeButton(body, close)

UIS.InputBegan:Connect(function(io, gp)
	if gp or not current then return end
	local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5 })[io.KeyCode]
	local o = n and shownOpts.list and shownOpts.list[n]
	if o then
		UI.sound("Click")
		choose(o.id)
	end
end)

local function open(info)
	local first = not current or current.guest ~= info.guest
	current = { guest = info.guest, info = info }
	nameLbl.Text = info.name or "Guest"
	local sub = info.room and ("Staying in room " .. info.room) or "Waiting for a room"
	if info.event then sub = sub .. "  -  " .. info.event end
	if info.want then sub = sub .. "  -  wants " .. info.want end
	if info.doing and info.doing ~= "" and not info.staff and not string.find(info.doing, "^Room ") then sub = info.doing .. "  -  " .. sub end
	-- round 14: who they are and what they're feeling
	if info.feel and not info.staff then sub = "Feeling " .. string.lower(info.feel) .. "  -  " .. sub end
	if info.persona and not info.staff then
		local gold = string.format("#%02X%02X%02X", T.gold.R * 255, T.gold.G * 255, T.gold.B * 255)
		nameLbl.Text = (info.name or "Guest") .. '  <font size="15" color="' .. gold .. '">' .. string.upper((info.gtype and (info.gtype .. "  /  ") or "") .. info.persona .. (info.from and (" from " .. info.from) or "")) .. "</font>"
	end
	if info.staff then sub = info.sub or "" end -- round 10e: staff (stars = their level)
	rateLbl.Text = info.staff and "STAFF LEVEL" or "WOULD RATE YOU"
	setOptions(info)
	subLbl.Text = sub
	setMood(info, false)
	typeOut(info.line or "Hi!")
	if first then portrait(info.guest) end
	if not wrap.Visible then
		wrap.Visible = true
		holder.Visible = true
		UI.open(holder, { rise = 26 })
	end
end

-- walk away (or the guest leaves) and the conversation ends
RunService.Heartbeat:Connect(function()
	if not current then return end
	local g = current.guest
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local groot = g and g.Parent and g:FindFirstChild("HumanoidRootPart")
	if not groot or not root or (groot.Position - root.Position).Magnitude > 20 then close() end
end)

---------------------------------------------------------------- review cards (a guest checked out)

local reviewList = UI.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -22), Size = UDim2.fromOffset(350, 400), BackgroundTransparency = 1, Parent = gui })
UI.list(reviewList, nil, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
UI.autoScale(reviewList, Vector2.new(1500, 860))

local function reviewCard(d)
	local stars = d.stars or 3
	local accent = stars >= 4 and T.gold or (stars <= 2 and T.red or T.line)
	local slot = UI.new("Frame", { Size = UDim2.fromOffset(340, 98), BackgroundTransparency = 1, LayoutOrder = math.floor(os.clock() * 100), Parent = reviewList })
	local card = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(380, 0), BackgroundColor3 = T.ink, Parent = slot })
	UI.corner(card, 16)
	UI.stroke(card, 2, accent, 0.2)
	UI.label(card, "NEW REVIEW", 12, { FontFace = UI.F.heavy, TextColor3 = accent == T.line and T.muted or accent, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(120, 14) })
	local _, set = starRow(card, 20, UDim2.new(1, -124, 0, 8))
	set(stars)
	UI.label(card, '"' .. (d.text or "") .. '"', 16, {
		FontFace = UI.F.heavy, TextColor3 = T.cream, Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -32, 0, 42),
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd,
	})
	UI.label(card, (d.name or "A guest") .. (d.room and (", room " .. d.room) or ""), 13, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 16) })
	UI.tween(card, 0.5, { Position = UDim2.new() }, Enum.EasingStyle.Back)
	UI.sound(stars >= 5 and "sparkle" or (stars <= 2 and "error" or "toast"))
	task.delay(5, function()
		UI.tween(card, 0.3, { Position = UDim2.fromOffset(380, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.3)
		UI.tween(slot, 0.2, { Size = UDim2.fromOffset(340, 0) })
		task.wait(0.22)
		slot:Destroy()
	end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "talk" and d then
		open(d)
	elseif kind == "talkReply" and d and current and current.guest == d.guest then
		local before = current.info.mood
		current.info = d
		setOptions(d)
		setMood(d, d.mood ~= before)
		if d.mood < before then UI.shake(chip) end
		typeOut(d.line or "")
	elseif kind == "review" and d then
		if player:GetAttribute("RAH_HideReviews") then return end
		reviewCard(d)
	end
end)

---------------------------------------------------------------- round 14: dropping what you carry
-- A bag (RAH_Bag) or a lost thing (RAH_Found): G or the button puts it down in front of you (Remotes.Drop).
local Drop = Remotes:WaitForChild("Drop", 30)
local dropWrap = UI.new("Frame", { Name = "DropHint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -118), Size = UDim2.fromOffset(250, 52), BackgroundTransparency = 1, Visible = false, Parent = gui })
UI.autoScale(dropWrap, Vector2.new(1500, 860))
local dropBtn = UI.button(dropWrap, {
	text = "Drop", kind = "ink", key = "G", size = UDim2.fromScale(1, 1), textSize = 18, radius = 14,
	onClick = function() if Drop then Drop:FireServer() end end,
})
local function carryName()
	if player:GetAttribute("RAH_Bag") then return "Drop the bag" end
	local f = player:GetAttribute("RAH_Found")
	if f then return "Drop the " .. string.lower(tostring(f)) end
	return nil
end
local function refreshDrop()
	local n = carryName()
	if n then
		local lbl = dropBtn:FindFirstChild("Label", true)
		if lbl then lbl.Text = n end
		if not dropWrap.Visible then
			dropWrap.Visible = true
			local sc = UI.scaleOf(dropBtn)
			sc.Scale = 0.7
			UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	else
		dropWrap.Visible = false
	end
end
player:GetAttributeChangedSignal("RAH_Bag"):Connect(refreshDrop)
player:GetAttributeChangedSignal("RAH_Found"):Connect(refreshDrop)
refreshDrop()
UIS.InputBegan:Connect(function(io, gp)
	if gp or io.KeyCode ~= Enum.KeyCode.G or player:GetAttribute("RAH_Building") then return end
	if carryName() and Drop then
		UI.sound("Click")
		Drop:FireServer()
	end
end)
