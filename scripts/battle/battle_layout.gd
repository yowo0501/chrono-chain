extends RefCounted
## 768x672 design coordinates. UI starts at y=506; actors stop at y=484.
const ARENA := Rect2(24,104,720,380)
## Ground anchors stay on paving; the lowest slot reserves room for shadows/HP.
const ENEMY_FEET := Rect2(460,300,170,140)

static func enemy_foot(point: Vector2) -> Vector2:
	return point.clamp(ENEMY_FEET.position,ENEMY_FEET.end)

static func clipped_regions(destination: Rect2, source: Rect2, bounds: Rect2 = ARENA) -> Array[Rect2]:
	var original := destination.abs()
	var visible := original.intersection(bounds)
	if not visible.has_area() or not original.has_area(): return []
	var flipped_x := destination.size.x < 0
	var flipped_y := destination.size.y < 0
	var offset := visible.position-original.position
	if flipped_x: offset.x = original.end.x-visible.end.x
	if flipped_y: offset.y = original.end.y-visible.end.y
	var ratio := source.size/original.size
	var cropped := Rect2(source.position+offset*ratio,visible.size*ratio)
	if flipped_x:
		visible.position.x += visible.size.x
		visible.size.x = -visible.size.x
	if flipped_y:
		visible.position.y += visible.size.y
		visible.size.y = -visible.size.y
	return [visible,cropped]

static func draw_sprite(canvas: CanvasItem, texture: Texture2D, destination: Rect2, source: Rect2, tint: Color = Color.WHITE, bounds: Rect2 = ARENA) -> void:
	var regions := clipped_regions(destination,source,bounds)
	if regions.is_empty(): return
	canvas.draw_texture_rect_region(texture,regions[0],regions[1],tint)
