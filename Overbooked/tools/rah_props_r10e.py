"""Round 10e props. Loaded by rah_props.py (exec) after the r10c file.
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
  BedTwin       : two single beds with a shared nightstand (sleeps two: groups can share a room)
  BedBunk       : a walnut bunk bed with a ladder (sleeps two)
  BedCanopy     : a four-poster with drapes and a quilted throw
  AirHockey     : an air-hockey table, glowing rails, pucks and mallets
  Pinball       : a pinball machine with a lit backglass
  KaraokeStage  : a little round stage with a mic stand, a speaker and a lyrics screen
  PhotoBooth    : a curtained photo booth with a lit sign
  HotTub        : a round wooden hot tub with steaming water and a step
  Treadmill     : a gym treadmill with a console
  StaffLocker   : a bank of four staff lockers with a bench (the staff room)
  StaffTable    : a staff break table with a kettle, mugs and two stools
  ServiceCart   : a room-service trolley under a white cloth, a cloche and a rose
  Suitcase      : a hard-shell travel case with a handle (a guest's luggage)
  Duffel        : a leather duffel bag
  ParkingSpot   : painted bay lines with a wheel stop and a P sign
"""

LINEN = (246, 242, 234)
OAK_C = (176, 122, 76)
NAVY = (36, 44, 78)
TEAL = (52, 150, 150)
NEON_PINK = (255, 90, 160)
NEON_BLUE = (90, 200, 255)
STEEL = (120, 126, 136)
LOCKER_C = (70, 110, 120)
CEDAR = (150, 92, 56)


def single_bed(o, cx, w=3.4, l=7.6, frame=OAK_C, duvet=(232, 222, 204), runner=(52, 92, 120)):
    o.append(paint(box("Base", (w, l, 0.9), (cx, 0, 0.75), 0.14), frame))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Leg", 0.16, 0.35, (cx + sx * (w / 2 - 0.3), sy * (l / 2 - 0.3), 0.18), 12), WALNUT_C))
    o.append(paint(box("Mattress", (w - 0.3, l - 0.3, 0.85), (cx, 0.05, 1.6), 0.28, 5), LINEN, var=0.02))
    o.append(paint(box("Headboard", (w + 0.2, 0.45, 4.0), (cx, l / 2 + 0.05, 2.0), 0.16), frame))
    o.append(paint(box("HeadPad", (w - 0.5, 0.3, 2.0), (cx, l / 2 - 0.2, 2.7), 0.28, 6), (204, 196, 180), var=0.03))
    duv = box("Duvet", (w + 0.05, l * 0.66, 1.25), (cx, -l * 0.15, 1.55), 0.32, 5, cuts=5)
    wobble(duv, 0.04, 0.9, cx)
    o.append(paint(duv, duvet, var=0.03))
    o.append(paint(box("Runner", (w + 0.12, 1.2, 1.32), (cx, -l * 0.38, 1.56), 0.34, 5), runner, var=0.04))
    p = box("Pillow", (w - 1.0, 1.2, 0.62), (cx, l / 2 - 0.95, 2.3), 0.28, 6, cuts=2)
    puff(p, (w - 1.0) / 2, 0.6, 0.4)
    o.append(paint(p, LINEN, var=0.02))


@prop
def BedTwin():
    o = []
    for cx in (-2.6, 2.6):
        single_bed(o, cx)
    # the shared nightstand and a lamp
    o.append(paint(box("Stand", (1.4, 1.4, 2.0), (0, 3.0, 1.0), 0.08), WALNUT_C2))
    o.append(paint(box("Drawer", (1.2, 0.05, 0.5), (0, 2.28, 1.4), 0.02), WALNUT_C))
    o.append(paint(sphere("Pull", 0.06, (0, 2.24, 1.4)), BRASS_C, "chrome"))
    o.append(paint(lathe("LampBase", [(0, 0), (0.3, 0), (0.25, 0.2), (0.08, 0.3), (0.08, 0.9), (0, 0.9)], (0, 3.0, 2.0), 20), BRASS_C, "chrome"))
    o.append(paint(lathe("Shade", [(0.45, 0), (0.3, 0.6), (0.29, 0.6), (0.44, 0.0)], (0, 3.0, 2.75), 24), (246, 232, 206), "glow"))
    return o


@prop
def BedBunk():
    o = []
    w, l = 3.8, 7.8
    for z in (0.9, 5.4):
        o.append(paint(box("Frame", (w, l, 0.5), (0, 0, z), 0.08), WALNUT_C2))
        o.append(paint(box("Mattress", (w - 0.35, l - 0.35, 0.75), (0, 0, z + 0.6), 0.25, 5), LINEN, var=0.02))
        duv = box("Duvet", (w - 0.2, l * 0.62, 1.0), (0, -l * 0.17, z + 0.7), 0.3, 5, cuts=4)
        wobble(duv, 0.04, 0.9, z)
        o.append(paint(duv, (196, 58, 52) if z < 2 else NAVY, var=0.03))
        p = box("Pillow", (w - 1.1, 1.1, 0.55), (0, l / 2 - 0.9, z + 1.25), 0.25, 6, cuts=2)
        puff(p, (w - 1.1) / 2, 0.55, 0.35)
        o.append(paint(p, LINEN, var=0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Post", (0.4, 0.4, 8.6), (sx * (w / 2 - 0.1), sy * (l / 2 - 0.1), 4.3), 0.06), WALNUT_C))
            o.append(paint(sphere("Finial", 0.26, (sx * (w / 2 - 0.1), sy * (l / 2 - 0.1), 8.75)), WALNUT_C2))
    # rails round the top bunk
    for sx in (-1, 1):
        o.append(paint(box("Rail", (0.18, l - 0.4, 0.22), (sx * (w / 2 - 0.1), 0, 6.9), 0.05), WALNUT_C))
    o.append(paint(box("RailEnd", (w - 0.4, 0.18, 1.2), (0, l / 2 - 0.1, 6.6), 0.05), WALNUT_C))
    # the ladder on the front-left
    lx = -w / 2 - 0.25
    for sy in (-1.6, -0.4):
        o.append(paint(box("LadderSide", (0.16, 0.16, 7.2), (lx, sy, 3.6), 0.04), WALNUT_C))
    for k in range(5):
        o.append(paint(cyl("Rung", 0.08, 1.2, (lx, -1.0, 1.4 + k * 1.2), 10, rot=(math.radians(90), 0, 0)), BRASS_C, "chrome"))
    return o


@prop
def BedCanopy():
    o = []
    w, l = 6.4, 8.8
    o.append(paint(box("Base", (w, l, 1.1), (0, 0, 0.9), 0.16), WALNUT_C2))
    o.append(paint(box("Mattress", (w - 0.4, l - 0.4, 1.0), (0, 0, 1.95), 0.32, 5), LINEN, var=0.02))
    duv = box("Duvet", (w + 0.1, l * 0.66, 1.5), (0, -l * 0.15, 1.9), 0.38, 5, cuts=6)
    wobble(duv, 0.05, 0.9, 3.0)
    o.append(paint(duv, (240, 228, 206), var=0.03))
    # a quilted throw: a grid of puffy squares
    for i in range(5):
        for j in range(2):
            q = box("Quilt", (1.25, 0.95, 0.3), (-2.5 + i * 1.25, -2.9 + j * 0.95, 2.7), 0.12, 4)
            o.append(paint(q, (120, 30, 48) if (i + j) % 2 == 0 else (150, 44, 60), var=0.04))
    for x in (-1.6, 1.6):
        p = box("Pillow", (2.4, 1.4, 0.8), (x, 3.4, 2.85), 0.34, 6, cuts=2)
        puff(p, 1.2, 0.7, 0.45)
        o.append(paint(p, LINEN, var=0.02))
    o.append(paint(box("Headboard", (w, 0.5, 5.2), (0, l / 2 + 0.05, 2.6), 0.16), WALNUT_C2))
    for i in range(5):
        o.append(paint(box("Carve", (0.9, 0.2, 3.2), (-2.4 + i * 1.2, l / 2 - 0.25, 3.0), 0.2, 4), WALNUT_C))
    # four turned posts, the canopy frame and drapes
    H = 10.4
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 + 0.05), sy * (l / 2 + 0.05)
            o.append(paint(lathe("Post", [(0, 0), (0.32, 0), (0.32, 0.6), (0.2, 0.8), (0.16, 3.0), (0.24, 3.4), (0.14, 3.8), (0.13, H), (0, H)], (x, y, 0), 20), WALNUT_C))
            o.append(paint(sphere("Finial", 0.24, (x, y, H + 0.15)), BRASS_C, "chrome"))
            # a gathered drape tied to each post
            d = box("Drape", (0.7, 0.35, H - 1.8), (x - sx * 0.5, y - sy * 0.3, (H - 1.8) / 2 + 1.4), 0.15, 4, cuts=6)
            wobble(d, 0.05, 1.6, x + y)
            o.append(paint(d, (236, 226, 210), var=0.04))
            o.append(paint(cyl("Tie", 0.3, 0.2, (x - sx * 0.5, y - sy * 0.3, 4.2), 16), BRASS_C, "chrome"))
    for sy in (-1, 1):
        o.append(paint(box("Beam", (w + 0.5, 0.3, 0.3), (0, sy * (l / 2 + 0.05), H - 0.1), 0.05), WALNUT_C2))
    for sx in (-1, 1):
        o.append(paint(box("Beam", (0.3, l + 0.5, 0.3), (sx * (w / 2 + 0.05), 0, H - 0.1), 0.05), WALNUT_C2))
    v = box("Valance", (w + 0.6, l + 0.6, 0.7), (0, 0, H - 0.5), 0.1, 3, cuts=8)
    wobble(v, 0.05, 2.0, 1.0)
    o.append(paint(v, (236, 226, 210), var=0.03))
    return o


@prop
def AirHockey():
    o = []
    W, L = 4.2, 7.6
    o.append(paint(box("Body", (W, L, 1.4), (0, 0, 2.3), 0.12), NAVY))
    o.append(paint(box("Surface", (W - 0.5, L - 0.5, 0.06), (0, 0, 3.03), 0.02, 2), (238, 244, 250)))
    o.append(paint(box("CenterLine", (W - 0.5, 0.08, 0.02), (0, 0, 3.07), 0.0, 1), (230, 60, 70)))
    o.append(paint(lathe("Circle", [(0.8, 0), (0.86, 0), (0.86, 0.02), (0.8, 0.02)], (0, 0, 3.06), 40), (230, 60, 70)))
    for sy in (-1, 1):
        o.append(paint(box("Goal", (1.4, 0.2, 0.3), (0, sy * (L / 2 - 0.15), 3.05), 0.04), (20, 20, 28)))
        o.append(paint(box("Rail", (W, 0.2, 0.36), (0, sy * (L / 2 - 0.1), 3.18), 0.06), NEON_PINK if sy > 0 else NEON_BLUE, "glow"))
        o.append(paint(lathe("Mallet", [(0, 0), (0.42, 0), (0.42, 0.18), (0.18, 0.24), (0.14, 0.55), (0.2, 0.62), (0, 0.66)], (0.6 * sy, sy * 2.6, 3.06), 24), (230, 60, 70) if sy > 0 else (60, 120, 230)))
    for sx in (-1, 1):
        o.append(paint(box("Rail", (0.2, L, 0.36), (sx * (W / 2 - 0.1), 0, 3.18), 0.06), (200, 200, 210), "chrome"))
    o.append(paint(cyl("Puck", 0.28, 0.1, (-0.4, 0.5, 3.1), 24), (20, 20, 24)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.5, 0.5, 1.6), (sx * (W / 2 - 0.4), sy * (L / 2 - 0.4), 0.8), 0.06), (28, 32, 52)))
    return o


@prop
def Pinball():
    o = []
    W = 2.6
    # the cabinet tilts up toward the back
    o.append(paint(box("Cab", (W, 5.0, 1.2), (0, 0, 3.0), 0.08, rot=(math.radians(-6.5), 0, 0)), (180, 30, 60)))
    o.append(paint(box("Playfield", (W - 0.3, 4.7, 0.06), (0, 0, 3.62), 0.02, 2, rot=(math.radians(-6.5), 0, 0)), (40, 60, 140)))
    o.append(paint(box("GlassTop", (W - 0.2, 4.8, 0.04), (0, 0, 3.72), 0.01, 1, rot=(math.radians(-6.5), 0, 0)), (200, 220, 240), "glass"))
    for i, (x, y) in enumerate(((-0.5, 0.8), (0.4, 1.4), (0.0, 0.2))):
        o.append(paint(cyl("Bumper", 0.28, 0.3, (x, y, 3.75 + y * 0.11), 20), (255, 210, 80), "glow"))
    for sx in (-1, 1):
        o.append(paint(box("Flipper", (0.7, 0.16, 0.12), (sx * 0.45, -1.9, 3.55), 0.04, rot=(0, 0, math.radians(sx * -20))), (250, 250, 250)))
    # the backbox with the lit backglass
    o.append(paint(box("Backbox", (W, 0.6, 2.6), (0, 2.7, 5.2), 0.08), (180, 30, 60)))
    o.append(paint(box("Backglass", (W - 0.3, 0.05, 2.2), (0, 2.38, 5.25), 0.02, 2), NEON_PINK, "glow"))
    o.append(paint(box("Score", (1.6, 0.06, 0.4), (0, 2.37, 4.25), 0.02), (255, 160, 60), "glow"))
    for sx in (-1, 1):
        o.append(paint(box("LegF", (0.22, 0.22, 2.4), (sx * (W / 2 - 0.2), -2.3, 1.2), 0.04), STEEL, "chrome"))
        o.append(paint(box("LegB", (0.22, 0.22, 3.0), (sx * (W / 2 - 0.2), 2.3, 1.5), 0.04), STEEL, "chrome"))
    o.append(paint(box("Coin", (0.8, 0.06, 0.5), (0, -2.55, 2.2), 0.02), (230, 200, 120), "chrome"))
    return o


@prop
def KaraokeStage():
    o = []
    o.append(paint(lathe("Stage", [(0, 0), (4.0, 0), (4.0, 0.9), (0, 0.9)], (0, 0, 0), 48), WALNUT_C2, var=0.03))
    o.append(paint(lathe("Edge", [(3.95, 0.85), (4.08, 0.85), (4.08, 1.0), (3.95, 1.0)], (0, 0, 0), 48), NEON_PINK, "glow"))
    o.append(paint(lathe("Carpet", [(0, 0.9), (3.6, 0.9), (3.6, 0.95), (0, 0.95)], (0, 0, 0), 48), (150, 28, 44)))
    # mic stand
    o.append(paint(lathe("MicBase", [(0, 0), (0.5, 0), (0.45, 0.1), (0, 0.12)], (0, -0.8, 0.95), 24), (30, 30, 34), "chrome"))
    o.append(paint(cyl("MicPole", 0.05, 4.4, (0, -0.8, 3.15), 10), (40, 40, 44), "chrome"))
    o.append(paint(sphere("Mic", 0.2, (0, -0.95, 5.4)), (200, 200, 205), "chrome"))
    o.append(paint(cyl("MicGrip", 0.09, 0.6, (0, -0.88, 5.05), 10, rot=(math.radians(-15), 0, 0)), (30, 30, 34)))
    # a speaker each side
    for sx in (-1, 1):
        o.append(paint(box("Speaker", (1.3, 1.1, 2.4), (sx * 2.7, 1.6, 2.15), 0.06), (28, 28, 32)))
        for z, r in ((2.8, 0.42), (1.75, 0.3)):
            o.append(paint(cyl("Cone", r, 0.08, (sx * 2.7, 1.04, z), 24, rot=(math.radians(90), 0, 0)), (70, 70, 76)))
    # a lyrics screen on a stand at the back
    o.append(paint(box("Screen", (3.0, 0.15, 1.8), (0, 3.0, 5.2), 0.04), (20, 20, 24)))
    o.append(paint(box("Lyrics", (2.7, 0.04, 1.5), (0, 2.91, 5.2), 0.01, 1), NEON_BLUE, "glow"))
    o.append(paint(cyl("ScreenPole", 0.08, 3.4, (0, 3.1, 2.6), 10), (40, 40, 44), "chrome"))
    return o


@prop
def PhotoBooth():
    o = []
    W, D, H = 4.2, 4.0, 8.4
    o.append(paint(box("Back", (W, 0.3, H), (0, D / 2 - 0.15, H / 2), 0.06), (34, 34, 44)))
    for sx in (-1, 1):
        o.append(paint(box("Side", (0.3, D, H), (sx * (W / 2 - 0.15), 0, H / 2), 0.06), (190, 40, 60)))
    o.append(paint(box("Roof", (W + 0.3, D + 0.3, 0.4), (0, 0, H + 0.2), 0.08), (190, 40, 60)))
    o.append(paint(box("Sign", (W - 0.6, 0.15, 1.0), (0, -D / 2 - 0.05, H - 0.6), 0.04), (255, 220, 120), "glow"))
    # the curtain, gathered to one side
    c = box("Curtain", (W * 0.45, 0.25, H - 1.6), (-W * 0.22, -D / 2 + 0.2, (H - 1.6) / 2 + 0.3), 0.12, 4, cuts=8)
    wobble(c, 0.12, 2.4, 0.5)
    o.append(paint(c, (120, 20, 40), var=0.05))
    o.append(paint(cyl("Rod", 0.06, W - 0.4, (0, -D / 2 + 0.2, H - 1.2), 10, rot=(0, math.radians(90), 0)), BRASS_C, "chrome"))
    # inside: a bench, the camera and a strip of photos
    o.append(paint(box("Bench", (W - 0.8, 1.2, 0.4), (0, 0.9, 2.0), 0.08), (60, 60, 72)))
    o.append(paint(box("BenchBase", (W - 1.0, 1.0, 1.8), (0, 0.9, 0.9), 0.06), (44, 44, 54)))
    o.append(paint(box("Camera", (1.0, 0.4, 0.8), (0, D / 2 - 0.5, 5.0), 0.06), (20, 20, 24)))
    o.append(paint(cyl("Lens", 0.25, 0.2, (0, D / 2 - 0.75, 5.0), 20, rot=(math.radians(90), 0, 0)), (200, 220, 240), "glass"))
    for k in range(4):
        o.append(paint(box("Photo", (0.7, 0.04, 0.55), (W / 2 + 0.03, -0.6 + k * 0.6, 4.0), 0.01, 1, rot=(0, 0, math.radians(90))), (240, 236, 226)))
    return o


@prop
def HotTub():
    o = []
    R = 3.6
    n = 28
    # cedar staves round the tub
    for k in range(n):
        a = 2 * math.pi * k / n
        o.append(paint(box("Stave", (0.8, 0.3, 3.0), (math.cos(a) * R, math.sin(a) * R, 1.5), 0.05, rot=(0, 0, a + math.pi / 2)), CEDAR if k % 2 else (166, 104, 64)))
    for z in (0.6, 2.4):
        o.append(paint(lathe("Hoop", [(R + 0.14, z), (R + 0.24, z), (R + 0.24, z + 0.2), (R + 0.14, z + 0.2)], (0, 0, 0), 48), (60, 60, 66), "chrome"))
    o.append(paint(lathe("Rim", [(R - 0.3, 3.0), (R + 0.3, 3.0), (R + 0.3, 3.2), (R - 0.3, 3.2)], (0, 0, 0), 48), (186, 120, 76)))
    o.append(paint(lathe("Water", [(0, 2.6), (R - 0.15, 2.6), (R - 0.15, 2.65), (0, 2.65)], (0, 0, 0), 48), (110, 200, 220), "glass"))
    o.append(paint(lathe("WaterGlow", [(0, 2.2), (R - 0.2, 2.2), (R - 0.2, 2.24), (0, 2.24)], (0, 0, 0), 48), (120, 220, 255), "glow"))
    # a bench ring inside and a step outside
    o.append(paint(lathe("Bench", [(R - 1.0, 1.4), (R - 0.2, 1.4), (R - 0.2, 1.7), (R - 1.0, 1.7)], (0, 0, 0), 40), CEDAR))
    o.append(paint(box("Step", (2.4, 1.2, 1.0), (0, -R - 0.7, 0.5), 0.06), (166, 104, 64)))
    o.append(paint(box("Towel", (1.4, 0.8, 0.25), (0, -R - 0.7, 1.12), 0.1), (246, 246, 246), var=0.02))
    return o


@prop
def Treadmill():
    o = []
    o.append(paint(box("Deck", (2.8, 6.2, 0.7), (0, -0.4, 0.5), 0.12), (40, 42, 48)))
    o.append(paint(box("Belt", (2.0, 5.6, 0.08), (0, -0.4, 0.9), 0.03, 2), (24, 24, 26)))
    for sx in (-1, 1):
        o.append(paint(box("SideRail", (0.32, 5.8, 0.12), (sx * 1.2, -0.4, 0.92), 0.04), STEEL, "chrome"))
        o.append(paint(tube("Upright", [(sx * 1.1, 2.4, 0.8), (sx * 1.15, 2.9, 4.6)], 0.12), (60, 62, 70)))
        o.append(paint(tube("Handle", [(sx * 1.15, 2.9, 4.3), (sx * 1.2, 1.8, 4.2)], 0.1), (30, 30, 32)))
    o.append(paint(box("Console", (2.6, 0.8, 1.0), (0, 2.9, 5.0), 0.12, rot=(math.radians(-30), 0, 0)), (54, 56, 64)))
    o.append(paint(box("Display", (1.6, 0.05, 0.6), (0, 2.5, 5.15), 0.02, 1, rot=(math.radians(-30), 0, 0)), (90, 230, 160), "glow"))
    return o


@prop
def StaffLocker():
    o = []
    for k in range(4):
        x = -2.4 + k * 1.6
        o.append(paint(box("Locker", (1.5, 1.6, 7.2), (x, 0.4, 3.6), 0.04), LOCKER_C if k % 2 == 0 else (64, 102, 112)))
        o.append(paint(box("DoorLine", (1.3, 0.04, 6.8), (x, -0.42, 3.6), 0.01, 1), (54, 88, 96)))
        for z in (6.3, 6.0, 5.7):
            o.append(paint(box("Vent", (0.8, 0.05, 0.08), (x, -0.44, z), 0.0, 1), (40, 64, 72)))
        o.append(paint(box("Handle", (0.12, 0.12, 0.6), (x + 0.5, -0.48, 3.8), 0.03), (210, 210, 214), "chrome"))
        o.append(paint(box("Tag", (0.6, 0.04, 0.3), (x, -0.44, 5.0), 0.01), (240, 236, 220)))
    o.append(paint(box("Bench", (6.0, 1.3, 0.3), (0, -1.9, 1.7), 0.06), OAK_C))
    for sx in (-1, 1):
        o.append(paint(box("BenchLeg", (0.3, 1.0, 1.55), (sx * 2.5, -1.9, 0.78), 0.04), STEEL, "chrome"))
    # a staff jacket hanging off one door and a bag on the bench
    o.append(paint(box("Jacket", (1.0, 0.3, 2.0), (-0.8, -0.6, 4.6), 0.2, 4), (36, 60, 112)))
    o.append(paint(box("Bag", (1.0, 0.6, 0.6), (1.6, -1.9, 2.15), 0.2, 4), (130, 90, 56)))
    return o


@prop
def StaffTable():
    o = []
    o.append(paint(box("Top", (4.4, 3.0, 0.2), (0, 0, 3.0), 0.06), OAK_C, var=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.22, 0.22, 2.9), (sx * 1.9, sy * 1.2, 1.45), 0.04), STEEL, "chrome"))
    o.append(paint(lathe("Kettle", [(0, 0), (0.45, 0), (0.5, 0.3), (0.42, 0.8), (0.2, 0.95), (0, 0.98)], (-1.2, 0.3, 3.1), 24), (220, 222, 228), "chrome"))
    o.append(paint(tube("KettleHandle", [(-1.55, 0.3, 3.7), (-1.6, 0.3, 4.3), (-0.8, 0.3, 4.3), (-0.85, 0.3, 3.7)], 0.06), (30, 30, 32)))
    for i, c in enumerate(((230, 80, 70), (80, 160, 220), (240, 200, 90))):
        x = 0.2 + i * 0.7
        o.append(paint(lathe("Mug", [(0, 0), (0.26, 0), (0.28, 0.55), (0.24, 0.55), (0.22, 0.08), (0, 0.08)], (x, -0.4 + (i % 2) * 0.5, 3.1), 20), c))
    o.append(paint(box("Biscuits", (0.9, 0.6, 0.25), (1.2, 0.7, 3.22), 0.06), (190, 140, 80)))
    for sy in (-1, 1):
        o.append(paint(lathe("Stool", [(0, 0), (0.6, 0), (0.6, 0.1), (0.15, 0.2), (0.12, 2.0), (0.7, 2.05), (0.7, 2.25), (0, 2.3)], (0, sy * 2.4, 0), 24), (60, 64, 72)))
    return o


@prop
def ServiceCart():
    o = []
    o.append(paint(box("Top", (2.4, 3.8, 0.12), (0, 0, 3.0), 0.04), (226, 226, 230), "chrome"))
    o.append(paint(box("Shelf", (2.2, 3.6, 0.1), (0, 0, 1.0), 0.03), (200, 200, 206), "chrome"))
    cl = box("Cloth", (2.6, 4.0, 0.9), (0, 0, 2.62), 0.12, 4, cuts=5)
    wobble(cl, 0.04, 1.6, 0.2)
    o.append(paint(cl, (250, 250, 248), var=0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Post", 0.06, 2.8, (sx * 1.1, sy * 1.8, 1.6), 10), (200, 200, 206), "chrome"))
            o.append(paint(sphere("Wheel", 0.2, (sx * 1.1, sy * 1.8, 0.2), (0.6, 1, 1)), (40, 40, 44)))
    o.append(paint(tube("Handle", [(-1.0, 2.0, 3.1), (-1.0, 2.3, 3.8), (1.0, 2.3, 3.8), (1.0, 2.0, 3.1)], 0.07), (200, 200, 206), "chrome"))
    # a cloche, a plate, a glass, a rose in a bud vase
    o.append(paint(lathe("Plate", [(0, 0), (0.75, 0), (0.85, 0.08), (0, 0.06)], (0, -0.6, 3.07), 32), (248, 248, 246)))
    o.append(paint(lathe("Cloche", [(0.7, 0), (0.66, 0.35), (0.45, 0.62), (0.1, 0.72), (0, 0.73)], (0, -0.6, 3.12), 32), (220, 222, 226), "chrome"))
    o.append(paint(sphere("Knob", 0.08, (0, -0.6, 3.9)), BRASS_C, "chrome"))
    o.append(paint(lathe("Glass", [(0, 0), (0.14, 0), (0.03, 0.06), (0.03, 0.4), (0.18, 0.5), (0.2, 0.85), (0.18, 0.86), (0, 0.5)], (0.6, 1.0, 3.07), 20), (220, 236, 244), "glass"))
    o.append(paint(lathe("Vase", [(0, 0), (0.1, 0), (0.12, 0.2), (0.05, 0.5), (0, 0.5)], (-0.6, 1.0, 3.07), 16), (240, 240, 244), "glass"))
    o.append(paint(sphere("Rose", 0.14, (-0.6, 1.0, 3.95)), (210, 30, 50)))
    o.append(paint(cyl("Stem", 0.02, 0.5, (-0.6, 1.0, 3.6), 6), (60, 120, 60)))
    return o


@prop
def Suitcase():
    o = []
    o.append(paint(box("Shell", (1.8, 0.9, 2.6), (0, 0, 1.55), 0.22, 5), (40, 110, 170)))
    for x in (-0.45, 0.0, 0.45):
        o.append(paint(box("Rib", (0.1, 0.94, 2.4), (x, 0, 1.55), 0.04), (34, 96, 150)))
    o.append(paint(box("Zip", (1.84, 0.04, 2.5), (0, 0, 1.55), 0.02), (60, 60, 70)))
    for sx in (-1, 1):
        o.append(paint(box("HandlePost", (0.08, 0.08, 1.0), (sx * 0.4, 0.2, 3.3), 0.02), STEEL, "chrome"))
        for sy in (-1, 1):
            o.append(paint(sphere("Wheel", 0.12, (sx * 0.7, sy * 0.3, 0.12)), (30, 30, 34)))
    o.append(paint(box("Handle", (0.95, 0.12, 0.12), (0, 0.2, 3.8), 0.04), (30, 30, 34)))
    o.append(paint(box("Tag", (0.25, 0.04, 0.35), (0.6, -0.47, 2.6), 0.01), (240, 200, 90)))
    return o


@prop
def Duffel():
    o = []
    b = box("Bag", (2.4, 1.2, 1.1), (0, 0, 0.6), 0.45, 6, cuts=3)
    o.append(paint(b, (120, 74, 44), var=0.04))
    for sx in (-1, 1):
        o.append(paint(turned(lathe("End", [(0, 0), (0.52, 0), (0.52, 0.06), (0, 0.06)], (0, 0, 0), 24), (0, math.radians(90), 0), (sx * 1.18, 0, 0.6)), (92, 56, 32)))
    o.append(paint(box("Zip", (2.0, 0.05, 0.05), (0, 0, 1.16), 0.02), BRASS_C, "chrome"))
    o.append(paint(tube("Strap", [(-0.6, 0, 1.1), (-0.5, 0, 1.6), (0.5, 0, 1.6), (0.6, 0, 1.1)], 0.07), (70, 44, 26)))
    return o


@prop
def ParkingSpot():
    o = []
    W, L = 9.0, 17.0
    # two white bay lines and a back line, the bay faintly tinted, a P painted on the tarmac
    o.append(paint(box("Bay", (W, L, 0.04), (0, 0, 0.02), 0.0, 1), (62, 64, 70)))
    for sx in (-1, 1):
        o.append(paint(box("Line", (0.35, L, 0.06), (sx * (W / 2 - 0.18), 0, 0.04), 0.0, 1), (240, 240, 236)))
    o.append(paint(box("BackLine", (W, 0.35, 0.06), (0, L / 2 - 0.18, 0.04), 0.0, 1), (240, 240, 236)))
    o.append(paint(box("Hatch", (W - 1.4, 0.5, 0.06), (0, -L / 2 + 0.6, 0.04), 0.0, 1), (240, 200, 70)))
    # a concrete wheel stop with yellow ends
    o.append(paint(box("Stop", (5.0, 0.9, 0.5), (0, L / 2 - 2.0, 0.25), 0.12), (196, 194, 188)))
    for sx in (-1, 1):
        o.append(paint(box("StopEnd", (0.8, 0.94, 0.54), (sx * 2.1, L / 2 - 2.0, 0.27), 0.12), (240, 200, 60)))
    # a little blue P sign on a post at the back corner
    o.append(paint(cyl("SignPost", 0.1, 6.0, (W / 2 - 0.4, L / 2 - 0.4, 3.0), 10), STEEL, "chrome"))
    o.append(paint(box("SignBoard", (1.6, 0.12, 1.6), (W / 2 - 0.4, L / 2 - 0.5, 6.2), 0.06), (40, 90, 200)))
    o.append(paint(box("SignP", (0.3, 0.04, 1.0), (W / 2 - 0.65, L / 2 - 0.58, 6.2), 0.0, 1), (250, 250, 250)))
    o.append(paint(box("SignP", (0.6, 0.04, 0.3), (W / 2 - 0.4, L / 2 - 0.58, 6.55), 0.0, 1), (250, 250, 250)))
    return o
