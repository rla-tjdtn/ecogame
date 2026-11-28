# 술래(k7h4) 3D 실사판 — 공통 정의: 뼈대(쉬는 자세 = 네 팔을 벌린 자세)와 몸 형태(SDF 부드러운 합집합)
# 단위 m, Blender 좌표(Z 위, 캐릭터는 -Y 를 본다, .L = +X)
# 원본 디자인 art/creatures/source/set1/c8h.js 를 읽어 비율만 옮겼다(원본 파일은 건드리지 않는다).
import math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

S = 0.235  # 디자인 단위 → m (디자인 키 9.4 → 약 2.15 m)


def D(x, y, z):
    """디자인 좌표(x 왼, y 위, z 앞) → Blender(m)"""
    return Vector((x * S, -z * S, y * S))


def nrm(v):
    v = Vector(v)
    return v.normalized()


HEAD_C = D(0, 8.05, .25)  # 머리 중심(쉬는 자세)
EYE_L = (.35, -.09, .73)  # 눈알 중심(머리 로컬, 디자인 단위). 오른쪽은 x 부호만 바꾼다
EYE_RAD = .15 * .235 * .97  # 눈알 반지름(m)


def HL(x, y, z):
    """머리 로컬(디자인 단위, x 왼 y 위 z 앞) → Blender 월드(m)"""
    return HEAD_C + Vector((x * S, -z * S, y * S))


# ---------------------------------------------------------------- 뼈대
# bones: name -> dict(parent, head, tail, z(roll 기준 벡터), deform)
FINGERS = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky']
ARMS = ['F', 'B']  # F = 앞 팔(눈 가림), B = 뒤 팔(정수리 감쌈)
SIDES = {'L': 1, 'R': -1}


def _arm_layout(tag, m):
    """쉬는 자세 팔: 어깨 시작점, 어깨, 팔꿈치, 손목, 손바닥 방향 f, 손바닥 법선 n(손바닥이 보는 쪽)"""
    if tag == 'F':
        c0 = Vector((m * .028, -.012, 1.425))
        sh = Vector((m * .150, -.004, 1.468))
        ud = nrm((m * .93, -.16, -.33)); ul = .300
        el = sh + ud * ul
        fd = nrm((m * .95, -.22, -.12)); fl = .285
        wr = el + fd * fl
        f = nrm((m * .96, -.24, -.10))
        n = nrm((0, -.25, -1))  # 손바닥이 아래·앞을 본다
    else:
        c0 = Vector((m * .026, .040, 1.398))
        sh = Vector((m * .128, .066, 1.418))
        ud = nrm((m * .62, .20, .76)); ul = .360
        el = sh + ud * ul
        fd = nrm((m * .30, .02, .95)); fl = .325
        wr = el + fd * fl
        f = nrm((m * .26, -.02, .97))
        n = nrm((-m * .2, -1, 0))  # 손바닥이 앞을 본다
    n = (n - f * f.dot(n)).normalized()
    return c0, sh, el, wr, f, n


# 손가락: (마디 길이 3개, 뿌리 반지름, 끝 반지름)
FING_LEN = {'Thumb': (.052, .050, .042),  # 엄지: 중수골(Thumb1) + 첫마디(Thumb2) + 끝마디(Thumb3)
            'Index': (.100, .086, .072), 'Middle': (.110, .094, .078),
            'Ring': (.104, .088, .074), 'Pinky': (.090, .076, .064)}
FING_R = {'Thumb': (.0128, .0066), 'Index': (.0102, .0056), 'Middle': (.0106, .0058), 'Ring': (.0100, .0055), 'Pinky': (.0092, .0050)}


def finger_rest(f, n, wr, m, fi):
    """손가락 쉬는 자세의 관절 4점과 법선. fi: 0 엄지 .. 4 새끼"""
    side = f.cross(n).normalized()  # 손바닥 기준 옆 방향
    th = -side * m  # 엄지 쪽
    name = FINGERS[fi]
    if fi == 0:
        # 엄지: 손목 가까이 손바닥 안(엄지두덩)에서 중수골이 시작해 손바닥 앞쪽으로 비스듬히 나온다.
        # 굽힘 방향(nn)이 손바닥을 가로질러 새끼 쪽을 향해서 다른 손가락과 마주 본다(맞섬).
        base = wr + f * .014 + th * .015 + n * .006
        d = (f * .72 + th * .60 + n * .36).normalized()
        nn = (n * .62 - th * .78).normalized()
    else:
        off = (2.5 - fi) * .0195  # 검지가 엄지 쪽
        base = wr + f * .088 + th * off
        sp = math.radians((2.5 - fi) * 7.0)
        d = (f * math.cos(sp) + th * math.sin(sp)).normalized()
        nn = n
    nn = (nn - d * d.dot(nn)).normalized()
    pts = [base]
    cur = base.copy(); dd = d.copy()
    ax = dd.cross(nn).normalized()
    for k, L in enumerate(FING_LEN[name]):
        dd = (Quaternion(ax, math.radians(6 if fi else (3, 10, 8)[k])) @ dd).normalized()  # 살짝 굽은 쉬는 자세
        cur = cur + dd * L
        pts.append(cur.copy())
    return pts, nn


def skeleton():
    B = {}

    def add(name, parent, head, tail, z, deform=True):
        B[name] = dict(parent=parent, head=Vector(head), tail=Vector(tail), z=Vector(z), deform=deform)

    fwd = Vector((0, -1, 0)); up = Vector((0, 0, 1))
    add('Root', None, (0, 0, 0), (0, -.25, 0), up)
    add('Hips', 'Root', (0, .005, .905), (0, .004, 1.005), fwd)
    add('Spine1', 'Hips', (0, .004, 1.005), (0, -.004, 1.135), fwd)
    add('Spine2', 'Spine1', (0, -.004, 1.135), (0, .000, 1.285), fwd)
    add('Spine3', 'Spine2', (0, .000, 1.285), (0, .012, 1.452), fwd)
    add('Neck', 'Spine3', (0, .012, 1.452), (0, -.050, 1.680), fwd)
    add('Head', 'Neck', (0, -.050, 1.680), (0, -.062, 2.120), fwd)
    add('Jaw', 'Head', HL(0, -.12, .02), HL(0, -.80, .55), up)
    for s, m in SIDES.items():
        add(f'Eye.{s}', 'Head', HL(m * EYE_L[0], EYE_L[1], EYE_L[2]), HL(m * EYE_L[0], EYE_L[1], EYE_L[2] + .34), up)
    # 다리
    for s, m in SIDES.items():
        hip = Vector((m * .072, .004, .885)); kn = Vector((m * .084, -.026, .482)); an = Vector((m * .074, .010, .072))
        h = (kn - hip).cross(an - kn).normalized()
        add(f'Thigh.{s}', 'Hips', hip, kn, h.cross((kn - hip).normalized()))
        add(f'Shin.{s}', f'Thigh.{s}', kn, an, h.cross((an - kn).normalized()))
        fd = nrm((-m * .05, -1, -.38)); ball = an + fd * .150; ball.z = .022
        add(f'Foot.{s}', f'Shin.{s}', an, ball, up)
        toe = ball + nrm((-m * .04, -1, -.05)) * .065; toe.z = .016
        add(f'Toe.{s}', f'Foot.{s}', ball, toe, up)
        # IK 컨트롤(변형 안 함)
        add(f'IK_Foot.{s}', 'Root', an + Vector((0, .0, -.0)), an + Vector((0, -.12, 0)), up, False)
        add(f'IK_Knee.{s}', 'Root', kn + Vector((0, -.45, 0)), kn + Vector((0, -.53, 0)), up, False)
    # 팔 넷
    for tag in ARMS:
        for s, m in SIDES.items():
            c0, sh, el, wr, f, n = _arm_layout(tag, m)
            hinge = (el - sh).cross(wr - el).normalized()
            if tag == 'F':
                hinge = -hinge if hinge.z < 0 else hinge
            add(f'Shoulder_{tag}.{s}', 'Spine3', c0, sh, up if tag == 'F' else fwd)
            add(f'UpperArm_{tag}.{s}', f'Shoulder_{tag}.{s}', sh, el, hinge.cross((el - sh).normalized()))
            add(f'LowerArm_{tag}.{s}', f'UpperArm_{tag}.{s}', el, wr, hinge.cross((wr - el).normalized()))
            add(f'Hand_{tag}.{s}', f'LowerArm_{tag}.{s}', wr, wr + f * .088, n)
            for fi, fn in enumerate(FINGERS):
                pts, nn = finger_rest(f, n, wr, m, fi)
                for j in range(3):
                    add(f'{fn}{j + 1}_{tag}.{s}', f'Hand_{tag}.{s}' if j == 0 else f'{fn}{j}_{tag}.{s}', pts[j], pts[j + 1], nn)
            add(f'IK_Hand_{tag}.{s}', 'Root', wr, wr + f * .1, n, False)
            pole = el + (el - (sh + wr) / 2).normalized() * .35
            add(f'IK_Elbow_{tag}.{s}', 'Root', pole, pole + Vector((0, 0, .06)), fwd, False)
    return B


ARM_INFO = {(tag, s): _arm_layout(tag, m) for tag in ARMS for s, m in SIDES.items()}


# ---------------------------------------------------------------- 몸 형태(SDF)
class Prim:
    __slots__ = ('kind', 'a', 'b', 'r1', 'r2', 'R', 'rad', 'k', 'op', 'lo', 'hi', 'grp')

    def __init__(self, kind, k=.01, op='add', grp='body', **kw):
        self.kind, self.k, self.op, self.grp = kind, k, op, grp
        for key, v in kw.items():
            setattr(self, key, v)
        self._bbox()

    def _bbox(self):
        if self.kind == 'cone':
            a, b = np.array(self.a), np.array(self.b); r = max(self.r1, self.r2)
            self.lo = np.minimum(a, b) - r; self.hi = np.maximum(a, b) + r
        elif self.kind == 'ell':
            r = max(self.rad); c = np.array(self.a)
            self.lo = c - r; self.hi = c + r
        elif self.kind == 'torus':
            c = np.array(self.a); r = self.r1 + self.r2
            self.lo = c - r; self.hi = c + r
        elif self.kind == 'cap':
            c = np.array(self.a); self.lo = c - self.r1; self.hi = c + self.r1


def cone(a, b, r1, r2=None, **kw):
    return Prim('cone', a=tuple(a), b=tuple(b), r1=r1, r2=r1 if r2 is None else r2, **kw)


def ball(c, r, **kw):
    return Prim('cone', a=tuple(c), b=tuple(Vector(c) + Vector((0, 0, 1e-5))), r1=r, r2=r, **kw)


def ell(c, rad, rot=None, **kw):
    R = np.eye(3) if rot is None else np.array(rot)  # 열 = 로컬 축(월드)
    return Prim('ell', a=tuple(c), rad=tuple(rad), R=R, **kw)


def cap(c, R, normal, h, round_=.003, **kw):
    """구(c, R) 중 평면 dot(p-c, n) >= h 쪽만 남긴 뚜껑(눈꺼풀). 모서리를 round_ 만큼 둥글린다"""
    return Prim('cap', a=tuple(c), r1=R, R=np.array(nrm(normal)[:]), r2=h, b=round_, **kw)


def prim_points(p, U):
    """복셀 리메시용 볼록 껍질 점들"""
    if p.kind == 'cone':
        return np.vstack([np.array(p.a) + U * p.r1, np.array(p.b) + U * p.r2])
    if p.kind == 'cap':
        c = np.array(p.a); n = p.R; Q = c + U * p.r1
        keep = (Q - c) @ n >= p.r2
        t = np.cross(n, [0, 0, 1] if abs(n[2]) < .9 else [1, 0, 0]); t /= np.linalg.norm(t); u = np.cross(n, t)
        rr = math.sqrt(max(p.r1 ** 2 - p.r2 ** 2, 1e-9))
        ring = np.array([c + n * p.r2 + (t * math.cos(a) + u * math.sin(a)) * rr for a in np.linspace(0, math.tau, 48, endpoint=False)])
        return np.vstack([Q[keep], ring])
    return np.array(p.a) + (U * np.array(p.rad)) @ np.array(p.R).T


def torus(c, axis, R, r, **kw):
    ax = nrm(axis); t = ax.orthogonal().normalized(); u = ax.cross(t)
    M = np.array([[t.x, ax.x, u.x], [t.y, ax.y, u.y], [t.z, ax.z, u.z]])
    return Prim('torus', a=tuple(c), r1=R, r2=r, R=M, **kw)


def frame_rot(x, y, z):
    """y 를 주축으로, z 를 y 에 직교화한 정규직교 프레임(x 는 무시하고 y×z 로 다시 만든다)"""
    y = nrm(y); z = Vector(z)
    z = z - y * y.dot(z)
    if z.length < 1e-6:
        z = y.orthogonal()
    z.normalize(); x = y.cross(z)
    return [[x.x, y.x, z.x], [x.y, y.y, z.y], [x.z, y.z, z.z]]


def tube(pts, r, k=.004, **kw):
    rs = r if isinstance(r, (list, tuple)) else [r] * len(pts)
    return [cone(pts[i], pts[i + 1], rs[i], rs[i + 1], k=k, **kw) for i in range(len(pts) - 1)]


def prims():
    P = []
    s = S
    # --- 다리 · 발
    for sd, m in SIDES.items():
        hip = Vector((m * .072, .004, .885)); kn = Vector((m * .084, -.026, .482)); an = Vector((m * .074, .010, .072))
        P += [cone(hip + Vector((m * .006, 0, .02)), kn + Vector((0, .004, .03)), .056, .036, k=.03)]
        P += [ell(hip.lerp(kn, .35) + Vector((m * .008, -.010, 0)), (.040, .042, .11), k=.03)]  # 허벅지 살
        P += [ball(kn + Vector((0, -.008, 0)), .038, k=.016), ball(kn + Vector((0, -.030, .005)), .022, k=.012)]  # 무릎·슬개골
        P += [cone(kn, an, .033, .020, k=.016)]
        P += [ell(kn.lerp(an, .28) + Vector((0, .018, 0)), (.030, .030, .085), k=.022)]  # 종아리(말랐다)
        P += [cone(kn.lerp(an, .15) + Vector((0, -.022, 0)), an + Vector((0, -.012, .02)), .011, .008, k=.01)]  # 정강이뼈
        P += [ball(an + Vector((m * .014, 0, 0)), .015, k=.012), ball(an + Vector((-m * .012, 0, .006)), .014, k=.012)]  # 복사뼈
        fd = nrm((-m * .05, -1, -.38)); ball_p = an + fd * .150; ball_p.z = .022
        P += [ell(Vector((an.x, an.y + .022, .030)), (.028, .036, .030), k=.012)]  # 발꿈치
        P += [cone(Vector((an.x, an.y + .02, .028)), ball_p + Vector((0, 0, .004)), .027, .020, k=.015)]
        P += [ell(an.lerp(ball_p, .55) + Vector((0, 0, .012)), (.028, .06, .014), rot=frame_rot((1, 0, 0), fd, (0, 0, 1)), k=.015)]
        td = nrm((-m * .04, -1, -.05))
        for t in range(5):
            o = (t - 2) * .0150 * m + (t == 0) * -.004 * m; ln = (.050, .040, .036, .032, .026)[t]; rr = (.0092, .0066, .0062, .0058, .0054)[t]  # 엄지발가락이 안쪽(몸 가운데 쪽)
            b0 = ball_p + Vector((o, .010, .000)) - td * .006 * (abs(t - 1))
            b1 = b0 + td * ln * .55 + Vector((0, 0, .003)); b2 = b0 + td * ln + Vector((0, 0, -.006))
            P += tube([b0, b1, b2], [rr * 1.05, rr, rr * .85], k=.003)
    # --- 골반 · 배 · 가슴(천으로 덮이지만 형태는 있다)
    P += [ell((0, .006, .925), (.118, .082, .085), k=.03)]
    P += [ell((0, -.030, 1.075), (.104, .088, .112), k=.04)]  # 볼록한 배
    P += [cone((0, .004, .98), (0, .012, 1.30), .085, .080, k=.04)]
    P += [ell((0, .012, 1.330), (.128, .080, .150), k=.035)]  # 갈비뼈 통
    P += [ell((0, .020, 1.420), (.150, .066, .052), k=.03)]  # 어깨 윤곽
    for i in range(5):  # 갈비뼈가 비친다(몸통 윤곽 안쪽에 붙인다)
        z = 1.40 - i * .038
        w = max(.080, .128 * math.sqrt(max(0, 1 - ((z - 1.33) / .15) ** 2))) - .006
        for m in (-1, 1):
            a = Vector((m * .022, -.066 + i * .002, z + .006)); b = Vector((m * (w - .008), -.030, z - .016)); c = Vector((m * (w - .020), .030, z - .006))
            P += tube([a, b, c], .0055, k=.014)
    for i in range(9):  # 등뼈
        z = 1.44 - i * .055
        P += [ball((0, .078 - (i > 5) * .01, z), .013, k=.01)]
    for m in (-1, 1):  # 쇄골
        P += [cone((m * .020, -.050, 1.440), (m * .140, -.010, 1.470), .010, .012, k=.012)]
        P += [ell((m * .065, .060, 1.37), (.06, .025, .07), k=.025)]  # 견갑
    P += [ball((0, -.094, 1.075), .007, op='sub', k=.006)]  # 배꼽
    # --- 목 · 머리
    P += [cone((0, .014, 1.43), (0, -.040, 1.72), .040, .036, k=.03)]
    for m in (-1, 1):
        P += [cone((m * .016, -.034, 1.458), (m * .040, -.004, 1.690), .0095, .0085, k=.022)]  # 목빗근
    P += [cone((0, .050, 1.47), HL(0, -.35, -.65), .022, .018, k=.02)]  # 목덜미
    P += [ell(HL(0, .22, -.08), (.98 * s, 1.02 * s, .95 * s), k=.038)]  # 커다란 두개
    P += [ell(HL(0, -.42, .22), (.72 * s, .66 * s, .56 * s), k=.038)]  # 얼굴 아래
    for m in (-1, 1):
        P += [ell(HL(m * .48, -.50, .48), (.30 * s, .28 * s, .30 * s), k=.03)]  # 볼살
        P += [ell(HL(m * .40, .16, .70), (.30 * s, .16 * s, .16 * s), k=.02)]  # 눈두덩
    P += [ell(HL(0, -.82, .50), (.22 * s, .20 * s, .16 * s), k=.025)]  # 턱
    P += [ell(HL(0, -.26, .90), (.13 * s, .12 * s, .13 * s), k=.025)]  # 들창코
    for m in (-1, 1):
        P += [ell(HL(m * .09, -.33, .96), (.035 * s, .035 * s, .04 * s), op='sub', k=.01)]  # 콧구멍
        P += [ell(HL(m * .36, -.08, .86), (.21 * s, .19 * s, .20 * s), op='sub', k=.03)]  # 눈구멍
    for m in (-1, 1):
        # 눈꺼풀: 눈알보다 4.5mm 큰 구의 위·아래 뚜껑. 윗눈꺼풀이 동공 위까지 반쯤 내려오고 바깥 끝이 처진다
        ec = HL(m * EYE_L[0], EYE_L[1], EYE_L[2]); lr = EYE_RAD + .0045
        P += [cap(ec, lr, (-m * .16, .10, 1), .0055, round_=.0035, k=.010)]  # 윗눈꺼풀
        P += [cap(ec, lr, (m * .10, .18, -1), .0150, round_=.0035, k=.010)]  # 아랫눈꺼풀
        P += [cap(ec, lr + .0035, (-m * .10, .20, 1), .0150, round_=.004, k=.012)]  # 쌍꺼풀 위 두툼한 살
    P += [ell(HL(0, -.535, .84), (.15 * s, .045 * s, .045 * s), k=.02)]  # 윗입술
    P += [ell(HL(0, -.655, .80), (.13 * s, .05 * s, .045 * s), k=.02)]  # 아랫입술
    P += tube([HL(-.28, -.60, .80), HL(0, -.585, .93), HL(.28, -.60, .80)], .022 * s, op='sub', k=.012)  # 입 틈
    # 머리 디테일: 앞이마 두 혹, 관자놀이 꺼짐, 숫구멍(정수리 오목), 이마 주름, 눈 밑 주름, 두피 핏줄
    cc = Vector((0, .22, -.08)); cr = Vector((.98, .95, 1.02))
    def on_skull(x, y, lift=0.0):
        """머리 로컬 방향(x,y,앞) → 두개 타원 표면 위 점(m)"""
        u = Vector((x, y - cc.y, 0)); z2 = 1 - (u.x / cr.x) ** 2 - (u.y / cr.y) ** 2
        z = cc.z + cr.z * math.sqrt(max(z2, 0))
        p = Vector((x, y, z)); dirv = (p - cc); nrm_ = Vector((dirv.x / cr.x ** 2, dirv.y / cr.y ** 2, dirv.z / cr.z ** 2)).normalized()
        q = p + nrm_ * lift
        return HL(q.x, q.y, q.z)
    def on_skull_dir(dx, dy, dz, lift=0.0):
        d_ = Vector((dx, dy, dz)).normalized(); t = 1 / math.sqrt((d_.x / cr.x) ** 2 + (d_.y / cr.y) ** 2 + (d_.z / cr.z) ** 2)
        p = cc + d_ * t; nrm_ = Vector(((p - cc).x / cr.x ** 2, (p - cc).y / cr.y ** 2, (p - cc).z / cr.z ** 2)).normalized()
        q = p + nrm_ * lift
        return HL(q.x, q.y, q.z)
    for m in (-1, 1):
        P += [ell(on_skull(m * .36, .62, -.10), (.17 * s, .15 * s, .14 * s), k=.03)]  # 앞이마 혹
        P += [ell(on_skull_dir(m * 1, -.05, .45, .05), (.10 * s, .22 * s, .22 * s), op='sub', k=.05)]  # 관자놀이 꺼짐
    # 이마 주름 홈·두피 핏줄 돌기는 넣지 않는다(깔끔한 이마). 핏줄은 피부 텍스처로만 비친다
    for m in (-1, 1):  # 귀
        P += [ell(HL(m * .95, -.22, -.12), (.12 * s, .19 * s, .05 * s), rot=frame_rot(None, (m * .25, .35, 1), (m, 0, 0)), k=.016)]  # 귀(뒤로 누운 작은 귀)
        P += [ell(HL(m * .99, -.24, -.08), (.06 * s, .11 * s, .02 * s), rot=frame_rot(None, (m * .25, .35, 1), (m, 0, 0)), op='sub', k=.014)]
    # --- 팔 넷
    for (tag, sd), (c0, sh, el, wr, f, n) in ARM_INFO.items():
        m = SIDES[sd]
        ru = .036 if tag == 'F' else .033
        P += [ball(sh, ru * 1.15, k=.03)]
        P += [cone(sh, el, ru, ru * .74, k=.02)]
        P += [ell(sh.lerp(el, .4), (ru * .9, (el - sh).length * .32, ru * .9), rot=frame_rot(None, el - sh, (el - sh).orthogonal()), k=.02)]
        P += [ball(el, ru * .82, k=.014)]
        hinge = (el - sh).cross(wr - el).normalized()
        P += [ball(el + (el - (sh + wr) / 2).normalized() * .016, .016, k=.01)]  # 팔꿈치뼈
        P += [cone(el, wr, ru * .78, .021, k=.014)]
        P += [ell(el.lerp(wr, .3), (ru * .75, (wr - el).length * .28, ru * .75), rot=frame_rot(hinge, (wr - el), hinge.cross((wr - el).normalized())), k=.016)]
        side = f.cross(n).normalized(); th = -side * m
        P += [ball(wr + th * .012, .017, k=.008), ball(wr - th * .012, .016, k=.008)]  # 손목뼈
        # 손바닥(평평한 타원)
        P += [ell(wr + f * .046 + n * .002, (.040, .050, .0135), rot=frame_rot(th, f, n), k=.012)]
        tp, tnn = finger_rest(f, n, wr, m, 0)
        P += [ell(tp[0].lerp(tp[1], .45) + n * .002 - tnn * .002, (.017, .032, .0135), rot=frame_rot(None, tp[1] - tp[0], n), k=.012)]  # 엄지두덩(중수골을 감싼다)
        P += [ell(wr + f * .040 - th * .029 + n * .008, (.012, .034, .0095), rot=frame_rot(None, f, n), k=.01)]  # 새끼두덩
        # 손바닥 주름 세 줄(손바닥 표면 높이에 얕게 판다)
        def palm_pt(u, v):
            h = .0135 * math.sqrt(max(0, 1 - (u / .040) ** 2 - ((v - .046) / .050) ** 2)) + .002
            return wr + th * u + f * v + n * (h - .0002)
        for line in (((-.036, .074), (-.008, .071), (.016, .064)), ((.030, .060), (.004, .056), (-.028, .050)), ((.022, .062), (.012, .040), (.009, .016))):
            P += tube([palm_pt(u, v) for u, v in line], .0013, op='sub', k=.001, grp='finger')
        for fi, fn in enumerate(FINGERS):
            pts, nn = finger_rest(f, n, wr, m, fi)
            r0, r3 = FING_R[fn]
            rr = [r0, r0 * .86 + r3 * .14, r0 * .55 + r3 * .45, r3]
            if fi:
                P += [cone(wr + f * .012 + th * ((2.5 - fi) * .012) - n * .006, pts[0] - n * .004, .0042, .0040, k=.006)]  # 손등 힘줄
                P += [ball(pts[0] - n * .002, r0 * 1.12, k=.006)]  # 손가락 뿌리 마디
            for j in range(3):
                P += [cone(pts[j], pts[j + 1], rr[j], rr[j + 1], k=.0035, grp='finger')]
                if j:
                    d = (pts[j + 1] - pts[j - 1]).normalized(); sd_ = d.cross(nn).normalized()
                    P += [ell(pts[j] - nn * rr[j] * .22, (rr[j] * 1.06, rr[j] * 1.25, rr[j] * 1.0), rot=frame_rot(None, d, nn), k=.004, grp='finger')]  # 마디(살짝 굵다)
                    # 손등 쪽 마디 주름: 짧게 휜 가로 골 여러 줄
                    for o in (-.0042, -.0021, 0, .0021, .0040):
                        w = rr[j] * (.55 + .2 * (o == 0))
                        P += [ell(pts[j] + d * (o + .001) - nn * (rr[j] * 1.02 + .0004), (w, .0010, .0011), rot=frame_rot(None, d, nn), op='sub', k=.0007, grp='finger')]
                    # 손바닥 쪽 굽힘 주름 두 줄
                    for o in (-.0016, .0016):
                        P += [ell(pts[j] + d * o + nn * (rr[j] * 1.02 + .0004), (rr[j] * .8, .0010, .0011), rot=frame_rot(None, d, nn), op='sub', k=.0007, grp='finger')]
            P += [ell(pts[3] - (pts[3] - pts[2]).normalized() * .006 + nn * rr[3] * .25, (rr[3] * 1.05, rr[3] * 1.6, rr[3] * .9),
                      rot=frame_rot((pts[3] - pts[2]).cross(nn), (pts[3] - pts[2]), nn), k=.003, grp='finger')]  # 손가락 끝 살
            dd3 = (pts[3] - pts[2]).normalized()
            P += [ell(pts[2].lerp(pts[3], .62) - nn * rr[3] * 1.05, (rr[3] * .95, (pts[3] - pts[2]).length * .30, .0006), rot=frame_rot(None, dd3, nn), op='sub', k=.0008, grp='finger')]  # 손톱 바닥 홈
    return P


# ---------------------------------------------------------------- numpy SDF
def _rcone(P, a, b, r1, r2):
    a = np.asarray(a); b = np.asarray(b)
    ba = b - a; l2 = ba @ ba; rr = r1 - r2; a2 = l2 - rr * rr; il2 = 1.0 / l2
    pa = P - a; y = pa @ ba; z = y - l2
    q = pa * l2 - np.outer(y, ba); x2 = np.einsum('ij,ij->i', q, q)
    y2 = y * y * l2; z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


def _ell(P, c, rad, R):
    q = (P - np.asarray(c)) @ R  # 로컬
    r = np.asarray(rad)
    k0 = np.linalg.norm(q / r, axis=1); k1 = np.linalg.norm(q / (r * r), axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def _torus(P, c, Rr, r, M):
    q = (P - np.asarray(c)) @ M
    xz = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - Rr
    return np.sqrt(xz * xz + q[:, 1] ** 2) - r


def prim_d(p, P):
    if p.kind == 'cone':
        return _rcone(P, p.a, p.b, p.r1, p.r2)
    if p.kind == 'ell':
        return _ell(P, p.a, p.rad, p.R)
    if p.kind == 'cap':
        q = P - np.asarray(p.a)
        ds = np.linalg.norm(q, axis=1) - p.r1; dp = p.r2 - q @ p.R
        return -smin(-ds, -dp, p.b)  # 부드러운 교집합
    return _torus(P, p.a, p.r1, p.r2, p.R)


def smin(a, b, k):
    h = np.clip(.5 + .5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def sdf(P, plist, masks=None):
    d = np.full(len(P), 10.0)
    for i, p in enumerate(plist):
        idx = masks[i] if masks is not None else np.nonzero(np.all((P >= p.lo - p.k - .02) & (P <= p.hi + p.k + .02), axis=1))[0]
        if len(idx) == 0:
            continue
        di = prim_d(p, P[idx])
        if p.op == 'add':
            d[idx] = smin(d[idx], di, p.k)
        else:
            d[idx] = -smin(-d[idx], di, p.k)
    return d


def project(P, plist, iters=4, h=.0004):
    P = P.copy()
    for it in range(iters):
        masks = [np.nonzero(np.all((P >= p.lo - p.k - .03) & (P <= p.hi + p.k + .03), axis=1))[0] for p in plist]
        f = sdf(P, plist, masks)
        g = np.zeros_like(P)
        for ax in range(3):
            e = np.zeros(3); e[ax] = h
            g[:, ax] = (sdf(P + e, plist, masks) - sdf(P - e, plist, masks)) / (2 * h)
        gl2 = np.maximum(np.einsum('ij,ij->i', g, g), 1e-6)
        step = (f / gl2)[:, None] * g
        sl = np.linalg.norm(step, axis=1)
        step *= np.minimum(1, .012 / np.maximum(sl, 1e-9))[:, None]
        P -= step
        print(f'  project it{it}: |f| mean {np.abs(f).mean():.5f} max {np.abs(f).max():.5f}', flush=True)
    return P
