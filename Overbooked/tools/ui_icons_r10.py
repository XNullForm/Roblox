"""Round 10 icons (left dock, hotel level, kitchen), same chunky style as ui_icons.py.
python ui_icons_r10.py  ->  ui/<name>.png + ui/_sheet_r10.png
"""
import os, math
from PIL import Image
from ui_icons import Icon, c, lighten, OUT


def gear():
    i = Icon()
    pts = []
    teeth, ro, ri = 8, 112, 86
    for k in range(teeth * 4):
        a = (k / (teeth * 4)) * math.tau - math.pi / 2
        r = ro if (k % 4) in (1, 2) else ri
        pts.append((128 + math.cos(a) * r, 132 + math.sin(a) * r))
    i.add("poly", pts, c("#D6DEEA"), c("#8C9AB0"))
    i.add("ellipse", (88, 92, 168, 172), c("#5C6A82"), c("#3C465A"), gloss=False)
    i.add("ellipse", (108, 112, 148, 152), c("#FFD24A"), c("#E09A20"))
    return i


def stats():
    i = Icon()
    i.add("rrect", (30, 206, 226, 228, 10), c("#C8D2DE"), c("#7A8898"), gloss=False)
    i.add("rrect", (40, 132, 84, 210, 10), c("#8ED8FF"), c("#3A8EE0"))
    i.add("rrect", (106, 86, 150, 210, 10), c("#9AF0B0"), c("#38B060"))
    i.add("rrect", (172, 36, 216, 210, 10), c("#FFE07A"), c("#E0A030"))
    return i


def food():
    # a cloche on a plate
    i = Icon()
    i.add("ellipse", (20, 178, 236, 222), c("#FFFFFF"), c("#C8D2DE"))
    i.add("poly", [(128 + math.cos(a) * 96, 188 - abs(math.sin(a)) * 112) for a in [math.pi * k / 24 for k in range(25)]], c("#F2F6FA"), c("#A8B6C8"))
    i.add("rrect", (32, 180, 224, 198, 8), c("#C8D2DE"), c("#8C9AB0"), gloss=False)
    i.add("ellipse", (112, 54, 144, 86), c("#FFD24A"), c("#E09A20"))
    return i


def chef():
    i = Icon()
    i.add("ellipse", (40, 50, 120, 130), c("#FFFFFF"), c("#DCE4F0"))
    i.add("ellipse", (136, 50, 216, 130), c("#FFFFFF"), c("#DCE4F0"))
    i.add("ellipse", (78, 24, 178, 120), c("#FFFFFF"), c("#E4EAF4"))
    i.add("rrect", (66, 100, 190, 200, 14), c("#FFFFFF"), c("#D4DCE8"))
    i.add("rrect", (60, 176, 196, 222, 12), c("#F06A6A"), c("#B83440"))
    return i


def medal():
    i = Icon()
    i.add("poly", ((70, 20), (118, 20), (146, 112), (106, 122)), c("#6AB4FF"), c("#2E70D0"), gloss=False)
    i.add("poly", ((186, 20), (138, 20), (110, 112), (150, 122)), c("#FF7A7A"), c("#C83A48"), gloss=False)
    i.add("ellipse", (54, 96, 202, 244), c("#FFE48A"), c("#D69A2A"))
    i.add("ellipse", (82, 124, 174, 216), c("#F6C858"), c("#E0A030"), gloss=False)
    star = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 36 if k % 2 == 0 else 15
        star.append((128 + math.cos(a) * r, 172 + math.sin(a) * r))
    i.add("poly", star, c("#FFF6D0"), c("#FFE08A"), gloss=False)
    return i


def hotel():
    i = Icon()
    i.add("rrect", (40, 66, 216, 228, 12), c("#F4D8B0"), c("#C89A6A"))
    i.add("rrect", (28, 44, 228, 82, 12), c("#E05A5A"), c("#A8323A"))
    for y in (100, 140):
        for x in (62, 112, 162):
            i.add("rrect", (x, y, x + 32, y + 26, 6), c("#9ED8FF"), c("#4A9AE0"), gloss=False)
    i.add("rrect", (104, 178, 152, 228, 8), c("#8E5A32"), c("#5E3A20"), gloss=False)
    i.add("rrect", (96, 14, 160, 44, 8), c("#FFD24A"), c("#E09A20"))
    return i


def pot():
    i = Icon()
    i.add("rrect", (16, 120, 60, 140, 8), c("#5C6A82"), c("#3C465A"), gloss=False)
    i.add("rrect", (196, 120, 240, 140, 8), c("#5C6A82"), c("#3C465A"), gloss=False)
    i.add("rrect", (46, 100, 210, 220, 28), c("#E8EEF6"), c("#98A6BA"))
    i.add("rrect", (38, 84, 218, 110, 12), c("#C8D2DE"), c("#7A8898"))
    i.add("rrect", (112, 62, 144, 90, 10), c("#5C6A82"), c("#3C465A"))
    for x in (84, 172):
        i.add("line", ([(x, 70), (x + 6, 58), (x - 4, 44), (x + 4, 30), (x, 20)], 9), c("#FFFFFF"), gloss=False)
    return i


ALL = {"settings": gear, "stats": stats, "food": food, "chef": chef, "medal": medal, "hotel": hotel, "pot": pot}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render(n)
    names = list(ALL)
    cols = len(names)
    sheet = Image.new("RGBA", (cols * 160, 160), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), (k * 160 + 5, 5))
    sheet.save(os.path.join(OUT, "_sheet_r10.png"))
    print("ok", len(names))
