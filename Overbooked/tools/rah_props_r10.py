"""Round 10 props: the hotel remake (classic boutique: oak, slate, brass, emerald green).
Loaded by rah_props.py (exec) after the round 9 file, so a prop defined here replaces the older one of the
same name. Front = -Y (Roblox +Z), floor = z 0, 1 unit = 1 stud.
"""

FONT_SERIF = r"C:\Windows\Fonts\georgiab.ttf"
SLATE = (58, 62, 66)
SLATE_DK = (34, 36, 40)
OAK10 = (176, 122, 76)
OAK10_DK = (128, 84, 52)
BRASS10 = (218, 178, 98)
EMERALD = (34, 92, 72)
INK10 = (30, 32, 36)
PAPER10 = (246, 240, 226)


def text_mesh(name, text, size, loc, depth, font=FONT_SERIF, rot=(math.radians(90), 0, 0)):
    """Solid text (mesh). Default turn: reads along +X, faces -Y, centred on loc, `depth` either side of it."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text
    try:
        cu.font = bpy.data.fonts.load(font, check_existing=True)
    except Exception:
        pass
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = depth
    cu.resolution_u = 6
    tmp = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(tmp)
    tmp.location = loc
    tmp.rotation_euler = rot
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    mw = tmp.matrix_world.copy()
    bpy.data.objects.remove(tmp, do_unlink=True)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.matrix_world = mw
    bake_xform(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def carve(target, cutter):
    """Boolean difference (exact), then drop the cutter."""
    m = target.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    apply_mods(target)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return shade(target, 30)


def paint_fn(ob, fn, group="main", var=0.04):
    """Per-corner colour from fn(position) -> rgb (0..255)."""
    me = ob.data
    col = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    seed = random.random() * 50
    for li, loop in enumerate(me.loops):
        p = me.vertices[loop.vertex_index].co
        c = fn(p)
        k = 1 + var * noise.noise(p * 0.9 + Vector((seed, 2, 3)))
        col.data[li].color = (c[0] / 255 * k, c[1] / 255 * k, c[2] / 255 * k, 1)
    ob["group"] = group
    return ob


def planks_h(o, name, w, h, y, z0, x0, n, col, depth=0.12, gap=0.05, var=0.1):
    """A face of horizontal planks (facing -Y at y), each a slightly different tone."""
    ph = (h - gap * (n - 1)) / n
    for i in range(n):
        z = z0 + ph / 2 + i * (ph + gap)
        t = 1 + (random.random() - 0.5) * var * 2
        o.append(paint(box(name, (w, depth, ph), (x0, y, z), 0.025, 2), tuple(min(255, c * t) for c in col), var=0.06))


@prop
def Desk():
    """Reception desk, 12 wide: oak ends, a slate front with RECEPTION carved in, an oak guest ledge,
    three staff stations (monitor + keyboard) on the work surface behind. Guests at -Y, staff at +Y."""
    random.seed(1010)
    o = []
    W, D = 12.0, 3.2
    yf = -D / 2  # front face
    # plinth (recessed) and the staff-side carcass
    o.append(paint(box("Plinth", (W - 0.5, D - 0.4, 0.36), (0, 0.15, 0.18), 0.03, 2), SLATE_DK))
    o.append(paint(box("Carcass", (W - 0.2, D - 0.9, 2.62), (0, 0.35, 1.67), 0.05, 2), (226, 218, 204)))
    # slate front panel with RECEPTION carved in (no bevel, so only the letters sit inside the face)
    sw = 7.0
    slab = box("Slate", (sw, 0.34, 3.36), (0, yf + 0.17, 2.04), 0)
    txt = text_mesh("Word", "RECEPTION", 1.12, (0, yf, 2.0), 0.075)
    slab = carve(slab, txt)
    slab_front = yf

    def slate_col(p):
        if slab_front + 0.004 < p.y < slab_front + 0.3 and abs(p.x) < sw / 2 - 0.01 and 0.37 < p.z < 3.7:
            # inside the letters: paler, sandblasted stone, darker at the floor of the cut
            k = min(1, (p.y - slab_front) / 0.075)
            return tuple(a * (1 - k) + b * k for a, b in zip((150, 154, 156), (104, 108, 112)))
        return SLATE
    o.append(paint_fn(slab, slate_col, var=0.05))
    # a thin brass reveal round the slate, and oak ends with horizontal planks
    for sx in (-1, 1):
        o.append(paint(box("Reveal", (0.09, 0.36, 3.36), (sx * (sw / 2 + 0.045), yf + 0.17, 2.04), 0.02, 1), BRASS10, "chrome"))
        ex = sx * (sw / 2 + 0.09 + (W / 2 - sw / 2 - 0.09) / 2)
        ew = W / 2 - sw / 2 - 0.09
        o.append(paint(box("EndCore", (ew, D - 0.45, 3.36), (ex, 0.1, 2.04), 0.04, 2), OAK10_DK))
        planks_h(o, "EndPlank", ew - 0.06, 3.3, yf + 0.06, 0.39, ex, 7, OAK10)
        # side face planks (the short ends)
        for i in range(7):
            ph = (3.3 - 0.05 * 6) / 7
            z = 0.39 + ph / 2 + i * (ph + 0.05)
            t = 1 + (random.random() - 0.5) * 0.2
            o.append(paint(box("SidePlank", (0.12, D - 0.5, ph), (sx * (W / 2 - 0.02), 0.1, z), 0.025, 2), tuple(min(255, c * t) for c in OAK10), var=0.06))
    # the guest ledge: thick oak with a brass nosing underneath
    o.append(paint(box("Ledge", (W + 0.35, 1.25, 0.24), (0, yf + 0.42, 3.86), 0.07, 4), OAK10, var=0.05))
    o.append(paint(box("Nosing", (W + 0.3, 0.08, 0.08), (0, yf - 0.17, 3.7), 0.03, 2), BRASS10, "chrome"))
    # riser between the ledge and the lower work surface, then the work surface (staff side)
    o.append(paint(box("Riser", (W - 0.2, 0.22, 0.95), (0, yf + 1.1, 3.25), 0.03, 2), OAK10_DK))
    o.append(paint(box("Work", (W - 0.1, 1.85, 0.14), (0, 0.67, 2.98), 0.04, 2), (204, 154, 104)))
    # staff side: drawer fronts and a kick
    for x in (-4.5, -1.5, 1.5, 4.5):
        o.append(paint(box("Drawer", (2.6, 0.1, 0.8), (x, D / 2 - 0.02, 2.4), 0.04, 2), OAK10))
        o.append(paint(box("Pull", (0.8, 0.1, 0.1), (x, D / 2 + 0.05, 2.45), 0.03, 2), BRASS10, "chrome"))
        o.append(paint(box("Door", (2.6, 0.1, 1.55), (x, D / 2 - 0.02, 1.15), 0.04, 2), OAK10_DK))
    # a brass foot rail along the front
    o.append(paint(tube("FootRail", [(-W / 2 + 0.6, yf - 0.42, 0.62), (W / 2 - 0.6, yf - 0.42, 0.62)], 0.08, 12), BRASS10, "chrome"))
    for x in (-W / 2 + 0.9, -2.0, 2.0, W / 2 - 0.9):
        o.append(paint(tube("RailPost", [(x, yf - 0.42, 0.62), (x, yf - 0.02, 0.62)], 0.06, 10), BRASS10, "chrome"))
    # three staff stations: monitor (screen faces the staff, +Y) and keyboard
    for x in (-3.4, 0.0, 3.4):
        o.append(paint(box("MonFoot", (0.9, 0.62, 0.06), (x, 0.55, 3.08), 0.03, 2), INK10))
        o.append(paint(box("MonNeck", (0.18, 0.14, 0.75), (x, 0.42, 3.45), 0.04, 2), (54, 56, 62)))
        o.append(paint(box("MonBack", (1.86, 0.2, 1.14), (x, 0.24, 4.18), 0.08, 3), INK10))
        o.append(paint(box("Bezel", (1.95, 0.08, 1.22), (x, 0.36, 4.18), 0.04, 2), (22, 24, 28)))
        o.append(paint(box("Screen", (1.78, 0.03, 1.06), (x, 0.405, 4.19), 0.01, 1), (120, 200, 236), "glow"))
        o.append(paint(box("Keyboard", (1.45, 0.5, 0.07), (x, 1.05, 3.085), 0.03, 2), (44, 46, 52)))
        o.append(paint(box("Keys", (1.32, 0.38, 0.03), (x, 1.05, 3.13), 0.01, 1), (86, 90, 98)))
        o.append(paint(box("Mouse", (0.18, 0.28, 0.08), (x + 1.05, 1.05, 3.09), 0.04, 2), (44, 46, 52)))
    # on the ledge: a brass service bell, an open guest book, a banker's lamp and an orchid
    o.append(paint(cyl("BellBase", 0.3, 0.08, (1.7, yf + 0.45, 4.02), 28, 0.02), INK10))
    o.append(paint(lathe("Bell", [(0, 0), (0.27, 0), (0.26, 0.06), (0.2, 0.2), (0.1, 0.27), (0, 0.29)], (1.7, yf + 0.45, 4.06), 28), BRASS10, "chrome"))
    o.append(paint(cyl("Plunger", 0.035, 0.12, (1.7, yf + 0.45, 4.4), 10, 0), BRASS10, "chrome"))
    for sx, rz in ((-1, 6), (1, -6)):
        page = box("Page", (0.62, 0.86, 0.06), (-1.9 + sx * 0.33, yf + 0.45, 4.03), 0.02, 2, (0, math.radians(sx * -5), 0))
        o.append(paint(page, PAPER10, var=0.02))
    o.append(paint(box("Cover", (1.36, 0.92, 0.04), (-1.9, yf + 0.45, 3.99), 0.02, 2), (122, 34, 40)))
    o.append(paint(box("Ribbon", (0.05, 0.5, 0.02), (-1.9, yf + 0.1, 4.0), 0.0), (214, 170, 80)))
    lx = 5.1
    o.append(paint(lathe("LampBase", [(0, 0), (0.32, 0), (0.33, 0.05), (0.22, 0.1), (0.06, 0.14), (0, 0.14)], (lx, yf + 0.5, 3.98), 28), BRASS10, "chrome"))
    o.append(paint(tube("LampArm", [(lx, yf + 0.5, 4.1), (lx, yf + 0.5, 4.8), (lx, yf + 0.38, 4.86)], 0.04, 8), BRASS10, "chrome"))
    shade_ob = box("Shade", (0.95, 0.42, 0.24), (lx, yf + 0.36, 4.9), 0.18, 5)
    o.append(paint(shade_ob, EMERALD, var=0.03))
    o.append(paint(box("ShadeGlow", (0.8, 0.3, 0.03), (lx, yf + 0.36, 4.77), 0.01, 1), (255, 226, 170), "glow"))
    ox = -5.15
    o.append(paint(lathe("OrchidPot", [(0, 0), (0.22, 0), (0.28, 0.42), (0.26, 0.44), (0, 0.44)], (ox, yf + 0.5, 3.98), 24), (240, 238, 232)))
    for i in range(5):
        a = i / 5 * math.tau
        lf = sphere("Leaf", 0.2, (0, 0, 0), (1.4, 0.5, 0.22), 2)
        lf.rotation_euler = (0, 0, a)
        lf.location = (ox + 0.2 * math.cos(a), yf + 0.5 + 0.2 * math.sin(a), 4.45)
        bake_xform(lf)
        o.append(paint(lf, (70, 128, 72)))
    o.append(paint(tube("Stem", bend_path([(ox, yf + 0.5, 4.4), (ox + 0.05, yf + 0.5, 5.3), (ox + 0.4, yf + 0.5, 5.5)], 0.25), 0.025, 6), (90, 120, 70)))
    for i, t in enumerate((0.0, 0.33, 0.66, 1.0)):
        p = (ox + 0.1 + 0.32 * t, yf + 0.44 - 0.04 * i, 5.42 + 0.1 * math.sin(t * 3))
        b = sphere("Bloom", 0.11, p, (1.2, 0.5, 1.0), 2)
        o.append(paint(b, (236, 150, 196) if i % 2 == 0 else (246, 196, 226)))
    return o
