# 2단계: geo.blend → 눈알·손톱·천/붕대 + UV + 절차 재질을 텍스처로 굽기 + 뼈대·웨이트 → base.blend
#   blender -b --factory-startup -noaudio -P build_model.py -- <work_dir> <out_dir>
import bpy, bmesh, sys, os, time, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion, noise
from mathutils.kdtree import KDTree
sys.path.insert(0, os.path.dirname(__file__))
import sullae_def as SD

argv = sys.argv[sys.argv.index('--') + 1:]
WORK, OUT = argv[0], argv[1]
TEX = os.path.join(OUT, 'textures'); os.makedirs(TEX, exist_ok=True)
RES_BODY = int(os.environ.get('RES_BODY', '2048')); RES_CLOTH = int(os.environ.get('RES_CLOTH', '2048')); RES_SMALL = 512
BAKE = os.environ.get('NOBAKE') is None
t0 = time.time()
def log(*a):
    print(f'[{time.time() - t0:6.1f}s]', *a, flush=True)

bpy.ops.wm.open_mainfile(filepath=os.path.join(WORK, 'geo.blend'))
sc = bpy.context.scene; col = sc.collection
HI = bpy.data.objects['SullaeHi']; BODY = bpy.data.objects['SullaeBody']
plist = SD.prims()
SK = SD.skeleton()


def link(ob):
    col.objects.link(ob); return ob


def mesh_obj(name, verts, faces):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], faces); me.update()
    return link(bpy.data.objects.new(name, me))


def np_co(me):
    a = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', a); return a.reshape(-1, 3)


def np_no(me):
    a = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('normal', a); return a.reshape(-1, 3)


def decimate_to(ob, tris):
    n = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    md = ob.modifiers.new('dec', 'DECIMATE'); md.ratio = min(1, tris / max(n, 1))
    dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear(); old = ob.data; ob.data = me; bpy.data.meshes.remove(old)
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.triangulate(bm, faces=bm.faces[:]); bm.to_mesh(me); bm.free()
    me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))


# ---------------------------------------------------------------- 뼈 선분(분류용)
DEF = [(n, b) for n, b in SK.items() if b['deform'] and not n.startswith('Eye') and n != 'Root']
SEG_A = np.array([b['head'][:] for n, b in DEF]); SEG_B = np.array([b['tail'][:] for n, b in DEF]); SEG_N = [n for n, b in DEF]


def nearest_bone(P):
    best = np.full(len(P), 1e9); idx = np.zeros(len(P), int); tt = np.zeros(len(P))
    for i in range(len(SEG_N)):
        a, b = SEG_A[i], SEG_B[i]; ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        m = d < best; best[m] = d[m]; idx[m] = i; tt[m] = t[m]
    return idx, tt, best


# ---------------------------------------------------------------- 천 / 붕대 (고해상도 껍질 → 게임용)
def nz(p, s=1.0, o=0.0):
    return noise.noise(Vector((p[0] * s + o, p[1] * s - o * .7, p[2] * s + o * 1.3)))


def make_shell(name, mask_fn, offset_fn, tris):
    me = HI.data
    P = np_co(me); N = np_no(me)
    keep = mask_fn(P)
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    dead = [f for f in bm.faces if not all(keep[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context='FACES')
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        i = v.index
    # 원래 인덱스가 바뀌므로 좌표로 다시 계산
    for v in bm.verts:
        p = np.array(v.co[:]); n = Vector(v.normal)
        v.co = v.co + n * offset_fn(p)
    # 너덜너덜한 가장자리: 경계 가까운 면을 잡음으로 지운다(두 번)
    for it in range(3):
        bm.faces.ensure_lookup_table()
        edge_v = {v for e in bm.edges if e.is_boundary for v in e.verts}
        dead = [f for f in bm.faces if any(v in edge_v for v in f.verts) and nz(f.calc_center_median(), 45, it * 3.1) > .12]
        bmesh.ops.delete(bm, geom=dead, context='FACES')
    # 떨어진 작은 조각 제거
    bm.verts.ensure_lookup_table()
    seen = set(); comps = []
    for v in bm.verts:
        if v in seen: continue
        st = [v]; c = []; seen.add(v)
        while st:
            x = st.pop(); c.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y not in seen: seen.add(y); st.append(y)
        comps.append(c)
    for c in comps:
        if len(c) < 400:
            bmesh.ops.delete(bm, geom=c, context='VERTS')
    hm = bpy.data.meshes.new(name + 'Hi'); bm.to_mesh(hm); bm.free()
    hm.polygons.foreach_set('use_smooth', [True] * len(hm.polygons))
    ohi = link(bpy.data.objects.new(name + 'Hi', hm))
    olo = link(bpy.data.objects.new(name, hm.copy())); olo.data.name = name
    decimate_to(olo, tris)
    log(name, 'hi', len(hm.polygons), 'lo', len(olo.data.polygons))
    return ohi, olo


P_hi = np_co(HI.data)
BI, BT, BD = nearest_bone(P_hi)
BN = np.array(SEG_N)[BI]
torso_set = {'Hips', 'Spine1', 'Spine2', 'Spine3'}


def torso_mask(P):
    out = np.zeros(len(P), bool)
    for i, p in enumerate(P):
        n = BN[i]; x, y, z = p
        top = 1.425 + .03 * (y > 0) + .012 * nz(p, 18)
        hem = .735 + .03 * nz(p, 22, 5) + .018 * math.sin(math.atan2(x, -y) * 3)
        if z > top or z < hem: continue
        if n in torso_set or n.startswith('Thigh') or (n.startswith('Shoulder') and abs(x) < .165):
            # 구멍 몇 개
            if nz(p, 9, 11) > .42 and .95 < z < 1.38: continue
            out[i] = True
    return out


def torso_off(p):
    x, y, z = p
    ang = math.atan2(x, -y)
    ph = (z * 22 + ang * .45 + .35 * nz(p, 6)) % 1.0  # 감아 묶은 천 띠(겹친 가장자리가 계단처럼)
    band = ph
    fold = nz(p, 14, 2) * .0025 + nz(p, 40, 7) * .0008
    sag = .0035 * max(0, 1 - abs(z - 1.08) / .2) * (y < 0)  # 배 앞에 늘어진 천
    return .0040 + band * .0030 + fold + sag


BAND = {'LowerArm_F.L': (.30, .92), 'UpperArm_B.R': (.25, .75), 'Shin.R': (.35, .85), 'LowerArm_B.L': (.55, 1.0), 'Thigh.L': (.6, .95), 'Hand_F.R': (0, .5)}


def band_mask(P):
    out = np.zeros(len(P), bool)
    for i, p in enumerate(P):
        rng = BAND.get(BN[i])
        if rng is None: continue
        t = BT[i] + .06 * nz(p, 30, 3)
        if rng[0] < t < rng[1]:
            out[i] = True
    return out


def band_off(p):
    i = None
    ph = p[0] * 37 + p[1] * 23 + p[2] * 140
    return .0026 + ((ph / 6.283 + .3 * nz(p, 8)) % 1.0) * .0022 + nz(p, 50, 9) * .0006


log('shells...')
CL_HI, CL = make_shell('SullaeCloth', torso_mask, torso_off, 8000)
BD_HI, BDL = make_shell('SullaeBandage', band_mask, band_off, 3000)
# 천과 붕대를 하나로(재질 하나)
def join_into(dst, src):
    bm = bmesh.new(); bm.from_mesh(dst.data); bm.from_mesh(src.data); bm.to_mesh(dst.data); bm.free()
    me = src.data; bpy.data.objects.remove(src); bpy.data.meshes.remove(me)


join_into(CL, BDL); join_into(CL_HI, BD_HI)
log('cloth tris', len(CL.data.polygons))

# ---------------------------------------------------------------- 눈알
EYE_R = SD.EYE_RAD
def eye_c(m): return SD.HL(m * SD.EYE_L[0], SD.EYE_L[1], SD.EYE_L[2])
bm = bmesh.new()
for sd, m in SD.SIDES.items():
    c = eye_c(m)
    r = bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=EYE_R)
    vs = r['verts']
    rot = Matrix.Rotation(math.radians(90), 4, 'X')  # 극(+Z)을 앞(-Y)으로
    bmesh.ops.transform(bm, matrix=Matrix.Translation(c) @ rot, verts=vs)
    # 각막: 홍채 위가 투명한 돔처럼 살짝 솟는다(빛이 작은 점으로 맺힌다)
    for v in vs:
        d = (v.co - c).normalized(); th = math.degrees(math.acos(max(-1, min(1, -d.y))))
        if th < 34:
            v.co = v.co + d * EYE_R * .085 * math.cos(math.radians(th / 34 * 90)) ** 1.5
em = bpy.data.meshes.new('SullaeEyes'); bm.to_mesh(em); bm.free()
EYES = link(bpy.data.objects.new('SullaeEyes', em)); em.polygons.foreach_set('use_smooth', [True] * len(em.polygons))
# 눈알 UV: 앞 극을 중심으로 한 원형 투영(홍채가 가운데)
uvl = em.uv_layers.new(name='UVMap')
for poly in em.polygons:
    for li in poly.loop_indices:
        v = em.vertices[em.loops[li].vertex_index].co
        m = 1 if v.x > 0 else -1
        c = eye_c(m)
        d = (v - c).normalized()
        th = math.acos(max(-1, min(1, -d.y)))  # 앞에서 잰 각
        ph = math.atan2(d.z, d.x)
        rr = th / math.pi * .5
        uvl.data[li].uv = (.5 + rr * math.cos(ph), .5 + rr * math.sin(ph))
log('eyes', len(em.polygons))

# ---------------------------------------------------------------- 손톱(길고 두꺼운, 갈라진)
nail_v, nail_f = [], []
NAIL_OWNER = []
for (tag, sd), (c0, sh, el, wr, f, n) in SD.ARM_INFO.items():
    m = SD.SIDES[sd]
    for fi, fn in enumerate(SD.FINGERS):
        pts, nn = SD.finger_rest(f, n, wr, m, fi)
        d = (pts[3] - pts[2]).normalized(); side = d.cross(nn).normalized(); dors = -nn
        r3 = SD.FING_R[fn][1]
        L0, L1, ext = .58, 1.0, (.010 if fi else .007)
        seg = (pts[3] - pts[2]).length
        rows = []
        NU, NV = 5, 8
        for iv in range(NV):
            t = iv / (NV - 1)
            along = seg * (L0 + (L1 - L0) * min(t / .62, 1))
            over = max(0, t - .62) / .38 * ext  # 끝을 넘어 자란 부분
            w = r3 * (1.55 if fi else 1.7) * (1 - .35 * max(0, t - .62) / .38)
            row = []
            base_pts = []
            for iu in range(NU):
                u = (iu / (NU - 1) - .5) * w
                if over == 0:
                    q = pts[2] + d * along + side * u + dors * (r3 * 2.5)
                    base_pts.append(q)
                else:
                    base_pts.append(None)
            if over == 0:
                Q = SD.project(np.array([b[:] for b in base_pts]), [p for p in plist if np.all(p.hi > np.array(pts[3][:]) - .05) and np.all(p.lo < np.array(pts[3][:]) + .05)], iters=5)
                rows.append([Vector(q) for q in Q])
                last = rows[-1]
            else:
                prev = rows[-1]; ctr = sum(prev, Vector()) / len(prev)
                k = max(0, t - .62) / .38
                row = []
                for iu in range(NU):
                    u = (iu / (NU - 1) - .5) * w
                    # 처음 투영된 행의 곡률을 유지한 채 앞으로 뻗고 살짝 아래로 굽는다
                    q = last[iu] - (sum(last, Vector()) / len(last)) + (sum(last, Vector()) / len(last))
                    q = q + d * (over + (L1 - L0) * 0) + nn * (k * k * .004)
                    q = (sum(last, Vector()) / len(last)) + (last[iu] - sum(last, Vector()) / len(last)) * (1 - .35 * k) + d * over + nn * (k * k * .004)
                    row.append(q)
                rows.append(row)
        # 아래(살 쪽)·위 두 겹
        base = len(nail_v)
        for iv, row in enumerate(rows):
            ctr = sum(row, Vector()) / len(row)
            for iu, q in enumerate(row):
                nrm_ = (q - (pts[2] + d * d.dot(q - pts[2]))).normalized()
                thick = .0011 + .0004 * (iv / (NV - 1))
                nail_v.append(q + nrm_ * .0003)
                nail_v.append(q + nrm_ * (.0003 + thick))
        def vid(iv, iu, top):
            return base + (iv * NU + iu) * 2 + top
        for iv in range(NV - 1):
            for iu in range(NU - 1):
                nail_f.append([vid(iv, iu, 1), vid(iv, iu + 1, 1), vid(iv + 1, iu + 1, 1), vid(iv + 1, iu, 1)])
                nail_f.append([vid(iv, iu, 0), vid(iv + 1, iu, 0), vid(iv + 1, iu + 1, 0), vid(iv, iu + 1, 0)])
        for iv in range(NV - 1):
            for iu in (0, NU - 1):
                a, b = (vid(iv, iu, 0), vid(iv + 1, iu, 0)), (vid(iv, iu, 1), vid(iv + 1, iu, 1))
                nail_f.append([a[0], a[1], b[1], b[0]] if iu == 0 else [a[0], b[0], b[1], a[1]])
        for iv in (0, NV - 1):
            for iu in range(NU - 1):
                a = (vid(iv, iu, 0), vid(iv, iu + 1, 0)); b = (vid(iv, iu, 1), vid(iv, iu + 1, 1))
                nail_f.append([a[0], b[0], b[1], a[1]] if iv == 0 else [a[0], a[1], b[1], b[0]])
        NAIL_OWNER += [f'{fn}3_{tag}.{sd}'] * (NV * NU * 2)
NAILS = mesh_obj('SullaeNails', nail_v, nail_f)
bm = bmesh.new(); bm.from_mesh(NAILS.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]); bmesh.ops.triangulate(bm, faces=bm.faces[:]); bm.to_mesh(NAILS.data); bm.free()
log('nails', len(NAILS.data.polygons))

# ---------------------------------------------------------------- UV
def smart_uv(ob, margin=.003):
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, scale_to_bounds=True)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()  # 섬 크기를 실제 넓이에 맞추고
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)  # 빈틈 없이 다시 배치(텍스처 해상도 낭비 줄이기)
    bpy.ops.object.mode_set(mode='OBJECT')


for o in (BODY, CL, NAILS):
    if not o.data.uv_layers:
        o.data.uv_layers.new(name='UVMap')
    smart_uv(o, .0025 if o is BODY else .004)
log('uv done')

# ---------------------------------------------------------------- 절차 재질(굽기용)
def nodes_new(mt):
    mt.use_nodes = True; nt = mt.node_tree; nt.nodes.clear(); return nt, nt.nodes, nt.links


def tex_coord(N, L):
    tc = N.new('ShaderNodeTexCoord'); return tc


def noise_n(N, L, vec, scale, detail=4, rough=.55, dist=0.0):
    n = N.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail
    n.inputs['Roughness'].default_value = rough; n.inputs['Distortion'].default_value = dist
    L.new(vec, n.inputs['Vector']); return n


def ramp(N, L, src, stops):
    r = N.new('ShaderNodeValToRGB'); cr = r.color_ramp
    while len(cr.elements) > 1: cr.elements.remove(cr.elements[-1])
    cr.elements[0].position = stops[0][0]; cr.elements[0].color = stops[0][1]
    for pos, c in stops[1:]:
        e = cr.elements.new(pos); e.color = c
    L.new(src, r.inputs['Fac']); return r


def mix(N, L, a, b, fac, mode='MIX'):
    m = N.new('ShaderNodeMix'); m.data_type = 'RGBA'; m.blend_type = mode
    if isinstance(fac, float): m.inputs['Factor'].default_value = fac
    else: L.new(fac, m.inputs['Factor'])
    for sock, v in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(v, tuple): sock.default_value = v
        else: L.new(v, sock)
    return m.outputs[2]


def math_n(N, L, op, a, b=None):
    m = N.new('ShaderNodeMath'); m.operation = op
    for sock, v in ((m.inputs[0], a), (m.inputs[1], b)):
        if v is None: continue
        if isinstance(v, (int, float)): sock.default_value = v
        else: L.new(v, sock)
    return m.outputs[0]


def C(r, g, b):
    """sRGB 로 생각한 색 → 선형"""
    f = lambda c: c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1)


def skin_material():
    """핏기 없는 시체 같은 피부: 누르스름한 회녹색 바탕 + 넓은 얼룩 + 잔 얼룩 + 군데군데 비치는 가는 정맥
    + 관절·손끝·발의 때 + 기름진 젖은 광택 얼룩. 범프: 모공·잔주름·피부결·정맥 돌기"""
    mt = bpy.data.materials.new('SkinProc'); nt, N, L = nodes_new(mt)
    out = N.new('ShaderNodeOutputMaterial'); bs = N.new('ShaderNodeBsdfPrincipled'); L.new(bs.outputs[0], out.inputs[0])
    tc = N.new('ShaderNodeTexCoord'); P = tc.outputs['Object']
    sep = N.new('ShaderNodeSeparateXYZ'); L.new(P, sep.inputs[0])
    # 정맥: 두 크기의 '능선' 잡음(|n-0.5| 가 0 근처인 가는 선), 피부가 얇은 곳(머리·목·손·팔 안쪽)에서 진하다
    def ridge(scale, width, dist, seed):
        n = N.new('ShaderNodeTexNoise'); n.noise_dimensions = '4D'; n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = 3
        n.inputs['Roughness'].default_value = .45; n.inputs['Distortion'].default_value = dist; n.inputs['W'].default_value = seed
        L.new(P, n.inputs['Vector'])
        a = math_n(N, L, 'ABSOLUTE', math_n(N, L, 'SUBTRACT', n.outputs['Fac'], .5))
        return ramp(N, L, a, [(0, (1, 1, 1, 1)), (width, (0, 0, 0, 1))]).outputs[0]
    v1 = ridge(6.0, .010, .35, 1.7); v2 = ridge(15.0, .008, .5, 4.2)
    vm = noise_n(N, L, P, 2.0, 2, .5)
    vmask = ramp(N, L, vm.outputs['Fac'], [(.45, (.15, .15, .15, 1)), (.62, (1, 1, 1, 1))])
    head = ramp(N, L, sep.outputs['Z'], [(1.55, (.55, .55, .55, 1)), (1.75, (1, 1, 1, 1))])
    veins = math_n(N, L, 'MULTIPLY', math_n(N, L, 'MAXIMUM', v1, math_n(N, L, 'MULTIPLY', v2, .6)), math_n(N, L, 'MULTIPLY', vmask.outputs[0], head.outputs[0]))
    # 바탕 피부색
    big = noise_n(N, L, P, 3.0, 4, .55)
    base = ramp(N, L, big.outputs['Fac'], [(.25, C(.50, .52, .45)), (.5, C(.60, .61, .53)), (.75, C(.66, .65, .57))])
    mott = noise_n(N, L, P, 22, 6, .65)
    mottc = ramp(N, L, mott.outputs['Fac'], [(.25, (.80, .82, .80, 1)), (.75, (1.06, 1.05, 1.02, 1))])
    c = mix(N, L, base.outputs[0], mottc.outputs[0], 1.0, 'MULTIPLY')
    fine = noise_n(N, L, P, 140, 3, .6)
    finec = ramp(N, L, fine.outputs['Fac'], [(.3, (.92, .92, .92, 1)), (.7, (1.04, 1.04, 1.04, 1))])
    c = mix(N, L, c, finec.outputs[0], 1.0, 'MULTIPLY')
    # 시반처럼 탁한 회갈색·녹회색 얼룩(보라색 없이)
    blo = noise_n(N, L, P, 2.4, 4, .55, .5)
    blom = ramp(N, L, blo.outputs['Fac'], [(.57, (0, 0, 0, 1)), (.72, (.75, .75, .75, 1))])
    c = mix(N, L, c, C(.44, .44, .38), blom.outputs[0], 'MIX')
    blo2 = noise_n(N, L, P, 5.0, 4, .55, .3)
    blom2 = ramp(N, L, blo2.outputs['Fac'], [(.6, (0, 0, 0, 1)), (.75, (.5, .5, .5, 1))])
    c = mix(N, L, c, C(.52, .50, .40), blom2.outputs[0], 'MIX')
    # 정맥 색: 피부 아래 비치는 탁한 청회색
    c = mix(N, L, c, C(.36, .42, .46), math_n(N, L, 'MULTIPLY', veins, .75), 'MIX')
    # 발·손끝 때
    dirt = ramp(N, L, sep.outputs['Z'], [(.0, (1, 1, 1, 1)), (.25, (0, 0, 0, 1))])
    dn = noise_n(N, L, P, 10, 4, .6)
    c = mix(N, L, c, C(.30, .28, .22), math_n(N, L, 'MULTIPLY', dirt.outputs[0], dn.outputs['Fac']), 'MIX')
    L.new(c, bs.inputs['Base Color'])
    # 거칠기: 대체로 무광(.55), 기름진 젖은 얼룩만 .28
    wet = noise_n(N, L, P, 6, 4, .6)
    rough = ramp(N, L, wet.outputs['Fac'], [(.40, (.30, .30, .30, 1)), (.55, (.52, .52, .52, 1)), (.75, (.62, .62, .62, 1))])
    rfine = noise_n(N, L, P, 300, 2, .5)
    L.new(math_n(N, L, 'ADD', rough.outputs[0], math_n(N, L, 'MULTIPLY', math_n(N, L, 'SUBTRACT', rfine.outputs['Fac'], .5), .12)), bs.inputs['Roughness'])
    # 범프: 모공 + 피부결(세포 무늬) + 잔주름 + 정맥 돌기
    pore = noise_n(N, L, P, 700, 2, .5)
    cell = N.new('ShaderNodeTexVoronoi'); cell.inputs['Scale'].default_value = 260; cell.feature = 'DISTANCE_TO_EDGE'; L.new(P, cell.inputs['Vector'])
    cellh = ramp(N, L, cell.outputs['Distance'], [(0, (0, 0, 0, 1)), (.12, (1, 1, 1, 1))])
    wr = N.new('ShaderNodeTexWave'); wr.wave_type = 'BANDS'; wr.inputs['Scale'].default_value = 140; wr.inputs['Distortion'].default_value = 14; wr.inputs['Detail'].default_value = 4
    wr.inputs['Detail Scale'].default_value = 2.5; L.new(P, wr.inputs['Vector'])
    h = math_n(N, L, 'ADD', math_n(N, L, 'MULTIPLY', pore.outputs['Fac'], .35), math_n(N, L, 'MULTIPLY', cellh.outputs[0], .25))
    h = math_n(N, L, 'ADD', h, math_n(N, L, 'MULTIPLY', wr.outputs['Fac'], .30))
    h = math_n(N, L, 'ADD', h, math_n(N, L, 'MULTIPLY', veins, .8))
    bump = N.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .30; bump.inputs['Distance'].default_value = .0006
    L.new(h, bump.inputs['Height']); L.new(bump.outputs[0], bs.inputs['Normal'])
    return mt


def cloth_material():
    mt = bpy.data.materials.new('ClothProc'); nt, N, L = nodes_new(mt)
    out = N.new('ShaderNodeOutputMaterial'); bs = N.new('ShaderNodeBsdfPrincipled'); L.new(bs.outputs[0], out.inputs[0])
    tc = N.new('ShaderNodeTexCoord'); P = tc.outputs['Object']
    big = noise_n(N, L, P, 5, 5, .6)
    base = ramp(N, L, big.outputs['Fac'], [(.25, C(.27, .27, .25)), (.55, C(.40, .40, .37)), (.8, C(.47, .46, .42))])
    st = noise_n(N, L, P, 3.2, 4, .55, .8)
    stm = ramp(N, L, st.outputs['Fac'], [(.55, (0, 0, 0, 1)), (.68, (1, 1, 1, 1))])
    c = mix(N, L, base.outputs[0], C(.20, .17, .12), stm.outputs[0], 'MIX')  # 오래된 얼룩
    st2 = noise_n(N, L, P, 9, 4, .6)
    stm2 = ramp(N, L, st2.outputs['Fac'], [(.6, (0, 0, 0, 1)), (.72, (.7, .7, .7, 1))])
    c = mix(N, L, c, C(.33, .37, .27), stm2.outputs[0], 'MIX')  # 곰팡이 녹빛
    # 올(직조)
    w1 = N.new('ShaderNodeTexWave'); w1.inputs['Scale'].default_value = 260; w1.bands_direction = 'X'; L.new(P, w1.inputs['Vector'])
    w2 = N.new('ShaderNodeTexWave'); w2.inputs['Scale'].default_value = 260; w2.bands_direction = 'Z'; L.new(P, w2.inputs['Vector'])
    weave = math_n(N, L, 'MULTIPLY', w1.outputs['Fac'], w2.outputs['Fac'])
    c = mix(N, L, c, (.0, .0, .0, 1), math_n(N, L, 'MULTIPLY', weave, .18), 'MIX')
    L.new(c, bs.inputs['Base Color'])
    rough = ramp(N, L, stm.outputs[0], [(0, (.86, .86, .86, 1)), (1, (.55, .55, .55, 1))])
    L.new(rough.outputs[0], bs.inputs['Roughness'])
    fz = noise_n(N, L, P, 70, 6, .7)
    h = math_n(N, L, 'ADD', math_n(N, L, 'MULTIPLY', weave, .6), math_n(N, L, 'MULTIPLY', fz.outputs['Fac'], .4))
    bump = N.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .5; bump.inputs['Distance'].default_value = .0006
    L.new(h, bump.inputs['Height']); L.new(bump.outputs[0], bs.inputs['Normal'])
    return mt


def eye_material():
    """사람 눈처럼: 누렇게 탁한 흰자 + 가는 실핏줄 + 결이 보이는 흐린 회녹색 홍채 + 어두운 테 + 뿌옇게 낀 동공(백내장 막)"""
    mt = bpy.data.materials.new('EyeProc'); nt, N, L = nodes_new(mt)
    out = N.new('ShaderNodeOutputMaterial'); bs = N.new('ShaderNodeBsdfPrincipled'); L.new(bs.outputs[0], out.inputs[0])
    tc = N.new('ShaderNodeTexCoord'); uv = tc.outputs['UV']
    sep = N.new('ShaderNodeSeparateXYZ'); L.new(uv, sep.inputs[0])
    dx = math_n(N, L, 'SUBTRACT', sep.outputs['X'], .5); dy = math_n(N, L, 'SUBTRACT', sep.outputs['Y'], .5)
    r = math_n(N, L, 'SQRT', math_n(N, L, 'ADD', math_n(N, L, 'MULTIPLY', dx, dx), math_n(N, L, 'MULTIPLY', dy, dy)))
    ang = math_n(N, L, 'ARCTAN2', dy, dx)
    # 홍채 결: 반지름 방향으로 늘어진 잡음
    cv = N.new('ShaderNodeCombineXYZ'); L.new(math_n(N, L, 'MULTIPLY', ang, 9.0), cv.inputs[0]); L.new(math_n(N, L, 'MULTIPLY', r, 90.0), cv.inputs[1])
    fib = N.new('ShaderNodeTexNoise'); fib.inputs['Scale'].default_value = 1.3; fib.inputs['Detail'].default_value = 8; fib.inputs['Roughness'].default_value = .65
    L.new(cv.outputs[0], fib.inputs['Vector'])
    fibc = ramp(N, L, fib.outputs['Fac'], [(.3, (.55, .55, .55, 1)), (.5, (1, 1, 1, 1)), (.7, (1.45, 1.45, 1.45, 1))])
    # 반지름별 기본 색: 동공 → 홍채(안쪽 갈색 고리, 바깥 회녹) → 어두운 테 → 흰자 → 뒤쪽 누런 흰자
    col = ramp(N, L, r, [(0, C(.03, .03, .035)), (.036, C(.05, .05, .055)), (.044, C(.30, .27, .20)), (.055, C(.40, .44, .40)),
                         (.074, C(.46, .50, .47)), (.083, C(.20, .22, .22)), (.092, C(.16, .17, .17)), (.100, C(.74, .71, .62)),
                         (.2, C(.71, .67, .57)), (.5, C(.60, .52, .44))])
    iris_m = ramp(N, L, r, [(.038, (0, 0, 0, 1)), (.046, (1, 1, 1, 1)), (.080, (1, 1, 1, 1)), (.09, (0, 0, 0, 1))])
    c = mix(N, L, col.outputs[0], mix(N, L, col.outputs[0], fibc.outputs[0], 1.0, 'MULTIPLY'), iris_m.outputs[0], 'MIX')
    # 흰자 실핏줄: 가장자리에서 홍채 쪽으로 가늘어진다
    vn = N.new('ShaderNodeTexNoise'); vn.inputs['Scale'].default_value = 7; vn.inputs['Detail'].default_value = 6; vn.inputs['Distortion'].default_value = 1.2
    L.new(uv, vn.inputs['Vector'])
    vline = ramp(N, L, math_n(N, L, 'ABSOLUTE', math_n(N, L, 'SUBTRACT', vn.outputs['Fac'], .5)), [(0, (1, 1, 1, 1)), (.012, (0, 0, 0, 1))])
    far = ramp(N, L, r, [(.11, (0, 0, 0, 1)), (.30, (1, 1, 1, 1))])
    c = mix(N, L, c, C(.52, .36, .34), math_n(N, L, 'MULTIPLY', vline.outputs[0], far.outputs[0]), 'MIX')
    # 백내장처럼 뿌연 막(동공·홍채 안쪽)
    film = noise_n(N, L, uv, 40, 4, .6)
    fm = ramp(N, L, r, [(0, (.55, .55, .55, 1)), (.06, (.25, .25, .25, 1)), (.09, (0, 0, 0, 1))])
    c = mix(N, L, c, C(.62, .66, .66), math_n(N, L, 'MULTIPLY', fm.outputs[0], film.outputs['Fac']), 'MIX')
    L.new(c, bs.inputs['Base Color'])
    # 각막(가운데)은 젖어 매끈, 흰자는 덜 반짝
    rg = ramp(N, L, r, [(.08, (.05, .05, .05, 1)), (.11, (.22, .22, .22, 1)), (.5, (.30, .30, .30, 1))])
    L.new(rg.outputs[0], bs.inputs['Roughness'])
    return mt


def nail_material():
    mt = bpy.data.materials.new('NailProc'); nt, N, L = nodes_new(mt)
    out = N.new('ShaderNodeOutputMaterial'); bs = N.new('ShaderNodeBsdfPrincipled'); L.new(bs.outputs[0], out.inputs[0])
    tc = N.new('ShaderNodeTexCoord'); P = tc.outputs['Object']
    n1 = noise_n(N, L, P, 160, 5, .6)
    c = ramp(N, L, n1.outputs['Fac'], [(.2, C(.20, .18, .13)), (.5, C(.38, .34, .25)), (.8, C(.50, .46, .35))])
    L.new(c.outputs[0], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = .38
    w = N.new('ShaderNodeTexWave'); w.inputs['Scale'].default_value = 600; w.inputs['Distortion'].default_value = 4; L.new(P, w.inputs['Vector'])
    bump = N.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .4; bump.inputs['Distance'].default_value = .0003
    L.new(w.outputs['Fac'], bump.inputs['Height']); L.new(bump.outputs[0], bs.inputs['Normal'])
    return mt


M_SKIN, M_CLOTH, M_EYE, M_NAIL = skin_material(), cloth_material(), eye_material(), nail_material()
for o, mt in ((HI, M_SKIN), (BODY, M_SKIN), (CL_HI, M_CLOTH), (CL, M_CLOTH), (EYES, M_EYE), (NAILS, M_NAIL)):
    o.data.materials.clear(); o.data.materials.append(mt)

# ---------------------------------------------------------------- 굽기
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 4


def new_img(name, res, color=True):
    if name in bpy.data.images: bpy.data.images.remove(bpy.data.images[name])
    im = bpy.data.images.new(name, res, res, alpha=False, float_buffer=False)
    if not color: im.colorspace_settings.name = 'Non-Color'
    return im


def bake(target, src, kind, img, samples=4):
    """target 의 UV 에 굽는다. src 가 있으면 selected-to-active."""
    sc.cycles.samples = samples
    for o in bpy.data.objects: o.select_set(False)
    for mt in target.data.materials:
        nt = mt.node_tree
        for nd in [n for n in nt.nodes if n.name == '_bake']: nt.nodes.remove(nd)
        nd = nt.nodes.new('ShaderNodeTexImage'); nd.name = '_bake'; nd.image = img; nt.nodes.active = nd
    target.select_set(True); bpy.context.view_layer.objects.active = target
    kw = dict(type=kind, margin=8, use_clear=True)
    if src is not None:
        src.select_set(True); kw.update(use_selected_to_active=True, cage_extrusion=.012, max_ray_distance=.03)
    if kind == 'DIFFUSE':
        kw['pass_filter'] = {'COLOR'}
    if kind == 'NORMAL':
        kw.update(normal_space='TANGENT')
    bpy.ops.object.bake(**kw)
    for mt in target.data.materials:
        nt = mt.node_tree
        for nd in [n for n in nt.nodes if n.name == '_bake']: nt.nodes.remove(nd)


def save_img(img, name):
    p = os.path.join(TEX, name); img.filepath_raw = p; img.file_format = 'PNG'; img.save()
    return p


SETS = [('skin', BODY, HI, RES_BODY), ('cloth', CL, CL_HI, RES_CLOTH), ('eye', EYES, None, RES_SMALL), ('nail', NAILS, None, RES_SMALL)]
IMG = {}
if BAKE:
    for key, tgt, src, res in SETS:
        for kind, suf, colr, smp in (('DIFFUSE', 'baseColor', True, 1), ('ROUGHNESS', 'roughness', False, 1), ('NORMAL', 'normal', False, 4), ('AO', 'ao', False, 48)):
            img = new_img(f'sullae_{key}_{suf}', res, colr)
            if kind == 'AO':
                # AO 는 게임 메시끼리만(고해상도 원본은 숨긴다)
                for o in (HI, CL_HI): o.hide_render = True
                bake(tgt, None, kind, img, smp)
                for o in (HI, CL_HI): o.hide_render = False
            else:
                bake(tgt, src, kind, img, smp)
            IMG[(key, suf)] = save_img(img, f'sullae_{key}_{suf}.png')
            log('baked', key, suf)
else:
    for key, tgt, src, res in SETS:
        for suf in ('baseColor', 'roughness', 'normal', 'ao'):
            IMG[(key, suf)] = os.path.join(TEX, f'sullae_{key}_{suf}.png')

# ---------------------------------------------------------------- 최종 재질(텍스처)
def gltf_out_group():
    if 'glTF Material Output' in bpy.data.node_groups: return bpy.data.node_groups['glTF Material Output']
    g = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
    g.interface.new_socket('Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
    g.nodes.new('NodeGroupInput')
    return g


def final_material(key, double=False):
    mt = bpy.data.materials.new(f'Sullae_{key}'); nt, N, L = nodes_new(mt)
    out = N.new('ShaderNodeOutputMaterial'); bs = N.new('ShaderNodeBsdfPrincipled'); L.new(bs.outputs[0], out.inputs[0])
    def img(suf, colr):
        nd = N.new('ShaderNodeTexImage'); im = bpy.data.images.load(IMG[(key, suf)], check_existing=True)
        im.filepath = bpy.path.relpath(IMG[(key, suf)]) if bpy.data.filepath else IMG[(key, suf)]
        if not colr: im.colorspace_settings.name = 'Non-Color'
        nd.image = im; return nd
    bc = img('baseColor', True); L.new(bc.outputs[0], bs.inputs['Base Color'])
    rg = img('roughness', False); L.new(rg.outputs[0], bs.inputs['Roughness'])
    nm = img('normal', False); nmap = N.new('ShaderNodeNormalMap'); L.new(nm.outputs[0], nmap.inputs['Color']); L.new(nmap.outputs[0], bs.inputs['Normal'])
    ao = img('ao', False); g = N.new('ShaderNodeGroup'); g.node_tree = gltf_out_group(); L.new(ao.outputs[0], g.inputs['Occlusion'])
    bs.inputs['Metallic'].default_value = 0
    if key == 'skin':
        bs.inputs['Subsurface Weight'].default_value = .18; bs.inputs['Subsurface Radius'].default_value = (.75, .62, .5); bs.inputs['Subsurface Scale'].default_value = .005
        bs.inputs['Specular IOR Level'].default_value = .42
    if key == 'eye':
        bs.inputs['Specular IOR Level'].default_value = .45
        bs.inputs['Subsurface Weight'].default_value = .15; bs.inputs['Subsurface Radius'].default_value = (.9, .7, .6); bs.inputs['Subsurface Scale'].default_value = .004
    mt.use_backface_culling = not double
    return mt


FINAL = {k: final_material(k, double=(k == 'cloth')) for k in ('skin', 'cloth', 'eye', 'nail')}
for o, k in ((BODY, 'skin'), (CL, 'cloth'), (EYES, 'eye'), (NAILS, 'nail')):
    o.data.materials.clear(); o.data.materials.append(FINAL[k])
for o in (HI, CL_HI):
    o.hide_render = True; o.hide_set(True)
hc = bpy.data.collections.new('HighPoly_bake_source'); sc.collection.children.link(hc)
for o in (HI, CL_HI):
    col.objects.unlink(o); hc.objects.link(o)
hc.hide_render = True
log('materials done')

# ---------------------------------------------------------------- 뼈대
ad = bpy.data.armatures.new('SullaeRig'); ARM = link(bpy.data.objects.new('SullaeRig', ad))
ad.display_type = 'OCTAHEDRAL'
bpy.ops.object.select_all(action='DESELECT'); ARM.select_set(True); bpy.context.view_layer.objects.active = ARM
bpy.ops.object.mode_set(mode='EDIT')
for name, b in SK.items():
    eb = ad.edit_bones.new(name); eb.head = b['head']; eb.tail = b['tail']; eb.align_roll(b['z'])
for name, b in SK.items():
    eb = ad.edit_bones[name]
    if b['parent']:
        eb.parent = ad.edit_bones[b['parent']]
        if (ad.edit_bones[b['parent']].tail - eb.head).length < 1e-5 and not name.startswith(('UpperArm', 'Thigh')):
            eb.use_connect = True
    eb.use_deform = b['deform']
bpy.ops.object.mode_set(mode='OBJECT')
# 뼈 모음(Bone Collections)
for cname, pred in (('Body', lambda n: not n.startswith('IK_') and not any(f in n for f in SD.FINGERS)), ('Fingers', lambda n: any(f in n for f in SD.FINGERS)), ('IK', lambda n: n.startswith('IK_'))):
    bc = ad.collections.new(cname)
    for b in ad.bones:
        if pred(b.name): bc.assign(b)
log('bones', len(ad.bones), 'deform', sum(b.use_deform for b in ad.bones))

# IK 컨트롤러(기본 꺼짐: 동작은 FK 로 구워져 있다. 'ik_on' 을 1 로 올리면 손발 IK 로 포즈를 잡을 수 있다)
ARM['ik_on'] = 0.0
for s in ('L', 'R'):
    pb = ARM.pose.bones[f'Shin.{s}']; c = pb.constraints.new('IK'); c.target = ARM; c.subtarget = f'IK_Foot.{s}'
    c.pole_target = ARM; c.pole_subtarget = f'IK_Knee.{s}'; c.pole_angle = math.radians(-90); c.chain_count = 2; c.influence = 0
    for tag in SD.ARMS:
        pb = ARM.pose.bones[f'Hand_{tag}.{s}']; c = pb.constraints.new('IK'); c.target = ARM; c.subtarget = f'IK_Hand_{tag}.{s}'
        c.pole_target = ARM; c.pole_subtarget = f'IK_Elbow_{tag}.{s}'; c.pole_angle = math.radians(-90); c.chain_count = 3; c.use_rotation = True; c.influence = 0
for pb in ARM.pose.bones:
    for c in pb.constraints:
        if c.type == 'IK':
            d = c.driver_add('influence').driver; d.type = 'AVERAGE'
            v = d.variables.new(); v.name = 'ik'; v.targets[0].id = ARM; v.targets[0].data_path = '["ik_on"]'
for pb in ARM.pose.bones:
    pb.rotation_mode = 'QUATERNION'

# ---------------------------------------------------------------- 웨이트
for bn in ('Eye.L', 'Eye.R', 'Root'):
    ad.bones[bn].use_deform = False
bpy.ops.object.select_all(action='DESELECT')
BODY.select_set(True); ARM.select_set(True); bpy.context.view_layer.objects.active = ARM
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for bn in ('Eye.L', 'Eye.R', 'Root'):
    ad.bones[bn].use_deform = True


def weights_of(ob):
    vg = {g.index: g.name for g in ob.vertex_groups}
    W = []
    for v in ob.data.vertices:
        W.append({vg[g.group]: g.weight for g in v.groups if g.weight > 1e-4})
    return W


W_BODY = weights_of(BODY)
zero = [i for i, w in enumerate(W_BODY) if not w]
log('auto weights; unweighted verts', len(zero))
if zero:
    # 가장 가까운 웨이트 있는 정점에서 복사
    kd = KDTree(len(W_BODY) - len(zero)); zs = set(zero)
    for i, v in enumerate(BODY.data.vertices):
        if i not in zs: kd.insert(v.co, i)
    kd.balance()
    for i in zero:
        _, j, _ = kd.find(BODY.data.vertices[i].co)
        for g, w in W_BODY[j].items():
            vgp = BODY.vertex_groups.get(g) or BODY.vertex_groups.new(name=g); vgp.add([i], w, 'REPLACE')
    W_BODY = weights_of(BODY)

# 정점당 영향 4개로 제한 + 정규화(게임 엔진용)
bpy.ops.object.select_all(action='DESELECT'); BODY.select_set(True); bpy.context.view_layer.objects.active = BODY


def limit_normalize(ob):
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)


# 좌우가 섞이지 않게: 몸 왼쪽(+X) 정점에서 오른쪽(.R) 팔다리 뼈 웨이트를 지운다(반대도). 발끝이 안쪽으로 모여 있어 생기던 막 제거
LIMB = ('Thigh', 'Shin', 'Foot', 'Toe', 'Shoulder', 'UpperArm', 'LowerArm', 'Hand') + tuple(SD.FINGERS)
nfix = 0
for vg in BODY.vertex_groups:
    nm = vg.name
    if not nm.startswith(LIMB) or not nm[-2:] in ('.L', '.R'): continue
    bad = [v.index for v in BODY.data.vertices if (v.co.x < -.012 if nm.endswith('.L') else v.co.x > .012) and any(g.group == vg.index for g in v.groups)]
    if bad: vg.remove(bad); nfix += len(bad)
log('side-fixed weights', nfix)
limit_normalize(BODY); W_BODY = weights_of(BODY)


def attach(ob, weights):
    ob.parent = ARM
    md = ob.modifiers.new('Armature', 'ARMATURE'); md.object = ARM
    for i, w in enumerate(weights):
        for g, x in w.items():
            vgp = ob.vertex_groups.get(g) or ob.vertex_groups.new(name=g); vgp.add([i], x, 'REPLACE')


# 천: 가장 가까운 몸 정점 3개 가중 평균
kd = KDTree(len(BODY.data.vertices))
for i, v in enumerate(BODY.data.vertices): kd.insert(v.co, i)
kd.balance()
wc = []
for v in CL.data.vertices:
    acc = {}
    hits = kd.find_n(v.co, 4); tot = 0
    for co, j, d in hits:
        k = 1 / (d + 1e-4); tot += k
        for g, x in W_BODY[j].items(): acc[g] = acc.get(g, 0) + x * k
    wc.append({g: x / tot for g, x in acc.items()})
attach(CL, wc); limit_normalize(CL)
attach(EYES, [{'Eye.L' if v.co.x > 0 else 'Eye.R': 1.0} for v in EYES.data.vertices])
attach(NAILS, [{NAIL_OWNER[i]: 1.0} for i in range(len(NAILS.data.vertices))])
log('weights attached')

# ---------------------------------------------------------------- 정리 + 저장
for o in (BODY, CL, EYES, NAILS):
    o.data.name = o.name
BODY.name = 'Sullae_Body'; CL.name = 'Sullae_Cloth'; EYES.name = 'Sullae_Eyes'; NAILS.name = 'Sullae_Nails'; ARM.name = 'Sullae'
for o in (BODY, CL, EYES, NAILS): o.data.name = o.name
tot = sum(len(o.data.polygons) for o in (BODY, CL, EYES, NAILS))
log('TOTAL TRIS', tot, {o.name: len(o.data.polygons) for o in (BODY, CL, EYES, NAILS)})
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'base.blend'))
log('SAVED base.blend')
