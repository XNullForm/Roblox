"""Round 15: push Luau sources into Studio as an image pack.
python push.py [files...]   (default: every src15/*.lua changed since the last push)
File name = <full.dotted.path>.<ClassName>.lua, e.g. ReplicatedStorage.Shared.UI.ModuleScript.lua
Writes export/code_<n>.png (served on 8790) and prints the URL(s); then in Studio (Edit):
  require(game.ServerStorage.DevTools.ImagePack:Clone()).push(<assetId>)
"""
import sys, os, json, math, time, glob
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src15")
OUT = os.path.join(HERE, "export")
STAMP = os.path.join(SRC, ".pushed")
files = [a for a in sys.argv[1:]]
if not files:
    last = os.path.getmtime(STAMP) if os.path.exists(STAMP) else 0
    files = [f for f in glob.glob(os.path.join(SRC, "*.lua")) if os.path.getmtime(f) > last and not os.path.basename(f).startswith("_")]
else:
    files = [f if os.path.exists(f) else os.path.join(SRC, f) for f in files]
if not files:
    print("nothing to push"); sys.exit()
data = {}
for f in files:
    key = os.path.basename(f)[:-4]
    s = open(f, encoding="utf8").read()
    if s.startswith("\ufeff"): s = s[1:]
    data[key] = s
raw = json.dumps(data).encode("utf8")
n = int(time.time()) % 1000000
parts = [raw]
if len(raw) > 2_900_000:
    # split per file
    parts, cur = [], {}
    for k, v in data.items():
        cur[k] = v
        if len(json.dumps(cur)) > 2_000_000:
            parts.append(json.dumps(cur).encode("utf8")); cur = {}
    if cur: parts.append(json.dumps(cur).encode("utf8"))
for i, p in enumerate(parts):
    b = len(p).to_bytes(4, "big") + p
    side = max(16, math.ceil(math.sqrt(len(b) / 3)))
    b = b + bytes(side * side * 3 - len(b))
    name = "code_%d_%d.png" % (n, i)
    Image.frombytes("RGB", (side, side), b).save(os.path.join(OUT, name))
    print("http://127.0.0.1:8790/" + name, side, len(p))
print("files:", ", ".join(sorted(data)))
open(STAMP, "w").write(str(time.time()))
