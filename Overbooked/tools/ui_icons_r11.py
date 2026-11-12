"""Round 11 icons (repairs, luggage, lost & found, breakdowns, hotel grade), same chunky style as ui_icons.py.
python ui_icons_r11.py  ->  ui/<name>.png + ui/_sheet_r11.png
"""
import os, math
from PIL import Image
from ui_icons import Icon, c, OUT


def wrench():
    i = Icon()
    # handle on a diagonal, an open jaw at the top right
    i.add("line", ([(62, 194), (150, 106)], 34), c("#C8D0E0"), gloss=False)
    i.add("line", ([(62, 194), (150, 106)], 22), c("#F0F4FA"), gloss=False)
    i.add("ellipse", (126, 40, 222, 136), c("#DDE3EE"), c("#7A86A0"))
    i.add("poly", [(168, 40), (222, 40), (222, 94), (186, 94), (168, 76)], c("#2A3048"), c("#2A3048"), gloss=False)
    i.add("ellipse", (40, 172, 84, 216), c("#FFB24A"), c("#C86A1A"))
    return i


def suitcase():
    i = Icon()
    i.add("rrect", (96, 36, 160, 70, 12), c("#5A4030"), c("#3A2818"), gloss=False)
    i.add("rrect", (110, 46, 146, 70, 6), c("#1E2440"), c("#1E2440"), gloss=False)
    i.add("rrect", (40, 64, 216, 220, 22), c("#FF8A5A"), c("#C84A2A"))
    for x in (84, 172):
        i.add("rrect", (x - 7, 64, x + 7, 220, 4), c("#FFD8A0"), c("#D69A5A"), gloss=False)
    i.add("rrect", (112, 132, 144, 152, 6), c("#FFD24A"), c("#C88A2A"), gloss=False)
    return i


def teddy():
    i = Icon()
    for x in (66, 190):
        i.add("ellipse", (x - 30, 30, x + 30, 90), c("#C8884A"), c("#8A5428"))
    i.add("ellipse", (54, 40, 202, 188), c("#D99A5A"), c("#8A5428"))
    i.add("ellipse", (92, 112, 164, 168), c("#F4D2A8"), c("#C8A070"), gloss=False)
    for x in (100, 156):
        i.add("ellipse", (x - 9, 88, x + 9, 106), c("#2A1E18"), c("#2A1E18"), gloss=False)
    i.add("ellipse", (116, 120, 140, 138), c("#3A2418"), c("#3A2418"), gloss=False)
    i.add("rrect", (70, 186, 186, 236, 22), c("#D99A5A"), c("#8A5428"))
    i.add("poly", [(100, 186), (128, 204), (156, 186), (156, 212), (128, 198), (100, 212)], c("#FF6A8A"), c("#C83A5A"), gloss=False)
    return i


def spark():
    i = Icon()
    i.add("ellipse", (24, 24, 232, 232), c("#FF7A6A"), c("#C82A2A"))
    i.add("poly", [(142, 40), (78, 140), (124, 140), (104, 216), (178, 108), (132, 108), (156, 40)], c("#FFE65A"), c("#E0A020"))
    return i


def grade():
    i = Icon()
    i.add("rrect", (52, 60, 204, 232, 10), c("#E06A4A"), c("#9A3A2A"))
    i.add("rrect", (40, 48, 216, 70, 8), c("#F4E6C8"), c("#C8B48A"), gloss=False)
    for y in (88, 136):
        for x in (80, 128, 176):
            i.add("rrect", (x - 14, y, x + 14, y + 30, 5), c("#FFD86A"), c("#C89A2A"), gloss=False)
    i.add("rrect", (110, 184, 146, 232, 6), c("#4A3020"), c("#2A1810"), gloss=False)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 30 if k % 2 == 0 else 13
        pts.append((128 + math.cos(a) * r, 22 + 12 + math.sin(a) * r))
    i.add("poly", pts, c("#FFE48A"), c("#D69A2A"))
    return i


ALL = {"wrench": wrench, "suitcase": suitcase, "teddy": teddy, "spark": spark, "grade": grade}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render(n)
    names = list(ALL)
    sheet = Image.new("RGBA", (len(names) * 160, 160), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), (k * 160 + 5, 5))
    sheet.save(os.path.join(OUT, "_sheet_r11.png"))
    print("ok", len(names))
