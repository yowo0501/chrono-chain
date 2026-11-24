# 필드 체인과 연우 대기 모션 — 2026-11-16

기존 그림체·걷기·스탠딩을 유지하면서 요청한 동작만 수정했다.

추흔의 필드 체인은 **0.5초 동작 + 0.25초 후딜**, 사거리 **4칸**이다. 정지·걷기 그림을 기울이는 대신, 기존 `chuheun_night.png`를 기준으로 내장 이미지 생성 도구에서 전용 준비·당기기·들기·방출·회수·복귀 6프레임을 만들었다. 네 방향 총 24포즈이며 대각선은 현재 필드와 동일하게 좌우 방향 원화를 사용한다.

원화는 `assets/sprites/field-chain/source/chuheun.png`, 실행 아틀라스는 `assets/sprites/field-chain/chuheun.png`, 생성 요청문은 `assets/sprites/field-chain/prompts.json`에 있다. `tools/pack_field_chain.gd`가 96×96 셀에 원본 필드와 같은 배율·발 위치로 등록한다. 각 프레임의 사슬 끝 좌표는 `anchors.json`에 저장한다.

짧은 사슬은 전용 프레임에 포함되어 준비 동작부터 손목에 붙어 있다. 긴 체인은 방출 순간 그 끝에서 이어진다. 0~0.25초는 준비, 약 0.32초에 최대 사거리, 0.45초까지 회수하고 0.5초에 정지 자세로 복귀한다. 발사 전 타격 방지, 벽 차단, 선제권, 이동 중 입력 예약은 유지한다.

연우의 대기는 후속 요청으로 원래의 작은 발끝 까딱임으로 복귀했다. 졸음·하품 연출은 제외했다. 현재 규격은 [연우 대기 모션](YEONWOO_IDLE.md)을 따른다.

`tests/duo_overhaul_test.gd`는 전용 프레임 연결·발 정렬·동작 시간과 연우의 연속 움직임을 검사한다. `tests/field_gimmicks_test.gd`는 실제 범위·명중 시점·후딜을 검사한다. `tests/preview_chain_swing.gd`는 실제 게임에서 캡처하며 결과는 `art-reviews/chain-swing/`에 있다.
