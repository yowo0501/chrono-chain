extends RefCounted
## The cast snapshots living foes; marks never deal damage before the return/yawn.
signal damage_hit
signal finished
enum Stage { MORPH, CUTIN, VANISH, QTE, MARK, RETURN, YAWN, SLASHES, EMBARRASSED, RECOVER, DONE }
const BLUE := Color("61cfff")
const WHITE := Color("e9faff")
var stage := Stage.MORPH
var elapsed := 0.0
var settings: Dictionary
var origin := Vector2.ZERO
var targets: Array = []
var marked: Array[int] = []
var results: Array[bool] = []
var target_cursor := 0
var damage := 0
var texture: Texture2D
var eyes: Texture2D

func setup(config: Dictionary, power: int, from: Vector2, living: Array, atlas: Texture2D, cutin: Texture2D) -> void:
	settings = config
	origin = from
	targets = living.duplicate()
	texture = atlas
	eyes = cutin
	damage = roundi(power * float(config.damage_multiplier))

func is_qte() -> bool:
	return stage == Stage.QTE

func cursor() -> float:
	return clampf(elapsed / float(settings.qte_duration), 0.0, 1.0)

func press() -> void:
	if is_qte():
		_resolve(absf(cursor() - 0.5) <= float(settings.qte_half_width))

func _resolve(success: bool) -> void:
	results.append(success)
	if success:
		marked.append(int(targets[target_cursor]))
	_enter(Stage.MARK)

func _enter(next: int) -> void:
	stage = next
	elapsed = 0.0
	if stage == Stage.SLASHES:
		damage_hit.emit()
	elif stage == Stage.DONE:
		finished.emit()

func advance(delta: float) -> void:
	if stage == Stage.DONE:
		return
	elapsed += delta
	if is_qte():
		if cursor() > 0.5 + float(settings.qte_half_width):
			_resolve(false)
		return
	var duration := 0.0
	match stage:
		Stage.MORPH: duration = 0.65
		Stage.CUTIN: duration = 0.65
		Stage.VANISH: duration = 0.24
		Stage.MARK: duration = 0.28
		Stage.RETURN: duration = 0.28
		Stage.YAWN: duration = 1.0
		Stage.SLASHES: duration = 0.9
		Stage.EMBARRASSED: duration = 1.6
		Stage.RECOVER: duration = 0.3
	if elapsed < duration:
		return
	match stage:
		Stage.MORPH: _enter(Stage.CUTIN)
		Stage.CUTIN: _enter(Stage.VANISH)
		Stage.VANISH: _enter(Stage.QTE if not targets.is_empty() else Stage.RETURN)
		Stage.MARK:
			target_cursor += 1
			_enter(Stage.QTE if target_cursor < targets.size() else Stage.RETURN)
		Stage.RETURN: _enter(Stage.YAWN if not marked.is_empty() else Stage.EMBARRASSED)
		Stage.YAWN: _enter(Stage.SLASHES)
		Stage.SLASHES, Stage.EMBARRASSED: _enter(Stage.RECOVER)
		Stage.RECOVER: _enter(Stage.DONE)

func _actor(screen, frame: int, at: Vector2, alpha: float = 1.0) -> void:
	# Source rows use their actual gutters, preserving long hair and boot pixels.
	var tops := [0.0, 278.0, 510.0, 755.0]
	var heights := [278.0, 232.0, 245.0, 237.0]
	var row := int(frame / 4)
	var region := Rect2((frame % 4) * 396.5, tops[row], 396.5, heights[row])
	var dimensions := region.size * 0.57
	screen.draw_texture_rect_region(texture, Rect2(at - Vector2(dimensions.x * 0.5, dimensions.y * 0.98), dimensions), region, Color(1, 1, 1, alpha))

func _slash(screen, index: int, time: float, multiple: bool) -> void:
	var center: Vector2 = screen.FOE_POS[index] + Vector2(0, -58)
	var count := 5 if multiple else 1
	for i in count:
		var t := clampf((time - i * 0.105) / 0.24, 0, 1)
		if t <= 0 or t >= 1:
			continue
		var direction := Vector2(1, -0.48 if i % 2 == 0 else 0.65).normalized()
		var offset := Vector2(0, (i - count / 2.0) * 9)
		var start := center + offset - direction * 64
		var end := start + direction * 128 * minf(1, t * 3)
		var fade := sin(t * PI)
		screen.draw_line(start, end, Color(0.15, 0.6, 1, fade * 0.4), 13)
		screen.draw_line(start, end, Color(0.55, 0.9, 1, fade), 5)
		screen.draw_line(start, end, Color(1, 1, 1, fade), 2)

func draw(screen) -> void:
	# Background and enemies stay still during each QTE; only the bar moves.
	match stage:
		Stage.MORPH:
			_actor(screen, mini(int(elapsed / 0.65 * 4), 3), origin)
		Stage.CUTIN:
			_actor(screen, 4, origin)
			screen.draw_rect(Rect2(0, 96, 768, 390), Color(0.01, 0.03, 0.06, 0.6))
			var slide := (1.0 - smoothstep(0.0, 0.13, elapsed)) * -800.0 + smoothstep(0.51, 0.65, elapsed) * 800.0
			screen.draw_texture_rect(eyes, Rect2(slide - 16, 156, 800, 267), false)
		Stage.VANISH:
			var p := clampf(elapsed / 0.24, 0, 1)
			for i in 3:
				_actor(screen, 6, origin + Vector2(p * 380 - i * 26, 0), (1 - p) * (0.5 - i * 0.12))
		Stage.MARK:
			if results.back():
				_slash(screen, int(targets[target_cursor]), elapsed, false)
		Stage.RETURN:
			var p := smoothstep(0.0, 0.28, elapsed)
			_actor(screen, 6 if p < 0.7 else 7, origin + Vector2((1 - p) * 210, 0), p)
		Stage.YAWN:
			_actor(screen, 8 + mini(int(elapsed * 4), 3), origin)
		Stage.SLASHES:
			_actor(screen, 11, origin)
			for index in marked:
				_slash(screen, index, elapsed, true)
				if elapsed > 0.3:
					screen._label(str(damage), screen.FOE_POS[index] + Vector2(-20, -135 - elapsed * 16), WHITE, 24)
		Stage.EMBARRASSED:
			var frames := [12, 13, 14, 13, 14, 15]
			_actor(screen, int(frames[mini(int(elapsed / 1.6 * frames.size()), frames.size() - 1)]), origin)
			screen._label("MISS", origin + Vector2(-22, -153), Color("ffb3c1"), 22)
		Stage.RECOVER:
			_actor(screen, 7, origin)

func draw_qte(screen) -> void:
	screen._panel(Rect2(24, 506, 720, 129))
	screen._label("어쌔신 스텝", Vector2(48, 534), BLUE, 19)
	screen._label("성공 %d / %d" % [marked.size(), targets.size()], Vector2(610, 534), WHITE, 16)
	if is_qte():
		var enemy_name: String = str(screen.enemies[targets[target_cursor]].name)
		screen._label("%d / %d  ·  %s" % [target_cursor + 1, targets.size(), enemy_name], Vector2(285, 533), WHITE, 14)
		var half := float(settings.qte_half_width) * 664
		screen.draw_rect(Rect2(52, 558, 664, 35), Color("080e19"))
		screen.draw_rect(Rect2(384 - half, 554, half * 2, 43), Color("284a62"))
		screen.draw_rect(Rect2(384 - half, 554, half * 2, 43), BLUE, false, 1)
		screen.draw_rect(Rect2(52 + cursor() * 664 - 2, 552, 4, 47), WHITE)
		screen._label("SPACE", Vector2(354, 584), WHITE, 17)
		screen._label("중앙에 한 번!  ·  성공한 적에게만 귀환 후 연속 베기", Vector2(48, 620), BLUE, 13)
	else:
		var text := "크로노 체인을 단검으로"
		match stage:
			Stage.CUTIN, Stage.VANISH: text = "눈 깜짝할 사이에 사라졌다"
			Stage.MARK: text = "표식 성공!" if results.back() else "MISS"
			Stage.RETURN: text = "연우가 제자리로 돌아왔다"
			Stage.YAWN: text = "하아암…"
			Stage.SLASHES: text = "성공한 적에게 연속 베기!"
			Stage.EMBARRASSED: text = "…못 본 걸로 해."
			Stage.RECOVER: text = "어쌔신 스텝 종료"
		screen._label(text, Vector2(48, 583), WHITE, 20)
