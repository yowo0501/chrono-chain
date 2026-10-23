extends SceneTree
var player: Node2D
var frame_number := 0
const FOLDER := "res://.godot/field-modern-frames"

func _initialize() -> void:
	call_deferred("run")

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FOLDER.path_join("%04d.png" % frame_number))
	frame_number += 1

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	main.get_node("Field").test_grid = true
	root.add_child(main)
	await process_frame
	player = main.get_node("Player")
	player.set_process(false)
	root.get_node("EncounterManager").balance.encounter.safe_steps = 1000
	player.grid_pos = Vector2i(7, 6)
	player.position = Vector2(player.grid_pos * 16)
	player.follower_grid = Vector2i(6, 6)
	player.follower.position = Vector2(player.follower_grid * 16)
	player.facing = "down"
	player._update_sprite(false)
	player.follower.facing = "down"
	var camera: Camera2D = player.get_node("Camera2D")
	camera.top_level = true
	camera.position = Vector2(160, 112)
	for i in 40:
		await capture()
	root.get_texture().get_image().save_png("res://tests/preview-field-modern.png")
	for segment in [["right", 6], ["down", 2], ["left", 6], ["up", 2]]:
		for tile in segment[1]:
			player._move_to(player.grid_pos + player.DIR_VECTOR[segment[0]])
			for i in 12:
				player._advance_step(player.MOVE_TIME / 12.0)
				if i == 11 and player._moving:
					player._advance_step(0.0001)
				await capture()
	player.facing = "down"
	player._update_sprite(false)
	player.follower.facing = "down"
	for i in 40:
		await capture()
	print("FIELD WALK CAPTURE: ", frame_number, " frames, 20ms cadence")
	quit()
