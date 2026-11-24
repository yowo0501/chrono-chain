extends Control
## Freeze the contact point inside a diagonal slit; close both shutters after 0.5 s.
signal covered
signal finished
const FOCUS_DURATION := 0.5
const CLOSE_DURATION := 0.3
const BLACK_HOLD := 0.12
const REVEAL_DURATION := 0.28
const COVER_TIME := FOCUS_DURATION + CLOSE_DURATION
const TOTAL_TIME := COVER_TIME + BLACK_HOLD + REVEAL_DURATION
const NORMAL := Vector2(0.8466, 0.5321) # Slit follows the 32-degree diagonal in the brief.
var elapsed := 0.0
var did_cover := false
var did_finish := false
var snapshot: Texture2D
var focus_uv := Vector2(0.5, 0.5)

func configure(frame: Image, contact_uv: Vector2) -> void:
	focus_uv = contact_uv.clamp(Vector2(0.04, 0.04), Vector2(0.96, 0.96))
	if frame != null and not frame.is_empty():
		snapshot = ImageTexture.create_from_image(frame)

func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
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

func close_progress() -> float:
	return clampf((elapsed - FOCUS_DURATION) / CLOSE_DURATION, 0.0, 1.0)

func zoom_factor() -> float:
	var t := clampf(elapsed / FOCUS_DURATION, 0.0, 1.0)
	return lerpf(1.0, 1.65, 1.0 - pow(1.0 - t, 3.0))

func shutter_polygon(normal: Vector2, width: float) -> PackedVector2Array:
	# Clip the viewport rectangle against one edge of the slit.
	var corners := PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	var result := PackedVector2Array()
	var focus := size * focus_uv
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var da := (a - focus).dot(normal) - width
		var db := (b - focus).dot(normal) - width
		if da >= 0.0:
			result.append(a)
		if (da >= 0.0) != (db >= 0.0):
			result.append(a.lerp(b, da / (da - db)))
	return result

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _draw() -> void:
	if elapsed < COVER_TIME:
		var focus := size * focus_uv
		var zoom := zoom_factor()
		if snapshot != null:
			draw_texture_rect(snapshot, Rect2(focus - focus * zoom, size * zoom), false)
		var t := close_progress()
		var width := minf(size.x, size.y) * 0.20 * (1.0 - t * t * (3.0 - 2.0 * t))
		for normal in [NORMAL, -NORMAL]:
			var polygon := shutter_polygon(normal, width)
			if polygon.size() >= 3:
				draw_colored_polygon(polygon, Color.BLACK)
	else:
		var reveal := clampf((elapsed - COVER_TIME - BLACK_HOLD) / REVEAL_DURATION, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 1.0 - reveal))
