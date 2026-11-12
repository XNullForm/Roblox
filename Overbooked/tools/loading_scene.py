# Overbooked loading screen (round 14): a rendered night street with the starter hotel.
# blender -b --factory-startup -P loading_scene.py -- <out_dir> <pass: dark|lit> [samples]
# Renders 2048x1152. "dark": windows unlit, doors shut. "lit": every window lit, doors open on a bright lobby.
# Also writes rects.json (window / door / plaque / sign rectangles in pixels) for RAH_Loading.
import bpy, bmesh, math, json, os, sys, random
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.dirname(os.path.abspath(__file__))
PASS = argv[1] if len(argv) > 1 else "dark"
SAMPLES = int(argv[2]) if len(argv) > 2 else 160
LIT = PASS == "lit"
RX, RY = 2048, 1152
os.makedirs(OUT, exist_ok=True)

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scene = bpy.context.scene
col = scene.collection
rng = random.Random(14)

# ---------------------------------------------------------------- materials
def mat(name, color, rough=0.6, metal=0.0, emit=None, estr=0.0, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = estr
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
    return m

def srgb(r, g, b):
    def c(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b))

def brick_mat():
    m = bpy.data.materials.new("Brick")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (math.radians(90), 0, 0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = (*srgb(150, 58, 44), 1)
    br.inputs["Color2"].default_value = (*srgb(118, 44, 36), 1)
    br.inputs["Mortar"].default_value = (*srgb(150, 140, 128), 1)
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Brick Width"].default_value = 0.24
    br.inputs["Row Height"].default_value = 0.08
    br.offset = 0.5
    nt.links.new(mp.outputs["Vector"], br.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.0
    nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.35
    nt.links.new(br.outputs["Color"], mix.inputs[6])
    nt.links.new(noise.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m

def tiles_mat(name, c1, c2, mortar, scale, rough, rows=1.0, width=1.0, wet=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = (*c1, 1)
    br.inputs["Color2"].default_value = (*c2, 1)
    br.inputs["Mortar"].default_value = (*mortar, 1)
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = 0.01
    br.inputs["Brick Width"].default_value = width
    br.inputs["Row Height"].default_value = rows
    nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
    nt.links.new(br.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if wet:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 0.35
        nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.45
        ramp.color_ramp.elements[0].color = (0.06, 0.06, 0.06, 1)
        ramp.color_ramp.elements[1].position = 0.6
        ramp.color_ramp.elements[1].color = (0.55, 0.55, 0.55, 1)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Roughness"])
    return m

M = {
    "brick": brick_mat(),
    "stone": mat("Stone", srgb(196, 186, 168), 0.75),
    "stoneDk": mat("StoneDk", srgb(120, 112, 104), 0.8),
    "trim": mat("Trim", srgb(236, 232, 222), 0.45),
    "black": mat("Black", srgb(22, 22, 26), 0.35, 0.6),
    "brass": mat("Brass", srgb(214, 168, 90), 0.28, 1.0),
    "glass": mat("Glass", srgb(30, 34, 48), 0.04, 0.0),
    "asphalt": tiles_mat("Asphalt", srgb(34, 34, 40), srgb(30, 30, 36), srgb(30, 30, 36), 0.2, 0.3, wet=True),
    "walk": tiles_mat("Walk", srgb(150, 148, 146), srgb(138, 136, 134), srgb(90, 88, 88), 0.8, 0.45, rows=0.5, width=0.5, wet=True),
    "curb": mat("Curb", srgb(160, 158, 154), 0.6),
    "leaf": mat("Leaf", srgb(40, 96, 46), 0.7),
    "pot": mat("Pot", srgb(60, 54, 52), 0.5),
    "yellow": mat("Yellow", srgb(240, 200, 40), 0.4),
    "bulb": mat("Bulb", srgb(255, 230, 180), 0.2, emit=srgb(255, 214, 150), estr=40),
    "moon": mat("Moon", srgb(255, 246, 222), 0.5, emit=srgb(255, 244, 222), estr=6),
    "neighbour": mat("Neighbour", srgb(70, 64, 78), 0.8),
    "neighbour2": mat("Neighbour2", srgb(92, 74, 66), 0.8),
    "roof": mat("Roof", srgb(40, 38, 46), 0.7),
}
# window interiors: lit warm rooms, or dark rooms with a faint cool reflection
CURTAINS = [srgb(232, 220, 196), srgb(168, 52, 54), srgb(56, 108, 80), srgb(230, 196, 120)]
def interior_mat(i):
    warm = [srgb(255, 200, 130), srgb(255, 184, 110), srgb(255, 214, 160), srgb(250, 176, 104)][i % 4]
    if LIT:
        return mat("Room%d" % i, warm, 0.8, emit=warm, estr=rng.uniform(2.2, 3.6))
    return mat("Room%d" % i, srgb(18, 18, 28), 0.9, emit=srgb(30, 34, 60), estr=0.05)

# ---------------------------------------------------------------- helpers
def box(name, x0, x1, y0, y1, z0, z1, m, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o

def cyl(name, x, y, z0, z1, r, m, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o

def sphere(name, loc, r, m, seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o

def light(kind, loc, energy, color, size=0.3, rot=None):
    d = bpy.data.lights.new("L", kind)
    d.energy = energy
    d.color = color
    if kind in ("POINT", "SPOT"):
        d.shadow_soft_size = size
    if kind == "AREA":
        d.size = size
    o = bpy.data.objects.new("L", d)
    o.location = loc
    if rot:
        o.rotation_euler = rot
    col.objects.link(o)
    return o

# ---------------------------------------------------------------- the hotel
HW = 16.0
FLOOR = [0.0, 3.8, 7.0, 10.2]
TOP = 13.4
wall = box("Wall", -HW / 2, HW / 2, 0, 10, 0, TOP, M["brick"])

cut = bmesh.new()
def cutter(x0, x1, z0, z1, depth=0.3):
    bmesh.ops.create_cube(cut, size=1, matrix=__import__("mathutils").Matrix.LocRotScale(
        Vector(((x0 + x1) / 2, depth / 2 - 0.05, (z0 + z1) / 2)), None, Vector((x1 - x0, depth + 0.1, z1 - z0))))

windows = []  # (x0, x1, z0, z1, kind)
COLS = [-6.25, -3.75, -1.25, 1.25, 3.75, 6.25]
for f in (1, 2, 3):
    for x in COLS:
        windows.append((x - 0.62, x + 0.62, FLOOR[f] + 0.85, FLOOR[f] + 2.65, "sash"))
for x in (-6.0, -3.6, 3.6, 6.0):
    windows.append((x - 0.95, x + 0.95, 0.75, 2.95, "shop"))
DOOR = (-1.25, 1.25, 0.18, 3.1)
for w in windows:
    cutter(w[0], w[1], w[2], w[3])
cutter(DOOR[0], DOOR[1], 0.0, DOOR[3], depth=0.6)
cm = bpy.data.meshes.new("Cutter")
cut.to_mesh(cm)
cutObj = bpy.data.objects.new("Cutter", cm)
col.objects.link(cutObj)
mod = wall.modifiers.new("Holes", "BOOLEAN")
mod.operation = "DIFFERENCE"
mod.object = cutObj
mod.solver = "EXACT"
bpy.context.view_layer.objects.active = wall
bpy.ops.object.modifier_apply(modifier="Holes")
bpy.data.objects.remove(cutObj, do_unlink=True)

# plinth, string course, cornice, parapet, side piers
box("Plinth", -HW / 2 - 0.05, HW / 2 + 0.05, -0.12, 0.2, 0, 0.55, M["stoneDk"])
box("String", -HW / 2 - 0.1, HW / 2 + 0.1, -0.22, 0.1, FLOOR[1] - 0.32, FLOOR[1] - 0.06, M["stone"])
for f in (2, 3):
    box("Band%d" % f, -HW / 2, HW / 2, -0.06, 0.1, FLOOR[f] - 0.12, FLOOR[f] + 0.02, M["stone"])
box("Cornice", -HW / 2 - 0.35, HW / 2 + 0.35, -0.5, 0.2, TOP, TOP + 0.35, M["stone"])
box("CorniceLow", -HW / 2 - 0.2, HW / 2 + 0.2, -0.32, 0.1, TOP - 0.25, TOP, M["stone"])
for i in range(40):
    x = -HW / 2 + 0.2 + i * (HW - 0.4) / 39
    box("Dentil", x - 0.08, x + 0.08, -0.26, 0, TOP - 0.45, TOP - 0.25, M["stone"])
box("Parapet", -HW / 2, HW / 2, 0, 0.3, TOP + 0.35, TOP + 1.0, M["brick"])
box("ParapetCap", -HW / 2 - 0.08, HW / 2 + 0.08, -0.08, 0.38, TOP + 1.0, TOP + 1.12, M["stone"])
for x in (-HW / 2, HW / 2):
    box("Pier", x - 0.35, x + 0.35, -0.16, 0.1, 0, TOP, M["brick"])
    for z in [0.6 + k * 0.62 for k in range(20)]:
        if z < TOP - 0.4:
            box("Quoin", x - 0.38, x + 0.38, -0.2, 0.06, z, z + 0.28, M["stone"])
# a rooftop water tank and a vent: a little city character
cyl("Tank", 4.6, 5, TOP + 1.0, TOP + 3.2, 1.0, mat("Tank", srgb(98, 72, 54), 0.85), 32)
cyl("TankRoof", 4.6, 5, TOP + 3.2, TOP + 3.5, 1.08, M["roof"], 32)
for a in range(4):
    ang = a * math.pi / 2 + 0.4
    cyl("TankLeg", 4.6 + math.cos(ang) * 0.8, 5 + math.sin(ang) * 0.8, TOP + 0.35, TOP + 1.0, 0.07, M["black"], 8)
box("Vent", -5.2, -4.4, 3, 3.8, TOP + 1.0, TOP + 1.9, M["roof"])

# ---------------------------------------------------------------- windows
rects = {"windows": [], "size": [RX, RY]}
lights_inside = []
for i, (x0, x1, z0, z1, kind) in enumerate(windows):
    cx, w, h = (x0 + x1) / 2, x1 - x0, z1 - z0
    # reveal (the inside of the opening) in stone-ish plaster
    box("RevealB", x0, x1, 0, 0.3, z0 - 0.02, z0, M["stone"])
    # the room behind
    room = box("Room", x0 - 0.6, x1 + 0.6, 1.4, 1.5, z0 - 0.5, z1 + 0.5, interior_mat(i))
    box("RoomFloor", x0 - 0.6, x1 + 0.6, 0.3, 1.5, z0 - 0.52, z0 - 0.5, M["neighbour2"])
    # frame + mullions (white sash), glass
    t = 0.07
    fy0, fy1 = 0.12, 0.2
    box("FrameL", x0, x0 + t, fy0, fy1, z0, z1, M["trim"])
    box("FrameR", x1 - t, x1, fy0, fy1, z0, z1, M["trim"])
    box("FrameT", x0, x1, fy0, fy1, z1 - t, z1, M["trim"])
    box("FrameB", x0, x1, fy0, fy1, z0, z0 + t, M["trim"])
    if kind == "sash":
        box("MidH", x0, x1, fy0 - 0.02, fy1, (z0 + z1) / 2 - 0.04, (z0 + z1) / 2 + 0.04, M["trim"])
        box("MidV", cx - 0.025, cx + 0.025, fy0, fy1, z0, z1, M["trim"])
        box("MidH2", x0, x1, fy0, fy1, z0 + h * 0.75 - 0.02, z0 + h * 0.75 + 0.02, M["trim"])
        box("MidH3", x0, x1, fy0, fy1, z0 + h * 0.25 - 0.02, z0 + h * 0.25 + 0.02, M["trim"])
    else:
        box("Transom", x0, x1, fy0, fy1, z1 - 0.55, z1 - 0.48, M["trim"])
        box("ShopV", cx - 0.03, cx + 0.03, fy0, fy1, z0, z1 - 0.5, M["trim"])
    g = box("Glass", x0 + 0.02, x1 - 0.02, 0.15, 0.16, z0 + 0.02, z1 - 0.02, M["glass"])
    # curtains drawn to the sides (and half drawn on some)
    cc = mat("Curtain%d" % i, CURTAINS[rng.randrange(len(CURTAINS))], 0.9)
    cw = w * rng.uniform(0.18, 0.3)
    box("CurtL", x0 + 0.05, x0 + 0.05 + cw, 0.4, 0.46, z0 + 0.05, z1 - 0.05, cc)
    box("CurtR", x1 - 0.05 - cw, x1 - 0.05, 0.4, 0.46, z0 + 0.05, z1 - 0.05, cc)
    if kind == "sash":
        box("Valance", x0 + 0.05, x1 - 0.05, 0.38, 0.46, z1 - 0.3, z1 - 0.05, cc)
        # stone sill and lintel with a keystone
        box("Sill", x0 - 0.16, x1 + 0.16, -0.16, 0.12, z0 - 0.16, z0, M["stone"])
        box("Lintel", x0 - 0.12, x1 + 0.12, -0.06, 0.05, z1, z1 + 0.28, M["stone"])
        box("Key", cx - 0.14, cx + 0.14, -0.1, 0.05, z1 - 0.04, z1 + 0.36, M["stone"])
        # a few window boxes with flowers
        if rng.random() < 0.4:
            box("Planter", x0, x1, -0.42, -0.14, z0 - 0.42, z0 - 0.16, M["black"])
            for k in range(7):
                fx = x0 + 0.1 + k * (w - 0.2) / 6
                sphere("Bloom", (fx, -0.28, z0 - 0.1 + rng.uniform(-0.03, 0.05)), rng.uniform(0.09, 0.14),
                       mat("Fl", [srgb(230, 80, 110), srgb(250, 210, 90), srgb(240, 240, 230), srgb(70, 140, 70)][k % 4], 0.7), 12)
    else:
        # a striped awning over each shop window (like the game's)
        pass
    if LIT:
        lights_inside.append(light("POINT", (cx, 0.9, (z0 + z1) / 2 + 0.3), 55 if kind == "sash" else 120, srgb(255, 200, 140), 0.4))
    rects["windows"].append([x0, x1, z0, z1])

# striped awnings: a sloped canopy made of alternating strips with a scalloped-ish valance
def awning(x0, x1, ztop, depth, drop, name):
    n = max(6, int((x1 - x0) / 0.32))
    green, white = mat("AwG", srgb(28, 104, 64), 0.8), mat("AwW", srgb(240, 236, 224), 0.8)
    for k in range(n):
        a = x0 + k * (x1 - x0) / n
        b = x0 + (k + 1) * (x1 - x0) / n
        m_ = green if k % 2 == 0 else white
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in [(a, 0, ztop), (b, 0, ztop), (b, -depth, ztop - drop), (a, -depth, ztop - drop)]]
        bm.faces.new(vs)
        vs2 = [bm.verts.new(v) for v in [(a, -depth, ztop - drop), (b, -depth, ztop - drop), (b, -depth, ztop - drop - 0.38), (a, -depth, ztop - drop - 0.38)]]
        bm.faces.new(vs2)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        o = bpy.data.objects.new(name, me)
        o.data.materials.append(m_)
        sol = o.modifiers.new("S", "SOLIDIFY")
        sol.thickness = 0.03
        col.objects.link(o)
    # side cheeks
    for x in (x0, x1):
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in [(x, 0, ztop), (x, -depth, ztop - drop), (x, -depth, ztop - drop - 0.38), (x, 0, ztop - drop - 0.2)]]
        bm.faces.new(vs)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        o = bpy.data.objects.new(name, me)
        o.data.materials.append(green)
        col.objects.link(o)

for x in (-6.0, -3.6, 3.6, 6.0):
    awning(x - 1.1, x + 1.1, 3.45, 1.0, 0.55, "ShopAwning")
awning(-1.75, 1.75, 3.62, 1.7, 0.6, "DoorAwning")

# ---------------------------------------------------------------- the entrance
x0, x1, z0, z1 = DOOR
box("DoorStep", x0 - 0.4, x1 + 0.4, -0.7, 0.3, 0, 0.18, M["stone"])
box("DoorStep2", x0 - 0.2, x1 + 0.2, -0.35, 0.3, 0.18, 0.3, M["stone"])
# frame
for (a, b) in ((x0, x0 + 0.12), (x1 - 0.12, x1)):
    box("DoorJamb", a, b, 0.1, 0.5, 0.3, z1, M["brass"])
box("DoorHead", x0, x1, 0.1, 0.5, z1 - 0.12, z1, M["brass"])
# the transom panel over the doors: the plaque where the loading percentage sits
PLAQUE = (x0 + 0.25, x1 - 0.25, z1 - 0.72, z1 - 0.18)
box("Plaque", PLAQUE[0], PLAQUE[1], 0.02, 0.12, PLAQUE[2], PLAQUE[3], mat("PlaqueFace", srgb(26, 24, 34), 0.35, 0.3))
box("PlaqueRim", PLAQUE[0] - 0.06, PLAQUE[1] + 0.06, 0.08, 0.14, PLAQUE[2] - 0.06, PLAQUE[3] + 0.06, M["brass"])
box("DoorHead2", x0, x1, 0.1, 0.5, PLAQUE[2] - 0.14, PLAQUE[2] - 0.06, M["brass"])
dz1 = PLAQUE[2] - 0.14
# the lobby behind: warm and bright when lit
lobbyM = mat("Lobby", srgb(255, 214, 160), 0.7, emit=srgb(255, 206, 150), estr=(5.5 if LIT else 0.25))
box("LobbyBack", x0 - 2, x1 + 2, 4.5, 4.6, 0, 3.6, lobbyM)
box("LobbyFloor", x0 - 2, x1 + 2, 0.3, 4.6, 0.28, 0.3, mat("LobbyFloorM", srgb(120, 74, 44), 0.35))
box("LobbyRug", x0 + 0.3, x1 - 0.3, 0.6, 4.4, 0.3, 0.32, mat("Rug", srgb(126, 40, 44), 0.9))
box("DeskBody", -1.4, 1.4, 3.3, 3.9, 0.3, 1.4, mat("Desk", srgb(96, 60, 40), 0.5))
box("DeskTop", -1.5, 1.5, 3.2, 3.95, 1.4, 1.48, M["stone"])
cyl("Bellbase", 0.4, 3.4, 1.48, 1.52, 0.09, M["brass"], 16)
sphere("Bell", (0.4, 3.4, 1.55), 0.08, M["brass"], 12)
if LIT:
    light("AREA", (0, 2.4, 3.3), 900, srgb(255, 208, 150), 3.0, rot=(0, 0, 0))
    light("POINT", (0, 1.0, 2.0), 260, srgb(255, 200, 140), 0.6)
# the two glass doors: shut in the dark pass, swung open into the lobby in the lit pass
for side in (-1, 1):
    hinge = Vector((x0 + 0.12 if side < 0 else x1 - 0.12, 0.3, 0.3))
    leaf_w = (x1 - x0) / 2 - 0.12
    bpy.ops.object.empty_add(location=hinge)
    piv = bpy.context.active_object
    parts = []
    xs, xe = (0, leaf_w) if side < 0 else (-leaf_w, 0)
    parts.append(box("LeafL", hinge.x + xs, hinge.x + xs + 0.1, 0.25, 0.35, 0.3, dz1, M["brass"]))
    parts.append(box("LeafR", hinge.x + xe - 0.1, hinge.x + xe, 0.25, 0.35, 0.3, dz1, M["brass"]))
    parts.append(box("LeafT", hinge.x + xs, hinge.x + xe, 0.25, 0.35, dz1 - 0.1, dz1, M["brass"]))
    parts.append(box("LeafB", hinge.x + xs, hinge.x + xe, 0.25, 0.35, 0.3, 0.6, M["brass"]))
    parts.append(box("LeafG", hinge.x + xs + 0.08, hinge.x + xe - 0.08, 0.28, 0.32, 0.6, dz1 - 0.1, M["glass"]))
    parts.append(box("Handle", hinge.x + (xe - 0.25 if side < 0 else xs + 0.2), hinge.x + (xe - 0.2 if side < 0 else xs + 0.25), 0.18, 0.25, 1.0, 1.9, M["brass"]))
    for p in parts:
        p.parent = piv
        p.matrix_parent_inverse = piv.matrix_world.inverted()
    if LIT:
        piv.rotation_euler = (0, 0, math.radians(-78 if side < 0 else 78))
# a lantern either side of the door
for x in (x0 - 0.55, x1 + 0.55):
    box("LanternArm", x - 0.04, x + 0.04, -0.35, 0, 2.5, 2.56, M["black"])
    box("LanternCap", x - 0.16, x + 0.16, -0.51, -0.19, 2.5, 2.56, M["black"])
    sphere("LanternGlow", (x, -0.35, 2.32), 0.13, M["bulb"], 16)
    box("LanternBase", x - 0.13, x + 0.13, -0.48, -0.22, 2.08, 2.13, M["black"])
    light("POINT", (x, -0.45, 2.3), 45, srgb(255, 200, 140), 0.15)
# potted topiaries by the door
for x in (x0 - 1.0, x1 + 1.0):
    cyl("Pot", x, -0.55, 0, 0.75, 0.38, M["pot"], 24)
    sphere("Topiary", (x, -0.55, 1.25), 0.55, M["leaf"], 20)
    sphere("Topiary2", (x, -0.55, 1.95), 0.36, M["leaf"], 16)

# ---------------------------------------------------------------- the street
box("Sidewalk", -40, 40, -4.6, 0, -0.2, 0.15, M["walk"])
box("Curb", -40, 40, -4.85, -4.6, -0.2, 0.15, M["curb"])
box("Street", -60, 60, -40, -4.6, -0.3, 0.0, M["asphalt"])
# centre line dashes
for k in range(-12, 13):
    box("Dash", k * 5 - 1.4, k * 5 + 1.4, -12.1, -11.9, 0.0, 0.006, mat("Line", srgb(230, 200, 90), 0.4))
# bollards along the curb (black with a yellow band)
for x in (-8.5, -5.5, -2.5, 2.5, 5.5, 8.5):
    cyl("Bollard", x, -4.1, 0.15, 1.15, 0.16, M["black"], 20)
    cyl("BollardBand", x, -4.1, 0.86, 0.98, 0.165, M["yellow"], 20)
    sphere("BollardTop", (x, -4.1, 1.15), 0.16, M["black"], 16)
# street lamps
for x in (-10.6, 10.6):
    cyl("LampPole", x, -3.4, 0.15, 5.2, 0.1, M["black"], 16)
    cyl("LampFoot", x, -3.4, 0.15, 0.8, 0.2, M["black"], 16)
    box("LampArm", x - 0.05, x + 0.05, -3.4, -2.6, 5.05, 5.15, M["black"])
    cyl("LampCap", x, -2.6, 5.15, 5.35, 0.32, M["black"], 20)
    sphere("LampGlobe", (x, -2.6, 4.9), 0.26, M["bulb"], 20)
    light("POINT", (x, -2.6, 4.75), 900, srgb(255, 196, 130), 0.25)
# a bench to the right
box("BenchSeat", 7.2, 9.4, -2.9, -2.4, 0.6, 0.68, mat("Wood", srgb(170, 110, 60), 0.6))
box("BenchBack", 7.2, 9.4, -2.42, -2.34, 0.7, 1.25, mat("Wood2", srgb(170, 110, 60), 0.6))
for x in (7.35, 9.25):
    box("BenchLeg", x - 0.05, x + 0.05, -2.9, -2.35, 0.15, 0.62, M["black"])

# ---------------------------------------------------------------- neighbours and the city behind
def building(x0, x1, y0, h, m, lit_chance, seed):
    r = random.Random(seed)
    box("Bldg", x0, x1, y0, y0 + 12, 0, h, m)
    box("BldgCap", x0 - 0.2, x1 + 0.2, y0 - 0.2, y0 + 12, h, h + 0.3, M["stoneDk"])
    nx = max(1, int((x1 - x0) / 2.3))
    for fl in range(1, int(h / 3.2)):
        for k in range(nx):
            wx = x0 + (k + 0.5) * (x1 - x0) / nx
            on = r.random() < lit_chance
            mm = mat("NW", srgb(255, 196, 120) if on else srgb(20, 22, 32), 0.5, emit=srgb(255, 190, 120) if on else None, estr=r.uniform(1.5, 3) if on else 0)
            box("NWin", wx - 0.55, wx + 0.55, y0 - 0.05, y0, fl * 3.2 + 0.7, fl * 3.2 + 2.3, mm)
box("GapL", -11.5, -8.4, 2, 3, 0, 9, M["roof"])
building(-26, -11.5, 1.0, 10.5, M["neighbour2"], 0.35, 1)
building(11.8, 26, 0.6, 15.5, M["neighbour"], 0.3, 2)
for k in range(26):
    bx = rng.uniform(-70, 70)
    bw = rng.uniform(5, 12)
    bh = rng.uniform(16, 42)
    by = rng.uniform(30, 70)
    building(bx - bw / 2, bx + bw / 2, by, bh, mat("Far", srgb(36, 34, 58), 0.9), 0.18, 100 + k)

# moon
sphere("Moon", (34, 160, 62), 5.5, M["moon"], 48)

# ---------------------------------------------------------------- world: a navy-to-violet night with stars
world = bpy.data.worlds.new("Night")
scene.world = world
world.use_nodes = True
nt = world.node_tree
bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
tc = nt.nodes.new("ShaderNodeTexCoord")
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
ramp = nt.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (*srgb(70, 46, 92), 1)
ramp.color_ramp.elements[1].position = 0.35
ramp.color_ramp.elements[1].color = (*srgb(12, 14, 38), 1)
nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
vor = nt.nodes.new("ShaderNodeTexVoronoi")
vor.inputs["Scale"].default_value = 220
nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
sr = nt.nodes.new("ShaderNodeValToRGB")
sr.color_ramp.elements[0].position = 0.0
sr.color_ramp.elements[0].color = (1, 1, 1, 1)
sr.color_ramp.elements[1].position = 0.035
sr.color_ramp.elements[1].color = (0, 0, 0, 1)
nt.links.new(vor.outputs["Distance"], sr.inputs["Fac"])
add = nt.nodes.new("ShaderNodeMix")
add.data_type = "RGBA"
add.blend_type = "ADD"
add.inputs["Factor"].default_value = 1.0
nt.links.new(ramp.outputs["Color"], add.inputs[6])
nt.links.new(sr.outputs["Color"], add.inputs[7])
nt.links.new(add.outputs[2], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 1.0
# moonlight
sun = light("SUN", (0, 0, 30), 0.35, srgb(160, 180, 255), rot=(math.radians(55), 0, math.radians(200)))
sun.data.angle = math.radians(1.5)

# ---------------------------------------------------------------- camera
cd = bpy.data.cameras.new("Cam")
cd.lens = 32
cd.sensor_width = 36
cd.shift_y = 0.135
cam = bpy.data.objects.new("Cam", cd)
cam.location = (0, -28.5, 3.3)
cam.rotation_euler = (math.radians(90), 0, 0)
col.objects.link(cam)
scene.camera = cam
cd.dof.use_dof = True
cd.dof.focus_distance = 28.5
cd.dof.aperture_fstop = 2.2

# ---------------------------------------------------------------- render
scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.use_adaptive_sampling = True
scene.cycles.adaptive_threshold = 0.015
scene.cycles.use_denoising = True
try:
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
except Exception:
    pass
scene.cycles.max_bounces = 6
scene.render.resolution_x = RX
scene.render.resolution_y = RY
scene.render.resolution_percentage = 100
try:
    scene.view_settings.view_transform = "AgX"
    looks = [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items]
    for want in ("AgX - Medium High Contrast", "Medium High Contrast"):
        if want in looks:
            scene.view_settings.look = want
            break
except Exception as e:
    print("view", e)
scene.view_settings.exposure = 0.35
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(OUT, "load_%s.png" % PASS)

# rectangles in pixels (top-left origin)
bpy.context.view_layer.update()
def px(p):
    v = world_to_camera_view(scene, cam, Vector(p))
    return [v.x * RX, (1 - v.y) * RY]
def rect(x0, x1, z0, z1, y=0.0):
    a, b = px((x0, y, z1)), px((x1, y, z0))
    return [round(a[0], 1), round(a[1], 1), round(b[0], 1), round(b[1], 1)]
out = {"size": [RX, RY]}
out["windows"] = [rect(*w) for w in rects["windows"]]
out["door"] = rect(DOOR[0] + 0.12, DOOR[1] - 0.12, 0.3, dz1, 0.2)
out["plaque"] = rect(*PLAQUE, 0.02)
out["sign"] = rect(-6.5, 6.5, TOP + 1.2, TOP + 4.0, 0)
out["roofY"] = px((0, 0, TOP + 1.12))[1]
out["lamps"] = [px((x, -2.6, 4.9)) for x in (-10.6, 10.6)]
out["lanterns"] = [px((x, -0.35, 2.32)) for x in (DOOR[0] - 0.55, DOOR[1] + 0.55)]
out["moon"] = px((34, 160, 62))
with open(os.path.join(OUT, "rects.json"), "w") as f:
    json.dump(out, f, indent=1)
if SAMPLES > 0:
    bpy.ops.render.render(write_still=True)
print("DONE", PASS)
