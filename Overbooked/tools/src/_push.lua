-- Dev helper (not part of the game). In execute_luau (Edit):
--   loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8791/_push.lua"))()({"RAH_Clock", "RAH_Lighting"})
-- Fetches each src/<name>.lua, compile-checks it, and writes it to its place (creating the script if new).
local HS = game:GetService("HttpService")
local SES = game:GetService("ScriptEditorService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts

-- name -> { parent, class, instance name }
local function where(name)
	local rahMods = { RAH_Config = "Config", RAH_Catalog = "Catalog", RAH_Build = "Build", RAH_Clock = "Clock",
		RAH_UI = "UI", RAH_Research = "Research", RAH_Events = "Events", RAH_Looks = "Looks", RAH_Shapes = "Shapes",
		RAH_Street = "Street", RAH_Levels = "Levels", RAH_Quests = "Quests", RAH_Grades = "Grades", RAH_StaffLook = "StaffLook", RAH_NPCAnimLib = "NPCAnimLib" }
	if rahMods[name] then return RS.RAH, "ModuleScript", rahMods[name] end
	if name == "HotelBuilder" then return SS, "ModuleScript", "RAH_HotelBuilder" end
	if name == "RAH_Loading" then return game:GetService("ReplicatedFirst"), "LocalScript", name end
	local ssMods = { RAH_HotelSim = true, RAH_Bodies = true, RAH_MapBuilder = true, RAH_Walker = true, RAH_GuestEvents = true, RAH_GuestLife = true, RAH_Kitchen = true,
		RAH_Nav = true, RAH_Rooms = true, RAH_Upkeep = true }
	if ssMods[name] then return SS, "ModuleScript", name end
	local server = { RAH_BuildServer = true, RAH_Save = true, RAH_Plots = true, RAH_Crowds = true, RAH_DayNight = true,
		RAH_Tutorial = true, RAH_ResearchServer = true, RAH_QuestServer = true, RAH_Weather = true }
	if server[name] then return SSS, "Script", name end
	return SPS, "LocalScript", name
end

return function(names)
	local out = {}
	for _, name in ipairs(names) do
		local src = HS:GetAsync("http://127.0.0.1:8791/" .. name .. ".lua?t=" .. os.clock())
		src = src:gsub("^\239\187\191", "")
		local fn, err = loadstring(src)
		if not fn then
			table.insert(out, name .. ": COMPILE ERROR " .. tostring(err))
		else
			local parent, class, iname = where(name)
			local s = parent:FindFirstChild(iname)
			if s and not s:IsA(class) then s:Destroy(); s = nil end
			if not s then
				s = Instance.new(class)
				s.Name = iname
				s.Parent = parent
			end
			SES:UpdateSourceAsync(s, function() return src end)
			if name == "HotelBuilder" and SS:FindFirstChild("DevTools") then
				local d = SS.DevTools:FindFirstChild("HotelBuilder")
				if d then SES:UpdateSourceAsync(d, function() return src end) end
			end
			table.insert(out, name .. " -> " .. s:GetFullName() .. " (" .. #src .. ")")
		end
	end
	return table.concat(out, "\n")
end
