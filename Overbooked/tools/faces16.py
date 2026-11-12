"""Round 16: the NPC face kit v2 -> export/f16/<name>.png (512x512, transparent).
Layers on the ClassicHead's front (same uv layout and crop as faces15):
  eye_<style>_<state>   eyes only (10 styles x 11 states): fa fb fc fd (women), ma mb mc md (men), ka (kids), ea (elders)
  brow_<style>_<kind>   white brows, tinted in game to the hair colour (5 styles x 7 kinds)
  mouth_<set>_<shape>   13 shapes x 2 sets (m: ink line, f: rose lips)
  nose_<n>              3 noses (static)
  mark_<n>              freckles, mole, wrinkles, rosy, freckles2 (static)
  fhair_<n>             white facial hair, tinted in game: stubble, moustache, goatee, beard, handlebar
  blush                 emotional blush
Drawn 4x and scaled down.
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export", "f16")
SS = 4
N = 512 * SS

INK = (34, 22, 26, 255)
WHITE = (255, 255, 255, 255)
SCLERA = (252, 250, 248, 255)
LINE_M = (60, 26, 32, 255)
LINE_F = (150, 52, 74, 255)
MOUTH_IN = (104, 26, 40, 255)
TONGUE = (234, 108, 120, 255)
TEETH = (255, 255, 255, 255)

EYE_L, EYE_R, EYE_V = 0.393, 0.607, 0.432
BROW_DV = 0.09
MOUTH_V = 0.618
ZOOM, ZC = 1.62, (0.5, 0.545)


def P(u, v):
    return (u * N, v * N)


def S(x):
    return x * N


def new():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def save(img, name):
    half = N / ZOOM / 2
    cx, cy = ZC[0] * N, ZC[1] * N
    img = img.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


def ellipse(d, cu, cv, w, h, fill=None, outline=None, width=0):
    d.ellipse([S(cu - w / 2), S(cv - h / 2), S(cu + w / 2), S(cv + h / 2)], fill=fill, outline=outline,
              width=int(S(width)) if width else 0)


def thick(d, pts, w, col):
    px = [P(u, v) for u, v in pts]
    d.line(px, fill=col, width=max(1, int(S(w))), joint="curve")
    r = S(w) / 2
    for x, y in (px[0], px[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def taper(d, pts, w0, w1, col, wmid=None):
    """a stroke whose width goes w0 -> (wmid) -> w1, filled as a polygon"""
    n = len(pts)
    left, right = [], []
    for i, (u, v) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        l = math.hypot(tx, ty) or 1
        nx, ny = -ty / l, tx / l
        t = i / (n - 1)
        if wmid is not None:
            w = w0 + (wmid - w0) * (t / 0.5) if t < 0.5 else wmid + (w1 - wmid) * ((t - 0.5) / 0.5)
        else:
            w = w0 + (w1 - w0) * t
        left.append((u + nx * w / 2, v + ny * w / 2))
        right.append((u - nx * w / 2, v - ny * w / 2))
    d.polygon([P(u, v) for u, v in left + right[::-1]], fill=col)


def bez(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def cubic(p0, p1, p2, p3, n=30):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + e * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + e * p3[1]))
    return out


def clip(layer, mask):
    return Image.composite(layer, Image.new("RGBA", (N, N), (0, 0, 0, 0)), mask)


def mask_poly(poly_uv):
    m = Image.new("L", (N, N), 0)
    ImageDraw.Draw(m).polygon([P(u, v) for u, v in poly_uv], fill=255)
    return m


# ------------------------------------------------------------------ eyes

# shape: round | almond | bean.  tilt: outer corner up (rad).  iris colour or None.
# lash: 0 none, 1 flicks, 2 flicks + lower lashes, 3 winged liner.  lid: upper lid line width.
# hood: share of the eye always covered from the top.  extra: "wrinkles" for elders
EYES = {
    "fa": dict(shape="round", w=0.074, h=0.094, iris=(64, 116, 186), ir=0.62, lash=1, lid=0.012, tilt=0.0),
    "fb": dict(shape="almond", w=0.086, h=0.07, iris=(70, 136, 84), ir=0.66, lash=3, lid=0.013, tilt=0.12),
    "fc": dict(shape="round", w=0.08, h=0.102, iris=(118, 72, 42), ir=0.66, lash=2, lid=0.012, tilt=0.0),
    "fd": dict(shape="bean", w=0.056, h=0.086, iris=None, lash=1, lid=0.0, tilt=0.0),
    "ma": dict(shape="round", w=0.072, h=0.086, iris=(110, 70, 40), ir=0.6, lash=0, lid=0.011, tilt=0.0),
    "mb": dict(shape="almond", w=0.084, h=0.06, iris=(90, 118, 146), ir=0.7, lash=0, lid=0.013, tilt=0.04),
    "mc": dict(shape="bean", w=0.052, h=0.08, iris=None, lash=0, lid=0.0, tilt=0.0),
    "md": dict(shape="almond", w=0.08, h=0.07, iris=(128, 104, 58), ir=0.68, lash=0, lid=0.014, tilt=-0.03, hood=0.22),
    "ka": dict(shape="round", w=0.086, h=0.104, iris=(84, 54, 36), ir=0.74, lash=0, lid=0.011, tilt=0.0, big=True),
    "ea": dict(shape="almond", w=0.068, h=0.056, iris=(92, 96, 104), ir=0.66, lash=0, lid=0.012, tilt=-0.05, hood=0.18, extra="wrinkles"),
}


def eye_outline(st, cu, side, sc):
    """the open eye's outline (uv points) and its top edge (for the lid line)"""
    w, h = st["w"] * sc, st["h"] * sc
    cv = EYE_V
    tilt = st.get("tilt", 0) * (1 if side > 0 else -1)
    if st["shape"] == "almond":
        L, R = (cu - w / 2, cv), (cu + w / 2, cv)
        top = bez(L, (cu - w * 0.05, cv - h * 1.15), R, 28)
        bot = bez(R, (cu + w * 0.05, cv + h * 0.85), L, 28)
        pts = top + bot[1:]
    else:
        pts = [(cu + math.cos(a) * w / 2, cv + math.sin(a) * h / 2) for a in [math.pi + i / 48 * 2 * math.pi for i in range(49)]]
        top = pts[:25]
    # tilt about the centre: the outer corner goes up
    def rot(p):
        x, y = p[0] - cu, p[1] - cv
        a = -tilt
        return (cu + x * math.cos(a) - y * math.sin(a), cv + x * math.sin(a) + y * math.cos(a))
    return [rot(p) for p in pts], [rot(p) for p in top]


def eye_open(st, cu, side, sc=1.0, look=(0, 0)):
    img = new()
    d = ImageDraw.Draw(img)
    cv = EYE_V
    w, h = st["w"] * sc, st["h"] * sc
    if st["shape"] == "bean":
        ellipse(d, cu, cv, w, h, fill=INK)
        ellipse(d, cu + w * 0.18, cv - h * 0.2, w * 0.4, w * 0.4, fill=WHITE)
        ellipse(d, cu - w * 0.16, cv + h * 0.22, w * 0.16, w * 0.16, fill=WHITE)
        if st["lash"]:
            for k in range(2):
                a = math.radians(150 + 22 * k) if side < 0 else math.radians(30 - 22 * k)
                x0, y0 = cu + math.cos(a) * w * 0.46, cv - math.sin(a) * h * 0.46
                taper(d, [(x0, y0), (x0 + math.cos(a) * 0.026, y0 - math.sin(a) * 0.022)], 0.009, 0.002, INK)
        return img
    outline, top = eye_outline(st, cu, side, sc)
    m = mask_poly(outline)
    inner = new()
    di = ImageDraw.Draw(inner)
    di.polygon([P(u, v) for u, v in outline], fill=SCLERA)
    # iris, pupil and two highlights
    r = min(w, h * 1.1) * st["ir"] * (1.05 if st.get("big") else 1)
    iu, iv = cu + look[0] * w * 0.18, cv + h * 0.04 + look[1] * h * 0.14
    col = st["iris"]
    dark = tuple(int(c * 0.55) for c in col) + (255,)
    ellipse(di, iu, iv, r, r, fill=dark)
    ellipse(di, iu, iv + r * 0.06, r * 0.82, r * 0.82, fill=col + (255,))
    # a soft lighter lower half of the iris
    glow = new()
    ellipse(ImageDraw.Draw(glow), iu, iv + r * 0.22, r * 0.62, r * 0.4, fill=tuple(min(255, int(c * 1.35 + 30)) for c in col) + (150,))
    glow = glow.filter(ImageFilter.GaussianBlur(S(0.006)))
    inner = Image.alpha_composite(inner, glow)
    di = ImageDraw.Draw(inner)
    ellipse(di, iu, iv, r * 0.42, r * 0.42, fill=INK)
    ellipse(di, iu + r * 0.2, iv - r * 0.22, r * (0.36 if st.get("big") else 0.3), r * (0.36 if st.get("big") else 0.3), fill=WHITE)
    ellipse(di, iu - r * 0.2, iv + r * 0.22, r * 0.13, r * 0.13, fill=WHITE)
    # the lid's shadow on the top of the eyeball
    sh = new()
    thick(ImageDraw.Draw(sh), top, h * 0.32, (60, 40, 50, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(S(0.006)))
    inner = Image.alpha_composite(inner, sh)
    img = clip(inner, m)
    d = ImageDraw.Draw(img)
    # a thin outline all round, the upper lid line heavier toward the outer corner
    thick(d, outline, 0.0045, INK)
    tp = top if side > 0 else top  # top runs left -> right
    if side > 0:
        taper(d, tp, st["lid"] * 0.55, st["lid"] * 1.25, INK)
    else:
        taper(d, tp, st["lid"] * 1.25, st["lid"] * 0.55, INK)
    lash_on(d, st, top, side)
    hood = st.get("hood", 0)
    if hood:
        img = lid_flat(img, st, cu, side, sc, cv - h / 2 + h * hood)
    return img


def lash_on(d, st, top, side, y_override=None):
    if not st.get("lash"):
        return
    outer = top[-1] if side > 0 else top[0]
    near = top[-4] if side > 0 else top[3]
    if st["lash"] == 3:  # a winged liner flick
        dx = (outer[0] - near[0])
        taper(d, [near, outer, (outer[0] + dx * 1.6 + side * 0.012, outer[1] - 0.02)], 0.012, 0.002, INK, 0.012)
        return
    for k, (frac, ln) in enumerate(((0.62, 0.02), (0.8, 0.026), (0.95, 0.028))):
        i = int((len(top) - 1) * (frac if side > 0 else 1 - frac))
        x0, y0 = top[i]
        ang = math.radians(60 + 40 * frac) if side > 0 else math.radians(120 - 40 * frac)
        taper(d, [(x0, y0), (x0 + math.cos(ang) * ln * 0.6 + side * ln * 0.25, y0 - math.sin(ang) * ln * 0.8)], 0.008, 0.0015, INK)


def lower_lashes(d, st, cu, side, sc):
    if st.get("lash") != 2:
        return
    w, h = st["w"] * sc, st["h"] * sc
    for frac in (0.25, 0.4):
        a = math.pi / 2 - (frac * math.pi if side > 0 else -frac * math.pi)
        x0, y0 = cu + math.cos(a) * w * 0.5 * (1 if side > 0 else -1) * -1, EYE_V + math.sin(a) * h * 0.48
        x0 = cu + side * w * (0.18 + frac * 0.6)
        y0 = EYE_V + h * 0.45 - frac * h * 0.25
        taper(d, [(x0, y0), (x0 + side * 0.008, y0 + 0.014)], 0.005, 0.001, INK)


def cut(img, poly_uv, line=None, lw=0.012, line_taper=None):
    m = mask_poly(poly_uv)
    a = img.split()[3]
    a = Image.composite(Image.new("L", (N, N), 0), a, m)
    img.putalpha(a)
    if line:
        d = ImageDraw.Draw(img)
        if line_taper:
            taper(d, line, line_taper[0], line_taper[1], INK)
        else:
            thick(d, line, lw, INK)
    return img


def lid_flat(img, st, cu, side, sc, y):
    w = st["w"] * sc
    L, R = cu - w * 0.8, cu + w * 0.8
    top = EYE_V - st["h"] * sc
    pts = bez((cu - w * 0.53, y + 0.004), (cu, y - 0.006), (cu + w * 0.53, y + 0.004), 16)
    tw = (st.get("lid") or 0.011)
    return cut(img, [(L, top - 0.03), (R, top - 0.03), (R, y), (L, y)], pts, line_taper=(tw * 1.1, tw * 1.1))


def lid_cut(img, cu, st, side, kind, sc=1.0):
    w, h = st["w"] * sc, st["h"] * sc
    cv = EYE_V
    L, R = cu - w * 0.8, cu + w * 0.8
    top = cv - h * 1.2
    inner = 1 if side < 0 else -1
    lw = max(st.get("lid") or 0.011, 0.011)
    if kind == "tired":
        return lid_flat(img, st, cu, side, sc, cv - h * 0.04)
    if kind == "smug":
        return lid_flat(img, st, cu, side, sc, cv - h * 0.0)
    if kind in ("sad", "angry", "worried"):
        hi, lo = cv - h * 0.52, cv - h * (0.04 if kind != "worried" else 0.24)
        yi, yo = (lo, hi) if kind == "angry" else (hi, lo)
        ui, uo = cu + inner * w * 0.8, cu - inner * w * 0.8
        img = cut(img, [(ui, top), (uo, top), (uo, yo), (ui, yi)])
        li = (cu + inner * w * 0.5, yi + (yo - yi) * 0.19)
        lo_ = (cu - inner * w * 0.5, yo - (yo - yi) * 0.19)
        d = ImageDraw.Draw(img)
        taper(d, [li, lo_], lw * 0.9, lw * 1.2, INK)
        return img
    if kind == "happy":
        bot = cv + h * 0.9
        y = cv + h * 0.2
        poly = bez((L - w * 0.1, bot), (cu, y - h * 0.16), (R + w * 0.1, bot), 20) + [(R + w * 0.1, bot + 0.06), (L - w * 0.1, bot + 0.06)]
        img = cut(img, poly)
        d = ImageDraw.Draw(img)
        thick(d, bez((cu - w * 0.46, cv + h * 0.36), (cu, cv + h * 0.02), (cu + w * 0.46, cv + h * 0.36), 16), 0.006, INK)
        return img
    if kind == "squint":
        img = lid_flat(img, st, cu, side, sc, cv - h * 0.12)
        return cut(img, [(L, cv + h * 0.24), (R, cv + h * 0.24), (R, cv + h), (L, cv + h)])
    return img


def closed_eye(d, cu, st, mode):
    w = max(st["w"], 0.06) * 1.12
    cv = EYE_V
    if mode == "joy":
        pts = bez((cu - w * 0.6, cv + 0.014), (cu, cv - 0.056), (cu + w * 0.6, cv + 0.014), 24)
        taper(d, pts, 0.008, 0.008, INK, 0.02)
    else:
        pts = bez((cu - w * 0.58, cv - 0.002), (cu, cv + 0.03), (cu + w * 0.58, cv - 0.002), 24)
        taper(d, pts, 0.007, 0.007, INK, 0.016)
        if st.get("lash"):
            for k in (-0.3, 0.05, 0.38):
                x = cu + k * w
                thick(d, [(x, cv + 0.018), (x + k * 0.02, cv + 0.034)], 0.0055, INK)


def wrinkles(d, cu, side, st):
    # crow's feet at the outer corner and a soft bag line under the eye
    w = st["w"]
    ox = cu + side * w * 0.62
    for k in (-1, 0, 1):
        thick(d, bez((ox, EYE_V + k * 0.012), (ox + side * 0.012, EYE_V + k * 0.016), (ox + side * 0.024, EYE_V + k * 0.024), 8), 0.0035, (80, 50, 44, 150))
    thick(d, bez((cu - w * 0.4, EYE_V + st["h"] * 0.95), (cu, EYE_V + st["h"] * 1.25), (cu + w * 0.4, EYE_V + st["h"] * 0.95), 12), 0.004, (80, 50, 44, 120))


STATES = {
    "neutral": ("open", 1.0), "happy": ("happy", 1.0), "joy": ("joy", 1.0), "sad": ("sad", 1.0),
    "angry": ("angry", 1.0), "wide": ("open", 1.14), "tired": ("tired", 1.0), "blink": ("closed", 1.0),
    "worried": ("worried", 1.05), "think": ("think", 1.0), "smug": ("smug", 1.0),
}


def eyes(style, state):
    st = EYES[style]
    kind, sc = STATES[state]
    img = new()
    for cu, side in ((EYE_L, -1), (EYE_R, 1)):
        k = kind
        if k == "think":
            k = "open" if side < 0 else "tired"
        if k in ("joy", "closed"):
            closed_eye(ImageDraw.Draw(img), cu, st, k)
        else:
            look = (0.7, -0.7) if state == "think" else (0, 0)
            e = eye_open(st, cu, side, sc, look)
            if k != "open":
                if st["shape"] == "bean":
                    e = lid_cut_bean(e, cu, st, side, k, sc)
                else:
                    e = lid_cut(e, cu, st, side, k, sc)
            if k in ("open",) and state != "wide":
                lower_lashes(ImageDraw.Draw(e), st, cu, side, sc)
            img = Image.alpha_composite(img, e)
        if st.get("extra") == "wrinkles":
            wrinkles(ImageDraw.Draw(img), cu, side, st)
    return img


def lid_cut_bean(img, cu, st, side, kind, sc):
    w, h = st["w"] * sc, st["h"] * sc
    cv = EYE_V
    L, R = cu - w, cu + w
    top = cv - h
    inner = 1 if side < 0 else -1
    if kind in ("tired", "smug"):
        y = cv - h * (0.05 if kind == "tired" else 0.0)
        return cut(img, [(L, top), (R, top), (R, y), (L, y)], [(cu - w * 0.55, y), (cu + w * 0.55, y)], 0.011)
    if kind in ("sad", "angry", "worried"):
        hi, lo = cv - h * 0.5, cv - h * (0.04 if kind != "worried" else 0.22)
        yi, yo = (lo, hi) if kind == "angry" else (hi, lo)
        ui, uo = cu + inner * w, cu - inner * w
        return cut(img, [(ui, top), (uo, top), (uo, yo), (ui, yi)],
                   [(cu + inner * w * 0.55, yi + (yo - yi) * 0.22), (cu - inner * w * 0.55, yo - (yo - yi) * 0.22)], 0.011)
    if kind == "happy":
        bot = cv + h
        y = cv + h * 0.22
        poly = bez((L, bot), (cu, y - h * 0.15), (R, bot), 20) + [(R, bot + 0.05), (L, bot + 0.05)]
        return cut(img, poly)
    return img


# ------------------------------------------------------------------ brows (white; tinted in game)

BROWS = {
    # width, length scale, arch, taper inner->outer, jagged
    "thin": dict(w=0.011, ln=1.0, arch=0.02, peak=0.62),
    "soft": dict(w=0.016, ln=1.0, arch=0.014, peak=0.55),
    "straight": dict(w=0.02, ln=1.08, arch=0.006, peak=0.5),
    "bushy": dict(w=0.027, ln=1.1, arch=0.008, peak=0.45, fuzz=True),
    "kid": dict(w=0.017, ln=0.8, arch=0.012, peak=0.5),
}
BROW_KINDS = ["neutral", "raised", "high", "angry", "sad", "worried", "flat"]


def brows(style, kind):
    b = BROWS[style]
    img = new()
    d = ImageDraw.Draw(img)
    for cu, side in ((EYE_L, -1), (EYE_R, 1)):
        cv = EYE_V - BROW_DV
        half = 0.05 * b["ln"]
        inner = 1 if side < 0 else -1
        ui, uo = cu + inner * half, cu - inner * half
        dy_i, dy_o, arch = {
            "neutral": (0.004, 0.006, 0), "raised": (-0.008, -0.002, 0.006), "high": (-0.02, -0.012, 0.012),
            "angry": (0.026, -0.012, -0.004), "sad": (-0.02, 0.018, -0.002), "worried": (-0.026, 0.012, 0.004),
            "flat": (0.01, 0.01, -0.008),
        }[kind]
        a = b["arch"] + arch
        pk = cu + (uo - cu) * (b["peak"] - 0.5) * 2 * -1 if False else ui + (uo - ui) * b["peak"]
        pts = cubic((ui, cv + dy_i), (ui + (uo - ui) * 0.3, cv + dy_i - a * 1.2), (pk, cv + (dy_i + dy_o) / 2 - a * 1.1), (uo, cv + dy_o + 0.004), 30)
        # thick at the inner end (the brow head), tapering to the tail
        taper(d, pts, b["w"] * 1.05, b["w"] * 0.32, WHITE, b["w"] * 0.95)
        if b.get("fuzz"):
            rnd = random.Random(int(cu * 1000))
            for i in range(0, len(pts) - 2, 2):
                u, v = pts[i]
                for _ in range(2):
                    ox, oy = rnd.uniform(-0.004, 0.004), rnd.uniform(-b["w"] * 0.55, b["w"] * 0.55)
                    thick(d, [(u + ox, v + oy), (u + ox - inner * 0.008, v + oy - 0.004)], 0.0035, WHITE)
    return img


# ------------------------------------------------------------------ mouths

def mouth(name, lips):
    img = new()
    d = ImageDraw.Draw(img)
    cu, cv = 0.5, MOUTH_V
    LINE = LINE_F if lips == "f" else LINE_M
    lw = 0.016 if lips == "m" else 0.015

    def under_lip(w):
        # a soft lower-lip shade for the rose set
        if lips != "f":
            return
        g = new()
        thick(ImageDraw.Draw(g), bez((cu - w * 0.32, cv + 0.032), (cu, cv + 0.05), (cu + w * 0.32, cv + 0.032), 12), 0.012, (214, 110, 130, 120))
        nonlocal img
        img = Image.alpha_composite(img, g.filter(ImageFilter.GaussianBlur(S(0.004))))

    def finish_open(w, h, top_curve=0.0, teeth=True, tongue=True):
        nonlocal img
        L, R = cu - w / 2, cu + w / 2
        topc = bez((L, cv), (cu, cv + top_curve), (R, cv), 16)
        bot = cubic((R, cv), (R - w * 0.03, cv + h * 1.28), (L + w * 0.03, cv + h * 1.28), (L, cv), 30)
        poly_uv = topc + bot[1:]
        poly = [P(u, v) for u, v in poly_uv]
        base = new()
        bd = ImageDraw.Draw(base)
        bd.polygon(poly, fill=MOUTH_IN)
        layer = new()
        ld = ImageDraw.Draw(layer)
        if tongue:
            ellipse(ld, cu, cv + h * 1.0, w * 0.56, h * 0.62, fill=TONGUE)
        if teeth:
            ld.rectangle([S(L), S(cv - 0.02), S(R), S(cv + h * 0.24)], fill=TEETH)
        m = Image.new("L", (N, N), 0)
        ImageDraw.Draw(m).polygon(poly, fill=255)
        base = Image.alpha_composite(base, clip(layer, m))
        bd = ImageDraw.Draw(base)
        bd.line(poly + [poly[0]], fill=LINE, width=int(S(0.012 if lips == "m" else 0.014)), joint="curve")
        if lips == "f":
            thick(bd, bez((cu - w * 0.3, cv + h * 1.0 + 0.012), (cu, cv + h * 1.08 + 0.016), (cu + w * 0.3, cv + h * 1.0 + 0.012), 12), 0.008, (214, 110, 130, 160))
        # little corner tucks
        for sx in (-1, 1):
            x = cu + sx * w / 2
            thick(bd, [(x, cv), (x + sx * 0.008, cv - 0.006)], 0.007, LINE)
        img = Image.alpha_composite(img, base)

    if name == "smile":
        pts = bez((cu - 0.08, cv - 0.01), (cu, cv + 0.058), (cu + 0.08, cv - 0.01))
        taper(d, pts, 0.008, 0.008, LINE, lw)
        under_lip(0.16)
    elif name == "flat":
        taper(d, bez((cu - 0.055, cv + 0.014), (cu, cv + 0.022), (cu + 0.055, cv + 0.014)), 0.007, 0.007, LINE, lw)
        under_lip(0.11)
    elif name == "frown":
        taper(d, bez((cu - 0.065, cv + 0.042), (cu, cv - 0.008), (cu + 0.065, cv + 0.042)), 0.007, 0.007, LINE, lw)
    elif name == "wavy":
        pts = [(cu - 0.066 + i * 0.132 / 40, cv + 0.018 + math.sin(i / 40 * math.pi * 3) * 0.01) for i in range(41)]
        taper(d, pts, 0.007, 0.007, LINE, 0.014)
    elif name == "smirk":
        taper(d, cubic((cu - 0.066, cv + 0.022), (cu - 0.02, cv + 0.034), (cu + 0.04, cv + 0.03), (cu + 0.078, cv - 0.01)), 0.007, 0.009, LINE, lw)
        under_lip(0.12)
    elif name == "grin":
        finish_open(0.16, 0.066, -0.012)
    elif name == "laugh":
        finish_open(0.18, 0.1, -0.016)
    elif name == "talkA":
        finish_open(0.11, 0.072, 0.004)
    elif name == "talkE":
        finish_open(0.14, 0.04, 0.0, tongue=False)
    elif name in ("o", "talkO", "smallO"):
        w, h = {"o": (0.066, 0.08), "talkO": (0.066, 0.066), "smallO": (0.04, 0.044)}[name]
        ellipse(d, cu, cv + 0.02, w, h, fill=MOUTH_IN, outline=LINE, width=0.011 if lips == "m" else 0.013)
        if name != "smallO":
            layer = new()
            ellipse(ImageDraw.Draw(layer), cu, cv + 0.02 + h * 0.32, w * 0.6, h * 0.42, fill=TONGUE)
            m = Image.new("L", (N, N), 0)
            ellipse(ImageDraw.Draw(m), cu, cv + 0.02, w - 0.012, h - 0.012, fill=255)
            img = Image.alpha_composite(img, clip(layer, m))
    elif name == "grit":
        w, h = 0.14, 0.048
        L, R = cu - w / 2, cu + w / 2
        top = bez((L, cv + 0.008), (cu, cv - 0.006), (R, cv + 0.008), 16)
        bot = bez((R, cv + h), (cu, cv + h - 0.014), (L, cv + h), 16)
        poly = [P(u, v) for u, v in top + bot]
        d.polygon(poly, fill=TEETH)
        mid = bez((L + 0.004, cv + h / 2 + 0.002), (cu, cv + h / 2 - 0.006), (R - 0.004, cv + h / 2 + 0.002), 16)
        d.line([P(u, v) for u, v in mid], fill=LINE, width=int(S(0.007)))
        for k in range(1, 6):
            u = L + w * k / 6
            d.line([P(u, cv + 0.004), P(u, cv + h - 0.004)], fill=(160, 140, 150, 255), width=int(S(0.004)))
        d.line(poly + [poly[0]], fill=LINE, width=int(S(0.012)), joint="curve")
    return img


MOUTHS = ["smile", "grin", "laugh", "flat", "frown", "o", "grit", "wavy", "smirk", "talkA", "talkO", "talkE", "smallO"]


# ------------------------------------------------------------------ static layers

SHADE = (110, 56, 40, 120)


def nose(n):
    img = new()
    d = ImageDraw.Draw(img)
    cu, cv = 0.5, 0.535
    if n == 1:  # a small side hook
        thick(d, bez((cu + 0.006, cv - 0.03), (cu + 0.024, cv + 0.004), (cu - 0.008, cv + 0.01), 14), 0.0075, SHADE)
    elif n == 2:  # button nostrils
        for sx in (-1, 1):
            ellipse(d, cu + sx * 0.013, cv + 0.006, 0.011, 0.008, fill=SHADE)
    else:  # a soft shaded tip
        g = new()
        ellipse(ImageDraw.Draw(g), cu, cv + 0.008, 0.05, 0.03, fill=(150, 70, 50, 70))
        g = g.filter(ImageFilter.GaussianBlur(S(0.008)))
        img = Image.alpha_composite(img, g)
        d = ImageDraw.Draw(img)
        thick(d, bez((cu - 0.014, cv + 0.014), (cu, cv + 0.02), (cu + 0.014, cv + 0.014), 10), 0.006, SHADE)
    return img


def mark(n):
    img = new()
    d = ImageDraw.Draw(img)
    rnd = random.Random(n * 13 + 5)
    if n in (1, 5):  # freckles
        cnt = 8 if n == 1 else 12
        for cu in (0.335, 0.665):
            for _ in range(cnt):
                s = rnd.uniform(0.008, 0.013)
                ellipse(d, cu + rnd.uniform(-0.05, 0.05), 0.522 + rnd.uniform(-0.022, 0.022), s, s, fill=(140, 76, 52, 150))
        if n == 5:
            for _ in range(5):
                s = rnd.uniform(0.007, 0.01)
                ellipse(d, 0.5 + rnd.uniform(-0.03, 0.03), 0.51 + rnd.uniform(-0.01, 0.01), s, s, fill=(140, 76, 52, 140))
    elif n == 2:  # a beauty mark
        ellipse(d, 0.574, 0.598, 0.013, 0.013, fill=(70, 40, 34, 230))
    elif n == 3:  # elder wrinkles: forehead lines and laugh lines
        for k, y in enumerate((0.262, 0.29)):
            thick(d, bez((0.4 + k * 0.02, y + 0.004), (0.5, y - 0.008), (0.6 - k * 0.02, y + 0.004), 16), 0.004, (96, 54, 44, 120))
        for sx in (-1, 1):
            thick(d, bez((0.5 + sx * 0.06, 0.555), (0.5 + sx * 0.095, 0.6), (0.5 + sx * 0.088, 0.645), 14), 0.0045, (96, 54, 44, 120))
    elif n == 4:  # rosy cheeks (kids)
        g = new()
        for cu in (0.31, 0.69):
            ellipse(ImageDraw.Draw(g), cu, 0.54, 0.08, 0.04, fill=(255, 120, 130, 90))
        img = g.filter(ImageFilter.GaussianBlur(S(0.012)))
    return img


def fhair(n):
    """white facial hair (tinted in game). Mouth sits above it in z order."""
    img = new()
    d = ImageDraw.Draw(img)
    rnd = random.Random(n * 7 + 1)
    cu, cv = 0.5, MOUTH_V
    if n == 1:  # stubble: a soft shadow round the jaw with fine dots
        band = new()
        bd = ImageDraw.Draw(band)
        out = bez((cu - 0.19, cv - 0.07), (cu, cv + 0.22), (cu + 0.19, cv - 0.07), 40)
        inn = bez((cu + 0.13, cv - 0.07), (cu, cv + 0.1), (cu - 0.13, cv - 0.07), 40)
        bd.polygon([P(u, v) for u, v in out + inn], fill=(255, 255, 255, 70))
        for sx in (-1, 1):
            taper(bd, cubic((cu, cv - 0.03), (cu + sx * 0.04, cv - 0.044), (cu + sx * 0.08, cv - 0.034), (cu + sx * 0.1, cv - 0.01), 16), 0.02, 0.012, (255, 255, 255, 70), 0.022)
        band = band.filter(ImageFilter.GaussianBlur(S(0.006)))
        dots = new()
        dd = ImageDraw.Draw(dots)
        for _ in range(700):
            u, v = cu + rnd.uniform(-0.19, 0.19), cv + rnd.uniform(-0.07, 0.17)
            if band.getpixel((int(S(u)), int(S(v))))[3] < 40:
                continue
            ellipse(dd, u, v, 0.0028, 0.0028, fill=(255, 255, 255, 90))
        img = Image.alpha_composite(band, dots)
    elif n == 2:  # moustache
        for sx in (-1, 1):
            pts = cubic((cu, cv - 0.036), (cu + sx * 0.03, cv - 0.05), (cu + sx * 0.066, cv - 0.042), (cu + sx * 0.078, cv - 0.018), 20)
            taper(d, pts, 0.02, 0.005, WHITE, 0.021)
    elif n == 3:  # goatee and a small moustache
        for sx in (-1, 1):
            pts = cubic((cu, cv - 0.034), (cu + sx * 0.025, cv - 0.044), (cu + sx * 0.05, cv - 0.038), (cu + sx * 0.06, cv - 0.02), 16)
            taper(d, pts, 0.015, 0.004, WHITE, 0.015)
        d.polygon([P(u, v) for u, v in bez((cu - 0.035, cv + 0.075), (cu, cv + 0.15), (cu + 0.035, cv + 0.075), 16) + [(cu + 0.022, cv + 0.068), (cu - 0.022, cv + 0.068)]], fill=WHITE)
    elif n == 4:  # full beard: a jaw band with the mouth left open
        out = bez((cu - 0.19, cv - 0.07), (cu, cv + 0.23), (cu + 0.19, cv - 0.07), 40)
        inn = bez((cu + 0.145, cv - 0.07), (cu, cv + 0.115), (cu - 0.145, cv - 0.07), 40)
        d.polygon([P(u, v) for u, v in out + inn], fill=WHITE)
        for sx in (-1, 1):
            pts = cubic((cu, cv - 0.036), (cu + sx * 0.04, cv - 0.052), (cu + sx * 0.09, cv - 0.04), (cu + sx * 0.13, cv - 0.02), 16)
            taper(d, pts, 0.02, 0.018, WHITE, 0.024)
        img = img.filter(ImageFilter.GaussianBlur(S(0.0025)))
    elif n == 5:  # handlebar moustache
        for sx in (-1, 1):
            pts = cubic((cu, cv - 0.034), (cu + sx * 0.04, cv - 0.052), (cu + sx * 0.08, cv - 0.022), (cu + sx * 0.1, cv - 0.052), 24)
            taper(d, pts, 0.024, 0.004, WHITE, 0.022)
    return img


def blush():
    g = new()
    for cu in (0.31, 0.69):
        ellipse(ImageDraw.Draw(g), cu, 0.535, 0.1, 0.05, fill=(255, 112, 136, 130))
    return g.filter(ImageFilter.GaussianBlur(S(0.012)))


def sheet():
    """faces assembled on skin tones, to judge them together"""
    skins = [(255, 224, 196), (234, 184, 140), (186, 128, 88), (118, 74, 50)]
    combos = [
        ("fa", "thin", "f", 1, 0, 0, (60, 40, 30)), ("fb", "soft", "f", 3, 2, 0, (34, 28, 28)), ("fc", "thin", "f", 2, 1, 0, (150, 70, 40)),
        ("fd", "soft", "f", 1, 0, 0, (186, 148, 96)), ("ma", "straight", "m", 1, 0, 1, (60, 40, 30)), ("mb", "bushy", "m", 3, 0, 2, (34, 28, 28)),
        ("mc", "straight", "m", 2, 0, 3, (110, 66, 40)), ("md", "bushy", "m", 1, 0, 4, (34, 28, 28)), ("ka", "kid", "m", 2, 4, 0, (110, 66, 40)),
        ("ka", "kid", "f", 2, 1, 0, (186, 148, 96)), ("ea", "bushy", "m", 3, 3, 5, (170, 168, 164)), ("ea", "thin", "f", 1, 3, 0, (190, 186, 182)),
    ]
    states = [("neutral", "smile"), ("happy", "grin"), ("angry", "grit"), ("sad", "frown"), ("joy", "laugh"), ("worried", "wavy")]
    T = 200
    out = Image.new("RGBA", (T * len(states), T * len(combos)), (210, 216, 224, 255))
    for r, (es, bs, ls, ns, mk, fh, bc) in enumerate(combos):
        for c, (st, mo) in enumerate(states):
            sk = skins[(r + c) % 4]
            base = Image.new("RGBA", (512, 512), sk + (255,))
            layers = []
            if mk:
                layers.append(Image.open(os.path.join(OUT, "mark_%d.png" % mk)))
            layers.append(Image.open(os.path.join(OUT, "nose_%d.png" % ns)))
            if fh:
                layers.append(tint(Image.open(os.path.join(OUT, "fhair_%d.png" % fh)), bc))
            layers.append(Image.open(os.path.join(OUT, "eye_%s_%s.png" % (es, st))))
            bk = {"neutral": "neutral", "happy": "raised", "angry": "angry", "sad": "sad", "joy": "raised", "worried": "worried"}[st]
            layers.append(tint(Image.open(os.path.join(OUT, "brow_%s_%s.png" % (bs, bk))), bc))
            layers.append(Image.open(os.path.join(OUT, "mouth_%s_%s.png" % (ls, mo))))
            for L in layers:
                base.alpha_composite(L)
            out.alpha_composite(base.resize((T, T), Image.LANCZOS), (c * T, r * T))
    out.save(os.path.join(HERE, "export", "face16_sheet.png"))


def tint(img, rgb):
    r, g, b, a = img.split()
    return Image.merge("RGBA", (r.point(lambda x: x * rgb[0] // 255), g.point(lambda x: x * rgb[1] // 255), b.point(lambda x: x * rgb[2] // 255), a))


if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]
    if not only or "eyes" in only:
        for s in EYES:
            for state in STATES:
                save(eyes(s, state), "eye_%s_%s" % (s, state))
    if not only or "rest" in only:
        for s in BROWS:
            for k in BROW_KINDS:
                save(brows(s, k), "brow_%s_%s" % (s, k))
        for ls in ("m", "f"):
            for m in MOUTHS:
                save(mouth(m, ls), "mouth_%s_%s" % (ls, m))
        for n in (1, 2, 3):
            save(nose(n), "nose_%d" % n)
        for n in (1, 2, 3, 4, 5):
            save(mark(n), "mark_%d" % n)
        for n in (1, 2, 3, 4, 5):
            save(fhair(n), "fhair_%d" % n)
        save(blush(), "blush")
    sheet()
    print("done", len(os.listdir(OUT)))
