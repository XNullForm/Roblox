-- ServerStorage.RAH_Bodies: the shared NPC body builder (guests, staff, street crowds).
-- Builds a random R15 rig from the Config wardrobe; every NPC in the game gets its look here
-- so hotel guests and street pedestrians always match.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local C = require(RS:WaitForChild("RAH"):WaitForChild("Config"))

local Bodies = {}
local rng = Random.new()
local function pick(t) return t[rng:NextInteger(1, #t)] end

function Bodies.description()
	local d = Instance.new("HumanoidDescription")
	d.Shirt = pick(C.SHIRTS)
	d.Pants = pick(C.PANTS)
	local hair = pick(C.HAIR)
	d.HairAccessory = tostring(hair)
	if rng:NextNumber() < 0.3 then d.HatAccessory = tostring(pick(C.HATS)) end
	local face = pick(C.FACES)
	if face > 0 then d.Face = face end
	local skin = pick(C.SKIN)
	d.HeadColor, d.TorsoColor = skin, skin
	d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = skin, skin, skin, skin
	d.HeightScale = rng:NextNumber(0.92, 1.06)
	d.WidthScale = rng:NextNumber(0.9, 1.05)
	d.DepthScale = d.WidthScale
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	return d
end

-- builds an R15 rig; falls back to a plain rig if the catalog is slow
function Bodies.make(name, walkSpeed)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Bodies.description(), Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("RAH body builder: " .. tostring(model))
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		if not ok then return nil end
	end
	model.Name = name or "NPC"
	local anim = model:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.WalkSpeed = walkSpeed or C.WALK_SPEED
	hum.BreakJointsOnDeath = false
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	return model
end

return Bodies