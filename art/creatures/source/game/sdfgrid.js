// 시안 조각 몸(SDF)을 시안 렌더러와 똑같은 셰이더 함수(setN/view.html 의 prim·grp·map)로 3D 격자에 찍는다(GPU, Edge headless).
// sdfGrid(setDir, bodyData, vox) → { nx, ny, nz, mn, vox, d: Float32Array(거리), m: Uint8Array(재질) }
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';

function sdfGrid(setDir, b, vox) {
  const view = fs.readFileSync(path.join(setDir, 'view.html'), 'utf8');
  const a = view.indexOf('const FS1=`') + 'const FS1=`'.length, e = view.indexOf('void main(){vec2 px=gl_FragCoord.xy', a);
  if (a < 20 || e < 0) throw new Error('view.html FS1 not found in ' + setDir);
  const funcs = view.slice(a, e);
  const mn = b.mn.map(v => v - vox * 2), mx = b.mx.map(v => v + vox * 2);
  const nx = Math.ceil((mx[0] - mn[0]) / vox) + 1, ny = Math.ceil((mx[1] - mn[1]) / vox) + 1, nz = Math.ceil((mx[2] - mn[2]) / vox) + 1;
  const cols = Math.max(1, Math.floor(8192 / nx)), rowsT = Math.ceil(nz / cols), W = nx * cols, H = ny * rowsT;
  if (H > 16384) throw new Error('grid too big ' + [nx, ny, nz]);
  const fsMain = `uniform float uVox;uniform int uNX,uNY,uCols;
void main(){ivec2 c=ivec2(gl_FragCoord.xy);int tx=c.x/uNX,ix=c.x-tx*uNX,ty=c.y/uNY,iy=c.y-ty*uNY;int iz=ty*uCols+tx;vec3 p=uMn+vec3(float(ix),float(iy),float(iz))*uVox;vec2 h=map(p);o0=vec4(h.x,h.y,0,1);o1=vec4(0);}`;
  const page = `<!doctype html><html><body><pre id="out"></pre><script>
const SPEC=${JSON.stringify({ P: b.P, G: b.G, np: b.np, ng: b.ng, mn, vox, nx, ny, nz, cols, W, H })};
const cv=document.createElement('canvas');cv.width=8;cv.height=8;const gl=cv.getContext('webgl2');gl.getExtension('EXT_color_buffer_float');
const VS='#version 300 es\\nvoid main(){vec2 p=vec2((gl_VertexID<<1)&2,gl_VertexID&2);gl_Position=vec4(p*2.-1.,0,1);}';
const FS=${JSON.stringify(funcs)}+${JSON.stringify(fsMain)};
function ftex(d,w,h){const t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA32F,w,h,0,gl.RGBA,gl.FLOAT,d?new Float32Array(d):null);for(const k of[gl.TEXTURE_MIN_FILTER,gl.TEXTURE_MAG_FILTER])gl.texParameteri(gl.TEXTURE_2D,k,gl.NEAREST);return t}
const out=document.getElementById('out');
try{
const p=gl.createProgram();for(const[t,s]of[[gl.VERTEX_SHADER,VS],[gl.FRAGMENT_SHADER,FS]]){const h=gl.createShader(t);gl.shaderSource(h,s);gl.compileShader(h);if(!gl.getShaderParameter(h,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(h));gl.attachShader(p,h)}gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error("link "+gl.getProgramInfoLog(p));gl.useProgram(p);const E=[];const ck=n=>{const e=gl.getError();if(e)E.push(n+":"+e)};
const U=n=>gl.getUniformLocation(p,n);
const tP=ftex(SPEC.P,4,SPEC.np),tG=ftex(SPEC.G,3,SPEC.ng);ck("tex");
gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,tP);gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,tG);
gl.uniform1i(U('uP'),0);gl.uniform1i(U('uG'),1);gl.uniform1i(U('uNG'),SPEC.ng);gl.uniform3fv(U('uMn'),SPEC.mn);gl.uniform1f(U('uVox'),SPEC.vox);gl.uniform1i(U('uNX'),SPEC.nx);gl.uniform1i(U('uNY'),SPEC.ny);gl.uniform1i(U('uCols'),SPEC.cols);ck("unif");
const t0=ftex(null,SPEC.W,SPEC.H),t1=ftex(null,SPEC.W,SPEC.H),fb=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,t0,0);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT1,gl.TEXTURE_2D,t1,0);gl.drawBuffers([gl.COLOR_ATTACHMENT0,gl.COLOR_ATTACHMENT1]);ck("fb");gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,tP);gl.activeTexture(gl.TEXTURE1);gl.bindTexture(gl.TEXTURE_2D,tG);
gl.viewport(0,0,SPEC.W,SPEC.H);gl.enable(gl.SCISSOR_TEST);const T=256,px1=new Float32Array(4);gl.readBuffer(gl.COLOR_ATTACHMENT0);
for(let y=0;y<SPEC.H;y+=T)for(let x=0;x<SPEC.W;x+=T){gl.scissor(x,y,T,T);gl.drawArrays(gl.TRIANGLES,0,3);gl.readPixels(x,y,1,1,gl.RGBA,gl.FLOAT,px1)}
ck("draw");gl.disable(gl.SCISSOR_TEST);
const buf=new Float32Array(SPEC.W*SPEC.H*4);gl.readPixels(0,0,SPEC.W,SPEC.H,gl.RGBA,gl.FLOAT,buf);
const n=SPEC.nx*SPEC.ny*SPEC.nz,q=new Int16Array(n),m=new Uint8Array(n);
for(let iz=0;iz<SPEC.nz;iz++){const tx=iz%SPEC.cols,ty=Math.floor(iz/SPEC.cols);for(let iy=0;iy<SPEC.ny;iy++)for(let ix=0;ix<SPEC.nx;ix++){const k=((ty*SPEC.ny+iy)*SPEC.W+tx*SPEC.nx+ix)*4,i=(iz*SPEC.ny+iy)*SPEC.nx+ix;q[i]=Math.max(-32767,Math.min(32767,Math.round(buf[k]*4000)));m[i]=buf[k+1]}}
const b64=u=>{let s='';const B=new Uint8Array(u.buffer);for(let i=0;i<B.length;i+=32768)s+=String.fromCharCode.apply(null,B.subarray(i,i+32768));return btoa(s)};
out.textContent='OK|'+b64(q)+'|'+b64(m)+'|'+gl.checkFramebufferStatus(gl.FRAMEBUFFER)+','+gl.getError()+','+buf[0]+','+buf[1]+','+E.join(';');
}catch(err){out.textContent='ERR|'+err.message}
</script></body></html>`;
  const tmpDir = path.join(process.env.TEMP, 'sdfgrid-' + process.pid); fs.mkdirSync(tmpDir, { recursive: true });
  const h = path.join(tmpDir, 'g.html'); fs.writeFileSync(h, page);
  const dom = execFileSync(EDGE, ['--headless=new', '--use-angle=d3d11', '--mute-audio', '--virtual-time-budget=1500000', `--user-data-dir=${path.join(tmpDir, 'u')}`, '--dump-dom', 'file:///' + encodeURI(h.split(path.sep).join('/'))], { maxBuffer: 1 << 30, timeout: 1500000 }).toString();
  try { fs.rmSync(tmpDir, { recursive: true, force: true }); } catch (err) {}
  const mm = dom.match(/<pre id="out">([^<]*)<\/pre>/); if (!mm) throw new Error('no output');
  const parts = mm[1].split('|'); if (process.env.DBG) console.log(parts.slice(3).join(' ')); if (parts[0] !== 'OK') throw new Error('shader: ' + parts[1]);
  const qb = Buffer.from(parts[1], 'base64'), q = new Int16Array(qb.buffer, qb.byteOffset, qb.length / 2);
  const d = new Float32Array(q.length); for (let i = 0; i < q.length; i++) d[i] = q[i] / 4000;
  const m = new Uint8Array(Buffer.from(parts[2], 'base64'));
  return { nx, ny, nz, mn, vox, d, m };
}
module.exports = { sdfGrid };
