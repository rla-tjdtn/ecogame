# 눈 QA: 모든 동작의 모든 프레임에서 눈꺼풀·눈알을 자동 검사한다.  blender -b tteunnun.blend -P qa_eyes.py
#  - 눈알 변형: 흰자·홍채·동공·각막 정점 사이 거리가 쉬는 자세와 같은지(최대 변화 mm). 동공 원판은 Pupil 뼈 스케일만 허용(따로 잼)
#  - 눈꺼풀 관통: 눈꺼풀 띠의 바깥 면·말린 가장자리가 눈알 표면 밖에 있는지(최소 여유 mm, 음수면 관통)
#  - 찢어짐·늘어짐: 눈 둘레(눈 중심 0.45m 안) 모서리 길이 비(최대·99.9%)
#  - Roblox 스키닝 규칙: 정점당 뼈 영향 4개 이하, 셰이프 키 없음
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from tt_common import OUT, WORK

sc = bpy.context.scene; vl = bpy.context.view_layer
arm = bpy.data.objects['TteunnunRig']; body = bpy.data.objects['Tteunnun']
me = body.data
ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
nv = len(me.vertices)
R0 = np.zeros(nv * 3); me.vertices.foreach_get('co', R0); R0 = R0.reshape(-1, 3)
E0 = np.array(arm.data.bones['Eye'].head_local)
R_EYE = 1.12 * .235 - .003
mats = [m.name for m in me.materials]
pm = np.zeros(len(me.polygons), int); me.polygons.foreach_get('material_index', pm)
vmat = np.full(nv, -1)
for p in me.polygons:
    vmat[list(p.vertices)] = p.material_index
eye_v = np.nonzero(np.isin(vmat, [mats.index(n) for n in mats if n.startswith(('Eye', 'Cornea'))]))[0]
ga = lambda n: np.array([a.value for a in me.attributes[n].data]) if n in me.attributes else np.zeros(nv)
lidshell = ga('lidshell') > .5
dist0 = np.linalg.norm(R0 - E0, axis=1)
lid_out = np.nonzero(lidshell & (dist0 > R_EYE + .012) & (ga('thin') < .5))[0]      # 바깥 면·가장자리(속눈썹 제외)
E = np.array([e.vertices[:] for e in me.edges])
near = (np.linalg.norm(R0 - E0, axis=1) < .45) & (ga('armpart') < .5) & ~np.isin(vmat, [mats.index(n) for n in mats if n.startswith('Pupil')])   # (동공 원판은 Pupil 뼈 크기 조절이 정상)   # 눈·머리·눈꺼풀(팔·손은 따로: stress.py)
Ek = E[near[E[:, 0]] & near[E[:, 1]]]
L0 = np.linalg.norm(R0[Ek[:, 0]] - R0[Ek[:, 1]], axis=1)
# 눈알 강체 검사용: 눈알 정점에서 고른 점 쌍
rng = np.random.default_rng(0)
pa = rng.choice(eye_v, 4000); pb = rng.choice(eye_v, 4000)
D0 = np.linalg.norm(R0[pa] - R0[pb], axis=1)
# Roblox 규칙
maxinf = max(len([g for g in v.groups if g.weight > 1e-4]) for v in me.vertices)
lines = ['정점당 최대 뼈 영향: %d (Roblox 4 이하)' % maxinf, '셰이프 키: %s' % ('없음' if not me.shape_keys else '있음(!)'),
         '변형 뼈: %d' % len([b for b in arm.data.bones if b.use_deform])]
fails = []
for act in sorted(bpy.data.actions, key=lambda a: a.name):
    if act.name not in [t.name for t in ad.nla_tracks]:
        continue
    for _pb in arm.pose.bones:
        _pb.location = (0, 0, 0); _pb.rotation_euler = (0, 0, 0); _pb.rotation_quaternion = (1, 0, 0, 0); _pb.scale = (1, 1, 1)
    ad.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    worst = dict(stretch=0, p999=0, eye=0, clear=9, sf=0, cf=0)
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); m2 = ev.to_mesh()
        P = np.zeros(nv * 3); m2.vertices.foreach_get('co', P); P = P.reshape(-1, 3); ev.to_mesh_clear()
        Ep = np.array((arm.matrix_world @ arm.pose.bones['Eye'].head))
        L = np.linalg.norm(P[Ek[:, 0]] - P[Ek[:, 1]], axis=1); r = L / np.maximum(L0, 1e-9)
        eyed = np.abs(np.linalg.norm(P[pa] - P[pb], axis=1) - D0).max() * 1000
        clear = (np.linalg.norm(P[lid_out] - Ep, axis=1) - R_EYE).min() * 1000
        if r.max() > worst['stretch']:
            worst['stretch'], worst['sf'] = r.max(), f
        worst['p999'] = max(worst['p999'], np.percentile(r, 99.9))
        worst['eye'] = max(worst['eye'], eyed)
        if clear < worst['clear']:
            worst['clear'], worst['cf'] = clear, f
    ok = worst['stretch'] < 2.5 and worst['eye'] < 0.5 and worst['clear'] > 0   # 2.5 넘게 늘어나면 찢어짐·텍스처 왜곡으로 반려
    if not ok:
        fails.append(act.name)
    lines.append('%-11s 프레임 %3d  모서리 늘어남 최대 %.2f(f%d) 99.9%% %.2f | 눈알 변형 %.3fmm | 눈꺼풀-눈알 여유 최소 %+.1fmm(f%d)  %s' % (
        act.name, f1 - f0 + 1, worst['stretch'], worst['sf'], worst['p999'], worst['eye'], worst['clear'], worst['cf'], '통과' if ok else '반려'))
lines.append('반려: ' + (', '.join(fails) if fails else '없음'))
txt = '\n'.join(lines)
print(txt)
open(os.path.join(OUT, 'renders', 'qa_eyes.txt'), 'w', encoding='utf-8').write(txt + '\n')
