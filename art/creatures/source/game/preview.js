// 구운 게임 부품을 음파 선처럼(원통 = 실루엣 2줄, 공 = 원, 상자 = 모서리) 그려 본다: node preview.js k1h1 ... → out/<id>_game.png
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const OUTD = path.join(__dirname, 'out'); fs.mkdirSync(OUTD, { recursive: true });
function load(id) { return JSON.parse(fs.readFileSync(path.join(OUTD, id + '.json'), 'utf8')); }
function draw(D, frame, yaw, pitch, W, H) {
  const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
  const pr = p => { const x = p[0] * cy - p[2] * sy, z = p[0] * sy + p[2] * cy; const y = p[1] * cp - z * sp; return [x, -y, z * cp + p[1] * sp]; };
  const pts = []; let o = 0; const items = D.parts.map(pt => { const t = pt[0]; const n = t === 'c' ? 6 : 3; const v = frame.slice(o, o + n); o += n; return { t, pt, v }; });
  for (const it of items) { if (it.t === 'c') pts.push(pr(it.v.slice(0, 3)), pr(it.v.slice(3))); else pts.push(pr(it.v)); }
  let mnx = 1e9, mxx = -1e9, mny = 1e9, mxy = -1e9; for (const p of pts) { mnx = Math.min(mnx, p[0]); mxx = Math.max(mxx, p[0]); mny = Math.min(mny, p[1]); mxy = Math.max(mxy, p[1]); }
  const k = Math.min(W * .86 / (mxx - mnx), H * .86 / (mxy - mny)), ox = W / 2 - (mnx + mxx) / 2 * k, oy = H / 2 - (mny + mxy) / 2 * k; const S = p => [p[0] * k + ox, p[1] * k + oy];
  let svg = '';
  for (const it of items) {
    if (it.t === 'c') { const a = S(pr(it.v.slice(0, 3))), b = S(pr(it.v.slice(3))), r = it.pt[1] * k; const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l * r, ny = dx / l * r;
      if (r < 1.2) svg += `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}"/>`; else svg += `<line x1="${a[0] + nx}" y1="${a[1] + ny}" x2="${b[0] + nx}" y2="${b[1] + ny}"/><line x1="${a[0] - nx}" y1="${a[1] - ny}" x2="${b[0] - nx}" y2="${b[1] - ny}"/>`; }
    else if (it.t === 'b') { const c = S(pr(it.v)); svg += `<circle cx="${c[0]}" cy="${c[1]}" r="${Math.max(.8, it.pt[1] * k)}"/>`; }
    else { const c = it.v, h = it.pt.slice(1, 4), ax = [it.pt.slice(4, 7), it.pt.slice(7, 10), it.pt.slice(10, 13)]; const corner = (i, j, l) => S(pr([0, 1, 2].map(d => c[d] + ax[0][d] * h[0] * i + ax[1][d] * h[1] * j + ax[2][d] * h[2] * l)));
      for (const [p, q] of [[[-1, -1, -1], [1, -1, -1]], [[-1, 1, -1], [1, 1, -1]], [[-1, -1, 1], [1, -1, 1]], [[-1, 1, 1], [1, 1, 1]], [[-1, -1, -1], [-1, 1, -1]], [[1, -1, -1], [1, 1, -1]], [[-1, -1, 1], [-1, 1, 1]], [[1, -1, 1], [1, 1, 1]], [[-1, -1, -1], [-1, -1, 1]], [[1, -1, -1], [1, -1, 1]], [[-1, 1, -1], [-1, 1, 1]], [[1, 1, -1], [1, 1, 1]]]) { const a = corner(...p), b = corner(...q); svg += `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}"/>`; } }
  }
  return svg;
}
for (const id of process.argv.slice(2)) {
  const D = load(id); const W = 420, H = 520; const views = [[35, 8, D.idle, '대기 3/4'], [0, 4, D.idle, '정면'], [90, 4, D.idle, '측면'], [35, 8, D.chase[2], '추격'], [35, 8, D.attack, '덮침']];
  let body = views.map(([y, p, f, t], i) => `<g transform="translate(${i * W},0)"><rect width="${W}" height="${H}" fill="#020305" stroke="#1b2230"/><text x="12" y="26" fill="#8b98a9" font-size="16">${t}</text><g stroke="#d7d7d7" stroke-width="1.3" fill="none">${draw(D, f, y * Math.PI / 180, p * Math.PI / 180, W, H)}</g></g>`).join('');
  const svgf = path.join(OUTD, id + '_game.svg'); fs.writeFileSync(svgf, `<svg xmlns="http://www.w3.org/2000/svg" width="${W * views.length}" height="${H}" font-family="Malgun Gothic"><text x="10" y="${H - 10}" fill="#556" font-size="13">${id} ${D.name} — 게임 음파 선(부품 ${D.parts.length}개)</text>${body}</svg>`);
  execFileSync('C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', ['--headless=new', '--hide-scrollbars', `--window-size=${W * views.length},${H}`, `--screenshot=${path.join(OUTD, id + '_game.png')}`, 'file:///' + svgf.split(path.sep).join('/')], { stdio: 'ignore', timeout: 60000 });
  console.log(id, 'ok');
}
