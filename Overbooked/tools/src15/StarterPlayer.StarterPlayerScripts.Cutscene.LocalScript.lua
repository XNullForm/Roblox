-- StarterPlayerScripts.Cutscene (round 15, 2026-11-10): short camera cutscenes.
-- Notify "cutscene" { kind = "star", model, name, title, line, icon }: a star guest walks up to the hotel. Letterbox
--   bars come in, the HUD steps aside, the camera opens wide on them, tracks them from the front while a title card
--   names them, and ends close on their face with their first line.
-- Notify "gradeUp" { grade, name, hotel, pos }: a slow orbit round the grown hotel with the new grade's name.
-- Skippable (any key, a click or a tap, or the Skip button). Never starts while building, talking, in a minigame or on
-- the title screen; one plays at a time and one more may wait. The camera blends back to where it was.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local Notify = Shared:WaitForChild("Remotes"):WaitForChild("Notify")
local T = UI.T

local GOLD = Color3.fromRGB(255, 206, 92)
local KEEP = { Cutscene = true, Loading = true, MainMenu = true }

---------------------------------------------------------------- the overlay

local gui = Instance.new("ScreenGui")
gui.Name = "Cutscene"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.ScreenInsets = Enum.ScreenInsets.None
gui.Enabled = false
gui:SetAttribute("NoSkin", true)
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(top)
	local f = Instance.new("Frame")
	f.Name = top and "BarTop" or "BarBottom"
	f.BackgroundColor3 = Color3.fromRGB(6, 6, 10)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, top and 0 or 1)
	f.Position = UDim2.fromScale(0, top and 0 or 1)
	f.Size = UDim2.new(1, 0, 0, 0)
	f.ZIndex = 2
	f.Parent = gui
	return f
end
local barTop, barBottom = bar(true), bar(false)

local vignette = Instance.new("ImageLabel")
vignette.Name = "Vignette"
vignette.BackgroundTransparency = 1
vignette.Image = UI.IMG.vignette
vignette.ImageColor3 = Color3.new(0, 0, 0)
vignette.ImageTransparency = 1
vignette.Size = UDim2.fromScale(1, 1)
vignette.ZIndex = 1
vignette.Parent = gui

-- the title card, bottom left above the lower bar
local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundTransparency = 1
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0, 70, 0.86, -18)
card.Size = UDim2.fromOffset(760, 190)
card.ZIndex = 3
card.Parent = gui
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

local function label(name, text, size, font, color, y, h)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextSize = size
	t.FontFace = font
	t.TextColor3 = color
	t.TextTransparency = 1
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Position = UDim2.fromOffset(0, y)
	t.Size = UDim2.new(1, 0, 0, h)
	t.ZIndex = 4
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(0, 0, 0)
	s.Transparency = 1
	s.Thickness = 2
	s.Parent = t
	t.Parent = card
	return t, s
end
local kicker = label("Kicker", "STAR GUEST", 22, UI.F.heavy, GOLD, 0, 26)
local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.BackgroundColor3 = GOLD
accent.BorderSizePixel = 0
accent.Position = UDim2.fromOffset(0, 32)
accent.Size = UDim2.fromOffset(0, 4)
accent.ZIndex = 4
accent.Parent = card
local title = label("Name", "", 68, UI.F.display, Color3.new(1, 1, 1), 40, 76)
local sub = label("Sub", "", 26, UI.F.bold, Color3.fromRGB(236, 232, 255), 118, 32)
local quote = label("Quote", "", 24, UI.F.italic, Color3.fromRGB(255, 240, 210), 154, 30)

local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AutoButtonColor = false
skip.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
skip.BackgroundTransparency = 0.35
skip.AnchorPoint = Vector2.new(1, 0)
skip.Position = UDim2.new(1, -28, 0, 0)
skip.Size = UDim2.fromOffset(112, 40)
skip.Text = "SKIP  >>"
skip.TextSize = 18
skip.FontFace = UI.F.heavy
skip.TextColor3 = Color3.fromRGB(240, 238, 255)
skip.ZIndex = 5
skip.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = skip
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Transparency = 0.7
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = skip
end

local function fit()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local k = math.clamp(math.min(vp.X / 1500, vp.Y / 860), 0.5, 1.2)
	cardScale.Scale = k
	card.Position = UDim2.new(0, math.floor(70 * k), 0.86, -math.floor(18 * k))
	skip.Position = UDim2.new(1, -28, 0, math.floor(vp.Y * 0.14) + 14)
end

local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end

local function showCard(kick, name, subText, line)
	kicker.Text = kick
	title.Text = name
	sub.Text = subText or ""
	quote.Text = line and ("\"" .. line .. "\"") or ""
	for i, t in ipairs({ kicker, title, sub, quote }) do
		t.TextTransparency = 1
		t.UIStroke.Transparency = 1
		local y0 = t.Position.Y.Offset
		t.Position = UDim2.fromOffset(-30, y0)
		task.delay(0.08 * i + (t == quote and 0.6 or 0), function()
			tw(t, 0.55, { TextTransparency = 0, Position = UDim2.fromOffset(0, y0) })
			tw(t.UIStroke, 0.55, { Transparency = 0.55 })
		end)
	end
	accent.Size = UDim2.fromOffset(0, 4)
	tw(accent, 0.7, { Size = UDim2.fromOffset(math.max(140, math.min(520, title.TextBounds.X > 0 and title.TextBounds.X or 300)), 4) })
end
local function hideCard()
	for _, t in ipairs({ kicker, title, sub, quote }) do
		tw(t, 0.35, { TextTransparency = 1 })
		tw(t.UIStroke, 0.35, { Transparency = 1 })
	end
	tw(accent, 0.35, { Size = UDim2.fromOffset(0, 4) })
end

local function chime(id, vol)
	if player:GetAttribute("SfxOff") then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = (vol or 0.5) * (player:GetAttribute("SfxVol") or 1)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(10, function() if s.Parent then s:Destroy() end end)
end

---------------------------------------------------------------- running a cutscene

local busy, queued = false, nil
local skipped = false

local function blocked()
	if player:GetAttribute("Building") or player:GetAttribute("InTalk") then return true end
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return true end
	for _, n in ipairs({ "Minigame", "MainMenu", "Loading" }) do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then return true end
	end
	return false
end

local hidden = {}
local function hideHud(on)
	local pg = player:FindFirstChild("PlayerGui")
	if on then
		table.clear(hidden)
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and not KEEP[g.Name] then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
	else
		for _, g in ipairs(hidden) do
			if g.Parent then g.Enabled = true end
		end
		table.clear(hidden)
	end
end

-- hold the character still (this game has no PlayerModule, so hold the humanoid, like Talk does)
local frozen
local function controls(on)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not on then
		if hum and not frozen then
			frozen = { hum = hum, ws = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight }
			hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
		end
	elseif frozen then
		local f = frozen
		frozen = nil
		if f.hum.Parent then f.hum.WalkSpeed, f.hum.JumpPower, f.hum.JumpHeight = f.ws, f.jp, f.jh end
	end
end

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
-- keep the camera on the near side of anything between it and what it's looking at: walls, trees, lamps and other
-- people (only the subject is ignored, so nobody's head ever fills the shot)
local subject
local function clear(from, to)
	rp.FilterDescendantsInstances = subject and { subject } or {}
	local d = to - from
	local hit = workspace:Raycast(from, d, rp)
	if hit then return from + d.Unit * math.max(1.5, hit.Distance - 0.8) end
	return to
end

local function ease(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- shots: a list of { dur, fn(t, k, dt) -> CFrame, fov }; returns when done or skipped
local function play(shots, onStart)
	local cam = workspace.CurrentCamera
	local saved = { type = cam.CameraType, cf = cam.CFrame, fov = cam.FieldOfView }
	busy, skipped = true, false
	gui.Enabled = true
	fit()
	hideHud(true)
	controls(false)
	player:SetAttribute("InCutscene", true)
	cam.CameraType = Enum.CameraType.Scriptable
	local barH = function() return math.floor(cam.ViewportSize.Y * 0.11) end
	tw(barTop, 0.6, { Size = UDim2.new(1, 0, 0, barH()) })
	tw(barBottom, 0.6, { Size = UDim2.new(1, 0, 0, barH()) })
	tw(vignette, 0.8, { ImageTransparency = 0.45 })
	if onStart then onStart() end
	local t0 = os.clock()
	local inputConn = UIS.InputBegan:Connect(function(io, gp)
		if os.clock() - t0 < 0.6 then return end
		local tt = io.UserInputType
		if tt == Enum.UserInputType.Keyboard or tt == Enum.UserInputType.MouseButton1 or tt == Enum.UserInputType.Touch or tt == Enum.UserInputType.Gamepad1 then
			skipped = true
		end
	end)
	local skipConn = skip.Activated:Connect(function() skipped = true end)
	local cur = cam.CFrame
	local i, shotT = 1, 0
	local last = os.clock()
	while i <= #shots and not skipped do
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		shotT += dt
		-- anything that pops up mid-scene (a toast, a goal card) steps aside too
		for _, g in ipairs(player.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and not KEEP[g.Name] then
				g.Enabled = false
				table.insert(hidden, g)
			end
		end
		-- Studio: player attribute CutsceneHold = n parks the camera inside shot n (for screenshots)
		local hold = RunService:IsStudio() and player:GetAttribute("CutsceneHold")
		if hold == i and shotT > shots[i][1] * 0.7 then shotT = shots[i][1] * 0.7 end
		local s = shots[i]
		if shotT >= s[1] then
			shotT -= s[1]
			i += 1
		else
			local ok, cf, fov = pcall(s[2], shotT, shotT / s[1], dt)
			if ok and cf then
				-- a short ease between shots, a hard cut when the shot says so
				if shotT < dt * 1.5 and s.cut then cur = cf else cur = cur:Lerp(cf, math.min(1, dt * (s.follow or 9))) end
				cam.CFrame = cur
				if fov then cam.FieldOfView = cam.FieldOfView + (fov - cam.FieldOfView) * math.min(1, dt * 4) end
			elseif not ok then
				break
			end
		end
		RunService.RenderStepped:Wait()
	end
	inputConn:Disconnect()
	skipConn:Disconnect()
	hideCard()
	tw(barTop, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
	tw(barBottom, 0.5, { Size = UDim2.new(1, 0, 0, 0) })
	tw(vignette, 0.5, { ImageTransparency = 1 })
	-- blend back to where the camera was
	local from, fov0 = cam.CFrame, cam.FieldOfView
	local b0 = os.clock()
	while os.clock() - b0 < 0.7 do
		local k = ease((os.clock() - b0) / 0.7)
		cam.CFrame = from:Lerp(saved.cf, k)
		cam.FieldOfView = fov0 + (saved.fov - fov0) * k
		RunService.RenderStepped:Wait()
	end
	cam.CFrame = saved.cf
	cam.FieldOfView = saved.fov
	cam.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
	controls(true)
	hideHud(false)
	player:SetAttribute("InCutscene", nil)
	task.wait(0.5)
	gui.Enabled = false
	busy = false
	if queued then
		local q = queued
		queued = nil
		task.defer(q)
	end
end

---------------------------------------------------------------- the star guest

local function starShots(d)
	local m = d.model
	local root = m and m:FindFirstChild("HumanoidRootPart")
	local head = m and m:FindFirstChild("ClassicHead") or (m and m:FindFirstChild("Head"))
	if not (root and head) then return nil end
	subject = m
	-- a smoothed frame that follows them (they turn on the path; the shot shouldn't snap)
	local frame = CFrame.lookAt(root.Position, root.Position + Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z))
	local function follow(dt)
		local lv = root.CFrame.LookVector
		local fl = Vector3.new(lv.X, 0, lv.Z)
		if fl.Magnitude < 0.1 then fl = frame.LookVector end
		local want = CFrame.lookAt(root.Position, root.Position + fl.Unit)
		frame = frame:Lerp(want, math.min(1, dt * 2.2))
		frame = frame.Rotation + root.Position
		return frame
	end
	return {
		-- wide: high and ahead of them, easing in
		{ 2.4, function(t, k, dt)
			local f = follow(dt)
			local dist = 24 - 6 * ease(k)
			local at = f.Position + Vector3.new(0, 1.5, 0)
			local pos = (f * CFrame.new(9, 0, 0)).Position + f.LookVector * dist + Vector3.new(0, 10 - 3 * ease(k), 0)
			return CFrame.lookAt(clear(at, pos), at), 50
		end, cut = true, follow = 30 },
		-- tracking: a medium shot from the front, walking backwards with them
		{ 3.4, function(t, k, dt)
			local f = follow(dt)
			local at = head.Position + Vector3.new(0, -0.6, 0)
			local pos = (f * CFrame.new(1.8, 0, -8.5 + 1.2 * ease(k))).Position + Vector3.new(0, 1.2, 0)
			return CFrame.lookAt(clear(at, pos), at), 42
		end, cut = true, follow = 30 },
		-- close: their face, slightly low, a slow push in
		{ 2.4, function(t, k, dt)
			local f = follow(dt)
			local at = head.Position + Vector3.new(0, -0.25, 0)
			local pos = (f * CFrame.new(1.1, 0, -6.6 + 1.0 * ease(k))).Position + Vector3.new(0, head.Position.Y - f.Position.Y - 0.45, 0)
			return CFrame.lookAt(clear(at, pos), at), 32
		end, cut = true, follow = 30 },
	}
end

local function runStar(d)
	local shots = starShots(d)
	if not shots then return end
	play(shots, function()
		chime(9113849492, 0.55)
		task.delay(2.3, function()
			if not skipped then showCard("STAR GUEST", d.name or "", d.title, nil) end
		end)
		task.delay(5.9, function()
			if not skipped and d.line then
				quote.Text = "\"" .. d.line .. "\""
				quote.TextTransparency = 1
				tw(quote, 0.5, { TextTransparency = 0 })
				tw(quote.UIStroke, 0.5, { Transparency = 0.55 })
			end
		end)
	end)
end

---------------------------------------------------------------- the hotel grows

local function runGrade(d)
	local hotel = d.hotel
	local at = typeof(d.pos) == "Vector3" and d.pos or nil
	if not at and hotel and hotel:IsA("Model") then
		local cf, size = hotel:GetBoundingBox()
		at = cf.Position - Vector3.new(0, size.Y / 2, 0)
	end
	if not at then return end
	subject = nil
	local cam = workspace.CurrentCamera
	local look = at + Vector3.new(0, 14, 0)
	local base = cam.CFrame.Position - look
	local a0 = math.atan2(base.X, base.Z)
	play({
		{ 6.0, function(t, k)
			local a = a0 + math.rad(-40 + 80 * ease(k))
			local r = 92 - 18 * ease(k)
			local pos = look + Vector3.new(math.sin(a) * r, 26 - 8 * ease(k), math.cos(a) * r)
			return CFrame.lookAt(pos, look), 48
		end, cut = false, follow = 3 },
	}, function()
		task.delay(0.5, function()
			if not skipped then showCard("HOTEL UPGRADED", d.name or "A bigger hotel", "New floors, a new look, and pickier guests.", nil) end
		end)
	end)
end

---------------------------------------------------------------- incoming

local function want(fn)
	if busy then
		queued = fn
		return
	end
	task.spawn(fn)
end

Notify.OnClientEvent:Connect(function(kind, data)
	if type(data) ~= "table" then return end
	if kind == "cutscene" and data.kind == "star" then
		local m = data.model
		local root = m and m:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not root or (root.Position - cam.CFrame.Position).Magnitude > 420 then return end
		want(function()
			if blocked() or not m.Parent then return end
			runStar(data)
		end)
	elseif kind == "gradeUp" then
		want(function()
			task.wait(1.2) -- the building grows first
			if blocked() then return end
			runGrade(data)
		end)
	end
end)

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if gui.Enabled then fit() end
end)

-- Studio: player attribute TestCutscene = "star" plays the next guest's arrival as a star shot, "grade" the orbit
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("TestCutscene"):Connect(function()
		local v = player:GetAttribute("TestCutscene")
		if not v then return end
		player:SetAttribute("TestCutscene", nil)
		if v == "grade" then
			local plots = workspace:FindFirstChild("Plots")
			local h = plots and plots:FindFirstChild(player:GetAttribute("Plot") or "")
			want(function() runGrade({ hotel = h, name = "Grand Hotel" }) end)
		else
			local plots = workspace:FindFirstChild("Plots")
			local h = plots and plots:FindFirstChild(player:GetAttribute("Plot") or "")
			local gs = h and h:FindFirstChild("Guests")
			local pick
			for _, m in ipairs(gs and gs:GetChildren() or {}) do
				if m:GetAttribute("Guest") and m:FindFirstChild("HumanoidRootPart") then pick = m break end
			end
			if pick then want(function() runStar({ model = pick, name = "Jett Vega", title = "Rock star on a world tour", line = "Is this where the after-party is?" }) end) end
		end
	end)
end
