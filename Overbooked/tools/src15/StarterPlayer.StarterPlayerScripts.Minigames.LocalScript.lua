-- StarterPlayerScripts.Minigames: the cleaning minigames (round 10b remake) and the front desk (round 10c).
-- The server opens one with Notify "minigame" when a clean or desk prompt is pressed; this script plays it and
-- reports through CleanDone(cancel, stars) (the server checks the timing itself, so finishing here is the only way to score).
--   Floor  : sort the litter into the RECYCLE and TRASH bins
--   Bed    : fluff the pillows, pull the blanket up, smooth out the wrinkles
--   Shower : scrub the grime off the glass with a sponge, then rinse
--   Toilet : scrub the stains with the brush, then flush
--   CheckIn : find the guest's booking on the computer, grab their room key, stamp the card on the beat
--   CheckOut: count the right change out of the drawer
--   Cook    : pick the ingredients, chop, flip the pan in the gold, plate up and ring the bell (the kitchen)
--   Repair  : wire the loose leads to their terminals, tighten the cover's bolts, throw the power lever (round 11)
-- Round 11: every game is a 3D scene in a ViewportFrame (G3 below); the flat versions are kept behind FLAT.
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
	Floor = { title = "Tidy the Floor", icon = "clean", par = 14 },
	Bed = { title = "Make the Bed", icon = "bed", par = 13 },
	Shower = { title = "Scrub the Shower", icon = "shower", par = 12 },
	Toilet = { title = "Clean the Toilet", icon = "toilet", par = 11 },
	CheckIn = { title = "Check In", icon = "bell", par = 7, words = { "Done!", "Great service!", "Perfect check-in!" } },
	CheckOut = { title = "Check Out", icon = "cash", par = 7, words = { "Done!", "Great service!", "Perfect change!" } },
	Cook = { title = "Cook", icon = "food", par = 17, words = { "Served!", "Tasty!", "Chef's kiss!" } },
	Repair = { title = "Repair", icon = "wrench", par = 13, words = { "Fixed!", "Good as new!", "Expert repair!" } },
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

---------------------------------------------------------------- Floor: sort the litter

local LITTER = { bottle = "r", can = "r", paper = "r", banana = "t", wrapper = "t", apple = "t" }

local function playFloor()
	S.area.BackgroundColor3 = Color3.fromRGB(184, 132, 86)
	UI.grad(S.area, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 200, 190), 90)
	for i = 0, 12 do -- planks
		new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromOffset(i * 52, 0), BackgroundColor3 = Color3.fromRGB(120, 80, 50), BackgroundTransparency = 0.6, ZIndex = 1, Parent = S.area })
	end
	local rug = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 128), Size = UDim2.fromOffset(380, 190), BackgroundColor3 = Color3.fromRGB(30, 96, 90), ZIndex = 2, Parent = S.area })
	UI.corner(rug, 18)
	UI.stroke(rug, 4, T.gold, 0.2)
	local bins = {
		r = { pos = Vector2.new(W - 92, H - 78), name = "RECYCLE", col = T.blue },
		t = { pos = Vector2.new(92, H - 78), name = "TRASH", col = T.green },
	}
	for k, b in pairs(bins) do
		b.obj = img(k == "r" and "binr" or "bint", Vector2.new(108, 108), b.pos, { ZIndex = 8 })
		local tag = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(110, 24),
			BackgroundColor3 = T.ink, Text = b.name, TextSize = 15, FontFace = UI.F.black, TextColor3 = b.col, ZIndex = 9, Parent = b.obj,
		})
		UI.corner(tag, 8)
	end
	-- 7 pieces, at least 3 of each kind, scattered over the floor
	local kinds = { "bottle", "can", "paper", "banana", "wrapper", "apple" }
	local pick = { "bottle", "can", "paper", "banana", "wrapper", "apple", kinds[rng:NextInteger(1, 6)] }
	local items, done = {}, 0
	for i, name in ipairs(pick) do
		local p
		for _ = 1, 30 do
			p = Vector2.new(rng:NextNumber(70, W - 70), rng:NextNumber(46, H - 140))
			local ok = true
			for _, o in ipairs(items) do if (o.pos - p).Magnitude < 70 then ok = false end end
			if ok then break end
		end
		local o = img(name, Vector2.new(64, 64), p, { ZIndex = 10 + i, Rotation = rng:NextNumber(-35, 35) })
		table.insert(items, { obj = o, kind = LITTER[name], pos = p, home = p })
		local sc = UI.scaleOf(o)
		sc.Scale = 0
		UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.05 * i)
	end
	say("Drag each piece into the right bin")
	local held, grab
	S.onDown = function(p)
		for i = #items, 1, -1 do
			local it = items[i]
			if not it.gone and (it.pos - p).Magnitude < 42 then
				held, grab = it, it.pos - p
				it.obj.ZIndex = 45
				UI.tween(UI.scaleOf(it.obj), 0.15, { Scale = 1.2 }, Enum.EasingStyle.Back)
				UI.tween(it.obj, 0.15, { Rotation = 0 })
				sound("select")
				return
			end
		end
	end
	S.onMove = function(p)
		if held then
			held.pos = Vector2.new(math.clamp(p.X + grab.X, 24, W - 24), math.clamp(p.Y + grab.Y, 24, H - 24))
			setPos(held.obj, held.pos)
			for k, b in pairs(bins) do
				local near = (held.pos - b.pos).Magnitude < 74
				UI.tween(UI.scaleOf(b.obj), 0.12, { Scale = near and 1.12 or 1 })
			end
		end
	end
	S.onUp = function()
		local it = held
		held = nil
		if not it then return end
		UI.tween(UI.scaleOf(it.obj), 0.15, { Scale = 1 })
		for k, b in pairs(bins) do
			UI.tween(UI.scaleOf(b.obj), 0.12, { Scale = 1 })
			if (it.pos - b.pos).Magnitude < 74 then
				if k == it.kind then
					it.gone = true
					UI.tween(it.obj, 0.22, { Position = UDim2.fromOffset(b.pos.X, b.pos.Y - 10), Size = UDim2.fromOffset(10, 10), Rotation = 200 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(0.22, function()
						it.obj:Destroy()
						if not S then return end
						pulse(b.obj, 1.25)
						burst(b.pos - Vector2.new(0, 40), b.col, 7)
					end)
					done += 1
					floatText(b.pos - Vector2.new(0, 70), done == #items and "All done!" or "+1", T.green)
					sound("place")
					setProgress(done / #items)
					if done == #items then task.delay(0.35, win) end
				else
					shake(b.obj)
					floatText(b.pos - Vector2.new(0, 70), k == "r" and "Not recyclable!" or "Recycle that!", T.red)
					sound("error")
					it.pos = it.home
					UI.tween(it.obj, 0.3, { Position = UDim2.fromOffset(it.home.X, it.home.Y) }, Enum.EasingStyle.Back)
				end
				return
			end
		end
		it.home = it.pos -- dropped on the floor: it stays there
		it.obj.ZIndex = 20
	end
end

---------------------------------------------------------------- Bed: pillows, blanket, wrinkles

local function playBed()
	S.area.BackgroundColor3 = Color3.fromRGB(196, 150, 104)
	UI.grad(S.area, Color3.fromRGB(255, 255, 255), Color3.fromRGB(214, 200, 190), 90)
	for i = 0, 12 do -- floorboards
		new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromOffset(i * 52, 0), BackgroundColor3 = Color3.fromRGB(120, 80, 50), BackgroundTransparency = 0.6, ZIndex = 1, Parent = S.area })
	end
	local bx, bw, top, bottom = W / 2, 330, 26, H - 14
	-- a rug under the bed and a nightstand with a lamp either side
	local rug = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(bx, H + 20), Size = UDim2.fromOffset(bw + 150, 150), BackgroundColor3 = Color3.fromRGB(150, 52, 52), ZIndex = 1, Parent = S.area })
	UI.corner(rug, 14)
	UI.stroke(rug, 4, T.gold, 0.3)
	for _, sx in ipairs({ -1, 1 }) do
		local nx = bx + sx * (bw / 2 + 62)
		local stand = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(nx, top + 6), Size = UDim2.fromOffset(74, 66), BackgroundColor3 = Color3.fromRGB(110, 70, 44), ZIndex = 2, Parent = S.area })
		UI.corner(stand, 10)
		UI.stroke(stand, 3, Color3.fromRGB(70, 44, 28), 0)
		local shade = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(nx, top + 36), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.fromRGB(255, 226, 160), ZIndex = 3, Parent = S.area })
		UI.corner(shade, 21)
		UI.stroke(shade, 3, Color3.fromRGB(214, 170, 90), 0)
		local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(nx, top + 36), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.fromRGB(255, 220, 150), BackgroundTransparency = 0.82, ZIndex = 2, Parent = S.area })
		UI.corner(glow, 55)
	end
	local frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(bx, top), Size = UDim2.fromOffset(bw + 24, bottom - top + 10), BackgroundColor3 = Color3.fromRGB(110, 70, 44), ZIndex = 2, Parent = S.area })
	UI.corner(frame, 16)
	local head = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(bx, top - 14), Size = UDim2.fromOffset(bw + 40, 30), BackgroundColor3 = Color3.fromRGB(86, 54, 34), ZIndex = 3, Parent = S.area })
	UI.corner(head, 12)
	local mattress = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(bx, top + 10), Size = UDim2.fromOffset(bw, bottom - top - 14), BackgroundColor3 = Color3.fromRGB(250, 246, 238), ZIndex = 3, Parent = S.area })
	UI.corner(mattress, 12)
	-- pillows start squashed; three taps each fluffs them up
	local pillows = {}
	for i, x in ipairs({ bx - 80, bx + 80 }) do
		local p = Vector2.new(x, top + 52)
		local o = img("pillow", Vector2.new(150, 150), p, { ZIndex = 6, Rotation = i == 1 and -8 or 6 })
		local sc = UI.scaleOf(o)
		sc.Scale = 0.72
		table.insert(pillows, { obj = o, pos = p, taps = 0 })
	end
	-- the blanket: its top edge (blanketTop) moves; the line marks where it belongs
	local lineY = top + 104
	local startTop = bottom - 92
	local blanketTop = startTop
	local blanket = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(bx, bottom - 4), Size = UDim2.fromOffset(bw + 6, bottom - 4 - blanketTop), BackgroundColor3 = Color3.fromRGB(52, 118, 108), ZIndex = 8, Parent = S.area })
	UI.corner(blanket, 12)
	UI.grad(blanket, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 210), 90)
	local cuff = new("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = Color3.fromRGB(250, 246, 238), ZIndex = 9, Parent = blanket })
	UI.corner(cuff, 8)
	for i = 1, 2 do
		new("Frame", { Size = UDim2.new(1, -24, 0, 4), Position = UDim2.new(0, 12, 0, 26 + i * 10), BackgroundColor3 = T.gold, BackgroundTransparency = 0.2, ZIndex = 9, Parent = blanket })
	end
	local guide = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(bx, lineY), Size = UDim2.fromOffset(bw - 10, 4), BackgroundColor3 = T.gold, BackgroundTransparency = 1, ZIndex = 7, Parent = S.area })
	local function sizeBlanket()
		blanket.Size = UDim2.fromOffset(bw + 6, bottom - 4 - blanketTop)
	end
	local phase = 1
	local wrinkles = {}
	say("Tap the pillows to fluff them up")
	local function startWrinkles()
		phase = 3
		say("Rub out the wrinkles")
		for i = 1, 5 do
			local y = lineY + 34 + (i - 1) * ((bottom - lineY - 60) / 4)
			local x = bx + rng:NextNumber(-90, 90)
			local len = rng:NextNumber(90, 150)
			local rot = rng:NextNumber(-25, 25)
			local o = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(len, 7), Rotation = rot, BackgroundColor3 = Color3.fromRGB(24, 70, 64), ZIndex = 12, Parent = S.area })
			UI.corner(o, 4)
			local hi = new("Frame", { Size = UDim2.new(1, -10, 0, 3), Position = UDim2.fromOffset(5, -4), BackgroundColor3 = Color3.fromRGB(120, 190, 176), ZIndex = 12, Parent = o })
			UI.corner(hi, 2)
			local r = math.rad(rot)
			local dir = Vector2.new(math.cos(r), math.sin(r))
			table.insert(wrinkles, { obj = o, a = Vector2.new(x, y) - dir * len / 2, b = Vector2.new(x, y) + dir * len / 2, hp = 150, max = 150 })
		end
	end
	local function distSeg(p, a, b)
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		return (p - (a + ab * t)).Magnitude
	end
	local dragging, lastP, grabOff = false, nil, 0
	local smoothed = 0
	S.onDown = function(p)
		lastP = p
		if phase == 1 then
			for _, pl in ipairs(pillows) do
				if pl.taps < 3 and math.abs(p.X - pl.pos.X) < 74 and math.abs(p.Y - pl.pos.Y) < 44 then
					pl.taps += 1
					local sc = UI.scaleOf(pl.obj)
					local k = 0.72 + 0.28 * pl.taps / 3
					sc.Scale = k * 0.82
					UI.tween(sc, 0.3, { Scale = k }, Enum.EasingStyle.Back)
					burst(pl.pos, Color3.fromRGB(255, 255, 255), 6, 60)
					sound("sheets")
					if pl.taps == 3 then
						UI.tween(pl.obj, 0.3, { Rotation = 0 })
						floatText(pl.pos - Vector2.new(0, 40), "Fluffy!", T.cream)
					end
					local total = 0
					for _, q in ipairs(pillows) do total += q.taps end
					setProgress(total / 6 / 3)
					if total == 6 then
						phase = 2
						say("Drag the blanket up to the gold line")
						UI.tween(guide, 0.3, { BackgroundTransparency = 0.1 })
						task.spawn(function()
							while S and phase == 2 do
								UI.tween(guide, 0.45, { BackgroundTransparency = 0.6 })
								task.wait(0.5)
								if not S or phase ~= 2 then break end
								UI.tween(guide, 0.45, { BackgroundTransparency = 0.05 })
								task.wait(0.5)
							end
						end)
					end
					return
				end
			end
		elseif phase == 2 then
			if p.Y > blanketTop - 30 and math.abs(p.X - bx) < bw / 2 + 10 then
				dragging = true
				grabOff = blanketTop - p.Y
				sound("select")
			end
		end
	end
	S.onMove = function(p)
		if phase == 2 and dragging then
			blanketTop = math.clamp(p.Y + grabOff, lineY - 6, startTop)
			sizeBlanket()
			setProgress(1 / 3 + (startTop - blanketTop) / (startTop - lineY) / 3)
		elseif phase == 3 and S.held and lastP then
			local travel = (p - lastP).Magnitude
			for _, w in ipairs(wrinkles) do
				if w.hp > 0 and distSeg(p, w.a, w.b) < 26 then
					w.hp -= travel
					w.obj.BackgroundTransparency = 1 - math.max(w.hp, 0) / w.max
					if w.hp <= 0 then
						smoothed += 1
						UI.tween(w.obj, 0.2, { Size = UDim2.fromOffset(w.obj.Size.X.Offset * 1.2, 0) })
						task.delay(0.25, function() w.obj:Destroy() end)
						burst((w.a + w.b) / 2, T.cream, 6, 50)
						sound("sheets")
						setProgress(2 / 3 + smoothed / #wrinkles / 3)
						if smoothed == #wrinkles then
							phase = 4
							local m = img("mint", Vector2.new(56, 56), pillows[1].pos + Vector2.new(40, -6), { ZIndex = 20 })
							UI.pop(m, 0.2, 0.45)
							task.delay(0.35, win)
						end
					end
				end
			end
			if travel > 2 and rng:NextNumber() < 0.15 then sound("sheets") end
		end
		lastP = p
	end
	S.onUp = function()
		if phase == 2 and dragging then
			dragging = false
			if blanketTop - lineY < 22 then
				blanketTop = lineY
				sizeBlanket()
				pulse(blanket, 1.04)
				burst(Vector2.new(bx, lineY), T.gold, 10, 90)
				sound("place")
				UI.tween(guide, 0.2, { BackgroundTransparency = 1 })
				startWrinkles()
				setProgress(2 / 3)
			end
		end
	end
end

---------------------------------------------------------------- scrubbing (Shower and Toilet)

-- stains with hit points: rub over them (held + moving) to wear them away
local function scrubber(stains, radius, sfxName, onAllClean)
	local lastP
	local left = #stains
	local lastSfx = 0
	S.onDown = function(p) lastP = p end
	S.onMove = function(p)
		if S.held and lastP and not S.won then
			local travel = (p - lastP).Magnitude
			if travel > 0.5 then
				for _, s in ipairs(stains) do
					if s.hp > 0 and (s.pos - p).Magnitude < s.r + radius then
						s.hp -= travel
						local k = math.max(s.hp, 0) / s.max
						s.obj.ImageTransparency = 1 - (0.12 + 0.88 * k)
						local sc = UI.scaleOf(s.obj)
						sc.Scale = 0.75 + 0.25 * k
						if s.hp <= 0 then
							left -= 1
							burst(s.pos, T.cream, 8, 70)
							bubbles(s.pos, 3)
							sound("sparkle")
							task.delay(0.1, function() s.obj:Destroy() end)
							setProgress((#stains - left) / #stains * 0.85)
							-- point out the last few so nobody hunts for them
							if left > 0 and left <= 2 then
								for _, q in ipairs(stains) do
									if q.hp > 0 and not q.pulsing then
										q.pulsing = true
										task.spawn(function()
											while S and q.hp > 0 and q.obj.Parent do
												local qs = UI.scaleOf(q.obj)
												UI.tween(qs, 0.35, { Scale = qs.Scale * 1.12 }, Enum.EasingStyle.Sine)
												task.wait(0.4)
												if not (S and q.obj.Parent) then break end
												UI.tween(qs, 0.35, { Scale = 0.75 + 0.25 * math.max(q.hp, 0) / q.max }, Enum.EasingStyle.Sine)
												task.wait(0.4)
											end
										end)
									end
								end
							end
							if left == 0 then onAllClean() end
						end
					end
				end
				if rng:NextNumber() < 0.25 then bubbles(p, 1) end
				if os.clock() - lastSfx > 0.22 then
					lastSfx = os.clock()
					sound(sfxName)
				end
			end
		end
		lastP = p
	end
	S.onUp = function() lastP = nil end
end

local function stain(pos, size, tint, hp)
	local o = img("grime", Vector2.new(size, size), pos, { ZIndex = 10, ImageColor3 = tint, Rotation = rng:NextNumber(0, 360), ImageTransparency = 0.12 })
	return { obj = o, pos = pos, r = size * 0.38, hp = hp, max = hp }
end

local function playShower()
	S.area.BackgroundColor3 = Color3.fromRGB(226, 236, 242)
	for i = 0, 15 do -- tiles
		new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromOffset(i * 40, 0), BackgroundColor3 = Color3.fromRGB(176, 190, 200), ZIndex = 1, Parent = S.area })
	end
	for j = 0, 9 do
		new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, j * 40), BackgroundColor3 = Color3.fromRGB(176, 190, 200), ZIndex = 1, Parent = S.area })
	end
	local glass = new("Frame", { Size = UDim2.new(1, -40, 1, -30), Position = UDim2.fromOffset(20, 15), BackgroundColor3 = Color3.fromRGB(200, 230, 246), BackgroundTransparency = 0.6, ZIndex = 3, Parent = S.area })
	UI.corner(glass, 10)
	UI.stroke(glass, 5, Color3.fromRGB(200, 208, 220), 0)
	local head = img("showerhead", Vector2.new(96, 96), Vector2.new(W - 70, 60), { ZIndex = 4 })
	local stains = {}
	for _ = 1, 11 do
		local p
		for _ = 1, 30 do
			p = Vector2.new(rng:NextNumber(70, W - 70), rng:NextNumber(60, H - 50))
			local ok = (p - Vector2.new(W - 70, 60)).Magnitude > 90
			for _, s in ipairs(stains) do if (s.pos - p).Magnitude < 70 then ok = false end end
			if ok then break end
		end
		local soap = rng:NextNumber() < 0.35
		local tint = soap and Color3.fromRGB(246, 246, 236) or Color3.fromRGB(rng:NextInteger(120, 160), rng:NextInteger(130, 150), rng:NextInteger(90, 110))
		table.insert(stains, stain(p, rng:NextNumber(64, 96), tint, rng:NextNumber(150, 240)))
	end
	useTool("sponge", 84, Vector2.new(0, 6))
	say("Hold and scrub the grime off the glass")
	scrubber(stains, 26, "scrub", function()
		say("Now tap the shower head to rinse")
		S.tool.Visible = false
		S.noTool = true
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W - 70, 60), Size = UDim2.fromOffset(116, 116), BackgroundTransparency = 1, ZIndex = 3, Parent = S.area })
		UI.corner(ring, 58)
		local st = UI.stroke(ring, 4, T.gold, 0)
		task.spawn(function()
			while S and ring.Parent do
				UI.tween(st, 0.4, { Transparency = 0.7 })
				task.wait(0.45)
				if not (S and ring.Parent) then break end
				UI.tween(st, 0.4, { Transparency = 0 })
				task.wait(0.45)
			end
		end)
		S.onDown = function(p)
			if (p - Vector2.new(W - 70, 60)).Magnitude < 70 and ring.Parent then
				ring:Destroy()
				pulse(head, 1.2)
				sound("spray")
				for i = 1, 40 do
					task.delay(i * 0.02, function()
						if not S then return end
						local x = rng:NextNumber(30, W - 30)
						local d = new("Frame", { Size = UDim2.fromOffset(3, rng:NextNumber(18, 34)), Position = UDim2.fromOffset(x, -30), BackgroundColor3 = Color3.fromRGB(150, 210, 250), BackgroundTransparency = 0.2, ZIndex = 26, Parent = S.area })
						UI.tween(d, 0.5, { Position = UDim2.fromOffset(x, H + 10) }, Enum.EasingStyle.Linear)
						task.delay(0.55, function() d:Destroy() end)
					end)
				end
				task.delay(0.9, win)
			end
		end
		S.onMove = nil
	end)
end

local function playToilet()
	S.area.BackgroundColor3 = Color3.fromRGB(214, 228, 236)
	for i = 0, 7 do -- floor tiles
		new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.fromOffset(i * 88, 0), BackgroundColor3 = Color3.fromRGB(186, 200, 210), ZIndex = 1, Parent = S.area })
		new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, i * 88 - 20), BackgroundColor3 = Color3.fromRGB(186, 200, 210), ZIndex = 1, Parent = S.area })
	end
	-- a bath mat, a paper roll and a little bin round the bowl
	local mat = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(W / 2, H + 18), Size = UDim2.fromOffset(300, 70), BackgroundColor3 = Color3.fromRGB(120, 176, 196), ZIndex = 2, Parent = S.area })
	UI.corner(mat, 22)
	UI.stroke(mat, 3, Color3.fromRGB(255, 255, 255), 0.3)
	local roll = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(96, 120), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(252, 252, 248), ZIndex = 3, Parent = S.area })
	UI.corner(roll, 32)
	UI.stroke(roll, 3, Color3.fromRGB(196, 204, 214), 0)
	local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.fromRGB(200, 160, 110), ZIndex = 4, Parent = roll })
	UI.corner(core, 11)
	local tail = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(96, 140), Size = UDim2.fromOffset(46, 70), BackgroundColor3 = Color3.fromRGB(252, 252, 248), ZIndex = 2, Parent = S.area })
	UI.corner(tail, 6)
	img("bint", Vector2.new(84, 84), Vector2.new(W - 84, H - 70), { ZIndex = 3 })
	local cx, cy, sz = W / 2, H / 2 + 14, 360
	local bowl = img("toilet", Vector2.new(sz, sz), Vector2.new(cx, cy), { ZIndex = 4 })
	-- in the sprite the water is centred at (128, 155)/256 with radii about 40 x 51; the porcelain ring runs out to about 58 x 70
	local oc = Vector2.new(cx, cy + (155 - 128) / 256 * sz)
	local wx, wy = 38 / 256 * sz, 48 / 256 * sz
	local stains = {}
	for i = 1, 7 do
		local p
		local tough = i <= 2
		if i >= 6 then -- splashes on the rim
			local a = rng:NextNumber(0, math.pi * 2)
			p = oc + Vector2.new(math.cos(a) * 66 / 256 * sz, math.sin(a) * 78 / 256 * sz)
		else
			local a = (i / 5) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
			local k = rng:NextNumber(0.3, 0.8)
			p = oc + Vector2.new(math.cos(a) * wx * k, math.sin(a) * wy * k)
		end
		table.insert(stains, stain(p, tough and 50 or rng:NextNumber(34, 42), tough and Color3.fromRGB(110, 84, 50) or Color3.fromRGB(150, 120, 74), tough and 260 or 150))
	end
	useTool("brush", 92, Vector2.new(-10, -26))
	say("Hold and scrub the stains away")
	-- the flush button sits on the tank
	local fb = UI.button(S.area, { text = "FLUSH", kind = "blue", size = UDim2.fromOffset(110, 40), pos = UDim2.fromOffset(cx + 176, cy - 138), anchor = Vector2.new(0.5, 0.5) })
	fb.ZIndex = 30
	fb.Visible = false
	scrubber(stains, 22, "scrub", function()
		say("Flush it!")
		S.tool.Visible = false
		S.noTool = true
		fb.Visible = true
		UI.pop(fb, 0.4, 0.4)
		S.onMove = nil
		S.onDown = function(p)
			if math.abs(p.X - (cx + 176)) < 64 and math.abs(p.Y - (cy - 138)) < 28 and fb.Visible then
				fb.Visible = false
				sound("flush")
				local swirl = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(oc.X, oc.Y), Size = UDim2.fromOffset(wx * 2, wy * 2), BackgroundColor3 = Color3.fromRGB(120, 196, 246), BackgroundTransparency = 0.1, ZIndex = 20, Parent = S.area })
				UI.corner(swirl, 200)
				local g = UI.grad(swirl, Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 140, 220), 0)
				UI.tween(g, 1, { Rotation = 720 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				UI.tween(swirl, 1, { Size = UDim2.fromOffset(4, 4), BackgroundTransparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				bubbles(oc, 6)
				task.delay(1, function() if swirl.Parent then swirl:Destroy() end win() end)
			end
		end
	end)
end

---------------------------------------------------------------- Front desk (round 10c): check in, check out

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

-- the desk top every front desk game sits on
local function deskTop()
	S.area.BackgroundColor3 = WOOD
	UI.grad(S.area, Color3.fromRGB(255, 236, 214), Color3.fromRGB(170, 130, 100), 90)
	for i = 0, 6 do -- grain
		box({ Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 18 + i * 50 + rng:NextInteger(-6, 6)), BackgroundColor3 = Color3.fromRGB(90, 56, 30), BackgroundTransparency = 0.75, ZIndex = 1 })
	end
end

local function playCheckIn()
	local d = S.data or {}
	local guest = d.guest or "Guest"
	local roomId = tostring(d.room or "101")
	local nights = d.nights or 2
	S.mistakes = 0
	deskTop()

	-- the registration card along the bottom: fields fill in as you go
	local card = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, 252), Size = UDim2.fromOffset(330, 78), BackgroundColor3 = PAPER, ZIndex = 4, Rotation = -1.5 })
	UI.corner(card, 6)
	UI.stroke(card, 1.5, Color3.fromRGB(200, 180, 150), 0)
	text(card, "REGISTRATION", 12, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(200, 14), TextXAlignment = Enum.TextXAlignment.Left })
	local fields = {}
	for i, f in ipairs({ { "GUEST", 14 }, { "ROOM", 168 }, { "NIGHTS", 250 } }) do
		text(card, f[1], 10, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(150, 140, 130), Position = UDim2.fromOffset(f[2], 30), Size = UDim2.fromOffset(80, 12), TextXAlignment = Enum.TextXAlignment.Left })
		box({ Parent = card, Position = UDim2.fromOffset(f[2], 66), Size = UDim2.fromOffset(i == 1 and 140 or 66, 1), BackgroundColor3 = Color3.fromRGB(190, 170, 150), ZIndex = 5 })
		fields[i] = text(card, "", 19, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(f[2], 42), Size = UDim2.fromOffset(i == 1 and 140 or 70, 22), TextXAlignment = Enum.TextXAlignment.Left })
	end
	local function fill(i, str)
		fields[i].Text = str
		fields[i].MaxVisibleGraphemes = 0
		UI.tween(fields[i], 0.3, { MaxVisibleGraphemes = #str }, Enum.EasingStyle.Linear)
		sound("tick")
	end

	-- the computer: today's bookings
	local mon = box({ Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(292, 216), BackgroundColor3 = Color3.fromRGB(58, 61, 66), ZIndex = 3 })
	UI.corner(mon, 12)
	UI.stroke(mon, 2, T.shadow, 0.3)
	box({ Position = UDim2.fromOffset(128, 226), Size = UDim2.fromOffset(52, 22), BackgroundColor3 = Color3.fromRGB(53, 56, 60), ZIndex = 2 })
	local screen = box({ Parent = mon, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = T.ink, ZIndex = 4 })
	UI.corner(screen, 6)
	UI.grad(screen, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 230), 90)
	text(screen, "TODAY'S BOOKINGS", 12, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(200, 14), TextXAlignment = Enum.TextXAlignment.Left })
	local names = shuffle(table.clone(d.names or { guest, "Emily", "James", "Ava", "Leo" }))
	local rows = {}
	for i, nm in ipairs(names) do
		local y = 30 + (i - 1) * 34
		local r = box({ Parent = screen, Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = T.ink2, ZIndex = 5 })
		UI.corner(r, 6)
		text(r, nm, 16, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(150, 22), TextXAlignment = Enum.TextXAlignment.Left })
		local n = nm == guest and nights or rng:NextInteger(1, 5)
		text(r, n .. (n == 1 and " night" or " nights"), 13, { TextColor3 = T.muted, Position = UDim2.new(1, -96, 0, 6), Size = UDim2.fromOffset(86, 18), TextXAlignment = Enum.TextXAlignment.Right })
		-- centre in area units (the screen sits at 26,22 inside the area)
		rows[i] = { obj = r, name = nm, pos = Vector2.new(18 + 8 + 8 + 130, 14 + 8 + y + 15), size = Vector2.new(260, 30) }
		r.BackgroundTransparency = 1
		UI.tween(r, 0.25, { BackgroundTransparency = 0 }, nil, nil, 0.05 * i)
	end

	-- the key rack
	local rack = box({ Position = UDim2.fromOffset(330, 14), Size = UDim2.fromOffset(272, 216), BackgroundColor3 = Color3.fromRGB(110, 66, 38), ZIndex = 3 })
	UI.corner(rack, 10)
	UI.grad(rack, Color3.fromRGB(255, 230, 205), Color3.fromRGB(190, 150, 120), 90)
	UI.stroke(rack, 2, Color3.fromRGB(70, 40, 20), 0.2)
	text(rack, "ROOM KEYS", 12, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(255, 226, 160), Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14) })
	local ids = {}
	for _, k in ipairs(d.keys or {}) do table.insert(ids, tostring(k)) end
	if not table.find(ids, roomId) then table.insert(ids, roomId) end
	-- pad the rack to 8 keys with neighbouring numbers
	local base = tonumber(roomId) or 101
	local floor = math.floor(base / 100) * 100
	local tries = 0
	while #ids < 8 and tries < 80 do
		tries += 1
		local fake = tostring((rng:NextNumber() < 0.65 and floor or floor + 100) + rng:NextInteger(1, 12))
		if not table.find(ids, fake) then table.insert(ids, fake) end
	end
	while #ids > 8 do -- keep the right one
		local i = rng:NextInteger(1, #ids)
		if ids[i] ~= roomId then table.remove(ids, i) end
	end
	shuffle(ids)
	local keys = {}
	for i, id in ipairs(ids) do
		local cx = 330 + 38 + ((i - 1) % 4) * 65
		local cy = 14 + 70 + math.floor((i - 1) / 4) * 92
		local hook = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy - 34), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(60, 40, 26), ZIndex = 6 })
		UI.corner(hook, UDim.new(0.5, 0))
		local tag = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(48, 58), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 7, Rotation = rng:NextNumber(-6, 6) })
		UI.corner(tag, 10)
		UI.grad(tag, Color3.fromRGB(255, 226, 140), Color3.fromRGB(206, 150, 60), 90)
		UI.stroke(tag, 1.5, Color3.fromRGB(120, 80, 30), 0.2)
		local hole = box({ Parent = tag, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(24, 5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Color3.fromRGB(110, 66, 38), ZIndex = 8 })
		UI.corner(hole, UDim.new(0.5, 0))
		text(tag, id, 17, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(70, 44, 16), Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 22), ZIndex = 9 })
		-- the key itself under the tag
		local key = box({ Parent = tag, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(6, 22), BackgroundColor3 = Color3.fromRGB(200, 200, 210), ZIndex = 6 })
		box({ Parent = key, Position = UDim2.fromOffset(6, 12), Size = UDim2.fromOffset(6, 4), BackgroundColor3 = Color3.fromRGB(200, 200, 210), ZIndex = 6 })
		box({ Parent = key, Position = UDim2.fromOffset(6, 18), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(200, 200, 210), ZIndex = 6 })
		keys[i] = { obj = tag, id = id, pos = Vector2.new(cx, cy), size = Vector2.new(56, 70) }
		local sc = UI.scaleOf(tag)
		sc.Scale = 0
		UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.15 + 0.04 * i)
	end

	-- the stamp meter (step 3) lives over the top half, hidden until then
	local meter = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 122), Size = UDim2.fromOffset(420, 92), BackgroundColor3 = T.ink, BackgroundTransparency = 0.04, ZIndex = 30, Visible = false })
	UI.corner(meter, 16)
	UI.stroke(meter, 2, T.gold, 0.2)
	text(meter, "STAMP IT!", 20, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 24), ZIndex = 31 })
	local bar = box({ Parent = meter, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(372, 26), BackgroundColor3 = T.ink2, ZIndex = 31 })
	UI.corner(bar, 13)
	local zoneW = 70
	local zoneX = rng:NextNumber(110, 372 - 110)
	local zone = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(zoneX, 0), Size = UDim2.fromOffset(zoneW, 26), BackgroundColor3 = T.green, ZIndex = 32 })
	UI.corner(zone, 8)
	UI.grad(zone, T.green, T.greenDk, 90)
	local sweet = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(zoneX, 0), Size = UDim2.fromOffset(18, 26), BackgroundColor3 = T.gold, ZIndex = 33 })
	UI.corner(sweet, 6)
	local marker = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 13), Size = UDim2.fromOffset(8, 40), BackgroundColor3 = T.cream, ZIndex = 34 })
	UI.corner(marker, 4)
	UI.stroke(marker, 2, T.shadow, 0.2)

	local step = 1
	local mx, dir = 0, 1
	setProgress(0)
	say("Find " .. guest .. "'s booking on the computer")

	local function stamp(good, perfect)
		meter.Visible = false
		local st = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(250, 44), Size = UDim2.fromOffset(150, 40), BackgroundTransparency = 1,
			Text = good and "APPROVED" or "APPROVED?", TextSize = 24, FontFace = UI.F.black,
			TextColor3 = good and Color3.fromRGB(200, 40, 60) or Color3.fromRGB(150, 90, 100), TextTransparency = good and 0 or 0.35,
			Rotation = good and -12 or -26, ZIndex = 9, Parent = card,
		})
		local stk = Instance.new("UIStroke")
		stk.Color = st.TextColor3
		stk.Thickness = 2.5
		stk.Transparency = good and 0.1 or 0.4
		stk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stk.Parent = st
		local sc = UI.scaleOf(st)
		sc.Scale = 2.6
		UI.tween(sc, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			if not S then return end
			sound("knock")
			shake(card)
			burst(Vector2.new(W / 2 + 85, 296), perfect and T.gold or Color3.fromRGB(220, 70, 90), perfect and 14 or 8, 90)
			floatText(Vector2.new(W / 2, 220), perfect and "Perfect!" or (good and "Nice!" or "Smudged..."), perfect and T.gold or (good and T.green or T.red))
			setProgress(1)
			task.delay(0.45, win)
		end)
	end

	S.onDown = function(p)
		if step == 1 then
			for _, r in ipairs(rows) do
				if hitRect(p, r.pos, r.size) then
					if r.name == guest then
						step = 2
						r.obj.BackgroundColor3 = T.greenDk
						pulse(r.obj, 1.06)
						sound("select")
						fill(1, guest)
						fill(3, tostring(nights))
						setProgress(0.34)
						say("Grab the key for room " .. roomId)
					else
						r.obj.BackgroundColor3 = T.redDk
						UI.tween(r.obj, 0.4, { BackgroundColor3 = T.ink2 })
						miss(r.obj, p, "That's " .. r.name)
					end
					return
				end
			end
		elseif step == 2 then
			for _, k in ipairs(keys) do
				if hitRect(p, k.pos, k.size) then
					if k.id == roomId then
						step = 3
						sound("coins")
						UI.tween(k.obj, 0.35, { Position = UDim2.fromOffset(W / 2 + 196, 284), Rotation = 24 }, Enum.EasingStyle.Back)
						UI.tween(UI.scaleOf(k.obj), 0.35, { Scale = 0.8 })
						k.obj.ZIndex = 20
						fill(2, roomId)
						setProgress(0.67)
						say("Tap when the marker is in the green")
						task.delay(0.35, function()
							if not S then return end
							meter.Visible = true
							UI.pop(meter, 0.6, 0.35)
							step = 4
						end)
					else
						miss(k.obj, p, "That's room " .. k.id)
					end
					return
				end
			end
		elseif step == 4 then
			step = 5
			local off = math.abs(mx - zoneX)
			local good = off <= zoneW / 2
			if not good then S.mistakes += 1 end
			stamp(good, off <= 9)
		end
	end

	-- the marker sweeps back and forth, a little faster each pass
	local speed = 260
	table.insert(S.conns, RunService.RenderStepped:Connect(function(dt)
		if not S or step ~= 4 then return end
		mx += dir * speed * dt
		if mx > 372 then mx, dir, speed = 372, -1, speed + 30 end
		if mx < 0 then mx, dir, speed = 0, 1, speed + 30 end
		marker.Position = UDim2.fromOffset(mx, 13)
	end))
end

local NOTES = { 20, 10, 5, 1 }
local NOTE_COL = {
	[1] = Color3.fromRGB(150, 200, 140), [5] = Color3.fromRGB(120, 180, 210),
	[10] = Color3.fromRGB(230, 170, 110), [20] = Color3.fromRGB(192, 203, 220),
}

local function playCheckOut()
	local d = S.data or {}
	local bill = d.bill or 60
	local paid = d.paid or 80
	local change = paid - bill
	S.mistakes = 0
	deskTop()

	-- the receipt
	local rc = box({ Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(212, 312), BackgroundColor3 = PAPER, ZIndex = 3, Rotation = -1 })
	UI.corner(rc, 6)
	UI.stroke(rc, 1.5, Color3.fromRGB(200, 180, 150), 0)
	text(rc, "RECEIPT", 13, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 16) })
	text(rc, d.guest or "Guest", 18, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 22) })
	text(rc, "Room " .. tostring(d.room or ""), 13, { TextColor3 = Color3.fromRGB(130, 120, 110), Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 16) })
	local function line(y, a, b, big)
		text(rc, a, big and 16 or 15, { FontFace = big and UI.F.black or UI.F.bold, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(18, y), Size = UDim2.fromOffset(120, 22), TextXAlignment = Enum.TextXAlignment.Left })
		return text(rc, b, big and 24 or 17, { FontFace = UI.F.black, TextColor3 = big and Color3.fromRGB(46, 150, 84) or INK_TEXT, Position = UDim2.new(1, -138, 0, y - (big and 4 or 0)), Size = UDim2.fromOffset(120, big and 30 or 22), TextXAlignment = Enum.TextXAlignment.Right })
	end
	line(96, "Stay", "$" .. bill)
	line(126, "Paid", "$" .. paid)
	box({ Parent = rc, Position = UDim2.fromOffset(18, 160), Size = UDim2.new(1, -36, 0, 2), BackgroundColor3 = Color3.fromRGB(200, 180, 150), ZIndex = 4 })
	line(174, "Change", "$" .. change, true)
	text(rc, "Thank you for staying!", 12, { TextColor3 = Color3.fromRGB(150, 140, 130), Position = UDim2.fromOffset(0, 274), Size = UDim2.new(1, 0, 0, 16) })

	-- the counter tray: what you've handed over so far
	local tray = box({ Position = UDim2.fromOffset(250, 14), Size = UDim2.fromOffset(352, 150), BackgroundColor3 = T.ink, BackgroundTransparency = 0.15, ZIndex = 3 })
	UI.corner(tray, 14)
	UI.stroke(tray, 2, T.gold, 0.4)
	text(tray, "GIVING BACK", 12, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(160, 14), TextXAlignment = Enum.TextXAlignment.Left })
	local total = text(tray, "$0", 30, { FontFace = UI.F.black, Position = UDim2.new(1, -176, 0, 6), Size = UDim2.fromOffset(160, 36), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 })
	local of = text(tray, "of $" .. change, 13, { TextColor3 = T.muted, Position = UDim2.new(1, -176, 0, 42), Size = UDim2.fromOffset(160, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 })
	local given, sum = {}, 0

	-- the cash drawer: four slots of notes
	local drawer = box({ Position = UDim2.fromOffset(250, 178), Size = UDim2.fromOffset(352, 150), BackgroundColor3 = Color3.fromRGB(72, 75, 80), ZIndex = 3 })
	UI.corner(drawer, 14)
	UI.stroke(drawer, 2, T.shadow, 0.3)
	local slots = {}
	for i, v in ipairs(NOTES) do
		local cx = 250 + 14 + 40 + (i - 1) * 82
		local cy = 178 + 75
		local slot = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(76, 128), BackgroundColor3 = Color3.fromRGB(49, 52, 56), ZIndex = 4 })
		UI.corner(slot, 10)
		for s = 1, 3 do -- a little stack
			local n = box({ Parent = slot, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (s - 2) * 2, 0.5, (s - 2) * -3), Size = UDim2.fromOffset(58, 100), BackgroundColor3 = NOTE_COL[v], ZIndex = 4 + s, Rotation = (s - 2) * 3 })
			UI.corner(n, 6)
			UI.stroke(n, 1.5, Color3.fromRGB(40, 60, 40), 0.5)
			if s == 3 then
				text(n, "$" .. v, 22, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.new(0, 0, 0.5, -13), Size = UDim2.new(1, 0, 0, 26), Rotation = -90, ZIndex = 9 })
			end
		end
		slots[i] = { obj = slot, v = v, pos = Vector2.new(cx, cy), size = Vector2.new(76, 128) }
	end

	local function refresh()
		total.Text = "$" .. sum
		total.TextColor3 = sum == change and T.green or (sum > change and T.red or T.cream)
		UI.pop(total, 0.8, 0.2)
		setProgress(math.min(sum / change, 1) * 0.95)
	end
	local function layoutTray()
		for i, g in ipairs(given) do
			local x = 22 + (i - 1) * math.min(76, 210 / math.max(#given - 1, 1))
			UI.tween(g.obj, 0.25, { Position = UDim2.fromOffset(x, 66), Rotation = rng:NextNumber(-8, 8) }, Enum.EasingStyle.Back)
		end
	end
	local done = false
	say("Hand back $" .. change .. " in change")
	S.onDown = function(p)
		if done then return end
		-- a note in the tray: take it back
		if hitRect(p, Vector2.new(250 + 176, 14 + 100), Vector2.new(352, 100)) and #given > 0 then
			local g = table.remove(given)
			sum -= g.v
			g.obj:Destroy()
			sound("click")
			refresh()
			layoutTray()
			return
		end
		for _, s in ipairs(slots) do
			if hitRect(p, s.pos, s.size) then
				pulse(s.obj, 0.92)
				local n = box({ Parent = tray, Position = UDim2.fromOffset(s.pos.X - 250 - 29, 170), Size = UDim2.fromOffset(100, 58), BackgroundColor3 = NOTE_COL[s.v], ZIndex = 5 })
				UI.corner(n, 6)
				UI.stroke(n, 1.5, Color3.fromRGB(40, 60, 40), 0.4)
				text(n, "$" .. s.v, 20, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.new(0, 0, 0.5, -12), Size = UDim2.new(1, 0, 0, 24), ZIndex = 6 })
				table.insert(given, { obj = n, v = s.v })
				sum += s.v
				sound("coins")
				layoutTray()
				refresh()
				if sum == change then
					done = true
					sound("register")
					floatText(Vector2.new(250 + 176, 120), "Exact change!", T.green)
					burst(Vector2.new(250 + 176, 90), T.gold, 14, 120)
					setProgress(1)
					task.delay(0.5, win)
				elseif sum > change then
					-- too much: the guest hands the last note back
					floatText(Vector2.new(250 + 176, 120), "Too much!", T.red)
					S.mistakes += 1
					S.t0 -= 1
					sound("error")
					shake(tray)
					task.delay(0.35, function()
						if not S or done then return end
						local g = table.remove(given)
						if g then
							sum -= g.v
							UI.tween(g.obj, 0.25, { Position = UDim2.fromOffset(g.obj.Position.X.Offset, 190), Rotation = 40 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
							task.delay(0.25, function() g.obj:Destroy() end)
							refresh()
						end
					end)
				end
				return
			end
		end
	end
end

---------------------------------------------------------------- Cook (round 10c): prep, chop, cook, serve
-- A stove's Cook prompt: pick the ticket's ingredients off the shelf, chop them, flip the pan when the doneness
-- meter is in the gold, slide it onto the plate and ring the bell. Wrong picks and bad flips cost stars.

local ROUND = UDim.new(0.5, 0)
local LEFT = Enum.TextXAlignment.Left

-- a rounded, softly shaded shape centred on x, y (design units inside its parent)
local function blob(parent, x, y, w, h, color, round, rot, z, flat)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color, Rotation = rot or 0, ZIndex = z or 1, Parent = parent,
	})
	if round then UI.corner(f, round) end
	if not flat then UI.grad(f, Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 202), 90) end
	return f
end

-- ingredients: name, a colour for the crumbs, and a little drawing in a 64 x 64 box
local FOOD = {
	bun = { "Bun", Color3.fromRGB(234, 170, 86), function(f)
		blob(f, 32, 43, 54, 16, Color3.fromRGB(206, 140, 70), 7, 0, 1)
		blob(f, 32, 30, 52, 32, Color3.fromRGB(234, 170, 86), ROUND, 0, 2)
		for i = 1, 5 do blob(f, 18 + i * 5, 22 + (i % 2) * 6, 5, 3, Color3.fromRGB(255, 246, 214), ROUND, 25, 3, true) end
	end },
	patty = { "Patty", Color3.fromRGB(124, 68, 42), function(f)
		blob(f, 32, 34, 56, 26, Color3.fromRGB(124, 68, 42), ROUND, 0, 1)
		for i = -1, 1 do blob(f, 32 + i * 14, 34, 4, 18, Color3.fromRGB(72, 38, 24), 2, 25, 2, true) end
	end },
	cheese = { "Cheese", Color3.fromRGB(252, 206, 66), function(f)
		blob(f, 32, 32, 44, 42, Color3.fromRGB(252, 206, 66), 6, -8, 1)
		local hole = Color3.fromRGB(222, 166, 36)
		blob(f, 23, 25, 9, 9, hole, ROUND, 0, 2, true)
		blob(f, 40, 39, 11, 11, hole, ROUND, 0, 2, true)
		blob(f, 40, 21, 6, 6, hole, ROUND, 0, 2, true)
	end },
	egg = { "Egg", Color3.fromRGB(250, 238, 218), function(f)
		blob(f, 32, 34, 38, 48, Color3.fromRGB(250, 238, 218), ROUND, -10, 1)
		blob(f, 25, 23, 8, 13, Color3.new(1, 1, 1), ROUND, -10, 2, true)
	end },
	pepper = { "Pepper", Color3.fromRGB(64, 168, 70), function(f)
		blob(f, 32, 37, 40, 42, Color3.fromRGB(64, 168, 70), 14, 0, 1)
		blob(f, 23, 37, 9, 28, Color3.fromRGB(120, 214, 120), ROUND, 0, 2, true)
		blob(f, 33, 13, 7, 12, Color3.fromRGB(56, 104, 40), 3, 12, 3, true)
	end },
	flour = { "Flour", Color3.fromRGB(246, 240, 226), function(f)
		blob(f, 32, 37, 44, 46, Color3.fromRGB(242, 234, 214), 10, 0, 1)
		blob(f, 32, 15, 30, 9, Color3.fromRGB(214, 198, 166), 4, 0, 2)
		text(f, "FLOUR", 9, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(150, 110, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(32, 40), Size = UDim2.fromOffset(44, 12), ZIndex = 3 })
	end },
	berries = { "Berries", Color3.fromRGB(40, 84, 130), function(f)
		for i, p in ipairs({ { 22, 40 }, { 42, 41 }, { 32, 25 } }) do
			blob(f, p[1], p[2], 22, 22, i == 3 and Color3.fromRGB(64, 119, 176) or Color3.fromRGB(40, 87, 136), ROUND, 0, i * 2 - 1)
			blob(f, p[1] - 4, p[2] - 4, 5, 5, Color3.fromRGB(248, 251, 255), ROUND, 0, i * 2, true)
		end
		blob(f, 40, 12, 14, 6, Color3.fromRGB(80, 160, 60), ROUND, -30, 9, true)
	end },
	steak = { "Steak", Color3.fromRGB(178, 58, 54), function(f)
		blob(f, 33, 33, 54, 38, Color3.fromRGB(178, 58, 54), 14, -12, 1)
		blob(f, 12, 28, 8, 30, Color3.fromRGB(250, 226, 214), ROUND, -12, 2, true)
		blob(f, 38, 30, 12, 6, Color3.fromRGB(222, 120, 110), ROUND, -20, 3, true)
		blob(f, 30, 40, 9, 5, Color3.fromRGB(222, 120, 110), ROUND, 10, 3, true)
	end },
	carrot = { "Carrot", Color3.fromRGB(244, 136, 40), function(f)
		blob(f, 28, 38, 15, 48, Color3.fromRGB(244, 136, 40), ROUND, 35, 1)
		for i = 0, 2 do blob(f, 22 + i * 7, 44 - i * 9, 7, 2, Color3.fromRGB(200, 100, 30), 1, 35, 2, true) end
		blob(f, 44, 15, 6, 18, Color3.fromRGB(80, 170, 60), 3, 15, 3, true)
		blob(f, 49, 19, 6, 15, Color3.fromRGB(80, 170, 60), 3, 55, 3, true)
	end },
	broccoli = { "Broccoli", Color3.fromRGB(60, 140, 60), function(f)
		blob(f, 32, 45, 12, 26, Color3.fromRGB(150, 200, 110), 4, 0, 1)
		for i, p in ipairs({ { 20, 29 }, { 44, 29 }, { 32, 20 } }) do blob(f, p[1], p[2], 26, 24, Color3.fromRGB(60, 140, 60), ROUND, 0, i + 1) end
	end },
	pasta = { "Pasta", Color3.fromRGB(242, 212, 120), function(f)
		for i = 1, 7 do blob(f, 20 + i * 3, 32, 4, 50, Color3.fromRGB(242, 212, 120), 2, (i - 4) * 5, i) end
		blob(f, 32, 34, 28, 8, Color3.fromRGB(70, 114, 160), 3, 0, 9)
	end },
	tomato = { "Tomato", Color3.fromRGB(226, 52, 42), function(f)
		blob(f, 32, 36, 44, 40, Color3.fromRGB(226, 52, 42), ROUND, 0, 1)
		blob(f, 23, 28, 9, 7, Color3.fromRGB(255, 170, 160), ROUND, -20, 2, true)
		for i = 0, 2 do blob(f, 32, 17, 6, 16, Color3.fromRGB(70, 150, 60), 3, i * 60, 3, true) end
	end },
	basil = { "Basil", Color3.fromRGB(70, 160, 70), function(f)
		blob(f, 22, 38, 18, 32, Color3.fromRGB(60, 140, 60), ROUND, -35, 1)
		blob(f, 42, 38, 18, 32, Color3.fromRGB(60, 140, 60), ROUND, 35, 2)
		blob(f, 32, 27, 20, 36, Color3.fromRGB(90, 180, 80), ROUND, 0, 3)
		blob(f, 32, 29, 2, 26, Color3.fromRGB(50, 110, 50), 1, 0, 4, true)
	end },
}

local function drawFood(id, parent, pos, size, z)
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1, ZIndex = z or 8, Parent = parent,
	})
	local def = FOOD[id]
	if def then def[3](f) end
	UI.scaleOf(f).Scale = (size or 64) / 64
	return f
end

-- ingredients that go into the dish rather than sitting on the plate beside it
local RAW_ONLY = { flour = true, egg = true, pasta = true }

-- what sizzles in the pan: raw, golden, burnt
local PAN = {
	patty = { Color3.fromRGB(214, 122, 122), Color3.fromRGB(130, 72, 44), Color3.fromRGB(40, 28, 24) },
	egg = { Color3.fromRGB(252, 250, 242), Color3.fromRGB(250, 234, 190), Color3.fromRGB(150, 110, 70) },
	batter = { Color3.fromRGB(250, 238, 206), Color3.fromRGB(226, 164, 88), Color3.fromRGB(72, 46, 30) },
	steak = { Color3.fromRGB(208, 86, 86), Color3.fromRGB(142, 72, 48), Color3.fromRGB(42, 28, 22) },
	sauce = { Color3.fromRGB(238, 118, 96), Color3.fromRGB(198, 48, 36), Color3.fromRGB(82, 26, 20) },
}

local function playCook()
	local d = S.data or {}
	local items = d.items or { "bun", "patty", "cheese" }
	local dish = d.dishName or "Cheeseburger"
	local panKind = PAN[d.pan or ""] and d.pan or "patty"
	local stir = panKind == "sauce"
	local shelf = shuffle(table.clone(d.shelf or { "bun", "patty", "cheese", "egg", "tomato", "carrot" }))
	S.mistakes = 0
	local step = "prep"
	local CX = 396 -- the middle of the work space right of the ticket

	-- the kitchen: a tiled wall over a brushed steel counter
	S.area.BackgroundColor3 = Color3.fromRGB(200, 206, 216)
	UI.grad(S.area, Color3.new(1, 1, 1), Color3.fromRGB(164, 167, 172), 90)
	local wall = box({ Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Color3.fromRGB(238, 240, 234), ZIndex = 1 })
	UI.grad(wall, Color3.new(1, 1, 1), Color3.fromRGB(214, 216, 206), 90)
	local grout = Color3.fromRGB(198, 200, 192)
	for i = 1, 15 do
		box({ Parent = wall, Position = UDim2.fromOffset(i * 42, 0), Size = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = grout, ZIndex = 2 })
		box({ Parent = wall, Position = UDim2.new(0, i * 42 - 21, 0.5, 0), Size = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = grout, ZIndex = 2 })
	end
	box({ Parent = wall, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = grout, ZIndex = 2 })
	box({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.fromRGB(120, 126, 140), ZIndex = 2 })
	for i = 0, 10 do -- brushed steel
		box({ Position = UDim2.fromOffset(0, 84 + i * 24 + rng:NextInteger(-4, 4)), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, ZIndex = 1 })
	end

	-- the order ticket, clipped to the rail
	local rail = box({ Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(176, 8), BackgroundColor3 = Color3.fromRGB(150, 156, 170), ZIndex = 9 })
	UI.corner(rail, 4)
	local ticket = box({ Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(158, 210), BackgroundColor3 = PAPER, ZIndex = 10, Rotation = -2 })
	UI.corner(ticket, 4)
	UI.stroke(ticket, 1.5, Color3.fromRGB(210, 196, 170), 0)
	local clip = box({ Parent = ticket, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(34, 14), BackgroundColor3 = Color3.fromRGB(110, 116, 130), ZIndex = 12 })
	UI.corner(clip, 3)
	text(ticket, "ORDER", 11, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(134, 14), TextXAlignment = LEFT })
	text(ticket, dish, 19, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(12, 30), Size = UDim2.fromOffset(136, 42), TextWrapped = true, TextXAlignment = LEFT, TextYAlignment = Enum.TextYAlignment.Top })
	text(ticket, "for " .. (d.guest or "a guest"), 12, { TextColor3 = Color3.fromRGB(140, 130, 120), Position = UDim2.fromOffset(12, 72), Size = UDim2.fromOffset(134, 14), TextXAlignment = LEFT })
	for i = 0, 13 do
		box({ Parent = ticket, Position = UDim2.fromOffset(12 + i * 10, 94), Size = UDim2.fromOffset(6, 1), BackgroundColor3 = Color3.fromRGB(190, 176, 150), ZIndex = 11 })
	end
	local rows = {}
	for i, id in ipairs(items) do
		local y = 102 + (i - 1) * 26
		local chk = box({ Parent = ticket, Position = UDim2.fromOffset(12, y + 3), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 })
		UI.corner(chk, 4)
		UI.stroke(chk, 1.5, Color3.fromRGB(170, 156, 130), 0)
		local lab = text(ticket, FOOD[id] and FOOD[id][1] or id, 15, { FontFace = UI.F.heavy, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(36, y), Size = UDim2.fromOffset(110, 22), TextXAlignment = LEFT })
		local strike = box({ Parent = lab, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = T.greenDk, ZIndex = 13 })
		rows[i] = { chk = chk, lab = lab, strike = strike, at = Vector2.new(36, 10 + y + 11) }
	end
	local pills = {}
	for i, nm in ipairs({ "PREP", "CHOP", "COOK", "SERVE" }) do
		local pl = box({ Parent = ticket, Position = UDim2.fromOffset(10 + (i - 1) * 35, 184), Size = UDim2.fromOffset(33, 16), BackgroundColor3 = Color3.fromRGB(232, 222, 200), ZIndex = 11 })
		UI.corner(pl, 8)
		pills[i] = { f = pl, l = text(pl, nm, 9, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(160, 146, 120), Size = UDim2.fromScale(1, 1), ZIndex = 12 }) }
	end
	local function setStep(n)
		for i, pl in ipairs(pills) do
			pl.f.BackgroundColor3 = i < n and T.green or i == n and T.gold or Color3.fromRGB(232, 222, 200)
			pl.l.TextColor3 = i <= n and INK_TEXT or Color3.fromRGB(160, 146, 120)
		end
		pulse(pills[n].f, 1.25)
	end
	setStep(1)
	setProgress(0)

	-- whatever the current step put on the counter; swept away when the next one starts
	local stage = {}
	local function clearStage()
		for _, o in ipairs(stage) do
			if o.Parent then
				UI.tween(UI.scaleOf(o), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.delay(0.22, function() o:Destroy() end)
			end
		end
		table.clear(stage)
	end
	local function popIn(o, delay)
		local sc = UI.scaleOf(o)
		local to = sc.Scale
		sc.Scale = 0
		UI.tween(sc, 0.35, { Scale = to }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, delay or 0)
	end

	---------------- 1. prep: pick the ticket's ingredients off the shelf
	local bowls, got = {}, 0
	for i, id in ipairs(shelf) do
		local c = Vector2.new(270 + ((i - 1) % 3) * 126, 140 + ((i - 1) // 3) * 116)
		local bowl = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = Color3.fromRGB(236, 240, 246), ZIndex = 6 })
		UI.corner(bowl, ROUND)
		UI.grad(bowl, Color3.new(1, 1, 1), Color3.fromRGB(164, 167, 172), 120)
		UI.stroke(bowl, 2, Color3.fromRGB(124, 127, 132), 0.25)
		local inner = box({ Parent = bowl, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = Color3.fromRGB(196, 202, 214), ZIndex = 7 })
		UI.corner(inner, ROUND)
		UI.grad(inner, Color3.fromRGB(170, 176, 190), Color3.new(1, 1, 1), 120)
		local food = drawFood(id, bowl, Vector2.new(48, 45), 62, 8)
		local tag = box({ Parent = bowl, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(78, 18), BackgroundColor3 = T.ink, ZIndex = 9 })
		UI.corner(tag, 9)
		text(tag, FOOD[id] and FOOD[id][1] or id, 12, { FontFace = UI.F.black, Size = UDim2.fromScale(1, 1), ZIndex = 10 })
		bowls[i] = { obj = bowl, id = id, pos = c, food = food }
		table.insert(stage, bowl)
		popIn(bowl, 0.05 * i)
	end
	say("Grab the " .. #items .. " ingredients on the ticket")

	local function tickRow(i)
		local r = rows[i]
		r.done = true
		r.chk.BackgroundColor3 = T.green
		pulse(r.chk, 1.5)
		r.lab.TextColor3 = Color3.fromRGB(150, 140, 130)
		UI.tween(r.strike, 0.25, { Size = UDim2.fromOffset(r.lab.TextBounds.X + 4, 2) })
	end

	---------------- 2. chop: tap fast, the knife works across the board
	local CHOPS = 8
	local board, knife, pieces
	local chops = 0
	local function cutX(n) return CX - 150 + (n - 1) * (300 / (CHOPS - 1)) end
	local startCook, startPlate -- forward
	local function startChop()
		clearStage()
		setStep(2)
		chops = 0
		board = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX + 6, 226), Size = UDim2.fromOffset(364, 160), BackgroundColor3 = Color3.fromRGB(200, 146, 92), ZIndex = 6 })
		UI.corner(board, 16)
		UI.grad(board, Color3.fromRGB(255, 240, 220), Color3.fromRGB(190, 150, 110), 90)
		UI.stroke(board, 2, Color3.fromRGB(120, 76, 40), 0.2)
		for i = 0, 5 do
			box({ Parent = board, Position = UDim2.fromOffset(14, 18 + i * 25 + rng:NextInteger(-3, 3)), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = Color3.fromRGB(120, 76, 40), BackgroundTransparency = 0.7, ZIndex = 7 })
		end
		local hole = box({ Parent = board, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(170, 176, 190), ZIndex = 8 })
		UI.corner(hole, ROUND)
		table.insert(stage, board)
		popIn(board)
		pieces = {}
		for i, id in ipairs(items) do
			local f = drawFood(id, S.area, Vector2.new(CX - 112 + (i - 1) * 112, 226), 80, 10)
			pieces[i] = f
			table.insert(stage, f)
			popIn(f, 0.1 + i * 0.06)
		end
		knife = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(24, 150), Position = UDim2.fromOffset(cutX(1), 138), BackgroundTransparency = 1, ZIndex = 30, Parent = S.area })
		local blade = box({ Parent = knife, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(22, 98), BackgroundColor3 = Color3.fromRGB(226, 230, 238), ZIndex = 31 })
		UI.corner(blade, 4)
		UI.grad(blade, Color3.new(1, 1, 1), Color3.fromRGB(150, 156, 170), 0)
		UI.stroke(blade, 1, Color3.fromRGB(110, 116, 130), 0.3)
		box({ Parent = blade, Position = UDim2.new(1, -5, 0, 6), Size = UDim2.new(0, 3, 1, -12), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 32 })
		local handle = box({ Parent = knife, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(18, 54), BackgroundColor3 = Color3.fromRGB(64, 42, 30), ZIndex = 33 })
		UI.corner(handle, 6)
		for n = 0, 2 do
			local rivet = box({ Parent = handle, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 12 + n * 14), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.fromRGB(226, 206, 150), ZIndex = 34 })
			UI.corner(rivet, ROUND)
		end
		table.insert(stage, knife)
		say("Chop chop! Tap fast")
		step = "chop"
	end

	local function chop()
		chops += 1
		local n = chops
		local x = cutX(n)
		knife.Position = UDim2.fromOffset(x, 138)
		UI.tween(knife, 0.05, { Position = UDim2.fromOffset(x, 240) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.05, function()
			if not S then return end
			sound("chop")
			shake(board)
			local cut = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 226), Size = UDim2.fromOffset(3, 64), BackgroundColor3 = Color3.fromRGB(90, 56, 30), BackgroundTransparency = 0.4, ZIndex = 9 })
			table.insert(stage, cut)
			local near, nd = 1, math.huge
			for i, f in ipairs(pieces) do
				local px = f.Position.X.Offset
				if math.abs(px - x) < nd then near, nd = i, math.abs(px - x) end
				UI.tween(f, 0.12, { Position = UDim2.fromOffset(px + (px < x and -3 or 3), 226) })
			end
			local fd = FOOD[items[near]]
			burst(Vector2.new(x, 220), fd and fd[2] or T.gold, 7, 50)
			setProgress(0.25 + n / CHOPS * 0.25)
			if n < CHOPS then
				if chops == n then
					UI.tween(knife, 0.1, { Position = UDim2.fromOffset(cutX(n + 1), 138) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			else
				UI.tween(knife, 0.3, { Position = UDim2.fromOffset(x + 80, 40), Rotation = 30 })
				floatText(Vector2.new(CX, 140), "Chopped!", T.green)
				sound("select")
				task.delay(0.5, function() if S then startCook() end end)
			end
		end)
	end

	---------------- 3. cook: a doneness meter; flip (or stir) when it's in the gold, twice
	local panC = Vector2.new(CX - 60, 230)
	local panFood, meter, marker, zone, barGrad, sideLab, flames
	local k, dur, zc, zw, side, cooking = 0, 2.6, 0.6, 0.17, 1, false
	local fxAcc = 0

	local function sizzle()
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(26, 64)
		local p = panC + Vector2.new(math.cos(a) * r, math.sin(a) * r)
		local sz = rng:NextNumber(4, 7)
		local dot = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.fromRGB(255, 246, 200), ZIndex = 15 })
		UI.corner(dot, ROUND)
		local to = p + Vector2.new(rng:NextNumber(-8, 8), -rng:NextNumber(8, 20))
		UI.tween(dot, 0.3, { Position = UDim2.fromOffset(to.X, to.Y), BackgroundTransparency = 1 })
		task.delay(0.32, function() dot:Destroy() end)
		if rng:NextNumber() < 0.14 then -- a puff of steam
			local s = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(p.X, p.Y), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, ZIndex = 16 })
			UI.corner(s, ROUND)
			local up = p + Vector2.new(rng:NextNumber(-24, 24), -rng:NextNumber(70, 100))
			UI.tween(s, 1.1, { Position = UDim2.fromOffset(up.X, up.Y), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
			task.delay(1.15, function() s:Destroy() end)
		end
	end

	local function newSide()
		k = 0
		dur = side == 1 and 2.6 or 2.1
		zw = side == 1 and 0.17 or 0.14
		zc = rng:NextNumber(0.5, 0.74)
		local c = PAN[panKind]
		barGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c[1]), ColorSequenceKeypoint.new(zc, c[2]), ColorSequenceKeypoint.new(1, c[3]) })
		zone.Position = UDim2.fromScale(zc, 0)
		zone.Size = UDim2.new(zw, 0, 1, 0)
		pulse(zone, 1.3)
		sideLab.Text = (stir and "STIR " or "SIDE ") .. side .. " OF 2"
		panFood.BackgroundColor3 = c[1]
		cooking = true
		step = "cook"
	end

	local function flip(good, perfect, why)
		cooking = false
		step = "flipping"
		if not good then S.mistakes += 1 end
		sound("flip")
		if stir then
			UI.tween(panFood, 0.4, { Rotation = panFood.Rotation + 360 }, Enum.EasingStyle.Quad)
		else
			-- a toss: up, over and back down into the pan
			UI.tween(panFood, 0.18, { Position = UDim2.fromOffset(panC.X, panC.Y - 72), Rotation = panFood.Rotation + 180 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			UI.tween(UI.scaleOf(panFood), 0.18, { Scale = 1.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			task.delay(0.18, function()
				if not S then return end
				UI.tween(panFood, 0.18, { Position = UDim2.fromOffset(panC.X, panC.Y), Rotation = panFood.Rotation + 180 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				UI.tween(UI.scaleOf(panFood), 0.18, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end)
		end
		task.delay(0.38, function()
			if not S then return end
			sound("sizzle")
			for _ = 1, 8 do sizzle() end
			local col = perfect and T.gold or good and T.green or T.red
			burst(panC, col, perfect and 14 or 7, 100)
			floatText(panC - Vector2.new(0, 104), why or (perfect and "Perfect!" or "Golden!"), col)
			if not good then shake(panFood) end
			side += 1
			setProgress(0.5 + (side - 1) * 0.15)
			if side <= 2 then
				task.delay(0.35, function() if S then newSide() end end)
			else
				task.delay(0.45, function() if S then startPlate() end end)
			end
		end)
	end

	startCook = function()
		clearStage()
		setStep(3)
		local grate = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(panC.X, panC.Y), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = Color3.fromRGB(50, 51, 52), ZIndex = 4 })
		UI.corner(grate, ROUND)
		UI.stroke(grate, 3, Color3.fromRGB(33, 33, 34), 0)
		for a = 0, 3 do
			box({ Parent = grate, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 0, 7), Rotation = a * 45, BackgroundColor3 = Color3.fromRGB(31, 31, 32), ZIndex = 5 })
		end
		table.insert(stage, grate)
		flames = {}
		for i = 1, 16 do
			local a = i / 16 * math.pi * 2
			local f = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(panC.X + math.cos(a) * 88, panC.Y + math.sin(a) * 88), Size = UDim2.fromOffset(12, 18), Rotation = math.deg(a) + 90, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6 })
			UI.corner(f, ROUND)
			UI.grad(f, Color3.fromRGB(255, 196, 110), Color3.fromRGB(80, 140, 255), 90)
			flames[i] = f
			table.insert(stage, f)
		end
		local handle = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(panC.X + 44, panC.Y + 66), Size = UDim2.fromOffset(24, 130), Rotation = -24, BackgroundColor3 = Color3.fromRGB(44, 45, 46), ZIndex = 7 })
		UI.corner(handle, 10)
		UI.grad(handle, Color3.fromRGB(200, 200, 210), Color3.fromRGB(117, 118, 120), 0)
		local pan = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(panC.X, panC.Y), Size = UDim2.fromOffset(172, 172), BackgroundColor3 = Color3.fromRGB(84, 85, 88), ZIndex = 8 })
		UI.corner(pan, ROUND)
		UI.grad(pan, Color3.new(1, 1, 1), Color3.fromRGB(127, 128, 130), 120)
		UI.stroke(pan, 2, Color3.fromRGB(129, 131, 134), 0.2)
		local well = box({ Parent = pan, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(146, 146), BackgroundColor3 = Color3.fromRGB(51, 52, 54), ZIndex = 9 })
		UI.corner(well, ROUND)
		UI.grad(well, Color3.fromRGB(156, 158, 160), Color3.new(1, 1, 1), 120)
		panFood = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(panC.X, panC.Y), Size = UDim2.fromOffset(stir and 118 or 104, stir and 118 or 94), BackgroundColor3 = PAN[panKind][1], ZIndex = 12 })
		UI.corner(panFood, ROUND)
		UI.grad(panFood, Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205), 120)
		if panKind == "egg" then
			local yolk = box({ Parent = panFood, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.44, 0.46), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Color3.fromRGB(255, 186, 40), ZIndex = 13 })
			UI.corner(yolk, ROUND)
			UI.grad(yolk, Color3.new(1, 1, 1), Color3.fromRGB(220, 190, 150), 120)
		elseif stir then
			for i = 1, 5 do
				blob(panFood, 30 + (i * 37) % 60, 30 + (i * 23) % 60, 12, 8, Color3.fromRGB(242, 212, 120), ROUND, i * 40, 13, true)
			end
		end
		local shine = box({ Parent = panFood, Position = UDim2.fromScale(0.18, 0.16), Size = UDim2.fromScale(0.3, 0.14), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Rotation = -25, ZIndex = 14 })
		UI.corner(shine, ROUND)
		for _, o in ipairs({ handle, pan, panFood }) do
			table.insert(stage, o)
			popIn(o)
		end
		-- the doneness meter
		meter = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX + 4, 98), Size = UDim2.fromOffset(392, 50), BackgroundColor3 = T.ink, ZIndex = 20 })
		UI.corner(meter, 12)
		UI.stroke(meter, 2, T.gold, 0.3)
		sideLab = text(meter, "", 11, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(14, 5), Size = UDim2.fromOffset(120, 13), TextXAlignment = LEFT, ZIndex = 21 })
		text(meter, "GET IT GOLDEN", 10, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.new(1, -150, 0, 5), Size = UDim2.fromOffset(136, 13), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21 })
		local bar = box({ Parent = meter, Position = UDim2.fromOffset(14, 22), Size = UDim2.new(1, -28, 0, 18), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 21 })
		UI.corner(bar, 9)
		barGrad = Instance.new("UIGradient")
		barGrad.Parent = bar
		text(bar, "RAW", 9, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(120, 96, 70), Position = UDim2.fromOffset(8, 2), Size = UDim2.fromOffset(40, 14), TextXAlignment = LEFT, ZIndex = 22 })
		text(bar, "BURNT", 9, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(240, 226, 210), Position = UDim2.new(1, -56, 0, 2), Size = UDim2.fromOffset(48, 14), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22 })
		zone = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ZIndex = 22 })
		UI.corner(zone, 6)
		UI.stroke(zone, 3, T.gold, 0)
		marker = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(7, 30), BackgroundColor3 = T.cream, ZIndex = 23 })
		UI.corner(marker, 3)
		UI.stroke(marker, 2, T.shadow, 0.2)
		table.insert(stage, meter)
		popIn(meter, 0.1)
		sound("sizzle")
		side = 1
		newSide()
		say(stir and "Tap to stir when the sauce hits the gold!" or "Tap to flip it when it hits the gold!")
	end

	---------------- 4. serve: slide it onto the plate, then ring the bell
	local plateC = Vector2.new(CX + 138, 236)
	local bellC = Vector2.new(566, 112)
	local plate, bell
	startPlate = function()
		setStep(4)
		if meter then
			UI.tween(UI.scaleOf(meter), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local m = meter
			task.delay(0.22, function() m:Destroy() end)
		end
		plate = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W + 90, plateC.Y), Size = UDim2.fromOffset(138, 138), BackgroundColor3 = Color3.fromRGB(252, 252, 248), ZIndex = 8 })
		UI.corner(plate, ROUND)
		UI.grad(plate, Color3.new(1, 1, 1), Color3.fromRGB(214, 212, 204), 120)
		UI.stroke(plate, 1.5, Color3.fromRGB(196, 190, 176), 0)
		local rim = box({ Parent = plate, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(104, 104), BackgroundColor3 = Color3.fromRGB(246, 244, 238), ZIndex = 9 })
		UI.corner(rim, ROUND)
		UI.stroke(rim, 1.5, T.gold, 0.35)
		table.insert(stage, plate)
		UI.tween(plate, 0.4, { Position = UDim2.fromOffset(plateC.X, plateC.Y) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		sound("place")
		say("Tap the plate to serve it up")
		step = "plate"
	end

	local function serve()
		step = "serving"
		sound("place")
		-- the food arcs out of the pan onto the plate
		local mid = (panC + plateC) / 2 - Vector2.new(0, 90)
		UI.tween(panFood, 0.17, { Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = panFood.Rotation + 120 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.17, function()
			if not S then return end
			UI.tween(panFood, 0.17, { Position = UDim2.fromOffset(plateC.X, plateC.Y), Rotation = panFood.Rotation + 120 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			UI.tween(UI.scaleOf(panFood), 0.17, { Scale = 0.82 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(0.36, function()
			if not S then return end
			sound("tick")
			pulse(plate, 1.08)
			burst(plateC, T.gold, 8, 70)
			-- the rest of the ingredients go round it
			local n = 0
			for _, id in ipairs(items) do
				if id ~= panKind and not RAW_ONLY[id] then
					n += 1
					local a = math.rad(-150 + n * 115)
					local g = drawFood(id, S.area, plateC + Vector2.new(math.cos(a) * 48, math.sin(a) * 44), 38, 13)
					table.insert(stage, g)
					popIn(g, 0.05 * n)
				end
			end
			setProgress(0.9)
			-- the bell on the pass
			bell = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(bellC.X, bellC.Y), Size = UDim2.fromOffset(80, 64), BackgroundTransparency = 1, ZIndex = 20, Parent = S.area })
			local base = box({ Parent = bell, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(80, 11), BackgroundColor3 = Color3.fromRGB(70, 50, 36), ZIndex = 23 })
			UI.corner(base, 4)
			local hold = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -9), Size = UDim2.fromOffset(62, 34), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 21, Parent = bell })
			local dome = box({ Parent = hold, Size = UDim2.fromOffset(62, 66), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 22 })
			UI.corner(dome, ROUND)
			UI.grad(dome, Color3.fromRGB(255, 244, 200), Color3.fromRGB(206, 146, 44), 60)
			local glint = box({ Parent = hold, Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(10, 16), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Rotation = 30, ZIndex = 23 })
			UI.corner(glint, ROUND)
			local knob = box({ Parent = bell, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -41), Size = UDim2.fromOffset(12, 10), BackgroundColor3 = Color3.fromRGB(230, 180, 70), ZIndex = 21 })
			UI.corner(knob, ROUND)
			table.insert(stage, bell)
			UI.scaleOf(bell).Scale = 1.45
			popIn(bell)
			say("Ring the bell!")
			step = "bell"
		end)
	end

	local function ring()
		step = "done"
		sound("bell")
		shake(bell)
		UI.scaleOf(bell).Scale = 1.7
		UI.tween(UI.scaleOf(bell), 0.3, { Scale = 1.45 }, Enum.EasingStyle.Back)
		local ringFx = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(bellC.X, bellC.Y + 6), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, ZIndex = 19 })
		UI.corner(ringFx, ROUND)
		local st = UI.stroke(ringFx, 4, T.gold, 0)
		UI.tween(ringFx, 0.6, { Size = UDim2.fromOffset(170, 170) }, Enum.EasingStyle.Quad)
		UI.tween(st, 0.6, { Transparency = 1 })
		task.delay(0.62, function() ringFx:Destroy() end)
		burst(bellC, T.gold, 14, 110)
		floatText(Vector2.new(plateC.X - 30, 150), "Order up!", T.gold)
		setProgress(1)
		task.delay(0.45, win)
	end

	S.onDown = function(p)
		if step == "prep" then
			for _, b in ipairs(bowls) do
				if not b.used and (p - b.pos).Magnitude <= 50 then
					local i = table.find(items, b.id)
					if i and not rows[i].done then
						b.used = true
						got += 1
						sound("select")
						tickRow(i)
						-- the ingredient hops out of its bowl onto the ticket
						local f = b.food
						f.Parent = S.area
						f.ZIndex = 40
						setPos(f, b.pos)
						UI.tween(f, 0.35, { Position = UDim2.fromOffset(rows[i].at.X, rows[i].at.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						UI.tween(UI.scaleOf(f), 0.35, { Scale = 0.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						task.delay(0.36, function() f:Destroy() end)
						pulse(b.obj, 1.1)
						burst(b.pos, FOOD[b.id] and FOOD[b.id][2] or T.gold, 7, 54)
						setProgress(got / #items * 0.25)
						if got == #items then
							step = "wait"
							task.delay(0.45, function() if S then startChop() end end)
						end
					elseif not i then
						miss(b.obj, p, "No " .. string.lower(FOOD[b.id] and FOOD[b.id][1] or b.id) .. " in this!")
					end
					return
				end
			end
		elseif step == "chop" then
			if chops < CHOPS then chop() end
		elseif step == "cook" and cooking then
			local off = math.abs(k - zc)
			local good = off <= zw / 2
			flip(good, off <= zw / 6, not good and (k < zc and "Too soon!" or "Overdone!") or nil)
		elseif step == "plate" then
			if (p - plateC).Magnitude <= 80 or (p - panC).Magnitude <= 90 then serve() end
		elseif step == "bell" then
			if (p - bellC).Magnitude <= 56 then ring() end
		end
	end

	local t0 = os.clock()
	table.insert(S.conns, RunService.RenderStepped:Connect(function(dt)
		if not S then return end
		local t = os.clock() - t0
		if flames then
			for i, f in ipairs(flames) do
				if f.Parent then f.Size = UDim2.fromOffset(11 + math.sin(t * 23 + i * 1.7) * 2, 17 + math.sin(t * 31 + i * 2.3) * 5) end
			end
		end
		if step == "cook" and cooking then
			k += dt / dur
			marker.Position = UDim2.fromScale(math.min(k, 1), 0.5)
			local c = PAN[panKind]
			panFood.BackgroundColor3 = k < zc and c[1]:Lerp(c[2], k / zc) or c[2]:Lerp(c[3], math.clamp((k - zc) / (1 - zc), 0, 1))
			fxAcc += dt
			if fxAcc > 0.06 then
				fxAcc = 0
				sizzle()
			end
			if k >= 1 then flip(false, false, "Burnt!") end
		elseif step == "bell" and bell then
			UI.scaleOf(bell).Scale = 1.45 + math.sin(t * 7) * 0.07
		end
	end))
end

---------------------------------------------------------------- Repair (round 11): wires, bolts, power
-- A broken machine's Repair prompt (Upkeep): drag each loose wire to the terminal of its colour, tighten
-- the service cover's four bolts (two turns each), then throw the power lever back on.

local WIRES = {
	Color3.fromRGB(232, 72, 72), Color3.fromRGB(70, 140, 240), Color3.fromRGB(250, 200, 60), Color3.fromRGB(80, 200, 110),
}
local STEEL = Color3.fromRGB(150, 160, 178)

local function wireLine(obj, a, b)
	local d = b - a
	obj.Size = UDim2.fromOffset(d.Magnitude + 10, 10)
	obj.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	obj.Rotation = math.deg(math.atan2(d.Y, d.X))
end

local function playRepair()
	S.mistakes = 0
	S.area.BackgroundColor3 = Color3.fromRGB(70, 78, 96)
	UI.grad(S.area, Color3.fromRGB(255, 255, 255), Color3.fromRGB(179, 184, 190), 90)
	for i = 0, 16 do -- brushed metal
		box({ Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 8 + i * 20), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, ZIndex = 1 })
	end
	-- the wiring bay on the left, the power box on the right
	local bay = box({ Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(400, 312), BackgroundColor3 = Color3.fromRGB(38, 41, 44), ZIndex = 2 })
	UI.corner(bay, 12)
	UI.stroke(bay, 2, Color3.fromRGB(20, 22, 24), 0.2)
	text(bay, "WIRING", 12, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(100, 14), TextXAlignment = LEFT })
	local pbox = box({ Position = UDim2.fromOffset(428, 14), Size = UDim2.fromOffset(178, 312), BackgroundColor3 = Color3.fromRGB(50, 52, 56), ZIndex = 2 })
	UI.corner(pbox, 12)
	UI.stroke(pbox, 2, Color3.fromRGB(20, 22, 24), 0.2)
	text(pbox, "POWER", 12, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 14) })
	for _, c in ipairs({ Vector2.new(24, 24), Vector2.new(404, 24), Vector2.new(24, 316), Vector2.new(404, 316), Vector2.new(438, 24), Vector2.new(596, 24), Vector2.new(438, 316), Vector2.new(596, 316) }) do
		local r = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Color3.fromRGB(90, 98, 116), ZIndex = 3 })
		UI.corner(r, 4)
	end

	-- loose wires come in from the left; terminals of the same colours, shuffled, on the right
	local ys = { 70, 138, 206, 274 }
	local order = shuffle({ 1, 2, 3, 4 })
	local stubs, terms = {}, {}
	for i, col in ipairs(WIRES) do
		local y = ys[i]
		local cable = box({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(46, 10), BackgroundColor3 = col, ZIndex = 4 })
		UI.stroke(cable, 1.5, col:Lerp(Color3.new(0, 0, 0), 0.5), 0)
		local plug = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(64, y), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = col, ZIndex = 6 })
		UI.corner(plug, 13)
		UI.stroke(plug, 2, col:Lerp(Color3.new(0, 0, 0), 0.5), 0)
		local tip = box({ Parent = plug, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(230, 190, 110), ZIndex = 7 })
		UI.corner(tip, 5)
		stubs[i] = { col = col, pos = Vector2.new(64, y), plug = plug }
		local ty = ys[order[i]]
		local ring = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(360, ty), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(68, 71, 76), ZIndex = 4 })
		UI.corner(ring, 20)
		UI.stroke(ring, 3, col, 0.1)
		local dot = box({ Parent = ring, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(27, 28, 30), ZIndex = 5 })
		UI.corner(dot, 7)
		local lead = box({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(380, ty), Size = UDim2.fromOffset(34, 6), BackgroundColor3 = col:Lerp(Color3.new(0, 0, 0), 0.25), ZIndex = 3 })
		UI.corner(lead, 3)
		terms[i] = { col = col, pos = Vector2.new(360, ty), ring = ring }
	end

	-- the power box: a lamp and a lever
	local lamp = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(517, 74), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = T.red, ZIndex = 4 })
	UI.corner(lamp, 20)
	UI.stroke(lamp, 3, Color3.fromRGB(27, 28, 30), 0.1)
	local glow = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(517, 74), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = T.red, BackgroundTransparency = 0.75, ZIndex = 3 })
	UI.corner(glow, 35)
	local lampText = text(pbox, "OFF", 14, { FontFace = UI.F.black, TextColor3 = T.red, Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 18) })
	local slot = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(517, 140), Size = UDim2.fromOffset(22, 150), BackgroundColor3 = Color3.fromRGB(23, 24, 26), ZIndex = 4 })
	UI.corner(slot, 11)
	local LEVER_UP, LEVER_DOWN = 156, 274
	local knob = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(517, LEVER_UP), Size = UDim2.fromOffset(78, 34), BackgroundColor3 = Color3.fromRGB(200, 60, 54), ZIndex = 6 })
	UI.corner(knob, 10)
	UI.grad(knob, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 170), 90)
	local knobStroke = UI.stroke(knob, 2, Color3.fromRGB(70, 20, 20), 0.1)
	text(pbox, "ON", 12, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(0, 282), Size = UDim2.new(1, 0, 0, 14), ZIndex = 5 })

	local step, connected, drag = "wires", 0, nil
	local bolts, tight = {}, 0
	say("Drag each wire to the terminal of its colour")
	setProgress(0)

	local function startBolts()
		step = "bolts"
		say("Tighten the four bolts on the cover")
		sound("open")
		local cover = box({ Position = UDim2.fromOffset(14, -330), Size = UDim2.fromOffset(400, 312), BackgroundColor3 = STEEL, ZIndex = 10 })
		UI.corner(cover, 12)
		UI.stroke(cover, 2, Color3.fromRGB(74, 77, 82), 0.1)
		UI.grad(cover, Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 184, 204), 90)
		for i = 0, 5 do -- vents
			local v = box({ Parent = cover, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(200, 106 + i * 20), Size = UDim2.fromOffset(220, 8), BackgroundColor3 = Color3.fromRGB(46, 52, 66), ZIndex = 11 })
			UI.corner(v, 4)
		end
		text(cover, "SERVICE PANEL", 14, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(74, 77, 82), Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 18), ZIndex = 11 })
		UI.tween(cover, 0.35, { Position = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
		for _, c in ipairs({ Vector2.new(46, 46), Vector2.new(382, 46), Vector2.new(46, 294), Vector2.new(382, 294) }) do
			local seat = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(70, 78, 96), BackgroundTransparency = 1, ZIndex = 12 })
			UI.corner(seat, 20)
			local ring = UI.stroke(seat, 3, T.gold, 1)
			local b = box({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X + 3, c.Y - 4), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(214, 220, 232), ZIndex = 13, Rotation = rng:NextNumber(10, 50) })
			UI.corner(b, 7)
			UI.stroke(b, 2, Color3.fromRGB(80, 88, 106), 0)
			box({ Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 4), BackgroundColor3 = Color3.fromRGB(70, 78, 96), ZIndex = 14 })
			local sc = UI.scaleOf(b)
			sc.Scale = 0
			UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.3)
			table.insert(bolts, { obj = b, ring = ring, seat = seat, pos = c, turns = 0 })
		end
	end

	local function startLever()
		step = "lever"
		say("Switch the power back on")
		knobStroke.Color = T.gold
		knobStroke.Thickness = 3
	end

	S.onDown = function(p)
		if step == "wires" then
			for _, s in ipairs(stubs) do
				if not s.done and (p - s.pos).Magnitude < 24 then
					local line = box({ AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = s.col, ZIndex = 5 })
					UI.corner(line, 5)
					UI.stroke(line, 1.5, s.col:Lerp(Color3.new(0, 0, 0), 0.5), 0)
					box({ Parent = line, Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, ZIndex = 6 })
					wireLine(line, s.pos, p)
					drag = { s = s, line = line }
					s.plug.ZIndex = 8
					sound("select")
					return
				end
			end
		elseif step == "bolts" then
			for _, b in ipairs(bolts) do
				if b.turns < 2 and (p - b.pos).Magnitude < 26 then
					b.turns += 1
					UI.tween(b.obj, 0.18, { Rotation = b.obj.Rotation + 90, Position = UDim2.fromOffset(b.pos.X + (b.turns == 2 and 0 or 1.5), b.pos.Y - (b.turns == 2 and 0 or 2)), Size = UDim2.fromOffset(b.turns == 2 and 28 or 30, b.turns == 2 and 28 or 30) }, Enum.EasingStyle.Back)
					sound("turn")
					if b.turns == 2 then
						tight += 1
						b.ring.Transparency = 0.1
						b.ring.Color = T.green
						burst(b.pos, STEEL, 6, 40)
						sound("tick")
						setProgress(0.5 + tight / 4 * 0.35)
						if tight == 4 then task.delay(0.25, function() if S then startLever() end end) end
					end
					return
				end
			end
		elseif step == "lever" and hitRect(p, Vector2.new(517, LEVER_UP), Vector2.new(96, 54)) then
			step = "done"
			knob.Rotation = 0
			knobStroke.Color = Color3.fromRGB(20, 70, 30)
			UI.tween(knob, 0.18, { Position = UDim2.fromOffset(517, LEVER_DOWN), BackgroundColor3 = Color3.fromRGB(70, 180, 96) }, Enum.EasingStyle.Back)
			sound("place")
			task.delay(0.15, function()
				if not S then return end
				lamp.BackgroundColor3 = T.green
				glow.BackgroundColor3 = T.green
				lampText.Text = "ON"
				lampText.TextColor3 = T.green
				pulse(lamp, 1.4)
				burst(Vector2.new(517, 74), T.green, 14, 90)
				sound("register")
				setProgress(1)
				task.delay(0.35, win)
			end)
		end
	end
	S.onMove = function(p)
		if drag then wireLine(drag.line, drag.s.pos, p) end
	end
	S.onUp = function(p)
		if not drag then return end
		local d = drag
		drag = nil
		d.s.plug.ZIndex = 6
		for _, t in ipairs(terms) do
			if p and (p - t.pos).Magnitude < 28 and not t.done then
				if t.col == d.s.col then
					t.done, d.s.done = true, true
					wireLine(d.line, d.s.pos, t.pos)
					UI.tween(d.s.plug, 0.2, { Position = UDim2.fromOffset(t.pos.X, t.pos.Y) }, Enum.EasingStyle.Back)
					pulse(t.ring, 1.3)
					burst(t.pos, T.gold, 10, 50)
					sound("place")
					connected += 1
					setProgress(connected / 4 * 0.5)
					if connected == 4 then
						floatText(Vector2.new(210, 170), "All wired!", T.green)
						task.delay(0.45, function() if S then startBolts() end end)
					end
				else
					miss(t.ring, t.pos, "Wrong colour!")
					burst(t.pos, T.red, 8, 40)
					d.line:Destroy()
				end
				return
			end
		end
		d.line:Destroy()
	end
	-- loose wires spark now and then
	local acc = 0
	table.insert(S.conns, RunService.Heartbeat:Connect(function(dt)
		if not S then return end
		if step == "lever" then knob.Rotation = math.sin(os.clock() * 8) * 2 end
		if step ~= "wires" then return end
		acc += dt
		if acc > 0.45 then
			acc = 0
			local live = {}
			for _, s in ipairs(stubs) do if not s.done and not (drag and drag.s == s) then table.insert(live, s) end end
			if #live > 0 then burst(live[rng:NextInteger(1, #live)].pos + Vector2.new(10, 0), Color3.fromRGB(255, 230, 120), 4, 26) end
		end
	end))
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
		V = { vp = vp, wm = wm, cam = cam, tanY = math.tan(math.rad(cam.FieldOfView) / 2) }
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
		-- the player's own arm: while a game holds something (V.hand = a model or part, V.handOff = a grip point in
		-- its space, or V.handPos = a world point), your avatar's right arm (a copy of your character with
		-- everything else hidden, so your shirt and skin show) reaches in from the lower right and holds it
		local rig, armParts, armLen
		-- round 14 (2026-11-09): a built arm instead of a clone of the avatar (the clone dragged in packages, odd
		-- mesh sizes and accessories, and glitched): a rolled uniform sleeve, the forearm in your skin tone and a
		-- yellow rubber cleaning glove whose fingers curl round what you hold. deco = parts riding on an arm part
		-- (fromEnd = offset from the part's hand end, for the stretching sleeve)
		local deco = {}
		do
			local char = Players.LocalPlayer.Character
			local skinP = char and (char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm"))
			local skin = skinP and skinP.Color or Color3.fromRGB(234, 184, 146)
			local GLOVE, GLOVE2 = Color3.fromRGB(255, 204, 58), Color3.fromRGB(255, 226, 120)
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
					p.Shape = Enum.PartType.Cylinder -- along X: laid along the arm by its deco offset
				elseif shape == "bone" then
					p.Transparency = 1
				elseif shape == "ball" then
					p.Shape = Enum.PartType.Ball
				end
				p.Parent = rig
				return p
			end
			-- a long arm and a modest hand: the arm is drawn nearer the camera the longer it is, so the glove stays small on screen
			local sleeve = mk(Vector3.new(0.78, 2.4, 0.78), SLEEVE, "bone")
			local fore = mk(Vector3.new(0.56, 1.7, 0.56), skin, "bone")
			local glove = mk(Vector3.new(0.8, 0.95, 0.48), GLOVE)
			glove:SetAttribute("Grip", 0.06) -- the held thing sits just past the fingertips (was the palm, which hid it)
			armParts = { sleeve, fore, glove }
			for _, p in ipairs(armParts) do p:SetAttribute("BaseLen", p.Size.Y) end
			armLen = 0
			for _, p in ipairs(armParts) do armLen += p.Size.Y end
			local function add(base, p, cf, fromEnd, stretch) table.insert(deco, { base = base, p = p, cf = cf, fromEnd = fromEnd, stretch = stretch }) end
			local ROLL = CFrame.Angles(0, 0, math.pi / 2)
			add(sleeve, mk(Vector3.new(2.4, 0.78, 0.78), SLEEVE, "cyl"), ROLL, false, true)
			add(fore, mk(Vector3.new(1.75, 0.56, 0.56), skin, "cyl"), ROLL)
			add(fore, mk(Vector3.new(0.6, 0.6, 0.6), skin, "ball"), CFrame.new(0, 0.85, 0))
			add(sleeve, mk(Vector3.new(0.3, 0.88, 0.88), SHIRT, "cyl"), CFrame.new(0, 0.12, 0) * ROLL, true)
			add(sleeve, mk(Vector3.new(0.08, 0.81, 0.81), Color3.fromRGB(240, 184, 70), "cyl"), CFrame.new(0, 0.4, 0) * ROLL, true)
			add(glove, mk(Vector3.new(0.9, 0.34, 0.62), GLOVE2), CFrame.new(0, 0.52, 0))
			for k = 0, 3 do
				local x = -0.27 + k * 0.18
				add(glove, mk(Vector3.new(0.24, 0.24, 0.24), GLOVE, "ball"), CFrame.new(x, -0.46, 0.04))
				add(glove, mk(Vector3.new(0.17, 0.3, 0.2), GLOVE), CFrame.new(x, -0.58, -0.14) * CFrame.Angles(math.rad(-55), 0, 0))
				add(glove, mk(Vector3.new(0.17, 0.22, 0.18), GLOVE), CFrame.new(x, -0.56, -0.34) * CFrame.Angles(math.rad(-110), 0, 0))
			end
			add(glove, mk(Vector3.new(0.24, 0.5, 0.24), GLOVE), CFrame.new(-0.45, -0.22, -0.12) * CFrame.Angles(math.rad(-30), 0, math.rad(28)))
			add(glove, mk(Vector3.new(0.22, 0.22, 0.22), GLOVE, "ball"), CFrame.new(-0.52, -0.46, -0.24))
		end
		local at
		local function place(p, centre, u, side)
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
			if not grip then
				rig.Parent = nil
				at = nil
				return
			end
			-- round 14: no more stretching. The arm keeps its real length and is drawn nearer the camera (like a
			-- first-person arm): the hand sits over the grip on screen, at the depth where the arm's own length just
			-- reaches a shoulder point below the bottom edge of the screen
			local c = cam.CFrame
			local rel = c:PointToObjectSpace(grip)
			local gz = math.max(-rel.Z, 0.5)
			local tanVp = math.tan(math.rad(cam.FieldOfView) / 2)
			local aspect = vp.AbsoluteSize.X / math.max(vp.AbsoluteSize.Y, 1)
			local sx, sy = rel.X / (gz * tanVp), rel.Y / (gz * tanVp) -- screen point, in half-heights
			-- round 14: keep the hand on screen and never let it balloon towards the camera (it used to fill the
			-- screen when the pointer went to an edge or over the top bar)
			sx = math.clamp(sx, -aspect * 0.92, aspect * 0.92)
			sy = math.clamp(sy, -0.9, 0.82)
			local ex, ey = math.clamp(sx + 0.75, aspect * 0.35, aspect * 1.08), -1.32
			local dn = math.max(math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2), 0.3)
			local zMin = (armLen or 3) / (2.4 * tanVp)
			local z = math.clamp((armLen or 3) / (dn * tanVp), math.min(zMin, gz * 0.97), gz * 0.97)
			local handPt = c:PointToWorldSpace(Vector3.new(sx * z * tanVp, sy * z * tanVp, -z))
			local shoulder = c:PointToWorldSpace(Vector3.new(ex * z * tanVp, ey * z * tanVp, -z))
			if not at then at = handPt end
			at = at:Lerp(handPt, 1 - math.exp(-dt * 24))
			local d = at - shoulder
			if d.Magnitude < 0.5 then return end
			local u = d.Unit
			local side = -c.LookVector
			-- hand at the grip, then forearm and upper arm back toward the shoulder
			local p = at
			local lower = 0
			for i = 2, #armParts do lower += armParts[i]:GetAttribute("BaseLen") end
			for i = #armParts, 1, -1 do
				local part = armParts[i]
				local L = part:GetAttribute("BaseLen")
				if i == 1 then
					-- the upper arm (or a one-piece R6 arm) reaches all the way to the shoulder below the screen
					L = math.max(L, d.Magnitude - lower + ((#armParts == 1) and L * 0.35 or 0))
					if math.abs(part.Size.Y - L) > 0.01 then part.Size = Vector3.new(part.Size.X, L, part.Size.Z) end
				end
				local back = (i == #armParts) and L * (part:GetAttribute("Grip") or 0.35) or 0
				local centre = p - u * (L / 2 - back)
				place(part, centre, u, side)
				p = centre - u * L / 2
			end
			for _, dd in ipairs(deco) do
				if dd.stretch then
					local L = dd.base.Size.Y
					if math.abs(dd.p.Size.X - L) > 0.01 then dd.p.Size = Vector3.new(L, dd.p.Size.Y, dd.p.Size.Z) end
					dd.p.CFrame = dd.base.CFrame * dd.cf
				elseif dd.fromEnd then
					dd.p.CFrame = dd.base.CFrame * CFrame.new(0, -dd.base.Size.Y / 2, 0) * dd.cf
				else
					dd.p.CFrame = dd.base.CFrame * dd.cf
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

	-- scrubbing (shower glass, toilet bowl): spots lose "hp" as the tool rubs over them
	local function scrubSpots(spots, radius, sfxName, onClean)
		local last, lastSfx, lastFx = nil, 0, 0
		local cleaned = 0
		return function(at)
			if not at then return end
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
					if now - lastFx > 0.07 then
						lastFx = now
						bubbles(toArea(s.pos), 1)
					end
					if now - lastSfx > 0.28 then
						lastSfx = now
						sound(sfxName)
					end
					if s.hp <= 0 then
						cleaned += 1
						for _, b in ipairs(s.parts) do tw(b[1], 0.2, { Transparency = 1 }) end
						burst(toArea(s.pos), T.cream, 6, 40)
						setProgress(cleaned / #spots * 0.85)
						if cleaned == #spots then onClean() end
					end
				end
			end
		end, function() last = nil end
	end

	---------------------------------------------------------------- Floor: pick up the litter
	local LITTER3 = { bottle = "r", can = "r", paper = "r", banana = "t", wrapper = "t", apple = "t" }

	local function litter(kind)
		local m = model(kind)
		if kind == "bottle" then
			local g = Color3.fromRGB(96, 182, 132)
			local b = cylX(1.5, 0.6, CFrame.new(0, 0.3, 0), g, Enum.Material.Glass, m)
			b.Transparency = 0.15
			cylX(0.62, 0.62, CFrame.new(-0.1, 0.3, 0), Color3.fromRGB(244, 236, 214), SMOOTH, m)
			cylX(0.5, 0.3, CFrame.new(0.95, 0.3, 0), g, Enum.Material.Glass, m).Transparency = 0.15
			cylX(0.14, 0.34, CFrame.new(1.25, 0.3, 0), Color3.fromRGB(60, 110, 220), SMOOTH, m)
		elseif kind == "can" then
			cylX(1.05, 0.64, CFrame.new(0, 0.32, 0), Color3.fromRGB(210, 40, 48), METAL, m)
			for i = -1, 1, 2 do cylX(0.07, 0.6, CFrame.new(0.53 * i, 0.32, 0), CHROME, METAL, m) end
			cylX(0.3, 0.65, CFrame.new(0, 0.32, 0), Color3.fromRGB(250, 250, 250), SMOOTH, m)
		elseif kind == "paper" then
			local c = Color3.fromRGB(246, 242, 230)
			ball(0.95, CFrame.new(0, 0.46, 0), c, FABRIC, m)
			ball(0.55, CFrame.new(0.32, 0.55, 0.15), c, FABRIC, m)
			ball(0.5, CFrame.new(-0.26, 0.6, -0.2), Color3.fromRGB(232, 228, 214), FABRIC, m)
			ball(0.42, CFrame.new(0.05, 0.75, 0.3), c, FABRIC, m)
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
		end
		return done(m)
	end

	G3.Floor = function()
		scene({ cam = CFrame.lookAt(Vector3.new(0, 14.5, 13.5), Vector3.new(0, 0.3, 0.6)), fov = 40, bg = Color3.fromRGB(60, 50, 44) })
		roomSet({ wallZ = -9 })
		local rugB = part(Vector3.new(13.2, 0.06, 7.2), CFrame.new(0, 0.03, -1.4), T.gold)
		rugB.CanQuery = false
		local rug = part(Vector3.new(12.6, 0.08, 6.6), CFrame.new(0, 0.05, -1.4), Color3.fromRGB(30, 96, 90), FABRIC)
		rug.CanQuery = false
		item("Plant", CFrame.new(-10, 0, -7.2))
		item("FloorLamp", CFrame.new(9.5, 0, -7.6))
		item("Sofa", CFrame.new(0, 0, -7.4))
		-- the bins: the lobby bin (trash) and a blue recycling bin
		local bins = {}
		local tb = item("LobbyBin", CFrame.new(-6.6, 0, 4.0), 1.35)
		bins.t = { pos = Vector3.new(-6.6, 0, 4.0), top = 4.05, col = T.green, name = "TRASH", m = tb }
		local rb = model("Recycle")
		cyl(3.5, 2.4, CFrame.new(6.6, 1.75, 4.0), Color3.fromRGB(52, 120, 210), SMOOTH, rb)
		cyl(0.5, 2.46, CFrame.new(6.6, 2.3, 4.0), Color3.fromRGB(240, 244, 250), SMOOTH, rb)
		cyl(0.26, 2.62, CFrame.new(6.6, 3.5, 4.0), Color3.fromRGB(36, 84, 160), SMOOTH, rb)
		cyl(0.06, 2.1, CFrame.new(6.6, 3.62, 4.0), Color3.fromRGB(16, 22, 34), SMOOTH, rb)
		for _, p in ipairs(partsOf(rb)) do p.CanQuery = false end
		bins.r = { pos = Vector3.new(6.6, 0, 4.0), top = 3.65, col = T.blue, name = "RECYCLE", m = rb }
		-- round 15: most of the time food scraps go in a third bin, COMPOST, front and centre
		local compost = rng:NextNumber() < 0.65
		if compost then
			local cb = model("Compost")
			cyl(2.9, 2.2, CFrame.new(0, 1.45, 5.4), Color3.fromRGB(64, 146, 74), SMOOTH, cb)
			cyl(0.4, 2.26, CFrame.new(0, 1.9, 5.4), Color3.fromRGB(236, 240, 228), SMOOTH, cb)
			cyl(0.28, 2.42, CFrame.new(0, 3.0, 5.4), Color3.fromRGB(96, 70, 44), SMOOTH, cb)
			cyl(0.06, 1.9, CFrame.new(0, 3.12, 5.4), Color3.fromRGB(30, 22, 16), SMOOTH, cb)
			for _, p in ipairs(partsOf(cb)) do p.CanQuery = false end
			bins.c = { pos = Vector3.new(0, 0, 5.4), top = 3.15, col = T.green, name = "COMPOST", m = cb }
			bins.t.col = Color3.fromRGB(156, 158, 160)
		end
		for _, b in pairs(bins) do
			shadow(b.pos.X, b.pos.Z, 3.1)
			b.ring = cyl(0.03, 3.8, CFrame.new(b.pos.X, 0.06, b.pos.Z), b.col, SMOOTH)
			b.ring.Transparency = 1
			b.ring.CanQuery = false
			b.label = tag3(b.pos + Vector3.new(0, b.top + 0.9, 0), b.name, b.col, 15, 110)
		end
		-- 5 pieces, recycling and rubbish, spread over the floor
		local kinds = { "bottle", "can", "paper", "banana", "wrapper", "apple" }
		local list = { "bottle", "banana", kinds[rng:NextInteger(2, 3)], kinds[rng:NextInteger(5, 6)], kinds[rng:NextInteger(1, 6)] }
		-- round 15: a messier room now and then (5 to 7 pieces)
		for _ = 1, rng:NextInteger(0, 2) do table.insert(list, kinds[rng:NextInteger(1, 6)]) end
		local function binOf(k) if compost and (k == "banana" or k == "apple") then return "c" end return LITTER3[k] end
		local items, owner, pickList, gone = {}, {}, {}, 0
		for i, k in ipairs(list) do
			local pos
			for _ = 1, 40 do
				pos = Vector3.new(rng:NextNumber(-4.6, 4.6), 0, rng:NextNumber(-4.0, 1.8))
				local ok = true
				for _, o in ipairs(items) do if (o.home.Position - pos).Magnitude < 2.6 then ok = false end end
				if ok then break end
			end
			local m = litter(k)
			m:ScaleTo(1.6)
			local home = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			m:PivotTo(home * CFrame.new(0, 6, 0))
			tweenPivot(m, home, 0.45 + i * 0.04, Enum.EasingStyle.Bounce)
			local it = { m = m, kind = binOf(k), home = home, sh = shadow(pos.X, pos.Z, 1.8) }
			table.insert(items, it)
			for _, p in ipairs(partsOf(m)) do owner[p] = it; table.insert(pickList, p) end
		end
		say(compost and "Sort it: trash, recycling and food scraps" or "Drag each piece into the right bin")
		local held
		local function near(pos)
			for k, b in pairs(bins) do
				if Vector3.new(pos.X - b.pos.X, 0, pos.Z - b.pos.Z).Magnitude < 2.5 then return k, b end
			end
		end
		S.onDown = function(p)
			local r = pick(p, pickList)
			local it = r and owner[r.Instance]
			if it and not it.gone then
				held = it
				V.hand, V.handOff = it.m, Vector3.new(0, 0.35, 0)
				sound("select")
				S.onMove(p)
			end
		end
		S.onMove = function(p)
			if not held then return end
			local w = onPlane(p, Vector3.new(0, 1.6, 0), UP)
			if not w then return end
			w = Vector3.new(math.clamp(w.X, -10, 10), 1.6, math.clamp(w.Z, -6.5, 6.5))
			local t = os.clock()
			held.m:PivotTo(CFrame.new(w) * held.home.Rotation * CFrame.Angles(math.sin(t * 9) * 0.12, 0, math.cos(t * 7) * 0.12))
			held.sh.CFrame = CFrame.new(w.X, 0.025, w.Z) * CFrame.Angles(0, 0, math.rad(90))
			held.sh.Size = Vector3.new(0.02, 1.3, 1.3)
			local k = near(w)
			for key, b in pairs(bins) do b.ring.Transparency = key == k and 0.35 or 1 end
		end
		S.onUp = function()
			local it = held
			held = nil
			V.hand = nil
			if not it then return end
			for _, b in pairs(bins) do b.ring.Transparency = 1 end
			local at = it.m:GetPivot().Position
			local k, b = near(at)
			if k and k == it.kind then
				it.gone = true
				it.sh:Destroy()
				tweenPivot(it.m, CFrame.new(b.pos.X, b.top + 1.2, b.pos.Z) * it.home.Rotation, 0.14)
				task.delay(0.14, function()
					if not S then return end
					tweenPivot(it.m, CFrame.new(b.pos.X, b.top - 1.4, b.pos.Z) * it.home.Rotation * CFrame.Angles(1.4, 0, 0), 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(0.2, function()
						it.m:Destroy()
						if not S then return end
						pulse(b.label, 1.3)
						burst(toArea(b.pos + Vector3.new(0, b.top + 0.4, 0)), b.col, 8)
					end)
				end)
				gone += 1
				floatText(toArea(b.pos + Vector3.new(0, b.top + 2.4, 0)), gone == #items and "All done!" or "+1", T.green)
				sound("place")
				setProgress(gone / #items)
				if gone == #items then task.delay(0.45, win) end
			elseif k then
				shake(b.label)
				floatText(toArea(b.pos + Vector3.new(0, b.top + 2.4, 0)), it.kind == "c" and "Compost that!" or it.kind == "r" and "Recycle that!" or k == "c" and "Not food!" or "Not recyclable!", T.red)
				S.mistakes = (S.mistakes or 0) + 1
				S.t0 -= 1
				sound("error")
				tweenPivot(it.m, it.home, 0.35, Enum.EasingStyle.Back)
				it.sh.CFrame = CFrame.new(it.home.X, 0.025, it.home.Z) * CFrame.Angles(0, 0, math.rad(90))
				it.sh.Size = Vector3.new(0.02, 1.8, 1.8)
			else
				-- dropped on the floor: it stays there
				local cf = CFrame.new(at.X, 0, at.Z) * it.home.Rotation
				it.home = cf
				tweenPivot(it.m, cf, 0.22, Enum.EasingStyle.Bounce)
				it.sh.Size = Vector3.new(0.02, 1.8, 1.8)
				sound("place")
			end
		end
	end

	---------------------------------------------------------------- Bed: pillows, blanket, wrinkles
	G3.Bed = function()
		scene({ cam = CFrame.lookAt(Vector3.new(0, 11, 11.5), Vector3.new(0, 1.9, -0.6)), fov = 40, bg = Color3.fromRGB(60, 50, 44) })
		roomSet({ wallZ = -6.2, wall = Color3.fromRGB(214, 200, 176) })
		local rug = part(Vector3.new(13, 0.08, 9), CFrame.new(0, 0.04, 1.5), Color3.fromRGB(150, 52, 52), FABRIC)
		rug.CanQuery = false
		for i = -1, 1, 2 do item("Nightstand", CFrame.new(5.5 * i, 0, -4.6)) end
		local WOOD = Color3.fromRGB(110, 70, 44)
		local frame = model("BedFrame")
		part(Vector3.new(7.6, 1.1, 10.2), CFrame.new(0, 0.75, -0.2), WOOD, WOODM, frame)
		part(Vector3.new(8, 4.4, 0.5), CFrame.new(0, 2.4, -5.2), WOOD, WOODM, frame)
		cylX(8, 0.7, CFrame.new(0, 4.6, -5.2), Color3.fromRGB(96, 60, 36), WOODM, frame)
		part(Vector3.new(6.8, 2.6, 0.2), CFrame.new(0, 2.9, -4.92), Color3.fromRGB(48, 74, 110), FABRIC, frame)
		for r = 0, 1 do
			for c = -2, 2 do ball(0.18, CFrame.new(c * 1.25, 2.3 + r * 1.2, -4.8), Color3.fromRGB(30, 46, 72), SMOOTH, frame) end
		end
		part(Vector3.new(7.8, 1.9, 0.4), CFrame.new(0, 1.15, 5.0), WOOD, WOODM, frame)
		part(Vector3.new(7, 1, 9.6), CFrame.new(0, 1.8, -0.2), Color3.fromRGB(250, 246, 238), FABRIC, frame)
		for _, p in ipairs(partsOf(frame)) do p.CanQuery = false end
		shadow(0, -0.2, 10)

		-- pillows start squashed; three taps each fluffs them up
		local pillows = {}
		for i, x in ipairs({ -1.6, 1.6 }) do
			local home = CFrame.new(x, 2.5, -3.9) * CFrame.Angles(0.25, i == 1 and 0.18 or -0.22, i == 1 and 0.12 or -0.1)
			local p = ell(Vector3.new(2.8, 0.45, 1.5), home, Color3.fromRGB(252, 250, 246), FABRIC)
			table.insert(pillows, { p = p, x = x, taps = 0 })
		end
		-- the blanket: its top edge (zt) moves from START up to the gold line at TARGET
		local START, TARGET, FOOT = 1.9, -2.5, 4.6
		local zt = START
		local BLUE = Color3.fromRGB(52, 118, 108)
		local blanket = part(Vector3.new(7.2, 0.36, FOOT - zt), CFrame.new(0, 2.44, (FOOT + zt) / 2), BLUE, FABRIC)
		part(Vector3.new(7.2, 1.5, 0.32), CFrame.new(0, 1.8, FOOT + 0.1), BLUE, FABRIC).CanQuery = false
		for _, z in ipairs({ 3.5, 3.9 }) do part(Vector3.new(7.22, 0.37, 0.14), CFrame.new(0, 2.44, z), T.gold, FABRIC).CanQuery = false end
		local cuff = part(Vector3.new(7.24, 0.5, 0.9), CFrame.new(0, 2.5, zt + 0.45), Color3.fromRGB(250, 246, 238), FABRIC)
		local guide = part(Vector3.new(6.6, 0.04, 0.14), CFrame.new(0, 2.32, TARGET), T.gold, Enum.Material.Neon)
		guide.Transparency = 1
		guide.CanQuery = false
		local function sizeBlanket()
			blanket.Size = Vector3.new(7.2, 0.36, FOOT - zt)
			blanket.CFrame = CFrame.new(0, 2.44, (FOOT + zt) / 2)
			cuff.CFrame = CFrame.new(0, 2.5, zt + 0.45)
		end
		local phase = 1
		local wrinkles = {}
		say("Tap the pillows to fluff them up")
		local fluffed = 0
		local function startWrinkles()
			phase = 3
			say("Rub out the wrinkles")
			for i = 1, 3 do
				local z = TARGET + 1.2 + (i - 1) * ((FOOT - 0.8 - TARGET - 1.2) / 2)
				local x = rng:NextNumber(-1.8, 1.8)
				local len = rng:NextNumber(2.4, 3.8)
				local yaw = rng:NextNumber(-0.5, 0.5)
				local cf = CFrame.new(x, 2.64, z) * CFrame.Angles(0, yaw, 0)
				local w = ell(Vector3.new(len, 0.24, 0.34), cf, Color3.fromRGB(38, 92, 84), FABRIC)
				w.CanQuery = false
				local dir = cf.RightVector
				table.insert(wrinkles, { p = w, a = cf.Position - dir * len / 2, b = cf.Position + dir * len / 2, hp = 2, max = 2 })
			end
		end
		local dragging, grabOff, lastW = false, 0, nil
		local smoothed = 0
		S.onDown = function(p)
			if phase == 1 then
				local r = pick(p, { pillows[1].p, pillows[2].p })
				for _, pl in ipairs(pillows) do
					if r and r.Instance == pl.p and pl.taps < 3 then
						pl.taps += 1
						local k = pl.taps / 3
						tw(pl.p, 0.28, {
							Size = Vector3.new(2.8, 0.45 + 0.6 * k, 1.5 + 0.1 * k),
							CFrame = CFrame.new(pl.x, 2.5 + 0.3 * k, -3.9 - 0.05 * k) * CFrame.Angles(0.25 - 0.45 * k, (pl.x < 0 and 0.18 or -0.22) * (1 - k), (pl.x < 0 and 0.12 or -0.1) * (1 - k)),
						}, Enum.EasingStyle.Back)
						sound("select")
						burst(toArea(pl.p.Position + Vector3.new(0, 0.6, 0)), Color3.fromRGB(255, 255, 255), 5, 46)
						if pl.taps == 3 then
							fluffed += 1
							floatText(toArea(pl.p.Position + Vector3.new(0, 1.4, 0)), "Fluffy!", T.green)
							setProgress(fluffed / 2 * 0.33)
							if fluffed == 2 then
								phase = 2
								say("Pull the blanket up to the gold line")
								guide.Transparency = 0.1
							end
						end
						return
					end
				end
			elseif phase == 2 then
				local r = pick(p, { blanket, cuff })
				if r then
					dragging = true
					local w = onPlane(p, Vector3.new(0, 2.6, 0), UP)
					grabOff = w and (zt - w.Z) or 0
					sound("sheets")
				end
			elseif phase == 3 then
				lastW = onPlane(p, Vector3.new(0, 2.62, 0), UP)
			end
		end
		S.onMove = function(p)
			if phase == 2 and dragging then
				local w = onPlane(p, Vector3.new(0, 2.6, 0), UP)
				if not w then return end
				zt = math.clamp(w.Z + grabOff, TARGET, START)
				sizeBlanket()
				setProgress(0.33 + 0.33 * (START - zt) / (START - TARGET))
				if zt <= TARGET + 0.15 then
					zt = TARGET
					sizeBlanket()
					dragging = false
					phase = 2.5
					tw(guide, 0.3, { Transparency = 1 })
					sound("place")
					floatText(toArea(Vector3.new(0, 3.2, TARGET)), "Tucked in!", T.green)
					task.delay(0.35, function() if S then startWrinkles() end end)
				end
			elseif phase == 3 and S.held then
				local w = onPlane(p, Vector3.new(0, 2.62, 0), UP)
				if not (w and lastW) then lastW = w return end
				local moved = (w - lastW).Magnitude
				lastW = w
				if moved > 3 then return end
				for _, wr in ipairs(wrinkles) do
					if wr.hp > 0 and distSeg(w, wr.a, wr.b) < 0.75 then
						wr.hp -= moved
						local k = math.clamp(wr.hp / wr.max, 0, 1)
						wr.p.Size = Vector3.new(wr.p.Size.X, 0.04 + 0.2 * k, 0.34)
						if os.clock() - (wr.fx or 0) > 0.12 then
							wr.fx = os.clock()
							sound("sheets")
						end
						if wr.hp <= 0 then
							smoothed += 1
							tw(wr.p, 0.2, { Transparency = 1 })
							burst(toArea(wr.p.Position), T.cream, 6, 40)
							setProgress(0.66 + 0.34 * smoothed / #wrinkles)
							if smoothed == #wrinkles then
								phase = 4
								task.delay(0.3, win)
							end
						end
					end
				end
			end
		end
		S.onUp = function()
			if phase == 2 and dragging then
				dragging = false
			end
			lastW = nil
		end
		-- the gold line breathes while it waits
		table.insert(S.conns, RunService.Heartbeat:Connect(function()
			if S and phase == 2 then guide.Transparency = 0.15 + math.sin(os.clock() * 5) * 0.15 end
		end))
	end

	---------------------------------------------------------------- Shower: scrub the glass, then rinse
	-- a smear of grime: a few overlapping soft blobs (cf = the spot, its Z pointing out of the surface), with drips
	local function grime(cf, d, tints, drips)
		local parts = {}
		for i = 1, rng:NextInteger(3, 5) do
			local r = d * (i == 1 and 0.8 or rng:NextNumber(0.35, 0.6))
			local off = i == 1 and Vector2.zero or Vector2.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)) * d * 0.75
			local p = ell(Vector3.new(r * rng:NextNumber(0.9, 1.4), r, 0.03), cf * CFrame.new(off.X, off.Y, 0.006 * i) * CFrame.Angles(0, 0, rng:NextNumber(0, 3.1)), tints[rng:NextInteger(1, #tints)], SMOOTH)
			p.CanQuery = false
			local t0 = i == 1 and rng:NextNumber(0.05, 0.15) or rng:NextNumber(0.15, 0.32) -- round 14: thicker, so it reads as grime
			p.Transparency = t0
			table.insert(parts, { p, t0 })
		end
		-- dark specks of mildew in it
		for _ = 1, rng:NextInteger(3, 6) do
			local off = Vector2.new(rng:NextNumber(-0.45, 0.45), rng:NextNumber(-0.45, 0.45)) * d
			local sz = rng:NextNumber(0.08, 0.18) * d
			local p = ell(Vector3.new(sz, sz * rng:NextNumber(0.7, 1.2), 0.03), cf * CFrame.new(off.X, off.Y, 0.04), Color3.fromRGB(86, 92, 62), SMOOTH)
			p.CanQuery = false
			p.Transparency = 0.25
			table.insert(parts, { p, 0.25 })
		end
		for _ = 1, drips and rng:NextInteger(1, 2) or 0 do
			local len = rng:NextNumber(0.4, 0.8)
			local p = ell(Vector3.new(0.17, len, 0.03), cf * CFrame.new(rng:NextNumber(-0.3, 0.3) * d, -d * 0.35 - len / 2, 0.04), tints[1], SMOOTH)
			p.CanQuery = false
			p.Transparency = 0.4
			table.insert(parts, { p, 0.4 })
		end
		return parts
	end

	G3.Shower = function()
		S.hideCursor = true
		scene({
			cam = CFrame.lookAt(Vector3.new(0.6, 4.9, 14.6), Vector3.new(0.6, 4.5, 0)), fov = 40, bg = Color3.fromRGB(50, 53, 56),
			ambient = Color3.fromRGB(127, 129, 132), light = Color3.fromRGB(240, 232, 222), dir = Vector3.new(-0.35, -1, -0.55),
		})
		roomSet({ wallZ = -1.8, wall = Color3.fromRGB(196, 178, 156), floor = Color3.fromRGB(88, 94, 106), floorMat = Enum.Material.Slate })
		-- the tiled stall
		local TILE = Color3.fromRGB(142, 180, 186)
		part(Vector3.new(8.4, 9.6, 0.2), CFrame.new(0.4, 4.8, -1.65), TILE).CanQuery = false
		grout(CFrame.new(0.4, 4.8, -1.55), 8.4, 9.6, 0.92, Color3.fromRGB(222, 232, 232))
		part(Vector3.new(0.4, 9.6, 4.2), CFrame.new(-3.6, 4.8, 0.3), TILE).CanQuery = false
		part(Vector3.new(0.42, 0.3, 4.22), CFrame.new(-3.6, 9.6, 0.3), Color3.fromRGB(236, 238, 240)).CanQuery = false
		part(Vector3.new(8.6, 0.4, 4.4), CFrame.new(0.4, 0.2, 0.4), Color3.fromRGB(236, 238, 240)).CanQuery = false
		cyl(0.06, 0.45, CFrame.new(0.4, 0.42, 0.4), CHROME, METAL).CanQuery = false
		local mat = part(Vector3.new(4.6, 0.08, 2.2), CFrame.new(0.4, 0.04, 4.6), Color3.fromRGB(222, 116, 104), FABRIC)
		mat.CanQuery = false
		-- outside the stall: a towel on a rail, a plant
		cylX(2.8, 0.14, CFrame.new(-6.7, 6.3, -1.55), CHROME, METAL).CanQuery = false
		part(Vector3.new(2.3, 3.4, 0.22), CFrame.new(-6.7, 4.75, -1.45), Color3.fromRGB(40, 62, 112), FABRIC).CanQuery = false
		for _, y in ipairs({ 3.75, 3.45 }) do part(Vector3.new(2.32, 0.16, 0.24), CFrame.new(-6.7, y, -1.45), T.gold, FABRIC).CanQuery = false end
		item("Plant", CFrame.new(7.4, 0, -0.6))
		-- the shower head, the shelf and the tap
		cylZ(1.4, 0.18, CFrame.new(0.4, 8.7, -1.1), CHROME, METAL).CanQuery = false
		cyl(0.28, 1.6, CFrame.new(0.4, 8.45, -0.4) * CFrame.Angles(math.rad(25), 0, 0), CHROME, METAL).CanQuery = false
		part(Vector3.new(2.6, 0.15, 0.7), CFrame.new(-2.2, 5.4, -1.25), Color3.fromRGB(236, 238, 240)).CanQuery = false
		for i, c in ipairs({ Color3.fromRGB(230, 90, 120), Color3.fromRGB(90, 170, 230), Color3.fromRGB(250, 200, 80) }) do
			cyl(0.9 - i * 0.12, 0.42, CFrame.new(-3.1 + i * 0.6, 5.9 - i * 0.06, -1.22), c, SMOOTH).CanQuery = false
		end
		local plate = cylZ(0.12, 1.1, CFrame.new(2.6, 4.6, -1.5), CHROME, METAL)
		local lever = part(Vector3.new(0.3, 1.1, 0.3), CFrame.new(2.6, 4.85, -1.28), CHROME, METAL)
		-- the glass door, with a few soft reflections
		local GZ = 2.2
		local glass = part(Vector3.new(7.6, 8.8, 0.1), CFrame.new(0.4, 4.8, GZ), Color3.fromRGB(200, 230, 242), Enum.Material.Glass)
		glass.Transparency = 0.8
		glass.CanQuery = false
		for _, s in ipairs({ { -2.4, 6.4, 0.16 }, { -1.9, 6.8, 0.08 }, { 3.2, 2.6, 0.14 } }) do
			local r = part(Vector3.new(s[3], 2.6, 0.02), CFrame.new(s[1], s[2], GZ + 0.06) * CFrame.Angles(0, 0, math.rad(-28)), Color3.new(1, 1, 1))
			r.Transparency = 0.8
			r.CanQuery = false
		end
		for _, e in ipairs({ { Vector3.new(7.7, 0.16, 0.16), CFrame.new(0.4, 9.2, GZ) }, { Vector3.new(7.7, 0.16, 0.16), CFrame.new(0.4, 0.42, GZ) }, { Vector3.new(0.16, 8.8, 0.16), CFrame.new(4.2, 4.8, GZ) } }) do
			part(e[1], e[2], CHROME, METAL).CanQuery = false
		end
		cyl(2.2, 0.16, CFrame.new(3.6, 4.6, GZ + 0.25), CHROME, METAL).CanQuery = false
		-- soap scum on the glass
		local spots = {}
		local tints = { Color3.fromRGB(176, 160, 118), Color3.fromRGB(152, 140, 104), Color3.fromRGB(196, 184, 146), Color3.fromRGB(140, 150, 120) }
		for _ = 1, 5 do
			local pos
			for _ = 1, 40 do
				pos = Vector3.new(rng:NextNumber(-2.5, 3.3), rng:NextNumber(1.8, 7.6), GZ + 0.07)
				local ok = true
				for _, s in ipairs(spots) do if (s.pos - pos).Magnitude < 1.6 then ok = false end end
				if ok then break end
			end
			local d = rng:NextNumber(1.1, 1.8)
			table.insert(spots, { parts = grime(CFrame.new(pos), d, tints, true), pos = pos, r = d / 2, hp = 1.0 + d * 0.6, max = 1.0 + d * 0.6 })
		end
		-- the sponge follows the pointer over the glass
		local sponge = model("Sponge")
		part(Vector3.new(1.7, 1.1, 0.55), CFrame.new(0, 0, 0.32), Color3.fromRGB(250, 212, 84), FABRIC, sponge)
		part(Vector3.new(1.7, 1.1, 0.22), CFrame.new(0, 0, -0.07), Color3.fromRGB(56, 150, 84), FABRIC, sponge)
		done(sponge)
		for _, p in ipairs(partsOf(sponge)) do p.CanQuery = false end
		local tilt = CFrame.Angles(math.rad(-14), math.rad(-24), 0)
		sponge:PivotTo(CFrame.new(5.8, 1.4, GZ + 0.6) * tilt)
		V.hand, V.handOff = sponge, Vector3.new(0, 0, 0.5)
		local phase, tapTag = "scrub", nil
		local rub, reset
		rub, reset = scrubSpots(spots, 0.75, "scrub", function()
			phase = "rinse"
			V.hand = nil
			S.hideCursor = false
			UIS.MouseIconEnabled = true
			say("All clean! Turn the tap to rinse")
			tweenPivot(sponge, CFrame.new(-2.2, 5.75, -0.9) * CFrame.Angles(0, 0.3, 0), 0.4, Enum.EasingStyle.Back)
			tapTag = tag3(Vector3.new(2.6, 6.0, -1.2), "TURN", T.gold, 14, 64)
		end)
		say("Scrub the grime off the glass")
		local function follow(p)
			local w = onPlane(p, Vector3.new(0, 0, GZ + 0.3), Vector3.zAxis)
			if not w then return nil end
			local t = os.clock()
			sponge:PivotTo(CFrame.new(w.X, w.Y, GZ + (S.held and 0.35 or 0.7)) * tilt * CFrame.Angles(0, 0, S.held and math.sin(t * 24) * 0.12 or 0))
			return Vector3.new(w.X, w.Y, GZ + 0.07)
		end
		local function water()
			-- a soft cone of spray, streams from the head, and drops running down the glass
			local cone = ell(Vector3.new(2.8, 7.4, 1.8), CFrame.new(0.4, 4.4, -0.1), Color3.fromRGB(186, 222, 246), SMOOTH)
			cone.Transparency = 1
			cone.CanQuery = false
			tw(cone, 0.25, { Transparency = 0.8 })
			task.delay(0.9, function() if cone.Parent then tw(cone, 0.35, { Transparency = 1 }) end end)
			for i = 1, 34 do
				task.delay(i * 0.028, function()
					if not S then return end
					local a = rng:NextNumber(0, math.pi * 2)
					local r = rng:NextNumber(0, 0.6)
					local from = Vector3.new(0.4 + math.cos(a) * r * 0.5, 8.0, -0.2 + math.sin(a) * r * 0.4)
					local to = Vector3.new(0.4 + math.cos(a) * r * 2.4, 0.5, -0.2 + math.sin(a) * r * 1.6)
					local s = cyl(1.3, 0.09, CFrame.lookAt(from, to) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(176, 218, 248), SMOOTH)
					s.Transparency = 0.3
					s.CanQuery = false
					tw(s, 0.42, { CFrame = CFrame.lookAt(to, to + (to - from)) * CFrame.Angles(math.rad(90), 0, 0), Transparency = 0.75 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					task.delay(0.45, function() s:Destroy() end)
				end)
			end
			for i = 1, 10 do
				task.delay(0.25 + i * 0.06, function()
					if not S then return end
					local x, y = rng:NextNumber(-2.6, 3.4), rng:NextNumber(4, 8.4)
					local dr = ell(Vector3.new(0.16, 0.24, 0.05), CFrame.new(x, y, GZ + 0.08), Color3.fromRGB(220, 240, 255), SMOOTH)
					dr.Transparency = 0.25
					dr.CanQuery = false
					tw(dr, 0.7, { CFrame = CFrame.new(x, y - rng:NextNumber(1.5, 3), GZ + 0.08), Size = Vector3.new(0.12, 0.6, 0.05) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					burst(toArea(Vector3.new(x, y, GZ)), Color3.fromRGB(220, 240, 255), 3, 30)
				end)
			end
		end
		S.onDown = function(p)
			if phase == "rinse" then
				if pick(p, { lever, plate }) then
					phase = "done"
					if tapTag then tapTag:Destroy() end
					tw(lever, 0.25, { CFrame = lever.CFrame * CFrame.Angles(0, 0, math.rad(-70)) }, Enum.EasingStyle.Back)
					sound("spray")
					water()
					setProgress(1)
					task.delay(1.0, win)
				end
				return
			end
			if phase ~= "scrub" then return end
			reset()
			rub(follow(p))
		end
		S.onMove = function(p)
			if phase ~= "scrub" then return end
			local at = follow(p)
			if S.held then rub(at) end
		end
		S.onUp = function() reset() end
		table.insert(S.conns, RunService.Heartbeat:Connect(function()
			if S and phase == "rinse" and tapTag then tapTag.Size = UDim2.fromOffset(64 + math.sin(os.clock() * 7) * 6, 24) end
		end))
	end

	---------------------------------------------------------------- Toilet: scrub the bowl, then flush
	G3.Toilet = function()
		S.hideCursor = true
		scene({
			cam = CFrame.lookAt(Vector3.new(0, 10.6, 7.2), Vector3.new(0, 2.9, -0.3)), fov = 40, bg = Color3.fromRGB(50, 53, 56),
			ambient = Color3.fromRGB(125, 127, 130), light = Color3.fromRGB(240, 232, 224), dir = Vector3.new(-0.4, -1, -0.5),
		})
		roomSet({ wallZ = -3, wall = Color3.fromRGB(150, 180, 166), floor = Color3.fromRGB(78, 90, 112), floorMat = SMOOTH })
		grout(CFrame.new(0, 6, -2.99), 30, 12, 1.2, Color3.fromRGB(206, 222, 212))
		grout(CFrame.new(0, 0.01, 0) * CFrame.Angles(math.rad(-90), 0, 0), 40, 40, 2, Color3.fromRGB(116, 128, 150))
		part(Vector3.new(30, 0.7, 0.3), CFrame.new(0, 0.35, -2.85), Color3.fromRGB(236, 238, 240)).CanQuery = false
		-- a paper roll on the wall and a little bin
		cylZ(0.5, 0.2, CFrame.new(3.4, 3.6, -2.7), CHROME, METAL).CanQuery = false
		cylX(1.1, 1.0, CFrame.new(3.4, 3.2, -2.25), Color3.fromRGB(250, 250, 248), FABRIC).CanQuery = false
		cylX(1.2, 0.3, CFrame.new(3.4, 3.2, -2.25), CHROME, METAL).CanQuery = false
		item("LobbyBin", CFrame.new(-3.7, 0, -1.9), 0.9)
		local PORC = Color3.fromRGB(238, 241, 245)
		local t = model("Toilet")
		local function P(p) p.CanQuery = false; return p end
		P(ell(Vector3.new(1.9, 2.4, 2.4), CFrame.new(0, 0.9, -0.2), PORC, SMOOTH, t))
		P(ell(Vector3.new(3.0, 1.6, 3.7), CFrame.new(0, 2.05, 0.25), PORC, SMOOTH, t))
		P(ell(Vector3.new(3.15, 0.3, 3.85), CFrame.new(0, 2.86, 0.25), Color3.fromRGB(226, 230, 236), SMOOTH, t))
		P(ell(Vector3.new(2.2, 0.32, 2.85), CFrame.new(0, 2.88, 0.35), Color3.fromRGB(214, 222, 230), SMOOTH, t))
		P(ell(Vector3.new(1.9, 0.32, 2.5), CFrame.new(0, 2.895, 0.4), Color3.fromRGB(200, 212, 224), SMOOTH, t))
		local water = P(ell(Vector3.new(1.25, 0.32, 1.55), CFrame.new(0, 2.91, 0.55), Color3.fromRGB(150, 160, 120), SMOOTH, t))
		P(part(Vector3.new(3.0, 2.6, 1.3), CFrame.new(0, 3.6, -1.75), PORC, SMOOTH, t))
		P(part(Vector3.new(3.2, 0.3, 1.5), CFrame.new(0, 5.0, -1.75), Color3.fromRGB(246, 247, 249), SMOOTH, t))
		P(ell(Vector3.new(3.0, 3.2, 0.3), CFrame.new(0, 4.2, -0.95) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(244, 246, 248), SMOOTH, t))
		local button = cyl(0.14, 0.62, CFrame.new(0.7, 5.2, -1.75), CHROME, METAL, t)
		shadow(0, 0, 3.6)
		-- the stains: inside the bowl and a couple on the rim
		local spots = {}
		local tints = { Color3.fromRGB(150, 116, 64), Color3.fromRGB(176, 144, 76), Color3.fromRGB(124, 100, 66) }
		local up = CFrame.Angles(math.rad(-90), 0, 0)
		for i = 1, 5 do
			local pos
			for _ = 1, 40 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = i <= 3 and rng:NextNumber(0.15, 0.8) or 1.0
				pos = Vector3.new(math.cos(a) * r * (i <= 3 and 0.85 or 1.3), i <= 3 and 3.075 or 3.03, 0.4 + math.sin(a) * r * (i <= 3 and 1.1 or 1.6))
				local ok = true
				for _, s in ipairs(spots) do if (s.pos - pos).Magnitude < 0.6 then ok = false end end
				if ok then break end
			end
			local d = rng:NextNumber(0.5, 0.85)
			table.insert(spots, { parts = grime(CFrame.new(pos) * up, d, tints, false), pos = pos, r = d / 2, hp = 0.8 + d * 0.6, max = 0.8 + d * 0.6 })
		end
		-- the brush follows the pointer over the bowl
		local brush = model("Brush")
		ell(Vector3.new(0.8, 0.55, 0.8), CFrame.new(0, 0.28, 0), Color3.fromRGB(70, 140, 220), FABRIC, brush)
		cyl(0.12, 0.86, CFrame.new(0, 0.5, 0), Color3.fromRGB(240, 240, 244), SMOOTH, brush)
		part(Vector3.new(0.16, 3.4, 0.16), CFrame.new(0.55, 2.1, 0.5) * CFrame.Angles(math.rad(18), 0, math.rad(-18)), Color3.fromRGB(245, 245, 248), SMOOTH, brush)
		done(brush)
		for _, p in ipairs(partsOf(brush)) do p.CanQuery = false end
		brush:PivotTo(CFrame.new(2.6, 3.0, 1.6))
		V.hand, V.handOff = brush, Vector3.new(0.95, 3.4, 0.9)
		local phase, pushTag = "scrub", nil
		local rub, reset = scrubSpots(spots, 0.45, "scrub", function()
			phase = "flush"
			V.hand = nil
			S.hideCursor = false
			UIS.MouseIconEnabled = true
			say("Sparkling! Push the flush button")
			tweenPivot(brush, CFrame.new(-2.8, 0, 1.8) * CFrame.Angles(0, 0, math.rad(12)), 0.35, Enum.EasingStyle.Back)
			-- the camera rises so the flush button sits in the middle of the screen
			tw(V.cam, 0.5, { CFrame = CFrame.lookAt(Vector3.new(0, 9.4, 7.2), Vector3.new(0.3, 4.4, -1.1)) })
			task.delay(0.55, function()
				if S and phase == "flush" then pushTag = tag3(Vector3.new(0.7, 6.3, -1.75), "PUSH", T.gold, 14, 64) end
			end)
		end)
		say("Scrub the stains with the brush")
		local function follow(p)
			local w = onPlane(p, Vector3.new(0, 3.05, 0), UP)
			if not w then return nil end
			w = Vector3.new(math.clamp(w.X, -1.8, 1.8), 3.05, math.clamp(w.Z, -0.9, 2.4))
			local tt = os.clock()
			brush:PivotTo(CFrame.new(w.X, S.held and 2.95 or 3.25, w.Z) * CFrame.Angles(S.held and math.sin(tt * 26) * 0.15 or 0, 0, 0))
			return w
		end
		S.onDown = function(p)
			if phase == "flush" then
				if pick(p, { button }) then
					phase = "done"
					if pushTag then pushTag:Destroy() end
					tw(button, 0.12, { CFrame = button.CFrame - Vector3.new(0, 0.08, 0) })
					sound("flush")
					-- the water swirls away and comes back clear
					local c0 = water.CFrame
					local spin = 0
					local conn
					conn = RunService.Heartbeat:Connect(function(dt)
						spin += dt
						if not water.Parent or spin > 1.2 then conn:Disconnect() return end
						water.CFrame = c0 * CFrame.Angles(0, spin * 14, 0)
						water.Size = Vector3.new(1.25 - math.sin(spin / 1.2 * math.pi) * 0.5, 0.32, 1.55 - math.sin(spin / 1.2 * math.pi) * 0.6)
						if math.random() < 0.5 then bubbles(toArea(c0.Position + Vector3.new(math.cos(spin * 9) * 0.5, 0, math.sin(spin * 9) * 0.6)), 1) end
					end)
					tw(water, 1.2, { Color = Color3.fromRGB(150, 206, 240) })
					setProgress(1)
					task.delay(1.1, win)
				end
				return
			end
			if phase ~= "scrub" then return end
			reset()
			rub(follow(p))
		end
		S.onMove = function(p)
			if phase ~= "scrub" then return end
			local at = follow(p)
			if S.held then rub(at) end
		end
		S.onUp = function() reset() end
		table.insert(S.conns, RunService.Heartbeat:Connect(function()
			if S and phase == "flush" and pushTag then pushTag.Size = UDim2.fromOffset(64 + math.sin(os.clock() * 7) * 6, 24) end
		end))
	end

	---------------------------------------------------------------- the front desk set (check in, check out)
	local function deskSet(camCF)
		scene({ cam = camCF, fov = 40, bg = Color3.fromRGB(56, 46, 40), ambient = Color3.fromRGB(140, 132, 130) })
		roomSet({ wallZ = -7.5, wall = Color3.fromRGB(70, 92, 84), floorY = -4 })
		local top = part(Vector3.new(44, 1.2, 10), CFrame.new(0, -0.6, -1.4), Color3.fromRGB(122, 78, 48), WOODM)
		top.CanQuery = false
		part(Vector3.new(44, 0.22, 0.22), CFrame.new(0, -0.06, 3.6), BRASS, METAL).CanQuery = false
		-- wainscot panels on the back wall
		for i = -3, 3 do
			local pnl = part(Vector3.new(4.2, 3.2, 0.15), CFrame.new(i * 5, 2.4, -7.42), Color3.fromRGB(58, 78, 70))
			pnl.CanQuery = false
		end
		-- a brass bell and a little plant for company
		local bell = model("Bell")
		cyl(0.18, 1.2, CFrame.new(0, 0.09, 0), Color3.fromRGB(60, 40, 30), WOODM, bell)
		ell(Vector3.new(0.95, 0.8, 0.95), CFrame.new(0, 0.3, 0), BRASS, METAL, bell)
		ball(0.2, CFrame.new(0, 0.75, 0), BRASS, METAL, bell)
		done(bell)
		for _, p in ipairs(partsOf(bell)) do p.CanQuery = false end
		return bell
	end

	G3.CheckIn = function()
		local d = S.data or {}
		local guest = d.guest or "Guest"
		local roomId = tostring(d.room or "101")
		local nights = d.nights or 2
		S.mistakes = 0
		local bell = deskSet(CFrame.lookAt(Vector3.new(0, 9.8, 10.0), Vector3.new(0, 1.7, -1.4)))
		bell:PivotTo(CFrame.new(-1.0, 0, -3.8))
		-- round 14 (2026-11-09): the real guest waits across the desk (a still copy of their body), shifting
		-- their weight while you work and hopping when they get their key
		do
			local src
			for _, plot in ipairs(workspace:FindFirstChild("Plots") and workspace.Plots:GetChildren() or {}) do
				local gs = plot:FindFirstChild("Guests")
				for _, m in ipairs(gs and gs:GetChildren() or {}) do
					if not src and m:IsA("Model") and not m:GetAttribute("Staff") and (m:GetAttribute("BName") == guest or m.Name == guest) then src = m end
				end
			end
			if src then
				local was = src.Archivable
				src.Archivable = true
				local ok, copy = pcall(function() return src:Clone() end)
				src.Archivable = was
				if ok and copy then
					for _, x in ipairs(copy:GetDescendants()) do
						if x:IsA("LuaSourceContainer") or x:IsA("BillboardGui") or x:IsA("ProximityPrompt") or x:IsA("Sound") or x:IsA("ParticleEmitter") then x:Destroy()
						elseif x:IsA("BasePart") then x.Anchored, x.CanCollide, x.CanQuery = true, false, false end
					end
					local hum = copy:FindFirstChildOfClass("Humanoid")
					if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
					-- stand them up by their root (the copy can come from a guest lying in bed or sitting)
					local root = copy:FindFirstChild("HumanoidRootPart") or copy.PrimaryPart
					local rootY = -2.5 + (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
					local home = CFrame.lookAt(Vector3.new(1.0, rootY, -5.8), Vector3.new(1.0, rootY, 10))
					local off = root and root.CFrame:ToObjectSpace(copy:GetPivot()) or CFrame.identity
					copy:PivotTo(home * off)
					copy.Parent = V.wm
					local t0 = os.clock()
					table.insert(S.conns, RunService.RenderStepped:Connect(function()
						if not copy.Parent then return end
						local t = os.clock() - t0
						local hop = (S and S.won) and math.abs(math.sin(t * 9)) * 0.9 or 0
						copy:PivotTo(home * CFrame.new(math.sin(t * 1.3) * 0.12, math.abs(math.sin(t * 2.6)) * 0.05 + hop, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.12, math.sin(t * 1.3) * 0.025) * off)
					end))
				end
			end
		end
		-- the computer
		local tilt = CFrame.Angles(math.rad(-16), 0, 0)
		local monCF = CFrame.new(-4.3, 3.6, -2.7) * V.cam.CFrame.Rotation
		cyl(0.15, 1.8, CFrame.new(-4.3, 0.08, -2.9), Color3.fromRGB(47, 48, 50), METAL).CanQuery = false
		part(Vector3.new(0.35, 1.8, 0.3), CFrame.new(-4.3, 0.95, -3.0), Color3.fromRGB(47, 48, 50), METAL).CanQuery = false
		part(Vector3.new(7.2, 4.6, 0.35), monCF, Color3.fromRGB(37, 38, 40)).CanQuery = false
		local glassCF = monCF * CFrame.new(0, 0, 0.19)
		part(Vector3.new(6.8, 4.2, 0.04), glassCF, Color3.fromRGB(16, 28, 40)).CanQuery = false
		part(Vector3.new(3.8, 0.15, 1.3), CFrame.new(-4.6, 0.08, -0.4), Color3.fromRGB(54, 55, 58)).CanQuery = false
		-- the booking list sits on the screen
		local sa, ss = overArea(glassCF, 6.8, 4.2)
		local screen = box({ Position = UDim2.fromOffset(sa.X + 2, sa.Y + 2), Size = UDim2.fromOffset(ss.X - 4, ss.Y - 4), BackgroundColor3 = Color3.fromRGB(24, 41, 58), BackgroundTransparency = 0.05, ZIndex = 6 })
		UI.corner(screen, 6)
		UI.grad(screen, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 230), 90)
		text(screen, "TODAY'S BOOKINGS", 11, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(10, 5), Size = UDim2.fromOffset(200, 13), TextXAlignment = LEFT, ZIndex = 7 })
		local names = shuffle(table.clone(d.names or { guest, "Emily", "James", "Ava", "Leo" }))
		local rowH = math.floor((ss.Y - 8 - 24) / #names) - 3
		local rows = {}
		for i, nm in ipairs(names) do
			local y = 22 + (i - 1) * (rowH + 3)
			local r = box({ Parent = screen, Position = UDim2.fromOffset(6, y), Size = UDim2.new(1, -12, 0, rowH), BackgroundColor3 = T.ink2, ZIndex = 7 })
			UI.corner(r, 5)
			text(r, nm, math.min(15, rowH - 6), { FontFace = UI.F.heavy, Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = LEFT, ZIndex = 8 })
			local n = nm == guest and nights or rng:NextInteger(1, 5)
			text(r, n .. (n == 1 and " night" or " nights"), math.min(12, rowH - 8), { TextColor3 = T.muted, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 8 })
			rows[i] = { obj = r, name = nm, pos = Vector2.new(sa.X + 4 + ss.X / 2, sa.Y + 4 + y + rowH / 2), size = Vector2.new(ss.X - 20, rowH) }
		end
		-- the key board: brass keys on hooks, numbered tags
		local boardCF = CFrame.new(4.6, 3.1, -3.2) * tilt
		part(Vector3.new(6.2, 5.8, 0.3), boardCF, Color3.fromRGB(86, 54, 34), WOODM).CanQuery = false
		part(Vector3.new(5.6, 5.2, 0.05), boardCF * CFrame.new(0, -0.1, 0.16), Color3.fromRGB(40, 58, 52), FABRIC).CanQuery = false
		part(Vector3.new(6.5, 0.35, 0.55), boardCF * CFrame.new(0, 2.95, 0.1), Color3.fromRGB(70, 44, 28), WOODM).CanQuery = false
		tag3((boardCF * CFrame.new(0, 2.25, 0.3)).Position, "ROOM KEYS", T.gold, 11, 86)
		local ids = {}
		for _, k in ipairs(d.keys or { 101, 102, 103 }) do table.insert(ids, tostring(k)) end
		table.sort(ids)
		while #ids > 8 do table.remove(ids) end
		local keys, keyParts = {}, {}
		local TAGS = { Color3.fromRGB(196, 52, 60), Color3.fromRGB(44, 110, 180), Color3.fromRGB(40, 140, 90), Color3.fromRGB(200, 140, 40) }
		for i, id in ipairs(ids) do
			local c, r = (i - 1) % 4, (i - 1) // 4
			local cols = math.min(#ids, 4)
			local hook = boardCF * CFrame.new((c - (cols - 1) / 2) * 1.45, (#ids > 4 and 1.7 or 1.1) - r * 2.6, 0.2)
			cylZ(0.4, 0.14, hook * CFrame.new(0, 0, 0.1), BRASS, METAL).CanQuery = false
			local k = model("Key" .. id)
			cylZ(0.08, 0.6, CFrame.new(0, -0.32, 0.25), BRASS, METAL, k)
			part(Vector3.new(0.16, 0.8, 0.08), CFrame.new(0, -0.95, 0.25), BRASS, METAL, k)
			part(Vector3.new(1.15, 1.15, 0.1), CFrame.new(0, -1.85, 0.25), TAGS[(i - 1) % #TAGS + 1], SMOOTH, k)
			part(Vector3.new(0.92, 0.66, 0.11), CFrame.new(0, -1.85, 0.25), Color3.fromRGB(250, 244, 226), SMOOTH, k)
			done(k)
			k:PivotTo(hook)
			local kd = { m = k, id = id, home = hook }
			kd.label = tag3((hook * CFrame.new(0, -1.85, 0.36)).Position, id, INK_TEXT, 15, 40)
			kd.label.BackgroundTransparency = 1
			local ks = kd.label:FindFirstChildOfClass("UIStroke")
			if ks then ks:Destroy() end
			table.insert(keys, kd)
			for _, p in ipairs(partsOf(k)) do keyParts[p] = kd end
		end
		-- the registration card on a clipboard, leaning toward you
		local cardCF = CFrame.new(-0.2, 1.25, 1.6) * CFrame.Angles(math.rad(-50), 0, 0)
		part(Vector3.new(6.0, 3.3, 0.14), cardCF, Color3.fromRGB(150, 108, 66), WOODM).CanQuery = false
		part(Vector3.new(1.3, 0.3, 0.3), cardCF * CFrame.new(0, 1.6, 0.12), CHROME, METAL).CanQuery = false
		local paperCF = cardCF * CFrame.new(0, -0.1, 0.09)
		part(Vector3.new(5.6, 2.8, 0.03), paperCF, PAPER).CanQuery = false
		part(Vector3.new(1.0, 2.2, 0.6), CFrame.new(-0.2, 0.25, 0.8), Color3.fromRGB(110, 70, 44), WOODM).CanQuery = false
		local ca, cs = overArea(paperCF, 5.6, 2.8)
		local card = box({ Position = UDim2.fromOffset(ca.X, ca.Y), Size = UDim2.fromOffset(cs.X, cs.Y), BackgroundTransparency = 1, ZIndex = 6 })
		text(card, "REGISTRATION", 11, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(200, 13), TextXAlignment = LEFT, ZIndex = 7 })
		local fields = {}
		local cols = { { "GUEST", 0.05, 0.42 }, { "ROOM", 0.5, 0.2 }, { "NIGHTS", 0.74, 0.2 } }
		for i, f in ipairs(cols) do
			text(card, f[1], 9, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(150, 140, 130), Position = UDim2.new(f[2], 0, 0.3, 0), Size = UDim2.new(f[3], 0, 0, 11), TextXAlignment = LEFT, ZIndex = 7 })
			box({ Parent = card, Position = UDim2.new(f[2], 0, 0.78, 0), Size = UDim2.new(f[3], -6, 0, 1), BackgroundColor3 = Color3.fromRGB(190, 170, 150), ZIndex = 7 })
			fields[i] = text(card, "", 17, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.new(f[2], 0, 0.45, 0), Size = UDim2.new(f[3], 0, 0, 20), TextXAlignment = LEFT, ZIndex = 7 })
		end
		local function fill(i, str)
			fields[i].Text = str
			fields[i].MaxVisibleGraphemes = 0
			UI.tween(fields[i], 0.3, { MaxVisibleGraphemes = #str }, Enum.EasingStyle.Linear)
			sound("tick")
		end
		-- the stamp on its ink pad
		part(Vector3.new(1.8, 0.2, 1.2), CFrame.new(4.4, 0.1, 2.0), Color3.fromRGB(44, 45, 46)).CanQuery = false
		part(Vector3.new(1.6, 0.05, 1.0), CFrame.new(4.4, 0.22, 2.0), Color3.fromRGB(170, 30, 50), FABRIC).CanQuery = false
		local stamp = model("Stamp")
		part(Vector3.new(1.3, 0.3, 0.9), CFrame.new(0, 0.15, 0), Color3.fromRGB(180, 40, 54), SMOOTH, stamp)
		part(Vector3.new(1.2, 0.5, 0.8), CFrame.new(0, 0.55, 0), Color3.fromRGB(150, 100, 60), WOODM, stamp)
		cyl(1.0, 0.36, CFrame.new(0, 1.3, 0), Color3.fromRGB(150, 100, 60), WOODM, stamp)
		ball(0.75, CFrame.new(0, 1.9, 0), Color3.fromRGB(120, 40, 44), SMOOTH, stamp)
		done(stamp)
		for _, p in ipairs(partsOf(stamp)) do p.CanQuery = false end
		stamp:PivotTo(CFrame.new(4.4, 0.24, 2.0))
		local spotCF = paperCF * CFrame.new(1.5, -0.6, 0.02) * CFrame.Angles(math.rad(90), 0, 0)
		-- the timing meter (step 3)
		local meter = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, 12), Size = UDim2.fromOffset(400, 46), BackgroundColor3 = T.ink, ZIndex = 20, Visible = false })
		UI.corner(meter, 12)
		UI.stroke(meter, 2, T.gold, 0.3)
		local track = box({ Parent = meter, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 0, 18), BackgroundColor3 = Color3.fromRGB(76, 79, 84), ZIndex = 21 })
		UI.corner(track, 9)
		local zoneW = 54
		local zoneX = rng:NextInteger(80, 290)
		local zone = box({ Parent = track, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(zoneX, 0), Size = UDim2.fromOffset(zoneW, 18), BackgroundColor3 = T.green, ZIndex = 22 })
		UI.corner(zone, 9)
		local marker = box({ Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 9), Size = UDim2.fromOffset(8, 30), BackgroundColor3 = T.cream, ZIndex = 23 })
		UI.corner(marker, 4)
		local step, mx, dir = 1, 0, 1
		setProgress(0)
		say("Find " .. guest .. "'s booking on the computer")
		local function slam(good, perfect)
			meter.Visible = false
			tweenPivot(stamp, spotCF * CFrame.new(0, 0.02, 0), 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.12, function()
				if not S then return end
				sound("knock")
				local ink = part(Vector3.new(2.5, 0.85, 0.02), paperCF * CFrame.new(1.5, -0.6, 0.025) * CFrame.Angles(0, 0, math.rad(good and -12 or -26)), Color3.fromRGB(200, 40, 60), SMOOTH)
				ink.Transparency = good and 0.72 or 0.85
				ink.CanQuery = false
				local at = toArea((paperCF * CFrame.new(1.5, -0.6, 0)).Position)
				local st = new("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(120, 30), BackgroundTransparency = 1,
					Text = good and "APPROVED" or "APPROVED?", TextSize = 21, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(190, 26, 48), TextTransparency = good and 0 or 0.35,
					Rotation = good and -12 or -26, ZIndex = 9, Parent = S.area,
				})
				UI.pop(st, 1.6, 0.2)
				tweenPivot(stamp, spotCF * CFrame.new(0, 1.6, 0), 0.25, Enum.EasingStyle.Back)
				burst(at, perfect and T.gold or Color3.fromRGB(220, 70, 90), perfect and 14 or 8, 90)
				floatText(at - Vector2.new(0, 50), perfect and "Perfect!" or (good and "Nice!" or "Smudged..."), perfect and T.gold or (good and T.green or T.red))
				setProgress(1)
				task.delay(0.5, win)
			end)
		end
		S.onDown = function(p)
			if step == 1 then
				for _, r in ipairs(rows) do
					if hitRect(p, r.pos, r.size) then
						if r.name == guest then
							step = 2
							r.obj.BackgroundColor3 = T.greenDk
							pulse(r.obj, 1.06)
							sound("select")
							fill(1, guest)
							fill(3, tostring(nights))
							setProgress(0.34)
							say("Grab the key for room " .. roomId)
						else
							r.obj.BackgroundColor3 = T.redDk
							UI.tween(r.obj, 0.4, { BackgroundColor3 = T.ink2 })
							miss(r.obj, p, "That's " .. r.name)
						end
						return
					end
				end
			elseif step == 2 then
				local list = {}
				for pp in pairs(keyParts) do table.insert(list, pp) end
				local r = pick(p, list)
				local k = r and keyParts[r.Instance]
				if k then
					if k.id == roomId then
						step = 3
						V.hand, V.handOff = stamp, Vector3.new(0, 1.9, 0)
						sound("coins")
						k.label:Destroy()
						tweenPivot(k.m, CFrame.new(-4.4, 0.12, 2.2) * CFrame.Angles(0, math.rad(35), 0) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 1.2, 0), 0.4, Enum.EasingStyle.Back)
						fill(2, roomId)
						setProgress(0.67)
						say("Tap when the marker is in the green")
						tweenPivot(stamp, spotCF * CFrame.new(0, 1.6, 0), 0.4, Enum.EasingStyle.Back)
						task.delay(0.4, function()
							if not S then return end
							meter.Visible = true
							UI.pop(meter, 0.6, 0.35)
							step = 4
						end)
					else
						miss(k.label, p, "That's room " .. k.id)
						tweenPivot(k.m, k.home * CFrame.Angles(0, 0, 0.25), 0.1)
						task.delay(0.1, function() if k.m.Parent then tweenPivot(k.m, k.home, 0.4, Enum.EasingStyle.Elastic) end end)
					end
				end
			elseif step == 4 then
				step = 5
				local off = math.abs(mx - zoneX)
				local good = off <= zoneW / 2
				if not good then S.mistakes += 1 end
				slam(good, off <= 9)
			end
		end
		local speed = 260
		table.insert(S.conns, RunService.RenderStepped:Connect(function(dt)
			if not S or step ~= 4 then return end
			mx += dir * speed * dt
			if mx > 372 then mx, dir, speed = 372, -1, speed + 30 end
			if mx < 0 then mx, dir, speed = 0, 1, speed + 30 end
			marker.Position = UDim2.fromOffset(mx, 9)
			stamp:PivotTo(spotCF * CFrame.new(0, 1.6 + math.sin(os.clock() * 8) * 0.08, 0))
		end))
	end

	G3.CheckOut = function()
		local d = S.data or {}
		local bill = d.bill or 60
		local paid = d.paid or 80
		local change = paid - bill
		S.mistakes = 0
		local bell = deskSet(CFrame.lookAt(Vector3.new(0.4, 11, 8.4), Vector3.new(0.4, 0.2, -0.8)))
		bell:PivotTo(CFrame.new(-6.4, 0, 2.6))
		-- the receipt, standing on a spike
		local rcCF = CFrame.new(-5.4, 2.0, -1.6) * CFrame.Angles(math.rad(-34), math.rad(8), 0)
		part(Vector3.new(3.0, 4.4, 0.03), rcCF, PAPER).CanQuery = false
		cyl(0.2, 1.2, CFrame.new(-5.4, 0.1, -2.4), Color3.fromRGB(44, 45, 46), METAL).CanQuery = false
		local ra, rs = overArea(rcCF, 3.0, 4.4)
		local rc = box({ Position = UDim2.fromOffset(ra.X, ra.Y), Size = UDim2.fromOffset(rs.X, rs.Y), BackgroundTransparency = 1, ZIndex = 6 })
		text(rc, "RECEIPT", 11, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.new(0, 0, 0.05, 0), Size = UDim2.new(1, 0, 0, 13), ZIndex = 7 })
		text(rc, d.guest or "Guest", 14, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.new(0, 0, 0.13, 0), Size = UDim2.new(1, 0, 0, 16), ZIndex = 7 })
		text(rc, "Room " .. tostring(d.room or ""), 11, { TextColor3 = Color3.fromRGB(130, 120, 110), Position = UDim2.new(0, 0, 0.22, 0), Size = UDim2.new(1, 0, 0, 13), ZIndex = 7 })
		local function line(y, a, b, big)
			text(rc, a, big and 13 or 12, { FontFace = big and UI.F.black or UI.F.bold, TextColor3 = INK_TEXT, Position = UDim2.new(0.08, 0, y, 0), Size = UDim2.new(0.5, 0, 0, 16), TextXAlignment = LEFT, ZIndex = 7 })
			text(rc, b, big and 18 or 13, { FontFace = UI.F.black, TextColor3 = big and Color3.fromRGB(46, 150, 84) or INK_TEXT, Position = UDim2.new(0.42, 0, y - (big and 0.01 or 0), 0), Size = UDim2.new(0.5, 0, 0, big and 22 or 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7 })
		end
		line(0.36, "Stay", "$" .. bill)
		line(0.46, "Paid", "$" .. paid)
		box({ Parent = rc, Position = UDim2.new(0.08, 0, 0.57, 0), Size = UDim2.new(0.84, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(200, 180, 150), ZIndex = 7 })
		line(0.62, "Change", "$" .. change, true)
		-- the cash drawer: four slots of notes
		local drawer = part(Vector3.new(9.6, 0.6, 4.0), CFrame.new(1.8, 0.3, 1.5), Color3.fromRGB(48, 51, 54), METAL)
		drawer.CanQuery = false
		local slots, slotParts = {}, {}
		for i, v in ipairs(NOTES) do
			local x = 1.8 - 3.6 + (i - 1) * 2.4
			if i > 1 then part(Vector3.new(0.12, 0.5, 3.8), CFrame.new(x - 1.2, 0.62, 1.5), Color3.fromRGB(84, 87, 92), METAL).CanQuery = false end
			local st = model("Notes" .. v)
			for s = 1, 4 do
				part(Vector3.new(1.9, 0.06, 3.2), CFrame.new(0, 0.65 + s * 0.07, 0) * CFrame.Angles(0, (s - 2.5) * 0.04, 0), NOTE_COL[v], SMOOTH, st)
			end
			part(Vector3.new(0.5, 0.062, 3.21), CFrame.new(0, 0.94, 0), NOTE_COL[v]:Lerp(Color3.new(1, 1, 1), 0.35), SMOOTH, st)
			done(st)
			st:PivotTo(CFrame.new(x, 0, 1.5))
			local sd = { m = st, v = v, x = x }
			sd.label = tag3(Vector3.new(x, 1.1, 1.5), "$" .. v, INK_TEXT, 16, 46)
			sd.label.BackgroundColor3 = Color3.fromRGB(250, 246, 232)
			table.insert(slots, sd)
			for _, p in ipairs(partsOf(st)) do slotParts[p] = sd end
		end
		-- the change tray
		local tray = part(Vector3.new(4.8, 0.26, 3.0), CFrame.new(1.8, 0.13, -2.6), BRASS, METAL)
		part(Vector3.new(4.4, 0.27, 2.6), CFrame.new(1.8, 0.14, -2.6), Color3.fromRGB(30, 44, 78), FABRIC).CanQuery = false
		tag3(Vector3.new(1.8, 0.4, -4.4), "CHANGE TRAY", T.gold, 11, 96).BackgroundTransparency = 0.3
		-- the running total
		local panel = box({ Position = UDim2.new(1, -196, 0, 12), Size = UDim2.fromOffset(182, 64), BackgroundColor3 = T.ink, BackgroundTransparency = 0.05, ZIndex = 20 })
		UI.corner(panel, 12)
		UI.stroke(panel, 2, T.gold, 0.4)
		text(panel, "GIVING BACK", 11, { FontFace = UI.F.black, TextColor3 = T.gold, Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(150, 13), TextXAlignment = LEFT, ZIndex = 21 })
		local total = text(panel, "$0", 26, { FontFace = UI.F.black, Position = UDim2.fromOffset(12, 20), Size = UDim2.fromOffset(90, 32), TextXAlignment = LEFT, ZIndex = 21 })
		text(panel, "of $" .. change, 13, { TextColor3 = T.muted, Position = UDim2.new(1, -92, 0, 30), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 21 })
		local given, sum, finished = {}, 0, false
		local function refresh()
			total.Text = "$" .. sum
			total.TextColor3 = sum == change and T.green or (sum > change and T.red or T.cream)
			UI.pop(total, 0.8, 0.2)
			setProgress(math.min(sum / change, 1) * 0.95)
		end
		local function takeBack()
			local g = table.remove(given)
			if not g then return end
			sum -= g.v
			tweenPivot(g.m, CFrame.new(g.x, 1.2, 1.5), 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.2, function() g.m:Destroy() end)
			refresh()
		end
		say("Hand back $" .. change .. " in change")
		S.onDown = function(p)
			if finished then return end
			local list = { tray }
			for pp in pairs(slotParts) do table.insert(list, pp) end
			local r = pick(p, list)
			if not r then return end
			if r.Instance == tray then
				if #given > 0 then sound("click"); takeBack() end
				return
			end
			local s = slotParts[r.Instance]
			if not s then return end
			-- one note flies from the slot to the tray
			local n = model("Note")
			part(Vector3.new(1.9, 0.06, 3.2), CFrame.new(), NOTE_COL[s.v], SMOOTH, n)
			part(Vector3.new(0.5, 0.062, 3.21), CFrame.new(), NOTE_COL[s.v]:Lerp(Color3.new(1, 1, 1), 0.35), SMOOTH, n)
			done(n)
			for _, pp in ipairs(partsOf(n)) do pp.CanQuery = false end
			n:PivotTo(CFrame.new(s.x, 1.0, 1.5))
			local k = #given
			tweenPivot(n, CFrame.new(1.8 + rng:NextNumber(-0.5, 0.5), 0.32 + k * 0.07, -2.6 + rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6) + math.rad(90), 0), 0.3, Enum.EasingStyle.Back)
			table.insert(given, { m = n, v = s.v, x = s.x })
			V.hand, V.handOff = n, Vector3.zero
			task.delay(0.45, function() if V and V.hand == n then V.hand = nil end end)
			sum += s.v
			pulse(s.label, 0.9)
			sound("coins")
			refresh()
			local trayAt = toArea(Vector3.new(1.8, 1.2, -2.6))
			if sum == change then
				finished = true
				sound("register")
				floatText(trayAt - Vector2.new(0, 30), "Exact change!", T.green)
				burst(trayAt, T.gold, 14, 120)
				setProgress(1)
				task.delay(0.55, win)
			elseif sum > change then
				floatText(trayAt - Vector2.new(0, 30), "Too much!", T.red)
				S.mistakes += 1
				S.t0 -= 1
				sound("error")
				shake(total)
				task.delay(0.4, function() if S and not finished then takeBack() end end)
			end
		end
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

	G3.Cook = function()
		local d = S.data or {}
		local items = d.items or { "bun", "patty", "cheese" }
		local panKind = PAN3[d.pan or ""] and d.pan or "patty"
		local stir = panKind == "sauce"
		local shelf = shuffle(table.clone(d.shelf or { "bun", "patty", "cheese", "egg", "tomato", "basil" }))
		S.mistakes = 0
		scene({ cam = CFrame.lookAt(Vector3.new(0, 10, 9.6), Vector3.new(0, 1.0, -1.2)), fov = 40, bg = Color3.fromRGB(50, 46, 44), ambient = Color3.fromRGB(156, 148, 144) })
		roomSet({ wallZ = -5.5, wall = Color3.fromRGB(236, 238, 236), floorY = -4 })
		grout(CFrame.new(0, 3, -5.49), 40, 16, 0.9, Color3.fromRGB(200, 206, 210))
		part(Vector3.new(22, 1, 10), CFrame.new(0, -0.5, -0.8), Color3.fromRGB(236, 232, 226), Enum.Material.Marble).CanQuery = false
		part(Vector3.new(22, 0.2, 0.2), CFrame.new(0, -0.05, 4.2), CHROME, METAL).CanQuery = false
		-- the pantry row: six bowls along the back
		local bowls, owner = {}, {}
		for i, id in ipairs(shelf) do
			local x = -4.9 + (i - 1) * 2.35
			cyl(0.5, 2.0, CFrame.new(x, 0.25, -3.6), Color3.fromRGB(250, 250, 248), SMOOTH).CanQuery = false
			cyl(0.52, 1.7, CFrame.new(x, 0.26, -3.6), Color3.fromRGB(224, 228, 232), SMOOTH).CanQuery = false
			local m = ingredient(id)
			m:ScaleTo(1.3)
			m:PivotTo(CFrame.new(x, 0.5, -3.6) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0))
			local b = { m = m, id = id, x = x }
			table.insert(bowls, b)
			for _, p in ipairs(partsOf(m)) do owner[p] = b end
		end
		-- board, knife, stove, pan, plate, bell
		part(Vector3.new(4.6, 0.25, 3.0), CFrame.new(-4.4, 0.13, 1.2), Color3.fromRGB(206, 156, 100), WOODM).CanQuery = false
		local knife = model("Knife")
		part(Vector3.new(2.6, 0.5, 0.06), CFrame.new(0, 0, 0), CHROME, METAL, knife)
		part(Vector3.new(1.1, 0.32, 0.18), CFrame.new(1.8, 0.04, 0), Color3.fromRGB(40, 36, 34), SMOOTH, knife)
		done(knife)
		for _, p in ipairs(partsOf(knife)) do p.CanQuery = false end
		local knifeRest = CFrame.new(-4.4, 0.45, 3.0) * CFrame.Angles(math.rad(90), 0, 0)
		knife:PivotTo(knifeRest)
		part(Vector3.new(5.0, 0.3, 3.8), CFrame.new(4.2, 0.15, 0.6), Color3.fromRGB(29, 29, 30), Enum.Material.Glass).CanQuery = false
		local burner = cyl(0.04, 2.8, CFrame.new(4.2, 0.32, 0.6), Color3.fromRGB(80, 30, 26), SMOOTH)
		burner.CanQuery = false
		local panM = model("Pan")
		cyl(0.4, 2.6, CFrame.new(0, 0.55, 0), Color3.fromRGB(55, 56, 58), METAL, panM)
		cyl(0.06, 2.25, CFrame.new(0, 0.74, 0), Color3.fromRGB(81, 82, 84), METAL, panM)
		part(Vector3.new(2.2, 0.2, 0.36), CFrame.new(2.2, 0.62, 0), Color3.fromRGB(40, 36, 34), SMOOTH, panM)
		done(panM)
		for _, p in ipairs(partsOf(panM)) do p.CanQuery = false end
		panM:PivotTo(CFrame.new(4.2, 0, 0.6))
		local plateP = cyl(0.14, 2.6, CFrame.new(0.2, 0.08, 2.4), Color3.fromRGB(252, 252, 250), SMOOTH)
		local plateRing = cyl(0.03, 3.4, CFrame.new(0.2, 0.03, 2.4), T.gold, Enum.Material.Neon)
		plateRing.Transparency = 1
		plateRing.CanQuery = false
		local bell = model("Bell")
		local bellBase = cyl(0.22, 1.4, CFrame.new(0, 0.11, 0), Color3.fromRGB(60, 40, 30), WOODM, bell)
		local dome = ell(Vector3.new(1.15, 0.9, 1.15), CFrame.new(0, 0.38, 0), BRASS, METAL, bell)
		ball(0.24, CFrame.new(0, 0.88, 0), BRASS, METAL, bell)
		done(bell)
		bell:PivotTo(CFrame.new(6.2, 0, 2.9))
		local bellRing = cyl(0.03, 2.0, CFrame.new(6.2, 0.03, 2.9), T.gold, Enum.Material.Neon)
		bellRing.Transparency = 1
		bellRing.CanQuery = false
		-- the ticket (2D, top left)
		local ticket = box({ Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(170, 52 + #items * 22), BackgroundColor3 = PAPER, ZIndex = 20, Rotation = -2 })
		UI.corner(ticket, 6)
		UI.stroke(ticket, 1.5, Color3.fromRGB(200, 180, 150), 0)
		text(ticket, "ORDER", 10, { FontFace = UI.F.black, TextColor3 = Color3.fromRGB(176, 128, 52), Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(100, 12), TextXAlignment = LEFT, ZIndex = 21 })
		text(ticket, d.dishName or "Dish", 15, { FontFace = UI.F.black, TextColor3 = INK_TEXT, Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = LEFT, ZIndex = 21 })
		local ticks = {}
		for i, id in ipairs(items) do
			local row = text(ticket, "  " .. id:sub(1, 1):upper() .. id:sub(2), 13, { TextColor3 = Color3.fromRGB(90, 80, 70), Position = UDim2.fromOffset(16, 22 + i * 22), Size = UDim2.new(1, -30, 0, 18), TextXAlignment = LEFT, ZIndex = 21 })
			local dot = box({ Parent = ticket, Position = UDim2.fromOffset(10, 28 + i * 22), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(200, 180, 150), ZIndex = 21 })
			UI.corner(dot, 4)
			ticks[id] = { row = row, dot = dot }
		end

		local step = "prep"
		local picked, chops = {}, 0
		local food, meterBox, marker, zoneL, zoneR
		local heat, flips = 0, 0
		say("Grab the " .. #items .. " ingredients on the ticket")
		setProgress(0)

		local function startCook()
			step = "cook"
			say(stir and "Tap to stir when the sauce hits the gold!" or "Tap to flip it when it hits the gold!")
			burner.Color = Color3.fromRGB(255, 110, 40)
			sound("sizzle")
			-- what goes in the pan
			local raw = PAN3[panKind][1]
			food = model("Food")
			if panKind == "egg" then
				ell(Vector3.new(1.6, 0.14, 1.4), CFrame.new(0, 0.82, 0), raw, SMOOTH, food)
				ell(Vector3.new(0.55, 0.32, 0.55), CFrame.new(0.1, 0.9, 0), Color3.fromRGB(250, 196, 40), SMOOTH, food)
			elseif panKind == "batter" then
				cyl(0.2, 1.7, CFrame.new(0, 0.86, 0), raw, SMOOTH, food)
			elseif panKind == "sauce" then
				cyl(0.18, 2.1, CFrame.new(0, 0.84, 0), raw, SMOOTH, food)
				for i = 1, 4 do ball(0.3, CFrame.new(math.cos(i * 1.6) * 0.55, 0.95, math.sin(i * 1.6) * 0.55), Color3.fromRGB(230, 70, 50), SMOOTH, food) end
			elseif panKind == "steak" then
				ell(Vector3.new(1.6, 0.36, 1.1), CFrame.new(0, 0.94, 0), raw, SMOOTH, food)
			else
				cyl(0.34, 1.4, CFrame.new(0, 0.93, 0), raw, SMOOTH, food)
			end
			done(food)
			for _, p in ipairs(partsOf(food)) do p.CanQuery = false end
			food:PivotTo(CFrame.new(4.2, 0, 0.6))
			food:SetAttribute("Main", true)
			-- the doneness meter
			meterBox = box({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2 + 60, 10), Size = UDim2.fromOffset(330, 48), BackgroundColor3 = T.ink, ZIndex = 20 })
			UI.corner(meterBox, 12)
			UI.stroke(meterBox, 2, T.gold, 0.3)
			text(meterBox, "GET IT GOLDEN", 10, { FontFace = UI.F.black, TextColor3 = T.muted, Position = UDim2.fromOffset(14, 4), Size = UDim2.fromOffset(160, 12), TextXAlignment = LEFT, ZIndex = 21 })
			local bar = box({ Parent = meterBox, Position = UDim2.fromOffset(14, 20), Size = UDim2.new(1, -28, 0, 18), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 21 })
			UI.corner(bar, 9)
			local g = Instance.new("UIGradient")
			local c = PAN3[panKind]
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c[1]), ColorSequenceKeypoint.new(0.6, c[2]), ColorSequenceKeypoint.new(1, c[3]) })
			g.Parent = bar
			zoneL, zoneR = rng:NextNumber(0.5, 0.6), 0
			zoneR = zoneL + 0.16
			local zone = box({ Parent = bar, Position = UDim2.fromScale(zoneL, 0), Size = UDim2.fromScale(zoneR - zoneL, 1), BackgroundTransparency = 1, ZIndex = 22 })
			UI.corner(zone, 6)
			UI.stroke(zone, 3, T.gold, 0)
			marker = box({ Parent = bar, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(7, 28), BackgroundColor3 = T.cream, ZIndex = 23 })
			UI.corner(marker, 3)
			UI.pop(meterBox, 0.6, 0.3)
			heat = 0
		end
		local function tint(k) -- 0 raw .. 1 golden .. 2 burnt
			local c = PAN3[panKind]
			local col = k <= 1 and c[1]:Lerp(c[2], k) or c[2]:Lerp(c[3], math.min(k - 1, 1))
			for _, p in ipairs(partsOf(food)) do
				if p.Color ~= Color3.fromRGB(250, 196, 40) and p.Color ~= Color3.fromRGB(230, 70, 50) then p.Color = col end
			end
		end
		local function startPlate()
			V.hand = nil
			step = "plate"
			say("Tap the plate to serve it up")
			burner.Color = Color3.fromRGB(80, 30, 26)
			plateRing.Transparency = 0.2
			if meterBox then
				UI.tween(UI.scaleOf(meterBox), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			end
		end
		local function flip(good, perfect, why)
			step = "flipping"
			flips += 1
			if not good then S.mistakes += 1 end
			local at = toArea(Vector3.new(4.2, 1.6, 0.6))
			floatText(at - Vector2.new(0, 40), why or (perfect and "Perfect!" or (good and "Golden!" or "Hmm...")), good and (perfect and T.gold or T.green) or T.red)
			burst(at, good and T.gold or Color3.fromRGB(120, 110, 100), good and 12 or 6, 70)
			sound(stir and "chop" or "flip")
			local c0 = food:GetPivot()
			if stir then
				tweenPivot(food, c0 * CFrame.Angles(0, math.pi, 0), 0.35, Enum.EasingStyle.Back)
			else
				tweenPivot(food, c0 * CFrame.new(0, 2.6, 0) * CFrame.Angles(math.pi / 2, 0, 0), 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.delay(0.2, function() if food.Parent then tweenPivot(food, CFrame.new(4.2, 0, 0.6), 0.22, Enum.EasingStyle.Bounce) end end)
			end
			tint(good and 1 or (heat >= 1 and 2 or 0.4))
			task.delay(0.5, function() if S then startPlate() end end)
		end
		local function chopNext()
			chops += 1
			-- the knife comes down on the next ingredient in line
			local b = picked[math.min(#picked, (chops - 1) // 2 + 1)]
			local at = b.m:GetPivot().Position
			V.hand, V.handOff = knife, Vector3.zero
			knife:PivotTo(CFrame.new(at.X, 1.6, at.Z) * CFrame.Angles(math.rad(90), 0, math.rad(90)))
			tweenPivot(knife, CFrame.new(at.X, 0.55, at.Z) * CFrame.Angles(math.rad(90), 0, math.rad(90)), 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.08, function()
				if not S then return end
				tweenPivot(knife, CFrame.new(at.X, 1.6, at.Z) * CFrame.Angles(math.rad(90), 0, math.rad(90)), 0.1)
			end)
			sound("chop")
			burst(toArea(at + Vector3.new(0, 0.5, 0)), RAW3[b.id] or T.cream, 5, 40)
			if chops % 2 == 0 then
				-- chopped: the piece becomes a little pile
				local pile = model("Pile")
				for i = 1, 5 do
					ell(Vector3.new(0.38, 0.22, 0.32), CFrame.new(math.cos(i * 1.3) * 0.35, 0.12 + (i > 3 and 0.12 or 0), math.sin(i * 1.3) * 0.3) * CFrame.Angles(0, i, 0), RAW3[b.id] or T.cream, SMOOTH, pile)
				end
				done(pile)
				pile:PivotTo(CFrame.new(at.X, 0.26, at.Z))
				b.m:Destroy()
				b.m = pile
			end
			setProgress(0.25 + 0.25 * chops / (#items * 2))
			if chops >= #items * 2 then
				step = "toPan"
				tweenPivot(knife, knifeRest, 0.3)
				for i, pb in ipairs(picked) do
					task.delay(0.1 * i, function()
						if not S then return end
						tweenPivot(pb.m, CFrame.new(4.2, 1.6, 0.6), 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						task.delay(0.26, function() pb.m:Destroy() end)
					end)
				end
				task.delay(0.2 + 0.1 * #picked + 0.3, function() if S then startCook() end end)
			end
		end
		S.onDown = function(p)
			if step == "prep" then
				local list = {}
				for pp in pairs(owner) do table.insert(list, pp) end
				local r = pick(p, list)
				local b = r and owner[r.Instance]
				if not b or b.used then return end
				if table.find(items, b.id) and not ticks[b.id].done then
					b.used = true
					ticks[b.id].done = true
					ticks[b.id].dot.BackgroundColor3 = T.green
					ticks[b.id].row.TextColor3 = Color3.fromRGB(46, 150, 84)
					table.insert(picked, b)
					local k = #picked
					tweenPivot(b.m, CFrame.new(-6.0 + (k - 1) * (3.4 / math.max(#items - 1, 1)), 0.26, 1.2) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 0.35, Enum.EasingStyle.Back)
					sound("select")
					setProgress(0.25 * k / #items)
					if k == #items then
						step = "chop"
						task.delay(0.35, function() if S then say("Chop chop! Tap fast") end end)
					end
				else
					miss(ticket, p, "Not on the order!")
					tweenPivot(b.m, b.m:GetPivot() * CFrame.new(0, 0.6, 0), 0.08)
					task.delay(0.08, function() if b.m.Parent then tweenPivot(b.m, CFrame.new(b.x, 0.5, -3.6), 0.3, Enum.EasingStyle.Bounce) end end)
				end
			elseif step == "chop" then
				chopNext()
			elseif step == "cook" then
				local good = heat >= zoneL and heat <= zoneR
				local perfect = math.abs(heat - (zoneL + zoneR) / 2) < 0.03
				flip(good, perfect, not good and (heat < zoneL and "Too early!" or "Overdone!") or nil)
			elseif step == "plate" then
				if pick(p, { plateP }) then
					step = "serving"
					plateRing.Transparency = 1
					tweenPivot(food, CFrame.new(0.2, 0.4, 2.4), 0.3, Enum.EasingStyle.Quad)
					sound("place")
					task.delay(0.3, function()
						if not S then return end
						food:Destroy()
						local dish = dishModel(d.dish or "burger")
						dish:PivotTo(CFrame.new(0.2, 0.16, 2.4))
						burst(toArea(Vector3.new(0.2, 1.2, 2.4)), T.gold, 12, 80)
						setProgress(0.9)
						step = "bell"
						say("Ring the bell!")
						bellRing.Transparency = 0.2
					end)
				end
			elseif step == "bell" then
				if pick(p, { bellBase, dome }) then
					step = "done"
					bellRing.Transparency = 1
					tweenPivot(bell, bell:GetPivot() * CFrame.new(0, -0.12, 0), 0.06)
					task.delay(0.07, function() if bell.Parent then tweenPivot(bell, CFrame.new(6.2, 0, 2.9), 0.3, Enum.EasingStyle.Elastic) end end)
					sound("bell")
					floatText(toArea(Vector3.new(6.2, 2, 2.9)), "Order up!", T.gold)
					setProgress(1)
					task.delay(0.4, win)
				end
			end
		end
		table.insert(S.conns, RunService.Heartbeat:Connect(function(dt)
			if not S then return end
			local t = os.clock()
			if step == "cook" then
				heat += dt / 3.4
				marker.Position = UDim2.fromScale(math.min(heat, 1), 0.5)
				tint(math.min(heat / ((zoneL + zoneR) / 2), 1) + math.max(0, heat - zoneR) * 3)
				food:PivotTo(CFrame.new(4.2, math.abs(math.sin(t * 18)) * 0.04, 0.6))
				if math.random() < 0.3 then burst(toArea(Vector3.new(4.2 + rng:NextNumber(-0.8, 0.8), 1.1, 0.6)), Color3.fromRGB(255, 220, 160), 1, 20) end
				if heat >= 1 then flip(false, false, "Burnt!") end
			elseif step == "plate" then
				plateRing.Transparency = 0.25 + math.sin(t * 6) * 0.2
			elseif step == "bell" then
				bellRing.Transparency = 0.25 + math.sin(t * 6) * 0.2
			end
		end))
	end

	---------------------------------------------------------------- Repair: wires, bolts, power
	local WIRE3 = { Color3.fromRGB(232, 72, 72), Color3.fromRGB(70, 140, 240), Color3.fromRGB(250, 200, 60), Color3.fromRGB(80, 200, 110) }

	G3.Repair = function()
		S.mistakes = 0
		scene({ cam = CFrame.lookAt(Vector3.new(4.6, 3.6, 15.6), Vector3.new(0.5, -0.3, 0)), fov = 38, bg = Color3.fromRGB(50, 56, 70), ambient = Color3.fromRGB(148, 149, 152), dir = Vector3.new(-0.5, -0.7, -0.8) })
		-- a chunky steel frame round the bay and the power box, so the panel has depth
		for _, b in ipairs({ { -1.6, 12.8 }, { 6.6, 4.8 } }) do
			local x, w = b[1], b[2]
			for _, e in ipairs({ { Vector3.new(w, 0.45, 1.1), CFrame.new(x, 4.1, 0.25) }, { Vector3.new(w, 0.45, 1.1), CFrame.new(x, -4.1, 0.25) }, { Vector3.new(0.45, 8.65, 1.1), CFrame.new(x - w / 2, 0, 0.25) }, { Vector3.new(0.45, 8.65, 1.1), CFrame.new(x + w / 2, 0, 0.25) } }) do
				part(e[1], e[2], Color3.fromRGB(86, 94, 112), METAL).CanQuery = false
			end
		end
		cyl(9, 0.7, CFrame.new(7.6, 8.6, -0.3), Color3.fromRGB(120, 128, 146), METAL).CanQuery = false
		cyl(9, 0.5, CFrame.new(-6.4, -8.4, -0.3), Color3.fromRGB(120, 128, 146), METAL).CanQuery = false
		local wall = part(Vector3.new(60, 40, 1), CFrame.new(0, 0, -1), Color3.fromRGB(110, 118, 136), Enum.Material.DiamondPlate)
		wall.CanQuery = false
		local bay = part(Vector3.new(12.4, 7.8, 0.4), CFrame.new(-1.6, 0, -0.2), Color3.fromRGB(42, 45, 48), METAL)
		bay.CanQuery = false
		local pbox = part(Vector3.new(4.4, 7.8, 0.4), CFrame.new(6.6, 0, -0.2), Color3.fromRGB(54, 56, 60), METAL)
		pbox.CanQuery = false
		for _, c in ipairs({ { -7.5, 3.6 }, { 4.3, 3.6 }, { -7.5, -3.6 }, { 4.3, -3.6 }, { 4.7, 3.6 }, { 8.5, 3.6 }, { 4.7, -3.6 }, { 8.5, -3.6 } }) do
			cylZ(0.1, 0.25, CFrame.new(c[1], c[2], 0.05), Color3.fromRGB(110, 118, 136), METAL).CanQuery = false
		end
		-- hazard stripes along the top of the power box
		for i = 0, 4 do
			part(Vector3.new(0.4, 0.5, 0.05), CFrame.new(5.0 + i * 0.7, 3.5, 0.02) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(250, 196, 40)).CanQuery = false
		end
		local function lbl(pos, s) local l = tag3(pos, s, T.gold, 11, 70); l.BackgroundTransparency = 1; return l end
		local wiringLbl = lbl(Vector3.new(-6.4, 3.4, 0.1), "WIRING")
		local ys = { 2.4, 0.8, -0.8, -2.4 }
		local order = shuffle({ 1, 2, 3, 4 })
		local stubs, terms, termParts = {}, {}, {}
		for i, col in ipairs(WIRE3) do
			local y = ys[i]
			cylX(1.6, 0.36, CFrame.new(-7.6, y, 0.3), col, SMOOTH).CanQuery = false
			local plug = ball(0.62, CFrame.new(-6.8, y, 0.3), col, SMOOTH)
			ball(0.28, CFrame.new(-6.55, y, 0.45), Color3.fromRGB(230, 170, 90), METAL).CanQuery = false
			stubs[i] = { col = col, pos = Vector3.new(-6.8, y, 0.3), plug = plug }
			local ty = ys[order[i]]
			local ring = cylZ(0.3, 1.1, CFrame.new(3.0, ty, 0.15), col, SMOOTH)
			cylZ(0.32, 0.55, CFrame.new(3.0, ty, 0.16), Color3.fromRGB(27, 28, 30), METAL).CanQuery = false
			cylX(1.2, 0.2, CFrame.new(3.9, ty, 0.1), col:Lerp(Color3.new(0, 0, 0), 0.25), SMOOTH).CanQuery = false
			terms[i] = { col = col, pos = Vector3.new(3.0, ty, 0.3), ring = ring }
			termParts[ring] = terms[i]
		end
		-- the power box: a lamp and a lever
		local lamp = ball(1.1, CFrame.new(6.6, 2.2, 0.3), Color3.fromRGB(230, 50, 50), Enum.Material.Neon)
		lamp.CanQuery = false
		cylZ(0.3, 1.5, CFrame.new(6.6, 2.2, 0.05), Color3.fromRGB(27, 28, 30), METAL).CanQuery = false
		local lampLbl = lbl(Vector3.new(6.6, 1.2, 0.3), "OFF")
		lampLbl.TextColor3 = T.red
		part(Vector3.new(0.5, 4.0, 0.2), CFrame.new(6.6, -1.4, 0.05), Color3.fromRGB(19, 20, 22)).CanQuery = false
		local LEVER_UP, LEVER_DOWN = 0.2, -3.0
		local lever = model("Lever")
		local handle = part(Vector3.new(1.8, 0.7, 0.7), CFrame.new(0, 0, 0.55), Color3.fromRGB(210, 56, 50), SMOOTH, lever)
		part(Vector3.new(0.3, 0.3, 0.5), CFrame.new(0, 0, 0.15), CHROME, METAL, lever)
		done(lever)
		lever:PivotTo(CFrame.new(6.6, LEVER_UP, 0))
		local leverRing = cylZ(0.04, 2.6, CFrame.new(6.6, LEVER_UP, 0.1), T.gold, Enum.Material.Neon)
		leverRing.Transparency = 1
		leverRing.CanQuery = false
		local onLbl = lbl(Vector3.new(6.6, -3.75, 0.3), "ON")
		onLbl.TextColor3 = T.muted

		local step, connected, drag = "wires", 0, nil
		local bolts, boltParts, tight = {}, {}, 0
		say("Drag each wire to the terminal of its colour")
		setProgress(0)
		local function wireBetween(w, a, b)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			w.Size = Vector3.new(math.max(len, 0.05), 0.32, 0.32)
			w.CFrame = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0)
		end
		local function startBolts()
			step = "bolts"
			say("Tighten the four bolts on the cover")
			wiringLbl:Destroy()
			sound("open")
			local cover = model("Cover")
			part(Vector3.new(12.2, 7.4, 0.25), CFrame.new(0, 0, 0), Color3.fromRGB(150, 160, 178), METAL, cover)
			for i = 0, 5 do part(Vector3.new(6, 0.28, 0.05), CFrame.new(0, -1.6 + i * 0.6, 0.14), Color3.fromRGB(46, 52, 66), SMOOTH, cover) end
			done(cover)
			for _, pp in ipairs(partsOf(cover)) do pp.CanQuery = false end
			cover:PivotTo(CFrame.new(-1.6, 9, 0.8))
			tweenPivot(cover, CFrame.new(-1.6, 0, 0.8), 0.4, Enum.EasingStyle.Back)
			lbl(Vector3.new(-1.6, 2.6, 1), "SERVICE PANEL").TextColor3 = Color3.fromRGB(74, 77, 82)
			for i, c in ipairs({ { -7.2, 3.1 }, { 4.0, 3.1 }, { -7.2, -3.1 }, { 4.0, -3.1 } }) do
				local b = model("Bolt")
				local head = cylZ(0.4, 0.8, CFrame.new(0, 0, 0), Color3.fromRGB(214, 220, 232), METAL, b)
				part(Vector3.new(0.6, 0.12, 0.08), CFrame.new(0, 0, 0.2), Color3.fromRGB(70, 78, 96), SMOOTH, b)
				done(b)
				local bd = { m = b, pos = Vector3.new(c[1], c[2], 0), turns = 0, rot = rng:NextNumber(0.3, 1.2) }
				b:PivotTo(CFrame.new(c[1], c[2], 1.8) * CFrame.Angles(0, 0, bd.rot))
				task.delay(0.35, function()
					if b.Parent then tweenPivot(b, CFrame.new(c[1], c[2], 1.45) * CFrame.Angles(0, 0, bd.rot), 0.25, Enum.EasingStyle.Back) end
				end)
				bd.ring = cylZ(0.03, 1.3, CFrame.new(c[1], c[2], 0.96), T.gold, Enum.Material.Neon)
				bd.ring.Transparency = 1
				bd.ring.CanQuery = false
				table.insert(bolts, bd)
				boltParts[head] = bd
				for _, pp in ipairs(partsOf(b)) do boltParts[pp] = bd end
			end
		end
		local function startLever()
			step = "lever"
			say("Switch the power back on")
			leverRing.Transparency = 0.6
		end
		S.onDown = function(p)
			if step == "wires" then
				local list = {}
				for _, s in ipairs(stubs) do if not s.done then table.insert(list, s.plug) end end
				local r = pick(p, list)
				if not r then return end
				for _, s in ipairs(stubs) do
					if s.plug == r.Instance then
						local w = cylX(0.1, 0.32, CFrame.new(s.pos), s.col, SMOOTH)
						w.CanQuery = false
						drag = { s = s, w = w }
						sound("select")
						S.onMove(p)
						return
					end
				end
			elseif step == "bolts" then
				local list = {}
				for pp in pairs(boltParts) do table.insert(list, pp) end
				local r = pick(p, list)
				local b = r and boltParts[r.Instance]
				if b and b.turns < 2 then
					b.turns += 1
					b.rot += math.pi / 2
					tweenPivot(b.m, CFrame.new(b.pos.X, b.pos.Y, b.turns == 2 and 1.0 or 1.22) * CFrame.Angles(0, 0, b.rot), 0.18, Enum.EasingStyle.Back)
					sound("turn")
					if b.turns == 2 then
						tight += 1
						b.ring.Color = T.green
						b.ring.Transparency = 0.55
						burst(toArea(b.pos + Vector3.new(0, 0, 1)), Color3.fromRGB(200, 210, 226), 6, 40)
						sound("tick")
						setProgress(0.5 + tight / 4 * 0.35)
						if tight == 4 then task.delay(0.25, function() if S then startLever() end end) end
					end
				end
			elseif step == "lever" then
				if pick(p, { handle }) then
					step = "done"
					leverRing.Transparency = 1
					tweenPivot(lever, CFrame.new(6.6, LEVER_DOWN, 0), 0.2, Enum.EasingStyle.Back)
					handle.Color = Color3.fromRGB(70, 180, 96)
					sound("place")
					task.delay(0.18, function()
						if not S then return end
						lamp.Color = Color3.fromRGB(90, 230, 120)
						lampLbl.Text = "ON"
						lampLbl.TextColor3 = T.green
						onLbl.TextColor3 = T.green
						burst(toArea(Vector3.new(6.6, 2.2, 0.3)), T.green, 14, 90)
						sound("register")
						setProgress(1)
						task.delay(0.4, win)
					end)
				end
			end
		end
		S.onMove = function(p)
			if not drag then return end
			local w = onPlane(p, Vector3.new(0, 0, 0.3), Vector3.zAxis)
			if w then
				wireBetween(drag.w, drag.s.pos, w)
				V.handPos = w + Vector3.new(0, 0, 0.3)
			end
		end
		S.onUp = function(p)
			if not drag then return end
			local dd = drag
			drag = nil
			V.handPos = nil
			local w = p and onPlane(p, Vector3.new(0, 0, 0.3), Vector3.zAxis)
			if w then
				for _, t in ipairs(terms) do
					if not t.done and (w - t.pos).Magnitude < 1.0 then
						if t.col == dd.s.col then
							t.done, dd.s.done = true, true
							wireBetween(dd.w, dd.s.pos, t.pos)
							burst(toArea(t.pos), T.gold, 10, 50)
							sound("place")
							connected += 1
							setProgress(connected / 4 * 0.5)
							if connected == 4 then
								floatText(toArea(Vector3.new(-1.6, 0, 0.5)), "All wired!", T.green)
								task.delay(0.45, function() if S then startBolts() end end)
							end
						else
							S.mistakes += 1
							S.t0 -= 1
							floatText(toArea(t.pos), "Wrong colour!", T.red)
							burst(toArea(t.pos), T.red, 8, 40)
							sound("error")
							dd.w:Destroy()
						end
						return
					end
				end
			end
			dd.w:Destroy()
		end
		-- loose wires spark, the lever ring breathes
		local acc = 0
		table.insert(S.conns, RunService.Heartbeat:Connect(function(dt)
			if not S then return end
			if step == "lever" then leverRing.Transparency = 0.62 + math.sin(os.clock() * 6) * 0.18 end
			if step ~= "wires" then return end
			acc += dt
			if acc > 0.4 then
				acc = 0
				local live = {}
				for _, s in ipairs(stubs) do if not s.done and not (drag and drag.s == s) then table.insert(live, s) end end
				if #live > 0 then burst(toArea(live[rng:NextInteger(1, #live)].pos + Vector3.new(0.35, 0, 0)), Color3.fromRGB(255, 230, 120), 4, 26) end
			end
		end))
	end
end

-- the flat (2D) versions above stay as a fallback: set FLAT = true to play them instead
local FLAT = false
local GAMES = FLAT and { Floor = playFloor, Bed = playBed, Shower = playShower, Toilet = playToilet, CheckIn = playCheckIn, CheckOut = playCheckOut, Cook = playCook, Repair = playRepair } or G3

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

local function open(kind, data)
	if S or not GAMES[kind] then return end
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
	local function card(props)
		local f = new("Frame", props)
		f.BackgroundColor3 = T.ink
		f.BackgroundTransparency = 0.06
		f.Parent = hud
		UI.corner(f, 18)
		UI.stroke(f, 1.5, T.gold, 0.55)
		return f
	end
	local subtitle = data and (data.guest and (data.guest .. (data.room and (", room " .. data.room) or "")) or (data.room and ("Room " .. data.room))) or "Overbooked"
	local titleCard = card({ Name = "Title", Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(330, 66) })
	UI.icon(titleCard, C.ICONS[info.icon] or C.ICONS.clean, 42, { Position = UDim2.fromOffset(12, 12) })
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
	local track = new("Frame", { Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -36, 0, 10), BackgroundColor3 = T.ink2, Parent = hintCard })
	UI.corner(track, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	UI.corner(fill, 5)
	UI.grad(fill, T.green, T.greenDk, 90)
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
		table.insert(S.conns, RunService.RenderStepped:Connect(function()
			if S ~= me or me.won then return end
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
