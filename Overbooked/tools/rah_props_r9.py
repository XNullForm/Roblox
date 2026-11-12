"""Round 9 props: the big build-mode catalogue (furniture, decor, lighting, fun, amenities, event gear).
Loaded by rah_props.py (exec) so they share its helpers and export. Front = -Y, floor = z 0, 1 unit = 1 stud.
"""

BRASS = (214, 176, 96)
WALNUT = (104, 64, 40)
OAK = (196, 146, 96)
LINEN = (236, 228, 214)
INKY = (40, 42, 50)
VELVET_G = (66, 122, 106)
VELVET_B = (54, 76, 140)
BLUSH = (226, 160, 150)
MUSTARD = (220, 168, 64)


def legs4(o, w, d, h, r=0.1, col=BRASS, group="chrome", inset=0.25, taper=True):
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (w / 2 - inset), sy * (d / 2 - inset)
            if taper:
                o.append(paint(lathe("Leg", [(0, 0), (r * 0.7, 0), (r, h), (0, h)], (x, y, 0), 12), col, group))
            else:
                o.append(paint(cyl("Leg", r, h, (x, y, h / 2), 12), col, group))


def tufted(o, name, size, loc, col, nx=3, nz=2, bevel=0.3):
    """A padded panel with button tufts."""
    b = box(name, size, loc, bevel, 6, cuts=3)
    puff(b, size[0] / 2, size[1] / 2, 0.15)
    o.append(paint(b, col, var=0.04))
    for i in range(nx):
        for j in range(nz):
            x = loc[0] - size[0] / 2 + size[0] * (i + 0.5) / nx
            z = loc[2] - size[2] / 2 + size[2] * (j + 0.5) / nz
            o.append(paint(sphere("Tuft", 0.07, (x, loc[1] - size[1] / 2 - 0.01, z), (1, 0.5, 1), 1), tuple(c * 0.7 for c in col)))


# ---------------------------------------------------------------- furniture

@prop
def Loveseat():
    o = []
    F = VELVET_G
    o.append(paint(box("Base", (5.4, 2.9, 0.8), (0, 0, 0.95), 0.22), F))
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.6, 2.9, 1.6), (sx * 2.45, 0, 1.4), 0.3, 5), F))
    tufted(o, "Back", (4.4, 0.6, 1.7), (0, 1.15, 2.15), F, 4, 2)
    for x in (-1.08, 1.08):
        c = box("Seat", (2.1, 2.2, 0.6), (x, -0.25, 1.6), 0.28, 6, cuts=2)
        puff(c, 1.05, 1.1, 0.3)
        o.append(paint(c, tuple(min(255, v * 1.08) for v in F), var=0.04))
    legs4(o, 5.0, 2.5, 0.55, 0.1)
    p = box("Pillow", (1.2, 0.5, 1.1), (-1.6, 0.55, 2.3), 0.3, 6, cuts=2)
    puff(p, 0.6, 0.25, 0.4)
    p.rotation_euler = (math.radians(-12), 0, math.radians(10))
    bake_xform(p)
    o.append(paint(p, MUSTARD, var=0.04))
    return o


@prop
def Sectional():
    o = []
    F = (196, 188, 176)
    o.append(paint(box("BaseA", (8.4, 3.0, 0.8), (0, 0, 0.9), 0.22), F))
    o.append(paint(box("BaseB", (3.0, 4.6, 0.8), (-2.7, -3.8, 0.9), 0.22), F))
    o.append(paint(box("BackA", (8.4, 0.8, 1.6), (0, 1.1, 2.0), 0.35, 5), F))
    o.append(paint(box("ArmR", (0.7, 3.0, 1.3), (3.85, 0, 1.6), 0.32, 5), F))
    o.append(paint(box("ArmB", (3.0, 0.7, 1.3), (-2.7, -5.75, 1.6), 0.32, 5), F))
    o.append(paint(box("BackB", (0.8, 4.6, 1.6), (-3.8, -3.8, 2.0), 0.35, 5), F))
    for x in (-2.6, 0.1, 2.75):
        c = box("Seat", (2.6, 2.2, 0.6), (x, -0.3, 1.6), 0.28, 6, cuts=2)
        puff(c, 1.3, 1.1, 0.3)
        o.append(paint(c, (210, 204, 194), var=0.04))
    c = box("SeatB", (2.2, 3.6, 0.6), (-2.5, -3.9, 1.6), 0.28, 6, cuts=2)
    puff(c, 1.1, 1.8, 0.3)
    o.append(paint(c, (210, 204, 194), var=0.04))
    for x, col in ((-2.9, VELVET_B), (-1.6, MUSTARD), (2.6, BLUSH)):
        p = box("Pillow", (1.2, 0.5, 1.1), (x, 0.5, 2.35), 0.3, 6, cuts=2)
        puff(p, 0.6, 0.25, 0.4)
        p.rotation_euler = (math.radians(-12), 0, math.radians(random.uniform(-12, 12)))
        bake_xform(p)
        o.append(paint(p, col, var=0.04))
    for x, y in ((-3.9, 1.2), (3.9, 1.2), (3.9, -1.2), (-3.9, -5.9), (-1.4, -5.9)):
        o.append(paint(cyl("Foot", 0.14, 0.5, (x, y, 0.25), 12), WALNUT))
    return o


@prop
def LoungeChair():
    o = []
    o.append(paint(box("Shell", (3.0, 3.0, 0.25), (0, 0, 1.3), 0.12, rot=(math.radians(-8), 0, 0)), WALNUT))
    o.append(paint(box("ShellBack", (3.0, 0.25, 2.6), (0, 1.35, 2.6), 0.12, rot=(math.radians(-12), 0, 0)), WALNUT))
    c = box("Seat", (2.6, 2.6, 0.5), (0, -0.1, 1.65), 0.24, 6, cuts=2)
    puff(c, 1.3, 1.3, 0.3)
    c.rotation_euler = (math.radians(-8), 0, 0)
    bake_xform(c)
    o.append(paint(c, (40, 40, 46), var=0.03))
    b = box("BackPad", (2.6, 0.45, 2.2), (0, 1.1, 2.75), 0.22, 6, cuts=2)
    puff(b, 1.3, 0.22, 0.3)
    b.rotation_euler = (math.radians(-12), 0, 0)
    bake_xform(b)
    o.append(paint(b, (40, 40, 46), var=0.03))
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.25, 2.4, 0.18), (sx * 1.45, 0.1, 2.3), 0.07), WALNUT))
    o.append(paint(cyl("Stem", 0.14, 1.1, (0, 0.1, 0.6), 16), CHROME, "chrome"))
    for a in range(5):
        t = a / 5 * math.pi * 2
        o.append(paint(box("Star", (1.4, 0.2, 0.12), (math.cos(t) * 0.65, 0.1 + math.sin(t) * 0.65, 0.12), 0.05, rot=(0, 0, t)), CHROME, "chrome"))
    return o


@prop
def BarStool():
    o = []
    s = cyl("Seat", 0.85, 0.35, (0, 0, 3.25), 32, 0.12)
    o.append(paint(s, (122, 40, 52), var=0.03))
    o.append(paint(cyl("Rim", 0.88, 0.08, (0, 0, 3.05), 32, 0.02), BRASS, "chrome"))
    for a in range(4):
        t = a / 4 * math.pi * 2 + math.pi / 4
        o.append(paint(tube("Leg", [(math.cos(t) * 0.6, math.sin(t) * 0.6, 3.05), (math.cos(t) * 0.9, math.sin(t) * 0.9, 0)], 0.06), BRASS, "chrome"))
    pts = [(math.cos(a / 24 * math.pi * 2) * 0.72, math.sin(a / 24 * math.pi * 2) * 0.72, 1.2) for a in range(25)]
    o.append(paint(tube("Ring", pts, 0.045), BRASS, "chrome"))
    return o


@prop
def DiningSet():
    o = []
    o.append(paint(cyl("Top", 2.3, 0.18, (0, 0, 2.8), 48, 0.06), (240, 236, 228), var=0.02))
    o.append(paint(cyl("Edge", 2.32, 0.06, (0, 0, 2.69), 48, 0.02), BRASS, "chrome"))
    o.append(paint(lathe("Pedestal", [(0, 0), (1.1, 0), (1.1, 0.12), (0.3, 0.4), (0.2, 2.7), (0, 2.7)], (0, 0, 0), 32), WALNUT))
    for a in range(4):
        t = a / 4 * math.pi * 2
        cx, cy = math.cos(t) * 3.1, math.sin(t) * 3.1
        ch = []
        ch.append(paint(box("ChairSeat", (1.6, 1.6, 0.3), (0, 0, 1.75), 0.12), WALNUT))
        c = box("Cush", (1.4, 1.4, 0.25), (0, 0, 1.97), 0.12, 4, cuts=1)
        puff(c, 0.7, 0.7, 0.3)
        ch.append(paint(c, VELVET_G, var=0.04))
        ch.append(paint(box("ChairBack", (1.5, 0.2, 1.7), (0, 0.72, 2.75), 0.1, rot=(math.radians(-8), 0, 0)), WALNUT))
        for sx in (-1, 1):
            for sy in (-1, 1):
                ch.append(paint(box("ChairLeg", (0.16, 0.16, 1.65), (sx * 0.64, sy * 0.64, 0.82), 0.04), WALNUT))
        for p in ch:
            p.rotation_euler = (0, 0, t + math.pi / 2)
            p.location = (cx, cy, 0)
            bake_xform(p)
            o.append(p)
    o.append(paint(cyl("Vase", 0.25, 0.7, (0, 0, 3.24), 16, 0.05), (90, 150, 190), "glass"))
    for i in range(5):
        a = i / 5 * math.pi * 2
        o.append(paint(sphere("Bloom", 0.22, (math.cos(a) * 0.22, math.sin(a) * 0.22, 3.75 + (i % 2) * 0.12)), (250, 200, 210)))
    return o


@prop
def ConsoleTable():
    o = []
    o.append(paint(box("Top", (5.2, 1.4, 0.16), (0, 0, 2.9), 0.04), (60, 62, 70)))
    o.append(paint(box("Shelf", (4.8, 1.2, 0.1), (0, 0, 0.6), 0.03), WALNUT))
    for sx in (-1, 1):
        o.append(paint(box("Frame", (0.12, 1.3, 2.82), (sx * 2.45, 0, 1.41), 0.03), BRASS, "chrome"))
    o.append(paint(lathe("Vase", [(0, 0), (0.28, 0), (0.42, 0.5), (0.2, 1.2), (0.24, 1.4), (0, 1.4)], (-1.6, 0, 2.98), 24), (236, 230, 220)))
    for i in range(4):
        o.append(paint(tube("Twig", [(-1.6, 0, 4.2), (-1.6 + random.uniform(-0.8, 0.8), random.uniform(-0.3, 0.3), 5.4 + random.uniform(0, 0.8))], 0.03), WALNUT))
    for i, c in enumerate(((200, 80, 70), (60, 100, 150), (230, 200, 120))):
        o.append(paint(box("Book", (1.1, 0.8, 0.18), (1.2, 0, 3.07 + i * 0.18), 0.03, 2, (0, 0, 0.15 * i)), c))
    o.append(paint(sphere("Orb", 0.3, (1.2, 0, 3.86)), BRASS, "chrome"))
    for x in (-1.2, 1.0):
        o.append(paint(box("Basket", (1.4, 1.0, 0.8), (x, 0, 1.06), 0.12), (200, 170, 120)))
    return o


@prop
def Ottoman():
    o = []
    b = lathe("Pouf", [(0, 0), (1.25, 0.05), (1.4, 0.5), (1.35, 1.2), (1.05, 1.5), (0, 1.55)], (0, 0, 0.2), 40)
    o.append(paint(b, MUSTARD, var=0.05))
    for a in range(8):
        t = a / 8 * math.pi * 2
        o.append(paint(sphere("Tuft", 0.07, (math.cos(t) * 0.6, math.sin(t) * 0.6, 1.73), (1, 1, 0.5), 1), (150, 110, 40)))
    o.append(paint(sphere("Tuft", 0.08, (0, 0, 1.76), (1, 1, 0.5), 1), (150, 110, 40)))
    o.append(paint(cyl("Base", 1.2, 0.2, (0, 0, 0.1), 32), BRASS, "chrome"))
    return o


@prop
def WorkDesk():
    o = []
    o.append(paint(box("Top", (5.6, 2.6, 0.18), (0, 0, 2.85), 0.05), OAK))
    o.append(paint(box("Drawers", (1.8, 2.4, 2.6), (1.8, 0, 1.4), 0.06), (240, 236, 228)))
    for z in (0.6, 1.45, 2.25):
        o.append(paint(box("Pull", (0.6, 0.08, 0.08), (1.8, -1.25, z), 0.02), BRASS, "chrome"))
    for sx in (-1,):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.18, 0.18, 2.78), (-2.6, sy * 1.1, 1.39), 0.04), (50, 52, 60)))
    # laptop
    o.append(paint(box("Base", (1.6, 1.1, 0.06), (-0.5, -0.3, 2.97), 0.02), (190, 194, 200), "chrome"))
    o.append(paint(box("Lid", (1.6, 0.06, 1.0), (-0.5, 0.25, 3.45), 0.02, rot=(math.radians(-14), 0, 0)), (190, 194, 200), "chrome"))
    o.append(paint(box("Screen", (1.45, 0.02, 0.85), (-0.5, 0.21, 3.45), 0.01, rot=(math.radians(-14), 0, 0)), (110, 170, 230), "glow"))
    # lamp
    o.append(paint(cyl("LampBase", 0.3, 0.1, (-2.1, 0.6, 2.99), 20), BRASS, "chrome"))
    o.append(paint(tube("LampArm", [(-2.1, 0.6, 3.0), (-2.1, 0.5, 4.0), (-1.7, 0.2, 4.4)], 0.04), BRASS, "chrome"))
    o.append(paint(lathe("Shade", [(0, 0), (0.12, 0), (0.42, -0.45), (0, -0.45)], (-1.7, 0.2, 4.55), 20), (40, 70, 60)))
    o.append(paint(sphere("Bulb", 0.12, (-1.7, 0.2, 4.15)), (255, 230, 180), "glow"))
    # chair
    ch = []
    c = box("Seat", (1.8, 1.8, 0.4), (0, 0, 1.75), 0.18, 5, cuts=1)
    puff(c, 0.9, 0.9, 0.25)
    ch.append(paint(c, INKY, var=0.03))
    ch.append(paint(box("Back", (1.7, 0.35, 1.8), (0, 0.85, 2.8), 0.16, rot=(math.radians(-8), 0, 0)), INKY))
    ch.append(paint(cyl("Post", 0.1, 1.3, (0, 0, 0.95), 12), CHROME, "chrome"))
    for a in range(5):
        t = a / 5 * math.pi * 2
        ch.append(paint(box("Spoke", (1.0, 0.16, 0.1), (math.cos(t) * 0.5, math.sin(t) * 0.5, 0.2), 0.04, rot=(0, 0, t)), CHROME, "chrome"))
    for p in ch:
        p.location = (-0.5, -2.0, 0)
        p.rotation_euler = (0, 0, math.radians(170))
        bake_xform(p)
        o.append(p)
    return o


@prop
def Dresser():
    o = []
    o.append(paint(box("Body", (5.0, 2.0, 3.0), (0, 0, 1.75), 0.08), (240, 236, 228)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.08, 0), (0.12, 0.3), (0, 0.3)], (sx * 2.3, sy * 0.8, 0), 12), BRASS, "chrome"))
    for j in range(3):
        z = 0.75 + j * 0.95
        for sx in (-1, 1):
            o.append(paint(box("Drawer", (2.3, 0.08, 0.82), (sx * 1.22, -1.02, z), 0.04, 2), (232, 226, 214)))
            o.append(paint(sphere("Knob", 0.09, (sx * 1.22, -1.1, z)), BRASS, "chrome"))
    o.append(paint(box("Top", (5.1, 2.1, 0.12), (0, 0, 3.29), 0.04), OAK))
    m = lathe("MirrorFrame", [(0, 0), (1.45, 0), (1.45, 0.14), (0, 0.14)], (0, 0, 0), 48)
    m.rotation_euler = (math.radians(90), 0, 0)
    m.location = (0, 0.7, 5.0)
    bake_xform(m)
    o.append(paint(m, BRASS, "chrome"))
    g = cyl("Mirror", 1.32, 0.04, (0, 0.62, 5.0), 48, 0, rot=(math.radians(90), 0, 0))
    o.append(paint(g, (210, 226, 236), "glass"))
    o.append(paint(lathe("Jar", [(0, 0), (0.25, 0), (0.3, 0.4), (0.12, 0.6), (0, 0.6)], (1.7, -0.2, 3.35), 16), (150, 190, 170)))
    return o


@prop
def Crib():
    o = []
    W = (246, 244, 240)
    o.append(paint(box("Mattress", (2.8, 4.6, 0.5), (0, 0, 1.6), 0.18, 4), (220, 236, 246), var=0.02))
    for sx in (-1, 1):
        o.append(paint(box("EndPost", (0.22, 0.22, 3.6), (sx * 1.55, -2.45, 1.8), 0.05), W))
        o.append(paint(box("EndPost", (0.22, 0.22, 3.6), (sx * 1.55, 2.45, 1.8), 0.05), W))
        o.append(paint(box("RailTop", (0.16, 5.0, 0.16), (sx * 1.55, 0, 3.3), 0.05), W))
        o.append(paint(box("RailLow", (0.16, 5.0, 0.16), (sx * 1.55, 0, 1.3), 0.05), W))
        for i in range(9):
            o.append(paint(cyl("Bar", 0.05, 2.0, (sx * 1.55, -2.0 + i * 0.5, 2.3), 8), W))
    for sy in (-1, 1):
        o.append(paint(box("Head", (3.2, 0.18, 2.4), (0, sy * 2.45, 2.4), 0.12), W))
    o.append(paint(box("Blanket", (2.6, 2.2, 0.15), (0, -0.8, 1.9), 0.07, 3, cuts=2), (250, 200, 200), var=0.03))
    bear = []
    bear.append(paint(sphere("BearBody", 0.35, (0.6, 1.4, 2.2), (1, 0.9, 1.1)), (200, 150, 100)))
    bear.append(paint(sphere("BearHead", 0.26, (0.6, 1.4, 2.7)), (200, 150, 100)))
    for sx in (-1, 1):
        bear.append(paint(sphere("BearEar", 0.09, (0.6 + sx * 0.18, 1.4, 2.92)), (170, 120, 80)))
    o += bear
    # mobile
    o.append(paint(tube("MobileArm", [(1.55, 2.45, 3.6), (1.55, 2.45, 5.0), (0, 1.2, 5.2)], 0.04), W))
    for i, c in enumerate(((255, 200, 120), (170, 210, 250), (250, 170, 190))):
        a = i / 3 * math.pi * 2
        o.append(paint(tube("Str", [(0, 1.2, 5.2), (math.cos(a) * 0.6, 1.2 + math.sin(a) * 0.6, 4.4)], 0.01), (90, 90, 90)))
        o.append(paint(sphere("Star", 0.18, (math.cos(a) * 0.6, 1.2 + math.sin(a) * 0.6, 4.3), (1, 1, 0.5)), c))
    return o


@prop
def PetBed():
    o = []
    r = lathe("Ring", [(0, 0), (1.5, 0), (1.75, 0.3), (1.7, 0.75), (1.4, 0.85), (1.25, 0.55), (0, 0.45)], (0, 0, 0), 40, 60, 0.8)
    o.append(paint(r, (120, 150, 190), var=0.05))
    c = box("Cush", (2.0, 1.7, 0.3), (0, 0, 0.55), 0.14, 4, cuts=2)
    puff(c, 1.0, 0.85, 0.3)
    o.append(paint(c, (236, 228, 214), var=0.03))
    o.append(paint(sphere("Bone", 0.12, (0.6, -0.2, 0.78), (2.6, 1, 1)), (246, 240, 230)))
    o.append(paint(cyl("Bowl", 0.4, 0.25, (2.1, -0.6, 0.13), 20), (200, 70, 70)))
    o.append(paint(cyl("Food", 0.32, 0.05, (2.1, -0.6, 0.25), 20, 0), (150, 100, 60)))
    return o


@prop
def ShowerChair():
    o = []
    o.append(paint(box("Seat", (2.0, 1.7, 0.18), (0, 0, 1.9), 0.08), (246, 246, 246)))
    for i in range(4):
        o.append(paint(cyl("Hole", 0.08, 0.02, (-0.6 + i * 0.4, 0, 2.0), 8, 0), (190, 200, 210)))
    o.append(paint(box("Back", (2.0, 0.16, 1.2), (0, 0.8, 2.7), 0.07), (246, 246, 246)))
    for sx in (-1, 1):
        o.append(paint(tube("ArmRail", [(sx * 1.0, 0.75, 2.2), (sx * 1.05, 0.7, 2.6), (sx * 1.05, -0.6, 2.6), (sx * 1.0, -0.65, 2.0)], 0.05), CHROME, "chrome"))
        for sy in (-1, 1):
            o.append(paint(tube("Leg", [(sx * 0.85, sy * 0.7, 1.85), (sx * 0.95, sy * 0.78, 0.1)], 0.06), CHROME, "chrome"))
            o.append(paint(cyl("Foot", 0.1, 0.12, (sx * 0.95, sy * 0.78, 0.06), 10), (60, 64, 72)))
    return o


@prop
def GrabBar():
    """A chrome safety rail. Raise it to hand height in build mode."""
    o = []
    o.append(paint(tube("Rail", bend_path([(-1.8, 0.25, 0.4), (-1.8, 0, 0.4), (1.8, 0, 0.4), (1.8, 0.25, 0.4)], 0.15), 0.07), CHROME, "chrome"))
    for sx in (-1, 1):
        o.append(paint(cyl("Flange", 0.2, 0.08, (sx * 1.8, 0.3, 0.4), 16, 0.02, rot=(math.radians(90), 0, 0)), CHROME, "chrome"))
    o.append(paint(box("Sign", (0.5, 0.05, 0.5), (0, 0.32, 1.0), 0.04), (60, 110, 200)))
    return o


# ---------------------------------------------------------------- decor

@prop
def WallArt():
    """Big abstract canvas in a slim oak frame; front -Y. Raise it onto a wall."""
    o = []
    o.append(paint(box("Frame", (6.2, 0.25, 4.2), (0, 0, 2.1), 0.04), OAK))
    o.append(paint(box("Canvas", (5.8, 0.06, 3.8), (0, -0.12, 2.1), 0.01), (244, 238, 226)))
    for c, x, z, w, h in (((214, 120, 90), -1.2, 2.6, 2.4, 2.0), ((60, 90, 130), 1.0, 1.6, 2.2, 1.6), ((230, 190, 110), 1.6, 3.0, 1.2, 1.0), ((120, 150, 120), -1.8, 1.2, 1.4, 1.0)):
        o.append(paint(box("Shape", (w, 0.04, h), (x, -0.17, z), 0.4, 6), c, var=0.06))
    return o


@prop
def Mirror():
    o = []
    rim = lathe("Rim", [(0, 0), (1.9, 0), (1.95, 0.08), (1.9, 0.18), (1.7, 0.18), (0, 0.1)], (0, 0, 0), 64)
    rim.rotation_euler = (math.radians(90), 0, 0)
    rim.location = (0, 0.05, 2.0)
    bake_xform(rim)
    o.append(paint(rim, BRASS, "chrome"))
    o.append(paint(cyl("Glass", 1.72, 0.03, (0, -0.12, 2.0), 64, 0, rot=(math.radians(90), 0, 0)), (214, 228, 238), "glass"))
    for a in range(16):
        t = a / 16 * math.pi * 2
        o.append(paint(box("Ray", (0.08, 0.06, 0.55), (math.cos(t) * 2.2, 0.0, 2.0 + math.sin(t) * 2.2), 0.02, 1, (0, -t + math.pi / 2, 0)), BRASS, "chrome"))
    return o


@prop
def FloorVase():
    o = []
    o.append(paint(lathe("Vase", [(0, 0), (0.55, 0), (0.85, 0.9), (0.75, 2.1), (0.35, 2.8), (0.42, 3.1), (0, 3.1)], (0, 0, 0), 36), (40, 60, 70), var=0.04))
    o.append(paint(lathe("Band", [(0, 0), (0.86, 0), (0.86, 0.1), (0, 0.1)], (0, 0, 1.3), 36), BRASS, "chrome"))
    for i in range(7):
        a = i / 7 * math.pi * 2
        top = (math.cos(a) * random.uniform(0.6, 1.3), math.sin(a) * random.uniform(0.6, 1.3), random.uniform(5.2, 6.6))
        o.append(paint(tube("Branch", [(0, 0, 2.9), (top[0] * 0.5, top[1] * 0.5, 4.2), top], 0.04), WALNUT))
        for k in range(4):
            p = Vector(top) * (0.65 + k * 0.1)
            o.append(paint(sphere("Blossom", 0.17, (p.x + random.uniform(-0.15, 0.15), p.y, p.z + random.uniform(-0.2, 0.2))), (250, 214, 226)))
    return o


@prop
def Sculpture():
    o = []
    o.append(paint(box("Plinth", (1.8, 1.8, 3.0), (0, 0, 1.5), 0.05), (232, 228, 220)))
    t = tube("Swirl", [(math.cos(a * 0.35) * (0.6 - a * 0.02), math.sin(a * 0.35) * (0.6 - a * 0.02), 3.1 + a * 0.12) for a in range(24)], 0.16)
    o.append(paint(t, BRASS, "chrome"))
    o.append(paint(sphere("Orb", 0.35, (0, 0, 6.1)), BRASS, "chrome"))
    return o


@prop
def Aquarium():
    o = []
    o.append(paint(box("Cabinet", (5.0, 1.8, 2.6), (0, 0, 1.3), 0.06), WALNUT))
    o.append(paint(box("Hood", (5.1, 1.9, 0.35), (0, 0, 5.9), 0.06), WALNUT))
    o.append(paint(box("Water", (4.7, 1.5, 3.0), (0, 0, 4.2), 0.02), (120, 200, 230), "glass"))
    o.append(paint(box("Sand", (4.6, 1.4, 0.3), (0, 0, 2.75), 0.1, cuts=3), (230, 210, 160)))
    for i in range(6):
        x = -1.9 + i * 0.75
        h = random.uniform(0.8, 2.0)
        o.append(paint(tube("Weed", [(x, 0.3, 2.9), (x + 0.2, 0.3, 2.9 + h * 0.5), (x - 0.1, 0.3, 2.9 + h)], 0.07), (70, 170, 100)))
    o.append(paint(sphere("Rock", 0.45, (1.4, 0.2, 3.0), (1.4, 1, 0.8)), (140, 140, 150)))
    for c, x, z in (((255, 150, 60), -1.0, 4.4), ((90, 170, 255), 0.6, 3.8), ((255, 220, 80), 1.6, 4.9), ((255, 120, 150), -0.2, 5.2)):
        f = sphere("Fish", 0.18, (x, -0.2, z), (2, 0.7, 1.1))
        o.append(paint(f, c, "glow"))
        o.append(paint(sphere("Tail", 0.12, (x + 0.38, -0.2, z), (0.6, 0.4, 1.3)), c, "glow"))
    o.append(paint(box("Light", (4.4, 0.6, 0.06), (0, 0, 5.7), 0.02), (200, 240, 255), "glow"))
    return o


@prop
def Fireplace():
    o = []
    S = (232, 228, 220)
    o.append(paint(box("Surround", (6.4, 1.4, 4.4), (0, 0.2, 2.2), 0.06), S))
    o.append(paint(box("Mantel", (7.0, 1.7, 0.3), (0, 0.05, 4.5), 0.06), WALNUT))
    o.append(paint(box("Firebox", (4.2, 1.0, 2.2), (0, -0.2, 1.6), 0.04), (30, 30, 34)))
    o.append(paint(box("Hearth", (6.8, 1.6, 0.3), (0, -0.6, 0.15), 0.05), (70, 72, 78)))
    for i in range(3):
        o.append(paint(cyl("Log", 0.18, 2.4, (0, -0.25 + i * 0.1, 0.85 + (i % 2) * 0.2), 12, 0.03, (0, math.radians(90), math.radians(-10 + i * 12))), (120, 74, 44)))
    for i in range(5):
        x = -1.2 + i * 0.6
        o.append(paint(lathe("Flame", [(0, 0), (0.25, 0.1), (0.18, 0.7), (0, 1.2 + random.uniform(0, 0.4))], (x, -0.3, 0.9), 12), (255, 150, 50), "glow"))
    o.append(paint(box("Glass", (4.2, 0.05, 2.2), (0, -0.72, 1.6), 0.01), (230, 220, 210), "glass"))
    for x in (-2.6, 2.6):
        o.append(paint(lathe("Candle", [(0, 0), (0.15, 0), (0.15, 0.7), (0, 0.7)], (x, 0, 4.65), 12), (246, 240, 230)))
        o.append(paint(sphere("Flame", 0.08, (x, 0, 5.45), (1, 1, 1.6)), (255, 200, 120), "glow"))
    return o


@prop
def GrandPiano():
    o = []
    B = (20, 20, 24)
    # the body: a rounded wing shape from a lofted outline
    out = []
    for i in range(25):
        t = i / 24
        out.append((-2.2 + 4.4 * t, 2.0 - 0.0))
    shape = [(-2.2, -1.6), (2.2, -1.6), (2.2, 0.4), (1.6, 2.4), (0.4, 3.6), (-1.2, 4.0), (-2.2, 3.6)]
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 2.3)) for x, y in shape]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in ext["geom"]:
        if isinstance(v, bmesh.types.BMVert):
            v.co.z += 1.1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    body = _new("Body", bm)
    m = body.modifiers.new("bv", "BEVEL")
    m.width = 0.12
    m.segments = 3
    apply_mods(body)
    o.append(paint(shade(body), B, var=0.02))
    lid = box("Lid", (3.6, 0.08, 4.4), (0, 0, 0), 0.04)
    lid.location = (0.3, 1.2, 4.7)
    lid.rotation_euler = (math.radians(-90 + 40), 0, math.radians(-10))
    bake_xform(lid)
    o.append(paint(lid, B))
    o.append(paint(tube("Prop", [(1.4, 0.8, 3.4), (1.2, 1.4, 5.3)], 0.04), B))
    o.append(paint(box("Keybed", (4.4, 1.0, 0.25), (0, -2.0, 2.45), 0.04), B))
    o.append(paint(box("Keys", (4.1, 0.75, 0.1), (0, -2.05, 2.62), 0.02), (248, 246, 240)))
    for i in range(20):
        if i % 7 not in (2, 6):
            o.append(paint(box("Black", (0.1, 0.45, 0.1), (-1.95 + i * 0.205 + 0.1, -1.95, 2.72), 0.02, 1), B))
    for x, y in ((-1.9, -1.4), (1.9, -1.4), (-0.8, 3.4)):
        o.append(paint(lathe("Leg", [(0, 0), (0.18, 0), (0.24, 2.3), (0, 2.3)], (x, y, 0), 16), B))
        o.append(paint(sphere("Caster", 0.15, (x, y, 0.1)), BRASS, "chrome"))
    o.append(paint(box("Lyre", (0.8, 0.12, 1.6), (0, -0.6, 1.0), 0.05), B))
    for x in (-0.25, 0, 0.25):
        o.append(paint(box("Pedal", (0.12, 0.4, 0.06), (x, -0.8, 0.25), 0.02), BRASS, "chrome"))
    o.append(paint(box("Bench", (2.4, 1.1, 0.35), (0, -3.6, 1.65), 0.1), B))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("BenchLeg", (0.14, 0.14, 1.5), (sx * 1.0, -3.6 + sy * 0.4, 0.75), 0.03), B))
    return o


@prop
def GrandfatherClock():
    o = []
    o.append(paint(box("Base", (2.0, 1.4, 2.2), (0, 0, 1.1), 0.06), WALNUT))
    o.append(paint(box("Waist", (1.6, 1.2, 3.6), (0, 0, 4.0), 0.05), WALNUT))
    o.append(paint(box("Hood", (2.1, 1.5, 2.2), (0, 0, 6.9), 0.06), WALNUT))
    o.append(paint(box("Crown", (2.3, 1.6, 0.3), (0, 0, 8.1), 0.08), WALNUT))
    o.append(paint(cyl("Face", 0.75, 0.06, (0, -0.76, 6.9), 40, 0, rot=(math.radians(90), 0, 0)), (246, 240, 226)))
    o.append(paint(cyl("Bezel", 0.82, 0.04, (0, -0.74, 6.9), 40, 0, rot=(math.radians(90), 0, 0)), BRASS, "chrome"))
    o.append(paint(box("Hand", (0.05, 0.03, 0.55), (0.1, -0.8, 7.1), 0.01, 1, (0, math.radians(-30), 0)), (20, 20, 20)))
    o.append(paint(box("Hand", (0.05, 0.03, 0.4), (-0.12, -0.8, 6.85), 0.01, 1, (0, math.radians(60), 0)), (20, 20, 20)))
    o.append(paint(box("Window", (1.0, 0.05, 2.6), (0, -0.62, 4.1), 0.02), (200, 214, 226), "glass"))
    o.append(paint(tube("Rod", [(0, -0.4, 5.3), (0, -0.4, 3.6)], 0.03), BRASS, "chrome"))
    o.append(paint(cyl("Bob", 0.32, 0.08, (0, -0.4, 3.4), 24, 0.02, rot=(math.radians(90), 0, 0)), BRASS, "chrome"))
    return o


@prop
def CoatRack():
    o = []
    o.append(paint(lathe("Pole", [(0, 0), (0.75, 0), (0.75, 0.1), (0.14, 0.25), (0.1, 6.4), (0.16, 6.6), (0, 6.7)], (0, 0, 0), 24), WALNUT))
    for a in range(6):
        t = a / 6 * math.pi * 2
        z = 6.0 if a % 2 == 0 else 5.4
        o.append(paint(tube("Hook", [(0, 0, z - 0.3), (math.cos(t) * 0.55, math.sin(t) * 0.55, z), (math.cos(t) * 0.7, math.sin(t) * 0.7, z + 0.2)], 0.04), BRASS, "chrome"))
    c = box("Coat", (1.0, 0.5, 2.6), (0.55, 0, 4.4), 0.25, 4, cuts=3)
    wobble(c, 0.06, 1.4, 2.0)
    o.append(paint(c, (160, 60, 50), var=0.05))
    o.append(paint(lathe("Hat", [(0, 0), (0.55, 0), (0.55, 0.05), (0.3, 0.08), (0.3, 0.45), (0, 0.45)], (-0.62, 0, 6.1), 20), (40, 40, 46)))
    return o


@prop
def SnakePlant():
    o = []
    o.append(paint(lathe("Pot", [(0, 0), (0.75, 0), (0.85, 1.6), (0.9, 1.7), (0, 1.7)], (0, 0, 0), 32), (236, 232, 222)))
    o.append(paint(cyl("Soil", 0.82, 0.05, (0, 0, 1.6), 24, 0), (70, 50, 36)))
    for i in range(11):
        a = i / 11 * math.pi * 2 + random.uniform(-0.2, 0.2)
        r = random.uniform(0.1, 0.5)
        h = random.uniform(2.4, 4.0)
        lf = leaf("Leaf", h, 0.45, 0)
        lf.rotation_euler = (math.radians(random.uniform(-8, 8)), math.radians(random.uniform(-10, 10)), a)
        lf.location = (math.cos(a) * r, math.sin(a) * r, 1.55)
        bake_xform(lf)
        o.append(paint(lf, (60, 120, 70), var=0.12, grad=lambda p, c: c * (0.7 + 0.3 * math.sin(p.z * 9))))
    return o


@prop
def IndoorPalm():
    o = []
    o.append(paint(lathe("Pot", [(0, 0), (0.9, 0), (1.15, 1.9), (1.2, 2.0), (0, 2.0)], (0, 0, 0), 32), (40, 42, 50)))
    o.append(paint(cyl("Soil", 1.1, 0.05, (0, 0, 1.9), 24, 0), (70, 50, 36)))
    trunk = [(0, 0, 1.9)]
    for k in range(1, 9):
        trunk.append((math.sin(k * 0.3) * 0.15, 0.05 * k, 1.9 + k * 0.62))
    o.append(paint(tube("Trunk", trunk, 0.17), (130, 100, 70)))
    top = Vector(trunk[-1])
    for i in range(9):
        a = i / 9 * math.pi * 2
        pts = []
        for k in range(7):
            t = k / 6
            pts.append(top + Vector((math.cos(a) * t * 2.6, math.sin(a) * t * 2.6, 0.6 * math.sin(t * math.pi * 0.8) - t * t * 1.6)))
        o.append(paint(tube("Frond", pts, 0.05), (70, 140, 70)))
        for k in range(1, 6):
            p = pts[k]
            for s in (-1, 1):
                d = Vector((-math.sin(a), math.cos(a), 0)) * s * (0.5 - k * 0.05)
                o.append(paint(tube("Leaflet", [p, p + d + Vector((0, 0, -0.2))], 0.03), (80, 160, 80)))
    return o


@prop
def FlowerStand():
    o = []
    o.append(paint(lathe("Stand", [(0, 0), (0.7, 0), (0.7, 0.1), (0.2, 0.3), (0.15, 3.0), (0.6, 3.1), (0.6, 3.25), (0, 3.25)], (0, 0, 0), 32), (236, 232, 222)))
    o.append(paint(lathe("Bowl", [(0, 0), (0.4, 0), (0.75, 0.5), (0.8, 0.6), (0, 0.6)], (0, 0, 3.25), 32), BRASS, "chrome"))
    cols = [(250, 140, 160), (255, 220, 120), (250, 250, 250), (200, 150, 230), (255, 170, 110)]
    for i in range(16):
        a = random.uniform(0, math.pi * 2)
        r = random.uniform(0, 0.75)
        z = 3.95 + random.uniform(0, 0.8) - r * 0.4
        o.append(paint(sphere("Bloom", random.uniform(0.18, 0.28), (math.cos(a) * r, math.sin(a) * r, z)), random.choice(cols)))
    for i in range(10):
        a = random.uniform(0, math.pi * 2)
        lf = leaf("Leaf", 1.0, 0.35, 0)
        lf.rotation_euler = (math.radians(55), 0, a)
        lf.location = (math.cos(a) * 0.5, math.sin(a) * 0.5, 3.8)
        bake_xform(lf)
        o.append(paint(lf, (70, 140, 80), var=0.1))
    return o


@prop
def DeskGlobe():
    o = []
    o.append(paint(lathe("Stand", [(0, 0), (0.9, 0), (0.9, 0.12), (0.2, 0.3), (0.15, 2.4), (0, 2.4)], (0, 0, 0), 24), WALNUT))
    o.append(paint(sphere("Globe", 1.0, (0, 0, 3.4), sub=4), (70, 130, 190), grad=lambda p, c: Vector((0.42, 0.62, 0.3)) if noise.noise(p * 1.6) > 0.15 else c))
    pts = [(math.cos(a / 30 * math.pi * 2) * 1.12, 0, 3.4 + math.sin(a / 30 * math.pi * 2) * 1.12) for a in range(23)]
    o.append(paint(tube("Meridian", pts, 0.05), BRASS, "chrome"))
    return o


# ---------------------------------------------------------------- lighting

@prop
def TableLamp():
    o = []
    o.append(paint(lathe("Base", [(0, 0), (0.45, 0), (0.6, 0.5), (0.5, 1.2), (0.15, 1.6), (0, 1.6)], (0, 0, 0), 32), (60, 110, 120)))
    o.append(paint(cyl("Neck", 0.05, 0.6, (0, 0, 1.9), 12), BRASS, "chrome"))
    o.append(paint(lathe("Shade", [(0.45, 0), (0.85, 0), (0.85, 0.02), (0.45, 1.0), (0.43, 1.0)], (0, 0, 2.0), 40), (246, 238, 220)))
    o.append(paint(sphere("Glow", 0.18, (0, 0, 2.4)), (255, 230, 180), "glow"))
    return o


@prop
def ArcLamp():
    o = []
    o.append(paint(box("Base", (1.3, 1.3, 0.5), (0, 0, 0.25), 0.08), (230, 228, 224)))
    pts = [(0, 0, 0.5)]
    for k in range(1, 13):
        t = k / 12
        pts.append((0, -math.sin(t * math.pi * 0.5) * 3.8, 0.5 + math.sin(t * math.pi * 0.75) * 7.4))
    o.append(paint(tube("Arc", pts, 0.09), CHROME, "chrome"))
    end = Vector(pts[-1])
    o.append(paint(sphere("Shade", 0.75, (end.x, end.y, end.z - 0.5), (1, 1, 0.6), 3), CHROME, "chrome"))
    o.append(paint(sphere("Glow", 0.32, (end.x, end.y, end.z - 0.8)), (255, 230, 180), "glow"))
    return o


@prop
def WallSconce():
    o = []
    o.append(paint(box("Plate", (0.7, 0.12, 1.3), (0, 0.4, 0.65), 0.05), BRASS, "chrome"))
    o.append(paint(tube("Arm", [(0, 0.35, 0.5), (0, 0.0, 0.5), (0, -0.25, 0.75)], 0.05), BRASS, "chrome"))
    o.append(paint(lathe("Shade", [(0.3, 0), (0.42, 0), (0.42, 0.02), (0.25, 0.7), (0.23, 0.7)], (0, -0.25, 0.75), 24), (246, 238, 220), "glass"))
    o.append(paint(sphere("Glow", 0.15, (0, -0.25, 1.05)), (255, 230, 180), "glow"))
    return o


# ---------------------------------------------------------------- fun

@prop
def Arcade():
    o = []
    B = (40, 30, 80)
    o.append(paint(box("Body", (2.6, 2.4, 6.4), (0, 0.2, 3.2), 0.06), B))
    o.append(paint(box("SideL", (0.12, 2.6, 6.6), (-1.35, 0.1, 3.3), 0.04), (230, 70, 120)))
    o.append(paint(box("SideR", (0.12, 2.6, 6.6), (1.35, 0.1, 3.3), 0.04), (230, 70, 120)))
    o.append(paint(box("Screen", (2.1, 0.05, 1.8), (0, -1.0, 4.4), 0.02, rot=(math.radians(-12), 0, 0)), (90, 220, 255), "glow"))
    o.append(paint(box("Marquee", (2.4, 0.06, 0.8), (0, -0.95, 6.0), 0.02), (255, 200, 80), "glow"))
    o.append(paint(box("Panel", (2.4, 1.0, 0.25), (0, -1.2, 3.2), 0.05, rot=(math.radians(15), 0, 0)), (24, 24, 30)))
    o.append(paint(cyl("Stick", 0.05, 0.4, (-0.6, -1.25, 3.5), 8), (30, 30, 30)))
    o.append(paint(sphere("Ball", 0.13, (-0.6, -1.25, 3.72)), (240, 60, 60)))
    for i, c in enumerate(((255, 220, 60), (80, 200, 255), (120, 240, 120))):
        o.append(paint(cyl("Btn", 0.12, 0.08, (0.2 + i * 0.35, -1.2, 3.36), 12), c))
    return o


@prop
def PoolTable():
    o = []
    o.append(paint(box("Felt", (4.8, 8.6, 0.2), (0, 0, 2.7), 0.02), (40, 120, 90)))
    for sx in (-1, 1):
        o.append(paint(box("RailL", (0.5, 9.4, 0.5), (sx * 2.65, 0, 2.85), 0.12), WALNUT))
    for sy in (-1, 1):
        o.append(paint(box("RailE", (5.8, 0.5, 0.5), (0, sy * 4.55, 2.85), 0.12), WALNUT))
    o.append(paint(box("Apron", (5.4, 9.0, 0.9), (0, 0, 2.15), 0.08), WALNUT))
    for sx in (-1, 1):
        for sy in (-1, 0, 1):
            o.append(paint(cyl("Pocket", 0.3, 0.12, (sx * 2.45, sy * 4.3, 3.0), 16, 0.02), (24, 24, 24)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.4, 0), (0.45, 0.3), (0.3, 1.0), (0.38, 1.7), (0, 1.7)], (sx * 2.2, sy * 3.8, 0), 20), WALNUT))
    cols = [(240, 220, 60), (40, 80, 200), (220, 50, 50), (120, 40, 160), (240, 120, 40), (30, 140, 70), (120, 40, 40), (20, 20, 20)]
    k = 0
    for row in range(4):
        for j in range(row + 1):
            o.append(paint(sphere("Ball", 0.18, ((j - row / 2) * 0.38, 2.0 + row * 0.33, 2.98)), cols[k % len(cols)]))
            k += 1
    o.append(paint(sphere("Cue", 0.18, (0, -2.2, 2.98)), (250, 250, 246)))
    o.append(paint(tube("Stick", [(0.4, -2.6, 3.0), (1.6, -6.5, 3.5)], 0.06), OAK))
    return o


@prop
def Jukebox():
    o = []
    body = lathe("Arch", [(0, 0), (1.4, 0), (1.4, 3.6), (1.2, 4.6), (0.6, 5.2), (0, 5.35)], (0, 0, 0), 48, 50, 0.55)
    o.append(paint(body, (150, 50, 40), var=0.03))
    o.append(paint(box("Window", (1.8, 0.1, 1.1), (0, -0.78, 3.6), 0.2), (255, 220, 150), "glow"))
    for i in range(5):
        o.append(paint(box("Tube", (0.1, 0.1, 3.0), (-1.1 + i * 0.55, -0.74, 2.0), 0.04), [(255, 120, 80), (255, 200, 80), (120, 220, 255), (255, 120, 200), (140, 255, 140)][i], "glow"))
    o.append(paint(box("Grille", (2.0, 0.08, 1.0), (0, -0.8, 1.0), 0.06), BRASS, "chrome"))
    o.append(paint(box("Base", (2.9, 1.7, 0.3), (0, 0, 0.15), 0.05), (40, 30, 30)))
    return o


@prop
def Foosball():
    o = []
    o.append(paint(box("Box", (3.0, 5.6, 1.1), (0, 0, 3.0), 0.06), (220, 70, 50)))
    o.append(paint(box("Field", (2.7, 5.3, 0.06), (0, 0, 3.0), 0.01), (50, 150, 80)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.3, 0.3, 2.5), (sx * 1.3, sy * 2.6, 1.25), 0.05), (40, 40, 46)))
    for i in range(6):
        y = -2.2 + i * 0.88
        o.append(paint(cyl("Rod", 0.05, 4.4, (0, y, 3.35), 8, 0, (0, math.radians(90), 0)), CHROME, "chrome"))
        o.append(paint(cyl("Handle", 0.1, 0.5, ((1 if i % 2 else -1) * 2.3, y, 3.35), 10, 0.02, (0, math.radians(90), 0)), (30, 30, 30)))
        for k in (-0.6, 0, 0.6):
            o.append(paint(box("Man", (0.18, 0.12, 0.5), (k, y, 3.2), 0.04), (240, 220, 60) if i % 2 else (60, 120, 220)))
    return o


@prop
def ClawMachine():
    o = []
    o.append(paint(box("Base", (3.0, 3.0, 2.6), (0, 0, 1.3), 0.08), (240, 120, 170)))
    o.append(paint(box("Glass", (2.8, 2.8, 3.2), (0, 0, 4.2), 0.03), (220, 240, 250), "glass"))
    o.append(paint(box("Top", (3.0, 3.0, 0.9), (0, 0, 6.25), 0.08), (240, 120, 170)))
    o.append(paint(box("Sign", (2.6, 0.06, 0.6), (0, -1.52, 6.25), 0.02), (255, 230, 120), "glow"))
    for i in range(12):
        c = [(250, 200, 120), (170, 220, 255), (255, 170, 200), (180, 240, 170)][i % 4]
        o.append(paint(sphere("Prize", 0.35, (random.uniform(-1, 1), random.uniform(-1, 1), 2.9 + random.uniform(0, 0.3)), (1, 1, 0.9), 2), c))
    o.append(paint(tube("Cable", [(0.3, 0.2, 5.8), (0.3, 0.2, 4.4)], 0.03), CHROME, "chrome"))
    for a in range(3):
        t = a / 3 * math.pi * 2
        o.append(paint(tube("Claw", [(0.3, 0.2, 4.4), (0.3 + math.cos(t) * 0.3, 0.2 + math.sin(t) * 0.3, 4.1), (0.3 + math.cos(t) * 0.2, 0.2 + math.sin(t) * 0.2, 3.85)], 0.04), CHROME, "chrome"))
    o.append(paint(cyl("Stick", 0.05, 0.4, (-0.6, -1.4, 2.8), 8), (30, 30, 30)))
    o.append(paint(sphere("Knob", 0.13, (-0.6, -1.4, 3.02)), (240, 60, 60)))
    return o


@prop
def MassageChair():
    o = []
    D = (52, 48, 46)
    o.append(paint(box("Base", (3.0, 4.0, 1.4), (0, 0, 0.8), 0.3), D))
    c = box("Seat", (2.4, 2.4, 0.6), (0, -0.2, 1.7), 0.28, 5, cuts=2)
    puff(c, 1.2, 1.2, 0.3)
    o.append(paint(c, (120, 84, 60), var=0.04))
    b = box("Back", (2.4, 0.9, 3.2), (0, 1.3, 3.2), 0.4, 5, cuts=2, rot=(math.radians(-20), 0, 0))
    o.append(paint(b, (120, 84, 60), var=0.04))
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.6, 2.8, 1.4), (sx * 1.5, 0.1, 2.0), 0.3, 5), D))
    o.append(paint(box("Legrest", (2.2, 0.8, 1.6), (0, -2.0, 1.1), 0.3, 5, rot=(math.radians(30), 0, 0)), D))
    o.append(paint(box("Remote", (0.3, 0.6, 0.12), (1.5, -0.8, 2.75), 0.05), (200, 200, 210)))
    o.append(paint(box("Lights", (0.08, 1.8, 0.08), (1.82, 0.1, 2.2), 0.02), (110, 200, 255), "glow"))
    return o


# ---------------------------------------------------------------- amenities

@prop
def CoffeeBar():
    o = []
    o.append(paint(box("Counter", (5.0, 2.2, 2.9), (0, 0, 1.45), 0.06), WALNUT))
    o.append(paint(box("Top", (5.2, 2.4, 0.15), (0, 0, 2.97), 0.04), (236, 232, 224)))
    o.append(paint(box("Machine", (1.6, 1.3, 1.6), (-1.2, 0.3, 3.85), 0.12), CHROME, "chrome"))
    o.append(paint(box("Group", (0.5, 0.3, 0.3), (-1.2, -0.45, 3.6), 0.05), (40, 40, 44)))
    o.append(paint(box("Display", (0.6, 0.03, 0.3), (-1.2, -0.37, 4.35), 0.02), (120, 230, 255), "glow"))
    for x in (0.4, 0.9, 1.4):
        o.append(paint(lathe("Cup", [(0, 0), (0.16, 0), (0.2, 0.3), (0, 0.3)], (x, -0.2, 3.05), 16), (248, 246, 240)))
    o.append(paint(lathe("Jar", [(0, 0), (0.3, 0), (0.32, 0.7), (0, 0.7)], (1.6, 0.6, 3.05), 20), (210, 226, 236), "glass"))
    o.append(paint(lathe("Beans", [(0, 0), (0.28, 0), (0.28, 0.45), (0, 0.45)], (1.6, 0.6, 3.08), 20), (90, 56, 34)))
    o.append(paint(box("Sign", (1.8, 0.1, 0.8), (0, 1.15, 4.4), 0.05), (40, 42, 50)))
    o.append(paint(box("SignText", (1.4, 0.04, 0.3), (0, 1.09, 4.45), 0.02), (255, 220, 160), "glow"))
    return o


@prop
def WaterCooler():
    o = []
    o.append(paint(box("Body", (1.4, 1.4, 3.6), (0, 0, 1.8), 0.15), (240, 240, 244)))
    o.append(paint(box("Recess", (0.9, 0.2, 0.9), (0, -0.65, 2.6), 0.1), (60, 64, 72)))
    for x, c in ((-0.2, (80, 140, 240)), (0.2, (240, 80, 80))):
        o.append(paint(box("Tap", (0.14, 0.2, 0.16), (x, -0.72, 3.0), 0.04), c))
    o.append(paint(lathe("Bottle", [(0, 0), (0.15, 0), (0.15, 0.3), (0.6, 0.6), (0.62, 2.0), (0.4, 2.3), (0, 2.35)], (0, 0, 3.6), 32), (150, 200, 240), "glass"))
    return o


@prop
def ATM():
    o = []
    o.append(paint(box("Body", (2.2, 1.8, 5.2), (0, 0, 2.6), 0.1), (60, 64, 76)))
    o.append(paint(box("Hood", (2.3, 0.8, 0.4), (0, -0.9, 4.6), 0.08), (60, 64, 76)))
    o.append(paint(box("Screen", (1.2, 0.05, 0.9), (0, -0.92, 3.6), 0.02, rot=(math.radians(-10), 0, 0)), (90, 200, 140), "glow"))
    o.append(paint(box("Keypad", (0.9, 0.5, 0.1), (0, -1.0, 2.8), 0.03, rot=(math.radians(30), 0, 0)), (180, 184, 190), "chrome"))
    o.append(paint(box("Slot", (0.9, 0.05, 0.1), (0, -0.93, 2.3), 0.02), (20, 20, 24)))
    o.append(paint(box("Logo", (1.6, 0.05, 0.4), (0, -0.92, 4.95), 0.02), (255, 210, 90), "glow"))
    return o


@prop
def LuggageCart():
    o = []
    o.append(paint(box("Deck", (2.4, 4.4, 0.2), (0, 0, 0.6), 0.06), (110, 40, 40)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Wheel", 0.25, 0.15, (sx * 1.0, sy * 1.8, 0.25), 16, 0.02, (0, math.radians(90), 0)), (30, 30, 30)))
    o.append(paint(tube("Arch", bend_path([(-1.1, -2.1, 0.7), (-1.1, -2.1, 5.2), (-1.1, 2.1, 5.2), (-1.1, 2.1, 0.7)], 0.5), 0.08), BRASS, "chrome"))
    o.append(paint(tube("Arch", bend_path([(1.1, -2.1, 0.7), (1.1, -2.1, 5.2), (1.1, 2.1, 5.2), (1.1, 2.1, 0.7)], 0.5), 0.08), BRASS, "chrome"))
    o.append(paint(tube("Bar", [(-1.1, 0, 5.2), (1.1, 0, 5.2)], 0.07), BRASS, "chrome"))
    o.append(paint(box("Case", (1.8, 2.8, 1.1), (0, -0.4, 1.3), 0.12), (60, 90, 140)))
    o.append(paint(box("Case", (1.4, 2.0, 0.9), (0.1, -0.3, 2.3), 0.12), (200, 120, 60)))
    o.append(paint(box("Bag", (1.2, 1.2, 1.4), (0, 1.5, 1.4), 0.3), (80, 120, 80)))
    return o


@prop
def FireExtinguisher():
    o = []
    o.append(paint(box("Stand", (1.2, 0.8, 0.12), (0, 0, 0.06), 0.03), (60, 60, 66)))
    o.append(paint(lathe("Tank", [(0, 0), (0.4, 0), (0.42, 0.1), (0.42, 2.1), (0.3, 2.4), (0.1, 2.5), (0, 2.5)], (0, 0, 0.12), 24), (210, 40, 40)))
    o.append(paint(box("Label", (0.5, 0.02, 0.7), (0, -0.42, 1.2), 0.01), (250, 250, 250)))
    o.append(paint(box("Valve", (0.25, 0.25, 0.35), (0, 0, 2.75), 0.04), (40, 40, 44)))
    o.append(paint(box("Lever", (0.6, 0.1, 0.08), (0.2, 0, 2.95), 0.02), (40, 40, 44)))
    o.append(paint(tube("Hose", [(0.15, 0, 2.7), (0.5, -0.2, 2.5), (0.48, -0.25, 1.2)], 0.05), (30, 30, 30)))
    o.append(paint(box("Sign", (0.8, 0.06, 0.8), (0, 0.3, 3.6), 0.02), (210, 40, 40)))
    return o


@prop
def FirstAid():
    o = []
    o.append(paint(box("Cabinet", (1.8, 0.7, 1.5), (0, 0, 0.75), 0.06), (246, 246, 246)))
    o.append(paint(box("CrossV", (0.3, 0.04, 0.9), (0, -0.37, 0.8), 0.01), (40, 160, 90)))
    o.append(paint(box("CrossL", (0.3, 0.04, 0.3), (-0.3, -0.37, 0.8), 0.01), (40, 160, 90)))
    o.append(paint(box("CrossR", (0.3, 0.04, 0.3), (0.3, -0.37, 0.8), 0.01), (40, 160, 90)))
    o.append(paint(box("Handle", (0.08, 0.1, 0.4), (0.75, -0.4, 0.8), 0.02), CHROME, "chrome"))
    return o


@prop
def LobbyBin():
    o = []
    o.append(paint(lathe("Bin", [(0, 0), (0.7, 0), (0.75, 2.6), (0, 2.6)], (0, 0, 0), 32), (40, 42, 50)))
    o.append(paint(lathe("Lid", [(0, 0), (0.8, 0), (0.8, 0.12), (0.5, 0.35), (0, 0.4)], (0, 0, 2.6), 32), BRASS, "chrome"))
    o.append(paint(box("Mouth", (0.8, 0.3, 0.12), (0, -0.55, 2.85), 0.05), (20, 20, 22)))
    return o


@prop
def BrochureStand():
    o = []
    o.append(paint(box("Base", (1.6, 1.0, 0.15), (0, 0, 0.08), 0.04), (60, 62, 70)))
    o.append(paint(box("Post", (1.4, 0.2, 4.6), (0, 0.3, 2.4), 0.04), (60, 62, 70)))
    cols = [(240, 120, 90), (90, 160, 220), (250, 210, 100), (130, 200, 140), (210, 140, 220), (240, 240, 240)]
    for row in range(3):
        z = 1.2 + row * 1.3
        o.append(paint(box("Shelf", (1.4, 0.5, 0.06), (0, 0.05, z), 0.02), CHROME, "chrome"))
        for k in range(2):
            o.append(paint(box("Leaflet", (0.55, 0.06, 0.9), (-0.32 + k * 0.64, 0.0, z + 0.45), 0.01, 1, (math.radians(-12), 0, 0)), cols[(row * 2 + k) % 6]))
    return o


@prop
def MiniFridge():
    o = []
    o.append(paint(box("Body", (1.8, 1.8, 2.4), (0, 0, 1.2), 0.12), (236, 236, 240)))
    o.append(paint(box("Door", (1.7, 0.1, 2.2), (0, -0.92, 1.2), 0.08), (244, 244, 248)))
    o.append(paint(box("Handle", (0.08, 0.12, 1.0), (0.7, -1.0, 1.4), 0.03), CHROME, "chrome"))
    o.append(paint(box("Kettle", (0.6, 0.6, 0.7), (-0.4, 0, 2.75), 0.2), (200, 70, 70)))
    for x in (0.3, 0.6):
        o.append(paint(lathe("Cup", [(0, 0), (0.14, 0), (0.17, 0.28), (0, 0.28)], (x, -0.2, 2.4), 16), (248, 246, 240)))
    return o


@prop
def LuggageRack():
    o = []
    for sx in (-1, 1):
        o.append(paint(tube("X1", [(sx * 1.4, -0.9, 0), (sx * 1.4, 0.9, 2.0)], 0.07), BRASS, "chrome"))
        o.append(paint(tube("X2", [(sx * 1.4, 0.9, 0), (sx * 1.4, -0.9, 2.0)], 0.07), BRASS, "chrome"))
    for y in (-0.9, 0.9):
        o.append(paint(tube("Rail", [(-1.4, y, 2.0), (1.4, y, 2.0)], 0.06), BRASS, "chrome"))
    for i in range(4):
        o.append(paint(box("Strap", (2.8, 0.25, 0.04), (0, -0.6 + i * 0.4, 2.02), 0.01), (110, 40, 40)))
    o.append(paint(box("Suitcase", (2.4, 1.4, 1.0), (0, 0, 2.6), 0.15), (60, 90, 140)))
    o.append(paint(box("Handle", (0.8, 0.12, 0.18), (0, 0, 3.2), 0.05), (30, 30, 30)))
    return o


@prop
def PartyKit():
    """Birthday balloons and a cake table."""
    o = []
    o.append(paint(cyl("Table", 1.3, 0.12, (0, 0, 2.6), 32, 0.03), (250, 246, 240)))
    o.append(paint(cyl("Stem", 0.12, 2.5, (0, 0, 1.3), 12), BRASS, "chrome"))
    o.append(paint(cyl("Foot", 0.7, 0.1, (0, 0, 0.05), 24), BRASS, "chrome"))
    o.append(paint(cyl("Cake", 0.7, 0.6, (0, 0, 2.97), 32, 0.06), (250, 220, 230)))
    o.append(paint(cyl("Cake2", 0.45, 0.45, (0, 0, 3.5), 32, 0.06), (250, 220, 230)))
    o.append(paint(cyl("Icing", 0.72, 0.08, (0, 0, 3.25), 32, 0.03), (240, 120, 160)))
    for a in range(5):
        t = a / 5 * math.pi * 2
        o.append(paint(cyl("Candle", 0.04, 0.3, (math.cos(t) * 0.25, math.sin(t) * 0.25, 3.87), 8, 0), (120, 180, 250)))
        o.append(paint(sphere("Flame", 0.05, (math.cos(t) * 0.25, math.sin(t) * 0.25, 4.07), (1, 1, 1.6)), (255, 200, 120), "glow"))
    cols = [(240, 80, 100), (90, 170, 250), (255, 210, 80), (150, 220, 120), (200, 130, 240)]
    for i in range(5):
        a = i / 5 * math.pi * 2
        top = (1.6 + math.cos(a) * 0.6, math.sin(a) * 0.6, 6.0 + i * 0.25)
        o.append(paint(tube("String", [(1.6, 0, 0.6), top], 0.015), (220, 220, 220)))
        o.append(paint(sphere("Balloon", 0.55, (top[0], top[1], top[2] + 0.6), (1, 1, 1.2)), cols[i]))
    o.append(paint(box("Weight", (0.4, 0.4, 0.5), (1.6, 0, 0.25), 0.1), BRASS, "chrome"))
    return o


@prop
def ChampagneBucket():
    """Honeymoon gift: champagne on ice and two glasses on a stand."""
    o = []
    o.append(paint(lathe("Stand", [(0, 0), (0.6, 0), (0.6, 0.08), (0.08, 0.2), (0.06, 2.6), (0.5, 2.7), (0, 2.7)], (0, 0, 0), 24), BRASS, "chrome"))
    o.append(paint(lathe("Bucket", [(0, 0), (0.5, 0), (0.62, 1.0), (0.66, 1.05), (0, 1.0)], (0, 0, 2.7), 32), CHROME, "chrome"))
    for i in range(8):
        o.append(paint(box("Ice", (0.2, 0.2, 0.2), (random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 3.7), 0.05), (230, 244, 252), "glass"))
    o.append(paint(lathe("Bottle", [(0, 0), (0.25, 0), (0.25, 1.0), (0.1, 1.4), (0.09, 1.8), (0, 1.8)], (0.1, 0.1, 3.0), 20), (30, 70, 40)))
    o.append(paint(cyl("Foil", 0.1, 0.3, (0.1, 0.1, 4.7), 12), (220, 190, 100), "chrome"))
    for x in (-0.9, -0.5):
        o.append(paint(lathe("Glass", [(0, 0), (0.25, 0), (0.03, 0.05), (0.03, 0.6), (0.14, 0.7), (0.14, 1.2), (0, 1.2)], (x, -0.3, 2.7), 16), (230, 240, 246), "glass"))
    for i in range(10):
        a = random.uniform(0, math.pi * 2)
        o.append(paint(box("Petal", (0.25, 0.18, 0.04), (math.cos(a) * random.uniform(0.6, 1.4), math.sin(a) * random.uniform(0.6, 1.4), 0.03), 0.02, 1, (0, 0, a)), (210, 40, 60)))
    return o
