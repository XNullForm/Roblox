p = "src15/_prompt_block.lua"
s = open(p, encoding="utf8").read()
end = s.index("-- round 12: the desk buttons on guests")
s = open("src15/_prompt_top_v2.lua", encoding="utf8").read() + "\n" + s[end:]
reps = [
 ("\tif math.abs(o.x - e.x) < 280 * PS and math.abs((o.y - o.lift * 66 * PS) - (e.y - lift * 66 * PS)) < 60 * PS then lift = o.lift + 1 end",
  "\tif math.abs(o.x - e.x) < 300 * PS and math.abs((o.y - o.lift * 76 * PS) - (e.y - lift * 76 * PS)) < 70 * PS then lift = o.lift + 1 end"),
 ("local want = Vector2.new(0, lift * 0.46)", "local want = Vector2.new(0, lift * 0.46)"),
 ("\ts.card.BackgroundColor3 = s.cols[1]:Lerp(Color3.new(1, 1, 1), 0.55)\n\tUI.tween(s.card, 0.45, { BackgroundColor3 = T.white })",
  "\ts.card.BackgroundColor3 = s.cols[1]:Lerp(Color3.new(1, 1, 1), 0.5)\n\tUI.tween(s.card, 0.5, { BackgroundColor3 = T.white })\n\tif s.shine then s.shine(0.45) end\n\tUI.sparkles(s.wrap, 5, s.cols[1], 1.1)"),
]
for a, b in reps:
    assert a in s, a
    s = s.replace(a, b)
open(p, "w", encoding="utf8").write(s)
print("ok", len(s.split("\n")))
