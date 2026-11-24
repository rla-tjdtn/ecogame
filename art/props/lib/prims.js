// 시뮬레이터가 찍은 기본 도형 파트들을 게임 규칙 그대로(상자 12모서리·SonarEdgeAxis·원통 고리+실루엣·구·Line·Disc·None)
// Model 로 옮긴다 → 바꾸기 전 모습 그리기·선 수 비교용. frame(12개 수, 소품 좌표계) 기준 로컬로.
const { Model, Xf } = require('./model.js');

function xfOf(cf) { return new Xf([cf[3], cf[4], cf[5], cf[6], cf[7], cf[8], cf[9], cf[10], cf[11], cf[0], cf[1], cf[2]]); }
function fromParts(parts, frame) {
  const m = new Model();
  const inv = frame ? xfOf(frame).inv() : new Xf();
  for (const p of parts) {
    if (p.tr >= 1) continue; // 보이지 않는 충돌 상자·소리 발생기
    const tagged = p.tags.includes('SonarRenderable');
    const shape = (p.a && p.a.SonarShape) || (p.c === 'WedgePart' ? 'Wedge' : p.sh === 'Cylinder' ? 'Cylinder' : p.sh === 'Ball' ? 'Ball' : 'Box');
    const X = inv.mul(xfOf(p.cf)); const [sx, sy, sz] = p.s;
    m.push(X);
    const none = !tagged || shape === 'None';
    if (p.sh === 'Cylinder' && p.c === 'Part') {
      const r = Math.min(sy, sz) / 2, rings = (p.a && p.a.SonarRings) || 0; const ts = []; for (let i = 1; i <= rings; i++) ts.push(i / (rings + 1));
      if (none) m.cyl([-sx / 2, 0, 0], [sx / 2, 0, 0], r, { lines: 'none' });
      else if (shape === 'Line') { m.cyl([-sx / 2, 0, 0], [sx / 2, 0, 0], r, { lines: 'none' }); m.line([[-sx / 2, 0, 0], [sx / 2, 0, 0]]); }
      else if (shape === 'Disc') { m.cyl([-sx / 2, 0, 0], [sx / 2, 0, 0], r, { caps: false, silhouette: false, rings: [0.5] }); }
      else m.cyl([-sx / 2, 0, 0], [sx / 2, 0, 0], r, { rings: ts });
    } else if (p.sh === 'Ball' && p.c === 'Part') {
      m.sphere([0, 0, 0], Math.min(sx, sy, sz) / 2, { lines: none ? 'none' : 'all' });
    } else if (p.c === 'WedgePart' || p.sh === 'Wedge') {
      m.push(new Xf([0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0]));
      m.extrude([[-sz / 2, -sy / 2], [sz / 2, -sy / 2], [sz / 2, sy / 2]], sx, { lines: none ? 'none' : 'all', crease: 1 });
      m.pop();
    } else {
      const axis = p.a && p.a.SonarEdgeAxis;
      if (shape === 'Line') { m.box([0, 0, 0], p.s, { lines: 'none' }); const L = Math.max(sx, sy, sz); const d = sx === L ? [L / 2, 0, 0] : sy === L ? [0, L / 2, 0] : [0, 0, L / 2]; m.line([[-d[0], -d[1], -d[2]], d]); }
      else if (shape === 'Disc') { m.box([0, 0, 0], p.s, { lines: 'none' }); }
      else m.box([0, 0, 0], p.s, { lines: none ? 'none' : (axis || 'all') });
    }
    m.pop();
  }
  return m;
}
module.exports = { fromParts, xfOf };
