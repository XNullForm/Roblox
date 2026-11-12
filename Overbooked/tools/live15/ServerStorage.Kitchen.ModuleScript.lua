-- ServerStorage.Kitchen (round 10c): meals. The kitchen opens at hotel level 3 once the hotel has a Stove
-- and a Serving Counter (build mode, Kitchen tab). Hungry guests order at the counter (GuestLife "eat"),
-- wait beside it, collect their plate when it's up, then eat at a cafe table (or standing) and pay.
-- Orders are cooked by a Cook (staff "cook": walks to a stove, cooks, plates up at the pass) or by a player:
-- a stove's Cook prompt opens the cooking minigame (Minigames "Cook"); its stars set the meal's quality.
-- HotelSim makes one per hotel: Kitchen.new(ctx), ctx = its evCtx (see there for the fields used).
local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Levels = require(RS.Shared:WaitForChild("Levels"))

local Kitchen = {}
Kitchen.__index = Kitchen

-- counter-local spots (pivot = floor centre, guests on +Z). Plates sit on the marble pass.
local SLOTS = { -1.0, 0.1, 1.2 }
local PASS_TOP = 3.38
local STOVE_PAN = Vector3.new(-0.98, 3.02, 0.55) -- the front-left pan

local function flat(v) return Vector3.new(v.X, 0, v.Z) end

-- a stable key per model (GetDebugId needs Plugin capability, so game scripts can't use it)
local modelKeys = setmetatable({}, { __mode = "k" })
local nextKey = 0
local function keyOf(m)
	local k = modelKeys[m]
	if not k then
		nextKey += 1
		k = tostring(nextKey)
		modelKeys[m] = k
	end
	return k
end

---------------------------------------------------------------- plates of food (simple parts, by dish)

local function bit(m, name, shape, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Parent = m
	return p
end

-- a plate with the dish on it, its base at the origin
local function plate(dish)
	local m = Instance.new("Model")
	m.Name = "Meal"
	local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie on X; this stands them up
	local base = bit(m, "Plate", CYL, Vector3.new(0.08, 1.15, 1.15), CFrame.new(0, 0.04, 0) * up, Color3.fromRGB(250, 250, 246))
	bit(m, "Rim", CYL, Vector3.new(0.05, 1.25, 1.25), CFrame.new(0, 0.07, 0) * up, Color3.fromRGB(226, 200, 140), Enum.Material.Metal)
	local id = dish.id
	if id == "burger" then
		bit(m, "Bun", CYL, Vector3.new(0.16, 0.66, 0.66), CFrame.new(0, 0.17, 0) * up, Color3.fromRGB(222, 160, 84))
		bit(m, "Patty", CYL, Vector3.new(0.16, 0.7, 0.7), CFrame.new(0, 0.32, 0) * up, Color3.fromRGB(104, 58, 34))
		bit(m, "Cheese", nil, Vector3.new(0.62, 0.05, 0.62), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(250, 200, 60))
		bit(m, "Lettuce", CYL, Vector3.new(0.05, 0.72, 0.72), CFrame.new(0, 0.46, 0) * up, Color3.fromRGB(120, 196, 80))
		bit(m, "Top", BALL, Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.5, 0), Color3.fromRGB(226, 156, 76)).Size = Vector3.new(0.7, 0.42, 0.7)
	elseif id == "omelette" then
		bit(m, "Egg", BALL, Vector3.new(0.9, 0.3, 0.6), CFrame.new(0, 0.18, 0), Color3.fromRGB(250, 214, 90))
		for i = 1, 3 do bit(m, "Herb", BALL, Vector3.new(0.1, 0.06, 0.1), CFrame.new(-0.2 + i * 0.12, 0.33, (i % 2) * 0.1 - 0.05), Color3.fromRGB(80, 150, 60)) end
	elseif id == "pancakes" then
		for i = 0, 2 do bit(m, "Cake", CYL, Vector3.new(0.12, 0.82, 0.82), CFrame.new(0, 0.15 + i * 0.12, 0) * up, Color3.fromRGB(226, 170, 96)) end
		bit(m, "Butter", nil, Vector3.new(0.2, 0.1, 0.2), CFrame.new(0, 0.5, 0), Color3.fromRGB(255, 236, 160))
		for i = 1, 4 do bit(m, "Berry", BALL, Vector3.new(0.13, 0.13, 0.13), CFrame.new(math.cos(i * 1.6) * 0.3, 0.48, math.sin(i * 1.6) * 0.3), Color3.fromRGB(110, 40, 120)) end
	elseif id == "steak" then
		bit(m, "Steak", nil, Vector3.new(0.6, 0.18, 0.42), CFrame.new(-0.12, 0.18, 0) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(120, 62, 40))
		for i = 1, 3 do bit(m, "Carrot", nil, Vector3.new(0.3, 0.07, 0.07), CFrame.new(0.28, 0.14, -0.2 + i * 0.1) * CFrame.Angles(0, 0.2 * i, 0), Color3.fromRGB(240, 132, 40)) end
		for i = 1, 2 do bit(m, "Broccoli", BALL, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.15 + i * 0.1, 0.2, 0.28), Color3.fromRGB(70, 140, 60)) end
	else -- pasta
		bit(m, "Pasta", BALL, Vector3.new(0.8, 0.32, 0.8), CFrame.new(0, 0.18, 0), Color3.fromRGB(240, 210, 130))
		bit(m, "Sauce", BALL, Vector3.new(0.5, 0.16, 0.5), CFrame.new(0, 0.32, 0), Color3.fromRGB(200, 50, 40))
		bit(m, "Basil", nil, Vector3.new(0.14, 0.03, 0.08), CFrame.new(0.05, 0.41, 0) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(70, 150, 60))
	end
	m.PrimaryPart = base
	m.WorldPivot = CFrame.new()
	-- a wisp of steam off the hot food
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 0.6, 0)
	a.Parent = base
	local st = Instance.new("ParticleEmitter")
	st.Texture = "rbxasset://textures/particles/smoke_main.dds"
	st.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	st.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) })
	st.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	st.Lifetime = NumberRange.new(1, 1.6)
	st.Speed = NumberRange.new(0.6, 1)
	st.Rate = 3
	st.LightEmission = 0.2
	st.Parent = a
	return m
end
Kitchen.plate = plate

---------------------------------------------------------------- the kitchen

function Kitchen.new(ctx)
	local k = setmetatable({ ctx = ctx, orders = {}, stoves = {}, slots = {} }, Kitchen)
	task.spawn(function() k:watch() end)
	return k
end

-- placed pieces of the kitchen
function Kitchen:items(id)
	local out = {}
	for _, m in ipairs(self.ctx.PLACED:GetChildren()) do
		if m:GetAttribute("Item") == id and m:GetAttribute("Zone") == "Lobby" then table.insert(out, m) end
	end
	return out
end

function Kitchen:open()
	local H = self.ctx.HOTEL
	return Levels.featureOk(H, "kitchen") and #self:items("Stove") > 0 and #self:items("ServingCounter") > 0
end

local function depthOf(m) return m:GetExtentsSize().Z end

-- the counter nearest to a position
function Kitchen:counter(pos)
	local best, bd
	for _, m in ipairs(self:items("ServingCounter")) do
		local d = (m:GetPivot().Position - pos).Magnitude
		if not bd or d < bd then best, bd = m, d end
	end
	return best
end

-- where a guest stands to order, or waits (side = -1/1), or collects from a plate slot
function Kitchen:frontSpot(counter, x, back)
	local piv = counter:GetPivot()
	local p = (piv * CFrame.new(x or 0, 0, 1.3 + (back or 1.6))).Position
	return Vector3.new(p.X, piv.Y + 3, p.Z)
end

function Kitchen:stoveFront(stove)
	local piv = stove:GetPivot()
	local p = (piv * CFrame.new(-0.6, 0, depthOf(stove) / 2 + 1.5)).Position
	return Vector3.new(p.X, piv.Y + 3, p.Z)
end

-- the staff side of a counter (behind it)
function Kitchen:passBack(counter)
	local piv = counter:GetPivot()
	local p = (piv * CFrame.new(0, 0, -(1.3 + 1.5))).Position
	return Vector3.new(p.X, piv.Y + 3, p.Z)
end

function Kitchen:freeStove(near)
	local best, bd
	for _, m in ipairs(self:items("Stove")) do
		local st = self.stoves[m]
		if not (st and st.busy) then
			local d = near and (m:GetPivot().Position - near).Magnitude or 0
			if not bd or d < bd then best, bd = m, d end
		end
	end
	return best
end

-- the oldest order nobody is cooking yet
function Kitchen:nextOrder(focus)
	-- round 13: a cook set to "pricey" takes the dearest dish first
	local best
	for _, o in ipairs(self.orders) do
		if o.state == "new" and not o.cook and o.g.alive then
			if focus ~= "pricey" then return o end
			if not best or o.dish.price > best.dish.price then best = o end
		end
	end
	return best
end

function Kitchen:order(g)
	local ctx = self.ctx
	local dish = C.DISHES[ctx.rng:NextInteger(1, #C.DISHES)]
	local o = { g = g, dish = dish, t0 = os.clock(), state = "new" }
	table.insert(self.orders, o)
	ctx.tell("toast", { text = g.name .. " ordered the " .. string.lower(dish.name), icon = "food" })
	return o
end

local function removeFrom(t, v)
	local i = table.find(t, v)
	if i then table.remove(t, i) end
end

function Kitchen:cancel(o)
	o.state = "gone"
	removeFrom(self.orders, o)
	if o.slot then self.slots[o.slot] = nil end
	if o.plate then o.plate:Destroy() o.plate = nil end
end

-- the dish is up: a plate appears on the pass and the bell rings
function Kitchen:ready(o, stars)
	if o.state ~= "new" then return end
	local counter = self:counter(o.g.root and o.g.root.Position or Vector3.zero)
	if not counter then self:cancel(o) return end
	local slotKey, x
	for i, sx in ipairs(SLOTS) do
		local key = keyOf(counter) .. ":" .. i
		if not self.slots[key] then slotKey, x = key, sx break end
	end
	slotKey = slotKey or (keyOf(counter) .. ":1")
	x = x or SLOTS[1]
	self.slots[slotKey] = o
	o.slot, o.counter, o.slotX = slotKey, counter, x
	o.stars = stars or 2
	o.state = "ready"
	local p = plate(o.dish)
	p:PivotTo(counter:GetPivot() * CFrame.new(x, PASS_TOP, 0.2) * CFrame.Angles(0, math.rad(self.ctx.rng:NextNumber(-20, 20)), 0))
	p.Parent = self.ctx.PLACED.Parent
	o.plate = p
	self.ctx.sfx("bell", p:GetPivot().Position)
	self.ctx.Notify:FireAllClients("plateUp", { pos = p:GetPivot().Position, dish = o.dish.name })
end

-- the guest takes their plate: carried in front of them
function Kitchen:take(o, g)
	if o.slot then self.slots[o.slot] = nil o.slot = nil end
	local p = o.plate
	if not p then return end
	local torso = g.model:FindFirstChild("UpperTorso") or g.model:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	-- every bit welds to the plate, the plate to the hand (held level in front)
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") and d ~= p.PrimaryPart then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = p.PrimaryPart, d
			w.Parent = d
		end
	end
	-- carried level in front, at waist height
	local tcf = torso.CFrame
	p:PivotTo(CFrame.lookAt(tcf.Position, tcf.Position + tcf.LookVector) * CFrame.new(0, -0.75, -1.1))
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = torso, p.PrimaryPart
	w.Parent = p.PrimaryPart
	o.hold = w
	p.Parent = g.model
end

-- put the plate down on a table (world CFrame of the plate's base)
function Kitchen:putDown(o, cf)
	local p = o.plate
	if not p then return end
	if o.hold then o.hold:Destroy() o.hold = nil end
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	p:PivotTo(cf)
	p.Parent = self.ctx.PLACED.Parent
end

-- finished: pay for the meal (price, plus a tip for quality and mood) and clear the plate
function Kitchen:pay(o, g)
	local ctx = self.ctx
	local stars = o.stars or 2
	local amount = o.dish.price + (stars - 1) * 3 + math.floor(math.max(0, (g.mood or 60) - 50) / 10)
	amount = math.floor(amount * (ctx.rmul and ctx.rmul("mealPrice") or 1) + 0.5) -- round 13: Dining research
	local at = g.head and g.head.Position + Vector3.new(0, 2.5, 0) or Vector3.zero
	ctx.earn(amount, at)
	Levels.award(ctx.HOTEL, Levels.XP.meal, "Meal served", at)
	if stars >= 3 then
		ctx.moodShift(g, 10, "The food here is amazing!", "Amazing food.")
	elseif stars == 2 then
		ctx.moodShift(g, 6, "That meal was tasty!", "Tasty food.")
	else
		ctx.moodShift(g, 1, "The food was okay.", nil)
	end
	if ctx.quest then ctx.quest("meal") end
	self:cancel(o)
	return amount
end

---------------------------------------------------------------- stoves: flames, smoke and the Cook prompt

function Kitchen:flame(stove, on)
	local st = self.stoves[stove]
	if not st then return end
	if on and not st.fx then
		local base = stove:FindFirstChildWhichIsA("BasePart")
		if not base then return end
		local a = Instance.new("Attachment")
		a.Name = "CookFX"
		a.WorldCFrame = stove:GetPivot() * CFrame.new(STOVE_PAN)
		a.Parent = base
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "Flame"
		fire.Texture = "rbxasset://textures/particles/fire_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 90, 40))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
		fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		fire.Lifetime = NumberRange.new(0.2, 0.35)
		fire.Speed = NumberRange.new(0.5, 1.2)
		fire.SpreadAngle = Vector2.new(60, 60)
		fire.Rate = 45
		fire.Parent = a
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "Steam"
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.8) })
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		smoke.Lifetime = NumberRange.new(1.2, 1.8)
		smoke.Speed = NumberRange.new(1.5, 2.5)
		smoke.SpreadAngle = Vector2.new(15, 15)
		smoke.Rate = 8
		smoke.Parent = a
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Range = 6
		light.Brightness = 1.2
		light.Parent = a
		st.fx = a
		-- a little flicker
		task.spawn(function()
			while st.fx == a and a.Parent do
				light.Brightness = 0.9 + math.random() * 0.6
				task.wait(0.08)
			end
		end)
	elseif not on and st.fx then
		st.fx:Destroy()
		st.fx = nil
	end
end

-- keeps a Cook prompt on every stove, lit while an order waits and the stove is free
function Kitchen:watch()
	local ctx = self.ctx
	while ctx.running() do
		local live = {}
		for _, m in ipairs(self:items("Stove")) do
			live[m] = true
			local st = self.stoves[m]
			if not st then
				st = {}
				self.stoves[m] = st
				local base = m:FindFirstChildWhichIsA("BasePart")
				if base then
					local pr = Instance.new("ProximityPrompt")
					pr.Name = "CookPrompt"
					pr.ActionText = "Cook"
					pr.KeyboardKeyCode = Enum.KeyCode.E
					pr.HoldDuration = 0.25
					pr.MaxActivationDistance = 9
					pr.RequiresLineOfSight = false
					pr.Style = Enum.ProximityPromptStyle.Custom
					pr:SetAttribute("Icon", "food")
					pr:SetAttribute("Color", "yellow")
					pr.Enabled = false
					pr.Parent = base
					st.prompt = pr
					pr.Triggered:Connect(function(player) self:playerCook(m, player) end)
				end
			end
			local o = self:nextOrder()
			if st.prompt then
				st.prompt.Enabled = o ~= nil and not st.busy and self:open()
				if o then st.prompt.ObjectText = o.dish.name .. " for " .. o.g.name end
			end
		end
		for m, st in pairs(self.stoves) do
			if not live[m] or not m.Parent then
				if st.fx then st.fx:Destroy() end
				self.stoves[m] = nil
			end
		end
		-- orders for guests who left
		for i = #self.orders, 1, -1 do
			local o = self.orders[i]
			if not o.g.alive then self:cancel(o) end
		end
		task.wait(0.4)
	end
	for _, o in ipairs(table.clone(self.orders)) do self:cancel(o) end
end

-- a player cooks: claims the next order and opens the minigame
function Kitchen:playerCook(stove, player)
	local ctx = self.ctx
	if not ctx.isMember(player) then ctx.notMine(player) return end
	if ctx.deskGames[player] or ctx.cleaning[player] then return end
	local st = self.stoves[stove]
	local o = self:nextOrder()
	if not (st and o) or st.busy then return end
	o.cook = player
	st.busy = player
	self:flame(stove, true)
	ctx.status(o.g, "food", o.dish.name .. " on the stove")
	local session = { t0 = os.clock() }
	session.done = function(ok, stars)
		if st.busy == player then st.busy = nil end
		self:flame(stove, false)
		if ok and o.state == "new" and o.g.alive then
			self:ready(o, stars)
		elseif o.cook == player then
			o.cook = nil
		end
	end
	ctx.deskGames[player] = session
	-- the shelf: the dish's three ingredients and three that don't belong
	local shelf = table.clone(o.dish.items)
	local pool = {}
	for _, d in ipairs(C.DISHES) do
		for _, it in ipairs(d.items) do
			if not table.find(shelf, it) and not table.find(pool, it) then table.insert(pool, it) end
		end
	end
	for _ = 1, 3 do
		if #pool == 0 then break end
		table.insert(shelf, table.remove(pool, ctx.rng:NextInteger(1, #pool)))
	end
	ctx.Notify:FireClient(player, "minigame", {
		task = "Cook", guest = o.g.name, dish = o.dish.id, dishName = o.dish.name, items = o.dish.items, pan = o.dish.pan, shelf = shelf,
	})
	task.delay(C.MINIGAME_TIMEOUT, function()
		if ctx.deskGames[player] == session then
			ctx.deskGames[player] = nil
			session.done(false, 0)
			ctx.Notify:FireClient(player, "minigameEnd")
		end
	end)
end

---------------------------------------------------------------- the cook

local CHEF_LINES = { "Order up!", "Service!", "Hot plate coming through!", "Bon appetit!", "Fresh off the stove!" }

function Kitchen:cookLife(s)
	local ctx, g = self.ctx, s.g
	while g.alive do
		if ctx.breakTime and ctx.breakTime(s) then continue end -- round 14: breaks and leaving
		local off = ctx.offShift and ctx.offShift(s) -- round 13: shifts
		local o = not off and self:open() and self:nextOrder(ctx.job and ctx.job(s).focus)
		local stove = o and self:freeStove(g.root.Position)
		if o and stove then
			local st = self.stoves[stove]
			if not st then task.wait(0.5) continue end
			o.cook = g
			st.busy = g
			ctx.status(o.g, "food", o.dish.name .. " on the stove")
			ctx.status(g, "walk", o.dish.name)
			ctx.walkTo(g, self:stoveFront(stove), 1.3)
			ctx.faceTo(g, stove:GetPivot().Position)
			if g.alive and o.state == "new" then
				ctx.status(g, "food", "Cooking " .. string.lower(o.dish.name), "yellow")
				self:flame(stove, true)
				ctx.sfx("sizzle", stove:GetPivot().Position)
				ctx.play(g, "@cook") -- round 14: stirring, pan in the other hand, a toss now and then
				ctx.timed(g, C.COOK_SECS * (ctx.hasPerk("cook") and 0.7 or 1) * (ctx.staffPace and ctx.staffPace(s) or 1))
				ctx.stop(g, "@cook")
				self:flame(stove, false)
			end
			if st.busy == g then st.busy = nil end
			if g.alive and o.state == "new" and o.g.alive then
				local counter = self:counter(o.g.root.Position)
				if counter then
					ctx.status(g, "food", "Plating up")
					ctx.walkTo(g, self:passBack(counter), 1.3)
					ctx.faceTo(g, counter:GetPivot().Position)
				end
				if o.state == "new" and o.g.alive then
					self:ready(o, ctx.rng:NextNumber() < 0.35 and 3 or 2)
					ctx.say(g, CHEF_LINES[ctx.rng:NextInteger(1, #CHEF_LINES)], 2.2)
					ctx.play(g, "present")
				end
			elseif o.cook == g then
				o.cook = nil
			end
			task.wait(0.6)
		else
			-- wait by the stoves for the next order
			local st = self:items("Stove")[1 + (s.index - 1) % math.max(1, #self:items("Stove"))]
			local home = st and (st:GetPivot() * CFrame.new(1.6 * (s.index - 1) - 0.6, 3, depthOf(st) / 2 + 2.6)).Position or s.home
			ctx.status(g, "chef", off and "Off shift" or self:open() and "Waiting for orders" or "Needs a stove and a serving counter")
			if flat(g.root.Position - home).Magnitude > 2.5 then ctx.walkTo(g, home, 1.3) end
			if st then ctx.faceTo(g, st:GetPivot().Position) end
			task.wait(1)
		end
	end
end

return Kitchen
