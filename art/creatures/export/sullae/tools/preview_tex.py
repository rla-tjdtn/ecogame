# base.blend(또는 sullae.blend) 텍스처 미리보기 + 극단 자세 변형 검사
#   blender -b -P preview_tex.py -- <blend> <out_dir> [pose]
import bpy, sys, os, math
import numpy as np
from mathutils import Quaternion, Vector, Euler
sys.path.insert(0, os.path.dirname(__file__))
import render_util as RU
argv = sys.argv[sys.argv.index('--') + 1:]
blend, out = argv[0], argv[1]; mode = argv[2] if len(argv) > 2 else 'rest'
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
ARM = bpy.data.objects['Sullae']
RU.setup(res=(640, 860))
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('Sullae_')]


def edge_stats(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me0 = ob.data; me1 = ob.evaluated_get(dg).to_mesh()
    e = np.empty(len(me0.edges) * 2, int); me0.edges.foreach_get('vertices', e); e = e.reshape(-1, 2)
    c0 = np.empty(len(me0.vertices) * 3); me0.vertices.foreach_get('co', c0); c0 = c0.reshape(-1, 3)
    c1 = np.empty(len(me1.vertices) * 3); me1.vertices.foreach_get('co', c1); c1 = c1.reshape(-1, 3)
    l0 = np.linalg.norm(c0[e[:, 0]] - c0[e[:, 1]], axis=1); l1 = np.linalg.norm(c1[e[:, 0]] - c1[e[:, 1]], axis=1)
    r = l1 / np.maximum(l0, 1e-7)
    ob.evaluated_get(dg).to_mesh_clear()
    return r


if mode == 'extreme':
    def rot(bn, ax, deg):  # 쉬는 자세 축(아마추어 공간) 기준 회전
        pb = ARM.pose.bones[bn]; R = pb.bone.matrix_local.to_quaternion()
        q = Quaternion(ax, math.radians(deg))
        pb.rotation_quaternion = R.inverted() @ q @ R @ pb.rotation_quaternion
    for s, m in (('L', 1), ('R', -1)):
        for tag in ('F', 'B'):
            for fn in ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky'):
                for j in (1, 2, 3):
                    ARM.pose.bones[f'{fn}{j}_{tag}.{s}'].rotation_quaternion = Quaternion((1, 0, 0), math.radians(95 if j > 1 else 80))
        rot(f'LowerArm_F.{s}', (0, 0, 1), m * 120)
        rot(f'UpperArm_F.{s}', (0, 1, 0), -m * 60)
        rot(f'LowerArm_B.{s}', (1, 0, 0), -110)
        rot(f'Hand_F.{s}', (0, 1, 0), m * 50)
        rot(f'Thigh.{s}', (1, 0, 0), 100)
        rot(f'Shin.{s}', (1, 0, 0), -130)
        rot(f'Foot.{s}', (1, 0, 0), 30)
    rot('Spine2', (1, 0, 0), 30); rot('Spine3', (0, 0, 1), 25); rot('Neck', (1, 0, 0), 35); rot('Head', (0, 1, 0), 25); rot('Jaw', (1, 0, 0), 25)
    rot('Eye.L', (0, 0, 1), 30)
    bpy.context.view_layer.update()
    for o in meshes:
        r = edge_stats(o)
        print(f'STRETCH {o.name}: max {r.max():.2f} min {r.min():.2f} >1.8: {(r > 1.8).sum()} <0.45: {(r < .45).sum()} of {len(r)}')
views = (('front', (0, 0, 1.08), 0, 4.6, .1), ('q34', (0, 0, 1.08), 35, 4.6, .3), ('face', (0, -.06, 1.88), 15, 1.25, .0),
         ('hand', (.78, -.2, 1.38), 20, .8, .25), ('back', (0, 0, 1.08), 160, 4.6, .3), ('torso', (0, 0, 1.12), 25, 1.9, .1))
if mode == 'extreme':
    views = (('front', (0, 0, .95), 20, 4.4, .3), ('side', (0, 0, .95), 90, 4.4, .3), ('hand', (.45, -.25, 1.2), 40, 1.4, .3))
for nm, tgt, yaw, dist, h in views:
    RU.aim(tgt, yaw, dist, h)
    RU.shot(os.path.join(out, f'{mode}_{nm}.png'))
