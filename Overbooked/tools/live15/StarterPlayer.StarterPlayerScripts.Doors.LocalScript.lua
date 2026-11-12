-- Run a Hotel: hinged doors (round 10). Every model tagged SwingDoor (the room doors and the build-mode
-- Door item) holds a Pivot part on its hinge line and a Leaf model. When a player, guest or staff member
-- comes within REACH of the doorway the leaf swings open by the model's Swing attribute (degrees about the
-- hinge), and it shuts again once they've gone. It all happens on each client: the server keeps every leaf
-- shut, and leaves never collide, so a door can't trap anyone.
-- Round 10c:
--   * a room whose guest is inside is Locked (room attribute): its door only swings for guests and staff
--   * a player on the push side drives the door: it opens just enough to keep its knob at arm's length ahead
--     of them (and never swings through them), so it follows them in and closes as they back away. Their
--     hand rides on that knob (an IKControl per arm, on every client, for every player) and lets go once
--     they've walked away. Guests and staff, and players pulling from the far side, swing it fully open
--   * Notify "knock" plays the knock (sound + a knuckle tap on the door); Notify "doorReply" shows what the
--     guest calls back, in a bubble on the door
local CS = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local Notify = Shared:WaitForChild("Remotes"):WaitForChild("Notify")
local T = UI.T
local player = Players.LocalPlayer

local REACH = 6.5
local SPEED = 3.2 -- full swings per second
local GRAB_NEAR, GRAB_FAR = 3.4, 5.2 -- the hand is fully on the knob inside GRAB_NEAR, back by GRAB_FAR
local ARM = 2.5 -- how far ahead of a pushing player the knob is held (studs)
local BODY = 1.1 -- a player's radius, for keeping the leaf out of them

local doors = {} -- model -> { pivot, swing, parts, offs, seen, centre, knobs, t, goal }

-- only real doors in a hotel (not the catalogue template or a build-mode ghost)
local function live(m)
	return m:IsDescendantOf(workspace) and (m:FindFirstAncestor("Rooms") or m:FindFirstAncestor("Placed")) ~= nil
end

-- picks up leaf parts as they stream in; the server keeps them shut, so their CFrame is the closed one
local function gather(d)
	local leaf = d.model:FindFirstChild("Leaf")
	if not leaf then return end
	local added = false
	for _, p in ipairs(leaf:GetDescendants()) do
		if p:IsA("BasePart") and not d.seen[p] then
			d.seen[p] = true
			table.insert(d.parts, p)
			table.insert(d.offs, d.pivot.CFrame:ToObjectSpace(p.CFrame))
			if p.Name == "Knob" then
				table.insert(d.knobs, p)
				-- the push-side knob: the one furthest out on the side the leaf swings away from
				local z = d.offs[#d.offs].Position.Z * d.dir
				if not d.pushKnob or z > d.pushKnob.Z * d.dir then d.pushKnob = d.offs[#d.offs].Position end
				d.pushPart = (d.pushKnob == d.offs[#d.offs].Position) and p or d.pushPart
			end
			added = true
		end
	end
	if added then
		local sum = Vector3.zero
		for _, o in ipairs(d.offs) do sum += o.Position end
		d.centre = sum / #d.offs
	end
end

local function track(m)
	if doors[m] or not m:IsA("Model") or not live(m) then return end
	local pivot = m.PrimaryPart or m:FindFirstChild("Pivot")
	if not pivot then return end
	local swing = m:GetAttribute("Swing") or 90
	local d = { model = m, pivot = pivot, swing = swing, dir = swing >= 0 and 1 or -1, parts = {}, offs = {}, seen = {}, knobs = {}, t = 0, goal = 0, push = 0, e = 0 }
	doors[m] = d
	gather(d)
end

CS:GetInstanceAddedSignal("SwingDoor"):Connect(function(m) task.defer(track, m) end)
CS:GetInstanceRemovedSignal("SwingDoor"):Connect(function(m) doors[m] = nil end)
for _, m in ipairs(CS:GetTagged("SwingDoor")) do track(m) end

-- who can open a door: players (not through a locked door), and every guest or staff member in a hotel
local lastPos = {} -- npc root -> position last check (only an npc that's actually moving holds a door open)
local npcRoots = {} -- round 14: moving guests and staff push doors and reach for the knob like players do
local function movers()
	table.clear(npcRoots)
	local people, npcs = {}, {}
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(people, r.Position) end
	end
	local holders = {}
	local plots = workspace:FindFirstChild("Plots")
	if plots then for _, h in ipairs(plots:GetChildren()) do table.insert(holders, h) end end
	if workspace:FindFirstChild("Hotel") then table.insert(holders, workspace.Hotel) end
	local seen = {}
	for _, h in ipairs(holders) do
		local g = h:FindFirstChild("Guests")
		if g then
			for _, m in ipairs(g:GetChildren()) do
				local r = m:FindFirstChild("HumanoidRootPart")
				if r then
					seen[r] = true
					-- an npc stood still by a door (idle staff, a guest pausing) must not hold it open
					local last = lastPos[r]
					if not last or (r.Position - last).Magnitude > 0.15 then
						table.insert(npcs, r.Position)
						table.insert(npcRoots, r)
					end
					lastPos[r] = r.Position
				end
			end
		end
	end
	for r in pairs(lastPos) do
		if not seen[r] then lastPos[r] = nil end
	end
	return people, npcs
end

local function anyNear(list, c, d)
	for _, p in ipairs(list) do
		local dx, dz = p.X - c.X, p.Z - c.Z
		if dx * dx + dz * dz < REACH * REACH and math.abs(p.Y - c.Y) < 8 then
			-- (with a door given, only people on its pull side count: the push side drives the door itself)
			if not d or d.pivot.CFrame:PointToObjectSpace(p).Z * d.dir < -0.2 then return true end
		end
	end
	return false
end

task.spawn(function()
	while true do
		local people, npcs = movers()
		for m, d in pairs(doors) do
			if not m.Parent or not d.pivot.Parent then
				doors[m] = nil
			else
				gather(d)
				local near = false
				if d.centre then
					local c = d.pivot.CFrame * d.centre
					local locked = m.Parent and m.Parent:GetAttribute("Locked") == true
					d.locked = locked
					-- (round 14: from the push side guests and staff drive the leaf by hand, like players)
				near = anyNear(npcs, c, (d.pushKnob and not locked) and d or nil) or (not locked and anyNear(people, c, d))
				end
				d.goal = near and 1 or 0
			end
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------- hands on the knob

local hands = {} -- character -> { L, R, side, knob, door, w }
local function handsOf(char)
	local h = hands[char]
	if h then return h end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	local function chain(side)
		local upper, hand = char:FindFirstChild(side .. "UpperArm"), char:FindFirstChild(side .. "Hand")
		if not (upper and hand) then return nil end
		local ik = Instance.new("IKControl")
		ik.Name = "Knob" .. side
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = upper
		ik.EndEffector = hand
		ik.SmoothTime = 0.06
		ik.Weight = 0
		ik.Enabled = false
		ik.Parent = hum
		return ik
	end
	local L, R = chain("Left"), chain("Right")
	if not (L and R) then return nil end
	h = { L = L, R = R, w = 0 }
	hands[char] = h
	char.AncestryChanged:Connect(function() if not char.Parent then hands[char] = nil end end)
	return h
end

-- the knob a character should reach for: the closest one on a door that's opening or open
local function pickKnob(root)
	local best, bestD, bestDoor
	for _, d in pairs(doors) do
		local moving = d.goal == 1 or d.e > 0.02
		if moving or (d.pushKnob and not d.locked) then
			for _, k in ipairs(d.knobs) do
				if k.Parent then
					local dist = (k.Position - root.Position).Magnitude
					local ok = dist < GRAB_FAR
					if ok and not moving then
						-- a shut door: only reach for a knob that's close and in front (not one you're walking past)
						local rel = root.CFrame:PointToObjectSpace(k.Position)
						ok = dist < GRAB_NEAR + 0.4 and rel.Z < -0.3 and math.abs(rel.X) < -rel.Z * 1.3
					end
					if ok and (not bestD or dist < bestD) then best, bestD, bestDoor = k, dist, d end
				end
			end
		end
	end
	return best, bestDoor
end

local handChars = {}
local function updateHands(dt)
	table.clear(handChars)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(handChars, p.Character) end
	end
	-- guests and staff near the camera reach for knobs too
	local camPos = workspace.CurrentCamera.CFrame.Position
	for _, r in ipairs(npcRoots) do
		if r.Parent and (r.Position - camPos).Magnitude < 90 then table.insert(handChars, r.Parent) end
	end
	for _, char in ipairs(handChars) do
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local h = root and handsOf(char)
		if h and not h.knocking then
			-- keep the same knob until the hand has let go of it
			if not h.knob or not h.knob.Parent or h.w < 0.02 then
				local k, d = pickKnob(root)
				if k ~= h.knob then
					h.knob, h.door = k, d
					if k then
						h.side = root.CFrame:PointToObjectSpace(k.Position).X < 0 and "L" or "R"
						h.L.Target, h.R.Target = k, k
					end
				end
			end
			local want = 0
			if h.knob and h.knob.Parent and h.door then
				local dist = (h.knob.Position - root.Position).Magnitude
				want = math.clamp((GRAB_FAR - dist) / (GRAB_FAR - GRAB_NEAR), 0, 1)
				-- never wrench an arm behind the back
				local rel = root.CFrame:PointToObjectSpace(h.knob.Position)
				if rel.Z > 0.4 then want *= math.clamp(1 - (rel.Z - 0.4) / 1.2, 0, 1) end
				-- a locked door stays shut: no reaching for it
				if h.door.locked and Players:GetPlayerFromCharacter(char) then want = 0 end
			end
			h.w += (want - h.w) * math.min(1, dt * 9)
			if h.w < 0.003 and want == 0 then h.w = 0 end
			local on = h.side == "L" and h.L or h.R
			local off = h.side == "L" and h.R or h.L
			on.Weight = h.w
			on.Enabled = h.w > 0
			off.Weight = 0
			off.Enabled = false
		end
	end
end

---------------------------------------------------------------- the leaves

-- the opening (0..1) that keeps the push-side knob ARM studs ahead of a player at hinge-space point p,
-- and the leaf clear of their body
local function pushOpen(d, p)
	local k = d.pushKnob
	local amax = math.rad(math.abs(d.swing))
	local function dist(a)
		local q = CFrame.Angles(0, a * d.dir, 0) * k
		local dx, dz = q.X - p.X, q.Z - p.Z
		return math.sqrt(dx * dx + dz * dz)
	end
	local a
	if dist(0) >= ARM then
		a = 0
	elseif dist(amax) < ARM then
		a = amax
	else
		local lo, hi = 0, amax
		for _ = 1, 12 do
			local mid = (lo + hi) / 2
			if dist(mid) < ARM then lo = mid else hi = mid end
		end
		a = hi
	end
	-- keep the leaf out of the body: past the player's own angle round the hinge, plus their width
	local zs = p.Z * d.dir
	local rho = math.sqrt(p.X * p.X + zs * zs)
	local w = math.abs(k.X) + 0.5
	if rho < w + BODY and rho > 0.2 then
		local phi = math.atan2(-zs, math.abs(p.X))
		local need = phi + math.asin(math.min(1, BODY / rho))
		if need > a then a = need end
	end
	return math.clamp(a / amax, 0, 1)
end

-- ease the leaves; an open door is re-placed every frame so it follows the server moving it (build mode)
local parts, cfs = {}, {}
local pushers = {}
RunService.Heartbeat:Connect(function(dt)
	table.clear(parts)
	table.clear(cfs)
	table.clear(pushers)
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(pushers, r.Position) end
	end
	for _, r in ipairs(npcRoots) do
		if r.Parent then table.insert(pushers, r.Position) end
	end
	for _, d in pairs(doors) do
		-- players on the push side drive the door directly
		local want = 0
		if d.pushKnob and not d.locked and d.pivot.Parent then
			local pcf = d.pivot.CFrame
			for _, pos in ipairs(pushers) do
				local p = pcf:PointToObjectSpace(pos)
				local zs = p.Z * d.dir
				local half = math.abs(d.pushKnob.X) * 0.5
				if zs > -0.2 and math.abs(p.Y - 3) < 8 and math.abs(p.X - d.pushKnob.X * 0.5) < half + 2.5 and zs < REACH then
					want = math.max(want, pushOpen(d, p))
				elseif zs <= -0.2 and zs > -6 and math.abs(p.X - d.pushKnob.X * 0.5) < half + 1.5 and math.abs(p.Y - 3) < 8 then
					-- walked through: hold it open behind them until they're clear of the swing
					want = math.max(want, pushOpen(d, p))
				end
			end
		end
		d.push += (want - d.push) * math.min(1, dt * 14)
		if d.push < 0.002 and want == 0 then d.push = 0 end
		if d.t ~= d.goal or d.t > 0 or d.push > 0 or d.e > 0 then
			if d.goal > d.t then d.t = math.min(d.goal, d.t + dt * SPEED) else d.t = math.max(d.goal, d.t - dt * SPEED) end
			local e = math.max(d.t * d.t * (3 - 2 * d.t), d.push)
			d.e = e
			local cf = d.pivot.CFrame * CFrame.Angles(0, math.rad(d.swing * e), 0)
			for i, p in ipairs(d.parts) do
				if p.Parent then
					table.insert(parts, p)
					table.insert(cfs, cf * d.offs[i])
				end
			end
		end
	end
	if #parts > 0 then workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged) end
	updateHands(dt)
end)

---------------------------------------------------------------- knocking

local playEvent
local function sound(name, pos)
	if not playEvent then
		local a = player:WaitForChild("PlayerScripts"):FindFirstChild("Audio")
		playEvent = a and a:FindFirstChild("Play")
	end
	if playEvent then playEvent:Fire(name, pos) end
end

-- round 20: a creak when a leaf starts to swing, a latch when it settles shut. The open/shut
-- thresholds are spaced apart so a door held half-open by a player doesn't chatter.
RunService.Heartbeat:Connect(function()
	for _, d in pairs(doors) do
		local e = d.e or 0
		if d.sfx ~= "open" and e > 0.05 then
			d.sfx = "open"
			if d.pivot.Parent then
				-- round 14: the handle turns first, then the hinge (now and then a soft swish instead of a creak)
				local at = d.pivot.CFrame.Position
				sound("handle", at)
				task.delay(0.08, sound, math.random() < 0.7 and "doorCreak" or "doorSoft", at)
			end
		elseif d.sfx ~= "shut" and e < 0.015 then
			d.sfx = "shut"
			if d.pivot.Parent then sound("doorLatch", d.pivot.CFrame.Position) end
		end
	end
end)

local TAPS = { 0.05, 0.3, 0.55 } -- knuckle hits (seconds after the start), timed to the knock sound

local function knock(who, doorModel, pos)
	sound("knock", pos)
	local char = who and who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local d = doorModel and doors[doorModel]
	local h = root and handsOf(char)
	if not (h and d) then return end
	-- the knuckles land on the leaf a little above the knob, on the knocker's side
	local knob
	for _, k in ipairs(d.knobs) do
		if k.Parent and (not knob or (k.Position - root.Position).Magnitude < (knob.Position - root.Position).Magnitude) then knob = k end
	end
	if not knob then return end
	local look = d.pivot.CFrame.LookVector
	local n = look:Dot(root.Position - knob.Position) > 0 and look or -look
	local centre = d.pivot.CFrame * d.centre
	local across = Vector3.new(centre.X - knob.Position.X, 0, centre.Z - knob.Position.Z)
	across = across.Magnitude > 0.01 and across.Unit or Vector3.zero
	local base = knob.Position + Vector3.new(0, 1.15, 0) + across * 0.55 - n * 0.1
	local att = Instance.new("Attachment")
	att.Name = "KnockAt"
	att.WorldPosition = base + n * 0.4
	att.Parent = workspace.Terrain
	h.knocking = true
	local side = root.CFrame:PointToObjectSpace(base).X < 0 and "L" or "R"
	local ik = h[side]
	local other = side == "L" and h.R or h.L
	other.Enabled, other.Weight = false, 0
	ik.Target = att
	ik.Enabled = true
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 1.05 or not att.Parent or not ik.Parent then
			conn:Disconnect()
			att:Destroy()
			if ik.Parent then
				ik.Weight, ik.Enabled = 0, false
				h.w, h.knob = 0, nil
			end
			h.knocking = false
			return
		end
		-- a quick in-and-out at each tap
		local off = 1
		for _, ti in ipairs(TAPS) do off = math.min(off, math.abs(t - ti) / 0.09) end
		att.WorldPosition = base + n * (0.06 + 0.32 * math.min(off, 1))
		ik.Weight = math.clamp(math.min(t / 0.12, (1.05 - t) / 0.25), 0, 1)
	end)
end

---------------------------------------------------------------- what the guest calls back

local pgui = player:WaitForChild("PlayerGui")
local bubbles = {} -- door model -> billboard

local function reply(d)
	if not d.pos then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - d.pos).Magnitude > 60 then return end
	local old = d.door and bubbles[d.door]
	if old then old:Destroy() end
	local att = Instance.new("Attachment")
	att.WorldPosition = d.pos + Vector3.new(0, 1.2, 0)
	att.Parent = workspace.Terrain
	local accent = d.ok and T.green or ((d.sign or d.mood and d.mood < 40) and T.red or T.gold)
	local bb = UI.new("BillboardGui", {
		Name = "DoorReply", Adornee = att, Size = UDim2.fromOffset(300, 120), StudsOffset = Vector3.new(0, 0.6, 0),
		AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 60, ResetOnSpawn = false, Parent = pgui,
	})
	if d.door then bubbles[d.door] = bb end
	bb.Destroying:Connect(function() att:Destroy() end)
	local root2 = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = root2
	local card = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = T.paper or T.ink, Parent = root2,
	})
	UI.corner(card, 16)
	UI.stroke(card, 3, T.outline or accent, 0)
	UI.pad(card, 16, 10, 16, 12)
	UI.list(card, nil, 2, Enum.HorizontalAlignment.Left)
	local who = UI.new("TextLabel", {
		Text = string.upper((d.name or "Guest") .. (d.ok and "  -  door unlocked" or "  -  behind the door")), TextSize = 13, FontFace = UI.F.heavy,
		TextColor3 = accent, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 1, Parent = card,
	})
	who.TextXAlignment = Enum.TextXAlignment.Left
	local line = UI.new("TextLabel", {
		Text = d.text or "", TextSize = 21, FontFace = UI.F.heavy, TextColor3 = T.outline or T.cream, TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 2, MaxVisibleGraphemes = 0, Parent = card,
	})
	line.TextXAlignment = Enum.TextXAlignment.Left
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(268, 200)
	cap.Parent = line
	-- the tail: a small diamond under the card
	local tail = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(16, 16), Rotation = 45,
		BackgroundColor3 = T.paper or T.ink, ZIndex = 0, Parent = root2,
	})
	UI.stroke(tail, 3, T.outline or accent, 0)
	UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	-- type the words out
	task.spawn(function()
		local n = utf8.len(line.Text) or #line.Text
		for i = 1, n do
			if not line.Parent then return end
			line.MaxVisibleGraphemes = i
			task.wait(0.022)
		end
		line.MaxVisibleGraphemes = -1
	end)
	sound(d.ok and "ready" or (accent == T.red and "error" or "select"), d.pos)
	task.delay(3.8, function()
		if not bb.Parent then return end
		UI.tween(sc, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.22)
		if bubbles[d.door] == bb then bubbles[d.door] = nil end
		bb:Destroy()
	end)
end

Notify.OnClientEvent:Connect(function(kind, d)
	if kind == "knock" and d then
		knock(d.player, d.door, d.pos)
	elseif kind == "doorReply" and d then
		reply(d)
	end
end)
