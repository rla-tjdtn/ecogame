// 시안 얼굴(out/mesh/<id>_face_design.png) | 게임 미리보기 얼굴 | 게임 미리보기 몸 → out/<id>_tex_compare.png
const {PNG}=require('pngjs'),fs=require('fs');const id=process.argv[2];
const pv=PNG.sync.read(fs.readFileSync('out/tex/'+id+'_prev.png'));const ds=PNG.sync.read(fs.readFileSync('out/mesh/'+id+'_face_design.png'));
const H=800,W=600*2+700+20,o=new PNG({width:W,height:H});for(let i=0;i<o.data.length;i+=4){o.data[i]=o.data[i+1]=o.data[i+2]=0;o.data[i+3]=255}
const blit=(src,sx,sy,sw,sh,dx,dy,dw,dh)=>{for(let y=0;y<dh;y++)for(let x=0;x<dw;x++){const X=Math.floor(sx+x*sw/dw),Y=Math.floor(sy+y*sh/dh);const i=(Y*src.width+X)*4,j=((dy+y)*W+dx+x)*4;for(let k=0;k<3;k++)o.data[j+k]=src.data[i+k]}};
blit(ds,0,0,ds.width,ds.height,0,0,600,800);blit(pv,3*1024+137,0,750,1000,610,0,600,800);blit(pv,1024+100,40,800,914,1220,0,700,800);
fs.writeFileSync('out/'+id+'_tex_compare.png',PNG.sync.write(o));
