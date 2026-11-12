-- StarterPlayerScripts.RoomStatus (round 19): how a room tells you it needs cleaning.
-- The status lamp is gone. Instead a "Please tidy" hanger hangs on the door of every dirty room
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

-- the hanger: a small card on a brass hook, hanging at the door handle's height
local function makeHanger(anchor)
	local bb = Instance.new("BillboardGui")
	bb.Name = "TidyHanger"
	bb.Adornee = anchor
	bb.Size = UDim2.fromOffset(150, 78)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	local swing = UI.new("Frame", { Name = "Swing", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })
	local hook = UI.new("Frame", {
		Name = "Hook", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(4, 16), BackgroundColor3 = Color3.fromRGB(202, 152, 62), BorderSizePixel = 0, Parent = swing,
	})
	UI.corner(hook, 2)
	local card = UI.new("Frame", {
		Name = "Card", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(146, 46), BackgroundColor3 = T.ink, BackgroundTransparency = 0.08, Parent = swing,
	})
	UI.corner(card, 10)
	UI.stroke(card, 2, Color3.fromRGB(255, 170, 70), 0.1)
	UI.icon(card, C.ICONS.clean, 30, { Position = UDim2.fromOffset(7, 8) })
	UI.label(card, "Please tidy", 17, { FontFace = UI.F.heavy, Position = UDim2.fromOffset(41, 0), Size = UDim2.new(1, -49, 1, 0), TextColor3 = T.cream })
	bb.Parent = player:WaitForChild("PlayerGui")
	UI.pop(card, 0.4, 0.4)
	return bb, swing
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
			d.hanger, d.swing = makeHanger(d.anchor)
		elseif not want and d.hanger then
			d.hanger:Destroy()
			d.hanger, d.swing = nil, nil
		end
		if d.swing then
			-- it sways gently on its hook
			d.swing.Rotation = math.sin(t * 2.2) * 4
		end
	end
end)
