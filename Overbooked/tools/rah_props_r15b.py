"""Round 15b: modelled staff uniforms (StaffLook swaps them in for the part-built ones).
Groups: main = the uniform colour (painted near white, the game sets Color), tint = the trim colour (painted white,
the game sets Color), trim = own colours (black visors, white shirts), chrome = metal (buttons, badges).
Headwear: origin = the head's centre (head top is about +0.6, radius about 0.62); front = -Y.
  WearPeakedCap, WearTopHat, WearToque, WearHardHat, WearCap, WearBeanie
Torso (origin = UpperTorso centre, torso 1.94 x 1.0 x 1.7):
  WearGreatcoat, WearBlazer, WearChefJacket, WearApronBib
Waist (origin = LowerTorso centre, lower torso 1.94 x 1.0 x 0.4; hangs down from its top at +0.2):
  WearCoatSkirt (long, open front), WearBlazerSkirt (short, open front), WearApron (front panel and ties)
Loaded by rah_props.py (exec) after r15.
"""

NEAR_WHITE = (240, 240, 240)
VISOR = (24, 24, 28)
SHIRT = (246, 246, 242)


def slab(name, pts, thick, y, bevel=0.015):
    """A flat prism: the outline pts (x, z) extruded thick along Y, its front face at y."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y, z)) for x, z in pts]
    back = [bm.verts.new((x, y + thick, z)) for x, z in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    if bevel > 0:
        m = ob.modifiers.new("bv", "BEVEL")
        m.width = bevel
        m.segments = 2
        m.limit_method = "ANGLE"
        apply_mods(ob)
    return shade(ob, 40)


def _se(t, a, b, p=4.0):
    """A point on a rounded box outline (superellipse), t = 0 at the front (-Y), going round through +X."""
    s, c = math.sin(t), math.cos(t)
    x = a * math.copysign(abs(s) ** (2 / p), s)
    y = -b * math.copysign(abs(c) ** (2 / p), c)
    return x, y


def drape(name, rings, closed, thick=0.06, wob=0.0, seed=0.0):
    """A cloth sheet through rings of points (each ring the same count), thickened outward."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for k in range(len(rings) - 1):
        a, b = vs[k], vs[k + 1]
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    if wob:
        wobble(ob, wob, 2.2, seed)
    m = ob.modifiers.new("sd", "SOLIDIFY")
    m.thickness = thick
    m.offset = 0
    apply_mods(ob)
    return shade(ob, 50)


def skirt_rings(top_a, top_b, bot_a, bot_b, z0, z1, slit, n=40, rows=6, flare_p=4.0):
    rings = []
    for r in range(rows + 1):
        u = r / rows
        a = top_a + (bot_a - top_a) * (u ** 1.3)
        b = top_b + (bot_b - top_b) * (u ** 1.3)
        z = z0 + (z1 - z0) * u
        ring = []
        for i in range(n + 1):
            t = slit / 2 + (2 * math.pi - slit) * i / n
            x, y = _se(t, a, b, flare_p)
            # soft folds that grow toward the hem
            fold = 0.035 * u * math.sin(t * 7)
            ring.append((x * (1 + fold), y * (1 + fold), z))
        rings.append(ring)
    return rings


def pleat_lathe(name, prof, pleats, depth, N=96):
    """A lathe whose radius ripples (chef's toque pleats, a beanie's ribs)."""
    bm = bmesh.new()
    rows = []
    for j in range(N):
        t = 2 * math.pi * j / N
        row = []
        for r, z, w in prof:
            rr = r * (1 + depth * w * math.cos(t * pleats))
            row.append(bm.verts.new((rr * math.cos(t), rr * math.sin(t), z)))
        rows.append(row)
    for j in range(N):
        a, b = rows[j], rows[(j + 1) % N]
        for k in range(len(prof) - 1):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
    # close the top
    top = [rows[j][-1] for j in range(N)]
    c = bm.verts.new((0, 0, prof[-1][1] + 0.02))
    for j in range(N):
        bm.faces.new((top[j], top[(j + 1) % N], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    return shade(ob, 60)


def _buttons(o, xs, zs, y, r=0.055, group="chrome", col=CHROME):
    for x in xs:
        for z in zs:
            o.append(paint(cyl("Button", r, 0.04, (x, y, z), 14, 0.012, (math.pi / 2, 0, 0)), col, group))


# ---------------------------------------------------------------- headwear

@prop
def WearPeakedCap():
    o = []
    o.append(paint(lathe("Band", [(0.0, 0.3), (0.64, 0.3), (0.65, 0.34), (0.65, 0.58), (0.64, 0.62), (0.0, 0.62)]), NEAR_WHITE, "tint", 0.01))
    # the crown: wider than the band, a little higher at the front, a soft top
    cr = lathe("Crown", [(0.6, 0.6), (0.7, 0.68), (0.8, 0.8), (0.82, 0.86), (0.78, 0.92), (0.5, 0.95), (0.0, 0.96)], N=48)
    for v in cr.data.vertices:
        if v.co.z > 0.7:
            v.co.z += max(0, -v.co.y) * 0.12
    o.append(paint(cr, NEAR_WHITE, "main", 0.02))
    # the peak: a curved half disc dipping forward
    bm = bmesh.new()
    rows = []
    for i in range(17):
        t = math.pi * i / 16
        row = []
        for k, rr in enumerate((0.62, 0.8, 0.98)):
            x = math.cos(t) * 0.66 * (rr / 0.62 if k else 1)
            y = -math.sin(t) * rr
            z = 0.33 - (rr - 0.62) * 0.35
            row.append(bm.verts.new((x * 0.98, y, z)))
        rows.append(row)
    for i in range(16):
        for k in range(2):
            bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
    pk = _new("Peak", bm)
    m = pk.modifiers.new("sd", "SOLIDIFY")
    m.thickness = 0.05
    apply_mods(pk)
    o.append(paint(shade(pk, 50), VISOR, "trim", 0.01))
    o.append(paint(tube("Cord", [(-0.6, -0.25, 0.4), (-0.3, -0.62, 0.42), (0.3, -0.62, 0.42), (0.6, -0.25, 0.4)], 0.022, 6), CHROME, "chrome"))
    o.append(paint(box("Badge", (0.26, 0.05, 0.22), (0, -0.68, 0.74), 0.04, 3, (math.radians(-12), 0, 0)), CHROME, "chrome"))
    o.append(paint(sphere("BadgeGem", 0.05, (0, -0.71, 0.75)), (200, 40, 50), "trim"))
    return o


@prop
def WearTopHat():
    o = []
    brim = lathe("Brim", [(0.0, 0.42), (0.98, 0.42), (1.02, 0.47), (0.98, 0.5), (0.6, 0.47), (0.0, 0.47)], N=56)
    for v in brim.data.vertices:  # the sides curl up a touch
        r = math.hypot(v.co.x, v.co.y)
        if r > 0.7:
            v.co.z += (abs(v.co.x) / 1.0) ** 2 * 0.12
    o.append(paint(brim, (30, 28, 34), "trim", 0.02))
    o.append(paint(lathe("Crown", [(0.6, 0.46), (0.58, 0.9), (0.6, 1.5), (0.63, 1.68), (0.6, 1.72), (0.0, 1.73)], N=48), (30, 28, 34), "trim", 0.02))
    o.append(paint(lathe("Band", [(0.0, 0.48), (0.615, 0.48), (0.605, 0.72), (0.0, 0.72)], N=48), NEAR_WHITE, "tint", 0.01))
    return o


@prop
def WearToque():
    o = []
    o.append(paint(lathe("Band", [(0.0, 0.3), (0.66, 0.3), (0.67, 0.34), (0.67, 0.68), (0.66, 0.72), (0.0, 0.72)], N=56), SHIRT, "trim", 0.01))
    # pleated column puffing out into a mushroom top
    prof = [(0.66, 0.7, 0.2), (0.68, 0.95, 1.0), (0.72, 1.3, 1.0), (0.82, 1.55, 0.8), (0.86, 1.68, 0.5), (0.74, 1.8, 0.3), (0.45, 1.87, 0.15)]
    o.append(paint(pleat_lathe("Puff", prof, 14, 0.06), SHIRT, "trim", 0.02))
    return o


@prop
def WearHardHat():
    o = []
    yel = (250, 196, 40)
    dome = lathe("Dome", [(0.0, 1.05), (0.4, 1.02), (0.62, 0.9), (0.72, 0.68), (0.74, 0.42), (0.74, 0.34), (0.0, 0.34)], N=56)
    o.append(paint(dome, yel, "trim", 0.02))
    brim = lathe("Brim", [(0.0, 0.3), (0.86, 0.3), (0.9, 0.34), (0.86, 0.37), (0.0, 0.37)], N=56)
    for v in brim.data.vertices:  # a longer peak at the front
        if v.co.y < 0:
            k = (-v.co.y / 0.9) ** 2
            v.co.y -= k * 0.22
            v.co.z -= k * 0.05
    o.append(paint(brim, yel, "trim", 0.02))
    o.append(paint(box("Ridge", (0.16, 1.2, 0.14), (0, 0, 0.98), 0.06, 4), (236, 180, 30), "trim"))
    for sx in (-1, 1):  # side ribs following the dome
        pts = [(sx * 0.3, -0.67 * math.cos(a), 0.34 + 0.68 * math.sin(a)) for a in [math.radians(d) for d in range(30, 151, 15)]]
        o.append(paint(tube("Rib", [(x, y, z * 1.0 + 0.0) for x, y, z in pts], 0.04, 6), (236, 180, 30), "trim"))
    o.append(paint(box("Sticker", (0.3, 0.04, 0.2), (0, -0.7, 0.62), 0.03, 3, (math.radians(-22), 0, 0)), NEAR_WHITE, "tint"))
    return o


@prop
def WearCap():
    o = []
    dome = lathe("Dome", [(0.0, 0.98), (0.3, 0.96), (0.52, 0.86), (0.64, 0.68), (0.67, 0.42), (0.67, 0.34), (0.0, 0.34)], N=48)
    o.append(paint(dome, NEAR_WHITE, "main", 0.02))
    for i in range(6):  # panel seams
        t = 2 * math.pi * i / 6
        pts = []
        for k in range(7):
            u = k / 6
            ang = u * math.pi / 2
            r = 0.675 * math.cos(ang) + 0.01
            pts.append((r * math.cos(t), r * math.sin(t), 0.42 + 0.56 * math.sin(ang)))
        o.append(paint(tube("Seam", pts, 0.012, 4), NEAR_WHITE, "tint"))
    o.append(paint(sphere("Button", 0.07, (0, 0, 0.99), (1, 1, 0.6)), NEAR_WHITE, "tint"))
    # the bill: curved across, a little down
    bm = bmesh.new()
    rows = []
    for i in range(13):
        t = math.pi * (0.15 + 0.7 * i / 12)
        row = []
        for rr in (0.62, 0.86, 1.08):
            x = math.cos(t) * 0.62 * (0.95 if rr > 0.7 else 1)
            y = -math.sin(t) * rr
            z = 0.4 - (rr - 0.62) * 0.18 - abs(math.cos(t)) * 0.05
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(12):
        for k in range(2):
            bm.faces.new((rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1]))
    bill = _new("Bill", bm)
    m = bill.modifiers.new("sd", "SOLIDIFY")
    m.thickness = 0.05
    apply_mods(bill)
    o.append(paint(shade(bill, 50), NEAR_WHITE, "main", 0.02))
    o.append(paint(box("Logo", (0.24, 0.04, 0.16), (0, -0.64, 0.66), 0.03, 3, (math.radians(-18), 0, 0)), NEAR_WHITE, "tint"))
    return o


@prop
def WearBeanie():
    o = []
    knit = pleat_lathe("Knit", [(0.67, 0.5, 0.3), (0.66, 0.7, 0.4), (0.6, 0.88, 0.4), (0.46, 1.02, 0.3), (0.22, 1.1, 0.2)], 24, 0.03)
    o.append(paint(knit, NEAR_WHITE, "main", 0.03))
    cuff = pleat_lathe("Cuff", [(0.7, 0.3, 1.0), (0.71, 0.4, 1.0), (0.71, 0.52, 1.0), (0.68, 0.56, 0.5)], 40, 0.035)
    o.append(paint(cuff, (220, 220, 220), "main", 0.02))
    pom = sphere("Pom", 0.2, (0, 0, 1.2), (1, 1, 0.9), 3)
    wobble(pom, 0.03, 9, 2)
    o.append(paint(pom, NEAR_WHITE, "tint", 0.05))
    return o


# ---------------------------------------------------------------- torso

def _shell(o, w=2.02, d=1.08, h=1.76, col=NEAR_WHITE, group="main"):
    sh = box("Shell", (w, d, h), (0, 0, 0), 0.1, 4, cuts=3)
    wobble(sh, 0.008, 3.0, 1.0)
    o.append(paint(sh, col, group, 0.02))


def _stand_collar(o, h=0.2, group="main", col=NEAR_WHITE):
    rings = []
    for z in (0.86, 0.86 + h):
        ring = []
        for i in range(29):
            t = 0.35 + (2 * math.pi - 0.7) * i / 28
            x, y = _se(t, 0.5, 0.36, 2.6)
            ring.append((x, y + 0.04, z))
        rings.append(ring)
    o.append(paint(drape("Collar", rings, False, 0.07), col, group, 0.02))


@prop
def WearGreatcoat():
    o = []
    _shell(o)
    _stand_collar(o, 0.22)
    # the double-breasted front: an overlapping flap edge, two rows of brass buttons
    o.append(paint(slab("Flap", [(-0.14, -0.84), (0.46, -0.84), (0.46, 0.84), (-0.14, 0.84)], 0.03, -0.575), NEAR_WHITE, "main", 0.02))
    o.append(paint(box("FlapEdge", (0.03, 0.035, 1.68), (-0.14, -0.585, 0), 0.01, 2), NEAR_WHITE, "tint"))
    _buttons(o, (-0.36, 0.26), (0.5, 0.18, -0.14, -0.46), -0.62, 0.065)
    # epaulettes with a fringe, a belt with a buckle
    for sx in (-1, 1):
        o.append(paint(box("Epaulette", (0.6, 0.62, 0.08), (sx * 0.74, 0, 0.9), 0.04, 3), NEAR_WHITE, "tint"))
        for k in range(7):
            o.append(paint(cyl("Fringe", 0.025, 0.2, (sx * (0.98 + 0.0 * k), -0.27 + k * 0.09, 0.8), 6, 0.0), NEAR_WHITE, "tint"))
        o.append(paint(cyl("EpButton", 0.05, 0.04, (sx * 0.56, 0, 0.95), 12, 0.01), CHROME, "chrome"))
    o.append(paint(box("Belt", (2.08, 1.14, 0.2), (0, 0, -0.76), 0.04, 3), (36, 32, 34), "trim"))
    o.append(paint(box("Buckle", (0.34, 0.06, 0.26), (0, -0.585, -0.76), 0.04, 3), CHROME, "chrome"))
    o.append(paint(box("BuckleIn", (0.2, 0.08, 0.12), (0, -0.59, -0.76), 0.02, 2), (36, 32, 34), "trim"))
    # cuffed sleeve tops (the arms are coloured by the game), a breast pocket flap and an aiguillette cord
    o.append(paint(slab("PocketFlap", [(0.5, 0.28), (0.86, 0.28), (0.84, 0.18), (0.68, 0.14), (0.52, 0.18)], 0.03, -0.575), NEAR_WHITE, "main", 0.02))
    o.append(paint(tube("Aiguillette", [(0.95, -0.2, 0.82), (0.82, -0.6, 0.5), (0.55, -0.62, 0.28), (0.3, -0.62, 0.36)], 0.025, 6), NEAR_WHITE, "tint"))
    o.append(paint(tube("Aiguillette2", [(0.95, -0.15, 0.8), (0.86, -0.6, 0.36), (0.62, -0.62, 0.1), (0.4, -0.62, 0.2)], 0.022, 6), NEAR_WHITE, "tint"))
    return o


@prop
def WearBlazer():
    o = []
    _shell(o)
    # the shirt and tie in the V
    o.append(paint(slab("ShirtV", [(-0.3, 0.86), (0.3, 0.86), (0.0, -0.05)], 0.02, -0.565, 0.005), SHIRT, "trim"))
    o.append(paint(slab("Tie", [(-0.07, 0.72), (0.07, 0.72), (0.1, 0.1), (0.0, -0.02), (-0.1, 0.1)], 0.03, -0.585, 0.008), NEAR_WHITE, "tint"))
    o.append(paint(slab("Knot", [(-0.09, 0.84), (0.09, 0.84), (0.06, 0.7), (-0.06, 0.7)], 0.05, -0.6, 0.01), NEAR_WHITE, "tint"))
    # notched lapels
    for sx in (-1, 1):
        pts = [(sx * 0.3, 0.86), (sx * 0.52, 0.86), (sx * 0.5, 0.62), (sx * 0.62, 0.58), (sx * 0.32, 0.12), (sx * 0.02, -0.05)]
        if sx > 0:
            pts = pts[::-1]
        o.append(paint(slab("Lapel", pts, 0.035, -0.6, 0.012), (226, 226, 226), "main", 0.01))
    o.append(paint(slab("Collar", [(-0.52, 0.86), (0.52, 0.86), (0.5, 0.98), (-0.5, 0.98)], 0.3, -0.25, 0.03), (226, 226, 226), "main"))
    _buttons(o, (0.0,), (-0.28,), -0.58, 0.06, "trim", (40, 40, 44))
    for sx in (-1, 1):
        o.append(paint(slab("PocketFlap", [(sx * 0.4, -0.5), (sx * 0.86, -0.5), (sx * 0.86, -0.62), (sx * 0.4, -0.62)], 0.03, -0.575), NEAR_WHITE, "main"))
    o.append(paint(slab("BreastPocket", [(-0.82, 0.38), (-0.5, 0.38), (-0.5, 0.32), (-0.82, 0.32)], 0.03, -0.575), NEAR_WHITE, "main"))
    o.append(paint(slab("PocketSquare", [(-0.78, 0.38), (-0.72, 0.5), (-0.64, 0.42), (-0.57, 0.5), (-0.54, 0.38)], 0.03, -0.585, 0.008), NEAR_WHITE, "tint"))
    return o


@prop
def WearChefJacket():
    o = []
    _shell(o)
    _stand_collar(o, 0.18)
    o.append(paint(slab("Flap", [(-0.06, -0.84), (0.6, -0.84), (0.6, 0.86), (-0.06, 0.86)], 0.03, -0.575), NEAR_WHITE, "main", 0.02))
    o.append(paint(box("Piping", (0.03, 0.035, 1.7), (-0.06, -0.585, 0), 0.01, 2), NEAR_WHITE, "tint"))
    # cloth knot buttons
    for x in (-0.3, 0.38):
        for z in (0.55, 0.22, -0.11, -0.44):
            b = sphere("Knot", 0.065, (x, -0.61, z), (1, 0.7, 1), 2)
            o.append(paint(b, NEAR_WHITE, "tint", 0.03))
    o.append(paint(box("Thermo", (0.05, 0.05, 0.36), (-0.7, -0.6, 0.3), 0.02, 2), CHROME, "chrome"))
    o.append(paint(box("ThermoPocket", (0.3, 0.035, 0.28), (-0.7, -0.57, 0.22), 0.02, 2), NEAR_WHITE, "main"))
    return o


@prop
def WearApronBib():
    o = []
    o.append(paint(slab("Bib", [(-0.5, 0.62), (0.5, 0.62), (0.56, -0.86), (-0.56, -0.86)], 0.03, -0.585, 0.01), NEAR_WHITE, "main", 0.02))
    o.append(paint(slab("BibPocket", [(-0.3, 0.1), (0.3, 0.1), (0.3, -0.3), (-0.3, -0.3)], 0.025, -0.605, 0.008), (230, 230, 230), "main"))
    for sx in (-1, 1):
        o.append(paint(tube("Strap", [(sx * 0.46, -0.6, 0.6), (sx * 0.5, -0.4, 0.92), (sx * 0.5, 0.2, 0.92), (sx * 0.4, 0.56, 0.5), (sx * 0.2, 0.58, -0.7)], 0.035, 6), NEAR_WHITE, "tint"))
    return o


# ---------------------------------------------------------------- waist

@prop
def WearCoatSkirt():
    o = []
    rings = skirt_rings(1.03, 0.56, 1.22, 0.78, 0.18, -2.25, 0.5)
    o.append(paint(drape("Skirt", rings, False, 0.07, 0.012, 3.0), NEAR_WHITE, "main", 0.02))
    # a hem band and back vent
    hem = skirt_rings(1.225, 0.785, 1.23, 0.79, -2.12, -2.25, 0.5, rows=1)
    o.append(paint(drape("Hem", hem, False, 0.09), NEAR_WHITE, "tint"))
    _buttons(o, (-0.36, 0.26), (-0.2, -0.55), -0.67, 0.06)
    return o


@prop
def WearBlazerSkirt():
    o = []
    rings = skirt_rings(1.03, 0.56, 1.1, 0.64, 0.18, -0.75, 0.75, rows=4)
    o.append(paint(drape("Skirt", rings, False, 0.06, 0.006, 5.0), NEAR_WHITE, "main", 0.02))
    return o


@prop
def WearApron():
    o = []
    bm_pts = [(-0.95, 0.12), (0.95, 0.12), (1.0, -1.7), (-1.0, -1.7)]
    ap = slab("Apron", bm_pts, 0.03, -0.6, 0.012)
    for v in ap.data.vertices:  # curve round the legs a little
        v.co.y += (v.co.x ** 2) * 0.12
    o.append(paint(ap, NEAR_WHITE, "main", 0.02))
    o.append(paint(slab("Pocket", [(-0.6, -0.4), (0.6, -0.4), (0.6, -0.9), (-0.6, -0.9)], 0.025, -0.62, 0.008), (232, 232, 232), "main"))
    o.append(paint(box("PocketSeam", (0.02, 0.03, 0.5), (0, -0.635, -0.65), 0.005, 1), NEAR_WHITE, "tint"))
    o.append(paint(box("Waistband", (2.08, 1.12, 0.14), (0, 0, 0.12), 0.04, 3), NEAR_WHITE, "tint"))
    for sx in (-1, 1):
        o.append(paint(tube("Tie", [(sx * 0.15, 0.58, 0.1), (sx * 0.3, 0.64, -0.25), (sx * 0.24, 0.62, -0.6)], 0.04, 6), NEAR_WHITE, "tint"))
    o.append(paint(sphere("Bow", 0.11, (0, 0.6, 0.1), (1.4, 0.6, 1), 2), NEAR_WHITE, "tint"))
    return o
