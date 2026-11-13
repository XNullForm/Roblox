-- StarterPlayerScripts.Minigames: the cleaning minigames (round 10b remake) and the front desk (round 10c).
-- The server opens one with Notify "minigame" when a clean or desk prompt is pressed; this script plays it and
-- reports through CleanDone(cancel, stars) (the server checks the timing itself, so finishing here is the only way to score).
--   Floor   : bin the litter (flick to throw), vacuum the dust, straighten the rug
--   Bed     : strip the dirty sheet, bag it, throw a fresh sheet on the beat, fluff the pillows, duvet, mint
--   Shower  : scrub the mildew, rinse the suds with the hand shower, squeegee the steamy glass
--   Toilet  : lift the lid, scrub the bowl, plunge on the beat, flush, hang a fresh roll
--   CheckIn : match the booking (name and nights), pick the room's key card, swipe it, hand it over
--   CheckOut: take the cash, count exact change from the drawer, tear off the receipt
--   Cook    : pick the order's ingredients, chop on the lines, keep the heat in the green (flip or stir), plate, bell
--   Repair  : fuse box (screws, blown fuse, wires, power) or a leaking pipe (valve, nut, washer, pressure)
-- Round 40: every game was remade as a run of stages (STEP n OF N); the old flat 2D versions are gone.
-- Input is read straight from UserInputService and hit-tested here (a full-screen modal button swallows the
-- clicks), so it works with the mouse locked, in first person, on touch, and at any UI scale.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")

local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local Q = require(Shared:WaitForChild("Quests"))
local Remotes = Shared:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify")
local CleanDone = Remotes:WaitForChild("CleanDone")
local WorkPose = Remotes:WaitForChild("WorkPose", 5) -- round 40: everyone sees your character doing the job
local T = UI.T

local IMG = {
	bottle = "rbxassetid://86193432458015", can = "rbxassetid://103766569087226", paper = "rbxassetid://99334777377053",
	banana = "rbxassetid://114278023450014", wrapper = "rbxassetid://95830604219034", apple = "rbxassetid://101209520957711",
	binr = "rbxassetid://133323185713109", bint = "rbxassetid://111101338078251",
	sponge = "rbxassetid://100451274874623", brush = "rbxassetid://74723486809343", grime = "rbxassetid://134455059084339",
	pillow = "rbxassetid://139851756990269", mint = "rbxassetid://105903608003606", showerhead = "rbxassetid://107059385822602",
	toilet = "rbxassetid://86957984630585", bubble = "rbxassetid://114091398845640",
}

local INFO = {
	Floor = { title = "Tidy the Floor", icon = "clean", par = 24 },
	Bed = { title = "Make the Bed", icon = "bed", par = 30 },
	Shower = { title = "Scrub the Shower", icon = "shower", par = 26 },
	Toilet = { title = "Clean the Toilet", icon = "toilet", par = 26 },
	CheckIn = { title = "Check In", icon = "bell", par = 16, words = { "Done!", "Great service!", "Perfect check-in!" } },
	CheckOut = { title = "Check Out", icon = "cash", par = 14, words = { "Done!", "Great service!", "Perfect change!" } },
	Cook = { title = "Cook", icon = "food", par = 30, words = { "Served!", "Tasty!", "Chef's kiss!" } },
	Repair = { title = "Repair", icon = "wrench", par = 26, words = { "Fixed!", "Good as new!", "Expert repair!" } },
}

local W, H = 620, 340 -- the play area's design size; everything inside is laid out in these units

local rng = Random.new()
local S -- the open session

local function sound(name) UI.sound(name) end

---------------------------------------------------------------- the session

local function closeGame(cancel)
	local s = S
	if not s then return end
	S = nil
	if WorkPose then WorkPose:FireServer(nil) end
	CAS:UnbindAction("MinigamePad")
	for _, c in ipairs(s.conns) do c:Disconnect() end
	UIS.MouseIconEnabled = true
	UI.blur(false)
	if cancel then CleanDone:FireServer(true) end
	if s.gui then
		if s.hud then UI.tween(s.hud, 0.18, { Position = UDim2.fromOffset(0, -60) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
		if s.areaScale then UI.tween(s.areaScale, 0.2, { Scale = s.areaScale.Scale * 0.95 }) end
		for _, d in ipairs(s.gui:GetDescendants()) do
			if d:IsA("ViewportFrame") then UI.tween(d, 0.2, { ImageTransparency = 1, BackgroundTransparency = 1 }) end
		end
		UI.tween(s.dim, 0.24, { BackgroundTransparency = 1 })
		task.delay(0.24, function() s.gui:Destroy() end)
	end
end

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	for k, v in pairs(props) do o[k] = v end
	return o
end

-- an image in the play area, centred on pos (design units)
local function img(name, size, pos, props)
	local i = new("ImageLabel", {
		Image = IMG[name] or name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y), Position = UDim2.fromOffset(pos.X, pos.Y), ZIndex = 5,
		ScaleType = Enum.ScaleType.Fit,
	})
	for k, v in pairs(props or {}) do i[k] = v end
	i.Parent = props and props.Parent or S.area
	return i
end

local function setPos(o, p) o.Position = UDim2.fromOffset(p.X, p.Y) end

-- pointer in play-area units
local function toLocal(screen)
	local a = S.area
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	return Vector2.new((screen.X - ap.X) * W / math.max(as.X, 1), (screen.Y - ap.Y) * H / math.max(as.Y, 1))
end

local function inArea(p) return p.X >= 0 and p.Y >= 0 and p.X <= W and p.Y <= H end

-- a few bright flecks fly out from pos
local function burst(pos, color, n, spread)
	for _ = 1, n or 8 do
		local sz = rng:NextNumber(5, 10)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(sz, sz), Position = UDim2.fromOffset(pos.X, pos.Y),
			BackgroundColor3 = color or T.gold, ZIndex = 30, Rotation = rng:NextNumber(0, 90), Parent = S.area,
		})
		UI.corner(f, 3)
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(30, spread or 80)
		local to = pos + Vector2.new(math.cos(a), math.sin(a)) * d
		UI.tween(f, 0.5, { Position = UDim2.fromOffset(to.X, to.Y), Rotation = f.Rotation + 180, BackgroundTransparency = 1, Size = UDim2.fromOffset(2, 2) })
		task.delay(0.55, function() f:Destroy() end)
	end
end

local function floatText(pos, text, color)
	local l = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(200, 34), Position = UDim2.fromOffset(pos.X, pos.Y),
		BackgroundTransparency = 1, Text = text, TextSize = 26, FontFace = UI.F.black, TextColor3 = color or T.cream, ZIndex = 40, Parent = S.area,
	})
	UI.textStroke(l, 2.5, 0.1)
	UI.pop(l, 0.5, 0.3)
	UI.tween(l, 0.9, { Position = UDim2.fromOffset(pos.X, pos.Y - 46), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.35)
	task.delay(1.3, function() l:Destroy() end)
end

-- soap bubbles that drift up and pop
local function bubbles(pos, n)
	for _ = 1, n or 2 do
		local sz = rng:NextNumber(14, 30)
		local p = pos + Vector2.new(rng:NextNumber(-18, 18), rng:NextNumber(-10, 10))
		local b = img("bubble", Vector2.new(sz, sz), p, { ZIndex = 25, ImageTransparency = 0.1 })
		local to = p + Vector2.new(rng:NextNumber(-20, 20), -rng:NextNumber(30, 70))
		UI.tween(b, rng:NextNumber(0.7, 1.2), { Position = UDim2.fromOffset(to.X, to.Y), ImageTransparency = 1, Size = UDim2.fromOffset(sz * 1.3, sz * 1.3) }, Enum.EasingStyle.Sine)
		task.delay(1.3, function() b:Destroy() end)
	end
end

local function shake(o)
	local base = o.Position
	for i = 1, 6 do
		task.delay(i * 0.035, function()
			if o.Parent then o.Position = base + UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (7 - i), 0) end
		end)
	end
	task.delay(0.26, function() if o.Parent then o.Position = base end end)
end

local function pulse(o, k)
	local s = UI.scaleOf(o)
	s.Scale = k or 1.18
	UI.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function setProgress(k)
	S.progress = k
	UI.tween(S.fill, 0.25, { Size = UDim2.fromScale(math.clamp(k, 0, 1), 1) })
end

local function say(text)
	S.hint.Text = text
	UI.pop(S.hint, 0.9, 0.25)
end

-- the tool that follows the pointer (sponge, brush); the OS cursor hides over the play area
local function useTool(name, size, offset)
	S.tool = img(name, Vector2.new(size, size), Vector2.new(W / 2, H / 2), { ZIndex = 50, Visible = false })
	S.toolOffset = offset or Vector2.zero
end

-- the result: stars for speed, a burst of sparkle, then report the win
local function win()
	if S.won then return end
	S.won = true
	setProgress(1)
	local took = os.clock() - S.t0
	local par = C.MINIGAME_PAR and C.MINIGAME_PAR[S.kind] or INFO[S.kind].par
	local stars = took <= par and 3 or took <= par * 1.6 and 2 or 1
	-- slips cap it: one mistake is two stars at best, two or more is one
	local m = S.mistakes or 0
	if m > 0 then stars = math.min(stars, m >= 2 and 1 or 2) end
	local info = INFO[S.kind]
	sound("sparkle")
	sound("jingle")
	-- round 39: the extras line: a best time, the hot streak (three stars in a row), a grabbed bonus coin
	local extras = {}
	if not S.best or took < S.best - 0.05 then
		table.insert(extras, string.format("NEW BEST %.1fs", took))
	else
		table.insert(extras, string.format("BEST %.1fs", S.best))
	end
	local streak = stars >= 3 and (Players.LocalPlayer:GetAttribute("MGStreak") or 0) + 1 or 0
	if streak >= 2 then table.insert(extras, "HOT STREAK x" .. streak .. " +$" .. math.min(streak, Q.MG.cap) * Q.MG.streak) end
	if S.bonus then table.insert(extras, "BONUS COIN") end
	if S.found then table.insert(extras, "RETURNED A " .. string.upper(S.found)) end
	if S.shooed then table.insert(extras, "BUG SHOOED") end
	-- the play area dims behind the result
	local veil = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.shadow, BackgroundTransparency = 1, ZIndex = 59, Parent = S.area })
	UI.tween(veil, 0.3, { BackgroundTransparency = 0.4 })
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, H / 2), Size = UDim2.fromOffset(360, 184),
		BackgroundColor3 = T.ink, BackgroundTransparency = 0, ZIndex = 60, Parent = S.area,
	})
	local ex = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 140), BackgroundTransparency = 1, ZIndex = 61,
		Text = table.concat(extras, "  ·  "), TextSize = 16, FontFace = UI.F.black, TextScaled = false, TextWrapped = true,
		TextColor3 = extras[1]:sub(1, 3) == "NEW" and T.green or T.muted, Parent = card,
	})
	if #extras > 1 then ex.TextColor3 = T.gold end
	UI.corner(card, 18)
	UI.stroke(card, 2, T.gold, 0.1)
	local t = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 14), BackgroundTransparency = 1, ZIndex = 61,
		Text = info.words and info.words[stars] or (stars == 3 and "Spotless!" or stars == 2 and "Sparkling!" or "All clean!"), TextSize = 36, FontFace = UI.F.black, TextColor3 = T.gold, Parent = card,
	})
	UI.textStroke(t, 2, 0.2)
	for i = 1, 3 do
		local st = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 2) * 58, 0, 96), Size = UDim2.fromOffset(50, 50),
			BackgroundTransparency = 1, Image = i <= stars and C.ICONS.star or C.ICONS.starEmpty, ZIndex = 62, Parent = card,
		})
		local sc = UI.scaleOf(st)
		sc.Scale = 0
		UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.15 + i * 0.14)
		if i <= stars then task.delay(0.2 + i * 0.14, function() if S then sound("tick") end end) end
	end
	UI.pop(card, 0.6, 0.4)
	for k = 1, 4 do
		task.delay(k * 0.12, function()
			if S then burst(Vector2.new(rng:NextNumber(80, W - 80), rng:NextNumber(60, H - 60)), k % 2 == 0 and T.gold or T.green, 10, 110) end
		end)
	end
	task.delay(1.35, function()
		if S and S.won then
			CleanDone:FireServer(nil, stars, { kind = S.kind, secs = took, bonus = S.bonus or nil })
			closeGame(false)
		end
	end)
end

---------------------------------------------------------------- small helpers

local LEFT = Enum.TextXAlignment.Left
local WOOD = Color3.fromRGB(150, 98, 60)
local PAPER = Color3.fromRGB(252, 246, 232)
local INK_TEXT = Color3.fromRGB(47, 49, 52)

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function box(props)
	local f = new("Frame", props)
	f.Parent = props.Parent or S.area
	return f
end

local function text(parent, str, size, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = str, TextSize = size, FontFace = UI.F.bold, TextColor3 = T.cream,
		Size = UDim2.new(1, 0, 0, size + 6), ZIndex = (parent.ZIndex or 1) + 1,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	l.Parent = parent
	return l
end

local function hitRect(p, pos, size) -- pos = centre, design units
	return math.abs(p.X - pos.X) <= size.X / 2 and math.abs(p.Y - pos.Y) <= size.Y / 2
end

-- a wrong pick: costs a second, shakes the thing, says why
local function miss(obj, at, why)
	S.mistakes = (S.mistakes or 0) + 1
	S.t0 -= 1
	shake(obj)
	floatText(at, why or "Not that one!", T.red)
	sound("error")
end

---------------------------------------------------------------- 3D minigames (round 11)
-- Every minigame is a small 3D scene now: a ViewportFrame over the play area with a WorldModel (raycasts work
-- in it) and its own camera. ray(p) turns a pointer (design units) into a world ray, pick(p, list) raycasts the
-- listed parts, onPlane(p, at, normal) meets a plane, toArea(pos) projects a world point back to design units,
-- so the 2D effects (burst, floatText, bubbles) and labels sit over the 3D things. ViewportFrames draw no
-- particles, beams or shadows: sparkle, steam and bubbles stay 2D, and props get soft blob shadows.
-- The old flat versions are in archive/Minigames_20261105b.lua.
local G3 = {}
do
	local TS = game:GetService("TweenService")
	local ITEMS = Shared:WaitForChild("Items")
	local V -- the open scene
	local UP = Vector3.yAxis
	local SMOOTH = Enum.Material.SmoothPlastic
	local METAL = Enum.Material.Metal
	local FABRIC = Enum.Material.Fabric
	local WOODM = Enum.Material.Wood
	local CHROME = Color3.fromRGB(214, 220, 228)
	local BRASS = Color3.fromRGB(226, 186, 96)
	local PORCELAIN = Color3.fromRGB(246, 248, 250)

	local function scene(o)
		local vp = new("ViewportFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = o.bg or Color3.fromRGB(34, 37, 40),
			Ambient = o.ambient or Color3.fromRGB(150, 144, 150), LightColor = o.light or Color3.fromRGB(255, 238, 214),
			LightDirection = o.dir or Vector3.new(-0.45, -1, -0.7), ZIndex = 2, Parent = S.area,
		})
		local wm = Instance.new("WorldModel")
		wm.Parent = vp
		local cam = Instance.new("Camera")
		cam.FieldOfView = o.fov or 40
		cam.CFrame = o.cam
		cam.Parent = vp
		vp.CurrentCamera = cam
		-- soft dark edges, top and bottom
		for _, top in ipairs({ true, false }) do
			local f = new("Frame", { Size = UDim2.new(1, 0, 0, 90), Position = top and UDim2.new() or UDim2.new(0, 0, 1, -90), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 3, Parent = vp })
			local g = Instance.new("UIGradient")
			g.Rotation = top and 90 or -90
			g.Transparency = NumberSequence.new(0.7, 1)
			g.Parent = f
		end
		V = { vp = vp, wm = wm, cam = cam, tanY = math.tan(math.rad(cam.FieldOfView) / 2), armDepth = o.armDepth }
		-- round 12, full screen: the frame spreads past the play area to the screen's edges and the camera widens to
		-- match, so ray / toArea (which work in play-area units) stay exact
		local baseTan = V.tanY
		local function fit()
			local sc = S and S.areaScale
			if not sc or not vp.Parent then return end
			local k = math.max(sc.Scale, 0.01)
			local v = workspace.CurrentCamera.ViewportSize
			local sw, sh = v.X / k, v.Y / k
			vp.Position = UDim2.fromOffset((W - sw) / 2, (H - sh) / 2)
			vp.Size = UDim2.fromOffset(sw, sh)
			cam.FieldOfView = math.clamp(math.deg(math.atan(baseTan * sh / H)) * 2, 1, 120)
		end
		fit()
		-- round 40: the arm, remade. A rolled uniform sleeve, a slim forearm in your skin tone and a rounded yellow
		-- rubber glove (palm, four curled fingers, a thumb, a cuff). It is drawn at the depth of what it holds and
		-- scaled up to reach a shoulder below the screen, so it never covers the tool it holds; with nothing held
		-- the empty glove follows the pointer at the scene's resting depth.
		local rig, armParts, armLen
		local deco, baseSize = {}, {}
		do
			local char = Players.LocalPlayer.Character
			local skinP = char and (char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm"))
			local skin = skinP and skinP.Color or Color3.fromRGB(234, 184, 146)
			local GLOVE, GLOVE2 = Color3.fromRGB(255, 206, 60), Color3.fromRGB(255, 228, 120)
			local SLEEVE, SHIRT = Color3.fromRGB(128, 40, 50), Color3.fromRGB(250, 244, 230)
			rig = Instance.new("Model")
			rig.Name = "Arm"
			local function mk(size, color, shape)
				local p = Instance.new("Part")
				p.Size = size
				p.Color = color
				p.Material = Enum.Material.SmoothPlastic
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				if shape == "cyl" then
					p.Shape = Enum.PartType.Cylinder
				elseif shape == "bone" then
					p.Transparency = 1
				elseif shape == "ball" then
					p.Shape = Enum.PartType.Ball
				elseif shape == "ell" then
					local m = Instance.new("SpecialMesh")
					m.MeshType = Enum.MeshType.Sphere
					m.Parent = p
				end
				p.Parent = rig
				baseSize[p] = size
				return p
			end
			-- bones: the upper arm, the forearm and the hand (their +Y runs back up the arm)
			local sleeve = mk(Vector3.new(0.6, 3.2, 0.6), SLEEVE, "bone")
			local fore = mk(Vector3.new(0.44, 2.4, 0.44), skin, "bone")
			local hand = mk(Vector3.new(0.6, 0.9, 0.4), GLOVE, "bone")
			hand:SetAttribute("Grip", 0.1)
			armParts = { sleeve, fore, hand }
			for _, p in ipairs(armParts) do p:SetAttribute("BaseLen", p.Size.Y) end
			armLen = 0
			for _, p in ipairs(armParts) do armLen += p.Size.Y end
			local function add(base, p, cf, fromEnd) table.insert(deco, { base = base, p = p, cf = cf, fromEnd = fromEnd }) end
			local ROLL = CFrame.Angles(0, 0, math.pi / 2)
			add(sleeve, mk(Vector3.new(3.2, 0.6, 0.6), SLEEVE, "cyl"), ROLL)
			add(sleeve, mk(Vector3.new(0.3, 0.7, 0.7), SHIRT, "cyl"), CFrame.new(0, 0.15, 0) * ROLL, true)
			add(sleeve, mk(Vector3.new(0.08, 0.72, 0.72), Color3.fromRGB(240, 184, 70), "cyl"), CFrame.new(0, 0.42, 0) * ROLL, true)
			add(fore, mk(Vector3.new(2.4, 0.44, 0.44), skin, "cyl"), ROLL)
			add(fore, mk(Vector3.new(0.5, 0.5, 0.5), skin, "ball"), CFrame.new(0, 1.2, 0))
			-- the glove: a rolled cuff, a rounded palm, knuckles and curled fingers, a thumb
			add(hand, mk(Vector3.new(0.34, 0.56, 0.56), GLOVE2, "cyl"), CFrame.new(0, 0.5, 0) * ROLL)
			add(hand, mk(Vector3.new(0.66, 0.78, 0.42), GLOVE, "ell"), CFrame.new(0, 0.08, 0))
			for k = 0, 3 do
				local x = -0.22 + k * 0.147
				local len = (k == 0 or k == 3) and 0.24 or 0.3
				add(hand, mk(Vector3.new(0.15, 0.15, 0.15), GLOVE, "ball"), CFrame.new(x, -0.3, 0.02))
				add(hand, mk(Vector3.new(0.13, len, 0.14), GLOVE, "ell"), CFrame.new(x, -0.42, -0.08) * CFrame.Angles(math.rad(-40), 0, 0))
				add(hand, mk(Vector3.new(0.12, 0.2, 0.13), GLOVE, "ell"), CFrame.new(x, -0.5, -0.24) * CFrame.Angles(math.rad(-95), 0, 0))
			end
			add(hand, mk(Vector3.new(0.16, 0.38, 0.17), GLOVE, "ell"), CFrame.new(-0.34, -0.1, -0.1) * CFrame.Angles(math.rad(-25), 0, math.rad(32)))
			add(hand, mk(Vector3.new(0.14, 0.14, 0.14), GLOVE, "ball"), CFrame.new(-0.42, -0.28, -0.2))
		end
		local at
		local function place(p, centre, u, side, k)
			-- the part's +Y runs back up the arm; its front faces the camera's side
			local up = -u
			local right = up:Cross(side)
			if right.Magnitude < 1e-3 then right = up:Cross(Vector3.xAxis) end
			p.CFrame = CFrame.fromMatrix(centre, right.Unit, up)
		end
		table.insert(S.conns, RunService.RenderStepped:Connect(function(dt)
			if not S or V == nil or V.vp ~= vp then return end
			fit()
			if not rig then return end
			local h, grip = V.hand, nil
			if typeof(h) == "Instance" and h.Parent then
				local cf = h:IsA("Model") and h:GetPivot() or h.CFrame
				grip = cf:PointToWorldSpace(V.handOff or Vector3.zero)
			elseif typeof(V.handPos) == "Vector3" then
				grip = V.handPos
			end
			if not grip and not V.noArm and not S.won then
				local p = S.pointer or Vector2.new(W / 2, H / 2)
				local x = (p.X / W * 2 - 1) * V.tanY * (W / H)
				local y = (1 - p.Y / H * 2) * V.tanY
				grip = cam.CFrame:PointToWorldSpace(Vector3.new(x, y, -1) * (V.armDepth or 9) * (S.held and 0.94 or 1))
			end
			if not grip then
				rig.Parent = nil
				at = nil
				return
			end
			local c = cam.CFrame
			local rel = c:PointToObjectSpace(grip)
			local gz = math.max(-rel.Z, 0.5)
			local tanVp = math.tan(math.rad(cam.FieldOfView) / 2)
			local aspect = vp.AbsoluteSize.X / math.max(vp.AbsoluteSize.Y, 1)
			local sx, sy = rel.X / (gz * tanVp), rel.Y / (gz * tanVp) -- screen point, in half-heights
			sx = math.clamp(sx, -aspect * 0.95, aspect * 0.95)
			sy = math.clamp(sy, -0.92, 0.9)
			-- the shoulder: below the screen, to the right of the hand
			local ex, ey = math.clamp(sx + 0.9, aspect * 0.3, aspect * 1.1), -1.45
			local dn = math.max(math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2), 0.3)
			local z = gz * 0.97
			local k = (dn * z * tanVp) / armLen -- the scale that makes the arm reach
			local handPt = c:PointToWorldSpace(Vector3.new(sx * z * tanVp, sy * z * tanVp, -z))
			local shoulder = c:PointToWorldSpace(Vector3.new(ex * z * tanVp, ey * z * tanVp, -z))
			if not at then at = handPt end
			at = at:Lerp(handPt, 1 - math.exp(-dt * 26))
			local d = at - shoulder
			if d.Magnitude < 0.2 then return end
			local u = d.Unit
			local side = -c.LookVector
			local p = at
			for i = #armParts, 1, -1 do
				local part = armParts[i]
				local L = part:GetAttribute("BaseLen") * k
				if i == 1 then L = math.max(L, (p - shoulder).Magnitude) end
				local bs = baseSize[part]
				part.Size = Vector3.new(bs.X * k, L, bs.Z * k)
				local back = (i == #armParts) and L * (part:GetAttribute("Grip") or 0) or 0
				local centre = p - u * (L / 2 - back)
				place(part, centre, u, side)
				p = centre - u * L / 2
			end
			for _, dd in ipairs(deco) do
				local bs = baseSize[dd.p]
				local off = CFrame.new(dd.cf.Position * k) * dd.cf.Rotation
				if dd.base == armParts[1] and dd.p.Shape == Enum.PartType.Cylinder and not dd.fromEnd then
					dd.p.Size = Vector3.new(dd.base.Size.Y, bs.Y * k, bs.Z * k) -- the sleeve runs the whole upper arm
				else
					dd.p.Size = bs * k
				end
				if dd.fromEnd then
					dd.p.CFrame = dd.base.CFrame * CFrame.new(0, -dd.base.Size.Y / 2, 0) * off
				else
					dd.p.CFrame = dd.base.CFrame * off
				end
			end
			if rig.Parent ~= wm then rig.Parent = wm end
		end))
		return V
	end

	local function ray(p)
		local x = (p.X / W * 2 - 1) * V.tanY * (W / H)
		local y = (1 - p.Y / H * 2) * V.tanY
		local cf = V.cam.CFrame
		return cf.Position, cf:VectorToWorldSpace(Vector3.new(x, y, -1)).Unit
	end
	local function pick(p, list)
		local o, d = ray(p)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = list
		return V.wm:Raycast(o, d * 400, params)
	end
	local function onPlane(p, at, normal)
		local o, d = ray(p)
		local den = d:Dot(normal)
		if math.abs(den) < 1e-4 then return nil end
		local t = (at - o):Dot(normal) / den
		if t < 0 then return nil end
		return o + d * t
	end
	local function toArea(pos)
		local rel = V.cam.CFrame:PointToObjectSpace(pos)
		local z = math.max(-rel.Z, 0.01)
		return Vector2.new((rel.X / z / (V.tanY * W / H) + 1) / 2 * W, (1 - rel.Y / z / V.tanY) / 2 * H)
	end

	---------------- parts
	local function part(size, cf, color, mat, parent)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CastShadow = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or SMOOTH
		p.Parent = parent or V.wm
		return p
	end
	local function ball(d, cf, color, mat, parent)
		local p = part(Vector3.new(d, d, d), cf, color, mat, parent)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- a cylinder along cf's X axis
	local function cylX(len, d, cf, color, mat, parent)
		local p = part(Vector3.new(len, d, d), cf, color, mat, parent)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- a cylinder standing up (along cf's Y), and one facing the camera (along cf's Z)
	local function cyl(h, d, cf, color, mat, parent) return cylX(h, d, cf * CFrame.Angles(0, 0, math.rad(90)), color, mat, parent) end
	local function cylZ(h, d, cf, color, mat, parent) return cylX(h, d, cf * CFrame.Angles(0, math.rad(90), 0), color, mat, parent) end
	-- an ellipsoid (a block with a sphere mesh)
	local function ell(size, cf, color, mat, parent)
		local p = part(size, cf, color, mat, parent)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p
	end
	local function model(name)
		local m = Instance.new("Model")
		m.Name = name
		m.Parent = V.wm
		return m
	end
	local function done(m) -- the pivot sits at the origin it was built round (no PrimaryPart: that would own the pivot)
		m.WorldPivot = CFrame.new()
		return m
	end
	local function partsOf(m)
		local out = {}
		for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then table.insert(out, p) end end
		return out
	end
	local function item(name, cf, scale)
		local src = ITEMS:FindFirstChild(name)
		if not src then return nil end
		local m = src:Clone()
		if scale then m:ScaleTo(scale) end
		m:PivotTo(cf)
		for _, p in ipairs(partsOf(m)) do p.CanQuery = false end
		m.Parent = V.wm
		return m
	end
	local function shadow(x, z, d, y, parent)
		local s = cyl(0.02, d, CFrame.new(x, (y or 0) + 0.025, z), Color3.new(0, 0, 0), SMOOTH, parent)
		s.Transparency = 0.6
		s.CanQuery = false
		return s
	end
	local function tw(o, t, props, style, dir, delay)
		local x = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
		x:Play()
		return x
	end
	local function tweenPivot(m, cf, t, style, dir)
		local v = Instance.new("CFrameValue")
		v.Value = m:GetPivot()
		v.Changed:Connect(function(c) if m.Parent then m:PivotTo(c) end end)
		local x = TS:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = cf })
		x:Play()
		x.Completed:Connect(function() v:Destroy() end)
		return x
	end
	-- floor and back wall in the hotel's colours
	local function roomSet(o)
		local fl = part(Vector3.new(90, 1, 90), CFrame.new(0, (o.floorY or 0) - 0.5, 0), o.floor or Color3.fromRGB(176, 124, 80), o.floorMat or Enum.Material.WoodPlanks)
		fl.CanQuery = false
		if o.wallZ then
			local wl = part(Vector3.new(90, 50, 1), CFrame.new(0, 20, o.wallZ - 0.5), o.wall or Color3.fromRGB(226, 212, 186), o.wallMat or SMOOTH)
			wl.CanQuery = false
			local base = part(Vector3.new(90, 0.9, 0.3), CFrame.new(0, (o.floorY or 0) + 0.45, o.wallZ + 0.1), Color3.fromRGB(250, 246, 236))
			base.CanQuery = false
		end
	end
	-- a grid of grout lines over a tiled surface (cf = the surface's centre, facing +Z)
	local function grout(cf, w, h, step, color, parent)
		for x = -w / 2 + step, w / 2 - 0.01, step do
			local g = part(Vector3.new(0.05, h, 0.04), cf * CFrame.new(x, 0, 0.01), color)
			g.CanQuery = false
			if parent then g.Parent = parent end
		end
		for y = -h / 2 + step, h / 2 - 0.01, step do
			local g = part(Vector3.new(w, 0.05, 0.04), cf * CFrame.new(0, y, 0.01), color)
			g.CanQuery = false
			if parent then g.Parent = parent end
		end
	end
	-- a label over a 3D spot
	local function tag3(pos, str, col, size, w)
		local a = toArea(pos)
		local l = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(w or 112, (size or 15) + 10),
			BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, Text = str, TextSize = size or 15, FontFace = UI.F.black,
			TextColor3 = col or T.cream, ZIndex = 8, Parent = S.area,
		})
		UI.corner(l, 8)
		UI.stroke(l, 1.5, col or T.gold, 0.5)
		return l
	end
	-- the rectangle a flat 3D panel covers on screen (cf = its centre, facing the camera on +Z)
	local function overArea(cf, w, h)
		local a, b = toArea((cf * CFrame.new(-w / 2, h / 2, 0)).Position), toArea((cf * CFrame.new(w / 2, -h / 2, 0)).Position)
		return a, b - a
	end
	local function distSeg(p, a, b)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		return (p - (a + ab * t)).Magnitude
	end

	---------------------------------------------------------------- round 40: the remade games' kit
	-- Every game is a run of stages (a STEP n OF N ribbon names each one), the arm always reaches for the pointer
	-- (holding the tool when there is one) and held things ride a plane under the pointer.
	local NEON, GLASSM = Enum.Material.Neon, Enum.Material.Glass
	local function every(fn)
		local me = S
		local c = RunService.RenderStepped:Connect(function(dt)
			if S == me then fn(dt) end
		end)
		table.insert(S.conns, c)
		return c
	end
	local function later(t, fn)
		local me = S
		task.delay(t, function()
			if S == me and not me.won then fn() end
		end)
	end
	local function ptr() return S.pointer or Vector2.new(W / 2, H / 2) end
	local function setQuery(m, on)
		for _, p in ipairs(m:IsA("BasePart") and { m } or partsOf(m)) do p.CanQuery = on end
		return m
	end
	local function flatDist(a, b, n)
		local d = a - b
		return (d - n * d:Dot(n)).Magnitude
	end
	-- a slip: costs a second and a star cap, says why over the spot
	local function oops(at3, why)
		S.mistakes = (S.mistakes or 0) + 1
		S.t0 -= 1
		floatText(toArea(at3), why or "Oops!", T.red)
		sound("error")
		if S.hint and S.hint.Parent then shake(S.hint.Parent) end
	end
	-- a near miss that only costs time
	local function nope(at3, why)
		floatText(toArea(at3), why, T.orange)
		sound("knock")
	end
	local function nice(at3, why, col)
		local a = toArea(at3)
		floatText(a, why, col or T.green)
		burst(a, col or T.sun, 10, 70)
	end

	-- the ribbon that names each stage as it starts
	local function ribbon(i, n, name)
		local old = S.area:FindFirstChild("Ribbon")
		if old then old:Destroy() end
		local r = new("Frame", {
			Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 70), Size = UDim2.fromOffset(300, 66),
			BackgroundColor3 = Color3.fromRGB(24, 30, 44), BackgroundTransparency = 0.06, ZIndex = 40, Parent = S.area,
		})
		UI.corner(r, 20)
		UI.grad(r, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 180, 205), 90)
		local st = UI.stroke(r, 2, T.sun, 0)
		st.Thickness = 3
		local step = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 8),
			Text = "STEP " .. i .. " OF " .. n, TextSize = 14, FontFace = UI.F.black, TextColor3 = T.sun, ZIndex = 41, Parent = r,
		})
		local nm = new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 26),
			Text = name, TextSize = 27, FontFace = UI.F.black, TextColor3 = T.white, ZIndex = 41, Parent = r,
		})
		-- one pip per stage, the done ones filled
		for k = 1, n do
			local pip = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (k - (n + 1) / 2) * 16, 1, 0), Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = k < i and T.green or k == i and T.sun or Color3.fromRGB(70, 80, 100), ZIndex = 42, Parent = r,
			})
			UI.corner(pip, 5)
			UI.stroke(pip, 1, Color3.fromRGB(24, 30, 44), 0).Thickness = 2
		end
		local sc = UI.scaleOf(r)
		sc.Scale = 0.3
		UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(1.15, function()
			if not r.Parent then return end
			UI.tween(sc, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			for _, o in ipairs(r:GetDescendants()) do
				if o:IsA("TextLabel") then UI.tween(o, 0.25, { TextTransparency = 1 })
				elseif o:IsA("Frame") then UI.tween(o, 0.25, { BackgroundTransparency = 1 })
				elseif o:IsA("UIStroke") then UI.tween(o, 0.25, { Transparency = 1 }) end
			end
			UI.tween(r, 0.25, { BackgroundTransparency = 1 })
			UI.tween(st, 0.25, { Transparency = 1 })
			task.delay(0.27, function() r:Destroy() end)
		end)
	end

	-- run the stages in order: each gets (next, progress) and sets its own input handlers
	local function stages(list)
		local me = S
		me.hideCursor = true
		-- round 40: maybe a surprise step, somewhere after the first
		local sp = #list >= 2 and G3._surprise and G3._surprise(me.kind)
		if sp then table.insert(list, Players.LocalPlayer:GetAttribute("MGSurprise") and 1 or rng:NextInteger(2, #list), sp) end -- forced (test): first
		-- a small dot marks exactly where the pointer is (the glove follows it in 3D)
		local dot = new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = T.white, ZIndex = 55, Parent = S.area })
		UI.corner(dot, 6)
		UI.stroke(dot, 1, Color3.fromRGB(20, 24, 34), 0).Thickness = 2
		every(function()
			local p = ptr()
			dot.Position = UDim2.fromOffset(p.X, p.Y)
			local k = me.held and 8 or 11
			dot.Size = UDim2.fromOffset(k, k)
			dot.Visible = not me.won and inArea(p) and not UI.gamepad()
		end)
		local i = 0
		local function go()
			if S ~= me or me.won then return end
			i += 1
			me.onDown, me.onMove, me.onUp = nil, nil, nil
			local st = list[i]
			if not st then win() return end
			me.stageNo, me.stageCount, me.stageName = i, #list, st.name
			ribbon(i, #list, st.name)
			say(st.hint)
			local base = (i - 1) / #list
			setProgress(base)
			local finished = false
			local stT0 = os.clock()
			st.run(function()
				if finished or S ~= me then return end
				finished = true
				if st.surprise then me.t0 += os.clock() - stT0 end -- a surprise's time doesn't count against par
				me.onDown, me.onMove, me.onUp = nil, nil, nil
				setProgress(i / #list)
				sound("sparkle")
				task.delay(st.pause or 0.5, go)
			end, function(k)
				if not finished then setProgress(base + math.clamp(k, 0, 1) / #list) end
			end)
		end
		go()
	end

	-- a held thing rides the plane through `at` facing `n`, lifted off it by o.lift; pressing pushes it in.
	-- The arm holds it at o.grip (its own space). Returns the connection: letGo(c) puts it down.
	local function follow(m, at, n, o)
		o = o or {}
		V.hand, V.handOff, V.handPos = m, o.grip or Vector3.zero, nil
		local pos
		return every(function(dt)
			if not m.Parent then return end
			local hit = onPlane(ptr(), at, n)
			if not hit then return end
			local target = hit + n * ((o.lift or 0) - (S.held and (o.press or 0.1) or 0))
			if o.clamp then target = o.clamp(target) end
			pos = pos and pos:Lerp(target, 1 - math.exp(-dt * (o.speed or 22))) or target
			local r = o.rot
			if typeof(r) == "function" then r = r(pos, dt) end
			m:PivotTo(CFrame.new(pos) * (r or CFrame.identity))
		end)
	end
	local function letGo(c)
		if c then c:Disconnect() end
		V.hand = nil
	end

	-- a glowing target disc at pos facing n
	local function marker(pos, d, n)
		n = n or UP
		local r = n:Cross(Vector3.xAxis)
		if r.Magnitude < 0.1 then r = n:Cross(Vector3.zAxis) end
		local cf = CFrame.fromMatrix(pos, n, r.Unit)
		local ring = cylX(0.04, d, cf, T.sun, NEON)
		local inner = cylX(0.05, d * 0.72, cf, Color3.fromRGB(255, 250, 230), NEON)
		ring.CanQuery, inner.CanQuery = false, false
		local t0 = os.clock()
		local c = every(function()
			local k = (math.sin((os.clock() - t0) * 6) + 1) / 2
			ring.Transparency = 0.15 + k * 0.4
			inner.Transparency = 0.7 + k * 0.2
		end)
		return { destroy = function() c:Disconnect() ring:Destroy() inner:Destroy() end }
	end

	-- a throw or hop: m flies to `to` along an arc `h` high over t seconds, tumbling by `spin`
	local function arc(m, to, t, h, onLand, spin)
		local from = m:GetPivot()
		local t0 = os.clock()
		local c
		c = every(function()
			local k = math.min((os.clock() - t0) / t, 1)
			local p = from.Position:Lerp(to.Position, k) + Vector3.new(0, h * 4 * k * (1 - k), 0)
			local s = (spin or 0) * k
			m:PivotTo(CFrame.new(p) * from.Rotation:Lerp(to.Rotation, k) * CFrame.Angles(s, 0, s * 0.5))
			if k >= 1 then
				c:Disconnect()
				if onLand then onLand() end
			end
		end)
	end

	-- drag m along a plane; let go within `radius` of target (or past it, with o.away) to finish(pos)
	local function dragStage(m, at, n, target, radius, o, finish)
		o = o or {}
		local home = m:GetPivot()
		local mk = target and not o.away and not o.noMark and marker(target, o.mark or radius * 1.5, n)
		local conn
		setQuery(m, true)
		S.onDown = function(p)
			-- a press just next to a small thing (a washer, a fuse) still grabs it
			if conn or not (pick(p, partsOf(m)) or (p - toArea(m:GetPivot().Position)).Magnitude < 28) then return end
			sound("select")
			if o.lift0 then o.lift0() end
			conn = follow(m, at, n, o)
		end
		S.onUp = function()
			if not conn then return end
			letGo(conn)
			conn = nil
			local pos = m:GetPivot().Position
			local d = target and flatDist(pos, target, n) or 0
			if (o.away and d > radius) or (not o.away and d <= radius) then
				if mk then mk.destroy() end
				S.onDown, S.onUp = nil, nil
				finish(pos)
			else
				tweenPivot(m, home, 0.35, Enum.EasingStyle.Back)
				if o.wrong then o.wrong(pos) end
			end
		end
	end

	-- a twist: press on/near `at` and circle the pointer round it; turn(k, da) as it goes, finish() after `turns`
	local function twistStage(at, turns, turn, finish, radius)
		local centre = toArea(at)
		local ring, set = UI.ring(S.area, 96, 7, T.sun, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(centre.X, centre.Y), ZIndex = 20 })
		local arrow = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1,
			Text = "↻", TextSize = 40, FontFace = UI.F.black, TextColor3 = T.sun, TextTransparency = 0.25, ZIndex = 21, Parent = ring,
		})
		UI.textStroke(arrow, 2, 0.1)
		local acc, lastA, active = 0, nil, false
		local full = turns * 2 * math.pi
		local spinC = every(function(dt) arrow.Rotation = (arrow.Rotation + dt * 120) % 360 end)
		S.onDown = function(p)
			if (p - centre).Magnitude > (radius or 110) then return end
			active, lastA = true, nil
		end
		S.onMove = function(p)
			if not active or not S.held then return end
			local d = p - centre
			if d.Magnitude < 6 then return end
			local a = math.atan2(d.Y, d.X)
			if lastA then
				local da = a - lastA
				if da > math.pi then da -= 2 * math.pi elseif da < -math.pi then da += 2 * math.pi end
				acc += math.abs(da)
				set(acc / full)
				turn(math.min(acc / full, 1), da)
				if acc >= full then
					active = false
					spinC:Disconnect()
					ring:Destroy()
					S.onDown, S.onMove, S.onUp = nil, nil, nil
					finish()
					return
				end
			end
			lastA = a
		end
		S.onUp = function() active = false end
	end

	-- a timing ring: a ring shrinks onto a fixed circle at pos, over and over. judge() rates the last press:
	-- 2 perfect, 1 good, 0 off. stop() clears it
	local function beatRing(pos, period, size)
		size = size or 66
		local hold = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = T.sun, BackgroundTransparency = 0.7, ZIndex = 20, Parent = S.area,
		})
		UI.corner(hold, size)
		UI.stroke(hold, 4, T.sun, 0).Thickness = 4
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 21, Parent = hold })
		UI.corner(ring, size * 3)
		local s2 = UI.stroke(ring, 3, T.white, 0)
		s2.Thickness = 4
		local t0, d = os.clock(), size * 2.4
		local c = every(function()
			local k = ((os.clock() - t0) % period) / period
			d = size * (2.4 - 1.9 * k)
			ring.Size = UDim2.fromOffset(d, d)
			s2.Color = math.abs(d - size) / size < 0.14 and T.green or T.white
		end)
		return function()
			local e = math.abs(d - size) / size
			return e < 0.14 and 2 or e < 0.3 and 1 or 0
		end, function()
			c:Disconnect()
			hold:Destroy()
		end
	end

	-- a 2D gauge with a green zone: set(v 0..1) moves the needle and says whether it's in the zone
	local function meter(pos, label, lo, hi, horizontal)
		local w, h = horizontal and 210 or 36, horizontal and 36 or 170
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = Color3.fromRGB(24, 30, 44), BackgroundTransparency = 0.05, ZIndex = 20, Parent = S.area,
		})
		UI.corner(f, 12)
		UI.stroke(f, 2, T.white, 0.6).Thickness = 2
		local track = new("Frame", { Position = UDim2.fromOffset(9, 9), Size = UDim2.new(1, -18, 1, -18), BackgroundColor3 = Color3.fromRGB(56, 64, 84), ZIndex = 21, Parent = f })
		UI.corner(track, 6)
		local zone = new("Frame", { BackgroundColor3 = T.green, ZIndex = 22, Parent = track })
		if horizontal then
			zone.Position, zone.Size = UDim2.fromScale(lo, 0), UDim2.fromScale(hi - lo, 1)
		else
			zone.AnchorPoint, zone.Position, zone.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1 - lo), UDim2.fromScale(1, hi - lo)
		end
		UI.corner(zone, 4)
		UI.grad(zone, Color3.fromRGB(150, 255, 190), Color3.fromRGB(40, 190, 110), horizontal and 90 or 0)
		local needle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.white, ZIndex = 23, Parent = track })
		needle.Size = horizontal and UDim2.new(0, 6, 1, 14) or UDim2.new(1, 14, 0, 6)
		UI.corner(needle, 3)
		UI.stroke(needle, 1, Color3.fromRGB(20, 24, 34), 0).Thickness = 2
		local cap = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(110, 16), BackgroundTransparency = 1,
			Text = label, TextSize = 13, FontFace = UI.F.black, TextColor3 = T.white, ZIndex = 21, Parent = f,
		})
		UI.textStroke(cap, 1.5, 0.2)
		return function(v)
			v = math.clamp(v, 0, 1)
			needle.Position = horizontal and UDim2.fromScale(v, 0.5) or UDim2.fromScale(0.5, 1 - v)
			local inZone = v >= lo and v <= hi
			needle.BackgroundColor3 = inZone and T.green or (v > hi and T.red or T.white)
			return inZone
		end, f
	end

	-- a 2D card over the play area (labels, receipts, order tickets)
	local function card2(pos, size, props)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = T.white, ZIndex = 12, Parent = S.area,
		})
		for k, v in pairs(props or {}) do f[k] = v end
		UI.corner(f, 12)
		UI.stroke(f, 2, Color3.fromRGB(24, 30, 44), 0.2).Thickness = 2
		return f
	end

	-- scrubbing: spots lose hp while the tool rubs over them (held); progress(k), finish() when all are gone
	local function scrubber(spots, radius, progress, finish, sfx)
		local last, lastSfx, lastFx = nil, 0, 0
		local cleaned = 0
		return function(at)
			if not at then last = nil return end
			if not last then last = at return end
			local moved = (at - last).Magnitude
			last = at
			if moved < 0.01 or moved > 4 then return end
			for _, s in ipairs(spots) do
				if s.hp > 0 and (s.pos - at).Magnitude < radius + s.r then
					s.hp -= moved
					local k = math.clamp(s.hp / s.max, 0, 1)
					for _, b in ipairs(s.parts) do b[1].Transparency = b[2] + (1 - b[2]) * (1 - k) end
					local now = os.clock()
					if now - lastFx > 0.06 then
						lastFx = now
						bubbles(toArea(s.pos), 1)
						if s.onRub then s.onRub(at) end
					end
					if now - lastSfx > 0.26 then
						lastSfx = now
						sound(sfx or "scrub")
					end
					if s.hp <= 0 then
						cleaned += 1
						for _, b in ipairs(s.parts) do tw(b[1], 0.2, { Transparency = 1 }) end
						nice(s.pos, cleaned == #spots and "Spotless!" or "Clean!", T.green)
						progress(cleaned / #spots)
						if cleaned == #spots then finish() end
					end
				end
			end
		end
	end

	-- a blotchy stain of n blobs round pos on a surface facing n (for scrubbing)
	local function stain(pos, n, r, cols, count)
		local s = { pos = pos, r = r, parts = {}, max = r * 6, hp = r * 6 }
		local right = n:Cross(UP)
		if right.Magnitude < 0.1 then right = n:Cross(Vector3.zAxis) end
		right = right.Unit
		local up = right:Cross(n).Unit
		for k = 1, count or 4 do
			local off = right * rng:NextNumber(-r, r) * 0.6 + up * rng:NextNumber(-r, r) * 0.6
			local d = rng:NextNumber(r * 0.6, r * 1.2)
			local cf = CFrame.fromMatrix(pos + off + n * (0.01 * k), right, up) * CFrame.Angles(0, 0, rng:NextNumber(0, 3))
			local b = ell(Vector3.new(d, d * rng:NextNumber(0.6, 1), 0.06), cf, cols[rng:NextInteger(1, #cols)], SMOOTH)
			b.CanQuery = false
			local tr = rng:NextNumber(0.05, 0.3)
			b.Transparency = tr
			table.insert(s.parts, { b, tr })
		end
		return s
	end

	-- the guest across the desk: a still copy of their body (or a stand-in), swaying; hop() when served
	local function deskGuest(name, x, z)
		local hopAt
		local src
		for _, plot in ipairs(workspace:FindFirstChild("Plots") and workspace.Plots:GetChildren() or {}) do
			local gs = plot:FindFirstChild("Guests")
			for _, m in ipairs(gs and gs:GetChildren() or {}) do
				if not src and m:IsA("Model") and not m:GetAttribute("Staff") and (m:GetAttribute("BName") == name or m.Name == name) then src = m end
			end
		end
		local copy, off, home
		if src then
			local was = src.Archivable
			src.Archivable = true
			local ok, c = pcall(function() return src:Clone() end)
			src.Archivable = was
			if ok and c then
				for _, x2 in ipairs(c:GetDescendants()) do
					if x2:IsA("LuaSourceContainer") or x2:IsA("BillboardGui") or x2:IsA("ProximityPrompt") or x2:IsA("Sound") or x2:IsA("ParticleEmitter") then x2:Destroy()
					elseif x2:IsA("BasePart") then x2.Anchored, x2.CanCollide, x2.CanQuery = true, false, false end
				end
				local hum = c:FindFirstChildOfClass("Humanoid")
				if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
				local root = c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart
				local rootY = -2.5 + (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
				home = CFrame.lookAt(Vector3.new(x, rootY, z), Vector3.new(x, rootY, 10))
				off = root and root.CFrame:ToObjectSpace(c:GetPivot()) or CFrame.identity
				copy = c
			end
		end
		if not copy then
			-- a stand-in: a smart guest in a coloured shirt
			copy = model("Guest")
			local shirt = Color3.fromHSV(rng:NextNumber(), 0.55, 0.85)
			local skin = Color3.fromRGB(234, 184, 146)
			part(Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt, SMOOTH, copy)
			part(Vector3.new(0.9, 2, 1), CFrame.new(-0.5, 1, 0), Color3.fromRGB(50, 56, 80), SMOOTH, copy)
			part(Vector3.new(0.9, 2, 1), CFrame.new(0.5, 1, 0), Color3.fromRGB(50, 56, 80), SMOOTH, copy)
			part(Vector3.new(0.8, 2, 0.9), CFrame.new(-1.45, 3, 0), shirt, SMOOTH, copy)
			part(Vector3.new(0.8, 2, 0.9), CFrame.new(1.45, 3, 0), shirt, SMOOTH, copy)
			ball(1.5, CFrame.new(0, 4.75, 0), skin, SMOOTH, copy)
			ball(0.2, CFrame.new(-0.3, 4.9, 0.66), Color3.fromRGB(30, 30, 30), SMOOTH, copy)
			ball(0.2, CFrame.new(0.3, 4.9, 0.66), Color3.fromRGB(30, 30, 30), SMOOTH, copy)
			done(copy)
			setQuery(copy, false)
			home = CFrame.lookAt(Vector3.new(x, -2.5, z), Vector3.new(x, -2.5, 10))
			off = CFrame.identity
		end
		copy:PivotTo(home * off)
		copy.Parent = V.wm
		local t0 = os.clock()
		every(function()
			if not copy.Parent then return end
			local t = os.clock() - t0
			local hop = hopAt and math.max(0, math.sin(math.min((os.clock() - hopAt) * 9, math.pi * 3))) * 0.9 or 0
			copy:PivotTo(home * CFrame.new(math.sin(t * 1.3) * 0.12, math.abs(math.sin(t * 2.6)) * 0.05 + hop, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.12, math.sin(t * 1.3) * 0.025) * off)
		end)
		return {
			hop = function() hopAt = os.clock() end,
			head = home.Position + Vector3.new(0, 3.2, 0),
		}
	end

	-- a speech bubble over a 3D point
	local function speech(at3, str)
		local a = toArea(at3)
		local b = card2(a, Vector2.new(math.max(120, #str * 10 + 30), 40), { ZIndex = 14 })
		local l = text(b, str, 18, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(24, 30, 44), Size = UDim2.fromScale(1, 1), ZIndex = 15 })
		l.TextXAlignment = Enum.TextXAlignment.Center
		UI.pop(b, 0.5, 0.3)
		return b
	end

	local function deskSet(camCF)
		scene({ cam = camCF, fov = 40, bg = Color3.fromRGB(56, 46, 40), ambient = Color3.fromRGB(150, 140, 136), armDepth = 8 })
		roomSet({ wallZ = -7.5, wall = Color3.fromRGB(70, 92, 84), floorY = -4 })
		local top = part(Vector3.new(44, 1.2, 10), CFrame.new(0, -0.6, -1.4), Color3.fromRGB(122, 78, 48), WOODM)
		top.CanQuery = false
		part(Vector3.new(44, 0.22, 0.22), CFrame.new(0, -0.06, 3.6), BRASS, METAL).CanQuery = false
		-- a leather blotter, wainscot panels, sconces and a plant
		part(Vector3.new(7, 0.06, 3.6), CFrame.new(0.4, 0.03, 0.6), Color3.fromRGB(46, 70, 60), FABRIC).CanQuery = false
		for i = -3, 3 do
			part(Vector3.new(4.2, 3.2, 0.15), CFrame.new(i * 5, 2.4, -7.42), Color3.fromRGB(58, 78, 70)).CanQuery = false
			part(Vector3.new(3.6, 2.6, 0.1), CFrame.new(i * 5, 2.4, -7.33), Color3.fromRGB(64, 86, 77)).CanQuery = false
		end
		for _, x in ipairs({ -7.5, 7.5 }) do
			cylZ(0.3, 0.6, CFrame.new(x, 6.2, -7.3), BRASS, METAL).CanQuery = false
			ball(0.7, CFrame.new(x, 6.6, -7.0), Color3.fromRGB(255, 236, 190), NEON).CanQuery = false
		end
		item("Plant", CFrame.new(-9.5, 0, -4.5), 0.7)
		local bell = model("Bell")
		cyl(0.18, 1.2, CFrame.new(0, 0.09, 0), Color3.fromRGB(60, 40, 30), WOODM, bell)
		ell(Vector3.new(0.95, 0.8, 0.95), CFrame.new(0, 0.3, 0), BRASS, METAL, bell)
		ball(0.2, CFrame.new(0, 0.75, 0), BRASS, METAL, bell)
		done(bell)
		setQuery(bell, false)
		return bell
	end

	---------------------------------------------------------------- Cook: prep, chop, cook, serve
	local RAW3 = {
		bun = Color3.fromRGB(222, 160, 84), patty = Color3.fromRGB(196, 96, 96), cheese = Color3.fromRGB(250, 200, 60),
		egg = Color3.fromRGB(250, 246, 236), pepper = Color3.fromRGB(220, 50, 40), flour = Color3.fromRGB(240, 232, 214),
		berries = Color3.fromRGB(40, 84, 130), steak = Color3.fromRGB(176, 66, 60), carrot = Color3.fromRGB(240, 132, 40),
		broccoli = Color3.fromRGB(70, 146, 64), pasta = Color3.fromRGB(250, 214, 96), tomato = Color3.fromRGB(222, 52, 40), basil = Color3.fromRGB(64, 156, 64),
	}
	local function ingredient(id)
		local m = model(id)
		local c = RAW3[id] or Color3.fromRGB(200, 200, 200)
		if id == "bun" then
			ell(Vector3.new(1.2, 0.65, 1.2), CFrame.new(0, 0.33, 0), c, SMOOTH, m)
			for i = 1, 6 do ell(Vector3.new(0.12, 0.05, 0.07), CFrame.new(math.cos(i) * 0.3, 0.62, math.sin(i) * 0.3) * CFrame.Angles(0, i, 0), Color3.fromRGB(250, 240, 210), SMOOTH, m) end
		elseif id == "patty" then
			cyl(0.32, 1.15, CFrame.new(0, 0.16, 0), c, SMOOTH, m)
		elseif id == "cheese" then
			part(Vector3.new(1.0, 0.1, 1.0), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0.4, 0), c, SMOOTH, m)
			part(Vector3.new(1.0, 0.1, 1.0), CFrame.new(0.05, 0.15, 0.05) * CFrame.Angles(0, 0.2, 0), c:Lerp(Color3.new(1, 1, 1), 0.1), SMOOTH, m)
		elseif id == "egg" then
			ell(Vector3.new(0.62, 0.82, 0.62), CFrame.new(0, 0.41, 0), c, SMOOTH, m)
		elseif id == "pepper" then
			ell(Vector3.new(0.8, 0.95, 0.8), CFrame.new(0, 0.48, 0), c, SMOOTH, m)
			cyl(0.25, 0.12, CFrame.new(0, 1.0, 0), Color3.fromRGB(60, 130, 50), SMOOTH, m)
		elseif id == "flour" then
			part(Vector3.new(0.9, 1.15, 0.6), CFrame.new(0, 0.58, 0), c, FABRIC, m)
			part(Vector3.new(0.92, 0.35, 0.62), CFrame.new(0, 0.6, 0), Color3.fromRGB(70, 110, 190), FABRIC, m)
			ell(Vector3.new(0.9, 0.3, 0.6), CFrame.new(0, 1.18, 0), c, FABRIC, m)
		elseif id == "berries" then
			for i = 1, 6 do ball(0.38, CFrame.new(math.cos(i * 1.1) * 0.28, 0.2 + (i > 4 and 0.25 or 0), math.sin(i * 1.1) * 0.28), c:Lerp(Color3.fromRGB(20, 54, 90), (i % 3) * 0.2), SMOOTH, m) end
		elseif id == "steak" then
			ell(Vector3.new(1.3, 0.34, 0.95), CFrame.new(0, 0.17, 0), c, SMOOTH, m)
			ell(Vector3.new(0.4, 0.3, 0.9), CFrame.new(0.55, 0.16, 0), Color3.fromRGB(240, 220, 210), SMOOTH, m)
		elseif id == "carrot" then
			ell(Vector3.new(0.38, 0.38, 1.4), CFrame.new(0, 0.2, 0), c, SMOOTH, m)
			for i = -1, 1 do ell(Vector3.new(0.1, 0.12, 0.5), CFrame.new(0.1 * i, 0.26, -0.85) * CFrame.Angles(0, 0.4 * i, 0), Color3.fromRGB(70, 150, 60), SMOOTH, m) end
		elseif id == "broccoli" then
			cyl(0.6, 0.28, CFrame.new(0, 0.3, 0), Color3.fromRGB(150, 200, 110), SMOOTH, m)
			for i = 0, 3 do ball(0.5, CFrame.new(math.cos(i * 1.57) * 0.22, 0.75 + (i % 2) * 0.08, math.sin(i * 1.57) * 0.22), c, SMOOTH, m) end
		elseif id == "pasta" then
			part(Vector3.new(1.0, 0.6, 0.55), CFrame.new(0, 0.3, 0), Color3.fromRGB(40, 90, 170), SMOOTH, m)
			part(Vector3.new(0.6, 0.35, 0.56), CFrame.new(0, 0.3, 0), c, SMOOTH, m)
		elseif id == "tomato" then
			ball(0.85, CFrame.new(0, 0.42, 0), c, SMOOTH, m)
			ell(Vector3.new(0.4, 0.08, 0.4), CFrame.new(0, 0.86, 0), Color3.fromRGB(70, 140, 60), SMOOTH, m)
		else -- basil
			for i = -1, 1 do ell(Vector3.new(0.55, 0.06, 0.32), CFrame.new(0.2 * i, 0.06 + math.abs(i) * 0.02, 0) * CFrame.Angles(0, 0.7 * i, 0), c, SMOOTH, m) end
		end
		done(m)
		for _, p in ipairs(partsOf(m)) do p.CanQuery = true end
		return m
	end
	-- the plated dish (the same build as Kitchen's plate), base at the origin, scale ~1.9
	local function dishModel(id)
		local m = model("Meal")
		local k = 1.9
		local function bit(shape, size, cf, color, mat)
			local p = part(size * k, CFrame.new(cf.Position * k) * cf.Rotation, color, mat or SMOOTH, m)
			if shape then p.Shape = shape end
			p.CanQuery = false
			return p
		end
		local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
		local up = CFrame.Angles(0, 0, math.rad(90))
		bit(CYL, Vector3.new(0.08, 1.15, 1.15), CFrame.new(0, 0.04, 0) * up, Color3.fromRGB(250, 250, 246))
		bit(CYL, Vector3.new(0.05, 1.25, 1.25), CFrame.new(0, 0.03, 0) * up, Color3.fromRGB(226, 200, 140), METAL)
		if id == "burger" then
			bit(CYL, Vector3.new(0.16, 0.66, 0.66), CFrame.new(0, 0.17, 0) * up, Color3.fromRGB(222, 160, 84))
			bit(CYL, Vector3.new(0.16, 0.7, 0.7), CFrame.new(0, 0.32, 0) * up, Color3.fromRGB(104, 58, 34))
			bit(nil, Vector3.new(0.62, 0.05, 0.62), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(250, 200, 60))
			bit(CYL, Vector3.new(0.05, 0.72, 0.72), CFrame.new(0, 0.46, 0) * up, Color3.fromRGB(120, 196, 80))
			local top = ell(Vector3.new(0.7, 0.42, 0.7) * k, CFrame.new(0, 0.58 * k, 0), Color3.fromRGB(226, 156, 76), SMOOTH, m)
			top.CanQuery = false
		elseif id == "omelette" then
			ell(Vector3.new(0.9, 0.3, 0.6) * k, CFrame.new(0, 0.18 * k, 0), Color3.fromRGB(250, 214, 90), SMOOTH, m).CanQuery = false
			for i = 1, 3 do bit(BALL, Vector3.new(0.1, 0.1, 0.1), CFrame.new(-0.2 + i * 0.12, 0.33, (i % 2) * 0.1 - 0.05), Color3.fromRGB(80, 150, 60)) end
		elseif id == "pancakes" then
			for i = 0, 2 do bit(CYL, Vector3.new(0.12, 0.82, 0.82), CFrame.new(0, 0.15 + i * 0.12, 0) * up, Color3.fromRGB(226, 170, 96)) end
			bit(nil, Vector3.new(0.2, 0.1, 0.2), CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 236, 160))
			for i = 1, 4 do bit(BALL, Vector3.new(0.13, 0.13, 0.13), CFrame.new(math.cos(i * 1.6) * 0.3, 0.48, math.sin(i * 1.6) * 0.3), Color3.fromRGB(40, 79, 120)) end
		elseif id == "steak" then
			bit(nil, Vector3.new(0.6, 0.18, 0.42), CFrame.new(-0.12, 0.18, 0) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(120, 62, 40))
			for i = 1, 3 do bit(nil, Vector3.new(0.3, 0.07, 0.07), CFrame.new(0.28, 0.14, -0.2 + i * 0.1) * CFrame.Angles(0, 0.2 * i, 0), Color3.fromRGB(240, 132, 40)) end
			for i = 1, 2 do bit(BALL, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.15 + i * 0.1, 0.2, 0.28), Color3.fromRGB(70, 140, 60)) end
		else -- pasta
			ell(Vector3.new(0.8, 0.32, 0.8) * k, CFrame.new(0, 0.18 * k, 0), Color3.fromRGB(240, 210, 130), SMOOTH, m).CanQuery = false
			ell(Vector3.new(0.5, 0.16, 0.5) * k, CFrame.new(0, 0.32 * k, 0), Color3.fromRGB(200, 50, 40), SMOOTH, m).CanQuery = false
			bit(nil, Vector3.new(0.14, 0.03, 0.08), CFrame.new(0.05, 0.41, 0) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(70, 150, 60))
		end
		return done(m)
	end
	local PAN3 = {
		patty = { Color3.fromRGB(214, 122, 122), Color3.fromRGB(130, 72, 44), Color3.fromRGB(40, 28, 24) },
		egg = { Color3.fromRGB(252, 250, 242), Color3.fromRGB(250, 234, 190), Color3.fromRGB(150, 110, 70) },
		batter = { Color3.fromRGB(250, 238, 206), Color3.fromRGB(226, 164, 88), Color3.fromRGB(72, 46, 30) },
		steak = { Color3.fromRGB(208, 86, 86), Color3.fromRGB(142, 72, 48), Color3.fromRGB(42, 28, 22) },
		sauce = { Color3.fromRGB(238, 118, 96), Color3.fromRGB(198, 48, 36), Color3.fromRGB(82, 26, 20) },
	}

	---------------------------------------------------------------- Floor: bin the litter, vacuum the dust, straighten the rug
	local LITTER3 = { bottle = "r", can = "r", paper = "r", banana = "t", wrapper = "t", apple = "t" }

	local function litter(kind)
		local m = model(kind)
		if kind == "bottle" then
			local g = Color3.fromRGB(96, 182, 132)
			cylX(1.5, 0.6, CFrame.new(0, 0.3, 0), g, GLASSM, m).Transparency = 0.15
			cylX(0.62, 0.63, CFrame.new(-0.1, 0.3, 0), Color3.fromRGB(244, 236, 214), SMOOTH, m)
			cylX(0.2, 0.64, CFrame.new(-0.1, 0.3, 0), Color3.fromRGB(220, 60, 60), SMOOTH, m)
			cylX(0.5, 0.3, CFrame.new(0.95, 0.3, 0), g, GLASSM, m).Transparency = 0.15
			cylX(0.14, 0.34, CFrame.new(1.25, 0.3, 0), Color3.fromRGB(60, 110, 220), SMOOTH, m)
		elseif kind == "can" then
			cylX(1.05, 0.64, CFrame.new(0, 0.32, 0), Color3.fromRGB(210, 40, 48), METAL, m)
			for i = -1, 1, 2 do cylX(0.07, 0.6, CFrame.new(0.53 * i, 0.32, 0), CHROME, METAL, m) end
			cylX(0.3, 0.65, CFrame.new(0, 0.32, 0), Color3.fromRGB(250, 250, 250), SMOOTH, m)
			-- squashed in the middle
			ell(Vector3.new(0.35, 0.2, 0.7), CFrame.new(0.25, 0.62, 0), Color3.fromRGB(180, 30, 40), METAL, m)
		elseif kind == "paper" then
			local c = Color3.fromRGB(246, 242, 230)
			ball(0.95, CFrame.new(0, 0.46, 0), c, FABRIC, m)
			ball(0.55, CFrame.new(0.32, 0.55, 0.15), c, FABRIC, m)
			ball(0.5, CFrame.new(-0.26, 0.6, -0.2), Color3.fromRGB(232, 228, 214), FABRIC, m)
			ball(0.42, CFrame.new(0.05, 0.75, 0.3), c, FABRIC, m)
			part(Vector3.new(0.5, 0.04, 0.12), CFrame.new(0.1, 0.92, 0) * CFrame.Angles(0, 0.4, 0.3), Color3.fromRGB(80, 120, 200), SMOOTH, m)
		elseif kind == "banana" then
			local y = Color3.fromRGB(246, 206, 64)
			ell(Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 0.2, 0), y, SMOOTH, m)
			for i = 0, 2 do
				ell(Vector3.new(0.36, 0.14, 1.2), CFrame.Angles(0, i * 2.09 + 0.3, 0) * CFrame.new(0, 0.1, 0.55) * CFrame.Angles(-0.12, 0, 0), y, SMOOTH, m)
				ball(0.12, CFrame.Angles(0, i * 2.09 + 0.3, 0) * CFrame.new(0.05, 0.16, 0.7), Color3.fromRGB(120, 84, 40), SMOOTH, m)
			end
			ball(0.18, CFrame.new(0, 0.42, 0), Color3.fromRGB(90, 64, 36), SMOOTH, m)
		elseif kind == "wrapper" then
			ell(Vector3.new(0.95, 0.34, 0.55), CFrame.new(0, 0.18, 0), Color3.fromRGB(230, 70, 124), SMOOTH, m)
			ell(Vector3.new(0.5, 0.36, 0.2), CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 255, 255), SMOOTH, m)
			for i = -1, 1, 2 do
				ell(Vector3.new(0.42, 0.3, 0.6), CFrame.new(0.62 * i, 0.16, 0) * CFrame.Angles(0.5 * i, 0, 0), Color3.fromRGB(252, 176, 60), SMOOTH, m)
			end
		else -- apple core
			ell(Vector3.new(0.45, 0.85, 0.45), CFrame.new(0, 0.46, 0), Color3.fromRGB(246, 236, 196), SMOOTH, m)
			ell(Vector3.new(0.75, 0.3, 0.75), CFrame.new(0, 0.12, 0), Color3.fromRGB(206, 40, 40), SMOOTH, m)
			ell(Vector3.new(0.7, 0.28, 0.7), CFrame.new(0, 0.84, 0), Color3.fromRGB(206, 40, 40), SMOOTH, m)
			cyl(0.32, 0.07, CFrame.new(0, 1.08, 0), Color3.fromRGB(110, 70, 40), WOODM, m)
			ell(Vector3.new(0.3, 0.04, 0.16), CFrame.new(0.12, 1.12, 0) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(80, 150, 60), SMOOTH, m)
		end
		return done(m)
	end

	-- a pedal bin with a flap lid, a colour band and its label
	local function bin3(x, z, col, label)
		local m = model("Bin")
		local dk = col:Lerp(Color3.new(0, 0, 0), 0.3)
		cyl(2.6, 2.3, CFrame.new(0, 1.3, 0), col, SMOOTH, m)
		cyl(0.3, 2.42, CFrame.new(0, 0.15, 0), dk, SMOOTH, m)
		cyl(0.22, 2.5, CFrame.new(0, 2.62, 0), dk, SMOOTH, m)
		cyl(0.05, 2.0, CFrame.new(0, 2.74, 0), Color3.fromRGB(24, 24, 28), SMOOTH, m)
		cyl(0.35, 2.34, CFrame.new(0, 1.5, 0), Color3.fromRGB(250, 250, 250), SMOOTH, m)
		part(Vector3.new(0.7, 0.18, 0.5), CFrame.new(0, 0.1, 1.25), Color3.fromRGB(60, 60, 64), METAL, m)
		done(m)
		setQuery(m, false)
		m:PivotTo(CFrame.new(x, 0, z))
		local hinge = CFrame.new(x, 2.8, z - 1.15)
		local function lidAt(a) return hinge * CFrame.Angles(-a, 0, 0) * CFrame.new(0, 0, 1.15) * CFrame.Angles(0, 0, math.rad(90)) end
		local lid = cylX(0.16, 2.5, lidAt(0), col:Lerp(Color3.new(1, 1, 1), 0.12), SMOOTH)
		lid.CanQuery = false
		local lb = tag3(Vector3.new(x, 0.6, z + 1.6), label, col, 16, 104)
		lb.TextColor3 = col
		return {
			top = Vector3.new(x, 2.8, z),
			flap = function()
				tw(lid, 0.12, { CFrame = lidAt(1.1) })
				task.delay(0.35, function() if lid.Parent then tw(lid, 0.3, { CFrame = lidAt(0) }, Enum.EasingStyle.Bounce) end end)
			end,
		}
	end

	G3.Floor = function()
		scene({ cam = CFrame.lookAt(Vector3.new(0, 15.5, 11.5), Vector3.new(0, 0, 0.6)), fov = 40, bg = Color3.fromRGB(58, 48, 42), ambient = Color3.fromRGB(150, 140, 136), armDepth = 9 })
		roomSet({ wallZ = -7, wall = Color3.fromRGB(232, 216, 190), floor = Color3.fromRGB(170, 116, 72) })
		for x = -20, 20, 2 do part(Vector3.new(0.6, 14, 0.05), CFrame.new(x, 7, -6.97), Color3.fromRGB(222, 202, 172)).CanQuery = false end
		item("Bed", CFrame.new(-9.5, 0, -5.5), 1)
		item("Nightstand", CFrame.new(-4.6, 0, -6.1), 1)
		item("TableLamp", CFrame.new(-4.6, 3.4, -6.1), 1)
		item("Armchair", CFrame.new(8.5, 0, -5) * CFrame.Angles(0, math.rad(-20), 0), 1)
		item("Plant", CFrame.new(10.5, 0, 0.5), 0.8)
		-- the rug, knocked crooked
		local rug = model("Rug")
		part(Vector3.new(7.6, 0.08, 4.8), CFrame.new(0, 0.04, 0), Color3.fromRGB(150, 40, 52), FABRIC, rug)
		part(Vector3.new(7.0, 0.09, 4.2), CFrame.new(0, 0.045, 0), Color3.fromRGB(236, 214, 170), FABRIC, rug)
		part(Vector3.new(6.4, 0.1, 3.6), CFrame.new(0, 0.05, 0), Color3.fromRGB(176, 52, 62), FABRIC, rug)
		ell(Vector3.new(2.6, 0.11, 1.6), CFrame.new(0, 0.055, 0), Color3.fromRGB(240, 190, 80), FABRIC, rug)
		ell(Vector3.new(1.6, 0.12, 0.9), CFrame.new(0, 0.06, 0), Color3.fromRGB(150, 40, 52), FABRIC, rug)
		for i = -5, 5 do
			for _, sx in ipairs({ -1, 1 }) do
				part(Vector3.new(0.35, 0.04, 0.12), CFrame.new(sx * 3.95, 0.02, i * 0.42), Color3.fromRGB(246, 236, 210), FABRIC, rug)
			end
		end
		done(rug)
		local RUGC = Vector3.new(0, 0, 0.4)
		local rugA = math.rad(rng:NextInteger(0, 1) == 0 and 24 or -24)
		rug:PivotTo(CFrame.new(RUGC) * CFrame.Angles(0, rugA, 0))
		setQuery(rug, false)
		local bins = {
			r = bin3(-7.2, 3.6, Color3.fromRGB(46, 120, 226), "RECYCLE"),
			t = bin3(7.2, 3.6, Color3.fromRGB(66, 150, 84), "TRASH"),
		}

		stages({
			{
				name = "Bin the Litter",
				hint = "Drag each piece to the right bin. Flick it to throw!",
				run = function(next, progress)
					local kinds = shuffle({ "bottle", "can", "paper", "banana", "wrapper", "apple" })
					local junk, owner, list, spots = {}, {}, {}, {}
					for _, k in ipairs(kinds) do
						local pos
						for _ = 1, 40 do
							pos = Vector3.new(rng:NextNumber(-4.6, 4.6), 0.12, rng:NextNumber(-3.6, 2.4))
							local ok = true
							for _, q in ipairs(spots) do if (q - pos).Magnitude < 2.2 then ok = false break end end
							if ok then break end
						end
						table.insert(spots, pos)
						local m = litter(k)
						m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
						setQuery(m, true)
						local j = { m = m, kind = LITTER3[k] }
						table.insert(junk, j)
						for _, p in ipairs(partsOf(m)) do
							owner[p] = j
							table.insert(list, p)
						end
					end
					local binned, combo, lastBin = 0, 0, 0
					local held, conn, trail = nil, nil, {}
					local function land(j, b)
						local ok = bins[j.kind] == b
						if ok then
							b.flap()
							tweenPivot(j.m, CFrame.new(b.top - Vector3.new(0, 1.8, 0)), 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
							task.delay(0.2, function() j.m:Destroy() end)
							binned += 1
							combo = os.clock() - lastBin < 2.2 and combo + 1 or 1
							lastBin = os.clock()
							nice(b.top, combo >= 3 and ("COMBO x" .. combo) or j.thrown and "Nice shot!" or "In!", combo >= 3 and T.sun or T.green)
							sound("place")
							progress(binned / #junk)
							if binned == #junk then next() end
						else
							oops(b.top, j.kind == "r" and "That's recycling!" or "That's trash!")
							b.flap()
							local back = Vector3.new(rng:NextNumber(-3.5, 3.5), 0.12, rng:NextNumber(-2.5, 1.5))
							arc(j.m, CFrame.new(back) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 0.55, 3.5, function()
								j.busy = false
							end, 4)
						end
					end
					local function overBin(pos)
						for _, b in pairs(bins) do
							if flatDist(pos, b.top, UP) < 1.8 then return b end
						end
					end
					S.onDown = function(p)
						if held then return end
						local hit = pick(p, list)
						local j = hit and owner[hit.Instance]
						if not j or j.busy or not j.m.Parent then return end
						held, trail = j, {}
						sound("select")
						conn = follow(j.m, Vector3.new(0, 1.9, 0), UP, {
							rot = function() return CFrame.Angles(0.35, os.clock() * 2, 0.2) end, speed = 26,
						})
					end
					S.onMove = function(p)
						if held then
							table.insert(trail, { p, os.clock() })
							if #trail > 8 then table.remove(trail, 1) end
						end
					end
					S.onUp = function(p)
						local j = held
						if not j then return end
						held = nil
						letGo(conn)
						j.busy = true
						local pos = j.m:GetPivot().Position
						local b = overBin(pos)
						if b then
							j.thrown = false
							arc(j.m, CFrame.new(b.top + Vector3.new(0, 0.4, 0)), 0.2, 0.8, function() land(j, b) end)
							return
						end
						-- a flick: fast enough toward a bin flies there
						local v = Vector2.zero
						local now = os.clock()
						for _, s in ipairs(trail) do
							if now - s[2] < 0.12 then
								v = (p - s[1]) / math.max(now - s[2], 1 / 60)
								break
							end
						end
						if v.Magnitude > 650 then
							local best, bd = nil, 0.82
							for _, bb in pairs(bins) do
								local dir = toArea(bb.top) - toArea(pos)
								local dd = v.Unit:Dot(dir.Unit)
								if dd > bd then best, bd = bb, dd end
							end
							if best then
								j.thrown = true
								arc(j.m, CFrame.new(best.top + Vector3.new(0, 0.4, 0)), 0.45, 3.4, function() land(j, best) end, 6)
								sound("turn")
								return
							end
						end
						arc(j.m, CFrame.new(Vector3.new(pos.X, 0.12, pos.Z)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), 0.25, 0.4, function() j.busy = false end)
					end
				end,
			},
			{
				name = "Vacuum the Dust",
				hint = "Hold down to run the vacuum over the dusty patches",
				run = function(next, progress)
					local vac = model("Vacuum")
					cylX(1.0, 0.34, CFrame.new(0, 0, 0), Color3.fromRGB(40, 42, 48), SMOOTH, vac)
					ell(Vector3.new(1.0, 1.7, 1.0), CFrame.new(0, -0.85, 0), Color3.fromRGB(220, 50, 60), SMOOTH, vac)
					local cup = cyl(0.8, 0.8, CFrame.new(0, -0.8, 0.32), Color3.fromRGB(200, 220, 235), GLASSM, vac)
					cup.Transparency = 0.35
					cyl(1.3, 0.3, CFrame.new(0, -2.1, 0), CHROME, METAL, vac)
					part(Vector3.new(1.8, 0.28, 0.7), CFrame.new(0, -2.75, 0), Color3.fromRGB(46, 48, 54), SMOOTH, vac)
					local light = part(Vector3.new(1.5, 0.08, 0.06), CFrame.new(0, -2.68, 0.36), Color3.fromRGB(90, 90, 96), NEON, vac)
					done(vac)
					setQuery(vac, false)
					local tip = Vector3.new(0, -2.75, 0)
					local conn = follow(vac, Vector3.new(0, 0, 0), UP, {
						lift = 2.9, press = 0,
						rot = function() return CFrame.Angles(-0.32, 0, S.held and math.sin(os.clock() * 50) * 0.02 or 0) end,
					})
					local patches, done2 = {}, 0
					for i = 1, 4 do
						local pos
						for _ = 1, 30 do
							pos = Vector3.new(rng:NextNumber(-5, 5), 0.13, rng:NextNumber(-3.4, 2.2))
							local ok = true
							for _, q in ipairs(patches) do if (q.pos - pos).Magnitude < 3 then ok = false break end end
							if ok then break end
						end
						local pt = { pos = pos, hp = 1.1, bits = {} }
						pt.disc = cyl(0.02, 2.4, CFrame.new(pos), Color3.fromRGB(120, 112, 100), SMOOTH)
						pt.disc.Transparency = 0.3
						pt.disc.CanQuery = false
						for k = 1, 10 do
							local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0.1, 1.1)
							local b = ball(rng:NextNumber(0.14, 0.32), CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.08, math.sin(a) * r)), k % 3 == 0 and Color3.fromRGB(140, 96, 60) or Color3.fromRGB(150, 146, 140), FABRIC)
							b.CanQuery = false
							table.insert(pt.bits, b)
						end
						table.insert(patches, pt)
					end
					local nextSuck, nextSfx = 0, 0
					every(function(dt)
						if not vac.Parent then return end
						local on = S.held
						light.Color = on and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(90, 90, 96)
						if not on then return end
						local tipW = vac:GetPivot() * tip
						local now = os.clock()
						if now > nextSfx then nextSfx = now + 0.3 sound("spray") end
						for _, pt in ipairs(patches) do
							if pt.hp > 0 and flatDist(tipW, pt.pos, UP) < 1.6 then
								pt.hp -= dt
								pt.disc.Transparency = 0.3 + 0.7 * (1 - math.max(pt.hp, 0) / 1.1)
								if now > nextSuck and #pt.bits > 0 then
									nextSuck = now + 0.07
									local b = table.remove(pt.bits)
									tw(b, 0.16, { Position = tipW, Size = Vector3.new(0.05, 0.05, 0.05) })
									task.delay(0.17, function() b:Destroy() end)
								end
								if pt.hp <= 0 then
									for _, b in ipairs(pt.bits) do b:Destroy() end
									pt.bits = {}
									pt.disc:Destroy()
									done2 += 1
									nice(pt.pos, done2 == #patches and "Dust-free!" or "Sucked up!")
									progress(done2 / #patches)
									if done2 == #patches then
										letGo(conn)
										tweenPivot(vac, vac:GetPivot() + Vector3.new(0, 14, 0), 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
										task.delay(0.42, function() vac:Destroy() end)
										next()
									end
								end
							end
						end
					end)
				end,
			},
			{
				name = "Straighten the Rug",
				hint = "Grab the rug and turn it until it sits square",
				run = function(next, progress)
					setQuery(rug, true)
					local list = partsOf(rug)
					local grabbing, a0, s0 = false, 0, 0
					local function angleAt(p)
						local hit = onPlane(p, RUGC, UP)
						if not hit then return nil end
						return math.atan2(-(hit.Z - RUGC.Z), hit.X - RUGC.X)
					end
					local function off() -- how far from square, either way round
						local a = rugA % math.pi
						return math.min(a, math.pi - a)
					end
					local start = off()
					S.onDown = function(p)
						if not pick(p, list) then return end
						local a = angleAt(p)
						if not a then return end
						grabbing, a0, s0 = true, a, rugA
						sound("sheets")
					end
					S.onMove = function(p)
						if not grabbing then return end
						local a = angleAt(p)
						if not a then return end
						rugA = s0 + (a - a0)
						rug:PivotTo(CFrame.new(RUGC) * CFrame.Angles(0, rugA, 0))
						progress(1 - off() / math.max(start, 0.01))
						if off() < math.rad(3.5) then
							grabbing = false
							rugA = math.floor(rugA / math.pi + 0.5) * math.pi
							tweenPivot(rug, CFrame.new(RUGC) * CFrame.Angles(0, rugA, 0), 0.15)
							setQuery(rug, false)
							nice(RUGC, "Perfectly square!", T.sun)
							next()
						end
					end
					S.onUp = function() grabbing = false end
				end,
			},
		})
	end

	---------------------------------------------------------------- Bed: strip it, bag it, fresh sheet, fluff, duvet, mint
	G3.Bed = function()
		scene({ cam = CFrame.lookAt(Vector3.new(0, 13.5, 10.5), Vector3.new(0, 1.4, -1.0)), fov = 42, bg = Color3.fromRGB(54, 46, 44), ambient = Color3.fromRGB(150, 142, 140), armDepth = 9 })
		roomSet({ wallZ = -6, wall = Color3.fromRGB(196, 214, 222), floor = Color3.fromRGB(150, 104, 70) })
		for x = -20, 20, 2.5 do part(Vector3.new(1.2, 14, 0.05), CFrame.new(x, 7, -5.97), Color3.fromRGB(186, 206, 216)).CanQuery = false end
		-- the bed: a wooden frame, a padded headboard and the mattress (top at y = 2)
		part(Vector3.new(8.0, 1.1, 10.0), CFrame.new(0, 0.85, -0.3), Color3.fromRGB(120, 78, 48), WOODM).CanQuery = false
		part(Vector3.new(7.4, 0.9, 9.4), CFrame.new(0, 1.55, -0.3), Color3.fromRGB(236, 236, 240), FABRIC).CanQuery = false
		part(Vector3.new(8.4, 4.8, 0.5), CFrame.new(0, 2.6, -5.4), Color3.fromRGB(110, 70, 44), WOODM).CanQuery = false
		part(Vector3.new(7.4, 3.0, 0.3), CFrame.new(0, 3.3, -5.05), Color3.fromRGB(40, 110, 118), FABRIC).CanQuery = false
		for i = -2, 2 do ball(0.18, CFrame.new(i * 1.4, 3.3, -4.9), BRASS, METAL).CanQuery = false end
		item("Nightstand", CFrame.new(6.3, 0, -4.4), 1)
		item("TableLamp", CFrame.new(6.3, 3.3, -4.9), 0.9)
		item("Rug", CFrame.new(0, 0, 6.5), 0.9)
		local C = Vector3.new(0, 2.04, -0.3)
		local HX, HZ = 3.65, 4.6
		-- the basket (laundry goes here)
		local BASKET = Vector3.new(-7.0, 0, 2.0)
		cyl(2.4, 2.6, CFrame.new(BASKET + Vector3.new(0, 1.2, 0)), Color3.fromRGB(196, 160, 110), Enum.Material.Fabric).CanQuery = false
		cyl(0.25, 2.8, CFrame.new(BASKET + Vector3.new(0, 2.4, 0)), Color3.fromRGB(160, 120, 76), WOODM).CanQuery = false
		cyl(0.05, 2.3, CFrame.new(BASKET + Vector3.new(0, 2.53, 0)), Color3.fromRGB(60, 46, 34), SMOOTH).CanQuery = false
		tag3(BASKET + Vector3.new(0, 0.4, 1.8), "LAUNDRY", T.gold, 14, 96)

		local bundle -- the stripped sheet, balled up
		local pillows = {}
		for i, sx in ipairs({ -1, 1 }) do
			local p = ell(Vector3.new(3.0, 0.32, 1.7), CFrame.new(sx * 1.75, 2.22, -4.0) * CFrame.Angles(0, sx * 0.25 + rng:NextNumber(-0.15, 0.15), sx * 0.08), Color3.fromRGB(250, 250, 252), FABRIC)
			pillows[i] = { p = p, n = 0, x = sx * 1.75 }
		end

		stages({
			{
				name = "Strip the Sheet",
				hint = "Drag each corner of the dirty sheet into the middle",
				run = function(next, progress)
					local quads, handles, owner = {}, {}, {}
					local stainCols = { Color3.fromRGB(160, 120, 60), Color3.fromRGB(190, 160, 80), Color3.fromRGB(120, 100, 80) }
					for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
						local q = { sx = s[1], sz = s[2], K = C + Vector3.new(s[1] * HX, 0, s[2] * HZ), stains = {} }
						q.H = q.K
						q.part = part(Vector3.new(HX, 0.06, HZ), CFrame.new((C + q.K) / 2), Color3.fromRGB(228, 220, 196), FABRIC)
						q.part.CanQuery = false
						for _ = 1, rng:NextInteger(1, 2) do
							local st = ell(Vector3.new(1, 0.08, 0.8), CFrame.new(C), stainCols[rng:NextInteger(1, 3)], SMOOTH)
							st.CanQuery = false
							st.Transparency = 0.2
							table.insert(q.stains, { p = st, u = rng:NextNumber(0.25, 0.8), v = rng:NextNumber(0.25, 0.8), d = rng:NextNumber(0.8, 1.5) })
						end
						q.handle = ball(0.6, CFrame.new(q.K + Vector3.new(0, 0.15, 0)), T.sun, NEON)
						owner[q.handle] = q
						table.insert(handles, q.handle)
						table.insert(quads, q)
					end
					local function shape(q)
						local a, b = C, q.H
						local w, d = math.max(math.abs(b.X - a.X), 0.05), math.max(math.abs(b.Z - a.Z), 0.05)
						q.part.Size = Vector3.new(w, 0.06, d)
						q.part.CFrame = CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, 0)
						local k = math.min(w / HX, d / HZ)
						for _, st in ipairs(q.stains) do
							st.p.CFrame = CFrame.new(Vector3.new(a.X + (b.X - a.X) * st.u, 2.09, a.Z + (b.Z - a.Z) * st.v))
							st.p.Size = Vector3.new(st.d * k, 0.08, st.d * 0.7 * k)
						end
						q.handle.CFrame = CFrame.new(q.H + Vector3.new(0, 0.15, 0))
					end
					local t0 = os.clock()
					every(function()
						local k = (math.sin((os.clock() - t0) * 6) + 1) / 2
						for _, q in ipairs(quads) do if q.handle.Parent then q.handle.Transparency = k * 0.4 end end
					end)
					local held, folded = nil, 0
					local bits = {}
					S.onDown = function(p)
						local hit = pick(p, handles)
						held = hit and owner[hit.Instance]
						if held then sound("sheets") V.handPos = held.H end
					end
					S.onMove = function(p)
						local q = held
						if not q then return end
						local hit = onPlane(p, C, UP)
						if not hit then return end
						-- the corner only moves inward, inside its own quarter
						local x = math.clamp(hit.X, math.min(C.X, q.K.X), math.max(C.X, q.K.X))
						local z = math.clamp(hit.Z, math.min(C.Z, q.K.Z), math.max(C.Z, q.K.Z))
						q.H = Vector3.new(x, C.Y, z)
						V.handPos = q.H + Vector3.new(0, 0.2, 0)
						shape(q)
						if (q.H - C).Magnitude < 1.3 then
							held = nil
							V.handPos = nil
							q.part:Destroy()
							q.handle:Destroy()
							table.remove(handles, table.find(handles, q.handle))
							for _, st in ipairs(q.stains) do st.p:Destroy() end
							folded += 1
							for _ = 1, 2 do
								local b = ball(rng:NextNumber(1.0, 1.5), CFrame.new(C + Vector3.new(rng:NextNumber(-0.5, 0.5), 0.5 + folded * 0.12, rng:NextNumber(-0.5, 0.5))), Color3.fromRGB(226, 218, 194), FABRIC)
								b.CanQuery = false
								table.insert(bits, b)
							end
							sound("sheets")
							bubbles(toArea(C), 3)
							progress(folded / 4)
							if folded == 4 then
								bundle = model("Bundle")
								for _, b in ipairs(bits) do
									b.CFrame = CFrame.new(b.Position - C)
									b.Parent = bundle
								end
								ell(Vector3.new(0.7, 0.1, 0.5), CFrame.new(0.3, 0.9, 0.4), Color3.fromRGB(170, 130, 70), SMOOTH, bundle)
								done(bundle)
								bundle:PivotTo(CFrame.new(C))
								next()
							end
						end
					end
					S.onUp = function() held = nil V.handPos = nil end
				end,
			},
			{
				name = "Into the Laundry",
				hint = "Carry the dirty bundle to the laundry basket",
				run = function(next)
					dragStage(bundle, Vector3.new(0, 3.2, 0), UP, BASKET + Vector3.new(0, 3.2, 0), 2.0, { mark = 2.6 }, function()
						arc(bundle, CFrame.new(BASKET + Vector3.new(0, 1.6, 0)), 0.3, 1.2, function()
							bundle:Destroy()
							sound("place")
							nice(BASKET + Vector3.new(0, 2.6, 0), "In the wash!")
							next()
						end)
					end)
				end,
			},
			{
				name = "Throw the Sheet",
				hint = "Click when the ring lines up to spread the fresh sheet",
				run = function(next)
					local sheet = model("Sheet")
					part(Vector3.new(7.6, 0.06, 9.5), CFrame.new(0, 0, 0), Color3.fromRGB(252, 252, 255), FABRIC, sheet)
					part(Vector3.new(7.62, 0.07, 0.35), CFrame.new(0, 0.01, 4.4), Color3.fromRGB(60, 110, 200), FABRIC, sheet)
					part(Vector3.new(7.62, 0.07, 0.12), CFrame.new(0, 0.01, 4.1), BRASS, FABRIC, sheet)
					done(sheet)
					setQuery(sheet, false)
					local t0 = os.clock()
					local flying = true
					local wave = every(function()
						if not flying then return end
						local t = os.clock() - t0
						sheet:PivotTo(CFrame.new(C + Vector3.new(0, 3.2 + math.sin(t * 3) * 0.35, 0.3)) * CFrame.Angles(math.sin(t * 2.3) * 0.12, 0, math.sin(t * 1.7) * 0.08))
					end)
					local judge, stop = beatRing(toArea(C + Vector3.new(0, 1, 0)), 1.25)
					S.onDown = function()
						local j = judge()
						if j == 0 then
							nope(C + Vector3.new(0, 2, 0), "Not yet... wait for it!")
							return
						end
						stop()
						flying = false
						wave:Disconnect()
						S.onDown = nil
						tweenPivot(sheet, CFrame.new(C + Vector3.new(0, 0.03, 0)), 0.35, Enum.EasingStyle.Back)
						sound("sheets")
						task.delay(0.3, function()
							nice(C, j == 2 and "Perfect throw!" or "Nice!", j == 2 and T.sun or T.green)
							next()
						end)
					end
				end,
			},
			{
				name = "Fluff the Pillows",
				hint = "Click each pillow to plump it up",
				run = function(next, progress)
					local list, owner = {}, {}
					for _, pl in ipairs(pillows) do
						pl.p.CanQuery = true
						table.insert(list, pl.p)
						owner[pl.p] = pl
					end
					local total = 0
					S.onDown = function(p)
						local hit = pick(p, list)
						local pl = hit and owner[hit.Instance]
						if not pl or pl.n >= 4 then return end
						pl.n += 1
						total += 1
						local sz = Vector3.new(3.0, 0.32 + pl.n * 0.2, 1.7 + pl.n * 0.05)
						pl.p.Size = sz * Vector3.new(1.06, 1.15, 1.06)
						tw(pl.p, 0.25, { Size = sz }, Enum.EasingStyle.Back)
						burst(toArea(pl.p.Position), Color3.fromRGB(255, 255, 255), 6, 60)
						sound("sheets")
						progress(total / 8)
						if pl.n == 4 then
							pl.p.CanQuery = false
							tw(pl.p, 0.35, { CFrame = CFrame.new(pl.x, 2.85, -4.25) * CFrame.Angles(math.rad(-58), 0, 0) }, Enum.EasingStyle.Back)
							floatText(toArea(pl.p.Position), "Fluffy!", T.green)
						end
						if total == 8 then next() end
					end
				end,
			},
			{
				name = "Pull Up the Duvet",
				hint = "Drag the duvet up to the pillows",
				run = function(next, progress)
					local FOOT = 4.55
					local edge = 2.6
					local duvet = part(Vector3.new(7.9, 0.42, FOOT - edge), CFrame.new(0, 2.3, (FOOT + edge) / 2), Color3.fromRGB(46, 84, 150), FABRIC)
					local stripe = part(Vector3.new(7.95, 0.44, 0.3), CFrame.new(0, 2.3, FOOT - 0.6), BRASS, FABRIC)
					stripe.CanQuery = false
					local bar = part(Vector3.new(7.6, 0.12, 0.25), CFrame.new(0, 2.56, edge + 0.2), T.sun, NEON)
					bar.CanQuery = false
					local grabbing = false
					local function set(e)
						edge = math.clamp(e, -2.6, 3.4)
						duvet.Size = Vector3.new(7.9, 0.42, FOOT - edge)
						duvet.CFrame = CFrame.new(0, 2.3, (FOOT + edge) / 2)
						bar.CFrame = CFrame.new(0, 2.56, edge + 0.2)
						progress((2.6 - edge) / 4.6)
					end
					S.onDown = function(p)
						if not pick(p, { duvet }) then return end
						grabbing = true
						sound("sheets")
					end
					S.onMove = function(p)
						if not grabbing then return end
						local hit = onPlane(p, Vector3.new(0, 2.5, 0), UP)
						if not hit then return end
						set(math.min(hit.Z, edge + 0.6))
						V.handPos = Vector3.new(hit.X, 2.6, edge + 0.2)
						if edge <= -1.9 then
							grabbing = false
							V.handPos = nil
							bar:Destroy()
							set(-2.3)
							part(Vector3.new(7.95, 0.46, 1.0), CFrame.new(0, 2.32, -1.8), Color3.fromRGB(250, 250, 252), FABRIC).CanQuery = false
							sound("sheets")
							nice(Vector3.new(0, 2.5, 0), "Snug!")
							next()
						end
					end
					S.onUp = function() grabbing = false V.handPos = nil end
				end,
			},
			{
				name = "Leave a Mint",
				hint = "Place a chocolate mint on the pillow",
				run = function(next)
					local mint = model("Mint")
					part(Vector3.new(0.8, 0.18, 0.5), CFrame.new(0, 0, 0), Color3.fromRGB(70, 180, 130), SMOOTH, mint)
					part(Vector3.new(0.82, 0.19, 0.12), CFrame.new(0, 0, 0), BRASS, METAL, mint)
					for i = -1, 1, 2 do ell(Vector3.new(0.3, 0.16, 0.4), CFrame.new(0.52 * i, 0, 0), Color3.fromRGB(70, 180, 130), SMOOTH, mint) end
					done(mint)
					cyl(0.12, 1.4, CFrame.new(6.0, 3.32, -3.6), Color3.fromRGB(250, 250, 250), SMOOTH).CanQuery = false
					mint:PivotTo(CFrame.new(6.0, 3.5, -3.6))
					local target = Vector3.new(1.75, 3.6, -4.1)
					dragStage(mint, Vector3.new(0, 3.6, 0), UP, target, 1.4, { mark = 1.6 }, function()
						tweenPivot(mint, CFrame.new(1.75, 3.25, -3.9) * CFrame.Angles(math.rad(-50), 0.3, 0), 0.25, Enum.EasingStyle.Back)
						sound("place")
						nice(target, "A sweet touch!", T.sun)
						next()
					end)
				end,
			},
		})
	end

	---------------------------------------------------------------- Shower: scrub the mildew, rinse the suds, squeegee the glass
	G3.Shower = function()
		scene({
			cam = CFrame.lookAt(Vector3.new(0, 6.2, 12.5), Vector3.new(0, 4.6, 0)), fov = 42, bg = Color3.fromRGB(50, 56, 62),
			ambient = Color3.fromRGB(150, 156, 160), light = Color3.fromRGB(240, 244, 250), dir = Vector3.new(-0.3, -1, -0.6), armDepth = 8,
		})
		roomSet({ wallZ = -1.6, wall = Color3.fromRGB(214, 226, 230), floor = Color3.fromRGB(90, 100, 118), floorMat = SMOOTH })
		local WALLZ = -0.97
		part(Vector3.new(10.4, 10.6, 0.4), CFrame.new(0, 5.3, -1.17), Color3.fromRGB(226, 238, 242)).CanQuery = false
		grout(CFrame.new(0, 5.3, WALLZ - 0.01), 10.4, 10.6, 1.05, Color3.fromRGB(196, 210, 216))
		-- a band of darker tiles at shoulder height
		part(Vector3.new(10.4, 0.5, 0.05), CFrame.new(0, 6.6, WALLZ + 0.01), Color3.fromRGB(46, 120, 140)).CanQuery = false
		for _, sx in ipairs({ -1, 1 }) do
			part(Vector3.new(0.4, 10.6, 6), CFrame.new(sx * 5.4, 5.3, 1.8), Color3.fromRGB(220, 232, 236)).CanQuery = false
		end
		part(Vector3.new(10.4, 0.45, 6), CFrame.new(0, 0.22, 1.8), Color3.fromRGB(250, 250, 252)).CanQuery = false
		cyl(0.05, 0.9, CFrame.new(0, 0.46, 1.6), CHROME, METAL).CanQuery = false
		-- the rain head, its arm, the mixer and a caddy of bottles
		cylZ(1.4, 0.24, CFrame.new(3.2, 9.0, -0.3), CHROME, METAL).CanQuery = false
		cyl(0.25, 1.8, CFrame.new(3.2, 8.85, 0.4), CHROME, METAL).CanQuery = false
		cylZ(0.5, 0.9, CFrame.new(3.2, 4.2, -0.75), CHROME, METAL).CanQuery = false
		part(Vector3.new(0.25, 1.1, 0.25), CFrame.new(3.2, 4.65, -0.4) * CFrame.Angles(0.6, 0, 0), CHROME, METAL).CanQuery = false
		part(Vector3.new(2.6, 0.15, 0.9), CFrame.new(-3.4, 5.1, -0.5), CHROME, METAL).CanQuery = false
		for i, c in ipairs({ Color3.fromRGB(240, 120, 150), Color3.fromRGB(110, 180, 240), Color3.fromRGB(250, 250, 250) }) do
			cyl(1.0 - i * 0.12, 0.55, CFrame.new(-4.3 + i * 0.75, 5.7 - i * 0.06, -0.5), c, SMOOTH).CanQuery = false
			cyl(0.2, 0.3, CFrame.new(-4.3 + i * 0.75, 6.25 - i * 0.12, -0.5), Color3.fromRGB(60, 60, 64), SMOOTH).CanQuery = false
		end
		local spots = {}
		local mildew = { Color3.fromRGB(120, 110, 60), Color3.fromRGB(96, 110, 70), Color3.fromRGB(170, 120, 60), Color3.fromRGB(80, 80, 60) }
		local suds = {}

		stages({
			{
				name = "Scrub the Mildew",
				hint = "Hold and rub the sponge over the grimy tiles",
				run = function(next, progress)
					local placed = {}
					for _ = 1, 6 do
						local pos
						for _ = 1, 40 do
							pos = Vector3.new(rng:NextNumber(-4.2, 4.2), rng:NextNumber(1.2, 8.0), WALLZ + 0.02)
							local ok = (pos - Vector3.new(3.2, 4.2, pos.Z)).Magnitude > 1.4 and (pos - Vector3.new(-3.4, 5.6, pos.Z)).Magnitude > 1.8
							for _, q in ipairs(placed) do if (q - pos).Magnitude < 2.3 then ok = false break end end
							if ok then break end
						end
						table.insert(placed, pos)
						local s = stain(pos, Vector3.zAxis, rng:NextNumber(0.7, 1.0), mildew, 5)
						s.onRub = function(at)
							if #suds < 90 then
								local b = ball(rng:NextNumber(0.25, 0.55), CFrame.new(at + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), 0.2)), Color3.fromRGB(255, 255, 255), SMOOTH)
								b.CanQuery = false
								b.Transparency = 0.08
								table.insert(suds, b)
							end
						end
						table.insert(spots, s)
					end
					local sponge = model("Sponge")
					part(Vector3.new(1.5, 1.0, 0.55), CFrame.new(0, 0, 0), Color3.fromRGB(255, 214, 70), SMOOTH, sponge)
					part(Vector3.new(1.5, 1.0, 0.18), CFrame.new(0, 0, -0.36), Color3.fromRGB(60, 160, 90), FABRIC, sponge)
					for k = 1, 5 do ball(0.12, CFrame.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.4, 0.4), 0.27), Color3.fromRGB(230, 186, 50), SMOOTH, sponge) end
					done(sponge)
					setQuery(sponge, false)
					local conn = follow(sponge, Vector3.new(0, 0, WALLZ + 0.5), Vector3.zAxis, {
						press = 0.05, grip = Vector3.new(0, -0.2, 0.3),
						rot = function() return CFrame.Angles(0, 0, S.held and math.sin(os.clock() * 24) * 0.12 or 0) end,
					})
					local rub = scrubber(spots, 0.75, progress, function()
						letGo(conn)
						tweenPivot(sponge, sponge:GetPivot() + Vector3.new(0, -12, 4), 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						task.delay(0.42, function() sponge:Destroy() end)
						next()
					end)
					every(function()
						if not sponge.Parent then return end
						if S.held then
							local p = sponge:GetPivot().Position
							rub(Vector3.new(p.X, p.Y, WALLZ + 0.02))
						else
							rub(nil)
						end
					end)
				end,
			},
			{
				name = "Rinse It Down",
				hint = "Hold down to spray the suds away",
				run = function(next, progress)
					-- every scrubbed spot leaves a little foam behind
					for _, s in ipairs(spots) do
						for _ = 1, 5 do
							local b = ball(rng:NextNumber(0.3, 0.6), CFrame.new(s.pos + Vector3.new(rng:NextNumber(-0.9, 0.9), rng:NextNumber(-0.9, 0.9), 0.2)), Color3.fromRGB(255, 255, 255), SMOOTH)
							b.CanQuery = false
							b.Transparency = 0.08
							table.insert(suds, b)
						end
					end
					local total = #suds
					local gone = 0
					local head = model("Handset")
					cylZ(0.3, 1.0, CFrame.new(0, 0, -0.1), CHROME, METAL, head)
					cylZ(0.05, 0.85, CFrame.new(0, 0, -0.27), Color3.fromRGB(70, 74, 80), SMOOTH, head)
					part(Vector3.new(0.32, 1.9, 0.32), CFrame.new(0, -1.05, 0.2) * CFrame.Angles(0.25, 0, 0), CHROME, METAL, head)
					done(head)
					setQuery(head, false)
					V.hand, V.handOff = head, Vector3.new(0, -1.5, 0.35)
					local stream = cylX(1, 0.28, CFrame.new(), Color3.fromRGB(150, 205, 255), SMOOTH)
					stream.CanQuery = false
					stream.Transparency = 1
					local splash = {}
					for k = 1, 6 do
						local b = ball(0.2, CFrame.new(), Color3.fromRGB(190, 230, 255), SMOOTH)
						b.CanQuery, b.Transparency = false, 1
						splash[k] = b
					end
					local nextDrop, nextSfx = 0, 0
					local pos
					every(function(dt)
						if not head.Parent then return end
						local p = ptr()
						local wallHit = onPlane(p, Vector3.new(0, 0, WALLZ + 0.05), Vector3.zAxis)
						local near = onPlane(p, Vector3.new(0, 0, 3.4), Vector3.zAxis)
						if not wallHit or not near then return end
						local target = near + Vector3.new(1.0, -1.2, 0)
						pos = pos and pos:Lerp(target, 1 - math.exp(-dt * 20)) or target
						head:PivotTo(CFrame.lookAt(pos, wallHit))
						local on = S.held
						local nozzle = pos + (wallHit - pos).Unit * 0.3
						if on then
							local L = (wallHit - nozzle).Magnitude
							stream.Size = Vector3.new(L, 0.22 + math.sin(os.clock() * 40) * 0.04, 0.22)
							stream.CFrame = CFrame.lookAt((nozzle + wallHit) / 2, wallHit) * CFrame.Angles(0, math.rad(90), 0)
							stream.Transparency = 0.4
							for k, b in ipairs(splash) do
								local a = os.clock() * 9 + k
								b.Position = wallHit + Vector3.new(math.cos(a) * rng:NextNumber(0.2, 0.7), math.sin(a) * rng:NextNumber(0.2, 0.7), 0.1)
								b.Transparency = 0.3
							end
							local now = os.clock()
							if now > nextSfx then nextSfx = now + 0.4 sound("spray") end
							if now > nextDrop then
								nextDrop = now + 0.05
								local d = ball(0.16, CFrame.new(wallHit + Vector3.new(rng:NextNumber(-0.4, 0.4), 0, 0.12)), Color3.fromRGB(170, 215, 255), SMOOTH)
								d.CanQuery, d.Transparency = false, 0.3
								tw(d, 0.6, { Position = Vector3.new(d.Position.X, 0.6, d.Position.Z), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
								task.delay(0.62, function() d:Destroy() end)
							end
							for i = #suds, 1, -1 do
								local b = suds[i]
								if (b.Position - wallHit).Magnitude < 1.4 then
									b.Transparency += dt * 3
									b.Position -= Vector3.new(0, dt * 3, 0)
									if b.Transparency >= 1 then
										b:Destroy()
										table.remove(suds, i)
										gone += 1
										progress(gone / total)
									end
								end
							end
							if #suds == 0 and head:GetAttribute("Done") == nil then
								head:SetAttribute("Done", true)
								stream:Destroy()
								for _, b in ipairs(splash) do b:Destroy() end
								V.hand = nil
								head:Destroy()
								nice(Vector3.new(0, 4.5, WALLZ), "Squeaky clean!")
								next()
							end
						else
							stream.Transparency = 1
							for _, b in ipairs(splash) do b.Transparency = 1 end
						end
					end)
				end,
			},
			{
				name = "Squeegee the Glass",
				hint = "Hold and wipe the steamy glass clear, top to bottom",
				run = function(next, progress)
					local GZ = 3.4
					local door = model("Door")
					local glass = part(Vector3.new(10.2, 9.8, 0.12), CFrame.new(0, 5.1, GZ), Color3.fromRGB(200, 232, 240), GLASSM, door)
					glass.Transparency = 0.7
					for _, y in ipairs({ 0.2, 10.0 }) do part(Vector3.new(10.4, 0.2, 0.25), CFrame.new(0, y, GZ), CHROME, METAL, door) end
					for _, x in ipairs({ -5.1, 5.1 }) do part(Vector3.new(0.2, 10, 0.25), CFrame.new(x, 5.1, GZ), CHROME, METAL, door) end
					done(door)
					setQuery(door, false)
					door:PivotTo(CFrame.new(14, 0, 0))
					tweenPivot(door, CFrame.new(), 0.45, Enum.EasingStyle.Back)
					sound("open")
					local LANES, ROWS = 6, 6 -- the fog only covers the part of the glass the camera sees (y 1.8..8.2)
					local cells, cleared = {}, 0
					local lw, rh = 10 / LANES, 6.4 / ROWS
					for i = 1, LANES do
						for j = 1, ROWS do
							local c = { x = -5 + (i - 0.5) * lw, y = 1.8 + (j - 0.5) * rh, drops = {} }
							c.p = part(Vector3.new(lw + 0.02, rh + 0.02, 0.04), CFrame.new(c.x, c.y, GZ + 0.12), Color3.fromRGB(236, 242, 246), SMOOTH)
							c.p.CanQuery, c.p.Transparency = false, 1
							tw(c.p, 0.4, { Transparency = 0.22 }, nil, nil, 0.3)
							for _ = 1, 2 do
								local d = ball(rng:NextNumber(0.1, 0.2), CFrame.new(c.x + rng:NextNumber(-0.6, 0.6), c.y + rng:NextNumber(-0.4, 0.4), GZ + 0.16), Color3.fromRGB(210, 230, 240), SMOOTH)
								d.CanQuery, d.Transparency = false, 0.2
								table.insert(c.drops, d)
							end
							table.insert(cells, c)
						end
					end
					local sq = model("Squeegee")
					part(Vector3.new(2.2, 0.22, 0.22), CFrame.new(0, 0, 0), Color3.fromRGB(30, 30, 34), SMOOTH, sq)
					part(Vector3.new(2.3, 0.36, 0.3), CFrame.new(0, 0.26, 0.05), Color3.fromRGB(46, 150, 210), SMOOTH, sq)
					cyl(1.8, 0.28, CFrame.new(0, 1.3, 0.1), Color3.fromRGB(46, 150, 210), SMOOTH, sq)
					done(sq)
					setQuery(sq, false)
					local conn = follow(sq, Vector3.new(0, 0, GZ + 0.3), Vector3.zAxis, {
						press = 0.06, grip = Vector3.new(0, 1.6, 0.1),
						clamp = function(t) return Vector3.new(math.clamp(t.X, -4.2, 4.2), math.clamp(t.Y, 1.6, 8.4), t.Z) end,
					})
					local nextSfx = 0
					every(function()
						if not sq.Parent or not S.held then return end
						local p = sq:GetPivot().Position
						for _, c in ipairs(cells) do
							if not c.done and math.abs(c.x - p.X) < 1.15 and math.abs(c.y - p.Y) < 0.6 then
								c.done = true
								cleared += 1
								tw(c.p, 0.15, { Transparency = 1 })
								for _, d in ipairs(c.drops) do tw(d, 0.4, { Position = d.Position - Vector3.new(0, 1.2, 0), Transparency = 1 }) end
								if os.clock() > nextSfx then nextSfx = os.clock() + 0.18 sound("sheets") end
								progress(cleared / #cells)
								if cleared == #cells then
									letGo(conn)
									tweenPivot(sq, sq:GetPivot() + Vector3.new(0, -12, 0), 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
									task.delay(0.37, function() sq:Destroy() end)
									nice(Vector3.new(0, 5, GZ), "Crystal clear!", T.sun)
									next()
								end
							end
						end
					end)
				end,
			},
		})
	end

	---------------------------------------------------------------- Toilet: lid up, scrub, plunge, flush, fresh roll
	G3.Toilet = function()
		scene({
			cam = CFrame.lookAt(Vector3.new(0, 11, 8.2), Vector3.new(0, 2.8, -0.7)), fov = 42, bg = Color3.fromRGB(50, 53, 56),
			ambient = Color3.fromRGB(135, 137, 140), light = Color3.fromRGB(240, 234, 226), dir = Vector3.new(-0.4, -1, -0.5), armDepth = 8,
		})
		roomSet({ wallZ = -3.6, wall = Color3.fromRGB(150, 182, 168), floor = Color3.fromRGB(78, 90, 112), floorMat = SMOOTH })
		grout(CFrame.new(0, 6, -3.59), 30, 12, 1.2, Color3.fromRGB(206, 222, 212))
		grout(CFrame.new(0, 0.01, 0) * CFrame.Angles(math.rad(-90), 0, 0), 40, 40, 2, Color3.fromRGB(116, 128, 150))
		item("TowelStack", CFrame.new(-5.6, 0, -2.2), 1)
		item("Plant", CFrame.new(6.2, 0, -2.0), 0.6)
		-- the toilet, facing us
		local P = PORCELAIN
		part(Vector3.new(2.5, 0.3, 3.0), CFrame.new(0, 0.15, -0.6), P).CanQuery = false
		ell(Vector3.new(2.1, 2.6, 2.7), CFrame.new(0, 1.2, -0.5), P).CanQuery = false
		ell(Vector3.new(3.5, 1.9, 4.3), CFrame.new(0, 2.3, 0.1), P).CanQuery = false
		ell(Vector3.new(3.6, 0.3, 4.4), CFrame.new(0, 3.1, 0.1), Color3.fromRGB(240, 242, 245)).CanQuery = false
		ell(Vector3.new(3.7, 0.22, 4.5), CFrame.new(0, 3.24, 0.15), Color3.fromRGB(252, 252, 252)).CanQuery = false
		ell(Vector3.new(2.6, 0.24, 3.3), CFrame.new(0, 3.27, 0.25), Color3.fromRGB(214, 222, 228)).CanQuery = false
		ell(Vector3.new(2.1, 0.25, 2.7), CFrame.new(0, 3.29, 0.3), Color3.fromRGB(196, 206, 214)).CanQuery = false
		local water = ell(Vector3.new(1.6, 0.26, 2.1), CFrame.new(0, 3.31, 0.35), Color3.fromRGB(150, 140, 96))
		water.CanQuery = false
		part(Vector3.new(3.8, 3.2, 1.4), CFrame.new(0, 4.4, -2.75), P).CanQuery = false
		part(Vector3.new(4.0, 0.32, 1.6), CFrame.new(0, 6.15, -2.75), Color3.fromRGB(240, 242, 245)).CanQuery = false
		local lever = model("Lever")
		ball(0.32, CFrame.new(0, 0, 0), CHROME, METAL, lever)
		part(Vector3.new(1.0, 0.18, 0.2), CFrame.new(0.5, 0, 0.05), CHROME, METAL, lever)
		done(lever)
		lever:PivotTo(CFrame.new(-1.75, 5.3, -2.0))
		-- the lid, hinged at the back
		local HINGE = CFrame.new(0, 3.42, -2.0)
		local lid = ell(Vector3.new(3.7, 0.24, 4.3), HINGE * CFrame.new(0, 0, 2.15), Color3.fromRGB(252, 252, 252))
		local function lidAt(a) return HINGE * CFrame.Angles(-a, 0, 0) * CFrame.new(0, 0, 2.15) end
		-- the roll holder: an empty tube on the wall
		local HOLD = Vector3.new(4.0, 3.4, -3.15)
		cylX(1.5, 0.16, CFrame.new(HOLD), CHROME, METAL).CanQuery = false
		part(Vector3.new(0.2, 0.7, 0.5), CFrame.new(HOLD + Vector3.new(-0.75, 0, -0.2)), CHROME, METAL).CanQuery = false
		local tube = cylX(1.1, 0.5, CFrame.new(HOLD), Color3.fromRGB(190, 150, 104), SMOOTH)
		tube.CanQuery = false
		local BOWL = Vector3.new(0, 3.42, 0.35)

		stages({
			{
				name = "Lift the Lid",
				hint = "Drag the lid up",
				run = function(next, progress)
					local grabbing, y0, a = false, 0, 0
					S.onDown = function(p)
						grabbing, y0 = true, p.Y
						sound("click")
					end
					S.onMove = function(p)
						if not grabbing then return end
						a = math.clamp((y0 - p.Y) / 150 * math.rad(100), 0, math.rad(100))
						lid.CFrame = lidAt(a)
						V.handPos = (lid.CFrame * CFrame.new(0, 0.2, 2.0)).Position
						progress(a / math.rad(80))
						if a >= math.rad(78) then
							grabbing = false
							V.handPos = nil
							tw(lid, 0.25, { CFrame = lidAt(math.rad(100)) }, Enum.EasingStyle.Bounce)
							sound("knock")
							next()
						end
					end
					S.onUp = function()
						grabbing = false
						V.handPos = nil
						if a < math.rad(78) then
							a = 0
							tw(lid, 0.2, { CFrame = lidAt(0) }, Enum.EasingStyle.Bounce)
						end
					end
				end,
			},
			{
				name = "Scrub the Bowl",
				hint = "Hold and scrub every stain with the brush",
				run = function(next, progress)
					local spots = {}
					local cols = { Color3.fromRGB(150, 110, 60), Color3.fromRGB(180, 150, 70), Color3.fromRGB(110, 90, 60) }
					for k = 1, 6 do
						local a = (k / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
						local r = rng:NextNumber(0.55, 1.0)
						local pos = BOWL + Vector3.new(math.cos(a) * r * 0.85, 0.01, math.sin(a) * r * 1.1)
						table.insert(spots, stain(pos, UP, rng:NextNumber(0.3, 0.42), cols, 3))
					end
					local brush = model("Brush")
					for k = 1, 7 do
						ball(0.42, CFrame.new(math.cos(k) * 0.22, 0.1 + (k % 2) * 0.12, math.sin(k) * 0.22), Color3.fromRGB(70, 140, 230), FABRIC, brush)
					end
					cyl(3.0, 0.2, CFrame.new(0, 1.7, 0), Color3.fromRGB(250, 250, 250), SMOOTH, brush)
					ball(0.34, CFrame.new(0, 3.2, 0), Color3.fromRGB(70, 140, 230), SMOOTH, brush)
					done(brush)
					setQuery(brush, false)
					local conn = follow(brush, BOWL, UP, {
						lift = 0.1, press = 0.08, grip = Vector3.new(0, 2.8, 0),
						rot = function() return CFrame.Angles(0.55, 0, S.held and math.sin(os.clock() * 26) * 0.15 or 0) end,
						clamp = function(t)
							local d = t - BOWL
							local nx, nz = d.X / 1.25, d.Z / 1.6
							local m = math.sqrt(nx * nx + nz * nz)
							if m > 1 then d = Vector3.new(d.X / m, d.Y, d.Z / m) end
							return BOWL + d
						end,
					})
					local rub = scrubber(spots, 0.45, progress, function()
						letGo(conn)
						tweenPivot(brush, brush:GetPivot() + Vector3.new(6, 2, 0), 0.35)
						task.delay(0.37, function() brush:Destroy() end)
						next()
					end)
					every(function()
						if not brush.Parent then return end
						rub(S.held and brush:GetPivot().Position * Vector3.new(1, 0, 1) + Vector3.new(0, BOWL.Y + 0.01, 0) or nil)
					end)
				end,
			},
			{
				name = "Unclog It",
				hint = "Plunge on the beat! Click as the ring lines up",
				run = function(next, progress)
					local pl = model("Plunger")
					ell(Vector3.new(1.4, 0.8, 1.4), CFrame.new(0, 0.2, 0), Color3.fromRGB(200, 40, 50), SMOOTH, pl)
					cyl(3.2, 0.24, CFrame.new(0, 2.1, 0), Color3.fromRGB(176, 128, 80), WOODM, pl)
					done(pl)
					setQuery(pl, false)
					local up = CFrame.new(BOWL + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0.35, 0, 0)
					pl:PivotTo(up + Vector3.new(0, 5, 0))
					tweenPivot(pl, up, 0.3, Enum.EasingStyle.Back)
					V.hand, V.handOff = pl, Vector3.new(0, 3.3, 0)
					local judge, stop = beatRing(toArea(BOWL) + Vector2.new(0, -20), 1.0)
					local hits = 0
					local dirty, clean = Color3.fromRGB(150, 140, 96), Color3.fromRGB(120, 175, 220)
					S.onDown = function()
						local j = judge()
						if j == 0 then
							nope(BOWL + Vector3.new(0, 1.5, 0), "Off the beat!")
							return
						end
						hits += 1
						tweenPivot(pl, up - Vector3.new(0, 0.45, 0), 0.08)
						task.delay(0.1, function() if pl.Parent then tweenPivot(pl, up, 0.18, Enum.EasingStyle.Back) end end)
						bubbles(toArea(BOWL), 4)
						sound("knock")
						water.Color = dirty:Lerp(clean, hits / 3 * 0.5)
						floatText(toArea(BOWL) + Vector2.new(0, -50), j == 2 and "PERFECT!" or "Good!", j == 2 and T.sun or T.green)
						progress(hits / 3)
						if hits == 3 then
							stop()
							S.onDown = nil
							V.hand = nil
							tweenPivot(pl, up + Vector3.new(5, 4, 0), 0.35)
							task.delay(0.36, function() pl:Destroy() end)
							next()
						end
					end
				end,
			},
			{
				name = "Flush!",
				hint = "Press the flush handle on the tank",
				run = function(next)
					local mk = marker(Vector3.new(-1.75, 5.3, -1.95), 1.0, Vector3.zAxis)
					setQuery(lever, true)
					S.onDown = function(p)
						if not pick(p, partsOf(lever)) then return end
						S.onDown = nil
						mk.destroy()
						V.handPos = Vector3.new(-1.2, 5.3, -1.9)
						tweenPivot(lever, CFrame.new(-1.75, 5.3, -2.0) * CFrame.Angles(0, 0, -0.6), 0.12)
						task.delay(0.3, function()
							V.handPos = nil
							tweenPivot(lever, CFrame.new(-1.75, 5.3, -2.0), 0.3, Enum.EasingStyle.Bounce)
						end)
						sound("flush")
						local swirl = {}
						for k = 1, 5 do
							local s = ell(Vector3.new(0.7, 0.05, 0.18), CFrame.new(BOWL), Color3.fromRGB(240, 250, 255), SMOOTH)
							s.CanQuery = false
							swirl[k] = s
						end
						local t0 = os.clock()
						local c
						c = every(function()
							local t = os.clock() - t0
							local k = math.min(t / 1.4, 1)
							water.Color = water.Color:Lerp(Color3.fromRGB(110, 180, 235), 0.08)
							for i, s in ipairs(swirl) do
								local a = t * 9 + i * 1.25
								local r = (1 - k) * 0.9 + 0.05
								s.CFrame = CFrame.new(BOWL + Vector3.new(math.cos(a) * r * 0.85, 0.02, math.sin(a) * r * 1.1)) * CFrame.Angles(0, -a, 0)
								s.Transparency = k
							end
							if k >= 1 then
								c:Disconnect()
								for _, s in ipairs(swirl) do s:Destroy() end
								nice(BOWL, "Whoosh!")
								next()
							end
						end)
					end
				end,
			},
			{
				name = "Fresh Roll",
				hint = "Put a new toilet roll on the holder",
				run = function(next)
					tw(tube, 0.4, { CFrame = tube.CFrame - Vector3.new(0, 3.2, -0.4), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					local roll = model("Roll")
					cylX(1.1, 1.2, CFrame.new(), Color3.fromRGB(252, 252, 250), FABRIC, roll)
					cylX(1.12, 0.45, CFrame.new(), Color3.fromRGB(190, 150, 104), SMOOTH, roll)
					done(roll)
					roll:PivotTo(CFrame.new(3.0, 0.6, 1.6)) -- on the floor, in view (the tank top is above the frame)
					dragStage(roll, Vector3.new(0, 0, HOLD.Z + 0.1), Vector3.zAxis, HOLD, 1.1, { mark = 1.6 }, function()
						tweenPivot(roll, CFrame.new(HOLD), 0.2, Enum.EasingStyle.Back)
						-- the hotel fold: a neat little point on the end
						task.delay(0.2, function()
							if not V then return end
							local tip = part(Vector3.new(0.9, 0.04, 0.7), CFrame.new(HOLD + Vector3.new(0, -0.3, 0.6)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(252, 252, 250), FABRIC)
							tip.CanQuery = false
						end)
						sound("place")
						nice(HOLD, "Hotel fold!", T.sun)
						next()
					end)
				end,
			},
		})
	end

	---------------------------------------------------------------- CheckIn: match the booking, pick the key, encode it, hand it over
	local function keyCard(col, label)
		local m = model("Card")
		part(Vector3.new(1.0, 1.5, 0.06), CFrame.new(), col, SMOOTH, m)
		part(Vector3.new(1.02, 0.3, 0.07), CFrame.new(0, 0.45, 0), Color3.fromRGB(250, 250, 250), SMOOTH, m)
		part(Vector3.new(0.7, 0.12, 0.08), CFrame.new(0, -0.5, 0), Color3.fromRGB(40, 40, 44), SMOOTH, m)
		ell(Vector3.new(0.32, 0.32, 0.08), CFrame.new(0, 0, 0), BRASS, METAL, m)
		done(m)
		return m
	end

	G3.CheckIn = function()
		local d = S.data or {}
		local guest = d.guest or "Guest"
		local roomId = tostring(d.room or "101")
		local nights = d.nights or 2
		local camCF = CFrame.lookAt(Vector3.new(0, 9.8, 10.0), Vector3.new(0, 1.7, -1.4))
		local bell = deskSet(camCF)
		bell:PivotTo(CFrame.new(-1.0, 0, -3.8))
		local g = deskGuest(guest, 1.0, -5.8)
		-- the computer
		local monCF = CFrame.new(-4.4, 3.6, -2.7) * V.cam.CFrame.Rotation
		cyl(0.15, 1.8, CFrame.new(-4.4, 0.08, -2.9), Color3.fromRGB(47, 48, 50), METAL).CanQuery = false
		part(Vector3.new(0.35, 1.8, 0.3), CFrame.new(-4.4, 0.95, -3.0), Color3.fromRGB(47, 48, 50), METAL).CanQuery = false
		part(Vector3.new(7.4, 4.8, 0.35), monCF, Color3.fromRGB(37, 38, 40)).CanQuery = false
		local glassCF = monCF * CFrame.new(0, 0, 0.19)
		part(Vector3.new(7.0, 4.4, 0.04), glassCF, Color3.fromRGB(16, 28, 40)).CanQuery = false
		part(Vector3.new(3.8, 0.15, 1.3), CFrame.new(-4.6, 0.08, -0.4), Color3.fromRGB(54, 55, 58)).CanQuery = false
		-- the key rack and the encoder
		local rackCF = CFrame.new(5.6, 3.2, -3.4) * V.cam.CFrame.Rotation
		part(Vector3.new(4.4, 3.6, 0.2), rackCF, Color3.fromRGB(96, 62, 40), WOODM).CanQuery = false
		local ENC = Vector3.new(2.6, 0, 1.4)
		part(Vector3.new(1.8, 1.2, 1.4), CFrame.new(ENC + Vector3.new(0, 0.6, 0)), Color3.fromRGB(46, 48, 54), SMOOTH).CanQuery = false
		part(Vector3.new(1.3, 0.05, 0.16), CFrame.new(ENC + Vector3.new(0, 1.22, 0)), Color3.fromRGB(10, 10, 12), SMOOTH).CanQuery = false
		local led = ball(0.3, CFrame.new(ENC + Vector3.new(0.6, 0.85, 0.71)), Color3.fromRGB(220, 60, 60), NEON)
		led.CanQuery = false
		local card -- the chosen key card

		stages({
			{
				name = "Find the Booking",
				hint = guest .. " has arrived. Find their booking!",
				run = function(next)
					local bub = speech(g.head + Vector3.new(0, 1.2, 0), "Hi! " .. guest .. ", " .. nights .. " night" .. (nights == 1 and "" or "s") .. ".")
					local sa, ss = overArea(glassCF, 7.0, 4.4)
					local screen = box({ Position = UDim2.fromOffset(sa.X + 3, sa.Y + 3), Size = UDim2.fromOffset(ss.X - 6, ss.Y - 6), BackgroundColor3 = Color3.fromRGB(22, 40, 58), ZIndex = 6 })
					UI.corner(screen, 6)
					UI.grad(screen, Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 186, 230), 90)
					text(screen, "TODAY'S ARRIVALS", 11, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(120, 200, 255), Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(200, 13), TextXAlignment = LEFT, ZIndex = 7 })
					-- the list: other guests, and one with the same name but the wrong stay
					local rows = {}
					for _, nm in ipairs(d.names or { "Emily", "James", "Ava", "Leo" }) do
						if nm ~= guest and #rows < 3 then table.insert(rows, { name = nm, n = rng:NextInteger(1, 5) }) end
					end
					table.insert(rows, { name = guest, n = nights, right = true })
					table.insert(rows, { name = guest, n = nights == 1 and 3 or nights - 1 })
					shuffle(rows)
					local top = 22
					local rh = math.floor((ss.Y - 6 - top - 4) / #rows) - 2
					for i, r in ipairs(rows) do
						local y = top + (i - 1) * (rh + 2)
						local row = new("Frame", { Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, rh), BackgroundColor3 = Color3.fromRGB(40, 66, 92), ZIndex = 7, Parent = screen })
						UI.corner(row, 5)
						text(row, r.name, math.min(16, rh - 4), { FontFace = UI.F.black, TextColor3 = T.white, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = LEFT, ZIndex = 8 })
						text(row, r.n .. (r.n == 1 and " night" or " nights"), math.min(14, rh - 5), { FontFace = UI.F.bold, TextColor3 = Color3.fromRGB(170, 210, 240), Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
						r.frame = row
						r.c = Vector2.new(sa.X + 3 + 6 + (ss.X - 18) / 2, sa.Y + 3 + y + rh / 2)
						r.s = Vector2.new(ss.X - 18, rh)
					end
					S.onMove = function(p)
						for _, r in ipairs(rows) do r.frame.BackgroundColor3 = hitRect(p, r.c, r.s) and Color3.fromRGB(60, 110, 160) or Color3.fromRGB(40, 66, 92) end
					end
					S.onDown = function(p)
						for _, r in ipairs(rows) do
							if hitRect(p, r.c, r.s) then
								if r.right then
									S.onDown, S.onMove = nil, nil
									r.frame.BackgroundColor3 = T.green
									sound("click")
									floatText(r.c, "Found it!", T.green)
									task.delay(0.5, function()
										screen:Destroy()
										bub:Destroy()
									end)
									next()
								else
									shake(r.frame)
									oops(V.cam.CFrame.Position + V.cam.CFrame.LookVector * 10, r.name == guest and "Wrong stay length!" or "Wrong guest!")
								end
								return
							end
						end
					end
				end,
			},
			{
				name = "Grab the Key",
				hint = "Take the key card for room " .. roomId,
				run = function(next)
					local labels = {}
					for _, k in ipairs(d.keys or { "101", "102", "103", "104" }) do
						if tostring(k) ~= roomId and #labels < 5 then table.insert(labels, tostring(k)) end
					end
					table.insert(labels, roomId)
					shuffle(labels)
					local cards, owner = {}, {}
					local cols = { Color3.fromRGB(46, 120, 226), Color3.fromRGB(220, 70, 90), Color3.fromRGB(60, 170, 110), Color3.fromRGB(240, 170, 40), Color3.fromRGB(140, 90, 210), Color3.fromRGB(40, 170, 180) }
					for i, lab in ipairs(labels) do
						local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
						local cf = rackCF * CFrame.new(-1.35 + col * 1.35, 0.85 - row * 1.75, 0.15)
						local m = keyCard(cols[(i - 1) % #cols + 1], lab)
						m:PivotTo(cf)
						setQuery(m, true)
						cylZ(0.3, 0.14, rackCF * CFrame.new(-1.35 + col * 1.35, 1.65 - row * 1.75, 0.1), BRASS, METAL).CanQuery = false
						local a = toArea((cf * CFrame.new(0, 0.45, 0.05)).Position)
						local tagL = new("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(40, 14), BackgroundTransparency = 1,
							Text = lab, TextSize = 13, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(24, 30, 44), ZIndex = 7, Parent = S.area,
						})
						local c = { m = m, lab = lab, tag = tagL }
						table.insert(cards, c)
						for _, p in ipairs(partsOf(m)) do owner[p] = c end
					end
					local list = {}
					for p in pairs(owner) do table.insert(list, p) end
					S.onDown = function(p)
						local hit = pick(p, list)
						local c = hit and owner[hit.Instance]
						if not c then return end
						if c.lab ~= roomId then
							oops(c.m:GetPivot().Position, "That's room " .. c.lab .. "!")
							return
						end
						S.onDown = nil
						card = c.m
						for _, o in ipairs(cards) do o.tag:Destroy() end
						sound("select")
						tweenPivot(card, CFrame.new(ENC + Vector3.new(0, 2.0, 0)), 0.35, Enum.EasingStyle.Back)
						nice(card:GetPivot().Position, "Room " .. roomId .. "!")
						next()
					end
				end,
			},
			{
				name = "Encode the Key",
				hint = "Swipe the card down through the slot. Not too fast!",
				run = function(next, progress)
					local TOPY, BOTY = 2.0, 0.9
					local grabbing, tStart, y = false, nil, TOPY
					local band = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = S.area })
					local function place(yy)
						y = math.clamp(yy, BOTY, TOPY)
						card:PivotTo(CFrame.new(ENC.X, y, ENC.Z))
						V.handPos = Vector3.new(ENC.X, y + 0.6, ENC.Z + 0.1)
					end
					S.onDown = function(p)
						if not pick(p, partsOf(card)) then return end
						grabbing, tStart = true, nil
					end
					S.onMove = function(p)
						if not grabbing then return end
						local hit = onPlane(p, ENC, Vector3.zAxis)
						if not hit then return end
						place(math.min(hit.Y, y + 0.05))
						if not tStart and y < TOPY - 0.12 then tStart = os.clock() end
						progress((TOPY - y) / (TOPY - BOTY))
						if y <= BOTY + 0.02 then
							grabbing = false
							local took = tStart and os.clock() - tStart or 0
							if took < 0.16 then
								nope(ENC + Vector3.new(0, 2, 0), "Too fast!")
								led.Color = Color3.fromRGB(220, 60, 60)
								place(TOPY)
								V.handPos = nil
							elseif took > 1.1 then
								nope(ENC + Vector3.new(0, 2, 0), "Too slow!")
								place(TOPY)
								V.handPos = nil
							else
								S.onDown, S.onMove, S.onUp = nil, nil, nil
								led.Color = Color3.fromRGB(60, 230, 110)
								sound("register")
								nice(ENC + Vector3.new(0, 2, 0), took < 0.6 and "Beep! Perfect swipe" or "Beep!", T.green)
								V.handPos = nil
								band:Destroy()
								tweenPivot(card, CFrame.new(ENC + Vector3.new(-1.2, 0.3, 0.6)) * CFrame.Angles(math.rad(-90), 0, 0), 0.3)
								next()
							end
						end
					end
					S.onUp = function()
						if grabbing then
							grabbing = false
							place(TOPY)
							V.handPos = nil
						end
					end
				end,
			},
			{
				name = "Hand It Over",
				hint = "Give " .. guest .. " their key",
				run = function(next)
					local target = Vector3.new(1.0, 0.4, -4.4)
					dragStage(card, Vector3.new(0, 0.4, 0), UP, target, 1.5, { mark = 2.0, rot = CFrame.Angles(math.rad(-90), 0, 0) }, function()
						arc(card, CFrame.new(g.head - Vector3.new(0, 1.5, -0.6)), 0.3, 1, function()
							card:Destroy()
							g.hop()
							sound("bell")
							speech(g.head + Vector3.new(0, 1.2, 0), "Thank you!")
							next()
						end)
					end)
				end,
			},
		})
	end

	---------------------------------------------------------------- CheckOut: take the cash, count the change, tear the receipt
	local NOTE_COLS = { [1] = Color3.fromRGB(150, 196, 140), [5] = Color3.fromRGB(110, 160, 220), [10] = Color3.fromRGB(240, 160, 70), [20] = Color3.fromRGB(170, 120, 220) }
	local function note(v)
		local m = model("Note")
		part(Vector3.new(1.6, 0.04, 0.8), CFrame.new(), NOTE_COLS[v], SMOOTH, m)
		ell(Vector3.new(0.5, 0.05, 0.5), CFrame.new(0, 0.01, 0), NOTE_COLS[v]:Lerp(Color3.new(1, 1, 1), 0.45), SMOOTH, m)
		done(m)
		setQuery(m, false)
		return m
	end

	G3.CheckOut = function()
		local d = S.data or {}
		local bill = d.bill or 60
		local paid = d.paid or 80
		local change = paid - bill
		local bell = deskSet(CFrame.lookAt(Vector3.new(0.4, 11, 8.6), Vector3.new(0.4, 0.2, -0.8)))
		bell:PivotTo(CFrame.new(-6.4, 0, 2.6))
		local g = deskGuest(d.guest or "Guest", 0.6, -6.0)
		-- the till: a body, a screen showing the bill and a drawer that slides out toward us
		local TILL = Vector3.new(-4.0, 0, -1.6)
		part(Vector3.new(4.4, 1.6, 3.0), CFrame.new(TILL + Vector3.new(0, 0.8, 0)), Color3.fromRGB(60, 62, 70), SMOOTH).CanQuery = false
		local scrCF = CFrame.new(TILL + Vector3.new(0, 2.6, -0.6)) * CFrame.Angles(math.rad(-25), 0, 0)
		part(Vector3.new(2.4, 1.3, 0.2), scrCF, Color3.fromRGB(30, 32, 36), SMOOTH).CanQuery = false
		tag3((scrCF * CFrame.new(0, 0, 0.15)).Position, "$" .. bill, T.green, 18, 70)
		local drawer = model("Drawer")
		part(Vector3.new(4.2, 0.6, 2.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(80, 82, 90), SMOOTH, drawer)
		local DEN = { 20, 10, 5, 1 }
		local slots = {}
		for i, v in ipairs(DEN) do
			local x = -1.55 + (i - 1) * 1.03
			part(Vector3.new(0.95, 0.12, 2.3), CFrame.new(x, 0.62, 0), Color3.fromRGB(46, 48, 54), SMOOTH, drawer)
			for k = 0, 3 do
				part(Vector3.new(0.85, 0.04, 1.8), CFrame.new(x, 0.7 + k * 0.05, 0.1), NOTE_COLS[v], SMOOTH, drawer)
			end
			slots[i] = { v = v, x = x }
		end
		done(drawer)
		local DCLOSED, DOPEN = CFrame.new(TILL + Vector3.new(0, 0.1, 0.4)), CFrame.new(TILL + Vector3.new(0, 0.1, 2.9))
		drawer:PivotTo(DCLOSED)
		local TRAY = Vector3.new(2.4, 0.1, 1.2)
		part(Vector3.new(3.0, 0.15, 2.0), CFrame.new(TRAY), Color3.fromRGB(176, 140, 90), WOODM).CanQuery = false
		local stack = {}

		stages({
			{
				name = "Take the Payment",
				hint = "Take the guest's cash and put it in the till",
				run = function(next)
					local cash = model("Cash")
					local v = paid >= 20 and 20 or 10
					for k = 0, math.max(math.floor(paid / v) - 1, 0) do
						local n = note(v)
						n:PivotTo(CFrame.new(rng:NextNumber(-0.15, 0.15), k * 0.06, rng:NextNumber(-0.1, 0.1)) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0))
						n.Parent = cash
					end
					done(cash)
					cash:PivotTo(CFrame.new(0.8, 0.1, -3.3))
					setQuery(cash, true)
					local lab = tag3(Vector3.new(0.8, 0.9, -3.3), "$" .. paid, T.green, 18, 70)
					S.onDown = function(p)
						if not pick(p, partsOf(cash)) then return end
						S.onDown = nil
						lab:Destroy()
						sound("register")
						tweenPivot(drawer, DOPEN, 0.3, Enum.EasingStyle.Back)
						arc(cash, CFrame.new(TILL + Vector3.new(0, 1.2, 2.9)), 0.4, 2.5, function()
							cash:Destroy()
							sound("coins")
							nice(TILL + Vector3.new(0, 1, 2.9), "Paid $" .. paid)
							next()
						end)
					end
				end,
			},
			{
				name = "Count the Change",
				hint = "Bill $" .. bill .. ", paid $" .. paid .. ". Give back $" .. change,
				run = function(next, progress)
					local sum = 0
					local ta = toArea(TRAY + Vector3.new(0, 0, 1.6))
					local readout = card2(ta + Vector2.new(0, 22), Vector2.new(170, 40), { ZIndex = 14 })
					local rl = text(readout, "", 20, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(24, 30, 44), Size = UDim2.fromScale(1, 1), ZIndex = 15 })
					rl.TextXAlignment = Enum.TextXAlignment.Center
					local function show()
						rl.Text = "$" .. sum .. " of $" .. change
						rl.TextColor3 = sum == change and T.greenDk or Color3.fromRGB(24, 30, 44)
						progress(sum / change)
					end
					show()
					local labels = {}
					for _, s in ipairs(slots) do
						local w = DOPEN * Vector3.new(s.x, 1.0, 1.4)
						table.insert(labels, tag3(w, "$" .. s.v, NOTE_COLS[s.v]:Lerp(Color3.new(0, 0, 0), 0.3), 16, 46))
					end
					setQuery(drawer, true)
					local dparts = partsOf(drawer)
					local trayHit = part(Vector3.new(3.0, 1.2, 2.0), CFrame.new(TRAY + Vector3.new(0, 0.5, 0)), Color3.new(1, 1, 1), SMOOTH)
					trayHit.Transparency = 1
					local busy = false
					S.onDown = function(p)
						if busy then return end
						local hit = pick(p, dparts)
						if hit then
							local lx = DOPEN:PointToObjectSpace(hit.Position).X
							local s
							for _, ss in ipairs(slots) do if math.abs(ss.x - lx) < 0.52 then s = ss end end
							if not s then return end
							local n = note(s.v)
							n:PivotTo(DOPEN * CFrame.new(s.x, 1, 0))
							local top = CFrame.new(TRAY + Vector3.new(rng:NextNumber(-0.3, 0.3), 0.12 + #stack * 0.05, rng:NextNumber(-0.2, 0.2))) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
							table.insert(stack, { m = n, v = s.v })
							sum += s.v
							busy = true
							sound("coins")
							arc(n, top, 0.22, 1.2, function()
								busy = false
								if sum > change then
									oops(TRAY, "Too much!")
									local last = table.remove(stack)
									sum -= last.v
									arc(last.m, DOPEN * CFrame.new(0, 1.2, 0), 0.25, 1.2, function() last.m:Destroy() end)
								elseif sum == change then
									S.onDown = nil
									for _, l in ipairs(labels) do l:Destroy() end
									readout:Destroy()
									trayHit:Destroy()
									tweenPivot(drawer, DCLOSED, 0.25)
									nice(TRAY, "Exact change!", T.sun)
									next()
								end
								show()
							end)
							return
						end
						if pick(p, { trayHit }) and #stack > 0 then
							local last = table.remove(stack)
							sum -= last.v
							busy = true
							arc(last.m, DOPEN * CFrame.new(0, 1.2, 0), 0.25, 1.2, function()
								last.m:Destroy()
								busy = false
							end)
							sound("select")
							show()
						end
					end
				end,
			},
			{
				name = "Tear the Receipt",
				hint = "Swipe across the receipt to tear it off",
				run = function(next, progress)
					local PR = Vector3.new(4.8, 0, -1.2)
					part(Vector3.new(2.6, 1.3, 2.0), CFrame.new(PR + Vector3.new(0, 0.65, 0)), Color3.fromRGB(220, 222, 228), SMOOTH).CanQuery = false
					part(Vector3.new(2.0, 0.05, 0.2), CFrame.new(PR + Vector3.new(0, 1.31, 0.2)), Color3.fromRGB(30, 30, 34), SMOOTH).CanQuery = false
					local rot = V.cam.CFrame.Rotation
					local paper = part(Vector3.new(1.9, 0.05, 0.04), CFrame.new(PR + Vector3.new(0, 1.35, 0.2)) * rot, Color3.fromRGB(252, 250, 244), SMOOTH)
					paper.CanQuery = false
					tw(paper, 0.7, { Size = Vector3.new(1.9, 3.0, 0.04), CFrame = CFrame.new(PR + Vector3.new(0, 2.85, 0.2)) * rot })
					sound("register")
					later(0.75, function()
						local a, s = overArea(CFrame.new(PR + Vector3.new(0, 2.85, 0.2)) * rot, 1.9, 3.0)
						local slip = box({ Position = UDim2.fromOffset(a.X, a.Y), Size = UDim2.fromOffset(s.X, s.Y), BackgroundTransparency = 1, ZIndex = 8 })
						local lines = { "OVERBOOKED", "ROOM " .. tostring(d.room or "-"), "BILL  $" .. bill, "PAID  $" .. paid, "CHANGE $" .. change, "THANK YOU!" }
						for i, l in ipairs(lines) do
							text(slip, l, math.max(9, math.floor(s.Y / 11)), { FontFace = i == 1 and UI.F.black or UI.F.bold, TextColor3 = Color3.fromRGB(40, 40, 50), Position = UDim2.fromOffset(0, 4 + (i - 1) * s.Y / 7.5), Size = UDim2.new(1, 0, 0, s.Y / 8), ZIndex = 9 })
						end
						local tearY = toArea(PR + Vector3.new(0, 1.5, 0.2)).Y
						local guide = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X + s.X / 2, tearY), Size = UDim2.fromOffset(s.X + 30, 4), BackgroundColor3 = T.sun, ZIndex = 9, Parent = S.area })
						UI.corner(guide, 2)
						local x0, x1, tracking = nil, nil, false
						S.onDown = function(p)
							if math.abs(p.Y - tearY) > 70 or p.X < a.X - 50 or p.X > a.X + s.X + 50 then return end
							tracking, x0, x1 = true, p.X, p.X
						end
						S.onMove = function(p)
							if not tracking then return end
							x0, x1 = math.min(x0, p.X), math.max(x1, p.X)
							V.handPos = onPlane(p, PR + Vector3.new(0, 1.5, 0.3), Vector3.zAxis)
							local k = (x1 - x0) / (s.X + 10)
							progress(k)
							if k >= 1 then
								tracking = false
								S.onDown, S.onMove, S.onUp = nil, nil, nil
								V.handPos = nil
								guide:Destroy()
								slip:Destroy()
								sound("sheets")
								tw(paper, 0.5, { CFrame = paper.CFrame * CFrame.new(0, 1.2, 0.4) * CFrame.Angles(0.3, 0.4, 0.5), Transparency = 1 })
								g.hop()
								speech(g.head + Vector3.new(0, 1.2, 0), "Great stay, thanks!")
								nice(PR + Vector3.new(0, 2.5, 0), "Riiip!")
								next()
							end
						end
						S.onUp = function()
							tracking = false
							V.handPos = nil
						end
					end)
				end,
			},
		})
	end

	---------------------------------------------------------------- Cook: pick, chop, cook in the zone, plate, ring the bell
	G3.Cook = function()
		local d = S.data or {}
		local items = d.items or { "bun", "patty", "cheese" }
		local panKind = PAN3[d.pan or ""] and d.pan or "patty"
		local stir = panKind == "sauce"
		local shelf = shuffle(table.clone(d.shelf or { "bun", "patty", "cheese", "egg", "tomato", "basil" }))
		scene({ cam = CFrame.lookAt(Vector3.new(0, 10.5, 9.6), Vector3.new(0, 0.9, -0.9)), fov = 42, bg = Color3.fromRGB(50, 46, 44), ambient = Color3.fromRGB(160, 152, 148), armDepth = 8 })
		roomSet({ wallZ = -5.5, wall = Color3.fromRGB(236, 238, 236), floorY = -4 })
		grout(CFrame.new(0, 3, -5.49), 40, 16, 0.9, Color3.fromRGB(200, 206, 210))
		part(Vector3.new(24, 1, 10), CFrame.new(0, -0.5, -0.8), Color3.fromRGB(236, 232, 226), Enum.Material.Marble).CanQuery = false
		part(Vector3.new(24, 0.2, 0.2), CFrame.new(0, -0.05, 4.2), CHROME, METAL).CanQuery = false
		-- a rail of utensils and a hood light along the back
		part(Vector3.new(14, 0.15, 0.15), CFrame.new(0, 4.6, -5.3), CHROME, METAL).CanQuery = false
		for i = -3, 3 do
			part(Vector3.new(0.12, 1.6, 0.06), CFrame.new(i * 1.8, 3.8, -5.25), CHROME, METAL).CanQuery = false
			ell(Vector3.new(0.5, 0.6, 0.08), CFrame.new(i * 1.8, 2.9, -5.24), CHROME, METAL).CanQuery = false
		end
		-- the pantry: six bowls along the back
		local bowls, owner, list = {}, {}, {}
		for i, id in ipairs(shelf) do
			local x = -5.6 + (i - 1) * 2.24
			cyl(0.5, 2.0, CFrame.new(x, 0.25, -3.5), Color3.fromRGB(250, 250, 248), SMOOTH).CanQuery = false
			cyl(0.52, 1.7, CFrame.new(x, 0.26, -3.5), Color3.fromRGB(224, 228, 232), SMOOTH).CanQuery = false
			local m = ingredient(id)
			m:ScaleTo(1.3)
			m:PivotTo(CFrame.new(x, 0.5, -3.5) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0))
			local b = { m = m, id = id, x = x }
			table.insert(bowls, b)
			for _, p in ipairs(partsOf(m)) do owner[p] = b table.insert(list, p) end
		end
		-- board, stove + pan, plate, bell
		local BOARD = Vector3.new(-3.8, 0.13, 1.2)
		part(Vector3.new(5.6, 0.25, 3.0), CFrame.new(BOARD), Color3.fromRGB(206, 156, 100), WOODM).CanQuery = false
		local STOVE = Vector3.new(4.4, 0.15, 0.4)
		part(Vector3.new(5.0, 0.3, 3.8), CFrame.new(STOVE), Color3.fromRGB(29, 29, 30), GLASSM).CanQuery = false
		local burner = cyl(0.04, 2.9, CFrame.new(STOVE + Vector3.new(0, 0.17, 0)), Color3.fromRGB(70, 30, 26), NEON)
		burner.CanQuery = false
		local panM = model("Pan")
		cyl(0.42, 2.7, CFrame.new(0, 0.55, 0), Color3.fromRGB(55, 56, 58), METAL, panM)
		cyl(0.06, 2.3, CFrame.new(0, 0.77, 0), Color3.fromRGB(81, 82, 84), METAL, panM)
		part(Vector3.new(2.3, 0.2, 0.36), CFrame.new(2.3, 0.62, 0), Color3.fromRGB(40, 36, 34), SMOOTH, panM)
		local food = cyl(0.26, 1.9, CFrame.new(0, 0.85, 0), PAN3[panKind][1], SMOOTH, panM)
		food.Transparency = 1
		done(panM)
		setQuery(panM, false)
		local PANHOME = CFrame.new(STOVE)
		panM:PivotTo(PANHOME)
		local PLATE = Vector3.new(0.4, 0.08, 2.5)
		cyl(0.14, 2.7, CFrame.new(PLATE), Color3.fromRGB(252, 252, 250), SMOOTH).CanQuery = false
		cyl(0.1, 3.0, CFrame.new(PLATE - Vector3.new(0, 0.03, 0)), Color3.fromRGB(226, 200, 140), METAL).CanQuery = false
		local bell = model("Bell")
		cyl(0.22, 1.4, CFrame.new(0, 0.11, 0), Color3.fromRGB(60, 40, 30), WOODM, bell)
		ell(Vector3.new(1.15, 0.9, 1.15), CFrame.new(0, 0.38, 0), BRASS, METAL, bell)
		ball(0.24, CFrame.new(0, 0.88, 0), BRASS, METAL, bell)
		done(bell)
		bell:PivotTo(CFrame.new(6.6, 0, 2.9))
		-- the order ticket
		local ticket = card2(Vector2.new(70, 180), Vector2.new(124, 128), { BackgroundColor3 = Color3.fromRGB(255, 252, 236), Rotation = -4 })
		text(ticket, "ORDER", 12, { FontFace = UI.F.black, TextColor3 = T.red, Position = UDim2.fromOffset(0, 6), ZIndex = 13 }).TextXAlignment = Enum.TextXAlignment.Center
		text(ticket, d.dishName or "Cheeseburger", 15, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(24, 30, 44), Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 0, 20), TextScaled = true, ZIndex = 13 })
		local ticks = {}
		for i, id in ipairs(items) do
			ticks[id] = text(ticket, "○ " .. id:sub(1, 1):upper() .. id:sub(2), 14, { FontFace = UI.F.bold, TextColor3 = Color3.fromRGB(60, 64, 76), Position = UDim2.fromOffset(12, 48 + (i - 1) * 22), Size = UDim2.new(1, -16, 0, 20), TextXAlignment = LEFT, ZIndex = 13 })
		end
		local picked = {}

		stages({
			{
				name = "Grab the Ingredients",
				hint = "Pick the three things on the order",
				run = function(next, progress)
					S.onDown = function(p)
						local hit = pick(p, list)
						local b = hit and owner[hit.Instance]
						if not b or b.taken then return end
						if not table.find(items, b.id) then
							oops(b.m:GetPivot().Position, "Not in a " .. (d.dishName or "dish") .. "!")
							return
						end
						b.taken = true
						table.insert(picked, b)
						ticks[b.id].Text = "✔ " .. b.id:sub(1, 1):upper() .. b.id:sub(2)
						ticks[b.id].TextColor3 = T.greenDk
						sound("select")
						local slot = BOARD + Vector3.new(-1.6 + (#picked - 1) * 1.6, 0.13, 0)
						arc(b.m, CFrame.new(slot), 0.35, 2.2)
						progress(#picked / #items)
						if #picked == #items then next() end
					end
				end,
			},
			{
				name = "Chop It Up",
				hint = "Line the knife up with each dashed line and click to chop",
				run = function(next, progress)
					local guides = {}
					for _, b in ipairs(picked) do
						local c = b.m:GetPivot().Position
						for _, dx in ipairs({ -0.32, 0.32 }) do
							local gd = part(Vector3.new(0.06, 0.05, 1.9), CFrame.new(c.X + dx, 1.25, c.Z), T.red, NEON)
							gd.CanQuery = false
							table.insert(guides, { p = gd, x = c.X + dx, b = b })
						end
					end
					local knife = model("Knife")
					part(Vector3.new(0.06, 0.8, 2.4), CFrame.new(0, 0.4, 0), CHROME, METAL, knife)
					part(Vector3.new(0.2, 0.36, 1.2), CFrame.new(0, 0.62, 1.75), Color3.fromRGB(40, 36, 34), SMOOTH, knife)
					for k = 0, 2 do ball(0.08, CFrame.new(0.1, 0.62, 1.4 + k * 0.32), BRASS, METAL, knife) end
					done(knife)
					setQuery(knife, false)
					local kx, chopT = BOARD.X, -1
					V.hand, V.handOff = knife, Vector3.new(0, 0.62, 1.9)
					every(function(dt)
						if not knife.Parent then return end
						local hit = onPlane(ptr(), Vector3.new(0, 1.0, BOARD.Z), UP)
						if hit then kx = kx + (math.clamp(hit.X, BOARD.X - 2.6, BOARD.X + 2.6) - kx) * (1 - math.exp(-dt * 25)) end
						local k = math.clamp((os.clock() - chopT) / 0.14, 0, 1)
						local y = 1.0 - math.sin(k * math.pi) * 0.85
						knife:PivotTo(CFrame.new(kx, y, BOARD.Z - 0.2))
						for _, gd in ipairs(guides) do
							if gd.p.Parent then gd.p.Color = math.abs(gd.x - kx) < 0.16 and T.green or T.red end
						end
					end)
					local cut = 0
					S.onDown = function()
						chopT = os.clock()
						local best, bd = nil, 0.2
						for _, gd in ipairs(guides) do
							if gd.p.Parent and math.abs(gd.x - kx) < bd then best, bd = gd, math.abs(gd.x - kx) end
						end
						if not best then
							sound("knock")
							floatText(toArea(Vector3.new(kx, 1.2, BOARD.Z)), "Line it up!", T.orange)
							return
						end
						best.p:Destroy()
						cut += 1
						-- the piece past the cut slides away a little
						local c = best.b.m:GetPivot().Position
						for _, pp in ipairs(partsOf(best.b.m)) do
							if (pp.Position.X - best.x) * (best.x - c.X) > 0 then pp.CFrame += Vector3.new(best.x > c.X and 0.2 or -0.2, 0, 0) end
						end
						sound("chop")
						burst(toArea(Vector3.new(best.x, 0.6, BOARD.Z)), Color3.fromRGB(255, 255, 255), 5, 40)
						progress(cut / #guides)
						if cut == #guides then
							S.onDown = nil
							later(0.25, function()
								V.hand = nil
								knife:Destroy()
								for i, b in ipairs(picked) do
									arc(b.m, CFrame.new(STOVE + Vector3.new(0, 1.0, 0)), 0.3 + i * 0.08, 2, function() b.m:Destroy() end)
								end
								task.delay(0.6, function()
									food.Transparency = 0
									sound("sizzle")
									next()
								end)
							end)
						end
					end
				end,
			},
			{
				name = stir and "Simmer the Sauce" or "Cook It",
				hint = "Hold to turn up the heat. Keep the needle in the green!",
				pause = 0.6,
				run = function(next, progress)
					local setHeat, heatF = meter(toArea(STOVE + Vector3.new(3.3, 1, 0)), "HEAT", 0.48, 0.78)
					local doneBar = card2(toArea(STOVE + Vector3.new(-1.0, 0, 2.4)), Vector2.new(150, 22), { BackgroundColor3 = Color3.fromRGB(56, 64, 84) })
					local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.sun, ZIndex = 13, Parent = doneBar })
					UI.corner(fill, 10)
					local heat, doneK, hot = 0.2, 0, 0
					local needTurn, turned = false, false
					local tw2 = nil
					local raw, cooked, burnt = PAN3[panKind][1], PAN3[panKind][2], PAN3[panKind][3]
					local nextSfx, nextPuff = 0, 0
					local lastA, acc = nil, 0
					local panC = toArea(STOVE + Vector3.new(0, 0.9, 0))
					local flipY
					S.onDown = function(p)
						if needTurn and not stir then flipY = p.Y end
					end
					S.onMove = function(p)
						if not needTurn then return end
						if stir then
							if not S.held then lastA = nil return end
							local dd = p - panC
							local a = math.atan2(dd.Y, dd.X)
							if lastA then
								local da = a - lastA
								if da > math.pi then da -= 2 * math.pi elseif da < -math.pi then da += 2 * math.pi end
								acc += math.abs(da)
								food.CFrame = food.CFrame * CFrame.Angles(da, 0, 0)
								if acc > math.pi * 4 then turned = true end
							end
							lastA = a
						elseif flipY and flipY - p.Y > 70 then
							flipY = nil
							turned = true
							local cf = food.CFrame
							tw(food, 0.18, { CFrame = cf + Vector3.new(0, 1.6, 0) })
							task.delay(0.18, function() if food.Parent then tw(food, 0.22, { CFrame = cf * CFrame.Angles(math.pi, 0, 0) }, Enum.EasingStyle.Bounce) end end)
							sound("flip")
						end
						if turned then
							needTurn = false
							if tw2 then tw2:Destroy() tw2 = nil end
							nice(STOVE + Vector3.new(0, 2, 0), stir and "Well stirred!" or "Nice flip!", T.sun)
							say("Hold to turn up the heat. Keep the needle in the green!")
						end
					end
					every(function(dt)
						if not food.Parent or doneK >= 1 then return end
						heat = math.clamp(heat + (S.held and not needTurn and 0.5 or -0.38) * dt, 0, 1)
						local inZone = setHeat(heat)
						burner.Color = Color3.fromRGB(70, 30, 26):Lerp(Color3.fromRGB(255, 120, 40), heat)
						if needTurn then return end
						if inZone then
							doneK = math.min(doneK + dt / 6, 1)
							if os.clock() > nextSfx then nextSfx = os.clock() + 0.6 sound("sizzle") end
						end
						if heat > 0.78 then
							hot += dt
							if os.clock() > nextPuff then
								nextPuff = os.clock() + 0.12
								bubbles(panC + Vector2.new(rng:NextNumber(-20, 20), -10), 1)
							end
							if hot > 1.2 then
								hot = 0
								heat = 0.5
								food.Color = burnt
								task.delay(0.4, function() if food.Parent then food.Color = raw:Lerp(cooked, doneK) end end)
								oops(STOVE + Vector3.new(0, 1.5, 0), "It's burning!")
							end
						else
							hot = math.max(hot - dt, 0)
						end
						food.Color = raw:Lerp(cooked, doneK)
						fill.Size = UDim2.fromScale(doneK, 1)
						progress(doneK)
						-- halfway: flip it (or stir the sauce)
						if doneK >= 0.5 and not turned and not needTurn then
							needTurn = true
							say(stir and "Hold and stir in circles!" or "Flip it! Press and flick up")
							tw2 = new("TextLabel", {
								AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(panC.X, panC.Y - 70), Size = UDim2.fromOffset(150, 40), BackgroundTransparency = 1,
								Text = stir and "STIR!" or "FLIP! ⬆", TextSize = 34, FontFace = UI.F.black, TextColor3 = T.sun, ZIndex = 30, Parent = S.area,
							})
							UI.textStroke(tw2, 2, 0)
							UI.pop(tw2, 0.4, 0.3)
						end
						if doneK >= 1 then
							burner.Color = Color3.fromRGB(70, 30, 26)
							food.Color = cooked
							nice(STOVE + Vector3.new(0, 2, 0), "Cooked to perfection!", T.sun)
							task.delay(0.4, function()
								doneBar:Destroy()
								heatF:Destroy()
							end)
							next()
						end
					end)
				end,
			},
			{
				name = "Plate It Up",
				hint = "Carry the pan over to the plate",
				run = function(next)
					dragStage(panM, Vector3.new(0, 1.6, 0), UP, PLATE + Vector3.new(0, 1.6, 0), 2.0, { mark = 3.0, grip = Vector3.new(2.6, 0.62, 0) }, function()
						tweenPivot(panM, CFrame.new(PLATE + Vector3.new(1.4, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(40)), 0.2)
						task.delay(0.25, function()
							food:Destroy()
							local meal = dishModel(d.dish or "burger")
							meal:PivotTo(CFrame.new(PLATE + Vector3.new(0, 0.08, 0)))
							UI.pop(ticket, 0.8, 0.2)
							sound("place")
							nice(PLATE + Vector3.new(0, 1, 0), "Looks delicious!", T.sun)
							tweenPivot(panM, PANHOME, 0.35)
							next()
						end)
					end)
				end,
			},
			{
				name = "Order Up!",
				hint = "Ring the bell to send it out",
				run = function(next)
					local mk = marker(Vector3.new(6.6, 0.05, 2.9), 2.0, UP)
					setQuery(bell, true)
					S.onDown = function(p)
						if not pick(p, partsOf(bell)) then return end
						S.onDown = nil
						mk.destroy()
						V.handPos = Vector3.new(6.6, 1.0, 2.9)
						tweenPivot(bell, CFrame.new(6.6, -0.12, 2.9), 0.06)
						task.delay(0.08, function() tweenPivot(bell, CFrame.new(6.6, 0, 2.9), 0.25, Enum.EasingStyle.Bounce) end)
						task.delay(0.3, function() V.handPos = nil end)
						sound("bell")
						nice(Vector3.new(6.6, 1.5, 2.9), "Order up!", T.sun)
						next()
					end
				end,
			},
		})
	end

	---------------------------------------------------------------- Repair: the fuse box (sparks) or the leaking pipe (water)
	-- a bendy wire from a to b as a chain of short cylinders, sagging by `sag`
	local function wire(col, n)
		local segs = {}
		for k = 1, n or 8 do
			local s = cylX(1, 0.2, CFrame.new(), col, SMOOTH)
			s.CanQuery = false
			segs[k] = s
		end
		return function(a, b, sag)
			local mid = (a + b) / 2 - Vector3.new(0, sag or 0.6, -0.3)
			local prev = a
			for k = 1, #segs do
				local t = k / #segs
				local p = a:Lerp(mid, t):Lerp(mid:Lerp(b, t), t)
				local L = (p - prev).Magnitude
				if L > 0.001 then
					segs[k].Size = Vector3.new(L + 0.08, 0.2, 0.2)
					segs[k].CFrame = CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, math.rad(90), 0)
				end
				prev = p
			end
		end
	end
	-- a needle sweeps a gauge; click while it's in the green
	local function sweepStage(pos, label, finish, progress)
		local set, f = meter(pos, label, 0.42, 0.58, true)
		local t0 = os.clock()
		local v = 0
		every(function()
			if not f.Parent then return end
			v = (math.sin((os.clock() - t0) * 2.6) + 1) / 2
			set(v)
		end)
		S.onDown = function()
			if v >= 0.42 and v <= 0.58 then
				S.onDown = nil
				f:Destroy()
				progress(1)
				finish(math.abs(v - 0.5) < 0.04)
			else
				floatText(pos + Vector2.new(0, -40), "Not yet!", T.orange)
				sound("knock")
			end
		end
	end

	G3.Repair = function()
		local d = S.data or {}
		local water = d.kind == "water"
		scene({
			cam = CFrame.lookAt(Vector3.new(0, 4.8, 10.5), Vector3.new(0, 3.9, -1.5)), fov = 42, bg = Color3.fromRGB(44, 48, 54),
			ambient = Color3.fromRGB(140, 144, 150), light = Color3.fromRGB(250, 240, 226), armDepth = 7,
		})
		roomSet({ wallZ = -2.05, wall = water and Color3.fromRGB(226, 220, 206) or Color3.fromRGB(176, 186, 196), floor = Color3.fromRGB(110, 100, 92), floorMat = water and SMOOTH or Enum.Material.Concrete })
		-- a toolbox on the floor
		part(Vector3.new(2.6, 1.2, 1.4), CFrame.new(-5.6, 0.6, 1.2), Color3.fromRGB(210, 50, 50), METAL).CanQuery = false
		part(Vector3.new(1.6, 0.2, 0.2), CFrame.new(-5.6, 1.5, 1.2), Color3.fromRGB(40, 40, 44), METAL).CanQuery = false
		if water then
			---------------- the leaking pipe under the sink
			part(Vector3.new(12, 0.5, 4), CFrame.new(0, 7.6, -0.2), Color3.fromRGB(240, 238, 232), Enum.Material.Marble).CanQuery = false
			part(Vector3.new(12, 0.4, 3.6), CFrame.new(0, 0.2, -0.2), Color3.fromRGB(196, 170, 130), WOODM).CanQuery = false
			local PIPE = Color3.fromRGB(200, 206, 212)
			cyl(3.0, 0.5, CFrame.new(-2.6, 1.5, -1.0), PIPE, METAL).CanQuery = false
			cylX(5.2, 0.5, CFrame.new(0, 3.0, -1.0), PIPE, METAL).CanQuery = false
			cyl(4.6, 0.5, CFrame.new(2.6, 5.3, -1.0), PIPE, METAL).CanQuery = false
			local JOINT = Vector3.new(1.0, 3.0, -1.0)
			local VALVE = Vector3.new(-2.6, 3.0, -0.4)
			local valve = model("Valve")
			cylZ(0.25, 1.7, CFrame.new(), Color3.fromRGB(210, 40, 50), METAL, valve)
			cylZ(0.3, 1.1, CFrame.new(), Color3.fromRGB(44, 46, 50), METAL, valve)
			for k = 0, 3 do part(Vector3.new(1.7, 0.16, 0.16), CFrame.Angles(0, 0, k * math.pi / 4), Color3.fromRGB(210, 40, 50), METAL, valve) end
			ball(0.4, CFrame.new(0, 0, 0.2), CHROME, METAL, valve)
			done(valve)
			setQuery(valve, false)
			valve:PivotTo(CFrame.new(VALVE))
			local nut = model("Nut")
			cylX(0.6, 0.95, CFrame.new(), Color3.fromRGB(176, 180, 186), METAL, nut)
			for k = 0, 5 do part(Vector3.new(0.62, 0.08, 0.5), CFrame.Angles(k * math.pi / 3, 0, 0) * CFrame.new(0, 0.44, 0), Color3.fromRGB(150, 154, 160), METAL, nut) end
			done(nut)
			setQuery(nut, false)
			nut:PivotTo(CFrame.new(JOINT))
			local washer = cylX(0.14, 0.9, CFrame.new(JOINT - Vector3.new(0.4, 0, 0)), Color3.fromRGB(30, 30, 32), SMOOTH)
			local puddle = cyl(0.03, 3.2, CFrame.new(JOINT.X, 0.42, 0), Color3.fromRGB(150, 200, 240), SMOOTH)
			puddle.CanQuery, puddle.Transparency = false, 0.35
			local flow = 1
			local nextDrip = 0
			every(function()
				if flow <= 0 or os.clock() < nextDrip then return end
				nextDrip = os.clock() + 0.12 / flow
				local b = ball(0.18, CFrame.new(JOINT + Vector3.new(rng:NextNumber(-0.3, 0.3), -0.3, 0.2)), Color3.fromRGB(150, 200, 250), SMOOTH)
				b.CanQuery, b.Transparency = false, 0.2
				tw(b, 0.5, { Position = Vector3.new(b.Position.X, 0.5, b.Position.Z) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.5, function() b:Destroy() end)
			end)
			local function twistNut(back, next, progress)
				twistStage(nut:GetPivot().Position, 2, function(k, da)
					local x = back and (JOINT.X + 0.9 * (1 - k)) or (JOINT.X + 0.9 * k)
					nut:PivotTo(CFrame.new(x, JOINT.Y, JOINT.Z) * CFrame.Angles(k * 30, 0, 0))
					V.handPos = nut:GetPivot().Position + Vector3.new(0, 0.5, 0.3)
					progress(k)
					if math.random() < 0.15 then sound("turn") end
				end, function()
					V.handPos = nil
					next()
				end)
			end
			stages({
				{
					name = "Shut Off the Water",
					hint = "Grab the red valve and turn it round and round",
					run = function(next, progress)
						twistStage(VALVE, 3, function(k, da)
							valve:PivotTo(valve:GetPivot() * CFrame.Angles(0, 0, da))
							V.handPos = VALVE + Vector3.new(0.6, 0.6, 0.3)
							flow = 1 - k
							progress(k)
							if math.random() < 0.12 then sound("turn") end
						end, function()
							V.handPos = nil
							flow = 0
							nice(VALVE, "Water off!")
							next()
						end)
					end,
				},
				{
					name = "Undo the Nut",
					hint = "Circle round the nut to loosen it",
					run = function(next, progress)
						twistNut(false, function()
							tweenPivot(nut, CFrame.new(4.4, 1.0, 0.6), 0.35, Enum.EasingStyle.Back)
							sound("knock")
							next()
						end, progress)
					end,
				},
				{
					name = "Swap the Washer",
					hint = "Pull out the cracked washer...",
					run = function(next, progress)
						dragStage(washer, Vector3.new(0, 0, -0.6), Vector3.zAxis, JOINT, 1.8, { away = true }, function(pos)
							progress(0.5)
							arc(washer, CFrame.new(-5.6, 1.4, 1.2), 0.4, 2, function() washer:Destroy() end)
							sound("place")
							say("...and fit the new one on the pipe")
							local fresh = cylX(0.14, 0.9, CFrame.new(4.4, 1.0, 1.6), Color3.fromRGB(60, 130, 230), SMOOTH)
							dragStage(fresh, Vector3.new(0, 0, -0.6), Vector3.zAxis, JOINT - Vector3.new(0.4, 0, 0), 0.7, { mark = 1.2 }, function()
								tw(fresh, 0.15, { CFrame = CFrame.new(JOINT - Vector3.new(0.4, 0, 0)) })
								sound("place")
								nice(JOINT, "Snug fit!")
								next()
							end)
						end)
					end,
				},
				{
					name = "Tighten the Nut",
					hint = "Circle round the nut to tighten it",
					run = function(next, progress)
						tweenPivot(nut, CFrame.new(JOINT + Vector3.new(0.9, 0, 0)), 0.3, Enum.EasingStyle.Back)
						later(0.32, function() twistNut(true, next, progress) end)
					end,
				},
				{
					name = "Water Back On",
					hint = "Click when the pressure needle is in the green",
					run = function(next, progress)
						sweepStage(toArea(Vector3.new(0, 1.2, 0.5)), "PRESSURE", function(perfect)
							tweenPivot(valve, valve:GetPivot() * CFrame.Angles(0, 0, -2.5), 0.4)
							puddle:Destroy()
							nice(JOINT, perfect and "Perfect pressure!" or "No more leaks!", T.sun)
							sound("sparkle")
							next()
						end, progress)
					end,
				},
			})
			return
		end

		---------------- the fuse box (sparks)
		local BOX = Vector3.new(0, 4.2, -1.55)
		part(Vector3.new(6.6, 5.6, 0.9), CFrame.new(BOX), Color3.fromRGB(150, 156, 164), METAL).CanQuery = false
		part(Vector3.new(6.0, 5.0, 0.05), CFrame.new(BOX + Vector3.new(0, 0, 0.47)), Color3.fromRGB(56, 60, 66), SMOOTH).CanQuery = false
		local lamp = ball(0.5, CFrame.new(2.6, 6.4, -1.0), Color3.fromRGB(230, 50, 50), NEON)
		lamp.CanQuery = false
		-- the fuses (one blown)
		local FUSEY = 5.5
		local blownI = rng:NextInteger(1, 4)
		local fuses, slots = {}, {}
		local function fuse(blown)
			local m = model("Fuse")
			local g = cyl(1.0, 0.36, CFrame.new(), blown and Color3.fromRGB(60, 56, 54) or Color3.fromRGB(220, 236, 244), GLASSM, m)
			g.Transparency = blown and 0.1 or 0.45
			for _, y in ipairs({ -0.55, 0.55 }) do cyl(0.22, 0.4, CFrame.new(0, y, 0), CHROME, METAL, m) end
			if not blown then cyl(0.9, 0.05, CFrame.new(), Color3.fromRGB(255, 180, 80), NEON, m)
			else ell(Vector3.new(0.5, 0.4, 0.1), CFrame.new(0, 0.1, 0.18), Color3.fromRGB(20, 18, 16), SMOOTH, m) end
			done(m)
			setQuery(m, false)
			return m
		end
		for i = 1, 4 do
			local x = -2.1 + (i - 1) * 1.4
			slots[i] = Vector3.new(x, FUSEY, -0.95)
			for _, y in ipairs({ -0.62, 0.62 }) do part(Vector3.new(0.5, 0.12, 0.3), CFrame.new(x, FUSEY + y, -1.05), Color3.fromRGB(190, 150, 70), METAL).CanQuery = false end
			fuses[i] = fuse(i == blownI)
			fuses[i]:PivotTo(CFrame.new(slots[i]))
		end
		-- the wires: three roots at the bottom, three terminals above, ends dangling loose
		local WCOL = { Color3.fromRGB(220, 50, 50), Color3.fromRGB(50, 110, 230), Color3.fromRGB(240, 200, 40) }
		local order = shuffle({ 1, 2, 3 })
		local wires = {}
		for i = 1, 3 do
			local root = Vector3.new(-1.6 + (i - 1) * 1.6, 2.0, -1.05)
			local term = Vector3.new(-1.6 + (table.find(order, i) - 1) * 1.6, 3.7, -1.0)
			cylZ(0.25, 0.55, CFrame.new(term), CHROME, METAL).CanQuery = false
			cylZ(0.27, 0.75, CFrame.new(term - Vector3.new(0, 0, 0.05)), WCOL[i], SMOOTH).CanQuery = false
			local w = { root = root, term = term, col = WCOL[i], draw = wire(WCOL[i]) }
			w.home = root + Vector3.new(rng:NextNumber(-0.7, 0.7), -1.1, 0.9)
			w.tip = ball(0.42, CFrame.new(w.home), WCOL[i], SMOOTH)
			w.draw(root, w.home, 0.2)
			wires[i] = w
		end
		-- the cover, with its four screws and a warning sticker
		local cover = model("Cover")
		part(Vector3.new(6.8, 5.8, 0.14), CFrame.new(), Color3.fromRGB(196, 200, 206), METAL, cover)
		part(Vector3.new(1.8, 1.6, 0.02), CFrame.new(0, 0.6, 0.08), Color3.fromRGB(255, 200, 40), SMOOTH, cover)
		part(Vector3.new(5.6, 0.12, 0.02), CFrame.new(0, -1.8, 0.08), Color3.fromRGB(60, 62, 66), SMOOTH, cover)
		part(Vector3.new(5.6, 0.12, 0.02), CFrame.new(0, -2.1, 0.08), Color3.fromRGB(60, 62, 66), SMOOTH, cover)
		done(cover)
		setQuery(cover, false)
		local COVERCF = CFrame.new(BOX + Vector3.new(0, 0, 0.6))
		cover:PivotTo(COVERCF)
		local warn = toArea(BOX + Vector3.new(0, 0.6, 0.7))
		local icon = img(C.ICONS.spark, Vector2.new(70, 70), warn, { ZIndex = 6 })
		local screws = {}
		for _, s in ipairs({ { -2.95, 2.45 }, { 2.95, 2.45 }, { -2.95, -2.45 }, { 2.95, -2.45 } }) do
			local m = model("Screw")
			cylZ(0.2, 0.55, CFrame.new(), CHROME, METAL, m)
			part(Vector3.new(0.42, 0.07, 0.05), CFrame.new(0, 0, 0.11), Color3.fromRGB(60, 62, 66), METAL, m)
			part(Vector3.new(0.07, 0.42, 0.05), CFrame.new(0, 0, 0.11), Color3.fromRGB(60, 62, 66), METAL, m)
			done(m)
			setQuery(m, false)
			local at = BOX + Vector3.new(s[1], s[2], 0.75)
			m:PivotTo(CFrame.new(at))
			table.insert(screws, { m = m, at = at })
		end
		-- sparks fly from the broken bits until they're fixed
		local sparking = true
		local nextSpark = 0
		every(function()
			if not sparking or os.clock() < nextSpark then return end
			nextSpark = os.clock() + rng:NextNumber(0.35, 0.8)
			local w = wires[rng:NextInteger(1, 3)]
			local at = cover.Parent and (BOX + Vector3.new(rng:NextNumber(-3, 3), -2.9, 0.8)) or w.tip.Position
			burst(toArea(at), Color3.fromRGB(255, 220, 90), 6, 40)
			if rng:NextNumber() < 0.4 then sound("click") end
		end)

		stages({
			{
				name = "Unscrew the Cover",
				hint = "Circle round each glowing screw to undo it",
				run = function(next, progress)
					local i = 0
					local function nextScrew()
						i += 1
						local s = screws[i]
						if not s then
							icon:Destroy()
							tweenPivot(cover, COVERCF * CFrame.new(0, -3.5, 4) * CFrame.Angles(math.rad(-80), 0, 0), 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
							task.delay(0.5, function() cover:Destroy() end)
							sound("knock")
							next()
							return
						end
						local mk = marker(s.at + Vector3.new(0, 0, 0.12), 0.9, Vector3.zAxis)
						twistStage(s.at, 1.5, function(k, da)
							s.m:PivotTo(CFrame.new(s.at + Vector3.new(0, 0, k * 0.5)) * CFrame.Angles(0, 0, k * 20))
							V.handPos = s.at + Vector3.new(0.3, -0.4, 0.7)
							progress((i - 1 + k) / 4)
							if math.random() < 0.1 then sound("turn") end
						end, function()
							mk.destroy()
							V.handPos = nil
							arc(s.m, CFrame.new(s.at.X, 0.2, 1.5), 0.45, 1.5, nil, 8)
							sound("click")
							nextScrew()
						end, 90)
					end
					nextScrew()
				end,
			},
			{
				name = "Swap the Fuse",
				hint = "Pull out the blown fuse",
				run = function(next, progress)
					local bad = fuses[blownI]
					dragStage(bad, Vector3.new(0, 0, -0.3), Vector3.zAxis, slots[blownI], 1.8, { away = true }, function()
						arc(bad, CFrame.new(-5.6, 1.4, 1.2), 0.4, 2, function() bad:Destroy() end, 5)
						progress(0.5)
						sound("place")
						say("Now push a new fuse into the empty clip")
						local good = fuse(false)
						good:PivotTo(CFrame.new(-4.6, 2.6, -0.4))
						dragStage(good, Vector3.new(0, 0, -0.6), Vector3.zAxis, slots[blownI], 0.7, { mark = 1.0 }, function()
							tweenPivot(good, CFrame.new(slots[blownI]), 0.12)
							sound("click")
							nice(slots[blownI], "Click!")
							next()
						end)
					end)
				end,
			},
			{
				name = "Reconnect the Wires",
				hint = "Drag each loose wire to the terminal of the same colour",
				run = function(next, progress)
					local tips, owner = {}, {}
					for _, w in ipairs(wires) do
						table.insert(tips, w.tip)
						owner[w.tip] = w
					end
					local held, fixed = nil, 0
					S.onDown = function(p)
						local hit = pick(p, tips)
						held = hit and owner[hit.Instance]
						if held then sound("select") end
					end
					S.onMove = function(p)
						local w = held
						if not w then return end
						local hit = onPlane(p, Vector3.new(0, 0, -0.7), Vector3.zAxis)
						if not hit then return end
						w.tip.Position = hit
						V.handPos = hit + Vector3.new(0, -0.3, 0.3)
						w.draw(w.root, hit, 0.3)
					end
					S.onUp = function()
						local w = held
						held = nil
						V.handPos = nil
						if not w then return end
						local at = w.tip.Position
						for _, o in ipairs(wires) do
							if flatDist(at, o.term, Vector3.zAxis) < 0.65 then
								if o == w then
									w.tip.Position = w.term
									w.draw(w.root, w.term, 0.5)
									w.tip.CanQuery = false
									table.remove(tips, table.find(tips, w.tip))
									fixed += 1
									sound("click")
									nice(w.term, "Connected!")
									progress(fixed / 3)
									if fixed == 3 then
										sparking = false
										next()
									end
								else
									oops(o.term, "Wrong colour!")
									w.tip.Position = w.home
									w.draw(w.root, w.home, 0.2)
								end
								return
							end
						end
						tw(w.tip, 0.25, { Position = w.home }, Enum.EasingStyle.Back)
						task.delay(0.26, function() w.draw(w.root, w.home, 0.2) end)
					end
				end,
			},
			{
				name = "Power It Up",
				hint = "Click when the needle is in the green",
				run = function(next, progress)
					sweepStage(toArea(BOX + Vector3.new(0, -3.4, 0.8)), "POWER", function(perfect)
						lamp.Color = Color3.fromRGB(60, 230, 110)
						for _, f in ipairs(fuses) do
							if f.Parent then for _, p in ipairs(partsOf(f)) do if p.Material == NEON then p.Color = Color3.fromRGB(255, 240, 160) end end end
						end
						sound("sparkle")
						nice(BOX + Vector3.new(0, 2.2, 0.8), perfect and "Perfect power-up!" or "Power's back!", T.sun)
						next()
					end, progress)
				end,
			},
		})
	end


	---------------------------------------------------------------- round 40: surprises
	-- Now and then a job throws in an extra step: a guest's lost thing to hand in, or a bug to shoo. They sit on the
	-- scene's floor (or counter) where the lower part of the screen looks at it; their time doesn't count against par.
	-- Test hook: player attribute MGSurprise = "off" | "lost" | "bug".
	-- the surface height per scene, and whether its middle is open enough for a bug to run about (the shower and the
	-- repairs have no floor in view; the bed and the toilet stand in the middle of theirs)
	local SURFACE = { Floor = { 0, true }, Bed = { 0 }, Toilet = { 0 }, CheckIn = { 0, true }, CheckOut = { 0, true }, Cook = { 0, true } }
	local LOST = {
		{ "teddy bear", function(m)
			local fur = Color3.fromRGB(176, 120, 70)
			ball(0.9, CFrame.new(0, 0.45, 0), fur, FABRIC, m)
			ball(0.66, CFrame.new(0, 1.15, 0), fur, FABRIC, m)
			for _, x in ipairs({ -0.27, 0.27 }) do ball(0.26, CFrame.new(x, 1.44, 0), fur, FABRIC, m) end
			for _, x in ipairs({ -0.42, 0.42 }) do ball(0.3, CFrame.new(x, 0.6, 0.1), fur, FABRIC, m) end
			ball(0.26, CFrame.new(0, 1.07, 0.27), Color3.fromRGB(232, 202, 160), FABRIC, m)
			for _, x in ipairs({ -0.13, 0.13 }) do ball(0.09, CFrame.new(x, 1.24, 0.29), Color3.fromRGB(30, 24, 20), SMOOTH, m) end
			ell(Vector3.new(0.5, 0.14, 0.2), CFrame.new(0, 0.86, 0.22), Color3.fromRGB(220, 50, 70), SMOOTH, m)
		end },
		{ "watch", function(m)
			part(Vector3.new(0.34, 0.06, 1.5), CFrame.new(0, 0.04, 0), Color3.fromRGB(70, 46, 30), SMOOTH, m)
			cyl(0.14, 0.78, CFrame.new(0, 0.12, 0), BRASS, METAL, m)
			cyl(0.15, 0.62, CFrame.new(0, 0.13, 0), Color3.fromRGB(250, 250, 246), SMOOTH, m)
			part(Vector3.new(0.04, 0.16, 0.24), CFrame.new(0, 0.15, -0.08), Color3.fromRGB(30, 30, 34), SMOOTH, m)
			part(Vector3.new(0.16, 0.16, 0.04), CFrame.new(0.06, 0.15, 0), Color3.fromRGB(30, 30, 34), SMOOTH, m)
		end },
		{ "phone", function(m)
			part(Vector3.new(0.72, 0.08, 1.36), CFrame.new(0, 0.04, 0), Color3.fromRGB(34, 36, 42), SMOOTH, m)
			part(Vector3.new(0.62, 0.02, 1.16), CFrame.new(0, 0.09, 0), Color3.fromRGB(80, 160, 255), NEON, m)
		end },
		{ "sunglasses", function(m)
			for _, x in ipairs({ -0.36, 0.36 }) do ell(Vector3.new(0.6, 0.12, 0.46), CFrame.new(x, 0.06, 0), Color3.fromRGB(20, 22, 30), GLASSM, m) end
			part(Vector3.new(0.3, 0.06, 0.08), CFrame.new(0, 0.08, -0.12), Color3.fromRGB(230, 180, 60), METAL, m)
			for _, x in ipairs({ -0.66, 0.66 }) do part(Vector3.new(0.06, 0.06, 1.0), CFrame.new(x, 0.08, -0.6), Color3.fromRGB(230, 180, 60), METAL, m) end
		end },
	}
	local function floorAt(y, ax, ay) return onPlane(Vector2.new(ax, ay), Vector3.new(0, y, 0), UP) end

	local function lostStage(y)
		local pickL = LOST[rng:NextInteger(1, #LOST)]
		return {
			name = "Lost & Found",
			hint = "Someone left their " .. pickL[1] .. "! Pop it in the lost & found box",
			surprise = true,
			run = function(next)
				local left = rng:NextNumber() < 0.5
				local A = floorAt(y, W * (left and 0.24 or 0.76), H * 0.8)
				local B = floorAt(y, W * (left and 0.76 or 0.24), H * 0.8)
				if not (A and B) then next() return end
				local it = model("Lost")
				pickL[2](it)
				done(it)
				local turn = CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
				it:PivotTo(CFrame.new(A + Vector3.new(0, 7, 0)) * turn)
				tweenPivot(it, CFrame.new(A) * turn, 0.5, Enum.EasingStyle.Bounce)
				sound("place")
				local glint = marker(A, 1.8, UP)
				local box = model("LostBox")
				local CARD = Color3.fromRGB(196, 150, 96)
				part(Vector3.new(2.0, 1.1, 1.5), CFrame.new(0, 0.55, 0), CARD, SMOOTH, box)
				part(Vector3.new(1.8, 0.05, 1.3), CFrame.new(0, 1.08, 0), Color3.fromRGB(120, 86, 50), SMOOTH, box)
				for _, s in ipairs({ -1, 1 }) do
					part(Vector3.new(2.0, 0.06, 0.6), CFrame.new(0, 1.2, s * 0.95) * CFrame.Angles(s * math.rad(-35), 0, 0), CARD, SMOOTH, box)
				end
				part(Vector3.new(1.2, 0.36, 0.02), CFrame.new(0, 0.62, 0.76), Color3.fromRGB(255, 248, 220), SMOOTH, box)
				done(box)
				setQuery(box, false)
				box:PivotTo(CFrame.new(B) * CFrame.Angles(0, 0, 0))
				UI.pop(tag3(B + Vector3.new(0, 3.0, 0), "LOST & FOUND", T.sun, 13, 120), 0.6, 0.25)
				later(0.45, function()
					dragStage(it, Vector3.new(0, y + 0.9, 0), UP, B + Vector3.new(0, 0.9, 0), 1.5, { mark = 2.2, lift0 = function() glint.destroy() end }, function()
						tweenPivot(it, CFrame.new(B + Vector3.new(0, 0.5, 0)), 0.2)
						task.delay(0.2, function() if it.Parent then it:Destroy() end end)
						sound("coins")
						nice(B + Vector3.new(0, 1.2, 0), "Handed in!", T.sun)
						S.found = pickL[1]
						next()
					end)
				end)
			end,
		}
	end

	local function bugStage(y)
		return {
			name = "Bug!",
			hint = "A beetle! Tap it three times to shoo it out",
			surprise = true,
			run = function(next, progress)
				local P0 = floorAt(y, W * 0.5, H * 0.8)
				if not P0 then next() return end
				local bug = model("Bug")
				local SHELL = Color3.fromRGB(70, 46, 30)
				ell(Vector3.new(0.8, 0.4, 1.1), CFrame.new(0, 0.26, 0.1), SHELL, SMOOTH, bug)
				part(Vector3.new(0.03, 0.42, 1.0), CFrame.new(0, 0.3, 0.1), Color3.fromRGB(40, 26, 16), SMOOTH, bug)
				ball(0.38, CFrame.new(0, 0.22, -0.55), Color3.fromRGB(40, 30, 24), SMOOTH, bug)
				for _, x in ipairs({ -0.1, 0.1 }) do
					part(Vector3.new(0.03, 0.03, 0.5), CFrame.new(x * 2, 0.3, -0.9) * CFrame.Angles(0.3, x * 4, 0), Color3.fromRGB(30, 22, 16), SMOOTH, bug)
				end
				local legs = {}
				for i = -1, 1 do
					for _, s in ipairs({ -1, 1 }) do
						local l = part(Vector3.new(0.5, 0.04, 0.05), CFrame.new(s * 0.5, 0.1, i * 0.32), Color3.fromRGB(30, 22, 16), SMOOTH, bug)
						table.insert(legs, l)
					end
				end
				done(bug)
				setQuery(bug, true)
				local pos, heading, speed = P0, rng:NextNumber(0, math.pi * 2), 2.4
				local turnAt, hops, gone = 0, 0, false
				local c = every(function(dt)
					if not bug.Parent then return end
					local now = os.clock()
					if now > turnAt then turnAt = now + rng:NextNumber(0.4, 1.1) heading += rng:NextNumber(-1.6, 1.6) end
					local dir = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
					local nextPos = pos + dir * speed * dt
					local a = toArea(nextPos)
					if not gone and (a.X < 50 or a.X > W - 50 or a.Y < H * 0.62 or a.Y > H - 16) then
						local to = P0 - pos
						heading = math.atan2(-to.X, -to.Z) + rng:NextNumber(-0.4, 0.4)
					else
						pos = nextPos
					end
					local wob = math.sin(now * 30) * 0.06
					bug:PivotTo(CFrame.new(pos) * CFrame.Angles(0, heading + wob, 0))
				end)
				S.onDown = function(p)
					if gone then return end
					if not (pick(p, partsOf(bug)) or (p - toArea(pos)).Magnitude < 34) then
						floatText(p + Vector2.new(0, -24), "Missed!", T.orange)
						return
					end
					hops += 1
					sound("knock")
					burst(toArea(pos), Color3.fromRGB(255, 255, 255), 6, 36)
					progress(hops / 3)
					speed += 1.6
					heading += math.pi + rng:NextNumber(-0.6, 0.6)
					if hops >= 3 then
						gone = true
						S.onDown = nil
						local dir = (pos - V.cam.CFrame.Position) * Vector3.new(1, 0, 1)
						tweenPivot(bug, CFrame.new(pos + dir.Unit * 14) * CFrame.Angles(0, heading, 0), 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						task.delay(0.62, function() c:Disconnect() if bug.Parent then bug:Destroy() end end)
						nice(pos + Vector3.new(0, 1, 0), "Shoo!", T.green)
						S.shooed = true
						next()
					end
				end
			end,
		}
	end

	G3._surprise = function(kind)
		local sf = SURFACE[kind]
		if not sf then return nil end
		local y = sf[1]
		local want = Players.LocalPlayer:GetAttribute("MGSurprise")
		if want == "off" then return nil end
		if want == "lost" then return lostStage(y) end
		if want == "bug" and sf[2] then return bugStage(y) end
		if want then return lostStage(y) end
		if rng:NextNumber() > 0.35 then return nil end
		return (rng:NextNumber() < 0.55 or not sf[2]) and lostStage(y) or bugStage(y)
	end

	-- test hooks (MGTest below): a named model or part's play-area position, and any world point's
	G3._find = function(name)
		if not V or not V.wm.Parent then return nil end
		for _, o in ipairs(V.wm:GetDescendants()) do
			if o.Name == name and (o:IsA("Model") or o:IsA("BasePart")) then
				return toArea(o:IsA("Model") and o:GetPivot().Position or o.Position)
			end
		end
	end
	G3._toArea = function(v) return V and toArea(v) end
end

local GAMES = G3

---------------------------------------------------------------- opening one

-- round 39: this game's best time in this hotel (QuestServer keeps state.best in the Quests attribute)
local HttpService = game:GetService("HttpService")
local function bestOf(kind)
	local plots = workspace:FindFirstChild("Plots")
	local hotel = plots and plots:FindFirstChild(Players.LocalPlayer:GetAttribute("Plot") or "")
	local ok, t = pcall(HttpService.JSONDecode, HttpService, hotel and hotel:GetAttribute("Quests") or "")
	return ok and type(t) == "table" and type(t.best) == "table" and tonumber(t.best[kind]) or nil
end

-- round 39: a bonus coin spins in somewhere for a few seconds; a tap on it (before the game sees the tap) grabs it
local function spawnCoin(s)
	local plots = workspace:FindFirstChild("Plots")
	local hotel = plots and plots:FindFirstChild(Players.LocalPlayer:GetAttribute("Plot") or "")
	local worth = Q.mgCoin(hotel and hotel:GetAttribute("Level"))
	local pos = Vector2.new(rng:NextNumber(70, W - 70), rng:NextNumber(90, H - 50))
	local coin = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Color3.fromRGB(255, 204, 48), ZIndex = 45, Parent = s.area })
	UI.corner(coin, 26)
	UI.stroke(coin, 3, Color3.fromRGB(176, 120, 16), 0)
	UI.grad(coin, Color3.fromRGB(255, 232, 120), Color3.fromRGB(240, 170, 30), 90)
	local mark = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "$", TextSize = 30, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(150, 96, 10), ZIndex = 46, Parent = coin })
	local t0 = os.clock()
	UI.pop(coin, 0.5, 0.3)
	sound("tick")
	local spin = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.abs(math.cos(t * 4))
		coin.Size = UDim2.fromOffset(math.max(6, 52 * k), 52)
		mark.TextTransparency = k < 0.3 and 1 or 0
		setPos(coin, pos + Vector2.new(0, math.sin(t * 3) * 5))
	end)
	table.insert(s.conns, spin)
	local function gone()
		spin:Disconnect()
		if s.coin then s.coin = nil end
	end
	s.coin = function(p)
		if (p - pos).Magnitude > 40 then return false end
		gone()
		s.bonus = true
		coin:Destroy()
		burst(pos, T.gold, 14, 120)
		floatText(pos, "+$" .. worth, T.gold)
		sound("sparkle")
		return true
	end
	task.delay(3.5, function()
		if not coin.Parent then return end
		gone()
		UI.tween(coin, 0.25, { BackgroundTransparency = 1 })
		mark.TextTransparency = 1
		task.delay(0.25, function() coin:Destroy() end)
	end)
	return pos
end

-- test hook (like the hotel's Test* attributes): player attribute TestMG = "coin" grabs a bonus coin, "win" finishes
Players.LocalPlayer:GetAttributeChangedSignal("TestMG"):Connect(function()
	local v = Players.LocalPlayer:GetAttribute("TestMG")
	if not S or not v then return end
	Players.LocalPlayer:SetAttribute("TestMG", nil)
	if v == "coin" then local s = S local p = spawnCoin(s) task.wait(0.6) if s.coin then s.coin(p) end
	elseif v == "win" then win() end
end)

-- round 40: scripted input for playtests: PlayerScripts.Minigames.MGTest:Invoke(op, ...). op "down" / "move" / "up"
-- with x, y in play-area units; "stage" returns the stage name, number, count, mistakes, won; "find" a named
-- model's play-area x, y; "area" a world point's
do
	local hook = Instance.new("BindableFunction")
	hook.Name = "MGTest"
	hook.OnInvoke = function(op, a, b, c)
		local s = S
		if not s then return nil end
		if op == "down" or op == "move" or op == "up" then
			local p = Vector2.new(a, b)
			s.pointer = p
			if op == "down" then
				s.held = true
				if s.onDown then s.onDown(p) end
			elseif op == "move" then
				if s.onMove then s.onMove(p) end
			else
				s.held = false
				if s.onUp then s.onUp(p) end
			end
			return true
		elseif op == "stage" then
			return s.stageName, s.stageNo, s.stageCount, s.mistakes, s.won
		elseif op == "find" then
			local v = G3._find(a)
			return v and v.X, v and v.Y
		elseif op == "area" then
			local v = G3._toArea(Vector3.new(a, b, c))
			return v and v.X, v and v.Y
		end
	end
	hook.Parent = script
end

local function open(kind, data)
	if S or not GAMES[kind] then return end
	if WorkPose then WorkPose:FireServer(kind) end
	local info = INFO[kind]
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = new("ScreenGui", { Name = "Minigame", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	-- full-screen catcher: swallows clicks (no punching or building behind it) and frees a locked mouse
	local dim = new("TextButton", {
		Name = "Catch", Text = "", AutoButtonColor = false, Modal = true, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 14, 20), BackgroundTransparency = 1, Parent = gui,
	})
	UI.tween(dim, 0.25, { BackgroundTransparency = 0 })
	-- round 12: the game fills the screen. The play area keeps its W x H design units, scaled to fit between the
	-- top bar and an equal band below (so its centre stays the screen's centre); the 3D scene spreads to the edges.
	local area = new("Frame", {
		Name = "Area", Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1, Parent = dim,
	})
	local areaScale = Instance.new("UIScale")
	areaScale.Parent = area
	-- the top bar: what this job is, what to do now, how far along, and a way out
	local hud = new("Frame", { Name = "Hud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = dim })
	-- round 40: cards in the job's colour: a soft tinted gradient, a solid rim and a tab of colour along the top
	local ACCENT = ({ CheckIn = T.sun, CheckOut = T.sun, Cook = Color3.fromRGB(240, 120, 50), Repair = T.red })[kind] or T.gold
	local function card(props)
		local f = new("Frame", props)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.Parent = hud
		UI.corner(f, 18)
		UI.grad(f, Color3.new(1, 1, 1), Color3.fromRGB(226, 234, 248), 90)
		UI.stroke(f, 2, ACCENT, 0).Thickness = 2.5
		local tab = new("Frame", { Name = "Tab", Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -44, 0, 4), BackgroundColor3 = ACCENT, BorderSizePixel = 0, Parent = f })
		UI.corner(tab, 2)
		return f
	end
	local subtitle = data and (data.guest and (data.guest .. (data.room and (", room " .. data.room) or "")) or (data.room and ("Room " .. data.room))) or "Overbooked"
	local titleCard = card({ Name = "Title", Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(330, 66) })
	local badge = new("Frame", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = ACCENT, Parent = titleCard })
	UI.corner(badge, 14)
	UI.grad(badge, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
	UI.stroke(badge, 2, Color3.new(1, 1, 1), 0.2).Thickness = 2
	UI.icon(badge, C.ICONS[info.icon] or C.ICONS.clean, 36, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	new("TextLabel", {
		Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -74, 0, 30), BackgroundTransparency = 1,
		Text = data and (data.dishName or data.title) or info.title, TextSize = 24, FontFace = UI.F.black, TextColor3 = T.cream,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = titleCard,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(64, 38), Size = UDim2.new(1, -74, 0, 20), BackgroundTransparency = 1,
		Text = subtitle, TextSize = 16, FontFace = UI.F.bold, TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = titleCard,
	})
	local hintCard = card({ Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(540, 66) })
	local hint = new("TextLabel", {
		Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -36, 0, 32), BackgroundTransparency = 1, Text = "",
		TextSize = 22, FontFace = UI.F.heavy, TextColor3 = T.cream, Parent = hintCard,
	})
	local track = new("Frame", { Position = UDim2.fromOffset(18, 43), Size = UDim2.new(1, -36, 0, 12), BackgroundColor3 = Color3.fromRGB(206, 214, 230), Parent = hintCard })
	UI.corner(track, 6)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.corner(fill, 6)
	UI.grad(fill, T.green, T.greenDk, 90)
	local fillGlow = new("Frame", { Position = UDim2.fromOffset(3, 2), Size = UDim2.new(1, -6, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Parent = fill })
	UI.corner(fillGlow, 2)
	-- the step chip on the card's top edge: which step of how many, and its name
	local stepChip = new("TextLabel", {
		Name = "Step", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = ACCENT, Text = "", TextSize = 13, FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 4, Parent = hintCard,
	})
	UI.corner(stepChip, 11)
	UI.stroke(stepChip, 2, Color3.new(1, 1, 1), 0).Thickness = 2
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = stepChip })
	local closeWrap = new("Frame", { Name = "CloseWrap", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(66, 66), BackgroundTransparency = 1, Parent = hud })
	UI.iconButton(closeWrap, { name = "Close", icon = C.ICONS.close, iconSize = 30, size = UDim2.fromScale(1, 1), color = T.red, radius = 18, onClick = function() closeGame(true) end })
	-- round 15: the star clock: three stars that drop one at a time as the job runs past par, the time, and a bar
	-- that drains toward the next drop
	local par = (C.MINIGAME_PAR and C.MINIGAME_PAR[kind]) or info.par or 12
	local clockCard = card({ Name = "Clock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -92, 0, 14), Size = UDim2.fromOffset(178, 66) })
	local starIcons = {}
	for i = 1, 3 do
		starIcons[i] = new("ImageLabel", { Image = C.ICONS.star or "", BackgroundTransparency = 1, Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(12 + (i - 1) * 32, 8), ImageColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = clockCard })
	end
	local clockText = new("TextLabel", { Position = UDim2.fromOffset(110, 8), Size = UDim2.fromOffset(56, 30), BackgroundTransparency = 1, Text = "0:00", TextSize = 22, FontFace = UI.F.black, TextColor3 = T.cream, TextXAlignment = Enum.TextXAlignment.Right, Parent = clockCard })
	local clockTrack = new("Frame", { Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = T.ink2, Parent = clockCard })
	UI.corner(clockTrack, 4)
	local clockFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.gold, Parent = clockTrack })
	UI.corner(clockFill, 4)
	local hudScales = {}
	for _, o in ipairs({ titleCard, hintCard, closeWrap, clockCard }) do
		local sc = Instance.new("UIScale")
		sc.Name = "HudScale"
		sc.Parent = o
		table.insert(hudScales, sc)
	end
	local cam = workspace.CurrentCamera
	local function layout()
		local v = cam.ViewportSize
		local k = math.clamp(math.min(v.X / 1500, v.Y / 860), 0.5, 1.2)
		for _, sc in ipairs(hudScales) do sc.Scale = k end
		titleCard.Visible = v.X / k > 1180 -- a narrow screen keeps the room for the hint
		local band = 88 * k
		areaScale.Scale = math.min(v.X / W, (v.Y - band * 2) / H)
	end
	layout()
	S = {
		kind = kind, data = data, gui = gui, dim = dim, root = hud, hud = hud, area = area, areaScale = areaScale, hint = hint, fill = fill,
		conns = {}, t0 = os.clock(), held = false, progress = 0, best = bestOf(kind),
	}
	-- round 39: a hot streak shows under the clock (three stars keeps it going)
	local streakNow = Players.LocalPlayer:GetAttribute("MGStreak") or 0
	if streakNow >= 1 then
		local badge = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(160, 24), BackgroundColor3 = Color3.fromRGB(232, 96, 40),
			Text = "HOT STREAK x" .. streakNow, TextSize = 14, FontFace = UI.F.black, TextColor3 = Color3.new(1, 1, 1), Parent = clockCard,
		})
		UI.corner(badge, 12)
		UI.stroke(badge, 1.5, Color3.fromRGB(140, 50, 20), 0)
	end
	table.insert(S.conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(layout))
	do
		local shown, me = 3, S
		local stepShown
		table.insert(S.conns, RunService.RenderStepped:Connect(function()
			if S ~= me or me.won then return end
			if me.stageName and me.stageName ~= stepShown then
				stepShown = me.stageName
				stepChip.Text = string.upper(string.format("Step %d of %d  ·  %s", me.stageNo or 1, me.stageCount or 1, me.stageName))
				stepChip.Visible = true
				UI.pop(stepChip, 0.6, 0.25)
			end
			local e = os.clock() - me.t0
			local m = me.mistakes or 0
			local n = e <= par and 3 or e <= par * 1.6 and 2 or 1
			if m > 0 then n = math.min(n, m >= 2 and 1 or 2) end
			clockText.Text = string.format("%d:%02d", math.floor(e / 60), math.floor(e % 60))
			local k = 0
			if n == 3 then k = 1 - e / par elseif n == 2 and m == 0 then k = 1 - (e - par) / (par * 0.6) end
			clockFill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
			clockFill.BackgroundColor3 = n == 3 and T.gold or T.muted
			if n < shown then
				for i = n + 1, shown do
					starIcons[i].Image = C.ICONS.starEmpty or starIcons[i].Image
					UI.tween(starIcons[i], 0.3, { ImageTransparency = 0.25 })
					pulse(starIcons[i], 1.4)
				end
				shown = n
				sound("tick")
			end
		end))
	end
	gui.Parent = pg
	-- arrive: the scene settles in, the cards drop from the top
	local a1 = areaScale.Scale
	areaScale.Scale = a1 * 0.9
	UI.tween(areaScale, 0.5, { Scale = a1 }, Enum.EasingStyle.Back)
	for i, o in ipairs({ titleCard, hintCard, closeWrap, clockCard }) do
		local p0 = o.Position
		o.Position = p0 - UDim2.fromOffset(0, 130)
		task.delay(0.05 * i, function()
			if o.Parent then UI.tween(o, 0.5, { Position = p0 }, Enum.EasingStyle.Back) end
		end)
	end
	sound("open")

	-- InputObject.Position and AbsolutePosition share the space below the top bar inset
	local function screenPos(io) return Vector2.new(io.Position.X, io.Position.Y) end
	local function isPress(io) return io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch end
	local s = S
	table.insert(s.conns, UIS.InputBegan:Connect(function(io)
		if S ~= s or not isPress(io) then return end
		local p = toLocal(screenPos(io))
		s.pointer = p
		if not inArea(p) then return end
		if s.coin and s.coin(p) then return end
		s.held = true
		if s.onDown then s.onDown(p) end
	end))
	table.insert(s.conns, UIS.InputChanged:Connect(function(io)
		if S ~= s then return end
		if io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch then
			local p = toLocal(screenPos(io))
			s.pointer = p
			if s.onMove then s.onMove(p) end
		end
	end))
	table.insert(s.conns, UIS.InputEnded:Connect(function(io)
		if S ~= s or not isPress(io) then return end
		s.held = false
		if s.onUp then s.onUp(s.pointer) end
	end))
	-- a controller (round 10c): the left stick moves a cursor ring over the play area, A or RT presses, B gives up
	s.padP = Vector2.new(W / 2, H / 2)
	local stick = Vector2.zero
	local ring = new("Frame", { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 50, Visible = false, Parent = area })
	UI.corner(ring, 17)
	UI.stroke(ring, 3, T.gold, 0)
	local ringDot = new("Frame", { Size = UDim2.fromOffset(8, 8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.cream, ZIndex = 51, Parent = ring })
	UI.corner(ringDot, 4)
	CAS:BindActionAtPriority("MinigamePad", function(_, state, io)
		if S ~= s then return Enum.ContextActionResult.Pass end
		local kc = io.KeyCode
		if kc == Enum.KeyCode.Thumbstick1 then
			stick = state == Enum.UserInputState.End and Vector2.zero or Vector2.new(io.Position.X, -io.Position.Y)
		elseif kc == Enum.KeyCode.ButtonA or kc == Enum.KeyCode.ButtonR2 then
			if state == Enum.UserInputState.Begin then
				s.pointer = s.padP
				if s.coin and s.coin(s.padP) then return Enum.ContextActionResult.Sink end
				s.held = true
				if s.onDown then s.onDown(s.padP) end
			elseif state == Enum.UserInputState.End then
				s.held = false
				if s.onUp then s.onUp(s.padP) end
			end
		elseif kc == Enum.KeyCode.ButtonB and state == Enum.UserInputState.Begin then
			closeGame(true)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY)
	table.insert(s.conns, RunService.RenderStepped:Connect(function(dt)
		if S ~= s then return end
		local on = UI.gamepad()
		ring.Visible = on and not s.won
		if not on then return end
		if stick.Magnitude > 0.15 then
			local m = math.min(stick.Magnitude, 1)
			local v = stick.Unit * (m * m) * dt * (s.held and 420 or 520)
			s.padP = Vector2.new(math.clamp(s.padP.X + v.X, 0, W), math.clamp(s.padP.Y + v.Y, 0, H))
			s.pointer = s.padP
			if s.onMove then s.onMove(s.padP) end
		end
		setPos(ring, s.padP)
		ring.Size = UDim2.fromOffset(s.held and 28 or 34, s.held and 28 or 34)
	end))
	-- the tool follows the pointer; the OS cursor hides while it's over the play area
	table.insert(s.conns, RunService.RenderStepped:Connect(function()
		if S ~= s or not (s.tool or s.hideCursor) then return end
		local p = toLocal(UIS:GetMouseLocation() - GuiService:GetGuiInset())
		if UIS.TouchEnabled and not UIS.MouseEnabled then p = s.pointer or p end
		if UI.gamepad() then p = s.padP end
		local over = p and inArea(p) and not s.noTool and not s.won
		UIS.MouseIconEnabled = not over
		if not s.tool then return end -- 3D games (hideCursor) move their own tool in the scene
		s.tool.Visible = over and true or false
		if over then
			setPos(s.tool, p + s.toolOffset)
			s.tool.Rotation = s.held and math.sin(os.clock() * 30) * 8 or 0
		end
	end))
	-- one frame later the area has its real size
	task.defer(function()
		if S == s then GAMES[kind]() end
	end)
	if rng:NextNumber() < Q.MG.coinChance then
		task.delay(rng:NextNumber(1.5, math.max(2, par * 0.55)), function()
			if S == s and not s.won then spawnCoin(s) end
		end)
	end
end

Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "minigame" and data and data.task then
		open(data.task, data)
	elseif kind == "minigameEnd" then
		closeGame(false)
	end
end)
