"""Round 15: luggage and staff gear, remade.
Luggage (origin = bottom centre, front = -Y (Roblox +Z); rollers keep their wheels and pull handle on the +Y side):
  CaseSpinner   1.8 x 1.0 x 3.9   hard-shell spinner: ribbed shell, zip seam, 4 double casters, pull handle, tag
  CaseCarryOn   1.5 x 0.9 x 3.3   soft cabin roller: front pockets with zips, piping, 2 inline wheels
  CaseVintage   2.2 x 0.8 x 1.8   carried: vintage hard case, brass corners, two leather straps, stickers
  Weekender     2.3 x 1.0 x 1.7   carried: canvas duffel, leather ends and base, rolled leather handles
  Briefcase     1.7 x 0.4 x 1.6   carried: leather, brass latches, stitched flap
  Handbag       1.2 x 0.5 x 1.6   carried: structured tote, arched handles, clasp
  Backpack      1.5 x 0.8 x 2.3   worn: rounded pack, front pocket, side pockets, lid buckles, bedroll; straps on +Y
  GuitarCase    3.7 x 0.5 x 1.5   carried by its side handle: hard case in a guitar outline, latches
Groups: main = the tinted shell/fabric (painted near white, the game sets Color), trim = rubber, leather and plastic
(their own colours), chrome = metal.
Staff gear (origin = where the hand closes):
  Mop / Broom   the stick runs down -Z from the hand; the head is turned so it lies flat when the stick leans 38 deg
  Wrench        an adjustable wrench, shaft along +Z
  Clipboard     board and paper, the hand at the bottom edge
Groups for gear: main (own colours), tint (the staff colour), chrome.
Loaded by rah_props.py (exec) after r14f.
"""

SHELL = (236, 236, 236)
RUBBER = (34, 34, 38)
PLASTIC = (52, 54, 60)
LEATHER = (132, 82, 48)
LEATHER_DK = (92, 56, 34)
BRASS = (214, 176, 96)
STEEL15 = (200, 204, 212)


def _wheel(o, x, y, z, r=0.13, w=0.08, double=True):
    """A caster: a swivel fork with one or two small wheels."""
    o.append(paint(cyl("Swivel", 0.09, 0.06, (x, y, z + r + 0.05), 16), PLASTIC, "trim"))
    o.append(paint(box("Fork", (0.22, 0.12, 0.16), (x, y, z + r + 0.0), 0.04), PLASTIC, "trim"))
    xs = (x - w * 0.75, x + w * 0.75) if double else (x,)
    for wx in xs:
        o.append(paint(cyl("Wheel", r, w, (wx, y, z + r), 20, 0.025, (0, math.pi / 2, 0)), RUBBER, "trim"))
        o.append(paint(cyl("Hub", r * 0.45, w + 0.01, (wx, y, z + r), 12, 0.01, (0, math.pi / 2, 0)), (150, 152, 160), "trim"))


def _pull(o, x, y, z0, z1, gw):
    """A telescoping pull handle on the back: two rails and a padded grip."""
    for sx in (-1, 1):
        o.append(paint(box("Rail", (0.1, 0.08, z1 - z0), (sx * x, y, (z0 + z1) / 2), 0.02), STEEL15, "chrome"))
        o.append(paint(box("RailCap", (0.16, 0.14, 0.12), (sx * x, y, z0 + 0.04), 0.03), PLASTIC, "trim"))
    o.append(paint(box("Grip", (gw, 0.2, 0.2), (0, y, z1 + 0.06), 0.08, 4), RUBBER, "trim"))
    o.append(paint(box("GripBtn", (0.3, 0.06, 0.08), (0, y - 0.1, z1 + 0.06), 0.02), (90, 92, 100), "trim"))


def _carry(o, x, y, z, length, axis="x"):
    """A short carry handle standing off a face."""
    if axis == "x":
        pts = [(x - length / 2, y, z), (x - length / 2 + 0.06, y, z + 0.16), (x + length / 2 - 0.06, y, z + 0.16), (x + length / 2, y, z)]
    else:
        pts = [(x, y, z - length / 2), (x + 0.16, y, z - length / 2 + 0.06), (x + 0.16, y, z + length / 2 - 0.06), (x, y, z + length / 2)]
    o.append(paint(tube("Carry", bend_path(pts, 0.06, 4), 0.05, 8), RUBBER, "trim"))


def _tag(o, x, y, z, col=(240, 196, 60)):
    o.append(paint(tube("TagLoop", [(x, y, z), (x, y - 0.02, z - 0.18)], 0.015, 6), (60, 60, 64), "trim"))
    o.append(paint(box("Tag", (0.26, 0.04, 0.34), (x, y - 0.03, z - 0.36), 0.04), col, "trim"))
    o.append(paint(box("TagCard", (0.18, 0.05, 0.16), (x, y - 0.04, z - 0.38), 0.01), (250, 250, 246), "trim"))


@prop
def CaseSpinner():
    o = []
    W, D, H, Z0 = 1.76, 1.0, 2.62, 0.3
    zc = Z0 + H / 2
    # two shell halves, front a touch deeper, meeting at the zip seam
    o.append(paint(box("ShellF", (W, D * 0.56, H), (0, -D * 0.22, zc), 0.24, 6, cuts=4), SHELL, var=0.015))
    o.append(paint(box("ShellB", (W, D * 0.44, H), (0, D * 0.28, zc), 0.22, 6, cuts=4), SHELL, var=0.015))
    o.append(paint(box("Seam", (W + 0.03, 0.07, H + 0.03), (0, D * 0.06, zc), 0.2, 4), RUBBER, "trim"))
    # moulded ribs across the front
    for i in range(5):
        z = Z0 + 0.45 + i * 0.43
        o.append(paint(box("Rib", (W - 0.36, 0.06, 0.12), (0, -D / 2 - 0.02, z), 0.05, 3), (226, 226, 226), var=0.01))
    # corner guards and a top handle with a TSA lock beside it
    for sx in (-1, 1):
        for sz in (0, 1):
            z = Z0 + 0.16 if sz == 0 else Z0 + H - 0.16
            o.append(paint(box("Guard", (0.36, D + 0.04, 0.34), (sx * (W / 2 - 0.13), 0, z), 0.12, 4), PLASTIC, "trim"))
    _carry(o, 0, 0.06, Z0 + H + 0.0, 0.8)
    _carry(o, W / 2 + 0.0, 0.06, zc, 0.7, "z")
    o.append(paint(box("Lock", (0.3, 0.12, 0.2), (0.55, -0.12, Z0 + H - 0.02), 0.04), STEEL15, "chrome"))
    o.append(paint(box("LockDial", (0.2, 0.04, 0.08), (0.55, -0.19, Z0 + H - 0.02), 0.01), (60, 60, 64), "trim"))
    # four double casters
    for sx in (-1, 1):
        for sy in (-1, 1):
            _wheel(o, sx * (W / 2 - 0.2), sy * (D / 2 - 0.16), 0.0)
    # the pull handle housing on the back and the rails
    o.append(paint(box("Housing", (1.05, 0.12, H - 0.3), (0, D / 2 + 0.03, zc), 0.05, 3), PLASTIC, "trim"))
    _pull(o, 0.42, D / 2 + 0.08, Z0 + H - 0.05, 3.78, 1.0)
    _tag(o, -0.3, 0.06, Z0 + H + 0.12)
    return o


@prop
def CaseCarryOn():
    o = []
    W, D, H, Z0 = 1.46, 0.86, 2.1, 0.22
    zc = Z0 + H / 2
    b = box("Body", (W, D, H), (0, 0, zc), 0.26, 6, cuts=5)
    wobble(b, 0.012, 2.0, 3.0)
    o.append(paint(b, SHELL, var=0.02))
    # piping round the front and back faces
    for y in (-D / 2 + 0.03, D / 2 - 0.03):
        for sx in (-1, 1):
            o.append(paint(box("Pipe", (0.06, 0.06, H - 0.4), (sx * (W / 2 - 0.02), y, zc), 0.03), RUBBER, "trim"))
        for z in (Z0 + 0.02, Z0 + H - 0.02):
            o.append(paint(box("Pipe", (W - 0.4, 0.06, 0.06), (0, y, z), 0.03), RUBBER, "trim"))
    # two front pockets with zips and pulls
    for i, (h, z) in enumerate(((0.95, Z0 + 0.62), (0.62, Z0 + 1.55))):
        p = box("Pocket", (W - 0.26, 0.14, h), (0, -D / 2 - 0.05, z), 0.07, 4, cuts=2)
        puff(p, (W - 0.26) / 2, 0.07, 0.25)
        o.append(paint(p, (226, 226, 226), var=0.02))
        o.append(paint(box("Zip", (W - 0.34, 0.04, 0.05), (0, -D / 2 - 0.12, z + h / 2 - 0.08), 0.02), RUBBER, "trim"))
        o.append(paint(box("Pull", (0.08, 0.04, 0.18), (W / 2 - 0.3, -D / 2 - 0.14, z + h / 2 - 0.16), 0.02), STEEL15, "chrome"))
    o.append(paint(box("Base", (W + 0.02, D + 0.02, 0.2), (0, 0, Z0 + 0.06), 0.06, 3), PLASTIC, "trim"))
    # two inline wheels at the back, two feet at the front
    for sx in (-1, 1):
        o.append(paint(cyl("Wheel", 0.17, 0.12, (sx * (W / 2 - 0.16), D / 2 - 0.16, 0.17), 22, 0.03, (0, math.pi / 2, 0)), RUBBER, "trim"))
        o.append(paint(box("WheelCup", (0.2, 0.36, 0.3), (sx * (W / 2 - 0.16), D / 2 - 0.12, 0.3), 0.06), PLASTIC, "trim"))
        o.append(paint(box("Foot", (0.22, 0.2, 0.16), (sx * (W / 2 - 0.2), -D / 2 + 0.16, 0.08), 0.05), PLASTIC, "trim"))
    _carry(o, 0, -0.05, Z0 + H - 0.03, 0.7)
    o.append(paint(box("Housing", (0.95, 0.1, H - 0.2), (0, D / 2 + 0.02, zc), 0.04, 3), PLASTIC, "trim"))
    _pull(o, 0.36, D / 2 + 0.06, Z0 + H - 0.05, 3.18, 0.86)
    _tag(o, 0.25, -0.05, Z0 + H + 0.1, (90, 170, 230))
    return o


def _sticker(o, x, z, y, w, h, col, col2, rot=0.0):
    s = box("Sticker", (w, 0.02, h), (0, 0, 0), min(w, h) * 0.3, 3)
    _place(s, (x, y, z), (0, rot, 0))
    o.append(paint(s, col, var=0.02))
    s2 = box("StickerIn", (w * 0.6, 0.02, h * 0.25), (0, 0, 0), 0.02, 2)
    _place(s2, (x, y - 0.012, z), (0, rot, 0))
    o.append(paint(s2, col2, var=0.0))


@prop
def CaseVintage():
    o = []
    L, D, H = 2.2, 0.78, 1.42
    zc = H / 2 + 0.04
    o.append(paint(box("Body", (L, D, H), (0, 0, zc), 0.14, 5, cuts=3), SHELL, var=0.03))
    o.append(paint(box("Lid", (L + 0.03, D + 0.03, 0.08), (0, 0, H * 0.72), 0.03), LEATHER_DK, "trim"))
    # brass corner caps
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.1, H - 0.02):
                o.append(paint(sphere("Corner", 0.12, (sx * (L / 2 - 0.04), sy * (D / 2 - 0.04), z), (1, 1, 0.9), 2), BRASS, "chrome"))
    # two leather straps around the case with buckles
    for x in (-0.6, 0.6):
        o.append(paint(box("Strap", (0.2, D + 0.06, 0.05), (x, 0, H + 0.065), 0.02), LEATHER, "trim"))
        for sy in (-1, 1):
            o.append(paint(box("Strap", (0.2, 0.05, H), (x, sy * (D / 2 + 0.02), zc), 0.02), LEATHER, "trim"))
        o.append(paint(box("Buckle", (0.26, 0.06, 0.2), (x, -D / 2 - 0.05, H * 0.82), 0.02), BRASS, "chrome"))
    # latches and the leather handle on brass loops
    for x in (-0.25, 0.25):
        o.append(paint(box("Latch", (0.16, 0.06, 0.2), (x, -D / 2 - 0.03, H * 0.72), 0.02), BRASS, "chrome"))
    for x in (-0.3, 0.3):
        o.append(paint(box("Loop", (0.08, 0.12, 0.12), (x, 0, H + 0.1), 0.02), BRASS, "chrome"))
    o.append(paint(tube("Handle", bend_path([(-0.3, 0, H + 0.12), (-0.24, 0, H + 0.34), (0.24, 0, H + 0.34), (0.3, 0, H + 0.12)], 0.08, 4), 0.07, 8), LEATHER_DK, "trim"))
    # travel stickers
    _sticker(o, -0.15, 0.55, -D / 2 - 0.035, 0.42, 0.3, (200, 64, 52), (250, 236, 200), 0.12)
    _sticker(o, 0.25, 0.42, -D / 2 - 0.035, 0.3, 0.3, (40, 110, 160), (246, 240, 220), -0.2)
    _sticker(o, -0.85, 0.5, -D / 2 - 0.035, 0.34, 0.24, (232, 182, 60), (60, 70, 90), 0.05)
    _sticker(o, 0.9, 0.62, -D / 2 - 0.035, 0.28, 0.36, (70, 140, 80), (246, 246, 236), 0.18)
    return o


@prop
def Weekender():
    o = []
    L = 2.3
    # a soft barrel: a lathe along X, flattened at the base
    prof = [(0, -L / 2), (0.36, -L / 2), (0.48, -L / 2 + 0.06), (0.52, -L / 2 + 0.2), (0.53, 0), (0.52, L / 2 - 0.2), (0.48, L / 2 - 0.06), (0.36, L / 2), (0, L / 2)]
    b = lathe("Body", [(r, z) for r, z in prof], (0, 0, 0), 40, 50, 0.95)
    b.rotation_euler = (0, math.pi / 2, 0)
    b.location = (0, 0, 0.55)
    bake_xform(b)
    for v in b.data.vertices:
        if v.co.z < 0.18:
            v.co.z = 0.18 + (v.co.z - 0.18) * 0.25
    b.data.update()
    wobble(b, 0.015, 2.2, 2.0)
    o.append(paint(b, SHELL, var=0.03))
    # leather ends, base and trim
    for sx in (-1, 1):
        e = lathe("End", [(0, 0), (0.5, 0), (0.5, 0.05), (0, 0.05)], (0, 0, 0), 32, 50, 0.95)
        o.append(paint(turned(e, (0, math.pi / 2, 0), (sx * (L / 2 - 0.02) - (0.05 if sx > 0 else 0), 0, 0.56)), LEATHER, "trim"))
    o.append(paint(box("Base", (L - 0.25, 0.86, 0.12), (0, 0, 0.14), 0.05, 3), LEATHER, "trim"))
    o.append(paint(box("Zip", (L - 0.5, 0.06, 0.05), (0, 0, 1.09), 0.02), LEATHER_DK, "trim"))
    o.append(paint(box("Pull", (0.08, 0.06, 0.2), (0.7, -0.04, 1.02), 0.02), BRASS, "chrome"))
    # two rolled leather handles, joined by a wrap at the top
    for sy in (-1, 1):
        pts = [(-0.5, sy * 0.3, 0.98), (-0.42, sy * 0.24, 1.4), (-0.1, sy * 0.06, 1.62), (0.1, sy * 0.06, 1.62), (0.42, sy * 0.24, 1.4), (0.5, sy * 0.3, 0.98)]
        o.append(paint(tube("Handle", pts, 0.055, 8), LEATHER, "trim"))
        for x in (-0.5, 0.5):
            o.append(paint(box("Tab", (0.18, 0.06, 0.3), (x, sy * 0.33, 0.95), 0.03), LEATHER_DK, "trim"))
            o.append(paint(cyl("Rivet", 0.04, 0.04, (x, sy * 0.37, 0.9), 10, 0.0, (math.pi / 2, 0, 0)), BRASS, "chrome"))
    o.append(paint(box("Wrap", (0.34, 0.26, 0.16), (0, 0, 1.63), 0.07, 4), LEATHER_DK, "trim"))
    return o


@prop
def Briefcase():
    o = []
    L, D, H = 1.7, 0.38, 1.22
    o.append(paint(box("Body", (L, D, H), (0, 0, H / 2), 0.08, 4, cuts=2), SHELL, var=0.03))
    o.append(paint(box("Flap", (L + 0.02, D + 0.02, 0.36), (0, 0, H - 0.17), 0.06, 4), (226, 226, 226), var=0.02))
    for z in (0.04, H - 0.36):
        o.append(paint(box("Stitch", (L - 0.1, D + 0.03, 0.02), (0, 0, z), 0.005), (200, 200, 200), var=0.0))
    for x in (-0.48, 0.48):
        o.append(paint(box("Latch", (0.2, 0.06, 0.16), (x, -D / 2 - 0.02, H - 0.36), 0.02), BRASS, "chrome"))
        o.append(paint(box("Mount", (0.1, 0.1, 0.1), (x * 0.5, 0, H + 0.04), 0.02), BRASS, "chrome"))
    o.append(paint(tube("Handle", bend_path([(-0.26, 0, H + 0.06), (-0.22, 0, H + 0.3), (0.22, 0, H + 0.3), (0.26, 0, H + 0.06)], 0.08, 4), 0.06, 8), LEATHER_DK, "trim"))
    for sx in (-1, 1):
        o.append(paint(box("Foot", (0.1, 0.1, 0.04), (sx * (L / 2 - 0.15), 0, 0.0), 0.02), BRASS, "chrome"))
    return o


@prop
def Handbag():
    o = []
    # a structured tote, wider at the base
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        top = v.co.z > 0
        v.co.x *= 1.15 if not top else 0.95
        v.co.y *= 0.46 if not top else 0.36
        v.co.z = 0.45 + v.co.z * 0.85
    b = _new("Body", bm)
    m = b.modifiers.new("bv", "BEVEL")
    m.width, m.segments = 0.1, 4
    apply_mods(b)
    shade(b)
    o.append(paint(b, SHELL, var=0.02))
    o.append(paint(box("Band", (1.0, 0.4, 0.1), (0, 0, 0.82), 0.04), (210, 210, 210), var=0.0))
    o.append(paint(box("Clasp", (0.2, 0.06, 0.14), (0, -0.2, 0.78), 0.03), BRASS, "chrome"))
    for sy in (-1, 1):
        pts = [(-0.34, sy * 0.15, 0.86), (-0.31, sy * 0.13, 1.14), (-0.12, sy * 0.1, 1.34), (0.12, sy * 0.1, 1.34), (0.31, sy * 0.13, 1.14), (0.34, sy * 0.15, 0.86)]
        o.append(paint(tube("Handle", pts, 0.035, 8), LEATHER_DK, "trim"))
        for x in (-0.34, 0.34):
            o.append(paint(box("Ring", (0.08, 0.04, 0.08), (x, sy * 0.17, 0.86), 0.02), BRASS, "chrome"))
    return o


@prop
def Backpack():
    o = []
    W, D, H, Z0 = 1.5, 0.72, 1.85, 0.0
    b = box("Body", (W, D, H), (0, 0, Z0 + H / 2), 0.3, 6, cuts=4)
    wobble(b, 0.015, 2.0, 5.0)
    o.append(paint(b, SHELL, var=0.02))
    # front pocket with a zip, side bottle pockets
    p = box("Pocket", (W - 0.35, 0.22, 0.8), (0, -D / 2 - 0.08, Z0 + 0.55), 0.12, 4, cuts=2)
    puff(p, (W - 0.35) / 2, 0.11, 0.3)
    o.append(paint(p, (222, 222, 222), var=0.02))
    o.append(paint(box("Zip", (W - 0.5, 0.04, 0.05), (0, -D / 2 - 0.2, Z0 + 0.9), 0.02), RUBBER, "trim"))
    for sx in (-1, 1):
        s = box("Side", (0.16, D - 0.2, 0.6), (sx * (W / 2 + 0.05), 0, Z0 + 0.42), 0.07, 3)
        o.append(paint(s, (222, 222, 222), var=0.02))
        o.append(paint(cyl("Bottle", 0.13, 0.7, (sx * (W / 2 + 0.08), 0.05, Z0 + 0.62), 16, 0.04), (60, 150, 200), "trim"))
    # the top lid with two buckled straps
    o.append(paint(box("Lid", (W - 0.1, D + 0.08, 0.3), (0, -0.02, Z0 + H - 0.05), 0.12, 4), (226, 226, 226), var=0.02))
    for x in (-0.38, 0.38):
        o.append(paint(box("LidStrap", (0.14, 0.04, 0.7), (x, -D / 2 - 0.06, Z0 + H - 0.35), 0.015), RUBBER, "trim"))
        o.append(paint(box("Clip", (0.2, 0.08, 0.14), (x, -D / 2 - 0.08, Z0 + H - 0.62), 0.03), PLASTIC, "trim"))
    # a bedroll strapped on top
    o.append(paint(cyl("Bedroll", 0.24, W - 0.05, (0, 0.02, Z0 + H + 0.22), 24, 0.08, (0, math.pi / 2, 0)), (60, 120, 90), "trim"))
    for x in (-0.45, 0.45):
        o.append(paint(cyl("RollStrap", 0.255, 0.07, (x, 0.02, Z0 + H + 0.22), 24, 0.01, (0, math.pi / 2, 0)), RUBBER, "trim"))
    # back panel, haul loop and the shoulder straps rising over the top (+Y is the wearer's side)
    o.append(paint(box("BackPad", (W - 0.25, 0.1, H - 0.4), (0, D / 2 + 0.03, Z0 + H / 2 + 0.1), 0.05, 3), PLASTIC, "trim"))
    for sx in (-1, 1):
        pts = [(sx * 0.38, D / 2 + 0.09, Z0 + 0.25), (sx * 0.4, D / 2 + 0.1, Z0 + H - 0.2), (sx * 0.42, D / 2 + 0.2, Z0 + H + 0.05)]
        o.append(paint(tube("Shoulder", pts, 0.07, 8), PLASTIC, "trim"))
    _carry(o, 0, D / 2 + 0.05, Z0 + H + 0.02, 0.36)
    return o


def _outline(pts, depth, z0, name, bevel=0.08):
    """Extrude a closed XZ outline (list of (x, z)) along Y by depth, centred on y = 0, with a bevel."""
    bm = bmesh.new()
    front = [bm.verts.new((x, -depth / 2, z + z0)) for x, z in pts]
    back = [bm.verts.new((x, depth / 2, z + z0)) for x, z in pts]
    bm.faces.new(front[::-1])
    bm.faces.new(back)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    m = ob.modifiers.new("bv", "BEVEL")
    m.width, m.segments = bevel, 4
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(50)
    apply_mods(ob)
    return shade(ob, 50)


@prop
def GuitarCase():
    o = []
    # outline: a lower bout, a waist, an upper bout and a long neck, lying along X
    pts = []
    cx1, r1, cx2, r2 = -1.15, 0.66, -0.15, 0.5
    for i in range(24):
        a = math.pi / 2 + math.pi * i / 23
        pts.append((cx1 + r1 * math.cos(a), r1 * math.sin(a)))
    # bottom edge from the lower bout to the upper bout, to the neck, out to the head and back
    bottom = [(cx1 + 0.3, -r1 * 0.98), (-0.62, -0.5), (cx2, -r2), (cx2 + 0.35, -r2 * 0.9), (0.42, -0.24), (1.6, -0.2), (1.82, -0.26), (2.0, -0.2), (2.0, 0.2), (1.82, 0.26), (1.6, 0.2), (0.42, 0.24), (cx2 + 0.35, r2 * 0.9), (cx2, r2), (-0.62, 0.5), (cx1 + 0.3, r1 * 0.98)]
    pts = pts + bottom
    body = _outline(pts, 0.46, 0.7, "Body", 0.1)
    o.append(paint(body, SHELL, var=0.02))
    # a seam round the middle, latches and the side handle (on the top edge, +Z)
    seam = _outline([(x * 1.012, z * 1.04) for x, z in pts], 0.06, 0.7, "Seam", 0.02)
    o.append(paint(seam, RUBBER, "trim"))
    for x, z in ((-1.5, 0.55), (-0.6, -0.48), (0.9, 0.24), (0.9, -0.24), (-1.15, -0.64)):
        o.append(paint(box("Latch", (0.16, 0.5, 0.1), (x, 0, 0.7 + z), 0.03), STEEL15, "chrome"))
    o.append(paint(tube("Handle", bend_path([(-0.6, 0, 0.7 + 0.52), (-0.55, 0, 0.7 + 0.78), (-0.05, 0, 0.7 + 0.78), (0.0, 0, 0.7 + 0.5)], 0.08, 4), 0.06, 8), RUBBER, "trim"))
    o.append(paint(box("Sticker", (0.4, 0.02, 0.3), (-1.2, -0.24, 0.75), 0.06), (232, 70, 70), "trim"))
    o.append(paint(box("Sticker", (0.3, 0.02, 0.3), (-0.3, -0.24, 0.68), 0.12), (250, 214, 60), "trim"))
    return o


# ------------------------------------------------------------------ staff gear

def _stick(o, z0, z1, r=0.075, col=STEEL15, group="chrome"):
    o.append(paint(cyl("Stick", r, z0 - z1, (0, 0, (z0 + z1) / 2), 16, 0.02), col, group))


@prop
def Mop():
    o = []
    _stick(o, 1.25, -2.95)
    o.append(paint(cyl("TopGrip", 0.1, 0.6, (0, 0, 0.95), 16, 0.04), SHELL, "tint"))
    o.append(paint(cyl("HandGrip", 0.095, 0.5, (0, 0, -0.1), 16, 0.03), RUBBER, "main"))
    o.append(paint(sphere("Cap", 0.11, (0, 0, 1.27), (1, 1, 0.6), 2), SHELL, "tint"))
    # the head, built level and then turned so it lies flat when the stick leans 38 degrees
    head = []
    head.append(paint(box("Socket", (0.95, 0.4, 0.2), (0, 0, 0.0), 0.07, 3), SHELL, "tint"))
    head.append(paint(cyl("Collar", 0.12, 0.3, (0, 0, 0.22), 14, 0.03), SHELL, "tint"))
    rnd = random.Random(15)
    for i in range(51):
        x = -0.42 + 0.84 * (i % 17) / 16
        y = (-0.13, 0.0, 0.13)[i // 17]
        ang = rnd.uniform(-1, 1)
        L = rnd.uniform(0.6, 0.85)
        dx, dy = math.sin(ang) * 0.3 + x * 0.35, (y * 3.2) + rnd.uniform(-0.15, 0.15)
        pts = [(x, y, -0.06), (x + dx * 0.35, y + dy * 0.35, -0.16), (x + dx, y + dy, -0.24), (x + dx * 1.25, y + dy * 1.25 + (L - 0.6), -0.26)]
        head.append(paint(tube("Strand", pts, 0.062, 6), (236, 236, 228), "main", var=0.06))
    for h in head:
        h.matrix_world = Matrix.Translation(Vector((0, 0, -3.02))) @ Matrix.Rotation(math.radians(-38), 4, "X")
        bake_xform(h)
        o.append(h)
    return o


@prop
def Broom():
    o = []
    _stick(o, 1.25, -2.75, 0.07, (176, 124, 76), "main")
    o.append(paint(cyl("TopGrip", 0.085, 0.45, (0, 0, 1.05), 16, 0.04), SHELL, "tint"))
    o.append(paint(sphere("Cap", 0.09, (0, 0, 1.28), (1, 1, 0.6), 2), SHELL, "tint"))
    head = []
    head.append(paint(box("Block", (1.0, 0.3, 0.26), (0, 0, 0), 0.06, 3), SHELL, "tint"))
    head.append(paint(box("Band", (1.04, 0.32, 0.06), (0, 0, -0.1), 0.02), (50, 50, 56), "main"))
    rnd = random.Random(7)
    for i in range(26):
        for j in range(3):
            x = -0.46 + 0.92 * i / 25
            y = -0.08 + 0.08 * j
            sp = 1 + 0.25 * abs(x)
            pts = [(x, y, -0.12), (x * sp + rnd.uniform(-0.03, 0.03), y * 1.6, -0.55 + rnd.uniform(-0.03, 0.03))]
            head.append(paint(tube("Bristle", pts, 0.028, 4, False), (214, 170, 92), "main", var=0.1))
    for h in head:
        h.matrix_world = Matrix.Translation(Vector((0, 0, -2.85))) @ Matrix.Rotation(math.radians(-38), 4, "X")
        bake_xform(h)
        o.append(h)
    return o


@prop
def Wrench():
    o = []
    # handle with a rubber grip around the origin, the head up at +Z
    o.append(paint(box("Shaft", (0.2, 0.08, 1.5), (0, 0, 0.45), 0.035, 3), STEEL15, "chrome"))
    o.append(paint(box("Grip", (0.26, 0.14, 0.62), (0, 0, -0.05), 0.06, 4), (196, 56, 46), "main"))
    o.append(paint(cyl("Hole", 0.07, 0.16, (0, 0, -0.42), 12, 0.01, (math.pi / 2, 0, 0)), (40, 40, 44), "main"))
    o.append(paint(box("Head", (0.5, 0.1, 0.34), (0.08, 0, 1.26), 0.05, 3), STEEL15, "chrome"))
    o.append(paint(box("JawTop", (0.12, 0.1, 0.34), (-0.12, 0, 1.55), 0.03), STEEL15, "chrome"))
    o.append(paint(box("JawLow", (0.12, 0.1, 0.24), (0.26, 0, 1.5), 0.03), STEEL15, "chrome"))
    o.append(paint(cyl("Worm", 0.06, 0.16, (0.08, 0, 1.22), 12, 0.01, (0, math.pi / 2, 0)), (160, 164, 172), "chrome"))
    return o


@prop
def Clipboard():
    o = []
    o.append(paint(box("Board", (0.9, 0.06, 1.25), (0, 0, 0.62), 0.04, 3), (164, 118, 74), "main", var=0.04))
    o.append(paint(box("Paper", (0.76, 0.02, 1.02), (0, -0.035, 0.56), 0.005), (250, 250, 246), "main", var=0.0))
    for i in range(7):
        o.append(paint(box("Line", (0.56 if i % 3 else 0.4, 0.01, 0.025), (-0.05 if i % 3 == 0 else 0, -0.048, 0.92 - i * 0.12), 0.0, 1), (120, 130, 150), "main", var=0.0))
        o.append(paint(box("Tick", (0.06, 0.01, 0.06), (-0.32, -0.048, 0.92 - i * 0.12), 0.0, 1), (60, 150, 80) if i < 4 else (200, 200, 206), "main", var=0.0))
    o.append(paint(box("Clip", (0.42, 0.08, 0.16), (0, -0.05, 1.18), 0.03), STEEL15, "chrome"))
    o.append(paint(cyl("Pen", 0.03, 0.6, (0.32, -0.08, 0.7), 10, 0.01, (0, 0, 0.3)), (40, 70, 160), "main"))
    return o
