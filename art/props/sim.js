// 오프라인 소품 시뮬레이터: 지금 작업 트리의 소품 빌더를 luau.exe 로 실제 스테이지 격자에 돌려
// 만들어진 파트를 out/sim/stage<n>.jsonl 로 남긴다(Studio 없이 소품별 크기·선 수·배치 수를 잰다).
//   node art/props/sim.js [1 2 ... 10]
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..', '..');
const SRC = process.env.SIM_SRC || path.join(ROOT, 'src');
const LUAU = 'C:/Users/User/Tools/luau/luau.exe';
const OUT = path.join(__dirname, 'out', 'sim'); fs.mkdirSync(OUT, { recursive: true });

function mods() {
  const list = [];
  const add = (rel) => list.push(rel);
  add('server/MapKit'); add('server/Props'); add('server/HomeProps');
  for (const f of fs.readdirSync(path.join(SRC, 'server/ChapterProps'))) if (f.endsWith('.luau')) add('server/ChapterProps/' + f.slice(0, -5));
  for (const f of fs.readdirSync(path.join(SRC, 'server/Stages'))) if (/^Stage\d+\.luau$/.test(f)) add('server/Stages/' + f.slice(0, -5));
  if (fs.existsSync(path.join(SRC, 'server/PropMesh.luau'))) add('server/PropMesh');
  return list;
}
function wrap(rel) {
  let s = fs.readFileSync(path.join(SRC, rel + '.luau'), 'utf8');
  s = s.replace(/^--!\w+/gm, '').replace(/^export type /gm, 'type ');
  return `__mods[${JSON.stringify(rel)}] = function(script)\n${s}\nend\n`;
}
const CONFIG = `
__mods["shared/PropMeshData"] = function() return { assets = {}, get = function() return nil end, groupOf = function() return nil end } end
__mods["shared/Config"] = function() return { Tags = { Renderable = "SonarRenderable", Dynamic = "SonarDynamic", Door = "SonarDoor", AmbientEmitter = "AmbientEmitter", HideSpot = "HideSpot", SearchSpot = "SearchSpot", Monster = "Monster" }, Sonar = { SegmentLength = 2 } } end\n`;

function run(stages, extra) {
  const bundle = fs.readFileSync(path.join(__dirname, 'sim', 'rbx.luau'), 'utf8') + '\n__mods = {}\n' + CONFIG + mods().map(wrap).join('\n') + '\n' +
    (extra || fs.readFileSync(path.join(__dirname, 'sim', 'driver.luau'), 'utf8').replaceAll('__STAGES__', '{' + stages.join(',') + '}'));
  const f = path.join(process.env.SIM_TMP || 'C:/Users/User/AppData/Local/Temp', `propsim-${process.pid}-${Date.now()}.luau`); fs.writeFileSync(f, bundle);
  try { return execFileSync(LUAU, [f], { maxBuffer: 1 << 30, encoding: 'utf8' }); } finally { try { fs.unlinkSync(f); } catch (e) { } }
}
module.exports = { run };
// 결과 파일은 임시 이름으로 쓴 뒤 바꾼다(여러 세션·에이전트가 동시에 돌려도 반쯤 쓴 파일을 읽지 않게)
function writeAtomic(file, text) { const t = file + '.' + process.pid + '.tmp'; fs.writeFileSync(t, text); fs.renameSync(t, file); }
// 서브 괴물 자리 소품(HomeProps): 이름마다 한 번씩 → out/sim/extra.jsonl
function runHome() {
  const src = fs.readFileSync(path.join(SRC, 'server/HomeProps.luau'), 'utf8');
  const names = [...src.matchAll(/^P\.(\w+) = function/gm)].map(m => m[1]);
  const base = fs.readFileSync(path.join(__dirname, 'sim', 'driver.luau'), 'utf8');
  const driver = base.slice(0, base.lastIndexOf('for _, n in __STAGES__ do')) + `
local HP = require(pathProxy({ "server", "HomeProps" }))
for k, name in { ${names.map(n => JSON.stringify(n)).join(', ')} } do
	local folder = Instance.new("Folder")
	HP.place({ nodes = { Vector3.new(4, 3, 4) } }, { x = { prop = name, rect = { 1, 1, 1, 1 } } }, { "x" }, folder)
	for _, c in folder.__children do
		print(string.format('@@{"stage":0,"floor":1,"i":%d,"j":0,"ch":"","fn":%s,"ok":true,"err":"","base":[4,0,4],"fy":0,"models":[{"name":%s,"dress":%s,"parts":[%s]}]}', k, js("Home." .. name), js(c.Name), dressJson(c), table.concat(modelJson(c), ",")))
	end
end
`;
  const out = run([], driver);
  const lines = out.split('\n').filter(l => l.startsWith('@@')).map(l => l.slice(2));
  writeAtomic(path.join(OUT, 'extra.jsonl'), lines.join('\n'));
  console.log('home props:', lines.length);
}
module.exports.runHome = runHome;
if (require.main === module) {
  if (process.argv.includes('--home')) { runHome(); process.exit(0); }
  const stages = process.argv.slice(2).map(Number); if (!stages.length) for (let i = 1; i <= 10; i++) stages.push(i);
  for (const n of stages) {
    const out = run([n]);
    const lines = out.split('\n').filter(l => l.startsWith('@@')).map(l => l.slice(2));
    writeAtomic(path.join(OUT, `stage${n}.jsonl`), lines.join('\n'));
    const bad = lines.map(l => JSON.parse(l)).filter(r => !r.ok);
    console.log(`stage ${n}: ${lines.length} prop calls, ${bad.length} errors` + (bad.length ? ' e.g. ' + bad[0].fn + ' ' + bad[0].err : ''));
  }
}
