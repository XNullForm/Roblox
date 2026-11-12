p = "src15/StarterPlayer.StarterPlayerScripts.Bubbles.LocalScript.lua"
s = open(p, encoding="utf8").read()
parts = open("src15/_bub_v2.lua", encoding="utf8").read().split("--@@")
P = {}
for chunk in parts[1:]:
    name, _, body = chunk.partition("\n")
    P[name.strip()] = body

# 1. header comment + helpers (measure, speech bubble maker) before `local marks = {}`
a = s.index("local marks = {} -- model -> m")
s = s[:a] + P["HELPERS"] + "\n" + s[a:]

# 2. build(): tag, disc and speech construction
a = s.index("\t-- staff tag ------------------------------------------------------------")
b = s.index("\tm.bb, m.sc, m.tag, m.discSlot")
s = s[:a] + P["BUILD"] + s[b:]

# 3. refreshTag colours
a = s.index("\t\tlocal col = model:GetAttribute(\"BRoleColor\") or T.brand")
b = s.index("\tlocal function refreshStatus()")
s = s[:a] + P["TAGCOL"] + "\tend\n" + s[b:]

# 4. say(): fitting and the name chip
a = s.index("\t\twho.Text = first")
b = s.index("\t\tsayText.Text = line")
s = s[:a] + P["SAYFIT"] + s[b:]

# 5. player chat bubbles use the same maker
a = s.index("\tif not rec or not rec.bb.Parent then")
b = s.index("\trec.n += 1")
s = s[:a] + P["CHATREC"] + s[b:]
a = s.index("\tlocal one = TextService:GetTextSize(shown, 15")
b = s.index("\trec.txt.Text = shown")
s = s[:a] + "\tlocal w, h = fitBubble(shown)\n\trec.slot.Size = UDim2.fromOffset(w, h)\n" + s[b:]

# 6. dots bounce
s = s.replace("dd.Position = UDim2.fromOffset((i - 1) * 16, 1 - math.max(0, math.sin(clock * 9 - i * 0.9)) * 5)",
              "dd.Position = UDim2.fromOffset((i - 1) * 16, 2 - math.max(0, math.sin(clock * 9 - i * 0.9)) * 6)")
s = s.replace("-- StarterPlayerScripts.Bubbles (round 15, 2026-11-09): what floats over people's heads.",
              "-- StarterPlayerScripts.Bubbles (round 15 v2, 2026-11-09): what floats over people's heads (glossy style).")
open(p, "w", encoding="utf8").write(s)
print("ok", len(s.split("\n")))
