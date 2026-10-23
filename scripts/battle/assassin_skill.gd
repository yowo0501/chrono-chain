extends RefCounted
## Four positional attempts; the pressed timing selects the marked foe.
## Successful marks deal damage together after the return/yawn.
signal damage_hit
signal finished
enum Stage { MORPH, VANISH, QTE, MARK, RETURN, YAWN, SLASHES, EMBARRASSED, RECOVER, DONE }
const BLUE := Color("61cfff")
const WHITE := Color("e9faff")
const STRIKES := 4
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
var target_resolver := Callable()

func setup(config: Dictionary, power: int, from: Vector2, living: Array, atlas: Texture2D) -> void:
	settings = config
	origin = from
	targets.clear()
	if not living.is_empty():
		for hit in STRIKES:
			targets.append(living[hit % living.size()])
	texture = atlas
	damage = roundi(power * float(config.damage_multiplier))

func is_qte() -> bool:
	return stage == Stage.QTE

func hit_counts() -> Dictionary:
	var counts := {}
	for index in marked:
		counts[index] = int(counts.get(index, 0)) + 1
	return counts

func cursor() -> float:
	return clampf(elapsed / float(settings.qte_duration), 0.0, 1.0)

func press() -> void:
	if is_qte():
		if target_resolver.is_valid():
			var target: int = target_resolver.call(cursor())
			if target >= 0:
				targets[target_cursor] = target
			_resolve(target >= 0)
		else:
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
		if cursor() >= 1.0:
			_resolve(false)
		return
	var duration := 0.0
	match stage:
		Stage.MORPH: duration = 0.65
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
		Stage.MORPH: _enter(Stage.VANISH)
		Stage.VANISH: _enter(Stage.QTE if not targets.is_empty() else Stage.RETURN)
		Stage.MARK:
			target_cursor += 1
			_enter(Stage.QTE if target_cursor < targets.size() else Stage.RETURN)
		Stage.RETURN: _enter(Stage.YAWN if not marked.is_empty() else Stage.EMBARRASSED)
		Stage.YAWN: _enter(Stage.SLASHES)
		Stage.SLASHES, Stage.EMBARRASSED: _enter(Stage.RECOVER)
		Stage.RECOVER: _enter(Stage.DONE)

func actor_region(frame: int) -> Rect2:
	var tops := [0.0,278.0,510.0,755.0]
	var heights := [278.0,232.0,245.0,237.0]
	# The dash extends beyond its nominal cell; the return starts after it.
	if frame == 6:
		return Rect2(793,278,477,232)
	if frame == 7:
		return Rect2(1270,278,316,232)
	return Rect2((frame%4)*396.5,tops[frame/4],396.5,heights[frame/4])

func actor_rect(frame: int, at: Vector2, battle_scale: float) -> Rect2:
	# 236px standing figure -> the ordinary Yeonwoo sprite's 162px figure.
	# One scale for every pose; crouching/yawning never changes body scale.
	var scale := (162.0/236.0)*battle_scale
	var feet := [Vector2(199,262),Vector2(208,262),Vector2(262,259),Vector2(240,260),
		Vector2(187,219),Vector2(205,219),Vector2(250,219),Vector2(173,226),
		Vector2(194,239),Vector2(208,239),Vector2(221,239),Vector2(250,239),
		Vector2(176,226),Vector2(220,226),Vector2(225,226),Vector2(223,226)]
	return Rect2(at-feet[frame]*scale,actor_region(frame).size*scale)

func _actor(screen, frame: int, at: Vector2, alpha: float = 1.0) -> void:
	screen.draw_texture_rect_region(texture,actor_rect(frame,at,screen.ACTOR_SCALE),actor_region(frame),Color(1,1,1,alpha))

func _slash(screen, index: int, time: float, multiple: bool) -> void:
	var center: Vector2 = screen.foe_position(index) + Vector2(0, -58)
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
			var counts := hit_counts()
			for index in counts:
				_slash(screen, index, elapsed, true)
				if elapsed > 0.3:
					screen._label("%d  (%d회)" % [damage * counts[index], counts[index]], screen.foe_position(index) + Vector2(-44, -118 - elapsed * 16), WHITE, 20)
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
		screen._label("%d / 4 · 위치에 맞춰 SPACE" % (target_cursor + 1), Vector2(285, 533), WHITE, 14)
		screen.draw_position_bar(cursor(), Rect2(52, 558, 664, 35))
		screen._label("선택한 위치에 표식 · 네 번 입력 후 귀환하여 일제 타격", Vector2(48, 620), BLUE, 13)
	elif stage == Stage.MARK:
		screen._label("SUCCESS" if results.back() else "MISS",Vector2(48,583),WHITE,20)
