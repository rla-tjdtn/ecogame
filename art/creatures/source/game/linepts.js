// 시안 선 픽셀 → 원래 곡면(SDF) 위 3D 점: 시안 렌더러와 똑같은 셰이더 함수(prim·grp·map)로 픽셀마다 광선을 쏴 표면 위치·법선을 구한다(GPU, Edge headless).
// linePoints(setDir, bodyData, views, pix) → Float32Array [x,y,z, nx,ny,nz, hit] × N
//   views[k] = { eye, R, U, F, scale }  (직교 카메라, scale = 픽셀/스터드)
//   pix = Float32Array [px, py, k] × N  (px, py = 칸 가운데 기준 픽셀, 위가 +)
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';

function linePoints(setDir, b, views, pix) {
  const view = fs.readFileSync(path.join(setDir, 'view.html'), 'utf8');
  const a = view.indexOf('const FS1=`') + 'const FS1=`'.length, e = view.indexOf('void main(){vec2 px=gl_FragCoord.xy', a);
  if (a < 20 || e < 0) throw new Error('view.html FS1 not found in ' + setDir);
  const funcs = view.slice(a, e);
  const N = pix.length / 3, TW = 4096, TH = Math.max(1, Math.ceil(N / TW));
  const NV = views.length;
  const fsMain = `uniform sampler2D uPix;uniform vec3 uE[${NV}],uRr[${NV}],uUu[${NV}],uFf[${NV}];uniform float uSc[${NV}];uniform int uN;
void main(){ivec2 c=ivec2(gl_FragCoord.xy);int i=c.y*${TW}+c.x;if(i>=uN){o0=vec4(0);o1=vec4(0);return;}
vec4 q=texelFetch(uPix,ivec2(i%${TW},i/${TW}),0);int k=int(q.z+.5);vec3 eye=uE[0],R=uRr[0],U=uUu[0],F=uFf[0];float sc=uSc[0];
for(int j=0;j<${NV};j++){if(j==k){eye=uE[j];R=uRr[j];U=uUu[j];F=uFf[j];sc=uSc[j];}}
vec3 ro=eye+(R*q.x+U*q.y)/sc,rd=F;vec3 iv=1./(rd+vec3(1e-7)),ta=(uMn-ro)*iv,tb=(uMx-ro)*iv;vec3 t1=min(ta,tb),t2=max(ta,tb);float tn=max(max(t1.x,t1.y),t1.z),tf=min(min(t2.x,t2.y),t2.z);
o0=vec4(0);o1=vec4(0);if(tf<max(tn,0.))return;float t=max(tn,0.);vec2 h;bool hit=false;float ee=.45/sc;
for(int s=0;s<220;s++){h=map(ro+rd*t);if(h.x<ee){hit=true;break;}t+=h.x*.82;if(t>tf)break;}if(!hit)return;
vec3 p=ro+rd*t;float e2=1.1/sc;vec2 E=vec2(1,-1)*e2;vec3 n=normalize(E.xyy*map(p+E.xyy).x+E.yyx*map(p+E.yyx).x+E.yxy*map(p+E.yxy).x+E.xxx*map(p+E.xxx).x);
o0=vec4(p,1);o1=vec4(n,1);}`;
  const v3 = arr => arr.flatMap(v => v);
  const page = `<!doctype html><html><body><pre id="out"></pre><script>
const S=${JSON.stringify({ P: b.P, G: b.G, np: b.np, ng: b.ng, mn: b.mn, mx: b.mx, N, TW, TH, E: v3(views.map(v => v.eye)), R: v3(views.map(v => v.R)), U: v3(views.map(v => v.U)), F: v3(views.map(v => v.F)), SC: views.map(v => v.scale) })};
const PIX=new Float32Array(Uint8Array.from(atob("${Buffer.from(pix.buffer, pix.byteOffset, pix.byteLength).toString('base64')}"),c=>c.charCodeAt(0)).buffer);
const cv=document.createElement('canvas');cv.width=8;cv.height=8;const gl=cv.getContext('webgl2');gl.getExtension('EXT_color_buffer_float');
const VS='#version 300 es\\nvoid main(){vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(p*2.-1.,0,1);}';
const FS=${JSON.stringify(funcs)}+${JSON.stringify(fsMain)};
function ftex(d,w,h){const t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA32F,w,h,0,gl.RGBA,gl.FLOAT,d);for(const k of[gl.TEXTURE_MIN_FILTER,gl.TEXTURE_MAG_FILTER])gl.texParameteri(gl.TEXTURE_2D,k,gl.NEAREST);return t}
const out=document.getElementById('out');
try{
const p=gl.createProgram();for(const[t,s]of[[gl.VERTEX_SHADER,VS],[gl.FRAGMENT_SHADER,FS]]){const h=gl.createShader(t);gl.shaderSource(h,s);gl.compileShader(h);if(!gl.getShaderParameter(h,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(h));gl.attachShader(p,h)}gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p));gl.useProgram(p);
const U=n=>gl.getUniformLocation(p,n);
const pixD=new Float32Array(S.TW*S.TH*4);for(let i=0;i<S.N;i++){pixD[i*4]=PIX[i*3];pixD[i*4+1]=PIX[i*3+1];pixD[i*4+2]=PIX[i*3+2];}
const t0=ftex(null,S.TW,S.TH),t1=ftex(null,S.TW,S.TH),fb=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,t0,0);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT1,gl.TEXTURE_2D,t1,0);gl.drawBuffers([gl.COLOR_ATTACHMENT0,gl.COLOR_ATTACHMENT1]);
const tP=ftex(new Float32Array(S.P),4,S.np),tG=ftex(new Float32Array(S.G),3,S.ng),tX=ftex(pixD,S.TW,S.TH);
gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,tP);gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,tG);gl.activeTexture(gl.TEXTURE2);gl.bindTexture(gl.TEXTURE_2D,tX);
gl.uniform1i(U('uP'),0);gl.uniform1i(U('uG'),1);gl.uniform1i(U('uPix'),2);gl.uniform1i(U('uNG'),S.ng);gl.uniform1i(U('uN'),S.N);gl.uniform3fv(U('uMn'),S.mn);gl.uniform3fv(U('uMx'),S.mx);
gl.uniform3fv(U('uE'),S.E);gl.uniform3fv(U('uRr'),S.R);gl.uniform3fv(U('uUu'),S.U);gl.uniform3fv(U('uFf'),S.F);gl.uniform1fv(U('uSc'),S.SC);
gl.viewport(0,0,S.TW,S.TH);gl.enable(gl.SCISSOR_TEST);const T=256,px1=new Float32Array(4);gl.readBuffer(gl.COLOR_ATTACHMENT0);
for(let y=0;y<S.TH;y+=T)for(let x=0;x<S.TW;x+=T){gl.scissor(x,y,T,T);gl.drawArrays(gl.TRIANGLES,0,3);gl.readPixels(x,y,1,1,gl.RGBA,gl.FLOAT,px1)}
gl.disable(gl.SCISSOR_TEST);const err=gl.getError();
const A0=new Float32Array(S.TW*S.TH*4),A1=new Float32Array(S.TW*S.TH*4);gl.readBuffer(gl.COLOR_ATTACHMENT0);gl.readPixels(0,0,S.TW,S.TH,gl.RGBA,gl.FLOAT,A0);gl.readBuffer(gl.COLOR_ATTACHMENT1);gl.readPixels(0,0,S.TW,S.TH,gl.RGBA,gl.FLOAT,A1);
const R7=new Float32Array(S.N*7);for(let i=0;i<S.N;i++){R7.set([A0[i*4],A0[i*4+1],A0[i*4+2],A1[i*4],A1[i*4+1],A1[i*4+2],A0[i*4+3]],i*7);}
const B=new Uint8Array(R7.buffer);let s='';for(let i=0;i<B.length;i+=32768)s+=String.fromCharCode.apply(null,B.subarray(i,i+32768));
out.textContent='OK|'+btoa(s)+'|'+err;
}catch(er){out.textContent='ERR|'+er.message}
</script></body></html>`;
  const tmpDir = path.join(process.env.TEMP, 'linepts-' + process.pid + '-' + Date.now()); fs.mkdirSync(tmpDir, { recursive: true });
  const h = path.join(tmpDir, 'g.html'); fs.writeFileSync(h, page);
  const dom = execFileSync(EDGE, ['--headless=new', '--use-angle=d3d11', '--mute-audio', '--virtual-time-budget=1500000', `--user-data-dir=${path.join(tmpDir, 'u')}`, '--dump-dom', 'file:///' + encodeURI(h.split(path.sep).join('/'))], { maxBuffer: 1 << 30, timeout: 1500000 }).toString();
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (err) {}
  const mm = dom.match(/<pre id="out">([^<]*)<\/pre>/); if (!mm) throw new Error('linepts: no output');
  const parts = mm[1].split('|'); if (parts[0] !== 'OK') throw new Error('linepts shader: ' + parts[1]);
  const buf = Buffer.from(parts[1], 'base64');
  return new Float32Array(buf.buffer, buf.byteOffset, buf.length / 4);
}
module.exports = { linePoints };
