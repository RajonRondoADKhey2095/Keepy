"""Shared helpers for the carte-blanche prop families (bpy 5.0, headless).

Every family script builds N variants, writes one GLB per variant with
per-vertex colours (COLOR_0) and a single flat KHR_materials_unlit material,
then renders a contact sheet PNG so the shapes can be looked at before they
go anywhere near Godot.
"""
import bpy, bmesh, math, random, os, json, struct
from mathutils import Vector, Color

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def srgb_to_linear(c):
    out = []
    for v in c[:3]:
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return out

def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob

def ensure_color_layer(me, name="Col"):
    if name not in me.color_attributes:
        me.color_attributes.new(name=name, type='BYTE_COLOR', domain='CORNER')
    return me.color_attributes[name]

def paint(ob, func):
    """func(vertex_co_local, face_normal) -> (r,g,b) in sRGB 0..1.
    Writes CORNER colours (per face-loop) so flat facets can differ."""
    me = ob.data
    layer = ensure_color_layer(me)
    me.calc_loop_triangles()
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            r, g, b = func(v, poly.normal)
            # Blender stores BYTE_COLOR in sRGB space via color_srgb.
            layer.data[li].color_srgb = (r, g, b, 1.0)

def flat_material(name="Flat"):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat

def stand(ob):
    """Geometry is authored Y-up (game convention). Blender is Z-up, and the
    glTF exporter converts Blender Z-up to glTF Y-up -- so rotate +90 deg
    about X first, which maps authored +Y onto Blender +Z. Applied to the
    mesh data so export_apply and the sheet camera both see it upright."""
    ob.rotation_euler = (math.pi / 2, 0.0, 0.0)
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return ob

def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True,
        export_normals=True, export_texcoords=False, export_tangents=False,
        export_materials='EXPORT', export_vertex_color='ACTIVE',
        export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
        export_animations=False, export_skins=False, export_morph=False,
        export_lights=False, export_cameras=False)

def post_unlit(path, base_color=(1.0, 1.0, 1.0)):
    """Rewrite the GLB: one material, flat baseColorFactor, KHR_materials_unlit,
    no textures, no PBR maps (the same contract decimate_decor.py writes)."""
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67
    off = 12
    chunks = []
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunks.append((ctype, data[off:off + clen]))
        off += clen
    js = json.loads(chunks[0][1].decode("utf-8"))
    mat = {"name": "Flat", "pbrMetallicRoughness": {"baseColorFactor": [*base_color, 1.0],
           "metallicFactor": 0.0, "roughnessFactor": 1.0},
           "extensions": {"KHR_materials_unlit": {}}, "doubleSided": False}
    js["materials"] = [mat]
    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["material"] = 0
            prim["attributes"].pop("TEXCOORD_0", None)
            prim["attributes"].pop("TANGENT", None)
    js["extensionsUsed"] = ["KHR_materials_unlit"]
    js["extensionsRequired"] = []
    js.pop("images", None); js.pop("textures", None); js.pop("samplers", None)
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    while len(jb) % 4:
        jb += b" "
    binb = chunks[1][1]
    while len(binb) % 4:
        binb += b"\0"
    total = 12 + 8 + len(jb) + 8 + len(binb)
    out = struct.pack("<III", magic, 2, total) + struct.pack("<II", len(jb), 0x4E4F534A) + jb \
        + struct.pack("<II", len(binb), 0x004E4942) + binb
    with open(path, "wb") as f:
        f.write(out)
    tri = 0
    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            acc = js["accessors"][prim["indices"]]
            tri += acc["count"] // 3
    return tri

def render_sheet(objs, path, spacing=3.0, cam_dist=None, res=(1200, 700), elev_deg=22.0, light_rot=(0.9, 0.3, 0.6)):
    """Lays the variants in a row and renders them with EEVEE, flat vertex colours
    (the emission material) plus a workbench-ish look: no lighting is needed."""
    scene = bpy.context.scene
    n = len(objs)
    for i, o in enumerate(objs):
        o.location = ((i - (n - 1) / 2.0) * spacing, 0.0, 0.0)
    width = spacing * n
    if cam_dist is None:
        cam_dist = width * 1.1 + 4.0
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    e = math.radians(elev_deg)
    cam.location = (0.0, -cam_dist * math.cos(e), cam_dist * math.sin(e) + 1.0)
    cam.rotation_euler = (math.pi / 2 - e, 0.0, 0.0)
    cam_data.lens = 40
    scene.camera = cam
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.82, 0.86, 0.80, 1.0)
    scene.world = world
    sun = bpy.data.lights.new("Sun", 'SUN'); sun.energy = 3.0
    so = bpy.data.objects.new("Sun", sun); scene.collection.objects.link(so)
    so.rotation_euler = light_rot
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

def tri_count(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)
