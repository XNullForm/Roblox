"""Round 10c props: more for build mode. Loaded by rah_props.py (exec) after the kitchen file.
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
  Bathtub       : a white clawfoot tub on brass feet, a brass mixer and a folded towel
  Vanity        : a walnut dressing table with an oval mirror, a stool, a jewellery box and perfume
  Chesterfield  : a deep-buttoned oxblood leather sofa with rolled arms
  ChessTable    : a pedestal games table with an inlaid board, pieces mid-game, two chairs
  Dartboard     : a dartboard on a walnut stand with a chalk scoreboard
  Gramophone    : a brass horn gramophone on a little cabinet
  Bonsai        : a twisted juniper in a glazed tray on a low stand
  Easel         : a painter's easel holding a landscape, a palette on the ledge
  Telescope     : a brass telescope on a wooden tripod
  UmbrellaStand : a brass-banded stand full of umbrellas (handy when it rains)
  Candelabra    : a tall five-arm brass candelabra, lit
  Column        : a classical column, marble with a brass collar
"""

def turned(ob, rot, loc, scale=(1, 1, 1)):
    """Pose a part built at the origin: scale, then turn, then move (and bake it in)."""
    ob.scale = scale
    ob.rotation_euler = rot
    ob.location = loc
    bake_xform(ob)
    return ob


PORCELAIN = (244, 244, 240)
BRASS_C = (214, 176, 96)
WALNUT_C = (86, 56, 38)
WALNUT_C2 = (110, 74, 48)
OXBLOOD = (112, 34, 36)
MARBLE_C = (236, 232, 224)
IVORY = (238, 228, 206)
EBONY = (34, 30, 30)
GREEN_FELT = (38, 92, 64)


@prop
def Bathtub():
    o = []
    # the tub: a lathed bowl stretched long (sy scales the depth axis)
    prof = [(0, 0.55), (1.05, 0.55), (1.32, 0.9), (1.42, 1.6), (1.46, 2.25), (1.36, 2.3), (1.3, 1.65), (1.18, 1.0), (0, 0.95)]
    o.append(paint(lathe("Tub", prof, (0, 0, 0), 48, sy=0.52), PORCELAIN, var=0.01))
    o.append(paint(lathe("Rim", [(1.36, 2.24), (1.5, 2.24), (1.5, 2.34), (1.36, 2.34)], (0, 0, 0), 48, sy=0.52), PORCELAIN, var=0.01))
    o.append(paint(lathe("Water", [(0, 1.85), (1.3, 1.85), (1.3, 1.88), (0, 1.88)], (0, 0, 0), 48, sy=0.52), (150, 200, 226), "glass"))
    # four claw feet
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(sphere("Claw", 0.2, (sx * 0.95, sy * 0.38, 0.2), (1, 1, 1.3)), BRASS_C, "chrome"))
            o.append(paint(cyl("Leg", 0.1, 0.4, (sx * 0.9, sy * 0.36, 0.5), 12), BRASS_C, "chrome"))
    # the mixer on the back end
    o.append(paint(tube("Spout", [(1.2, 0, 2.3), (1.2, 0, 2.85), (0.95, 0, 3.0), (0.8, 0, 2.8)], 0.07), BRASS_C, "chrome"))
    for sy in (-1, 1):
        o.append(paint(cyl("Tap", 0.1, 0.12, (1.2, sy * 0.22, 2.45), 16), BRASS_C, "chrome"))
        o.append(paint(box("TapLever", (0.06, 0.24, 0.05), (1.2, sy * 0.3, 2.53), 0.02), BRASS_C, "chrome"))
    # a folded towel over the rim
    o.append(paint(box("Towel", (0.6, 0.22, 0.5), (-0.4, 0.74, 2.15), 0.06), (246, 238, 222), var=0.02))
    return o


@prop
def Vanity():
    o = []
    o.append(paint(box("Top", (3.4, 1.5, 0.14), (0, 0.2, 2.6), 0.04), WALNUT_C2, var=0.03))
    o.append(paint(box("Apron", (3.2, 1.3, 0.4), (0, 0.2, 2.33), 0.03), WALNUT_C, var=0.03))
    for sx in (-1, 1):
        o.append(paint(box("Drawer", (1.0, 0.06, 0.28), (sx * 0.95, -0.47, 2.33), 0.02), WALNUT_C2))
        o.append(paint(sphere("Pull", 0.05, (sx * 0.95, -0.53, 2.33)), BRASS_C, "chrome"))
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.07, 0), (0.1, 1.6), (0.12, 2.0), (0.12, 2.15), (0, 2.15)], (sx * 1.5, 0.2 + sy * 0.55, 0), 16), WALNUT_C))
    # the oval mirror on a stand
    o.append(paint(turned(lathe("Frame", [(0, 0), (1.0, 0), (1.0, 0.12), (0, 0.12)], (0, 0, 0), 48), (math.radians(90), 0, 0), (0, 0.82, 4.1), (0.75, 1.0, 1.0)), BRASS_C, "chrome"))
    o.append(paint(turned(lathe("Glass", [(0, 0), (0.9, 0), (0.9, 0.04), (0, 0.04)], (0, 0, 0), 48), (math.radians(90), 0, 0), (0, 0.69, 4.1), (0.75, 1.0, 1.0)), (200, 214, 222), "glass"))
    o.append(paint(box("MirrorPost", (0.12, 0.12, 0.7), (0, 0.8, 2.98), 0.03), BRASS_C, "chrome"))
    # things on top
    o.append(paint(box("JewelBox", (0.5, 0.35, 0.25), (-1.1, 0.0, 2.8), 0.04), (150, 30, 50)))
    o.append(paint(box("JewelLid", (0.52, 0.37, 0.06), (-1.1, 0.0, 2.95), 0.03), BRASS_C, "chrome"))
    for i, c in enumerate(((220, 170, 200), (170, 210, 230))):
        o.append(paint(lathe("Perfume", [(0, 0), (0.14, 0), (0.15, 0.26), (0.05, 0.3), (0.05, 0.38), (0, 0.38)], (0.9 + i * 0.35, 0.1, 2.67), 20), c, "glass"))
        o.append(paint(sphere("Atomiser", 0.06, (0.9 + i * 0.35, 0.1, 3.08)), BRASS_C, "chrome"))
    # the stool tucked in front
    o.append(paint(lathe("Stool", [(0, 1.3), (0.6, 1.3), (0.62, 1.45), (0.5, 1.6), (0, 1.62)], (0, -1.0, 0), 32), (226, 196, 200), var=0.02))
    for a in range(4):
        ang = math.radians(45 + a * 90)
        o.append(paint(tube("StoolLeg", [(0.42 * math.cos(ang), -1.0 + 0.42 * math.sin(ang), 1.3), (0.5 * math.cos(ang), -1.0 + 0.5 * math.sin(ang), 0)], 0.05), BRASS_C, "chrome"))
    return o


@prop
def Chesterfield():
    o = []
    W = 6.2
    o.append(paint(box("Base", (W, 2.6, 0.9), (0, 0, 0.95), 0.12), OXBLOOD, var=0.02))
    for i in range(3):
        o.append(paint(box("Seat", (W / 3 - 0.1, 2.0, 0.45), (-W / 3 + i * W / 3, -0.2, 1.6), 0.18), OXBLOOD, var=0.03))
    o.append(paint(box("Back", (W, 0.7, 1.6), (0, 1.0, 2.2), 0.25), OXBLOOD, var=0.02))
    # rolled arms
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.75, 2.6, 1.3), (sx * (W / 2 + 0.05), 0, 1.65), 0.2), OXBLOOD, var=0.02))
        o.append(paint(cyl("Roll", 0.52, 2.7, (sx * (W / 2 + 0.05), 0, 2.3), 24, 0.08, rot=(math.radians(90), 0, 0)), OXBLOOD, var=0.02))
    # the buttons that make it a chesterfield
    for row in range(2):
        for i in range(9):
            x = -W / 2 + 0.6 + i * (W - 1.2) / 8 + (0.3 if row == 1 else 0)
            if abs(x) < W / 2 - 0.4:
                o.append(paint(sphere("Button", 0.06, (x, 0.64, 2.0 + row * 0.6)), (70, 18, 20)))
    # turned feet
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(lathe("Foot", [(0, 0), (0.14, 0), (0.18, 0.3), (0.12, 0.5), (0, 0.5)], (sx * (W / 2 - 0.2), sy * 1.05, 0), 16), WALNUT_C))
    return o


@prop
def ChessTable():
    o = []
    o.append(paint(box("Top", (2.6, 2.6, 0.16), (0, 0, 2.8), 0.05), WALNUT_C2, var=0.03))
    # the board: an 8x8 of light and dark squares
    s = 0.25
    for i in range(8):
        for j in range(8):
            c = IVORY if (i + j) % 2 == 0 else EBONY
            o.append(paint(box("Square", (s, s, 0.02), (-0.875 + i * s, -0.875 + j * s, 2.89), 0.0, segs=1), c))
    o.append(paint(lathe("Pedestal", [(0, 0), (0.9, 0), (0.9, 0.15), (0.3, 0.3), (0.22, 1.5), (0.3, 2.5), (0.5, 2.72), (0, 2.72)], (0, 0, 0), 32), WALNUT_C))
    # some pieces mid-game
    pieces = [(-0.875, -0.875, IVORY, 0.36), (-0.375, -0.625, IVORY, 0.22), (0.125, -0.375, IVORY, 0.5), (0.625, -0.875, IVORY, 0.3),
              (-0.625, 0.875, EBONY, 0.36), (0.375, 0.625, EBONY, 0.22), (-0.125, 0.375, EBONY, 0.5), (0.875, 0.625, EBONY, 0.3),
              (0.375, -0.125, EBONY, 0.22), (-0.375, 0.125, IVORY, 0.22)]
    for x, y, c, h in pieces:
        o.append(paint(lathe("Piece", [(0, 0), (0.09, 0), (0.09, 0.04), (0.05, 0.08), (0.04, h - 0.08), (0.07, h - 0.04), (0, h)], (x, y, 2.9), 16), c))
    # two chairs
    for sy in (-1, 1):
        y = sy * 2.2
        o.append(paint(box("ChairSeat", (1.5, 1.4, 0.18), (0, y, 1.75), 0.06), WALNUT_C2))
        o.append(paint(box("ChairPad", (1.3, 1.2, 0.12), (0, y, 1.88), 0.05), GREEN_FELT))
        o.append(paint(box("ChairBack", (1.5, 0.14, 1.5), (0, y + sy * 0.65, 2.6), 0.05), WALNUT_C2))
        for sx in (-1, 1):
            for sz in (-1, 1):
                o.append(paint(box("ChairLeg", (0.12, 0.12, 1.7), (sx * 0.62, y + sz * 0.56, 0.85), 0.03), WALNUT_C))
    return o


@prop
def Dartboard():
    o = []
    o.append(paint(box("Board", (3.0, 0.3, 3.6), (0, 0.3, 5.0), 0.06), WALNUT_C2, var=0.03))
    for sx in (-1, 1):
        o.append(paint(box("Leg", (0.3, 0.3, 6.6), (sx * 1.35, 0.4, 3.3), 0.05), WALNUT_C))
        o.append(paint(box("Foot", (0.4, 1.8, 0.2), (sx * 1.35, 0.2, 0.1), 0.05), WALNUT_C))
    # the dartboard: rings, then the bull
    cy = 0.12
    rings = [(1.05, EBONY), (0.95, (196, 44, 48)), (0.86, IVORY), (0.62, (36, 120, 70)), (0.55, EBONY), (0.18, (36, 120, 70)), (0.08, (196, 44, 48))]
    for i, (r, c) in enumerate(rings):
        d = cyl("Ring", r, 0.1 + i * 0.012, (0, cy - i * 0.006, 5.3), 40, 0.01, rot=(math.radians(90), 0, 0))
        o.append(paint(d, c))
    # three darts in it
    for dx, dz in ((0.2, 0.15), (-0.3, -0.25), (0.05, 0.6)):
        o.append(paint(tube("Dart", [(dx, -0.05, 5.3 + dz), (dx + 0.05, -0.55, 5.35 + dz)], 0.03), BRASS_C, "chrome"))
        o.append(paint(box("Flight", (0.16, 0.12, 0.02), (dx + 0.05, -0.55, 5.35 + dz), 0.0, segs=1), (230, 60, 60)))
    # a chalk scoreboard under it
    o.append(paint(box("Chalk", (2.4, 0.06, 0.9), (0, 0.13, 3.75), 0.02), (40, 52, 46)))
    for i in range(4):
        o.append(paint(box("Score", (0.5, 0.02, 0.05), (-0.7 + (i % 2) * 1.2, 0.09, 3.95 - (i // 2) * 0.3), 0.0, segs=1), (230, 230, 220)))
    return o


@prop
def Gramophone():
    o = []
    o.append(paint(box("Cabinet", (2.0, 1.8, 2.6), (0, 0, 1.3), 0.06), WALNUT_C, var=0.03))
    o.append(paint(box("CabTop", (2.2, 2.0, 0.12), (0, 0, 2.66), 0.04), WALNUT_C2))
    o.append(paint(box("Grille", (1.4, 0.06, 1.2), (0, -0.92, 1.4), 0.03), (60, 40, 28)))
    o.append(paint(box("Box", (1.5, 1.5, 0.6), (0, 0, 3.02), 0.06), WALNUT_C2, var=0.03))
    o.append(paint(cyl("Platter", 0.62, 0.06, (0, 0, 3.36), 40), (40, 40, 44)))
    o.append(paint(cyl("Record", 0.58, 0.03, (0, 0, 3.41), 40), (18, 18, 20)))
    o.append(paint(cyl("Label", 0.18, 0.035, (0, 0, 3.42), 24), (196, 44, 48)))
    o.append(paint(tube("Crank", [(0.76, 0, 3.0), (1.0, 0, 3.0), (1.0, -0.2, 3.0)], 0.04), BRASS_C, "chrome"))
    # the arm and the big brass horn
    o.append(paint(tube("Arm", [(0.6, 0.55, 3.35), (0.6, 0.55, 3.7), (0.3, 0.3, 3.75), (0.1, 0.05, 3.48)], 0.05), BRASS_C, "chrome"))
    horn = lathe("Horn", [(0, 0), (0.08, 0), (0.12, 0.6), (0.22, 1.2), (0.45, 1.75), (0.95, 2.15), (1.05, 2.2), (0.95, 2.18), (0.4, 1.75), (0.18, 1.2), (0.06, 0.6), (0, 0.6)], (0, 0, 0), 40)
    turned(horn, (math.radians(-55), 0, math.radians(20)), (0.6, 0.55, 3.7))
    o.append(paint(horn, BRASS_C, "chrome"))
    return o


@prop
def Bonsai():
    o = []
    o.append(paint(box("Stand", (2.4, 1.4, 0.2), (0, 0, 1.3), 0.05), WALNUT_C))
    for sx in (-1, 1):
        o.append(paint(box("StandLeg", (0.24, 1.2, 1.2), (sx * 1.0, 0, 0.6), 0.05), WALNUT_C))
    o.append(paint(box("Tray", (1.9, 1.1, 0.35), (0, 0, 1.58), 0.08), (40, 70, 96), var=0.03))
    o.append(paint(box("Soil", (1.75, 0.95, 0.06), (0, 0, 1.74), 0.03), (70, 54, 40)))
    o.append(paint(sphere("Moss", 0.35, (-0.5, 0.1, 1.75), (1.4, 1, 0.35)), (96, 136, 64)))
    o.append(paint(sphere("Stone", 0.2, (0.6, -0.2, 1.8), (1.3, 1, 0.8)), (120, 120, 116)))
    # a twisting trunk and cloud pads of foliage
    trunk = [(0, 0, 1.75), (0.15, 0, 2.2), (-0.15, 0.05, 2.65), (0.1, 0, 3.05), (0.45, 0, 3.35)]
    o.append(paint(tube("Trunk", trunk, 0.16), (96, 70, 52)))
    o.append(paint(tube("Branch", [(-0.15, 0.05, 2.65), (-0.6, 0.05, 2.85), (-0.95, 0, 2.8)], 0.08), (96, 70, 52)))
    for x, z, r in ((0.5, 3.55, 0.55), (-0.95, 2.95, 0.42), (0.0, 3.25, 0.38), (0.95, 3.25, 0.32)):
        o.append(paint(sphere("Pad", r, (x, 0, z), (1.4, 1.1, 0.55)), (58, 112, 62), var=0.06))
    return o


@prop
def Easel():
    o = []
    # three legs leaning together
    o.append(paint(tube("LegL", [(-1.0, -0.4, 0), (-0.1, 0, 6.2)], 0.09), WALNUT_C2))
    o.append(paint(tube("LegR", [(1.0, -0.4, 0), (0.1, 0, 6.2)], 0.09), WALNUT_C2))
    o.append(paint(tube("LegB", [(0, 1.4, 0), (0, 0.1, 5.8)], 0.08), WALNUT_C2))
    o.append(paint(box("Ledge", (2.4, 0.5, 0.12), (0, -0.55, 2.4), 0.03), WALNUT_C))
    # the canvas: a landscape in a few bands
    lean = math.radians(-8)
    o.append(paint(box("Canvas", (2.6, 0.08, 2.0), (0, -0.42, 3.5), 0.02, rot=(lean, 0, 0)), (250, 248, 240)))
    bands = [((140, 196, 232), 0.55, 4.0), ((250, 206, 140), 0.18, 3.62), ((92, 130, 92), 0.35, 3.38), ((60, 104, 70), 0.3, 3.05)]
    for c, h, z in bands:
        o.append(paint(box("Paint", (2.4, 0.02, h), (0, -0.49 + (z - 3.5) * math.tan(lean), z), 0.0, segs=1, rot=(lean, 0, 0)), c))
    o.append(paint(sphere("Sun", 0.18, (0.6, -0.5, 4.0), (1, 0.3, 1)), (252, 236, 170)))
    # the palette on the ledge
    o.append(paint(cyl("Palette", 0.45, 0.04, (0.65, -0.6, 2.48), 24), (200, 160, 110)))
    for i, c in enumerate(((220, 60, 60), (60, 120, 220), (240, 200, 60), (80, 170, 90))):
        a = i * 1.2
        o.append(paint(sphere("Dab", 0.07, (0.65 + 0.28 * math.cos(a), -0.6 + 0.28 * math.sin(a), 2.52), (1, 1, 0.4)), c))
    o.append(paint(tube("Brush", [(-0.7, -0.62, 2.48), (-0.1, -0.62, 2.5)], 0.03), (40, 40, 40)))
    return o


@prop
def Telescope():
    o = []
    head = (0, 0, 4.2)
    for a in (90, 210, 330):
        r = math.radians(a)
        o.append(paint(tube("TripodLeg", [(1.3 * math.cos(r), 1.3 * math.sin(r), 0), (0.12 * math.cos(r), 0.12 * math.sin(r), 4.05)], 0.08), WALNUT_C2))
    o.append(paint(cyl("Mount", 0.22, 0.3, head, 20), BRASS_C, "chrome"))
    # the tube, tilted up to the sky
    tube_ob = lathe("Tube", [(0, 0), (0.24, 0), (0.24, 2.4), (0.3, 2.45), (0.3, 3.1), (0.26, 3.1), (0.26, 2.5), (0, 2.5)], (0, 0, 0), 32)
    turned(tube_ob, (math.radians(55), 0, 0), (0, 1.0, 3.6))
    o.append(paint(tube_ob, BRASS_C, "chrome"))
    o.append(paint(cyl("Eyepiece", 0.09, 0.4, (0, 1.05, 3.55), 16, rot=(math.radians(55), 0, 0)), EBONY))
    o.append(paint(turned(lathe("Lens", [(0, 0), (0.25, 0), (0.25, 0.02), (0, 0.02)], (0, 0, 0), 24), (math.radians(55), 0, 0), (0, -1.55, 5.38)), (170, 200, 220), "glass"))
    return o


@prop
def UmbrellaStand():
    o = []
    o.append(paint(lathe("Stand", [(0, 0), (0.62, 0), (0.62, 2.1), (0.56, 2.1), (0.56, 0.12), (0, 0.12)], (0, 0, 0), 40), (40, 64, 56), var=0.02))
    for z in (0.15, 1.95):
        o.append(paint(lathe("Band", [(0.6, 0), (0.67, 0), (0.67, 0.14), (0.6, 0.14)], (0, 0, z), 40), BRASS_C, "chrome"))
    cols = [(196, 54, 64), (38, 58, 112), (30, 32, 40), (232, 184, 64)]
    for i, c in enumerate(cols):
        a = math.radians(i * 90 + 20)
        x, y = 0.28 * math.cos(a), 0.28 * math.sin(a)
        lean_x, lean_y = 0.25 * math.cos(a), 0.25 * math.sin(a)
        # a furled umbrella: a long cone of cloth, a shaft and a crook handle
        o.append(paint(tube("Furl", [(x, y, 0.3), (x + lean_x * 0.5, y + lean_y * 0.5, 1.6), (x + lean_x, y + lean_y, 2.6)], 0.14), c))
        hx, hy = x + lean_x * 1.1, y + lean_y * 1.1
        o.append(paint(tube("Shaft", [(x + lean_x, y + lean_y, 2.6), (hx, hy, 3.05)], 0.04), (60, 60, 66), "chrome"))
        o.append(paint(tube("Crook", [(hx, hy, 3.05), (hx, hy, 3.3), (hx + 0.18 * math.cos(a), hy + 0.18 * math.sin(a), 3.38), (hx + 0.3 * math.cos(a), hy + 0.3 * math.sin(a), 3.2)], 0.05), (88, 56, 34)))
    return o


@prop
def Candelabra():
    o = []
    o.append(paint(lathe("Stem", [(0, 0), (0.7, 0), (0.7, 0.12), (0.3, 0.3), (0.12, 0.6), (0.1, 4.8), (0.18, 5.0), (0.1, 5.2), (0, 5.2)], (0, 0, 0), 32), BRASS_C, "chrome"))
    arms = [(-1.0, 5.6), (-0.5, 6.0), (0, 6.3), (0.5, 6.0), (1.0, 5.6)]
    for x, z in arms:
        if x != 0:
            o.append(paint(tube("Arm", [(0, 0, 5.1), (x * 0.6, 0, 5.15), (x, 0, z - 0.2)], 0.06), BRASS_C, "chrome"))
        o.append(paint(lathe("Cup", [(0, 0), (0.16, 0), (0.2, 0.18), (0, 0.18)], (x, 0, z - 0.2), 20), BRASS_C, "chrome"))
        o.append(paint(cyl("Candle", 0.1, 0.6, (x, 0, z + 0.28), 16), IVORY))
        o.append(paint(sphere("Glow", 0.09, (x, 0, z + 0.72), (1, 1, 1.8)), (255, 210, 140), "glow"))
    return o


@prop
def Column():
    o = []
    o.append(paint(box("Plinth", (2.4, 2.4, 0.5), (0, 0, 0.25), 0.05), MARBLE_C, var=0.02))
    o.append(paint(lathe("Base", [(0, 0), (1.05, 0), (1.05, 0.2), (0.9, 0.35), (0.95, 0.45), (0.82, 0.55), (0, 0.55)], (0, 0, 0.5), 40), MARBLE_C, var=0.02))
    # a fluted shaft: a cylinder ringed with shallow ribs
    o.append(paint(lathe("Shaft", [(0, 0), (0.78, 0), (0.72, 8.0), (0, 8.0)], (0, 0, 1.05), 40), MARBLE_C, var=0.02))
    for i in range(16):
        a = math.radians(i * 22.5)
        o.append(paint(box("Flute", (0.1, 0.1, 7.6), (0.78 * math.cos(a), 0.78 * math.sin(a), 4.9), 0.04, rot=(0, 0, a)), (226, 222, 214)))
    o.append(paint(lathe("Collar", [(0.72, 0), (0.86, 0), (0.86, 0.22), (0.72, 0.22)], (0, 0, 8.2), 40), BRASS_C, "chrome"))
    o.append(paint(lathe("Capital", [(0, 0), (0.8, 0), (1.15, 0.35), (1.2, 0.5), (0, 0.5)], (0, 0, 9.05), 40), MARBLE_C, var=0.02))
    o.append(paint(box("Abacus", (2.5, 2.5, 0.35), (0, 0, 9.72), 0.05), MARBLE_C, var=0.02))
    return o
