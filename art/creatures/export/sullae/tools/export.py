# 4단계: sullae.blend → sullae.fbx / sullae.glb (애니메이션·텍스처 포함)
#   blender -b --factory-startup -noaudio -P export.py -- <out_dir>
import bpy, sys, os
argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'sullae.blend'))
ARM = bpy.data.objects['Sullae']
for tr in ARM.animation_data.nla_tracks: tr.mute = True
keep = {'Sullae', 'Sullae_Body', 'Sullae_Cloth', 'Sullae_Eyes', 'Sullae_Nails'}
for o in bpy.data.objects:
    o.select_set(o.name in keep)
bpy.context.view_layer.objects.active = ARM
ARM.animation_data.action = bpy.data.actions['Idle']; ARM.animation_data.action_slot = bpy.data.actions['Idle'].slots[0]
bpy.context.scene.frame_set(0)

bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'sullae.glb'), export_format='GLB', use_selection=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_def_bones=True, export_force_sampling=True,
                          export_optimize_animation_size=False, export_anim_slide_to_zero=True,
                          export_image_format=os.environ.get('GLB_IMG', 'JPEG'), export_image_quality=90, export_skins=True, export_all_influences=False,
                          export_morph=False, export_yup=True, export_apply=False)
print('GLB written')
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, 'sullae.fbx'), use_selection=True, object_types={'ARMATURE', 'MESH'},
                         add_leaf_bones=False, use_armature_deform_only=True, primary_bone_axis='Y', secondary_bone_axis='X',
                         bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
                         bake_anim_step=1.0, bake_anim_simplify_factor=0.0, path_mode='RELATIVE', embed_textures=False,
                         mesh_smooth_type='FACE', use_tspace=True, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL')
print('FBX written')
