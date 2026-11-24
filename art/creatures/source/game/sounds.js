// 괴물 소리: sounds_plan.json(괴물마다 괴성·걸음·특수 검색어)으로 Freesound 에서 CC0(자유 사용) 소리만 골라 미리듣기 파일을 받고,
// 다듬어(시작 소리만 / 짧게 / 길게, 크기 맞춤) 챕터마다 한 파일로 이어 붙인다(로블록스 오디오 업로드 수를 줄이려고).
//   node sounds.js            → out/sounds/raw/<freesound id>.mp3, out/sounds/clip/<id>_<kind>.wav, out/sounds/pack_ch<N>.ogg, sounds_map.json
// 한 소리는 게임 전체에서 한 번만 쓴다(같은 Freesound 번호 금지).
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const PLAN = JSON.parse(fs.readFileSync(path.join(__dirname, 'sounds_plan.json'), 'utf8'));
const OUT = path.join(__dirname, 'out', 'sounds'), RAW = path.join(OUT, 'raw'), CLIP = path.join(OUT, 'clip');
for (const d of [OUT, RAW, CLIP]) fs.mkdirSync(d, { recursive: true });
const MAPF = path.join(__dirname, 'sounds_map.json');
const MAP = fs.existsSync(MAPF) ? JSON.parse(fs.readFileSync(MAPF, 'utf8')) : { picks: {}, packs: {} };
const sleep = ms => new Promise(r => setTimeout(r, ms));
const UA = { 'User-Agent': 'Mozilla/5.0 (sound picker)' };
const KINDS = ['scream', 'steps', 'special'];
const CUT = { onset: .8, short: 1.5, long: 3 };

async function search(q) {
  const url = 'https://freesound.org/search/?q=' + encodeURIComponent(q) + '&f=license:%22Creative+Commons+0%22&s=Downloads+(most+first)';
  const html = await (await fetch(url, { headers: UA, signal: AbortSignal.timeout(20000) })).text();
  const out = []; const re = /href="\/people\/([^/"]+)\/sounds\/(\d+)\/"[\s\S]*?data-mp3="([^"]+)"/g; let m;
  const mp3s = [...html.matchAll(/data-mp3="([^"]+)"/g)].map(x => x[1]);
  for (const u of mp3s) { const id = (u.match(/\/(\d+)_\d+-lq\.mp3$/) || [])[1]; if (id && !out.find(o => o.id === id)) out.push({ id, mp3: u.replace('-lq.mp3', '-hq.mp3') }); }
  void re; void m;
  return out;
}
function ff(args) { execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'pipe' }); }
function dur(f) { return parseFloat(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString()); }

(async () => {
  const used = new Set(Object.values(MAP.picks).flatMap(p => Object.values(p).map(x => x.fs)));
  for (const [id, P] of Object.entries(PLAN)) {
    MAP.picks[id] = MAP.picks[id] || {};
    for (const kind of KINDS) {
      if (MAP.picks[id][kind]) continue;
      const spec = P[kind]; let got = null;
      const FALL = { scream: ['monster growl', 'creature scream horror', 'zombie groan'], steps: ['footstep', 'creature footsteps', 'thud impact'], special: ['horror sound effect', 'creepy creak', 'bone crack'] };
      for (const q of [...spec.q, ...FALL[kind]]) {
        let res = []; try { res = await search(q); } catch (e) { console.log('search fail', q, e.message); }
        await sleep(800);
        for (const r of res.slice(0, 8)) {
          if (used.has(r.id)) continue;
          const raw = path.join(RAW, r.id + '.mp3');
          try {
            if (!fs.existsSync(raw)) { const b = Buffer.from(await (await fetch(r.mp3, { headers: UA, signal: AbortSignal.timeout(30000) })).arrayBuffer()); fs.writeFileSync(raw, b); await sleep(400); }
            const d = dur(raw); if (!(d > .15) || d > 120) continue;
            const clip = path.join(CLIP, `${id}_${kind}.wav`), len = CUT[spec.cut] || 1.5;
            // 앞의 조용한 부분을 잘라내고 길이만큼, 끝은 부드럽게, 크기 맞춤, 모노 44.1k
            ff(['-i', raw, '-af', `silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:${len},afade=t=out:st=${Math.max(0, len - 0.15).toFixed(2)}:d=0.15,loudnorm=I=-16:TP=-1.5:LRA=11`, '-ac', '1', '-ar', '44100', clip]);
            const cd = dur(clip); if (!(cd > .1)) continue;
            got = { fs: r.id, q, url: 'https://freesound.org/s/' + r.id + '/', dur: Math.round(cd * 1000) / 1000 };
            break;
          } catch (e) { console.log('dl fail', r.id, e.message.slice(0, 80)); }
        }
        if (got) break;
      }
      if (got) { used.add(got.fs); MAP.picks[id][kind] = got; console.log(id, kind, got.fs, got.q, got.dur + 's'); fs.writeFileSync(MAPF, JSON.stringify(MAP, null, 1)); }
      else console.log('NONE', id, kind);
    }
  }
  // 챕터마다 이어 붙이기: 소리 사이 0.3초 쉼, 시작 위치 기록
  const byCh = {};
  const ch = id => Number(id.match(/^k(\d+)/)[1]);
  for (const id of Object.keys(MAP.picks)) (byCh[ch(id)] = byCh[ch(id)] || []).push(id);
  for (const [c, ids] of Object.entries(byCh)) {
    const parts = [], index = {}; let t = 0;
    const gap = path.join(CLIP, '_gap.wav'); if (!fs.existsSync(gap)) ff(['-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono', '-t', '0.3', gap]);
    for (const id of ids) for (const kind of KINDS) { const p = MAP.picks[id][kind]; if (!p) continue; const f = path.join(CLIP, `${id}_${kind}.wav`); index[id] = index[id] || {}; index[id][kind] = { start: Math.round(t * 1000) / 1000, dur: p.dur }; parts.push(f, gap); t += p.dur + .3; }
    const list = path.join(OUT, `pack_ch${c}.txt`); fs.writeFileSync(list, parts.map(f => `file '${f.split(path.sep).join('/')}'`).join('\n'));
    const ogg = path.join(OUT, `pack_ch${c}.ogg`);
    ff(['-f', 'concat', '-safe', '0', '-i', list, '-c:a', 'libvorbis', '-q:a', '5', ogg]);
    MAP.packs[c] = Object.assign(MAP.packs[c] || {}, { file: path.basename(ogg), length: Math.round(dur(ogg) * 100) / 100, index });
    console.log('pack ch' + c, MAP.packs[c].length + 's', ids.length, 'creatures');
  }
  fs.writeFileSync(MAPF, JSON.stringify(MAP, null, 1));
})();
