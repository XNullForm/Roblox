-- ServerScriptService.Crowds: the people on the street (round 9 rewrite).
-- Pedestrians walk the full length of both sidewalks, tunnel to tunnel, whether or not a plot is taken.
-- They keep to the right, steer round lamps, trees and benches (tagged WalkObstacle by the map
-- builder) and round each other, cross at the signalised crosswalks on the walk light, pop in and out of
-- the shops, and sometimes stop to look at a window or their phone. As one passes a hotel's front path,
-- that hotel's sim is asked wantsWalkIn(); on yes the body is handed over and becomes a guest. Leaving
-- guests come back through HotelSim.handOff and walk off down the street.
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local S = require(Shared:WaitForChild("Street"))
local Looks = require(Shared:WaitForChild("Looks"))
local Clock = require(Shared:WaitForChild("Clock"))
local Bodies = require(game.ServerStorage:WaitForChild("Bodies"))
local Sim = require(game.ServerStorage:WaitForChild("HotelSim"))

local rng = Random.new()
local weatherLook, FAR_AWAY -- set further down
local CROWD = Instance.new("Folder")
CROWD.Name = "StreetCrowd"
CROWD.Parent = workspace
local POOL = Instance.new("Folder")
POOL.Name = "CrowdPool"
POOL.Parent = game.ServerStorage

pcall(function() PhysicsService:RegisterCollisionGroup("Guests") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Guests", "Guests", true) end)
local function setGroup(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = "Guests" end
	end
end

-- round 10: walkers collide with the ground only. Every city part standing above the sidewalk (lamps, benches,
-- trees, signs, shop fronts) goes in NPCSolid, which walkers pass through, so nobody gets stuck on the street.
-- Players still collide with all of it. (HotelSim does the same inside each hotel.)
pcall(function() PhysicsService:RegisterCollisionGroup("NPCSolid") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("Guests", "NPCSolid", false) end)
task.spawn(function()
	local city = workspace:WaitForChild("City", 30)
	if not city then return end
	local n = 0
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") and d.CollisionGroup == "Default" then
			local cf, sz = d.CFrame, d.Size
			local top = cf.Y + 0.5 * (math.abs(cf.RightVector.Y) * sz.X + math.abs(cf.UpVector.Y) * sz.Y + math.abs(cf.LookVector.Y) * sz.Z)
			if top > S.Y + 0.95 then d.CollisionGroup = "NPCSolid" end
		end
		n += 1
		if n % 2000 == 0 then task.wait() end
	end
end)

---------------------------------------------------------------- obstacles (static, bucketed by x)

local BUCKET = 24
local obstacles = {}
local function addObstacle(m)
	local r = m:GetAttribute("WalkRadius")
	if not r or not m:IsDescendantOf(workspace) then return end
	local p = m:GetPivot().Position
	local b = math.floor(p.X / BUCKET)
	obstacles[b] = obstacles[b] or {}
	table.insert(obstacles[b], { x = p.X, z = p.Z, r = r })
end
for _, m in ipairs(CS:GetTagged("WalkObstacle")) do addObstacle(m) end

local function nearObstacles(x)
	local b = math.floor(x / BUCKET)
	return obstacles[b - 1], obstacles[b], obstacles[b + 1]
end

---------------------------------------------------------------- the people

local peds = {}
local byBucket = {}

local function loadAnims(p)
	local hum = p.hum
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local function track(id, looped, prio)
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, t = pcall(function() return animator:LoadAnimation(a) end)
		if not ok then return nil end
		t.Looped = looped
		t.Priority = prio
		return t
	end
	p.walk = track(p.model:GetAttribute("WalkAnim") or C.ANIM.walk, true, Enum.AnimationPriority.Movement)
	p.run = track(C.ANIM.run, true, Enum.AnimationPriority.Movement)
	p.idle = track(p.model:GetAttribute("IdleAnim") or C.ANIM.idle, true, Enum.AnimationPriority.Idle)
	if p.idle then p.idle:Play(0.2) end
end

local function setWalking(p, on)
	if not p.walk then return end
	if on and not p.walk.IsPlaying then
		p.walk:Play(0.25)
		if p.run then p.run:Play(0.25) end
	elseif not on and p.walk.IsPlaying then
		p.walk:Stop(0.3)
		if p.run then p.run:Stop(0.3) end
	end
	if on then
		-- the default Roblox walk/run blend for this speed
		local ww, rw, ws, rs = Looks.moveBlend(p.hum.WalkSpeed)
		p.walk:AdjustWeight(ww, 0.15)
		p.walk:AdjustSpeed(ws)
		if p.run then
			p.run:AdjustWeight(rw, 0.15)
			p.run:AdjustSpeed(rs)
		end
	end
end

-- direction of travel -> which walking lane (keep right)
local function laneZ(side, dir)
	local w = side == "near" and S.NEAR.walk or S.FAR.walk
	-- walking +X, your right hand is +Z
	if side == "near" then return dir == 1 and w[2] or w[1] end
	return dir == 1 and w[2] or w[1]
end

local function endX(dir) return dir == 1 and S.X1 + 120 or S.X0 - 120 end

-- somewhere near a random player (the crowd gathers where people are)
local function nearPlayerX()
	local list = {}
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(list, r.Position.X) end
	end
	if #list == 0 then return nil end
	return math.clamp(list[rng:NextInteger(1, #list)] + rng:NextNumber(-200, 200), S.X0 + 30, S.X1 - 30)
end

local function nearestPlayerDist(x)
	local best = math.huge
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if r then best = math.min(best, math.abs(r.Position.X - x)) end
	end
	return best == math.huge and 0 or best -- nobody spawned yet: keep everyone
end


local function newPed(model, name, x, z, side, dir)
	local p = {
		model = model, name = name, side = side, dir = dir, alive = true,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:FindFirstChild("HumanoidRootPart"),
		laneOff = rng:NextNumber(-0.7, 0.7),
		pause = 0, plan = {},
		decided = {}, -- hotel / crosswalk / shop decisions already made (by x key)
	}
	p.speed = (rng:NextNumber(8.5, 11.5)) * (model:GetAttribute("WalkSpeedMul") or 1)
	p.hum.WalkSpeed = p.speed
	p.wetMood = rng:NextNumber() -- who reaches for an umbrella first
	p.hum.AutoRotate = true
	model:PivotTo(CFrame.lookAt(Vector3.new(x, S.Y + 3, z), Vector3.new(x + dir, S.Y + 3, z)))
	model.Parent = CROWD
	setGroup(model)
	loadAnims(p)
	table.insert(peds, p)
	return p
end

local pool = {}
local building = 0
local function getBody()
	if #pool > 0 and (rng:NextNumber() < 0.75 or building > 1) then
		local i = rng:NextInteger(1, #pool)
		local m = table.remove(pool, i)
		return m, Bodies.name()
	end
	building += 1
	local name = Bodies.name()
	local m = Bodies.make(name, 10)
	building -= 1
	return m, name
end

local function retire(p, keep)
	p.alive = false
	if p.umbrella then p.umbrella:Destroy() p.umbrella = nil end
	if p.model and p.model:GetAttribute("Carry") == "umbrella" then p.model:SetAttribute("Carry", nil) end
	local i = table.find(peds, p)
	if i then table.remove(peds, i) end
	if keep then return end
	if p.model and p.model.Parent then
		for _, t in ipairs({ p.walk, p.run, p.idle, p.wave }) do pcall(function() t:Stop(0) end) end
		if #pool < 70 and not p.model:GetAttribute("Guest") then
			p.model.Parent = POOL
			table.insert(pool, p.model)
		else
			p.model:Destroy()
		end
	end
end

---------------------------------------------------------------- planning

-- hotel entrances on the near side (x of each plot's front path)
local function hotelAt(x)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end
	for _, h in ipairs(plots:GetChildren()) do
		local o = h:GetAttribute("Origin")
		if o and math.abs(o.X - x) < 3 then return h end
	end
	return nil
end

local function crossAhead(p)
	for _, cx in ipairs(S.CROSS) do
		local d = (cx - p.root.Position.X) * p.dir
		if d > 0 and d < 4 and not p.decided["c" .. cx] then return cx end
	end
end

local function hotelPathAhead(p)
	if p.side ~= "near" then return nil end
	for k = 1, S.PLOT_COUNT do
		local cx = S.centre(k)
		local d = (cx - p.root.Position.X) * p.dir
		if d > -1 and d < 2.5 and not p.decided["h" .. k] then return k, cx end
	end
end

---------------------------------------------------------------- steering

local function bucketPeds()
	table.clear(byBucket)
	for _, p in ipairs(peds) do
		if p.root then
			local b = math.floor(p.root.Position.X / BUCKET)
			byBucket[b] = byBucket[b] or {}
			table.insert(byBucket[b], p)
		end
	end
end

local function steer(p, target)
	local pos = p.root.Position
	local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if to.Magnitude < 0.2 then return Vector3.zero end
	local dir = to.Unit
	local side = Vector3.new(-dir.Z, 0, dir.X) -- left of travel
	local push = 0
	-- static obstacles just ahead: slide round them
	for _, list in ipairs({ nearObstacles(pos.X) }) do
		for _, o in ipairs(list or {}) do
			local rel = Vector3.new(o.x - pos.X, 0, o.z - pos.Z)
			local ahead = rel:Dot(dir)
			if ahead > -0.5 and ahead < 7 then
				local lat = rel:Dot(side)
				local clear = o.r + 1.3
				if math.abs(lat) < clear then
					push += (lat > 0 and -1 or 1) * (clear - math.abs(lat)) * 1.2
				end
			end
		end
	end
	-- other people: keep a little apart
	local b = math.floor(pos.X / BUCKET)
	for bi = b - 1, b + 1 do
		for _, q in ipairs(byBucket[bi] or {}) do
			if q ~= p and q.root then
				local rel = q.root.Position - pos
				rel = Vector3.new(rel.X, 0, rel.Z)
				local d = rel.Magnitude
				if d < 3.2 and d > 0.01 then
					local ahead = rel:Dot(dir)
					if ahead > -0.5 then
						push += (rel:Dot(side) > 0 and -1 or 1) * (3.2 - d) * 0.9
					end
				end
			end
		end
	end
	local v = dir + side * math.clamp(push, -1.6, 1.6) * 0.5
	return v.Magnitude > 0 and v.Unit or dir
end

---------------------------------------------------------------- behaviour (one coroutine-free tick per person)

local function goal(p, x, z, onArrive)
	table.insert(p.plan, { x = x, z = z, arrive = onArrive })
end

---------------------------------------------------------------- weather (round 10c: Weather sets Shared.Weather)

local WET = { rain = 1, storm = 1, snow = 0.7 }
local function wet() return WET[Shared:GetAttribute("Weather") or "clear"] or 0 end

-- a simple umbrella over the head: canopy, rim and handle, welded to the head
local UMBRELLA_COLS = { Color3.fromRGB(196, 54, 64), Color3.fromRGB(38, 58, 112), Color3.fromRGB(30, 32, 40),
	Color3.fromRGB(232, 184, 64), Color3.fromRGB(54, 124, 92), Color3.fromRGB(142, 82, 160) }
-- round 14: the umbrella swings up from the side, pops open (canopy springs out, the rib tips appear),
-- leans a little into the walk and drips off the rim; it folds and drops away when the rain stops
local TS = game:GetService("TweenService")
local U_OPEN = CFrame.new(0.45, 2.45, -0.2) * CFrame.Angles(math.rad(-8), 0, math.rad(-7))
local U_SHUT = CFrame.new(1.0, 0.4, -0.5) * CFrame.Angles(math.rad(-28), 0, math.rad(-34))
local U_FOLD = Vector3.new(0.13, 1.9, 0.13)
-- held in the right hand (clients pose the arm with NPCAnim's "umbrella" carry): the handle sits in the fist
-- (measured from the posed hand in a playtest: the shaft stands up from the fist, leaning a touch forward)
local U_GRIP = CFrame.new(-0.053, -0.001, -0.244) * CFrame.fromEulerAnglesXYZ(-1.4276, -0.5938, 0.2568)
local U_HAND_OPEN = U_GRIP * CFrame.new(0, 3.95, 0)
local U_HAND_SHUT = U_GRIP * CFrame.Angles(math.rad(165), 0, 0) * CFrame.new(0, 3.95, 0)
local function makeUmbrella(p)
	local head = p.model:FindFirstChild("Head")
	if not head then return end
	local col = UMBRELLA_COLS[rng:NextInteger(1, #UMBRELLA_COLS)]
	local m = Instance.new("Model")
	m.Name = "Umbrella"
	local function part(name, size, color, mat, mesh)
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.CFrame = head.CFrame
		x.Color = color
		x.Material = mat
		x.CanCollide, x.CanQuery, x.CanTouch, x.Massless = false, false, false, true
		x.CastShadow = name == "Canopy"
		if mesh then
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = mesh
			sm.Parent = x
		end
		x.Parent = m
		return x
	end
	local hub = part("Hub", Vector3.new(0.2, 0.2, 0.2), col, Enum.Material.SmoothPlastic)
	hub.Transparency = 1
	local hand = p.model:FindFirstChild("RightHand")
	local openC0 = hand and U_HAND_OPEN or U_OPEN
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = hand or head, hub, hand and U_HAND_SHUT or U_SHUT
	weld.Parent = hub
	hub:SetAttribute("Hand", hand ~= nil)
	if hand then p.model:SetAttribute("Carry", "umbrella") end
	local function on(x, cf)
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = hub, x, cf
		w.Parent = x
		return x
	end
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.38)
	local canopy = on(part("Canopy", Vector3.new(6.4, 1.7, 6.4), col, Enum.Material.Fabric, Enum.MeshType.Sphere), CFrame.new())
	local under = on(part("Under", Vector3.new(6.0, 1.2, 6.0), dark, Enum.Material.Fabric, Enum.MeshType.Sphere), CFrame.new(0, -0.2, 0))
	local ribs = {}
	for i = 1, 8 do
		local a = (i - 0.5) / 8 * math.pi * 2
		local r = on(part("Rib", Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(46, 46, 52), Enum.Material.Metal, Enum.MeshType.Sphere), CFrame.new(math.cos(a) * 3.2, -0.08, math.sin(a) * 3.2))
		r.Transparency = 1
		table.insert(ribs, r)
	end
	on(part("Tip", Vector3.new(0.2, 0.7, 0.2), Color3.fromRGB(46, 46, 52), Enum.Material.Metal), CFrame.new(0, 0.95, 0))
	on(part("Shaft", Vector3.new(0.12, 3.95, 0.12), Color3.fromRGB(70, 70, 78), Enum.Material.Metal), CFrame.new(0, -1.95, 0))
	on(part("Handle", Vector3.new(0.26, 0.62, 0.26), Color3.fromRGB(96, 60, 36), Enum.Material.Wood), CFrame.new(0, -3.95, 0))
	on(part("Hook", Vector3.new(0.22, 0.22, 0.46), Color3.fromRGB(96, 60, 36), Enum.Material.Wood), CFrame.new(0, -4.27, 0.16))
	-- drips off the rim: an invisible ring the drops fall from
	local ring = on(part("Drip", Vector3.new(0.05, 6.1, 6.1), col, Enum.Material.SmoothPlastic), CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, math.pi / 2))
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 1
	local pe = Instance.new("ParticleEmitter")
	pe.Shape = Enum.ParticleEmitterShape.Cylinder
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pe.Rate = 7
	pe.Lifetime = NumberRange.new(0.35, 0.55)
	pe.Speed = NumberRange.new(0, 0.3)
	pe.Acceleration = Vector3.new(0, -70, 0)
	pe.Size = NumberSequence.new(0.07)
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 220, 240))
	pe.Transparency = NumberSequence.new(0.35)
	pe.Squash = NumberSequence.new(1.6)
	pe.LightEmission = 0.2
	pe.Enabled = false
	pe.Parent = ring
	canopy.Mesh.Scale, under.Mesh.Scale = U_FOLD, U_FOLD
	m.Parent = p.model
	p.umbrella = m
	-- the open: swing up, then pop
	TS:Create(weld, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = openC0 }):Play()
	task.delay(0.28, function()
		if not m.Parent then return end
		TS:Create(canopy.Mesh, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Vector3.one }):Play()
		TS:Create(under.Mesh, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Vector3.one }):Play()
		task.delay(0.3, function()
			for _, r in ipairs(ribs) do r.Transparency = 0 end
			pe.Enabled = true
		end)
	end)
end

local function closeUmbrella(p)
	local m = p.umbrella
	p.umbrella = nil
	if not m then return end
	local hub = m:FindFirstChild("Hub")
	local weld = hub and hub:FindFirstChildOfClass("Weld")
	local shutC0 = (hub and hub:GetAttribute("Hand")) and U_HAND_SHUT or U_SHUT
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("ParticleEmitter") then d.Enabled = false end
		if d.Name == "Rib" then d.Transparency = 1 end
		if d:IsA("SpecialMesh") and d.Parent and (d.Parent.Name == "Canopy" or d.Parent.Name == "Under") then
			TS:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = U_FOLD }):Play()
		end
	end
	if weld then
		task.delay(0.2, function()
			if weld.Parent then TS:Create(weld, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = shutC0 }):Play() end
		end)
	end
	task.delay(0.55, function()
		m:Destroy()
		if p.model and not p.umbrella then p.model:SetAttribute("Carry", nil) end
	end)
end

-- every tick: umbrellas up when it's wet, a hurried pace in the rain (cheap: only acts on a change)
weatherLook = function(p)
	local w = wet()
	local want = w > 0.5 and p.wetMood < 0.7
	if want and not p.umbrella then
		makeUmbrella(p)
	elseif not want and p.umbrella then
		closeUmbrella(p)
	end
	local speed = p.speed * (w > 0.5 and (p.umbrella and 1.12 or 1.35) or 1)
	if p.hum.WalkSpeed ~= speed then p.hum.WalkSpeed = speed end
end

local function tick(p, dt)
	if not p.alive or not p.root or not p.model.Parent then
		retire(p)
		return
	end
	local pos = p.root.Position
	weatherLook(p)
	-- waiting (window shopping, a phone, the crosswalk light)
	if p.pause > 0 then
		p.pause -= dt
		p.hum:Move(Vector3.zero)
		setWalking(p, false)
		if p.waitFor and p.waitFor() then p.pause = 0 end
		if p.pause <= 0 then
			p.waitFor = nil
			if p.lookAt then p.lookAt = nil end
		end
		return
	end
	-- the planned route first (crossing, going in/out of shops), then the lane
	local g = p.plan[1]
	local target
	if g then
		target = Vector3.new(g.x, pos.Y, g.z)
		if Vector3.new(g.x - pos.X, 0, g.z - pos.Z).Magnitude < 1.6 then
			table.remove(p.plan, 1)
			if g.arrive then g.arrive(p) end
			return
		end
	else
		target = Vector3.new(pos.X + p.dir * 10, pos.Y, laneZ(p.side, p.dir) + p.laneOff)
		-- reached the far tunnel, or wandered far from everyone: gone
		if (pos.X - endX(p.dir)) * p.dir > 0 or nearestPlayerDist(pos.X) > FAR_AWAY then
			retire(p)
			return
		end
		-- a hotel's front path: maybe turn in
		local k, hx = hotelPathAhead(p)
		if k then
			p.decided["h" .. k] = true
			local hotel = hotelAt(hx)
			local handle = hotel and Sim.registry[hotel]
			if handle and handle.wantsWalkIn() then
				-- walk up the path, then the hotel takes over
				goal(p, hx + rng:NextNumber(-1.5, 1.5), S.NEAR.z0 - 2, function(pp)
					retire(pp, true)
					for _, t in ipairs({ pp.walk, pp.run, pp.idle, pp.wave }) do pcall(function() t:Stop(0.2) end) end
					pp.hum:Move(Vector3.zero)
					handle.adopt(pp.model, pp.name)
				end)
				return
			end
		end
		-- a crosswalk: sometimes cross over to the other side
		local cx = crossAhead(p)
		if cx then
			p.decided["c" .. cx] = true
			if rng:NextNumber() < 0.3 then
				local fromNear = p.side == "near"
				local cross = cx + (p.dir == 1 and -3 or 3) + rng:NextNumber(-1.5, 1.5)
				local curbA = fromNear and S.NEAR.z1 - 1.2 or S.FAR.z0 + 1.2
				local curbB = fromNear and S.FAR.z0 + 1.5 or S.NEAR.z1 - 1.5
				goal(p, cross, curbA, function(pp)
					-- wait for the walk light (with enough time left to get across)
					pp.pause = 40
					pp.waitFor = function()
						local ph, left = S.signalPhase(workspace:GetServerTimeNow())
						return ph == "walk" and left > 6
					end
				end)
				goal(p, cross, curbB, function(pp)
					pp.side = fromNear and "far" or "near"
				end)
				return
			end
		end
		-- now and then: a pause (window shopping on the shop side, a phone call anywhere)
		p.nextIdea = (p.nextIdea or rng:NextNumber(8, 30)) - dt
		if p.nextIdea <= 0 and wet() > 0.5 then
			p.nextIdea = rng:NextNumber(15, 45) -- nobody window-shops in the rain; some duck into a shop
			if p.side == "far" and rng:NextNumber() < 0.35 then
				goal(p, pos.X + p.dir * 4, S.FAR.z1 + 0.5, function(pp) retire(pp) end)
				return
			end
		elseif p.nextIdea <= 0 then
			p.nextIdea = rng:NextNumber(15, 45)
			local r = rng:NextNumber()
			if p.side == "far" and r < 0.35 then
				-- look in a shop window
				local wx = pos.X + p.dir * 3
				goal(p, wx, S.FAR.z1 - 1.8, function(pp)
					pp.root.CFrame = CFrame.lookAt(pp.root.Position, pp.root.Position + Vector3.new(0, 0, 1))
					pp.pause = rng:NextNumber(3, 7)
				end)
				return
			elseif p.side == "far" and r < 0.55 then
				-- go into a shop (and someone else comes out later)
				goal(p, pos.X + p.dir * 4, S.FAR.z1 + 0.5, function(pp) retire(pp) end)
				return
			elseif r < 0.7 then
				p.pause = rng:NextNumber(2, 5)
				return
			end
		end
	end
	local v = steer(p, target)
	p.hum:Move(v)
	setWalking(p, true)
end

---------------------------------------------------------------- spawning

-- how busy the street is by the hour: a morning rush, a quieter afternoon, a big evening, near-empty small hours
local HOURS = { 0.18, 0.12, 0.1, 0.1, 0.14, 0.3, 0.6, 1.05, 1.15, 0.9, 0.8, 0.85,
	0.95, 0.9, 0.8, 0.8, 0.9, 1.1, 1.2, 1.1, 0.85, 0.6, 0.4, 0.26 }
local WEATHER_CROWD = { clear = 1, cloudy = 0.95, fog = 0.75, rain = 0.55, storm = 0.3, snow = 0.6 }
local function crowdTarget()
	local t = Clock.now()
	local h0 = math.floor(t) % 24
	local a = t - math.floor(t)
	local hour = HOURS[h0 + 1] * (1 - a) + HOURS[(h0 + 1) % 24 + 1] * a
	local w = WEATHER_CROWD[Shared:GetAttribute("Weather") or "clear"] or 1
	return math.floor((C.CROWD or 44) * hour * w + 0.5)
end
-- the crowd that counts is the one round the players: walkers far away don't fill anyone's street
local NEAR_PLAYER = 220 -- round 10d: a tighter ring (fewer walkers simulated)
FAR_AWAY = 280
local function nearCount()
	local n = 0
	for _, p in ipairs(peds) do
		if p.root and nearestPlayerDist(p.root.Position.X) < NEAR_PLAYER then n += 1 end
	end
	return n
end

local function spawnOne(warm)
	local model, name = getBody()
	if not model then return end
	local dir = rng:NextNumber() < 0.5 and 1 or -1
	local side = rng:NextNumber() < 0.55 and "near" or "far"
	local x, z
	local r = rng:NextNumber()
	local px = nearPlayerX()
	if warm then
		x = px or rng:NextNumber(S.X0 + 20, S.X1 - 20)
		z = laneZ(side, dir)
	elseif px and r < 0.8 then
		if side == "near" then
			-- out of the gap between two plots
			local k = math.floor((px - S.centre(1)) / S.PLOT_W + 0.5) + 1
			x = S.centre(math.clamp(k, 1, S.PLOT_COUNT)) + (rng:NextNumber() < 0.5 and -1 or 1) * (S.PLOT_W / 2 - 4)
			z = S.NEAR.z0 + 0.6
			local p = newPed(model, name, x, z, side, dir)
			goal(p, x + dir * 3, laneZ("near", dir), nil)
			return
		end
		-- out of a shop door
		x = px
		z = S.FAR.z1 + 0.5
	elseif r < 0.9 and nearestPlayerDist(dir == 1 and S.X0 - 100 or S.X1 + 100) < FAR_AWAY - 20 then
		-- out of a tunnel
		x = dir == 1 and S.X0 - 100 or S.X1 + 100
		z = laneZ(side, dir)
	else
		-- out of a shop door on the far side
		side = "far"
		x = rng:NextNumber(S.X0 + 60, S.X1 - 60)
		z = S.FAR.z1 + 0.5
	end
	local p = newPed(model, name, x, z, side, dir)
	if not warm and z > S.FAR.z1 then
		goal(p, x + dir * 2, laneZ("far", dir), nil)
	end
end

-- leaving hotel guests rejoin the street
Sim.handOff = function(model, name)
	if not model or not model.Parent then return end
	local pos = model:GetPivot().Position
	local dir = rng:NextNumber() < 0.5 and 1 or -1
	model.Parent = CROWD
	local p = newPed(model, name, pos.X, pos.Z, "near", dir)
	model:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	goal(p, pos.X, S.NEAR.z0 + 1.5, nil)
	-- they already made their choice about this hotel
	for k = 1, S.PLOT_COUNT do
		if math.abs(S.centre(k) - pos.X) < 10 then p.decided["h" .. k] = true end
	end
end

-- start with a full street
task.spawn(function()
	for i = 1, math.floor(crowdTarget() * 0.8) do
		spawnOne(true)
		task.wait(0.15)
	end
end)

-- top the crowd up (a little at a time: building bodies takes a moment)
task.spawn(function()
	while true do
		local want = crowdTarget()
		if nearCount() < want and #peds < want * 1.5 + 6 then
			task.spawn(spawnOne, false)
		end
		task.wait(rng:NextNumber(0.6, 1.4))
	end
end)

-- the walking loop: 10 ticks a second for everyone
task.spawn(function()
	local last = os.clock()
	while true do
		local now = os.clock()
		local dt = now - last
		last = now
		bucketPeds()
		for i = #peds, 1, -1 do
			local p = peds[i]
			if p then
				local ok, err = pcall(tick, p, dt)
				if not ok then
					warn("Shared crowd: " .. tostring(err))
					retire(p)
				end
			end
		end
		task.wait(0.1)
	end
end)
