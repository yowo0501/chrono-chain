extends SceneTree
var main: Node2D

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	var view: Node = main.get_node("Diorama")
	field.set_process(false)
	player.set_process(false)
	await capture("res://tests/preview-diorama-entrance.png")
	# Deterministic, non-dark route for a short in-engine walking preview.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/diorama-walk"))
	var frame := 0
	field.grace = 60
	for tile in [Vector2i(3,5), Vector2i(3,4), Vector2i(4,4), Vector2i(5,4), Vector2i(5,5), Vector2i(5,4), Vector2i(4,4), Vector2i(3,4), Vector2i(3,5), Vector2i(2,5)]:
		player._move_to(tile)
		for i in 6:
			player._advance_step(0.04001)
			view._sync_actors()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/diorama-walk/%04d.png" % frame)
			frame += 1
	player.warp_to(Vector2i(12, 7))
	view.focus = view._camera_target()
	view._position_camera()
	await capture("res://tests/preview-diorama-plaza.png")
	view.set_process(false)
	view.camera.size = 30
	view.focus = Vector3(12.5, 0, 7)
	view._position_camera()
	await capture("res://tests/preview-diorama-overview.png")
	print("DIORAMA PREVIEW: entrance, plaza, overview and 60 walking frames captured; draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
