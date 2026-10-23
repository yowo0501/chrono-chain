extends Node2D
## Native fixed-cell atlas: neither source cropping nor scaling changes per pose.
var texture: Texture2D
var facing := "down"
var walking := false
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
	# One stride per tile: pass through neutral, extend one foot, then plant it.
	current_frame = step_pose + 1 if progress >= 0.20 and progress < 0.80 else 0
	queue_redraw()

func end_step() -> void:
	walking = false
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
	draw_texture_rect_region(texture, frame_rect(region), region)
