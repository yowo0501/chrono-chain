extends RefCounted
## Shared authored atlas for ordinary enemies and every tutorial slime size.
const ATLAS = preload("res://assets/enemies/night_slime/slime-atlas.png")
const SHADOW = preload("res://assets/sprites/battle/ground-shadow.svg")
const BattleLayout = preload("res://scripts/battle/battle_layout.gd")
static var anchors: Array[Vector2] = []

static func region_for(frame: int) -> Rect2i:
	var cell := ATLAS.get_size()/4.0
	var grid := Vector2(frame%4,frame/4)
	var start := Vector2i((grid*cell).round())
	var end := Vector2i(((grid+Vector2.ONE)*cell).round())
	return Rect2i(start,end-start)

static func prepare_anchors() -> void:
	if not anchors.is_empty(): return
	var image := ATLAS.get_image()
	for frame in 16:
		var region := region_for(frame)
		var origin := region.position
		var cell := region.size
		var left := cell.x
		var right := 0
		var bottom := 0
		for y in cell.y:
			for x in cell.x:
				if image.get_pixelv(origin+Vector2i(x,y)).a < 0.4: continue
				left = mini(left,x)
				right = maxi(right,x)
				bottom = maxi(bottom,y+1)
		anchors.append(Vector2((left+right)/2.0,bottom)/Vector2(cell))

static func frame_for(state: String, time: float, rear: bool = false) -> int:
	if rear:
		return 14 + (int(time * 8.0) % 2 if state == "move" else 0)
	match state:
		"move": return 4 + int(time * 10.0) % 4
		"windup": return 8
		"attack": return 8 + clampi(int(time * 8.0), 1, 3)
		"hit": return 12 + clampi(int(time * 7.0), 0, 1)
		"defeat": return 12
	return int(time * 5.0) % 4

static func draw_actor(canvas: CanvasItem, foot: Vector2, width: float, state: String, time: float, facing: String = "left", tint: Color = Color.WHITE, shadow: bool = true, bounds: Rect2 = Rect2()) -> void:
	prepare_anchors()
	var frame := frame_for(state, time, facing.begins_with("up"))
	var region := region_for(frame)
	var cell := Vector2(region.size)
	var size := Vector2(width,width*cell.y/cell.x)
	if state == "defeat":
		size.y *= maxf(0.12, 1.0 - time)
		tint.a *= clampf(1.0-time/0.8,0.0,1.0)
	if shadow:
		var shadow_size := Vector2(width*0.62,width*0.12)
		_draw_texture(canvas,SHADOW,Rect2(foot-shadow_size/2,shadow_size),Rect2(Vector2.ZERO,SHADOW.get_size()),Color(1,1,1,tint.a),bounds)
	var anchor := anchors[frame]
	if facing.ends_with("right"): anchor.x = 1.0-anchor.x
	var rect := Rect2(foot-size*anchor,size)
	if facing.ends_with("right"):
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	_draw_texture(canvas,ATLAS,rect,Rect2(region),tint,bounds)

static func _draw_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, region: Rect2, tint: Color, bounds: Rect2) -> void:
	if bounds.has_area():
		BattleLayout.draw_sprite(canvas,texture,rect,region,tint,bounds)
	else:
		canvas.draw_texture_rect_region(texture,rect,region,tint)
