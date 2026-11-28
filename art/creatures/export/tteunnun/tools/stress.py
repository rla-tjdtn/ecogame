# 극단 자세 검사: blender -b tteunnun.blend --factory-startup -noaudio -P stress.py
# IK·시선 제약을 끄고 관절을 한계까지 꺾은 뒤, 변형된 메시의 모서리 길이가 쉬는 자세 대비 얼마나 늘고 줄었는지 잰다
# (찢어짐/늘어짐 = 모서리가 크게 늘어남, 꺾여 뭉개짐 = 크게 줄어듦). 렌더 몇 장도 남긴다.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Euler
from tt_common import OUT, WORK, look

arm = bpy.data.objects['TteunnunRig']; body = bpy.data.objects['Tteunnun']
arm.animation_data.action = None
for tr in arm.animation_data.nla_tracks:
    tr.mute = True
PB = arm.pose.bones
for pb in PB:
    for c in pb.constraints:
        c.influence = 0.0
me = body.data
E = np.array([e.vertices[:] for e in me.edges])
P0 = np.array([v.co for v in me.vertices])
L0 = np.linalg.norm(P0[E[:, 0]] - P0[E[:, 1]], axis=1)
mat_of_v = np.zeros(len(P0), int)
for p in me.polygons:
    mat_of_v[list(p.vertices)] = p.material_index
mats = [m.name for m in me.materials]
vl = bpy.context.view_layer
S, H, F = ('L', 'R'), ('F', 'B'), ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky')


def reset():
    for pb in PB:
        pb.rotation_mode = 'XYZ'; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)


def R(b, x=0, y=0, z=0):
    if b not in PB:
        return
    PB[b].rotation_euler = Euler([math.radians(v) for v in (x, y, z)])


POSES = {}
POSES['fist'] = lambda: [R('%s%d_%s.%s' % (f, j, h, s), 85 if f != 'Thumb' else 50) for f in F for j in (1, 2, 3) for h in H for s in S]
POSES['finger_back'] = lambda: [R('%s%d_%s.%s' % (f, j, h, s), -35, 0, 12 if j == 1 else 0) for f in F for j in (1, 2, 3) for h in H for s in S]
POSES['elbow_wrist'] = lambda: ([R('LowerArm_%s.%s' % (h, s), 75) for h in H for s in S] + [R('Hand_%s.%s' % (h, s), 60, 0, 35) for h in H for s in S]
                                + [R('UpperArm_%s.%s' % (h, s), -40, 30) for h in H for s in S])
POSES['crouch'] = lambda: ([R('UpperLeg.' + s, 100) for s in S] + [R('LowerLeg.' + s, -125) for s in S] + [R('Foot.' + s, 35) for s in S]
                           + [R('Toes.' + s, 45) for s in S])
POSES['spine_twist'] = lambda: ([R(b, 22, 18, 10) for b in ('Spine1', 'Spine2', 'Spine3')] + [R('Neck', 25, 35, 10), R('Head', 20, 35, -15)])
POSES['eye_lids'] = lambda: [R('Eye', 30, 0, 32), R('EyelidUpper', 56), R('EyelidLower', -20), R('Hook_Up.L', 10), R('Hook_Lo.R', -10)]
out = []
for name, fn in POSES.items():
    reset(); fn(); vl.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg); m2 = ev.to_mesh()
    P = np.array([v.co for v in m2.vertices]); ev.to_mesh_clear()
    L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    r = L / np.maximum(L0, 1e-9)
    line = '%-12s stretch max %.2f p99.9 %.2f | squash min %.2f p0.1 %.2f | edges>1.8: %d  <0.35: %d' % (
        name, r.max(), np.percentile(r, 99.9), r.min(), np.percentile(r, .1), (r > 1.8).sum(), (r < .35).sum())
    worst = E[np.argmax(r)][0]
    line += '  (worst at %s %s)' % (mats[mat_of_v[worst]], np.round(P0[worst], 3))
    print('STRESS', line); out.append(line)
with open(os.path.join(WORK, 'stress.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

# 렌더: 주먹 쥔 손 + 쪼그린 자세 + 비튼 몸
sc = bpy.context.scene
sys.argv = [sys.argv[0]]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview.py'), encoding='utf-8').read().split('cam = stage(sc)')[0])
cam = stage(sc)
sc.render.resolution_x, sc.render.resolution_y = 640, 640
shots = [('fist', (.9, -1.4, 1.95), (0, -.15, 1.9), 45), ('crouch', (2.6, -3.0, 1.2), (0, 0, .7), 45),
         ('spine_twist', (2.4, -3.4, 1.6), (0, 0, 1.3), 45), ('elbow_wrist', (2.4, -3.4, 1.7), (0, 0, 1.6), 45)]
for name, loc, tgt, lens in shots:
    reset(); POSES[name](); vl.update()
    cam.location = loc; look(cam, tgt); cam.data.lens = lens
    sc.render.filepath = os.path.join(WORK, 'stress_' + name + '.png')
    bpy.ops.render.render(write_still=True)
print('STRESS DONE')
