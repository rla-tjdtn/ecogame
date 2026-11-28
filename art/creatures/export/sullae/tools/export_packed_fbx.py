# 텍스처까지 안에 넣은 통합 FBX 한 파일(sullae_all.fbx) — 모델·재질 텍스처·뼈대·동작 11개
#   blender -b --factory-startup -noaudio -P export_packed_fbx.py -- <out_dir> <dest.fbx>
import bpy, sys, os
argv = sys.argv[sys.argv.index('--') + 1:]
OUT, DEST = argv[0], argv[1]
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'sullae.blend'))
ARM = bpy.data.objects['Sullae']
for tr in ARM.animation_data.nla_tracks: tr.mute = True
keep = {'Sullae', 'Sullae_Body', 'Sullae_Eyes', 'Sullae_Nails'}
for o in bpy.data.objects: o.select_set(o.name in keep)
bpy.context.view_layer.objects.active = ARM
ARM.animation_data.action = bpy.data.actions['Idle']; ARM.animation_data.action_slot = bpy.data.actions['Idle'].slots[0]
bpy.ops.export_scene.fbx(filepath=DEST, use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False, use_armature_deform_only=True,
                         bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
                         bake_anim_step=1.0, bake_anim_simplify_factor=0.0, path_mode='COPY', embed_textures=True,
                         mesh_smooth_type='FACE', use_tspace=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL')
print('PACKED FBX', os.path.getsize(DEST))
