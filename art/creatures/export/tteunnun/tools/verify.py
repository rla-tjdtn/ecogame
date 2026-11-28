# 결과 다시 읽어 확인: blender -b --factory-startup -noaudio -P verify.py
# 1) glb 를 JSON 으로 직접 읽어 뼈·클립·길이·텍스처·삼각형 수  2) fbx·glb 를 Blender 로 다시 가져와 뼈·동작 목록
import sys, os, json, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from tt_common import OUT

lines = []
def say(*a):
    s = ' '.join(str(x) for x in a); print(s); lines.append(s)

glb = os.path.join(OUT, 'tteunnun.glb')
with open(glb, 'rb') as f:
    data = f.read()
jl = struct.unpack('<I', data[12:16])[0]
J = json.loads(data[20:20 + jl])
binoff = 20 + jl + 8
say('== GLB', os.path.getsize(glb) // 1024, 'KB')
skin = J['skins'][0]
names = [J['nodes'][j]['name'] for j in skin['joints']]
say('bones', len(names))
say('bone names:', ', '.join(names))
acc = J['accessors']
tris = 0
for m in J['meshes']:
    for pr in m['primitives']:
        tris += acc[pr['indices']]['count'] // 3
        say('  primitive material', J['materials'][pr['material']]['name'], 'tris', acc[pr['indices']]['count'] // 3)
say('triangles', tris)
say('images', len(J.get('images', [])), [i.get('name') for i in J.get('images', [])])
for a in J['animations']:
    tmax = max(acc[s['input']]['max'][0] for s in a['samplers'])
    tgt = {J['nodes'][c['target']['node']]['name'] for c in a['channels']}
    say('clip %-11s %.3f s  = %d frames @30fps, channels %d, bones %d' % (a['name'], tmax, round(tmax * 30) + 1, len(a['channels']), len(tgt)))
for mt in J['materials']:
    pbr = mt.get('pbrMetallicRoughness', {})
    say('material %-7s base=%s mr=%s normal=%s ao=%s emis=%s alpha=%s' % (mt['name'], 'baseColorTexture' in pbr, 'metallicRoughnessTexture' in pbr,
        'normalTexture' in mt, 'occlusionTexture' in mt, 'emissiveTexture' in mt, mt.get('alphaMode', 'OPAQUE')))

for path in (os.path.join(OUT, 'tteunnun.fbx'), glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.endswith('.fbx'):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    say('== reimport', os.path.basename(path), os.path.getsize(path) // 1024, 'KB', 'bones', len(arm.data.bones),
        'meshes', [(o.name, len(o.data.polygons)) for o in bpy.data.objects if o.type == 'MESH'])
    for a in bpy.data.actions:
        fr = a.frame_range
        say('  action %-32s frames %g..%g (%d)' % (a.name, fr[0], fr[1], int(round(fr[1] - fr[0])) + 1))
with open(os.path.join(OUT, 'work', 'verify.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
