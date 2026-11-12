-- Shared.NPCGait (round 14e, 2026-11-09): a hand-keyed procedural walk and idle for every R15 hotel NPC,
-- replacing Roblox's stock walk/idle under NPCAnim's gesture layers. Client only (NPCAnim calls it).
--   * the walk is keyed per joint on a 0..1 cycle (heel strike, loading, mid-stance, toe-off, swing) and sampled
--     with periodic cubic curves, so it moves through poses rather than wobbling on sines
--   * stride length and cadence come from the real speed, so feet barely slide
--   * arms swing against the legs with a lag, roll inward as they come forward and bend at the elbow
--   * hips yaw and roll, shoulders counter-rotate, the head stays level; leaning into starts, settling on stops,
--     a small bank into turns
--   * idle: an uneven breath (quick in, slow out) and weight shifts from leg to leg with a relaxed knee
--   * every NPC walks a little differently: a style from who they are (Persona / GuestType / staff), plus jitter
-- Gait.new(model, rig) -> g;  Gait.step(g, dt, root, out) fills out[jointKey] = CFrame and returns the weight

local Gait = {}

local CF, ANG, V3 = CFrame.new, CFrame.Angles, Vector3.new
local clamp, abs, exp, pi, max, min = math.clamp, math.abs, math.exp, math.pi, math.max, math.min

---------------------------------------------------------------- curves

-- periodic cubic (Catmull-Rom with tangents clamped so a key is never overshot between two of the same side)
local function periodic(keys)
	-- keys = { {t, v}, ... } with t ascending in [0, 1); the curve wraps
	local n = #keys
	local T, Vv = table.create(n), table.create(n)
	for i, k in ipairs(keys) do T[i], Vv[i] = k[1], k[2] end
	local M = table.create(n)
	for i = 1, n do
		local ip, inx = (i - 2) % n + 1, i % n + 1
		local tp = T[ip] - (i == 1 and 1 or 0)
		local tn = T[inx] + (i == n and 1 or 0)
		local d0 = (Vv[i] - Vv[ip]) / (T[i] - tp)
		local d1 = (Vv[inx] - Vv[i]) / (tn - T[i])
		if d0 * d1 <= 0 then M[i] = 0 else M[i] = (d0 + d1) / 2 end
	end
	return function(t)
		t = t % 1
		local i = n
		for k = 1, n do
			if T[k] > t then i = k - 1 break end
		end
		local a, b, ta, tb
		if i == 0 then
			a, b = n, 1
			ta, tb = T[n] - 1, T[1]
		else
			a = i
			b = i % n + 1
			ta, tb = T[a], T[b] + (b == 1 and 1 or 0)
		end
		local h = tb - ta
		local s = (t - ta) / h
		local s2, s3 = s * s, s * s * s
		return (2 * s3 - 3 * s2 + 1) * Vv[a] + (s3 - 2 * s2 + s) * h * M[a] + (-2 * s3 + 3 * s2) * Vv[b] + (s3 - s2) * h * M[b]
	end
end

-- the right leg; p = 0 is the right heel striking with that leg forward. The left is p + 0.5.
local HIP = periodic({ { 0.00, 1.00 }, { 0.10, 0.85 }, { 0.30, 0.20 }, { 0.50, -0.70 }, { 0.58, -0.86 }, { 0.66, -0.60 },
	{ 0.76, 0.05 }, { 0.88, 0.85 }, { 0.96, 1.00 } })
-- the knee folds most while the thigh passes under the hip, so the foot clears the floor without kicking back
local KNEE = periodic({ { 0.00, -0.06 }, { 0.10, -0.26 }, { 0.26, -0.12 }, { 0.46, -0.10 }, { 0.58, -0.40 }, { 0.68, -0.82 },
	{ 0.76, -0.78 }, { 0.86, -0.36 }, { 0.95, -0.06 } })
-- the ankle on top of keeping the sole flat: toes up at the strike, a push at toe-off, toes lifted through swing
local ANKLE = periodic({ { 0.00, 0.24 }, { 0.08, 0.0 }, { 0.44, 0.0 }, { 0.58, -0.46 }, { 0.66, -0.34 }, { 0.80, 0.12 }, { 0.94, 0.22 } })
-- one bob per step (sampled at 2p): lowest just after the strike, highest at mid-stance
local BOB = periodic({ { 0.00, -0.55 }, { 0.12, -1.00 }, { 0.42, 0.40 }, { 0.62, 0.25 }, { 0.85, -0.25 } })
-- side sway toward the standing foot
local SWAY = periodic({ { 0.00, 0.0 }, { 0.18, 0.85 }, { 0.32, 1.0 }, { 0.50, 0.0 }, { 0.68, -0.85 }, { 0.82, -1.0 } })
-- the breath: in quickly, a short hold, out slowly
local BREATH = periodic({ { 0.00, 0.0 }, { 0.30, 1.0 }, { 0.40, 0.92 }, { 0.85, 0.08 } })

---------------------------------------------------------------- styles

local STYLES = {
	--          stride  arm   elbow lo/hi    bob  lean    knee  cad   sway  stiff  idle lean, arms out
	normal = { A = 1.0, B = 0.42, e0 = 0.20, e1 = 0.34, bob = 1.0, lean = -0.04, knee = 1.0, cad = 1.0, sway = 1.0, roll = 0.14, idleLean = 0.0 },
	brisk  = { A = 1.06, B = 0.30, e0 = 0.42, e1 = 0.62, bob = 0.8, lean = -0.08, knee = 0.95, cad = 1.1, sway = 0.6, roll = 0.10, idleLean = -0.01 },
	bouncy = { A = 1.0, B = 0.55, e0 = 0.26, e1 = 0.55, bob = 1.8, lean = -0.03, knee = 1.2, cad = 1.06, sway = 1.1, roll = 0.18, idleLean = 0.0 },
	stroll = { A = 0.9, B = 0.30, e0 = 0.10, e1 = 0.20, bob = 0.75, lean = 0.01, knee = 0.85, cad = 0.92, sway = 1.35, roll = 0.16, idleLean = 0.03 },
	stomp  = { A = 1.0, B = 0.18, e0 = 0.14, e1 = 0.18, bob = 1.35, lean = -0.02, knee = 0.8, cad = 1.02, sway = 0.5, roll = 0.04, idleLean = -0.02, heel = 1.5 },
	sneak  = { A = 0.95, B = 0.24, e0 = 0.55, e1 = 0.75, bob = 0.6, lean = -0.17, knee = 1.15, cad = 1.08, sway = 0.7, roll = 0.08, idleLean = -0.06, crouch = 0.12 },
}
Gait.STYLES = STYLES

local BY_PERSONA = {
	["On business"] = "brisk", ["Fitness fan"] = "bouncy", ["Social butterfly"] = "bouncy", ["Here to relax"] = "stroll",
	["Bookworm"] = "stroll", ["Tourist"] = "normal", ["Foodie"] = "stroll", ["Shopaholic"] = "brisk",
}
local BY_TYPE = { karen = "stomp", dasher = "sneak", party = "bouncy", influencer = "bouncy", sleepy = "stroll", bigspender = "brisk" }

function Gait.styleOf(model)
	if model:GetAttribute("GaitStyle") and STYLES[model:GetAttribute("GaitStyle")] then return model:GetAttribute("GaitStyle") end
	local gt = model:GetAttribute("GuestType")
	if gt and BY_TYPE[gt] then return BY_TYPE[gt] end
	if model:GetAttribute("BRole") then return "brisk" end
	local p = model:GetAttribute("Persona")
	if p and BY_PERSONA[p] then return BY_PERSONA[p] end
	return "normal"
end

---------------------------------------------------------------- state

function Gait.new(model, rig, rng)
	rng = rng or Random.new()
	local name = Gait.styleOf(model)
	local base = STYLES[name]
	local s = {}
	for k, v in pairs(base) do s[k] = v end
	-- nobody walks exactly like their type
	s.A *= rng:NextNumber(0.94, 1.06)
	s.B *= rng:NextNumber(0.85, 1.15)
	s.bob *= rng:NextNumber(0.85, 1.15)
	s.cad *= rng:NextNumber(0.96, 1.04)
	s.lean += rng:NextNumber(-0.015, 0.015)
	local L = 2.0
	if rig.legR and rig.legR.Lt then L = rig.legR.Lt + rig.legR.Ls + 0.15 end
	return {
		style = s, styleName = name, model = model, L = L,
		phase = rng:NextNumber(0, 1), breathT = rng:NextNumber(0, 10), breathLen = rng:NextNumber(3.6, 4.6),
		speed = 0, walkW = 0, w = 0,
		accel = 0, leanS = 0, leanV = 0, lastSpeed = 0,
		yaw = nil, yawRate = 0,
		side = rng:NextNumber() < 0.5 and -1 or 1, sideS = 0, sideV = 0, nextShift = rng:NextNumber(2, 6),
		settle = 0, settleV = 0,
		armLagX = 0,
	}
end

-- critically damped spring step toward target
local function spring(x, v, target, freq, damp, dt)
	local w = 2 * pi * freq
	local f = 1 + 2 * dt * damp * w
	local oo = w * w
	local hoo = dt * oo
	local hhoo = dt * hoo
	local detInv = 1 / (f + hhoo)
	local nx = (f * x + dt * v + hhoo * target) * detInv
	local nv = (v + hoo * (target - x)) * detInv
	return nx, nv
end

---------------------------------------------------------------- per frame

-- out: jointKey -> CFrame (rs re rw ls le lw rh rk ra lh lk la neck waist root)
function Gait.step(g, dt, root, out, now)
	local s = g.style
	dt = min(dt, 0.1)
	local v = root.AssemblyLinearVelocity
	local hs = V3(v.X, 0, v.Z).Magnitude
	if hs < 0.15 then hs = 0 end
	local fs = g.model:GetAttribute("GaitSpeed") -- Studio pose sheets: a fake speed and a held phase
	if fs then hs = fs end
	g.speed += (hs - g.speed) * (1 - exp(-dt * 10))
	local speed = g.speed

	-- acceleration (for the lean into starts and the settle on stops)
	local acc = (speed - g.lastSpeed) / max(dt, 1e-3)
	g.lastSpeed = speed
	g.accel += (clamp(acc, -60, 60) - g.accel) * (1 - exp(-dt * 8))
	g.leanS, g.leanV = spring(g.leanS, g.leanV, clamp(g.accel * 0.0035, -0.09, 0.07), 1.6, 0.45, dt)

	-- turning
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if g.yaw then
		local d = (yaw - g.yaw + pi) % (2 * pi) - pi
		g.yawRate += (d / max(dt, 1e-3) - g.yawRate) * (1 - exp(-dt * 6))
	end
	g.yaw = yaw

	-- walk weight (0 standing, 1 walking)
	local wantW = clamp((speed - 0.6) / 2.6, 0, 1)
	local was = g.walkW
	g.walkW += (wantW - g.walkW) * (1 - exp(-dt * 7))
	local ww = g.walkW * g.walkW * (3 - 2 * g.walkW)
	if was > 0.45 and g.walkW <= 0.45 then g.settleV -= 0.9 * s.bob end -- a little sink as they stop
	g.settle, g.settleV = spring(g.settle, g.settleV, 0, 2.2, 0.32, dt)

	-- stride: amplitude grows with speed; cadence from the distance a cycle covers
	local A = clamp(0.24 + 0.026 * speed, 0.3, 0.62) * s.A
	local cycleDist = 4 * g.L * math.sin(A) * 1.08
	local f = speed > 0.05 and (speed / cycleDist) * s.cad or 0
	f = clamp(f, 0, 2.6)
	g.phase = (g.phase + f * dt) % 1
	local fp = g.model:GetAttribute("GaitPhase")
	if fp then g.phase = fp end
	local p = g.phase

	-- legs -----------------------------------------------------------------
	local kneeAmt = s.knee * (0.75 + 0.25 * clamp(speed / 10, 0, 1.4))
	local function leg(ph)
		local hn = HIP(ph)
		local hip = hn * A
		local knee = KNEE(ph) * kneeAmt
		local ank = -(hip + knee) + ANKLE(ph) * (ph < 0.1 and (s.heel or 1) or 1)
		return hip, knee, ank, hn
	end
	local rH, rK, rA, rN = leg(p)
	local lH, lK, lA, lN = leg(p + 0.5)

	-- idle stance: weight on one leg, the other knee relaxed; shifts every few seconds
	g.nextShift -= dt
	if g.nextShift <= 0 then
		g.nextShift = 3.5 + math.random() * 5.5
		g.side = -g.side
	end
	g.sideS, g.sideV = spring(g.sideS, g.sideV, g.side, 0.55, 0.62, dt)
	local sd = g.sideS -- +1 = weight on the right foot
	local shift = 0.13 * sd
	local legLean = -shift / g.L
	local relaxR = clamp(-sd, 0, 1)
	local relaxL = clamp(sd, 0, 1)
	local crouch = s.crouch or 0
	local iRH, iRK, iRA = 0.06 * relaxR + crouch, -0.2 * relaxR - crouch * 1.6, 0.14 * relaxR + crouch * 0.6
	local iLH, iLK, iLA = 0.06 * relaxL + crouch, -0.2 * relaxL - crouch * 1.6, 0.14 * relaxL + crouch * 0.6

	local function mix(a, b) return a + (b - a) * ww end
	local hipZ = legLean * (1 - ww)
	out.rh = ANG(mix(iRH, rH + crouch * 0.6), 0, hipZ - 0.02 * relaxR * (1 - ww))
	out.rk = ANG(mix(iRK, rK - crouch * 0.9), 0, 0)
	out.ra = ANG(mix(iRA, rA + crouch * 0.3), 0, -hipZ)
	out.lh = ANG(mix(iLH, lH + crouch * 0.6), 0, hipZ + 0.02 * relaxL * (1 - ww))
	out.lk = ANG(mix(iLK, lK - crouch * 0.9), 0, 0)
	out.la = ANG(mix(iLA, lA + crouch * 0.3), 0, -hipZ)

	-- the body ---------------------------------------------------------------
	g.breathT += dt
	local b = BREATH(g.breathT / g.breathLen)
	local bob = BOB((2 * p) % 1) * 0.085 * s.bob * clamp(speed / 8, 0.5, 1.4)
	local sway = SWAY(p) * 0.055 * s.sway
	local pelvisYaw = 0.085 * rN * clamp(speed / 9, 0.4, 1.2)
	local pelvisRoll = -0.035 * SWAY(p) * s.sway
	local bank = clamp(-g.yawRate * speed * 0.0035, -0.05, 0.05)
	local idleY = -abs(sd) * 0.02 + b * 0.012
	local py = mix(idleY, bob - 0.02) + g.settle * 0.06
	local px = mix(shift, sway)
	local tz = mix(-0.035 * sd, pelvisRoll + bank)
	local ty = mix(0.03 * sd, pelvisYaw)
	out.root = CF(px, py, 0) * ANG(0, ty, tz)
	local lean = mix(s.idleLean - 0.012 * b, s.lean + g.leanS * 0.6) + (1 - ww) * g.leanS * 0.5
	local waistYaw = mix(-0.04 * sd, -1.75 * pelvisYaw)
	out.waist = ANG(lean, waistYaw, mix(0.03 * sd, -pelvisRoll * 0.6))
	out.neck = ANG(-lean * 0.7 - 0.01 * b, -(ty + waistYaw) * 0.75, -tz * 0.5)

	-- arms -------------------------------------------------------------------
	local lagP = p - 0.035
	local function arm(sign, ph, idleSide)
		local swing = -HIP(ph) * s.B * clamp(speed / 9, 0.35, 1.25)
		local fwd = max(swing, 0)
		local wx = mix(0.05 + 0.02 * b, swing)
		local wz = mix(0.06 + 0.03 * b + 0.05 * idleSide, 0.075 + 0.05 * max(-swing, 0)) * sign
		local wyaw = mix(0.0, 0.22 * swing) * sign
		local el = mix(0.16 + 0.03 * b, s.e0 + (s.e1 - s.e0) * clamp(fwd / max(s.B, 0.05), 0, 1) + 0.06 * (1 - fwd))
		local wr = mix(-0.06, -0.08 - 0.12 * fwd)
		return ANG(wx, wyaw, wz), ANG(el, 0, 0), ANG(wr, 0, 0.04 * sign)
	end
	out.rs, out.re, out.rw = arm(1, lagP + 0.5, relaxR * 0.4)   -- the right arm swings with the left leg
	out.ls, out.le, out.lw = arm(-1, lagP, relaxL * 0.4)

	-- how much this layer owns the body: fade out while sitting
	return ww
end

return Gait
