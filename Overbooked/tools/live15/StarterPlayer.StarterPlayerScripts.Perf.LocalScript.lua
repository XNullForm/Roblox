-- StarterPlayerScripts.Perf (round 10d): client-side savings nobody should notice.
--   1. Lights in the city and the other plots switch off when they're far from the camera (Culled attribute).
--      Lighting's night lights record what they want in NightOn, so a light coming back in range knows
--      whether it should be on.
--   2. Small city props (lamps' fittings, signs, bins, litter) stop casting shadows.
local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local LIGHT_RANGE = 140 -- studs past a light's own range before it's switched off
local SMALL = 2.5 -- props smaller than this (largest side) cast no shadow
local BATCH = 60 -- lights checked per frame

local lights, index = {}, {}
local function track(d)
	if d:IsA("Light") and not index[d] then
		index[d] = true
		table.insert(lights, d)
	end
end
local function untrack(d)
	if index[d] then
		index[d] = nil
		local i = table.find(lights, d)
		if i then table.remove(lights, i) end
	end
end
local function small(d)
	if d:IsA("BasePart") and d.CastShadow then
		local s = d.Size
		if math.max(s.X, s.Y, s.Z) < SMALL then d.CastShadow = false end
	end
end

local function watch(root, shadows)
	for _, d in ipairs(root:GetDescendants()) do
		track(d)
		if shadows then small(d) end
	end
	root.DescendantAdded:Connect(function(d)
		track(d)
		if shadows then small(d) end
	end)
	root.DescendantRemoving:Connect(untrack)
end

task.spawn(function()
	local city = workspace:WaitForChild("City", 60)
	if city then watch(city, true) end
end)
task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 60)
	if plots then watch(plots, false) end
end)

local function lightPos(l)
	local p = l.Parent
	if p:IsA("Attachment") then return p.WorldPosition end
	if p:IsA("BasePart") then return p.Position end
	return nil
end

local cursor = 0
RunService.Heartbeat:Connect(function()
	local n = #lights
	if n == 0 then return end
	local cam = camera.CFrame.Position
	for _ = 1, math.min(BATCH, n) do
		cursor = cursor % n + 1
		local l = lights[cursor]
		local pos = l and l.Parent and lightPos(l)
		if pos then
			local far = (pos - cam).Magnitude > LIGHT_RANGE + l.Range
			local culled = l:GetAttribute("Culled") == true
			if far and not culled then
				l:SetAttribute("BaseOn", l.Enabled)
				l:SetAttribute("Culled", true)
				l.Enabled = false
			elseif not far and culled then
				l:SetAttribute("Culled", nil)
				local night = l:GetAttribute("NightOn")
				if night ~= nil then l.Enabled = night else l.Enabled = l:GetAttribute("BaseOn") ~= false end
			end
		end
	end
end)
