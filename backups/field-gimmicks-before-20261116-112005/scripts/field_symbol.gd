extends "res://scripts/field_actor.gd"
## Fixed 64px art; field owns movement, contact and persistence.
var symbol_id := -1
var grid_pos := Vector2i.ZERO
var target := Vector2i.ZERO
var origin := Vector2.ZERO
var elapsed := 0.0
var moving := false
var wait := 0.0
var defeated := false
var dormant := false
var is_boss := false
var patrol_area := -1

func place(tile: Vector2i) -> void:
	grid_pos = tile
	target = tile
	position = Vector2(tile * TILE_SIZE)
	moving = false
	end_step()

func start_step(tile: Vector2i) -> void:
	var offset := tile - grid_pos
	facing = "right" if offset.x > 0 else "left" if offset.x < 0 else "down" if offset.y > 0 else "up"
	origin = position
	target = tile
	elapsed = 0.0
	moving = true
	begin_step()

func advance(delta: float, duration: float) -> bool:
	elapsed = minf(elapsed + delta, duration)
	var progress := elapsed / duration
	position = origin.lerp(Vector2(target * TILE_SIZE), progress).round()
	set_step_progress(progress)
	if elapsed >= duration:
		place(target)
		return true
	return false


var siege_area := -1
var siege_time := 0.0
var route: Array[Vector2i] = []
var route_key := ""
