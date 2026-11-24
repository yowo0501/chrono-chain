extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Assassin = preload("res://scripts/battle/assassin_skill.gd")
var manager: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REVISION FAIL: " + message)

func step(player: Node2D, tile: Vector2i) -> void:
	player._move_to(tile)
	player._advance_step(player.MOVE_TIME + 0.001)

func open_screen() -> void:
	manager.transition.set_process(false)
	manager._on_transition_covered()
	manager._on_transition_finished()
	manager.screen.set_process(false)

func battle_fixture(count: int) -> Control:
	manager.reset_party()
	var settings: Dictionary = manager.balance.duplicate(true)
	settings.monster_count = count
	settings.monster.max_hp = 2000
	settings.armored_monster.max_hp = 2000
	var screen := Screen.new()
	var random := RandomNumberGenerator.new()
	random.seed = 5
	screen.setup(manager.party.duplicate(true), settings, random, count == 1)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	return screen

func begin_assassin(screen: Control) -> void:
	screen.hero_index = 1
	var cost: Dictionary = screen.balance.special_skills.yeonwoo[0].cost
	for stack in ["attack", "defense", "focus"]:
		screen.party[1][stack + "_stacks"] = int(cost.get(stack, 0))
	screen._begin_assassin(screen.balance.special_skills.yeonwoo[0])
	screen.advance(0.65)
	screen.advance(0.24)

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	manager = root.get_node("EncounterManager")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	for symbol in field.symbols:
		symbol.defeated = true
		symbol.visible = false
	# Repeated random darkness fights do not consume hidden field symbols.
	player.warp_to(Vector2i(31,10))
	field.grace = 0
	field.settings.dark_encounter.chance_per_step = 0.0
	field.settings.dark_encounter.maximum_steps = 4
	for cycle in 2:
		for i in 3:
			field.player_step_completed(player)
			check(not manager.active, "No guaranteed fight just for entering darkness")
		field.player_step_completed(player)
		check(manager.active and manager.encounter_symbol == null,"Darkness independently starts a repeatable battle")
		check(manager.encounter_context.random_darkness,"Dark encounter context is retained")
		var rolled: int = manager.encounter_balance.monster_count
		open_screen()
		check(manager.screen.enemies.size() == rolled,"Count rolled only once through transition")
		manager._finish_battle(cycle == 0)
		await process_frame
		check(field.defeated_count == 0,"Ambient result never changes symbol progress")
		if cycle == 0:
			field.grace = 0
	check(player.grid_pos == field.start_tile(),"Ambient defeat safely returns to entrance")
	# The actual remaining lamps control both light and dark encounters.
	manager.rng.seed = 101
	for remaining in [4,3,2,1,0]:
		field.lit.fill(true)
		for area in remaining:
			field.lit[area+5] = false
		var lower := 3 if remaining <= 2 else 2
		for light in [true,false]:
			var seen := {}
			for trial in 40:
				manager.start_symbol_battle(player,null,field,{"boss":false,"light":light,"dark_lamps":99})
				var rolled: int = manager.encounter_balance.monster_count
				check(manager.encounter_context.dark_lamps == remaining,"Count uses live field progress")
				check(rolled >= lower and rolled <= lower+2, "Enemy count follows remaining lamps")
				seen[rolled] = true
				manager._finish_battle(true)
				await process_frame
			check(seen.size() == 3, "All three allowed group sizes occur")
		for requested in [-1,99]:
			var config: Dictionary = manager.balance_for_context({"boss":false,"light":true,"dark_lamps":remaining,"enemy_count":requested},field.settings)
			check(config.monster_count == (lower if requested < 0 else lower+2),"Explicit counts obey progress limits")
	manager.start_symbol_battle(player,null,field,{"boss":true,"light":false,"dark_lamps":3})
	check(manager.encounter_balance.monster_count == 1, "Boss remains a single enemy")
	manager._finish_battle(true)
	await process_frame
	main.queue_free()
	await process_frame
	# All sixteen success/failure combinations for one, two, three and four foes.
	for count in range(1,5):
		for pattern in 16:
			var screen := battle_fixture(count)
			begin_assassin(screen)
			check(screen.assassin_cast.targets.size() == 4, "Always four attempts")
			var expected := {}
			for hit in 4:
				check(screen.position_hit(0.0) < 0, "Empty timing position misses")
				check(screen.assassin_cast.is_qte(), "Each attempt opens a QTE")
				if pattern & (1 << hit):
					screen.assassin_cast.elapsed = screen.Rules.position_marker(screen.foe_position(hit % count).y) * float(screen.balance.assassin.qte_duration)
					expected[hit % count] = int(expected.get(hit % count,0))+1
					screen.assassin_cast.press()
				else:
					screen.advance(float(screen.balance.assassin.qte_duration)+0.01)
				check(screen.assassin_cast.results.size() == hit+1, "Success or timeout resolves once")
				screen.assassin_cast.press()
				check(screen.assassin_cast.results.size() == hit+1, "Extra press during mark cannot duplicate hit")
				for enemy in screen.enemies:
					check(enemy.hp == 2000, "No damage during QTE")
				screen.advance(0.28)
			check(screen.assassin_cast.stage == Assassin.Stage.RETURN, "Fourth attempt closes QTE sequence")
			screen.advance(0.28)
			check(screen.assassin_cast.stage == (Assassin.Stage.EMBARRASSED if pattern == 0 else Assassin.Stage.YAWN), "Miss / return presentation preserved")
			if pattern != 0:
				screen.advance(1.0)
				for index in count:
					check(screen.enemies[index].hp == 2000 - 168*int(expected.get(index,0)), "Each successful allocated strike adds damage")
				screen.advance(0.91)
			else:
				screen.advance(1.61)
			screen.advance(0.31)
			check(screen.assassin_cast.stage == Assassin.Stage.DONE, "Cast completes after exactly four attempts")
			check(screen.party[1].attack_stacks == 0 and screen.party[1].defense_stacks == 0 and screen.party[1].focus_stacks == 0, "Cost paid once even on failure")
			screen.free()
	# A timed strike cannot hit a dead foe, even with gaps in living indices.
	var screen := battle_fixture(4)
	screen.enemies[1].hp = 0
	screen.enemies[3].hp = 0
	begin_assassin(screen)
	screen.assassin_cast.elapsed = screen.Rules.position_marker(screen.foe_position(1).y)*float(screen.balance.assassin.qte_duration)
	screen.assassin_cast.press()
	check(screen.assassin_cast.marked.is_empty(),"Dead foe positions cannot receive marks")
	screen.free()
	# Positional input reaches the fourth slot, including in darkness.
	for dark in [false,true]:
		screen = battle_fixture(4)
		screen.field_context = {"light":not dark}
		screen.select_command(0)
		screen.qte_elapsed = screen.Rules.position_marker(screen.foe_position(3).y)*0.8
		screen._resolve_qte(true)
		check(screen.enemies[3].hp == 1952,"Fourth foe can be hit at its actual vertical position")
		screen.free()
	print("ENCOUNTER REVISION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
