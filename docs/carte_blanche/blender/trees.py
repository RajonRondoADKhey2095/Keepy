"""Tree family: round 'cloud' canopies on tapered trunks, AC-like.
Variants: 0-2 near trees (puffy, ~350 tri), 3 tall tree, 4 conifer (rounded tiers),
5 far-LOD blob (~100 tri) for the forest wall."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
def clamp01(x): return max(0.0, min(1.0, x))

def trunk_bm(height, r_base, r_top, segs=8, bend=0.12, seed=0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    rings = 4
    prev = None
    for k in range(rings + 1):
        t = k / rings
        y = height * t
        r = r_base * (1.0 - t) + r_top * t
        if k == 0:
            r = r_base * 1.25  # flared foot
        ox = bend * (t ** 2) * height
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            wob = 1.0 + 0.06 * math.sin(a * 3 + k * 1.3 + seed)
            ring.append(bm.verts.new((math.cos(a) * r * wob + ox, y, math.sin(a) * r * wob)))
        if prev:
            for i in range(segs):
                bm.faces.new((prev[i], prev[(i + 1) % segs], ring[(i + 1) % segs], ring[i]))
        prev = ring
    bm.faces.new(tuple(reversed(prev)))  # top cap
    return bm

def blob_bm(radius, subdiv=2, squash=(1.0, 0.85, 1.0), noise=0.10, seed=0, center=(0, 0, 0)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    # lumpy: low-frequency displacement along the normal
    phase = [rnd.uniform(0, 6.28) for _ in range(3)]
    for v in bm.verts:
        n = v.co.normalized()
        d = 1.0 + noise * (math.sin(n.x * 2.3 + phase[0]) * math.cos(n.y * 1.7 + phase[1]) + 0.6 * math.sin(n.z * 3.1 + phase[2]))
        v.co = Vector((n.x * radius * squash[0] * d, n.y * radius * squash[1] * d, n.z * radius * squash[2] * d)) + Vector(center)
    return bm

def join(bms):
    out = bmesh.new()
    for bm in bms:
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me); bm.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    return out

PALETTE = {
    # canopy (top, bottom), trunk (light, dark) -- sRGB
    "spring": (((0.58, 0.82, 0.36), (0.30, 0.56, 0.24)), ((0.55, 0.40, 0.27), (0.38, 0.26, 0.17))),
    "summer": (((0.45, 0.74, 0.33), (0.22, 0.48, 0.24)), ((0.52, 0.37, 0.25), (0.36, 0.24, 0.15))),
    "lime":   (((0.72, 0.86, 0.38), (0.40, 0.62, 0.26)), ((0.58, 0.44, 0.30), (0.40, 0.28, 0.18))),
    "teal":   (((0.50, 0.78, 0.52), (0.28, 0.56, 0.38)), ((0.50, 0.36, 0.26), (0.34, 0.23, 0.15))),
    "amber":  (((0.94, 0.72, 0.32), (0.74, 0.44, 0.18)), ((0.52, 0.37, 0.25), (0.36, 0.24, 0.15))),
}

def make_tree(kind, seed, palette):
    rnd = random.Random(seed)
    (ctop, cbot), (tl, td) = PALETTE[palette]
    if kind == "round":
        h = rnd.uniform(1.5, 1.9); rb = rnd.uniform(0.20, 0.26)
        trunk = trunk_bm(h, rb, rb * 0.7, bend=rnd.uniform(-0.15, 0.15), seed=seed)
        R = rnd.uniform(1.15, 1.45)
        cy = h + R * 0.55
        blobs = [blob_bm(R, 2, (1.0, 0.82, 1.0), 0.10, seed, (0, cy, 0))]
        for k in range(rnd.randint(2, 3)):
            a = rnd.uniform(0, 6.28); rr = R * rnd.uniform(0.45, 0.6)
            blobs.append(blob_bm(rr, 1, (1.0, 0.9, 1.0), 0.12, seed + k + 1,
                                 (math.cos(a) * R * 0.7, cy + rnd.uniform(-0.2, 0.45), math.sin(a) * R * 0.7)))
        top = cy + R; bot_c = cy - R * 0.82
    elif kind == "hi":
        h = rnd.uniform(1.5, 1.9); rb = rnd.uniform(0.20, 0.26)
        trunk = trunk_bm(h, rb, rb * 0.7, bend=rnd.uniform(-0.15, 0.15), seed=seed)
        R = rnd.uniform(1.15, 1.45)
        cy = h + R * 0.55
        blobs = [blob_bm(R, 3, (1.0, 0.82, 1.0), 0.09, seed, (0, cy, 0))]
        for k in range(rnd.randint(2, 3)):
            a = rnd.uniform(0, 6.28); rr = R * rnd.uniform(0.45, 0.6)
            blobs.append(blob_bm(rr, 2, (1.0, 0.9, 1.0), 0.10, seed + k + 1,
                                 (math.cos(a) * R * 0.7, cy + rnd.uniform(-0.2, 0.45), math.sin(a) * R * 0.7)))
        top = cy + R; bot_c = cy - R * 0.82
    elif kind == "tall":
        h = rnd.uniform(2.6, 3.2); rb = rnd.uniform(0.22, 0.28)
        trunk = trunk_bm(h, rb, rb * 0.6, bend=rnd.uniform(-0.1, 0.1), seed=seed)
        R = rnd.uniform(1.0, 1.2)
        cy = h + R * 0.5
        blobs = [blob_bm(R, 2, (1.0, 1.15, 1.0), 0.09, seed, (0, cy, 0)),
                 blob_bm(R * 0.7, 1, (1.0, 0.9, 1.0), 0.1, seed + 7, (R * 0.5, cy - R * 0.3, 0.2)),
                 blob_bm(R * 0.6, 1, (1.0, 0.9, 1.0), 0.1, seed + 9, (-R * 0.45, cy + R * 0.2, -0.3))]
        top = cy + R * 1.15; bot_c = cy - R
    elif kind == "conifer":
        h = rnd.uniform(0.8, 1.1); rb = 0.2
        trunk = trunk_bm(h, rb, rb * 0.8, bend=0.0, seed=seed)
        blobs = []
        tiers = [(1.35, h + 0.9), (1.05, h + 2.0), (0.7, h + 2.95), (0.38, h + 3.6)]
        for i, (r, y) in enumerate(tiers):
            blobs.append(blob_bm(r, 2, (1.0, 0.72, 1.0), 0.07, seed + i, (0, y, 0)))
        top = h + 3.95; bot_c = h + 0.3
    elif kind == "far":
        h = rnd.uniform(1.6, 2.0); rb = 0.22
        trunk = trunk_bm(h, rb, rb * 0.7, segs=6, bend=0.0, seed=seed)
        R = rnd.uniform(1.25, 1.5)
        cy = h + R * 0.55
        blobs = [blob_bm(R, 1, (1.0, 0.85, 1.0), 0.12, seed, (0, cy, 0))]
        top = cy + R; bot_c = cy - R * 0.85
    trunk_top = h
    tr = new_obj("Trunk", trunk)
    can = new_obj("Canopy", join(blobs))
    # trunk: darker at the foot, lighter up, slight facet variation
    def paint_trunk(co, n):
        t = clamp01(co.y / trunk_top)
        c = lerp(td, tl, 0.35 + 0.65 * t)
        f = 1.0 + 0.07 * (n.x + 0.3 * n.z)
        return tuple(clamp01(v * f) for v in c)
    paint(tr, paint_trunk)
    def paint_canopy(co, n):
        t = clamp01((co.y - bot_c) / max(0.01, top - bot_c))
        t = t ** 0.8
        c = lerp(cbot, ctop, t)
        # a touch of warm on the +x/+y facing side, cool on the underside
        f = 1.0 + 0.05 * n.y + 0.03 * n.x
        return tuple(clamp01(v * f) for v in c)
    paint(can, paint_canopy)
    for o in (tr, can):
        for p in o.data.polygons:
            p.use_smooth = (o is can)
    return tr, can, top

if __name__ == "__main__":
    reset()
    mat = flat_material()
    specs = [("round", 11, "spring"), ("round", 23, "summer"), ("round", 37, "lime"),
             ("tall", 41, "summer"), ("conifer", 5, "teal"), ("round", 61, "amber"), ("far", 7, "summer"),
             ("hi", 111, "spring"), ("hi", 123, "summer"), ("hi", 137, "lime"), ("hi", 161, "amber")]
    sheet = []
    stats = {}
    for i, (kind, seed, pal) in enumerate(specs):
        tr, can, top = make_tree(kind, seed, pal)
        for o in (tr, can):
            o.data.materials.append(mat)
        # join into one object for a single primitive
        bpy.ops.object.select_all(action='DESELECT')
        tr.select_set(True); can.select_set(True)
        bpy.context.view_layer.objects.active = tr
        bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = f"tree_{kind}_{i}"
        stand(ob)
        path = os.path.join(OUT, f"tree_{i}_{kind}.glb")
        export_glb([ob], path)
        tris = post_unlit(path)
        stats[ob.name] = {"tris": tris, "height": round(top, 3), "bytes": os.path.getsize(path)}
        sheet.append(ob)
    render_sheet(sheet, os.path.join(OUT, "trees_sheet.png"), spacing=3.4, res=(2000, 600), elev_deg=18)
    print("STATS", json.dumps(stats))
