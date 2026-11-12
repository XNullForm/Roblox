-- NPCAnim (round 14, client): plays Shared.NPCAnimLib's hand-keyed motions on every hotel NPC.
-- Reads the model attributes Pose, Act ("name:serial") and Carry that the server sets, and layers them over the
-- Animator's walk / idle / sit. Also gives everyone a living head: they glance around, look at you when you
-- come close or when they talk to you, and gesture while they speak (the bubble's SayN).
-- Joints are written in PreSimulation, after the Animator. A joint the Animator didn't touch this frame still
-- holds what we wrote, so we remember the base we started from and reuse it (no drift, no pops).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local Lib = require(RS:WaitForChild("Shared"):WaitForChild("NPCAnimLib"))
local Gait = require(RS:WaitForChild("Shared"):WaitForChild("NPCGait")) -- round 14e: our own walk and idle
-- Roblox's stock tracks the gait replaces; anything else playing (laugh, dance) keeps the body
local CORE_ANIM = { ["rbxassetid://507766666"] = true, ["rbxassetid://507766951"] = true, ["rbxassetid://507777826"] = true,
	["rbxassetid://507767714"] = true, ["rbxassetid://2506281703"] = true, ["rbxassetid://507776043"] = true,
	["rbxassetid://913402848"] = true, ["rbxassetid://913376220"] = true, ["rbxassetid://913384386"] = true,
	["rbxassetid://180435571"] = true, ["rbxassetid://180426354"] = true, ["rbxassetid://180435792"] = true }
local player = Players.LocalPlayer

local CF, V3, ANG = CFrame.new, Vector3.new, CFrame.Angles
local clamp, sin, atan2, exp, pi = math.clamp, math.sin, math.atan2, math.exp, math.pi
local IDENT = CFrame.identity

local FAR = 130          -- studs: further NPCs are left to the Animator
local STREET_FAR = 75    -- the same for the street crowd
local TAG = "Bubble" -- every hotel NPC (guests, staff, buddies) carries it
local BUSY = { mop = true, fix = true, cook = true, clean = true, desk = true, text = true, photo = true, read = true, eat = true, inspect = true }

local rigs = {}
local rng = Random.new()

local function smooth(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

---------------------------------------------------------------- tracking

local function startAct(st, name)
	local def = Lib.ACTS[name]
	if not def then return end
	st.act, st.actT0, st.actRate = def, os.clock(), rng:NextNumber(0.94, 1.06)
end

local function track(model, street)
	if rigs[model] or not model:IsA("Model") then return end
	local rig = Lib.rig(model)
	if not rig then
		-- bodies arrive part by part while streaming; try again shortly
		task.delay(1, function()
			if model.Parent and not rigs[model] and CollectionService:HasTag(model, TAG) then track(model) end
		end)
		return
	end
	local st = {
		rig = rig, base = {}, anim = {}, out = {}, wrote = false,
		gait = nil, gaitW = 0, gOut = {}, -- round 15: back on Roblox's own walk and idle (the hand-made gait looked wrong in motion)
		poseW = 0, poseCur = nil, poseT0 = 0, poseRate = rng:NextNumber(0.9, 1.1),
		carryW = 0, carryCur = nil,
		gy = 0, gp = 0, gty = 0, gtp = 0, gNext = 0, gFocusUntil = 0,
		ph1 = rng:NextNumber(0, 2 * pi), ph2 = rng:NextNumber(0, 2 * pi),
		root = model:FindFirstChild("HumanoidRootPart"),
		lastSay = model:GetAttribute("SayN"),
		street = street,
	}
	st.conns = {
		model:GetAttributeChangedSignal("Act"):Connect(function()
			local a = model:GetAttribute("Act")
			if type(a) == "string" then startAct(st, a:match("^([%w_]+)")) end
		end),
		model:GetAttributeChangedSignal("SayN"):Connect(function()
			st.sayAt = os.clock()
			local pose = model:GetAttribute("Pose")
			if st.act or (pose and BUSY[pose]) then return end
			if model:GetAttribute("Carry") then
				if rng:NextNumber() < 0.6 then startAct(st, "talk3") end
			else
				local line = tostring(model:GetAttribute("Say") or "")
				local T = Lib.TALK
				local pool
				if model:GetAttribute("SayMode") == "think" then
					if rng:NextNumber() < 0.55 then pool = T.think else return end
				elseif line:find("%?") then pool = T.ask
				elseif line:find("!") or (#line > 5 and line == line:upper() and line:find("%u")) then pool = T.shout
				elseif model:GetAttribute("Voice") == "grump" and rng:NextNumber() < 0.6 then pool = T.angry
				elseif model:GetAttribute("BRole") and rng:NextNumber() < 0.55 then pool = T.polite
				else pool = T.plain end
				startAct(st, pool[rng:NextInteger(1, #pool)])
			end
		end),
	}
	rigs[model] = st
	-- a pose sheet sets Act before the model is tracked
	local a0 = model:GetAttribute("Act")
	if type(a0) == "string" and model:GetAttribute("AnimT") then startAct(st, a0:match("^([%w_]+)")) end
end

local function untrack(model)
	local st = rigs[model]
	if not st then return end
	for _, c in ipairs(st.conns) do c:Disconnect() end
	if st.prop then st.prop:Destroy() end
	rigs[model] = nil
end

for _, m in ipairs(CollectionService:GetTagged(TAG)) do task.spawn(track, m) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m) track(m) end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
	local st = rigs[m]
	if st and st.street then return end
	untrack(m)
end)

-- round 14: the people on the street too (fidgets while they wait, glances, the umbrella hold), within a
-- shorter range since there are many of them (STREET_FAR, up top)
task.spawn(function()
	while true do
		local crowd = workspace:FindFirstChild("StreetCrowd")
		local cam = workspace.CurrentCamera
		if crowd and cam then
			local cp = cam.CFrame.Position
			for _, m in ipairs(crowd:GetChildren()) do
				if not rigs[m] then
					local r = m:FindFirstChild("HumanoidRootPart")
					if r and (r.Position - cp).Magnitude < STREET_FAR then track(m, true) end
				end
			end
		end
		task.wait(0.8)
	end
end)

---------------------------------------------------------------- per frame

local vals, poseV, actV = {}, {}, {}
local function clear(t) for k in pairs(t) do t[k] = nil end end

-- additive channel sum
local add = { nx = 0, ny = 0, nz = 0, wx = 0, wy = 0, wz = 0, tx = 0, ty = 0, tz = 0, px = 0, py = 0, pz = 0 }
local ADD_KEYS = { "nx", "ny", "nz", "wx", "wy", "wz", "tx", "ty", "tz", "px", "py", "pz" }

local function addLayer(src, w, vig)
	if w <= 0 then return end
	for _, k in ipairs(ADD_KEYS) do
		local v = src[k]
		if v then add[k] += v * w * vig end
	end
end

-- arm from a layer: IK if the layer keys that hand
local function armLayer(st, sideKey, src, w, pole, cur)
	if w <= 0 then return cur end
	local x = src[sideKey .. "x"]
	if not x then return cur end
	local arm = sideKey == "R" and st.rig.armR or st.rig.armL
	if not arm then return cur end
	local sh, el = Lib.solveArm(arm, x, src[sideKey .. "y"], src[sideKey .. "z"], pole)
	cur.sh = cur.sh:Lerp(sh, w)
	cur.el = cur.el:Lerp(el, w)
	return cur
end

local function wristLayer(cur, prefix, src, w)
	if w <= 0 then return end
	local x, y, z = src[prefix .. "x"], src[prefix .. "y"], src[prefix .. "z"]
	if x or y or z then
		cur.wr = cur.wr:Lerp(ANG(x or 0, y or 0, z or 0), w)
	end
end

local LEG_KEYS = { "rh", "rk", "ra", "lh", "lk", "la" }
local function legLayer(st, legs, src, w)
	if w <= 0 then return end
	local c = src.crouch
	if c and c > 0.001 then
		local drop = 0
		for _, side in ipairs({ "r", "l" }) do
			local info = side == "r" and st.rig.legR or st.rig.legL
			if info then
				local hp, kn, an, d = Lib.solveCrouch(info, c)
				legs[side .. "h"] = legs[side .. "h"]:Lerp(ANG(hp, 0, 0), w)
				legs[side .. "k"] = legs[side .. "k"]:Lerp(ANG(kn, 0, 0), w)
				legs[side .. "a"] = legs[side .. "a"]:Lerp(ANG(an, 0, 0), w)
				drop = math.max(drop, d)
			end
		end
		add.py -= drop * w
	end
	for _, k in ipairs(LEG_KEYS) do
		local x = src[k .. "x"]
		if x then legs[k] = legs[k]:Lerp(ANG(x, src[k .. "y"] or 0, src[k .. "z"] or 0), w) end
	end
end

local arms = { R = {}, L = {} }
local legs = {}

local function step(st, now, dt, camPos, myHead)
	local rig, model, root = st.rig, st.rig.model, st.root
	local j = rig.j
	if not (root and root.Parent) then return end
	local dist = (root.Position - camPos).Magnitude

	-- the base each joint starts from (the Animator's pose, or what was there before we wrote)
	for k, m in pairs(j) do
		local cur = m.Transform
		local last = st.out[k]
		if last and (cur == last or cur:FuzzyEq(last, 2e-4)) then -- AnimationConstraint reads back with rounding
			-- untouched by the Animator since our write: keep the base we had
		else
			st.anim[k] = cur
		end
		st.base[k] = st.anim[k]
	end

	if dist > (st.street and STREET_FAR + 10 or FAR) then
		if st.wrote then
			for k, m in pairs(j) do
				if st.anim[k] then m.Transform = st.anim[k] end
				st.out[k] = nil
			end
			st.wrote = false
			st.gaitW = 0
		end
		return
	end

	-- layers -------------------------------------------------------------
	-- the looping activity (fades out before a new one fades in)
	local want = model:GetAttribute("Pose")
	if want ~= nil and not Lib.POSES[want] then want = nil end
	if want ~= st.poseCur then
		st.poseW = math.max(0, st.poseW - dt / 0.25)
		if st.poseW <= 0 or st.poseCur == nil then
			st.poseCur, st.poseT0, st.poseW = want, now, 0
			if st.prop then st.prop:Destroy(); st.prop = nil end
			local d = want and Lib.POSES[want]
			if d and d.prop then st.prop = Lib.prop(d.prop, model) end
		end
	elseif want then
		st.poseW = math.min(1, st.poseW + dt / 0.35)
	end
	local poseDef = st.poseCur and Lib.POSES[st.poseCur]
	local pw = poseDef and smooth(st.poseW) or 0
	-- Studio pose sheets: model attribute AnimT freezes every layer at that time
	local frozen = model:GetAttribute("AnimT")
	if frozen and want then
		if st.poseCur ~= want then
			st.poseCur = want
			if st.prop then st.prop:Destroy(); st.prop = nil end
			local d = Lib.POSES[want]
			if d and d.prop then st.prop = Lib.prop(d.prop, model) end
		end
		poseDef, pw, st.poseW = Lib.POSES[want], 1, 1
	end
	clear(poseV)
	if poseDef then Lib.sample(poseDef, frozen or (now - st.poseT0) * st.poseRate, poseV) end

	-- round 14e: the hand-keyed walk / idle under everything (not while seated, frozen or in a Roblox emote)
	if st.gait then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if now >= (st.trackCheck or 0) then
			st.trackCheck = now + 0.3
			st.emoting = false
			local an = hum and hum:FindFirstChildOfClass("Animator")
			if an then
				for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
					local id = tr.Animation and tr.Animation.AnimationId
					if id and not CORE_ANIM[id] and tr.WeightTarget > 0.3 then st.emoting = true break end
				end
			end
		end
		local seated = hum and (hum.Sit or hum.SeatPart ~= nil or hum:GetState() == Enum.HumanoidStateType.Seated)
		local gwant = (not seated and not st.emoting and not frozen and not (poseDef and poseDef.ownsBody)) and 1 or 0
		st.gaitW += (gwant - st.gaitW) * (1 - exp(-dt * 9))
		if st.gaitW > 0.002 then
			Gait.step(st.gait, dt, root, st.gOut, now)
			local gw0 = st.gaitW
			for key, cf in pairs(st.gOut) do
				local a = st.anim[key]
				if j[key] then st.base[key] = a and a:Lerp(cf, gw0) or cf end
			end
		end
	end

	-- carrying luggage
	local carry = model:GetAttribute("Carry")
	if carry ~= nil and not Lib.CARRY[carry] then carry = nil end
	if carry ~= st.carryCur then
		st.carryW = math.max(0, st.carryW - dt / 0.2)
		if st.carryW <= 0 then st.carryCur = carry end
	elseif carry then
		st.carryW = math.min(1, st.carryW + dt / 0.3)
	end
	local carryDef = st.carryCur and Lib.CARRY[st.carryCur]
	local cw = carryDef and smooth(st.carryW) or 0

	-- a one-shot gesture
	local actDef = st.act
	local aw = 0
	clear(actV)
	if actDef then
		local t = (now - st.actT0) * st.actRate
		if frozen then
			aw = 1
			Lib.sample(actDef, frozen, actV)
		elseif t >= actDef.len then
			st.act, actDef = nil, nil
		else
			aw = smooth(t / 0.15) * smooth((actDef.len - t) / 0.25)
			Lib.sample(actDef, t, actV)
		end
	end

	-- standing about: a fidget now and then (client-side, so everyone fidgets differently)
	if not actDef and not frozen then
		if not st.fidgetAt then st.fidgetAt = now + rng:NextNumber(3, 12) end
		if now >= st.fidgetAt then
			st.fidgetAt = now + rng:NextNumber(7, 17)
			local hum = model:FindFirstChildOfClass("Humanoid")
			if not want and not carry and dist < 90 and root.AssemblyLinearVelocity.Magnitude < 0.6
				and not (hum and (hum.Sit or hum.SeatPart)) and (not st.sayAt or now - st.sayAt > 3) then
				local F = Lib.FIDGETS
				local pool = model:GetAttribute("BRole") and F.staff or F.guest
				local w = workspace:GetAttribute("Weather")
				if (w == "Snow" or w == "snow") and rng:NextNumber() < 0.5 then pool = F.cold end
				startAct(st, pool[rng:NextInteger(1, #pool)])
			end
		end
	end

	-- vigor drift: nobody does the same motion the same way twice
	local vig = 1 + 0.1 * sin(now * 2 * pi * 0.29 + st.ph1) + 0.06 * sin(now * 2 * pi * 0.17 + st.ph2)

	-- the head: glance around, look at you ---------------------------------
	local moving = root.AssemblyLinearVelocity.Magnitude > 2
	local gazeY, gazeP
	if myHead and not frozen then
		local to = myHead.Position - (root.Position + V3(0, 1.6, 0))
		local dd = to.Magnitude
		local talking = st.sayAt and now - st.sayAt < 4
		if dd < 6 or (talking and dd < 16) or (dd < 11 and now < st.gFocusUntil) then
			local l = root.CFrame:VectorToObjectSpace(to)
			local yaw = atan2(-l.X, -l.Z)
			if math.abs(yaw) < 1.9 then
				gazeY = clamp(yaw, -1.1, 1.1)
				gazeP = clamp(atan2(l.Y, math.sqrt(l.X * l.X + l.Z * l.Z)), -0.45, 0.4)
				if dd < 11 and now >= st.gFocusUntil then st.gFocusUntil = now + rng:NextNumber(2, 5) end
			end
		end
	end
	if not gazeY then
		if frozen then
			st.gty, st.gtp, st.gy, st.gp = 0, 0, 0, 0
		elseif now >= st.gNext then
			st.gNext = now + rng:NextNumber(1.4, 4.2)
			if moving or rng:NextNumber() < 0.4 then
				st.gty, st.gtp = rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.08, 0.04)
			else
				st.gty, st.gtp = rng:NextNumber(-0.75, 0.75), rng:NextNumber(-0.15, 0.1)
			end
		end
		gazeY, gazeP = st.gty, st.gtp
	end
	local k = 1 - exp(-dt * 7)
	st.gy += (gazeY - st.gy) * k
	st.gp += (gazeP - st.gp) * k
	-- a motion that keys the head owns it
	local headBusy = math.max(pw * ((poseV.ny or poseV.nx) and 0.75 or 0), aw * ((actV.ny or actV.nx) and 0.85 or 0))
	local gw = 1 - headBusy

	-- compose ---------------------------------------------------------------
	for key in pairs(add) do add[key] = 0 end
	addLayer(poseV, pw, vig)
	if carryDef then addLayer(carryDef, cw, 1) end
	addLayer(actV, aw, vig)
	add.ny += st.gy * 0.72 * gw
	add.wy += st.gy * 0.22 * gw
	add.nx += st.gp * gw

	-- arms
	for _, side in ipairs({ "R", "L" }) do
		local a = arms[side]
		local p = side == "R" and "r" or "l"
		a.sh = st.base[p .. "s"] or IDENT
		a.el = st.base[p .. "e"] or IDENT
		a.wr = st.base[p .. "w"] or IDENT
		if poseDef then
			armLayer(st, side, poseV, pw, poseDef.pole and poseDef.pole[side], a)
			wristLayer(a, p .. "w", poseV, pw)
		end
		if carryDef and carryDef[side] then
			local c = carryDef[side]
			local tmp = { [side .. "x"] = c[1], [side .. "y"] = c[2], [side .. "z"] = c[3] }
			armLayer(st, side, tmp, cw, carryDef.pole, a)
			if side == "R" then wristLayer(a, "rw", carryDef, cw) end
		end
		if actDef then
			armLayer(st, side, actV, aw, actDef.pole and actDef.pole[side], a)
			wristLayer(a, p .. "w", actV, aw)
		end
	end

	-- legs (only motions that key them)
	local legsTouched = (poseDef and (poseDef.useLegs or poseDef.useCrouch)) or (actDef and (actDef.useLegs or actDef.useCrouch)) or st.gaitW > 0.002
	if legsTouched then
		for _, key in ipairs(LEG_KEYS) do legs[key] = st.base[key] or IDENT end
		if poseDef then legLayer(st, legs, poseV, pw) end
		if actDef then legLayer(st, legs, actV, aw) end
	end

	-- write -----------------------------------------------------------------
	local function put(key, cf)
		local m = j[key]
		if m then
			m.Transform = cf
			st.out[key] = cf
		end
	end
	put("neck", (st.base.neck or IDENT) * ANG(add.nx, add.ny, add.nz))
	put("waist", (st.base.waist or IDENT) * ANG(add.wx, add.wy, add.wz))
	put("root", (st.base.root or IDENT) * CF(add.px, add.py, add.pz) * ANG(add.tx, add.ty, add.tz))
	if pw > 0 or aw > 0 or cw > 0 or st.gaitW > 0.002 then
		put("rs", arms.R.sh); put("re", arms.R.el); put("rw", arms.R.wr)
		put("ls", arms.L.sh); put("le", arms.L.el); put("lw", arms.L.wr)
		st.armsOut = true
	elseif st.armsOut then
		-- hand the arms back to the Animator
		for _, key in ipairs({ "rs", "re", "rw", "ls", "le", "lw" }) do
			if j[key] and st.anim[key] then j[key].Transform = st.anim[key] end
			st.out[key] = nil
		end
		st.armsOut = false
	end
	if legsTouched then
		for _, key in ipairs(LEG_KEYS) do put(key, legs[key]) end
		st.legsOut = true
	elseif st.legsOut then
		for _, key in ipairs(LEG_KEYS) do
			if j[key] and st.anim[key] then j[key].Transform = st.anim[key] end
			st.out[key] = nil
		end
		st.legsOut = false
	end
	st.wrote = true
end

RunService.PreSimulation:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local camPos = cam.CFrame.Position
	local char = player.Character
	local myHead = char and char:FindFirstChild("Head")
	local now = os.clock()
	for model, st in pairs(rigs) do
		if model.Parent then
			local ok, err = pcall(step, st, now, dt, camPos, myHead)
			if not ok then
				warn("NPCAnim: " .. tostring(err))
				untrack(model)
			end
		else
			untrack(model)
		end
	end
end)

-- Studio preview hook: _G.NPCAnimTest(model) tracks a local clone (used by the pose sheet)
if RunService:IsStudio() then
	_G.NPCAnimTrack = function(model) track(model) return rigs[model] ~= nil end
	_G.NPCAnimState = function(model) return rigs[model] end
end
