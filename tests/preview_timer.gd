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
	screen.target_index = 1
	screen.confirm_target()
	for stage in 3:
		screen.advance(0.9)
		await capture(["jump", "morph", "aim"][stage])
		screen.timer_cast.press()
		if stage == 0:
			screen.advance(0.48)
		elif stage == 1:
			screen.advance(0.88)
	screen.advance(0.22)
	screen.advance(0.15)
	await capture("throw")
	screen.advance(0.24)
	screen.advance(0.5)
	await capture("planted")
	screen.advance(0.51)
	screen.advance(0.10)
	await capture("lightning")
	screen.advance(0.8)
	screen.advance(0.66)
	screen.hero_index = 0
	screen._next_hero()
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.select_command(3)
	screen.select_skill(0)
	screen.confirm_target()
	for i in 3:
		screen.timer_cast.press()
		if i == 0:
			screen.advance(0.48)
		elif i == 1:
			screen.advance(0.88)
	await capture("confused")
	screen.advance(0.56)
	screen.advance(0.25)
	await capture("fall")
	screen.advance(0.31)
	await capture("flat")
	print("TIMER PREVIEWS saved: ", ProjectSettings.globalize_path(folder))
	quit()
