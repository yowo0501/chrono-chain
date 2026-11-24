extends SceneTree
const STACKS := ["attack_stacks", "defense_stacks", "focus_stacks"]
var manager: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func open_battle(player: Node2D) -> void:
	manager.start_battle(player)
	manager.transition.set_process(false)
	manager._on_transition_covered()
	manager._on_transition_finished()
	manager.screen.set_process(false)

func run() -> void:
	manager = root.get_node("EncounterManager")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	main.get_node("Field").test_grid = true
	root.add_child(main)
	await process_frame
	var player: Node2D = main.get_node("Player")
	player.set_process(false)
	for won in [true, false]:
		manager.reset_party()
		open_battle(player)
		var screen: Control = manager.screen
		for i in 2:
			for j in STACKS.size():
				screen.party[i][STACKS[j]] = 3
		# Actual skill payment leaves different balances for both heroes.
		screen.hero_index = 0
		screen._pay_skill(screen.balance.special_skills.chuheun[0])
		screen.hero_index = 1
		screen._pay_skill(screen.balance.special_skills.yeonwoo[0])
		var expected := [[1,3,1], [2,1,2]]
		for i in 2:
			screen.party[i].hp = 1 if won else 0
			screen.party[i].guarding = true
		screen.battle_finished.emit(won)
		await process_frame
		check(not manager.active and not player.input_locked, "Battle returns field control")
		for i in 2:
			for j in STACKS.size():
				check(manager.party[i][STACKS[j]] == expected[i][j], "Remaining stacks survive outcome " + str(won))
			check(manager.party[i].hp == manager.party[i].max_hp, "HP recovery remains intact")
			check(not manager.party[i].guarding, "Temporary guarding is cleared")
		open_battle(player)
		for i in 2:
			for j in STACKS.size():
				check(manager.screen.party[i][STACKS[j]] == expected[i][j], "Next battle inherits unspent stacks")
		manager.screen.hero_index = 1
		check(not manager.screen.can_use_skill(manager.balance.special_skills.yeonwoo[0]), "Carried cost is preserved; one missing defense stack blocks repeat cast")
		manager._finish_battle(true)
		await process_frame
	manager.reset_party()
	for hero in manager.party:
		for stack in STACKS:
			check(hero[stack] == 0, "New game reset still starts at zero")
	main.free()
	print("STACK CARRYOVER: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
