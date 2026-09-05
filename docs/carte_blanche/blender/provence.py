"""Third-map family (carte-blanche v3): "la Lande aux Moulins" -- a lavender
heath in the Provence register. Violet rows, bleached stone, dark slim
cypresses, a windmill whose sails turn (separate GLB so Godot can rotate
them), beehives, a stone well, dry-stone wall segments, a gnarled olive.

Same contract as every other family: Y-up authoring, COLOR_0 per corner,
one flat KHR_materials_unlit material, no textures.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from transport import add_cyl, add_box, seg_between, recalc

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

def clamp01(x): return max(0.0, min(1.0, x))
def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def blob(bm, center, radius, subdiv=1, squash=(1, 1, 1), noise=0.12, seed=0):
    rnd = random.Random(seed)
    k = bmesh.new()
    bmesh.ops.create_icosphere(k, subdivisions=subdiv, radius=1.0)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    for v in k.verts:
        n = v.co.normalized()
        d = 1.0 + noise * (math.sin(n.x * 2.3 + ph[0]) * math.cos(n.y * 1.7 + ph[1]) + 0.6 * math.sin(n.z * 3.1 + ph[2]))
        v.co = Vector((center[0] + n.x * radius * squash[0] * d, center[1] + n.y * radius * squash[1] * d, center[2] + n.z * radius * squash[2] * d))
    me = bpy.data.meshes.new("tmp"); k.to_mesh(me); k.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)

# ------------------------------------------------------------- lavender
def lavender(seed, spikes, hue):
    """A low grey-green mound with violet spikes standing out of it."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    blob(bm, (0, 0.16, 0), 0.34, subdiv=1, squash=(1.15, 0.55, 1.15), noise=0.15, seed=seed)
    tops = []
    for i in range(spikes):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.0, 0.26)
        x, z = math.cos(a) * r, math.sin(a) * r
        h = rnd.uniform(0.42, 0.62)
        lean = rnd.uniform(-0.08, 0.08)
        # stem
        seg_between(bm, (x, 0.15, z), (x + lean, h, z + lean * 0.5), r=0.012, segs=3)
        # spike head: a squashed blob
        blob(bm, (x + lean, h + 0.05, z + lean * 0.5), 0.075, subdiv=0, squash=(0.7, 1.6, 0.7), noise=0.05, seed=seed + i)
        tops.append(h)
    recalc(bm)
    ob = new_obj("Lavender", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_l(co, n):
        if co.y < 0.36 and (co.x * co.x + co.z * co.z) > 0.0004 and co.y < 0.34:
            f = 0.85 + 0.25 * clamp01(n.y)
            return tuple(clamp01(c * f) for c in (0.56, 0.64, 0.50))
        if co.y > 0.40:
            f = 0.88 + 0.22 * clamp01(n.y)
            return tuple(clamp01(c * f) for c in hue)
        return (0.46, 0.54, 0.40)
    paint(ob, paint_l)
    return ob

# ------------------------------------------------------------- cypress
def cypress(seed, height):
    bm = bmesh.new()
    add_cyl(bm, 0, 0, 0.5, 0, 0.11, 0.09, segs=6)
    # stacked tapering blobs
    # Fixed number of tiers scaled to the height (a geometric loop on the
    # radius never reached `height` and spun for ever -- paid once).
    tiers = 6
    for i in range(tiers):
        t = i / (tiers - 1)
        y = 0.4 + (height - 0.9) * t
        r = 0.42 * (1.0 - 0.62 * t)
        blob(bm, (0, y + r * 0.6, 0), r, subdiv=1, squash=(1.0, 1.35, 1.0), noise=0.10, seed=seed + i)
    recalc(bm)
    ob = new_obj("Cypress", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_c(co, n):
        if co.y < 0.45 and (co.x * co.x + co.z * co.z) < 0.02:
            return (0.34, 0.24, 0.16)
        t = clamp01(co.y / height)
        f = 0.80 + 0.30 * clamp01(n.y) + 0.10 * t
        return tuple(clamp01(c * f) for c in (0.18, 0.36, 0.24))
    paint(ob, paint_c)
    return ob

# ------------------------------------------------------------- olive
def olive(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # gnarled trunk: two leaning cylinders
    add_cyl(bm, 0, 0, 0.9, 0, 0.26, 0.18, segs=7)
    seg_between(bm, (0.05, 0.8, 0), (0.55, 1.6, 0.2), r=0.11, segs=5)
    seg_between(bm, (-0.05, 0.85, 0.05), (-0.5, 1.7, -0.3), r=0.10, segs=5)
    for i in range(6):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.3, 0.85)
        blob(bm, (math.cos(a) * r, 1.75 + rnd.uniform(-0.15, 0.35), math.sin(a) * r), rnd.uniform(0.45, 0.62), subdiv=1, squash=(1.1, 0.8, 1.1), noise=0.14, seed=seed + i)
    recalc(bm)
    ob = new_obj("Olive", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_o(co, n):
        if co.y < 1.25:
            return (0.46, 0.38, 0.28)
        f = 0.82 + 0.28 * clamp01(n.y)
        return tuple(clamp01(c * f) for c in (0.60, 0.68, 0.52))
    paint(ob, paint_o)
    return ob

# ------------------------------------------------------------- windmill
def windmill_tower(seed):
    bm = bmesh.new()
    H = 7.5
    add_cyl(bm, 0, 0, H, 0, 1.55, 1.15, segs=12)
    # conical roof
    ring = [bm.verts.new((math.cos(2 * math.pi * i / 12) * 1.35, H, math.sin(2 * math.pi * i / 12) * 1.35)) for i in range(12)]
    apex = bm.verts.new((0, H + 1.6, 0))
    for i in range(12):
        bm.faces.new((ring[i], ring[(i + 1) % 12], apex))
    bm.faces.new(tuple(reversed(ring)))
    # door (+z) and two windows as slightly proud boxes
    add_box(bm, 0, 0.75, 1.42, 0.7, 1.5, 0.16)
    add_box(bm, 0, 3.6, 1.3, 0.5, 0.6, 0.14)
    add_box(bm, 1.28, 5.2, 0.0, 0.14, 0.6, 0.5)
    # hub axle stub (+z side, high) where the sails attach
    add_cyl(bm, 0, H - 0.9, H - 0.9 + 0.001, 0, 0.001, 0.001, segs=3, cap=False)
    seg_between(bm, (0, H - 0.9, 1.0), (0, H - 0.9, 1.75), r=0.16, segs=8)
    # stone base ring
    add_cyl(bm, 0, 0, 0.35, 0, 1.85, 1.85, segs=12)
    recalc(bm)
    ob = new_obj("Windmill", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_w(co, n):
        r = math.hypot(co.x, co.z)
        # Roof = the wider ring at H (r 1.35) and the apex; the tower's own
        # top ring (r 1.15) must stay white or its colour interpolates down
        # the whole two-ring cylinder (first sheet: a red tower).
        if (co.y > H - 0.01 and r > 1.25) or (co.y > H + 0.5):
            return (0.72, 0.30, 0.24)
        if co.y < 0.36 and r > 1.6:          # base ring
            return (0.62, 0.58, 0.50)
        if abs(co.x) < 0.4 and co.z > 1.3 and co.y < 1.6:   # door
            return (0.42, 0.28, 0.18)
        if (co.z > 1.25 and co.y > 3.2 and co.y < 4.0) or (co.x > 1.2 and co.y > 4.8 and co.y < 5.6):  # windows
            return (0.38, 0.50, 0.62)
        if co.z > 0.9 and co.y > H - 1.2 and co.y < H - 0.6 and r < 0.5 + 1.8:  # axle
            return (0.40, 0.28, 0.18)
        # whitewashed stone with bands
        band = 0.94 + 0.06 * math.sin(co.y * 5.0)
        f = (0.86 + 0.14 * clamp01(n.y + 0.4)) * band
        return tuple(clamp01(c * f) for c in (0.96, 0.92, 0.84))
    paint(ob, paint_w)
    return ob

def windmill_sails(seed):
    """Four sails on a hub, in the X-Y plane, origin at the axle. Rotated by
    Godot about +Z (the axle points +Z out of the tower's front)."""
    bm = bmesh.new()
    seg_between(bm, (0, 0, -0.3), (0, 0, 0.25), r=0.26, segs=8)
    L = 4.6
    for k in range(4):
        a = k * math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        # spar
        seg_between(bm, (0, 0, 0.05), (ca * L, sa * L, 0.05), r=0.07, segs=4)
        # lattice blade: a thin box offset to one side of the spar
        # (built as a quad strip so it can be trapezoidal)
        w0, w1 = 0.45, 0.95
        px, py = -sa, ca   # perpendicular in the plane
        pts = []
        for (d, w) in ((0.9, w0), (L, w1)):
            pts.append((ca * d + px * 0.0, sa * d + py * 0.0, 0.12))
            pts.append((ca * d + px * w, sa * d + py * w, 0.12))
        v = [bm.verts.new(p) for p in pts]
        # One quad only: the decor shader is cull_disabled, so the back
        # shows too (a second, reversed face is a duplicate to bmesh).
        bm.faces.new((v[0], v[1], v[3], v[2]))
    recalc(bm)
    ob = new_obj("Sails", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_s(co, n):
        r = math.hypot(co.x, co.y)
        if r < 0.32:
            return (0.40, 0.28, 0.18)
        if abs(co.z - 0.12) < 0.02:
            stripe = 0.9 + 0.1 * math.sin(r * 6.0)
            return tuple(clamp01(c * stripe) for c in (0.96, 0.93, 0.86))
        return (0.50, 0.36, 0.22)
    paint(ob, paint_s)
    return ob

# ------------------------------------------------------------- beehive
def beehive(seed):
    bm = bmesh.new()
    add_box(bm, 0, 0.14, 0, 0.62, 0.28, 0.62, top_scale=1.06)
    add_box(bm, 0, 0.42, 0, 0.66, 0.28, 0.66, top_scale=1.06)
    add_box(bm, 0, 0.66, 0, 0.72, 0.10, 0.72)
    add_box(bm, 0, 0.74, 0, 0.58, 0.06, 0.58)
    recalc(bm)
    ob = new_obj("Beehive", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_h(co, n):
        if co.y > 0.60:
            return (0.55, 0.40, 0.28)
        if co.y > 0.29 and co.y < 0.30:
            return (0.60, 0.44, 0.30)
        if abs(co.x) < 0.14 and co.z > 0.3 and co.y < 0.12 and co.y > 0.04:
            return (0.20, 0.14, 0.10)
        return (0.99, 0.94, 0.78) if co.y < 0.29 else (0.92, 0.80, 0.52)
    paint(ob, paint_h)
    return ob

# ------------------------------------------------------------- well
def well(seed):
    bm = bmesh.new()
    add_cyl(bm, 0, 0, 0.85, 0, 0.78, 0.78, segs=10)
    add_cyl(bm, 0, 0.85, 0.86, 0, 0.62, 0.62, segs=10)  # dark water disc cap
    for sx in (-1, 1):
        add_cyl(bm, sx * 0.55, 0.85, 2.0, 0, 0.07, 0.06, segs=5)
    seg_between(bm, (-0.6, 2.0, 0), (0.6, 2.0, 0), r=0.05, segs=5)
    # little roof
    for sz in (-1, 1):
        add_box(bm, 0, 2.15, sz * 0.32, 1.5, 0.06, 0.7)
    seg_between(bm, (0, 1.3, 0), (0, 2.0, 0), r=0.02, segs=3)
    add_box(bm, 0, 1.25, 0, 0.22, 0.22, 0.22)
    recalc(bm)
    ob = new_obj("Well", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_well(co, n):
        r = math.hypot(co.x, co.z)
        if co.y > 0.84 and co.y < 0.87 and r < 0.63:
            return (0.20, 0.36, 0.44)
        if co.y > 2.05:
            return (0.72, 0.30, 0.24)
        if co.y > 0.9 and co.y < 2.05:
            return (0.50, 0.36, 0.22) if r > 0.3 else (0.55, 0.40, 0.28)
        stone = 0.92 + 0.10 * math.sin(co.y * 12.0 + math.atan2(co.z, co.x) * 5.0)
        return tuple(clamp01(c * stone) for c in (0.72, 0.68, 0.60))
    paint(ob, paint_well)
    return ob

# ------------------------------------------------------------- dry-stone wall
def wall(seed, length):
    rnd = random.Random(seed)
    bm = bmesh.new()
    x = -length / 2
    while x < length / 2:
        w = rnd.uniform(0.35, 0.6)
        for row, y in enumerate((0.15, 0.42, 0.66)):
            h = 0.28 if row < 2 else 0.22
            add_box(bm, x + w / 2 + (0.1 if row == 1 else 0), y, rnd.uniform(-0.03, 0.03), w * 0.95, h, 0.42 - row * 0.04)
        x += w
    recalc(bm)
    ob = new_obj("Wall", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_wall(co, n):
        f = 0.86 + 0.16 * clamp01(n.y) + 0.06 * math.sin(co.x * 7.0)
        return tuple(clamp01(c * f) for c in (0.74, 0.70, 0.62))
    paint(ob, paint_wall)
    return ob

# ------------------------------------------------------------- bleached rock
def pale_rock(seed, size):
    rnd = random.Random(seed)
    bm = bmesh.new()
    blob(bm, (0, size * 0.42, 0), size, subdiv=1, squash=(1.2, 0.7, 1.0), noise=0.18, seed=seed)
    recalc(bm)
    ob = new_obj("PaleRock", bm)
    for p in ob.data.polygons:
        p.use_smooth = False
    def paint_r(co, n):
        f = 0.82 + 0.22 * clamp01(n.y)
        return tuple(clamp01(c * f) for c in (0.82, 0.78, 0.70))
    paint(ob, paint_r)
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    families = {
        "lavender": [lavender(1, 9, (0.58, 0.40, 0.82)), lavender(2, 11, (0.50, 0.34, 0.76)), lavender(3, 8, (0.66, 0.48, 0.88))],
        "cypress": [cypress(11, 4.2), cypress(12, 3.4)],
        "olive": [olive(21)],
        "windmill": [windmill_tower(31)],
        "sails": [windmill_sails(32)],
        "beehive": [beehive(41)],
        "well": [well(51)],
        "wall": [wall(61, 3.0), wall(62, 2.0)],
        "palerock": [pale_rock(71, 0.5), pale_rock(72, 0.8)],
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
    cols = 8
    for i, o in enumerate(sheet):
        o.location = ((i % cols - (cols - 1) / 2.0) * 3.2, (i // cols) * -6.0 + 3.0, 0.0)
    render_sheet([], os.path.join(OUT, "provence_sheet.png"), spacing=1.0, cam_dist=30.0, res=(1800, 900), elev_deg=22)
    print("STATS", json.dumps(stats))
