-- StarterPlayerScripts.Bubbles (round 14, 2026-11-09): no more speech or thought bubbles, and no names over heads.
-- * Talk comes out as captions at the bottom of the screen (like subtitles): a coloured name tag, then the line
--   typing in at the pace of the speaker's voice (Shared.VoiceFX). Only people near you are heard, at most
--   MAX_LINES at once; a new line from the same person replaces their last one. Thoughts (SayMode "think")
--   stay in their heads.
-- * While someone talks, three little bars bounce over their head so you can see who it is.
-- * A small status disc (icon + timer ring, the event badge) shows only while someone is waiting on something
--   (BIcon set by HotelSim: patience outside, a job in progress).
-- Server contract is unchanged (tag Bubble; BName, BRole, BRoleColor, BIcon, BBar, BT0, BSecs, BDrain, BEvent,
-- Say, SaySecs, SayN, SayMode). Player attributes HideBubbles (Settings) and Building hide it all.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local TextChatService = game:GetService("TextChatService")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local VoiceFX = require(Shared:WaitForChild("VoiceFX"))
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

local HEAR = 46 -- you hear people within this many studs
local STATUS_FAR = 70
local MAX_LINES = 3
local WRAP = 470
local TAGS = {
	Color3.fromRGB(226, 96, 76), Color3.fromRGB(62, 150, 214), Color3.fromRGB(92, 168, 72), Color3.fromRGB(196, 120, 40),
	Color3.fromRGB(150, 98, 196), Color3.fromRGB(32, 150, 140), Color3.fromRGB(214, 84, 140), Color3.fromRGB(110, 120, 140),
}
local BAR = { yellow = T.gold, blue = T.blue, purple = T.violet, green = T.green, red = T.red }

local function hiddenAll()
	return player:GetAttribute("HideBubbles") == true or player:GetAttribute("Building") == true
end
local function hash(s)
	local h = 5
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 100003 end
	return h
end

---------------------------------------------------------------- captions

local capGui = UI.new("ScreenGui", { Name = "Captions", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Parent = pgui })
local holder = UI.new("Frame", {
	Name = "Lines", Size = UDim2.fromOffset(720, 260), Position = UDim2.new(0.5, 0, 1, -170), AnchorPoint = Vector2.new(0.5, 1),
	BackgroundTransparency = 1, Parent = capGui,
})
UI.autoScale(holder)
UI.list(holder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

local lines = {} -- newest last: { frame, model, n }
local order = 0
local function dropLine(L, fast)
	for i, x in ipairs(lines) do
		if x == L then table.remove(lines, i) break end
	end
	if not L.frame.Parent then return end
	local tw = UI.tween(L.frame, fast and 0.12 or 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Connect(function() L.frame:Destroy() end)
end

local function caption(model, text, secs)
	local name = model:GetAttribute("BName") or model.Name
	local first = name:match("^(%S+)") or name
	local role = model:GetAttribute("BRole")
	local tagCol = model:GetAttribute("BRoleColor") or TAGS[hash(first) % #TAGS + 1]
	-- the same person speaking again replaces their line
	for _, L in ipairs(lines) do
		if L.model == model then dropLine(L, true) break end
	end
	while #lines >= MAX_LINES do dropLine(lines[1], true) end
	order += 1
	local f = UI.new("CanvasGroup", {
		Name = "Line", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), BackgroundColor3 = T.paper,
		LayoutOrder = order, GroupTransparency = 1, Parent = holder,
	})
	UI.corner(f, 14)
	UI.stroke(f, 2.5, T.outline, 0)
	UI.pad(f, 8, 7, 14, 7)
	UI.list(f, Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center)
	local tag = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = tagCol, LayoutOrder = 1, Parent = f })
	UI.corner(tag, 9)
	UI.stroke(tag, 2, T.outline, 0)
	UI.pad(tag, 9, 0, 9, 0)
	UI.list(tag, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
	local nm = UI.new("TextLabel", { Text = first, TextSize = 17, FontFace = UI.F.black, TextColor3 = T.white, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 1, Parent = tag })
	UI.wordRim(nm, 1.6)
	if role then
		UI.new("TextLabel", { Text = string.lower(role), TextSize = 13, FontFace = UI.F.bold, TextColor3 = T.white, TextTransparency = 0.1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Parent = tag })
	end
	local w = math.min(TextService:GetTextSize(text, 18, Enum.Font.Nunito, Vector2.new(4000, 100)).X + 6, WRAP)
	local words = UI.new("TextLabel", {
		Text = text, TextSize = 18, FontFace = UI.F.bold, TextColor3 = T.cream, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(w, 22),
		MaxVisibleGraphemes = 0, LayoutOrder = 2, Parent = f,
	})
	local L = { frame = f, model = model }
	table.insert(lines, L)
	UI.pop(f, 0.85, 0.3)
	UI.tween(f, 0.2, { GroupTransparency = 0 })
	return L, words
end

---------------------------------------------------------------- over heads: the talking bars and the status disc

local marks = {} -- model -> m

local function build(model)
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	if not head or not model.Parent then return end
	local m = { model = model }
	local bb = UI.new("BillboardGui", {
		Name = "Mark", Size = UDim2.fromOffset(60, 70), StudsOffset = Vector3.new(0, 2.6, 0), LightInfluence = 0,
		MaxDistance = STATUS_FAR, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Adornee = head,
		Enabled = not hiddenAll(), Parent = pgui,
	})
	local root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local sc = Instance.new("UIScale")
	sc.Parent = root
	-- talking bars
	local talk = UI.new("Frame", { Name = "Talk", Size = UDim2.fromOffset(34, 22), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.paper, Visible = false, Parent = root })
	UI.corner(talk, 11)
	UI.stroke(talk, 2, T.outline, 0)
	local bars = {}
	for i = 1, 3 do
		local b = UI.new("Frame", { Size = UDim2.fromOffset(4, 8), Position = UDim2.new(0.5, (i - 2) * 8, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.outline, Parent = talk })
		UI.corner(b, 2)
		bars[i] = b
	end
	-- status disc
	local disc = UI.new("Frame", { Name = "Disc", Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = T.paper, Visible = false, Parent = root })
	UI.corner(disc, UDim.new(0.5, 0))
	UI.stroke(disc, 2.5, T.outline, 0)
	local _, setRing, ringStrokes = UI.ring(disc, 38, 4, T.green, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local icon = UI.icon(disc, "", 26, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local badge = UI.new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, 4, 0, -4), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.paper, Visible = false, ZIndex = 3, Parent = disc })
	UI.corner(badge, UDim.new(0.5, 0))
	UI.stroke(badge, 2, T.outline, 0)
	local badgeIcon = UI.icon(badge, "", 16, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 })
	m.bb, m.sc, m.talk, m.bars, m.disc, m.setRing, m.ringStrokes, m.icon = bb, sc, talk, bars, disc, setRing, ringStrokes, icon

	local function refreshStatus()
		local ic = model:GetAttribute("BIcon")
		local show = ic ~= nil and ICON[ic] ~= nil
		if show and not disc.Visible then UI.pop(disc, 0.4, 0.4) end
		disc.Visible = show
		icon.Image = show and ICON[ic] or ""
		local e = model:GetAttribute("BEvent")
		badge.Visible = e ~= nil and ICON[e] ~= nil
		badgeIcon.Image = e and ICON[e] or ""
	end
	local function refreshSay()
		local line = model:GetAttribute("Say")
		if not line or line == "" or model:GetAttribute("SayMode") == "think" then return end
		if hiddenAll() then return end
		local cam = workspace.CurrentCamera
		local char = player.Character
		local from = (char and char:FindFirstChild("HumanoidRootPart") and char.HumanoidRootPart.Position) or (cam and cam.CFrame.Position)
		if not from or (head.Position - from).Magnitude > HEAR then return end
		m.n = (m.n or 0) + 1
		local n = m.n
		local dur = VoiceFX.speak(head, line, VoiceFX.voiceOf(model.Name, model:GetAttribute("Deep")), { rate = model:GetAttribute("VoiceRate") })
		dur = math.clamp(dur, 0.3, 3.2)
		local L, words = caption(model, line, dur)
		L.n = n
		UI.tween(words, dur, { MaxVisibleGraphemes = utf8.len(line) or #line }, Enum.EasingStyle.Linear)
		m.talkUntil = os.clock() + dur
		local secs = math.max(model:GetAttribute("SaySecs") or 3, dur + 2.2)
		task.delay(secs, function()
			if L.frame.Parent then dropLine(L) end
		end)
	end
	refreshStatus()
	m.conns = {
		model:GetAttributeChangedSignal("BIcon"):Connect(refreshStatus),
		model:GetAttributeChangedSignal("BEvent"):Connect(refreshStatus),
		model:GetAttributeChangedSignal("SayN"):Connect(refreshSay),
	}
	return m
end

local function remove(model)
	local m = marks[model]
	marks[model] = nil
	if type(m) ~= "table" then return end
	for _, c in ipairs(m.conns) do c:Disconnect() end
	m.bb:Destroy()
end

local function add(model)
	if marks[model] or not model:IsA("Model") then return end
	marks[model] = true
	local m = build(model)
	if marks[model] ~= true then
		if m then for _, c in ipairs(m.conns) do c:Disconnect() end m.bb:Destroy() end
		return
	end
	marks[model] = m
	if m then
		table.insert(m.conns, model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(workspace) then remove(model) end
		end))
	end
end

CollectionService:GetInstanceAddedSignal("Bubble"):Connect(function(m) task.spawn(add, m) end)
CollectionService:GetInstanceRemovedSignal("Bubble"):Connect(function(m)
	if marks[m] == true then marks[m] = nil return end
	remove(m)
end)
for _, m in ipairs(CollectionService:GetTagged("Bubble")) do task.spawn(add, m) end

local function applyHidden()
	local off = hiddenAll()
	capGui.Enabled = not off
	for _, m in pairs(marks) do
		if type(m) == "table" then m.bb.Enabled = not off end
	end
end
player:GetAttributeChangedSignal("HideBubbles"):Connect(applyHidden)
player:GetAttributeChangedSignal("Building"):Connect(applyHidden)

-- players talk too: a chat message plays in the sender's own voice at their head
pcall(function()
	TextChatService.MessageReceived:Connect(function(msg)
		local src = msg.TextSource
		local pl = src and Players:GetPlayerByUserId(src.UserId)
		local head = pl and pl.Character and pl.Character:FindFirstChild("Head")
		if head and msg.Text and msg.Text ~= "" then
			VoiceFX.speak(head, msg.Text, VoiceFX.voiceOf(pl.Name), { volume = pl == player and 0.8 or 1 })
		end
	end)
end)

---------------------------------------------------------------- every frame: rings, the talking bars, size by distance

local function patienceColor(k)
	if k > 0.5 then return T.green end
	if k > 0.25 then return T.gold end
	return T.red
end
RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cpos = cam.CFrame.Position
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, m in pairs(marks) do
		if type(m) == "table" and m.bb.Adornee then
			local d = (m.bb.Adornee.Position - cpos).Magnitude
			m.sc.Scale = math.clamp(1.15 - d / 90, 0.55, 1.05)
			local talking = m.talkUntil and clock < m.talkUntil
			m.talk.Visible = talking and not m.disc.Visible
			if talking then
				for i, b in ipairs(m.bars) do
					b.Size = UDim2.fromOffset(4, 5 + math.abs(math.sin(clock * 14 + i * 1.7)) * 9)
				end
			end
			if m.disc.Visible then
				local bar = model:GetAttribute("BBar")
				local t0, secs = model:GetAttribute("BT0"), model:GetAttribute("BSecs")
				if bar and t0 and secs and secs > 0 then
					local k = math.clamp((now - t0) / secs, 0, 1)
					if model:GetAttribute("BDrain") then k = 1 - k end
					m.setRing(k)
					local col = bar == "patience" and patienceColor(k) or BAR[bar] or T.gold
					for _, st in ipairs(m.ringStrokes) do st.Color = col end
					m.disc.Rotation = (bar == "patience" and k < 0.25) and math.sin(clock * 30) * 7 or 0
				else
					m.setRing(0)
					m.disc.Rotation = 0
				end
			end
		end
	end
end)
