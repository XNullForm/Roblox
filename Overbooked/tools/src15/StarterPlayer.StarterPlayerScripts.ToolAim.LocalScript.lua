-- StarterPlayerScripts.ToolAim (round 21): keeps a janitor's mop or broom the right way up.
-- The tool is welded to the hand, so whenever the arm pose turned the hand over, the mop pointed at the ceiling.
-- Here, on each client, the weld is re-aimed every frame: the grip stays in the hand and the head points at the
-- floor a little in front of the feet, whatever the arm is doing. (StaffLook names the tool's first part
-- "Mop<Part>" / "Broom<Part>" and welds it to RightHand; the other parts are welded to that one.)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local tools = {} -- weld -> { root = HumanoidRootPart, hand = RightHand }
local function scan()
	for w, t in pairs(tools) do
		if not w.Parent or not t.root.Parent then tools[w] = nil end
	end
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, h in ipairs(plots:GetChildren()) do
		local folder = h:FindFirstChild("Guests")
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			local hand = m:FindFirstChild("RightHand")
			local root = m:FindFirstChild("HumanoidRootPart")
			if hand and root then
				for _, w in ipairs(hand:GetChildren()) do
					if w:IsA("Weld") and w.Part0 == hand and w.Part1 and not tools[w] then
						local n = w.Part1.Name
						if n:sub(1, 3) == "Mop" or n:sub(1, 5) == "Broom" then tools[w] = { root = root, hand = hand } end
					end
				end
			end
		end
	end
end
task.spawn(function()
	while true do
		scan()
		task.wait(1)
	end
end)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera.CFrame.Position
	for w, t in pairs(tools) do
		local hand, root = t.hand, t.root
		if hand.Parent and (hand.Position - cam).Magnitude < 140 then
			local look = root.CFrame.LookVector
			local floor = root.Position + look * 2.3 - Vector3.new(0, 3, 0)
			local down = floor - hand.Position
			if down.Magnitude > 0.5 then
				down = down.Unit
				local up = -down
				local right = look:Cross(up)
				if right.Magnitude > 0.01 then
					right = right.Unit
					local want = CFrame.fromMatrix(hand.Position, right, up)
					w.C0 = hand.CFrame:ToObjectSpace(want)
					w.C1 = CFrame.new()
				end
			end
		end
	end
end)
