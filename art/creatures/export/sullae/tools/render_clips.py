# 6단계: 동작마다 모든 프레임을 PNG 로 찍는다(EEVEE, 소리 없음). mp4/gif 는 ffmpeg 로 묶는다(-an).
#   blender -b --factory-startup -noaudio -P render_clips.py -- <blend> <frames_dir> <Clip[,Clip]|all> [full|face]
import bpy, sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import render_util as RU
argv = sys.argv[sys.argv.index('--') + 1:]
blend, out, clips = argv[0], argv[1], argv[2]
mode = argv[3] if len(argv) > 3 else 'full'
bpy.ops.wm.open_mainfile(filepath=blend)
ARM = bpy.data.objects['Sullae']
for tr in ARM.animation_data.nla_tracks: tr.mute = True
for o in bpy.data.objects:
    if o.name.endswith('Hi'): o.hide_render = True
RU.setup(res=(540, 720) if mode == 'full' else (600, 600))
sc = bpy.context.scene
sc.eevee.taa_render_samples = 24
names = [a.name for a in bpy.data.actions] if clips == 'all' else clips.split(',')
VIEW = {  # 목표점, 방향(도), 거리, 높이
    'full': {'_': ((0, -.05, 1.05), 28, 4.3, .45), 'Death': ((0, -.35, .7), 40, 4.6, .9), 'Attack': ((0, -.25, 1.1), 35, 4.6, .5), 'Run': ((0, -.05, 1.0), 60, 4.4, .4),
             'Walk': ((0, -.05, 1.05), 50, 4.3, .4), 'Kill': ((0, -.35, 1.2), 55, 3.8, .3), 'Jumpscare': ((0, -.2, 1.45), 0, 2.6, .0)},
    'face': {'_': ((0, -.12, 1.84), 12, 1.05, -.05), 'Peek': ((0, -.12, 1.84), 18, 1.0, -.05), 'Jumpscare': ((0, -.25, 1.75), 0, 1.5, -.05)},
}[mode]
for c in names:
    act = bpy.data.actions[c]; ARM.animation_data.action = act; ARM.animation_data.action_slot = act.slots[0]
    tgt, yaw, dist, h = VIEW.get(c, VIEW['_'])
    RU.aim(tgt, yaw, dist, h)
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    last = f1 - 1 if act.use_cyclic else f1  # 반복 동작은 마지막(=첫) 프레임을 빼서 이음매가 겹치지 않게
    d = os.path.join(out, f'{c}_{mode}'); os.makedirs(d, exist_ok=True)
    for f in range(f0, last + 1):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(d, f'f{f:04d}.png'); sc.render.image_settings.file_format = 'PNG'
        bpy.ops.render.render(write_still=True)
    print('RENDERED', c, mode, last - f0 + 1, flush=True)
