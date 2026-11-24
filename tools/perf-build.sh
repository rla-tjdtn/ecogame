#!/bin/sh
# 성능 측정용 플레이스 만들기(최적화 전/후를 같은 맵에서 비교).
#   sh tools/perf-build.sh <out.rbxlx> [freezeDir|-] [overlayDir]
#   freezeDir 를 주면 맵·괴물 폴더(Stages, ChapterProps, Creatures, CreatureRigs, CreatureSprites)를 그 사본으로 바꿔 넣는다
#   (레벨 디자인·괴물 세션이 맵을 계속 바꿔도 측정 조건이 같게). 없거나 - 이면 지금 작업 트리 그대로.
#   overlayDir 를 주면 그 안의 src/... 파일을 마지막에 덮어쓴다(예: 최적화 전 파일로 되돌린 비교 빌드). 작업 트리는 건드리지 않는다.
# 결과 플레이스를 Studio 로 열고 node tools/studio-test.js <mode> 로 측정한다(측정 방법: docs/perf/baseline.md).
set -e
cd "$(dirname "$0")/.."
out="$1"; freeze="$2"; overlay="$3"; [ "$freeze" = "-" ] && freeze=""
[ -n "$out" ] || { echo "usage: tools/perf-build.sh <out.rbxlx> [freezeDir]"; exit 1; }
tmp="${out%.rbxlx}.proj"
bad=0
src="${SRC:-src}" # env SRC: 저장해 둔 src 사본으로 빌드(같은 코드로 다시 측정할 때)
for f in $(find "$src" -name "*.luau"); do
  /c/Users/User/Tools/luau/luau-compile.exe --text "$f" >/dev/null 2>"$tmp.err" || { echo "SYNTAX $f"; head -2 "$tmp.err"; bad=1; }
done
[ $bad = 0 ] || exit 1
rm -rf "$tmp"; mkdir -p "$tmp"; cp -r "$src" "$tmp/src"; cp default.project.json "$tmp/"
# env TEST_PORT: 이 플레이스를 연 Studio 가 그 포트로 테스트를 받는다(여러 Studio 창을 동시에 — tools/studio-test.js 에도 같은 TEST_PORT)
if [ -n "$TEST_PORT" ]; then
  node tools/perf-port.js "$tmp/default.project.json" "$TEST_PORT"
fi
if [ -n "$freeze" ]; then
  for d in server/Stages server/ChapterProps server/Creatures shared/CreatureRigs shared/CreatureSprites; do
    if [ -d "$freeze/src/$d" ]; then rm -rf "$tmp/src/$d"; cp -r "$freeze/src/$d" "$tmp/src/$d"; fi
  done
fi
if [ -n "$overlay" ]; then
  # 덮어쓰기 폴더에 regen/make-before.js 가 있으면 빌드하는 순간의 트리로 다시 만든다(다른 세션이 그 뒤에 고친 내용이 빠지지 않게)
  if [ -f "$overlay/regen/make-before.js" ]; then
    rm -rf "$tmp.ovl"; mkdir -p "$tmp.ovl"
    node "$overlay/regen/make-before.js" "$tmp.ovl" || { echo "overlay regen failed"; exit 1; }
    overlay="$tmp.ovl"
  fi
  cp -r "$overlay/src/." "$tmp/src/"
fi
(cd "$tmp" && "/c/Users/User/Desktop/로블 백룸/tools/rojo.exe" build default.project.json -o "$out")
rm -rf "$tmp" "$tmp.err" "$tmp.ovl"
echo "built $out"
