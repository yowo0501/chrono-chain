v004: 추흔 발 스텝 대기 / 두 캐릭터 머리 위 라소 회전 개정
참고: references/chuheun-idle-pose.png 사용자가 제공한 팔 벌린 대기 자세.
이전 모션 참고: assets/sprites/battle/chuheun-motion.png 하단 머리 위 체인 회전.
내장 image_gen으로 생성 후 반대발 스텝 오류를 추가 편집해 수정.
source/chuheun-motion.png 4x3: 첫8포즈 좌우 교대 스텝, 다음4포즈 크게 회전하는 머리 위 손동작.
source/yeonwoo-motion.png 2x2: 발을 고정한 절제된 손목 회전4포즈.
runtime 아틀라스: v003 기존20포즈 보존, 새포즈20번부터추가. 추흔32포즈, 연우24포즈.
추흔 대기1.12초/8포즈, 머리위 회전0.56초/4포즈. 연우회전0.72초/4포즈.
머리 위 금속체인 루프는 손목소켓과 연동, 몸 뒤/앞 구분. 이후 기존 투척/회수 동작으로 연결.
스킬/연우 대기/필드스프라이트/게임규칙/캐릭터배치및크기 유지.
검증: character_overhaul_test245통과. 실제 튜토리얼전투 로딩성공.
review/battle-idle.gif: 좌우 발 교대 확인. battle-windup-0.gif:추흔. battle-windup-1.gif:연우.
