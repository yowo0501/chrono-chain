# 연우 전투 대기: 발끝 까딱이기

2026-11-16. 사이드 스텝을 교체하고 한쪽 발끝을 가볍게 들었다 내리는 대기 모션을 새로 제작했다. 기존 캐릭터 원화를 기준으로 내장 이미지 생성 도구를 사용했다.

상체는 차분하게 유지하고 한쪽 발을 지지한 채 앞발의 뒤꿈치를 바닥에 둔다. 발끝 들기 → 잠깐 들고 있기 → 내리기 → 바닥에 닿기 → 잠깐 쉬기를 반복한다. 8프레임, 0.8초 주기로 이전보다 두 배 자주 반복한다. 쉬는 구간을 줄이고 발끝 각도·무릎 반응과 머리카락·사슬의 후속 움직임을 키웠다. 전신을 움직이거나 좌우로 미는 추가 변형은 없다.

- 실행 아틀라스: `assets/sprites/yeonwoo-toe-idle/toe-tap-v2.png`
- 생성 원화: `assets/sprites/yeonwoo-toe-idle/source-v2.png`
- 생성 프롬프트: `assets/sprites/yeonwoo-toe-idle/prompts-v2.json`
- 원화 기준: `assets/sprites/battle/yeonwoo.png`
- 등록 도구: `tools/pack_yeonwoo_toe_idle.gd`. 전 프레임에 같은 배율·위치를 적용한다.
- 실제 전투 캡처: `art-reviews/yeonwoo-toe-idle-v2/yeonwoo-idle.gif`

일반 대기에만 적용한다. 공격·수비·피격·하품·특수기와 추흔의 필드 체인은 그대로다. 이전 사이드 스텝 자산은 보관하지만 게임에서는 사용하지 않는다. 검사는 새 아틀라스 연결, 앞발 끝이 들리는 높이, 지지하는 발의 바닥 위치와 반복 시간을 확인한다.
