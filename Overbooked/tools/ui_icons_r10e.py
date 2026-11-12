"""Round 10e icons (phone, shop, run), same chunky style as ui_icons.py.
python ui_icons_r10e.py  ->  ui/<name>.png + ui/_sheet_r10e.png
"""
import os, math
from PIL import Image
from ui_icons import Icon, c, OUT


def phone():
    i = Icon()
    i.add("rrect", (66, 16, 190, 240, 26), c("#3A4466"), c("#1E2440"))
    i.add("rrect", (78, 40, 178, 206, 10), c("#8FD8FF"), c("#3C8AE0"), gloss=False)
    for k, (x, y) in enumerate(((96, 62), (128, 62), (160, 62), (96, 96), (128, 96), (160, 96))):
        col = ("#FFD24A", "#9AF0B0", "#FF9AB0", "#FFFFFF", "#C8B0FF", "#FFB070")[k]
        i.add("rrect", (x - 12, y - 12, x + 12, y + 12, 6), c(col), c("#5A6A8A"), gloss=False)
    i.add("rrect", (90, 132, 166, 146, 6), c("#FFFFFF"), c("#C8D8F0"), gloss=False)
    i.add("rrect", (90, 156, 146, 170, 6), c("#E4F0FF"), c("#C8D8F0"), gloss=False)
    i.add("rrect", (108, 216, 148, 228, 6), c("#8A96B8"), c("#5A6488"), gloss=False)
    i.add("rrect", (110, 24, 146, 32, 4), c("#1A2038"), c("#10142A"), gloss=False)
    return i


def shop():
    i = Icon()
    i.add("line", ([(92, 92), (92, 58), (128, 30), (164, 58), (164, 92)], 14), c("#C88A2A"), gloss=False)
    i.add("poly", [(40, 84), (216, 84), (200, 236), (56, 236)], c("#FFE48A"), c("#D69A2A"))
    i.add("rrect", (40, 84, 216, 112, 8), c("#FFD24A"), c("#C88A2A"), gloss=False)
    pts = []
    for k in range(8):
        a = -math.pi / 2 + k * math.pi / 4
        r = 46 if k % 2 == 0 else 18
        pts.append((128 + math.cos(a) * r, 170 + math.sin(a) * r))
    i.add("poly", pts, c("#FFFFFF"), c("#FFF2C0"), gloss=False)
    return i


def run():
    i = Icon()
    i.add("ellipse", (24, 24, 232, 232), c("#FFC27A"), c("#D86A28"))
    for k, x in enumerate((70, 112, 154)):
        i.add("line", ([(x, 78), (x + 42, 128), (x, 178)], 22), c("#FFFFFF") if k == 2 else c("#FFE8D0"), gloss=False)
    return i


ALL = {"phone": phone, "shop": shop, "run": run}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render(n)
    names = list(ALL)
    sheet = Image.new("RGBA", (len(names) * 160, 160), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), (k * 160 + 5, 5))
    sheet.save(os.path.join(OUT, "_sheet_r10e.png"))
    print("ok", len(names))
