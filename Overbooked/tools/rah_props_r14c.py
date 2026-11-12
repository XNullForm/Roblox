"""Round 14c: the next most-seen pieces, remade by hand (same names and footprints).
  Armchair  ~3.8 x 3.2  a rust velvet club chair: rolled scroll arms with piping, button-tufted back, splayed walnut legs, brass toes
  Sofa      ~8.6 x 3.8  the matching three-seater in teal velvet, two cushions a side, a knit throw over one arm
  Wardrobe  ~4.4 x 8.1  a walnut armoire: bracket feet, raised-panel doors, a drawer, stepped cornice, brass hardware
  Bookshelf ~4.4 x 7.0  walnut shelves with real-looking books (banded spines, leaners, a stack), a trailing plant, bookends
Loaded by rah_props.py (exec) last. Front = -Y (Roblox +Z), floor = z 0.
"""

RUST = (186, 92, 62)
RUST_LT = (204, 112, 78)
RUST_DK = (132, 60, 42)
TEAL = (52, 120, 128)
TEAL_LT = (66, 140, 148)
TEAL_DK = (34, 84, 92)
WAL = (128, 80, 50)
WAL_LT = (150, 98, 62)
WAL_DK = (88, 54, 34)
BRASS_C = (214, 172, 92)


def _leg(o, x, y, h, lean=(0.0, 0.0), r0=0.07, r1=0.12):
    """A tapered walnut leg with a brass toe, from the floor up to h, leaning outward at the foot."""
    foot = Vector((x + lean[0], y + lean[1], 0))
    top = Vector((x, y, h))
    d = top - foot
    leg = lathe("Leg", [(0, 0), (r0, 0), (r1, d.length), (0, d.length)], (0, 0, 0), 14, 50)
    _align(leg, d, foot)
    o.append(paint(leg, WAL, var=0.05))
    toe = lathe("Toe", [(0, 0), (r0 * 0.96, 0), (r0 * 1.08, 0.16), (0, 0.16)], (0, 0, 0), 14, 50)
    _align(toe, d, foot)
    o.append(paint(toe, BRASS_C, "chrome", var=0.02))


def _rolled_arm(o, x, y0, y1, z, r, col, pipe_col, outward):
    """A scroll arm: a fat cylinder along Y with a flat scroll face and piping round the front."""
    L = y1 - y0
    o.append(paint(cyl("ArmRoll", r, L, (x, (y0 + y1) / 2, z), 28, 0.04, (math.radians(90), 0, 0)), col, var=0.04))
    # front scroll face: a slightly bigger disc, then a piping ring
    o.append(paint(cyl("Scroll", r * 1.06, 0.1, (x, y0 - 0.02, z), 28, 0.03, (math.radians(90), 0, 0)), col, var=0.03))
    ring = [(x + math.cos(t) * r * 1.07, y0 - 0.08, z + math.sin(t) * r * 1.07) for t in [k / 24 * 2 * math.pi for k in range(25)]]
    o.append(paint(tube("Piping", ring, 0.045, 6), pipe_col, var=0.03))


def _place(ob, loc, rot=(0, 0, 0)):
    """Move a mesh built round the origin to loc, turned by rot about its own centre."""
    from mathutils import Euler
    ob.matrix_world = Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4()
    bake_xform(ob)
    return ob


def _xf(loc, rot, p):
    from mathutils import Euler
    return tuple(Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4() @ Vector(p))


def _cushion(name, size, loc, puffy, col, rot=(0, 0, 0), var=0.04):
    c = box(name, size, (0, 0, 0), min(size) * 0.42, 6, cuts=3)
    puff(c, size[0] / 2, size[1] / 2, puffy)
    _place(c, loc, rot)
    return paint(c, col, var=var)


def _drape(name, path, width, thick, x0):
    """A cloth strip: path is a list of (y, z) points across the fold, the strip runs along X for width."""
    bm = bmesh.new()
    nx = 8
    rows = []
    for (py, pz) in path:
        rows.append([bm.verts.new((x0 - width / 2 + width * i / nx, py, pz)) for i in range(nx + 1)])
    for j in range(len(rows) - 1):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    return shade(ob, 50)


def _button(o, p, col):
    o.append(paint(sphere("Button", 0.065, p, (1, 0.6, 1), 1), col, var=0.0))


@prop
def Armchair():
    random.seed(1411)
    o = []
    H = 0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(o, sx * 1.3, sy * 1.05, H + 0.05, (sx * 0.1, sy * 0.1))
    # the frame: an upholstered base with a welt along the front
    base = box("Base", (3.3, 2.9, 0.7), (0, 0.02, H + 0.35), 0.2, 4, cuts=2)
    o.append(paint(base, RUST, var=0.04))
    o.append(paint(tube("Welt", [(-1.35, -1.43, H + 0.08), (1.35, -1.43, H + 0.08)], 0.05, 6), RUST_DK))
    # arms: a side panel topped by a scroll roll
    for sx in (-1, 1):
        o.append(paint(box("ArmSide", (0.5, 2.8, 1.15), (sx * 1.5, 0.05, H + 1.05), 0.18, 4), RUST, var=0.04))
        _rolled_arm(o, sx * 1.5, -1.36, 1.42, H + 1.62, 0.34, RUST_LT, RUST_DK, sx)
    # the back: a curved, tufted panel with a rolled top edge
    BL, BR = (0, 1.18, H + 1.62), (math.radians(-7), 0, 0)
    back = box("Back", (3.2, 0.62, 1.9), (0, 0, 0), 0.26, 5, cuts=3)
    for v in back.data.vertices:
        v.co.y += 0.12 * (v.co.x / 1.6) ** 2      # wraps round the sitter a little
    back.data.update()
    o.append(paint(_place(back, BL, BR), RUST, var=0.04))
    o.append(paint(tube("BackTop", [_xf(BL, BR, (-1.55 + i * 0.155, 0.12 * ((-1.55 + i * 0.155) / 1.6) ** 2 + 0.05, 0.98))
                                    for i in range(21)], 0.2, 10), RUST_LT, var=0.04))
    # button tufts on the inside face of the back (two staggered rows), above the back cushion
    for row, lz in enumerate((0.45, 0.8)):
        for k in range(3 if row == 0 else 4):
            x = (-0.8 + k * 0.8) if row == 0 else (-1.2 + k * 0.8)
            _button(o, _xf(BL, BR, (x, -0.31 + 0.12 * (x / 1.6) ** 2 - 0.01, lz)), RUST_DK)
    # seat cushion with front piping, and a back cushion
    o.append(_cushion("Seat", (2.5, 2.35, 0.55), (0, -0.18, H + 0.95), 0.32, RUST_LT))
    o.append(paint(tube("SeatPipe", [(-1.18, -1.36, H + 1.1), (1.18, -1.36, H + 1.1)], 0.045, 6), RUST_DK))
    o.append(_cushion("BackCush", (2.35, 0.5, 1.25), (0, 0.66, H + 1.72), 0.35, RUST_LT, (math.radians(-12), 0, 0)))
    # a cream lumbar pillow with a mustard stripe
    LL, LR = (0.15, 0.3, H + 1.5), (math.radians(-18), 0, math.radians(5))
    p = box("Lumbar", (1.3, 0.38, 0.62), (0, 0, 0), 0.18, 5, cuts=2)
    puff(p, 0.65, 0.19, 0.45)
    o.append(paint(_place(p, LL, LR), (244, 232, 210), var=0.03))
    o.append(paint(_place(box("Stripe", (1.24, 0.42, 0.1), (0, 0, 0), 0.04, 2), LL, LR), (226, 170, 64), var=0.03))
    return o


@prop
def Sofa():
    random.seed(1412)
    o = []
    H = 0.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(o, sx * 3.75, sy * 1.15, H + 0.05, (sx * 0.1, sy * 0.1), 0.08, 0.13)
    o.append(paint(box("CenterLeg", (0.22, 0.22, H), (0, 0.6, H / 2), 0.05, 2), WAL_DK))
    o.append(paint(box("Base", (8.0, 3.1, 0.75), (0, 0.02, H + 0.38), 0.22, 4, cuts=2), TEAL, var=0.04))
    o.append(paint(tube("Welt", [(-3.9, -1.53, H + 0.08), (3.9, -1.53, H + 0.08)], 0.05, 6), TEAL_DK))
    for sx in (-1, 1):
        o.append(paint(box("ArmSide", (0.55, 3.0, 1.3), (sx * 3.98, 0.05, H + 1.1), 0.2, 4), TEAL, var=0.04))
        _rolled_arm(o, sx * 3.98, -1.46, 1.52, H + 1.78, 0.38, TEAL_LT, TEAL_DK, sx)
    back = box("Back", (7.9, 0.66, 2.0), (0, 1.28, H + 1.75), 0.28, 5, (math.radians(-6), 0, 0), cuts=4)
    o.append(paint(back, TEAL, var=0.04))
    o.append(paint(tube("BackTop", [(-3.95, 1.45, H + 2.72), (3.95, 1.45, H + 2.72)], 0.22, 10), TEAL_LT, var=0.04))
    # two seat cushions and two back cushions, each a little different
    for i, x in enumerate((-1.84, 1.84)):
        o.append(_cushion("Seat", (3.62, 2.45, 0.6), (x, -0.2, H + 1.03), 0.3 + 0.05 * i, TEAL_LT))
        o.append(paint(tube("SeatPipe", [(x - 1.72, -1.46, H + 1.2), (x + 1.72, -1.46, H + 1.2)], 0.045, 6), TEAL_DK))
        o.append(_cushion("BackCush", (3.55, 0.55, 1.4), (x, 0.74, H + 1.85), 0.36, TEAL_LT,
                          (math.radians(-13 + 3 * i), 0, math.radians(1.5 * (1 - 2 * i)))))
    # throw pillows: mustard and a cream one with a rust stripe
    for (x, rz, col) in ((-3.0, 18, (226, 168, 62)), (2.95, -14, (244, 232, 210))):
        PL, PR = (x, 0.32, H + 1.95), (math.radians(-20), math.radians(rz * 0.4), math.radians(rz))
        p = box("Pillow", (1.35, 0.5, 1.35), (0, 0, 0), 0.22, 5, cuts=2)
        puff(p, 0.67, 0.25, 0.5)
        o.append(paint(_place(p, PL, PR), col, var=0.03))
        if x > 0:
            o.append(paint(_place(box("Stripe", (0.2, 0.56, 1.32), (0, 0, 0), 0.04, 2), PL, PR), RUST, var=0.03))
    # a knit throw folded over the right arm roll: in over the seat, up and over, down the outside
    ax, az, r = 3.98, H + 1.78, 0.43
    path = [(-0.05, H + 1.2), (-0.05, az - 0.15)]
    path = []
    for k in range(13):
        a = math.pi * (1 - k / 12)             # from the inside (x-) over the top to the outside (x+)
        path.append((ax + r * math.cos(a), az + r * math.sin(a)))
    path = [(ax - r - 0.02, H + 1.25)] + path + [(ax + r + 0.02, az - 0.55), (ax + r + 0.06, az - 0.9)]
    thr = _drape("Throw", path, 1.25, 0.07, 0.0)
    # the strip was built in (x along width, y, z); turn it so the fold crosses the arm (path in x/z, width along y)
    for v in thr.data.vertices:
        v.co.x, v.co.y = v.co.y, v.co.x - 0.15
    thr.data.update()
    bmesh_fix = bmesh.new(); bmesh_fix.from_mesh(thr.data)
    bmesh.ops.recalc_face_normals(bmesh_fix, faces=bmesh_fix.faces); bmesh_fix.to_mesh(thr.data); bmesh_fix.free()
    wobble(thr, 0.025, 2.5, 3.0)
    o.append(paint(thr, (236, 222, 196), var=0.05, grad=lambda q, c: c * (0.86 if int((q.y + 5) * 7) % 2 else 1.0)))
    # fringe along the hanging edges
    for side in (path[0], path[-1]):
        for i in range(9):
            y = -0.15 - 0.6 + i * 0.15
            o.append(paint(tube("Fringe", [(side[0], y, side[1]), (side[0] + (0.02 if side is path[-1] else -0.02), y, side[1] - 0.16)], 0.018, 4),
                           (226, 210, 182)))
    return o


@prop
def Wardrobe():
    random.seed(1413)
    o = []
    W, D, T = 4.1, 2.0, 7.9
    # bracket feet and a moulded plinth
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Foot", (0.42, 0.42, 0.34), (sx * (W / 2 - 0.2), sy * (D / 2 - 0.2) - 0.02, 0.17), 0.06, 2), WAL_DK))
    o.append(paint(box("Plinth", (W + 0.1, D + 0.1, 0.32), (0, 0, 0.5), 0.06, 3), WAL))
    o.append(paint(box("PlinthLip", (W + 0.2, D + 0.2, 0.08), (0, 0, 0.68), 0.03, 2), WAL_LT))
    # the case
    o.append(paint(box("Case", (W, D, T - 1.2), (0, 0.04, 0.72 + (T - 1.2) / 2), 0.05, 2), WAL, var=0.04))
    # a drawer across the bottom with two brass bail pulls
    zD = 1.25
    o.append(paint(box("Drawer", (W - 0.4, 0.08, 0.8), (0, -D / 2 - 0.02, zD), 0.04, 2), WAL_LT, var=0.04))
    for sx in (-1, 1):
        o.append(paint(box("PullPlate", (0.42, 0.04, 0.16), (sx * 0.95, -D / 2 - 0.08, zD + 0.05), 0.02, 1), BRASS_C, "chrome"))
        o.append(paint(tube("Bail", [(sx * 0.95 - 0.16, -D / 2 - 0.1, zD + 0.03), (sx * 0.95 - 0.12, -D / 2 - 0.16, zD - 0.1),
                                     (sx * 0.95 + 0.12, -D / 2 - 0.16, zD - 0.1), (sx * 0.95 + 0.16, -D / 2 - 0.1, zD + 0.03)], 0.025, 6),
                       BRASS_C, "chrome"))
    # two doors: frame + a raised, bevelled panel top and bottom
    zb, zt = 1.75, T - 0.62
    dh = zt - zb
    for sx in (-1, 1):
        cx = sx * (W / 4 - 0.02)
        dw = W / 2 - 0.2
        o.append(paint(box("Door", (dw, 0.1, dh), (cx, -D / 2 - 0.03, zb + dh / 2), 0.04, 2), WAL_LT, var=0.04))
        for (pz, ph) in ((zb + dh * 0.28, dh * 0.4), (zb + dh * 0.74, dh * 0.4)):
            o.append(paint(box("PanelBevel", (dw - 0.4, 0.06, ph), (cx, -D / 2 - 0.1, pz), 0.12, 2), WAL, var=0.04))
            o.append(paint(box("Panel", (dw - 0.7, 0.06, ph - 0.3), (cx, -D / 2 - 0.15, pz), 0.04, 2), WAL_LT, var=0.05))
        # knob near the meeting edge
        o.append(paint(sphere("Knob", 0.09, (sx * 0.2, -D / 2 - 0.2, zb + dh * 0.5), (1, 1, 1), 2), BRASS_C, "chrome"))
        o.append(paint(cyl("KnobNeck", 0.04, 0.12, (sx * 0.2, -D / 2 - 0.12, zb + dh * 0.5), 10, 0.0, (math.radians(90), 0, 0)), BRASS_C, "chrome"))
    o.append(paint(box("Astragal", (0.08, 0.06, dh), (0, -D / 2 - 0.1, zb + dh / 2), 0.02, 1), WAL_DK))
    o.append(paint(box("Escutcheon", (0.1, 0.04, 0.22), (0.12, -D / 2 - 0.12, zb + dh * 0.5 + 0.22), 0.02, 1), BRASS_C, "chrome"))
    # stepped cornice
    z = T - 0.48
    for k, (gw, gh) in enumerate(((0.08, 0.12), (0.18, 0.1), (0.3, 0.14), (0.38, 0.08))):
        o.append(paint(box("Cornice", (W + gw, D + gw, gh), (0, 0.04, z + gh / 2), 0.03 if k != 2 else 0.06, 2),
                       WAL_LT if k % 2 else WAL, var=0.04))
        z += gh
    # side panels get a recessed frame too
    for sx in (-1, 1):
        o.append(paint(box("SidePanel", (0.05, D - 0.5, T - 2.6), (sx * (W / 2 + 0.01), 0.04, 0.72 + (T - 1.2) / 2), 0.03, 2), WAL_LT, var=0.04))
    return o


@prop
def Bookshelf():
    random.seed(1414)
    o = []
    W, D, T = 4.3, 1.4, 6.95
    y0 = 0.1
    for sx in (-1, 1):
        o.append(paint(box("Side", (0.16, D, T - 0.2), (sx * (W / 2 - 0.08), y0, (T - 0.2) / 2), 0.03, 2), WAL, var=0.04))
    o.append(paint(box("Back", (W - 0.2, 0.08, T - 0.4), (0, y0 + D / 2 - 0.06, T / 2), 0.0, 1), WAL_DK, var=0.05))
    o.append(paint(box("Kick", (W - 0.3, 0.1, 0.36), (0, y0 - D / 2 + 0.08, 0.18), 0.02, 1), WAL_DK))
    o.append(paint(box("Bottom", (W - 0.3, D - 0.1, 0.1), (0, y0, 0.4), 0.0, 1), WAL))
    # cornice top
    o.append(paint(box("Top", (W, D, 0.12), (0, y0, T - 0.26), 0.03, 2), WAL))
    o.append(paint(box("TopLip", (W + 0.16, D + 0.12, 0.14), (0, y0 - 0.04, T - 0.12), 0.05, 2), WAL_LT))
    shelves = [0.45, 2.05, 3.65, 5.2]
    for z in shelves[1:]:
        o.append(paint(box("Shelf", (W - 0.3, D - 0.12, 0.1), (0, y0 - 0.02, z), 0.02, 1), WAL, var=0.04))
        o.append(paint(box("ShelfLip", (W - 0.3, 0.06, 0.14), (0, y0 - D / 2 + 0.06, z), 0.02, 1), WAL_LT))
    tops = shelves[1:] + [T - 0.32]
    BOOK = [(150, 52, 46), (52, 82, 120), (60, 104, 74), (196, 150, 70), (226, 216, 196), (96, 62, 106), (40, 40, 46),
            (176, 98, 58), (120, 136, 150)]
    xl, xr = -W / 2 + 0.2, W / 2 - 0.2
    yb = y0 + D / 2 - 0.12           # back of the shelf
    for si, z in enumerate(s + 0.05 for s in shelves):
        room = tops[si] - z - 0.12
        x = xl + 0.02
        plan = random.choice(("plant", "stack", "vase", "frame"))
        feature_at = random.uniform(0.25, 0.65)
        did = False
        while x < xr - 0.15:
            frac = (x - xl) / (xr - xl)
            if not did and frac > feature_at:
                did = True
                if plan == "plant":
                    o.append(paint(lathe("Pot", [(0, 0), (0.2, 0), (0.25, 0.36), (0.27, 0.4), (0, 0.4)], (x + 0.3, y0 - 0.1, z), 18), (232, 226, 214)))
                    for k in range(14):
                        a = random.uniform(-1.2, 1.2)
                        ln = random.uniform(0.2, 0.9)
                        p0 = Vector((x + 0.3, y0 - 0.1, z + 0.42))
                        p1 = p0 + Vector((math.sin(a) * 0.3, -0.35, -ln * 0.6 + 0.15))
                        o.append(paint(tube("Vine", [tuple(p0), tuple(p0 + (p1 - p0) * 0.5 + Vector((0, 0, 0.12))), tuple(p1)], 0.012, 4),
                                       (70, 110, 60)))
                        for m in range(3):
                            q = p0 + (p1 - p0) * (0.35 + m * 0.3)
                            lf = sphere("Leaf", 0.08, tuple(q), (1.2, 0.3, 0.9), 1)
                            o.append(paint(lf, (72 + random.randint(-10, 20), 140 + random.randint(-15, 15), 70), var=0.06))
                    x += 0.7
                elif plan == "stack":
                    zz = z
                    for k in range(random.randint(3, 4)):
                        h = random.uniform(0.12, 0.18)
                        w = random.uniform(0.8, 1.0)
                        o.append(paint(box("Flat", (w, 0.75, h), (x + 0.5, yb - 0.45, zz + h / 2), 0.02, 1, (0, 0, random.uniform(-0.1, 0.1))),
                                       random.choice(BOOK), var=0.05))
                        zz += h
                    o.append(paint(sphere("Globe", 0.16, (x + 0.5, yb - 0.45, zz + 0.16), (1, 1, 1), 2), (110, 150, 170)))
                    x += 1.05
                elif plan == "vase":
                    o.append(paint(lathe("Vase", [(0, 0), (0.12, 0), (0.2, 0.2), (0.16, 0.45), (0.08, 0.6), (0.1, 0.66), (0, 0.66)],
                                         (x + 0.25, y0 - 0.1, z), 20), (64, 112, 132), var=0.03))
                    x += 0.55
                else:
                    f = box("Frame", (0.55, 0.06, 0.7), (x + 0.3, yb - 0.2, z + 0.36), 0.02, 1, (math.radians(-12), 0, 0))
                    o.append(paint(f, BRASS_C, "chrome"))
                    o.append(paint(box("Photo", (0.42, 0.03, 0.55), (x + 0.3, yb - 0.24, z + 0.36), 0.0, 1, (math.radians(-12), 0, 0)),
                                   (170, 196, 206), var=0.1))
                    x += 0.65
                continue
            w = random.uniform(0.13, 0.26)
            h = min(random.uniform(0.85, 1.32), room)
            d = random.uniform(0.7, 0.95)
            tilt = 0.0
            if random.random() < 0.08 and x > xl + 0.4:
                tilt = -random.uniform(0.18, 0.32)        # a leaner resting on its neighbour
            col = random.choice(BOOK)
            cx = x + w / 2 + (math.sin(-tilt) * h / 2 if tilt else 0)
            b = box("Book", (w, d, h), (cx, yb - d / 2, z + h / 2 * math.cos(tilt)), 0.025, 1, (0, tilt, 0))
            o.append(paint(b, col, var=0.06))
            if random.random() < 0.55:
                for bz in (0.16, h - 0.2):
                    o.append(paint(box("Band", (w + 0.01, 0.02, 0.05), (cx, yb - d - 0.0, z + bz), 0.0, 1, (0, tilt, 0)),
                                   (214, 180, 96), var=0.02))
            x += w + 0.015 + (math.sin(-tilt) * h if tilt else 0)
            if random.random() < 0.05:
                x += 0.25
        # a bookend at the right of some shelves
        if si % 2 == 0:
            o.append(paint(box("Bookend", (0.08, 0.5, 0.55), (xr - 0.02, y0, z + 0.28), 0.02, 1), BRASS_C, "chrome"))
    return o
