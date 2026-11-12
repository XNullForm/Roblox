-- ServerStorage.RAH_Bodies: the shared NPC body builder (guests, staff, street crowds).
-- Round 9: looks and walk styles come from RAH.Looks. Every body carries attributes WalkAnim, IdleAnim,
-- WalkStyle and WalkSpeedMul, so the crowd and the hotel sims animate it the same way.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))
local Looks = require(RS.RAH:WaitForChild("Looks"))

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
local function classicFace(model, faceId)
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
	mesh.Scale = Vector3.new(1.2, 1.2, 1.2) * (head.Size.Y / 1.19)
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

function Bodies.make(name, walkSpeed, kind, override)
	local desc = override or Bodies.description(kind)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("RAH body builder: " .. tostring(model))
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
	pcall(classicFace, model, ok and desc.Face or 0)
	local anim = model:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	local style = Looks.walkStyle(rng, kind)
	model:SetAttribute("WalkStyle", style.id)
	model:SetAttribute("WalkAnim", "rbxassetid://" .. style.walk)
	model:SetAttribute("IdleAnim", "rbxassetid://" .. style.idle)
	model:SetAttribute("WalkSpeedMul", style.speed)
	if kind then model:SetAttribute("Kind", kind) end
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
