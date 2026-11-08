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
	check(menu.get_viewport().gui_get_focus_owner().text == "프롤로그 실행", "Menu defaults to prologue")
	await click(menu.get_viewport().gui_get_focus_owner().get_global_rect().get_center())
	await settle()
	var story: Control = current_scene
	story.set_process(false)
	check(story.event_index == 0 and not story.stage.visible, "Opening starts on black")
	check(not tutorial.enabled and not manager.active, "Prologue does not enable tutorial/combat")
	story.advance_time(0.1)
	var index: int = story.event_index
	await key(KEY_SPACE)
	check(story.event_index == index and story.narration.visible_characters == story.narration.text.length(), "First key reveals text without skipping")
	await key(KEY_ENTER)
	check(story.event_index == index + 1, "Second key advances exactly once")
	await click(story.narration.get_global_rect().get_center())
	check(story.event_index == 1 and story.narration.visible_characters == story.narration.text.length(), "Click reveals text")
	await click(story.narration.get_global_rect().get_center())
	check(story.event_index == 2, "Next click advances text")
	var lines := 2
	var completed_signal := [false]
	story.finished.connect(func(): completed_signal[0] = true)
	for safety in 80:
		if story.completed:
			break
		if story.waiting_for_text:
			lines += 1
			if story.current.has("display_text"):
				check(story.current.display_text.replace("\n", " ") == story.current.text, "Presentation line breaks preserve source wording")
			story.advance_time(20)
			var text_label: Label = story.narration if story.current.type == "narration" else story.body
			check(text_label.get_line_count() * text_label.get_line_height() <= text_label.size.y, "Dialogue fits vertically: " + text_label.text)
			story.advance_dialogue()
		else:
			index = story.event_index
			story.advance_dialogue()
			check(story.event_index == index, "Timed staging cannot be skipped by dialogue input")
			story.advance_time(10)
	check(lines == 20, "All twenty source lines played")
	check(story.completed and completed_signal[0], "Timeline reaches final logo and completion signal")
	check(story.stage.chain_progress == 1 and story.stage.rush_progress == 1, "Draw and rush finish")
	check(story.stage.facing.chuheun == "up", "Chuheun turns back toward monster")
	check(story.logo_alpha == 1 and not story.stage.visible, "Logo follows blackout")
	check(manager.encounters == 0 and not manager.active and not paused, "No combat during full prologue")
	story.restart()
	await settle()
	check(current_scene.event_index == 0 and current_scene.stage.chain_progress == 0, "Replay starts from clean opening")
	await key(KEY_F10)
	await settle()
	check(current_scene.scene_file_path == router.MENU, "F10 returns to menu")
	current_scene._open_tutorial()
	await settle()
	check(current_scene.name == "Main" and tutorial.active and paused, "Tutorial button opens original field and onboarding")
	await key(KEY_F10)
	await settle()
	check(current_scene.scene_file_path == router.MENU and not paused and not tutorial.active, "F10 exits even paused tutorial")
	current_scene._open_tutorial()
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
