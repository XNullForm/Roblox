-- StarterPlayerScripts.RAH_RoomStatus (round 10b): how a room tells you it needs cleaning.
-- Every room door has a status lamp over it (DoorFrame.StatusLight, made by HotelBuilder). This colours it from
-- the room's State: green when it's ready, warm white while a guest has it, a pulsing amber when it needs
-- cleaning, and off while it's unfurnished. Rooms in your own hotel that need cleaning also get a small
-- "Needs cleaning" tag over the door (it hides once you're inside that room).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local RAH = RS:WaitForChild("RAH")
local C = require(RAH:WaitForChild("Config"))
local UI = require(RAH:WaitForChild("UI"))
local T = UI.T

local COLORS = {
	Ready = Color3.fromRGB(110, 230, 150),
	Booked = Color3.fromRGB(255, 214, 160),
	Dirty = Color3.fromRGB(255, 160, 50),
	Unfurnished = Color3.fromRGB(60, 62, 70),
}

local rooms = {} -- room model -> { lamp, light, tag }

local function makeTag(lamp)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RAH_CleanTag"
	bb.Adornee = lamp
	bb.Size = UDim2.fromOffset(190, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0.6)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local pill = UI.new("Frame", { Name = "Pill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(176, 38), BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, Parent = bb })
	UI.corner(pill, 19)
	UI.stroke(pill, 2, Color3.fromRGB(255, 170, 70), 0.1)
	UI.icon(pill, C.ICONS.clean, 30, { Position = UDim2.fromOffset(6, 4) })
	UI.label(pill, "Needs cleaning", 17, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), TextColor3 = T.cream })
	bb.Parent = player:WaitForChild("PlayerGui")
	UI.pop(pill, 0.4, 0.4)
	return bb
end

local function track(room)
	if rooms[room] then return end
	local fr = room:FindFirstChild("DoorFrame")
	local lamp = fr and fr:FindFirstChild("StatusLight")
	if not lamp then return end
	local light = lamp:FindFirstChild("Glow") or Instance.new("PointLight")
	light.Name = "Glow"
	light.Range = 7
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = lamp
	rooms[room] = { lamp = lamp, light = light }
end

local function myHotel()
	local plots = workspace:FindFirstChild("Plots")
	local id = player:GetAttribute("RAH_Plot")
	return plots and id and plots:FindFirstChild(id)
end

-- rooms stream in and out, and wings are bought at any time: look for them on a slow poll
task.spawn(function()
	while true do
		local plots = workspace:FindFirstChild("Plots")
		if plots then
			for _, h in ipairs(plots:GetChildren()) do
				local rf = h:FindFirstChild("Rooms")
				if rf then for _, r in ipairs(rf:GetChildren()) do track(r) end end
			end
		end
		for r, d in pairs(rooms) do
			if not r.Parent or not d.lamp.Parent then
				if d.tag then d.tag:Destroy() end
				rooms[r] = nil
			end
		end
		task.wait(1)
	end
end)

RunService.Heartbeat:Connect(function()
	local mine = myHotel()
	local t = os.clock()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for r, d in pairs(rooms) do
		local state = r:GetAttribute("State") or "Ready"
		local col = COLORS[state] or COLORS.Ready
		local dirty = state == "Dirty"
		if dirty then
			local k = 0.55 + 0.45 * math.sin(t * 5)
			d.lamp.Color = col:Lerp(Color3.fromRGB(120, 50, 10), 1 - k)
			d.light.Brightness = 0.4 + 1.2 * k
		else
			d.lamp.Color = col
			d.light.Brightness = state == "Unfurnished" and 0 or 0.7
		end
		d.light.Color = col
		-- the tag: your own dirty rooms, hidden while you're inside that room
		local inside = false
		if root then
			local f = r:FindFirstChild("Floor")
			if f then
				local l = f.CFrame:PointToObjectSpace(root.Position)
				inside = math.abs(l.X) < f.Size.X / 2 and math.abs(l.Z) < f.Size.Z / 2 and math.abs(l.Y) < 10
			end
		end
		local want = dirty and mine ~= nil and r:IsDescendantOf(mine) and not inside and not player:GetAttribute("RAH_HideRoomSigns")
		if want and not d.tag then
			d.tag = makeTag(d.lamp)
		elseif not want and d.tag then
			d.tag:Destroy()
			d.tag = nil
		end
		if d.tag then
			d.tag.StudsOffsetWorldSpace = Vector3.new(0, 1.6 + math.sin(t * 3) * 0.18, 0.6)
		end
	end
end)
