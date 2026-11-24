extends Node2D
## Dark districts conceal enemies, while blue lamp silhouettes remain visible.
var field: Node2D
var last_camera := Vector2.INF
var last_revision := -1
var last_siege := -1.0
var lamp_texture: Texture2D

func _ready() -> void:
	z_index = 2048
	lamp_texture = load("res://assets/tilesets/night_lamp.png")

func _process(_delta: float) -> void:
	var camera := get_canvas_transform().origin
	var siege := 0.0
	for symbol in field.symbols:
		siege += symbol.siege_time
	if camera != last_camera or last_revision != field.lighting_revision or siege != last_siege:
		last_camera = camera
		last_revision = field.lighting_revision
		last_siege = siege
		queue_redraw()

func _draw() -> void:
	if field == null:
		return
	var inverse := get_canvas_transform().affine_inverse()
	var corner: Vector2 = inverse * Vector2.ZERO
	var end: Vector2 = inverse * get_viewport_rect().size
	var first := Vector2i(maxi(0,floori(corner.x/16)-2),maxi(0,floori(corner.y/16)-2))
	var last := Vector2i(mini(field.width(),ceili(end.x/16)+2),mini(field.height(),ceili(end.y/16)+2))
	for y in range(first.y,last.y):
		for x in range(first.x,last.x):
			var tile := Vector2i(x,y)
			if not field.is_lit(tile):
				draw_rect(Rect2(Vector2(tile*16),Vector2(16,16)),Color("030713"))
	for i in field.lamps.size():
		var at := Vector2(field.lamps[i]*16)+Vector2(8,8)
		if not field.lit[i]:
			for ring in range(5,0,-1):
				draw_circle(at-Vector2(0,19),ring*2.5,Color(0.25,0.50,1.0,0.035))
			draw_texture_rect(lamp_texture,Rect2(at-Vector2(5,24),Vector2(10,28)),false,Color(0.25,0.48,0.85,0.75))
			draw_rect(Rect2(at-Vector2(2,23),Vector2(4,6)),Color("6e9fd4"))
	for symbol in field.symbols:
		if symbol.siege_area >= 0 and symbol.siege_time > 0:
			var at := Vector2(field.lamps[symbol.siege_area]*16)+Vector2(0,-22)
			draw_rect(Rect2(at,Vector2(16,2)),Color("2e2335"))
			draw_rect(Rect2(at,Vector2(16*symbol.siege_time/float(field.settings.lamp_break_seconds),2)),Color("e67d73"))
