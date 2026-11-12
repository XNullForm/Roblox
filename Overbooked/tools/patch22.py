"""Round 22 edits to the src15 mirrors: hotel styles (floors, walls, roof) in HotelSkin, Upgrades and the Upgrades tab."""
import os
H = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src15")


def edit(name, pairs, pre=None):
    p = os.path.join(H, name)
    s = open(p, encoding="utf8").read()
    if pre:
        s = pre(s)
    for a, b in pairs:
        assert a in s, (name, a[:70])
        s = s.replace(a, b)
    open(p, "w", encoding="utf8").write(s)
    print("ok", name)


edit("ServerStorage.HotelSkin.ModuleScript.lua", [
    ('local GRIME = rgb(120, 110, 90)\n', '''local GRIME = rgb(120, 110, 90)

-- round 22: the finishes the owner picks (Shared.Upgrades.STYLES; hotel attribute Style). Floors and walls are
-- found by part name, the roof by its tile / roof kind.
local FLOOR = {
	stone = { Mat.Limestone, "R16_Stone", rgb(238, 228, 208) }, oak = { Mat.WoodPlanks, "", rgb(204, 160, 110) },
	walnut = { Mat.WoodPlanks, "", rgb(124, 88, 62) }, marble = { Mat.Marble, "Checker", rgb(255, 255, 255) },
	terracotta = { Mat.Pavement, "R16_Paver", rgb(224, 140, 102) }, concrete = { Mat.Concrete, "", rgb(178, 180, 184) },
	carpet = { Mat.Fabric, "", rgb(66, 112, 124) },
}
local WALLC = {
	white = rgb(250, 246, 238), sand = rgb(238, 224, 198), sage = rgb(208, 222, 206), sky = rgb(208, 226, 240),
	blush = rgb(242, 216, 208), charcoal = rgb(78, 82, 92),
}
local ROOFC = {
	terracotta = { Mat.ClayRoofTiles, rgb(208, 110, 74) }, slate = { Mat.Slate, rgb(84, 92, 104) },
	white = { Mat.Concrete, rgb(238, 236, 230) }, copper = { Mat.Metal, rgb(72, 146, 124) },
}
local WALL_NAMES = { Paper = true, PierIn = true, HeaderIn = true }
local styleOf = setmetatable({}, { __mode = "k" }) -- hotel -> its style table (refreshed with the look)
'''),
    ('''	local mv = p.MaterialVariant
	if mv == "Brick" or mv == "R16_Stucco" then''', '''	local mv = p.MaterialVariant
	local n = p.Name
	if n == "LobbyFloor" then
		k = "s_lobby"
	elseif n == "Floor" and p.Parent and p.Parent.Parent and p.Parent.Parent.Name == "Rooms" then
		k = "s_rooms"
	elseif WALL_NAMES[n] or (n == "Core" and p.Material == Mat.Plaster) then
		k = "s_wall"
	elseif mv == "Brick" or mv == "R16_Stucco" then'''),
    ('''function Skin.dress(p, stage)
	local k = kindOf(p)
	if not k then return end
	local L = LOOKS[stage] or LOOKS[2]
''', '''function Skin.dress(p, stage, style)
	local k = kindOf(p)
	if not k then return end
	local L = LOOKS[stage] or LOOKS[2]
	style = style or U.STYLE_DEFAULT
	if k == "s_lobby" or k == "s_rooms" then
		local v = FLOOR[k == "s_lobby" and style.lobby or style.rooms] or FLOOR.stone
		p.Material, p.MaterialVariant, p.Color = v[1], v[2], v[3]:Lerp(GRIME, L.grime)
		return
	elseif k == "s_wall" then
		p.Material, p.MaterialVariant = Mat.Plaster, ""
		p.Color = (WALLC[style.walls] or WALLC.white):Lerp(GRIME, L.grime)
		return
	elseif (k == "tile" or k == "roof") and stage >= 2 then
		local r = ROOFC[style.roof] or ROOFC.terracotta
		p.Material, p.MaterialVariant, p.Color = r[1], "", r[2]
		return
	end
'''),
    ('''function Skin.apply(root, stage)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not skipped(d, root) then Skin.dress(d, stage) end
	end
end''', '''function Skin.apply(root, stage, style)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not skipped(d, root) then Skin.dress(d, stage, style) end
	end
end'''),
    ('''	hotel:SetAttribute("Look", stage)
	Skin.apply(hotel, stage)
	Skin.decor(hotel, stage)''', '''	hotel:SetAttribute("Look", stage)
	local style = U.style(hotel)
	styleOf[hotel] = style
	Skin.apply(hotel, stage, style)
	if hotel:GetAttribute("DecorStage") ~= stage or not hotel:FindFirstChild("LookDecor") then
		hotel:SetAttribute("DecorStage", stage)
		Skin.decor(hotel, stage)
	end'''),
    ('''	hotel:GetAttributeChangedSignal("Grade"):Connect(later)''', '''	hotel:GetAttributeChangedSignal("Grade"):Connect(later)
	hotel:GetAttributeChangedSignal("Style"):Connect(later)
	-- HotelBuilder restyles its own parts now and then (a new grade, a custom room): lay the look back over it
	task.spawn(function()
		while hotel.Parent do
			task.wait(25)
			if hotel.Parent then Skin.apply(hotel, hotel:GetAttribute("Look") or 2, styleOf[hotel]) end
		end
	end)'''),
    ('''Skin.dress(d, hotel:GetAttribute("Look") or 2) end''', '''Skin.dress(d, hotel:GetAttribute("Look") or 2, styleOf[hotel]) end'''),
], pre=lambda s: s.replace('"SK"', '"SK3"'))

edit("ReplicatedStorage.Shared.Upgrades.ModuleScript.lua", [
    ('''function U.decode(raw)''', '''-- round 22: finishes the owner can pick for free in the Upgrades tab (hotel attribute Style, JSON { key = id }).
-- ServerStorage.HotelSkin paints them. The third value is the colour of the button.
U.STYLE_DEFAULT = { lobby = "stone", rooms = "oak", walls = "white", roof = "terracotta" }
local rgb = Color3.fromRGB
local FLOORS = {
	{ "stone", "Sandstone", rgb(238, 228, 208) }, { "oak", "Oak planks", rgb(204, 160, 110) }, { "walnut", "Walnut planks", rgb(124, 88, 62) },
	{ "marble", "Checker marble", rgb(210, 226, 216) }, { "terracotta", "Terracotta tile", rgb(224, 140, 102) },
	{ "concrete", "Concrete", rgb(178, 180, 184) }, { "carpet", "Teal carpet", rgb(66, 112, 124) },
}
U.STYLES = {
	{ key = "lobby", name = "Lobby floor", list = FLOORS },
	{ key = "rooms", name = "Room floors", list = FLOORS },
	{ key = "walls", name = "Walls", list = {
		{ "white", "White", rgb(250, 246, 238) }, { "sand", "Sand", rgb(238, 224, 198) }, { "sage", "Sage", rgb(208, 222, 206) },
		{ "sky", "Sky", rgb(208, 226, 240) }, { "blush", "Blush", rgb(242, 216, 208) }, { "charcoal", "Charcoal", rgb(78, 82, 92) },
	} },
	{ key = "roof", name = "Roof", list = {
		{ "terracotta", "Terracotta tile", rgb(208, 110, 74) }, { "slate", "Slate", rgb(84, 92, 104) },
		{ "white", "White", rgb(238, 236, 230) }, { "copper", "Green copper", rgb(72, 146, 124) },
	} },
}
function U.style(hotel)
	local t = {}
	for k, v in pairs(U.STYLE_DEFAULT) do t[k] = v end
	local raw = hotel and hotel:GetAttribute("Style")
	if type(raw) == "string" and raw ~= "" then
		local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(d) == "table" then
			for _, g in ipairs(U.STYLES) do
				for _, e in ipairs(g.list) do
					if d[g.key] == e[1] then t[g.key] = e[1] end
				end
			end
		end
	end
	return t
end

function U.decode(raw)'''),
])

edit("ServerScriptService.Upgrades.Script.lua", [
    ('''remote.OnServerInvoke = function(player, id)
	local def = type(id) == "string" and U.BY[id]''', '''remote.OnServerInvoke = function(player, id, key, value)
	-- round 22: ("style", key, id) picks a floor, wall or roof finish (free)
	if id == "style" then
		local hotel = hotelOf(player)
		if not hotel then return false, "Join your hotel first" end
		if os.clock() - (last[player] or 0) < 0.15 then return false, "Slow down" end
		last[player] = os.clock()
		for _, g in ipairs(U.STYLES) do
			if g.key == key then
				for _, e in ipairs(g.list) do
					if e[1] == value then
						local st = U.style(hotel)
						st[key] = value
						hotel:SetAttribute("Style", U.encode(st))
						return true
					end
				end
			end
		end
		return false, "No such style"
	end
	local def = type(id) == "string" and U.BY[id]'''),
])

edit("StarterPlayer.StarterPlayerScripts.UpgradesUI.LocalScript.lua", [
    ('''local function refresh()
	local h = hotel()''', '''-- round 22: the hotel's style. A row per surface with a swatch for every finish; the ringed one is in use
local styleBtns = {}
do
	UI.label(page, "HOTEL STYLE", 13, { FontFace = UI.F.heavy, TextColor3 = T.brand, Size = UDim2.new(1, 0, 0, 30), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = 50 })
	for gi, g in ipairs(U.STYLES) do
		local row = UI.new("Frame", { Name = "Style_" .. g.key, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = T.ink2, LayoutOrder = 50 + gi, Parent = page })
		UI.corner(row, 14)
		UI.stroke(row, 1, T.line, 0)
		UI.label(row, g.name, 18, { FontFace = UI.F.black, Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(200, 22) })
		local now = UI.label(row, "", 13, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(20, 34), Size = UDim2.fromOffset(200, 18) })
		styleBtns[g.key] = { now = now, list = {} }
		for i, e in ipairs(g.list) do
			local b = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(44, 44), Position = UDim2.new(1, -18 - (#g.list - i) * 54, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = e[3], Parent = row })
			UI.corner(b, 12)
			local ring = Instance.new("UIStroke")
			ring.Thickness = 3
			ring.Color = T.brand
			ring.Transparency = 1
			ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			ring.Parent = b
			UI.tooltip(b, e[2])
			b.Activated:Connect(function()
				UI.sound("Click")
				local ok, good, msg = pcall(function() return remote:InvokeServer("style", g.key, e[1]) end)
				if not (ok and good) then UI.toast(ok and msg or "That didn't work", nil, "bad") end
			end)
			styleBtns[g.key].list[e[1]] = { ring = ring, name = e[2] }
		end
	end
end

local function refresh()
	local h = hotel()
	local style = U.style(h)
	for key, sb in pairs(styleBtns) do
		for id, b in pairs(sb.list) do
			local on = style[key] == id
			b.ring.Transparency = on and 0 or 1
			if on then sb.now.Text = b.name end
		end
	end'''),
    ('''		h:GetAttributeChangedSignal("Grade"):Connect(refresh)''', '''		h:GetAttributeChangedSignal("Grade"):Connect(refresh)
		h:GetAttributeChangedSignal("Style"):Connect(refresh)'''),
])
