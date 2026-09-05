"""Carte-blanche v4 -- the CLIMBABLE tree family ("arbre-perchoir") and the
nuts it drops.

Why a family of its own and not a flag on the round trees: the brief asks
for a silhouette a player recognises as climbable at a glance, and for a
seat where Keepy stays VISIBLE from the fixed camera (pitch -34 deg, frame
top at +2.4 deg over the horizon). Both are shape decisions:

  * a TALL, STRAIGHT, BARE trunk (3.3 u, ringed bark) -- the round trees
    hide theirs under a canopy that starts at 1.5 u; this one shows 2.6 u
    of trunk, which is the ladder the eye reads;
  * a WREATH canopy: a ring of lobes around the trunk top with an OPEN
    centre, floored by a flat leaf pad. Keepy sits on the pad, so his
    body rises above the ring (pad top ~3.45, ring tops ~3.9-4.0, his head
    ~5.1) and is framed by leaves rather than buried in them. From the
    camera's elevation the ring's near lobes sit under his feet.

Nuts: an acorn (oval body, cap, stalk) and a hazelnut (round, pale base),
~0.3 u tall -- oversized for a squirrel, sized for a phone at 11.7 u of
camera distance (~35 px). Same contract as every carte-blanche GLB:
COLOR_0 per corner, one flat KHR_materials_unlit material, no texture.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from trees import trunk_bm, blob_bm, join, lerp, clamp01

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

# canopy (top, bottom), trunk (light, dark), pad (top, bottom) -- sRGB
PALETTES = {
    "lime":  (((0.76, 0.88, 0.40), (0.42, 0.64, 0.26)), ((0.60, 0.44, 0.28), (0.40, 0.27, 0.16)), ((0.62, 0.80, 0.34), (0.44, 0.64, 0.26))),
    "jade":  (((0.58, 0.84, 0.52), (0.30, 0.58, 0.36)), ((0.56, 0.40, 0.26), (0.36, 0.24, 0.14)), ((0.50, 0.76, 0.44), (0.32, 0.58, 0.34))),
    "amber": (((0.96, 0.74, 0.34), (0.78, 0.46, 0.18)), ((0.52, 0.37, 0.25), (0.36, 0.24, 0.15)), ((0.92, 0.66, 0.28), (0.76, 0.44, 0.18))),
    "moor":  (((0.72, 0.80, 0.46), (0.42, 0.56, 0.30)), ((0.58, 0.46, 0.34), (0.40, 0.30, 0.20)), ((0.64, 0.74, 0.40), (0.44, 0.56, 0.30))),
}

# Geometry the game reads back (published in STATS and copied ONCE into
# HubTrees as the family's contract; a probe re-measures the GLB).
TRUNK_H = 3.3
TRUNK_R_BASE = 0.30
TRUNK_R_TOP = 0.21
RING_R = 0.98          # distance of lobe centres from the axis
LOBE_R = 0.66
RING_Y = 3.32
PAD_R = 0.95
PAD_Y = 3.02
PAD_SQUASH = 0.42      # pad top = PAD_Y + PAD_R * PAD_SQUASH = 3.42

def ringed_trunk(height, r_base, r_top, segs=10, seed=0):
    """The bare trunk, with a slight lean and a wobble per ring so it is
    not a lathe; the bark rings are painted, not modelled."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = 6
    prev = None
    bend = rnd.uniform(-0.05, 0.05)
    for k in range(rings + 1):
        t = k / rings
        y = height * t
        r = r_base * (1.0 - t) + r_top * t
        if k == 0:
            r = r_base * 1.35
        ox = bend * (t ** 2) * height
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            wob = 1.0 + 0.05 * math.sin(a * 3 + k * 1.1 + seed)
            ring.append(bm.verts.new((math.cos(a) * r * wob + ox, y, math.sin(a) * r * wob)))
        if prev:
            for i in range(segs):
                bm.faces.new((prev[i], prev[(i + 1) % segs], ring[(i + 1) % segs], ring[i]))
        prev = ring
    bm.faces.new(tuple(reversed(prev)))
    # two stub branches under the wreath: the silhouette's "hands"
    for side in (0, 1):
        a = rnd.uniform(0, 2 * math.pi)
        y0 = height * rnd.uniform(0.70, 0.82)
        L = rnd.uniform(0.55, 0.75)
        d = Vector((math.cos(a), 0.55, math.sin(a))).normalized()
        base = Vector((0.0, y0, 0.0))
        tip = base + d * L
        rr = 0.09
        # orthonormal frame round d
        u = d.cross(Vector((0, 1, 0))).normalized()
        w = d.cross(u).normalized()
        b0 = [bm.verts.new(tuple(base + (u * math.cos(2 * math.pi * i / 5) + w * math.sin(2 * math.pi * i / 5)) * rr)) for i in range(5)]
        b1 = [bm.verts.new(tuple(tip + (u * math.cos(2 * math.pi * i / 5) + w * math.sin(2 * math.pi * i / 5)) * rr * 0.55)) for i in range(5)]
        for i in range(5):
            bm.faces.new((b0[i], b0[(i + 1) % 5], b1[(i + 1) % 5], b1[i]))
        bm.faces.new(tuple(reversed(b1)))
    return bm

def make_climb_tree(seed, palette):
    rnd = random.Random(seed)
    (ctop, cbot), (tl, td), (ptop, pbot) = PALETTES[palette]
    trunk = ringed_trunk(TRUNK_H, TRUNK_R_BASE, TRUNK_R_TOP, seed=seed)
    lobes = []
    n = 7
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-0.12, 0.12)
        r = RING_R * rnd.uniform(0.94, 1.06)
        y = RING_Y + rnd.uniform(-0.12, 0.12)
        lr = LOBE_R * rnd.uniform(0.9, 1.1)
        lobes.append(blob_bm(lr, 2, (1.0, 0.86, 1.0), 0.09, seed + i, (math.cos(a) * r, y, math.sin(a) * r)))
    # the pad: a flat leaf cushion filling the ring's centre (the seat)
    pad = blob_bm(PAD_R, 2, (1.0, PAD_SQUASH, 1.0), 0.05, seed + 40, (0.0, PAD_Y, 0.0))
    tr = new_obj("Trunk", trunk)
    can = new_obj("Canopy", join(lobes))
    pd = new_obj("Pad", pad)
    def paint_trunk(co, nrm):
        t = clamp01(co.y / TRUNK_H)
        c = lerp(td, tl, 0.3 + 0.7 * t)
        # bark rings: a slightly lighter band every 0.55 u, the ladder cue
        band = 0.5 + 0.5 * math.cos(co.y / 0.55 * 2 * math.pi)
        f = 1.0 + 0.10 * (band ** 3) + 0.06 * (nrm.x + 0.3 * nrm.z)
        return tuple(clamp01(v * f) for v in c)
    paint(tr, paint_trunk)
    top = RING_Y + LOBE_R + 0.12
    bot = RING_Y - LOBE_R
    def paint_canopy(co, nrm):
        t = clamp01((co.y - bot) / max(0.01, top - bot)) ** 0.8
        c = lerp(cbot, ctop, t)
        f = 1.0 + 0.05 * nrm.y + 0.03 * nrm.x
        return tuple(clamp01(v * f) for v in c)
    paint(can, paint_canopy)
    ptop_y = PAD_Y + PAD_R * PAD_SQUASH
    def paint_pad(co, nrm):
        t = clamp01((co.y - (PAD_Y - PAD_R * PAD_SQUASH)) / max(0.01, 2 * PAD_R * PAD_SQUASH))
        c = lerp(pbot, ptop, t)
        return tuple(clamp01(v * (1.0 + 0.04 * nrm.y)) for v in c)
    paint(pd, paint_pad)
    for o in (tr, can, pd):
        for p in o.data.polygons:
            p.use_smooth = (o is not tr)
    return tr, can, pd, {"trunk_h": TRUNK_H, "trunk_r_base": TRUNK_R_BASE, "trunk_r_top": TRUNK_R_TOP,
                         "seat_y": round(ptop_y, 3), "ring_top": round(RING_Y + LOBE_R, 3), "ring_r": RING_R + LOBE_R}

def acorn_bm(seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # body: ellipsoid, pointed underneath
    body = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.11)
    for v in bm.verts:
        n = v.co.normalized()
        y = n.y
        r_xz = 1.0 - 0.18 * max(0.0, -y)
        v.co = Vector((n.x * 0.11 * r_xz, n.y * 0.135 + 0.13, n.z * 0.11 * r_xz))
    body_verts = list(bm.verts)
    # cap: a squashed sphere top, slightly wider than the body
    cap = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.125)
    for v in cap["verts"]:
        n = v.co.normalized()
        v.co = Vector((n.x * 0.125, max(n.y, -0.15) * 0.075 + 0.225, n.z * 0.125))
    # stalk
    stalk = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.02, radius2=0.012, depth=0.06)
    for v in stalk["verts"]:
        v.co = Vector((v.co.x, v.co.z + 0.315, v.co.y))
    return bm

def hazelnut_bm(seed=0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.13)
    for v in bm.verts:
        n = v.co.normalized()
        # flatter base, slightly pointed top
        y = n.y * 0.13 * (1.08 if n.y > 0 else 0.92) + 0.135
        v.co = Vector((n.x * 0.13, y, n.z * 0.13))
    return bm

def paint_acorn(ob):
    def f(co, nrm):
        if co.y > 0.205:
            c = (0.46, 0.29, 0.15) if co.y < 0.30 else (0.40, 0.25, 0.13)
            return tuple(clamp01(v * (1.0 + 0.10 * nrm.y)) for v in c)
        c = lerp((0.70, 0.46, 0.22), (0.86, 0.64, 0.34), clamp01(co.y / 0.2))
        return tuple(clamp01(v * (1.0 + 0.08 * nrm.x + 0.06 * nrm.y)) for v in c)
    paint(ob, f)

def paint_hazelnut(ob):
    def f(co, nrm):
        if co.y < 0.06:
            return (0.88, 0.78, 0.60)
        c = lerp((0.52, 0.32, 0.16), (0.72, 0.48, 0.24), clamp01((co.y - 0.06) / 0.2))
        return tuple(clamp01(v * (1.0 + 0.08 * nrm.x + 0.06 * nrm.y)) for v in c)
    paint(ob, f)

if __name__ == "__main__":
    reset()
    mat = flat_material()
    sheet = []
    stats = {}
    specs = [(301, "lime"), (317, "jade"), (331, "lime"), (347, "amber"), (359, "moor")]
    for i, (seed, pal) in enumerate(specs):
        tr, can, pd, geo = make_climb_tree(seed, pal)
        for o in (tr, can, pd):
            o.data.materials.append(mat)
        bpy.ops.object.select_all(action='DESELECT')
        tr.select_set(True); can.select_set(True); pd.select_set(True)
        bpy.context.view_layer.objects.active = tr
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = f"climbtree_{i}"
        stand(ob)
        path = os.path.join(OUT, f"climbtree_{i}.glb")
        export_glb([ob], path)
        tris = post_unlit(path)
        geo.update({"tris": tris, "bytes": os.path.getsize(path), "palette": pal})
        stats[ob.name] = geo
        sheet.append(ob)
    for name, builder, painter in (("acorn_0", acorn_bm, paint_acorn), ("hazelnut_0", hazelnut_bm, paint_hazelnut)):
        ob = new_obj(name, builder())
        for p in ob.data.polygons:
            p.use_smooth = True
        painter(ob)
        ob.data.materials.append(mat)
        stand(ob)
        path = os.path.join(OUT, f"{name}.glb")
        export_glb([ob], path)
        tris = post_unlit(path)
        stats[name] = {"tris": tris, "bytes": os.path.getsize(path)}
        big = ob.copy(); big.data = ob.data.copy(); big.scale = (5, 5, 5)
        bpy.context.scene.collection.objects.link(big)
        sheet.append(big)
        ob.location = (0, 0, -50)
    render_sheet(sheet, os.path.join(OUT, "climbtree_sheet.png"), spacing=3.6, res=(2400, 700), elev_deg=20)
    print("STATS", json.dumps(stats))
