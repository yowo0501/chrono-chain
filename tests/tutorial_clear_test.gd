extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 5:
		await process_frame

func run() -> void:
	var router: Node = root.get_node("StoryRouter")
	var tutorial: Node = root.get_node("Tutorial")
	var manager: Node = root.get_node("EncounterManager")
	for missing_symbol in [false, true]:
		router.open_scene(router.TUTORIAL)
		await settle()
		check(tutorial.active and tutorial.seen.has("move"), "New session starts onboarding")
		tutorial.active = false
		tutorial.enabled = false
		tutorial.view.hide()
		paused = false
		var field: Node2D = current_scene.get_node("Field")
		var player: Node2D = current_scene.get_node("Player")
		field.set_process(false)
		player.set_process(false)
		field.lit.fill(true)
		field._spawn_boss()
		player.warp_to(field.boss.grid_pos)
		field._engage(field.boss, player)
		manager._finish_battle(false)
		check(not field.boss_defeated and not tutorial.seen.has("clear"), "Boss defeat does not clear tutorial")
		await settle()
		player.warp_to(field.boss.grid_pos)
		field._engage(field.boss, player)
		check(manager.active and manager.encounter_context.boss, "Boss can be retried after defeat")
		manager.transition.set_process(false)
		manager._on_transition_covered()
		manager._on_transition_finished()
		var battle: Control = manager.screen
		battle.set_process(false)
		field.pending_contact = field.boss
		if missing_symbol:
			manager.encounter_symbol = null
		battle.enemies[0].hp = 0
		check(battle._check_end() and battle.won, "Zero boss HP resolves as victory")
		await settle()
		check(field.boss_defeated and field.boss.defeated and not field.boss.visible, "Victory marks field and boss defeated")
		check(field.pending_contact == null, "Victory clears queued contacts")
		check(not manager.active and tutorial.active and paused, "Victory automatically opens paused completion")
		check(tutorial.view.title == "튜토리얼 클리어" and tutorial.choices[0].label == "타이틀 화면으로 돌아가기", "Completion has title and return button")
		var count: int = manager.encounters
		field.grace = 0
		field.pending_contact = field.boss
		check(not field.check_contact(player), "Queued contact cannot reopen cleared battle")
		field.player_step_completed(player)
		field._engage(field.boss, player)
		manager.start_symbol_battle(player, field.boss, field, {"boss":true,"light":true})
		check(not manager.active and manager.encounters == count, "All encounter entry points reject cleared field")
		var wrong := InputEventKey.new()
		wrong.keycode = KEY_X
		wrong.pressed = true
		tutorial._input(wrong)
		check(tutorial.active, "Unrelated input leaves completion visible")
		tutorial.choose(0)
		await settle()
		check(current_scene.scene_file_path == router.MENU and not paused, "Button returns to actual title scene")
		check(not tutorial.enabled and not tutorial.active and tutorial.seen.is_empty() and not manager.active, "Returning resets onboarding and battle state")
	print("TUTORIAL CLEAR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
