"""Round 2 shop props (build mode). Loaded by rah_props.py (exec) so they share its helpers and export.
"""


@prop
def Armchair():
    """Single lounge chair, front at -Y."""
    o = []
    FAB = (232, 150, 92)
    o.append(paint(box("Base", (3.4, 3.0, 0.9), (0, 0, 1.0), 0.25), FAB))
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.7, 3.1, 1.9), (sx * 1.55, 0.05, 1.5), 0.32, 5), FAB))
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.09, 0), (0.13, 0.55), (0, 0.55)], (sx * 1.35, sy * 1.15, 0), 12), WOOD_DK))
    o.append(paint(box("Back", (3.3, 0.8, 2.5), (0, 1.15, 2.0), 0.36, 5), FAB))
    c = box("Seat", (2.3, 2.4, 0.7), (0, -0.2, 1.75), 0.3, 6, cuts=2)
    puff(c, 1.15, 1.2, 0.3)
    o.append(paint(c, (240, 162, 104), var=0.04))
    p = box("Pillow", (1.5, 0.6, 1.3), (0, 0.6, 2.75), 0.3, 6, cuts=2)
    puff(p, 0.75, 0.3, 0.4)
    p.rotation_euler = (math.radians(-14), 0, math.radians(6))
    bake_xform(p)
    o.append(paint(p, (250, 236, 210), var=0.04))
    return o


@prop
def TVStand():
    """Low wood cabinet with a flat TV, screen faces -Y."""
    o = []
    o.append(paint(box("Cab", (6.4, 1.8, 1.9), (0, 0, 1.2), 0.1), WOOD))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.2, 0.2, 0.3), (sx * 2.9, sy * 0.7, 0.15), 0.05, 2), WOOD_DK))
    for i, x in enumerate((-2.1, 0, 2.1)):
        o.append(paint(box("Door", (2.0, 0.1, 1.6), (x, -0.92, 1.2), 0.05, 2), (226, 214, 196) if i != 1 else (190, 126, 80)))
        o.append(paint(box("Pull", (0.5, 0.1, 0.08), (x, -1.0, 1.75), 0.03, 2), (212, 176, 96), "chrome"))
    o.append(paint(box("Body", (5.4, 0.25, 3.1), (0, 0.15, 4.0), 0.08), (32, 34, 40)))
    o.append(paint(box("Screen", (5.1, 0.04, 2.8), (0, 0.01, 4.0), 0.02), (60, 140, 200), "glow"))
    o.append(paint(box("Neck", (0.3, 0.3, 0.6), (0, 0.3, 2.35), 0.05), (40, 42, 48)))
    o.append(paint(box("Foot", (1.6, 0.9, 0.08), (0, 0.2, 2.18), 0.04), (40, 42, 48)))
    for i, c in enumerate(((230, 90, 80), (90, 160, 220))):
        o.append(paint(box("Book", (0.7, 0.5, 0.18), (2.2, -0.1, 2.24 + i * 0.18), 0.03, 2, (0, 0, 0.2 * i)), c))
    return o


@prop
def Wardrobe():
    o = []
    o.append(paint(box("Body", (4.2, 2.2, 7.6), (0, 0, 4.0), 0.12), (236, 228, 214)))
    o.append(paint(box("Plinth", (4.0, 2.0, 0.25), (0, 0, 0.12), 0.05), WOOD_DK))
    o.append(paint(box("Crown", (4.4, 2.4, 0.3), (0, 0, 7.9), 0.1), WOOD))
    for sx in (-1, 1):
        o.append(paint(box("Door", (1.95, 0.12, 6.8), (sx * 1.02, -1.1, 4.0), 0.06, 3), (244, 238, 228)))
        o.append(paint(box("Inset", (1.5, 0.08, 2.6), (sx * 1.02, -1.17, 5.6), 0.05, 2), (226, 218, 204)))
        o.append(paint(box("Inset", (1.5, 0.08, 2.6), (sx * 1.02, -1.17, 2.5), 0.05, 2), (226, 218, 204)))
        o.append(paint(box("Handle", (0.1, 0.14, 0.9), (sx * 0.25, -1.24, 4.1), 0.04, 2), (212, 176, 96), "chrome"))
    return o


@prop
def Bookshelf():
    random.seed(21)
    o = []
    for sx in (-1, 1):
        o.append(paint(box("Side", (0.2, 1.5, 7.0), (sx * 2.1, 0.1, 3.5), 0.05), WOOD))
    o.append(paint(box("Cap", (4.4, 1.5, 0.2), (0, 0.1, 6.9), 0.05), WOOD))
    o.append(paint(box("Kick", (4.4, 1.5, 0.3), (0, 0.1, 0.15), 0.05), WOOD))
    o.append(paint(box("Inner", (4.0, 0.15, 6.4), (0, 0.62, 3.55), 0.02), (120, 76, 46)))
    o.append(paint(box("Frame2", (4.4, 0.2, 7.0), (0, 0.75, 3.5), 0.05), WOOD))
    BOOK = [(214, 72, 64), (64, 120, 190), (240, 190, 70), (90, 160, 110), (180, 100, 170), (240, 236, 226), (60, 60, 70)]
    for z in (0.55, 2.15, 3.75, 5.35):
        o.append(paint(box("Shelf", (4.0, 1.3, 0.14), (0, -0.05, z), 0.03, 2), WOOD))
        x = -1.85
        while x < 1.75:
            w = random.uniform(0.18, 0.32)
            h = random.uniform(0.9, 1.35)
            if random.random() < 0.12 and x < 1.2:
                o.append(paint(lathe("Pot", [(0, 0), (0.22, 0), (0.28, 0.4), (0, 0.4)], (x + 0.3, -0.25, z + 0.07), 16), (230, 226, 220)))
                o.append(paint(sphere("Leaves", 0.36, (x + 0.3, -0.25, z + 0.7), (1, 1, 0.9), 2), (90, 156, 84)))
                x += 0.7
                continue
            tilt = random.uniform(-0.12, 0.12) if random.random() < 0.2 else 0
            b = box("Book", (w, 0.9, h), (x + w / 2, -0.2, z + 0.07 + h / 2), 0.03, 1, (0, tilt, 0))
            o.append(paint(b, random.choice(BOOK), var=0.06))
            x += w + 0.02
    return o


@prop
def PingPongTable():
    """9 x 5 table, net along Y (across the middle)."""
    o = []
    o.append(paint(box("Top", (9.0, 5.0, 0.22), (0, 0, 2.6), 0.05), (36, 96, 170)))
    o.append(paint(box("Line", (9.02, 0.08, 0.02), (0, 0, 2.72), 0.0), (250, 250, 250)))
    for sx in (-1, 1):
        o.append(paint(box("EdgeL", (0.08, 5.02, 0.02), (sx * 4.47, 0, 2.72), 0.0), (250, 250, 250)))
        o.append(paint(box("EdgeS", (9.02, 0.08, 0.02), (0, sx * 2.47, 2.72), 0.0), (250, 250, 250)))
    o.append(paint(box("Net", (0.06, 5.4, 0.55), (0, 0, 2.98), 0.02), (240, 240, 244)))
    o.append(paint(box("NetTop", (0.1, 5.4, 0.08), (0, 0, 3.27), 0.02), (250, 250, 250)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.25, 0.25, 2.5), (sx * 3.6, sy * 1.9, 1.25), 0.06, 2), (50, 52, 58)))
    o.append(paint(box("Brace", (7.4, 0.2, 0.2), (0, 0, 0.9), 0.05, 2), (50, 52, 58)))
    for (x, y, c) in ((2.5, -1.2, (210, 60, 60)), (-2.4, 1.0, (40, 40, 44))):
        o.append(paint(cyl("Paddle", 0.42, 0.06, (x, y, 2.75), 24, 0.02), c))
        o.append(paint(box("Grip", (0.15, 0.6, 0.12), (x, y - 0.6, 2.75), 0.05, 2), WOOD))
    o.append(paint(sphere("Ball", 0.1, (0.9, 0.6, 2.82)), (255, 160, 60)))
    return o


@prop
def VendingMachine():
    """Red snack machine with a real window cavity (snacks visible behind glass)."""
    random.seed(5)
    o = []
    RED = (214, 52, 58)
    o.append(paint(box("Back", (3.6, 1.8, 7.4), (0, 0.4, 3.7), 0.15), RED))
    o.append(paint(box("LeftS", (0.25, 0.85, 7.4), (-1.675, -0.88, 3.7), 0.08), RED))
    o.append(paint(box("RightP", (1.05, 0.85, 7.4), (1.275, -0.88, 3.7), 0.1), RED))
    o.append(paint(box("TopB", (2.4, 0.85, 0.6), (-0.45, -0.88, 7.1), 0.08), RED))
    o.append(paint(box("BotB", (2.4, 0.85, 1.8), (-0.45, -0.88, 0.9), 0.08), RED))
    o.append(paint(box("Cavity", (2.4, 0.06, 5.0), (-0.45, -0.52, 4.3), 0.01), (40, 44, 56)))
    SN = [(240, 190, 60), (90, 170, 230), (110, 200, 110), (240, 120, 160), (250, 240, 230), (240, 140, 60)]
    for r in range(5):
        z = 2.3 + r * 0.95
        o.append(paint(box("Rack", (2.3, 0.7, 0.06), (-0.45, -0.9, z - 0.32), 0.01, 1), (180, 184, 190), "chrome"))
        c = random.choice(SN)
        for k in range(4):
            x = -1.3 + k * 0.57
            o.append(paint(box("Snack", (0.42, 0.3, 0.55), (x, -0.95, z), 0.08, 2), c, var=0.05))
    o.append(paint(box("Glass", (2.4, 0.05, 5.0), (-0.45, -1.27, 4.3), 0.02), GLASS, "glass"))
    o.append(paint(box("Panel", (0.75, 0.08, 2.2), (1.25, -1.32, 4.8), 0.04), (40, 40, 48)))
    o.append(paint(box("Display", (0.55, 0.05, 0.3), (1.25, -1.37, 5.6), 0.02), (120, 240, 160), "glow"))
    for r in range(3):
        for k in range(2):
            o.append(paint(box("Key", (0.18, 0.06, 0.16), (1.12 + k * 0.26, -1.37, 4.9 - r * 0.28), 0.03, 1), (220, 222, 228)))
    o.append(paint(box("Tray", (2.0, 0.1, 0.6), (-0.45, -1.32, 1.1), 0.05), (30, 32, 38)))
    o.append(paint(box("Logo", (3.2, 0.06, 0.5), (0, -1.32, 7.05), 0.04), (255, 236, 200)))
    return o


@prop
def PottedTree():
    """Square planter with a round topiary on a trunk."""
    random.seed(9)
    o = []
    o.append(paint(box("Planter", (2.4, 2.4, 2.0), (0, 0, 1.0), 0.15), (240, 236, 228)))
    o.append(paint(box("Band", (2.5, 2.5, 0.25), (0, 0, 1.85), 0.08), WOOD))
    o.append(paint(box("Soil", (2.1, 2.1, 0.1), (0, 0, 1.96), 0.03), (70, 50, 36)))
    o.append(paint(tube("Trunk", [Vector((0, 0, 1.9)), Vector((0.1, 0.05, 3.4)), Vector((0, 0, 4.6))], 0.16, 8), (120, 84, 56)))
    for (x, y, z, r) in ((0, 0, 5.6, 1.5), (0.6, -0.4, 5.2, 0.9), (-0.6, 0.4, 6.1, 0.9), (0.2, 0.6, 6.4, 0.8)):
        s = sphere("Leaves", r, (x, y, z), (1, 1, 0.95), 3)
        wobble(s, 0.12, 1.6, x * 3 + z)
        o.append(paint(s, (84, 156, 76), var=0.1, grad=lambda p, c: c * (0.82 + 0.3 * min(max((p.z - 4.2) / 3, 0), 1))))
    return o


@prop
def SideTable():
    """Small round table with a vase of flowers."""
    random.seed(13)
    o = []
    o.append(paint(lathe("Top", [(0, 0), (1.0, 0), (1.05, 0.06), (1.05, 0.14), (1.0, 0.18), (0, 0.18)], (0, 0, 2.3), 40), WOOD))
    o.append(paint(lathe("Stem", [(0, 0), (0.6, 0), (0.62, 0.06), (0.14, 0.2), (0.12, 2.3), (0, 2.3)], (0, 0, 0), 28), (40, 40, 44)))
    o.append(paint(lathe("Vase", [(0, 0), (0.28, 0), (0.4, 0.35), (0.3, 0.75), (0.18, 0.95), (0.22, 1.05), (0, 1.0)], (0, 0, 2.48), 24), (110, 170, 190)))
    for i in range(7):
        a = i / 7 * math.tau
        tip = Vector((0.35 * math.cos(a), 0.35 * math.sin(a), 4.2 + random.uniform(-0.2, 0.25)))
        o.append(paint(tube("Stalk", [Vector((0, 0, 3.4)), tip], 0.03, 4), (90, 140, 70)))
        o.append(paint(sphere("Bloom", 0.2, tip, (1, 1, 0.8), 2), random.choice([(250, 120, 140), (255, 210, 90), (250, 250, 250), (240, 150, 90)])))
    return o
