extends RefCounted
## One cast owns its QTE and damage timeline; the battle owns targets and HP.
signal spear_hit
signal lightning_hit
signal finished
enum Stage { PREP, JUMP, CHAIN, MORPH, AIM, THROW, FLIGHT, WAIT, LIGHTNING, LAND, CONFUSED, FALL, FLAT, RECOVER, DONE }
const BLUE := Color("61cfff")
const WHITE := Color("e9faff")
# The generated special atlas has larger anatomy than the regular 384x240 cells.
# Normalize its source pixels, then use the same world scale as regular actors.
const ATLAS_TO_ACTOR := 0.60
const LABELS := ["도약", "체인 변환", "조준 · 투척"]
# Explicit atlas regions follow the generated gutters (the source is not a
# mathematically uniform grid). This prevents neighboring feet/chain fragments.
const REGIONS := [
	Rect2(0, 0, 362, 278), Rect2(362, 0, 354, 278), Rect2(716, 0, 344, 278), Rect2(1060, 0, 388, 278),
	Rect2(0, 278, 390, 287), Rect2(390, 278, 326, 287), Rect2(716, 278, 344, 287), Rect2(1060, 278, 388, 287),
	Rect2(0, 565, 362, 250), Rect2(362, 565, 354, 250), Rect2(716, 565, 344, 250), Rect2(1060, 565, 388, 250),
	Rect2(0, 815, 362, 271), Rect2(362, 815, 354, 271), Rect2(716, 815, 344, 271), Rect2(1060, 815, 388, 271)]
var stage: int = Stage.PREP
var elapsed := 0.0
var total_time := 0.0
var successes := 0
var results: Array[bool] = []
var settings: Dictionary
var target_position := Vector2.ZERO
var origin := Vector2.ZERO
var texture: Texture2D
var motion_texture: Texture2D
var feedback := ""
var feedback_time := 0.0
var spear_damage := 0
var lightning_damage := 0

func setup(config: Dictionary, power: int, from: Vector2, target: Vector2, atlas: Texture2D) -> void:
	settings = config
	origin = from
	target_position = target + Vector2(0, -52)
	texture = atlas
	spear_damage = power

func is_qte() -> bool:
	return stage in [Stage.PREP, Stage.CHAIN, Stage.AIM]

func qte_index() -> int:
	return [Stage.PREP, Stage.CHAIN, Stage.AIM].find(stage)

func cursor() -> float:
	return clampf(elapsed / float(settings.qte_duration), 0.0, 1.0)

func press() -> void:
	if not is_qte():
		return
	_resolve(absf(cursor() - 0.5) <= float(settings.qte_half_width))

func _resolve(success: bool) -> void:
	results.append(success)
	if success:
		successes += 1
	feedback = "SUCCESS" if success else "MISS"
	feedback_time = 0.45
	if stage == Stage.PREP:
		_enter(Stage.JUMP)
	elif stage == Stage.CHAIN:
		_enter(Stage.MORPH)
	else:
		var power: int = spear_damage
		spear_damage = roundi(power * float(settings.spear_multipliers[successes]))
		lightning_damage = roundi(power * float(settings.lightning_multipliers[successes]))
		_enter(Stage.CONFUSED if successes == 0 else Stage.THROW)

func advance(delta: float) -> void:
	if stage == Stage.DONE:
		return
	elapsed += delta
	total_time += delta
	feedback_time = maxf(0.0, feedback_time - delta)
	if is_qte():
		# Once the window passes, there is no return trip and no further chance.
		if cursor() > 0.5 + float(settings.qte_half_width):
			_resolve(false)
		return
	var duration := 0.0
	match stage:
		Stage.JUMP: duration = 0.48
		Stage.MORPH: duration = 0.88
		Stage.THROW: duration = 0.22
		Stage.FLIGHT: duration = 0.38
		Stage.WAIT: duration = 1.0
		Stage.LIGHTNING: duration = 0.8
		Stage.LAND: duration = 0.65
		Stage.CONFUSED: duration = 0.55
		Stage.FALL: duration = 0.55
		Stage.FLAT: duration = 0.6
		Stage.RECOVER: duration = 0.45
	if elapsed < duration:
		return
	match stage:
		Stage.JUMP: _enter(Stage.CHAIN)
		Stage.MORPH: _enter(Stage.AIM)
		Stage.THROW: _enter(Stage.FLIGHT)
		Stage.FLIGHT: _enter(Stage.WAIT)
		Stage.WAIT: _enter(Stage.LIGHTNING)
		Stage.LIGHTNING: _enter(Stage.LAND)
		Stage.LAND, Stage.RECOVER: _enter(Stage.DONE)
		Stage.CONFUSED: _enter(Stage.FALL)
		Stage.FALL: _enter(Stage.FLAT)
		Stage.FLAT: _enter(Stage.RECOVER)

func _enter(next: int) -> void:
	stage = next
	elapsed = 0.0
	if stage == Stage.WAIT:
		spear_hit.emit()
	elif stage == Stage.LIGHTNING:
		lightning_hit.emit()
	elif stage == Stage.DONE:
		finished.emit()

func draw(screen) -> void:
	var art_scale: float = screen.ACTOR_SCALE * ATLAS_TO_ACTOR
	var relative_scale := art_scale / 0.62
	var sky := origin + Vector2(95, -155)
	var actor := sky
	var frame := 0
	var motion_frame := -1
	screen.draw_rect(Rect2(0, 96, 768, 390), Color(0.01, 0.035, 0.09, 0.38))
	match stage:
		Stage.PREP:
			actor = origin
			motion_frame = 0
		Stage.JUMP:
			var p := clampf(elapsed / 0.48, 0, 1)
			actor = origin.lerp(sky, sin(p * PI * 0.5))
			motion_frame = 1 + mini(int(p * 3.0), 2)
			for i in 4:
				screen.draw_line(actor + Vector2(-25 + i * 18, 12), actor + Vector2(-25 + i * 18, 28 + i * 5), Color(0.4, 0.8, 1, 0.35), 2)
		Stage.CHAIN:
			motion_frame = 5
		Stage.MORPH:
			motion_frame = 4 + mini(int(elapsed / 0.88 * 8), 7)
			var glow := sin(clampf(elapsed / 0.88, 0, 1) * PI)
			screen.draw_circle(sky + Vector2(30, -110) * relative_scale, (35 + glow * 35) * relative_scale, Color(0.15, 0.6, 1, glow * 0.13))
		Stage.AIM:
			frame = 6
			screen.draw_dashed_line(sky + Vector2(35, -65) * relative_scale, target_position, Color(0.4, 0.8, 1, 0.45), 1, 7)
			screen.draw_arc(target_position, 24, 0, TAU, 24, BLUE, 2)
		Stage.THROW:
			frame = 6 if elapsed < 0.07 else (7 if elapsed < 0.15 else 8)
			actor.x += smoothstep(0.0, 0.22, elapsed) * 12.0
		Stage.FLIGHT:
			frame = 7 if elapsed < 0.15 else 8
			var start := sky + Vector2(45, -70) * relative_scale
			var pos := start.lerp(target_position, clampf(elapsed / 0.38, 0, 1))
			_draw_spear(screen, pos, (target_position - start).angle())
		Stage.WAIT, Stage.LIGHTNING:
			frame = 9
			_draw_spear(screen, target_position, 0.65)
			if stage == Stage.WAIT:
				screen.draw_arc(target_position, 22 + elapsed * 14, -PI * 0.5, -PI * 0.5 + elapsed * TAU, 32, BLUE, 2)
			else:
				actor = sky.lerp(origin, clampf(elapsed / 0.65, 0, 1))
				frame = 10 if elapsed >= 0.65 else 9
				_draw_lightning(screen)
		Stage.LAND:
			actor = origin
			frame = 10 if elapsed < 0.4 else 11
		Stage.CONFUSED:
			frame = 12
			screen._label("?", sky + Vector2(15, -165) * relative_scale, WHITE, 30)
		Stage.FALL:
			frame = 13
			actor = sky.lerp(origin, pow(clampf(elapsed / 0.55, 0, 1), 2))
		Stage.FLAT:
			frame = 14
			actor = origin
			screen._label("MISS", origin + Vector2(-25, -75), BLUE, 24)
		Stage.RECOVER:
			frame = 10 if elapsed < 0.25 else 11
			actor = origin
	var region: Rect2 = REGIONS[frame]
	var active_texture: Texture2D = texture
	if motion_frame >= 0 and motion_texture != null:
		active_texture = motion_texture
		var row := int(motion_frame / 4)
		var tops := [0.0, 304.0, 543.0, 815.0]
		var heights := [304.0, 239.0, 272.0, 271.0]
		region = Rect2((motion_frame % 4) * 362, tops[row], 362, heights[row])
	var dimensions: Vector2 = region.size * art_scale
	if motion_frame < 0 and frame == 11:
		# Resume the regular standing sprite before handing the turn back.
		screen._frame(screen.calm_idle_texture, 0, 3, 2, Rect2(actor - screen.FOOT_ANCHOR * screen.ACTOR_SCALE, screen.ANIMATION_CELL * screen.ACTOR_SCALE))
	else:
		screen.draw_texture_rect_region(active_texture, Rect2(actor - Vector2(dimensions.x * 0.5, dimensions.y * 0.98), dimensions), region)
	if feedback_time > 0:
		screen._label(feedback, Vector2(335, 158), BLUE if feedback == "SUCCESS" else Color("ffb35a"), 21)

func _draw_spear(screen, center: Vector2, angle: float) -> void:
	var points := PackedVector2Array()
	var weapon_scale: float = screen.ACTOR_SCALE * ATLAS_TO_ACTOR / 0.62
	for corner in [Vector2(-90, -65), Vector2(90, -65), Vector2(90, 65), Vector2(-90, 65)]:
		points.append(center + (corner * weapon_scale).rotated(angle))
	var region: Rect2 = REGIONS[15]
	var tex_size: Vector2 = texture.get_size()
	var uv_start := region.position / tex_size
	var uv_end := region.end / tex_size
	screen.draw_polygon(points, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
		PackedVector2Array([uv_start, Vector2(uv_end.x, uv_start.y), uv_end, Vector2(uv_start.x, uv_end.y)]), texture)

func _draw_lightning(screen) -> void:
	var fade := 1.0 - clampf(elapsed / 0.8, 0, 1)
	# Branches reach every enemy; the planted spear remains the main conductor.
	for foe in screen.enemies.size():
		var bottom: Vector2 = screen.FOE_POS[foe] + Vector2(0, -32)
		var points := PackedVector2Array([Vector2(target_position.x, 98)])
		for i in range(1, 9):
			var t := i / 8.0
			var point := Vector2(target_position.x, 98).lerp(bottom, t)
			point.x += sin(i * 2.37 + int(elapsed * 24.0) * 1.1 + foe) * 28.0 * sin(t * PI)
			points.append(point)
		screen.draw_polyline(points, Color(0.15, 0.45, 1, fade * 0.45), 22)
		screen.draw_polyline(points, Color(0.2, 0.75, 1, fade), 8)
		screen.draw_polyline(points, Color(0.9, 1, 1, fade), 3)
		screen.draw_arc(bottom, 24 + elapsed * 80, 0, TAU, 28, Color(0.3, 0.8, 1, fade), 3)
		screen._label(str(lightning_damage), bottom + Vector2(-20, -105 - elapsed * 20), WHITE, 24)
	screen.draw_rect(Rect2(0, 96, 768, 390), Color(0.45, 0.85, 1, fade * 0.13))

func draw_qte(screen) -> void:
	screen._panel(Rect2(24, 506, 720, 129))
	var subtitle: String = LABELS[qte_index()] if is_qte() else ("점프" if stage == Stage.JUMP else ("체인 → 창" if stage == Stage.MORPH else ("실패" if successes == 0 else "투척 · 낙뢰")))
	screen._label("타이머  ·  " + subtitle, Vector2(48, 534), BLUE, 19)
	screen._label("성공 %d / 3" % successes, Vector2(610, 534), WHITE, 16)
	for i in 3:
		var color := Color("344961")
		if i < results.size():
			color = BLUE if results[i] else Color("bc6679")
		screen.draw_circle(Vector2(326 + i * 32, 528), 7, color)
	if is_qte():
		var bar := Rect2(52, 558, 664, 35)
		screen.draw_rect(bar, Color("080e19"))
		var half := float(settings.qte_half_width) * bar.size.x
		screen.draw_rect(Rect2(384 - half, 554, half * 2, 43), Color("284a62"))
		screen.draw_rect(Rect2(384 - half, 554, half * 2, 43), BLUE, false, 1)
		screen.draw_rect(Rect2(52 + cursor() * 664 - 2, 552, 4, 47), WHITE)
		screen._label("SPACE", Vector2(354, 584), WHITE, 17)
		screen._label("중앙에 한 번!  ·  왕복 없음  ·  성공 횟수에 따라 위력 증가", Vector2(48, 620), BLUE, 13)
	else:
		var text := "다음 자세를 준비합니다"
		if stage == Stage.MORPH:
			text = "푸른 빛 속에서 체인이 창으로 변화한다"
		elif stage >= Stage.CONFUSED:
			text = "어라…?  체인이 말을 안 듣는다!"
		elif stage == Stage.WAIT:
			text = "창 적중!  1초 뒤 낙뢰"
		elif stage == Stage.LIGHTNING:
			text = "푸른 번개가 적 전체를 덮친다"
		screen._label(text, Vector2(48, 582), WHITE, 20)
