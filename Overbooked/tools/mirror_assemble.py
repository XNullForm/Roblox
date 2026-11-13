import json, re, sys, os
TR = sys.argv[1]; M = sys.argv[2]; files = sys.argv[3:]
buf = ""
for f in files:
    raw = open(os.path.join(TR, f), encoding="utf-8").read()
    if f.endswith(".json"):
        raw = "".join(x["text"] for x in json.loads(raw) if x.get("type") == "text")
    i = raw.index("@@@CHUNK"); i = raw.index("\n", i) + 1
    j = raw.rindex("\n@@@CHUNKEND")
    buf += raw[i:j]
n = 0
for m in re.finditer(r"@@@FILE (\S+)\n(.*?)\n@@@END\n", buf, re.S):
    open(os.path.join(M, m.group(1)), "w", encoding="utf-8", newline="\n").write(m.group(2))
    print(m.group(1), len(m.group(2))); n += 1
print("files", n, "buf", len(buf))
