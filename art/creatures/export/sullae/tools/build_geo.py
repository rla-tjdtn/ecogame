# 1단계: 몸 메시 만들기 — 형태(SDF) 원형들의 단단한 합집합 → 복셀 리메시 → 부드러운 합집합 표면으로 투영
#   → 고해상도(노멀 굽기용) + 게임용 저해상도(데시메이트)
#   blender -b --factory-startup -noaudio -P build_geo.py -- <work_dir>
import bpy, bmesh, sys, os, time, math
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(__file__))
import sullae_def as SD

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
WORK = argv[0] if argv else os.path.join(os.path.dirname(__file__), '..', 'work')
VOX = float(os.environ.get('VOX', '0.0021'))
LOW_TRIS = int(os.environ.get('LOW_TRIS', '42000'))
os.makedirs(WORK, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
t0 = time.time()

plist = SD.prims()
print('prims', len(plist))

# 단위 구 점(정이십면체 분할)
bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
U = np.array([v.co[:] for v in bm.verts]); bm.free()

V_all, F_all = [], []
for p in plist:
    if p.op != 'add' or p.kind == 'torus':
        continue
    pts = SD.prim_points(p, U)
    b = bmesh.new()
    vs = [b.verts.new(q) for q in pts]
    r = bmesh.ops.convex_hull(b, input=vs)
    bmesh.ops.delete(b, geom=list({g for g in r['geom_interior'] + r['geom_unused'] if isinstance(g, bmesh.types.BMVert)}), context='VERTS')
    b.verts.index_update()
    off = sum(len(v) for v in V_all)
    V_all.append([v.co[:] for v in b.verts])
    F_all += [[off + v.index for v in f.verts] for f in b.faces]
    b.free()
V = [q for vs in V_all for q in vs]
me = bpy.data.meshes.new('union'); me.from_pydata(V, [], F_all); me.update()
ob = bpy.data.objects.new('union', me); bpy.context.scene.collection.objects.link(ob)
print('hull verts', len(V), 'faces', len(F_all), f'{time.time() - t0:.1f}s')

md = ob.modifiers.new('rm', 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = VOX; md.adaptivity = 0
dg = bpy.context.evaluated_depsgraph_get()
hi = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
hi.name = 'SullaeHi'
print('remesh verts', len(hi.vertices), 'polys', len(hi.polygons), f'{time.time() - t0:.1f}s')
bpy.data.objects.remove(ob)

co = np.empty(len(hi.vertices) * 3); hi.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
co = SD.project(co, plist, iters=int(os.environ.get('ITERS', '4')))
hi.vertices.foreach_set('co', co.ravel()); hi.update()
print('projected', f'{time.time() - t0:.1f}s')

ohi = bpy.data.objects.new('SullaeHi', hi); bpy.context.scene.collection.objects.link(ohi)
for p in hi.polygons:
    pass
hi.shade_smooth() if hasattr(hi, 'shade_smooth') else None
# 가벼운 이완(투영 뒤 뭉친 정점 정리) — 모양은 거의 안 바뀐다
sm = ohi.modifiers.new('relax', 'SMOOTH'); sm.factor = .35; sm.iterations = 2
dg = bpy.context.evaluated_depsgraph_get()
hi2 = bpy.data.meshes.new_from_object(ohi.evaluated_get(dg)); ohi.modifiers.clear()
co = np.empty(len(hi2.vertices) * 3); hi2.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
co = SD.project(co, plist, iters=2)
hi2.vertices.foreach_set('co', co.ravel()); hi2.update()
old = ohi.data; ohi.data = hi2; bpy.data.meshes.remove(old); hi2.name = 'SullaeHi'
ntri = sum(len(p.vertices) - 2 for p in hi2.polygons)
print('hi tris', ntri)

# 게임용 저해상도
olo = bpy.data.objects.new('SullaeBody', hi2.copy()); bpy.context.scene.collection.objects.link(olo)
dc = olo.modifiers.new('dec', 'DECIMATE'); dc.decimate_type = 'COLLAPSE'; dc.ratio = LOW_TRIS / ntri; dc.use_symmetry = True; dc.symmetry_axis = 'X'
dg = bpy.context.evaluated_depsgraph_get()
lo = bpy.data.meshes.new_from_object(olo.evaluated_get(dg)); olo.modifiers.clear()
old = olo.data; olo.data = lo; bpy.data.meshes.remove(old); lo.name = 'SullaeBody'
bm = bmesh.new(); bm.from_mesh(lo); bmesh.ops.triangulate(bm, faces=bm.faces[:]); bm.to_mesh(lo); bm.free()
for m_ in (hi2, lo):
    m_.polygons.foreach_set('use_smooth', [True] * len(m_.polygons))
print('lo tris', len(lo.polygons), f'{time.time() - t0:.1f}s')
# ---- 손·머리는 더 촘촘한 복셀로 다시 만들어 노멀 굽기 원본을 바꿔 낀다(마디 주름·손톱 홈·이마 주름·핏줄이 보이게)
ARMS_ = [(np.array(wr[:]), np.array((wr - el).normalized()[:])) for (c0, sh, el, wr, f, n) in SD.ARM_INFO.values()]
HC = np.array(SD.HEAD_C[:])
# 손 영역 = 손목→손가락 마디 뼈 선분에서 2.8cm 안(머리 가까이 있는 손이 머리 표면까지 잡아먹지 않게)
HSEG = []
for (tag_, sd_), (c0, sh, el, wr, f, n) in SD.ARM_INFO.items():
    m_ = SD.SIDES[sd_]; fd_ = np.array((wr - el).normalized()[:])
    for fi_ in range(5):
        pts_, _ = SD.finger_rest(f, n, wr, m_, fi_)
        chain_ = [wr] + pts_
        for i_ in range(len(chain_) - 1):
            HSEG.append((np.array(chain_[i_][:]), np.array(chain_[i_ + 1][:]), np.array(wr[:]), fd_))
def in_hand(P, slack=0.0):
    m = np.zeros(len(P), bool)
    for a_, b_, wr_, fd_ in HSEG:
        ab = b_ - a_; t = np.clip(((P - a_) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(P - (a_ + t[:, None] * ab), axis=1)
        m |= (d < .028 + slack) & (((P - wr_) @ fd_) > -.015 - slack)
    return m
def in_head(P, slack=0.0):
    return (np.linalg.norm(P - HC, axis=1) < .42 + slack) & (P[:, 2] > 1.675 - slack) & ~in_hand(P, .05)
def centers(me):
    P = np.empty(len(me.polygons) * 3); me.polygons.foreach_get('center', P); return P.reshape(-1, 3)
def hull_mesh(sel):
    V_all, F_all = [], []
    for p in sel:
        pts = SD.prim_points(p, U)
        b = bmesh.new(); vs = [b.verts.new(q) for q in pts]; r = bmesh.ops.convex_hull(b, input=vs)
        bmesh.ops.delete(b, geom=list({g for g in r['geom_interior'] + r['geom_unused'] if isinstance(g, bmesh.types.BMVert)}), context='VERTS')
        b.verts.index_update(); off = sum(len(v) for v in V_all)
        V_all.append([v.co[:] for v in b.verts]); F_all += [[off + v.index for v in f.verts] for f in b.faces]; b.free()
    me = bpy.data.meshes.new('h'); me.from_pydata([q for vs in V_all for q in vs], [], F_all); me.update(); return me
def prim_center(p):
    return (np.array(p.a) + np.array(p.b)) / 2 if p.kind == 'cone' else np.array(p.a)
def keep_faces(me, mask):
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f, k in zip(bm.faces, mask) if not k], context='FACES'); bm.to_mesh(me); bm.free()
def fix_spikes(me, rounds=3):
    """투영이 덜 된(표면에서 0.4mm 넘게 떨어진) 정점과 이웃을 평균으로 다듬고 다시 투영한다 — 가시 모양 오류 제거"""
    for r_ in range(rounds):
        co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        f = np.abs(SD.sdf(co, plist))
        bad = np.nonzero(f > .0004)[0]
        print('  spikes', len(bad), flush=True)
        if len(bad) == 0: break
        bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
        sel = {bm.verts[i] for i in bad}
        for v in list(sel):
            for e in v.link_edges: sel.add(e.other_vert(v))
        bmesh.ops.smooth_vert(bm, verts=list(sel), factor=.8, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        bmesh.ops.smooth_vert(bm, verts=list(sel), factor=.8, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        idx = np.array(sorted(v.index for v in sel))
        bm.to_mesh(me); bm.free()
        co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        co[idx] = SD.project(co[idx], plist, iters=3)
        me.vertices.foreach_set('co', co.ravel()); me.update()


pieces = []
for name, region, vox in (('hands', in_hand, float(os.environ.get('VOX_HAND', '0.0008'))), ('head', in_head, float(os.environ.get('VOX_HEAD', '0.0012')))):
    C_ = np.array([prim_center(p) for p in plist])
    sel = [p for p, c in zip(plist, C_) if p.op == 'add' and p.kind != 'torus' and region(c[None, :], .09)[0]]
    def remesh(me_):
        oh = bpy.data.objects.new('tmp_' + name, me_); bpy.context.scene.collection.objects.link(oh)
        md = oh.modifiers.new('rm', 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = vox; md.adaptivity = 0
        dg = bpy.context.evaluated_depsgraph_get(); out = bpy.data.meshes.new_from_object(oh.evaluated_get(dg))
        bpy.data.objects.remove(oh); bpy.data.meshes.remove(me_); return out
    def proj(me_, it):
        co = np.empty(len(me_.vertices) * 3); me_.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
        co = SD.project(co, plist, iters=it); me_.vertices.foreach_set('co', co.ravel()); me_.update()
    # 껍질 → 리메시 → 투영을 세 번: 홈·눈꺼풀 틈의 모양이 위상에 들어가 늘어진 지느러미 삼각형이 생기지 않는다
    dm = remesh(hull_mesh(sel)); proj(dm, 4)
    dm = remesh(dm); proj(dm, 3)
    dm = remesh(dm); proj(dm, 3)
    fix_spikes(dm)
    keep_faces(dm, region(centers(dm), .004))
    print(name, 'detail polys', len(dm.polygons), f'{time.time() - t0:.1f}s', flush=True)
    pieces.append(dm)
hib = ohi.data
cP = centers(hib)
keep_faces(hib, ~(in_hand(cP, -.004) | in_head(cP, -.004)))
bm = bmesh.new(); bm.from_mesh(hib)
for dm in pieces: bm.from_mesh(dm)
bm.to_mesh(hib); bm.free()
hib.polygons.foreach_set('use_smooth', [True] * len(hib.polygons))
print('hi composite tris', sum(len(p.vertices) - 2 for p in hib.polygons), flush=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'geo.blend'))
print('SAVED geo', f'{time.time() - t0:.1f}s')
