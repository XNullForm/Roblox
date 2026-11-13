"""Round 39b (2026-11-13): every UI icon remade as a Blender render in the build hammer's style (icon_hammer14.py):
glossy modelled props, the same three area lights, AgX, an ortho camera, then outline_icon.py adds the house outline.
blender -b --factory-startup -P icons39.py -- name1 name2 ...   (or "all")  ->  ui39/<name>_raw.png
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "ui39")
os.makedirs(OUTDIR, exist_ok=True)
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["all"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COL = bpy.data.collections.new("Icon")
scene.collection.children.link(COL)

# ---------------------------------------------------------------- materials
_mats = {}


def mat(base, rough=0.35, metal=0.0, coat=0.5, emit=0.0, glass=False, alpha=1.0, key=None):
    k = key or (tuple(round(c, 3) for c in base), rough, metal, coat, emit, glass, alpha)
    if k in _mats:
        return _mats[k]
    m = bpy.data.materials.new("M%d" % len(_mats))
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    for name, v in (("Coat Weight", coat), ("Transmission Weight", 1.0 if glass else 0.0), ("IOR", 1.45), ("Alpha", alpha)):
        try:
            b.inputs[name].default_value = v
        except KeyError:
            pass
    if emit:
        b.inputs["Emission Color"].default_value = (*base, 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[k] = m
    return m


def rgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)  # sRGB -> linear


def P(h, **kw):  # glossy plastic
    return mat(rgb(h), **kw)


WHITE = P("f4f2ee", rough=0.3)
INK = P("2a2733", rough=0.4)
GOLD = mat(rgb("ffc23a"), rough=0.3, metal=0.65, coat=0.4)
SILVER = mat(rgb("d8dde6"), rough=0.2, metal=1.0, coat=0.1)
STEEL = mat(rgb("9aa3b0"), rough=0.3, metal=1.0, coat=0.0)
WOOD = P("b06a35", rough=0.45, coat=0.4)
WOODD = P("7a4424", rough=0.5, coat=0.3)
SKIN = P("f1c39b", rough=0.45, coat=0.2)
GLASS = mat(rgb("cfe9ff"), rough=0.05, glass=True, coat=0.0)
RED = P("e8443a")
GREEN = P("3cc35a")
BLUE = P("3a8ef0")
YELLOW = P("ffc83a")
ORANGE = P("ff8a2a")
PINK = P("ff6fa5")
PURPLE = P("8a5cf0")
TEAL = P("2fbfae")
BROWN = P("8b5a36")
GREY = P("9ba3b4")
DARK = P("3b3f4c")
CREAM = P("fff1d2")
GLOW = mat(rgb("fff2b0"), emit=4.0, rough=0.4, coat=0.0)

# ---------------------------------------------------------------- primitives (Z up, the front faces -Y)


def _link(o):
    COL.objects.link(o)
    return o


def _fin(o, m, bevel=0.0, seg=4, smooth=True, angle=False):
    if m:
        o.data.materials.append(m)
    if bevel:
        md = o.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = seg
        md.limit_method = "ANGLE" if angle else "NONE"
        if angle:
            md.angle_limit = math.radians(30)
    if smooth and o.type == "MESH":
        for p in o.data.polygons:
            p.use_smooth = True
        try:
            o.data.shade_smooth()
        except Exception:
            pass
        if bevel:
            try:
                md2 = o.modifiers.new("WN", "WEIGHTED_NORMAL")
                md2.keep_sharp = False
            except Exception:
                pass
    return o


def _place(o, loc, rot, scale=None):
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    if scale:
        o.scale = scale
    return o


def mesh_from_bm(bm, name="m"):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _link(bpy.data.objects.new(name, me))


def box(size, loc=(0, 0, 0), m=WHITE, rot=(0, 0, 0), bevel=0.06):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    o = mesh_from_bm(bm, "box")
    _fin(o, m, min(bevel, min(size) * 0.45), smooth=True)
    return _place(o, loc, rot)


def cyl(r, h, loc=(0, 0, 0), m=WHITE, rot=(0, 0, 0), bevel=0.04, seg=64, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = mesh_from_bm(bm, "cyl")
    _fin(o, m, min(bevel, h * 0.45, r * 0.45) if bevel else 0, angle=True)
    return _place(o, loc, rot)


def disc(r, h, loc=(0, 0, 0), m=WHITE, bevel=0.06):  # a cylinder facing the camera
    return cyl(r, h, loc, m, rot=(90, 0, 0), bevel=bevel)


def sph(r, loc=(0, 0, 0), m=WHITE, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=r)
    o = mesh_from_bm(bm, "sph")
    _fin(o, m)
    return _place(o, loc, rot, scale)


def tor(R, r, loc=(0, 0, 0), m=WHITE, rot=(0, 0, 0), arc=360, start=0):
    pts = []
    n = max(8, int(64 * arc / 360))
    for i in range(n + 1 if arc < 360 else n):
        a = math.radians(start + arc * i / n)
        pts.append((R * math.cos(a), R * math.sin(a), 0))
    o = tube(pts, r, m, closed=arc >= 360)
    return _place(o, loc, rot)


def tube(pts, r, m=WHITE, closed=False, caps=True):
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 6
    cu.use_fill_caps = caps
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = closed
    o = _link(bpy.data.objects.new("tube", cu))
    o.data.materials.append(m)
    return o


def lathe(profile, loc=(0, 0, 0), m=WHITE, rot=(0, 0, 0), seg=64, sxy=(1, 1)):
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg) * sxy[0], r * math.sin(2 * math.pi * i / seg) * sxy[1], z)) for i in range(seg)])
    for k in range(len(rings) - 1):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    o = mesh_from_bm(bm, "lathe")
    _fin(o, m)
    return _place(o, loc, rot)


def shape(pts, depth, loc=(0, 0, 0), m=WHITE, rot=(0, 0, 0), bevel=0.05, scale=1.0):
    """extrude a 2D outline (x, z) toward +Y (the back), centred on y"""
    bm = bmesh.new()
    vs = [bm.verts.new((x * scale, -depth / 2, z * scale)) for x, z in pts]
    f = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in nv:
        v.co.y += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    o = mesh_from_bm(bm, "shape")
    _fin(o, m, bevel, seg=5, angle=True)
    return _place(o, loc, rot)


def text(s, size, depth, loc=(0, 0, 0), m=WHITE, rot=(90, 0, 0), bevel=0.02):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = s
    cu.size = size
    cu.extrude = depth
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    try:
        f = bpy.data.fonts.load("C:/Windows/Fonts/ariblk.ttf")
        cu.font = f
    except Exception:
        pass
    o = _link(bpy.data.objects.new("txt", cu))
    o.data.materials.append(m)
    return _place(o, loc, rot)


# ---------------------------------------------------------------- 2D outlines


def star_pts(n=5, ro=1.0, ri=0.45, rot=90):
    out = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + 180 * i / n)
        out.append((r * math.cos(a), r * math.sin(a)))
    return out


def round_star(n=5, ro=1.0, ri=0.5):  # a softer star (rounded tips via many points)
    return star_pts(n, ro, ri)


def heart_pts(s=1.0, n=80):
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        out.append((x / 17 * s, y / 17 * s + 0.1 * s))
    return out


def arrow_pts(w=0.42, head=1.0, hl=0.8, tail=1.0):  # pointing up, from z=-tail to z=hl
    return [(-w / 2, -tail), (w / 2, -tail), (w / 2, 0), (head / 2, 0), (0, hl), (-head / 2, 0), (-w / 2, 0)]


def bolt_pts(s=1.0):
    p = [(0.2, 1.0), (-0.45, -0.05), (-0.05, -0.05), (-0.25, -1.0), (0.45, 0.15), (0.05, 0.15), (0.3, 1.0)]
    return [(x * s, z * s) for x, z in p]


def check_pts(s=1.0):
    p = [(-0.75, 0.05), (-0.45, 0.35), (-0.2, 0.08), (0.5, 0.75), (0.8, 0.45), (-0.2, -0.55)]
    return [(x * s, z * s) for x, z in p]


def cross_pts(s=1.0, w=0.32):
    a = w / 2
    p = [(-a, 1), (a, 1), (a, a), (1, a), (1, -a), (a, -a), (a, -1), (-a, -1), (-a, -a), (-1, -a), (-1, a), (-a, a)]
    return [(x * s, z * s) for x, z in p]


def gear_pts(n=8, ro=1.0, ri=0.78):
    out = []
    for i in range(n):
        a0 = 2 * math.pi * i / n
        for da, r in ((-0.30, ri), (-0.18, ro), (0.18, ro), (0.30, ri)):
            a = a0 + da * 2 * math.pi / n
            out.append((r * math.cos(a), r * math.sin(a)))
    return out


def circle_pts(r=1.0, n=48, cx=0, cz=0):
    return [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def round_rect(w, h, r, n=8):
    out = []
    for cx, cz, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            out.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return out


def tri_pts(s=1.0, r=0.18):
    # a rounded warning triangle
    base = [(0, 1.0), (-1.0, -0.75), (1.0, -0.75)]
    out = []
    for i, (x, z) in enumerate(base):
        px, pz = base[i - 1]
        nx, nz = base[(i + 1) % 3]
        for k in range(7):
            t = k / 6
            # blend between the two edge directions around the corner
            ax, az = x + (px - x) * r * (1 - t), z + (pz - z) * r * (1 - t)
            bx, bz = x + (nx - x) * r * t, z + (nz - z) * r * t
            out.append(((ax + bx) / 2 * s + (x * s - (ax + bx) / 2 * s) * 0.0, (az + bz) / 2 * s))
    return out


# ---------------------------------------------------------------- composite bits


def badge(kind, loc=(0.95, -0.5, 0.95), r=0.48, col=None):
    """a glossy round badge with a white symbol, for status icons"""
    col = col or {"check": GREEN, "up": GREEN, "plus": GREEN, "x": RED, "person": BLUE, "star": BLUE, "dirt": BROWN, "crown": PURPLE}[kind]
    x, y, z = loc
    disc(r, 0.22, (x, y, z), col, bevel=0.08)
    fy = y - 0.14
    if kind == "check":
        shape(check_pts(r * 0.85), 0.12, (x, fy, z), WHITE, bevel=0.03)
    elif kind == "up":
        shape(arrow_pts(0.3, 0.8, 0.55, 0.55), 0.12, (x, fy, z - 0.02), WHITE, bevel=0.03, scale=r * 0.95)
    elif kind == "plus":
        shape(cross_pts(r * 0.6, 0.36), 0.12, (x, fy, z), WHITE, bevel=0.03)
    elif kind == "x":
        shape(cross_pts(r * 0.62, 0.34), 0.12, (x, fy, z), WHITE, rot=(0, 45, 0), bevel=0.03)
    elif kind == "person":
        sph(r * 0.28, (x, fy, z + r * 0.22), WHITE)
        sph(r * 0.45, (x, fy, z - r * 0.42), WHITE, scale=(1, 0.5, 0.6))
    elif kind == "star":
        shape(star_pts(5, r * 0.7, r * 0.32), 0.12, (x, fy, z), YELLOW, bevel=0.03)
    elif kind == "dirt":
        for dx, dz, s in ((-0.12, -0.08, 0.17), (0.12, -0.1, 0.14), (0.0, 0.12, 0.15)):
            sph(s * r / 0.48, (x + dx * r / 0.48, fy, z + dz * r / 0.48), P("c9a074"))


def face(col, mouth="smile", brows=0, eyes="dot", loc=(0, 0, 0), r=1.0):
    x, y, z = loc
    sph(r, loc, col)
    def surf(px, pz, out=0.0):
        return y - math.sqrt(max(0.0, r * r - px * px - pz * pz)) - out
    if eyes == "dot":
        for s in (-1, 1):
            sph(r * 0.12, (x + s * r * 0.33, surf(r * 0.33, r * 0.18, -r * 0.02), z + r * 0.18), INK, scale=(0.85, 0.5, 1.3))
            sph(r * 0.035, (x + s * r * 0.31, surf(r * 0.31, r * 0.24, r * 0.05), z + r * 0.24), WHITE)
    elif eyes == "x":
        for s in (-1, 1):
            shape(cross_pts(r * 0.13, 0.4), 0.06, (x + s * r * 0.33, surf(r * 0.33, r * 0.18, 0.0), z + r * 0.18), INK, rot=(0, 45, 0), bevel=0.01)
    if brows:
        for s in (-1, 1):
            box((r * 0.36, 0.1, r * 0.09), (x + s * r * 0.33, surf(r * 0.33, r * 0.45, 0.0), z + r * 0.45), INK, rot=(0, -s * brows, 0), bevel=0.03)
    ey = y
    pts = []
    for i in range(13):
        t = -1 + 2 * i / 12
        if mouth == "smile":
            dz = -0.42 - (1 - t * t) * 0.18
        elif mouth == "frown":
            dz = -0.55 + (1 - t * t) * 0.15
        else:
            dz = -0.48 + 0.04 * math.sin(t * 6)
        px = t * r * 0.36
        pz = dz * r
        py = -math.sqrt(max(0.0, r * r - px * px - pz * pz)) - r * 0.02
        pts.append((x + px, y + py - 0.02, z + pz))
    tube(pts, r * 0.055, INK)
    if mouth == "smile":
        for s in (-1, 1):
            sph(r * 0.13, (x + s * r * 0.55, surf(r * 0.55, r * 0.18, 0.0), z - r * 0.18), P("ff8fa6", rough=0.6, coat=0.0), scale=(1, 0.4, 0.7))


def person(shirt, loc=(0, 0, 0), s=1.0, hat=None, skin=SKIN):
    x, y, z = loc
    box((1.3 * s, 0.8 * s, 0.95 * s), (x, y, z - 0.75 * s), shirt, bevel=0.3 * s)
    sph(0.5 * s, (x, y, z + 0.32 * s), skin)
    for k in (-1, 1):
        sph(0.06 * s, (x + k * 0.17 * s, y - 0.46 * s, z + 0.38 * s), INK, scale=(0.9, 0.5, 1.3))
    sm = [(x + (t - 3) / 3 * 0.16 * s, y - 0.47 * s, z + 0.18 * s - (1 - ((t - 3) / 3) ** 2) * 0.06 * s) for t in range(7)]
    tube(sm, 0.025 * s, INK)
    if hat == "cap":
        sph(0.52 * s, (x, y, z + 0.5 * s), BLUE, scale=(1, 1, 0.62))
        box((0.75 * s, 0.5 * s, 0.07 * s), (x, y - 0.42 * s, z + 0.52 * s), BLUE, bevel=0.03)
    elif hat == "doorman":
        cyl(0.46 * s, 0.34 * s, (x, y, z + 0.82 * s), RED, bevel=0.05)
        cyl(0.47 * s, 0.08 * s, (x, y, z + 0.7 * s), GOLD, bevel=0.02)
        box((0.6 * s, 0.32 * s, 0.06 * s), (x, y - 0.42 * s, z + 0.66 * s), INK, rot=(-12, 0, 0), bevel=0.03)
    elif hat == "chef":
        cyl(0.4 * s, 0.3 * s, (x, y, z + 0.8 * s), WHITE, bevel=0.05)
        for dx, dz in ((-0.25, 1.1), (0.25, 1.1), (0, 1.22)):
            sph(0.3 * s, (x + dx * s, y, z + dz * s), WHITE)
    elif hat == "hair":
        sph(0.53 * s, (x, y + 0.06 * s, z + 0.45 * s), BROWN, scale=(1, 1, 0.7))


def cloud(loc=(0, 0, 0), m=None, s=1.0):
    m = m or P("f7f9ff", rough=0.4)
    x, y, z = loc
    for dx, dz, r in ((-0.55, -0.1, 0.45), (0.0, 0.18, 0.62), (0.55, -0.05, 0.5), (0.0, -0.22, 0.45)):
        sph(r * s, (x + dx * s, y, z + dz * s), m)
    box((1.9 * s, 0.9 * s, 0.5 * s), (x, y, z - 0.33 * s), m, bevel=0.24 * s)


def bed(loc=(0, 0, 0), blanket=BLUE):
    x, y, z = loc
    box((2.2, 1.3, 0.35), (x, y, z - 0.45), WOOD, bevel=0.08)
    box((0.22, 1.35, 1.25), (x - 1.05, y, z - 0.05), WOOD, bevel=0.08)
    box((0.18, 1.35, 0.7), (x + 1.08, y, z - 0.35), WOOD, bevel=0.07)
    box((2.0, 1.2, 0.32), (x + 0.02, y, z - 0.15), WHITE, bevel=0.14)
    box((0.55, 0.95, 0.22), (x - 0.7, y, z + 0.08), WHITE, rot=(0, -12, 0), bevel=0.1)
    box((1.25, 1.26, 0.28), (x + 0.42, y, z - 0.08), blanket, bevel=0.12)
    box((0.12, 1.27, 0.29), (x - 0.18, y, z - 0.07), WHITE, bevel=0.05)


# ---------------------------------------------------------------- the icons
ICONS = {}


def icon(name, rot=(8, 0, -22)):
    def deco(fn):
        ICONS[name] = (fn, rot)
        return fn
    return deco


@icon("angry", rot=(0, 0, 0))
def _():
    face(P("ff6a4a"), "frown", brows=22)


@icon("happy", rot=(0, 0, 0))
def _():
    face(P("ffcf3a"), "smile")


@icon("ev_sick", rot=(0, 0, 0))
def _():
    face(P("9fd86a"), "flat", eyes="x")
    cyl(0.07, 1.1, (0.45, -0.95, -0.25), WHITE, rot=(0, -60, 0), bevel=0.03)
    sph(0.1, (-0.02, -0.95, -0.52), RED)


def moon_pts(r=1.0, n=40):
    import math
    out = []
    for i in range(n + 1):  # outer arc, right side of a full circle
        a = math.radians(-120 + 240 * i / n)
        out.append((r * math.cos(a), r * math.sin(a)))
    for i in range(n + 1):  # inner arc, cut by an offset circle
        a = math.radians(120 - 240 * i / n)
        out.append((0.45 * r + 0.78 * r * math.cos(a) - 0.62 * r, 0.82 * r * math.sin(a)))
    return out


@icon("sleep")
def _():
    shape(moon_pts(1.0), 0.45, (-0.15, 0, -0.05), YELLOW, rot=(0, 25, 0), bevel=0.08)
    text("Z", 1.0, 0.16, (0.55, -0.45, 0.25), BLUE, bevel=0.035)
    text("z", 0.65, 0.12, (1.05, -0.45, 0.95), BLUE, bevel=0.03)


@icon("bed")
def _():
    bed()


@icon("roomReady")
def _():
    bed()
    badge("check", (1.0, -0.75, 0.75))


@icon("roomBusy")
def _():
    bed()
    badge("person", (1.0, -0.75, 0.75))


@icon("roomDirty")
def _():
    bed(blanket=P("a08060"))
    for dx, dz in ((-0.2, 0.15), (0.6, 0.1), (0.25, 0.18)):
        sph(0.17, (dx, -0.55, dz), P("8a6a45", rough=0.8, coat=0), scale=(1, 0.4, 0.7))
    badge("dirt", (1.0, -0.75, 0.75))


@icon("roomDeluxe")
def _():
    bed(blanket=P("8a5cf0"))
    badge("up", (1.0, -0.75, 0.75))


@icon("roomSuite")
def _():
    bed(blanket=P("d43a5a"))
    crown((0.95, -0.7, 0.9), 0.45)


def crown(loc=(0, 0, 0), s=1.0):
    x, y, z = loc
    n = 64
    prof = []
    bm = bmesh.new()
    ring_lo, ring_hi = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        spike = 0.5 + 0.5 * math.cos(a * 5)
        hz = 0.35 + 0.55 * spike ** 3
        ring_lo.append(bm.verts.new((math.cos(a) * 0.8, math.sin(a) * 0.8, -0.45)))
        ring_hi.append(bm.verts.new((math.cos(a) * 0.86, math.sin(a) * 0.86, hz)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
    bm.faces.new(list(reversed(ring_lo)))
    o = mesh_from_bm(bm, "crown")
    sol = o.modifiers.new("Sol", "SOLIDIFY")
    sol.thickness = 0.1
    _fin(o, GOLD, 0.03)
    o.scale = (s, s, s)
    o.location = loc
    for k in range(5):
        a = 2 * math.pi * k / 5 - math.pi / 2
        sph(0.12 * s, (x + math.cos(a) * 0.86 * s, y + math.sin(a) * 0.86 * s, z + 0.92 * s), GOLD)
    for dx, m in ((-0.4, RED), (0.0, BLUE), (0.4, GREEN)):
        sph(0.12 * s, (x + dx * s, y - 0.86 * s, z - 0.1 * s), m, scale=(1, 0.6, 1))
    return o


@icon("ev_vip", rot=(12, 0, 0))
def _():
    crown()


@icon("shower")
def _():
    tube([(0.6, 0, -1.2), (0.6, 0, 0.9), (0.5, 0, 1.15), (0.1, 0, 1.2), (-0.15, 0, 1.0)], 0.1, SILVER)
    cyl(0.5, 0.18, (-0.25, 0, 0.88), SILVER, rot=(0, 25, 0), bevel=0.05, r2=0.32)
    cyl(0.44, 0.04, (-0.3, 0, 0.78), P("cfd6e2"), rot=(0, 25, 0), bevel=0.01)
    for dx, dz in ((-0.6, 0.35), (-0.25, 0.25), (0.05, 0.4), (-0.45, -0.15), (-0.1, -0.2), (-0.75, -0.05), (-0.3, -0.6)):
        sph(0.1, (dx, -0.1, dz), mat(rgb("6cc4ff"), rough=0.05, coat=0.8), scale=(0.8, 0.8, 1.4))
    cyl(0.2, 0.1, (0.6, 0, -1.2), SILVER, bevel=0.03)


@icon("toilet")
def _():
    box((1.4, 0.55, 0.95), (0, 0.55, 0.65), WHITE, bevel=0.15)
    box((1.5, 0.62, 0.12), (0, 0.55, 1.15), WHITE, bevel=0.06)
    cyl(0.12, 0.05, (0.35, 0.55, 1.23), SILVER, bevel=0.02)
    lathe([(0.0, -1.0), (0.45, -1.0), (0.5, -0.95), (0.42, -0.6), (0.62, -0.25), (0.8, 0.0), (0.82, 0.08), (0.0, 0.08)], (0, -0.35, 0), WHITE, sxy=(0.95, 1.2))
    tor(0.66, 0.1, (0, -0.35, 0.12), P("eef2f8"), rot=(0, 0, 0))
    cyl(0.6, 0.02, (0, -0.35, 0.06), mat(rgb("7ec8ff"), rough=0.05, coat=0.8), bevel=0.0)


@icon("bell", rot=(10, 0, 0))
def _():
    cyl(1.15, 0.28, (0, 0, -0.75), WOODD, bevel=0.1)
    lathe([(0.0, -0.6), (1.0, -0.6), (1.02, -0.52), (0.95, -0.3), (0.75, 0.15), (0.45, 0.45), (0.15, 0.55), (0.0, 0.56)], m=GOLD)
    cyl(0.08, 0.25, (0, 0, 0.66), SILVER, bevel=0.02)
    sph(0.17, (0, 0, 0.82), SILVER, scale=(1, 1, 0.6))


@icon("cash", rot=(18, 0, -18))
def _():
    BILL = P("4fbf6a", rough=0.5, coat=0.2)
    for i in range(4):
        box((2.1, 1.1, 0.1), (0.04 * (i % 2), 0.02 * i, -0.4 + i * 0.12), BILL, rot=(0, 0, (i % 2) * 4), bevel=0.03)
    box((2.1, 1.1, 0.1), (0, 0, 0.1), P("6fd88a", rough=0.5, coat=0.2), bevel=0.03)
    box((0.42, 1.14, 0.62), (0, 0, -0.1), P("f6e2b0"), bevel=0.04)
    text("$", 0.55, 0.04, (-0.62, -0.1, 0.17), P("2e9a4c"), rot=(0, 0, 0), bevel=0.01)
    for k, (dx, dz) in enumerate(((0.8, 0.55), (1.05, 0.25))):
        cyl(0.42, 0.14, (dx, -0.6, dz), GOLD, rot=(80, 0, 0), bevel=0.04)


@icon("sell", rot=(0, 0, 0))
def _():
    disc(1.0, 0.3, (0, 0, 0), GOLD, bevel=0.08)
    tor(0.82, 0.05, (0, -0.15, 0), P("d99a1a", metal=1.0, rough=0.3), rot=(90, 0, 0))
    text("$", 1.25, 0.08, (0, -0.2, -0.05), P("d98c12", rough=0.3), bevel=0.02)


@icon("clean")
def _():
    lathe([(0.0, -1.0), (0.62, -1.0), (0.85, 0.3), (0.0, 0.3)], m=BLUE)
    tor(0.86, 0.06, (0, 0, 0.3), P("2a6fc6"))
    for dx, dy, dz, r in ((-0.4, -0.2, 0.45, 0.32), (0.1, -0.3, 0.55, 0.4), (0.5, -0.1, 0.45, 0.3), (-0.05, 0.2, 0.7, 0.3), (0.3, -0.45, 0.85, 0.2), (-0.35, -0.5, 0.9, 0.15)):
        sph(r, (dx, dy, dz), mat(rgb("f4fbff"), rough=0.08, coat=1.0))
    box((0.8, 0.5, 0.35), (0.55, -0.6, 0.2), YELLOW, rot=(0, -20, 0), bevel=0.12)
    box((0.8, 0.52, 0.1), (0.55, -0.6, 0.38), GREEN, rot=(0, -20, 0), bevel=0.04)
    tube([(-0.8, 0, 0.3), (-0.6, 0, 1.0), (0.6, 0, 1.0), (0.8, 0, 0.3)], 0.04, STEEL)


@icon("sparkle", rot=(0, 0, 0))
def _():
    shape(star_pts(4, 1.0, 0.22), 0.3, (-0.15, 0, -0.1), YELLOW, bevel=0.06)
    shape(star_pts(4, 0.45, 0.1), 0.2, (0.75, 0, 0.7), P("8fd3ff"), bevel=0.04)
    shape(star_pts(4, 0.3, 0.07), 0.16, (0.7, 0, -0.75), P("ffd0f0"), bevel=0.03)


@icon("star", rot=(0, 0, 0))
def _():
    shape(star_pts(5, 1.0, 0.5), 0.36, m=YELLOW, bevel=0.12)


@icon("starEmpty", rot=(0, 0, 0))
def _():
    shape(star_pts(5, 1.0, 0.5), 0.36, m=P("8a8fa8", rough=0.55, coat=0.1), bevel=0.12)


@icon("door", rot=(6, 0, -18))
def _():
    box((1.5, 0.35, 2.6), (0, 0.1, 0), WOODD, bevel=0.06)
    box((1.2, 0.3, 2.35), (0, -0.05, -0.08), WOOD, bevel=0.05)
    for dz in (0.55, -0.6):
        box((0.85, 0.12, 0.8), (0, -0.22, dz), P("c27a42", rough=0.45), bevel=0.05)
    sph(0.12, (0.42, -0.32, -0.05), GOLD)
    box((0.25, 0.08, 0.3), (0.42, -0.24, -0.05), GOLD, bevel=0.03)


def shoe(col, loc=(0, 0, 0), s=1.0):
    x, y, z = loc
    box((1.9 * s, 0.85 * s, 0.25 * s), (x, y, z - 0.45 * s), WHITE, bevel=0.1 * s)
    sph(0.6 * s, (x + 0.4 * s, y, z - 0.15 * s), col, scale=(1.3, 0.72, 0.62))
    box((0.85 * s, 0.75 * s, 0.85 * s), (x - 0.45 * s, y, z + 0.05 * s), col, bevel=0.3 * s)
    for k in range(3):
        box((0.4 * s, 0.05 * s, 0.07 * s), (x + (0.0 + k * 0.22) * s, y - 0.36 * s, z + (0.12 - k * 0.07) * s), WHITE, rot=(0, -25, 0), bevel=0.02)
    box((1.9 * s, 0.86 * s, 0.07 * s), (x, y, z - 0.33 * s), col, bevel=0.03)


@icon("walk")
def _():
    shoe(BLUE)


@icon("run")
def _():
    shoe(ORANGE, (0.3, 0, 0))
    for dz, w in ((0.3, 0.9), (0.0, 1.2), (-0.3, 0.8)):
        box((w, 0.12, 0.12), (-1.35 - w / 2 + 0.4, 0, dz), P("ffd166"), bevel=0.06)


@icon("guest", rot=(5, 0, -15))
def _():
    person(ORANGE, hat="hair")
    box((0.7, 0.3, 0.55), (0.75, -0.5, -0.95), P("2f7be0"), bevel=0.08)
    tor(0.16, 0.04, (0.75, -0.5, -0.62), INK, rot=(90, 0, 0), arc=180)


@icon("janitor", rot=(5, 0, -15))
def _():
    person(P("4fa3ff"), hat="cap")
    tube([(0.95, -0.4, -1.45), (0.6, -0.4, 1.05)], 0.06, WOOD)
    box((0.7, 0.35, 0.25), (1.0, -0.4, -1.5), P("ffd56a", rough=0.7, coat=0), rot=(0, 20, 0), bevel=0.1)


@icon("doorman", rot=(5, 0, -15))
def _():
    person(RED, hat="doorman")
    for dz in (-0.55, -0.85):
        sph(0.06, (0, -0.4, dz), GOLD)


@icon("chef", rot=(10, 0, -10))
def _():
    cyl(0.62, 0.55, (0, 0, -0.55), WHITE, bevel=0.1)
    for dx, dz, r in ((-0.45, 0.15, 0.5), (0.45, 0.15, 0.5), (0, 0.35, 0.6), (-0.15, 0.0, 0.45), (0.2, 0.05, 0.45)):
        sph(r, (dx, 0, dz), WHITE)
    box((1.26, 0.1, 0.1), (0, -0.62, -0.5), P("e4e8ef"), bevel=0.04)


@icon("staff", rot=(5, 0, -10))
def _():
    person(RED, (0.55, 0.3, 0.1), 0.85, hat="doorman")
    person(BLUE, (-0.55, -0.2, -0.1), 0.85, hat="cap")


@icon("coop", rot=(5, 0, -10))
def _():
    person(GREEN, (0.6, 0.2, -0.1), 0.85, hat="hair")
    person(BLUE, (-0.6, 0.2, -0.1), 0.85, hat="cap")
    shape(heart_pts(0.45), 0.2, (0, -0.6, 0.85), RED, bevel=0.06)


@icon("catAll", rot=(18, 0, -18))
def _():
    for (dx, dz), m in zip(((-0.55, 0.55), (0.55, 0.55), (-0.55, -0.55), (0.55, -0.55)), (BLUE, ORANGE, GREEN, PINK)):
        box((0.95, 0.4, 0.95), (dx, 0, dz), m, bevel=0.18)


@icon("catFurniture")
def _():
    box((2.2, 1.0, 0.45), (0, 0, -0.55), TEAL, bevel=0.15)
    box((2.2, 0.35, 1.0), (0, 0.4, 0.1), TEAL, bevel=0.15)
    for s in (-1, 1):
        box((0.35, 1.05, 0.75), (s * 1.05, 0, -0.2), P("27a394"), bevel=0.15)
    for s in (-1, 1):
        box((0.85, 0.85, 0.22), (s * 0.43, -0.05, -0.22), P("54d8c8"), bevel=0.1)
    for s in (-1, 1):
        cyl(0.07, 0.3, (s * 0.95, 0, -0.9), WOODD, bevel=0.02)


@icon("catDecor", rot=(10, 0, -10))
def _():
    lathe([(0.0, -1.1), (0.5, -1.1), (0.68, -0.2), (0.75, -0.15), (0.75, 0.0), (0.0, 0.0)], m=P("e0743c", rough=0.6, coat=0.1))
    cyl(0.66, 0.06, (0, 0, -0.03), P("5a3a24", rough=0.9, coat=0), bevel=0.0)
    LEAF = P("43b85a")
    for a, tilt, ln in ((0, 25, 1.0), (72, 35, 0.9), (144, 30, 1.05), (216, 40, 0.85), (288, 28, 0.95), (36, 5, 1.15)):
        o = sph(0.36, (0, 0, 0.5), LEAF, scale=(0.55, 0.2, ln))
        o.rotation_euler = Euler((math.radians(tilt), 0, math.radians(a)), "ZXY")
        o.location = (math.sin(math.radians(a)) * 0.3, -math.cos(math.radians(a)) * 0.3, 0.55)


@icon("catFun", rot=(18, 0, 0))
def _():
    box((2.2, 0.6, 1.0), (0, 0, 0), P("5f63f0"), bevel=0.4)
    for s in (-1, 1):
        sph(0.55, (s * 0.85, 0, -0.35), P("5f63f0"), scale=(0.9, 0.55, 1.0))
    box((0.5, 0.15, 0.16), (-0.6, -0.33, 0.05), INK, bevel=0.05)
    box((0.16, 0.15, 0.5), (-0.6, -0.33, 0.05), INK, bevel=0.05)
    for (dx, dz), m in zip(((0.55, 0.25), (0.8, 0.05), (0.55, -0.15), (0.3, 0.05)), (YELLOW, RED, GREEN, BLUE)):
        sph(0.12, (dx, -0.32, dz), m, scale=(1, 0.6, 1))


@icon("rotate", rot=(0, 0, 0))
def _():
    tor(0.85, 0.2, (0, 0, 0), BLUE, rot=(90, 0, 0), arc=280, start=110)
    a = math.radians(110)
    shape([(-0.45, 0), (0.45, 0), (0, 0.55)], 0.42, (0.85 * math.cos(a) + 0.05, 0, 0.85 * math.sin(a) - 0.15), BLUE, rot=(0, -20, 0), bevel=0.08)


@icon("move", rot=(0, 0, 0))
def _():
    w, hw, hl, reach = 0.17, 0.42, 0.42, 1.05
    q = []
    for k in range(4):  # one arm per quarter turn, traced anticlockwise from the right arm
        a = math.radians(90 * k)
        c, s_ = math.cos(a), math.sin(a)
        local = [(w, -w), (reach - hl, -w), (reach - hl, -hw), (reach, 0), (reach - hl, hw), (reach - hl, w)]
        q += [(px * c - pz * s_, px * s_ + pz * c) for px, pz in local]
    shape(q, 0.36, m=ORANGE, bevel=0.07)
    disc(0.2, 0.42, m=P("ffd166"), bevel=0.06)


@icon("close", rot=(0, 0, 0))
def _():
    disc(1.0, 0.35, m=RED, bevel=0.1)
    shape(cross_pts(0.62, 0.34), 0.2, (0, -0.2, 0), WHITE, rot=(0, 45, 0), bevel=0.05)


@icon("place", rot=(0, 0, 0))
def _():
    disc(1.0, 0.35, m=GREEN, bevel=0.1)
    shape(check_pts(0.8), 0.2, (0, -0.2, 0), WHITE, bevel=0.05)


@icon("checkmark", rot=(0, 0, 0))
def _():
    shape(check_pts(1.0), 0.4, m=GREEN, bevel=0.1)


@icon("plus", rot=(0, 0, 0))
def _():
    disc(1.0, 0.35, m=GREEN, bevel=0.1)
    shape(cross_pts(0.6, 0.36), 0.2, (0, -0.2, 0), WHITE, bevel=0.05)


@icon("upgrade", rot=(0, 0, 0))
def _():
    disc(1.0, 0.35, m=GREEN, bevel=0.1)
    shape(arrow_pts(0.36, 0.95, 0.55, 0.55), 0.2, (0, -0.2, -0.02), WHITE, bevel=0.05)


@icon("up", rot=(0, 0, 0))
def _():
    shape(arrow_pts(0.55, 1.5, 0.95, 0.95), 0.4, m=BLUE, bevel=0.1)


@icon("down", rot=(0, 0, 0))
def _():
    shape(arrow_pts(0.55, 1.5, 0.95, 0.95), 0.4, m=ORANGE, rot=(0, 180, 0), bevel=0.1)


@icon("lamp", rot=(8, 0, -10))
def _():
    cyl(0.6, 0.15, (0, 0, -1.1), GOLD, bevel=0.06)
    cyl(0.07, 1.2, (0, 0, -0.45), GOLD, bevel=0.02)
    cyl(0.75, 0.9, (0, 0, 0.5), CREAM, bevel=0.04, r2=0.42)
    sph(0.28, (0, 0, 0.1), GLOW)


@icon("shapes", rot=(12, 0, -20))
def _():
    box((0.95, 0.95, 0.95), (-0.55, 0.2, -0.45), BLUE, bevel=0.12)
    sph(0.55, (0.6, -0.1, -0.45), RED)
    cyl(0.55, 1.0, (0.05, 0.4, 0.55), YELLOW, bevel=0.04, r2=0.0)


@icon("research", rot=(5, 0, 0))
def _():
    lathe([(0.0, -1.0), (0.95, -1.0), (1.0, -0.92), (0.3, 0.55), (0.3, 1.0), (0.36, 1.08), (0.0, 1.08)], m=GLASS)
    lathe([(0.0, -0.95), (0.9, -0.95), (0.55, -0.1), (0.0, -0.1)], m=mat(rgb("5ee08a"), rough=0.1, coat=0.8, emit=0.3))
    for dx, dz, r in ((-0.2, -0.5, 0.1), (0.15, -0.3, 0.07), (0.05, -0.65, 0.08)):
        sph(r, (dx, -0.35, dz), WHITE)
    cyl(0.34, 0.15, (0, 0, 1.08), P("8a5a3a", rough=0.7), bevel=0.04)


@icon("lock", rot=(5, 0, -12))
def _():
    box((1.5, 0.6, 1.2), (0, 0, -0.45), GOLD, bevel=0.2)
    tor(0.5, 0.13, (0, 0, 0.15), SILVER, rot=(90, 0, 0), arc=180, start=0)
    for s in (-1, 1):
        cyl(0.13, 0.4, (s * 0.5, 0, 0.0), SILVER, bevel=0.0)
    sph(0.15, (0, -0.32, -0.32), INK, scale=(1, 0.4, 1))
    box((0.12, 0.1, 0.3), (0, -0.3, -0.55), INK, bevel=0.04)


@icon("copy", rot=(10, 0, -15))
def _():
    box((1.3, 0.15, 1.6), (0.25, 0.25, 0.25), P("c9d3e6"), bevel=0.12)
    box((1.3, 0.15, 1.6), (-0.2, -0.05, -0.2), WHITE, bevel=0.12)
    badge("plus", (0.45, -0.3, -0.55), 0.38)


@icon("paint", rot=(12, 0, -15))
def _():
    # a paint tin full of pink, a brush dipped in it
    cyl(0.8, 1.1, (0, 0, -0.5), SILVER, bevel=0.06)
    cyl(0.82, 0.08, (0, 0, 0.05), STEEL, bevel=0.03)
    cyl(0.74, 0.05, (0, 0, 0.04), PINK, bevel=0.0)
    for dx, dz in ((-0.55, 0.0), (0.35, 0.0)):
        sph(0.12, (dx, -0.6, -0.1), PINK, scale=(0.9, 0.6, 1.6))
    tube([(0.25, 0, 0.1), (0.95, 0, 1.25)], 0.11, WOOD)
    cyl(0.17, 0.35, (0.3, 0, 0.25), SILVER, rot=(0, 31, 0), bevel=0.03)
    box((0.42, 0.28, 0.45), (0.13, 0, -0.05), PINK, rot=(0, 31, 0), bevel=0.12)


@icon("grid", rot=(35, 0, -20))
def _():
    for i in range(3):
        for j in range(3):
            box((0.62, 0.62, 0.15), ((i - 1) * 0.68, (j - 1) * 0.68, 0), P("8fb2e6") if (i + j) % 2 else P("c3d6f2"), bevel=0.06, rot=(90, 0, 0))


@icon("roof", rot=(8, 0, -22))
def _():
    box((1.8, 1.4, 1.1), (0, 0, -0.6), CREAM, bevel=0.06)
    shape([(-1.25, 0), (1.25, 0), (0, 1.0)], 1.7, (0, 0, -0.05), RED, bevel=0.06)
    box((0.45, 0.1, 0.7), (0, -0.72, -0.8), WOOD, bevel=0.05)
    box((0.3, 0.3, 0.6), (0.6, 0.2, 0.55), P("b74a3a"), bevel=0.04)


@icon("search", rot=(0, 0, 0))
def _():
    tor(0.62, 0.13, (-0.25, 0, 0.25), INK, rot=(90, 0, 0))
    disc(0.6, 0.06, (-0.25, 0, 0.25), GLASS, bevel=0.0)
    tube([(0.2, 0, -0.2), (0.95, 0, -0.95)], 0.16, WOOD)
    sph(0.12, (-0.45, -0.1, 0.45), mat(rgb("ffffff"), emit=2.0), scale=(1.2, 0.3, 0.6))


@icon("clock", rot=(0, 0, 0))
def _():
    disc(1.0, 0.3, m=GOLD, bevel=0.1)
    disc(0.82, 0.32, (0, -0.02, 0), WHITE, bevel=0.03)
    for k in range(12):
        a = 2 * math.pi * k / 12
        box((0.06, 0.05, 0.15 if k % 3 else 0.22), (0.66 * math.sin(a), -0.18, 0.66 * math.cos(a)), INK, rot=(0, math.degrees(a), 0), bevel=0.02)
    box((0.08, 0.06, 0.5), (0, -0.21, 0.22), INK, bevel=0.03)
    box((0.07, 0.06, 0.4), (0.15, -0.21, -0.1), INK, rot=(0, 120, 0), bevel=0.03)
    sph(0.08, (0, -0.22, 0), RED)


@icon("ev_baby", rot=(5, 0, -18))
def _():
    lathe([(0.0, -1.0), (0.5, -1.0), (0.55, -0.9), (0.55, 0.45), (0.0, 0.45)], m=GLASS)
    lathe([(0.0, -0.95), (0.5, -0.95), (0.5, 0.1), (0.0, 0.1)], m=P("fffaf0", rough=0.3))
    cyl(0.58, 0.25, (0, 0, 0.55), PINK, bevel=0.05)
    lathe([(0.0, 0.65), (0.3, 0.65), (0.22, 0.85), (0.12, 1.05), (0.13, 1.15), (0.0, 1.2)], m=P("f8d58a", rough=0.5))


@icon("ev_access", rot=(5, 0, -25))
def _():
    tor(0.75, 0.1, (0.0, 0, -0.35), INK, rot=(90, 0, 0))
    tor(0.6, 0.05, (0.0, 0, -0.35), SILVER, rot=(90, 0, 0))
    box((0.9, 0.9, 0.15), (0.15, 0.3, 0.0), BLUE, bevel=0.06)
    box((0.15, 0.9, 1.0), (-0.3, 0.3, 0.5), BLUE, bevel=0.06)
    tube([(0.6, 0.3, 0.0), (0.85, 0.3, -0.7), (1.05, 0.3, -0.75)], 0.05, SILVER)
    tor(0.18, 0.06, (1.05, 0.3, -0.92), INK, rot=(90, 0, 0))


@icon("ev_pet", rot=(0, 0, 0))
def _():
    PAW = P("a0663c")
    sph(0.62, (0, 0, -0.35), PAW, scale=(1.1, 0.45, 0.85))
    for dx, dz in ((-0.75, 0.3), (-0.28, 0.72), (0.28, 0.72), (0.75, 0.3)):
        sph(0.27, (dx, 0, dz), PAW, scale=(0.9, 0.45, 1.15))


@icon("ev_night", rot=(0, 0, 0))
def _():
    shape(moon_pts(1.0), 0.5, (-0.2, 0, 0), P("ffd24a"), rot=(0, 20, 0), bevel=0.1)
    shape(star_pts(5, 0.34, 0.15), 0.14, (0.75, -0.2, 0.6), YELLOW, bevel=0.04)
    shape(star_pts(5, 0.2, 0.09), 0.1, (0.95, -0.2, -0.3), P("bcd7ff"), bevel=0.03)
    shape(star_pts(4, 0.14, 0.05), 0.08, (0.45, -0.2, 1.05), P("bcd7ff"), bevel=0.02)


@icon("ev_party", rot=(10, 0, -15))
def _():
    cyl(1.0, 0.7, (0, 0, -0.6), PINK, bevel=0.1)
    cyl(1.02, 0.12, (0, 0, -0.3), WHITE, bevel=0.05)
    cyl(0.7, 0.55, (0, 0, 0.05), P("ffd3e5"), bevel=0.1)
    cyl(0.72, 0.1, (0, 0, 0.3), WHITE, bevel=0.04)
    for k, m in enumerate((BLUE, YELLOW, GREEN)):
        x = (k - 1) * 0.35
        cyl(0.06, 0.45, (x, -0.1, 0.55), m, bevel=0.02)
        sph(0.09, (x, -0.1, 0.86), mat(rgb("ffb83a"), emit=6.0), scale=(0.8, 0.8, 1.4))
    for a in range(0, 360, 40):
        sph(0.08, (math.cos(math.radians(a)) * 0.98, math.sin(math.radians(a)) * 0.98, -0.28), RED)


@icon("ev_romance", rot=(0, 0, 0))
def _():
    shape(heart_pts(1.0), 0.45, (-0.15, 0.1, -0.1), RED, bevel=0.14)
    shape(heart_pts(0.5), 0.3, (0.8, -0.3, 0.6), PINK, rot=(0, -15, 0), bevel=0.08)


@icon("heart", rot=(0, 0, 0))
def _():
    shape(heart_pts(1.0), 0.5, m=RED, bevel=0.16)


@icon("ev_business", rot=(10, 0, -18))
def _():
    LEATHER = P("8b4a26", rough=0.45)
    box((2.1, 0.75, 1.4), (0, 0, -0.3), LEATHER, bevel=0.15)
    box((2.12, 0.77, 0.08), (0, 0, 0.1), P("6e3a1e"), bevel=0.03)
    tor(0.38, 0.09, (0, 0, 0.42), INK, rot=(90, 0, 0), arc=180)
    for s in (-1, 1):
        box((0.22, 0.12, 0.25), (s * 0.6, -0.4, 0.15), GOLD, bevel=0.04)


@icon("suitcase", rot=(8, 0, -20))
def _():
    box((1.35, 0.75, 1.8), (0, 0, -0.15), ORANGE, bevel=0.2)
    for dx in (-0.35, 0.35):
        box((0.1, 0.78, 1.82), (dx, 0, -0.15), P("e0661a"), bevel=0.04)
    tube([(-0.3, 0, 0.75), (-0.3, 0, 1.2), (0.3, 0, 1.2), (0.3, 0, 0.75)], 0.07, INK)
    for dx in (-0.45, 0.45):
        cyl(0.13, 0.14, (dx, 0, -1.12), INK, rot=(90, 0, 0), bevel=0.04)


@icon("ev_inspector", rot=(8, 0, -15))
def _():
    box((1.5, 0.15, 2.0), (0, 0.05, 0), WOOD, bevel=0.1)
    box((1.25, 0.1, 1.6), (0, -0.06, -0.12), WHITE, bevel=0.04)
    box((0.7, 0.2, 0.3), (0, -0.08, 0.95), SILVER, bevel=0.08)
    for k in range(3):
        z = 0.35 - k * 0.45
        shape(check_pts(0.18), 0.06, (-0.35, -0.13, z), GREEN, bevel=0.01)
        box((0.55, 0.05, 0.08), (0.2, -0.13, z), P("b8c2d6"), bevel=0.03)


@icon("quest", rot=(8, 0, -12))
def _():
    PAPER = P("f5e3b8", rough=0.6, coat=0.1)
    box((1.4, 0.08, 1.6), (0, 0, 0), PAPER, bevel=0.03)
    for dz in (0.85, -0.85):
        cyl(0.15, 1.7, (0, 0, dz), P("d9b97a", rough=0.6), rot=(0, 90, 0), bevel=0.04)
        for s in (-1, 1):
            sph(0.1, (s * 0.9, 0, dz), WOODD)
    for k in range(3):
        box((0.8, 0.05, 0.08), (0.05, -0.06, 0.35 - k * 0.3), P("a98a58"), bevel=0.03)
    disc(0.2, 0.1, (0.3, -0.1, -0.5), RED, bevel=0.04)


@icon("ev_tour", rot=(8, 0, -25))
def _():
    box((2.6, 1.2, 1.3), (0, 0, 0), YELLOW, bevel=0.25)
    box((2.62, 1.22, 0.45), (0, 0, 0.2), mat(rgb("6ec2ff"), rough=0.05, coat=1.0), bevel=0.12)
    for k in range(4):
        box((0.06, 1.24, 0.45), (-0.9 + k * 0.6, 0, 0.2), YELLOW, bevel=0.02)
    box((2.62, 1.22, 0.12), (0, 0, -0.35), P("ff7a2a"), bevel=0.04)
    for dx in (-0.8, 0.8):
        cyl(0.3, 0.25, (dx, -0.55, -0.65), INK, rot=(90, 0, 0), bevel=0.08)
        cyl(0.13, 0.27, (dx, -0.55, -0.65), SILVER, rot=(90, 0, 0), bevel=0.03)
    for dz in (-0.1,):
        sph(0.1, (1.3, -0.4, dz), mat(rgb("fff4b0"), emit=3.0))


@icon("ev_firstaid", rot=(8, 0, -18))
def _():
    box((2.0, 0.9, 1.5), (0, 0, -0.2), WHITE, bevel=0.18)
    tube([(-0.35, 0, 0.55), (-0.35, 0, 0.85), (0.35, 0, 0.85), (0.35, 0, 0.55)], 0.08, RED)
    shape(cross_pts(0.5, 0.36), 0.12, (0, -0.48, -0.2), RED, bevel=0.03)


@icon("settings", rot=(0, 0, 0))
def _():
    shape(gear_pts(9, 1.0, 0.8), 0.38, m=mat(rgb("9aa6ba"), rough=0.25, metal=0.8, coat=0.3), bevel=0.05)
    disc(0.4, 0.5, m=ORANGE, bevel=0.08)
    disc(0.18, 0.55, m=INK, bevel=0.04)


@icon("stats", rot=(12, 0, -20))
def _():
    box((2.2, 0.9, 0.18), (0, 0, -1.0), GREY, bevel=0.06)
    for k, (h, m) in enumerate(((0.8, BLUE), (1.3, GREEN), (1.9, ORANGE))):
        box((0.5, 0.5, h), (-0.65 + k * 0.65, 0, -0.9 + h / 2), m, bevel=0.1)


@icon("food", rot=(12, 0, -10))
def _():
    cyl(1.25, 0.08, (0, 0, -0.55), WHITE, bevel=0.03)
    lathe([(0.0, -0.5), (1.0, -0.5), (0.98, -0.3), (0.85, 0.1), (0.55, 0.45), (0.2, 0.58), (0.0, 0.6)], m=SILVER)
    sph(0.14, (0, 0, 0.7), SILVER)
    cyl(0.06, 0.12, (0, 0, 0.6), SILVER, bevel=0.02)


@icon("pot", rot=(12, 0, -10))
def _():
    lathe([(0.0, -0.8), (0.95, -0.8), (1.0, -0.7), (1.0, 0.35), (0.0, 0.35)], m=SILVER)
    lathe([(0.0, 0.35), (1.05, 0.35), (1.0, 0.42), (0.55, 0.62), (0.0, 0.66)], m=STEEL)
    sph(0.16, (0, 0, 0.72), INK)
    for s in (-1, 1):
        box((0.35, 0.25, 0.15), (s * 1.12, 0, 0.1), INK, bevel=0.06)
    for dx in (-0.35, 0.05, 0.4):
        tube([(dx, 0, 0.85), (dx + 0.1, 0, 1.05), (dx - 0.05, 0, 1.25), (dx + 0.08, 0, 1.45)], 0.05, mat(rgb("ffffff"), rough=0.6, coat=0, alpha=1.0))


@icon("medal", rot=(5, 0, 0))
def _():
    for s, m in ((-1, BLUE), (1, RED)):
        box((0.45, 0.08, 1.3), (s * 0.28, 0.15, 0.6), m, rot=(0, s * 18, 0), bevel=0.03)
    disc(0.75, 0.22, (0, 0, -0.35), GOLD, bevel=0.06)
    shape(star_pts(5, 0.45, 0.22), 0.12, (0, -0.13, -0.35), P("ffe08a", metal=1.0, rough=0.25), bevel=0.03)


@icon("trophy", rot=(8, 0, 0))
def _():
    lathe([(0.0, -0.1), (0.15, -0.1), (0.2, 0.0), (0.75, 0.45), (0.85, 1.0), (0.0, 1.0)], (0, 0, 0), GOLD)
    for s in (-1, 1):
        tor(0.32, 0.07, (s * 0.85, 0, 0.6), GOLD, rot=(90, 0, 0), arc=200, start=-100 if s > 0 else 80)
    cyl(0.12, 0.5, (0, 0, -0.3), GOLD, bevel=0.03)
    box((1.0, 0.7, 0.35), (0, 0, -0.75), WOODD, bevel=0.08)
    shape(star_pts(5, 0.25, 0.11), 0.1, (0, -0.68, 0.55), WHITE, bevel=0.02)


@icon("chat", rot=(0, 0, -10))
def _():
    shape(round_rect(1.8, 1.2, 0.5), 0.3, (0.45, 0.25, 0.45), BLUE, bevel=0.08)
    shape([(0.0, 0.0), (0.5, 0.0), (0.55, -0.45)], 0.3, (0.75, 0.25, -0.2), BLUE, bevel=0.05)
    shape(round_rect(1.7, 1.15, 0.5), 0.34, (-0.3, -0.25, -0.3), WHITE, bevel=0.09)
    shape([(0.0, 0.0), (-0.5, 0.0), (-0.6, -0.45)], 0.34, (-0.6, -0.25, -0.82), WHITE, bevel=0.05)
    for k in range(3):
        sph(0.13, (-0.68 + k * 0.38, -0.45, -0.3), INK)


@icon("sun", rot=(0, 0, 0))
def _():
    sph(0.7, m=mat(rgb("ffc93a"), emit=0.6, rough=0.3, coat=0.6))
    for k in range(10):
        a = 2 * math.pi * k / 10
        shape([(-0.16, 0), (0.16, 0), (0, 0.38)], 0.2, (math.sin(a) * 0.95, 0, math.cos(a) * 0.95), ORANGE, rot=(0, math.degrees(a), 0), bevel=0.05)


@icon("cloudy", rot=(0, 0, 0))
def _():
    sph(0.6, (0.55, 0.4, 0.45), mat(rgb("ffc93a"), emit=0.6, rough=0.3, coat=0.6))
    cloud((-0.1, 0, -0.2))


@icon("rain", rot=(0, 0, 0))
def _():
    cloud((0, 0, 0.4), P("aab4c8", rough=0.45))
    for dx, dz in ((-0.55, -0.6), (0.0, -0.8), (0.55, -0.6), (-0.25, -1.15), (0.3, -1.15)):
        sph(0.13, (dx, -0.2, dz), mat(rgb("3fa0ff"), rough=0.05, coat=1.0), scale=(0.8, 0.8, 1.5))


@icon("snow", rot=(0, 0, 0))
def _():
    cloud((0, 0, 0.4), P("e6ecf7", rough=0.45))
    for dx, dz in ((-0.55, -0.7), (0.2, -0.75), (-0.15, -1.2), (0.6, -1.2)):
        shape(star_pts(6, 0.22, 0.07), 0.08, (dx, -0.2, dz), P("bfe3ff", rough=0.2), bevel=0.02)


@icon("storm", rot=(0, 0, 0))
def _():
    cloud((0, 0.2, 0.4), P("6e768a", rough=0.45))
    shape(bolt_pts(0.75), 0.2, (0.05, -0.3, -0.65), mat(rgb("ffd23a"), emit=1.5, rough=0.3), bevel=0.04)


@icon("gift", rot=(12, 0, -20))
def _():
    box((1.6, 1.6, 1.25), (0, 0, -0.45), RED, bevel=0.1)
    box((1.75, 1.75, 0.35), (0, 0, 0.32), P("ff5a4e"), bevel=0.1)
    box((0.32, 1.78, 1.6), (0, 0, -0.3), YELLOW, bevel=0.05)
    box((1.78, 0.32, 1.6), (0, 0, -0.3), YELLOW, bevel=0.05)
    for s in (-1, 1):
        tor(0.3, 0.1, (s * 0.3, 0, 0.72), YELLOW, rot=(90, s * 30, 0))
    sph(0.15, (0, 0, 0.6), YELLOW)


@icon("phone", rot=(5, 0, -15))
def _():
    box((1.15, 0.18, 2.1), (0, 0, 0), DARK, bevel=0.18)
    box((0.98, 0.05, 1.8), (0, -0.09, 0.0), mat(rgb("2b6cff"), emit=0.8, rough=0.2), bevel=0.1)
    for i in range(3):
        for j in range(2):
            box((0.22, 0.04, 0.22), (-0.2 + j * 0.4 - 0.0 + (i - 1) * 0.0, -0.12, 0.45 - i * 0.38), [WHITE, YELLOW, PINK, GREEN, ORANGE, P("8fd3ff")][i * 2 + j], bevel=0.05)


@icon("shop", rot=(8, 0, -15))
def _():
    lathe([(0.0, -1.0), (0.9, -1.0), (0.9, 0.5), (0.0, 0.5)], m=ORANGE, sxy=(1.0, 0.55), seg=4)
    o = list(COL.objects)[-1]
    o.rotation_euler = (0, 0, math.radians(45))
    box((1.3, 0.75, 1.5), (0, 0, -0.25), ORANGE, bevel=0.1)
    o.hide_render = True
    for s in (-1, 1):
        tor(0.28, 0.06, (s * 0.3, -0.25, 0.5), INK, rot=(90, 0, 0), arc=180)
    shape(star_pts(5, 0.38, 0.18), 0.1, (0, -0.4, -0.25), YELLOW, bevel=0.03)


@icon("wrench", rot=(0, -40, 0))
def _():
    head = circle_pts(0.5, 40)
    pts = head
    shape(round_rect(0.36, 1.9, 0.17), 0.25, (0.0, 0, -0.55), STEEL, bevel=0.05)
    o = cyl(0.55, 0.25, (0, 0, 0.55), STEEL, rot=(90, 0, 0), bevel=0.06)
    cut = box((0.42, 1.0, 0.8), (0, 0, 0.9), WHITE, bevel=0.0)
    md = o.modifiers.new("B", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.object = cut
    cut.hide_render = True
    box((0.42, 0.3, 0.85), (0, 0, -1.05), ORANGE, bevel=0.15)
    for o2 in list(COL.objects):
        pass


@icon("teddy", rot=(5, 0, -10))
def _():
    FUR = P("b9783f", rough=0.75, coat=0.0)
    LIGHT = P("e6b98a", rough=0.75, coat=0.0)
    sph(0.62, (0, 0, -0.65), FUR, scale=(1, 0.85, 1.05))
    sph(0.32, (0, -0.35, -0.6), LIGHT, scale=(1, 0.5, 1.1))
    sph(0.55, (0, 0, 0.35), FUR)
    for s in (-1, 1):
        sph(0.22, (s * 0.45, 0, 0.78), FUR)
        sph(0.12, (s * 0.45, -0.1, 0.8), LIGHT, scale=(1, 0.5, 1))
        sph(0.22, (s * 0.65, -0.1, -0.45), FUR, scale=(0.8, 0.8, 1.2))
        sph(0.07, (s * 0.2, -0.48, 0.45), INK)
    sph(0.22, (0, -0.45, 0.2), LIGHT, scale=(1.1, 0.6, 0.8))
    sph(0.09, (0, -0.6, 0.27), INK)
    for s in (-1, 1):
        shape([(0, 0), (0.25 * s, 0.13), (0.25 * s, -0.13)], 0.12, (0, -0.5, -0.12), RED, bevel=0.03)


@icon("spark", rot=(0, 0, 0))
def _():
    # the broken-power sign: a rounded yellow warning triangle, a dark bolt, sparks flying off
    shape(tri_pts(1.15, 0.22), 0.35, (0, 0, 0), P("ffc61a"), bevel=0.1)
    shape(tri_pts(0.92, 0.22), 0.36, (0, -0.02, -0.04), P("ffdb4d"), bevel=0.06)
    shape(bolt_pts(0.68), 0.2, (0.0, -0.22, -0.18), INK, bevel=0.03)
    SP = mat(rgb("ff8a1a"), emit=3.0, rough=0.4)
    for (dx, dz, s, rr) in ((0.78, 0.55, 0.26, 15), (0.55, 0.95, 0.14, 0), (-0.8, 0.5, 0.2, -10), (1.0, 0.1, 0.12, 30)):
        shape(star_pts(4, s, s * 0.25, 90 + rr), 0.08, (dx, -0.25, dz), SP, bevel=0.02)


@icon("grade", rot=(8, 0, -18))
def _():
    hotel_block()
    shape(star_pts(5, 0.45, 0.22), 0.2, (0, -0.2, 1.45), YELLOW, bevel=0.05)


def hotel_block():
    box((1.8, 1.2, 2.0), (0, 0, -0.2), P("f2d7b0"), bevel=0.08)
    box((1.95, 1.3, 0.2), (0, 0, 0.88), RED, bevel=0.06)
    WIN = mat(rgb("6ec2ff"), rough=0.05, coat=1.0)
    for i in range(3):
        for j in range(3):
            if not (j == 0 and i == 1):
                box((0.3, 0.1, 0.3), (-0.55 + i * 0.55, -0.6, 0.45 - j * 0.5), WIN, bevel=0.04)
    box((0.42, 0.1, 0.6), (0, -0.6, -0.9), WOOD, bevel=0.05)
    box((1.0, 0.15, 0.3), (0, -0.62, 1.15), BLUE, bevel=0.06)


@icon("hotel", rot=(8, 0, -18))
def _():
    hotel_block()


ORDER = [k for k in ICONS]


# ---------------------------------------------------------------- stage: camera, lights, render settings (as the hammer)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
scene.camera = cam


def light(name, kind, loc, energy, size=1.0, color=(1, 1, 1)):
    l = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
    scene.collection.objects.link(l)
    l.location = loc
    l.data.energy = energy
    l.data.color = color
    if kind == "AREA":
        l.data.size = size
    l.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return l


light("Key", "AREA", (-4, -6, 6), 900, 4, (1.0, 0.95, 0.88))
light("Fill", "AREA", (6, -4, 1), 300, 5, (0.8, 0.86, 1.0))
light("Rim", "AREA", (2, 6, 5), 700, 3, (1.0, 0.9, 0.75))
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bgn = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bgn.inputs["Color"].default_value = (0.32, 0.33, 0.4, 1)
bgn.inputs["Strength"].default_value = 0.6
r = scene.render
r.engine = "CYCLES"
scene.cycles.samples = 64
scene.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for dt in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = dt
            prefs.get_devices()
            if any(d.type == dt for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == dt
                scene.cycles.device = "GPU"
                break
        except Exception:
            pass
except Exception:
    pass
r.film_transparent = True
r.resolution_x = r.resolution_y = 512
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
try:
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.35
except Exception:
    pass


def clear():
    for o in list(COL.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def frame(root_rot):
    root = bpy.data.objects.new("Root", None)
    COL.objects.link(root)
    for o in COL.objects:
        if o is not root and o.parent is None:
            o.parent = root
    root.rotation_euler = [math.radians(a) for a in root_rot]
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    # the camera looks along +Y from the front, a touch from above
    cam.rotation_euler = (math.radians(84), 0, 0)
    bpy.context.view_layer.update()
    m = cam.matrix_world.to_3x3()
    right, up = m.col[0], m.col[1]
    xs, ys = [], []
    for o in COL.objects:
        if o.type not in ("MESH", "CURVE", "FONT") or o.hide_render:
            continue
        ev = o.evaluated_get(deps)
        try:
            me = ev.to_mesh()
        except Exception:
            continue
        mw = o.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            xs.append(w.dot(right))
            ys.append(w.dot(up))
        ev.to_mesh_clear()
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    fwd = -m.col[2]
    cam.location = right * cx + up * cy - fwd * 30
    cam.data.ortho_scale = span * 1.12
    cam.data.clip_end = 100


names = ORDER if ARGS == ["all"] else ARGS
for n in names:
    if n not in ICONS:
        print("SKIP", n)
        continue
    clear()
    fn, rot = ICONS[n]
    try:
        fn()
        frame(rot)
        r.filepath = os.path.join(OUTDIR, n + "_raw.png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", n)
    except Exception as e:
        import traceback
        traceback.print_exc()
        print("FAILED", n, e)
