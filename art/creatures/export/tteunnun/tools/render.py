# 동작마다 렌더(소리 없음): blender -b tteunnun.blend --factory-startup -noaudio -P render.py -- [clip ...]
# work/frames/<clip>/0000.png 로 찍고, 영상은 ffmpeg 로 따로 묶는다(render_video.sh).
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from tt_common import OUT, WORK, look

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
sc = bpy.context.scene
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview.py'), encoding='utf-8').read()
sys.argv = [sys.argv[0]]
exec(src.split('cam = stage(sc)')[0])
cam = stage(sc)
if os.environ.get('REAL'):
    realistic(sc)
sc.render.resolution_x, sc.render.resolution_y = 540, 720
sc.eevee.taa_render_samples = 32
sc.render.image_settings.file_format = 'PNG'
arm = bpy.data.objects['TteunnunRig']
ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
FULL = ((2.7, -4.3, 1.75), (0, -.05, 1.15), 46)
CAMS = {'EyeDart': ((.55, -1.75, 2.05), (0, -.08, 1.96), 55), 'Stare': ((.45, -1.9, 2.0), (0, -.08, 1.93), 50),
        'Death': ((3.2, -4.4, 1.6), (0, .25, .8), 40), 'Attack': ((3.0, -4.4, 1.7), (0, -.2, 1.15), 42), 'Kill': ((2.6, -4.4, 1.8), (0, -.25, 1.3), 40),
        'Jumpscare': ((0, -2.6, 1.95), (0, -.2, 1.75), 30), 'Spot': ((2.7, -4.3, 1.75), (0, -.05, 1.15), 46)}
clips = [a for a in argv if a in ('Idle','Walk','Run','Attack','LookAround','Hit','Death','EyeDart','Stare','Kill','Jumpscare','Spot')] or ['Idle', 'Walk', 'Run', 'Attack', 'LookAround', 'Hit', 'Death', 'EyeDart', 'Stare', 'Kill', 'Jumpscare', 'Spot']
for name in clips:
    act = bpy.data.actions[name]
    ad.action = act
    n0, n1 = int(act.frame_range[0]), int(act.frame_range[1])
    if act.use_cyclic:
        n1 -= 1           # 끝 프레임 = 첫 프레임이므로 빼고 찍어 반복 재생이 끊기지 않게
    loc, tgt, lens = CAMS.get(name, FULL)
    cam.location = loc; look(cam, tgt); cam.data.lens = lens
    d = os.path.join(WORK, 'frames', name); os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    for f in range(n0, n1 + 1):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(d, '%04d.png' % f)
        bpy.ops.render.render(write_still=True)
    print('RENDERED', name, n1 - n0 + 1)
