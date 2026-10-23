extends SceneTree
var field: Node2D
var player: Node2D
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

func tick(seconds: float) -> void:
	for i in ceili(seconds/0.1):
		field._process(0.1)

func clear_symbols() -> void:
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()

func run() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	field = main.get_node("Field")
	# Legacy destruction remains testable, but is disabled in the shipped prototype.
	field.settings.lamp_break_enabled = true
	player = main.get_node("Player")
	manager = root.get_node("EncounterManager")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000
	check(field.width() == 128 and field.height() == 64,"128 by 64 field")
	check(field.lamps.size() == 16 and field.dark_count() == 8,"Sixteen districts, eight begin dark")
	check(field.symbols.size() == 5,"Five initial symbols")
	check(field.is_lit(field.start_tile()),"Entrance is lit")
	check(field.lit[0] and field.lit[1] and field.lit[2],"Plaza, bakery, shopping street begin lit")
	check(not field.lit[5] and not field.lit[9],"Alleys and vacant lot begin dark")
	for actor in [player.sprite,player.follower]+field.symbols:
		check(actor.texture.get_size() == Vector2(192,256),"64px fixed actor frames")
		check(actor.frame_rect(Rect2()).size == Vector2(16,16),"Actors fit one logical tile")
	clear_symbols()
	var seen := {player.grid_pos:true}
	var frontier: Array[Vector2i] = [player.grid_pos]
	var index := 0
	while index < frontier.size():
		var tile := frontier[index]
		index += 1
		for offset in field.OFFSETS:
			var next: Vector2i = tile+offset
			if not field.is_blocked(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			if not field.is_blocked(tile):
				check(seen.has(tile),"Every walkable cell is reachable")
	for area in field.lamps.size():
		check(field.area_at(field.lamps[area]) == area,"Lamp belongs to its district")
		var goals: Array[Vector2i] = field.object_edges(field.lamps[area])
		check(goals.has(field.start_tile()) or not field.path_to(field.start_tile(),goals).is_empty(),"Every lamp is reachable")
		check(not field.adjacent_areas(area).is_empty(),"Every district connects to another")
		var connected := {}
		var region_frontier: Array[Vector2i] = goals.filter(func(p: Vector2i) -> bool: return field.area_at(p)==area)
		for point in region_frontier:
			connected[point] = true
		index = 0
		while index < region_frontier.size():
			var tile := region_frontier[index]
			index += 1
			for offset in field.OFFSETS:
				var next: Vector2i = tile+offset
				if not field.is_blocked(next) and field.area_at(next)==area and not connected.has(next):
					connected[next] = true
					region_frontier.append(next)
		check(connected.size() == field.area_cells[area].size(),"Each district's walkable area is contiguous")
	# Real dark-origin raider travels continuously to a lit district and breaks a lamp.
	var origin: Array = field.settings.areas[6].spawn
	var enemy: Node2D = field._spawn_symbol(Vector2i(origin[0],origin[1]))
	for i in field.spawn_clocks.size():
		field.spawn_clocks[i] = 10000
	var original: Vector2i = enemy.grid_pos
	field._decide(enemy,player)
	check(enemy.moving,"Dark symbol actively migrates")
	var pixel_start: Vector2 = enemy.position
	enemy.advance(0.15,0.30)
	check(enemy.position == pixel_start.lerp(Vector2(enemy.target*16),0.5).round(),"Symbol crosses intermediate pixels")
	enemy.advance(0.15,0.30)
	var initial_dark: int = field.dark_count()
	for i in 1800:
		field._process(0.1)
		if field.dark_count() > initial_dark:
			break
	check(field.dark_count() == initial_dark+1,"Migrating enemy extinguishes a light district")
	check(enemy.grid_pos != original,"Dark spawn never stays dormant")
	check(not field.is_lit(enemy.grid_pos),"Attacked district becomes dark")
	var broken: int = field.area_at(enemy.grid_pos)
	check(field.spawn_clocks[broken] > 0,"New darkness starts its own spawn clock")
	clear_symbols()
	# Continuous siege, player interruption, and escaping into another district.
	field.repair_lamp(1,player)
	var lamp_edge: Vector2i = field.object_edges(field.lamps[1])[0]
	enemy = field._spawn_symbol(lamp_edge)
	tick(8.0)
	check(field.lit[1] and enemy.siege_time > 7,"Lamp survives before the nine-second threshold")
	player.warp_to(Vector2i(18,25))
	tick(0.1)
	check(enemy.siege_time == 0 and enemy.siege_area == -1,"Player arrival interrupts siege")
	for i in 1200:
		field._process(0.1)
		if field.area_at(enemy.grid_pos) != 1:
			break
	check(field.area_at(enemy.grid_pos) != 1,"Enemy escapes to a different area")
	check(field.lit[1],"Interrupted lamp remains lit")
	player.warp_to(field.start_tile())
	enemy.place(lamp_edge)
	enemy.route.clear()
	tick(9.2)
	check(not field.lit[1],"Uninterrupted attachment breaks lamp")
	manager.party[0].hp = 1
	check(field.repair_lamp(1,player),"Repair succeeds even at one HP")
	check(manager.party[0].hp == 1,"Repair never spends HP")
	check(not field.repair_lamp(1,player) and manager.party[0].hp == 1,"Already lit lamp has no side effect")
	clear_symbols()
	# Per-dark-area generation, bounded active population, and battle pause.
	for i in field.spawn_clocks.size():
		field.spawn_clocks[i] = 0
	field._tick_spawns(0.1,player)
	check(field.symbols.size() == field.dark_count(),"Each dark district can emit a symbol")
	for symbol in field.symbols:
		check(not field.is_lit(symbol.grid_pos),"All periodic spawns originate in darkness")
	var clocks: Array = field.spawn_clocks.duplicate()
	manager.active = true
	field._process(99)
	check(field.spawn_clocks == clocks,"Battle pauses spawning and siege clocks")
	manager.active = false
	for symbol in field.symbols:
		var area: int = field.area_at(symbol.grid_pos)
		var candidates: Array[Vector2i] = field._free_tiles(area,symbol,player)
		symbol.place(candidates[-1])
	for i in field.spawn_clocks.size():
		field.spawn_clocks[i] = 0
	field._tick_spawns(0.1,player)
	check(field.symbols.size() <= int(field.settings.max_active_symbols),"Spawn cap bounds active population")
	clear_symbols()
	# Kills no longer satisfy boss condition.
	enemy = field._spawn_symbol(Vector2i(23,44))
	field.battle_resolved(enemy,true)
	check(not field.boss_spawned,"Last symbol defeat does not summon boss")
	await process_frame
	# Leave the center undefended: infection follows the roads into the plaza.
	player.warp_to(Vector2i(105,14))
	field.grace = 10000
	for i in field.spawn_clocks.size():
		field.spawn_clocks[i] = 0
	for i in 9000:
		field._process(0.1)
		if not field.lit[0]:
			break
	check(not field.lit[0],"Dark-origin raiders can spread all the way to the fountain plaza")
	check(not field.boss_spawned,"Darkness propagation never summons boss")
	clear_symbols()
	player.warp_to(field.start_tile())
	var remaining: int = field.lit.find(false)
	for area in field.lamps.size():
		if area != remaining and not field.lit[area]:
			field.repair_lamp(area,player)
	check(not field.boss_spawned,"Boss waits for the final lamp")
	field.repair_lamp(remaining,player)
	check(field.boss_spawned and field.dark_count()==0,"All lamps lit summons boss")
	check(field.boss.grid_pos == Vector2i(21,42),"Boss appears in fountain plaza")
	var existing: Node2D = field.boss
	field._extinguish(1,player)
	field.repair_lamp(1,player)
	check(field.boss == existing,"Relighting cannot duplicate boss")
	check(field.boss_dark_count == 0,"No obsolete darkness weakening")
	# Runtime roll and balance input clamp both enforce a maximum of three.
	var rolls := {}
	for trial in 50:
		manager.start_symbol_battle(player,null,field,{"boss":false,"light":true})
		var count: int = manager.encounter_balance.monster_count
		check(count in [3,4,5],"Ordinary battle has three to five foes")
		rolls[count] = true
		manager._finish_battle(true)
		await process_frame
	check(rolls.size()==3,"All three group sizes occur")
	check(manager.balance_for_context({"boss":false,"light":true,"enemy_count":99},field.settings).monster_count==5,"Explicit context cannot exceed cap")
	# Contact during movement commits the tile before opening the battle.
	field.grace = 0
	var crossing: Node2D = field._spawn_symbol(Vector2i(23,44))
	player.warp_to(Vector2i(22,44))
	player._move_to(Vector2i(23,44))
	player._advance_step(player.MOVE_TIME*0.5)
	var halfway := player.position
	field.check_contact(player)
	check(not manager.active and player.position == halfway,"Contact cannot teleport a half-step")
	check(player.input_locked and field.pending_contact == crossing,"Pending contact locks the following step")
	player._advance_step(player.MOVE_TIME*0.5)
	check(manager.active and player.grid_pos == Vector2i(23,44),"Battle begins on whole-tile arrival")
	manager._finish_battle(false)
	check(player.grid_pos == field.start_tile(),"Defeat returns to the lit entrance")
	await process_frame
	clear_symbols()
	# Pity-step darkness encounters remain repeatable and independent of symbols.
	# Start a fresh darkness fixture; repaired lamps in the old map are permanent.
	field.secured_lamps.clear()
	field._extinguish(9,player)
	player.warp_to(Vector2i(105,14))
	field.settings.dark_encounter.chance_per_step = 0
	field.settings.dark_encounter.maximum_steps = 4
	for cycle in 2:
		field.grace = 0
		for i in 3:
			field.player_step_completed(player)
			check(not manager.active,"Darkness respects safe/random steps")
		field.player_step_completed(player)
		check(manager.active and manager.encounter_symbol == null,"Darkness independently triggers battle")
		manager._finish_battle(true)
		await process_frame
	main.free()
	print("NIGHT DUNGEON: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)


