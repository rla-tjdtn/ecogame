--!strict
-- 게임 전체 설정값. 숫자는 모두 여기서 조정한다.
-- (ReplicatedStorage.Shared.Config — 서버와 클라이언트가 같이 읽는다)

local Config = {}

-- ─────────────────────────────── 음파 ───────────────────────────────
Config.Sonar = {
	Radius = 35, -- 음파가 퍼지는 최대 거리(스터드, 벽을 돌아가는 경로 길이 기준)
	Cooldown = 1.5, -- 발사 간격(초) — 서버가 같은 값으로 검증한다
	ServerTolerance = 0.5, -- 네트워크 지연·몰림 허용치(초). 평균 간격은 그대로 Cooldown
	WaveSpeed = 40, -- 파동 전진 속도(스터드/초): 35스터드 끝까지 약 0.9초
	MonsterRevealSeconds = 10, -- 음파에 맞은 괴물은 이 시간 동안 지금 모습 그대로(움직이는 그대로) 보인다(Reveal.luau)
	Hold = 3.5, -- 선이 나타난 뒤 완전히 사라질 때까지(초)
	FadeTime = 1.2, -- Hold 끝부분에서 서서히 사라지는 구간(초)
	FlashTime = 0.15, -- 파동이 지나가는 순간 살짝 더 밝은 구간(초)
	BaseLevel = 0.7, -- 플래시 이후 선 밝기(0~1)
	FarLevel = 0.45, -- 반경 끝에 있는 선의 밝기 배율(가까울수록 1)
	LineColor = Color3.fromRGB(215, 215, 215), -- (눈부심을 줄이려고 조금 어둡게)
	-- 선 굵기: 카메라와의 거리에 비례해 화면상 굵기가 거의 일정하게 보이도록
	LineMinWidth = 0.022, -- (눈이 아프지 않게 얇게: 0.035 → 0.022)
	LineWidthPerStud = 0.0013,
	LineMaxWidth = 0.075,
	SegmentLength = 2.5, -- 긴 모서리를 이 길이 이하로 잘라 가까운 쪽부터 그려지게 한다
	CellSize = 2, -- 파동 전파용 복셀 크기(스터드)
	AttachDistance = 2.6, -- 선분이 이 거리 안의 빈 복셀을 통해 음파를 받는다
	PoolSize = 5500, -- 동시에 존재할 수 있는 선 파트 최대 수(재사용). 4500 은 4명이 서로 다른 곳에서 쏘면 선이 많이 빠졌고, 7000 은 렌더 부담이 컸다(휴대폰은 Main 에서 2000)
	MaxRemotePulses = 4, -- 동시에 퍼지는 팀원·도플갱어 음파 수 상한(넘으면 가장 오래된 것을 끝낸다)
	RemoteViewDistance = 110, -- 다른 플레이어 음파를 그리는 최대 거리
	RevealPerFrame = 360, -- 한 프레임에 새로 나타나게 할 선(조각) 수 상한(모든 음파 합계, 넘으면 다음 프레임으로)
	ExpandBudget = 5000, -- 프레임당 파동 전파 연산량 상한(복셀 확장 수)
	ThinCylinder = 0.3, -- 이보다 가는 원통은 끝 링 없이 실루엣 두 줄만
}

-- ─────────────────────────────── 이동 ───────────────────────────────
Config.Move = {
	Walk = 10,
	Run = 18,
	Crouch = 5,
	CrouchCameraDrop = 1.6, -- 웅크릴 때 시점이 내려가는 높이
	BobWalk = 0.045, -- 헤드밥 세기(스터드)
	BobRun = 0.09,
	BobCrouch = 0.02,
	JumpPower = 40, -- 점프(약 4스터드 높이: 상자 위로는 오르지만 벽은 천장까지라 미로를 넘을 수 없다)
}

-- ─────────────────────────── 소리(괴물이 듣는 범위) ───────────────────────────
Config.Noise = {
	Crouch = 4,
	Walk = 10,
	Run = 25,
	Sonar = 45,
	Door = 16,
	Land = 12, -- 점프 후 착지 소리(걷기보다 조금 크다)
	-- 서버가 실제 이동 속도로 발소리 종류를 판정하는 기준(스터드/초)
	RunSpeedAbove = 13.5,
	WalkSpeedAbove = 7,
	MovingAbove = 0.8,
	StepInterval = 0.3, -- 발소리 소음 이벤트 간격(초)
	-- 벽 감쇠: 소리와 괴물 사이 벽 하나마다 들리는 거리에 곱한다(1이면 감쇠 없음)
	WallAttenuation = 0.5,
	MaxWallsCounted = 3,
}

-- ─────────────────────────────── 괴물 ───────────────────────────────
Config.Monster = {
	WanderSpeed = 6, -- 돌아다니기(플레이어 걷기 10)
	InvestigateSpeed = 10, -- 소리 듣고 조사하러 갈 때
	ChaseSpeed = 12, -- 쫓아올 때: 걷기(10)보다 빠르고 달리기(18)보다 느리다
	SightRange = 24, -- 시야(어둠 속 감각) 거리 (15 → 24: 더 멀리서 알아챈다)
	SightRangeCrouch = 12, -- 웅크리면 이만큼만
	SenseRange = 7, -- 이 거리 안이면 시야와 상관없이 알아챈다
	CatchDistance = 3.4,
	AlertTime = 0.8, -- 소리를 듣고 멈칫하는 시간
	SearchTime = 9, -- 소리 난 곳 주변을 뒤지는 시간
	SearchRadius = 14,
	LoseTime = 4, -- 시야에서 이만큼 사라지면 놓친다
	RepathChase = 0.5,
	StartDelay = 4, -- 라운드 시작 후 움직이기까지
	MinSpawnDistance = 70, -- 플레이어 시작점에서 이만큼 떨어진 곳에 등장
	AgentRadius = 1.6,
	AgentHeight = 8,
	HuntEvery = 25, -- 배회 중 이 시간(초)마다 한 번은 플레이어 근처 지점으로 간다(큰 맵에서 마주치게)
	HuntRadius = 40, -- 그 지점이 플레이어에서 이 거리(스터드) 안
	StepWanderVolume = 0.55, -- 배회할 때 발소리 크기(추격 때 = 1)
	LegTiles = 8, -- 먼 길은 타일 경로를 따라 이만큼(칸)씩 나눠 경로를 계산한다
}

-- ─────────────────────────────── 목숨·안전 구역 ───────────────────────────────
-- 스테이지마다 목숨 3개. 괴물(메인·도플갱어)에게 잡히면 하나 잃고 그 스테이지 시작 방에서 다시 시작한다.
-- 다 잃으면 그 스테이지에서는 아웃(관전). 찾은 열쇠·지도 기록은 팀에 그대로 남는다.
Config.Lives = {
	PerStage = 3,
	RespawnDelay = 3, -- 잡힌 뒤 다시 살아나기까지(초, 점프스케어 포함)
}
-- 시작한 방(시작 칸 S 가 있는 방, 문·아치로 둘러싸인 곳)은 안전 구역: 괴물이 들어오지 않고, 그 안의 플레이어는 보지도 잡지도 않는다
Config.SafeZone = {
	Enabled = true,
}

-- ─────────────────────────────── 도플갱어(서브 괴물) ───────────────────────────────
-- 스테이지마다 한 마리. 평소엔 플레이어처럼(사람 모양, 플레이어 발소리, 가끔 가짜 음파 소리) 돌아다니다가
-- 들키면(가까이서 보이거나 음파에 맞으면) 5~10초 뒤 사람 모습이 터지며 작은 괴물로 변해 쫓아온다.
Config.Doppel = {
	Enabled = true,
	PerStage = 1,
	VoiceVolume = 0.45, -- 도플갱어 전용 소리(비명·터짐·걸음)의 음량 배율(너무 시끄러워서 줄임)
	StartDelay = 6, -- 라운드 시작 후 움직이기까지
	WalkSpeed = 7, -- 사람 흉내: 천천히 걷기(플레이어 걷기 10)
	PauseEvery = { 6, 14 }, -- 이 시간(초)마다 멈춰 서서 두리번(플레이어처럼)
	PauseFor = { 1.5, 3.5 },
	FakePingEvery = { 7, 15 }, -- 이 간격(초)으로 플레이어처럼 가짜 음파를 쏜다(파동·소리 모두 진짜와 같다)
	SpawnDistance = { 45, 120 }, -- 시작점에서 이 거리 사이에 등장
	SeeRange = 14, -- 이 거리 안에서 플레이어가 보면(벽 없이) 들킨다
	SonarRange = 35, -- 이 거리 안에서 음파를 쏘면(벽 1장 이하) 들킨다(음파에 모습이 드러났으니)
	TransformDelay = { 10, 30 }, -- 들킨 뒤 변신까지(초). 이 시간이 지나도 플레이어가 TransformNear 안에 있어야 변신한다
	TransformNear = 20, -- 변신할 때 살아 있는 플레이어가 이 거리(스터드) 안에 있어야 한다(멀면 가까워질 때까지 기다린다)
	StalkSpeed = 3, -- 들킨 뒤 변신 전: 발견한 플레이어를 바라보며 아주 천천히 다가온다
	BurstPause = 0.8, -- 터지며 변신하는 동안 멈춤
	-- 변신 뒤(괴물): 메인 괴물보다 작다
	WanderSpeed = 6,
	InvestigateSpeed = 8,
	ChaseSpeed = 10, -- 메인 괴물 12, 플레이어 걷기 10
	CatchDistance = 3.0,
	AgentRadius = 1.3,
	AgentHeight = 6.5,
	MawDistance = 8, -- 이 거리 안으로 덮치면 머리~배의 틈이 세로 입으로 벌어진다
	EyeLinger = 1.2, -- 음파 선이 사라진 뒤에도 눈이 이만큼 더 남는다(초)
}

-- ─────────────────────────────── 꽃괴물(서브 괴물) ───────────────────────────────
-- 스테이지마다 한 마리. 평소엔 봉오리 머리를 닫고 가만히 서 있다(돌아다니지 않는다).
-- 누가 음파를 쏘면(들리는 거리 안, 벽마다 줄어듦) 쉿 소리와 함께 꽃잎 6장을 펼치고 쏜 곳으로 달려간다.
-- 도착해서 아무도 없으면 두리번거리다 머리를 닫고 그 자리에서 다시 기다린다(음파를 쏠수록 조금씩 다가온다).
Config.Flower = {
	Enabled = true,
	PerStage = 1,
	Stages = { 3 }, -- 이 스테이지(Config.Stages 의 Id)에만 나온다: 3 하수도(그 챕터의 시안 괴물이 준비되어 나오면 Round 가 꽃괴물을 띄우지 않는다)
	StartDelay = 6,
	SpawnDistance = { 100, 9999 }, -- 시작점에서 최소 이만큼(스터드) 떨어진 곳(맵 크기 약 350): 시작하자마자 마주치지 않게
	MidRadius = 0.15, -- 맵 한가운데에서 맵 크기(긴 변)의 이 비율 안쪽에 나온다
	KeepOut = 45, -- 시작점에서 이 거리(스터드) 안으로는 달려오지 않는다(시작 위치를 막아 못 나가는 일이 없게)
	ReturnSpeed = 6, -- 두리번거린 뒤 머리를 닫고 원래 자리로 돌아가는 속도
	WakeTime = 0.8, -- 꽃잎이 펼쳐지는 동안(멈춰 있음)
	ChaseSpeed = 12, -- 음파 쏜 곳으로 달려가는 속도(걷기 10 < 12 < 달리기 18: 달리면 따돌릴 수 있다)
	WanderSpeed = 0, -- (돌아다니지 않는다)
	InvestigateSpeed = 0,
	LookAround = { 2, 3 }, -- 도착 뒤 두리번거리는 시간(초)
	GrabRange = 7, -- 달리거나 두리번거리는 중 이 거리 안의 플레이어(벽 없이)에게 덤빈다
	CatchDistance = 3.2,
	AgentRadius = 1.5,
	AgentHeight = 8.5,
}

-- ─────────────────────────────── 라운드 ───────────────────────────────
Config.Round = {
	FirstStartDelay = 2,
	ResultSeconds = 7, -- 클리어/실패 화면 뒤 다음 스테이지까지
	DeadBodyLinger = 0.6,
}

-- ─────────────────────────────── 스테이지 ───────────────────────────────
-- Module 은 ServerScriptService.Server.Stages 안의 레이아웃 모듈 이름
-- 열쇠: 스테이지마다 상자·서랍(맵 문자 Z) 중 한 곳에 있고, 팀이 찾아야 출구가 열린다
Config.Key = {
	Required = true, -- false 면 열쇠 없이도 탈출(테스트용)
	Count = 3, -- 스테이지마다 열쇠 수: 팀이 모두 찾아야 출구가 열린다(누가 찾든 팀 공유)
	HintAfter = 60, -- 마지막 열쇠 하나만 남은 뒤 이 시간(초)이 지나면 "힌트 보기"로 그 상자 위치를 지도에 표시할 수 있다
	PromptDistance = 6,
	SearchSeconds = 0.8, -- 뒤지는 시간
	SearchNoise = 10, -- 뒤지는 소리 반경(스터드)
}

-- 로비·방
Config.Lobby = {
	MaxPlayers = 6, -- 방 하나 최대 인원(서버 최대 인원 default.project.json Players.MaxPlayers 와 같게)
	MinPlayers = 1, -- 시작할 수 있는 최소 인원
	LocalStart = false, -- true 면 텔레포트하지 않고 이 서버에서 시작(Studio 에서는 항상 이 서버에서)
}

-- 숨는 곳(맵 문자 L: 캐비닛·옷장)
Config.Hide = {
	Noise = 8, -- 문을 여닫는 소리 반경(스터드)
	PromptDistance = 6, -- E 안내가 뜨는 거리
	SeenWindow = 0.8, -- 쫓던 괴물이 이 시간(초) 안에 플레이어를 봤으면 숨는 모습을 본 것: 와서 끌어낸다
	Tile = 8, -- 맵 한 칸(스터드), StageBuilder 와 같게
}

-- ─────────────────────────────── 챕터 괴물(시안 그림) ───────────────────────────────
-- 사용자가 고른 시안 괴물들. 몸은 시안을 만든 렌더러로 찍은 8방향 × 9자세 그림(Shared/CreatureSprites)으로 보인다.
-- main = 메인 괴물(맵을 나눈 구역을 돌며 소리를 듣고 쫓아온다, 잡히면 목숨 하나)
-- sub = 서브 괴물: 역할에 맞는 자기 자리(Shared/CreatureHomes)에 있다가 그 영역 안에서 음파·소리·사람을 알아채면 쫓고, 놓치면 돌아간다 + 기믹(Creatures/Sub.luau)
-- 이 챕터의 괴물이 있으면 기존 메인 괴물 대신 이 괴물들이 나오고, 맵을 괴물 수만큼 구역으로 나눠 한 구역씩 맡는다
Config.Creatures = {
	Chapters = {
		[1] = { main = { "k1h1", "k1h2" }, sub = { "k1s1", "k1s2" } }, -- 흉문 · 척수 / 양두 · 나무
		[2] = { main = { "k2h1", "k2h2" }, sub = { "k2s1", "k2s2" } }, -- 갈고리 · 진열장 / 다섯 손가락 · 가위
		[3] = { main = { "k3h1", "k3h2" }, sub = { "k3s1", "k3s2" } }, -- 부은 자 · 수초 / 아가리 · 칠성
		[4] = { main = { "k4h1", "k4h2", "k4h3" }, sub = { "k4s1", "k4s2", "k4s3", "k4s4" } }, -- 수간호사 · 무영등 · 폐 / 바퀴 · 거꾸로 기는 환자 · 뒤집힌 환자 · 합본
		[5] = { main = { "k5h1", "k5h2" }, sub = { "k5s1", "k5s2", "k5s3" } }, -- 길잡이 · 나선 / 웅크린 것 · 끼인 것 · 청음귀
		[6] = { main = { "k6h1", "k6h2", "k6h3" }, sub = { "k6s1", "k6s2", "k6s3", "k6s4" } }, -- 무도회 · 벨보이 · 지배인 / 여행가방 · 반쪽 · 욕조 · 젖은 투숙객
		[7] = { main = { "k7h1", "k7h2", "k7h3", "k7h4" }, sub = { "k7s1", "k7s2", "k7s3" } }, -- 복도 끝 그 애 · 걸상 · 저요 · 술래(8장 디자인) / 인체모형 · 판서 · 풍금
		[8] = { main = { "k8h1", "k8h2", "k8h3" }, sub = { "k8s1", "k8s2", "k8s3", "k8s4" } }, -- 토끼 · 토끼 선생님 · 미끄럼틀 / 누더기 · 흔들말 · 모빌 · 큰 인형
		[9] = { main = { "k9h1", "k9h2", "k9h3" }, sub = { "k9s1", "k9s2", "k9s3", "k9s4" } }, -- 키다리 · 치인 자 · 압축 / 차밑 · 덮개 · 전조등 · 보닛
		[10] = { main = { "k10h1a", "k10h1b", "k10h1c" }, sub = { "k10s1", "k10s2", "k10s3" } }, -- 뜬눈 3마리(소리는 마리마다 다르게) / 잔상 · 만석 · 영사기사
	} :: { [number]: { main: { string }, sub: { string } } },
	On = true, -- false 면 챕터 괴물 대신 기존 메인 괴물
	Overlap = 0.12, -- 메인 괴물 구역(맵 n 등분)이 이웃 구역으로 넘어가는 비율(살짝 겹침)
	HomeMargin = 1, -- 서브 괴물 방 둘레로 더 돌아다니는 칸 수
	-- 서브 괴물 기믹 수치
	Gimmicks = {
		ScareCooldown = 12, -- scare: 같은 사람을 다시 놀래기까지(초)
		Near = 14, -- near: 이 거리(스터드) 안의 소리·사람만 알아챈다
		Freeze = 4, -- freeze: 음파를 맞으면 굳는 시간(초)
		FreezeSight = 16, -- freeze: 보고 쫓는 거리
		BlindTouch = 4, -- blind: 몸에 닿을 만큼 가까워야 알아챈다(나머지는 뛰는 발소리로만)
	},
}

Config.Stages = {
	{ Id = 1, Name = "STAGE 1 — 지하 시설", Module = "Stage1", Monsters = 2 },
	{ Id = 2, Name = "STAGE 2 — 물류 창고", Module = "Stage2", Monsters = 2 },
	{ Id = 3, Name = "STAGE 3 — 하수도", Module = "Stage3", Monsters = 2 },
	{ Id = 4, Name = "STAGE 4 — 폐병원", Module = "Stage4", Monsters = 2 },
	{ Id = 5, Name = "STAGE 5 — 심층 미로", Module = "Stage5", Monsters = 2 },
	{ Id = 6, Name = "STAGE 6 — 호텔", Module = "Stage6", Monsters = 3 },
	{ Id = 7, Name = "STAGE 7 — 학교", Module = "Stage7", Monsters = 4 },
	{ Id = 8, Name = "STAGE 8 — 폐유치원", Module = "Stage8", Monsters = 4 },
	{ Id = 9, Name = "STAGE 9 — 지하 주차장", Module = "Stage9", Monsters = 4 },
	{ Id = 10, Name = "STAGE 10 — 폐영화관", Module = "Stage10", Monsters = 5 },
}

-- ─────────────────────────────── 사운드 ───────────────────────────────
-- 기본값은 Roblox 클라이언트에 기본 포함된 rbxasset:// 파일만 쓴다(외부 에셋 ID 없음).
-- 더 어울리는 소리가 있으면 Id 를 "rbxassetid://숫자" 로 바꾸면 된다. Id = "" 이면 그 소리는 재생하지 않는다.
Config.Sounds = {
	-- 사람 발소리: 실제 녹음된 발걸음 파일(2.5초 안에 4걸음) 중 가장 또렷한 한 걸음(1.22초 지점)만 짧게(Steps = {시작초, 재생길이초}).
	-- 걸음마다 똑같은 소리 하나 — 다른 소리를 섞거나 피치를 바꾸지 않는다(깔끔하게).
	FootWalk = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.36, Pitch = 1.0, Range = 40, Steps = { { 1.22, 0.13 } } },
	FootRun = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.55, Pitch = 1.0, Range = 70, Steps = { { 1.22, 0.13 } } },
	FootCrouch = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.13, Pitch = 1.0, Range = 18, Steps = { { 1.22, 0.13 } } },
	Sonar = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.3, Pitch = 0.35, Range = 90 }, -- (크면 머리가 아프다: 0.9 → 0.3)
	SonarEcho = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.12, Pitch = 0.28, Range = 90 },
	Door = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.8, Pitch = 0.55, Range = 60 },
	-- 괴물 발소리: 사람과 완전히 다르게 — 깊고 무거운 "쿵"(울림) + 낮게 늘인 발톱 "타닥"(Claw). 걸음 간격도 사람보다 느리고 불규칙하다
	-- 괴물 발소리: 실제 녹음된 무거운 생물 발걸음(Pro Sound Effects). 쫓아올 때만 들린다
	MonsterStep = { Id = "rbxassetid://9114166413", Volume = 0.9, Pitch = 0.9, Range = 120, Near = 10, Cut = 0.6 }, -- (늘 난다: 배회 땐 Monster.StepWanderVolume 배)
	MonsterClaw = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.35, Pitch = 0.55, Range = 95, Steps = { { 0.03, 0.34 }, { 0.62, 0.34 } } },
	-- MonsterIdle / MonsterAlert / MonsterChase / MonsterScream2 / MonsterWaveThud(괴성)는 아래 Config.ScreamStyles 에서 고른 시안이 채운다.
	AmbientHum = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.18, Pitch = 0.22, Range = 0 }, -- 환풍기·배관 진동(루프)
	AmbientFan = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.5, Pitch = 0.4, Range = 45 }, -- 맵 안 환풍기 위치(루프)
	AmbientDrip = { Id = "", Volume = 0.25, Pitch = 2.2, Range = 60 }, -- 물방울(찰팍) 소리 제거
	AmbientMetal = { Id = "", Volume = 0.22, Pitch = 0.35, Range = 160 }, -- 폭발음 같은 금속음 제거
	AmbientCreak = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.25, Pitch = 0.3, Range = 120 },
	AmbientWater = { Id = "", Volume = 0.35, Pitch = 0.6, Range = 50 }, -- 하수도 물소리(찰팍거림) 제거
}

-- ── 괴성 시안(음파 공격 느낌) ──
-- Config.ScreamStyle 숫자 하나로 고른다(아래 1~6). 시안마다 Sounds(소리 정의)와 Screams(시간차 겹침 표)가 있다.
-- Fx = { { "효과클래스", { 속성 = 값 } }, ... } — Roblox SoundEffect 속성 이름 그대로(Audio.luau 가 pcall 로 안전하게 적용).
-- 목소리 파일(ouch/oof)은 원래 아주 크고 바람 파일(action_falling)은 아주 작아서 Volume 이 다르다.
-- Screams 표: s = 소리 이름, t = 시작 지연(초), p = 피치 배율, v = 볼륨 배율.
Config.ScreamStyle = 13 -- 선택: 귀신 곡소리. 1~6 괴성 시안, 7~12 사이렌 변형(10 = 끊기는 사이렌), 13~15 귀신 곡소리(끊기는 박자·음 높이 일정). 괴물 괴성은 추격 때만(발소리는 평소에도 난다)

local OUCH, OOF, WIND, LAND = "rbxasset://sounds/ouch.ogg", "rbxasset://sounds/oof.ogg", "rbxasset://sounds/action_falling.ogg", "rbxasset://sounds/action_jump_land.mp3"
local function snd(id: string, vol: number, pitch: number, range: number, cut: number?, fx: { { any } }?): { [string]: any }
	return { Id = id, Volume = vol, Pitch = pitch, Range = range, Cut = cut, Fx = fx }
end
local function L(s: string, t: number, p: number, v: number, sweep: { { number } }?, dur: number?, gate: { number }?): { [string]: any }
	return { s = s, t = t, p = p, v = v, sweep = sweep, dur = dur, gate = gate } -- gate = { 켜짐초, 꺼짐초 }: 끊기는 박자 -- sweep = { {정규화 시간 0~1, 피치 배율}, ... }, dur = 길이(초)
end
local function EQ(lo: number, mid: number, hi: number): { any }
	return { "EqualizerSoundEffect", { LowGain = lo, MidGain = mid, HighGain = hi } }
end
local function TREM(freq: number, depth: number): { any }
	return { "TremoloSoundEffect", { Frequency = freq, Depth = depth } }
end
local function DIST(level: number): { any }
	return { "DistortionSoundEffect", { Level = level } }
end
local function REV(decay: number, wet: number): { any }
	return { "ReverbSoundEffect", { DecayTime = decay, WetLevel = wet } }
end

local FX_SCREECH = { TREM(25, 0.6), DIST(0.25), EQ(-20, 0, 4) }
local FX_PULSE = { TREM(7, 0.85), EQ(6, -12, -40), REV(2.5, -4) }
local FX_SIREN = { TREM(14, 0.9), DIST(0.3), REV(3, -2) }
local FX_ECHO = { { "EchoSoundEffect", { Delay = 0.28, Feedback = 0.55, DryLevel = 0, WetLevel = -3 } }, { "ChorusSoundEffect", { Depth = 0.5, Mix = 0.5, Rate = 2 } } }
local FX_FLANGE = { { "FlangeSoundEffect", { Depth = 1, Mix = 0.8, Rate = 1.2 } }, EQ(-40, -4, 6) }
local FX_ROAR = { DIST(0.8), REV(3, -2) }

Config.ScreamStyles = {
	-- 1. 초음파 비명: 높은 음이 떨리며 점점 날카롭게 치솟는다(고주파 찢는 소리)
	{
		Name = "초음파 비명 (치솟는 고주파)",
		Sounds = {
			MonsterIdle = snd(OUCH, 0.2, 1.3, 70, nil, FX_SCREECH),
			MonsterAlert = snd(OUCH, 0.35, 1.45, 90, nil, FX_SCREECH),
			MonsterChase = snd(OUCH, 0.4, 1.5, 110, nil, FX_SCREECH),
			MonsterScream2 = snd(OOF, 0.2, 1.3, 110, nil, FX_SCREECH),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 0.9, 1), L("MonsterIdle", 0.12, 1.1, 1), L("MonsterIdle", 0.24, 1.3, 0.8) },
			Alert = { L("MonsterAlert", 0, 0.75, 1), L("MonsterAlert", 0.1, 0.9, 1), L("MonsterAlert", 0.2, 1.05, 1), L("MonsterAlert", 0.3, 1.2, 1), L("MonsterAlert", 0.4, 1.35, 0.9) },
			Chase = {
				L("MonsterChase", 0, 0.6, 1), L("MonsterChase", 0.1, 0.72, 1), L("MonsterChase", 0.2, 0.84, 1), L("MonsterChase", 0.3, 0.96, 1),
				L("MonsterChase", 0.4, 1.08, 1), L("MonsterChase", 0.5, 1.2, 1), L("MonsterChase", 0.6, 1.32, 0.9), L("MonsterChase", 0.7, 1.44, 0.8),
				L("MonsterScream2", 0.5, 1.0, 0.8), L("MonsterScream2", 0.8, 1.3, 0.7),
			},
		},
	},
	-- 2. 저주파 맥동파: 바닥을 울리는 낮은 "우우웅" 이 맥박처럼 일렁이고 쿵, 쿵 충격파가 번진다
	{
		Name = "저주파 맥동파 (우우웅 + 쿵쿵)",
		Sounds = {
			MonsterIdle = snd(WIND, 3, 0.35, 70, 1.2, FX_PULSE),
			MonsterAlert = snd(WIND, 4.5, 0.33, 90, 1.8, FX_PULSE),
			MonsterChase = snd(WIND, 6, 0.3, 110, 2.6, FX_PULSE),
			MonsterScream2 = snd(LAND, 1.5, 0.4, 110, 0.35, { REV(2, -2) }),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1) },
			Alert = { L("MonsterAlert", 0, 1, 1), L("MonsterScream2", 0, 1, 1), L("MonsterScream2", 0.5, 1, 0.8) },
			Chase = { L("MonsterChase", 0, 1, 1), L("MonsterScream2", 0, 1, 1), L("MonsterScream2", 0.45, 1, 0.9), L("MonsterScream2", 0.9, 1, 0.8), L("MonsterScream2", 1.35, 1, 0.7), L("MonsterScream2", 1.8, 1, 0.6) },
		},
	},
	-- 3. 떨리는 사이렌: 비명이 빠르게 떨려 경보 사이렌처럼 일렁이며 점점 낮아진다
	{
		Name = "떨리는 사이렌 비명",
		Sounds = {
			MonsterIdle = snd(OUCH, 0.2, 0.7, 70, nil, FX_SIREN),
			MonsterAlert = snd(OUCH, 0.35, 0.6, 90, nil, FX_SIREN),
			MonsterChase = snd(OUCH, 0.4, 0.5, 110, nil, FX_SIREN),
			MonsterScream2 = snd(OOF, 0.2, 0.55, 110, nil, FX_SIREN),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1), L("MonsterIdle", 0.4, 0.9, 0.7) },
			Alert = { L("MonsterAlert", 0, 1, 1), L("MonsterAlert", 0.3, 0.9, 0.9), L("MonsterAlert", 0.7, 0.8, 0.8) },
			Chase = { L("MonsterChase", 0, 1, 1), L("MonsterScream2", 0.15, 1, 0.9), L("MonsterChase", 0.4, 0.9, 1), L("MonsterScream2", 0.7, 0.85, 0.8), L("MonsterChase", 1.0, 0.8, 0.8), L("MonsterChase", 1.4, 0.7, 0.7) },
		},
	},
	-- 4. 에코 파동: 비명이 메아리처럼 되풀이되며 퍼져 나가는 파동
	{
		Name = "에코 파동 (되풀이되며 퍼짐)",
		Sounds = {
			MonsterIdle = snd(OUCH, 0.2, 0.5, 70, nil, FX_ECHO),
			MonsterAlert = snd(OUCH, 0.35, 0.45, 90, nil, FX_ECHO),
			MonsterChase = snd(OUCH, 0.4, 0.4, 110, nil, FX_ECHO),
			MonsterScream2 = snd(OOF, 0.2, 0.45, 110, nil, FX_ECHO),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1) },
			Alert = { L("MonsterAlert", 0, 1, 1), L("MonsterAlert", 0.5, 0.9, 0.8) },
			Chase = { L("MonsterChase", 0, 1, 1), L("MonsterScream2", 0.25, 0.9, 0.8), L("MonsterChase", 0.7, 0.85, 0.9) },
		},
	},
	-- 5. 플랜저 레이저: 쉬이잉— 하고 휘감기는 가는 음파가 훑고 지나간다
	{
		Name = "플랜저 음파 (쉬이잉 휘감김)",
		Sounds = {
			MonsterIdle = snd(WIND, 2, 1.5, 70, 0.9, FX_FLANGE),
			MonsterAlert = snd(WIND, 4, 1.6, 90, 1.5, FX_FLANGE),
			MonsterChase = snd(WIND, 5, 1.7, 110, 2.2, FX_FLANGE),
			MonsterScream2 = snd(OUCH, 0.3, 1.4, 110, nil, FX_FLANGE),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1) },
			Alert = { L("MonsterAlert", 0, 1, 1), L("MonsterScream2", 0.3, 1, 0.8) },
			Chase = { L("MonsterChase", 0, 1, 1), L("MonsterScream2", 0.3, 1, 1), L("MonsterScream2", 0.8, 0.85, 0.9), L("MonsterScream2", 1.3, 0.7, 0.8) },
		},
	},
	-- 6. 혼합 충격 포효: 거칠게 왜곡된 낮은 포효 + 바닥을 울리는 저주파 + 쿵 충격파
	{
		Name = "혼합 충격 포효 (포효 + 저주파 + 충격)",
		Sounds = {
			MonsterIdle = snd(OUCH, 0.2, 0.45, 70, nil, FX_ROAR),
			MonsterAlert = snd(OUCH, 0.35, 0.42, 90, nil, FX_ROAR),
			MonsterChase = snd(OUCH, 0.45, 0.38, 110, nil, FX_ROAR),
			MonsterScream2 = snd(WIND, 5, 0.3, 110, 2.2, FX_PULSE),
			MonsterWaveThud = snd(LAND, 1.5, 0.4, 110, 0.35, { REV(2, -2) }),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1) },
			Alert = { L("MonsterAlert", 0, 1, 1), L("MonsterWaveThud", 0, 1, 1) },
			Chase = {
				L("MonsterChase", 0, 1, 1), L("MonsterScream2", 0, 1, 1), L("MonsterWaveThud", 0, 1, 1), L("MonsterWaveThud", 0.5, 1, 0.8),
				L("MonsterChase", 0.6, 0.9, 0.9), L("MonsterWaveThud", 1.0, 1, 0.7), L("MonsterChase", 1.3, 0.8, 0.7),
			},
		},
	},
}

-- ── 3번(떨리는 사이렌)의 높낮이 변형 7~12번: 소리를 반복하며 피치를 시간에 따라 바꾼다(sweep). 길이: 배회 1.2초 / 경계 1.8초 / 추격 2.7초 ──
local FX_STUTTER = { { "TremoloSoundEffect", { Frequency = 9, Depth = 1, Duty = 0.5 } }, DIST(0.3), REV(3, -2) }
local function sirenVariant(name: string, sweep: { { number } }, fx: { { any } }?): { [string]: any }
	local f = fx or FX_SIREN
	return {
		Name = name,
		Sounds = {
			MonsterIdle = snd(OUCH, 0.2, 0.5, 70, nil, f),
			MonsterAlert = snd(OUCH, 0.35, 0.5, 90, nil, f),
			MonsterChase = snd(OUCH, 0.4, 0.5, 110, nil, f),
			MonsterScream2 = snd(OOF, 0.2, 0.4, 110, nil, f),
		},
		Screams = {
			Idle = { L("MonsterIdle", 0, 1, 1, sweep, 1.2) },
			Alert = { L("MonsterAlert", 0, 1, 1, sweep, 1.8), L("MonsterScream2", 0.05, 1, 0.6, sweep, 1.8) },
			Chase = { L("MonsterChase", 0, 1, 1, sweep, 2.7), L("MonsterScream2", 0.05, 1, 0.6, sweep, 2.7) },
		},
	}
end
do
	local styles: any = Config.ScreamStyles
	table.insert(styles, sirenVariant("3-A 사이렌: 내려갔다 올라감", { { 0, 1.3 }, { 0.5, 0.7 }, { 1, 1.3 } }))
	table.insert(styles, sirenVariant("3-B 사이렌: 올라감", { { 0, 0.7 }, { 1, 1.7 } }))
	table.insert(styles, sirenVariant("3-C 사이렌: 올라갔다 내려감", { { 0, 0.7 }, { 0.5, 1.5 }, { 1, 0.6 } }))
	table.insert(styles, sirenVariant("3-D 사이렌: 끊기며 떨리는 소리(음 높이 일정)", { { 0, 1.2 }, { 1, 1.2 } }, FX_STUTTER))
	table.insert(styles, sirenVariant("3-E 사이렌: 투톤(삐뽀삐뽀)", { { 0, 1 }, { 0.1667, 1 }, { 0.1668, 1.5 }, { 0.3333, 1.5 }, { 0.3334, 1 }, { 0.5, 1 }, { 0.5001, 1.5 }, { 0.6667, 1.5 }, { 0.6668, 1 }, { 0.8333, 1 }, { 0.8334, 1.5 }, { 1, 1.5 } }))
	table.insert(styles, sirenVariant("3-F 사이렌: 오르락내리락 3번(앰뷸런스)", { { 0, 0.8 }, { 0.167, 1.5 }, { 0.333, 0.8 }, { 0.5, 1.5 }, { 0.667, 0.8 }, { 0.833, 1.5 }, { 1, 0.8 } }))
end

-- ── 귀신 곡소리(13~15번): 소름 끼치는 귀신 울음. 음 높이는 일정하고 gate 박자로 끊겨 들린다. 괴성은 추격(Chase) 때만 낸다(발소리는 평소에도 난다) ──
-- (Idle/Alert 는 쓰지 않아 비워 둔다. MonsterAlert 소리 정의는 사망 연출(2D 한 번)이 쓰므로 반드시 있어야 한다)
local FLAT = { { 0, 1 }, { 1, 1 } }
local function ghost(name: string, voice: { [string]: any }, air: { [string]: any }, alert: { [string]: any }, gate: { number }): { [string]: any }
	return {
		Name = name,
		Sounds = { MonsterIdle = voice, MonsterAlert = alert, MonsterChase = voice, MonsterScream2 = air },
		Screams = {
			Idle = {},
			Alert = {},
			Chase = { L("MonsterChase", 0, 1, 1, FLAT, 2.4, gate), L("MonsterScream2", 0, 1, 1, FLAT, 2.4, gate) },
		},
	}
end
do
	local styles: any = Config.ScreamStyles
	local FX_GHOST = { EQ(-30, -4, 6), { "ChorusSoundEffect", { Depth = 0.6, Mix = 0.6, Rate = 1.5 } }, TREM(5, 0.3), REV(4, -2) }
	local FX_HOLLOW = { EQ(-20, -8, 2), { "FlangeSoundEffect", { Depth = 0.5, Mix = 0.5, Rate = 0.4 } }, { "EchoSoundEffect", { Delay = 0.35, Feedback = 0.6, DryLevel = -3, WetLevel = -3 } }, REV(5, -2) }
	local FX_BREATH = { EQ(-40, -2, 8), { "FlangeSoundEffect", { Depth = 1, Mix = 0.8, Rate = 1.2 } }, { "ChorusSoundEffect", { Depth = 0.6, Mix = 0.6, Rate = 1.5 } }, REV(4, -2) }
	-- 13: 높고 속삭이는 곡소리 (높은 목소리 + 바람 숨결, 약하게 떨림, 긴 울림)
	table.insert(styles, ghost("13 귀신 곡소리: 높고 속삭이는 울음", snd(OUCH, 0.3, 1.25, 110, nil, FX_GHOST), snd(WIND, 6, 1.6, 110, nil, { EQ(-40, -2, 8), REV(4, -2) }), snd(OUCH, 0.35, 1.25, 90, nil, FX_GHOST), { 0.22, 0.14 }))
	-- 14: 공허한 울음 (낮은 중음 + 되울림 + 천천히 휘감김)
	table.insert(styles, ghost("14 귀신 곡소리: 공허하게 울리는 울음", snd(OUCH, 0.3, 0.8, 110, nil, FX_HOLLOW), snd(OOF, 0.1, 0.7, 110, nil, FX_HOLLOW), snd(OUCH, 0.35, 0.8, 90, nil, FX_HOLLOW), { 0.3, 0.2 }))
	-- 15: 바람이 우는 소리 (숨소리 같은 바람이 휘감기고 아주 작은 목소리가 속삭임)
	table.insert(styles, ghost("15 귀신 곡소리: 바람이 우는 숨소리", snd(WIND, 6, 2.0, 110, nil, FX_BREATH), snd(OOF, 0.1, 1.4, 110, nil, FX_GHOST), snd(OUCH, 0.3, 1.3, 90, nil, FX_GHOST), { 0.25, 0.15 }))
end

-- ── 괴성 카탈로그 + 직접 만들기 ──
-- 미리듣기 페이지(tools/sound-preview/index.html)에 60개 카탈로그와 "직접 만들기" 칸이 있다.
--   · 카탈로그에서 고르면: 아래 Config.ScreamRecipe 에 그 번호(1~60)를 적는다.
--   · 직접 만들면: 페이지가 알려주는 한 줄(Config.ScreamCustom = {...})을 그대로 붙여 넣는다(이게 있으면 번호보다 우선).
Config.ScreamRecipe = 0 -- 0 = 쓰지 않음(위의 ScreamStyle 사용), 1~60 = 카탈로그 번호

-- ── 실제 녹음 괴성(Roblox 크리에이터 스토어, Pro Sound Effects 라이선스 — 어떤 게임에서든 무료로 써도 된다) ──
-- 번호 하나(Config.RealScream)로 고른다. 0 이면 위의 합성 시안을 쓴다. 들어 보기: tools/sound-preview/real.html
-- Start = 파일에서 시작 지점(초), Dur = 괴성 길이(초)
Config.RealScreams = {
	{ Id = 9113090127, Start = 0, Dur = 3, Volume = 0.55, Name = "외계 생명체 소리 1 (Alien Creature 1)" },
	{ Id = 9113090147, Start = 0, Dur = 2, Volume = 0.55, Name = "외계 생명체 소리 2 (Alien Creature 2)" },
	{ Id = 9113093880, Start = 0, Dur = 2, Volume = 0.55, Name = "외계인 휘파람 + 낮게 꾸르륵거리는 소리 (Alien Whistles Deep Gurgly Grunts)" },
	{ Id = 9119839011, Start = 0, Dur = 3, Volume = 0.5, Name = "낮게 웅웅 울리는 외계 에너지 (Synth Throb Deep Wubba Wubba Alien)" },
	{ Id = 9116966503, Start = 0, Dur = 3, Volume = 0.55, Name = "괴물 목소리 (Monster Vocals 1)" },
	{ Id = 9114628818, Start = 0, Dur = 2, Volume = 0.55, Name = "거인의 낮게 으르렁거리는 목소리 (Goliath Vocal Deep Growling)" },
	{ Id = 9125548429, Start = 0, Dur = 3, Volume = 0.5, Name = "느리게 웅웅거리는 드론 소리 (Slow Buzzing Synth Drone Hum)" },
	{ Id = 9113980319, Start = 0, Dur = 3, Volume = 0.5, Name = "거대 게 괴물의 포효와 으르렁 (Giant Crab Monster Roar Growl)" },
	-- 9~12: 4번(낮게 웅웅 울리는 외계 에너지) + 소름 끼치는 비명을 겹친 것. Layer = 겹치는 비명(Delay 초 뒤에 시작)
	{ Id = 9119839011, Start = 0, Dur = 3, Volume = 0.45, Name = "4번 웅웅 + 날카롭게 찢어지는 비명", Layer = { Id = 9117339703, Start = 0, Dur = 2.4, Volume = 0.4, Delay = 0.5 } },
	{ Id = 9119839011, Start = 0, Dur = 3, Volume = 0.45, Name = "4번 웅웅 + 고통에 찬 괴물 비명", Layer = { Id = 9113985971, Start = 0, Dur = 2, Volume = 0.4, Delay = 0.5 } },
	{ Id = 9119839011, Start = 0, Dur = 3, Volume = 0.45, Name = "4번 웅웅 + 다가오는 귀신 비명", Layer = { Id = 9114572653, Start = 0.5, Dur = 2.4, Volume = 0.45, Delay = 0.4 } },
	{ Id = 9119839011, Start = 0, Dur = 3, Volume = 0.45, Name = "4번 웅웅 + 악마 비명", Layer = { Id = 9114037660, Start = 0, Dur = 2.4, Volume = 0.4, Delay = 0.5 } },
}
-- 괴물 소리 크기(괴성·추격 발소리 배율), 가까이에서 줄지 않는 거리, 들리는 최대 거리
Config.MonsterLoudness = 2.5
Config.MonsterNear = 15
Config.MonsterRange = 150
Config.RealScream = 9 -- 위 목록 번호 1~12 (9~12 = 4번 웅웅 + 비명). Studio 에서 Play 중 숫자키 1~4 로 9~12번을 바로 들어 볼 수 있다 (0 = 합성 시안). 들어 보기: tools/sound-preview/real.html
Config.ScreamGate = nil :: { number }? -- 끊기는 박자 { 켜짐초, 꺼짐초 } (nil = 끊지 않고 한 번에 지른다. 예전 끊기는 방식: { 0.2, 0.1 })
Config.ScreamCustom = nil :: any -- 예: { src = "ouch", pitch = 1.25, fx = "ghost", gate = { 0.22, 0.14 }, dur = 2.4, air = "wind" }
-- src: "ouch"(비명) / "oof"(낮은 목소리) / "wind"(바람 숨결)   pitch: 음 높이 배율(클수록 높음)
-- fx: ghost hollow breath siren stutter echo flange screech roar pulse   gate: { 켜짐초, 꺼짐초 } (끊기는 박자, 없으면 이어짐)
-- dur: 괴성 길이(초)   air: 겹치는 두 번째 소리 "wind" 또는 "oof"(없으면 생략)   to: 끝 음 높이 배율(음이 올라가거나 내려가게, 없으면 일정)
local ScreamFx: { [string]: { { any } } } = {
	ghost = { EQ(-30, -4, 6), { "ChorusSoundEffect", { Depth = 0.6, Mix = 0.6, Rate = 1.5 } }, TREM(5, 0.3), REV(4, -2) },
	hollow = { EQ(-20, -8, 2), { "FlangeSoundEffect", { Depth = 0.5, Mix = 0.5, Rate = 0.4 } }, { "EchoSoundEffect", { Delay = 0.35, Feedback = 0.6, DryLevel = -3, WetLevel = -3 } }, REV(5, -2) },
	breath = { EQ(-40, -2, 8), { "FlangeSoundEffect", { Depth = 1, Mix = 0.8, Rate = 1.2 } }, { "ChorusSoundEffect", { Depth = 0.6, Mix = 0.6, Rate = 1.5 } }, REV(4, -2) },
	siren = FX_SIREN,
	stutter = FX_STUTTER,
	echo = FX_ECHO,
	flange = FX_FLANGE,
	screech = FX_SCREECH,
	roar = FX_ROAR,
	pulse = FX_PULSE,
}
local SCREAM_SRC = { ouch = OUCH, oof = OOF, wind = WIND }
local SCREAM_VOL = { ouch = 0.3, oof = 0.12, wind = 6 } -- 원본 크기가 달라서(비명은 크고 바람은 아주 작다) 소리별로 맞춘 기본 볼륨
local function recipeStyle(r: any): { [string]: any }
	local fx = ScreamFx[r.fx] or {}
	local voice = snd(SCREAM_SRC[r.src] or OUCH, SCREAM_VOL[r.src] or 0.3, r.pitch or 1, 110, nil, fx)
	local alert = snd(SCREAM_SRC[r.src] or OUCH, (SCREAM_VOL[r.src] or 0.3) * 1.15, r.pitch or 1, 90, nil, fx) -- 사망 연출(2D 한 번)이 쓴다
	local sounds: { [string]: any } = { MonsterIdle = voice, MonsterAlert = alert, MonsterChase = voice }
	local sweep = if r.to then { { 0, 1 }, { 1, r.to } } else { { 0, 1 }, { 1, 1 } }
	local dur = r.dur or 2.4
	local layers = { L("MonsterChase", 0, 1, 1, sweep, dur, r.gate) }
	if r.air == "wind" then
		sounds.MonsterScream2 = snd(WIND, 6, 1.6, 110, nil, { EQ(-40, -2, 8), REV(4, -2) })
		table.insert(layers, L("MonsterScream2", 0, 1, 1, sweep, dur, r.gate))
	elseif r.air == "oof" then
		sounds.MonsterScream2 = snd(OOF, 0.1, (r.pitch or 1) * 0.9, 110, nil, fx)
		table.insert(layers, L("MonsterScream2", 0, 1, 1, sweep, dur, r.gate))
	end
	return { Name = "recipe", Sounds = sounds, Screams = { Idle = {}, Alert = {}, Chase = layers } }
end
-- BEGIN SCREAM RECIPES (자동 생성: node tools/sound-preview/build.js — 직접 고치지 말고 tools/sound-preview/recipes.js 를 고친다)
local ScreamRecipes: { { [string]: any } } = {
	{ fx = "ghost", src = "ouch", pitch = 1.5, gate = { 0.15, 0.1 }, air = "wind" }, -- 1 귀신 곡소리 · 높은 음 · 빠르게 끊김
	{ fx = "ghost", src = "ouch", pitch = 1.5, gate = { 0.35, 0.25 }, air = "wind" }, -- 2 귀신 곡소리 · 높은 음 · 느리게 끊김
	{ fx = "ghost", src = "ouch", pitch = 1.25, gate = { 0.15, 0.1 }, air = "wind" }, -- 3 귀신 곡소리 · 중간 음 · 빠르게 끊김
	{ fx = "ghost", src = "ouch", pitch = 1.25, gate = { 0.35, 0.25 }, air = "wind" }, -- 4 귀신 곡소리 · 중간 음 · 느리게 끊김
	{ fx = "ghost", src = "ouch", pitch = 0.9, gate = { 0.15, 0.1 }, air = "wind" }, -- 5 귀신 곡소리 · 낮은 음 · 빠르게 끊김
	{ fx = "ghost", src = "ouch", pitch = 0.9, gate = { 0.35, 0.25 }, air = "wind" }, -- 6 귀신 곡소리 · 낮은 음 · 느리게 끊김
	{ fx = "hollow", src = "ouch", pitch = 1, gate = { 0.15, 0.1 }, air = "oof" }, -- 7 공허한 울음 · 높은 음 · 빠르게 끊김
	{ fx = "hollow", src = "ouch", pitch = 1, gate = { 0.35, 0.25 }, air = "oof" }, -- 8 공허한 울음 · 높은 음 · 느리게 끊김
	{ fx = "hollow", src = "ouch", pitch = 0.8, gate = { 0.15, 0.1 }, air = "oof" }, -- 9 공허한 울음 · 중간 음 · 빠르게 끊김
	{ fx = "hollow", src = "ouch", pitch = 0.8, gate = { 0.35, 0.25 }, air = "oof" }, -- 10 공허한 울음 · 중간 음 · 느리게 끊김
	{ fx = "hollow", src = "ouch", pitch = 0.55, gate = { 0.15, 0.1 }, air = "oof" }, -- 11 공허한 울음 · 낮은 음 · 빠르게 끊김
	{ fx = "hollow", src = "ouch", pitch = 0.55, gate = { 0.35, 0.25 }, air = "oof" }, -- 12 공허한 울음 · 낮은 음 · 느리게 끊김
	{ fx = "breath", src = "wind", pitch = 2.4, gate = { 0.15, 0.1 }, air = "oof" }, -- 13 바람 숨소리 · 높은 음 · 빠르게 끊김
	{ fx = "breath", src = "wind", pitch = 2.4, gate = { 0.35, 0.25 }, air = "oof" }, -- 14 바람 숨소리 · 높은 음 · 느리게 끊김
	{ fx = "breath", src = "wind", pitch = 2, gate = { 0.15, 0.1 }, air = "oof" }, -- 15 바람 숨소리 · 중간 음 · 빠르게 끊김
	{ fx = "breath", src = "wind", pitch = 2, gate = { 0.35, 0.25 }, air = "oof" }, -- 16 바람 숨소리 · 중간 음 · 느리게 끊김
	{ fx = "breath", src = "wind", pitch = 1.4, gate = { 0.15, 0.1 }, air = "oof" }, -- 17 바람 숨소리 · 낮은 음 · 빠르게 끊김
	{ fx = "breath", src = "wind", pitch = 1.4, gate = { 0.35, 0.25 }, air = "oof" }, -- 18 바람 숨소리 · 낮은 음 · 느리게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.9, gate = { 0.15, 0.1 } }, -- 19 떨리는 사이렌 · 높은 음 · 빠르게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.9, gate = { 0.35, 0.25 } }, -- 20 떨리는 사이렌 · 높은 음 · 느리게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.6, gate = { 0.15, 0.1 } }, -- 21 떨리는 사이렌 · 중간 음 · 빠르게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.6, gate = { 0.35, 0.25 } }, -- 22 떨리는 사이렌 · 중간 음 · 느리게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.45, gate = { 0.15, 0.1 } }, -- 23 떨리는 사이렌 · 낮은 음 · 빠르게 끊김
	{ fx = "siren", src = "ouch", pitch = 0.45, gate = { 0.35, 0.25 } }, -- 24 떨리는 사이렌 · 낮은 음 · 느리게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.9, gate = { 0.15, 0.1 } }, -- 25 더듬는 사이렌 · 높은 음 · 빠르게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.9, gate = { 0.35, 0.25 } }, -- 26 더듬는 사이렌 · 높은 음 · 느리게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.6, gate = { 0.15, 0.1 } }, -- 27 더듬는 사이렌 · 중간 음 · 빠르게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.6, gate = { 0.35, 0.25 } }, -- 28 더듬는 사이렌 · 중간 음 · 느리게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.45, gate = { 0.15, 0.1 } }, -- 29 더듬는 사이렌 · 낮은 음 · 빠르게 끊김
	{ fx = "stutter", src = "ouch", pitch = 0.45, gate = { 0.35, 0.25 } }, -- 30 더듬는 사이렌 · 낮은 음 · 느리게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.7, gate = { 0.15, 0.1 } }, -- 31 에코 파동 · 높은 음 · 빠르게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.7, gate = { 0.35, 0.25 } }, -- 32 에코 파동 · 높은 음 · 느리게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.5, gate = { 0.15, 0.1 } }, -- 33 에코 파동 · 중간 음 · 빠르게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.5, gate = { 0.35, 0.25 } }, -- 34 에코 파동 · 중간 음 · 느리게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.4, gate = { 0.15, 0.1 } }, -- 35 에코 파동 · 낮은 음 · 빠르게 끊김
	{ fx = "echo", src = "ouch", pitch = 0.4, gate = { 0.35, 0.25 } }, -- 36 에코 파동 · 낮은 음 · 느리게 끊김
	{ fx = "flange", src = "wind", pitch = 2, gate = { 0.15, 0.1 } }, -- 37 플랜저 휘감김 · 높은 음 · 빠르게 끊김
	{ fx = "flange", src = "wind", pitch = 2, gate = { 0.35, 0.25 } }, -- 38 플랜저 휘감김 · 높은 음 · 느리게 끊김
	{ fx = "flange", src = "wind", pitch = 1.6, gate = { 0.15, 0.1 } }, -- 39 플랜저 휘감김 · 중간 음 · 빠르게 끊김
	{ fx = "flange", src = "wind", pitch = 1.6, gate = { 0.35, 0.25 } }, -- 40 플랜저 휘감김 · 중간 음 · 느리게 끊김
	{ fx = "flange", src = "wind", pitch = 1.1, gate = { 0.15, 0.1 } }, -- 41 플랜저 휘감김 · 낮은 음 · 빠르게 끊김
	{ fx = "flange", src = "wind", pitch = 1.1, gate = { 0.35, 0.25 } }, -- 42 플랜저 휘감김 · 낮은 음 · 느리게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.8, gate = { 0.15, 0.1 } }, -- 43 초음파 비명 · 높은 음 · 빠르게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.8, gate = { 0.35, 0.25 } }, -- 44 초음파 비명 · 높은 음 · 느리게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.4, gate = { 0.15, 0.1 } }, -- 45 초음파 비명 · 중간 음 · 빠르게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.4, gate = { 0.35, 0.25 } }, -- 46 초음파 비명 · 중간 음 · 느리게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.1, gate = { 0.15, 0.1 } }, -- 47 초음파 비명 · 낮은 음 · 빠르게 끊김
	{ fx = "screech", src = "ouch", pitch = 1.1, gate = { 0.35, 0.25 } }, -- 48 초음파 비명 · 낮은 음 · 느리게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.6, gate = { 0.15, 0.1 }, air = "wind" }, -- 49 왜곡 포효 · 높은 음 · 빠르게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.6, gate = { 0.35, 0.25 }, air = "wind" }, -- 50 왜곡 포효 · 높은 음 · 느리게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.45, gate = { 0.15, 0.1 }, air = "wind" }, -- 51 왜곡 포효 · 중간 음 · 빠르게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.45, gate = { 0.35, 0.25 }, air = "wind" }, -- 52 왜곡 포효 · 중간 음 · 느리게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.35, gate = { 0.15, 0.1 }, air = "wind" }, -- 53 왜곡 포효 · 낮은 음 · 빠르게 끊김
	{ fx = "roar", src = "ouch", pitch = 0.35, gate = { 0.35, 0.25 }, air = "wind" }, -- 54 왜곡 포효 · 낮은 음 · 느리게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.5, gate = { 0.15, 0.1 } }, -- 55 저주파 맥동 · 높은 음 · 빠르게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.5, gate = { 0.35, 0.25 } }, -- 56 저주파 맥동 · 높은 음 · 느리게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.35, gate = { 0.15, 0.1 } }, -- 57 저주파 맥동 · 중간 음 · 빠르게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.35, gate = { 0.35, 0.25 } }, -- 58 저주파 맥동 · 중간 음 · 느리게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.28, gate = { 0.15, 0.1 } }, -- 59 저주파 맥동 · 낮은 음 · 빠르게 끊김
	{ fx = "pulse", src = "wind", pitch = 0.28, gate = { 0.35, 0.25 } }, -- 60 저주파 맥동 · 낮은 음 · 느리게 끊김
}
-- END SCREAM RECIPES

-- 고른 시안의 소리·겹침 표를 적용한다(직접 만든 것 > 카탈로그 번호 > 시안 번호 순)
do
	local styles: any = Config.ScreamStyles
	local style: any = styles[Config.ScreamStyle] or styles[1]
	if Config.ScreamCustom then
		style = recipeStyle(Config.ScreamCustom)
	elseif ScreamRecipes[Config.ScreamRecipe] then
		style = recipeStyle(ScreamRecipes[Config.ScreamRecipe])
	end
	-- 실제 녹음 괴성(Config.RealScream): 있으면 위 합성 시안보다 우선
	local real = Config.RealScreams[Config.RealScream]
	if real then
		local id = "rbxassetid://" .. real.Id
		style = {
			Sounds = {
				MonsterChase = { Id = id, Volume = real.Volume * Config.MonsterLoudness, Pitch = 1, Range = Config.MonsterRange, Near = Config.MonsterNear, Cut = real.Dur, Fx = { { "ReverbSoundEffect", { DecayTime = 2.5, WetLevel = -8 } } } },
				MonsterAlert = if real.Layer
					then { Id = "rbxassetid://" .. real.Layer.Id, Volume = real.Layer.Volume * Config.MonsterLoudness, Pitch = 1, Range = Config.MonsterRange, Near = Config.MonsterNear, Cut = real.Layer.Dur }
					else { Id = id, Volume = real.Volume * Config.MonsterLoudness, Pitch = 1, Range = Config.MonsterRange, Near = Config.MonsterNear, Cut = real.Dur }, -- (잡힐 때 점프스케어가 2D 로 튼다: 겹친 비명이 있으면 그 비명)
				MonsterChaseLayer = if real.Layer then { Id = "rbxassetid://" .. real.Layer.Id, Volume = real.Layer.Volume * Config.MonsterLoudness, Pitch = 1, Range = Config.MonsterRange, Near = Config.MonsterNear, Cut = real.Layer.Dur } else { Id = "", Volume = 0, Pitch = 1, Range = 0 },
				MonsterIdle = { Id = "", Volume = 0, Pitch = 1, Range = 0 }, -- 평소에는 소리를 내지 않는다
				MonsterScream2 = { Id = "", Volume = 0, Pitch = 1, Range = 0 },
			},
			-- 추격 괴성: 끊었다 켰다 하며(Config.ScreamGate) 같은 음 높이로
			Screams = { Chase = { { s = "MonsterChase", t = 0, p = 1, v = 1, dur = real.Dur, gate = Config.ScreamGate, start = real.Start } } },
		}
		if real.Layer then
			table.insert(style.Screams.Chase, { s = "MonsterChaseLayer", t = real.Layer.Delay, p = 1, v = 1, start = real.Layer.Start })
		end
	end
	for name, def in style.Sounds do
		(Config.Sounds :: any)[name] = def
	end
	;(Config :: any).Screams = style.Screams
end

-- 태그 이름
-- ─────────────────────────────── 괴물마다 자기 소리 ───────────────────────────────
-- 모든 괴물은 각자의 소리가 있다. 괴물 모델의 Voice 속성(메인 괴물 = 머리 모양 번호 "1"~"5", 도플갱어 = "Doppel")으로 고른다.
-- Freesound 의 CC0(자유 사용) 소리를 계정에 올린 에셋. 목록에 여러 개면 매번 그중 하나.
--   Scream = 쫓아올 때 괴성, Steps = 걸음, Special = 소리를 듣고 멈칫할 때(머리 돌리기·상체 꺾기·씹기), Burst = 도플갱어가 터지며 변신할 때
Config.MonsterVoices = {
	["1"] = { Name = "삼각", Scream = { 120058293974831 }, Steps = { 76678088411883 }, Special = { 76493509944508 } }, -- 발 끌기, 머리 돌 때 뼈 소리
	["2"] = { Name = "사각", Scream = { 105287149316706 }, Steps = { 79801539256457, 128595779168447 }, Special = { 114002785847325 } }, -- 나무 딱딱·삐걱, 상체가 꺾일 때 와르르
	["3"] = { Name = "원", Scream = { 116389741993620 }, Steps = { 134919568490352 }, Special = { 83953676554672 } }, -- 손톱 톡톡, 머리로 씹기
	["4"] = { Name = "별", Scream = { 78248585425234 }, Steps = { 137748804042134 } }, -- 쿵 걸음
	["5"] = { Name = "육각", Scream = { 123342966944903 }, Steps = { 119059498928351 } }, -- 곤충 걸음
	Doppel = { Name = "도플갱어", Scream = { 111740849904916 }, Burst = { 85832788832876, 74039555089610 } }, -- 일그러진 비명(지직 괴성 102508063645161 은 로블록스 검토 거절) / 살 찢어짐 + 뼈 우두둑
	-- 꽃괴물: 깨어날 때 쉿(Special), 꽃잎 펼칠 때 뼈·살(Unfold), 다 펼치면 질척(Squelch, 닫을 때도 낮게), 달려갈 때 괴성, 걸음은 손톱 톡톡을 낮게
	Flower = { Name = "꽃괴물", Scream = { 74933650585675 }, Special = { 132007379899903 }, Unfold = { 103473951609932 }, Squelch = { 125203001018778 }, Steps = { 134919568490352 } },
	-- BEGIN CREATURE VOICES (gen-game.js)
	k1h1 = { Name = "흉문", Scream = { { 91571656965183, 0, 3 } }, Steps = { { 91571656965183, 3.3, 0.8 } }, Special = { { 91571656965183, 4.4, 1.01 } } }, -- 1장 메인 · Freesound CC0 333832/349865/134025
	k1h2 = { Name = "척수", Scream = { { 91571656965183, 5.71, 3 } }, Steps = { { 91571656965183, 9.01, 0.8 } }, Special = { { 91571656965183, 10.11, 1.5 } } }, -- 1장 메인 · Freesound CC0 267179/366111/764458
	k1s1 = { Name = "양두", Scream = { { 91571656965183, 11.91, 3 } }, Steps = { { 91571656965183, 15.21, 0.8 } }, Special = { { 91571656965183, 16.31, 1.5 } } }, -- 1장 서브(near) · Freesound CC0 535095/50725/316797
	k1s2 = { Name = "나무", Scream = { { 91571656965183, 18.11, 3 } }, Steps = { { 91571656965183, 21.41, 0.8 } }, Special = { { 91571656965183, 22.51, 1.5 } } }, -- 1장 서브(freeze) · Freesound CC0 251309/457741/369986
	k2h1 = { Name = "갈고리", Scream = { { 126579656575718, 0, 3 } }, Steps = { { 126579656575718, 3.3, 0.8 } }, Special = { { 126579656575718, 4.4, 1.5 } } }, -- 2장 메인 · Freesound CC0 433735/389990/450509
	k2h2 = { Name = "진열장", Scream = { { 126579656575718, 6.2, 2.463 } }, Steps = { { 126579656575718, 8.963, 0.8 } }, Special = { { 126579656575718, 10.063, 1.5 } } }, -- 2장 메인 · Freesound CC0 85568/19292/453763
	k2s1 = { Name = "다섯 손가락", Scream = { { 126579656575718, 11.863, 3 } }, Steps = { { 126579656575718, 15.163, 0.8 } }, Special = { { 126579656575718, 16.263, 1.5 } } }, -- 2장 서브(blind) · Freesound CC0 398908/452621/417537
	k2s2 = { Name = "가위", Scream = { { 126579656575718, 18.063, 3 } }, Steps = { { 126579656575718, 21.363, 0.8 } }, Special = { { 126579656575718, 22.463, 1.5 } } }, -- 2장 서브(scare) · Freesound CC0 147069/738951/236007
	k3h1 = { Name = "부은 자", Scream = { { 81158456574281, 0, 3 } }, Steps = { { 81158456574281, 3.3, 0.8 } }, Special = { { 81158456574281, 4.4, 1.5 } } }, -- 3장 메인 · Freesound CC0 575314/376809/423959
	k3h2 = { Name = "수초", Scream = { { 81158456574281, 6.2, 3 } }, Steps = { { 81158456574281, 9.5, 0.489 } }, Special = { { 81158456574281, 10.289, 1.5 } } }, -- 3장 메인 · Freesound CC0 268580/495117/162758
	k3s1 = { Name = "아가리", Scream = { { 81158456574281, 12.089, 3 } }, Steps = { { 81158456574281, 15.389, 0.8 } }, Special = { { 81158456574281, 16.489, 1.5 } } }, -- 3장 서브(blind) · Freesound CC0 734900/411206/238258
	k3s2 = { Name = "칠성", Scream = { { 81158456574281, 18.289, 3 } }, Steps = { { 81158456574281, 21.589, 0.8 } }, Special = { { 81158456574281, 22.689, 3 } } }, -- 3장 서브(near) · Freesound CC0 449066/198962/222517
	k4h1 = { Name = "수간호사", Scream = { { 132906482027644, 0, 3 } }, Steps = { { 132906482027644, 3.3, 0.8 } }, Special = { { 132906482027644, 4.4, 1.5 } } }, -- 4장 메인 · Freesound CC0 320740/844745/458424
	k4h2 = { Name = "무영등", Scream = { { 132906482027644, 6.2, 3 } }, Steps = { { 132906482027644, 9.5, 0.8 } }, Special = { { 132906482027644, 10.6, 1.5 } } }, -- 4장 메인 · Freesound CC0 483634/837389/577277
	k4h3 = { Name = "폐", Scream = { { 132906482027644, 12.4, 3 } }, Steps = { { 132906482027644, 15.7, 0.8 } }, Special = { { 132906482027644, 16.8, 3 } } }, -- 4장 메인 · Freesound CC0 590135/240732/703025
	k4s1 = { Name = "바퀴", Scream = { { 132906482027644, 20.1, 3 } }, Steps = { { 132906482027644, 23.4, 0.273 } }, Special = { { 132906482027644, 23.973, 1.5 } } }, -- 4장 서브(blind) · Freesound CC0 661211/57642/336328
	k4s2 = { Name = "거꾸로 기는 환자", Scream = { { 132906482027644, 25.773, 3 } }, Steps = { { 132906482027644, 29.073, 0.8 } }, Special = { { 132906482027644, 30.173, 0.692 } } }, -- 4장 서브(freeze) · Freesound CC0 520286/260824/578874
	k4s3 = { Name = "뒤집힌 환자", Scream = { { 132906482027644, 31.165, 3 } }, Steps = { { 132906482027644, 34.465, 0.8 } }, Special = { { 132906482027644, 35.565, 3 } } }, -- 4장 서브(scare) · Freesound CC0 240091/352870/65401
	k4s4 = { Name = "합본", Scream = { { 132906482027644, 38.865, 3 } }, Steps = { { 132906482027644, 42.165, 0.8 } }, Special = { { 132906482027644, 43.265, 1.5 } } }, -- 4장 서브(near) · Freesound CC0 140256/481862/397994
	k5h1 = { Name = "길잡이", Scream = { { 139570916666564, 0, 3 } }, Steps = { { 139570916666564, 3.3, 0.8 } }, Special = { { 139570916666564, 4.4, 0.251 } } }, -- 5장 메인 · Freesound CC0 345645/616615/389590
	k5h2 = { Name = "나선", Scream = { { 139570916666564, 4.951, 3 } }, Steps = { { 139570916666564, 8.251, 0.8 } }, Special = { { 139570916666564, 9.351, 1.5 } } }, -- 5장 메인 · Freesound CC0 170454/175215/169727
	k5s1 = { Name = "웅크린 것", Scream = { { 139570916666564, 11.151, 0.278 } }, Steps = { { 139570916666564, 11.729, 0.8 } }, Special = { { 139570916666564, 12.829, 1.5 } } }, -- 5장 서브(scare) · Freesound CC0 760564/175226/655333
	k5s2 = { Name = "끼인 것", Scream = { { 139570916666564, 14.629, 3 } }, Steps = { { 139570916666564, 17.929, 0.8 } }, Special = { { 139570916666564, 19.029, 1.5 } } }, -- 5장 서브(freeze) · Freesound CC0 321464/500009/243699
	k5s3 = { Name = "청음귀", Scream = { { 139570916666564, 20.829, 3 } }, Steps = { { 139570916666564, 24.129, 0.8 } }, Special = { { 139570916666564, 25.229, 3 } } }, -- 5장 서브(blind) · Freesound CC0 171945/465358/419748
	k6h1 = { Name = "무도회", Scream = { { 75782061847063, 0, 3 } }, Steps = { { 75782061847063, 3.3, 0.8 } }, Special = { { 75782061847063, 4.4, 3 } } }, -- 6장 메인 · Freesound CC0 278903/392482/150025
	k6h2 = { Name = "벨보이", Scream = { { 75782061847063, 7.7, 3 } }, Steps = { { 75782061847063, 11, 0.8 } }, Special = { { 75782061847063, 12.1, 1.5 } } }, -- 6장 메인 · Freesound CC0 329867/712066/116779
	k6h3 = { Name = "지배인", Scream = { { 75782061847063, 13.9, 0.485 } }, Steps = { { 75782061847063, 14.685, 0.8 } }, Special = { { 75782061847063, 15.785, 1.5 } } }, -- 6장 메인 · Freesound CC0 502211/659370/240549
	k6s1 = { Name = "여행가방", Scream = { { 75782061847063, 17.585, 2.168 } }, Steps = { { 75782061847063, 20.053, 0.8 } }, Special = { { 75782061847063, 21.153, 1.5 } } }, -- 6장 서브(freeze) · Freesound CC0 166156/588655/180686
	k6s2 = { Name = "반쪽", Scream = { { 75782061847063, 22.953, 0.734 } }, Steps = { { 75782061847063, 23.987, 0.8 } }, Special = { { 75782061847063, 25.087, 0.438 } } }, -- 6장 서브(near) · Freesound CC0 244690/431541/824189
	k6s3 = { Name = "욕조", Scream = { { 75782061847063, 25.825, 3 } }, Steps = { { 75782061847063, 29.125, 0.8 } }, Special = { { 75782061847063, 30.225, 1.5 } } }, -- 6장 서브(blind) · Freesound CC0 161691/432821/382649
	k6s4 = { Name = "젖은 투숙객", Scream = { { 75782061847063, 32.025, 3 } }, Steps = { { 75782061847063, 35.325, 0.8 } }, Special = { { 75782061847063, 36.425, 3 } } }, -- 6장 서브(scare) · Freesound CC0 157835/531725/456771
	k7h1 = { Name = "복도 끝 그 애", Scream = { { 114174835468486, 0, 2.926 } }, Steps = { { 114174835468486, 3.226, 0.8 } }, Special = { { 114174835468486, 4.326, 1.5 } } }, -- 7장 메인 · Freesound CC0 377742/613747/378394
	k7h2 = { Name = "걸상", Scream = { { 114174835468486, 6.126, 3 } }, Steps = { { 114174835468486, 9.426, 0.8 } }, Special = { { 114174835468486, 10.526, 0.414 } } }, -- 7장 메인 · Freesound CC0 486289/569255/379924
	k7h3 = { Name = "저요", Scream = { { 114174835468486, 11.24, 3 } }, Steps = { { 114174835468486, 14.54, 0.8 } }, Special = { { 114174835468486, 15.64, 3 } } }, -- 7장 메인 · Freesound CC0 438421/262507/736924
	k7h4 = { Name = "술래", Scream = { { 114174835468486, 18.94, 3 } }, Steps = { { 114174835468486, 22.24, 0.8 } }, Special = { { 114174835468486, 23.34, 1.5 } } }, -- 7장 메인 · Freesound CC0 483157/51148/151219
	k7s1 = { Name = "인체모형", Scream = { { 114174835468486, 25.14, 3 } }, Steps = { { 114174835468486, 28.44, 0.765 } }, Special = { { 114174835468486, 29.505, 0.976 } } }, -- 7장 서브(freeze) · Freesound CC0 320345/529245/278205
	k7s2 = { Name = "판서", Scream = { { 114174835468486, 30.781, 3 } }, Steps = { { 114174835468486, 34.081, 0.8 } }, Special = { { 114174835468486, 35.181, 1.5 } } }, -- 7장 서브(near) · Freesound CC0 445138/735343/365892
	k7s3 = { Name = "풍금", Scream = { { 114174835468486, 36.981, 3 } }, Steps = { { 114174835468486, 40.281, 0.8 } }, Special = { { 114174835468486, 41.381, 3 } } }, -- 7장 서브(blind) · Freesound CC0 569857/502507/166748
	k8h1 = { Name = "토끼", Scream = { { 106197945666716, 0, 3 } }, Steps = { { 106197945666716, 3.3, 0.8 } }, Special = { { 106197945666716, 4.4, 0.44 } } }, -- 8장 메인 · Freesound CC0 20208/504626/468443
	k8h2 = { Name = "토끼 선생님", Scream = { { 106197945666716, 5.14, 0.879 } }, Steps = { { 106197945666716, 6.319, 0.8 } }, Special = { { 106197945666716, 7.419, 1.5 } } }, -- 8장 메인 · Freesound CC0 677660/862960/157873
	k8h3 = { Name = "미끄럼틀", Scream = { { 106197945666716, 9.219, 3 } }, Steps = { { 106197945666716, 12.519, 0.8 } }, Special = { { 106197945666716, 13.619, 1.5 } } }, -- 8장 메인 · Freesound CC0 512966/435210/412394
	k8s1 = { Name = "누더기", Scream = { { 106197945666716, 15.419, 3 } }, Steps = { { 106197945666716, 18.719, 0.8 } }, Special = { { 106197945666716, 19.819, 1.5 } } }, -- 8장 서브(scare) · Freesound CC0 346663/245937/646047
	k8s2 = { Name = "흔들말", Scream = { { 106197945666716, 21.619, 3 } }, Steps = { { 106197945666716, 24.919, 0.8 } }, Special = { { 106197945666716, 26.019, 0.26 } } }, -- 8장 서브(freeze) · Freesound CC0 59569/124972/364704
	k8s3 = { Name = "모빌", Scream = { { 106197945666716, 26.579, 3 } }, Steps = { { 106197945666716, 29.879, 0.8 } }, Special = { { 106197945666716, 30.979, 3 } } }, -- 8장 서브(near) · Freesound CC0 457294/772279/163644
	k8s4 = { Name = "큰 인형", Scream = { { 106197945666716, 34.279, 0.652 } }, Steps = { { 106197945666716, 35.231, 0.8 } }, Special = { { 106197945666716, 36.331, 1.5 } } }, -- 8장 서브(blind) · Freesound CC0 418194/553899/415278
	k9h1 = { Name = "키다리", Scream = { { 113939796310653, 0, 3 } }, Steps = { { 113939796310653, 3.3, 0.8 } }, Special = { { 113939796310653, 4.4, 1.5 } } }, -- 9장 메인 · Freesound CC0 869056/622737/104373
	k9h2 = { Name = "치인 자", Scream = { { 113939796310653, 6.2, 1.964 } }, Steps = { { 113939796310653, 8.464, 0.8 } }, Special = { { 113939796310653, 9.564, 1.5 } } }, -- 9장 메인 · Freesound CC0 104026/221650/237375
	k9h3 = { Name = "압축", Scream = { { 113939796310653, 11.364, 3 } }, Steps = { { 113939796310653, 14.664, 0.8 } }, Special = { { 113939796310653, 15.764, 3 } } }, -- 9장 메인 · Freesound CC0 231347/481926/51044
	k9s1 = { Name = "차밑", Scream = { { 113939796310653, 19.064, 3 } }, Steps = { { 113939796310653, 22.364, 0.8 } }, Special = { { 113939796310653, 23.464, 0.407 } } }, -- 9장 서브(near) · Freesound CC0 837986/243400/170243
	k9s2 = { Name = "덮개", Scream = { { 113939796310653, 24.171, 0.409 } }, Steps = { { 113939796310653, 24.88, 0.8 } }, Special = { { 113939796310653, 25.98, 1.5 } } }, -- 9장 서브(freeze) · Freesound CC0 445958/19295/558749
	k9s3 = { Name = "전조등", Scream = { { 113939796310653, 27.78, 3 } }, Steps = { { 113939796310653, 31.08, 0.8 } }, Special = { { 113939796310653, 32.18, 1.5 } } }, -- 9장 서브(scare) · Freesound CC0 273334/390798/182474
	k9s4 = { Name = "보닛", Scream = { { 113939796310653, 33.98, 3 } }, Steps = { { 113939796310653, 37.28, 0.8 } }, Special = { { 113939796310653, 38.38, 1.5 } } }, -- 9장 서브(blind) · Freesound CC0 125211/108673/329516
	k10h1a = { Name = "뜬눈", Scream = { { 105296463212360, 0, 3 } }, Steps = { { 105296463212360, 3.3, 0.8 } }, Special = { { 105296463212360, 4.4, 0.351 } } }, -- 10장 메인 · Freesound CC0 840311/142008/445109
	k10h1b = { Name = "뜬눈", Scream = { { 105296463212360, 5.051, 3 } }, Steps = { { 105296463212360, 8.351, 0.8 } }, Special = { { 105296463212360, 9.451, 1.5 } } }, -- 10장 메인 · Freesound CC0 829399/191513/232130
	k10h1c = { Name = "뜬눈", Scream = { { 105296463212360, 11.251, 3 } }, Steps = { { 105296463212360, 14.551, 0.8 } }, Special = { { 105296463212360, 15.651, 1.5 } } }, -- 10장 메인 · Freesound CC0 813270/702293/698818
	k10s1 = { Name = "잔상", Scream = { { 105296463212360, 17.451, 3 } }, Steps = { { 105296463212360, 20.751, 0.8 } }, Special = { { 105296463212360, 21.851, 1.5 } } }, -- 10장 서브(scare) · Freesound CC0 520147/508673/534695
	k10s2 = { Name = "만석", Scream = { { 105296463212360, 23.651, 3 } }, Steps = { { 105296463212360, 26.951, 0.8 } }, Special = { { 105296463212360, 28.051, 1.5 } } }, -- 10장 서브(freeze) · Freesound CC0 196099/584864/570312
	k10s3 = { Name = "영사기사", Scream = { { 105296463212360, 29.851, 3 } }, Steps = { { 105296463212360, 33.151, 0.8 } }, Special = { { 105296463212360, 34.251, 3 } } }, -- 10장 서브(near) · Freesound CC0 391552/339114/253758
	-- END CREATURE VOICES
}
-- 소리 종류별 크기(괴성은 Config.MonsterLoudness 배)·자르는 길이(초)
Config.VoiceMix = {
	Scream = { Volume = 1.0, Cut = 3.5 },
	Steps = { Volume = 0.7, Cut = 1.2 },
	Special = { Volume = 0.9, Cut = 2.5 },
	Burst = { Volume = 1.2, Cut = 2.5 },
	Unfold = { Volume = 1.0, Cut = 1.3 },
	Squelch = { Volume = 1.0, Cut = 1.0 },
}
-- 메인 괴물(Voice "1"~"5")의 소리만 이만큼 더 크게(괴성·걸음·특수 동작 모두). 서브 괴물(도플갱어·꽃괴물)은 그대로
Config.MainVoiceBoost = 1.4
for v, def in Config.MonsterVoices do
	local boost = if tonumber(v) ~= nil then Config.MainVoiceBoost else 1
	for kind, mix in Config.VoiceMix do
		local ids = (def :: any)[kind]
		if ids then
			for k, id in ids do
				local loud = (if kind == "Scream" or kind == "Burst" or kind == "Unfold" then Config.MonsterLoudness else 1) * boost
				-- 챕터 소리 묶음이면 { 에셋, 시작, 길이 }: 그 구간만
				local pack = if type(id) == "table" then id :: any else nil
				;(Config.Sounds :: any)["Voice_" .. v .. "_" .. kind .. "_" .. k] = {
					Id = "rbxassetid://" .. (if pack then pack[1] else id),
					Region = if pack then { pack[2], pack[2] + pack[3] } else nil,
					Volume = mix.Volume * loud,
					Pitch = (def :: any).Pitch or 1, -- (챕터 괴물: 몸 크기에 맞춘 음 높이)
					Range = if kind == "Steps" then 120 else Config.MonsterRange,
					Near = if kind == "Steps" then 10 else Config.MonsterNear,
					Cut = mix.Cut,
				}
			end
		end
	end
end

Config.Tags = {
	Renderable = "SonarRenderable", -- 이 태그가 붙은 파트(또는 모델 안 파트)는 음파 윤곽선 대상
	Dynamic = "SonarDynamic", -- 움직이는 대상(문, 괴물): 음파가 닿는 순간의 모습으로 선을 만든다
	Door = "SonarDoor",
	Monster = "Monster",
	Doppel = "Doppel", -- 도플갱어(Monster 태그도 함께 붙는다)
	Flower = "Flower", -- 꽃괴물(Monster 태그도 함께 붙는다)
	AmbientEmitter = "AmbientEmitter",
	HideSpot = "HideSpot",
	SearchSpot = "SearchSpot",
}

return Config
