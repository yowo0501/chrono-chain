# 현재 두 명 파티 검사

Godot 4.7에서 `--headless --path . --script tests/<이름>.gd`로 실행한다.

현재 실행 대상으로 확인한 검사:

- `duo_overhaul_test`: 두 명 파티, 8방향 이동·맵 도달성, 프레임 등록, 체인 범위, 새 밸런스.
- `field_party_test`, `field_gimmicks_test`, `field_2d_test`, `night_dungeon_test`: 이동·동료·선제권·필드·점등·보스.
- `battle_test`, `timer_test`, `encounter_revision_test`, `oct20_update_test`, `stack_carryover_test`, `confirm_input_test`: 턴·QTE·특수기·어둠·스택·입력.
- `prologue_test`, `tutorial_test`, `tutorial_clear_test`, `prototype_fixes_test`: 이야기·튜토리얼·메뉴 복귀·가로등 보호.

`preview_chain_swing.gd`는 현재 전용 체인 모션과 연우의 연속 대기 움직임을 확인하는 화면 캡처용이며 headless 없이 실행한다. `preview_duo_overhaul.gd`는 채택하지 않은 새 아트의 과거 검수 도구다.

`new_party_test`, `marker_bind_test`, `shield_patrol_test`는 이전 네 명 파티의 설아·위성 기능을 전제로 한 과거 검사다. 현재 두 명 파티의 실행 목록에는 포함하지 않는다. `diorama_test` 역시 이전 3D 필드용 기록이다.

## 프롤로그 챕터 (2026-11-23)

- `prologue_chapter_test`: 전체 챕터, 첫 전투와 2/3/3/5 추격전, 집중/타이머, 엔딩, 전용 수치 격리.
- `prologue_chapter_branches_test`: 공격×방어 9개 결과 조합, 대사 분기·표정, QTE 안내 일시 정지, 실제 입력 및 맵 도달성.
- `preview_prologue_chapter`: 실제 렌더러로 13개 장면을 `art-reviews/prologue-chapter/`에 저장.
