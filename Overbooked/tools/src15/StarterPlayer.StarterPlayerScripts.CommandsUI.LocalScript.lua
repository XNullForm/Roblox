-- StarterPlayerScripts.CommandsUI (round 21): /commands opens a full page that lists every chat command, in groups.
-- The server (ChatCommands) fires Notify "commands"; this page is the list. Close with the X or by clicking outside.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Shared = RS:WaitForChild("Shared")
local UI = require(Shared:WaitForChild("UI"))
local Notify = Shared:WaitForChild("Remotes"):WaitForChild("Notify")
local T = UI.T

local GROUPS = {
	{ "Money and progress", {
		{ "/cash 5000", "Adds cash (any amount)" },
		{ "/mmoney", "Infinite money on or off" },
		{ "/level", "The hotel goes up one level" },
		{ "/mlevel", "The hotel jumps to the top level" },
		{ "/research", "Unlocks every research" },
		{ "/upgrades", "Buys every upgrade to the top" },
		{ "/preset", "A maxed-out hotel: rooms, beds, staff, restaurant, decor" },
	} },
	{ "Hotel look and story", {
		{ "/look 0", "Sets the hotel's look: 0 run-down, 1 patched, 2 fresh, 3 charming, 4 grand" },
		{ "/intro", "Plays the opening story again" },
	} },
	{ "Seasons", {
		{ "/seasonspr", "Spring" }, { "/seasonsum", "Summer" }, { "/seasonal", "Fall" }, { "/seasonwin", "Winter" },
		{ "/seasonauto", "Back to the calendar" },
	} },
	{ "Weather", {
		{ "/weatherclear", "Clear sky" }, { "/weathercloud", "Cloudy" }, { "/weatherfog", "Fog" },
		{ "/weatherrain", "Rain" }, { "/weatherstorm", "Thunderstorm" }, { "/weathersnow", "Snow" },
	} },
	{ "Special guests (the next arrival)", {
		{ "/eventbaby", "A family with a baby" }, { "/eventaccess", "A guest who needs an accessible room" }, { "/eventpet", "A guest with a pet" },
		{ "/eventallnighter", "An all-nighter" }, { "/eventbirthday", "A birthday" }, { "/eventbusiness", "A business trip" },
		{ "/eventhoneymoon", "Honeymooners" }, { "/eventsick", "A sick guest" }, { "/eventinspector", "The inspector" },
		{ "/eventtour", "A tour group" }, { "/eventcelebrity", "A celebrity" }, { "/eventrockstar", "Star guest: the rock star" },
		{ "/eventroyal", "Star guest: royalty" }, { "/eventcritic", "Star guest: the critic" }, { "/eventmystery", "Star guest: the mystery guest" },
		{ "/eventtycoon", "Star guest: the tycoon" },
	} },
	{ "Players", {
		{ "/goto name", "Teleport to a player" },
		{ "/bring name", "Bring a player to you" },
		{ "/commands", "This page" },
	} },
}

local gui, panel, wrap, dim
local function build()
	gui = UI.new("ScreenGui", { Name = "Commands", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 45, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	dim = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = gui })
	wrap = UI.new("Frame", { Size = UDim2.fromOffset(980, 720), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	UI.autoScale(wrap)
	local close
	local body
	panel, body = UI.panel(wrap, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), { title = "Commands", subtitle = "Type these in chat. Most need admin (the owner, or anyone in Studio)", onClose = function() close() end })
	close = function()
		UI.close(panel, function() gui.Enabled = false end)
	end
	dim.Activated:Connect(function() close() end)
	local list = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, -36, 1, -84), Position = UDim2.fromOffset(18, 74), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, ScrollBarImageColor3 = T.muted, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body,
	})
	UI.list(list, nil, 6)
	UI.pad(list, 0, 2, 10, 8)
	local order = 0
	for _, g in ipairs(GROUPS) do
		order += 1
		UI.label(list, string.upper(g[1]), 13, { FontFace = UI.F.heavy, TextColor3 = T.brand, Size = UDim2.new(1, 0, 0, 26), TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order })
		-- two columns of rows
		local grid = UI.new("Frame", { Size = UDim2.new(1, 0, 0, math.ceil(#g[2] / 2) * 42), BackgroundTransparency = 1, LayoutOrder = order + 0.5, Parent = list })
		order += 1
		for i, c in ipairs(g[2]) do
			local colN, rowN = (i - 1) % 2, math.floor((i - 1) / 2)
			local r = UI.new("Frame", { Size = UDim2.new(0.5, -4, 0, 38), Position = UDim2.new(colN * 0.5, colN * 4, 0, rowN * 42), BackgroundColor3 = T.ink2, Parent = grid })
			UI.corner(r, 8)
			local cmd = UI.new("TextLabel", { Text = c[1], TextSize = 15, FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold), TextColor3 = T.cream, BackgroundColor3 = T.ink3, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), Position = UDim2.fromOffset(6, 6), Parent = r })
			UI.corner(cmd, 6)
			UI.pad(cmd, 8, 0, 8, 0)
			UI.label(r, c[2], 14, { FontFace = UI.F.body, TextColor3 = T.muted, Position = UDim2.fromOffset(176, 0), Size = UDim2.new(1, -184, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		end
	end
end

Notify.OnClientEvent:Connect(function(kind)
	if kind ~= "commands" then return end
	if not gui then build() end
	gui.Enabled = true
	UI.open(panel)
end)
