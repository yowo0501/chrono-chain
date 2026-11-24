extends Node2D
## Native fixed-cell atlas: neither source cropping nor scaling changes per pose.
var texture: Texture2D
var facing := "down"
var walking := false
var dashing := false
var stride_progress := 0.0
var action_progress := 1.0
var action_lean := 0.0
var action_offset := Vector2.ZERO
var step_pose := 0
var current_frame := 0
var z_base := 0
var regions: Array[Rect2] = []
var chain_texture: Texture2D
var chain_anchors: Array = []
var chain_frame := 0
const TILE_SIZE := preload("res://scripts/field.gd").TILE_SIZE
const FRAME_SIZE := 64
const DIRECTIONS := {"down":0,"down_left":1,"left":1,"up_left":1,"up":3,"up_right":2,"right":2,"down_right":2}

func configure(source: Texture2D) -> void:
	assert(source.get_size() == Vector2(FRAME_SIZE * 3, FRAME_SIZE * 4), "Field sprites require a 3x4 atlas of 64px frames")
	texture = source
	if source.resource_path.ends_with("chuheun_night.png"):
		chain_texture = load("res://assets/sprites/field-chain/chuheun.png")
		chain_anchors = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/field-chain/anchors.json"))
	regions.clear()
	for row in 4:
		for column in 3:
			regions.append(Rect2(Vector2(column, row) * FRAME_SIZE, Vector2.ONE * FRAME_SIZE))
	queue_redraw()

func begin_step() -> void:
	action_progress = 1.0
	step_pose = 1 - step_pose
	walking = true
	set_step_progress(0.0)

func set_step_progress(progress: float) -> void:
	stride_progress = progress
	# One stride per tile: pass through neutral, extend one foot, then plant it.
	current_frame = step_pose + 1 if progress >= 0.20 and progress < 0.80 else 0
	queue_redraw()

func end_step() -> void:
	action_progress = 1.0
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
	if chain_texture != null and action_progress < 1.0:
		# Authored arm/torso poses; no simulated lean or split-body replacement.
		draw_texture_rect_region(chain_texture,Rect2(-4,-6.5,24,24),Rect2(chain_frame*96,direction*96,96,96))
		return
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

func set_chain_progress(progress: float) -> void:
	action_progress = progress
	chain_frame = mini(5,int(progress*6.0))
	current_frame = 0
	queue_redraw()

func chain_socket() -> Vector2:
	if chain_anchors.is_empty():
		return Vector2(8,10)
	var tip: Array = chain_anchors[int(DIRECTIONS[facing])*6+chain_frame].tip
	return Vector2(-4,-6.5)+Vector2(tip[0],tip[1])*0.25
