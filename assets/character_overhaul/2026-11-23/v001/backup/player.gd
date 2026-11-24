extends Node2D

## Grid-snapped 8-direction movement: a held direction repeats whole tiles.
## Each step smoothly crosses to an adjacent cell with a synchronized foot cycle; blocked tiles
## just turn the character to face that way instead of moving.

const TILE_SIZE := preload("res://scripts/field.gd").TILE_SIZE
const MOVE_TIME := 0.24
const DASH_MULTIPLIER := 2.0
const CHAIN_RANGE := 2.0 # Half-width of the inclusive 5x5 lock-on square.
const CHAIN_SWING := 0.5
const CHAIN_RECOVERY := 0.25
const FIELD_COMPANIONS: Array[String] = [] # Current field cast: Chuheun and Yeonwoo only.

const DIR_VECTOR := {
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"up": Vector2i(0, -1),
	"up_left": Vector2i(-1,-1),
	"up_right": Vector2i(1,-1),
	"down_left": Vector2i(-1,1),
	"down_right": Vector2i(1,1),
}

const FieldActor = preload("res://scripts/field_actor.gd")
var sprite: Node2D
var follower: Node2D
var follower_grid: Vector2i
var extra_followers: Array[Node2D] = []
var extra_grids: Array[Vector2i] = []
var extra_targets: Array[Vector2i] = []
var extra_starts: Array[Vector2] = []

var field: Node = null
var grid_pos: Vector2i
var facing := "down"
var _moving := false
var input_locked := false
var _step_elapsed := 0.0
var _step_duration := MOVE_TIME
var chain_elapsed := -1.0
var chain_queued := false
var chain_victim: Node2D
var _step_target: Vector2i
var _follower_target: Vector2i
var _step_start: Vector2
var _follower_start: Vector2


func _ready() -> void:
	if not InputMap.has_action("field_dash"):
		InputMap.add_action("field_dash")
		var dash_key := InputEventKey.new()
		dash_key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("field_dash", dash_key)
	field = get_tree().get_first_node_in_group("field")
	if field != null and not field.test_grid:
		position = Vector2(field.start_tile() * TILE_SIZE)
	grid_pos = Vector2i(round(position.x / TILE_SIZE), round(position.y / TILE_SIZE))
	position = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	z_index = 2300 + roundi(position.y)
	if field != null:
		field.track_player_tile(self)
	sprite = FieldActor.new()
	sprite.name = "Chuheun"
	add_child(sprite)
	sprite.configure(load("res://assets/sprites/field/chuheun_night.png"))
	follower = FieldActor.new()
	follower.z_base = 2300
	follower.name = "Yeonwoo"
	get_parent().add_child.call_deferred(follower)
	follower.configure(load("res://assets/sprites/field/yeonwoo_night.png"))
	follower_grid = grid_pos
	for offset in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if field == null or not field.is_blocked(grid_pos + offset):
			follower_grid = grid_pos + offset
			break
	follower.position = Vector2(follower_grid * TILE_SIZE)
	for id in FIELD_COMPANIONS:
		var companion := FieldActor.new()
		companion.name = id.capitalize()
		companion.z_base = 2300
		companion.configure(load("res://assets/sprites/field/%s_night.png" % id))
		get_parent().add_child.call_deferred(companion)
		extra_followers.append(companion)
	_update_sprite(false)
	var camera := get_node_or_null("Camera2D") as Camera2D
	if camera != null and field != null:
		camera.position = Vector2(8, 8)
		# Reserve screen space for the fixed HUD at the north/south map limits.
		camera.limit_top = 0 if field.test_grid else -22
		camera.limit_right = field.width() * TILE_SIZE
		camera.limit_bottom = field.height() * TILE_SIZE + (0 if field.test_grid else 26)


func _process(delta: float) -> void:
	z_index = 2300 + roundi(position.y)
	if EncounterManager.active:
		return
	if field != null:
		field.chain_target(self,CHAIN_RANGE)
		queue_redraw()
	if chain_elapsed >= 0.0:
		_advance_chain(delta)
		return
	if _moving:
		_advance_step(delta)
		return
	_try_input_step()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			if field != null and field.chain_target(self,CHAIN_RANGE) == null:
				field.interact(self)
			else:
				request_chain()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_T:
			request_chain()
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_E, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and field != null:
			field.interact(self)
			get_viewport().set_input_as_handled()


func warp_to(tile: Vector2i) -> void:
	reset_field_action()
	grid_pos = tile
	position = Vector2(tile * TILE_SIZE)
	z_index = 2300 + roundi(position.y)
	_moving = false
	follower_grid = tile
	for offset in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if not field.is_blocked(tile + offset):
			follower_grid = tile + offset
			break
	follower.position = Vector2(follower_grid * TILE_SIZE)
	sprite.end_step()
	follower.end_step()
	_place_extra_followers()
	if field != null:
		field.track_player_tile(self)


func _try_input_step() -> void:
	if input_locked or chain_elapsed >= 0.0:
		return
	var dir := _read_direction()
	if dir == "":
		return
	facing = dir
	var target: Vector2i = grid_pos + DIR_VECTOR[dir]
	if field != null and not field.can_step(grid_pos,target):
		_update_sprite(false)
		return
	_move_to(target)


func _read_direction() -> String:
	var delta := Vector2i(int(Input.is_action_pressed("ui_right"))-int(Input.is_action_pressed("ui_left")), int(Input.is_action_pressed("ui_down"))-int(Input.is_action_pressed("ui_up")))
	for direction in DIR_VECTOR:
		if DIR_VECTOR[direction] == delta:
			return direction
	return ""


func _move_to(target: Vector2i) -> void:
	if _moving or input_locked or chain_elapsed >= 0.0 or (target - grid_pos).length_squared() not in [1,2]:
		return
	if field != null and not field.can_step(grid_pos,target):
		_update_sprite(false)
		return
	_moving = true
	var dash := Input.is_action_pressed("field_dash")
	_step_duration = MOVE_TIME * Vector2(target-grid_pos).length() / (DASH_MULTIPLIER if dash else 1.0)
	sprite.dashing = dash
	follower.dashing = dash
	var previous := grid_pos
	var direction_delta := target - previous
	for direction in DIR_VECTOR:
		if DIR_VECTOR[direction] == direction_delta:
			facing = direction
	var follower_delta := previous - follower_grid
	for direction in DIR_VECTOR:
		if DIR_VECTOR[direction] == follower_delta:
			follower.facing = direction
	follower.walking = follower_delta != Vector2i.ZERO
	if follower.walking:
		follower.begin_step()
	sprite.begin_step()
	_step_elapsed = 0.0
	_step_start = position
	_follower_start = follower.position
	_step_target = target
	_follower_target = previous
	var ahead := follower_grid
	for i in extra_followers.size():
		var companion := extra_followers[i]
		extra_starts[i] = companion.position
		extra_targets[i] = ahead
		var step := ahead - extra_grids[i]
		for direction in DIR_VECTOR:
			if DIR_VECTOR[direction] == step:
				companion.facing = direction
		if step != Vector2i.ZERO:
			companion.begin_step()
		ahead = extra_grids[i]
	_update_sprite(true)


func _advance_step(delta: float) -> void:
	_step_elapsed = minf(_step_elapsed + delta, _step_duration)
	var progress := _step_elapsed / _step_duration
	# Logical cells commit on arrival; render positions cross every pixel in between.
	position = _step_start.lerp(Vector2(_step_target * TILE_SIZE), progress).round()
	follower.position = _follower_start.lerp(Vector2(_follower_target * TILE_SIZE), progress).round()
	for i in extra_followers.size():
		extra_followers[i].position = extra_starts[i].lerp(Vector2(extra_targets[i] * TILE_SIZE), progress).round()
		if extra_followers[i].walking:
			extra_followers[i].set_step_progress(progress)
	sprite.set_step_progress(progress)
	if follower.walking:
		follower.set_step_progress(progress)
	if _step_elapsed >= _step_duration:
		_on_move_finished()


func _on_move_finished() -> void:
	grid_pos = _step_target
	follower_grid = _follower_target
	position = Vector2(grid_pos * TILE_SIZE)
	follower.position = Vector2(follower_grid * TILE_SIZE)
	_moving = false
	sprite.end_step()
	follower.end_step()
	for i in extra_followers.size():
		extra_grids[i] = extra_targets[i]
		extra_followers[i].position = Vector2(extra_grids[i] * TILE_SIZE)
		extra_followers[i].end_step()
	_update_sprite(false)
	EncounterManager.step_completed(self)
	# Finish a tile before a buffered swing; contact takes priority at this boundary.
	if chain_queued:
		chain_queued = false
		request_chain()
	_try_input_step()


func _update_sprite(walking: bool) -> void:
	sprite.facing = facing
	sprite.walking = walking

func _place_extra_followers() -> void:
	if extra_followers.is_empty():
		return
	# Prefer a complete straight starting column; walking still follows the path.
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var clear := true
		for distance in range(1,4):
			if field != null and field.is_blocked(grid_pos+direction*distance):
				clear = false
		if clear:
			follower_grid = grid_pos+direction
			follower.position = Vector2(follower_grid*TILE_SIZE)
			break
	extra_grids.clear()
	extra_targets.clear()
	extra_starts.clear()
	var used: Array[Vector2i] = [grid_pos, follower_grid]
	var ahead := follower_grid
	for companion in extra_followers:
		var tile := ahead
		for offset in [follower_grid-grid_pos,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			if ahead+offset not in used and (field == null or not field.is_blocked(ahead+offset)):
				tile = ahead+offset
				break
		extra_grids.append(tile)
		extra_targets.append(tile)
		companion.position = Vector2(tile*TILE_SIZE)
		extra_starts.append(companion.position)
		companion.end_step()
		used.append(tile)
		ahead = tile

func occupies_tile(tile: Vector2i) -> bool:
	return tile == grid_pos or tile == follower_grid or tile in extra_grids or (_moving and (tile == _step_target or tile in extra_targets))

func _exit_tree() -> void:
	for companion in extra_followers:
		if is_instance_valid(companion):
			companion.queue_free()
	if is_instance_valid(follower):
		follower.queue_free()


func request_chain() -> bool:
	if input_locked or EncounterManager.active or chain_elapsed >= 0.0:
		return false
	if _moving:
		chain_queued = true
		return true
	chain_queued = false
	chain_victim = field.chain_target(self,CHAIN_RANGE) if field != null else null
	if not is_instance_valid(chain_victim): return false
	var aim: Vector2 = chain_victim.position-position
	facing = ("right" if aim.x>0 else "left") if absf(aim.x)>absf(aim.y) else ("down" if aim.y>0 else "up")
	chain_elapsed = 0.0
	_update_sprite(false)
	sprite.end_step()
	sprite.set_chain_progress(0.0)
	queue_redraw()
	return true

func chain_remaining() -> float:
	return maxf(0.0, CHAIN_SWING + CHAIN_RECOVERY - chain_elapsed) if chain_elapsed >= 0.0 else 0.0

func reset_field_action() -> void:
	chain_elapsed = -1.0
	chain_queued = false
	chain_victim = null
	if is_instance_valid(sprite):
		sprite.action_lean = 0.0
		sprite.action_offset = Vector2.ZERO
		sprite.set_chain_progress(1.0)
	queue_redraw()

func _advance_chain(delta: float) -> void:
	var previous := chain_elapsed
	chain_elapsed = minf(chain_elapsed + delta, CHAIN_SWING + CHAIN_RECOVERY)
	sprite.set_chain_progress(clampf(chain_elapsed / CHAIN_SWING,0.0,1.0))
	if previous < CHAIN_SWING:
		# Sweep the interval as well as its endpoint so a slow frame cannot skip a hit.
		var peak := clampf(CHAIN_SWING * 0.64, previous, minf(chain_elapsed, CHAIN_SWING))
		var reach := chain_extension(peak / CHAIN_SWING) * CHAIN_RANGE
		if peak >= CHAIN_SWING*0.64 and field != null and field.try_chain_hit(self, reach):
			sprite.action_lean = 0.0
			sprite.action_offset = Vector2.ZERO
			queue_redraw()
			return
	sprite.action_lean = 0.0
	sprite.action_offset = Vector2.ZERO
	if chain_remaining() <= 0.00001:
		reset_field_action()
	queue_redraw()

func chain_extension(progress: float) -> float:
	# Deliberate draw-back, cast, then retract; no early hit during anticipation.
	return smoothstep(0.5,0.64,progress) * (1.0-smoothstep(0.66,0.90,progress))

func _draw() -> void:
	if field != null and is_instance_valid(field.locked_target) and not EncounterManager.active:
		var marker: Vector2 = field.locked_target.position-position+Vector2(8,-7)
		draw_arc(marker,5,0,TAU,16,Color("f4d07a"),1)
		draw_line(marker-Vector2(7,0),marker+Vector2(7,0),Color("f4d07a"),0.6)
		draw_line(marker-Vector2(0,7),marker+Vector2(0,7),Color("f4d07a"),0.6)
	if chain_elapsed <= 0.0 or chain_elapsed >= CHAIN_SWING:
		return
	var progress := chain_elapsed / CHAIN_SWING
	var direction: Vector2 = Vector2(DIR_VECTOR[facing]).normalized()
	var side := direction.orthogonal()
	var endpoint: Vector2 = chain_victim.position-position+Vector2(8,8) if is_instance_valid(chain_victim) else Vector2(8,8)+direction*CHAIN_RANGE*TILE_SIZE
	var wrist: Vector2 = sprite.chain_socket()
	var extension := chain_extension(progress)
	if extension <= 0.001:
		return
	var end := wrist.lerp(endpoint,extension)
	var reach := wrist.distance_to(end)
	var count := maxi(1, ceili(reach / 3.0))
	for i in count:
		var t := float(i) / count
		var at := wrist.lerp(end,t) + side * sin(t * PI) * sin(progress * TAU) * 3.0
		var points := PackedVector2Array()
		for j in 9:
			var angle := TAU * j / 8.0
			points.append(at + direction * cos(angle) * 2.0 + side * sin(angle) * (1.0 if i % 2 == 0 else 0.5))
		draw_polyline(points, Color(0.12, 0.44, 0.85, 0.24), 3.0)
		draw_polyline(points, Color("172f59"), 1.4)
		draw_polyline(points, Color("9dbde3"), 0.65)
