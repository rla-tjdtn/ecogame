// 메시 미리보기: node meshview.js <id> [yaw] → out/mesh/<id>_view.png (어두운 몸 + 가장자리 빛, 게임 느낌 확인용)
const fs=require('fs'),path=require('path'),{execFileSync}=require('child_process');
const id=process.argv[2],yaw=+(process.argv[3]||20);const D=JSON.parse(fs.readFileSync(path.join(__dirname,'out/mesh',id+'.json'),'utf8'));
const html=`<!doctype html><body style="margin:0;background:#05070a"><canvas id=c width=900 height=1100></canvas><script>
const D=${JSON.stringify(D)};const gl=document.getElementById('c').getContext('webgl2',{antialias:true});
const vs=\`#version 300 es
in vec3 p;in vec3 n;uniform mat4 M;out vec3 vn;out vec3 vp;void main(){vn=n;vp=p;gl_Position=M*vec4(p,1);}\`;
const fs=\`#version 300 es
precision highp float;in vec3 vn;in vec3 vp;uniform vec3 V;out vec4 o;void main(){vec3 n=normalize(vn);float r=pow(1.-abs(dot(n,V)),2.5);float k=max(dot(n,normalize(vec3(-.4,.8,.5))),0.);float f=.03+.5*r+.18*k*k*k;o=vec4(vec3(f*.92,f,f*1.1),1);}\`;
const pr=gl.createProgram();for(const[t,s]of[[gl.VERTEX_SHADER,vs],[gl.FRAGMENT_SHADER,fs]]){const h=gl.createShader(t);gl.shaderSource(h,s);gl.compileShader(h);gl.attachShader(pr,h)}gl.linkProgram(pr);gl.useProgram(pr);
const buf=(a,l,n)=>{const b=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,b);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(a),gl.STATIC_DRAW);const L=gl.getAttribLocation(pr,l);gl.enableVertexAttribArray(L);gl.vertexAttribPointer(L,n,gl.FLOAT,false,0,0)};
buf(D.P,'p',3);buf(D.N,'n',3);const ib=gl.createBuffer();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,ib);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,new Uint32Array(D.T),gl.STATIC_DRAW);
let mn=[1e9,1e9,1e9],mx=[-1e9,-1e9,-1e9];for(let i=0;i<D.P.length;i+=3)for(let k=0;k<3;k++){mn[k]=Math.min(mn[k],D.P[i+k]);mx[k]=Math.max(mx[k],D.P[i+k])}
const c=mn.map((v,i)=>(v+mx[i])/2),R=Math.max(mx[1]-mn[1],mx[0]-mn[0],mx[2]-mn[2])*.56;const y=${yaw}*Math.PI/180,cy=Math.cos(y),sy=Math.sin(y),pt=.08,cp=Math.cos(pt),sp=Math.sin(pt);
const s=1/R,a=1100/900;const M=[cy*s/a,-sy*sp*s,sy*cp*-.01, 0, 0,cp*s,sp*.01,0, sy*s/a,cy*sp*s,-cy*cp*.01,0, 0,0,0,1];
const tx=-(c[0]*M[0]+c[1]*M[4]+c[2]*M[8]),ty=-(c[0]*M[1]+c[1]*M[5]+c[2]*M[9]);M[12]=tx;M[13]=ty;M[14]=0;
gl.uniformMatrix4fv(gl.getUniformLocation(pr,'M'),false,M);gl.uniform3fv(gl.getUniformLocation(pr,'V'),[-sy*cp,-sp,cy*cp].map(v=>-v));
gl.enable(gl.DEPTH_TEST);gl.clearColor(.02,.027,.04,1);gl.clear(16640);gl.drawElements(gl.TRIANGLES,D.T.length,gl.UNSIGNED_INT,0);
</script>`;
const h=path.join(__dirname,'out/mesh',id+'_view.html');fs.writeFileSync(h,html);
execFileSync('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',['--headless=new','--use-angle=d3d11','--hide-scrollbars','--window-size=900,1100',`--screenshot=${path.join(__dirname,'out/mesh',id+'_view.png')}`,'file:///'+encodeURI(h.split(path.sep).join('/'))],{stdio:'ignore'});
