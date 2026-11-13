-- StarterPlayerScripts.RoomStatus (round 19): how a room tells you it needs cleaning.
-- The status lamp is gone. Instead (round 35) a yellow 3D A-frame sign stands beside the door of every dirty room
-- (your own hotel only, hidden while you're inside that room), the mess itself stays visible in the
-- room, and the rooms chip under the HUD counts what needs doing.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local C = require(Shared:WaitForChild("Config"))
local UI = require(Shared:WaitForChild("UI"))
local T = UI.T

local rooms = {} -- room model -> { anchor, hanger, swing }

-- round 35: a real 3D sign: a yellow A-frame cleaning board standing in the corridor beside the door, facing out,
-- with the clean icon, NEEDS CLEANING and the room's number. Local to you (parented to the camera, no collisions).
local YELLOW = Color3.fromRGB(255, 204, 40)
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
local function makeSign(room, anchor)
	local f = room:FindFirstChild("Floor")
	local out = anchor.Position - (f and f.Position or anchor.Position)
	out = Vector3.new(out.X, 0, out.Z)
	if out.Magnitude < 0.1 then out = Vector3.new(anchor.CFrame.LookVector.X, 0, anchor.CFrame.LookVector.Z) end
	out = out.Unit
	local side = out:Cross(Vector3.yAxis)
	local at = anchor.Position + out * 2 + side * 3.7
	castParams.FilterDescendantsInstances = { player.Character, workspace.CurrentCamera }
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), castParams)
	local y = hit and hit.Position.Y or (anchor.Position.Y + anchor.Size.Y / 2)
	local base = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(at.X, y, at.Z) + out)
	local m = Instance.new("Model")
	m.Name = "CleanSign"
	local function part(name, size, cf, col)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = col or YELLOW
		p.Size = size
		p.CFrame = base * cf
		p.Parent = m
		return p
	end
	local front = part("Front", Vector3.new(1.7, 2.7, 0.1), CFrame.new(0, 1.3, -0.28) * CFrame.Angles(math.rad(12), 0, 0))
	part("Back", Vector3.new(1.7, 2.7, 0.1), CFrame.new(0, 1.3, 0.28) * CFrame.Angles(math.rad(-12), 0, 0))
	part("Cap", Vector3.new(1.8, 0.16, 0.3), CFrame.new(0, 2.64, 0), Color3.fromRGB(40, 44, 52))
	part("Handle", Vector3.new(0.7, 0.3, 0.12), CFrame.new(0, 2.85, 0), Color3.fromRGB(40, 44, 52))
	m.PrimaryPart = front
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 80
	sg.LightInfluence = 0.6
	sg.Parent = front
	local ink = Color3.fromRGB(26, 28, 34)
	local band = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 10), BackgroundColor3 = ink, Parent = sg })
	UI.new("ImageLabel", { Image = UI.G.clean, ImageColor3 = ink, BackgroundTransparency = 1, Size = UDim2.fromOffset(74, 74), Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = Vector2.new(0.5, 0), Parent = sg })
	UI.label(sg, "NEEDS\nCLEANING", 26, { FontFace = UI.F.black, TextColor3 = ink, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 62), LineHeight = 0.9 })
	UI.label(sg, "ROOM " .. tostring(room:GetAttribute("Label") or room.Name:gsub("%D", "")), 18, { FontFace = UI.F.black, TextColor3 = ink, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 178), Size = UDim2.new(1, 0, 0, 22) })
	m.Parent = workspace.CurrentCamera
	return m, base
end

local function track(room)
	if rooms[room] then return end
	local fr = room:FindFirstChild("DoorFrame")
	if not fr then return end
	-- the threshold pins the hanger to the doorway whatever angle the door leaf sits at
	local anchor = fr:FindFirstChild("Threshold") or fr:FindFirstChildWhichIsA("BasePart")
	if not anchor then return end
	rooms[room] = { anchor = anchor }
end

local function myHotel()
	local plots = workspace:FindFirstChild("Plots")
	local id = player:GetAttribute("Plot")
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
			if not r.Parent or not d.anchor.Parent then
				if d.hanger then d.hanger:Destroy() end
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
		local dirty = (r:GetAttribute("State") or "Ready") == "Dirty"
		-- the hanger: your own dirty rooms, hidden while you're inside that room
		local inside = false
		if root then
			local f = r:FindFirstChild("Floor")
			if f then
				local l = f.CFrame:PointToObjectSpace(root.Position)
				inside = math.abs(l.X) < f.Size.X / 2 and math.abs(l.Z) < f.Size.Z / 2 and math.abs(l.Y) < 10
			end
		end
		local want = dirty and mine ~= nil and r:IsDescendantOf(mine) and not inside and not player:GetAttribute("HideRoomSigns")
		if want and not d.hanger then
			d.hanger, d.base = makeSign(r, d.anchor)
			d.off = d.base:ToObjectSpace(d.hanger:GetPivot())
			d.born = t
		elseif not want and d.hanger then
			d.hanger:Destroy()
			d.hanger, d.base = nil, nil
		end
		if d.hanger and d.born then
			-- it drops in and wobbles to a stop
			local k = math.min(1, (t - d.born) / 0.9)
			local drop = math.max(0, 1 - k * 2.2) * 2.5
			local wob = math.sin(k * 18) * (1 - k) * 0.12
			d.hanger:PivotTo(d.base * CFrame.new(0, drop, 0) * CFrame.Angles(0, 0, wob) * d.off)
			if k >= 1 then d.born = nil end
		end
	end
end)
