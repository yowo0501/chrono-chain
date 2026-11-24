extends Control
## Two dark pulses, then a clockwise pixel wipe; create the battle only at black.
signal covered
signal finished
const PULSE_DURATION := 0.36
const PULSE_COUNT := 2
const WIPE_DURATION := 1.0
const BLACK_HOLD := 0.12
const REVEAL_DURATION := 0.28
const COVER_TIME := PULSE_DURATION * PULSE_COUNT + WIPE_DURATION
const TOTAL_TIME := COVER_TIME + BLACK_HOLD + REVEAL_DURATION
var elapsed := 0.0
var did_cover := false
var did_finish := false

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resize()
	get_viewport().size_changed.connect(_resize)

func _resize() -> void:
	size = get_viewport_rect().size
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if did_finish:
		return
	elapsed += delta
	if elapsed >= COVER_TIME and not did_cover:
		did_cover = true
		covered.emit()
	if elapsed >= TOTAL_TIME:
		did_finish = true
		finished.emit()
	queue_redraw()

func pulse_alpha() -> float:
	if elapsed >= PULSE_DURATION * PULSE_COUNT:
		return 0.0
	var phase := fmod(elapsed, PULSE_DURATION) / PULSE_DURATION
	return sin(phase * PI) * 0.88

func wipe_progress() -> float:
	return clampf((elapsed - PULSE_DURATION * PULSE_COUNT) / WIPE_DURATION, 0, 1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if elapsed < PULSE_DURATION * PULSE_COUNT:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, pulse_alpha()))
	elif elapsed < COVER_TIME:
		var sweep := wipe_progress() * TAU
		var center := size * 0.5
		# Four logical pixels become sixteen screen pixels at the default window size.
		for y in range(0, int(ceil(size.y)), 4):
			for x in range(0, int(ceil(size.x)), 4):
				var offset := Vector2(x + 2, y + 2) - center
				var angle := fposmod(atan2(offset.y, offset.x) + PI * 0.5, TAU)
				if angle <= sweep:
					draw_rect(Rect2(x, y, 4, 4), Color.BLACK)
	else:
		var reveal := clampf((elapsed - COVER_TIME - BLACK_HOLD) / REVEAL_DURATION, 0, 1)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - reveal))
