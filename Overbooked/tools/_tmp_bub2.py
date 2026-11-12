p = "src15/StarterPlayer.StarterPlayerScripts.Bubbles.LocalScript.lua"
s = open(p, encoding="utf8").read()
reps = [
 ('Name = "Bubble", Size = UDim2.fromOffset(340, 250), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.15, 0),\n\t\tLightInfluence = 0,',
  'Name = "Bubble", Size = UDim2.fromOffset(340, 260), SizeOffset = Vector2.new(0, 0.5), StudsOffset = Vector3.new(0, 1.9, 0),\n\t\tAlwaysOnTop = true, LightInfluence = 0,'),
 ("\t\t\tlocal d = (m.bb.Adornee.Position - cpos).Magnitude\n",
  "\t\t\tlocal d = (m.bb.Adornee.Position - cpos).Magnitude\n"
  "\t\t\t-- drawn on top, so hide it while a wall stands between you and them (checked a few times a second)\n"
  "\t\t\tif clock >= (m.nextRay or 0) then\n"
  "\t\t\t\tm.nextRay = clock + 0.2 + math.random() * 0.1\n"
  "\t\t\t\tlocal hidden = blocked(cpos, m.bb.Adornee, model)\n"
  "\t\t\t\tif hidden ~= m.blocked then\n"
  "\t\t\t\t\tm.blocked = hidden\n"
  "\t\t\t\t\tlocal want = hidden and 0 or 1\n"
  "\t\t\t\t\tUI.tween(m.fade, 0.2, { GroupTransparency = 1 - want })\n"
  "\t\t\t\tend\n"
  "\t\t\tend\n"),
 ("local function patienceColor(k)",
  "-- is anything solid (not a person) between the camera and this head?\n"
  "local rayParams = RaycastParams.new()\n"
  "rayParams.FilterType = Enum.RaycastFilterType.Exclude\n"
  "rayParams.IgnoreWater = true\n"
  "local function blocked(from, head, model)\n"
  "\tlocal ignore = { model }\n"
  "\tif player.Character then table.insert(ignore, player.Character) end\n"
  "\tlocal to = head.Position + Vector3.new(0, 1, 0)\n"
  "\tfor _ = 1, 4 do\n"
  "\t\trayParams.FilterDescendantsInstances = ignore\n"
  "\t\tlocal r = workspace:Raycast(from, to - from, rayParams)\n"
  "\t\tif not r then return false end\n"
  "\t\tlocal hit = r.Instance\n"
  "\t\tlocal mdl = hit:FindFirstAncestorOfClass(\"Model\")\n"
  "\t\tif (mdl and mdl:FindFirstChildOfClass(\"Humanoid\")) or hit.Transparency > 0.6 or not hit.CanQuery or (hit:IsA(\"BasePart\") and hit.Size.Magnitude < 3) then\n"
  "\t\t\ttable.insert(ignore, mdl and mdl:FindFirstChildOfClass(\"Humanoid\") and mdl or hit)\n"
  "\t\telse\n"
  "\t\t\treturn true\n"
  "\t\tend\n"
  "\tend\n"
  "\treturn false\n"
  "end\n\n"
  "local function patienceColor(k)"),
]
for a, b in reps:
    assert a in s, a[:80]
    s = s.replace(a, b)
# the root frame becomes a CanvasGroup so the whole stack can fade
a = '\tlocal root = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })\n\tlocal sc = Instance.new("UIScale")\n\tsc.Parent = root\n'
assert a in s
s = s.replace(a, '\tlocal root = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = bb })\n\tm.fade = root\n\tlocal sc = Instance.new("UIScale")\n\tsc.Parent = root\n', 1)
open(p, "w", encoding="utf8").write(s)
print("ok")
