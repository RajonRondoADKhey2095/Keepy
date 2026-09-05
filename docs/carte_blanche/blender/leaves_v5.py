"""Carte-blanche v5 -- GREEN leaves for what a shaken plateau tree sheds.
The hollow's leaf_0..2 (ground_props.leaf) are autumn oranges; tinting
them toward green in the shader gave olive-brown lozenges on capture, so
the plateau gets its own three, same 6-vertex quad, painted green. Same
contract as every carte-blanche GLB."""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from common import *
from ground_props import leaf

OUT = os.path.join(os.path.dirname(__file__), "..", "out")
os.makedirs(OUT, exist_ok=True)

if __name__ == "__main__":
    reset()
    mat = flat_material()
    stats = {}
    for i, col in enumerate([(0.58, 0.84, 0.36), (0.74, 0.90, 0.42), (0.44, 0.72, 0.34)]):
        ob = leaf(91 + i, col)
        ob.data.materials.append(mat)
        ob.name = f"greenleaf_{i}"
        stand(ob)
        path = os.path.join(OUT, f"greenleaf_{i}.glb")
        export_glb([ob], path)
        stats[ob.name] = {"tris": post_unlit(path), "bytes": os.path.getsize(path)}
    print("STATS", json.dumps(stats))
