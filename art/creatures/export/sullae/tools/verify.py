# 5단계: 내보낸 파일을 빈 장면에 다시 읽어 뼈 이름·개수, 메시·삼각형, 재질 텍스처, 클립 이름·길이를 확인한다
#   blender -b --factory-startup -noaudio -P verify.py -- <file.glb|file.fbx> [report.json]
import bpy, sys, os, json
argv = sys.argv[sys.argv.index('--') + 1:]
src = argv[0]; rep = argv[1] if len(argv) > 1 else None
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith('.glb'):
    bpy.ops.import_scene.gltf(filepath=src)
else:
    bpy.ops.import_scene.fbx(filepath=src, use_anim=True)
sc = bpy.context.scene
fps = sc.render.fps / sc.render.fps_base
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
R = dict(file=os.path.basename(src), bytes=os.path.getsize(src), fps=fps,
         bones=[b.name for b in arm.data.bones], bone_count=len(arm.data.bones),
         meshes={o.name: dict(tris=sum(len(p.vertices) - 2 for p in o.data.polygons), verts=len(o.data.vertices), groups=len(o.vertex_groups),
                              skinned=any(m.type == 'ARMATURE' for m in o.modifiers),
                              textures=sorted({n.image.name for m in o.data.materials if m and m.node_tree for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image}))
                 for o in meshes},
         clips={})
for a in sorted(bpy.data.actions, key=lambda a: a.name):
    f0, f1 = a.frame_range
    R['clips'][a.name] = dict(frames=round(f1 - f0, 2), seconds=round((f1 - f0) / fps, 3))
R['total_tris'] = sum(m['tris'] for m in R['meshes'].values())
print('VERIFY', json.dumps(R, ensure_ascii=False))
if rep:
    with open(rep, 'w', encoding='utf-8') as fh: json.dump(R, fh, ensure_ascii=False, indent=1)
