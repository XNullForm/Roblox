p = "src15/_hud_block.lua"
s = open(p, encoding="utf8").read()
start = s.index("-- round 15 (2026-11-09): the HUD is three white cards")
end = s.index("local shownStars = -1")
new = open("src15/_hud_top_v2.lua", encoding="utf8").read()
s = s[:start] + new + s[end:]
reps = [
 ("UI.tween(starClips[i], 0.6, { Size = UDim2.fromOffset(18 * k, 18) }", "UI.tween(starClips[i], 0.6, { Size = UDim2.fromOffset(STAR * k, STAR) }"),
 ("if up then UI.pop(rateSlot, 1.15) end", "if up then UI.pop(rateSlot, 1.15) UI.sparkles(rateSlot, 4, T.sun, 1.2) end"),
 ("levelNum.TextSize = lv >= 100 and 20 or 30", "levelNum.TextSize = lv >= 100 and 26 or 36"),
 ("\t\tlvTile.Rotation = -180\n\t\tUI.tween(lvTile, 0.8, { Rotation = 0 }, Enum.EasingStyle.Back)\n\t\tUI.pop(lvTile, 1.4, 0.5)",
  "\t\tlvTile.Rotation = -180\n\t\tUI.tween(lvTile, 0.8, { Rotation = 0 }, Enum.EasingStyle.Back)\n\t\tUI.pop(lvTile, 1.4, 0.5)\n\t\tlocal rays = UI.rays(lvHolder, 200, T.sun, { ImageTransparency = 0.2 })\n\t\tUI.sparkles(lvHolder, 8, T.sun, 1.6)\n\t\ttask.delay(2.2, function() UI.tween(rays, 0.5, { ImageTransparency = 1 }) task.wait(0.5) rays:Destroy() end)"),
 ("UI.tween(skyTile, 0.6, { BackgroundColor3 = night and T.night or ((w == \"rain\" or w == \"storm\" or w == \"fog\" or w == \"cloudy\") and Color3.fromRGB(120, 136, 170) or T.blue) })",
  "local sky = night and Color3.fromRGB(78, 64, 170) or ((w == \"rain\" or w == \"storm\" or w == \"fog\" or w == \"cloudy\") and Color3.fromRGB(130, 146, 184) or T.blue)\n\t\tUI.tween(skyTile, 0.6, { BackgroundColor3 = sky })\n\t\tif skyTile:FindFirstChild(\"Rim\") then UI.tween(skyTile.Rim, 0.6, { Color = UI.shade(sky, -0.4) }) end"),
]
for a, b in reps:
    assert a in s, a
    s = s.replace(a, b)
a = s.index("local function flyDelta(d)")
b = s.index("player:GetAttributeChangedSignal(\"Cash\")")
s = s[:a] + open("src15/_hud_fly_v2.lua", encoding="utf8").read() + s[b:]
open(p, "w", encoding="utf8").write(s)
print("ok", len(s.split("\n")))
