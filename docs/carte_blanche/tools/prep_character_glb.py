#!/usr/bin/env python3
"""Prepare a raw Meshy character GLB for the hub.

Same treatment the squirrel hero received (docs/MESHY_SPEC.md, CH21 for the
badger): KHR_materials_unlit added by us, metallicRoughness and normal maps
DROPPED (the glTF importer never binds them on an unlit material -- proven at
the pixel), Baked_BaseColor resized to 1024x1024 JPEG q88. The source file is
never modified.

usage: prep_character_glb.py <source.glb> <dest.glb> [--size 1024]
"""
import io, json, struct, sys
from PIL import Image

def align4(b, pad=b'\x00'):
    return b + pad * ((4 - len(b) % 4) % 4)

def main(src, dst, size=1024):
    d = open(src, 'rb').read()
    assert d[:4] == b'glTF'
    jlen = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + jlen])
    boff = 20 + jlen
    assert d[boff + 4:boff + 8] == b'BIN\x00'
    blen = struct.unpack('<I', d[boff:boff + 4])[0]
    bin_ = d[boff + 8:boff + 8 + blen]
    # Which bufferViews are images?
    img_bv = {im['bufferView']: i for i, im in enumerate(j.get('images', []))}
    keep_img = None
    for mt in j['materials']:
        pbr = mt.get('pbrMetallicRoughness', {})
        keep_img = j['textures'][pbr['baseColorTexture']['index']]['source']
        pbr.pop('metallicRoughnessTexture', None)
        mt.pop('normalTexture', None)
        mt.pop('occlusionTexture', None)
        mt.pop('emissiveTexture', None)
        mt.setdefault('extensions', {})['KHR_materials_unlit'] = {}
    j['extensionsUsed'] = sorted(set(j.get('extensionsUsed', []) + ['KHR_materials_unlit']))
    # Rebuild the binary buffer: every non-image bufferView verbatim, the base
    # colour re-encoded, every other image dropped.
    new_bin = b''
    new_bvs = []
    bv_map = {}
    for i, bv in enumerate(j['bufferViews']):
        start = bv.get('byteOffset', 0)
        chunk = bin_[start:start + bv['byteLength']]
        if i in img_bv:
            if img_bv[i] != keep_img:
                continue
            im = Image.open(io.BytesIO(chunk)).convert('RGB')
            w0, h0 = im.size
            im = im.resize((size, size), Image.LANCZOS)
            out = io.BytesIO()
            im.save(out, format='JPEG', quality=88, optimize=True)
            chunk = out.getvalue()
            print(f'  base colour {w0}x{h0} -> {size}x{size} JPEG {len(chunk)} bytes')
        nbv = dict(bv)
        nbv['byteOffset'] = len(new_bin)
        nbv['byteLength'] = len(chunk)
        bv_map[i] = len(new_bvs)
        new_bvs.append(nbv)
        new_bin = align4(new_bin + chunk)
    # Remap accessors and the surviving image.
    for acc in j['accessors']:
        if 'bufferView' in acc:
            acc['bufferView'] = bv_map[acc['bufferView']]
    img = j['images'][keep_img]
    j['images'] = [{'name': img.get('name', 'Baked_BaseColor'), 'mimeType': 'image/jpeg', 'bufferView': bv_map[img['bufferView']]}]
    j['textures'] = [{'source': 0, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})}]
    for mt in j['materials']:
        mt['pbrMetallicRoughness']['baseColorTexture'] = {'index': 0}
    j['bufferViews'] = new_bvs
    j['buffers'] = [{'byteLength': len(new_bin)}]
    js = align4(json.dumps(j, separators=(',', ':')).encode(), b' ')
    out = b'glTF' + struct.pack('<II', 2, 12 + 8 + len(js) + 8 + len(new_bin))
    out += struct.pack('<I', len(js)) + b'JSON' + js
    out += struct.pack('<I', len(new_bin)) + b'BIN\x00' + new_bin
    open(dst, 'wb').write(out)
    print(f'{src} ({len(d)} B) -> {dst} ({len(out)} B)')

if __name__ == '__main__':
    size = 1024
    args = [a for a in sys.argv[1:]]
    if '--size' in args:
        k = args.index('--size'); size = int(args[k + 1]); del args[k:k + 2]
    main(args[0], args[1], size)
