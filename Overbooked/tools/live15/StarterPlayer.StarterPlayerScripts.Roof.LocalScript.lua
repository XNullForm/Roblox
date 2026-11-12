-- StarterPlayerScripts.Roof: shows or hides the roof of the hotel you work in, on this screen only.
-- Player attribute RoofMode: "auto" (hidden while you build), "show" (always there), "hide" (always gone).
-- It fades the roof and ceiling (Hotel.Roof) with LocalTransparencyModifier, stops them casting shadows,
-- and sets the hotel attribute RoofHidden locally so Lighting lights the hotel as open sky.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PLOTS = workspace:WaitForChild("Plots")

local shown = 1 -- 1 = roof fully there, 0 = gone
local want = 1
local last

local function hotel()
	local id = player:GetAttribute("Plot")
	return id and PLOTS:FindFirstChild(id)
end

local function hidden()
	local mode = player:GetAttribute("RoofMode") or "auto"
	if mode == "hide" then return true end
	if mode == "show" then return false end
	return player:GetAttribute("Building") == true
end

local function apply(h, k)
	local roof = h and h:FindFirstChild("Roof")
	if not roof then return end
	for _, d in ipairs(roof:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1 - k
			if d:GetAttribute("Shadow") == nil then d:SetAttribute("Shadow", d.CastShadow) end
			d.CastShadow = k > 0.5 and d:GetAttribute("Shadow") or false
		elseif d:IsA("SurfaceGui") or d:IsA("Decal") then
			if d:IsA("SurfaceGui") then d.Enabled = k > 0.5 end
		end
	end
	h:SetAttribute("RoofHidden", k < 0.5 or nil)
end

RunService.Heartbeat:Connect(function(dt)
	local h = hotel()
	if last and last ~= h then apply(last, 1) end -- moved to another hotel: put the old roof back
	want = hidden() and 0 or 1
	local roof = h and h:FindFirstChild("Roof")
	-- a new wing rebuilds the roof: re-apply when it changes
	local stamp = roof and #roof:GetDescendants() or 0
	if shown ~= want or h ~= last or stamp ~= (h and h:GetAttribute("RoofStamp") or 0) then
		shown = want > shown and math.min(shown + dt * 4, 1) or math.max(shown - dt * 4, 0)
		if h then
			apply(h, shown)
			h:SetAttribute("RoofStamp", stamp)
		end
	end
	last = h
end)
