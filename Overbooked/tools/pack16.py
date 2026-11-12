"""Pack mesh JSONs (export/<Prop>_<group>.json + manifests) into PNGs for DevTools.ImagePack.
  python pack16.py <tag> Prop1 Prop2 ...   -> export/_<tag>_<n>.png (each at most ~2.9 MB of JSON)"""
import json, os, sys, math
from PIL import Image
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
tag, names = sys.argv[1], sys.argv[2:]
packs, cur, size = [], {}, 0
for n in names:
    man = json.load(open(os.path.join(OUT, n + ".manifest.json")))
    items = {n + ".manifest": man}
    for e in man:
        items[e["file"]] = json.load(open(os.path.join(OUT, e["file"] + ".json")))
    s = len(json.dumps(items, separators=(",", ":")))
    if cur and size + s > 2900000:
        packs.append(cur); cur, size = {}, 0
    cur.update(items); size += s
packs.append(cur)
for i, p in enumerate(packs):
    b = json.dumps(p, separators=(",", ":")).encode()
    b = len(b).to_bytes(4, "big") + b
    side = math.ceil(math.sqrt(len(b) / 3))
    b += bytes(side * side * 3 - len(b))
    Image.frombytes("RGB", (side, side), b).save(os.path.join(OUT, "_%s_%d.png" % (tag, i)))
    print("_%s_%d.png" % (tag, i), side, [k for k in p if k.endswith(".manifest")])
