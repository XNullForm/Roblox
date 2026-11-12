"""Round 10 hotel surface textures (tileable PNGs) -> ui/tex_*.png (served on 8792 for upload_image).
  python tex_r10.py
checker  : lobby floor, cream and deep green marble squares with veins and thin grout
chevron  : room floor, warm oak chevron planks
brick    : facade, running bond red-brown brick with pale mortar
paper    : wallpaper, near-white with soft stripes and a fine pinstripe (tinted per wall in Studio)
hex      : bathroom floor, white hex tiles with grey grout
carpet   : corridor runner, deep teal with a small gold diamond lattice
"""
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ui")
rng = np.random.default_rng(10)


def tile_noise(n, scale, octaves=4, seed=0):
    """Tileable value noise in 0..1 (sum of wrapped bilinear-upsampled random grids)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        g = max(2, int(scale * 2 ** o))
        grid = r.random((g, g))
        ys = np.arange(n) * g / n
        y0 = np.floor(ys).astype(int)
        fy = (ys - y0)[:, None]
        fx = (ys - y0)[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        a = grid[np.ix_(y0 % g, y0 % g)]
        b = grid[np.ix_(y0 % g, (y0 + 1) % g)]
        c = grid[np.ix_((y0 + 1) % g, y0 % g)]
        d = grid[np.ix_((y0 + 1) % g, (y0 + 1) % g)]
        v = a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy
        acc += v * amp
        tot += amp
        amp *= 0.5
    return acc / tot


def save(name, rgb, height=None, rough=None, depth=3.0):
    """Colour map, plus a normal map from `height` (0..1, OpenGL / +Y up, as Roblox wants) and a roughness map."""
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    img.save(os.path.join(OUT, "tex_%s.png" % name))
    if height is not None:
        dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * depth
        dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * depth
        nrm = np.stack([-dx, dy, np.ones_like(height)], -1)
        nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
        Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "tex_%s_n.png" % name))
    if rough is not None:
        r = np.broadcast_to(np.asarray(rough, float), rgb.shape[:2])
        Image.fromarray(np.clip(r * 255, 0, 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "tex_%s_r.png" % name))
    print("wrote", name, img.size)


def veins(n, seed, scale=3, sharp=40):
    """Marble veins: ridged noise (thin lines where the noise crosses its middle)."""
    w = tile_noise(n, scale, 5, seed)
    return np.exp(-((w - 0.5) ** 2) * sharp * 60)


def checker():
    n = 1024
    half = n // 2
    yy, xx = np.mgrid[0:n, 0:n]
    sq = ((xx // half) + (yy // half)) % 2
    cream = np.array([236, 228, 212], float)
    green = np.array([30, 54, 48], float)
    cloud = tile_noise(n, 4, 5, 3)
    v1 = veins(n, 5, 2, 260) * 0.8
    v2 = veins(n, 9, 4, 400) * 0.5
    base = np.where(sq[..., None] == 0, cream, green)
    tone = (cloud[..., None] - 0.5) * np.where(sq[..., None] == 0, 26, 18)
    vein = np.where(sq[..., None] == 0, -(v1 * 34 + v2 * 14)[..., None] * np.array([1.0, 1.0, 0.9]),
                    (v1 * 46 + v2 * 18)[..., None] * np.array([0.9, 1.0, 0.95]))
    rgb = base + tone + vein
    # thin grout lines (with a faint bevel highlight)
    gx = np.minimum(xx % half, half - 1 - xx % half)
    gy = np.minimum(yy % half, half - 1 - yy % half)
    g = np.minimum(gx, gy)
    rgb = np.where((g < 2)[..., None], np.array([150, 140, 120], float), rgb)
    rgb = np.where(((g >= 2) & (g < 5))[..., None], rgb * 1.06, rgb)
    height = np.clip((g - 1) / 4, 0, 1)
    rough = np.where(g < 2, 0.85, 0.22 + 0.08 * cloud)
    save("checker", rgb, height, rough, 2.0)


def chevron():
    n = 1024
    S = 128  # strip width (px)
    P = 64   # plank pitch measured along the strip (px)
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    k = (xx // S).astype(int)
    lx = xx - k * S
    up = (k % 2 == 0)
    t = np.where(up, yy + lx, yy - lx + S)
    pid = np.floor(t / P).astype(int)
    frac = t / P - pid
    # tone per plank (hash of strip and plank index, wrapped so it tiles)
    nk, npk = n // S, int(np.ceil((n + S) / P)) + 2
    tones = rng.random((nk, npk + 4))
    tone = tones[k % nk, (pid % (n // P)) % npk]
    oak = np.array([196, 144, 96], float)
    oak2 = np.array([170, 116, 72], float)
    base = oak[None, None, :] * (1 - tone[..., None]) + oak2[None, None, :] * tone[..., None]
    # grain runs along the plank: stretch noise along its direction
    g2 = tile_noise(n, 4, 3, 11)
    fine = tile_noise(n, 128, 1, 3)
    across = np.where(up, xx + yy, yy - xx)
    grain = np.sin(across * 0.55 + g2 * 30 + tone * 20) * 0.5 + 0.5
    grain2 = np.sin(across * 0.13 + g2 * 12) * 0.5 + 0.5
    rgb = base * (0.9 + 0.07 * grain[..., None] + 0.06 * grain2[..., None] + 0.02 * fine[..., None])
    # seams between planks and between strips
    seam = (frac < 0.035) | (frac > 0.975)
    edge = (lx < 2) | (lx > S - 3)
    rgb = np.where((seam | edge)[..., None], rgb * 0.55, rgb)
    rgb = np.where(((frac > 0.035) & (frac < 0.08))[..., None], rgb * 1.05, rgb)
    height = np.where(seam | edge, 0.0, 1.0) - 0.04 * grain
    rough = np.where(seam | edge, 0.9, 0.42 + 0.12 * grain)
    save("chevron", rgb, height, rough, 1.5)


def brick():
    n = 1024
    rows, cols = 16, 8
    bh, bw = n // rows, n // cols
    yy, xx = np.mgrid[0:n, 0:n]
    r = yy // bh
    off = np.where(r % 2 == 0, 0, bw // 2)
    c = ((xx + off) // bw) % cols
    lx = (xx + off) % bw
    ly = yy % bh
    tones = rng.random((rows, cols))
    t = tones[r % rows, c]
    a = np.array([164, 78, 58], float)
    b = np.array([128, 58, 46], float)
    hi = np.array([186, 104, 76], float)
    base = a * (1 - t[..., None]) + b * t[..., None]
    base = np.where((tones[r % rows, c] > 0.88)[..., None], hi, base)
    sp = tile_noise(n, 40, 2, 4)
    cl = tile_noise(n, 6, 3, 8)
    rgb = base * (0.86 + 0.22 * sp[..., None]) * (0.94 + 0.12 * cl[..., None])
    m = 5
    mortar = (lx < m) | (ly < m)
    mort = np.array([206, 198, 184], float) * (0.92 + 0.1 * sp[..., None])
    rgb = np.where(mortar[..., None], mort, rgb)
    # a soft shadow under each brick's top edge (recessed mortar)
    rgb = np.where(((ly >= m) & (ly < m + 3))[..., None], rgb * 0.82, rgb)
    edge = np.minimum(np.minimum(lx - m, bw - 1 - lx), np.minimum(ly - m, bh - 1 - ly))
    height = np.where(mortar, 0.0, np.clip(edge / 4.0, 0, 1) * (0.85 + 0.15 * sp))
    save("brick", rgb, height, 0.88 + 0.1 * sp, 3.0)


def paper():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n]
    base = np.full((n, n, 3), 246.0)
    band = (xx // 64) % 2
    base -= band[..., None] * 7
    pin = (xx % 64 == 0) | (xx % 64 == 1)
    base = np.where(pin[..., None], base - np.array([22, 26, 40]), base)
    # a faint woven texture
    w = tile_noise(n, 64, 2, 5)
    base *= (0.97 + 0.04 * w[..., None])
    # small diamond motif in the darker bands
    cx = (xx % 64) - 32
    cy = (yy % 64) - 32
    dia = (np.abs(cx) + np.abs(cy) < 7) & (band == 1)
    base = np.where(dia[..., None], base - 12, base)
    save("paper", base, 0.08 * w + 0.04 * band, 0.75, 4.0)


def hexes():
    n = 512
    s = n / 8  # hex size so the pattern wraps: width = sqrt(3)*s is not integral, so use an axial grid fit
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    # pointy hexes on a grid of period (w, 1.5 s) fitted to the image
    cols, rows = 8, 10
    w = n / cols
    h = n / rows  # row pitch
    R = h / 1.5
    best = np.full((n, n), 1e9)
    edge = np.full((n, n), 1e9)
    for r in range(-1, rows + 1):
        for c in range(-1, cols + 1):
            cx = c * w + (w / 2 if r % 2 else 0)
            cy = r * h
            dx = np.abs(xx - cx)
            dy = np.abs(yy - cy) * (1.5 * (w / 1.732) / h)
            Rr = w / 1.732
            d = np.maximum(dx, dx * 0.5 + dy * 0.866) / (Rr * 0.866)  # pointy hex distance (1 at the edge)
            d = np.minimum(d, best)
            best = d
    g = best
    tile = np.array([244, 244, 240], float) * (0.97 + 0.04 * tile_noise(n, 8, 2, 2)[..., None])
    grout = np.array([150, 154, 156], float)
    rgb = np.where((g > 0.93)[..., None], grout, tile)
    rgb = np.where(((g > 0.85) & (g <= 0.93))[..., None], tile * 0.94, rgb)
    height = np.clip((0.95 - g) / 0.1, 0, 1)
    save("hex", rgb, height, np.where(g > 0.93, 0.9, 0.2), 3.0)


def carpet():
    n = 512
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    base = np.array([22, 78, 74], float)
    fib = tile_noise(n, 96, 2, 6)
    rgb = base * (0.88 + 0.2 * fib[..., None])
    p = 64
    u = (xx + yy) % p
    v = (xx - yy) % p
    line = (np.abs(u - p / 2) < 1.6) | (np.abs(v - p / 2) < 1.6)
    gold = np.array([204, 166, 86], float)
    rgb = np.where(line[..., None], gold * (0.85 + 0.2 * fib[..., None]), rgb)
    dot = ((xx % p - p / 2) ** 2 + (yy % p - p / 2) ** 2) < 30
    rgb = np.where(dot[..., None], gold, rgb)
    save("carpet", rgb, fib * 0.6, 1.0, 3.0)


if __name__ == "__main__":
    checker()
    chevron()
    brick()
    paper()
    hexes()
    carpet()
