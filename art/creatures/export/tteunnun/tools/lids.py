# 제대로 된 눈꺼풀: 눈알을 감싸는 위·아래 살 띠(바깥 면 → 둥글게 말린 두툼한 가장자리 → 눈알 쪽 안 면).
# 손가락이 잡아당긴 자리(위·아래 좌우 62°)에서 더 벌어지고, 가장자리 근처는 부어오른 주름.
# 뒤쪽 열린 끝은 머리 살 속에 묻힌다. 정점마다 위/아래 눈꺼풀 웨이트(w_up, w_lo)를 속성으로 넣어 rig.py 가 쓴다.
import math
import numpy as np
from tt_common import Geo, nrm, smooth, _connect, tube

AP_A, AP_B = .258, .228                     # 벌어진 눈구멍 반폭·반높이(정면 투영, 시안 속눈썹 뿌리 자리에 맞춤)
PULLS = [(-62, .006), (-118, .006), (62, .006), (118, .006)]
RIM = .011


def lid_grab(E, R_EYE, th_deg, out=.012):
    """손가락 끝이 닿는 자리(가장자리 바로 바깥 살 위) — limbs.py 가 붙잡는 자세 목표로 쓴다."""
    g = build_lids(E, R_EYE, _only_frame=True)
    return g(th_deg, out)


def build_lids(E, R_EYE, _only_frame=False):
    FWD = np.array([0, -1.0, 0]); RGT = np.array([1.0, 0, 0]); UPV = np.array([0, 0, 1.0])
    R_IN = R_EYE + .006

    def sph(th, phi, r):
        return E + r * (math.cos(phi) * FWD + math.sin(phi) * (math.cos(th) * RGT + math.sin(th) * UPV))

    # 참고 그림의 눈구멍: 가로로 긴 레몬 꼴(위·아래 호가 양 끝에서 뾰족하게 만남). 정면 투영 반폭 AP_A, 반높이 AP_B(위)/0.9 AP_B(아래).
    # 경계: |y| = B (1 - (x/A)^2)^p, p<1 이면 둥글고 1 이면 끝이 뾰족해진다. 각도마다 반지름을 이분법으로 풀어 표로 둔다.
    def _edge_r(th):
        c, s = math.cos(th), math.sin(th)
        B = AP_B if s >= 0 else AP_B * .9
        p = .82 if s >= 0 else .95
        lo_, hi_ = 0.0, AP_A * 1.2
        for _ in range(40):
            r = (lo_ + hi_) / 2; x = r * c; y = abs(r * s)
            inside = abs(x) < AP_A and y < B * max(0.0, 1 - (x / AP_A) ** 2) ** p
            lo_, hi_ = (r, hi_) if inside else (lo_, r)
        return (lo_ + hi_) / 2
    _T = np.linspace(-math.pi, math.pi, 1441)
    _R = np.array([_edge_r(t) for t in _T])

    def ap_phi(th):
        th = math.atan2(math.sin(th), math.cos(th))
        r = float(np.interp(th, _T, _R)) + .002 * math.sin(th * 5 + .7)
        return math.asin(min(max(r, .02), R_IN * .975) / R_IN)

    if _only_frame:
        def grab(th_deg, out):
            th = math.radians(th_deg); pm = ap_phi(th)
            p = sph(th, pm + .11, R_IN + 2 * RIM + .016)
            return p + nrm(p - E) * out
        return grab
    g = Geo('Eyelids', 'Body')
    n = 96
    ths = np.arange(n) / n * 2 * math.pi
    PB = math.radians(112)                    # 뒤 끝(머리 살 속으로 파묻힘 — 껍데기·헬멧처럼 보이지 않게)
    rows = [('o', t) for t in np.linspace(0, 1, 26)] + [('r', t) for t in np.linspace(0, 1, 12)[1:-1]] + [('i', t) for t in np.linspace(0, 1, 9)]
    rings, dmv, inn, thv = [], [], [], []
    for kind, t in rows:
        idx = []
        for th in ths:
            pm = ap_phi(th)
            if kind == 'o':
                tt = t ** 1.15
                phi = PB - tt * (PB - pm)
                # 눈을 둘러싼 부푼 살 둔덕: 뒤 끝은 머리 살 밑, 가운데는 눈알보다 4.5cm 솟아 눈알이 눈구멍 안에 들어앉게
                s1 = smooth(0, .5, tt); s2 = smooth(.78, 1, tt)
                rr = (R_IN + .006) * (1 - s1) + (R_IN + .02) * s1
                rr = rr * (1 - s2) + (R_IN + 2 * RIM) * s2
                up = max(0.0, math.sin(th)); lo = max(0.0, -math.sin(th))
                rr += .004 * math.exp(-((tt - .93) / .05) ** 2)                                  # 얇은 눈꺼풀 입술
                rr -= .002 * math.exp(-((tt - .85) / .025) ** 2)
                rr += .004 * math.exp(-((tt - .77) / .045) ** 2) * (.5 + .5 * up)               # 바깥 주름(약하게)
                rr += .0035 * math.sin(th * 23 + 2 * math.sin(th * 5)) * smooth(.55, .8, tt) * (1 - smooth(.86, .9, tt))   # 잔주름
                p = sph(th, phi, rr); dm = (phi - pm) * R_IN; ins = False
            elif kind == 'r':
                b = t * math.pi
                rim = RIM * (.35 + .65 * abs(math.sin(th)) ** .6)        # 구석으로 갈수록 가장자리가 얇아져 뾰족하게 만남
                c = sph(th, pm, R_IN + rim)
                radial = nrm(c - E); tang = nrm(sph(th, pm - .01, R_IN + rim) - c)
                p = c + rim * (math.cos(b) * radial + math.sin(b) * tang); dm = 0.0; ins = b > math.pi / 2
            else:
                phi = pm + t * (PB - pm)
                p = sph(th, phi, R_IN); dm = (phi - pm) * R_IN; ins = True
            idx.append(g.nv()); g.V.append(p); dmv.append(dm); inn.append(ins); thv.append(th)
        rings.append(idx)
    vco = [0.0]
    for a, b in zip(rings[:-1], rings[1:]):
        vco.append(vco[-1] + float(np.linalg.norm(np.array([g.V[i] for i in a]) - np.array([g.V[i] for i in b]), axis=1).mean()))
    _connect(g, rings, vco, 2 * math.pi * .26)
    dm = np.array(dmv); inn = np.array(inn); th = np.array(thv)
    nband = g.nv()
    wl = np.where(inn, 1 - smooth(.015, .06, dm), 1 - smooth(.025, .1, dm))
    up = smooth(-.3, .3, np.sin(th))
    rng_ = range(g.nv())
    g.setattr_('lidshell', rng_, np.ones(g.nv()))
    g.setattr_('w_up', rng_, wl * up)
    g.setattr_('w_lo', rng_, wl * (1 - up))
    corner = np.abs(np.cos(th)) ** 8                          # 눈 양 구석: 위·아래 꺼풀이 만나는 세모 자리는 넓게 점막
    g.setattr_('lidm', rng_, np.clip(1 - dm / (.01 + .06 * corner), 0, 1) * inn + np.clip(1 - dm / (.004 + .05 * corner), 0, 1) * corner * (~inn))
    g.setattr_('lip', rng_, np.clip(1 - dm / (.012 + .05 * corner), 0, 1) * (~inn) + inn * 1.0)   # 눈꺼풀 입술(분홍빛 갈색)      # 가장자리(충혈·젖음)
    # (눈 구석 분홍 살은 뺐다 — 참고 그림처럼 구석은 위·아래 눈꺼풀 가장자리가 뾰족하게 만나기만 한다)
    # 속눈썹: 시안(e10h.js)과 같은 꼴 — 위·아래 13개씩, 굵고 끝이 뾰족한 뼈빛 가시가 앞으로 나왔다가 위(아래)로 휨.
    # 자리만 눈꺼풀 가장자리 말림 위에 뿌리를 박았다(시안에서는 떠 있었음). 몸 재질로 굽히고 thin 속성으로 뼈빛.
    lash = Geo('Lashes', 'Body')
    S = .235
    for u in (1, -1):
        for i in range(13):
            t = (i / 12 * 2 - 1) * .88
            th = math.atan2(u * math.sqrt(max(0.0, 1 - (t * .95) ** 2)) * .84, t * 1.1)   # 시안 속눈썹 뿌리 각도
            pm = ap_phi(th)
            c = sph(th, pm, R_IN + RIM)
            radial = nrm(c - E); tang = nrm(sph(th, pm - .01, R_IN + RIM) - c)
            b = math.pi * .3
            nrmv = math.cos(b) * radial + math.sin(b) * tang
            root = c + RIM * nrmv - nrmv * .004
            lat = RGT * (1 if t >= 0 else -1)
            p1 = root + FWD * .18 * S + UPV * u * .18 * S + lat * abs(t) * .1 * S
            p2 = root + FWD * .16 * S + UPV * u * (.42 + .1 * math.sin(i * 3)) * S + lat * abs(t) * .22 * S
            st = lash.nv()
            tube(lash, [root - nrmv * .006, root, p1, p2], [.032 * S, .032 * S, .024 * S, .005 * S], n=8, seglen=.006, up=nrmv,
                 caps=('round', 'round'), capk=.6)
            r2 = range(st, lash.nv()); k = lash.nv() - st
            lash.setattr_('lidshell', r2, np.ones(k))
            lash.setattr_('w_up' if u > 0 else 'w_lo', r2, np.ones(k))
            lash.setattr_('thin', r2, np.ones(k))
    return g, lash
