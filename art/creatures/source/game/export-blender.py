# 내보낸 괴물 glb 확인·렌더(Blender, 소리 없음):
#   blender -b --factory-startup -noaudio -P export-blender.py -- <in.glb> <shots_dir>
# 다시 읽어 뼈·메시·액션(클립)과 길이를 출력하고, 클립마다 4프레임을 3/4 앞에서 EEVEE 로 찍어 <shots_dir>/<이름>_<클립>_<n>.png
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, shots = argv[0], argv[1]
os.makedirs(shots, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 60
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and any(md.type == 'ARMATURE' for md in o.modifiers)]
actions = sorted(bpy.data.actions, key=lambda a: a.name)
sc = bpy.context.scene
print('MESHES', [(o.name, len(o.data.polygons), [m.name for m in o.data.materials], [n.image.name for m in o.data.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]) for o in meshes])
print('ARM', arm.name, 'bones', len(arm.data.bones), 'skinned', [any(md.type == 'ARMATURE' for md in o.modifiers) for o in meshes])
for a in actions:
    print('CLIP', a.name, 'sec', round((a.frame_range[1] - a.frame_range[0]) * sc.render.fps_base / sc.render.fps, 3))

pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
H = mx.z - mn.z; cx, cy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
sc.render.engine = 'BLENDER_EEVEE'
sc.render.resolution_x, sc.render.resolution_y = 600, 800
sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
sc.world = bpy.data.worlds.new('W'); sc.world.use_nodes = True
bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.02, 0.022, 0.028, 1)
for nm, loc, en, col in (('Key', (4, -6, 9), 2500, (1, 0.93, 0.85)), ('Rim', (-5, 7, 7), 3500, (0.6, 0.75, 1.0)), ('Fill', (-7, -5, 2), 600, (0.8, 0.85, 1.0))):
    ld = bpy.data.lights.new(nm, 'AREA'); ld.energy = en * 0.25 * (H / 9) ** 2; ld.color = col; ld.size = H * 0.4
    lo = bpy.data.objects.new(nm, ld); sc.collection.objects.link(lo); lo.location = Vector(loc) * (H / 9) + Vector((cx, cy, mn.z + H * 0.3))
    lo.rotation_euler = (Vector((cx, cy, mn.z + H * 0.55)) - lo.location).to_track_quat('-Z', 'Y').to_euler()
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 60; cam.data.clip_end = H * 20
ctr = Vector((cx, cy, mn.z + H * 0.5)); yaw = math.radians(float(os.environ.get('YAW', '200')))
d = Vector((math.sin(yaw), -math.cos(yaw), 0.12)).normalized()
cam.location = ctr + d * H * 1.9; cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()

arm.animation_data_create()
name = os.path.splitext(os.path.basename(src))[0]
for a in actions:
    arm.animation_data.action = a
    if hasattr(arm.animation_data, 'action_slot') and a.slots: arm.animation_data.action_slot = a.slots[0]
    f0, f1 = a.frame_range
    for k in range(4):
        sc.frame_set(int(round(f0 + (f1 - f0) * k / 4)))
        sc.render.filepath = os.path.join(shots, f'{name}_{a.name}_{k}.png')
        bpy.ops.render.render(write_still=True)
print('SHOTS done')
