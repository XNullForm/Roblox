local s = game.ServerStorage.GuestEvents
local DT = game.ServerStorage.DevTools
if not DT:FindFirstChild("GuestEvents_Backup_20261110") then local b = s:Clone(); b.Name = "GuestEvents_Backup_20261110"; b.Parent = DT end
local src = s.Source
local function rep(a, b, all)
	local i, j = src:find(a, 1, true)
	assert(i, "miss: " .. a:sub(1, 60))
	if all then
		src = src:gsub(a:gsub("%p", "%%%0"), (b:gsub("%%", "%%%%")))
		return
	end
	assert(not src:find(a, j + 1, true), "dup: " .. a:sub(1, 60))
	src = src:sub(1, i - 1) .. b .. src:sub(j + 1)
end

rep("for id, d in pairs(E.DEFS) do d.id = id end", [==[-- round 15: star guests. Named people, one at a time, from the Town Hotel grade or level 6. A cutscene plays as
-- they walk up (client Cutscene), they take the best room, and they pay well (plus a gift) when it's good enough.
E.STAR_CHANCE = 0.07
E.STAR_GAP = 300
E.DEFS.rockstar = {
	star = true, who = "Jett Vega", title = "Rock star on a world tour", icon = "ev_party", label = "Star guest: rock star",
	minStars = 3, pay = 3.5, miss = 1.2, gift = 800,
	arrive = "the rock star, just pulled up!", act = "Shredding a guitar solo", actIcon = "ev_party", secs = { 7, 9 },
	lines = { "Is this where the after-party is?", "Keep it down? Never heard of it.", "One night, one show, one hotel." },
	happy = { "Rock on! Best stop on the tour.", "I'm writing a song about this place." },
	sad = { "This room is not rock and roll.", "My roadies had better rooms." },
}
E.DEFS.royal = {
	star = true, who = "Duchess Wilhelmina", title = "Royalty, travelling quietly", icon = "ev_vip", label = "Star guest: royalty",
	minStars = 4, pay = 5, miss = 1, gift = 1500,
	arrive = "the Duchess, has arrived!", act = "Taking afternoon tea", actIcon = "ev_vip", secs = { 6, 8 },
	lines = { "One would like your finest room.", "Do curtsy, darling. Only joking.", "The palace is being repainted." },
	happy = { "Simply splendid. One is delighted.", "Fit for a queen. Well, a duchess." },
	sad = { "One has slept in better stables.", "How very... ordinary." },
}
E.DEFS.critic = {
	star = true, who = "Margaux Fontaine", title = "The city's toughest critic", icon = "ev_inspector", label = "Star guest: critic",
	minStars = 3, pay = 3, miss = 0.8, gift = 600,
	arrive = "the famous critic, is here. Impress her!", act = "Taking notes", actIcon = "ev_inspector", secs = { 6, 8 },
	lines = { "I'll be writing about this.", "Hmm. Interesting choice of carpet.", "Don't mind me. Just observing." },
	happy = { "Five stars. Write that down.", "I was ready to hate it. I don't." },
	sad = { "This will make a short review.", "Disappointing. Truly." },
}
E.DEFS.mystery = {
	star = true, who = "Mystery Guest", title = "Who is that in the trench coat?", icon = "ev_inspector", label = "Star guest: mystery guest",
	pay = 2.5, miss = 1, gift = 1200,
	arrive = "slipped in. Nobody knows who they are...", act = "Peeking around", actIcon = "ev_inspector", secs = { 5, 7 },
	lines = { "I'm nobody. Just a regular guest.", "You didn't see me.", "Nice place. Very... normal." },
	happy = { "I'm the secret reviewer. You passed!", "Surprise! Hotel Weekly. Top marks." },
	sad = { "I'm the secret reviewer. Not great.", "Hotel Weekly will hear about this." },
}
E.DEFS.tycoon = {
	star = true, who = "Sir Reginald Goldworth", title = "Owns forty hotels. Wants yours?", icon = "ev_business", label = "Star guest: tycoon",
	minStars = 4, pay = 6, miss = 1, gift = 2500,
	arrive = "the hotel tycoon, is checking you out!", act = "Counting his money", actIcon = "ev_business", secs = { 6, 8 },
	lines = { "I own forty hotels, you know.", "Show me what you've built, kid.", "Time is money. Chop chop." },
	happy = { "You've got a real business here.", "I'd invest. Here's a little something." },
	sad = { "Amateur hour.", "I'd have knocked this one down." },
}
for id, d in pairs(E.DEFS) do d.id = id end]==])

rep("if unlocked(hotel, d) then", "if not d.star and unlocked(hotel, d) then", true)

rep("	-- round 11: from grade 3 (City Hotel) VIPs visit", [==[	-- round 15: a star guest now and then (never two close together)
	do
		local okG, gr = pcall(function() return require(RS.Shared.Grades).of(hotel) end)
		local okL, lv = pcall(function() return require(RS.Shared.Levels).of(hotel) end)
		local ready = (okG and (gr or 1) >= 2) or (okL and (lv or 1) >= 6)
		if ready and os.clock() - (hotel:GetAttribute("StarAt") or -1e9) > E.STAR_GAP and rng:NextNumber() < E.STAR_CHANCE then
			local list = {}
			for _, d in pairs(E.DEFS) do
				if d.star then table.insert(list, d) end
			end
			table.sort(list, function(a, b) return a.id < b.id end)
			hotel:SetAttribute("StarAt", os.clock())
			return list[rng:NextInteger(1, #list)]
		end
	end
	-- round 11: from grade 3 (City Hotel) VIPs visit]==])

rep("function E.dress(g, d)", [==[-- round 15: the star guests' looks
local function shimmer(g, col)
	local sp = Instance.new("ParticleEmitter")
	sp.Name = "Shimmer"
	sp.Texture = C.ICONS.sparkle
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sp.Lifetime = NumberRange.new(0.8, 1.2)
	sp.Rate = 3
	sp.Speed = NumberRange.new(0.4, 1)
	sp.SpreadAngle = Vector2.new(180, 180)
	sp.LightEmission = 0.8
	sp.Color = ColorSequence.new(col)
	sp.Parent = g.model:FindFirstChild("UpperTorso") or g.root
end
local function shades(g, lens, frame)
	prop(g, "Shades", "Head", CFrame.new(0, 0.12, -0.6), function(m, add)
		for _, x in ipairs({ -0.22, 0.22 }) do
			add(Vector3.new(0.4, 0.24, 0.06), lens, CFrame.new(x, 0, 0), Enum.Material.Glass).Transparency = 0.05
			add(Vector3.new(0.44, 0.04, 0.07), frame, CFrame.new(x, 0.12, 0), Enum.Material.Metal)
		end
		add(Vector3.new(0.12, 0.04, 0.05), frame, CFrame.new(0, 0.08, 0), Enum.Material.Metal)
		for _, x in ipairs({ -0.62, 0.62 }) do add(Vector3.new(0.04, 0.04, 0.6), frame, CFrame.new(x, 0.1, 0.3), Enum.Material.Metal) end
	end)
end
-- a coat over the torso: front panels, back, sides and a hem below the waist
local function coat(g, col, len, open, collar)
	local ut = g.model:FindFirstChild("UpperTorso")
	if not ut then return end
	local s = ut.Size
	prop(g, "Coat", "UpperTorso", CFrame.new(), function(m, add)
		local d = s.Z / 2 + 0.04
		if open then
			for _, x in ipairs({ -1, 1 }) do add(Vector3.new(s.X * 0.36, s.Y + 0.04, 0.08), col, CFrame.new(x * s.X * 0.33, 0, -d), Enum.Material.Fabric) end
		else
			add(Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), col, CFrame.new(0, 0, -d), Enum.Material.Fabric)
		end
		add(Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), col, CFrame.new(0, 0, d), Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do add(Vector3.new(0.08, s.Y + 0.04, s.Z + 0.16), col, CFrame.new(x * (s.X / 2 + 0.04), 0, 0), Enum.Material.Fabric) end
		if len > 0 then
			local y = -s.Y / 2 - len / 2 - 0.02
			add(Vector3.new(s.X + 0.1, len, 0.08), col, CFrame.new(0, y, d + 0.02), Enum.Material.Fabric)
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(s.X * 0.42, len, 0.08), col, CFrame.new(x * s.X * 0.3, y, -d - 0.02), Enum.Material.Fabric)
				add(Vector3.new(0.08, len, s.Z + 0.2), col, CFrame.new(x * (s.X / 2 + 0.06), y, 0), Enum.Material.Fabric)
			end
		end
		if collar then
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(0.34, 0.5, 0.1), collar, CFrame.new(x * 0.34, s.Y / 2 - 0.15, -d - 0.05) * CFrame.Angles(0, 0, x * math.rad(-24)), Enum.Material.Fabric)
			end
		end
	end)
	for _, n in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local a = g.model:FindFirstChild(n)
		if a then
			prop(g, "Sleeve", n, CFrame.new(), function(m, add)
				add(a.Size + Vector3.new(0.08, 0.02, 0.08), col, CFrame.new(), Enum.Material.Fabric)
			end)
		end
	end
end
LOOKS.rockstar = function(g)
	shades(g, Color3.fromRGB(20, 20, 26), Color3.fromRGB(200, 204, 214))
	coat(g, Color3.fromRGB(26, 24, 28), 0, true, Color3.fromRGB(40, 38, 44))
	prop(g, "Studs", "UpperTorso", CFrame.new(), function(m, add)
		local s = g.model.UpperTorso.Size
		for i = 0, 5 do
			for _, x in ipairs({ -1, 1 }) do
				add(Vector3.new(0.09, 0.09, 0.09), Color3.fromRGB(214, 216, 224), CFrame.new(x * s.X * 0.18, s.Y * 0.42 - i * 0.24, -s.Z / 2 - 0.1), Enum.Material.Metal, Enum.PartType.Ball)
			end
		end
	end)
	shimmer(g, Color3.fromRGB(255, 120, 200))
end
LOOKS.royal = function(g)
	prop(g, "Tiara", "Head", CFrame.new(0, 0.68, -0.15), function(m, add)
		add(Vector3.new(1.1, 0.1, 0.12), Color3.fromRGB(232, 196, 96), CFrame.new(0, 0, 0), Enum.Material.Metal)
		for i = -2, 2 do
			add(Vector3.new(0.1, 0.22 - math.abs(i) * 0.04, 0.08), Color3.fromRGB(232, 196, 96), CFrame.new(i * 0.2, 0.14, 0), Enum.Material.Metal)
		end
		add(Vector3.new(0.16, 0.16, 0.16), Color3.fromRGB(110, 170, 255), CFrame.new(0, 0.26, -0.02), Enum.Material.Glass, Enum.PartType.Ball)
		for _, x in ipairs({ -0.4, 0.4 }) do add(Vector3.new(0.1, 0.1, 0.1), Color3.fromRGB(220, 60, 90), CFrame.new(x, 0.12, -0.02), Enum.Material.Glass, Enum.PartType.Ball) end
	end)
	local s = g.model.UpperTorso.Size
	prop(g, "Sash", "UpperTorso", CFrame.new(0, 0, -s.Z / 2 - 0.06) * CFrame.Angles(0, 0, math.rad(-38)), function(m, add)
		add(Vector3.new(0.34, s.Y * 1.35, 0.06), Color3.fromRGB(44, 72, 170), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.3, 0.3, 0.08), Color3.fromRGB(232, 196, 96), CFrame.new(0, -0.15, -0.02), Enum.Material.Metal, Enum.PartType.Ball)
	end)
	prop(g, "Pearls", "UpperTorso", CFrame.new(0, s.Y / 2 - 0.12, -s.Z / 2 - 0.05), function(m, add)
		for i = -4, 4 do
			add(Vector3.new(0.11, 0.11, 0.11), Color3.fromRGB(246, 242, 232), CFrame.new(i * 0.1, -math.abs(i) * -0.03 - 0.16 + (i * i) * 0.012, 0), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end)
	prop(g, "Cape", "UpperTorso", CFrame.new(0, -0.05, s.Z / 2 + 0.08), function(m, add)
		add(Vector3.new(s.X + 0.3, s.Y + 2.1, 0.08), Color3.fromRGB(150, 24, 44), CFrame.new(0, -1.0, 0.08) * CFrame.Angles(math.rad(6), 0, 0), Enum.Material.Fabric)
		add(Vector3.new(s.X + 0.4, 0.22, 0.24), Color3.fromRGB(246, 244, 240), CFrame.new(0, s.Y / 2 + 0.02, 0), Enum.Material.Fabric)
	end)
	shimmer(g, Color3.fromRGB(255, 220, 120))
end
LOOKS.critic = function(g)
	prop(g, "Beret", "Head", CFrame.new(0.08, 0.66, 0.02) * CFrame.Angles(0, 0, math.rad(-10)), function(m, add)
		add(Vector3.new(1.35, 0.32, 1.3), Color3.fromRGB(28, 28, 34), CFrame.new(), Enum.Material.Fabric, Enum.PartType.Ball)
		add(Vector3.new(0.08, 0.14, 0.08), Color3.fromRGB(28, 28, 34), CFrame.new(0, 0.18, 0), Enum.Material.Fabric)
	end)
	prop(g, "Specs", "Head", CFrame.new(0, 0.12, -0.6), function(m, add)
		for _, x in ipairs({ -0.22, 0.22 }) do
			add(Vector3.new(0.05, 0.3, 0.3), Color3.fromRGB(196, 40, 52), CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		add(Vector3.new(0.14, 0.04, 0.04), Color3.fromRGB(196, 40, 52), CFrame.new(0, 0.04, 0))
	end)
	local s = g.model.UpperTorso.Size
	prop(g, "Scarf", "UpperTorso", CFrame.new(0, s.Y / 2 - 0.05, 0), function(m, add)
		add(Vector3.new(s.X * 0.62, 0.3, s.Z + 0.16), Color3.fromRGB(196, 40, 52), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.3, 0.9, 0.1), Color3.fromRGB(196, 40, 52), CFrame.new(0.3, -0.5, -s.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(8)), Enum.Material.Fabric)
	end)
	coat(g, Color3.fromRGB(52, 54, 64), 0.5, true)
	prop(g, "Notebook", "LeftHand", CFrame.new(0, -0.35, -0.25) * CFrame.Angles(math.rad(-65), 0, 0), function(m, add)
		add(Vector3.new(0.7, 0.9, 0.1), Color3.fromRGB(30, 30, 36), CFrame.new(), Enum.Material.Leather)
		add(Vector3.new(0.62, 0.82, 0.04), Color3.fromRGB(250, 248, 240), CFrame.new(0, 0, -0.06))
	end)
	shimmer(g, Color3.fromRGB(255, 240, 200))
end
LOOKS.mystery = function(g)
	prop(g, "Fedora", "Head", CFrame.new(0, 0.66, 0), function(m, add)
		add(Vector3.new(0.1, 1.9, 1.9), Color3.fromRGB(58, 50, 44), CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.62, 1.22, 1.22), Color3.fromRGB(58, 50, 44), CFrame.new(0, 0.24, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.16, 1.25, 1.25), Color3.fromRGB(26, 22, 20), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
	shades(g, Color3.fromRGB(14, 14, 18), Color3.fromRGB(30, 30, 34))
	coat(g, Color3.fromRGB(184, 150, 104), 1.4, false, Color3.fromRGB(160, 128, 86))
	prop(g, "Belt", "LowerTorso", CFrame.new(), function(m, add)
		local s = g.model.LowerTorso.Size
		add(Vector3.new(s.X + 0.2, 0.2, s.Z + 0.24), Color3.fromRGB(150, 118, 78), CFrame.new(0, s.Y / 2 - 0.05, 0), Enum.Material.Fabric)
	end)
end
LOOKS.tycoon = function(g)
	prop(g, "TopHat", "Head", CFrame.new(0, 0.66, 0), function(m, add)
		add(Vector3.new(0.08, 1.75, 1.75), Color3.fromRGB(22, 20, 24), CFrame.new(0, -0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(1.25, 1.16, 1.16), Color3.fromRGB(22, 20, 24), CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
		add(Vector3.new(0.24, 1.18, 1.18), Color3.fromRGB(232, 196, 96), CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end)
	prop(g, "Monocle", "Head", CFrame.new(0.22, 0.12, -0.62), function(m, add)
		add(Vector3.new(0.05, 0.32, 0.32), Color3.fromRGB(232, 196, 96), CFrame.new() * CFrame.Angles(0, math.rad(90), 0), Enum.Material.Metal, Enum.PartType.Cylinder)
		add(Vector3.new(0.02, 0.6, 0.02), Color3.fromRGB(232, 196, 96), CFrame.new(0.12, -0.42, 0.02), Enum.Material.Metal)
	end)
	coat(g, Color3.fromRGB(30, 30, 38), 1.0, true, Color3.fromRGB(20, 20, 24))
	local s = g.model.UpperTorso.Size
	prop(g, "Vest", "UpperTorso", CFrame.new(0, -0.05, -s.Z / 2 - 0.03), function(m, add)
		add(Vector3.new(s.X * 0.36, s.Y * 0.8, 0.04), Color3.fromRGB(140, 30, 44), CFrame.new(), Enum.Material.Fabric)
		add(Vector3.new(0.5, 0.2, 0.08), Color3.fromRGB(20, 20, 24), CFrame.new(0, s.Y * 0.42, -0.03), Enum.Material.Fabric)
		add(Vector3.new(0.5, 0.04, 0.05), Color3.fromRGB(232, 196, 96), CFrame.new(-0.2, -0.1, -0.03) * CFrame.Angles(0, 0, math.rad(14)), Enum.Material.Metal)
	end)
	prop(g, "Cane", "RightHand", GRIP, function(m, add)
		add(Vector3.new(2.6, 0.12, 0.12), Color3.fromRGB(22, 20, 24), CFrame.new(0, -1.2, 0.1) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		add(Vector3.new(0.26, 0.26, 0.26), Color3.fromRGB(232, 196, 96), CFrame.new(0, 0.1, 0.1), Enum.Material.Metal, Enum.PartType.Ball)
	end)
	shimmer(g, Color3.fromRGB(255, 220, 120))
end

function E.dress(g, d)]==])

local f, err = loadstring(src)
if not f then return "compile " .. tostring(err) end
s.Source = src
return "ok"
