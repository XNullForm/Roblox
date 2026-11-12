"""Round 14d: the room upgrades remade so they feel worth buying over the plain starter set.
  BedDeluxe (+Messy)  ~7.3 x 4.9 x 9.4  boutique double: channel-tufted sage headboard on walnut, white duvet, charcoal runner
  BedSuite  (+Messy)  ~7.3 x 4.9 x 9.4  king: navy wingback, diamond tufting, brass nailheads, cream duvet, navy throw
  ToiletDeluxe        ~3.0 x 3.9 x 3.5  skirted one-piece, soft lid, chrome dual flush, a succulent
  ShowerRain          ~5.2 x 8.8 x 5.5  walk-in: subway tile, slate tray, teak mat, square rain head, matte black fittings, glass side
  Vanity              ~3.4 x 5.1 x 2.6  walnut cabinet, marble top, vessel basin, brass tap, round brass mirror
Same use spots as the starter set (Catalog coreKind): mattress top ~2.35, toilet seat ~1.55, shower head (0, 0.5, ~7.9).
Head of the bed / backs at +Y, front = -Y (Roblox +Z), floor z 0. Loaded by rah_props.py (exec) after r14c.
"""

SAGE = (124, 150, 124)
SAGE_LT = (142, 168, 140)
NAVY = (44, 58, 92)
NAVY_LT = (58, 74, 112)
CHAR = (66, 68, 74)
DUVET = (246, 244, 238)
CREAM_D = (240, 230, 208)
BLACK_M = (44, 44, 48)
SUBWAY = (236, 234, 226)
GROUT = (196, 194, 186)
SLATE = (88, 92, 98)
TEAK = (170, 116, 70)
MARBLE = (238, 236, 230)


def _mattress(o, top=2.35):
    o.append(paint(box("Mattress", (6.3, 8.1, 1.0), (0, -0.15, top - 0.5), 0.3, 5, cuts=4), (250, 250, 246), var=0.015))
    o.append(paint(box("BoxSpring", (6.3, 8.1, 0.5), (0, -0.15, top - 1.2), 0.12, 3), (232, 228, 220), var=0.015))


def _clean_bedding(o, duvet, accent, accent2, top=2.35):
    # duvet with drops over both sides and the foot, the sheet folded back over it at the head
    d = box("Duvet", (6.62, 6.4, 0.42), (0, -1.15, top + 0.05), 0.2, 5, cuts=6)
    wobble(d, 0.018, 1.2, 4.0)
    o.append(paint(d, duvet, var=0.02))
    for sx in (-1, 1):
        o.append(paint(box("Drop", (0.14, 6.4, 1.05), (sx * 3.25, -1.15, top - 0.38), 0.07, 3), duvet, var=0.02))
    o.append(paint(box("DropFoot", (6.62, 0.14, 1.05), (0, -4.3, top - 0.38), 0.07, 3), duvet, var=0.02))
    o.append(paint(box("Fold", (6.66, 0.95, 0.5), (0, 2.25, top + 0.1), 0.22, 5, cuts=2), (252, 252, 250), var=0.01))
    # a runner across the foot
    o.append(paint(box("Runner", (6.7, 1.7, 0.5), (0, -3.05, top + 0.12), 0.18, 4, cuts=2), accent, var=0.03))
    for sx in (-1, 1):
        o.append(paint(box("RunnerDrop", (0.16, 1.7, 0.9), (sx * 3.3, -3.05, top - 0.25), 0.07, 3), accent, var=0.03))
    o.append(paint(box("RunnerBand", (6.72, 0.16, 0.52), (0, -2.45, top + 0.12), 0.06, 2), accent2, var=0.02))
    # two sleeping pillows, two shams standing behind them, a bolster in front
    for sx in (-1, 1):
        p = box("Pillow", (2.7, 1.15, 0.6), (0, 0, 0), 0.26, 6, cuts=3)
        puff(p, 1.35, 0.57, 0.35)
        o.append(paint(_place(p, (sx * 1.5, 3.05, top + 0.42), (math.radians(-22), 0, math.radians(sx * 2))), (252, 252, 250), var=0.015))
        s = box("Sham", (2.7, 0.5, 2.0), (0, 0, 0), 0.22, 6, cuts=3)
        puff(s, 1.35, 0.25, 0.45)
        o.append(paint(_place(s, (sx * 1.48, 3.62, top + 0.95), (math.radians(-10), 0, math.radians(-sx * 1.5))), accent2, var=0.03))
    b = cyl("Bolster", 0.32, 2.6, (0, 0, 0), 24, 0.12, (0, math.pi / 2, 0))
    o.append(paint(_place(b, (0, 2.45, top + 0.38)), accent, var=0.03))
    for sx in (-1, 1):
        o.append(paint(cyl("BolsterEnd", 0.2, 0.06, (sx * 1.31, 2.45, top + 0.38), 18, 0.02, (0, math.pi / 2, 0)), accent2))


def _messy_bedding(o, duvet, accent, accent2, top=2.35, seed=1.0):
    random.seed(int(seed * 100))
    sh = box("Sheet", (6.2, 7.6, 0.24), (0.1, -0.1, top + 0.05), 0.1, 3, cuts=8)
    wobble(sh, 0.09, 1.2, seed * 3)
    o.append(paint(sh, (250, 250, 246), var=0.03))
    d = box("Duvet", (5.6, 4.6, 1.0), (0, 0, 0), 0.45, 5, cuts=8)
    wobble(d, 0.26, 0.9, seed * 5)
    o.append(paint(_place(d, (0.7, -2.2, top + 0.42), (0, math.radians(4), math.radians(-10))), duvet, var=0.04))
    heap = sphere("Heap", 1.0, (-1.8, -1.0, top + 0.45), (1.4, 1.1, 0.55), 3)
    wobble(heap, 0.15, 1.3, seed * 7)
    o.append(paint(heap, duvet, var=0.04))
    # the runner slid half off the foot
    path = [(-2.7, top + 0.1), (-3.6, top + 0.08), (-4.15, top + 0.02), (-4.38, top - 0.35), (-4.42, top - 0.9), (-4.36, top - 1.35)]
    rn = _drape("Runner", path, 4.2, 0.12, -0.9)
    wobble(rn, 0.05, 1.6, seed * 2)
    o.append(paint(rn, accent, var=0.04))
    # pillows knocked about, one sham flat
    p = box("Pillow", (2.7, 1.15, 0.6), (0, 0, 0), 0.26, 6, cuts=3)
    puff(p, 1.35, 0.57, 0.35)
    wobble(p, 0.04, 1.4, seed)
    o.append(paint(_place(p, (-1.3, 2.7, top + 0.4), (math.radians(-14), math.radians(8), math.radians(18))), (252, 252, 250), var=0.02))
    p = box("Pillow", (2.7, 1.15, 0.6), (0, 0, 0), 0.26, 6, cuts=3)
    puff(p, 1.35, 0.57, 0.35)
    o.append(paint(_place(p, (1.7, 2.2, top + 0.36), (math.radians(-4), math.radians(-6), math.radians(-28))), (252, 252, 250), var=0.02))
    s = box("Sham", (2.7, 0.5, 2.0), (0, 0, 0), 0.22, 6, cuts=3)
    puff(s, 1.35, 0.25, 0.45)
    o.append(paint(_place(s, (1.4, 3.55, top + 0.95), (math.radians(-12), 0, math.radians(3))), accent2, var=0.03))
    s = box("Sham", (2.7, 0.5, 2.0), (0, 0, 0), 0.22, 6, cuts=3)
    puff(s, 1.35, 0.25, 0.45)
    o.append(paint(_place(s, (-1.0, 0.9, top + 0.42), (math.radians(-84), 0, math.radians(-20))), accent2, var=0.03))


def _deluxe_frame(o):
    # a low walnut platform on brass-tipped legs, with a channel-tufted headboard on a walnut back
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(o, sx * 3.1, sy * 3.9, 0.45, (sx * 0.06, sy * 0.06), 0.08, 0.12)
    o.append(paint(box("Rail", (6.7, 8.5, 0.55), (0, -0.15, 0.7), 0.06, 3, cuts=2), WAL, var=0.04))
    o.append(paint(box("RailLip", (6.8, 8.6, 0.08), (0, -0.15, 0.98), 0.03, 2), WAL_LT))
    o.append(paint(box("HeadBack", (7.2, 0.3, 4.5), (0, 4.35, 2.45), 0.06, 3), WAL, var=0.04))
    o.append(paint(box("HeadCap", (7.3, 0.42, 0.16), (0, 4.33, 4.78), 0.05, 2), WAL_LT))
    n = 7
    pitch = 6.7 / n
    for i in range(n):
        x = -3.35 + pitch * (i + 0.5)
        o.append(paint(cyl("Channel", pitch * 0.5, 2.9, (x, 4.08, 2.75), 18, 0.0), SAGE if i % 2 else SAGE_LT, var=0.03))
        o.append(paint(sphere("ChanTop", pitch * 0.5, (x, 4.08, 4.2), (1, 1, 0.55), 2), SAGE if i % 2 else SAGE_LT, var=0.03))
    o.append(paint(box("ChanBase", (6.75, 0.6, 0.2), (0, 4.08, 1.25), 0.06, 2), WAL_DK))


def _suite_frame(o):
    # an upholstered navy platform and a wingback headboard: diamond tufts and brass nailheads
    for sx in (-1, 1):
        for sy in (-1, 1):
            _leg(o, sx * 3.15, sy * 3.95, 0.42, (sx * 0.05, sy * 0.05), 0.09, 0.12)
    o.append(paint(box("Rail", (6.8, 8.6, 0.7), (0, -0.15, 0.78), 0.18, 4, cuts=2), NAVY, var=0.04))
    o.append(paint(tube("Welt", [(-3.4, -4.46, 0.45), (3.4, -4.46, 0.45)], 0.045, 6), NAVY_LT))
    hb = box("Head", (6.4, 0.62, 3.75), (0, 0, 0), 0.26, 5, cuts=4)
    puff(hb, 3.2, 0.31, 0.12)
    o.append(paint(_place(hb, (0, 4.22, 2.95)), NAVY_LT, var=0.03))
    for sx in (-1, 1):
        w = box("Wing", (0.55, 1.2, 3.9), (0, 0, 0), 0.24, 5, cuts=2)
        o.append(paint(_place(w, (sx * 3.38, 3.85, 3.0), (0, 0, math.radians(sx * 22))), NAVY, var=0.03))
    o.append(paint(tube("HeadTop", [(-3.15, 4.22, 4.88), (3.15, 4.22, 4.88)], 0.26, 10), NAVY, var=0.03))
    # diamond tufting
    yf = 4.22 - 0.31 - 0.02
    for r, z in enumerate((1.75, 2.35, 2.95, 3.55, 4.15)):
        xs = [-2.4 + k * 0.8 for k in range(7)] if r % 2 == 0 else [-2.8 + k * 0.8 for k in range(8)]
        for x in xs:
            _button(o, (x, yf, z), NAVY)
            # a crease toward each neighbour above makes the diamond read
            if r < 4:
                for dx in (-0.4, 0.4):
                    o.append(paint(tube("Crease", [(x, yf + 0.005, z), (x + dx, yf + 0.005, z + 0.6)], 0.018, 4), (36, 48, 78)))
    # brass nailheads round the face
    pts = []
    for k in range(25):
        pts.append((-3.05 + k * 6.1 / 24, yf - 0.02, 4.72))
    for k in range(11):
        z = 1.3 + k * 3.3 / 11
        pts.append((-3.12, yf - 0.02, z))
        pts.append((3.12, yf - 0.02, z))
    for p in pts:
        o.append(paint(sphere("Nail", 0.045, p, (1, 0.6, 1), 1), BRASS_C, "chrome", var=0.0))


@prop
def BedDeluxe():
    o = []
    _deluxe_frame(o)
    _mattress(o)
    _clean_bedding(o, DUVET, CHAR, SAGE_LT)
    return o


@prop
def BedDeluxeMessy():
    o = []
    _deluxe_frame(o)
    _mattress(o)
    _messy_bedding(o, DUVET, CHAR, SAGE_LT, seed=1.3)
    return o


@prop
def BedSuite():
    o = []
    _suite_frame(o)
    _mattress(o)
    _clean_bedding(o, CREAM_D, NAVY, (226, 186, 100))
    return o


@prop
def BedSuiteMessy():
    o = []
    _suite_frame(o)
    _mattress(o)
    _messy_bedding(o, CREAM_D, NAVY, (226, 186, 100), seed=2.1)
    return o


@prop
def ToiletDeluxe():
    """One-piece skirted toilet; back against +Y, seat top ~1.55."""
    o = []
    WHITE_C = (250, 250, 248)
    base = lathe("Skirt", [(0, 0), (0.6, 0), (0.64, 0.05), (0.64, 0.9), (0.7, 1.22), (0.8, 1.36), (0.79, 1.44), (0.66, 1.43),
                           (0.42, 1.12), (0, 1.06)], (0, -0.3, 0), 40, 40, sy=1.32)
    o.append(paint(base, WHITE_C, var=0.008))
    o.append(paint(box("Body", (1.34, 1.3, 1.38), (0, 0.55, 0.7), 0.4, 6), WHITE_C, var=0.008))
    seat = lathe("Seat", [(0.62, 1.45), (0.84, 1.45), (0.87, 1.49), (0.84, 1.55), (0.64, 1.55), (0.6, 1.5), (0.62, 1.45)],
                 (0, -0.3, 0), 40, 40, sy=1.32)
    o.append(paint(seat, WHITE_C, var=0.008))
    lid = lathe("Lid", [(0, 0), (0.84, 0), (0.88, 0.05), (0.85, 0.11), (0.7, 0.14), (0, 0.15)], (0, 0, 0), 40, 40, sy=1.32)
    o.append(paint(_place(lid, (0, 0.92, 2.6), (math.radians(-82), 0, 0)), WHITE_C, var=0.008))
    o.append(paint(box("Hinge", (0.9, 0.2, 0.12), (0, 0.86, 1.56), 0.05, 3), (200, 202, 206), "chrome"))
    # a low, soft tank and its lid, chrome dual flush on top
    o.append(paint(box("Tank", (1.85, 0.82, 1.15), (0, 1.38, 2.05), 0.32, 6), WHITE_C, var=0.008))
    o.append(paint(box("TankLid", (1.92, 0.9, 0.14), (0, 1.38, 2.66), 0.06, 3), WHITE_C, var=0.008))
    o.append(paint(cyl("Flush", 0.16, 0.05, (0, 1.38, 2.75), 24, 0.01), (210, 212, 216), "chrome"))
    o.append(paint(box("FlushSplit", (0.02, 0.3, 0.02), (0, 1.38, 2.78), 0.0, 1), (150, 152, 156)))
    # a succulent in a concrete pot on the lid
    o.append(paint(lathe("Pot", [(0, 0), (0.18, 0), (0.21, 0.24), (0, 0.24)], (0.6, 1.38, 2.73), 18), (176, 174, 168)))
    for k in range(9):
        a = k * 2.4
        r = 0.05 + 0.012 * k
        o.append(paint(sphere("Leaf", 0.07, (0.6 + r * math.cos(a), 1.38 + r * math.sin(a), 3.0 + 0.02 * (9 - k)), (1.4, 0.7, 0.55), 1),
                       (108 + 4 * k, 160, 120), var=0.05))
    # chrome roll holder on the wall
    o.append(paint(box("RollPlate", (0.1, 0.08, 0.36), (1.45, 1.72, 1.95), 0.03, 2), (210, 212, 216), "chrome"))
    o.append(paint(tube("RollArm", [(1.45, 1.7, 1.95), (1.45, 1.35, 1.95), (1.45, 1.35, 2.05)], 0.035, 6), (210, 212, 216), "chrome"))
    o.append(paint(cyl("Roll", 0.28, 0.4, (1.45, 1.3, 1.95), 20, 0.04, (0, math.pi / 2, 0)), (252, 252, 250), var=0.02))
    return o


@prop
def ShowerRain():
    """Walk-in rain shower. Back wall +Y, side wall +X, glass on the left (-X), open at the front."""
    random.seed(1415)
    o = []
    o.append(paint(box("Tray", (5.2, 5.2, 0.24), (0, 0, 0.12), 0.05, 2), SLATE, var=0.03))
    o.append(paint(box("Drain", (3.4, 0.22, 0.03), (0, 1.9, 0.25), 0.01, 1), BLACK_M, "chrome"))
    # teak slatted mat
    for k in range(7):
        o.append(paint(box("Slat", (2.4, 0.24, 0.08), (-0.2, -1.0 + k * 0.32, 0.33), 0.03, 2), TEAK, var=0.06))
    for sx in (-1, 1):
        o.append(paint(box("Runner", (0.18, 2.2, 0.07), (-0.2 + sx * 1.0, -0.05, 0.27), 0.02, 1), (130, 88, 54)))
    # tiled walls: white subway with offset joints and a sage band
    H = 8.2
    o.append(paint(box("WallB", (5.2, 0.2, H), (0, 2.5, 0.24 + H / 2), 0.02, 1), SUBWAY, var=0.015))
    o.append(paint(box("WallR", (0.2, 4.8, H), (2.5, -0.1, 0.24 + H / 2), 0.02, 1), SUBWAY, var=0.015))
    rows = int(H / 0.5)
    for r in range(rows + 1):
        z = 0.24 + r * 0.5
        o.append(paint(box("GroutH", (5.0, 0.03, 0.035), (0, 2.39, z), 0.0, 1), GROUT))
        o.append(paint(box("GroutH", (0.03, 4.8, 0.035), (2.39, -0.1, z), 0.0, 1), GROUT))
        if r == rows:
            break
        off = 0.5 if r % 2 else 0.0
        x = -2.5 + off
        while x < 2.45:
            if x > -2.45:
                o.append(paint(box("GroutV", (0.035, 0.03, 0.5), (x, 2.39, z + 0.25), 0.0, 1), GROUT))
            x += 1.0
        y = 2.4 - off
        while y > -2.5:
            if y < 2.35:
                o.append(paint(box("GroutV", (0.03, 0.035, 0.5), (2.39, y, z + 0.25), 0.0, 1), GROUT))
            y -= 1.0
    o.append(paint(box("Band", (5.0, 0.06, 0.5), (0, 2.38, 4.49), 0.01, 1), SAGE_LT, var=0.03))
    o.append(paint(box("Band", (0.06, 4.8, 0.5), (2.38, -0.1, 4.49), 0.01, 1), SAGE_LT, var=0.03))
    # a niche shelf with bottles
    o.append(paint(box("Niche", (1.6, 0.5, 0.08), (-1.3, 2.17, 3.6), 0.02, 1), MARBLE))
    for k, (c, h) in enumerate(((CHAR, 0.62), ((216, 206, 186), 0.54), ((124, 150, 124), 0.46))):
        o.append(paint(lathe("Bottle", [(0, 0), (0.13, 0), (0.14, h * 0.8), (0.07, h * 0.9), (0.07, h), (0, h)], (-1.8 + k * 0.42, 2.15, 3.64), 16), c))
    # square rain head on a ceiling arm, matte black
    o.append(paint(tube("Arm", [(0, 2.4, 8.25), (0, 0.5, 8.25), (0, 0.5, 8.05)], 0.06, 8), BLACK_M, "chrome"))
    o.append(paint(box("RainHead", (1.5, 1.5, 0.08), (0, 0.5, 8.0), 0.03, 2), BLACK_M, "chrome"))
    for i in range(6):
        for j in range(6):
            o.append(paint(box("Nozzle", (0.05, 0.05, 0.02), (-0.55 + i * 0.22, 0.5 - 0.55 + j * 0.22, 7.95), 0.0, 1), (24, 24, 26)))
    # hand shower on a slide rail, mixer plate and lever
    o.append(paint(tube("RailBar", [(1.5, 2.35, 2.6), (1.5, 2.35, 6.0)], 0.04, 6), BLACK_M, "chrome"))
    o.append(paint(box("Holder", (0.18, 0.2, 0.22), (1.5, 2.24, 5.0), 0.04, 2), BLACK_M, "chrome"))
    o.append(paint(tube("Wand", [(1.5, 2.12, 4.7), (1.5, 2.05, 5.5)], 0.06, 8), BLACK_M, "chrome"))
    o.append(paint(cyl("WandHead", 0.15, 0.08, (1.5, 2.0, 5.58), 18, 0.02), BLACK_M, "chrome"))
    o.append(paint(tube("Hose", [(1.5, 2.12, 4.7), (1.42, 2.15, 3.6), (1.2, 2.2, 3.1), (0.95, 2.3, 3.4)], 0.03, 6), BLACK_M, "chrome"))
    o.append(paint(cyl("MixPlate", 0.32, 0.04, (0.6, 2.38, 3.4), 24, 0.01, (math.pi / 2, 0, 0)), BLACK_M, "chrome"))
    o.append(paint(box("Lever", (0.08, 0.5, 0.08), (0.6, 2.15, 3.4), 0.03, 2), BLACK_M, "chrome"))
    # the glass side on the left in a slim black channel
    o.append(paint(box("Glass", (0.06, 4.6, 7.3), (-2.52, 0.1, 0.24 + 3.68), 0.0, 1), (214, 232, 236), "glass"))
    o.append(paint(box("Channel", (0.16, 4.62, 0.12), (-2.52, 0.1, 0.3), 0.02, 1), BLACK_M, "chrome"))
    o.append(paint(box("Profile", (0.14, 0.14, 7.3), (-2.52, 2.42, 0.24 + 3.68), 0.02, 1), BLACK_M, "chrome"))
    o.append(paint(tube("Brace", [(-2.52, -2.1, 7.4), (-2.52, -2.1, 8.0), (2.4, -2.1, 8.0)], 0.03, 6), BLACK_M, "chrome"))
    # a towel on a hook outside the glass
    o.append(paint(box("Hook", (0.06, 0.06, 0.2), (-2.6, -1.6, 5.2), 0.02, 1), BLACK_M, "chrome"))
    tw = box("Towel", (0.12, 0.9, 1.6), (0, 0, 0), 0.05, 2, cuts=3)
    wobble(tw, 0.03, 2.0, 4.0)
    o.append(paint(_place(tw, (-2.68, -1.6, 4.35)), (240, 238, 232), var=0.03))
    return o


@prop
def Vanity():
    """Walnut vanity, marble top, vessel basin, brass tap and a round brass mirror; back against +Y."""
    o = []
    o.append(paint(box("Plinth", (3.0, 1.7, 0.3), (0, 0.3, 0.15), 0.03, 1), WAL_DK))
    o.append(paint(box("Cab", (3.2, 1.9, 2.25), (0, 0.25, 0.3 + 1.125), 0.05, 2), WAL, var=0.04))
    for k, z in enumerate((0.95, 1.95)):
        o.append(paint(box("Drawer", (2.9, 0.08, 0.85), (0, -0.74, z), 0.04, 2), WAL_LT, var=0.04))
        o.append(paint(box("Pull", (0.9, 0.06, 0.06), (0, -0.82, z + 0.25), 0.02, 2), BRASS_C, "chrome"))
        for sx in (-1, 1):
            o.append(paint(box("PullPost", (0.05, 0.08, 0.05), (sx * 0.42, -0.79, z + 0.25), 0.0, 1), BRASS_C, "chrome"))
    def vein(p, c):
        n = noise.noise(Vector((p.x * 1.6, p.y * 1.6 + p.x * 0.8, p.z * 2)))
        return c * (0.84 if abs(n) < 0.045 else 1.0)
    o.append(paint(box("Top", (3.4, 2.05, 0.16), (0, 0.22, 2.63), 0.03, 2, cuts=6), MARBLE, var=0.01, grad=vein))
    o.append(paint(box("Splash", (3.4, 0.1, 0.5), (0, 1.2, 2.96), 0.02, 1, cuts=4), MARBLE, var=0.01, grad=vein))
    o.append(paint(lathe("Basin", [(0, 0), (0.3, 0), (0.48, 0.12), (0.6, 0.36), (0.62, 0.44), (0.58, 0.45), (0.55, 0.36), (0.42, 0.14), (0, 0.1)],
                         (-0.25, 0.05, 2.71), 36, 50, sy=0.85), (252, 252, 250), var=0.01))
    o.append(paint(cyl("Drain", 0.08, 0.02, (-0.25, 0.05, 2.83), 14, 0.0), BRASS_C, "chrome"))
    # a tall gooseneck tap behind the basin
    o.append(paint(cyl("TapBase", 0.1, 0.12, (-0.25, 0.85, 2.77), 16, 0.02), BRASS_C, "chrome"))
    o.append(paint(tube("Tap", bend_path([(-0.25, 0.85, 2.8), (-0.25, 0.85, 3.85), (-0.25, 0.3, 3.85), (-0.25, 0.3, 3.65)], 0.2), 0.05, 8),
                   BRASS_C, "chrome"))
    o.append(paint(box("TapLever", (0.3, 0.06, 0.06), (-0.05, 0.85, 3.2), 0.02, 1), BRASS_C, "chrome"))
    # soap pump and a little plant
    o.append(paint(lathe("Soap", [(0, 0), (0.15, 0), (0.16, 0.38), (0.06, 0.44), (0, 0.44)], (0.95, 0.6, 2.71), 16), (196, 214, 200)))
    o.append(paint(tube("Pump", [(0.95, 0.6, 3.15), (0.95, 0.6, 3.27), (0.95, 0.45, 3.27)], 0.025, 4), BRASS_C, "chrome"))
    o.append(paint(lathe("PlantPot", [(0, 0), (0.17, 0), (0.2, 0.3), (0, 0.3)], (1.35, 0.85, 2.71), 16), (232, 228, 218)))
    for k in range(7):
        a = k * 0.9
        o.append(paint(tube("Sprig", [(1.35, 0.85, 2.98), (1.35 + 0.25 * math.cos(a), 0.85 + 0.2 * math.sin(a), 3.45 + 0.05 * k)], 0.02, 4),
                       (86, 136, 82)))
        o.append(paint(sphere("Leaf", 0.08, (1.35 + 0.25 * math.cos(a), 0.85 + 0.2 * math.sin(a), 3.47 + 0.05 * k), (1.3, 0.5, 0.8), 1),
                       (96, 150, 88), var=0.05))
    # the round mirror with a brass rim (mirror face in the main group so it reads as a mirror, not see-through glass)
    o.append(paint(_place(cyl("Mirror", 0.93, 0.04, (0, 0, 0), 48, 0.0, (math.pi / 2, 0, 0)), (0, 1.22, 4.12)), (196, 210, 216), var=0.0,
                   grad=lambda p, c: c * (0.9 + 0.12 * (p.z - 3.2) / 1.9)))
    ring = [(math.cos(t) * 0.97, 1.18, 4.12 + math.sin(t) * 0.97) for t in [k / 48 * 2 * math.pi for k in range(49)]]
    o.append(paint(tube("Rim", ring, 0.06, 8), BRASS_C, "chrome"))
    # towel ring on the side with a hand towel
    o.append(paint(box("TRPlate", (0.06, 0.2, 0.2), (1.72, 0.25, 2.2), 0.02, 1), BRASS_C, "chrome"))
    tr = [(1.82, 0.25 + math.cos(t) * 0.32, 1.9 + math.sin(t) * 0.32) for t in [k / 24 * 2 * math.pi for k in range(25)]]
    o.append(paint(tube("TowelRing", tr, 0.03, 6), BRASS_C, "chrome"))
    tw = box("HandTowel", (0.14, 0.6, 1.1), (0, 0, 0), 0.05, 2, cuts=3)
    wobble(tw, 0.025, 2.0, 2.0)
    o.append(paint(_place(tw, (1.84, 0.25, 1.35)), (232, 226, 210), var=0.03))
    return o
