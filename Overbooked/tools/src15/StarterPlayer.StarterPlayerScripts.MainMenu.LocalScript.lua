-- StarterPlayerScripts.MainMenu (round 21, 2026-11-12): the title screen, remade from scratch.
-- A slow film of the seaside town plays behind a dark column on the left: the OVERBOOKED wordmark, three SAVE FILES
-- (each shows its hotel's name, level, rooms and cash with Continue, or New hotel when it is empty, and a bin to
-- delete it), a switch to replay the tutorial, and Settings. Nothing else: no podium, no news card, no tips.
-- Playing: the column slides away, the screen fades to black while the server (Plots / Save) claims your plot and
-- loads that save file, then a crane shot swoops down behind your character and the HUD comes back.
-- After "Reset progress" the server clears Slot and the title screen returns.
-- Remotes.Menu: client fires ("slots") for the summaries, ("play", n) to start file n (1..3), ("delete", n) to erase
-- one; the server answers ("slots", { [n] = { name, cash, rooms, level, stars } }).
-- The player's settings (the attributes in PREF_KEYS) go to the server (Remotes.Prefs) whenever they change.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local Menu = Shared.Remotes:WaitForChild("Menu")
local T, G = UI.T, UI.G

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local V3 = Vector3.new
local SLOTS = 3

---------------------------------------------------------------- settings sync (round 12)

do
	local PREF_KEYS = {
		"MusicVol", "SfxVol", "MusicOff", "SfxOff", "UiSfxOff", "Sprint", "HideQuests",
		"HideReviews", "HideBubbles", "HideRoomSigns", "HideDaySummary", "HidePops", "FOV",
		"ShadowsOff", "PromptSize", "LookSens", "LookInvert",
	}
	local Prefs = Shared.Remotes:WaitForChild("Prefs", 10)
	local pending = false
	local function send()
		if pending or not Prefs then return end
		pending = true
		task.delay(1.5, function()
			pending = false
			local t = {}
			for _, k in ipairs(PREF_KEYS) do
				local v = player:GetAttribute(k)
				-- a switched-off flag is sent as false so turning it back on saves too
				if v == nil and (k:find("Hide") or k:find("Off") or k == "LookInvert") then v = false end
				if v ~= nil then t[k] = v end
			end
			Prefs:FireServer(t)
		end)
	end
	for _, k in ipairs(PREF_KEYS) do player:GetAttributeChangedSignal(k):Connect(send) end
end

---------------------------------------------------------------- the title screen

local running = false
local function run()
	local cons = {} -- cut when the title screen closes
	local gui
	local cam = workspace.CurrentCamera
	local menuFx = {}
	local function teardown()
		for _, c in ipairs(cons) do c:Disconnect() end
		table.clear(cons)
		for _, e in ipairs(menuFx) do e:Destroy() end
		if gui then gui:Destroy() end
	end
	local old = pgui:FindFirstChild("MainMenu")
	if old then old:Destroy() end
	gui = UI.new("ScreenGui", {
		Name = "MainMenu", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 50, Parent = pgui,
	})

	-- other screens hide while the title is up
	local KEEP = { MainMenu = true, Toasts = true, Loading = true, Tooltip = true }
	local hidden = {}
	local function hideGui(g)
		if g:IsA("ScreenGui") and not KEEP[g.Name] and g.Enabled then
			hidden[g] = true
			g.Enabled = false
		end
	end
	for _, g in ipairs(pgui:GetChildren()) do hideGui(g) end
	local hideCon = pgui.ChildAdded:Connect(function(g) task.defer(hideGui, g) end)
	local function restoreGuis()
		hideCon:Disconnect()
		for g in pairs(hidden) do if g.Parent then g.Enabled = true end end
		table.clear(hidden)
	end

	---------------------------------------------------------------- the film: slow shots of the town

	local SHOTS = {
		{ from = V3(-300, 46, 330), to = V3(-140, 34, 300), lookA = V3(-200, 6, 150), lookB = V3(-20, 8, 120), secs = 16 },
		{ from = V3(-70, 15, 118), to = V3(80, 15, 118), lookA = V3(10, 10, 20), lookB = V3(160, 10, 20), secs = 14 },
		{ from = V3(214, 16, 470), to = V3(184, 20, 330), lookA = V3(160, 4, 300), lookB = V3(160, 8, 140), secs = 15 },
		{ from = V3(-470, 18, 92), to = V3(-320, 22, 92), lookA = V3(-220, 6, 100), lookB = V3(-60, 6, 100), secs = 14 },
		{ from = V3(540, 30, 180), to = V3(420, 22, 160), lookA = V3(380, 2, 190), lookB = V3(300, 6, 120), secs = 15 },
	}
	local filmOn = true
	local shotIndex, shotT = 1, 0
	local black = UI.new("Frame", { Name = "Black", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 50, Parent = gui })
	local function ease(a) return a * a * (3 - 2 * a) end
	local function streamAround(pos)
		task.spawn(function() pcall(function() player:RequestStreamAroundAsync(pos, 4) end) end)
	end
	streamAround(SHOTS[1].from)
	do
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "MenuDOF"
		dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0.25, 0, 80, 60
		dof.Parent = cam
		menuFx = { dof }
	end
	local filmCon = RunService.RenderStepped:Connect(function(dt)
		if not filmOn then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local s = SHOTS[shotIndex]
		shotT += dt
		local a = ease(math.clamp(shotT / s.secs, 0, 1))
		cam.FieldOfView = 52
		cam.CFrame = CFrame.lookAt(s.from:Lerp(s.to, a), s.lookA:Lerp(s.lookB, a))
		if shotT > s.secs - 0.6 and not black:GetAttribute("Cutting") then
			black:SetAttribute("Cutting", true)
			UI.tween(black, 0.55, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
			streamAround(SHOTS[shotIndex % #SHOTS + 1].from)
		end
		if shotT >= s.secs then
			shotIndex = shotIndex % #SHOTS + 1
			shotT = 0
			black:SetAttribute("Cutting", nil)
			if filmOn then UI.tween(black, 0.8, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad) end
		end
	end)
	task.delay(0.4, function() if filmOn then UI.tween(black, 1.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad) end end)

	---------------------------------------------------------------- the column

	-- round 34: a soft blue fade down the left, and the column sits on a white glossy card (the chapter goals' look)
	local shade = UI.new("Frame", { Name = "Shade", Size = UDim2.fromScale(0.55, 1), BackgroundColor3 = Color3.fromRGB(16, 44, 86), ZIndex = 51, Parent = gui })
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) }), Parent = shade })
	local left = UI.new("Frame", { Name = "Left", Size = UDim2.fromOffset(520, 700), Position = UDim2.new(0, 84, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ZIndex = 52, Parent = gui })
	UI.autoScale(left)
	do
		local back = UI.new("Frame", { Name = "Panel", Size = UDim2.fromOffset(584, 740), Position = UDim2.fromOffset(-32, -34), BackgroundColor3 = T.ink, ZIndex = 52, Parent = left })
		UI.corner(back, 30)
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = back })
		UI.rim(back, Color3.fromRGB(232, 237, 244), 3)
	end
	local ICON = require(Shared:WaitForChild("Config")).ICONS
	local function L(text, size, font, color, pos, sz)
		return UI.label(left, text, size, { FontFace = font, TextColor3 = color, Position = pos, Size = sz, ZIndex = 53 })
	end
	UI.icon(left, ICON.hotel, 64, { Position = UDim2.fromOffset(-6, -10), ZIndex = 54 })
	L("OVERBOOKED", 70, UI.F.black, T.cream, UDim2.fromOffset(-3, 58), UDim2.fromOffset(520, 74))
	L("SEASIDE HOTEL TYCOON", 18, UI.F.black, T.brand, UDim2.fromOffset(2, 134), UDim2.fromOffset(520, 22))
	L("SAVE FILES", 16, UI.F.heavy, T.muted, UDim2.fromOffset(2, 190), UDim2.fromOffset(300, 20))

	local busy = false
	local start -- forward
	local replayTutorial = false
	local cards = {}
	local function cash(n)
		if type(n) ~= "number" or n ~= n or n > 1e12 then return "lots of cash" end
		return "$" .. UI.commas(n)
	end
	for i = 1, SLOTS do
		local card = UI.new("Frame", { Name = "Save" .. i, Size = UDim2.fromOffset(500, 92), Position = UDim2.fromOffset(0, 216 + (i - 1) * 102), BackgroundColor3 = T.ink2, BackgroundTransparency = 0.1, ZIndex = 53, Parent = left })
		UI.corner(card, 14)
		local st = Instance.new("UIStroke")
		st.Color = T.line
		st.Transparency = 0.4
		st.Parent = card
		local tile = UI.new("Frame", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(16, 18), BackgroundColor3 = T.line, ZIndex = 54, Parent = card })
		UI.corner(tile, 14)
		local tileCap = UI.label(tile, "FILE", 11, { FontFace = UI.F.heavy, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 12), ZIndex = 55 })
		local tileNum = UI.label(tile, tostring(i), 26, { FontFace = UI.F.black, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), ZIndex = 55 })
		local name = UI.label(card, "Save file " .. i, 22, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(88, 20), Size = UDim2.fromOffset(212, 26), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 54 })
		local sub = UI.label(card, "Checking...", 16, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(88, 48), Size = UDim2.fromOffset(212, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 54 })
		local rec = { filled = false }
		local playBtn, playText = UI.button(card, {
			text = "New hotel", kind = "green", size = UDim2.fromOffset(124, 46), pos = UDim2.new(1, -16, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 17,
			onClick = function() if rec.ready then start(i, rec.filled and replayTutorial) end end,
		})
		playBtn.ZIndex = 54
		UI.setDisabled(playBtn, true)
		-- the bin: press once to arm it, again to erase the file
		local armed = 0
		local bin = UI.new("ImageButton", { Name = "Delete", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -150, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = T.line, BackgroundTransparency = 0, AutoButtonColor = true, Visible = false, ZIndex = 54, Parent = card })
		UI.corner(bin, 10)
		local binRim = UI.rim(bin, T.red, 2) -- round 41: a solid tile, so turning red when armed never leaves it white-on-white
		binRim.Transparency = 1
		local binIcon = UI.new("ImageLabel", { Image = G.trash, ImageColor3 = T.muted, BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 55, Parent = bin })
		UI.tooltip(bin, function() return os.clock() - armed < 4 and "Press again to erase this save for good" or "Delete this save" end)
		bin.Activated:Connect(function()
			if busy or not rec.filled then return end
			if os.clock() - armed < 4 then
				armed = 0
				UI.sound("Sell")
				rec.ready = false
				UI.setDisabled(playBtn, true)
				sub.Text = "Deleting..."
				Menu:FireServer("delete", i)
			else
				armed = os.clock()
				UI.sound("Error")
				bin.BackgroundColor3 = T.red
				binIcon.ImageColor3 = Color3.new(1, 1, 1)
				binRim.Transparency = 0
				sub.TextColor3 = T.red
				sub.Text = "Press the red bin again"
				UI.pop(bin, 0.8, 0.2)
				task.delay(4, function()
					if bin.Parent and os.clock() - armed >= 4 then
						bin.BackgroundColor3 = T.line
						binIcon.ImageColor3 = T.muted
						binRim.Transparency = 1
						sub.TextColor3 = T.muted
						if rec.text then sub.Text = rec.text end
					end
				end)
			end
		end)
		function rec.set(d)
			rec.ready = true
			rec.filled = d ~= nil
			UI.setDisabled(playBtn, false)
			bin.Visible = rec.filled
			bin.BackgroundColor3 = T.line
			binIcon.ImageColor3 = T.muted
			binRim.Transparency = 1
			sub.TextColor3 = T.muted
			if d then
				name.Text = d.name or "My Hotel"
				rec.text = "Level " .. (d.level or 1) .. ",  " .. (d.rooms or 3) .. " rooms,  " .. cash(d.cash)
				tile.BackgroundColor3 = T.brand
				tileCap.Text = "LEVEL"
				tileCap.TextColor3 = T.white
				tileNum.Text = tostring(d.level or 1)
				tileNum.TextColor3 = T.white
				playText.Text = "Continue"
				UI.setKind(playBtn, "gold")
			else
				name.Text = "Empty save"
				rec.text = "Start a new hotel here"
				tile.BackgroundColor3 = T.line
				tileCap.Text = "FILE"
				tileCap.TextColor3 = T.muted
				tileNum.Text = tostring(i)
				tileNum.TextColor3 = T.muted
				playText.Text = "New hotel"
				UI.setKind(playBtn, "green")
			end
			sub.Text = rec.text
		end
		cards[i] = rec
	end

	-- replay the tutorial, settings, who is here
	local optY = 216 + SLOTS * 102 + 8
	local replayToggle, setReplay = UI.toggle(left, false, function(on) replayTutorial = on end, { pos = UDim2.fromOffset(0, optY) })
	for _, o in ipairs(replayToggle and { replayToggle, unpack(replayToggle:GetDescendants()) } or {}) do
		if o:IsA("GuiObject") then o.ZIndex += 53 end -- above the white panel
	end
	L("Replay the tutorial when I continue", 17, UI.F.bold, T.cream, UDim2.fromOffset(74, optY + 4), UDim2.fromOffset(400, 24))
	local openSettings -- forward
	local setBtn = UI.button(left, { text = "Settings", icon = G.settings, iconSize = 18, kind = "night", size = UDim2.fromOffset(160, 44), pos = UDim2.fromOffset(0, optY + 52), textSize = 17, onClick = function() openSettings() end })
	setBtn.ZIndex = 53
	local here = L("", 16, UI.F.bold, T.muted, UDim2.fromOffset(2, optY + 110), UDim2.fromOffset(500, 22))
	local function countHere()
		local n = #Players:GetPlayers() - 1
		here.Text = n <= 0 and "Just you on this street right now" or (n == 1 and "1 other player on this street" or (n .. " other players on this street"))
	end
	countHere()
	table.insert(cons, Players.PlayerAdded:Connect(countHere))
	table.insert(cons, Players.PlayerRemoving:Connect(function() task.defer(countHere) end))

	---------------------------------------------------------------- settings

	local dim = UI.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 60, Parent = gui })
	local panelWrap = UI.new("Frame", { Size = UDim2.fromOffset(580, 560), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 61, Parent = gui })
	UI.autoScale(panelWrap)
	local closeSettings
	local panel, body = UI.panel(panelWrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { title = "Settings", subtitle = "These save with your profile", onClose = function() closeSettings() end })
	local rows = UI.new("Frame", { Size = UDim2.new(1, -40, 1, -84), Position = UDim2.fromOffset(20, 76), BackgroundTransparency = 1, Parent = body })
	UI.list(rows, nil, 6)
	local function row(order, title, hint)
		local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = rows })
		UI.corner(r, 10)
		UI.label(r, title, 16, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(300, 20) })
		UI.label(r, hint, 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 29), Size = UDim2.fromOffset(300, 18) })
		return r
	end
	local function volume(order, title, hint, attr, offAttr)
		local r = row(order, title, hint)
		local v = player:GetAttribute(attr)
		if v == nil then v = player:GetAttribute(offAttr) and 0 or 100 end
		UI.slider(r, 0, 100, v, function(nv)
			player:SetAttribute(attr, nv)
			player:SetAttribute(offAttr, nv <= 0 and true or nil)
		end, { size = UDim2.fromOffset(200, 28), pos = UDim2.new(1, -214, 0.5, -14), step = 5 })
	end
	local function switch(order, title, hint, on, fn)
		local r = row(order, title, hint)
		UI.toggle(r, on, fn, { pos = UDim2.new(1, -14, 0.5, 0), anchor = Vector2.new(1, 0.5) })
	end
	volume(1, "Music", "How loud the music is", "MusicVol", "MusicOff")
	volume(2, "Sounds", "Voices, doors, coins and the rest", "SfxVol", "SfxOff")
	switch(3, "Menu sounds", "Clicks on buttons", player:GetAttribute("UiSfxOff") ~= true, function(on) player:SetAttribute("UiSfxOff", not on and true or nil) end)
	if player:GetAttribute("Sprint") == nil then player:SetAttribute("Sprint", true) end
	switch(4, "Sprint", "Hold Shift to run", player:GetAttribute("Sprint") ~= false, function(on) player:SetAttribute("Sprint", on) end)
	switch(5, "Shadows", "Turn off for a smoother game on slow devices", player:GetAttribute("ShadowsOff") ~= true, function(on) player:SetAttribute("ShadowsOff", not on and true or nil) end)
	switch(6, "Money pop-ups", "+$ and XP numbers that float up", player:GetAttribute("HidePops") ~= true, function(on) player:SetAttribute("HidePops", not on and true or nil) end)
	do
		local r = row(7, "Field of view", "How wide the camera sees")
		UI.slider(r, 55, 100, player:GetAttribute("FOV") or 70, function(nv) player:SetAttribute("FOV", nv) end, { size = UDim2.fromOffset(200, 28), pos = UDim2.new(1, -214, 0.5, -14), step = 1 })
	end
	openSettings = function()
		if busy then return end
		dim.Visible = true
		UI.tween(dim, 0.2, { BackgroundTransparency = 0.5 })
		panelWrap.Visible = true
		UI.open(panel)
	end
	closeSettings = function()
		UI.tween(dim, 0.15, { BackgroundTransparency = 1 })
		UI.close(panel, function()
			panelWrap.Visible = false
			dim.Visible = false
		end)
	end
	dim.Activated:Connect(function() closeSettings() end)

	-- arrive: the column slides in
	left.Position = UDim2.new(0, 44, 0.5, 0)
	UI.tween(left, 0.6, { Position = UDim2.new(0, 84, 0.5, 0) }, Enum.EasingStyle.Quint)

	---------------------------------------------------------------- start playing: fade, load, crane shot down to you

	local function swoopIn()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local fov = player:GetAttribute("FOV") or 70
		local function finish()
			cam.CameraType = Enum.CameraType.Custom
			if hum then cam.CameraSubject = hum end
			cam.FieldOfView = fov
		end
		if not hrp then
			UI.tween(black, 0.5, { BackgroundTransparency = 1 })
			finish()
			return
		end
		local p = hrp.Position
		local look = hrp.CFrame.LookVector * V3(1, 0, 1)
		look = look.Magnitude > 0.01 and look.Unit or V3(0, 0, -1)
		local right = look:Cross(V3(0, 1, 0))
		local a0 = p - look * 44 + right * 26 + V3(0, 56, 0)
		local a1 = p - look * 30 + right * 6 + V3(0, 20, 0)
		local a2 = p - look * 11 + V3(0, 4.6, 0)
		local f0, f2 = p + look * 22 + V3(0, 4, 0), p + look * 2 + V3(0, 1.6, 0)
		pcall(function() player:RequestStreamAroundAsync(p, 3) end)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(a0, f0)
		cam.FieldOfView = 58
		local bars = {}
		for k, y in ipairs({ 0, 1 }) do
			bars[k] = UI.new("Frame", { Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, y), AnchorPoint = Vector2.new(0, y), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 55, Parent = gui })
		end
		UI.tween(black, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		local secs = 2.7
		local t0 = os.clock()
		local done = false
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / secs, 0, 1)
			local e = k < 0.5 and 4 * k * k * k or 1 - (-2 * k + 2) ^ 3 / 2
			local pos = a0:Lerp(a1, e):Lerp(a1:Lerp(a2, e), e)
			cam.CFrame = CFrame.lookAt(pos, f0:Lerp(f2, e))
			cam.FieldOfView = 58 + (fov - 58) * e
			if k >= 1 and not done then
				done = true
				conn:Disconnect()
			end
		end)
		task.wait(secs * 0.55)
		for _, b in ipairs(bars) do UI.tween(b, secs * 0.5, { Size = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quad) end
		while not done do task.wait() end
		finish()
	end

	start = function(slot, withTutorial)
		if busy then return end
		busy = true
		Menu:FireServer("play", slot)
		UI.tween(left, 0.35, { Position = UDim2.new(0, -640, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.tween(shade, 0.4, { BackgroundTransparency = 1 })
		UI.tween(black, 0.45, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
		task.wait(0.55)
		filmOn = false
		filmCon:Disconnect()
		for _, e in ipairs(menuFx) do e:Destroy() end
		table.clear(menuFx)
		left.Visible = false
		shade.Visible = false
		local t0 = os.clock()
		while os.clock() - t0 < 8 and not (player:GetAttribute("Slot") and player:GetAttribute("Plot")) do task.wait(0.1) end
		task.wait(0.8) -- the server moves the character to the plot
		swoopIn()
		restoreGuis()
		if withTutorial then
			task.spawn(function()
				local t1 = os.clock()
				while not player:GetAttribute("Loaded") and os.clock() - t1 < 15 do task.wait(0.2) end
				Shared.Remotes.TutSkip:FireServer("replay")
			end)
		end
		teardown()
	end

	table.insert(cons, Menu.OnClientEvent:Connect(function(action, data)
		if action ~= "slots" or player:GetAttribute("Slot") then return end
		for i = 1, SLOTS do
			-- (the list arrives with string keys when a middle file is empty)
			local d = type(data) == "table" and (data[i] or data[tostring(i)]) or nil
			cards[i].set(type(d) == "table" and d or nil)
		end
	end))
	Menu:FireServer("slots")

	-- if something else starts the game (tests, a co-op move), get out of the way
	table.insert(cons, player:GetAttributeChangedSignal("Slot"):Connect(function()
		if player:GetAttribute("Slot") and not busy then
			busy = true
			filmOn = false
			filmCon:Disconnect()
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			if hum then cam.CameraSubject = hum end
			cam.FieldOfView = player:GetAttribute("FOV") or 70
			restoreGuis()
			teardown()
		end
	end))
end

local function maybeRun()
	if running or player:GetAttribute("Slot") then return end
	running = true
	run()
end
maybeRun()
player:GetAttributeChangedSignal("Slot"):Connect(function()
	if not player:GetAttribute("Slot") then
		task.defer(maybeRun)
	else
		running = false
	end
end)
