extends SceneTree
const OUT = "res://assets/character_overhaul/2026-11-24/legacy_retarget/review/"
var checks = 0
func _initialize(): call_deferred("run")
func verify(ok,label):
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
func settle():
	for i in 8: await process_frame
func capture(name):
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	var router = root.get_node("StoryRouter")
	router.open_scene(router.MENU)
	await settle()
	var menu = current_scene
	menu.advance_intro(6.1)
	verify(menu.map_test_button.visible and not menu.map_test_button.disabled,"Map button visible")
	verify(menu.map_test_button.position.y > menu.start_button.position.y,"Below Start")
	await capture("menu")
	menu.map_test_button.pressed.emit()
	await settle()
	verify(current_scene.scene_file_path.ends_with("map_movement_test.tscn"),"Button routes actual test scene")
	var field = current_scene.get_node("Field")
	var player = current_scene.get_node("Player")
	verify(field.movement_only,"Movement-only active")
	verify(field.symbols.is_empty() and not field.boss_spawned,"No enemies")
	verify(not root.get_node("Tutorial").active and not paused,"No tutorial dialogue")
	verify(player.sprite.texture.get_width()==960,"High-resolution C field atlas")
	verify(field.get_node("Town2D").floors.paving.get_width()==504,"Original floor detail retained")
	var start = player.grid_pos
	var direction = ""
	for pair in [["ui_right",Vector2i.RIGHT],["ui_left",Vector2i.LEFT],["ui_down",Vector2i.DOWN],["ui_up",Vector2i.UP]]:
		if field.can_step(start,start+pair[1]): direction=pair[0]; break
	verify(direction!="","Walkable spawn")
	Input.action_press(direction)
	await create_timer(0.55).timeout
	Input.action_release(direction)
	await create_timer(0.35).timeout
	verify(player.grid_pos!=start,"Actual input moves character")
	field._process(600.0)
	field.player_step_completed(player)
	verify(not root.get_node("EncounterManager").active and field.symbols.is_empty(),"No encounter after time or movement")
	player.warp_to(Vector2i(43,42))
	await capture("map-movement")
	var back = InputEventKey.new()
	back.keycode=KEY_F10
	back.pressed=true
	Input.parse_input_event(back)
	await settle()
	verify(current_scene.scene_file_path==router.MENU,"F10 returns menu")
	current_scene.advance_intro(6.1)
	current_scene.start_button.pressed.emit()
	await settle()
	verify(current_scene.scene_file_path==router.PROLOGUE,"Original Start still starts prologue")
	var chase = load("res://scripts/story/chapter/chase_field.gd").new()
	root.add_child(chase)
	chase.mode="chase"
	chase.set_process(false)
	verify(chase.actor.texture.resource_path.contains("/field_c/"),"Prologue now C actor")
	verify(chase.floor_art.resource_path.contains("/style_c/"),"Prologue now C floor")
	chase.free()
	print("MAP MOVEMENT INTEGRATION: %d checks / 0 failures"%checks)
	quit()
