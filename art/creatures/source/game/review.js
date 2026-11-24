// 검토 모음: node review.js out/review_a.png id1 id2 ... → 움직임 미리보기들을 이름표와 함께 세로로 이어 붙인다
const fs=require('fs'),path=require('path'),{execFileSync}=require('child_process');const {CFG}=require('./bake.js');
const [out,...ids]=process.argv.slice(2);const W=1800,H=800,S=.55;
const html=`<body style="margin:0;background:#000;color:#aab;font:22px Malgun Gothic">`+ids.map(id=>`<div style="position:relative"><img src="mesh/${id}_anim.png" style="width:${W*S}px;display:block"><span style="position:absolute;left:8px;top:4px">${id} ${CFG[id]?CFG[id].name:''}</span></div>`).join('')+'</body>';
const h=path.join(__dirname,'out','review.html');fs.writeFileSync(h,html);
execFileSync('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--hide-scrollbars',`--window-size=${W*S},${H*S*ids.length}`,`--screenshot=${path.resolve(out)}`,'file:///'+encodeURI(h.split(path.sep).join('/'))],{stdio:'ignore'});
