extends SceneTree
var failures := 0
var checks := 0
var tutorial: Node
var manager: Node

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	tutorial._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	tutorial = root.get_node("Tutorial")
	manager = root.get_node("EncounterManager")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	check(tutorial.active and paused, "Startup pauses the scene")
	var grace_before: float = tutorial.field.grace
	await process_frame
	await process_frame
	check(tutorial.field.grace == grace_before, "Field simulation stays frozen")
	key(KEY_ESCAPE)
	check(tutorial.active and not tutorial.seen.has("light"), "Wrong key cannot dismiss")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	tutorial._input(click)
	check(not tutorial.seen.has("light"), "Outside click cannot dismiss")
	key(KEY_RIGHT)
	check(tutorial.seen.has("light") and paused, "Arrow opens light objective")
	key(KEY_ENTER)
	check(not paused, "Acknowledgement resumes")
	var battle: Control = load("res://scripts/battle/battle_screen.gd").new()
	battle.setup(manager.party,manager.balance,manager.rng)
	root.add_child(battle)
	battle.set_process(false)
	battle.advance(1.1)
	manager.active = true
	manager.screen = battle
	tutorial._process(0)
	check(tutorial.seen.has("commands") and paused, "First command tutorial")
	key(KEY_DOWN)
	key(KEY_ENTER)
	check(tutorial.seen.has("command_1") and battle.phase == battle.Phase.COMMAND, "Guard selection opens detail before action")
	key(KEY_ENTER)
	check(battle.party[0].guarding and not paused, "Guard detail executes action once")
	battle.phase = battle.Phase.COMMAND
	battle.select_command(0)
	check(tutorial.active and battle.phase == battle.Phase.COMMAND, "Attack detail waits")
	key(KEY_ENTER)
	check(battle.phase == battle.Phase.ATTACK_QTE and battle.qte_elapsed == 0, "Attack starts at zero after explanation")
	battle.phase = battle.Phase.COMMAND
	battle.round_number = 2
	tutorial._process(0)
	var before: float = battle.clock
	await process_frame
	await process_frame
	check(tutorial.seen.has("resources") and paused and battle.clock == before, "Round two pauses timers")
	var focus_before: int = battle.party[0].focus_stacks
	key(KEY_ENTER)
	check(not paused and battle.phase == battle.Phase.COMMAND and battle.party[0].focus_stacks == focus_before, "Resource acknowledgement does not spend an action or force focus")
	battle.select_command(0)
	check(battle.phase == battle.Phase.ATTACK_QTE and not tutorial.active, "Attack remains available after resource tutorial")
	battle.phase = battle.Phase.COMMAND
	battle.select_command(1)
	check(battle.phase == battle.Phase.RESOLVE and not tutorial.active, "Guard remains available after resource tutorial")
	battle.phase = battle.Phase.COMMAND
	battle.select_command(2)
	check(tutorial.seen.has("command_2"), "Voluntarily selected focus gets its explanation")
	key(KEY_ENTER)
	battle.phase = battle.Phase.COMMAND
	battle.select_command(3)
	key(KEY_ENTER)
	check(battle.phase == battle.Phase.SKILLS, "Special explanation opens skills")
	manager.active = false
	manager.screen = null
	tutorial.battle_ended({"light":true})
	check(tutorial.seen.has("after_first") and paused, "First return points to darkness")
	key(KEY_ENTER)
	var dark_area: int = tutorial.field.lit.find(false)
	tutorial.field.walker().warp_to(tutorial.field.area_cells[dark_area][0])
	tutorial._process(0)
	check(tutorial.seen.has("dark_area") and paused and not tutorial.seen.has("dark_battle"), "Entering darkness does not consume battle tutorial")
	check(not tutorial.view.body.contains("판정선"), "Dark area entry only explains random encounters")
	key(KEY_ENTER)
	manager.active = true
	manager.screen = battle
	battle.phase = battle.Phase.COMMAND
	battle.field_context = {"light":false}
	tutorial._process(0)
	check(tutorial.seen.has("dark_battle") and paused and tutorial.view.body.contains("판정선"), "First dark battle explains hidden markers even after area tutorial")
	key(KEY_ENTER)
	tutorial._process(0)
	check(not tutorial.active, "Hidden marker tutorial does not repeat")
	manager.active = false
	manager.screen = null
	tutorial.battle_ended({"light":false})
	tutorial._process(0)
	check(tutorial.seen.has("lamps") and paused, "Night return introduces lamps")
	key(KEY_ENTER)
	check(tutorial.active, "Map instruction requires M")
	key(KEY_M)
	check(tutorial.field.hud.show_map and not paused, "M opens map")
	tutorial.field.hud.show_map = false
	var edges: Array[Vector2i] = tutorial.field.object_edges(tutorial.field.lamps[dark_area])
	tutorial.field.walker().warp_to(edges[0])
	tutorial._process(0)
	check(tutorial.seen.has("lamp_use") and paused, "Adjacent dark lamp highlights E")
	key(KEY_E)
	check(tutorial.field.lit[dark_area] and not paused, "Highlighted E actually lights lamp")
	tutorial.field.boss_spawned = true
	tutorial._process(0)
	check(tutorial.seen.has("boss") and paused, "Boss announcement")
	key(KEY_M)
	tutorial._process(0)
	check(not tutorial.active, "Boss announcement does not repeat")
	tutorial.enabled = false
	battle.free()
	main.free()
	print("Tutorial: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
