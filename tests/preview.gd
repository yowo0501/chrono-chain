extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
func _initialize() -> void:
	call_deferred("run")
func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + file + ".png")
func run() -> void:
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	await capture("preview-field")
	var manager: Node = root.get_node("EncounterManager")
	manager.start_battle(main.get_node("Player"))
	manager.transition.set_process(false)
	manager.transition.advance(0.18)
	await capture("preview-flash")
	manager.transition.advance(0.54 + 0.5)
	await capture("preview-wipe")
	manager.transition.advance(0.51)
	await capture("preview-black")
	manager.transition.advance(0.5)
	await create_timer(1.2).timeout
	var screen: Control = manager.screen
	screen.set_process(false)
	await capture("preview-battle")
	screen.select_command(0)
	screen.confirm_target()
	for frame in 8:
		screen.qte_elapsed = frame / 16.0 + 0.01
		screen.queue_redraw()
		await capture("preview-twirl-" + str(frame))
	screen.qte_elapsed = 0.4
	screen._resolve_qte(true)
	screen.advance(0.2)
	screen.queue_redraw()
	await capture("preview-critical")
	screen.advance(0.38)
	screen.queue_redraw()
	await capture("preview-recovery")
	screen.advance(0.3)
	screen.select_command(0)
	screen.confirm_target()
	for frame in 8:
		screen.qte_elapsed = frame / 16.0 + 0.01
		screen.queue_redraw()
		await capture("preview-yeonwoo-twirl-" + str(frame))
	screen.qte_elapsed = 0.4
	screen._resolve_qte(true)
	screen.advance(0.2)
	screen.queue_redraw()
	await capture("preview-yeonwoo-critical")
	screen.fx_time = 0
	screen.shake_time = 0
	screen._start_party_turn()
	screen.special_actor = 0
	screen.special_elapsed = 0.6
	screen.queue_redraw()
	await capture("preview-chuheun-stretch")
	screen.special_actor = 1
	screen.queue_redraw()
	await capture("preview-yeonwoo-yawn")
	quit()
