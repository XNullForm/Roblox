-- StarterPlayerScripts.RAH_Props: little local motion for guest event props (RAH_GuestEvents), on this screen only.
-- Dogs (models with attribute Bob) trot while their owner walks and sniff around while they stand;
-- balloons sway. Only the welds' C0 change, locally; the server never touches them after it builds them.
local RunService = game:GetService("RunService")
local PLOTS = workspace:WaitForChild("Plots")

local base = setmetatable({}, { __mode = "k" }) -- weld -> its built C0
local list = {}
local scanT = 0

local function rescan()
	table.clear(list)
	for _, plot in ipairs(PLOTS:GetChildren()) do
		local guests = plot:FindFirstChild("Guests")
		if guests then
			for _, g in ipairs(guests:GetChildren()) do
				local root = g:FindFirstChild("HumanoidRootPart")
				for _, c in ipairs(g:GetChildren()) do
					local kind = c.Name == "EventProp_Dog" and "dog" or c.Name == "EventProp_Balloon" and "balloon" or nil
					local pp = kind and c.PrimaryPart
					local w = pp and pp:FindFirstChildOfClass("Weld")
					if w and root then
						if not base[w] then base[w] = w.C0 end
						table.insert(list, { w = w, kind = kind, root = root, seed = (#list + 1) * 1.7 })
					end
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	scanT -= dt
	if scanT <= 0 then
		scanT = 0.5
		rescan()
	end
	local t = os.clock()
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, e in ipairs(list) do
		local w, b = e.w, base[e.w]
		if w.Parent and b and (e.root.Position - cam).Magnitude < 140 then
			if e.kind == "dog" then
				local v = e.root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				if speed > 1 then
					local ph = t * (8 + speed * 0.5)
					w.C0 = b * CFrame.new(0, math.abs(math.sin(ph)) * 0.22, 0) * CFrame.Angles(math.sin(ph) * 0.06, 0, math.sin(ph * 0.5) * 0.05)
				else
					local s = t * 1.3 + e.seed
					w.C0 = b * CFrame.new(0, math.sin(t * 3) * 0.02, 0) * CFrame.Angles(math.sin(s) * 0.12 - 0.05, math.sin(s * 0.7) * 0.35, 0)
				end
			else
				local s = t * 1.1 + e.seed
				w.C0 = b * CFrame.new(math.sin(s) * 0.35, math.sin(s * 1.7) * 0.15, math.cos(s * 0.8) * 0.3)
			end
		end
	end
end)
