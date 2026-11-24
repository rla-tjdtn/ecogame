#!/bin/bash
# 마무리: 텍스처 다시 붙이기(그림 재사용) → 텍스처 이미지 올리기 → 메시 올리기 → SurfaceAppearance 모델(json)
#   bash final3d.sh N(작업자 수) [id...]
cd "$(dirname "$0")"
W=${1:-3}; shift
IDS=${@:-$(node -e "console.log(Object.keys(require('./meshids.json')).join(' '))")}
mkdir -p out/logfin
work() { for id in "$@"; do
  { REUSE=1 PREVIEW=1 node texbake.js $id && node upload-tex.js $id && FORCE=1 node upload.js $id && node gen-tex.js $id; } > out/logfin/$id.txt 2>&1
  echo "$id $(grep -h 'asset\|FAIL\|rror\|surface appearances' out/logfin/$id.txt | grep -v '^\[' | tr '\n' ' ')"
done; }
arr=($IDS); n=${#arr[@]}
for ((w=0; w<W; w++)); do sel=(); for ((i=w; i<n; i+=W)); do sel+=(${arr[i]}); done; work "${sel[@]}" & done
wait; echo ALLDONE
