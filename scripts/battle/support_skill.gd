extends RefCounted
## Automatic small lightning and ally-selected food/drink recovery animations.
signal effect
signal finished
var kind := "thunder"
var target := 0
var elapsed := 0.0
var applied := false
var done := false
var texture: Texture2D = load("res://assets/sprites/battle/support-skills.png")
const SHIELD_WALK := 0.65
const SHIELD_TRANSFORM := 2.0
const SHIELD_IMPACT := 3.05
const SHIELD_END := 3.85
const RETURN_TRANSFORM := 0.8
const RETURN_STARTLED := 1.4
const RETURN_END := 2.25
const FEET := [Vector2(177,460),Vector2(542,460),Vector2(924,460),Vector2(1318,460),
	Vector2(180,787),Vector2(550,787),Vector2(913,787),Vector2(1303,787),
	Vector2(168,1080),Vector2(536,1080),Vector2(907,1080),Vector2(1288,1080)]

func draw_pose(screen, frame: int, actor: int) -> void:
	var row := frame / 4
	var tops := [0,474,796]
	var heights := [474,322,290]
	var region := Rect2((frame % 4)*362,tops[row],362,heights[row])
	var scale: float = screen.ACTOR_SCALE * 0.54
	var anchor: Vector2 = FEET[frame] - region.position
	screen.draw_texture_rect_region(texture,Rect2(screen.HERO_POS[actor]-anchor*scale,region.size*scale),region)

func advance(delta: float) -> void:
	if done:
		return
	elapsed += delta
	var effect_at := SHIELD_IMPACT if kind == "shield" else 0.95 if kind == "thunder" else 1.25
	var end_at := 3.0 if kind == "swing_prepare" else SHIELD_END if kind == "shield" else RETURN_END if kind == "shield_return" else 1.85 if kind == "thunder" else 2.5
	if not applied and elapsed >= effect_at and kind not in ["shield_return","swing_prepare"]:
		applied = true
		effect.emit()
	if elapsed >= end_at:
		done = true
		finished.emit()

func draw(screen) -> void:
	var origin: Vector2 = screen.HERO_POS[screen.hero_index]
	if kind == "swing_prepare":
		screen.draw_overhead_pose(0 if elapsed < 0.4 else 1 if elapsed < 1.8 else 2,origin+Vector2(sin(elapsed*24)*0.8,0))
	elif kind in ["shield", "shield_return"]:
		_draw_shield(screen,origin)
	elif kind == "illuminate":
		screen.draw_new_pose(screen.hero_index,6 if elapsed < 0.65 else 7,origin)
		var orb := origin+Vector2(-10,-92)
		var strength := clampf(elapsed/1.25,0,1)
		screen.draw_circle(orb,8+sin(elapsed*9)*2,Color(0.5,0.85,1,strength))
		for ring in 3:
			var radius := fposmod(elapsed*65+ring*24,72)
			screen.draw_arc(orb,radius,0,TAU,48,Color(0.4,0.8,1,(1-radius/72)*strength),2)
	elif kind == "thunder":
		draw_pose(screen,0 if elapsed < 0.25 else 1 if elapsed < 0.6 else 2 if elapsed < 0.95 else 3,0)
		if applied:
			var fade := clampf(1.0 - (elapsed - 0.95) / 0.8, 0, 1)
			for i in screen.enemies.size():
				var bottom: Vector2 = screen.foe_position(i) + Vector2(0,-35)
				var points := PackedVector2Array([Vector2(bottom.x, 100)])
				for j in range(1, 8):
					points.append(Vector2(bottom.x + sin(j * 7 + elapsed * 35) * 19, lerpf(100, bottom.y, j / 7.0)))
				screen.draw_polyline(points, Color(0.22,0.6,1,fade*0.3), 15)
				screen.draw_polyline(points, Color(0.7,0.9,1,fade), 3)
	else:
		if target == screen.hero_index:
			draw_pose(screen,4 if elapsed < 0.4 else 5 if elapsed < 1.4 else 6 if elapsed < 1.8 else 7,1)
		else:
			draw_pose(screen,8 if elapsed < 0.3 else 9 if elapsed < 1.8 else 7,1)
			if elapsed >= 1.1 and target == 0:
				draw_pose(screen,10 if elapsed < 1.5 else 11,0)
			elif elapsed >= 1.1 and target >= 2:
				var food_at: Vector2 = screen.hero_position(target)+Vector2(0,-50)
				screen.draw_colored_polygon(PackedVector2Array([food_at+Vector2(-5,3),food_at+Vector2(5,3),food_at+Vector2(-3,-5)]),Color("e6c693"))
			var to: Vector2 = screen.hero_position(target) + Vector2(8,-65)
			var p := clampf((elapsed-0.3)/0.8, 0, 1)
			var food := (origin+Vector2(22,-86)).lerp(to,p) + Vector2(0,-sin(p*PI)*55)
			if elapsed >= 0.3 and elapsed < 1.1:
				screen.draw_colored_polygon(PackedVector2Array([food+Vector2(-11,8),food+Vector2(11,8),food+Vector2(-8,-10)]),Color("e6c693"))
				screen.draw_line(food+Vector2(-9,4),food+Vector2(7,4),Color("73a15f"),3)
		if applied:
			var heal_at: Vector2 = screen.hero_position(target)
			for i in 6:
				var p := heal_at + Vector2(sin(i*2.5)*34, -35-(elapsed-1.25)*65-i*7)
				screen.draw_line(p-Vector2(4,0),p+Vector2(4,0),Color("66dfb0"),2)
				screen.draw_line(p-Vector2(0,4),p+Vector2(0,4),Color("66dfb0"),2)
	screen._panel(Rect2(24,506,720,129))
	var caption := "회복 · " + str(screen.party[target].name)
	if kind == "thunder":
		caption = "벼락 · 전체 공격 · %d초 밝힘" % int(screen.balance.thunder.reveal_seconds)
	elif kind == "shield":
		caption = "방패 전개 · 공격 유도 · 다음 1턴 자동 수비"
	elif kind == "shield_return":
		caption = "방패 해제 · 체인을 거두고 원래 자리로!"
	elif kind == "swing_prepare":
		caption = "크게 휘두르기 · 방패를 무겁게 들어 올린다"
	elif kind == "illuminate":
		caption = "맵 밝히기 · %d초 밝힘" % int(screen.balance.illuminate.reveal_seconds)
	screen._label(caption,Vector2(48,548),Color("61cfff"),21)

func _draw_shield(screen, origin: Vector2) -> void:
	var front: Vector2 = screen.SHIELD_POS
	if kind == "shield_return":
		if elapsed < RETURN_TRANSFORM:
			var progress := elapsed / RETURN_TRANSFORM
			screen.draw_shield_pose(5,front,Color(1,1,1,1-progress))
			screen.draw_shield_pose(6,front,Color(1,1,1,progress))
			_transform_light(screen,front,progress)
		elif elapsed < RETURN_STARTLED:
			screen.draw_shield_pose(6,front+Vector2(sin(elapsed*35)*1.5,0))
		else:
			var progress := clampf((elapsed-RETURN_STARTLED)/(RETURN_END-RETURN_STARTLED),0,1)
			var at := front.lerp(origin,progress)+Vector2(0,-absf(sin(progress*PI*5))*3)
			screen.draw_shield_pose(7+int(elapsed*12)%2,at)
		return
	if elapsed < SHIELD_WALK:
		var progress := elapsed / SHIELD_WALK
		screen.draw_shield_pose(1,origin.lerp(front,progress)+Vector2(0,-absf(sin(progress*PI*3))*2))
	elif elapsed < SHIELD_WALK + SHIELD_TRANSFORM:
		var progress := (elapsed-SHIELD_WALK)/SHIELD_TRANSFORM
		# Hands stay overhead. Only the chain changes brightness, never the body.
		screen.draw_overhead_pose(0 if progress < 0.2 else 1 if progress < 0.85 else 2,front)
	elif elapsed < SHIELD_IMPACT:
		var progress := (elapsed-SHIELD_WALK-SHIELD_TRANSFORM)/(SHIELD_IMPACT-SHIELD_WALK-SHIELD_TRANSFORM)
		if progress < 0.55:
			screen.draw_overhead_pose(2,front+Vector2(0,-sin(progress*PI)*3))
		else:
			screen.draw_shield_pose(3,front+Vector2(0,-(1-progress)*18))
	else:
		var impact_age := elapsed-SHIELD_IMPACT
		screen.draw_shield_pose(4 if impact_age < 0.25 else 5,front+Vector2(sin(elapsed*38)*1.3,0))
		if impact_age < 0.4:
			screen.draw_arc(front+Vector2(20,0),8+impact_age*90,PI,TAU,24,Color(0.4,0.8,1,1-impact_age/0.4),3)

func _transform_light(screen, at: Vector2, progress: float) -> void:
	var center := at+Vector2(15,-42)
	var intensity := sin(progress*PI)
	for i in 8:
		var angle := i*TAU/8+elapsed*5
		var radius := 12+intensity*20
		screen.draw_circle(center+Vector2.from_angle(angle)*radius,1.5,Color(0.4,0.8,1,intensity))
	screen.draw_arc(center,14+intensity*22,elapsed*4,elapsed*4+PI*1.5,24,Color(0.4,0.8,1,intensity),2)
