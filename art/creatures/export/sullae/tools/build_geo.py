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
    if p.kind == 'cone':
        pts = np.vstack([np.array(p.a) + U * p.r1, np.array(p.b) + U * p.r2])
    else:
        pts = np.array(p.a) + (U * np.array(p.rad)) @ np.array(p.R).T
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
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(WORK, 'geo.blend'))
print('SAVED geo', f'{time.time() - t0:.1f}s')
