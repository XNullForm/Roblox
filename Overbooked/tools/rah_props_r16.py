"""Round 16 city kit (exec'd last by rah_props.py): modelled facade pieces, roof kit and new trees.
Facade pieces are built with their origin ON the wall plane (y = 0), facing -Y (= Roblox +Z); MapBuilder turns
them to face the street. Windows: origin = centre of the opening. Runs (cornice, belt, awning, shop window):
origin = bottom centre, 8 studs long, tiled / stretched along X in Studio.
Groups: trim (white stone, tinted per building), main (baked colours), glass (the pane, named Window in Studio),
paint / paint2 (white, tinted: shutters, bulkheads, awning stripes), metal (dark iron), bark / leaf (trees).
"""

IRON = (44, 46, 52)
SASH = (236, 234, 228)
STONE = (250, 250, 250)


def bx(name, size, loc, bevel=0.03, rot=(0, 0, 0)):
    return box(name, size, loc, bevel, 1, rot)


def extr(name, prof, L, x0=None):
    """Extrude a closed (y, z) profile along X (length L, centred)."""
    bm = bmesh.new()
    a = [bm.verts.new((-L / 2, y, z)) for y, z in prof]
    b = [bm.verts.new((L / 2, y, z)) for y, z in prof]
    n = len(prof)
    for i in range(n):
        bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shade(_new(name, bm), 25)


def wedge_block(name, a0, a1, r0, r1, y0, y1, cz):
    """A voussoir: ring segment between angles a0..a1 (radians), radii r0..r1, from wall y0 out to y1."""
    bm = bmesh.new()
    vs = []
    for y in (y0, y1):
        for r, a in ((r0, a0), (r0, a1), (r1, a1), (r1, a0)):
            vs.append(bm.verts.new((r * math.cos(a), y, cz + r * math.sin(a))))
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    m = ob.modifiers.new("bv", "BEVEL")
    m.width = 0.035
    m.segments = 1
    apply_mods(ob)
    return shade(ob, 30)


def limb(name, pts, radii, n=10):
    """A tapering tube through pts with a radius per point (trunks, branches)."""
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        p = Vector(p)
        t = (Vector(pts[min(i + 1, len(pts) - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        u = t.cross(Vector((0.3, 1, 0.1))).normalized()
        w = t.cross(u)
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / n) + w * math.sin(2 * math.pi * k / n)) * radii[i]) for k in range(n)])
    for i in range(len(rings) - 1):
        for k in range(n):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]))
    bm.faces.new(rings[-1])
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return shade(_new(name, bm), 70)


def T(o, ob, rgb=STONE, g="trim", var=0.03):
    o.append(paint(ob, rgb, g, var))
    return ob


def sash(o, w, h, cz=0.0, bars=1, rails=1, col=SASH, y=-0.1):
    """A window sash: outer frame, vertical bars and cross rails, and the pane behind."""
    t = 0.22
    for sx in (-1, 1):
        T(o, bx("Stile", (t, 0.2, h), (sx * (w / 2 - t / 2), y, cz)), col, "main")
    for sz in (-1, 1):
        T(o, bx("Rail", (w, 0.2, t), (0, y, cz + sz * (h / 2 - t / 2))), col, "main")
    for i in range(bars):
        T(o, bx("Bar", (0.1, 0.16, h), (-w / 2 + w * (i + 1) / (bars + 1), y, cz), 0.02), col, "main")
    for i in range(rails):
        T(o, bx("Mid", (w, 0.2, 0.16 if rails > 1 else 0.26), (0, y - 0.03, cz - h / 2 + h * (i + 1) / (rails + 1)), 0.02), col, "main")
    T(o, bx("Pane", (w - 0.1, 0.06, h - 0.1), (0, y + 0.08, cz), 0), (255, 255, 255), "glass", 0)


def sill(o, w, z, brackets=True):
    T(o, extr("Sill", [(0, 0), (-0.75, 0), (-0.85, 0.1), (-0.85, 0.3), (-0.7, 0.42), (0, 0.42)], w).copy() if False else extr("Sill", [(0, 0), (-0.75, 0), (-0.85, 0.1), (-0.85, 0.3), (-0.7, 0.42), (0, 0.42)], w))
    o[-1].location = (0, 0, z)
    bake_xform(o[-1])
    if brackets:
        for sx in (-1, 1):
            b = extr("Bracket", [(0, 0), (-0.2, 0.05), (-0.5, 0.45), (-0.6, 0.7), (0, 0.7)], 0.42)
            b.location = (sx * (w / 2 - 0.55), 0, z - 0.7)
            T(o, bake_xform(b))


@prop
def WinA():
    """Classic sash window in a stone surround with a keystone lintel and bracketed sill."""
    o = []
    w, h = 4.2, 6.4
    for sx in (-1, 1):
        T(o, bx("Jamb", (0.55, 0.34, h), (sx * (w / 2 + 0.275), -0.17, 0)))
    lint = extr("Lintel", [(0, 0), (-0.4, 0), (-0.4, 0.7), (-0.55, 0.78), (-0.72, 1.0), (-0.72, 1.14), (0, 1.14)], w + 1.7)
    lint.location = (0, 0, h / 2)
    T(o, bake_xform(lint))
    T(o, wedge_block("Key", math.radians(80), math.radians(100), 3.0, 4.35, 0, -0.62, h / 2 - 3.1))
    sill(o, w + 1.6, -h / 2 - 0.42)
    sash(o, w, h, 0, 1, 1)
    return o


@prop
def WinB():
    """Round-arched window: brick-sized voussoirs, proud keystone, fanlight."""
    o = []
    w, r = 4.2, 2.1
    sp = 1.2  # spring line above the centre
    bot = -3.2
    for sx in (-1, 1):
        T(o, bx("Jamb", (0.5, 0.3, sp - bot), (sx * (w / 2 + 0.25), -0.15, (sp + bot) / 2)))
        T(o, bx("Impost", (0.8, 0.46, 0.4), (sx * (w / 2 + 0.3), -0.23, sp + 0.05)))
    n = 11
    for i in range(n):
        a0, a1 = math.pi * i / n, math.pi * (i + 1) / n
        key = i == n // 2
        proud = -0.62 if key else (-0.4 if i % 2 == 0 else -0.3)
        T(o, wedge_block("Vous", a0 + 0.008, a1 - 0.008, r, r + (1.25 if key else 0.85), 0, proud, sp + 0.25), var=0.06)
    sill(o, w + 1.4, bot - 0.42)
    # sash below the spring, fan above
    sash(o, w, sp - bot, (sp + bot) / 2, 1, 1)
    arc = [(r * 0.94 * math.cos(math.pi * k / 16), -0.1, sp + 0.25 + r * 0.94 * math.sin(math.pi * k / 16)) for k in range(17)]
    T(o, tube("Arc", arc, 0.11, 6), SASH, "main")
    for k in (4, 8, 12):
        a = math.pi * k / 16
        T(o, tube("Spoke", [(0, -0.1, sp + 0.25), (r * 0.9 * math.cos(a), -0.1, sp + 0.25 + r * 0.9 * math.sin(a))], 0.05, 4), SASH, "main")
    bm = bmesh.new()
    vs = [bm.verts.new((r * math.cos(math.pi * k / 16), -0.02, sp + 0.2 + r * math.sin(math.pi * k / 16))) for k in range(17)]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    fan = _new("Fan", bm)
    if fan.data.polygons[0].normal.y > 0:
        fan.data.flip_normals()
    T(o, fan, (255, 255, 255), "glass", 0)
    return o


def shutter(o, x, h, w=1.25):
    T(o, bx("ShFrameL", (0.14, 0.14, h), (x - w / 2 + 0.07, -0.1, 0), 0.02), (255, 255, 255), "paint")
    T(o, bx("ShFrameR", (0.14, 0.14, h), (x + w / 2 - 0.07, -0.1, 0), 0.02), (255, 255, 255), "paint")
    for z in (-h / 2 + 0.08, 0, h / 2 - 0.08):
        T(o, bx("ShRail", (w, 0.14, 0.16), (x, -0.1, z), 0.02), (255, 255, 255), "paint")
    n = 20
    for i in range(n):
        z = -h / 2 + 0.2 + (h - 0.4) * (i + 0.5) / n
        if abs(z) < 0.12:
            continue
        T(o, box("Slat", (w - 0.26, 0.03, 0.2), (x, -0.09, z), 0, 1, (math.radians(-32), 0, 0)), (232, 232, 232), "paint", 0)


@prop
def WinC():
    """Shuttered window with a flower box."""
    o = []
    w, h = 3.8, 6.0
    for sx in (-1, 1):
        T(o, bx("Jamb", (0.3, 0.2, h + 0.3), (sx * (w / 2 + 0.15), -0.1, 0)))
        shutter(o, sx * (w / 2 + 0.3 + 0.7), h)
    T(o, bx("Head", (w + 0.9, 0.3, 0.5), (0, -0.15, h / 2 + 0.25)))
    T(o, bx("HeadCap", (w + 1.2, 0.42, 0.16), (0, -0.21, h / 2 + 0.58)))
    sill(o, w + 0.8, -h / 2 - 0.42, False)
    sash(o, w, h, 0, 1, 2)
    # flower box on iron brackets
    T(o, bx("Box", (w + 0.5, 0.95, 0.85), (0, -0.95, -h / 2 - 0.3), 0.05), (112, 78, 56), "main", 0.08)
    T(o, bx("Soil", (w + 0.3, 0.75, 0.1), (0, -0.95, -h / 2 + 0.1), 0), (60, 44, 34), "main")
    for sx in (-1, 1):
        T(o, tube("Brk", bend_path([(sx * 1.6, -0.02, -h / 2 - 1.5), (sx * 1.6, -0.02, -h / 2 - 0.75), (sx * 1.6, -1.35, -h / 2 - 0.75)], 0.3, 4), 0.05, 4), IRON, "metal")
    random.seed(31)
    for i in range(11):
        x = -w / 2 + 0.1 + (w - 0.2) * i / 10
        s = sphere("Leafy", random.uniform(0.36, 0.5), (x, -0.95 + random.uniform(-0.15, 0.15), -h / 2 + 0.32 + random.uniform(0, 0.16)), (1, 1, 0.8), 2)
        wobble(s, 0.09, 3.0, i)
        T(o, s, (70 + random.randint(0, 30), 142 + random.randint(0, 30), 60), "main", 0.15)
    for i in range(16):
        c = random.choice([(250, 96, 120), (255, 204, 84), (250, 246, 250), (236, 120, 190), (255, 140, 70)])
        T(o, sphere("Bloom", random.uniform(0.12, 0.18), (random.uniform(-w / 2, w / 2), -0.95 + random.uniform(-0.4, 0.35), -h / 2 + random.uniform(0.55, 0.85)), sub=1), c, "main")
    for i in range(5):  # trailing ivy over the front
        x = random.uniform(-w / 2 + 0.2, w / 2 - 0.2)
        L = random.uniform(0.5, 1.3)
        T(o, tube("Vine", [(x, -1.44, -h / 2 + 0.1), (x + 0.05, -1.5, -h / 2 - L * 0.5), (x - 0.04, -1.47, -h / 2 - L)], 0.07, 4), (64, 128, 58), "main", 0.2)
    return o


@prop
def WinD():
    """Wide steel-framed triple window (mid-century / deco blocks)."""
    o = []
    w, h = 7.2, 5.6
    T(o, bx("Surround", (w + 0.7, 0.26, 0.34), (0, -0.13, h / 2 + 0.17)))
    T(o, bx("SurroundB", (w + 0.7, 0.5, 0.3), (0, -0.25, -h / 2 - 0.15)))
    for sx in (-1, 1):
        T(o, bx("Fin", (0.34, 0.5, h + 0.64), (sx * (w / 2 + 0.17), -0.25, 0.02)))
    DK = (52, 56, 62)
    sash(o, w, h, 0, 0, 0, DK)
    for sx in (-1, 1):
        T(o, bx("Mullion", (0.16, 0.24, h), (sx * w / 6, -0.12, 0), 0.02), DK, "main")
    for k in (-1, 0, 1):
        T(o, bx("Transom", (w / 3 - 0.2, 0.18, 0.1), (k * w / 3, -0.1, h / 2 - 1.5), 0.02), DK, "main")
    return o


@prop
def WinE():
    """French door onto a small stone balcony with an iron railing."""
    o = []
    w, h = 4.2, 8.0
    cz = -0.8  # the door reaches down to the balcony floor
    for sx in (-1, 1):
        T(o, bx("Jamb", (0.55, 0.34, h), (sx * (w / 2 + 0.275), -0.17, cz)))
    ped = extr("Ped", [(0, 0), (-0.4, 0), (-0.4, 0.5), (-0.8, 0.62), (-0.8, 0.8), (0, 0.8)], w + 1.8)
    ped.location = (0, 0, cz + h / 2)
    T(o, bake_xform(ped))
    bm = bmesh.new()  # a low triangular pediment over it
    pts = [(-(w + 1.8) / 2, 0.8), ((w + 1.8) / 2, 0.8), (0, 1.9)]
    f = [bm.verts.new((x, 0, cz + h / 2 + z)) for x, z in pts]
    b = [bm.verts.new((x, -0.5, cz + h / 2 + z)) for x, z in pts]
    bm.faces.new(f); bm.faces.new(list(reversed(b)))
    for i in range(3):
        bm.faces.new((f[i], f[(i + 1) % 3], b[(i + 1) % 3], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    T(o, shade(_new("Tri", bm), 20))
    sash(o, w, h, cz, 1, 3)
    # balcony
    bz = cz - h / 2 - 0.5
    slab = extr("Slab", [(0, 0), (-2.5, 0), (-2.7, 0.15), (-2.7, 0.4), (-2.55, 0.5), (0, 0.5)], w + 2.4)
    slab.location = (0, 0, bz)
    T(o, bake_xform(slab))
    for sx in (-1, 1):
        c = extr("Corbel", [(0, 0), (-0.4, 0.1), (-1.6, 1.0), (-2.2, 1.3), (0, 1.3)], 0.5)
        c.location = (sx * (w / 2 + 0.5), 0, bz - 1.3)
        T(o, bake_xform(c))
    hw, d, top = (w + 2.4) / 2 - 0.15, 2.5, bz + 0.5 + 3.0
    path = [(-hw, 0, top), (-hw, -d, top), (hw, -d, top), (hw, 0, top)]
    T(o, tube("TopRail", path, 0.09, 6), IRON, "metal")
    T(o, tube("LowRail", [(x, y, bz + 0.75) for x, y, z in path], 0.05, 4), IRON, "metal")
    for i in range(19):
        x = -hw + 2 * hw * i / 18
        T(o, box("Bal", (0.07, 0.07, 2.9), (x, -d, bz + 0.5 + 1.5), 0, 1), IRON, "metal", 0)
        if i % 3 == 1:  # a ring between some balusters
            T(o, tube("Ring", [(x + 0.17 + 0.14 * math.cos(a), -d, bz + 2.0 + 0.14 * math.sin(a)) for a in [k * math.pi / 5 for k in range(11)]], 0.03, 4, False), IRON, "metal")
    for sx in (-1, 1):
        for i in range(1, 7):
            T(o, box("BalS", (0.07, 0.07, 2.9), (sx * hw, -d * i / 7, bz + 0.5 + 1.5), 0, 1), IRON, "metal", 0)
    for sx in (-1, 1):
        T(o, bx("Post", (0.16, 0.16, 3.2), (sx * hw, -d, bz + 0.5 + 1.55), 0.03), IRON, "metal")
        T(o, sphere("Finial", 0.14, (sx * hw, -d, top + 0.16), sub=1), IRON, "metal")
    return o


@prop
def Cornice():
    """Roof cornice, 8 long: frieze, dentils, scroll brackets and a deep crown."""
    o = []
    T(o, extr("Frieze", [(0, 0), (-0.3, 0), (-0.3, 1.5), (0, 1.5)], 8))
    T(o, extr("Bed", [(0, 1.5), (-0.5, 1.5), (-0.62, 1.7), (-0.62, 2.0), (0, 2.0)], 8))
    crown = [(0, 2.0), (-1.5, 2.0), (-1.6, 2.1), (-1.6, 2.3), (-1.75, 2.4), (-1.95, 2.72), (-1.95, 2.95), (0, 2.95)]
    T(o, extr("Crown", crown, 8))
    for i in range(16):
        T(o, bx("Dentil", (0.3, 0.22, 0.3), (-4 + 0.25 + i * 0.5, -0.41, 1.3), 0.02))
    for i in range(4):
        b = extr("Mod", [(0, 0), (-0.25, 0), (-0.45, 0.25), (-0.7, 0.95), (-1.3, 1.3), (-1.45, 1.5), (0, 1.5)], 0.42)
        b.location = (-3 + i * 2, -0.02, 0.5)
        T(o, bake_xform(b))
    return o


@prop
def Belt():
    """String course between the shop floor and the floors above, 8 long."""
    o = []
    T(o, extr("Belt", [(0, 0), (-0.45, 0), (-0.45, 0.25), (-0.7, 0.4), (-1.0, 0.75), (-1.0, 0.95), (-0.85, 1.05), (0, 1.05)], 8))
    return o


@prop
def Pilaster():
    """Ground-floor pier: plinth, panelled shaft, capital. 2.2 wide, 14.2 tall; origin bottom centre."""
    o = []
    T(o, bx("Plinth", (2.4, 0.7, 1.5), (0, -0.35, 0.75), 0.05), (150, 146, 140))
    T(o, bx("Shaft", (2.0, 0.5, 11.2), (0, -0.25, 7.1)))
    for sx in (-1, 1):
        T(o, bx("PanelSide", (0.2, 0.12, 9.6), (sx * 0.62, -0.56, 7.1), 0.03))
    for z in (2.4, 11.8):
        T(o, bx("PanelEnd", (1.44, 0.12, 0.2), (0, -0.56, z), 0.03))
    cap = extr("Cap", [(0, 0), (-0.55, 0), (-0.6, 0.2), (-0.8, 0.45), (-0.95, 0.9), (-0.95, 1.2), (0, 1.2)], 2.5)
    cap.location = (0, 0, 12.7)
    T(o, bake_xform(cap))
    T(o, bx("Neck", (2.2, 0.62, 0.22), (0, -0.31, 12.5), 0.04))
    return o


@prop
def ShopWin():
    """Shop window bay, 8 wide, 0..10.6 tall: panelled bulkhead, big pane, transom lights."""
    o = []
    DK = (40, 42, 46)
    T(o, bx("Bulk", (8, 0.5, 2.0), (0, -0.25, 1.0), 0.04), (255, 255, 255), "paint")
    for k in (-1, 1):
        T(o, bx("BulkPanel", (3.2, 0.1, 1.2), (k * 1.9, -0.54, 1.0), 0.05), (228, 228, 228), "paint", 0)
    T(o, bx("Ledge", (8, 0.75, 0.2), (0, -0.37, 2.1), 0.04), DK, "main")
    for sx in (-1, 1):
        T(o, bx("Stile", (0.26, 0.4, 8.5), (sx * 3.87, -0.2, 6.35)), DK, "main")
    T(o, bx("Head", (8, 0.4, 0.26), (0, -0.2, 10.47)), DK, "main")
    T(o, bx("TransomBar", (8, 0.4, 0.2), (0, -0.2, 8.6)), DK, "main")
    for i in range(1, 5):
        T(o, bx("TBar", (0.1, 0.3, 1.8), (-4 + i * 1.6, -0.15, 9.5), 0.02), DK, "main")
    T(o, bx("Pane", (7.6, 0.06, 8.2), (0, -0.1, 6.3), 0), (255, 255, 255), "glass", 0)
    return o


@prop
def ShopDoor():
    """Recessed shop door, 5 wide, 0..10.6 tall: glazed timber door, brass pull, transom, stone step."""
    o = []
    DK = (40, 42, 46)
    T(o, bx("Step", (5, 1.2, 0.35), (0, -0.2, 0.17), 0.04), (170, 166, 160), "main")
    for sx in (-1, 1):
        T(o, bx("Jamb", (0.3, 0.5, 10.3), (sx * 2.35, -0.25, 5.45)), DK, "main")
    T(o, bx("Head", (5, 0.5, 0.3), (0, -0.25, 10.45)), DK, "main")
    T(o, bx("TransomBar", (5, 0.5, 0.22), (0, -0.25, 8.6)), DK, "main")
    T(o, bx("TransomPane", (4.4, 0.06, 1.7), (0, -0.1, 9.5), 0), (255, 255, 255), "glass", 0)
    # the door leaf (tinted): rails, stiles, kick panel
    for sx in (-1, 1):
        T(o, bx("DStile", (0.5, 0.26, 8.1), (sx * 1.95, -0.02, 4.4)), (255, 255, 255), "paint")
    T(o, bx("DTop", (4.4, 0.26, 0.5), (0, -0.02, 8.2)), (255, 255, 255), "paint")
    T(o, bx("DKick", (4.4, 0.26, 1.7), (0, -0.02, 1.2)), (255, 255, 255), "paint")
    T(o, bx("DKickPanel", (3.2, 0.08, 1.0), (0, -0.18, 1.2), 0.04), (226, 226, 226), "paint", 0)
    T(o, bx("DMid", (4.4, 0.26, 0.3), (0, -0.02, 4.4)), (255, 255, 255), "paint")
    T(o, bx("DPane", (3.5, 0.05, 5.9), (0, 0.0, 5.1), 0), (255, 255, 255), "glass", 0)
    T(o, bx("KickPlate", (3.6, 0.03, 0.5), (0, -0.17, 0.62), 0.01), (214, 176, 96), "chrome")
    T(o, tube("Pull", bend_path([(1.45, -0.16, 3.6), (1.45, -0.42, 3.6), (1.45, -0.42, 5.2), (1.45, -0.16, 5.2)], 0.12, 4), 0.055, 6), (214, 176, 96), "chrome")
    return o


@prop
def Awning():
    """Canvas awning, 8 wide, reaching 5.4 out: sloped top in 8 stripes (paint / paint2), scalloped valance,
    iron arms. Origin = the wall line at the top edge."""
    o = []
    out, drop, val = 5.4, 2.5, 1.0
    for i in range(8):
        x0, x1 = -4 + i, -3 + i
        g = "paint" if i % 2 == 0 else "paint2"
        bm = bmesh.new()
        n = 5
        top, bot = [], []
        for k in range(n + 1):
            t = k / n
            sag = -0.12 * math.sin(math.pi * t)
            top.append([bm.verts.new((x, -out * t, -drop * t + sag)) for x in (x0, x1)])
        for k in range(n):
            bm.faces.new((top[k][0], top[k][1], top[k + 1][1], top[k + 1][0]))
        # the valance: a hanging flap with a scalloped lower edge
        e0, e1 = top[n]
        m = 6
        row = [bm.verts.new((x0 + (x1 - x0) * j / m, -out - 0.02, -drop - 0.12 - val + 0.38 * abs(math.sin(math.pi * j / m)) ** 0.6 * 0 - 0.3 * math.sin(math.pi * j / m))) for j in range(m + 1)]
        up = [bm.verts.new((x0 + (x1 - x0) * j / m, -out, -drop - 0.12)) for j in range(m + 1)]
        for j in range(m):
            bm.faces.new((up[j], up[j + 1], row[j + 1], row[j]))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = _new("Stripe", bm)
        sm = ob.modifiers.new("s", "SOLIDIFY")
        sm.thickness = 0.07
        apply_mods(ob)
        shade(ob, 40)
        T(o, ob, (255, 255, 255), g, 0.04)
    for sx in (-1, 1):
        T(o, tube("Arm", [(sx * 3.85, -0.05, -drop - 0.5), (sx * 3.85, -out + 0.05, -drop - 0.2)], 0.06, 6), IRON, "metal")
        T(o, tube("Stay", [(sx * 3.85, -0.05, -0.3), (sx * 3.85, -out + 0.05, -drop - 0.2)], 0.045, 6), IRON, "metal")
    T(o, tube("FrontBar", [(-3.95, -out + 0.03, -drop - 0.2), (3.95, -out + 0.03, -drop - 0.2)], 0.05, 6), IRON, "metal")
    return o


@prop
def RoofTank():
    """Timber water tank on a steel frame with a conical cap. ~15 tall; origin bottom centre."""
    o = []
    WOOD = (150, 104, 70)
    r, h, z0 = 3.4, 7.5, 4.5
    n = 26
    for i in range(n):
        a = 2 * math.pi * i / n
        s = bx("Stave", (2 * math.pi * r / n * 0.96, 0.3, h), (0, 0, 0), 0.03)
        s.rotation_euler = (0, 0, a + math.pi / 2)
        s.location = (r * math.cos(a), r * math.sin(a), z0 + h / 2)
        bake_xform(s)
        T(o, s, tuple(int(c * random.uniform(0.82, 1.08)) for c in WOOD), "main", 0.1)
    for z in (z0 + 0.8, z0 + 2.6, z0 + 4.6, z0 + 6.6):
        T(o, tube("Hoop", [((r + 0.17) * math.cos(a), (r + 0.17) * math.sin(a), z) for a in [2 * math.pi * k / 32 for k in range(33)]], 0.07, 4, False), IRON, "metal")
    T(o, lathe("Cap", [(0, z0 + h + 2.6), (0.3, z0 + h + 2.5), (r + 0.5, z0 + h + 0.1), (r + 0.5, z0 + h - 0.05), (0, z0 + h - 0.05)], N=26), (92, 84, 78), "main")
    T(o, cyl("Floor", r + 0.1, 0.3, (0, 0, z0 - 0.1), 26, 0.02), (110, 80, 58), "main")
    for sx in (-1, 1):
        for sy in (-1, 1):
            T(o, bx("Leg", (0.3, 0.3, z0), (sx * 2.3, sy * 2.3, z0 / 2)), IRON, "metal")
        T(o, tube("BraceA", [(sx * 2.3, -2.3, 0.3), (sx * 2.3, 2.3, z0 - 0.4)], 0.07, 4), IRON, "metal")
        T(o, tube("BraceB", [(-2.3, sx * 2.3, z0 - 0.4), (2.3, sx * 2.3, 0.3)], 0.07, 4), IRON, "metal")
        T(o, bx("Beam", (5.2, 0.3, 0.3), (0, sx * 2.3, z0 - 0.4)), IRON, "metal")
    for k in range(9):  # ladder
        T(o, bx("Rung", (0.9, 0.06, 0.06), (0, -r - 0.5, 1.2 + k * 1.3), 0), IRON, "metal")
    for sx in (-1, 1):
        T(o, bx("Rail", (0.07, 0.07, 11.6), (sx * 0.45, -r - 0.5, 6.2), 0), IRON, "metal")
    return o


@prop
def RoofAC():
    """Rooftop air handler: louvred box, fan cowl, duct elbow. Origin bottom centre."""
    o = []
    G = (176, 180, 184)
    T(o, bx("Skid", (6.2, 4.2, 0.4), (0, 0, 0.2)), (70, 72, 78), "main")
    T(o, bx("Body", (6, 4, 3), (0, 0, 1.9), 0.08), G, "main", 0.06)
    for i in range(9):
        T(o, box("Louvre", (2.4, 0.08, 0.26), (-1.5, -2.02, 0.9 + i * 0.24), 0, 1, (math.radians(-35), 0, 0)), (120, 124, 130), "main", 0)
    T(o, bx("Panel", (2.2, 0.06, 2.2), (1.6, -2.02, 1.9), 0.03), (196, 200, 204), "main")
    T(o, cyl("Cowl", 1.2, 0.5, (1.4, 0, 3.6), 20, 0.04), (90, 94, 100), "main")
    for k in range(6):
        a = k * math.pi / 3
        T(o, box("Blade", (1.0, 0.3, 0.04), (1.4 + 0.5 * math.cos(a), 0.5 * math.sin(a), 3.8), 0, 1, (0.3, 0, a)), (60, 62, 66), "main", 0)
    T(o, tube("Duct", bend_path([(-1.6, 0, 3.3), (-1.6, 0, 4.6), (-1.6, 3.2, 4.6), (-1.6, 3.2, 0.2)], 0.6, 5), 0.55, 10), (150, 154, 158), "chrome")
    return o


# ---------------------------------------------------------------- trees

def canopy(o, blobs, base, seed, small=5, light=(1.16, 1.14, 0.9)):
    """Leaf masses: each big blob gets a ring of smaller clumps so the outline is broken, not a ball."""
    random.seed(seed)
    zs = [c[2] for c, r in blobs]
    zlo, zhi = min(zs) - 3, max(zs) + 3
    def grad(p, c):
        t = min(max((p.z - zlo) / (zhi - zlo), 0), 1)
        k = 0.62 + 0.5 * t
        return Vector((c.x * k * (1 + (light[0] - 1) * t), c.y * k * (1 + (light[1] - 1) * t), c.z * k * (1 + (light[2] - 1) * t)))
    for i, (c, r) in enumerate(blobs):
        s = sphere("Leaf", r, c, (1, 1, 0.82), 3)
        wobble(s, r * 0.2, 0.55, seed + i)
        wobble(s, r * 0.06, 2.4, seed + i + 9)
        o.append(paint(s, base, "leaf", 0.1, grad))
        for k in range(small):
            a = random.uniform(0, 2 * math.pi)
            e = random.uniform(-0.5, 0.9)
            d = r * random.uniform(0.72, 1.0)
            rr = r * random.uniform(0.28, 0.45)
            p = (c[0] + d * math.cos(a) * math.cos(e), c[1] + d * math.sin(a) * math.cos(e), c[2] + d * math.sin(e) * 0.8)
            s = sphere("Clump", rr, p, (1, 1, 0.8), 2)
            wobble(s, rr * 0.25, 1.3, seed + i * 7 + k)
            tint = tuple(min(255, int(v * random.uniform(0.9, 1.12))) for v in base)
            o.append(paint(s, tint, "leaf", 0.1, grad))


def trunk(o, pts, r0, r1, col, branches=()):
    n = len(pts)
    rad = [r0 * (1.75 if i == 0 else 1.0) + (r1 - r0) * i / (n - 1) for i in range(n)]
    pts = [pts[0], tuple(Vector(pts[0]).lerp(Vector(pts[1]), 0.12))] + list(pts[1:])
    rad = [rad[0], r0 * 1.12] + rad[1:]
    grad = lambda p, c: c * (0.8 + 0.25 * min(p.z / 6.0, 1))
    o.append(paint(limb("Trunk", pts, rad, 12), col, "bark", 0.08, grad))
    for a, b, r in branches:
        mid = tuple(Vector(a).lerp(Vector(b), 0.5) + Vector((0, 0, 0.5)))
        o.append(paint(limb("Branch", [a, mid, b], [r, r * 0.75, r * 0.4], 8), col, "bark", 0.08))


BARK = (236, 214, 196)


@prop
def TreeA():
    """Broad street tree (plane / maple), ~23 tall."""
    o = []
    trunk(o, [(0, 0, 0), (0.15, 0.05, 4), (0.35, 0.2, 8), (0.2, 0.1, 12)], 0.62, 0.3, BARK,
          [((0.3, 0.15, 7.2), (3.4, 1.0, 11.6), 0.26), ((0.3, 0.15, 8.4), (-3.2, -1.2, 12.4), 0.26), ((0.3, 0.2, 9.4), (0.6, 3.2, 12.6), 0.2), ((0.25, 0.1, 9.0), (-0.4, -3.2, 12.2), 0.2)])
    canopy(o, [((0, 0, 16.2), 4.8), ((3.6, 1.2, 13.4), 3.5), ((-3.4, -1.3, 14.2), 3.6), ((0.6, -3.4, 13.4), 3.1),
               ((-0.6, 3.4, 13.6), 3.1), ((0.6, 0.4, 19.6), 3.2)], (150, 226, 104), 1)
    return o


@prop
def TreeB():
    """Tall columnar tree (poplar / hornbeam), ~27 tall."""
    o = []
    trunk(o, [(0, 0, 0), (0.05, 0, 4), (0, 0.05, 9)], 0.5, 0.3, (226, 206, 190))
    canopy(o, [((0, 0, 10.5), 3.4), ((0.3, 0.2, 14.6), 3.4), ((-0.2, 0, 18.6), 3.0), ((0, -0.2, 22.2), 2.4), ((0.1, 0, 25.0), 1.5)],
           (120, 204, 110), 2, 6)
    return o


@prop
def TreeC():
    """Cherry in blossom, ~18 tall: a low forking trunk under a wide pink cloud."""
    o = []
    trunk(o, [(0, 0, 0), (0.3, 0, 3.2), (-0.1, 0.25, 6.2), (0.1, 0, 8.6)], 0.55, 0.3, (214, 176, 170),
          [((0.25, 0.05, 3.4), (3.6, -0.6, 8.8), 0.3), ((0, 0.2, 5.2), (-3.4, 1.0, 9.4), 0.26), ((0, 0.2, 6.0), (0.6, 3.2, 9.6), 0.2)])
    canopy(o, [((0, 0, 12.2), 4.0), ((3.8, -0.7, 10.2), 3.0), ((-3.6, 1.0, 10.8), 3.1), ((0.6, 3.4, 10.4), 2.7),
               ((-0.3, -3.0, 10.6), 2.6), ((0.4, 0.2, 15.0), 2.6)], (255, 196, 216), 3, 6, (1.04, 1.1, 1.08))
    return o


@prop
def Bush():
    """Clipped hedge in a stone planter with flowers, 8 long."""
    o = []
    o.append(paint(bx("Planter", (8.0, 2.4, 1.3), (0, 0, 0.65), 0.08), (224, 220, 212), "main", 0.05))
    o.append(paint(bx("Lip", (8.3, 2.7, 0.3), (0, 0, 1.4), 0.08), (236, 232, 226), "main", 0.05))
    o.append(paint(bx("Soil", (7.5, 1.9, 0.2), (0, 0, 1.5), 0), (70, 52, 40), "main"))
    canopy(o, [((-2.6, 0, 2.3), 1.15), ((0, 0.1, 2.45), 1.25), ((2.6, -0.1, 2.3), 1.15), ((-1.3, 0.2, 2.2), 0.95), ((1.3, -0.2, 2.2), 0.95)],
           (130, 208, 104), 7, 4)
    random.seed(7)
    for i in range(22):
        x, y = random.uniform(-3.5, 3.5), random.uniform(-0.85, 0.85)
        c = random.choice([(250, 110, 140), (255, 210, 80), (244, 242, 250), (196, 126, 232)])
        o.append(paint(sphere("Flower", 0.24, (x, y, 2.95 + random.uniform(0, 0.6)), sub=1), c, "main"))
    return o


@prop
def Balustrade():
    """Stone promenade balustrade, 8 long, 3.5 tall, centred on y = 0: plinth, turned balusters, moulded rail,
    a square pedestal with a cap at one end (tiles end to end)."""
    o = []
    base = extr("Base", [(-0.6, 0), (0.6, 0), (0.6, 0.35), (0.48, 0.5), (-0.48, 0.5), (-0.6, 0.35)], 8)
    T(o, base)
    rail = extr("Rail", [(-0.5, 2.85), (0.5, 2.85), (0.62, 3.0), (0.62, 3.2), (0.45, 3.4), (-0.45, 3.4), (-0.62, 3.2), (-0.62, 3.0)], 8)
    T(o, rail)
    prof = [(0, 0.5), (0.3, 0.5), (0.3, 0.62), (0.2, 0.7), (0.34, 1.05), (0.36, 1.3), (0.2, 1.9), (0.16, 2.3), (0.24, 2.45), (0.2, 2.6), (0.3, 2.7), (0.3, 2.85), (0, 2.85)]
    for i in range(7):
        T(o, lathe("Bal", prof, (-3.0 + i * 0.93, 0, 0), N=12), var=0.05)
    T(o, bx("Ped", (1.1, 1.3, 3.4), (3.45, 0, 1.7), 0.05))
    T(o, bx("PedCap", (1.4, 1.6, 0.3), (3.45, 0, 3.55), 0.06))
    T(o, sphere("Ball", 0.42, (3.45, 0, 4.05), sub=2))
    return o
