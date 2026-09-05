"""Ground-level families: rocks, bushes, grass tufts, flowers, mushrooms, stumps,
fallen leaves, pebbles. Each exported as its own GLB with vertex colours."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from trees import lerp, clamp01, join, blob_bm

OUT = os.path.join(os.path.dirname(__file__), "..", "out")

def rock(seed, size=1.0):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.55 * size)
    sx, sy, sz = rnd.uniform(0.9, 1.4), rnd.uniform(0.55, 0.8), rnd.uniform(0.8, 1.2)
    for v in bm.verts:
        n = v.co.normalized()
        d = 1.0 + 0.18 * (rnd.random() - 0.5)
        v.co = Vector((n.x * sx, n.y * sy, n.z * sz)) * 0.55 * size * d
    # flatten the bottom so it sits
    for v in bm.verts:
        if v.co.y < -0.12 * size:
            v.co.y = -0.12 * size + (v.co.y + 0.12 * size) * 0.3
    ob = new_obj("Rock", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    base = (0.66, 0.64, 0.60)
    moss = (0.52, 0.66, 0.36)
    def paint_rock(co, n):
        up = clamp01(n.y)
        c = lerp(base, moss, clamp01((up - 0.78) * 6.0))
        f = 1.0 + 0.10 * (rnd.random() - 0.5)
        f *= 0.85 + 0.15 * clamp01(co.y / (0.4 * size) + 0.5)
        return tuple(clamp01(v * f) for v in c)
    paint(ob, paint_rock)
    return ob

def bush(seed):
    rnd = random.Random(seed)
    blobs = [blob_bm(0.55, 1, (1.15, 0.8, 1.0), 0.12, seed, (0, 0.38, 0))]
    for k in range(rnd.randint(2, 4)):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.3, 0.42)
        blobs.append(blob_bm(r, 1, (1.0, 0.85, 1.0), 0.12, seed + k + 3,
                             (math.cos(a) * 0.45, 0.30 + rnd.uniform(-0.05, 0.12), math.sin(a) * 0.45)))
    ob = new_obj("Bush", join(blobs))
    for p in ob.data.polygons:
        p.use_smooth = True
    top = (0.50, 0.76, 0.34); bot = (0.22, 0.46, 0.22)
    def paint_bush(co, n):
        t = clamp01(co.y / 0.85)
        return lerp(bot, top, t ** 0.9)
    paint(ob, paint_bush)
    return ob

def grass_tuft(seed, blades=6):
    """A fan of blades: each blade is a 2-quad strip (4 tris), bent outward.
    Vertex colour alpha... no alpha: the shader uses local y for the sway weight."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    for b in range(blades):
        a = 2 * math.pi * b / blades + rnd.uniform(-0.3, 0.3)
        h = rnd.uniform(0.28, 0.46)
        w = rnd.uniform(0.045, 0.07)
        lean = rnd.uniform(0.10, 0.22)
        dx, dz = math.cos(a), math.sin(a)
        px, pz = -dz, dx
        base = Vector((dx * 0.04, 0, dz * 0.04))
        vs = []
        for k, (t, ww) in enumerate([(0.0, 1.0), (0.55, 0.7), (1.0, 0.0)]):
            y = h * t
            out = lean * t * t
            c = base + Vector((dx * out, y, dz * out))
            if ww > 0:
                vs.append((bm.verts.new(c + Vector((px * w * ww, 0, pz * w * ww))),
                           bm.verts.new(c - Vector((px * w * ww, 0, pz * w * ww)))))
            else:
                tip = bm.verts.new(c)
                vs.append((tip, tip))
        bm.faces.new((vs[0][0], vs[0][1], vs[1][1], vs[1][0]))
        bm.faces.new((vs[1][0], vs[1][1], vs[2][0]))
    ob = new_obj("Grass", bm)
    for p in ob.data.polygons:
        p.use_smooth = True
    top = (0.66, 0.86, 0.40); bot = (0.30, 0.56, 0.26)
    def paint_grass(co, n):
        return lerp(bot, top, clamp01(co.y / 0.42))
    paint(ob, paint_grass)
    return ob

def flower(seed, petals=5, col=(0.98, 0.62, 0.72)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    h = rnd.uniform(0.22, 0.34)
    # stem: a thin 3-sided prism
    stem = []
    for k in range(2):
        ring = []
        for i in range(3):
            a = 2 * math.pi * i / 3
            r = 0.018 if k == 0 else 0.012
            ring.append(bm.verts.new((math.cos(a) * r, k * h, math.sin(a) * r)))
        stem.append(ring)
    for i in range(3):
        bm.faces.new((stem[0][i], stem[0][(i + 1) % 3], stem[1][(i + 1) % 3], stem[1][i]))
    # head: a small disc of petals (fan) + centre
    cx = bm.verts.new((0, h + 0.01, 0))
    ring = []
    R = rnd.uniform(0.09, 0.13)
    for i in range(petals * 2):
        a = 2 * math.pi * i / (petals * 2)
        r = R if i % 2 == 0 else R * 0.55
        ring.append(bm.verts.new((math.cos(a) * r, h + 0.02 + (0.02 if i % 2 == 0 else 0.0), math.sin(a) * r)))
    for i in range(petals * 2):
        bm.faces.new((cx, ring[(i + 1) % (petals * 2)], ring[i]))
    ob = new_obj("Flower", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    stem_c = (0.36, 0.62, 0.30); centre = (0.98, 0.86, 0.30)
    def paint_flower(co, n):
        if co.y < h + 0.005:
            return stem_c
        d = math.hypot(co.x, co.z)
        return lerp(centre, col, clamp01(d / 0.06))
    paint(ob, paint_flower)
    return ob

def mushroom(seed, cap_col=(0.90, 0.36, 0.30)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    h = rnd.uniform(0.16, 0.26); rs = 0.04; rc = rnd.uniform(0.11, 0.16)
    segs = 7
    rings = []
    for k, (y, r) in enumerate([(0, rs * 1.2), (h * 0.7, rs), (h * 0.75, rc * 0.9), (h * 0.95, rc), (h * 1.12, rc * 0.55)]):
        ring = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r, y, math.sin(2 * math.pi * i / segs) * r)) for i in range(segs)]
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            bm.faces.new((rings[k][i], rings[k][(i + 1) % segs], rings[k + 1][(i + 1) % segs], rings[k + 1][i]))
    top = bm.verts.new((0, h * 1.2, 0))
    for i in range(segs):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % segs], top))
    ob = new_obj("Mushroom", bm)
    for p in ob.data.polygons:
        p.use_smooth = True
    stem_c = (0.96, 0.90, 0.78)
    def paint_m(co, n):
        if co.y < h * 0.72:
            return stem_c
        if n.y < -0.2:
            return (0.98, 0.94, 0.80)
        t = clamp01((co.y - h * 0.75) / (h * 0.45))
        return lerp(tuple(c * 0.85 for c in cap_col), cap_col, t)
    paint(ob, paint_m)
    return ob

def stump(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    segs = 8; h = rnd.uniform(0.38, 0.5); r = rnd.uniform(0.32, 0.42)
    bot = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r * (1.25 + 0.12 * math.sin(i * 2.1)), 0, math.sin(2 * math.pi * i / segs) * r * (1.25 + 0.12 * math.cos(i * 1.7)))) for i in range(segs)]
    mid = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r, h * 0.3, math.sin(2 * math.pi * i / segs) * r)) for i in range(segs)]
    top = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r * 1.02, h, math.sin(2 * math.pi * i / segs) * r * 1.02)) for i in range(segs)]
    inner = [bm.verts.new((math.cos(2 * math.pi * i / segs) * r * 0.82, h + 0.01, math.sin(2 * math.pi * i / segs) * r * 0.82)) for i in range(segs)]
    c = bm.verts.new((0, h + 0.015, 0))
    for a, b in ((bot, mid), (mid, top), (top, inner)):
        for i in range(segs):
            bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    for i in range(segs):
        bm.faces.new((inner[i], inner[(i + 1) % segs], c))
    ob = new_obj("Stump", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    bark = (0.46, 0.32, 0.20); ring_l = (0.86, 0.72, 0.50); ring_d = (0.70, 0.55, 0.36)
    def paint_s(co, n):
        if n.y > 0.7 and co.y > h - 0.02:
            d = math.hypot(co.x, co.z) / (r * 0.82)
            return ring_l if (int(d * 5) % 2 == 0) else ring_d
        return tuple(clamp01(v * (0.9 + 0.2 * clamp01(co.y / h))) for v in bark)
    paint(ob, paint_s)
    return ob

def leaf(seed, col=(0.86, 0.52, 0.24)):
    rnd = random.Random(seed)
    bm = bmesh.new()
    L = 0.22; W = 0.13
    pts = [(0, 0, -L * 0.5), (W * 0.5, 0.01, -L * 0.1), (W * 0.35, 0.02, L * 0.3), (0, 0.03, L * 0.5), (-W * 0.35, 0.02, L * 0.3), (-W * 0.5, 0.01, -L * 0.1)]
    vs = [bm.verts.new(p) for p in pts]
    bm.faces.new(vs)
    ob = new_obj("Leaf", bm)
    def paint_l(co, n):
        return lerp(tuple(c * 0.8 for c in col), col, clamp01((co.z + L * 0.5) / L))
    paint(ob, paint_l)
    return ob

def pebble(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.09)
    for v in bm.verts:
        v.co = Vector((v.co.x * rnd.uniform(1.0, 1.5), v.co.y * 0.55, v.co.z * rnd.uniform(0.9, 1.3)))
    ob = new_obj("Pebble", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_p(co, n):
        f = 0.9 + 0.15 * clamp01(n.y)
        return tuple(clamp01(v * f) for v in (0.70, 0.66, 0.60))
    paint(ob, paint_p)
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    families = {
        "rock": [rock(1, 1.0), rock(2, 1.25), rock(3, 0.8), rock(4, 1.5)],
        "bush": [bush(11), bush(12), bush(13)],
        "grass": [grass_tuft(21, 6), grass_tuft(22, 5), grass_tuft(23, 7)],
        "flower": [flower(31, 5, (0.98, 0.62, 0.72)), flower(32, 6, (0.99, 0.90, 0.40)), flower(33, 5, (0.72, 0.62, 0.96)), flower(34, 5, (0.99, 0.98, 0.94))],
        "mushroom": [mushroom(41, (0.90, 0.36, 0.30)), mushroom(42, (0.92, 0.70, 0.40))],
        "stump": [stump(51), stump(52)],
        "leaf": [leaf(61, (0.86, 0.52, 0.24)), leaf(62, (0.96, 0.72, 0.28)), leaf(63, (0.74, 0.34, 0.20))],
        "pebble": [pebble(71), pebble(72)],
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
    # contact sheet: two rows
    scene = bpy.context.scene
    n = len(sheet)
    cols = 8
    for i, o in enumerate(sheet):
        o.location = ((i % cols - (cols - 1) / 2.0) * 1.7, (i // cols) * -1.9 + 1.9, 0.0)
    render_sheet([], os.path.join(OUT, "ground_sheet.png"), spacing=1.0, cam_dist=11.0, res=(1600, 900), elev_deg=38)
    print("STATS", json.dumps(stats))
