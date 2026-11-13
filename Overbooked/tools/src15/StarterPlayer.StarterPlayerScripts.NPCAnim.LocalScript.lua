-- NPCAnim (round 14, client; round 15: luggage that rolls and swings, faces that change and talk): plays Shared.NPCAnimLib's hand-keyed motions on every hotel NPC.
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
local Faces = require(RS:WaitForChild("Shared"):WaitForChild("Faces")) -- round 15: faces that move
-- Roblox's stock tracks the gait replaces; anything else playing (laugh, dance) keeps the body
local CORE_ANIM = { ["rbxassetid://507766666"] = true, ["rbxassetid://507766951"] = true, ["rbxassetid://507777826"] = true,
	["rbxassetid://507767714"] = true, ["rbxassetid://2506281703"] = true, ["rbxassetid://507776043"] = true,
	["rbxassetid://913402848"] = true, ["rbxassetid://913376220"] = true, ["rbxassetid://913384386"] = true,
	["rbxassetid://180435571"] = true, ["rbxassetid://180426354"] = true, ["rbxassetid://180435792"] = true,
	["rbxassetid://2510202577"] = true, ["rbxassetid://2510198475"] = true } -- round 32: Rthro walk / run
local player = Players.LocalPlayer

local CF, V3, ANG = CFrame.new, Vector3.new, CFrame.Angles
local clamp, sin, atan2, exp, pi = math.clamp, math.sin, math.atan2, math.exp, math.pi
local IDENT = CFrame.identity

local FAR = 130          -- studs: further NPCs are left to the Animator
local STREET_FAR = 75    -- the same for the street crowd
local TAG = "Bubble" -- every hotel NPC (guests, staff, buddies) carries it
local PTAG = "PlayerPose" -- round 40: a player doing a minigame (server WorkPose sets Pose / WorkAt on their character)
local BUSY = { mop = true, fix = true, cook = true, clean = true, desk = true, text = true, photo = true, read = true, eat = true, inspect = true,
	makebed = true, scrub = true, wipe = true, dust = true, deskkeys = true }

local rigs = {}
local rng = Random.new()
local updateFace -- forward (faces, round 15)

local function smooth(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

---------------------------------------------------------------- tracking

local function startAct(st, name)
	local def = Lib.ACTS[name]
	if not def then return end
	st.act, st.actT0, st.actRate = def, os.clock(), rng:NextNumber(0.94, 1.06)
end

local function track(model, street, isPlayer)
	if rigs[model] or not model:IsA("Model") then return end
	local rig = Lib.rig(model)
	if not rig then
		-- bodies arrive part by part while streaming; try again shortly
		task.delay(1, function()
			if model.Parent and not rigs[model] and (CollectionService:HasTag(model, TAG) or CollectionService:HasTag(model, PTAG)) then track(model, street, isPlayer) end
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
		player = isPlayer, -- no face, no glances: only the work pose
	}
	st.conns = {
		model:GetAttributeChangedSignal("Act"):Connect(function()
			local a = model:GetAttribute("Act")
			if type(a) == "string" then startAct(st, a:match("^([%w_]+)")) end
		end),
		model:GetAttributeChangedSignal("Feel"):Connect(function()
			local f = model:GetAttribute("Feel")
			if type(f) == "string" then st.feel, st.feelUntil = f:match("^(%a+)"), os.clock() + 5.5 end
		end),
		model:GetAttributeChangedSignal("SayN"):Connect(function()
			st.sayAt = os.clock()
			-- in a face-to-face talk the server picks the gesture (Act) to match the line
			if model:GetAttribute("LocalTalk") then return end
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
for _, m in ipairs(CollectionService:GetTagged(PTAG)) do task.spawn(track, m, false, true) end
CollectionService:GetInstanceAddedSignal(PTAG):Connect(function(m) track(m, false, true) end)
CollectionService:GetInstanceRemovedSignal(PTAG):Connect(function(m) untrack(m) end)
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

---------------------------------------------------------------- luggage (round 15)
-- The luggage is welded on the server; each client re-poses the weld locally every frame so it moves like the
-- real thing, and the right hand is solved onto it:
-- * the roller stands upright at their side, hand resting on the handle, while they stand; when they walk it
--   tips back onto its wheels and trails behind, handle in the hand, rattling a little over the floor
-- * the duffel hangs from the hand and swings like a pendulum as they speed up, slow down and turn
-- Suitcase geometry (Shared HotelProps.Suitcase, origin at the bottom centre): handle top (0, 3.86, -0.2),
-- the wheels along the bottom of the -Z face.
local CASE_TOP, CASE_HZ, CASE_WZ = 3.86, -0.2, -0.47

local function luggageOf(st, model)
	local lg = st.lug
	if lg and lg.model.Parent == model and lg.weld.Parent then return lg end
	st.lug = nil
	local m = model:FindFirstChild("Luggage")
	if not m then return nil end
	for _, w in ipairs(m:GetDescendants()) do
		if w:IsA("Weld") and w.Part1 and w.Part0 and not w.Part0:IsDescendantOf(m) then
			local k = 1
			local body = m:FindFirstChild("Body")
			-- round 15: the new luggage says where its handle and wheels are (model attributes); the old case scales
			local top = m:GetAttribute("CaseTop")
			if not top and body and body:IsA("BasePart") then k = body.Size.Y / CASE_TOP end
			lg = { model = m, weld = w, k = k, swing = 0, swingV = 0, moveK = 0, lastVel = Vector3.zero, t = 0,
				top = top or CASE_TOP, hz = m:GetAttribute("CaseHZ") or CASE_HZ, wz = m:GetAttribute("CaseWZ") or CASE_WZ,
				hang = m:GetAttribute("HangY") or 1.55 }
			st.lug = lg
			return lg
		end
	end
	return nil
end

-- the roller: sets the weld, returns the handle (world) for the hand
local function rollCase(st, model, root, dt, now)
	local lg = luggageOf(st, model)
	if not lg or lg.weld.Part0 ~= root then return nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local floor = (hum and hum.HipHeight or 2) + root.Size.Y / 2
	local k = lg.k
	local top, hz, wz = lg.top * k, lg.hz * k, lg.wz * k
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local want = speed > 1.2 and 1 or 0
	lg.moveK += (want - lg.moveK) * (1 - exp(-dt * (want > lg.moveK and 5 or 3.5)))
	local mk = smooth(lg.moveK)
	-- rolling: the handle sits where a relaxed hand trails (down and a little behind the hip); the case tips
	-- until its handle is at that height, wheels on the floor
	local hand = V3(1.08, -0.5, 0.62)
	local hy = floor + hand.Y -- the handle's height above the floor
	local th = -0.2
	for _ = 1, 12 do
		-- height of the handle above the wheel line for a tilt th (rotating about the wheel edge)
		local y = (top) * math.cos(th) - (hz - wz) * math.sin(th)
		local dy = -(top) * math.sin(th) - (hz - wz) * math.cos(th)
		if math.abs(dy) < 1e-4 then break end
		th = clamp(th - (y - hy) / dy, -1.25, 0)
	end
	local rattle = sin(now * 23 + st.ph1) * 0.012 * mk * clamp(speed / 8, 0, 1.5)
	local zOff = (top) * math.sin(th) + (hz - wz) * math.cos(th) -- handle forward of the wheels (negative = forward)
	local rollPos = V3(hand.X, -floor, hand.Z - zOff)
	local rollCF = CF(rollPos) * ANG(th, 0, rattle) * CF(0, 0, -wz)
	-- standing: upright beside them, leaning in a touch
	local standCF = CF(1.62, -floor, -0.25) * ANG(-0.12, 0.15, -0.05) * CF(0, 0, -wz)
	local cf = standCF:Lerp(rollCF, mk)
	lg.weld.C0 = cf
	-- the handle top in world space (a hair under it, where the fingers close)
	return root.CFrame * cf * CF(0, top - 0.12, hz)
end

-- the duffel: a pendulum hanging from the hand
local function swingBag(st, model, root, dt)
	local lg = luggageOf(st, model)
	if not lg then return end
	if not lg.c0 then lg.c0 = lg.weld.C0 end
	local v = root.AssemblyLinearVelocity
	local acc = (v - lg.lastVel) / math.max(dt, 1 / 240)
	lg.lastVel = v
	-- forward acceleration in the body's frame drives the swing (speeding up throws it back)
	local la = root.CFrame:VectorToObjectSpace(acc)
	local force = -clamp(la.Z, -60, 60) * 0.0065
	-- a damped pendulum (about 1.4 Hz)
	lg.swingV += (force - lg.swing * 78 - lg.swingV * 3.2) * dt
	lg.swing = clamp(lg.swing + lg.swingV * dt, -0.6, 0.6)
	-- the hang point is the top of the bag (where the hand is): rotate about it
	local hp = lg.c0.Position + V3(0, lg.hang, 0)
	lg.weld.C0 = CF(hp) * ANG(-lg.swing, 0, 0) * CF(-hp) * lg.c0
end

-- a world point -> the right hand's IK target (shoulder space, reach units)
local function handTarget(st, side, world)
	local arm = side == "R" and st.rig.armR or st.rig.armL
	local jm = st.rig.j[side == "R" and "rs" or "ls"]
	if not (arm and jm and jm.Part0) then return nil end
	local p = jm.Part0.CFrame:PointToObjectSpace(world) - jm.C0.Position
	local r = arm.reach
	return { p.X / r * arm.side, p.Y / r, p.Z / r }, p.Magnitude / r
end

---------------------------------------------------------------- round 27: hands on the work, and the mop
-- A pose with `anchor` hands is written round a world point (model attribute WorkAt, or a part found nearby for
-- Lib.ANCHORED poses). findNear looks for that part once a second.
local function findNear(st, root, name, now)
	local p = st.findPart
	if p and p.Parent and p.Name == name and (p.Position - root.Position).Magnitude < 6 then return p end
	if now < (st.findAt or 0) then return nil end
	st.findAt = now + 2
	st.findPart = nil
	-- desk kit parts don't answer spatial queries, so look through the desks of their own hotel
	local hotel = st.rig.model.Parent and st.rig.model.Parent.Parent
	if not hotel then return nil end
	local best, bd
	local function try(m)
		local q = m:FindFirstChild(name, true)
		if q and q:IsA("BasePart") then
			local d = (q.Position - root.Position).Magnitude
			if d < 6 and (not bd or d < bd) then best, bd = q, d end
		end
	end
	local lobby = hotel:FindFirstChild("Lobby")
	local desk = lobby and lobby:FindFirstChild("Desk")
	if desk then try(desk) end
	local placed = hotel:FindFirstChild("Placed")
	for _, m in ipairs(placed and placed:GetChildren() or {}) do
		if (m:GetPivot().Position - root.Position).Magnitude < 9 then try(m) end
	end
	st.findPart = best
	return best
end

-- the janitor's mop or broom (welded to the right hand by StaffLook; its first part is "Mop..." / "Broom...")
local function toolOf(st, model, now)
	local t = st.tool
	if t then
		if t.weld.Parent and t.part.Parent then return t end
		st.tool = nil
	end
	if now < (st.toolCheck or 0) then return nil end
	st.toolCheck = now + 1.5
	if not model:GetAttribute("BRole") then st.toolCheck = now + 30 return nil end
	local hand = model:FindFirstChild("RightHand")
	if not hand then return nil end
	for _, w in ipairs(model:GetDescendants()) do
		if w:IsA("Weld") and w.Part0 == hand and w.Part1 then
			local n = w.Part1.Name
			local kind = (n:sub(1, 3) == "Mop" and "Mop") or (n:sub(1, 5) == "Broom" and "Broom") or nil
			if kind then
				local hum = model:FindFirstChildOfClass("Humanoid")
				t = { weld = w, part = w.Part1, hand = hand, def = Lib.TOOLS[kind], stowW = 0,
					floor = (hum and hum.HipHeight or 2) + (st.root and st.root.Size.Y / 2 or 1) }
				st.tool = t
				return t
			end
		end
	end
	return nil
end

-- Sets the tool's weld for this frame and returns how much it is in the hands (0 = put down) and the world
-- point on the handle for the other hand.
--   in the hands: the grip follows the right hand and the head rests on the floor toward (hx, hz) in front
--   put down (any pose but mopping): it stands on its head beside them until the job is done
local function stepTool(st, t, root, dt, stow, hx, hz)
	local hand = t.hand
	if not hand.Parent then return 0 end
	local floorY = root.Position.Y - t.floor
	local hp = hand.Position
	local look = root.CFrame.LookVector
	local tgt = root.CFrame * V3(hx, 0, hz)
	local fd = V3(tgt.X - hp.X, 0, tgt.Z - hp.Z)
	fd = fd.Magnitude > 0.05 and fd.Unit or V3(look.X, 0, look.Z).Unit
	local h = hp.Y - floorY
	local L = t.def.head
	local d = math.sqrt(math.max(L * L - h * h, 0.02))
	local headPos = V3(hp.X, math.max(floorY, hp.Y - L), hp.Z) + fd * d
	local up = (hp - headPos).Unit
	local right = fd:Cross(up)
	local held = right.Magnitude > 0.01 and CFrame.fromMatrix(hp, right.Unit, up) or CF(hp)
	if stow and t.stowW <= 0 then
		-- where it gets stood: at their right, a step back
		local p = root.CFrame * V3(1.9, 0, 0.7)
		t.stowCF = CFrame.lookAt(V3(p.X, floorY + L, p.Z), V3(p.X, floorY + L, p.Z) + V3(look.X, 0, look.Z)) * ANG(0, 0, -0.05)
	end
	t.stowW = clamp(t.stowW + (stow and dt / 0.4 or -dt / 0.35), 0, 1)
	local w = t.weld
	if t.stowW >= 1 and t.stowCF then
		if w.Part0 ~= root then w.Part0 = root end
		w.C0 = root.CFrame:ToObjectSpace(t.stowCF)
	else
		if w.Part0 ~= hand then w.Part0 = hand end
		local cf = held
		if t.stowW > 0 and t.stowCF then
			local k = smooth(t.stowW)
			-- lifted a little on the way so it doesn't drag through the floor
			cf = held:Lerp(t.stowCF, k) + V3(0, math.sin(k * pi) * 0.5, 0)
		end
		w.C0 = hand.CFrame:ToObjectSpace(cf)
	end
	w.C1 = IDENT
	return 1 - t.stowW, held * V3(0, t.def.top, 0)
end

local arms = { R = {}, L = {} }
local legs = {}

---------------------------------------------------------------- faces (round 15)
-- The drawn face layers (Shared.Faces) on the ClassicHead: the feel of their last line for a few seconds,
-- else their mood (Mood) or tiredness (Energy); blinks; the mouth follows what they're saying, letter by letter.
local SLEEPY = { sleep = true, bed = true, nap = true }
local function faceOf(st, model, now)
	local f = st.faceRef
	if f and f.upper.Parent and f.mouth.Parent then return f end
	if now < (st.faceCheck or 0) then return nil end
	st.faceCheck = now + 1.5
	local ch = model:FindFirstChild("ClassicHead")
	local up = ch and ch:FindFirstChild("FaceUpper")
	local mo = ch and ch:FindFirstChild("FaceMouth")
	if not (up and mo) then st.faceRef = nil return nil end
	f = { upper = up, mouth = mo, brow = ch:FindFirstChild("FaceBrow"), extra = ch:FindFirstChild("FaceExtra"), blinkAt = now + rng:NextNumber(0.5, 4), blinkUntil = 0, lipAt = 0, tick = 0 }
	st.faceRef = f
	return f
end
updateFace = function(st, model, now)
	local f = faceOf(st, model, now)
	if not f then return end
	local style, lips, bstyle = model:GetAttribute("FaceStyle"), model:GetAttribute("FaceLips"), model:GetAttribute("FaceBrow")
	local upper, mouth, blush
	if st.feel and now < (st.feelUntil or 0) then
		local e = Faces.EXPR[st.feel]
		if e then upper, mouth, blush = e[1], e[2], e[3] end
	end
	if not upper then
		if SLEEPY[model:GetAttribute("Pose") or ""] then
			upper, mouth = "blink", "smallO"
		else
			local m, en = model:GetAttribute("Mood"), model:GetAttribute("Energy")
			upper, mouth = Faces.moodExpr(type(m) == "number" and m or nil, type(en) == "number" and en or nil)
		end
	end
	-- blinks (now and then a double)
	if now >= f.blinkAt then
		f.blinkUntil = now + 0.12
		f.blinkAt = now + (rng:NextNumber() < 0.15 and 0.28 or rng:NextNumber(1.8, 5.5))
	end
	if now < f.blinkUntil and upper ~= "joy" and upper ~= "blink" then upper = "blink" end
	-- talking: the mouth follows the letters
	local t0 = model:GetAttribute("SpeakT0")
	if t0 then
		local k = (now - t0) / math.max(model:GetAttribute("SpeakDur") or 1, 0.2)
		if k >= 0 and k < 1 then
			if now >= f.lipAt then
				f.lipAt = now + 0.07
				f.tick += 1
				f.lip = Faces.lipShape(tostring(model:GetAttribute("SpeakText") or ""), k, mouth, f.tick)
			end
			mouth = f.lip or mouth
		end
	end
	-- round 16: eyes, brows (tinted to their hair, set by the server) and lips from the new kit
	if upper ~= f.u then
		f.u = upper
		f.upper.Texture = Faces.eyeTex(style, upper)
		if f.brow and f.brow.Parent then f.brow.Texture = Faces.browTex(bstyle, upper) end
	end
	if mouth ~= f.m then f.m = mouth f.mouth.Texture = Faces.mouthTex(lips, mouth) end
	if f.extra and (blush and true or false) ~= f.b then
		f.b = blush and true or false
		f.extra.Texture = blush and Faces.id(Faces.BLUSH) or ""
	end
end

local function step(st, now, dt, camPos, myHead)
	local rig, model, root = st.rig, st.rig.model, st.root
	local j = rig.j
	if not (root and root.Parent) then return end
	local dist = (root.Position - camPos).Magnitude
	if not st.wrote and dist > (st.street and STREET_FAR + 10 or FAR) then return end -- round 31: far and already handed back

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
	local anchorAt
	local alt = want and Lib.ANCHORED[want]
	if alt then
		local p = findNear(st, root, alt.find, now)
		if p then want, anchorAt = alt.pose, p.Position + V3(0, p.Size.Y / 2, 0) end
	end
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

	-- round 27: hands written round the work point -> arm targets; the body leans in until they reach
	local leaning = false
	if poseDef and poseDef.anchor then
		local at = anchorAt or model:GetAttribute("WorkAt")
		local look = root.CFrame.LookVector
		local fl = V3(look.X, 0, look.Z)
		if typeof(at) == "Vector3" and fl.Magnitude > 0.01 and (at - root.Position).Magnitude < 9 then
			local W = CFrame.lookAt(at, at + fl.Unit)
			local far = 0
			for side in pairs(poseDef.anchor) do
				local x = poseV[side .. "x"]
				if x then
					local tg, d = handTarget(st, side, W * V3(x, poseV[side .. "y"], poseV[side .. "z"]))
					if tg then
						poseV[side .. "x"], poseV[side .. "y"], poseV[side .. "z"] = tg[1], tg[2], tg[3]
						if d > far then far = d end
					end
				end
			end
			if not poseDef.noLean then
				leaning = true
				st.lean = clamp((st.lean or 0) + clamp((far - 0.9) * 5, -1.2, 1.8) * dt, 0, 1)
				if frozen then st.lean = clamp((st.lean or 0) + clamp((far - 0.9) * 5, -1.2, 1.8) * 0.05, 0, 1) end
			end
		else
			-- nothing to put the hands on: leave the arms alone
			for side in pairs(poseDef.anchor) do
				poseV[side .. "x"], poseV[side .. "y"], poseV[side .. "z"] = nil, nil, nil
			end
		end
	end
	if not leaning and (st.lean or 0) > 0 then st.lean = math.max(0, st.lean - dt * 3) end
	local leanK = (st.lean or 0)
	if poseDef and (leanK > 0 or poseDef.minCrouch) then
		poseV.wx = (poseV.wx or 0) - 0.72 * leanK
		poseV.crouch = math.max(poseV.crouch or 0, poseDef.minCrouch or 0, 0.5 * leanK)
	end

	-- the mop: in the hands (head on the floor) or stood beside them while they do something else
	local tool = toolOf(st, model, now)
	local toolW, toolL, mopW = 0, nil, 0
	if tool then
		mopW = (st.poseCur == "mop") and pw or 0
		local TC = Lib.TOOL_CARRY
		local hx = TC.hx + ((poseV.hx or TC.hx) - TC.hx) * mopW
		local hz = TC.hz + ((poseV.hz or TC.hz) - TC.hz) * mopW
		local stow = (want ~= nil and want ~= "mop") or (st.poseCur ~= nil and st.poseCur ~= "mop")
		local grip
		toolW, grip = stepTool(st, tool, root, dt, stow, hx, hz)
		if grip and mopW > 0 then
			local tg = handTarget(st, "L", grip)
			if tg then
				st.toolLT = st.toolLT or {}
				st.toolLT.Lx, st.toolLT.Ly, st.toolLT.Lz = tg[1], tg[2], tg[3]
				toolL = st.toolLT
			end
		end
	end

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
	local caseHand
	if st.carryCur == "case" then
		local w = rollCase(st, model, root, dt, now)
		if w then caseHand = handTarget(st, "R", w.Position) end
	elseif st.carryCur == "bag" then
		swingBag(st, model, root, dt)
	end

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
	local talkLock = model:GetAttribute("LocalTalk")
	if myHead and not frozen and not st.player then
		local to = (talkLock and camPos or myHead.Position) - (root.Position + V3(0, 1.6, 0))
		local dd = to.Magnitude
		local talking = st.sayAt and now - st.sayAt < 4
		if talkLock or dd < 6 or (talking and dd < 16) or (dd < 11 and now < st.gFocusUntil) then
			local l = root.CFrame:VectorToObjectSpace(to)
			local yaw = atan2(-l.X, -l.Z)
			if talkLock or math.abs(yaw) < 1.9 then
				gazeY = clamp(yaw, -1.1, 1.1)
				gazeP = clamp(atan2(l.Y, math.sqrt(l.X * l.X + l.Z * l.Z)), -0.45, 0.4)
				if dd < 11 and now >= st.gFocusUntil then st.gFocusUntil = now + rng:NextNumber(2, 5) end
			end
		end
	end
	if st.player then gazeY, gazeP = 0, 0 end
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
	if dist < 60 and not st.player then updateFace(st, model, now) end
	-- a motion that keys the head owns it
	local headBusy = math.max(pw * ((poseV.ny or poseV.nx) and 0.75 or 0), aw * ((actV.ny or actV.nx) and 0.85 or 0))
	local gw = 1 - headBusy
	-- in a face-to-face talk their eyes stay on you: gestures only nod and tilt the head a little
	if talkLock then gw = math.max(gw, 0.85) end

	-- compose ---------------------------------------------------------------
	for key in pairs(add) do add[key] = 0 end
	addLayer(poseV, pw, vig)
	if carryDef then addLayer(carryDef, cw, 1) end
	local ny0, nx0, wy0 = add.ny, add.nx, add.wy
	addLayer(actV, aw, vig)
	if talkLock then
		add.ny = ny0 + (add.ny - ny0) * 0.2
		add.nx = nx0 + (add.nx - nx0) * 0.55
		add.wy = wy0 + (add.wy - wy0) * 0.4
	end
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
		if toolW > 0 and side == "R" and pw < 1 then
			armLayer(st, "R", Lib.TOOL_CARRY, toolW * (1 - pw), Lib.TOOL_CARRY.pole, a)
		end
		if poseDef then
			armLayer(st, side, poseV, pw, poseDef.pole and poseDef.pole[side], a)
			wristLayer(a, p .. "w", poseV, pw)
		end
		if toolL and side == "L" then
			armLayer(st, "L", toolL, mopW * toolW, poseDef and poseDef.pole and poseDef.pole.L, a)
		end
		if carryDef and carryDef[side] then
			local c = carryDef[side]
			if side == "R" and caseHand then c = caseHand end
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
	local legsTouched = (poseDef and (poseDef.useLegs or poseDef.useCrouch or poseV.crouch)) or (actDef and (actDef.useLegs or actDef.useCrouch)) or st.gaitW > 0.002
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
	if pw > 0 or aw > 0 or cw > 0 or toolW > 0 or st.gaitW > 0.002 then
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
