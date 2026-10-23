extends SceneTree
const FOLDER := "res://.godot/map-preview-frames"
var main: Node2D
var field: Node2D
var player: Node2D
var frame := 0

func _initialize() -> void:
	call_deferred("run")

func capture(count: int, tick: bool = true) -> void:
	for i in count:
		if tick:
			field._process(0.04)
			if player._moving:
				player._advance_step(0.04)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(FOLDER + "/%04d.png" % frame)
		frame += 1

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	field = main.get_node("Field")
	player = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	field.rng.seed = 19
	await capture(1, false)
	root.get_texture().get_image().save_png("res://tests/preview-map-system.png")
	field.hud.show_map = true
	await capture(25, false)
	root.get_texture().get_image().save_png("res://tests/preview-map-overview.png")
	field.hud.show_map = false
	await capture(30)
	var goals: Array[Vector2i] = [Vector2i(9,4)]
	var route: Array[Vector2i] = field.path_to(player.grid_pos, goals)
	for tile in route:
		player._move_to(tile)
		await capture(6)
		if player._moving:
			player._advance_step(0.0001)
	player.facing = "right"
	player._update_sprite(false)
	var manager := root.get_node("EncounterManager")
	if manager.active:
		# The revised map guarantees a battle before this dark lamp can be repaired.
		for i in 240:
			await capture(1, false)
			if manager.screen != null and manager.transition == null:
				break
		assert(manager.screen != null and manager.transition == null)
		root.get_texture().get_image().save_png("res://tests/preview-dark-entry.png")
		# Preview fixture: resolve that battle as won, then demonstrate lamp repair.
		manager._finish_battle(true)
		await process_frame
	await capture(20)
	field.interact(player)
	await capture(1, false)
	root.get_texture().get_image().save_png("res://tests/preview-map-repair.png")
	await capture(30)
	print("MAP PREVIEW: ",frame," frames, 40ms cadence")
	quit()
