"""Transport family (carte-blanche v3): hot-air balloons, their docks, and
the hoppity ball ("Sautillon").

Balloon GLB origin = basket FLOOR centre (Keepy stands at y ~0.05 inside
the basket). Dock GLB origin = ground under the deck centre. Sign GLB origin
= foot of the post, arrow points +Z (rotated in Godot toward the twin dock).
Ball GLB origin = ground contact (bottom of the sphere), face toward +Z.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

def clamp01(x): return max(0.0, min(1.0, x))
def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def add_cyl(bm, cx, y0, y1, cz, r0, r1, segs=8, cap=True):
    """Vertical tapered cylinder, y from y0 to y1."""
    rings = []
    for y, r in ((y0, r0), (y1, r1)):
        ring = [bm.verts.new((cx + math.cos(2 * math.pi * i / segs) * r, y, cz + math.sin(2 * math.pi * i / segs) * r)) for i in range(segs)]
        rings.append(ring)
    a, b = rings
    for i in range(segs):
        bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    if cap:
        bm.faces.new(tuple(reversed(b)))
        bm.faces.new(tuple(a))
    return bm

def add_box(bm, cx, cy, cz, sx, sy, sz, top_scale=1.0):
    h = [sx / 2, sy / 2, sz / 2]
    ts = top_scale
    v = [bm.verts.new((cx + x * h[0] * (ts if y > 0 else 1.0), cy + y * h[1], cz + z * h[2] * (ts if y > 0 else 1.0)))
         for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    # index: x*4 + y*2 + z  (0..7)
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for q in f:
        bm.faces.new(tuple(v[i] for i in q))
    return bm

def seg_between(bm, a, b, r=0.03, segs=4):
    """Thin rope/rod from point a to point b."""
    a = Vector(a); b = Vector(b)
    d = (b - a)
    L = d.length
    if L < 1e-6:
        return
    z = d.normalized()
    x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    x = (x - z * x.dot(z)).normalized()
    y = z.cross(x)
    ra = [bm.verts.new(a + (x * math.cos(2 * math.pi * i / segs) + y * math.sin(2 * math.pi * i / segs)) * r) for i in range(segs)]
    rb = [bm.verts.new(b + (x * math.cos(2 * math.pi * i / segs) + y * math.sin(2 * math.pi * i / segs)) * r) for i in range(segs)]
    for i in range(segs):
        bm.faces.new((ra[i], ra[(i + 1) % segs], rb[(i + 1) % segs], rb[i]))

def recalc(bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# ---------------------------------------------------------------- balloon
def balloon(seed, main, cream, gores=8):
    """Envelope (teardrop, striped gores), skirt, ropes, wicker basket."""
    bm = bmesh.new()
    R = 1.75
    CY = 4.2   # envelope centre height above basket floor
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        n = v.co.copy()
        y = n.y
        # teardrop: full width at the equator, pinched toward the bottom
        pinch = 1.0 if y >= 0 else (1.0 + y * 0.72)
        squash = 1.08 if y >= 0 else 1.25
        v.co = Vector((n.x * R * pinch, CY + n.y * R * squash, n.z * R * pinch))
    env_faces = list(bm.faces)
    for f in env_faces:
        f.smooth = False
    # skirt ring (open mouth) under the envelope
    add_cyl(bm, 0.0, CY - R * 1.25 - 0.05, CY - R * 1.25 + 0.30, 0.0, 0.42, 0.62, segs=10, cap=False)
    # basket
    add_box(bm, 0.0, 0.32, 0.0, 0.95, 0.64, 0.95, top_scale=1.08)
    # rim
    add_box(bm, 0.0, 0.66, 0.0, 1.06, 0.07, 1.06)
    # ropes from basket corners up to the skirt
    for sx in (-1, 1):
        for sz in (-1, 1):
            seg_between(bm, (sx * 0.46, 0.68, sz * 0.46), (sx * 0.34, CY - R * 1.25 - 0.02, sz * 0.34), r=0.022, segs=4)
    recalc(bm)
    ob = new_obj("Balloon", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_b(co, n):
        y = co.y
        if y > CY - R * 1.25 + 0.34:  # envelope
            ang = math.atan2(co.z, co.x)
            g = int((ang + math.pi) / (2 * math.pi) * gores) % gores
            base = main if g % 2 == 0 else cream
            # top cap a touch lighter, lower part darker
            t = clamp01((y - (CY - R)) / (2.2 * R))
            f = 0.86 + 0.24 * t
            return tuple(clamp01(c * f) for c in base)
        if y > CY - R * 1.25 - 0.08:  # skirt
            return tuple(clamp01(c * 0.72) for c in main)
        if y > 0.62 and abs(co.x) < 0.4 and abs(co.z) < 0.4 and y < CY - 2.0:  # ropes
            return (0.62, 0.50, 0.34)
        if y > 0.62:  # rim
            return (0.50, 0.36, 0.22)
        # basket: wicker weave by bands
        band = 0.90 + 0.12 * math.sin(y * 32.0)
        return tuple(clamp01(c * band) for c in (0.76, 0.58, 0.36))
    paint(ob, paint_b)
    return ob

# ---------------------------------------------------------------- dock
def dock(seed):
    bm = bmesh.new()
    segs = 16
    R = 1.9
    # deck (thick disc) with a lower ring step
    add_cyl(bm, 0.0, 0.0, 0.16, 0.0, R, R, segs=segs)
    add_cyl(bm, 0.0, 0.0, 0.07, 0.0, R + 0.38, R + 0.38, segs=segs)
    # mooring posts around the rim (5), alternating heights
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3
        h = 0.55 if i % 2 == 0 else 0.42
        add_cyl(bm, math.cos(a) * (R - 0.18), 0.16, 0.16 + h, math.sin(a) * (R - 0.18), 0.09, 0.075, segs=6)
    # rope loops between posts (low, sagging) as thin segments
    for i in range(5):
        a0 = 2 * math.pi * i / 5 + 0.3
        a1 = 2 * math.pi * (i + 1) / 5 + 0.3
        p0 = (math.cos(a0) * (R - 0.18), 0.16 + (0.5 if i % 2 == 0 else 0.38), math.sin(a0) * (R - 0.18))
        p1 = (math.cos(a1) * (R - 0.18), 0.16 + (0.5 if (i + 1) % 2 == 0 else 0.38), math.sin(a1) * (R - 0.18))
        mid = ((p0[0] + p1[0]) / 2 * 1.02, min(p0[1], p1[1]) - 0.12, (p0[2] + p1[2]) / 2 * 1.02)
        seg_between(bm, p0, mid, r=0.018, segs=3)
        seg_between(bm, mid, p1, r=0.018, segs=3)
    # sandbag pair on the deck
    for sx, sz in ((0.9, 0.5), (-0.7, -0.9)):
        add_box(bm, sx, 0.16 + 0.13, sz, 0.36, 0.26, 0.28, top_scale=0.8)
    recalc(bm)
    ob = new_obj("Dock", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_d(co, n):
        y = co.y
        r = math.hypot(co.x, co.z)
        if y <= 0.075 and r > R - 0.01:      # low step: stone
            return (0.70, 0.66, 0.58)
        if y <= 0.165 and r <= R + 0.01:     # deck planks
            plank = 0.92 + 0.10 * math.sin(co.x * 9.0)
            return tuple(clamp01(c * plank) for c in (0.74, 0.55, 0.34))
        if y > 0.16 and (abs(co.x) < 0.4 and abs(co.z) < 0.4):
            return (0.62, 0.50, 0.34)
        if y > 0.16 and n.y > 0.5 and r > 1.0 and r < 1.75 and y < 0.7:
            return (0.50, 0.36, 0.22)
        if y > 0.2 and y < 0.6 and r < 1.3:  # sandbags
            return (0.86, 0.78, 0.60)
        return (0.50, 0.36, 0.22)
    paint(ob, paint_d)
    return ob

def sign(seed):
    """Post + arrow board pointing +Z."""
    bm = bmesh.new()
    add_cyl(bm, 0.0, 0.0, 2.05, 0.0, 0.075, 0.06, segs=6)
    # arrow board: box body + pointed tip along +Z
    add_box(bm, 0.0, 1.78, 0.30, 0.10, 0.34, 0.84)
    tip = [bm.verts.new((x, 1.78 + y, 0.72)) for x, y in ((-0.05, -0.17), (0.05, -0.17), (0.05, 0.17), (-0.05, 0.17))]
    apex_a = bm.verts.new((-0.05, 1.78, 1.02))
    apex_b = bm.verts.new((0.05, 1.78, 1.02))
    bm.faces.new((tip[0], tip[1], apex_b, apex_a))
    bm.faces.new((tip[3], tip[2], apex_b, apex_a))
    bm.faces.new((tip[1], tip[2], apex_b))
    bm.faces.new((tip[0], apex_a, tip[3]))
    recalc(bm)
    ob = new_obj("Sign", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_s(co, n):
        if co.y > 1.55 and (abs(co.x) > 0.04 or co.z > 0.1):
            return (0.96, 0.90, 0.72) if abs(n.x) > 0.5 else (0.78, 0.62, 0.40)
        return (0.50, 0.36, 0.22)
    paint(ob, paint_s)
    return ob

# ---------------------------------------------------------------- hoppity ball
def ball(seed):
    bm = bmesh.new()
    R = 0.62
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=R)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.y * 0.94 + R * 0.94, v.co.z))
    # handle: two knobs on top like ears
    for sx in (-1, 1):
        k = bmesh.new()
        bmesh.ops.create_icosphere(k, subdivisions=1, radius=0.15)
        for v in k.verts:
            v.co = Vector((v.co.x * 0.7 + sx * 0.24, v.co.y * 1.3 + R * 0.94 + R * 0.86, v.co.z * 0.7 + 0.02))
        me = bpy.data.meshes.new("tmp"); k.to_mesh(me); k.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    recalc(bm)
    ob = new_obj("Ball", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    body = (0.96, 0.46, 0.36)
    def paint_ball(co, n):
        y = co.y - R * 0.94
        if co.y > R * 0.94 + R * 0.70:   # knobs
            return (0.98, 0.86, 0.60)
        # face on +Z: eyes and blush
        for sx in (-1, 1):
            if math.hypot(co.x - sx * 0.19, y - 0.10) < 0.085 and co.z > 0.35:
                return (0.18, 0.14, 0.16)
            if math.hypot(co.x - sx * 0.36, y - 0.02) < 0.10 and co.z > 0.25:
                return (0.99, 0.66, 0.62)
        # smile: thin arc under the eyes
        d = math.hypot(co.x, y + 0.14)
        if co.z > 0.38 and 0.13 < d < 0.19 and y < -0.10:
            return (0.30, 0.16, 0.18)
        # a lighter belly band and a cream stripe
        f = 0.92 + 0.16 * clamp01(n.y)
        if abs(y) < 0.035 and co.z < 0.0:
            return (0.99, 0.92, 0.80)
        return tuple(clamp01(c * f) for c in body)
    paint(ob, paint_ball)
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    families = {
        "balloon": [balloon(1, (0.98, 0.76, 0.22), (0.99, 0.95, 0.86)),
                    balloon(2, (0.40, 0.70, 0.96), (0.99, 0.97, 0.92)),
                    balloon(3, (0.96, 0.52, 0.70), (0.99, 0.95, 0.90))],
        "dock": [dock(1)],
        "docksign": [sign(1)],
        "hopball": [ball(1)],
    }
    stats = {}
    sheet = []
    for fam, obs in families.items():
        for i, ob in enumerate(obs):
            ob.data.materials.append(mat)
            ob.name = f"{fam}_{i}"
            stand(ob)
            path = os.path.join(OUT, f"{fam}_{i}.glb")
            export_glb([ob], path)
            stats[ob.name] = {"tris": post_unlit(path), "bytes": os.path.getsize(path)}
            sheet.append(ob)
    n = len(sheet)
    for i, o in enumerate(sheet):
        o.location = ((i - (n - 1) / 2.0) * 4.2, 0.0, 0.0)
    render_sheet([], os.path.join(OUT, "transport_sheet.png"), spacing=1.0, cam_dist=30.0, res=(1800, 800), elev_deg=14)
    print("STATS", json.dumps(stats))
