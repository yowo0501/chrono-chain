extends Node2D
## Whole-cell registered animation. Heroes use 8 directions; enemy atlases remain compatible.
const TILE_SIZE := 16
const FRAME_SIZE := 64
const DIRECTIONS := {"down":0,"down_left":1,"left":2,"up_left":3,"up":4,"up_right":5,"right":6,"down_right":7}
const LEGACY_DIRECTIONS := {"down":0,"down_left":1,"left":1,"up_left":1,"up":3,"up_right":2,"right":2,"down_right":2}
var texture: Texture2D
var facing := "down"
var walking := false
var dashing := false
var stride_progress := 0.0
var action_progress := -1.0
var action_lean := 0.0
var action_offset := Vector2.ZERO
var step_pose := 0
var current_frame := 0
var z_base := 0
var regions: Array[Rect2] = []
var eight_way := false

func configure(source: Texture2D) -> void:
	texture = source
	eight_way = source.get_size() == Vector2(512,512)
	assert(eight_way or source.get_size() == Vector2(192,256), "Unexpected atlas layout")
	regions.clear()
	for row in (8 if eight_way else 4):
		for column in (8 if eight_way else 3):
			regions.append(Rect2(Vector2(column,row)*64,Vector2(64,64)))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func begin_step() -> void:
	step_pose = 1-step_pose
	walking = true
	action_progress = -1.0
	set_step_progress(0.0)

func set_step_progress(progress: float) -> void:
	stride_progress = progress
	if eight_way:
		if dashing:
			current_frame = (4 if step_pose == 0 else 5) if progress < 0.78 else 2
		else:
			current_frame = 2 if progress < 0.15 or progress >= 0.78 else (1 if step_pose == 0 else 3)
	else:
		current_frame = step_pose+1 if progress >= 0.2 and progress < 0.8 else 0
	queue_redraw()

func set_chain_progress(progress: float) -> void:
	action_progress = progress
	if eight_way:
		current_frame = 6 if progress < 0.25 else 7 if progress < 0.75 else 2 if progress < 1.0 else 0
	queue_redraw()

func end_step() -> void:
	walking = false
	dashing = false
	stride_progress = 0.0
	action_progress = -1.0
	current_frame = 0
	queue_redraw()

func _process(_delta: float) -> void:
	z_index = z_base + roundi(position.y)
	queue_redraw()

func frame_rect(_region: Rect2) -> Rect2:
	return Rect2(-8,-14,32,32) if eight_way else Rect2(0,0,16,16)

func _draw() -> void:
	if regions.is_empty():
		return
	var row: int = DIRECTIONS.get(facing,0) if eight_way else LEGACY_DIRECTIONS.get(facing,0)
	var region := regions[row*(8 if eight_way else 3)+current_frame]
	var hop := -1.0 if walking and dashing and stride_progress > 0.2 and stride_progress < 0.65 else 0.0
	if eight_way:
		draw_set_transform(Vector2(8,15),0,Vector2(1,0.35))
		draw_circle(Vector2.ZERO,6.0,Color(0,0,0,0.24))
		draw_set_transform(Vector2(0,hop))
	# Never crop or independently transform head, torso, hair, or feet.
	draw_texture_rect_region(texture,frame_rect(region),region)
	draw_set_transform(Vector2.ZERO)