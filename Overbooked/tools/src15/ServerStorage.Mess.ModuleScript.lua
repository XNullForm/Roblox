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

-- round 38: count things for goals and achievements (QuestServer listens on Signals.Quest)
local function quest(plot, stat)
	local s = game:GetService("ServerStorage"):FindFirstChild("Signals")
	s = s and s:FindFirstChild("Quest")
	if s then s:Fire(plot, stat, 1) end
end

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
		if hit and hit.Normal.Y > 0.95 and math.abs(hit.Position.Y - (y0 - 1.5)) < 0.75 and --[[ round 38: was 2.5, which let sofas and armchairs count as floor ]] (hit.Position - seat.Position).Magnitude > 5 then
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
	place(folder, pos, kind, function() quest(plot, "spill") end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == plot.Name then
			Notify:FireClient(p, "toast", { text = SPILL_TEXT[kind] .. ". Clean it up for $" .. PAY, icon = "clean" })
		end
	end
end

-- round 36: lost property. A guest drops something in the lobby (WorldEvents calls Mess.lost now and then) and asks
-- around for it. Pick it up (player attribute LostItem), find the owner (a "Give back" prompt on them) for a reward.
local REWARD = 50
local LOST = {
	teddy = { "teddy bear", function(m, cf)
		local fur = Color3.fromRGB(150, 104, 64)
		local b = part(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), Color = fur, Material = Enum.Material.Fabric, CFrame = cf * CFrame.new(0, 0.45, 0) })
		part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), Color = fur, Material = Enum.Material.Fabric, CFrame = cf * CFrame.new(0, 1.1, 0) })
		for _, x in ipairs({ -0.28, 0.28 }) do
			part(m, { Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = fur, Material = Enum.Material.Fabric, CFrame = cf * CFrame.new(x, 1.42, 0) })
		end
		part(m, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), Color = Color3.fromRGB(40, 30, 24), CFrame = cf * CFrame.new(0, 1.05, -0.36) })
		return b
	end },
	wallet = { "wallet", function(m, cf)
		local w = part(m, { Name = "Wallet", Size = Vector3.new(1, 0.16, 0.75), Color = Color3.fromRGB(96, 58, 34), Material = Enum.Material.Leather, CFrame = cf * CFrame.new(0, 0.08, 0) })
		part(m, { Name = "Note", Size = Vector3.new(0.7, 0.04, 0.4), Color = Color3.fromRGB(150, 196, 140), CFrame = cf * CFrame.new(0.25, 0.18, 0.1) * CFrame.Angles(0, 0.4, 0) })
		return w
	end },
	phone = { "phone", function(m, cf)
		local p = part(m, { Name = "Phone", Size = Vector3.new(0.55, 0.07, 1.05), Color = Color3.fromRGB(30, 32, 38), CFrame = cf * CFrame.new(0, 0.04, 0) })
		part(m, { Name = "Screen", Size = Vector3.new(0.47, 0.02, 0.92), Color = Color3.fromRGB(90, 160, 240), Material = Enum.Material.Neon, CFrame = cf * CFrame.new(0, 0.085, 0) })
		return p
	end },
	sunglasses = { "sunglasses", function(m, cf)
		local black = Color3.fromRGB(24, 24, 28)
		local l = part(m, { Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.5, 0.5), Color = black, Reflectance = 0.3, CFrame = cf * CFrame.new(-0.32, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Name = "Lens2", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.5, 0.5), Color = black, Reflectance = 0.3, CFrame = cf * CFrame.new(0.32, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Name = "Bridge", Size = Vector3.new(0.2, 0.05, 0.06), Color = black, CFrame = cf * CFrame.new(0, 0.08, -0.05) })
		for _, x in ipairs({ -0.56, 0.56 }) do
			part(m, { Name = "Arm", Size = Vector3.new(0.05, 0.05, 0.9), Color = black, CFrame = cf * CFrame.new(x, 0.05, 0.42) })
		end
		return l
	end },
	hat = { "sun hat", function(m, cf)
		local straw = Color3.fromRGB(226, 196, 130)
		local b = part(m, { Name = "Brim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 2, 2), Color = straw, Material = Enum.Material.Fabric, CFrame = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Name = "Crown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.05, 1.05), Color = straw, Material = Enum.Material.Fabric, CFrame = cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		part(m, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16, 1.08, 1.08), Color = Color3.fromRGB(200, 70, 70), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)) })
		return b
	end },
}
local LOST_IDS = { "teddy", "wallet", "phone", "sunglasses", "hat" }
local ASK = { "Has anyone seen my %s?", "I've lost my %s! Oh no...", "My %s! Where did I put it?", "Excuse me, did anyone find a %s?" }
local THANKS = { "My %s! Thank you so much!", "You found it! You're a star.", "Oh, bless you. Here, take this.", "I'd have lost my head next. Thank you!" }

local function sayAs(m, line)
	m:SetAttribute("SayMode", nil)
	m:SetAttribute("SaySecs", 3.5)
	m:SetAttribute("Say", line)
	m:SetAttribute("SayN", (m:GetAttribute("SayN") or 0) + 1)
end

local function toastPlot(plot, t)
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Plot") == plot.Name then Notify:FireClient(p, "toast", t) end
	end
end

function Mess.lost(plot)
	if not plot or plot:GetAttribute("LostOwner") then return end
	local guests, seat = plot:FindFirstChild("Guests"), plot:FindFirstChild("DeskSeat", true)
	if not (guests and seat) then return end
	local pool = {}
	for _, g in ipairs(guests:GetChildren()) do
		local r = g:FindFirstChild("HumanoidRootPart")
		if r and g:GetAttribute("BName") and not g:GetAttribute("BRole") and (r.Position - seat.Position).Magnitude < 60 then table.insert(pool, g) end
	end
	local owner = pool[1] and pool[rng:NextInteger(1, #pool)]
	local pos = owner and spots(plot)[1]
	if not pos then return end
	local id = LOST_IDS[rng:NextInteger(1, #LOST_IDS)]
	local what, build = LOST[id][1], LOST[id][2]
	local name = owner:GetAttribute("BName"):match("^%S+") or "A guest"
	plot:SetAttribute("LostOwner", owner.Name)
	local m = Instance.new("Model")
	m.Name = "Lost_" .. id
	m.Parent = plot
	local base = build(m, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
	m.PrimaryPart = base
	local holder -- the player carrying it
	local finished = false
	local give
	local function finish()
		if finished then return end
		finished = true
		if m.Parent then m:Destroy() end
		if give then give:Destroy() end
		if holder and holder:GetAttribute("LostItem") == what then holder:SetAttribute("LostItem", nil) end
		if plot.Parent then plot:SetAttribute("LostOwner", nil) end
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Pick up"
	pr.ObjectText = name .. "'s " .. what
	pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = base
	pr.Triggered:Connect(function(player)
		if finished or holder or player:GetAttribute("LostItem") then return end
		if not owner.Parent then finish() return end
		holder = player
		player:SetAttribute("LostItem", what)
		m:Destroy()
		Notify:FireClient(player, "toast", { text = "You found " .. name .. "'s " .. what .. ". Find " .. name .. " and give it back!", icon = "guest" })
		local r = owner:FindFirstChild("HumanoidRootPart")
		if not r then finish() return end
		give = Instance.new("ProximityPrompt")
		give.Name = "GiveBack"
		give.ActionText = "Give back"
		give.ObjectText = what:gsub("^%l", string.upper)
		give.HoldDuration = 0.3
		give.MaxActivationDistance = 10
		give.RequiresLineOfSight = false
		give.UIOffset = Vector2.new(0, 60) -- clear of the talk prompt
		give.Parent = r
		give.Triggered:Connect(function(p)
			if finished or p ~= holder then return end
			sayAs(owner, THANKS[rng:NextInteger(1, #THANKS)]:format(what))
			p:SetAttribute("Cash", (p:GetAttribute("Cash") or 0) + REWARD)
			p:SetAttribute("Earned", (p:GetAttribute("Earned") or 0) + REWARD)
			Notify:FireClient(p, "toast", { text = name .. " got their " .. what .. " back. +$" .. REWARD .. " reward", icon = "cash", kind = "good" })
			quest(plot, "lost")
			finish()
		end)
	end)
	toastPlot(plot, { text = name .. " lost a " .. what .. " in the lobby. Find it!", icon = "guest" })
	-- the owner asks around until it's back; the lost thing lies about 4 minutes, then the cleaners take it
	task.spawn(function()
		local t0 = os.clock()
		while not finished and os.clock() - t0 < 240 do
			if not owner.Parent then
				if holder then Notify:FireClient(holder, "toast", { text = name .. " already left. The " .. what .. " goes to lost property.", icon = "guest" }) end
				break
			end
			local hr, orr = holder and holder.Character and holder.Character:FindFirstChild("HumanoidRootPart"), owner:FindFirstChild("HumanoidRootPart")
			local close = hr and orr and (hr.Position - orr.Position).Magnitude < 16
			sayAs(owner, (close and "Is that my %s?!" or ASK[rng:NextInteger(1, #ASK)]):format(what))
			task.wait(close and 5 or rng:NextNumber(12, 18))
		end
		finish()
	end)
	return m
end

---------------------------------------------------------------- round 38: tips and critters

local function sound(parent, id, vol, speed)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 90
	s.Parent = parent
	s:Play()
	game:GetService("Debris"):AddItem(s, 5)
end

local function onPlot(plot, p) return p:GetAttribute("Plot") == plot.Name end

local function pay(p, amount)
	p:SetAttribute("Cash", (p:GetAttribute("Cash") or 0) + amount)
	p:SetAttribute("Earned", (p:GetAttribute("Earned") or 0) + amount)
end

-- a happy guest leaves a tip on the floor where they paid (HotelSim calls this). Walk over it to grab it.
local MAX_TIPS = 5
function Mess.tip(plot, pos, amount)
	if not plot or not pos then return end
	local folder = plot:FindFirstChild("Tips")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Tips"
		folder.Parent = plot
	end
	if #folder:GetChildren() >= MAX_TIPS then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	local off = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	local hit = workspace:Raycast(pos + off + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	if not hit then return end
	local at = hit.Position
	local m = Instance.new("Model")
	m.Name = "Tip"
	local gold = Color3.fromRGB(246, 196, 64)
	local base
	for i = 0, 2 do
		local c = part(m, { Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.75, 0.75), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.15,
			CFrame = CFrame.new(at + Vector3.new(i * 0.12 - 0.12, 0.08 + i * 0.15, i * 0.08)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(90)) })
		base = base or c
	end
	local note = part(m, { Name = "Note", Size = Vector3.new(1, 0.04, 0.5), Color = Color3.fromRGB(150, 200, 140), CFrame = CFrame.new(at + Vector3.new(0.5, 0.03, -0.3)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) })
	local grab = part(m, { Name = "Grab", Size = Vector3.new(3.2, 4, 3.2), Transparency = 1, CanQuery = false, CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) })
	grab.CanTouch = true
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = gold, 6, 1.2
	glow.Parent = base
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.6, 1)
	sp.Speed = NumberRange.new(0.6, 1.4)
	sp.SpreadAngle = Vector2.new(60, 60)
	sp.Rate = 5
	sp.LightEmission = 0.8
	sp.Parent = note
	m.PrimaryPart = base
	m.Parent = folder
	local taken = false
	grab.Touched:Connect(function(h)
		local p = Players:GetPlayerFromCharacter(h.Parent)
		if taken or not p or not onPlot(plot, p) then return end
		taken = true
		pay(p, amount)
		sound(base, "rbxassetid://9113704038", 0.6, 1.1) -- coins
		Notify:FireClient(p, "paid", { amount = amount, pos = at + Vector3.new(0, 3, 0) })
		quest(plot, "tip")
		for _, x in ipairs(m:GetChildren()) do if x:IsA("BasePart") then x.Transparency = 1 end end
		sp.Enabled, glow.Enabled = false, false
		task.delay(1, function() m:Destroy() end)
	end)
	game:GetService("Debris"):AddItem(m, 120)
	return m
end

-- critters: built at the origin facing -Z, then moved as one each frame (offsets from the root part).
-- One at a time per hotel (plot attribute Critter). They roam between floor spots in the lobby, picking a target
-- with a clear line to it, and run from a player who gets close.
local CRITTER_PAY = 40
local DOG_NAMES = { "Biscuit", "Pepper", "Noodle", "Waffles", "Bean", "Scout", "Mochi", "Pickles", "Tofu", "Ziggy" }
local BARK, SQUAWK = "rbxassetid://9113955372", "rbxassetid://9118858259"

-- offsets from a point `lift` under the root (the floor under the critter when it was built at the origin)
local function rig(m, root, lift)
	local parts, offs = {}, {}
	local base = root.CFrame * CFrame.new(0, -(lift or 0), 0)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(parts, p)
			offs[p] = base:ToObjectSpace(p.CFrame)
		end
	end
	return parts, offs
end

local function clearLine(plot, a, b, height)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plot }
	local from, to = a + Vector3.new(0, height, 0), b + Vector3.new(0, height, 0)
	local hit = workspace:Raycast(from, to - from, params)
	return not hit or not hit.Instance.CanCollide
end

local function nearestRoot(plot, pos)
	local best, bd
	for _, p in ipairs(Players:GetPlayers()) do
		local r = onPlot(plot, p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local d = (r.Position - pos).Magnitude
			if not bd or d < bd then best, bd = r, d end
		end
	end
	return best, bd or math.huge
end

-- moves the critter until stop() says so. o: speed, fleeSpeed, fleeDist, hop, fly (height while moving),
-- pose(parts table, cf, t) for extra motion. Returns a handle with :flee() and :stop().
local function roam(plot, m, root, list, o)
	local parts, offs = rig(m, root, 0.95) -- both critters' bodies were built 0.95 up
	local pos = list[1]
	local target, speed = pos, o.speed
	local dir = Vector3.new(0, 0, -1)
	local alive = true
	local h = {}
	local function pick(away)
		local best, score
		for _ = 1, 8 do
			local c = list[rng:NextInteger(1, #list)]
			if (c - pos).Magnitude > 4 and clearLine(plot, pos, c, 1) then
				local s = away and (c - away).Magnitude or rng:NextNumber()
				if not score or s > score then best, score = c, s end
			end
		end
		return best
	end
	function h.flee(from)
		local t = pick(from)
		if t then target, speed = t, o.fleeSpeed end
	end
	function h.stop() alive = false end
	h.pos = function() return pos end
	local t0 = os.clock()
	local conn
	conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not alive or not m.Parent then conn:Disconnect() return end
		local t = os.clock() - t0
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local moving = flat.Magnitude > 0.3
		if moving then
			dir = flat.Unit
			pos += dir * math.min(flat.Magnitude, speed * dt)
			pos = Vector3.new(pos.X, pos.Y + (target.Y - pos.Y) * math.min(1, dt * 6), pos.Z) -- rugs and carpet edges
		elseif rng:NextNumber() < dt * 0.6 then
			local nt = pick()
			if nt then target, speed = nt, o.speed end
		end
		local r, d = nearestRoot(plot, pos)
		if r and d < o.fleeDist and speed ~= o.fleeSpeed then h.flee(r.Position) end
		if not moving and speed == o.fleeSpeed then speed = o.speed end
		local y = moving and (o.fly or 0) + o.hop * math.abs(math.sin(t * 11)) or 0
		local cf = CFrame.lookAt(pos, pos + dir) + Vector3.new(0, y, 0)
		local cfs = table.create(#parts)
		for i, p in ipairs(parts) do cfs[i] = cf * offs[p] end
		if o.pose then o.pose(parts, cfs, cf, t, moving) end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	return h
end

local function critterStart(plot)
	if not plot or plot:GetAttribute("Critter") then return nil end
	local list = spots(plot)
	if #list < 3 then return nil end
	return list
end

local function buildDog(m)
	local coat = ({ Color3.fromRGB(196, 150, 96), Color3.fromRGB(240, 236, 226), Color3.fromRGB(60, 50, 44), Color3.fromRGB(150, 96, 60), Color3.fromRGB(226, 190, 120) })[rng:NextInteger(1, 5)]
	local dark, light = coat:Lerp(Color3.new(0, 0, 0), 0.35), coat:Lerp(Color3.new(1, 1, 1), 0.35)
	local F = Enum.Material.Fabric
	local body = part(m, { Name = "Body", Size = Vector3.new(0.9, 0.8, 1.6), Color = coat, Material = F, CFrame = CFrame.new(0, 0.95, 0) })
	part(m, { Name = "Head", Size = Vector3.new(0.8, 0.75, 0.75), Color = coat, Material = F, CFrame = CFrame.new(0, 1.5, -0.95) })
	part(m, { Name = "Snout", Size = Vector3.new(0.45, 0.35, 0.42), Color = light, Material = F, CFrame = CFrame.new(0, 1.34, -1.45) })
	part(m, { Name = "Nose", Size = Vector3.new(0.18, 0.14, 0.1), Color = Color3.fromRGB(26, 22, 22), CFrame = CFrame.new(0, 1.46, -1.67) })
	for _, x in ipairs({ -1, 1 }) do
		part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.13, 0.13, 0.13), Color = Color3.fromRGB(20, 20, 24), CFrame = CFrame.new(x * 0.2, 1.62, -1.33) })
		part(m, { Name = "Ear", Size = Vector3.new(0.18, 0.45, 0.16), Color = dark, Material = F, CFrame = CFrame.new(x * 0.36, 1.66, -0.9) * CFrame.Angles(0, 0, x * math.rad(-12)) })
		for _, z in ipairs({ -0.55, 0.55 }) do
			part(m, { Name = "Leg", Size = Vector3.new(0.24, 0.6, 0.24), Color = coat, Material = F, CFrame = CFrame.new(x * 0.28, 0.3, z) })
		end
	end
	part(m, { Name = "Collar", Size = Vector3.new(0.86, 0.16, 0.8), Color = Color3.fromRGB(210, 50, 60), CFrame = CFrame.new(0, 1.22, -0.72) })
	part(m, { Name = "Tail", Size = Vector3.new(0.14, 0.14, 0.7), Color = coat, Material = F, CFrame = CFrame.new(0, 1.35, 0.95) * CFrame.Angles(math.rad(40), 0, 0) })
	return body
end

-- a dog got off its lead and is having the time of its life. Catch it (walk up and press the prompt).
function Mess.dog(plot)
	local list = critterStart(plot)
	if not list then return end
	local name = DOG_NAMES[rng:NextInteger(1, #DOG_NAMES)]
	plot:SetAttribute("Critter", "dog")
	local m = Instance.new("Model")
	m.Name = "Critter_Dog"
	local body = buildDog(m)
	m.PrimaryPart = body
	m:PivotTo(CFrame.new(list[1]))
	m.Parent = plot
	local legs, tail = {}, nil
	for _, p in ipairs(m:GetChildren()) do
		if p.Name == "Leg" then table.insert(legs, p) elseif p.Name == "Tail" then tail = p end
	end
	local h = roam(plot, m, body, list, { speed = 8, fleeSpeed = 11, fleeDist = 11, hop = 0.35,
		pose = function(parts, cfs, cf, t, moving)
			for i, p in ipairs(parts) do
				if p == tail then
					cfs[i] = cfs[i] * CFrame.Angles(0, math.sin(t * 22) * 0.6, 0)
				elseif moving and p.Name == "Leg" then
					local k = table.find(legs, p) or 1
					cfs[i] = cfs[i] * CFrame.new(0, 0.3, 0) * CFrame.Angles(math.sin(t * 16 + (k % 2) * math.pi) * 0.7, 0, 0) * CFrame.new(0, -0.3, 0)
				end
			end
		end })
	local done = false
	local function finish()
		if done then return end
		done = true
		h.stop()
		if plot.Parent then plot:SetAttribute("Critter", nil) end
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Catch"
	pr.ObjectText = name
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr.Parent = body
	pr.Triggered:Connect(function(p)
		if done or not onPlot(plot, p) then return end
		finish()
		pay(p, CRITTER_PAY)
		quest(plot, "critter")
		sound(body, BARK, 0.7, 1.6)
		Notify:FireClient(p, "paid", { amount = CRITTER_PAY, pos = body.Position + Vector3.new(0, 3, 0) })
		toastPlot(plot, { text = p.DisplayName .. " caught " .. name .. "! Their owner says thanks. +$" .. CRITTER_PAY, icon = "ev_pet", kind = "good" })
		puff(body.Position)
		m:Destroy()
	end)
	toastPlot(plot, { text = "A dog called " .. name .. " is loose in the lobby! Catch it!", icon = "ev_pet" })
	task.spawn(function()
		local t0 = os.clock()
		while not done and m.Parent and os.clock() - t0 < 150 do
			sound(body, BARK, 0.55, rng:NextNumber(1.5, 1.75))
			task.wait(rng:NextNumber(3, 7))
		end
		if not done then
			finish()
			if m.Parent then puff(body.Position) m:Destroy() end
			toastPlot(plot, { text = name .. " ran back to their owner.", icon = "ev_pet" })
		end
	end)
	return m
end

local function buildGull(m)
	local white, grey, orange = Color3.fromRGB(246, 246, 248), Color3.fromRGB(150, 158, 170), Color3.fromRGB(240, 160, 40)
	local body = part(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.75, 1.3), Color = white, CFrame = CFrame.new(0, 0.95, 0) })
	part(m, { Name = "Back", Size = Vector3.new(0.7, 0.2, 1), Color = grey, CFrame = CFrame.new(0, 1.25, 0.1) })
	part(m, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Color = white, CFrame = CFrame.new(0, 1.45, -0.6) })
	part(m, { Name = "Beak", Size = Vector3.new(0.14, 0.14, 0.45), Color = orange, CFrame = CFrame.new(0, 1.4, -1.02) })
	for _, x in ipairs({ -1, 1 }) do
		part(m, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.1, 0.1, 0.1), Color = Color3.fromRGB(20, 20, 24), CFrame = CFrame.new(x * 0.2, 1.55, -0.75) })
		part(m, { Name = x < 0 and "WingL" or "WingR", Size = Vector3.new(1.1, 0.08, 0.6), Color = grey, CFrame = CFrame.new(x * 0.9, 1.2, 0.1) })
		part(m, { Name = "Leg", Size = Vector3.new(0.08, 0.6, 0.08), Color = orange, CFrame = CFrame.new(x * 0.15, 0.3, 0.05) })
	end
	part(m, { Name = "Tail", Size = Vector3.new(0.5, 0.08, 0.4), Color = Color3.fromRGB(40, 40, 46), CFrame = CFrame.new(0, 1.05, 0.75) })
	return body
end

-- a seagull flew in through the front door and wants chips. Shoo it three times and it flies off.
local SHOOS = 3
function Mess.gull(plot)
	local list = critterStart(plot)
	if not list then return end
	plot:SetAttribute("Critter", "gull")
	local m = Instance.new("Model")
	m.Name = "Critter_Gull"
	local body = buildGull(m)
	m.PrimaryPart = body
	m:PivotTo(CFrame.new(list[1]))
	m.Parent = plot
	local flapping = 0
	local h = roam(plot, m, body, list, { speed = 5, fleeSpeed = 18, fleeDist = 0, hop = 0.15,
		pose = function(parts, cfs, cf, t, moving)
			local fly = moving and os.clock() < flapping
			for i, p in ipairs(parts) do
				if fly then cfs[i] = cfs[i] + Vector3.new(0, 2.5 * math.min(1, (flapping - os.clock())), 0) end
				if p.Name == "WingL" or p.Name == "WingR" then
					local s = p.Name == "WingL" and 1 or -1
					local a = fly and math.sin(t * 24) * 0.9 or 0.15
					cfs[i] = cf * CFrame.new(-s * 0.4, 1.2, 0.1) * CFrame.Angles(0, 0, s * a) * CFrame.new(-s * 0.5, 0, 0) + (fly and Vector3.new(0, 2.5 * math.min(1, flapping - os.clock()), 0) or Vector3.zero)
				end
			end
		end })
	local shoos, done = 0, false
	local function finish()
		if done then return end
		done = true
		h.stop()
		if plot.Parent then plot:SetAttribute("Critter", nil) end
	end
	-- flies up and away, then gone
	local function leave()
		local start = body.CFrame
		local away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
		local parts, offs = rig(m, body)
		local t0 = os.clock()
		local conn
		conn = game:GetService("RunService").Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > 2.5 or not m.Parent then conn:Disconnect() m:Destroy() return end
			local cf = CFrame.lookAt(start.Position, start.Position + away) + away * t * 14 + Vector3.new(0, t * 9, 0)
			local cfs = {}
			for i, p in ipairs(parts) do
				cfs[i] = cf * offs[p]
				if p.Name == "WingL" or p.Name == "WingR" then
					local s = p.Name == "WingL" and 1 or -1
					cfs[i] = cf * CFrame.new(-s * 0.4, 0.25, 0.1) * CFrame.Angles(0, 0, s * math.sin(t * 26) * 1) * CFrame.new(-s * 0.5, 0, 0)
				end
				p.Transparency = math.max(p.Transparency, math.clamp((t - 1.5), 0, 1))
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Shoo!"
	pr.ObjectText = "Seagull"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = body
	pr.Triggered:Connect(function(p)
		if done or not onPlot(plot, p) then return end
		shoos += 1
		sound(body, SQUAWK, 0.6, rng:NextNumber(0.95, 1.1))
		if shoos >= SHOOS then
			finish()
			pay(p, CRITTER_PAY)
			quest(plot, "critter")
			Notify:FireClient(p, "paid", { amount = CRITTER_PAY, pos = body.Position + Vector3.new(0, 3, 0) })
			toastPlot(plot, { text = "The seagull is gone. The guests clap! +$" .. CRITTER_PAY, icon = "happy", kind = "good" })
			leave()
		else
			pr.ObjectText = "Seagull (" .. (SHOOS - shoos) .. " more)"
			flapping = os.clock() + 1.6
			h.flee(p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart.Position or body.Position)
		end
	end)
	toastPlot(plot, { text = "A seagull flew into the lobby! Shoo it out!", icon = "happy" })
	task.spawn(function()
		local t0 = os.clock()
		while not done and m.Parent and os.clock() - t0 < 150 do
			if rng:NextNumber() < 0.5 then sound(body, SQUAWK, 0.45, rng:NextNumber(0.95, 1.1)) end
			task.wait(rng:NextNumber(5, 10))
		end
		if not done then
			finish()
			if m.Parent then leave() end
			toastPlot(plot, { text = "The seagull flew off with someone's sandwich.", icon = "happy" })
		end
	end)
	return m
end

return Mess
