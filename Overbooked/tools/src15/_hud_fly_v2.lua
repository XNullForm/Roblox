local function flyDelta(d)
	local up = d > 0
	local l = UI.chip(flyLayer, (up and "+" or "-") .. money(math.abs(d)), up and T.green or T.red, { TextSize = 18, Size = UDim2.fromOffset(0, 30), Position = UDim2.fromOffset(0, -6), ZIndex = 9 })
	UI.pop(l, 0.4, 0.4)
	if up then UI.sparkles(l, 3, T.white, 1.4) end
	UI.tween(l, 1.3, { Position = UDim2.fromOffset(0, 30) }, Enum.EasingStyle.Quint)
	UI.tween(l, 0.4, { TextTransparency = 1, BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1)
	for _, st in ipairs(l:GetChildren()) do
		if st:IsA("UIStroke") then UI.tween(st, 0.4, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 1) end
	end
	task.delay(1.45, function() l:Destroy() end)
end
