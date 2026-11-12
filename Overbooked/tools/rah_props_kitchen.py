"""Round 10c: the kitchen (unlocked at hotel level 3). Loaded by rah_props.py (exec), sharing its helpers.
Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
  Stove          : a pro range, four burners, a pan and a stock pot (RAH_Kitchen cooks here)
  PrepCounter    : a steel prep table with a butcher block, a chopping board and fresh veg
  KitchenFridge  : a tall double-door steel fridge
  ServingCounter : the pass, lobby side out: walnut and emerald front, marble top, heat lamps, a ticket rail
                   (guests order here and collect their plates; RAH_Kitchen puts plates on its top)
  CafeTable      : a round bistro table with two chairs facing each other
"""

STEEL = (200, 204, 210)
STEEL_DK = (150, 154, 162)
CAST = (34, 34, 38)
WALNUT_K = (78, 50, 34)
EMERALD = (36, 82, 68)
MARBLE = (240, 236, 228)
BRASS_K = (214, 176, 96)


def knob(o, x, y, z):
    o.append(paint(cyl("Knob", 0.14, 0.14, (x, y, z), 20, 0.03, rot=(math.radians(90), 0, 0)), CAST))
    o.append(paint(box("KnobTick", (0.04, 0.03, 0.12), (x, y - 0.08, z + 0.04), 0.01), STEEL, "chrome"))


@prop
def Stove():
    o = []
    o.append(paint(box("Body", (4.2, 2.6, 2.55), (0, 0.1, 1.42), 0.06), STEEL, "chrome", var=0.02))
    o.append(paint(box("Kick", (4.0, 2.3, 0.2), (0, 0.2, 0.1), 0.03), CAST))
    o.append(paint(box("Top", (4.3, 2.85, 0.14), (0, 0, 2.76), 0.04), CAST))
    o.append(paint(box("Splash", (4.3, 0.3, 1.0), (0, 1.28, 3.3), 0.05), STEEL, "chrome", var=0.02))
    o.append(paint(box("SplashCap", (4.34, 0.42, 0.08), (0, 1.26, 3.82), 0.03), STEEL_DK, "chrome"))
    # the control strip with six knobs
    o.append(paint(box("Panel", (4.1, 0.08, 0.42), (0, -1.24, 2.43), 0.03), CAST))
    for i in range(6):
        knob(o, -1.75 + i * 0.7, -1.32, 2.43)
    # the oven door: a steel door, a smoked window, a long bar handle
    o.append(paint(box("Door", (3.7, 0.12, 1.7), (0, -1.25, 1.3), 0.05), STEEL, "chrome", var=0.02))
    o.append(paint(box("Window", (2.7, 0.05, 0.85), (0, -1.33, 1.35), 0.04), (40, 44, 52), "glass"))
    o.append(paint(tube("Handle", [(-1.55, -1.46, 1.98), (1.55, -1.46, 1.98)], 0.06), STEEL, "chrome"))
    for sx in (-1, 1):
        o.append(paint(box("HandlePost", (0.08, 0.16, 0.08), (sx * 1.5, -1.37, 1.98), 0.02), STEEL_DK, "chrome"))
    # four burners: a cast grate over a brass cap
    for bx, by in ((-0.98, -0.55), (0.98, -0.55), (-0.98, 0.58), (0.98, 0.58)):
        o.append(paint(lathe("Ring", [(0.42, 0), (0.52, 0), (0.52, 0.06), (0.42, 0.06), (0.42, 0)], (bx, by, 2.83), 32), CAST))
        for a in (0, 90):
            o.append(paint(box("Grate", (1.08, 0.08, 0.08), (bx, by, 2.9), 0.02, rot=(0, 0, math.radians(a + 45))), (24, 24, 26)))
        o.append(paint(cyl("Cap", 0.17, 0.08, (bx, by, 2.87), 20, 0.02), BRASS_K, "chrome"))
    # a pan on the front left, a stock pot on the back right
    o.append(paint(lathe("Pan", [(0, 0), (0.56, 0), (0.64, 0.2), (0.6, 0.2), (0.52, 0.05), (0, 0.05)], (-0.98, -0.55, 2.95), 40), (44, 44, 48)))
    o.append(paint(box("PanHandle", (0.95, 0.13, 0.07), (-1.85, -0.92, 3.08), 0.03, rot=(0, math.radians(-8), math.radians(22))), CAST))
    o.append(paint(lathe("Pot", [(0, 0), (0.5, 0), (0.52, 0.78), (0.48, 0.78), (0.46, 0.05), (0, 0.05)], (0.98, 0.58, 2.95), 40), STEEL, "chrome"))
    o.append(paint(lathe("Lid", [(0, 0.04), (0.53, 0), (0.5, 0.06), (0.1, 0.14), (0, 0.15)], (0.98, 0.58, 3.73), 40), STEEL_DK, "chrome"))
    o.append(paint(sphere("LidKnob", 0.09, (0.98, 0.58, 3.92)), CAST))
    for sx in (-1, 1):
        o.append(paint(box("PotEar", (0.18, 0.12, 0.08), (0.98 + sx * 0.6, 0.58, 3.55), 0.03), STEEL_DK, "chrome"))
    # feet
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Foot", 0.12, 0.18, (sx * 1.9, 0.15 + sy * 1.0, 0.09), 12), CAST))
    return o


@prop
def PrepCounter():
    o = []
    o.append(paint(box("Top", (5.0, 2.6, 0.12), (0, 0, 2.94), 0.03), STEEL, "chrome", var=0.02))
    o.append(paint(box("Lip", (5.0, 0.12, 0.3), (0, 1.25, 3.1), 0.03), STEEL, "chrome"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.14, 0.14, 2.88), (sx * 2.35, sy * 1.15, 1.44), 0.02), STEEL_DK, "chrome"))
            o.append(paint(cyl("Foot", 0.1, 0.1, (sx * 2.35, sy * 1.15, 0.05), 12), CAST))
    o.append(paint(box("Shelf", (4.8, 2.4, 0.08), (0, 0, 0.62), 0.02), STEEL, "chrome"))
    # stock on the shelf: two stacked bowls, a crate of potatoes
    for i in range(2):
        o.append(paint(lathe("Bowl", [(0, 0), (0.35, 0), (0.55, 0.32), (0.5, 0.32), (0.32, 0.04), (0, 0.04)], (-1.5, 0, 0.66 + i * 0.12), 32), STEEL, "chrome"))
    o.append(paint(box("Crate", (1.6, 1.1, 0.6), (1.3, 0.1, 0.96), 0.04), (176, 128, 76)))
    for i in range(7):
        o.append(paint(sphere("Potato", 0.2, (0.8 + (i % 4) * 0.32, -0.2 + (i // 4) * 0.45, 1.3), (1.2, 1, 0.85), 2), (170, 130, 80), var=0.08))
    # the butcher block and the board
    o.append(paint(box("Block", (2.2, 1.7, 0.2), (1.25, 0.05, 3.1), 0.04, cuts=2), (196, 146, 96), var=0.06))
    o.append(paint(box("Board", (1.5, 1.0, 0.08), (-1.3, -0.15, 3.04), 0.04), (238, 238, 232)))
    o.append(paint(box("Blade", (0.9, 0.16, 0.025), (-1.2, -0.45, 3.1), 0.01, rot=(0, 0, math.radians(-12))), STEEL, "chrome"))
    o.append(paint(box("KnifeHandle", (0.42, 0.12, 0.09), (-1.82, -0.32, 3.11), 0.03, rot=(0, 0, math.radians(-12))), CAST))
    for i in range(5):
        o.append(paint(cyl("Carrot", 0.09, 0.04, (-1.6 + i * 0.16, 0.05 + (i % 2) * 0.08, 3.1), 12, 0.01), (236, 132, 40)))
    # fresh veg on the block
    for x, y in ((0.55, -0.35), (0.85, -0.2), (0.62, 0.0)):
        o.append(paint(sphere("Tomato", 0.21, (x, y, 3.4), (1, 1, 0.88)), (214, 52, 40), var=0.04))
        o.append(paint(box("Stem", (0.1, 0.1, 0.05), (x, y, 3.6), 0.02), (70, 130, 50)))
    o.append(paint(sphere("Lettuce", 0.42, (1.55, 0.25, 3.5), (1, 1, 0.8)), (130, 196, 84), var=0.08))
    o.append(paint(sphere("Onion", 0.2, (2.05, -0.3, 3.4)), (226, 196, 150)))
    o.append(paint(lathe("MixBowl", [(0, 0), (0.25, 0), (0.48, 0.35), (0.44, 0.35), (0.23, 0.04), (0, 0.04)], (-0.1, 0.55, 3.0), 32), STEEL, "chrome"))
    # a utensil rail along the back with three hanging tools
    o.append(paint(tube("Rail", [(-2.3, 1.2, 4.25), (2.3, 1.2, 4.25)], 0.04), STEEL, "chrome"))
    for sx in (-1, 1):
        o.append(paint(box("RailPost", (0.06, 0.06, 1.2), (sx * 2.3, 1.2, 3.65), 0.01), STEEL_DK, "chrome"))
    for i, x in enumerate((-1.2, -0.4, 0.5)):
        o.append(paint(tube("Hook", [(x, 1.2, 4.25), (x, 1.14, 4.0)], 0.025), STEEL_DK, "chrome"))
        if i == 0:
            o.append(paint(lathe("Ladle", [(0, 0), (0.18, 0.02), (0.2, 0.12), (0, 0.12)], (x, 1.14, 3.3), 20), STEEL, "chrome"))
            o.append(paint(box("LadleStick", (0.04, 0.04, 0.6), (x, 1.14, 3.72), 0.01), STEEL, "chrome"))
        elif i == 1:
            o.append(paint(box("Spatula", (0.26, 0.03, 0.34), (x, 1.14, 3.45), 0.02), CAST))
            o.append(paint(box("SpatStick", (0.05, 0.04, 0.42), (x, 1.14, 3.8), 0.01), CAST))
        else:
            o.append(paint(lathe("Whisk", [(0, 0), (0.1, 0.1), (0.12, 0.3), (0.05, 0.5), (0, 0.52)], (x, 1.14, 3.38), 12), STEEL, "chrome"))
            o.append(paint(box("WhiskStick", (0.05, 0.05, 0.3), (x, 1.14, 4.0), 0.01), CAST))
    return o


@prop
def KitchenFridge():
    o = []
    o.append(paint(box("Body", (3.4, 2.5, 6.7), (0, 0.05, 3.55), 0.06), STEEL_DK, "chrome", var=0.02))
    o.append(paint(box("Kick", (3.2, 2.3, 0.22), (0, 0.15, 0.11), 0.03), CAST))
    for sx in (-1, 1):
        o.append(paint(box("Door", (1.66, 0.12, 6.0), (sx * 0.85, -1.24, 3.45), 0.05), STEEL, "chrome", var=0.02))
        o.append(paint(tube("Handle", [(sx * 0.2, -1.5, 2.4), (sx * 0.2, -1.5, 5.0)], 0.06), STEEL, "chrome"))
        for z in (2.5, 4.9):
            o.append(paint(box("HandlePost", (0.08, 0.2, 0.08), (sx * 0.2, -1.38, z), 0.02), STEEL_DK, "chrome"))
        o.append(paint(box("Gasket", (1.6, 0.04, 0.06), (sx * 0.85, -1.31, 0.48), 0.01), CAST))
    o.append(paint(box("Gap", (0.05, 0.06, 6.0), (0, -1.26, 3.45), 0.01), CAST))
    # the top grille and a little blue temperature display
    o.append(paint(box("Grille", (3.2, 0.08, 0.5), (0, -1.24, 6.72), 0.03), CAST))
    for i in range(10):
        o.append(paint(box("Slat", (0.14, 0.04, 0.38), (-1.35 + i * 0.3, -1.29, 6.72), 0.01), STEEL_DK, "chrome"))
    o.append(paint(box("Display", (0.7, 0.06, 0.3), (-0.85, -1.31, 6.05), 0.03), CAST))
    o.append(paint(box("Glow", (0.56, 0.04, 0.18), (-0.85, -1.35, 6.05), 0.01), (120, 220, 255), "glow"))
    o.append(paint(box("Badge", (0.6, 0.03, 0.16), (0.85, -1.31, 6.05), 0.02), BRASS_K, "chrome"))
    return o


@prop
def ServingCounter():
    o = []
    o.append(paint(box("Body", (5.6, 2.2, 3.15), (0, 0.1, 1.62), 0.05), WALNUT_K, var=0.04))
    o.append(paint(box("Plinth", (5.7, 2.3, 0.35), (0, 0.1, 0.17), 0.04), (28, 30, 34)))
    # the guest face: an emerald inset in a brass frame, with three brass bars
    o.append(paint(box("Inset", (4.9, 0.06, 2.0), (0, -1.02, 1.7), 0.02), EMERALD))
    for z in (0.68, 2.72):
        o.append(paint(box("Brass", (5.0, 0.08, 0.07), (0, -1.06, z), 0.02), BRASS_K, "chrome"))
    for x in (-2.48, 2.48):
        o.append(paint(box("Brass", (0.07, 0.08, 2.1), (x, -1.06, 1.7), 0.02), BRASS_K, "chrome"))
    for x in (-1.2, 0, 1.2):
        o.append(paint(box("Rib", (0.06, 0.06, 1.9), (x, -1.07, 1.7), 0.02), BRASS_K, "chrome"))
    # the marble pass
    o.append(paint(box("Top", (5.9, 2.6, 0.18), (0, 0.0, 3.28), 0.05), MARBLE, var=0.02))
    o.append(paint(box("Bead", (5.9, 0.08, 0.08), (0, -1.27, 3.17), 0.02), BRASS_K, "chrome"))
    # heat lamps on a brass gantry
    for sx in (-1, 1):
        o.append(paint(tube("Post", [(sx * 2.7, 0.95, 3.37), (sx * 2.7, 0.95, 5.75)], 0.07), BRASS_K, "chrome"))
    o.append(paint(tube("Bar", [(-2.7, 0.95, 5.75), (2.7, 0.95, 5.75)], 0.07), BRASS_K, "chrome"))
    for x in (-1.4, 1.4):
        o.append(paint(tube("Drop", [(x, 0.95, 5.75), (x, 0.3, 5.75), (x, 0.3, 5.35)], 0.04), BRASS_K, "chrome"))
        o.append(paint(lathe("Shade", [(0.12, 0.42), (0.18, 0.42), (0.55, 0), (0.5, 0), (0.12, 0.36)], (x, 0.3, 4.95), 32), BRASS_K, "chrome"))
        o.append(paint(sphere("Glow", 0.18, (x, 0.3, 5.05)), (255, 170, 90), "glow"))
    # the ticket rail with orders on it
    o.append(paint(box("TicketRail", (4.6, 0.1, 0.12), (0, 0.95, 4.65), 0.02), STEEL, "chrome"))
    for i, x in enumerate((-1.6, -0.7, 0.4)):
        o.append(paint(box("Ticket", (0.36, 0.02, 0.56), (x, 0.88, 4.33), 0.01, rot=(0, math.radians((i - 1) * 4), 0)), (250, 246, 236)))
        for k in range(3):
            o.append(paint(box("Ink", (0.24, 0.01, 0.03), (x, 0.865, 4.48 - k * 0.12), 0.0), (60, 60, 70)))
    # a cloche and the service bell on the ends (plates go in the middle)
    o.append(paint(cyl("Plate", 0.55, 0.05, (-2.25, -0.2, 3.4), 32, 0.02), (250, 250, 248)))
    o.append(paint(lathe("Cloche", [(0, 0.62), (0.15, 0.6), (0.42, 0.4), (0.5, 0.05), (0.52, 0)], (-2.25, -0.2, 3.42), 40), STEEL, "chrome"))
    o.append(paint(sphere("ClocheKnob", 0.08, (-2.25, -0.2, 4.08)), BRASS_K, "chrome"))
    o.append(paint(cyl("BellBase", 0.26, 0.06, (2.3, -0.5, 3.4), 24, 0.02), WALNUT_K))
    o.append(paint(lathe("Bell", [(0, 0.3), (0.12, 0.27), (0.2, 0.12), (0.22, 0)], (2.3, -0.5, 3.43), 24), BRASS_K, "chrome"))
    o.append(paint(cyl("BellPin", 0.03, 0.1, (2.3, -0.5, 3.78), 8, 0.0), BRASS_K, "chrome"))
    return o


def bistroChair(o, x, face):
    """A rattan bistro chair at (x, 0), facing +X when face = 1 (toward the table)."""
    o.append(paint(cyl("Seat", 0.72, 0.14, (x, 0, 1.72), 32, 0.04), (200, 156, 100), var=0.06))
    o.append(paint(cyl("Cushion", 0.62, 0.1, (x, 0, 1.84), 32, 0.04), EMERALD, var=0.04))
    for a in range(4):
        t = a / 4 * math.pi * 2 + math.pi / 4
        o.append(paint(tube("Leg", [(x + math.cos(t) * 0.5, math.sin(t) * 0.5, 1.66), (x + math.cos(t) * 0.62, math.sin(t) * 0.62, 0)], 0.05), (40, 36, 34)))
    # the curved back, behind the sitter
    pts = []
    for k in range(13):
        t = math.radians(-70 + k * (140 / 12))
        pts.append((x - face * math.cos(t) * 0.68, math.sin(t) * 0.68, 3.05))
    o.append(paint(tube("BackRail", pts, 0.07), (200, 156, 100)))
    for k in (0, 4, 8, 12):
        px, py, _ = pts[k]
        o.append(paint(tube("BackPost", [(px, py, 1.78), (px, py, 3.05)], 0.045), (200, 156, 100)))


@prop
def CafeTable():
    o = []
    o.append(paint(cyl("Top", 1.25, 0.12, (0, 0, 2.86), 48, 0.04), MARBLE, var=0.02))
    o.append(paint(cyl("Edge", 1.27, 0.06, (0, 0, 2.78), 48, 0.02), BRASS_K, "chrome"))
    o.append(paint(lathe("Pedestal", [(0, 0), (0.85, 0), (0.85, 0.08), (0.2, 0.3), (0.12, 2.75), (0, 2.75)], (0, 0, 0), 32), (40, 36, 34)))
    o.append(paint(lathe("Vase", [(0, 0), (0.12, 0), (0.16, 0.22), (0.07, 0.42), (0.09, 0.5), (0, 0.5)], (0, 0, 2.92), 20), (90, 150, 190), "glass"))
    o.append(paint(tube("FlowerStem", [(0, 0, 3.1), (0.04, 0.02, 3.65)], 0.02), (70, 130, 60)))
    o.append(paint(sphere("Bloom", 0.13, (0.05, 0.02, 3.72)), (240, 120, 130)))
    for i, c in enumerate(((248, 248, 246), (40, 40, 44))):
        o.append(paint(lathe("Shaker", [(0, 0), (0.07, 0), (0.07, 0.2), (0.04, 0.26), (0, 0.27)], (0.5, -0.2 + i * 0.18, 2.92), 12), c))
    bistroChair(o, -2.05, 1)
    bistroChair(o, 2.05, -1)
    return o
