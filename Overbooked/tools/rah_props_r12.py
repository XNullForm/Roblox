"""Round 12 props: a lot more to build with. Loaded by rah_props.py (exec) after the r10e file.
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
  Furniture : DiningChair, ReadingNook (wingback + lamp), Bench (tufted lobby bench), Beanbag, RoundTable, BarCounter
  Decor     : Bookcase (tall, full of books), Globe2 (no: see DeskGlobe), PlantShelf, FruitBowl table, Statue (marble bust),
              Fountain (tiered lobby fountain), Tapestry (wall), RoomDivider (folding screen), Planter (long box hedge)
  Lighting  : Chandelier, PendantLamp, LanternPost (lobby lantern), NeonSign (wall, OPEN)
  Fun       : DJBooth, BowlingLane (one short lane), VRPod, MiniGolf (a putting hole)
  Amenities : TowelStack, IceMachine, PhoneBooth, KeyRack (wall)
  Rooms     : RoomSafe, BunkLadder? (no), CurtainWindow (wall), BedsideRadio
  Outdoor   : Bike rack, Bench (park), Streetlamp (no: city has one)
"""

ROSE = (210, 120, 130)
CREAMY = (240, 232, 214)
MOSS = (88, 128, 72)
LEAF = (70, 140, 74)
STONE = (204, 200, 192)
NEON_GOLD = (255, 200, 90)
PLUM = (96, 52, 86)
MINT = (150, 214, 190)
CHERRY = (164, 52, 52)


def leg4(o, w, d, h, inset=0.25, r=0.12, col=None):
    col = col or WALNUT_C
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (r * 0.8, 0), (r, h * 0.5), (r * 1.1, h), (0, h)], (sx * (w / 2 - inset), sy * (d / 2 - inset), 0), 12), col))


@prop
def DiningChair():
    o = []
    leg4(o, 2.0, 2.0, 1.9, 0.2, 0.1, WALNUT_C2)
    seat = box("Seat", (2.1, 2.0, 0.45), (0, 0, 2.05), 0.16, 4, cuts=2)
    puff(seat, 1.0, 1.0, 0.25)
    o.append(paint(seat, VELVET_G, var=0.04))
    o.append(paint(box("Apron", (2.0, 1.9, 0.3), (0, 0, 1.75), 0.05), WALNUT_C2))
    for sx in (-1, 1):
        o.append(paint(box("Stile", (0.22, 0.22, 2.8), (sx * 0.85, 0.85, 3.3), 0.06), WALNUT_C2))
    for k in range(3):
        o.append(paint(box("Slat", (0.24, 0.12, 1.6), (-0.5 + k * 0.5, 0.88, 3.4), 0.04), WALNUT_C))
    o.append(paint(box("Crest", (2.0, 0.28, 0.42), (0, 0.85, 4.55), 0.12, 4), WALNUT_C2))
    return o


@prop
def ReadingNook():
    o = []
    FAB = (130, 44, 52)
    o.append(paint(box("Base", (3.6, 3.2, 1.0), (0, 0, 1.1), 0.22), FAB))
    for sx in (-1, 1):
        a = box("Arm", (0.7, 3.0, 1.6), (sx * 1.6, -0.1, 2.1), 0.3, 5)
        o.append(paint(a, FAB, var=0.04))
        # the wings
        w = box("Wing", (0.5, 1.2, 2.6), (sx * 1.6, 1.0, 3.6), 0.28, 5)
        o.append(paint(w, FAB, var=0.04))
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.1, 0), (0.15, 0.6), (0, 0.6)], (sx * 1.45, sy * 1.3, 0), 12), WALNUT_C))
    o.append(paint(box("Back", (3.4, 0.8, 4.2), (0, 1.3, 3.2), 0.36, 6), FAB, var=0.04))
    c = box("Seat", (2.4, 2.5, 0.7), (0, -0.2, 1.9), 0.3, 6, cuts=2)
    puff(c, 1.2, 1.25, 0.3)
    o.append(paint(c, (150, 54, 62), var=0.04))
    # buttons in the back
    for i in range(3):
        for j in range(2):
            o.append(paint(sphere("Tuft", 0.08, (-0.8 + i * 0.8, 0.88, 3.0 + j * 1.0)), (90, 30, 36)))
    # a reading lamp beside it and a book on the arm
    o.append(paint(lathe("LampBase", [(0, 0), (0.45, 0), (0.4, 0.15), (0.06, 0.25), (0.06, 6.0), (0, 6.0)], (2.6, 0.6, 0), 20), BRASS_C, "chrome"))
    o.append(paint(lathe("Shade", [(0.65, 0), (0.42, 0.8), (0.41, 0.8), (0.64, 0.0)], (2.6, 0.6, 5.6), 24), (246, 232, 206), "glow"))
    o.append(paint(box("Book", (0.7, 1.0, 0.18), (1.6, -0.6, 2.98), 0.04, 2, rot=(0, 0, math.radians(12))), (40, 70, 120)))
    return o


@prop
def LobbyBench():
    o = []
    L = 6.6
    o.append(paint(box("Frame", (L, 2.0, 0.4), (0, 0, 1.3), 0.08), WALNUT_C2))
    for sx in (-1, 0, 1):
        o.append(paint(box("Leg", (0.3, 1.6, 1.1), (sx * (L / 2 - 0.4), 0, 0.55), 0.06), WALNUT_C))
    c = box("Cushion", (L - 0.2, 1.9, 0.6), (0, 0, 1.8), 0.25, 5, cuts=3)
    puff(c, (L - 0.2) / 2, 0.95, 0.2)
    o.append(paint(c, VELVET_B, var=0.04))
    for i in range(6):
        o.append(paint(sphere("Tuft", 0.07, (-2.7 + i * 1.08, 0, 2.12)), (36, 52, 104)))
    return o


@prop
def Beanbag():
    o = []
    b = sphere("Bag", 1.7, (0, 0, 1.3), scale=(1.0, 1.05, 0.72), sub=4)
    wobble(b, 0.12, 0.8, 2.0)
    o.append(paint(b, (240, 140, 60), var=0.06))
    d = sphere("Dent", 1.0, (0, -0.2, 2.15), scale=(1.0, 1.0, 0.35), sub=3)
    o.append(paint(d, (226, 124, 50), var=0.05))
    return o


@prop
def RoundTable():
    o = []
    o.append(paint(cyl("Top", 2.0, 0.22, (0, 0, 3.0), 40, 0.06), WALNUT_C2))
    o.append(paint(lathe("Pedestal", [(0, 0), (1.1, 0), (1.0, 0.2), (0.3, 0.4), (0.22, 1.2), (0.32, 2.4), (0.25, 2.9), (0, 2.9)], (0, 0, 0), 28), WALNUT_C))
    o.append(paint(lathe("Vase", [(0, 0), (0.2, 0), (0.3, 0.3), (0.12, 0.8), (0.18, 0.95), (0, 0.95)], (0, 0, 3.11), 20), (60, 120, 160)))
    for k in range(5):
        a = k / 5 * math.pi * 2
        o.append(paint(sphere("Bloom", 0.18, (math.cos(a) * 0.18, math.sin(a) * 0.18, 4.2 + (k % 2) * 0.15)), ROSE))
    return o


@prop
def BarCounter():
    o = []
    L = 8.0
    o.append(paint(box("Body", (L, 2.2, 3.4), (0, 0.2, 1.7), 0.08), WALNUT_C))
    for i in range(7):
        o.append(paint(box("Panel", (0.9, 0.06, 2.4), (-3.3 + i * 1.1, -0.92, 1.7), 0.04, 2), WALNUT_C2))
    o.append(paint(box("Top", (L + 0.4, 2.8, 0.28), (0, 0.1, 3.5), 0.08), MARBLE_C, var=0.03))
    o.append(paint(cyl("FootRail", 0.1, L, (0, -1.25, 0.7), 16, 0.02, rot=(0, math.radians(90), 0)), BRASS_C, "chrome"))
    # glasses and a tap
    for i in range(4):
        o.append(paint(cyl("Glass", 0.18, 0.5, (-2.6 + i * 0.45, 0.6, 3.9), 16, 0.01), (210, 236, 244), "glass"))
    o.append(paint(cyl("TapBase", 0.25, 0.3, (2.2, 0.7, 3.8), 16), BRASS_C, "chrome"))
    o.append(paint(box("Tap", (0.14, 0.14, 1.2), (2.2, 0.7, 4.4), 0.04), BRASS_C, "chrome"))
    o.append(paint(box("Spout", (0.12, 0.5, 0.12), (2.2, 0.5, 4.9), 0.04), BRASS_C, "chrome"))
    return o


@prop
def Bookcase():
    o = []
    W, D, H = 4.6, 1.5, 8.4
    o.append(paint(box("Back", (W, 0.15, H), (0, D / 2 - 0.08, H / 2), 0.03), WALNUT_C))
    for sx in (-1, 1):
        o.append(paint(box("Side", (0.22, D, H), (sx * (W / 2 - 0.11), 0, H / 2), 0.04), WALNUT_C2))
    for k in range(6):
        o.append(paint(box("Shelf", (W - 0.3, D - 0.1, 0.16), (0, 0, 0.3 + k * 1.6), 0.03), WALNUT_C2))
    o.append(paint(box("Crown", (W + 0.3, D + 0.2, 0.3), (0, 0, H + 0.1), 0.06), WALNUT_C2))
    cols = [(130, 40, 40), (40, 70, 120), (60, 110, 70), (200, 160, 80), (90, 60, 110), (220, 210, 190), (30, 30, 40)]
    rnd = random.Random(12)
    for k in range(5):
        x = -W / 2 + 0.35
        z0 = 0.38 + k * 1.6
        while x < W / 2 - 0.5:
            t = rnd.uniform(0.18, 0.34)
            h = rnd.uniform(0.9, 1.35)
            lean = 0 if rnd.random() > 0.15 else math.radians(rnd.uniform(-12, 12))
            o.append(paint(box("Book", (t, D - 0.4, h), (x + t / 2, -0.05, z0 + h / 2), 0.03, 1, rot=(0, lean, 0)), rnd.choice(cols), var=0.06))
            x += t + 0.02
            if rnd.random() < 0.08:
                x += 0.5
    return o


@prop
def Fountain():
    o = []
    o.append(paint(lathe("Basin", [(0, 0), (3.4, 0), (3.5, 0.2), (3.5, 1.4), (3.2, 1.5), (3.1, 0.4), (0, 0.4)], (0, 0, 0), 48), STONE, var=0.05))
    o.append(paint(cyl("Water", 3.1, 0.1, (0, 0, 1.15), 48, 0), (120, 190, 220), "glass"))
    o.append(paint(lathe("Stem", [(0, 0), (0.8, 0), (0.5, 0.6), (0.35, 2.5), (0.5, 2.8), (0, 2.8)], (0, 0, 0.4), 28), STONE, var=0.05))
    o.append(paint(lathe("Bowl2", [(0, 0), (0.4, 0), (1.6, 0.4), (1.7, 0.7), (1.5, 0.75), (0.3, 0.45), (0, 0.45)], (0, 0, 3.1), 36), STONE, var=0.05))
    o.append(paint(cyl("Water2", 1.5, 0.08, (0, 0, 3.72), 36, 0), (120, 190, 220), "glass"))
    o.append(paint(lathe("Top", [(0, 0), (0.3, 0), (0.18, 1.0), (0.4, 1.2), (0.25, 1.5), (0, 1.6)], (0, 0, 3.8), 24), STONE, var=0.05))
    # streams falling from the top bowl
    for k in range(6):
        a = k / 6 * math.pi * 2
        o.append(paint(box("Stream", (0.12, 0.12, 2.3), (math.cos(a) * 1.55, math.sin(a) * 1.55, 2.35), 0.05, 2), (200, 236, 250), "glass"))
    return o


@prop
def Statue():
    o = []
    o.append(paint(box("Plinth", (1.8, 1.8, 3.6), (0, 0, 1.8), 0.08), MARBLE_C, var=0.03))
    o.append(paint(box("Cap", (2.1, 2.1, 0.3), (0, 0, 3.75), 0.06), MARBLE_C, var=0.03))
    o.append(paint(lathe("Shoulders", [(0, 0), (0.9, 0), (1.0, 0.4), (0.8, 0.9), (0.35, 1.1), (0.3, 1.4), (0, 1.4)], (0, 0, 3.9), 32, sy=0.6), (236, 232, 226), var=0.03))
    o.append(paint(sphere("Head", 0.55, (0, 0, 5.75), scale=(0.85, 0.95, 1.1), sub=4), (236, 232, 226), var=0.03))
    o.append(paint(sphere("Nose", 0.12, (0, -0.5, 5.7), scale=(0.7, 1.0, 1.0)), (236, 232, 226)))
    hair = sphere("Hair", 0.58, (0, 0.08, 5.95), scale=(0.9, 0.95, 0.8), sub=3)
    wobble(hair, 0.06, 4.0, 1.0)
    o.append(paint(hair, (226, 222, 214), var=0.03))
    return o


@prop
def RoomDivider():
    o = []
    for i in range(3):
        x = -2.2 + i * 2.2
        rot = math.radians(14 if i == 1 else -14)
        o.append(paint(box("Frame", (2.1, 0.18, 6.0), (x, 0, 3.4), 0.05, 2, rot=(0, 0, rot)), WALNUT_C2))
        o.append(paint(box("Panel", (1.7, 0.2, 5.0), (x, 0, 3.5), 0.03, 2, rot=(0, 0, rot)), (238, 226, 200), var=0.03))
        # a painted branch on each panel
        o.append(paint(box("Branch", (1.2, 0.22, 0.06), (x, 0, 4.4 + i * 0.3), 0.02, 1, rot=(0, math.radians(20), rot)), (80, 50, 40)))
        for k in range(3):
            o.append(paint(sphere("Blossom", 0.1, (x - 0.4 + k * 0.4, -0.12, 4.5 + i * 0.3 + (k % 2) * 0.2)), ROSE))
        for sy in (-1, 1):
            o.append(paint(box("Foot", (0.2, 0.6, 0.4), (x, sy * 0.1, 0.2), 0.04), WALNUT_C))
    return o


@prop
def Planter():
    o = []
    L = 6.0
    o.append(paint(box("Box", (L, 1.6, 1.8), (0, 0, 0.9), 0.08), (230, 226, 218)))
    o.append(paint(box("Rim", (L + 0.2, 1.8, 0.2), (0, 0, 1.85), 0.05), (200, 196, 188)))
    h = box("Hedge", (L - 0.2, 1.4, 1.6), (0, 0, 2.6), 0.5, 6, cuts=6)
    wobble(h, 0.3, 2.6, 3.0)
    o.append(paint(h, (52, 112, 58), var=0.3))
    return o


@prop
def Chandelier():
    o = []
    # hangs from the ceiling: the model's floor is the floor, the crystals sit up high
    top = 11.6
    o.append(paint(cyl("Chain", 0.06, 2.0, (0, 0, top - 1.0), 8, 0), BRASS_C, "chrome"))
    o.append(paint(lathe("Hub", [(0, 0), (0.5, 0), (0.6, 0.3), (0.3, 0.8), (0.12, 1.2), (0, 1.2)], (0, 0, top - 3.2), 24), BRASS_C, "chrome"))
    for k in range(8):
        a = k / 8 * math.pi * 2
        x, y = math.cos(a) * 1.8, math.sin(a) * 1.8
        o.append(paint(tube("Arm", [(0, 0, top - 2.9), (x * 0.6, y * 0.6, top - 3.1), (x, y, top - 2.8)], 0.06, 8), BRASS_C, "chrome"))
        o.append(paint(cyl("Cup", 0.16, 0.2, (x, y, top - 2.7), 12), BRASS_C, "chrome"))
        o.append(paint(sphere("Flame", 0.14, (x, y, top - 2.45), scale=(1, 1, 1.6)), (255, 236, 180), "glow"))
        o.append(paint(sphere("Crystal", 0.1, (x * 0.8, y * 0.8, top - 3.5), scale=(1, 1, 2.2)), (230, 240, 255), "glass"))
    o.append(paint(sphere("Drop", 0.22, (0, 0, top - 3.6), scale=(1, 1, 1.8)), (230, 240, 255), "glass"))
    return o


@prop
def PendantLamp():
    o = []
    top = 11.6
    o.append(paint(cyl("Cord", 0.04, 4.0, (0, 0, top - 2.0), 8, 0), (30, 30, 34)))
    o.append(paint(lathe("Shade", [(0.2, 0), (1.3, -1.0), (1.32, -1.05), (0.22, 0.05)], (0, 0, top - 4.0), 32), (36, 70, 64)))
    o.append(paint(sphere("Bulb", 0.3, (0, 0, top - 4.85)), (255, 236, 190), "glow"))
    return o


@prop
def LanternPost():
    o = []
    o.append(paint(lathe("Base", [(0, 0), (0.7, 0), (0.6, 0.4), (0.2, 0.6), (0.14, 5.2), (0, 5.2)], (0, 0, 0), 24), (34, 36, 40)))
    o.append(paint(box("Cage", (1.0, 1.0, 1.5), (0, 0, 6.0), 0.06), (34, 36, 40)))
    o.append(paint(box("Glass", (0.86, 0.86, 1.3), (0, 0, 6.0), 0.02, 1), (255, 226, 160), "glow"))
    o.append(paint(lathe("Roof", [(0, 0), (0.85, 0), (0.1, 0.6), (0, 0.6)], (0, 0, 6.75), 4), (34, 36, 40)))
    return o


@prop
def NeonSign():
    o = []
    # a wall sign: OPEN in neon tubes on a dark board (lies flat against the wall, front = -Y)
    o.append(paint(box("Board", (5.2, 0.2, 2.0), (0, 0.1, 1.0), 0.08), (24, 26, 34)))

    def stroke(pts):
        o.append(paint(tube("Tube", [(x, -0.08, z) for x, z in pts], 0.08, 8), (255, 90, 120), "glow"))
    # O
    pts = [(-1.9 + 0.45 * math.cos(t / 16 * math.pi * 2), 1.0 + 0.6 * math.sin(t / 16 * math.pi * 2)) for t in range(17)]
    stroke(pts)
    # P
    stroke([(-0.9, 0.4), (-0.9, 1.6), (-0.45, 1.6), (-0.3, 1.35), (-0.45, 1.05), (-0.9, 1.05)])
    # E
    stroke([(0.5, 1.6), (0.05, 1.6), (0.05, 0.4), (0.5, 0.4)])
    stroke([(0.05, 1.0), (0.4, 1.0)])
    # N
    stroke([(0.9, 0.4), (0.9, 1.6), (1.55, 0.4), (1.55, 1.6)])
    o.append(paint(box("Underline", (3.6, 0.1, 0.1), (-0.15, -0.08, 0.2), 0.04), NEON_BLUE, "glow"))
    return o


@prop
def DJBooth():
    o = []
    o.append(paint(box("Desk", (6.0, 2.4, 3.4), (0, 0, 1.7), 0.1), (24, 26, 34)))
    o.append(paint(box("Front", (5.6, 0.1, 2.6), (0, -1.22, 1.8), 0.03, 1), NEON_BLUE, "glow"))
    o.append(paint(box("Top", (6.2, 2.6, 0.2), (0, 0, 3.5), 0.05), (40, 42, 52)))
    for sx in (-1, 1):
        o.append(paint(cyl("Deck", 0.75, 0.15, (sx * 1.6, 0.1, 3.68), 32), (30, 30, 34)))
        o.append(paint(cyl("Record", 0.65, 0.04, (sx * 1.6, 0.1, 3.78), 32), (14, 14, 16)))
        o.append(paint(cyl("Label", 0.2, 0.05, (sx * 1.6, 0.1, 3.8), 16), NEON_PINK))
    o.append(paint(box("Mixer", (1.1, 1.4, 0.3), (0, 0.1, 3.75), 0.05), (50, 52, 60)))
    for k in range(4):
        o.append(paint(box("Fader", (0.08, 0.6, 0.1), (-0.36 + k * 0.24, 0.1, 3.93), 0.02), NEON_GOLD, "glow"))
    for sx in (-1, 1):
        o.append(paint(box("Speaker", (1.4, 1.4, 4.6), (sx * 3.9, 0.2, 2.3), 0.1), (24, 26, 34)))
        for zz, r in ((1.4, 0.55), (3.3, 0.35)):
            o.append(paint(cyl("Cone", r, 0.12, (sx * 3.9, -0.52, zz), 24, 0.02, rot=(math.radians(90), 0, 0)), (60, 62, 70)))
    return o


@prop
def VRPod():
    o = []
    o.append(paint(cyl("Pad", 2.4, 0.3, (0, 0, 0.15), 48), (40, 44, 56)))
    o.append(paint(cyl("Ring", 2.2, 0.05, (0, 0, 0.33), 48, 0), NEON_BLUE, "glow"))
    # a curved rail on three posts
    for k in range(3):
        a = math.radians(-90 + (k - 1) * 70)
        o.append(paint(cyl("Post", 0.1, 3.4, (math.cos(a) * 2.0, math.sin(a) * 2.0 * -1, 1.9), 12), STEEL))
    pts = [(math.cos(math.radians(-90 + t)) * 2.0, -math.sin(math.radians(-90 + t)) * 2.0, 3.6) for t in range(-80, 81, 10)]
    o.append(paint(tube("Rail", pts, 0.1, 10), STEEL, "chrome"))
    o.append(paint(box("Headset", (0.9, 0.6, 0.5), (0, 1.9, 3.75), 0.15, 4), (240, 240, 244)))
    o.append(paint(box("Lens", (0.7, 0.1, 0.3), (0, 1.6, 3.75), 0.05, 2), NEON_BLUE, "glow"))
    return o


@prop
def MiniGolf():
    o = []
    o.append(paint(box("Green", (4.0, 9.0, 0.3), (0, 0, 0.15), 0.12), (70, 150, 80), var=0.08))
    for sx in (-1, 1):
        o.append(paint(box("Rail", (0.3, 9.0, 0.6), (sx * 2.0, 0, 0.3), 0.1), WALNUT_C2))
    for sy in (-1, 1):
        o.append(paint(box("Rail", (4.3, 0.3, 0.6), (0, sy * 4.5, 0.3), 0.1), WALNUT_C2))
    o.append(paint(box("Bump", (2.0, 1.2, 0.4), (0.6, 0.5, 0.4), 0.4, 6), (60, 136, 70)))
    o.append(paint(cyl("Hole", 0.3, 0.05, (0, 3.4, 0.31), 24, 0), (20, 20, 20)))
    o.append(paint(cyl("Flag", 0.04, 2.4, (0, 3.4, 1.5), 8), (240, 240, 240)))
    o.append(paint(box("Pennant", (0.8, 0.04, 0.5), (0.42, 3.4, 2.4), 0.02, 1), (220, 50, 50)))
    o.append(paint(sphere("Ball", 0.16, (-0.6, -3.2, 0.46)), (250, 250, 250)))
    return o


@prop
def TowelStack():
    o = []
    o.append(paint(box("Back", (2.6, 0.12, 4.2), (0, 0.84, 2.1), 0.03), (240, 238, 232)))
    for sx in (-1, 1):
        o.append(paint(box("Side", (0.14, 1.6, 4.2), (sx * 1.23, 0.1, 2.1), 0.03), (240, 238, 232)))
    o.append(paint(box("Top", (2.7, 1.7, 0.14), (0, 0.1, 4.25), 0.03), (240, 238, 232)))
    for k in range(3):
        o.append(paint(box("Board", (2.4, 1.5, 0.12), (0, 0, 0.6 + k * 1.3), 0.03), (220, 216, 208)))
        for j in range(3):
            t = box("Towel", (2.0, 1.2, 0.3), (0, -0.05, 0.85 + k * 1.3 + j * 0.3), 0.14, 4)
            o.append(paint(t, [(250, 250, 248), MINT, (250, 236, 220)][k], var=0.03))
    return o


@prop
def IceMachine():
    o = []
    o.append(paint(box("Body", (2.6, 2.4, 5.0), (0, 0.1, 2.5), 0.12), (210, 214, 220)))
    o.append(paint(box("Panel", (2.2, 0.1, 1.6), (0, -1.12, 4.0), 0.04, 2), (40, 70, 110)))
    o.append(paint(box("IceLabel", (1.4, 0.12, 0.4), (0, -1.15, 4.2), 0.03, 1), (180, 230, 255), "glow"))
    o.append(paint(box("Nook", (1.6, 0.6, 1.4), (0, -0.9, 2.2), 0.08), (60, 64, 72)))
    o.append(paint(box("Tray", (1.6, 0.8, 0.12), (0, -1.0, 1.5), 0.03), STEEL, "chrome"))
    for k in range(6):
        o.append(paint(box("Ice", (0.22, 0.22, 0.22), (-0.5 + (k % 3) * 0.4, -1.0 - (k // 3) * 0.2, 1.65), 0.06, 2), (220, 240, 250), "glass"))
    return o


@prop
def PhoneBooth():
    o = []
    W, D, H = 3.2, 3.2, 8.6
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Post", (0.3, 0.3, H), (sx * (W / 2 - 0.15), sy * (D / 2 - 0.15), H / 2), 0.05), CHERRY))
    o.append(paint(box("Roof", (W + 0.3, D + 0.3, 0.5), (0, 0, H + 0.1), 0.15), CHERRY))
    o.append(paint(box("Sign", (W - 0.4, 0.1, 0.45), (0, -D / 2 - 0.02, H - 0.5), 0.03, 1), (255, 240, 220), "glow"))
    o.append(paint(box("BackWall", (W - 0.3, 0.2, H - 1.0), (0, D / 2 - 0.15, (H - 1.0) / 2 + 0.2), 0.03), CHERRY))
    for sx in (-1, 1):
        for k in range(5):
            o.append(paint(box("Pane", (0.08, D - 0.5, 1.2), (sx * (W / 2 - 0.15), 0, 1.4 + k * 1.35), 0.02, 1), (200, 228, 240), "glass"))
    o.append(paint(box("Phone", (0.8, 0.4, 1.1), (0, D / 2 - 0.45, 4.4), 0.08), (30, 30, 34)))
    o.append(paint(box("Receiver", (0.2, 0.25, 0.9), (0.55, D / 2 - 0.55, 4.5), 0.08), (30, 30, 34)))
    o.append(paint(box("Floor", (W, D, 0.2), (0, 0, 0.1), 0.05), (60, 60, 64)))
    return o


@prop
def KeyRack():
    o = []
    # wall item: a board of brass hooks with room keys
    o.append(paint(box("Board", (3.4, 0.25, 2.4), (0, 0.12, 1.2), 0.06), WALNUT_C2))
    o.append(paint(box("Plate", (3.0, 0.1, 0.35), (0, -0.05, 2.15), 0.03), BRASS_C, "chrome"))
    for i in range(4):
        for j in range(2):
            x, z = -1.2 + i * 0.8, 1.3 - j * 0.9
            o.append(paint(cyl("Hook", 0.05, 0.3, (x, -0.1, z), 8, 0, rot=(math.radians(90), 0, 0)), BRASS_C, "chrome"))
            if (i + j) % 3 != 2:
                o.append(paint(box("Fob", (0.22, 0.06, 0.45), (x, -0.22, z - 0.35), 0.03, 2), [CHERRY, (40, 70, 120), (60, 110, 70)][(i + j) % 3]))
    return o


@prop
def RoomSafe():
    o = []
    o.append(paint(box("Body", (1.8, 1.6, 1.6), (0, 0, 0.8), 0.08), (50, 54, 62)))
    o.append(paint(box("Door", (1.5, 0.08, 1.3), (0, -0.82, 0.8), 0.03, 2), (70, 74, 84)))
    o.append(paint(box("Keypad", (0.5, 0.06, 0.6), (0.35, -0.88, 0.9), 0.02, 1), (30, 32, 36)))
    o.append(paint(box("Display", (0.4, 0.05, 0.12), (0.35, -0.92, 1.12), 0.01, 1), (120, 255, 160), "glow"))
    o.append(paint(cyl("Handle", 0.18, 0.12, (-0.3, -0.9, 0.8), 16, 0.02, rot=(math.radians(90), 0, 0)), STEEL, "chrome"))
    return o


@prop
def BikeRack():
    o = []
    for k in range(4):
        x = -2.4 + k * 1.6
        pts = [(x, 0.0, 0), (x, 0.0, 2.2), (x, -0.3, 2.6), (x, -0.9, 2.6), (x, -1.2, 2.2), (x, -1.2, 0)]
        o.append(paint(tube("Loop", bend_path(pts, 0.25, 4), 0.09, 8), STEEL, "chrome"))
    o.append(paint(box("Base", (6.4, 1.6, 0.12), (0, -0.6, 0.06), 0.03), (90, 90, 96)))
    # one bike leaning in
    for sy in (-1.8, 1.0):
        o.append(paint(lathe("Wheel", [(1.05, -0.06), (1.15, -0.06), (1.15, 0.06), (1.05, 0.06), (1.05, -0.06)], (0, 0, 0), 32), (24, 24, 26)))
        o[-1].rotation_euler = (0, math.radians(90), 0)
        o[-1].location = (-0.8, sy - 0.4, 1.15)
        bake_xform(o[-1])
    o.append(paint(tube("Frame", [(-0.8, -2.2, 1.15), (-0.8, -0.6, 2.3), (-0.8, 0.6, 1.15), (-0.8, -0.7, 1.2), (-0.8, -2.2, 1.15)], 0.08, 8), (40, 120, 170)))
    o.append(paint(box("Saddle", (0.3, 0.8, 0.18), (-0.8, 0.3, 2.6), 0.08), (30, 30, 30)))
    return o


@prop
def ParkBench():
    o = []
    L = 6.0
    for sx in (-1, 1):
        o.append(paint(tube("Side", [(sx * (L / 2 - 0.4), -0.9, 0), (sx * (L / 2 - 0.4), -0.7, 1.8), (sx * (L / 2 - 0.4), 0.6, 1.8), (sx * (L / 2 - 0.4), 0.8, 3.6)], 0.1, 8), (30, 32, 36)))
        o.append(paint(box("Foot", (0.2, 1.9, 0.18), (sx * (L / 2 - 0.4), -0.1, 0.09), 0.05), (30, 32, 36)))
    for k in range(4):
        o.append(paint(box("Slat", (L, 0.4, 0.14), (0, -0.7 + k * 0.45, 1.86), 0.04), CEDAR, var=0.06))
    for k in range(3):
        o.append(paint(box("BackSlat", (L, 0.12, 0.4), (0, 0.65 + k * 0.05, 2.4 + k * 0.48), 0.04, 2, rot=(math.radians(-15), 0, 0)), CEDAR, var=0.06))
    return o


@prop
def Tapestry():
    o = []
    # a woven wall hanging: front = -Y, hangs against the wall
    o.append(paint(cyl("Rod", 0.08, 4.4, (0, 0, 4.6), 12, 0.01, rot=(0, math.radians(90), 0)), BRASS_C, "chrome"))
    t = box("Cloth", (3.8, 0.1, 4.2), (0, 0.02, 2.45), 0.02, 1, cuts=8)
    wobble(t, 0.04, 1.5, 4.0)

    def g(p, c):
        # bands of colour and a diamond in the middle
        band = int((p.z + 10) * 1.6) % 4
        cols = [PLUM, (196, 120, 70), (220, 196, 150), (60, 100, 110)]
        base = Vector(tuple(x / 255 for x in cols[band]))
        if abs(p.x) + abs(p.z - 2.45) < 1.0:
            base = Vector((0.85, 0.7, 0.4))
        return base
    o.append(paint(t, (1, 1, 1), var=0.0, grad=g))
    for k in range(10):
        o.append(paint(box("Tassel", (0.06, 0.06, 0.4), (-1.7 + k * 0.38, 0.02, 0.15), 0.01, 1), (220, 196, 150)))
    return o


@prop
def Gumball():
    o = []
    o.append(paint(lathe("Stand", [(0, 0), (0.7, 0), (0.6, 0.3), (0.2, 0.5), (0.2, 3.0), (0.6, 3.3), (0, 3.3)], (0, 0, 0), 24), CHERRY))
    o.append(paint(box("Coin", (1.0, 0.9, 0.9), (0, 0, 3.7), 0.15, 4), CHERRY))
    o.append(paint(cyl("Knob", 0.2, 0.2, (0, -0.5, 3.7), 16, 0.02, rot=(math.radians(90), 0, 0)), BRASS_C, "chrome"))
    o.append(paint(sphere("Globe", 1.0, (0, 0, 5.0), sub=4), (220, 236, 244), "glass"))
    rnd = random.Random(3)
    for k in range(26):
        a, b = rnd.uniform(0, math.pi * 2), rnd.uniform(-0.6, 0.2)
        r = rnd.uniform(0, 0.75)
        o.append(paint(sphere("Gum", 0.15, (math.cos(a) * r, math.sin(a) * r, 4.9 + b), sub=2), rnd.choice([(255, 80, 80), (80, 200, 255), (255, 220, 60), (120, 220, 120), (240, 120, 220)])))
    o.append(paint(lathe("Cap", [(0, 0), (0.5, 0), (0.4, 0.3), (0, 0.4)], (0, 0, 5.9), 24), CHERRY))
    return o
