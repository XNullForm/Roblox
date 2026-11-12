"""Round 14 (2026-11-09): the bottom bar's icons, rendered like the hammer (icon_hammer14.py).
blender -b --factory-startup -P icon_bar14.py -- bell|cap|flask|trophy|gear   ->  ui/bar_<name>_raw.png
then: python outline_icon.py ui/bar_<name>_raw.png ui/bar_<name>.png
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
NAME = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(HERE, "ui", "bar_%s_raw.png" % NAME)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, base, rough=0.5, metal=0.0, coat=0.0, glass=False, emit=None, wood=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*base, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    for k, v in (("Coat Weight", coat), ("Transmission Weight", 1.0 if glass else 0.0), ("IOR", 1.45)):
        try:
            b.inputs[k].default_value = v
        except KeyError:
            pass
    if emit:
        try:
            b.inputs["Emission Color"].default_value = (*emit[0], 1)
            b.inputs["Emission Strength"].default_value = emit[1]
        except KeyError:
            pass
    if wood:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (1.0, 1.0, 0.12)
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.inputs["Scale"].default_value = 3.0
        wv.inputs["Distortion"].default_value = 6.0
        wv.inputs["Detail"].default_value = 3.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * 0.6 for c in base], 1)
        ramp.color_ramp.elements[1].color = (*base, 1)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], wv.inputs["Vector"])
        nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


BRASS = mat("Brass", (0.95, 0.68, 0.26), 0.22, 1.0)
GOLD = mat("Gold", (1.0, 0.74, 0.22), 0.18, 1.0)
WALNUT = mat("Walnut", (0.42, 0.22, 0.11), 0.4, 0.0, coat=0.5, wood=True)
STEEL = mat("Steel", (0.66, 0.7, 0.76), 0.3, 1.0)
STEEL_DK = mat("SteelDk", (0.25, 0.27, 0.32), 0.35, 1.0)
RED = mat("Red", (0.72, 0.06, 0.06), 0.42, 0.0, coat=0.3)
BLACK = mat("Black", (0.04, 0.04, 0.05), 0.35)
GLASS = mat("Glass", (0.92, 0.97, 1.0), 0.02, glass=True)
LIQUID = mat("Liquid", (0.05, 0.75, 0.42), 0.1, emit=((0.15, 1.0, 0.6), 0.6))
CORK = mat("Cork", (0.72, 0.52, 0.32), 0.8)
CREAM = mat("Cream", (0.95, 0.9, 0.8), 0.5)

root = bpy.data.objects.new("Root", None)
scene.collection.objects.link(root)


def obj(name, me, m, smooth=True):
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o.parent = root
    return o


def lathe(name, profile, m, segs=64, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r <= 0:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)])
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], b[0], a[j]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = obj(name, me, m)
    o.location = loc
    o.rotation_euler = rot
    return o


def tube(name, pts, radius, m, closed=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 6
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for p, c in zip(sp.bezier_points, pts):
        p.co = c
        p.handle_left_type = p.handle_right_type = "AUTO"
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(o)
    o.data.materials.append(m)
    o.parent = root
    return o


def bevel_box(name, size, m, bevel=0.05, loc=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    md = o.modifiers.new("Bevel", "BEVEL")
    md.width = bevel
    md.segments = 4
    md.limit_method = "NONE"
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    o.parent = root
    return o


def sphere(name, r, m, loc):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=32, ring_count=16)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    o.parent = root
    return o


tilt = (math.radians(18), 0, math.radians(-22))
scale = 4.2

if NAME == "bell":
    # a front-desk service bell: walnut base, brass dome, the plunger on top
    lathe("Base", [(0, -0.5), (1.55, -0.5), (1.62, -0.44), (1.62, -0.2), (1.5, -0.12), (1.4, -0.08), (0, -0.08)], WALNUT)
    lathe("Rim", [(0, -0.1), (1.32, -0.1), (1.36, -0.04), (1.3, 0.0), (0, 0.0)], BRASS)
    prof = []
    for i in range(25):
        a = (math.pi / 2) * i / 24
        prof.append((1.28 * math.cos(a), 0.0 + 1.05 * math.sin(a)))
    prof[-1] = (0.0, 1.05)
    lathe("Dome", [(1.32, -0.02)] + prof, BRASS)
    lathe("Stem", [(0, 1.0), (0.11, 1.0), (0.11, 1.42), (0, 1.42)], STEEL)
    lathe("Button", [(0, 1.38), (0.34, 1.38), (0.38, 1.44), (0.36, 1.54), (0.2, 1.6), (0, 1.62)], BRASS)
    tilt = (math.radians(20), 0, math.radians(-18))
    scale = 4.0
elif NAME == "cap":
    # a bellhop's pillbox cap: red felt, gold braid bands, a black chin strap and gold buttons
    lathe("Crown", [(0, 0), (1.18, 0), (1.2, 0.05), (1.26, 1.05), (1.24, 1.12), (1.15, 1.17), (0, 1.2)], RED)
    lathe("BandLow", [(1.205, 0.06), (1.25, 0.06), (1.27, 0.12), (1.27, 0.24), (1.25, 0.3), (1.215, 0.3)], GOLD)
    lathe("BandTop", [(1.255, 0.98), (1.3, 1.0), (1.3, 1.08), (1.26, 1.12)], GOLD)
    pts = []
    for i in range(9):
        a = math.pi * (0.06 + 0.88 * i / 8)
        pts.append((1.3 * math.cos(a) * -1, -1.3 * math.sin(a) * 0.35 - 0.05, 0.18 - 0.55 * math.sin(a)))
    tube("Strap", [(-1.27, -0.05, 0.18), (-1.05, -0.62, -0.22), (0.0, -0.9, -0.42), (1.05, -0.62, -0.22), (1.27, -0.05, 0.18)], 0.06, BLACK)
    for s in (-1, 1):
        sphere("Btn", 0.13, GOLD, (s * 1.27, -0.05, 0.18))
    lathe("Top", [(0, 1.17), (0.5, 1.18), (0.0, 1.21)], RED)
    em = sphere("Emblem", 0.2, GOLD, (0, -1.24, 0.62))
    em.scale = (1, 0.35, 1)
    tilt = (math.radians(9), 0, math.radians(-16))
    scale = 4.0
elif NAME == "flask":
    # an Erlenmeyer flask, green brew inside, a cork and bubbles rising out of it
    prof = [(0, -1.1), (1.05, -1.1), (1.15, -1.02), (1.16, -0.9), (0.95, -0.35), (0.62, 0.25), (0.34, 0.75), (0.34, 1.25), (0.4, 1.3), (0.4, 1.36), (0.3, 1.38)]
    lathe("Glass", prof + [(0.28, 1.3), (0.28, 0.75), (0.56, 0.25), (0.89, -0.35), (1.08, -0.92), (0.98, -1.03), (0, -1.03)], GLASS)
    lathe("Brew", [(0, -1.02), (0.97, -1.02), (1.06, -0.92), (0.88, -0.38), (0.72, -0.1), (0, -0.1)], LIQUID)
    lathe("Cork", [(0, 1.2), (0.27, 1.2), (0.33, 1.6), (0, 1.62)], CORK)
    for (x, y, z, r) in ((0.25, 0, 0.3, 0.1), (-0.1, 0, 0.62, 0.075), (0.6, -0.2, 1.75, 0.13), (0.9, -0.1, 2.12, 0.09)):
        sphere("Bubble", r, LIQUID if z < 1 else GLASS, (x, y, z))
    scale = 4.4
elif NAME == "trophy":
    # a gold cup with looped handles on a walnut plinth with a brass plate
    bevel_box("Plinth", (1.7, 1.25, 0.55), WALNUT, 0.06, loc=(0, 0, -1.45))
    bevel_box("Plate", (0.95, 0.04, 0.26), BRASS, 0.015, loc=(0, -0.64, -1.45))
    lathe("Foot", [(0, -1.17), (0.68, -1.17), (0.7, -1.1), (0.5, -1.0), (0.2, -0.86), (0.13, -0.6), (0.12, -0.32), (0.22, -0.22), (0.12, -0.12), (0, -0.12)], GOLD)
    prof = [(0, -0.2)]
    for i in range(1, 21):
        t = i / 20
        prof.append((0.98 * math.sin(t * math.pi / 2) ** 0.7, -0.2 + 1.55 * t))
    prof += [(1.08, 1.36), (1.06, 1.42), (0.94, 1.38), (0.0, 1.0)]
    lathe("Cup", prof, GOLD)
    for s in (-1, 1):
        tube("Handle", [(s * 0.86, 0, 1.15), (s * 1.45, 0, 1.05), (s * 1.42, 0, 0.45), (s * 0.7, 0, 0.25)], 0.09, GOLD)
    scale = 4.5
elif NAME == "gear":
    # a chunky steel cog with a brass hub
    bm = bmesh.new()
    teeth, ro, ri, th = 9, 1.5, 1.18, 0.42
    outer = []
    n = teeth * 4
    for i in range(n):
        a = 2 * math.pi * i / n
        r = ro if (i % 4) in (1, 2) else ri
        outer.append(bm.verts.new((r * math.cos(a), r * math.sin(a), -th / 2)))
    hole = [bm.verts.new((0.52 * math.cos(2 * math.pi * i / n), 0.52 * math.sin(2 * math.pi * i / n), -th / 2)) for i in range(n)]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((outer[i], outer[j], hole[j], hole[i]))
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]:
        v.co.z += th
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("Cog")
    bm.to_mesh(me)
    cog = obj("Cog", me, STEEL, smooth=False)
    bv = cog.modifiers.new("Bevel", "BEVEL")
    bv.width = 0.05
    bv.segments = 3
    cog.rotation_euler = (math.radians(90), 0, 0)
    lathe("Hub", [(0.0, -0.3), (0.62, -0.3), (0.68, -0.24), (0.68, 0.24), (0.62, 0.3), (0.0, 0.3)], BRASS, rot=(math.radians(90), 0, 0))
    lathe("Bolt", [(0, -0.36), (0.22, -0.36), (0.22, 0.36), (0, 0.36)], STEEL_DK, rot=(math.radians(90), 0, 0))
    tilt = (math.radians(12), math.radians(14), math.radians(-24))
    scale = 3.9

root.rotation_euler = tilt

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = scale
cam.location = (0, -10, 0.15)
cam.rotation_euler = (math.radians(90), 0, 0)
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
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.32, 0.33, 0.4, 1)
bg.inputs["Strength"].default_value = 0.6

r = scene.render
try:
    r.engine = "CYCLES"
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
except Exception:
    pass
r.film_transparent = True
r.resolution_x = r.resolution_y = 512
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
try:
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass
r.filepath = OUT
bpy.ops.render.render(write_still=True)
print("RENDERED", OUT)
