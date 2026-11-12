"""Round 10b: sprites for the cleaning minigames, in the same chunky style as ui_icons.py.
python ui_minigame.py  ->  ui/mg_<name>.png + ui/_sheet_mg.png
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter
from ui_icons import Icon, c, lighten, OUT


def bottle():
    i = Icon()
    i.add("rrect", (86, 78, 170, 236, 30), c("#7ED8A0"), c("#2E9A60"))
    i.add("rrect", (108, 30, 148, 92, 12), c("#86DCA8"), c("#3AA868"))
    i.add("rrect", (102, 14, 154, 40, 8), c("#4AA0F0"), c("#2060C0"))
    i.add("rrect", (92, 128, 164, 182, 6), c("#FFF4E0"), c("#E8D8B8"), gloss=False)
    i.add("rrect", (104, 146, 152, 164, 4), c("#F06A6A"), c("#C84048"), gloss=False)
    return i


def can():
    i = Icon()
    i.add("rrect", (68, 40, 188, 228, 22), c("#FF7A6A"), c("#C8343C"))
    i.add("rrect", (74, 30, 182, 56, 12), c("#E6EEF6"), c("#98A6BA"))
    i.add("rrect", (74, 210, 182, 234, 12), c("#E6EEF6"), c("#98A6BA"), gloss=False)
    i.add("rrect", (68, 104, 188, 150, 4), c("#FFFFFF"), c("#E8ECF4"), gloss=False)
    i.add("rrect", (112, 18, 148, 36, 8), c("#C8D2DE"), c("#7A8898"), gloss=False)
    return i


def paper():
    i = Icon()
    random.seed(4)
    pts = []
    for k in range(18):
        a = k / 18 * math.tau
        r = 92 + random.uniform(-16, 12)
        pts.append((128 + math.cos(a) * r, 134 + math.sin(a) * r * 0.92))
    i.add("poly", pts, c("#FFFFFF"), c("#C8D0DC"))
    for seg in ([(78, 96), (118, 128), (104, 176)], [(150, 70), (140, 120), (186, 150)], [(118, 128), (150, 136)], [(96, 200), (140, 186), (170, 206)]):
        i.add("line", (seg, 6), c("#A8B2C2"), gloss=False)
    return i


def banana():
    i = Icon()
    # three floppy strips of peel round a stub
    i.add("line", ([(128, 112), (92, 150), (60, 206)], 34), c("#FFE15A"), c("#D8A820"))
    i.add("line", ([(128, 112), (166, 152), (204, 198)], 34), c("#FFE15A"), c("#D8A820"))
    i.add("line", ([(128, 112), (128, 170), (122, 226)], 34), c("#FFEB7A"), c("#E0B428"))
    i.add("rrect", (106, 52, 150, 128, 20), c("#FFE878"), c("#E0B030"))
    i.add("rrect", (118, 28, 138, 60, 8), c("#7A5A2A"), c("#4E3618"), gloss=False)
    for x, y in ((80, 182), (180, 176), (124, 204)):
        i.add("ellipse", (x - 6, y - 6, x + 6, y + 6), c("#8A6A2A"), gloss=False)
    return i


def wrapper():
    i = Icon()
    i.add("poly", [(70, 128), (22, 84), (30, 128), (22, 172)], c("#C89CFF"), c("#7A50D8"))
    i.add("poly", [(186, 128), (234, 84), (226, 128), (234, 172)], c("#C89CFF"), c("#7A50D8"))
    i.add("rrect", (62, 90, 194, 166, 30), c("#FF8AC8"), c("#D0408C"))
    i.add("rrect", (96, 114, 160, 142, 10), c("#FFF4E0"), c("#F0DCC0"), gloss=False)
    return i


def apple():
    i = Icon()
    i.add("ellipse", (74, 150, 182, 226), c("#FF6A5A"), c("#C02C38"))
    i.add("ellipse", (70, 36, 186, 112), c("#FF6A5A"), c("#C02C38"))
    i.add("rrect", (96, 84, 160, 178, 26), c("#FFF6D8"), c("#F0DCA8"))
    for y in (118, 146):
        i.add("ellipse", (120, y - 9, 136, y + 9), c("#5A3A1E"), gloss=False)
    i.add("line", ([(128, 40), (134, 14)], 9), c("#7A5A2A"), gloss=False)
    i.add("poly", [(136, 26), (176, 10), (168, 36)], c("#7EE07A"), c("#2EA048"), gloss=False)
    return i


def bin_(top, bot, rim):
    def f():
        i = Icon()
        i.add("poly", [(46, 92), (210, 92), (192, 236), (64, 236)], top, bot)
        for x in (92, 128, 164):
            i.add("rrect", (x - 7, 116, x + 7, 214, 7), lighten(top, 0.25), lighten(bot, 0.1), gloss=False)
        i.add("rrect", (36, 70, 220, 100, 12), rim, lighten(rim, -0.2) if False else tuple(max(0, v - 50) for v in rim))
        return i
    return f


def sponge():
    i = Icon()
    i.add("rrect", (34, 104, 222, 214, 26), c("#FFE15A"), c("#E0A828"))
    i.add("rrect", (34, 70, 222, 120, 20), c("#6AD47A"), c("#2E9A50"))
    random.seed(7)
    for _ in range(9):
        x, y = random.uniform(56, 200), random.uniform(134, 196)
        r = random.uniform(5, 9)
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#E8B83A"), c("#C89020"), gloss=False)
    return i


def brush():
    i = Icon()
    i.add("line", ([(210, 30), (130, 140)], 22), c("#FFFFFF"), c("#C8D2DE"))
    i.add("ellipse", (54, 120, 160, 226), c("#8ED8FF"), c("#3A8EE0"))
    i.add("ellipse", (78, 144, 136, 202), c("#B8E8FF"), c("#6AB4F0"), gloss=False)
    i.add("rrect", (118, 120, 152, 150, 10), c("#C8D2DE"), c("#7A8898"), gloss=False)
    return i


def grime():
    i = Icon()
    random.seed(12)
    pts = []
    for k in range(22):
        a = k / 22 * math.tau
        r = 80 + random.uniform(-22, 26) + (18 if k % 5 == 0 else 0)
        pts.append((128 + math.cos(a) * r, 128 + math.sin(a) * r))
    i.add("poly", pts, c("#B8A890"), c("#8A7A62"), gloss=False)
    for (x, y, r) in ((96, 108, 18), (156, 150, 14), (140, 92, 10), (100, 168, 9)):
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#9A8A70"), gloss=False)
    return i


def pillow():
    i = Icon()
    i.add("poly", [(30, 66), (128, 82), (226, 66), (214, 128), (226, 190), (128, 176), (30, 190), (42, 128)], c("#FFFFFF"), c("#D8E0EC"))
    i.add("line", ([(72, 128), (184, 128)], 5), c("#C8D2E0"), gloss=False)
    return i


def mint():
    i = Icon()
    i.add("poly", [(70, 128), (30, 96), (36, 128), (30, 160)], c("#7EE0B0"), c("#2EA070"))
    i.add("poly", [(186, 128), (226, 96), (220, 128), (226, 160)], c("#7EE0B0"), c("#2EA070"))
    i.add("ellipse", (62, 82, 194, 174), c("#9AF0C8"), c("#38B07A"))
    i.add("ellipse", (100, 112, 156, 144), c("#FFFFFF"), c("#E0F4EA"), gloss=False)
    return i


def showerhead():
    i = Icon()
    i.add("line", ([(30, 40), (110, 40), (150, 80)], 22), c("#E6EEF6"), c("#98A6BA"))
    i.add("poly", [(118, 96), (186, 50), (226, 110), (160, 150)], c("#F2F6FA"), c("#A8B6C8"))
    for k in range(5):
        x, y = 150 + k * 14, 156 - k * 10
        i.add("line", ([(x, y), (x - 20, y + 40)], 7), c("#8ED8FF"), gloss=False)
    return i


def toilet():
    i = Icon()
    i.add("rrect", (50, 10, 206, 70, 16), c("#FFFFFF"), c("#D4DCE8"))
    i.add("rrect", (176, 22, 200, 36, 6), c("#C8D2DE"), c("#7A8898"), gloss=False)
    i.add("ellipse", (40, 50, 216, 246), c("#FFFFFF"), c("#D8E0EC"))
    i.add("ellipse", (70, 82, 186, 222), c("#E4EAF2"), c("#C4CEDC"), gloss=False)
    i.add("ellipse", (88, 104, 168, 206), c("#BDE6FF"), c("#78C0F0"), gloss=False)
    return i


def bubble():
    # soft soap bubble with real transparency (drawn directly)
    S = 4
    N = 256 * S
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((16 * S, 16 * S, 240 * S, 240 * S), fill=(220, 240, 255, 70), outline=(160, 210, 255, 220), width=10 * S)
    hl = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse((62 * S, 52 * S, 120 * S, 96 * S), fill=(255, 255, 255, 230))
    hd.ellipse((168 * S, 170 * S, 188 * S, 190 * S), fill=(255, 255, 255, 160))
    img.alpha_composite(hl.filter(ImageFilter.GaussianBlur(3 * S)))
    img = img.resize((256, 256), Image.LANCZOS)
    img.save(os.path.join(OUT, "mg_bubble.png"))
    return img


ALL = {
    "bottle": bottle, "can": can, "paper": paper, "banana": banana, "wrapper": wrapper, "apple": apple,
    "binr": bin_(c("#7EC4FF"), c("#2E78D8"), c("#4A90E8")), "bint": bin_(c("#7EE09A"), c("#2E9A58"), c("#40B068")),
    "sponge": sponge, "brush": brush, "grime": grime, "pillow": pillow, "mint": mint, "showerhead": showerhead, "toilet": toilet,
}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render("mg_" + n)
    bubble()
    names = list(ALL) + ["bubble"]
    sheet = Image.new("RGBA", (len(names) * 140, 140), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, "mg_" + n + ".png")).resize((130, 130), Image.LANCZOS), (k * 140 + 5, 5))
    sheet.save(os.path.join(OUT, "_sheet_mg.png"))
    print("ok", len(names))
