extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 3:
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
	await capture("res://tests/preview-hg2d-start.png")
	player.warp_to(Vector2i(7,5))
	camera.reset_smoothing()
	await capture("res://tests/preview-hg2d-town.png")
	player.warp_to(Vector2i(17,9))
	await capture("res://tests/preview-hg2d-dark.png")
	camera.reparent(main)
	camera.position = Vector2(400,240)
	camera.zoom = Vector2(0.32,0.32)
	field.hud.set_process(false)
	field.hud.hide()
	await capture("res://tests/preview-hg2d-overview.png")
	main.free()
	print("2D PREVIEW COMPLETE")
	quit()
