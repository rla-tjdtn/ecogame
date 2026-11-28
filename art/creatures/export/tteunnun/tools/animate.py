# 뜬눈(k10h1) — 3단계: 조종 뼈(IK·시선) + 동작 9개 → tteunnun.blend, tteunnun.fbx, tteunnun.glb
#   blender -b work/stageB.blend --factory-startup -noaudio -P animate.py
# 30fps. 반복 동작(Idle, Walk, Run, LookAround, EyeDart)은 첫 프레임 = 끝 프레임이 되게 주기 함수로 만든다.
# 모든 동작에 '살아 있음' 층을 더한다: 눈알 미세 도약(saccade), 눈꺼풀 떨림(감으려 하지만 손가락이 버팀), 손가락 꼼지락, 동공 맥동, 갈고리 떨림.
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from mathutils import Vector, Matrix, Euler
from tt_common import *

sc = bpy.context.scene
sc.render.fps = 30
arm = bpy.data.objects['TteunnunRig']
vl = bpy.context.view_layer
FWD = Vector((0, -1, 0)); E = Vector((0, -0.047, 1.99))
SIDES = ('L', 'R')
HANDS = ('F', 'B')
FINGERS = ('Thumb', 'Index', 'Middle', 'Ring', 'Pinky')

# ------------------------------------------------------------ 조종 뼈 만들기
for o in bpy.data.objects:
    o.select_set(False)
arm.select_set(True); vl.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones


def ctrl(name, head, tail, roll_like=None, parent=None, up=None):
    b = eb.new(name); b.head = head; b.tail = tail
    if roll_like:
        b.roll = eb[roll_like].roll
    elif up is not None:
        b.align_roll(up)
    b.parent = eb[parent] if parent else None
    b.use_deform = False
    return b


for s in SIDES:
    ft = eb['Foot.' + s]
    ctrl('IK_Foot.' + s, ft.head.copy(), ft.tail.copy(), 'Foot.' + s, 'Root')
    kn = eb['LowerLeg.' + s].head
    ctrl('Pole_Knee.' + s, kn + Vector((0, -.55, 0)), kn + Vector((0, -.65, 0)), None, 'Root', Vector((0, 0, 1)))
    for h in HANDS:
        hb = eb['Hand_%s.%s' % (h, s)]
        ctrl('IK_Hand_%s.%s' % (h, s), hb.head.copy(), hb.tail.copy(), 'Hand_%s.%s' % (h, s), 'Head')
        sh = eb['UpperArm_%s.%s' % (h, s)].head; el = eb['LowerArm_%s.%s' % (h, s)].head; wr = hb.head
        mid = (sh + wr) / 2; pd = (el - mid).normalized()
        ctrl('Pole_Elbow_%s.%s' % (h, s), el + pd * .4, el + pd * .5, None, 'Spine3', Vector((0, 0, 1)))
ctrl('EyeTarget', E + FWD * 1.2, E + FWD * 1.3, None, 'Head', Vector((0, 0, 1)))
bpy.ops.object.mode_set(mode='POSE')
PB = arm.pose.bones
for pb in PB:
    pb.rotation_mode = 'XYZ'


def ik(bone, target, pole, chain=2):
    c = PB[bone].constraints.new('IK'); c.target = arm; c.subtarget = target
    c.pole_target = arm; c.pole_subtarget = pole; c.chain_count = chain; c.use_stretch = False
    return c


def copyrot(bone, target):
    c = PB[bone].constraints.new('COPY_ROTATION'); c.target = arm; c.subtarget = target
    c.target_space = 'WORLD'; c.owner_space = 'WORLD'


IKC = []
for s in SIDES:
    IKC.append((ik('LowerLeg.' + s, 'IK_Foot.' + s, 'Pole_Knee.' + s), 'UpperLeg.' + s))
    copyrot('Foot.' + s, 'IK_Foot.' + s)
    for h in HANDS:
        IKC.append((ik('LowerArm_%s.%s' % (h, s), 'IK_Hand_%s.%s' % (h, s), 'Pole_Elbow_%s.%s' % (h, s)), 'UpperArm_%s.%s' % (h, s)))
        copyrot('Hand_%s.%s' % (h, s), 'IK_Hand_%s.%s' % (h, s))
dt = PB['Eye'].constraints.new('DAMPED_TRACK'); dt.target = arm; dt.subtarget = 'EyeTarget'; dt.track_axis = 'TRACK_Y'


# 극점 각도 맞추기: 쉬는 자세에서 IK 결과가 원래 팔꿈치·무릎 자리와 같도록
def chain_err(c, first):
    vl.update()
    second = [b.name for b in arm.data.bones if b.parent and b.parent.name == first and b.use_deform][0]
    return ((PB[first].tail - arm.data.bones[first].tail_local).length + (PB[second].tail - arm.data.bones[second].tail_local).length)


for c, first in IKC:
    best = (1e9, 0)
    for a in range(-180, 180, 3):
        c.pole_angle = math.radians(a); e = chain_err(c, first)
        if e < best[0]:
            best = (e, a)
    a0 = best[1]
    for a in np.arange(a0 - 3, a0 + 3, .25):
        c.pole_angle = math.radians(a); e = chain_err(c, first)
        if e < best[0]:
            best = (e, a)
    c.pole_angle = math.radians(best[1])
    print('POLE', first, round(best[1], 2), 'err', round(best[0] * 1000, 2), 'mm')

# ------------------------------------------------------------ 자세 도구
REST = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}


def to_local(bone, world_delta):
    return REST[bone].inverted() @ Vector(world_delta)


ROT_BONES = ['Root', 'Hips', 'Spine1', 'Spine2', 'Spine3', 'Neck', 'Head', 'EyelidUpper', 'EyelidLower']
ROT_BONES += ['Hook_%s.%s' % (u, s) for u in ('Up', 'Lo') for s in SIDES]
ROT_BONES += ['Shoulder_%s.%s' % (h, s) for h in HANDS for s in SIDES]
ROT_BONES += ['%s%d_%s.%s' % (f, j, h, s) for f in FINGERS for j in (1, 2, 3) for h in HANDS for s in SIDES]
ROT_BONES += ['Toes.' + s for s in SIDES] + ['IK_Foot.' + s for s in SIDES] + ['IK_Hand_%s.%s' % (h, s) for h in HANDS for s in SIDES]
LOC_BONES = ['Root', 'Hips', 'EyeTarget'] + ['IK_Foot.' + s for s in SIDES] + ['IK_Hand_%s.%s' % (h, s) for h in HANDS for s in SIDES]
for n in ROT_BONES + LOC_BONES + ['Pupil']:
    assert n in PB, n


class Pose:
    def __init__(s):
        s.rot = {}; s.loc = {}; s.pupil = 1.0

    def r(s, b, x=0, y=0, z=0):
        v = s.rot.get(b, np.zeros(3)); s.rot[b] = v + np.array([x, y, z], float)

    def l(s, b, d):
        """d = 세계(쉬는 자세) 방향 이동량."""
        v = s.loc.get(b, np.zeros(3)); s.loc[b] = v + np.array(d, float)


def apply_key(p, f):
    for b in ROT_BONES:
        PB[b].rotation_euler = Euler([math.radians(x) for x in p.rot.get(b, (0, 0, 0))], 'XYZ')
        PB[b].keyframe_insert('rotation_euler', frame=f, group=b)
    for b in LOC_BONES:
        PB[b].location = to_local(b, p.loc.get(b, (0, 0, 0)))
        PB[b].keyframe_insert('location', frame=f, group=b)
    PB['Pupil'].scale = (p.pupil, 1.0, p.pupil)
    PB['Pupil'].keyframe_insert('scale', frame=f, group='Pupil')


# ------------------------------------------------------------ 움직임 함수
def pn(t, period, seed, harm=3):
    """주기 period 로 반복되는 부드러운 잡음(-1~1)."""
    r = random.Random(seed); s = tot = 0
    for k in range(1, harm + 1):
        a = 1 / k; s += a * math.sin(2 * math.pi * k * t / period + r.uniform(0, 6.283)); tot += a
    return s / tot


def ease(x):
    x = min(max(x, 0), 1); return x * x * (3 - 2 * x)


def kf(t, keys):
    """[(프레임, 값)...] 사이를 부드럽게 잇는다(값은 수 또는 튜플)."""
    if t <= keys[0][0]:
        return np.array(keys[0][1], float)
    for (f0, v0), (f1, v1) in zip(keys[:-1], keys[1:]):
        if t <= f1:
            w = ease((t - f0) / max(f1 - f0, 1e-6))
            return np.array(v0, float) * (1 - w) + np.array(v1, float) * w
    return np.array(keys[-1][1], float)


def saccades(t, period, pts, move=3):
    """눈 도약: pts=[(시작프레임, yaw, pitch)], 각 점으로 move 프레임 동안 빠르게 이동 후 정지."""
    pts = sorted(pts)
    cur = pts[-1][1:] if period else pts[0][1:]
    prev = cur
    for f0, yw, pt in pts:
        if t >= f0:
            prev = cur; cur = (yw, pt); start = f0
    if t < pts[0][0]:
        return np.array(cur, float)
    w = min((t - start) / move, 1)
    w = 1 - (1 - w) ** 3
    return np.array(prev, float) * (1 - w) + np.array(cur, float) * w


def gaze(p, yaw, pitch):
    """눈 시선(도): yaw + 는 괴물의 왼쪽(+X), pitch + 는 위."""
    p.l('EyeTarget', (1.2 * math.tan(math.radians(yaw)), 0, 1.2 * math.tan(math.radians(pitch))))


def alive(p, t, period, k=1.0, grip=0.0, lid_strain=0.0, tremor=1.0, seed=0):
    """모든 동작에 더하는 층. period: 반복 주기(프레임, 한 번 동작이면 큰 값)."""
    P = period
    for hi, h in enumerate(HANDS):
        for si, s in enumerate(SIDES):
            for fi, fn in enumerate(FINGERS):
                base = pn(t, P, seed + 100 + hi * 50 + si * 25 + fi, 3) * 4.5 * k
                tw = pn(t, P / 3 if P < 500 else 37, seed + 300 + hi * 50 + si * 25 + fi, 2) * 1.5 * k * tremor
                for j in (1, 2, 3):
                    p.r('%s%d_%s.%s' % (fn, j, h, s), base * (1.2 - .2 * j) + tw + grip * (.6 + .2 * j))
                if fn != 'Thumb':
                    p.r('%s1_%s.%s' % (fn, h, s), 0, 0, pn(t, P, seed + 700 + fi + si * 9, 2) * 2.5 * k)
    # 눈꺼풀: 감으려 애씀(위 +X, 아래 -X 가 감는 쪽) — 손가락이 버텨 조금만
    trem = pn(t, P / 6 if P < 500 else 13, seed + 11, 3) * 1.4 * tremor + pn(t, P, seed + 12, 2) * 1.0
    p.r('EyelidUpper', trem + lid_strain)
    p.r('EyelidLower', -(pn(t, P / 6 if P < 500 else 11, seed + 13, 3) * 1.1 * tremor + lid_strain * .8))
    for u in ('Up', 'Lo'):
        for s in SIDES:
            p.r('Hook_%s.%s' % (u, s), pn(t, P / 10 if P < 500 else 7, seed + hash(u + s) % 97, 2) * .7 * tremor, 0,
                pn(t, P / 8 if P < 500 else 9, seed + 31 + hash(s + u) % 89, 2) * .5 * tremor)
    p.pupil *= 1 + .04 * pn(t, P, seed + 21, 3)


def hold_hands(p, t, P, seed, amp=.004):
    """손이 눈꺼풀을 붙잡고 있는 작은 당김(머리 공간에서 미세 이동)."""
    for h in HANDS:
        for s in SIDES:
            m = 1 if s == 'L' else -1
            sgn = -1 if h == 'F' else 1   # 앞손은 아래로, 뒷손은 위로 당김
            p.l('IK_Hand_%s.%s' % (h, s), (m * amp * pn(t, P, seed + hash(h + s) % 50, 2) * .5, 0,
                                           sgn * amp * (1 + pn(t, P, seed + 7 + hash(s + h) % 50, 2))))


# ------------------------------------------------------------ 걸음
def gait(p, t, N, S, beta, lift, bob, crouch, seed):
    ph = t / N
    for s, off in (('L', 0.0), ('R', .5)):
        q = (ph + off) % 1
        m = 1 if s == 'L' else -1
        if q < beta:
            w = q / beta
            y = -S / 2 + S * w; z = 0
            pitch = kf(w, [(0, 12), (.18, 0), (.75, 0), (1, -18)])
            heel = kf(w, [(0, 0), (.75, 0), (1, .035)])
            toes = kf(w, [(0, 0), (.75, 0), (1, 22)])
        else:
            w = (q - beta) / (1 - beta)
            y = S / 2 - S * ease(w); z = lift * math.sin(math.pi * w) ** .9
            pitch = kf(w, [(0, -18), (.25, -30), (.7, 5), (1, 12)])
            heel = kf(w, [(0, .035), (.3, .02), (1, 0)])
            toes = kf(w, [(0, 22), (.3, 5), (1, 0)])
        p.l('IK_Foot.' + s, (m * .008 * math.sin(2 * math.pi * ph), -y, z + heel))
        p.r('IK_Foot.' + s, float(pitch))
        p.r('Toes.' + s, float(toes))
    p.l('Hips', (.022 * math.sin(2 * math.pi * ph), 0, -crouch - bob * (.5 + .5 * math.cos(4 * math.pi * ph))))
    p.r('Hips', 0, 6 * math.sin(2 * math.pi * ph), 3 * math.sin(2 * math.pi * ph + 1.2))


# ------------------------------------------------------------ 동작들
CLIPS = {}


def clip(name, N, loop):
    def deco(fn):
        CLIPS[name] = (N, loop, fn); return fn
    return deco


@clip('Idle', 90, True)
def a_idle(t):
    p = Pose(); N = 90
    br = math.sin(2 * math.pi * 2 * t / N)
    p.r('Spine2', 1.2 * br); p.r('Spine3', .8 * br, 0, 0); p.r('Spine1', 2.5)
    p.l('Hips', (.008 * math.sin(2 * math.pi * t / N), 0, -.012 + .004 * br))
    p.r('Hips', 0, 0, 1.5 * math.sin(2 * math.pi * t / N))
    p.r('Neck', 3 + 1.5 * pn(t, N, 5), 2 * pn(t, N, 6), 0)
    p.r('Head', -2 + 2 * pn(t, N, 7), 3 * pn(t, N, 8), 4 * pn(t, N, 9) - 3)
    for s in SIDES:
        p.r('Shoulder_F.' + s, .8 * br); p.r('Shoulder_B.' + s, -.6 * br)
    g = saccades(t, N, [(0, 0, 0), (12, 11, 3), (27, -7, -5), (41, 4, 7), (58, -16, 1), (70, 6, -3), (84, 0, 0)])
    gaze(p, g[0] + .6 * pn(t, N, 40), g[1] + .6 * pn(t, N, 41))
    alive(p, t, N, seed=1)
    hold_hands(p, t, N, 3)
    return p


@clip('Walk', 36, True)
def a_walk(t):
    p = Pose(); N = 36
    gait(p, t, N, .5, .62, .085, .022, .045, 2)
    ph = 2 * math.pi * t / N
    p.r('Spine1', 6 + 1.5 * math.cos(2 * ph), -4 * math.sin(ph)); p.r('Spine2', 3, -3 * math.sin(ph)); p.r('Spine3', 2, -2 * math.sin(ph))
    p.r('Neck', 4 - 2 * math.cos(2 * ph + .6), 3 * math.sin(ph))
    p.r('Head', -6 + 2.5 * math.cos(2 * ph + 1.0), 4 * math.sin(ph + .5), 3 * math.sin(ph + .3) - 4)
    for s in SIDES:
        m = 1 if s == 'L' else -1
        p.r('Shoulder_F.' + s, 2 * math.sin(ph) * m); p.r('Shoulder_B.' + s, 1.5 * math.cos(ph))
    g = saccades(t, N, [(0, -10, -2), (9, 3, 0), (18, 14, -3), (27, 2, 2)])
    gaze(p, g[0], g[1])
    alive(p, t, N, seed=4)
    hold_hands(p, t, N, 6, .006)
    return p


@clip('Run', 22, True)
def a_run(t):
    p = Pose(); N = 22
    gait(p, t, N, .8, .38, .2, .05, .12, 5)
    ph = 2 * math.pi * t / N
    p.r('Spine1', 14 + 3 * math.cos(2 * ph), -6 * math.sin(ph)); p.r('Spine2', 8, -4 * math.sin(ph)); p.r('Spine3', 5 + 2 * math.cos(2 * ph + .5))
    p.r('Neck', -6 - 3 * math.cos(2 * ph + .9), 3 * math.sin(ph))
    p.r('Head', -12 + 4 * math.cos(2 * ph + 1.4), 3 * math.sin(ph + .6), 5 * math.sin(ph + .3))
    for s in SIDES:
        m = 1 if s == 'L' else -1
        p.r('Shoulder_F.' + s, 4 * math.sin(ph) * m, 0, -4); p.r('Shoulder_B.' + s, 3 * math.cos(ph), 0, 3 * m)
    gaze(p, 1.5 * pn(t, N, 50), -4 + 1.5 * pn(t, N, 51))
    p.pupil = 1.3
    alive(p, t, N, k=.7, grip=8, lid_strain=-2, tremor=1.6, seed=7)
    hold_hands(p, t, N, 9, .012)
    return p


@clip('Attack', 45, False)
def a_attack(t):
    p = Pose(); P = 1000
    sp = kf(t, [(0, 0), (11, -9), (17, 26), (24, 30), (34, 8), (45, 0)])
    p.r('Spine1', sp * .35); p.r('Spine2', sp * .35); p.r('Spine3', sp * .3)
    p.r('Neck', kf(t, [(0, 0), (11, -4), (17, -12), (26, -14), (45, 0)]))
    p.r('Head', kf(t, [(0, 0), (11, -6), (17, -10), (26, -8), (45, 0)]), 0, kf(t, [(0, 0), (8, 6), (17, -4), (45, 0)]))
    p.l('Hips', kf(t, [(0, (0, 0, 0)), (11, (0, .05, -.03)), (17, (0, -.16, -.1)), (26, (0, -.18, -.1)), (45, (0, 0, 0))]))
    p.l('IK_Foot.R', kf(t, [(0, (0, 0, 0)), (11, (0, 0, 0)), (14, (0, -.18, .12)), (17, (0, -.36, 0)), (30, (0, -.36, 0)),
                            (37, (0, -.18, .08)), (42, (0, 0, 0))]))
    p.r('IK_Foot.R', kf(t, [(0, 0), (12, -20), (16, 15), (18, 0), (31, 0), (35, -15), (42, 0)]))
    p.l('IK_Foot.L', kf(t, [(0, (0, 0, 0)), (17, (0, .04, 0)), (45, (0, 0, 0))]))
    p.r('IK_Foot.L', kf(t, [(0, 0), (17, -12), (30, -10), (45, 0)]))
    p.r('Toes.L', kf(t, [(0, 0), (17, 18), (30, 15), (45, 0)]))
    # 앞손: 눈꺼풀을 놓고 앞으로 뻗어 움켜쥔 뒤 다시 잡음 (머리 공간 이동, 세계 방향 기준)
    for s in SIDES:
        m = 1 if s == 'L' else -1
        d = kf(t, [(0, (0, 0, 0)), (10, (m * .02, .02, -.02)), (16, (m * .16, -.42, -.12)), (20, (m * .1, -.5, -.1)),
                   (25, (m * .06, -.38, -.1)), (36, (m * .03, -.08, -.03)), (43, (0, 0, 0))])
        p.l('IK_Hand_F.' + s, d)
        p.r('IK_Hand_F.' + s, kf(t, [(0, 0), (16, -35), (22, -10), (40, 0)]), 0, 0)
        p.r('Shoulder_F.' + s, kf(t, [(0, 0), (16, 12), (26, 8), (45, 0)]))
        op = kf(t, [(0, 0), (12, -5), (16, -32), (19, -30), (21, 55), (28, 60), (37, 15), (43, 0)])
        for fn in FINGERS:
            for j in (1, 2, 3):
                p.r('%s%d_F.%s' % (fn, j, s), op * (.7 + .15 * j) if fn != 'Thumb' else op * .6)
        p.r('Shoulder_B.' + s, kf(t, [(0, 0), (11, -4), (17, 6), (45, 0)]))
    # 놓인 아래 눈꺼풀은 처지려(감으려) 함 — 갈고리가 버팀
    p.r('EyelidLower', kf(t, [(0, 0), (14, 0), (18, -14), (30, -12), (40, -3), (44, 0)]))
    p.r('EyelidUpper', kf(t, [(0, 0), (16, -3), (30, -3), (44, 0)]))
    for s in SIDES:
        p.r('Hook_Lo.' + s, kf(t, [(0, 0), (16, 0), (19, 6), (30, 5), (42, 0)]))
    g = saccades(t, P, [(0, 0, 0), (6, 0, -6), (15, 0, -12), (30, 4, -6), (40, 0, 0)])
    gaze(p, g[0], g[1])
    p.pupil = float(kf(t, [(0, 1), (10, .7), (16, 1.55), (28, 1.5), (45, 1.0)]))
    alive(p, t, P, k=.6, tremor=1.3, seed=12)
    return p


@clip('LookAround', 120, True)
def a_look(t):
    p = Pose(); N = 120
    yaw = kf(t, [(0, 0), (8, 0), (28, 34), (48, 34), (72, -36), (94, -36), (114, 0), (120, 0)])
    pit = kf(t, [(0, 0), (28, 4), (48, -3), (72, 5), (94, -2), (120, 0)])
    p.r('Head', -pit * .5, yaw * .45, -yaw * .08); p.r('Neck', -pit * .3, yaw * .3)
    p.r('Spine3', 0, yaw * .15); p.r('Spine2', 2, yaw * .08)
    p.l('Hips', (-.01 * yaw / 35, 0, -.012))
    p.r('Hips', 0, yaw * .04)
    lead = kf(t + 6, [(0, 0), (8, 0), (28, 34), (48, 34), (72, -36), (94, -36), (114, 0), (126, 0)])
    sac = saccades(t, N, [(0, 0, 0), (35, 4, -3), (42, -3, 2), (80, -5, 3), (88, 2, -2), (110, 0, 0)])
    gaze(p, (lead - yaw) * .9 + sac[0] + 10 * math.tanh((lead - yaw) / 10), pit * .4 + sac[1])
    p.pupil = float(1 + .18 * math.sin(2 * math.pi * t / N * 2))
    alive(p, t, N, seed=15)
    hold_hands(p, t, N, 16)
    return p


@clip('Hit', 20, False)
def a_hit(t):
    p = Pose(); P = 1000
    j = kf(t, [(0, 0), (2.5, 1), (7, .55), (11, -.15), (15, .06), (20, 0)])
    p.r('Spine1', -8 * j); p.r('Spine2', -7 * j, 0, 4 * j); p.r('Spine3', -5 * j)
    p.r('Neck', -10 * j, 6 * j); p.r('Head', -14 * j, -5 * j, 9 * j)
    p.l('Hips', (0, .06 * j, -.03 * abs(j)))
    p.l('IK_Foot.L', (0, .05 * max(j, 0) * (t > 3), .03 * math.sin(min(t / 10, 1) * math.pi) * (t < 10)))
    p.r('EyelidUpper', 10 * max(j, 0)); p.r('EyelidLower', -8 * max(j, 0))
    for s in SIDES:
        p.r('Shoulder_F.' + s, -5 * j); p.r('Shoulder_B.' + s, 5 * j)
    g = saccades(t, P, [(0, 0, 0), (1, -14, 9), (6, 9, -6), (12, 0, 0)], move=2)
    gaze(p, g[0], g[1])
    p.pupil = float(kf(t, [(0, 1), (2, .62), (9, .75), (20, 1)]))
    alive(p, t, P, grip=float(12 * max(j, 0)), tremor=2.2, seed=19)
    hold_hands(p, t, P, 20, .01 * max(j, 0) + .002)
    return p


@clip('Death', 75, False)
def a_death(t):
    p = Pose(); P = 1000
    # 0~14 휘청 → 14~34 무릎 꺾임 → 34~56 뒤로 쓰러짐 → 56~75 경련 후 멎음
    p.l('Hips', kf(t, [(0, (0, 0, 0)), (8, (0, .06, -.02)), (14, (.03, .02, -.06)), (34, (.02, .1, -.42)),
                       (50, (0, .42, -.72)), (56, (0, .5, -.78)), (75, (0, .5, -.78))]))
    p.r('Hips', kf(t, [(0, 0), (14, 4), (34, -10), (50, -78), (56, -84), (62, -82), (75, -83)]), 0,
        kf(t, [(0, 0), (14, 6), (34, -6), (56, 3), (75, 3)]))
    p.r('Spine1', kf(t, [(0, 0), (8, -8), (14, 10), (34, 16), (52, -4), (58, 2), (75, 0)]))
    p.r('Spine2', kf(t, [(0, 0), (8, -6), (14, 8), (34, 10), (56, -2), (75, 0)]), 0, kf(t, [(0, 0), (14, -6), (40, 5), (75, 2)]))
    p.r('Neck', kf(t, [(0, 0), (8, -10), (34, 8), (52, -18), (58, -24), (75, -22)]))
    p.r('Head', kf(t, [(0, 0), (8, -14), (20, 10), (52, -12), (57, -26), (60, -20), (75, -22)]), kf(t, [(0, 0), (40, 0), (58, 22), (75, 24)]),
        kf(t, [(0, 0), (8, 10), (30, -8), (75, -10)]))
    p.l('IK_Foot.L', kf(t, [(0, (0, 0, 0)), (10, (0, .08, .05)), (14, (0, .12, 0)), (40, (.03, -.05, 0)), (56, (.06, -.28, 0)), (75, (.07, -.3, 0))]))
    p.l('IK_Foot.R', kf(t, [(0, (0, 0, 0)), (20, (-.04, -.06, 0)), (45, (-.08, -.2, 0)), (56, (-.1, -.38, .03)), (75, (-.11, -.42, 0))]))
    p.r('IK_Foot.L', kf(t, [(0, 0), (34, -10), (56, 40), (75, 38)]))
    p.r('IK_Foot.R', kf(t, [(0, 0), (34, -6), (56, 55), (75, 60)]), 0, kf(t, [(0, 0), (56, 10), (75, 12)]))
    for s in SIDES:
        m = 1 if s == 'L' else -1
        # 손이 눈꺼풀을 놓고 축 늘어짐(머리 공간에서 바깥·아래로)
        p.l('IK_Hand_F.' + s, kf(t, [(0, (0, 0, 0)), (30, (0, 0, 0)), (44, (m * .22, -.05, -.3)), (56, (m * .32, .05, -.38)), (75, (m * .33, .06, -.39))]))
        p.l('IK_Hand_B.' + s, kf(t, [(0, (0, 0, 0)), (36, (0, 0, 0)), (50, (m * .25, .1, -.05)), (60, (m * .36, .25, -.2)), (75, (m * .37, .26, -.21))]))
        p.r('IK_Hand_F.' + s, kf(t, [(0, 0), (30, 0), (56, 40), (75, 42)]))
        relax = kf(t, [(0, 0), (30, 6), (44, -18), (58, -12), (62, 6), (66, -10), (75, -8)])
        for h in HANDS:
            for fn in FINGERS:
                for j in (1, 2, 3):
                    p.r('%s%d_%s.%s' % (fn, j, h, s), relax * (1.1 - .2 * j))
        p.r('Hook_Up.' + s, kf(t, [(0, 0), (56, 0), (58, 6), (61, -3), (75, 0)]))
    p.r('EyelidUpper', kf(t, [(0, 0), (8, 8), (14, 2), (40, 4), (50, 14), (58, 18), (64, 15), (75, 16)]))
    p.r('EyelidLower', kf(t, [(0, 0), (8, -6), (40, -4), (50, -12), (75, -14)]))
    g = saccades(t, P, [(0, 0, 0), (3, 12, 8), (9, -10, -4), (16, 4, 18), (34, -6, 24), (58, 2, 30), (64, 0, 6)], move=3)
    gaze(p, g[0], g[1])
    p.pupil = float(kf(t, [(0, 1), (4, .6), (30, .8), (58, .9), (70, 1.8), (75, 1.85)]))
    fade = kf(t, [(0, 1), (56, 1), (75, .05)])
    alive(p, t, P, k=float(fade), tremor=float(2.0 * fade), seed=23)
    return p


@clip('EyeDart', 60, True)
def a_dart(t):
    p = Pose(); N = 60
    r = random.Random(77); pts = []; f = 0
    while f < N - 6:
        pts.append((f, r.uniform(-28, 28), r.uniform(-15, 15))); f += r.randint(4, 8)
    pts.append((N - 4, 0, 0)); pts[0] = (0, 0, 0)
    g = saccades(t, N, pts, move=2)
    gaze(p, g[0], g[1])
    p.r('Head', -g[1] * .1 + .8 * pn(t, N, 3), g[0] * .08, 0); p.r('Neck', 2, g[0] * .04)
    p.r('Spine2', 2 + .8 * math.sin(2 * math.pi * 2 * t / N))
    p.pupil = float(1 + .16 * pn(t, N, 5, 4))
    alive(p, t, N, grip=6, lid_strain=-3, tremor=2.0, seed=27)
    hold_hands(p, t, N, 28, .007)
    return p


@clip('Stare', 90, False)
def a_stare(t):
    p = Pose(); P = 1000
    lean = kf(t, [(0, 0), (18, 1), (90, 1)])
    p.r('Spine1', 3 + 4 * lean); p.r('Spine2', 3 * lean); p.r('Neck', 5 * lean); p.r('Head', -9 * lean)
    p.l('Hips', (0, -.02 * lean, -.015))
    g = kf(t, [(0, (6, -3)), (10, (6, -3)), (13, (0, 1)), (90, (0, 1))])
    gaze(p, float(g[0]) + .25 * pn(t, 45, 2), float(g[1]) + .25 * pn(t, 45, 3))
    p.pupil = float(kf(t, [(0, 1.0), (14, .92), (70, 1.85), (90, 1.9)]))
    strain = float(kf(t, [(0, 0), (20, -2), (70, -5), (90, -5.5)]))
    alive(p, t, P, k=.5, grip=float(4 * lean), lid_strain=strain, tremor=float(.5 + 1.2 * lean), seed=31)
    hold_hands(p, t, P, 32, .004 + .004 * float(lean))
    return p


# ------------------------------------------------------------ 굽기(키 넣기)
arm.animation_data_create()
ad = arm.animation_data
acts = {}
for name, (N, loop, fn) in CLIPS.items():
    act = bpy.data.actions.new(name); act.use_fake_user = True
    ad.action = act
    for f in range(0, N + 1):
        tt = f % N if loop else f
        p = fn(float(tt))
        apply_key(p, f)
    act.use_frame_range = True; act.frame_start = 0; act.frame_end = N
    act.use_cyclic = loop
    acts[name] = act
    print('CLIP', name, N + 1, 'frames', 'loop' if loop else 'once')
# NLA: 각 동작을 따로 된 트랙에(glTF 가 동작마다 하나씩 내보냄), 모두 음소거
ad.action = None
for name, act in acts.items():
    tr = ad.nla_tracks.new(); tr.name = name
    st = tr.strips.new(name, 0, act); st.name = name
    tr.mute = True
ad.action = acts['Idle']
sc.frame_start, sc.frame_end = 0, CLIPS['Idle'][0]
bpy.ops.object.mode_set(mode='OBJECT')
for pb in PB:
    pb.location = (0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)

# 최종 메시: 재질별 조각을 하나로 합친다(재질 7칸)
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('M_')]
for o in bpy.data.objects:
    o.select_set(False)
for o in meshes:
    o.select_set(True)
vl.objects.active = meshes[0]
bpy.ops.object.join()
body = vl.objects.active; body.name = 'Tteunnun'; body.data.name = 'Tteunnun'
for m in list(body.modifiers):
    if m.type == 'ARMATURE' and m.name != body.modifiers[0].name:
        body.modifiers.remove(m)
body.modifiers[0].object = arm
arm.name = 'TteunnunRig'
OUTB = os.path.join(OUT, 'tteunnun.blend')
bpy.ops.wm.save_as_mainfile(filepath=OUTB)
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_mainfile()
print('SAVED', OUTB)

# ------------------------------------------------------------ 내보내기
for o in bpy.data.objects:
    o.select_set(o in (arm, body))
vl.objects.active = arm
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, 'tteunnun.glb'), export_format='GLB', use_selection=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                          export_def_bones=True, export_frame_step=1, export_image_format='JPEG', export_jpeg_quality=92,
                          export_optimize_animation_size=False, export_skins=True, export_morph=False, export_apply=False,
                          export_yup=True, export_materials='EXPORT')
print('GLB done')
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, 'tteunnun.fbx'), use_selection=True, object_types={'ARMATURE', 'MESH'},
                         add_leaf_bones=False, use_armature_deform_only=True, bake_anim=True, bake_anim_use_all_actions=True,
                         bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0,
                         apply_scale_options='FBX_SCALE_ALL', path_mode='RELATIVE', mesh_smooth_type='FACE', use_tspace=True)
print('FBX done')
