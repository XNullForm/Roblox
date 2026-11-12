-- ServerStorage.Upkeep (round 11): things that go wrong, and the little jobs round the hotel.
--   Breakdowns  : from hotel level 2, now and then a shower, a toilet or a lobby machine breaks (sparks and smoke,
--                 or a leak and a puddle). Guests can't use it and complain, a broken lobby item costs appeal.
--                 A player fixes it with the Repair minigame (its F prompt), or a Handyman walks over and does.
--   Luggage     : some guests leave their bag at the desk after check-in. Carry it up to their room (knock, or
--                 walk in while they're out) for a tip; after BAG_WAIT it goes up anyway and they grumble.
--   Lost & found: a guest sometimes forgets something on the bed. Pick it up and hand it in at the Lost &
--                 Found box by the desk for a reward; if the room is cleaned first, housekeeping hands it in.
-- HotelSim makes one per hotel: Upkeep.new(ctx), ctx = its evCtx. Player attributes Bag (room id)
-- and Found (item name) mark what a player is carrying (Tray is room service).
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Levels = require(RS.Shared:WaitForChild("Levels"))

local Upkeep = {}
Upkeep.__index = Upkeep

local BREAK_EVERY = { 75, 130 } -- seconds between breakdowns
local BAG_CHANCE = 0.5
local BAG_WAIT = 110
local LOST_CHANCE = 0.16

-- what can break, and how: "spark" (machines) or "water" (leaks)
local BREAKS = {
	VendingMachine = "spark", Arcade = "spark", ClawMachine = "spark", Jukebox = "spark", CoffeeBar = "spark",
	Pinball = "spark", Treadmill = "spark", AirHockey = "spark", PhotoBooth = "spark", KaraokeStage = "spark",
	ATM = "spark", MassageChair = "spark", TVStand = "spark", MiniFridge = "spark", Gramophone = "spark",
	WaterCooler = "water", HotTub = "water", Aquarium = "water",
}
local CORE_BREAKS = { Shower = "water", Toilet = "water" }

local GRUMBLE = {
	Shower = { "The shower's broken!", "No hot water? Seriously?", "The shower is spraying everywhere!" },
	Toilet = { "The toilet won't flush!", "Ugh, the toilet's broken.", "Who do I call about the toilet?" },
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- Studio test attributes take a number, or true for "always" (`on` is what true means)
local function chance(v, default, on)
	if v == true then return on or 1 end
	return tonumber(v) or default
end

function Upkeep.new(ctx)
	local self = setmetatable({ ctx = ctx, broken = {}, bags = {}, lost = {}, rng = ctx.rng }, Upkeep)
	local f = Instance.new("Folder")
	f.Name = "Upkeep"
	f.Parent = ctx.HOTEL
	self.folder = f
	self.started = os.clock()
	task.spawn(function() self:breakLoop() end)
	task.spawn(function() self:watch() end)
	-- round 14: G drops whatever you're carrying (a bag or a lost thing); it waits on the floor to be picked up
	local remotes = RS.Shared:WaitForChild("Remotes")
	local drop = remotes:FindFirstChild("Drop")
	if not drop then
		drop = Instance.new("RemoteEvent")
		drop.Name = "Drop"
		drop.Parent = remotes
	end
	self.dropConn = drop.OnServerEvent:Connect(function(player) pcall(function() self:drop(player) end) end)
	return self
end

-- put down what the player carries, a step in front of them
function Upkeep:drop(player)
	local ctx = self.ctx
	local ch = player.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
	local spot = root.Position + fwd * 2.4
	local y = self:floorAt(spot)
	local cf = CFrame.lookAt(Vector3.new(spot.X, y, spot.Z), Vector3.new(spot.X, y, spot.Z) - fwd)
	for room, rec in pairs(self.bags) do
		if rec.carrier == player then
			-- set down in its own room counts as delivered
			if flat(root.Position - room.nav.Enter.Position).Magnitude < 7 then self:deliverBag(rec, player) return true end
			rec.carrier = nil
			player:SetAttribute("Bag", nil)
			rec.bag.model:PivotTo(cf)
			anchorAll(rec.bag.model)
			rec.bag.model.Parent = self.folder
			rec.prompt.Enabled = true
			-- left lying about: it still goes up on its own, a little later
			rec.t0 = math.max(rec.t0, os.clock() - BAG_WAIT + 45)
			ctx.sfx("pickup", spot)
			return true
		end
	end
	local rec = self.carried and self.carried[player]
	if rec then
		self.carried[player] = nil
		player:SetAttribute("Found", nil)
		rec.carrier = nil
		rec.model:PivotTo(cf * CFrame.new(0, 0, 0))
		anchorAll(rec.model)
		rec.model.Parent = self.folder
		rec.dropped = os.clock()
		rec.prompt = prompt(rec.base, "Pick Up", rec.owner .. "'s " .. rec.def.name, "teddy", "gold")
		rec.prompt.HoldDuration = 0.2
		rec.prompt.Triggered:Connect(function(p) self:takeLost(rec, p) end)
		self.lost[self.lost[rec.room] and rec or rec.room] = rec
		ctx.sfx("pickup", spot)
		return true
	end
	return false
end

-- the floor under a point (ignores guests, staff and our own props)
function Upkeep:floorAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = { self.folder, self.ctx.GUESTS }
	for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(skip, p.Character) end end
	params.FilterDescendantsInstances = skip
	params.RespectCanCollide = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	return hit and hit.Position.Y or pos.Y - 3
end

function Upkeep:carrying(player)
	return player:GetAttribute("Tray") or player:GetAttribute("Bag") or player:GetAttribute("Found")
end

local function prompt(parent, action, object, icon, color)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = action
	pr.ObjectText = object or ""
	pr.KeyboardKeyCode = Enum.KeyCode.F
	pr.GamepadKeyCode = Enum.KeyCode.ButtonY
	pr.HoldDuration = 0.3
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Custom
	pr:SetAttribute("Icon", icon)
	pr:SetAttribute("Color", color or "gold")
	pr.Parent = parent
	return pr
end

-- weld a prop model into a player's right hand (pivot at the model's base); a suitcase is pulled on its wheels
local function carry(player, m, base, height, name, pull)
	local ch = player.Character
	local hand = ch and (ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm"))
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not (hand and root and hum) then return false end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		end
	end
	local to = hand
	if pull then
		to = root
		m:PivotTo(root.CFrame * CFrame.new(1.35, -(hum.HipHeight + root.Size.Y / 2), 1.1) * CFrame.Angles(math.rad(-22), 0, math.rad(-8)))
	else
		m:PivotTo(hand.CFrame * CFrame.new(0, -0.25 - height, 0) * CFrame.Angles(0, math.rad(90), 0))
	end
	local w = Instance.new("Weld")
	w.Name = "CarryWeld"
	w.Part0 = to
	w.Part1 = base
	w.C0 = to.CFrame:ToObjectSpace(base.CFrame)
	w.Parent = base
	m.Name = name
	m.Parent = ch
	return true
end

local function anchorAll(m)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
		if p:IsA("Weld") and p.Name == "CarryWeld" then p:Destroy() end
	end
end

---------------------------------------------------------------- breakdowns

function Upkeep:roomOf(m)
	local id = m:GetAttribute("Room")
	if not id then return nil end
	for _, r in pairs(self.ctx.rooms) do
		if r.model and r.model.Name == id then return r end
	end
end

function Upkeep:maxBroken()
	local lv = Levels.of(self.ctx.HOTEL)
	return 1 + (lv >= 7 and 1 or 0) + (lv >= 13 and 1 or 0)
end

function Upkeep:candidates()
	local out = {}
	for _, m in ipairs(self.ctx.PLACED:GetChildren()) do
		if not m:GetAttribute("Broken") then
			local core = m:GetAttribute("Core")
			if core and CORE_BREAKS[core] then
				local room = self:roomOf(m)
				if room and room.state ~= "Unfurnished" then table.insert(out, m) end
			elseif not core and BREAKS[m:GetAttribute("Item") or ""] and m:GetAttribute("Zone") == "Lobby" then
				table.insert(out, m)
			end
		end
	end
	return out
end

function Upkeep:countLobby()
	local n = 0
	for m, rec in pairs(self.broken) do
		if not rec.room and m.Parent then n += 1 end
	end
	self.ctx.HOTEL:SetAttribute("BrokenLobby", n > 0 and n or nil)
	if self.ctx.scanAppeal then self.ctx.scanAppeal() end
end

function Upkeep:breakLoop()
	local ctx = self.ctx
	local H = ctx.HOTEL
	while ctx.running() do
		local t0, wait_ = os.clock(), self.rng:NextNumber(BREAK_EVERY[1], BREAK_EVERY[2]) / (chance(H:GetAttribute("TestBreaks"), 1, 1000)) * (self.ctx.rmul and self.ctx.rmul("breakEvery") or 1)
		while ctx.running() and os.clock() - t0 < wait_ and not H:GetAttribute("TestBreakNow") do task.wait(1) end
		if not ctx.running() then break end
		-- Studio tests: hotel attribute TestBreakNow = true (anything) or an Item / Core name breaks one now
		local forced = H:GetAttribute("TestBreakNow")
		H:SetAttribute("TestBreakNow", nil)
		local n = 0
		for _ in pairs(self.broken) do n += 1 end
		if forced or (Levels.of(H) >= 2 and n < self:maxBroken() and os.clock() - self.started > 60) then
			local list = self:candidates()
			if type(forced) == "string" then
				local only = {}
				for _, m in ipairs(list) do
					if m:GetAttribute("Item") == forced or m:GetAttribute("Core") == forced then table.insert(only, m) end
				end
				list = only
			end
			if #list > 0 then self:breakItem(list[self.rng:NextInteger(1, #list)]) end
		end
	end
	for _, rec in pairs(self.broken) do if rec.fx then rec.fx:Destroy() end end
	for _, b in pairs(self.bags) do
		if b.carrier then b.carrier:SetAttribute("Bag", nil) end
		if b.bag and b.bag.model then b.bag.model:Destroy() end
	end
	for _, l in pairs(self.lost) do
		if l.carrier then l.carrier:SetAttribute("Found", nil) end
		l.model:Destroy()
	end
	self.folder:Destroy()
end

-- the fx folder: a spark/smoke or spray emitter, a puddle, a warning sign and the Repair prompt
function Upkeep:dressBroken(rec)
	local m = rec.model
	local cf, size = m:GetBoundingBox()
	local fx = Instance.new("Model")
	fx.Name = "Broken_" .. rec.name
	local floorY = self:floorAt(cf.Position)
	local top = Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2, cf.Position.Z)
	local anchor = part({ Name = "Spot", Size = Vector3.new(1, 1, 1), Transparency = 1, Position = cf.Position })
	anchor.Parent = fx
	local emitAt = rec.kind == "water" and Vector3.new(cf.Position.X, floorY + math.min(size.Y * 0.7, 5), cf.Position.Z) or top
	local src = part({ Name = "Source", Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1, Position = emitAt })
	src.Parent = fx
	if rec.kind == "spark" then
		local sp = Instance.new("ParticleEmitter")
		sp.Name = "Sparks"
		sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sp.Color = ColorSequence.new(Color3.fromRGB(255, 236, 150), Color3.fromRGB(255, 150, 60))
		sp.LightEmission = 1
		sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sp.Lifetime = NumberRange.new(0.25, 0.6)
		sp.Speed = NumberRange.new(6, 12)
		sp.SpreadAngle = Vector2.new(70, 70)
		sp.Acceleration = Vector3.new(0, -30, 0)
		sp.Rate = 0
		sp.Parent = src
		local sm = Instance.new("ParticleEmitter")
		sm.Name = "Smoke"
		sm.Texture = "rbxasset://textures/particles/smoke_main.dds"
		sm.Color = ColorSequence.new(Color3.fromRGB(70, 72, 80))
		sm.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.2) })
		sm.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		sm.Lifetime = NumberRange.new(1.6, 2.6)
		sm.Speed = NumberRange.new(1.2, 2.2)
		sm.SpreadAngle = Vector2.new(18, 18)
		sm.RotSpeed = NumberRange.new(-40, 40)
		sm.Rate = 6
		sm.Parent = src
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(170, 200, 255)
		light.Range = 9
		light.Brightness = 0
		light.Parent = src
		rec.sparks, rec.light = sp, light
	else
		-- where the water goes: out of a room's shower/toilet toward its front spot, or toward the desk in the lobby
		local toward
		if rec.room and rec.core then
			toward = self.ctx.coreSpot(rec.room, rec.core, "front")
		else
			toward = self.ctx.NAV.DeskGuest.Position
		end
		local away = flat(toward - cf.Position)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
		local h = rec.core == "Shower" and size.Y * 0.8 or math.min(size.Y * 0.6, 3)
		emitAt = Vector3.new(cf.Position.X, floorY + h, cf.Position.Z) + away * 0.3
		src.CFrame = CFrame.lookAt(emitAt, emitAt + away + Vector3.new(0, rec.core == "Shower" and -0.1 or 0.9, 0))
		local spray = Instance.new("ParticleEmitter")
		spray.Name = "Spray"
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(226, 242, 255), Color3.fromRGB(150, 200, 240))
		spray.LightEmission = 0.25
		spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.7) })
		spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
		spray.Lifetime = NumberRange.new(0.45, 0.75)
		spray.Speed = NumberRange.new(8, 12)
		spray.SpreadAngle = Vector2.new(22, 22)
		spray.Acceleration = Vector3.new(0, -38, 0)
		spray.EmissionDirection = Enum.NormalId.Front
		spray.Rate = 90
		spray.Parent = src
		local mist = Instance.new("ParticleEmitter")
		mist.Name = "Mist"
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
		mist.Lifetime = NumberRange.new(1, 1.6)
		mist.Speed = NumberRange.new(0.5, 1.2)
		mist.Rate = 5
		mist.Parent = src
		-- a puddle that spreads out in front of it
		local puddle = part({
			Name = "Puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.6, 0.6),
			Color = Color3.fromRGB(96, 150, 196), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.35,
		})
		local at = Vector3.new(cf.Position.X, floorY + 0.04, cf.Position.Z):Lerp(Vector3.new(toward.X, floorY + 0.04, toward.Z), rec.room and 0.75 or 0.4)
		puddle.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		puddle.Parent = fx
		local TS = game:GetService("TweenService")
		TS:Create(puddle, TweenInfo.new(10, Enum.EasingStyle.Sine), { Size = Vector3.new(0.05, 5.6, 5.6) }):Play()
		local splash = puddle:Clone()
		splash.Name = "Puddle2"
		splash.CFrame = CFrame.new(at + away * 1.6 + Vector3.new(0.8, 0.005, 0)) * CFrame.Angles(0, 0, math.rad(90))
		splash.Parent = fx
		TS:Create(splash, TweenInfo.new(14, Enum.EasingStyle.Sine), { Size = Vector3.new(0.05, 3.8, 3.8) }):Play()
	end
	-- the warning sign floating above
	local bb = Instance.new("BillboardGui")
	bb.Name = "Warn"
	bb.Size = UDim2.fromScale(2.2, 2.2)
	bb.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1.8, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 90
	bb.Adornee = anchor
	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = C.ICONS.spark or C.ICONS.hammer
	icon.Parent = bb
	bb.Parent = anchor
	rec.prompt = prompt(anchor, "Repair", rec.name, "wrench", "yellow")
	rec.prompt.Triggered:Connect(function(player) self:playerRepair(rec, player) end)
	fx.Parent = self.folder
	rec.fx = fx
	rec.anchor = anchor
	rec.pivot0 = m:GetPivot()
end

function Upkeep:breakItem(m)
	local ctx = self.ctx
	local core = m:GetAttribute("Core")
	local id = m:GetAttribute("Item") or core or "Item"
	local room = core and self:roomOf(m) or nil
	local rec = {
		model = m, room = room, core = core, kind = core and CORE_BREAKS[core] or BREAKS[id] or "spark",
		name = core or (require(RS.Shared.Catalog).ITEMS[id] or {}).name or id, t0 = os.clock(),
	}
	if room then rec.name = (core == "Toilet" and "Toilet" or "Shower") end
	self.broken[m] = rec
	m:SetAttribute("Broken", true)
	self:dressBroken(rec)
	local where = room and (" in room " .. room.id) or " in the lobby"
	ctx.tell("toast", { text = "The " .. rec.name:lower() .. where .. " broke!", icon = "spark", bad = true })
	ctx.sfx(rec.kind == "water" and "leak" or "zap", rec.anchor.Position)
	self:countLobby()
end

function Upkeep:fix(rec, player, stars, byStaff)
	local ctx = self.ctx
	if self.broken[rec.model] ~= rec then return end
	self.broken[rec.model] = nil
	local pos = rec.anchor and rec.anchor.Position or rec.model:GetPivot().Position
	if rec.fx then rec.fx:Destroy() end
	rec.model:SetAttribute("Broken", nil)
	if ctx.sparkle then ctx.sparkle(pos + Vector3.new(0, 1, 0)) end
	ctx.sfx("fixed", pos)
	if player then
		Levels.award(ctx.HOTEL, 8 + 4 * (stars or 1), "Repair", pos + Vector3.new(0, 2, 0))
		ctx.tell("toast", { text = player.DisplayName .. " fixed the " .. rec.name:lower(), icon = "wrench" })
	else
		ctx.tell("toast", { text = (byStaff and byStaff.name or "The handyman") .. " fixed the " .. rec.name:lower(), icon = "wrench" })
	end
	ctx.quest("repair")
	self:countLobby()
end

function Upkeep:playerRepair(rec, player)
	local ctx = self.ctx
	if not ctx.isMember(player) then ctx.notMine(player) return end
	if ctx.deskGames[player] or ctx.cleaning[player] or rec.fixer then return end
	if self.broken[rec.model] ~= rec then return end
	rec.fixer = player
	rec.prompt.Enabled = false
	local session = { t0 = os.clock() }
	session.done = function(ok, stars)
		if rec.fixer == player then rec.fixer = nil end
		if ok then
			self:fix(rec, player, stars)
		elseif self.broken[rec.model] == rec and rec.prompt then
			rec.prompt.Enabled = true
		end
	end
	ctx.deskGames[player] = session
	ctx.Notify:FireClient(player, "minigame", { task = "Repair", title = "Fix the " .. rec.name, room = rec.room and rec.room.id, kind = rec.kind })
	task.delay(C.MINIGAME_TIMEOUT, function()
		if ctx.deskGames[player] == session then
			ctx.deskGames[player] = nil
			session.done(false, 0)
			ctx.Notify:FireClient(player, "minigameEnd")
		end
	end)
end

-- a guest who finds their shower or toilet broken: a look, a sigh and a complaint. True when it was broken.
function Upkeep:brokenCore(g, room, kind)
	local ctx = self.ctx
	local m = ctx.core(room, kind)
	if not (m and m:GetAttribute("Broken")) then return false end
	local front = ctx.coreSpot(room, kind, "front")
	ctx.status(g, "walk", kind == "Toilet" and "Bathroom" or "Shower")
	ctx.walkTo(g, front)
	if not g.alive then return true end
	ctx.faceTo(g, m:GetPivot().Position)
	ctx.status(g, "angry", "Broken " .. kind:lower(), "red")
	ctx.play(g, "point")
	ctx.say(g, GRUMBLE[kind][self.rng:NextInteger(1, #GRUMBLE[kind])], 3)
	ctx.moodShift(g, -10, "The " .. kind:lower() .. " is broken!", "The " .. kind:lower() .. " in my room was broken.")
	task.wait(2.5)
	return true
end

-- the next thing a handyman should fix (nearest; never a room with a guest inside, the door is locked)
function Upkeep:nextJob(from, focus)
	local best, bestD
	for m, rec in pairs(self.broken) do
		if m.Parent and not rec.fixer and not (rec.room and rec.room.occupant) then
			local d = flat(m:GetPivot().Position - from).Magnitude
			-- round 13: a handyman set to rooms first or lobby first goes there before anything else
			if (focus == "rooms" and not rec.room) or (focus == "lobby" and rec.room) then d += 5000 end
			if not bestD or d < bestD then best, bestD = rec, d end
		end
	end
	return best
end

-- the handyman: walks to the nearest broken thing and fixes it; idle jobs otherwise
function Upkeep:handymanLife(s, pace, gain, idleJob)
	local ctx, g = self.ctx, s.g
	while g.alive do
		if ctx.breakTime and ctx.breakTime(s) then continue end -- round 14: breaks and leaving
		local off = ctx.offShift and ctx.offShift(s) -- round 13: shifts
		local rec = not off and self:nextJob(g.root.Position, ctx.job and ctx.job(s).focus)
		if rec then
			rec.fixer = g
			if rec.prompt then rec.prompt.Enabled = false end
			ctx.status(g, "walk", rec.name)
			local room = rec.room
			if room then
				ctx.walkTo(g, room.nav.Door.Position)
				ctx.walkTo(g, room.nav.Enter.Position)
			end
			local spot
			if room then
				spot = ctx.coreSpot(room, rec.core, "front")
			else
				local piv = rec.model:GetPivot().Position
				local dir = flat(piv - g.root.Position)
				if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
				local _, size = rec.model:GetBoundingBox()
				spot = Vector3.new(piv.X, g.root.Position.Y, piv.Z) - dir.Unit * (math.max(size.X, size.Z) / 2 + 2)
			end
			ctx.walkTo(g, spot)
			if g.alive and self.broken[rec.model] == rec then
				ctx.faceTo(g, rec.model:GetPivot().Position)
				ctx.status(g, "wrench", "Repairing", "yellow")
				ctx.say(g, ({ "Let's have a look...", "Seen worse.", "Easy fix.", "Hand me that wrench... oh, I've got it." })[self.rng:NextInteger(1, 4)], 2.5)
				local secs = 14 * pace(s) -- round 13: was 7
				local t0 = os.clock()
				ctx.barTimer(g, secs)
				while g.alive and os.clock() - t0 < secs and self.broken[rec.model] == rec do
					if os.clock() - t0 < 0.1 then ctx.play(g, "@fix") end -- round 14: crouched, knocking with the wrench
					task.wait()
				end
				ctx.stop(g, "@fix")
				if g.alive and self.broken[rec.model] == rec then
					self:fix(rec, nil, 2, g)
					gain(s, 3)
					ctx.play(g, "dust_hands")
					ctx.say(g, ({ "Good as new!", "Fixed!", "That should hold.", "Done and dusted." })[self.rng:NextInteger(1, 4)], 2)
				end
			end
			if rec.fixer == g then
				rec.fixer = nil
				if rec.prompt and self.broken[rec.model] == rec then rec.prompt.Enabled = true end
			end
			if room and g.alive then
				ctx.walkTo(g, room.nav.Enter.Position)
				ctx.walkTo(g, room.nav.Door.Position)
			end
		else
			ctx.status(g, "wrench", off and "Off shift" or "Checking the machines")
			idleJob(s)
		end
	end
end

---------------------------------------------------------------- luggage

-- the spot beside the front desk where bags wait (in a row) and the Lost & Found box
function Upkeep:deskFrame()
	local NAV = self.ctx.NAV
	local a, b = NAV.DeskGuest.Position, NAV.Receptionist.Position
	local fwd = flat(b - a)
	fwd = fwd.Magnitude > 0.1 and fwd.Unit or Vector3.new(0, 0, -1)
	local side = Vector3.new(-fwd.Z, 0, fwd.X)
	return a, fwd, side
end

function Upkeep:checkedIn(g, room)
	local ctx = self.ctx
	local H = ctx.HOTEL
	if not g.bag or g.event or g.tourist or Levels.of(H) < 2 then return end
	if self.rng:NextNumber() > chance(H:GetAttribute("TestBags"), BAG_CHANCE) then return end
	local b = g.bag
	g.bag = nil
	g.model:SetAttribute("Carry", nil)
	if b.weld then b.weld:Destroy(); b.weld = nil end
	-- in a row on the guest's left of the desk
	local n = 0
	for _ in pairs(self.bags) do n += 1 end
	local a, fwd, side = self:deskFrame()
	local pos = a + side * (5 + (n % 4) * 1.7) - fwd * 0.4
	local y = self:floorAt(pos)
	b.model:PivotTo(CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) - fwd))
	anchorAll(b.model)
	b.model.Parent = self.folder
	local rec = { g = g, room = room, bag = b, t0 = os.clock() }
	rec.prompt = prompt(b.base, "Carry Bag", "Room " .. room.id, "suitcase", "gold")
	rec.prompt.Triggered:Connect(function(player) self:takeBag(rec, player) end)
	self.bags[room] = rec
	ctx.say(g, ({ "Could someone bring my bag up?", "I'll leave my bag here, thanks!", "My bag's so heavy..." })[self.rng:NextInteger(1, 3)], 3)
	ctx.tell("toast", { text = g.name .. "'s bag needs taking up to room " .. room.id, icon = "suitcase" })
end

function Upkeep:takeBag(rec, player)
	local ctx = self.ctx
	if not ctx.isMember(player) then ctx.notMine(player) return end
	if rec.carrier or self.bags[rec.room] ~= rec then return end
	if self:carrying(player) then
		ctx.Notify:FireClient(player, "toast", { text = "Your hands are full", icon = "suitcase", bad = true })
		return
	end
	if not carry(player, rec.bag.model, rec.bag.base, rec.bag.height, "Bag", rec.bag.kind == "Suitcase") then return end
	rec.carrier = player
	rec.prompt.Enabled = false
	player:SetAttribute("Bag", rec.room.id)
	ctx.sfx("pickup", rec.bag.base.Position)
	ctx.Notify:FireClient(player, "toast", { text = "Take it up to room " .. rec.room.id, icon = "suitcase" })
end

-- the bag reaches the room: set down by the bed. Tip when a player brought it, a grumble when it was late
function Upkeep:deliverBag(rec, player)
	local ctx = self.ctx
	local g, room = rec.g, rec.room
	self.bags[room] = nil
	if rec.carrier then rec.carrier:SetAttribute("Bag", nil) end
	if rec.prompt then rec.prompt:Destroy() end
	local b = rec.bag
	-- a bag that went with a reset character is gone
	if not g.alive or not pcall(function() b.model.Parent = self.folder end) then
		pcall(function() b.model:Destroy() end)
		if g.alive and not player then ctx.moodShift(g, -10, "They lost my bag!", "The hotel lost my bag.") end
		return
	end
	anchorAll(b.model)
	g.bag = b
	ctx.dropBag(g, room)
	if b.model.Parent ~= ctx.GUESTS then b.model.Parent = ctx.GUESTS end
	if player then
		local fast = os.clock() - rec.t0 < 45
		local tip = math.floor((fast and 18 or 10) + self.rng:NextInteger(0, 8) + Levels.of(ctx.HOTEL) * 0.6)
		ctx.addCash(player, tip)
		ctx.Notify:FireAllClients("paid", { pos = room.nav.Enter.Position + Vector3.new(0, 2, 0), amount = tip })
		Levels.award(ctx.HOTEL, 6, "Bag delivered", room.nav.Enter.Position + Vector3.new(0, 3, 0))
		ctx.moodShift(g, fast and 8 or 4, "They brought my bag up!", "Staff carried my bag to the room.")
		ctx.tell("toast", { text = "Bag delivered to room " .. room.id .. ". Tip: $" .. tip, icon = "suitcase" })
		ctx.quest("bag")
	else
		ctx.moodShift(g, -6, "My bag took ages to come up.", "My bag took ages to reach the room.")
	end
end

-- knocking on a room while carrying its bag (HotelSim's knockOn asks first): true when handled
function Upkeep:onKnock(room, player)
	local rec = self.bags[room]
	if not rec or rec.carrier ~= player or player:GetAttribute("Bag") ~= room.id then return false end
	self:deliverBag(rec, player)
	return true
end

-- at check-out: a bag still waiting goes back to its guest
function Upkeep:checkout(g)
	for room, rec in pairs(self.bags) do
		if rec.g == g then
			self.bags[room] = nil
			if rec.carrier then rec.carrier:SetAttribute("Bag", nil) end
			if rec.prompt then rec.prompt:Destroy() end
			anchorAll(rec.bag.model)
			g.bag = rec.bag
			self.ctx.holdBag(g)
		end
	end
end

---------------------------------------------------------------- lost & found

local LOST = {
	{ id = "teddy", name = "teddy bear" }, { id = "phone", name = "phone" }, { id = "wallet", name = "wallet" },
	{ id = "book", name = "book" }, { id = "glasses", name = "sunglasses" }, { id = "watch", name = "watch" },
}

local function lostModel(id)
	local m = Instance.new("Model")
	local function bit(name, size, cf, color, mat, shape)
		local p = part({ Name = name, Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic })
		if shape then p.Shape = shape end
		p.Parent = m
		return p
	end
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
	local up = CFrame.Angles(0, 0, math.rad(90))
	local base
	if id == "teddy" then
		local fur, Fabric = Color3.fromRGB(196, 136, 82), Enum.Material.Fabric
		base = bit("Body", Vector3.new(0.9, 1.0, 0.8), CFrame.new(0, 0.5, 0), fur, Fabric, BALL)
		bit("Head", Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 1.2, 0), fur, Fabric, BALL)
		for i = -1, 1, 2 do
			bit("Ear", Vector3.new(0.28, 0.28, 0.18), CFrame.new(0.3 * i, 1.55, 0), fur:Lerp(Color3.new(0, 0, 0), 0.15), Fabric, BALL)
			bit("Arm", Vector3.new(0.3, 0.55, 0.3), CFrame.new(0.48 * i, 0.6, -0.08) * CFrame.Angles(0, 0, 0.5 * i), fur, Fabric, BALL)
			bit("Leg", Vector3.new(0.34, 0.34, 0.5), CFrame.new(0.26 * i, 0.15, -0.25), fur, Fabric, BALL)
			bit("Eye", Vector3.new(0.09, 0.09, 0.09), CFrame.new(0.14 * i, 1.28, -0.34), Color3.fromRGB(30, 22, 18), nil, BALL)
		end
		bit("Snout", Vector3.new(0.34, 0.26, 0.24), CFrame.new(0, 1.1, -0.32), Color3.fromRGB(240, 210, 170), Fabric, BALL)
		bit("Bow", Vector3.new(0.5, 0.16, 0.12), CFrame.new(0, 0.88, -0.36), Color3.fromRGB(230, 70, 110))
	elseif id == "phone" then
		base = bit("Phone", Vector3.new(0.5, 0.06, 0.95), CFrame.new(0, 0.03, 0), Color3.fromRGB(30, 32, 40), Enum.Material.Glass)
		bit("Screen", Vector3.new(0.44, 0.02, 0.86), CFrame.new(0, 0.07, 0), Color3.fromRGB(90, 150, 255), Enum.Material.Neon)
	elseif id == "wallet" then
		base = bit("Wallet", Vector3.new(0.85, 0.14, 0.62), CFrame.new(0, 0.07, 0), Color3.fromRGB(110, 62, 36), Enum.Material.Leather)
		bit("Strap", Vector3.new(0.86, 0.02, 0.14), CFrame.new(0, 0.15, 0.1), Color3.fromRGB(80, 44, 26), Enum.Material.Leather)
		bit("Clasp", Vector3.new(0.12, 0.03, 0.12), CFrame.new(0.3, 0.16, 0.1), Color3.fromRGB(230, 190, 90), Enum.Material.Metal)
	elseif id == "book" then
		local cover = ({ Color3.fromRGB(170, 50, 60), Color3.fromRGB(50, 90, 160), Color3.fromRGB(60, 130, 90) })[math.random(1, 3)]
		base = bit("Cover", Vector3.new(0.8, 0.22, 1.05), CFrame.new(0, 0.11, 0), cover, Enum.Material.Fabric)
		bit("Pages", Vector3.new(0.74, 0.18, 1.0), CFrame.new(0.04, 0.11, 0), Color3.fromRGB(248, 242, 226))
		bit("Ribbon", Vector3.new(0.06, 0.02, 0.3), CFrame.new(-0.1, 0.23, 0.6), Color3.fromRGB(230, 190, 90))
	elseif id == "glasses" then
		base = bit("Bridge", Vector3.new(0.2, 0.05, 0.05), CFrame.new(0, 0.18, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		for i = -1, 1, 2 do
			bit("Lens", Vector3.new(0.04, 0.36, 0.36), CFrame.new(0.27 * i, 0.18, 0) * CFrame.Angles(0, math.rad(90), 0) * up, Color3.fromRGB(40, 50, 70), Enum.Material.Glass, CYL)
			bit("Arm", Vector3.new(0.04, 0.04, 0.8), CFrame.new(0.45 * i, 0.18, 0.4), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		end
	else -- watch
		base = bit("Face", Vector3.new(0.1, 0.42, 0.42), CFrame.new(0, 0.06, 0) * up, Color3.fromRGB(230, 190, 90), Enum.Material.Metal, CYL)
		bit("Glass", Vector3.new(0.02, 0.34, 0.34), CFrame.new(0, 0.12, 0) * up, Color3.fromRGB(240, 244, 250), Enum.Material.Glass, CYL)
		for i = -1, 1, 2 do bit("Strap", Vector3.new(0.26, 0.04, 0.5), CFrame.new(0, 0.03, 0.42 * i), Color3.fromRGB(90, 52, 30), Enum.Material.Leather) end
	end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= base then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = base, p
			w.Parent = p
		end
	end
	m.PrimaryPart = base
	m.WorldPivot = CFrame.new()
	local _, size = m:GetBoundingBox()
	return m, base, size.Y
end

function Upkeep:leftBehind(g, room)
	local ctx = self.ctx
	if self.rng:NextNumber() > chance(ctx.HOTEL:GetAttribute("TestLost"), LOST_CHANCE) or self.lost[room] then return end
	local bed = ctx.core(room, "Bed")
	if not bed then return end
	local def = LOST[self.rng:NextInteger(1, #LOST)]
	local m, base, h = lostModel(def.id)
	-- on the mattress: cast down onto the bed only
	local cf, size = bed:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { bed }
	local at = cf.Position + flat(cf.RightVector) * self.rng:NextNumber(-0.25, 0.25) * size.X + flat(cf.LookVector) * self.rng:NextNumber(-0.2, 0.15) * size.Z
	local hit = workspace:Raycast(Vector3.new(at.X, cf.Position.Y + size.Y, at.Z), Vector3.new(0, -size.Y * 2, 0), params)
	local y = hit and hit.Position.Y or cf.Position.Y
	local yaw = CFrame.Angles(0, self.rng:NextNumber(0, math.pi * 2), 0)
	local door = room.nav and room.nav.Enter and flat(room.nav.Enter.Position - at)
	if def.id == "teddy" and door and door.Magnitude > 0.5 then -- the teddy sits up facing the door
		yaw = CFrame.lookAt(Vector3.zero, door.Unit).Rotation * CFrame.Angles(0, self.rng:NextNumber(-0.35, 0.35), 0)
	end
	m:PivotTo(CFrame.new(at.X, y + 0.02, at.Z) * yaw)
	m.Name = "Lost_" .. def.id
	local glint = Instance.new("ParticleEmitter")
	glint.Name = "Glint"
	glint.Texture = C.ICONS.sparkle
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 0) })
	glint.Lifetime = NumberRange.new(0.8, 1.2)
	glint.Speed = NumberRange.new(0.3, 0.8)
	glint.SpreadAngle = Vector2.new(180, 180)
	glint.LightEmission = 0.6
	glint.Rate = 3
	glint.Parent = base
	m.Parent = self.folder
	local rec = { g = g, room = room, model = m, base = base, height = h, def = def, owner = g.name }
	rec.prompt = prompt(base, "Pick Up", g.name .. "'s " .. def.name, "teddy", "gold")
	rec.prompt.HoldDuration = 0.2
	rec.prompt.Triggered:Connect(function(player) self:takeLost(rec, player) end)
	self.lost[room] = rec
end

function Upkeep:takeLost(rec, player)
	local ctx = self.ctx
	if not ctx.isMember(player) then ctx.notMine(player) return end
	if rec.carrier or (self.lost[rec.room] ~= rec and self.lost[rec] ~= rec) then return end
	if self:carrying(player) then
		ctx.Notify:FireClient(player, "toast", { text = "Your hands are full", icon = "teddy", bad = true })
		return
	end
	local glint = rec.base:FindFirstChild("Glint")
	if glint then glint:Destroy() end
	if not carry(player, rec.model, rec.base, rec.height, "Found") then return end
	-- held in front, not dangling
	local w = rec.base:FindFirstChild("CarryWeld")
	if w then w.C0 = CFrame.new(0, -0.6, -0.7) end
	rec.carrier = player
	rec.prompt:Destroy()
	if self.lost[rec.room] == rec then self.lost[rec.room] = nil end
	self.lost[rec] = nil
	rec.dropped = nil
	self.carried = self.carried or {}
	self.carried[player] = rec
	player:SetAttribute("Found", rec.def.name)
	ctx.sfx("pickup", rec.base.Position)
	ctx.Notify:FireClient(player, "toast", { text = "Hand " .. rec.owner .. "'s " .. rec.def.name .. " in at the Lost & Found by the desk", icon = "teddy" })
end

function Upkeep:turnIn(player)
	local ctx = self.ctx
	local rec = self.carried and self.carried[player]
	if not rec then return end
	self.carried[player] = nil
	player:SetAttribute("Found", nil)
	rec.model:Destroy()
	local reward = self.rng:NextInteger(35, 60) + Levels.of(ctx.HOTEL) * 2
	ctx.addCash(player, reward)
	local pos = self.box and self.box.Position or player.Character and player.Character:GetPivot().Position
	ctx.Notify:FireAllClients("paid", { pos = pos + Vector3.new(0, 2, 0), amount = reward })
	Levels.award(ctx.HOTEL, 12, "Lost & found", pos + Vector3.new(0, 3, 0))
	ctx.tell("toast", { text = rec.owner .. " got their " .. rec.def.name .. " back. Reward: $" .. reward, icon = "teddy" })
	ctx.quest("lost")
end

-- the Lost & Found box beside the desk (made on first use), its prompt shows while anyone carries something
function Upkeep:lostBox()
	if self.box and self.box.Parent then return self.box end
	local a, fwd, side = self:deskFrame()
	local pos = a - side * 5.2 - fwd * 0.2
	local y = self:floorAt(pos)
	local box = part({
		Name = "LostFound", Size = Vector3.new(2.2, 1.5, 1.6), Color = Color3.fromRGB(196, 150, 96), Material = Enum.Material.Cardboard,
		CanCollide = true, CanQuery = true, CastShadow = true,
	})
	box.CFrame = CFrame.lookAt(Vector3.new(pos.X, y + 0.75, pos.Z), Vector3.new(pos.X, y + 0.75, pos.Z) - fwd)
	box.Parent = self.folder
	for i = -1, 1, 2 do
		local flap = part({ Name = "Flap", Size = Vector3.new(2.2, 0.06, 0.9), Color = Color3.fromRGB(176, 132, 82), Material = Enum.Material.Cardboard })
		flap.CFrame = box.CFrame * CFrame.new(0, 0.82, 0.62 * i) * CFrame.Angles(math.rad(-38 * i), 0, 0)
		flap.Parent = box
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0.6
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "LOST &\nFOUND"
	l.TextScaled = true
	l.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Black)
	l.TextColor3 = Color3.fromRGB(70, 44, 24)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.Parent = l
	l.Parent = sg
	sg.Parent = box
	local pr = prompt(box, "Hand In", "Lost & Found", "teddy", "green")
	pr.Enabled = false
	pr.Triggered:Connect(function(player) self:turnIn(player) end)
	self.box, self.boxPrompt = box, pr
	return box
end

---------------------------------------------------------------- the watcher

function Upkeep:watch()
	local ctx = self.ctx
	while ctx.running() do
		local now = os.clock()
		-- fx follow items moved in build mode; sold items take their fx with them
		for m, rec in pairs(self.broken) do
			if not m.Parent then
				self.broken[m] = nil
				if rec.fx then rec.fx:Destroy() end
				self:countLobby()
			else
				local piv = m:GetPivot()
				if rec.pivot0 and (piv.Position - rec.pivot0.Position).Magnitude > 0.2 then
					rec.fx:PivotTo(piv * rec.pivot0:ToObjectSpace(rec.fx:GetPivot()))
					rec.pivot0 = piv
				end
				if rec.sparks and self.rng:NextNumber() < 0.35 then
					rec.sparks:Emit(self.rng:NextInteger(6, 14))
					rec.light.Brightness = 3
					task.delay(0.08, function() if rec.light then rec.light.Brightness = 0 end end)
					if self.rng:NextNumber() < 0.3 then ctx.sfx("zap", rec.anchor.Position) end
				end
			end
		end
		-- bags: walked into the room while the guest is out, or waited too long, or the guest left
		for room, rec in pairs(self.bags) do
			if not rec.g.alive then
				self.bags[room] = nil
				if rec.carrier then rec.carrier:SetAttribute("Bag", nil) end
				rec.bag.model:Destroy()
			elseif rec.carrier and (not rec.carrier.Parent or rec.carrier:GetAttribute("Bag") ~= room.id or not rec.bag.model:IsDescendantOf(workspace)) then
				-- the carrier left, reset, or dropped it: the bag goes up on its own (late)
				if rec.carrier.Parent then rec.carrier:SetAttribute("Bag", nil) end
				rec.carrier = nil
				self.bags[room] = nil
				self:deliverBag(rec, nil)
			elseif rec.carrier and not room.occupant then
				local ch = rec.carrier.Character
				local root = ch and ch:FindFirstChild("HumanoidRootPart")
				if root and flat(root.Position - room.nav.Enter.Position).Magnitude < 5 then self:deliverBag(rec, rec.carrier) end
			elseif now - rec.t0 > BAG_WAIT and not rec.carrier then
				self:deliverBag(rec, nil)
			end
		end
		-- lost things: the room got cleaned first, so housekeeping hands it in
		for key, rec in pairs(self.lost) do
			local room = rec.room
			-- the room got cleaned first (or it was dropped and left on the floor a while)
			if not rec.carrier and ((not rec.dropped and room.state ~= "Dirty") or (rec.dropped and now - rec.dropped > 90)) then
				self.lost[key] = nil
				rec.model:Destroy()
				ctx.earn(15, room.nav.Enter.Position + Vector3.new(0, 2, 0))
				ctx.tell("toast", { text = "Housekeeping handed in " .. rec.owner .. "'s " .. rec.def.name .. " (+$15)", icon = "teddy" })
			end
		end
		local anyCarried = false
		if self.carried then
			for player, rec in pairs(self.carried) do
				if not player.Parent or not rec.model:IsDescendantOf(workspace) then
					self.carried[player] = nil
					rec.model:Destroy()
					if player.Parent then player:SetAttribute("Found", nil) end
				else
					anyCarried = true
				end
			end
		end
		if anyCarried then self:lostBox() end
		if self.boxPrompt then self.boxPrompt.Enabled = anyCarried end
		task.wait(0.35)
	end
end

return Upkeep
