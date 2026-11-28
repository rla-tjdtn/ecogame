# Roblox 전용 파일 만들기(업로드는 하지 않는다 — 파일로만)
#   blender -b --factory-startup -noaudio -P export_roblox.py -- <sullae_dir> <dest_dir>
# - 메시 하나당 삼각형 2만 개 제한 → 몸을 머리 / 팔 / 몸통·다리로 나눈다(넘으면 그 조각만 줄인다)
# - 정점당 뼈 영향 4개(이미 제한됨)
# - SurfaceAppearance 용 1024 텍스처: ColorMap(= baseColor × AO, Roblox 는 AO 맵이 없다), NormalMap(OpenGL), RoughnessMap, MetalnessMap
# - 리그 FBX 1개(메시+뼈대, 텍스처 포함) + 동작별 FBX(뼈대만, 테이크 1개) — 애니메이션 에디터는 FBX 하나에 동작 하나만 가져온다
import bpy, bmesh, sys, os, math
import numpy as np

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, DEST = argv[0], argv[1]
TEXD = os.path.join(DEST, 'textures'); ANIMD = os.path.join(DEST, 'animations')
for d in (DEST, TEXD, ANIMD): os.makedirs(d, exist_ok=True)
MAX_TRIS = 19800
bpy.ops.wm.open_mainfile(filepath=os.path.join(SRC, 'sullae.blend'))
ARM = bpy.data.objects['Sullae']
for tr in ARM.animation_data.nla_tracks: tr.mute = True
for o in list(bpy.data.objects):
    if o.name.endswith('Hi') or o.name == 'WeightProxy':
        bpy.data.objects.remove(o)


def log(*a): print('[roblox]', *a, flush=True)


# ---------------------------------------------------------------- 1. 텍스처 1024 변환
def load_np(path, size=1024):
    im = bpy.data.images.load(path)
    if im.size[0] != size: im.scale(size, size)
    a = np.array(im.pixels[:], dtype=np.float32).reshape(size, size, 4)
    bpy.data.images.remove(im)
    return a


def save_np(a, path, non_color=False):
    size = a.shape[0]
    im = bpy.data.images.new(os.path.basename(path), size, size, alpha=False)
    if non_color: im.colorspace_settings.name = 'Non-Color'
    im.pixels[:] = a.ravel(); im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    return im


TEX = {}
for key in ('skin', 'eye', 'nail'):
    src = lambda suf: os.path.join(SRC, 'textures', f'sullae_{key}_{suf}.png')
    bc = load_np(src('baseColor')); ao = load_np(src('ao'))
    col = bc.copy(); col[..., :3] = bc[..., :3] * (.35 + .65 * ao[..., :1])  # AO 를 색에 섞는다(너무 새까맣지 않게 65%)
    col[..., 3] = 1
    nm = load_np(src('normal')); rg = load_np(src('roughness'))
    met = np.zeros_like(rg); met[..., 3] = 1
    TEX[key] = dict(
        color=save_np(col, os.path.join(TEXD, f'sullae_{key}_ColorMap.png')),
        normal=save_np(nm, os.path.join(TEXD, f'sullae_{key}_NormalMap.png'), True),
        rough=save_np(rg, os.path.join(TEXD, f'sullae_{key}_RoughnessMap.png'), True),
        metal=save_np(met, os.path.join(TEXD, f'sullae_{key}_MetalnessMap.png'), True))
    log('textures', key)


def rbx_material(key):
    mt = bpy.data.materials.new(f'Sullae_{key}'); mt.use_nodes = True; nt = mt.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new('ShaderNodeOutputMaterial'); bs = nt.nodes.new('ShaderNodeBsdfPrincipled'); nt.links.new(bs.outputs[0], out.inputs[0])
    def tex(im):
        n = nt.nodes.new('ShaderNodeTexImage'); n.image = im; return n
    nt.links.new(tex(TEX[key]['color']).outputs[0], bs.inputs['Base Color'])
    nt.links.new(tex(TEX[key]['rough']).outputs[0], bs.inputs['Roughness'])
    nt.links.new(tex(TEX[key]['metal']).outputs[0], bs.inputs['Metallic'])
    nm = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(tex(TEX[key]['normal']).outputs[0], nm.inputs['Color']); nt.links.new(nm.outputs[0], bs.inputs['Normal'])
    return mt


# ---------------------------------------------------------------- 2. 몸을 2만 삼각형 이하 조각으로
BODY = bpy.data.objects['Sullae_Body']
vg_name = {g.index: g.name for g in BODY.vertex_groups}


def part_of(bone):
    if bone in ('Head', 'Neck', 'Jaw') or bone.startswith('Eye'): return 'Head'
    if any(bone.startswith(p) for p in ('Shoulder_', 'UpperArm_', 'LowerArm_', 'Hand_', 'Thumb', 'Index', 'Middle', 'Ring', 'Pinky')):
        return 'Arms_F' if '_F.' in bone else 'Arms_B'
    return 'Torso'


me = BODY.data
dom = []
for v in me.vertices:
    best = max(v.groups, key=lambda g: g.weight, default=None)
    dom.append(part_of(vg_name[best.group]) if best else 'Torso')
face_part = []
for p in me.polygons:
    cnt = {}
    for vi in p.vertices: cnt[dom[vi]] = cnt.get(dom[vi], 0) + 1
    face_part.append(max(cnt, key=cnt.get))
parts = sorted(set(face_part))
skin_mat = rbx_material('skin')
PIECES = []
for part in parts:
    ob = BODY.copy(); ob.data = me.copy(); bpy.context.scene.collection.objects.link(ob); ob.name = f'Sullae_{part}'
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f, fp in zip(bm.faces, face_part) if fp != part], context='FACES')
    bm.to_mesh(ob.data); bm.free()
    n = len(ob.data.polygons)
    if n > MAX_TRIS:
        md = ob.modifiers.new('dec', 'DECIMATE'); md.ratio = MAX_TRIS / n
        bpy.context.view_layer.objects.active = ob
        for m in list(ob.modifiers):
            if m.type == 'ARMATURE': ob.modifiers.remove(m)
        dg = bpy.context.evaluated_depsgraph_get(); nm_ = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear(); old = ob.data; ob.data = nm_; bpy.data.meshes.remove(old)
        a = ob.modifiers.new('Armature', 'ARMATURE'); a.object = ARM
        log('decimated', part, n, '->', len(ob.data.polygons))
    ob.data.materials.clear(); ob.data.materials.append(skin_mat)
    ob.data.name = ob.name
    PIECES.append(ob)
    log('piece', ob.name, len(ob.data.polygons), 'tris')
bpy.data.objects.remove(BODY)
EYES = bpy.data.objects['Sullae_Eyes']; NAILS = bpy.data.objects['Sullae_Nails']
EYES.data.materials.clear(); EYES.data.materials.append(rbx_material('eye'))
NAILS.data.materials.clear(); NAILS.data.materials.append(rbx_material('nail'))
MESHES = PIECES + [EYES, NAILS]
for o in MESHES:
    assert len(o.data.polygons) <= 20000, o.name
    for v in o.data.vertices:
        assert len([g for g in v.groups if g.weight > 1e-4]) <= 4

# ---------------------------------------------------------------- 3. 리그 FBX(메시+뼈대+텍스처)
def select_only(objs):
    for o in bpy.data.objects: o.select_set(o in objs)
    bpy.context.view_layer.objects.active = ARM


ARM.animation_data.action = None
for pb in ARM.pose.bones:
    pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
select_only([ARM] + MESHES)
COMMON = dict(object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False, use_armature_deform_only=True, primary_bone_axis='Y', secondary_bone_axis='X',
              apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', use_tspace=True)
bpy.ops.export_scene.fbx(filepath=os.path.join(DEST, 'sullae_roblox_rig.fbx'), use_selection=True, bake_anim=False,
                         path_mode='COPY', embed_textures=True, **COMMON)
log('rig fbx written')

# ---------------------------------------------------------------- 4. 동작별 FBX(뼈대만, 테이크 1개)
select_only([ARM])
CLIPS = []
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    if not act.slots: continue
    ARM.animation_data.action = act; ARM.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = f0, f1
    path = os.path.join(ANIMD, f'sullae_{act.name}.fbx')
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_force_startend_keying=True, bake_anim_step=1.0, bake_anim_simplify_factor=0.0, path_mode='AUTO', **COMMON)
    CLIPS.append((act.name, f1 - f0, bool(act.use_cyclic)))
    log('anim', act.name, f1 - f0)
with open(os.path.join(DEST, 'clips.txt'), 'w', encoding='utf-8') as fh:
    for n, fr, loop in CLIPS:
        fh.write(f'{n}\t{fr} frames @30fps = {fr / 30:.2f}s\t{"Looped=true" if loop else "Looped=false"}\n')
log('DONE', len(CLIPS), 'clips')
