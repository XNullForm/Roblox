-- ServerStorage.HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades.
-- Plots calls Sim.start(hotel) for every claimed plot (hotel attribute Origin = the plot's offset) and
-- handle.stop() when the plot is freed. The server owns every number; clients only draw.
-- Members of a hotel = players whose attribute Plot is the hotel's name (its owner and co-op partners):
-- only they get its toasts, and only they can use its prompts.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Catalog = require(RS.Shared:WaitForChild("Catalog"))
local Build = require(RS.Shared:WaitForChild("Build"))
local Research = require(RS.Shared:WaitForChild("Research"))
local StaffLook = require(RS.Shared:WaitForChild("StaffLook")) -- round 13: staff outfits and the wardrobe
local GuestEvents = require(game.ServerStorage:WaitForChild("GuestEvents"))
local Nav = require(game.ServerStorage:WaitForChild("Nav"))
local Life = require(game.ServerStorage:WaitForChild("GuestLife"))
local Conv = require(game.ServerStorage:WaitForChild("Conversations")) -- round 15: topics, questions, feelings
local Kitchen = require(game.ServerStorage:WaitForChild("Kitchen"))
local Looks = require(RS.Shared:WaitForChild("Looks"))
local Levels = require(RS.Shared:WaitForChild("Levels"))
local Rooms = require(game.ServerStorage:WaitForChild("Rooms"))
local Clock = require(RS.Shared:WaitForChild("Clock"))
local Notify = RS.Shared.Remotes.Notify
-- a sound at a spot in the world, played by Audio on every client
local function sfx(name, pos) Notify:FireAllClients("sfx", { name = name, pos = pos }) end
local QuestSig = game.ServerStorage:WaitForChild("Signals"):FindFirstChild("Quest")
if not QuestSig then
	QuestSig = Instance.new("BindableEvent")
	QuestSig.Name = "Quest"
	QuestSig.Parent = game.ServerStorage.Signals
end

local Sim = {}
Sim.registry = {} -- hotel -> handle { wantsWalkIn(), adopt(model, name) } (used by Crowds)
Sim.handOff = nil -- set by Crowds: function(model, name) takes a leaving guest back onto the street

function Sim.start(HOTEL)
local O = HOTEL:GetAttribute("Origin") or Vector3.zero
local running = true
local function quest(stat, n) QuestSig:Fire(HOTEL, stat, n or 1) end -- chapter goals (QuestServer)
local conns = {} -- connections to shared signals, cut on stop
local GUESTS = HOTEL:FindFirstChild("Guests") or Instance.new("Folder")
GUESTS.Name = "Guests"
GUESTS.Parent = HOTEL

local function members()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == HOTEL.Name then table.insert(list, p) end
	end
	return list
end
local function isMember(player) return player:GetAttribute("Plot") == HOTEL.Name end
-- a Notify message for this hotel's members only
local function tell(kind, data)
	for _, p in ipairs(members()) do Notify:FireClient(p, kind, data) end
end
local function notMine(player)
	Notify:FireClient(player, "toast", { text = "This isn't your hotel. Ask the owner for a co-op invite!", icon = "door", bad = true })
end

local NAV = HOTEL:WaitForChild("Nav")
local PLACED = HOTEL:WaitForChild("Placed")
local PROPS = game.ServerStorage:WaitForChild("HotelProps")
local ItemsChanged = game.ServerStorage:WaitForChild("Signals"):WaitForChild("ItemsChanged")

local rng = Random.new()
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function range(t) return rng:NextNumber(t[1], t[2]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

---------------------------------------------------------------- collision groups

pcall(function() PhysicsService:RegisterCollisionGroup("Guests") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
-- round 18: people are solid: players, guests and staff bump into each other (the walkers steer round)
PhysicsService:CollisionGroupSetCollidable("Guests", "Guests", true)
PhysicsService:CollisionGroupSetCollidable("Guests", "Players", true)

local function setGroup(model, group)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end)
end

-- round 10: guests and staff only collide with floors. Everything standing above the floor (walls, furniture,
-- placed items, doors) goes in NPCSolid, which guests pass through, so nobody can ever get wedged. Nav
-- keeps them walking round things, and players still collide with all of it.
pcall(function() PhysicsService:RegisterCollisionGroup("NPCSolid") end)
PhysicsService:CollisionGroupSetCollidable("Guests", "NPCSolid", false)
local function topOf(d)
	local cf, s = d.CFrame, d.Size
	return cf.Y + 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
end
local function solid(d)
	if not d:IsA("BasePart") or not d.Parent or d:IsDescendantOf(GUESTS) or d.CollisionGroup ~= "Default" then return end
	if d:IsDescendantOf(PLACED) or topOf(d) > O.Y + 1.45 then d.CollisionGroup = "NPCSolid" end
end
for _, d in ipairs(HOTEL:GetDescendants()) do solid(d) end
table.insert(conns, HOTEL.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") then task.defer(solid, d) end
end))

---------------------------------------------------------------- props that shouldn't block

-- (placed items carry their own CanCollide from Shared.Items; this covers the room clutter)
for _, d in ipairs(HOTEL:GetDescendants()) do
	if d:IsA("BasePart") and not d:IsDescendantOf(PLACED) then
		local m = d:FindFirstAncestorWhichIsA("Model")
		local n = m and m.Name or ""
		if n == "Plant" or n == "FloorLamp" or n == "Rug" or n == "Towel" or n == "Trash"
			or n == "Painting" or n == "NeedCleaning" or d.Name == "Glow" then
			d.CanCollide = false
		end
	end
end

---------------------------------------------------------------- visibility helpers

local function setShown(model, on)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("BaseT") == nil then d:SetAttribute("BaseT", d.Transparency) end
			d.Transparency = on and d:GetAttribute("BaseT") or 1
			if model.Name == "Clean" then d.CanCollide = on and d.Name ~= "Glass" end
			if model.Name ~= "Clean" and model.Name ~= "Messy" then d.CanCollide = false end
		elseif d:IsA("SurfaceGui") or d:IsA("Light") then
			d.Enabled = on
		end
	end
end

---------------------------------------------------------------- money

local pending = 0 -- cash on the pile, collected by anyone
local dayStats = { earned = 0, guests = 0, cleans = 0 } -- resets at every day rollover

local function addCash(player, amount)
	-- round 10e: a co-op hotel's money is the owner's (a helper's collecting lands in the owner's cash)
	player = Players:GetPlayerByUserId(HOTEL:GetAttribute("Owner") or 0) or player
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + amount)
	player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + amount)
end

local pile = HOTEL.Lobby.CashPile
local pileOrigin = pile:GetAttribute("Origin")
local cashPrompt

local function drawPile()
	local want = math.min(math.ceil(pending / C.BUNDLE_VALUE), 30)
	local have = #pile:GetChildren()
	for i = have + 1, want do
		local b = PROPS.CashBundle:Clone()
		local k = i - 1
		local layer = k // 6
		local slot = k % 6
		local x = (slot % 2) * 1.7 - 0.85
		local z = (slot // 2) * 0.82 - 0.82
		b:PivotTo(pileOrigin * CFrame.new(x, layer * 0.31, z) * CFrame.Angles(0, rng:NextNumber(-0.06, 0.06), 0))
		for _, p in ipairs(b:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
		b.Parent = pile
	end
	for i = have, want + 1, -1 do
		local c = pile:GetChildren()[i]
		if c then c:Destroy() end
	end
	if cashPrompt then
		cashPrompt.Enabled = pending > 0
		cashPrompt.ActionText = "Collect $" .. pending
	end
	HOTEL:SetAttribute("Pending", pending)
end

do
	local stand = HOTEL.Lobby.CashStand
	cashPrompt = Instance.new("ProximityPrompt")
	cashPrompt.Name = "CollectPrompt"
	cashPrompt.ObjectText = "Hotel Cash"
	cashPrompt.ActionText = "Collect"
	cashPrompt.Style = Enum.ProximityPromptStyle.Custom
	cashPrompt.MaxActivationDistance = 11
	cashPrompt.RequiresLineOfSight = false
	cashPrompt.HoldDuration = 0.25
	cashPrompt:SetAttribute("Icon", "cash")
	cashPrompt:SetAttribute("Color", "green")
	cashPrompt.Enabled = false
	cashPrompt.Parent = stand
	cashPrompt.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player); return end
		if pending <= 0 then return end
		local amount = pending
		pending = 0
		addCash(player, amount)
		drawPile()
		quest("collect")
		Notify:FireClient(player, "collect", { amount = amount, pos = stand.Position + Vector3.new(0, 4, 0) })
	end)
end

---------------------------------------------------------------- rooms

local rooms = {} -- id -> room

local function roomCounts()
	local r, b, d = 0, 0, 0
	for _, room in pairs(rooms) do
		if room.state == "Ready" then r += 1
		elseif room.state == "Dirty" then d += 1
		elseif room.state == "Unfurnished" then -- bought but not open yet
		else b += 1 end
	end
	HOTEL:SetAttribute("RoomsReady", r)
	HOTEL:SetAttribute("RoomsBusy", b)
	HOTEL:SetAttribute("RoomsDirty", d)
	return r, b, d
end

-- a room's own bed / shower / toilet, wherever build mode put it
local function core(room, kind)
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Core") == kind and m:GetAttribute("Room") == room.model.Name then return m end
	end
end

-- a bought wing starts unfurnished: it opens for guests once it has its bed, shower and toilet
local CORE_KINDS = { "Bed", "Shower", "Toilet" }
local function furnished(room)
	for _, kind in ipairs(CORE_KINDS) do
		if not core(room, kind) then return false end
	end
	return true
end

local function showBed(room, clean)
	local bed = core(room, "Bed")
	if not bed then return end
	setShown(bed.Clean, clean)
	setShown(bed.Messy, not clean)
	if room.throw then setShown(room.throw, clean) end
end

local function setRoomState(room, state)
	room.state = state
	room.model:SetAttribute("State", state)
	local dirty = state == "Dirty"
	showBed(room, not dirty)
	setShown(room.mess, dirty)
	for name, prompt in pairs(room.prompts) do
		local need = dirty and room.tasks[name]
		prompt.Enabled = need and true or false
		room.dust[name].Enabled = need and true or false
	end
	roomCounts()
	-- round 10e: the save keeps which rooms were left dirty
	local ids = {}
	for id, r in pairs(rooms) do if r.state == "Dirty" then table.insert(ids, id) end end
	table.sort(ids)
	HOTEL:SetAttribute("DirtyRooms", HttpService:JSONEncode(ids))
end

local function sparkleBurst(pos)
	local a = Instance.new("Part")
	a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.Transparency = 1
	a.Size = Vector3.new(1, 1, 1); a.Position = pos
	a.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = C.ICONS.sparkle
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rotation = NumberRange.new(0, 360)
	e.LightEmission = 0.4
	e.Rate = 0
	e.Parent = a
	e:Emit(16)
	game:GetService("Debris"):AddItem(a, 2)
end

local function makeDust(part)
	-- soft brown motes over a dirty spot, so it reads from across the room
	local e = Instance.new("ParticleEmitter")
	e.Name = "Dust"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 120, 90))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.7), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new(0.6, 1.4)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 3
	e.LightInfluence = 1
	e.Enabled = false
	e.Parent = part
	return e
end

-- round 10e: happy guests leave a tip on the bed. Any member can take it (straight into their cash);
-- otherwise it goes on the cash pile once the room is cleaned
local function takeTip(room, player)
	local t = room.tip
	if not t then return end
	room.tip = nil
	local pos = t.part.Position
	t.part:Destroy()
	if player then
		addCash(player, t.amount)
	else
		pending += t.amount
		dayStats.earned += t.amount
		drawPile()
	end
	sparkleBurst(pos)
	Notify:FireAllClients("paid", { pos = pos + Vector3.new(0, 2, 0), amount = t.amount })
end
local function leaveTip(room, amount)
	local bed = core(room, "Bed")
	if not bed or room.tip then return end
	local cf, size = bed:GetBoundingBox()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { bed }
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, size.Y, 0), Vector3.new(0, -size.Y * 2, 0), rp)
	local top = hit and hit.Position or (cf.Position + Vector3.new(0, size.Y / 2, 0))
	local note = Instance.new("Part")
	note.Name = "Tip"
	note.Size = Vector3.new(1.3, 0.12, 0.75)
	note.Color = Color3.fromRGB(120, 196, 120)
	note.Material = Enum.Material.SmoothPlastic
	note.Anchored, note.CanCollide, note.CanQuery = true, false, false
	note.CFrame = CFrame.new(top + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = C.ICONS.cash
	d.Parent = note
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Take Tip"
	p.ObjectText = "$" .. amount
	p.KeyboardKeyCode = Enum.KeyCode.F
	p.GamepadKeyCode = Enum.KeyCode.ButtonY
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Icon", "cash")
	p:SetAttribute("Color", "green")
	p.Parent = note
	note.Parent = room.model
	room.tip = { part = note, amount = amount }
	p.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player) return end
		takeTip(room, player)
	end)
end

local function roomFinishedCleaning(room)
	takeTip(room, nil)
	setRoomState(room, "Ready")
	quest("clean")
	sparkleBurst(room.nav.Enter.Position + Vector3.new(0, 2, 0))
	tell("toast", { text = "Room " .. room.id .. " is ready!", icon = "roomReady" })
end

---------------------------------------------------------------- room upgrades (round 7: room attribute Tier 1..3, Stars 1..5)
-- Deluxe and Suite rooms get wainscoting, an upholstered feature wall behind the bed, wall sconces, a darker
-- floor and a throw on the bed (the throw follows the bed). Suites add crown moulding and a marble bathroom.
-- Every room has a sign over its door with its tier and stars.

local TIER_LOOK = {
	{ sign = Color3.fromRGB(92, 66, 118), trim = Color3.fromRGB(214, 204, 228), text = Color3.fromRGB(255, 255, 255) },
	{ sign = Color3.fromRGB(40, 54, 116), trim = Color3.fromRGB(216, 174, 96), text = Color3.fromRGB(255, 232, 170),
		accent = Color3.fromRGB(48, 66, 138), floor = Color3.fromRGB(150, 88, 54), throw = Color3.fromRGB(44, 60, 140) },
	{ sign = Color3.fromRGB(18, 86, 66), trim = Color3.fromRGB(240, 192, 76), text = Color3.fromRGB(255, 226, 140),
		accent = Color3.fromRGB(22, 108, 82), floor = Color3.fromRGB(112, 64, 42), throw = Color3.fromRGB(20, 110, 82), suite = true },
}
local PANEL = Color3.fromRGB(250, 244, 234)
local PANEL_DK = Color3.fromRGB(226, 214, 198)
local WOOD_DK = Color3.fromRGB(110, 66, 42)

local function tierOf(room)
	return math.clamp(room.model:GetAttribute("Tier") or 1, 1, #C.ROOM_TIERS)
end

local function starsOf(room)
	local a = room.model:GetAttribute("Appeal") or 0
	local s = tierOf(room) + (a >= C.STAR_APPEAL[1] and 1 or 0) + (a >= C.STAR_APPEAL[2] and 1 or 0)
	return math.clamp(s, 1, 5)
end

local function decoPart(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- inner wall faces round a room (raycasts into the shell, so wing rooms work too)
local function roomBox(room)
	if room.box then return room.box end
	local f = room.model.Floor
	if room.model:GetAttribute("Custom") then
		local ox = f.Position.X
		room.box = { cx = ox, xl = ox - f.Size.X / 2, xr = ox + f.Size.X / 2, zb = f.Position.Z - f.Size.Z / 2, zf = f.Position.Z + f.Size.Z / 2 }
		return room.box
	end
	local cx = f.Position.X
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { HOTEL.Shell }
	local o = Vector3.new(cx, Build.FY + 6, -15)
	local function hit(d, fallback)
		local r = workspace:Raycast(o, d, rp)
		return r and r.Position or fallback
	end
	room.box = {
		cx = cx,
		xl = hit(Vector3.new(-40, 0, 0), o - Vector3.new(12.75, 0, 0)).X,
		xr = hit(Vector3.new(40, 0, 0), o + Vector3.new(12.75, 0, 0)).X,
		zb = hit(Vector3.new(0, 0, -40), Vector3.new(cx, 0, -29.5)).Z,
		zf = -2.5,
	}
	return room.box
end

-- one run of wainscoting on a wall face from a to b (floor height); n points into the room
local function wainscot(parent, a, b, n, look)
	local len = (b - a).Magnitude
	if len < 1.5 then return end
	local mid = (a + b) / 2
	local base = CFrame.lookAt(mid, mid + n) -- -Z points into the room, X runs along the wall
	local H = 3.8
	decoPart(parent, "Wainscot", Vector3.new(len, H, 0.12), base * CFrame.new(0, H / 2, -0.06), PANEL, Enum.Material.Plaster)
	decoPart(parent, "Skirting", Vector3.new(len, 0.7, 0.26), base * CFrame.new(0, 0.35, -0.13), WOOD_DK, Enum.Material.Wood)
	decoPart(parent, "Rail", Vector3.new(len, 0.3, 0.3), base * CFrame.new(0, H + 0.1, -0.15), look.trim, Enum.Material.Metal)
	-- raised panel mouldings
	local count = math.max(1, math.floor(len / 3.4 + 0.5))
	local w = len / count
	local pw, ph = w - 0.8, H - 1.6
	for i = 1, count do
		local pc = base * CFrame.new(-len / 2 + w * (i - 0.5), 0.7 + 0.45 + ph / 2, -0.16)
		decoPart(parent, "Mould", Vector3.new(pw, 0.14, 0.08), pc * CFrame.new(0, ph / 2, 0), PANEL_DK)
		decoPart(parent, "Mould", Vector3.new(pw, 0.14, 0.08), pc * CFrame.new(0, -ph / 2, 0), PANEL_DK)
		decoPart(parent, "Mould", Vector3.new(0.14, ph, 0.08), pc * CFrame.new(-pw / 2, 0, 0), PANEL_DK)
		decoPart(parent, "Mould", Vector3.new(0.14, ph, 0.08), pc * CFrame.new(pw / 2, 0, 0), PANEL_DK)
	end
end

-- a wall sconce on the back wall: brass plate, arm, glowing shade
local function sconce(parent, pos, look)
	local plate = decoPart(parent, "SconcePlate", Vector3.new(0.7, 1.5, 0.14), CFrame.new(pos + Vector3.new(0, 0, 0.07)), look.trim, Enum.Material.Metal)
	decoPart(parent, "SconceArm", Vector3.new(0.18, 0.18, 0.8), CFrame.new(pos + Vector3.new(0, -0.2, 0.5)), look.trim, Enum.Material.Metal)
	local shade = decoPart(parent, "SconceShade", Vector3.new(1.2, 1.05, 1.05),
		CFrame.new(pos + Vector3.new(0, 0.3, 0.95)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 226, 180), Enum.Material.Neon, Enum.PartType.Cylinder)
	shade.Transparency = 0.08
	local l = Instance.new("PointLight")
	l.Range = 13
	l.Brightness = 0.9
	l.Color = Color3.fromRGB(255, 210, 160)
	l.Parent = shade
	return plate
end

-- the upholstered feature wall behind the bed (channel tufting, brass frame)
local function featureWall(parent, x, zb, look)
	local W, Ht = 10, 11
	local base = CFrame.lookAt(Vector3.new(x, Build.FY, zb), Vector3.new(x, Build.FY, zb + 1))
	decoPart(parent, "Feature", Vector3.new(W, Ht, 0.22), base * CFrame.new(0, Ht / 2, -0.11), look.accent, Enum.Material.Fabric)
	local dark = look.accent:Lerp(Color3.new(0, 0, 0), 0.35)
	local n = 8
	for i = 1, n - 1 do
		decoPart(parent, "Channel", Vector3.new(0.1, Ht - 0.6, 0.06), base * CFrame.new(-W / 2 + W / n * i, Ht / 2, -0.24), dark, Enum.Material.Fabric)
	end
	for _, sx in ipairs({ -1, 1 }) do
		decoPart(parent, "FeatureEdge", Vector3.new(0.3, Ht + 0.3, 0.34), base * CFrame.new(sx * (W / 2 + 0.15), Ht / 2, -0.17), look.trim, Enum.Material.Metal)
	end
	decoPart(parent, "FeatureTop", Vector3.new(W + 0.6, 0.3, 0.34), base * CFrame.new(0, Ht + 0.15, -0.17), look.trim, Enum.Material.Metal)
end

-- the throw across the foot of the bed (built at the bed, then moved with it)
local function makeThrow(parent, bedCF, look)
	local m = Instance.new("Model")
	m.Name = "Throw"
	local h, z, d = 3.0, 2.7, 2.3
	local stripe = look.trim
	decoPart(m, "Top", Vector3.new(7.0, 0.14, d), bedCF * CFrame.new(0, h, z), look.throw, Enum.Material.Fabric)
	for _, sz in ipairs({ -0.75, 0.75 }) do
		decoPart(m, "Stripe", Vector3.new(7.02, 0.16, 0.22), bedCF * CFrame.new(0, h, z + sz), stripe, Enum.Material.Fabric)
	end
	for _, sx in ipairs({ -1, 1 }) do
		decoPart(m, "Drape", Vector3.new(0.14, 1.3, d), bedCF * CFrame.new(sx * 3.5, h - 0.58, z), look.throw, Enum.Material.Fabric)
		for _, sz in ipairs({ -0.75, 0.75 }) do
			decoPart(m, "Stripe", Vector3.new(0.16, 1.32, 0.22), bedCF * CFrame.new(sx * 3.5, h - 0.58, z + sz), stripe, Enum.Material.Fabric)
		end
	end
	m.WorldPivot = bedCF
	m.Parent = parent
	return m
end

local function placeThrow(room)
	local bed = core(room, "Bed")
	if room.throw and bed then room.throw:PivotTo(bed:GetPivot()) end
end

-- (re)builds a room's upgrade decor for its tier
local function dressRoom(room)
	local m = room.model
	local old = m:FindFirstChild("Upgrade")
	if old then old:Destroy() end
	room.throw = nil
	local tier = tierOf(room)
	local look = TIER_LOOK[tier]
	local up = Instance.new("Model")
	up.Name = "Upgrade"
	local b = roomBox(room)
	local cx, xl, xr, zb, zf = b.cx, b.xl, b.xr, b.zb, b.zf
	local FY = Build.FY
	-- floors (remember the builder's look so a reset can put it back)
	for _, name in ipairs({ "Floor", "BathFloor" }) do
		local f = m:FindFirstChild(name)
		if f then
			if f:GetAttribute("BaseColor") == nil then
				f:SetAttribute("BaseColor", f.Color)
				f:SetAttribute("BaseMat", f.Material.Name)
			end
			f.Color = f:GetAttribute("BaseColor")
			f.Material = Enum.Material[f:GetAttribute("BaseMat")]
		end
	end
	local props = m:FindFirstChild("Props")
	local painting = props and props:FindFirstChild("Painting")
	if painting then
		if painting:GetAttribute("BaseCF") == nil then painting:SetAttribute("BaseCF", painting:GetPivot()) end
		painting:PivotTo(painting:GetAttribute("BaseCF") + Vector3.new(0, 0, tier >= 2 and 0.3 or 0))
	end
	if tier >= 2 then
		m.Floor.Color = Color3.new(1, 1, 1):Lerp(look.floor, 0.5)
	end
	if tier >= 2 and not m:GetAttribute("Custom") then
		if look.suite and m:FindFirstChild("BathFloor") then
			m.BathFloor.Color = Color3.fromRGB(240, 236, 230)
			m.BathFloor.Material = Enum.Material.Marble
		end
		local fx = cx - 4 -- feature wall centred where the bed starts
		local back = Vector3.new(0, 0, 1)
		wainscot(up, Vector3.new(xl, FY, zb), Vector3.new(fx - 5.3, FY, zb), back, look)
		wainscot(up, Vector3.new(fx + 5.3, FY, zb), Vector3.new(cx + 5.2, FY, zb), back, look)
		wainscot(up, Vector3.new(xl, FY, zb), Vector3.new(xl, FY, zf - 0.1), Vector3.new(1, 0, 0), look)
		wainscot(up, Vector3.new(xr, FY, -13.8), Vector3.new(xr, FY, zf - 0.1), Vector3.new(-1, 0, 0), look)
		wainscot(up, Vector3.new(xl, FY, zf), Vector3.new(cx - 2.9, FY, zf), Vector3.new(0, 0, -1), look)
		wainscot(up, Vector3.new(cx + 2.9, FY, zf), Vector3.new(xr, FY, zf), Vector3.new(0, 0, -1), look)
		featureWall(up, fx, zb, look)
		sconce(up, Vector3.new(fx - 6.4, FY + 6.6, zb), look)
		sconce(up, Vector3.new(fx + 6.4, FY + 6.6, zb), look)
		local bed = core(room, "Bed")
		if bed then room.throw = makeThrow(up, bed:GetPivot(), look) end
	end
	up.Parent = m
	if room.throw then setShown(room.throw, room.state ~= "Dirty") end
end

-- the hotel's rating (Hotel attribute HotelStars): the average of its rooms' stars, blended half and half with
-- the guests' reviews once there are any. The last 20 reviews are published as JSON (Hotel attribute Reviews).
local reviews = {} -- newest first: { name, stars, text, room }
local reviewsJSON
-- the saved reviews arrive on the hotel attribute when a save loads (Save)
local function loadReviews()
	local j = HOTEL:GetAttribute("Reviews")
	if j == reviewsJSON or type(j) ~= "string" then return end
	reviewsJSON = j
	local ok, t = pcall(HttpService.JSONDecode, HttpService, j)
	if ok and type(t) == "table" then reviews = t end
end
local function updateRating()
	loadReviews()
	local sum, n = 0, 0
	for _, r in pairs(rooms) do
		sum += r.model:GetAttribute("Stars") or 1
		n += 1
	end
	local rating = n > 0 and sum / n or 1
	if #reviews > 0 then
		local rs = 0
		local wn = 0
		for _, r in ipairs(reviews) do rs += r.stars * (r.w or 1); wn += (r.w or 1) end -- influencers count more
		local avg = rs / wn
		HOTEL:SetAttribute("ReviewStars", math.floor(avg * 10 + 0.5) / 10)
		rating = rating * 0.5 + avg * 0.5
	end
	HOTEL:SetAttribute("HotelStars", math.floor(rating * 10 + 0.5) / 10)
end

local onTier -- forward: a room's Tier changed (set after syncRoom)

---------------------------------------------------------------- cleaning minigames
-- pressing a clean prompt opens a minigame on that player's screen (Minigames).
-- The server never trusts the client: a session is opened here, and CleanDone only
-- counts if it arrives in time, took at least C.MINIGAME_MIN, and the task is still dirty.
local cleaning = {} -- player -> { room, task, t0 }
-- front desk minigames (round 10c): Check In / Check Out open one too (tasks "CheckIn" / "CheckOut"),
-- reported on the same remote; the guest's patience pauses while it's open
local deskGames = {} -- player -> { t0, done = function(ok, stars) }

local function endCleaning(player, restore)
	local s = cleaning[player]
	if not s then return end
	cleaning[player] = nil
	if restore and s.room.tasks[s.task] and s.room.state == "Dirty" then
		s.room.prompts[s.task].Enabled = true
	end
end

local function startCleaning(player, room, task)
	if cleaning[player] then return end -- already playing one
	cleaning[player] = { room = room, task = task, t0 = os.clock() }
	room.prompts[task].Enabled = false
	Notify:FireClient(player, "minigame", {
		task = task,
		label = room.spots[task] and room.spots[task]:GetAttribute("Label"),
		room = room.id,
	})
	task.delay(C.MINIGAME_TIMEOUT, function()
		local s = cleaning[player]
		if s and s.room == room and s.task == task then
			endCleaning(player, true)
			Notify:FireClient(player, "minigameEnd") -- still on screen? close it
		end
	end)
end

table.insert(conns, RS.Shared.Remotes.CleanDone.OnServerEvent:Connect(function(player, cancel, stars)
	local dg = deskGames[player]
	if dg then
		deskGames[player] = nil
		local ok = not cancel and os.clock() - dg.t0 >= C.DESK_GAME_MIN and isMember(player)
		dg.done(ok, ok and math.clamp(math.floor(tonumber(stars) or 1), 1, 3) or 0)
		return
	end
	local s = cleaning[player]
	if not s then return end
	if cancel then -- the player closed the minigame: give the prompt back
		endCleaning(player, true)
		return
	end
	local took = os.clock() - s.t0
	local room, task = s.room, s.task
	if took < C.MINIGAME_MIN or took > C.MINIGAME_TIMEOUT or not isMember(player) then
		endCleaning(player, true) -- never leave the prompt switched off
		return
	end
	cleaning[player] = nil
	if room.state == "Dirty" and room.tasks[task] and room.clean(task, player) then
		-- a quick, tidy job earns a little extra (the minigame shows three stars under par)
		local par = C.MINIGAME_PAR[task]
		if par and took <= par then
			Levels.award(HOTEL, math.ceil(Levels.XP.clean * 0.5), "Speedy clean", room.spots[task].Position + Vector3.new(0, 2, 0))
		end
	end
end))
table.insert(conns, Players.PlayerRemoving:Connect(function(player)
	cleaning[player] = nil
	local dg = deskGames[player]
	deskGames[player] = nil
	if dg then dg.done(false, 0) end
end))

-- the day summary: when DayNight rolls the clock over, every hotel reports
-- its day to its members, then starts fresh
table.insert(conns, game.ServerStorage.Signals:WaitForChild("DayEnded").Event:Connect(function(dayN)
	local s = dayStats
	dayStats = { earned = 0, guests = 0, cleans = 0 }
	-- round 10e: wages, paid by the owner (or whoever's in) every morning; cash can't go below zero
	local wages = 0
	if HOTEL:GetAttribute("WageBill") then
		wages = HOTEL:GetAttribute("WageBill") -- round 13: shifts and research (set by the staff code)
	else
		for _, def in ipairs(C.STAFF) do wages += (def.wage or 0) * (HOTEL:GetAttribute(def.attr) or 0) end
	end
	-- round 19: seasonal upkeep -- winter heating, spring gardening -- per built room, with the wages
	local upkeep = 0
	local rooms = 0
	for _, r in ipairs(HOTEL.Rooms:GetChildren()) do
		if r:IsA("Model") then rooms += 1 end
	end
	upkeep = math.floor(rooms * Clock.seasonData(dayN).upkeep + 0.5)
	local bill = wages + upkeep
	if bill > 0 then
		local payer = Players:GetPlayerByUserId(HOTEL:GetAttribute("Owner") or 0) or members()[1]
		if payer then
			payer:SetAttribute("Cash", math.max(0, (payer:GetAttribute("Cash") or 0) - bill))
			payer:SetAttribute("Spent", (payer:GetAttribute("Spent") or 0) + bill)
		end
	end
	-- a new season reprices every room from its base rate
	for _, r in ipairs(HOTEL.Rooms:GetChildren()) do
		local base = r:GetAttribute("PriceBase")
		if base then r:SetAttribute("Price", math.floor(base * Clock.seasonData(dayN).price + 0.5)) end
	end
	tell("day", {
		wages = wages,
		upkeep = upkeep,
		day = dayN,
		earned = s.earned,
		guests = s.guests,
		cleans = s.cleans,
		uncollected = pending,
	})
end))

---------------------------------------------------------------- room doors: locks, knocking, door hangers (round 10c)
-- While a guest is inside their room the door is locked to players: an invisible DoorBlock in the doorway
-- (NPCSolid, so guests and staff walk through it) and the room attribute Locked, which Doors reads so the
-- leaf won't swing for you. A Knock prompt sits on the corridor side; the guest may let you in for a while.
-- Guests hang a Do Not Disturb or Sleeping card on the corridor knob (room attribute Sign = "DND" / "Sleep").
local knockOn -- forward (set once guests can talk): function(room, player)
local HANGER_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)
local HANGERS = {
	DND = { card = Color3.fromRGB(150, 32, 46), small = "PLEASE", big = { "DO NOT", "DISTURB" } },
	Sleep = { card = Color3.fromRGB(36, 46, 96), small = "SHHH...", big = { "SLEEPING" }, icon = C.ICONS.sleep },
}

-- the door's hinge part and the corridor-side knob (in hinge space), or nil
local function doorKnob(room)
	local door = Rooms.door(room.model)
	local leaf = door and door:FindFirstChild("Leaf")
	local pivot = door and (door.PrimaryPart or door:FindFirstChild("Pivot"))
	if not (leaf and pivot) then return nil end
	for _, p in ipairs(leaf:GetChildren()) do
		if p.Name == "Knob" and p:IsA("BasePart") then
			local l = pivot.CFrame:PointToObjectSpace(p.Position)
			if l.Z > 0.1 then return pivot, leaf, l end
		end
	end
	return nil
end

local function hangerPart(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a card hung on the corridor knob; it lives in the door's Leaf, so the door swings it (Doors)
local function makeHanger(room, kind)
	local def = HANGERS[kind]
	local pivot, leaf, k = doorKnob(room)
	if not (def and pivot) then return nil end
	local m = Instance.new("Model")
	m.Name = "Hanger"
	local tilt = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4)))
	-- hinge space: the card hangs from the knob, flat against the door just in front of the escutcheon
	local top = pivot.CFrame * CFrame.new(k.X, k.Y + 0.02, k.Z - 0.15) * tilt
	local card = hangerPart(m, "Card", Vector3.new(0.64, 1.5, 0.035), top * CFrame.new(0, -0.56, 0), def.card)
	hangerPart(m, "Trim", Vector3.new(0.7, 1.56, 0.02), top * CFrame.new(0, -0.56, -0.012), Color3.fromRGB(214, 172, 92), Enum.Material.Metal)
	-- the ring round the knob's neck
	hangerPart(m, "Ring", Vector3.new(0.05, 0.4, 0.4), top * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(226, 186, 104), Enum.Material.Metal, Enum.PartType.Cylinder)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back -- the corridor side
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 120
	g.LightInfluence = 0.35
	g.Brightness = 1.4
	g.Parent = card
	local cream = Color3.fromRGB(250, 240, 220)
	local gold = Color3.fromRGB(232, 190, 106)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = g
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = gold
	border.Transparency = 0.15
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = frame
	local inner = Instance.new("UIPadding")
	inner.PaddingTop, inner.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	inner.PaddingLeft, inner.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	inner.Parent = frame
	-- the hole the knob goes through
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.new(0.5, 0, 0, 26)
	hole.Size = UDim2.fromOffset(34, 34)
	hole.BackgroundColor3 = Color3.fromRGB(20, 14, 12)
	hole.Parent = frame
	Instance.new("UICorner", hole).CornerRadius = UDim.new(1, 0)
	local hs = Instance.new("UIStroke")
	hs.Thickness = 3
	hs.Color = gold
	hs.Parent = hole
	local function text(t, y, h, size, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y)
		l.Size = UDim2.new(1, 0, 0, h)
		l.FontFace = HANGER_FONT
		l.Text = t
		l.TextScaled = true
		l.TextColor3 = color
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.Parent = l
		l.Parent = frame
		return l
	end
	text(def.small, 52, 16, 14, gold)
	local y = 80
	if def.icon then
		local ic = Instance.new("ImageLabel")
		ic.BackgroundTransparency = 1
		ic.AnchorPoint = Vector2.new(0.5, 0)
		ic.Position = UDim2.new(0.5, 0, 0, 70)
		ic.Size = UDim2.fromOffset(40, 40)
		ic.Image = def.icon
		ic.Parent = frame
		y = 114
	end
	for i, line in ipairs(def.big) do
		text(line, y + (i - 1) * 24, 22, 22, cream)
	end
	-- a brass rule under the words
	local rule = Instance.new("Frame")
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, y + #def.big * 24 + 8)
	rule.Size = UDim2.fromOffset(40, 2)
	rule.BackgroundColor3 = gold
	rule.BorderSizePixel = 0
	rule.Parent = frame
	m.Parent = leaf
	return m
end

local function setSign(room, kind)
	if room.signKind == kind then return end
	room.signKind = kind
	room.model:SetAttribute("Sign", kind)
	if room.hanger then room.hanger:Destroy() room.hanger = nil end
	if kind then room.hanger = makeHanger(room, kind) end
	if room.knockPrompt then
		room.knockPrompt.ObjectText = kind == "DND" and "Do Not Disturb" or (kind == "Sleep" and "Guest sleeping" or ("Room " .. room.id))
	end
end

-- the doorway block and the knock prompt (made once per room)
local function doorBits(room)
	local fr = room.model:FindFirstChild("DoorFrame")
	local th = fr and fr:FindFirstChild("Threshold")
	if not th then return end
	local block = Instance.new("Part")
	block.Name = "DoorBlock"
	block.Size = Vector3.new(th.Size.X - 0.1, 7.9, 0.5)
	block.CFrame = th.CFrame * CFrame.new(0, 3.95, 0)
	block.Transparency = 1
	block.Anchored = true
	block.CanCollide = false
	block.CanQuery = false
	block.CanTouch = false
	block.CollisionGroup = "NPCSolid"
	block:SetAttribute("NavOpen", true)
	block.Parent = fr
	room.doorBlock = block
	local pivot, _, k = doorKnob(room)
	local at = pivot and (pivot.CFrame * Vector3.new(k.X - 0.9, k.Y + 0.7, k.Z + 0.5)) or (th.Position + Vector3.new(0, 4.5, 1))
	local spot = Instance.new("Part")
	spot.Name = "KnockSpot"
	spot.Size = Vector3.new(0.4, 0.4, 0.4)
	spot.CFrame = CFrame.new(at)
	spot.Transparency = 1
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Parent = fr
	local p = Instance.new("ProximityPrompt")
	p.Name = "KnockPrompt"
	p.ActionText = "Knock"
	p.ObjectText = "Room " .. room.id
	p.HoldDuration = 0
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Icon", "door")
	p:SetAttribute("Color", "blue")
	p.Enabled = false
	p.Parent = spot
	room.knockSpot, room.knockPrompt = spot, p
	p.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player) return end
		if knockOn then knockOn(room, player) end
	end)
end

local function addRoom(m)
	local id = m:GetAttribute("RoomId")
	-- room clutter never blocks anyone
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local pm = d:FindFirstAncestorWhichIsA("Model")
			local n = pm and pm.Name or ""
			if n == "Towel" or n == "Trash" or n == "Painting" or n == "NeedCleaning" then d.CanCollide = false end
		end
	end
	local room = {
		id = id, model = m, state = "Ready", mess = m.Mess,
		nav = {}, tasks = {}, prompts = {}, dust = {}, spots = {},
	}
	for _, s in ipairs(m.Nav:GetChildren()) do room.nav[s.Name] = s end
	-- one cleaning job, by a player (prompt) or a janitor (player = nil); false if it was already done
	function room.clean(task, player)
		if room.state ~= "Dirty" or not room.tasks[task] then return false end
		local spot = room.spots[task]
		room.tasks[task] = false
		dayStats.cleans += 1
		Levels.award(HOTEL, Levels.XP.clean, "Cleaning", spot.Position)
		room.prompts[task].Enabled = false
		room.dust[task].Enabled = false
		sparkleBurst(spot.Position)
		if task == "Bed" then
			showBed(room, true)
		elseif task == "Floor" then
			setShown(room.mess, false)
		end
		if player then
			player:SetAttribute("Cleaned", (player:GetAttribute("Cleaned") or 0) + 1)
			Notify:FireClient(player, "cleaned", { task = task, pos = spot.Position })
		else
			sfx(({ Bed = "sheets", Shower = "spray", Toilet = "scrub", Floor = "broom" })[task], spot.Position)
		end
		local left = 0
		for _, t in ipairs(C.TASKS) do if room.tasks[t] then left += 1 end end
		m:SetAttribute("TasksLeft", left)
		if left == 0 then roomFinishedCleaning(room) end
		return true
	end
	for _, spot in ipairs(m.CleanSpots:GetChildren()) do
		local task = spot:GetAttribute("Task")
		room.spots[task] = spot
		local p = Instance.new("ProximityPrompt")
		p.Name = "CleanPrompt"
		p.ActionText = "Clean"
		p.ObjectText = spot:GetAttribute("Label")
		p.HoldDuration = 0
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Style = Enum.ProximityPromptStyle.Custom
		p:SetAttribute("Icon", C.TASK_ICON[task])
		p:SetAttribute("Color", "yellow")
		p.Enabled = false
		p.Parent = spot
		room.prompts[task] = p
		room.dust[task] = makeDust(spot)
		p.Triggered:Connect(function(player)
			if not isMember(player) then notMine(player); return end
			startCleaning(player, room, task)
		end)
	end
	-- shower water + steam (on while someone showers); follows the shower in syncRoom
	local att = Instance.new("Attachment")
	att.Name = "ShowerHead"
	att.Parent = workspace.Terrain
	room.showerHead = att
	local water = Instance.new("ParticleEmitter")
	water.Name = "Water"
	water.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	water.Size = NumberSequence.new(0.12)
	water.Transparency = NumberSequence.new(0.25)
	water.Lifetime = NumberRange.new(0.32, 0.38)
	water.Speed = NumberRange.new(20, 24)
	water.EmissionDirection = Enum.NormalId.Bottom
	water.SpreadAngle = Vector2.new(12, 12)
	water.Rate = 160
	water.LightEmission = 0.3
	water.Enabled = false
	water.Parent = att
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "Steam"
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new(1.5, 4)
	steam.Lifetime = NumberRange.new(2.5, 3.5)
	steam.Speed = NumberRange.new(0.5, 1.5)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.SpreadAngle = Vector2.new(60, 60)
	steam.Rate = 6
	steam.Enabled = false
	steam.Parent = att
	room.water, room.steam = water, steam
	m:SetAttribute("TasksLeft", 0)
	rooms[id] = room
	doorBits(room)
	dressRoom(room)
	m:GetAttributeChangedSignal("Tier"):Connect(function() if onTier then onTier(room) end end)
	return room
end

for _, m in ipairs(HOTEL.Rooms:GetChildren()) do addRoom(m) end

---------------------------------------------------------------- furniture follows build mode

-- world spots for a room's core items (guests read these, so moving a bed just works)
local function coreSpot(room, kind, key)
	local m = core(room, kind)
	local o = Catalog.CORE[kind][key]
	if not m then return nil end
	return m:GetPivot() * o -- CFrame offsets give a CFrame, Vector3 offsets a point
end

local sideParams = OverlapParams.new()
sideParams.FilterType = Enum.RaycastFilterType.Include

-- the first side of the bed with room to stand
local function bedSide(room)
	local bed = core(room, "Bed")
	if not bed then return nil end
	local piv = bed:GetPivot()
	local zone = HOTEL.BuildZones:FindFirstChild(room.model.Name)
	sideParams.FilterDescendantsInstances = { HOTEL.Shell, HOTEL.Rooms, PLACED }
	local first
	for _, o in ipairs(Catalog.CORE.Bed.sides) do
		local p = piv * o
		first = first or p
		local inZone = zone and Build.zoneAt(p) == zone
		local clear = inZone
		if clear then
			for _, hit in ipairs(workspace:GetPartBoundsInBox(CFrame.new(p), Vector3.new(2, 3.6, 2), sideParams)) do
				if hit.CanCollide and not hit:IsDescendantOf(bed) then
					clear = false
					break
				end
			end
		end
		if clear then return p end
	end
	return first
end

local function syncRoom(room)
	for task, kind in pairs({ Bed = "Bed", Shower = "Shower", Toilet = "Toilet" }) do
		local p = coreSpot(room, kind, "clean")
		if p and room.spots[task] then room.spots[task].Position = p end
	end
	local head = coreSpot(room, "Shower", "head")
	if head then room.showerHead.WorldPosition = head end
	local appeal = Build.appeal(room.model.Name, HOTEL)
	room.model:SetAttribute("Appeal", appeal)
	local nightly = C.ROOM_PRICE + C.ROOM_TIERS[tierOf(room)].bonus + appeal * Catalog.PRICE_PER_APPEAL
	nightly = math.floor(nightly * (Research.hasPerk(HOTEL, "price") and 1.15 or 1) * Research.mul(HOTEL, "price") + 0.5) -- research: Premium Pricing, Smart Rates, ...
	local Grades = require(RS.Shared.Grades) -- round 11: a better hotel grade charges more
	nightly = math.floor(nightly * Grades.priceMul(Grades.of(HOTEL)) + 0.5)
	-- round 19: seasonal rates (the base is kept so a new season can reprice every room)
	room.model:SetAttribute("PriceBase", nightly)
	nightly = math.floor(nightly * Clock.seasonData().price + 0.5)
	room.model:SetAttribute("Price", nightly)
	room.model:SetAttribute("Stars", starsOf(room))
	if room.state == "Unfurnished" then
		local missing = {}
		for _, kind in ipairs(CORE_KINDS) do
			if not core(room, kind) then table.insert(missing, string.lower(kind)) end
		end
		room.model:SetAttribute("Missing", table.concat(missing, ", "))
	else
		room.model:SetAttribute("Missing", nil)
	end
	placeThrow(room)
	showBed(room, room.state ~= "Dirty")
end

-- round 10e: lobby decor gathers dust now and then (a little less appeal each). Janitors with nothing to do
-- dust it off, or any member can (hold the prompt)
local DUST_MAX = 4
local function isDusty(m) return m:GetAttribute("Dusty") == true end
local function dustyItems()
	local list = {}
	for _, m in ipairs(PLACED:GetChildren()) do if isDusty(m) then table.insert(list, m) end end
	return list
end
local scanAppeal -- forward (re-reads the lobby appeal)
local function setDusty(m, on)
	local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	m:SetAttribute("Dusty", on or nil)
	local e = part:FindFirstChild("Dust") or makeDust(part)
	e.Enabled = on
	local p = part:FindFirstChild("DustPrompt")
	if on and not p then
		p = Instance.new("ProximityPrompt")
		p.Name = "DustPrompt"
		p.ActionText = "Dust Off"
		p.ObjectText = Catalog.ITEMS[m:GetAttribute("Item") or ""] and Catalog.ITEMS[m:GetAttribute("Item")].name or "Decor"
		p.KeyboardKeyCode = Enum.KeyCode.F
		p.GamepadKeyCode = Enum.KeyCode.ButtonY
		p.HoldDuration = 1.2
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Style = Enum.ProximityPromptStyle.Custom
		p:SetAttribute("Icon", "clean")
		p:SetAttribute("Color", "blue")
		p.Parent = part
		p.Triggered:Connect(function(player)
			if not isMember(player) then notMine(player) return end
			if not isDusty(m) then return end
			setDusty(m, false)
			sparkleBurst(part.Position)
			Levels.award(HOTEL, 2, "Dusted", part.Position + Vector3.new(0, 2, 0))
		end)
	elseif not on and p then
		p:Destroy()
	end
	if not on then sparkleBurst(part.Position) end
	if scanAppeal then scanAppeal() end
end
task.spawn(function()
	while running do
		task.wait(rng:NextNumber(50, 80))
		if #dustyItems() < DUST_MAX then
			local list = {}
			for _, m in ipairs(PLACED:GetChildren()) do
				local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
				if m:GetAttribute("Zone") == "Lobby" and it and not it.flat and not it.structure and not isDusty(m) and (it.appeal or 0) > 0 then
					table.insert(list, m)
				end
			end
			if #list > 0 then setDusty(list[rng:NextInteger(1, #list)], true) end
		end
	end
end)

local lobbyAppeal = 0
local function syncAll()
	for _, room in pairs(rooms) do
		syncRoom(room)
		-- the moment an unfurnished room gets its bed, shower and toilet, it opens for guests
		if room.state == "Unfurnished" and furnished(room) then
			setRoomState(room, "Ready")
			syncRoom(room)
			sparkleBurst(room.nav.Enter.Position + Vector3.new(0, 2, 0))
			tell("toast", { text = "Room " .. room.id .. " is furnished and open!", icon = "roomReady" })
		end
	end
	lobbyAppeal = math.max(0, Build.appeal("Lobby", HOTEL) - 2 * #dustyItems() - 3 * (HOTEL:GetAttribute("BrokenLobby") or 0))
	HOTEL:SetAttribute("LobbyAppeal", lobbyAppeal)
	updateRating()
end

-- an upgrade (BuildServer sets Tier) or a restored save: redress the room, sparkle it up
onTier = function(room)
	dressRoom(room)
	syncRoom(room)
	updateRating()
	local b = roomBox(room)
	for _ = 1, 7 do
		sparkleBurst(Vector3.new(b.cx + rng:NextNumber(-10, 8), Build.FY + rng:NextNumber(2, 8), rng:NextNumber(-27, -6)))
	end
end

for _, room in pairs(rooms) do setRoomState(room, furnished(room) and "Ready" or "Unfurnished") end
syncAll()
scanAppeal = function()
	lobbyAppeal = math.max(0, Build.appeal("Lobby", HOTEL) - 2 * #dustyItems() - 3 * (HOTEL:GetAttribute("BrokenLobby") or 0))
	HOTEL:SetAttribute("LobbyAppeal", lobbyAppeal)
end
-- round 10e: a restored save brings back the rooms that were left dirty (Save sets DirtyRestore)
local function restoreDirty()
	local list = {}
	pcall(function() list = HttpService:JSONDecode(HOTEL:GetAttribute("DirtyRestore") or "[]") end)
	HOTEL:SetAttribute("DirtyRestore", nil)
	task.wait(3) -- rooms made of walls are found a moment after the build comes back
	for _, id in ipairs(list) do
		local room = rooms[id] or rooms[tonumber(id) or id] or rooms[tostring(id)]
		if room and room.state == "Ready" and not room.guest then
			for _, t in ipairs(C.TASKS) do room.tasks[t] = true end
			room.model:SetAttribute("TasksLeft", #C.TASKS)
			setRoomState(room, "Dirty")
		end
	end
end
if HOTEL:GetAttribute("DirtyRestore") then task.spawn(restoreDirty) end
table.insert(conns, HOTEL:GetAttributeChangedSignal("DirtyRestore"):Connect(function()
	if HOTEL:GetAttribute("DirtyRestore") then task.spawn(restoreDirty) end
end))
table.insert(conns, ItemsChanged.Event:Connect(syncAll))

-- round 12: every front desk gets a chair you can sit in (a Seat named DeskSeat at its SeatSpot, with a Sit
-- prompt). Guests' Check In / Check Out buttons only work for a member sitting in one (see deskService).
do
	local function seatDesk(desk)
		local spot = desk:FindFirstChild("SeatSpot")
		if not spot or desk:FindFirstChild("DeskSeat") then return end
		local seat = Instance.new("Seat")
		seat.Name = "DeskSeat"
		seat.Size = Vector3.new(2, 0.3, 2)
		seat.Transparency = 1
		seat.Anchored = true
		seat.CanCollide = false
		seat.CanTouch = false -- walking past never sits you down; the prompt does
		seat.CFrame = spot.CFrame * CFrame.new(0, -1.55, 0)
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "SitDesk"
		pr.ActionText = "Sit at the desk"
		pr.ObjectText = "Front desk"
		pr.Style = Enum.ProximityPromptStyle.Custom
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr.HoldDuration = 0
		pr.KeyboardKeyCode = Enum.KeyCode.F
		pr:SetAttribute("Icon", "bell")
		pr:SetAttribute("Color", "blue")
		pr.Parent = seat
		pr.Triggered:Connect(function(player)
			if not isMember(player) then notMine(player); return end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not seat.Occupant then
				-- round 14: a receptionist in the chair gets up and steps aside first
				desk:SetAttribute("PlayerTaking", os.clock())
				task.wait(0.4)
				if not seat.Occupant and hum.Health > 0 then seat:Sit(hum) end
			end
		end)
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			pr.Enabled = seat.Occupant == nil
			local hum = seat.Occupant
			local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
			if player then
				Notify:FireClient(player, "toast", { text = "You're on the desk. Serve the guests waiting in line", icon = "bell" })
			end
		end)
		seat.Parent = desk
	end
	local function seatAll()
		for _, d in ipairs(Build.desks(HOTEL)) do seatDesk(d) end
	end
	-- sofas, armchairs, stools and dining chairs: a Sit prompt on each seat guests use (GuestLife.SEATS)
	local function seatDecor(m)
		local seats = Life.SEATS[m:GetAttribute("Item") or ""]
		if not seats or m:FindFirstChild("DecorSeat1") then return end
		local piv = m:GetPivot()
		for i, sp in ipairs(seats) do
			local seat = Instance.new("Seat")
			seat.Name = "DecorSeat" .. i
			seat.Size = Vector3.new(1.8, 0.2, 1.8)
			seat.Transparency = 1
			seat.Anchored = true
			seat.CanCollide = false
			seat.CanTouch = false
			seat.CanQuery = false
			seat.CFrame = piv * CFrame.new(sp[1], sp[3] - 0.1, sp[2]) * CFrame.Angles(0, math.rad(sp[4] or 0), 0) * CFrame.Angles(0, math.pi, 0)
			local pr = Instance.new("ProximityPrompt")
			pr.Name = "SitDecor"
			pr.ActionText = "Sit"
			pr.Style = Enum.ProximityPromptStyle.Custom
			pr.MaxActivationDistance = 6
			pr.RequiresLineOfSight = false
			pr.HoldDuration = 0
			pr.KeyboardKeyCode = Enum.KeyCode.F
			pr:SetAttribute("Icon", "guest")
			pr:SetAttribute("Color", "blue")
			pr.Parent = seat
			pr.Triggered:Connect(function(player)
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and not seat.Occupant and not hum.SeatPart then seat:Sit(hum) end
			end)
			seat:GetPropertyChangedSignal("Occupant"):Connect(function() pr.Enabled = seat.Occupant == nil end)
			seat.Parent = m
		end
	end
	local function seatEverything()
		seatAll()
		for _, m in ipairs(PLACED:GetChildren()) do seatDecor(m) end
	end
	seatEverything()
	table.insert(conns, ItemsChanged.Event:Connect(function() task.defer(seatEverything) end))
end

-- round 10d: rooms made with walls and a door. A scan runs a moment after any build change (and every few
-- seconds while a room waits for its guest to leave before it can go)
local scanQueued = false
local function scanSoon()
	if scanQueued then return end
	scanQueued = true
	task.delay(0.4, function()
		scanQueued = false
		if not running then return end
		local ok, made = pcall(Rooms.scan, HOTEL)
		if not ok then warn("Rooms:", made) return end
		for _, id in ipairs(made) do
			local r = rooms[id]
			if r then sparkleBurst(r.nav.Enter.Position + Vector3.new(0, 2, 0)) end
			tell("toast", { text = "Room " .. id .. " made! Add a bed, shower and toilet", icon = "roomReady" })
		end
	end)
end
table.insert(conns, ItemsChanged.Event:Connect(scanSoon))
task.spawn(function()
	while running do
		task.wait(5)
		if HOTEL:GetAttribute("RoomsPending") then scanSoon() end
	end
end)
scanSoon()
table.insert(conns, game.ServerStorage.Signals:WaitForChild("RoomRemoved").Event:Connect(function(m)
	for id, room in pairs(rooms) do
		if room.model == m then
			if room.showerHead then room.showerHead:Destroy() end
			rooms[id] = nil
		end
	end
	task.defer(function() if running then syncAll() end end)
end))

-- a room bought in build mode (BuildServer builds it, then fires this)
table.insert(conns, game.ServerStorage.Signals:WaitForChild("RoomAdded").Event:Connect(function(m)
	if not m:IsDescendantOf(HOTEL) or rooms[m:GetAttribute("RoomId")] then return end
	local room = addRoom(m)
	setRoomState(room, furnished(room) and "Ready" or "Unfurnished")
	syncAll()
end))

-- a nicer lobby: guests wait longer and arrive sooner
local function parkingSpots()
	local n = 0
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Item") == "ParkingSpot" then n += 1 end
	end
	return n
end
local function patience(g) return C.PATIENCE * (1 + lobbyAppeal / 40) * Research.mul(HOTEL, "patience") * (g and g.patienceK or 1) end
-- a better star rating brings guests sooner too
local function arrivalGap()
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	-- round 10e: parking brings drivers in (up to +30%)
	local park = math.min(10, parkingSpots()) * 0.03
	-- round 10e: busier in the evening, quiet in the small hours
	local h = Clock.now()
	local busy = (h >= 17 and h < 22) and 1.25 or ((h >= 0.5 and h < 5.8) and 0.55 or 1)
	local Grades = require(RS.Shared.Grades)
	-- round 19: the season sets the mood -- busy summer, quiet winter
	local season = Clock.seasonData()
	return range(C.ARRIVE_EVERY) / (1 + lobbyAppeal / 60) / (1 + (stars - 1) * C.STAR_ARRIVALS) / (1 + park) / busy / Grades.arrivalMul(Grades.of(HOTEL)) / Research.mul(HOTEL, "arrivals") / season.demand
end

local evCtx -- guest events' view of this hotel (set before guestLife)
-- the room a guest gets: the lowest free number, or for an event guest the first that has what they need
-- round 10e: how many a room's bed sleeps (Catalog `sleeps`)
local function bedSleeps(room)
	local b = room and room.model and core(room, "Bed")
	local it = b and Catalog.ITEMS[b:GetAttribute("Item") or ""]
	return it and it.sleeps or 1
end
local function freeRoom(g)
	local ids = {}
	for id, r in pairs(rooms) do if r.state == "Ready" then table.insert(ids, id) end end
	table.sort(ids)
	-- a couple takes a room with a bed for two when there is one
	if g and g.buddy then
		for _, id in ipairs(ids) do
			if bedSleeps(rooms[id]) >= 2 then return rooms[id] end
		end
	end
	if g and evCtx and #ids > 1 then
		local ready = {}
		for _, id in ipairs(ids) do table.insert(ready, rooms[id]) end
		return GuestEvents.pickRoom(evCtx, g.event, ready)
	end
	return ids[1] and rooms[ids[1]]
end

---------------------------------------------------------------- guest bodies (shared builder in ServerStorage.Bodies)

local Bodies = require(game.ServerStorage:WaitForChild("Bodies"))
local function makeBody(name, desc)
	return Bodies.make(name, C.WALK_SPEED, nil, desc)
end

---------------------------------------------------------------- status bubble (round 10c: drawn by the clients)
-- The server only publishes what the bubble says, as attributes on the model (tag Bubble); every client
-- draws its own (Bubbles): BName, BRole/BRoleColor (staff), BIcon, BText, BBar (a colour, "patience" or nil),
-- BT0 + BSecs + BDrain (a timed bar the clients animate from the server clock), BEvent (an event's icon),
-- Say + SaySecs + SayN (a line of speech; SayN counts up so the same line twice still shows) and SayMode
-- ("think" = an inner thought, drawn as a cloud; anything else = out loud, a speech box).

local CollectionService = game:GetService("CollectionService")

local function makeBubble(g)
	g.model:SetAttribute("BName", g.name)
	CollectionService:AddTag(g.model, "Bubble")
	g.ui = true
end

local BUBBLE_ATTRS = { "BName", "BRole", "BRoleColor", "BIcon", "BIconHold", "BWhat", "BText", "BBar", "BT0", "BSecs", "BDrain", "BEvent", "Say", "SaySecs", "SayN", "SayMode" }
local function clearBubble(g)
	g.ui = nil
	if not g.model then return end
	CollectionService:RemoveTag(g.model, "Bubble")
	for _, k in ipairs(BUBBLE_ATTRS) do g.model:SetAttribute(k, nil) end
end

-- round 10e: no more action labels over heads. What someone is doing now comes out, now and then, as a
-- thought in their speech bubble ("I should take a shower."); often they say nothing. The icon disc only
-- shows while a timer runs (patience outside, a job in progress).
local THOUGHTS = {
	["Shower"] = { "I should take a shower.", "Shower time.", "I could use a hot shower." },
	["Toilet"] = { "I should use the bathroom.", "Where's the loo..." },
	["Bathroom"] = { "I should use the bathroom.", "Be right back." },
	["Bedtime"] = { "I should get some sleep.", "So tired...", "Time for bed." },
	["Checking in"] = { "I should check in.", "Let's get my key." },
	["Checking out"] = { "I should check out.", "Time to settle up." },
	["Paying"] = { "I should pay for my stay." },
	["Heading out"] = { "I should go see the town.", "Let's go explore outside." },
	["Out for a walk"] = { "I should stretch my legs." },
	["Getting something to eat"] = { "I should get something to eat.", "I'm starving." },
	["Midnight snack"] = { "I should grab a snack.", "Just a little something..." },
	["Finding a seat"] = { "I should sit down for a bit.", "My feet hurt." },
	["Finding a table"] = { "I should find a table." },
	["Eating"] = { "Mmm, this is good." },
	["Exploring"] = { "I should look around.", "Wonder what's over there." },
	["Enjoying the lobby"] = { "Nice place.", "I should hang out here a bit." },
	["Going home"] = { "I should head home.", "Back to real life..." },
	["Unpacking"] = { "I should unpack.", "Where do I put all this?" },
	["Stretching"] = { "I should stretch." },
	["Taking photos"] = { "I should get a photo of this." },
	["On the phone"] = { "I should call home." },
	["Chatting"] = {},
	["Dancing"] = { "I love this song!" },
	["Arriving"] = { "So this is the place." },
	["At the desk"] = { "I should get checked in." },
	["Waiting for work"] = { "I should find something to do.", "Quiet day." },
	["No clean rooms"] = { "I should wait for a clean room." },
}
local lastThought = {}
local function think(g, text)
	if not text or text == "" or not g.model then return end
	local now = os.clock()
	if now - (lastThought[g] or 0) < 9 or rng:NextNumber() > 0.45 then return end
	local list = THOUGHTS[text]
	-- round 18: their own voice first (Voice), the plain thoughts only as a fallback
	local line = Life.Voice and Life.Voice.thought(g.model, text)
	if line then
	elseif list then
		line = #list > 0 and list[rng:NextInteger(1, #list)] or nil
	else
		-- "Cleaning room 102" -> "I should start cleaning room 102."
		local first = text:match("^(%a+)")
		if first and first:sub(-3) == "ing" and not text:find("^Waiting") and not text:find("^Leaving") then
			line = "I should start " .. text:sub(1, 1):lower() .. text:sub(2) .. "."
		end
	end
	if not line then return end
	lastThought[g] = now
	local m = g.model
	m:SetAttribute("SayMode", "think")
	m:SetAttribute("SaySecs", 2.6)
	m:SetAttribute("Say", line)
	m:SetAttribute("SayN", (m:GetAttribute("SayN") or 0) + 1)
end

local function status(g, icon, text, color)
	if not g.ui then return end
	local m = g.model
	if m:GetAttribute("BWhat") ~= text then think(g, text) end
	m:SetAttribute("BWhat", text)
	m:SetAttribute("BIconHold", icon)
	m:SetAttribute("BIcon", nil)
	m:SetAttribute("BText", nil)
	m:SetAttribute("BBar", color)
	m:SetAttribute("BT0", nil)
	m:SetAttribute("BSecs", nil)
	m:SetAttribute("BDrain", nil)
end

-- start the bubble's bar: it fills over `secs` (or drains when `drain`); "patience" colours it by what's left
local function barTimer(g, secs, drain, patience, elapsed)
	if not g.ui then return end
	local m = g.model
	m:SetAttribute("BIcon", m:GetAttribute("BIconHold") or "walk")
	if patience then m:SetAttribute("BBar", "patience") end
	m:SetAttribute("BSecs", secs)
	m:SetAttribute("BDrain", drain == true)
	m:SetAttribute("BT0", workspace:GetServerTimeNow() - (elapsed or 0))
end

-- fills the bar over `secs` (or drains when `drain`); returns when done
local function timed(g, secs, drain)
	barTimer(g, secs, drain)
	local t0 = os.clock()
	while g.alive do
		if os.clock() - t0 >= secs then break end
		task.wait(0.1)
	end
end

local function say(g, line, secs, mode)
	if not g.ui or not line then return end
	local m = g.model
	if Life.Voice and mode ~= "think" then line = Life.Voice.flavor(m, line) end
	m:SetAttribute("SayMode", mode == "think" and "think" or nil)
	m:SetAttribute("SaySecs", secs or 3)
	m:SetAttribute("Say", line)
	m:SetAttribute("SayN", (m:GetAttribute("SayN") or 0) + 1)
end

-- round 18: voices (ServerStorage.Voice) and the chatter that goes on by itself
do
	Life.Voice = Life.Voice or require(game.ServerStorage:WaitForChild("Voice"))
	Life.Voice.start(GUESTS, function(m, line, secs, mode)
		m:SetAttribute("SayMode", mode == "think" and "think" or nil)
		m:SetAttribute("SaySecs", secs or 3)
		m:SetAttribute("Say", line)
		m:SetAttribute("SayN", (m:GetAttribute("SayN") or 0) + 1)
	end, function() return workspace:GetAttribute("Weather") end)
end

---------------------------------------------------------------- mood + reviews (round 10c)
-- Every guest has a mood (0..100, model attribute Mood). Things that happen to them nudge it and leave a note
-- (what they'd say about it, and how it reads in a review). At check-out the mood becomes a 1-5 star review
-- led by their strongest note; it feeds the hotel rating and scales the tip.

local function moodWord(m)
	for _, w in ipairs(C.MOOD_WORDS) do
		if m >= w[1] then return w[2] end
	end
	return "Okay"
end

local function moodShift(g, d, say_, review)
	if d < 0 and g.gtype and g.gtype.touchy then d = d * g.gtype.touchy end -- round 14: some guests take things harder
	g.mood = math.clamp((g.mood or 65) + d, 0, 100)
	if g.model then g.model:SetAttribute("Mood", math.floor(g.mood + 0.5)) end
	if say_ or review then
		table.insert(g.notes, { d = d, say = say_, review = review })
	end
end

local function starsFrom(g)
	return math.clamp(math.floor((g.mood or 65) / 20 + 0.5), 1, 5)
end

-- the strongest note in the direction the guest leans (good notes for a happy guest, bad for an unhappy one)
local function topNote(g, field)
	local best
	local happy = (g.mood or 65) >= 60
	for _, n in ipairs(g.notes) do
		if n[field] and ((happy and n.d > 0) or (not happy and n.d < 0)) then
			if not best or math.abs(n.d) > math.abs(best.d) then best = n end
		end
	end
	return best
end

local function reviewText(g)
	local stars = starsFrom(g)
	local open = pick(C.REVIEW_OPEN[stars])
	local n = topNote(g, "review")
	return n and (open .. " " .. n.review) or open, stars
end

---------------------------------------------------------------- animation

local function loadAnims(g)
	local animator = g.hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", g.hum)
	g.tracks = {}
	for k, id in pairs(C.ANIM) do
		local a = Instance.new("Animation")
		-- each body has its own walk style (Bodies / Shared.Looks)
		if k == "walk" then id = g.model:GetAttribute("WalkAnim") or id end
		if k == "idle" then id = g.model:GetAttribute("IdleAnim") or id end
		a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then g.tracks[k] = tr end
	end
	for _, k in ipairs({ "walk", "run" }) do
		if g.tracks[k] then
			g.tracks[k].Priority = Enum.AnimationPriority.Movement
			g.tracks[k].Looped = true
		end
	end
	if g.tracks.sit then g.tracks.sit.Priority = Enum.AnimationPriority.Action; g.tracks.sit.Looped = true end
	if g.tracks.idle then g.tracks.idle.Looped = true; g.tracks.idle:Play(0.1) end
	if g.runConn then g.runConn:Disconnect() end
	g.runConn = g.hum.Running:Connect(function(speed)
		local w, r = g.tracks.walk, g.tracks.run
		if not w then return end
		if speed > 0.5 then
			-- moving: keep (or start) the default walk and run tracks, blended by speed like Roblox's Animate
			g.lastRun = os.clock()
			if not w.IsPlaying and not g.posed then
				w:Play(0.2)
				if r then r:Play(0.2) end
			end
			local ww, rw, ws, rs = Looks.moveBlend(speed)
			w:AdjustWeight(ww, 0.15)
			w:AdjustSpeed(ws)
			if r then
				r:AdjustWeight(rw, 0.15)
				r:AdjustSpeed(rs)
			end
		elseif w.IsPlaying then
			-- brief speed dips (waypoint hand-offs, deceleration) must NOT cut the
			-- animation mid-stride; only stop if the NPC stays slow for a moment
			local id = (g.stopId or 0) + 1
			g.stopId = id
			task.delay(0.3, function()
				if g.stopId == id and w.IsPlaying and not g.posed
					and os.clock() - (g.lastRun or 0) >= 0.3 then
					w:Stop(0.2)
					if r then r:Stop(0.2) end
				end
			end)
		end
	end)
end

-- round 14: names without a track are hand-keyed motions from Shared.NPCAnimLib, played by every client:
-- "@pose" sets the looping activity (model attribute Pose), anything else is a one-shot gesture (Act).
local function play(g, name, fade)
	local t = g.tracks and g.tracks[name]
	if t then t:Play(fade or 0.25) return t end
	if g.model then
		if string.sub(name, 1, 1) == "@" then
			g.model:SetAttribute("Pose", string.sub(name, 2))
		else
			g.actN = (g.actN or 0) + 1
			g.model:SetAttribute("Act", name .. ":" .. g.actN)
		end
	end
	return nil
end

local function stop(g, name, fade)
	local t = g.tracks and g.tracks[name]
	if t and t.IsPlaying then t:Stop(fade or 0.25) end
	if g.model and string.sub(name, 1, 1) == "@" then
		local cur = g.model:GetAttribute("Pose")
		if name == "@" or cur == string.sub(name, 2) then g.model:SetAttribute("Pose", nil) end
	end
end

-- round 15: how a line feels (model attribute Feel = "feel:n": the face on every client) and the gesture with it
-- (act false = the caller played its own)
local feelN = 0
local function feelUp(g, feel, act)
	if not g.model or not feel then return end
	feelN += 1
	g.model:SetAttribute("Feel", feel .. ":" .. feelN)
	if act ~= false and not g.posed then play(g, act or Conv.actFor(evCtx, feel)) end
end

---------------------------------------------------------------- walking

local function faceTo(g, look)
	if not look then return end
	local p = g.root.Position
	local dir = flat(look - p)
	if dir.Magnitude < 0.05 then return end
	g.root.CFrame = CFrame.lookAt(p, p + dir)
end

-- round 15: while someone talks to them they keep turning to face that player (smoothly), whatever their
-- routine was doing (queue shuffles, desk work); ends with the talk (bye / leave / 40 s quiet)
local function holdFace(g, player)
	if g.faceHold then return end
	g.faceHold = true
	task.spawn(function()
		while g.alive and g.talkUntil and os.clock() < g.talkUntil and g.talkPlayer == player do
			local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not pr or not g.root or not g.root.Parent then break end
			if not g.posed then
				local p = g.root.Position
				local dir = flat(pr.Position - p)
				if dir.Magnitude > 0.05 and dir.Magnitude < 20 then
					local want = CFrame.lookAt(p, p + dir)
					if want.LookVector:Dot(g.root.CFrame.LookVector) < 0.999 then
						g.root.CFrame = g.root.CFrame:Lerp(want, 0.35)
					end
				end
			end
			task.wait(0.1)
		end
		g.faceHold = nil
	end)
end

-- turn on the spot to face a direction over a moment (no snapping), eased; with `to`, also ease the last
-- stud or so onto that exact spot (the Humanoid stops short and twists about if made to walk that last bit)
local function turnTo(g, dir, to)
	dir = flat(dir)
	if dir.Magnitude < 0.05 or not g.alive or g.posed then return end
	if g.talkUntil and os.clock() < g.talkUntil then return end -- facing whoever they're talking to
	local p0 = g.root.Position
	local slide = to and Vector3.new(to.X - p0.X, 0, to.Z - p0.Z) or Vector3.zero
	if slide.Magnitude > 2 then slide = slide.Unit * 2 end
	local look = g.root.CFrame.LookVector
	local a0 = math.atan2(-look.X, -look.Z)
	local a1 = math.atan2(-dir.X, -dir.Z)
	local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
	if math.abs(d) < math.rad(4) and slide.Magnitude < 0.1 then return end
	local secs = math.clamp(math.max(math.abs(d) / math.pi * 0.5, slide.Magnitude * 0.3), 0.15, 0.55)
	local t0 = os.clock()
	while g.alive and not g.posed do
		local k = math.min(1, (os.clock() - t0) / secs)
		local e = k * k * (3 - 2 * k)
		local y = g.root.Position.Y
		g.root.CFrame = CFrame.new(p0.X + slide.X * e, y, p0.Z + slide.Z * e) * CFrame.Angles(0, a0 + d * e, 0)
		if k >= 1 then break end
		task.wait()
	end
end

local function settle(g, target, timeout, tol)
	-- final approach: MoveTo decelerates into the exact spot, so the NPC glides to a
	-- stop instead of lurching past it (hum:Move steering never decelerates on its own)
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < (timeout or 6) do
		local offset = flat(target - g.root.Position)
		if offset.Magnitude <= (tol or 1.2) then
			g.hum:Move(Vector3.zero)
			return true
		end
		g.hum:MoveTo(target)
		task.wait(0.1)
	end
	g.hum:Move(Vector3.zero)
	return flat(g.root.Position - target).Magnitude <= 2.5
end

-- round 10: walking runs on Nav's grid (see that module). A walker steers at a point a little way ahead
-- on its path, which rounds corners smoothly, then glides into the last point. A watchdog nudges anyone who
-- stops making progress, and after three plans that fail the walker is simply put at its spot.
local grid = Nav.new(HOTEL, O)
local navQueued = false
local function navDirty()
	if navQueued then return end
	navQueued = true
	task.delay(0.6, function()
		navQueued = false
		if running then grid:rebuild() end
	end)
end
task.spawn(function() grid:rebuild() end)
table.insert(conns, ItemsChanged.Event:Connect(navDirty))
table.insert(conns, game.ServerStorage.Signals:WaitForChild("RoomAdded").Event:Connect(navDirty))

local LOOK = 2.4 -- studs ahead along the path that a walker aims at

-- false if the walker is knocked off its path or keeps getting stuck (the caller plans again)
local SEP_R = 2.4 -- how far apart walkers try to stay from each other
local function follow(g, pts, tol)
	local n = #pts
	local seg = 1
	local lastPos, lastMove, nudges = g.root.Position, os.clock(), 0
	local sepAt, sepNear = 0, {} -- nearby walkers, rescanned a few times a second
	while g.alive and not g.posed do
		-- round 10e: someone's talking to them: stop, face them, and carry on once they're done
		if g.talkUntil and os.clock() < g.talkUntil then
			g.hum:Move(Vector3.zero)
			while g.alive and g.talkUntil and os.clock() < g.talkUntil do
				local pr = g.talkPlayer and g.talkPlayer.Character and g.talkPlayer.Character:FindFirstChild("HumanoidRootPart")
				if not pr or flat(pr.Position - g.root.Position).Magnitude > 16 then break end
				faceTo(g, pr.Position)
				task.wait(0.25)
			end
			g.talkUntil, g.talkPlayer = nil, nil
			lastPos, lastMove = g.root.Position, os.clock()
		end
		local pos = g.root.Position
		-- the closest point on the current leg; move on to the next leg once this one is passed
		local a, b, t
		while true do
			a, b = pts[seg], pts[seg + 1]
			local ab = flat(b - a)
			local len2 = ab:Dot(ab)
			t = len2 > 1e-4 and math.clamp(flat(pos - a):Dot(ab) / len2, 0, 1) or 1
			if seg < n - 1 and (t >= 0.999 or flat(b - pos).Magnitude < 1.2) then seg += 1 else break end
		end
		local proj = a + (b - a) * t
		if flat(pos - proj).Magnitude > 6 then g.hum:Move(Vector3.zero) return false end
		local last = pts[n]
		if seg == n - 1 and flat(last - pos).Magnitude < LOOK + 0.6 then
			return settle(g, last, 5, tol)
		end
		-- the carrot: LOOK studs further along the path from the closest point
		local left, from, k = LOOK, proj, seg
		local carrot = b
		while true do
			local to = pts[k + 1]
			local leg = flat(to - from)
			local d = leg.Magnitude
			if d >= left then carrot = from + leg.Unit * left break end
			left -= d
			if k + 1 >= n then carrot = to break end
			from, k = to, k + 1
		end
		local dir = flat(carrot - pos)
		-- round 16: steer apart from nearby walkers, so guests and staff spread out
		-- instead of walking through each other (off within 3 studs of the destination,
		-- so queue spots and poses still land exactly where they should)
		-- round 18: real avoidance. Each walker predicts where the people round it (guests, staff and players)
		-- will be over the next second and a half and sidesteps early, keeping right like people do; someone
		-- coming straight at them makes them ease off; a near miss that still touches is a bump (Voice.bump)
		if os.clock() - sepAt > 0.2 then
			sepAt = os.clock()
			table.clear(sepNear)
			for _, m in ipairs(GUESTS:GetChildren()) do
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and r ~= g.root and flat(r.Position - pos).Magnitude < 12 then table.insert(sepNear, r) end
			end
			for _, pl in ipairs(Players:GetPlayers()) do
				local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if r and flat(r.Position - pos).Magnitude < 12 then table.insert(sepNear, r) end
			end
		end
		local move = dir.Magnitude > 0.05 and dir.Unit or Vector3.zero
		local pace = 1
		if move.Magnitude > 0 and flat(pts[n] - pos).Magnitude > 2.5 then
			local myV = move * g.hum.WalkSpeed
			local right = Vector3.new(-move.Z, 0, move.X)
			local steer = Vector3.zero
			for _, r in ipairs(sepNear) do
				if r.Parent and math.abs(r.Position.Y - pos.Y) < 4 then
					local rel = flat(r.Position - pos)
					local d = rel.Magnitude
					if d > 0.01 and d < 10 then
						if d < SEP_R then steer -= rel.Unit * (1 - d / SEP_R) * 1.1 end
						local relV = flat(r.AssemblyLinearVelocity) - myV
						local vv = relV:Dot(relV)
						local tc = vv > 0.01 and math.clamp(-rel:Dot(relV) / vv, 0, 1.5) or 0
						local close = rel + relV * tc
						if tc > 0.05 and close.Magnitude < 2.4 then
							local side = close:Dot(right)
							local s = (math.abs(side) < 0.35) and -1 or (side > 0 and -1 or 1)
							steer += right * s * (1 - close.Magnitude / 2.4) * (1.7 - tc)
							if rel.Unit:Dot(move) > 0.75 and d < 4.5 then pace = math.min(pace, 0.55) end
						end
						if d < 1.7 and rel.Unit:Dot(move) > 0.35 and Life.Voice then
							Life.Voice.bump(g.model, r.Parent)
						end
					end
				end
			end
			if steer.Magnitude > 0.05 then move = (move + steer).Unit end
		end
		if move.Magnitude > 0.05 then g.hum:Move(move * pace) end
		-- watchdog
		if flat(pos - lastPos).Magnitude > 0.5 then
			lastPos, lastMove = pos, os.clock()
		elseif os.clock() - lastMove > 1 then
			nudges += 1
			if nudges > 3 or dir.Magnitude < 0.05 then g.hum:Move(Vector3.zero) return false end
			g.root.CFrame = g.root.CFrame + dir.Unit * math.min(1.5, dir.Magnitude)
			lastPos, lastMove = g.root.Position, os.clock()
		end
		task.wait(0.05)
	end
	g.hum:Move(Vector3.zero)
	return false
end

local function walkTo(g, target, tol)
	if typeof(target) == "Instance" then target = target.Position end
	if not g.alive then return end
	for _ = 1, 3 do
		if not g.alive or g.posed then return end
		local pts = grid:path(g.root.Position, target) or { g.root.Position, target }
		if follow(g, pts, tol) then return end
	end
	-- still not there: put them there rather than leave anyone stuck
	if g.alive and not g.posed and flat(g.root.Position - target).Magnitude > 3 then
		g.root.CFrame = CFrame.new(target) * g.root.CFrame.Rotation
	end
	g.hum:Move(Vector3.zero)
end

-- walk to a spot, then ease onto it while turning to its Look (no stop, shuffle and snap)
local function goSpot(g, spot)
	local p = spot.Position
	walkTo(g, p, 1.3)
	if not g.alive or g.posed then return end
	local look = spot:GetAttribute("Look")
	turnTo(g, look and (look - p) or g.root.CFrame.LookVector, p)
end

-- pin the root to a CFrame for a pose (sleep, toilet); restore with unpose
local function pose(g, cf)
	g.posed = true
	if g.talkPrompt then g.talkPrompt.Enabled = false end
	stop(g, "walk", 0.1)
	stop(g, "run", 0.1)
	g.root.Anchored = true
	g.root.CFrame = cf
end

local function unpose(g, standCF)
	g.root.CFrame = standCF
	g.root.Anchored = false
	g.posed = false
	if g.talkPrompt then g.talkPrompt.Enabled = true end
end

---------------------------------------------------------------- queue + guests

local queue = {} -- guests waiting outside, in order
local guests = {}
local doorPrompt
local letIn -- forward (the front door)

-- desk lines: one queue for check-in and one for check-out so guests take
-- turns at the reception desk instead of phasing into each other
local deskLines = { ["in"] = {}, out = {} }

local function deskRemove(g)
	for _, line in pairs(deskLines) do
		local i = table.find(line, g)
		if i then table.remove(line, i) end
	end
end

local function queueSlot(g)
	for i, q in ipairs(queue) do if q == g then return i end end
end

-- the line outside (round 10c): one straight file up the front path, everyone facing the door. A guest walks
-- straight into their place (no stop-and-shuffle), turns smoothly to the door, and steps back in if bumped.
local function queueGo(g, slot)
	if not (slot and g.alive) or g.room then return end
	local q1 = NAV.Queue1.Position
	local p = Vector3.new(O.X, q1.Y, q1.Z + (slot - 1) * C.QUEUE_GAP)
	local face = Vector3.new(0, 0, -1)
	local d = flat(p - g.root.Position).Magnitude
	if d > 1.3 then
		if d > 12 then walkTo(g, p, 1.3) end
		-- the last stretch: straight in
		local t1, last, lastT = os.clock(), g.root.Position, os.clock()
		while g.alive and not g.room and g.slot == slot and os.clock() - t1 < 8 do
			if flat(p - g.root.Position).Magnitude <= 1.3 then break end
			g.hum:MoveTo(p)
			if flat(g.root.Position - last).Magnitude > 0.3 then
				last, lastT = g.root.Position, os.clock()
			elseif os.clock() - lastT > 1.5 then
				walkTo(g, p, 1.3) -- something's in the way: path round it
				break
			end
			task.wait(0.1)
		end
		g.hum:Move(Vector3.zero)
	end
	-- ease onto the spot while turning to the door
	if g.alive and not g.room and g.slot == slot then turnTo(g, face, p) end
end

local function refreshQueue()
	for i, q in ipairs(queue) do
		q.slot = i
	end
	local n = #queue
	HOTEL:SetAttribute("Waiting", n)
	if doorPrompt then
		doorPrompt.Enabled = n > 0
		doorPrompt.ObjectText = "New Guests (" .. n .. ")"
		doorPrompt.ActionText = freeRoom() and "Let In" or "No clean rooms"
	end
end

local parkCar
do
-- round 10e: guests who drive park in a free ParkingSpot for their stay (a car from the street's
-- parked set, turned to fit the bay) and drive off when they leave
local parkedCars = {} -- spot model -> car
parkCar = function(g)
	if g.car or rng:NextNumber() > 0.7 then return end
	local src = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Parked")
	local cars = src and src:GetChildren() or {}
	if #cars == 0 then return end
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Item") == "ParkingSpot" and not (parkedCars[m] and parkedCars[m].Parent) then
			local car = cars[rng:NextInteger(1, #cars)]:Clone()
			for _, d in ipairs(car:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true; d.CanQuery = false end
			end
			-- round 29: street cars are bigger than a bay; a guest's car is scaled to sit inside the lines
			local _, csz = car:GetBoundingBox()
			local k = math.min(1, 14.6 / math.max(csz.X, csz.Z), 6.4 / math.min(csz.X, csz.Z))
			if k < 0.99 then car:ScaleTo(k) end
			local flip = rng:NextNumber() < 0.5 and math.pi or 0
			car:PivotTo(m:GetPivot() * CFrame.Angles(0, math.pi / 2 + flip, 0))
			car.Name = "GuestCar"
			car.Parent = m
			parkedCars[m] = car
			g.car = car
			return
		end
	end
end
end

local function despawn(g)
	g.alive = false
	if g.car then g.car:Destroy(); g.car = nil end
	if g.bag then g.bag.model:Destroy(); g.bag = nil end
	if g.buddy then g.buddy.model:Destroy(); g.buddy = nil end
	guests[g] = nil
	deskRemove(g)
	local i = queueSlot(g)
	if i then table.remove(queue, i); refreshQueue() end
	if g.model then g.model:Destroy() end
end

---------------------------------------------------------------- the desk line (check-in / check-out queue at the reception desk)

local function deskSpot(kind)
	return kind == "in" and NAV.DeskGuest or NAV.DeskGuest2
end

-- where the i-th guest in a desk line stands (1 is at the desk itself, the rest line up behind it)
local function deskLineSpot(kind, i)
	local front = deskSpot(kind)
	local look = front:GetAttribute("Look")
	local back = look and flat(front.Position - look) or Vector3.new(0, 0, 1)
	if back.Magnitude < 0.1 then back = Vector3.new(0, 0, 1) end
	return front.Position + back.Unit * (i - 1) * 2.4, look
end

-- join a desk line and wait for the front; returns true once g stands at the desk
local function deskWait(g, kind)
	local line = deskLines[kind]
	table.insert(line, g)
	local t0 = os.clock()
	local lastIdx
	while g.alive do
		local i = table.find(line, g)
		if not i then return false end
		if i == 1 then break end
		if i ~= lastIdx then
			lastIdx = i
			local p, look = deskLineSpot(kind, i)
			walkTo(g, p, 1.3)
			if g.alive and not g.posed then turnTo(g, look and (look - p) or g.root.CFrame.LookVector, p) end
		end
		if os.clock() - t0 > patience(g) then
			table.remove(line, i)
			return false
		end
		task.wait(0.15)
	end
	if not g.alive then deskRemove(g); return false end
	goSpot(g, deskSpot(kind))
	return true
end

-- serve a guest at the desk: a receptionist handles it automatically, but with no
-- receptionist the player has to interact with the guest to check them in or out
local deskService
do
local function serve(g, secs, action)
	-- round 13: receptionists on shift take their time (C.CLERK_SLOW); levels, research, their focus and every
	-- extra receptionist speed the desk up (evCtx.deskPace). Nobody on shift: the player serves the desk
	local dp = evCtx and evCtx.deskPace and evCtx.deskPace(action)
	if dp and evCtx.serveDesk then
		-- round 14: each receptionist serves one guest at a time; the rest wait their turn
		local r = evCtx.serveDesk(g, secs, action)
		if r ~= nil then return r end
	elseif dp then
		timed(g, secs * C.CLERK_SLOW * dp)
		return g.alive
	end
	local waitText = action == "Check In" and "Waiting to check in" or "Waiting to pay"
	status(g, "bell", waitText, "yellow")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeskService"
	prompt.ActionText = action
	prompt.ObjectText = g.name
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.25
	prompt:SetAttribute("Icon", action == "Check In" and "bell" or "cash")
	prompt:SetAttribute("Color", "yellow")
	prompt.MaxActivationDistance = 12
	CollectionService:AddTag(prompt, "DeskPrompt") -- clients show it only while sitting at a desk
	prompt.Parent = g.root
	local served, playing = false, false
	barTimer(g, patience(g), true, true)
	local t0 = os.clock()
	-- pressing it opens the desk minigame on that player's screen; patience pauses meanwhile
	prompt.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player); return end
		if playing or served or deskGames[player] or cleaning[player] then return end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local sp = hum and hum.SeatPart
		if not (sp and sp.Name == "DeskSeat" and sp:IsDescendantOf(HOTEL)) then
			Notify:FireClient(player, "toast", { text = "Sit at the front desk to serve guests", icon = "bell", bad = true })
			return
		end
		playing = true
		prompt.Enabled = false
		prompt:SetAttribute("Busy", true)
		status(g, "bell", action == "Check In" and "Checking in" or "Paying", "green")
		local room = g.room
		local data = { task = action == "Check In" and "CheckIn" or "CheckOut", guest = g.name, room = room and room.id }
		if data.task == "CheckIn" then
			local names = { g.name }
			for _ = 1, 40 do
				if #names >= 5 then break end
				local n = pick(C.NAMES)
				if not table.find(names, n) then table.insert(names, n) end
			end
			data.names = names
			data.keys = {}
			for id in pairs(rooms) do table.insert(data.keys, id) end
			data.nights = rng:NextInteger(1, 4)
		else
			local bill = room and room.model and room.model:GetAttribute("Price") or C.ROOM_PRICE
			local paid = math.ceil((bill + 2) / 20) * 20
			if paid - bill < 3 then paid += 20 end
			data.bill, data.paid = bill, paid
		end
		local session = { t0 = os.clock() }
		session.done = function(ok, stars)
			playing = false
			if not g.alive then return end
			if ok then
				served = true
				g.deskStars = stars
			else
				if prompt.Parent then prompt.Enabled = true; prompt:SetAttribute("Busy", nil) end
				status(g, "bell", waitText, "yellow")
				barTimer(g, patience(g), true, true, os.clock() - t0)
			end
		end
		deskGames[player] = session
		Notify:FireClient(player, "minigame", data)
		task.delay(C.MINIGAME_TIMEOUT, function()
			if deskGames[player] == session then
				deskGames[player] = nil
				session.done(false, 0)
				Notify:FireClient(player, "minigameEnd")
			end
		end)
	end)
	local last = os.clock()
	while g.alive and not served do
		local now = os.clock()
		if playing then t0 += now - last end
		last = now
		-- a receptionist was hired while they waited: they take over
		if not playing and (HOTEL:GetAttribute("Receptionists") or 0) > 0 then
			prompt:Destroy()
			timed(g, secs)
			return g.alive
		end
		local k = 1 - (now - t0) / patience(g)
		if k <= 0 then break end
		task.wait(0.1)
	end
	prompt:Destroy()
	if served and g.alive then
		status(g, "bell", action == "Check In" and "Checked in" or "Paid", "green")
		task.wait(0.5)
		return true
	end
	return false
end
-- round 30: while served the guest has their hands on the nearest desk's counter (check-in) or slides a card
-- over it (check-out); Shared.NPCAnimLib `counter` / `pay`, through the round 27 WorkAt contract
deskService = function(g, secs, action)
	local desk, bd
	for _, d in ipairs(Build.desks(HOTEL)) do
		local dd = flat(d:GetPivot().Position - g.root.Position).Magnitude
		if dd < 7 and (not bd or dd < bd) then desk, bd = d, dd end
	end
	local pn = action == "Check In" and "@counter" or "@pay"
	-- inset -0.05: the guest ledge overhangs the lower panel the ray hits, so this lands mid-ledge
	local on = desk and not g.posed and evCtx.workStart(g, desk, "top", -0.05, 3.4)
	if on then play(g, pn) end
	local ok = serve(g, secs, action)
	if on then
		stop(g, pn)
		evCtx.workEnd(g)
	end
	return ok
end
end

-- put a booked room back on the market when a guest abandons it before checking in
local function releaseRoom(room)
	if not room or not room.model then return end
	room.guest = nil
	room.model:SetAttribute("Guest", nil)
	if room.state == "Booked" then
		setRoomState(room, "Ready")
		roomCounts()
		refreshQueue()
	end
end

local function leaveStreet(g)
	walkTo(g, NAV.PathStart.Position)
	if Sim.handOff and g.model and g.alive then
		-- the street crowd takes the body back: it walks off down the sidewalk
		g.alive = false
		guests[g] = nil
		deskRemove(g)
		local i = queueSlot(g)
		if i then table.remove(queue, i); refreshQueue() end
		for _, t in pairs(g.tracks or {}) do pcall(function() t:Stop(0.2) end) end
		if g.runConn then g.runConn:Disconnect() end
		clearBubble(g)
		if g.zzz then g.zzz:Destroy() end
		if g.talkPrompt then g.talkPrompt:Destroy() g.talkPrompt = nil end
		GuestEvents.undress(g)
		g.model:SetAttribute("Guest", nil)
		g.model:SetAttribute("Mood", nil)
		Sim.handOff(g.model, g.name)
		return
	end
	walkTo(g, (rng:NextNumber() < 0.5 and NAV.Street or NAV.StreetExit).Position)
	despawn(g)
end

local holdBag, giveBag, dropBag, anyDoubleRoom, addBuddy, playItem
do
---------------------------------------------------------------- luggage, couples, thoughts and fun (round 10e)
-- Most guests arrive with luggage: a rolling suitcase pulled along at their side, or a duffel in the hand.
-- It goes down by the bed for the stay and comes home with them. Couples arrive when a room with a bed for
-- two (Catalog `sleeps`) exists: the partner follows them everywhere, they get that room if it's free, and
-- they pay 60% more. Guests think out loud now and then ("I should..."), and the fun items (Catalog tag
-- "play") get played with: pinball, air hockey, karaoke, the photo booth, a treadmill run, a hot tub soak.
local PROPS = game.ServerStorage:FindFirstChild("HotelProps")
local function floorBelow(g) return g.hum.HipHeight + g.root.Size.Y / 2 end
-- round 15: eight kinds of luggage (HotelProps; model attribute Kind = roll / hand / back), picked by who they are and
-- tinted from a palette per kind. g.bag.kind stays "Suitcase" (rolled), "Duffel" (in the hand) or "Backpack" (worn)
-- so Upkeep's bag carrying keeps working.
local Lug = {}
Lug.LIST = { { "CaseSpinner", 5 }, { "CaseCarryOn", 4 }, { "Weekender", 3 }, { "Backpack", 2 }, { "CaseVintage", 1.5 }, { "Handbag", 1.5 }, { "Briefcase", 1 }, { "GuitarCase", 0.4 } }
Lug.BY = {
	business = { Briefcase = 5, CaseCarryOn = 4 }, celebrity = { CaseSpinner = 3, Handbag = 3, GuitarCase = 2 },
	honeymoon = { CaseSpinner = 3, Handbag = 2, CaseVintage = 2 }, tour = { Backpack = 5, CaseCarryOn = 2 },
	backpacker = { Backpack = 1 }, bigspender = { CaseSpinner = 3, Handbag = 2, Weekender = 1 },
	chatty = { CaseVintage = 4, Weekender = 2 }, party = { Weekender = 3, Backpack = 2, GuitarCase = 1 },
	influencer = { Handbag = 3, CaseSpinner = 3 }, baby = { Weekender = 2, CaseSpinner = 2 }, rockstar = { GuitarCase = 1 }, royal = { CaseSpinner = 1 }, critic = { Briefcase = 1 }, mystery = { Briefcase = 1 }, tycoon = { CaseSpinner = 1 },
}
Lug.COL = {
	shell = { { 34, 64, 130 }, { 190, 44, 52 }, { 30, 128, 132 }, { 200, 204, 212 }, { 140, 200, 180 }, { 226, 170, 60 }, { 40, 40, 46 }, { 232, 120, 100 }, { 110, 70, 160 }, { 236, 236, 232 }, { 70, 150, 220 } },
	canvas = { { 176, 156, 116 }, { 96, 110, 70 }, { 44, 58, 92 }, { 120, 122, 128 }, { 150, 90, 60 }, { 170, 60, 52 }, { 226, 130, 50 } },
	leather = { { 140, 80, 44 }, { 40, 32, 30 }, { 110, 36, 40 }, { 186, 130, 80 }, { 228, 214, 190 }, { 214, 130, 160 } },
	vintage = { { 232, 220, 190 }, { 150, 176, 150 }, { 150, 180, 214 }, { 214, 180, 90 }, { 180, 90, 80 } },
	guitar = { { 30, 30, 34 }, { 170, 40, 40 }, { 226, 214, 186 } },
}
Lug.PAL = { CaseSpinner = "shell", CaseCarryOn = "shell", Weekender = "canvas", Backpack = "canvas", CaseVintage = "vintage", Handbag = "leather", Briefcase = "leather", GuitarCase = "guitar" }
function Lug.pick(w)
	local tot = 0
	for _, v in pairs(w) do tot += v end
	local r = rng:NextNumber() * tot
	for k, v in pairs(w) do
		r -= v
		if r <= 0 then return k end
	end
	return next(w)
end
holdBag = function(g)
	local b = g.bag
	if not b or not g.alive then return end
	for _, p in ipairs(b.model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = false end
	end
	if b.weld then b.weld:Destroy() end
	if b.straps then
		for _, s in ipairs(b.straps) do s:Destroy() end
		b.straps = nil
	end
	local cf, carry
	local to = g.root
	if b.kind == "Suitcase" then
		-- pulled along at their right side, leaning toward the hand (NPCAnim re-poses it every frame)
		cf = g.root.CFrame * CFrame.new(1.35, -floorBelow(g), 1.1) * CFrame.Angles(math.rad(-22), 0, math.rad(-8))
		carry = "case"
	elseif b.kind == "Backpack" then
		-- worn on the back, with the straps over the front of the shoulders
		to = g.model:FindFirstChild("UpperTorso") or g.root
		local sz = to.Size
		cf = to.CFrame * CFrame.new(0, -sz.Y / 2 - 0.42 * b.k, sz.Z / 2 + 0.41 * b.k)
		b.straps = {}
		for _, sx in ipairs({ -1, 1 }) do
			local s = Instance.new("Part")
			s.Name = "PackStrap"
			s.Size = Vector3.new(0.22 * b.k, sz.Y * 0.62, 0.07)
			s.Color = Color3.fromRGB(52, 54, 60)
			s.Material = Enum.Material.Fabric
			s.CanCollide, s.CanQuery, s.CanTouch, s.Massless = false, false, false, true
			s.CastShadow = false
			local c0 = CFrame.new(sx * sz.X * 0.22, sz.Y * 0.18, -sz.Z / 2 - 0.035)
			s.CFrame = to.CFrame * c0
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = to, s, c0
			w.Parent = s
			s.Parent = g.model
			table.insert(b.straps, s)
		end
	else
		-- hanging from the hand by its handle, long side along the walk (NPCAnim swings it)
		to = g.model:FindFirstChild("RightHand") or g.model:FindFirstChild("Right Arm") or g.root
		cf = to.CFrame * CFrame.new(0, -0.1 - b.hang, 0) * CFrame.Angles(0, math.rad(90), 0)
		carry = "bag"
	end
	b.model:PivotTo(cf)
	local w = Instance.new("Weld")
	w.Part0 = to
	w.Part1 = b.base
	w.C0 = to.CFrame:ToObjectSpace(b.base.CFrame)
	w.Parent = b.base
	b.weld = w
	b.model.Parent = g.model
	g.model:SetAttribute("Carry", carry)
end
giveBag = function(g)
	if g.bag or not PROPS or rng:NextNumber() > 0.8 then return end
	local w = Lug.BY[(g.event and g.event.id) or ""] or Lug.BY[(g.gtype and g.gtype.id) or ""]
	local name = w and Lug.pick(w)
	if not name then
		local tot = 0
		for _, e in ipairs(Lug.LIST) do tot += e[2] end
		local r = rng:NextNumber() * tot
		for _, e in ipairs(Lug.LIST) do
			r -= e[2]
			if r <= 0 then name = e[1] break end
		end
	end
	local src = PROPS:FindFirstChild(name or "CaseSpinner") or PROPS:FindFirstChild("Suitcase")
	if not src then return end
	local m = src:Clone()
	m.Name = "Luggage"
	local body = m:FindFirstChild("Body")
	local pal = Lug.COL[Lug.PAL[src.Name] or "shell"]
	if body and Lug.PAL[src.Name] then
		local c = pal[rng:NextInteger(1, #pal)]
		body.Color = Color3.fromRGB(c[1], c[2], c[3])
	end
	local mk = m:GetAttribute("Kind") or (src.Name == "Suitcase" and "roll" or "hand")
	local k = 1
	if mk == "back" then
		local ut = g.model:FindFirstChild("UpperTorso")
		k = ut and math.clamp(ut.Size.X / 2, 0.55, 1.2) or 1
		if math.abs(k - 1) > 0.01 then m:ScaleTo(k) end
	end
	local _, size = m:GetBoundingBox()
	local base = body
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
			base = base or p
		end
	end
	if not base then m:Destroy() return end
	m.PrimaryPart = base -- round 11: the pivot follows the bag (a fixed WorldPivot drifted while it was carried)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= base then
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = base, p
			wc.Parent = p
		end
	end
	g.bag = {
		model = m, base = base, height = size.Y, k = k, name = src.Name,
		kind = mk == "roll" and "Suitcase" or mk == "back" and "Backpack" or "Duffel",
		hang = (m:GetAttribute("HangY") or 1.55) * k,
	}
	holdBag(g)
end
-- set it down by the bed (stays put, anchored, until they leave)
dropBag = function(g, room)
	local b = g.bag
	if not b or not room then return end
	local bed = core(room, "Bed")
	local side = bedSide(room)
	if not (bed and side) then return end
	local along = flat(bed:GetPivot().LookVector)
	local out = flat(side - bed:GetPivot().Position)
	out = out.Magnitude > 0.1 and out.Unit or Vector3.new(1, 0, 0)
	local pos = side + along * 2.2 + out * 0.6
	local y = g.root.Position.Y - floorBelow(g)
	if b.weld then b.weld:Destroy(); b.weld = nil end
	if b.straps then
		for _, s in ipairs(b.straps) do s:Destroy() end
		b.straps = nil
	end
	b.model:PivotTo(CFrame.lookAt(Vector3.new(pos.X, y, pos.Z), Vector3.new(pos.X, y, pos.Z) + out))
	for _, p in ipairs(b.model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	b.model.Parent = GUESTS
	g.model:SetAttribute("Carry", nil)
end

anyDoubleRoom = function()
	for _, r in pairs(rooms) do
		if r.model and r.model.Parent and bedSleeps(r) >= 2 then return true end
	end
	return false
end
-- a partner who follows the guest everywhere (no logic of their own)
addBuddy = function(g)
	local nm = pick(C.NAMES)
	local m = makeBody(nm)
	if not m then return end
	m:PivotTo(g.root.CFrame * CFrame.new(1.9, 0, 1.6))
	m.Parent = GUESTS
	setGroup(m, "Guests")
	local b = {
		model = m, name = nm, alive = true,
		hum = m:FindFirstChildOfClass("Humanoid"), root = m:WaitForChild("HumanoidRootPart"), head = m:WaitForChild("Head"),
	}
	m:SetAttribute("Guest", true)
	pcall(makeBubble, b)
	loadAnims(b)
	g.buddy = b
	task.spawn(function()
		local lying = false
		while g.alive and m.Parent do
			local lr = g.root
			if g.posed then
				b.hum:Move(Vector3.zero)
				if g.sleeping and not lying and g.sleepCF then
					-- into bed beside them (the other bed of a twin, the top bunk's partner below)
					lying = true
					b.root.Anchored = true
					b.root.CFrame = g.sleepCF * CFrame.new(g.sleepSide or 2.4, 0, 0)
				end
			else
				if lying then
					lying = false
					b.root.Anchored = false
					b.root.CFrame = lr.CFrame * CFrame.new(1.9, 0, 1.6)
				end
				local target = (lr.CFrame * CFrame.new(1.9, 0, 1.6)).Position
				local d = flat(target - b.root.Position).Magnitude
				if d > 18 then
					b.root.CFrame = CFrame.new(target) * lr.CFrame.Rotation
				elseif d > 1.3 then
					b.hum:MoveTo(target)
				else
					b.hum:Move(Vector3.zero)
					local p = b.root.Position
					b.root.CFrame = b.root.CFrame:Lerp(CFrame.lookAt(p, p + flat(lr.CFrame.LookVector)), 0.25)
				end
			end
			task.wait(0.15)
		end
		b.alive = false
		if m.Parent then m:Destroy() end
	end)
end

-- the fun items: how each is played
local PLAY = {
	Pinball = { anim = "point", lines = { "Come on, multiball!", "New high score!", "Tilt! Argh." } },
	AirHockey = { anim = "point", lines = { "Goal!", "You're going down!", "So close!" } },
	PhotoBooth = { anim = "cheer", lines = { "Say cheese!", "Ha, look at that one!", "Strike a pose!" } },
	KaraokeStage = { anim = "dance", lines = { "This is my song!", "La la laaa!", "Encore!", "One more song!" } },
	Treadmill = { anim = "run", on = 3.6, lines = { "Feel the burn!", "Just one more mile.", "Phew!" } },
	HotTub = { anim = "sit", on = 2.0, lines = { "Ahh, bubbles.", "I could stay here all day.", "So relaxing." } },
}
playItem = function(g, e)
	local def = PLAY[e.model:GetAttribute("Item") or ""] or { anim = "cheer", lines = { "This is fun!" } }
	local piv = e.model:GetPivot()
	local dir = flat(piv.Position - g.root.Position)
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
	local spot = Vector3.new(piv.X - dir.Unit.X * 3.2, g.root.Position.Y, piv.Z - dir.Unit.Z * 3.2)
	status(g, "happy", "Having fun")
	walkTo(g, spot)
	if not g.alive then return end
	faceTo(g, piv.Position)
	local standCF = g.root.CFrame
	if def.on then
		pose(g, CFrame.new(piv.Position + Vector3.new(0, def.on, 0)) * piv.Rotation)
	end
	local tr = play(g, def.anim, 0.2)
	if tr and def.anim ~= "point" and def.anim ~= "cheer" then tr.Looped = true end
	say(g, pick(def.lines), 2.5)
	local secs = range({ 4, 7 })
	timed(g, secs)
	if tr then tr.Looped = false; stop(g, def.anim, 0.2) end
	if def.on then unpose(g, standCF) end
	if not g.playedFun then
		g.playedFun = true
		moodShift(g, 4, "That was so much fun!", "Loads of fun things to do.")
	end
end
end

local orders, deliverOrder, hasCart, waitOrder
do
-- round 10e: room service, a job only players can do. With a Room Service Cart placed, guests sometimes
-- order: grab the tray at the cart, carry it up and knock. Quick delivery pays and pleases; after
-- ORDER_SECS the order is cancelled and the guest is cross
local ORDER_SECS = 75
orders = {} -- room -> { g, t, carrier }
local function carts()
	local list = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Item") == "ServiceCart" then table.insert(list, m) end
	end
	return list
end
local function dropTray(player)
	if not player then return end
	player:SetAttribute("Tray", nil)
	local ch = player.Character
	local t = ch and ch:FindFirstChild("Tray")
	if t then t:Destroy() end
end
local function giveTray(player, room)
	local ch = player.Character
	local hand = ch and (ch:FindFirstChild("RightHand") or ch:FindFirstChild("Right Arm"))
	if not hand then return false end
	local tray = Instance.new("Part")
	tray.Name = "Tray"
	tray.Size = Vector3.new(1.8, 0.12, 1.3)
	tray.Color = Color3.fromRGB(214, 218, 224)
	tray.Material = Enum.Material.Metal
	tray.CanCollide, tray.CanQuery, tray.CanTouch, tray.Massless = false, false, false, true
	local dome = Instance.new("Part")
	dome.Shape = Enum.PartType.Ball
	dome.Size = Vector3.new(1.2, 1.2, 1.2)
	dome.Color = Color3.fromRGB(226, 230, 236)
	dome.Material = Enum.Material.Metal
	dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.Massless = false, false, false, true
	dome.Parent = tray
	local cut = Instance.new("Part") -- the knob on top
	cut.Shape = Enum.PartType.Ball
	cut.Size = Vector3.new(0.3, 0.3, 0.3)
	cut.Color = C.ICONS and Color3.fromRGB(230, 190, 90) or Color3.new(1, 1, 1)
	cut.Material = Enum.Material.Metal
	cut.CanCollide, cut.CanQuery, cut.CanTouch, cut.Massless = false, false, false, true
	cut.Parent = tray
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = hand, tray, CFrame.new(0, -0.2, -0.9)
	w.Parent = tray
	local w2 = Instance.new("Weld")
	w2.Part0, w2.Part1, w2.C0 = tray, dome, CFrame.new(0, 0.1, 0)
	w2.Parent = dome
	local w3 = Instance.new("Weld")
	w3.Part0, w3.Part1, w3.C0 = tray, cut, CFrame.new(0, 0.72, 0)
	w3.Parent = cut
	tray.Parent = ch
	player:SetAttribute("Tray", room.id)
	return true
end
-- the cart's prompt shows while an order waits to be picked up
task.spawn(function()
	while running do
		local waiting
		for room, o in pairs(orders) do
			if not o.carrier and (not waiting or o.t < orders[waiting].t) then waiting = room end
		end
		for _, cart in ipairs(carts()) do
			local part = cart.PrimaryPart or cart:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local p = part:FindFirstChild("OrderPrompt")
				if not p then
					p = Instance.new("ProximityPrompt")
					p.Name = "OrderPrompt"
					p.ActionText = "Take Order"
					p.KeyboardKeyCode = Enum.KeyCode.F
					p.GamepadKeyCode = Enum.KeyCode.ButtonY
					p.HoldDuration = 0.4
					p.MaxActivationDistance = 9
					p.RequiresLineOfSight = false
					p.Style = Enum.ProximityPromptStyle.Custom
					p:SetAttribute("Icon", "food")
					p:SetAttribute("Color", "gold")
					p.Parent = part
					p.Triggered:Connect(function(player)
						if not isMember(player) then notMine(player) return end
						if player:GetAttribute("Tray") then return end
						local pick_
						for room, o in pairs(orders) do
							if not o.carrier and (not pick_ or o.t < orders[pick_].t) then pick_ = room end
						end
						if pick_ and giveTray(player, pick_) then
							orders[pick_].carrier = player
							Notify:FireClient(player, "toast", { text = "Take it up to room " .. pick_.id .. " and knock", icon = "food" })
						end
					end)
				end
				p.Enabled = waiting ~= nil
				p.ObjectText = waiting and ("Room " .. waiting.id) or ""
			end
		end
		task.wait(0.5)
	end
end)
deliverOrder = function(room, player)
	local o = orders[room]
	if not o then return end
	orders[room] = nil
	dropTray(player)
	local g = o.g
	local quick = os.clock() - o.t < ORDER_SECS * 0.5
	local pay = 30 + (quick and 15 or 0)
	addCash(player, pay)
	Notify:FireAllClients("paid", { pos = room.knockSpot.Position + Vector3.new(0, 3, 0), amount = pay })
	Levels.award(HOTEL, 6, "Room service", room.knockSpot.Position + Vector3.new(0, 4, 0))
	if g and g.alive then
		moodShift(g, quick and 9 or 5, quick and "Room service was so fast!" or "My food came!", quick and "Super quick room service." or "Room service was good.")
		say(g, pick({ "Thank you! Smells amazing.", "Finally, food!", "You're a lifesaver!", "Yum, thanks!" }), 3)
		g.orderDone = true
	end
	quest("serve")
end
hasCart = function() return #carts() > 0 end
waitOrder = function(g, room)
	if not hasCart() then return end
	orders[room] = { g = g, t = os.clock() }
	g.orderDone = false
	say(g, pick({ "I'll order room service!", "Room service, please!", "I'm starving. Room service!" }), 2.5)
	tell("toast", { text = "Room " .. room.id .. " ordered room service. Grab it from the cart!", icon = "food" })
	status(g, "food", "Waiting for room service", "green")
	barTimer(g, ORDER_SECS, true)
	local t0 = os.clock()
	while g.alive and not g.orderDone and os.clock() - t0 < ORDER_SECS do task.wait(0.25) end
	local o = orders[room]
	if o and o.g == g then
		orders[room] = nil
		if o.carrier then dropTray(o.carrier) end
		if g.alive then
			moodShift(g, -8, "My room service never came.", "Room service never showed up.")
			say(g, "Forget it, I'm not hungry anymore.", 3)
		end
	end
end
table.insert(conns, Players.PlayerRemoving:Connect(function(player)
	for _, o in pairs(orders) do if o.carrier == player then o.carrier = nil end end
end))
end

local function stayIn(g, room)
	local nav = room.nav
	walkTo(g, room.nav.Door.Position)
	walkTo(g, nav.Enter.Position)
	-- in: the door locks behind them, some hang a Do Not Disturb card, and they judge the room
	room.occupant = g
	room.model:SetAttribute("Occupied", true)
	parkCar(g)
	dropBag(g, room)
	if g.buddy then
		if bedSleeps(room) >= 2 then
			moodShift(g, 4, "Room for both of us!", "A perfect room for two.")
		else
			moodShift(g, -8, "One small bed for the two of us?", "One small bed for the two of us.")
		end
	end
	g.dnd = rng:NextNumber() < C.DND_CHANCE
	if g.dnd then setSign(room, "DND") end
	local rs = room.model:GetAttribute("Stars") or 1
	if rs >= 4 then
		moodShift(g, (rs - 3) * 5, "My room is beautiful!", "The room was gorgeous.")
	elseif rs <= 2 then
		moodShift(g, (rs - 3) * 5, "My room is pretty basic...", "Very basic room.")
	end
	say(g, rs >= 4 and "Wow, what a room!" or (rs <= 2 and "Hm. It's a bit plain." or pick(C.LINES.room)), 2.5)
	-- different guests do different things, in different orders, for different lengths
	local order = {}
	if rng:NextNumber() < 0.8 then table.insert(order, "Toilet") end
	if rng:NextNumber() < 0.8 then table.insert(order, "Shower") end
	if #order == 2 and rng:NextNumber() < 0.5 then order = { order[2], order[1] } end
	if rng:NextNumber() < 0.4 then table.insert(order, 1, "Wander") end
	-- out and about: a walk, a coffee, a chat in the lobby (never last thing at night)
	for _ = 1, (rng:NextNumber() < 0.55 and 1 or 0) + (rng:NextNumber() < 0.25 and 1 or 0) do
		table.insert(order, rng:NextInteger(math.min(2, #order + 1), #order + 1), "Outing")
	end
	-- round 10e: room service, when there's a cart (a player carries it up)
	if hasCart() and rng:NextNumber() < (HOTEL:GetAttribute("TestOrder") or 0.35) then table.insert(order, rng:NextInteger(1, #order + 1), "Order") end
	table.insert(order, "Bed") -- bed last: it's the "night"
	Life.orderHook(g, order) -- round 14: guest types (judge the room, wipe it down, a party, straight to bed)
	-- an event guest's own moment (night owls stay up instead of sleeping)
	if g.event then
		if g.event.noBed then table.remove(order) end
		table.insert(order, g.event.noBed and #order + 1 or #order, "Event")
	end
	for _, act in ipairs(order) do
		if not g.alive then return end
		local secs = range(C.ACTIVITY[act] or C.ACTIVITY.Wander) * (HOTEL:GetAttribute("TestLinger") or 1)
		if act == "Event" then
			g.eventMet = GuestEvents.stay(evCtx, g, room)
			if g.eventMet then
				moodShift(g, 12, "They had everything I needed!", "They had everything I needed.")
			elseif g.event.missing then
				moodShift(g, -15, "No " .. (g.event.missing:gsub("^an? ", "")) .. "? Really?", "They didn't have " .. g.event.missing .. ".")
			end
			-- an unwell guest with no first aid goes home early
			if g.event.id == "sick" and not g.eventMet then return end
		elseif Life.STAY_ACTS[act] then
			Life.STAY_ACTS[act](evCtx, g, room, secs)
		elseif (act == "Toilet" or act == "Shower") and evCtx.upkeep:brokenCore(g, room, act) then
			-- round 11: it's broken (Upkeep: they look, grumble and lose mood)
		elseif act == "Toilet" then
			status(g, "walk", "Bathroom")
			local piv = core(room, "Toilet"):GetPivot()
			local front = coreSpot(room, "Toilet", "front")
			walkTo(g, front)
			faceTo(g, piv.Position)
			status(g, "toilet", "Toilet", "blue")
			pose(g, coreSpot(room, "Toilet", "sit"))
			play(g, "sit", 0.2)
			timed(g, secs)
			stop(g, "sit", 0.2)
			-- round 30: up, turn round and push the flush
			unpose(g, CFrame.lookAt(front, front + flat(piv.Position - front)))
			local on = evCtx.workStart(g, core(room, "Toilet"), "top", 1.2, 2.6)
			if on then play(g, "@flush") task.wait(0.6) end
			sfx("flush", piv.Position)
			if on then
				task.wait(0.7)
				stop(g, "@flush")
				evCtx.workEnd(g)
			end
		elseif act == "Shower" then
			status(g, "walk", "Shower")
			local piv = core(room, "Shower"):GetPivot()
			local front = coreSpot(room, "Shower", "front")
			walkTo(g, front)
			faceTo(g, piv.Position)
			-- round 30: stood inside facing the wall (as the janitor's wipe), tap on, wash the hair, tap off
			local on = evCtx.workStart(g, core(room, "Shower"), "inside")
			if on then
				play(g, "@tap")
				task.wait(0.9)
			else
				pose(g, coreSpot(room, "Shower", "inside"))
			end
			room.water.Enabled = true
			room.steam.Enabled = true
			status(g, "shower", "Shower", "blue")
			if on then play(g, "@wash") end
			timed(g, secs)
			if on then
				play(g, "@tap")
				task.wait(0.9)
			end
			room.water.Enabled = false
			room.steam.Enabled = false
			if on then
				stop(g, "@tap")
				evCtx.workEnd(g)
			end
			unpose(g, CFrame.lookAt(front, front + flat(front - piv.Position)))
		elseif act == "Outing" then
			status(g, "walk", "Heading out")
			walkTo(g, nav.Enter.Position)
			walkTo(g, nav.Door.Position)
			if not g.alive then return end
			room.occupant = nil
			room.model:SetAttribute("Occupied", nil)
			room.model:SetAttribute("Away", true)
			setSign(room, nil)
			Life.outing(evCtx, g, "stay")
			if not g.alive then return end
			room.model:SetAttribute("Away", nil)
			status(g, "walk", "Room " .. room.id)
			walkTo(g, nav.Door.Position)
			walkTo(g, nav.Enter.Position)
			room.occupant = g
			room.model:SetAttribute("Occupied", true)
			Life.shoppingBag(g, false) -- the shopping goes down in the room
			if g.dnd then setSign(room, "DND") end
		elseif act == "Order" then
			waitOrder(g, room)
			Life.fill(g, "hunger", 60)
		elseif act == "Wander" then
			status(g, "guest", "Unpacking")
			goSpot(g, nav.Wander)
			task.wait(secs)
		elseif act == "Bed" then
			status(g, "walk", "Bedtime")
			local side = bedSide(room)
			local bedPos = core(room, "Bed"):GetPivot().Position
			walkTo(g, side)
			faceTo(g, bedPos)
			-- round 30: turn the duvet down first
			if evCtx.workStart(g, core(room, "Bed"), "top", 0.8, 2.4) then
				play(g, "@turndown")
				task.wait(2.6)
				stop(g, "@turndown")
				evCtx.workEnd(g)
			end
			status(g, "sleep", "Sleeping", "purple")
			setSign(room, "Sleep")
			g.sleepCF = coreSpot(room, "Bed", "lie")
			g.sleeping = bedSleeps(room) >= 2
			pose(g, g.sleepCF)
			g.zzz.Enabled = true
			timed(g, secs)
			Life.fill(g, "energy", 100)
			g.zzz.Enabled = false
			setSign(room, g.dnd and "DND" or nil)
			if not g.wokenUp then moodShift(g, 3, "I slept like a baby.", "Slept like a baby.") end
			local out = flat(side - bedPos)
			g.sleeping = false
			unpose(g, CFrame.lookAt(side, side + out))
		end
		-- thinking out loud now and then
		if rng:NextNumber() < 0.22 then say(g, pick(C.THOUGHTS), 2.6) end
		task.wait(0.4)
	end
end

-- a stay in the room; whatever happens, the door unlocks and the card comes down when it ends
local function useRoom(g, room)
	local ok, err = pcall(stayIn, g, room)
	if room.occupant == g then
		room.occupant = nil
		room.letInUntil = nil
		room.model:SetAttribute("Occupied", nil)
	end
	room.model:SetAttribute("Away", nil)
	setSign(room, nil)
	if not ok then error(err, 0) end
end

---------------------------------------------------------------- lobby roaming (guests admire the placed decor)

-- non-flat items standing in the lobby
local function lobbyItems()
	local list = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Zone") == "Lobby" and not m:GetAttribute("Broken") then
			local it = Catalog.ITEMS[m:GetAttribute("Item")]
			if it and not it.flat then table.insert(list, { model = m, item = it }) end
			end
	end
	return list
end

-- a stroll through the lobby: walk up to a few pieces of decor and admire them
local function lobbyVisit(g, judgeOnly)
	if not g.alive then return end
	if not g.lobbyJudged then
		g.lobbyJudged = true
		if lobbyAppeal >= 12 then
			moodShift(g, math.min(8, math.floor(lobbyAppeal / 4)), "This lobby is gorgeous!", "Gorgeous lobby.")
		elseif lobbyAppeal < 4 then
			moodShift(g, -3, "The lobby feels a bit empty.", "The lobby was bare.")
		end
	end
	if judgeOnly then return end
	local items = lobbyItems()
	if #items == 0 then return end
	-- a nicer lobby draws more lingering
	if rng:NextNumber() > 0.4 + lobbyAppeal / 60 then return end
	status(g, "guest", "Enjoying the lobby")
	for _ = 1, rng:NextInteger(1, math.min(3, #items)) do
		if not g.alive then return end
		local e = pick(items)
		if not e.model.Parent then continue end
		-- round 10e: the fun items get played with (and they're picked more often)
		local fun = {}
		for _, f in ipairs(items) do
			if f.item.tags and table.find(f.item.tags, "play") then table.insert(fun, f) end
		end
		if #fun > 0 and rng:NextNumber() < 0.55 then e = pick(fun) end
		if e.item.tags and table.find(e.item.tags, "play") then
			playItem(g, e)
			continue
		end
		local piv = e.model:GetPivot().Position
		local dir = flat(piv - g.root.Position)
		if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
		local spot = Vector3.new(piv.X - dir.Unit.X * 2.6, g.root.Position.Y, piv.Z - dir.Unit.Z * 2.6)
		walkTo(g, spot)
		if not g.alive then return end
		faceTo(g, piv)
		say(g, pick(C.LINES.lobby), 2.5)
		task.wait(range({ 2, 4.5 }))
	end
end

evCtx = {
	HOTEL = HOTEL, PLACED = PLACED, rng = rng, walkTo = walkTo, status = status, timed = timed, say = say,
	faceTo = faceTo, play = play, stop = stop, sfx = sfx, tell = tell,
	-- GuestLife's view (the same table): staff is filled in further down
	pose = pose, unpose = unpose, moodShift = moodShift, lobbyItems = lobbyItems, NAV = NAV, isMember = isMember,
	Notify = Notify, burst = GuestEvents.burst, guests = guests,
	-- Kitchen's view (round 10c): kitchen itself is made once staff exists
	barTimer = barTimer, deskGames = deskGames, cleaning = cleaning, notMine = notMine, quest = quest,
	-- Upkeep's view (round 11): breakdowns, luggage, lost & found
	core = core, coreSpot = coreSpot, holdBag = holdBag, dropBag = dropBag, addCash = addCash, rooms = rooms,
	GUESTS = GUESTS, scanAppeal = scanAppeal, sparkle = sparkleBurst,
	running = function() return running end,
	hasPerk = function(id) return Research.hasPerk(HOTEL, id) end,
	earn = function(amount, pos)
		pending += amount
		dayStats.earned += amount
		drawPile()
		if pos then Notify:FireAllClients("paid", { pos = pos, amount = amount }) end
		quest("earn", amount)
	end,
}

local adoptGuest -- forward (tour groups bring friends)
local talkTo -- forward (the talk prompt on every guest)
local talkStaff, staffReply -- forward (round 10e: talking to staff)
local staff = {} -- list of { def, g, home, index }
local usedNames = {}

local function guestLife(g)
	-- arrive from the street (a fresh body, or a pedestrian passing by)
	if not g.adopted then
		g.model:PivotTo(NAV[(rng:NextNumber() < 0.5) and "Street" or "StreetExit"].CFrame)
		g.model.Parent = GUESTS
		setGroup(g.model, "Guests")
	else
		g.model.Parent = GUESTS
	end
	loadAnims(g)
	giveBag(g)
	if not g.event and not g.tourist and anyDoubleRoom() and rng:NextNumber() < 0.3 then addBuddy(g) end
	status(g, "walk", "Arriving")
	if #queue >= C.QUEUE_MAX then
		walkTo(g, NAV.PathStart.Position)
		say(g, "Too busy here...", 2.5)
		leaveStreet(g)
		return
	end
	-- take a place at the back of the line and walk straight to it
	table.insert(queue, g)
	g.queuedAt = os.clock()
	refreshQueue()
	local lastSlot = g.slot
	queueGo(g, lastSlot)
	if not g.alive then return end
	local ev = g.event
	if g.gtype and not ev then
		say(g, pick(g.gtype.arrive), 3.2)
		if g.gtype.toast then tell("flavor", { text = g.gtype.toast, icon = g.gtype.icon, bad = g.gtype.id == "karen" }) end
		if g.gtype.id == "karen" then play(g, "stomp") end
	end
	if ev and not g.tourist then
		say(g, ev.lines[rng:NextInteger(1, #ev.lines)], 3.5)
		tell("flavor", { text = g.name .. " " .. ev.arrive, icon = ev.icon })
		if ev.id == "celebrity" then
			for _ = 1, 3 do GuestEvents.burst(g.head.Position + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2)), "flash", 1) end
		elseif ev.id == "tour" then
			-- the rest of the group follows a moment later
			task.spawn(function()
				for _ = 1, 3 do
					task.wait(rng:NextNumber(0.6, 1.2))
					if not running then return end
					local nm = pick(C.NAMES)
					if usedNames[nm] then nm = nm .. " " .. string.char(65 + rng:NextInteger(0, 25)) .. "." end
					usedNames[nm] = true
					local m = makeBody(nm)
					if m then adoptGuest(m, nm, false, ev, true) end
				end
			end)
		end
	else
		say(g, pick(C.LINES.arrive), 3)
	end
	sfx("arrive", NAV.PathStart.Position)
	-- wait in line until let in (step forward as the line moves, chat with the person in front)
	status(g, "door", "Waiting", "green")
	barTimer(g, patience(g), true, true)
	local t0 = os.clock()
	local nextFix, nextChat = os.clock() + 1, os.clock() + rng:NextNumber(5, 12)
	while g.alive and not g.room do
		if g.slot and g.slot ~= lastSlot then
			lastSlot = g.slot
			queueGo(g, lastSlot)
		elseif os.clock() >= nextFix then
			nextFix = os.clock() + 1
			queueGo(g, lastSlot)
		end
		local k = 1 - (os.clock() - t0) / patience(g)
		if k <= 0 then
			local i = queueSlot(g)
			if i then table.remove(queue, i); refreshQueue() end
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " got tired of waiting", icon = "guest", bad = true })
			leaveStreet(g)
			return
		end
		if os.clock() >= nextChat then
			nextChat = os.clock() + rng:NextNumber(10, 22)
			local front = g.slot and queue[g.slot - 1]
			if front and rng:NextNumber() < 0.55 then
				Life.queueChat(evCtx, g, front)
			elseif rng:NextNumber() < 0.35 then
				say(g, pick(C.LINES.wait), 2.5)
			end
		end
		task.wait(0.1)
	end
	if not g.alive then return end
	local room = g.room
	local waited = (os.clock() - t0) / patience(g)
	if waited > 0.45 then
		moodShift(g, -math.floor((waited - 0.3) * 30), "I waited ages outside!", "Waited ages to get in.")
	elseif waited < 0.15 then
		moodShift(g, 4, "You let me in so quickly!", "Got in right away.")
	end
	local deskT0 = os.clock()
	-- check in (one guest at the desk at a time, like the queue outside)
	status(g, "walk", "Room " .. room.id)
	walkTo(g, NAV.Inside.Position)
	status(g, "door", "Waiting in line", "green")
	if not deskWait(g, "in") then
		releaseRoom(room)
		if g.alive then
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " got tired of waiting", icon = "guest", bad = true })
			leaveStreet(g)
		end
		return
	end
	status(g, "bell", "Checking in", "yellow")
	-- round 18: they introduce themselves at the desk, in their own way
	if Life.Voice and g.model then
		local hi = Life.Voice.line(g.model, "hello")
		if hi then Life.Voice.say(g.model, hi, 3.6) end
	end
	sfx("bell", NAV.DeskGuest.Position)
	say(g, pick(C.LINES.checkin), 2.5)
	if not deskService(g, C.CHECK_IN * (Research.hasPerk(HOTEL, "checkin") and 0.67 or 1), "Check In") then
		deskRemove(g)
		releaseRoom(room)
		if g.alive then
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("flavor", { text = g.name .. " left without checking in", icon = "guest", bad = true })
			leaveStreet(g)
		end
		return
	end
	deskRemove(g)
	quest("checkin")
	evCtx.upkeep:checkedIn(g, room) -- round 11: some leave their bag for you to carry up
	if g.deskStars == 3 then
		moodShift(g, 6, "The front desk was lovely!", "Lovely front desk.")
	end
	g.deskStars = nil
	local deskSecs = os.clock() - deskT0
	if deskSecs > 30 then
		moodShift(g, -8, "Check-in took forever.", "Slow check-in.")
	elseif deskSecs < 14 then
		moodShift(g, 5, "Check-in was so quick!", "Speedy check-in.")
	end
	Levels.award(HOTEL, Levels.XP.checkin, "Check-in", g.head.Position + Vector3.new(0, 2, 0))
	if ev and ev.id == "inspector" then
		local _, reward = GuestEvents.inspect(evCtx, g, room)
		g.inspectReward = reward
	else
		-- everyone's different: a stroll round the decor, something else in the lobby, or straight up
		local r = rng:NextNumber()
		lobbyVisit(g, r >= 0.4)
		if r >= 0.4 and r < 0.8 then Life.outing(evCtx, g, "lobby") end
	end
	if not g.alive then return end
	status(g, "walk", "Room " .. room.id)
	useRoom(g, room)
	if not g.alive then return end
	g.checkingOut = true
	evCtx.upkeep:checkout(g)
	holdBag(g)
	-- a happy guest leaves something on the bed
	if g.mood >= 62 and rng:NextNumber() < 0.6 then
		leaveTip(room, math.floor(8 + (g.mood - 60) * 0.5 + rng:NextNumber(0, 8)))
	end
	-- check out: the room is dirty the moment they leave it
	status(g, "walk", "Checking out")
	walkTo(g, room.nav.Enter.Position)
	walkTo(g, room.nav.Door.Position)
	room.guest = nil
	room.model:SetAttribute("Guest", nil)
	for _, t in ipairs(C.TASKS) do room.tasks[t] = true end
	room.model:SetAttribute("TasksLeft", #C.TASKS)
	setRoomState(room, "Dirty")
	refreshQueue()
	tell("toast", { text = "Room " .. room.id .. " needs cleaning", icon = "roomDirty" })
	evCtx.upkeep:leftBehind(g, room) -- round 11: lost & found
	-- one last look round the lobby before paying, sometimes
	local r = rng:NextNumber()
	if r < 0.25 then lobbyVisit(g) elseif r < 0.5 then Life.outing(evCtx, g, "lobby") end
	if not g.alive then return end
	-- round 14: a shifty guest tries to slip out without paying (talk to them to stop them)
	if Life.tryDash(evCtx, g) then
		if g.alive then leaveStreet(g) end
		return
	end
	if not g.alive then return end
	status(g, "door", "Waiting in line", "green")
	if not deskWait(g, "out") then
		if g.alive then
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " left without paying", icon = "guest", bad = true })
			walkTo(g, NAV.Inside.Position)
			leaveStreet(g)
		end
		return
	end
	status(g, "cash", "Paying", "green")
	if not deskService(g, C.CHECK_OUT * (Research.hasPerk(HOTEL, "checkin") and 0.67 or 1), "Check Out") then
		deskRemove(g)
		if g.alive then
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " left without paying", icon = "guest", bad = true })
			walkTo(g, NAV.Inside.Position)
			leaveStreet(g)
		end
		return
	end
	deskRemove(g)
	-- round 10e: what the hotel had to offer. A bare starter hotel lands near 2 stars, a full one near 4
	local offer = starsOf(room) + math.min(2.5, lobbyAppeal / 30)
	local dm = math.floor((offer - C.STAY_PAR) * C.STAY_MOOD + 0.5) + Research.add(HOTEL, "mood") -- round 13: Guest Experience research
	if dm <= -6 then
		moodShift(g, dm, nil, offer < 3 and "Pretty bare hotel, not much to do." or "The room was very basic.")
	elseif dm >= 6 then
		moodShift(g, dm, nil, "Lovely room and plenty to do.")
	elseif dm ~= 0 then
		moodShift(g, dm)
	end
	-- research: Tip Jar makes tips half as big again
	local tipK = C.ROOM_TIERS[tierOf(room)].tip * (Research.hasPerk(HOTEL, "tips") and 1.5 or 1) * Research.mul(HOTEL, "tips")
	tipK *= 0.4 + g.mood / 100 -- happy guests tip more
	local pay = (room.model:GetAttribute("Price") or C.ROOM_PRICE) + math.floor(range(C.TIP) * tipK)
	-- event guests pay more when the hotel had what they needed, less when it didn't
	if ev and ev.pay then
		local met = g.eventMet ~= false
		pay = GuestEvents.pay(ev, met, pay)
		if met and ev.star and ev.gift then
			pay += ev.gift
			tell("flavor", { text = g.name .. " left a gift: $" .. ev.gift .. "!", icon = ev.icon })
		end
		if not met then
			tell("toast", { text = g.name .. " wanted " .. (ev.missing or "more") .. " in room " .. room.id, icon = ev.icon, bad = true })
		elseif not g.tourist then
			tell("flavor", { text = g.name .. " loved their stay: $" .. pay, icon = ev.icon })
		end
	end
	pay += g.inspectReward or 0
	if g.buddy then pay = math.floor(pay * 1.6) end -- round 10e: a couple
	if g.payMul then pay = math.floor(pay * g.payMul) end -- round 14: guest types (big spenders, budget travellers)
	if g.discount then pay = math.floor(pay * (1 - g.discount)) end -- round 14: money off, promised in a conversation
	Levels.award(HOTEL, Levels.XP.stay + ((ev and ev.pay and g.eventMet ~= false) and Levels.XP.event or 0), "Happy stay", g.head.Position + Vector3.new(0, 2, 0))
	pending += pay
	dayStats.earned += pay
	dayStats.guests += 1
	drawPile()
	-- the review: mood becomes stars, led by the strongest reason
	local rtext, rstars = reviewText(g)
	loadReviews()
	table.insert(reviews, 1, { name = g.name, stars = rstars, text = rtext, room = room.id, w = g.gtype and g.gtype.reviewW })
	if g.gtype and g.gtype.reviewW then
		tell("flavor", { text = g.name .. " posted a " .. rstars .. "-star review to their followers!", icon = "phone", bad = rstars <= 2 })
	end
	if #reviews > 20 then table.remove(reviews) end
	reviewsJSON = HttpService:JSONEncode(reviews)
	HOTEL:SetAttribute("Reviews", reviewsJSON)
	updateRating()
	quest("guests")
	quest("earn", pay)
	if rstars >= 5 then quest("review5") end
	tell("review", { name = g.name, stars = rstars, text = rtext, room = room.id })
	say(g, rstars >= 4 and pick(C.LINES.checkout) or (rstars <= 2 and "I won't be back." or "Thanks, bye."), 3)
	Notify:FireAllClients("paid", { amount = pay, pos = g.head.Position + Vector3.new(0, 3, 0) })
	play(g, rstars >= 4 and "wave_small" or "head_shake")
	task.wait(1)
	status(g, "walk", "Going home")
	walkTo(g, NAV.Inside.Position)
	leaveStreet(g)
end

-- turn a body (fresh from makeBody, or a pedestrian's) into a guest and start its life
adoptGuest = function(model, name, adopted, event, tourist)
	local g = {
		name = name, model = model, alive = true, adopted = adopted, tourist = tourist,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
		head = model:WaitForChild("Head"),
	}
	model:SetAttribute("Guest", true)
	makeBubble(g)
	g.notes = {}
	Life.persona(g) -- round 14: who they are and what they need
	Life.needs(g)
	g.mood = range(C.MOOD_START)
	model:SetAttribute("Mood", math.floor(g.mood + 0.5))
	local tp = Instance.new("ProximityPrompt")
	tp.Name = "TalkPrompt"
	tp.ActionText = "Talk"
	tp.ObjectText = name
	tp.KeyboardKeyCode = Enum.KeyCode.F
	tp.GamepadKeyCode = Enum.KeyCode.ButtonY
	tp.HoldDuration = 0
	tp.MaxActivationDistance = 7
	tp.RequiresLineOfSight = false
	tp.Style = Enum.ProximityPromptStyle.Custom
	tp:SetAttribute("Icon", "guest")
	tp:SetAttribute("Color", "blue")
	tp.Parent = g.root
	g.talkPrompt = tp
	tp.Triggered:Connect(function(player) if talkTo then talkTo(g, player) end end)
	g.event = event or GuestEvents.roll(HOTEL, rng)
	if g.event then GuestEvents.dress(g, g.event) end
	if g.event and g.event.star then
		-- round 15: a star guest: their own name, and a cutscene for the hotel's players as they walk up (Cutscene)
		g.name = g.event.who
		g.special = true
		model:SetAttribute("BName", g.name)
		model:SetAttribute("Star", g.event.id)
		tp.ObjectText = g.name
		tell("cutscene", { kind = "star", model = model, name = g.name, title = g.event.title, line = g.event.lines[1], icon = g.event.icon })
	end
	Life.rollType(evCtx, g) -- round 14: a demanding guest, a big spender, a backpacker...
	local z = Instance.new("ParticleEmitter")
	z.Name = "Zzz"
	z.Texture = C.ICONS.sleep
	z.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.1) })
	z.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	z.Lifetime = NumberRange.new(1.6, 2)
	z.Speed = NumberRange.new(1.5, 2.2)
	z.EmissionDirection = Enum.NormalId.Top
	z.SpreadAngle = Vector2.new(15, 15)
	z.Acceleration = Vector3.new(0.6, 0.4, 0)
	z.Rate = 1.2
	z.Enabled = false
	z.Parent = g.head
	g.zzz = z
	guests[g] = true
	task.spawn(function()
		local ok, err = pcall(guestLife, g)
		if not ok then
			if running then warn("Shared guest " .. name .. ": " .. tostring(err)) end
			if g.room and g.room.state == "Booked" then setRoomState(g.room, "Ready") end
			despawn(g)
		end
		usedNames[name] = nil
	end)
end

local function spawnGuest()
	-- round 12: sometimes it's one of your friends, in their own avatar
	local busy = {}
	for g in pairs(guests) do
		local id = g.model and g.model:GetAttribute("FriendId")
		if id then busy[id] = true end
	end
	local friend = Bodies.friendPick(members(), rng, busy)
	local name
	if friend then
		name = friend.name
	else
		for _ = 1, 10 do
			name = pick(C.NAMES)
			if not usedNames[name] then break end
		end
	end
	usedNames[name] = true
	local model = makeBody(name, friend and friend.desc)
	if not model then return end
	if friend then
		model:SetAttribute("FriendId", friend.userId)
		Notify:FireClient(friend.of, "toast", { text = "Your friend " .. friend.name .. " is coming to stay!", icon = "guest" })
	end
	adoptGuest(model, name)
end

---------------------------------------------------------------- locked doors, knocking and talking (round 10c)

local function playerInside(room)
	local f = room.model:FindFirstChild("Floor")
	if not f then return false end
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local l = f.CFrame:PointToObjectSpace(r.Position)
			if math.abs(l.X) < f.Size.X / 2 and math.abs(l.Z) < f.Size.Z / 2 and l.Y > -2 and l.Y < 12 then return true end
		end
	end
	return false
end

-- a room is locked while its guest is inside, unless they let someone in or a player is already in there
task.spawn(function()
	while running do
		local now = os.clock()
		for _, room in pairs(rooms) do
			local g = room.occupant
			local open = room.letInUntil and now < room.letInUntil
			local locked = (g ~= nil and g.alive and not open and not playerInside(room)) == true
			if room.locked ~= locked then
				room.locked = locked
				room.model:SetAttribute("Locked", locked or nil)
				local ref = room.model:FindFirstChild("DoorRef")
				if ref and ref.Value then ref.Value:SetAttribute("Locked", locked or nil) end
				if room.doorBlock then room.doorBlock.CanCollide = locked end
			end
			if room.knockPrompt then
				room.knockPrompt.Enabled = locked and now >= (room.knockReady or 0)
			end
		end
		task.wait(0.25)
	end
end)

knockOn = function(room, player)
	-- round 11: carrying their bag? Then it's a delivery
	if evCtx.upkeep:onKnock(room, player) then return end
	-- round 10e: carrying their room service? Then it's a delivery, not a knock
	if orders[room] and player:GetAttribute("Tray") == room.id then
		deliverOrder(room, player)
		return
	end
	local g = room.occupant
	local now = os.clock()
	if not (g and g.alive) or now < (room.knockReady or 0) or not room.knockSpot then return end
	room.knockReady = now + 4.5
	room.knockPrompt.Enabled = false
	local door = Rooms.door(room.model)
	Notify:FireAllClients("knock", { player = player, door = door, pos = room.knockSpot.Position })
	local again = room.lastKnock and now - room.lastKnock < 25
	room.lastKnock = now
	task.delay(1.7, function()
		if not g.alive or room.occupant ~= g then return end
		local text, ok
		local sign = room.signKind
		if sign == "Sleep" then
			g.wokenUp = true
			moodShift(g, -18, "Somebody woke me up knocking!", "Woken up by knocking in the night.")
			text = pick(C.KNOCK.sleep)
		elseif sign == "DND" then
			moodShift(g, -12, "Nobody here respects the sign.", "Staff ignored my Do Not Disturb sign.")
			text = pick(C.KNOCK.dnd)
		elseif again and not (room.letInUntil and os.clock() < room.letInUntil) then
			moodShift(g, -6, "Somebody kept knocking on my door.", "Kept knocking on my door.")
			text = pick(C.KNOCK.again)
		elseif rng:NextNumber() < 0.35 + g.mood / 200 then
			ok = true
			text = pick(C.KNOCK.yes)
			room.letInUntil = os.clock() + C.LET_IN_SECS
		else
			moodShift(g, -2)
			text = pick(C.KNOCK.no)
		end
		say(g, text, 3.2)
		if sign == "Sleep" or sign == "DND" or (again and not ok) then
			-- round 10e: disturbed and cross about it
			g.model:SetAttribute("BIcon", "angry")
			sfx("grumble", room.knockSpot.Position)
			task.delay(3.5, function()
				if g.model and g.model:GetAttribute("BIcon") == "angry" then g.model:SetAttribute("BIcon", nil) end
			end)
		end
		Notify:FireAllClients("doorReply", {
			door = door, pos = room.knockSpot.Position, text = text, ok = ok == true, name = g.name,
			mood = math.floor(g.mood + 0.5), sign = sign,
		})
	end)
end

local Talk = RS.Shared.Remotes:FindFirstChild("Talk")
if not Talk then
	Talk = Instance.new("RemoteEvent")
	Talk.Name = "Talk"
	Talk.Parent = RS.Shared.Remotes
end

local function guestOf(model)
	for g in pairs(guests) do
		if g.model == model then return g end
	end
	return nil
end

-- round 12: what the guest is doing picks the replies on the talk card. Life.TALK_SETS[context] = option ids;
-- Life.TALK_TEXT[id] = the button text. Every set ends with "bye".
Life.TALK_TEXT = Life.TALK_TEXT or {
	stay = "How's your stay?", need = "Need anything?", nice = "Enjoy your stay!", bye = "Goodbye",
	sorryWait = "Sorry for the wait!", soon = "A room's nearly ready", trip = "How was your trip?",
	whatsWrong = "What's wrong?", freeDrink = "Have a drink on us ($10)", calm = "Please calm down",
	review = "Leave us a review?", comeBack = "Come back soon!", beRight = "Be right with you!",
	foodSoon = "Your food's on its way", tasty = "How's the food?", lobby = "Enjoying the lobby?",
	tip = "Try the cafe!", sorryWake = "Sorry, wrong room!", couple = "You two look happy!",
	special = "Here for anything special?", weather = "Crazy weather, huh?", fun = "Having fun?",
	recommend = "Want a tip for the town?", luggage = "Can I take your bags?",
}
Life.TALK_SETS = Life.TALK_SETS or {
	queue = { "sorryWait", "soon", "trip", "bye" },
	desk = { "beRight", "trip", "luggage", "bye" },
	upset = { "whatsWrong", "freeDrink", "calm", "bye" },
	room = { "stay", "about", "plans", "need", "bye" },
	town = { "howTown", "plans", "need", "bye" },
	karen = { "listen", "manager", "discount", "refuse", "bye" },
	dash = { "caught", "bye" },
	party = { "keepDown", "about", "bye" },
	sleep = { "sorryWake", "bye" },
	food = { "foodSoon", "tasty", "need", "bye" },
	lobby = { "lobby", "about", "need", "nice", "bye" },
	leaving = { "stay", "review", "comeBack", "bye" },
	out = { "recommend", "weather", "nice", "bye" },
	default = { "stay", "about", "need", "bye" },
}
function Life.talkContext(g)
	local tc = Life.typeContext and Life.typeContext(g) -- round 14: a Karen, a party, someone sneaking out
	if tc then return tc end
	local what = g.model and g.model:GetAttribute("BWhat") or ""
	if g.mood < 35 then return "upset" end
	if g.sleeping or what == "Sleeping" or what == "Bedtime" then return "sleep" end
	if what == "Waiting in line" or what == "At the door" or what == "No clean rooms" then return "queue" end
	if what:find("check in") or what == "Checking in" or what == "At the desk" or what == "Paying" then return "desk" end
	if g.checkingOut or what == "Checking out" or what == "Leaving" or what == "Going home" then return "leaving" end
	if what:find("to eat") or what:find("Eating") or what:find("room service") or what:find("snack") or what:find("table") then return "food" end
	if what == "Enjoying the lobby" or what == "Having fun" or what == "Dancing" or what == "Chatting" or what == "Finding a seat" or what == "Taking photos" then return "lobby" end
	if what == "Out for a walk" or what == "Enjoying the town" or what == "Heading out" or what == "Exploring" then return "out" end
	if g.lastTown and os.clock() - g.lastTown.t < 90 and not (g.told and g.told.howTown) then return "town" end
	if g.room and g.room.occupant == g then return "room" end
	return "default"
end
function Life.talkOptions(g)
	-- round 14: a reply that leads somewhere shows its follow-ups for a while
	if g.talkNext and os.clock() - g.talkNext.t < 25 then
		local out = {}
		for _, id in ipairs(g.talkNext.ids) do table.insert(out, { id = id, text = Life.TALK_TEXT[id] or Life.optionText(g, id) or id }) end
		return out
	end
	local list = table.clone(Life.TALK_SETS[Life.talkContext(g)] or Life.TALK_SETS.default)
	-- a couple, an event guest or wild weather adds one more line to pick (before "bye")
	local extra
	if g.buddy then extra = "couple"
	elseif g.event and not g.talkedSpecial then extra = "special"
	elseif Life.weather() ~= "sun" then extra = "weather" end
	if extra and not table.find(list, extra) and #list < 5 then table.insert(list, #list, extra) end
	local out = {}
	for _, id in ipairs(list) do table.insert(out, { id = id, text = Life.optionText(g, id) or Life.TALK_TEXT[id] or id }) end
	return out
end

-- what the talk card shows: who they are, how they feel, and the review they'd leave right now
local function talkInfo(g, line, feel)
	local text, stars = reviewText(g)
	local want
	if g.event and g.event.missing and g.eventMet ~= true then want = g.event.missing end
	return {
		guest = g.model, name = g.name, line = line,
		mood = math.floor(g.mood + 0.5), moodWord = moodWord(g.mood),
		stars = stars, review = text,
		room = g.room and g.room.id, event = g.event and g.event.label, want = want,
		options = Conv.guestOptions(evCtx, g, Life.talkOptions(g)), doing = g.model and g.model:GetAttribute("BWhat"), feel = feel,
		persona = g.persona and g.persona.name, feel = Life.feeling(g), from = g.hometown, gtype = g.gtype and g.gtype.label,
	}
end

talkTo = function(g, player)
	if not isMember(player) then notMine(player) return end
	if not g.alive then return end
	-- round 10e: what they say depends on what they're up to
	local T = C.TALK
	local line = Life.answered(evCtx, g)
	if not line then
		if g.gtype and g.gtype.id == "karen" and g.mood < 60 then line = pick(Life.KAREN_DEMAND)
		elseif g.dashing then line = "Oh! Uh. Hi. I was just... leaving. Bye!"
		elseif g.partying then line = "Hey! Come join the party!"
		elseif g.mood < 35 then line = pick(T.hiGrumpy)
		elseif queueSlot(g) then line = pick(T.hiQueue)
		elseif g.checkingOut then line = pick(T.hiLeaving)
		elseif g.room and g.room.occupant == g then line = pick(Clock.isNight(Clock.now()) and T.hiNight or T.hiRoom)
		elseif g.buddy and rng:NextNumber() < 0.5 then line = pick(T.hiCouple)
		elseif g.bag and not g.room then line = pick(T.hiBags)
		elseif rng:NextNumber() < 0.25 then
			-- round 17: sometimes they open with the weather instead
			local w = Life.weather()
			line = T.hiWeather[w] and pick(T.hiWeather[w]) or pick(T.hi)
		else line = pick(T.hi) end
	end
	g.talkUntil, g.talkPlayer = os.clock() + 40, player
	g.convNext, g.talkNext = nil, nil
	holdFace(g, player)
	say(g, line, 2.5)
	feelUp(g, g.mood >= 62 and "happy" or (g.mood < 35 and "angry" or "plain"), false)
	if not g.talkedTo then
		g.talkedTo = true
		quest("talk")
	end
	if not g.posed then
		faceTo(g, player.Character and player.Character:GetPivot().Position)
		play(g, "wave_small")
	end
	Notify:FireClient(player, "talk", talkInfo(g, line))
end

-- Studio test hook: ServerStorage.TalkTest_<plot>:Invoke(player, npcName) starts a talk with that guest / staff member
if game:GetService("RunService"):IsStudio() then
	local bf = Instance.new("BindableFunction")
	bf.Name = "TalkTest_" .. HOTEL.Name
	bf.OnInvoke = function(player, name)
		for g in pairs(guests) do
			if g.alive and g.model and g.model.Name == name then talkTo(g, player) return "guest" end
		end
		for _, s in ipairs(staff) do
			if s.g.alive and s.g.name == name then talkStaff(s, player) return "staff" end
		end
		return "none"
	end
	bf.Parent = game.ServerStorage
	table.insert(conns, { Disconnect = function() bf:Destroy() end })
end

local talkGap = {}
table.insert(conns, Talk.OnServerEvent:Connect(function(player, model, option)
	if typeof(model) ~= "Instance" or type(option) ~= "string" then return end
	local g = guestOf(model)
	local st
	if not g then
		for _, s in ipairs(staff) do if s.g.model == model then st = s end end
		g = st and st.g
	end
	if not g or not g.alive or not isMember(player) then return end
	-- round 15: walking away (or closing the card) ends it at once, so nobody keeps staring after you
	if option == "leave" then
		if g.talkPlayer == player then g.talkUntil, g.talkPlayer = nil, nil end
		return
	end
	local now = os.clock()
	if now < (talkGap[player] or 0) then return end
	talkGap[player] = now + 0.45
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - g.root.Position).Magnitude > 24 then return end
	if option == "bye" then g.talkUntil, g.talkPlayer = nil, nil else g.talkUntil, g.talkPlayer = os.clock() + 40, player end
	-- round 15: Conversations answers first (topics and their questions, with a feel for the face and gesture)
	if st then
		local cl, cf, ca = Conv.staffReply(evCtx, st, option, player)
		staffReply(st, player, option, cl, cf, ca)
		return
	end
	local moodBefore = g.mood
	do
		local cl, cf, ca = Conv.guestReply(evCtx, g, option, player)
		if cl then
			say(g, cl, 3.5)
			feelUp(g, cf, ca)
			Notify:FireClient(player, "talkReply", talkInfo(g, cl, cf))
			return
		end
	end
	local line = Life.talkReply(evCtx, g, option, player) -- round 14: conversations that go somewhere
	if line then
		-- answered (GuestLife)
	elseif option == "stay" then
		local n = topNote(g, "say")
		if g.mood >= 70 then
			line = n and n.say or pick(C.TALK.stayGood)
		elseif g.mood >= 45 then
			line = pick(C.TALK.stayOk) .. (n and (" " .. n.say) or "")
		else
			line = n and n.say or pick(C.TALK.stayBad)
		end
	elseif option == "need" then
		local room = g.room
		if g.event and g.event.missing and g.eventMet ~= true then
			line = "I'd really love " .. g.event.missing .. " in my room."
		elseif lobbyAppeal < 6 then
			line = "The lobby could use some decor."
		elseif room and (room.model:GetAttribute("Stars") or 1) < 3 then
			line = "A comfier room would be nice."
		else
			line = pick(C.TALK.allSet)
		end
	elseif option == "sorryWait" or option == "beRight" then
		if not g.soothed then
			g.soothed = true
			moodShift(g, 4)
			line = pick({ "No problem, take your time!", "Thanks, I appreciate that.", "Oh, that's kind of you." })
		else
			line = pick({ "You said that already...", "Mhm. Still waiting.", "Okay, okay." })
		end
	elseif option == "soon" then
		local free = false
		for _, r in pairs(rooms) do if r.state == "Ready" then free = true end end
		if free then
			moodShift(g, 2)
			line = pick({ "Great, can't wait!", "Perfect, I'm exhausted.", "Oh good!" })
		else
			if not g.promised then g.promised = true else moodShift(g, -3) end
			line = pick({ "You keep saying that...", "I hope so, my feet hurt.", "Soon? How soon?" })
		end
	elseif option == "trip" then
		line = pick({ "Long drive, but worth it!", "The traffic was awful.", "Smooth! The train was lovely.", "I got a bit lost, honestly.", "First time in this town!" })
		if not g.chatted then g.chatted = true; moodShift(g, 2) end
	elseif option == "luggage" then
		if g.bag then
			moodShift(g, 3)
			line = pick({ "Oh, would you? Thank you!", "Such service! Thanks." })
		else
			line = pick({ "I travel light, but thanks!", "No bags, just me." })
		end
	elseif option == "whatsWrong" then
		local n = topNote(g, "say")
		line = n and n.say or pick({ "Everything takes forever here!", "This place is a mess.", "I expected better, honestly." })
	elseif option == "freeDrink" then
		local owner = Players:GetPlayerByUserId(HOTEL:GetAttribute("Owner") or 0) or player
		local cash = owner:GetAttribute("Cash") or 0
		if g.drinkGiven then
			line = "I already have one, thanks."
		elseif cash < 10 then
			line = "You can't even afford it? Wow."
			moodShift(g, -2)
		else
			g.drinkGiven = true
			owner:SetAttribute("Cash", cash - 10)
			owner:SetAttribute("Spent", (owner:GetAttribute("Spent") or 0) + 10)
			moodShift(g, 12, nil, "They gave me a free drink when I was upset. Classy.")
			line = pick({ "Oh! That's... actually really nice. Thanks.", "Okay, you've won me back a little.", "A free drink? Fine, I'll stay." })
		end
	elseif option == "calm" then
		if rng:NextNumber() < 0.4 then
			moodShift(g, 3)
			line = pick({ "...Fine. Sorry.", "You're right, I'm just tired." })
		else
			moodShift(g, -4)
			line = pick({ "Don't tell me to calm down!", "Excuse me?!", "Unbelievable." })
		end
	elseif option == "review" then
		if g.mood >= 60 then
			moodShift(g, 2)
			line = pick({ "Five stars, for sure!", "I'll write something nice!", "Already on it!" })
		else
			moodShift(g, -2)
			line = pick({ "Oh, I'll leave a review alright.", "You might not like it.", "We'll see." })
		end
	elseif option == "comeBack" then
		line = g.mood >= 55 and pick({ "We definitely will!", "See you next time!", "Count on it!" }) or pick({ "Maybe...", "We'll see." })
		if g.mood >= 55 and not g.complimented then g.complimented = true; moodShift(g, 2) end
	elseif option == "foodSoon" then
		line = pick({ "Great, I'm starving!", "Can't wait!", "Smells amazing already." })
		if not g.soothed then g.soothed = true; moodShift(g, 2) end
	elseif option == "tasty" then
		line = g.mood >= 55 and pick({ "Delicious! My compliments.", "Really good, thank you!" }) or pick({ "It's... edible.", "A bit cold, honestly." })
	elseif option == "lobby" then
		line = lobbyAppeal >= 12 and pick({ "It's gorgeous in here!", "Love the decor!", "So cosy." }) or pick({ "It's a bit empty, isn't it?", "Could use some plants.", "It's fine." })
	elseif option == "fun" then
		line = pick({ "So much fun!", "Best hotel lobby ever!", "Yes! Again!", "Pretty fun, yeah." })
		if not g.chatted then g.chatted = true; moodShift(g, 2) end
	elseif option == "tip" then
		line = pick({ "Ooh, maybe I will!", "Is the food any good?", "I might grab a bite." })
	elseif option == "recommend" then
		line = pick({ "Ooh, where should I go?", "The park looked nice!", "Thanks, I'll check it out!", "Is there a good cafe nearby?" })
		if not g.chatted then g.chatted = true; moodShift(g, 2) end
	elseif option == "weather" then
		local w = Life.weather()
		line = w == "rain" and pick({ "Pouring! Glad I'm inside.", "Forgot my umbrella too." })
			or (w == "snow" and pick({ "So pretty though!", "Freezing out there!" }))
			or (w == "storm" and pick({ "That thunder scared me!", "Wild out there." }))
			or pick({ "Can't see a thing in this fog.", "Strange weather today." })
	elseif option == "sorryWake" then
		moodShift(g, -2)
		line = pick({ "Mmph... go away...", "Do you know what time it is?", "Zzz... huh?" })
	elseif option == "couple" then
		moodShift(g, 3)
		line = pick({ "Aww, thank you!", "We're on our honeymoon!", "Ten years together!" })
	elseif option == "special" then
		g.talkedSpecial = true
		line = g.event and g.event.label and ("Yes! It's a " .. string.lower(g.event.label) .. " stay.") or "Just a little getaway!"
		moodShift(g, 2)
	elseif option == "nice" then
		if not g.complimented then
			g.complimented = true
			moodShift(g, 4, "The staff here are so friendly!", "Lovely, friendly staff.")
			line = pick(C.TALK.nice)
		else
			moodShift(g, -1)
			line = pick(C.TALK.niceAgain)
		end
	else
		line = pick(C.TALK.bye)
		if not g.posed then play(g, "wave_small") end
	end
	say(g, line, 3)
	local feel = option == "bye" and "happy" or Conv.feelOf(moodBefore, g.mood, line)
	feelUp(g, feel, option == "bye" and false or nil)
	Notify:FireClient(player, "talkReply", talkInfo(g, line, feel))
end))
table.insert(conns, Players.PlayerRemoving:Connect(function(player) talkGap[player] = nil; Life.playerLeft(player) end))

---------------------------------------------------------------- sidewalk pedestrians (passers-by; some stop and become guests)

local peds = {}

local function pedDone(p, keepModel)
	p.alive = false
	local i = table.find(peds, p)
	if i then table.remove(peds, i) end
	if not keepModel and p.model then p.model:Destroy() end
end

-- the hotel's pull on passers-by: more stars, more walk-ins
-- round 10d: a young hotel gets guests slowly. 0 at level 1, 1 from level 7 (C.WALKIN_RAMP_LEVELS) on
local function growth()
	return math.clamp((Levels.of(HOTEL) - 1) / (C.WALKIN_RAMP_LEVELS or 6), 0, 1)
end

local function pedInterest()
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	return (C.PED_BASE + (stars - 1) * C.PED_PER_STAR) * (0.4 + 0.6 * growth())
end

local function spawnPed()
	local name = pick(C.NAMES)
	local model = makeBody(name)
	if not model then return end
	local g = {
		name = name, model = model, alive = true,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
		head = model:WaitForChild("Head"),
	}
	local fromLeft = rng:NextNumber() < 0.5
	g.model:PivotTo((fromLeft and NAV.Street or NAV.StreetExit).CFrame)
	model.Parent = GUESTS
	setGroup(model, "Guests")
	loadAnims(g)
	table.insert(peds, g)
	task.spawn(function()
		local ok, err = pcall(function()
			-- decide up front whether this passer-by will walk in and become a guest;
			-- everyone else strolls the whole street without stopping
			local count = 0
			for _ in pairs(guests) do count += 1 end
			local willJoin = #members() > 0 and #queue < C.QUEUE_MAX and count < 14
				and rng:NextNumber() < pedInterest() * (RS.Shared:GetAttribute("Night") and C.NIGHT_TRAFFIC or 1)
			if willJoin then
				-- stroll along the sidewalk to the front of the hotel, then walk in
				local front = Vector3.new(NAV.PathStart.Position.X, NAV.Street.Position.Y, NAV.Street.Position.Z)
				walkTo(g, front)
				if not g.alive then return end
				pedDone(g, true) -- keep the body: it becomes a guest
				if usedNames[g.name] then g.name = g.name .. " II" end
				usedNames[g.name] = true
				adoptGuest(g.model, g.name, true)
				return
			end
			-- just passing through: straight to the far end, no stopping
			walkTo(g, (fromLeft and NAV.StreetExit or NAV.Street).Position)
			pedDone(g)
		end)
		if not ok then
			if running then warn("Shared ped " .. name .. ": " .. tostring(err)) end
			pedDone(g)
		end
	end)
end

---------------------------------------------------------------- the front door

-- gives queued guests free rooms, front of the line first; returns how many went in
letIn = function(maxN)
	local let = 0
	while #queue > 0 and let < (maxN or math.huge) do
		local room = freeRoom(queue[1])
		if not room then break end
		local g = table.remove(queue, 1)
		room.state = "Booked"
		room.guest = g
		room.model:SetAttribute("State", "Booked")
		room.model:SetAttribute("Guest", g.name)
		g.room = room
		let += 1
	end
	if let > 0 then quest("letin", let) end
	if let > 0 then
		roomCounts()
		refreshQueue()
	end
	return let
end

do
	doorPrompt = Instance.new("ProximityPrompt")
	doorPrompt.Name = "LetInPrompt"
	doorPrompt.ActionText = "Let In"
	doorPrompt.ObjectText = "New Guests (0)"
	doorPrompt.Style = Enum.ProximityPromptStyle.Custom
	doorPrompt.MaxActivationDistance = 12
	doorPrompt.RequiresLineOfSight = false
	doorPrompt.HoldDuration = 0.3
	doorPrompt:SetAttribute("Icon", "door")
	doorPrompt:SetAttribute("Color", "blue")
	doorPrompt.Enabled = false
	doorPrompt.Parent = NAV.DoorPrompt
	doorPrompt.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player); return end
		if #queue == 0 then return end
		sfx("door", doorPrompt.Parent.Position)
		local let = letIn()
		if let == 0 then
			Notify:FireClient(player, "toast", { text = "No clean rooms! Clean one first.", icon = "roomDirty", bad = true })
		else
			Notify:FireClient(player, "toast", { text = "Let in " .. let .. (let == 1 and " guest" or " guests"), icon = "door" })
		end
	end)
end

-- sliding doors: open for anyone (player or guest) close by
do
	local doors = HOTEL.Doors
	local centre = O + Vector3.new(0, 0, 30.2)
	local open = false
	local tweens = {}
	local function slide(o)
		if o == open then return end
		open = o
		for _, d in ipairs(doors:GetChildren()) do
			local side = d:GetAttribute("Side")
			-- capture the closed CFrame at RUNTIME from where the door actually is now.
			-- the "Closed" attribute was saved at edit time and goes stale the moment this
			-- hotel is cloned to a different plot: doors would tween away to the template's
			-- old coordinates, looking like a duplicated door somewhere else
			local base = d:FindFirstChild("ClosedCF")
			if not base then
				base = Instance.new("CFrameValue")
				base.Name = "ClosedCF"
				base.Value = d:GetPivot()
				base.Parent = d
			end
			local v = d:FindFirstChild("Slide") or Instance.new("CFrameValue")
			v.Name = "Slide"
			if not v.Parent then
				v.Value = base.Value
				v.Parent = d
				v.Changed:Connect(function(cf) d:PivotTo(cf) end)
			end
			local goal = o and base.Value * CFrame.new(side * 4.6, 0, 0) or base.Value
			if tweens[d] then tweens[d]:Cancel() end
			tweens[d] = TweenService:Create(v, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = goal })
			tweens[d]:Play()
		end
	end
	task.spawn(function()
		while running do
			local near = false
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r and flat(r.Position - centre).Magnitude < 8 then near = true end
			end
			-- round 14: guests standing in the line outside no longer hold the doors open (the head of the line is
			-- about 10 studs out); only someone walking through, or right at the glass, opens them
			for g in pairs(guests) do
				if g.root then
					local d = flat(g.root.Position - centre).Magnitude
					if d < 5 or (d < 8.5 and g.root.AssemblyLinearVelocity.Magnitude > 1.5) then near = true end
				end
			end
			slide(near)
			task.wait(0.15)
		end
	end)
end

---------------------------------------------------------------- staff (hired in build mode or the menu; Hotel attributes Janitors / Doormen / Receptionists)

evCtx.staff = staff
evCtx.topNote = topNote
evCtx.kitchen = Kitchen.new(evCtx) -- meals (round 10c): stoves, the pass, orders and the cook's work
evCtx.upkeep = require(game.ServerStorage:WaitForChild("Upkeep")).new(evCtx) -- round 11: breakdowns, luggage, lost & found
local STAFF_NAMES = { "Rosa", "Gus", "Mabel", "Theo", "Ines", "Walt", "Pearl", "Otto", "Hugo", "Nell", "Ivo", "Dot", "Bea", "Rex" }
local STAFF_HOME = { janitor = {}, doorman = { O + Vector3.new(6, 4, 34), O + Vector3.new(-6, 4, 34) }, cook = {} } -- where idle staff stand
for i = 1, 6 do
	table.insert(STAFF_HOME.janitor, O + Vector3.new(26 + ((i - 1) % 3) * 4, 4, 6 + (i - 1) // 3 * 3.5))
	table.insert(STAFF_HOME.cook, O + Vector3.new(-26 + ((i - 1) % 3) * 4, 4, 4 + (i - 1) // 3 * 3.5))
end
STAFF_HOME.handyman = { STAFF_HOME.janitor[6], STAFF_HOME.cook[6] }

-- the n-th receptionist's post: one per desk (round 10b), the lobby desk first, then desks bought in build mode.
-- Returns where to stand, where to look and the desk's SeatSpot; with fewer desks than receptionists the extra
-- one stands beside the lobby desk (a desk was sold while they were hired)
local function receptionSpot(index)
	local desk = Build.desks(HOTEL)[index]
	if desk then
		local piv = desk:GetPivot()
		return (piv * CFrame.new(0, 3, -2.4)).Position, (piv * CFrame.new(0, 3, 5)).Position, desk:FindFirstChild("SeatSpot"), desk
	end
	local main = NAV.Receptionist
	local look = main:GetAttribute("Look")
	local fwd = look and flat(look - main.Position) or Vector3.new(0, 0, 1)
	if fwd.Magnitude < 0.1 then fwd = Vector3.new(0, 0, 1) end
	local off = Vector3.new(-fwd.Unit.Z, 0, fwd.Unit.X) * (index % 2 == 0 and 4 or -4)
	return main.Position + off, look and look + off
end
-- round 13: looks and jobs live in evCtx (this function is at Luau's local limit).
-- evCtx.looks: hotel attribute StaffLooks (JSON, "janitor1" -> a Shared.StaffLook look). A new hire gets a default look
-- that's saved straight away, so everyone keeps their face and outfit for good unless you change it.
-- evCtx.jobs: hotel attribute StaffJobs (JSON, "janitor1" -> { focus, shift, rooms = { room ids } }).
evCtx.looks, evCtx.jobs = {}, {}
pcall(function() evCtx.looks = HttpService:JSONDecode(HOTEL:GetAttribute("StaffLooks") or "{}") end)
pcall(function() evCtx.jobs = HttpService:JSONDecode(HOTEL:GetAttribute("StaffJobs") or "{}") end)
evCtx.saveLooks = function() HOTEL:SetAttribute("StaffLooks", HttpService:JSONEncode(evCtx.looks)) end
evCtx.saveJobs = function() HOTEL:SetAttribute("StaffJobs", HttpService:JSONEncode(evCtx.jobs)) end
evCtx.job = function(st) return evCtx.jobs[st.def.id .. st.index] or {} end
-- round 14 (2026-11-09): who each hire is (Shared.Hiring profile: name, voice, skill, pro, con, wage), hotel attribute StaffProfiles
evCtx.Hiring = require(RS.Shared:WaitForChild("Hiring"))
evCtx.profiles = function()
	local ok, t = pcall(function() return HttpService:JSONDecode(HOTEL:GetAttribute("StaffProfiles") or "{}") end)
	return ok and type(t) == "table" and t or {}
end
evCtx.setProfile = function(key, p)
	local t = evCtx.profiles()
	t[key] = p
	HOTEL:SetAttribute("StaffProfiles", HttpService:JSONEncode(t))
end
evCtx.shiftProfiles = function(def, idx)
	local t = evCtx.profiles()
	for j = idx, def.max - 1 do t[def.id .. j] = t[def.id .. (j + 1)] end
	t[def.id .. def.max] = nil
	HOTEL:SetAttribute("StaffProfiles", HttpService:JSONEncode(t))
end
-- a day-shift worker rests at night, a night-shift one by day
evCtx.offShift = function(st)
	local sh = evCtx.job(st).shift
	local night = RS.Shared:GetAttribute("Night") and true or false
	return (sh == "day" and night) or (sh == "night" and not night)
end
evCtx.rmul = function(stat) return Research.mul(HOTEL, stat) end
task.spawn(StaffLook.ensureParts)

-- a staff body: their saved look (plain base body, then Shared.StaffLook's part-built uniform, headwear and props)
local function makeStaff(def, index)
	local key = def.id .. index
	local prof = evCtx.profiles()[key]
	if type(prof) ~= "table" then
		local old = evCtx.looks[key] and evCtx.looks[key].name or STAFF_NAMES[(index + (StaffLook.ROLE_N[def.id] or 0) - 1) % #STAFF_NAMES + 1]
		prof = evCtx.Hiring.legacy(def, index, old)
		evCtx.setProfile(key, prof)
	end
	local fallback = StaffLook.default(def.id, index, prof.name)
	local look = StaffLook.clean(def.id, evCtx.looks[key] or fallback, Research.hasPerk(HOTEL, "uniforms"), fallback)
	if not evCtx.looks[key] then
		evCtx.looks[key] = look
		evCtx.saveLooks()
	end
	local desc = Instance.new("HumanoidDescription")
	desc.HairAccessory = look.hair > 0 and tostring(C.HAIR[look.hair]) or ""
	desc.Face = C.FACES[look.face] or 0
	local skin = C.SKIN[look.skin] or C.SKIN[1]
	desc.HeadColor, desc.TorsoColor, desc.LeftArmColor, desc.RightArmColor, desc.LeftLegColor, desc.RightLegColor = skin, skin, skin, skin, skin, skin
	local model = makeBody(look.name, desc)
	if not model then return nil end
	model:SetAttribute("LookHair", look.hair)
	local g = {
		name = look.name, model = model, alive = true, staff = def.id,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
		head = model:WaitForChild("Head"),
	}
	g.prof = prof
	g.hum.WalkSpeed = C.STAFF_WALK * evCtx.Hiring.walk(prof)
	model:SetAttribute("Voice", prof.voice)
	model:SetAttribute("Deep", prof.deep and true or nil)
	model:SetAttribute("StaffSkill", prof.skill)
	model:SetAttribute("TraitPro", prof.pro)
	model:SetAttribute("TraitCon", prof.con)
	model:SetAttribute("Wage", prof.wage)
	model:SetAttribute("Staff", def.id)
	model:SetAttribute("StaffKey", key)
	local refs = StaffLook.dress(model, def.id, look)
	g.mopWeld, g.mopRest, g.toolWeld, g.toolRest = refs.mopWeld, refs.mopRest, refs.toolWeld, refs.toolRest
	makeBubble(g)
	model:SetAttribute("BRole", def.name)
	model:SetAttribute("BRoleColor", StaffLook.colors(look).main:Lerp(Color3.new(1, 1, 1), 0.45))
	return g
end

local function idle(g, home, look)
	status(g, "sleep", "Waiting for work")
	if flat(g.root.Position - home).Magnitude > 2 then walkTo(g, home) end
	faceTo(g, look or (home + Vector3.new(0, 0, 10)))
end

-- sweep the mop while working; fills the status bar
local function mopWork(g, secs)
	barTimer(g, secs)
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < secs do
		local t = os.clock() - t0
		if t < 0.1 then play(g, "@mop") end -- round 14: the clients sweep the whole body (Shared.NPCAnimLib)
		task.wait(0.1)
	end
	stop(g, "@mop")
end

-- round 27: work that touches the thing. workPoint finds the spot on `model` to work on from where they stand
-- ("top": on its top, `inset` studs in from the near edge; "face": on its near face at chest height) and where to
-- stand for it. workOn steps them up to it, publishes the point (model attribute WorkAt) and plays the pose:
-- every client then puts the hands on that point (Shared.NPCAnimLib anchored poses, StarterPlayerScripts.NPCAnim).
do
	local workParams = RaycastParams.new()
	workParams.FilterType = Enum.RaycastFilterType.Include
	evCtx.workPoint = function(g, model, mode, inset, fallY)
		local sp = g.root.Position
		local dir = flat(model:GetPivot().Position - sp)
		local dist = dir.Magnitude
		if dist < 0.2 then return nil end
		dir = dir.Unit
		local floorY = sp.Y - (g.hum.HipHeight + g.root.Size.Y / 2)
		workParams.FilterDescendantsInstances = { model }
		local from = Vector3.new(sp.X, floorY + (mode == "face" and 3.9 or mode == "low" and 1.9 or 1.3), sp.Z)
		local hit = workspace:Raycast(from, dir * (dist + 0.5), workParams)
		local face = hit and hit.Position or (from + dir * math.max(dist - 1.5, 0.5))
		local at = face
		if mode == "top" then
			local p = face + dir * inset
			local top = workspace:Raycast(Vector3.new(p.X, floorY + 5.5, p.Z), Vector3.new(0, -5.2, 0), workParams)
			local y = top and top.Position.Y or (floorY + fallY)
			at = Vector3.new(p.X, math.clamp(y, floorY + 0.8, floorY + 4.2), p.Z)
		end
		return at, Vector3.new(face.X, sp.Y, face.Z) - dir * (mode == "low" and 1.9 or 1.25)
	end
	-- steps up to the thing and publishes the work point; false if there's nothing to put the hands on
	evCtx.workStart = function(g, model, mode, inset, fallY)
		if mode == "inside" then
			-- a walk-in shower: stood inside it, facing the back wall
			if not (model and model.Parent) or g.posed then return false end
			local piv = model:GetPivot()
			local look = flat(piv.LookVector)
			if look.Magnitude < 0.1 then return false end
			local sp = g.root.Position
			local floorY = sp.Y - (g.hum.HipHeight + g.root.Size.Y / 2)
			local p, a = piv * Vector3.new(0, 0, -0.4), piv * Vector3.new(0.2, 0, -2.3)
			local stand = Vector3.new(p.X, sp.Y, p.Z)
			g.workBack = g.root.CFrame
			pose(g, CFrame.lookAt(stand, stand + look.Unit))
			g.model:SetAttribute("WorkAt", Vector3.new(a.X, floorY + 3.7, a.Z))
			return true
		end
		local at, stand
		if model and model.Parent then at, stand = evCtx.workPoint(g, model, mode, inset, fallY) end
		if not at then return false end
		if flat(stand - g.root.Position).Magnitude > 0.5 and not g.posed then
			g.hum:MoveTo(stand)
			local t0 = os.clock()
			while g.alive and os.clock() - t0 < 1.8 and flat(stand - g.root.Position).Magnitude > 0.45 do task.wait(0.1) end
			g.hum:Move(Vector3.zero)
		end
		faceTo(g, at)
		g.model:SetAttribute("WorkAt", at)
		return true
	end
	evCtx.workEnd = function(g)
		g.model:SetAttribute("WorkAt", nil)
		if g.workBack then
			unpose(g, g.workBack)
			g.workBack = nil
		end
	end
	evCtx.workOn = function(g, poseName, secs, model, mode, inset, fallY)
		if not evCtx.workStart(g, model, mode, inset, fallY) then poseName = "mop" end
		barTimer(g, secs)
		play(g, "@" .. poseName)
		local t0 = os.clock()
		while g.alive and os.clock() - t0 < secs do task.wait(0.1) end
		stop(g, "@" .. poseName)
		evCtx.workEnd(g)
	end
	-- what each room job looks like: pose, mode, inset, fallback height
	evCtx.WORK = { Bed = { "makebed", "top", 0.8, 2.4 }, Toilet = { "scrub", "top", 0.6, 1.7 }, Shower = { "wipe", "inside" } }
end

-- where a janitor stands for each job (follows furniture that was moved)
local function workSpot(room, task)
	if task == "Bed" then return bedSide(room)
	elseif task == "Shower" then return coreSpot(room, "Shower", "front")
	elseif task == "Toilet" then return coreSpot(room, "Toilet", "front") end
	local p = room.spots.Floor.Position
	return Vector3.new(p.X, 4, p.Z)
end

local staffPace, staffGain, staffTag, idleJob
do
---------------------------------------------------------------- staff levels, the staff room, idle jobs and talking (round 10e)
-- Every staff member earns XP for their jobs (and a little for each minute on shift), saved in the hotel
-- attribute StaffXP (JSON, "janitor1" -> xp). Levels come slowly (STAFF_LV) and each one makes them 7% quicker.
-- Once you have STAFF_ROOM_AT staff they want a staff room (Staff Lockers): without one they work 30% slower
-- and say so. With nothing to do they tidy the lobby or take a break at the Break Table / lockers (more at night).
local STAFF_LV = { 0, 60, 160, 320, 560 }
local STAFF_ROOM_AT = 3
local staffXP = {}
pcall(function() staffXP = HttpService:JSONDecode(HOTEL:GetAttribute("StaffXP") or "{}") end)
local function staffKey(s) return s.def.id .. s.index end
local function staffLevel(s)
	local xp, lv = staffXP[staffKey(s)] or 0, 1
	for i, need in ipairs(STAFF_LV) do if xp >= need then lv = i end end
	return lv
end
staffTag = function(s)
	s.role = s.role or s.g.model:GetAttribute("BRole") or s.def.name
	s.g.model:SetAttribute("BRole", s.role .. "  LV " .. staffLevel(s))
end
local xpDirty = false
staffGain = function(s, n)
	if not s.g.alive then return end
	local before = staffLevel(s)
	staffXP[staffKey(s)] = (staffXP[staffKey(s)] or 0) + n * Research.mul(HOTEL, "staffXP") * evCtx.Hiring.xp(s.g.prof)
	xpDirty = true
	local lv = staffLevel(s)
	if lv > before then
		staffTag(s)
		say(s.g, pick({ "I'm getting good at this!", "Level up! Feeling sharp.", "Practice makes perfect!" }), 2.5)
		sparkleBurst(s.g.head.Position)
		tell("toast", { text = s.g.name .. " is now a level " .. lv .. " " .. s.def.name:lower(), icon = s.def.icon })
	end
end
local function placedWith(tag)
	local out = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		local it = Catalog.ITEMS[m:GetAttribute("Item") or ""]
		if it and it.tags and table.find(it.tags, tag) then table.insert(out, m) end
	end
	return out
end
local function staffCount()
	local n = 0
	for _, s in ipairs(staff) do if s.g.alive then n += 1 end end
	return n
end
local function needsStaffRoom() return staffCount() >= STAFF_ROOM_AT and #placedWith("staffroom") == 0 end
-- round 15: what Conversations needs from the sim
evCtx.pick = pick
evCtx.Life = Life
evCtx.weather = function() return Life.weather() end
evCtx.isNight = function() return Clock.isNight(Clock.now()) end
evCtx.lobbyAppeal = function() return lobbyAppeal end
evCtx.guestList = function() return guests end
evCtx.staffList = function() return staff end
evCtx.staffGain = function(s, n) return staffGain(s, n) end
evCtx.staffLevel = staffLevel
evCtx.needsStaffRoom = needsStaffRoom
evCtx.charge = function(player, amt)
	local owner = Players:GetPlayerByUserId(HOTEL:GetAttribute("Owner") or 0) or player
	local cash = owner:GetAttribute("Cash") or 0
	if cash < amt then return false end
	owner:SetAttribute("Cash", cash - amt)
	owner:SetAttribute("Spent", (owner:GetAttribute("Spent") or 0) + amt)
	return true
end
-- how long a job takes: quicker with levels, slower with no staff room
staffPace = function(s)
	-- round 13: Staff Training (and other) research shortens each role's jobs
	local stat = ({ janitor = "janitorTime", doorman = "doormanTime", receptionist = "deskTime", cook = "cookTime", handyman = "handymanTime" })[s.def.id]
	local tired = ((s.energy or 100) < 25 and 1.25 or 1) * ((s.restedAt and os.clock() - s.restedAt < 180) and 0.85 or 1) -- round 14
	return (1 - 0.07 * (staffLevel(s) - 1)) * (needsStaffRoom() and 1.3 or 1) * (stat and Research.mul(HOTEL, stat) or 1) * tired * evCtx.Hiring.pace(s.g.prof)
end
task.spawn(function()
	local warned, tick = false, 0
	while running do
		task.wait(5)
		tick += 1
		if tick % 12 == 0 then
			for _, s in ipairs(staff) do staffGain(s, 1) end -- a minute on shift
		end
		if xpDirty then
			xpDirty = false
			HOTEL:SetAttribute("StaffXP", HttpService:JSONEncode(staffXP))
		end
		if tick % 4 == 0 then
			if needsStaffRoom() then
				if not warned then
					warned = true
					tell("phone", { from = "Your staff", icon = "staff", text = "There are " .. staffCount() .. " of us now and nowhere to keep our things. Could we get a staff room? Staff Lockers are in Build, under Staff. We're slower without one." })
				end
				local s = staff[rng:NextInteger(1, #staff)]
				if s and s.g.alive and rng:NextNumber() < 0.5 then say(s.g, "We really need a staff room...", 2.6) end
			else
				warned = false
			end
		end
	end
end)

local function lobbyPoint()
	local z = HOTEL:FindFirstChild("BuildZones") and HOTEL.BuildZones:FindFirstChild("Lobby")
	if not z then return nil end
	local p = z.CFrame * Vector3.new(rng:NextNumber(-0.3, 0.3) * z.Size.X, 0, rng:NextNumber(-0.3, 0.3) * z.Size.Z)
	return Vector3.new(p.X, 4, p.Z)
end
local function breakSpot()
	local t = placedWith("staffbreak")
	if #t == 0 then t = placedWith("staffroom") end
	if #t == 0 then return nil end
	local cf = t[rng:NextInteger(1, #t)]:GetPivot()
	local p = (cf * CFrame.new(rng:NextNumber(-1.5, 1.5), 0, -3)).Position
	return Vector3.new(p.X, 4, p.Z), cf.Position
end
local function dirtyWaiting()
	for _, room in pairs(rooms) do
		if room.state == "Dirty" and (not room.cleaner or not room.cleaner.alive) then return true end
	end
	return false
end
-- round 20: idle small talk between colleagues
local IDLE_CHAT = {
	"Did you see the guest in 204?", "I heard we might get a pool.", "This place runs on coffee, I swear.",
	"You catch the game last night?", "My feet are killing me.", "Same old, same old.",
	"New manager's doing alright, I think.", "Six years and they still haven't changed the lobby music.",
}
-- something to do while there's no work
idleJob = function(s)
	local g = s.g
	local night = Clock.isNight(Clock.now())
	local r = rng:NextNumber()
	local bp, look = breakSpot()
	if bp and r < (night and 0.6 or 0.3) then
		status(g, "food", "On a break")
		walkTo(g, bp)
		faceTo(g, look)
		if rng:NextNumber() < 0.5 then say(g, pick({ "Coffee time.", "Ahh, a sit down.", "Five minutes...", "Busy day!", "My feet hurt." }), 2.5) end
		play(g, "@break")
		local t0, secs = os.clock(), range({ 8, 14 })
		while g.alive and os.clock() - t0 < secs and not dirtyWaiting() do task.wait(0.5) end
		stop(g, "@break")
		return
	end
	local dusty = dustyItems()
	local janitor = s.def.id == "janitor" -- round 27: only janitors carry a mop and a duster
	if janitor and #dusty > 0 and r < 0.85 then
		local m = dusty[rng:NextInteger(1, #dusty)]
		local piv = m:GetPivot().Position
		local dir = flat(piv - g.root.Position)
		if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
		status(g, "walk", "Dusting the decor")
		walkTo(g, Vector3.new(piv.X - dir.Unit.X * 2.8, 4, piv.Z - dir.Unit.Z * 2.8))
		if not g.alive or not isDusty(m) then return end
		faceTo(g, piv)
		status(g, "clean", "Dusting", "blue")
		evCtx.workOn(g, "dust", range({ 3.2, 4.5 }) * staffPace(s), m, "top", 0.35, 2.6)
		if isDusty(m) then setDusty(m, false) end
		staffGain(s, 2)
		return
	end
	if janitor and r < 0.75 then
		local p = lobbyPoint()
		if p then
			status(g, "walk", "Tidying the lobby")
			walkTo(g, p)
			status(g, "clean", "Tidying the lobby", "blue")
			mopWork(g, range({ 3, 5 }))
			staffGain(s, 1)
			return
		end
	end
	-- round 20: idle staff keep living: a chat with a nearby colleague, or a slow wander round the floor
	local r3 = rng:NextNumber()
	local mate
	for _, o in ipairs(staff) do
		if o ~= s and o.g.alive and flat(o.g.root.Position - g.root.Position).Magnitude < 45 then mate = o break end
	end
	if mate and r3 < 0.5 then
		local mp = mate.g.root.Position
		local dir = flat(g.root.Position - mp)
		if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
		status(g, "guest", "Chatting with " .. mate.g.name)
		walkTo(g, Vector3.new(mp.X + dir.Unit.X * 3, 4, mp.Z + dir.Unit.Z * 3))
		if not g.alive then return end
		faceTo(g, mp)
		say(g, pick(IDLE_CHAT), 3)
		task.delay(1.4, function()
			if g.alive and mate.g.alive then say(mate.g, pick(IDLE_CHAT), 3) end
		end)
		task.wait(range({ 4, 6 }))
		return
	end
	if r3 < 0.8 then
		status(g, "walk", "Stretching their legs")
		walkTo(g, s.home + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9)))
		if not g.alive then return end
		local r4 = rng:NextNumber()
		if r4 < 0.3 then play(g, "look_watch") elseif r4 < 0.55 then play(g, "stretch") elseif r4 < 0.75 then play(g, "scratch_head") end
		task.wait(range({ 2, 4 }))
		return
	end
	idle(g, s.home)
	-- round 14: nobody stands frozen: a stretch, a glance at the watch, a yawn on a slow night
	local r2 = rng:NextNumber()
	if r2 < 0.22 then play(g, "look_watch") elseif r2 < 0.36 then play(g, "stretch") elseif r2 < 0.46 and night then play(g, "yawn")
	elseif r2 < 0.56 then play(g, "scratch_head") end
	task.wait(range({ 3, 5 }))
end

local STAFF_TALK = {
	hi = { "Hi boss!", "Oh, hey boss!", "Need something?", "Reporting for duty!", "Hey! Busy day.",
		"Boss! Just the person.", "All quiet on my floor.", "You look like you need coffee. Same.",
		"Working hard, hardly working!", "Hi! Don't mind the mess, it's organised mess." },
	hiNight = { "Quiet night, boss.", "Night shift, boss. Somebody's got to.", "The lobby's so peaceful at night.",
		"I'm on it, don't worry. Just... slower.", "Yawn... sorry. Coffee's brewing." },
	hiWeather = {
		rain = { "Wet one out there, boss.", "Umbrella by the door, remember!" },
		storm = { "That thunder! I nearly dropped my mop.", "Storm's rattling the windows something fierce." },
		snow = { "Snow! I swept the step twice already.", "It's a winter wonderland out there, boss." },
		fog = { "Can't see the road from the door.", "Spooky fog tonight." },
	},
	noRoom = { "Honestly? We need a staff room.", "It'd be nice to have lockers somewhere.", "Where am I meant to put my coat?",
		"A break room, boss. Even a chair!", "My thermos lives in a broom cupboard. A staff room would fix that." },
	good = {
		janitor = { "Every room spotless, boss.", "Mopping is an art, you know.", "I found a sock under a bed. Again.",
			"Room 102's floor? Mirror finish.", "You could eat off the lobby tiles. Please don't.", "The carts practically steer themselves now." },
		doorman = { "Lots of people out there today!", "I've got a great welcome going.", "The door's never looked better.",
			"I held the door for a VIP today. Nailed it.", "My welcome wave is getting famous.", "Tips of the hat, boss. That's my currency." },
		receptionist = { "The desk is running smooth.", "Keys, smiles, check-ins. Easy.", "Guests seem happy at check-in.",
			"Checked in a whole tour group. Didn't even flinch.", "I remember everyone's name. Everyone.", "The ledger balances to the cent, boss." },
		cook = { "Kitchen's running hot!", "Nobody's sent a plate back yet.", "I'm trying a new recipe.",
			"Today's special? You'll just have to order it.", "I've plated so much food I dream in garnish.", "The breakfast rush? Handled. Barely." },
		handyman = { "Everything's ticking along nicely.", "That vending machine and I have history.", "If it squeaks, I fix it.",
			"Fixed three leaks before breakfast.", "My toolkit and I are ready for anything.", "The boiler and I have an understanding now." },
	},
	need = {
		janitor = { "More janitors would help when it's busy.", "A second mop bucket would change my life." },
		doorman = { "A nicer lobby keeps the line patient.", "A mat outside would save my floors. And my soul." },
		receptionist = { "Another desk would cut the queue.", "A bell for the desk. Ding ding!" },
		cook = { "More tables means more hungry guests.", "A bigger kitchen, boss. I'm dreaming small." },
		handyman = { "Old machines break more. Keep me busy!", "A workshop corner would be lovely." },
	},
	praise = { "Thanks boss! That means a lot.", "Aw, cheers!", "I'll keep it up!", "You noticed! Best shift ever.", "I'm putting that in my performance review. The one I write myself." },
	praiseAgain = { "Ha, you said that already.", "Thanks... again!", "Okay, okay, I get it!", "Save it for my raise, boss.", "Two compliments in one day? I'm glowing." },
	bye = { "See you, boss!", "Back to work!", "Later!", "Off like a shot!", "You know where to find me!" },
}
local function staffInfo(s, line, feel)
	local lv = staffLevel(s)
	local xp = staffXP[staffKey(s)] or 0
	local nextNeed = STAFF_LV[lv + 1]
	local morale = Conv.morale(evCtx, s)
	if s.g.model then s.g.model:SetAttribute("Mood", morale) end
	return {
		guest = s.g.model, name = s.g.name, line = line, staff = true, feel = feel, options = Conv.staffOptions(evCtx, s),
		role = s.def.name, energy = math.floor(s.energy or 100), level = lv,
		mood = morale, moodWord = moodWord(morale), stars = lv,
		review = "Level " .. lv .. " " .. s.def.name:lower() .. (nextNeed and ("  -  " .. xp .. " / " .. nextNeed .. " XP") or "  -  top level"),
		sub = s.def.blurb .. "  -  $" .. (s.def.wage or 0) .. " a day",
	}
end
talkStaff = function(s, player)
	if not isMember(player) then notMine(player) return end
	local g = s.g
	if not g.alive then return end
	-- round 17: the opener fits the moment (night shift, weather) before falling back to a plain hi
	local line
	if Clock.isNight(Clock.now()) and rng:NextNumber() < 0.5 then
		line = pick(STAFF_TALK.hiNight)
	elseif rng:NextNumber() < 0.2 then
		local wl = STAFF_TALK.hiWeather[Life.weather()]
		if wl then line = pick(wl) end
	end
	if not line then line = pick(STAFF_TALK.hi) end
	g.talkUntil, g.talkPlayer = os.clock() + 40, player
	s.convNext = nil
	holdFace(g, player)
	say(g, line, 2.5)
	feelUp(g, needsStaffRoom() and "tired" or "happy", false)
	if not g.posed then
		faceTo(g, player.Character and player.Character:GetPivot().Position)
		play(g, "nod")
	end
	Notify:FireClient(player, "talk", staffInfo(s, line))
end
staffReply = function(s, player, option, preLine, preFeel, preAct)
	local g = s.g
	local line, feel, act = preLine, preFeel, preAct
	if line then
		-- Conversations answered
	elseif option == "stay" then
		line = needsStaffRoom() and pick(STAFF_TALK.noRoom) or pick(STAFF_TALK.good[s.def.id] or STAFF_TALK.hi)
		feel = needsStaffRoom() and "sad" or "proud"
	elseif option == "need" then
		local needList = STAFF_TALK.need[s.def.id]
		line = needsStaffRoom() and "A staff room. Lockers, a table, anything!" or (needList and pick(needList) or "I'm all good!")
		feel = "think"
	elseif option == "nice" then
		if not s.praisedAt or os.clock() - s.praisedAt > 300 then
			s.praisedAt = os.clock()
			staffGain(s, 5)
			line = pick(STAFF_TALK.praise)
			if not g.posed then play(g, "cheer") end
			feel, act = "excited", false
		else
			line = pick(STAFF_TALK.praiseAgain)
			feel = "shy"
		end
	else
		line = pick(STAFF_TALK.bye)
		if not g.posed then play(g, "wave_small") end
		feel, act = "happy", false
	end
	say(g, line, 3.5)
	feelUp(g, feel or "plain", act)
	Notify:FireClient(player, "talkReply", staffInfo(s, line, feel))
end

-- round 14: energy, breaks, firing and the front desk.
-- Energy (model attribute Energy, 0..100) drains while someone works; under 25 they slow down and ask for a
-- break, at 0 they take one themselves. A break (sent from the menu, or their own) walks them to the staff room
-- for a coffee (pose "break"), refills energy and leaves them quicker for a few minutes after.
-- Firing: they say goodbye, walk out the front, and everyone of that role above them moves down one slot
-- (looks, jobs and XP follow them), so nobody else changes.
evCtx.breakTime = function(s)
	local g = s.g
	if not g.alive then return false end
	if s.firing then
		if s.standUpNow then s.standUpNow() end
		status(g, "walk", "Leaving the hotel")
		stop(g, "@")
		walkTo(g, NAV.Inside.Position)
		walkTo(g, NAV.PathStart.Position)
		g.alive = false
		if g.model then g.model:Destroy() end
		return true
	end
	if not s.onBreak then return false end
	if s.standUpNow then s.standUpNow() end
	local bp, look = breakSpot()
	status(g, "walk", "Going on a break")
	if bp then
		walkTo(g, bp)
		faceTo(g, look)
	end
	if not g.alive then return true end
	status(g, "food", "On a break", "blue")
	play(g, "stretch")
	task.wait(1.2)
	play(g, "@break")
	say(g, pick({ "Ahh, coffee.", "Five minutes off my feet.", "Thanks, boss!", "I needed this.", "Don't tell the guests I'm sitting." }), 2.6)
	local secs = s.breakSecs or 40
	barTimer(g, secs, true)
	local t0 = os.clock()
	while g.alive and s.onBreak and not s.firing and os.clock() - t0 < secs do
		task.wait(0.25)
		s.energy = math.min(100, (s.energy or 100) + 0.25 * 100 / secs * 1.2 * evCtx.Hiring.rest(g.prof))
		g.model:SetAttribute("Energy", math.floor(s.energy))
	end
	stop(g, "@break")
	s.onBreak, s.breakSecs = false, nil
	g.model:SetAttribute("OnBreak", nil)
	if s.firing or not g.alive then return true end
	s.energy = 100
	s.restedAt = os.clock()
	g.model:SetAttribute("Energy", 100)
	play(g, "stretch")
	say(g, pick({ "Back to work!", "Right, where was I?", "Feeling fresh!", "Okay, let's go!" }), 2.2)
	task.wait(1.4)
	return true
end
evCtx.sendBreak = function(s, on)
	if s.firing then return end
	s.onBreak = on and true or false
	s.breakSecs = on and 40 or nil
	s.g.model:SetAttribute("OnBreak", on and true or nil)
	evCtx.wageBill()
end
-- fire someone: slots above them move down one so everybody else keeps their look, job and XP
evCtx.fire = function(s)
	if s.firing then return end
	local def, idx = s.def, s.index
	local n = HOTEL:GetAttribute(def.attr) or 0
	s.firing = true
	s.onBreak = false
	local i = table.find(staff, s)
	if i then table.remove(staff, i) end
	local same = {}
	for _, o in ipairs(staff) do if o.def == def then table.insert(same, o) end end
	table.sort(same, function(a, b) return a.index < b.index end)
	for j = idx, def.max - 1 do
		local a, b = def.id .. j, def.id .. (j + 1)
		evCtx.looks[a], evCtx.jobs[a], staffXP[a] = evCtx.looks[b], evCtx.jobs[b], staffXP[b]
	end
	local top = def.id .. def.max
	evCtx.looks[top], evCtx.jobs[top], staffXP[top] = nil, nil, nil
	evCtx.shiftProfiles(def, idx)
	for _, o in ipairs(same) do
		if o.index > idx then
			o.index -= 1
			o.g.model:SetAttribute("StaffKey", def.id .. o.index)
			staffTag(o)
		end
	end
	evCtx.saveLooks()
	evCtx.saveJobs()
	xpDirty = true
	HOTEL:SetAttribute(def.attr, math.max(0, n - 1))
	say(s.g, pick({ "Oh... okay. Thanks for having me.", "Really? Well, good luck, boss.", "I'll get my coat.", "Fair enough. Take care!" }), 3)
	play(s.g, "shrug")
	s.g.model:SetAttribute("Staff", nil) -- off the team list straight away
	s.g.model:SetAttribute("BRole", "Leaving")
	evCtx.wageBill()
	tell("toast", { text = s.g.name .. " has left your team", icon = def.icon })
end
-- energy drains while working (every 5 s); tired staff ask for a break, exhausted ones take it
task.spawn(function()
	while running do
		task.wait(5)
		for _, s in ipairs(staff) do
			local g = s.g
			if g.alive and not s.onBreak and not s.firing then
				local off = evCtx.offShift(s)
				s.energy = math.clamp((s.energy or 100) + (off and 0.8 or -0.42 * evCtx.Hiring.drain(g.prof)), 0, 100)
				g.model:SetAttribute("Energy", math.floor(s.energy))
				if not off and s.energy < 25 and not s.askedBreak then
					s.askedBreak = true
					say(g, pick({ "I could really use a break...", "So... tired...", "Is it break time yet?" }), 3)
					play(g, "yawn")
					tell("toast", { text = g.name .. " is tired. Send them on a break from Staff", icon = s.def.icon })
				elseif s.energy >= 25 then
					s.askedBreak = nil
				end
				if s.energy <= 0 then evCtx.sendBreak(s, true) end
			end
		end
	end
end)
end

-- round 13: how fast the desk runs for an action (false = no receptionist on shift), and the wage bill
evCtx.staffPace = function(st) return staffPace(st) end
evCtx.deskPace = function(action)
	local n, pace = 0, 0
	for _, st in ipairs(staff) do
		if st.def.id == "receptionist" and st.g.alive and not evCtx.offShift(st) and not st.onBreak and not st.displaced and not st.firing then
			n += 1
			local f = evCtx.job(st).focus
			local k = (f == "in" and (action == "Check In" and 0.75 or 1.3)) or (f == "out" and (action == "Check Out" and 0.75 or 1.3)) or 1
			pace += staffPace(st) * k
		end
	end
	if n == 0 then return false end
	return (pace / n) / (1 + 0.6 * (n - 1))
end
-- round 14: one guest per receptionist at a time. Waiting guests are served in the order they reached the desk.
-- Returns true when served, false if they gave up, nil if no receptionist can serve (the player serves instead).
do
	local waiting = {} -- g -> time they reached the front of a desk line
	local function freeClerk()
		for _, st in ipairs(staff) do
			if st.def.id == "receptionist" and st.g.alive and not evCtx.offShift(st) and not st.onBreak
				and not st.displaced and not st.firing and not (st.serving and st.serving.alive) then
				return st
			end
		end
	end
	evCtx.serveDesk = function(g, secs, action)
		waiting[g] = os.clock()
		local t0 = os.clock()
		local clerk
		local shown = false
		while g.alive do
			if not evCtx.deskPace(action) then waiting[g] = nil return nil end
			-- first come, first served
			local first = true
			for o, t in pairs(waiting) do
				if o ~= g and o.alive and t < waiting[g] then first = false break end
			end
			if first then clerk = freeClerk() end
			if clerk then break end
			if not shown then
				shown = true
				status(g, "bell", "Waiting for the receptionist", "yellow")
				barTimer(g, patience(g), true, true)
			end
			if os.clock() - t0 > patience(g) then
				waiting[g] = nil
				say(g, pick({ "This is taking forever.", "Is anyone serving?", "Forget it." }), 2.6)
				return false
			end
			task.wait(0.2)
		end
		waiting[g] = nil
		if not g.alive then return false end
		clerk.serving = g
		local cg = clerk.g
		local f = evCtx.job(clerk).focus
		local k = (f == "in" and (action == "Check In" and 0.75 or 1.3)) or (f == "out" and (action == "Check Out" and 0.75 or 1.3)) or 1
		play(cg, "nod")
		say(cg, action == "Check In" and pick({ "Welcome! Name for the booking?", "Hi! Let me find your room.", "Checking in? Lovely." })
			or pick({ "Checking out? Hope you enjoyed it!", "How was your stay?", "Let me get your bill." }), 2.4)
		status(cg, "bell", (action == "Check In" and "Checking in " or "Checking out ") .. g.name, "green")
		play(cg, "@desk")
		status(g, "bell", action == "Check In" and "Checking in" or "Paying", "green")
		timed(g, secs * C.CLERK_SLOW * staffPace(clerk) * k)
		stop(cg, "@desk")
		if cg.alive then
			play(cg, "present")
			status(cg, "bell", "At the desk")
		end
		if clerk.serving == g then clerk.serving = nil end
		return g.alive
	end
end
evCtx.onShift = function(role)
	local n = 0
	for _, st in ipairs(staff) do
		if st.def.id == role and st.g.alive and not evCtx.offShift(st) then n += 1 end
	end
	return n
end
evCtx.wageBill = function()
	local total = 0
	for _, st in ipairs(staff) do
		if st.g.alive then total += (st.g.prof and st.g.prof.wage or st.def.wage or 0) * ((evCtx.job(st).shift or "all") ~= "all" and 0.6 or 1) end
	end
	total = math.floor(total * Research.mul(HOTEL, "wages") + 0.5)
	HOTEL:SetAttribute("WageBill", total)
	return total
end
table.insert(conns, HOTEL:GetAttributeChangedSignal("Research"):Connect(function() evCtx.wageBill() end))

local function janitorLife(s)
	local g = s.g
	while g.alive do
		if evCtx.breakTime(s) then continue end
		-- the nearest dirty room nobody is on yet (round 13: or the rooms they're assigned, and only on shift)
		local best, bestD
		local job = evCtx.job(s)
		local mine = {}
		for _, id in ipairs(type(job.rooms) == "table" and job.rooms or {}) do mine[tostring(id)] = true end
		local focus = next(mine) and job.focus or "nearest"
		if evCtx.offShift(s) then
			status(g, "sleep", "Off shift")
		else
			for _, room in pairs(rooms) do
				local isMine = mine[tostring(room.id)]
				if room.state == "Dirty" and (not room.cleaner or not room.cleaner.alive) and (focus ~= "only" or isMine) then
					local d = flat(room.nav.Door.Position - g.root.Position).Magnitude + ((focus == "first" and not isMine) and 5000 or 0)
					if not bestD or d < bestD then best, bestD = room, d end
				end
			end
		end
		if best then
			local room = best
			room.cleaner = g
			status(g, "walk", "Room " .. room.id)
			walkTo(g, room.nav.Door.Position)
			walkTo(g, room.nav.Enter.Position)
			for _, task in ipairs({ "Floor", "Bed", "Toilet", "Shower" }) do
				if not g.alive or room.state ~= "Dirty" then break end
				if room.tasks[task] then
					walkTo(g, workSpot(room, task))
					faceTo(g, room.spots[task].Position)
					if room.tasks[task] then
						status(g, C.TASK_ICON[task], "Cleaning", "blue")
						local secs = C.STAFF_CLEAN * (Research.hasPerk(HOTEL, "clean") and 0.7 or 1) * staffPace(s)
						local W = evCtx.WORK[task]
						if W then evCtx.workOn(g, W[1], secs, core(room, task), W[2], W[3], W[4]) else mopWork(g, secs) end
						room.clean(task, nil)
						staffGain(s, 2)
					end
				end
			end
			if room.cleaner == g then room.cleaner = nil end
			if g.alive then
				say(g, pick({ "All clean!", "Spotless!", "Next!", "Sparkling!" }), 2)
				walkTo(g, room.nav.Enter.Position)
				walkTo(g, room.nav.Door.Position)
			end
		else
			idleJob(s)
		end
	end
end

local function doormanLife(s)
	local g = s.g
	idle(g, s.home, s.home + Vector3.new(0, 0, 12))
	while g.alive do
		if evCtx.breakTime(s) then idle(g, s.home, s.home + Vector3.new(0, 0, 12)) continue end
		-- round 13: no more instant doors. Once a guest has waited C.DOORMAN_DELAY, the doorman walks out to them,
		-- greets them and takes their bags (C.DOORMAN_WORK, quicker with levels and research), then shows them in.
		-- Focus: warm (default, guests start happier), quick (faster, no boost) or vip (event guests first)
		local focus = evCtx.job(s).focus or "warm"
		local first = queue[1]
		local doormen = math.max(1, evCtx.onShift("doorman"))
		if evCtx.offShift(s) then
			if s.posing then s.posing = false stop(g, "@door") end
			status(g, "sleep", "Off shift")
			idleJob(s)
		elseif first and first.queuedAt and os.clock() - first.queuedAt > C.DOORMAN_DELAY / doormen and freeRoom() then
			local q = first
			if focus == "vip" then
				for _, c in ipairs(queue) do
					if c.event and not c.doorman then q = c break end
				end
			end
			if q.doorman and q.doorman ~= g and q.doorman.alive then
				q = nil
				for _, c in ipairs(queue) do
					if not (c.doorman and c.doorman.alive) then q = c break end
				end
			end
			if q then
				q.doorman = g
				stop(g, "@door")
				s.posing = false
				status(g, "walk", "Greeting " .. q.name)
				local to = q.root.Position
				local dir = flat(s.home - to)
				if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, 1) end
				walkTo(g, to + dir.Unit * 2.6, 1.5)
				if g.alive and q.alive and table.find(queue, q) then
					faceTo(g, q.root.Position)
					play(g, "bow")
					say(g, pick({ "Welcome to the hotel!", "Good to see you! Let me take those.", "Right this way, please.", "Lovely day for it! In you come." }), 2.6)
					status(g, "door", focus == "quick" and "Quick hello" or "Welcoming " .. q.name, "green")
					timed(g, C.DOORMAN_WORK * staffPace(s) * (focus == "quick" and 0.55 or 1))
					-- round 27: shows them the way in
					if g.alive and q.alive then
						faceTo(g, doorPrompt.Parent.Position)
						play(g, "present")
						task.wait(0.5)
					end
				end
				local at = table.find(queue, q)
				if g.alive and q.alive and at and freeRoom(q) then
					table.remove(queue, at)
					table.insert(queue, 1, q)
					sfx("door", doorPrompt.Parent.Position)
					if letIn(1) > 0 then
						if focus ~= "quick" then moodShift(q, 3) end
						staffGain(s, 2)
					end
				end
				if q.doorman == g then q.doorman = nil end
				if g.alive then
					walkTo(g, s.home, 1.5)
					faceTo(g, s.home + Vector3.new(0, 0, 10))
				end
			end
		elseif first and not freeRoom() then
			status(g, "roomDirty", "No clean rooms")
		else
			status(g, "door", "At the door")
			-- round 14: at ease by the door, hands behind the back, watching the street
			if not s.posing and flat(g.root.Position - s.home).Magnitude < 2.5 then s.posing = true play(g, "@door") end
		end
		task.wait(0.4)
	end
end

local function receptionistLife(s)
	local g = s.g
	status(g, "bell", "At the desk")
	local greeted = {}
	local seated -- the SeatSpot CFrame they sit at, while sitting
	local function sitDown()
		local post, look, seat = receptionSpot(s.index)
		s.home = post
		if seat then
			pose(g, seat.CFrame)
			play(g, "sit", 0.2)
			seated = seat.CFrame
		else
			faceTo(g, look)
		end
	end
	local function standUp()
		if not seated then return end
		stop(g, "sit", 0.2)
		stop(g, "@desk")
		unpose(g, CFrame.lookAt(s.home, s.home + flat(seated.LookVector)))
		seated = nil
	end
	-- round 14: a player who sits at this desk gets the chair; the receptionist steps aside until they leave
	s.standUpNow = function()
		if seated then
			standUp()
			local fwd = s.home and (s.home - g.root.Position) or Vector3.zero
			local side = Vector3.new(-3.2, 0, 0)
			local _, look = receptionSpot(s.index)
			if look then
				local f = flat(look - s.home)
				if f.Magnitude > 0.1 then side = Vector3.new(-f.Unit.Z, 0, f.Unit.X) * 3.4 end
			end
			g.model:PivotTo(CFrame.lookAt(s.home + side, s.home + side + (look and flat(look - s.home) or Vector3.new(0, 0, 1))))
			local _ = fwd
		end
	end
	sitDown()
	while g.alive do
		if evCtx.breakTime(s) then sitDown() continue end
		local post0, _, _, desk0 = receptionSpot(s.index)
		local chair = desk0 and desk0:FindFirstChild("DeskSeat")
		local taking = desk0 and os.clock() - (desk0:GetAttribute("PlayerTaking") or -9) < 1.5
		if chair and chair:IsA("Seat") and (chair.Occupant or taking) then
			if not s.displaced then
				s.displaced = true
				s.standUpNow()
				play(g, "nod")
				say(g, pick({ "All yours, boss!", "Take over? Sure!", "I'll be right here.", "Go for it!" }), 2.4)
				status(g, "bell", "Watching you work the desk")
				play(g, "@wait")
			end
			task.wait(0.15)
			continue
		elseif s.displaced then
			s.displaced = nil
			stop(g, "@wait")
			walkTo(g, post0)
			sitDown()
			say(g, pick({ "Back at it.", "Thanks for covering!", "I'll take it from here." }), 2)
		end
		-- the desk moved in build mode (or another was bought or sold): get up and go to the new post
		local post, _, seat, desk = receptionSpot(s.index)
		if (post - s.home).Magnitude > 1.5 or (seat == nil) ~= (seated == nil) then
			standUp()
			walkTo(g, post)
			sitDown()
		end
		-- greet whoever steps up to this desk
		local front = desk and (desk:GetPivot() * CFrame.new(0, 3, 3.4)).Position or NAV.DeskGuest.Position
		for q in pairs(guests) do
			if q.root and not greeted[q] and flat(q.root.Position - front).Magnitude < 2.5 then
				greeted[q] = true
				play(g, "wave_small")
				say(g, pick({ "Welcome! Checking in?", "Hi there, one moment.", "Good to see you!", "Hello! How can I help?" }), 2.5)
				staffGain(s, 1)
			end
		end
		-- round 14: between guests they work on the computer, with a look round now and then
		if seated and not s.serving then
			s.deskT = (s.deskT or 0) + 0.3
			if s.deskT > (s.deskNext or 6) then
				s.deskT, s.deskNext = 0, range({ 5, 11 })
				s.typing = not s.typing
				if s.typing then play(g, "@desk") else stop(g, "@desk") if rng:NextNumber() < 0.4 then play(g, "look_watch") end end
			end
		end
		task.wait(0.3)
	end
end

local function hire(def, index)
	local g = makeStaff(def, index)
	if not g then return end
	local home, look
	if def.id == "receptionist" then
		home, look = receptionSpot(index)
	else
		local homes = STAFF_HOME[def.id]
		home = homes[(index - 1) % #homes + 1]
	end
	local s = { def = def, g = g, index = index, home = home }
	staffTag(s)
	local tp = Instance.new("ProximityPrompt")
	tp.Name = "TalkPrompt"
	tp.ActionText = "Talk"
	tp.ObjectText = g.name
	tp.KeyboardKeyCode = Enum.KeyCode.F
	tp.GamepadKeyCode = Enum.KeyCode.ButtonY
	tp.HoldDuration = 0
	tp.MaxActivationDistance = 7
	tp.RequiresLineOfSight = false
	tp.Style = Enum.ProximityPromptStyle.Custom
	tp:SetAttribute("Icon", def.icon)
	tp:SetAttribute("Color", "gold")
	tp.Parent = g.root
	g.talkPrompt = tp
	tp.Triggered:Connect(function(player) talkStaff(s, player) end)
	g.model:PivotTo(CFrame.lookAt(home, look or (home + Vector3.new(0, 0, 10))))
	g.model.Parent = GUESTS
	setGroup(g.model, "Guests")
	loadAnims(g)
	table.insert(staff, s)
	local life = def.id == "janitor" and janitorLife or def.id == "receptionist" and receptionistLife
		or def.id == "cook" and function(st) evCtx.kitchen:cookLife(st) end
		or def.id == "handyman" and function(st) evCtx.upkeep:handymanLife(st, staffPace, staffGain, idleJob) end or doormanLife
	task.spawn(function()
		local ok, err = pcall(life, s)
		if not ok and g.alive and running then warn("Shared staff " .. g.name .. ": " .. tostring(err)) end
	end)
	return s
end

-- keep the staff in the world matching the Hotel attributes (one pass at a time; bodies take a moment to make)
local syncing, syncAgain = false, false
local function syncStaff()
	if syncing then syncAgain = true; return end
	syncing = true
	for _, def in ipairs(C.STAFF) do
		local want = math.clamp(HOTEL:GetAttribute(def.attr) or 0, 0, def.max)
		local have = {}
		for _, s in ipairs(staff) do if s.def == def then table.insert(have, s) end end
		for i = #have + 1, want do hire(def, i) end
		for i = #have, want + 1, -1 do
			local s = have[i]
			s.g.alive = false
			s.g.model:Destroy()
			table.remove(staff, table.find(staff, s))
		end
	end
	syncing = false
	evCtx.wageBill()
	if syncAgain then syncAgain = false; syncStaff() end
end

-- round 13: the wardrobe and job settings (StaffEdit). Remotes.StaffEdit:FireServer(action, key, data):
--   "look", key, look   -> saved in StaffLooks and dressed on the spot (the name goes through Roblox's filter)
--   "job", key, { focus, shift, rooms }
do
	local edit = RS.Shared.Remotes:FindFirstChild("StaffEdit")
	if not edit then
		edit = Instance.new("RemoteEvent")
		edit.Name = "StaffEdit"
		edit.Parent = RS.Shared.Remotes
	end
	local last = {}
	local function find(key)
		for _, st in ipairs(staff) do
			if st.g.alive and st.def.id .. st.index == key then return st end
		end
	end
	table.insert(conns, edit.OnServerEvent:Connect(function(player, action, key, data)
		if not isMember(player) or type(key) ~= "string" or type(data) ~= "table" then return end
		if os.clock() - (last[player] or 0) < 0.3 then return end
		last[player] = os.clock()
		local st = find(key)
		if not st then return end
		if action == "look" then
			local old = evCtx.looks[key] or StaffLook.default(st.def.id, st.index, st.g.name)
			local premium = Research.hasPerk(HOTEL, "uniforms")
			local look = StaffLook.clean(st.def.id, data, premium, old)
			if look.name ~= old.name then
				local ok, res = pcall(function()
					return game:GetService("TextService"):FilterStringAsync(look.name, player.UserId):GetNonChatStringForBroadcastAsync()
				end)
				if not ok or not res or res:find("#") or res:gsub("%s", "") == "" then
					look.name = old.name
					Notify:FireClient(player, "toast", { text = "That name can't be used", icon = "staff", bad = true })
				else
					look.name = res
				end
			end
			evCtx.looks[key] = look
			evCtx.saveLooks()
			local g = st.g
			g.name = look.name
			g.model.Name = look.name
			g.model:SetAttribute("BName", look.name)
			local refs = StaffLook.dress(g.model, st.def.id, look)
			g.mopWeld, g.mopRest, g.toolWeld, g.toolRest = refs.mopWeld, refs.mopRest, refs.toolWeld, refs.toolRest
			g.model:SetAttribute("BRoleColor", StaffLook.colors(look).main:Lerp(Color3.new(1, 1, 1), 0.45))
			g.model:SetAttribute("LookRev", (g.model:GetAttribute("LookRev") or 0) + 1)
			play(g, "cheer")
			say(g, pick({ "Looking sharp!", "Ooh, I like it!", "New look, who dis?", "Fits perfectly!" }), 2.5)
		elseif action == "fire" then
			evCtx.fire(st)
		elseif action == "break" then
			evCtx.sendBreak(st, not st.onBreak)
			if st.onBreak then say(st.g, pick({ "Ooh, thank you!", "A break? You're the best.", "Coffee time!" }), 2.4) play(st.g, "cheer")
			else say(st.g, pick({ "Back to it!", "Okay, okay, I'm going!" }), 2) end
		elseif action == "job" then
			local opts = StaffLook.FOCUS[st.def.id] or {}
			local job = {}
			for _, o in ipairs(opts) do if o[1] == data.focus then job.focus = o[1] end end
			for _, o in ipairs(StaffLook.SHIFTS) do if o[1] == data.shift then job.shift = o[1] end end
			if st.def.id == "janitor" and type(data.rooms) == "table" then
				job.rooms = {}
				for _, id in ipairs(data.rooms) do
					for _, room in pairs(rooms) do
						if tostring(room.id) == tostring(id) and #job.rooms < 24 then table.insert(job.rooms, room.id) break end
					end
				end
			end
			evCtx.jobs[key] = job
			evCtx.saveJobs()
			evCtx.wageBill()
			say(st.g, pick({ "You got it!", "On it, boss.", "Understood!", "Will do!" }), 2)
		end
	end))
end
for _, def in ipairs(C.STAFF) do
	HOTEL:GetAttributeChangedSignal(def.attr):Connect(function() task.spawn(syncStaff) end)
end
task.spawn(syncStaff)

---------------------------------------------------------------- NPC small talk (guests and staff chat with each other)

task.spawn(function()
	while running do
		task.wait(range({ 6, 14 }))
		-- NPCs standing still: guests and staff alike
		-- (not anyone in a line: the queue outside has its own chats and everyone there faces the door)
		local idle = {}
		for g in pairs(guests) do
			if g.alive and g.root and not g.posed and g.root.AssemblyLinearVelocity.Magnitude < 1
				and not queueSlot(g) and not table.find(deskLines["in"], g) and not table.find(deskLines.out, g)
				and not g.chatWith and not g.busyTalk and not g.wantsWord then
				table.insert(idle, g)
			end
		end
		for _, s in ipairs(staff) do
			local g = s.g
			if g and g.alive and g.root and not g.posed and g.root.AssemblyLinearVelocity.Magnitude < 1 and not g.busyTalk then
				table.insert(idle, g)
			end
		end
		-- the first pair within chatting distance stops and talks a moment
		for _, a in ipairs(idle) do
			local b
			for _, other in ipairs(idle) do
				if other ~= a and flat(other.root.Position - a.root.Position).Magnitude < 9 then
					b = other
					break
				end
			end
			local busy = function(g) return g.talkUntil and os.clock() < g.talkUntil end
			if b and not busy(a) and not busy(b) then
				-- round 15: staff talk like staff (to guests and to each other), guests like guests
				local STAFF_CHAT = {
					guest = { "Enjoying your stay?", "Let me know if you need anything!", "Breakfast's at eight.", "Lovely to have you here.",
						"Need directions anywhere?", "The lobby sofa is the comfiest seat in town.", "Mind the wet floor!" },
					staff = { "Busy shift, huh?", "Coffee later?", "Did you see the new guy?", "My feet are done for today.",
						"Boss seems happy today.", "Room 104 again...", "Who left the mop out?", "Lunch break soon, right?", "We make a good team." },
				}
				local function chatLine(g, other)
					if g.model and g.model:GetAttribute("Staff") then
						return pick((other.model and other.model:GetAttribute("Staff")) and STAFF_CHAT.staff or STAFF_CHAT.guest)
					end
					if other.model and other.model:GetAttribute("Staff") then
						return pick({ "Hi! Lovely hotel.", "Thanks for your help earlier!", "Where's the pool?", "Is breakfast included?", "You all work so hard!" })
					end
					return pick(C.LINES.chat)
				end
				task.spawn(turnTo, a, b.root.Position - a.root.Position)
				task.spawn(turnTo, b, a.root.Position - b.root.Position)
				say(a, chatLine(a, b), 3)
				task.delay(0.9, function() say(b, chatLine(b, a), 2.6) end)
				break
			end
		end
	end
end)

---------------------------------------------------------------- the owner's name (Plots sets HotelName)

local function nameSign()
	-- round 11: the marquee lives on the roof (rebuilt with it when land is bought)
	local sign = HOTEL:FindFirstChild("HotelSign", true)
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	if gui then gui.Text.Text = string.upper(HOTEL:GetAttribute("HotelName") or "My Hotel") end
end
nameSign()
HOTEL:GetAttributeChangedSignal("HotelName"):Connect(nameSign)
table.insert(conns, HOTEL.ChildAdded:Connect(function(c) if c.Name == "Roof" then task.defer(nameSign) end end))

---------------------------------------------------------------- arrivals

roomCounts()
refreshQueue()
drawPile()
HOTEL:SetAttribute("HotelReady", true) -- Save waits for this before restoring a saved hotel

-- guests come from the street crowd (ServerScriptService.Crowds): passers-by ask wantsWalkIn()
-- as they pass the front path, and walk in when it says yes
local handle = { hotel = HOTEL }
local lastWalkIn = 0
function handle.wantsWalkIn()
	if not running or #members() == 0 then return false end
	-- round 10d: at a low level, longer gaps, a shorter line and fewer guests at once
	local k = growth()
	local gap = (C.WALKIN_GAP or 4) + (1 - k) * 14 -- 18 s at level 1, 4 s from level 7
	if os.clock() - lastWalkIn < gap then return false end
	local count = 0
	for _ in pairs(guests) do count += 1 end
	local queueMax = math.min(C.QUEUE_MAX, 2 + math.floor(k * 4 + 0.5))
	if #queue >= queueMax or count >= math.floor(6 + 8 * k) then return false end
	local chance = pedInterest() * (RS.Shared:GetAttribute("Night") and C.NIGHT_TRAFFIC or 1)
	if freeRoom() then chance *= 1.6 end
	-- bad weather sends people looking for a roof (round 10c)
	chance *= ({ rain = 1.5, storm = 1.9, snow = 1.6, fog = 1.15 })[RS.Shared:GetAttribute("Weather") or "clear"] or 1
	if Research.hasPerk(HOTEL, "walkins") then chance *= 1.5 end -- research: Street Signage
	chance *= Research.mul(HOTEL, "walkins") -- round 13: Marketing research
	if (HOTEL:GetAttribute("InspectedUntil") or 0) > os.time() then chance *= 1.4 end -- passed an inspection
	if rng:NextNumber() < chance then
		lastWalkIn = os.clock()
		return true
	end
	return false
end
-- Studio test hook: set the hotel's TestLetIn attribute to a number to let that many queued guests in
if game:GetService("RunService"):IsStudio() then
	HOTEL:GetAttributeChangedSignal("TestLetIn"):Connect(function()
		local n = HOTEL:GetAttribute("TestLetIn")
		if n then
			HOTEL:SetAttribute("TestLetIn", nil)
			HOTEL:SetAttribute("TestLetInResult", letIn(n))
		end
	end)
	-- TestSpawn = true sends a fresh guest from the street (use with TestEvent)
	HOTEL:GetAttributeChangedSignal("TestSpawn"):Connect(function()
		if not HOTEL:GetAttribute("TestSpawn") then return end
		HOTEL:SetAttribute("TestSpawn", nil)
		spawnGuest()
	end)
	-- TestDirty = room id: that room needs cleaning now. TestClean = "id:Task": open that minigame for the first member
	HOTEL:GetAttributeChangedSignal("TestDirty"):Connect(function()
		local id = HOTEL:GetAttribute("TestDirty")
		if not id then return end
		HOTEL:SetAttribute("TestDirty", nil)
		local room = rooms[id]
		if room and not room.guest then
			for _, t in ipairs(C.TASKS) do room.tasks[t] = true end
			room.model:SetAttribute("TasksLeft", #C.TASKS)
			setRoomState(room, "Dirty")
		end
	end)
	-- TestReady = room id: a dirty room is cleaned at once. TestLinger = n: guests take n times longer in their rooms
	HOTEL:GetAttributeChangedSignal("TestReady"):Connect(function()
		local id = HOTEL:GetAttribute("TestReady")
		if not id then return end
		HOTEL:SetAttribute("TestReady", nil)
		local room = rooms[id]
		if room and room.state == "Dirty" then
			for _, t in ipairs(C.TASKS) do
				if room.tasks[t] then room.clean(t, nil) end
			end
		end
	end)
	HOTEL:GetAttributeChangedSignal("TestClean"):Connect(function()
		local v = HOTEL:GetAttribute("TestClean")
		if not v then return end
		HOTEL:SetAttribute("TestClean", nil)
		local id, t = string.match(v, "(%d+):(%a+)")
		local room = rooms[tonumber(id)]
		local who = members()[1]
		if room and who and room.state == "Dirty" and room.tasks[t] then startCleaning(who, room, t) end
	end)
end

function handle.adopt(model, name)
	if usedNames[name] then name = name .. " " .. string.char(65 + rng:NextInteger(0, 25)) .. "." end
	usedNames[name] = true
	adoptGuest(model, name, true)
end
Sim.registry[HOTEL] = handle

-- keep the door prompt text right when rooms change state
task.spawn(function()
	while running do
		refreshQueue()
		task.wait(0.5)
	end
end)

return {
	hotel = HOTEL,
	handle = handle,
	stop = function()
		running = false
		Sim.registry[HOTEL] = nil
		for _, c in ipairs(conns) do c:Disconnect() end
		for g in pairs(guests) do g.alive = false end
		for _, p in ipairs(peds) do p.alive = false end
		for _, st in ipairs(staff) do st.g.alive = false end
		for _, room in pairs(rooms) do
			if room.showerHead then room.showerHead:Destroy() end
		end
	end,
}
end

return Sim
