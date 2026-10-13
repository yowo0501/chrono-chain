extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const TimerCast = preload("res://scripts/battle/timer_skill.gd")
const Assassin = preload("res://scripts/battle/assassin_skill.gd")
var screen: Control
var folder := "res://.godot/special-v2-preview/"

func _initialize() -> void:
	call_deferred("render")

func shot(label: String) -> void:
	screen.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + label + ".png")

func render() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	screen = Screen.new()
	screen.setup(manager.party.duplicate(true), manager.balance, RandomNumberGenerator.new(), true)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	screen.select_command(3)
	screen.select_skill(0)
	await shot("01-skills-insufficient")
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.select_skill(0)
	screen.confirm_target()
	await shot("02-jump-preparation")
	screen.timer_cast.stage = TimerCast.Stage.MORPH
	screen.timer_cast.elapsed = 0.6
	await shot("03-chain-morph")
	screen.phase = Screen.Phase.COMMAND
	screen.select_command(2)
	screen.focus_elapsed = 0.6
	await shot("04-focus")
	screen.hero_index = 1
	screen.phase = Screen.Phase.COMMAND
	screen.party[1].attack_stacks = 1
	screen.party[1].defense_stacks = 2
	screen.party[1].focus_stacks = 1
	screen.select_command(3)
	await shot("05-assassin-menu")
	screen.select_skill(0)
	screen.assassin_cast.stage = Assassin.Stage.CUTIN
	screen.assassin_cast.elapsed = 0.3
	await shot("06-eye-cutin")
	screen.assassin_cast.stage = Assassin.Stage.QTE
	screen.assassin_cast.elapsed = 0.9
	await shot("07-assassin-qte")
	screen.assassin_cast.stage = Assassin.Stage.EMBARRASSED
	screen.assassin_cast.elapsed = 0.8
	await shot("08-embarrassed")
	screen.assassin_cast.stage = Assassin.Stage.YAWN
	screen.assassin_cast.elapsed = 0.6
	await shot("09-yawn")
	quit()
