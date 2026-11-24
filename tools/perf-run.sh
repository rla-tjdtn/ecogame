#!/bin/sh
# 측정 묶음을 차례로 돌린다(열린 Studio 의 측정용 플레이스에서, 모두 음소거).
#   sh tools/perf-run.sh <outDir> <tag> <item...>
#   item: 숫자 n = stress STAGE=n,  soakN = soak STAGE=N(150초),  multi4 = 실제 클라이언트 4개 multi,  P4:netaudio = PLAYERS=4 로 그 모드,
#         그 밖의 이름 = 그 모드(census, pbench, core, sonarall ...)
# env TEST_PORT: 그 포트의 Studio 창에서(기본 34902). 다른 테스트가 그 포트를 쓰는 중이면 빌 때까지 기다린다(남의 프로세스는 건드리지 않는다).
cd "$(dirname "$0")/.."
out="$1"; tag="$2"; shift 2
mkdir -p "$out"
busy() { powershell -NoProfile -Command "if(Get-NetTCPConnection -LocalPort ${TEST_PORT:-34902} -State Listen -ErrorAction SilentlyContinue){'1'}" | grep -q 1; }
for x in "$@"; do
  while busy; do sleep 10; done
  f="$out/$tag-$(echo "$x" | tr ':' '-').txt"
  case $x in
    soak*) STAGE=${x#soak} WATCH_SECONDS=150 node tools/studio-test.js soak 480 > "$f" 2>&1;;
    multi*) PLAYERS=${x#multi} node tools/studio-test.js multi 600 > "$f" 2>&1;;
    P*:*) n=${x%%:*}; PLAYERS=${n#P} node tools/studio-test.js ${x#*:} 900 > "$f" 2>&1;;
    [0-9]*) STAGE=$x node tools/studio-test.js stress 480 > "$f" 2>&1;;
    *) node tools/studio-test.js $x 1200 > "$f" 2>&1;;
  esac
  echo "$(date +%H:%M:%S) $x exit $?"
  sleep 5
done
