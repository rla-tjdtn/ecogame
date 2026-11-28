# 뜬눈(k10h1) — 시안 형태 메시(retex.py 결과)에 이름 붙인 뼈대 + 웨이트.  work/retexA.blend → work/stageB.blend
#   blender -b work/retexA.blend --factory-startup -noaudio -P rig.py
# 뼈 자리: 시안 도형(design_dump.js → work/design_prims.json)의 관절(손가락 마디 공, 팔 관 끝, 다리·척추 좌표)에서 직접.
# 웨이트: 메시의 연결 조각(껍질)마다 가장 가까운 시안 그룹을 찾아 그 그룹의 뼈들로만 bone heat 자동 웨이트,
#         눈꺼풀 관·속눈썹은 눈꺼풀 뼈에 고정, 갈고리는 머리→갈고리 뼈로 길이를 따라 섞음, 실패한 정점은 거리식으로 메움.
import sys, os, math, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Vector
from tt_common import *

S = 0.235
sc = bpy.context.scene; vl = bpy.context.view_layer
G = json.load(open(os.path.join(WORK, 'design_prims.json')))


def W(p):
    """시안 좌표 → Blender 미터."""
    p = np.asarray(p, float)
    return np.array([p[0], -p[2], p[1]]) * S


def segs(g):
    return [(W(p['a']), W(p['b'])) for p in g['prims'] if not p['op'] and p['t'] == 0 and np.linalg.norm(np.subtract(p['a'], p['b'])) > 1e-4]


def balls(g):
    return [W(p['a']) for p in g['prims'] if not p['op'] and p['t'] == 0 and np.linalg.norm(np.subtract(p['a'], p['b'])) <= 1e-4]


def gpts(g):
    out = []
    for p in g['prims']:
        if p['op']:
            continue
        out.append(W(p['a']))
        if p['t'] == 0:
            out.append(W(p['b']))
    return np.array(out)


SIDE = lambda m: '.L' if m > 0 else '.R'
BONES = {}


def bone(name, head, tail, up, parent, deform=True):
    BONES[name] = (np.asarray(head, float), np.asarray(tail, float), nrm(up), parent, deform)


GB = {}          # 시안 그룹 번호 → 뼈 목록(자동 웨이트) 또는 ('fix', 그룹), ('hook', 뼈)
E = W(G[23]['prims'][0]['a']); R0 = 1.12 * S
FWD = np.array([0, -1.0, 0]); UP = np.array([0, 0, 1.0])

# ---- 척추·목·머리·눈
hips = W([0, 4.35, -.05])
bone('Root', (0, 0, 0), (0, -.25, 0), UP, None)
bone('Hips', hips, W([0, 4.75, -.07]), FWD, 'Root')
bone('Spine1', W([0, 4.75, -.07]), W([0, 5.3, -.06]), FWD, 'Hips')
bone('Spine2', W([0, 5.3, -.06]), W([0, 6.15, 0]), FWD, 'Spine1')
bone('Spine3', W([0, 6.15, 0]), W([0, 7.0, -.05]), FWD, 'Spine2')
bone('Neck', W([0, 7.0, -.05]), W([0, 7.62, .1]), FWD, 'Spine3')
bone('Head', W([0, 7.62, .1]), W([0, 9.4, .1]), FWD, 'Neck')
bone('Eye', E, E + FWD * .16, UP, 'Head')
R_EYE = R0 - .003; RI = .112; PHI_I = math.asin(RI / R_EYE)
pc = E + FWD * (R_EYE * math.cos(PHI_I) + .0012)
bone('Pupil', pc, pc + FWD * .03, UP, 'Eye')
bone('EyelidUpper', E, E + nrm((0, -.48, .88)) * .2, (0, -1, 0), 'Head')
bone('EyelidLower', E, E + nrm((0, -.48, -.88)) * .2, (0, 1, 0), 'Head')
for gi in (16,):
    GB[gi] = ['Hips', 'Spine1', 'UpperLeg.L', 'UpperLeg.R']
GB[17] = ['Hips', 'Spine1', 'Spine2']; GB[19] = ['Spine1', 'Spine2', 'Spine3']
GB[18] = ['Spine1', 'Spine2', 'Spine3', 'Neck', 'Shoulder_F.L', 'Shoulder_F.R', 'Shoulder_B.L', 'Shoulder_B.R']
GB[20] = ['Spine3', 'Neck', 'Head']; GB[21] = ['Neck', 'Head']; GB[22] = ['Head']
for _gi in range(44, 76):
    GB.pop(_gi, None)            # 굵은 눈꺼풀 주름 관은 뺐다(lids.py 눈꺼풀로 바뀜)
for gi in list(range(44, 60)):
    GB[gi] = ('fix', 'EyelidUpper')
for gi in list(range(60, 76)):
    GB[gi] = ('fix', 'EyelidLower')
# (관자 쇠틀·갈고리·눈물 관은 사용자 요청으로 뺐다 — 뼈도 없음)

# ---- 다리·발
for m, (leg, leg2, foot, toes) in ((-1, (0, 1, 2, range(3, 8))), (1, (8, 9, 10, range(11, 16)))):
    sd = SIDE(m)
    h, k, an = W([m * .48, 4.2, -.05]), W([m * .56, 2.3, .25]), W([m * .5, .36, -.15])
    tb = np.mean([gpts(G[t])[0] for t in toes], 0)
    tt = np.mean([gpts(G[t])[np.argmax(gpts(G[t])[:, 1] * -1)] for t in toes], 0)
    ball = np.array([an[0] + (tb[0] - an[0]) * .9, tb[1], max(tb[2], .02)])
    bone('UpperLeg' + sd, h, k, FWD, 'Hips')
    bone('LowerLeg' + sd, k, an, FWD, 'UpperLeg' + sd)
    bone('Foot' + sd, an, ball, UP, 'LowerLeg' + sd)
    bone('Toes' + sd, ball, np.array([tt[0], tt[1], ball[2]]), UP, 'Foot' + sd)
    GB[leg] = GB[leg2] = ['Hips', 'UpperLeg' + sd, 'LowerLeg' + sd, 'Foot' + sd]
    GB[foot] = ['LowerLeg' + sd, 'Foot' + sd, 'Toes' + sd]
    for t in toes:
        GB[t] = ['Foot' + sd, 'Toes' + sd]

# ---- 팔 4개 + 손: 펼친 묶는 자세(limbs.py → work/limbs.json)의 관절 그대로
LIMBS = json.load(open(os.path.join(WORK, 'limbs.json')))
for n, (h, t, u, par) in LIMBS['joints'].items():
    bone(n, h, t, u, par)
ARMG = {int(k): v for k, v in LIMBS['groups'].items()}
print('BONES', len(BONES))

# ---- 아마추어
arm_d = bpy.data.armatures.new('TteunnunRig'); arm = bpy.data.objects.new('TteunnunRig', arm_d); sc.collection.objects.link(arm)
vl.objects.active = arm; bpy.ops.object.mode_set(mode='EDIT')
done = []
def visit(n):
    if n in done: return
    if BONES[n][3]: visit(BONES[n][3])
    done.append(n)
for n in BONES: visit(n)
for n in done:
    h, t, u, par, de = BONES[n]
    b = arm_d.edit_bones.new(n); b.head = Vector(h); b.tail = Vector(t); b.align_roll(Vector(u))
    if par: b.parent = arm_d.edit_bones[par]
    b.use_deform = de
bpy.ops.object.mode_set(mode='OBJECT')

# ---- 정점마다 가장 가까운 시안 그룹(눈 겉 그룹 23~43 제외)
body = bpy.data.objects['Tteunnun']; me = body.data
V = np.array([v.co for v in me.vertices]); nv = len(V)
best_d = np.full(nv, 1e9); lab = np.full(nv, -1)
for g in G:
    if g['i'] not in GB:
        continue
    for p in g['prims']:
        if p['op']:
            continue
        a = W(p['a'])
        if p['t'] == 0:
            b_ = W(p['b']); d = seg_dist(V, a, b_) - max(p['ra'], p['rb']) * S
        else:
            r = np.mean(p['b']) * S; d = np.linalg.norm(V - a, axis=1) - r
        better = d < best_d; best_d[better] = d[better]; lab[better] = g['i']
# 연결 조각
E_ = np.array([e.vertices[:] for e in me.edges]); par = np.arange(nv)
def find(x):
    while par[x] != x:
        par[x] = par[par[x]]; x = par[x]
    return x
for a, b_ in E_:
    ra, rb = find(a), find(b_)
    if ra != rb: par[rb] = ra
comp = np.array([find(i) for i in range(nv)])
LIDS = None
ARMP = np.array([a.value for a in me.attributes['armpart'].data]) if 'armpart' in me.attributes else None
if 'lidshell' in me.attributes:
    _ga = lambda n: np.array([a.value for a in me.attributes[n].data])
    LIDS = (_ga('lidshell'), _ga('w_up'), _ga('w_lo'))
deform_all = {b.name: b.use_deform for b in arm_d.bones}
W_all = {}                       # 뼈 → 정점별 웨이트
def addw(bn, idx, w):
    W_all.setdefault(bn, np.zeros(nv))[idx] = w
fails = []
for c in np.unique(comp):
    idx = np.nonzero(comp == c)[0]
    if ARMP is not None and ARMP[idx].max() > .5:              # 새 팔·손 조각: 만들 때 정한 뼈 묶음
        code = int(round(np.median(ARMP[idx][ARMP[idx] > .5])))
        bones = sorted(ARMG[code])
    elif LIDS is not None and LIDS[0][idx].mean() > .5:          # 눈꺼풀 살 띠: 만들 때 넣은 위/아래 웨이트 그대로
        up_, lo_ = LIDS[1][idx], LIDS[2][idx]
        addw('EyelidUpper', idx, up_); addw('EyelidLower', idx, lo_); addw('Head', idx, np.clip(1 - up_ - lo_, 0, 1)); continue
    labs, cnt = np.unique(lab[idx], return_counts=True)
    main = labs[np.argmax(cnt)]
    # 손 조각(사람 손으로 새로 만든 것)은 머리·눈꺼풀 그룹이 가까워도 팔·손 뼈만 쓴다
    HANDG = set(range(82, 114))
    if int(main) in HANDG:
        keep = np.isin(labs, list(HANDG)); labs, cnt = labs[keep], cnt[keep]
    spec = GB.get(int(main))
    if isinstance(spec, tuple) and spec[0] == 'fix' and not (ARMP is not None and ARMP[idx].max() > .5):
        addw(spec[1], idx, 1.0); continue
    if isinstance(spec, tuple) and spec[0] == 'hook':
        p0, p1 = spec[2], spec[3]; t = np.clip(((V[idx] - p0) @ (p1 - p0)) / np.dot(p1 - p0, p1 - p0), 0, 1)
        w = smooth(.3, .65, t)
        addw(spec[1], idx, w); addw('Head', idx, 1 - w); continue
    bones = []
    for l, n_ in zip(labs, cnt):
        sp = GB.get(int(l))
        if n_ < max(10, .03 * len(idx)) or sp is None:
            continue
        if isinstance(sp, tuple):
            bones += [sp[1]] if sp[0] == 'fix' else [sp[1], 'Head']
        else:
            bones += sp
    bones = sorted(set(bones))
    if ARMP is not None and ARMP[idx].max() > .5:
        bones = sorted(ARMG[int(round(np.median(ARMP[idx][ARMP[idx] > .5])))])
    if len(bones) == 1:
        addw(bones[0], idx, 1.0); continue
    # 이 껍질만 떼어 자동 웨이트
    bm_ = bpy.data.meshes.new('tmp'); sub = bpy.data.objects.new('tmp', bm_); sc.collection.objects.link(sub)
    remap = -np.ones(nv, int); remap[idx] = np.arange(len(idx))
    F = [p.vertices[:] for p in me.polygons if remap[p.vertices[0]] >= 0]
    bm_.from_pydata([tuple(V[i]) for i in idx], [], [tuple(remap[list(f)]) for f in F]); bm_.update()
    for b in arm_d.bones:
        b.use_deform = b.name in bones
    for o in bpy.data.objects: o.select_set(False)
    arm.scale = sub.scale = (10, 10, 10); vl.update()
    sub.select_set(True); arm.select_set(True); vl.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    arm.scale = (1, 1, 1)
    ws = np.zeros((len(idx), len(bones)))
    for vg in sub.vertex_groups:
        if vg.name in bones:
            k = bones.index(vg.name)
            for v in bm_.vertices:
                for gg in v.groups:
                    if gg.group == vg.index:
                        ws[v.index, k] = gg.weight
    empty = ws.sum(1) < 1e-3
    if empty.any():
        fails.append((int(main), int(empty.sum()), len(idx)))
        D = np.stack([seg_dist(V[idx][empty], np.array(arm_d.bones[b].head_local), np.array(arm_d.bones[b].tail_local)) for b in bones], 1)
        ww = 1 / (D ** 4 + 1e-12); ws[empty] = ww / ww.sum(1, keepdims=True)
    ws /= np.maximum(ws.sum(1, keepdims=True), 1e-9)
    for k, b in enumerate(bones):
        addw(b, idx, ws[:, k])
    bpy.data.objects.remove(sub); bpy.data.meshes.remove(bm_)
for b in arm_d.bones:
    b.use_deform = deform_all[b.name]
print('HEAT_FALLBACK', fails)
# 눈구멍 테두리 살(굵은 눈꺼풀 관을 뺀 자리) → 눈꺼풀 뼈로 섞음: 눈알 가까이, 앞쪽일수록 눈꺼풀을 따라 움직임
dEv = np.linalg.norm(V - E, axis=1); dirv = (V - E) / np.maximum(dEv, 1e-9)[:, None]
front = smooth(.25, .6, dirv @ FWD)
headish = (W_all.get('Head', np.zeros(nv)) > .5) & ((LIDS[0] < .5) if LIDS is not None else True)
wl = (1 - smooth(R0 + .008, R0 + .055, dEv)) * front * headish
upv = smooth(-.25, .25, dirv[:, 2])
for b in list(W_all):
    W_all[b] = W_all[b] * (1 - wl)
W_all['EyelidUpper'] = W_all.get('EyelidUpper', np.zeros(nv)) + wl * upv
W_all['EyelidLower'] = W_all.get('EyelidLower', np.zeros(nv)) + wl * (1 - upv)
print('LID rim verts', int((wl > .05).sum()))
# 정점당 4개, 정규화
names = list(W_all); M_ = np.stack([W_all[n] for n in names], 1)
order = np.argsort(-M_, 1)
M2 = np.zeros_like(M_)
rows = np.arange(nv)[:, None]
M2[rows, order[:, :4]] = M_[rows, order[:, :4]]
M2[M2 < .01] = 0
M2 /= np.maximum(M2.sum(1, keepdims=True), 1e-9)
body.vertex_groups.clear()
for k, n in enumerate(names):
    vg = body.vertex_groups.new(name=n)
    nz = np.nonzero(M2[:, k])[0]
    for i in nz:
        vg.add([int(i)], float(M2[i, k]), 'REPLACE')
print('unweighted verts', int((M2.sum(1) < .5).sum()))
mod = body.modifiers.new('Armature', 'ARMATURE'); mod.object = arm; body.parent = arm
# 눈알 부품
for on, grp in (('Eyeball', 'Eye'), ('Cornea', 'Eye'), ('Pupil', 'Pupil')):
    o = bpy.data.objects[on]
    vg = o.vertex_groups.new(name=grp); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    md = o.modifiers.new('Armature', 'ARMATURE'); md.object = arm; o.parent = arm
# 속눈썹: 만들 때 넣은 위/아래 웨이트로
lo_ = bpy.data.objects.get('Lashes')
if lo_:
    lm = lo_.data; ga_ = lambda n: np.array([a.value for a in lm.attributes[n].data])
    for gname, arr in (('EyelidUpper', ga_('w_up')), ('EyelidLower', ga_('w_lo'))):
        vg = lo_.vertex_groups.new(name=gname)
        for i in np.nonzero(arr > .01)[0]:
            vg.add([int(i)], float(arr[i]), 'REPLACE')
    md = lo_.modifiers.new('Armature', 'ARMATURE'); md.object = arm; lo_.parent = arm
    lo_.name = 'M_Lash'
# animate.py 가 'M_' 로 시작하는 메시들을 하나로 합친다
body.name = 'M_Body'; bpy.data.objects['Eyeball'].name = 'M_Eye'; bpy.data.objects['Cornea'].name = 'M_Cornea'; bpy.data.objects['Pupil'].name = 'M_Pupil'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'stageB.blend'))
print('SAVED stageB rig')
