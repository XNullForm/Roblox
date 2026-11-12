"""Round 14f: the last furniture still in the old style, remade by hand (same names and footprints).
  Plant          ~6.3 x 5.9  a real monstera: split, holed leaves on arching stems, a moss pole, a fluted cream pot
  Rug            7 x 5       a hand-knotted look: rust edge, navy border with diamonds, an 8-point medallion, corner spandrels, fringes
  Nightstand     ~2 x 3.6    walnut with a drawer and an open cubby on splayed legs; ginger-jar lamp, clock, books
  ServiceCart    ~2.6 x 4.1  room service: a brass trolley under a pleated linen skirt, cloche, coffee pot, juice, a rose
  VendingMachine 3.6 x 7.4   lit header, coil rows of bags, bars, cans and bottles behind glass, keypad, card reader, flap
Loaded by rah_props.py (exec) last. Front = -Y (Roblox +Z), floor = z 0.
"""

CREAM = (238, 230, 214)
NAVY = (38, 52, 82)
RUG_RUST = (170, 70, 52)
RUG_GOLD = (222, 184, 112)
LEAF_G = (44, 112, 56)
LEAF_LT = (70, 140, 72)
SILVER = (214, 216, 222)


# ------------------------------------------------------------------ Plant

def _monstera(name, L, W, seed):
    """A monstera leaf: heart base, deep side splits and a row of holes; stalk at origin, blade along +Y."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    N, M = 34, 16
    rows = []
    for i in range(N + 1):
        t = i / N
        hw = W * (math.sin(math.pi * min(t * 1.02, 1)) ** 0.55) * (0.55 + 0.45 * min(t / 0.18, 1))
        row = []
        for j in range(M + 1):
            s = j / M * 2 - 1
            y = t * L - 0.16 * L * abs(s) * (1 - t) ** 3     # heart lobes reach back past the stalk
            z = -0.22 * W * s * s + 0.16 * L * math.sin(math.pi * t) - 0.24 * L * t * t
            row.append(bm.verts.new((s * hw, y, z)))
        rows.append(row)
    splits = {}
    for side in (-1, 1):
        for k in range(rnd.randint(4, 5)):
            r = int(N * (0.24 + k * 0.15 + rnd.uniform(-0.03, 0.03)))
            splits[(side, r)] = rnd.uniform(0.32, 0.5)
    for i in range(N):
        for j in range(M):
            s = ((j + 0.5) / M) * 2 - 1
            side = 1 if s > 0 else -1
            cut = splits.get((side, i))
            if cut is not None and abs(s) > cut:
                continue
            # holes: a short gap between splits, inside the blade
            if 0.3 < i / N < 0.8 and i % 5 == 2 and 0.2 < abs(s) < 0.3:
                continue
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    ob = _new(name, bm)
    m = ob.modifiers.new("sol", "SOLIDIFY")
    m.thickness = 0.035
    apply_mods(ob)
    return shade(ob, 70)


@prop
def Plant():
    random.seed(1406)
    o = []
    # fluted cream ceramic pot on a dark plinth ring
    pot = lathe("Pot", [(0, 0.12), (1.12, 0.12), (1.22, 0.24), (1.42, 1.86), (1.5, 2.0), (1.47, 2.1), (1.34, 2.06), (0, 1.96)],
                (0, 0, 0), 64, 40)
    for v in pot.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if 0.3 < v.co.z < 1.9 and r > 0.5:
            th = math.atan2(v.co.y, v.co.x)
            k = 1 + 0.022 * math.cos(th * 22)
            v.co.x *= k
            v.co.y *= k
    pot.data.update()
    o.append(paint(pot, CREAM, var=0.03))
    o.append(paint(lathe("Plinth", [(0, 0), (1.08, 0), (1.12, 0.04), (1.1, 0.13), (0, 0.13)], (0, 0, 0), 48, 40), (52, 46, 42)))
    o.append(paint(lathe("Soil", [(0, 1.96), (1.36, 1.98), (1.34, 2.02), (0, 2.04)], (0, 0, 0), 40, 40), (66, 48, 36), var=0.12))
    for i in range(6):
        a, r = random.uniform(0, 6.28), random.uniform(0.4, 1.1)
        o.append(paint(sphere("Moss", random.uniform(0.1, 0.16), (r * math.cos(a), r * math.sin(a), 2.03), (1.2, 1, 0.45), 1),
                       (96, 120, 62), var=0.1))
    # moss pole with twine wraps
    o.append(paint(cyl("Pole", 0.13, 3.0, (0.12, 0.2, 3.4), 12, 0.03), (104, 92, 58), var=0.18))
    for z in (2.9, 3.8, 4.6):
        o.append(paint(lathe("Twine", [(0.12, -0.03), (0.155, -0.03), (0.155, 0.03), (0.12, 0.03)], (0.12, 0.2, z), 16, 40),
                       (190, 170, 128)))
    # leaves on arching stems, big ones high and outward, young ones near the pole
    n = 11
    for i in range(n):
        a = i / n * math.tau + random.uniform(-0.22, 0.22)
        young = i % 4 == 3
        h = random.uniform(3.0, 4.2) if not young else random.uniform(4.3, 5.0)
        reach = random.uniform(1.2, 1.9) if not young else random.uniform(0.4, 0.8)
        base = Vector((0.25 * math.cos(a), 0.25 * math.sin(a), 2.0))
        tip = Vector((reach * math.cos(a), reach * math.sin(a), h))
        ctrl = Vector((reach * 0.25 * math.cos(a), reach * 0.25 * math.sin(a), h + 0.3))
        pts = [tuple((1 - t) ** 2 * base + 2 * (1 - t) * t * ctrl + t * t * tip) for t in [k / 10 for k in range(11)]]
        o.append(paint(tube("Stem", pts, 0.045, 6), (84, 128, 64), var=0.05))
        L = random.uniform(1.6, 2.2) if not young else random.uniform(1.0, 1.3)
        lf = _monstera("Leaf", L, L * 0.5, i * 7 + 3)
        _place(lf, tip, (math.radians(random.uniform(-38, -18)), math.radians(random.uniform(-12, 12)), a - math.pi / 2))
        g = random.uniform(0.88, 1.1)
        base_c = LEAF_LT if young else LEAF_G
        o.append(paint(lf, tuple(int(c * g) for c in base_c), var=0.07))
    return o


# ------------------------------------------------------------------ Rug

def _fan(name, cx, cy, dx, dy, r, h):
    """A quarter disc in the corner (cx, cy) opening toward (dx, dy), h tall."""
    bm = bmesh.new()
    a0 = math.atan2(0, dx)
    a1 = math.atan2(dy, 0)
    if dx < 0 and dy < 0:
        a0, a1 = math.pi, 1.5 * math.pi
    pts = [(cx, cy)] + [(cx + r * math.cos(a0 + (a1 - a0) * k / 16), cy + r * math.sin(a0 + (a1 - a0) * k / 16)) for k in range(17)]
    vb = [bm.verts.new((x, y, 0)) for (x, y) in pts]
    vt = [bm.verts.new((x, y, h)) for (x, y) in pts]
    bm.faces.new(vt)
    bm.faces.new(list(reversed(vb)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shade(_new(name, bm), 30)


@prop
def Rug():
    random.seed(1407)
    o = []
    # nested layers: each sits a hair higher so its colour shows as a ring
    o.append(paint(box("Edge", (7.0, 5.0, 0.08), (0, 0, 0.04), 0.02, 2, cuts=10), RUG_RUST, var=0.05))
    o.append(paint(box("Border", (6.7, 4.7, 0.086), (0, 0, 0.043), 0.0, 1, cuts=10), NAVY, var=0.05))
    o.append(paint(box("Guard", (5.7, 3.7, 0.092), (0, 0, 0.046), 0.0, 1, cuts=8), CREAM, var=0.04))
    o.append(paint(box("Field", (5.5, 3.5, 0.098), (0, 0, 0.049), 0.0, 1, cuts=10), RUG_RUST, var=0.06))
    # border motif: cream diamonds with gold dots between, all round
    def ring_points(hx, hy, step):
        pts = []
        x = -hx
        while x <= hx + 1e-3:
            pts += [(x, -hy), (x, hy)]
            x += step
        y = -hy + step
        while y < hy - 1e-3:
            pts += [(-hx, y), (hx, y)]
            y += step
        return pts
    for (x, y) in ring_points(3.1, 2.1, 0.4):
        o.append(paint(box("Diamond", (0.2, 0.2, 0.092), (x, y, 0.046), 0.0, 1, (0, 0, math.pi / 4)), CREAM, var=0.04))
    for (x, y) in [(x + 0.2, y) for (x, y) in ring_points(3.1, 2.1, 0.4) if abs(y) > 2.0 and x < 3.0] + \
                  [(x, y + 0.2) for (x, y) in ring_points(3.1, 2.1, 0.4) if abs(x) > 3.0 and y < 2.0]:
        o.append(paint(cyl("Dot", 0.05, 0.092, (x, y, 0.046), 8, 0.0), RUG_GOLD, var=0.03))
    # thin gold line inside the guard
    for sx in (-1, 1):
        o.append(paint(box("Line", (0.06, 3.3, 0.104), (sx * 2.6, 0, 0.052), 0.0, 1), RUG_GOLD, var=0.02))
    for sy in (-1, 1):
        o.append(paint(box("Line", (5.26, 0.06, 0.104), (0, sy * 1.65, 0.052), 0.0, 1), RUG_GOLD, var=0.02))
    # 8-point star medallion: navy star, cream star, rust centre, gold boss
    for (s, h, c) in ((1.15, 0.104, NAVY), (0.85, 0.108, CREAM), (0.55, 0.112, RUG_RUST)):
        for r in (0, math.pi / 4):
            sq = box("Star", (s * 1.25, s * 1.25, h), (0, 0, h / 2), 0.0, 1, (0, 0, r))
            sq.scale = (1.3, 1.0, 1.0)
            bake_xform(sq)
            o.append(paint(sq, c, var=0.04))
    o.append(paint(cyl("Boss", 0.2, 0.116, (0, 0, 0.058), 24, 0.0), RUG_GOLD, var=0.03))
    # pendants either side of the medallion along the long axis
    for sx in (-1, 1):
        o.append(paint(box("Pendant", (0.34, 0.34, 0.104), (sx * 1.55, 0, 0.052), 0.0, 1, (0, 0, math.pi / 4)), NAVY, var=0.04))
        o.append(paint(box("Pendant", (0.16, 0.16, 0.108), (sx * 1.55, 0, 0.054), 0.0, 1, (0, 0, math.pi / 4)), RUG_GOLD, var=0.03))
    # corner spandrels: navy quarter fans with a cream inner fan, tucked into the field corners
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(_fan("Spandrel", sx * 2.75, sy * 1.75, -sx, -sy, 0.8, 0.104), NAVY, var=0.04))
            o.append(paint(_fan("SpandrelIn", sx * 2.75, sy * 1.75, -sx, -sy, 0.46, 0.108), CREAM, var=0.04))
    # small scattered flowers on the field
    for x in (-2.0, -0.95, 0.95, 2.0):
        for y in (-1.05, 1.05):
            if abs(x) > 1.9 and abs(y) > 1.0:
                continue
            o.append(paint(box("Flower", (0.16, 0.16, 0.104), (x, y, 0.052), 0.0, 1, (0, 0, math.pi / 4)), RUG_GOLD, var=0.04))
    # fringes on the short ends
    for sx in (-1, 1):
        for i in range(26):
            y = -2.35 + i * (4.7 / 25)
            wob = random.uniform(-0.04, 0.04)
            o.append(paint(tube("Fringe", [(sx * 3.5, y, 0.02), (sx * 3.66, y + wob, 0.015), (sx * 3.78, y + wob * 2, 0.012)], 0.022, 4),
                           (240, 232, 214), var=0.04))
    return o


# ------------------------------------------------------------------ Nightstand

@prop
def Nightstand():
    random.seed(1408)
    o = []
    # walnut case on splayed legs: top 2.3, case from 0.7
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(o, sx * 0.72, sy * 0.6, 0.72, (sx * 0.1, sy * 0.08), 0.05, 0.09)
    o.append(paint(box("Top", (1.98, 1.78, 0.1), (0, 0, 2.25), 0.04, 3), WAL_LT, var=0.05))
    o.append(paint(box("Case", (1.86, 1.66, 1.52), (0, 0.02, 1.46), 0.04, 2), WAL, var=0.05))
    # open cubby (lower) and drawer (upper)
    o.append(paint(box("Cubby", (1.62, 1.2, 0.62), (0, -0.25, 1.12), 0.02, 1), WAL_DK, var=0.04))
    o.append(paint(box("Shelf", (1.86, 1.66, 0.06), (0, 0.02, 1.5), 0.01, 1), WAL, var=0.04))
    o.append(paint(box("Drawer", (1.62, 0.08, 0.56), (0, -0.83, 1.86), 0.025, 2), WAL_LT, var=0.05))
    o.append(paint(box("Groove", (1.7, 0.06, 0.66), (0, -0.81, 1.86), 0.01, 1), WAL_DK))
    o.append(paint(box("Pull", (0.6, 0.06, 0.06), (0, -0.92, 1.88), 0.025, 2), BRASS_C, "chrome", var=0.02))
    for sx in (-1, 1):
        o.append(paint(box("PullPost", (0.05, 0.06, 0.05), (sx * 0.27, -0.88, 1.88), 0.02, 1), BRASS_C, "chrome"))
    # books in the cubby (spines out) and a basket
    x = -0.72
    for k in range(5):
        w = random.uniform(0.09, 0.15)
        h = random.uniform(0.42, 0.55)
        col = random.choice([(150, 56, 50), (52, 86, 110), (210, 196, 160), (64, 100, 76), (190, 140, 70)])
        o.append(paint(box("Book", (w, 0.8, h), (x + w / 2, -0.3, 0.83 + h / 2), 0.015, 1), col, var=0.04))
        x += w + 0.01
    o.append(paint(lathe("Basket", [(0, 0), (0.32, 0), (0.36, 0.34), (0.33, 0.36), (0.3, 0.06), (0, 0.06)], (0.4, -0.3, 0.83), 24, 40),
                   (196, 164, 116), var=0.1))
    # ginger-jar lamp: glazed teal body, brass neck, linen drum shade, a warm bulb
    LX, LY = 0.38, 0.22
    o.append(paint(lathe("Jar", [(0, 0), (0.22, 0), (0.3, 0.06), (0.42, 0.3), (0.4, 0.52), (0.26, 0.7), (0.14, 0.76), (0, 0.76)],
                         (LX, LY, 2.3), 32, 40), (64, 128, 132), var=0.05))
    o.append(paint(cyl("Neck", 0.05, 0.4, (LX, LY, 3.22), 10, 0.0), BRASS_C, "chrome"))
    o.append(paint(sphere("Bulb", 0.16, (LX, LY, 3.42), (1, 1, 1.25), 2), (255, 242, 210), "glow", var=0.0))
    shade = lathe("Shade", [(0.56, 3.12), (0.57, 3.14), (0.44, 3.64), (0.43, 3.66), (0.42, 3.64), (0.55, 3.15), (0.56, 3.12)],
                  (0, 0, 0), 48, 60)
    for v in shade.data.vertices:
        v.co.x += LX
        v.co.y += LY
    shade.data.update()
    o.append(paint(shade, (246, 234, 208), var=0.03))
    # a round brass alarm clock and a book with reading glasses
    o.append(paint(cyl("Clock", 0.2, 0.12, (-0.55, -0.3, 2.52), 24, 0.03, (math.radians(80), 0, math.radians(14))), BRASS_C, "chrome"))
    o.append(paint(cyl("Face", 0.16, 0.13, (-0.55, -0.3, 2.52), 24, 0.0, (math.radians(80), 0, math.radians(14))), (246, 242, 230)))
    for sx in (-1, 1):
        o.append(paint(cyl("Foot", 0.03, 0.1, (-0.55 + sx * 0.12, -0.28, 2.33), 6, 0.0), BRASS_C, "chrome"))
    o.append(paint(box("Book", (0.7, 0.5, 0.1), (-0.3, 0.3, 2.35), 0.02, 2, (0, 0, -0.25)), (52, 86, 110), var=0.03))
    o.append(paint(box("Pages", (0.66, 0.46, 0.07), (-0.29, 0.3, 2.35), 0.01, 1, (0, 0, -0.25)), (246, 240, 226)))
    ring = lambda cx: [(cx + 0.09 * math.cos(t), 0.22, 2.43 + 0.06 * math.sin(t)) for t in [k / 12 * math.tau for k in range(13)]]
    for cx in (-0.42, -0.2):
        o.append(paint(tube("Glasses", ring(cx), 0.012, 4), (40, 34, 30)))
    return o


# ------------------------------------------------------------------ ServiceCart

def _skirt(name, hx, hy, z0, z1, flare, folds, amp, n=8):
    """A pleated cloth skirt round a rounded rectangle, hanging from z0 down to z1."""
    bm = bmesh.new()
    NA, NR = 160, 6
    rows = []
    for k in range(NR + 1):
        t = k / NR
        row = []
        for i in range(NA):
            th = i / NA * math.tau
            c, s = math.cos(th), math.sin(th)
            x = hx * math.copysign(abs(c) ** (2 / n), c)
            y = hy * math.copysign(abs(s) ** (2 / n), s)
            nrm = Vector((x / hx ** 2, y / hy ** 2, 0)).normalized()
            off = flare * t + amp * (t ** 1.2) * math.sin(th * folds)
            row.append(bm.verts.new((x + nrm.x * off, y + nrm.y * off, z0 + (z1 - z0) * t)))
        rows.append(row)
    for k in range(NR):
        for i in range(NA):
            j = (i + 1) % NA
            bm.faces.new((rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.03)
    ob = _new(name, bm)
    return shade(ob, 60)


@prop
def ServiceCart():
    random.seed(1409)
    o = []
    LINEN = (250, 248, 242)
    # brass frame: posts, a lower shelf, casters
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Post", 0.06, 2.62, (sx * 1.02, sy * 1.7, 1.66), 12, 0.0), BRASS_C, "chrome", var=0.02))
            o.append(paint(cyl("Fork", 0.09, 0.14, (sx * 1.02, sy * 1.7, 0.36), 12, 0.02), BRASS_C, "chrome"))
            o.append(paint(cyl("Wheel", 0.17, 0.1, (sx * 1.02, sy * 1.7, 0.17), 18, 0.03, (0, math.radians(90), 0)), (40, 40, 44)))
            o.append(paint(cyl("Hub", 0.07, 0.12, (sx * 1.02, sy * 1.7, 0.17), 10, 0.0, (0, math.radians(90), 0)), BRASS_C, "chrome"))
    o.append(paint(box("Shelf", (2.12, 3.48, 0.08), (0, 0, 0.82), 0.02, 1), WAL, var=0.05))
    for sx in (-1, 1):
        o.append(paint(cyl("Rail", 0.035, 3.4, (sx * 1.02, 0, 1.05), 10, 0.0, (math.radians(90), 0, 0)), BRASS_C, "chrome"))
    # linen tablecloth with a pleated skirt
    o.append(paint(box("Cloth", (2.5, 3.9, 0.08), (0, 0, 3.04), 0.04, 3), LINEN, var=0.02))
    o.append(paint(_skirt("Skirt", 1.25, 1.95, 3.04, 2.0, 0.08, 46, 0.035), LINEN, var=0.03))
    # handle at the back (+Y)
    o.append(paint(tube("Handle", [(-0.95, 1.9, 2.9), (-0.95, 2.14, 3.2), (-0.8, 2.22, 3.4), (0.8, 2.22, 3.4), (0.95, 2.14, 3.2), (0.95, 1.9, 2.9)],
                        0.06, 8), BRASS_C, "chrome", var=0.02))
    T = 3.08
    # silver cloche on a white plate
    o.append(paint(lathe("Plate", [(0, 0), (0.62, 0), (0.78, 0.06), (0.8, 0.08), (0, 0.04)], (0, -0.9, T), 40, 40), CERAMIC, var=0.01))
    o.append(paint(lathe("Cloche", [(0.66, 0.04), (0.67, 0.1), (0.62, 0.34), (0.46, 0.58), (0.22, 0.7), (0, 0.72)], (0, -0.9, T), 40, 40),
                   SILVER, "chrome", var=0.01))
    o.append(paint(lathe("Knob", [(0, 0), (0.04, 0), (0.04, 0.08), (0.11, 0.12), (0.1, 0.18), (0, 0.19)], (0, -0.9, T + 0.72), 16, 40),
                   SILVER, "chrome"))
    # coffee pot
    o.append(paint(lathe("Pot", [(0, 0), (0.22, 0), (0.26, 0.08), (0.27, 0.4), (0.2, 0.62), (0.14, 0.7), (0.17, 0.74), (0, 0.76)],
                         (0.62, 0.45, T), 28, 40), SILVER, "chrome", var=0.01))
    o.append(paint(tube("Spout", [(0.62, 0.2, T + 0.3), (0.62, 0.06, T + 0.5), (0.62, -0.02, T + 0.66)], 0.035, 6), SILVER, "chrome"))
    o.append(paint(tube("PotHandle", [(0.62, 0.7, T + 0.6), (0.62, 0.86, T + 0.5), (0.62, 0.84, T + 0.22), (0.62, 0.7, T + 0.16)], 0.03, 6),
                   (40, 34, 30)))
    # cup and saucer
    o.append(paint(lathe("Saucer", [(0, 0), (0.24, 0), (0.32, 0.04), (0.3, 0.05), (0, 0.03)], (-0.55, 0.35, T), 28, 40), CERAMIC))
    o.append(paint(lathe("Cup", [(0, 0.03), (0.1, 0.03), (0.17, 0.12), (0.18, 0.26), (0.16, 0.26), (0.15, 0.13), (0, 0.1)],
                         (-0.55, 0.35, T), 24, 40), CERAMIC))
    o.append(paint(cyl("Coffee", 0.15, 0.02, (-0.55, 0.35, T + 0.22), 20, 0.0), (82, 52, 34)))
    o.append(paint(tube("CupHandle", [(-0.37, 0.35, T + 0.22), (-0.3, 0.35, T + 0.18), (-0.3, 0.35, T + 0.1), (-0.37, 0.35, T + 0.08)], 0.018, 5),
                   CERAMIC))
    # orange juice
    o.append(paint(lathe("Glass", [(0, 0), (0.13, 0), (0.15, 0.42), (0.14, 0.42), (0.12, 0.02), (0, 0.02)], (-0.7, 1.3, T), 20, 40),
                   GLASS, "glass"))
    o.append(paint(lathe("Juice", [(0, 0.02), (0.115, 0.02), (0.13, 0.32), (0, 0.32)], (-0.7, 1.3, T), 20, 40), (246, 160, 40), var=0.02))
    # bud vase and a rose
    o.append(paint(lathe("Vase", [(0, 0), (0.1, 0), (0.12, 0.16), (0.05, 0.42), (0.06, 0.5), (0, 0.5)], (0.6, 1.4, T), 16, 40),
                   GLASS, "glass"))
    o.append(paint(tube("Stem", [(0.6, 1.4, T + 0.1), (0.62, 1.4, T + 0.6), (0.6, 1.42, T + 0.95)], 0.018, 5), (60, 110, 58)))
    lf = leaf("RoseLeaf", 0.18, 0.08, 0)
    _place(lf, (0.62, 1.42, T + 0.62), (math.radians(-30), 0, math.radians(60)))
    o.append(paint(lf, (60, 120, 60)))
    for k in range(5):
        a = k / 5 * math.tau
        o.append(paint(sphere("Petal", 0.08, (0.6 + 0.05 * math.cos(a), 1.42 + 0.05 * math.sin(a), T + 1.0), (1, 1, 1.3), 1),
                       (190, 28, 46), var=0.06))
    o.append(paint(sphere("Bud", 0.07, (0.6, 1.42, T + 1.06), (1, 1, 1.3), 1), (160, 20, 38)))
    # folded napkin with cutlery
    o.append(paint(box("Napkin", (0.5, 0.8, 0.05), (-0.05, 1.05, T + 0.02), 0.02, 2, (0, 0, 0.1)), (196, 72, 62), var=0.03))
    for dx in (-0.1, 0.08):
        o.append(paint(box("Cutlery", (0.05, 0.7, 0.02), (-0.05 + dx, 1.05, T + 0.06), 0.008, 1, (0, 0, 0.1)), SILVER, "chrome"))
    # lower shelf: a bread basket and folded linen
    o.append(paint(lathe("Basket", [(0, 0), (0.42, 0), (0.5, 0.3), (0.47, 0.32), (0.4, 0.06), (0, 0.06)], (0.3, -0.6, 0.86), 28, 40),
                   (190, 150, 96), var=0.1))
    for k in range(3):
        o.append(paint(sphere("Roll", 0.16, (0.3 + 0.15 * math.cos(k * 2.1), -0.6 + 0.15 * math.sin(k * 2.1), 1.08), (1.3, 1, 0.8), 2),
                       (206, 150, 84), var=0.08))
    for k in range(3):
        o.append(paint(box("Linen", (0.9, 0.7, 0.1), (-0.35, 0.8, 0.92 + k * 0.1), 0.04, 2, (0, 0, random.uniform(-0.06, 0.06))),
                       LINEN, var=0.03))
    return o


# ------------------------------------------------------------------ VendingMachine

@prop
def VendingMachine():
    random.seed(1410)
    o = []
    RED = (186, 32, 44)
    RED_DK = (140, 24, 34)
    CHAR = (40, 40, 48)
    WX0, WX1 = -1.57, 0.79        # window x span
    WC = (WX0 + WX1) / 2
    WW = WX1 - WX0
    Z0, Z1 = 1.75, 6.7            # window z span
    # glossy red shell with a cavity behind the window
    o.append(paint(box("Back", (3.6, 1.7, 7.4), (0, 0.55, 3.7), 0.12, 3), RED, var=0.03))
    o.append(paint(box("Side", (0.24, 1.02, 7.4), (-1.68, -0.8, 3.7), 0.08, 2), RED, var=0.03))
    o.append(paint(box("Panel", (1.02, 1.02, 7.4), (1.29, -0.8, 3.7), 0.08, 2), CHAR, var=0.03))
    o.append(paint(box("Head", (WW, 1.02, 0.7), (WC, -0.8, 7.05), 0.06, 2), RED, var=0.03))
    o.append(paint(box("Base", (WW, 1.02, Z0), (WC, -0.8, Z0 / 2), 0.06, 2), RED, var=0.03))
    o.append(paint(box("Liner", (WW, 0.06, Z1 - Z0), (WC, -0.3, (Z0 + Z1) / 2), 0.0, 1), (30, 32, 40)))
    for x in (WX0 + 0.02, WX1 - 0.02):
        o.append(paint(box("LinerS", (0.04, 0.98, Z1 - Z0), (x, -0.8, (Z0 + Z1) / 2), 0.0, 1), (58, 60, 70)))
    # white stripe wrapping the lower body, and a lit header band
    o.append(paint(box("Stripe", (3.64, 2.74, 0.22), (0, 0.05, 1.42), 0.02, 1), (246, 244, 240), var=0.02))
    o.append(paint(box("HeadBox", (WW - 0.2, 0.06, 0.42), (WC, -1.32, 7.05), 0.03, 2), (255, 236, 200), "glow", var=0.0))
    o.append(paint(box("HeadRim", (WW - 0.08, 0.04, 0.52), (WC, -1.3, 7.05), 0.03, 2), (230, 230, 236), "chrome"))
    # inside light strip
    o.append(paint(box("Light", (WW - 0.1, 0.12, 0.06), (WC, -1.12, Z1 - 0.08), 0.02, 1), (240, 248, 255), "glow", var=0.0))
    # five shelves of coils with snacks
    BAGS = [(240, 196, 48), (226, 60, 60), (60, 140, 220), (250, 140, 40), (110, 190, 90), (150, 80, 180)]
    CANS = [(214, 40, 40), (40, 80, 190), (60, 170, 80), (240, 240, 240), (30, 30, 34), (250, 180, 40)]
    kinds = ["can", "bottle", "bar", "bag", "bag"]
    slot = WW / 4
    for r in range(5):
        z = Z0 + 0.25 + r * 0.92
        o.append(paint(box("Tray", (WW - 0.06, 0.92, 0.05), (WC, -0.78, z), 0.01, 1), (70, 72, 82)))
        o.append(paint(box("Lip", (WW - 0.06, 0.03, 0.12), (WC, -1.22, z + 0.02), 0.01, 1), SILVER, "chrome"))
        for k in range(4):
            x = WX0 + slot * (k + 0.5)
            o.append(paint(box("Tag", (0.22, 0.02, 0.07), (x, -1.24, z + 0.02), 0.005, 1), (250, 250, 246)))
            coil = [(x + 0.19 * math.cos(t * math.tau * 5), -1.18 + 0.78 * t, z + 0.24 + 0.19 * math.sin(t * math.tau * 5))
                    for t in [i / 80 for i in range(81)]]
            o.append(paint(tube("Coil", coil, 0.018, 5, False), SILVER, "chrome", var=0.0))
            kind = kinds[r]
            for d, yy in enumerate((-1.02, -0.72)):
                if kind == "can":
                    c = CANS[(k + r) % len(CANS)]
                    o.append(paint(cyl("Can", 0.15, 0.46, (x, yy, z + 0.26), 18, 0.02), c, var=0.03))
                    o.append(paint(cyl("CanTop", 0.13, 0.47, (x, yy, z + 0.26), 18, 0.0), SILVER, "chrome"))
                elif kind == "bottle":
                    c = [(60, 150, 230), (240, 120, 40), (90, 200, 120), (230, 60, 90)][k]
                    o.append(paint(lathe("Bottle", [(0, 0), (0.13, 0), (0.14, 0.34), (0.06, 0.5), (0.05, 0.6), (0, 0.6)],
                                         (x, yy, z + 0.03), 16, 40), c, var=0.02))
                    o.append(paint(cyl("Cap", 0.055, 0.08, (x, yy, z + 0.66), 12, 0.01), (250, 250, 250)))
                    o.append(paint(cyl("Label", 0.145, 0.16, (x, yy, z + 0.2), 16, 0.0), (250, 248, 240)))
                elif kind == "bar":
                    c = BAGS[(k * 2 + 1) % len(BAGS)]
                    o.append(paint(box("Bar", (0.4, 0.08, 0.3), (x, yy, z + 0.2), 0.03, 2, (math.radians(-12), 0, 0)), c, var=0.04))
                    o.append(paint(box("Wrap", (0.42, 0.085, 0.08), (x, yy, z + 0.2), 0.02, 1, (math.radians(-12), 0, 0)),
                                   (250, 246, 236)))
                else:
                    c = BAGS[(k + r * 3) % len(BAGS)]
                    bag = _cushion("Bag", (0.44, 0.62, 0.16), (x, yy, z + 0.36), 0.7, c, (math.radians(90 - 8), 0, 0), 0.05)
                    o.append(bag)
    # window glass and a black frame round it
    o.append(paint(box("Window", (WW, 0.04, Z1 - Z0), (WC, -1.28, (Z0 + Z1) / 2), 0.0, 1), GLASS, "glass", var=0.0))
    for z in (Z0, Z1):
        o.append(paint(box("Frame", (WW + 0.06, 0.08, 0.08), (WC, -1.3, z), 0.02, 1), (26, 26, 30)))
    for x in (WX0, WX1):
        o.append(paint(box("Frame", (0.08, 0.08, Z1 - Z0 + 0.06), (x, -1.3, (Z0 + Z1) / 2), 0.02, 1), (26, 26, 30)))
    # right panel: screen, keypad, card reader, coin slot, change cup
    PX = 1.29
    o.append(paint(box("Bezel", (0.72, 0.05, 0.46), (PX, -1.32, 5.85), 0.03, 2), (18, 18, 22)))
    o.append(paint(box("Screen", (0.58, 0.04, 0.32), (PX, -1.345, 5.85), 0.01, 1), (110, 220, 255), "glow", var=0.0))
    o.append(paint(box("Keypad", (0.66, 0.05, 1.0), (PX, -1.32, 4.95), 0.04, 2), (24, 24, 28)))
    for r in range(4):
        for k in range(3):
            o.append(paint(box("Key", (0.16, 0.06, 0.15), (PX - 0.2 + k * 0.2, -1.35, 5.3 - r * 0.22), 0.03, 2), (226, 228, 234)))
    o.append(paint(box("Reader", (0.42, 0.12, 0.5), (PX, -1.36, 4.05), 0.05, 2), (20, 20, 24)))
    o.append(paint(box("Tap", (0.18, 0.02, 0.18), (PX, -1.43, 4.1), 0.02, 1), (120, 255, 160), "glow", var=0.0))
    o.append(paint(box("Coin", (0.3, 0.05, 0.42), (PX, -1.33, 3.45), 0.03, 2), SILVER, "chrome"))
    o.append(paint(box("Slot", (0.04, 0.02, 0.2), (PX, -1.36, 3.5), 0.01, 1), (14, 14, 16)))
    o.append(paint(box("Cup", (0.4, 0.14, 0.3), (PX, -1.36, 2.7), 0.04, 2), (14, 14, 16)))
    o.append(paint(box("CupRim", (0.48, 0.1, 0.38), (PX, -1.33, 2.7), 0.04, 2), SILVER, "chrome"))
    # pickup bay with a tinted flap
    o.append(paint(box("Bay", (WW - 0.3, 0.08, 0.72), (WC, -1.29, 0.95), 0.03, 2), (14, 14, 16)))
    o.append(paint(box("Flap", (WW - 0.4, 0.05, 0.62), (WC, -1.33, 0.97), 0.03, 2, (math.radians(6), 0, 0)), (54, 56, 64), var=0.02))
    o.append(paint(box("FlapBar", (WW - 0.6, 0.05, 0.06), (WC, -1.37, 1.18), 0.02, 1), SILVER, "chrome"))
    # kick plate
    o.append(paint(box("Kick", (3.5, 2.6, 0.2), (0, 0.05, 0.1), 0.03, 1), (24, 24, 28)))
    return o
