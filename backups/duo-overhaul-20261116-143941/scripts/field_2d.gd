extends Node2D
## Orthogonal city; props and buildings share authored collision footprints.
const TILE := 16
var field: Node2D
var art := {}
var floors := {}
var last_revision := -1
var prop_tiles := {}

func _ready() -> void:
	field = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for kind in ["bakery","shop","house","warehouse","fountain","arch","crate","lamp","bench"]:
		art[kind] = load("res://assets/tilesets/night_%s.png" % kind)
	for item in field.settings.decor:
		for y in range(int(item.y),int(item.y+item.h)):
			for x in range(int(item.x),int(item.x+item.w)):
				prop_tiles[Vector2i(x,y)] = true
	for kind in ["plaza","bakery","market","quay","arcade","alley","lot","warehouse","yard","bridge","workshop","gate","wall","water"]:
		floors[kind] = _ground_texture(kind)

func _process(_delta: float) -> void:
	if last_revision != field.lighting_revision:
		last_revision = field.lighting_revision
		queue_redraw()

func _ground_texture(kind: String) -> ImageTexture:
	var pixels := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var base := Color("41485f")
	if kind in ["plaza","arcade","bridge"]:
		base = Color("4c5065")
	elif kind in ["bakery","market","gate"]:
		base = Color("55536a")
	elif kind in ["lot","yard"]:
		base = Color("454751")
	elif kind == "wall":
		base = Color("222d43")
	elif kind == "water":
		base = Color("173947")
	elif kind == "quay":
		base = Color("3d5362")
	for y in 32:
		for x in 32:
			var n := (x*17+y*43+x*y*3)%97
			var seam := y%8 == 0 or (x+(8 if (y/8)%2 else 0))%16 == 0
			var color := base.darkened(0.23) if seam else base
			if n < 8 and not seam:
				color = base.lightened(0.07)
			elif n > 92:
				color = base.darkened(0.08)
			if kind == "water":
				color = base.lightened(0.12) if (y+x/4)%9 == 0 else base
			if kind in ["lot","yard"]:
				color = base.lightened(0.12) if n < 6 else base.darkened(0.14) if n > 90 else base
			pixels.set_pixel(x,y,color)
	return ImageTexture.create_from_image(pixels)

func _draw() -> void:
	if field == null or art.is_empty():
		return
	draw_rect(Rect2(-4096,-4096,12288,12288),Color("111c30"))
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			var at := Vector2(tile*TILE)
			var blocked: bool = field.tile_kind(tile) == "#" and not prop_tiles.has(tile)
			var kind: String = "water" if field.tile_kind(tile) == "W" else "wall" if blocked else str(field.settings.areas[field.area_at(tile)].kind)
			draw_texture_rect(floors[kind],Rect2(at,Vector2(16,16)),false)
			if not blocked:
				for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
					if field.tile_kind(tile+side) == "#" and not prop_tiles.has(tile+side):
						var edge := Rect2(at,Vector2(16,1)) if side == Vector2i.UP else Rect2(at+Vector2(0,15),Vector2(16,1)) if side == Vector2i.DOWN else Rect2(at,Vector2(1,16)) if side == Vector2i.LEFT else Rect2(at+Vector2(15,0),Vector2(1,16))
						draw_rect(edge,Color("85849a"))
			elif field.tile_kind(tile+Vector2i.DOWN) == ".":
				draw_rect(Rect2(at+Vector2(0,9),Vector2(16,7)),Color("303849"))
				draw_line(at+Vector2(0,9),at+Vector2(16,9),Color("656678"),0.5)
				if x%3 == 0:
					draw_rect(Rect2(at+Vector2(5,10),Vector2(5,4)),Color("a58457"))
					draw_line(at+Vector2(7,10),at+Vector2(7,14),Color("353147"),0.5)
	var center := Vector2(18.5,40)*TILE
	draw_arc(center,63,0,TAU,64,Color("8c8790"),1)
	draw_arc(center,66,0,TAU,64,Color("333b52"),1)
	for item in field.settings.decor:
		var rect := Rect2(float(item.x)*TILE,float(item.y)*TILE,float(item.w)*TILE,float(item.h)*TILE)
		draw_texture_rect(art[str(item.kind)],rect,false,Color("c3c6e1"))
	for i in field.lamps.size():
		var at := Vector2(field.lamps[i]*TILE)+Vector2(8,8)
		if field.lit[i]:
			for ring in range(7,0,-1):
				draw_circle(at,ring*5,Color(1.0,0.78,0.38,0.017))
		draw_texture_rect(art.lamp,Rect2(at-Vector2(5,24),Vector2(10,28)),false)
