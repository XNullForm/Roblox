-- ServerScriptService.RAH_Crowds: map-wide street life, purely ambient.
-- Big crowds of pedestrians stroll the sidewalk from one end of the map to the other (some
-- detour down a hotel's front path and linger, so the crosswalk areas always feel busy), and
-- cars cruise the road lanes in both directions. Guests themselves still come from the hotel
-- sims; this layer just makes the street feel alive.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))
local Bodies = require(game.ServerStorage:WaitForChild("RAH_Bodies"))

local rng = Random.new()
local function pick(t) return t[rng:NextInteger(1, #t)] end
local function range(t) return rng:NextNumber(t[1], t[2]) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- the map (kept in sync with RAH_Plots): 6 plots, 220 apart, plot 3 at X=0
local PLOT_W = 220
local PLOT_COUNT = 6
local CENTERS = {}
for k = 1, PLOT_COUNT do table.insert(CENTERS, (k - 3) * PLOT_W) end
local LEFT, RIGHT = CENTERS[1] - PLOT_W / 2, CENTERS[PLOT_COUNT] + PLOT_W / 2 -- -550 .. 770
local SIDEWALK_Z = 66
local PATH_Z = 46 -- the front path between a hotel and the sidewalk

local CROWD = Instance.new("Folder")
CROWD.Name = "StreetCrowd"
CROWD.Parent = workspace

pcall(function() PhysicsService:RegisterCollisionGroup("Guests") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Players") end)
local function setGroup(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CollisionGroup = "Guests" end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then d.CollisionGroup = "Guests" end
	end)
end

---------------------------------------------------------------- pedestrians

local PED_MAX = 28
local peds = {}

local function loadAnims(g)
	local animator = g.hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", g.hum)
	local tracks = {}
	for k, id in pairs(C.ANIM) do
		local a = Instance.new("Animation")
		a.AnimationId = id
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok then tracks[k] = tr end
	end
	if tracks.walk then
		tracks.walk.Priority = Enum.AnimationPriority.Movement
		tracks.walk.Looped = true
		tracks.walk:AdjustSpeed(math.clamp(g.hum.WalkSpeed / 14, 0.65, 1.8))
		tracks.walk:Play(0.2)
	end
	g.tracks = tracks
end

-- steer straight along the sidewalk toward a target X; returns when close in X
local function strollTo(g, targetX, targetZ, timeout)
	local t0 = os.clock()
	local lastPos, lastMove = g.root.Position, os.clock()
	while g.alive and os.clock() - t0 < (timeout or 30) do
		local target = Vector3.new(targetX, g.root.Position.Y, targetZ)
		local offset = flat(target - g.root.Position)
		if math.abs(offset.X) < 1.5 then
			g.hum:Move(Vector3.zero)
			return true
		end
		g.hum:Move(offset.Unit)
		if flat(g.root.Position - lastPos).Magnitude > 0.6 then
			lastPos, lastMove = g.root.Position, os.clock()
		elseif os.clock() - lastMove > 1.5 then
			break -- stuck on something: give up and teleport-finish
		end
		task.wait(0.06)
	end
	g.hum:Move(Vector3.zero)
	g.root.CFrame = CFrame.new(targetX, g.root.Position.Y, targetZ)
	return true
end

local function pedDone(p)
	p.alive = false
	local i = table.find(peds, p)
	if i then table.remove(peds, i) end
	if p.model then p.model:Destroy() end
end

local function spawnPed()
	local model = Bodies.make(pick(C.NAMES), range({ 9, 13 }))
	if not model then return end
	local g = {
		alive = true, model = model,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:WaitForChild("HumanoidRootPart"),
	}
	-- most spawn at a map edge and cross the whole street; some appear mid-map so the
	-- middle fills in quickly at server start
	local fromLeft
	if rng:NextNumber() < 0.25 then
		local cx = pick(CENTERS)
		g.x0 = cx + rng:NextNumber(-90, 90)
		fromLeft = rng:NextNumber() < 0.5
	else
		fromLeft = rng:NextNumber() < 0.5
		g.x0 = fromLeft and LEFT + 4 or RIGHT - 4
	end
	g.dir = fromLeft and 1 or -1
	g.z = SIDEWALK_Z + rng:NextNumber(-4, 4)
	g.exitX = fromLeft and RIGHT + 6 or LEFT - 6
	g.detoured = false
	model:PivotTo(CFrame.new(g.x0, 4, g.z))
	model.Parent = CROWD
	setGroup(model)
	loadAnims(g)
	table.insert(peds, g)
	task.spawn(function()
		local ok, err = pcall(function()
			while g.alive do
				-- near a plot's front path: some pop down the crosswalk, look around, come back
				if not g.detoured then
					for _, cx in ipairs(CENTERS) do
						if math.abs(g.root.Position.X - cx) < 2.5 and rng:NextNumber() < 0.3 then
							g.detoured = true
							if g.tracks.walk then g.tracks.walk:Stop(0.2) end
							strollTo(g, cx, PATH_Z, 20)
							task.wait(range({ 1, 3 })) -- admire the hotel
							if g.tracks.walk then g.tracks.walk:Play(0.2) end
							strollTo(g, cx, g.z, 20)
							break
						end
					end
				end
				if not g.alive then break end
				-- walk the sidewalk until the far end of the map
				strollTo(g, g.exitX, g.z, 180)
				break
			end
		end)
		if not ok then warn("RAH crowd ped: " .. tostring(err)) end
		pedDone(g)
	end)
end

task.spawn(function()
	task.wait(3) -- let the streets clone in first
	-- a starting crowd so the street never looks empty
	for _ = 1, 10 do task.spawn(spawnPed) end
	while true do
		if #peds < PED_MAX then
			spawnPed()
		end
		task.wait(range({ 0.4, 1.6 }))
	end
end)

---------------------------------------------------------------- cars

local CAR_MAX = 6
local cars = {}
local CAR_COLORS = {
	Color3.fromRGB(210, 60, 60), Color3.fromRGB(60, 110, 210), Color3.fromRGB(230, 230, 235),
	Color3.fromRGB(40, 44, 52), Color3.fromRGB(160, 200, 120), Color3.fromRGB(240, 190, 60),
	Color3.fromRGB(150, 150, 160), Color3.fromRGB(90, 60, 140),
}
local LANES = { { z = 79.3, dir = 1 }, { z = 93.1, dir = -1 } }

local function carPart(parent, name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildCar(color)
	local m = Instance.new("Model")
	m.Name = "Car"
	local L, W, H = 13.5, 6.2, 2.3 -- length along X, width along Z, body height
	-- body
	carPart(m, "Body", Vector3.new(L, H, W), CFrame.new(0, H / 2 + 0.85, 0), color)
	carPart(m, "Cabin", Vector3.new(L * 0.45, H * 0.85, W * 0.86), CFrame.new(-0.4, H + 0.85 + H * 0.42, 0), color)
	local glass = carPart(m, "Windshield", Vector3.new(0.25, H * 0.62, W * 0.8), CFrame.new(L * 0.24, H + 0.85 + H * 0.38, 0), Color3.fromRGB(170, 210, 230), Enum.Material.Glass)
	glass.Transparency = 0.45
	carPart(m, "BumperF", Vector3.new(0.5, 1.1, W * 0.94), CFrame.new(L / 2 + 0.2, 1.4, 0), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
	carPart(m, "BumperB", Vector3.new(0.5, 1.1, W * 0.94), CFrame.new(-L / 2 - 0.2, 1.4, 0), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
	-- lights
	for _, sz in ipairs({ -1, 1 }) do
		local head = carPart(m, "Headlight", Vector3.new(0.35, 0.7, 1.1), CFrame.new(L / 2 + 0.1, 1.9, sz * W * 0.3), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
		head.Transparency = 0.1
		local tail = carPart(m, "Taillight", Vector3.new(0.3, 0.6, 1.0), CFrame.new(-L / 2 - 0.1, 1.9, sz * W * 0.3), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		tail.Transparency = 0.1
	end
	-- wheels (named so the drive loop can spin them)
	for _, wx in ipairs({ -L / 2 + 2.4, L / 2 - 2.4 }) do
		for _, wz in ipairs({ -W / 2 + 0.5, W / 2 - 0.5 }) do
			local w = Instance.new("Part")
			w.Name = "Wheel"
			w.Shape = Enum.PartType.Cylinder
			w.Size = Vector3.new(0.9, 2.4, 2.4)
			w.CFrame = CFrame.new(wx, 1.2, wz) * CFrame.Angles(0, 0, math.rad(90))
			w.Color = Color3.fromRGB(35, 35, 40)
			w.Material = Enum.Material.SmoothPlastic
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.Parent = m
		end
	end
	return m
end

local function spawnCar()
	local lane = pick(LANES)
	local model = buildCar(pick(CAR_COLORS))
	-- wheel offsets relative to the car's origin, captured once at build time
	local wheels = {}
	for _, w in ipairs(model:GetChildren()) do
		if w.Name == "Wheel" then table.insert(wheels, { w, w.CFrame }) end
	end
	local car = {
		model = model, wheels = wheels,
		dir = lane.dir,
		speed = range({ 26, 38 }),
		z = lane.z + rng:NextNumber(-1, 1),
		spin = 0,
	}
	car.x = car.dir == 1 and LEFT - 12 or RIGHT + 12
	car.exitX = car.dir == 1 and RIGHT + 14 or LEFT - 14
	car.model:PivotTo(CFrame.new(car.x, 0.2, car.z) * (car.dir == 1 and CFrame.identity or CFrame.Angles(0, math.rad(180), 0)))
	car.model.Parent = CROWD
	table.insert(cars, car)
end

-- one heartbeat drives every car (anchored, no physics)
RunService.Heartbeat:Connect(function(dt)
	for i = #cars, 1, -1 do
		local car = cars[i]
		car.x += car.dir * car.speed * dt
		car.spin = (car.spin + car.speed * dt / 1.2) % (math.pi * 2)
		local cf = CFrame.new(car.x, 0.2, car.z) * (car.dir == 1 and CFrame.identity or CFrame.Angles(0, math.rad(180), 0))
		car.model:PivotTo(cf)
		for _, w in ipairs(car.wheels) do
			w[1].CFrame = cf * w[2] * CFrame.Angles(car.spin, 0, 0)
		end
		if (car.dir == 1 and car.x > car.exitX) or (car.dir == -1 and car.x < car.exitX) then
			table.remove(cars, i)
			car.model:Destroy()
		end
	end
end)

task.spawn(function()
	task.wait(3)
	for _ = 1, 3 do spawnCar() end
	while true do
		if #cars < CAR_MAX then
			spawnCar()
		end
		task.wait(range({ 2.5, 7 }))
	end
end)