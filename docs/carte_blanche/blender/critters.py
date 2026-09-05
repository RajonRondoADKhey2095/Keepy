"""Butterflies: a tiny body plus two wing quads, vertex-coloured. The flap
and the flight path are done in cozy_butterfly.gdshader; the mesh only has
to put the wings at x<0 / x>0 with the body along Z."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from trees import lerp, clamp01

OUT = os.path.join(os.path.dirname(__file__), "..", "out")

def butterfly(seed, col, edge):
    rnd = random.Random(seed)
    bm = bmesh.new()
    # body: a thin 4-vert diamond strip along Z
    L = 0.16
    b = [bm.verts.new((0, 0.012, -L * 0.5)), bm.verts.new((0.016, 0, 0)), bm.verts.new((0, 0.012, L * 0.5)), bm.verts.new((-0.016, 0, 0))]
    bm.faces.new((b[0], b[1], b[2], b[3]))
    # wings: each a 2-quad fan (fore + hind lobe)
    for side in (1, -1):
        W = 0.20; H = 0.14
        root_f = bm.verts.new((side * 0.012, 0.0, 0.03))
        root_h = bm.verts.new((side * 0.012, 0.0, -0.03))
        tip_f1 = bm.verts.new((side * W, 0.0, 0.11))
        tip_f2 = bm.verts.new((side * W * 1.05, 0.0, 0.0))
        tip_h1 = bm.verts.new((side * W * 0.75, 0.0, -0.09))
        tip_h2 = bm.verts.new((side * W * 0.35, 0.0, -0.13))
        if side > 0:
            bm.faces.new((root_f, tip_f1, tip_f2))
            bm.faces.new((root_f, tip_f2, root_h))
            bm.faces.new((root_h, tip_f2, tip_h1))
            bm.faces.new((root_h, tip_h1, tip_h2))
        else:
            bm.faces.new((root_f, tip_f2, tip_f1))
            bm.faces.new((root_f, root_h, tip_f2))
            bm.faces.new((root_h, tip_h1, tip_f2))
            bm.faces.new((root_h, tip_h2, tip_h1))
    ob = new_obj("Butterfly", bm)
    body_c = (0.25, 0.18, 0.14)
    def paint_b(co, n):
        if abs(co.x) < 0.02 and abs(co.z) <= 0.081 and (abs(co.x) < 0.017):
            return body_c
        d = abs(co.x) / 0.21
        return lerp(col, edge, clamp01((d - 0.55) * 2.5))
    paint(ob, paint_b)
    return ob

if __name__ == "__main__":
    reset()
    mat = flat_material()
    specs = [((0.99, 0.72, 0.82), (0.86, 0.36, 0.56)), ((0.99, 0.90, 0.45), (0.92, 0.62, 0.20)), ((0.72, 0.84, 0.99), (0.36, 0.52, 0.90))]
    stats = {}
    sheet = []
    for i, (c, e) in enumerate(specs):
        ob = butterfly(80 + i, c, e)
        ob.data.materials.append(mat)
        ob.name = f"butterfly_{i}"
        stand(ob)
        path = os.path.join(OUT, f"butterfly_{i}.glb")
        export_glb([ob], path)
        stats[ob.name] = {"tris": post_unlit(path), "bytes": os.path.getsize(path)}
        sheet.append(ob)
    render_sheet(sheet, os.path.join(OUT, "critters_sheet.png"), spacing=0.6, cam_dist=2.2, res=(900, 400), elev_deg=55)
    print("STATS", json.dumps(stats))
