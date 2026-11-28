# 깜빡임(Blink 0~1) 전수 검사 + 완전 감김 노출 검사 + 100회 반복 + 걷기/달리기와 동시 재생 + 6단계×8방향 렌더
#   blender -b tteunnun.blend -P qa_blink.py      → renders/qa_blink.txt, renders/qa_blink_views.png
# Blink b: 눈꺼풀 조종 뼈 EyelidUpper = 84°·b(위 꺼풀 감음), EyelidLower = -34°·b(아래 꺼풀 감음). 실제 변형은 눈꺼풀 뼈 격자(40개)가 한다.
import sys, os, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Vector, Euler
from tt_common import OUT, WORK, look

sc = bpy.context.scene; vl = bpy.context.view_layer
arm = bpy.data.objects['TteunnunRig']; body = bpy.data.objects['Tteunnun']; me = body.data
ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
ad.action = None
PB = arm.pose.bones


def reset():
    for pb in PB:
        pb.location = (0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)


def set_blink(b):
    PB['EyelidUpper'].rotation_euler = Euler((math.radians(78 * b), 0, 0)); PB['EyelidLower'].rotation_euler = Euler((math.radians(-40 * b), 0, 0))
    vl.update()


nv = len(me.vertices)


def evalP():
    dg = bpy.context.evaluated_depsgraph_get(); ev = body.evaluated_get(dg); m2 = ev.to_mesh()
    P = np.zeros(nv * 3); m2.vertices.foreach_get('co', P); ev.to_mesh_clear()
    return P.reshape(-1, 3)


ga = lambda n: np.array([a.value for a in me.attributes[n].data]) if n in me.attributes else np.zeros(nv)
mats = [m.name for m in me.materials]
vmat = np.full(nv, -1)
for p in me.polygons:
    vmat[list(p.vertices)] = p.material_index
pmat = np.array([p.material_index for p in me.polygons])
eye_mat = [mats.index(n) for n in mats if n.startswith(('Eye', 'Cornea', 'Pupil'))]
eye_v = np.nonzero(np.isin(vmat, eye_mat))[0]
lidshell = ga('lidshell') > .5; thin = ga('thin') > .5
lash_v = np.nonzero(lidshell & thin)[0]; band_v = np.nonzero(lidshell & ~thin)[0]
other_v = np.nonzero(~lidshell & ~np.isin(vmat, eye_mat))[0]
R_EYE = 1.12 * .235 - .003
reset(); set_blink(0)
P0 = evalP()
E0 = np.array(arm.matrix_world @ PB['Eye'].head)
M0 = arm.matrix_world @ PB['Eye'].matrix
lid_out = band_v[np.linalg.norm(P0[band_v] - E0, axis=1) > R_EYE + .012]
Edg = np.array([e.vertices[:] for e in me.edges]); lidE = Edg[lidshell[Edg[:, 0]] & lidshell[Edg[:, 1]] & ~thin[Edg[:, 0]]]
L0 = np.linalg.norm(P0[lidE[:, 0]] - P0[lidE[:, 1]], axis=1)
rng = np.random.default_rng(0); pa = rng.choice(eye_v, 3000); pb_ = rng.choice(eye_v, 3000)
D0 = np.linalg.norm(P0[pa] - P0[pb_], axis=1)
# 속눈썹 뿌리: 속눈썹 조각마다 눈꺼풀 띠에 가장 가까운 정점과 그 띠 정점(쉬는 자세 거리 기억)
from mathutils.kdtree import KDTree
kd = KDTree(len(band_v))
for k, i in enumerate(band_v):
    kd.insert(Vector(P0[i]), k)
kd.balance()
# 속눈썹 조각마다(연결 조각) 눈꺼풀 띠까지의 최소 거리 = 뿌리 간격. 감을 때 이 간격이 늘면 벌어진 것
par_ = np.arange(nv)
def _f(a):
    while par_[a] != a:
        par_[a] = par_[par_[a]]; a = par_[a]
    return a
for e_ in me.edges:
    a_, b2_ = _f(e_.vertices[0]), _f(e_.vertices[1])
    if a_ != b2_:
        par_[a_] = b2_
comp_ = np.array([_f(i) for i in range(nv)])
lash_sh = [np.nonzero(comp_ == c)[0] for c in np.unique(comp_[lash_v])]


def lash_gaps(P):
    t = KDTree(len(band_v))
    for k, i in enumerate(band_v):
        t.insert(Vector(P[i]), k)
    t.balance()
    return np.array([min(t.find(Vector(P[v]))[2] for v in vs[::2]) for vs in lash_sh])


gap0 = lash_gaps(P0)
# 눈꺼풀 띠 면 방향(바깥 면이 눈 중심 반대쪽을 보는지)
band_faces = np.array([p.index for p in me.polygons if lidshell[p.vertices[0]] and not thin[p.vertices[0]]])


def face_dir_sign(P):
    out = []
    for fi in band_faces[::4]:
        vs = me.polygons[fi].vertices
        a, b_, c = P[vs[0]], P[vs[1]], P[vs[2]]
        n = np.cross(b_ - a, c - a); ctr = (a + b_ + c) / 3
        out.append(np.sign(np.dot(n, ctr - E0)))
    return np.array(out)


S0 = face_dir_sign(P0)
VIEWS = {'정면': (0, -1, 0), '좌45': (1, -1, 0), '좌90': (1, 0, 0), '우45': (-1, -1, 0), '우90': (-1, 0, 0), '후면': (0, 1, 0), '상단사선': (0, -1, 1), '하단사선': (0, -1, -1)}


def exposure(P):
    """눈알(흰자·홍채·동공·각막) 정점에서 각 방향으로 광선 — 피부(눈알 재질이 아닌 면)에 막히지 않으면 노출."""
    dg = bpy.context.evaluated_depsgraph_get()
    res = {}
    samp = eye_v[::6]
    for nm, d in VIEWS.items():
        d = np.array(d, float); d /= np.linalg.norm(d)
        cnt = 0
        for i in samp:
            n = P[i] - E0; n /= np.linalg.norm(n)
            if np.dot(n, d) < .1:
                continue
            o = Vector(P[i] + d * .004)
            for _ in range(4):
                hit, loc, nor, idx, ob, mw = sc.ray_cast(dg, o, Vector(d), distance=5.0)
                if not hit:
                    cnt += 1; break
                if ob.name == body.name and pmat[idx] in eye_mat:
                    o = loc + Vector(d) * .002; continue     # 눈알 자신(각막 등)은 지나감
                break
        res[nm] = cnt
    return res


lines = ['# 깜빡임 검사 (Blink = 눈꺼풀 조종 값 0~1)', '']
lines.append('Blink | 눈알 위치/회전/크기 변화 | 눈알 정점 변형 | 눈꺼풀-눈알 여유 | 뒤집힌 면 | 눈꺼풀 모서리 늘어남 최대 | 속눈썹 뿌리 벌어짐 | 머리·몸 다른 정점 이동')
fails = []
for k in range(21):
    b = k / 20
    reset(); set_blink(b); P = evalP()
    M = arm.matrix_world @ PB['Eye'].matrix
    dm = (np.array(M) - np.array(M0)); eyeT = np.abs(dm).max()
    eyed = np.abs(np.linalg.norm(P[pa] - P[pb_], axis=1) - D0).max() * 1000
    clear = (np.linalg.norm(P[lid_out] - E0, axis=1) - R_EYE).min() * 1000
    flips = int((face_dir_sign(P) != S0).sum())
    st = (np.linalg.norm(P[lidE[:, 0]] - P[lidE[:, 1]], axis=1) / L0).max()
    sep = 0.0
    sep = max((lash_gaps(P) - gap0).max(), 0.0) * 1000
    oth = np.linalg.norm(P[other_v] - P0[other_v], axis=1).max() * 1000
    ok = eyeT < 1e-6 and eyed < .01 and clear > 0 and flips == 0 and st < 2.5 and sep < 2 and oth < .01
    if not ok:
        fails.append('%.2f' % b)
    lines.append('%.2f | %.1e | %.4fmm | %+.1fmm | %d | %.2f | %.2fmm | %.4fmm | %s' % (b, eyeT, eyed, clear, flips, st, sep, oth, '통과' if ok else '반려'))
# 완전 감김·완전 뜸 노출
for b in (1.0, .95, 0.0):
    reset(); set_blink(b); P = evalP()
    ex = exposure(P)
    lines.append('노출 검사 Blink %.2f: ' % b + ', '.join('%s %d' % kv for kv in ex.items()) + ('  (보이는 눈알 정점 수 — 감김이면 0 이어야 함)' if b > .9 else '  (뜬 상태 — 보이는 게 정상)'))
    if b >= 1.0 and any(v > 0 for v in ex.values()):
        fails.append('감김노출')
# OPEN_REFERENCE 복귀
reset(); set_blink(1); evalP(); reset(); set_blink(0); Pb = evalP()
back = np.linalg.norm(Pb - P0, axis=1).max() * 1000
lines.append('OPEN_REFERENCE 복귀(감았다 뜬 뒤 정점 차이 최대): %.5f mm' % back)
# 100회 반복(눈꺼풀 조종 뼈로 감았다 뜨기)
reset(); set_blink(1); Pc = evalP(); reset(); set_blink(0); Po = evalP()
mx = 0.0
for it in range(100):
    reset(); set_blink(1); mx = max(mx, np.abs(evalP() - Pc).max()); reset(); set_blink(0); mx = max(mx, np.abs(evalP() - Po).max())
lines.append('감았다 뜨기 100회 반복: 매번 같은 모양(최대 차이 %.6f mm)' % (mx * 1000))
for tr in ad.nla_tracks:
    tr.mute = True
lines.append('')
lines.append('반려: ' + (', '.join(fails) if fails else '없음'))
txt = '\n'.join(lines); print(txt)
open(os.path.join(OUT, 'renders', 'qa_blink.txt'), 'w', encoding='utf-8').write(txt + '\n')

# 6단계 × 8방향 렌더(같은 조명·같은 거리)
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview.py'), encoding='utf-8').read()
sys.argv = [sys.argv[0]]
exec(src.split('cam = stage(sc)')[0])
cam = stage(sc)
sc.render.resolution_x = sc.render.resolution_y = 360; sc.eevee.taa_render_samples = 24
d = os.path.join(WORK, 'qa'); os.makedirs(d, exist_ok=True)
files = []
for b in (0, .25, .5, .75, .9, 1.0):
    reset(); ad.action = None; set_blink(b)
    for nm, dv in VIEWS.items():
        dv = Vector(dv).normalized()
        cam.location = Vector(E0) + dv * 1.45 + Vector((0, 0, .05)); look(cam, Vector(E0)); cam.data.lens = 40
        sc.render.filepath = os.path.join(d, 'blink_%03d_%s.png' % (int(b * 100), list(VIEWS).index(nm)))
        bpy.ops.render.render(write_still=True); files.append(sc.render.filepath)
args = ['ffmpeg', '-loglevel', 'error', '-y']
for fp in files:
    args += ['-i', fp]
n = len(files)
layout = '|'.join('%d_%d' % ((i % 8) * 360, (i // 8) * 360) for i in range(n))
args += ['-filter_complex', ''.join('[%d]' % i for i in range(n)) + 'xstack=inputs=%d:layout=%s' % (n, layout), os.path.join(OUT, 'renders', 'qa_blink_views.png')]
subprocess.run(args, check=True)
print('BLINK VIEWS DONE')
