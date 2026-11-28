# sullae.blend 의 모든 동작에서 턱(Jaw) 회전을 쉬는 자세로 고정한다(관절인형: 입을 벌리지 않음)
#   blender -b --factory-startup -noaudio -P zero_jaw.py -- <out_dir>
import bpy, sys, os
from bpy_extras import anim_utils
OUT = sys.argv[sys.argv.index('--') + 1:][0]
bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT, 'sullae.blend'))
n = 0
for act in bpy.data.actions:
    for slot in act.slots:
        cb = anim_utils.action_get_channelbag_for_slot(act, slot)
        if cb is None: continue
        for fc in cb.fcurves:
            if fc.data_path == 'pose.bones["Jaw"].rotation_quaternion':
                v = 1.0 if fc.array_index == 0 else 0.0
                for kp in fc.keyframe_points:
                    kp.co[1] = v; kp.handle_left[1] = v; kp.handle_right[1] = v
                fc.update(); n += 1
print('JAW fcurves zeroed', n)
bpy.ops.wm.save_mainfile()
