"""Round 9 city props: cars and street furniture. Loaded by rah_props.py (exec), sharing its helpers.
Cars are built along Blender +X (= Roblox +X, the car's forward), centred on the ground under the
middle of the car. Groups: main (baked colours), paint (white, tinted per car by Part.Color in Studio),
tint (dark car glass), chrome, glow (lamps). Wheels are a separate prop (CarWheel) placed in Studio.
"""


def ring(sec, k=5):
    """Rounded trapezoid cross-section in the YZ plane at sec['x'].
    sec: x, w (half width at bottom), wt (half width at top), zb, zt, rb, rt (corner radii)."""
    x, wb, wt, zb, zt = sec["x"], sec["w"], sec.get("wt", sec["w"]), sec["zb"], sec["zt"]
    rb = min(sec.get("rb", 0.4), (zt - zb) / 2 - 0.01, wb - 0.01)
    rt = min(sec.get("rt", 0.4), (zt - zb) / 2 - 0.01, wt - 0.01)
    pts = []
    corners = [((wb - rb, zb + rb), rb, -90), ((wt - rt, zt - rt), rt, 0),
               ((-(wt - rt), zt - rt), rt, 90), ((-(wb - rb), zb + rb), rb, 180)]
    for (cy, cz), r, a0 in corners:
        for i in range(k + 1):
            a = math.radians(a0 + 90 * i / k)
            pts.append((x, cy + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def loft(name, secs, k=5, caps=True):
    bm = bmesh.new()
    rows = [[bm.verts.new(p) for p in ring(s, k)] for s in secs]
    n = len(rows[0])
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps:
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    return shade(ob, 38)


def rot_z(ob, deg):
    ob.rotation_euler = (0, 0, math.radians(deg))
    bake_xform(ob)
    return ob


def arch_secs(length, half_w, wheel_x, wheel_r, bot, belt_r, belt_f, nose_z, tail_z, wt_k=0.97):
    """Lower body sections with wheel arches. belt_r/belt_f = beltline height at the rear/front."""
    L = length / 2
    xs = [-L, -L + 0.35, -L + 1.0]
    for wx in (-wheel_x, wheel_x):
        xs += [wx - wheel_r - 0.35, wx - wheel_r + 0.05, wx - wheel_r * 0.55, wx, wx + wheel_r * 0.55, wx + wheel_r - 0.05, wx + wheel_r + 0.35]
    xs += [L - 1.0, L - 0.35, L]
    xs = sorted(set(round(x, 3) for x in xs))
    secs = []
    for x in xs:
        u = (x + L) / length
        zt = belt_r + (belt_f - belt_r) * u
        zb = bot
        for wx in (-wheel_x, wheel_x):
            d = abs(x - wx)
            if d < wheel_r + 0.06:
                zb = max(zb, bot + (wheel_r + 0.25) * math.sqrt(max(0, 1 - (d / (wheel_r + 0.06)) ** 2)) * 0.95 + 0.15)
        w = half_w
        if x <= -L + 0.36:
            zt = tail_z if x == -L else (zt + tail_z) / 2
            w = half_w - (0.35 if x == -L else 0.08)
        if x >= L - 0.36:
            zt = nose_z if x == L else (zt + nose_z) / 2
            w = half_w - (0.35 if x == L else 0.08)
        secs.append(dict(x=x, w=w, wt=w * wt_k, zb=zb, zt=zt, rb=0.35, rt=0.55))
    return secs


def car_common(o, length, half_w, wheel_x, nose_z, tail_z, front_x, rear_x, lamp_z, grille=(46, 48, 54)):
    """Lights, bumpers, grille, plates, mirrors shared by every car."""
    L = length / 2
    for s in (-1, 1):
        # headlights (glow) and tail lights
        o.append(paint(box("HeadL", (0.25, 1.1, 0.5), (front_x, s * (half_w - 0.85), lamp_z), 0.1), (255, 250, 230), "glow"))
        o.append(paint(box("TailL", (0.22, 1.0, 0.45), (rear_x, s * (half_w - 0.8), lamp_z + 0.1), 0.1), (230, 40, 40), "glow"))
        # side mirrors
        o.append(paint(box("Mirror", (0.5, 0.45, 0.35), (wheel_x - 2.4, s * (half_w + 0.2), lamp_z + 1.65), 0.12), (40, 42, 48)))
        # door handles
        for hx in (-0.9, 1.3):
            o.append(paint(box("Handle", (0.5, 0.06, 0.12), (hx, s * (half_w + 0.01), lamp_z + 0.75), 0.03, 2), CHROME, "chrome"))
    # bumpers
    o.append(paint(box("BumpF", (0.5, half_w * 2 - 0.3, 0.55), (L - 0.05, 0, 1.15), 0.22), (52, 54, 60)))
    o.append(paint(box("BumpR", (0.5, half_w * 2 - 0.3, 0.55), (-L + 0.05, 0, 1.15), 0.22), (52, 54, 60)))
    o.append(paint(box("Grille", (0.2, half_w * 1.0, 0.45), (front_x + 0.04, 0, lamp_z - 0.25), 0.08), grille))
    o.append(paint(box("PlateF", (0.08, 1.4, 0.45), (L + 0.22, 0, 1.2), 0.03), (246, 246, 240)))
    o.append(paint(box("PlateR", (0.08, 1.4, 0.45), (-L - 0.22, 0, 1.45), 0.03), (246, 246, 240)))


def cabin(o, x0, x1, x_rear_top, x_front_top, half_w, z_belt_r, z_belt_f, z_roof, roof_w=0.82, pillars=True):
    """Glass greenhouse + painted roof skin + pillars."""
    secs = [
        dict(x=x0, w=half_w - 0.1, wt=half_w - 0.15, zb=z_belt_r - 0.15, zt=z_belt_r + 0.1, rb=0.1, rt=0.1),
        dict(x=x_rear_top, w=half_w - 0.15, wt=half_w * roof_w, zb=z_belt_r - 0.15, zt=z_roof, rb=0.1, rt=0.55),
        dict(x=x_front_top, w=half_w - 0.15, wt=half_w * roof_w, zb=z_belt_f - 0.15, zt=z_roof, rb=0.1, rt=0.55),
        dict(x=x1, w=half_w - 0.1, wt=half_w - 0.15, zb=z_belt_f - 0.15, zt=z_belt_f + 0.1, rb=0.1, rt=0.1),
    ]
    o.append(paint(loft("Cabin", secs), (40, 52, 66), "tint"))
    # roof skin: a thin painted shell over the top of the greenhouse
    rs = []
    for x in (x_rear_top - 0.25, (x_rear_top + x_front_top) / 2, x_front_top + 0.25):
        rs.append(dict(x=x, w=half_w * roof_w + 0.06, zb=z_roof - 0.3, zt=z_roof + 0.06, rb=0.25, rt=0.5))
    o.append(paint(loft("Roof", rs), (255, 255, 255), "paint", var=0.0))
    if pillars:
        # B pillar and the two pillars that frame the glass, both sides
        for s in (-1, 1):
            xm = (x_rear_top + x_front_top) / 2 - 0.2
            zb = (z_belt_r + z_belt_f) / 2
            b0 = Vector((xm, s * (half_w - 0.13), zb + 0.05))
            b1 = Vector((xm, s * (half_w * roof_w - 0.01), z_roof - 0.2))
            o.append(paint(tube("BPillar", [b0, b1], 0.12, 8), (30, 32, 38)))
            # A pillar: from the front belt to the front roof corner
            a0 = Vector((x1 + 0.05, s * (half_w - 0.12), z_belt_f + 0.05))
            a1 = Vector((x_front_top - 0.05, s * (half_w * roof_w - 0.02), z_roof - 0.2))
            o.append(paint(tube("APillar", [a0, a1], 0.13, 8), (255, 255, 255), "paint", var=0))
            c0 = Vector((x0 - 0.05, s * (half_w - 0.12), z_belt_r + 0.05))
            c1 = Vector((x_rear_top + 0.05, s * (half_w * roof_w - 0.02), z_roof - 0.2))
            o.append(paint(tube("CPillar", [c0, c1], 0.18, 8), (255, 255, 255), "paint", var=0))


@prop
def CarWheel():
    """One wheel, axle along Y, centred at the origin raised by its radius (r 1.35)."""
    o = []
    prof = [(0.0, -0.62), (0.9, -0.62), (1.18, -0.6), (1.32, -0.48), (1.36, -0.2), (1.36, 0.2), (1.32, 0.48), (1.18, 0.6), (0.9, 0.62), (0.0, 0.62)]
    t = lathe("Tire", [(r, z) for r, z in prof], N=28, angle=40)
    t.rotation_euler = (math.radians(90), 0, 0)
    t.location = (0, 0, 1.35)
    bake_xform(t)
    o.append(paint(t, (34, 34, 38), var=0.03))
    rim = lathe("Rim", [(0, 0.64), (0.82, 0.64), (0.92, 0.58), (0.92, 0.5), (0.3, 0.5), (0, 0.45)], N=24, angle=40)
    rim.rotation_euler = (math.radians(-90), 0, 0)
    rim.location = (0, 0, 1.35)
    bake_xform(rim)
    o.append(paint(rim, (200, 204, 210), "chrome", var=0))
    for i in range(5):
        a = 2 * math.pi * i / 5
        s = box("Spoke", (0.22, 0.12, 0.75), (0, 0, 0), 0.04, 2)
        s.location = (math.sin(a) * 0.45, -0.66, 1.35 + math.cos(a) * 0.45)
        s.rotation_euler = (0, a, 0)
        bake_xform(s)
        o.append(paint(s, (170, 174, 182), "chrome", var=0))
    o.append(paint(cyl("Hub", 0.22, 0.1, (0, -0.7, 1.35), 16, 0.02, (math.radians(90), 0, 0)), (120, 124, 130), "chrome", var=0))
    return o


@prop
def Sedan():
    o = []
    hw = 3.2
    o.append(paint(loft("Body", arch_secs(15.4, hw, 4.75, 1.35, 0.75, 3.55, 3.25, 2.55, 2.85)), (255, 255, 255), "paint", var=0))
    cabin(o, -5.0, 3.0, -2.6, 0.9, hw, 3.5, 3.3, 5.6)
    car_common(o, 15.4, hw, 4.75, 2.55, 2.85, 7.62, -7.62, 2.45)
    o.append(paint(box("Under", (13.6, hw * 2 - 0.6, 0.5), (0, 0, 0.95), 0.1), (30, 30, 34)))
    return o


@prop
def Hatch():
    o = []
    hw = 3.0
    o.append(paint(loft("Body", arch_secs(12.6, hw, 3.9, 1.3, 0.75, 3.6, 3.25, 2.5, 3.0)), (255, 255, 255), "paint", var=0))
    cabin(o, -6.0, 2.4, -5.4, 0.6, hw, 3.55, 3.3, 5.9)
    car_common(o, 12.6, hw, 3.9, 2.5, 3.0, 6.22, -6.22, 2.45)
    o.append(paint(box("Under", (11.0, hw * 2 - 0.6, 0.5), (0, 0, 0.95), 0.1), (30, 30, 34)))
    o.append(paint(box("Spoiler", (0.8, hw * 1.4, 0.18), (-5.95, 0, 5.85), 0.06), (30, 32, 38)))
    return o


@prop
def SUV():
    o = []
    hw = 3.5
    o.append(paint(loft("Body", arch_secs(16.6, hw, 5.1, 1.6, 1.2, 4.4, 4.1, 3.4, 3.6)), (255, 255, 255), "paint", var=0))
    cabin(o, -7.6, 3.5, -7.0, 1.6, hw, 4.35, 4.1, 7.3, roof_w=0.88)
    car_common(o, 16.6, hw, 5.1, 3.4, 3.6, 8.22, -8.22, 3.2)
    o.append(paint(box("Under", (14.8, hw * 2 - 0.6, 0.7), (0, 0, 1.3), 0.1), (30, 30, 34)))
    for s in (-1, 1):
        o.append(paint(box("Rail", (8.0, 0.25, 0.25), (-2.6, s * (hw * 0.82), 7.45), 0.08), (40, 42, 48)))
        # chunky black arch trims
        for wx in (-5.1, 5.1):
            o.append(paint(box("Cladding", (4.0, 0.15, 0.45), (wx, s * (hw + 0.02), 1.6), 0.06), (40, 42, 46)))
    o.append(paint(box("Spare", (0.6, 2.4, 2.4), (-8.6, 0, 3.4), 0.5), (34, 34, 38)))
    return o


@prop
def Taxi():
    o = Sedan()
    # roof sign
    o.append(paint(box("TaxiSign", (1.0, 2.4, 0.7), (-0.7, 0, 6.05), 0.2), (255, 248, 220), "glow"))
    o.append(paint(box("SignBase", (1.1, 2.5, 0.12), (-0.7, 0, 5.7), 0.05), (34, 34, 38)))
    for s in (-1, 1):
        o.append(paint(box("Checks", (6.0, 0.06, 0.32), (0, s * 3.21, 2.85), 0.02, 2), (30, 30, 34)))
    return o


@prop
def Van():
    o = []
    hw = 3.5
    secs = arch_secs(18.0, hw, 5.6, 1.45, 0.9, 4.0, 3.6, 3.0, 3.6)
    o.append(paint(loft("Body", secs), (255, 255, 255), "paint", var=0))
    # tall box behind a short cab
    box_secs = [dict(x=-9.0, w=hw, wt=hw - 0.05, zb=3.5, zt=9.0, rb=0.3, rt=0.5),
                dict(x=3.4, w=hw, wt=hw - 0.05, zb=3.5, zt=9.0, rb=0.3, rt=0.5),
                dict(x=4.6, w=hw, wt=hw - 0.4, zb=3.5, zt=8.6, rb=0.3, rt=0.9),
                dict(x=6.6, w=hw - 0.05, wt=hw - 0.6, zb=3.5, zt=5.0, rb=0.3, rt=0.6)]
    o.append(paint(loft("Box", box_secs), (255, 255, 255), "paint", var=0))
    # windscreen and side windows of the cab
    ws = box("Windscreen", (0.15, hw * 1.7, 3.0), (5.55, 0, 6.75), 0.05, rot=(0, math.radians(-40), 0))
    o.append(paint(ws, (40, 52, 66), "tint"))
    for s in (-1, 1):
        o.append(paint(box("SideWin", (2.6, 0.1, 2.0), (3.6, s * (hw + 0.01), 6.3), 0.05), (40, 52, 66), "tint"))
        o.append(paint(box("Stripe", (12.0, 0.06, 0.7), (-2.8, s * (hw + 0.02), 5.0), 0.03, 2), (240, 120, 60)))
    car_common(o, 18.0, hw, 5.6, 3.0, 3.6, 8.92, -8.92, 2.9)
    o.append(paint(box("Under", (16.0, hw * 2 - 0.6, 0.6), (0, 0, 1.1), 0.1), (30, 30, 34)))
    o.append(paint(box("RearDoorGap", (0.06, 0.08, 5.0), (-9.02, 0, 6.2), 0.01, 1), (40, 40, 44)))
    return o


@prop
def Pickup():
    o = []
    hw = 3.4
    o.append(paint(loft("Body", arch_secs(17.4, hw, 5.4, 1.55, 1.15, 4.3, 4.0, 3.3, 3.8)), (255, 255, 255), "paint", var=0))
    cabin(o, -1.8, 3.6, -1.4, 1.6, hw, 4.25, 4.0, 7.1, roof_w=0.9)
    car_common(o, 17.4, hw, 5.4, 3.3, 3.8, 8.62, -8.62, 3.1)
    o.append(paint(box("Under", (15.6, hw * 2 - 0.6, 0.7), (0, 0, 1.3), 0.1), (30, 30, 34)))
    # open bed: floor and inner walls
    o.append(paint(box("BedFloor", (6.4, hw * 2 - 0.8, 0.2), (-5.2, 0, 3.6), 0.04), (60, 60, 64)))
    for s in (-1, 1):
        o.append(paint(box("BedWall", (6.6, 0.3, 1.5), (-5.2, s * (hw - 0.25), 4.6), 0.08), (255, 255, 255), "paint", var=0))
    o.append(paint(box("Tailgate", (0.3, hw * 2 - 0.3, 1.5), (-8.55, 0, 4.6), 0.08), (255, 255, 255), "paint", var=0))
    o.append(paint(box("Crate", (2.2, 2.2, 1.6), (-5.6, 0.6, 4.5), 0.1, 2, (0, 0, 0.15)), (186, 140, 90)))
    return o


@prop
def Bus():
    """City bus, 34 long, along +X."""
    o = []
    hw = 4.1
    body = [dict(x=-17.0, w=hw - 0.1, wt=hw - 0.2, zb=1.0, zt=11.0, rb=0.6, rt=1.0),
            dict(x=-16.6, w=hw, wt=hw - 0.1, zb=0.9, zt=11.3, rb=0.6, rt=1.1),
            dict(x=16.4, w=hw, wt=hw - 0.1, zb=0.9, zt=11.3, rb=0.6, rt=1.1),
            dict(x=17.0, w=hw - 0.1, wt=hw - 0.3, zb=1.0, zt=10.8, rb=0.6, rt=1.0)]
    o.append(paint(loft("Body", body), (255, 255, 255), "paint", var=0))
    # window band, both sides, and a big windscreen
    for s in (-1, 1):
        o.append(paint(box("Windows", (28.0, 0.12, 3.6), (-0.6, s * (hw + 0.02), 7.6), 0.06), (40, 52, 66), "tint"))
        o.append(paint(box("Stripe", (33.0, 0.08, 0.8), (0, s * (hw + 0.03), 4.2), 0.03, 2), (40, 150, 220)))
        o.append(paint(box("Skirt", (33.4, 0.1, 1.0), (0, s * (hw + 0.02), 1.4), 0.03, 2), (50, 52, 58)))
        for x in range(-13, 15, 4):
            o.append(paint(box("Mullion", (0.3, 0.14, 3.6), (x - 0.6, s * (hw + 0.04), 7.6), 0.03, 2), (30, 32, 36)))
    o.append(paint(box("Doors", (2.8, 0.12, 6.0), (12.6, -(hw + 0.03), 4.4), 0.04), (40, 52, 66), "tint"))
    o.append(paint(box("Doors2", (2.8, 0.12, 6.0), (0.5, -(hw + 0.03), 4.4), 0.04), (40, 52, 66), "tint"))
    o.append(paint(box("Windscreen", (0.15, hw * 1.8, 5.2), (17.02, 0, 7.4), 0.08), (40, 52, 66), "tint"))
    o.append(paint(box("RearWin", (0.15, hw * 1.5, 2.6), (-17.02, 0, 8.6), 0.08), (40, 52, 66), "tint"))
    o.append(paint(box("RouteSign", (0.12, hw * 1.3, 0.9), (17.05, 0, 10.4), 0.05), (255, 190, 60), "glow"))
    o.append(paint(box("RoofPod", (12.0, hw * 1.4, 0.9), (-3.0, 0, 11.6), 0.35), (230, 232, 236)))
    for s in (-1, 1):
        o.append(paint(box("HeadL", (0.2, 1.2, 0.6), (17.05, s * (hw - 1.0), 2.4), 0.1), (255, 250, 230), "glow"))
        o.append(paint(box("TailL", (0.2, 0.8, 1.2), (-17.05, s * (hw - 0.8), 2.8), 0.1), (230, 40, 40), "glow"))
        o.append(paint(box("Mirror", (0.4, 0.3, 1.4), (17.3, s * (hw + 0.6), 8.6), 0.1), (40, 42, 48)))
    o.append(paint(box("BumpF", (0.6, hw * 2 - 0.2, 0.9), (17.05, 0, 1.4), 0.25), (52, 54, 60)))
    o.append(paint(box("BumpR", (0.6, hw * 2 - 0.2, 0.9), (-17.05, 0, 1.4), 0.25), (52, 54, 60)))
    return o


# ---------------------------------------------------------------- street furniture

@prop
def StreetLamp():
    """Modern double street lamp, 20 tall, heads reach over +Y? No: arm reaches toward -Y (the prop front)."""
    o = []
    METAL = (52, 58, 66)
    o.append(paint(lathe("Base", [(0, 0), (0.75, 0), (0.75, 0.3), (0.55, 0.5), (0.4, 1.6), (0, 1.6)], N=24), METAL))
    o.append(paint(lathe("Pole", [(0, 1.5), (0.32, 1.5), (0.22, 18.5), (0, 18.5)], N=20), METAL))
    arm = tube("Arm", bend_path([(0, 0, 17.8), (0, 0, 19.0), (0, -4.5, 19.2)], 1.0, 8), 0.16, 8)
    o.append(paint(arm, METAL))
    head = box("Head", (1.4, 2.8, 0.5), (0, -4.6, 19.15), 0.2)
    o.append(paint(head, METAL))
    o.append(paint(box("Bulb", (1.0, 2.2, 0.12), (0, -4.6, 18.86), 0.05), (255, 240, 200), "glow"))
    o.append(paint(box("Banner", (0.1, 1.6, 3.4), (0, 0.95, 13.8), 0.05), (210, 60, 70)))
    o.append(paint(box("BannerRod", (0.12, 1.9, 0.12), (0, 0.85, 15.6), 0.04), METAL))
    return o


@prop
def TrafficLight():
    """Pole with a mast arm over the road (toward -Y), signal box at the end (facing -X/+X both ways)."""
    o = []
    METAL = (44, 48, 54)
    o.append(paint(lathe("Base", [(0, 0), (0.85, 0), (0.85, 0.4), (0.5, 0.7), (0, 0.7)], N=24), METAL))
    o.append(paint(lathe("Pole", [(0, 0.6), (0.4, 0.6), (0.32, 17.0), (0, 17.0)], N=20), METAL))
    o.append(paint(cyl("Mast", 0.22, 16.0, (0, -8.0, 16.2), 14, 0.02, (math.radians(90), 0, 0)), METAL))
    # signal heads hang from the mast at two spots; red/amber/green lenses are separate glow pieces in Studio
    for y in (-7.0, -14.0):
        o.append(paint(box("Head", (1.3, 1.3, 3.8), (0, y, 13.8), 0.25), (240, 196, 40)))
        o.append(paint(box("Back", (0.2, 1.6, 4.2), (0, y, 13.8), 0.06), (34, 36, 40)))
        for i in range(3):
            for sx in (-1, 1):
                o.append(paint(box("Visor", (0.5, 1.0, 0.12), (sx * 0.8, y, 14.95 - i * 1.15 + 0.45), 0.04, 2), (34, 36, 40)))
    # pedestrian signal box on the pole
    o.append(paint(box("PedBox", (1.0, 1.0, 1.4), (0, 0.55, 9.0), 0.15), (240, 196, 40)))
    o.append(paint(box("Button", (0.5, 0.35, 0.6), (0.48, 0, 4.2), 0.08), (240, 196, 40)))
    return o


@prop
def Bench():
    """Park bench, 7 wide, seat faces -Y."""
    o = []
    METAL = (48, 54, 60)
    for sx in (-1, 1):
        side = tube("Side", [(sx * 3.0, -0.9, 0), (sx * 3.0, -0.8, 1.6), (sx * 3.0, 0.7, 1.7), (sx * 3.0, 0.9, 3.6)], 0.12, 8)
        o.append(paint(side, METAL))
        o.append(paint(tube("Leg", [(sx * 3.0, 0.7, 1.7), (sx * 3.0, 0.6, 0)], 0.12, 8), METAL))
        o.append(paint(tube("Arm", [(sx * 3.1, -0.9, 2.5), (sx * 3.1, 0.6, 2.6)], 0.1, 8), METAL))
    for i in range(4):
        o.append(paint(box("Slat", (6.6, 0.42, 0.18), (0, -0.75 + i * 0.47, 1.75), 0.06), (176, 112, 64)))
    for i in range(3):
        b = box("BackSlat", (6.6, 0.18, 0.42), (0, 0.78 + i * 0.05, 2.35 + i * 0.5), 0.06)
        o.append(paint(b, (176, 112, 64)))
    return o


@prop
def TrashBin():
    o = []
    o.append(paint(lathe("Bin", [(0, 0), (0.95, 0), (1.05, 0.2), (1.05, 3.4), (0.98, 3.5), (0, 3.5)], N=28), (46, 92, 70)))
    for z in (0.8, 2.6):
        o.append(paint(lathe("Band", [(1.06, z), (1.12, z + 0.05), (1.12, z + 0.25), (1.06, z + 0.3)], N=28), (200, 170, 90), "chrome"))
    o.append(paint(lathe("Lid", [(0, 3.5), (1.15, 3.5), (1.1, 3.75), (0.6, 4.05), (0, 4.1)], N=28), (40, 80, 62)))
    o.append(paint(box("Slot", (0.9, 0.3, 0.3), (0, -0.85, 3.45), 0.08), (20, 22, 24)))
    return o


@prop
def Hydrant():
    o = []
    RED = (220, 50, 46)
    o.append(paint(lathe("Body", [(0, 0), (0.7, 0), (0.7, 0.25), (0.48, 0.35), (0.45, 2.1), (0.62, 2.2), (0.62, 2.45), (0.4, 2.6), (0.3, 2.95), (0.12, 3.05), (0, 3.05)], N=24), RED))
    for a in (0, 180):
        n = cyl("Nozzle", 0.2, 0.5, (0, 0, 0), 14, 0.02, (0, math.radians(90), 0))
        n.location = (math.cos(math.radians(a)) * 0.6, math.sin(math.radians(a)) * 0.6, 1.7)
        n.rotation_euler = (0, math.radians(90), math.radians(a))
        bake_xform(n)
        o.append(paint(n, RED))
    o.append(paint(cyl("Front", 0.28, 0.45, (0, -0.6, 1.5), 14, 0.02, (math.radians(90), 0, 0)), (240, 230, 220)))
    return o


def canopy_blobs(o, centers, color, seed):
    for i, (c, r) in enumerate(centers):
        s = sphere("Leaves", r, c, sub=3)
        wobble(s, r * 0.12, 0.9, seed + i)
        o.append(paint(s, color, var=0.12, grad=lambda p, c: c * (0.82 + 0.05 * (p.z - 8))))


@prop
def TreeA():
    """Round street tree, ~22 tall."""
    o = []
    o.append(paint(tube("Trunk", [(0, 0, 0), (0.1, 0, 5), (0.3, 0.2, 9), (0.2, 0.1, 12)], 0.55, 10), (110, 78, 54)))
    o.append(paint(tube("Branch", [(0.25, 0.15, 8), (2.2, 0.8, 11.5)], 0.25, 8), (110, 78, 54)))
    o.append(paint(tube("Branch", [(0.25, 0.15, 9), (-2.0, -0.9, 12.5)], 0.25, 8), (110, 78, 54)))
    canopy_blobs(o, [((0, 0, 15.5), 5.2), ((2.8, 1.2, 13.5), 3.8), ((-2.8, -1.0, 14.2), 3.9), ((0.6, -2.6, 13.4), 3.4),
                     ((-0.8, 2.4, 13.0), 3.3), ((0.5, 0.4, 19.0), 3.4)], (92, 168, 76), 1)
    return o


@prop
def TreeB():
    """Tall slim tree (columnar), ~26 tall."""
    o = []
    o.append(paint(tube("Trunk", [(0, 0, 0), (0, 0, 8)], 0.45, 10), (100, 74, 52)))
    canopy_blobs(o, [((0, 0, 11), 3.8), ((0.3, 0.2, 15.5), 3.6), ((-0.2, 0, 19.5), 3.0), ((0, -0.2, 23), 2.2),
                     ((1.6, 0.6, 13), 2.6), ((-1.5, -0.8, 14.5), 2.6)], (70, 140, 74), 2)
    return o


@prop
def TreeC():
    """Blossom tree (pink), ~18 tall."""
    o = []
    o.append(paint(tube("Trunk", [(0, 0, 0), (0.3, 0, 4), (-0.2, 0.3, 7), (0.1, 0, 9)], 0.5, 10), (96, 66, 58)))
    o.append(paint(tube("Branch", [(0, 0.2, 6.5), (2.6, -0.5, 9.5)], 0.22, 8), (96, 66, 58)))
    canopy_blobs(o, [((0, 0, 12), 4.4), ((2.8, -0.6, 10.6), 3.2), ((-2.6, 0.8, 11), 3.3), ((0.4, 2.4, 10.4), 2.9),
                     ((-0.3, -2.3, 10.8), 2.8), ((0.4, 0.2, 15.2), 2.8)], (246, 170, 196), 3)
    return o


@prop
def Bush():
    o = []
    canopy_blobs(o, [((0, 0, 1.6), 2.0), ((1.6, 0.4, 1.3), 1.5), ((-1.5, -0.3, 1.4), 1.6), ((0.2, 1.3, 1.2), 1.3), ((0, -1.3, 1.2), 1.3)], (78, 150, 70), 4)
    return o


@prop
def BusStop():
    """Bus shelter, 14 wide, open front at -Y (the road side)."""
    o = []
    METAL = (56, 62, 70)
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Post", (0.35, 0.35, 8.4), (sx * 6.6, sy * 1.6 + 0.4, 4.2), 0.08), METAL))
    roof = box("Roof", (14.4, 4.4, 0.4), (0, 0.2, 8.6), 0.15, rot=(math.radians(-3), 0, 0))
    o.append(paint(roof, METAL))
    o.append(paint(box("Back", (13.0, 0.12, 6.4), (0, 2.0, 4.6), 0.04), (210, 232, 240), "glass"))
    o.append(paint(box("Side", (0.12, 3.0, 6.4), (6.6, 0.4, 4.6), 0.04), (210, 232, 240), "glass"))
    o.append(paint(box("Ad", (3.6, 0.3, 6.0), (-6.6, 0.4, 4.4), 0.1), (34, 36, 42)))
    o.append(paint(box("AdFace", (0.04, 2.8, 5.0), (-6.4, 0.4, 4.6), 0.02), (255, 240, 220), "glow"))
    o.append(paint(box("Seat", (8.0, 1.4, 0.3), (1.0, 1.2, 1.9), 0.1), (176, 112, 64)))
    for x in (-2.0, 4.0):
        o.append(paint(box("SeatLeg", (0.3, 0.3, 1.8), (x, 1.4, 0.9), 0.05), METAL))
    o.append(paint(box("SignPole", (0.25, 0.25, 11.0), (7.6, -1.6, 5.5), 0.05), METAL))
    o.append(paint(box("Sign", (0.2, 2.2, 1.6), (7.6, -1.6, 10.4), 0.1), (40, 150, 220)))
    return o


@prop
def Mailbox():
    o = []
    BLUE = (40, 84, 170)
    o.append(paint(box("Body", (2.0, 2.0, 3.0), (0, 0, 2.2), 0.15), BLUE))
    o.append(paint(lathe("Top", [(0, 0), (1.0, 0), (1.0, 0.05), (0, 0.05)], N=16), BLUE))
    top = cyl("Dome", 1.0, 2.0, (0, 0, 3.7), 24, 0.04, (0, math.radians(90), 0))
    o.append(paint(top, BLUE))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.2, 0.2, 0.7), (sx * 0.8, sy * 0.8, 0.35), 0.04), (34, 36, 40)))
    o.append(paint(box("Slot", (1.0, 0.1, 0.25), (0, -1.02, 3.3), 0.04), (20, 22, 24)))
    return o


@prop
def Bollard():
    o = []
    o.append(paint(lathe("Body", [(0, 0), (0.45, 0), (0.42, 2.6), (0.38, 2.8), (0, 2.9)], N=20), (52, 56, 62)))
    o.append(paint(lathe("Band", [(0.44, 2.2), (0.47, 2.2), (0.47, 2.45), (0.44, 2.45)], N=20), (240, 200, 60)))
    return o


@prop
def CafeTable():
    """Round table, two chairs and a parasol."""
    o = []
    o.append(paint(lathe("Table", [(0, 0), (0.8, 0), (0.8, 0.1), (0.12, 0.2), (0.12, 2.6), (1.5, 2.6), (1.5, 2.75), (0, 2.75)], N=28), (236, 236, 232)))
    o.append(paint(cyl("Pole", 0.08, 9.0, (0, 0, 4.5), 10), (60, 60, 64)))
    shade_ = lathe("Parasol", [(0, 8.8), (4.4, 7.4), (4.4, 7.3), (0, 8.6)], N=8, angle=10)
    o.append(paint(shade_, (240, 90, 80)))
    for a in (0, 180):
        cx, cy = math.cos(math.radians(a)) * 2.3, math.sin(math.radians(a)) * 2.3
        o.append(paint(box("Seat", (1.3, 1.3, 0.15), (cx, cy, 1.6), 0.05), (60, 62, 68)))
        bk = box("Back", (0.15, 1.3, 1.4), (cx + (0.65 if a == 0 else -0.65), cy, 2.3), 0.05)
        o.append(paint(bk, (60, 62, 68)))
        for sx in (-1, 1):
            for sy in (-1, 1):
                o.append(paint(box("Leg", (0.1, 0.1, 1.6), (cx + sx * 0.55, cy + sy * 0.55, 0.8), 0.02, 1), (60, 62, 68)))
    return o


@prop
def Planter():
    """Long concrete planter with flowers, 8 x 2.4."""
    o = []
    o.append(paint(box("Box", (8.0, 2.4, 1.8), (0, 0, 0.9), 0.15), (214, 206, 194)))
    o.append(paint(box("Soil", (7.5, 1.9, 0.2), (0, 0, 1.75), 0.05), (96, 70, 50)))
    canopy_blobs(o, [((-2.6, 0, 2.3), 1.1), ((0, 0.1, 2.4), 1.2), ((2.6, -0.1, 2.3), 1.1), ((-1.3, 0.2, 2.2), 0.9), ((1.3, -0.2, 2.2), 0.9)], (86, 160, 74), 7)
    random.seed(7)
    for i in range(16):
        x, y = random.uniform(-3.4, 3.4), random.uniform(-0.8, 0.8)
        c = random.choice([(250, 110, 140), (255, 210, 80), (240, 240, 250), (190, 120, 230)])
        o.append(paint(sphere("Flower", 0.28, (x, y, 2.9 + random.uniform(0, 0.6)), sub=1), c))
    return o


exec(open(os.path.join(HERE, "rah_lobby.py"), encoding="utf8").read()) if os.path.exists(os.path.join(HERE, "rah_lobby.py")) else None
