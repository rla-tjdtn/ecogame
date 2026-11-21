# 음파 미로 (SonarMaze) — Roblox 1인칭 협동 공포 미로 탈출

완전한 어둠 속에서 좌클릭으로 음파를 쏘면, 음파가 퍼져 나가며 닿은 구조물의 **모서리만 얇은 흰 선**으로 잠깐(약 3.5초) 드러납니다.
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
| E | 문 열기/닫기 · 캐비닛/옷장에 숨기/나오기 |
| Q | 지도 열기/닫기 |
| Tab | (로비) 방 메뉴 열기/닫기 — 마우스가 풀린다 |

## 로비와 방

서버에 들어오면 로비(어두운 홀, 음파로 본다)에서 시작합니다. Tab으로 방 메뉴를 열어 **방 만들기 / 참가 / 나가기**,
방장은 **시작**(방 하나 최대 4명, `Config.Lobby`). 방장이 나가면 다음 사람이 방장이 됩니다.

- 게시된 게임: 시작하면 그 방 사람들이 새 예약 서버로 텔레포트되어 방마다 따로 플레이합니다(`TeleportService`).
  예약 서버는 들어오자마자 게임으로 시작합니다.
- Studio(텔레포트 불가): 같은 서버에서 그 방 사람들만 참가자로 시작하고, 다섯 스테이지를 모두 깨면 로비로 돌아옵니다.
- 코드: `src/server/Lobby.luau`(방·시작·모드 결정), `src/client/LobbyUI.luau`, 로비 맵 `src/server/Stages/Lobby.luau`.

## 지도(Q)

검은 바탕에 벽 윤곽을 흰 선으로, 내 위치는 빨간 칸으로 보여 줍니다. **나와 팀원의 음파가 닿은 칸**이 그려지고 그 스테이지가 끝날 때까지 남습니다
(게임 화면의 선은 그대로 사라집니다 — 팀원의 음파 선은 게임 화면에서도 함께 보입니다). 팀원은 흰 테두리 칸으로 표시됩니다. 출구는 음파가 닿았을 때만 표시됩니다.
코드: `src/client/MapView.luau`, 격자는 서버가 스테이지 폴더 속성 `Rows`로 보냅니다.

## 괴물

손으로 그린 듯한 가는 선 몸(챕터마다 머리 모양이 다름). 몸은 완전히 투명해서 **음파를 맞을 때만** 보입니다. 막대는 음파에 한 획(`SonarShape = Line`), 눈·둥근 머리 같은 얇은 원판은 원 하나(`Disc`)로 그려집니다.
아주 천천히 움직입니다(배회 3.5 · 조사 5.5 · 추격 8.5 — 걷기 10보다 느림). 걸을 때 팔다리를 흔듭니다. 괴물이 연 문 소리에는 반응하지 않습니다.
배회하다가 `Config.Monster.HuntEvery`(25초)마다 한 번은 숨지 않은 플레이어 근처(`HuntRadius` 40스터드)로 가서, 큰 맵에서도 마주치게 됩니다.

## 열쇠

스테이지마다 뒤질 수 있는 상자·서랍(맵 문자 `Z`, 8~10곳)이 있고, 그중 한 곳에 열쇠가 있습니다(라운드마다 서버가 시작에서 먼 쪽 절반 중 무작위).
**열쇠를 찾아야 출구가 열립니다** — 누가 찾든 팀 전체가 가집니다(오른쪽 위 표시). E로 뒤지면 서랍이 빠지거나 뚜껑이 젖혀지고, 뒤지는 소리(10스터드)를 괴물이 듣습니다.
챕터별 모양(`SearchStyle`): 철제 서랍장 · 나무 상자 · 공구함 · 협탁 · 궤짝. 코드: `src/server/Search.luau`, `src/client/KeyHUD.luau`.

## 잡혔을 때

괴물에게 잡히면 그 스테이지 괴물의 얼굴(흰 선, 챕터별 머리 모양)이 화면 가득 튀어나오며 흔들린다(점프스케어, 약 0.9초) — 그다음 YOU DIED. 코드: src/client/JumpScare.luau.

## 숨는 곳

맵 문자 `L`. 챕터마다 모양이 다릅니다(`HideStyle`): 지하 시설 철제 사물함 · 창고 공구 캐비닛 · 하수도 찌그러진 정비 사물함 ·
폐병원 병실 옷장 · 심층 미로 낡은 벽장. 스테이지마다 8~14곳, 어울리는 방(병실·기계실·사무실 등)과 막다른 통로 끝에 놓입니다.

- E로 들어가고 E로 나옵니다. 숨어 있는 동안은 움직일 수 없고 음파도 쏠 수 없습니다(문 살 틈으로 다른 사람의 음파는 보입니다).
- 괴물은 숨은 사람을 보지도 잡지도 못합니다. 단, 쫓아오던 괴물이 숨는 순간을 봤다면(`Config.Hide.SeenWindow`) 와서 끌어냅니다.
- 문을 여닫는 소리(`Config.Hide.Noise`, 8스터드)는 가까운 괴물이 듣습니다.
- 코드: `src/server/Hiding.luau`(모양·들어가기/나오기), `Monster.luau`(끌어내기).

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
                                (먼 길은 StageBuilder 의 타일 경로를 Config.Monster.LegTiles 칸씩 나눠 계산)
  Doors.luau                    문(E), 괴물은 다가가면 연다
  Hiding.luau                   숨는 곳(L): 챕터별 캐비닛·옷장, 숨기/나오기(E)
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
  MapView.luau                  지도(Q): 내 음파가 닿은 칸의 벽 윤곽을 기록
  Mates.luau                    팀원: 음파 없이도 늘 흰 윤곽선(실제 아바타, Highlight)
  RbxCharacterSounds.client.luau  기본 캐릭터 소리 끄기(빈 스크립트)
```

RemoteEvent (`ReplicatedStorage.Remotes`): `SonarFire`(클→서), `SonarPulse`(서→다른 클라이언트), `SetMoveMode`(클→서), `RoundEvent`(서→클).

## 스테이지 만들기·고치기

`src/server/Stages/StageN.luau`의 `Rows`가 맵입니다(1칸 = 8스터드, 천장 14, 아래층 -6).

`#` 벽 · `.` 바닥 · `S` 시작 · `E` 출구 · `D` 문 · `A` 아치 · `O` 기둥 · `c` 상자 · `m` 기계 · `v` 수직 배관 · `f` 환풍기 ·
`p` 구덩이(아래층) · `b` 다리 · `n` 좁은 다리(괴물 못 건넘) · `s` 계단 · `L` 숨는 곳 · `Z` 뒤지는 곳(열쇠) — 스테이지별 소품 문자는 각 파일 `Props`에.

다섯 맵(43~47 × 41~43칸)은 `node tools/gen-stages.js`가 챕터별 테마(방 종류·통로 굴곡·막다른 길·문/아치 비율·구덩이/수로·소품)로
만들어 `Rows`에 씁니다. 출구는 시작에서 최단 약 150~160칸(걸어서 약 2분) 거리에 놓입니다.
`node tools/gen-stages.js 3 --dry`처럼 한 스테이지만 미리 볼 수 있고, 테마와 시드는 파일 위쪽 `THEMES`에 있습니다.
1스테이지 왼쪽 위 20×20칸은 자동 테스트가 쓰는 원래 시작 구역이라 그대로 둡니다.

고친 뒤 `node tools/check-layout.js`로 문/아치 위치, 계단, 출구 입구 수, 시작→출구 연결을 확인합니다.

## 사운드

외부 에셋 ID는 넣지 않았습니다. 기본값은 Roblox 클라이언트에 들어 있는 `rbxasset://sounds/*` 파일(발소리, 착지음 등)을
피치를 바꿔 쓴 **임시 소리**입니다. `Config.Sounds`의 `Id`를 직접 고른 `rbxassetid://…`로 바꾸면 교체됩니다(빈 문자열이면 재생 안 함).

## 자동 테스트

```powershell
node tools/studio-test.js core 300
```

`tools/SonarTestRunner.plugin.lua`를 Studio 플러그인 폴더에 설치하고, 열린 SonarMaze Studio에서 실제 플레이를 돌려 결과를 출력합니다.
`core`(1인 전체), `stages`(스테이지 1~5 빌드), `perf`(스크립트 비용), `PLAYERS=4 … multi`(4인),
`PLAYERS=2 … lobby`(2인: 로비 → 방 만들기·참가·나가기 → 방장 시작 → 함께 플레이 → 로비 복귀), `STAGE=4 WATCH_SECONDS=60 … walk`(괴물이 실제로 돌아다니는지), `load`(스테이지마다 서버·클라이언트 빌드 시간, 괴물이 움직이는 동안 서버 프레임·경로 계산·음파 비용), `STAGE=3 … probe`(그 스테이지의 모든 바닥 칸까지 실제 경로가 있는지, `QUICK=1`이면 출구만). 테스트 플레이어는 모두 음소거됩니다.
오류 로그는 `node tools/studio-errors.js`.
