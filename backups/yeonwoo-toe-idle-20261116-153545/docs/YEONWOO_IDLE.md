# 연우 전투 대기: 작은 사이드 스텝

2026-11-16. 사용자 설명과 이전 `character-refresh-2026-11` 백업의 연우 모션 아틀라스 첫 두 행을 비교했다. 예전 프레임은 발 간격과 지지하는 다리를 바꾸는 움직임이 있었지만, 현재 교체된 모션은 같은 자세에 가까웠다.

최근 추가했던 전신 사각형의 호흡 변형을 제거했다. 현재 복장과 그림체를 기준으로 내장 이미지 생성 도구에서 작은 발 옮김 8프레임을 제작했다. 상체는 차분하게 유지하며 앞발 들기·짧게 내딛기·체중 이동·반대발 정리·원위치 순으로 1.6초마다 반복한다. 전체 그림을 좌우로 미는 동작이 아니라 발과 무릎의 자세가 바뀐다.

- 실행 아틀라스: `assets/sprites/yeonwoo-idle/sidestep.png`
- 생성 원화: `assets/sprites/yeonwoo-idle/source.png`
- 참고한 이전 모션: `assets/sprites/yeonwoo-idle/previous-motion-reference.png`
- 생성 프롬프트: `assets/sprites/yeonwoo-idle/prompts.json`
- 등록: `tools/pack_yeonwoo_idle.gd`. 모든 프레임에 동일 배율과 좌표를 적용해 작은 발 이동을 보존한다.
- 실제 전투 캡처: `art-reviews/yeonwoo-sidestep/yeonwoo-idle.gif`

일반 대기일 때만 적용한다. 공격·수비·피격·하품·특수기는 기존 그림과 동작을 유지한다. 추흔의 필드 체인 0.5초·후딜 0.25초·사거리 4칸은 변경하지 않는다.
