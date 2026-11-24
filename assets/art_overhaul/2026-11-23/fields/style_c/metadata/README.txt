필드 아트 C 스타일 리워크 / 2026-11-23
적용 프로젝트: 크로노 체인 동방 버전. StoryRouter.TUTORIAL -> scenes/main/main.tscn에서 적용 확인.
배경: C 후보의 compact 비율, 풍부한 색상단계, 둥근 실루엣에 맞춘 새 게임용 소재.
source/props.png: 내장 image_gen 생성20종 소품/건축물 원본. runtime에는 사용19종과 예비planter 보관.
source/floors.png: 새 바닥6종 원본. runtime: paving,cobble,asphalt,concrete,roof,water.
props: bakery,shop,house,warehouse,fountain,arch,crate,lamp,bench,tree,factory,workshop,servicehouse,junk,wall_dark,wall_warm,manhole,puddle,drain.
캐릭터: assets/character_overhaul/2026-11-23/field_c/에 원본/게임용 걷기 및 추흔8방향 체인 포즈 보관.
캐릭터 실제 높이약24 world px, 기존16px 타일1.5칸. 문/가로등/건물 색상과 세부단계 함께 조정.
night_layout_snapshot.json: 이번 작업 전 실제 지형과 오브젝트 좌표. 변경 없음.
조명: 기존 연속경계/점등전 어둠/점등후 푸른시야 보존. hanging lamp에 맞춰 발광 위치 조정.
전투: 직전 실패한v004스텝/라소모션 제거. v003 대기/일반공격 복구. 대각선배치/표시크기 유지.
검증: field_style_c_test11/11, character_overhaul_test213/213, tutorial_test29/29.
field_party_test는 병렬실행시 입력해제 assertion이 한차례 발생하여 단독 재실행, 전체 통과.
registered_field_style_c_test: 등록프로젝트 튜토리얼의 두캐릭터/새맵/전투롤백경로 확인.
review: 08-style-c-street.png, 01-plaza.png, 02-dark-off.png, 03-dark-on.png, 04-boundary.png, 05-overview.png.
