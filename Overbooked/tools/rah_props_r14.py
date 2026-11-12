"""Round 14: the starter hotel's necessities, remade plain. Loaded by rah_props.py (exec) last, so these
replace the older Bed, BedMessy, Toilet, Shower and Nightstand (same names, footprints and use spots:
Catalog.CORE lie 3.3 / sit 2.49 / shower head (0, 0.5, 7.75) in Blender axes stay valid).
A roadside-inn look: pine and laminate, a wool blanket, a wooden toilet seat, a curtain shower.
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
"""

PINE = (204, 158, 104)
PINE_DK = (164, 118, 74)
LINEN = (240, 238, 230)
SHEET = (232, 230, 222)
WOOL = (64, 82, 118)
WOOL_DK = (52, 66, 96)
STRIPE = (232, 214, 170)
ACRYLIC = (238, 236, 228)
SEAM = (206, 204, 196)
CURTAIN = (156, 198, 212)
CURTAIN_DK = (128, 172, 190)
LAMINATE = (206, 170, 124)
LAMINATE_DK = (176, 140, 98)
PLASTIC = (236, 234, 226)


def r14_frame(o):
    """The pine bed frame, headboard and mattress shared by the clean and messy beds."""
    # side rails and end rails (a plain box frame on four square legs)
    o.append(paint(box("Frame", (5.8, 8.3, 0.75), (0, -0.05, 0.92), 0.08, 3, cuts=3), PINE, var=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.42, 0.42, 0.6), (sx * 2.62, sy * 3.86, 0.3), 0.05, 2), PINE_DK))
    # headboard: two square posts with ball-less flat caps, a solid board and a top rail
    for sx in (-1, 1):
        o.append(paint(box("Post", (0.48, 0.48, 4.4), (sx * 2.86, 4.05, 2.2), 0.07, 3), PINE_DK, var=0.02))
        o.append(paint(box("PostCap", (0.6, 0.6, 0.14), (sx * 2.86, 4.05, 4.45), 0.04, 2), PINE_DK))
    o.append(paint(box("Board", (5.3, 0.22, 1.9), (0, 4.08, 2.95), 0.05, 3, cuts=3), PINE, var=0.04))
    o.append(paint(box("TopRail", (5.3, 0.36, 0.38), (0, 4.08, 4.05), 0.08, 3), PINE_DK))
    o.append(paint(box("LowRail", (5.3, 0.3, 0.26), (0, 4.08, 1.86), 0.06, 2), PINE_DK))
    # thin mattress, plain white
    o.append(paint(box("Mattress", (5.35, 7.9, 0.95), (0, -0.05, 1.77), 0.3, 5, cuts=5), LINEN, var=0.015))


@prop
def Bed():
    """Starter bed: pine frame, thin mattress, one long pillow, a wool blanket with two stripes."""
    o = []
    r14_frame(o)
    # the sheet folded back over the blanket at the head end
    o.append(paint(box("Sheet", (5.6, 1.1, 1.18), (0, 1.0, 1.78), 0.3, 5, cuts=4), SHEET, var=0.02))
    blanket = box("Blanket", (5.65, 5.4, 1.12), (0, -1.75, 1.76), 0.32, 5, cuts=10)
    wobble(blanket, 0.035, 0.8, 2.0)
    o.append(paint(blanket, WOOL, var=0.03))
    for y in (-3.6, -3.1):
        s = box("Stripe", (5.68, 0.18, 1.14), (0, y, 1.765), 0.3, 4, cuts=2)
        o.append(paint(s, STRIPE, var=0.02))
    p = box("Pillow", (4.3, 1.25, 0.55), (0, 0, 0), 0.26, 6, cuts=3)
    puff(p, 2.15, 0.62, 0.32)
    p.location = (0, 3.05, 2.42)
    p.rotation_euler = (math.radians(-8), 0, 0)
    bake_xform(p)
    o.append(paint(p, LINEN, var=0.02))
    # a folded towel at the foot (a roadside-inn touch)
    o.append(paint(box("Towel", (1.6, 1.05, 0.34), (1.4, -3.2, 2.42), 0.12, 3), (246, 246, 242), var=0.02))
    o.append(paint(box("TowelBand", (1.62, 0.16, 0.36), (1.4, -3.45, 2.42), 0.1, 2), (120, 150, 190)))
    return o


@prop
def BedMessy():
    """The starter bed after a guest: blanket shoved aside, sheet rumpled, pillow knocked crooked."""
    o = []
    r14_frame(o)
    sheet = box("Sheet", (5.5, 6.2, 0.5), (0.1, 0.2, 2.2), 0.22, 4, cuts=8)
    wobble(sheet, 0.12, 1.1, 3.0)
    o.append(paint(sheet, SHEET, var=0.04))
    blanket = box("Blanket", (5.0, 4.0, 1.6), (0.6, -2.4, 1.9), 0.5, 5, (0, 0, math.radians(-9)), cuts=9)
    bake_xform(blanket)
    wobble(blanket, 0.3, 0.8, 5.0)
    o.append(paint(blanket, WOOL, var=0.05))
    heap = sphere("Heap", 1.1, (-1.6, -2.9, 2.35), (1.3, 1.0, 0.55), 3)
    wobble(heap, 0.18, 1.3, 8.0)
    o.append(paint(heap, WOOL_DK, var=0.05))
    p = box("Pillow", (4.1, 1.25, 0.55), (0, 0, 0), 0.26, 6, cuts=3)
    puff(p, 2.05, 0.62, 0.32)
    p.location = (-0.4, 2.7, 2.55)
    p.rotation_euler = (math.radians(-20), math.radians(6), math.radians(14))
    bake_xform(p)
    wobble(p, 0.05, 1.4, 2.0)
    o.append(paint(p, LINEN, var=0.03))
    return o


@prop
def Toilet():
    """Budget close-coupled toilet with a pine seat; back against +Y, seat top at ~1.55."""
    o = []
    bowl = lathe("Bowl", [(0, 0), (0.58, 0), (0.6, 0.06), (0.5, 0.45), (0.54, 0.9), (0.76, 1.2), (0.9, 1.36), (0.88, 1.44),
                          (0.76, 1.46), (0.66, 1.3), (0.36, 1.02), (0, 0.98)], (0, -0.35, 0), 36, 40, sy=1.3)
    o.append(paint(bowl, PLASTIC, var=0.01))
    o.append(paint(box("Neck", (1.25, 1.05, 1.15), (0, 0.55, 0.82), 0.32, 5), PLASTIC, var=0.01))
    seat = lathe("Seat", [(0.64, 1.46), (0.95, 1.46), (0.98, 1.5), (0.95, 1.57), (0.68, 1.57), (0.62, 1.52), (0.64, 1.46)], (0, -0.35, 0), 36, 40, sy=1.3)
    o.append(paint(seat, PINE, var=0.03))
    lid = lathe("Lid", [(0, 0), (0.88, 0), (0.93, 0.05), (0.91, 0.12), (0.78, 0.15), (0, 0.15)], (0, 0, 0), 36, 40, sy=1.3)
    lid.rotation_euler = (math.radians(-84), 0, 0)
    lid.location = (0, 0.84, 2.72)
    bake_xform(lid)
    o.append(paint(lid, PINE, var=0.03))
    o.append(paint(box("Hinge", (1.0, 0.24, 0.14), (0, 0.85, 1.56), 0.05, 3), (170, 172, 176), "chrome"))
    # a squared-off tank with a side lever
    o.append(paint(box("Tank", (1.9, 0.78, 1.65), (0, 1.38, 2.2), 0.1, 3), PLASTIC, var=0.01))
    o.append(paint(box("TankLid", (1.98, 0.86, 0.16), (0, 1.38, 3.1), 0.05, 2), PLASTIC, var=0.01))
    o.append(paint(box("Lever", (0.42, 0.08, 0.1), (-0.72, 0.95, 2.75), 0.03, 2), (190, 192, 196), "chrome"))
    o.append(paint(cyl("LeverHub", 0.09, 0.06, (-0.92, 0.98, 2.75), 12, 0.01, (math.pi / 2, 0, 0)), (190, 192, 196), "chrome"))
    # a plain plastic roll holder on the wall
    o.append(paint(box("RollArm", (0.16, 0.5, 0.16), (1.6, 1.55, 2.0), 0.05, 2), PLASTIC))
    o.append(paint(cyl("Roll", 0.28, 0.4, (1.6, 1.3, 1.95), 20, 0.04, (0, math.pi / 2, 0)), (250, 250, 248), var=0.02))
    return o


def r14_curtain(o, a, b, z0, z1, pleat=0.34, seed=0.0):
    """A pleated curtain from a to b (x, y): narrow panels zig-zagging along the line, rings on top."""
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay)
    n = max(2, int(L / pleat))
    yaw = math.atan2(by - ay, bx - ax)
    step = L / n
    for i in range(n):
        t = (i + 0.5) / n
        x, y = ax + (bx - ax) * t, ay + (by - ay) * t
        tilt = 0.75 if i % 2 == 0 else -0.75
        w = step / math.cos(tilt) + 0.04
        pnl = box("Curtain", (w, 0.05, z1 - z0), (x, y, (z0 + z1) / 2), 0.02, 1, (0, 0, yaw + tilt))
        c = CURTAIN if i % 2 == 0 else CURTAIN_DK
        o.append(paint(pnl, c, var=0.02))
        if i % 2 == 0:
            o.append(paint(cyl("Ring", 0.07, 0.05, (x, y, z1 + 0.06), 10, 0.01), (196, 198, 202), "chrome"))


@prop
def Shower():
    """Budget corner shower: acrylic tray and wall panels, a plain head, a curtain on an L rod
    (closed on the left, pulled back on the front). Back wall at +Y, side wall at +X."""
    random.seed(14)
    o = []
    o.append(paint(box("Tray", (5.2, 5.2, 0.34), (0, 0, 0.17), 0.1, 3), ACRYLIC, var=0.01))
    o.append(paint(box("TrayLip", (4.7, 4.7, 0.06), (0, 0, 0.33), 0.04, 2), (226, 224, 216)))
    o.append(paint(cyl("Drain", 0.28, 0.03, (0, 0, 0.36), 20, 0), (178, 180, 184), "chrome"))
    # two smooth wall panels with a seam where the sheets meet
    o.append(paint(box("PanelB", (5.2, 0.18, 7.4), (0, 2.51, 4.04), 0.03, 2), ACRYLIC, var=0.012))
    o.append(paint(box("PanelR", (0.18, 5.0, 7.4), (2.51, -0.09, 4.04), 0.03, 2), ACRYLIC, var=0.012))
    for z in (2.9, 5.4):
        o.append(paint(box("Seam", (5.0, 0.04, 0.06), (0, 2.41, z), 0.01, 1), SEAM))
        o.append(paint(box("Seam", (0.04, 4.8, 0.06), (2.41, -0.1, z), 0.01, 1), SEAM))
    o.append(paint(box("Corner", (0.12, 0.12, 7.4), (2.38, 2.38, 4.04), 0.03, 1), SEAM))
    # the head on a plain arm, one round mixer knob, a soap dish
    o.append(paint(tube("Arm", [(0, 2.42, 7.0), (0, 1.6, 7.4), (0, 0.7, 7.75)], 0.07, 8), (196, 198, 202), "chrome"))
    head = lathe("Head", [(0, 0), (0.12, 0), (0.36, 0.22), (0.38, 0.28), (0, 0.3)], (0, 0, 0), 24)
    head.rotation_euler = (math.radians(200), 0, 0)
    head.location = (0, 0.55, 7.95)
    bake_xform(head)
    o.append(paint(head, (196, 198, 202), "chrome"))
    o.append(paint(cyl("Knob", 0.3, 0.14, (0, 2.38, 3.9), 24, 0.04, (math.pi / 2, 0, 0)), (196, 198, 202), "chrome"))
    o.append(paint(box("KnobBar", (0.5, 0.1, 0.1), (0, 2.28, 3.9), 0.03, 2), (196, 198, 202), "chrome"))
    o.append(paint(box("Dish", (0.9, 0.55, 0.12), (1.9, 2.15, 4.4), 0.04, 2), PLASTIC))
    o.append(paint(box("Soap", (0.5, 0.32, 0.18), (1.9, 2.12, 4.53), 0.07, 3), (236, 214, 150)))
    # the L-shaped rod and the curtain
    rod = [(-2.55, 2.5, 7.55), (-2.55, -2.55, 7.55), (2.5, -2.55, 7.55)]
    o.append(paint(tube("Rod", bend_path(rod, 0.3), 0.06, 8), (196, 198, 202), "chrome"))
    r14_curtain(o, (-2.55, 2.4), (-2.55, -2.5), 1.0, 7.42, 0.32, 1.0)
    # the front: pulled back toward the left corner (a gap to step in on the right)
    r14_curtain(o, (-2.45, -2.55), (-0.6, -2.55), 1.0, 7.42, 0.2, 2.0)
    return o


@prop
def Nightstand():
    """Starter nightstand: a laminate cube with one drawer and an open shelf, a plain lamp, an alarm clock."""
    o = []
    o.append(paint(box("Plinth", (1.7, 1.5, 0.2), (0, 0.05, 0.1), 0.03, 2), LAMINATE_DK))
    o.append(paint(box("Body", (1.9, 1.7, 1.85), (0, 0, 1.12), 0.06, 3, cuts=2), LAMINATE, var=0.025))
    o.append(paint(box("Shelf", (1.6, 0.1, 0.78), (0, -0.82, 0.78), 0.02, 1), (120, 92, 64)))
    o.append(paint(box("Drawer", (1.66, 0.08, 0.62), (0, -0.86, 1.58), 0.04, 2), (216, 182, 136)))
    o.append(paint(box("Pull", (0.5, 0.08, 0.08), (0, -0.93, 1.6), 0.03, 2), (150, 152, 156), "chrome"))
    o.append(paint(box("Top", (1.98, 1.78, 0.08), (0, 0, 2.08), 0.03, 2), LAMINATE_DK))
    # lamp: white ceramic gourd, cream drum shade
    o.append(paint(lathe("LampBase", [(0, 0), (0.28, 0), (0.3, 0.04), (0.36, 0.3), (0.26, 0.62), (0.07, 0.75), (0.07, 1.05), (0, 1.05)], (0.35, 0.25, 2.12), 24), (240, 238, 232)))
    o.append(paint(lathe("Shade", [(0.5, 0), (0.52, 0.02), (0.5, 0.62), (0.47, 0.64), (0.48, 0.6), (0.49, 0.04), (0.47, 0.02)], (0.35, 0.25, 2.98), 28), (250, 236, 206), "glow"))
    # a little alarm clock
    o.append(paint(box("Clock", (0.6, 0.32, 0.34), (-0.5, -0.35, 2.29), 0.05, 2, (0, 0, 0.25)), (52, 54, 60)))
    o.append(paint(box("ClockFace", (0.44, 0.03, 0.18), (-0.47, -0.52, 2.3), 0.01, 1, (0, 0, 0.25)), (210, 70, 60)))
    return o
