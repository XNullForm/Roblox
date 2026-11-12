-- StarterPlayerScripts.RAH_StaffEdit (round 13): the staff wardrobe and job settings.
-- Opens when the local player attribute RAH_StaffEdit is set to a staff key ("janitor1"; RAH_Coop's team rows
-- set it). Left: a turning preview of that staff member (a clone of their real body, re-dressed locally with
-- RAH.StaffLook as you pick). Right: LOOK (name, outfit, colours, headwear, skin, hair, face) and JOB (focus,
-- shift, and for janitors the rooms they look after). Changes go to the server through Remotes.StaffEdit,
-- which saves them in the hotel (StaffLooks / StaffJobs) for good.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local Research = require(RAH:WaitForChild("Research"))
local L = require(RAH:WaitForChild("StaffLook"))
-- the hotel sim makes Remotes.StaffEdit once a hotel is running, so look it up when it is needed
local Remote = setmetatable({}, { __index = function(_, k)
	local r = RAH.Remotes:WaitForChild("StaffEdit", 10)
	return function(_, ...) if r then r:FireServer(...) end end
end })
local T = UI.T
local ICON = C.ICONS
local PLOTS = workspace:WaitForChild("Plots")

local function hotel()
	local k = player:GetAttribute("RAH_Plot")
	return k and PLOTS:FindFirstChild(k)
end
local function decode(attr)
	local h = hotel()
	local ok, t = pcall(function() return HttpService:JSONDecode(h and h:GetAttribute(attr) or "{}") end)
	return ok and type(t) == "table" and t or {}
end
local function staffModel(key)
	local h = hotel()
	if not h then return nil end
	for _, m in ipairs(h:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("StaffKey") == key then return m end
	end
end

---------------------------------------------------------------- the frame

local gui = UI.new("ScreenGui", { Name = "RAH_StaffEdit", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 26, Enabled = false, Parent = pgui })
local dim = UI.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 0.35, Parent = gui })
local W, H = 1040, 640
local holder, body = UI.panel(gui, UDim2.fromOffset(W, H), UDim2.fromScale(0.5, 0.5), { title = "Staff", icon = ICON.staff, subtitle = "", onClose = function() player:SetAttribute("RAH_StaffEdit", nil) end })
UI.autoScale(holder, Vector2.new(W + 80, H + 60))
local title, sub = body.Head.Title, body.Head.Sub

-- left: the preview
local LEFT = 360
local stage = UI.new("Frame", { Name = "Stage", Size = UDim2.new(0, LEFT, 1, -80), Position = UDim2.fromOffset(18, 66), BackgroundColor3 = Color3.new(1, 1, 1), Parent = body })
UI.corner(stage, 16)
UI.grad(stage, Color3.fromRGB(70, 66, 92), Color3.fromRGB(16, 18, 30), 90)
UI.stroke(stage, 1.5, T.line, 0.4)
-- a soft gold floor glow under the figure
local glow = UI.new("Frame", { Size = UDim2.fromOffset(250, 40), Position = UDim2.new(0.5, 0, 1, -92), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.gold, BackgroundTransparency = 0.86, Parent = stage })
UI.corner(glow, 20)
local vp = UI.new("ViewportFrame", { Size = UDim2.new(1, 0, 1, -60), BackgroundTransparency = 1, Ambient = Color3.fromRGB(150, 146, 160), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1.2, -1.4), Parent = stage })
local world = Instance.new("WorldModel")
world.Parent = vp
local cam = Instance.new("Camera")
cam.FieldOfView = 30
cam.Parent = vp
vp.CurrentCamera = cam
local roleChip = UI.label(stage, "", 15, { FontFace = UI.F.black, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -54), Size = UDim2.new(1, 0, 0, 20) })
local hint = UI.label(stage, "Drag to turn", 13, { FontFace = UI.F.body, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -32), Size = UDim2.new(1, 0, 0, 18) })

-- right: LOOK / JOB
local RX = LEFT + 36
local right = UI.new("Frame", { Size = UDim2.new(1, -RX - 18, 1, -80), Position = UDim2.fromOffset(RX, 66), BackgroundTransparency = 1, Parent = body })
local pageLook = UI.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -112), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1, ScrollBarThickness = 5, ScrollBarImageColor3 = T.gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = right })
UI.list(pageLook, nil, 10)
UI.pad(pageLook, 2, 2, 12, 8)
local pageJob = UI.new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1, ScrollBarThickness = 5, ScrollBarImageColor3 = T.gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false, Parent = right })
UI.list(pageJob, nil, 10)
UI.pad(pageJob, 2, 2, 12, 8)
local _, seg = UI.segmented(right, { { id = "look", text = "LOOK" }, { id = "job", text = "JOB" } }, "look", function(id)
	pageLook.Visible = id == "look"
	pageJob.Visible = id == "job"
	if id == "look" then UI.stagger(pageLook) else UI.stagger(pageJob) end
end, { size = UDim2.new(1, -12, 0, 36) })

local function section(parent, text, order)
	return UI.label(parent, string.upper(text), 13, { FontFace = UI.F.black, TextColor3 = T.gold, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 18) })
end
local function flow(parent, order, h)
	local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, h or 0), AutomaticSize = h and Enum.AutomaticSize.None or Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local g = Instance.new("UIGridLayout")
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	return f, g
end

---------------------------------------------------------------- state

local key, role, look, job = nil, nil, nil, nil
local premium = false
local preview -- the cloned body in the viewport
local refresh -- forward
local dirty = false

local function redress()
	if preview and look then
		pcall(L.dress, preview, role, look)
	end
end

local function buildPreview()
	world:ClearAllChildren()
	preview = nil
	local src = staffModel(key)
	if not src then return end
	src.Archivable = true
	local ok, m = pcall(function() return src:Clone() end)
	if not ok or not m then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("Sound") then d:Destroy() end
	end
	local CS = game:GetService("CollectionService")
	for _, d in ipairs({ m, unpack(m:GetDescendants()) }) do
		for _, t in ipairs(CS:GetTags(d)) do CS:RemoveTag(d, t) end
	end
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root then m:Destroy() return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = p == root end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	m:PivotTo(CFrame.new(0, 3, 0))
	m.Parent = world
	preview = m
	redress()
end

local yaw, dragging, lastX = math.rad(200), false, 0
stage.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragging, lastX = true, i.Position.X
	end
end)
stage.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
stage.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		yaw += (i.Position.X - lastX) * 0.012
		lastX = i.Position.X
	end
end)
RunService.RenderStepped:Connect(function(dt)
	if not gui.Enabled or not preview then return end
	if not dragging then yaw += dt * 0.35 end
	local root = preview:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, yaw, 0) end
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.4, -13.5), Vector3.new(0, 2.6, 0))
end)

---------------------------------------------------------------- LOOK page

local nameRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = T.ink2, LayoutOrder = 1, Parent = pageLook })
UI.corner(nameRow, 12)
UI.stroke(nameRow, 1.5, T.line, 0.4)
UI.label(nameRow, "NAME", 13, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(60, 18) })
local nameBox = UI.new("TextBox", { Size = UDim2.new(1, -96, 1, -10), Position = UDim2.new(0, 80, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Text = "", PlaceholderText = "Their name", ClearTextOnFocus = false, TextSize = 20, FontFace = UI.F.heavy, TextColor3 = T.cream, PlaceholderColor3 = T.muted, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Parent = nameRow })
nameBox:GetPropertyChangedSignal("Text"):Connect(function()
	if #nameBox.Text > 16 then nameBox.Text = string.sub(nameBox.Text, 1, 16) end
end)
nameBox.FocusLost:Connect(function()
	if look and nameBox.Text ~= "" and nameBox.Text ~= look.name then
		look.name = nameBox.Text
		dirty = true
		refresh()
	end
end)

local styleSec = section(pageLook, "Outfit", 2)
local styleFlow, styleGrid = flow(pageLook, 3)
styleGrid.CellSize = UDim2.new(0.25, -8, 0, 54)
styleGrid.CellPadding = UDim2.fromOffset(8, 8)
section(pageLook, "Uniform colour", 4)
local colFlow, colGrid = flow(pageLook, 5)
colGrid.CellSize = UDim2.fromOffset(38, 38)
colGrid.CellPadding = UDim2.fromOffset(8, 8)
section(pageLook, "Buttons and trim", 6)
local trimFlow, trimGrid = flow(pageLook, 7)
trimGrid.CellSize = UDim2.fromOffset(96, 34)
trimGrid.CellPadding = UDim2.fromOffset(8, 8)
section(pageLook, "Headwear and extras", 8)
local accFlow, accGrid = flow(pageLook, 9)
accGrid.CellSize = UDim2.new(0.25, -8, 0, 40)
accGrid.CellPadding = UDim2.fromOffset(8, 8)
section(pageLook, "Skin", 10)
local skinFlow, skinGrid = flow(pageLook, 11)
skinGrid.CellSize = UDim2.fromOffset(38, 38)
skinGrid.CellPadding = UDim2.fromOffset(8, 8)
section(pageLook, "Hair and face", 12)
local hfRow = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, LayoutOrder = 13, Parent = pageLook })
UI.list(hfRow, Enum.FillDirection.Horizontal, 10)

local function chip(parent, text, order, onClick)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = parent })
	UI.corner(b, 10)
	local st = UI.stroke(b, 1.5, T.line, 0.4)
	local l = UI.label(b, text, 15, { FontFace = UI.F.heavy, Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
	UI.animate(b, { hover = 1.04 })
	b.Activated:Connect(function() UI.sound("Click") onClick(b) end)
	return b, l, st
end
local function setOn(b, st, on)
	b.BackgroundColor3 = on and T.gold:Lerp(T.ink, 0.55) or T.ink2
	st.Color = on and T.gold or T.line
	st.Transparency = on and 0 or 0.4
end
local function swatch(parent, color, order, onClick)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = color, LayoutOrder = order, Parent = parent })
	UI.corner(b, 19)
	local st = UI.stroke(b, 2, T.ink, 0)
	UI.animate(b, { hover = 1.1 })
	b.Activated:Connect(function() UI.sound("Click") onClick(b) end)
	return b, st
end
local function stepper(parent, label, onStep)
	local f = UI.new("Frame", { Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = T.ink2, Parent = parent })
	UI.corner(f, 12)
	UI.stroke(f, 1.5, T.line, 0.4)
	local l = UI.label(f, label, 16, { FontFace = UI.F.heavy, Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(50, 0), TextXAlignment = Enum.TextXAlignment.Center })
	for _, d in ipairs({ -1, 1 }) do
		local b = UI.button(f, { text = d < 0 and "<" or ">", kind = "ink", size = UDim2.fromOffset(38, 34), pos = UDim2.new(d < 0 and 0 or 1, d < 0 and 6 or -6, 0.5, 0), anchor = Vector2.new(d < 0 and 0 or 1, 0.5), textSize = 18, radius = 9, onClick = function() onStep(d) end })
	end
	return l
end

local styleBtns, colBtns, trimBtns, accBtns, skinBtns = {}, {}, {}, {}, {}
local hairLabel = stepper(hfRow, "Hair", function(d)
	look.hair = (look.hair + d) % (#C.HAIR + 1)
	dirty = true
	refresh()
end)
local faceLabel = stepper(hfRow, "Face", function(d)
	look.face = (look.face - 1 + d) % #C.FACES + 1
	dirty = true
	refresh()
end)

for i, c in ipairs(L.PALETTE) do
	local b, st = swatch(colFlow, c[2], i, function() look.color = i dirty = true refresh() end)
	UI.tooltip(b, c[1])
	colBtns[i] = { b = b, st = st }
end
for i, c in ipairs(L.TRIMS) do
	local b, l, st = chip(trimFlow, c[1], i, function() look.trim = i dirty = true refresh() end)
	local dot = UI.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = c[2], Parent = b })
	UI.corner(dot, 6)
	l.Position = UDim2.fromOffset(18, 0)
	trimBtns[i] = { b = b, st = st }
end
for i, c in ipairs(C.SKIN) do
	local b, st = swatch(skinFlow, c, i, function() look.skin = i dirty = true refresh() end)
	skinBtns[i] = { b = b, st = st }
end

-- bottom bar: save / reset
local bar = UI.new("Frame", { Size = UDim2.new(1, -12, 0, 56), Position = UDim2.new(0, 0, 1, -56), BackgroundTransparency = 1, Parent = right })
local saveBtn, saveTxt = UI.button(bar, { text = "Save look", kind = "gold", size = UDim2.new(0.62, -6, 1, 0), textSize = 20, radius = 13, onClick = function(b)
	if not (key and look) then return end
	if nameBox:IsFocused() then nameBox:ReleaseFocus() end
	Remote:FireServer("look", key, look)
	dirty = false
	UI.sound("Register")
	UI.pop(b, 1.05)
	UI.toast(look.name .. "'s new look is saved", ICON.staff)
	refresh()
end })
local resetBtn = UI.button(bar, { text = "Undo changes", kind = "ink", size = UDim2.new(0.38, -6, 1, 0), pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), textSize = 17, radius = 13, onClick = function()
	look = nil
	refresh(true)
end })
pageLook:GetPropertyChangedSignal("Visible"):Connect(function() bar.Visible = pageLook.Visible end)

---------------------------------------------------------------- JOB page

local focusSec = section(pageJob, "What they do first", 1)
local focusList = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = pageJob })
UI.list(focusList, nil, 8)
section(pageJob, "Shift", 3)
local shiftFlow, shiftGrid = flow(pageJob, 4)
shiftGrid.CellSize = UDim2.new(1 / 3, -8, 0, 74)
shiftGrid.CellPadding = UDim2.fromOffset(8, 8)
local roomsSec = section(pageJob, "Their rooms", 5)
local roomsNote = UI.label(pageJob, "Pick the rooms this janitor looks after. With none picked they clean anywhere.", 14, { FontFace = UI.F.body, TextColor3 = T.muted, LayoutOrder = 6, TextWrapped = true, Size = UDim2.new(1, 0, 0, 36) })
local roomsFlow, roomsGrid = flow(pageJob, 7)
roomsGrid.CellSize = UDim2.fromOffset(92, 44)
roomsGrid.CellPadding = UDim2.fromOffset(8, 8)

local function sendJob()
	if key and job then Remote:FireServer("job", key, job) end
end

local function card(parent, title, text, order, onClick)
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.ink2, LayoutOrder = order, Parent = parent })
	UI.corner(b, 12)
	local st = UI.stroke(b, 1.5, T.line, 0.4)
	local dot = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = T.ink, Parent = b })
	UI.corner(dot, 9)
	UI.stroke(dot, 2, T.gold, 0)
	local fill = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.gold, Parent = dot })
	UI.corner(fill, 5)
	UI.label(b, title, 17, { FontFace = UI.F.black, Position = UDim2.fromOffset(48, 10), Size = UDim2.new(1, -60, 0, 22) })
	UI.label(b, text, 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(48, 33), Size = UDim2.new(1, -60, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	UI.animate(b, { hover = 1.02 })
	b.Activated:Connect(function() UI.sound("Click") onClick(b) end)
	return { b = b, st = st, fill = fill }
end
local function setCard(c, on)
	c.b.BackgroundColor3 = on and T.gold:Lerp(T.ink, 0.6) or T.ink2
	c.st.Color = on and T.gold or T.line
	c.st.Transparency = on and 0 or 0.4
	c.fill.Visible = on
end

local focusCards, shiftCards, roomChips = {}, {}, {}
for i, sh in ipairs(L.SHIFTS) do
	local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = T.ink2, LayoutOrder = i, Parent = shiftFlow })
	UI.corner(b, 12)
	local st = UI.stroke(b, 1.5, T.line, 0.4)
	UI.icon(b, ICON[i == 1 and "clock" or i == 2 and "sun" or "sleep"], 24, { Position = UDim2.fromOffset(12, 12) })
	UI.label(b, sh[2], 16, { FontFace = UI.F.black, Position = UDim2.fromOffset(44, 12), Size = UDim2.new(1, -52, 0, 22) })
	UI.label(b, sh[3], 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -20, 0, 28), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	UI.animate(b, { hover = 1.03 })
	b.Activated:Connect(function()
		UI.sound("Click")
		job.shift = sh[1]
		sendJob()
		refresh()
	end)
	shiftCards[i] = { b = b, st = st, id = sh[1] }
end

---------------------------------------------------------------- refresh

refresh = function(reload)
	if not key then return end
	local m = staffModel(key)
	role = m and m:GetAttribute("Staff") or role or string.match(key, "^(%a+)")
	local r = L.ROLES[role] or L.ROLES.janitor
	local h = hotel()
	premium = h and Research.hasPerk(h, "uniforms") or false
	if reload or not look then
		look = L.clean(role, decode("StaffLooks")[key], true, L.default(role, tonumber(string.match(key, "%d+")) or 1, m and m.Name or "Staff"))
		dirty = false
	end
	if reload or not job then
		local j = decode("StaffJobs")[key]
		job = type(j) == "table" and j or {}
		job.focus = job.focus or (L.FOCUS[role] and L.FOCUS[role][1][1])
		job.shift = job.shift or "all"
		job.rooms = type(job.rooms) == "table" and job.rooms or {}
	end
	-- header
	local def
	for _, d in ipairs(C.STAFF) do if d.id == role then def = d end end
	title.Text = look.name
	sub.Text = (def and def.name or "Staff") .. "  -  " .. ((m and m:GetAttribute("BRole")) or ""):gsub("^.-  ", "")
	roleChip.Text = string.upper(def and def.name or "Staff") .. "  -  " .. string.upper(r.styles[look.style][1])
	if not nameBox:IsFocused() then nameBox.Text = look.name end
	-- styles (rebuilt per role)
	if styleFlow:GetAttribute("Role") ~= role then
		styleFlow:SetAttribute("Role", role)
		for _, c in ipairs(styleFlow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		for _, c in ipairs(accFlow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		table.clear(styleBtns)
		table.clear(accBtns)
		for i, st in ipairs(r.styles) do
			local b, l, s = chip(styleFlow, st[1], i, function()
				if st[2] and not premium then
					UI.toast("Research Tailored Uniforms (Staff Training) to unlock", ICON.lock, "bad")
					return
				end
				look.style = i
				dirty = true
				refresh()
			end)
			if st[2] then
				UI.icon(b, ICON.star, 16, { Position = UDim2.new(1, -6, 0, 6), AnchorPoint = Vector2.new(1, 0) })
			end
			styleBtns[i] = { b = b, st = s, l = l, premium = st[2] }
		end
		for i, a in ipairs(r.acc) do
			local b, _, s = chip(accFlow, a, i, function() look.acc = i dirty = true refresh() end)
			accBtns[i] = { b = b, st = s }
		end
	end
	for i, sb in ipairs(styleBtns) do
		setOn(sb.b, sb.st, look.style == i)
		sb.l.TextTransparency = (sb.premium and not premium) and 0.55 or 0
	end
	for i, ab in ipairs(accBtns) do setOn(ab.b, ab.st, look.acc == i) end
	for i, cb in ipairs(colBtns) do
		local on = look.color == i
		cb.st.Color = on and T.gold or T.ink
		cb.st.Thickness = on and 3 or 2
	end
	for i, tb in ipairs(trimBtns) do setOn(tb.b, tb.st, look.trim == i) end
	for i, sb in ipairs(skinBtns) do
		local on = look.skin == i
		sb.st.Color = on and T.gold or T.ink
		sb.st.Thickness = on and 3 or 2
	end
	hairLabel.Text = look.hair == 0 and "No hair" or ("Hair " .. look.hair .. " of " .. #C.HAIR)
	faceLabel.Text = "Face " .. look.face .. " of " .. #C.FACES
	UI.setKind(saveBtn, dirty and "gold" or "ghost")
	saveTxt.Text = dirty and "Save look" or "Saved"
	-- job: focus cards (per role)
	if focusList:GetAttribute("Role") ~= role then
		focusList:SetAttribute("Role", role)
		for _, c in ipairs(focusList:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
		table.clear(focusCards)
		for i, f in ipairs(L.FOCUS[role] or {}) do
			focusCards[i] = card(focusList, f[2], f[3], i, function()
				job.focus = f[1]
				sendJob()
				refresh()
			end)
			focusCards[i].id = f[1]
		end
	end
	for _, c in ipairs(focusCards) do setCard(c, job.focus == c.id) end
	for _, c in ipairs(shiftCards) do setOn(c.b, c.st, job.shift == c.id) end
	-- janitor rooms
	local isJan = role == "janitor"
	roomsSec.Visible, roomsNote.Visible, roomsFlow.Visible = isJan, isJan, isJan
	if isJan and h and h:FindFirstChild("Rooms") then
		local ids = {}
		for _, rm in ipairs(h.Rooms:GetChildren()) do
			local id = rm:GetAttribute("RoomId") or tonumber(string.match(rm.Name, "%d+"))
			if id then table.insert(ids, id) end
		end
		table.sort(ids)
		local want = table.concat(ids, ",")
		if roomsFlow:GetAttribute("Ids") ~= want then
			roomsFlow:SetAttribute("Ids", want)
			for _, c in ipairs(roomsFlow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
			table.clear(roomChips)
			for i, id in ipairs(ids) do
				local b, _, s = chip(roomsFlow, "Room " .. id, i, function()
					local at
					for k, v in ipairs(job.rooms) do if tostring(v) == tostring(id) then at = k end end
					if at then table.remove(job.rooms, at) else table.insert(job.rooms, id) end
					if #job.rooms > 0 and job.focus == "nearest" then job.focus = "first" end
					sendJob()
					refresh()
				end)
				roomChips[i] = { b = b, st = s, id = id }
			end
		end
		for _, c in ipairs(roomChips) do
			local on = false
			for _, v in ipairs(job.rooms) do if tostring(v) == tostring(c.id) then on = true end end
			setOn(c.b, c.st, on)
		end
	end
	redress()
end

---------------------------------------------------------------- open / close

local function open(k)
	key, look, job, role = k, nil, nil, nil
	gui.Enabled = true
	dim.BackgroundTransparency = 1
	UI.tween(dim, 0.25, { BackgroundTransparency = 0.35 })
	refresh(true)
	buildPreview()
	refresh()
	seg.set("look", true)
	pageLook.Visible, pageJob.Visible, bar.Visible = true, false, true
	UI.open(holder)
	UI.stagger(pageLook)
end
local function close()
	UI.close(holder, function()
		gui.Enabled = false
		world:ClearAllChildren()
		preview = nil
	end)
	UI.tween(dim, 0.2, { BackgroundTransparency = 1 })
	key = nil
end
dim.Activated:Connect(function() player:SetAttribute("RAH_StaffEdit", nil) end)
player:GetAttributeChangedSignal("RAH_StaffEdit"):Connect(function()
	local k = player:GetAttribute("RAH_StaffEdit")
	if k then open(k) elseif gui.Enabled then close() end
end)
-- the real body changed (a save from here or a co-op partner): rebuild the preview from it
local watched
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui.Enabled and key then
			local m = staffModel(key)
			local rev = m and ((m:GetAttribute("LookRev") or 0) .. tostring(m))
			if rev ~= watched then
				watched = rev
				if not dirty then
					buildPreview()
					refresh(true)
				end
			end
		end
	end
end)
