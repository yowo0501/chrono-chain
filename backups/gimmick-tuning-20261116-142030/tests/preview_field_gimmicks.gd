extends SceneTree
const OUT := "res://art-reviews/field-gimmicks"
var player: Node2D
var field: Node2D

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	player = main.get_node("Player")
	field = main.get_node("Field")
	player.set_process(false)
	field.set_process(false)
	field.grace = 10000.0
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()
	player.warp_to(Vector2i(21,45))
	player.follower_grid = Vector2i(20,45)
	player.follower.position = Vector2(player.follower_grid * 16)
	player.facing = "right"
	player.follower.facing = "right"
	player._update_sprite(false)
	await capture("01-field")
	Input.action_press("field_dash")
	player._move_to(player.grid_pos + Vector2i.RIGHT)
	player._advance_step(0.06)
	await capture("02-dash")
	player._advance_step(0.06)
	Input.action_release("field_dash")
	player.warp_to(Vector2i(21,45))
	player.follower_grid = Vector2i(20,45)
	player.follower.position = Vector2(player.follower_grid * 16)
	field._spawn_symbol(player.grid_pos + Vector2i.RIGHT * 2)
	player.request_chain()
	player._advance_chain(0.083)
	await capture("03-chain")
	player._advance_chain(0.02)
	var manager := root.get_node("EncounterManager")
	assert(manager.active)
	manager.transition.set_process(false)
	manager.transition.elapsed = 0.0
	manager.transition.advance(0.2)
	await capture("04-focus")
	manager.transition.advance(0.35)
	await capture("05-shutters")
	manager.transition.advance(0.15)
	await capture("06-closing")
	manager.transition.advance(0.11)
	await capture("07-black")
	manager.transition.advance(0.41)
	manager.screen.set_process(false)
	manager.screen.advance(1.01)
	await capture("08-preemptive")
	manager._finish_battle(true)
	main.free()
	await process_frame
	print("FIELD GIMMICKS PREVIEW: dash, chain, diagonal focus, shutters, full black, initiative")
	quit()
