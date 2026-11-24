extends Node2D
## Native fixed-cell atlas: neither source cropping nor scaling changes per pose.
var texture: Texture2D
var facing := "down"
var walking := false
var dashing := false
var stride_progress := 0.0
var action_lean := 0.0
var action_offset := Vector2.ZERO
var step_pose := 0
var current_frame := 0
var z_base := 0
var regions: Array[Rect2] = []
const TILE_SIZE := preload("res://scripts/field.gd").TILE_SIZE
const FRAME_SIZE := 64
const DIRECTIONS := {"down": 0, "left": 1, "right": 2, "up": 3}

func configure(source: Texture2D) -> void:
	assert(source.get_size() == Vector2(FRAME_SIZE * 3, FRAME_SIZE * 4), "Field sprites require a 3x4 atlas of 64px frames")
	texture = source
	regions.clear()
	for row in 4:
		for column in 3:
			regions.append(Rect2(Vector2(column, row) * FRAME_SIZE, Vector2.ONE * FRAME_SIZE))
	queue_redraw()

func begin_step() -> void:
	step_pose = 1 - step_pose
	walking = true
	set_step_progress(0.0)

func set_step_progress(progress: float) -> void:
	stride_progress = progress
	# One stride per tile: pass through neutral, extend one foot, then plant it.
	current_frame = step_pose + 1 if progress >= 0.20 and progress < 0.80 else 0
	queue_redraw()

func end_step() -> void:
	walking = false
	dashing = false
	stride_progress = 0.0
	current_frame = 0
	queue_redraw()

func _process(_delta: float) -> void:
	z_index = z_base + roundi(position.y)
	queue_redraw()

func frame_rect(_region: Rect2) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2.ONE * TILE_SIZE)

func _draw() -> void:
	if regions.is_empty():
		return
	var direction: int = int(DIRECTIONS[facing])
	var region := regions[direction * 3 + current_frame]
	var hop := roundf(sin(stride_progress * PI)) if walking and dashing else 0.0
	var lean := (0.10 if facing == "right" else -0.10 if facing == "left" else 0.0) if walking and dashing else 0.0
	var pivot := Vector2(8, 15)
	if walking and dashing:
		var behind := Vector2(-3, 0) if facing == "right" else Vector2(3, 0) if facing == "left" else Vector2(0, 2)
		draw_rect(Rect2(pivot + behind + Vector2(-2, 0), Vector2(2, 1)), Color(0.65, 0.71, 0.73, 0.4))
		draw_rect(Rect2(pivot + behind * 2.0 + Vector2(1, -1), Vector2.ONE), Color(0.65, 0.71, 0.73, 0.25))
	# Transform the complete atlas cell together; never split the head or body.
	var angle := lean + action_lean
	draw_set_transform(pivot + action_offset - pivot.rotated(angle) + Vector2(0, -hop), angle)
	draw_texture_rect_region(texture, frame_rect(region), region)
	draw_set_transform(Vector2.ZERO)
