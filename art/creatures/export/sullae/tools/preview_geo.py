# geo.blend 미리보기(점토 재질): 앞/옆/3-4, 얼굴, 손
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import render_util as RU
argv = sys.argv[sys.argv.index('--') + 1:]
blend, out = argv[0], argv[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
obj = bpy.data.objects[os.environ.get('OBJ', 'SullaeBody')]
for o in bpy.data.objects:
    if o.type == 'MESH' and o is not obj and o.name.startswith('Sullae'):
        o.hide_render = True
RU.setup(res=(640, 860), clay=[obj])
for nm, tgt, yaw, dist, h in (('front', (0, 0, 1.08), 0, 4.6, .1), ('side', (0, 0, 1.08), 90, 4.6, .1), ('q34', (0, 0, 1.08), 35, 4.6, .3),
                              ('face', (0, -.06, 1.88), 15, 1.25, .0), ('hand', (.78, -.2, 1.38), 20, .8, .25), ('back', (0, 0, 1.08), 180, 4.6, .3), ('feet', (0, -.05, .12), 30, 1.1, .35)):
    RU.aim(tgt, yaw, dist, h)
    RU.shot(os.path.join(out, f'geo_{nm}.png'))
