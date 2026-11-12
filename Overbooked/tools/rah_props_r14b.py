"""Round 14b: the lobby's most-seen pieces, remade by hand so they read as real furniture, not blobs.
Loaded by rah_props.py (exec) last; same names and footprints as before:
  IndoorPalm  ~5.1 x 7.2 (a kentia palm: terracotta pot, ringed trunk, arching fronds of leaflets)
  CoffeeTable ~3.9 round x 1.7 (mid-century walnut, splayed tapered legs with brass shoes, a cane shelf)
  FloorLamp   ~2.2 x 7.3 (brass stem on a weighted dome, pleated linen drum shade)
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
"""

TERRA = (196, 108, 72)
TERRA_DK = (160, 84, 56)
SOIL = (112, 84, 62)
TRUNK = (150, 118, 82)
TRUNK_DK = (112, 86, 60)
WALNUT = (132, 84, 52)
WALNUT_DK = (98, 62, 40)
CANE = (214, 184, 132)
BRASS = (214, 172, 92)
LINEN = (246, 234, 208)


def _orient(ob, X, Z, origin):
    """Place a mesh built at the origin with its local X along X and Z along Z (both unit-ish)."""
    X = Vector(X).normalized()
    Z = (Vector(Z) - X * Vector(Z).dot(X)).normalized()
    Y = Z.cross(X)
    m = Matrix((
        (X.x, Y.x, Z.x, origin[0]),
        (X.y, Y.y, Z.y, origin[1]),
        (X.z, Y.z, Z.z, origin[2]),
        (0, 0, 0, 1),
    ))
    ob.matrix_world = m
    bake_xform(ob)
    return ob


def _align(ob, d, origin):
    """Turn a mesh built along +Z so +Z points along d, then move it to origin."""
    q = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized())
    ob.matrix_world = Matrix.Translation(Vector(origin)) @ q.to_matrix().to_4x4()
    bake_xform(ob)
    return ob


@prop
def IndoorPalm():
    random.seed(1401)
    o = []
    # terracotta pot: a tapered body, a rolled rim, a darker band, soil and a few pebbles
    o.append(paint(lathe("Pot", [(0, 0), (0.6, 0), (0.64, 0.05), (0.84, 1.18), (0.86, 1.22), (0.8, 1.26), (0, 1.26)],
                         (0, 0, 0), 40, 40), TERRA, var=0.05))
    o.append(paint(lathe("Rim", [(0.8, 1.2), (0.98, 1.22), (1.02, 1.32), (1.0, 1.46), (0.94, 1.5), (0.86, 1.48),
                                 (0.84, 1.36), (0.8, 1.3)], (0, 0, 0), 40, 40), TERRA_DK, var=0.04))
    o.append(paint(lathe("Soil", [(0.84, 1.3), (0.86, 1.38), (0.5, 1.42), (0, 1.44)], (0, 0, 0), 32, 40), SOIL, var=0.08))
    for i in range(7):
        a = random.uniform(0, 6.28)
        r = random.uniform(0.3, 0.75)
        o.append(paint(sphere("Pebble", random.uniform(0.06, 0.1), (r * math.cos(a), r * math.sin(a), 1.44), (1, 1, 0.6), 1),
                       random.choice([(206, 200, 188), (168, 160, 150), (230, 224, 212)]), var=0.04))

    # the trunk: stacked flared rings along a gentle lean
    def path(t):
        return Vector((0.55 * t ** 1.6, -0.12 * t, 1.38 + 4.9 * t))
    N = 11
    for i in range(N):
        t0, t1 = i / N, (i + 1) / N
        a, b = path(t0), path(t1)
        r = 0.21 - 0.08 * t0
        h = (b - a).length
        ring = lathe("Trunk", [(0, 0), (r * 0.86, 0), (r * 1.06, h * 0.12), (r, h * 0.55), (r * 0.84, h * 1.02), (0, h * 1.02)],
                     (0, 0, 0), 14, 60)
        _align(ring, b - a, a)
        o.append(paint(ring, TRUNK if i % 2 == 0 else TRUNK_DK, var=0.06))

    # the crown: arching fronds, each a midrib with paired leaflets in two pieces (the tips droop more)
    top = path(1.0)
    up = Vector((0, 0, 1))
    n = 9
    for f in range(n):
        yaw = f / n * 2 * math.pi + random.uniform(-0.25, 0.25)
        elev = [0.95, 0.55, 0.2, -0.15][f % 4] + random.uniform(-0.12, 0.12)
        L = random.uniform(2.0, 2.6)
        droop = random.uniform(0.55, 0.85)
        hdir = Vector((math.cos(yaw), math.sin(yaw), 0))
        old = f == n - 1
        g = random.uniform(-14, 14)
        green = (60 + g, 138 + g, 66 + g * 0.5) if not old else (150, 136, 74)
        tip_green = (92 + g, 168 + g, 84) if not old else (176, 152, 90)

        def mid(u):
            return top + hdir * (L * u * math.cos(elev)) + up * (L * u * math.sin(elev) - droop * L * u * u)

        pts = [tuple(mid(k / 10)) for k in range(11)]
        o.append(paint(tube("Rib", pts, 0.035, 6), (110, 128, 70) if not old else (150, 128, 80), var=0.04))
        k = 0.12
        while k < 0.97:
            p = mid(k)
            tan = (mid(min(k + 0.02, 1)) - mid(max(k - 0.02, 0))).normalized()
            side0 = tan.cross(up)
            if side0.length < 1e-3:
                side0 = Vector((1, 0, 0))
            side0.normalize()
            ll = 0.95 * math.sin(math.pi * min(k * 1.05, 1)) ** 0.6 + 0.18
            w = 0.16 * (1 - 0.45 * k)
            for s in (-1, 1):
                side = side0 * s
                d1 = (side * 0.85 + tan * 0.45 - up * 0.18).normalized()
                d2 = (side * 0.7 + tan * 0.5 - up * 0.6).normalized()
                l1, l2 = ll * 0.55, ll * 0.5
                leaf = box("Leaf", (l1, w, 0.02), (0, 0, 0), 0, 1)
                _orient(leaf, d1, up, p + d1 * (l1 / 2))
                o.append(paint(leaf, green, var=0.08))
                e = p + d1 * l1
                leaf2 = box("Leaf", (l2, w * 0.8, 0.02), (0, 0, 0), 0, 1)
                _orient(leaf2, d2, up, e + d2 * (l2 / 2))
                o.append(paint(leaf2, tip_green, var=0.08))
            k += 0.088
    return o


@prop
def CoffeeTable():
    random.seed(1402)
    o = []
    # round walnut top with a rounded, slightly undercut edge
    o.append(paint(lathe("Top", [(0, 1.52), (1.84, 1.52), (1.92, 1.56), (1.94, 1.63), (1.9, 1.7), (0, 1.7)], (0, 0, 0), 56, 35),
                   WALNUT, var=0.05))
    o.append(paint(lathe("Apron", [(1.38, 1.36), (1.46, 1.36), (1.46, 1.53), (1.38, 1.53)], (0, 0, 0), 48, 35), WALNUT_DK, var=0.04))
    # four splayed, tapered legs with brass shoes
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        top = Vector((1.05 * math.cos(a), 1.05 * math.sin(a), 1.4))
        foot = Vector((1.5 * math.cos(a), 1.5 * math.sin(a), 0.0))
        d = foot - top
        leg = lathe("Leg", [(0, 0), (0.09, 0), (0.13, d.length), (0, d.length)], (0, 0, 0), 14, 50)
        _align(leg, -d, foot)
        o.append(paint(leg, WALNUT, var=0.05))
        shoe = lathe("Shoe", [(0, 0), (0.085, 0), (0.095, 0.2), (0, 0.2)], (0, 0, 0), 14, 50)
        _align(shoe, -d, foot)
        o.append(paint(shoe, BRASS, "chrome", var=0.02))
    # a woven cane shelf between the legs
    o.append(paint(cyl("Shelf", 1.3, 0.08, (0, 0, 0.52), 40, 0.02), CANE, var=0.06))
    for r in (0.45, 0.85, 1.22):
        o.append(paint(lathe("Weave", [(r - 0.03, 0.555), (r + 0.03, 0.555), (r + 0.03, 0.575), (r - 0.03, 0.575)], (0, 0, 0), 40, 35),
                       (188, 156, 106), var=0.04))
    # on top: two stacked books and a little ceramic bowl
    o.append(paint(box("Book", (1.1, 0.8, 0.14), (-0.55, 0.25, 1.77), 0.03, 2, (0, 0, 0.18)), (176, 64, 56), var=0.03))
    o.append(paint(box("Pages", (1.04, 0.74, 0.1), (-0.53, 0.25, 1.77), 0.01, 1, (0, 0, 0.18)), (246, 240, 226)))
    o.append(paint(box("Book", (0.9, 0.66, 0.12), (-0.5, 0.2, 1.9), 0.03, 2, (0, 0, -0.12)), (58, 92, 124), var=0.03))
    o.append(paint(lathe("Bowl", [(0, 1.7), (0.16, 1.7), (0.3, 1.78), (0.36, 1.92), (0.33, 1.93), (0.27, 1.82), (0, 1.79)],
                         (0.7, -0.35, 0), 28, 40), (232, 226, 214), var=0.02))
    return o


@prop
def FloorLamp():
    random.seed(1403)
    o = []
    # a weighted brass dome base, a slim stem with a collar and an inline switch, a harp and finial
    o.append(paint(lathe("Base", [(0, 0), (0.86, 0), (0.88, 0.05), (0.78, 0.16), (0.46, 0.26), (0.14, 0.3), (0, 0.3)], (0, 0, 0), 40, 40),
                   BRASS, "chrome", var=0.02))
    o.append(paint(cyl("Stem", 0.06, 5.5, (0, 0, 3.0), 12, 0.0), BRASS, "chrome", var=0.02))
    o.append(paint(cyl("Collar", 0.1, 0.16, (0, 0, 3.1), 16, 0.02), BRASS, "chrome"))
    o.append(paint(box("Switch", (0.2, 0.14, 0.3), (0.12, 0, 4.2), 0.04, 2), (54, 46, 40)))
    o.append(paint(tube("Harp", [(-0.3, 0, 5.9), (-0.3, 0, 6.4), (0, 0, 6.9), (0.3, 0, 6.4), (0.3, 0, 5.9)], 0.025, 6), BRASS, "chrome"))
    o.append(paint(sphere("Finial", 0.09, (0, 0, 7.0), (1, 1, 1.3), 2), BRASS, "chrome"))
    o.append(paint(sphere("Bulb", 0.26, (0, 0, 6.05), (1, 1, 1.25), 2), (255, 244, 214), "glow", var=0.0))
    # the shade: a tapered linen drum with soft pleats, open top and bottom (two walls)
    shade = lathe("Shade", [(1.08, 5.56), (1.1, 5.6), (0.84, 7.2), (0.82, 7.24), (0.8, 7.2), (1.05, 5.62), (1.08, 5.56)], (0, 0, 0), 72, 70)
    for v in shade.data.vertices:
        th = math.atan2(v.co.y, v.co.x)
        k = 1 + 0.018 * math.cos(th * 28)
        v.co.x *= k
        v.co.y *= k
    shade.data.update()
    o.append(paint(shade, LINEN, var=0.03))
    for z, r in ((5.6, 1.1), (7.22, 0.84)):
        o.append(paint(lathe("Trim", [(r - 0.01, z - 0.03), (r + 0.03, z - 0.03), (r + 0.03, z + 0.03), (r - 0.01, z + 0.03)], (0, 0, 0), 48, 40),
                       (196, 170, 120), var=0.02))
    return o
