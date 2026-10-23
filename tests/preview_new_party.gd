extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var screen: Control

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/preview-party-"+name+".png")

func run() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.get_node("Field").set_process(false)
	main.get_node("Player").set_process(false)
	await capture("field")
	main.free()
	await process_frame
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	for hero in manager.party:
		hero.attack_stacks = 3
		hero.defense_stacks = 3
		hero.focus_stacks = 3
	var config: Dictionary = manager.balance.duplicate(true)
	config.monster_count = 5
	var random := RandomNumberGenerator.new()
	random.seed = 21
	screen = Screen.new()
	screen.setup(manager.party,config,random)
	root.add_child(screen)
	screen.set_process(false)
	screen.delay = 0
	screen.pending = Callable()
	screen.phase = Screen.Phase.COMMAND
	await capture("battle")
	screen.hero_index = 2
	screen.phase = Screen.Phase.SKILLS
	await capture("skills")
	screen.party[2].guarding = true
	screen.phase = Screen.Phase.COMMAND
	screen.queue_redraw()
	await capture("normal-guard")
	screen.party[2].guarding = false
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	for sample in [[0.3,"shield-step"],[1.65,"shield-transform"],[2.8,"shield-lift"],[3.1,"shield-impact"],[3.6,"shield"]]:
		screen.support_cast.advance(float(sample[0])-screen.support_cast.elapsed)
		screen.queue_redraw()
		await capture(str(sample[1]))
	screen.support_cast.advance(0.3)
	screen.queue_redraw()
	await capture("shield-hold")
	screen.party[2].shield_turns = 0
	screen._begin_shield_return()
	for sample in [[0.4,"shield-revert"],[1.0,"shield-startled"],[1.8,"shield-run"]]:
		screen.support_cast.advance(float(sample[0])-screen.support_cast.elapsed)
		screen.queue_redraw()
		await capture(str(sample[1]))
	screen.support_cast.advance(0.5)
	screen.queue_redraw()
	await capture("shield-returned")
	screen.party[2].shield_turns = 0
	screen.party[2].guarding = false
	screen.hero_index = 2
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(1)
	screen.support_cast.advance(3.1)
	screen.queue_redraw()
	await capture("swing-windup")
	screen.qte_elapsed = Screen.Rules.position_marker(screen.foe_position(0).y)*float(screen.balance.qte.duration)/4.0
	screen._resolve_qte(true)
	screen.advance(0.71)
	screen.queue_redraw()
	await capture("swing-impact")
	screen.hero_index = 3
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	screen.support_cast.advance(1.3)
	screen.queue_redraw()
	await capture("illuminate")
	screen.hero_index = 3
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(1)
	screen._advance_bind(1.01)
	screen.field_context = {"light":false}
	screen.reveal_remaining = 0
	screen.queue_redraw()
	await capture("bind-qte")
	for index in 3:
		screen.bind_elapsed = Screen.Rules.position_marker(screen.foe_position(index).y)*screen._bind_duration()/4.0
		screen._press_bind()
	screen._advance_bind(screen._bind_duration())
	screen._advance_bind(0.81)
	screen.field_context = {"light":true}
	screen.queue_redraw()
	await capture("bind-chains")
	screen.hero_index = 1
	screen.heading = "김연우 / 회복"
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(1)
	screen.queue_redraw()
	await capture("heal-menu")
	screen.free()
	quit()
