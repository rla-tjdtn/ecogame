// SDF 격자 → 삼각형 메시(표면 그물 Surface Nets: 칸마다 표면 위 점 하나, 이웃 칸 점끼리 사각형 → 삼각형 2개)
// 점 위치는 칸 모서리에서 부호가 바뀌는 곳들의 평균 + 기울기 방향으로 표면에 한 번 더 붙인다.
function surfaceNets(G) {
  const { nx, ny, nz, mn, vox, d, m } = G;
  const idx = (x, y, z) => (z * ny + y) * nx + x;
  const vid = new Int32Array(nx * ny * nz).fill(-1);
  const P = [], N = [], M = [];
  const E = [[0, 0, 0, 1, 0, 0], [0, 1, 0, 1, 1, 0], [0, 0, 1, 1, 0, 1], [0, 1, 1, 1, 1, 1], [0, 0, 0, 0, 1, 0], [1, 0, 0, 1, 1, 0], [0, 0, 1, 0, 1, 1], [1, 0, 1, 1, 1, 1], [0, 0, 0, 0, 0, 1], [1, 0, 0, 1, 0, 1], [0, 1, 0, 0, 1, 1], [1, 1, 0, 1, 1, 1]];
  const val = (x, y, z) => d[idx(Math.min(nx - 1, Math.max(0, x)), Math.min(ny - 1, Math.max(0, y)), Math.min(nz - 1, Math.max(0, z)))];
  const grad = (x, y, z) => { const fx = Math.floor(x), fy = Math.floor(y), fz = Math.floor(z); const gx = val(fx + 1, fy, fz) - val(fx - 1, fy, fz), gy = val(fx, fy + 1, fz) - val(fx, fy - 1, fz), gz = val(fx, fy, fz + 1) - val(fx, fy, fz - 1); const l = Math.hypot(gx, gy, gz) || 1; return [gx / l, gy / l, gz / l]; };
  for (let z = 0; z < nz - 1; z++) for (let y = 0; y < ny - 1; y++) for (let x = 0; x < nx - 1; x++) {
    let sx = 0, sy = 0, sz = 0, c = 0, inside = 0;
    for (let k = 0; k < 8; k++) if (d[idx(x + (k & 1), y + ((k >> 1) & 1), z + (k >> 2))] < 0) inside++;
    if (inside === 0 || inside === 8) continue;
    for (const [ax, ay, az, bx, by, bz] of E) {
      const va = d[idx(x + ax, y + ay, z + az)], vb = d[idx(x + bx, y + by, z + bz)];
      if ((va < 0) !== (vb < 0)) { const t = va / (va - vb); sx += ax + (bx - ax) * t; sy += ay + (by - ay) * t; sz += az + (bz - az) * t; c++; }
    }
    let px = x + sx / c, py = y + sy / c, pz = z + sz / c;
    vid[idx(x, y, z)] = P.length / 3;
    P.push(mn[0] + px * vox, mn[1] + py * vox, mn[2] + pz * vox);
    const g = grad(px + .5, py + .5, pz + .5); N.push(...g);
    // 재질: 칸 안 가장 안쪽 점의 재질
    let best = 1e9, mat = 0; for (let k = 0; k < 8; k++) { const i = idx(x + (k & 1), y + ((k >> 1) & 1), z + (k >> 2)); if (d[i] < best) { best = d[i]; mat = m[i]; } } M.push(mat);
  }
  const T = [];
  for (let z = 1; z < nz - 1; z++) for (let y = 1; y < ny - 1; y++) for (let x = 1; x < nx - 1; x++) {
    const a = d[idx(x, y, z)] < 0;
    // x 방향 모서리
    if ((d[idx(x + 1, y, z)] < 0) !== a) quad(vid[idx(x, y - 1, z - 1)], vid[idx(x, y, z - 1)], vid[idx(x, y, z)], vid[idx(x, y - 1, z)], a);
    if ((d[idx(x, y + 1, z)] < 0) !== a) quad(vid[idx(x - 1, y, z - 1)], vid[idx(x - 1, y, z)], vid[idx(x, y, z)], vid[idx(x, y, z - 1)], a);
    if ((d[idx(x, y, z + 1)] < 0) !== a) quad(vid[idx(x - 1, y - 1, z)], vid[idx(x, y - 1, z)], vid[idx(x, y, z)], vid[idx(x - 1, y, z)], a);
  }
  function quad(i0, i1, i2, i3, flip) {
    if (i0 < 0 || i1 < 0 || i2 < 0 || i3 < 0) return;
    if (flip) T.push(i0, i1, i2, i0, i2, i3); else T.push(i0, i2, i1, i0, i3, i2);
  }
  return { P: new Float32Array(P), N: new Float32Array(N), M: new Uint8Array(M), T: new Uint32Array(T) };
}
module.exports = { surfaceNets };
