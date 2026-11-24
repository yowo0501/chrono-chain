# 현재 두 명 파티 검사

Godot 4.7에서 `--headless --path . --script tests/<이름>.gd`로 실행한다.

현재 실행 대상으로 확인한 검사:

- `duo_overhaul_test`: 두 명 파티, 8방향 이동·맵 도달성, 프레임 등록, 체인 범위, 새 밸런스.
- `field_party_test`, `field_gimmicks_test`, `field_2d_test`, `night_dungeon_test`: 이동·동료·선제권·필드·점등·보스.
- `battle_test`, `timer_test`, `encounter_revision_test`, `oct20_update_test`, `stack_carryover_test`, `confirm_input_test`: 턴·QTE·특수기·어둠·스택·입력.
- `prologue_test`, `tutorial_test`, `tutorial_clear_test`, `prototype_fixes_test`: 이야기·튜토리얼·메뉴 복귀·가로등 보호.

`preview_duo_overhaul.gd`는 화면 캡처용이며 headless 없이 실행한다.

`new_party_test`, `marker_bind_test`, `shield_patrol_test`는 이전 네 명 파티의 설아·위성 기능을 전제로 한 과거 검사다. 현재 두 명 파티의 실행 목록에는 포함하지 않는다. `diorama_test` 역시 이전 3D 필드용 기록이다.
