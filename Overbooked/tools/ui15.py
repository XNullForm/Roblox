"""Round 15 UI kit bitmaps -> export/ui15_*.png (white art, tinted in Studio)."""
import os, math
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "export")
S = 4
def save(im, name): im.save(os.path.join(OUT, "ui15_%s.png" % name)); print(name, im.size)

# soft drop shadow, 9-slice (centre 48..80 of 128)
im = Image.new("L", (128 * S, 128 * S), 0)
d = ImageDraw.Draw(im)
d.rounded_rectangle((28 * S, 28 * S, 100 * S, 100 * S), 18 * S, fill=255)
im = im.filter(ImageFilter.GaussianBlur(11 * S)).resize((128, 128), Image.LANCZOS)
out = Image.new("RGBA", (128, 128), (255, 255, 255, 0)); out.putalpha(im)
save(out, "shadow")

# speech bubble tail: a curved wedge pointing down, 40x28
W, H = 40, 28
im = Image.new("L", (W * S, H * S), 0)
d = ImageDraw.Draw(im)
pts = []
for i in range(41):
    t = i / 40
    x = 4 + 22 * t
    y = 0 + 26 * (t ** 2.2)
    pts.append((x * S, y * S))
for i in range(41):
    t = 1 - i / 40
    x = 36 - 10 * (1 - t)
    y = 26 * (t ** 1.3)
    pts.append((x * S, y * S))
d.polygon([(4 * S, 0)] + pts + [(36 * S, 0)], fill=255)
im = im.resize((W, H), Image.LANCZOS)
out = Image.new("RGBA", (W, H), (255, 255, 255, 0)); out.putalpha(im)
save(out, "tail")

# dotted pattern tile 32x32 (two dots, offset rows)
im = Image.new("L", (32 * S, 32 * S), 0)
d = ImageDraw.Draw(im)
for (x, y) in ((8, 8), (24, 24)):
    d.ellipse(((x - 2.2) * S, (y - 2.2) * S, (x + 2.2) * S, (y + 2.2) * S), fill=255)
im = im.resize((32, 32), Image.LANCZOS)
out = Image.new("RGBA", (32, 32), (255, 255, 255, 0)); out.putalpha(im)
save(out, "dots")

# diagonal pinstripe tile 32x32
im = Image.new("L", (32 * S, 32 * S), 0)
d = ImageDraw.Draw(im)
for k in range(-4, 8):
    x = k * 16 * S
    d.line((x, 32 * S, x + 32 * S, 0), fill=255, width=int(3.2 * S))
im = im.resize((32, 32), Image.LANCZOS)
out = Image.new("RGBA", (32, 32), (255, 255, 255, 0)); out.putalpha(im)
save(out, "stripes")

# scallop strip (ticket edge): white with half-circle bites along the bottom, tile 24x12
im = Image.new("L", (24 * S, 12 * S), 255)
d = ImageDraw.Draw(im)
d.ellipse((4 * S, 4 * S, 20 * S, 20 * S), fill=0)
im = im.resize((24, 12), Image.LANCZOS)
out = Image.new("RGBA", (24, 12), (255, 255, 255, 0)); out.putalpha(im)
save(out, "scallop")

# a 9-slice rounded "key tag": rounded rect with a punched hole on the left, 96x48, slice (40,16,80,32)
im = Image.new("L", (96 * S, 48 * S), 0)
d = ImageDraw.Draw(im)
d.rounded_rectangle((0, 0, 96 * S - 1, 48 * S - 1), 14 * S, fill=255)
d.ellipse((12 * S, 17 * S, 26 * S, 31 * S), fill=0)
im = im.resize((96, 48), Image.LANCZOS)
out = Image.new("RGBA", (96, 48), (255, 255, 255, 0)); out.putalpha(im)
save(out, "tag")

# soft round glow/vignette 256 (for spotlights and the first-person talk vignette), white centre -> transparent
im = Image.new("L", (256, 256), 0)
px = im.load()
for y in range(256):
    for x in range(256):
        r = math.hypot(x - 127.5, y - 127.5) / 127.5
        px[x, y] = int(255 * max(0, 1 - r) ** 1.6)
out = Image.new("RGBA", (256, 256), (255, 255, 255, 0)); out.putalpha(im)
save(out, "soft")

# vignette: transparent centre, opaque edges (512x288)
im = Image.new("L", (512, 288), 0)
px = im.load()
for y in range(288):
    for x in range(512):
        u, v = (x - 255.5) / 255.5, (y - 143.5) / 143.5
        r = math.sqrt(u * u * 0.85 + v * v * 0.85)
        px[x, y] = int(255 * min(1, max(0, (r - 0.55) / 0.6)) ** 1.5)
out = Image.new("RGBA", (512, 288), (255, 255, 255, 0)); out.putalpha(im)
save(out, "vignette")
