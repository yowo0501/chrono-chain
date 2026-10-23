extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	field.set_process(false)
	player.set_process(false)
	player.warp_to(Vector2i(21,40))
	camera.reset_smoothing()
	await capture("res://tests/preview-night-plaza.png")
	var frames := "res://.godot/night-walk"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames))
	player.warp_to(Vector2i(21,44))
	camera.reset_smoothing()
	field.grace = 10000
	var frame := 0
	for direction in ["right","right","right","right","down","down","left","left","left","left","up","up"]:
		player._move_to(player.grid_pos+player.DIR_VECTOR[direction])
		for step_frame in 6:
			player._advance_step(player.MOVE_TIME/6.0+0.00001)
			await capture(frames.path_join("%04d.png" % frame))
			frame += 1
	player.warp_to(Vector2i(17,22))
	camera.reset_smoothing()
	await capture("res://tests/preview-night-bakery.png")
	player.warp_to(Vector2i(103,14))
	camera.reset_smoothing()
	await capture("res://tests/preview-night-dark.png")
	field.hud.show_map = true
	await capture("res://tests/preview-night-map.png")
	field.hud.set_process(false)
	field.hud.hide()
	camera.reparent(main)
	camera.position = Vector2(1024,512)
	camera.zoom = Vector2(0.115,0.115)
	camera.reset_smoothing()
	# All-lit overview is an art/layout inspection, separate from initial gameplay.
	for i in field.lit.size():
		field.lit[i] = true
	field.lighting_revision += 1
	await capture("res://tests/preview-night-layout.png")
	print("NIGHT CITY PREVIEW COMPLETE")
	main.free()
	quit()
