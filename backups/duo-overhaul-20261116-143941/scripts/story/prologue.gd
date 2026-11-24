extends "res://scripts/story/story_screen.gd"
## Data-driven non-combat event player. Timed actions never consume dialogue input.
signal event_started(index: int, event: Dictionary)
signal finished

const Stage = preload("res://scripts/story/prologue_stage.gd")
const TEXT_SPEED := 30.0
var events: Array = []
var event_index := -1
var current: Dictionary = {}
var elapsed := 0.0
var text_elapsed := 0.0
var waiting_for_text := false
var completed := false
var stage: Control
var narration: Label
var dialogue_box: Panel
var speaker: Label
var body: Label
var hint: Label
var ending_buttons: Array[Button] = []
var impact_sound: AudioStreamPlayer
var logo: Texture2D = preload("res://assets/prologue/logo-chain-lettering.png")
var logo_alpha := 0.0

func _ready() -> void:
	super._ready()
	events = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue.json")).events
	stage = Stage.new()
	add_child(stage)
	stage.hide()
	narration = label_at("", Rect2(90,206,588,228), 25)
	narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	narration.add_theme_constant_override("line_spacing", 12)
	dialogue_box = Panel.new()
	dialogue_box.position = Vector2(28,484)
	dialogue_box.size = Vector2(712,152)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_box.add_theme_stylebox_override("panel", box(Color(0.025,0.045,0.085,0.96), Color("8d9fac")))
	add_child(dialogue_box)
	speaker = label_at("", Rect2(50,499,660,30), 20, Color("c4dbed"))
	body = label_at("", Rect2(50,540,660,82), 22)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 7)
	hint = label_at("", Rect2(28,642,712,22), 12, Color("a6adb9"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	impact_sound = AudioStreamPlayer.new()
	impact_sound.stream = load("res://assets/prologue/chain_clash.wav")
	impact_sound.volume_db = -9.0
	add_child(impact_sound)
	ending_buttons.append(button_at("다시 보기", Rect2(174,544,200,52), restart))
	ending_buttons.append(button_at("메뉴로", Rect2(394,544,200,52), return_to_menu))
	for button in ending_buttons:
		button.hide()
	next_event()

func next_event() -> void:
	event_index += 1
	if event_index >= events.size():
		return
	current = events[event_index]
	elapsed = 0.0
	text_elapsed = 0.0
	waiting_for_text = current.type in ["narration", "dialogue"]
	narration.hide()
	dialogue_box.hide()
	speaker.hide()
	body.hide()
	hint.text = "F10 메뉴로"
	match str(current.type):
		"narration":
			narration.text = current.get("display_text", current.text)
			narration.visible_characters = 0
			narration.show()
		"dialogue":
			speaker.text = current.speaker
			body.text = current.text
			body.visible_characters = 0
			dialogue_box.show()
			speaker.show()
			body.show()
		"fade_in":
			stage.show()
			stage.modulate.a = 0.0
		"face":
			stage.facing[current.actor] = current.direction
		"draw_chains":
			stage.drawing_chains = true
		"rush":
			stage.rushing = true
		"impact":
			stage.hide()
			impact_sound.play()
		"ending":
			logo_alpha = 0.0
	if waiting_for_text:
		hint.text = "클릭 / Enter / Space · 문장 완성     F10 메뉴로"
	event_started.emit(event_index, current)
	queue_redraw()

func _process(delta: float) -> void:
	advance_time(delta)

func advance_time(delta: float) -> void:
	if completed or current.is_empty():
		return
	elapsed += delta
	if waiting_for_text:
		text_elapsed += delta
		var label: Label = narration if current.type == "narration" else body
		label.visible_characters = mini(int(text_elapsed * TEXT_SPEED), label.text.length())
		if current.type == "narration":
			narration.modulate.a = minf(1.0, elapsed / 0.45)
		if label.visible_characters >= label.text.length():
			hint.text = "클릭 / Enter / Space · 다음  ▾     F10 메뉴로"
		return
	var progress := clampf(elapsed / float(current.get("duration", 1.0)), 0.0, 1.0)
	match str(current.type):
		"fade_in":
			stage.modulate.a = smoothstep(0.0, 1.0, progress)
		"draw_chains":
			stage.chain_progress = smoothstep(0.0, 1.0, progress)
		"rush":
			stage.rush_progress = progress * progress
		"ending":
			logo_alpha = smoothstep(0.0, 1.0, progress)
	queue_redraw()
	if progress >= 1.0:
		if current.type == "ending":
			completed = true
			hint.text = "프롤로그 끝     F10 메뉴로"
			for button in ending_buttons:
				button.show()
			ending_buttons[1].grab_focus()
			finished.emit()
		else:
			next_event()

func advance_dialogue() -> void:
	if not waiting_for_text or completed:
		return
	var label: Label = narration if current.type == "narration" else body
	if label.visible_characters < label.text.length():
		text_elapsed = float(label.text.length()) / TEXT_SPEED + 1.0
		label.visible_characters = label.text.length()
		narration.modulate.a = 1.0
	else:
		next_event()

func _unhandled_input(event: InputEvent) -> void:
	var advance: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		advance = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]
	if advance and not completed:
		advance_dialogue()
		get_viewport().set_input_as_handled()

func restart() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/prologue/prologue.tscn")

func return_to_menu() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/menu/title.tscn")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color.BLACK)
	if logo_alpha > 0.0:
		draw_texture_rect(logo, Rect2(84,-5,600,600), false, Color(1,1,1,logo_alpha))
