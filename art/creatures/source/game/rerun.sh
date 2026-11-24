#!/bin/bash
# 뼈가 너무 많은(>240) 괴물 + 아직 안 만든 괴물을 3묶음으로 다시 만든다 → 선 입히기·미리보기·원본 비교 그림까지
cd "$(dirname "$0")"
LIST=$(node -e "
const fs=require('fs');const {CFG}=require('./bake.js');
console.log(Object.keys(CFG).filter(id=>!['k7h1','k7h3','k7h4'].includes(id)).filter(id=>{const f='out/mesh/'+id+'_qa.json';if(!fs.existsSync(f))return true;return JSON.parse(fs.readFileSync(f,'utf8')).bones>240}).join(' '))")
set -- $LIST; n=$#; t=$(( (n+2)/3 )); echo "rerun $n: $LIST"
run() { for id in "$@"; do node rig.js $id 2>&1 | grep -v "ERROR:\|^\[\|^$" | grep "QA\|bones\|rror"; node linebake.js $id 2>&1 | grep lines; node animview.js $id; node designref.js $id 2>/dev/null; done; }
run "${@:1:$t}" > out/rr1.log 2>&1 & run "${@:$((t+1)):$t}" > out/rr2.log 2>&1 & run "${@:$((2*t+1))}" > out/rr3.log 2>&1 & wait
node fixlua.js > /dev/null; echo done
