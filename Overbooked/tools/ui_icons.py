"""Run a Hotel UI icons: chunky cartoon pictograms (dark outline, gradient fill, gloss).
python ui_icons.py  ->  ui/<name>.png (256x256, transparent). Upload with MCP upload_image from :8792.
"""
import os, math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui")
os.makedirs(OUT, exist_ok=True)
S = 4          # supersample
N = 256 * S
INK = (46, 34, 58, 255)
OL = 14 * S    # outline width


class Icon:
    def __init__(self):
        self.shapes = []  # (kind, args, fill_top, fill_bottom)

    def add(self, kind, args, top, bottom=None, gloss=True):
        self.shapes.append((kind, args, top, bottom or top, gloss))
        return self

    def _mask(self, kind, args, grow=0):
        m = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(m)
        if kind == "rrect":
            (x0, y0, x1, y1, r) = args
            d.rounded_rectangle((x0 * S - grow, y0 * S - grow, x1 * S + grow, y1 * S + grow), r * S + grow, fill=255)
        elif kind == "ellipse":
            (x0, y0, x1, y1) = args
            d.ellipse((x0 * S - grow, y0 * S - grow, x1 * S + grow, y1 * S + grow), fill=255)
        elif kind == "poly":
            pts = [(x * S, y * S) for x, y in args]
            d.polygon(pts, fill=255)
            if grow:
                d.line(pts + [pts[0]], fill=255, width=grow * 2, joint="curve")
                for p in pts:
                    d.ellipse((p[0] - grow, p[1] - grow, p[0] + grow, p[1] + grow), fill=255)
        elif kind == "line":
            (pts, w) = args
            pp = [(x * S, y * S) for x, y in pts]
            d.line(pp, fill=255, width=int(w * S + grow * 2), joint="curve")
            for p in (pp[0], pp[-1]):
                r = w * S / 2 + grow
                d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)
        return m

    def render(self, name):
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        # one shared outline under everything, plus a soft drop shadow
        outline = Image.new("L", (N, N), 0)
        for kind, args, *_ in self.shapes:
            outline = ImageChops.lighter(outline, self._mask(kind, args, OL))
        shadow = outline.filter(ImageFilter.GaussianBlur(6 * S))
        sh = Image.new("RGBA", (N, N), (20, 10, 30, 0))
        sh.putalpha(shadow.point(lambda a: int(a * 0.35)))
        img.alpha_composite(sh, (0, 6 * S))
        ink = Image.new("RGBA", (N, N), INK)
        ink.putalpha(outline)
        img.alpha_composite(ink)
        for kind, args, top, bot, gloss in self.shapes:
            m = self._mask(kind, args)
            bbox = m.getbbox()
            if not bbox:
                continue
            grad = Image.new("RGBA", (N, N))
            gd = ImageDraw.Draw(grad)
            y0, y1 = bbox[1], bbox[3]
            for y in range(y0, y1 + 1, 2):
                t = (y - y0) / max(y1 - y0, 1)
                c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
                gd.line([(0, y), (N, y), (0, y + 1), (N, y + 1)], fill=c)
            # inner rim: thin dark line just inside each shape so pieces read separately
            rim = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(9)))
            layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
            layer.paste(grad, (0, 0), m)
            rl = Image.new("RGBA", (N, N), INK[:3] + (0,))
            rl.putalpha(rim.point(lambda a: int(a * 0.55)))
            layer.alpha_composite(rl)
            if gloss:
                # gloss: a soft white band on the upper part of the shape
                g = Image.new("L", (N, N), 0)
                gdraw = ImageDraw.Draw(g)
                bx0, by0, bx1, by1 = bbox
                h = by1 - by0
                gdraw.rounded_rectangle((bx0 + (bx1 - bx0) * 0.12, by0 + h * 0.08, bx1 - (bx1 - bx0) * 0.12, by0 + h * 0.34), int(h * 0.12), fill=110)
                g = ImageChops.multiply(g.filter(ImageFilter.GaussianBlur(3 * S)), m.filter(ImageFilter.MinFilter(15)))
                wl = Image.new("RGBA", (N, N), (255, 255, 255, 0))
                wl.putalpha(g)
                layer.alpha_composite(wl)
            img.alpha_composite(layer)
        img = img.resize((256, 256), Image.LANCZOS)
        img.save(os.path.join(OUT, name + ".png"))
        return img


def c(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def lighten(col, k):
    return tuple(min(255, int(x + (255 - x) * k)) for x in col)


# ---------------------------------------------------------------- icons

def bed(extra=None, sheet="#FFF4E8", blanket="#F0965A"):
    i = Icon()
    i.add("rrect", (28, 150, 228, 196, 12), c("#C77A45"), c("#8E4E2A"))           # base
    i.add("rrect", (32, 70, 72, 196, 16), c("#D08A52"), c("#9A5A32"))             # headboard
    i.add("rrect", (40, 128, 222, 160, 14), c(sheet), lighten(c(sheet), -0.2) if False else c("#E6D8C8"))  # mattress
    i.add("rrect", (52, 104, 112, 138, 16), c("#FFFFFF"), c("#E4E0EA"))          # pillow
    i.add("rrect", (104, 118, 226, 168, 18), c(blanket), tuple(int(x * 0.8) for x in c(blanket)))  # duvet
    i.add("rrect", (36, 190, 52, 222, 6), c("#8E4E2A"), c("#6A3A20"))
    i.add("rrect", (204, 190, 220, 222, 6), c("#8E4E2A"), c("#6A3A20"))
    if extra:
        extra(i)
    return i


def check(i, x=190, y=70):
    i.add("ellipse", (x - 46, y - 46, x + 46, y + 46), c("#6BE07A"), c("#2FA348"))
    i.add("line", ([(x - 22, y + 2), (x - 6, y + 18), (x + 24, y - 16)], 14), c("#FFFFFF"), gloss=False)


def person(i, x=188, y=76, col="#5AA7F0"):
    i.add("rrect", (x - 34, y + 6, x + 34, y + 62, 26), c(col), tuple(int(v * 0.75) for v in c(col)))
    i.add("ellipse", (x - 26, y - 46, x + 26, y + 6), c("#FFD9B0"), c("#F2B27C"))


def dust(i):
    for (x, y, r) in ((176, 64, 30), (214, 92, 22), (150, 92, 18)):
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#C9A27A"), c("#8F6A48"))


def shower():
    i = Icon()
    i.add("line", ([(70, 230), (70, 56), (120, 40), (170, 56)], 20), c("#E6EAF0"), c("#9AA6B4"), gloss=False)
    i.add("poly", ((128, 70), (212, 70), (196, 100), (144, 100)), c("#F4F6FA"), c("#A8B4C4"))
    for k, x in enumerate((150, 170, 190)):
        y = 126 + (k % 2) * 16
        i.add("poly", ((x, y), (x - 9, y + 22), (x, y + 36), (x + 9, y + 22)), c("#7FD4FF"), c("#2E8EE0"))
        i.add("poly", ((x - 6, y + 52), (x - 15, y + 74), (x - 6, y + 88), (x + 3, y + 74)), c("#7FD4FF"), c("#2E8EE0"))
    return i


def toilet():
    i = Icon()
    i.add("rrect", (132, 40, 212, 136, 16), c("#FFFFFF"), c("#D8DEE8"))          # tank
    i.add("rrect", (44, 116, 212, 150, 16), c("#FFFFFF"), c("#DCE2EC"))          # seat
    i.add("poly", ((60, 146), (200, 146), (176, 196), (84, 196)), c("#F4F6FA"), c("#C4CCD8"))
    i.add("rrect", (96, 190, 168, 226, 10), c("#E8ECF2"), c("#B8C0CC"))
    i.add("rrect", (156, 56, 190, 70, 6), c("#9FB8D0"), c("#6E8AA8"), gloss=False)
    return i


def bell():
    i = Icon()
    i.add("rrect", (30, 186, 226, 214, 12), c("#6A5C6E"), c("#3E3442"))
    i.add("poly", ((50, 188), (60, 130), (92, 92), (128, 84), (164, 92), (196, 130), (206, 188)), c("#FFE07A"), c("#E0A030"))
    i.add("rrect", (116, 52, 140, 90, 10), c("#FFE07A"), c("#E0A030"))
    return i


def cash():
    i = Icon()
    for k, (dx, dy, rot) in enumerate(((0, 40, 0), (0, 0, 0))):
        y = 96 + dy
        i.add("rrect", (32 + dx, y - 10, 224 + dx, y + 70, 14), c("#8FE07A"), c("#3E9E48"))
        i.add("rrect", (102 + dx, y - 10, 154 + dx, y + 70, 6), c("#FFF6D8"), c("#E8D8A0"), gloss=False)
    i.add("ellipse", (100, 104, 156, 160), c("#C8F5B0"), c("#78C860"), gloss=False)
    i.add("line", ([(128, 112), (128, 152)], 8), c("#2E7A38"), gloss=False)
    return i


def broom():
    i = Icon()
    i.add("rrect", (54, 150, 214, 222, 18), c("#5AB0F0"), c("#2E70C0"))          # bucket
    i.add("rrect", (44, 138, 224, 158, 10), c("#7CC4F8"), c("#3E88D0"))
    for (x, y, r) in ((90, 124, 26), (124, 108, 30), (162, 120, 26), (190, 132, 18)):
        i.add("ellipse", (x - r, y - r, x + r, y + r), c("#FFFFFF"), c("#C8E4F8"))
    i.add("poly", ((164, 160), (222, 120), (234, 172), (200, 196)), c("#FFFFFF"), c("#E0E4EA"))  # cloth
    return i


def sparkle():
    i = Icon()

    def star(cx, cy, r, col1, col2):
        pts = []
        for k in range(8):
            a = math.pi / 4 * k - math.pi / 2
            rr = r if k % 2 == 0 else r * 0.32
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        i.add("poly", tuple(pts), c(col1), c(col2))
    star(118, 130, 92, "#FFF6B0", "#FFC838")
    star(196, 64, 40, "#FFFFFF", "#9FE4FF")
    star(204, 196, 30, "#FFFFFF", "#9FE4FF")
    return i


def door():
    i = Icon()
    i.add("rrect", (58, 26, 198, 232, 14), c("#A86A3C"), c("#6E3E20"))
    i.add("rrect", (78, 46, 178, 120, 10), c("#C68650"), c("#94582E"), gloss=False)
    i.add("rrect", (78, 134, 178, 212, 10), c("#C68650"), c("#94582E"), gloss=False)
    i.add("ellipse", (154, 122, 178, 146), c("#FFE07A"), c("#D89A20"))
    return i


def walk():
    i = Icon()
    # footprints
    for (x, y, a) in ((96, 170, -0.2), (156, 96, 0.2)):
        i.add("ellipse", (x - 26, y - 38, x + 26, y + 34), c("#FFFFFF"), c("#C8D0DA"))
        for k in range(3):
            tx = x - 18 + k * 16
            i.add("ellipse", (tx - 8, y - 66, tx + 8, y - 48), c("#FFFFFF"), c("#C8D0DA"))
    return i


def star():
    i = Icon()
    pts = []
    for k in range(10):
        a = math.pi / 5 * k - math.pi / 2
        rr = 104 if k % 2 == 0 else 46
        pts.append((128 + rr * math.cos(a), 136 + rr * math.sin(a)))
    i.add("poly", tuple(pts), c("#FFE878"), c("#F0A020"))
    return i


def guest():
    i = Icon()
    person(i, 128, 112, "#F0965A")
    return i


def zzz():
    i = Icon()
    for (x, y, s) in ((80, 160, 70), (160, 90, 50)):
        i.add("line", ([(x - s / 2, y - s / 2), (x + s / 2, y - s / 2), (x - s / 2, y + s / 2), (x + s / 2, y + s / 2)], 16), c("#B8A4FF"), c("#7A5CE8"), gloss=False)
    return i


def hammer():
    i = Icon()
    i.add("line", ([(84, 222), (150, 110)], 26), c("#D08A52"), c("#8E4E2A"))
    i.add("poly", ((100, 70), (176, 30), (226, 88), (196, 110), (170, 84), (128, 110)), c("#C8D2DE"), c("#7A8898"))
    return i


def sofa_icon():
    i = Icon()
    i.add("rrect", (40, 70, 216, 150, 28), c("#5EC4CF"), c("#2E8C9C"))
    i.add("rrect", (20, 110, 66, 196, 20), c("#5EC4CF"), c("#2E8C9C"))
    i.add("rrect", (190, 110, 236, 196, 20), c("#5EC4CF"), c("#2E8C9C"))
    i.add("rrect", (56, 132, 200, 186, 18), c("#7FD6DE"), c("#3EA0AE"))
    i.add("rrect", (40, 196, 56, 224, 6), c("#8E4E2A"), c("#6A3A20"))
    i.add("rrect", (200, 196, 216, 224, 6), c("#8E4E2A"), c("#6A3A20"))
    return i


def plant_icon():
    i = Icon()
    for (x0, y0, x1, y1) in ((60, 40, 130, 140), (126, 30, 196, 136), (34, 96, 112, 160), (144, 92, 222, 156)):
        i.add("ellipse", (x0, y0, x1, y1), c("#7CD66A"), c("#3C9A44"))
    i.add("poly", ((70, 150), (186, 150), (172, 228), (84, 228)), c("#F09A5A"), c("#C0602E"))
    i.add("rrect", (60, 140, 196, 166, 10), c("#F6AE72"), c("#D07040"))
    return i


def paddle():
    i = Icon()
    i.add("line", ([(150, 160), (204, 216)], 26), c("#D08A52"), c("#8E4E2A"))
    i.add("ellipse", (36, 36, 176, 176), c("#FF6A6A"), c("#C8323A"))
    i.add("ellipse", (182, 52, 230, 100), c("#FFB458"), c("#E07A20"))
    return i


def rotate():
    i = Icon()
    pts = [(128 + 78 * math.cos(math.radians(a)), 132 + 78 * math.sin(math.radians(a))) for a in range(-60, 200, 10)]
    i.add("line", (pts, 26), c("#8ED8FF"), c("#3A8EE0"), gloss=False)
    e = pts[0]
    i.add("poly", ((e[0] - 34, e[1] - 22), (e[0] + 26, e[1] - 36), (e[0] + 14, e[1] + 30)), c("#8ED8FF"), c("#3A8EE0"))
    return i


def move():
    i = Icon()
    i.add("line", ([(128, 40), (128, 216)], 22), c("#FFE07A"), c("#E0A030"), gloss=False)
    i.add("line", ([(40, 128), (216, 128)], 22), c("#FFE07A"), c("#E0A030"), gloss=False)
    for (x, y, dx, dy) in ((128, 30, 0, 1), (128, 226, 0, -1), (30, 128, 1, 0), (226, 128, -1, 0)):
        px, py = -dy, dx
        i.add("poly", ((x, y), (x + dx * 40 + px * 30, y + dy * 40 + py * 30), (x + dx * 40 - px * 30, y + dy * 40 - py * 30)), c("#FFE07A"), c("#E0A030"))
    return i


def sell():
    i = Icon()
    i.add("ellipse", (40, 40, 216, 216), c("#FFE07A"), c("#E0A030"))
    i.add("ellipse", (68, 68, 188, 188), c("#FFD24A"), c("#F0B020"), gloss=False)
    i.add("line", ([(150, 96), (110, 96), (106, 124), (148, 132), (146, 162), (104, 162)], 14), c("#B87A10"), gloss=False)
    i.add("line", ([(128, 80), (128, 178)], 12), c("#B87A10"), gloss=False)
    return i


def close_icon():
    i = Icon()
    i.add("ellipse", (32, 32, 224, 224), c("#FF7A7A"), c("#D03A44"))
    i.add("line", ([(88, 88), (168, 168)], 26), c("#FFFFFF"), gloss=False)
    i.add("line", ([(168, 88), (88, 168)], 26), c("#FFFFFF"), gloss=False)
    return i


def place_icon():
    i = Icon()
    i.add("ellipse", (32, 32, 224, 224), c("#6BE07A"), c("#2FA348"))
    i.add("line", ([(80, 130), (114, 164), (178, 96)], 26), c("#FFFFFF"), gloss=False)
    return i


def pile_icon():
    i = Icon()
    i.add("rrect", (30, 150, 226, 220, 14), c("#B8C4D2"), c("#7A8898"))
    i.add("rrect", (54, 96, 202, 156, 14), c("#D2DCE8"), c("#94A2B4"))
    i.add("rrect", (80, 44, 176, 100, 14), c("#E8EEF6"), c("#A8B4C4"))
    return i


def janitor():
    i = Icon()
    # mop leaning behind
    i.add("line", ([(206, 30), (150, 214)], 14), c("#D08A52"), c("#8E4E2A"), gloss=False)
    i.add("poly", ((116, 200), (186, 200), (196, 236), (106, 236)), c("#F4F6FA"), c("#B8C4D2"))
    # body in blue overalls, head, cap
    i.add("rrect", (52, 128, 160, 230, 40), c("#5AA7F0"), c("#2E70C0"))
    i.add("rrect", (84, 140, 128, 186, 10), c("#7CC4F8"), c("#3E88D0"), gloss=False)
    i.add("ellipse", (66, 44, 146, 124), c("#FFD9B0"), c("#F2B27C"))
    i.add("poly", ((62, 78), (70, 46), (106, 30), (146, 46), (152, 74)), c("#FFE07A"), c("#E0A030"))
    i.add("rrect", (130, 64, 178, 80, 8), c("#FFE07A"), c("#E0A030"), gloss=False)
    return i


def doorman():
    i = Icon()
    # red coat with gold buttons, tall hat
    i.add("rrect", (60, 132, 196, 232, 44), c("#F06A6A"), c("#B83A44"))
    for y in (156, 186, 214):
        i.add("ellipse", (120, y - 8, 136, y + 8), c("#FFE07A"), c("#D89A20"), gloss=False)
    i.add("ellipse", (88, 56, 168, 136), c("#FFD9B0"), c("#F2B27C"))
    i.add("rrect", (90, 14, 166, 68, 10), c("#F06A6A"), c("#B83A44"))
    i.add("rrect", (78, 58, 178, 76, 8), c("#3E3442"), c("#2A2230"), gloss=False)
    i.add("rrect", (90, 40, 166, 50, 4), c("#FFE07A"), c("#D89A20"), gloss=False)
    return i


def staff_icon():
    i = Icon()
    person(i, 86, 112, "#5AA7F0")
    person(i, 170, 112, "#F06A6A")
    return i


def up_badge(i, x=186, y=72):
    i.add("ellipse", (x - 48, y - 48, x + 48, y + 48), c("#6BE07A"), c("#2FA348"))
    i.add("poly", ((x, y - 32), (x + 30, y + 2), (x + 13, y + 2), (x + 13, y + 30), (x - 13, y + 30), (x - 13, y + 2), (x - 30, y + 2)), c("#FFFFFF"), c("#E4F2E0"), gloss=False)


def crown(i, x=180, y=70):
    i.add("poly", ((x - 52, y + 34), (x - 58, y - 30), (x - 26, y), (x, y - 44), (x + 26, y), (x + 58, y - 30), (x + 52, y + 34)), c("#FFE878"), c("#F0A020"))
    for dx in (-30, 0, 30):
        i.add("ellipse", (x + dx - 8, y + 10, x + dx + 8, y + 26), c("#FF6A7A"), c("#C8283C"), gloss=False)


def star_empty():
    i = Icon()
    pts = []
    for k in range(10):
        a = math.pi / 5 * k - math.pi / 2
        rr = 104 if k % 2 == 0 else 46
        pts.append((128 + rr * math.cos(a), 136 + rr * math.sin(a)))
    i.add("poly", tuple(pts), c("#8C7FA4"), c("#5E5274"))
    return i


def upgrade_icon():
    i = Icon()
    x, y = 128, 128
    i.add("ellipse", (x - 100, y - 100, x + 100, y + 100), c("#6BE07A"), c("#2FA348"))
    i.add("poly", ((x, y - 66), (x + 62, y + 4), (x + 27, y + 4), (x + 27, y + 62), (x - 27, y + 62), (x - 27, y + 4), (x - 62, y + 4)), c("#FFFFFF"), c("#E4F2E0"), gloss=False)
    return i


def coop_icon():
    i = Icon()
    person(i, 84, 120, "#5AA7F0")
    person(i, 172, 120, "#F0965A")
    # heart between them
    hx, hy = 128, 70
    i.add("ellipse", (hx - 34, hy - 22, hx + 2, hy + 14), c("#FF7A8A"), c("#E0304A"))
    i.add("ellipse", (hx - 2, hy - 22, hx + 34, hy + 14), c("#FF7A8A"), c("#E0304A"))
    i.add("poly", ((hx - 32, hy + 2), (hx + 32, hy + 2), (hx, hy + 38)), c("#F25468"), c("#D0283E"), gloss=False)
    return i


if __name__ == "__main__":
    import sys
    if "coop" in sys.argv:
        coop_icon().render("coop")
        raise SystemExit
    if "upgrades" in sys.argv:
        bed(up_badge, blanket="#3E5AC8").render("room_deluxe")
        bed(crown, blanket="#1F8F6A").render("room_suite")
        star_empty().render("star_empty")
        upgrade_icon().render("upgrade")
        names = ["room_deluxe", "room_suite", "star_empty", "upgrade", "star"]
        sheet = Image.new("RGBA", (len(names) * 160, 160), (225, 220, 235, 255))
        for k, n in enumerate(names):
            sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), (k * 160 + 5, 5))
        sheet.save(os.path.join(OUT, "_sheet_upgrades.png"))
        raise SystemExit
    if "staff" in sys.argv:
        janitor().render("janitor"); doorman().render("doorman"); staff_icon().render("staff")
        sheet = Image.new("RGBA", (3 * 160, 160), (225, 220, 235, 255))
        for k, n in enumerate(["janitor", "doorman", "staff"]):
            sheet.alpha_composite(Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS), (k * 160 + 5, 5))
        sheet.save(os.path.join(OUT, "_sheet_staff.png"))
        raise SystemExit
    bed().render("bed")
    bed(check).render("room_ready")
    bed(lambda i: person(i)).render("room_busy")
    bed(dust, sheet="#E8DCC8", blanket="#B88A6A").render("room_dirty")
    shower().render("shower")
    toilet().render("toilet")
    bell().render("bell")
    cash().render("cash")
    broom().render("clean")
    sparkle().render("sparkle")
    door().render("door")
    walk().render("walk")
    star().render("star")
    guest().render("guest")
    zzz().render("sleep")
    hammer().render("hammer")
    sofa_icon().render("cat_furniture")
    plant_icon().render("cat_decor")
    paddle().render("cat_fun")
    pile_icon().render("cat_all")
    rotate().render("rotate")
    move().render("move")
    sell().render("sell")
    close_icon().render("close")
    place_icon().render("place")
    # contact sheet for checking
    names = ["hammer", "cat_furniture", "cat_decor", "cat_fun", "cat_all", "rotate", "move", "sell", "close", "place"]
    sheet = Image.new("RGBA", (5 * 160, 3 * 160), (225, 220, 235, 255))
    for k, n in enumerate(names):
        im = Image.open(os.path.join(OUT, n + ".png")).resize((150, 150), Image.LANCZOS)
        sheet.alpha_composite(im, ((k % 5) * 160 + 5, (k // 5) * 160 + 5))
    sheet.save(os.path.join(OUT, "_sheet.png"))
