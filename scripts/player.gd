extends Node2D

## Grid-snapped 4-direction movement, DQ/FF-style: one tile per key press,
## a short tween between tiles (no free/analog movement), blocked tiles
## just turn the character to face that way instead of moving.

const TILE_SIZE := 16
const MOVE_TIME := 0.14

# sprite sheet column order: down, left, right, up (see hero_walk.png)
const DIR_COLUMN := {
	"down": 0,
	"left": 1,
	"right": 2,
	"up": 3,
}

const DIR_VECTOR := {
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"up": Vector2i(0, -1),
}

@onready var sprite: Sprite2D = $Sprite

var field: Node = null
var grid_pos: Vector2i
var facing := "down"
var _moving := false
var _step := 0
var _tween: Tween = null


func _ready() -> void:
	field = get_tree().get_first_node_in_group("field")
	grid_pos = Vector2i(round(position.x / TILE_SIZE), round(position.y / TILE_SIZE))
	position = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
	_update_sprite(false)


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _process(_delta: float) -> void:
	if _moving:
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
	_moving = true
	grid_pos = target
	_step = 1 - _step
	_update_sprite(true)
	var target_pos := Vector2(target.x * TILE_SIZE, target.y * TILE_SIZE)
	_tween = create_tween()
	_tween.tween_property(self, "position", target_pos, MOVE_TIME)
	_tween.finished.connect(_on_move_finished)


func _on_move_finished() -> void:
	_moving = false


func _update_sprite(walking: bool) -> void:
	var col: int = DIR_COLUMN[facing]
	var row := _step if walking else 0
	sprite.frame = row * 4 + col
