# 음파 미로 (SonarMaze) — Roblox 1인칭 협동 공포 미로 탈출

완전한 어둠 속에서 좌클릭으로 음파를 쏘면, 음파가 퍼져 나가며 닿은 구조물의 **모서리만 얇은 흰 선**으로 잠깐(약 2초) 드러납니다.
괴물은 음파와 발소리를 듣고 찾아옵니다. 1~4인, 스테이지 5개(지하 시설 · 물류 창고 · 하수도 · 폐병원 · 심층 미로).

## 열기 / 실행

1. `build/SonarMaze.rbxlx`를 Roblox Studio로 엽니다.
2. **Test → Play**(혼자) 또는 **Test → Clients and Servers**(2~4명).
3. 게시: **File → Publish to Roblox**.

코드를 고친 뒤 다시 빌드합니다.

```powershell
rojo build default.project.json -o build/SonarMaze.rbxlx
```

Studio를 열어 둔 채로 바로 반영하려면 `rojo serve`를 켜고 Studio의 Rojo 플러그인에서 Connect를 누릅니다.
맵은 플레이를 시작할 때 서버가 코드로 짓습니다(편집 모드 Workspace에는 맵이 없습니다).

## 조작

| 키 | 동작 |
|---|---|
| W A S D / 마우스 | 이동 / 시점(1인칭 고정) |
| 좌클릭 | 음파 (1.5초 간격) · 관전 중에는 관전 대상 변경 |
| Shift | 달리기 18 (발소리 25스터드) |
| Ctrl | 웅크리기 5 (발소리 4스터드) · 둘 다 누르면 웅크리기 |
| E | 문 열기/닫기 |

## 음파 렌더링 방식 (엔진 제약과 선택)

Roblox에는 사용자 셰이더가 없어 화면 공간 외곽선을 쓸 수 없습니다. 그래서:

1. **모서리 데이터** (`src/shared/SonarGeometry.luau`, `src/client/SonarWorld.luau`)
   스테이지가 로드되면 `SonarRenderable` 태그가 붙은 파트에서 모양별 모서리를 한 번만 만듭니다.
   - 상자 12개 모서리, 쐐기 9개, 원통은 양 끝 원 + **보는 위치 기준 실루엣 2줄**, 구는 실루엣 원
   - 같은 평면으로 이어지는 이음매(벽 조각 사이, 바닥 조각 사이)와 다른 파트 속에 묻힌 모서리는 제거
   - MeshPart/Union은 상자 프록시. 속성 `SonarShape`(Box/Cylinder/Ball/Wedge/None), `SonarEdgeAxis`(한 축 모서리만), `SonarRings`(원통 중간 원)로 조정
2. **음파 전파** (`src/client/SonarPulses.luau`)
   맵을 2스터드 복셀로 칠한 점유 격자 위에서 Dijkstra로 파동을 퍼뜨립니다. 파면 = 경과시간 × 40스터드/초.
   벽은 통과하지 못하고 열린 통로·문으로만 돌아 들어가며, 닫힌 문은 막습니다(열고 닫을 때 격자 갱신).
   카메라 쪽 가림은 검은 벽이 깊이 버퍼로 자연스럽게 처리합니다.
3. **선 그리기** (`src/client/SonarLines.luau`)
   얇은 Neon 파트 풀(최대 4500개)을 재사용합니다. 선은 흰색 → 검정으로 **색이 바래며** 사라집니다
   (배경이 검정이라 검정 Neon은 안 보이고, 불투명 파트라 투명 파트보다 훨씬 가볍습니다).
   같은 선분이 다시 음파를 받으면 새로 만들지 않고 타이머만 갱신 → 반복 발사해도 쌓이지 않습니다.
   괴물·문·다른 플레이어는 음파가 닿는 순간의 모습으로 선이 남습니다.

## 폴더 구조

```
default.project.json            Rojo 프로젝트(조명 0, 1인칭 고정, RemoteEvent 4개)
src/shared/   → ReplicatedStorage.Shared
  Config.luau                   모든 수치(음파·이동·소음 범위·괴물·스테이지·사운드)
  SonarGeometry.luau            모양별 모서리 생성
src/server/   → ServerScriptService.Server
  Main.server.luau              어둠 강제, 음파 검증(간격·생존·위치는 서버가 결정), 이동 모드
  Round.luau                    스테이지 진행, 사망/탈출/관전, 출구 판정, 발소리 소음(서버가 실제 속도로 판정)
  SoundBus.luau                 소리 이벤트 → 괴물 (거리 + 벽 감쇠, heardRange 하나만 바꾸면 전파 방식 교체)
  Monster.luau                  괴물 모델 + AI(배회→멈칫→조사→수색→추격→놓침), PathfindingService
  Doors.luau                    문(E), 괴물은 다가가면 연다
  MapKit.luau                   모듈형 부품(벽·배관·플랜지·난간·계단·아치·상자·EXIT 글자…)
  Props.luau                    스테이지 소품(선반·컨테이너·수로·대형 배관·침대·책상·수술대·캐비닛)
  StageBuilder.luau             타일 레이아웃 → 지형
  Stages/Stage1~5.luau          레이아웃(문자 격자)
  TestHarness.server.luau       자동 테스트(Studio 테스트 실행 때만 동작)
src/client/   → StarterPlayerScripts
  Main.client.luau              입력, 음파, 스테이지 로드, 관전, 결과 화면
  SonarWorld / SonarPulses / SonarLines   위 렌더링
  Movement.luau                 걷기/달리기/웅크리기, 헤드밥, 추격 긴장감
  Audio.luau                    발소리·음파·문·괴물·환경음(전부 클라이언트, 3D)
  UI.luau                       조준점, 음파 대기 막대, 스테이지 이름, 안내, YOU DIED / STAGE CLEAR
  RbxCharacterSounds.client.luau  기본 캐릭터 소리 끄기(빈 스크립트)
```

RemoteEvent (`ReplicatedStorage.Remotes`): `SonarFire`(클→서), `SonarPulse`(서→다른 클라이언트), `SetMoveMode`(클→서), `RoundEvent`(서→클).

## 스테이지 만들기·고치기

`src/server/Stages/StageN.luau`의 `Rows`가 맵입니다(1칸 = 8스터드, 천장 14, 아래층 -6).

`#` 벽 · `.` 바닥 · `S` 시작 · `E` 출구 · `D` 문 · `A` 아치 · `O` 기둥 · `c` 상자 · `m` 기계 · `v` 수직 배관 · `f` 환풍기 ·
`p` 구덩이(아래층) · `b` 다리 · `n` 좁은 다리(괴물 못 건넘) · `s` 계단 — 스테이지별 소품 문자는 각 파일 `Props`에.

고친 뒤 `node tools/check-layout.js`로 문/아치 위치, 계단, 출구 입구 수, 시작→출구 연결을 확인합니다.

## 사운드

외부 에셋 ID는 넣지 않았습니다. 기본값은 Roblox 클라이언트에 들어 있는 `rbxasset://sounds/*` 파일(발소리, 착지음 등)을
피치를 바꿔 쓴 **임시 소리**입니다. `Config.Sounds`의 `Id`를 직접 고른 `rbxassetid://…`로 바꾸면 교체됩니다(빈 문자열이면 재생 안 함).

## 자동 테스트

```powershell
node tools/studio-test.js core 300
```

`tools/SonarTestRunner.plugin.lua`를 Studio 플러그인 폴더에 설치하고, 열린 SonarMaze Studio에서 실제 플레이를 돌려 결과를 출력합니다.
`core`(1인 전체), `stages`(스테이지 1~5 빌드), `perf`(스크립트 비용), `PLAYERS=4 … multi`(4인). 테스트 플레이어는 모두 음소거됩니다.
오류 로그는 `node tools/studio-errors.js`.
