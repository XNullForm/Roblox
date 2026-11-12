"""Run a Hotel props. Headless:
  blender -b --factory-startup -P rah_props.py -- [prop ...] [--render]
Builds each prop around its floor-centre origin (1 Blender metre = 1 stud, Z up, -Y = the prop's
front = Roblox +Z), paints vertex colours per piece, bakes AO into them, and writes one v3 JSON per
material group to export/<Prop>_<group>.json (groups: main, chrome, glass, glow) plus
export/<Prop>.manifest.json. DevTools.MeshImporter in Studio uploads them.
"""
import bpy, bmesh, math, json, os, sys, random
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "export")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- helpers

def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def _new(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_mods(ob):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def bake_xform(ob):
    bpy.context.view_layer.update()
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = Matrix.Identity(4)
    return ob


def shade(ob, angle=40):
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for e in bm.edges:
        e.smooth = True
        if len(e.link_faces) == 2 and e.link_faces[0].normal.angle(e.link_faces[1].normal, 0) > math.radians(angle):
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    return ob


def box(name, size, loc, bevel=0.05, segs=4, rot=(0, 0, 0), cuts=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if cuts:
        # grid first, then bevel only the real corners (ANGLE limit skips the flat grid edges)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    ob = _new(name, bm)
    if bevel > 0:
        m = ob.modifiers.new("bv", "BEVEL")
        m.width = min(bevel, min(size) * 0.49)
        m.segments = segs
        m.limit_method = "ANGLE" if cuts else "NONE"
        m.angle_limit = math.radians(30)
        apply_mods(ob)
    ob.location = loc
    ob.rotation_euler = rot
    bake_xform(ob)
    return shade(ob)


def cyl(name, r, h, loc, n=32, bevel=0.02, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r, radius2=r, depth=h)
    ob = _new(name, bm)
    if bevel > 0:
        m = ob.modifiers.new("bv", "BEVEL")
        m.width = bevel
        m.segments = 2
        m.limit_method = "ANGLE"
        apply_mods(ob)
    ob.location = loc
    ob.rotation_euler = rot
    bake_xform(ob)
    return shade(ob, 50)


def sphere(name, r, loc, scale=(1, 1, 1), sub=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    ob = _new(name, bm)
    ob.location = loc
    ob.scale = scale
    bake_xform(ob)
    return shade(ob, 80)


def lathe(name, prof, loc=(0, 0, 0), N=40, angle=50, sy=1.0):
    bm = bmesh.new()
    rows = []
    for j in range(N):
        t = 2 * math.pi * j / N
        rows.append([bm.verts.new((r * math.cos(t), r * math.sin(t) * sy, z)) for r, z in prof])
    for j in range(N):
        a, b = rows[j], rows[(j + 1) % N]
        for k in range(len(prof) - 1):
            if prof[k][0] < 1e-6:
                bm.faces.new((a[k], b[k + 1], a[k + 1]))
            elif prof[k + 1][0] < 1e-6:
                bm.faces.new((a[k], b[k], a[k + 1]))
            else:
                bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = _new(name, bm)
    ob.location = loc
    bake_xform(ob)
    return shade(ob, angle)


def tube(name, pts, radius, res=10, caps=True):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1)
    cu.bevel_depth = radius
    cu.bevel_resolution = res // 2
    cu.use_fill_caps = caps
    tmp = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(cu)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return shade(ob, 60)


def bend_path(corners, r, n=6):
    out = [Vector(corners[0])]
    for i in range(1, len(corners) - 1):
        a, b, d = Vector(corners[i - 1]), Vector(corners[i]), Vector(corners[i + 1])
        u, w = (a - b).normalized(), (d - b).normalized()
        p0, p1 = b + u * r, b + w * r
        for k in range(n + 1):
            t = k / n
            out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * b + t ** 2 * p1)
    out.append(Vector(corners[-1]))
    return out


def wobble(ob, amp, freq, seed=0.0, mask=None):
    """Push vertices along their normals by noise (cloth wrinkles, crumples)."""
    me = ob.data
    off = Vector((seed * 1.7, seed * 3.1, seed * 0.7))
    for v in me.vertices:
        if mask and not mask(v.co):
            continue
        d = noise.noise(v.co * freq + off) + 0.5 * noise.noise(v.co * freq * 2.3 + off * 2)
        v.co += v.normal * d * amp
    me.update()
    return ob


def puff(ob, hx, hy, amount):
    """Pillow/cushion bulge: thicker in the middle, pinched at the seams."""
    me = ob.data
    c = sum((v.co for v in me.vertices), Vector()) / len(me.vertices)
    for v in me.vertices:
        u = min(abs(v.co.x - c.x) / hx, 1)
        w = min(abs(v.co.y - c.y) / hy, 1)
        k = (1 - u * u) * (1 - w * w)
        dz = v.co.z - c.z
        v.co.z = c.z + dz * (1 - amount + amount * (0.35 + 0.65 * k) * 1.0) + (amount * 0.6 * k if dz > 0 else -amount * 0.6 * k) * 0.5
    me.update()
    return ob


# ---------------------------------------------------------------- colour

def lin(c):
    return tuple(((x / 255.0) ** 2.2) if x > 1 else x ** 2.2 for x in c)


def paint(ob, rgb, group="main", var=0.05, grad=None):
    """Store an sRGB colour (0..1 or 0..255) per corner in 'Col' (kept in sRGB; the bake is lifted)."""
    rgb = tuple(x / 255.0 if max(rgb) > 1 else x for x in rgb)
    me = ob.data
    col = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    seed = random.random() * 50
    for li, loop in enumerate(me.loops):
        p = me.vertices[loop.vertex_index].co
        k = 1 + var * noise.noise(p * 0.9 + Vector((seed, 2, 3)))
        c = Vector(rgb) * k
        if grad:
            c = grad(p, c)
        col.data[li].color = (c.x, c.y, c.z, 1)
    ob["group"] = group
    return ob


PROPS = {}


def prop(fn):
    PROPS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------- props

WOOD = (168, 104, 62)
WOOD_DK = (104, 62, 38)
WHITE = (244, 242, 238)
CERAMIC = (248, 248, 246)
CHROME = (225, 228, 232)
GLASS = (205, 232, 240)


@prop
def Bed():
    """Single hotel bed, 5.8 x 8.6, head at +Y (back)."""
    o = []
    # round 10e: finer grids (cuts) on the big parts so the baked shading stays crisp up close
    o.append(paint(box("Base", (5.8, 8.4, 1.0), (0, 0, 0.85), 0.18, cuts=3), WOOD))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Leg", 0.22, 0.4, (sx * 2.5, sy * 3.8, 0.2), 16), WOOD_DK))
    o.append(paint(box("Mattress", (5.4, 8.1, 0.95), (0, 0.05, 1.8), 0.32, 5, cuts=5), WHITE, var=0.02))
    # headboard: wood frame + four channel-tufted fabric panels
    o.append(paint(box("Headboard", (6.2, 0.55, 4.9), (0, 4.42, 2.45), 0.2, cuts=4), WOOD))
    for i in range(4):
        x = -2.1 + i * 1.4
        o.append(paint(box("Panel", (1.3, 0.4, 3.0), (x, 4.12, 3.15), 0.3, 6, cuts=3), (122, 156, 150), var=0.04))
    # duvet: draped box over the mattress, gentle wrinkles
    duv = box("Duvet", (5.9, 5.9, 1.45), (0, -1.2, 1.72), 0.35, 5, cuts=11)
    wobble(duv, 0.05, 0.9, 1.0)
    o.append(paint(duv, (246, 226, 196), var=0.03))
    o.append(paint(box("Fold", (5.95, 1.0, 1.5), (0, 1.75, 1.75), 0.4, 5, cuts=5), WHITE, var=0.02))
    o.append(paint(box("Runner", (6.0, 1.7, 1.52), (0, -3.0, 1.73), 0.38, 5, cuts=5), (196, 104, 74), var=0.04))
    for x in (-1.3, 1.3):
        p = box("Pillow", (2.3, 1.35, 0.7), (x, 3.2, 2.55), 0.32, 6, cuts=2)
        puff(p, 1.15, 0.68, 0.45)
        p.rotation_euler = (math.radians(-12), 0, 0)
        bake_xform(p)
        o.append(paint(p, WHITE, var=0.02))
    return o


@prop
def BedMessy():
    """The same bed after a guest: crumpled duvet pulled down, pillows knocked about."""
    o = []
    o.append(paint(box("Base", (5.8, 8.4, 1.0), (0, 0, 0.85), 0.18), WOOD))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(cyl("Leg", 0.22, 0.4, (sx * 2.5, sy * 3.8, 0.2), 16), WOOD_DK))
    o.append(paint(box("Mattress", (5.4, 8.1, 0.95), (0, 0.05, 1.8), 0.32, 5), (236, 232, 222), var=0.03))
    o.append(paint(box("Headboard", (6.2, 0.55, 4.9), (0, 4.42, 2.45), 0.2), WOOD))
    for i in range(4):
        x = -2.1 + i * 1.4
        o.append(paint(box("Panel", (1.3, 0.4, 3.0), (x, 4.12, 3.15), 0.3, 6), (122, 156, 150), var=0.04))
    duv = box("Duvet", (6.1, 4.2, 1.9), (0.25, -2.2, 1.85), 0.5, 5, cuts=8)
    duv.rotation_euler = (0, 0, math.radians(7))
    bake_xform(duv)
    wobble(duv, 0.32, 0.75, 4.0)
    o.append(paint(duv, (240, 216, 184), var=0.06))
    heap = sphere("Heap", 1.4, (-1.4, 0.6, 2.4), (1.4, 1.0, 0.45), 3)
    wobble(heap, 0.22, 1.2, 7.0)
    o.append(paint(heap, (240, 216, 184), var=0.06))
    for x, rz, rx, y in ((-1.0, 25, -40, 3.0), (1.9, -50, 8, 2.2)):
        p = box("Pillow", (2.3, 1.35, 0.7), (0, 0, 0), 0.32, 6, cuts=2)
        puff(p, 1.15, 0.68, 0.45)
        p.location = (x, y, 2.6)
        p.rotation_euler = (math.radians(rx), 0, math.radians(rz))
        bake_xform(p)
        wobble(p, 0.06, 1.5, x)
        o.append(paint(p, WHITE, var=0.03))
    return o


def tiles(name, w, h, origin, axis, tile=0.95, gap=0.07, colors=((236, 244, 242), (226, 238, 236), (244, 248, 246))):
    """A wall of glazed tiles. axis 'y' = tiles face -Y at y=origin[1]; 'x' = tiles face -X."""
    o = []
    nx, nz = int(w / tile), int(h / tile)
    for i in range(nx):
        for j in range(nz):
            u = -w / 2 + tile * (i + 0.5)
            v = tile * (j + 0.5)
            if axis == "y":
                loc = (origin[0] + u, origin[1], origin[2] + v)
                sz = (tile - gap, 0.12, tile - gap)
            else:
                loc = (origin[0], origin[1] + u, origin[2] + v)
                sz = (0.12, tile - gap, tile - gap)
            t = box(name, sz, loc, 0.035, 1)
            o.append(paint(t, random.choice(colors), var=0.02))
    return o


@prop
def Shower():
    """5.2 x 5.2 corner shower. Back wall at +Y, side wall at +X, glass on -Y and -X."""
    random.seed(3)
    o = []
    o.append(paint(box("Tray", (5.2, 5.2, 0.38), (0, 0, 0.19), 0.12), CERAMIC, var=0.01))
    o.append(paint(cyl("Drain", 0.32, 0.03, (0, 0, 0.39), 24, 0), CHROME, "chrome"))
    # grout backing + tiles on the two wall sides
    o.append(paint(box("GroutB", (5.2, 0.2, 8.4), (0, 2.5, 4.6), 0.03), (176, 184, 186)))
    o.append(paint(box("GroutR", (0.2, 5.0, 8.4), (2.5, -0.1, 4.6), 0.03), (176, 184, 186)))
    o += tiles("TileB", 5.0, 8.3, (0, 2.36, 0.42), "y")
    o += tiles("TileR", 4.75, 8.3, (2.36, -0.22, 0.42), "x")
    # glass: front fixed panel + door, left panel
    o.append(paint(box("GlassL", (0.1, 4.9, 7.2), (-2.5, -0.05, 4.05), 0.03), GLASS, "glass"))
    o.append(paint(box("GlassF", (2.4, 0.1, 7.2), (-1.25, -2.5, 4.05), 0.03), GLASS, "glass"))
    o.append(paint(box("GlassD", (2.45, 0.1, 7.2), (1.25, -2.62, 4.05), 0.03), GLASS, "glass"))
    # chrome frame and door handle
    for pts in (
        [(-2.5, 2.45, 7.66), (-2.5, -2.5, 7.66), (2.45, -2.5, 7.66)],
        [(-2.5, -2.5, 0.42), (-2.5, -2.5, 7.66)],
    ):
        o.append(paint(tube("Frame", pts, 0.07, 8), CHROME, "chrome"))
    o.append(paint(tube("Handle", [(0.4, -2.72, 3.2), (0.4, -2.85, 3.3), (0.4, -2.85, 4.6), (0.4, -2.72, 4.7)], 0.06, 8), CHROME, "chrome"))
    # rain head on an arm, mixer valve
    o.append(paint(tube("Arm", bend_path([(0, 2.3, 7.2), (0, 2.3, 8.1), (0, 0.5, 8.1)], 0.35), 0.09, 10), CHROME, "chrome"))
    o.append(paint(cyl("Head", 0.85, 0.14, (0, 0.5, 7.98), 40, 0.05), CHROME, "chrome"))
    o.append(paint(cyl("Rose", 0.75, 0.02, (0, 0.5, 7.9), 40, 0), (90, 96, 104), "chrome"))
    o.append(paint(cyl("Valve", 0.42, 0.18, (0, 2.24, 3.8), 32, 0.05, (math.pi / 2, 0, 0)), CHROME, "chrome"))
    o.append(paint(box("Lever", (0.14, 0.5, 0.14), (0, 2.0, 3.8), 0.06, 3, (0, 0, 0)), CHROME, "chrome"))
    o.append(paint(box("Lever2", (0.12, 0.12, 0.7), (0, 1.78, 3.55), 0.05, 3), CHROME, "chrome"))
    # little corner shelf with bottles
    o.append(paint(box("Shelf", (0.9, 1.2, 0.1), (2.0, 1.5, 4.5), 0.03), CHROME, "chrome"))
    for i, (c, h) in enumerate((((236, 120, 140), 0.8), ((110, 180, 220), 0.65), ((250, 210, 110), 0.55))):
        b = lathe("Bottle", [(0, 0), (0.17, 0), (0.18, 0.05), (0.18, h - 0.15), (0.1, h - 0.05), (0.06, h), (0, h)], (2.0, 1.15 + i * 0.35, 4.55), 16)
        o.append(paint(b, c))
    return o


@prop
def Toilet():
    """Close-coupled toilet, back against +Y, seat top at ~1.55."""
    o = []
    bowl = lathe("Bowl", [(0, 0), (0.6, 0), (0.62, 0.06), (0.52, 0.45), (0.56, 0.9), (0.78, 1.2), (0.92, 1.36), (0.9, 1.44),
                          (0.78, 1.46), (0.68, 1.3), (0.38, 1.02), (0, 0.98)], (0, -0.35, 0), 40, 40, sy=1.32)
    o.append(paint(bowl, CERAMIC, var=0.01))
    o.append(paint(box("Neck", (1.3, 1.1, 1.2), (0, 0.55, 0.85), 0.35, 5), CERAMIC, var=0.01))
    seat = lathe("Seat", [(0.66, 1.46), (0.95, 1.46), (0.98, 1.5), (0.95, 1.56), (0.7, 1.56), (0.64, 1.51), (0.66, 1.46)], (0, -0.35, 0), 40, 40, sy=1.3)
    o.append(paint(seat, (252, 252, 250), var=0.01))
    lid = lathe("Lid", [(0, 0), (0.9, 0), (0.95, 0.05), (0.93, 0.12), (0.8, 0.15), (0, 0.15)], (0, 0, 0), 40, 40, sy=1.3)
    lid.rotation_euler = (math.radians(-82), 0, 0)
    lid.location = (0, 0.82, 2.72)
    bake_xform(lid)
    o.append(paint(lid, (252, 252, 250), var=0.01))
    o.append(paint(box("Hinge", (1.2, 0.3, 0.16), (0, 0.85, 1.55), 0.06, 3), CHROME, "chrome"))
    o.append(paint(box("Tank", (2.0, 0.85, 1.8), (0, 1.35, 2.25), 0.18, 5), CERAMIC, var=0.01))
    o.append(paint(box("TankLid", (2.12, 0.98, 0.2), (0, 1.35, 3.22), 0.08, 3), CERAMIC, var=0.01))
    o.append(paint(cyl("Flush", 0.2, 0.06, (0, 1.35, 3.34), 24, 0.02), CHROME, "chrome"))
    # wall roll holder beside it
    o.append(paint(box("RollPlate", (0.5, 0.08, 0.5), (1.65, 1.74, 2.0), 0.04, 3), CHROME, "chrome"))
    o.append(paint(cyl("RollBar", 0.05, 0.7, (1.65, 1.4, 2.0), 12, 0, (math.pi / 2, 0, 0)), CHROME, "chrome"))
    o.append(paint(cyl("Roll", 0.3, 0.42, (1.65, 1.35, 1.95), 24, 0.04, (math.pi / 2, 0, 0)), WHITE, var=0.02))
    return o


@prop
def Nightstand():
    o = []
    o.append(paint(box("Body", (1.9, 1.7, 2.1), (0, 0, 1.25), 0.1), WOOD))
    for sx in (-1, 1):
        for sy in (-1, 1):
            o.append(paint(box("Leg", (0.18, 0.18, 0.25), (sx * 0.8, sy * 0.7, 0.12), 0.04, 2), WOOD_DK))
    o.append(paint(box("Drawer", (1.6, 0.1, 0.8), (0, -0.86, 1.55), 0.06), (190, 126, 80)))
    o.append(paint(box("Knob", (0.4, 0.12, 0.1), (0, -0.95, 1.55), 0.04, 3), (212, 176, 96), "chrome"))
    o.append(paint(lathe("LampBase", [(0, 0), (0.35, 0), (0.38, 0.06), (0.42, 0.35), (0.3, 0.75), (0.08, 0.9), (0.08, 1.2), (0, 1.2)], (0.1, 0.1, 2.3), 28), (90, 140, 150)))
    o.append(paint(lathe("Shade", [(0.55, 0), (0.6, 0.02), (0.42, 0.78), (0.38, 0.8), (0.4, 0.76), (0.56, 0.04), (0.5, 0.02)], (0.1, 0.1, 3.3), 32), (252, 238, 210), "glow"))
    o.append(paint(box("Book", (0.75, 0.55, 0.14), (-0.45, -0.2, 2.37), 0.03, 2, (0, 0, 0.3)), (176, 64, 60)))
    return o


@prop
def Desk():
    """Reception desk 11 wide, guests stand at -Y, staff behind at +Y."""
    o = []
    o.append(paint(box("Kick", (10.6, 2.6, 0.4), (0, 0.1, 0.2), 0.05), (60, 54, 52)))
    # slatted wooden front
    o.append(paint(box("Core", (10.8, 2.8, 3.4), (0, 0.2, 2.1), 0.1), (236, 232, 226)))
    for i in range(27):
        x = -5.2 + i * 0.4
        o.append(paint(box("Slat", (0.26, 0.2, 3.2), (x, -1.25, 2.1), 0.08, 3), WOOD, var=0.08))
    o.append(paint(box("Top", (11.4, 1.6, 0.28), (0, -0.85, 3.95), 0.1), (246, 244, 240)))
    o.append(paint(box("Work", (10.6, 2.2, 0.2), (0, 0.6, 3.0), 0.06), (210, 160, 110)))
    o.append(paint(box("Band", (11.42, 1.62, 0.08), (0, -0.85, 3.78), 0.03), (212, 176, 96), "chrome"))
    # computer
    o.append(paint(box("Monitor", (2.2, 0.16, 1.35), (-2.2, 0.75, 4.25), 0.06), (40, 42, 48)))
    o.append(paint(box("Screen", (2.0, 0.04, 1.15), (-2.2, 0.66, 4.27), 0.02), (80, 200, 220), "glow"))
    o.append(paint(box("Stand", (0.2, 0.2, 0.7), (-2.2, 0.9, 3.45), 0.05), (60, 62, 68)))
    o.append(paint(box("Foot", (0.9, 0.6, 0.06), (-2.2, 0.9, 3.13), 0.03), (60, 62, 68)))
    o.append(paint(box("Keys", (1.6, 0.55, 0.08), (-2.2, 0.0, 3.14), 0.03), (230, 230, 232)))
    # bell + small succulent
    o.append(paint(cyl("BellBase", 0.32, 0.08, (1.6, -0.9, 4.13), 24, 0.02), (60, 54, 52)))
    o.append(paint(sphere("Bell", 0.3, (1.6, -0.9, 4.17), (1, 1, 0.75), 3), (212, 176, 96), "chrome"))
    o.append(paint(lathe("Pot", [(0, 0), (0.28, 0), (0.34, 0.45), (0, 0.45)], (4.2, -0.8, 4.09), 20), (230, 226, 220)))
    for i in range(7):
        a = i / 7 * math.tau
        l = sphere("Leaf", 0.16, (4.2 + 0.12 * math.cos(a), -0.8 + 0.12 * math.sin(a), 4.62 + 0.05 * (i % 2)), (1.0, 0.55, 1.4), 2)
        o.append(paint(l, (96, 156, 92)))
    return o


@prop
def Sofa():
    """Three-seat lobby sofa, seat front at -Y."""
    o = []
    VEL = (64, 140, 150)
    o.append(paint(box("Base", (8.0, 3.2, 1.0), (0, 0, 1.1), 0.25), VEL))
    for sx in (-1, 1):
        o.append(paint(box("Arm", (0.8, 3.3, 2.2), (sx * 3.9, 0.05, 1.7), 0.38, 5), VEL))
        for sy in (-1, 1):
            o.append(paint(lathe("Leg", [(0, 0), (0.1, 0), (0.15, 0.6), (0, 0.6)], (sx * 3.6, sy * 1.3, 0), 12), WOOD_DK))
    o.append(paint(box("Back", (7.6, 0.9, 2.6), (0, 1.25, 2.2), 0.4, 5), VEL))
    for i in range(3):
        x = -2.33 + i * 2.33
        c = box("Seat", (2.3, 2.6, 0.75), (x, -0.25, 1.95), 0.3, 6, cuts=2)
        puff(c, 1.15, 1.3, 0.3)
        o.append(paint(c, (74, 152, 162), var=0.04))
        b = box("BackC", (2.25, 0.8, 1.9), (x, 0.6, 2.95), 0.36, 6, cuts=2)
        b.rotation_euler = (math.radians(-10), 0, 0)
        bake_xform(b)
        o.append(paint(b, (74, 152, 162), var=0.04))
    p = box("Throw", (1.6, 0.9, 1.4), (2.4, 0.5, 3.0), 0.35, 6, cuts=2)
    puff(p, 0.8, 0.45, 0.4)
    p.rotation_euler = (math.radians(-15), math.radians(10), 0)
    bake_xform(p)
    o.append(paint(p, (238, 186, 92), var=0.04))
    return o


@prop
def CoffeeTable():
    o = []
    o.append(paint(lathe("Top", [(0, 0), (1.9, 0), (1.95, 0.08), (1.95, 0.18), (1.9, 0.24), (0, 0.24)], (0, 0, 1.36), 48), (246, 244, 240)))
    o.append(paint(lathe("Stem", [(0, 0), (1.0, 0), (1.0, 0.08), (0.22, 0.2), (0.18, 1.36), (0, 1.36)], (0, 0, 0), 32), (212, 176, 96), "chrome"))
    for i, c in enumerate(((210, 90, 80), (70, 120, 170))):
        o.append(paint(box("Mag", (1.0, 1.3, 0.05), (-0.4 + i * 0.25, 0.2 - i * 0.15, 1.63 + i * 0.05), 0.02, 2, (0, 0, 0.3 + i * 0.5)), c))
    return o


def leaf(name, length, width, slits=4):
    """Monstera-ish leaf in its own frame: stalk at origin, blade along +Y, with side slits."""
    bm = bmesh.new()
    N = 22
    rows = []
    for i in range(N + 1):
        t = i / N
        y = t * length
        hw = width * math.sin(math.pi * min(t * 1.05, 1)) ** 0.7 * (1.0 if t > 0.12 else t / 0.12 * 0.7 + 0.3)
        row = []
        for j in range(-4, 5):
            s = j / 4
            x = s * hw
            z = -0.18 * width * s * s + 0.12 * length * math.sin(math.pi * t) - 0.18 * length * t * t
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(N):
        for j in range(8):
            # leave slits: drop the outer quads on some rows
            if slits and j in (0, 7) and i % 4 == 2 and 3 < i < N - 3:
                continue
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    ob = _new(name, bm)
    m = ob.modifiers.new("sol", "SOLIDIFY")
    m.thickness = 0.04
    apply_mods(ob)
    return shade(ob, 70)


@prop
def Plant():
    """Big potted monstera, 3 wide pot."""
    random.seed(7)
    o = []
    o.append(paint(lathe("Pot", [(0, 0), (1.05, 0), (1.25, 0.15), (1.45, 1.9), (1.55, 2.05), (1.5, 2.15), (1.3, 2.1), (0, 2.0)], (0, 0, 0), 40), (58, 60, 64), var=0.04))
    o.append(paint(lathe("Soil", [(0, 1.98), (1.32, 1.98), (1.32, 2.0), (0, 2.02)], (0, 0, 0), 40), (70, 50, 36)))
    for i in range(9):
        a = i / 9 * math.tau + random.uniform(-0.2, 0.2)
        h = random.uniform(3.2, 6.0)
        lean = random.uniform(0.9, 1.9)
        tip = Vector((math.cos(a) * lean, math.sin(a) * lean, h))
        mid = Vector((math.cos(a) * lean * 0.35, math.sin(a) * lean * 0.35, h * 0.6))
        o.append(paint(tube("Stem", [Vector((0, 0, 1.9)), mid, tip], 0.06, 6), (92, 130, 70)))
        L = random.uniform(2.0, 2.9)
        lf = leaf("Leaf", L, L * 0.48)
        lf.rotation_euler = (math.radians(random.uniform(-35, -10)), 0, a - math.pi / 2)
        lf.location = tip
        bake_xform(lf)
        g = random.uniform(0.85, 1.1)
        o.append(paint(lf, (int(70 * g), int(150 * g), int(66 * g)), var=0.08,
                       grad=lambda p, c, tz=tip.z: c * (0.8 + 0.25 * min(max((p.z - tz + 1) / 2, 0), 1))))
    return o


@prop
def FloorLamp():
    o = []
    o.append(paint(lathe("Base", [(0, 0), (0.85, 0), (0.88, 0.06), (0.8, 0.16), (0, 0.18)], (0, 0, 0), 40), (40, 40, 44)))
    o.append(paint(cyl("Pole", 0.08, 6.4, (0, 0, 3.3), 16, 0), (212, 176, 96), "chrome"))
    o.append(paint(lathe("Shade", [(1.05, 0), (1.1, 0.03), (0.9, 1.7), (0.85, 1.72), (0.88, 1.68), (1.02, 0.05), (0.98, 0.03)], (0, 0, 5.6), 40), (252, 240, 214), "glow"))
    return o


@prop
def WetSign():
    """Yellow A-frame cleaning sign; the faces carry SurfaceGui text in Studio."""
    o = []
    Y = (250, 200, 40)
    for s in (-1, 1):
        p = box("Panel", (2.2, 0.12, 3.4), (0, 0, 0), 0.06, 3)
        p.rotation_euler = (math.radians(s * 12), 0, 0)
        p.location = (0, s * 0.36, 1.68)
        bake_xform(p)
        o.append(paint(p, Y, var=0.03))
        f = box("Foot", (2.3, 0.3, 0.12), (0, s * 0.72, 0.06), 0.05, 2)
        o.append(paint(f, (40, 40, 40)))
    o.append(paint(box("Top", (1.4, 0.5, 0.35), (0, 0, 3.45), 0.15, 4), Y))
    o.append(paint(box("Grip", (0.9, 0.52, 0.18), (0, 0, 3.32), 0.06, 2), (40, 40, 40)))
    return o


@prop
def CashBundle():
    """One bundle of bills, 1.6 x 0.75 x 0.3. Stacked in Studio."""
    o = []
    b = box("Bills", (1.6, 0.75, 0.3), (0, 0, 0.15), 0.04, 2, cuts=3)
    wobble(b, 0.01, 4.0, 2)
    o.append(paint(b, (120, 172, 96), var=0.06))
    o.append(paint(box("Band", (0.4, 0.78, 0.32), (0, 0, 0.15), 0.03, 2), (246, 236, 200)))
    return o


@prop
def Towel():
    t = box("Towel", (1.8, 1.2, 0.18), (0, 0, 0.09), 0.08, 3, cuts=6)
    wobble(t, 0.12, 1.4, 5)
    return [paint(t, (250, 250, 248), var=0.04)]


@prop
def Trash():
    random.seed(11)
    o = []
    for i in range(3):
        s = sphere("Paper", 0.28, (i * 0.7 - 0.7, random.uniform(-0.3, 0.3), 0.24), (1, 1, 0.85), 2)
        wobble(s, 0.09, 4.0, i)
        o.append(paint(s, (240, 240, 236), var=0.08))
    c = cyl("Can", 0.2, 0.75, (0.6, 0.6, 0.2), 20, 0.03, (0, math.pi / 2, 0.6))
    o.append(paint(c, (210, 60, 60)))
    return o


@prop
def Rug():
    # round 10e: crisp borders as real geometry (vertex colours blurred them), a medallion and fringes
    o = [paint(box("Rug", (7.0, 5.0, 0.08), (0, 0, 0.04), 0.03, 2, cuts=16), (214, 176, 112), var=0.04)]
    o.append(paint(box("Cream", (6.3, 4.3, 0.09), (0, 0, 0.045), 0.0, 1, cuts=12), (240, 228, 204), var=0.03))
    o.append(paint(box("Field", (5.8, 3.8, 0.1), (0, 0, 0.05), 0.0, 1, cuts=16), (178, 92, 72), var=0.05))
    for sx in (-1, 1):
        o.append(paint(box("Band", (0.12, 3.3, 0.105), (sx * 2.45, 0, 0.0525), 0.0, 1), (226, 196, 132), var=0.02))
    for sy in (-1, 1):
        o.append(paint(box("Band", (4.9, 0.12, 0.105), (0, sy * 1.6, 0.0525), 0.0, 1), (226, 196, 132), var=0.02))
    med = cyl("Medallion", 0.95, 0.11, (0, 0, 0.055), 40, 0.0)
    med.scale = (1.35, 1.0, 1.0)
    bake_xform(med)
    o.append(paint(med, (232, 204, 140), var=0.03))
    inner = cyl("Inner", 0.6, 0.115, (0, 0, 0.0575), 40, 0.0)
    inner.scale = (1.35, 1.0, 1.0)
    bake_xform(inner)
    o.append(paint(inner, (40, 72, 92), var=0.03))
    for sx in (-1, 1):
        for i in range(22):
            y = -2.3 + i * (4.6 / 21)
            o.append(paint(box("Fringe", (0.28, 0.06, 0.03), (sx * 3.64, y, 0.015), 0.0, 1), (238, 230, 214), var=0.02))
    return o


exec(open(os.path.join(HERE, "rah_props_shop.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_city.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r9.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r10.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_kitchen.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r10c.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r10e.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r12.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r14.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r14b.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r14c.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r14d.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r14f.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r15.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r15b.py"), encoding="utf8").read())
exec(open(os.path.join(HERE, "rah_props_r16.py"), encoding="utf8").read())


# ---------------------------------------------------------------- AO + export

def setup_bake():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.light_settings.distance = 1.6
    sc.render.bake.target = "VERTEX_COLORS"
    sc.render.bake.use_selected_to_active = False


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


def bake_ao(ob):
    me = ob.data
    if not me.materials:
        mat = bpy.data.materials.get("Bake") or bpy.data.materials.new("Bake")
        me.materials.append(mat)
    ao = me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = ao
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="AO")
    col = me.color_attributes["Col"]
    for li in range(len(me.loops)):
        a = ao.data[li].color[0] ** 0.5
        k = 0.45 + 0.55 * a
        c = col.data[li].color
        col.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1)
    me.color_attributes.remove(ao)


def export(ob, fname):
    me = ob.data
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    me.update()
    col = me.color_attributes["Col"]
    cn = me.corner_normals
    pos = []
    for v in me.vertices:
        pos += [round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)]
    tri, tn, tc, tu = [], [], [], []
    nkey, ckey = {}, {}
    nrm, cols = [], []
    for poly in me.polygons:
        for li in poly.loop_indices:
            tri.append(me.loops[li].vertex_index)
            n = cn[li].vector
            k = (round(n.x, 3), round(n.z, 3), round(-n.y, 3))
            i = nkey.get(k)
            if i is None:
                i = nkey[k] = len(nkey)
                nrm += list(k)
            tn.append(i)
            c = col.data[li].color
            k = tuple(int(round(min(max(x, 0), 1) * 255)) for x in c[:3])
            i = ckey.get(k)
            if i is None:
                i = ckey[k] = len(ckey)
                cols += list(k)
            tc.append(i)
            tu.append(0)
    xs, ys, zs = pos[0::3], pos[1::3], pos[2::3]
    data = {"name": fname, "version": 3, "pos": pos, "tri": tri, "nrm": nrm, "tn": tn, "col": cols, "tc": tc,
            "uv": [0, 0], "tu": tu, "bmin": [min(xs), min(ys), min(zs)], "bmax": [max(xs), max(ys), max(zs)],
            "ntri": len(tri) // 3}
    with open(os.path.join(OUT, fname + ".json"), "w") as f:
        json.dump(data, f, separators=(",", ":"))
    return data


def build(name):
    clear_scene()
    objs = PROPS[name]()
    groups = {}
    for o in objs:
        groups.setdefault(o.get("group", "main"), []).append(o)
    joined = {g: join(lst, "%s_%s" % (name, g)) for g, lst in groups.items()}
    setup_bake()
    for g, ob in joined.items():
        bake_ao(ob)
    man = []
    for g, ob in joined.items():
        d = export(ob, "%s_%s" % (name, g))
        man.append({"file": "%s_%s" % (name, g), "group": g, "tris": d["ntri"], "bmin": d["bmin"], "bmax": d["bmax"]})
    with open(os.path.join(OUT, name + ".manifest.json"), "w") as f:
        json.dump(man, f)
    return joined, man


def render(name, joined):
    """Quick check render: colours shown through an attribute shader, 3/4 view."""
    sc = bpy.context.scene
    for ob in joined.values():
        mat = bpy.data.materials.new("Show")
        mat.use_nodes = True
        nt = mat.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        at = nt.nodes.new("ShaderNodeVertexColor")
        at.layer_name = "Col"
        nt.links.new(at.outputs[0], bsdf.inputs[0])
        g = ob.name.split("_")[-1]
        if g == "glass":
            bsdf.inputs["Alpha"].default_value = 0.35
        if g == "chrome":
            bsdf.inputs["Metallic"].default_value = 0.8
            bsdf.inputs["Roughness"].default_value = 0.2
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    xs = [v for ob in joined.values() for v in ob.bound_box]
    mn = Vector((min(p[0] for p in xs), min(p[1] for p in xs), min(p[2] for p in xs)))
    mx = Vector((max(p[0] for p in xs), max(p[1] for p in xs), max(p[2] for p in xs)))
    c = (mn + mx) / 2
    r = (mx - mn).length
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    d = Vector((-0.75, -1.0, 0.65)).normalized()
    cam.location = c + d * r * 1.35
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    sc.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-30))
    sc.collection.objects.link(sun)
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.82, 0.9, 1)
    bg.inputs[1].default_value = 0.8
    sc.cycles.samples = 24
    sc.render.resolution_x = 520
    sc.render.resolution_y = 420
    sc.render.filepath = os.path.join(OUT, "_render_%s.png" % name)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    want_render = "--render" in argv
    names = [a for a in argv if not a.startswith("--")] or list(PROPS)
    for n in names:
        random.seed(hash(n) & 0xffff)
        joined, man = build(n)
        print("BUILT", n, json.dumps(man))
        if want_render:
            render(n, joined)
