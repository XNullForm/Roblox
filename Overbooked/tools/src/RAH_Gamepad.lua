-- StarterPlayerScripts.RAH_Gamepad (round 10c): PS5 / Xbox controller glue that doesn't belong to one screen.
-- B closes the topmost panel (UI.closeTopmost: every UI.closeButton registers there), and while a controller is
-- in use a small strip in the bottom-left shows the D-pad shortcuts (UP build, LEFT menu, RIGHT research).
-- Build mode and the minigames bind their own controls at a higher ContextActionService priority.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local RAH = RS:WaitForChild("RAH")
local UI = require(RAH:WaitForChild("UI"))
local T = UI.T

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- B: back out of whatever is on top (a selected button inside a panel first gives up its selection)
CAS:BindActionAtPriority("RAH_PadBack", function(_, state)
	if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if player:GetAttribute("RAH_Building") then return Enum.ContextActionResult.Pass end
	if UI.closeTopmost() then
		GuiService.SelectedObject = nil
		return Enum.ContextActionResult.Sink
	end
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)

-- the shortcut strip
local gui = UI.new("ScreenGui", { Name = "RAH_PadLegend", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Enabled = false, Parent = pgui })
local strip = UI.new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18), Size = UDim2.fromOffset(0, 34),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.ink, BackgroundTransparency = 0.18, Parent = gui,
})
UI.corner(strip, 12)
UI.stroke(strip, 1.5, T.gold, 0.55)
UI.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 12), Parent = strip })
UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = strip })
UI.autoScale(strip, Vector2.new(1280, 720))
local function entry(i, key, text)
	local f = UI.new("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = i, Parent = strip })
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = f })
	local k = UI.new("TextLabel", {
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.gold, Text = key,
		TextSize = 13, FontFace = UI.F.black, TextColor3 = Color3.fromRGB(40, 28, 10), LayoutOrder = 1, Parent = f,
	})
	UI.corner(k, 6)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = k })
	UI.new("TextLabel", {
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = text,
		TextSize = 15, FontFace = UI.F.bold, TextColor3 = T.cream, LayoutOrder = 2, Parent = f,
	})
end
entry(1, "UP", "Build")
entry(2, "LEFT", "Menu")
entry(3, "RIGHT", "Research")
entry(4, "B", "Close")

local function refresh()
	gui.Enabled = UI.gamepad() and player:GetAttribute("RAH_Slot") ~= nil and not player:GetAttribute("RAH_Building")
		and not player:GetAttribute("RAH_MenuOpen") and not player:GetAttribute("RAH_HideUI")
end
UI.PadChanged.Event:Connect(refresh)
for _, a in ipairs({ "RAH_Slot", "RAH_Building", "RAH_MenuOpen", "RAH_HideUI" }) do
	player:GetAttributeChangedSignal(a):Connect(refresh)
end
refresh()
