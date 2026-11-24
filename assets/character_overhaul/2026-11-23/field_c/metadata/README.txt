확정 필드 스타일C. reference: v001/candidates/C.png 및 확정 캐릭터시트.
내장 image_gen으로 두캐릭터 걷기와 추흔체인방향 포즈 생성, Godot용 아틀라스로 정리.
walk: 64px셀3x4, 행방향 down,left,right,up; 열정지/왼발/오른발. 몸체약48px, 화면높이약24worldpx.
chain: 96px셀2x8, 행방향 down,down_left,left,up_left,up,up_right,right,down_right.
열 준비/전개. 손목좌표는 chain_anchors.json. 체인 타격축은 기존45도 양자화 유지.
게임 연결: scripts/player.gd -> scripts/field_actor.gd. 필드배경style_c와 함께 사용.
전투는 이필드세트와 별도이며 v003으로 롤백함. v004원본은 보관만 유지.
