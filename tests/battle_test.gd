extends SceneTree
const Rules = preload("res://scripts/battle/battle_rules.gd")
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Transition = preload("res://scripts/battle/encounter_transition.gd")
var checks := 0
var failures := 0
var manager: Node
var cover_events := 0
var finish_events := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func fixture() -> Control:
	manager.reset_party()
	var s := Screen.new()
	var random := RandomNumberGenerator.new()
	random.seed = 71
	# Fixed damage fixture for QTE rules; live two-hero balance is covered separately.
	var settings: Dictionary = manager.balance.duplicate(true)
	settings.monster_count = 2
	settings.monster.max_hp = 90
	settings.monster.attack = 16
	s.setup(manager.party.duplicate(true), settings, random)
	root.add_child(s)
	s.set_process(false)
	s.advance(1.1)
	return s

func run() -> void:
	manager = root.get_node("EncounterManager")
	var transition := Transition.new()
	root.add_child(transition)
	transition.set_process(false)
	transition.covered.connect(func(): cover_events += 1)
	transition.finished.connect(func(): finish_events += 1)
	transition.advance(0.5)
	check(transition.zoom_factor() > 1.5 and cover_events == 0, "zoom focuses on contact before battle")
	check(transition.close_progress() == 0.0, "diagonal slit stays open for one second")
	transition.advance(0.5)
	check(transition.close_progress() == 0.0 and cover_events == 0, "shutters start only after 1.0 seconds")
	transition.advance(0.15)
	check(is_equal_approx(transition.close_progress(), 0.5), "both shutters close halfway")
	check(cover_events == 0, "battle is not created through an open slit")
	transition.advance(0.151)
	check(cover_events == 1 and finish_events == 0, "battle created only at full black")
	transition.advance(0.5)
	transition.advance(5)
	check(cover_events == 1 and finish_events == 1, "transition signals fire once")
	transition.free()
	# Four midpoint crossings, two complete round trips, strict end deadline.
	for t in [0.4, 1.2, 2.0, 2.8]:
		check(Rules.grade(t, 3.2, true, 0.065) == "perfect", "perfect crossing %.1f" % t)
	for t in [0.0, 0.8, 1.6, 2.4, 3.2]:
		check(is_equal_approx(Rules.cursor_at(t, 3.2), 0.0 if t in [0.0, 1.6, 3.2] else 1.0), "turning point")
	check(Rules.grade(0.1, 3.2, true, 0.065) == "normal", "off-center input")
	check(Rules.grade(3.2, 3.2, true, 0.065) == "miss", "input at timeout loses")
	check(Rules.grade(0.4, 3.2, false, 0.065) == "miss", "no input misses even on center")
	check(Rules.attack_damage(24, "perfect") == 48, "double damage")
	check(Rules.attack_damage(24, "normal") == 24, "normal damage")
	check(Rules.attack_damage(24, "miss") == 0, "miss damage")
	check(Rules.defense_damage(16, "perfect") == {"received": 0, "reflected": 16}, "counter reflects full damage")
	check(Rules.defense_damage(16, "normal").received == 8, "half damage")
	check(Rules.defense_damage(16, "miss").received == 16, "guard timeout full damage")
	for i in range(1, 9):
		check(not manager.should_encounter(i, 0.0), "safe opening steps")
	check(manager.should_encounter(9, 0.01), "random encounter")
	check(not manager.should_encounter(9, 0.99), "chance can fail")
	check(manager.should_encounter(28, 0.99), "pity maximum")
	var s := fixture()
	check(s.textures[0].get_size() == Vector2(3072, 960), "High-resolution eight-pose base atlas")
	check(s.monster_texture.get_size() == Vector2(576, 176), "monster sheet twice original resolution")
	check(s.motion_textures[0].get_size() == Vector2(3072, 1920) and s.expressive_textures[1].get_size() == Vector2(3072, 1920), "32-frame animation atlases have matching cells")
	check(s.textures.size() == 2 and s.motion_textures[0].get_size() == Vector2(3072,1920), "Previous two-hero battle art restored")
	check(s.calm_idle_texture.get_size() == Vector2(2304, 960), "calm idle six-frame sheet loaded")
	check(s.motion_textures[1].get_size() == Screen.ANIMATION_CELL * 8, "refreshed windup poses share the regular foot anchor")
	check(s.idle_frame(0, 0.05) == s.idle_frame(0, 0.20), "idle support pose is held instead of rushing")
	check(s.idle_frame(0, 0.05) == s.idle_frame(0, Screen.CHUHEUN_IDLE_CYCLE + 0.05), "calm idle repeats after full 1.6 seconds")
	check(Screen.HERO_POS[0].x > Screen.HERO_POS[1].x and Screen.HERO_POS[0].y > Screen.HERO_POS[1].y, "Chuheun stands below Yeonwoo in the front column")
	check(s.foe_position(0).x - Screen.HERO_POS[0].x >= 190, "wide open center between teams")
	s.special_wait = 0.01
	s.advance(0.02)
	check(s.special_actor == 0, "Chuheun gets first special idle")
	s.advance(Screen.SPECIAL_DURATION + 0.01)
	check(s.special_actor == -1, "special finishes before partner starts")
	s.advance(6.1)
	check(s.special_actor == 1, "Yeonwoo gets next special idle")
	s.select_command(0)
	s.confirm_target()
	s.advance(0.01)
	check(s.special_actor == -1, "action interrupts idle special")
	s.phase = Screen.Phase.COMMAND
	s.action_kind = ""
	s.special_wait = 0.01
	s.advance(0.02)
	check(s.special_actor == 0, "two-hero alternation survives an interrupted special")
	s.special_actor = -1
	s.special_wait = 7
	for actor in 2:
		for target in 2:
			s.target_index = target
			var points: PackedVector2Array = s.chain_points(actor, 0.25)
			check(points.size() > 0 and points[-1].distance_to(s.foe_position(target) + Vector2(-24,-105)*Screen.ACTOR_SCALE) < 0.1, "chain reaches either target without moving actor")
			check(s.attack_anchor(actor) == Screen.HERO_POS[actor], "attack foot anchor stays planted")
	check(s.chain_points(0, 0.7).is_empty(), "chain extension removed during final recovery")
	s.target_index = 0
	check(s.phase == Screen.Phase.COMMAND and s.hero_index == 0, "first hero starts")
	s.select_command(0)
	s.confirm_target()
	s.qte_elapsed = Rules.position_marker(s.foe_position(s.target_index).y) * 0.8
	s._resolve_qte(true)
	check(s.enemies[0].hp == 42, "first attack applies critical")
	s._resolve_qte(true)
	check(s.enemies[0].hp == 42, "duplicate input does not double hit")
	s.advance(0.9)
	check(s.hero_index == 1 and s.phase == Screen.Phase.COMMAND, "second hero acts next")
	s.select_command(1)
	s.advance(0.6)
	s.advance(0.6)
	check(s.phase == Screen.Phase.ENEMY, "enemy turn follows two heroes")
	s.defending_index = 1
	s.advance(0.6)
	check(s.phase == Screen.Phase.GUARD_QTE, "guard opens QTE")
	s.qte_elapsed = Rules.position_marker(s.foe_position(s.enemy_index).y) * 0.8
	s._resolve_qte(true)
	check(s.party[1].hp == 100 and s.enemies[0].hp == 26, "counter no self damage")
	s.advance(0.9)
	s.defending_index = 1
	s.advance(0.6)
	s.qte_elapsed = 0.1
	s._resolve_qte(true)
	check(s.party[1].hp == 92, "guard persists for both monster actions")
	s.advance(0.9)
	check(s.round_number == 2 and not s.party[1].guarding, "new round resets guard")
	s.free()
	s = fixture()
	s.select_command(0)
	s.confirm_target()
	s.advance(3.3)
	check(s.enemies[0].hp == 90 and s.last_grade == "miss", "attack timeout no damage")
	s.free()
	s = fixture()
	s.party[0].hp = 0
	s._start_party_turn()
	check(s.hero_index == 1, "KO ally skipped")
	s.enemies[0].hp = 0
	s.select_command(0)
	check(s.target_index == 1, "KO enemy excluded from targets")
	s.enemies[1].hp = 1
	s.confirm_target()
	s.qte_elapsed = Rules.position_marker(s.foe_position(s.target_index).y) * 0.8
	s._resolve_qte(true)
	s.advance(0.9)
	check(s.phase == Screen.Phase.RESULT and s.won, "victory without enemy actions")
	s.free()
	s = fixture()
	s.party[0].hp = 0
	s.party[1].hp = 1
	s.defending_index = 1
	s._enemy_strike()
	s.advance(0.9)
	check(s.phase == Screen.Phase.RESULT and not s.won, "total party defeat resolves")
	s.free()
	s = fixture()
	s.enemies[1].hp = 0
	s.enemies[0].hp = 1
	s.party[0].guarding = true
	s.defending_index = 0
	s._enemy_strike()
	s.qte_elapsed = Rules.position_marker(s.foe_position(s.enemy_index).y) * 0.8
	s._resolve_qte(true)
	s.advance(0.9)
	check(s.phase == Screen.Phase.RESULT and s.won, "final enemy dies to counter")
	s.free()
	# Real field integration, with completed movement and blocked-wall behavior.
	s = fixture()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_ENTER
	s._input(event)
	check(s.phase == Screen.Phase.ATTACK_QTE, "Enter directly starts positional attack")
	event.physical_keycode = KEY_ESCAPE
	s._input(event)
	check(s.phase == Screen.Phase.ATTACK_QTE, "Committed attack cannot be cancelled")
	s.qte_elapsed = Rules.position_marker(s.foe_position(0).y) * 0.8
	event.physical_keycode = KEY_SPACE
	event.echo = true
	s._input(event)
	check(s.phase == Screen.Phase.ATTACK_QTE, "held-key repeat ignored")
	event.echo = false
	s._input(event)
	check(s.enemies[0].hp == 42, "fresh Space key resolves QTE")
	s.free()
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	main.get_node("Field").test_grid = true
	root.add_child(main)
	var player: Node2D = main.get_node("Player")
	manager.steps = 0
	await create_timer(0.2).timeout
	check(manager.steps == 0, "standing still never rolls an encounter")
	var prior: Vector2 = player.position
	player._move_to(player.grid_pos + Vector2i(1, 0))
	await create_timer(player.MOVE_TIME + 0.04).timeout
	check(manager.steps == 1, "one completed step counted once")
	check(not player.sprite.walking and not player.follower.walking, "party standing animation restored")
	player.position = Vector2(48, 16)
	player.grid_pos = Vector2i(3, 1)
	Input.action_press("ui_up")
	await create_timer(0.25).timeout
	Input.action_release("ui_up")
	check(manager.steps == 1, "blocked movement does not roll")
	player.position = prior
	player.grid_pos = Vector2i(10, 6)
	manager.steps = 27
	player._move_to(Vector2i(11, 6))
	await create_timer(player.MOVE_TIME + 0.04).timeout
	check(not manager.active and manager.steps == 28, "walking never starts a random encounter")
	manager.start_battle(player)
	check(manager.active and player.input_locked, "explicit encounter request locks field")
	check(manager.screen == null and is_instance_valid(manager.transition), "encounter starts on field transition")
	manager.transition.set_process(false)
	var encounter_count: int = manager.encounters
	manager.start_battle(player)
	check(manager.encounters == encounter_count, "transition blocks duplicate encounters")
	prior = player.position
	Input.action_press("ui_right")
	await create_timer(0.3).timeout
	Input.action_release("ui_right")
	check(player.position == prior and manager.steps == 0, "combat blocks field walking")
	manager.transition.advance(Transition.COVER_TIME + 0.01)
	check(is_instance_valid(manager.screen) and manager.screen.process_mode == Node.PROCESS_MODE_DISABLED, "battle exists behind full black with input locked")
	manager.transition.advance(Transition.BLACK_HOLD + Transition.REVEAL_DURATION)
	check(manager.transition == null and manager.screen.process_mode == Node.PROCESS_MODE_INHERIT, "battle activates after reveal")
	manager._finish_battle(true)
	await process_frame
	check(not manager.active and not player.input_locked and player.position == prior, "victory restores exact location")
	manager.start_battle(player)
	manager.party[0].hp = 0
	manager.party[1].hp = 0
	manager._finish_battle(false)
	await process_frame
	check(manager.party[0].hp == 120 and manager.party[1].hp == 100 and not player.input_locked, "defeat recovers party")
	main.free()
	print("BATTLE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
