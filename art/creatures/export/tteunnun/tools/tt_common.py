# 뜬눈(k10h1) 실사 괴물 — 공통 도구 (Blender 5.2 안에서 import). 파일만 만든다: 업로드·네트워크 없음.
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)                       # art/creatures/export/tteunnun
WORK = os.path.join(OUT, 'work')                  # 중간 결과(커밋 안 함)
TEXD = os.path.join(OUT, 'textures')
for _d in (WORK, TEXD):
    os.makedirs(_d, exist_ok=True)


def nrm(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v) + 1e-12)


def rot(v, axis, ang):
    """Rodrigues: v 를 axis 둘레로 ang(rad) 회전."""
    v = np.asarray(v, float); k = nrm(axis)
    return v * math.cos(ang) + np.cross(k, v) * math.sin(ang) + k * np.dot(k, v) * (1 - math.cos(ang))


def smooth(e0, e1, x):
    t = np.clip((np.asarray(x, float) - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- 곡선
def catmull(P, per=24):
    P = [np.asarray(p, float) for p in P]
    if len(P) == 2:
        P = [P[0], (P[0] + P[1]) / 2, P[1]]
    ext = [2 * P[0] - P[1]] + P + [2 * P[-1] - P[-2]]
    out, idx = [], []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        t0 = 0.0
        t1 = t0 + max(np.linalg.norm(p1 - p0), 1e-6) ** .5
        t2 = t1 + max(np.linalg.norm(p2 - p1), 1e-6) ** .5
        t3 = t2 + max(np.linalg.norm(p3 - p2), 1e-6) ** .5
        idx.append(len(out))
        for t in np.linspace(t1, t2, per, endpoint=False):
            A1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            A2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            A3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            B1 = (t2 - t) / (t2 - t0) * A1 + (t - t0) / (t2 - t0) * A2
            B2 = (t3 - t) / (t3 - t1) * A2 + (t - t1) / (t3 - t1) * A3
            out.append((t2 - t) / (t2 - t1) * B1 + (t - t1) / (t2 - t1) * B2)
    idx.append(len(out)); out.append(P[-1])
    C = np.array(out)
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(C, axis=0), axis=1))]
    return C, d, np.array([d[i] for i in idx]) / d[-1], len(P)


# ---------------------------------------------------------------- 메시 조각
class Geo:
    """한 부위(한 재질). V: 정점, F: 면(정점 번호), UV: 면 모서리마다 (u,v). attr: 정점별 값. heat: 자동 웨이트에 쓸 뼈 목록,
    wts: {그룹: 정점별 웨이트} (분석식 웨이트)."""

    def __init__(s, name, mat, heat=None):
        s.name, s.mat, s.heat = name, mat, heat
        s.V, s.F, s.UV, s.attr, s.wts = [], [], [], {}, {}

    def nv(s):
        return len(s.V)

    def setattr_(s, name, idx, vals):
        a = s.attr.setdefault(name, {})
        for i, v in zip(idx, vals):
            a[i] = max(a.get(i, 0.0), float(v))

    def arr_attr(s, name):
        out = np.zeros(len(s.V))
        for i, v in s.attr.get(name, {}).items():
            out[i] = v
        return out

    def mirrored(s, name=None):
        g = Geo(name or s.name.replace('.L', '.R'), s.mat,
                [swap_lr(b) for b in s.heat] if s.heat else None)
        g.V = [np.array([-v[0], v[1], v[2]]) for v in s.V]
        g.F = [tuple(reversed(f)) for f in s.F]
        g.UV = [tuple(reversed(u)) for u in s.UV]
        g.attr = {k: dict(v) for k, v in s.attr.items()}
        g.wts = {swap_lr(k): np.array(v) for k, v in s.wts.items()}
        return g


def swap_lr(n):
    if n.endswith('.L'):
        return n[:-2] + '.R'
    if n.endswith('.R'):
        return n[:-2] + '.L'
    return n


def _connect(g, rings, vcoord, circ, closed_loop=False):
    """rings: 각 고리는 정점 번호 목록(길이 n) 또는 [극점 하나]. 고리끼리 사각형/삼각형으로 잇는다."""
    n = max(len(r) for r in rings)
    pairs = list(zip(range(len(rings) - 1), range(1, len(rings))))
    if closed_loop:
        pairs.append((len(rings) - 1, 0))
    for a, b in pairs:
        ra, rb = rings[a], rings[b]
        va, vb = vcoord[a], vcoord[b] if b != 0 or not closed_loop else vcoord[-1] + (vcoord[-1] - vcoord[-2])
        for j in range(n):
            j2 = (j + 1) % n
            u0, u1 = j / n * circ, (j + 1) / n * circ
            if len(ra) == 1 and len(rb) == 1:
                continue
            if len(ra) == 1:
                g.F.append((ra[0], rb[j], rb[j2])); g.UV.append((((u0 + u1) / 2, va), (u0, vb), (u1, vb)))
            elif len(rb) == 1:
                g.F.append((ra[j], rb[0], ra[j2])); g.UV.append(((u0, va), ((u0 + u1) / 2, vb), (u1, va)))
            else:
                g.F.append((ra[j], rb[j], rb[j2], ra[j2])); g.UV.append(((u0, va), (u0, vb), (u1, vb), (u1, va)))


def tube(g, pts, rx, ry=None, n=12, seglen=0.01, up=(0, 0, 1), caps=('round', 'round'), capk=1.0,
         power=2.0, shape=None, minseg=3, closed=False):
    """점들을 지나는 매끈한 관. rx/ry: 제어점마다(목록) 또는 s→값 함수. 단면 x축 = T×N(옆), y축 = N(up 쪽).
    shape(s, a) → 반지름 배수. caps: 'round' | 'flat' | 'hollow'(소매 끝처럼 안쪽으로 접힘) | None.
    돌려주는 info: 정점별 s(0~1), 바깥 방향 rd, 몸통 고리 여부."""
    C, d, cs, npts = catmull(pts)
    L = d[-1]
    M = max(minseg, int(round(L / seglen)))
    S = np.linspace(0, 1, M + 1)
    if closed:
        S = S[:-1]
    P = np.stack([np.interp(S * L, d, C[:, k]) for k in range(3)], 1)

    def prof(r):
        if r is None:
            return None
        if callable(r):
            return np.array([r(s) for s in S])
        r = list(r)
        if len(r) == 1:
            return np.full(len(S), r[0])
        cpos = cs if len(r) == len(cs) else np.linspace(0, 1, len(r))
        return np.interp(S, cpos, r)
    RX = prof(rx); RY = prof(ry) if ry is not None else RX.copy()
    T = np.gradient(P, axis=0)
    if closed:
        T = np.roll(P, -1, 0) - np.roll(P, 1, 0)
    T = np.array([nrm(t) for t in T])
    upv = nrm(up)
    N = [nrm(upv - T[0] * np.dot(upv, T[0]))]
    for k in range(1, len(S)):
        v = N[-1] - T[k] * np.dot(N[-1], T[k])
        N.append(nrm(v))
    N = np.array(N); B = np.cross(T, N)
    ang = np.arange(n) / n * 2 * math.pi
    ca, sa = np.cos(ang), np.sin(ang)
    e = 2.0 / power
    cpw = np.sign(ca) * np.abs(ca) ** e; spw = np.sign(sa) * np.abs(sa) ** e
    rings, centers, info_s, info_rd, info_body = [], [], [], [], []

    def add_ring(c, nn, bb, rxv, ryv, sv, body=True, shp=None):
        idx = []
        for j in range(n):
            f = 1.0 if shp is None else shp(j)
            off = (cpw[j] * rxv * bb + spw[j] * ryv * nn) * f
            idx.append(g.nv()); g.V.append(c + off)
            info_s.append(sv); info_rd.append(nrm(ca[j] * bb + sa[j] * nn)); info_body.append(body)
        rings.append(idx); centers.append(c)

    def add_pole(c, sv):
        rings.append([g.nv()]); g.V.append(np.asarray(c, float)); centers.append(c)
        info_s.append(sv); info_rd.append(np.zeros(3)); info_body.append(False)

    def cap(end):
        k = 0 if end == 0 else len(S) - 1
        sgn = -1 if end == 0 else 1
        c, t, nn, bb, r0x, r0y = P[k], T[k] * sgn, N[k], B[k], RX[k], RY[k]
        kind = caps[end]
        seq = []
        if kind == 'round':
            K = max(3, n // 4)
            for q in range(1, K):
                al = q / K * math.pi / 2
                seq.append(('r', c + t * min(r0x, r0y) * capk * math.sin(al), math.cos(al)))
            seq.append(('p', c + t * min(r0x, r0y) * capk))
        elif kind == 'flat':
            seq.append(('r', c + t * min(r0x, r0y) * .12, .55)); seq.append(('p', c + t * min(r0x, r0y) * .16))
        elif kind == 'hollow':
            th = min(r0x, r0y) * .14
            seq += [('r', c + t * th * .6, 1.0 - .06), ('r', c + t * th * .3, .86), ('r', c - t * .02, .84),
                    ('r', c - t * .05, .82), ('p', c - t * .06)]
        return seq, nn, bb, r0x, r0y, (0.0 if end == 0 else 1.0)

    if not closed and caps[0]:
        seq, nn, bb, rxx, ryy, sv = cap(0)
        for item in reversed(seq):
            if item[0] == 'p':
                add_pole(item[1], sv)
            else:
                add_ring(item[1], nn, bb, rxx * item[2], ryy * item[2], sv, False)
    for k in range(len(S)):
        shp = (lambda j, k=k: shape(S[k], ang[j])) if shape else None
        add_ring(P[k], N[k], B[k], RX[k], RY[k], S[k], True, shp)
    if not closed and caps[1]:
        seq, nn, bb, rxx, ryy, sv = cap(1)
        for item in seq:
            if item[0] == 'p':
                add_pole(item[1], sv)
            else:
                add_ring(item[1], nn, bb, rxx * item[2], ryy * item[2], sv, False)
    # v 좌표 = 고리 사이 평균 거리 누적
    vco = [0.0]
    for a, b in zip(rings[:-1], rings[1:]):
        pa = np.array([g.V[i] for i in a]); pb = np.array([g.V[i] for i in b])
        if len(pa) == len(pb):
            dd = np.linalg.norm(pa - pb, axis=1).mean()
        else:
            big, pole = (pa, pb) if len(pa) > len(pb) else (pb, pa)
            dd = np.linalg.norm(big - pole[0], axis=1).mean()
        vco.append(vco[-1] + dd)
    circ = 2 * math.pi * float(np.mean((RX + RY) / 2))
    _connect(g, rings, vco, circ, closed_loop=closed)
    first = rings[0][0]
    return dict(first=first, last=g.nv(), s=np.array(info_s), rd=np.array(info_rd), body=np.array(info_body),
                P=P, T=T, N=N, B=B, S=S, L=L)


def to_object(g, coll=None):
    """Geo → Blender 메시 오브젝트(UV, 속성, 분석식 웨이트 포함). 면 방향은 bmesh 로 바깥을 보게 맞춘다."""
    me = bpy.data.meshes.new(g.name)
    me.from_pydata([tuple(v) for v in g.V], [], [tuple(f) for f in g.F])
    uvl = me.uv_layers.new(name='UVMap')
    flat = []
    for uvf in g.UV:
        for u in uvf:
            flat += [u[0], u[1]]
    uvl.data.foreach_set('uv', flat)
    for name in g.attr:
        a = me.attributes.new(name, 'FLOAT', 'POINT')
        a.data.foreach_set('value', g.arr_attr(name))
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    me.validate(clean_customdata=False)
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
    ob = bpy.data.objects.new(g.name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    mat = bpy.data.materials.get(g.mat) or bpy.data.materials.new(g.mat)
    me.materials.append(mat)
    if g.wts:
        nvv = len(me.vertices)
        for grp, w in g.wts.items():
            vg = ob.vertex_groups.get(grp) or ob.vertex_groups.new(name=grp)
            w = np.asarray(w)
            for i in np.nonzero(w[:nvv] > 1e-4)[0]:
                vg.add([int(i)], float(w[i]), 'REPLACE')
    return ob


def seg_dist(p, a, b):
    p = np.asarray(p); a = np.asarray(a); b = np.asarray(b)
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(p - (a + t[..., None] * ab), axis=-1)


def envelope_weights(ob, arm, bones, power=4.0):
    """자동 웨이트가 비어 있는 정점을 메우는 예비 방식: 뼈 선분까지 거리의 역거듭제곱."""
    P = np.array([v.co for v in ob.data.vertices])
    D = []
    for b in bones:
        bb = arm.data.bones[b]
        D.append(seg_dist(P, np.array(bb.head_local), np.array(bb.tail_local)))
    D = np.stack(D, 1)
    W = 1.0 / (D ** power + 1e-12)
    W /= W.sum(1, keepdims=True)
    return P, W


def look(cam, target):
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def setup_gpu():
    try:
        pr = bpy.context.preferences.addons['cycles'].preferences
        for kind in ('OPTIX', 'CUDA'):
            try:
                pr.compute_device_type = kind
                pr.get_devices()
                devs = [d for d in pr.devices if d.type == kind]
                if devs:
                    for d in pr.devices:
                        d.use = d.type == kind
                    bpy.context.scene.cycles.device = 'GPU'
                    print('GPU', kind, [d.name for d in devs])
                    return kind
            except Exception as ex:
                print('gpu try', kind, ex)
    except Exception as ex:
        print('gpu setup fail', ex)
    bpy.context.scene.cycles.device = 'CPU'
    return 'CPU'


# 목 늘이기(사용자 요청): 시안 높이 7.05~7.62(목) 구간을 서서히 늘려 그 위(머리·눈·눈꺼풀)를 NECK_DZ 만큼 올린다.
# 시안 좌표를 미터로 바꾸는 모든 곳(retex 몸 정점·눈 중심, rig/limbs 의 W)에 똑같이 적용해 뼈·손 목표가 어긋나지 않게 한다.
NECK_DZ = .14
NECK_Z0, NECK_Z1 = 7.05 * .235, 7.62 * .235


def neck(P):
    P = np.array(P, float)
    z = P[..., 2]
    P[..., 2] = z + NECK_DZ * smooth(NECK_Z0, NECK_Z1, z)
    return P
