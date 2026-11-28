# 눈 동작 검수 그림: 동작마다 시작·절정·끝 프레임을 정면·측면·후면·사선에서 찍어 한 장(renders/qa_<동작>.png)
#   blender -b tteunnun.blend -P qa_render.py
import sys, os, math, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from tt_common import OUT, WORK, look

sc = bpy.context.scene
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview.py'), encoding='utf-8').read()
sys.argv = [sys.argv[0]]
exec(src.split('cam = stage(sc)')[0])
cam = stage(sc)
sc.render.resolution_x = sc.render.resolution_y = 420
sc.eevee.taa_render_samples = 24
arm = bpy.data.objects['TteunnunRig']; ad = arm.animation_data
for tr in ad.nla_tracks:
    tr.mute = True
E = arm.data.bones['Eye'].head_local
VIEWS = [('front', (0, -1.55, .05)), ('side', (1.55, -.15, .05)), ('back', (-.4, 1.55, .25)), ('34', (1.05, -1.15, .3))]
CLIPS = {'EyeOpen': (0, 30, 59), 'Blink': (0, 3, 4), 'BlinkFast': (0, 1, 2), 'BlinkSlow': (0, 8, 16), 'EyeSmile': (0, 25, 49),
         'EyeClose': (0, 5, 39), 'EyeClosedHold': (0, 15, 29), 'EyeReopen': (0, 6, 12), 'EyeWide': (0, 15, 29), 'LookLR': (0, 15, 44), 'LookUD': (0, 15, 44)}
d = os.path.join(WORK, 'qa'); os.makedirs(d, exist_ok=True)
for name, frames in CLIPS.items():
    for _pb in arm.pose.bones:
        _pb.location = (0, 0, 0); _pb.rotation_euler = (0, 0, 0); _pb.rotation_quaternion = (1, 0, 0, 0); _pb.scale = (1, 1, 1)
    ad.action = bpy.data.actions[name]
    files = []
    for f in frames:
        sc.frame_set(f)
        for vn, off in VIEWS:
            cam.location = E + __import__('mathutils').Vector(off); look(cam, E); cam.data.lens = 40
            sc.render.filepath = os.path.join(d, '%s_%02d_%s.png' % (name, f, vn))
            bpy.ops.render.render(write_still=True)
            files.append(sc.render.filepath)
    args = ['ffmpeg', '-loglevel', 'error', '-y']
    for fp in files:
        args += ['-i', fp]
    n = len(files); cols = 4
    rows = ''.join('[%d]' % i for i in range(n))
    layout = '|'.join('%d_%d' % ((i % cols) * 420, (i // cols) * 420) for i in range(n))
    args += ['-filter_complex', rows + 'xstack=inputs=%d:layout=%s' % (n, layout), os.path.join(OUT, 'renders', 'qa_%s.png' % name)]
    subprocess.run(args, check=True)
    print('QA SHEET', name)
