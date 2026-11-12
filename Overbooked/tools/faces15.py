"""Round 15: the NPC face kit -> export/face15_<part>.png (512x512, transparent).
Three decal layers on the ClassicHead's front: Upper (eyes + brows: 3 styles x 11 states), Mouth (13 shapes,
shared) and Extra (blush, freckles). Drawn 4x and scaled down for clean edges.
Layout matches the classic face texture: eyes at v 0.42, mouth at v 0.63.
"""
import os, math
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")
SS = 4
N = 512 * SS

INK = (36, 24, 30, 255)
BROW = (44, 30, 26, 255)
MOUTH_LINE = (58, 24, 32, 255)
MOUTH_IN = (112, 28, 44, 255)
TONGUE = (236, 112, 124, 255)
TEETH = (255, 255, 255, 255)
WHITE = (255, 255, 255, 255)
IRIS = (96, 62, 40, 255)

EYE_L, EYE_R, EYE_V = 0.385, 0.615, 0.425
MOUTH_V = 0.635


def P(u, v):
    return (u * N, v * N)


def S(x):
    return x * N


def new():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


ZOOM, ZC = 1.62, (0.5, 0.545)  # the head shows the middle of the texture: scale the features up about here


def save(img, name):
    half = N / ZOOM / 2
    cx, cy = ZC[0] * N, ZC[1] * N
    img = img.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(os.path.join(OUT, "face15_" + name + ".png"))


def ellipse(d, cu, cv, w, h, fill=None, outline=None, width=0):
    d.ellipse([S(cu - w / 2), S(cv - h / 2), S(cu + w / 2), S(cv + h / 2)], fill=fill, outline=outline, width=int(S(width)) if width else 0)


def thick_line(d, pts, w, col):
    """a polyline with round joints and caps (pts in uv)"""
    px = [P(u, v) for u, v in pts]
    d.line(px, fill=col, width=int(S(w)), joint="curve")
    r = S(w) / 2
    for x, y in (px[0], px[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)


def bez(p0, p1, p2, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 2
        b = 2 * (1 - t) * t
        c = t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0], a * p0[1] + b * p1[1] + c * p2[1]))
    return out


def cubic(p0, p1, p2, p3, n=30):
    out = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t * t
        e = t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + e * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + e * p3[1]))
    return out


# ------------------------------------------------------------------ eyes

STYLE = {
    # eye width/height, brow thickness, brow lift, lashes, sclera
    "a": dict(w=0.058, h=0.098, bw=0.017, by=0.085, lash=False, round=False),
    "b": dict(w=0.064, h=0.104, bw=0.014, by=0.09, lash=True, round=False),
    "c": dict(w=0.088, h=0.104, bw=0.025, by=0.088, lash=False, round=True),
}


def eye_layer(st, cu, side, scale=1.0, look=(0, 0)):
    """one open eye on its own layer (side -1 left, +1 right)"""
    img = new()
    d = ImageDraw.Draw(img)
    w, h = st["w"] * scale, st["h"] * scale
    cv = EYE_V
    if st["round"]:
        ellipse(d, cu, cv, w, h, fill=WHITE, outline=INK, width=0.009)
        ir = 0.036 * scale
        iu, iv = cu + look[0] * 0.012, cv + 0.006 + look[1] * 0.01
        ellipse(d, iu, iv, ir * 2, ir * 2.1, fill=IRIS)
        ellipse(d, iu, iv, ir * 1.1, ir * 1.15, fill=INK)
        ellipse(d, iu + 0.012, iv - 0.014, 0.017, 0.017, fill=WHITE)
        ellipse(d, iu - 0.011, iv + 0.012, 0.007, 0.007, fill=WHITE)
        # re-draw the outline over the iris
        ellipse(d, cu, cv, w, h, outline=INK, width=0.009)
    else:
        ellipse(d, cu, cv, w, h, fill=INK)
        ellipse(d, cu + w * 0.2, cv - h * 0.22, w * 0.36, w * 0.36, fill=WHITE)
        ellipse(d, cu - w * 0.18, cv + h * 0.2, w * 0.14, w * 0.14, fill=WHITE)
    if st["lash"]:
        # three lashes on the outer upper edge
        for k, a in enumerate((-0.15, 0.25, 0.62)):
            ang = math.pi / 2 - a * side * -1  # sweep outward
            ang = math.radians(100 - 40 * k) if side < 0 else math.radians(80 + 40 * k)
            x0 = cu + math.cos(ang) * w * 0.48
            y0 = cv - math.sin(ang) * h * 0.48
            x1 = x0 + math.cos(ang) * 0.024 + side * 0.008
            y1 = y0 - math.sin(ang) * 0.02
            thick_line(d, [(x0, y0), (x1, y1)], 0.008, INK)
    return img


def cut(img, poly_uv, line=None, lw=0.01):
    """erase a lid region (polygon in uv) and optionally ink its edge"""
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).polygon([P(u, v) for u, v in poly_uv], fill=255)
    a = img.split()[3]
    a = Image.composite(Image.new("L", (N, N), 0), a, mask)
    img.putalpha(a)
    if line:
        thick_line(ImageDraw.Draw(img), line, lw, INK)
    return img


def lid_cut(img, cu, st, side, kind, scale=1.0):
    """kind: tired (flat upper), sad (outer side low), angry (inner side low), happy (lower lid up), squint"""
    w, h = st["w"] * scale, st["h"] * scale
    cv = EYE_V
    L, R = cu - w * 0.75, cu + w * 0.75
    top = cv - h * 0.8
    inner = 1 if side < 0 else -1  # +u direction toward the nose for the left eye
    if kind == "tired":
        y = cv - h * 0.06
        return cut(img, [(L, top), (R, top), (R, y), (L, y)], [(cu - w * 0.52, y), (cu + w * 0.52, y)] if True else None, 0.011)
    if kind == "smug":
        y = cv - h * 0.02
        return cut(img, [(L, top), (R, top), (R, y), (L, y)], [(cu - w * 0.5, y + 0.002), (cu + w * 0.5, y + 0.002)], 0.012)
    if kind in ("sad", "angry", "worried"):
        hi, lo = cv - h * 0.5, cv - h * (0.02 if kind != "worried" else 0.2)
        # sad: the outer end low; angry: the inner end low
        if kind == "angry":
            yi, yo = lo, hi
        else:
            yi, yo = hi, lo
        ui, uo = cu + inner * w * 0.75, cu - inner * w * 0.75
        poly = [(ui, top), (uo, top), (uo, yo), (ui, yi)]
        li, lo_ = (cu + inner * w * 0.5, yi + (yo - yi) * 0.17), (cu - inner * w * 0.5, yo - (yo - yi) * 0.17)
        return cut(img, poly, [li, lo_], 0.011)
    if kind == "happy":
        bot = cv + h * 0.8
        y = cv + h * 0.22
        poly = bez((L - w * 0.1, bot), (cu, y - h * 0.12), (R + w * 0.1, bot), 20) + [(R + w * 0.1, bot + 0.05), (L - w * 0.1, bot + 0.05)]
        return cut(img, poly)
    if kind == "squint":
        y1, y2 = cv - h * 0.1, cv + h * 0.22
        cut(img, [(L, top), (R, top), (R, y1), (L, y1)], [(cu - w * 0.5, y1), (cu + w * 0.5, y1)], 0.011)
        return cut(img, [(L, y2), (R, y2), (R, cv + h), (L, cv + h)])
    return img


def closed_eye(d, cu, st, mode):
    w = st["w"] * 1.15
    cv = EYE_V
    if mode == "joy":  # happy arcs, like ^ ^
        pts = bez((cu - w * 0.62, cv + 0.012), (cu, cv - 0.058), (cu + w * 0.62, cv + 0.012), 24)
        thick_line(d, pts, 0.02 if st["round"] else 0.019, INK)
    else:  # a soft closed lid
        pts = bez((cu - w * 0.6, cv - 0.004), (cu, cv + 0.03), (cu + w * 0.6, cv - 0.004), 24)
        thick_line(d, pts, 0.016, INK)
        if st["lash"]:
            for k in (-0.35, 0.0, 0.35):
                x = cu + k * w
                thick_line(d, [(x, cv + 0.016), (x + k * 0.02, cv + 0.034)], 0.007, INK)


def brow(d, cu, st, side, kind):
    """kind: neutral, raised, high, angry, sad, flat, none"""
    if kind == "none":
        return
    bw = st["bw"]
    cv = EYE_V - st["by"]
    w = st["w"] * 1.35 if not st["round"] else st["w"] * 1.05
    inner = 1 if side < 0 else -1
    ui, uo = cu + inner * w * 0.5, cu - inner * w * 0.5
    arch = 0.016 if st["lash"] else 0.01
    if kind == "neutral":
        pts = bez((uo, cv + 0.008), (cu, cv - arch), (ui, cv + 0.004))
    elif kind == "raised":
        pts = bez((uo, cv), (cu, cv - arch - 0.016), (ui, cv - 0.006))
    elif kind == "high":
        pts = bez((uo, cv - 0.012), (cu, cv - arch - 0.034), (ui, cv - 0.02))
    elif kind == "angry":
        pts = bez((uo, cv - 0.018), (cu, cv - 0.004), (ui, cv + 0.03))
    elif kind == "sad":
        pts = bez((uo, cv + 0.022), (cu, cv + 0.004), (ui, cv - 0.022))
    elif kind == "worried":
        pts = bez((uo, cv + 0.018), (cu, cv - 0.01), (ui, cv - 0.03))
    elif kind == "flat":
        pts = bez((uo, cv + 0.014), (cu, cv + 0.01), (ui, cv + 0.012))
    else:
        pts = bez((uo, cv + 0.008), (cu, cv - arch), (ui, cv + 0.004))
    thick_line(d, pts, bw, BROW)


# state -> (left eye, right eye, left brow, right brow, eye scale)
STATES = {
    "neutral": ("open", "open", "neutral", "neutral", 1.0),
    "happy": ("happy", "happy", "raised", "raised", 1.0),
    "joy": ("joy", "joy", "raised", "raised", 1.0),
    "sad": ("sad", "sad", "sad", "sad", 1.0),
    "angry": ("angry", "angry", "angry", "angry", 1.0),
    "wide": ("open", "open", "high", "high", 1.18),
    "tired": ("tired", "tired", "flat", "flat", 1.0),
    "blink": ("closed", "closed", "neutral", "neutral", 1.0),
    "worried": ("worried", "worried", "worried", "worried", 1.06),
    "think": ("open", "tired", "raised", "flat", 1.0),
    "smug": ("smug", "smug", "raised", "flat", 1.0),
}


def upper(style, state):
    st = STYLE[style]
    le, re, lb, rb, sc = STATES[state]
    img = new()
    for cu, side, kind, bk in ((EYE_L, -1, le, lb), (EYE_R, 1, re, rb)):
        if kind in ("joy", "closed"):
            closed_eye(ImageDraw.Draw(img), cu, st, kind)
        else:
            look = (0.3 * side * -1, 0) if state == "think" else (0, 0)
            if state == "think":
                look = (0.6, -0.6)
            e = eye_layer(st, cu, side, sc, look)
            if kind != "open":
                e = lid_cut(e, cu, st, side, kind, sc)
            img = Image.alpha_composite(img, e)
        brow(ImageDraw.Draw(img), cu, st, side, bk)
    return img


# ------------------------------------------------------------------ mouths

def mouth_open(d, cu, cv, w, h, top_curve=0.0, teeth=True, tongue=True, flat_top=True):
    """an open mouth: a D shape (flat-ish top, round bottom)"""
    L, R = cu - w / 2, cu + w / 2
    topc = bez((L, cv), (cu, cv + top_curve), (R, cv), 16)
    bot = cubic((R, cv), (R - w * 0.02, cv + h * 1.25), (L + w * 0.02, cv + h * 1.25), (L, cv), 30)
    poly = [P(u, v) for u, v in topc + bot[1:]]
    d.polygon(poly, fill=MOUTH_IN)
    # tongue and teeth are clipped to the mouth
    layer = new()
    ld = ImageDraw.Draw(layer)
    if tongue:
        ellipse(ld, cu, cv + h * 0.98, w * 0.58, h * 0.6, fill=TONGUE)
    if teeth:
        ld.rectangle([S(L), S(cv - 0.02), S(R), S(cv + h * 0.22)], fill=TEETH)
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    return layer, mask, poly


def mouth(name):
    img = new()
    d = ImageDraw.Draw(img)
    cu, cv = 0.5, MOUTH_V
    lw = 0.017

    def finish_open(w, h, top_curve=0.0, teeth=True, tongue=True):
        nonlocal img
        layer, mask, poly = mouth_open(d, cu, cv, w, h, top_curve, teeth, tongue)
        base = img.copy()
        clipped = Image.composite(layer, Image.new("RGBA", (N, N), (0, 0, 0, 0)), mask)
        img = Image.alpha_composite(base, clipped)
        dd = ImageDraw.Draw(img)
        dd.line(poly + [poly[0]], fill=MOUTH_LINE, width=int(S(0.012)), joint="curve")
        return img

    if name == "smile":
        thick_line(d, bez((cu - 0.085, cv - 0.012), (cu, cv + 0.06), (cu + 0.085, cv - 0.012)), lw, MOUTH_LINE)
    elif name == "flat":
        thick_line(d, bez((cu - 0.06, cv + 0.012), (cu, cv + 0.02), (cu + 0.06, cv + 0.012)), lw, MOUTH_LINE)
    elif name == "frown":
        thick_line(d, bez((cu - 0.07, cv + 0.04), (cu, cv - 0.01), (cu + 0.07, cv + 0.04)), lw, MOUTH_LINE)
    elif name == "wavy":
        pts = [(cu - 0.07 + i * 0.14 / 40, cv + 0.018 + math.sin(i / 40 * math.pi * 3) * 0.011) for i in range(41)]
        thick_line(d, pts, 0.015, MOUTH_LINE)
    elif name == "smirk":
        thick_line(d, cubic((cu - 0.07, cv + 0.02), (cu - 0.02, cv + 0.034), (cu + 0.04, cv + 0.03), (cu + 0.08, cv - 0.012)), lw, MOUTH_LINE)
    elif name == "grin":
        img = finish_open(0.17, 0.07, -0.012, teeth=True, tongue=True)
    elif name == "laugh":
        img = finish_open(0.19, 0.105, -0.016, teeth=True, tongue=True)
    elif name == "talkA":
        img = finish_open(0.12, 0.075, 0.004, teeth=True, tongue=True)
    elif name == "talkE":
        img = finish_open(0.15, 0.042, 0.0, teeth=True, tongue=False)
    elif name in ("o", "talkO", "smallO"):
        w, h = {"o": (0.07, 0.085), "talkO": (0.07, 0.07), "smallO": (0.042, 0.048)}[name]
        ellipse(d, cu, cv + 0.02, w, h, fill=MOUTH_IN, outline=MOUTH_LINE, width=0.012)
        if name != "smallO":
            layer = new()
            ellipse(ImageDraw.Draw(layer), cu, cv + 0.02 + h * 0.32, w * 0.6, h * 0.42, fill=TONGUE)
            mask = Image.new("L", (N, N), 0)
            ellipse(ImageDraw.Draw(mask), cu, cv + 0.02, w - 0.012, h - 0.012, fill=255)
            img = Image.alpha_composite(img, Image.composite(layer, Image.new("RGBA", (N, N), (0, 0, 0, 0)), mask))
    elif name == "grit":
        w, h = 0.15, 0.05
        L, R = cu - w / 2, cu + w / 2
        top = bez((L, cv + 0.008), (cu, cv - 0.006), (R, cv + 0.008), 16)
        bot = bez((R, cv + h), (cu, cv + h - 0.014), (L, cv + h), 16)
        poly = [P(u, v) for u, v in top + bot]
        d.polygon(poly, fill=TEETH)
        # the gap between the teeth rows and the tooth lines
        mid = bez((L + 0.004, cv + h / 2 + 0.002), (cu, cv + h / 2 - 0.006), (R - 0.004, cv + h / 2 + 0.002), 16)
        d.line([P(u, v) for u, v in mid], fill=MOUTH_LINE, width=int(S(0.008)))
        for k in range(1, 6):
            u = L + w * k / 6
            d.line([P(u, cv + 0.004), P(u, cv + h - 0.004)], fill=(150, 130, 140, 255), width=int(S(0.005)))
        d.line(poly + [poly[0]], fill=MOUTH_LINE, width=int(S(0.012)), joint="curve")
    return img


MOUTHS = ["smile", "grin", "laugh", "flat", "frown", "o", "grit", "wavy", "smirk", "talkA", "talkO", "talkE", "smallO"]


def extras():
    blush = new()
    d = ImageDraw.Draw(blush)
    for cu in (0.31, 0.69):
        ellipse(d, cu, 0.535, 0.1, 0.05, fill=(255, 118, 140, 120))
    blush = blush.filter(ImageFilter.GaussianBlur(S(0.012)))
    save(blush, "blush")
    fr = new()
    d = ImageDraw.Draw(fr)
    import random
    rnd = random.Random(7)
    for cu in (0.32, 0.68):
        for _ in range(7):
            ellipse(d, cu + rnd.uniform(-0.045, 0.045), 0.525 + rnd.uniform(-0.02, 0.02), 0.012, 0.012, fill=(150, 86, 60, 150))
    save(fr, "freckles")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for s in STYLE:
        for state in STATES:
            save(upper(s, state), "u%s_%s" % (s, state))
    for m in MOUTHS:
        save(mouth(m), "m_" + m)
    extras()
    # a contact sheet to check them
    sheet = Image.new("RGBA", (128 * 12, 128 * 5), (226, 182, 150, 255))
    names = []
    for s in STYLE:
        for state in STATES:
            names.append("u%s_%s" % (s, state))
    names += ["m_" + m for m in MOUTHS] + ["blush", "freckles"]
    for i, nm in enumerate(names):
        im = Image.open(os.path.join(OUT, "face15_" + nm + ".png")).resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(im, ((i % 12) * 128, (i // 12) * 128))
    sheet.save(os.path.join(OUT, "face15_sheet.png"))
    print(len(names), "faces")
