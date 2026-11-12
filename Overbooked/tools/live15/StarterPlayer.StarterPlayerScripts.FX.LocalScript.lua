-- StarterPlayerScripts.FX (round 14): one place for the game's little moments, played locally from Notify.
-- paid -> a gold coin pop and ring; cleaned -> sparkles and soap bubbles; built -> a dust puff (place / move)
-- or a puff and gold glints (sell); upgraded / roomBuilt / hired -> confetti and a ring.
-- Bursts use a pool of slots (one attachment each): Emit() fires from where its attachment is on the next
-- particle update, so a slot is never moved twice in one frame. Counts follow the graphics quality.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Notify = RS:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Notify")

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local GOLD = Color3.fromRGB(255, 206, 84)

local UGS = UserSettings():GetService("UserGameSettings")
local function budget()
	local ok, q = pcall(function() return UGS.SavedQualityLevel.Value end)
	q = (ok and q and q > 0) and q or 6
	return math.clamp(q / 8, 0.35, 1)
end

local holder = Instance.new("Folder")
holder.Name = "FXLocal"
holder.Parent = workspace

local function seq(...) local t = {} for i, v in ipairs({ ... }) do t[i] = NumberSequenceKeypoint.new(v[1], v[2]) end return NumberSequence.new(t) end

local KINDS = {
	coin = function(e)
		e.Texture = SPARK
		e.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 240, 170))
		e.Size = seq({ 0, 0.85 }, { 0.7, 0.6 }, { 1, 0 })
		e.Lifetime = NumberRange.new(0.5, 0.8)
		e.Speed = NumberRange.new(8, 14)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -26, 0)
		e.LightEmission = 0.7
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-200, 200)
		e.EmissionDirection = Enum.NormalId.Top
	end,
	sparkle = function(e)
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 230, 255))
		e.Size = seq({ 0, 0 }, { 0.25, 0.7 }, { 1, 0 })
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1, 4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.LightEmission = 0.8
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
	end,
	bubble = function(e)
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
		e.Size = seq({ 0, 0.15 }, { 1, 0.4 })
		e.Transparency = seq({ 0, 0.3 }, { 0.8, 0.5 }, { 1, 1 })
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(1.5, 3)
		e.SpreadAngle = Vector2.new(60, 60)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Drag = 1.5
		e.LightEmission = 0.3
		e.EmissionDirection = Enum.NormalId.Top
	end,
	dust = function(e)
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(226, 212, 190))
		e.Size = seq({ 0, 1.2 }, { 1, 3.6 })
		e.Transparency = seq({ 0, 0.55 }, { 1, 1 })
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(5, 9)
		e.SpreadAngle = Vector2.new(85, 85)
		e.Drag = 5
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.EmissionDirection = Enum.NormalId.Top
		e.LightInfluence = 1
	end,
	confetti = function(e)
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 92)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 206, 84)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(96, 200, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(90, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 120, 255)),
		})
		e.Size = seq({ 0, 0.5 }, { 1, 0.4 })
		e.Squash = seq({ 0, -0.5 }, { 0.5, 0.6 }, { 1, -0.5 })
		e.Lifetime = NumberRange.new(1.4, 2.2)
		e.Speed = NumberRange.new(16, 26)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, -22, 0)
		e.Drag = 2.2
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-400, 400)
		e.EmissionDirection = Enum.NormalId.Top
		e.LightInfluence = 0.6
	end,
}

local SLOTS = 10
local slots, nextSlot = {}, 1
for i = 1, SLOTS do
	local a = Instance.new("Attachment")
	a.Name = "Burst" .. i
	a.Parent = workspace.Terrain
	local set = {}
	for k, f in pairs(KINDS) do
		local e = Instance.new("ParticleEmitter")
		e.Name = k
		e.Rate = 0
		e.Enabled = true
		f(e)
		e.Parent = a
		set[k] = e
	end
	slots[i] = { a = a, e = set, used = 0 }
end

local function burst(pos, list)
	local s = slots[nextSlot]
	nextSlot = nextSlot % SLOTS + 1
	s.a.WorldPosition = pos
	local q = budget()
	task.defer(function()
		for k, n in pairs(list) do
			local e = s.e[k]
			if e then e:Emit(math.max(1, math.floor(n * q + 0.5))) end
		end
	end)
end

local function ring(pos, color, size, time)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(0.08, 0.6, 0.6)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = holder
	local tw = TweenService:Create(p, TweenInfo.new(time or 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.04, size, size), Transparency = 1 })
	tw:Play()
	tw.Completed:Connect(function() p:Destroy() end)
end

local function near(pos)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude < 160
end

Notify.OnClientEvent:Connect(function(kind, d)
	d = type(d) == "table" and d or {}
	local pos = typeof(d.pos) == "Vector3" and d.pos or nil
	if not pos or not near(pos) then return end
	if kind == "paid" then
		burst(pos + Vector3.new(0, 1.5, 0), { coin = 14, sparkle = 4 })
		ring(pos + Vector3.new(0, 0.6, 0), GOLD, 7, 0.45)
	elseif kind == "cleaned" then
		burst(pos + Vector3.new(0, 1, 0), { sparkle = 16, bubble = 10 })
		ring(pos + Vector3.new(0, 0.3, 0), Color3.fromRGB(150, 220, 255), 6, 0.6)
	elseif kind == "built" then
		if d.kind == "sell" then
			burst(pos + Vector3.new(0, 0.4, 0), { dust = 10, coin = 10 })
		else
			burst(pos + Vector3.new(0, 0.3, 0), { dust = d.kind == "move" and 6 or 12 })
			ring(pos + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 244, 220), 8, 0.4)
		end
	elseif kind == "upgraded" or kind == "roomBuilt" then
		burst(pos + Vector3.new(0, 1, 0), { dust = 10 })
		task.delay(kind == "roomBuilt" and 1.3 or 0.85, function()
			burst(pos + Vector3.new(0, 2, 0), { confetti = 40, sparkle = 12 })
			ring(pos + Vector3.new(0, 0.4, 0), GOLD, 12, 0.7)
		end)
	elseif kind == "hired" then
		burst(pos + Vector3.new(0, 3, 0), { confetti = 26, sparkle = 8 })
	end
end)
