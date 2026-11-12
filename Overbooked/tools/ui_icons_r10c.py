"""Round 10c icons (quests, achievements, talk, weather), same chunky style as ui_icons.py.
python ui_icons_r10c.py  ->  ui/<name>.png + ui/_sheet_r10c.png
"""
import os, math
from PIL import Image
from ui_icons import Icon, c, OUT


def star_pts(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    pts = []
    for k in range(n * 2):
        a = rot + k * math.pi / n
        r = ro if k % 2 == 0 else ri
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def clipboard():
    i = Icon()
    i.add("rrect", (40, 34, 216, 236, 18), c("#C88A52"), c("#8A5428"))
    i.add("rrect", (58, 56, 198, 220, 10), c("#FFFFFF"), c("#DCE4F0"), gloss=False)
    i.add("rrect", (90, 18, 166, 62, 12), c("#D6DEEA"), c("#8C9AB0"))
    for k, y in enumerate((96, 136, 176)):
        i.add("rrect", (74, y - 10, 96, y + 12, 6), c("#9AF0B0") if k < 2 else c("#E4EAF4"), c("#38B060") if k < 2 else c("#B8C4D4"), gloss=False)
        i.add("rrect", (108, y - 6, 182 - k * 18, y + 8, 6), c("#B8C4D4"), c("#8C9AB0"), gloss=False)
    return i


def trophy():
    i = Icon()
    i.add("line", ([(70, 70), (34, 72), (36, 112), (82, 138)], 14), c("#F6C858"), gloss=False)
    i.add("line", ([(186, 70), (222, 72), (220, 112), (174, 138)], 14), c("#F6C858"), gloss=False)
    cup = [(60, 44), (196, 44), (190, 104), (168, 148), (140, 164), (116, 164), (88, 148), (66, 104)]
    i.add("poly", cup, c("#FFE48A"), c("#D69A2A"))
    i.add("rrect", (112, 160, 144, 196, 6), c("#F6C858"), c("#C88A2A"), gloss=False)
    i.add("rrect", (74, 192, 182, 234, 12), c("#8E5A32"), c("#5E3A20"))
    i.add("rrect", (98, 204, 158, 220, 5), c("#FFE48A"), c("#E0A030"), gloss=False)
    i.add("poly", star_pts(128, 96, 30, 13), c("#FFF6D0"), c("#FFE08A"), gloss=False)
    return i


def chat():
    i = Icon()
    i.add("rrect", (86, 34, 236, 140, 30), c("#B8E4FF"), c("#5AA0E8"))
    i.add("poly", [(196, 132), (220, 170), (170, 136)], c("#5AA0E8"), c("#4A8AD8"), gloss=False)
    i.add("rrect", (20, 92, 176, 206, 30), c("#FFFFFF"), c("#D4DCE8"))
    i.add("poly", [(52, 198), (36, 238), (92, 202)], c("#D4DCE8"), c("#C4CCD8"), gloss=False)
    for x in (62, 98, 134):
        i.add("ellipse", (x - 12, 137, x + 12, 161), c("#6A7890"), c("#4A5468"), gloss=False)
    return i


def sun():
    i = Icon()
    for k in range(8):
        a = k * math.tau / 8
        cx, cy = 128 + math.cos(a) * 92, 128 + math.sin(a) * 92
        p = [(cx + math.cos(a) * 22, cy + math.sin(a) * 22), (cx + math.cos(a + 1.6) * 14, cy + math.sin(a + 1.6) * 14),
             (cx - math.cos(a) * 14, cy - math.sin(a) * 14), (cx + math.cos(a - 1.6) * 14, cy + math.sin(a - 1.6) * 14)]
        i.add("poly", p, c("#FFD24A"), c("#F09A20"), gloss=False)
    i.add("ellipse", (62, 62, 194, 194), c("#FFE878"), c("#F0A020"))
    return i


def cloud_shape(i, dy=0, top="#FFFFFF", bot="#C8D2E2"):
    i.add("ellipse", (24, 96 + dy, 116, 188 + dy), c(top), c(bot))
    i.add("ellipse", (70, 52 + dy, 182, 164 + dy), c(top), c(bot))
    i.add("ellipse", (144, 92 + dy, 232, 180 + dy), c(top), c(bot))
    i.add("rrect", (48, 130 + dy, 214, 188 + dy, 28), c(top), c(bot))


def cloud():
    i = Icon()
    i.add("ellipse", (126, 30, 222, 126), c("#FFE070"), c("#F0A020"))
    cloud_shape(i, 20)
    return i


def rain():
    i = Icon()
    cloud_shape(i, -24, "#E4EAF4", "#9AA8C0")
    for x, y in ((74, 186), (128, 204), (182, 186)):
        i.add("poly", [(x, y - 22), (x + 13, y + 6), (x, y + 20), (x - 13, y + 6)], c("#8ED8FF"), c("#3A8EE0"), gloss=False)
        i.add("ellipse", (x - 13, y - 4, x + 13, y + 22), c("#8ED8FF"), c("#3A8EE0"), gloss=False)
    return i


def snow():
    i = Icon()
    cloud_shape(i, -24, "#F4F8FC", "#B8C6DA")
    for x, y in ((76, 196), (128, 214), (180, 196)):
        for k in range(3):
            a = k * math.pi / 3
            i.add("line", ([(x - math.cos(a) * 16, y - math.sin(a) * 16), (x + math.cos(a) * 16, y + math.sin(a) * 16)], 7), c("#CFEFFF"), gloss=False)
    return i


def storm():
    i = Icon()
    cloud_shape(i, -30, "#B8C2D4", "#6A7890")
    i.add("poly", [(140, 128), (98, 196), (128, 196), (110, 244), (170, 168), (138, 168), (156, 128)], c("#FFE070"), c("#F0A020"), gloss=False)
    return i


def gift():
    i = Icon()
    i.add("rrect", (40, 104, 216, 228, 14), c("#FF8A8A"), c("#C83A48"))
    i.add("rrect", (28, 78, 228, 116, 12), c("#FF9A9A"), c("#D84A58"))
    i.add("rrect", (112, 78, 144, 228, 4), c("#FFE48A"), c("#E0A030"), gloss=False)
    i.add("ellipse", (68, 30, 128, 86), c("#FFE48A"), c("#E0A030"), gloss=False)
    i.add("ellipse", (128, 30, 188, 86), c("#FFE48A"), c("#E0A030"), gloss=False)
    i.add("ellipse", (90, 46, 116, 72), c("#C88A2A"), c("#A86A1A"), gloss=False)
    i.add("ellipse", (140, 46, 166, 72), c("#C88A2A"), c("#A86A1A"), gloss=False)
    return i


def heart():
    i = Icon()
    pts = []
    for k in range(60):
        t = k / 60 * math.tau
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((128 + x * 6.4, 122 - y * 6.4))
    i.add("poly", pts, c("#FF8A9A"), c("#D83A58"))
    return i


def angry():
    i = Icon()
    i.add("ellipse", (28, 28, 228, 228), c("#FF9A6A"), c("#D84A3A"))
    i.add("line", ([(70, 92), (112, 110)], 12), c("#5A2018"), gloss=False)
    i.add("line", ([(186, 92), (144, 110)], 12), c("#5A2018"), gloss=False)
    i.add("ellipse", (82, 112, 108, 138), c("#5A2018"), c("#3A1008"), gloss=False)
    i.add("ellipse", (148, 112, 174, 138), c("#5A2018"), c("#3A1008"), gloss=False)
    i.add("line", ([(88, 186), (128, 166), (168, 186)], 12), c("#5A2018"), gloss=False)
    return i


def happy():
    i = Icon()
    i.add("ellipse", (28, 28, 228, 228), c("#FFE878"), c("#F0A020"))
    i.add("ellipse", (82, 90, 108, 124), c("#5A3818"), c("#3A2008"), gloss=False)
    i.add("ellipse", (148, 90, 174, 124), c("#5A3818"), c("#3A2008"), gloss=False)
    i.add("line", ([(74, 152), (100, 180), (128, 188), (156, 180), (182, 152)], 13), c("#5A3818"), gloss=False)
    return i


def plus():
    i = Icon()
    i.add("ellipse", (24, 24, 232, 232), c("#9AF0B0"), c("#28A058"))
    i.add("rrect", (110, 64, 146, 192, 12), c("#FFFFFF"), c("#E4F4E8"), gloss=False)
    i.add("rrect", (64, 110, 192, 146, 12), c("#FFFFFF"), c("#E4F4E8"), gloss=False)
    return i


def checkmark():
    i = Icon()
    i.add("ellipse", (24, 24, 232, 232), c("#9AF0B0"), c("#28A058"))
    i.add("line", ([(72, 132), (112, 172), (186, 92)], 26), c("#FFFFFF"), gloss=False)
    return i


ALL = {
    "quest": clipboard, "trophy": trophy, "chat": chat, "sun": sun, "cloudy": cloud, "rain": rain, "snow": snow,
    "storm": storm, "gift": gift, "heart": heart, "angry": angry, "happy": happy, "plus": plus, "checkmark": checkmark,
}

if __name__ == "__main__":
    for n, f in ALL.items():
        f().render(n)
    names = list(ALL)
    cols = 7
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGBA", (cols * 160, rows * 160), (30, 34, 52, 255))
    for k, n in enumerate(names):
        sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), ((k % cols) * 160 + 5, (k // cols) * 160 + 5))
    sheet.save(os.path.join(OUT, "_sheet_r10c.png"))
    print("ok", len(names))
