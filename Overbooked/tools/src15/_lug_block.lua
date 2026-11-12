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
			if body and body:IsA("BasePart") then k = body.Size.Y / CASE_TOP end
			lg = { model = m, weld = w, k = k, swing = 0, swingV = 0, moveK = 0, lastVel = Vector3.zero, t = 0 }
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
	local top, hz, wz = CASE_TOP * k, CASE_HZ * k, CASE_WZ * k
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
	local hp = lg.c0.Position + V3(0, 1.55, 0)
	lg.weld.C0 = CF(hp) * ANG(-lg.swing, 0, 0) * CF(-hp) * lg.c0
end

-- a world point -> the right hand's IK target (shoulder space, reach units)
local function handTarget(st, side, world)
	local arm = side == "R" and st.rig.armR or st.rig.armL
	local jm = st.rig.j[side == "R" and "rs" or "ls"]
	if not (arm and jm and jm.Part0) then return nil end
	local p = jm.Part0.CFrame:PointToObjectSpace(world) - jm.C0.Position
	local r = arm.reach
	return { p.X / r * arm.side, p.Y / r, p.Z / r }
end

