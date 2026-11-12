-- ServerScriptService.HotelSkin (round 16c): keeps every hotel in its resort colours (see ServerStorage.HotelSkin).
local Skin = require(game.ServerStorage:WaitForChild("HotelSkin"))

local function hook(h)
	if h:IsA("Model") or h:IsA("Folder") then Skin.watch(h) end
end
local template = workspace:FindFirstChild("Hotel")
if template then hook(template) end
local plots = workspace:WaitForChild("Plots")
for _, h in ipairs(plots:GetChildren()) do hook(h) end
plots.ChildAdded:Connect(hook)
workspace.ChildAdded:Connect(function(c)
	if c.Name == "Hotel" then hook(c) end
end)
