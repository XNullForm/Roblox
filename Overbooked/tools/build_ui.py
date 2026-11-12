"""Round 15: assembles Shared.UI from the new parts (src15/_ui_parts.lua) and the unchanged blocks of the
old module (src15/_UI_old.lua, by line range)."""
import re, os
HERE = os.path.dirname(os.path.abspath(__file__))
old = open(os.path.join(HERE, "src15/_UI_old.lua"), encoding="utf8").read().split("\n")
def L(a, b): return "\n".join(old[a - 1:b])
parts = {}
cur = None
for line in open(os.path.join(HERE, "src15/_ui_parts.lua"), encoding="utf8").read().split("\n"):
    m = re.match(r"^--@@(\w+)$", line)
    if m:
        cur = m.group(1); parts[cur] = []
    elif cur:
        parts[cur].append(line)
P = {k: "\n".join(v) for k, v in parts.items()}
NL, TB = "\n", "\t"

tabs = L(677, 818)
for a, b in [
    ("UI.corner(b, 12)" + NL + TB * 2 + "UI.pad(b, 14, 0, 14, 0)", "UI.corner(b, 12)" + NL + TB * 2 + "UI.sheen(b, 0.8)" + NL + TB * 2 + "UI.pad(b, 14, 0, 14, 0)"),
    ("TextSize = opts.textSize or 17, FontFace = UI.F.heavy", "TextSize = math.floor((opts.textSize or 17) * 1.06 + 0.5), FontFace = UI.F.display"),
    ("if tr then tr.Transparency = on and 0 or 1 end", "if tr then tr.Transparency = on and 0 or 1 tr.Color = T.brandDk tr.Thickness = 2.5 end"),
]:
    assert a in tabs, a
    tabs = tabs.replace(a, b)

slider = L(885, 931)
for a, b in [
    ("UI.corner(track, 5)" + NL + TB + "UI.stroke(track, 2, T.outline, 0)",
     "UI.corner(track, 5)" + NL + TB + 'UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(190, 184, 216), Color3.new(1, 1, 1)), Parent = track })' + NL + TB + "UI.rim(track, Color3.fromRGB(198, 190, 238), 1.5)"),
    ("UI.corner(fill, 3)", "UI.corner(fill, 5)" + NL + TB + "UI.sheen(fill)"),
    ("UI.corner(knob, 12)" + NL + TB + "UI.stroke(knob, 2.5, T.outline)",
     "UI.corner(knob, 12)" + NL + TB + 'UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 218, 240)), Parent = knob })' + NL + TB + "UI.rim(knob, T.brandDk, 3)" + NL + TB + "UI.animate(knob, { hover = 1.15, sound = false })"),
]:
    assert a in slider, a
    slider = slider.replace(a, b)

tooltip = L(933, 966)
for a, b in [
    ("TextSize = 15, FontFace = UI.F.bold, BackgroundColor3 = T.ink, BackgroundTransparency = 0.05,", "TextSize = 15, FontFace = UI.F.heavy, BackgroundColor3 = T.night, BackgroundTransparency = 0.04, TextColor3 = T.white,"),
    (TB * 3 + "UI.stroke(tipLabel, 2, T.outline, 0)" + NL, TB * 3 + "UI.rim(tipLabel, T.nightDk, 2)" + NL),
]:
    assert a in tooltip, a
    tooltip = tooltip.replace(a, b)

animate = L(477, 498)
ring = L(195, 281)
RAW = 'local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border s.Thickness = th s.Color = col s.Parent = c'
assert "local s = UI.stroke(c, th, col, 0)" in ring
ring = ring.replace("local s = UI.stroke(c, th, col, 0)", RAW)
out = "\n".join([
    P["HEAD"], L(39, 91), P["KIND"], L(119, 120), "", "---------------------------------------------------------------- building blocks", "",
    L(124, 148), "", L(150, 155), P["STROKES"], ring, "", L(283, 397), "", P["PANEL"], animate, P["BUTTON"], L(609, 620), P["ICONBTN"],
    "---------------------------------------------------------------- tabs, toggles, sliders, segments", "",
    tabs, P["TOGGLE"], slider, "", tooltip, "", L(968, 996), "", P["TOAST"],
])
open(os.path.join(HERE, "src15/ReplicatedStorage.Shared.UI.ModuleScript.lua"), "w", encoding="utf8").write(out)
print(len(out.split("\n")), "lines")
