# 프롤로그 챕터 그림 기록

생성일: 2026-11-23. 생성 방식: 내장 image_gen 도구. 아래 내용은 사용한 요청의 요약이며 원문 프롬프트를 그대로 옮긴 것은 아니다. 캐릭터의 기본 의상·외형은 사용자가 제공한 E:/크로노 체인/강추흔 캐릭터 시트.png 및 김연우 캐릭터 시트.png를 기준으로 했다. 새 전투 전체를 다시 그리지 않고 기존 전투·필드 아트와 어울리는 짧은 이벤트 그림을 요청했다.

| 파일 | 요청 요약 / 사용 위치 |
| --- | --- |
| rooftop.png | 한국의 밤 도시, 옥상에서 건물 아래 거리까지 이어지는 세로형 도트 배경. 시작 메뉴 및 아래로 내려가는 오프닝. 1024×1536 |
| ending.png | 검은색·청색 의상, 추흔의 주황 포인트와 연우의 금빛 포인트를 유지. 두 사람이 밤의 도시를 바라보는 뒷모습을 그린 와이드 애니메이션 일러스트. 엔딩 컷신 |
| event-poses-source.png | 기존 SD 필드 캐릭터를 참고한 전신 이벤트 포즈. 추흔은 준비·등·기지개·회복, 연우는 준비·등·하품·작은 미소. 투명 배경. 생성 결과는 5열×2행 |
| comic-poses-source.png | 기존 상세 전투 스프라이트를 참고한 4열×2행 이벤트 포즈. 추흔의 눈 부릅뜨기·집중·이마 반응·회복, 연우의 한숨·오른쪽으로 딱밤·부끄러움·코믹 분노. 금빛 포인트와 청색 체인, 투명 배경 |

`event-poses.png`는 원본을 64×64 고정 셀 5열×2행으로 정렬한 런타임 아틀라스다. `comic-poses.png`는 원본의 행별 배율과 발 기준점을 고정하여 384×240 셀 4열×2행으로 정렬한 아틀라스다. 기울기·손 위치를 보존하며 프레임별 임의 확대를 하지 않는다. Godot의 이미지 기능으로 셀 자르기·축소·패킹만 수행했다. 도구는 `tools/pack_chapter_events.gd`, `tools/pack_chapter_comic.gd`다.

원본 생성 결과 ID:
- rooftop: call_eARfiS3xNvIehvjJCnTZMErD
- ending: call_xGgYkZyxALXGF8NWr2riw5Gl
- event poses: call_90KwkF9AwpNE1eFiLMx2yhCJ
- comic poses: call_XjFC1iqZ4Z3LGgJSHoq2oN2k

기존 로고 및 원래의 걷기/전투/발 까딱임 시트는 그대로 사용한다. 연우의 기존 분홍색 포인트는 `assets/shaders/yeonwoo_gold.gdshader`로 금빛으로 표시한다.
