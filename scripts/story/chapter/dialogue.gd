extends Control
## Local dialogue pause: no SceneTree pause or hidden QTE time consumption.
signal closed
var lines: Array = []
var index := 0
var reveal := 0.0
var after := Callable()
var active := false
var require_enter := false
var any_key := false
var highlight := Rect2()
var speaker_label: Label
var text_label: Label
var hint: Label
var panel: Panel
var current: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_font := SystemFont.new()
	theme_font.font_names = PackedStringArray(["Malgun Gothic","Noto Sans CJK KR"])
	theme = Theme.new()
	theme.default_font = theme_font
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.045,0.085,0.97)
	style.border_color = Color("8cabbc")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size",19)
	speaker_label.add_theme_color_override("font_color",Color("eed294"))
	panel.add_child(speaker_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size",18)
	text_label.add_theme_constant_override("line_spacing",4)
	panel.add_child(text_label)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size",12)
	panel.add_child(hint)
	hide()

func play(entries: Array, callback: Callable = Callable(), focus: Rect2 = Rect2(), enter_only: bool = false, any_input: bool = false) -> void:
	lines = entries.duplicate(true)
	index = 0
	after = callback
	highlight = focus
	require_enter = enter_only
	any_key = any_input
	active = not lines.is_empty()
	if not active:
		if after.is_valid(): after.call()
		return
	panel.position = Vector2(24,112 if focus.has_area() else 480)
	panel.size = Vector2(720,164)
	speaker_label.position = Vector2(20,10)
	text_label.position = Vector2(20,40)
	text_label.size = Vector2(680,94)
	hint.position = Vector2(20,140)
	show()
	_set_line()

func _set_line() -> void:
	current = lines[index]
	var who := str(current.get("speaker","괄호"))
	speaker_label.text = "" if who == "괄호" else who
	text_label.text = ("( %s )" % str(current.text)) if who == "괄호" else str(current.text)
	reveal = 0.0
	text_label.visible_characters = 0
	hint.text = "Enter · 체인으로 선제공격" if require_enter else "아무 키 / 클릭 · 계속" if any_key else "Space / Enter / 클릭 · 계속"
	queue_redraw()

func tick(delta: float) -> void:
	if active:
		reveal += delta*42.0
		text_label.visible_characters = mini(int(reveal),text_label.text.length())

func advance_line() -> void:
	if not active: return
	if text_label.visible_characters < text_label.text.length():
		reveal = text_label.text.length()
		text_label.visible_characters = text_label.text.length()
		return
	index += 1
	if index < lines.size():
		_set_line()
	else:
		active = false
		hide()
		var callback := after
		after = Callable()
		closed.emit()
		if callback.is_valid(): callback.call()

func accept(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_F10: return false
		if (require_enter and key in [KEY_ENTER,KEY_KP_ENTER]) or (not require_enter and (any_key or key in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER,KEY_Z])):
			advance_line()
	elif not require_enter and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		advance_line()
	return true

func _draw() -> void:
	if active and highlight.has_area():
		draw_rect(highlight.grow(5),Color("f5d477"),false,3)

