"""Round 15 v2 UI bitmaps -> export/ui16_*.png (white art, tinted in Studio)."""
import os, math
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
S = 4
def save(im, name): im.save(os.path.join(OUT, "ui16_%s.png" % name)); print(name, im.size)
def alpha_img(L):
    out = Image.new("RGBA", L.size, (255, 255, 255, 0)); out.putalpha(L); return out

# radial glow 256
N = 256
im = Image.new("L", (N, N), 0)
px = im.load()
for y in range(N):
    for x in range(N):
        r = math.hypot(x - N / 2 + 0.5, y - N / 2 + 0.5) / (N / 2)
        a = max(0.0, 1 - r) ** 2.2
        px[x, y] = int(255 * a)
save(alpha_img(im), "glow")

# 4-point sparkle 128
N = 128
im = Image.new("L", (N * S, N * S), 0)
d = ImageDraw.Draw(im)
c = N * S / 2
pts = []
for i in range(256):
    t = i / 256 * 2 * math.pi
    ct, st = math.cos(t), math.sin(t)
    pts.append((c + math.copysign(abs(ct) ** 4.2, ct) * c * 0.96, c + math.copysign(abs(st) ** 4.2, st) * c * 0.96))
d.polygon(pts, fill=255)
im = im.filter(ImageFilter.GaussianBlur(1.5 * S)).resize((N, N), Image.LANCZOS)
save(alpha_img(im), "sparkle")

# 5-point star with rounded points 128 (filled) and an outline version
def star_poly(cx, cy, ro, ri, n=5, rot=-90):
    p = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180 / n)
        p.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return p
N = 128
for name, outline in (("star", False), ("starLine", True)):
    im = Image.new("L", (N * S, N * S), 0)
    d = ImageDraw.Draw(im)
    c = N * S / 2
    poly = star_poly(c, c * 1.06, c * 0.9, c * 0.42)
    d.polygon(poly, fill=255)
    # round the tips: a blur + threshold pass
    im = im.filter(ImageFilter.GaussianBlur(5 * S)).point(lambda v: 255 if v > 128 else 0)
    if outline:
        inner = Image.new("L", im.size, 0)
        di = ImageDraw.Draw(inner)
        di.polygon(star_poly(c, c * 1.06, c * 0.62, c * 0.29), fill=255)
        inner = inner.filter(ImageFilter.GaussianBlur(4 * S)).point(lambda v: 255 if v > 128 else 0)
        im = Image.composite(Image.new("L", im.size, 0), im, inner)
    im = im.filter(ImageFilter.GaussianBlur(0.6 * S)).resize((N, N), Image.LANCZOS)
    save(alpha_img(im), name)

# star shading overlay: soft top highlight in the star's shape (draw over a tinted star)
im = Image.new("L", (N * S, N * S), 0)
d = ImageDraw.Draw(im)
c = N * S / 2
d.polygon(star_poly(c, c * 1.06, c * 0.9, c * 0.42), fill=255)
im = im.filter(ImageFilter.GaussianBlur(5 * S)).point(lambda v: 255 if v > 128 else 0)
grad = Image.new("L", im.size, 0)
gp = grad.load()
for y in range(im.size[1]):
    v = int(255 * max(0, 1 - y / (im.size[1] * 0.62)) ** 1.4)
    for x in range(im.size[0]):
        gp[x, y] = v
im = Image.composite(grad, Image.new("L", im.size, 0), im).resize((N, N), Image.LANCZOS)
save(alpha_img(im), "starGloss")

# inner shadow 9-slice (128, centre 40..88): dark at the top edge, fading in
N = 128
L = Image.new("L", (N * S, N * S), 0)
d = ImageDraw.Draw(L)
d.rectangle((0, 0, N * S, N * S), fill=255)
hole = Image.new("L", (N * S, N * S), 0)
dh = ImageDraw.Draw(hole)
dh.rounded_rectangle((10 * S, 16 * S, 118 * S, 118 * S), 26 * S, fill=255)
hole = hole.filter(ImageFilter.GaussianBlur(7 * S))
L = Image.composite(Image.new("L", L.size, 0), L, hole)
mask = Image.new("L", (N * S, N * S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, N * S - 1, N * S - 1), 32 * S, fill=255)
L = Image.composite(L, Image.new("L", L.size, 0), mask).resize((N, N), Image.LANCZOS)
save(alpha_img(L), "inner")

# confetti-free soft pattern: tiny plus signs, 48 tile
N = 48
im = Image.new("L", (N * S, N * S), 0)
d = ImageDraw.Draw(im)
for (x, y) in ((12, 12), (36, 36)):
    d.rounded_rectangle(((x - 4) * S, (y - 1.2) * S, (x + 4) * S, (y + 1.2) * S), 1.2 * S, fill=255)
    d.rounded_rectangle(((x - 1.2) * S, (y - 4) * S, (x + 1.2) * S, (y + 4) * S), 1.2 * S, fill=255)
im = im.resize((N, N), Image.LANCZOS)
save(alpha_img(im), "plus")

# light rays (a burst behind rewards) 256
N = 256
im = Image.new("L", (N * S, N * S), 0)
d = ImageDraw.Draw(im)
c = N * S / 2
for i in range(12):
    a0 = math.radians(i * 30 - 6)
    a1 = math.radians(i * 30 + 6)
    d.polygon([(c, c), (c + math.cos(a0) * c * 1.5, c + math.sin(a0) * c * 1.5), (c + math.cos(a1) * c * 1.5, c + math.sin(a1) * c * 1.5)], fill=255)
rad = Image.new("L", im.size, 0)
rp = rad.load()
for y in range(0, im.size[1]):
    for x in range(0, im.size[0]):
        r = math.hypot(x - c, y - c) / c
        rp[x, y] = int(255 * max(0, 1 - r) ** 1.2)
im = Image.composite(rad, Image.new("L", im.size, 0), im).filter(ImageFilter.GaussianBlur(2 * S)).resize((N, N), Image.LANCZOS)
save(alpha_img(im), "rays")

# speech tail with a matching outline (stacked: rim under, fill over), 48x34
W, H = 48, 34
def tail_mask(grow):
    im = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(im)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append(((8 + 22 * t) * S, (0 + 26 * (t ** 2.2)) * S))
    for i in range(41):
        t = 1 - i / 40
        pts.append(((40 - 10 * (1 - t)) * S, (26 * (t ** 1.3)) * S))
    d.polygon([(8 * S, 0)] + pts + [(40 * S, 0)], fill=255)
    if grow:
        im = im.filter(ImageFilter.MaxFilter(2 * grow * S + 1))
    return im.filter(ImageFilter.GaussianBlur(0.5 * S)).resize((W, H), Image.LANCZOS)
fill = tail_mask(0)
rim = tail_mask(3)
# the rim stops at the top edge (the bubble's own rim covers the join)
save(alpha_img(fill), "tailFill")
save(alpha_img(rim), "tailRim")
