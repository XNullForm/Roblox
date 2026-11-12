"""Round 9 icons (build tools, research, guest events), same chunky style as ui_icons.py.
python ui_icons_r9.py  ->  ui/<name>.png + ui/_sheet_r9.png
"""
import os, math
from PIL import Image
from ui_icons import Icon, c, lighten, person, OUT, crown


def dk(col, k=0.72):
    return tuple(int(v * k) for v in col)


def lamp():
    i = Icon()
    i.add("rrect", (78, 206, 178, 228, 10), c("#C8A060"), c("#8E6A30"))
    i.add("line", ([(128, 210), (128, 110)], 14), c("#E6C98A"), c("#A88440"), gloss=False)
    i.add("poly", ((84, 34), (172, 34), (204, 112), (52, 112)), c("#FFF2C8"), c("#F0C870"))
    i.add("ellipse", (110, 104, 146, 132), c("#FFE89A"), c("#FFC040"), gloss=False)
    return i


def shapes():
    i = Icon()
    i.add("poly", ((40, 150), (96, 120), (152, 150), (152, 216), (96, 244), (40, 216)), c("#8ED8FF"), c("#3A8EE0"))
    i.add("ellipse", (138, 108, 228, 198), c("#FF9A8A"), c("#E0504A"))
    i.add("poly", ((92, 22), (148, 112), (36, 112)), c("#FFE07A"), c("#E0A030"))
    return i


def research():
    i = Icon()
    i.add("poly", ((104, 30), (152, 30), (152, 96), (212, 206), (196, 228), (60, 228), (44, 206), (104, 96)), c("#E8F4FF"), c("#B8CCE0"))
    i.add("poly", ((78, 150), (178, 150), (206, 204), (194, 220), (62, 220), (50, 204)), c("#9AF0B0"), c("#38B060"), gloss=False)
    i.add("rrect", (94, 22, 162, 44, 8), c("#C8D2DE"), c("#7A8898"))
    for (x, y, r) in ((112, 176, 10), (148, 188, 7), (132, 128, 8)):
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#FFFFFF"), c("#DFF8E6"), gloss=False)
    return i


def lock():
    i = Icon()
    i.add("line", ([(84, 124), (84, 84), (100, 52), (128, 42), (156, 52), (172, 84), (172, 124)], 22), c("#D2DCE8"), c("#8494A8"), gloss=False)
    i.add("rrect", (52, 112, 204, 228, 22), c("#FFD24A"), c("#E09A20"))
    i.add("ellipse", (114, 146, 142, 174), c("#6A4A18"), c("#4A3010"), gloss=False)
    i.add("rrect", (122, 164, 134, 198, 5), c("#6A4A18"), c("#4A3010"), gloss=False)
    return i


def copy_icon():
    i = Icon()
    i.add("rrect", (40, 40, 160, 176, 18), c("#B8C4D2"), c("#7A8898"))
    i.add("rrect", (96, 84, 216, 220, 18), c("#FFFFFF"), c("#D8DEE8"))
    i.add("line", ([(156, 124), (156, 180)], 14), c("#6BE07A"), gloss=False)
    i.add("line", ([(128, 152), (184, 152)], 14), c("#6BE07A"), gloss=False)
    return i


def paint():
    i = Icon()
    i.add("line", ([(150, 150), (210, 222)], 24), c("#D08A52"), c("#8E4E2A"))
    i.add("rrect", (118, 120, 172, 160, 10), c("#C8D2DE"), c("#7A8898"))
    i.add("poly", ((60, 34), (136, 26), (176, 122), (114, 134)), c("#FF8AC0"), c("#D8407A"))
    i.add("ellipse", (34, 150, 82, 198), c("#FF8AC0"), c("#D8407A"))
    return i


def arrow(up=True):
    i = Icon()
    if up:
        i.add("poly", ((128, 28), (220, 128), (166, 128), (166, 224), (90, 224), (90, 128), (36, 128)), c("#8ED8FF"), c("#3A8EE0"))
    else:
        i.add("poly", ((128, 228), (220, 128), (166, 128), (166, 32), (90, 32), (90, 128), (36, 128)), c("#FFB070"), c("#E06A30"))
    return i


def grid():
    i = Icon()
    i.add("rrect", (32, 32, 224, 224, 22), c("#E8EEF6"), c("#A8B4C4"))
    for k in (96, 160):
        i.add("line", ([(k, 48), (k, 208)], 10), c("#5A6A84"), gloss=False)
        i.add("line", ([(48, k), (208, k)], 10), c("#5A6A84"), gloss=False)
    return i


def roof():
    i = Icon()
    i.add("rrect", (58, 120, 198, 224, 10), c("#FFF2DC"), c("#E0CCAA"))
    i.add("rrect", (110, 158, 146, 224, 8), c("#C77A45"), c("#8E4E2A"))
    i.add("poly", ((128, 28), (236, 132), (210, 150), (128, 72), (46, 150), (20, 132)), c("#FF7A6A"), c("#C8403A"))
    i.add("rrect", (164, 46, 192, 100, 6), c("#B8C4D2"), c("#7A8898"))
    return i


def search():
    i = Icon()
    i.add("line", ([(156, 156), (220, 220)], 30), c("#D08A52"), c("#8E4E2A"))
    i.add("ellipse", (30, 30, 176, 176), c("#C8D2DE"), c("#7A8898"))
    i.add("ellipse", (54, 54, 152, 152), c("#DFF4FF"), c("#9ACCF0"))
    return i


def clock():
    i = Icon()
    i.add("ellipse", (28, 28, 228, 228), c("#FFE07A"), c("#E0A030"))
    i.add("ellipse", (52, 52, 204, 204), c("#FFFFFF"), c("#E8E4F0"), gloss=False)
    i.add("line", ([(128, 128), (128, 76)], 16), c("#46344A"), gloss=False)
    i.add("line", ([(128, 128), (168, 150)], 16), c("#46344A"), gloss=False)
    return i


# ---------------------------------------------------------------- guest events

def bottle():
    i = Icon()
    i.add("rrect", (78, 86, 178, 228, 30), c("#FFFFFF"), c("#DCE4F0"))
    i.add("rrect", (78, 150, 178, 228, 30), c("#FFE6A8"), c("#F6C870"), gloss=False)
    i.add("rrect", (90, 62, 166, 96, 12), c("#8ED8FF"), c("#3A8EE0"))
    i.add("poly", ((106, 64), (150, 64), (138, 22), (118, 22)), c("#FFC2A0"), c("#F08A6A"))
    return i


def wheel():
    i = Icon()
    i.add("ellipse", (30, 98, 160, 228), c("#8ED8FF"), c("#3A8EE0"))
    i.add("ellipse", (62, 130, 128, 196), c("#E8F6FF"), c("#BCDDF6"), gloss=False)
    i.add("ellipse", (100, 26, 146, 72), c("#FFD9B0"), c("#F2B27C"))
    i.add("line", ([(120, 82), (122, 150), (184, 150), (206, 214)], 22), c("#5AA7F0"), c("#2E70C0"), gloss=False)
    return i


def paw():
    i = Icon()
    i.add("ellipse", (66, 112, 190, 222), c("#C9A27A"), c("#8F6A48"))
    for (x, y) in ((50, 92), (96, 50), (160, 50), (206, 92)):
        i.add("ellipse", (x - 26, y - 30, x + 26, y + 30), c("#C9A27A"), c("#8F6A48"))
    return i


def moon():
    i = Icon()
    i.add("ellipse", (34, 34, 214, 214), c("#FFE89A"), c("#F0B840"))
    i.add("ellipse", (92, 18, 246, 172), c("#2A2E50"), c("#1A1D36"), gloss=False)
    for (x, y, r) in ((196, 186, 12), (222, 136, 8)):
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#FFFFFF"), gloss=False)
    return i


def cake():
    i = Icon()
    i.add("rrect", (34, 150, 222, 226, 16), c("#FF9AC0"), c("#D8508A"))
    i.add("rrect", (54, 100, 202, 156, 16), c("#FFF2DC"), c("#F0D8B0"))
    i.add("line", ([(54, 156), (80, 172), (106, 156), (132, 172), (158, 156), (184, 172), (202, 158)], 10), c("#FFFFFF"), gloss=False)
    for x in (92, 128, 164):
        i.add("rrect", (x - 6, 54, x + 6, 102, 4), c("#8ED8FF"), c("#3A8EE0"))
        i.add("ellipse", (x - 10, 26, x + 10, 54), c("#FFE07A"), c("#FF9A30"), gloss=False)
    return i


def heart():
    i = Icon()
    i.add("ellipse", (28, 40, 136, 148), c("#FF7A8A"), c("#E0304A"))
    i.add("ellipse", (120, 40, 228, 148), c("#FF7A8A"), c("#E0304A"))
    i.add("poly", ((34, 112), (222, 112), (128, 226)), c("#F25468"), c("#D0283E"))
    return i


def briefcase():
    i = Icon()
    i.add("line", ([(92, 74), (92, 46), (164, 46), (164, 74)], 16), c("#8E4E2A"), gloss=False)
    i.add("rrect", (28, 70, 228, 216, 20), c("#C77A45"), c("#8E4E2A"))
    i.add("rrect", (28, 120, 228, 136, 4), c("#8E4E2A"), c("#6A3A20"), gloss=False)
    i.add("rrect", (110, 110, 146, 146, 8), c("#FFE07A"), c("#E0A030"))
    return i


def clipboard():
    i = Icon()
    i.add("rrect", (46, 40, 210, 232, 18), c("#D08A52"), c("#8E4E2A"))
    i.add("rrect", (64, 62, 192, 216, 10), c("#FFFFFF"), c("#E4E0EA"))
    i.add("rrect", (94, 26, 162, 66, 12), c("#C8D2DE"), c("#7A8898"))
    for y in (110, 150, 188):
        i.add("line", ([(84, y), (96, y + 12), (114, y - 8)], 9), c("#2FA348"), gloss=False)
        i.add("line", ([(130, y), (172, y)], 9), c("#9AA4B8"), gloss=False)
    return i


def bus():
    i = Icon()
    i.add("rrect", (24, 54, 232, 196, 26), c("#FFD24A"), c("#E09A20"))
    i.add("rrect", (42, 74, 214, 128, 10), c("#DFF4FF"), c("#9ACCF0"), gloss=False)
    for x in (70, 186):
        i.add("ellipse", (x - 28, 170, x + 28, 226), c("#4A4E60"), c("#2A2E3C"))
    i.add("rrect", (34, 146, 64, 164, 6), c("#FFFFFF"), gloss=False)
    i.add("rrect", (192, 146, 222, 164, 6), c("#FFFFFF"), gloss=False)
    return i


def vip():
    i = Icon()
    i.add("poly", tuple((128 + r * math.cos(math.radians(a - 90)), 136 + r * math.sin(math.radians(a - 90)))
                       for k, a in enumerate(range(0, 360, 36)) for r in ((100 if k % 2 == 0 else 44),)),
          c("#FFE07A"), c("#E0A030"))
    crown(i, 128, 40)
    return i


def firstaid():
    i = Icon()
    i.add("rrect", (28, 60, 228, 214, 24), c("#FFFFFF"), c("#DCE4F0"))
    i.add("line", ([(92, 60), (92, 40), (164, 40), (164, 60)], 14), c("#9AA4B8"), gloss=False)
    i.add("rrect", (110, 92, 146, 186, 6), c("#FF6A6A"), c("#C8323A"), gloss=False)
    i.add("rrect", (82, 120, 174, 158, 6), c("#FF6A6A"), c("#C8323A"), gloss=False)
    return i


def sick():
    i = Icon()
    i.add("ellipse", (34, 40, 222, 228), c("#BEEA9A"), c("#7AC060"))
    for x in (92, 164):
        i.add("line", ([(x - 18, 112), (x + 18, 112)], 12), c("#46344A"), gloss=False)
    i.add("line", ([(96, 176), (128, 162), (160, 176)], 12), c("#46344A"), gloss=False)
    i.add("rrect", (162, 16, 178, 92, 6), c("#FFFFFF"), c("#DCE4F0"))
    i.add("ellipse", (158, 84, 182, 108), c("#FF6A6A"), c("#C8323A"), gloss=False)
    return i


ALL = {
    "lamp": lamp, "shapes": shapes, "research": research, "lock": lock, "copy": copy_icon, "paint": paint,
    "up": lambda: arrow(True), "down": lambda: arrow(False), "grid": grid, "roof": roof, "search": search, "clock": clock,
    "ev_baby": bottle, "ev_access": wheel, "ev_pet": paw, "ev_night": moon, "ev_party": cake, "ev_romance": heart,
    "ev_business": briefcase, "ev_inspector": clipboard, "ev_tour": bus, "ev_vip": vip, "ev_firstaid": firstaid, "ev_sick": sick,
}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render(n)
    names = list(ALL)
    cols = 8
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 160, rows * 160), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), ((k % cols) * 160 + 5, (k // cols) * 160 + 5))
    sheet.save(os.path.join(OUT, "_sheet_r9.png"))
    print("ok", len(names))
