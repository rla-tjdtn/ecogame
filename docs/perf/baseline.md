# 에코포비아 성능 기준선 (최적화 전)

측정 담당 세션이 만든 기준 수치. 최적화 세션(① 음파, ② 괴물 AI·애니메이션, ③ 맵·환경·물리, ④ 소리·UI·네트워크·메모리)은 고친 뒤 **같은 조건**으로 다시 재서 이 표와 비교한다.

## 측정 조건

- 측정용 플레이스 = 2026-11-24 20:36 작업 트리 코드 + 같은 시각 맵 사본(Stages·ChapterProps·Creatures·CreatureRigs·CreatureSprites를 얼림). 만드는 법: `sh tools/perf-build.sh <out.rbxlx> <freezeDir>`.
  레벨 디자인·괴물 세션이 맵을 계속 바꾸므로, 전/후 비교는 언제나 얼린 맵으로 한다.
- Roblox Studio 한 창(Windows 11), 모든 테스트 음소거(TestMute), `node tools/studio-test.js <mode>`(묶음 실행: `sh tools/perf-run.sh <outDir> <tag> <items...>`), 결과 표: `node tools/perf-show.js <result.txt> [before.txt]`.
- 측정 장치: `src/client/Perf.luau`(시스템별 os.clock 누적, MicroProfiler 이름표 `sonar.pulses`·`sonar.lines`·`audio.update` 등), TestProbe `perfx`(프레임 분포·메모리·인스턴스·Data Kbps·선·음파 1개 비용·소리 수).

## 숫자 읽는 법 (중요)

- **Studio 플레이 테스트는 서버와 클라이언트가 한 프로세스**다(`stress`·`census`·`soak`·`pbench`). 그래서 `srvFrame`(서버 Heartbeat 간격)은 클라이언트 프레임과 같은 값이고, 서버만의 부하는 `srvHeartbeatMs`(Stats.HeartbeatTimeMs)와 `emitMs`(SoundBus.emit 1회)로 본다.
- Studio 창의 화면 프레임 시간(fps, low1, p95, p99, worst)은 잡음이 크다. 아무것도 안 하는 idle 구간에서도 최악 프레임이 100~200ms 나온다(Studio 자체 작업). **판단 기준은 Lua 시간**이다: `luaAvg`/`luaP95`/`luaP99`/`luaWorst`(프레임마다 이동+음파 전파+선 갱신에 쓴 ms), `pulseAvg`/`pulseMax`(음파 1개에 든 CPU 총합 ms, 여러 프레임에 나뉨), 시스템별 ms/초.
- `multi`(PLAYERS=4)는 실제 클라이언트 4개(창 4개)다. 모두 비활성 창이라 약 15fps로 묶인다. 그래서 프레임 시간이 아니라 음파 스크립트 비용을 60fps 기준으로 환산해서 본다.
- 실제 기기(휴대폰)의 FPS·발열, 실제 인터넷 지연은 Studio로 잴 수 없다. 대신 지연은 서버 허용치(ServerTolerance)와 몰림 시험(flood-12)으로, 휴대폰은 가벼운 모드 값(PoolSize 2000, RevealPerFrame 220, MaxRemotePulses 3)으로 본다.

## stress 단계 (가장 빽빽한 배회 지점에서, 클라이언트 1개)

| 단계 | 내용 |
|---|---|
| idle | 음파 없음 |
| solo | 나 혼자 1.5초마다(최대 정상 속도) |
| two | 나 + 팀원 1 동시 |
| four | 나 + 팀원 3 동시(팀원은 8~28스터드 떨어진 서로 다른 자리) |
| four-overlap | 4명이 같은 자리에서 동시 |
| four-chase | four + 괴물 전부가 나를 쫓는 중(잡기는 끔) |
| flood-12 | 12발 동시(정상 상한 4를 넘는 몰림: MaxRemotePulses 동작 확인) |

팀원 음파는 서버가 실제 팀원 음파와 같은 `SonarPulse` 이벤트로 보낸다. 음파·소리·지도·괴물 드러남 경로가 모두 실제와 같다.

(아래 결과는 측정이 끝나는 대로 채운다)
