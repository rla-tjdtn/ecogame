#!/usr/bin/env bash
# 전체 다시 만들기(소리·업로드 없음). 원본(source/**)은 읽기만 한다.
#  1) design_mesh.js : e10h.js 시안 → 고해상도 메시(work/design_*.bin)   2) design_dump.js : 시안 도형 → 관절 자리(work/design_prims.json)
#  3) retex.py : 따로 된 눈알 + UV + 절차 재질 굽기(textures/)            4) rig.py : 이름 붙인 뼈 99개 + 웨이트
#  5) animate.py : IK·시선 조종 + 동작 9개 → tteunnun.blend/.glb/.fbx    6) verify.py · stress.py · render.py · render_video.sh
set -e
cd "$(dirname "$0")/.."
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
X="--factory-startup -noaudio --python-exit-code 1"
node tools/design_mesh.js
node tools/design_dump.js > /dev/null
"$B" -b $X -P tools/retex.py
"$B" -b work/retexA.blend $X -P tools/rig.py
"$B" -b work/stageB.blend $X -P tools/animate.py
"$B" -b $X -P tools/verify.py
"$B" -b tteunnun.blend $X -P tools/stress.py
"$B" -b tteunnun.blend $X -P tools/render.py
bash tools/render_video.sh
