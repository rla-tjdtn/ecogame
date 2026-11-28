# 뜬눈(k10h1) — 시안 3D 형태(design_mesh.js 가 e10h.js 시안에서 그대로 뽑은 메시)는 그대로 두고 재질만 실사로 입힌다.
#   blender -b --factory-startup -noaudio -P retex.py     → work/retexA.blend, textures/body_*.png, eye_*.png, pupil_*.png
# 시안의 눈알 겉면은 design_mesh.js 에서 이미 뺐고, 여기서 따로 된 눈알(흰자·홍채 구, 각막, 동공 원판)을 넣는다.
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import numpy as np
from mathutils import Vector
from tt_common import *

S = 0.235                                  # 시안 단위 → 미터 (키 10.14 → 2.38 m)
BODY_TEX = int(os.environ.get('BODY', 4096))

# textures.py 의 그림 함수·셰이더 도우미를 가져온다(실행부는 빼고)
_src = open(os.path.join(HERE, 'textures.py'), encoding='utf-8').read().split('# ============================================================ 실행')[0]
exec(_src)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; vl = bpy.context.view_layer
# ---- 시안 메시(design_mesh.js 결과) 읽기: 시안 좌표 (x, y 위, z 앞) → Blender (x, -z, y) × S
import json
LVL = os.environ.get('LVL', 'lo')
hdr = json.load(open(os.path.join(WORK, 'design_%s.json' % LVL)))
raw = open(os.path.join(WORK, 'design_%s.bin' % LVL), 'rb').read()
nv, nt = hdr['nv'], hdr['nt']
P = np.frombuffer(raw, np.float32, nv * 3, 0).reshape(-1, 3).astype(float)
T = np.frombuffer(raw, np.uint32, nt * 3, nv * 12).reshape(-1, 3)
MATV = np.frombuffer(raw, np.uint8, nv, nv * 12 + nt * 12).astype(float)
BKV = np.frombuffer(raw, np.uint8, nv, nv * 13 + nt * 12).astype(float)
V = np.c_[P[:, 0], -P[:, 2], P[:, 1]] * S
# 면 방향: 껍질(연결 조각)마다 부호 있는 부피를 재서 안쪽을 보는 껍질만 뒤집는다(recalc 는 겹친 껍질에서 틀림)
par = np.arange(nv)
def _find(x):
    r = x
    while par[r] != r:
        r = par[r]
    while par[x] != r:
        par[x], x = r, par[x]
    return r
for a_, b_, c_ in T:
    ra, rb, rc = _find(a_), _find(b_), _find(c_)
    par[rb] = ra; par[_find(c_)] = ra
comp = np.array([_find(i) for i in range(nv)])
tc = comp[T[:, 0]]
vol = np.einsum('ij,ij->i', V[T[:, 0]], np.cross(V[T[:, 1]], V[T[:, 2]]))
flipc = set()
for c_ in np.unique(tc):
    if vol[tc == c_].sum() < 0:
        flipc.add(c_)
flip = np.isin(tc, list(flipc))
T = T.copy(); T[flip] = T[flip][:, ::-1]
print('SHELLS', len(np.unique(tc)), 'flipped', len(flipc))
me = bpy.data.meshes.new('Tteunnun')
me.vertices.add(nv); me.vertices.foreach_set('co', V.astype(np.float32).ravel())
me.loops.add(nt * 3); me.loops.foreach_set('vertex_index', T.astype(np.int32).ravel())
me.polygons.add(nt); me.polygons.foreach_set('loop_start', np.arange(0, nt * 3, 3, dtype=np.int32)); me.polygons.foreach_set('loop_total', np.full(nt, 3, np.int32))
me.update(); me.validate()
body = bpy.data.objects.new('Tteunnun', me); sc.collection.objects.link(body)
V = np.array([v.co for v in me.vertices])
print('BODY', len(V), 'verts', len(me.polygons), 'tris', 'min', V.min(0).round(3), 'max', V.max(0).round(3), 'buckets', hdr['buckets'])
EC = np.array([hdr['eye']['c'][0], -hdr['eye']['c'][2], hdr['eye']['c'][1]]) * S; ER = hdr['eye']['r'] * S
FWD3 = np.array([0, -1.0, 0])
for nm, arr in (('dmat', MATV), ('bucket', BKV)):
    a = me.attributes.new(nm, 'FLOAT', 'POINT'); a.data.foreach_set('value', arr.astype(np.float32))
bone_v = np.zeros(nv)
for i, b in enumerate(hdr['buckets']):
    if b.startswith('T'):
        bone_v[BKV == i] = 1.0          # 가는 관(갈비 테·속눈썹·갈고리·손가락) — 뼈빛
a = me.attributes.new('thin', 'FLOAT', 'POINT'); a.data.foreach_set('value', bone_v.astype(np.float32))

# ---- 사람 손 4개(시안 손 관절 자리에 새 살) → 몸 메시에 합침
from limbs import build_limbs
_G = json.load(open(os.path.join(WORK, 'design_prims.json')))
from lids import build_lids
_lparts, _ljson = build_limbs(_G)
json.dump(_ljson, open(os.path.join(WORK, "limbs.json"), "w"))
_lg, _lsh = build_lids(EC, ER - .003)
_hobs = [to_object(g) for g in _lparts] + [to_object(_lg), to_object(_lsh)]   # 속눈썹도 몸에 합침(뼈빛)
_lash = None
for o in bpy.data.objects:
    o.select_set(False)
for o in _hobs:
    o.select_set(True)
body.select_set(True); vl.objects.active = body
bpy.ops.object.join()
me = body.data; me.materials.clear()
V = np.array([v.co for v in me.vertices]); nv = len(V)
print('HANDS added, verts', nv, 'tris', sum(len(p.vertices) - 2 for p in me.polygons))

# ---- 부위 속성: 허리 넝마(시안의 골반 덩어리), 눈꺼풀 가장자리 충혈·젖음
z = V[:, 2]
rag = smooth(.925, .945, z) * (1 - smooth(1.095, 1.115, z)) * (np.abs(V[:, 0]) < .2)
dE = np.linalg.norm(V - EC, axis=1)
dir_ = (V - EC) / np.maximum(dE, 1e-6)[:, None]
front = np.clip((dir_ @ FWD3 - .2) / .3, 0, 1)
lid = np.clip(1 - (dE - ER) / .05, 0, 1) * front * 0.0
if 'lidm' in me.attributes:
    lid = np.maximum(lid, np.array([a.value for a in me.attributes['lidm'].data]))
for nm, arr in (('rag', rag), ('lid', lid)):
    a = me.attributes.new(nm, 'FLOAT', 'POINT'); a.data.foreach_set('value', arr.astype(np.float32))
me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
mat_body = bpy.data.materials.get('Body') or bpy.data.materials.new('Body'); me.materials.append(mat_body)

# ---- 새 눈알(따로 된 구): 흰자·홍채, 각막, 동공 원판 — build.py 와 같은 방식, 크기만 시안 눈에 맞춤
R_EYE = ER - .003; RI = .112; PHI_I = math.asin(RI / R_EYE); RP = .051   # 세로로 째진 동공 원판(속은 짙은 홍채 안쪽 + 가운데 세로 틈)
E = EC
RGT = np.array([1.0, 0, 0]); UPV = np.array([0, 0, 1.0]); FWD = FWD3


def sph(th, phi, r):
    return E + r * (math.cos(phi) * FWD + math.sin(phi) * (math.cos(th) * RGT + math.sin(th) * UPV))


from tt_common import _connect
eg = Geo('Eyeball', 'Eye'); n = 48
phis = list(np.linspace(0, PHI_I, 13)) + list(np.linspace(PHI_I, math.pi, 34)[1:])
rings = []
for k, phi in enumerate(phis):
    if k == 0 or k == len(phis) - 1:
        p = E + FWD * (R_EYE * math.cos(PHI_I) - .002) if k == 0 else E - FWD * R_EYE
        rings.append([eg.nv()]); eg.V.append(p); continue
    idx = []
    for j in range(n):
        th = j / n * 2 * math.pi
        if phi <= PHI_I + 1e-6:
            rho = R_EYE * math.sin(phi); y = R_EYE * math.cos(PHI_I) - .002 + .003 * (rho / RI) ** 2
            p = E + FWD * y + rho * (math.cos(th) * RGT + math.sin(th) * UPV)
        else:
            p = sph(th, phi, R_EYE)
        idx.append(eg.nv()); eg.V.append(p)
    rings.append(idx)
for a in range(len(rings) - 1):
    ra, rb = rings[a], rings[a + 1]; va, vb = phis[a] / math.pi, phis[a + 1] / math.pi
    for j in range(n):
        j2 = (j + 1) % n; u0, u1 = j / n, (j + 1) / n
        if len(ra) == 1:
            eg.F.append((ra[0], rb[j], rb[j2])); eg.UV.append((((u0 + u1) / 2, va), (u0, vb), (u1, vb)))
        elif len(rb) == 1:
            eg.F.append((ra[j], rb[0], ra[j2])); eg.UV.append(((u0, va), ((u0 + u1) / 2, vb), (u1, va)))
        else:
            eg.F.append((ra[j], rb[j], rb[j2], ra[j2])); eg.UV.append(((u0, va), (u0, vb), (u1, vb), (u1, va)))
cg = Geo('Cornea', 'Cornea')
h = (R_EYE + .01) - R_EYE * math.cos(PHI_I); rl = RI + .006; Rc = (rl * rl + h * h) / (2 * h)
ctr = E + FWD * (R_EYE * math.cos(PHI_I) - .001 + h - Rc)
rings = [[cg.nv()]]; cg.V.append(ctr + FWD * Rc)
for k in range(1, 15):
    a = math.asin(rl / Rc) * k / 14; idx = []
    for j in range(48):
        th = j / 48 * 2 * math.pi
        idx.append(cg.nv()); cg.V.append(ctr + Rc * (math.cos(a) * FWD + math.sin(a) * (math.cos(th) * RGT + math.sin(th) * UPV)))
    rings.append(idx)
_connect(cg, rings, list(np.linspace(0, .1, len(rings))), .5)
pg = Geo('Pupil', 'Pupil')
pc = E + FWD * (R_EYE * math.cos(PHI_I) + .0012)
rings = [[pg.nv()]]; pg.V.append(pc)
for k in range(1, 9):
    r = RP * k / 8; idx = []
    for j in range(40):
        th = j / 40 * 2 * math.pi
        idx.append(pg.nv()); pg.V.append(pc + r * (math.cos(th) * RGT + math.sin(th) * UPV) - FWD * .0006 * (k / 8) ** 2)
    rings.append(idx)
uvp = lambda i: (.5 + .5 * np.dot(pg.V[i] - pc, RGT) / RP, .5 + .5 * np.dot(pg.V[i] - pc, UPV) / RP)
for a in range(len(rings) - 1):
    ra, rb = rings[a], rings[a + 1]
    for j in range(40):
        j2 = (j + 1) % 40
        if len(ra) == 1:
            pg.F.append((ra[0], rb[j], rb[j2])); pg.UV.append((uvp(ra[0]), uvp(rb[j]), uvp(rb[j2])))
        else:
            pg.F.append((ra[j], rb[j], rb[j2], ra[j2])); pg.UV.append((uvp(ra[j]), uvp(rb[j]), uvp(rb[j2]), uvp(ra[j2])))
EYEO = {g.name: to_object(g) for g in (eg, cg, pg)}

# ---- 몸 UV 펼치기
for o in bpy.data.objects:
    o.select_set(False)
body.select_set(True); vl.objects.active = body
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(name='UVMap')
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.remove_doubles(threshold=1e-6)
# (울퉁불퉁한 표면 그물 면 때문에 섬이 잘게 쪼개지지 않도록, 매끈하게 다듬은 사본 위치에서 펼친 뒤 원래 위치로 되돌린다)
bpy.ops.object.mode_set(mode='OBJECT')
_co0 = np.array([v.co for v in me.vertices]); _E = np.array([e.vertices[:] for e in me.edges])
_co = _co0.copy(); _deg = np.bincount(_E.ravel(), minlength=len(_co)).astype(float)[:, None]
for _ in range(12):
    _acc = np.zeros_like(_co); np.add.at(_acc, _E[:, 0], _co[_E[:, 1]]); np.add.at(_acc, _E[:, 1], _co[_E[:, 0]])
    _co = _co + .6 * (_acc / np.maximum(_deg, 1) - _co)
me.vertices.foreach_set('co', _co.astype(np.float32).ravel()); me.update()
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(80), island_margin=0.0015, area_weight=0.0, scale_to_bounds=True)
bpy.ops.uv.pack_islands(rotate=True, margin=0.002)
bpy.ops.object.mode_set(mode='OBJECT')
me.vertices.foreach_set('co', _co0.astype(np.float32).ravel()); me.update()


# ---- 몸 재질: 회색 굶주린 피부 + 튀어나온 뼈(갈비·등뼈·눈꺼풀 손가락)는 희게, 골은 때 끼어 어둡게 + 허리 넝마
def body_shader(mat):
    b = NB(mat)
    pos = b.n('ShaderNodeTexCoord').outputs['Object']
    pt = b.n('ShaderNodeNewGeometry').outputs['Pointiness']
    ridge = b.ramp(pt, .515, .58); cav = b.ramp(pt, .495, .44)
    n1 = b.noise(pos, 4.0, 8, .6); n2 = b.noise(pos, 18.0, 6, .6); n3 = b.noise(pos, 60.0, 4)
    col = b.mix(n1, (.22, .215, .21), (.31, .3, .29))
    col = b.mix(b.math('MULTIPLY', n2, .5), col, (.19, .18, .175))
    blot = b.ramp(b.noise(pos, 2.2, 4, .55), .55, .7)
    col = b.mix(b.math('MULTIPLY', blot, .6), col, (.15, .14, .14))
    dpos = b.n('ShaderNodeVectorMath', {0: pos, 1: b.noise(pos, 5.0, 2, .5, out='Color')}, operation='ADD').outputs[0]
    vl_ = b.ramp(b.voronoi(dpos, 11.0, 'DISTANCE_TO_EDGE'), .03, 0.0)
    vmask = b.math('MULTIPLY', vl_, b.ramp(b.noise(pos, 3.0, 2), .45, .62))
    col = b.mix(b.math('MULTIPLY', vmask, .35), col, (.22, .24, .28))
    bone = b.math('MULTIPLY', b.math('MAXIMUM', ridge, b.math('MULTIPLY', b.attr('thin'), .85)), b.ramp(n3, .2, .6))
    col = b.mix(b.math('MULTIPLY', bone, .75), col, (.66, .62, .55))
    col = b.mix(b.math('MULTIPLY', cav, .85), col, (.07, .065, .06))
    hs = b.attr('headskin')                                  # 눈알 머리 살: 따뜻한 갈회색, 울퉁불퉁
    col = b.mix(b.math('MULTIPLY', hs, .55), col, b.mix(n2, (.42, .34, .3), (.33, .27, .25)))
    pebble = b.ramp(b.voronoi(pos, 160.0), .5, .0)
    col = b.mix(b.math('MULTIPLY', b.math('MULTIPLY', hs, pebble), .25), col, (.5, .42, .38))
    nail = b.ramp(b.attr('nail'), .45, .56)
    col = b.mix(nail, col, b.mix(b.ramp(n3, .3, .7), (.6, .55, .45), (.42, .37, .28)))
    lid = b.attr('lid')
    col = b.mix(b.math('MULTIPLY', lid, .3), col, (.45, .31, .29))
    lip = b.attr('lip')                                       # 두툼한 눈꺼풀 입술: 참고 그림의 분홍빛 갈색
    col = b.mix(b.math('MULTIPLY', lip, .75), col, b.mix(n2, (.56, .38, .35), (.46, .3, .28)))
    # 눈꺼풀 가장자리: 젖은 분홍 점막 + 기름샘 작은 점 + 핏줄
    edge = b.ramp(lid, .88, .98)
    col = b.mix(b.math('MULTIPLY', edge, .45), col, (.52, .34, .32))
    dots = b.math('MULTIPLY', b.ramp(b.voronoi(pos, 700.0), .1, .0), edge)
    col = b.mix(b.math('MULTIPLY', dots, .6), col, (.85, .78, .62))
    lv = b.math('MULTIPLY', b.ramp(b.voronoi(b.n('ShaderNodeVectorMath', {0: pos, 1: b.noise(pos, 40.0, 2, .5, out='Color')}, operation='ADD').outputs[0], 90.0, 'DISTANCE_TO_EDGE'), .04, .0), b.ramp(lid, .3, .8))
    col = b.mix(b.math('MULTIPLY', lv, .5), col, (.45, .08, .07))
    rag = b.ramp(b.attr('rag'), .4, .6)
    linen = b.mix(b.noise(pos, 7.0, 6, .6), (.36, .33, .29), (.27, .25, .22))
    linen = b.mix(b.ramp(b.noise(pos, 2.5, 5, .6), .58, .7), linen, (.14, .12, .1))
    linen = b.mix(b.math('MULTIPLY', cav, .8), linen, (.06, .05, .045))
    col = b.mix(rag, col, linen)
    rough = b.math('ADD', .6, b.math('MULTIPLY', n2, .18))
    rough = b.fmix(ridge, rough, .48)
    rough = b.fmix(b.math('MULTIPLY', lid, .7), rough, .25)
    rough = b.fmix(edge, rough, .12)
    rough = b.fmix(b.math('MULTIPLY', lip, .6), rough, .3)
    rough = b.fmix(rag, rough, .92)
    rough = b.fmix(nail, rough, .33)
    hgt = b.math('ADD', b.math('MULTIPLY', b.noise(pos, 420.0, 2, .5), .3),
                 b.math('MULTIPLY', b.wave(pos, 110.0, 10.0, 'Z', 4.0), .55))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', b.noise(pos, 32.0, 5), .7))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', vmask, .4))
    weave = b.math('MULTIPLY', b.math('ADD', b.wave(pos, 700.0, .5, 'X', 0.0), b.wave(pos, 700.0, .5, 'Z', 0.0)), .3)
    hgt = b.fmix(rag, hgt, b.math('ADD', weave, b.math('MULTIPLY', b.noise(pos, 14.0, 4, .5, 2.0), 1.0)))
    hgt = b.math('ADD', hgt, b.math('MULTIPLY', hs, b.math('ADD', b.math('MULTIPLY', pebble, .9), b.math('MULTIPLY', b.wave(pos, 260.0, 14.0, 'X', 3.0), .4))))
    bump = b.n('ShaderNodeBump', {'Height': hgt, 'Strength': .6, 'Distance': .0016})
    return b, col, rough, None, bump.outputs['Normal']


setup_gpu()
sc.render.bake.margin = 16
sc.world = bpy.data.worlds.new('World'); sc.world.light_settings.distance = .12
# 눈 텍스처: 회색 흰자, 짙은 청회색 홍채, 큰 동공(홍채 반지름 대비)
paint_eye(); paint_pupil()
baked = bake(body, mat_body, body_shader, BODY_TEX)
for k in ('basecolor', 'roughness', 'normal', 'ao'):
    os.replace(os.path.join(TEXD, 'body_' + k + '.png'), os.path.join(TEXD, 'body_' + k + '.png')) if os.path.exists(os.path.join(TEXD, 'body_' + k + '.png')) else None
final_material(mat_body, baked, sss=.08)
ld = lambda nm: bpy.data.images.get(nm) or bpy.data.images.load(os.path.join(TEXD, nm + '.png'))
eimg = {k: ld('eye_' + k) for k in ('basecolor', 'roughness', 'normal', 'ao')}
for k in ('roughness', 'normal', 'ao'):
    eimg[k].colorspace_settings.name = 'Non-Color'
final_material(EYEO['Eyeball'].data.materials[0], eimg, sss=.05)
pimg = {k: ld('pupil_' + k) for k in ('basecolor', 'roughness', 'normal', 'ao')}
for k in ('roughness', 'normal', 'ao'):
    pimg[k].colorspace_settings.name = 'Non-Color'
final_material(EYEO['Pupil'].data.materials[0], pimg)
pc_ = final_material(EYEO['Cornea'].data.materials[0], None)
pc_.inputs['Base Color'].default_value = (1, 1, 1, 1); pc_.inputs['Roughness'].default_value = 0.0
pc_.inputs['Transmission Weight'].default_value = 1.0
pc_.inputs['Alpha'].default_value = .06; pc_.inputs['Specular IOR Level'].default_value = .8; pc_.inputs['IOR'].default_value = 1.376
EYEO['Cornea'].data.materials[0].surface_render_method = 'BLENDED'   # (게임용 파일은 반투명, 렌더는 render.py 가 굴절로 바꿈)
body.name = 'Tteunnun'; me.name = 'Tteunnun'
np.save(os.path.join(WORK, 'eye_fit.npy'), np.r_[EC, ER])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'retexA.blend'))
print('SAVED retexA', 'tris', sum(len(p.vertices) - 2 for p in me.polygons))
