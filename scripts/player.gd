extends Node2D

## Grid-snapped 4-direction movement: a held direction repeats whole tiles.
## Each step smoothly crosses to an adjacent cell with a synchronized foot cycle; blocked tiles
## just turn the character to face that way instead of moving.

const TILE_SIZE := preload("res://scripts/field.gd").TILE_SIZE
const MOVE_TIME := 0.24

const DIR_VECTOR := {
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"up": Vector2i(0, -1),
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
var _step_target: Vector2i
var _follower_target: Vector2i
var _step_start: Vector2
var _follower_start: Vector2


func _ready() -> void:
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
	for id in ["seola", "wiseong"]:
		var companion := FieldActor.new()
		companion.name = id.capitalize()
		companion.z_base = 2300
		companion.configure(load("res://assets/sprites/field/%s_night.png" % id))
		get_parent().add_child.call_deferred(companion)
		extra_followers.append(companion)
	_place_extra_followers()
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
	if _moving:
		_advance_step(delta)
		return
	_try_input_step()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_E, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and field != null:
			field.interact(self)
			get_viewport().set_input_as_handled()


func warp_to(tile: Vector2i) -> void:
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
	if input_locked:
		return
	var dir := _read_direction()
	if dir == "":
		return
	facing = dir
	var target: Vector2i = grid_pos + DIR_VECTOR[dir]
	if field != null and field.is_blocked(target):
		_update_sprite(false)
		return
	_move_to(target)


func _read_direction() -> String:
	if Input.is_action_pressed("ui_down"):
		return "down"
	if Input.is_action_pressed("ui_up"):
		return "up"
	if Input.is_action_pressed("ui_left"):
		return "left"
	if Input.is_action_pressed("ui_right"):
		return "right"
	return ""


func _move_to(target: Vector2i) -> void:
	if _moving or input_locked or (target - grid_pos).length_squared() != 1:
		return
	if field != null and field.is_blocked(target):
		_update_sprite(false)
		return
	_moving = true
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
	_step_elapsed = minf(_step_elapsed + delta, MOVE_TIME)
	var progress := _step_elapsed / MOVE_TIME
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
	if _step_elapsed >= MOVE_TIME:
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
	# Continue directly at tile boundaries; battles may lock input above.
	_try_input_step()


func _update_sprite(walking: bool) -> void:
	sprite.facing = facing
	sprite.walking = walking

func _place_extra_followers() -> void:
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
