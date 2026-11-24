#!/bin/bash
# 56종: 얼굴 고해상도 메시(lines3d NODOTS) → 시안 그림 텍스처(texbake) [→ UPLOAD=1 이면 올리기]
#   bash run3d.sh N(작업자 수) [id...]
cd "$(dirname "$0")"
W=${1:-3}; shift
IDS=${@:-$(node -e "console.log(Object.keys(require('./meshids.json')).join(' '))")}
mkdir -p out/log3d
work() { for id in "$@"; do
  { NODOTS=1 node lines3d.js $id && PREVIEW=1 node texbake.js $id && { [ -z "$UPLOAD" ] || FORCE=1 node upload.js $id; }; } > out/log3d/$id.txt 2>&1
  echo "$id $(grep -h 'textured parts\|asset\|FAIL\|rror' out/log3d/$id.txt | grep -v '^\[' | tail -1)"
done; }
arr=($IDS); n=${#arr[@]}
for ((w=0; w<W; w++)); do sel=(); for ((i=w; i<n; i+=W)); do sel+=(${arr[i]}); done; work "${sel[@]}" & done
wait; echo ALLDONE
