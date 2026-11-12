-- StarterPlayerScripts.RAH_Traffic: cars and buses driving the avenue (round 9). Runs on each client
-- (smooth, and costs the server nothing). Cars come out of one tunnel and drive to the other, keep a
-- gap to the car ahead, stop at red lights (the cycle comes from server time via RAH.Street, so every
-- player sees the same lights), and brake for anyone standing in their lane. Wheels turn, noses dip
-- under braking, brake lights glow and headlights come on at night. Also lights the traffic signals.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local RAH = RS:WaitForChild("RAH")
local S = require(RAH:WaitForChild("Street"))
local Clock = require(RAH:WaitForChild("Clock"))
local CARS = RAH:WaitForChild("Cars")

local rng = Random.new()
local FOLDER = Instance.new("Folder")
FOLDER.Name = "RAH_Traffic"
FOLDER.Parent = workspace

local COLORS = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 240, 240), Color3.fromRGB(40, 42, 48),
	Color3.fromRGB(150, 156, 164), Color3.fromRGB(70, 170, 120), Color3.fromRGB(240, 130, 60), Color3.fromRGB(120, 80, 170),
	Color3.fromRGB(180, 210, 230), Color3.fromRGB(140, 30, 40), Color3.fromRGB(30, 60, 110), Color3.fromRGB(250, 220, 120) }
local KINDS = { "Sedan", "Sedan", "Hatch", "Hatch", "SUV", "SUV", "Taxi", "Taxi", "Van", "Pickup" }
local MAX_CARS = 16
local START_X = { [1] = S.X0 - 135, [-1] = S.X1 + 135 } -- inside the tunnels
local END_X = { [1] = S.X1 + 140, [-1] = S.X0 - 140 }

local cars = {}
local lanes = { [1] = {}, [-1] = {} }

---------------------------------------------------------------- spawning

local function spawnCar(dir, kind)
	local tpl = CARS:FindFirstChild(kind)
	if not tpl then return end
	local m = tpl:Clone()
	local paint = kind == "Taxi" and Color3.fromRGB(255, 196, 40) or (kind == "Bus" and Color3.fromRGB(245, 245, 240) or COLORS[rng:NextInteger(1, #COLORS)])
	local parts, offsets, wheels = {}, {}, {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("Group") == "paint" then d.Color = paint end
			if not d.Parent:IsA("Model") or d.Parent == m then
				table.insert(parts, d)
				table.insert(offsets, d.CFrame) -- the template's pivot is the origin
			end
		end
	end
	for _, w in ipairs(m:GetChildren()) do
		if w.Name == "Wheel" then
			local hub = w.WorldPivot
			local wp = {}
			for _, p in ipairs(w:GetChildren()) do
				table.insert(wp, { part = p, rel = hub:ToObjectSpace(p.CFrame) })
			end
			table.insert(wheels, { hub = hub, parts = wp, r = w:GetAttribute("Radius") or 1.35 })
		end
	end
	local glow = m:FindFirstChild("Glow")
	local car = {
		model = m, dir = dir, kind = kind,
		x = START_X[dir], v = 0, a = 0,
		cruise = (kind == "Bus" and 30 or rng:NextNumber(36, 48)),
		len = m:GetAttribute("Length") or 15,
		lane = dir == 1 and S.LANES[2].z or S.LANES[1].z,
		parts = parts, offsets = offsets, wheels = wheels, spin = 0, pitch = 0,
		glow = glow, light = glow and glow:FindFirstChildOfClass("SpotLight"),
	}
	car.v = car.cruise * 0.8
	m.Parent = FOLDER
	table.insert(cars, car)
	table.insert(lanes[dir], car)
	return car
end

local function removeCar(car)
	car.model:Destroy()
	table.remove(cars, table.find(cars, car))
	table.remove(lanes[car.dir], table.find(lanes[car.dir], car))
end

-- the entry is clear when the last car in that lane has moved off
local function entryClear(dir)
	for _, c in ipairs(lanes[dir]) do
		if math.abs(c.x - START_X[dir]) < c.len + 14 then return false end
	end
	return true
end

---------------------------------------------------------------- driving

-- distance (along dir) from the car's front bumper to the next stop line it must obey, or nil
local function stopLineAhead(car)
	local front = car.x + car.dir * car.len / 2
	local best
	for _, cx in ipairs(S.CROSS) do
		local line = cx - car.dir * (S.CROSS_W / 2 + 3)
		local d = (line - front) * car.dir
		if d > -1 and (not best or d < best) then best = d end
	end
	return best
end

local function obstacleAhead(car)
	-- the nearest car ahead in this lane
	local best
	for _, c in ipairs(lanes[car.dir]) do
		if c ~= car then
			local gap = (c.x - car.x) * car.dir - (c.len + car.len) / 2
			if gap > -2 and (not best or gap < best) then best = gap end
		end
	end
	-- anyone standing in the lane ahead (players and other characters)
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and math.abs(root.Position.Z - car.lane) < 6 and root.Position.Y < 12 then
			local gap = (root.Position.X - car.x) * car.dir - car.len / 2 - 2
			if gap > -3 and (not best or gap < best) then best = gap end
		end
	end
	return best
end

local MAX_ACC, MAX_BRAKE = 16, 55
local function drive(car, dt, phase, phaseLeft)
	local want = car.cruise
	-- traffic in front: keep a time gap (simple intelligent-driver style)
	local gap = obstacleAhead(car)
	if gap then
		local safe = 6 + car.v * 0.9
		if gap < safe then
			want = math.min(want, math.max(0, (gap - 5) * 1.4))
		end
	end
	-- the signal: stop if the light is not green and we can stop in time (amber: only if comfortably)
	if phase ~= "go" then
		local d = stopLineAhead(car)
		if d and d < 70 then
			local brakeDist = car.v * car.v / (2 * 30)
			if phase == "walk" or d > brakeDist + 2 then
				want = math.min(want, math.max(0, (d - 0.5) * 1.1))
			end
		end
	elseif phaseLeft < 1.2 then
		-- about to turn: creep slower near the line
		local d = stopLineAhead(car)
		if d and d < 30 then want = math.min(want, car.cruise * 0.7) end
	end
	local acc = math.clamp((want - car.v) * 2.2, -MAX_BRAKE, MAX_ACC)
	car.a = acc
	car.v = math.max(0, car.v + acc * dt)
	car.x += car.dir * car.v * dt
end

---------------------------------------------------------------- signals

local signalParts = {}
local function collectSignals()
	table.clear(signalParts)
	for _, m in ipairs(CollectionService:GetTagged("RAH_Signal")) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Lens") then table.insert(signalParts, d) end
		end
	end
end
collectSignals()
CollectionService:GetInstanceAddedSignal("RAH_Signal"):Connect(function() task.defer(collectSignals) end)

local LENS = {
	Red = Color3.fromRGB(255, 50, 40), Amber = Color3.fromRGB(255, 176, 30), Green = Color3.fromRGB(60, 240, 120),
	Walk = Color3.fromRGB(250, 250, 255), DontWalk = Color3.fromRGB(255, 120, 40),
}
local DARK = Color3.fromRGB(38, 38, 42)
local lastPhase
local function paintSignals(phase, left)
	local blink = phase == "go" and left < 4 and (left % 0.8 < 0.4) -- the walk man flashes before it turns
	if phase == lastPhase and phase ~= "go" then return end
	lastPhase = phase
	for _, p in ipairs(signalParts) do
		local lens = p:GetAttribute("Lens")
		local on
		if lens == "Red" then on = phase == "walk"
		elseif lens == "Amber" then on = phase == "amber"
		elseif lens == "Green" then on = phase == "go"
		end
		if lens == "Walk" then
			p.Color = phase == "walk" and LENS.Walk or (blink and DARK or LENS.DontWalk)
			p.Material = Enum.Material.Neon
		else
			p.Color = on and LENS[lens] or DARK
			p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
end

---------------------------------------------------------------- the loop

local spawnTimer = { [1] = 0, [-1] = 1.5 }
local busTimer = 25
local nightOn
local moveParts, moveCFs = {}, {}

-- warm start: a few cars already on the road when you arrive
for _, dir in ipairs({ 1, -1 }) do
	for i = 1, 4 do
		local c = spawnCar(dir, KINDS[rng:NextInteger(1, #KINDS)])
		if c then c.x = S.X0 + (S.X1 - S.X0) * (i - 0.5) / 4 + rng:NextNumber(-60, 60); c.v = c.cruise end
	end
end

RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local phase, left = S.signalPhase(workspace:GetServerTimeNow())
	paintSignals(phase, left)

	-- spawning
	for _, dir in ipairs({ 1, -1 }) do
		spawnTimer[dir] -= dt
		if spawnTimer[dir] <= 0 and #cars < MAX_CARS and entryClear(dir) then
			spawnTimer[dir] = rng:NextNumber(3, 8)
			busTimer -= 1
			local kind = KINDS[rng:NextInteger(1, #KINDS)]
			if busTimer <= 0 then kind = "Bus"; busTimer = rng:NextInteger(6, 10) end
			spawnCar(dir, kind)
		end
	end

	local night = Clock.isNight(Clock.now()) or Clock.now() > 18.8
	table.clear(moveParts)
	table.clear(moveCFs)
	local camPos = workspace.CurrentCamera.CFrame.Position
	for i = #cars, 1, -1 do
		local car = cars[i]
		drive(car, dt, phase, left)
		-- round 10d: far cars skip the bounce (nobody can see it)
		local far = math.abs(car.x - camPos.X) > 260 or math.abs(car.lane - camPos.Z) > 260
		if (car.x - END_X[car.dir]) * car.dir > 0 then
			removeCar(car)
		else
			-- body: position, a little nose dip under braking, a tiny bounce
			car.pitch += ((math.clamp(-car.a / 55, -1, 1) * math.rad(1.6)) - car.pitch) * math.min(1, dt * 6)
			local yaw = car.dir == 1 and 0 or math.pi
			local base = CFrame.new(car.x, 0, car.lane) * CFrame.Angles(0, yaw, 0)
			local body = far and base or base * CFrame.new(0, 0.04 * math.sin(os.clock() * 9 + car.x * 0.1) * math.min(1, car.v / 20), 0) * CFrame.Angles(0, 0, -car.pitch)
			for j, p in ipairs(car.parts) do
				table.insert(moveParts, p)
				table.insert(moveCFs, body * car.offsets[j])
			end
			-- wheels roll with the distance covered
			car.spin -= car.v * dt / (car.wheels[1] and car.wheels[1].r or 1.35)
			for _, w in ipairs(car.wheels) do
				local hub = base * w.hub * CFrame.Angles(0, 0, car.spin)
				for _, wp in ipairs(w.parts) do
					table.insert(moveParts, wp.part)
					table.insert(moveCFs, hub * wp.rel)
				end
			end
			-- lights
			if car.glow then
				local braking = car.a < -6 or car.v < 0.5
				local lit = night or braking
				if car.glowLit ~= lit then
					car.glowLit = lit
					car.glow.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
				if car.light and car.light.Enabled ~= night then car.light.Enabled = night end
			end
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
