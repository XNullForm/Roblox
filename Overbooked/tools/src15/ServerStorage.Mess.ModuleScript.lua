-- ServerStorage.Mess (round 35): the story start. A brand-new hotel was Aunt Marigold's, and she left it in a state:
-- Mess.spawn(plot) drops rubbish around the lobby (bags, dust, papers, planks, puddles), each with a "Clean up"
-- prompt (tag "Mess"). Cleaning one pays a little and puffs away; the plot attribute MessLeft counts down and at 0 the
-- hotel gets CleanedUp and everyone in it a toast. TutorialClient's "Clean up the mess" step follows MessLeft.
-- Spots: random points within RADIUS of the desk seat whose downward ray lands on a flat floor at the desk's level.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Notify = RS.Shared.Remotes:WaitForChild("Notify")

local Mess = {}
local COUNT, RADIUS, PAY = 10, 22, 15
local rng = Random.new()

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, true, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = model
	return p
end

-- each kind builds its look at `cf` (on the floor) and returns the part the prompt sits on
local KINDS = {
	bag = function(m, cf)
		local b = part(m, { Name = "Bag", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Color = Color3.fromRGB(38, 42, 48), CFrame = cf * CFrame.new(0, 0.75, 0) })
		part(m, { Name = "Tie", Size = Vector3.new(0.35, 0.5, 0.35), Color = Color3.fromRGB(60, 64, 70), CFrame = cf * CFrame.new(0, 1.75, 0) })
		part(m, { Name = "Bag2", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = Color3.fromRGB(46, 50, 56), CFrame = cf * CFrame.new(1.1, 0.55, 0.4) })
		return b
	end,
	dust = function(m, cf)
		local d = part(m, { Name = "Dust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 2.8, 2.8), Color = Color3.fromRGB(150, 136, 118), Material = Enum.Material.Sand, CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Name = "Dust2", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.6, 1.6), Color = Color3.fromRGB(130, 118, 102), Material = Enum.Material.Sand, CFrame = cf * CFrame.new(0.4, 0.3, -0.2) * CFrame.Angles(0, 0, math.rad(90)) })
		return d
	end,
	papers = function(m, cf)
		local first
		for i = 1, 5 do
			local p = part(m, { Name = "Paper", Size = Vector3.new(0.9, 0.05, 1.2), Color = Color3.fromRGB(240, 236, 226),
				CFrame = cf * CFrame.new(rng:NextNumber(-1, 1), 0.05 + i * 0.02, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) })
			first = first or p
		end
		part(m, { Name = "Ball", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = Color3.fromRGB(232, 228, 216), CFrame = cf * CFrame.new(0.6, 0.3, 0.7) })
		return first
	end,
	planks = function(m, cf)
		local wood = Color3.fromRGB(124, 88, 56)
		local a = part(m, { Name = "Plank", Size = Vector3.new(4, 0.25, 0.7), Color = wood, Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0.3, 0) })
		part(m, { Name = "Plank2", Size = Vector3.new(3.2, 0.25, 0.7), Color = wood:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Wood, CFrame = cf * CFrame.new(0.2, 0.4, 0.3) * CFrame.Angles(0, -0.5, 0.12) })
		return a
	end,
	puddle = function(m, cf)
		return part(m, { Name = "Puddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 3.2, 2.4), Color = Color3.fromRGB(120, 150, 170), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.2, CFrame = cf * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	end,
}
local ORDER = { "bag", "dust", "papers", "planks", "puddle", "dust", "bag", "papers", "dust", "planks" }
local ACTION = { bag = "Pick up", dust = "Sweep", papers = "Pick up", planks = "Clear", puddle = "Mop" }
local NAME = { bag = "Rubbish", dust = "Dust", papers = "Old papers", planks = "Old planks", puddle = "Puddle" }

local function puff(at)
	local a = Instance.new("Attachment")
	a.WorldPosition = at
	a.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(235, 230, 220))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	e:Emit(16)
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://9113592940" -- the broom (Audio "broom")
	s.Volume = 0.6
	s.Parent = a
	s:Play()
	task.delay(2, function() a:Destroy() end)
end

local function spots(plot)
	local seat = plot:FindFirstChild("DeskSeat", true)
	if not seat then return {} end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	local y0 = seat.Position.Y
	local out = {}
	for _ = 1, 200 do
		if #out >= COUNT then break end
		local p = seat.Position + Vector3.new(rng:NextNumber(-RADIUS, RADIUS), 6, rng:NextNumber(-RADIUS, RADIUS))
		local hit = workspace:Raycast(p, Vector3.new(0, -12, 0), params)
		if hit and hit.Normal.Y > 0.95 and math.abs(hit.Position.Y - (y0 - 1.5)) < 2.5 and (hit.Position - seat.Position).Magnitude > 5 then
			local ok = true
			for _, q in ipairs(out) do if (q - hit.Position).Magnitude < 5 then ok = false break end end
			-- indoors only: something of the hotel overhead (the lobby ceiling)
			if ok and not workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, 40, 0), params) then ok = false end
			-- room to stand: nothing solid at chest height around it
			if ok and #workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 2.5, 0)), Vector3.new(3, 3, 3)) > 0 then
				for _, b in ipairs(workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 2.5, 0)), Vector3.new(3, 3, 3))) do
					if b.CanCollide and b.Transparency < 1 then ok = false break end
				end
			end
			if ok then table.insert(out, hit.Position) end
		end
	end
	return out
end

local function done(plot)
	plot:SetAttribute("CleanedUp", true)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == plot.Name then
			Notify:FireClient(p, "toast", { text = "Spotless! The Seabreeze is ready for guests.", icon = "clean", kind = "good" })
		end
	end
end

-- one piece of mess at `pos`; onClean(player) runs when someone cleans it
local function place(folder, pos, kind, onClean)
	local m = Instance.new("Model")
	m.Name = "Mess_" .. kind
	m.Parent = folder
	local base = KINDS[kind](m, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
	m.PrimaryPart = base
	CollectionService:AddTag(m, "Mess")
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = ACTION[kind]
	pr.ObjectText = NAME[kind]
	pr.HoldDuration = 0.7
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = base
	pr.Triggered:Connect(function(player)
		if not m.Parent then return end
		local at = base.Position
		m:Destroy()
		puff(at)
		player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + PAY)
		player:SetAttribute("Earned", (player:GetAttribute("Earned") or 0) + PAY)
		onClean(player)
	end)
	return m
end

function Mess.spawn(plot)
	if not plot or plot:GetAttribute("CleanedUp") or plot:FindFirstChild("Mess") then return end
	local folder = Instance.new("Folder")
	folder.Name = "Mess"
	folder.Parent = plot
	local list = spots(plot)
	plot:SetAttribute("MessLeft", #list)
	if #list == 0 then done(plot) return end
	for i, pos in ipairs(list) do
		place(folder, pos, ORDER[(i - 1) % #ORDER + 1], function()
			local left = math.max(0, (plot:GetAttribute("MessLeft") or 1) - 1)
			plot:SetAttribute("MessLeft", left)
			if left == 0 then done(plot) end
		end)
	end
end

-- round 35: day-to-day spills (WorldEvents calls this now and then): a dropped drink, litter, a muddy patch.
-- At most MAX_SPILLS lying about per hotel; the owner gets a toast pointing at it.
local SPILL_KINDS = { "puddle", "papers", "dust", "puddle", "bag" }
local SPILL_TEXT = { puddle = "Someone spilled a drink in the lobby", papers = "Litter in the lobby", dust = "Muddy footprints in the lobby", bag = "Someone left rubbish in the lobby" }
local MAX_SPILLS = 3
function Mess.spill(plot)
	if not plot or not plot:GetAttribute("CleanedUp") and plot:FindFirstChild("Mess") then return end
	local folder = plot:FindFirstChild("Spills")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Spills"
		folder.Parent = plot
	end
	if #folder:GetChildren() >= MAX_SPILLS then return end
	local list = spots(plot)
	local pos = list[1]
	if not pos then return end
	for _, c in ipairs(folder:GetChildren()) do if c.PrimaryPart and (c.PrimaryPart.Position - pos).Magnitude < 5 then return end end
	local kind = SPILL_KINDS[rng:NextInteger(1, #SPILL_KINDS)]
	place(folder, pos, kind, function() end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == plot.Name then
			Notify:FireClient(p, "toast", { text = SPILL_TEXT[kind] .. ". Clean it up for $" .. PAY, icon = "clean" })
		end
	end
end

return Mess
