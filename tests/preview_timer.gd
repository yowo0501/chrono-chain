extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var screen: Control
var folder := "res://.godot/timer-preview"

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	screen.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label + ".png"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	screen = Screen.new()
	screen.setup(manager.party, manager.balance, RandomNumberGenerator.new(), true)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	await capture("command")
	screen.select_command(3)
	screen.select_skill(0)
	var captured := {}
	for frame in 700:
		if screen.phase != Screen.Phase.TIMER:
			break
		var stage: int = screen.timer_cast.stage
		if not captured.has(stage) and screen.timer_cast.elapsed >= 0.10:
			await capture("automatic-stage-%02d" % stage)
			captured[stage] = true
		screen.advance(0.01)
	print("AUTOMATIC TIMER PREVIEWS saved: ", ProjectSettings.globalize_path(folder))
	quit()
