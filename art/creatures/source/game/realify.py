# 실사 공포 괴물 다듬기(Blender, 소리 없음, 파일만 만든다 — 업로드 없음):
#   blender -b --factory-startup -noaudio -P realify.py -- <in.glb(export-anim.js 결과)> <out_dir> <name> <kind: k7h4|k10h1>
# 1) 몸 메시를 라플라시안 스무딩(부피 유지) + 부드러운 음영  2) 부위별 절차 재질(피부·핏줄·얼룩·주름·젖은 광택 / 넝마 천 / 붕대 / 충혈된 눈알 / 금속 갈고리)
# 3) UV 펼쳐 PBR 텍스처 굽기(baseColor, roughness, metallic, normal, AO)  4) 텍스처 한 장짜리 재질로 바꿔 .glb(애니메이션 포함)·.fbx·png 저장
# DEBUG=1: 부위 나눔만 색으로 찍어 <out_dir>/<name>_regions.png
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
src, outdir, name, kind = argv[0], os.path.abspath(argv[1]), argv[2], argv[3]
TEX = int(os.environ.get('TEX', '2048'))
DEBUG = bool(os.environ.get('DEBUG'))
os.makedirs(outdir, exist_ok=True)
texdir = os.path.join(outdir, name + '_tex'); os.makedirs(texdir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 60  # (클립 시간을 촘촘히: 24fps 로 반올림되지 않게)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.data.polygons)
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o is not body: bpy.data.objects.remove(o)
arm.data.pose_position = 'REST'
vl = bpy.context.view_layer
for o in bpy.data.objects: o.select_set(False)
vl.objects.active = body; body.select_set(True)

# 1) 매끈하게: 부피를 지키는 라플라시안 스무딩(손가락·갈고리 끝이 녹지 않게 약하게) → 아마추어 앞에서 적용
ls = body.modifiers.new('Smooth', 'LAPLACIANSMOOTH'); ls.lambda_factor = float(os.environ.get('LAMBDA', '0.6')); ls.iterations = int(os.environ.get('ITER', '6')); ls.use_volume_preserve = True; ls.use_normalized = True
bpy.ops.object.modifier_move_to_index(modifier='Smooth', index=0)
bpy.ops.object.modifier_apply(modifier='Smooth')
bpy.ops.object.shade_smooth()

me = body.data
V = np.array([body.matrix_world @ v.co for v in me.vertices])
mn, mx = V.min(0), V.max(0); H = mx[2] - mn[2]; cx, cy = (mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2
FC = np.array([body.matrix_world @ p.center for p in me.polygons]); FN = np.array([(body.matrix_world.to_3x3() @ p.normal).normalized() for p in me.polygons])
hz = (FC[:, 2] - mn[2]) / H; ax = np.abs(FC[:, 0] - cx) / H; ay = np.abs(FC[:, 1] - cy) / H
print('BOUNDS', mn, mx, 'H', H, 'faces', len(FC))

# 부위 나누기: 0 피부, 1 넝마(허리·골반), 2 붕대(가슴·배), 3 눈알, 4 금속 갈고리
mat_idx = np.zeros(len(FC), dtype=int)
eyeC, eyeR = None, None
if kind == 'k7h4':
    mat_idx[(hz > 0.385) & (hz < 0.50) & (ax < 0.085)] = 1
    mat_idx[(hz >= 0.50) & (hz < 0.70) & (ax < 0.062) & (ay < 0.07)] = 2
else:
    # 큰 눈알: 위쪽 정점에서 RANSAC 구 맞춤
    rng = np.random.default_rng(1)
    up = V[(V[:, 2] - mn[2]) / H > 0.70]
    best = (0, None, None)
    for _ in range(3000):
        s = up[rng.choice(len(up), 4, replace=False)]
        A = np.c_[2 * s, np.ones(4)]; b = (s ** 2).sum(1)
        try: x = np.linalg.solve(A, b)
        except np.linalg.LinAlgError: continue
        c = x[:3]; r2 = x[3] + (c ** 2).sum()
        if r2 <= 0: continue
        r = math.sqrt(r2)
        if not (0.05 * H < r < 0.16 * H): continue
        n = int((np.abs(np.linalg.norm(up - c, axis=1) - r) < 0.006 * H).sum())
        if n > best[0]: best = (n, c, r)
    eyeC, eyeR = best[1], best[2]
    print('EYE', eyeC, eyeR, best[0])
    d = np.linalg.norm(FC - eyeC, axis=1)
    on = (np.abs(d - eyeR) < 0.02 * H) & ((FN * (FC - eyeC)).sum(1) / np.maximum(d, 1e-6) > 0.6)
    mat_idx[on] = 3
    near = (~on) & (d < eyeR * 1.45) & (d > eyeR * 0.9)
    mat_idx[near & (ax < (eyeR / H) * 1.25) & (FC[:, 2] > eyeC[2] - eyeR * 0.8)] = 4  # 눈 둘레 가시·갈고리
    mat_idx[(hz > 0.40) & (hz < 0.52) & (ax < 0.085)] = 1
    mat_idx[(hz >= 0.52) & (hz < 0.68) & (ax < 0.06) & (ay < 0.065)] = 2
print('REGIONS', np.bincount(mat_idx, minlength=5).tolist())

# ---------- 절차 재질 ----------
def nodes_of(mat):
    mat.use_nodes = True; nt = mat.node_tree; nt.nodes.clear(); return nt
def N(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items():
        if k.startswith('in_'): n.inputs[k[3:].replace('_', ' ')].default_value = v
        else: setattr(n, k, v)
    return n
def L(nt, a, b): nt.links.new(a, b)
def coords(nt, scale):
    tc = N(nt, 'ShaderNodeTexCoord'); mp = N(nt, 'ShaderNodeMapping'); mp.inputs['Scale'].default_value = (scale / H,) * 3
    L(nt, tc.outputs['Object'], mp.inputs['Vector']); return mp.outputs['Vector']
def noise(nt, vec, scale, detail=6, rough=0.55, dist=0.0):
    n = N(nt, 'ShaderNodeTexNoise', in_Scale=scale, in_Detail=detail, in_Roughness=rough, in_Distortion=dist); L(nt, vec, n.inputs['Vector']); return n
def ramp(nt, fac, stops):
    r = N(nt, 'ShaderNodeValToRGB'); el = r.color_ramp.elements
    while len(el) > 1: el.remove(el[-1])
    el[0].position, el[0].color = stops[0][0], stops[0][1]
    for p, c in stops[1:]:
        e = el.new(p); e.color = c
    L(nt, fac, r.inputs['Fac']); return r
def mix(nt, fac, a, b):
    m = N(nt, 'ShaderNodeMix', data_type='RGBA'); L(nt, fac, m.inputs['Factor'])
    for s, v in ((6, a), (7, b)):
        if isinstance(v, tuple): m.inputs[s].default_value = v
        else: L(nt, v, m.inputs[s])
    return m.outputs[2]
def math_(nt, op, a, b=None, clamp=False):
    m = N(nt, 'ShaderNodeMath', operation=op, use_clamp=clamp)
    for i, v in enumerate((a, b)):
        if v is None: continue
        if isinstance(v, (int, float)): m.inputs[i].default_value = v
        else: L(nt, v, m.inputs[i])
    return m.outputs[0]

def skin_part(nt):
    """창백한 회녹색 피부: 얼룩 · 핏줄 · 주름 · 젖은 광택 → (색, 거칠기, 높이)"""
    v = coords(nt, 10)
    base = ramp(nt, noise(nt, v, 3.5).outputs['Fac'], [(0.3, (0.13, 0.15, 0.11, 1)), (0.7, (0.22, 0.24, 0.18, 1))]).outputs['Color']
    blot = ramp(nt, noise(nt, v, 1.6, 8, 0.6, 0.4).outputs['Fac'], [(0.55, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))]).outputs['Color']
    col = mix(nt, blot, base, (0.06, 0.045, 0.05, 1))  # 멍·썩은 얼룩
    bruise = ramp(nt, noise(nt, v, 4.5, 4, 0.5, 1.2).outputs['Fac'], [(0.62, (0, 0, 0, 1)), (0.75, (1, 1, 1, 1))]).outputs['Color']
    col = mix(nt, math_(nt, 'MULTIPLY', bruise, 0.6), col, (0.16, 0.17, 0.06, 1))  # 누런 녹색 반점
    # 핏줄: 비틀린 보로노이 경계선
    dn = noise(nt, v, 6, 3, 0.5, 2.0)
    vv = N(nt, 'ShaderNodeVectorMath', operation='ADD'); L(nt, v, vv.inputs[0]); L(nt, dn.outputs['Color'], vv.inputs[1])
    vo = N(nt, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', in_Scale=9.0); L(nt, vv.outputs[0], vo.inputs['Vector'])
    vein = ramp(nt, vo.outputs['Distance'], [(0.0, (1, 1, 1, 1)), (0.045, (0, 0, 0, 1))]).outputs['Color']
    vmask = ramp(nt, noise(nt, v, 2.2).outputs['Fac'], [(0.45, (0, 0, 0, 1)), (0.6, (1, 1, 1, 1))]).outputs['Color']
    vein = math_(nt, 'MULTIPLY', vein, vmask)
    col = mix(nt, math_(nt, 'MULTIPLY', vein, 0.75), col, (0.04, 0.05, 0.10, 1))  # 푸르죽죽한 핏줄
    # 주름 높이
    wr = N(nt, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', in_Scale=40.0, in_Distortion=9.0, in_Detail=4.0); L(nt, v, wr.inputs['Vector'])
    h = math_(nt, 'ADD', math_(nt, 'MULTIPLY', wr.outputs['Fac'], 0.35), math_(nt, 'MULTIPLY', noise(nt, v, 12, 4, 0.5).outputs['Fac'], 0.65))
    h = math_(nt, 'ADD', h, math_(nt, 'MULTIPLY', vein, 0.5))
    wet = ramp(nt, noise(nt, v, 2.8, 5).outputs['Fac'], [(0.4, (0.18, 0.18, 0.18, 1)), (0.62, (0.55, 0.55, 0.55, 1))]).outputs['Color']
    return col, math_(nt, 'ADD', wet, 0), h, None

def cloth_part(nt):
    v = coords(nt, 10)
    w1 = N(nt, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='X', in_Scale=180.0); L(nt, v, w1.inputs['Vector'])
    w2 = N(nt, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', in_Scale=180.0); L(nt, v, w2.inputs['Vector'])
    weave = math_(nt, 'MULTIPLY', math_(nt, 'ADD', w1.outputs['Fac'], w2.outputs['Fac']), 0.5)
    base = ramp(nt, noise(nt, v, 5).outputs['Fac'], [(0.3, (0.025, 0.022, 0.018, 1)), (0.75, (0.06, 0.05, 0.035, 1))]).outputs['Color']
    stain = ramp(nt, noise(nt, v, 2.0, 6, 0.6, 0.6).outputs['Fac'], [(0.56, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))]).outputs['Color']
    col = mix(nt, stain, base, (0.05, 0.01, 0.006, 1))  # 말라붙은 핏자국
    h = math_(nt, 'ADD', math_(nt, 'MULTIPLY', weave, 0.4), math_(nt, 'MULTIPLY', noise(nt, v, 10, 3).outputs['Fac'], 0.6))
    return col, (0.92,), h, None

def bandage_part(nt):
    scol, srough, sh, _ = skin_part(nt)
    v = coords(nt, 10)
    dn = noise(nt, v, 3, 2, 0.5, 0.0)
    vv = N(nt, 'ShaderNodeVectorMath', operation='ADD'); L(nt, v, vv.inputs[0]); L(nt, math_(nt, 'MULTIPLY', dn.outputs['Fac'], 0.25), vv.inputs[1])
    st = N(nt, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z', in_Scale=10.0, in_Distortion=1.5); L(nt, vv.outputs[0], st.inputs['Vector'])
    gap = ramp(nt, noise(nt, v, 3.0, 4).outputs['Fac'], [(0.58, (1, 1, 1, 1)), (0.66, (0, 0, 0, 1))]).outputs['Color']  # 붕대가 풀려 피부가 보이는 곳
    band = math_(nt, 'MULTIPLY', ramp(nt, st.outputs['Fac'], [(0.12, (0, 0, 0, 1)), (0.2, (1, 1, 1, 1))]).outputs['Color'], gap)
    dirt = ramp(nt, noise(nt, v, 6, 8, 0.65).outputs['Fac'], [(0.35, (0.36, 0.32, 0.22, 1)), (0.7, (0.13, 0.10, 0.06, 1))]).outputs['Color']
    blood = ramp(nt, noise(nt, v, 3.5, 6, 0.6, 0.8).outputs['Fac'], [(0.62, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))]).outputs['Color']
    bcol = mix(nt, blood, dirt, (0.09, 0.012, 0.008, 1))
    col = mix(nt, band, scol, bcol)
    wv = N(nt, 'ShaderNodeTexWave', wave_type='BANDS', bands_direction='X', in_Scale=260.0); L(nt, v, wv.inputs['Vector'])
    h = mix(nt, band, sh, math_(nt, 'ADD', math_(nt, 'MULTIPLY', band, 0.8), math_(nt, 'MULTIPLY', wv.outputs['Fac'], 0.15)))
    rough = mix(nt, band, srough, (0.85, 0.85, 0.85, 1))
    return col, rough, h, None

def eye_part(nt):
    """충혈된 실사 눈알: 눈알 중심 기준 앞(+Y) 방향 각도로 동공·홍채·흰자, 흰자에 붉은 핏줄"""
    ec = eyeC if eyeC is not None else np.array([cx, cy, mx[2]])
    tc = N(nt, 'ShaderNodeTexCoord')
    rel = N(nt, 'ShaderNodeVectorMath', operation='SUBTRACT'); L(nt, tc.outputs['Object'], rel.inputs[0]); rel.inputs[1].default_value = tuple(body.matrix_world.inverted() @ Vector(ec))
    nrm = N(nt, 'ShaderNodeVectorMath', operation='NORMALIZE'); L(nt, rel.outputs[0], nrm.inputs[0])
    fwd = body.matrix_world.inverted().to_3x3() @ Vector((0, 1, 0))
    dp = N(nt, 'ShaderNodeVectorMath', operation='DOT_PRODUCT'); L(nt, nrm.outputs[0], dp.inputs[0]); dp.inputs[1].default_value = tuple(fwd)
    ang = math_(nt, 'ARCCOSINE', dp.outputs['Value'])  # 0 = 정면 가운데
    v = coords(nt, 10)
    radial = N(nt, 'ShaderNodeTexNoise', in_Scale=60.0, in_Detail=4.0); L(nt, nrm.outputs[0], radial.inputs['Vector'])
    iris = ramp(nt, radial.outputs['Fac'], [(0.3, (0.04, 0.02, 0.005, 1)), (0.55, (0.17, 0.09, 0.02, 1)), (0.8, (0.08, 0.10, 0.04, 1))]).outputs['Color']
    vo = N(nt, 'ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE', in_Scale=14.0)
    dn = noise(nt, v, 8, 3, 0.5, 2.5); vv = N(nt, 'ShaderNodeVectorMath', operation='ADD'); L(nt, v, vv.inputs[0]); L(nt, dn.outputs['Color'], vv.inputs[1]); L(nt, vv.outputs[0], vo.inputs['Vector'])
    vein = ramp(nt, vo.outputs['Distance'], [(0.0, (1, 1, 1, 1)), (0.05, (0, 0, 0, 1))]).outputs['Color']
    redness = ramp(nt, ang, [(0.5, (0.15, 0.15, 0.15, 1)), (1.5, (1, 1, 1, 1))]).outputs['Color']  # 가장자리로 갈수록 핏발
    sclera = ramp(nt, noise(nt, v, 4).outputs['Fac'], [(0.3, (0.55, 0.48, 0.35, 1)), (0.7, (0.66, 0.58, 0.44, 1))]).outputs['Color']
    sclera = mix(nt, math_(nt, 'MULTIPLY', ang, 0.35, True), sclera, (0.45, 0.13, 0.09, 1))
    sclera = mix(nt, math_(nt, 'MULTIPLY', vein, redness), sclera, (0.28, 0.004, 0.003, 1))
    irisM = ramp(nt, ang, [(0.40, (1, 1, 1, 1)), (0.44, (0, 0, 0, 1))]).outputs['Color']
    pupM = ramp(nt, ang, [(0.16, (1, 1, 1, 1)), (0.18, (0, 0, 0, 1))]).outputs['Color']
    ring = ramp(nt, ang, [(0.38, (0, 0, 0, 1)), (0.42, (1, 1, 1, 1)), (0.44, (0, 0, 0, 1))]).outputs['Color']  # 홍채 테두리
    col = mix(nt, irisM, sclera, iris)
    col = mix(nt, ring, col, (0.05, 0.04, 0.03, 1))
    col = mix(nt, pupM, col, (0.01, 0.01, 0.01, 1))
    h = math_(nt, 'ADD', math_(nt, 'MULTIPLY', vein, 0.3), math_(nt, 'MULTIPLY', math_(nt, 'MULTIPLY', radial.outputs['Fac'], irisM), 0.4))
    return col, (0.06,), h, None

def metal_part(nt):
    v = coords(nt, 10)
    rust = ramp(nt, noise(nt, v, 7, 8, 0.65, 0.5).outputs['Fac'], [(0.45, (0, 0, 0, 1)), (0.62, (1, 1, 1, 1))]).outputs['Color']
    col = mix(nt, rust, (0.45, 0.44, 0.42, 1), (0.10, 0.03, 0.01, 1))
    rough = mix(nt, rust, (0.3, 0.3, 0.3, 1), (0.85, 0.85, 0.85, 1))
    metal = math_(nt, 'SUBTRACT', 1.0, rust)
    h = math_(nt, 'MULTIPLY', noise(nt, v, 20, 4).outputs['Fac'], rust)
    return col, rough, h, metal

BUILD = [('Skin', skin_part), ('Rags', cloth_part), ('Bandage', bandage_part), ('Eye', eye_part), ('Hook', metal_part)]
DBGC = [(0.6, 0.65, 0.55, 1), (0.2, 0.15, 0.1, 1), (0.9, 0.85, 0.7, 1), (0.9, 0.2, 0.2, 1), (0.3, 0.4, 0.9, 1)]
me.materials.clear()
mats = []
for i, (mname, fn) in enumerate(BUILD):
    m = bpy.data.materials.new(mname); m.diffuse_color = DBGC[i]; me.materials.append(m); mats.append(m)
me.polygons.foreach_set('material_index', mat_idx.astype(np.int32)); me.update()

def render_setup(eevee=True):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE' if eevee else 'BLENDER_WORKBENCH'
    sc.render.resolution_x, sc.render.resolution_y = 600, 800
    sc.world = bpy.data.worlds.get('W') or bpy.data.worlds.new('W')
    if eevee:
        sc.world.use_nodes = True; bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.015, 0.016, 0.02, 1); bg.inputs[1].default_value = 1
        for nm, loc, en, col in (('Key', (4, -6, 9), 2500, (1, 0.93, 0.85)), ('Rim', (-5, 7, 7), 3500, (0.6, 0.75, 1.0)), ('Fill', (-7, -5, 2), 500, (0.8, 0.85, 1.0))):
            if nm in bpy.data.objects: continue
            ld = bpy.data.lights.new(nm, 'AREA'); ld.energy = en * (H / 9) ** 2; ld.color = col; ld.size = H * 0.4
            lo = bpy.data.objects.new(nm, ld); sc.collection.objects.link(lo); lo.location = Vector(loc) * (H / 9) + Vector((cx, cy, mn[2] + H * 0.3))
            lo.rotation_euler = (Vector((cx, cy, mn[2] + H * 0.55)) - lo.location).to_track_quat('-Z', 'Y').to_euler()
    else:
        sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
    cam = bpy.data.objects.get('Cam')
    if not cam:
        cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam)
    sc.camera = cam; cam.data.lens = 60
    ctr = Vector((cx, cy, mn[2] + H * 0.5)); yaw = math.radians(float(os.environ.get('YAW', '200')))
    d = Vector((math.sin(yaw), -math.cos(yaw), 0.12)).normalized()
    cam.location = ctr + d * H * 2.6; cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.clip_end = H * 20
    return sc

if DEBUG:
    sc = render_setup(False); sc.render.filepath = os.path.join(outdir, name + '_regions.png'); bpy.ops.render.render(write_still=True)
    print('DEBUG done'); sys.exit(0)

# ---------- 굽기 ----------
for m in mats:
    nt = nodes_of(m)
    col, rough, h, metal = dict(BUILD)[m.name](nt)
    bsdf = N(nt, 'ShaderNodeBsdfPrincipled'); out = N(nt, 'ShaderNodeOutputMaterial')
    def sock(x, target):
        if isinstance(x, tuple): target.default_value = x[0] if not hasattr(target.default_value, '__len__') else x
        else: L(nt, x, target)
    sock(col, bsdf.inputs['Base Color'])
    rr = rough if not isinstance(rough, tuple) else (rough[0],)
    if isinstance(rr, tuple): bsdf.inputs['Roughness'].default_value = rr[0]
    else:
        bw = N(nt, 'ShaderNodeRGBToBW'); L(nt, rr, bw.inputs[0]); L(nt, bw.outputs[0], bsdf.inputs['Roughness']); rr = bw.outputs[0]
    if metal is not None: L(nt, metal, bsdf.inputs['Metallic'])
    bump = N(nt, 'ShaderNodeBump', in_Strength=0.35, in_Distance=0.004 * H); L(nt, h, bump.inputs['Height']); L(nt, bump.outputs['Normal'], bsdf.inputs['Normal'])
    L(nt, bsdf.outputs[0], out.inputs['Surface'])
    em = N(nt, 'ShaderNodeEmission'); em.name = 'BakeEmit'  # (굽기용 발광 노드)

# UV
vl.objects.active = body
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(80), island_margin=0.003, scale_to_bounds=True)
bpy.ops.object.mode_set(mode='OBJECT')

sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.render.bake.margin = 6
imgs = {}
def new_img(key, noncolor):
    im = bpy.data.images.new(f'{name}_{key}', TEX, TEX, alpha=False, float_buffer=False)
    if noncolor: im.colorspace_settings.name = 'Non-Color'
    imgs[key] = im; return im
def set_target(im):
    for m in mats:
        nt = m.node_tree; t = nt.nodes.get('BakeTarget') or nt.nodes.new('ShaderNodeTexImage'); t.name = 'BakeTarget'; t.image = im
        nt.nodes.active = t
def emit_from(which):
    for m in mats:
        nt = m.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'); em = nt.nodes['BakeEmit']; out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
        inp = bsdf.inputs[which]
        for l in list(em.inputs['Color'].links): nt.links.remove(l)
        if inp.links: L(nt, inp.links[0].from_socket, em.inputs['Color'])
        else:
            v = inp.default_value; em.inputs['Color'].default_value = (v[0], v[1], v[2], 1) if hasattr(v, '__len__') else (v, v, v, 1)
        L(nt, em.outputs[0], out.inputs['Surface'])
def surface_bsdf():
    for m in mats:
        nt = m.node_tree; bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'); out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'); L(nt, bsdf.outputs[0], out.inputs['Surface'])
import time
for key, which, nc in (('basecolor', 'Base Color', False), ('roughness', 'Roughness', True), ('metallic', 'Metallic', True)):
    t = time.time(); im = new_img(key, nc); set_target(im); emit_from(which); sc.cycles.samples = 1
    bpy.ops.object.bake(type='EMIT'); print('BAKE', key, round(time.time() - t, 1), 's')
surface_bsdf()
t = time.time(); im = new_img('normal', True); set_target(im); sc.cycles.samples = 1
bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT'); print('BAKE normal', round(time.time() - t, 1), 's')
t = time.time(); im = new_img('ao', True); set_target(im); sc.cycles.samples = int(os.environ.get('AOS', '32'))
bpy.ops.object.bake(type='AO'); print('BAKE ao', round(time.time() - t, 1), 's')
for k, im in imgs.items():
    p = os.path.join(texdir, f'{name}_{k}.png'); im.filepath_raw = p; im.file_format = 'PNG'; im.save(filepath=p); print('PNG', p, os.path.exists(p))

# ---------- 텍스처 한 장짜리 재질 ----------
fm = bpy.data.materials.new(name + '_PBR'); nt = nodes_of(fm)
bsdf = N(nt, 'ShaderNodeBsdfPrincipled'); out = N(nt, 'ShaderNodeOutputMaterial'); L(nt, bsdf.outputs[0], out.inputs['Surface'])
uv = N(nt, 'ShaderNodeUVMap')
def tex(key):
    t = N(nt, 'ShaderNodeTexImage'); t.image = imgs[key]; L(nt, uv.outputs['UV'], t.inputs['Vector']); return t
L(nt, tex('basecolor').outputs['Color'], bsdf.inputs['Base Color'])
for key, inp in (('roughness', 'Roughness'), ('metallic', 'Metallic')):
    sp = N(nt, 'ShaderNodeSeparateColor'); L(nt, tex(key).outputs['Color'], sp.inputs[0]); L(nt, sp.outputs[0], bsdf.inputs[inp])
nm = N(nt, 'ShaderNodeNormalMap'); L(nt, tex('normal').outputs['Color'], nm.inputs['Color']); L(nt, nm.outputs[0], bsdf.inputs['Normal'])
# glTF AO: "glTF Material Output" 노드 그룹의 Occlusion
g = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
g.interface.new_socket('Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
gn = nt.nodes.new('ShaderNodeGroup'); gn.node_tree = g
sp = N(nt, 'ShaderNodeSeparateColor'); L(nt, tex('ao').outputs['Color'], sp.inputs[0]); L(nt, sp.outputs[0], gn.inputs['Occlusion'])
me.materials.clear(); me.materials.append(fm)
me.polygons.foreach_set('material_index', np.zeros(len(me.polygons), dtype=np.int32)); me.update()
for m in mats: bpy.data.materials.remove(m)

arm.data.pose_position = 'POSE'
glb = os.path.join(outdir, name + '.glb')
bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB', export_animations=True, export_animation_mode='ACTIONS', export_image_format=os.environ.get('IMGFMT', 'JPEG'), export_jpeg_quality=90, export_skins=True, export_all_influences=False)
print('GLB', glb, os.path.getsize(glb))
fbx = os.path.join(outdir, name + '.fbx')
bpy.ops.export_scene.fbx(filepath=fbx, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=True, bake_anim_use_nla_strips=False,
                         bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0, path_mode='RELATIVE', embed_textures=False)
print('FBX', fbx, os.path.getsize(fbx))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(texdir, name + '.blend'))
