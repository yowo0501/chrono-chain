extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var checks := 0
var failures := 0
var manager: Node
var field: Node2D
var player: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func opening(initiative: String, armored: bool = false) -> Control:
	manager.reset_party()
	var screen := Screen.new()
	var settings: Dictionary = manager.balance.duplicate(true)
	settings.monster_count = 1
	var random := RandomNumberGenerator.new()
	random.seed = 71
	screen.setup(manager.party.duplicate(true), settings, random, armored)
	screen.field_context = {"initiative": initiative}
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.01)
	return screen

func run() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	field = main.get_node("Field")
	player = main.get_node("Player")
	manager = root.get_node("EncounterManager")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000.0
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()
	var home := Vector2i(-1, -1)
	for y in range(5, field.height() - 5):
		for x in range(5, field.width() - 5):
			var tile := Vector2i(x, y)
			var clear: bool = field.is_lit(tile) and not field.is_blocked(tile)
			for direction in field.OFFSETS:
				for distance in range(1, 5):
					clear = clear and not field.is_blocked(tile + direction * distance) and field.is_lit(tile + direction * distance)
			if clear:
				home = tile
				break
		if home.x >= 0:
			break
	check(home.x >= 0, "Fixture has clear four-cell lanes in all eight directions")
	if home.x < 0:
		quit(1)
		return
	player.warp_to(home)
	player._move_to(home + Vector2i.RIGHT)
	player._advance_step(0.12)
	check(player._moving and player.position == Vector2(home * 16) + Vector2(8, 0), "Walk crosses half a tile in 0.12 s")
	player._advance_step(0.12)
	check(not player._moving, "Walk completes in 0.24 s")
	player.warp_to(home)
	Input.action_press("field_dash")
	player._move_to(home + Vector2i.RIGHT)
	check(player.sprite.dashing and player.follower.dashing, "Both heroes use the dash animation")
	player._advance_step(0.06)
	check(player._moving and player.position == Vector2(home * 16) + Vector2(8, 0), "Dash crosses half a tile in 0.06 s")
	player._advance_step(0.06)
	check(not player._moving and player.grid_pos == home + Vector2i.RIGHT, "Dash is exactly twice walking speed")
	check(player.follower_grid == home and not player.follower.dashing, "Follower commits one tile behind and returns to idle")
	Input.action_release("field_dash")
	player.warp_to(home)
	player._move_to(home + Vector2i.RIGHT)
	check(player.request_chain() and player.chain_queued and player.chain_elapsed < 0.0, "T buffers until the moving tile finishes")
	player._advance_step(0.24)
	check(not player._moving and player.chain_elapsed == 0.0 and not player.chain_queued, "Buffered chain starts on the tile boundary")
	player._advance_chain(1.0)
	check(is_equal_approx(player.chain_remaining(), 0.25), "Swing ends after 1 s, followed by 0.25 s recovery")
	check(not player.request_chain(), "Repeated T cannot cancel recovery")
	var stopped: Vector2i = player.grid_pos
	player._move_to(stopped + Vector2i.RIGHT)
	check(not player._moving, "Movement cannot bypass chain recovery")
	player._advance_chain(0.24)
	check(player.chain_remaining() > 0.0, "Recovery remains locked just before one second")
	player._advance_chain(0.01)
	check(player.chain_remaining() == 0.0 and player.request_chain(), "Chain is ready exactly after 1.25 seconds")
	player.reset_field_action()
	player.input_locked = true
	check(not player.request_chain(), "Locked field input cannot swing")
	player.input_locked = false
	player.warp_to(home)
	var symbol: Node2D = field._spawn_symbol(home + Vector2i.RIGHT * 4)
	for direction in player.DIR_VECTOR:
		player.facing = direction
		var offset: Vector2i = player.DIR_VECTOR[direction]
		var steps := 2 if offset.length_squared() == 2 else 4
		var reach := Vector2(offset * steps).length()
		symbol.place(home + offset * steps)
		check(field.chain_target(player, 4.0) == symbol, "Four-tile physical range in " + direction)
		check(field.chain_target(player, reach - 0.01) == null, "No hit beyond visible reach in " + direction)
		symbol.place(home + offset * (steps + 1))
		check(field.chain_target(player, 4.0) == null, "Next cell is out of range in " + direction)
		symbol.place(home - offset)
		check(field.chain_target(player, 4.0) == null, "No hit behind in " + direction)
	player.facing = "right"
	symbol.place(home + Vector2i(1, 1))
	check(field.chain_target(player, 4.0) == null, "Adjacent side lane is not hit")
	symbol.place(home + Vector2i.RIGHT * 4)
	var wall := home + Vector2i.RIGHT
	var old_row: String = field.tiles[wall.y]
	field.tiles[wall.y] = old_row.substr(0, wall.x) + "#" + old_row.substr(wall.x + 1)
	check(field.chain_target(player, 4.0) == null, "Chain cannot hit through a wall")
	field.tiles[wall.y] = old_row
	var area: int = field.area_at(symbol.grid_pos)
	field.lit[area] = false
	check(field.chain_target(player, 4.0) == null, "Invisible darkness symbols cannot be targeted")
	field.lit[area] = true
	symbol.start_step(home + Vector2i.RIGHT)
	check(field.contact_initiative(symbol, player) == "enemy", "Approaching enemy gains the first strike")
	symbol.place(home + Vector2i.RIGHT)
	symbol.start_step(home + Vector2i.RIGHT * 2)
	var results := {"party": 0, "enemy": 0}
	field.rng.seed = 824
	for i in 200:
		var result: String = field.contact_initiative(symbol, player)
		results[result] += 1
	check(results.party > 65 and results.enemy > 65, "Retreat contact can give either side the opening")
	symbol.place(home + Vector2i.RIGHT * 4)
	symbol.encounter_motion = "neutral"
	check(field.contact_initiative(symbol, player) == "normal", "Stationary contact keeps the normal opening")
	check(player.request_chain(), "Ready player begins the real chain action")
	var before: int = manager.encounters
	player._advance_chain(0.44)
	check(not manager.active, "Draw-back cannot deal an early hit")
	player._advance_chain(0.57)
	check(manager.active and manager.encounters == before + 1, "Even a slow frame hits a target crossed by the 1 s swing")
	check(manager.encounter_context.get("initiative") == "party", "Chain hit passes party initiative to the actual encounter")
	check(manager.screen == null and player.input_locked, "Transition locks input before creating battle")
	manager.transition.set_process(false)
	manager.transition.advance(1.15)
	check(manager.screen == null, "No battle screen before diagonal shutters fully close")
	manager.transition.advance(0.16)
	check(manager.screen != null and manager.screen.field_context.initiative == "party", "Covered transition creates battle with the correct initiative")
	manager.transition.advance(0.41)
	manager._finish_battle(true)
	check(not player.input_locked and player.chain_remaining() == 0.0 and not player.chain_queued, "Battle return clears field attack state")
	await process_frame
	# Collision while dashing must retain its first-contact initiative until tile arrival.
	player.warp_to(home)
	field.grace = 0.0
	symbol = field._spawn_symbol(home + Vector2i.RIGHT)
	symbol.start_step(home)
	symbol.encounter_motion = "approaching"
	player._move_to(home + Vector2i.RIGHT)
	player._advance_step(0.12)
	check(not field.check_contact(player) and field.pending_contact == symbol and player.input_locked, "Mid-step contact waits for a stable tile")
	check(field.pending_initiative == "enemy", "First-contact initiative is saved")
	player._advance_step(0.12)
	check(manager.active and manager.encounter_context.initiative == "enemy", "Deferred contact preserves enemy initiative")
	manager._finish_battle(true)
	await process_frame
	main.free()
	await process_frame
	var screen := opening("party")
	check(screen.phase == screen.Phase.COMMAND and screen.opening_party_bonus, "Party preemptive starts with playable commands")
	screen.hero_index = screen.party.size()
	screen._next_hero()
	check(not screen.opening_party_bonus and screen.phase != screen.Phase.ENEMY, "First enemy response is skipped once")
	screen.advance(0.81)
	check(screen.hero_index == 0 and screen.round_number == 1, "Normal first round follows the opening bonus")
	screen.hero_index = screen.party.size()
	screen._next_hero()
	check(screen.phase == screen.Phase.ENEMY, "Enemies act normally after the one-time advantage")
	screen.free()
	screen = opening("enemy", true)
	check(screen.phase == screen.Phase.ENEMY and screen.opening_enemy_bonus, "Enemy preemptive starts before party commands")
	screen.advance(0.81)
	check(screen.action_kind == "enemy_windup", "Opening attack is not skipped by the armored enemy interval")
	screen.enemy_index = screen.enemies.size()
	screen._enemy_action()
	check(screen.phase == screen.Phase.COMMAND and screen.round_number == 1 and not screen.opening_enemy_bonus, "Enemy opening returns to the ordinary first round")
	screen.free()
	screen = opening("normal")
	check(screen.phase == screen.Phase.COMMAND and not screen.opening_party_bonus and not screen.opening_enemy_bonus, "Existing neutral encounters keep their original flow")
	screen.free()
	print("FIELD GIMMICKS: %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
