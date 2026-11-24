// 시안 괴물 → 게임 파일: src/server/Creatures/<id>.luau(속도·기믹) + Config.luau 의 MonsterVoices 블록(괴물마다 괴성·걸음·특수 소리)
// node gen-game.js
// 소리: 한 챕터 안에서는 괴물끼리 소리 에셋이 하나도 겹치지 않게(괴성·걸음·특수 전부). 걸음은 생김새에 맞는 종류,
// 음 높이는 몸 크기(큰 몸 낮게, 작은 몸 높게) + 괴물마다 조금씩 달리 해서 다른 챕터의 같은 에셋도 다르게 들린다.
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..', '..', '..', '..');
const { CFG } = require('./bake.js');

// 걸음 소리 종류(이미 계정에 올린 CC0 에셋 + 로블록스 기본 소리)
const STEP = { heavy: 137748804042134, drag: 76678088411883, insect: 119059498928351, wood: 79801539256457, thud: 9114166413, creak: 128595779168447, tap: 134919568490352, bone: 76493509944508, wet: 125203001018778, hiss: 132007379899903, clatter: 114002785847325, flesh: 103473951609932 };
// 괴성 후보(도플갱어·공용 추격 괴성에 쓰는 것은 뺐다)
const SCREAM = [9114628818, 9114572653, 9113093880, 120058293974831, 9113980319, 105287149316706, 9113090147, 9113985971, 9116966503, 74933650585675, 9114037660, 116389741993620, 78248585425234, 123342966944903, 9113090127];
const SPECIAL_EXTRA = [83953676554672, 9125548429];

// id: [챕터, 메인?, 걸음 종류, 몸 크기(음 높이), 기믹, 속도(배회/조사/추격), hip]
const C = {
  k1h1: [1, 1, 'heavy', .85, null, [6, 10, 12], 2], k1h2: [1, 1, 'bone', 1, null, [5, 9, 11], 2], k1s1: [1, 0, 'insect', 1.05, 'near', [7, 11, 13], 1], k1s2: [1, 0, 'wood', .8, 'freeze', [3, 6, 9], 1],
  k2h1: [2, 1, 'thud', 1, null, [6, 10, 12], 1], k2h2: [2, 1, 'creak', .95, null, [5, 9, 11], 2], k2s1: [2, 0, 'tap', 1.2, 'blind', [6, 10, 13], 1], k2s2: [2, 0, 'bone', 1.1, 'scare', [5, 9, 12], 2],
  k3h1: [3, 1, 'wet', .8, null, [4, 8, 10], 2], k3h2: [3, 1, 'hiss', 1, null, [6, 10, 12], 2], k3s1: [3, 0, 'flesh', 1.15, 'blind', [7, 11, 14], 1], k3s2: [3, 0, 'drag', 1, 'near', [5, 9, 11], 2],
  k4h1: [4, 1, 'tap', 1, null, [6, 10, 12], 2], k4h2: [4, 1, 'heavy', .8, null, [5, 9, 11], 2], k4h3: [4, 1, 'wet', .75, null, [4, 9, 11], 2], k4s1: [4, 0, 'creak', .9, 'blind', [6, 11, 14], 1], k4s2: [4, 0, 'insect', 1.1, 'freeze', [6, 10, 12], 1], k4s3: [4, 0, 'bone', 1.15, 'scare', [6, 10, 13], 1], k4s4: [4, 0, 'drag', .9, 'near', [5, 9, 11], 2],
  k5h1: [5, 1, 'heavy', .9, null, [6, 10, 12], 2], k5h2: [5, 1, 'bone', 1, null, [6, 10, 12], 2], k5s1: [5, 0, 'insect', 1.05, 'scare', [6, 10, 13], 1], k5s2: [5, 0, 'clatter', .85, 'freeze', [5, 9, 11], 2], k5s3: [5, 0, 'tap', 1.1, 'blind', [6, 11, 14], 1],
  k6h1: [6, 1, 'insect', 1, null, [6, 10, 12], 2], k6h2: [6, 1, 'thud', 1, null, [6, 10, 12], 2], k6h3: [6, 1, 'tap', 1.05, null, [6, 10, 12], 2], k6s1: [6, 0, 'clatter', .95, 'freeze', [5, 10, 12], 1], k6s2: [6, 0, 'flesh', 1, 'near', [5, 9, 11], 2], k6s3: [6, 0, 'heavy', .75, 'blind', [3, 7, 11], 1], k6s4: [6, 0, 'wet', 1.05, 'scare', [6, 10, 12], 1],
  k7h1: [7, 1, 'drag', 1.1, null, [5, 9, 11], 2], k7h2: [7, 1, 'wood', 1, null, [6, 10, 12], 2], k7h3: [7, 1, 'tap', 1, null, [6, 10, 13], 2], k7h4: [7, 1, 'thud', 1, null, [6, 10, 12], 2], k7s1: [7, 0, 'bone', 1, 'freeze', [5, 9, 12], 2], k7s2: [7, 0, 'heavy', .95, 'near', [5, 9, 11], 2], k7s3: [7, 0, 'creak', .8, 'blind', [4, 9, 12], 1],
  k8h1: [8, 1, 'thud', 1.1, null, [6, 10, 12], 2], k8h2: [8, 1, 'drag', 1, null, [5, 9, 11], 2], k8h3: [8, 1, 'clatter', .8, null, [5, 9, 11], 2], k8s1: [8, 0, 'flesh', 1.05, 'scare', [6, 10, 13], 2], k8s2: [8, 0, 'wood', .9, 'freeze', [5, 10, 12], 2], k8s3: [8, 0, 'hiss', 1.15, 'near', [5, 9, 11], 2], k8s4: [8, 0, 'insect', 1.1, 'blind', [6, 11, 13], 1],
  k9h1: [9, 1, 'thud', .85, null, [6, 10, 13], 2], k9h2: [9, 1, 'drag', 1, null, [5, 9, 11], 2], k9h3: [9, 1, 'flesh', .8, null, [5, 9, 11], 2], k9s1: [9, 0, 'hiss', 1.05, 'near', [6, 10, 12], 1], k9s2: [9, 0, 'creak', 1.1, 'freeze', [5, 10, 12], 2], k9s3: [9, 0, 'insect', 1, 'scare', [6, 10, 13], 1], k9s4: [9, 0, 'clatter', .9, 'blind', [6, 11, 14], 2],
  // 10장: 메인 뜬눈 3마리(같은 그림 k10h1, 소리는 마리마다 다르게)
  k10h1a: [10, 1, 'heavy', .9, null, [6, 10, 12], 2, 'k10h1'], k10h1b: [10, 1, 'drag', 1, null, [6, 10, 12], 2, 'k10h1'], k10h1c: [10, 1, 'bone', 1.1, null, [6, 10, 12], 2, 'k10h1'],
  k10s1: [10, 0, 'hiss', 1.05, 'scare', [6, 10, 13], 2], k10s2: [10, 0, 'creak', .85, 'freeze', [5, 9, 12], 1], k10s3: [10, 0, 'clatter', 1, 'near', [6, 10, 12], 2],
};

// 괴물 모듈
const DIR = path.join(ROOT, 'src', 'server', 'Creatures');
for (const [id, [ch, main, , , gim, sp, hip, spr]] of Object.entries(C)) {
  const name = CFG[spr || id] ? CFG[spr || id].name : id;
  const lua = `--!strict\n-- ${ch}장 ${main ? '메인' : '서브'} 괴물: ${name} (자동 생성: art/creatures/source/game/gen-game.js)\n` +
    `local Baked = require(script.Parent.Baked)\nreturn Baked.creature({\n\tid = "${id}",\n` + (spr ? `\tsprite = "${spr}",\n` : '') + `\thip = ${hip},\n\tvoice = "${id}",\n` + (gim ? `\tgimmick = "${gim}",\n` : '') +
    `\tcfg = { WanderSpeed = ${sp[0]}, InvestigateSpeed = ${sp[1]}, ChaseSpeed = ${sp[2]}, AgentRadius = 1.6, AgentHeight = 6 },\n})\n`;
  fs.writeFileSync(path.join(DIR, id + '.luau'), lua);
}

// 소리: 챕터마다 겹치지 않게 배정
const voices = []; const byCh = {};
for (const [id, v] of Object.entries(C)) (byCh[v[0]] = byCh[v[0]] || []).push(id);
let n = 0;
for (const ch of Object.keys(byCh).sort((a, b) => a - b)) {
  const used = new Set(); const ids = byCh[ch];
  for (const id of ids) { const st = STEP[C[id][2]]; if (used.has(st)) throw new Error('걸음 겹침 ' + ch + ' ' + id); used.add(st); }
  const screams = SCREAM.filter(s => !used.has(s));
  const rot = (Number(ch) * 3) % screams.length; const order = screams.slice(rot).concat(screams.slice(0, rot));
  const sc = {}; ids.forEach((id, i) => { sc[id] = order[i]; used.add(order[i]); });
  const spPool = order.slice(ids.length).concat(SPECIAL_EXTRA, Object.values(STEP).filter(s => !used.has(s)));
  ids.forEach((id, i) => {
    const sp = spPool[i]; if (used.has(sp)) throw new Error('특수 겹침'); used.add(sp);
    const pitch = Math.round(C[id][3] * (1 + ((n++ % 5) - 2) * .035) * 100) / 100;
    // 새로 받은 CC0 소리(챕터 묶음 오디오의 구간)가 있으면 그것을 쓴다: { 에셋, 시작, 길이 }
    const SM = (() => { try { return JSON.parse(fs.readFileSync(path.join(__dirname, 'sounds_map.json'), 'utf8')); } catch (e) { return null; } })();
    const pk = SM && SM.packs[ch], ix = pk && pk.assetId && pk.index && pk.index[id];
    if (ix && ix.scream && ix.steps && ix.special) {
      const r = k => `{ { ${pk.assetId}, ${ix[k].start}, ${ix[k].dur} } }`;
      voices.push(`\t${id} = { Name = "${CFG[C[id][7] || id] ? CFG[C[id][7] || id].name : id}", Scream = ${r('scream')}, Steps = ${r('steps')}, Special = ${r('special')} }, -- ${ch}장 ${C[id][1] ? '메인' : '서브'}${C[id][4] ? '(' + C[id][4] + ')' : ''} · Freesound CC0 ${['scream', 'steps', 'special'].map(k => SM.picks[id][k].fs).join('/')}`);
      return;
    }
    voices.push(`\t${id} = { Name = "${CFG[C[id][7] || id] ? CFG[C[id][7] || id].name : id}", Pitch = ${pitch}, Scream = { ${sc[id]} }, Steps = { ${STEP[C[id][2]]} }, Special = { ${sp} } }, -- ${ch}장 ${C[id][1] ? '메인' : '서브'}${C[id][4] ? '(' + C[id][4] + ')' : ''} · 걸음 ${C[id][2]}`);
  });
}
const cfgPath = path.join(ROOT, 'src', 'shared', 'Config.luau'); let cfg = fs.readFileSync(cfgPath, 'utf8');
const A = '\t-- BEGIN CREATURE VOICES (gen-game.js)\n', B = '\t-- END CREATURE VOICES\n';
const block = A + voices.join('\n') + '\n' + B;
if (cfg.includes(A)) cfg = cfg.slice(0, cfg.indexOf(A)) + block + cfg.slice(cfg.indexOf(B) + B.length);
else { const k = cfg.indexOf('\tFlower = { Name = "꽃괴물"'); const e = cfg.indexOf('\n', k) + 1; cfg = cfg.slice(0, e) + block + cfg.slice(e); }
fs.writeFileSync(cfgPath, cfg);
console.log('modules', Object.keys(C).length, 'voices', voices.length);

// 서브 괴물 자기 자리(homes.json, 칸 좌표) → src/shared/CreatureHomes.luau
{
  const H = JSON.parse(fs.readFileSync(path.join(__dirname, 'homes.json'), 'utf8'));
  const PROP = { k6s3: 'Bathtub', k7s2: 'Blackboard', k7s3: 'Organ', k8s3: 'CribMobile', k9s2: 'HangBar' };
  const rows = Object.entries(H).map(([id, h]) => {
    const band = h.floor === 2 ? '"upper"' : h.level ? '"lower"' : 'nil';
    return `\t${id} = { rect = { ${h.rect.join(', ')} }, band = ${band}, prop = ${PROP[id] ? '"' + PROP[id] + '"' : 'nil'} }, -- ${h.room} · ${(h.spot || '').replace(/\n/g, ' ')}`;
  });
  fs.writeFileSync(path.join(ROOT, 'src', 'shared', 'CreatureHomes.luau'), `--!strict\n-- 자동 생성(art/creatures/source/game/gen-game.js ← homes.json): 서브 괴물마다 역할에 맞는 자기 자리.\n-- rect = 맵 칸 좌표 { x0, y0, x1, y1 }(1부터, 끝 포함, 1칸 = 8스터드). band = "upper"(2층) / "lower"(아래층) / nil(층 구분 없음).\n-- prop = 맵에 없어서 그 자리에 더 놓는 소품(Server/HomeProps)\nreturn {\n${rows.join('\n')}\n}\n`);
  console.log('homes', rows.length);
}
