p = "src15/StarterPlayer.StarterPlayerScripts.NPCAnim.LocalScript.lua"
s = open(p, encoding="utf8").read()
def rep(a, b):
    global s
    assert a in s, a[:70]
    s = s.replace(a, b, 1)

rep('local Gait = require(RS:WaitForChild("Shared"):WaitForChild("NPCGait")) -- round 14e: our own walk and idle\n',
    'local Gait = require(RS:WaitForChild("Shared"):WaitForChild("NPCGait")) -- round 14e: our own walk and idle\n'
    'local Faces = require(RS:WaitForChild("Shared"):WaitForChild("Faces")) -- round 15: faces that move\n')
rep("-- NPCAnim (round 14, client; round 15: luggage that rolls and swings)",
    "-- NPCAnim (round 14, client; round 15: luggage that rolls and swings, faces that change and talk)")
# the feel of their last line
rep('''		model:GetAttributeChangedSignal("SayN"):Connect(function()
			st.sayAt = os.clock()
			local pose = model:GetAttribute("Pose")''',
'''		model:GetAttributeChangedSignal("Feel"):Connect(function()
			local f = model:GetAttribute("Feel")
			if type(f) == "string" then st.feel, st.feelUntil = f:match("^(%a+)"), os.clock() + 5.5 end
		end),
		model:GetAttributeChangedSignal("SayN"):Connect(function()
			st.sayAt = os.clock()
			-- in a face-to-face talk the server picks the gesture (Act) to match the line
			if model:GetAttribute("LocalTalk") then return end
			local pose = model:GetAttribute("Pose")''')
# eyes on you while you talk to them
rep('''	if myHead and not frozen then
		local to = myHead.Position - (root.Position + V3(0, 1.6, 0))
		local dd = to.Magnitude
		local talking = st.sayAt and now - st.sayAt < 4
		if dd < 6 or (talking and dd < 16) or (dd < 11 and now < st.gFocusUntil) then
			local l = root.CFrame:VectorToObjectSpace(to)
			local yaw = atan2(-l.X, -l.Z)
			if math.abs(yaw) < 1.9 then''',
'''	local talkLock = model:GetAttribute("LocalTalk")
	if myHead and not frozen then
		local to = (talkLock and camPos or myHead.Position) - (root.Position + V3(0, 1.6, 0))
		local dd = to.Magnitude
		local talking = st.sayAt and now - st.sayAt < 4
		if talkLock or dd < 6 or (talking and dd < 16) or (dd < 11 and now < st.gFocusUntil) then
			local l = root.CFrame:VectorToObjectSpace(to)
			local yaw = atan2(-l.X, -l.Z)
			if talkLock or math.abs(yaw) < 1.9 then''')
# the face, after the head
rep('''	-- a motion that keys the head owns it
	local headBusy''',
'''	if dist < 60 then updateFace(st, model, now) end
	-- a motion that keys the head owns it
	local headBusy''')
# the face driver, before step()
rep('''local function step(st, now, dt, camPos, myHead)''',
'''---------------------------------------------------------------- faces (round 15)
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
	f = { upper = up, mouth = mo, extra = ch:FindFirstChild("FaceExtra"), blinkAt = now + rng:NextNumber(0.5, 4), blinkUntil = 0, lipAt = 0, tick = 0 }
	st.faceRef = f
	return f
end
function updateFace(st, model, now)
	local f = faceOf(st, model, now)
	if not f then return end
	local U = Faces.U[model:GetAttribute("FaceStyle") or "a"] or Faces.U.a
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
	if upper ~= f.u then f.u = upper f.upper.Texture = Faces.id(U[upper] or U.neutral) end
	if mouth ~= f.m then f.m = mouth f.mouth.Texture = Faces.id(Faces.M[mouth] or Faces.M.smile) end
	if f.extra and (blush and true or false) ~= f.b then
		f.b = blush and true or false
		f.extra.Texture = blush and Faces.id(Faces.BLUSH) or (model:GetAttribute("FaceFreckles") and Faces.id(Faces.FRECKLES) or "")
	end
end

local function step(st, now, dt, camPos, myHead)''')
# forward declare updateFace near the top (it's a global otherwise)
rep('local rigs = {}\nlocal rng = Random.new()\n', 'local rigs = {}\nlocal rng = Random.new()\nlocal updateFace -- forward (faces, round 15)\n')
s = s.replace("\nfunction updateFace(st, model, now)", "\nupdateFace = function(st, model, now)")
open(p, "w", encoding="utf8").write(s)
print("ok")
