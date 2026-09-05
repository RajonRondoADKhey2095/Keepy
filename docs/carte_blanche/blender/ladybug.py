"""Carte-blanche v5 -- the LADYBUG that sometimes falls out of a shaken
tree and scurries off: the first thing that falls and does not lie still.

Oversized for a squirrel, sized for a phone at 11.7 u of camera distance
(~0.32 u long, the acorn's scale): a red dome shell with black spots split
by a seam, a black head with two pale eye dots, six stub legs. Authored
Y-up, body along +Z (its walking direction), origin at the feet. Same
contract as every carte-blanche GLB: COLOR_0 per corner, one flat
KHR_materials_unlit material, no texture. No render sheet tonight (the
sandbox has no libEGL); the control of form is the Godot capture.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from trees import lerp, clamp01
from mathutils import Vector

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

L = 0.32   # body length along z
W = 0.24   # body width
H = 0.15   # shell height
# Few and small: captured with seven spots of r 0.05 the dome read BLACK
# from 11.7 u -- the shell is 0.24 wide, a spot is a pixel or two.
SPOTS = [(0.055, 0.07, 0.03), (-0.055, 0.07, 0.03), (0.06, -0.05, 0.03), (-0.06, -0.05, 0.03)]

def ladybug(seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # shell: the upper half of an ellipsoid (icosphere subdiv 2, y >= 0 kept by squashing)
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        y = max(n.y, -0.05)
        v.co = Vector((n.x * W * 0.5, y * H + 0.03, n.z * L * 0.5 * (1.0 if n.z < 0 else 0.85)))
    shell_verts = set(v.index for v in bm.verts)
    # head: a small black sphere at +z
    head = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.055)
    for v in head["verts"]:
        v.co = Vector((v.co.x, v.co.y * 0.8 + 0.07, v.co.z + L * 0.5 * 0.85 + 0.02))
    # legs: six thin boxes angled down and out
    for side in (1, -1):
        for k, z in enumerate((0.09, 0.0, -0.09)):
            a = math.radians(30 + 15 * (k - 1))
            base = Vector((side * W * 0.42, 0.06, z))
            tip = base + Vector((side * math.cos(a) * 0.07, -0.06, math.sin(a) * 0.03 * (k - 1)))
            d = (tip - base).normalized()
            u = d.cross(Vector((0, 1, 0))).normalized() * 0.012
            w = d.cross(u).normalized() * 0.012
            b0 = [bm.verts.new(tuple(base + s * u + t * w)) for s, t in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
            b1 = [bm.verts.new(tuple(tip + s * u * 0.6 + t * w * 0.6)) for s, t in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
            for i in range(4):
                bm.faces.new((b0[i], b0[(i + 1) % 4], b1[(i + 1) % 4], b1[i]))
            bm.faces.new(tuple(reversed(b1)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj("Ladybug", bm)
    red = (0.97, 0.22, 0.16); dark = (0.10, 0.07, 0.08); pale = (0.96, 0.94, 0.90)
    def paint_l(co, n):
        # legs and head and underside are dark
        if co.z > L * 0.5 * 0.85 - 0.01:
            # head: two pale eye dots
            for ex in (0.028, -0.028):
                if (co.x - ex) ** 2 + (co.y - 0.09) ** 2 < 0.014 ** 2 and co.z > L * 0.5 * 0.85 + 0.04:
                    return pale
            return dark
        if co.y < 0.03 or abs(co.x) > W * 0.5 + 0.005:
            return dark
        # seam down the middle of the shell (a thin line, not a band)
        if abs(co.x) < 0.004 and co.y > 0.08:
            return dark
        for sx, sz, sr in SPOTS:
            if (co.x - sx) ** 2 + (co.z - sz) ** 2 < sr ** 2:
                return dark
        f = 0.92 + 0.18 * clamp01(n.y)
        return tuple(clamp01(c * f) for c in red)
    paint(ob, paint_l)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    ob = ladybug(7)
    ob.data.materials.append(mat)
    ob.name = "ladybug_0"
    stand(ob)
    path = os.path.join(OUT, "ladybug_0.glb")
    export_glb([ob], path)
    tris = post_unlit(path)
    print("STATS", json.dumps({"ladybug_0": {"tris": tris, "bytes": os.path.getsize(path), "length": L, "width": W, "height": H + 0.03}}))
