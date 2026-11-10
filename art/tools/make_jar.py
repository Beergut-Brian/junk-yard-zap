# Builds store/jar.glb: Junk Yard Zap's tiny world for the Open Jar launcher's hub jar (GAME.md
# "Store art"). Art lane. Run through art/tools/make_jar.sh (Blender 5.2.3, background).
#
# Launcher contract (openjar-launcher docs/contracts.md, "Jar world"; same as Spaceballs' jar):
# Y up, origin at the centre of the floor, fits a cylinder r 0.8 m x h 1.9 m, reads from every side
# (turntable), no text, <= 5,000 triangles, <= 8 materials, textures <= 512 px, no external files.
# Flat colours come from one 32 px palette texture with per-face UVs: the launcher's runtime
# GLTFDocument drops vertex colours on untextured materials.
#
# The diorama: a round patch of yard dirt with a bit of picket fence, a scrap pile (rusty blocks,
# a tyre, an old fridge), and a giant spotted cow floating over it on a magenta balloon. Golden
# Afternoon palette (scripts/art/art_kit.gd).
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "store/jar.glb")
def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)



# Golden Afternoon (scripts/art/art_kit.gd), balloon from the fixed gun hues.
GROUND = hexc("c9965c")
GROUND_DARK = hexc("94653c")
FENCE = hexc("b88a58")
FENCE_DARK = hexc("7f5a39")
RUST = hexc("c45a28")
RUST_DARK = hexc("86391b")
METAL = hexc("97a3ab")
ENAMEL = hexc("f4ecda")
CRATE = hexc("d9a75e")
RUBBER = hexc("38302e")
CAR = hexc("d97a34")
TEAL = hexc("3f9e9a")
COW = hexc("fbf5ea")
SPOT = hexc("4d3b33")
PINK = hexc("f3b3b0")
INK = hexc("24181a")
WHITE = hexc("ffffff")
BALLOON = hexc("ec3cf0")
CLOUD = hexc("fff4e2")
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


PALETTE = {}            # linear RGBA -> cell index in the palette texture
PAL_CELLS = 8           # 8 x 8 cells
PAL_CELL_PX = 4         # 32 x 32 px texture


def pal_uv(c):
    key = tuple(round(x, 4) for x in c[:3])
    if key not in PALETTE:
        assert len(PALETTE) < PAL_CELLS * PAL_CELLS, "palette full"
        PALETTE[key] = len(PALETTE)
    i = PALETTE[key]
    return ((i % PAL_CELLS + 0.5) / PAL_CELLS, (i // PAL_CELLS + 0.5) / PAL_CELLS)


def colour_faces(obj, fn, skip=None):
    """Points every corner of a face at its colour's cell: fn(face_index, face_centre) -> colour."""
    me = obj.data
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        if skip and skip(poly):
            continue
        u = pal_uv(fn(poly.index, poly.center))
        for li in poly.loop_indices:
            uv.data[li].uv = u


def from_bmesh(name, bm, colour, smooth=False):
    for f in bm.faces:
        f.smooth = smooth
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    colour_faces(obj, colour if callable(colour) else (lambda i, p: colour))
    return obj


def place(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Blender is Z up; glTF export turns it into Y up with -Y(blender) -> +Z(front)."""
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    return obj


def cylinder(name, r1, r2, depth, segs, colour, cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return from_bmesh(name, bm, colour)


def sphere(name, r, segs, rings, colour):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return from_bmesh(name, bm, colour, smooth=True)


def ico(name, r, subdiv, colour):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return from_bmesh(name, bm, colour, smooth=True)




def rbox(name, size, colour, bevel=0.02, segs=1):
    """A box with bevelled edges; segs > 1 rounds them smooth (the toy look of the cow)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segs, affect="EDGES", profile=0.5)
    return from_bmesh(name, bm, colour, smooth=segs > 1)


def torus(name, r_major, r_minor, colour, segs=14, ring=6):
    bm = bmesh.new()
    for i in range(segs):
        for j in range(ring):
            a, b = 2 * math.pi * i / segs, 2 * math.pi * j / ring
            bm.verts.new(((r_major + r_minor * math.cos(b)) * math.cos(a), (r_major + r_minor * math.cos(b)) * math.sin(a), r_minor * math.sin(b)))
    bm.verts.ensure_lookup_table()
    for i in range(segs):
        for j in range(ring):
            q = [bm.verts[(i * ring + j)], bm.verts[((i + 1) % segs) * ring + j], bm.verts[((i + 1) % segs) * ring + (j + 1) % ring], bm.verts[i * ring + (j + 1) % ring]]
            bm.faces.new(q)
    return from_bmesh(name, bm, colour, smooth=True)


_pal_mat = None


def palette_material():
    global _pal_mat
    if _pal_mat is None:
        _pal_mat = bpy.data.materials.new("junkyard_palette")
        _pal_mat.use_nodes = True
        nt = _pal_mat.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        t = nt.nodes.new("ShaderNodeTexImage")
        t.interpolation = "Closest"
        t.name = "pal"
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.7
    return _pal_mat


def bake_palette():
    px = PAL_CELLS * PAL_CELL_PX
    img = bpy.data.images.new("junkyard_palette", px, px, alpha=False)
    buf = [1.0] * (px * px * 4)
    for c, i in PALETTE.items():
        srgb = [12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055 for x in c]
        cx, cy = (i % PAL_CELLS) * PAL_CELL_PX, (i // PAL_CELLS) * PAL_CELL_PX
        for y in range(cy, cy + PAL_CELL_PX):
            for x in range(cx, cx + PAL_CELL_PX):
                buf[(y * px + x) * 4:(y * px + x) * 4 + 3] = srgb
    img.pixels = buf
    img.pack()
    palette_material().node_tree.nodes["pal"].image = img


# ---------------------------------------------------------------- the diorama (Blender Z up, -Y front)

def ground():
    top = cylinder("Dirt", 0.78, 0.78, 0.1, 28, lambda i, p: GROUND if p.z > 0.04 else GROUND_DARK)
    place(top, (0, 0, 0.05))
    rnd = random.Random(44)
    for k in range(10):
        a, r = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.3, 0.7)
        s = sphere("Pebble%d" % k, rnd.uniform(0.02, 0.035), 6, 4, METAL if k % 3 == 0 else GROUND_DARK)
        place(s, (math.cos(a) * r, math.sin(a) * r, 0.1), scale=(1.3, 1.0, 0.5))
    return 0.1


def fence(g):
    # An arc of pickets round the back, with two rails.
    for k in range(13):
        a = math.radians(35 + k * 9.0)
        h = 0.36 + 0.04 * ((k * 7) % 3)
        p = rbox("Picket%d" % k, (0.07, 0.025, h), FENCE if k % 4 else FENCE_DARK, 0.008)
        place(p, (math.cos(a) * 0.7, math.sin(a) * 0.7, g + h / 2), (0, 0, a + math.pi / 2))
    for z in (0.1, 0.27):
        for k in range(4):
            a = math.radians(38 + k * 27 + 13.5)
            r = rbox("Rail", (0.17, 0.015, 0.03), FENCE_DARK, 0.005)
            place(r, (math.cos(a) * 0.685, math.sin(a) * 0.685, g + z), (0, 0, a + math.pi / 2))


def scrap_pile(g):
    mound = sphere("Mound", 0.42, 12, 6, lambda i, p: RUST_DARK if p.z < 0.1 else GROUND_DARK)
    place(mound, (0.0, 0.05, 0.172), scale=(1.15, 0.9, 0.4))   # bottom just above the floor
    rnd = random.Random(7)
    cols = [RUST, METAL, CAR, CRATE, RUST_DARK, ENAMEL, TEAL]
    for k in range(11):
        a, r = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.0, 0.32)
        sz = (rnd.uniform(0.1, 0.2), rnd.uniform(0.08, 0.16), rnd.uniform(0.06, 0.12))
        b = rbox("Junk%d" % k, sz, cols[k % len(cols)], 0.015)
        place(b, (math.cos(a) * r, 0.05 + math.sin(a) * r * 0.8, g + 0.12 + (0.32 - r) * 0.5),
              (rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(0, 3)))
    t = torus("Tyre", 0.085, 0.04, RUBBER)
    place(t, (-0.3, -0.25, g + 0.1), (1.2, 0.2, 0.3))
    hub = cylinder("Hub", 0.045, 0.045, 0.03, 10, METAL)
    place(hub, (-0.3, -0.25, g + 0.1), (1.2, 0.2, 0.3))
    fr = rbox("Fridge", (0.16, 0.13, 0.3), ENAMEL, 0.03)
    place(fr, (0.3, 0.12, g + 0.2), (0.1, -0.25, -0.4))
    hd = rbox("FridgeHandle", (0.012, 0.02, 0.1), METAL, 0.004)
    place(hd, (0.27, 0.04, g + 0.24), (0.1, -0.25, -0.4))
    return g + 0.55


def eye(name, at, look):
    w = sphere(name, 0.045, 8, 6, WHITE)
    place(w, at, scale=(1.0, 0.6, 1.15))
    p = sphere(name + "P", 0.024, 6, 4, INK)
    place(p, (at[0] + look[0] * 0.015, at[1] - 0.025, at[2] + look[1] * 0.015))


def cow(at):
    x, y, z = at
    body = rbox("CowBody", (0.56, 0.3, 0.3), COW, 0.09, 3)
    place(body, at)
    for k, (dx, dz, side) in enumerate([(-0.12, 0.05, -1), (0.1, -0.04, -1), (-0.05, 0.02, 1), (0.15, 0.06, 1)]):
        s = sphere("Spot%d" % k, 0.07, 8, 5, SPOT)
        place(s, (x + dx, y + side * 0.15, z + dz), scale=(1.3, 0.35, 1.0))
    for lx in (-0.18, 0.17):
        for ly in (-0.09, 0.09):
            leg = cylinder("Leg", 0.04, 0.04, 0.16, 8, lambda i, p: SPOT if p.z < -0.05 else COW)
            place(leg, (x + lx, y + ly, z - 0.2), (0, 0, 0))
    head = rbox("CowHead", (0.2, 0.22, 0.2), COW, 0.07, 3)
    place(head, (x + 0.35, y, z + 0.08))
    snout = rbox("Snout", (0.1, 0.18, 0.1), PINK, 0.04, 2)
    place(snout, (x + 0.45, y, z + 0.03))
    for side in (-1, 1):
        n = sphere("Nostril", 0.012, 6, 4, INK)
        place(n, (x + 0.505, y + side * 0.035, z + 0.04))
        horn = cylinder("Horn", 0.018, 0.004, 0.07, 6, ENAMEL)
        place(horn, (x + 0.32, y + side * 0.07, z + 0.21), (side * -0.4, 0, 0))
        ear = sphere("Ear", 0.035, 6, 4, COW)
        place(ear, (x + 0.3, y + side * 0.13, z + 0.14), scale=(0.6, 1.4, 0.5))
        # Wide eyes on both sides of the head, so it's surprised from every angle of the turntable.
        eye("Eye", (x + 0.41, y + side * 0.06, z + 0.13), (0.3, 0.5))
    tail = cylinder("Tail", 0.012, 0.012, 0.18, 6, COW)
    place(tail, (x - 0.31, y, z + 0.0), (0, 0.6, 0))
    tuft = sphere("Tuft", 0.025, 6, 4, SPOT)
    place(tuft, (x - 0.36, y, z - 0.08))
    udder = sphere("Udder", 0.05, 8, 5, PINK)
    place(udder, (x - 0.02, y, z - 0.15), scale=(1.2, 1.0, 0.6))


def balloon(tie, top):
    b = sphere("Balloon", 0.17, 14, 9, BALLOON)
    place(b, (tie[0] - 0.05, tie[1], top - 0.2), scale=(1.0, 1.0, 1.18))
    shine = sphere("Shine", 0.035, 6, 4, WHITE)
    place(shine, (tie[0] - 0.12, tie[1] - 0.12, top - 0.12), scale=(0.7, 0.5, 1.0))
    knot = cylinder("Knot", 0.012, 0.03, 0.04, 8, BALLOON)
    place(knot, (tie[0] - 0.045, tie[1], top - 0.42))
    s = Vector((tie[0] - 0.045, tie[1], top - 0.44)) - Vector(tie)
    st = cylinder("String", 0.004, 0.004, s.length, 5, INK)
    mid = Vector(tie) + s * 0.5
    place(st, tuple(mid), (0, math.atan2(s.x, s.z), 0))
    ring = torus("Tie", 0.025, 0.008, BALLOON, 10, 4)
    place(ring, tie)


def cloud(at, s):
    for k, (dx, dz, r) in enumerate([(-0.09, 0, 0.08), (0, 0.04, 0.1), (0.1, 0.0, 0.08)]):
        c = sphere("Cloud%d" % k, r * s, 10, 6, CLOUD)
        place(c, (at[0] + dx * s, at[1], at[2] + dz * s), scale=(1.0, 0.8, 0.85))


def main():
    reset()
    g = ground()
    fence(g)
    top = scrap_pile(g)
    # The giant cow: built at cow size, then grown (it's had the grow gun).
    before = set(bpy.context.scene.objects)
    at = Vector((-0.08, 0.0, 1.02))
    cow(tuple(at))
    for o in set(bpy.context.scene.objects) - before:
        o.location = at + (o.location - at) * 1.32
        o.scale = o.scale * 1.32
    balloon((-0.1, 0.0, 1.24), 1.88)
    cloud((0.45, 0.25, 1.55), 1.0)
    cloud((-0.5, -0.15, 1.35), 0.8)

    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.data.materials:
            o.data.materials.append(palette_material())
    bake_palette()

    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    mats = {m.name for o in bpy.context.scene.objects if o.type == "MESH" for m in o.data.materials[:]}
    print("make_jar: %d triangles, %d materials %s, pile top %.2f" % (tris, len(mats), sorted(mats), top))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_yup=True,
                              export_vertex_color="NONE",
                              export_animations=False, export_lights=False, export_cameras=False,
                              export_image_format="AUTO")
    print("make_jar: wrote", OUT)


main()
