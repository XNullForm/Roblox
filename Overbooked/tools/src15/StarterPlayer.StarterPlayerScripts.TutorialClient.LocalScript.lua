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
		body = "You're the new owner. Let's learn the ropes: serving guests, keeping rooms clean and building. New buttons unlock as you go.",
		button = "Let's go",
	},
	{
		-- round 35: the story start: Aunt Marigold left rubbish all over the lobby (ServerStorage.Mess)
		icon = "clean", title = "Clean up the mess",
		body = "Aunt Marigold left the place in a state. Press E at each pile of rubbish, then rub it clean. Nobody books a tip!",
		bodyTouch = "Aunt Marigold left the place in a state. Tap each pile of rubbish, then rub it clean.",
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
		icon = "bed", title = "Open your first room", unlock = { "build" },
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
		-- round 41: the hotel only takes guests from here on (the server holds them back until "guests")
		icon = "guest", title = "Wait for your first guest",
		body = "Your hotel is open! Stay at the desk. When your first guest walks up, press their Check In button.",
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
			TutSkip:FireServer("guests")
		end,
		done = function()
			local h = hotel()
			-- round 32: no skip button, so a hired receptionist (who checks guests in for you) completes it
			return h and ((h:GetAttribute("RoomsBusy") or 0) > (mark.busy or 0) or (h:GetAttribute("Receptionists") or 0) > 0)
		end,
		waiting = function()
			local h = hotel()
			if not seatedAtDesk() then return "Sit back down at the desk to serve the next guest." end
			local gs = h and h:FindFirstChild("Guests")
			if gs and #gs:GetChildren() > 0 then return nil end
			return "Your first guest is on the way..."
		end,
	},
	{
		icon = "chat", title = "Say hello", unlock = { "hotel" },
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
		icon = "guest", title = "Hire your first staff member", unlock = { "staff" },
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
		icon = "star", title = "You're all set!", unlock = { "research", "upgrades", "achievements" },
		body = "Research, Upgrades and Awards are unlocked too. Serve the desk, keep rooms clean and build your dream hotel. Here's $500!",
		button = "Start my day", final = true,
	},
}

---------------------------------------------------------------- the coach card

local gui = UI.new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12, Enabled = false, Parent = pgui })
local W, H = 660, 188
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
local disc = UI.new("Frame", { Size = UDim2.fromOffset(96, 96), Position = UDim2.fromOffset(20, 24), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
UI.corner(disc, 48)
local discG = UI.grad(disc, Color3.fromRGB(238, 245, 255), Color3.fromRGB(210, 228, 252), 90)
UI.stroke(disc, 2, Color3.fromRGB(196, 216, 244), 0)
local discIcon = UI.icon(disc, ICON.bell, 62, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
local check = UI.icon(disc, ICON.checkmark, 56, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 1 })

local stepTag = UI.label(card, "STEP 1 OF 10", 15, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(134, 16), Size = UDim2.new(1, -260, 0, 18) })
local title = UI.label(card, "", 28, { FontFace = UI.F.black, Position = UDim2.fromOffset(134, 34), Size = UDim2.new(1, -186, 0, 32), TextTruncate = Enum.TextTruncate.AtEnd })
local body = UI.label(card, "", 19, {
	FontFace = UI.F.bold, TextColor3 = Color3.fromRGB(62, 70, 86), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
	Position = UDim2.fromOffset(134, 70), Size = UDim2.new(1, -156, 0, 56),
})
local waitLine = UI.label(card, "", 16, { FontFace = UI.F.heavy, TextColor3 = T.gold, Position = UDim2.fromOffset(134, 134), Size = UDim2.new(1, -330, 0, 20), TextTransparency = 1, TextTruncate = Enum.TextTruncate.AtEnd })

-- progress pips along the bottom
local pips = UI.new("Frame", { Size = UDim2.new(1, -330, 0, 8), Position = UDim2.fromOffset(134, 164), BackgroundTransparency = 1, Parent = card })
UI.list(pips, Enum.FillDirection.Horizontal, 4)
local pipList = {}
for i = 1, #STEPS do
	local p = UI.new("Frame", { Size = UDim2.new(1 / #STEPS, -4, 1, 0), BackgroundColor3 = T.ink3, LayoutOrder = i, Parent = pips })
	UI.corner(p, 3)
	pipList[i] = p
end

-- buttons: the main one (info steps), Skip step (after a few seconds) and the close X (skip the tutorial)
local nextBtn = UI.button(card, { text = "Next", kind = "gold", size = UDim2.fromOffset(170, 48), pos = UDim2.new(1, -18, 1, -14), anchor = Vector2.new(1, 1), textSize = 20, radius = 12 })
local skipBtn = UI.button(card, { text = "Skip step", kind = "ghost", size = UDim2.fromOffset(120, 34), pos = UDim2.new(1, -18, 1, -16), anchor = Vector2.new(1, 1), textSize = 14, radius = 10 })
local closeBtn = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.ink2, Parent = card })
UI.corner(closeBtn, 18)
UI.tooltip(closeBtn, "Skip the tutorial")
UI.stroke(closeBtn, 1.5, T.line, 0.3)
UI.icon(closeBtn, ICON.close, 16, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
UI.animate(closeBtn)

-- "Skip the tutorial?" confirm strip
local confirm = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 20, Parent = wrap })
UI.corner(confirm, 20)
UI.stroke(confirm, 3, T.red, 0).Thickness = 3
UI.label(confirm, "Skip the tutorial?", 28, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 32), ZIndex = 21 })
UI.label(confirm, "You can replay it any time from Settings.", 18, { FontFace = UI.F.bold, TextColor3 = T.muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 22), ZIndex = 21 })
local yesBtn = UI.button(confirm, { text = "Skip it", kind = "red", size = UDim2.fromOffset(170, 50), pos = UDim2.new(0.5, -8, 1, -22), anchor = Vector2.new(1, 1), textSize = 19, radius = 12 })
local noBtn = UI.button(confirm, { text = "Keep going", kind = "green", size = UDim2.fromOffset(170, 50), pos = UDim2.new(0.5, 8, 1, -22), anchor = Vector2.new(0, 1), textSize = 19, radius = 12 })
for _, b in ipairs({ yesBtn, noBtn }) do
	b.ZIndex = 22
	for _, d in ipairs(b:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex += 21 end end
end

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
	wrapScale.Scale = k -- round 41: full size again, the words were too small
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

-- round 41: the pages unlock step by step (UI.locked reads player attribute TutLock); a replay keeps them open
local LOCKABLE = { "build", "hotel", "staff", "research", "upgrades", "achievements" }
local lockOn = false
local function applyLocks(i)
	if not lockOn then player:SetAttribute("TutLock", nil) return end
	local open = {}
	for k = 1, i do for _, id in ipairs(STEPS[k].unlock or {}) do open[id] = true end end
	local list = {}
	for _, id in ipairs(LOCKABLE) do if not open[id] then table.insert(list, id) end end
	local was = player:GetAttribute("TutLock")
	local now = #list > 0 and ("," .. table.concat(list, ",") .. ",") or nil
	player:SetAttribute("TutLock", now)
	if was and i > 1 and STEPS[i].unlock then
		UI.toast("Unlocked: " .. table.concat(STEPS[i].unlock, ", "):gsub("achievements", "awards"):gsub("^%l", string.upper), "star", "good")
	end
end

local function showStep(i)
	local s = STEPS[i]
	index, stepT = i, 0
	mark = {}
	applyLocks(i)
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
	lockOn = false
	applyLocks(#STEPS)
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

local function start(replay)
	if running then return end
	lockOn = not replay
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
	local busy = pgui:FindFirstChild("Minigame") ~= nil or pgui:FindFirstChild("MessGame") ~= nil or player:GetAttribute("MenuOpen") == true or not player:GetAttribute("Slot")
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


---------------------------------------------------------------- round 41: the tutorial's cleaning minigame
-- In the tutorial, each pile of Aunt Marigold's mess opens a quick rub-it-clean game (Mess sends Notify "messgame"
-- { model, kind }). Hold and rub over the grime until it's all gone; winning tells the server to clear the pile
-- (Remotes.TutSkip("mess", model)). Player attribute TestMG = "win" finishes it at once (Studio tests).
local MESS = {
	bag = { "Bag the rubbish", "Hold and rub over the rubbish to scoop it up", Color3.fromRGB(58, 62, 72), "blob", 5 },
	dust = { "Sweep the dust", "Hold and rub to sweep the dust away", Color3.fromRGB(150, 128, 98), "blob", 9 },
	papers = { "Pick up the papers", "Hold and rub over the papers to gather them", Color3.fromRGB(240, 234, 216), "sheet", 7 },
	planks = { "Clear the planks", "Hold and rub over the planks to stack them away", Color3.fromRGB(150, 104, 60), "plank", 4 },
	puddle = { "Mop the puddle", "Hold and rub to mop it dry", Color3.fromRGB(96, 156, 226), "blob", 5 },
}
local messOpen = false
local function messGame(model, kind)
	if messOpen or not (model and model.Parent) then return end
	local def = MESS[kind] or MESS.dust
	messOpen = true
	local g = UI.new("ScreenGui", { Name = "MessGame", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Parent = pgui })
	local dim = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = g })
	UI.tween(dim, 0.25, { BackgroundTransparency = 0.45 })
	local wrapM = UI.new("Frame", { Size = UDim2.fromOffset(600, 470), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = g })
	UI.autoScale(wrapM)
	local cardM = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = wrapM })
	UI.corner(cardM, 24)
	UI.grad(cardM, Color3.new(1, 1, 1), Color3.fromRGB(232, 240, 252), 90)
	UI.stroke(cardM, 3, T.brand, 0).Thickness = 3
	UI.icon(cardM, ICON.clean, 56, { Position = UDim2.fromOffset(20, 14) })
	UI.label(cardM, def[1], 28, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(88, 14), Size = UDim2.new(1, -150, 0, 32) })
	UI.label(cardM, def[2], 18, { FontFace = UI.F.bold, TextColor3 = T.muted, Position = UDim2.fromOffset(88, 48), Size = UDim2.new(1, -150, 0, 22) })
	local x = UI.new("TextButton", { Text = "", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.ink2, Parent = cardM })
	UI.corner(x, 20)
	UI.icon(x, ICON.close, 20, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	-- the floor: a tiled board the mess lies on
	local area = UI.new("Frame", { Name = "Floor", Size = UDim2.new(1, -40, 0, 320), Position = UDim2.fromOffset(20, 86), BackgroundColor3 = Color3.fromRGB(214, 196, 168), ClipsDescendants = true, Parent = cardM })
	UI.corner(area, 16)
	for i = 0, 7 do
		for j = 0, 4 do
			if (i + j) % 2 == 0 then
				UI.new("Frame", { Size = UDim2.fromScale(1 / 8, 1 / 5), Position = UDim2.fromScale(i / 8, j / 5), BackgroundColor3 = Color3.fromRGB(198, 178, 148), BorderSizePixel = 0, Parent = area })
			end
		end
	end
	local barT = UI.new("Frame", { Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 1, -40), BackgroundColor3 = T.ink2, Parent = cardM })
	UI.corner(barT, 9)
	local barF = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = barT })
	UI.corner(barF, 9)
	UI.grad(barF, T.green, T.greenDk, 90)
	local barL = UI.label(barT, "", 14, { FontFace = UI.F.black, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	UI.textStroke(barL, 1.5, 0.3)
	-- the mess
	local rngM = Random.new()
	local blobs = {}
	for i = 1, def[5] do
		local sz = def[4] == "plank" and Vector2.new(rngM:NextInteger(150, 210), 34) or def[4] == "sheet" and Vector2.new(70, 90)
			or Vector2.new(rngM:NextInteger(kind == "puddle" and 90 or 54, kind == "puddle" and 140 or 92), 0)
		if sz.Y == 0 then sz = Vector2.new(sz.X, sz.X * rngM:NextNumber(0.7, 1)) end
		local b = UI.new("Frame", {
			Size = UDim2.fromOffset(sz.X, sz.Y), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rngM:NextNumber(-40, 40),
			Position = UDim2.fromScale(rngM:NextNumber(0.14, 0.86), rngM:NextNumber(0.18, 0.82)), BackgroundColor3 = def[3], ZIndex = 3, Parent = area,
		})
		UI.corner(b, def[4] == "blob" and math.floor(sz.Y / 2) or 6)
		UI.stroke(b, 2, UI.shade(def[3], -0.3), 0.2)
		UI.grad(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
		if kind == "bag" then -- a knotted top
			local knot = UI.new("Frame", { Size = UDim2.fromOffset(16, 12), Position = UDim2.new(0.5, 0, 0, -4), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = UI.shade(def[3], 0.25), ZIndex = 4, Parent = b })
			UI.corner(knot, 5)
		end
		local shineB = UI.new("Frame", { Size = UDim2.fromScale(0.35, 0.18), Position = UDim2.fromScale(0.22, 0.16), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, ZIndex = 4, Parent = b })
		UI.corner(shineB, 6)
		if def[4] == "sheet" then
			for k = 1, 4 do UI.new("Frame", { Size = UDim2.new(0.7, 0, 0, 3), Position = UDim2.fromScale(0.15, 0.15 + k * 0.15), BackgroundColor3 = Color3.fromRGB(150, 150, 160), BorderSizePixel = 0, ZIndex = 4, Parent = b }) end
		elseif def[4] == "plank" then
			UI.new("Frame", { Size = UDim2.new(1, -16, 0, 3), Position = UDim2.new(0, 8, 0.5, -1), BackgroundColor3 = UI.shade(def[3], -0.25), BorderSizePixel = 0, ZIndex = 4, Parent = b })
		end
		table.insert(blobs, { f = b, life = 1, size = sz })
	end
	local total, gone, won, closed = #blobs, 0, false, false
	-- the sponge follows the pointer
	local sponge = UI.icon(g, ICON.clean, 64, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, Visible = false })
	local held, last = false, nil
	local conns = {}
	local function close(win)
		if closed then return end
		closed = true
		for _, c in ipairs(conns) do c:Disconnect() end
		UIS.MouseIconEnabled = true
		if win then TutSkip:FireServer("mess", model) end
		UI.tween(dim, 0.25, { BackgroundTransparency = 1 })
		UI.close(cardM, function() g:Destroy() messOpen = false end)
	end
	local function progress()
		barL.Text = gone .. " / " .. total
		UI.tween(barF, 0.25, { Size = UDim2.fromScale(gone / total, 1) }, Enum.EasingStyle.Quint)
		if gone >= total and not won then
			won = true
			UI.sound("Fixed")
			local big = UI.label(area, "Spotless!", 54, { FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(400, 64), ZIndex = 10 })
			UI.textStroke(big, 4, 0, T.greenDk)
			UI.pop(big, 0.3, 0.45)
			UI.sparkles(area, 14, T.sun, 1)
			task.delay(1.0, function() close(true) end)
		end
	end
	progress()
	x.Activated:Connect(function() UI.sound("Click") close(false) end)
	table.insert(conns, UIS.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then held = true last = nil end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then held = false end
	end))
	local scrubT = 0
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if won or closed then return end
		if player:GetAttribute("TestMG") == "win" then
			player:SetAttribute("TestMG", nil)
			for _, b in ipairs(blobs) do if b.life > 0 then b.life = 0 b.f:Destroy() gone += 1 end end
			progress()
			return
		end
		local p = UIS:GetMouseLocation()
		local a0, as = area.AbsolutePosition, area.AbsoluteSize
		local inside = p.X > a0.X and p.Y > a0.Y and p.X < a0.X + as.X and p.Y < a0.Y + as.Y
		sponge.Visible = inside
		UIS.MouseIconEnabled = not inside
		sponge.Position = UDim2.fromOffset(p.X, p.Y)
		sponge.Rotation = held and math.sin(os.clock() * 30) * 14 or 0
		local moved = last and (p - last).Magnitude or 0
		last = p
		if not (held and inside and moved > 0) then return end
		local k = wrapM.AutoScale.Scale
		for _, b in ipairs(blobs) do
			if b.life > 0 then
				local c = b.f.AbsolutePosition + b.f.AbsoluteSize / 2
				local r = math.max(b.f.AbsoluteSize.X, b.f.AbsoluteSize.Y) / 2 + 26 * k
				if (p - c).Magnitude < r then
					b.life -= moved / (120 * k)
					b.f.BackgroundTransparency = 1 - math.max(b.life, 0) * 0.9 - 0.1
					local s = 0.55 + 0.45 * math.max(b.life, 0)
					b.f.Size = UDim2.fromOffset(b.size.X * s, b.size.Y * s)
					scrubT += dt
					if scrubT > 0.12 then scrubT = 0 UI.sound("Tick") end
					if b.life <= 0 then
						gone += 1
						local at = b.f.Position
						b.f:Destroy()
						local spark = UI.new("Frame", { Size = UDim2.fromOffset(10, 10), Position = at, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = area })
						UI.sparkles(spark, 8, Color3.new(1, 1, 1), 1)
						task.delay(1, function() spark:Destroy() end)
						UI.sound("Coins")
						progress()
					end
				end
			end
		end
	end))
	UI.open(cardM, { from = 0.8 })
	UI.sound("Open")
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "messgame" and type(d) == "table" then
		messGame(d.model, d.kind)
		return
	end
	if kind == "tut2" and type(d) == "table" and d.start then
		-- wait until the title screen and the loading cover are gone
		task.spawn(function()
			local t0 = os.clock()
			while (pgui:FindFirstChild("MainMenu") or pgui:FindFirstChild("Loading")) and os.clock() - t0 < 30 do task.wait(0.2) end
			task.wait(1.2)
			start(d.replay)
		end)
	end
end)
