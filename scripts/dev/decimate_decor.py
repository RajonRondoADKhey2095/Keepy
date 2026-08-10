#!/usr/bin/env python3
"""Weld + decimate the raw Meshy decor .glb files down to a frame-budget LOD.

WHY THIS EXISTS
---------------
The decor .glb committed to assets_source/decor/ arrive at 4,130-5,230
triangles and 12-18 MB of PNG each. The frame they would have to fit in draws
48,376 triangles against a 50,000 target (docs/MESHY_SPEC.md 7.2), and the
whole shipped .pck is 4.23 MB. Neither number leaves room for the asset as
authored, so an asset only becomes installable after passing through here.

It emits a FLAT, TEXTURE-FREE, UNLIT .glb. That is not a shortcut, it is the
art direction: every trackside prop in TrackSegment.gd is an unshaded flat
albedo picked by the contrast sweep in MESHY_SPEC 8.2, and section 8 explains
why only an unshaded surface has a KNOWN colour once the dark-mode inversion
runs. A 4096x4096 metallic-roughness map is meaningless on an unlit material
and unaffordable in the payload, so all three maps are dropped and the albedo
is taken from TrackSegment's existing measured palette.

WHAT WELDING IS FOR
-------------------
Meshy builds these as clusters of separate closed shells (a canopy is a heap of
individual blobs). A quadric decimator cannot collapse across shells, so it
stalls well above target -- the leafy tree floors at 603 triangles no matter
what ratio it is given. Rounding positions to a tolerance first merges the
shells into one surface and lets the decimator run to any target. The tolerance
is a fraction of the model's longest bounding-box edge, so it scales with the
asset rather than assuming Meshy's normalisation never changes.

WHAT IT CANNOT DO
-----------------
It does not preserve UVs, so nothing textured survives it. That is the reason
the leafy tree is not installable at any budget the frame can afford: its
character is leaf colour, and losing the texture leaves a silhouette that reads
worse than the 25-triangle cone already shipping. See MESHY_SPEC 11's entry for
this batch, which records the renders that verdict was read off.

USAGE
-----
    python3 scripts/dev/decimate_decor.py [target_triangles ...]

Writes to /tmp/lod/<kind>_<target>.glb. Nothing is installed automatically:
picking a LOD is a visual decision, and installing one is a budget decision.

Requires: numpy, fast-simplification (pip install fast-simplification).
Excluded from the web export, like everything else under scripts/dev/.
"""
import json
import os
import struct
import sys

import numpy as np
import fast_simplification

SRC = "assets_source/decor"
OUT_DIR = "/tmp/lod"

## The four distinct subjects in the batch committed 2026-08-10. Note there is
## no rock and no bench here: the procedural kinds by those names have no
## supplied replacement, which is why this batch could not be a wholesale swap.
MODELS = {
    "tree": "Meshy_AI_Low_Poly_Tree_0810131748_texture.glb",
    "bare_tree": "Meshy_AI_Winter_s_Reach_0810130613_texture.glb",
    "stump": "Meshy_AI_Low_Poly_Tree_Stump_0810131232_texture.glb",
    "bush": "Meshy_AI_Green_Cluster_0810130244_texture.glb",
}

## Albedos lifted verbatim from TrackSegment.gd, NOT sampled off the Meshy
## textures. Those values were chosen by the contrast sweep in MESHY_SPEC 8.2
## against the dark-mode inversion and are the contract; a sampled average
## would quietly replace a measured decision with an arithmetic one.
## These are the values as GDScript writes them, i.e. sRGB: Godot's
## StandardMaterial3D.albedo_color is an sRGB colour, and 8.2's sweep was run
## against _unshaded(Color(...)) materials carrying exactly these numbers.
COLORS = {
    "tree": (0.14, 0.20, 0.15),       # _TREE_CANOPY_COLOR
    "bare_tree": (0.13, 0.10, 0.07),  # _TREE_TRUNK_COLOR
    "stump": (0.32, 0.24, 0.15),      # _STUMP_COLOR
    "bush": (0.11, 0.16, 0.12),       # _BUSH_COLOR
}


def srgb_to_linear(c):
    """glTF baseColorFactor is LINEAR; the table above is sRGB.

    Writing an sRGB value straight into baseColorFactor was the first version
    of this script's behaviour, and it made every asset render far brighter
    than the palette it was supposed to carry -- measured after import, Godot
    read _TREE_TRUNK_COLOR's 0.13 back as 0.396, which is 0.13 converted the
    other way. It did not show in-game only because TrackSegment overrides the
    surface material with the GDScript colour, so the baked one is never drawn.
    Converting here means the .glb is right ON ITS OWN, and the override is
    belt-and-braces rather than the only thing standing between the palette and
    the screen.
    """
    return tuple(
        v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c
    )

## Fraction of the longest bounding-box edge that counts as "the same point"
## when welding. 0.006 was picked as the smallest value that still merges the
## shells on all four subjects; larger values round off the silhouette detail
## the decimator should be choosing to keep or drop.
WELD_FRACTION = 0.006

_COMPONENT_TYPES = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
_NUM_COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def _load(path):
    data = open(path, "rb").read()
    offset, gltf, bin_offset = 12, None, None
    while offset < len(data):
        length, kind = struct.unpack_from("<II", data, offset)
        if kind == 0x4E4F534A:
            gltf = json.loads(data[offset + 8 : offset + 8 + length].decode())
        elif kind == 0x004E4942:
            bin_offset = offset + 8
        offset += 8 + length
    return gltf, data, bin_offset


def _accessor(gltf, data, bin_offset, index):
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = bin_offset + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = _NUM_COMPONENTS[acc["type"]]
    dtype = np.dtype(_COMPONENT_TYPES[acc["componentType"]])
    stride = view.get("byteStride")
    if stride and stride != count * dtype.itemsize:
        raw = np.frombuffer(data, dtype=np.uint8, count=stride * acc["count"], offset=start)
        raw = raw.reshape(acc["count"], stride)[:, : count * dtype.itemsize]
        return np.ascontiguousarray(raw).view(dtype).reshape(acc["count"], count)
    return np.frombuffer(
        data, dtype=dtype, count=acc["count"] * count, offset=start
    ).reshape(acc["count"], count)


def geometry(path):
    gltf, data, bin_offset = _load(path)
    primitive = gltf["meshes"][0]["primitives"][0]
    verts = _accessor(gltf, data, bin_offset, primitive["attributes"]["POSITION"]).astype(np.float32)
    faces = _accessor(gltf, data, bin_offset, primitive["indices"]).astype(np.uint32).reshape(-1, 3)
    return verts, faces


def weld(verts, faces, tolerance):
    """Merge coincident-within-tolerance vertices and drop degenerate faces."""
    keys = np.round(verts / tolerance).astype(np.int64)
    _, first, inverse = np.unique(keys, axis=0, return_index=True, return_inverse=True)
    welded_faces = inverse[faces]
    keep = (
        (welded_faces[:, 0] != welded_faces[:, 1])
        & (welded_faces[:, 1] != welded_faces[:, 2])
        & (welded_faces[:, 0] != welded_faces[:, 2])
    )
    return verts[first].astype(np.float32), welded_faces[keep].astype(np.uint32)


def write_glb(path, verts, faces, color):
    """A minimal unlit, untextured .glb: positions and indices, nothing else."""
    verts = np.ascontiguousarray(verts, dtype=np.float32)
    faces = np.ascontiguousarray(faces, dtype=np.uint32)
    vertex_bytes, index_bytes = verts.tobytes(), faces.tobytes()

    # glTF 2.0 requires each chunk to be 4-byte aligned, and requires the two
    # chunk types to be padded with DIFFERENT bytes: the BIN chunk with zeros,
    # the JSON chunk with spaces (0x20), because the padding is part of the
    # JSON text a reader hands to its parser. Padding JSON with NULs produces a
    # file that is valid or not depending on whether its JSON length happens to
    # be a multiple of 4 -- stump landed aligned and parsed, bare_tree did not
    # and its trailing "\x00\x00" made json.loads raise "Extra data".
    def pad(buf, fill=b"\x00"):
        return buf + fill * ((4 - len(buf) % 4) % 4)

    padded_vertices = pad(vertex_bytes)
    blob = padded_vertices + pad(index_bytes)
    gltf = {
        "asset": {"version": "2.0", "generator": "keepy-decimate-decor"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": os.path.basename(path).split(".")[0]}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1, "material": 0}]}],
        "materials": [
            {
                "name": "unlit_flat",
                "pbrMetallicRoughness": {
                    "baseColorFactor": [color[0], color[1], color[2], 1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0,
                },
                # The project's rule, not a preference -- MESHY_SPEC section 8.
                "extensions": {"KHR_materials_unlit": {}},
            }
        ],
        "extensionsUsed": ["KHR_materials_unlit"],
        "extensionsRequired": ["KHR_materials_unlit"],
        "buffers": [{"byteLength": len(blob)}],
        "bufferViews": [
            {"buffer": 0, "byteOffset": 0, "byteLength": len(vertex_bytes), "target": 34962},
            {
                "buffer": 0,
                "byteOffset": len(padded_vertices),
                "byteLength": len(index_bytes),
                "target": 34963,
            },
        ],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": len(verts),
                "type": "VEC3",
                "min": verts.min(0).tolist(),
                "max": verts.max(0).tolist(),
            },
            {"bufferView": 1, "componentType": 5125, "count": faces.size, "type": "SCALAR"},
        ],
    }
    json_chunk = pad(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    total = 12 + 8 + len(json_chunk) + 8 + len(blob)
    with open(path, "wb") as handle:
        handle.write(struct.pack("<III", 0x46546C67, 2, total))
        handle.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        handle.write(json_chunk)
        handle.write(struct.pack("<II", len(blob), 0x004E4942))
        handle.write(blob)


def main(targets):
    os.makedirs(OUT_DIR, exist_ok=True)
    for kind, filename in MODELS.items():
        verts, faces = geometry(os.path.join(SRC, filename))
        extent = float(np.ptp(verts, axis=0).max())
        welded_verts, welded_faces = weld(verts, faces, extent * WELD_FRACTION)
        print(
            "%-10s source %5d tri -> welded %5d tri"
            % (kind, len(faces), len(welded_faces))
        )
        for target in targets:
            ratio = max(0.0, min(0.999, 1.0 - target / len(welded_faces)))
            out_verts, out_faces = fast_simplification.simplify(welded_verts, welded_faces, ratio)
            out_path = os.path.join(OUT_DIR, "%s_%d.glb" % (kind, target))
            write_glb(out_path, out_verts, out_faces, srgb_to_linear(COLORS[kind]))
            print(
                "             %4d target -> %4d tri  %6.1f KB  %s"
                % (target, len(out_faces), os.path.getsize(out_path) / 1024.0, out_path)
            )


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]] or [100, 150, 250])
