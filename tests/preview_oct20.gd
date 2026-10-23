extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Rules = preload("res://scripts/battle/battle_rules.gd")
var main: Node2D
var screen: Control

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func new_battle(dark: bool = false) -> void:
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	for hero in manager.party:
		for stack in ["attack_stacks","defense_stacks","focus_stacks"]:
			hero[stack] = 8
	var config: Dictionary = manager.balance.duplicate(true)
	config.monster.max_hp = 600
	var random := RandomNumberGenerator.new()
	random.seed = 20
	screen = Screen.new()
	screen.setup(manager.party,config,random)
	screen.field_context = {"light":not dark}
	root.add_child(screen)
	screen.set_process(false)
	screen.delay = 0
	screen.pending = Callable()
	screen.phase = Screen.Phase.COMMAND
	screen.enemy_positions.assign([Vector2(500,265),Vector2(650,345),Vector2(510,428)])

func run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	field.set_process(false)
	player.set_process(false)
	await capture("res://tests/preview-oct20-field.png")
	field.grace = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/oct20-walk"))
	var frame := 0
	for tile in [Vector2i(6,11),Vector2i(7,11),Vector2i(7,10),Vector2i(7,9),Vector2i(8,9),Vector2i(9,9),Vector2i(10,9),Vector2i(11,9)]:
		player._move_to(tile)
		for i in 6:
			player._advance_step(0.04001)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/oct20-walk/%04d.png" % frame)
			frame += 1
	camera.reparent(main)
	camera.position = Vector2(400,240)
	camera.zoom = Vector2(0.32,0.32)
	await capture("res://tests/preview-oct20-overview.png")
	field.hud.show_map = true
	await capture("res://tests/preview-oct20-map.png")
	main.free()
	await process_frame
	new_battle()
	screen.select_command(0)
	screen.qte_elapsed = 0.19
	screen.queue_redraw()
	await capture("res://tests/preview-oct20-position-qte.png")
	screen.field_context.light = false
	screen.queue_redraw()
	await capture("res://tests/preview-oct20-dark-qte.png")
	screen.reveal(1)
	screen.queue_redraw()
	await capture("res://tests/preview-oct20-fading-qte.png")
	screen.free()
	new_battle(true)
	screen.select_command(3)
	screen.select_skill(0)
	for i in 600:
		if screen.timer_cast.stage == screen.TimerSkill.Stage.LIGHTNING:
			break
		screen.advance(0.01)
	screen.advance(0.1)
	await capture("res://tests/preview-oct20-timer.png")
	screen.free()
	new_battle(true)
	screen.select_command(3)
	screen.select_skill(1)
	screen.advance(1.0)
	await capture("res://tests/preview-oct20-thunder.png")
	screen.free()
	for target in [0,1]:
		new_battle()
		screen.hero_index = 1
		screen.party[target].hp = 20
		screen.select_command(3)
		screen.select_skill(1)
		screen.target_index = target
		screen.confirm_target()
		screen.advance(0.8)
		await capture("res://tests/preview-oct20-heal-%d.png" % target)
		screen.advance(0.8)
		await capture("res://tests/preview-oct20-heal-finish-%d.png" % target)
		screen.free()
	new_battle()
	screen.hero_index = 1
	screen.select_command(3)
	screen.select_skill(0)
	for i in 100:
		if screen.assassin_cast.is_qte():
			break
		screen.advance(0.02)
	screen.assassin_cast.elapsed = 0.4
	screen.queue_redraw()
	await capture("res://tests/preview-oct20-assassin.png")
	screen.free()
	print("OCT20 PREVIEW: field, expanded map, light/dark/fading QTE, timer, thunder, two recovery branches and assassin")
	quit()
