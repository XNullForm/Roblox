import io
cp = "src15/StarterPlayer.StarterPlayerScripts.Client.LocalScript.lua"
c = open(cp, encoding="utf8").read().split("\n")
# Client: HUD block = lines 36..334 (1-based), prompt block from 1236 to the end
hud = open("src15/_hud_block.lua", encoding="utf8").read().rstrip("\n").split("\n")
prompt = open("src15/_prompt_block.lua", encoding="utf8").read().rstrip("\n").split("\n")
assert c[35].startswith('local hud = UI.new("ScreenGui"'), c[35]
assert c[333] == "refreshRooms()", c[333]
assert c[1235].startswith("---------------------------------------------------------------- custom prompts"), c[1235]
out = c[:35] + hud + c[334:1235] + prompt
open(cp, "w", encoding="utf8").write("\n".join(out) + "\n")
print("client", len(out))

bp = "src15/StarterPlayer.StarterPlayerScripts.BuildClient.LocalScript.lua"
b = open(bp, encoding="utf8").read().split("\n")
dock = open("src15/_dock_block.lua", encoding="utf8").read().rstrip("\n").split("\n")
assert b[107].startswith("---------------------------------------------------------------- the bottom dock"), b[107]
end = next(i for i in range(216, 240) if b[i] == "end" and b[i - 1].strip() == "UI.pop(buildBtn, 0.9, 0.35)")
out = b[:107] + dock + b[end + 2:]
s = "\n".join(out)
assert 'local div = barRow:FindFirstChild("Div")' in s
s = s.replace('local div = barRow:FindFirstChild("Div")', 'local div = rowList:FindFirstChild("Div")')
open(bp, "w", encoding="utf8").write(s)
print("build", len(out))
