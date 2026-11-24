extends Node2D
## Continuous world-space illumination; gameplay area ownership stays discrete.
const BASE := "res://assets/art_overhaul/2026-11-23/fields/style_c/runtime/"
const FADE_SECONDS := 0.8
const BLUR_RADIUS := 4
var field: Node2D
var last_revision := -1
var lamp_texture: Texture2D
var mask: Sprite2D
var light_material: ShaderMaterial
var current_image: Image
var previous_image: Image
var fade := 1.0

func _ready() -> void:
	z_index = 2048
	lamp_texture = load(BASE+"lamp.png")
	mask = Sprite2D.new()
	mask.centered = false
	mask.show_behind_parent = true
	mask.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light_material = ShaderMaterial.new()
	light_material.shader = load("res://assets/shaders/field_lighting.gdshader")
	mask.material = light_material
	add_child(mask)
	_refresh(true)

func is_cold_area(area: int) -> bool:
	return str(field.settings.areas[area].kind) in ["alley","lot","warehouse","yard","workshop"] or field.settings.initial_dark_areas.has(float(area))

func raw_light(tile: Vector2i) -> Color:
	var area: int = field.area_at(tile)
	var distance := Vector2(tile).distance_to(Vector2(field.lamps[area]))
	var pool := exp(-distance*distance/32.0)
	if not field.lit[area]:
		return Color(0.10,0.15,0.24)
	if is_cold_area(area):
		return Color(0.28,0.43,0.65).lerp(Color(0.49,0.76,0.98),pool)
	return Color(0.78,0.74,0.79).lerp(Color(1.0,0.93,0.82),pool)

func build_light_image() -> Image:
	var w: int = field.width()
	var h: int = field.height()
	var source := Image.create(w,h,false,Image.FORMAT_RGBA8)
	var horizontal := Image.create(w,h,false,Image.FORMAT_RGBA8)
	var result := Image.create(w,h,false,Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			source.set_pixel(x,y,raw_light(Vector2i(x,y)))
	# Gaussian separable blur spans nine tiles, removing ownership-shaped cuts.
	for y in h:
		for x in w:
			var sum := Color(0,0,0,0)
			var weight := 0.0
			for offset in range(-BLUR_RADIUS,BLUR_RADIUS+1):
				var k := exp(-float(offset*offset)/8.0)
				sum += source.get_pixel(clampi(x+offset,0,w-1),y)*k
				weight += k
			horizontal.set_pixel(x,y,sum/weight)
	for y in h:
		for x in w:
			var sum := Color(0,0,0,0)
			var weight := 0.0
			for offset in range(-BLUR_RADIUS,BLUR_RADIUS+1):
				var k := exp(-float(offset*offset)/8.0)
				sum += horizontal.get_pixel(x,clampi(y+offset,0,h-1))*k
				weight += k
			result.set_pixel(x,y,sum/weight)
	return result

func _refresh(initial: bool = false) -> void:
	# Continue from the displayed state if another lamp changes during the fade.
	var next := build_light_image()
	if initial:
		previous_image = next
		fade = 1.0
	else:
		var blended := current_image.duplicate() as Image
		var t := smoothstep(0.0,1.0,fade)
		for y in blended.get_height():
			for x in blended.get_width():
				blended.set_pixel(x,y,previous_image.get_pixel(x,y).lerp(current_image.get_pixel(x,y),t))
		previous_image = blended
		fade = 0.0
	current_image = next
	mask.texture = ImageTexture.create_from_image(current_image)
	mask.scale = Vector2(16,16)
	light_material.set_shader_parameter("old_light",ImageTexture.create_from_image(previous_image))
	light_material.set_shader_parameter("transition",fade)
	last_revision = field.lighting_revision
	queue_redraw()

func _process(delta: float) -> void:
	if last_revision != field.lighting_revision:
		_refresh()
	if fade < 1.0:
		fade = minf(1.0,fade+delta/FADE_SECONDS)
		light_material.set_shader_parameter("transition",fade)
		queue_redraw()

func _draw() -> void:
	if field == null:
		return
	for i in field.lamps.size():
		var at := Vector2(field.lamps[i]*16)+Vector2(8,8)
		var bulb := at+Vector2(3,-14)
		var cold := is_cold_area(i)
		var color := Color("75caff") if cold else Color("ffcd77")
		if not field.lit[i]:
			# A small unpowered locator, not the wide pool of an activated lamp.
			draw_circle(bulb,3,Color(0.24,0.43,0.67,0.18))
			draw_rect(Rect2(bulb-Vector2(1,2),Vector2(2,3)),Color("58778e"))
		else:
			var strength := smoothstep(0.0,1.0,fade)
			for ring in range(6,0,-1):
				draw_circle(at,ring*7,Color(color,0.018*strength))
			draw_rect(Rect2(bulb-Vector2(2,2),Vector2(4,4)),Color(color,0.5+strength*0.5))
			draw_rect(Rect2(bulb-Vector2(1,1),Vector2(2,2)),Color("e2f6ff") if cold else Color("fff0bc"))
	for symbol in field.symbols:
		if symbol.siege_area >= 0 and symbol.siege_time > 0:
			var at := Vector2(field.lamps[symbol.siege_area]*16)+Vector2(0,-22)
			draw_rect(Rect2(at,Vector2(16,2)),Color("2e2335"))
			draw_rect(Rect2(at,Vector2(16*symbol.siege_time/float(field.settings.lamp_break_seconds),2)),Color("e67d73"))

