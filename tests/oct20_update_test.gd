extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Rules = preload("res://scripts/battle/battle_rules.gd")
var manager: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func battle(dark: bool = false, boss: bool = false) -> Control:
	var screen := Screen.new()
	var config: Dictionary = manager.balance.duplicate(true)
	config.monster_count = 1 if boss else 3
	config.monster.max_hp = 2000
	config.armored_monster.max_hp = 2000
	var heroes: Array = config.heroes.duplicate(true)
	for hero in heroes:
		hero.hp = hero.max_hp
		for stack in ["attack_stacks","defense_stacks","focus_stacks"]:
			hero[stack] = 3
	var random := RandomNumberGenerator.new()
	random.seed = 20
	screen.setup(heroes, config, random, boss)
	screen.field_context = {"light":not dark,"boss":boss}
	root.add_child(screen)
	screen.set_process(false)
	screen.delay = 0
	screen.pending = Callable()
	screen.phase = Screen.Phase.COMMAND
	return screen

func run_cast(screen: Control) -> void:
	for i in 1600:
		if screen.phase not in [Screen.Phase.TIMER,Screen.Phase.SUPPORT,Screen.Phase.ASSASSIN]:
			break
		screen.advance(0.01)
	check(screen.phase not in [Screen.Phase.TIMER,Screen.Phase.SUPPORT,Screen.Phase.ASSASSIN],"Automatic cast completes without input")

func run() -> void:
	manager = root.get_node("EncounterManager")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	check(field.width() == 128 and field.height() == 64,"Expanded night city dimensions")
	check(field.lamps.size() == 16 and field.symbols.size() == 5,"Sixteen lamp districts and five initial symbols")
	for anchor in field.lamps:
		var edges: Array[Vector2i] = field.object_edges(anchor)
		check(not edges.is_empty(),"Expanded object has an interaction perimeter")
		check(player.grid_pos in edges or not field.path_to(player.grid_pos,edges).is_empty(),"Expanded object reachable from entrance")
	for actor in [player.sprite,player.follower] + field.symbols:
		check(actor.texture.get_size() == (Vector2(192,256) if actor in [player.sprite,player.follower] else Vector2(192,256)),"Each actor uses its matching atlas layout")
	var start: Vector2 = player.position
	player._move_to(player.grid_pos+Vector2i.RIGHT)
	player._advance_step(player.MOVE_TIME/2.0)
	check(player.position.is_equal_approx(start+Vector2(8,0)),"Pure 2D map retains continuous half-step motion")
	player._advance_step(player.MOVE_TIME/2.0)
	check(player.sprite.frame_rect(Rect2()).size == Vector2(16,16),"Compact hero keeps its original fixed field size")
	# Repeated dark encounters are independent of the five persistent symbols.
	player.warp_to(Vector2i(31,10))
	field.grace = 0
	field.settings.dark_encounter.chance_per_step = 0.0
	field.settings.dark_encounter.maximum_steps = 4
	for cycle in 2:
		for step_index in 3:
			field.player_step_completed(player)
			check(not manager.active,"Dark entry itself does not guarantee a battle")
		field.player_step_completed(player)
		check(manager.active and manager.encounter_symbol == null,"Dark step cap triggers a repeatable ambient battle")
		check(int(manager.encounter_context.enemy_count) in [2,3,4],"Early random dark encounter has two to four enemies")
		manager._finish_battle(true)
		field.grace = 0
		check(field.defeated_count == 0,"Ambient victory never consumes symbol progress")
	check(field.repair_lamp(6,player),"Expanded lamp repair works")
	check(field.is_lit(player.grid_pos),"Lamp repair restores 2D district visibility")
	for symbol in field.symbols:
		symbol.place(Vector2i(7,7))
	for i in 20:
		field.player_step_completed(player)
	check(not manager.active,"Restored light stops random encounters")
	var bright: Dictionary = manager.balance_for_context({"boss":false,"light":true},field.settings)
	var dark: Dictionary = manager.balance_for_context({"boss":false,"light":false},field.settings)
	check(float(dark.monster.max_hp)/bright.monster.max_hp < 1.1,"Light/dark enemy stats are close")
	main.free()
	await process_frame
	# Position markers, including clustered lower foes, use actual Y rather than indices.
	var screen := battle()
	screen.enemy_positions.assign([Vector2(500,280),Vector2(650,360),Vector2(510,420)])
	for index in 3:
		screen.hero_index = 0
		screen.phase = Screen.Phase.COMMAND
		screen.select_command(0)
		check(screen.phase == Screen.Phase.ATTACK_QTE,"Attack begins positional QTE without target menu")
		var hp: int = screen.enemies[index].hp
		var marker := Rules.position_marker(screen.foe_position(index).y)
		screen.qte_elapsed = marker * float(screen.balance.qte.duration) / (2 * int(screen.balance.qte.round_trips))
		screen._resolve_qte(true)
		check(screen.target_index == index and screen.enemies[index].hp < hp,"Timing hits corresponding vertical-position foe")
	screen.phase = Screen.Phase.COMMAND
	screen.select_command(0)
	screen.qte_elapsed = 0
	screen._resolve_qte(true)
	check(screen.last_grade == "miss","Press outside every position window misses")
	screen.free()
	# Timer no longer owns a QTE, attacks all enemies, and reveals for ten seconds.
	screen = battle(true)
	screen.select_command(3)
	screen.select_skill(0)
	check(screen.phase == Screen.Phase.TIMER,"Timer starts directly with no target selection")
	check(screen.party[0].attack_stacks == 1 and screen.party[0].focus_stacks == 1,"Timer pays exactly its stated cost")
	for i in 1600:
		if screen.phase != Screen.Phase.TIMER:
			break
		check(not screen.timer_cast.is_qte(),"No timer QTE at any stage")
		screen.timer_cast.press()
		screen.advance(0.01)
	for enemy in screen.enemies:
		check(enemy.hp == 1880,"Timer deals one 5x attack area hit to every foe")
	check(screen.reveal_remaining > 18 and screen.reveal_remaining <= 20,"Timer reveal starts on lightning impact")
	screen.free()
	# Reveal clock runs in menus and QTE and fades in its final two seconds.
	screen = battle(true)
	check(screen.visibility_strength() == 0,"Dark enemies and hit markers initially hidden")
	screen.reveal(10)
	screen.advance(8.5)
	check(is_equal_approx(screen.visibility_strength(),0.75),"Reveal and marker opacity fade continuously")
	screen.phase = Screen.Phase.ATTACK_QTE
	screen.advance(1.5)
	check(screen.visibility_strength() == 0,"Darkness returns after real elapsed reveal time")
	screen.free()
	screen = battle(true)
	screen.select_command(3)
	screen.select_skill(1)
	run_cast(screen)
	for enemy in screen.enemies:
		check(enemy.hp == 1964,"Small thunder is a 1.5x whole-field attack")
	check(screen.reveal_remaining > 9 and screen.reveal_remaining <= 10,"Small thunder grants ten-second reveal")
	check(screen.party[0].focus_stacks == 2,"Thunder costs one focus")
	screen.free()
	# Both recovery branches, cancel, full-health refusal, and capped healing.
	for target in [0,1]:
		screen = battle()
		screen.hero_index = 1
		screen.party[target].hp = 1
		screen.select_command(3)
		screen.select_skill(1)
		check(screen.phase == Screen.Phase.TARGET,"Recovery opens ally selection")
		screen._cancel_target()
		check(screen.party[1].defense_stacks == 3,"Cancel never pays recovery cost")
		screen.select_skill(1)
		screen.target_index = target
		screen.confirm_target()
		run_cast(screen)
		check(screen.party[target].hp == 1+ceili(screen.party[target].max_hp*0.4),"Selected ally receives the recovery")
		check(screen.party[1].defense_stacks == 2,"Recovery costs one defense")
		screen.free()
	screen = battle()
	screen.hero_index = 1
	screen.select_command(3)
	screen.select_skill(1)
	screen.confirm_target()
	check(screen.phase == Screen.Phase.TARGET and screen.party[1].defense_stacks == 3,"Full-health target does not consume a stack")
	screen.party[1].hp -= 1
	screen.confirm_target()
	run_cast(screen)
	check(screen.party[1].hp == screen.party[1].max_hp,"Healing never exceeds maximum HP")
	screen.free()
	# All four assassin inputs select by location, including repeated boss hits.
	for boss in [false,true]:
		screen = battle(false,boss)
		screen.hero_index = 1
		screen.select_command(3)
		screen.select_skill(0)
		var count := 0
		for frame in 2500:
			if screen.phase != Screen.Phase.ASSASSIN:
				break
			if screen.assassin_cast.is_qte():
				var chosen := 0 if boss else count % 3
				screen.assassin_cast.elapsed = Rules.position_marker(screen.foe_position(chosen).y)*float(screen.balance.assassin.qte_duration)
				screen.assassin_cast.press()
				count += 1
				check(screen.enemies[chosen].hp == 2000,"Assassin marks defer damage until return/yawn")
			screen.advance(0.01)
		check(count == 4 and screen.assassin_cast.marked.size() == 4,"Assassin always has exactly four positional inputs")
		check(screen.enemies[0].hp == 2000-168*(4 if boss else 2),"Repeated positional marks accumulate correctly")
		screen.free()
	# Boss starts lit, switches at half HP, relocates, and remains revealable.
	screen = battle(false,true)
	check(not screen.darkness_active(),"Boss battle starts in light")
	screen.enemies[0].hp = 1000
	screen.advance(0.01)
	check(screen.darkness_active(),"Boss enters darkness at half HP")
	var previous: Vector2 = screen.foe_position(0)
	screen.round_number = 2
	screen._enemy_action()
	check(screen.foe_position(0).y != previous.y,"Boss relocation changes attack timing")
	screen.reveal(5)
	screen.advance(0.1)
	check(screen.visibility_strength() == 1,"Revealing a dark-phase boss is not immediately reset")
	screen.free()
	print("OCTOBER 20 UPDATE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
