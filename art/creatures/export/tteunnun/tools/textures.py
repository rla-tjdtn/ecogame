# 뜬눈(k10h1) — 2단계: 재질. work/stageA.blend → textures/*.png + work/stageB.blend
#   blender -b work/stageA.blend --factory-startup -noaudio -P textures.py
# 피부·옷·쇠: 절차 셰이더(3D 노이즈 + 정점 속성 마스크)를 Cycles 로 UV 에 굽는다(baseColor, roughness, [metallic], normal, AO).
# 눈알·동공: 극좌표 UV 를 알고 있으니 numpy 로 직접 그린다(충혈 핏줄, 홍채, 동공 속 작은 얼굴).
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import numpy as np
from tt_common import *

sc = bpy.context.scene
SIZE = {'Skin': int(os.environ.get('SKIN', 2048)), 'Cloth': int(os.environ.get('CLOTH', 2048)), 'Metal': 1024}
EYE_N = int(os.environ.get('EYE', 4096))
R_EYE = 0.248; RI = 0.118; PHI_I = math.asin(RI / R_EYE)
rng = np.random.default_rng(10)


def save_img(name, arr, noncolor):
    """arr: (H, W, 3|4) 0~1, 행 0 = 아래(v=0)."""
    h, w = arr.shape[:2]
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], 2)
    img = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    img.filepath_raw = os.path.join(TEXD, name + '.png'); img.file_format = 'PNG'
    img.save()
    return img


def vnoise(h, w, cells_v, cells_u, seed, wrap_u=True):
    r = np.random.default_rng(seed).random((cells_v + 1, cells_u + (0 if wrap_u else 1)))
    y = np.linspace(0, cells_v, h, endpoint=False) + cells_v / h / 2
    x = np.linspace(0, cells_u, w, endpoint=False) + cells_u / w / 2
    y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
    fy = (y - y0)[:, None]; fx = (x - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    x1 = (x0 + 1) % r.shape[1] if wrap_u else np.minimum(x0 + 1, r.shape[1] - 1)
    x0 = x0 % r.shape[1]; y1 = np.minimum(y0 + 1, r.shape[0] - 1)
    a = r[y0][:, x0]; b = r[y0][:, x1]; c = r[y1][:, x0]; d = r[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, base_v, base_u, seed, oct=5):
    s, amp, tot = 0, 1, 0
    for o in range(oct):
        s = s + amp * vnoise(h, w, base_v * 2 ** o, base_u * 2 ** o, seed + o); tot += amp; amp *= .5
    return s / tot


# ============================================================ 참고 눈 그림(사용자가 준 실사 눈) — 홍채·동공·흰자를 그대로 옮긴다
REF = os.path.join(os.path.dirname(HERE), 'ref', 'eye_ref.webp')
REF_C, REF_R = (518.0, 480.0), (316.0, 344.0)        # 그림 속 홍채 중심(x, y 아래로)·반지름(px)


def ref_img():
    if not os.path.exists(REF):
        return None
    im = bpy.data.images.load(REF)
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]   # 행 0 = 위
    return a


def ref_sample(a, x, y):
    h, w = a.shape[:2]
    x = np.clip(x, 0, w - 1.001); y = np.clip(y, 0, h - 1.001)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int); fx = (x - x0)[..., None]; fy = (y - y0)[..., None]
    return (a[y0, x0] * (1 - fx) + a[y0, x0 + 1] * fx) * (1 - fy) + (a[y0 + 1, x0] * (1 - fx) + a[y0 + 1, x0 + 1] * fx) * fy


# ============================================================ 눈알(극좌표: u=theta/2pi, v=phi/pi)
def paint_eye():
    N = EYE_N
    v = (np.arange(N) + .5) / N; u = (np.arange(N) + .5) / N
    phi = v * math.pi
    TH = u[None, :] * 2 * math.pi
    rr = (np.sin(np.minimum(phi, PHI_I)) / math.sin(PHI_I))[:, None] * np.ones((1, N))
    iris = (phi < PHI_I)[:, None] * np.ones((1, N), bool)
    # 흰자: 누런 기운 + 가장자리로 갈수록 충혈
    n1 = fbm(N, N, 6, 12, 1); n2 = fbm(N, N, 24, 48, 5, 4)
    scl = np.stack([.9 - .04 * n1, .8 - .06 * n1, .75 - .07 * n1], -1)   # 분홍빛 흰자
    redz = smooth(.24, .42, v)[:, None] * (.55 + .45 * n2)
    scl = scl * (1 - redz[..., None] * .55) + np.array([.78, .42, .38]) * redz[..., None] * .55
    yel = smooth(.55, .8, fbm(N, N, 5, 10, 9))[..., None] * smooth(.2, .3, v)[:, None, None]
    scl = scl * (1 - yel * .35) + np.array([.78, .68, .42]) * yel * .35
    # 핏줄: 눈꺼풀 밑에서 홍채 쪽으로 뻗는 무작위 걸음
    mask = np.zeros((N, N)); hgt = np.zeros((N, N)); thick = np.zeros((N, N))
    stamps = []

    def walk(th, ph, w, depth, stop, drift):
        dth = drift
        while ph > stop and w > .00022:
            stamps.append((th, ph, w))
            dth = dth * .9 + rng.normal(0, .22)
            ang = np.clip(dth, -1.3, 1.3)
            st = .0007
            ph -= st * math.cos(ang) / R_EYE
            th += st * math.sin(ang) / (R_EYE * max(math.sin(ph), .2))
            w *= .9935
            if depth < 2 and rng.random() < .018:
                walk(th, ph, w * .72, depth + 1, stop + rng.uniform(0, .1), rng.choice([-1, 1]) * rng.uniform(.6, 1.1))
    for i in range(130):
        th0 = rng.uniform(0, 2 * math.pi)
        walk(th0, rng.uniform(math.radians(62), math.radians(100)), rng.uniform(.0009, .0021), 0,
             rng.uniform(math.radians(31), math.radians(47)), rng.normal(0, .3))
    for i in range(2200):   # 잔 모세혈관(그물)
        th0 = rng.uniform(0, 2 * math.pi); ph0 = rng.uniform(math.radians(36), math.radians(80))
        d = rng.uniform(-1.5, 1.5); w = rng.uniform(.00025, .0006); L = rng.integers(10, 40)
        th, ph = th0, ph0
        for k in range(L):
            stamps.append((th, ph, w))
            d += rng.normal(0, .5)
            ph -= .0007 * math.cos(d) / R_EYE; th += .0007 * math.sin(d) / (R_EYE * max(math.sin(ph), .2))
    for th, ph, w in stamps:
        x = th / (2 * math.pi) * N; y = ph / math.pi * N
        ru = max(w / (2 * math.pi * R_EYE * max(math.sin(ph), .05)) * N, .55); rv = max(w / (math.pi * R_EYE) * N, .55)
        xs = np.arange(int(x - ru - 2), int(x + ru + 3)); ys = np.arange(max(0, int(y - rv - 2)), min(N, int(y + rv + 3)))
        if len(ys) == 0:
            continue
        dx = (xs[None, :] + .5 - x) / ru; dy = (ys[:, None] + .5 - y) / rv
        a = np.clip(1.25 - np.sqrt(dx * dx + dy * dy), 0, 1) ** .8
        xi = xs % N
        sub = mask[np.ix_(ys, xi)]; mask[np.ix_(ys, xi)] = np.maximum(sub, a)
        sub = hgt[np.ix_(ys, xi)]; hgt[np.ix_(ys, xi)] = np.maximum(sub, a * w)
        sub = thick[np.ix_(ys, xi)]; thick[np.ix_(ys, xi)] = np.maximum(sub, a * min(w / .002, 1))
    fade = smooth(.155, .2, v)[:, None]                 # 홍채 가까이서 옅어짐
    mask *= fade; thick *= fade
    vein_col = np.array([.62, .1, .08]) * (1 - thick[..., None]) + np.array([.36, .02, .03]) * thick[..., None]
    col = scl * (1 - mask[..., None] * .9) + vein_col * mask[..., None] * .9
    # 홍채: 방사 섬유, 깃 테두리, 어두운 가장자리 고리, 움푹한 무늬
    fib = np.zeros((1, N))
    for k in range(16):
        f = rng.integers(40, 260); fib = fib + rng.uniform(.3, 1) * np.sin(TH * f + rng.uniform(0, 6.28))
    fib = fib / 8
    wav = .03 * np.sin(TH * 7 + 1.0)
    fibr = np.tanh(fib + .6 * np.sin(TH * 31 + rr * 9)) * .5 + .5
    # 또렷한 홍채: 동공 둘레 누런 회색 → 청회색 → 짙은 바깥, 섬유는 날카롭게, 가장자리 고리는 거의 검게
    # 동공 원판(반지름 비 RP/RI ≈ .31)이 안쪽을 가리므로, 보이는 고리(.53~1)에 무늬 전체가 오게 반지름을 다시 잰다
    rr = np.where(rr > .456, .345 + (rr - .456) / .544 * .655, rr * .345 / .456)
    fib2 = np.tanh(2.6 * (fib + .5 * np.sin(TH * 37 + rr * 11))) * .5 + .5
    streak = smooth(.82, .97, np.abs(np.sin(TH * 70 + 3 * np.sin(TH * 5) + rr * 4)))     # 가는 어두운 방사선
    c_in = np.array([.05, .06, .08]); c_mid = np.array([.1, .14, .2]); c_out = np.array([.05, .08, .12])
    t1 = smooth(.38, .55, rr + wav)[..., None]; t2 = smooth(.6, .9, rr)[..., None]
    ic = c_in * (1 - t1) + c_mid * t1
    ic = ic * (1 - t2) + c_out * t2
    ic = ic * (.8 + .4 * fib2[..., None])
    fibn = fbm(N, N, 3, 900, 41, 3)   # 세로(반지름)로 길고 가로(각)로 촘촘한 줄무늬 = 가는 방사 섬유
    fibw = smooth(.58, .8, fibn)[..., None] * smooth(.36, .5, rr)[..., None] * (1 - smooth(.85, .95, rr)[..., None])   # 흰·하늘색 가는 섬유
    ic = ic * (1 - fibw * .8) + np.array([.62, .74, .84]) * fibw * .8
    # 시안 홍채처럼 도드라진 방사 주름 44개(밝은 능선·어두운 골)
    ridge = .5 + .5 * np.sin(TH * 44 + .35 * np.sin(TH * 7 + rr * 6))
    ridge = ridge * smooth(.36, .45, rr) * (1 - smooth(.86, .94, rr))
    ic = ic * (.9 + .15 * ridge[..., None])
    coll = np.exp(-((rr - .52 - wav * 1.5) / .028) ** 2)[..., None]
    ic = ic * (1 - coll * .8) + np.array([.85, .55, .22]) * coll * .8   # 주황 물결 고리
    crypt = smooth(.66, .76, fbm(N, N, 40, 160, 21, 3))[..., None] * smooth(.45, .55, rr)[..., None] * (1 - smooth(.8, .9, rr)[..., None])
    ic = ic * (1 - crypt * .75)
    # 동공 테 주름(짙은 갈색 톱니 테), 수축 고랑(바깥쪽 동심원), 주근깨 점
    ruff_r = .345 + .012 * np.sin(TH * 48 + 2 * np.sin(TH * 7))
    ruff = smooth(.0, .012, rr - ruff_r + .012) * (1 - smooth(.0, .01, rr - ruff_r - .016))
    ic = ic * (1 - ruff[..., None] * .5) + np.array([.22, .14, .08]) * ruff[..., None] * .5
    furrow = sum(np.exp(-((rr - r0 - .006 * np.sin(TH * 13 + i)) / .006) ** 2) for i, r0 in enumerate((.66, .74, .82)))
    ic = ic * (1 - .35 * furrow[..., None])
    frk = smooth(.83, .9, fbm(N, N, 60, 300, 33, 2))[..., None] * smooth(.5, .6, rr)[..., None] * (1 - smooth(.84, .9, rr)[..., None])
    ic = ic * (1 - frk) + np.array([.28, .17, .09]) * frk
    limb = smooth(.86, .96, rr)[..., None]
    ic = ic * (1 - limb * .93)
    pup = smooth(.33, .345, rr)[..., None]
    ic = ic * pup + np.array([.004, .004, .004]) * (1 - pup)
    col = np.where(iris[..., None], ic, col)
    # 흰자 쪽 가장자리 고리(홍채 바로 바깥 그림자)
    rim = np.exp(-((v - PHI_I / math.pi) / .008) ** 2)[:, None, None]
    col = col * (1 - rim * .45)
    rough = np.where(iris, .22, .1 + .06 * n2 + mask * .04)
    # 노멀: 핏줄 볼록 + 홍채 섬유
    h = hgt * .35 + np.where(iris, (ridge * .0016 + fib2 * .0005 - streak * .0002 - crypt[..., 0] * .0004 - furrow * .0002 + ruff * .0004) * smooth(.33, .4, rr), 0) + n2 * .00008
    du_m = (2 * math.pi * R_EYE * np.maximum(np.sin(phi), .05) / N)[:, None]
    dv_m = math.pi * R_EYE / N
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * du_m)
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * dv_m); gy[0] = gy[-1] = 0
    nn = np.stack([-gx, -gy, np.ones_like(h)], -1)
    nn /= np.linalg.norm(nn, axis=-1, keepdims=True)
    ao = (1 - .5 * smooth(.4, .75, v))[:, None] * np.ones((1, N)) * (1 - .25 * rim[..., 0])
    A = ref_img()
    if A is not None:
        # 홍채(실제 반지름 비 rg = sin(phi)/sin(PHI_I)): 그림의 홍채를 극좌표로 펼쳐 그대로
        rg = (np.sin(np.minimum(phi, math.pi / 2)) / math.sin(PHI_I))[:, None] * np.ones((1, N))
        ct, st = np.cos(TH) * np.ones((N, 1)), np.sin(TH) * np.ones((N, 1))
        iris_ref = ref_sample(A, REF_C[0] + np.minimum(rg, 1) * REF_R[0] * ct, REF_C[1] - np.minimum(rg, 1) * REF_R[1] * st)
        # 흰자: 홍채 밖은 그림의 흰자 띠에서(오른쪽 넓은 쪽으로 접어서), 반사광은 눌러 줌
        tt = np.clip((phi[:, None] - PHI_I) / (math.radians(72) - PHI_I), 0, 1) * np.ones((1, N))
        d = 1.04 + tt * 1.75
        xs = REF_C[0] + d * REF_R[0] * np.abs(ct); ys = REF_C[1] - np.clip(d * REF_R[1] * st, -330, 330)
        scl_ref = ref_sample(A, np.clip(xs, REF_C[0], 1400), np.clip(ys, 150, 830))
        lum = scl_ref @ np.array([.3, .59, .11])
        hi = smooth(.78, .95, lum)[..., None]
        scl_ref = scl_ref * (1 - hi) + np.array([.86, .74, .68]) * hi
        blend = smooth(.99, 1.03, rg)[..., None]
        col = iris_ref * (1 - blend) + col * blend      # 흰자는 절차(분홍 흰자 + 핏줄 그물), 홍채·동공만 그림에서
        nn = nn * blend + np.array([0, 0, 1.0]) * (1 - blend)   # 홍채는 그림 그대로(울퉁불퉁 절차 노멀 끔)
        rough = np.where(rg < 1, .2, .12)
        print('EYE from reference image')
    save_img('eye_basecolor', col, False)
    save_img('eye_roughness', np.repeat(rough[..., None], 3, -1), True)
    save_img('eye_normal', nn * .5 + .5, True)
    save_img('eye_ao', np.repeat(ao[..., None], 3, -1), True)
    print('EYE painted', len(stamps), 'stamps')


# ============================================================ 동공
def paint_pupil(N=1024):
    """세로로 째진 동공: 가운데 검은 세로 틈 + 둘레 짙은 남색(홍채 안쪽과 이어짐). 동공 뼈 X 스케일로 틈이 벌어진다."""
    y, x = np.mgrid[0:N, 0:N]
    X = (x + .5) / N * 2 - 1; Y = (y + .5) / N * 2 - 1
    R = np.sqrt(X * X + Y * Y)
    slit = np.sqrt((X / .14) ** 2 + (Y / .96) ** 2)
    TH = np.arctan2(Y, X)
    fib = sum(np.sin(TH * f + ph + R * k) for f, ph, k in ((61, .3, 2), (97, 1.1, 3), (143, 2.0, 1), (211, .7, 4), (317, 1.7, 2))) / 3
    fn = np.clip(.5 + .5 * fib, 0, 1)
    base = np.array([.1, .14, .2]) * (.7 + .6 * fn[..., None]) * (.55 + .45 * smooth(.0, .8, R)[..., None])   # 틈 둘레도 남색 홍채 결
    base = base * (1 - smooth(.75, .98, fn)[..., None] * .0) + np.array([.55, .66, .78]) * smooth(.8, .98, fn)[..., None] * .5 * smooth(.25, .6, R)[..., None]
    col = base * smooth(.9, 1.05, slit)[..., None] + np.array([.002, .002, .002]) * (1 - smooth(.9, 1.05, slit))[..., None]
    edge = smooth(.9, 1.0, R)[..., None]
    col = col * (1 - edge) + np.array([.05, .07, .1]) * edge
    A = ref_img()
    if A is not None:
        k = float(os.environ.get('RP_RI', .456))       # 동공 원판 반지름 / 홍채 반지름
        col = ref_sample(A, REF_C[0] + X * k * REF_R[0], REF_C[1] - Y * k * REF_R[1])
    save_img('pupil_basecolor', col, False)
    save_img('pupil_roughness', np.full((N, N, 3), .45), True)
    save_img('pupil_normal', np.tile(np.array([.5, .5, 1.0]), (N, N, 1)), True)
    save_img('pupil_ao', np.ones((N, N, 3)), True)


# ============================================================ 절차 셰이더 도우미
def lin(c):
    """sRGB 로 고른 색 → 선형(셰이더 안 값)."""
    return tuple(((x + .055) / 1.055) ** 2.4 if x > .04045 else x / 12.92 for x in c) + (1.0,)


class NB:
    def __init__(s, mat):
        mat.use_nodes = True
        s.nt = mat.node_tree; s.nt.nodes.clear(); s.N = s.nt.nodes; s.L = s.nt.links

    def set(s, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            s.L.new(v, sock)
        else:
            sock.default_value = v

    def n(s, t, ins=None, **props):
        nd = s.N.new(t)
        for k, v in props.items():
            setattr(nd, k, v)
        for k, v in (ins or {}).items():
            s.set(nd.inputs[k], v)
        return nd

    def math(s, op, a, b=0.0, clamp=False):
        nd = s.N.new('ShaderNodeMath'); nd.operation = op; nd.use_clamp = clamp
        s.set(nd.inputs[0], a); s.set(nd.inputs[1], b)
        return nd.outputs[0]

    def mix(s, fac, a, b):
        nd = s.N.new('ShaderNodeMix'); nd.data_type = 'RGBA'; nd.clamp_factor = True
        s.set(nd.inputs[0], fac)
        s.set([i for i in nd.inputs if i.name == 'A' and i.type == 'RGBA'][0], a if isinstance(a, bpy.types.NodeSocket) else lin(a))
        s.set([i for i in nd.inputs if i.name == 'B' and i.type == 'RGBA'][0], b if isinstance(b, bpy.types.NodeSocket) else lin(b))
        return [o for o in nd.outputs if o.type == 'RGBA'][0]

    def fmix(s, fac, a, b):   # 실수 섞기
        return s.math('ADD', s.math('MULTIPLY', a, s.math('SUBTRACT', 1.0, fac)), s.math('MULTIPLY', b, fac))

    def ramp(s, fac, a, b):
        """fac 을 [a,b] 에서 0→1 로(부드러운 계단)."""
        nd = s.N.new('ShaderNodeMapRange'); nd.interpolation_type = 'SMOOTHSTEP'; nd.clamp = True
        s.set(nd.inputs['Value'], fac); nd.inputs['From Min'].default_value = a; nd.inputs['From Max'].default_value = b
        return nd.outputs['Result']

    def attr(s, name):
        return s.n('ShaderNodeAttribute', attribute_name=name, attribute_type='GEOMETRY').outputs['Fac']

    def noise(s, vec, scale, detail=4.0, rough=.55, dist=0.0, out='Fac'):
        return s.n('ShaderNodeTexNoise', {'Vector': vec, 'Scale': scale, 'Detail': detail, 'Roughness': rough, 'Distortion': dist}).outputs[out]

    def voronoi(s, vec, scale, feature='F1', out='Distance'):
        return s.n('ShaderNodeTexVoronoi', {'Vector': vec, 'Scale': scale}, feature=feature).outputs[out]

    def wave(s, vec, scale, dist=2.0, axis='X', detail=2.0):
        return s.n('ShaderNodeTexWave', {'Vector': vec, 'Scale': scale, 'Distortion': dist, 'Detail': detail},
                   wave_type='BANDS', bands_direction=axis).outputs['Fac']


def skin_shader(mat):
    b = NB(mat)
    pos = b.n('ShaderNodeTexCoord').outputs['Object']
    n1 = b.noise(pos, 5.0, 8, .6); n2 = b.noise(pos, 22.0, 6, .6); n3 = b.noise(pos, 70.0, 3)
    col = b.mix(n1, (.40, .385, .36), (.47, .45, .41))
    col = b.mix(b.math('MULTIPLY', n2, .45), col, (.30, .29, .28))
    blot = b.ramp(b.noise(pos, 2.6, 3, .5), .52, .66)
    col = b.mix(b.math('MULTIPLY', blot, .55), col, (.24, .22, .22))
    dpos = b.n('ShaderNodeVectorMath', {0: pos, 1: b.noise(pos, 6.0, 2, .5, out='Color')}, operation='ADD').outputs[0]
    vl = b.ramp(b.voronoi(dpos, 13.0, 'DISTANCE_TO_EDGE'), .035, 0.0)
    vmask = b.math('MULTIPLY', vl, b.ramp(b.noise(pos, 3.5, 2), .45, .65))
    col = b.mix(b.math('MULTIPLY', vmask, .38), col, (.30, .31, .34))
    red = b.attr('red'); wet = b.attr('wet'); tear = b.attr('tearzone'); wound = b.attr('wound'); nail = b.ramp(b.attr('nail'), .45, .56)
    col = b.mix(b.math('MULTIPLY', red, .7), col, (.55, .36, .34))
    col = b.mix(b.math('MULTIPLY', wet, .5), col, (.62, .38, .36))
    streak = b.ramp(b.wave(pos, 26.0, 3.0, 'X', 3.0), .72, .95)
    col = b.mix(b.math('MULTIPLY', b.math('MULTIPLY', tear, streak), .75), col, (.42, .36, .28))
    crust = b.ramp(b.noise(pos, 90.0, 4), .45, .6)
    col = b.mix(b.math('MULTIPLY', wound, .85), col, b.mix(crust, (.55, .16, .12), (.32, .11, .08)))
    bone = b.attr("bone")
    col = b.mix(b.math("MULTIPLY", bone, b.ramp(b.noise(pos, 30.0, 4), .3, .7)), col, (.62, .58, .52))
    col = b.mix(b.math("MULTIPLY", bone, .35), col, (.55, .52, .47))
    col = b.mix(nail, col, b.mix(b.ramp(n3, .3, .7), (.8, .75, .6), (.62, .55, .4)))
    rough = b.fmix(wet, b.math('ADD', .5, b.math('MULTIPLY', n2, .2)), .16)
    rough = b.fmix(nail, rough, .3)
    rough = b.fmix(b.math('MULTIPLY', tear, streak), rough, .35)
    wr = b.math('ADD', .25, b.attr('wrinkle'))
    hgt = b.math('ADD', b.math('MULTIPLY', b.noise(pos, 420.0, 2, .5), .35),
                 b.math('MULTIPLY', b.wave(pos, 140.0, 9.0, 'Z', 4.0), b.math('MULTIPLY', wr, .9)))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', b.noise(pos, 38.0, 4), .6))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', vmask, .5))
    hgt = b.math('SUBTRACT', hgt, b.math('MULTIPLY', nail, .3))
    bump = b.n('ShaderNodeBump', {'Height': hgt, 'Strength': .55, 'Distance': .0012})
    return b, col, rough, None, bump.outputs['Normal']


def cloth_shader(mat):
    b = NB(mat)
    pos = b.n('ShaderNodeTexCoord').outputs['Object']
    n1 = b.noise(pos, 3.0, 5, .6); n2 = b.noise(pos, 11.0, 5); grain = b.noise(pos, 300.0, 3, .6)
    trouser = b.attr('trouser')
    wool = b.mix(trouser, (.36, .33, .29), (.30, .28, .25))
    wool = b.mix(b.math('MULTIPLY', grain, .5), wool, (.26, .24, .21))
    pin = b.math("MULTIPLY", b.ramp(b.wave(pos, 95.0, .4, "X", 0.0), .93, .99), 0.0)
    wool = b.mix(b.math('MULTIPLY', pin, .35), wool, (.4, .38, .35))
    fade = b.ramp(n1, .5, .72)
    wool = b.mix(b.math('MULTIPLY', fade, .6), wool, (.45, .42, .37))
    stain = b.ramp(n2, .6, .72)
    wool = b.mix(b.math('MULTIPLY', stain, .7), wool, (.16, .13, .1))
    hem = b.attr('hem')
    fray = b.math('MULTIPLY', hem, b.ramp(b.noise(pos, 60.0, 4), .4, .6))
    wool = b.mix(b.math('MULTIPLY', fray, .7), wool, (.38, .35, .3))
    moth = b.math('MULTIPLY', b.ramp(b.voronoi(pos, 32.0), .055, .0), b.ramp(b.noise(pos, 2.2, 2), .58, .66))
    lap = b.ramp(b.attr('lapel'), .48, .52)
    col = b.mix(b.math('MULTIPLY', lap, .7), wool, (.11, .105, .1))
    edge = b.math('MULTIPLY', b.ramp(b.math('ABSOLUTE', b.math('SUBTRACT', b.attr('lapel'), .5)), .02, .0), .5)
    col = b.mix(edge, col, (.32, .3, .27))
    shirt = b.ramp(b.attr('shirt'), .48, .52)
    shirtc = b.mix(b.ramp(b.noise(pos, 14.0, 5), .5, .75), (.78, .74, .62), (.6, .53, .38))
    col = b.mix(shirt, col, shirtc)
    tie = b.attr('tie')
    col = b.mix(tie, col, (.05, .045, .045))
    btnv = b.attr('btn')
    btn = b.ramp(btnv, .875, .885)
    col = b.mix(btn, col, b.mix(b.ramp(btnv, .9, .97), (.18, .12, .08), (.33, .24, .16)))
    seam = b.ramp(b.attr('seam'), .955, .975)
    pk = b.math('MULTIPLY', b.ramp(b.math('ABSOLUTE', b.math('SUBTRACT', b.attr('pocket'), .5)), .05, .0), 1.0)
    col = b.mix(b.math('MAXIMUM', seam, pk), col, (.04, .035, .03))
    tear = b.math('MULTIPLY', b.attr('tear'), b.math('ADD', .6, b.math('MULTIPLY', b.noise(pos, 25.0, 5), .7)))
    hole = b.ramp(tear, .62, .66)
    torn = b.math('MULTIPLY', b.ramp(tear, .5, .62), b.math('SUBTRACT', 1.0, hole))
    col = b.mix(b.math('MULTIPLY', torn, .8), col, (.38, .35, .3))
    col = b.mix(b.math('MAXIMUM', hole, moth), col, (.02, .018, .016))
    rough = b.fmix(shirt, .88, .74)
    rough = b.fmix(tie, rough, .38)
    rough = b.fmix(btn, rough, .32)
    rough = b.fmix(lap, rough, .66)
    hgt = b.math('ADD', b.math('MULTIPLY', grain, .4), b.math('MULTIPLY', b.noise(pos, 16.0, 3, .5, 2.0), 1.2))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', btn, .5))
    hgt = b.math('SUBTRACT', hgt, b.math('MULTIPLY', b.math('MAXIMUM', b.math('MAXIMUM', seam, pk), b.math('MAXIMUM', hole, moth)), .6))
    bump = b.n('ShaderNodeBump', {'Height': hgt, 'Strength': .45, 'Distance': .0025})
    return b, col, rough, None, bump.outputs['Normal']


def metal_shader(mat):
    b = NB(mat)
    pos = b.n('ShaderNodeTexCoord').outputs['Object']
    rust = b.ramp(b.noise(pos, 55.0, 10, .7), .44, .58)
    pits = b.ramp(b.voronoi(pos, 380.0), .12, .0)
    rc = b.mix(b.noise(pos, 160.0, 4), (.45, .2, .08), (.62, .36, .16))
    iron = b.mix(b.noise(pos, 90.0, 3), (.38, .37, .36), (.5, .49, .47))
    col = b.mix(rust, iron, rc)
    tip = b.math('MULTIPLY', b.attr('tip'), b.ramp(b.noise(pos, 70.0, 5), .35, .55))
    col = b.mix(b.math('MULTIPLY', tip, .9), col, (.3, .04, .03))
    met = b.math('MULTIPLY', b.math('SUBTRACT', 1.0, rust), b.math('SUBTRACT', 1.0, tip))
    rough = b.fmix(rust, .4, .88)
    rough = b.fmix(tip, rough, .3)
    hgt = b.math('ADD', b.math('MULTIPLY', rust, .7), b.math('MULTIPLY', pits, -.4))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', b.noise(pos, 300.0, 4), .3))
    bump = b.n('ShaderNodeBump', {'Height': hgt, 'Strength': .6, 'Distance': .0008})
    return b, col, rough, met, bump.outputs['Normal']


# ============================================================ 굽기
def bake(obj, mat, builder, size):
    sc.render.engine = 'CYCLES'
    b, col, rough, met, nor = builder(mat)
    out = b.n('ShaderNodeOutputMaterial'); em = b.n('ShaderNodeEmission', {'Strength': 1.0})
    L = b.L.new(em.outputs[0], out.inputs['Surface'])
    pr = b.n('ShaderNodeBsdfPrincipled', {'Base Color': col, 'Roughness': rough, 'Normal': nor})
    for o in bpy.data.objects:
        o.select_set(False)
    obj.select_set(True); bpy.context.view_layer.objects.active = obj
    key = mat.name.lower()
    jobs = [('basecolor', 'EMIT', col, False), ('roughness', 'EMIT', rough, True)]
    if met is not None:
        jobs.append(('metallic', 'EMIT', met, True))
    jobs += [('normal', 'NORMAL', None, True), ('ao', 'AO', None, True)]
    imgs = {}
    for nm, kind, sock, nc in jobs:
        img = bpy.data.images.new(key + '_' + nm, size, size, alpha=False)
        img.colorspace_settings.name = 'Non-Color' if nc else 'sRGB'
        tn = b.n('ShaderNodeTexImage', image=img)
        b.N.active = tn
        for l in list(out.inputs['Surface'].links):
            b.L.remove(l)
        if kind == 'EMIT':
            for l in list(em.inputs['Color'].links):
                b.L.remove(l)
            b.set(em.inputs['Color'], sock)
            b.L.new(em.outputs[0], out.inputs['Surface'])
            sc.cycles.samples = 8
        elif kind == 'NORMAL':
            b.L.new(pr.outputs[0], out.inputs['Surface']); sc.cycles.samples = 8
        else:
            b.L.new(pr.outputs[0], out.inputs['Surface']); sc.cycles.samples = 96
        bpy.ops.object.bake(type=kind, margin=16, margin_type='EXTEND', use_clear=True)
        img.filepath_raw = os.path.join(TEXD, key + '_' + nm + '.png'); img.file_format = 'PNG'; img.save()
        imgs[nm] = img
        b.N.remove(tn)
        print('BAKED', key, nm)
    return imgs


def final_material(mat, imgs, emissive=None, alpha=None, sss=0.0):
    """구운 텍스처로 glTF 가 그대로 읽는 Principled 재질을 만든다(AO 는 glTF Material Output 그룹)."""
    b = NB(mat)
    out = b.n('ShaderNodeOutputMaterial'); pr = b.n('ShaderNodeBsdfPrincipled')
    b.L.new(pr.outputs[0], out.inputs['Surface'])
    uv = b.n('ShaderNodeUVMap', uv_map='UVMap').outputs['UV']

    def tex(img):
        t = b.n('ShaderNodeTexImage', image=img); b.L.new(uv, t.inputs['Vector']); return t
    if imgs:
        b.L.new(tex(imgs['basecolor']).outputs['Color'], pr.inputs['Base Color'])
        b.L.new(tex(imgs['roughness']).outputs['Color'], pr.inputs['Roughness'])
        if 'metallic' in imgs:
            b.L.new(tex(imgs['metallic']).outputs['Color'], pr.inputs['Metallic'])
        else:
            pr.inputs['Metallic'].default_value = 0.0
        nm = b.n('ShaderNodeNormalMap', uv_map='UVMap')
        b.L.new(tex(imgs['normal']).outputs['Color'], nm.inputs['Color']); b.L.new(nm.outputs['Normal'], pr.inputs['Normal'])
        grp = bpy.data.node_groups.get('glTF Material Output')
        if grp is None:
            grp = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
            grp.interface.new_socket('Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
            grp.interface.new_socket('Thickness', in_out='INPUT', socket_type='NodeSocketFloat')
        g = b.n('ShaderNodeGroup'); g.node_tree = grp
        sep = b.n('ShaderNodeSeparateColor'); b.L.new(tex(imgs['ao']).outputs['Color'], sep.inputs[0])
        b.L.new(sep.outputs[0], g.inputs['Occlusion'])
    if emissive is not None:
        b.L.new(tex(emissive).outputs['Color'], pr.inputs['Emission Color']); pr.inputs['Emission Strength'].default_value = 1.0
    if sss:
        pr.inputs['Subsurface Weight'].default_value = sss
        pr.inputs['Subsurface Radius'].default_value = (1.0, .35, .2); pr.inputs['Subsurface Scale'].default_value = .012
    return pr


# ============================================================ 실행
setup_gpu()
sc.render.bake.margin = 16
if not sc.world:
    sc.world = bpy.data.worlds.new('World')
sc.world.light_settings.distance = .12
paint_eye(); paint_pupil()
OB = {o.name[2:]: o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('M_')}
# 굽는 동안 아마추어 변형 끄기(쉬는 자세 그대로)
for o in OB.values():
    for m in o.modifiers:
        m.show_render = False; m.show_viewport = False
baked = {}
for name, fn in [x for x in (("Skin", skin_shader), ("Cloth", cloth_shader), ("Metal", metal_shader)) if x[0] in OB]:
    baked[name] = bake(OB[name], OB[name].data.materials[0], fn, SIZE[name])
for o in OB.values():
    for m in o.modifiers:
        m.show_render = True; m.show_viewport = True
M = {o.data.materials[0].name: o.data.materials[0] for o in OB.values()}
final_material(M['Skin'], baked['Skin'], sss=.12)
final_material(M['Cloth'], baked['Cloth'])
if "Metal" in M:
    final_material(M["Metal"], baked["Metal"])
ld = lambda n: bpy.data.images.get(n) or bpy.data.images.load(os.path.join(TEXD, n + '.png'))
eimg = {k: ld('eye_' + k) for k in ('basecolor', 'roughness', 'normal', 'ao')}
for k in ('roughness', 'normal', 'ao'):
    eimg[k].colorspace_settings.name = 'Non-Color'
pe = final_material(M['Eye'], eimg, sss=.05)
pimg = {k: ld('pupil_' + k) for k in ('basecolor', 'roughness', 'normal', 'ao')}
for k in ('roughness', 'normal', 'ao'):
    pimg[k].colorspace_settings.name = 'Non-Color'
final_material(M['Pupil'], pimg, emissive=ld('pupil_emissive'))
pc = final_material(M['Cornea'], None)
pc.inputs['Base Color'].default_value = (1, 1, 1, 1); pc.inputs['Roughness'].default_value = .02
pc.inputs['Alpha'].default_value = .1; pc.inputs['Specular IOR Level'].default_value = 1.0; pc.inputs['IOR'].default_value = 1.376
M['Cornea'].surface_render_method = 'BLENDED'
if "Lash" in M:
    pl = final_material(M["Lash"], None)
    pl.inputs["Base Color"].default_value = (.035, .03, .026, 1); pl.inputs["Roughness"].default_value = .6
# 모든 이미지를 textures/ 상대 경로로
for img in bpy.data.images:
    if img.filepath_raw and TEXD.lower() in os.path.abspath(bpy.path.abspath(img.filepath_raw)).lower():
        img.filepath = os.path.join(TEXD, os.path.basename(img.filepath_raw))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'stageB.blend'))
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_mainfile()
print('SAVED stageB')
