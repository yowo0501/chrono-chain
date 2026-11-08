# 프롤로그 구현

2026-10-26. 제공된 `1-프롤로그.docx`의 20개 대사·나레이션을 원문 그대로 순서대로 구현했다. 원본 문서는 수정하지 않았다. `display_text`는 일부 긴 독백의 공백을 줄바꿈으로 표시하는 용도다.

## 실행과 조작

F5 → 타이틀 메뉴에서 프롤로그 실행 또는 튜토리얼 실행. 대사는 클릭·Enter·Space·Z로 완성하고 다음으로 넘긴다. 페이드·침묵·동작 중에는 진행 입력을 무시한다. 끝에서는 다시 보기/메뉴로를 고른다. F10은 일시정지된 튜토리얼이나 전투에서도 메뉴로 복귀한다. 메뉴 복귀는 현재 시험 진행을 초기화한다.

## 구성

- `scenes/menu/title.tscn`: 시작 로고와 버튼 두 개.
- `scenes/prologue/prologue.tscn`: 기존 필드와 분리된 이벤트 씬.
- `data/prologue.json`: 20개 텍스트 이벤트와 8개 연출 이벤트. 각 연출의 `duration`으로 길이를 조정한다.
- `scripts/story/prologue.gd`: 한 글자씩 표시하는 대사창과 이벤트 순서 제어. 다음 에피소드용으로 데이터 구조를 재사용할 수 있다.
- `scripts/story/prologue_stage.gd`: 배경과 필드 캐릭터 렌더링. 한 칸은 48 단위, 괴물은 3×3칸이며 두 캐릭터와 약 두 칸 떨어져 시작한다. 기존 추흔·연우 3×4 아틀라스를 사용한다.
- `scripts/story/session_router.gd`: 씬 전환과 세션 초기화. 기존 튜토리얼 씬의 필드·전투 코드는 변경하지 않는다. Autoload 등록 순서는 Tutorial 뒤이며, Godot의 역순 입력 전파에서 F10을 먼저 받는다.

프롤로그에는 필드 그룹, 플레이어 이동 코드, 적 심볼을 생성하지 않아 전투가 발생하지 않는다. 괴물은 이미지의 가로 띠를 조금씩 변형해 꿈틀거린다. 무기 전개는 기존 필드 캐릭터의 포즈와 체인 링크의 이동으로 표현한다. 돌진 뒤 합성한 금속 충돌음과 함께 암전한 후 로고를 표시한다.

## 이미지와 음향

내장 image_gen으로 생성한 `assets/prologue/logo-chain-lettering.png`, `alley.png`, `monster.png`(알파 포함)를 프로젝트 안에 저장했다. 로고는 사용자 스케치에 따라 사슬 글자의 Chrono / Chain 두 줄과 오른쪽의 작은 한글 제목으로 구성했다. 영문은 두께와 은색 금속 질감을 가진 맞물린 사슬 고리로 표현하고 희미한 푸른빛을 더했다. 한글은 획 끝에 개성을 준 명조 계열 전용 레터링으로 다듬었으며, 메뉴·종료 화면 모두 같은 로고를 원래 비율로 표시한다. 메뉴의 별 장식과 상단 부제도 제거했다. 기존 장식 로고 `logo.png`는 참조하지 않는다. 최종 로고 프롬프트는 `logo-chain-lettering-prompt.json` (이전 선형 로고는 `logo-minimal-blue-prompt.json`, 무발광 원본은 `logo-minimal-prompt.json`), 기존 자산 프롬프트는 `prompts.json`에 기록했다.

`chain_clash.wav`는 `tools/prepare_prologue_audio.py`로 생성한 짧은 금속성 충돌음이다. 음악이나 음성은 추가하지 않았다.

## 검증

- 원본 DOCX의 대사·나레이션 20개와 JSON의 `text`를 순서대로 대조한다.
- Godot `--headless --path . --script tests/prologue_test.gd`: 시작 메뉴, 실제 키·마우스 입력, 대사 표시, 연출 순서, 전투 미발생, 재생 초기화, 튜토리얼·전투에서 메뉴 복귀를 검사한다.
- Godot `--headless --path . --script tests/tutorial_test.gd`: 기존 튜토리얼 29개 검사.
- Godot `--path . --script tests/preview_prologue.gd --resolution 1024x896`: 주요 장면을 `art-reviews/prologue/`에 렌더링해 한글과 배치를 확인한다.
