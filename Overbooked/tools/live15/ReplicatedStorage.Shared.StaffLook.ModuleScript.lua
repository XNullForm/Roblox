-- ReplicatedStorage.Shared.StaffLook (round 13): what each staff member looks like, shared by the server (the real
-- staff) and the client (the wardrobe preview). A look is a small table saved per staff member in the hotel
-- attribute StaffLooks (JSON, "janitor1" -> look):
--   name, skin (C.SKIN), hair (C.HAIR, 0 = none), face (C.FACES), color (PALETTE), trim (TRIMS),
--   style (ROLES[role].styles, some need the Tailored Uniforms research), acc (ROLES[role].acc: headwear and extras)
-- L.dress(model, role, look) rebuilds the outfit in place: body colours, part-built clothing (tagged with the
-- attribute SL so the next dress clears it), headwear, hair and face. It returns the job props' welds
-- ({ mopWeld, mopRest, toolWeld, toolRest }) for the sim to animate. Hair and faces come from
-- RS.Shared.StaffParts (Hair_<i> accessories, Face_<i> decal textures), filled once by L.ensureParts() on the server.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = require(RS:WaitForChild("Shared"):WaitForChild("Config"))

local L = {}

L.PALETTE = {
	{ "Navy", Color3.fromRGB(34, 48, 92) }, { "Burgundy", Color3.fromRGB(128, 30, 48) }, { "Forest", Color3.fromRGB(36, 96, 64) },
	{ "Royal", Color3.fromRGB(52, 96, 200) }, { "Charcoal", Color3.fromRGB(52, 54, 62) }, { "Cream", Color3.fromRGB(236, 228, 208) },
	{ "Teal", Color3.fromRGB(30, 128, 132) }, { "Plum", Color3.fromRGB(96, 52, 110) }, { "Crimson", Color3.fromRGB(196, 44, 52) },
	{ "Sky", Color3.fromRGB(110, 170, 230) }, { "Orange", Color3.fromRGB(226, 128, 44) }, { "White", Color3.fromRGB(246, 246, 242) },
	{ "Black", Color3.fromRGB(28, 28, 32) }, { "Mustard", Color3.fromRGB(214, 170, 70) },
}
L.TRIMS = {
	{ "Gold", Color3.fromRGB(232, 192, 92) }, { "Silver", Color3.fromRGB(204, 210, 220) }, { "Black", Color3.fromRGB(36, 36, 42) },
	{ "Copper", Color3.fromRGB(196, 116, 70) },
}
-- styles: { name, premium? }; acc: names (1 is the role's default headwear)
L.ROLES = {
	janitor = { color = 4, styles = { { "Overalls" }, { "Work Shirt" }, { "Zip Tunic" }, { "Housekeeper", true } },
		acc = { "Cap", "None", "Bandana", "Headphones", "Glasses" } },
	doorman = { color = 9, styles = { { "Greatcoat" }, { "Tailcoat" }, { "Short Jacket" }, { "Royal Coat", true } },
		acc = { "Peaked Cap", "Top Hat", "None", "Glasses" } },
	receptionist = { color = 1, styles = { { "Blazer" }, { "Waistcoat" }, { "Polo" }, { "Tuxedo", true } },
		acc = { "None", "Glasses", "Headset", "Flower Pin" } },
	cook = { color = 12, styles = { { "Chef Whites" }, { "Bib Apron" }, { "Short Sleeves" }, { "Head Chef", true } },
		acc = { "Tall Toque", "Skull Cap", "Bandana", "Short Toque" } },
	handyman = { color = 11, styles = { { "Coveralls" }, { "Hi-Vis Vest" }, { "Flannel" }, { "Foreman", true } },
		acc = { "Hard Hat", "Beanie", "Cap", "Goggles" } },
}
L.ROLE_N = { janitor = 0, doorman = 6, receptionist = 8, cook = 11, handyman = 4 }

-- jobs (hotel attribute StaffJobs): what each role does first, and when they work. { id, name, what it does }
L.FOCUS = {
	janitor = { { "nearest", "Nearest room", "Cleans whichever dirty room is closest" }, { "first", "My rooms first", "Cleans their rooms first, then helps out" }, { "only", "Only my rooms", "Sticks to their own rooms" } },
	doorman = { { "warm", "Warm welcome", "Takes time to greet: guests start happier" }, { "quick", "Quick door", "Lets guests in faster, no happy boost" }, { "vip", "VIPs first", "Special guests skip the line" } },
	receptionist = { { "both", "Both", "Check-ins and check-outs alike" }, { "in", "Check-ins first", "Faster check-ins, slower check-outs" }, { "out", "Check-outs first", "Faster check-outs, slower check-ins" } },
	cook = { { "oldest", "Oldest order", "Cooks orders in the order they came in" }, { "pricey", "Big orders first", "Cooks the priciest dishes first" } },
	handyman = { { "nearest", "Nearest job", "Fixes whatever is closest" }, { "rooms", "Rooms first", "Guest rooms before the lobby" }, { "lobby", "Lobby first", "The lobby before guest rooms" } },
}
L.SHIFTS = { { "all", "All day", "Works day and night. Full wage" }, { "day", "Day shift", "Rests at night. 40% less wage" }, { "night", "Night shift", "Rests by day. 40% less wage" } }

-- the look a staff member starts with (the same every time for the same role and slot)
function L.default(role, index, name)
	local r = L.ROLES[role] or L.ROLES.janitor
	local n = (L.ROLE_N[role] or 0) + index
	return {
		name = name, skin = (n * 3) % #C.SKIN + 1, hair = (n * 7) % #C.HAIR + 1, face = n % #C.FACES + 1,
		color = r.color, trim = 1, style = 1, acc = 1,
	}
end

-- clamps every field to something valid (premiumOk: the Tailored Uniforms research is done)
function L.clean(role, look, premiumOk, fallback)
	local r = L.ROLES[role] or L.ROLES.janitor
	look = type(look) == "table" and look or {}
	fallback = fallback or L.default(role, 1)
	local function int(v, lo, hi, d)
		v = tonumber(v)
		if not v then return d end
		return math.clamp(math.floor(v), lo, hi)
	end
	local out = {
		name = type(look.name) == "string" and look.name ~= "" and string.sub(look.name, 1, 16) or fallback.name,
		skin = int(look.skin, 1, #C.SKIN, fallback.skin),
		hair = int(look.hair, 0, #C.HAIR, fallback.hair),
		face = int(look.face, 1, #C.FACES, fallback.face),
		color = int(look.color, 1, #L.PALETTE, fallback.color),
		trim = int(look.trim, 1, #L.TRIMS, fallback.trim),
		style = int(look.style, 1, #r.styles, 1),
		acc = int(look.acc, 1, #r.acc, 1),
	}
	if r.styles[out.style][2] and not premiumOk then out.style = 1 end
	return out
end

---------------------------------------------------------------- hair and faces (server fills RS.Shared.StaffParts)

local partsBusy = false
function L.ensureParts()
	if not RunService:IsServer() then return end
	if RS.Shared:FindFirstChild("StaffParts") or partsBusy then return end
	partsBusy = true
	local InsertService = game:GetService("InsertService")
	local f = Instance.new("Folder")
	f.Name = "StaffPartsLoading"
	for i, id in ipairs(C.HAIR) do
		local ok, a = pcall(InsertService.LoadAsset, InsertService, id)
		local acc = ok and a and a:FindFirstChildWhichIsA("Accessory", true)
		if acc then
			acc = acc:Clone()
			acc.Name = "Hair_" .. i
			acc.Parent = f
		end
		if ok and a then a:Destroy() end
	end
	for i, id in ipairs(C.FACES) do
		local ok, a = pcall(InsertService.LoadAsset, InsertService, id)
		local d = ok and a and a:FindFirstChildWhichIsA("Decal", true)
		if d then
			local v = Instance.new("StringValue")
			v.Name = "Face_" .. i
			v.Value = d.Texture
			v.Parent = f
		end
		if ok and a then a:Destroy() end
	end
	f.Name = "StaffParts"
	f.Parent = RS.Shared
	partsBusy = false
end

local function attachAccessory(model, acc)
	local handle = acc:FindFirstChild("Handle")
	if not handle then acc:Destroy() return end
	local att = handle:FindFirstChildOfClass("Attachment")
	local target = att and model:FindFirstChild(att.Name, true)
	for _, w in ipairs(handle:GetChildren()) do
		if w:IsA("Weld") or w:IsA("WeldConstraint") or w:IsA("Motor6D") then w:Destroy() end
	end
	handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, true
	handle.Anchored = false
	if target and target:IsA("Attachment") then
		local w = Instance.new("Weld")
		w.Name = "AccessoryWeld"
		w.Part0 = target.Parent
		w.Part1 = handle
		w.C0 = target.CFrame
		w.C1 = att.CFrame
		w.Parent = handle
		handle.CFrame = target.Parent.CFrame * target.CFrame * att.CFrame:Inverse()
	end
	acc.Parent = model
end

---------------------------------------------------------------- the outfit

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.fromRGB(248, 248, 244)

function L.colors(look)
	local main = L.PALETTE[look.color] and L.PALETTE[look.color][2] or L.PALETTE[1][2]
	local h, s, v = main:ToHSV()
	local light = v > 0.85 and s < 0.2 -- white / cream uniforms
	return {
		main = main,
		dark = main:Lerp(BLACK, light and 0.12 or 0.42),
		deep = light and Color3.fromRGB(46, 48, 56) or main:Lerp(BLACK, 0.62),
		shirt = light and Color3.fromRGB(60, 64, 76) or WHITE,
		trim = L.TRIMS[look.trim] and L.TRIMS[look.trim][2] or L.TRIMS[1][2],
		skin = C.SKIN[look.skin] or C.SKIN[1],
	}
end

function L.dress(model, role, look)
	local refs = {}
	local ut, lt = model:FindFirstChild("UpperTorso"), model:FindFirstChild("LowerTorso")
	local head = model:FindFirstChild("Head")
	if not (ut and lt and head) then return refs end
	local col = L.colors(look)
	local ROLE = L.ROLES[role] or L.ROLES.janitor
	local styleName = ROLE.styles[look.style] and ROLE.styles[look.style][1] or ROLE.styles[1][1]
	local accName = ROLE.acc[look.acc] or ROLE.acc[1]
	-- clear the last outfit
	for _, d in ipairs(model:GetDescendants()) do
		if d:GetAttribute("SL") then d:Destroy() end
	end
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then d:Destroy() end
	end
	local sx, sy, sz = ut.Size.X / 1.94, ut.Size.Y / 1.7, ut.Size.Z / 1.0
	local function put(to, name, size, c0, color, mat, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then p.Shape = shape end
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = false
		p:SetAttribute("SL", true)
		p.CFrame = to.CFrame * c0
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = to, p, c0
		w.Parent = p
		p.Parent = model
		return p, w
	end
	-- torso-space helpers (x across, y up, front is -z)
	local FZ = -0.5 * sz
	local function onChest(name, w, h, x, y, depth, color, mat, rz)
		return put(ut, name, Vector3.new(w * sx, h * sy, depth or 0.06), CFrame.new(x * sx, y * sy, FZ - (depth or 0.06) / 2 + 0.01) * CFrame.Angles(0, 0, rz or 0), color, mat)
	end
	local function onBack(name, w, h, x, y, depth, color, mat)
		return put(ut, name, Vector3.new(w * sx, h * sy, depth or 0.06), CFrame.new(x * sx, y * sy, -FZ + (depth or 0.06) / 2 - 0.01), color, mat)
	end
	local function button(x, y, color, r)
		r = r or 0.13
		return put(ut, "Button", Vector3.new(0.05, r, r), CFrame.new(x * sx, y * sy, FZ - 0.05) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	local trimMat = Enum.Material.Metal

	-- base colours: top = torso + upper arms, sleeve = lower arms, legs, hands, feet
	local top, sleeve, legs, hands, feet = col.main, col.main, col.deep, col.skin, Color3.fromRGB(30, 28, 30)
	if role == "janitor" then
		if styleName == "Overalls" then top, sleeve, legs = col.main:Lerp(WHITE, 0.75), col.skin, col.main
		elseif styleName == "Work Shirt" then top, sleeve, legs = col.main, col.main, Color3.fromRGB(60, 62, 72)
		elseif styleName == "Zip Tunic" then top, sleeve, legs = col.main, col.skin, col.dark
		else top, sleeve, legs = col.main, col.main, col.deep end
	elseif role == "doorman" then
		top, sleeve, legs, hands = col.main, col.main, col.deep, WHITE
	elseif role == "receptionist" then
		if styleName == "Waistcoat" then top, sleeve = WHITE, WHITE
		elseif styleName == "Polo" then top, sleeve, legs = col.main, col.skin, Color3.fromRGB(58, 56, 64)
		elseif styleName == "Tuxedo" then top, sleeve, legs = Color3.fromRGB(26, 26, 30), Color3.fromRGB(26, 26, 30), Color3.fromRGB(26, 26, 30) end
	elseif role == "cook" then
		if styleName == "Head Chef" then top, sleeve, legs = Color3.fromRGB(30, 30, 34), Color3.fromRGB(30, 30, 34), Color3.fromRGB(40, 40, 46)
		elseif styleName == "Bib Apron" then top, sleeve, legs = WHITE, WHITE, Color3.fromRGB(52, 54, 62)
		elseif styleName == "Short Sleeves" then top, sleeve, legs = col.main, col.skin, Color3.fromRGB(52, 54, 62)
		else top, sleeve, legs = col.main, col.main, Color3.fromRGB(46, 48, 56) end
	elseif role == "handyman" then
		feet = Color3.fromRGB(96, 64, 40)
		if styleName == "Coveralls" then top, sleeve, legs = col.main, col.main, col.main
		elseif styleName == "Hi-Vis Vest" then top, sleeve, legs = Color3.fromRGB(70, 74, 84), Color3.fromRGB(70, 74, 84), Color3.fromRGB(52, 74, 120)
		elseif styleName == "Flannel" then top, sleeve, legs = col.main, col.main, Color3.fromRGB(52, 74, 120)
		else top, sleeve, legs = WHITE, WHITE, Color3.fromRGB(52, 74, 120) end
	end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			local n = p.Name
			if n == "UpperTorso" or n:find("UpperArm") then p.Color = top
			elseif n:find("LowerArm") then p.Color = sleeve
			elseif n:find("Hand") then p.Color = hands
			elseif n == "LowerTorso" or n:find("UpperLeg") or n:find("LowerLeg") then p.Color = legs
			elseif n:find("Foot") then p.Color = feet
			elseif n == "Head" or n == "ClassicHead" then p.Color = col.skin end
		end
	end
	-- shiny shoes for everyone
	for _, side in ipairs({ "LeftFoot", "RightFoot" }) do
		local f = model:FindFirstChild(side)
		if f then put(f, "ShoeToe", Vector3.new(f.Size.X * 0.96, f.Size.Y * 0.7, 0.3), CFrame.new(0, -f.Size.Y * 0.1, -f.Size.Z / 2 + 0.1), feet:Lerp(BLACK, 0.2), Enum.Material.SmoothPlastic) end
	end
	-- a belt
	local function belt(color, buckle)
		put(lt, "Belt", Vector3.new(lt.Size.X + 0.04, 0.2, lt.Size.Z + 0.04), CFrame.new(0, lt.Size.Y / 2 - 0.08, 0), color, Enum.Material.Leather)
		if buckle then put(lt, "Buckle", Vector3.new(0.32, 0.22, 0.04), CFrame.new(0, lt.Size.Y / 2 - 0.08, -lt.Size.Z / 2 - 0.04), buckle, trimMat) end
	end
	-- a name badge on the left chest
	local function badge(color)
		local b = onChest("NameBadge", 0.56, 0.2, 0.48, 0.3, 0.04, color or col.trim, trimMat)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.PixelsPerStud = 90
		sg.LightInfluence = 0.4
		sg.Parent = b
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = string.upper(look.name or "")
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(30, 30, 36)
		t.Parent = sg
	end
	-- a coat skirt hanging from the waist (front halves and back)
	local function skirt(len, color, open)
		local h = len
		local y = lt.Size.Y / 2 - h / 2
		local w = lt.Size.X + 0.12
		put(lt, "CoatBack", Vector3.new(w, h, 0.1), CFrame.new(0, y, lt.Size.Z / 2 + 0.06), color)
		if open then
			for _, sgn in ipairs({ -1, 1 }) do
				put(lt, "CoatFront", Vector3.new(w * 0.36, h, 0.1), CFrame.new(sgn * w * 0.32, y, -lt.Size.Z / 2 - 0.06), color)
			end
		else
			put(lt, "CoatFront", Vector3.new(w, h, 0.1), CFrame.new(0, y, -lt.Size.Z / 2 - 0.06), color)
		end
		for _, sgn in ipairs({ -1, 1 }) do
			put(lt, "CoatSide", Vector3.new(0.1, h, lt.Size.Z + 0.12), CFrame.new(sgn * (w / 2), y, 0), color)
		end
	end
	local function lapels(color, deep)
		for _, sgn in ipairs({ -1, 1 }) do
			onChest("Lapel", 0.2, deep or 0.95, sgn * 0.2, 0.38, 0.05, color, nil, sgn * math.rad(-22))
		end
	end
	local function shirtV(color, tie)
		onChest("ShirtFront", 0.42, 0.7, 0, 0.47, 0.03, color)
		if tie then onChest("Tie", 0.14, 0.62, 0, 0.32, 0.05, tie) end
	end
	local function epaulettes(color)
		for _, sgn in ipairs({ -1, 1 }) do
			put(ut, "Epaulette", Vector3.new(0.62 * sx, 0.1, 0.62), CFrame.new(sgn * 0.78 * sx, 0.86 * sy, 0), color, trimMat)
			put(ut, "Fringe", Vector3.new(0.66 * sx, 0.16, 0.66), CFrame.new(sgn * 0.8 * sx, 0.76 * sy, 0), color:Lerp(BLACK, 0.15), Enum.Material.Fabric)
		end
	end
	local function cuffs(color)
		for _, side in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
			local a = model:FindFirstChild(side)
			if a then put(a, "Cuff", Vector3.new(a.Size.X + 0.06, 0.18, a.Size.Z + 0.06), CFrame.new(0, -a.Size.Y / 2 + 0.12, 0), color, Enum.Material.Fabric) end
		end
	end
	local function pocket(x, y, color)
		onChest("Pocket", 0.42, 0.36, x, y, 0.04, color)
		onChest("PocketFlap", 0.44, 0.1, x, y + 0.16, 0.06, color:Lerp(BLACK, 0.2))
	end

	if role == "janitor" then
		if styleName == "Overalls" then
			onChest("Bib", 1.0, 0.9, 0, -0.32, 0.06, col.main, Enum.Material.Fabric)
			onChest("BibPocket", 0.46, 0.3, 0, -0.18, 0.08, col.dark, Enum.Material.Fabric)
			for _, sgn in ipairs({ -1, 1 }) do
				onChest("Strap", 0.16, 0.9, sgn * 0.42, 0.42, 0.05, col.main, Enum.Material.Fabric)
				onBack("Strap", 0.16, 1.6, sgn * 0.3, 0.05, 0.05, col.main, Enum.Material.Fabric)
				button(sgn * 0.42, 0.08, col.trim, 0.14)
			end
		elseif styleName == "Work Shirt" then
			for _, y in ipairs({ 0.55, 0.25, -0.05, -0.35 }) do button(0, y, WHITE, 0.1) end
			onChest("Placket", 0.08, 1.6, 0, 0, 0.03, col.dark)
			pocket(-0.45, 0.25, col.main)
			onChest("Collar", 0.9, 0.14, 0, 0.8, 0.05, col.dark)
			belt(Color3.fromRGB(40, 30, 26), col.trim)
		elseif styleName == "Zip Tunic" then
			onChest("Zip", 0.06, 1.6, 0.2, 0, 0.04, col.trim, trimMat)
			onChest("Panel", 0.5, 1.6, 0.48, 0, 0.03, col.dark)
			onChest("Collar", 0.9, 0.16, 0, 0.8, 0.06, col.dark)
		else -- Housekeeper: a long white apron over a dress
			skirt(1.7, col.main)
			put(lt, "Apron", Vector3.new(1.3, 1.6, 0.06), CFrame.new(0, -0.66, -lt.Size.Z / 2 - 0.16), WHITE, Enum.Material.Fabric)
			onChest("ApronBib", 0.9, 0.8, 0, -0.3, 0.05, WHITE, Enum.Material.Fabric)
			onChest("Collar", 0.9, 0.14, 0, 0.8, 0.05, WHITE)
			cuffs(WHITE)
		end
		if styleName ~= "Housekeeper" then badge() end
		-- a mop in the right hand, held at the top and angled so the head rests on the floor
		local hand = model:FindFirstChild("RightHand")
		if hand then
			local stick, w = put(hand, "Mop", Vector3.new(0.22, 4.2, 0.22), CFrame.Angles(math.rad(38), 0, 0) * CFrame.new(0, -0.9, 0), Color3.fromRGB(196, 136, 82), Enum.Material.Wood)
			put(stick, "MopHead", Vector3.new(1.3, 0.35, 0.7), CFrame.new(0, -2.15, 0) * CFrame.Angles(math.rad(-38), 0, 0), Color3.fromRGB(236, 240, 246), Enum.Material.Fabric)
			put(stick, "MopBand", Vector3.new(0.3, 0.24, 0.3), CFrame.new(0, -1.9, 0), col.main, Enum.Material.SmoothPlastic)
			refs.mopWeld, refs.mopRest = w, w.C0
		end
	elseif role == "doorman" then
		if styleName == "Greatcoat" or styleName == "Royal Coat" then
			skirt(styleName == "Royal Coat" and 1.9 or 1.6, col.main)
			for _, sgn in ipairs({ -1, 1 }) do
				for _, y in ipairs({ 0.45, 0.1, -0.25, -0.6 }) do button(sgn * 0.32, y, col.trim) end
			end
			onChest("Collar", 1.0, 0.2, 0, 0.78, 0.07, col.dark)
			epaulettes(col.trim)
			cuffs(col.trim)
			belt(col.dark, col.trim)
			if styleName == "Royal Coat" then
				-- gold frogging across the chest and a sash
				for _, y in ipairs({ 0.45, 0.2, -0.05, -0.3 }) do onChest("Frog", 0.9, 0.05, 0, y, 0.07, col.trim, trimMat) end
				onChest("Sash", 0.24, 2.0, 0, 0, 0.08, Color3.fromRGB(40, 60, 140), Enum.Material.Fabric, math.rad(-38))
			else
				-- a gold aiguillette from the shoulder
				onChest("Aiguillette", 0.05, 0.75, 0.55, 0.35, 0.07, col.trim, trimMat, math.rad(28))
				onChest("Aiguillette", 0.05, 0.6, 0.65, 0.3, 0.07, col.trim, trimMat, math.rad(18))
			end
		elseif styleName == "Tailcoat" then
			put(lt, "Tail", Vector3.new(lt.Size.X * 0.8, 2.0, 0.1), CFrame.new(0, -0.9, lt.Size.Z / 2 + 0.07), col.main)
			shirtV(WHITE, col.trim)
			lapels(col.dark)
			for _, y in ipairs({ 0.0, -0.3 }) do for _, sgn in ipairs({ -1, 1 }) do button(sgn * 0.38, y, col.trim) end end
			cuffs(WHITE)
		else -- Short Jacket
			onChest("Collar", 0.9, 0.18, 0, 0.78, 0.07, col.trim, trimMat)
			for _, y in ipairs({ 0.45, 0.15, -0.15, -0.45 }) do button(0, y, col.trim) end
			for _, y in ipairs({ 0.45, 0.15, -0.15 }) do onChest("Braid", 0.6, 0.05, 0, y, 0.05, col.trim, trimMat) end
			epaulettes(col.trim)
			belt(col.dark, col.trim)
		end
		badge()
	elseif role == "receptionist" then
		if styleName == "Blazer" then
			shirtV(WHITE, col.trim)
			lapels(col.dark)
			onChest("PocketSquare", 0.24, 0.12, -0.5, 0.34, 0.06, col.trim, Enum.Material.Fabric)
			button(0, -0.35, col.trim)
			skirt(0.55, col.main, true)
			cuffs(WHITE)
		elseif styleName == "Waistcoat" then
			onChest("Vest", 1.4, 1.2, 0, -0.22, 0.05, col.main, Enum.Material.Fabric)
			onBack("VestBack", 1.5, 1.4, 0, -0.1, 0.05, col.main:Lerp(BLACK, 0.2), Enum.Material.Fabric)
			onChest("BowTie", 0.5, 0.2, 0, 0.66, 0.08, col.trim)
			for _, y in ipairs({ 0.2, -0.1, -0.4 }) do button(0, y, col.trim, 0.1) end
			onChest("WatchChain", 0.5, 0.04, -0.3, -0.25, 0.07, col.trim, trimMat, math.rad(14))
		elseif styleName == "Polo" then
			onChest("Collar", 0.8, 0.16, 0, 0.8, 0.06, col.dark)
			onChest("Placket", 0.18, 0.45, 0, 0.55, 0.04, col.dark)
			button(0, 0.65, WHITE, 0.08) button(0, 0.45, WHITE, 0.08)
			onChest("Logo", 0.2, 0.2, -0.5, 0.35, 0.05, col.trim, trimMat)
			belt(Color3.fromRGB(40, 30, 26), col.trim)
		else -- Tuxedo
			shirtV(WHITE)
			onChest("BowTie", 0.5, 0.2, 0, 0.66, 0.08, Color3.fromRGB(20, 20, 24))
			lapels(Color3.fromRGB(14, 14, 16), 1.1)
			for _, y in ipairs({ 0.4, 0.15 }) do button(0, y, Color3.fromRGB(20, 20, 24), 0.08) end
			onChest("Cummerbund", 1.6, 0.3, 0, -0.68, 0.05, col.main, Enum.Material.Fabric)
			onChest("PocketSquare", 0.24, 0.12, -0.5, 0.34, 0.06, WHITE, Enum.Material.Fabric)
			skirt(0.55, Color3.fromRGB(26, 26, 30), true)
			cuffs(WHITE)
		end
		if styleName ~= "Tuxedo" then badge() end
	elseif role == "cook" then
		if styleName == "Chef Whites" or styleName == "Head Chef" then
			-- double-breasted with two rows of buttons and a stand collar
			local btn = styleName == "Head Chef" and col.trim or Color3.fromRGB(60, 60, 66)
			onChest("Flap", 0.8, 1.6, 0.3, 0, 0.04, top:Lerp(BLACK, 0.06))
			for _, sgn in ipairs({ -1, 1 }) do for _, y in ipairs({ 0.45, 0.15, -0.15, -0.45 }) do button(sgn * 0.32 + 0.05, y, btn, 0.11) end end
			onChest("Collar", 0.9, 0.2, 0, 0.8, 0.07, styleName == "Head Chef" and col.trim or top)
			put(lt, "Apron", Vector3.new(1.5, 1.4, 0.06), CFrame.new(0, -0.55, -lt.Size.Z / 2 - 0.12), styleName == "Head Chef" and Color3.fromRGB(46, 48, 56) or WHITE, Enum.Material.Fabric)
			put(lt, "ApronTie", Vector3.new(lt.Size.X + 0.08, 0.12, lt.Size.Z + 0.1), CFrame.new(0, lt.Size.Y / 2 - 0.05, 0), styleName == "Head Chef" and col.trim or WHITE, Enum.Material.Fabric)
			onChest("Neckerchief", 0.7, 0.3, 0, 0.62, 0.08, styleName == "Head Chef" and col.trim or Color3.fromRGB(200, 50, 50), Enum.Material.Fabric)
			onChest("Thermometer", 0.06, 0.4, -0.65, 0.3, 0.06, Color3.fromRGB(200, 200, 210), trimMat)
		elseif styleName == "Bib Apron" then
			onChest("Bib", 1.1, 1.2, 0, -0.2, 0.06, col.main, Enum.Material.Fabric)
			put(lt, "Apron", Vector3.new(1.6, 1.7, 0.06), CFrame.new(0, -0.7, -lt.Size.Z / 2 - 0.12), col.main, Enum.Material.Fabric)
			for _, sgn in ipairs({ -1, 1 }) do onChest("Strap", 0.14, 0.5, sgn * 0.5, 0.6, 0.05, col.main) end
			onChest("Towel", 0.3, 0.5, -0.65, -0.55, 0.08, WHITE, Enum.Material.Fabric)
		else -- Short Sleeves
			onChest("Collar", 0.9, 0.16, 0, 0.8, 0.06, col.dark)
			for _, y in ipairs({ 0.4, 0.1, -0.2 }) do button(0.3, y, col.dark, 0.11) end
			put(lt, "Apron", Vector3.new(1.4, 1.2, 0.06), CFrame.new(0, -0.45, -lt.Size.Z / 2 - 0.12), WHITE, Enum.Material.Fabric)
		end
		badge()
	elseif role == "handyman" then
		if styleName == "Coveralls" then
			onChest("Zip", 0.06, 1.6, 0, 0, 0.04, Color3.fromRGB(200, 200, 210), trimMat)
			pocket(-0.48, 0.3, col.main) pocket(0.48, 0.3, col.main)
			onChest("Collar", 0.9, 0.16, 0, 0.8, 0.06, col.dark)
		elseif styleName == "Hi-Vis Vest" or styleName == "Foreman" then
			local vest = Color3.fromRGB(214, 240, 60)
			if styleName == "Foreman" then vest = col.main end
			onChest("Vest", 1.5, 1.5, 0, -0.08, 0.05, vest, Enum.Material.Fabric)
			onBack("VestBack", 1.6, 1.6, 0, 0, 0.05, vest, Enum.Material.Fabric)
			for _, y in ipairs({ 0.15, -0.4 }) do
				onChest("Reflect", 1.52, 0.12, 0, y, 0.07, Color3.fromRGB(220, 224, 232), trimMat)
				onBack("Reflect", 1.62, 0.12, 0, y, 0.07, Color3.fromRGB(220, 224, 232), trimMat)
			end
			if styleName == "Foreman" then
				onChest("Pen", 0.05, 0.3, -0.5, 0.42, 0.08, col.trim, trimMat)
				local hand = model:FindFirstChild("LeftHand")
				if hand then
					local board = put(hand, "Clipboard", Vector3.new(0.9, 1.2, 0.08), CFrame.new(0, -0.3, -0.35) * CFrame.Angles(math.rad(-60), 0, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
					put(board, "Paper", Vector3.new(0.74, 0.95, 0.02), CFrame.new(0, -0.05, -0.05), WHITE)
					put(board, "Clip", Vector3.new(0.4, 0.12, 0.08), CFrame.new(0, 0.55, -0.06), Color3.fromRGB(200, 204, 214), trimMat)
				end
			end
		else -- Flannel: a checked shirt
			for i = -2, 2 do onChest("Check", 0.07, 1.62, i * 0.38, 0, 0.03, col.dark) end
			for i = -1, 1 do onChest("Check", 1.9, 0.07, 0, i * 0.5, 0.03, col.dark) end
			onChest("Collar", 0.9, 0.14, 0, 0.8, 0.05, col.dark)
		end
		belt(Color3.fromRGB(120, 76, 40), col.trim)
		put(lt, "Pouch", Vector3.new(0.5, 0.5, 0.3), CFrame.new(0.7, -0.25, -0.5), Color3.fromRGB(96, 60, 32), Enum.Material.Leather)
		put(lt, "Hammer", Vector3.new(0.12, 0.6, 0.12), CFrame.new(-0.8, -0.35, -0.45), Color3.fromRGB(150, 100, 60), Enum.Material.Wood)
		put(lt, "HammerHead", Vector3.new(0.4, 0.14, 0.14), CFrame.new(-0.8, -0.02, -0.45), Color3.fromRGB(150, 154, 164), trimMat)
		local hand = model:FindFirstChild("RightHand")
		if hand then
			local steel = Color3.fromRGB(196, 202, 212)
			local shaft, w = put(hand, "Wrench", Vector3.new(0.2, 1.5, 0.12), CFrame.new(0, -0.35, -0.45) * CFrame.Angles(math.rad(-70), 0, 0), steel, trimMat)
			put(shaft, "Jaw", Vector3.new(0.5, 0.36, 0.14), CFrame.new(0, 0.85, 0), steel, trimMat)
			put(shaft, "Grip", Vector3.new(0.24, 0.6, 0.16), CFrame.new(0, -0.5, 0), Color3.fromRGB(200, 60, 50))
			refs.toolWeld, refs.toolRest = w, w.C0
		end
	end

	-- hair (from StaffParts when it changes; the body starts with its description's hair) and face
	local parts = RS.Shared:FindFirstChild("StaffParts")
	if parts and model:GetAttribute("LookHair") ~= look.hair then
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("Accessory") then d:Destroy() end
		end
		local src = parts:FindFirstChild("Hair_" .. look.hair)
		if src then attachAccessory(model, src:Clone()) end
		model:SetAttribute("LookHair", look.hair)
	end
	local fv = parts and parts:FindFirstChild("Face_" .. look.face)
	local ch = model:FindFirstChild("ClassicHead")
	local dec = ch and ch:FindFirstChild("face")
	if fv and dec then dec.Texture = fv.Value end

	-- headwear (big hats hide the hair)
	local hx, hy = head.Size.X / 1.16, head.Size.Y / 1.18
	local top0 = 0.55 * hy
	local hideHair = false
	local function cyl(name, h, d, y, color, mat, z)
		return put(head, name, Vector3.new(h, d * hx, d * hx), CFrame.new(0, y, z or 0) * CFrame.Angles(0, 0, math.rad(90)), color, mat or Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local function glasses(color)
		for _, sgn in ipairs({ -1, 1 }) do
			put(head, "Lens", Vector3.new(0.04, 0.3, 0.3), CFrame.new(sgn * 0.22 * hx, 0.08, -0.62 * hx) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.35
			put(head, "Rim", Vector3.new(0.03, 0.34, 0.34), CFrame.new(sgn * 0.22 * hx, 0.08, -0.6 * hx) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			put(head, "Arm", Vector3.new(0.04, 0.04, 0.7), CFrame.new(sgn * 0.6 * hx, 0.1, -0.25), Color3.fromRGB(30, 30, 34))
		end
		put(head, "Bridge", Vector3.new(0.16, 0.04, 0.04), CFrame.new(0, 0.12, -0.62 * hx), Color3.fromRGB(30, 30, 34))
	end
	if accName == "Cap" then
		put(head, "CapCrown", Vector3.new(1.3 * hx, 0.7, 1.3 * hx), CFrame.new(0, top0 - 0.02, 0), col.main, Enum.Material.Fabric, Enum.PartType.Ball)
		put(head, "CapBill", Vector3.new(1.0 * hx, 0.08, 0.6), CFrame.new(0, top0 - 0.2, -0.75 * hx) * CFrame.Angles(math.rad(-8), 0, 0), col.dark, Enum.Material.Fabric)
		put(head, "CapButton", Vector3.new(0.14, 0.1, 0.14), CFrame.new(0, top0 + 0.33, 0), col.trim)
		hideHair = true
	elseif accName == "Bandana" then
		cyl("Bandana", 0.3, 1.24, top0 - 0.18, col.main:Lerp(Color3.fromRGB(200, 40, 40), 0.5), Enum.Material.Fabric)
		put(head, "Knot", Vector3.new(0.3, 0.3, 0.4), CFrame.new(0, top0 - 0.2, 0.62 * hx), col.main:Lerp(Color3.fromRGB(200, 40, 40), 0.5), Enum.Material.Fabric)
	elseif accName == "Headphones" then
		put(head, "Band", Vector3.new(1.42 * hx, 0.12, 0.2), CFrame.new(0, top0 + 0.08, 0), Color3.fromRGB(30, 30, 36))
		for _, sgn in ipairs({ -1, 1 }) do
			put(head, "EarCup", Vector3.new(0.2, 0.5, 0.5), CFrame.new(sgn * 0.68 * hx, 0, 0), col.main, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			put(head, "Strut", Vector3.new(0.08, 0.5, 0.1), CFrame.new(sgn * 0.68 * hx, top0 - 0.18, 0), Color3.fromRGB(30, 30, 36))
		end
	elseif accName == "Glasses" then
		glasses(Color3.fromRGB(200, 220, 240))
	elseif accName == "Peaked Cap" then
		cyl("Cap", 0.9, 1.32, top0 + 0.15, col.main)
		cyl("Band", 0.24, 1.34, top0 - 0.15, col.trim, trimMat)
		put(head, "Brim", Vector3.new(1.0 * hx, 0.08, 0.5), CFrame.new(0, top0 - 0.26, -0.72 * hx) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(26, 24, 30), Enum.Material.SmoothPlastic)
		put(head, "CapBadge", Vector3.new(0.3, 0.3, 0.06), CFrame.new(0, top0 + 0.1, -0.68 * hx), col.trim, trimMat)
		hideHair = true
	elseif accName == "Top Hat" then
		cyl("Brim", 0.08, 1.8, top0 - 0.12, Color3.fromRGB(26, 24, 30))
		cyl("Crown", 1.3, 1.2, top0 + 0.55, Color3.fromRGB(26, 24, 30))
		cyl("HatBand", 0.24, 1.22, top0 + 0.04, col.main)
		hideHair = true
	elseif accName == "Headset" then
		put(head, "Band", Vector3.new(1.42 * hx, 0.08, 0.12), CFrame.new(0, top0 + 0.06, 0), Color3.fromRGB(40, 40, 46))
		put(head, "EarCup", Vector3.new(0.16, 0.42, 0.42), CFrame.new(0.66 * hx, 0, 0), Color3.fromRGB(40, 40, 46), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		put(head, "Boom", Vector3.new(0.05, 0.05, 0.62), CFrame.new(0.58 * hx, -0.28, -0.36) * CFrame.Angles(0, math.rad(-22), 0), Color3.fromRGB(40, 40, 46))
		put(head, "Mic", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.42 * hx, -0.3, -0.64), col.trim, trimMat, Enum.PartType.Ball)
	elseif accName == "Flower Pin" then
		local f = onChest("Flower", 0.26, 0.26, -0.5, 0.42, 0.08, Color3.fromRGB(230, 90, 120), Enum.Material.Fabric)
		f.Shape = Enum.PartType.Ball
		onChest("FlowerHeart", 0.1, 0.1, -0.5, 0.42, 0.12, col.trim, trimMat)
	elseif accName == "Tall Toque" or accName == "Short Toque" then
		local tall = accName == "Tall Toque"
		cyl("HatBand", 0.5, 1.28, top0 + 0.15, WHITE, Enum.Material.Fabric)
		put(head, "HatPuff", Vector3.new(1.55 * hx, tall and 1.25 or 0.8, 1.55 * hx), CFrame.new(0, top0 + (tall and 0.75 or 0.5), 0), WHITE, Enum.Material.Fabric, Enum.PartType.Ball)
		if tall then
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2
				put(head, "Pleat", Vector3.new(0.05, 0.5, 0.05), CFrame.new(math.cos(a) * 0.64 * hx, top0 + 0.2, math.sin(a) * 0.64 * hx), Color3.fromRGB(226, 226, 222))
			end
		end
		hideHair = true
	elseif accName == "Skull Cap" then
		put(head, "SkullCap", Vector3.new(1.3 * hx, 0.6, 1.3 * hx), CFrame.new(0, top0 + 0.02, 0), col.main:Lerp(Color3.fromRGB(40, 40, 46), 0.5), Enum.Material.Fabric, Enum.PartType.Ball)
		hideHair = true
	elseif accName == "Hard Hat" then
		put(head, "HardHat", Vector3.new(1.3 * hx, 0.66, 1.3 * hx), CFrame.new(0, top0 + 0.05, 0), Color3.fromRGB(255, 200, 40), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		cyl("HatBrim", 0.08, 1.5, top0 - 0.15, Color3.fromRGB(240, 186, 30))
		put(head, "Ridge", Vector3.new(0.16, 0.2, 1.2 * hx), CFrame.new(0, top0 + 0.36, 0), Color3.fromRGB(240, 186, 30))
		hideHair = true
	elseif accName == "Beanie" then
		put(head, "Beanie", Vector3.new(1.32 * hx, 0.8, 1.32 * hx), CFrame.new(0, top0 + 0.05, 0), col.main, Enum.Material.Fabric, Enum.PartType.Ball)
		cyl("BeanieCuff", 0.26, 1.34, top0 - 0.14, col.dark, Enum.Material.Fabric)
		put(head, "Pompom", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0, top0 + 0.46, 0), col.trim, Enum.Material.Fabric, Enum.PartType.Ball)
		hideHair = true
	elseif accName == "Goggles" then
		cyl("GoggleStrap", 0.14, 1.26, top0 - 0.12, Color3.fromRGB(40, 40, 46))
		for _, sgn in ipairs({ -1, 1 }) do
			put(head, "Goggle", Vector3.new(0.14, 0.34, 0.34), CFrame.new(sgn * 0.22 * hx, top0 - 0.12, -0.62 * hx) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 210, 230), Enum.Material.Glass, Enum.PartType.Cylinder)
		end
	end
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("Accessory") then
			local h = d:FindFirstChild("Handle")
			if h then h.Transparency = hideHair and (d.AccessoryType == Enum.AccessoryType.Hat and 1 or 0) or 0 end
			if d.AccessoryType == Enum.AccessoryType.Hat and h then h.Transparency = 1 end
		end
	end
	model:SetAttribute("LookStyle", styleName)
	return refs
end

return L
