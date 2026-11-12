"""Splits DevTools.Pull batches (saved tool results) into live15/<Full.Name>.<Class>.lua"""
import os, re, glob, json, sys, time
TR = r"C:\Users\Nickp\.claude\projects\C--Obsidian-Claude\cdd4aed2-01a5-4d01-91a2-07131ccbbf02\tool-results"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "live15")
os.makedirs(OUT, exist_ok=True)
since = float(sys.argv[1]) if len(sys.argv) > 1 else time.time() - 3600
parts = {}
for f in sorted(glob.glob(os.path.join(TR, "*")), key=os.path.getmtime):
    if os.path.getmtime(f) < since: continue
    try: s = open(f, encoding="utf8").read()
    except Exception: continue
    if "@@@FILE " not in s: continue
    if f.endswith(".json"):
        try: s = "".join(x.get("text", "") for x in json.loads(s))
        except Exception: pass
    for m in re.finditer(r"@@@FILE ([^|\n]+)\|(\w+)\|(\d+)/(\d+)\n(.*?)\n@@@END", s, re.S):
        name, cls, i, n, body = m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), m.group(5)
        parts.setdefault((name, cls, n), {})[i] = body
missing = []
for (name, cls, n), d in sorted(parts.items()):
    if len(d) < n:
        missing.append("%s (%d/%d)" % (name, len(d), n)); continue
    open(os.path.join(OUT, "%s.%s.lua" % (name, cls)), "w", encoding="utf8", newline="\n").write("".join(d[i] for i in range(1, n + 1)))
print(len(parts), "scripts;", "missing:", missing)
