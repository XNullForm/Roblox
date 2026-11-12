-- ServerStorage.Bodies: the shared NPC body builder (guests, staff, street crowds).
-- Round 9: looks and walk styles come from Shared.Looks. Every body carries attributes WalkAnim, IdleAnim,
-- WalkStyle and WalkSpeedMul, so the crowd and the hotel sims animate it the same way.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Looks = require(RS.Shared:WaitForChild("Looks"))

local Bodies = {}
local rng = Random.new()

function Bodies.description(kind)
	return Looks.description(rng, kind)
end

function Bodies.name()
	return Looks.name(rng)
end

-- round 10c: classic Roblox faces. The default R15 head is now a dynamic head with its face painted into the
-- texture, so a description's Face does nothing; instead the face asset's decal goes on a plain head.
local SMILE = 144075659
local faceTex = {} -- face asset id -> its decal texture (false if it wouldn't load)
local function classicFace(model, faceId, headK)
	faceId = (faceId and faceId > 0) and faceId or SMILE
	local tex = faceTex[faceId]
	if tex == nil then
		tex = false
		local ok, a = pcall(InsertService.LoadAsset, InsertService, faceId)
		if ok and a then
			local d = a:FindFirstChildWhichIsA("Decal", true)
			tex = d and d.Texture or false
			a:Destroy()
		end
		faceTex[faceId] = tex
	end
	local head = model:FindFirstChild("Head")
	if not (tex and head) then return end
	if head:IsA("MeshPart") then head.TextureID = "" end
	local fc = head:FindFirstChildOfClass("FaceControls")
	if fc then fc:Destroy() end
	for _, d in ipairs(head:GetChildren()) do
		if d:IsA("Decal") then d:Destroy() end
	end
	-- round 10d: a classic face decal warps on the dynamic head's UVs (eyes slide sideways), so the real head
	-- goes invisible (it keeps the neck, hair and hat attachments) and a classic head shape carries the face
	local old = model:FindFirstChild("ClassicHead")
	if old then old:Destroy() end
	local ch = Instance.new("Part")
	ch.Name = "ClassicHead"
	ch.Size = Vector3.new(2, 1, 1)
	ch.Color = head.Color
	ch.Material = Enum.Material.SmoothPlastic
	ch.CanCollide, ch.CanQuery, ch.CanTouch, ch.Massless = false, false, false, true
	ch.TopSurface, ch.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	-- round 14: a fixed classic size (it used to follow the dynamic head's height, which stretched faces tall)
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25) * (headK or 1)
	mesh.Parent = ch
	ch.CFrame = head.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = head, ch
	weld.Parent = ch
	ch.Parent = model
	head.Transparency = 1
	local dec = Instance.new("Decal")
	dec.Name = "face"
	dec.Face = Enum.NormalId.Front
	dec.Texture = tex
	dec.Parent = ch
end

-- builds an R15 rig; falls back to a plain rig if the catalog is slow
-- round 12: now and then a guest is one of the players' friends, wearing their real avatar.
-- Bodies.friendPick(players, rng, busy) -> { desc, name, userId } or nil (busy = set of userIds already in)
local friendCache = {} -- userId -> { t, list = { {id, name} } }
local FRIEND_CHANCE = 0.2
local function friendsOf(player)
	local c = friendCache[player.UserId]
	if c and os.clock() - c.t < 600 then return c.list end
	local list = {}
	local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
	if ok and pages then
		for _ = 1, 4 do
			for _, f in ipairs(pages:GetCurrentPage()) do
				table.insert(list, { id = f.Id, name = f.DisplayName or f.Username })
			end
			if pages.IsFinished then break end
			if not pcall(function() pages:AdvanceToNextPageAsync() end) then break end
		end
	end
	friendCache[player.UserId] = { t = os.clock(), list = list }
	return list
end
function Bodies.friendPick(players, rng, busy)
	if rng:NextNumber() > FRIEND_CHANCE then return nil end
	local pool = {}
	for _, p in ipairs(players) do
		for _, f in ipairs(friendsOf(p)) do
			if not (busy and busy[f.id]) then table.insert(pool, { id = f.id, name = f.name, of = p }) end
		end
	end
	if #pool == 0 then return nil end
	local f = pool[rng:NextInteger(1, #pool)]
	local ok, desc = pcall(function() return Players:GetHumanoidDescriptionFromUserId(f.id) end)
	if not ok or not desc then return nil end
	return { desc = desc, name = f.name, userId = f.id, of = f.of }
end

-- round 14: part-built gear (no catalog ids to break): hats, sunglasses, backpacks and crossbody bags,
-- welded to the classic head / upper torso. Everything is massless and never collides or blocks rays.
local function gearPart(parent, name, size, color, cf, mat, meshType)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if meshType then
		local m = Instance.new("SpecialMesh")
		m.MeshType = meshType
		m.Parent = p
	end
	p.CFrame = cf
	p.Parent = parent
	return p
end
local CYL = Enum.MeshType.Cylinder
local SPH = Enum.MeshType.Sphere
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder mesh runs along X; this stands it up
function Bodies.dress(model, g, headK)
	if not g then return end
	local head = model:FindFirstChild("ClassicHead") or model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if not (head and torso) then return end
	for _, a in ipairs(model:GetChildren()) do
		if a:IsA("Accessory") and g.hat then
			if string.find(string.lower(a.Name), "beanie") then g.hat = nil
			elseif g.hat == "beanie" or g.hat == "bucket" then a:Destroy() end
		end
	end
	local gear = Instance.new("Model")
	gear.Name = "Gear"
	local s = 1.25 * (headK or 1) * (head:FindFirstChildOfClass("SpecialMesh") and 1 or head.Size.Y / 1.25)
	local hcf = head.CFrame
	local top = hcf * CFrame.new(0, s * 0.5, 0)
	local parts = {}
	local function add(p, anchor) table.insert(parts, { p, anchor or head }) end
	local hc, bc = g.hatColor, g.bandColor
	if g.hat == "straw" then
		local base = top * CFrame.Angles(-0.1, 0, 0.04)
		add(gearPart(gear, "Brim", Vector3.new(0.08, s * 2.05, s * 2.05), hc, base * CFrame.new(0, -s * 0.12, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Crown", Vector3.new(s * 0.5, s * 1.08, s * 1.08), hc, base * CFrame.new(0, s * 0.12, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Top", Vector3.new(s * 0.9, s * 0.3, s * 0.9), hc, base * CFrame.new(0, s * 0.36, 0), Enum.Material.Fabric, SPH))
		add(gearPart(gear, "Band", Vector3.new(s * 0.16, s * 1.1, s * 1.1), bc, base * CFrame.new(0, -s * 0.02, 0) * UPRIGHT, nil, CYL))
	elseif g.hat == "cap" then
		add(gearPart(gear, "Crown", Vector3.new(s * 1.08, s * 0.66, s * 1.08), hc, top * CFrame.new(0, -s * 0.06, 0.02), Enum.Material.Fabric, SPH))
		add(gearPart(gear, "Brim", Vector3.new(s * 0.86, 0.06, s * 0.56), hc, top * CFrame.new(0, -s * 0.16, -s * 0.66) * CFrame.Angles(0.12, 0, 0), Enum.Material.Fabric))
		add(gearPart(gear, "Button", Vector3.new(0.12, 0.08, 0.12), hc:Lerp(Color3.new(0, 0, 0), 0.25), top * CFrame.new(0, s * 0.27, 0.02), nil, SPH))
	elseif g.hat == "beanie" then
		add(gearPart(gear, "Knit", Vector3.new(s * 1.12, s * 0.86, s * 1.12), hc, top * CFrame.new(0, -s * 0.02, 0.01), Enum.Material.Fabric, SPH))
		add(gearPart(gear, "Cuff", Vector3.new(s * 0.26, s * 1.1, s * 1.1), hc:Lerp(Color3.new(1, 1, 1), 0.18), top * CFrame.new(0, -s * 0.24, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Pom", Vector3.new(0.34, 0.34, 0.34), bc:Lerp(Color3.new(1, 1, 1), 0.5), top * CFrame.new(0, s * 0.43, 0), Enum.Material.Fabric, SPH))
	elseif g.hat == "bucket" then
		add(gearPart(gear, "Crown", Vector3.new(s * 0.46, s * 1.08, s * 1.08), hc, top * CFrame.new(0, s * 0.06, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Top", Vector3.new(s * 1.0, s * 0.22, s * 1.0), hc, top * CFrame.new(0, s * 0.28, 0), Enum.Material.Fabric, SPH))
		add(gearPart(gear, "Brim", Vector3.new(0.07, s * 1.55, s * 1.55), hc, top * CFrame.new(0, -s * 0.17, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
	elseif g.hat == "fedora" then
		local base = top * CFrame.Angles(-0.06, 0, -0.05)
		add(gearPart(gear, "Crown", Vector3.new(s * 0.56, s * 1.0, s * 0.96), hc, base * CFrame.new(0, s * 0.14, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Dent", Vector3.new(s * 0.9, s * 0.2, s * 0.86), hc, base * CFrame.new(0, s * 0.42, 0), Enum.Material.Fabric, SPH))
		add(gearPart(gear, "Brim", Vector3.new(0.07, s * 1.62, s * 1.62), hc, base * CFrame.new(0, -s * 0.12, 0) * UPRIGHT, Enum.Material.Fabric, CYL))
		add(gearPart(gear, "Band", Vector3.new(s * 0.13, s * 1.02, s * 0.98), Color3.fromRGB(30, 28, 30), base * CFrame.new(0, -s * 0.02, 0) * UPRIGHT, nil, CYL))
	end
	if g.glasses then
		local eye = hcf * CFrame.new(0, s * 0.08, -s * 0.5 - 0.03)
		local dark = Color3.fromRGB(26, 26, 30)
		for _, x in ipairs({ -0.22, 0.22 }) do
			local lens = gearPart(gear, "Lens", Vector3.new(s * 0.34, s * 0.22, 0.05), dark, eye * CFrame.new(x * s, 0, 0), Enum.Material.Glass)
			lens.Reflectance = 0.25
			add(lens)
		end
		add(gearPart(gear, "Bridge", Vector3.new(s * 0.14, 0.05, 0.05), dark, eye * CFrame.new(0, s * 0.06, 0)))
	end
	if g.bag then
		local w, h, d = torso.Size.X, torso.Size.Y, torso.Size.Z
		local tcf = torso.CFrame
		local col = g.bagColor
		local strap = col:Lerp(Color3.new(0, 0, 0), 0.35)
		if g.bag == "backpack" then
			local back = tcf * CFrame.new(0, -h * 0.02, d * 0.5 + 0.3)
			add(gearPart(gear, "Pack", Vector3.new(w * 0.62, h * 0.78, 0.58), col, back, Enum.Material.Fabric), torso)
			add(gearPart(gear, "Pocket", Vector3.new(w * 0.46, h * 0.3, 0.2), col:Lerp(Color3.new(0, 0, 0), 0.12), back * CFrame.new(0, -h * 0.18, 0.36), Enum.Material.Fabric), torso)
			add(gearPart(gear, "Flap", Vector3.new(w * 0.64, 0.16, 0.62), strap, back * CFrame.new(0, h * 0.37, 0.02), Enum.Material.Fabric), torso)
			for _, x in ipairs({ -0.27, 0.27 }) do
				add(gearPart(gear, "Strap", Vector3.new(0.16, h * 0.84, 0.05), strap, tcf * CFrame.new(x * w, h * 0.02, -d * 0.5 - 0.03), Enum.Material.Fabric), torso)
				add(gearPart(gear, "Strap", Vector3.new(0.16, 0.05, d + 0.1), strap, tcf * CFrame.new(x * w, h * 0.5 + 0.02, 0), Enum.Material.Fabric), torso)
			end
		else
			-- a crossbody bag: a diagonal strap from the right shoulder, the pouch on the left hip
			local len = math.sqrt(w * w * 0.5 + h * h) * 1.02
			local ang = math.atan2(w * 0.7, h)
			add(gearPart(gear, "Strap", Vector3.new(0.14, len, 0.05), strap, tcf * CFrame.new(0, 0, -d * 0.5 - 0.03) * CFrame.Angles(0, 0, -ang), Enum.Material.Fabric), torso)
			add(gearPart(gear, "Strap", Vector3.new(0.14, len, 0.05), strap, tcf * CFrame.new(0, 0, d * 0.5 + 0.03) * CFrame.Angles(0, 0, ang), Enum.Material.Fabric), torso)
			add(gearPart(gear, "Pouch", Vector3.new(0.78, 0.62, 0.3), col, tcf * CFrame.new(-w * 0.42, -h * 0.5 - 0.12, -d * 0.36), Enum.Material.Leather), torso)
			add(gearPart(gear, "Clasp", Vector3.new(0.14, 0.14, 0.05), Color3.fromRGB(212, 180, 110), tcf * CFrame.new(-w * 0.42, -h * 0.5 - 0.06, -d * 0.36 - 0.17), Enum.Material.Metal), torso)
		end
	end
	for _, pa in ipairs(parts) do
		local wc = Instance.new("WeldConstraint")
		wc.Part0, wc.Part1 = pa[2], pa[1]
		wc.Parent = pa[1]
	end
	gear.Parent = model
	return gear
end

function Bodies.make(name, walkSpeed, kind, override)
	local desc = override or Bodies.description(kind)
	local shape
	if not override then
		-- round 14: blocky classic proportions (no rthro), with real body types
		local SHAPES = {
			{id = "average", h = 1, w = 1, d = 1, hd = 1, w8 = 5},
			{id = "slim", h = 1.03, w = 0.8, d = 0.82, hd = 0.98, w8 = 3},
			{id = "tall", h = 1.12, w = 0.94, d = 0.95, hd = 1, w8 = 2, deep = true},
			{id = "short", h = 0.88, w = 1, d = 1, hd = 1.04, w8 = 2},
			{id = "broad", h = 1.05, w = 1.24, d = 1.12, hd = 1.02, w8 = 2, deep = true},
			{id = "round", h = 0.95, w = 1.32, d = 1.45, hd = 1.06, w8 = 3, deep = true},
			{id = "petite", h = 0.9, w = 0.84, d = 0.86, hd = 1, w8 = 2},
		}
		local tot = 0
		for _, s in ipairs(SHAPES) do tot += s.w8 end
		local pick = rng:NextNumber() * tot
		for _, s in ipairs(SHAPES) do pick -= s.w8; if pick <= 0 then shape = s break end end
		shape = shape or SHAPES[1]
		local j = function() return 1 + (rng:NextNumber() - 0.5) * 0.06 end
		pcall(function()
			desc.HeightScale = shape.h * j()
			desc.WidthScale = shape.w * j()
			desc.DepthScale = shape.d * j()
			desc.HeadScale = 1
			desc.BodyTypeScale = 0
			desc.ProportionScale = 0
		end)
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("Shared body builder: " .. tostring(model))
		ok, model = pcall(function()
			local d = Instance.new("HumanoidDescription")
			d.Shirt = Looks.SHIRTS[rng:NextInteger(1, #Looks.SHIRTS)]
			d.Pants = Looks.PANTS[rng:NextInteger(1, #Looks.PANTS)]
			d.HairAccessory = tostring(Looks.HAIR[rng:NextInteger(1, #Looks.HAIR)])
			return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
		end)
		if not ok then return nil end
	end
	model.Name = name or "NPC"
	-- kids are a whole small body with a slightly bigger head (a description can't go that small)
	local headK = (shape and shape.hd or 1) * (1 + (rng:NextNumber() - 0.5) * 0.06)
	if kind == "kid" and not override then
		pcall(function() model:ScaleTo(0.74) end)
		headK *= 0.74 * 1.14
	end
	if override then headK = 1 end
	pcall(classicFace, model, ok and desc.Face or 0, headK)
	if not override then
		local g = Looks.gear and Looks.gear(rng, kind)
		if g then
			pcall(Bodies.dress, model, g, headK)
			if g.hat then model:SetAttribute("Hat", g.hat) end
			if g.bag then model:SetAttribute("Bag", g.bag) end
		end
	end
	local anim = model:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	local style = Looks.walkStyle(rng, kind)
	model:SetAttribute("WalkStyle", style.id)
	model:SetAttribute("WalkAnim", "rbxassetid://" .. style.walk)
	model:SetAttribute("IdleAnim", "rbxassetid://" .. style.idle)
	model:SetAttribute("WalkSpeedMul", style.speed)
	if kind then model:SetAttribute("Kind", kind) end
	if shape then
		model:SetAttribute("BodyShape", shape.id)
		if shape.deep and rng:NextNumber() < 0.75 then model:SetAttribute("Deep", true) end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = (walkSpeed or C.WALK_SPEED) * style.speed
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	-- round 10d: states a walker never needs (each costs the humanoid's state machine every step)
	for _, st in ipairs({ "Swimming", "Flying", "StrafingNoPhysics", "PlatformStanding", "GettingUp", "Physics" }) do
		hum:SetStateEnabled(Enum.HumanoidStateType[st], false)
	end
	return model
end

return Bodies
