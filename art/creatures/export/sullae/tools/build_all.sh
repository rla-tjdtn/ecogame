#!/bin/sh
# 술래 3D 실사판 전체 다시 만들기(소리·업로드 없음). sullae/ 폴더에서 실행: sh tools/build_all.sh
# 원본 art/creatures/source/** 와 src/** 는 읽기만 한다.
set -e
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
HERE=$(pwd); W=$(cygpath -w "$HERE/work" 2>/dev/null || echo "$HERE/work"); O=$(cygpath -w "$HERE" 2>/dev/null || echo "$HERE")
mkdir -p work
VOX=0.0021 ITERS=3 LOW_TRIS=38000 "$B" -b --factory-startup -noaudio -P tools/build_geo.py -- "$W"      # 1 모델(고해상도 + 게임용)
"$B" -b --factory-startup -noaudio -P tools/build_model.py -- "$W" "$O"                                   # 2 눈·손톱·천·UV·PBR 굽기·뼈대·웨이트
"$B" -b --factory-startup -noaudio -P tools/build_anim.py -- "$W" "$O"                                    # 3 동작 9개 → sullae.blend
"$B" -b --factory-startup -noaudio -P tools/export.py -- "$O"                                             # 4 sullae.glb / sullae.fbx
"$B" -b --factory-startup -noaudio -P tools/verify.py -- "$O/sullae.glb" "$O/verify_glb.json"           # 5 다시 읽어 확인
"$B" -b --factory-startup -noaudio -P tools/verify.py -- "$O/sullae.fbx" "$O/verify_fbx.json"
"$B" -b --factory-startup -noaudio -P tools/render_clips.py -- "$O/sullae.blend" "$W/frames" all full  # 6 동작 렌더
"$B" -b --factory-startup -noaudio -P tools/render_clips.py -- "$O/sullae.blend" "$W/frames" Count,Peek,Idle face
sh tools/make_videos.sh work/frames previews
