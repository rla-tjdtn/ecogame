// 미리듣기 페이지 생성: node tools/sound-preview/build.js  (Roblox 기본 사운드를 base64로 내장한 index.html 을 만든다)
// Config.luau 의 Sounds / ScreamStyles 값을 그대로 옮긴 것 — 거리감·벽 가림은 빠져 있고, 효과(떨림·에코·플랜저 등)는 브라우저 소리 엔진으로 흉내 낸 근사치다.
const fs = require("fs"), path = require("path");
const dir = path.join(process.env.LOCALAPPDATA, "Roblox", "Versions");
const ver = fs.readdirSync(dir).map((v) => path.join(dir, v, "content", "sounds")).find((p) => fs.existsSync(path.join(p, "ouch.ogg")));
const b64 = (f) => fs.readFileSync(path.join(ver, f)).toString("base64");
const { recipes } = require("./recipes.js");
// Config.luau 의 ScreamRecipes 블록을 recipes.js 에서 자동으로 채운다
{
	const cfgPath = path.join(__dirname, "..", "..", "src", "shared", "Config.luau");
	let cfg = fs.readFileSync(cfgPath, "utf8");
	const a = cfg.indexOf("local ScreamRecipes"), b = cfg.indexOf("-- END SCREAM RECIPES");
	if (a > 0 && b > a) {
		const lines = recipes.map((r) => `	{ fx = "${r.fx}", src = "${r.src}", pitch = ${r.pitch}, gate = { ${r.gate[0]}, ${r.gate[1]} }${r.air ? `, air = "${r.air}"` : ""} }, -- ${r.n} ${r.name}`);
		cfg = cfg.slice(0, a) + ["local ScreamRecipes: { { [string]: any } } = {", ...lines, "}", ""].join(String.fromCharCode(10)) + cfg.slice(b);
		fs.writeFileSync(cfgPath, cfg);
	}
}
const files = {
	land: "data:audio/mpeg;base64," + b64("action_jump_land.mp3"),
	plastic: "data:audio/mpeg;base64," + b64("action_footsteps_plastic.mp3"),
	wind: "data:audio/ogg;base64," + b64("action_falling.ogg"),
	jump: "data:audio/mpeg;base64," + b64("action_jump.mp3"),
	slider: "data:audio/ogg;base64," + b64("volume_slider.ogg"),
	ouch: "data:audio/ogg;base64," + b64("ouch.ogg"),
	oof: "data:audio/ogg;base64," + b64("oof.ogg"),
};
const html = `<!doctype html><meta charset="utf-8"><title>음파 미로 소리 미리듣기</title>
<style>body{background:#111;color:#eee;font-family:Malgun Gothic,sans-serif;max-width:680px;margin:30px auto;padding:0 16px}
button{padding:12px 14px;font-size:16px;background:#222;color:#eee;border:1px solid #666;border-radius:8px;cursor:pointer}
button:hover{background:#333}.row{display:flex;gap:8px;margin:8px 0;flex-wrap:wrap}.row button{flex:1;min-width:150px}
.card{border:1px solid #444;border-radius:10px;padding:10px 12px;margin:12px 0}.card b{color:#fc8}h3{margin:24px 0 4px;color:#9cf}small{color:#999}</style>
<h2>음파 미로 소리 미리듣기</h2>
<div>볼륨 <input id="vol" type="range" min="0" max="1" step="0.05" value="0.4"> <small>(괴성은 커요. 낮게 시작하세요)</small></div>
<small>Config.luau 의 값(피치·길이·볼륨·효과)을 옮긴 것입니다. 게임 안의 거리감·벽 가림은 빠져 있고, 효과는 근사치라 실제 Roblox 소리와 조금 다를 수 있습니다.</small>
<h3>사람 발소리 (한 걸음 한 소리, 매번 똑같이)</h3><div class="row" id="foot"></div>
<h3>괴물 발소리 (깊은 쿵 + 발톱 타닥) — 사람과 비교</h3><div class="row" id="mstep"></div>
<h3>괴성 카탈로그 60개 + 직접 만들기 (맨 아래)</h3><div>효과 <select id="fxf"></select> <small>(고른 효과만 보기)</small></div><div class="row" id="cat" style="max-height:340px;overflow:auto"></div><div class="card" id="builder"></div>
<h3>음파 발사음 후보 6개 (부드럽고 짧은 한 번, 울림 없음 · 번호 = Config.SonarStyle)</h3><div class="row" id="sonar"></div>
<h3>괴성 — 지금 게임 적용: 13번 귀신 곡소리 (괴성은 플레이어를 발견해 쫓을 때만 (발소리는 평소에도 남)) · 마음에 드는 번호를 알려주세요</h3><small>13~15 = 소름 끼치는 귀신 곡소리(끊기며 울림, 음 높이 일정) · 3-A~3-F = 사이렌 높낮이 변형 · 1~6 = 처음 시안</small><div id="styles"></div>
<script>
const FILES=${JSON.stringify(files)};
const OUCH="ouch",OOF="oof",WIND="wind",LAND="land";
const EQ=(lo,mid,hi)=>["Equalizer",{LowGain:lo,MidGain:mid,HighGain:hi}],TREM=(f,d)=>["Tremolo",{Frequency:f,Depth:d}],DIST=(l)=>["Distortion",{Level:l}],REV=(d,w)=>["Reverb",{DecayTime:d,WetLevel:w}];
const snd=(f,v,p,cut,fx)=>({f,v,p,cut,fx}),Ly=(s,t,p,v,sweep,dur,gate)=>({s,t,p,v,sweep,dur,gate});
const BASE={
 FootWalk:{f:"plastic",v:0.55,p:1,steps:[[1.22,0.13]]},FootRun:{f:"plastic",v:0.85,p:1,steps:[[1.22,0.13]]},FootCrouch:{f:"plastic",v:0.2,p:1,steps:[[1.22,0.13]]},
 MonsterStep:{f:"land",v:0.5,p:0.7,cut:0.24,claw:"MonsterClaw",fx:[REV(1.2,-3)]},
 MonsterClaw:{f:"plastic",v:0.35,p:0.55,steps:[[0.03,0.34],[0.62,0.34]]}};
const FX_SCREECH=[TREM(25,0.6),DIST(0.25),EQ(-20,0,4)],FX_PULSE=[TREM(7,0.85),EQ(6,-12,-40),REV(2.5,-4)],FX_SIREN=[TREM(14,0.9),DIST(0.3),REV(3,-2)],
 FX_ECHO=[["Echo",{Delay:0.28,Feedback:0.55,DryLevel:0,WetLevel:-3}],["Chorus",{Depth:0.5,Mix:0.5,Rate:2}]],FX_FLANGE=[["Flange",{Depth:1,Mix:0.8,Rate:1.2}],EQ(-40,-4,6)],FX_ROAR=[DIST(0.8),REV(3,-2)];
const STYLES=[
 {name:"초음파 비명 — 높은 음이 떨리며 날카롭게 치솟는 고주파",S:{MonsterIdle:snd(OUCH,0.2,1.3,0,FX_SCREECH),MonsterAlert:snd(OUCH,0.35,1.45,0,FX_SCREECH),MonsterChase:snd(OUCH,0.4,1.5,0,FX_SCREECH),MonsterScream2:snd(OOF,0.2,1.3,0,FX_SCREECH)},
  M:{Idle:[Ly("MonsterIdle",0,0.9,1),Ly("MonsterIdle",0.12,1.1,1),Ly("MonsterIdle",0.24,1.3,0.8)],Alert:[0,1,2,3,4].map(i=>Ly("MonsterAlert",i*0.1,0.75+i*0.15,i==4?0.9:1)),
   Chase:[...[0,1,2,3,4,5,6,7].map(i=>Ly("MonsterChase",i*0.1,0.6+i*0.12,i>5?0.9-(i-6)*0.1:1)),Ly("MonsterScream2",0.5,1,0.8),Ly("MonsterScream2",0.8,1.3,0.7)]}},
 {name:"저주파 맥동파 — 바닥을 울리는 우우웅이 맥박처럼 일렁이고 쿵, 쿵 충격파가 번짐",S:{MonsterIdle:snd(WIND,3,0.35,1.2,FX_PULSE),MonsterAlert:snd(WIND,4.5,0.33,1.8,FX_PULSE),MonsterChase:snd(WIND,6,0.3,2.6,FX_PULSE),MonsterScream2:snd(LAND,1.5,0.4,0.35,[REV(2,-2)])},
  M:{Idle:[Ly("MonsterIdle",0,1,1)],Alert:[Ly("MonsterAlert",0,1,1),Ly("MonsterScream2",0,1,1),Ly("MonsterScream2",0.5,1,0.8)],
   Chase:[Ly("MonsterChase",0,1,1),Ly("MonsterScream2",0,1,1),Ly("MonsterScream2",0.45,1,0.9),Ly("MonsterScream2",0.9,1,0.8),Ly("MonsterScream2",1.35,1,0.7),Ly("MonsterScream2",1.8,1,0.6)]}},
 {name:"떨리는 사이렌 비명 — 빠르게 떨려 경보 사이렌처럼 일렁이며 낮아짐",S:{MonsterIdle:snd(OUCH,0.2,0.7,0,FX_SIREN),MonsterAlert:snd(OUCH,0.35,0.6,0,FX_SIREN),MonsterChase:snd(OUCH,0.4,0.5,0,FX_SIREN),MonsterScream2:snd(OOF,0.2,0.55,0,FX_SIREN)},
  M:{Idle:[Ly("MonsterIdle",0,1,1),Ly("MonsterIdle",0.4,0.9,0.7)],Alert:[Ly("MonsterAlert",0,1,1),Ly("MonsterAlert",0.3,0.9,0.9),Ly("MonsterAlert",0.7,0.8,0.8)],
   Chase:[Ly("MonsterChase",0,1,1),Ly("MonsterScream2",0.15,1,0.9),Ly("MonsterChase",0.4,0.9,1),Ly("MonsterScream2",0.7,0.85,0.8),Ly("MonsterChase",1.0,0.8,0.8),Ly("MonsterChase",1.4,0.7,0.7)]}},
 {name:"에코 파동 — 비명이 메아리처럼 되풀이되며 퍼져 나감",S:{MonsterIdle:snd(OUCH,0.2,0.5,0,FX_ECHO),MonsterAlert:snd(OUCH,0.35,0.45,0,FX_ECHO),MonsterChase:snd(OUCH,0.4,0.4,0,FX_ECHO),MonsterScream2:snd(OOF,0.2,0.45,0,FX_ECHO)},
  M:{Idle:[Ly("MonsterIdle",0,1,1)],Alert:[Ly("MonsterAlert",0,1,1),Ly("MonsterAlert",0.5,0.9,0.8)],Chase:[Ly("MonsterChase",0,1,1),Ly("MonsterScream2",0.25,0.9,0.8),Ly("MonsterChase",0.7,0.85,0.9)]}},
 {name:"플랜저 음파 — 쉬이잉 하고 휘감기는 가는 음파가 훑고 지나감",S:{MonsterIdle:snd(WIND,2,1.5,0.9,FX_FLANGE),MonsterAlert:snd(WIND,4,1.6,1.5,FX_FLANGE),MonsterChase:snd(WIND,5,1.7,2.2,FX_FLANGE),MonsterScream2:snd(OUCH,0.3,1.4,0,FX_FLANGE)},
  M:{Idle:[Ly("MonsterIdle",0,1,1)],Alert:[Ly("MonsterAlert",0,1,1),Ly("MonsterScream2",0.3,1,0.8)],Chase:[Ly("MonsterChase",0,1,1),Ly("MonsterScream2",0.3,1,1),Ly("MonsterScream2",0.8,0.85,0.9),Ly("MonsterScream2",1.3,0.7,0.8)]}},
 {name:"혼합 충격 포효 — 거칠게 왜곡된 낮은 포효 + 바닥을 울리는 저주파 + 쿵 충격파",S:{MonsterIdle:snd(OUCH,0.2,0.45,0,FX_ROAR),MonsterAlert:snd(OUCH,0.35,0.42,0,FX_ROAR),MonsterChase:snd(OUCH,0.45,0.38,0,FX_ROAR),MonsterScream2:snd(WIND,5,0.3,2.2,FX_PULSE),MonsterWaveThud:snd(LAND,1.5,0.4,0.35,[REV(2,-2)])},
  M:{Idle:[Ly("MonsterIdle",0,1,1)],Alert:[Ly("MonsterAlert",0,1,1),Ly("MonsterWaveThud",0,1,1)],
   Chase:[Ly("MonsterChase",0,1,1),Ly("MonsterScream2",0,1,1),Ly("MonsterWaveThud",0,1,1),Ly("MonsterWaveThud",0.5,1,0.8),Ly("MonsterChase",0.6,0.9,0.9),Ly("MonsterWaveThud",1.0,1,0.7),Ly("MonsterChase",1.3,0.8,0.7)]}}];
const SIREN=(sweep,fx)=>{const f=fx||FX_SIREN;return{S:{MonsterIdle:snd(OUCH,0.2,0.5,0,f),MonsterAlert:snd(OUCH,0.35,0.5,0,f),MonsterChase:snd(OUCH,0.4,0.5,0,f),MonsterScream2:snd(OOF,0.2,0.4,0,f)},M:{Idle:[Ly("MonsterIdle",0,1,1,sweep,1.2)],Alert:[Ly("MonsterAlert",0,1,1,sweep,1.8),Ly("MonsterScream2",0.05,1,0.6,sweep,1.8)],Chase:[Ly("MonsterChase",0,1,1,sweep,2.7),Ly("MonsterScream2",0.05,1,0.6,sweep,2.7)]}}};
const FX_STUTTER=[["Tremolo",{Frequency:9,Depth:1,Duty:0.5}],DIST(0.3),REV(3,-2)];
const VARIANTS=[["3-A (Config 7번) 내려갔다 올라감",[[0,1.3],[0.5,0.7],[1,1.3]]],["3-B (8번) 올라감",[[0,0.7],[1,1.7]]],["3-C (9번) 올라갔다 내려감",[[0,0.7],[0.5,1.5],[1,0.6]]],["3-D (10번) 끊기며 떨리는 사이렌 (음 높이 일정)",[[0,1.2],[1,1.2]],FX_STUTTER],["3-E (11번) 투톤 삐뽀삐뽀",[[0,1],[0.1667,1],[0.1668,1.5],[0.3333,1.5],[0.3334,1],[0.5,1],[0.5001,1.5],[0.6667,1.5],[0.6668,1],[0.8333,1],[0.8334,1.5],[1,1.5]]],["3-F (12번) 오르락내리락 3번 (앰뷸런스)",[[0,0.8],[0.167,1.5],[0.333,0.8],[0.5,1.5],[0.667,0.8],[0.833,1.5],[1,0.8]]]];
VARIANTS.forEach(([name,sweep,fx])=>{const v=SIREN(sweep,fx);v.name=name;v.variant=true;STYLES.splice(3+VARIANTS.indexOf(VARIANTS.find(x=>x[0]===name)),0,v)});
const FLAT=[[0,1],[1,1]],FX_GHOST=[EQ(-30,-4,6),["Chorus",{Depth:0.6,Mix:0.6,Rate:1.5}],TREM(5,0.3),REV(4,-2)],FX_HOLLOW=[EQ(-20,-8,2),["Flange",{Depth:0.5,Mix:0.5,Rate:0.4}],["Echo",{Delay:0.35,Feedback:0.6,DryLevel:-3,WetLevel:-3}],REV(5,-2)],FX_BREATH=[EQ(-40,-2,8),["Flange",{Depth:1,Mix:0.8,Rate:1.2}],["Chorus",{Depth:0.6,Mix:0.6,Rate:1.5}],REV(4,-2)];
const GHOST=(name,voice,air,alert,gate)=>({name,variant:true,ghost:true,S:{MonsterIdle:voice,MonsterAlert:alert,MonsterChase:voice,MonsterScream2:air},M:{Chase:[Ly("MonsterChase",0,1,1,FLAT,2.4,gate),Ly("MonsterScream2",0,1,1,FLAT,2.4,gate)],Alert:[Ly("MonsterAlert",0,1,1)]}});
STYLES.push(GHOST("13 귀신 곡소리 — 높고 속삭이는 울음 (높은 목소리 + 바람 숨결, 약한 떨림, 긴 울림)",snd(OUCH,0.3,1.25,0,FX_GHOST),snd(WIND,6,1.6,0,[EQ(-40,-2,8),REV(4,-2)]),snd(OUCH,0.35,1.25,0,FX_GHOST),[0.22,0.14]),GHOST("14 귀신 곡소리 — 공허하게 울리는 울음 (낮은 중음 + 되울림 + 천천히 휘감김)",snd(OUCH,0.3,0.8,0,FX_HOLLOW),snd(OOF,0.1,0.7,0,FX_HOLLOW),snd(OUCH,0.35,0.8,0,FX_HOLLOW),[0.3,0.2]),GHOST("15 귀신 곡소리 — 바람이 우는 숨소리 (숨 같은 바람 + 아주 작은 속삭임)",snd(WIND,6,2.0,0,FX_BREATH),snd(OOF,0.1,1.4,0,FX_GHOST),snd(OUCH,0.3,1.3,0,FX_GHOST),[0.25,0.15]));
const SONARS=[["1 후웅 (낮은 바람 한 번)",snd(WIND,1.6,1,0.35,[EQ(-4,-12,-40)])],["2 퉁 (낮고 부드러운 저음)",snd(LAND,0.35,0.6,0.3,[EQ(4,-6,-30)])],["3 휙 (가벼운 공기 가르는 소리)",snd("jump",0.6,1.3,0.25)],["4 똑 (아주 짧은 톡)",snd("slider",0.12,0.7,0.09)],["5 쉭 (맑은 높은 바람)",snd(WIND,4,2,0.3,[EQ(-40,-6,4)])],["6 웅 (아주 낮은 울림 한 번)",snd(WIND,3,0.5,0.5,[EQ(6,-10,-40)])]];
const ctx=new (window.AudioContext||window.webkitAudioContext)();const buf={};
const ready=Promise.all(Object.entries(FILES).map(async([k,u])=>{buf[k]=await ctx.decodeAudioData(await (await fetch(u)).arrayBuffer());}));
const dB=(x)=>Math.pow(10,x/20);
function impulse(sec){const n=ctx.sampleRate*sec,b=ctx.createBuffer(2,n,ctx.sampleRate);for(let c=0;c<2;c++){const d=b.getChannelData(c);for(let i=0;i<n;i++)d[i]=(Math.random()*2-1)*Math.pow(1-i/n,2.5)}return b}
function dist(a){const k=a*120,c=new Float32Array(1024);for(let i=0;i<1024;i++){const x=i/512-1;c[i]=(1+k)*x/(1+k*Math.abs(x))}return c}
function lfo(freq,amount,target){const o=ctx.createOscillator(),g=ctx.createGain();o.frequency.value=freq;g.gain.value=amount;o.connect(g);g.connect(target);o.start();return o}
// 효과 체인: 입력 노드 → 출력 노드 (Roblox SoundEffect 의 근사)
function applyFx(list,input,stops){let node=input;
 for(const [cls,p] of list||[]){
  if(cls==="Distortion"){const w=ctx.createWaveShaper();w.curve=dist(p.Level);node.connect(w);node=w}
  else if(cls==="Tremolo"){const g=ctx.createGain();g.gain.value=1-p.Depth/2;const o=lfo(p.Frequency,p.Depth/2,g.gain);if(p.Duty!==undefined)o.type="square";node.connect(g);node=g;stops.push(0)}
  else if(cls==="Equalizer"){const lo=ctx.createBiquadFilter(),mi=ctx.createBiquadFilter(),hi=ctx.createBiquadFilter();lo.type="lowshelf";lo.frequency.value=250;lo.gain.value=p.LowGain;mi.type="peaking";mi.frequency.value=1500;mi.Q.value=0.7;mi.gain.value=p.MidGain;hi.type="highshelf";hi.frequency.value=4000;hi.gain.value=p.HighGain;node.connect(lo);lo.connect(mi);mi.connect(hi);node=hi}
  else if(cls==="Reverb"){const dry=ctx.createGain(),cv=ctx.createConvolver(),wet=ctx.createGain(),out=ctx.createGain();cv.buffer=impulse(p.DecayTime);wet.gain.value=dB(p.WetLevel)*0.5;node.connect(dry);node.connect(cv);cv.connect(wet);dry.connect(out);wet.connect(out);node=out;stops.push(p.DecayTime*0.5)}
  else if(cls==="Echo"){const dry=ctx.createGain(),dl=ctx.createDelay(2),fb=ctx.createGain(),wet=ctx.createGain(),out=ctx.createGain();dl.delayTime.value=p.Delay;fb.gain.value=p.Feedback;wet.gain.value=dB(p.WetLevel);dry.gain.value=dB(p.DryLevel);node.connect(dry);node.connect(dl);dl.connect(fb);fb.connect(dl);dl.connect(wet);dry.connect(out);wet.connect(out);node=out;stops.push(p.Delay*6)}
  else if(cls==="Flange"||cls==="Chorus"){const base=cls==="Flange"?0.003:0.02,dl=ctx.createDelay(0.1),out=ctx.createGain(),dry=ctx.createGain(),wet=ctx.createGain();dl.delayTime.value=base;lfo(p.Rate,base*p.Depth*0.8,dl.delayTime);wet.gain.value=p.Mix;dry.gain.value=1-p.Mix*0.5;node.connect(dry);node.connect(dl);dl.connect(wet);dry.connect(out);wet.connect(out);node=out}
 }return node}
// play(정의, 지연초, 피치흔들림, 볼륨배율, 피치배율, 시작초, 길이초)
function play(d,delay=0,jit=0,vs=1,ps=1,start=0,cutOv,sw){const s=ctx.createBufferSource();s.buffer=buf[d.f];const rate0=d.p*ps*(1+(Math.random()*2-1)*jit);s.playbackRate.value=rate0;
 const g=ctx.createGain();g.gain.value=d.v*vs*document.getElementById("vol").value;s.connect(g);const stops=[];const out=applyFx(d.fx,g,stops);out.connect(ctx.destination);
 const t=ctx.currentTime+delay;
 if(sw){s.loop=true;const L=sw.sweep||[[0,1],[1,1]],D=sw.dur,v0=g.gain.value;s.playbackRate.setValueAtTime(rate0*L[0][1],t);for(const [x,m] of L)s.playbackRate.linearRampToValueAtTime(rate0*m,t+x*D);if(sw.gate){const [on,off]=sw.gate,cyc=on+off;g.gain.setValueAtTime(0,t);for(let k=0;k*cyc<D;k++){const a=t+k*cyc;g.gain.setValueAtTime(0,a);g.gain.linearRampToValueAtTime(v0,a+0.015);g.gain.setValueAtTime(v0,a+on-0.015);g.gain.linearRampToValueAtTime(0,a+on)}}else{g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(v0,t+0.05);g.gain.setValueAtTime(v0,t+D-0.15);g.gain.linearRampToValueAtTime(0,t+D);}s.start(t);s.stop(t+D+0.02);return}
 s.start(t,start);const cut=cutOv||d.cut;if(cut){g.gain.setValueAtTime(g.gain.value,t+cut);g.gain.linearRampToValueAtTime(0,t+cut+0.06);s.stop(t+cut+0.07)}}
const last={};
function footstep(d,key,delay=0,jit=0,ps=1){
 if(d.steps){let k=Math.floor(Math.random()*d.steps.length);if(k===last[key])k=(k+1)%d.steps.length;last[key]=k;play(d,delay,jit,1,ps,d.steps[k][0],d.steps[k][1])}else play(d,delay,jit,1,ps);
 if(d.claw)footstep(BASE[d.claw],d.claw,delay+0.07,0.06)}
function btn(id,label,fn,parent){const b=document.createElement("button");b.textContent=label;b.onclick=async()=>{await ctx.resume();await ready;fn()};(parent||document.getElementById(id)).appendChild(b)}
const walk=(key,n,gap,jit,irr)=>()=>{for(let i=0;i<n;i++)footstep(BASE[key],key,i*gap*(1+(Math.random()-0.5)*irr),jit)};
btn("foot","걷기 (6걸음)",walk("FootWalk",6,0.5,0,0.06));btn("foot","달리기 (8걸음)",walk("FootRun",8,0.36,0,0.06));btn("foot","웅크리기 (4걸음)",walk("FootCrouch",4,0.6,0,0.06));
btn("mstep","괴물 걸음 (쿵… 쿵… 느리고 불규칙)",walk("MonsterStep",5,0.75,0.08,0.35));
btn("mstep","비교: 사람 걷기 → 괴물 걸음",()=>{for(let i=0;i<4;i++)footstep(BASE.FootWalk,"FootWalk",i*0.5);for(let i=0;i<4;i++)footstep(BASE.MonsterStep,"MonsterStep",2.4+i*0.75,0.08)});
SONARS.forEach(([name,def])=>{btn("sonar","음파 "+name,()=>play(def))});
const box=document.getElementById("styles");{let n=0;STYLES.forEach(s=>{if(!s.variant)s.num=++n})}
STYLES.forEach((st,i)=>{const c=document.createElement("div");c.className="card";c.innerHTML=st.variant?"<b>"+st.name+"</b>":"<b>시안 "+(st.num)+"</b> — "+st.name;const r=document.createElement("div");r.className="row";c.appendChild(r);box.appendChild(c);
 const resolve=(n)=>st.S[n]||BASE[n];
 (st.ghost?[["추격(Chase) — 이때만 소리가 남","Chase"],["사망 연출용 한 번 (MonsterAlert, 2D)","Alert"]]:[["배회 중 (작고 멀리서)","Idle"],["경계(Alert)","Alert"],["추격(Chase)","Chase"]]).forEach(([lab,k])=>btn(null,lab,()=>{for(const l of st.M[k])play(resolve(l.s),l.t,0.05,l.v,l.p,0,undefined,(l.sweep||l.gate)?{sweep:l.sweep,dur:l.dur,gate:l.gate}:undefined)},r))});

const RECIPES=${JSON.stringify(recipes)};
const FXMAP={ghost:FX_GHOST,hollow:FX_HOLLOW,breath:FX_BREATH,siren:FX_SIREN,stutter:FX_STUTTER,echo:FX_ECHO,flange:FX_FLANGE,screech:FX_SCREECH,roar:FX_ROAR,pulse:FX_PULSE};
const SRCVOL={ouch:0.3,oof:0.12,wind:6};
function playRecipe(r){const fx=FXMAP[r.fx]||[];const sweep=r.to?[[0,1],[1,r.to]]:FLAT,dur=r.dur||2.4,sw={sweep,dur,gate:r.gate||undefined};
 play(snd(r.src,SRCVOL[r.src],r.pitch,0,fx),0,0,1,1,0,undefined,sw);
 if(r.air==="wind")play(snd("wind",6,1.6,0,[EQ(-40,-2,8),REV(4,-2)]),0,0,1,1,0,undefined,sw);
 else if(r.air==="oof")play(snd("oof",0.1,r.pitch*0.9,0,fx),0,0,1,1,0,undefined,sw)}
const FXNAMES={ghost:"귀신 곡소리",hollow:"공허한 울음",breath:"바람 숨소리",siren:"떨리는 사이렌",stutter:"더듬는 사이렌",echo:"에코 파동",flange:"플랜저 휘감김",screech:"초음파 비명",roar:"왜곡 포효",pulse:"저주파 맥동"};
const sel=document.getElementById("fxf"),cat=document.getElementById("cat");
sel.innerHTML='<option value="">전체</option>'+Object.entries(FXNAMES).map(([k,v])=>'<option value="'+k+'">'+v+'</option>').join("");
function renderCat(){cat.innerHTML="";RECIPES.filter(r=>!sel.value||r.fx===sel.value).forEach(r=>btn(null,r.n+". "+r.name,()=>playRecipe(r),cat))}
sel.onchange=renderCat;renderCat();
// 직접 만들기
const B=document.getElementById("builder");
B.innerHTML='<b>직접 만들기</b> <small>— 값을 바꾸고 재생해 보세요. 마음에 들면 아래 한 줄을 복사해 알려주세요(또는 Config.luau 에 붙여 넣기)</small>'
+'<div class="row"><label>소리 <select id="b_src"><option>ouch</option><option>oof</option><option>wind</option></select></label>'
+'<label>효과 <select id="b_fx">'+Object.keys(FXNAMES).map(k=>'<option>'+k+'</option>').join("")+'</select></label>'
+'<label>겹침 <select id="b_air"><option value="">없음</option><option>wind</option><option>oof</option></select></label></div>'
+'<div class="row"><label>음 높이 <input id="b_pitch" type="range" min="0.2" max="2.6" step="0.05" value="1.25"> <b id="o_pitch"></b></label></div>'
+'<div class="row"><label>켜짐(초) <input id="b_on" type="range" min="0" max="0.6" step="0.01" value="0.22"> <b id="o_on"></b></label>'
+'<label>꺼짐(초) <input id="b_off" type="range" min="0" max="0.6" step="0.01" value="0.14"> <b id="o_off"></b></label></div>'
+'<div class="row"><label>길이(초) <input id="b_dur" type="range" min="1" max="4" step="0.1" value="2.4"> <b id="o_dur"></b></label>'
+'<label>끝 높이 배율 <input id="b_to" type="range" min="0.3" max="2.5" step="0.05" value="1"> <b id="o_to"></b> <small>(1=일정, 작으면 내려가고 크면 올라감)</small></label></div>'
+'<div class="row"><button id="b_play">재생</button><button id="b_copy">한 줄 복사</button></div><pre id="b_out" style="white-space:pre-wrap;background:#000;border:1px solid #444;padding:8px"></pre>';
const g=(id)=>document.getElementById(id);
function cur(){const on=+g("b_on").value,off=+g("b_off").value,to=+g("b_to").value;const r={src:g("b_src").value,pitch:+g("b_pitch").value,fx:g("b_fx").value,dur:+g("b_dur").value};
 if(on>0&&off>0)r.gate=[on,off];if(g("b_air").value)r.air=g("b_air").value;if(Math.abs(to-1)>0.001)r.to=to;return r}
function line(r){const p=['src = "'+r.src+'"','pitch = '+r.pitch,'fx = "'+r.fx+'"'];if(r.gate)p.push("gate = { "+r.gate[0]+", "+r.gate[1]+" }");p.push("dur = "+r.dur);if(r.air)p.push('air = "'+r.air+'"');if(r.to)p.push("to = "+r.to);return "Config.ScreamCustom = { "+p.join(", ")+" }"}
function upd(){g("o_pitch").textContent=g("b_pitch").value;g("o_on").textContent=g("b_on").value;g("o_off").textContent=g("b_off").value;g("o_dur").textContent=g("b_dur").value;g("o_to").textContent=g("b_to").value;g("b_out").textContent=line(cur())}
B.querySelectorAll("input,select").forEach(e=>e.oninput=upd);upd();
g("b_play").onclick=async()=>{await ctx.resume();await ready;playRecipe(cur())};
g("b_copy").onclick=()=>{navigator.clipboard&&navigator.clipboard.writeText(g("b_out").textContent)};
</script>`;
fs.writeFileSync(path.join(__dirname, "index.html"), html);
console.log("ok", html.length);
