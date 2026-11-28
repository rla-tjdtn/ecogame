# Roblox Studio 용 FBX: blender -b tteunnun.blend -P export_roblox.py
#  - 각막(투명 막) 제거: Roblox 는 재질 투명도를 못 읽어 눈알을 흰 껍데기로 덮는다
#  - 재질은 Roblox 가 읽는 것만: 색 그림·노멀 그림·거칠기 그림 직결(AO 곱하기·SSS·노멀 세기 노드 없음)
#  - 그림은 Roblox 최대 1024 로 줄여 FBX 에 넣고, roblox/ 폴더에도 따로 둔다(SurfaceAppearance 에 직접 넣을 때)
#  - 몸은 그림 없이 단색(몸 텍스처 업로드로 계정이 정지된 적이 있어 몸 그림은 올리지 않는다)
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from tt_common import OUT

RD = os.path.join(OUT, 'roblox'); os.makedirs(RD, exist_ok=True)
arm = bpy.data.objects['TteunnunRig']; body = bpy.data.objects['Tteunnun']; me = body.data
mats = [m.name for m in me.materials]

# 각막 면 지우기
bm = bmesh.new(); bm.from_mesh(me)
ci = [i for i, n in enumerate(mats) if n.startswith('Cornea')]
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in ci], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(me); bm.free()
for i in sorted(ci, reverse=True):
    me.materials.pop(index=i)
print('ROBLOX tris', sum(len(p.vertices) - 2 for p in me.polygons))


def small(name, colorspace):
    """textures/<name>.png 를 1024 로 줄여 roblox/ 에 저장하고 그 그림을 돌려준다."""
    src = os.path.join(OUT, 'textures', name + '.png')
    img = bpy.data.images.load(src)
    if img.size[0] > 1024:
        img.scale(1024, 1024)
    img.filepath_raw = os.path.join(RD, name + '.png'); img.file_format = 'PNG'; img.save()
    img.colorspace_settings.name = colorspace
    return img


def simple(m, prefix):
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); bs = nt.nodes.new('ShaderNodeBsdfPrincipled')
    nt.links.new(bs.outputs[0], out.inputs['Surface'])
    bs.inputs['Metallic'].default_value = 0.0
    if prefix is None:                        # 몸: 단색(회갈색 피부·뼈)
        bs.inputs['Base Color'].default_value = (.30, .27, .24, 1); bs.inputs['Roughness'].default_value = .62
        return
    t = nt.nodes.new('ShaderNodeTexImage'); t.image = small(prefix + '_basecolor', 'sRGB'); nt.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    r = nt.nodes.new('ShaderNodeTexImage'); r.image = small(prefix + '_roughness', 'Non-Color'); nt.links.new(r.outputs['Color'], bs.inputs['Roughness'])
    n = nt.nodes.new('ShaderNodeTexImage'); n.image = small(prefix + '_normal', 'Non-Color')
    nm = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(n.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], bs.inputs['Normal'])


for m in me.materials:
    simple(m, None if m.name.startswith('Body') else ('eye' if m.name.startswith('Eye') else 'pupil'))
    m.surface_render_method = 'DITHERED'

for o in bpy.data.objects:
    o.select_set(o in (arm, body))
bpy.context.view_layer.objects.active = arm
for tr in arm.animation_data.nla_tracks:
    tr.mute = False
fp = os.path.join(OUT, 'tteunnun_roblox.fbx')
bpy.ops.export_scene.fbx(filepath=fp, use_selection=True, object_types={'ARMATURE', 'MESH'},
                         add_leaf_bones=False, use_armature_deform_only=True, bake_anim=True, bake_anim_use_all_actions=True,
                         bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.5,
                         apply_scale_options='FBX_SCALE_ALL', path_mode='COPY', embed_textures=True, mesh_smooth_type='FACE', use_tspace=True)
print('ROBLOX FBX', fp, os.path.getsize(fp))
