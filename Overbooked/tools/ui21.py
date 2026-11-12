"""Round 21 HUD glyphs: flat white icons on transparent -> export/g21/<name>.png (128 px, tinted in Studio).
  python ui21.py        (also writes export/g21_sheet.png)
One weight, round ends, no outlines or gloss: cash, guest, staff, hotel, hammer, check, research, upgrade, trophy,
phone, shop, settings, plus, clean, sun, moon, cloud, rain, storm, snow, fog, save, play, trash, bell, star, lock.
"""
import os, math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export", "g21")
os.makedirs(OUT, exist_ok=True)
N, S = 128, 4
G = {}


def glyph(fn):
    G[fn.__name__] = fn
    return fn


class C:
    """A supersampled mask with add / cut drawing in 128-px units."""
    def __init__(self):
        self.im = Image.new("L", (N * S, N * S), 0)
        self.d = ImageDraw.Draw(self.im)

    def _b(self, box):
        return [v * S for v in box]

    def rect(self, box, r=0, v=255):
        self.d.rounded_rectangle(self._b(box), radius=r * S, fill=v)

    def oval(self, box, v=255):
        self.d.ellipse(self._b(box), fill=v)

    def dot(self, x, y, r, v=255):
        self.oval((x - r, y - r, x + r, y + r), v)

    def poly(self, pts, v=255):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=v)

    def line(self, pts, w, v=255):
        p = [(x * S, y * S) for x, y in pts]
        self.d.line(p, fill=v, width=int(w * S), joint="curve")
        for x, y in pts:
            self.dot(x, y, w / 2, v)

    def arc(self, box, a0, a1, w, v=255):
        self.d.arc(self._b(box), a0, a1, fill=v, width=int(w * S))

    def soften(self, r):
        """Round every corner by r px (blur + threshold)."""
        self.im = self.im.filter(ImageFilter.GaussianBlur(r * S)).point(lambda p: 255 if p > 127 else 0)
        self.d = ImageDraw.Draw(self.im)

    def rotate(self, deg):
        self.im = self.im.rotate(deg, resample=Image.BICUBIC, center=(N * S / 2, N * S / 2))
        self.d = ImageDraw.Draw(self.im)

    def out(self):
        m = self.im.resize((N, N), Image.LANCZOS)
        o = Image.new("RGBA", (N, N), (255, 255, 255, 0))
        o.putalpha(m)
        return o


def person(c, cx, top, k=1.0, v=255):
    c.dot(cx, top + 17 * k, 17 * k, v)
    c.oval((cx - 31 * k, top + 40 * k, cx + 31 * k, top + 112 * k), v)


@glyph
def cash():
    c = C()
    c.rect((10, 34, 118, 94), 12)
    c.rect((20, 44, 108, 84), 6, 0)
    c.rect((24, 48, 104, 80), 4)
    c.dot(64, 64, 15, 0)
    c.dot(64, 64, 8)
    c.dot(34, 64, 4, 0)
    c.dot(94, 64, 4, 0)
    return c


@glyph
def guest():
    c = C()
    person(c, 64, 16)
    c.rect((0, 106, 128, 128), 0, 0)
    c.rect((33, 96, 95, 106), 5)
    return c


@glyph
def staff():
    c = C()
    person(c, 44, 30, 0.74)
    person(c, 84, 30, 0.74)
    c.rect((0, 108, 128, 128), 0, 0)
    c.oval((30, 54, 98, 134), 0)
    c.dot(64, 36, 22, 0)
    person(c, 64, 18, 0.92)
    c.rect((0, 106, 128, 128), 0, 0)
    c.rect((36, 97, 92, 106), 5)
    return c


@glyph
def hotel():
    c = C()
    c.rect((26, 30, 102, 110), 8)
    c.rect((40, 16, 88, 36), 6)
    for y in (44, 64):
        for x in (38, 58, 78):
            c.rect((x, y, x + 12, y + 12), 2, 0)
    c.rect((56, 86, 72, 110), 3, 0)
    c.rect((14, 104, 114, 114), 5)
    return c


@glyph
def hammer():
    c = C()
    c.rect((56, 44, 72, 116), 7)
    c.rect((28, 18, 100, 52), 9)
    c.rect((20, 24, 40, 46), 5)
    c.rotate(-38)
    return c


@glyph
def check():
    c = C()
    c.line([(26, 68), (52, 94), (102, 36)], 17)
    return c


@glyph
def research():
    c = C()
    c.poly([(52, 22), (76, 22), (76, 52), (106, 102), (98, 112), (30, 112), (22, 102), (52, 52)])
    c.soften(3)
    c.rect((44, 14, 84, 26), 6)
    c.poly([(44, 82), (84, 82), (95, 101), (33, 101)], 0)
    c.soften(1.5)
    c.dot(56, 92, 5)
    c.dot(72, 96, 3.5)
    return c


@glyph
def upgrade():
    c = C()
    c.line([(30, 64), (64, 30), (98, 64)], 16)
    c.line([(30, 100), (64, 66), (98, 100)], 16)
    return c


@glyph
def trophy():
    c = C()
    c.arc((14, 24, 54, 64), 60, 300, 9)
    c.arc((74, 24, 114, 64), 240, 120, 9)
    c.rect((36, 16, 92, 48), 5)
    c.oval((36, 14, 92, 82))
    c.rect((36, 12, 92, 20), 3)
    c.rect((57, 76, 71, 98), 2)
    c.rect((40, 96, 88, 112), 6)
    return c


@glyph
def phone():
    c = C()
    c.rect((36, 12, 92, 116), 13)
    c.rect((44, 26, 84, 94), 4, 0)
    c.dot(64, 105, 4.5, 0)
    return c


@glyph
def shop():
    c = C()
    c.arc((42, 14, 86, 70), 180, 360, 9)
    c.rect((24, 44, 104, 112), 12)
    c.dot(46, 58, 5, 0)
    c.dot(82, 58, 5, 0)
    return c


@glyph
def settings():
    c = C()
    for i in range(8):
        a = math.radians(i * 45)
        c.line([(64 + math.cos(a) * 30, 64 + math.sin(a) * 30), (64 + math.cos(a) * 46, 64 + math.sin(a) * 46)], 17)
    c.dot(64, 64, 36)
    c.dot(64, 64, 15, 0)
    return c


@glyph
def plus():
    c = C()
    c.line([(64, 26), (64, 102)], 18)
    c.line([(26, 64), (102, 64)], 18)
    return c


def sparkle(c, cx, cy, r):
    pts = []
    for i in range(96):
        t = i / 96 * 2 * math.pi
        ct, st = math.cos(t), math.sin(t)
        pts.append((cx + math.copysign(abs(ct) ** 3, ct) * r, cy + math.copysign(abs(st) ** 3, st) * r))
    c.poly(pts)


@glyph
def clean():
    c = C()
    sparkle(c, 54, 70, 46)
    sparkle(c, 98, 30, 24)
    return c


@glyph
def sun():
    c = C()
    for i in range(8):
        a = math.radians(i * 45)
        c.line([(64 + math.cos(a) * 42, 64 + math.sin(a) * 42), (64 + math.cos(a) * 54, 64 + math.sin(a) * 54)], 10)
    c.dot(64, 64, 26)
    return c


@glyph
def moon():
    c = C()
    c.dot(60, 66, 44)
    c.dot(82, 48, 38, 0)
    return c


def cloud_shape(c, y=0, k=1.0, x=0):
    c.dot(x + 44 * k, y + 62 * k, 22 * k)
    c.dot(x + 70 * k, y + 50 * k, 28 * k)
    c.dot(x + 94 * k, y + 66 * k, 18 * k)
    c.rect((x + 24 * k, y + 60 * k, x + 110 * k, y + 84 * k), 12 * k)


@glyph
def cloud():
    c = C()
    cloud_shape(c, 8)
    return c


@glyph
def rain():
    c = C()
    cloud_shape(c, -12)
    for x in (44, 66, 88):
        c.line([(x, 86), (x - 8, 108)], 9)
    return c


@glyph
def storm():
    c = C()
    cloud_shape(c, -12)
    c.poly([(70, 76), (48, 100), (62, 100), (54, 122), (86, 92), (70, 92), (80, 76)])
    return c


@glyph
def snow():
    c = C()
    cloud_shape(c, -12)
    for x, y in ((44, 92), (66, 104), (88, 92), (55, 116), (78, 116)):
        c.dot(x, y, 6)
    return c


@glyph
def fog():
    c = C()
    for i, (a, b) in enumerate(((22, 96), (34, 108), (18, 86), (40, 100))):
        c.line([(a, 34 + i * 20), (b, 34 + i * 20)], 11)
    return c


@glyph
def save():
    c = C()
    c.poly([(20, 28), (28, 20), (92, 20), (108, 36), (108, 100), (100, 108), (28, 108), (20, 100)])
    c.soften(3)
    c.rect((38, 20, 82, 46), 3, 0)
    c.rect((66, 24, 76, 42), 2)
    c.rect((36, 64, 92, 108), 5, 0)
    c.rect((44, 76, 84, 82), 3)
    c.rect((44, 90, 84, 96), 3)
    return c


@glyph
def play():
    c = C()
    c.poly([(40, 24), (104, 64), (40, 104)])
    c.soften(5)
    return c


@glyph
def trash():
    c = C()
    c.rect((22, 30, 106, 44), 6)
    c.rect((50, 18, 78, 34), 5)
    c.poly([(30, 50), (98, 50), (92, 112), (36, 112)])
    c.soften(3)
    for x in (52, 76):
        c.rect((x - 4, 62, x + 4, 100), 4, 0)
    return c


@glyph
def bell():
    c = C()
    c.oval((30, 26, 98, 110))
    c.rect((30, 68, 98, 96), 0)
    c.rect((18, 88, 110, 102), 7)
    c.rect((0, 102, 128, 128), 0, 0)
    c.dot(64, 22, 8)
    c.dot(64, 106, 9)
    return c


@glyph
def star():
    c = C()
    pts = []
    for i in range(10):
        r = 54 if i % 2 == 0 else 24
        a = math.radians(-90 + i * 36)
        pts.append((64 + math.cos(a) * r, 68 + math.sin(a) * r))
    c.poly(pts)
    c.soften(4)
    return c


@glyph
def lock():
    c = C()
    c.arc((36, 14, 92, 86), 180, 360, 11)
    c.rect((24, 54, 104, 114), 12)
    c.dot(64, 80, 8, 0)
    c.rect((60, 82, 68, 98), 3, 0)
    return c


@glyph
def close():
    c = C()
    c.line([(32, 32), (96, 96)], 17)
    c.line([(96, 32), (32, 96)], 17)
    return c


@glyph
def bed():
    c = C()
    c.rect((12, 30, 26, 104), 6)
    c.rect((12, 66, 116, 92), 8)
    c.rect((102, 66, 116, 104), 6)
    c.rect((32, 44, 66, 66), 8)
    return c


if __name__ == "__main__":
    names = list(G)
    sheet = Image.new("RGBA", (len(names) * 72 + 8, 152), (28, 32, 40, 255))
    for i, n in enumerate(names):
        im = G[n]().out()
        im.save(os.path.join(OUT, n + ".png"))
        sheet.alpha_composite(im.resize((64, 64), Image.LANCZOS), (8 + i * 72, 8))
        dark = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        small = im.resize((28, 28), Image.LANCZOS)
        sheet.alpha_composite(small, (26 + i * 72, 100))
    sheet.save(os.path.join(OUT, "..", "g21_sheet.png"))
    print(len(names), "glyphs:", " ".join(names))
