extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 5:
		await process_frame

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.keycode = code
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame

func run() -> void:
	var router: Node = root.get_node("StoryRouter")
	var tutorial: Node = root.get_node("Tutorial")
	var manager: Node = root.get_node("EncounterManager")
	check(ProjectSettings.get_setting("application/run/main_scene") == router.MENU, "Game boots to menu")
	router.open_scene(router.MENU)
	await settle()
	var menu: Control = current_scene
	menu.advance_intro(6.1)
	check(menu.get_viewport().gui_get_focus_owner().text == "시 작", "Menu defaults to prologue")
	await click(menu.get_viewport().gui_get_focus_owner().get_global_rect().get_center())
	await settle()
	var story: Control = current_scene
	story.set_process(false)
	check(story.mode=="opening" and not story.field.visible,"New chapter starts at rooftop")
	check(not tutorial.enabled and not manager.active,"Old onboarding is isolated")
	story.advance_time(0.1)
	await key(KEY_SPACE)
	check(story.guide.index==0 and story.guide.text_label.visible_characters==story.guide.text_label.text.length(),"First key completes text")
	await key(KEY_ENTER)
	check(story.guide.index==1,"Second key advances one line")
	await key(KEY_F10)
	await settle()
	check(current_scene.scene_file_path==router.MENU,"F10 exits the chapter")
	router.open_scene("res://scenes/main/main.tscn")
	await settle()
	check(current_scene.name == "Main" and tutorial.active and paused, "Tutorial button opens original field and onboarding")
	await key(KEY_F10)
	await settle()
	check(current_scene.scene_file_path == router.MENU and not paused and not tutorial.active, "F10 exits even paused tutorial")
	router.open_scene("res://scenes/main/main.tscn")
	await settle()
	check(tutorial.active and tutorial.seen.has("move"), "Tutorial can start again")
	# Simulate a real active encounter and leave it through the same router.
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	var field: Node = current_scene.get_node("Field")
	manager.start_battle(field.walker())
	check(manager.active, "Combat started for cleanup regression")
	await key(KEY_F10)
	await settle()
	check(not manager.active and manager.screen == null and manager.get_child_count() == 0, "Returning from combat cleans persistent overlay")
	check(current_scene.scene_file_path == router.MENU and not paused, "Combat return restores menu")
	print("PROLOGUE TEST: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)

func click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	root.push_input(event, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = point
	root.push_input(release, true)
	Input.flush_buffered_events()
	await process_frame
