# 챕터 괴물 게임 구현 가이드

본보기: `src/server/Creatures/c7n.luau`(서버: 몸·뼈·규칙) + `src/client/Creatures/c7n.luau`(클라이언트: 애니메이션). Studio 테스트 8/8 통과.

## 파일 (괴물 하나 = 파일 두 개, 다른 파일은 건드리지 않음)
- `src/server/Creatures/<id>.luau`
  - `M.cfg` = { WanderSpeed, InvestigateSpeed, ChaseSpeed, AgentRadius, AgentHeight, CatchDistance, ... } (없는 값은 Config.Monster 기본)
  - `M.spawnLift` 스폰 높이(스터드), `M.voice` 소리 키(Config.MonsterVoices 키, 전용 소리 전까지 기존 "1"~"5" 중 어울리는 것)
  - `M.build(cf): Model` — `Rig.shell(name, cf, rootSize)` → 선·공 목록 → `Rig.build(model, root, cf, def)` → `Rig.humanoid(model, hip, speed)` → return model
    - 루트 가운데 높이 = hip + 1, 그러니 `floorY = -(hip + 1)`. 모든 좌표는 루트 기준, 앞 = -Z, 오른쪽 = +X.
    - `bones`: 사양서의 고유 뼈대(부모 먼저). `lines`: { bone, a, b, r, red? } 원통 — 음파에는 긴 원통 = 가운데 선 1줄(굵기 안 보임), 짧은 원통(길이 < r×4) = 고리, 공 = 원. 몸의 부피는 윤곽선 두 줄·고리·공으로 만든다 / `balls`: { bone, c, r }
    - 선분 예산 40~120(lines + balls). 붉은 선(red = true)은 한 곳만.
  - 선택: `M.init(self)`, `M.tick(self, now): boolean`(true = 기본 AI 건너뜀), `M.hear(self, pos, radius, source, kind): boolean`
    - self.hum, self.root, self.model, self.state, self.target, self.cfg, self.cdata(자유 저장), self:setState(s), self.hum:MoveTo(p)
    - 클라이언트에 동작을 알릴 땐 `self.model:SetAttribute("이름", 값)`(서버 시계 대신 값 변경으로 알림)
- `src/client/Creatures/<id>.luau`
  - `M.init(b)`, `M.step(b, dt)` — `CreatureAnim.pose(b, 뼈이름, rx, ry, rz, offset?)` 로 뼈를 쉬는 자세 기준으로 돌림
  - b.speed(수평 속도), b.vel(루트 기준 속도, 앞 = -Z), b.state, b.t, b.data, b.model, b.root, `b.step(위치, 세기)` = 착지(걸음 소리)
  - 도구: `CreatureAnim.wave(p)`, `CreatureAnim.lift(p, duty)`, `CreatureAnim.approach(cur, target, rate, dt)`

## 원칙
- 공용 두 팔·두 다리 skeleton()·MonsterAnim 사용 금지. 괴물마다 사양서의 뼈대·이동 방식 그대로.
- 사람형 = 두 발로 체중 이동(골반 좌우·위아래, 발 디딤에서 b.step). 비인간형 = 사양서의 자기 방식.
- 미끄러짐 줄이기: 보행 위상을 이동 거리에 묶는다(phase += speed * dt / 보폭).
- 게임이 늘 돌아가야 한다: Config.Creatures.On 은 건드리지 않는다(검수 통과 후 아트 디렉터가 켬).

## 확인
- 린트: `node <scratchpad>/analyze.js` → 0 issue
- Studio(아트 디렉터만, 한 번에 하나): `CREATURE=<id> node tools/studio-test.js creature 240`
