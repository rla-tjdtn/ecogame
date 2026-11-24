#!/bin/bash
# 지정한 괴물들을 3묶음으로 다시: 메시·뼈·웨이트 → 프레임 묶음 정리 → 선 입히기 → 미리보기 → 원본 비교
cd "$(dirname "$0")"
set -- "$@"; n=$#; t=$(( (n+2)/3 ))
run() { for id in "$@"; do for try in 1 2; do node rig.js $id > out/rb_$id.log 2>&1 && break; done; grep "QA" out/rb_$id.log; node linebake.js $id 2>&1 | grep lines; node animview.js $id; node designref.js $id 2>/dev/null; done; }
run "${@:1:$t}" & run "${@:$((t+1)):$t}" & run "${@:$((2*t+1))}" & wait
node fixlua.js > /dev/null; echo done
