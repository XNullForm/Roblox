"""Applies src15/_ui21_parts.lua (round 21 flat style) to the Shared.UI mirror in src15."""
import re, os
H = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src15")
P = os.path.join(H, "ReplicatedStorage.Shared.UI.ModuleScript.lua")
src = open(P, encoding="utf8").read()
parts = open(os.path.join(H, "_ui21_parts.lua"), encoding="utf8").read()
tok = parts.split("--@@TOKENS\n")[1].split("--@@KIND\n")[0]
kind = parts.split("--@@KIND\n")[1].split("--@@FUNCS\n")[0]
funcs = parts.split("--@@FUNCS\n")[1]

a = src.index("UI.T = {")
b = src.index("local T = UI.T\n") + len("local T = UI.T\n")
src = src[:a] + tok + src[b:]
a = src.index("UI.KIND = {")
b = src.index("\n}\n", src.index("UI.F = {")) + 3
src = src[:a] + kind + src[b:]
src = src.replace("local toastGui, toastList\nfunction UI.toast", "function UI.toast")

# split the new functions (each keeps the comment / code lines above it)
chunks, cur = [], []
for line in funcs.split("\n"):
    cur.append(line)
    if line == "end":
        chunks.append("\n".join(cur).strip("\n") + "\n")
        cur = []
n = 0
for ch in chunks:
    m = re.search(r"(?m)^function UI\.(\w+)\(", ch)
    if not m:
        continue
    name = m.group(1)
    pat = re.compile(r"(?ms)(?:^--[^\n]*\n)*^function UI\.%s\(.*?^end\n" % name)
    mm = pat.search(src)
    assert mm, name
    src = src[:mm.start()] + ch.rstrip("\n") + "\n" + src[mm.end():]
    n += 1
head = src.split("\n", 1)
src = ("-- ReplicatedStorage.Shared.UI (round 21, 2026-11-12): the shared look and motion of every screen.\n"
       "-- \"Clean\": flat white cards with hairlines and soft shadows, one blue accent, Builder Sans throughout, no gloss,\n"
       "-- rims or sparkles; the HUD (top bar, bottom bar, toasts, prompts) is dark glass (T.hud). UI.G holds the flat white\n"
       "-- glyph set. The API is unchanged from round 15, so every screen follows.\n") + head[1]
open(P, "w", encoding="utf8").write(src)
print("replaced", n, "functions;", len(src), "chars")
