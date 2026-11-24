// MapKit 공용 구조물 메시(모든 챕터): 배관 플랜지, 난간, 계단, 나무 상자, EXIT 표지, 아치 리브.
// (곧은 배관 몸통은 원통 기본 도형 그대로: 메시로 바꿔도 모양·선이 똑같고 파트만 는다)
const { T, Rx, Ry, Rz, roundRect, arc2 } = require('../lib/model.js');

// 플랜지: 원점 = 플랜지 가운데, -z = 배관 진행 방향. 기준 반지름 1(dress 가 (fr, fr, 1) 로 늘린다)
function flange(m, bolts) {
  // 두 장 맞붙은 플랜지(가운데 이음 홈) + 양쪽 배관 목(허브)
  m.cyl([0, 0, 0.18], [0, 0, 0.02], 1, { seg: 24 });
  m.cyl([0, 0, -0.02], [0, 0, -0.18], 1, { seg: 24 });
  m.cone([0, 0, 0.18], [0, 0, 0.34], 0.86, 0.76, { seg: 20, caps: false, silhouette: false, lines: 'none' });
  m.cone([0, 0, -0.18], [0, 0, -0.34], 0.86, 0.76, { seg: 20, caps: false, silhouette: false, lines: 'none' });
  if (bolts) for (let i = 0; i < 6; i++) {
    const a = i / 6 * Math.PI * 2 + 0.3, x = Math.cos(a) * 0.83, y = Math.sin(a) * 0.83;
    m.cyl([x, y, 0.42], [x, y, -0.42], 0.07, { line: true });
    // 너트(작은 육각 머리) 양쪽: 가로 짧은 선
    for (const z of [0.24, -0.24]) m.box([x, y, z], [0.2, 0.2, 0.1], { lines: 'none', solid: false });
  }
}

// 난간: 원점 = 시작 기둥 바닥, -z = 끝 쪽. 길이 L, 기둥 n 개(같은 간격), 높이 3.3
function railing(m, L, posts, rise) {
  const h = 3.3;
  const P = t => [0, (rise || 0) * t, -L * t]; // 바닥 높이를 따라(계단 난간은 경사)
  for (let i = 0; i < posts; i++) {
    const t = posts === 1 ? 0 : i / (posts - 1), p = P(t);
    m.box([p[0], p[1] + h / 2, p[2]], [0.16, h, 0.16], { lines: 'none' });
    m.line([[p[0], p[1] + 0.06, p[2]], [p[0], p[1] + h - 0.1, p[2]]]);
    m.box([p[0], p[1] + 0.03, p[2]], [0.5, 0.06, 0.5], { lines: 'top', solid: false }); // 바닥 판
  }
  const a = P(0), b = P(1);
  m.cyl([a[0], a[1] + h, a[2] + 0.12], [b[0], b[1] + h, b[2] - 0.12], 0.1, { seg: 12 }); // 손잡이(둥근 관)
  m.cyl([a[0], a[1] + h * 0.52, a[2]], [b[0], b[1] + h * 0.52, b[2]], 0.06, { line: true }); // 중간 가로대
  if (!rise) m.box([0, 0.22, -L / 2], [0.05, 0.3, L], { lines: 'Z', solid: false }); // 발끝 막이
}

module.exports = {
  'Kit.PipeFlange': (m) => flange(m, false),
  'Kit.PipeFlangeBolted': (m) => flange(m, true),

  // 평지 난간: 길이 8 기준(기둥 4) / 짧은 것 3.4 기준(기둥 2) / 계단 경사(가로 8, 높이 6, 기둥 4). dress 가 길이를 늘린다
  'Kit.Railing': (m) => railing(m, 8, 4, 0),
  'Kit.RailingShort': (m) => railing(m, 3.4, 2, 0),
  'Kit.RailingSlope': (m) => railing(m, 8, 4, 6),

  // 계단: 원점 = 첫 계단 앞 가운데 바닥, -z = 올라가는 쪽. 폭 6, 높이 6, 길이 8, 8단.
  // 콘크리트 계단: 옆에서 본 톱니 단면을 폭만큼 밀어낸 몸 + 디딤판 앞 끝(논슬립) 선 + 양옆 벽 쪽 걸레받이 띠
  'Kit.Stairs': (m) => {
    const n = 8, W = 6, rise = 6, run = 8, sh = rise / n, sd = run / n;
    // 단면(z-y 평면 → extrude 의 x=z', y=y): 앞(z=0) 아래에서 시작해 계단 따라 위로, 뒤 끝에서 바닥으로
    const prof = [[0, 0]];
    for (let i = 0; i < n; i++) { prof.push([-i * sd, (i + 1) * sh]); prof.push([-(i + 1) * sd, (i + 1) * sh]); }
    prof.push([-run, 0]);
    // extrude 는 xy 다각형을 z 로 민다 → (단면 x = 계단 z, 단면 y = 높이, 미는 방향 = 계단 x)
    m.with(new (require('../lib/model.js').Xf)([0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0]), () => m.extrude(prof, W, { crease: 20 }));
    // 논슬립(디딤판 앞 끝에서 조금 안쪽 홈)
  },

  // 나무 상자: 원점 = 바닥 가운데, 3×3×3 기준(dress 가 크기에 맞춰 늘린다). 둘레 각재 + 대각 버팀 + 판자 이음
  'Kit.Crate': (m) => {
    const s = 3, h = s / 2, f = 0.28; // f = 테두리 각재 폭
    m.box([0, h, 0], [s, s, s], { bevel: 0.05 });
    // 앞·뒤·옆 네 면: 안쪽 테두리 사각 + 대각선 + 판자 이음 2줄
    const face = (xf) => m.with(xf, () => {
      const e = 0.01;
      m.line([[-h + f, f, e], [h - f, f, e], [h - f, s - f, e], [-h + f, s - f, e]], { closed: true });
      m.line([[-h + f, f, e], [h - f, s - f, e]]);
    });
    face(T(0, 0, h)); face(T(0, 0, -h).mul(Ry(Math.PI))); face(T(h, 0, 0).mul(Ry(Math.PI / 2))); face(T(-h, 0, 0).mul(Ry(-Math.PI / 2)));
    // 뚜껑: 판자 이음 3줄
    for (const x of [-0.75, 0, 0.75]) m.line([[x, s + 0.01, -h + f], [x, s + 0.01, h - f]]);
  },

  // EXIT 표지: 원점 = 글자 가운데, x = 읽는 방향(보는 사람의 오른쪽), +z = 벽 밖(보는 사람 쪽). 글자 높이 1.4 기준
  'Kit.Exit': (m) => {
    const hgt = 1.4, w = hgt * 0.62, gap = hgt * 0.3, total = 4 * w + 3 * gap;
    // 표지 상자(얇은 판, 둥근 모서리) — 앞 윤곽 한 줄
    m.with(T(0, 0, 0.05), () => m.extrude(roundRect(total + 0.7, hgt + 0.6, 0.15, 1), 0.2, { caps: 'front' }));
    const z = 0.17, x0 = -total / 2, y0 = -hgt / 2, t = 0.1;
    const L = (pts) => m.line(pts.map(([x, y]) => [x, y, z]));
    let x = x0;
    // E
    L([[x + w, y0 + hgt - t], [x + t, y0 + hgt - t], [x + t, y0 + t], [x + w, y0 + t]]); L([[x + t, y0 + hgt / 2], [x + w * 0.8, y0 + hgt / 2]]); x += w + gap;
    // X
    L([[x + t, y0 + t], [x + w - t, y0 + hgt - t]]); L([[x + t, y0 + hgt - t], [x + w - t, y0 + t]]); x += w + gap;
    // I
    L([[x + w / 2, y0 + t], [x + w / 2, y0 + hgt - t]]); x += w + gap;
    // T
    L([[x + t, y0 + hgt - t], [x + w - t, y0 + hgt - t]]); L([[x + w / 2, y0 + hgt - t], [x + w / 2, y0 + t]]);
  },

  // 아치 리브(석조): 원점 = 바닥 가운데, x = 가로, z = 깊이 방향(두께 1.4). 폭 8, 기둥 폭 0.7, 스프링 높이 6, 고리 두께 0.7.
  // 홍예석(쐐기돌) 9개 + 튀어나온 이맛돌 + 기둥머리 받침돌 + 기둥 아래 굽. 고리 위 벽은 기본 도형 그대로(평면)
  'Kit.Arch': (m) => {
    const span = 8, pier = 0.7, spring = 6, ring = 0.7, depth = 1.4;
    const inner = span / 2 - pier, outer = inner + ring, d2 = depth / 2;
    m.mirrorX(() => {
      const x = span / 2 - pier / 2;
      m.box([x, spring / 2, 0], [pier, spring, depth], { lines: 'Y' });
      m.box([x, 0.25, 0], [pier + 0.2, 0.5, depth + 0.2], { lines: 'top' }); // 굽
      m.box([x - 0.05, spring - 0.15, 0], [pier + 0.3, 0.3, depth + 0.16], { lines: 'all' }); // 받침돌
    });
    // 고리: 앞·뒤 면 윤곽(안쪽·바깥 반원) + 쐐기돌 이음(방사선) — 몸은 고리 모양 다각형을 깊이만큼
    const n = 9, segs = 10;
    const poly = [...arc2(0, 0, outer, 0, Math.PI, segs), ...arc2(0, 0, inner, Math.PI, 0, segs)];
    m.with(T(0, spring, 0), () => {
      m.extrude(poly, depth, { sides: false, crease: 50 });
      for (let i = 1; i < n; i++) {
        const a = i / n * Math.PI; const c = Math.cos(a), s = Math.sin(a);
        for (const z of [d2 + 0.005]) m.line([[c * inner, s * inner, z], [c * outer, s * outer, z]]);
      }
      // 이맛돌(가운데 쐐기돌이 살짝 튀어나옴)
      const ak = Math.PI / 2, w = Math.PI / n / 2;
      const kp = [[Math.cos(ak - w) * (inner - 0.05), Math.sin(ak - w) * (inner - 0.05)], [Math.cos(ak - w) * (outer + 0.15), Math.sin(ak - w) * (outer + 0.15)], [Math.cos(ak + w) * (outer + 0.15), Math.sin(ak + w) * (outer + 0.15)], [Math.cos(ak + w) * (inner - 0.05), Math.sin(ak + w) * (inner - 0.05)]];
      m.extrude(kp, depth + 0.2, { crease: 30 });
    });
    // 고리 옆 채움(스팬드럴) — 선 없음, 몸만(고리 위 수평선 = 바깥 반원 꼭대기 높이까지)
    m.mirrorX(() => m.extrude([[outer, 0], [outer, outer], [0, outer], ...arc2(0, 0, outer, Math.PI / 2, 0, 9).slice(1, -1)].map(([x, y]) => [x, y + spring]), depth * 0.55, { lines: 'none' }));
  },
  // ── StageBuilder 타일 구조물 ──
  // 콘크리트 기둥(O): 원점 = 바닥 가운데, 높이 14 기준(dress 가 y 를 늘린다). 모따기 기둥 + 굽(받침) + 위 드롭 패널(넓어지는 머리)
  'Kit.Pillar': (m) => {
    const H = 14;
    m.box([0, H / 2, 0], [2.4, H, 2.4], { bevel: 0.12, lines: 'Y' });
    m.box([0, 0.4, 0], [3.4, 0.8, 3.4], { bevel: 0.08, lines: 'top' });
    m.lathe([[1.2, H - 1.5], [1.6, H - 1.0], [1.6, H]], { seg: 4, lines: 'none' }); // (몸만: 사각 머리로 넓어짐)
    m.box([0, H - 0.6, 0], [3.2, 1.2, 3.2], { bevel: 0.06, lines: 'XZ' });
    // 기둥 표면: 거푸집 이음 2줄(가로) + 철근 노출 흠집(짧은 사선)
    for (const y of [4.6, 9.2]) m.line([[-1.2, y, 1.205], [1.2, y, 1.205], [1.2, y, -1.205]]);
    m.line([[0.3, 2.2, 1.21], [0.75, 2.9, 1.21], [0.55, 3.3, 1.21]]);
  },

  // 기계(m): 원점 = 바닥 가운데. 받침 철골(스키드) 위 전동기(냉각 핀 원통) + 펌프 몸통(소용돌이 꼴) + 제어함 + 배관 받침 둘
  'Kit.Machine': (m) => {
    // 스키드: ㄷ자 강철 두 줄 + 가로대 + 앵커 볼트 판
    for (const z of [-1.9, 1.9]) m.box([0, 0.4, z], [5.4, 0.8, 0.35], { lines: 'none' });
    for (const x of [-2.5, 0, 2.5]) m.box([x, 0.4, 0], [0.35, 0.8, 3.5], { lines: 'none' });
    m.box([0, 0.78, 0], [5.4, 0.06, 4.2], { lines: 'all', solid: false });
    // 전동기: x 축 원통(반지름 1.45) + 냉각 핀(고리 3) + 끝 덮개(돔)
    m.cyl([-2.4, 2.35, 0], [-0.3, 2.35, 0], 1.45, { seg: 24 });
    m.box([-1.35, 1.05, 0], [1.8, 0.55, 2.4], { lines: 'XZ' }); // 전동기 발
    // 펌프 몸통: 짧은 원통(소용돌이) + 토출구
    m.cyl([-0.3, 2.4, 0], [1.2, 2.4, 0], 1.6, { seg: 24, caps: false, rings: [1] });
    m.box([0.45, 3.75, 0], [0.9, 0.9, 0.9], { lines: 'Y' });
    // 제어함: 문 윤곽 + 손잡이 + 계기 둘
    m.box([1.9, 1.9, 0], [1.0, 2.2, 1.6], { bevel: 0.05 });
    m.line([[2.41, 1.0, -0.65], [2.41, 1.0, 0.65], [2.41, 2.8, 0.65], [2.41, 2.8, -0.65]], { closed: true });
    m.cyl([2.42, 2.4, -0.3], [2.5, 2.4, -0.3], 0.18, { caps: false, silhouette: false, rings: [0.5] });
    m.cyl([2.42, 2.4, 0.3], [2.5, 2.4, 0.3], 0.18, { caps: false, silhouette: false, rings: [0.5] });
    m.cyl([2.42, 1.6, 0.5], [2.6, 1.6, 0.5], 0.05, { line: true });
    // 배관 받침(위 큰 배관을 받치는 두 기둥 + 반원 띠)
    for (const x of [-1.8, 1.0]) m.box([x, 4.4, 0], [0.4, 1.0, 2.2], { lines: 'Y' });
  },

  // 천장 환풍기(f): 원점 = 천장 높이의 가운데(아래로 매달림, y 는 0 에서 -1.2). 둥근 하우징 + 격자 + 날개 넷
  'Kit.CeilingFan': (m) => {
    m.cyl([0, -1.2, 0], [0, 0, 0], 2.4, { seg: 28, caps: false });
    m.torus([0, -1.2, 0], [0, 1, 0], 2.35, 0.1, { seg: 28, ringsAt: [2.4] });
    m.cyl([0, -1.0, 0], [0, -0.2, 0], 0.5, { seg: 14 }); // 허브(모터)
    for (let k = 0; k < 4; k++) {
      const a = k * Math.PI / 2 + 0.4;
      m.with(T(Math.cos(a) * 1.25, -0.95, Math.sin(a) * 1.25).mul(Ry(-a)).mul(Rx(0.35)), () => m.extrude([[-0.7, -0.35], [0.75, -0.42], [0.85, 0], [0.75, 0.42], [-0.7, 0.35]], 0.06, { caps: 'front', lines: 'all' }));
    }
    // 아래 보호 격자: 십자 막대 + 안쪽 고리
    m.line([[-2.3, -1.15, 0], [2.3, -1.15, 0]]); m.line([[0, -1.15, -2.3], [0, -1.15, 2.3]]);
    m.torus([0, -1.15, 0], [0, 1, 0], 1.3, 0.03, { seg: 20, ringsAt: [1.3] });
  },

  // 출구 사다리 + 천장 해치(E): 원점 = 사다리 아래 가운데(바닥), -z = 벽 쪽, 높이 14 기준(y 를 늘린다)
  'Kit.ExitLadder': (m) => {
    const H = 14;
    for (const x of [-0.7, 0.7]) { m.box([x, H / 2, 0], [0.14, H, 0.3], { lines: 'none' }); m.line([[x, 0, -0.16], [x, H, -0.16]]); m.line([[x, 0, 0.16], [x, H, 0.16]]); }
    for (let y = 1; y <= H - 1; y += 1.2) m.cyl([-0.7, y, 0], [0.7, y, 0], 0.05, { line: true });
    for (const y of [3, 8, 12.5]) m.mirrorX(() => m.box([0.7, y, -0.45], [0.12, 0.12, 0.6], { lines: 'Z' })); // 벽 고정쇠(벽 = -z 0.6)
    // 해치: 천장 테두리 사각 틀 + 반쯤 열린 뚜껑
    m.with(T(0, H - 0.2, -0.4), () => { // (해치 = 사다리에서 벽 쪽으로 0.4)
      m.line([[-1.4, 0, -1.4], [1.4, 0, -1.4], [1.4, 0, 1.4], [-1.4, 0, 1.4]], { closed: true });
      m.box([0, -0.1, 1.4], [3.0, 0.4, 0.3], { lines: 'X' }); m.box([0, -0.1, -1.4], [3.0, 0.4, 0.3], { lines: 'X' });
      m.box([1.4, -0.1, 0], [0.3, 0.4, 3.0], { lines: 'Z' }); m.box([-1.4, -0.1, 0], [0.3, 0.4, 3.0], { lines: 'Z' });
      m.with(T(0, 0, -1.3).mul(Rx(-0.5)), () => m.box([0, -0.05, 1.3], [2.6, 0.1, 2.6], { lines: 'all', solid: false }));
    });
  },
  'Kit.Catwalk5': (m) => {
    const w = 5, L = 8;
    // 격자 바닥판(테두리 + 가로 띠) + 양옆 I 형강 보 + 아래 가로보. 원점 = 칸 가운데 바닥(다리 윗면 y = 0), -z = 다리 방향
    m.box([0, -0.25, 0], [w, 0.5, L], { lines: 'XZ' });
    for (let z = -L / 2 + 1.33; z < L / 2 - 0.5; z += 1.33) m.line([[-w / 2 + 0.35, 0.005, z], [w / 2 - 0.35, 0.005, z]]);
    for (const s of [-1, 1]) {
      const x = s * (w / 2 - 0.3);
      m.box([x, -0.9, 0], [0.4, 0.8, L], { lines: 'Z' }); // (I 형강: 윤곽 4줄)
    }
    m.box([0, -1.0, 0], [w, 0.6, 0.4], { lines: 'X' });
    
  },
  'Kit.Catwalk5C': (m) => {
    const w = 5, L = 8;
    // 격자 바닥판(테두리 + 가로 띠) + 양옆 I 형강 보 + 아래 가로보 + 아래 기둥 둘. 원점 = 칸 가운데 바닥(다리 윗면 y = 0), -z = 다리 방향
    m.box([0, -0.25, 0], [w, 0.5, L], { lines: 'XZ' });
    for (let z = -L / 2 + 1.33; z < L / 2 - 0.5; z += 1.33) m.line([[-w / 2 + 0.35, 0.005, z], [w / 2 - 0.35, 0.005, z]]);
    for (const s of [-1, 1]) {
      const x = s * (w / 2 - 0.3);
      m.box([x, -0.9, 0], [0.4, 0.8, L], { lines: 'Z' }); // (I 형강: 윤곽 4줄)
    }
    m.box([0, -1.0, 0], [w, 0.6, 0.4], { lines: 'X' });
    for (const s of [-1, 1]) { const x = s * (w / 2 - 0.3); m.box([x, (-6 - 1.3) / 2, 0], [0.5, 4.7, 0.5], { lines: 'Y', bevel: 0.03 }); m.box([x, -5.9, 0], [0.9, 0.2, 0.9], { lines: 'top' }); }
  },
  'Kit.Catwalk3': (m) => {
    const w = 3.2, L = 8;
    // 격자 바닥판(테두리 + 가로 띠) + 양옆 I 형강 보 + 아래 가로보. 원점 = 칸 가운데 바닥(다리 윗면 y = 0), -z = 다리 방향
    m.box([0, -0.25, 0], [w, 0.5, L], { lines: 'XZ' });
    for (let z = -L / 2 + 1.33; z < L / 2 - 0.5; z += 1.33) m.line([[-w / 2 + 0.35, 0.005, z], [w / 2 - 0.35, 0.005, z]]);
    for (const s of [-1, 1]) {
      const x = s * (w / 2 - 0.3);
      m.box([x, -0.9, 0], [0.4, 0.8, L], { lines: 'Z' }); // (I 형강: 윤곽 4줄)
    }
    m.box([0, -1.0, 0], [w, 0.6, 0.4], { lines: 'X' });
    
  },
  'Kit.Catwalk3C': (m) => {
    const w = 3.2, L = 8;
    // 격자 바닥판(테두리 + 가로 띠) + 양옆 I 형강 보 + 아래 가로보 + 아래 기둥 둘. 원점 = 칸 가운데 바닥(다리 윗면 y = 0), -z = 다리 방향
    m.box([0, -0.25, 0], [w, 0.5, L], { lines: 'XZ' });
    for (let z = -L / 2 + 1.33; z < L / 2 - 0.5; z += 1.33) m.line([[-w / 2 + 0.35, 0.005, z], [w / 2 - 0.35, 0.005, z]]);
    for (const s of [-1, 1]) {
      const x = s * (w / 2 - 0.3);
      m.box([x, -0.9, 0], [0.4, 0.8, L], { lines: 'Z' }); // (I 형강: 윤곽 4줄)
    }
    m.box([0, -1.0, 0], [w, 0.6, 0.4], { lines: 'X' });
    for (const s of [-1, 1]) { const x = s * (w / 2 - 0.3); m.box([x, (-6 - 1.3) / 2, 0], [0.5, 4.7, 0.5], { lines: 'Y', bevel: 0.03 }); m.box([x, -5.9, 0], [0.9, 0.2, 0.9], { lines: 'top' }); }
  },
};
