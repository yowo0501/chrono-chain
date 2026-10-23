# 필드 아트 및 이동 테스트

## 현재 적용본: 128×64 밤의 도시, 64px 필드 스프라이트

- 완전한 2D를 유지하며 밤 도시로 재설계했다. 푸른 회색 석재와 지붕, 따뜻한 창문·빵집·가로등, 청록 분수와 강변을 사용한다. 화단은 없다.
- 16개 연결된 불규칙 에어리어, 수작업으로 배치한 큰 광장/상업길/골목/공터 및 서로 다른 폭의 연결로다. 배치와 충돌은 `data/field_map.json`, 재생성은 `tools/build_night_dungeon.py`다.
- 추흔은 내장 **ImageGen 편집 모드**로 기존 SD 외형을 유지하면서 입을 다문 작은 미소로 수정했다. 원본: `assets/sprites/field/chuheun_night_source.png`.
- 게임용 캐릭터 시트: `assets/sprites/field/chuheun_night.png`, `yeonwoo_night.png`, `shadow_night.png`, `boss_night.png`. 각 192×256, **64px 고정 셀 3열×4행**. 연우·적·보스는 기존 고해상도 생성 원본에서 다시 추출했다. 기존 32px 시트를 단순 확대하지 않았다.
- `tools/prepare_night_field.gd`는 공통 배율과 발 기준선(62행), 방향별 공통 상단 32행을 사용한다. 월드에서는 16×16 논리 칸에 표시하고 카메라/포즈마다 배율을 바꾸지 않는다.
- 내장 **ImageGen 생성 모드**의 배경 원본: `assets/tilesets/night_town_source.png`. 최종 자산: 같은 폴더 `night_bakery.png`, `night_shop.png`, `night_house.png`, `night_warehouse.png`, `night_fountain.png`, `night_arch.png`, `night_crate.png`, `night_lamp.png`, `night_bench.png`. 투명 알파를 유지한다.
- 원본 프롬프트 세트: `tools/night_city_image_prompts.json`. 오프라인 추출: `tools/prepare_night_town.gd`. 지면은 코드로 만든 32px 석재·흙·물 타일을 사용한다. 필드 표현은 `scripts/field_2d.gd`다.
- 어둠의 가로등은 `field_darkness.gd`의 파란 실루엣/빛으로 유지한다. 일반 적은 어둠에 숨겨지고 파티는 계속 보인다. 큰 맵의 어둠 마스크는 화면 안의 칸만 그린다.
- 실게임 캡처: `tests/preview-night-plaza.png`, `preview-night-bakery.png`, `preview-night-dark.png`, `preview-night-map.png`, `preview-night-walk.gif`. `preview-night-layout.png`만 검수용 전체 점등 상태다.
- 새 규칙과 검사 목록은 [맵 시스템](MAP_SYSTEM.md)에 있다. 아래는 이전 제작 기록이며 현재 적용값이 아니다.

## 이전 적용본: 완전한 2D 마을, 화단 삭제 (2026-10-20 후속 수정)

- 사용자의 후속 요청을 우선하여 실제 실행 씬에서 3D 디오라마를 제거했다. `scripts/field_2d.gd`와 `Camera2D`만으로 회전 없는 2D 맵을 표시한다. 실행 중 Node3D, Camera3D, SubViewport를 만들지 않는다.
- 하트골드풍 집 2종, 나무, 생울타리, 돌담, 가로등을 새 도트 이미지로 제작했다. 지면은 잔디·흙길·중앙 광장 타일로 구분한다. 충돌과 화면은 같은 16px 좌표를 사용하며, 새 건물과 나무가 이동 가능 칸을 막지 않는다.
- 화단은 그림·타일 데이터·충돌·조사 안내·적 은신·자동 소등에서 모두 제거했다. 기존 화단 자리는 걸을 수 있다. 밝은 구역의 적은 길 위에서 도망가며, 주변에 어둠이 있으면 그쪽으로 이동한다.
- 50×30칸의 확대 크기, 12개 구역, 5개 심볼, 네 방향 캐릭터 시트와 0.24초 연속 이동은 유지한다. 2D 카메라의 위·아래 끝에 HUD 여백을 두어 경계의 건물과 길이 가려지지 않게 했다.
- 내장 ImageGen 생성 원본: `assets/tilesets/hg_town_source.png`. 게임용 시트: `assets/tilesets/hg_town.png` (192×128, 64px 고정 셀 6개). 프롬프트: `tools/hg_town_image_prompt.json`. 가공: `tools/prepare_hg_town.gd`.
- 실제 화면: `tests/preview-hg2d-town.png`, `tests/preview-hg2d-start.png`, `tests/preview-hg2d-dark.png`, `tests/preview-hg2d-overview.png`. 재생성: `tests/preview_hg2d.gd`.
- 검사: `tests/field_2d_test.gd`, `tests/field_party_test.gd`, `tests/map_system_test.gd`, `tests/oct20_update_test.gd`. 이전 `diorama_test.gd` 진입점도 현재 2D 검사를 실행하도록 연결했다.
- 아래 항목은 이전 작업 기록이다. 렌더링과 화단 규칙은 이 후속 수정이 우선한다. 옛 3D 제작 코드는 보관만 하며 실행 씬에서는 사용하지 않는다.

## 이전 적용본: 하트골드 참고 도트 + 확대 맵 (2026-10-20)

- 사용자 요청에 따라 이전 C타입을 새 하트골드 참고 필드 시트로 교체했다. 추흔(웃는 얼굴), 연우(차분한 얼굴), 그림자, 보스 네 종류다. 원래 캐릭터의 머리·의상·색을 유지하며 DS 시대의 큰 머리와 짧은 팔다리, 단순한 윤곽, 선명한 도트로 새로 제작했다.
- 적용 파일: `assets/sprites/field/chuheun_hg.png`, `yeonwoo_hg.png`, `shadow_hg.png`, `boss_hg.png`. 각 96×128px 시트, 32×32px 고정 셀 3열×4행. 행은 정면/왼쪽/오른쪽/뒷면, 열은 정지/발 A/발 B다.
- 내장 ImageGen을 사용했다. 생성 원본은 같은 폴더의 `*_hg_source.png`, 프롬프트는 `tools/hg_field_image_prompts.json`에 보관한다. `tools/prepare_hg_field.gd`가 알파 영역을 읽어 공통 배율·발 기준선으로 배치한다. 방향마다 상단 16행을 공유하여 걷기 중 머리 크기와 얼굴이 흔들리지 않게 했다.
- 한 셀의 논리 크기 16px와 월드 표시 크기를 고정했다. 포즈에 따른 확대·축소는 하지 않는다. 기존 승인된 0.24초 연속 이동, 한 칸마다 발 교대, 동료 추적은 유지한다.
- 원래 25×15 배치를 가로·세로 2배인 50×30칸으로 확장했다. 기존 입체 정원과 건물·화단·조명을 확대 배치하고 정투영 카메라를 유지한다. 판정과 상호작용도 확대된 타일 배치에 맞춘다.
- 어둠 구역은 지형과 창문까지 검게 숨긴다. 어두운 구역의 심볼은 표시하지 않는다. 최신 반복 랜덤 조우 규칙은 [맵 시스템](MAP_SYSTEM.md)을 따른다.
- 참고 영상: https://www.youtube.com/watch?v=e5yiRXOV61Q . 이 세션에서는 해당 영상 내용을 직접 가져오지 못했다. 사용자가 지정한 하트골드 도트 방향과 [닌텐도 공식 자료](https://www.nintendo.com/eu/media/downloads/migration_1/BROCHURE_POK_GOLD_SILVER_EN.pdf)를 참고했다. 게임의 원본 스프라이트를 가져오지 않았다.
- 실제 플레이 캡처: `tests/preview-oct20-field.png`, `tests/preview-oct20-overview.png`, `tests/preview-oct20-map.png`, `tests/preview-oct20-walk.gif`.
- 검사: `tests/field_party_test.gd`, `tests/diorama_test.gd`, `tests/oct20_update_test.gd`. 그래픽 변경 이후 맵·전투·스택 검사도 새 규칙으로 갱신했다.

## 이전 작업 기록

아래 내용은 날짜별 이전 구현과 승인 기록이다. 현재 적용 규칙과 자산은 위 2026-10-20 항목이 우선한다.
2026-10-19 현재 맵은 [가로등 골목 맵 시스템](MAP_SYSTEM.md)에 입체 배경을 결합한 버전이다. 아래 정사각형 테스트 맵과 이동 승인은 기준 기록으로 보관한다. 주인공 C타입과 승인된 이동은 그대로 사용하며, 그림자·보스 심볼을 추가했다.

## 이전 적용본: 도트 캐릭터 + 입체 정원 마을 (2026-10-19)

- `scripts/field_diorama.gd`는 표현만 담당한다. `field.gd`와 `player.gd`가 충돌, 타일 이동, 조사, 어둠 진입, 전투를 계속 결정한다. 논리 16px를 3D X/Z 평면의 1단위로 대응시킨다.
- 실제 3D 지형, 기와지붕 건물 6채, 목재 창틀과 발광 창문, 차양, 석조 화단, 정원 담장, 벤치, 나무와 원경 숲, 수로를 생성한다. 기존 통행 가능 칸에 장식을 추가하지 않는다. 건물 내부 진입은 구현하지 않는다.
- 카메라는 정투영, 위에서 비스듬히 내려다보는 고정 각도이며 파티를 부드럽게 따라간다. 거리나 발 프레임에 따라 캐릭터 크기가 바뀌지 않는다. 캐릭터는 승인된 64px C타입 시트를 그대로 사용하는 Sprite3D 빌보드다.
- 배경은 별도 3D SubViewport에서 기본 960×840으로 렌더링한다. 창 비율에 맞춰 렌더 폭을 조정하고 기존 HUD·지도·전투 화면을 위에 합성한다. 전투 중에는 배경 렌더링을 정지한다.
- 꽃잎·벽돌·목재 등 정적 기하를 재질별 MultiMesh로 묶는다. 실제 전체 지도 캡처에서 드로 호출을 15,061회에서 1,059회로 줄였다. 광원 유리와 캐릭터는 상태 갱신을 위해 별도로 유지한다.
- 가로등의 광원과 유리 재질은 게임의 점등 상태와 동기화된다. `assets/shaders/field_surface.gdshader`가 구역별로 지면·벽·화단을 함께 감광한다. 어둠 속 일반 적은 표시하지 않는다. 복구하면 즉시 밝아진다.
- 기존 0.24초 이동, 한 칸마다 좌우 발 교대, 동료 추적, 적 심볼 5개, 무작위 2~4마리 전투, 어둠 강제 조우, 4회 어쌔신 QTE, 전투 후 스택 유지를 유지한다.
- 참고: 사용자가 제공한 DQ7/제노기어스/옥토패스/DQ3 HD-2D 영상 링크. 이 작업에서는 영상 재생 내용을 직접 확인하지 못했으며, [Square Enix 공식 HD-2D 소개](https://www.jp.square-enix.com/octopathtraveler/about/)의 도트+3DCG 결합 방향과 사용자가 설명한 카메라 표현을 기준으로 자체 모델을 제작했다. 외부 게임의 모델·텍스처를 복제하거나 가져오지 않았다.
- 실행 검사: `tests/diorama_test.gd`. 실제 OpenGL 미리보기: `tests/preview_diorama.gd` → `tests/preview-diorama-entrance.png`, `tests/preview-diorama-plaza.png`, `tests/preview-diorama-overview.png`.
- 실제 걷기 캡처: 같은 미리보기 스크립트가 `.godot/diorama-walk/`에 60프레임을 저장한다. `tools/encode_field_walk.py --frames .godot/diorama-walk --output tests/preview-diorama-walk.gif --duration-ms 40`으로 2.4초 미리보기를 만든다.

## 사용자 승인 기준과 스타일 선택 (2026-10-17)

- 사용자가 현재의 연속 타일 이동과 걷기 프레임 연결을 “딱 바라던 거야”라고 승인했다. 이후 스프라이트 교체에서도 0.24초 이동, 진행도에 따른 발 내딛기/착지, 한 칸마다 반대 발 사용, 키 해제 후 해당 칸에서 정지하는 동작을 기준으로 유지한다.
- 기존 16×16 그림은 너무 저해상도라는 피드백에 따라 16비트 FF6풍 / 32비트 제노기어스풍 / 현대 Sea of Stars풍을 별도 제작했다. **사용자가 C타입(현대풍)을 선택했으며, 추흔의 표정을 웃는 얼굴로 수정해 적용했다.** A/B는 검토용으로 보관한다.
- 검토 파일은 `art-reviews/field-sprites-2026-10-17/`에 저장했다. A/B/C 이미지 각각 위 행 추흔·아래 행 연우, 열 순서는 정면/옆면/걷기/뒷면이다. 원화 참고는 `assets/sprites/battle/chuheun-source.png`, `yeonwoo-source.png`이다.
- 세 시안은 외형·도트 스타일 선택용 원화다. 선택된 C타입을 기준으로 네 방향 걷기 시트를 별도 생성했다. 16비트/32비트는 시대별 미술 스타일 구분이며 파일의 비트 깊이를 뜻하지 않는다.
- 논리 타일은 16×16, 스프라이트 셀은 64×64로 분리했다. 기존 canvas_items 확대 방식을 통해 기본 1024×896 창에서 원화의 64px 디테일을 표시한다. 모든 프레임에 동일한 그리기 크기와 발 기준선을 사용한다.
- 참고 영상: FF6 https://www.youtube.com/watch?v=XF2cski7Q7M / 제노기어스 https://www.youtube.com/watch?v=Jjm23wkeBk8 / Sea of Stars https://www.youtube.com/watch?v=vqK-1WGqYmI . 브라우저에서 세 영상의 캐릭터 표현을 확인했다.

## 이전 적용본: 정사각형 타일 테스트 맵 (2026-10-17)

- 밤 도시 배경과 가로등 렌더링을 제거하고 밝은 회녹색 격자로 교체했다. 기존 이미지 파일은 보관한다.
- 맵은 20×14칸, 한 칸은 16×16px이다. 테두리는 짙은 색의 통행 불가 타일이며 내부는 자유롭게 걸을 수 있다. 표시되는 격자와 충돌·이동 좌표가 일치한다.
- 참고 영상: https://www.youtube.com/watch?v=2V8stJAewZk (7:29 이후 29번 도로 필드 구간). 타일 간 연속 이동과 걸음 포즈 전환을 참고했다. 이동 시간은 이 프로젝트의 조정값이며 영상에서 측정한 수치는 아니다.
- 방향키를 누르면 인접한 다음 칸까지 0.24초에 걸쳐 일정한 속도로 이동한다. 화면 좌표는 중간 위치를 순서대로 지나가며, 논리 칸 좌표는 도착했을 때 확정한다. 키를 놓으면 진행 중인 칸까지 마치고 멈추며, 누르고 있으면 경계에서 바로 다음 걸음을 시작한다.
- 대각선 이동, 칸 건너뛰기, 진행 중 방향 변경은 막는다. 막힌 칸을 향하면 그 방향으로 돌아서기만 한다.
- C타입의 SD 비율과 검은 머리·도복, 푸른 테두리, 회색 허리띠를 유지한다. 추흔은 웃는 얼굴, 연우는 차분한 표정이다. 내장 ImageGen으로 정지/왼발/오른발 원화를 제작했다. 프롬프트: `tools/modern_field_image_prompts.json`.
- 적용 시트: `assets/sprites/field/chuheun_modern.png`, `assets/sprites/field/yeonwoo_modern.png`. 두 시트 모두 실제 192×256px이며, 64×64px 고정 셀 3열×4행이다. 행 순서는 정면/왼쪽/오른쪽/뒷면이며 열은 정지/발 포즈 A/발 포즈 B다.
- 런타임에서 알파 경계를 자르거나 포즈별 확대·축소를 하지 않는다. 64×64 원본 영역을 항상 같은 논리 16×16 사각형에 그린다. 원화의 투명 여백과 크기 차이로 걸음마다 캐릭터가 커졌다 작아지는 원인을 제거했다.
- 생성 원화는 `_modern_source.png`에 보관한다. `tools/prepare_modern_field.gd`는 원화의 투명 행간을 기준으로 자르고, 각 방향의 세 포즈에 공통 배율을 적용해 시트를 만든다. 모든 포즈는 같은 발 기준선에 정렬되며, 같은 방향의 세 프레임은 상단 26행의 머리를 공유한다. 팔·다리 포즈는 걸음에 맞춰 달라진다. 적용 시트의 알파 경계 자동 보정을 꺼서 프레임별 머리 픽셀을 동일하게 유지한다.
- 한 칸의 진행도 0~20%는 모은 발, 20~80%는 내딛은 발, 80~100%는 착지 자세로 그린다. 다음 칸에서는 반대 발을 내딛는다. 위치와 프레임은 같은 진행도를 사용하며 별도 애니메이션 타이머를 돌리지 않는다.
- 동료는 선두의 직전 칸을 따라간다. 기존 인카운터와 전투 복귀 동작은 유지한다.
- 검사: `tests/field_party_test.gd`. 시작 시 위치 유지, 중간 픽셀 통과, 중간 시점의 위치·발 프레임 동기화, 도착 시 정렬, 키 해제/연속 입력, 고정 크기, 충돌, 동료 추적, 전투 복귀를 검사한다.
- 실제 엔진 녹화: `tests/preview-field-modern.gif` (20ms 간격, 5.44초). `tests/record_field_walk.gd`로 프레임을 저장하고 `tools/encode_field_walk.py`로 인코딩한다. 정면 화면: `tests/preview-field-modern.png`. 확대 시트: `tests/preview-chuheun-modern.png`, `tests/preview-yeonwoo-modern.png`.

## 이전 적용본: 어두운 16비트 도시 (2026-10-14 재수정, 보관)

- 흑백 컨셉 철회. 어두운 남색 지붕, 회갈색의 마른 노면, 불 꺼진 창문, 약한 주황빛 가로등 두 개로 변경.
- 배경: `assets/tilesets/night_city_16bit.png`.
- 추흔: `assets/sprites/field/chuheun_16bit.png`.
- 연우: `assets/sprites/field/yeonwoo_16bit.png`.
- 내장 ImageGen 제작. 전체 프롬프트: `tools/field_16bit_image_prompts.json`. 16비트 DQ/FF 필드 스프라이트를 기준으로 단순한 눈·윤곽과 제한된 색을 사용하고, 과장된 SD 머리·눈을 줄였다.
- 방향당 2포즈와 한 칸 단위 이동, 연우의 동료 추적은 유지한다. 캐릭터는 최대 24px 높이로 표시한다.
- 가로등은 10Hz로 밝기를 갱신하고 서로 다른 주기의 짧은 감광을 사용한다. 작은 전구와 주변 바닥만 변하며 화면 전체 밝기는 변하지 않는다.
- 새 배경의 가로등 밑동에 맞춰 장애물 열은 3, 16으로 정렬했다. 다른 통행 행은 동일하다.
- Godot 4.7.2 실행·렌더링 및 필드 검사 통과: 방향당 포즈 수, 걸음 중 포즈 고정, 동료 경로/역방향, 충돌, 전투 복귀, 가로등 감광 및 비동기 주기. 미리보기: `tests/preview-field-16bit.png`.

## 이전 적용본: 흑백 붓질 도시 + SD (보관)

- 배경: `assets/tilesets/night_city_ink.png`. 흑백·회색의 큰 건물 면, 마른 붓질과 여백. 반사광, 색 조명, 젖은 도로 제거.
- 추흔: `assets/sprites/field/chuheun_sd.png`.
- 연우: `assets/sprites/field/yeonwoo_sd.png`.
- 두 캐릭터 모두 큰 머리와 짧은 몸의 SD 도트. 방향당 2포즈(정지/발 내딛기), 총 8포즈. 원본은 보존하며 런타임에서 발 위치를 맞추고 최대 20px 높이로 표시한다.
- 한 칸 0.16초. 포즈는 한 칸마다 한 번 교대하고 이동 중에는 고정한다. 위치는 한 칸당 네 번, 4px 단위로 갱신하여 연속 보간의 미끄러운 느낌을 줄였다. 정지하면 기본 포즈로 돌아온다.
- 연우의 한 칸 뒤 경로 추적은 유지한다.
- 내장 ImageGen으로 생성했다. 전체 프롬프트: `tools/field_ink_sd_image_prompts.json`. 사용자가 언급한 기존 붓질 컨셉아트 원본은 찾지 못해 이번 요청의 설명을 기준으로 제작했다.
- Godot 4.7.2 실제 렌더링과 필드 테스트 통과. 두 포즈 구성, 걸음 중 포즈 고정, 4px 단위 위치, 동료 경로/역방향/충돌/전투 복귀를 검사했다. 미리보기: `tests/preview-field-ink-sd.png`.

## 이전 적용본 (보관)

2026-10-14: 기존 20×14 논리 맵과 16px 이동 칸을 유지하면서 32비트 JRPG풍 배경 및 필드 파티를 적용했다. 전투 화면 해상도와 규칙은 변경하지 않았다.

- 배경: `assets/tilesets/night_city_32bit.png`. 건물·보도·도로의 다섯 구간을 기존 충돌 행에 맞춰 렌더링한다.
- 추흔: `assets/sprites/field/chuheun_walk.png`.
- 연우: `assets/sprites/field/yeonwoo_walk.png`.
- 내장 ImageGen으로 생성. 기존 전투 아트를 의상·외형 참고로 사용했다. 전체 생성 프롬프트는 `tools/field_32bit_image_prompts.json`에 기록했다.
- 시트 원본과 알파는 그대로 보존한다. `field_actor.gd`가 각 포즈의 투명 여백을 읽어 발 위치를 정렬하고 25px 높이에 맞춘다. 연우 시트의 넓은 좌우 여백은 별도 영역 좌표로 처리한다. 왼쪽 프레임은 일관된 오른쪽 행을 반전하여 사용한다.
- 추흔이 한 칸 이동할 때 연우는 추흔의 직전 칸으로 같은 시간 동안 이동한다. 막힌 칸에서는 방향만 바뀐다. 인카운터 걸음 수는 추흔만 보고하고 전투 복귀 후 파티 위치를 유지한다.

검증: `tests/field_party_test.gd`는 모퉁이, 역방향, 가로등 충돌, 입력 잠금, 걸음 수, 전투 복귀를 검사한다. 렌더러로 실행하면 `tests/preview-field-32bit.png`를 저장한다.

Godot 4.7.2에서 필드 검사와 실제 OpenGL 렌더링을 통과했다. 기존 전투 검사는 92개 중 91개 통과. 남은 `wide open center between teams`는 기존 HEAD에서도 팀 좌표 차이가 275인데 350 초과를 요구하는 기존 불일치다. 이번 작업에서는 전투 배치를 바꾸지 않았다.

