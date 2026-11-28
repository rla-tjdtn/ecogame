# 팔 4개 + 사람 손 — 묶는 자세(bind pose)는 팔을 펼친 자세로 만든다:
#   앞팔 _F: 어깨에서 옆으로 펼침(손바닥 아래), 뒤팔 _B: 날개뼈에서 바깥·위로 펼침.
# 눈꺼풀을 붙잡는 자세는 뼈대(IK)로 잡는다 — 그 목표 자리(시안 손목·손 방향·팔꿈치)는 hold 로 같이 돌려준다.
# 돌려주는 것: Geo 목록(정점 속성 armpart = 뼈 묶음 번호), joints(뼈 머리·꼬리·위 방향), hold(IK 목표), parts(번호 → 뼈 목록)
import math
import numpy as np
from tt_common import Geo, tube, nrm, smooth, rot, neck

S = 0.235
HS = 1.3                          # 시안 손 크기에 맞춘 배율(시안 손가락이 길다)
FINGERS = [('Index', .027 * HS, tuple(x * 1.35 for x in (.06, .036, .029)), .0086 * 1.18, 6), ('Middle', .009 * HS, tuple(x * 1.35 for x in (.067, .041, .031)), .009 * 1.18, 1),
           ('Ring', -.009 * HS, tuple(x * 1.35 for x in (.063, .038, .029)), .0085 * 1.18, -4), ('Pinky', -.026 * HS, tuple(x * 1.35 for x in (.05, .031, .025)), .0074 * 1.18, -10)]
PALM = .1 * 1.15
REST_CURL = (8, 10, 8)            # 펼친 손의 살짝 굽은 손가락(도)
HAND_LIFT = .006                  # 손목(손등 쪽 뼈)이 눈꺼풀 바깥 살 위로 뜨는 높이 — 손이 머리 표면에 붙게
ARM_LEN = {'F': (.40, .52), 'B': (.58, .53)}     # 위팔, 아래팔(m)
GRIP = {'F': (30, 44, 36), 'B': (30, 44, 36)}     # 눈꺼풀을 움켜쥘 때 더하는 굽힘(animate.py 기본 자세)


def tip_local(extra):
    """손 추상 좌표(a 엄지쪽, b 손가락, c 손바닥)에서 검지·중지·약지 끝 평균 — 굽힘 = REST + extra."""
    C = np.array([0, 0, 1.0]); tips = []
    for nm, ao, Ls, r0, spr in FINGERS[:3]:
        d0 = np.array([math.sin(math.radians(spr)), math.cos(math.radians(spr)), 0]); ax = np.cross(d0, C)
        J = np.array([ao, PALM + .003, -.004]); acc = 0
        for L, cu, ex in zip(Ls, REST_CURL, extra):
            acc += math.radians(cu + ex); J = J + rot(d0, ax, acc) * L
        tips.append(J)
    return np.mean(tips, 0)


def W(p):
    p = np.asarray(p, float)
    return neck(np.array([p[0], -p[2], p[1]]) * S)


def _segs(g):
    return [(W(p['a']), W(p['b'])) for p in g['prims'] if not p['op'] and p['t'] == 0 and np.linalg.norm(np.subtract(p['a'], p['b'])) > 1e-4]


# (이름, 시안 어깨, 시안 팔꿈치, 시안 팔·손바닥·손가락·엄지 그룹)
ARMS = [('F', [1.05, 6.95, -.02], [2.0, 6.5, .75], 98, 100, range(101, 105), 105),
        ('B', [.8, 7.2, -.45], [2.0, 8.9, -.45], 106, 108, range(109, 113), 113)]


def _hold(G, ga, gh, gfs, gt):
    """시안 손(눈꺼풀을 잡은 자세)에서 손목·손가락 방향·손바닥 방향."""
    palm_start = np.mean([s[0] for s in _segs(G[gh])[:4]], 0)
    ends = np.array([p for s in _segs(G[ga]) for p in s])
    Wr = ends[np.argmin(np.linalg.norm(ends - palm_start, axis=1))]
    chains = []
    for gf in gfs:
        sg = _segs(G[gf]); chains.append([sg[0][0]] + [s[1] for s in sg])
    K = np.mean([c[0] for c in chains], 0)
    D = nrm(K - Wr)
    Pn = nrm(np.mean([nrm((c[3] - c[1]) - nrm(c[1] - c[0]) * np.dot(c[3] - c[1], nrm(c[1] - c[0]))) for c in chains], 0))
    Pn = nrm(Pn - D * np.dot(Pn, D))
    T = np.mean([c[3] for c in chains[:3]], 0)
    return Wr, D, Pn, T


def _hand(parts, joints, sd, Wr, D, P, code0):
    """손 하나(세계 좌표). D 손가락 방향, P 손바닥이 보는 쪽. 엄지 쪽 = P×D."""
    X = nrm(np.cross(P, D)); M = np.stack([X, D, P], 1)
    w = lambda v: Wr + M @ np.asarray(v, float)
    # 손바닥
    g = Geo('Palm' + sd, 'Body')
    tube(g, [w((0, -.03, .002)), w((0, 0, 0)), w((0, .05, -.002)), w((0, PALM, -.004))], [.024 * HS, .03 * HS, .04 * HS, .042 * HS], [.016, .018, .018, .014],
         n=18, seglen=.012, up=P, power=2.3, caps=('round', 'round'),
         shape=lambda s, a: 1 + .12 * max(0.0, math.cos(a)) ** 4 * math.exp(-((s - .3) / .2) ** 2))   # 엄지두덩
    g.setattr_('armpart', range(g.nv()), np.full(g.nv(), code0 + 2.0)); parts.append(g)
    joints['Hand' + sd] = (Wr, w((0, PALM, -.004)), P, 'LowerArm' + sd)
    C = np.array([0, 0, 1.0])
    for fi, (nm, ao, Ls, r0, spr) in enumerate(FINGERS):
        d0 = np.array([math.sin(math.radians(spr)), math.cos(math.radians(spr)), 0]); ax = np.cross(d0, C)
        J = [np.array([ao, PALM + .003, -.004])]; cs = [C]; acc = 0
        for L, cu in zip(Ls, REST_CURL):
            acc += math.radians(cu); J.append(J[-1] + rot(d0, ax, acc) * L); cs.append(rot(C, ax, acc))
        Jw = [w(j) for j in J]
        pts = [w(J[0] - d0 * .016), Jw[0], (Jw[0] + Jw[1]) / 2, Jw[1], (Jw[1] + Jw[2]) / 2, Jw[2], (Jw[2] * 2 + Jw[3]) / 3, Jw[3] - (Jw[3] - Jw[2]) * .18]
        rr = [r0 * .95, r0 * 1.1, r0 * .9, r0 * 1.0, r0 * .84, r0 * .9, r0 * .8, r0 * .74]
        g = Geo('%s%s' % (nm, sd), 'Body')
        info = tube(g, pts, rr, [x * .85 for x in rr], n=10, seglen=r0 * .9, up=M @ C, caps=('round', 'round'), capk=.85)
        dorsal = -(M @ cs[3])
        sdist = np.minimum((info['rd'] @ dorsal - .4) * .02, (info['s'] - .8) * info['L'])
        g.setattr_('nail', range(g.nv()), np.clip(.5 + sdist * 90, 0, 1))
        g.setattr_('armpart', range(g.nv()), np.full(g.nv(), code0 + 3.0 + fi)); parts.append(g)
        for k in range(3):
            joints['%s%d%s' % (nm, k + 1, sd)] = (Jw[k], Jw[k + 1], M @ cs[k + 1], 'Hand' + sd if k == 0 else '%s%d%s' % (nm, k, sd))
    # 엄지
    tb = np.array([.024 * HS, .014, .008]); d0 = nrm((.68, .62, .34)); ct = nrm(np.array([-.5, .1, 1.0]) - d0 * np.dot((-.5, .1, 1.0), d0))
    ax = np.cross(d0, ct); J = [tb]; cs = [ct]; acc = 0
    for L, cu in zip((.044 * 1.3, .035 * 1.3, .03 * 1.3), (4, 10, 10)):
        acc += math.radians(cu); J.append(J[-1] + rot(d0, ax, acc) * L); cs.append(rot(ct, ax, acc))
    Jw = [w(j) for j in J]
    pts = [w(tb - d0 * .02), Jw[0], Jw[1], (Jw[1] + Jw[2]) / 2, Jw[2], Jw[3] - (Jw[3] - Jw[2]) * .2]
    rr = [x * 1.18 for x in (.015, .0135, .0112, .0098, .0102, .0082)]
    g = Geo('Thumb' + sd, 'Body')
    info = tube(g, pts, rr, [x * .86 for x in rr], n=10, seglen=.009, up=M @ ct, caps=('round', 'round'), capk=.85)
    dorsal = -(M @ cs[3])
    sdist = np.minimum((info['rd'] @ dorsal - .4) * .02, (info['s'] - .8) * info['L'])
    g.setattr_('nail', range(g.nv()), np.clip(.5 + sdist * 90, 0, 1))
    g.setattr_('armpart', range(g.nv()), np.full(g.nv(), code0 + 7.0)); parts.append(g)
    for k in range(3):
        joints['Thumb%d%s' % (k + 1, sd)] = (Jw[k], Jw[k + 1], M @ cs[k + 1], 'Hand' + sd if k == 0 else 'Thumb%d%s' % (k, sd))


def _arm(parts, S_, El, Wr, bend_n, code0, sd):
    """앙상한 팔 관: 삼각근, 가는 위팔, 뾰족한 팔꿈치 뼈, 두 뼈 능선의 아래팔, 손목 뼈."""
    u = nrm(El - S_); f = nrm(Wr - El)
    back = nrm(np.cross(bend_n, u))            # 팔꿈치 뒤쪽(굽는 면 바깥)
    pts = [S_ - u * .05, S_, S_ + (El - S_) * .3, S_ + (El - S_) * .65, El - u * .022, El + f * .022,
           El + (Wr - El) * .3, El + (Wr - El) * .7, Wr + f * .012]
    d = np.r_[0, np.cumsum([np.linalg.norm(b - a) for a, b in zip(pts[:-1], pts[1:])])]; d /= d[-1]
    sS, sE, sU = d[1], (d[4] + d[5]) / 2, (d[2] + d[3]) / 2
    rx = [.04, .043, .031, .028, .027, .027, .031, .024, .02]
    ry = [r * q for r, q in zip(rx, [1, .95, .95, .95, .95, .9, .82, .72, .7])]

    def shape(s, a):
        sa, ca = math.sin(a), math.cos(a)
        v = 1.0
        v += .34 * max(0.0, sa) ** 6 * math.exp(-((s - sE) / .032) ** 2)
        v += .16 * abs(ca) ** 6 * math.exp(-((s - sE) / .028) ** 2)
        band = smooth(sE + .04, sE + .1, s) * (1 - smooth(.93, .99, s))
        v += .07 * (max(0.0, math.cos(a - 1.0)) ** 8 + max(0.0, math.cos(a + 1.0)) ** 8) * band
        v -= .04 * max(0.0, sa) ** 2 * band
        v += .08 * max(0.0, -sa) ** 4 * math.exp(-((s - sU) / .09) ** 2)
        v += .05 * max(0.0, sa) ** 4 * math.exp(-((s - sU + .04) / .1) ** 2)
        v += .12 * math.exp(-((s - sS) / .05) ** 2) * (.6 + .4 * max(0.0, -ca))
        v += .16 * max(0.0, math.cos(a + 1.2)) ** 8 * math.exp(-((s - .965) / .025) ** 2)
        return v
    g = Geo('Arm' + sd, 'Body')
    tube(g, pts, rx, ry, n=14, seglen=.014, up=back, caps=('round', 'round'), shape=shape)
    g.setattr_('armpart', range(g.nv()), np.full(g.nv(), code0 + 1.0)); parts.append(g)


def build_limbs(G):
    """왼쪽(.L)을 만들고 거울로 오른쪽(.R)."""
    parts, joints, hold, groups = [], {}, {}, {}
    from lids import lid_grab
    _E = W(G[23]['prims'][0]['a'])
    for ai, (hk, s_, e_, ga, gh, gfs, gt) in enumerate(ARMS):
        sd = '_%s.L' % hk
        code0 = 10.0 * (ai + 1)
        S_ = W(s_)
        Wd, Dh, Ph, Td = _hold(G, ga, gh, gfs, gt)
        # 붙잡는 자세의 손목: 굽힌 손가락 끝(새 손 크기)이 시안 손가락 끝 자리에 오도록
        Xh = nrm(np.cross(Ph, Dh)); Mh = np.stack([Xh, Dh, Ph], 1)
        # 손가락 끝 목표 = 새 눈알 머리(head.py)의 눈꺼풀 가장자리 바로 바깥
        Td = lid_grab(_E, 1.12 * S - .003, -62 if hk == 'F' else 62, out=-.002)
        # 손 4개가 눈꺼풀을 잡아 벌리는 자세: 손은 머리 표면에 눕고(손바닥이 머리 쪽), 손가락은 눈 앞쪽(눈구멍)을 향해
        # 굽은 손가락 끝이 눈꺼풀 가장자리에 걸린다. 손목이 머리 표면(+손 두께) 높이에 오도록 손 기울기를 찾는다.
        nT = nrm(Td - _E); front = _E + np.array([0, -1.0, 0]) * np.linalg.norm(Td - _E)
        D0 = nrm((front - Td) - nT * np.dot(front - Td, nT)); X0 = nrm(np.cross(-nT, D0))
        Rw = np.linalg.norm(Td - _E) + HAND_LIFT
        best = None
        for al in np.radians(np.linspace(-60, 60, 241)):
            Dh = nrm(D0 * math.cos(al) - nT * math.sin(al)); Ph = nrm(np.cross(Dh, X0))
            if np.dot(Ph, nT) > 0:
                Ph = -Ph
            Xh = nrm(np.cross(Ph, Dh)); Mh = np.stack([Xh, Dh, Ph], 1)
            Wt = Td - Mh @ tip_local(GRIP[hk]); err = abs(np.linalg.norm(Wt - _E) - Rw)
            if best is None or err < best[0]:
                best = (err, Dh, Ph, Mh, Wt)
        _, Dh, Ph, Mh, Wh = best
        # 손으로 눈꺼풀을 벌릴 만큼 긴 팔(사용자 요청): 위팔·아래팔 길이
        L1, L2 = ARM_LEN[hk]
        # 붙잡는 자세의 팔꿈치: 이 길이로 두 뼈 IK 를 풀되, 시안 팔꿈치가 있던 쪽으로 꺾음
        Ed = W(e_); dv = Wh - S_; dist = min(np.linalg.norm(dv), (L1 + L2) * .995); dn = nrm(dv)
        print("REACH", hk, round(float(np.linalg.norm(dv)), 3), "of", round(L1 + L2, 3))
        aa = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist); hh = math.sqrt(max(L1 * L1 - aa * aa, 0))
        pole = Ed - (S_ + Wh) / 2
        if hk == 'F':
            pole = (S_ + np.array([.12, -.30, -.35])) - (S_ + dn * aa)   # 아래 팔: 팔꿈치를 어깨 아래(조금 바깥·앞)에 가장 가깝게 — 아래팔이 밑에서 올라와 손목이 덜 꺾이게
        pole = nrm(pole - dn * np.dot(pole, dn))
        El_hold = S_ + dn * aa + pole * hh
        if hk == 'F':
            A = nrm((1, 0, -.18)); fdir = nrm((1, -.12, -.18))     # 옆으로, 아래팔은 살짝 앞으로(굽는 면 정함)
            P = np.array([0, 0, -1.0])
        else:
            A = nrm((.62, .38, .68)); fdir = nrm((.62, .25, .74))  # 바깥·뒤·위로
            P = nrm(np.cross(A, (0, 1.0, 0)))
            if P[2] > 0:
                P = -P
        El = S_ + A * L1; Wr = El + fdir * L2
        bend_n = nrm(np.cross(A, fdir))
        _arm(parts, S_, El, Wr, bend_n, code0, sd)
        Dh_rest = fdir; P = nrm(P - Dh_rest * np.dot(P, Dh_rest))
        _hand(parts, joints, sd, Wr, Dh_rest, P, code0)
        sh0 = W([.25, 6.95, -.1]) if hk == 'F' else W([.25, 7.0, -.35])
        joints['Shoulder' + sd] = (sh0, S_, (0, 0, 1.0), 'Spine3')
        joints['UpperArm' + sd] = (S_, El, nrm(np.cross(bend_n, A)), 'Shoulder' + sd)
        joints['LowerArm' + sd] = (El, Wr, nrm(np.cross(bend_n, fdir)), 'UpperArm' + sd)
        # 붙잡는 자세 목표: 시안 손목·손 방향, 팔꿈치(시안)
        hold[sd] = dict(grip=list(GRIP[hk]), wrist=Wh.tolist(), dir=Dh.tolist(), palm=Ph.tolist(), elbow=El_hold.tolist(), shoulder=S_.tolist())
        groups[int(code0 + 1)] = ['Spine3', 'Shoulder' + sd, 'UpperArm' + sd, 'LowerArm' + sd, 'Hand' + sd]
        groups[int(code0 + 2)] = ['LowerArm' + sd, 'Hand' + sd] + ['%s1%s' % (f, sd) for f in ('Index', 'Middle', 'Ring', 'Pinky', 'Thumb')]
        for fi, (nm, *_r) in enumerate(FINGERS):
            groups[int(code0 + 3 + fi)] = ['Hand' + sd] + ['%s%d%s' % (nm, k, sd) for k in (1, 2, 3)]
        groups[int(code0 + 7)] = ['Hand' + sd] + ['Thumb%d%s' % (k, sd) for k in (1, 2, 3)]
    # 거울: 오른쪽은 armpart 번호에 +100
    mir = lambda v: np.array([-v[0], v[1], v[2]])
    for g in list(parts):
        m = g.mirrored(g.name.replace('.L', '.R'))
        a = m.attr.get('armpart', {})
        for i in a:
            a[i] += 100.0
        parts.append(m)
    for n in list(joints):
        h, t, u, par = joints[n]
        joints[n.replace('.L', '.R')] = (mir(h), mir(t), mir(np.asarray(u)), par.replace('.L', '.R') if par.endswith('.L') else par)
    for k in list(hold):
        hv = hold[k]
        hold[k.replace('.L', '.R')] = {kk: (mir(np.array(vv)).tolist() if kk != 'grip' else vv) for kk, vv in hv.items()}
    for c in list(groups):
        groups[c + 100] = [b.replace('.L', '.R') for b in groups[c]]
    J = {n: [np.asarray(h).tolist(), np.asarray(t).tolist(), np.asarray(u).tolist(), p] for n, (h, t, u, p) in joints.items()}
    return parts, dict(joints=J, hold=hold, groups={str(k): v for k, v in groups.items()})
