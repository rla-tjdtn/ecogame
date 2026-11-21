// 미리듣기 페이지 생성: node tools/sound-preview/build.js  (Roblox 기본 사운드를 base64로 내장한 index.html 을 만든다)
// Config.luau 의 Sounds / Screams 값을 그대로 옮긴 것 — 거리감·벽 가림은 빠져 있다.
const fs = require("fs"), path = require("path");
const dir = path.join(process.env.LOCALAPPDATA, "Roblox", "Versions");
const ver = fs.readdirSync(dir).map((v) => path.join(dir, v, "content", "sounds")).find((p) => fs.existsSync(path.join(p, "ouch.ogg")));
const b64 = (f) => fs.readFileSync(path.join(ver, f)).toString("base64");
const files = {
	land: "data:audio/mpeg;base64," + b64("action_jump_land.mp3"),
	plastic: "data:audio/mpeg;base64," + b64("action_footsteps_plastic.mp3"),
	ouch: "data:audio/ogg;base64," + b64("ouch.ogg"),
	oof: "data:audio/ogg;base64," + b64("oof.ogg"),
};
const html = `<!doctype html><meta charset="utf-8"><title>음파 미로 소리 미리듣기</title>
<style>body{background:#111;color:#eee;font-family:Malgun Gothic,sans-serif;max-width:640px;margin:30px auto;padding:0 16px}
button{display:block;width:100%;margin:8px 0;padding:14px;font-size:17px;background:#222;color:#eee;border:1px solid #666;border-radius:8px;cursor:pointer}
button:hover{background:#333}h3{margin:22px 0 4px;color:#9cf}small{color:#999}</style>
<h2>음파 미로 소리 미리듣기</h2>
<div>볼륨 <input id="vol" type="range" min="0" max="1" step="0.05" value="0.4"> <small>(괴성은 커요. 낮게 시작하세요)</small></div>
<small>Config.luau 의 값(걸음 선택·피치·길이·볼륨·왜곡·울림)을 그대로 옮긴 것입니다. 게임 안의 거리감·벽 가림은 빠져 있어서 실제와 조금 다를 수 있습니다.</small>
<h3>사람 발소리 (실제 발걸음 녹음 + 낮은 툭)</h3><div id="foot"></div>
<h3>괴물 발소리 (깊은 쿵 + 발톱 타닥) — 사람과 비교해 보세요</h3><div id="mstep"></div>
<h3>괴성</h3><div id="scream"></div>
<script>
const FILES=${JSON.stringify(files)};
const STEPS=[[0.03,0.2],[0.62,0.22],[1.22,0.13],[1.82,0.13]];
const SND={
 FootWalk:{f:"plastic",v:0.5,p:1.0,steps:STEPS,thump:0.22},FootRun:{f:"plastic",v:0.85,p:1.12,steps:STEPS,thump:0.4},
 FootCrouch:{f:"plastic",v:0.18,p:0.9,steps:[[1.22,0.13],[1.82,0.13]],thump:0.05},
 FootThump:{f:"land",v:1.0,p:1.25,cut:0.1},
 MonsterStep:{f:"land",v:0.5,p:0.7,cut:0.24,claw:"MonsterClaw",fx:{r:1.2}},
 MonsterClaw:{f:"plastic",v:0.35,p:0.55,steps:[[0.03,0.34],[0.62,0.34]]},
 MonsterIdle:{f:"ouch",v:0.22,p:0.6,fx:{d:0.5,r:2.5}},MonsterAlert:{f:"ouch",v:0.45,p:0.55,fx:{d:0.6,r:2.5}},
 MonsterChase:{f:"ouch",v:0.5,p:0.45,fx:{d:0.7,r:3}},MonsterScream2:{f:"oof",v:0.4,p:0.5,fx:{d:0.7,r:3}}};
const SCREAMS={
 Idle:[["MonsterIdle",0,1,1],["MonsterScream2",0.3,0.85,0.6],["MonsterIdle",0.75,0.8,0.6]],
 Alert:[["MonsterAlert",0,1,1],["MonsterScream2",0.25,0.9,0.8],["MonsterAlert",0.6,0.85,0.9],["MonsterScream2",1.0,0.8,0.6]],
 Chase:[["MonsterChase",0,1,1],["MonsterScream2",0.25,0.85,0.9],["MonsterChase",0.6,0.85,1],["MonsterScream2",1.0,0.7,0.8],["MonsterChase",1.4,0.65,0.7],["MonsterScream2",1.9,0.55,0.5]]};
const ctx=new (window.AudioContext||window.webkitAudioContext)();const buf={};
const ready=Promise.all(Object.entries(FILES).map(async([k,u])=>{buf[k]=await ctx.decodeAudioData(await (await fetch(u)).arrayBuffer());}));
function impulse(sec){const n=ctx.sampleRate*sec,b=ctx.createBuffer(2,n,ctx.sampleRate);for(let c=0;c<2;c++){const d=b.getChannelData(c);for(let i=0;i<n;i++)d[i]=(Math.random()*2-1)*Math.pow(1-i/n,2.5)}return b}
function dist(a){const k=a*120,c=new Float32Array(1024);for(let i=0;i<1024;i++){const x=i/512-1;c[i]=(1+k)*x/(1+k*Math.abs(x))}return c}
// play(이름, 지연초, 피치흔들림, 볼륨배율, 피치배율, 시작초, 길이초)
function play(name,delay=0,jit=0,vs=1,ps=1,start=0,cutOv){const d=SND[name],s=ctx.createBufferSource();s.buffer=buf[d.f];s.playbackRate.value=d.p*ps*(1+(Math.random()*2-1)*jit);
 const g=ctx.createGain();g.gain.value=d.v*vs*document.getElementById("vol").value;let node=s;
 if(d.fx&&d.fx.d){const w=ctx.createWaveShaper();w.curve=dist(d.fx.d);s.connect(w);node=w}
 const out=ctx.createGain();node.connect(g);g.connect(out);
 if(d.fx&&d.fx.r){const cv=ctx.createConvolver();cv.buffer=impulse(d.fx.r);const wet=ctx.createGain();wet.gain.value=0.35;g.connect(cv);cv.connect(wet);wet.connect(out)}
 out.connect(ctx.destination);const t=ctx.currentTime+delay;s.start(t,start);
 const cut=cutOv||d.cut;if(cut){g.gain.setValueAtTime(g.gain.value,t+cut);g.gain.linearRampToValueAtTime(0,t+cut+0.06);s.stop(t+cut+0.07)}}
const last={};
function footstep(name,delay=0,jit=0,ps=1){const d=SND[name];
 if(d.steps){let k=Math.floor(Math.random()*d.steps.length);if(k===last[name])k=(k+1)%d.steps.length;last[name]=k;play(name,delay,jit,1,ps,d.steps[k][0],d.steps[k][1])}else play(name,delay,jit,1,ps);
 if(d.thump)play("FootThump",delay,0.06,d.thump,ps);
 if(d.claw)footstep(d.claw,delay+0.07,0.06)}
function btn(id,label,fn){const b=document.createElement("button");b.textContent=label;b.onclick=async()=>{await ctx.resume();await ready;fn()};document.getElementById(id).appendChild(b)}
const walk=(n,name,gap,jit)=>()=>{for(let i=0;i<n;i++)footstep(name,i*gap*(1+(Math.random()-0.5)*(name==="MonsterStep"?0.35:0.08)),jit,1+(i%2?0.04:-0.04))};
btn("foot","걷기 (왼·오른발 번갈아 6걸음)",walk(6,"FootWalk",0.5,0.04));btn("foot","달리기",walk(8,"FootRun",0.36,0.04));btn("foot","웅크리기",walk(4,"FootCrouch",0.6,0.04));
btn("mstep","괴물 걸음 (쿵… 쿵… 느리고 불규칙)",walk(5,"MonsterStep",0.75,0.08));
btn("mstep","비교: 사람 걷기 → 괴물 걸음",()=>{for(let i=0;i<4;i++)footstep("FootWalk",i*0.5,0.04,1+(i%2?0.04:-0.04));for(let i=0;i<4;i++)footstep("MonsterStep",2.4+i*0.75,0.08)});
const scream=(k)=>()=>{for(const [s,t,p,v] of SCREAMS[k])play(s,t,0.05,v,p)};
btn("scream","배회 중 먼 괴성 (약 2초)",scream("Idle"));btn("scream","경계(Alert) 괴성 (약 2.5초)",scream("Alert"));btn("scream","추격(Chase) 괴성 (3초 이상)",scream("Chase"));
</script>`;
fs.writeFileSync(path.join(__dirname, "index.html"), html);
console.log("ok", html.length);
