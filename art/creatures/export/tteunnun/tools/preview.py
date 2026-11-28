# 미리보기: blender -b work/xxx.blend -P preview.py -- out_prefix [flat]
#   flat 이면 재질마다 단색으로 칠해 형태만 본다. 앞/옆/3-4/머리 가까이 4장 렌더(EEVEE, 소리 없음).
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from tt_common import look

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
pref = argv[0] if argv else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'work', 'pv')
flat = 'flat' in argv
sc = bpy.context.scene
COL = {'Skin': (.55, .58, .5, 1), 'Cloth': (.12, .11, .1, 1), 'Metal': (.35, .2, .1, 1), 'Eye': (.9, .85, .8, 1),
       'Pupil': (0, 0, 0, 1), 'Cornea': (.8, .9, 1, 1), 'Lash': (.05, .04, .03, 1)}
if flat:
    for m in bpy.data.materials:
        m.use_nodes = True
        nt = m.node_tree; nt.nodes.clear()
        b = nt.nodes.new("ShaderNodeBsdfPrincipled"); o = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(b.outputs[0], o.inputs[0])
        if m.name in COL:
            b.inputs['Base Color'].default_value = COL[m.name]
            if m.name == 'Cornea':
                b.inputs['Alpha'].default_value = .15
                m.surface_render_method = 'BLENDED'


def realistic(sc):
    """실사 렌더(REAL=1): Cycles GPU 경로 추적 + 잡티 제거, 렌더 때만 매끈하게(Subdivision 1), 각막은 진짜 굴절."""
    from tt_common import setup_gpu
    sc.render.engine = 'CYCLES'; setup_gpu()
    sc.cycles.samples = int(os.environ.get('SPP', 96)); sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPTIX'
    except Exception:
        pass
    sc.cycles.max_bounces = 8; sc.cycles.transmission_bounces = 8; sc.cycles.transparent_max_bounces = 8
    try:
        sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Punchy'
    except Exception as ex:
        print('look', ex)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name not in ('Floor',) and not any(m.type == 'SUBSURF' for m in o.modifiers) and len(o.data.polygons) > 3000:
            m = o.modifiers.new('RenderSmooth', 'SUBSURF'); m.levels = 0; m.render_levels = 1
    for mt in bpy.data.materials:
        if mt.name.startswith('Cornea') and mt.node_tree:
            for n in mt.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    n.inputs['Alpha'].default_value = 1.0; n.inputs['Transmission Weight'].default_value = 1.0
                    n.inputs['Roughness'].default_value = 0.0; n.inputs['Base Color'].default_value = (1, 1, 1, 1)
            mt.surface_render_method = 'DITHERED'
        # 몸: 골에 AO 를 곱해 깊이감, 노멀 세기 올림(렌더 때만 — 파일의 재질은 glTF 그대로)
        if mt.name.startswith('Body') and mt.node_tree:
            nt = mt.node_tree; pr = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
            tex = {n.image.name.split('.')[0]: n for n in nt.nodes if n.type == 'TEX_IMAGE' and n.image}
            ao = next((n for k, n in tex.items() if k.endswith('_ao')), None)
            bc = next((n for k, n in tex.items() if k.endswith('_basecolor')), None)
            if ao and bc:
                mx = nt.nodes.new('ShaderNodeMix'); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'
                mx.inputs[0].default_value = .55
                nt.links.new(bc.outputs['Color'], mx.inputs[6]); nt.links.new(ao.outputs['Color'], mx.inputs[7])
                nt.links.new(mx.outputs[2], pr.inputs['Base Color'])
            for n in nt.nodes:
                if n.type == 'NORMAL_MAP':
                    n.inputs['Strength'].default_value = 1.6
            pr.inputs['Subsurface Weight'].default_value = .15
    # 조명: 따뜻한 키 라이트(깊은 그림자), 차가운 강한 림, 어두운 주변
    for nm, en, col, sz in (('Key', 250, (1, .86, .72), .6), ('Rim', 520, (.62, .74, 1), .4), ('Fill', 12, (.8, .85, 1), 3.0)):
        lo = bpy.data.objects.get(nm)
        if lo:
            lo.data.energy = en; lo.data.color = col; lo.data.size = sz
    if sc.world and sc.world.node_tree:
        sc.world.node_tree.nodes['Background'].inputs[1].default_value = .35
    fl = bpy.data.objects.get('Floor')
    if fl and fl.data.materials:
        b = fl.data.materials[0].node_tree.nodes.get('Principled BSDF')
        if b:
            b.inputs['Roughness'].default_value = .85; b.inputs['Base Color'].default_value = (.03, .028, .026, 1)


def stage(sc):
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x, sc.render.resolution_y = 900, 1200
    sc.render.film_transparent = False
    w = bpy.data.worlds.new('W') if not sc.world else sc.world
    sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (.012, .013, .018, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
    if not bpy.data.objects.get('Floor'):
        bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0)); fl = bpy.context.active_object; fl.name = 'Floor'
        fm = bpy.data.materials.new('FloorMat'); fm.use_nodes = True
        fm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.05, .045, .04, 1)
        fm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .7
        fl.data.materials.append(fm)
    for nm, loc, en, col, sz in (("Key", (1.2, -2.6, 3.6), 180, (1, .9, .78), .8), ("Rim", (-1.8, 2.2, 2.8), 160, (.6, .75, 1), .5),
                                 ("Fill", (-2.5, -2.0, 1.4), 20, (.8, .85, 1), 2.0)):
        if bpy.data.objects.get(nm):
            continue
        ld = bpy.data.lights.new(nm, 'AREA'); ld.energy = en; ld.color = col; ld.size = sz
        lo = bpy.data.objects.new(nm, ld); sc.collection.objects.link(lo); lo.location = loc
        look(lo, (0, 0, 1.4))
    if not bpy.data.objects.get('Cam'):
        cd = bpy.data.cameras.new('Cam'); cd.lens = 50
        cam = bpy.data.objects.new('Cam', cd); sc.collection.objects.link(cam); sc.camera = cam
    return bpy.data.objects['Cam']


cam = stage(sc)
if os.environ.get('REAL'):
    realistic(sc)
import numpy as _np
_P = _np.array([o.matrix_world @ v.co for o in bpy.data.objects if o.type == 'MESH' and o.name not in ('Floor',) for v in list(o.data.vertices)[::7]])
_H = float(_P[:, 2].max())
_eo = bpy.data.objects.get('Eyeball')
_ez = float(_np.array([v.co for v in _eo.data.vertices]).mean(0)[2]) if _eo else 1.99
views = [('front', (0, -5.6, _H * .55), (0, 0, _H * .5), 50), ('side', (5.6, 0, _H * .55), (0, 0, _H * .5), 50),
         ('34', (3.4, -4.3, _H * .7), (0, 0, _H * .52), 50), ('back', (-2.6, 3.4, _H * .8), (0, 0, _H * .6), 50), ('head', (.75, -1.55, _ez + .1), (0, -.08, _ez - .02), 50)]
for nm, loc, tgt, lens in views:
    cam.location = loc; look(cam, tgt); cam.data.lens = lens
    sc.render.filepath = pref + '_' + nm + '.png'
    bpy.ops.render.render(write_still=True)
print('PREVIEW DONE')
