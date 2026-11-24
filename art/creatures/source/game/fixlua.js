// (한 번) 이미 만든 CreatureRigs/<id>.luau 의 프레임을 뼈마다 { } 로 다시 묶는다(rig.js f7 버그 수정 전 파일)
const fs=require('fs'),path=require('path');const D=path.join(__dirname,'..','..','..','..','src','shared','CreatureRigs');
for(const f of fs.readdirSync(D)){const p=path.join(D,f);let s=fs.readFileSync(p,'utf8');let n=0;
 s=s.replace(/\{ ([-0-9.,e ]+) \}/g,(m,body)=>{const v=body.split(',').map(x=>x.trim());if(v.length<14||v.length%7)return m;n++;const g=[];for(let i=0;i<v.length;i+=7)g.push('{'+v.slice(i,i+7).join(',')+'}');return '{ '+g.join(', ')+' }';});
 fs.writeFileSync(p,s);console.log(f,n);}
