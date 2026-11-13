-- StarterPlayerScripts.TutorialClient (round 12): the guided first day. The server (Tutorial) sends
-- Notify "tut2" { start = true } when a player who hasn't finished it starts playing (or asks to replay it from
-- Settings). Each step is a coach card at the top of the screen with a goal; a beacon (a bouncing marker, a
-- glowing ring on the floor and an arrow at the screen edge when it's off screen) shows where to go. Steps tick
-- themselves off by watching the game (sitting in the desk chair, the hotel's RoomsBusy, the Cleaned stat,
-- Building, the build camera, new items in HOTEL.Placed). Every step can be skipped after a few seconds.
-- Remotes.TutSkip: ("done") when finished (the server pays the reward once), ("skip") to stop it.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Notify = Shared.Remotes:WaitForChild("Notify")
local TutSkip = Shared.Remotes:WaitForChild("TutSkip")
local Catalog = require(Shared:WaitForChild("Catalog"))
local T = UI.T
local ICON = C.ICONS

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")
local TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled

local function hotel()
	local name = player:GetAttribute("Plot")
	local plots = workspace:FindFirstChild("Plots")
	return name and plots and plots:FindFirstChild(name)
end
local function root()
	local ch = player.Character
	return ch and ch:FindFirstChild("HumanoidRootPart")
end
local function seatedAtDesk()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local sp = hum and hum.SeatPart
	return sp ~= nil and sp.Name == "DeskSeat"
end
-- the closest enabled prompt in the hotel that passes ok(prompt), and where it is
local function nearestPrompt(ok)
	local h, r = hotel(), root()
	if not h then return nil end
	local best, bestD
	for _, d in ipairs(h:GetDescendants()) do
		if d:IsA("ProximityPrompt") and ok(d) then
			local p = d.Parent
			local pos = p and (p:IsA("BasePart") and p.Position or p:IsA("Attachment") and p.WorldPosition)
			if pos then
				local dist = r and (pos - r.Position).Magnitude or 0
				if not bestD or dist < bestD then best, bestD = pos, dist end
			end
		end
	end
	return best
end

---------------------------------------------------------------- the steps

-- each step: icon, title, body (or bodyTouch), button (info steps finish on a press), target() -> Vector3?,
-- begin() takes marks, done() -> true when finished, waiting() -> text shown while the goal can't happen yet
local mark = {}
local BuildMod = require(Shared:WaitForChild("Build"))
function StaffRoomOk()
	local h = hotel()
	if not h then return false, {} end
	local ok, a, b = pcall(BuildMod.staffRoom, h)
	if not ok then return false, {} end
	return a, b
end
local STEPS = {
	{
		icon = "hotel", title = "Welcome to your hotel!",
		body = "You're the new owner. Let's learn the ropes: serving guests, keeping rooms clean and building.",
		button = "Let's go",
	},
	{
		-- round 35: the story start: Aunt Marigold left rubbish all over the lobby (ServerStorage.Mess)
		icon = "clean", title = "Clean up the mess",
		body = "Aunt Marigold left the place in a state. Hold E on each pile of rubbish to clean it up. Nobody books a tip!",
		bodyTouch = "Aunt Marigold left the place in a state. Hold the button on each pile of rubbish to clean it up.",
		target = function()
			local h, r = hotel(), root()
			local best, bd
			for _, m in ipairs(CollectionService:GetTagged("Mess")) do
				if h and m:IsDescendantOf(h) and m.PrimaryPart then
					local d = r and (m.PrimaryPart.Position - r.Position).Magnitude or 0
					if not bd or d < bd then best, bd = m, d end
				end
			end
			return best and best.PrimaryPart.Position + Vector3.new(0, 2, 0)
		end,
		done = function()
			local h = hotel()
			return not h or (h:GetAttribute("MessLeft") or 0) <= 0
		end,
		waiting = function()
			local h = hotel()
			local n = h and h:GetAttribute("MessLeft")
			return n and n > 0 and (n .. " left to clean") or nil
		end,
	},
	{
		-- round 22: the hotel starts empty, so the first job is a room guests can sleep in
		icon = "bed", title = "Open your first room",
		body = "Press B to build. Put a Bed, a Shower and a Toilet in one of the rooms at the back. A room opens as soon as it has all three.",
		bodyTouch = "Tap the hammer button to build. Put a Bed, a Shower and a Toilet in one of the rooms at the back.",
		done = function()
			local h = hotel()
			local rooms = h and h:FindFirstChild("Rooms")
			for _, r in ipairs(rooms and rooms:GetChildren() or {}) do
				local st = r:GetAttribute("State")
				if st and st ~= "Unfurnished" then return true end
			end
			return false
		end,
		waiting = function()
			if player:GetAttribute("Building") ~= true then return "Open build mode (B) to furnish a room." end
			return nil
		end,
	},
	{
		icon = "checkmark", title = "Close build mode",
		body = "Your first room is open! Press B again (or DONE) to get back to your guests.",
		bodyTouch = "Your first room is open! Tap DONE to get back to your guests.",
		done = function() return player:GetAttribute("Building") ~= true end,
	},
	{
		icon = "bell", title = "Take a seat at the front desk",
		body = "Walk to the front desk and press F at the chair. You check guests in and out from the desk.",
		bodyTouch = "Walk to the front desk and tap Sit at the chair. You check guests in and out from the desk.",
		target = function()
			local h = hotel()
			local s = h and h:FindFirstChild("DeskSeat", true)
			return s and s.Position + Vector3.new(0, 2, 0)
		end,
		done = seatedAtDesk,
	},
	{
		icon = "guest", title = "Check in a guest",
		body = "When a guest reaches the desk, press their Check In button and finish the check-in.",
		target = function()
			for _, pr in ipairs(CollectionService:GetTagged("DeskPrompt")) do
				local h = hotel()
				if h and pr:IsDescendantOf(h) and pr.Parent and pr.Parent:IsA("BasePart") then return pr.Parent.Position + Vector3.new(0, 2, 0) end
			end
			return nil
		end,
		begin = function()
			local h = hotel()
			mark.busy = h and h:GetAttribute("RoomsBusy") or 0
		end,
		done = function()
			local h = hotel()
			-- round 32: no skip button, so a hired receptionist (who checks guests in for you) completes it
			return h and ((h:GetAttribute("RoomsBusy") or 0) > (mark.busy or 0) or (h:GetAttribute("Receptionists") or 0) > 0)
		end,
		waiting = function()
			local h = hotel()
			if not seatedAtDesk() then return "Sit back down at the desk to serve the next guest." end
			return nil
		end,
	},
	{
		icon = "chat", title = "Say hello",
		body = "Walk up to any guest and press F to talk. What you say changes how they feel about your hotel.",
		bodyTouch = "Walk up to any guest and tap Talk. What you say changes how they feel about your hotel.",
		target = function() return nearestPrompt(function(p) return p.ActionText == "Talk" and p.Enabled end) end,
		done = function()
			local g = pgui:FindFirstChild("Talk")
			local w = g and g:FindFirstChild("TalkWrap")
			return w ~= nil and w.Visible
		end,
	},
	{
		icon = "clean", title = "Clean a messy room",
		body = "When guests leave, rooms need a clean. Find a mess and press E to tidy it.",
		bodyTouch = "When guests leave, rooms need a clean. Find a mess and tap Clean to tidy it.",
		target = function() return nearestPrompt(function(p) return p.ActionText == "Clean" and p.Enabled end) end,
		begin = function() mark.cleaned = player:GetAttribute("Cleaned") or 0 end,
		done = function() return (player:GetAttribute("Cleaned") or 0) > (mark.cleaned or 0) end,
		waiting = function()
			if not nearestPrompt(function(p) return p.ActionText == "Clean" and p.Enabled end) then
				return "Every room is spotless right now. A mess will turn up when a guest leaves."
			end
			return nil
		end,
	},
	{
		icon = "hammer", title = "Open build mode",
		body = "Press B to start building. You can always build, even while guests are around.",
		bodyTouch = "Tap the hammer button on the left to start building.",
		done = function() return player:GetAttribute("Building") == true end,
	},
	{
		icon = "rotate", title = "Look around",
		body = "Hold the right mouse button and drag to turn. Scroll to zoom, WASD to move.",
		bodyTouch = "Drag one finger to move. Pinch to zoom, and twist two fingers to turn.",
		begin = function()
			local cam = workspace.CurrentCamera
			mark.look = cam.CFrame.LookVector
			mark.camPos = cam.CFrame.Position
		end,
		done = function()
			local cam = workspace.CurrentCamera
			if not mark.look then return false end
			local turned = math.deg(math.acos(math.clamp(cam.CFrame.LookVector:Dot(mark.look), -1, 1)))
			return turned > 30
		end,
		waiting = function()
			if player:GetAttribute("Building") ~= true then return "Open build mode again to try it." end
			return nil
		end,
	},
	{
		icon = "catFurniture", title = "Place something",
		body = "Pick any item from the catalog, aim, and click to place it. Hold and drag to lay a whole row of walls.",
		bodyTouch = "Pick any item from the catalog, tap the floor to aim, then tap Place.",
		begin = function()
			local h = hotel()
			mark.items = h and h:FindFirstChild("Placed") and #h.Placed:GetChildren() or 0
		end,
		done = function()
			local h = hotel()
			return h and h:FindFirstChild("Placed") and #h.Placed:GetChildren() > (mark.items or 0)
		end,
		waiting = function()
			if player:GetAttribute("Building") ~= true then return "Open build mode again to place something." end
			return nil
		end,
	},
	{
		-- round 14: the whole staff room, checked live (walls all round, lockers, a table and a drink)
		icon = "staff", title = "Build a staff room",
		body = "Your team needs a base before you can hire. Wall off a small room, then put in Staff Lockers, a Break Table and a Water Cooler (Staff tab).",
		done = function()
			local ok = StaffRoomOk()
			return ok
		end,
		waiting = function()
			local _, missing = StaffRoomOk()
			if missing and #missing > 0 then return "Still needed: " .. table.concat(missing, ", ") end
			if player:GetAttribute("Building") ~= true then return "Open build mode and look in the Staff tab." end
			return nil
		end,
	},
	{
		icon = "checkmark", title = "Finish building",
		body = "Press B again (or DONE) to go back to running your hotel.",
		bodyTouch = "Tap DONE to go back to running your hotel.",
		done = function() return player:GetAttribute("Building") ~= true end,
	},
	{
		-- round 14: pick your first hire from the candidates
		icon = "guest", title = "Hire your first staff member",
		body = "Press T (Staff) and pick someone. Every candidate has a skill, a pro and a con. A receptionist is a great first hire.",
		bodyTouch = "Tap STAFF and pick someone. Every candidate has a skill, a pro and a con.",
		begin = function()
			local h = hotel()
			local n = 0
			for _, d in ipairs(C.STAFF) do n += h and (h:GetAttribute(d.attr) or 0) or 0 end
			mark.staff = n
			if player:GetAttribute("MenuOpen") ~= true then player:SetAttribute("MenuWant", "staff") end
		end,
		done = function()
			local h = hotel()
			local n = 0
			for _, d in ipairs(C.STAFF) do n += h and (h:GetAttribute(d.attr) or 0) or 0 end
			return n > (mark.staff or 0)
		end,
		waiting = function()
			if (player:GetAttribute("Cash") or 0) < 700 then return "Save up a little cash first: serve a few guests." end
			return nil
		end,
	},
	{
		icon = "star", title = "You're all set!",
		body = "Serve the desk, keep rooms clean and build your dream hotel. Here's $500 to get you started.",
		button = "Start my day", final = true,
	},
}

---------------------------------------------------------------- the coach card

local gui = UI.new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12, Enabled = false, Parent = pgui })
local W, H = 560, 150
local wrap = UI.new("Frame", { Name = "Coach", Size = UDim2.fromOffset(W, H), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
local wrapScale = UI.new("UIScale", { Name = "Fit", Parent = wrap })
local card = UI.new("CanvasGroup", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.paper or T.ink, Parent = wrap })
UI.corner(card, 20)
-- round 34: the chapter look (white plate, soft rim, a light blue icon tile)
UI.shadow(wrap, { drop = 5, transparency = 0.7 })
local cardStroke = UI.stroke(card, 2.5, Color3.fromRGB(232, 237, 244), 0)
-- a soft sweep of light that runs across the card when a step arrives
local sweep = UI.new("Frame", { Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(-0.3, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, Rotation = 0, Parent = card })
UI.grad(sweep, Color3.new(1, 1, 1), Color3.new(1, 1, 1), 0).Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
})

-- the icon disc with a progress ring round it
local disc = UI.new("Frame", { Size = UDim2.fromOffset(84, 84), Position = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
UI.corner(disc, 42)
local discG = UI.grad(disc, Color3.fromRGB(238, 245, 255), Color3.fromRGB(210, 228, 252), 90)
UI.stroke(disc, 2, Color3.fromRGB(196, 216, 244), 0)
local discIcon = UI.icon(disc, ICON.bell, 52, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local check = UI.icon(disc, ICON.checkmark, 56, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 1 })

local stepTag = UI.label(card, "STEP 1 OF 10", 13, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(124, 18), Size = UDim2.new(1, -260, 0, 16) })
local title = UI.label(card, "", 24, { FontFace = UI.F.black, Position = UDim2.fromOffset(124, 36), Size = UDim2.new(1, -146, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd })
local body = UI.label(card, "", 15, {
	FontFace = UI.F.body, TextColor3 = T.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(124, 68), Size = UDim2.new(1, -146, 0, 40),
})
local waitLine = UI.label(card, "", 13, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(124, 112), Size = UDim2.new(1, -330, 0, 18), TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd })

-- progress pips along the bottom
local pips = UI.new("Frame", { Size = UDim2.new(1, -330, 0, 6), Position = UDim2.fromOffset(124, 134), BackgroundTransparency = 1, Parent = card })
UI.list(pips, Enum.FillDirection.Horizontal, 4)
local pipList = {}
for i = 1, #STEPS do
	local p = UI.new("Frame", { Size = UDim2.new(1 / #STEPS, -4, 1, 0), BackgroundColor3 = T.ink3, LayoutOrder = i, Parent = pips })
	UI.corner(p, 3)
	pipList[i] = p
end

-- buttons: the main one (info steps), Skip step (after a few seconds) and the close X (skip the tutorial)
local nextBtn = UI.button(card, { text = "Next", kind = "gold", size = UDim2.fromOffset(150, 44), pos = UDim2.new(1, -18, 1, -16), anchor = Vector2.new(1, 1), textSize = 18, radius = 12 })
local skipBtn = UI.button(card, { text = "Skip step", kind = "ghost", size = UDim2.fromOffset(120, 34), pos = UDim2.new(1, -18, 1, -16), anchor = Vector2.new(1, 1), textSize = 14, radius = 10 })
local closeBtn = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.ink2, Parent = card })
UI.corner(closeBtn, 15)
UI.stroke(closeBtn, 1.5, T.line, 0.3)
UI.icon(closeBtn, ICON.close, 16, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
UI.animate(closeBtn)

-- "Skip the tutorial?" confirm strip
local confirm = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 52), Position = UDim2.new(0, 0, 1, 10), BackgroundColor3 = T.ink, Visible = false, Parent = wrap })
UI.corner(confirm, 14)
UI.stroke(confirm, 1.5, T.red, 0.3)
UI.label(confirm, "Skip the tutorial? You can replay it from Settings.", 15, { FontFace = UI.F.bold, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -230, 1, 0), TextWrapped = true })
local yesBtn = UI.button(confirm, { text = "Skip", kind = "red", size = UDim2.fromOffset(90, 36), pos = UDim2.new(1, -110, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 15, radius = 10 })
local noBtn = UI.button(confirm, { text = "Keep going", kind = "ghost", size = UDim2.fromOffset(110, 36), pos = UDim2.new(1, -10, 0.5, -2), anchor = Vector2.new(1, 0.5), textSize = 14, radius = 10 })

---------------------------------------------------------------- the beacon: a marker over the goal, a ring on the floor, an edge arrow

local beaconAt = Instance.new("Attachment")
beaconAt.Name = "TutBeacon"
local marker = UI.new("BillboardGui", { Name = "TutMarker", Size = UDim2.fromOffset(120, 120), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Adornee = beaconAt, Parent = pgui })
local markerBox = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = marker })
local pin = UI.new("Frame", { Size = UDim2.fromOffset(58, 58), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = markerBox })
UI.corner(pin, 29)
UI.grad(pin, Color3.fromRGB(255, 222, 140), Color3.fromRGB(196, 126, 40), 90)
UI.stroke(pin, 3, Color3.fromRGB(110, 64, 18), 0)
local pinIcon = UI.icon(pin, ICON.bell, 36, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local pinTip = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = Color3.fromRGB(196, 126, 40), ZIndex = 0, Parent = markerBox })
local distLabel = UI.label(markerBox, "", 15, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 80), Size = UDim2.new(1, 0, 0, 20) })
UI.textStroke(distLabel, 2, 0.3)

local ring = Instance.new("Part")
ring.Name = "TutRing"
ring.Shape = Enum.PartType.Cylinder
ring.Size = Vector3.new(0.12, 7, 7)
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
ring.Material = Enum.Material.Neon
ring.Color = T.gold
ring.Transparency = 1
local ringHole = Instance.new("Part") -- the darker centre, so it reads as a ring
ringHole.Name = "Hole"
ringHole.Shape = Enum.PartType.Cylinder
ringHole.Size = Vector3.new(0.14, 5.6, 5.6)
ringHole.Anchored, ringHole.CanCollide, ringHole.CanQuery, ringHole.CanTouch, ringHole.CastShadow = true, false, false, false, false
ringHole.Material = Enum.Material.SmoothPlastic
ringHole.Color = Color3.fromRGB(30, 26, 20)
ringHole.Transparency = 1

local edge = UI.new("Frame", { Name = "EdgeArrow", Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = gui })
local edgeDisc = UI.new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.ink, Parent = edge })
UI.corner(edgeDisc, 26)
UI.stroke(edgeDisc, 2.5, T.gold, 0)
local edgeIcon = UI.icon(edgeDisc, ICON.bell, 30, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local edgeArrow = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = T.gold, ZIndex = 0, Parent = edge })

---------------------------------------------------------------- running it

local running, index, stepT, finishing = false, 0, 0, false
local target -- the current goal's position (or nil)

local function layout()
	local vp = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(vp.X / 1500, vp.Y / 860), TOUCH and 0.5 or 0.62, 1.1)
	if TOUCH then k = math.min(k, (vp.X - 24) / W) end
	wrapScale.Scale = k * 0.85 -- round 32: a little smaller
	-- under the top bar (phones publish where it ends); near the top while building (the HUD steps aside)
	local y = 112
	local hud = pgui:FindFirstChild("HUD")
	local pb = hud and hud:GetAttribute("PhoneBarBottom")
	if pb then y = pb + 64 * k end
	local tb = hud and hud:FindFirstChild("Top")
	if not pb and tb and tb.AbsoluteSize.Y > 0 then y = tb.AbsolutePosition.Y + tb.AbsoluteSize.Y + 58 + 16 end
	if player:GetAttribute("Building") == true then y = TOUCH and 12 or 70 end
	-- while a conversation card is up at the bottom, nothing changes; while a minigame fills the screen, hide
	wrap.Position = UDim2.new(0.5, 0, 0, y)
end

local function setPips(n, flash)
	for i, p in ipairs(pipList) do
		local on = i <= n
		UI.tween(p, 0.35, { BackgroundColor3 = on and T.gold or T.ink3 })
		if flash and i == n then UI.pop(p, 1.6) end
	end
end

local function textFor(s)
	return (TOUCH and s.bodyTouch) or s.body
end

local function showStep(i)
	local s = STEPS[i]
	index, stepT = i, 0
	mark = {}
	if s.begin then s.begin() end
	stepTag.Text = "STEP " .. i .. " OF " .. #STEPS
	discIcon.Image = ICON[s.icon] or ICON.star
	pinIcon.Image = discIcon.Image
	edgeIcon.Image = discIcon.Image
	check.ImageTransparency = 1
	discIcon.ImageTransparency = 0
	discG.Color = ColorSequence.new(Color3.fromRGB(238, 245, 255), Color3.fromRGB(210, 228, 252))
	-- the words type in
	title.Text = s.title
	title.MaxVisibleGraphemes = 0
	body.Text = textFor(s)
	body.MaxVisibleGraphemes = 0
	waitLine.TextTransparency = 1
	task.spawn(function()
		local n = utf8.len(s.title) or #s.title
		for k = 1, n, 2 do
			if index ~= i then return end
			title.MaxVisibleGraphemes = k
			task.wait(0.012)
		end
		title.MaxVisibleGraphemes = -1
		local m = utf8.len(body.Text) or #body.Text
		for k = 1, m, 4 do
			if index ~= i then return end
			body.MaxVisibleGraphemes = k
			task.wait(0.01)
		end
		body.MaxVisibleGraphemes = -1
	end)
	nextBtn.Visible = s.button ~= nil
	if s.button then
		local l = nextBtn:FindFirstChild("Label", true)
		if l then l.Text = s.button end
		UI.pop(nextBtn, 0.7)
	end
	skipBtn.Visible = false
	setPips(i - 1)
	-- the card bumps, the light sweeps
	UI.pop(wrap, 0.94)
	sweep.Position = UDim2.new(-0.3, 0, 0, 0)
	UI.tween(sweep, 0.9, { Position = UDim2.new(1.1, 0, 0, 0) }, Enum.EasingStyle.Quad)
	local ds = UI.scaleOf(disc)
	ds.Scale = 0.6
	UI.tween(ds, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	disc.Rotation = -25
	UI.tween(disc, 0.6, { Rotation = 0 }, Enum.EasingStyle.Elastic)
	UI.sound("Open")
end

local function stopBeacon()
	target = nil
	marker.Enabled = false
	edge.Visible = false
	ring.Parent, ringHole.Parent = nil, nil
	beaconAt.Parent = nil
end

local function finish(skipped)
	running = false
	stopBeacon()
	if not skipped then TutSkip:FireServer("done") else TutSkip:FireServer("skip") end
	UI.tween(card, 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UI.tween(UI.scaleOf(wrap), 0.3, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	confirm.Visible = false
	task.delay(0.32, function()
		if not running then gui.Enabled = false end
	end)
end

-- a step done: the disc flips to a green check, a few sparks burst out, then the next step arrives
local function complete()
	if finishing then return end
	finishing = true
	local i = index
	UI.sound("Fixed")
	discG.Color = ColorSequence.new(Color3.fromRGB(170, 250, 170), T.greenDk)
	UI.tween(discIcon, 0.15, { ImageTransparency = 1 })
	check.ImageTransparency = 0
	UI.pop(check, 0.3)
	UI.pop(disc, 1.25)
	UI.tween(cardStroke, 0.15, { Color = T.green, Transparency = 0 })
	setPips(i, true)
	for k = 1, 10 do
		local a = (k / 10) * math.pi * 2
		local spark = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = k % 2 == 0 and T.gold or T.green, ZIndex = 5, Parent = card })
		UI.corner(spark, 4)
		UI.tween(spark, 0.55, { Position = UDim2.fromOffset(64 + math.cos(a) * 70, 64 + math.sin(a) * 70), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
		task.delay(0.6, function() spark:Destroy() end)
	end
	stopBeacon()
	task.delay(0.9, function()
		UI.tween(cardStroke, 0.3, { Color = Color3.fromRGB(232, 237, 244), Transparency = 0 })
		finishing = false
		if not running or index ~= i then return end
		if STEPS[i].final or i >= #STEPS then
			finish(false)
		else
			showStep(i + 1)
		end
	end)
end

nextBtn.Activated:Connect(function()
	if running and not finishing and STEPS[index] and STEPS[index].button then complete() end
end)
skipBtn.Activated:Connect(function()
	if running and not finishing then complete() end
end)
closeBtn.Activated:Connect(function()
	if not running then return end
	confirm.Visible = not confirm.Visible
	if confirm.Visible then UI.pop(confirm, 0.9) end
end)
yesBtn.Activated:Connect(function() if running then finish(true) end end)
noBtn.Activated:Connect(function() confirm.Visible = false end)

local function start()
	if running then return end
	running = true
	finishing = false
	gui.Enabled = true
	card.GroupTransparency = 1
	UI.scaleOf(wrap).Scale = 1
	layout()
	local base = wrap.Position
	wrap.Position = base - UDim2.fromOffset(0, 40)
	UI.tween(wrap, 0.6, { Position = base }, Enum.EasingStyle.Back)
	UI.tween(card, 0.35, { GroupTransparency = 0 })
	showStep(1)
end

-- every frame: place the beacon, run the step's checks, and lay the card out
local checkT = 0
RunService.RenderStepped:Connect(function(dt)
	if not running then return end
	layout()
	-- a full-screen minigame or the menu window covers the card; the title screen hides it too
	local busy = pgui:FindFirstChild("Minigame") ~= nil or player:GetAttribute("MenuOpen") == true or not player:GetAttribute("Slot")
	wrap.Visible = not busy
	stepT += dt
	local s = STEPS[index]
	if not s then return end
	checkT += dt
	if checkT >= 0.2 and not finishing then
		checkT = 0
		if s.done and s.done() then
			complete()
			return
		end
		target = s.target and s.target() or nil
		local w = s.waiting and s.waiting()
		if w then
			if waitLine.Text ~= w then waitLine.Text = w end
			if waitLine.TextTransparency > 0.5 then UI.tween(waitLine, 0.3, { TextTransparency = 0 }) end
		elseif waitLine.TextTransparency < 0.5 then
			UI.tween(waitLine, 0.3, { TextTransparency = 1 })
		end
		-- round 32: no skipping single steps; finish it or skip the whole tutorial (X)
		local canSkip = false
		if canSkip ~= skipBtn.Visible then
			skipBtn.Visible = canSkip
			if canSkip then UI.pop(skipBtn, 0.7) end
		end
	end
	-- the beacon
	local cam = workspace.CurrentCamera
	if target and not busy and player:GetAttribute("Building") ~= true then
		beaconAt.Parent = workspace.Terrain
		beaconAt.WorldPosition = target + Vector3.new(0, 2.6 + math.sin(os.clock() * 4) * 0.35, 0)
		marker.Enabled = true
		local r = root()
		distLabel.Text = r and (math.floor((target - r.Position).Magnitude / 3.57 + 0.5) .. " m") or ""
		-- the floor ring under the goal
		local floorY = target.Y - 2
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = { player.Character, ring, ringHole }
		local hit = workspace:Raycast(target, Vector3.new(0, -12, 0), rp)
		if hit then floorY = hit.Position.Y end
		local pulse = 1 + 0.12 * math.sin(os.clock() * 5)
		ring.Size = Vector3.new(0.08, 6 * pulse, 6 * pulse)
		ringHole.Size = Vector3.new(0.1, 4.9 * pulse, 4.9 * pulse)
		ring.CFrame = CFrame.new(target.X, floorY + 0.06, target.Z) * CFrame.Angles(0, 0, math.rad(90))
		ringHole.CFrame = ring.CFrame * CFrame.new(0.01, 0, 0)
		ring.Transparency, ringHole.Transparency = 0.25, 0.55
		ring.Parent, ringHole.Parent = cam, cam
		-- off screen: an arrow on the screen's edge points the way
		local sp, onScreen = cam:WorldToViewportPoint(target)
		local vp = cam.ViewportSize
		if onScreen and sp.X > 0 and sp.X < vp.X and sp.Y > 0 and sp.Y < vp.Y then
			edge.Visible = false
		else
			local c = vp / 2
			local dir = Vector2.new(sp.X, sp.Y) - c
			if sp.Z < 0 then dir = -dir end
			if dir.Magnitude < 1 then dir = Vector2.new(0, 1) end
			dir = dir.Unit
			local m = 56
			local sx = (c.X - m) / math.max(math.abs(dir.X), 1e-3)
			local sy = (c.Y - m) / math.max(math.abs(dir.Y), 1e-3)
			local p = c + dir * math.min(sx, sy)
			edge.Position = UDim2.fromOffset(p.X, p.Y)
			edgeArrow.Position = UDim2.new(0.5, dir.X * 30, 0.5, dir.Y * 30)
			edge.Visible = true
		end
	else
		marker.Enabled = false
		edge.Visible = false
		ring.Parent, ringHole.Parent = nil, nil
	end
end)

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "tut2" and type(d) == "table" and d.start then
		-- wait until the title screen and the loading cover are gone
		task.spawn(function()
			local t0 = os.clock()
			while (pgui:FindFirstChild("MainMenu") or pgui:FindFirstChild("Loading")) and os.clock() - t0 < 30 do task.wait(0.2) end
			task.wait(1.2)
			start()
		end)
	end
end)
