#!/bin/bash
# 메시가 나온 괴물마다: 시안 선 입히기 → 움직임 미리보기(out/mesh/<id>_anim.png)
cd "$(dirname "$0")"
for id in "$@"; do
  [ -f out/mesh/${id}_anim.json ] || { echo "skip $id"; continue; }
  node linebake.js $id 2>&1 | grep "lines" ; node animview.js $id && echo "$id view ok"
done
