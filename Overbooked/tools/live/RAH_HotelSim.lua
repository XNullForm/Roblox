-- ServerStorage.RAH_HotelSim: runs one hotel. Rooms, guests, cleaning, cash, doors, staff, upgrades.
-- RAH_Plots calls Sim.start(hotel) for every claimed plot (hotel attribute Origin = the plot's offset) and
-- handle.stop() when the plot is freed. The server owns every number; clients only draw.
-- Members of a hotel = players whose attribute RAH_Plot is the hotel's name (its owner and co-op partners):
-- only they get its toasts, and only they can use its prompts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))
local Catalog = require(RS.RAH:WaitForChild("Catalog"))
local Build = require(RS.RAH:WaitForChild("Build"))
local Notify = RS.RAH.Remotes.Notify
-- a sound at a spot in the world, played by RAH_Audio on every client
local function sfx(name, pos) Notify:FireAllClients("sfx", { name = name, pos = pos }) end

local Sim = {}

function Sim.start(HOTEL)
local O = HOTEL:GetAttribute("Origin") or Vector3.zero
local running = true
local conns = {} -- connections to shared signals, cut on stop
local GUESTS = HOTEL:FindFirstChild("Guests") or Instance.new("Folder")
GUESTS.Name = "Guests"
GUESTS.Parent = HOTEL

local function members()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("RAH_Plot") == HOTEL.Name then table.insert(list, p) end
	end
	return list
end
local function isMember(player) return player:GetAttribute("RAH_Plot") == HOTEL.Name end
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
local ItemsChanged = game.ServerStorage:WaitForChild("RAH_Signals"):WaitForChild("ItemsChanged")

local rng = Random.new()
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function range(t) return rng:NextNumber(t[1], t[2]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

---------------------------------------------------------------- collision groups

pcall(function() PhysicsService:RegisterCollisionGroup("Guests") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
PhysicsService:CollisionGroupSetCollidable("Guests", "Guests", false)
PhysicsService:CollisionGroupSetCollidable("Guests", "Players", false)

local function setGroup(model, group)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = group end
	end)
end

---------------------------------------------------------------- props that shouldn't block

-- (placed items carry their own CanCollide from RAH.Items; this covers the room clutter)
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

local function roomFinishedCleaning(room)
	setRoomState(room, "Ready")
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

-- crown moulding along the top of a wall
local function crown(parent, a, b, n, look)
	local len = (b - a).Magnitude
	if len < 1 then return end
	local mid = (a + b) / 2
	local base = CFrame.lookAt(mid, mid + n)
	local top = 12
	decoPart(parent, "Crown", Vector3.new(len, 0.7, 0.36), base * CFrame.new(0, top - 0.35, -0.18), PANEL, Enum.Material.Plaster)
	decoPart(parent, "CrownBead", Vector3.new(len, 0.16, 0.44), base * CFrame.new(0, top - 0.78, -0.22), look.trim, Enum.Material.Metal)
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

-- the sign over the door: tier name and a row of stars (redrawn by drawSign when stars change)
local function makeSign(parent, room, look, tier)
	local b = roomBox(room)
	local cf = CFrame.new(b.cx, Build.FY + 10.95, -1.36)
	local plate = decoPart(parent, "Sign", Vector3.new(6.6, 1.8, 0.2), cf, look.sign, Enum.Material.SmoothPlastic)
	local fz = 0.14
	decoPart(parent, "SignTrim", Vector3.new(6.9, 0.16, 0.26), cf * CFrame.new(0, 0.97, fz / 2), look.trim, Enum.Material.Metal)
	decoPart(parent, "SignTrim", Vector3.new(6.9, 0.16, 0.26), cf * CFrame.new(0, -0.97, fz / 2), look.trim, Enum.Material.Metal)
	decoPart(parent, "SignTrim", Vector3.new(0.16, 2.1, 0.26), cf * CFrame.new(-3.37, 0, fz / 2), look.trim, Enum.Material.Metal)
	decoPart(parent, "SignTrim", Vector3.new(0.16, 2.1, 0.26), cf * CFrame.new(3.37, 0, fz / 2), look.trim, Enum.Material.Metal)
	local g = Instance.new("SurfaceGui")
	g.Name = "Face"
	g.Face = Enum.NormalId.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 0.25
	g.Parent = plate
	local t = Instance.new("TextLabel")
	t.Name = "Tier"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 0.5)
	t.Position = UDim2.fromScale(0, 0.06)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = string.upper(C.ROOM_TIERS[tier].name)
	t.TextColor3 = look.text
	t.Parent = g
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = look.sign:Lerp(Color3.new(0, 0, 0), 0.5)
	st.Parent = t
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 0.4)
	row.Position = UDim2.fromScale(0, 0.55)
	row.Parent = g
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.Padding = UDim.new(0, 2)
	ll.Parent = row
	for i = 1, 5 do
		local s = Instance.new("ImageLabel")
		s.Name = "Star" .. i
		s.LayoutOrder = i
		s.BackgroundTransparency = 1
		s.Size = UDim2.fromScale(1, 1)
		s.SizeConstraint = Enum.SizeConstraint.RelativeYY
		s.Image = C.ICONS.starEmpty
		s.Parent = row
	end
	room.sign = row
end

local function drawSign(room)
	if not room.sign then return end
	local n = starsOf(room)
	for i = 1, 5 do
		local s = room.sign:FindFirstChild("Star" .. i)
		if s then s.Image = i <= n and C.ICONS.star or C.ICONS.starEmpty end
	end
	-- an unfurnished room advertises itself as empty until the player furnishes it
	local face = room.sign.Parent
	local tierLabel = face and face:FindFirstChild("Tier")
	if tierLabel then
		tierLabel.Text = room.state == "Unfurnished" and "EMPTY ROOM" or string.upper(C.ROOM_TIERS[tierOf(room)].name)
	end
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
		m.Floor.Color = look.floor
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
		wainscot(up, Vector3.new(xl, FY, zf), Vector3.new(cx - 3.95, FY, zf), Vector3.new(0, 0, -1), look)
		wainscot(up, Vector3.new(cx + 3.95, FY, zf), Vector3.new(xr, FY, zf), Vector3.new(0, 0, -1), look)
		featureWall(up, fx, zb, look)
		sconce(up, Vector3.new(fx - 6.4, FY + 6.6, zb), look)
		sconce(up, Vector3.new(fx + 6.4, FY + 6.6, zb), look)
		if look.suite then
			crown(up, Vector3.new(xl, FY, zb), Vector3.new(xr, FY, zb), back, look)
			crown(up, Vector3.new(xl, FY, zb), Vector3.new(xl, FY, zf), Vector3.new(1, 0, 0), look)
			crown(up, Vector3.new(xr, FY, zb), Vector3.new(xr, FY, zf), Vector3.new(-1, 0, 0), look)
			crown(up, Vector3.new(xl, FY, zf), Vector3.new(cx - 3.95, FY, zf), Vector3.new(0, 0, -1), look)
			crown(up, Vector3.new(cx + 3.95, FY, zf), Vector3.new(xr, FY, zf), Vector3.new(0, 0, -1), look)
		end
		local bed = core(room, "Bed")
		if bed then room.throw = makeThrow(up, bed:GetPivot(), look) end
	end
	makeSign(up, room, look, tier)
	up.Parent = m
	drawSign(room)
	if room.throw then setShown(room.throw, room.state ~= "Dirty") end
end

-- the hotel's rating: the average of its rooms' stars (Hotel attribute HotelStars)
local function updateRating()
	local sum, n = 0, 0
	for _, r in pairs(rooms) do
		sum += r.model:GetAttribute("Stars") or 1
		n += 1
	end
	HOTEL:SetAttribute("HotelStars", n > 0 and math.floor(sum / n * 10 + 0.5) / 10 or 1)
end

local onTier -- forward: a room's Tier changed (set after syncRoom)

---------------------------------------------------------------- cleaning minigames
-- pressing a clean prompt opens a minigame on that player's screen (RAH_Minigames).
-- The server never trusts the client: a session is opened here, and CleanDone only
-- counts if it arrives in time, took at least C.MINIGAME_MIN, and the task is still dirty.
local cleaning = {} -- player -> { room, task, t0 }

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

table.insert(conns, RS.RAH.Remotes.CleanDone.OnServerEvent:Connect(function(player, cancel)
	local s = cleaning[player]
	if not s then return end
	if cancel then -- the player closed the minigame: give the prompt back
		endCleaning(player, true)
		return
	end
	local took = os.clock() - s.t0
	local room, task = s.room, s.task
	cleaning[player] = nil
	if took < C.MINIGAME_MIN or took > C.MINIGAME_TIMEOUT then return end
	if room.state == "Dirty" and room.tasks[task] and isMember(player) then
		room.clean(task, player)
	else
		endCleaning(player, true)
	end
end))
table.insert(conns, Players.PlayerRemoving:Connect(function(player) cleaning[player] = nil end))

-- the day summary: when RAH_DayNight rolls the clock over, every hotel reports
-- its day to its members, then starts fresh
table.insert(conns, game.ServerStorage.RAH_Signals:WaitForChild("DayEnded").Event:Connect(function(dayN)
	local s = dayStats
	dayStats = { earned = 0, guests = 0, cleans = 0 }
	tell("day", {
		day = dayN,
		earned = s.earned,
		guests = s.guests,
		cleans = s.cleans,
		uncollected = pending,
	})
end))

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
	room.model:SetAttribute("Price", C.ROOM_PRICE + C.ROOM_TIERS[tierOf(room)].bonus + appeal * Catalog.PRICE_PER_APPEAL)
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
	drawSign(room)
	placeThrow(room)
	showBed(room, room.state ~= "Dirty")
end

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
	lobbyAppeal = Build.appeal("Lobby", HOTEL)
	HOTEL:SetAttribute("LobbyAppeal", lobbyAppeal)
	updateRating()
end

-- an upgrade (RAH_BuildServer sets Tier) or a restored save: redress the room, sparkle it up
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
table.insert(conns, ItemsChanged.Event:Connect(syncAll))

-- a room bought in build mode (RAH_BuildServer builds it, then fires this)
table.insert(conns, game.ServerStorage.RAH_Signals:WaitForChild("RoomAdded").Event:Connect(function(m)
	if not m:IsDescendantOf(HOTEL) or rooms[m:GetAttribute("RoomId")] then return end
	local room = addRoom(m)
	setRoomState(room, furnished(room) and "Ready" or "Unfurnished")
	syncAll()
end))

-- a nicer lobby: guests wait longer and arrive sooner
local function patience() return C.PATIENCE * (1 + lobbyAppeal / 40) end
-- a better star rating brings guests sooner too
local function arrivalGap()
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	return range(C.ARRIVE_EVERY) / (1 + lobbyAppeal / 60) / (1 + (stars - 1) * C.STAR_ARRIVALS)
end

local function freeRoom()
	local ids = {}
	for id, r in pairs(rooms) do if r.state == "Ready" then table.insert(ids, id) end end
	table.sort(ids)
	return ids[1] and rooms[ids[1]]
end

---------------------------------------------------------------- guest bodies (shared builder in ServerStorage.RAH_Bodies)

local Bodies = require(game.ServerStorage:WaitForChild("RAH_Bodies"))
local function makeBody(name)
	return Bodies.make(name, C.WALK_SPEED)
end

---------------------------------------------------------------- status bubble (server-made, lives in the head)

local function makeBubble(g)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Status"
	bb.Size = UDim2.fromScale(4.6, 2.3)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false
	bb.Adornee = g.head
	bb.Parent = g.head

	local name = Instance.new("TextLabel")
	name.Name = "GuestName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.34)
	name.Position = UDim2.fromScale(0, 0.66)
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = g.name
	name.Parent = bb
	local s = Instance.new("UIStroke")
	s.Thickness = 2.5
	s.Color = Color3.fromRGB(46, 34, 58)
	s.Parent = name

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.02)
	card.Size = UDim2.fromScale(0.82, 0.56)
	card.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.3, 0)
	local cs = Instance.new("UIStroke")
	cs.Thickness = 2
	cs.Color = Color3.fromRGB(46, 34, 58)
	cs.Transparency = 0.2
	cs.Parent = card
	local cg = Instance.new("UIGradient")
	cg.Rotation = 90
	cg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 224, 236))
	cg.Parent = card

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0.02, 0.5)
	icon.Size = UDim2.fromScale(0.3, 1.25)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = C.ICONS.walk
	icon.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.3, 0.08)
	label.Size = UDim2.fromScale(0.66, 0.42)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(70, 60, 84)
	label.Text = ""
	label.Parent = card

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.3, 0.6)
	track.Size = UDim2.fromScale(0.64, 0.24)
	track.BackgroundColor3 = Color3.fromRGB(206, 202, 218)
	track.Parent = card
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(220, 200, 200))
	fg.Parent = fill

	-- speech bubble above the card
	local say = Instance.new("TextLabel")
	say.Name = "Say"
	say.AnchorPoint = Vector2.new(0.5, 1)
	say.Position = UDim2.fromScale(0.5, -0.04)
	say.Size = UDim2.fromScale(1.15, 0.36)
	say.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	say.BackgroundTransparency = 0.05
	say.Font = Enum.Font.FredokaOne
	say.TextScaled = true
	say.TextColor3 = Color3.fromRGB(60, 50, 74)
	say.Visible = false
	say.Parent = bb
	Instance.new("UICorner", say).CornerRadius = UDim.new(0.4, 0)
	local sp = Instance.new("UIPadding", say)
	sp.PaddingLeft = UDim.new(0.05, 0); sp.PaddingRight = UDim.new(0.05, 0)
	sp.PaddingTop = UDim.new(0.12, 0); sp.PaddingBottom = UDim.new(0.12, 0)

	g.ui = { bb = bb, icon = icon, label = label, fill = fill, track = track, say = say, card = card }
end

local BAR = {
	yellow = Color3.fromRGB(255, 200, 40),
	blue = Color3.fromRGB(80, 170, 255),
	purple = Color3.fromRGB(150, 120, 255),
	green = Color3.fromRGB(90, 210, 100),
	red = Color3.fromRGB(240, 80, 80),
}

local function status(g, icon, text, color)
	if not g.ui then return end
	g.ui.icon.Image = C.ICONS[icon] or C.ICONS.walk
	g.ui.label.Text = text
	g.ui.fill.BackgroundColor3 = BAR[color or "yellow"]
	g.ui.fill.Size = UDim2.fromScale(0, 1)
	g.ui.track.Visible = color ~= nil
end

-- fills the bar over `secs` (or drains when `drain`); returns when done
local function timed(g, secs, drain)
	local t0 = os.clock()
	while g.alive do
		local k = math.clamp((os.clock() - t0) / secs, 0, 1)
		if g.ui then g.ui.fill.Size = UDim2.fromScale(drain and (1 - k) or k, 1) end
		if k >= 1 then break end
		task.wait(0.1)
	end
end

local function say(g, line, secs)
	if not g.ui then return end
	g.sayId = (g.sayId or 0) + 1
	local id = g.sayId
	g.ui.say.Text = line
	g.ui.say.Visible = true
	task.delay(secs or 3, function()
		if g.sayId == id and g.ui then g.ui.say.Visible = false end
	end)
end

---------------------------------------------------------------- animation

local function loadAnims(g)
	local animator = g.hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", g.hum)
	g.tracks = {}
	for k, id in pairs(C.ANIM) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then g.tracks[k] = tr end
	end
	if g.tracks.walk then
		g.tracks.walk.Priority = Enum.AnimationPriority.Movement
		g.tracks.walk.Looped = true
	end
	if g.tracks.sit then g.tracks.sit.Priority = Enum.AnimationPriority.Action; g.tracks.sit.Looped = true end
	if g.tracks.idle then g.tracks.idle.Looped = true; g.tracks.idle:Play(0.1) end
	g.hum.Running:Connect(function(speed)
		local w = g.tracks.walk
		if not w then return end
		if speed > 0.5 then
			-- moving: keep (or start) the walk track, matched to actual speed
			g.lastRun = os.clock()
			if not w.IsPlaying and not g.posed then w:Play(0.2) end
			w:AdjustSpeed(math.clamp(speed / 14, 0.65, 1.8))
		elseif w.IsPlaying then
			-- brief speed dips (waypoint hand-offs, deceleration) must NOT cut the
			-- animation mid-stride; only stop if the NPC stays slow for a moment
			local id = (g.stopId or 0) + 1
			g.stopId = id
			task.delay(0.3, function()
				if g.stopId == id and w.IsPlaying and not g.posed
					and os.clock() - (g.lastRun or 0) >= 0.3 then
					w:Stop(0.2)
				end
			end)
		end
	end)
end

local function play(g, name, fade)
	local t = g.tracks and g.tracks[name]
	if t then t:Play(fade or 0.25) end
	return t
end

local function stop(g, name, fade)
	local t = g.tracks and g.tracks[name]
	if t and t.IsPlaying then t:Stop(fade or 0.25) end
end

---------------------------------------------------------------- walking

local function faceTo(g, look)
	if not look then return end
	local p = g.root.Position
	local dir = flat(look - p)
	if dir.Magnitude < 0.05 then return end
	g.root.CFrame = CFrame.lookAt(p, p + dir)
end

local function moveDirect(g, target, timeout, arriveDist)
	arriveDist = arriveDist or 1.5
	local t0 = os.clock()
	local lastPos, lastMove = g.root.Position, os.clock()
	while g.alive and os.clock() - t0 < (timeout or 6) do
		local offset = flat(target - g.root.Position)
		if offset.Magnitude <= arriveDist then
			g.hum:Move(Vector3.zero)
			return true
		end
		-- steer toward the target every tick: unlike MoveTo there is no built-in
		-- deceleration, so the NPC glides through waypoints without stopping
		g.hum:Move(offset.Unit)
		-- stuck (furniture in the way): give up early so the caller can move on
		if flat(g.root.Position - lastPos).Magnitude > 0.6 then
			lastPos, lastMove = g.root.Position, os.clock()
		elseif os.clock() - lastMove > 1.2 then
			break
		end
		task.wait(0.05)
	end
	g.hum:Move(Vector3.zero)
	return flat(g.root.Position - target).Magnitude <= arriveDist + 1
end

local function settle(g, target, timeout)
	-- final approach: MoveTo decelerates into the exact spot, so the NPC glides to a
	-- stop instead of lurching past it (hum:Move steering never decelerates on its own)
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < (timeout or 6) do
		local offset = flat(target - g.root.Position)
		if offset.Magnitude <= 1.2 then
			g.hum:Move(Vector3.zero)
			return true
		end
		g.hum:MoveTo(target)
		task.wait(0.1)
	end
	g.hum:Move(Vector3.zero)
	return flat(g.root.Position - target).Magnitude <= 2.5
end

local function walkTo(g, target)
	if typeof(target) == "Instance" then target = target.Position end
	if not g.alive then return end
	local path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 5 })
	local ok = pcall(function() path:ComputeAsync(g.root.Position, target) end)
	local wps
	if ok and path.Status == Enum.PathStatus.Success then
		wps = path:GetWaypoints()
	end
	if not wps or #wps < 2 then
		wps = { { Position = g.root.Position }, { Position = target } }
	end
	-- stream waypoints: move on to the next one early so the humanoid never stops between them
	for i = 2, #wps do
		if not g.alive then return end
		local wp = wps[i].Position
		if i < #wps then
			moveDirect(g, wp, 4, 2.5) -- roll through intermediate waypoints
		else
			settle(g, wp, 6) -- decelerate cleanly into the final one
		end
	end
end

local function goSpot(g, spot)
	walkTo(g, spot.Position)
	faceTo(g, spot:GetAttribute("Look"))
end

-- pin the root to a CFrame for a pose (sleep, toilet); restore with unpose
local function pose(g, cf)
	g.posed = true
	stop(g, "walk", 0.1)
	g.root.Anchored = true
	g.root.CFrame = cf
end

local function unpose(g, standCF)
	g.root.CFrame = standCF
	g.root.Anchored = false
	g.posed = false
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

local function despawn(g)
	g.alive = false
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
			walkTo(g, p)
			faceTo(g, look)
		end
		if os.clock() - t0 > patience() then
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
local function deskService(g, secs, action)
	if (HOTEL:GetAttribute("Receptionists") or 0) > 0 then
		timed(g, secs)
		return g.alive
	end
	status(g, "bell", action == "Check In" and "Waiting to check in" or "Waiting to pay", "yellow")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DeskService"
	prompt.ActionText = action
	prompt.ObjectText = g.name
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0.4
	prompt:SetAttribute("Icon", action == "Check In" and "bell" or "cash")
	prompt:SetAttribute("Color", "yellow")
	prompt.Parent = g.root
	local served = false
	prompt.Triggered:Connect(function(player)
		if not isMember(player) then notMine(player); return end
		served = true
	end)
	local t0 = os.clock()
	while g.alive and not served do
		-- a receptionist was hired while they waited: they take over
		if (HOTEL:GetAttribute("Receptionists") or 0) > 0 then
			prompt:Destroy()
			timed(g, secs)
			return g.alive
		end
		local k = 1 - (os.clock() - t0) / patience()
		if g.ui then
			g.ui.fill.Size = UDim2.fromScale(math.max(k, 0), 1)
			g.ui.fill.BackgroundColor3 = k > 0.5 and BAR.green or (k > 0.25 and BAR.yellow or BAR.red)
		end
		if k <= 0 then break end
		task.wait(0.1)
	end
	prompt:Destroy()
	if served and g.alive then
		timed(g, math.max(secs * 0.4, 0.8)) -- quick paperwork once the player helps
		return true
	end
	return false
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
	walkTo(g, (rng:NextNumber() < 0.5 and NAV.Street or NAV.StreetExit).Position)
	despawn(g)
end

local function useRoom(g, room)
	local nav = room.nav
	walkTo(g, room.nav.Door.Position)
	walkTo(g, nav.Enter.Position)
	say(g, pick(C.LINES.room), 2.5)
	-- different guests do different things, in different orders, for different lengths
	local order = {}
	if rng:NextNumber() < 0.8 then table.insert(order, "Toilet") end
	if rng:NextNumber() < 0.8 then table.insert(order, "Shower") end
	if #order == 2 and rng:NextNumber() < 0.5 then order = { order[2], order[1] } end
	if rng:NextNumber() < 0.4 then table.insert(order, 1, "Wander") end
	table.insert(order, "Bed") -- bed last: it's the "night"
	for _, act in ipairs(order) do
		if not g.alive then return end
		local secs = range(C.ACTIVITY[act])
		if act == "Toilet" then
			status(g, "walk", "Bathroom")
			local piv = core(room, "Toilet"):GetPivot()
			local front = coreSpot(room, "Toilet", "front")
			walkTo(g, front)
			faceTo(g, piv.Position)
			status(g, "toilet", "Toilet", "blue")
			pose(g, coreSpot(room, "Toilet", "sit"))
			play(g, "sit", 0.2)
			timed(g, secs)
			sfx("flush", piv.Position)
			stop(g, "sit", 0.2)
			unpose(g, CFrame.lookAt(front, front + flat(front - piv.Position)))
		elseif act == "Shower" then
			status(g, "walk", "Shower")
			local piv = core(room, "Shower"):GetPivot()
			local front = coreSpot(room, "Shower", "front")
			walkTo(g, front)
			faceTo(g, piv.Position)
			pose(g, coreSpot(room, "Shower", "inside"))
			room.water.Enabled = true
			room.steam.Enabled = true
			status(g, "shower", "Shower", "blue")
			timed(g, secs)
			room.water.Enabled = false
			room.steam.Enabled = false
			unpose(g, CFrame.lookAt(front, front + flat(front - piv.Position)))
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
			status(g, "sleep", "Sleeping", "purple")
			pose(g, coreSpot(room, "Bed", "lie"))
			g.zzz.Enabled = true
			timed(g, secs)
			g.zzz.Enabled = false
			local out = flat(side - bedPos)
			unpose(g, CFrame.lookAt(side, side + out))
		end
		task.wait(0.4)
	end
end

---------------------------------------------------------------- lobby roaming (guests admire the placed decor)

-- non-flat items standing in the lobby
local function lobbyItems()
	local list = {}
	for _, m in ipairs(PLACED:GetChildren()) do
		if m:GetAttribute("Zone") == "Lobby" then
			local it = Catalog.ITEMS[m:GetAttribute("Item")]
			if it and not it.flat then table.insert(list, { model = m, item = it }) end
			end
	end
	return list
end

-- a stroll through the lobby: walk up to a few pieces of decor and admire them
local function lobbyVisit(g)
	if not g.alive then return end
	local items = lobbyItems()
	if #items == 0 then return end
	-- a nicer lobby draws more lingering
	if rng:NextNumber() > 0.4 + lobbyAppeal / 60 then return end
	status(g, "guest", "Enjoying the lobby")
	for _ = 1, rng:NextInteger(1, math.min(3, #items)) do
		if not g.alive then return end
		local e = pick(items)
		if not e.model.Parent then continue end
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

local function guestLife(g)
	-- arrive from the street (a fresh body, or a pedestrian passing by)
	if not g.adopted then
		g.model:PivotTo(NAV[(rng:NextNumber() < 0.5) and "Street" or "StreetExit"].CFrame)
		g.model.Parent = GUESTS
		setGroup(g.model, "Guests")
		loadAnims(g)
	end
	status(g, "walk", "Arriving")
	walkTo(g, NAV.PathStart.Position)
	if #queue >= C.QUEUE_MAX then
		say(g, "Too busy here...", 2.5)
		leaveStreet(g)
		return
	end
	table.insert(queue, g)
	g.queuedAt = os.clock()
	refreshQueue()
	say(g, pick(C.LINES.arrive), 3)
	sfx("arrive", NAV.PathStart.Position)
	-- wait in line until let in (keep stepping forward as the line moves)
	status(g, "door", "Waiting", "green")
	local t0 = os.clock()
	local lastSlot
	while g.alive and not g.room do
		if g.slot ~= lastSlot then
			lastSlot = g.slot
			goSpot(g, NAV["Queue" .. g.slot])
		end
		local k = 1 - (os.clock() - t0) / patience()
		if g.ui then
			g.ui.fill.Size = UDim2.fromScale(math.max(k, 0), 1)
			g.ui.fill.BackgroundColor3 = k > 0.5 and BAR.green or (k > 0.25 and BAR.yellow or BAR.red)
		end
		if k <= 0 then
			local i = queueSlot(g)
			if i then table.remove(queue, i); refreshQueue() end
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " got tired of waiting", icon = "guest", bad = true })
			leaveStreet(g)
			return
		end
		if rng:NextNumber() < 0.004 then say(g, pick(C.LINES.wait), 2.5) end
		task.wait(0.1)
	end
	if not g.alive then return end
	local room = g.room
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
	sfx("bell", NAV.DeskGuest.Position)
	say(g, pick(C.LINES.checkin), 2.5)
	if not deskService(g, C.CHECK_IN, "Check In") then
		deskRemove(g)
		releaseRoom(room)
		if g.alive then
			status(g, "guest", "Leaving")
			say(g, pick(C.LINES.angry), 3)
			tell("toast", { text = g.name .. " left without checking in", icon = "guest", bad = true })
			leaveStreet(g)
		end
		return
	end
	deskRemove(g)
	lobbyVisit(g)
	if not g.alive then return end
	status(g, "walk", "Room " .. room.id)
	useRoom(g, room)
	if not g.alive then return end
	-- check out: the room is dirty the moment they leave it
	lobbyVisit(g)
	if not g.alive then return end
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
	if not deskService(g, C.CHECK_OUT, "Check Out") then
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
	local pay = (room.model:GetAttribute("Price") or C.ROOM_PRICE) + math.floor(range(C.TIP) * C.ROOM_TIERS[tierOf(room)].tip)
	pending += pay
	dayStats.earned += pay
	dayStats.guests += 1
	drawPile()
	say(g, pick(C.LINES.checkout), 3)
	Notify:FireAllClients("paid", { amount = pay, pos = g.head.Position + Vector3.new(0, 3, 0) })
	play(g, "wave")
	task.wait(1)
	status(g, "walk", "Going home")
	walkTo(g, NAV.Inside.Position)
	leaveStreet(g)
end

local usedNames = {}
-- turn a body (fresh from makeBody, or a pedestrian's) into a guest and start its life
local function adoptGuest(model, name, adopted)
	local g = {
		name = name, model = model, alive = true, adopted = adopted,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
		head = model:WaitForChild("Head"),
	}
	model:SetAttribute("Guest", true)
	makeBubble(g)
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
			if running then warn("RAH guest " .. name .. ": " .. tostring(err)) end
			if g.room and g.room.state == "Booked" then setRoomState(g.room, "Ready") end
			despawn(g)
		end
		usedNames[name] = nil
	end)
end

local function spawnGuest()
	local name
	for _ = 1, 10 do
		name = pick(C.NAMES)
		if not usedNames[name] then break end
	end
	usedNames[name] = true
	local model = makeBody(name)
	if not model then return end
	adoptGuest(model, name)
end

---------------------------------------------------------------- sidewalk pedestrians (passers-by; some stop and become guests)

local peds = {}

local function pedDone(p, keepModel)
	p.alive = false
	local i = table.find(peds, p)
	if i then table.remove(peds, i) end
	if not keepModel and p.model then p.model:Destroy() end
end

-- the hotel's pull on passers-by: more stars, more walk-ins
local function pedInterest()
	local stars = HOTEL:GetAttribute("HotelStars") or 1
	return C.PED_BASE + (stars - 1) * C.PED_PER_STAR
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
				and rng:NextNumber() < pedInterest() * (RS.RAH:GetAttribute("Night") and C.NIGHT_TRAFFIC or 1)
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
			if running then warn("RAH ped " .. name .. ": " .. tostring(err)) end
			pedDone(g)
		end
	end)
end

---------------------------------------------------------------- the front door

-- gives queued guests free rooms, front of the line first; returns how many went in
letIn = function(maxN)
	local let = 0
	while #queue > 0 and let < (maxN or math.huge) do
		local room = freeRoom()
		if not room then break end
		local g = table.remove(queue, 1)
		room.state = "Booked"
		room.guest = g
		room.model:SetAttribute("State", "Booked")
		room.model:SetAttribute("Guest", g.name)
		g.room = room
		let += 1
	end
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
				if r and flat(r.Position - centre).Magnitude < 10 then near = true end
			end
			for g in pairs(guests) do
				if g.root and flat(g.root.Position - centre).Magnitude < 10 then near = true end
			end
			slide(near)
			task.wait(0.15)
		end
	end)
end

-- placed doors (build mode): their panel slides aside for anyone close by, front doors or room doors
do
	local open = {}
	local tweens = {}
	task.spawn(function()
		while running do
			local movers = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r then table.insert(movers, r.Position) end
			end
			for g in pairs(guests) do
				if g.root then table.insert(movers, g.root.Position) end
			end
			for _, m in ipairs(PLACED:GetChildren()) do
				if m.Parent and m:GetAttribute("Item") == "Door" then
					local slide = m:FindFirstChild("Slide")
					local panel = slide and slide:FindFirstChild("Panel")
					if panel then
						-- capture the closed CFrame at runtime: the saved one goes stale on other plots
						local base = m:FindFirstChild("ClosedCF")
						if not base then
							base = Instance.new("CFrameValue")
							base.Name = "ClosedCF"
							base.Value = panel.CFrame
							base.Parent = m
						end
						local near = false
						local pp = m:GetPivot().Position
						for _, pos in ipairs(movers) do
							if flat(pos - pp).Magnitude < 7 then near = true end
						end
						if open[m] ~= near then
							open[m] = near
							local goal = near and base.Value * CFrame.new(3.4, 0, 0) or base.Value
							if tweens[m] then tweens[m]:Cancel() end
							tweens[m] = TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = goal })
							tweens[m]:Play()
						end
					end
				end
			end
			task.wait(0.15)
		end
	end)
end

---------------------------------------------------------------- staff (hired in build mode or the menu; Hotel attributes Janitors / Doormen / Receptionists)

local staff = {} -- list of { def, g, home, index }
local STAFF_NAMES = { "Rosa", "Gus", "Mabel", "Theo", "Ines", "Walt", "Pearl", "Otto" }
local STAFF_HOME = { -- where idle staff stand
	janitor = { O + Vector3.new(30, 4, 6), O + Vector3.new(34, 4, 6), O + Vector3.new(26, 4, 6) },
	doorman = { O + Vector3.new(6, 4, 34) },
}
local UNIFORM = {
	janitor = { top = Color3.fromRGB(70, 140, 220), legs = Color3.fromRGB(46, 96, 170), role = "Janitor", roleColor = Color3.fromRGB(140, 210, 255) },
	doorman = { top = Color3.fromRGB(205, 52, 60), legs = Color3.fromRGB(44, 36, 52), role = "Doorman", roleColor = Color3.fromRGB(255, 150, 150) },
	receptionist = { top = Color3.fromRGB(64, 70, 130), legs = Color3.fromRGB(44, 36, 52), role = "Receptionist", roleColor = Color3.fromRGB(255, 226, 150) },
}

-- a touch of variety: each staff member's uniform shades slightly differently
local function shade(c, k)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.clamp(s + k * 0.06, 0, 1), math.clamp(v + k * 0.05, 0, 1))
end

local function weldTo(part, to, c0)
	local w = Instance.new("Weld")
	w.Part0 = to
	w.Part1 = part
	w.C0 = c0
	w.Parent = part
	part.Parent = to.Parent
	return w
end

local function propPart(size, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

-- a staff body: a random guest look, then a uniform (plain coloured clothes) and a prop
local function makeStaff(def, index)
	local name = STAFF_NAMES[(index + (def.id == "doorman" and 4 or def.id == "receptionist" and 6 or 0) - 1) % #STAFF_NAMES + 1]
	local model = makeBody(name)
	if not model then return nil end
	local base = UNIFORM[def.id]
	local k = (((index - 1) % 3) - 1) * 0.5
	local u = { top = shade(base.top, k), legs = shade(base.legs, -k), role = base.role, roleColor = base.roleColor }
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then d:Destroy() end
		if def.id == "doorman" and d:IsA("Accessory") and d.AccessoryType == Enum.AccessoryType.Hat then d:Destroy() end
	end
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then bodyColors:Destroy() end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local n = p.Name
			if n:find("Torso") or n:find("UpperArm") then p.Color = u.top
			elseif n:find("Leg") or n:find("Foot") then p.Color = u.legs end
		end
	end
	local g = {
		name = name, model = model, alive = true, staff = def.id,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
		head = model:WaitForChild("Head"),
	}
	g.hum.WalkSpeed = C.STAFF_WALK
	model:SetAttribute("Staff", def.id)
	if def.id == "janitor" then
		-- a mop in the right hand
		local hand = model:FindFirstChild("RightHand")
		if hand then
			-- held at the top, angled forward so the head rests on the floor
			local stick = propPart(Vector3.new(0.22, 4.2, 0.22), Color3.fromRGB(196, 136, 82), Enum.Material.Wood)
			stick.Name = "Mop"
			g.mopWeld = weldTo(stick, hand, CFrame.Angles(math.rad(38), 0, 0) * CFrame.new(0, -0.9, 0))
			local head = propPart(Vector3.new(1.3, 0.35, 0.7), Color3.fromRGB(236, 240, 246), Enum.Material.Fabric)
			head.Name = "MopHead"
			weldTo(head, stick, CFrame.new(0, -2.15, 0) * CFrame.Angles(math.rad(-38), 0, 0))
			g.mopRest = g.mopWeld.C0
		end
	elseif def.id == "doorman" then
		-- a doorman's cap with a gold band
		local cap = propPart(Vector3.new(1.0, 1.25, 1.25), u.top, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		cap.Name = "Cap"
		weldTo(cap, g.head, CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local band = propPart(Vector3.new(0.22, 1.3, 1.3), Color3.fromRGB(255, 210, 90), Enum.Material.Metal, Enum.PartType.Cylinder)
		band.Name = "Band"
		weldTo(band, g.head, CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local brim = propPart(Vector3.new(0.12, 1.5, 1.5), Color3.fromRGB(40, 32, 48), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		brim.Name = "Brim"
		weldTo(brim, g.head, CFrame.new(0, 0.3, -0.1) * CFrame.Angles(0, 0, math.rad(90)))
	elseif def.id == "receptionist" then
		-- a neat gold bow tie
		local torso = model:FindFirstChild("UpperTorso")
		if torso then
			local tie = propPart(Vector3.new(0.55, 0.3, 0.18), Color3.fromRGB(255, 210, 90), Enum.Material.SmoothPlastic)
			tie.Name = "BowTie"
			weldTo(tie, torso, CFrame.new(0, -0.55, -0.42))
		end
	end
	makeBubble(g)
	local role = g.ui.bb.GuestName:Clone()
	role.Name = "Role"
	role.Text = u.role
	role.Size = UDim2.fromScale(1, 0.22)
	role.Position = UDim2.fromScale(0, 0.44)
	role.TextColor3 = u.roleColor
	role.Parent = g.ui.bb
	return g
end

local function idle(g, home, look)
	status(g, "sleep", "Waiting for work")
	if flat(g.root.Position - home).Magnitude > 2 then walkTo(g, home) end
	faceTo(g, look or (home + Vector3.new(0, 0, 10)))
end

-- sweep the mop while working; fills the status bar
local function mopWork(g, secs)
	local t0 = os.clock()
	while g.alive and os.clock() - t0 < secs do
		local t = os.clock() - t0
		if g.mopWeld then g.mopWeld.C0 = g.mopRest * CFrame.Angles(0, 0, math.sin(t * 9) * 0.45) end
		if g.ui then g.ui.fill.Size = UDim2.fromScale(math.clamp(t / secs, 0, 1), 1) end
		task.wait()
	end
	if g.mopWeld then g.mopWeld.C0 = g.mopRest end
end

-- where a janitor stands for each job (follows furniture that was moved)
local function workSpot(room, task)
	if task == "Bed" then return bedSide(room)
	elseif task == "Shower" then return coreSpot(room, "Shower", "front")
	elseif task == "Toilet" then return coreSpot(room, "Toilet", "front") end
	local p = room.spots.Floor.Position
	return Vector3.new(p.X, 4, p.Z)
end

local function janitorLife(s)
	local g = s.g
	while g.alive do
		-- the nearest dirty room nobody is on yet
		local best, bestD
		for _, room in pairs(rooms) do
			if room.state == "Dirty" and (not room.cleaner or not room.cleaner.alive) then
				local d = flat(room.nav.Door.Position - g.root.Position).Magnitude
				if not bestD or d < bestD then best, bestD = room, d end
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
						mopWork(g, C.STAFF_CLEAN)
						room.clean(task, nil)
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
			idle(g, s.home)
			task.wait(1)
		end
	end
end

local function doormanLife(s)
	local g = s.g
	idle(g, s.home, s.home + Vector3.new(0, 0, 12))
	while g.alive do
		local first = queue[1]
		if first and first.queuedAt and os.clock() - first.queuedAt > C.DOORMAN_DELAY and freeRoom() then
			play(g, "wave")
			say(g, pick({ "Come on in!", "Welcome!", "Right this way!", "Your room is ready!" }), 2.2)
			sfx("door", doorPrompt.Parent.Position)
			letIn()
			task.wait(2)
		elseif first and not freeRoom() then
			status(g, "roomDirty", "No clean rooms")
		else
			status(g, "door", "At the door")
		end
		task.wait(0.4)
	end
end

local function receptionistLife(s)
	local g = s.g
	status(g, "bell", "At the desk")
	-- greet whoever reaches the desk
	local greeted = {}
	local home = s.home
	while g.alive do
		-- the desk moved in build mode: walk to the new post
		local spot = NAV.Receptionist
		if spot and (spot.Position - home).Magnitude > 1.5 then
			home = spot.Position
			s.home = home
			goSpot(g, spot)
		end
		for q in pairs(guests) do
			if q.root and not greeted[q] and flat(q.root.Position - NAV.DeskGuest.Position).Magnitude < 2.5 then
				greeted[q] = true
				play(g, "wave")
				say(g, pick({ "Welcome!", "Hi there!", "Enjoy your stay!", "Here's your key!" }), 2.5)
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
		local spot = NAV.Receptionist
		home, look = spot.Position, spot:GetAttribute("Look")
	else
		local homes = STAFF_HOME[def.id]
		home = homes[(index - 1) % #homes + 1]
	end
	local s = { def = def, g = g, index = index, home = home }
	g.model:PivotTo(CFrame.lookAt(home, look or (home + Vector3.new(0, 0, 10))))
	g.model.Parent = GUESTS
	setGroup(g.model, "Guests")
	loadAnims(g)
	table.insert(staff, s)
	local life = def.id == "janitor" and janitorLife or def.id == "receptionist" and receptionistLife or doormanLife
	task.spawn(function()
		local ok, err = pcall(life, s)
		if not ok and g.alive and running then warn("RAH staff " .. g.name .. ": " .. tostring(err)) end
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
	if syncAgain then syncAgain = false; syncStaff() end
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
		local idle = {}
		for g in pairs(guests) do
			if g.alive and g.root and not g.posed and g.root.AssemblyLinearVelocity.Magnitude < 1 then
				table.insert(idle, g)
			end
		end
		for _, s in ipairs(staff) do
			local g = s.g
			if g and g.alive and g.root and not g.posed and g.root.AssemblyLinearVelocity.Magnitude < 1 then
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
			if b then
				faceTo(a, b.root.Position)
				faceTo(b, a.root.Position)
				say(a, pick(C.LINES.chat), 3)
				task.delay(0.9, function() say(b, pick(C.LINES.chat), 2.6) end)
				break
			end
		end
	end
end)

---------------------------------------------------------------- the owner's name (RAH_Plots sets HotelName)

local function nameSign()
	local sign = HOTEL.Shell:FindFirstChild("HotelSign")
	local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
	if gui then gui.Text.Text = string.upper(HOTEL:GetAttribute("HotelName") or "My Hotel") end
end
nameSign()
HOTEL:GetAttributeChangedSignal("HotelName"):Connect(nameSign)

---------------------------------------------------------------- arrivals

roomCounts()
refreshQueue()
drawPile()
HOTEL:SetAttribute("HotelReady", true) -- RAH_Save waits for this before restoring a saved hotel

task.spawn(function()
	task.wait(C.FIRST_ARRIVAL)
	while running do
		-- the sidewalk stays busy with passers-by; guests come from pedestrians
		-- who stop by (the chance scales with the hotel's stars)
		if #peds < C.PED_MAX then
			spawnPed()
		end
		task.wait(range(C.PED_EVERY))
	end
end)

-- keep the door prompt text right when rooms change state
task.spawn(function()
	while running do
		refreshQueue()
		task.wait(0.5)
	end
end)

return {
	hotel = HOTEL,
	stop = function()
		running = false
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
