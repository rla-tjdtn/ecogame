--!strict
-- 게임 전체 설정값. 숫자는 모두 여기서 조정한다.
-- (ReplicatedStorage.Shared.Config — 서버와 클라이언트가 같이 읽는다)

local Config = {}

-- ─────────────────────────────── 음파 ───────────────────────────────
Config.Sonar = {
	Radius = 35, -- 음파가 퍼지는 최대 거리(스터드, 벽을 돌아가는 경로 길이 기준)
	Cooldown = 1.5, -- 발사 간격(초) — 서버가 같은 값으로 검증한다
	ServerTolerance = 0.12, -- 네트워크 지연 허용치(초)
	WaveSpeed = 40, -- 파동 전진 속도(스터드/초): 35스터드 끝까지 약 0.9초
	Hold = 3.5, -- 선이 나타난 뒤 완전히 사라질 때까지(초)
	FadeTime = 1.2, -- Hold 끝부분에서 서서히 사라지는 구간(초)
	FlashTime = 0.15, -- 파동이 지나가는 순간 살짝 더 밝은 구간(초)
	BaseLevel = 0.8, -- 플래시 이후 선 밝기(0~1)
	FarLevel = 0.45, -- 반경 끝에 있는 선의 밝기 배율(가까울수록 1)
	LineColor = Color3.fromRGB(235, 235, 235),
	-- 선 굵기: 카메라와의 거리에 비례해 화면상 굵기가 거의 일정하게 보이도록
	LineMinWidth = 0.035,
	LineWidthPerStud = 0.0021,
	LineMaxWidth = 0.12,
	SegmentLength = 2.5, -- 긴 모서리를 이 길이 이하로 잘라 가까운 쪽부터 그려지게 한다
	CellSize = 2, -- 파동 전파용 복셀 크기(스터드)
	AttachDistance = 2.6, -- 선분이 이 거리 안의 빈 복셀을 통해 음파를 받는다
	PoolSize = 4500, -- 동시에 존재할 수 있는 선 파트 최대 수(재사용)
	RemoteViewDistance = 110, -- 다른 플레이어 음파를 그리는 최대 거리
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
}

-- ─────────────────────────── 소리(괴물이 듣는 범위) ───────────────────────────
Config.Noise = {
	Crouch = 4,
	Walk = 10,
	Run = 25,
	Sonar = 45,
	Door = 16,
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
	WanderSpeed = 3.5, -- 아주 천천히(플레이어는 길을 찾으며 도망가야 한다)
	InvestigateSpeed = 5.5,
	ChaseSpeed = 8.5, -- 걷기(10)보다도 느리다: 막다른 길·정면으로 마주칠 때 잡힌다
	SightRange = 15, -- 시야(어둠 속 감각) 거리
	SightRangeCrouch = 7,
	SenseRange = 4.5, -- 이 거리 안이면 시야와 상관없이 알아챈다
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
	LegTiles = 8, -- 먼 길은 타일 경로를 따라 이만큼(칸)씩 나눠 경로를 계산한다
}

-- ─────────────────────────────── 라운드 ───────────────────────────────
Config.Round = {
	FirstStartDelay = 2,
	ResultSeconds = 7, -- 클리어/실패 화면 뒤 다음 스테이지까지
	DeadBodyLinger = 0.6,
}

-- ─────────────────────────────── 스테이지 ───────────────────────────────
-- Module 은 ServerScriptService.Server.Stages 안의 레이아웃 모듈 이름
-- 로비·방
Config.Lobby = {
	MaxPlayers = 4, -- 방 하나 최대 인원
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

Config.Stages = {
	{ Id = 1, Name = "STAGE 1 — 지하 시설", Module = "Stage1", Monsters = 1 },
	{ Id = 2, Name = "STAGE 2 — 물류 창고", Module = "Stage2", Monsters = 2 },
	{ Id = 3, Name = "STAGE 3 — 하수도", Module = "Stage3", Monsters = 2 },
	{ Id = 4, Name = "STAGE 4 — 폐병원", Module = "Stage4", Monsters = 3 },
	{ Id = 5, Name = "STAGE 5 — 심층 미로", Module = "Stage5", Monsters = 4 },
}

-- ─────────────────────────────── 사운드 ───────────────────────────────
-- 기본값은 Roblox 클라이언트에 기본 포함된 rbxasset:// 파일만 쓴다(외부 에셋 ID 없음).
-- 더 어울리는 소리가 있으면 Id 를 "rbxassetid://숫자" 로 바꾸면 된다. Id = "" 이면 그 소리는 재생하지 않는다.
Config.Sounds = {
	-- 발소리 파일에는 여러 발짝이 들어 있어 Cut 초만 재생해 한 발짝만 낸다
	FootWalk = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.35, Pitch = 0.85, Range = 40, Cut = 0.2 },
	FootRun = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.6, Pitch = 0.95, Range = 70, Cut = 0.17 },
	FootCrouch = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.12, Pitch = 0.75, Range = 18, Cut = 0.22 },
	Sonar = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.9, Pitch = 0.35, Range = 90 },
	SonarEcho = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.35, Pitch = 0.28, Range = 90 },
	Door = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.8, Pitch = 0.55, Range = 60 },
	MonsterStep = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.9, Pitch = 0.5, Range = 95 },
	MonsterIdle = { Id = "rbxasset://sounds/oof.ogg", Volume = 0.55, Pitch = 0.32, Range = 70 },
	MonsterAlert = { Id = "rbxasset://sounds/ouch.ogg", Volume = 0.8, Pitch = 0.4, Range = 90 },
	MonsterChase = { Id = "rbxasset://sounds/ouch.ogg", Volume = 1.0, Pitch = 0.27, Range = 110 },
	AmbientHum = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.18, Pitch = 0.22, Range = 0 }, -- 환풍기·배관 진동(루프)
	AmbientFan = { Id = "rbxasset://sounds/action_falling.ogg", Volume = 0.5, Pitch = 0.4, Range = 45 }, -- 맵 안 환풍기 위치(루프)
	AmbientDrip = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.25, Pitch = 2.2, Range = 60 },
	AmbientMetal = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.22, Pitch = 0.35, Range = 160 },
	AmbientCreak = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.25, Pitch = 0.3, Range = 120 },
	AmbientWater = { Id = "rbxasset://sounds/action_swim.mp3", Volume = 0.35, Pitch = 0.6, Range = 50 }, -- 하수도 물 흐름(루프)
}

-- 태그 이름
Config.Tags = {
	Renderable = "SonarRenderable", -- 이 태그가 붙은 파트(또는 모델 안 파트)는 음파 윤곽선 대상
	Dynamic = "SonarDynamic", -- 움직이는 대상(문, 괴물): 음파가 닿는 순간의 모습으로 선을 만든다
	Door = "SonarDoor",
	Monster = "Monster",
	AmbientEmitter = "AmbientEmitter",
	HideSpot = "HideSpot",
}

return Config
