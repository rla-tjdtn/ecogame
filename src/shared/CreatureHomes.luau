--!strict
-- 자동 생성(art/creatures/source/game/gen-game.js ← homes.json): 서브 괴물마다 역할에 맞는 자기 자리.
-- rect = 맵 칸 좌표 { x0, y0, x1, y1 }(1부터, 끝 포함, 1칸 = 8스터드). band = "upper"(2층) / "lower"(아래층) / nil(층 구분 없음).
-- prop = 맵에 없어서 그 자리에 더 놓는 소품(Server/HomeProps)
return {
	k1s1 = { rect = { 15, 24, 27, 36 }, band = nil, prop = nil }, -- 구덩이 작업장 · 정비 구덩이와 다리 둘레
	k1s2 = { rect = { 30, 27, 40, 36 }, band = nil, prop = nil }, -- 냉각 배관 구역 · 배관 벽이 줄지어 선 좁은 통로
	k2s1 = { rect = { 10, 21, 17, 28 }, band = nil, prop = nil }, -- 아래 보관동 B' · 선반 줄(H) 사이 통로
	k2s2 = { rect = { 1, 1, 7, 4 }, band = "upper", prop = nil }, -- 2층 관리 사무실 · 2층 사무실 책상 구역
	k3s1 = { rect = { 17, 28, 27, 31 }, band = nil, prop = nil }, -- 침사지 · 저수조 남쪽 막다른 침사 웅덩이
	k3s2 = { rect = { 29, 24, 40, 31 }, band = nil, prop = nil }, -- 침전조 · 침전 물길과 기둥(O) 사이
	k4s1 = { rect = { 12, 12, 18, 16 }, band = "upper", prop = nil }, -- 엘리베이터 홀 · 병동 2층 엘리베이터 홀(기계 m, 복도로 트임)
	k4s2 = { rect = { 7, 36, 14, 41 }, band = nil, prop = nil }, -- 영안실 · 시신 냉장고(k) 줄과 안치대(R)
	k4s3 = { rect = { 16, 36, 22, 41 }, band = nil, prop = nil }, -- 수술실 · 수술대 구역
	k4s4 = { rect = { 29, 36, 36, 41 }, band = nil, prop = nil }, -- 회복실 · 침대 줄
	k5s1 = { rect = { 17, 4, 27, 8 }, band = nil, prop = nil }, -- 열주실 · 굵은 기둥(B) 숲
	k5s2 = { rect = { 2, 14, 2, 21 }, band = nil, prop = nil }, -- 좁은 서쪽 통로 · x2 한 줄 통로(양옆 벽)
	k5s3 = { rect = { 4, 20, 18, 22 }, band = nil, prop = nil }, -- 구덩이 옆 넓은 홀 · 구덩이 아래 빈 넓은 공간
	k6s1 = { rect = { 36, 25, 41, 27 }, band = nil, prop = nil }, -- 짐 보관실 · 짐 상자(c) 쌓인 방
	k6s2 = { rect = { 14, 21, 17, 24 }, band = "upper", prop = nil }, -- 커넥팅 룸 · 객실(샛문으로 아래 방과 연결)
	k6s3 = { rect = { 1, 12, 8, 18 }, band = nil, prop = "Bathtub" }, -- 세탁실 · 세탁기 줄
	k6s4 = { rect = { 22, 10, 25, 12 }, band = "upper", prop = nil }, -- 제빙·자판기실 · 코어 안 제빙기 방
	k7s1 = { rect = { 4, 22, 10, 27 }, band = "upper", prop = nil }, -- 과학실 · 과학실 앞쪽
	k7s2 = { rect = { 11, 15, 16, 20 }, band = "upper", prop = "Blackboard" }, -- 2-2 교실 · 교실 앞 교탁·칠판 쪽
	k7s3 = { rect = { 16, 22, 21, 27 }, band = "upper", prop = "Organ" }, -- 음악실 · 음악실 중앙
	k8s1 = { rect = { 1, 1, 6, 7 }, band = nil, prop = nil }, -- 교재 창고 · 상자(c) 쌓인 막다른 방
	k8s2 = { rect = { 17, 23, 30, 30 }, band = nil, prop = nil }, -- 실내 놀이터 · 미끄럼틀·정글짐 큰 공간
	k8s3 = { rect = { 1, 23, 7, 30 }, band = nil, prop = "CribMobile" }, -- 낮잠방 · 낮잠 매트(N) 줄
	k8s4 = { rect = { 17, 12, 23, 18 }, band = nil, prop = nil }, -- 별님반 · 교실
	k9s1 = { rect = { 12, 9, 26, 10 }, band = nil, prop = nil }, -- 북쪽 주차 줄 · 주차된 차(Q) 줄, y9~10
	k9s2 = { rect = { 1, 16, 1, 26 }, band = "lower", prop = "HangBar" }, -- 서쪽 배관 통로 · 지하2층 서쪽 끝 한 줄 통로(천장 배관)
	k9s3 = { rect = { 4, 18, 22, 19 }, band = "lower", prop = nil }, -- 지하2층 주차 줄 · 주차된 차(K) 줄, y18~19
	k9s4 = { rect = { 11, 12, 26, 13 }, band = nil, prop = nil }, -- 북쪽 아래 주차 줄 · 주차된 차(Q) 줄, y12~13
	k10s1 = { rect = { 22, 4, 24, 8 }, band = "upper", prop = nil }, -- 필름 보관실 · 필름 보관 작은 방
	k10s2 = { rect = { 27, 19, 34, 24 }, band = nil, prop = nil }, -- 3관 · 좌석 줄(u)
	k10s3 = { rect = { 26, 4, 34, 8 }, band = "upper", prop = nil }, -- 영사실 3 · 긴 영사실
}
