// 원본 디자인 자세(시안 렌더러) 6장: 걷기 0·.25·.5·.75 · 추격 · 덮침, 위줄 = 앞쪽 3/4(animview 와 같은 방향), 아래줄 = 옆
//   node designref.js <id> → out/mesh/<id>_design.png  (animview.js 의 <id>_anim.png 와 칸 순서가 같다)
const path=require('path');const {CFG}=require('./bake.js');const SRC=path.join(__dirname,'..');
const fs=require('fs');const FIXD=path.join(__dirname,'fixes');if(fs.existsSync(FIXD))for(const f of fs.readdirSync(FIXD))if(f.endsWith('.json')){const F=JSON.parse(fs.readFileSync(path.join(FIXD,f),'utf8'));for(const id in F)if(CFG[id])Object.assign(CFG[id],F[id]);}
const META=Object.assign({},require(path.join(SRC,'set1/meta.js')),require(path.join(SRC,'set2/meta2.js')),require(path.join(SRC,'set3/meta3.js')),require(path.join(SRC,'set4/meta4.js')));
const id=process.argv[2],c=CFG[id],C=require(path.join(SRC,c.mod+'.js')),{render}=require(path.join(SRC,path.dirname(c.mod),'sculpt.js'));
const m=META[path.basename(c.mod)]||{},base={...(m.hero||(m.poses&&m.poses[0]&&m.poses[0][1])||{})};const PK=c.phase||'walk';delete base[PK];
const ph=(o,v)=>({...base,...o,[PK]:c.phaseAmp?(c.phaseBase||0)+c.phaseAmp*Math.sin(v*2*Math.PI):v});
const poses=[ph(c.walk,0),ph(c.walk,.25),ph(c.walk,.5),ph(c.walk,.75),ph(c.chase,.25),{...base,...c.attack}];
const bodies=poses.map(p=>C.build(p).data());const b=bodies[0];const H=b.mx[1]-b.mn[1],R=Math.hypot(b.mx[0]-b.mn[0],b.mx[2]-b.mn[2])/2;
const sc=Math.min(300*.42/R,400*.85/Math.max(H,2*R));const target=b.mn.map((v,i)=>(v+b.mx[i])/2);
// animview 위줄 yaw 200(게임 좌표) = 디자인 yaw 20, 아래줄 90(게임) = 디자인 -90
const panels=[];for(let row=0;row<2;row++)for(let i=0;i<6;i++)panels.push({x:i*300,y:row*400,w:300,h:400,body:i,yaw:row?-90:20,pitch:6,scale:sc,target,lw:1.1,ss:2,bg:'hero'});
render({W:1800,H:800,bodies,panels},path.join(__dirname,'out/mesh',id+'_design.png'));
