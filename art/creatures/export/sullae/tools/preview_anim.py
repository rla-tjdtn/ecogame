# 동작 미리보기: 클립마다 몇 프레임을 찍는다(소리 없음)
#   blender -b -P preview_anim.py -- <blend> <out_dir> <Clip[,Clip]> [n] [yaw]
import bpy, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import render_util as RU
argv = sys.argv[sys.argv.index('--') + 1:]
blend, out, clips = argv[0], argv[1], argv[2].split(',')
n = int(argv[3]) if len(argv) > 3 else 4; yaw = float(argv[4]) if len(argv) > 4 else 25
os.makedirs(out, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=blend)
ARM = bpy.data.objects['Sullae']
for tr in ARM.animation_data.nla_tracks: tr.mute = True
RU.setup(res=(480, 640))
tgt = (0, -.05, float(os.environ.get('CAMZ', '1.1'))); dist = float(os.environ.get('DIST', '4.2'))
for c in clips:
    act = bpy.data.actions[c]; ARM.animation_data.action = act; ARM.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    for k in range(n):
        bpy.context.scene.frame_set(int(round(f0 + (f1 - f0) * k / max(1, n - (0 if act.use_cyclic else 1)))))
        RU.aim(tgt, yaw, dist, float(os.environ.get('CAMH', '.35')))
        RU.shot(os.path.join(out, f'{c}_{k:02d}.png'))
