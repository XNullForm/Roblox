"""Round 14: the BUILD button's hammer, rendered in Blender (a real claw hammer: forged steel head with a
split claw, ash handle with a rubber grip), then outlined in PIL to sit with the other icons.
blender -b --factory-startup -P icon_hammer14.py   ->  ui/hammer14.png
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ui", "hammer14_raw.png")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, base, rough=0.5, metal=0.0, noise=None, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*base, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    try:
        bsdf.inputs["Coat Weight"].default_value = coat
    except KeyError:
        pass
    if noise:
        # wood grain: stretched noise into a colour ramp
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (noise[0], noise[0], noise[1])
        nz = nt.nodes.new("ShaderNodeTexWave")
        nz.inputs["Scale"].default_value = 3.0
        nz.inputs["Distortion"].default_value = 6.0
        nz.inputs["Detail"].default_value = 3.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * 0.62 for c in base], 1)
        ramp.color_ramp.elements[1].color = (*base, 1)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
        nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    return m


STEEL = mat("Steel", (0.62, 0.66, 0.72), 0.28, 1.0)
STEEL_DARK = mat("SteelDark", (0.22, 0.24, 0.28), 0.35, 1.0)
WOOD = mat("Ash", (0.78, 0.5, 0.27), 0.45, 0.0, noise=(1.0, 0.12), coat=0.4)
GRIP = mat("Grip", (0.11, 0.13, 0.24), 0.62)
BRASS = mat("Brass", (0.93, 0.7, 0.32), 0.3, 1.0)


def obj(name, me, m):
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o


def lathe(name, profile, m, segs=48, scale_xy=(1, 1)):
    """revolve (radius, z) points around Z"""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((r * math.cos(a) * scale_xy[0], r * math.sin(a) * scale_xy[1], z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    for p in me.polygons:
        p.use_smooth = True
    return obj(name, me, m)


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
    return o


# ---- handle: ash, flared at the end, rubber grip with ridges, a brass ferrule under the head
handle = lathe("Handle", [
    (0.0, -2.05), (0.2, -2.05), (0.27, -2.0), (0.29, -1.9), (0.25, -1.7), (0.21, -1.2), (0.19, -0.4),
    (0.17, 0.3), (0.165, 0.7), (0.16, 0.95), (0.0, 0.95)], WOOD, scale_xy=(1.0, 0.78))
grip_profile = [(0.0, -2.12), (0.25, -2.12), (0.31, -2.06), (0.33, -1.95)]
z = -1.95
for k in range(7):
    grip_profile += [(0.3, z + 0.06), (0.325, z + 0.12)]
    z += 0.12
grip_profile += [(0.27, -0.95), (0.235, -0.9), (0.0, -0.9)]
grip = lathe("Grip", grip_profile, GRIP, scale_xy=(1.0, 0.8))
ferrule = lathe("Ferrule", [(0.0, 0.62), (0.2, 0.62), (0.215, 0.66), (0.215, 0.82), (0.2, 0.86), (0.0, 0.86)], BRASS, scale_xy=(1.0, 0.82))

# ---- head: a striking face cylinder, the eye block, and a curved split claw
eye = bevel_box("Eye", (0.5, 0.44, 0.52), STEEL, 0.06, loc=(0, 0, 1.05))
neck = lathe("Neck", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.02), (0.19, 0.4), (0.24, 0.62), (0.27, 0.66), (0.27, 0.78), (0.24, 0.82), (0.0, 0.82)], STEEL)
neck.rotation_euler = (0, math.radians(90), 0)
neck.location = (0.2, 0, 1.05)
face_ring = lathe("FaceRing", [(0.0, 0.0), (0.285, 0.0), (0.3, 0.03), (0.3, 0.05), (0.0, 0.05)], STEEL_DARK)
face_ring.rotation_euler = (0, math.radians(90), 0)
face_ring.location = (1.02, 0, 1.05)

# claw: two prongs swept back from the eye and curving down, splitting apart toward the tips
def prong(name, side):
    bm = bmesh.new()
    steps = 20
    prev = None
    R = 1.0
    for s_ in range(steps + 1):
        t = s_ / steps
        ph = 1.15 * t
        cx = -0.24 - R * math.sin(ph)
        cz = 1.08 - R * (1 - math.cos(ph))
        nx, nz = -math.sin(ph), math.cos(ph)
        th = 0.22 * (1 - 0.75 * t) + 0.02
        hw = 0.115 * (1 - 0.45 * t)
        cy = side * (0.115 + 0.09 * t * t)
        ring = []
        for (dy, dt) in ((-hw, -th), (hw, -th), (hw, th), (-hw, th)):
            ring.append(bm.verts.new((cx + nx * dt, cy + dy, cz + nz * dt)))
        if prev:
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((prev[i], prev[j], ring[j], ring[i]))
        else:
            bm.faces.new(list(reversed(ring)))
        prev = ring
    bm.faces.new(prev)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = obj(name, me, STEEL)
    md = o.modifiers.new("Sub", "SUBSURF")
    md.levels = 2
    md.render_levels = 2
    for p in me.polygons:
        p.use_smooth = True
    return o


clawA = prong("ClawA", 1)
clawB = prong("ClawB", -1)

# ---- group, pose: diagonal, head up-right
root = bpy.data.objects.new("Hammer", None)
scene.collection.objects.link(root)
for o in (handle, grip, ferrule, eye, neck, face_ring, clawA, clawB):
    o.parent = root
root.rotation_euler = (math.radians(12), math.radians(-38), math.radians(-6))
root.location = (0, 0, 0.35)

# ---- camera, lights
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 4.4
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
