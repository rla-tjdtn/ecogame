// 소품 하나(파트 묶음)의 기준 좌표계: 첫 보이는 파트의 수평 방향(요) + 보이는 파트 전체 상자(그 요 기준)의 바닥 가운데.
// 서버 PropMesh.luau 의 frameOf 와 같은 계산(둘을 같이 고칠 것).
//   frameOf(parts) → { yaw, ox, oy, oz (바닥 가운데 월드 좌표), size: [x,y,z], center: [x,y,z] (월드) }
//   toLocal(frame, p) → 소품 좌표(x 오른쪽, y 위, z = 요 축의 z)
function visible(p) { return p.tr < 1 && p.tags.includes('SonarRenderable') && !(p.a && p.a.SonarShape === 'None' && false); }
function yawOf(p) {
  const X = p.cf.slice(3, 6), Y = p.cf.slice(6, 9), Z = p.cf.slice(9, 12);
  // 세계 위와 가장 가까운 축을 '위' 로 보고, 나머지 중 첫 축을 수평 기준으로
  const ups = [Math.abs(X[1]), Math.abs(Y[1]), Math.abs(Z[1])];
  const u = ups.indexOf(Math.max(...ups));
  const h = u === 0 ? Z : X; // 위가 X 면 Z 를, 아니면 X 를 기준으로
  return Math.atan2(-h[2], h[0]); // (yaw: X 축이 (cos, 0, -sin))
}
function rotY(yaw, v) { const c = Math.cos(yaw), s = Math.sin(yaw); return [v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c]; } // 로컬 → 월드 (Roblox CFrame.Angles(0,yaw,0))
function rotYinv(yaw, v) { return rotY(-yaw, v); }
function corners(p) {
  const c = p.cf.slice(0, 3), X = p.cf.slice(3, 6), Y = p.cf.slice(6, 9), Z = p.cf.slice(9, 12), h = p.s.map(x => x / 2);
  const out = [];
  for (const a of [-1, 1]) for (const b of [-1, 1]) for (const d of [-1, 1]) out.push([0, 1, 2].map(k => c[k] + X[k] * h[0] * a + Y[k] * h[1] * b + Z[k] * h[2] * d));
  return out;
}
function frameOf(parts) {
  const vis = parts.filter(visible);
  const use = vis.length ? vis : parts;
  const yaw = yawOf(use[0]);
  let mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (const p of use) for (const w of corners(p)) { const l = rotYinv(yaw, w); for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], l[k]); mx[k] = Math.max(mx[k], l[k]); } }
  const cl = [(mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2];
  const o = rotY(yaw, cl);
  return { yaw, o, size: [mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]] };
}
function toLocal(f, w) { const l = rotYinv(f.yaw, [w[0] - f.o[0], w[1] - f.o[1], w[2] - f.o[2]]); return l; }
// 파트를 소품 좌표로(cf 12개 + 크기)
function partLocal(f, p) {
  const c = toLocal(f, p.cf.slice(0, 3));
  const r = v => rotYinv(f.yaw, v);
  return { ...p, cf: [...c, ...r(p.cf.slice(3, 6)), ...r(p.cf.slice(6, 9)), ...r(p.cf.slice(9, 12))] };
}
module.exports = { frameOf, toLocal, partLocal, visible, rotY, corners };
