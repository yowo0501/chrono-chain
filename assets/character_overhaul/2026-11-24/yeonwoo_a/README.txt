연우 A 시절 기준 수정 — 2026-11-24

사용자 확정 기준
A(검은 바지 시절)의 비율·포즈·동작을 기준으로 현재 설정화 디자인을 적용한다.
표정은 고개 방향과 시선을 유지하며 현재 설정화의 차분한 인상으로 조금씩 조정한다.

참조
reference/yeonwoo-motion-source.png: 대기 및 체인 준비 16프레임.
reference/yeonwoo-expressive-source.png: 공격/회수 및 쉬는 표현 16프레임.
reference/yeonwoo-source.png: 기본/방어/피격/표정 8프레임.
reference/yeonwoo-windup-fixed-source.png: 고정 몸통 체인 준비 1자세.
reference/battle_screen_A.gd: git 7d91a79의 실제 과거 재생 코드.
이후 만들어진 발끝 까딱임 자료는 이번 연우 대기에 사용하지 않는다.

적용
대기: motion 시트 0→1→2→3, 총 1.6초. 각 자세 0.7/0.2/0.4/0.3초.
공격: expressive 시트 0→2→3→4→6→7. 기존 0.8초 공격 타이밍 유지.
쉬는 표현: A 당시의 8→9→10→11→13→15 순서, 기존 공동 휴식 간격 사용.
체인 준비: A 당시 고정 몸통, 손목 회전 ±0.12라디안, 세로 타원 체인 1.6초 주기.
현재 설정화의 치마, 코발트 도복 테두리, 검은 허리띠, 금색 머리핀, 호박색 눈 적용.
추흔, 필드, 맵 이동 테스트는 이번 수정 대상에서 제외했다.

원본 보관과 생성
source: 내장 이미지 생성 도구로 A 원본을 직접 편집한 4종.
runtime: 게임이 사용하는 768x480 프레임 및 몸통/손목 레이어.
metadata/prompts.json: 생성 및 의상 오류 수정 프롬프트.
metadata/registration.json: 프레임 위치·배율·지면 정렬.
metadata/chain-joins.json: 기존 추흔 연결점과 새 연우 연결점.
이미지를 재해석한 결과이므로 원본과 픽셀 단위로 동일한 복제는 아니다.
A 원본과 동일한 키로 맞춘 비교는 review/comparison.png에서 확인한다.

검증
실제 Godot 등록 프로젝트: C:/Users/Administrator/Documents/ChatGPT/크로노 체인 동방 버전
연우 A 전용 점검 35개 통과: 재생 시점, 실제 자산 연결, 프레임 잘림, 추흔 경로 유지.
전투 점검 92개 통과.
review: 실제 전투 렌더러의 대기 연속 프레임 및 공격 연속 프레임, 준비·피격 외 관련 스킬 미리보기.
