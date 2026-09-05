"""Autumn family (carte blanche v2, second map 'le Vallon d'automne').
Autumn trees (orange / red / gold), a far LOD, the giant Mother Tree, ferns,
giant mushrooms, pumpkins, a hollow log, leaf piles and a lantern post.
Same contract as the v1 families: vertex colours, one flat unlit material."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from trees import lerp, clamp01, join, blob_bm, trunk_bm

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

AUTUMN = {
    "orange": ((0.96, 0.58, 0.22), (0.76, 0.34, 0.12)),
    "red":    ((0.90, 0.36, 0.22), (0.62, 0.18, 0.12)),
    "gold":   ((0.98, 0.80, 0.30), (0.82, 0.54, 0.16)),
    "rust":   ((0.86, 0.46, 0.20), (0.60, 0.26, 0.10)),
}
TRUNK = ((0.48, 0.34, 0.24), (0.32, 0.22, 0.14))

def smooth(ob, on=True):
    for p in ob.data.polygons:
        p.use_smooth = on

def paint_tree(tr, can, trunk_top, bot_c, top, pal):
    (ctop, cbot) = AUTUMN[pal]
    tl, td = TRUNK
    def pt(co, n):
        t = clamp01(co.y / trunk_top)
        c = lerp(td, tl, 0.35 + 0.65 * t)
        f = 1.0 + 0.07 * (n.x + 0.3 * n.z)
        return tuple(clamp01(v * f) for v in c)
    paint(tr, pt)
    def pc(co, n):
        t = clamp01((co.y - bot_c) / max(0.01, top - bot_c)) ** 0.8
        c = lerp(cbot, ctop, t)
        f = 1.0 + 0.06 * n.y + 0.03 * n.x
        return tuple(clamp01(v * f) for v in c)
    paint(can, pc)

def autumn_tree(kind, seed, pal):
    rnd = random.Random(seed)
    if kind == "round":
        h = rnd.uniform(1.6, 2.0); rb = rnd.uniform(0.20, 0.26)
        trunk = trunk_bm(h, rb, rb * 0.7, bend=rnd.uniform(-0.15, 0.15), seed=seed)
        R = rnd.uniform(1.15, 1.45); cy = h + R * 0.55
        blobs = [blob_bm(R, 2, (1.0, 0.86, 1.0), 0.11, seed, (0, cy, 0))]
        for k in range(rnd.randint(2, 3)):
            a = rnd.uniform(0, 6.28); rr = R * rnd.uniform(0.45, 0.6)
            blobs.append(blob_bm(rr, 1, (1.0, 0.9, 1.0), 0.12, seed + k + 1,
                                 (math.cos(a) * R * 0.7, cy + rnd.uniform(-0.2, 0.45), math.sin(a) * R * 0.7)))
        top = cy + R; bot_c = cy - R * 0.82
    elif kind == "tall":
        h = rnd.uniform(2.8, 3.4); rb = rnd.uniform(0.22, 0.28)
        trunk = trunk_bm(h, rb, rb * 0.6, bend=rnd.uniform(-0.1, 0.1), seed=seed)
        R = rnd.uniform(1.0, 1.2); cy = h + R * 0.5
        blobs = [blob_bm(R, 2, (1.0, 1.2, 1.0), 0.09, seed, (0, cy, 0)),
                 blob_bm(R * 0.7, 1, (1.0, 0.9, 1.0), 0.1, seed + 7, (R * 0.5, cy - R * 0.3, 0.2)),
                 blob_bm(R * 0.6, 1, (1.0, 0.9, 1.0), 0.1, seed + 9, (-R * 0.45, cy + R * 0.2, -0.3))]
        top = cy + R * 1.2; bot_c = cy - R
    elif kind == "far":
        h = rnd.uniform(1.6, 2.0); rb = 0.22
        trunk = trunk_bm(h, rb, rb * 0.7, segs=6, bend=0.0, seed=seed)
        R = rnd.uniform(1.25, 1.5); cy = h + R * 0.55
        blobs = [blob_bm(R, 1, (1.0, 0.85, 1.0), 0.12, seed, (0, cy, 0))]
        top = cy + R; bot_c = cy - R * 0.85
    tr = new_obj("Trunk", trunk); can = new_obj("Canopy", join(blobs))
    paint_tree(tr, can, h, bot_c, top, pal)
    smooth(tr, False); smooth(can, True)
    return tr, can, top

def mother_tree(seed=777):
    """The landmark: ~18 u tall, canopy ~14 u wide, root flares, four lobes."""
    rnd = random.Random(seed)
    h = 7.5; rb = 1.7
    trunk = trunk_bm(h, rb, rb * 0.55, segs=14, bend=0.05, seed=seed)
    # root flares: five squashed blobs around the foot
    roots = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-0.2, 0.2)
        roots.append(blob_bm(1.05, 1, (1.6, 0.55, 0.9), 0.12, seed + k, (math.cos(a) * 1.9, 0.25, math.sin(a) * 1.9)))
    R = 6.6; cy = h + R * 0.62
    blobs = [blob_bm(R, 3, (1.0, 0.78, 1.0), 0.08, seed, (0, cy, 0))]
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4; rr = R * rnd.uniform(0.48, 0.58)
        blobs.append(blob_bm(rr, 2, (1.0, 0.86, 1.0), 0.10, seed + 11 + k,
                             (math.cos(a) * R * 0.72, cy + rnd.uniform(-1.2, 1.6), math.sin(a) * R * 0.72)))
    blobs.append(blob_bm(R * 0.5, 2, (1.0, 0.9, 1.0), 0.1, seed + 99, (0, cy + R * 0.75, 0)))
    top = cy + R * 1.05; bot_c = cy - R * 0.85
    tr = new_obj("Trunk", join([trunk] + roots)); can = new_obj("Canopy", join(blobs))
    paint_tree(tr, can, h, bot_c, top, "orange")
    smooth(tr, False); smooth(can, True)
    return tr, can, top

def fern(seed, fronds=7):
    rnd = random.Random(seed)
    bm = bmesh.new()
    for b in range(fronds):
        a = 2 * math.pi * b / fronds + rnd.uniform(-0.25, 0.25)
        L = rnd.uniform(0.55, 0.8); w = rnd.uniform(0.10, 0.15)
        dx, dz = math.cos(a), math.sin(a); px, pz = -dz, dx
        prev = None
        for k, (t, ww, lift) in enumerate([(0.0, 0.25, 0.0), (0.35, 1.0, 0.30), (0.7, 0.8, 0.42), (1.0, 0.0, 0.34)]):
            c = Vector((dx * L * t, lift * L * 1.2 + 0.03, dz * L * t))
            if ww > 0:
                pair = (bm.verts.new(c + Vector((px * w * ww, 0, pz * w * ww))), bm.verts.new(c - Vector((px * w * ww, 0, pz * w * ww))))
            else:
                tip = bm.verts.new(c); pair = (tip, tip)
            if prev:
                if pair[0] is pair[1]:
                    bm.faces.new((prev[0], prev[1], pair[0]))
                else:
                    bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
            prev = pair
    ob = new_obj("Fern", bm); smooth(ob, True)
    top = (0.74, 0.78, 0.30); bot = (0.36, 0.50, 0.20)
    paint(ob, lambda co, n: lerp(bot, top, clamp01(math.hypot(co.x, co.z) / 0.7)))
    return ob

def big_mushroom(seed, cap=(0.88, 0.30, 0.22), spots=True):
    rnd = random.Random(seed)
    bm = bmesh.new()
    h = rnd.uniform(1.5, 2.3); rs = rnd.uniform(0.22, 0.30); rc = rnd.uniform(0.9, 1.3)
    segs = 12
    rings = []
    prof = [(0, rs * 1.3), (h * 0.35, rs * 0.95), (h * 0.72, rs), (h * 0.74, rc * 0.55), (h * 0.80, rc * 0.92), (h * 0.92, rc), (h * 1.05, rc * 0.78), (h * 1.16, rc * 0.4)]
    for (y, r) in prof:
        rings.append([bm.verts.new((math.cos(2 * math.pi * i / segs) * r * (1 + 0.04 * math.sin(i * 2.1 + seed)), y, math.sin(2 * math.pi * i / segs) * r)) for i in range(segs)])
    for k in range(len(rings) - 1):
        for i in range(segs):
            bm.faces.new((rings[k][i], rings[k][(i + 1) % segs], rings[k + 1][(i + 1) % segs], rings[k + 1][i]))
    top = bm.verts.new((0, h * 1.22, 0))
    for i in range(segs):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % segs], top))
    bm.faces.new(tuple(reversed(rings[0])))
    ob = new_obj("BigShroom", bm); smooth(ob, True)
    stem_c = (0.94, 0.88, 0.72); gill = (0.96, 0.90, 0.74)
    spot_seed = random.Random(seed + 5)
    spot_pts = [(spot_seed.uniform(0, 6.28), spot_seed.uniform(0.35, 0.9)) for _ in range(6)]
    def pm(co, n):
        if co.y < h * 0.73:
            return tuple(clamp01(v * (0.9 + 0.1 * clamp01(co.y / h))) for v in stem_c)
        if n.y < -0.15:
            return gill
        t = clamp01((co.y - h * 0.74) / (h * 0.5))
        c = lerp(tuple(v * 0.78 for v in cap), cap, t)
        if spots:
            a = math.atan2(co.z, co.x); r = math.hypot(co.x, co.z) / rc
            for (sa, sr) in spot_pts:
                if abs(((a - sa + math.pi) % (2 * math.pi)) - math.pi) < 0.17 and abs(r - sr) < 0.10:
                    return (0.98, 0.95, 0.86)
        return c
    paint(ob, pm)
    return ob

def pumpkin(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.32)
    for v in bm.verts:
        a = math.atan2(v.co.y, v.co.x)
        rib = 1.0 + 0.07 * math.cos(a * 8)
        v.co = Vector((v.co.x * rib, v.co.y * rib, v.co.z * 0.78 * (1.0 + 0.07 * math.cos(a * 8)) + 0.26))
    # blender Z is up here before stand(): we author Y-up, so swap: build in Y-up directly
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.z, v.co.y))
    stem = bmesh.new()
    prev = None
    for k in range(3):
        y = 0.50 + 0.06 * k; r = 0.05 - 0.01 * k
        ring = [stem.verts.new((math.cos(2 * math.pi * i / 5) * r + 0.03 * k, y, math.sin(2 * math.pi * i / 5) * r)) for i in range(5)]
        if prev:
            for i in range(5):
                stem.faces.new((prev[i], prev[(i + 1) % 5], ring[(i + 1) % 5], ring[i]))
        prev = ring
    stem.faces.new(tuple(reversed(prev)))
    ob = new_obj("Pumpkin", join([bm, stem])); smooth(ob, True)
    body = (0.96, 0.52, 0.16); crease = (0.78, 0.36, 0.10); st = (0.46, 0.56, 0.26)
    def pp(co, n):
        if co.y > 0.49 and math.hypot(co.x, co.z) < 0.09:
            return st
        a = math.atan2(co.z, co.x)
        return lerp(crease, body, clamp01(0.5 + 0.5 * math.cos(a * 8)) ** 0.6)
    paint(ob, pp)
    return ob

def hollow_log(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    L = rnd.uniform(2.2, 2.8); R = 0.42; segs = 10
    outer = []; inner = []
    for k in range(4):
        x = -L / 2 + L * k / 3
        wob = 1.0 + 0.05 * math.sin(k * 2.0 + seed)
        outer.append([bm.verts.new((x, R * wob * (1 + 0.05 * math.cos(i * 1.7)) * math.sin(2 * math.pi * i / segs) + R * 0.9, R * wob * math.cos(2 * math.pi * i / segs))) for i in range(segs)])
        inner.append([bm.verts.new((x, R * 0.68 * math.sin(2 * math.pi * i / segs) + R * 0.9, R * 0.68 * math.cos(2 * math.pi * i / segs))) for i in range(segs)])
    for k in range(3):
        for i in range(segs):
            bm.faces.new((outer[k][i], outer[k][(i + 1) % segs], outer[k + 1][(i + 1) % segs], outer[k + 1][i]))
            bm.faces.new((inner[k + 1][i], inner[k + 1][(i + 1) % segs], inner[k][(i + 1) % segs], inner[k][i]))
    for end, flip in ((0, True), (3, False)):
        for i in range(segs):
            q = (outer[end][i], outer[end][(i + 1) % segs], inner[end][(i + 1) % segs], inner[end][i])
            bm.faces.new(q if flip else tuple(reversed(q)))
    ob = new_obj("Log", bm); smooth(ob, True)
    bark = (0.44, 0.30, 0.20); bark2 = (0.34, 0.22, 0.14); wood = (0.72, 0.56, 0.34); moss = (0.52, 0.62, 0.30)
    def pl(co, n):
        r = math.hypot(co.y - R * 0.9, co.z)
        if r < R * 0.75:
            return wood
        if abs(abs(co.x) - L / 2) < 0.02:
            return wood
        if n.y > 0.75:
            return moss
        return lerp(bark2, bark, clamp01(0.5 + 0.5 * n.y))
    paint(ob, pl)
    return ob

def leaf_pile(seed):
    rnd = random.Random(seed)
    # Nearly flat, SMOOTH-shaded and low-noise: a faceted lumpy disc under
    # the toon shader reads as a boulder (measured on the first hollow
    # capture), a smooth one reads as a drift of leaves.
    bm = blob_bm(0.7, 2, (1.5, 0.09, 1.15), 0.06, seed, (0, 0.0, 0))
    for v in bm.verts:
        if v.co.y < 0.0:
            v.co.y = 0.0
    ob = new_obj("LeafPile", bm); smooth(ob, True)
    edge = (0.62, 0.34, 0.16); mid = (0.84, 0.54, 0.24); light = (0.92, 0.70, 0.32)
    def pp(co, n):
        r = clamp01(math.hypot(co.x / 1.05, co.z / 0.8))
        c = lerp(light, mid, clamp01(r * 1.4))
        c = lerp(c, edge, clamp01((r - 0.7) * 3.3))
        f = 1.0 + 0.05 * math.sin(co.x * 9.0 + co.z * 11.0)
        return tuple(clamp01(v * f) for v in c)
    paint(ob, pp)
    return ob

def lantern(seed):
    bm = bmesh.new()
    def box(cx, cy, cz, sx, sy, sz):
        vs = [bm.verts.new((cx + sx * ((i & 1) * 2 - 1), cy + sy * (((i >> 1) & 1) * 2 - 1), cz + sz * (((i >> 2) & 1) * 2 - 1))) for i in range(8)]
        for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            bm.faces.new(tuple(vs[i] for i in f))
        return vs
    box(0, 0.9, 0, 0.06, 0.9, 0.06)            # post
    box(0.16, 1.72, 0, 0.22, 0.03, 0.05)       # arm
    box(0.32, 1.50, 0, 0.11, 0.16, 0.11)       # lamp body (warm)
    box(0.32, 1.68, 0, 0.14, 0.03, 0.14)       # cap
    ob = new_obj("Lantern", bm); smooth(ob, False)
    wood = (0.40, 0.28, 0.18); warm = (1.0, 0.86, 0.46); cap = (0.30, 0.22, 0.16)
    def pl(co, n):
        if 1.34 < co.y < 1.66 and co.x > 0.2:
            return warm
        if co.y > 1.64 and co.x > 0.15:
            return cap
        return wood
    paint(ob, pl)
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    sheet = []; stats = {}
    def finish(obs, name):
        for o in obs:
            o.data.materials.append(mat)
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        stand(ob)
        path = os.path.join(OUT, name + ".glb")
        export_glb([ob], path)
        tris = post_unlit(path)
        stats[name] = {"tris": tris, "bytes": os.path.getsize(path)}
        sheet.append(ob)
    for i, (kind, seed, pal) in enumerate([("round", 301, "orange"), ("round", 313, "red"), ("round", 327, "gold"), ("tall", 341, "rust"), ("far", 357, "orange"), ("far", 359, "red")]):
        tr, can, top = autumn_tree(kind, seed, pal)
        finish([tr, can], "autumn_tree_%d" % i)
        stats["autumn_tree_%d" % i]["height"] = round(top, 3)
    tr, can, top = mother_tree()
    finish([tr, can], "mother_tree"); stats["mother_tree"]["height"] = round(top, 3)
    for i in range(2):
        finish([fern(401 + i)], "fern_%d" % i)
    finish([big_mushroom(501)], "bigshroom_0")
    finish([big_mushroom(517, cap=(0.80, 0.56, 0.30), spots=False)], "bigshroom_1")
    for i in range(2):
        finish([pumpkin(601 + i)], "pumpkin_%d" % i)
    finish([hollow_log(701)], "log_0")
    for i in range(2):
        finish([leaf_pile(801 + i)], "leafpile_%d" % i)
    finish([lantern(901)], "lantern_0")
    render_sheet(sheet, os.path.join(OUT, "autumn_sheet.png"), spacing=4.2, res=(2400, 700), elev_deg=16)
    print("STATS", json.dumps(stats))
