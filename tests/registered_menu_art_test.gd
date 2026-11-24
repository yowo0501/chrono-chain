extends SceneTree
const OUT := "res://assets/art_overhaul/2026-11-23/fields/v003/review/"
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in 6:
		await process_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await settle()
	var button: Button
	for candidate in current_scene.find_children("*","Button",true,false):
		if candidate.text == "튜토리얼 실행":
			button = candidate
	assert(button != null, "Actual title menu has tutorial button")
	if DisplayServer.get_name() != "headless":
		await capture("08-registered-title-menu")
	var at := button.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = at
	down.pressed = true
	root.push_input(down,true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = at
	root.push_input(up,true)
	await settle()
	assert(current_scene.scene_file_path == "res://scenes/main/main.tscn")
	var town: Node = current_scene.get_node("Field/Town2D")
	assert(town.floors.asphalt.resource_path.contains("/v003/"))
	assert(town.art.factory.resource_path.contains("/v003/"))
	assert(town.floors.paving.resource_path.contains("/v003/"))
	assert(root.get_node("Tutorial").active)
	print("MENU CLICK VERIFIED: "+ProjectSettings.globalize_path("res://"))
	print("TUTORIAL LOADS v003 paving + asphalt + factory")
	if DisplayServer.get_name() != "headless":
		await capture("09-registered-tutorial-entry")
		var tutorial: Node = root.get_node("Tutorial")
		tutorial.active = false
		tutorial.enabled = false
		tutorial.view.hide()
		paused = false
		current_scene.get_node("Player").set_process(false)
		current_scene.get_node("Field").set_process(false)
		await capture("10-registered-gameplay")
	quit()

