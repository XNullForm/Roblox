"""Round 16 city materials: tileable colour + normal + roughness maps -> export/t16/<name>_{c,n,r}.png
  python tex_r16.py
Colours are kept light and near-neutral so Part.Color / vertex colours tint them in Studio.
brick, stucco, stone (ashlar), asphalt, paver, roof (gravel), tower (curtain wall), leaf, bark
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export", "t16")
os.makedirs(OUT, exist_ok=True)
N = 1024


def fnoise(beta, seed, n=N):
    """Tileable 1/f^beta noise, 0..1."""
    r = np.random.default_rng(seed)
    f = np.fft.fft2(r.standard_normal((n, n)))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    v = np.real(np.fft.ifft2(f / k ** beta))
    v -= v.min()
    return v / v.max()


def sstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def grid(rows, cols, stagger, joint, bevel, seed, jit=0.0):
    """Face mask (0 joint .. 1 face), a random value per cell, and a second one."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    ch, cw = N / rows, N / cols
    row = np.floor(y / ch).astype(int)
    xo = x + (row % 2) * cw * stagger
    col = np.floor(xo / cw).astype(int) % cols
    u, v = xo % cw, y % ch
    d = np.minimum(np.minimum(u, cw - u), np.minimum(v, ch - v))
    r = np.random.default_rng(seed)
    if jit:
        d = d + (fnoise(1.6, seed + 5) - 0.5) * jit
    m = sstep(d, joint / 2, joint / 2 + bevel)
    a = r.random((rows, cols))[row % rows, col]
    b = r.random((rows, cols))[row % rows, col]
    return m, a, b


def save(name, col, h, rough, strength=6.0):
    col = np.clip(col, 0, 1)
    Image.fromarray((col * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_c.png"))
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    ln = np.sqrt(dx * dx + dy * dy + 1)
    nm = np.stack([0.5 - 0.5 * dx / ln, 0.5 + 0.5 * dy / ln, 0.5 + 0.5 * nz / ln], -1)
    Image.fromarray((np.clip(nm, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + "_n.png"))
    Image.fromarray((np.clip(rough, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, name + "_r.png"))
    print("saved", name)


def rgb(v, tint=(1, 1, 1)):
    return np.stack([v * tint[0], v * tint[1], v * tint[2]], -1)


def brick():
    m, a, b = grid(16, 8, 0.5, 9, 5, 1, jit=5)
    fine, big, pit = fnoise(0.6, 2), fnoise(2.0, 3), fnoise(1.1, 4)
    face = 0.70 + 0.20 * (a - 0.5) + 0.10 * (big - 0.5) + 0.07 * (fine - 0.5)
    face = np.where(b > 0.9, face * 0.82, face)  # the odd dark burnt brick
    mortar = 0.90 + 0.06 * (fine - 0.5)
    v = mortar * (1 - m) + face * m
    warm = 1 + 0.05 * (a - 0.5)[..., None] * np.array([1.0, 0.0, -1.0])
    col = rgb(v) * warm
    h = m * (0.75 + 0.12 * a) - 0.18 * sstep(pit, 0.62, 0.8) * m + 0.05 * fine
    save("brick", col, h, 0.80 + 0.12 * (1 - m) - 0.1 * (fine - 0.5), 7)


def stucco():
    fine, mid, big = fnoise(0.4, 11), fnoise(1.3, 12), fnoise(2.2, 13)
    y = np.mgrid[0:N, 0:N][0] / N
    streak = fnoise(2.0, 14)[:, :1] * np.ones((1, N))  # faint rain streaks run down
    v = 0.90 + 0.05 * (big - 0.5) + 0.04 * (mid - 0.5) - 0.03 * streak.T
    h = 0.5 * mid + 0.35 * fine
    save("stucco", rgb(v, (1, 0.995, 0.98)), h, 0.86 + 0.08 * (fine - 0.5), 3.2)


def stone():
    m, a, b = grid(4, 2, 0.5, 7, 9, 21)
    fine, big, pit = fnoise(0.7, 22), fnoise(2.1, 23), fnoise(1.0, 24)
    v = 0.86 + 0.08 * (a - 0.5) + 0.07 * (big - 0.5) + 0.04 * (fine - 0.5)
    v = v * (0.80 + 0.20 * m)
    h = m * 0.8 + 0.10 * fine - 0.12 * sstep(pit, 0.66, 0.8)
    save("stone", rgb(v, (1, 0.985, 0.95)), h, 0.62 + 0.2 * (1 - m) + 0.1 * (fine - 0.5), 5)


def asphalt():
    fine, grit, big = fnoise(0.15, 31), fnoise(0.7, 32), fnoise(2.4, 33)
    spark = (fnoise(0.0, 34) > 0.93).astype(float)
    v = 0.60 + 0.16 * (grit - 0.5) + 0.12 * (big - 0.5) + 0.10 * spark
    crack = np.abs(fnoise(1.9, 35) - 0.5)
    cm = 1 - sstep(crack, 0.0, 0.006)
    v = v * (1 - 0.35 * cm)
    h = 0.5 * grit + 0.5 * fine - 0.5 * cm
    save("asphalt", rgb(v), h, 0.88 - 0.25 * spark, 5)


def paver():
    m, a, b = grid(4, 4, 0.0, 6, 5, 41)
    fine, big, speck = fnoise(0.5, 42), fnoise(2.0, 43), fnoise(0.0, 44)
    v = 0.84 + 0.08 * (a - 0.5) + 0.07 * (big - 0.5) + 0.05 * (fine - 0.5) - 0.10 * (speck > 0.95) + 0.06 * (speck < 0.04)
    v = v * (0.62 + 0.38 * m)
    h = m * 0.7 + 0.08 * fine
    save("paver", rgb(v, (1, 0.99, 0.97)), h, 0.78 + 0.15 * (1 - m), 5)


def roof():
    g1, g2, big = fnoise(0.0, 51), fnoise(0.5, 52), fnoise(2.2, 53)
    v = 0.55 + 0.30 * (g2 - 0.5) + 0.14 * (g1 - 0.5) + 0.10 * (big - 0.5)
    save("roof", rgb(v, (1, 0.98, 0.95)), 0.6 * g2 + 0.4 * g1, 0.9 + 0 * g1, 7)


def tower():
    m, a, b = grid(4, 6, 0.0, 14, 3, 61)
    y, x = np.mgrid[0:N, 0:N] / N
    sky = 0.30 + 0.22 * ((y * 4) % 1)  # each pane reflects a little sky gradient
    pane = sky + 0.14 * (a - 0.5) + np.where(b > 0.82, 0.16, 0)
    span = ((y * 4) % 1 > 0.78).astype(float)  # the spandrel band under each floor
    pane = pane * (1 - span) + (0.56 + 0.05 * a) * span
    v = 0.93 * (1 - m) + pane * m
    col = rgb(v) * (1 - m[..., None]) + rgb(v, (0.80, 0.92, 1.06)) * m[..., None]
    h = (1 - m) * 1.0 + 0.04 * a * m
    rough = 0.55 * (1 - m) + (0.08 + 0.5 * span) * m
    save("tower", col, h, rough, 6)


def leaf():
    r = np.random.default_rng(71)
    h = np.zeros((N, N))
    shade = np.zeros((N, N))
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    for i in range(1500):
        cx, cy = r.random(2) * N
        L, W = r.uniform(34, 58), r.uniform(13, 22)
        an = r.uniform(0, np.pi * 2)
        ca, sa = np.cos(an), np.sin(an)
        dx = (xx - cx + N / 2) % N - N / 2
        dy = (yy - cy + N / 2) % N - N / 2
        box = (np.abs(dx) < L + 2) & (np.abs(dy) < L + 2)
        u = (dx[box] * ca + dy[box] * sa) / L
        w = (-dx[box] * sa + dy[box] * ca) / W
        e = 1 - (np.abs(u) ** 1.7 + (np.abs(w) * (1 + 0.5 * u)) ** 2)  # a leaf: pointed one end
        inside = e > 0
        z = i / 1500.0
        hv = z * 0.6 + 0.4 * np.clip(e, 0, 1) ** 0.5 - 0.1 * np.exp(-(w * 7) ** 2)  # mid-rib crease
        cur = h[box]
        take = inside & (hv > cur - 0.2) & (z * 0.6 + 0.2 > cur * 0.6)
        cur[take] = hv[take]
        h[box] = cur
        sh = shade[box]
        sh[take] = r.uniform(-1, 1)
        shade[box] = sh
    fine = fnoise(0.8, 72)
    v = 0.74 + 0.12 * shade + 0.20 * (h - 0.5) + 0.04 * (fine - 0.5)
    col = rgb(v, (0.98, 1.0, 0.92))
    save("leaf", col, h, 0.55 + 0.2 * (1 - h), 5)


def bark():
    y, x = np.mgrid[0:N, 0:N] / N
    warp = fnoise(2.0, 81) * 0.10 + fnoise(1.2, 82) * 0.03
    ridges = np.abs(np.sin((x + warp) * np.pi * 14)) ** 0.6
    stretch = np.repeat(fnoise(1.4, 83, 256)[:64, :], 4, 1)
    stretch = np.repeat(stretch, 16, 0)  # noise pulled long down the trunk
    h = ridges * (0.7 + 0.3 * stretch) + 0.15 * fnoise(0.6, 84)
    h = h / h.max()
    v = 0.52 + 0.40 * h + 0.06 * (stretch - 0.5)
    save("bark", rgb(v, (1, 0.97, 0.93)), h, 0.9 - 0.1 * h, 6)


if __name__ == "__main__":
    import sys
    for f in ([leaf] if 'leaf' in sys.argv else (brick, stucco, stone, asphalt, paver, roof, tower, leaf, bark)):
        f()
    names = ["brick", "stucco", "stone", "asphalt", "paver", "roof", "tower", "leaf", "bark"]
    sheet = Image.new("RGB", (9 * 260, 2 * 260), (30, 30, 30))
    for i, n in enumerate(names):
        for j, k in enumerate("cn"):
            sheet.paste(Image.open(os.path.join(OUT, "%s_%s.png" % (n, k))).resize((256, 256)), (i * 260 + 2, j * 260 + 2))
    sheet.save(os.path.join(HERE, "export", "t16_sheet.png"))
