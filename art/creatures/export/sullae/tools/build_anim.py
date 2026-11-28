# 3단계: base.blend → 동작 9개(30fps) 굽기 → sullae.blend / sullae.fbx / sullae.glb
#   blender -b --factory-startup -noaudio -P build_anim.py -- <work_dir> <out_dir>
# 자체 FK/IK 풀이로 매 프레임 뼈 회전을 계산해 키로 굽는다(손은 머리를 기준으로 감싸고, 손가락은 머리 표면에 닿도록 접촉 풀이).
import bpy, sys, os, math, time
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler
from bpy_extras import anim_utils
sys.path.insert(0, os.path.dirname(__file__))
import sullae_def as SD

argv = sys.argv[sys.argv.index('--') + 1:]
WORK, OUT = argv[0], argv[1]
FPS = 30
t0 = time.time()
def log(*a): print(f'[{time.time() - t0:6.1f}s]', *a, flush=True)

bpy.ops.wm.open_mainfile(filepath=os.path.join(WORK, 'base.blend'))
sc = bpy.context.scene; sc.render.fps = FPS; sc.render.fps_base = 1
ARM = bpy.data.objects['Sullae']; AD = ARM.data
BONES = [b for b in AD.bones if b.use_deform]
ORDER = []
def _walk(b):
    ORDER.append(b.name)
    for c in b.children: _walk(c)
for b in AD.bones:
    if b.parent is None: _walk(b)
DEFORM = {b.name for b in BONES}
REST = {b.name: b.matrix_local.copy() for b in AD.bones}
PAR = {b.name: (b.parent.name if b.parent else None) for b in AD.bones}
REL = {n: (REST[p].inverted() @ REST[n] if p else REST[n].copy()) for n, p in PAR.items()}
RQ = {n: REST[n].to_quaternion() for n in REST}
LEN = {b.name: b.length for b in AD.bones}
SIDES = SD.SIDES; FING = SD.FINGERS


def V(*a): return Vector(a)


def mirror(v, m):
    return Vector((v.x * m, v.y, v.z))


def rq(name, axis, deg):
    """쉬는 자세 축(아마추어 공간) 회전 → 뼈 로컬 회전"""
    q = Quaternion(Vector(axis).normalized(), math.radians(deg))
    return RQ[name].inverted() @ q @ RQ[name]


def qmul(*qs):
    r = Quaternion()
    for q in qs: r = r @ q
    return r


def frame_q(y, z):
    y = y.normalized(); z = (z - y * y.dot(z)).normalized(); x = y.cross(z)
    return Matrix((x, y, z)).transposed().to_quaternion()


# ---------------------------------------------------------------- FK
class Pose:
    def __init__(self):
        self.L = {n: Quaternion() for n in REST}
        self.T = {n: Vector() for n in REST}
        self.W = {}

    def world(self, n):
        p = PAR[n]
        base = (self.W[p] if p else Matrix()) @ REL[n]
        return base @ Matrix.Translation(self.T[n]) @ self.L[n].to_matrix().to_4x4()

    def solve(self, names=None):
        for n in ORDER:
            if names is None or n in names:
                self.W[n] = self.world(n)

    def base_rot(self, n):
        p = PAR[n]
        return ((self.W[p] if p else Matrix()) @ REL[n]).to_quaternion()


def chain(pose, root):
    out = []
    def w(n):
        out.append(n)
        for c in AD.bones[n].children: w(c.name)
    w(root); return out


# ---------------------------------------------------------------- 두 뼈 IK
HSIGN = {}
for tag in SD.ARMS:
    for s, m in SIDES.items():
        c0, sh, el, wr, f, n = SD.ARM_INFO[(tag, s)]
        h = (el - sh).cross(wr - el).normalized()
        HSIGN[(tag, s)] = 1 if h.dot(REST[f'UpperArm_{tag}.{s}'].col[0].xyz) > 0 else -1
for s in SIDES:
    hip, kn, an = REST[f'Thigh.{s}'].translation, REST[f'Shin.{s}'].translation, REST[f'Foot.{s}'].translation
    h = (kn - hip).cross(an - kn).normalized()
    HSIGN[('leg', s)] = 1 if h.dot(REST[f'Thigh.{s}'].col[0].xyz) > 0 else -1


def two_bone(pose, up, lo, target, pole, sign):
    S = pose.W[up].translation if up in pose.W else None
    pose.W[up] = pose.world(up); S = pose.W[up].translation.copy()
    a, b = LEN[up], LEN[lo]
    d = target - S; dist = max(min(d.length, (a + b) * .9985), abs(a - b) + 1e-3); dr = d.normalized()
    T = S + dr * dist
    ca = (a * a + dist * dist - b * b) / (2 * a * dist); sa = math.sqrt(max(0, 1 - ca * ca))
    pv = pole - S; pv = (pv - dr * dr.dot(pv)).normalized()
    E = S + dr * a * ca + pv * a * sa
    h = (E - S).cross(T - E)
    if h.length < 1e-6: h = dr.cross(pv)
    h = h.normalized() * sign
    qu = frame_q(E - S, h.cross((E - S).normalized()))
    pose.L[up] = pose.base_rot(up).inverted() @ qu
    pose.W[up] = pose.world(up)
    ql = frame_q(T - E, h.cross((T - E).normalized()))
    pose.L[lo] = pose.base_rot(lo).inverted() @ ql
    pose.W[lo] = pose.world(lo)
    return T


# ---------------------------------------------------------------- 머리 접촉(손가락이 머리 표면을 따라 감싼다)
HEAD_PRIMS = [p for p in SD.prims() if p.lo[2] > 1.60 and p.grp != 'finger' and p.op == 'add']


def head_sdf(P):
    return SD.sdf(np.atleast_2d(np.array(P)), HEAD_PRIMS)


def finger_world(Wh, fn, tag, s, curls, spread):
    """손 월드 행렬 Wh 에서 손가락 관절 끝점들"""
    pts = []; Wp = Wh
    for j in range(3):
        n = f'{fn}{j + 1}_{tag}.{s}'
        q = Quaternion((1, 0, 0), curls[j]) @ (Quaternion((0, 0, 1), spread) if j == 0 else Quaternion())
        Wp = Wp @ REL[n] @ q.to_matrix().to_4x4()
        pts.append((Wp @ Vector((0, LEN[n], 0))))
    return pts


def contact_curls(Wh, fn, tag, s, spread, gap=.0035, lim=(-.25, 1.45)):
    curls = [0.0, 0.0, 0.0]
    r0, r3 = SD.FING_R[fn]
    for j in range(3):
        rr = r0 + (r3 - r0) * (j + 1) / 3
        def g(th):
            c = curls[:]; c[j] = th
            return head_sdf(finger_world(Wh, fn, tag, s, c, spread)[j])[0] - (rr + gap)
        lo, hi = lim
        if j == 0: hi = .9
        if g(lo) <= 0: curls[j] = lo; continue
        if g(hi) > 0: curls[j] = hi; continue
        for _ in range(18):
            mid = (lo + hi) / 2
            if g(mid) > 0: lo = mid
            else: hi = mid
        curls[j] = (lo + hi) / 2
    return curls


# ---------------------------------------------------------------- 자세 사양
def hand_mat(wr, f, n):
    q = frame_q(f, n)
    return Matrix.Translation(wr) @ q.to_matrix().to_4x4()


WRAP, FREE, CONTACT = {}, {}, {}
for s, m in SIDES.items():
    HL = SD.HL
    # 앞 손: 손바닥을 볼에 대고 손가락이 얼굴 앞을 가로질러 눈을 덮는다(왼손이 조금 위·바깥)
    wr = HL(m * 1.00, -.50 + (.035 if m > 0 else -.035), .22 + (.02 if m > 0 else 0))
    f = Vector((-m * .12, -.92, .36)).normalized(); n = Vector((-m, .10, 0)); n = (n - f * f.dot(n)).normalized()
    WRAP[('F', s)] = dict(wr=wr, f=f, n=n, pole=V(m * .42, -.32, 1.28), spread=[.15, .10, .02, -.06, -.14])
    # 뒤 손: 머리 옆을 잡고 손가락이 정수리를 덮는다
    wr = HL(m * 1.13, -.12, -.12)
    f = Vector((-m * .25, -.02, 1)).normalized(); n = Vector((-m, 0, -.25)); n = (n - f * f.dot(n)).normalized()
    WRAP[('B', s)] = dict(wr=wr, f=f, n=n, pole=V(m * .55, .32, 1.52), spread=[.1, .16, .05, -.05, -.16])
    # 펼친 자세(추격): 앞 팔은 앞옆으로, 뒤 팔은 위로 벌리고 손가락을 쫙 편다
    FREE[('F', s)] = dict(wr=V(m * .60, -.36, 1.30), f=Vector((m * .45, -.88, .02)).normalized(), n=V(0, -.1, -1), pole=V(m * .5, .15, 1.1))
    FREE[('B', s)] = dict(wr=V(m * .50, -.16, 1.98), f=Vector((m * .35, -.55, .75)).normalized(), n=V(0, -.85, .55), pole=V(m * .65, .35, 1.55))
    for tag in SD.ARMS:
        for d in (FREE[(tag, s)],):
            d['n'] = (d['n'] - d['f'] * d['f'].dot(d['n'])).normalized()
for key, spec in WRAP.items():
    tag, s = key
    Wh = hand_mat(spec['wr'], spec['f'], spec['n'])
    CONTACT[key] = [contact_curls(Wh, fn, tag, s, spec['spread'][fi]) for fi, fn in enumerate(FING)]
    log('contact', key, [[round(math.degrees(c)) for c in cc] for cc in CONTACT[key]])


def delta(pose, bone):
    return pose.W[bone] @ REST[bone].inverted()


def solve_arm(pose, tag, s, spec, frame_bone):
    D = delta(pose, frame_bone)
    R = D.to_quaternion()
    wr = D @ spec['wr']; f = R @ spec['f']; n = R @ spec['n']; pole = D @ spec['pole']
    up, lo, hd = f'UpperArm_{tag}.{s}', f'LowerArm_{tag}.{s}', f'Hand_{tag}.{s}'
    two_bone(pose, up, lo, wr, pole, HSIGN[(tag, s)])
    qh = frame_q(f, n)
    pose.L[hd] = pose.base_rot(hd).inverted() @ qh
    return {b: pose.L[b].copy() for b in (up, lo, hd)}


# ---------------------------------------------------------------- 한 프레임 자세 만들기
def build(P):
    """P: 동작 함수가 만든 사양 dict → 뼈별 (로컬 회전, 이동)"""
    pose = Pose()
    # 몸통
    pose.T['Hips'] = RQ['Hips'].inverted() @ P.get('hips', Vector())
    pose.L['Hips'] = qmul(*[rq('Hips', a, d) for a, d in P.get('hips_rot', [])])
    for bn in ('Spine1', 'Spine2', 'Spine3', 'Neck', 'Head'):
        pose.L[bn] = qmul(*[rq(bn, a, d) for a, d in P.get(bn, [])])
    pose.L['Jaw'] = rq('Jaw', (1, 0, 0), P.get('jaw', 0))
    for s in SIDES:
        ey, ep = P.get('eye', (0, 0)) if not isinstance(P.get('eye'), dict) else P['eye'][s]
        pose.L[f'Eye.{s}'] = qmul(rq(f'Eye.{s}', (0, 0, 1), ey), rq(f'Eye.{s}', (1, 0, 0), -ep))
    pose.solve([n for n in ORDER if not any(k in n for k in ('Arm', 'Hand', 'Thigh', 'Shin', 'Foot', 'Toe', 'Shoulder_')) and n not in FINGER_BONES])
    # 다리(IK)
    for s, m in SIDES.items():
        lg = P['legs'][s]
        pose.L[f'Thigh.{s}'] = Quaternion()
        knee_pole = pose.W['Hips'] @ (REST['Hips'].inverted() @ (REST[f'Shin.{s}'].translation + V(m * .04, -.5, 0)))
        if lg.get('knee_pole') is not None: knee_pole = lg['knee_pole']
        two_bone(pose, f'Thigh.{s}', f'Shin.{s}', lg['ankle'], knee_pole, HSIGN[('leg', s)])
        qf = Quaternion((0, 0, 1), math.radians(lg.get('yaw', 0))) @ Quaternion((1, 0, 0), math.radians(lg.get('pitch', 0))) @ Quaternion((0, 1, 0), math.radians(lg.get('roll', 0)))
        pose.L[f'Foot.{s}'] = pose.base_rot(f'Foot.{s}').inverted() @ (qf @ RQ[f'Foot.{s}'])
        pose.W[f'Foot.{s}'] = pose.world(f'Foot.{s}')
        pose.L[f'Toe.{s}'] = rq(f'Toe.{s}', (1, 0, 0), lg.get('toe', 0))
        pose.W[f'Toe.{s}'] = pose.world(f'Toe.{s}')
    # 팔 넷
    for tag in SD.ARMS:
        for s, m in SIDES.items():
            A = P['arms'][(tag, s)]
            sh = f'Shoulder_{tag}.{s}'
            pose.L[sh] = qmul(*[rq(sh, mirror(Vector(a), 1), d * (1 if i else 1)) for i, (a, d) in enumerate(A.get('clav', []))])
            pose.W[sh] = pose.world(sh)
            w = A.get('w', 1.0)  # 1 = 머리 감쌈, 0 = 펼침
            res = {}
            if w > 0:
                spec = dict(WRAP[(tag, s)]); off = A.get('wrap_off')
                if off is not None:
                    spec['wr'] = spec['wr'] + mirror(off, m)
                if 'wrap_rot' in A:
                    q = A['wrap_rot']; spec['f'] = q @ spec['f']; spec['n'] = q @ spec['n']
                Lw = solve_arm(pose, tag, s, spec, 'Head')
            if w < 1:
                spec = A.get('free') or FREE[(tag, s)]
                Lf = solve_arm(pose, tag, s, spec, A.get('free_frame', 'Spine3'))
            for b in (f'UpperArm_{tag}.{s}', f'LowerArm_{tag}.{s}', f'Hand_{tag}.{s}'):
                if w >= 1: pose.L[b] = Lw[b]
                elif w <= 0: pose.L[b] = Lf[b]
                else:
                    a_, b_ = Lf[b], Lw[b]
                    if a_.dot(b_) < 0: b_ = -b_
                    pose.L[b] = a_.slerp(b_, w)
                pose.W[b] = pose.world(b)
            # 손가락
            for fi, fn in enumerate(FING):
                cw = CONTACT[(tag, s)][fi]; spw = WRAP[(tag, s)]['spread'][fi]
                cf = A.get('free_curl', [(.05, .12, .18)] * 5)[fi]; spf = A.get('free_spread', [math.radians((fi - 2) * -9) * (1 if fi else 0) + (.35 if fi == 0 else 0)] * 5)[fi] if isinstance(A.get('free_spread'), list) else (math.radians((2 - fi) * 9) if fi else .35)
                add = A.get('fadd', {}).get(fi, (0, 0, 0, 0))
                for j in range(3):
                    c = cw[j] * w + cf[j] * (1 - w) + add[j]
                    sp = (spw * w + spf * (1 - w) + add[3]) if j == 0 else 0
                    pose.L[f'{fn}{j + 1}_{tag}.{s}'] = Quaternion((1, 0, 0), c) @ Quaternion((0, 0, 1), sp)
    return pose


FINGER_BONES = {n for n in REST if any(n.startswith(f) for f in FING)}

# ---------------------------------------------------------------- 동작 도구
TAU = math.tau
def sn(t, k=1, ph=0.0): return math.sin(TAU * (k * t + ph))
def cs(t, k=1, ph=0.0): return math.cos(TAU * (k * t + ph))
def ease(x): x = max(0, min(1, x)); return x * x * (3 - 2 * x)
def seg(t, a, b): return ease((t - a) / (b - a)) if b > a else float(t >= a)
def lerp(a, b, t): return a + (b - a) * t
def bump(t, a, b):  # a~b 사이 0→1→0
    if t <= a or t >= b: return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


ANK = {s: REST[f'Foot.{s}'].translation.copy() for s in SIDES}


def stand_legs(dz=0.0, spread=0.0):
    return {s: dict(ankle=ANK[s] + V(m * spread, 0, 0)) for s, m in SIDES.items()}


def finger_life(t, tag, s, amp=1.0, speed=1, seed=0.0):
    """손가락이 하나하나 꿈틀거린다(주기 정수배라 반복이 끊기지 않는다)"""
    d = {}
    for fi in range(5):
        ph = (hash((tag, s, fi)) % 997) / 997.0 + seed
        a = amp * (.10 * sn(t, speed, ph) + .06 * sn(t, speed * 2 + 1, ph * 1.7) + .05 * sn(t, speed * 3 + 2, ph * 2.3))
        d[fi] = (a * .6, a * 1.0, a * .8, .05 * amp * sn(t, speed + 1, ph * .5))
    return d


def merge(a, b, w=1.0):
    out = dict(a)
    for k, v in b.items():
        if k in out:
            out[k] = tuple(x + y * w for x, y in zip(out[k], v))
        else:
            out[k] = tuple(y * w for y in v)
    return out


def arms_wrap(t, amp=1.0, speed=1, extra=None):
    A = {}
    for tag in SD.ARMS:
        for s in SIDES:
            A[(tag, s)] = dict(w=1.0, fadd=finger_life(t, tag, s, amp, speed))
    if extra:
        for k, v in extra.items(): A[k].update(v)
    return A


def arms_free(t, amp=1.0, speed=2):
    A = {}
    for tag in SD.ARMS:
        for s in SIDES:
            A[(tag, s)] = dict(w=0.0, fadd=finger_life(t, tag, s, amp, speed))
    return A


# ---------------------------------------------------------------- 동작들 (t = 0..1)
def clip_idle(t):
    br = sn(t, 2)  # 숨 두 번
    sway = sn(t, 1)
    return dict(hips=V(.006 * sway, 0, -.012 + .003 * br), hips_rot=[((0, 1, 0), 1.5 * sway)],
                Spine1=[((1, 0, 0), 3 + 1.2 * br)], Spine2=[((1, 0, 0), 4 + .8 * br), ((0, 1, 0), -1 * sway)], Spine3=[((1, 0, 0), 2 + 1.5 * br)],
                Neck=[((1, 0, 0), 10 + 2 * sn(t, 1, .2))], Head=[((1, 0, 0), 6 + 1.5 * sn(t, 2, .3)), ((0, 1, 0), 7 + 2 * sway), ((0, 0, 1), 2 * sn(t, 1, .4))],
                jaw=1 + 1 * (sn(t, 3) * .5 + .5), legs={s: dict(ankle=ANK[s], knee_pole=None) for s in SIDES}, arms=arms_wrap(t, 1.0, 1))


def clip_count(t):
    # 숫자를 센다: 하나·둘·셋·넷 — 셀 때마다 고개를 꾸벅이고 입이 벙긋, 손가락이 차례로 두드린다
    beats = 4
    ph = (t * beats) % 1.0; bi = int(t * beats) % beats
    nod = math.exp(-((ph - .18) ** 2) / .008) if True else 0
    rock = sn(t, 2)
    A = arms_wrap(t, .6, 2)
    for k, (tag, s) in enumerate([('F', 'L'), ('F', 'R'), ('B', 'L'), ('B', 'R')]):
        for fi in range(1, 5):
            # 박자마다 손가락 하나가 들렸다가 탁 붙는다
            tap = bump(ph, .05 + fi * .12, .32 + fi * .12) * (1.0 if (bi + fi + k) % 2 == 0 else .55)
            cur = A[(tag, s)]['fadd'].get(fi, (0, 0, 0, 0))
            A[(tag, s)]['fadd'][fi] = (cur[0] - .35 * tap, cur[1] - .25 * tap, cur[2] - .15 * tap, cur[3])
    return dict(hips=V(0, .008 * rock, -.018 - .006 * nod), Spine1=[((1, 0, 0), 5 + 3 * rock)], Spine2=[((1, 0, 0), 6 + 2 * rock)], Spine3=[((1, 0, 0), 4 + 4 * nod)],
                Neck=[((1, 0, 0), 14 + 6 * nod)], Head=[((1, 0, 0), 8 + 9 * nod), ((0, 1, 0), 4 * sn(t, 1)), ((0, 0, 1), 3 * sn(t, 2, .1))],
                jaw=2 + 9 * bump(ph, .1, .45), legs={s: dict(ankle=ANK[s]) for s in SIDES}, arms=A)


def clip_peek(t):
    # 손가락 틈을 벌려 엿본다(왼쪽 앞 손의 가운데·약지가 벌어지고 눈알이 굴러간다) → 다시 닫는다
    o = seg(t, .15, .32) * (1 - seg(t, .78, .92))
    look = sn(t, 2, .1) * o
    A = arms_wrap(t, .7, 2)
    fl = A[('F', 'L')]['fadd']
    fl[2] = merge({0: fl[2]}, {0: (-.55 * o, -.5 * o, -.3 * o, .32 * o)})[0]
    fl[3] = merge({0: fl[3]}, {0: (-.25 * o, -.2 * o, -.1 * o, -.30 * o)})[0]
    fl[1] = merge({0: fl[1]}, {0: (-.15 * o, -.1 * o, 0, .1 * o)})[0]
    A[('F', 'L')]['wrap_off'] = V(.015 * o, -.012 * o, .004 * o)
    A[('F', 'R')]['fadd'][1] = merge({0: A[('F', 'R')]['fadd'][1]}, {0: (-.2 * o, -.2 * o, -.1 * o, .12 * o)})[0]
    return dict(hips=V(0, 0, -.015), Spine1=[((1, 0, 0), 4)], Spine2=[((1, 0, 0), 5), ((0, 1, 0), 6 * o)], Spine3=[((1, 0, 0), 3)],
                Neck=[((1, 0, 0), 12 - 4 * o), ((0, 0, 1), 8 * o)], Head=[((1, 0, 0), 6 - 5 * o), ((0, 1, 0), 7 - 14 * o + 6 * look), ((0, 0, 1), -6 * o)],
                eye={'L': (28 * look, 6 * o - 4 * abs(look)), 'R': (28 * look, 6 * o - 4 * abs(look))}, jaw=1 + 6 * bump(t, .4, .6),
                legs={s: dict(ankle=ANK[s]) for s in SIDES}, arms=A)


def clip_look(t):
    # 둘러보기: 앞 손을 반쯤 열고(손가락 새장) 고개를 좌우로 돌리며 눈알이 따라 굴러간다
    yaw = 38 * sn(t, 1) ; pitch = 8 * sn(t, 2, .25)
    A = arms_wrap(t, 1.0, 2)
    for s in SIDES:
        A[('F', s)]['w'] = .55 + .1 * sn(t, 2)
        A[('F', s)]['free'] = dict(FREE[('F', s)], wr=V(SIDES[s] * .30, -.40, 1.70), f=Vector((SIDES[s] * .1, -.6, .8)).normalized(), n=V(-SIDES[s], -.3, 0), pole=V(SIDES[s] * .45, -.1, 1.2))
        A[('F', s)]['free']['n'] = (A[('F', s)]['free']['n'] - A[('F', s)]['free']['f'] * A[('F', s)]['free']['f'].dot(A[('F', s)]['free']['n'])).normalized()
        A[('F', s)]['free_frame'] = 'Head'
        A[('F', s)]['free_curl'] = [(.2, .4, .5)] * 5
    return dict(hips=V(0, 0, -.02), hips_rot=[((0, 0, 1), yaw * .12)], Spine1=[((1, 0, 0), 3)], Spine2=[((0, 0, 1), yaw * .15), ((1, 0, 0), 4)], Spine3=[((0, 0, 1), yaw * .2)],
                Neck=[((0, 0, 1), yaw * .25), ((1, 0, 0), 8 + pitch * .5)], Head=[((0, 0, 1), yaw * .35), ((1, 0, 0), pitch), ((0, 1, 0), 6 * sn(t, 1, .3))],
                eye=(yaw * .6 + 8 * sn(t, 5), 5 * sn(t, 3, .2)), jaw=1 + 2 * (sn(t, 4) * .5 + .5), legs={s: dict(ankle=ANK[s], yaw=-SIDES[s] * 0) for s in SIDES}, arms=A)


def gait(t, stride, lift, duty, ph, hip_z):
    """한 발의 발목 목표: t 0..1, ph 위상"""
    u = (t + ph) % 1.0
    if u < duty:  # 디딤: 앞에서 뒤로
        k = u / duty; y = lerp(-stride / 2, stride / 2, k); z = 0.0
        pitch = 0.0
        if k > .7: pitch = -25 * seg(k, .7, 1.0); z = .03 * seg(k, .7, 1.0)  # 뒤꿈치가 들린다
        toe = 25 * seg(k, .7, 1.0)
    else:  # 흔들기: 뒤에서 앞으로
        k = (u - duty) / (1 - duty); e = ease(k)
        y = lerp(stride / 2, -stride / 2, e); z = lift * math.sin(math.pi * k) + .03 * (1 - k) ** 2
        pitch = lerp(-25, 12, ease(min(1, k * 1.6))) * (1 - seg(k, .8, 1.0)) + 0
        toe = 25 * (1 - seg(k, 0, .4)) - 10 * bump(k, .3, .9)
    return y, z, pitch, toe


def clip_walk(t):
    stride, duty = .52, .62
    legs = {}
    for s, m in SIDES.items():
        y, z, pitch, toe = gait(t, stride, .09, duty, 0 if s == 'L' else .5, 0)
        legs[s] = dict(ankle=ANK[s] + V(0, y, z), pitch=pitch, toe=toe)
    bob = cs(t, 2)  # 두 번 디딤
    lat = sn(t, 1)
    A = arms_wrap(t, .8, 2)
    return dict(hips=V(.022 * lat, 0, -.035 - .018 * bob), hips_rot=[((0, 0, 1), 7 * lat), ((0, 1, 0), -3 * lat)],
                Spine1=[((1, 0, 0), 6), ((0, 0, 1), -4 * lat)], Spine2=[((1, 0, 0), 5 + 1.5 * bob), ((0, 1, 0), 2 * lat)], Spine3=[((0, 0, 1), -3 * lat), ((1, 0, 0), 3)],
                Neck=[((1, 0, 0), 14 + 2 * bob)], Head=[((1, 0, 0), 6 - 2 * bob), ((0, 1, 0), 8 * sn(t, 1, .1)), ((0, 0, 1), -3 * lat)],
                jaw=2 + 2 * sn(t, 2), legs=legs, arms=A)


def clip_run(t):
    stride, duty = 1.05, .38
    legs = {}
    for s, m in SIDES.items():
        y, z, pitch, toe = gait(t, stride, .20, duty, 0 if s == 'L' else .5, 0)
        legs[s] = dict(ankle=ANK[s] + V(0, y + .06, z), pitch=pitch, toe=toe)
    bob = cs(t, 2); lat = sn(t, 1)
    A = arms_free(t, 1.6, 2)
    for tag in SD.ARMS:
        for s, m in SIDES.items():
            sw = sn(t, 1, (.0 if s == 'L' else .5) + (.25 if tag == 'B' else 0))
            base = FREE[(tag, s)]
            A[(tag, s)]['free'] = dict(base, wr=base['wr'] + V(0, -.12 * sw, .05 * sw + (.04 if tag == 'B' else 0) * bob))
            A[(tag, s)]['free_curl'] = [(-.15, .25, .45)] * 5
    return dict(hips=V(.015 * lat, -.02, -.07 + .03 * bob), hips_rot=[((1, 0, 0), 10), ((0, 0, 1), 10 * lat)],
                Spine1=[((1, 0, 0), 8), ((0, 0, 1), -6 * lat)], Spine2=[((1, 0, 0), 9), ((0, 1, 0), 3 * lat)], Spine3=[((1, 0, 0), 6), ((0, 0, 1), -5 * lat)],
                Neck=[((1, 0, 0), -4)], Head=[((1, 0, 0), -10 + 4 * bob), ((0, 1, 0), 10 * sn(t, 1, .2)), ((0, 0, 1), 4 * lat)],
                eye=(10 * sn(t, 2), -6), jaw=14 + 6 * sn(t, 2), legs=legs, arms=A)


def chase_stance(t, crouch=0.0):
    return dict(hips=V(0, .0, -.06 - .08 * crouch), hips_rot=[((1, 0, 0), 8 + 10 * crouch)], legs={s: dict(ankle=ANK[s] + V(SIDES[s] * .04, (.10 if s == 'L' else -.12), 0), pitch=0) for s in SIDES})


def clip_attack(t):
    # 웅크렸다가(0~.3) 네 팔을 앞으로 덮치며(.3~.5) 손가락을 움켜쥐고 입을 벌린 채 끌어당긴다(.5~.8) → 추격 자세로
    wind = seg(t, 0, .28) * (1 - seg(t, .3, .42)); lunge = seg(t, .3, .46) * (1 - seg(t, .72, 1.0)); grab = seg(t, .44, .56) * (1 - seg(t, .8, 1.0))
    pull = seg(t, .56, .72) * (1 - seg(t, .82, 1.0))
    st = chase_stance(t, wind)
    A = arms_free(t, 1.2 * (1 - grab) + .3, 3)
    for tag in SD.ARMS:
        for s, m in SIDES.items():
            base = FREE[(tag, s)]
            tgt = V(m * (.16 if tag == 'F' else .30), -.70 if tag == 'F' else -.55, 1.42 if tag == 'F' else 1.98)
            back = base['wr'] + V(m * .08, .18, .05)
            wr = base['wr'].lerp(back, wind)
            wr = wr.lerp(tgt, lunge)
            wr = wr + V(0, .16 * pull, -.03 * pull)
            fdir = base['f'].lerp(Vector((m * .1, -1, (.0 if tag == 'F' else -.3))).normalized(), lunge).normalized()
            n = (V(-m * .6, 0, -.8) if tag == 'F' else V(-m * .5, -.2, -.85))
            n = base['n'].lerp(n, lunge); n = (n - fdir * fdir.dot(n)).normalized()
            A[(tag, s)]['free'] = dict(wr=wr, f=fdir, n=n, pole=base['pole'] + V(0, .1, 0))
            open_ = (-.25, -.05, .05)
            A[(tag, s)]['free_curl'] = [tuple(lerp(o, c, grab) for o, c in zip(open_, (1.0, 1.15, 1.0)))] * 5
    st.update(Spine1=[((1, 0, 0), 6 + 14 * lunge - 8 * wind)], Spine2=[((1, 0, 0), 6 + 12 * lunge - 6 * wind)], Spine3=[((1, 0, 0), 4 + 10 * lunge)],
              Neck=[((1, 0, 0), -6 - 10 * lunge + 8 * wind)], Head=[((1, 0, 0), -6 - 12 * lunge + 10 * wind), ((0, 1, 0), 10 * sn(t, 3) * grab)],
              eye=(0, -8 * lunge), jaw=8 + 30 * lunge + 6 * sn(t, 6) * grab, arms=A)
    st['hips'] = st['hips'] + V(0, -.12 * lunge, -.04 * lunge)
    return st


def clip_hit(t):
    # 맞음: 머리가 뒤로 젖혀지고 팔이 움찔 벌어졌다가 다시 머리를 감싼다
    k = seg(t, 0, .18) * (1 - seg(t, .35, 1.0))
    sh = math.exp(-((t - .12) ** 2) / .004)
    A = arms_wrap(t, .5 + 2.5 * k, 3)
    for tag in SD.ARMS:
        for s, m in SIDES.items():
            A[(tag, s)]['w'] = 1 - .65 * k
            A[(tag, s)]['free_curl'] = [(-.3, -.1, .1)] * 5
    return dict(hips=V(0, .05 * k, -.02 - .03 * k), hips_rot=[((1, 0, 0), -6 * k)], Spine1=[((1, 0, 0), 2 - 8 * k)], Spine2=[((1, 0, 0), 3 - 10 * k), ((0, 1, 0), 6 * sh)],
                Spine3=[((1, 0, 0), 2 - 10 * k)], Neck=[((1, 0, 0), 10 - 22 * k)], Head=[((1, 0, 0), 6 - 20 * k), ((0, 1, 0), 7 + 14 * sh), ((0, 0, 1), 8 * sh)],
                eye=(0, 15 * k), jaw=2 + 22 * k, legs={s: dict(ankle=ANK[s] + V(0, (.06 if s == 'L' else .0) * k, 0)) for s in SIDES}, arms=A)


def clip_death(t):
    # 무릎이 꺾이며 주저앉고(0~.45) 앞으로 고꾸라진다(.45~.7). 팔이 풀려 벌어지고 손가락이 갈고리처럼 오그라들며 몇 번 경련한다
    kneel = seg(t, .05, .42); fall = seg(t, .42, .68); twitch = (bump(t, .74, .8) + .6 * bump(t, .86, .9)) if t > .7 else 0
    rel = seg(t, .1, .5)
    A = arms_wrap(t, .4 + 1.5 * (1 - rel), 3)
    for tag in SD.ARMS:
        for s, m in SIDES.items():
            A[(tag, s)]['w'] = 1 - rel
            base = FREE[(tag, s)]
            wr = V(m * (.45 if tag == 'F' else .55), -.30 if tag == 'F' else -.10, 1.10 if tag == 'F' else 1.55)
            A[(tag, s)]['free'] = dict(base, wr=wr, f=Vector((m * .5, -.6, -.6 if tag == 'F' else .2)).normalized(), n=V(0, -.2, -1), pole=base['pole'])
            A[(tag, s)]['free']['n'] = (A[(tag, s)]['free']['n'] - A[(tag, s)]['free']['f'] * A[(tag, s)]['free']['f'].dot(A[(tag, s)]['free']['n'])).normalized()
            cl = seg(t, .55, .75)
            A[(tag, s)]['free_curl'] = [(.2 + .7 * cl + .2 * twitch, .3 + .9 * cl, .3 + .8 * cl)] * 5
    hz = -.36 * kneel - .30 * fall
    legs = {}
    for s, m in SIDES.items():
        legs[s] = dict(ankle=ANK[s] + V(0, .10 * kneel + .18 * fall, .04 * kneel), pitch=-30 * kneel - 40 * fall, toe=30 * kneel,
                       knee_pole=V(m * .1, -1.0, .3))
    return dict(hips=V(0, .06 * kneel - .30 * fall, hz), hips_rot=[((1, 0, 0), 15 * kneel + 55 * fall)],
                Spine1=[((1, 0, 0), 8 + 10 * fall)], Spine2=[((1, 0, 0), 6 + 8 * fall), ((0, 0, 1), 8 * fall)], Spine3=[((1, 0, 0), 4 + 6 * fall)],
                Neck=[((1, 0, 0), 12 - 30 * fall)], Head=[((1, 0, 0), 6 - 20 * fall + 5 * twitch), ((0, 1, 0), 7 + 25 * fall), ((0, 0, 1), 20 * fall)],
                eye=(0, -20 * fall), jaw=2 + 20 * seg(t, .3, .6) + 8 * twitch, legs=legs, arms=A)


CLIPS = [('Idle', clip_idle, 90, True), ('Walk', clip_walk, 40, True), ('Run', clip_run, 20, True), ('Attack', clip_attack, 40, False),
         ('LookAround', clip_look, 120, True), ('Hit', clip_hit, 20, False), ('Death', clip_death, 75, False),
         ('Count', clip_count, 120, True), ('Peek', clip_peek, 90, True)]
ONLY = os.environ.get('ONLY')

# ---------------------------------------------------------------- 키 굽기
for pb in ARM.pose.bones:
    pb.rotation_mode = 'QUATERNION'
ARM.animation_data_create()
KEYB = [n for n in ORDER if n in DEFORM]
INTERP_LIN = bpy.types.Keyframe.bl_rna.properties['interpolation'].enum_items['LINEAR'].value
made = []
for name, fn, N, loop in CLIPS:
    if ONLY and name not in ONLY.split(','): continue
    rot = {n: [] for n in KEYB}; loc = {n: [] for n in ('Hips',)}
    for f in range(N + 1):
        t = f / N
        P = fn(t if not loop else (f % N) / N)
        pose = build(P)
        for n in KEYB:
            q = pose.L[n].normalized()
            if rot[n] and rot[n][-1].dot(q) < 0: q = -q
            rot[n].append(q)
        loc['Hips'].append(pose.T['Hips'].copy())
    if name in bpy.data.actions: bpy.data.actions.remove(bpy.data.actions[name])
    act = bpy.data.actions.new(name); act.use_fake_user = True
    slot = act.slots.new(id_type='OBJECT', name='Sullae')
    ARM.animation_data.action = act; ARM.animation_data.action_slot = slot
    cb = anim_utils.action_ensure_channelbag_for_slot(act, slot)
    frames = np.arange(N + 1, dtype=float)
    def put(path, idx, vals, grp):
        fc = cb.fcurves.new(path, index=idx, group_name=grp)
        fc.keyframe_points.add(N + 1)
        co = np.empty((N + 1) * 2); co[0::2] = frames; co[1::2] = vals
        fc.keyframe_points.foreach_set('co', co)
        fc.keyframe_points.foreach_set('interpolation', [INTERP_LIN] * (N + 1))
        fc.update()
    for n in KEYB:
        arr = np.array([q[:] for q in rot[n]])
        for i in range(4): put(f'pose.bones["{n}"].rotation_quaternion', i, arr[:, i], n)
    arr = np.array([v[:] for v in loc['Hips']])
    for i in range(3): put('pose.bones["Hips"].location', i, arr[:, i], 'Hips')
    act.use_frame_range = True; act.frame_start = 0; act.frame_end = N; act.use_cyclic = loop
    act['loop'] = int(loop); act['fps'] = FPS
    made.append((name, N, loop))
    log('clip', name, N, 'frames', 'loop' if loop else '')

# 기본 동작: Idle
ARM.animation_data.action = bpy.data.actions['Idle'] if 'Idle' in bpy.data.actions else ARM.animation_data.action
ARM.animation_data.action_slot = ARM.animation_data.action.slots[0]
sc.frame_start, sc.frame_end = 0, 90
# NLA 트랙(엔진·검토용으로 동작을 나란히 보관)
for name, N, loop in made:
    tr = ARM.animation_data.nla_tracks.new(); tr.name = name; tr.mute = True
    act = bpy.data.actions[name]
    st = tr.strips.new(name, 0, act); st.action_slot = act.slots[0]
os.makedirs(OUT, exist_ok=True)
for img in bpy.data.images:
    if img.filepath and os.path.isabs(bpy.path.abspath(img.filepath)):
        pass
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'sullae.blend'), relative_remap=True)
log('SAVED', os.path.join(OUT, 'sullae.blend'))
