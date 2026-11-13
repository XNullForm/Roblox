-- StarterPlayerScripts.EventBanner (round 35): today's world event (ServerScriptService.WorldEvents).
-- When Shared attribute Event changes, a chapter-look card drops in at the top: the event's 3D icon over its edge,
-- TODAY IN HARBOUR VIEW, the name, what it means and what it does to guests and prices. After a few seconds it
-- folds into a small pill under the clock (top right) that stays for the day; tap the pill to read it again.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local ICON = require(Shared:WaitForChild("Config")).ICONS
local T = UI.T
local player = Players.LocalPlayer

local gui = UI.new("ScreenGui", { Name = "EventBanner", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 14, Parent = player:WaitForChild("PlayerGui") })

-- the card
local wrap = UI.new("Frame", { Size = UDim2.fromOffset(500, 132), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), BackgroundTransparency = 1, Visible = false, Parent = gui })
UI.autoScale(wrap)
local card = UI.new("Frame", { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(40, 0), Parent = wrap })
UI.shadow(card, { drop = 5, transparency = 0.7 })
card.BackgroundColor3 = T.ink
UI.corner(card, 20)
UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(244, 247, 250)), Parent = card })
UI.rim(card, Color3.fromRGB(232, 237, 244), 2.5)
local icon = UI.icon(wrap, ICON.ev_party, 96, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(44, 62), BackgroundTransparency = 1, ZIndex = 3 })
UI.label(card, "TODAY IN HARBOUR VIEW", 12, { FontFace = UI.F.black, TextColor3 = T.brand, Position = UDim2.fromOffset(58, 16), Size = UDim2.new(1, -76, 0, 14) })
local title = UI.label(card, "", 24, { FontFace = UI.F.black, TextColor3 = T.cream, Position = UDim2.fromOffset(58, 32), Size = UDim2.new(1, -76, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd })
local body = UI.label(card, "", 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(58, 62), Size = UDim2.new(1, -76, 0, 34), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
local fx = UI.label(card, "", 13, { FontFace = UI.F.black, TextColor3 = T.greenDk, Position = UDim2.fromOffset(58, 100), Size = UDim2.new(1, -76, 0, 18) })

-- the pill under the clock
local pill = UI.new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 112), Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.ink, Visible = false, Parent = gui })
UI.corner(pill, 18)
UI.rim(pill, Color3.fromRGB(232, 237, 244), 2)
UI.pad(pill, 6, 0, 14, 0)
UI.list(pill, Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center)
local pillIcon = UI.icon(pill, ICON.ev_party, 28, { BackgroundTransparency = 1, LayoutOrder = 1 })
local pillText = UI.label(pill, "", 14, { FontFace = UI.F.black, TextColor3 = T.cream, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), LayoutOrder = 2 })

local function pct(k, word)
	local p = math.floor((k - 1) * 100 + 0.5)
	if p == 0 then return nil end
	return (p > 0 and "+" or "") .. p .. "% " .. word
end

local showN = 0
local function show()
	local id = Shared:GetAttribute("Event")
	showN += 1
	local n = showN
	if not id then
		wrap.Visible, pill.Visible = false, false
		return
	end
	local img = ICON[Shared:GetAttribute("EventIcon") or ""] or ICON.star
	icon.Image, pillIcon.Image = img, img
	title.Text = Shared:GetAttribute("EventName") or ""
	pillText.Text = title.Text
	body.Text = Shared:GetAttribute("EventText") or ""
	local bits = {}
	table.insert(bits, pct(Shared:GetAttribute("EventDemand") or 1, "guests"))
	table.insert(bits, pct(Shared:GetAttribute("EventPrice") or 1, "room prices"))
	fx.Text = table.concat(bits, "   ")
	fx.TextColor3 = (Shared:GetAttribute("EventDemand") or 1) < 1 and T.red or T.greenDk
	pill.Visible = false
	wrap.Visible = true
	UI.open(wrap, { from = 0.8, rise = -20 })
	UI.pop(icon, 0.6, 0.45)
	UI.sound("Fanfare")
	task.delay(8, function()
		if showN ~= n then return end
		UI.close(wrap, function()
			if showN ~= n then return end
			wrap.Visible = false
			pill.Visible = true
			UI.pop(pill, 0.7, 0.3)
		end)
	end)
end
pill.Activated:Connect(function() UI.sound("Click") show() end)
Shared:GetAttributeChangedSignal("Event"):Connect(show)
if Shared:GetAttribute("Event") then task.delay(6, show) end
-- hidden while building or talking (the HUD steps aside then too)
local function vis()
	gui.Enabled = not player:GetAttribute("Building") and not player:GetAttribute("InTalk") and player:GetAttribute("Slot") ~= nil
end
for _, a in ipairs({ "Building", "InTalk", "Slot" }) do player:GetAttributeChangedSignal(a):Connect(vis) end
vis()
