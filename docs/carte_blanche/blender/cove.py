"""Fifth-zone family (CH29, 6 septembre 2026): "la Crique" -- a small warm
cove east of the moor. Pale sand, turquoise sea, a red-and-white
lighthouse as the landmark, palms on the dunes, beach umbrellas and
deckchairs, sandcastles (the zone's own interaction), buoys, a dune burrow
for a future inhabitant, and the sand yacht ("char a voile"), the night's
new free ground vehicle.

Same contract as every other family: Y-up authoring, COLOR_0 per corner,
one flat KHR_materials_unlit material, no textures. Origins:
  palm         ground under the trunk foot
  lighthouse   ground under the tower centre
  lamp         centre of the lamp (installed at LAMP_Y above the tower base)
  umbrella     pole foot
  deckchair    ground under the seat centre, faces +Z
  buoy         water line (y = 0 is the surface)
  shell/star   ground contact
  driftwood    ground contact
  sandcastle   ground under the mound centre
  castleflag   foot of the stick (installed on the keep top)
  yacht_hull   ground contact of the wheels, nose toward +Z
  yacht_sail   mast foot (same origin as the hull), sail toward -Z
  burrow       ground under the mound centre, opening toward +Z
  lifeguard    ground under the chair, seat faces +Z
  dunegrass    ground contact
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from transport import add_cyl, add_box, seg_between, recalc

OUT = os.environ.get("COVE_OUT", os.path.join(os.path.dirname(__file__), "..", "out"))
os.makedirs(OUT, exist_ok=True)

def clamp01(x): return max(0.0, min(1.0, x))
def lerp(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
def shade(c, f): return tuple(clamp01(v * f) for v in c)

SAND = (0.93, 0.85, 0.62)
SAND_WET = (0.78, 0.68, 0.48)
WOOD = (0.62, 0.47, 0.30)
WOOD_PALE = (0.80, 0.72, 0.58)
RED = (0.90, 0.30, 0.26)
WHITE = (0.97, 0.96, 0.92)
TEAL = (0.36, 0.76, 0.80)
YELLOW = (0.98, 0.82, 0.30)
PALM_TRUNK = (0.66, 0.50, 0.32)
PALM_LEAF = (0.36, 0.66, 0.34)
PALM_LEAF_B = (0.48, 0.74, 0.36)

def merge(bm, k):
    me = bpy.data.meshes.new("tmp"); k.to_mesh(me); k.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)

def blob(bm, center, radius, subdiv=1, squash=(1, 1, 1), noise=0.10, seed=0):
    rnd = random.Random(seed)
    k = bmesh.new()
    bmesh.ops.create_icosphere(k, subdivisions=subdiv, radius=1.0)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    for v in k.verts:
        n = v.co.normalized()
        d = 1.0 + noise * (math.sin(n.x * 2.3 + ph[0]) * math.cos(n.y * 1.7 + ph[1]) + 0.6 * math.sin(n.z * 3.1 + ph[2]))
        v.co = Vector((center[0] + n.x * radius * squash[0] * d, center[1] + n.y * radius * squash[1] * d, center[2] + n.z * radius * squash[2] * d))
    merge(bm, k)

def quad(bm, a, b, c, d):
    """One quad with CLOCKWISE winding seen from the side the normal faces
    -- recalc() is run afterwards on every closed body, but an open ribbon
    (the sail, a frond) keeps what it is given; the decor shader is
    cull_disabled, so both sides draw regardless."""
    return bm.faces.new(tuple(bm.verts.new(p) for p in (a, b, c, d)))

def tri(bm, a, b, c):
    return bm.faces.new((bm.verts.new(a), bm.verts.new(b), bm.verts.new(c)))

def finish(name, bm, painter, smooth=False):
    recalc(bm)
    ob = new_obj(name, bm)
    for p in ob.data.polygons:
        p.use_smooth = smooth
    paint(ob, painter)
    return ob

# ---------------------------------------------------------------- palm
def palm(seed, height=4.6, lean=0.55, fronds=7):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # Curved trunk: a chain of short tapered cylinders bending toward +x.
    segs = 6
    pts = []
    for i in range(segs + 1):
        t = i / segs
        x = lean * t * t * 1.4
        z = 0.12 * math.sin(t * 3.0 + seed)
        pts.append((x, height * t, z))
    for i in range(segs):
        a, b = pts[i], pts[i + 1]
        r0 = 0.30 - 0.12 * (i / segs)
        r1 = 0.30 - 0.12 * ((i + 1) / segs)
        k = bmesh.new()
        # tapered cylinder along the segment (rings at both ends, 6 sides)
        d = Vector(b) - Vector(a)
        L = d.length
        zax = d.normalized()
        xax = Vector((0, 0, 1)) if abs(zax.z) < 0.9 else Vector((1, 0, 0))
        xax = (xax - zax * xax.dot(zax)).normalized()
        yax = zax.cross(xax)
        ra = [k.verts.new(Vector(a) + (xax * math.cos(2 * math.pi * j / 6) + yax * math.sin(2 * math.pi * j / 6)) * r0) for j in range(6)]
        rb = [k.verts.new(Vector(b) + (xax * math.cos(2 * math.pi * j / 6) + yax * math.sin(2 * math.pi * j / 6)) * r1) for j in range(6)]
        for j in range(6):
            k.faces.new((ra[j], ra[(j + 1) % 6], rb[(j + 1) % 6], rb[j]))
        if i == 0:
            k.faces.new(tuple(reversed(ra)))
        merge(bm, k)
    top = Vector(pts[-1])
    # Crown knob
    blob(bm, (top.x, top.y + 0.1, top.z), 0.34, subdiv=1, noise=0.05, seed=seed)
    # Fronds: each a bent ribbon of 5 quads, drooping, tapering, with a
    # slight twist so the silhouette is not a star of flat blades.
    for f in range(fronds):
        a = 2 * math.pi * f / fronds + rnd.uniform(-0.2, 0.2)
        length = rnd.uniform(2.0, 2.6)
        droop = rnd.uniform(0.9, 1.4)
        dirx, dirz = math.cos(a), math.sin(a)
        prev = None
        n = 5
        for s in range(n):
            t0, t1 = s / n, (s + 1) / n
            def P(t, side):
                w = 0.36 * math.sin(math.pi * min(1.0, t * 1.15)) + 0.04
                px = top.x + dirx * length * t
                pz = top.z + dirz * length * t
                py = top.y + 0.25 + 0.9 * t - droop * t * t * 1.6
                # side offset perpendicular, tilted down a bit (V-shaped leaf)
                sx, sz = -dirz * w * side, dirx * w * side
                return (px + sx, py - abs(w) * 0.35, pz + sz)
            quad(bm, P(t0, -1), P(t0, 1), P(t1, 1), P(t1, -1))
    # Coconuts
    for c in range(3):
        a = 2 * math.pi * c / 3 + 0.5
        blob(bm, (top.x + math.cos(a) * 0.28, top.y - 0.12, top.z + math.sin(a) * 0.28), 0.14, subdiv=1, noise=0.0, seed=c)
    def painter(co, n):
        d = math.hypot(co.x - top.x, co.z - top.z)
        if co.y > top.y - 0.3 and d > 0.5:
            # frond: lighter toward the tip and on the upper face
            t = clamp01(d / 2.4)
            base = lerp(PALM_LEAF, PALM_LEAF_B, t)
            return shade(base, 0.88 + 0.2 * clamp01(n.y))
        if co.y > top.y - 0.3 and d <= 0.5 and co.y < top.y + 0.02:
            return (0.42, 0.30, 0.16)   # coconuts / crown base
        if co.y > top.y - 0.3:
            return shade(PALM_LEAF, 0.8)
        # trunk: ring bands
        band = 0.90 + 0.12 * math.sin(co.y * 9.0)
        return shade(PALM_TRUNK, band)
    return finish("Palm", bm, painter)

# ---------------------------------------------------------------- lighthouse
LH_H = 8.4
LAMP_Y = 7.55
def lighthouse(seed):
    bm = bmesh.new()
    # stone base
    add_cyl(bm, 0.0, 0.0, 0.5, 0.0, 1.75, 1.6, segs=14)
    # tower, tapered -- built as FOUR stacked segments, one per colour
    # band: vertex colours interpolate between rings, so a single 0.5..6.7
    # cylinder painted in bands rendered solid red (the first sheet).
    for b in range(4):
        y0 = 0.5 + b * 1.55
        y1 = 0.5 + (b + 1) * 1.55
        r0 = 1.30 - 0.35 * (b / 4.0)
        r1 = 1.30 - 0.35 * ((b + 1) / 4.0)
        add_cyl(bm, 0.0, y0, y1, 0.0, r0, r1, segs=14, cap=(b == 3))
    # gallery ring + railing posts
    add_cyl(bm, 0.0, 6.7, 6.95, 0.0, 1.35, 1.35, segs=14)
    for i in range(10):
        a = 2 * math.pi * i / 10
        seg_between(bm, (math.cos(a) * 1.25, 6.95, math.sin(a) * 1.25), (math.cos(a) * 1.25, 7.45, math.sin(a) * 1.25), r=0.03, segs=3)
    # lamp room glass (cylinder) and cap
    add_cyl(bm, 0.0, 6.95, 7.95, 0.0, 0.82, 0.78, segs=10)
    add_cyl(bm, 0.0, 7.95, 8.1, 0.0, 0.95, 0.95, segs=10)
    # roof cone
    k = bmesh.new()
    bmesh.ops.create_cone(k, cap_ends=True, cap_tris=False, segments=10, radius1=0.95, radius2=0.0, depth=0.95)
    for v in k.verts:
        v.co = Vector((v.co.x, v.co.z + 8.1 + 0.475, v.co.y))
    merge(bm, k)
    # finial ball
    blob(bm, (0.0, 8.7, 0.0), 0.13, subdiv=1, noise=0.0)
    # door toward +Z and two small windows
    add_box(bm, 0.0, 1.1, 1.45, 0.7, 1.2, 0.2)
    add_box(bm, 0.0, 3.4, 1.15, 0.45, 0.55, 0.2)
    add_box(bm, 0.0, 5.2, 1.05, 0.40, 0.50, 0.2)
    def painter(co, n):
        r = math.hypot(co.x, co.z)
        y = co.y
        if y < 0.5:
            return (0.66, 0.62, 0.56)  # stone base
        if y > 8.05 and y <= 8.75:
            return (0.85, 0.30, 0.26) if y < 8.62 else (0.95, 0.80, 0.30)
        if y > 7.9 and y <= 8.12:
            return (0.44, 0.44, 0.50)  # cap rim
        if y > 6.95 and y <= 7.95 and r < 0.9:
            return (0.80, 0.94, 0.98)  # glass
        if y > 6.65 and y <= 6.96:
            return (0.44, 0.44, 0.50)  # gallery
        if y > 6.96 and r > 1.1:
            return (0.44, 0.44, 0.50)  # railing
        if co.z > 1.0 and abs(co.x) < 0.4 and y < 1.75 and y > 0.5:
            return (0.34, 0.24, 0.16)  # door
        if co.z > 0.95 and abs(co.x) < 0.3 and (3.1 < y < 3.7 or 4.9 < y < 5.5):
            return (0.55, 0.78, 0.86)  # windows
        # tower bands: red / white, 4 bands of ~1.55
        band = int((y - 0.5 + 0.02) / 1.55)
        base = RED if band % 2 == 0 else WHITE
        return shade(base, 0.92 + 0.14 * clamp01(n.y + 0.4))
    return finish("Lighthouse", bm, painter)

def lamp(seed):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.42)
    def painter(co, n):
        return (0.99, 0.92, 0.62)
    return finish("Lamp", bm, painter)

# ---------------------------------------------------------------- umbrella / deckchair / lifeguard
def umbrella(seed, colour_a, colour_b):
    bm = bmesh.new()
    add_cyl(bm, 0.0, 0.0, 2.35, 0.0, 0.045, 0.035, segs=5)
    # canopy: 8 panels, scalloped hem, slight droop
    R = 1.35
    top = (0.0, 2.45, 0.0)
    n = 8
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        am = (a0 + a1) / 2
        rim0 = (math.cos(a0) * R, 1.95, math.sin(a0) * R)
        rim1 = (math.cos(a1) * R, 1.95, math.sin(a1) * R)
        scallop = (math.cos(am) * (R + 0.08), 1.82, math.sin(am) * (R + 0.08))
        mid0 = (math.cos(a0) * R * 0.55, 2.28, math.sin(a0) * R * 0.55)
        mid1 = (math.cos(a1) * R * 0.55, 2.28, math.sin(a1) * R * 0.55)
        tri(bm, top, mid1, mid0)
        quad(bm, mid0, mid1, rim1, rim0)
        tri(bm, rim0, rim1, scallop)
    blob(bm, (0.0, 2.52, 0.0), 0.08, subdiv=0, noise=0.0)
    def painter(co, n):
        if co.y < 1.75:
            return (0.85, 0.85, 0.82)
        a = math.atan2(co.z, co.x)
        panel = int((a + math.pi) / (2 * math.pi) * 8 + 0.5) % 8
        base = colour_a if panel % 2 == 0 else colour_b
        return shade(base, 0.9 + 0.16 * clamp01(n.y))
    return finish("Umbrella", bm, painter)

def deckchair(seed, stripe):
    bm = bmesh.new()
    # two side frames (wood), seat slats and a reclined back as a ribbon
    for sx in (-0.42, 0.42):
        seg_between(bm, (sx, 0.0, 0.55), (sx, 0.38, 0.55), r=0.035, segs=4)
        seg_between(bm, (sx, 0.0, -0.35), (sx, 0.42, -0.5), r=0.035, segs=4)
        seg_between(bm, (sx, 0.38, 0.6), (sx, 0.42, -0.5), r=0.035, segs=4)
        seg_between(bm, (sx, 0.42, -0.5), (sx, 1.05, -0.95), r=0.035, segs=4)
    # fabric: seat then back, ribbon of quads
    pts = [(0.45, 0.42, 0.55), (0.45, 0.44, -0.45), (0.45, 1.0, -0.9)]
    for i in range(2):
        a, b = pts[i], pts[i + 1]
        quad(bm, (-a[0], a[1], a[2]), (a[0], a[1], a[2]), (b[0], b[1], b[2]), (-b[0], b[1], b[2]))
    def painter(co, n):
        if abs(co.x) > 0.40 and abs(co.x) < 0.46 and (co.z > 0.5 or co.z < -0.3 or abs(co.y - 0.4) < 0.06):
            return WOOD_PALE
        if abs(co.x) <= 0.46:
            s = int((co.x + 0.45) / 0.15) % 2
            return WHITE if s == 0 else stripe
        return WOOD_PALE
    return finish("Deckchair", bm, painter)

def lifeguard(seed):
    bm = bmesh.new()
    for sx in (-0.6, 0.6):
        for sz in (-0.5, 0.5):
            seg_between(bm, (sx, 0.0, sz), (sx * 0.8, 2.1, sz * 0.8), r=0.06, segs=4)
    add_box(bm, 0.0, 2.15, 0.0, 1.2, 0.12, 1.0)
    add_box(bm, 0.0, 2.7, -0.42, 1.2, 1.0, 0.1)
    # ladder rungs on +Z
    for i in range(4):
        y = 0.45 + i * 0.45
        seg_between(bm, (-0.5, y, 0.45), (0.5, y, 0.45), r=0.03, segs=3)
    # small red umbrella on a post
    seg_between(bm, (0.45, 2.2, 0.3), (0.5, 3.6, 0.3), r=0.03, segs=3)
    k = bmesh.new()
    bmesh.ops.create_cone(k, cap_ends=True, cap_tris=False, segments=8, radius1=0.85, radius2=0.0, depth=0.45)
    for v in k.verts:
        v.co = Vector((v.co.x + 0.5, v.co.z + 3.55, v.co.y + 0.3))
    merge(bm, k)
    def painter(co, n):
        if co.y > 3.3:
            a = math.atan2(co.z - 0.3, co.x - 0.5)
            return RED if int((a + math.pi) / (2 * math.pi) * 8) % 2 == 0 else WHITE
        if co.y > 2.05:
            return WHITE if co.y < 2.25 or co.z < -0.3 else WHITE
        return (0.92, 0.90, 0.84)
    return finish("Lifeguard", bm, painter)

# ---------------------------------------------------------------- buoy / shells / driftwood / dune grass
def buoy(seed):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.42)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.y * 0.85 + 0.05, v.co.z))
    seg_between(bm, (0.0, 0.3, 0.0), (0.0, 0.95, 0.0), r=0.05, segs=4)
    blob(bm, (0.0, 1.0, 0.0), 0.1, subdiv=0, noise=0.0)
    def painter(co, n):
        if co.y > 0.9:
            return YELLOW
        if co.y > 0.4:
            return (0.30, 0.30, 0.34)
        return WHITE if 0.02 < co.y < 0.16 else RED
    return finish("Buoy", bm, painter)

def shell(seed, kind):
    bm = bmesh.new()
    if kind == 0:
        # fan shell: half disc of ridged quads
        n = 7
        for i in range(n):
            a0 = math.pi * i / n
            a1 = math.pi * (i + 1) / n
            r = 0.28
            tri(bm, (0.0, 0.02, 0.0), (math.cos(a0) * r * 0.6, 0.10, math.sin(a0) * r * 0.6), (math.cos(a1) * r * 0.6, 0.10, math.sin(a1) * r * 0.6))
            quad(bm, (math.cos(a0) * r * 0.6, 0.10, math.sin(a0) * r * 0.6), (math.cos(a0) * r, 0.02, math.sin(a0) * r), (math.cos(a1) * r, 0.02, math.sin(a1) * r), (math.cos(a1) * r * 0.6, 0.10, math.sin(a1) * r * 0.6))
        col = (0.97, 0.86, 0.72)
    else:
        # spiral shell: a tapered coil of blobs
        for i in range(5):
            t = i / 4
            a = t * 4.5
            r = 0.16 * (1.0 - 0.7 * t)
            blob(bm, (math.cos(a) * 0.12 * (1 - t), 0.05 + r * 0.8, math.sin(a) * 0.12 * (1 - t)), r, subdiv=0, noise=0.0, seed=i)
        col = (0.96, 0.80, 0.66)
    def painter(co, n):
        return shade(col, 0.86 + 0.2 * clamp01(n.y))
    return finish("Shell", bm, painter)

def starfish(seed):
    bm = bmesh.new()
    c = bm.verts.new((0.0, 0.08, 0.0))
    for i in range(5):
        a0 = 2 * math.pi * i / 5
        a1 = 2 * math.pi * (i + 0.5) / 5
        a2 = 2 * math.pi * (i + 1) / 5
        tip = bm.verts.new((math.cos(a0) * 0.34, 0.02, math.sin(a0) * 0.34))
        inner = bm.verts.new((math.cos(a1) * 0.12, 0.05, math.sin(a1) * 0.12))
        bm.faces.new((c, tip, inner))
        tip2 = bm.verts.new((math.cos(a2) * 0.34, 0.02, math.sin(a2) * 0.34))
        bm.faces.new((c, inner, tip2))
    def painter(co, n):
        return (0.96, 0.52, 0.34)
    return finish("Starfish", bm, painter)

def driftwood(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    pts = [(-1.1, 0.12, 0.0), (-0.4, 0.22, 0.12), (0.3, 0.18, -0.08), (1.0, 0.30, 0.05)]
    for i in range(3):
        seg_between(bm, pts[i], pts[i + 1], r=0.16 - 0.03 * i, segs=6)
    seg_between(bm, (0.3, 0.18, -0.08), (0.7, 0.62, -0.4), r=0.07, segs=5)
    for p in pts:
        blob(bm, p, 0.15, subdiv=0, noise=0.1, seed=seed)
    def painter(co, n):
        return shade((0.82, 0.76, 0.66), 0.88 + 0.16 * clamp01(n.y))
    return finish("Driftwood", bm, painter)

def dunegrass(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    for i in range(9):
        a = rnd.uniform(0, 6.28)
        r = rnd.uniform(0.0, 0.22)
        x, z = math.cos(a) * r, math.sin(a) * r
        h = rnd.uniform(0.6, 0.95)
        lean = rnd.uniform(-0.25, 0.25)
        w = 0.05
        quad(bm, (x - w, 0.0, z), (x + w, 0.0, z), (x + lean + w * 0.3, h, z + lean * 0.4), (x + lean - w * 0.3, h, z + lean * 0.4))
    def painter(co, n):
        t = clamp01(co.y / 0.9)
        return lerp((0.62, 0.70, 0.42), (0.86, 0.84, 0.56), t)
    return finish("Dunegrass", bm, painter)

# ---------------------------------------------------------------- sandcastle
def sandcastle(seed):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # mound base (squashed blob) and a moat ring suggestion via colour
    blob(bm, (0.0, 0.08, 0.0), 0.95, subdiv=1, squash=(1.0, 0.28, 1.0), noise=0.06, seed=seed)
    # keep: tapered cylinder with crenellations
    def tower(cx, cz, r, h, teeth):
        add_cyl(bm, cx, 0.2, 0.2 + h, cz, r, r * 0.9, segs=8)
        for i in range(teeth):
            a = 2 * math.pi * i / teeth
            add_box(bm, cx + math.cos(a) * r * 0.82, 0.2 + h + 0.08, cz + math.sin(a) * r * 0.82, r * 0.5, 0.16, r * 0.5)
    tower(0.0, 0.0, 0.34, 0.85, 6)
    for i in range(4):
        a = 2 * math.pi * i / 4 + math.pi / 4
        tower(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.2, 0.52 + 0.08 * (i % 2), 4)
    # walls between corner towers
    for i in range(4):
        a0 = 2 * math.pi * i / 4 + math.pi / 4
        a1 = 2 * math.pi * (i + 1) / 4 + math.pi / 4
        cx, cz = (math.cos(a0) + math.cos(a1)) * 0.31, (math.sin(a0) + math.sin(a1)) * 0.31
        L = 0.62 * math.sqrt(2) - 0.36
        ang = math.atan2(math.sin(a1) - math.sin(a0), math.cos(a1) - math.cos(a0))
        k = bmesh.new()
        v = [k.verts.new((x, y, z)) for x in (-L / 2, L / 2) for y in (0.2, 0.5) for z in (-0.08, 0.08)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in f:
            k.faces.new(tuple(v[j] for j in q))
        for vv in k.verts:
            x, z = vv.co.x, vv.co.z
            vv.co = Vector((cx + x * math.cos(ang) - z * math.sin(ang), vv.co.y, cz + x * math.sin(ang) + z * math.cos(ang)))
        merge(bm, k)
    # door on the keep (+z)
    add_box(bm, 0.0, 0.38, 0.32, 0.16, 0.26, 0.08)
    def painter(co, n):
        if co.z > 0.3 and abs(co.x) < 0.09 and 0.25 < co.y < 0.52:
            return (0.42, 0.32, 0.20)
        if co.y < 0.19:
            t = clamp01(math.hypot(co.x, co.z) / 0.95)
            return lerp(SAND_WET, (0.86, 0.76, 0.54), 1.0 - t)
        return shade((0.90, 0.78, 0.54), 0.86 + 0.2 * clamp01(n.y))
    return finish("Sandcastle", bm, painter)

def castleflag(seed):
    bm = bmesh.new()
    seg_between(bm, (0.0, 0.0, 0.0), (0.0, 0.55, 0.0), r=0.015, segs=3)
    tri(bm, (0.0, 0.56, 0.0), (0.0, 0.40, 0.0), (0.36, 0.48, 0.02))
    def painter(co, n):
        return RED if co.x > 0.02 else WOOD
    return finish("Castleflag", bm, painter)

# ---------------------------------------------------------------- burrow (P2)
def burrow(seed):
    bm = bmesh.new()
    # dune mound
    blob(bm, (0.0, 0.1, -0.3), 1.35, subdiv=1, squash=(1.15, 0.62, 1.0), noise=0.08, seed=seed)
    # opening: a dark half-disc set into the +z face -- an inset box
    add_box(bm, 0.0, 0.42, 0.72, 0.9, 0.7, 0.5, top_scale=0.7)
    # driftwood lintel and posts
    seg_between(bm, (-0.62, 0.0, 0.95), (-0.55, 0.9, 0.9), r=0.07, segs=5)
    seg_between(bm, (0.62, 0.0, 0.95), (0.55, 0.9, 0.9), r=0.07, segs=5)
    seg_between(bm, (-0.72, 0.9, 0.9), (0.72, 0.95, 0.9), r=0.08, segs=5)
    # a folded towel and a bucket with spade beside the door
    add_box(bm, 1.15, 0.08, 0.95, 0.55, 0.16, 0.42)
    add_cyl(bm, -1.15, 0.0, 0.42, 0.95, 0.22, 0.26, segs=8)
    seg_between(bm, (-1.05, 0.3, 0.9), (-0.9, 0.95, 1.05), r=0.025, segs=3)
    add_box(bm, -0.88, 1.0, 1.07, 0.16, 0.2, 0.04)
    # shells around the doorstep
    for i in range(3):
        blob(bm, (-0.35 + 0.35 * i, 0.04, 1.35 + 0.1 * (i % 2)), 0.08, subdiv=0, noise=0.0, seed=i)
    def painter(co, n):
        if abs(co.x) < 0.42 and 0.1 < co.y < 0.75 and co.z > 0.55 and co.z < 1.0:
            return (0.24, 0.17, 0.12)   # the dark opening
        if co.x > 0.85 and co.y < 0.2 and co.z > 0.7:
            return TEAL if int((co.x - 0.9) / 0.14) % 2 == 0 else WHITE   # towel
        if co.x < -0.9 and co.y < 0.45 and co.z > 0.7:
            return RED                  # bucket
        if co.x < -0.8 and co.y > 0.88 and co.z > 1.0:
            return YELLOW               # spade blade
        if (abs(co.x) > 0.5 and abs(co.x) < 0.75 and co.z > 0.8 and co.y < 1.0) or (co.y > 0.8 and co.z > 0.8 and abs(co.x) < 0.75):
            return (0.80, 0.72, 0.60)   # driftwood frame
        if co.y < 0.12 and co.z > 1.2:
            return (0.97, 0.88, 0.76)   # shells
        return shade(SAND, 0.86 + 0.18 * clamp01(n.y))
    return finish("Burrow", bm, painter)

# ---------------------------------------------------------------- sand yacht
def yacht_hull(seed):
    bm = bmesh.new()
    # three wheels: two rear at z=-0.55, one front at z=+0.85
    def wheel(cx, cz):
        k = bmesh.new()
        bmesh.ops.create_cone(k, cap_ends=True, cap_tris=False, segments=10, radius1=0.30, radius2=0.30, depth=0.16)
        for v in k.verts:
            v.co = Vector((cx + v.co.z, 0.30 + v.co.y, cz + v.co.x))
        merge(bm, k)
    wheel(-0.62, -0.55); wheel(0.62, -0.55); wheel(0.0, 0.85)
    # axle and frame
    seg_between(bm, (-0.62, 0.3, -0.55), (0.62, 0.3, -0.55), r=0.04, segs=4)
    seg_between(bm, (0.0, 0.3, -0.55), (0.0, 0.3, 0.85), r=0.05, segs=4)
    # hull: a low boat-like body sitting on the frame, seat cutout
    add_box(bm, 0.0, 0.5, 0.05, 0.62, 0.30, 1.4, top_scale=1.05)
    add_box(bm, 0.0, 0.66, 0.5, 0.56, 0.08, 0.5)   # foredeck
    add_box(bm, 0.0, 0.62, -0.45, 0.5, 0.14, 0.3)  # seat back/cushion
    # nose cone
    k = bmesh.new()
    bmesh.ops.create_cone(k, cap_ends=True, cap_tris=False, segments=6, radius1=0.30, radius2=0.05, depth=0.5)
    for v in k.verts:
        v.co = Vector((v.co.x, 0.52 + v.co.y * 0.6, 0.75 + v.co.z + 0.25))
    merge(bm, k)
    # mast foot stub (the sail GLB carries the mast)
    add_cyl(bm, 0.0, 0.6, 0.75, 0.15, 0.06, 0.06, segs=5)
    def painter(co, n):
        r = math.hypot(co.x - (0.62 if co.x > 0.3 else (-0.62 if co.x < -0.3 else 0.0)), co.z - (-0.55 if co.z < 0.2 else 0.85))
        if co.y < 0.61 and (abs(abs(co.x) - 0.62) < 0.1 or (abs(co.x) < 0.1 and co.z > 0.6)) and r < 0.31 and co.y < 0.62:
            return (0.22, 0.22, 0.26) if r > 0.14 else YELLOW   # tyre / hub
        if co.y < 0.36:
            return (0.55, 0.55, 0.58)    # frame
        if co.y > 0.66 and co.z < -0.25:
            return (0.30, 0.55, 0.62)    # cushion
        if co.y > 0.6 and co.z > 0.25:
            return WOOD_PALE             # foredeck
        stripe = int((co.z + 0.7) / 0.35) % 2
        return TEAL if stripe == 0 else WHITE
    return finish("YachtHull", bm, painter)

def yacht_sail(seed):
    bm = bmesh.new()
    seg_between(bm, (0.0, 0.7, 0.15), (0.0, 3.1, 0.15), r=0.035, segs=5)     # mast
    seg_between(bm, (0.0, 1.0, 0.15), (0.0, 1.05, -1.35), r=0.03, segs=4)    # boom
    # sail: triangular, in 4 horizontal strips so the wind shader bends it
    n = 4
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        def P(t, edge):
            y = 1.05 + t * 2.0
            zback = -1.35 * (1.0 - t)
            return (0.02, y, 0.12 if edge == 0 else zback)
        quad(bm, P(t0, 0), P(t0, 1), P(t1, 1), P(t1, 0))
    # pennant at the top
    tri(bm, (0.0, 3.1, 0.15), (0.0, 2.95, 0.15), (0.0, 3.03, -0.3))
    def painter(co, n):
        if co.y > 2.9 and co.z < 0.0:
            return YELLOW
        if abs(co.x) < 0.02 and (co.z > 0.1 or co.y < 1.08):
            return WOOD
        band = int((co.y - 1.05) / 0.5) % 2
        return RED if band == 0 else WHITE
    return finish("YachtSail", bm, painter)

# ---------------------------------------------------------------- main
if __name__ == "__main__":
    reset()
    mat = flat_material()
    families = {
        "palm": [palm(1, 4.6, 0.55), palm(2, 5.2, 0.35), palm(3, 4.0, 0.75)],
        "lighthouse": [lighthouse(1)],
        "lamp": [lamp(1)],
        "umbrella": [umbrella(1, RED, WHITE), umbrella(2, YELLOW, TEAL)],
        "deckchair": [deckchair(1, TEAL), deckchair(2, RED)],
        "lifeguard": [lifeguard(1)],
        "buoy": [buoy(1)],
        "shell": [shell(1, 0), shell(2, 1)],
        "starfish": [starfish(1)],
        "driftwood": [driftwood(1)],
        "dunegrass": [dunegrass(1), dunegrass(2)],
        "sandcastle": [sandcastle(1)],
        "castleflag": [castleflag(1)],
        "burrow": [burrow(1)],
        "yacht_hull": [yacht_hull(1)],
        "yacht_sail": [yacht_sail(1)],
    }
    stats = {}
    sheet = []
    for fam, obs in families.items():
        for i, ob in enumerate(obs):
            ob.data.materials.append(mat)
            stand(ob)
            path = os.path.join(OUT, f"{fam}_{i}.glb")
            export_glb([ob], path)
            tri = post_unlit(path)
            stats[f"{fam}_{i}"] = {"tris": tri, "bytes": os.path.getsize(path)}
            sheet.append(ob)
    print(json.dumps(stats, indent=1))
    with open(os.path.join(OUT, "cove_stats.json"), "w") as f:
        json.dump(stats, f, indent=1)
    if os.environ.get("COVE_SHEET", "1") == "1":
        # bpy 4.2 names the engine BLENDER_EEVEE_NEXT; fall back to the
        # workbench (vertex colours, flat) when neither EEVEE id exists.
        import common as _c
        _orig = bpy.ops.render.render
        def _render_sheet(objs, path, **kw):
            try:
                render_sheet(objs, path, **kw)
            except TypeError:
                sc = bpy.context.scene
                for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
                    try:
                        sc.render.engine = eng
                        break
                    except TypeError:
                        continue
                if sc.render.engine == "BLENDER_WORKBENCH":
                    sc.display.shading.light = 'FLAT'
                    sc.display.shading.color_type = 'VERTEX'
                sc.render.filepath = path
                bpy.ops.render.render(write_still=True)
        _render_sheet(sheet, os.path.join(OUT, "cove_sheet.png"), spacing=3.2, cam_dist=34.0, res=(2200, 700), elev_deg=16)
