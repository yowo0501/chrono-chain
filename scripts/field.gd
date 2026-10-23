extends Node2D
## 2D field: light/dark state persists while battle overlays are open.
const TILE_SIZE := 16
const OFFSETS := [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
@export var test_grid := false
var settings: Dictionary
var tiles: Array = []
var lamps: Array[Vector2i] = []
var lit: Array[bool] = []
var secured_lamps: Array[int] = []
var symbols: Array[Node2D] = []
var boss: Node2D
var boss_spawned := false
var boss_defeated := false
var boss_dark_count := 0
var defeated_count := 0
var grace := 0.0
var rng := RandomNumberGenerator.new()
var notice := "도시의 모든 가로등을 밝히세요 · 지도 M"
var notice_time := 6.0
var hud: Control
var pending_contact: Node2D
var last_player_area := -1
var last_player_lit := true
var map_scale := 1
var dark_steps := 0
var area_cells: Array = []
var area_exits: Array = []
var area_neighbors: Array = []
var spawn_clocks: Array[float] = []
var lighting_revision := 0
var light_patrol_areas: Dictionary = {}
var patrol_revision := -1
var patrol_refresh := 0.0

func _tick_light_patrols(delta: float, player: Node2D) -> void:
	if boss_defeated:
		return
	patrol_refresh -= delta
	if patrol_revision == lighting_revision and patrol_refresh > 0:
		return
	patrol_revision = lighting_revision
	patrol_refresh = 30.0
	var candidates: Array[int] = []
	for area in lamps.size():
		if lit[area]:
			candidates.append(area)
	for area in light_patrol_areas.keys():
		if not lit[area]:
			light_patrol_areas.erase(area)
	var desired := ceili(candidates.size()/2.0)
	while light_patrol_areas.size() > desired:
		light_patrol_areas.erase(light_patrol_areas.keys().back())
	for area in light_patrol_areas:
		candidates.erase(area)
	while light_patrol_areas.size() < desired and not candidates.is_empty():
		var chosen := rng.randi_range(0,candidates.size()-1)
		light_patrol_areas[candidates[chosen]] = rng.randi_range(1,2)
		candidates.remove_at(chosen)
	for symbol in symbols:
		if symbol.patrol_area >= 0 and not light_patrol_areas.has(symbol.patrol_area):
			symbol.patrol_area = -1
	for area in light_patrol_areas:
		var residents := 0
		for symbol in symbols:
			if not symbol.defeated and symbol.patrol_area == area:
				residents += 1
		var free: Array[Vector2i] = []
		for tile in area_cells[area]:
			if not _occupied(tile) and not player.occupies_tile(tile) and _distance(tile,player.grid_pos) > 4 and tile not in object_edges(lamps[area]):
				free.append(tile)
		while residents < int(light_patrol_areas[area]) and not free.is_empty():
			var chosen := rng.randi_range(0,free.size()-1)
			var symbol := _spawn_symbol(free[chosen])
			symbol.patrol_area = area
			free.remove_at(chosen)
			residents += 1

func area_name(area: int) -> String:
	return str(settings.areas[area].name)

func _index_areas() -> void:
	for area in lamps.size():
		area_cells.append([])
		area_exits.append([])
		area_neighbors.append([])
		spawn_clocks.append(float(settings.dark_spawn_seconds) + area * 1.7)
	for y in height():
		for x in width():
			var tile := Vector2i(x,y)
			if is_blocked(tile):
				continue
			var area := area_at(tile)
			area_cells[area].append(tile)
			for offset in OFFSETS:
				var next: Vector2i = tile + offset
				if is_blocked(next):
					continue
				var neighbor := area_at(next)
				if neighbor != area:
					if not area_neighbors[area].has(neighbor):
						area_neighbors[area].append(neighbor)
					if not area_exits[area].has(next):
						area_exits[area].append(next)

func _spawn_symbol(tile: Vector2i) -> Node2D:
	var symbol := _create_symbol(false)
	symbol.symbol_id = defeated_count + symbols.size()
	symbol.place(tile)
	symbol.wait = 1.0
	symbols.append(symbol)
	_update_visibility(symbol)
	return symbol

func _tick_spawns(delta: float, player: Node2D) -> void:
	if boss_defeated:
		return
	for area in lamps.size():
		if lit[area]:
			spawn_clocks[area] = float(settings.dark_spawn_seconds)
			continue
		spawn_clocks[area] -= delta
		if spawn_clocks[area] > 0 or symbols.size() >= int(settings.max_active_symbols):
			continue
		var point: Array = settings.areas[area].spawn
		var tile := Vector2i(int(point[0]),int(point[1]))
		if _occupied(tile) or player.occupies_tile(tile):
			continue
		_spawn_symbol(tile)
		spawn_clocks[area] = float(settings.dark_spawn_seconds)


func object_anchor(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x / map_scale, tile.y / map_scale) * map_scale + Vector2i.ONE * (map_scale / 2)

func object_edges(anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var corner := Vector2i(anchor.x / map_scale, anchor.y / map_scale) * map_scale
	for i in map_scale:
		for point in [corner + Vector2i(i, -1), corner + Vector2i(i, map_scale), corner + Vector2i(-1, i), corner + Vector2i(map_scale, i)]:
			if not is_blocked(point):
				result.append(point)
	return result

func track_player_tile(player: Node2D) -> void:
	last_player_area = area_at(player.grid_pos)
	last_player_lit = is_lit(player.grid_pos)

func player_step_completed(player: Node2D) -> void:
	if test_grid:
		return
	var area := area_at(player.grid_pos)
	track_player_tile(player)
	if boss_spawned and not boss_defeated and boss.grid_pos == player.grid_pos:
		_engage(boss, player)
		return
	if not lit[area]:
		dark_steps += 1
		var encounter: Dictionary = settings.dark_encounter
		if grace > 0 or dark_steps <= int(encounter.safe_steps):
			return
		if dark_steps < int(encounter.maximum_steps) and rng.randf() >= float(encounter.chance_per_step):
			return
		dark_steps = 0
		pending_contact = null
		EncounterManager.start_symbol_battle(player, null, self, {
			"boss": false, "light": false, "random_darkness": true,
			"dark_lamps": dark_count()
		})
		return
	dark_steps = 0
	check_contact(player)

func _ready() -> void:
	add_to_group("field")
	rng.randomize()
	settings = JSON.parse_string(FileAccess.get_file_as_string("res://data/field_map.json"))
	tiles = settings.tiles.duplicate()
	if test_grid:
		tiles.clear()
		for y in 14:
			tiles.append("####################" if y == 0 or y == 13 else "#..................#")
		return
	map_scale = int(settings.get("map_scale", 2))
	tiles.clear()
	for source_row in settings.tiles:
		var expanded := ""
		for character in str(source_row):
			expanded += character.repeat(map_scale)
		for repeat_row in map_scale:
			tiles.append(expanded)
	for definition in settings.areas:
		var point: Array = definition.lamp
		lamps.append(Vector2i(int(point[0]),int(point[1])))
		lit.append(not settings.initial_dark_areas.has(float(lamps.size()-1)))
	_index_areas()
	for point in settings.enemy_spawns:
		_spawn_symbol(Vector2i(int(point[0]),int(point[1])))
	var town := load("res://scripts/field_2d.gd").new() as Node2D
	town.name = "Town2D"
	add_child(town)
	var layer := CanvasLayer.new()
	var darkness: Node2D = load("res://scripts/field_darkness.gd").new()
	darkness.field = self
	add_child(darkness)
	layer.layer = 10
	add_child(layer)
	hud = load("res://scripts/field_hud.gd").new()
	hud.field = self
	layer.add_child(hud)
	queue_redraw()

func _create_symbol(is_boss: bool) -> Node2D:
	var symbol: Node2D = load("res://scripts/field_symbol.gd").new()
	symbol.is_boss = is_boss
	if is_boss:
		symbol.z_base = 2300
	add_child(symbol)
	symbol.configure(load("res://assets/sprites/field/%s_night.png" % ("boss" if is_boss else "shadow")))
	return symbol

func width() -> int:
	return str(tiles[0]).length() if not tiles.is_empty() else 25

func height() -> int:
	return tiles.size()

func tile_kind(tile: Vector2i) -> String:
	if tile.x < 0 or tile.y < 0 or tile.x >= width() or tile.y >= height():
		return "#"
	return str(tiles[tile.y]).substr(tile.x, 1)

func is_blocked(tile: Vector2i) -> bool:
	return tile_kind(tile) != "."

func start_tile() -> Vector2i:
	return Vector2i(int(settings.start[0]), int(settings.start[1])) * map_scale + Vector2i.ONE * (map_scale / 2)

func area_at(tile: Vector2i) -> int:
	if test_grid:
		return 0
	var x := clampi(tile.x,0,width()-1)
	var y := clampi(tile.y,0,height()-1)
	return "0123456789ABCDEF".find(str(settings.area_tiles[y]).substr(x,1))

func is_lit(tile: Vector2i) -> bool:
	return true if test_grid else lit[area_at(tile)]

func dark_count() -> int:
	return lit.count(false)

func walker() -> Node2D:
	return get_parent().get_node_or_null("Player")

func say(message: String) -> void:
	notice = message
	notice_time = 4.0

func _process(delta: float) -> void:
	if test_grid or EncounterManager.active:
		return
	grace = maxf(0.0, grace - delta)
	notice_time = maxf(0.0, notice_time - delta)
	var player := walker()
	if player == null:
		return
	if is_instance_valid(pending_contact):
		check_contact(player)
		return
	_tick_spawns(delta, player)
	_tick_light_patrols(delta, player)
	for symbol in symbols:
		if symbol.defeated:
			continue
		if symbol.moving:
			if symbol.advance(delta, float(settings.enemy_step_seconds)):
				symbol.wait = float(settings.enemy_idle_seconds)
		else:
			var area := area_at(symbol.grid_pos)
			var attacking: bool = bool(settings.get("lamp_break_enabled",false)) and symbol.patrol_area < 0 and lit[area] and area not in secured_lamps and area_at(player.grid_pos) != area and object_edges(lamps[area]).has(symbol.grid_pos)
			if attacking and not boss_defeated:
				symbol.siege_area = area
				symbol.siege_time += delta
				if symbol.siege_time >= float(settings.lamp_break_seconds):
					_extinguish(area,player)
					symbol.siege_time = 0
			else:
				symbol.siege_area = -1
				symbol.siege_time = 0
				symbol.wait -= delta
				if symbol.wait <= 0 and not boss_defeated:
					_decide(symbol,player)
		_update_visibility(symbol)
		if check_contact(player):
			break
	check_contact(player)

func _update_visibility(symbol: Node2D) -> void:
	symbol.visible = not symbol.defeated and (symbol.is_boss or is_lit(symbol.grid_pos))

func _occupied(tile: Vector2i, except: Node2D = null) -> bool:
	for symbol in symbols:
		if symbol == except or symbol.defeated:
			continue
		if symbol.grid_pos == tile or (symbol.moving and symbol.target == tile):
			return true
	return boss_spawned and not boss_defeated and boss != except and boss.grid_pos == tile

func path_to(start: Vector2i, goals: Array[Vector2i], symbol: Node2D = null, allowed_areas: Array[int] = []) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	var goal_set := {}
	for goal in goals:
		goal_set[goal] = true
	var player := walker() if symbol != null else null
	var index := 0
	while index < frontier.size():
		var current := frontier[index]
		index += 1
		if goal_set.has(current):
			var path: Array[Vector2i] = []
			while current != start:
				path.push_front(current)
				current = previous[current]
			return path
		for offset in OFFSETS:
			var next: Vector2i = current + offset
			if previous.has(next) or is_blocked(next) or _occupied(next, symbol):
				continue
			if player != null and (next == player.grid_pos or (player._moving and next == player._step_target)):
				continue
			if not allowed_areas.is_empty() and not allowed_areas.has(area_at(next)):
				continue
			previous[next] = current
			frontier.append(next)
	return []

func adjacent_areas(area: int) -> Array[int]:
	var result: Array[int] = []
	result.assign(area_neighbors[area])
	return result

func _decide(symbol: Node2D, player: Node2D) -> void:
	if symbol.patrol_area >= 0:
		var neighbors: Array[Vector2i] = []
		for offset in OFFSETS:
			var next: Vector2i = symbol.grid_pos + offset
			if not is_blocked(next) and area_at(next) == symbol.patrol_area and not _occupied(next,symbol) and not player.occupies_tile(next):
				neighbors.append(next)
		if not neighbors.is_empty():
			symbol.start_step(neighbors[rng.randi_range(0,neighbors.size()-1)])
		symbol.wait = rng.randf_range(0.6,1.5)
		return
	var area := area_at(symbol.grid_pos)
	var player_area := area_at(player.grid_pos)
	var key := "%d/%d/%d" % [area,player_area,lighting_revision]
	if symbol.route_key != key or symbol.route.is_empty():
		var goals: Array[Vector2i] = []
		var allowed: Array[int] = []
		if area == player_area:
			goals.assign(area_exits[area])
		else:
			for target_area in lamps.size():
				if target_area not in secured_lamps and lit[target_area] and target_area != player_area:
					goals.append_array(object_edges(lamps[target_area]))
				if target_area != player_area:
					allowed.append(target_area)
			symbol.route.clear()
		if not goals.is_empty():
			symbol.route = path_to(symbol.grid_pos, goals, symbol, allowed)
		symbol.route_key = key
	if not symbol.route.is_empty():
		var next: Vector2i = symbol.route.pop_front()
		if not _occupied(next,symbol) and next != player.grid_pos and (not player._moving or next != player._step_target):
			symbol.start_step(next)
		else:
			symbol.route.clear()
	elif area == player_area:
		_flee_neighbor(symbol,player)
	symbol.wait = float(settings.enemy_idle_seconds)

func _flee_neighbor(symbol: Node2D, player: Node2D) -> void:
	var best: Vector2i = symbol.grid_pos
	var distance := _distance(best, player.grid_pos)
	for offset in OFFSETS:
		var candidate: Vector2i = symbol.grid_pos + offset
		if is_blocked(candidate) or _occupied(candidate, symbol) or candidate == player.grid_pos:
			continue
		if player._moving and candidate == player._step_target:
			continue
		if _distance(candidate, player.grid_pos) > distance:
			best = candidate
			distance = _distance(candidate, player.grid_pos)
	if best != symbol.grid_pos:
		symbol.start_step(best)

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _free_tiles(area: int, symbol: Node2D, player: Node2D) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height():
		for x in width():
			var tile := Vector2i(x, y)
			if area_at(tile) != area or is_blocked(tile) or _occupied(tile, symbol):
				continue
			if player != null and (player.occupies_tile(tile)):
				continue
			result.append(tile)
	return result

func _extinguish(area: int, _player: Node2D) -> void:
	if not bool(settings.get("lamp_break_enabled",false)) or not lit[area] or boss_defeated or area in secured_lamps:
		return
	lit[area] = false
	lighting_revision += 1
	spawn_clocks[area] = float(settings.dark_spawn_seconds)
	say("%s · 가로등 파괴" % area_name(area))
	for symbol in symbols:
		_update_visibility(symbol)
	queue_redraw()

func interact(player: Node2D) -> void:
	if test_grid or EncounterManager.active or player._moving or player.input_locked:
		return
	var target := interaction_target(player)
	if target.is_empty():
		say("가로등 옆에서 E를 누르세요")
		return
	repair_lamp(lamps.find(target.tile), player)

func interaction_target(player: Node2D) -> Dictionary:
	var order: Array[Vector2i] = [player.DIR_VECTOR[player.facing]]
	for offset in OFFSETS:
		if not order.has(offset):
			order.append(offset)
	for offset in order:
		var tile: Vector2i = player.grid_pos + offset
		if tile_kind(tile) == "L":
			return {"tile": object_anchor(tile), "kind": tile_kind(tile)}
	return {}

func repair_lamp(area: int, _player: Node2D) -> bool:
	if area < 0 or area >= lit.size():
		return false
	if lit[area]:
		say("이미 켜진 가로등입니다")
		return false
	lit[area] = true
	secured_lamps.append(area)
	lighting_revision += 1
	spawn_clocks[area] = float(settings.dark_spawn_seconds)
	for symbol in symbols:
		_update_visibility(symbol)
	say("%s · 가로등 복구" % area_name(area))
	if dark_count() == 0:
		_spawn_boss()
	queue_redraw()
	return true

func check_contact(player: Node2D) -> bool:
	if test_grid or EncounterManager.active or grace > 0.0:
		return false
	if is_instance_valid(pending_contact):
		if player._moving:
			return false
		var contacted := pending_contact
		pending_contact = null
		_engage(contacted, player)
		return true
	var actors: Array[Node2D] = symbols.duplicate()
	if boss_spawned and not boss_defeated:
		actors.append(boss)
	for symbol in actors:
		if symbol.defeated:
			continue
		if not symbol.is_boss and not is_lit(symbol.grid_pos):
			continue # Dark areas roll repeatable encounters on completed steps.
		if symbol.position.distance_to(player.position) < TILE_SIZE * 0.60:
			if player._moving:
				pending_contact = symbol
				player.input_locked = true
				return false
			_engage(symbol, player)
			return true
	return false

func _engage(symbol: Node2D, player: Node2D) -> void:
	if EncounterManager.active:
		return
	EncounterManager.start_symbol_battle(player, symbol, self, {
		"boss": symbol.is_boss, "light": true if symbol.is_boss else is_lit(symbol.grid_pos),
		"dark_lamps": boss_dark_count if symbol.is_boss else dark_count()
	})

func battle_resolved(symbol: Node2D, won: bool) -> void:
	if won:
		if not is_instance_valid(symbol):
			say("어둠 속 습격을 물리쳤습니다")
		elif symbol.is_boss:
			symbol.defeated = true
			symbol.visible = false
			boss_defeated = true
			say("골목의 그림자를 모두 물리쳤습니다")
		elif not symbol.defeated:
			symbol.defeated = true
			symbol.visible = false
			defeated_count += 1
			symbols.erase(symbol)
			symbol.queue_free()
			say("밝은 구역의 그림자를 물리쳤습니다" if symbol.patrol_area >= 0 else "가로등을 노리던 그림자를 물리쳤습니다")
	else:
		walker().warp_to(start_tile())
		say("입구에서 다시 시작합니다 · 남은 적은 유지됩니다")
	grace = 1.2
	dark_steps = 0
	queue_redraw()

func _spawn_boss() -> void:
	if boss_spawned or dark_count() != 0:
		return
	boss_dark_count = 0
	boss_spawned = true
	boss = _create_symbol(true)
	boss.place(Vector2i(int(settings.boss_tile[0]), int(settings.boss_tile[1])) * map_scale + Vector2i.ONE * (map_scale / 2))
	boss.visible = true
	say("모든 가로등 점등 · 분수 광장에 보스 출현")

func _draw() -> void:
	if not test_grid:
		return
	for y in height():
		for x in width():
			var rect := Rect2(Vector2(x,y)*TILE_SIZE,Vector2.ONE*TILE_SIZE)
			draw_rect(rect,Color("63716b") if tile_kind(Vector2i(x,y)) == "#" else Color("dce3dc") if (x+y)%2 == 0 else Color("ccd6ce"))
			draw_rect(rect,Color("a0afa4"),false,0.3)
