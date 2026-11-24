extends Node2D
## Every blocked cell has a solid visible footprint; roads use the collision grid.
const TILE := 16
const BASE := "res://assets/art_overhaul/2026-11-23/fields/v002/runtime/"
var field: Node2D
var art := {}
var floors := {}
var prop_tiles := {}
var last_revision := -1
var infill: Array[Dictionary] = []

func _ready() -> void:
	field = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for kind in ["bakery","shop","house","warehouse","fountain","arch","crate","lamp","bench","tree"]:
		art[kind] = load(BASE+kind+".png")
	for item in field.settings.decor:
		for y in range(int(item.y),int(item.y+item.h)):
			for x in range(int(item.x),int(item.x+item.w)):
				prop_tiles[Vector2i(x,y)] = true
	for kind in ["paving","asphalt","wall","water"]:
		floors[kind] = _ground_texture(kind)
	_build_infill()

func _build_infill() -> void:
	var occupied := prop_tiles.duplicate()
	# Fit art ONLY into already blocked rectangles beside existing streets.
	# No collision or route is changed to accommodate the new art.
	for size in [Vector2i(5,4),Vector2i(4,3),Vector2i(2,2)]:
		for y in range(1,field.height()-size.y):
			for x in range(1,field.width()-size.x):
				var fits := true
				var street := false
				for yy in range(y,y+size.y):
					for xx in range(x,x+size.x):
						var tile := Vector2i(xx,yy)
						if field.tile_kind(tile) != "#" or occupied.has(tile):
							fits = false
							break
					if not fits:
						break
				if not fits:
					continue
				for dx in range(-1,size.x+1):
					street = street or field.tile_kind(Vector2i(x+dx,y-1)) == "." or field.tile_kind(Vector2i(x+dx,y+size.y)) == "."
				for dy in size.y:
					street = street or field.tile_kind(Vector2i(x-1,y+dy)) == "." or field.tile_kind(Vector2i(x+size.x,y+dy)) == "."
				if not street:
					continue
				var cold := is_cold_area(Vector2i(x,y))
				var kind := "warehouse" if cold else ("house" if (x+y)%3 == 0 else "shop")
				if size.x == 2:
					kind = "crate" if cold else "tree"
				infill.append({"kind":kind,"x":x,"y":y,"w":size.x,"h":size.y})
				for yy in range(y,y+size.y):
					for xx in range(x,x+size.x):
						occupied[Vector2i(xx,yy)] = true

func _process(_delta: float) -> void:
	if last_revision != field.lighting_revision:
		last_revision = field.lighting_revision
		queue_redraw()

func _ground_texture(kind: String) -> ImageTexture:
	var pixels := Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var noise := (x*17+y*43+x*y*3)%97
			var base := Color("95859b")
			var seam := y%8 == 0 or (x+(8 if (y/8)%2 else 0))%16 == 0
			var color := base.darkened(0.28) if seam else base
			if y%8 == 1 and not seam:
				color = base.lightened(0.13)
			elif noise < 12 and not seam:
				color = base.lightened(0.06)
			if kind == "asphalt":
				color = Color("687787").lightened(0.06) if noise < 15 else Color("687787")
				if (x*3+y*2)%31 == 0:
					color = Color("465465")
			elif kind == "wall":
				color = Color("44546b")
				if y%8 == 0 or (x+(8 if (y/8)%2 else 0))%16 == 0:
					color = Color("2d3b50")
				elif y%8 == 1:
					color = Color("5c6d85")
			elif kind == "water":
				color = Color("246c7b") if (y+x/4)%9 == 0 else Color("204452")
				if (x+y*3)%29 < 3:
					color = Color("438f9a")
			pixels.set_pixel(x,y,color)
	return ImageTexture.create_from_image(pixels)

func visual_kind(tile: Vector2i) -> String:
	if field.tile_kind(tile) == "W":
		return "water"
	if field.tile_kind(tile) == "L":
		return "lamp"
	if field.tile_kind(tile) == "#":
		return "prop" if prop_tiles.has(tile) else "wall"
	return "road"

func is_cold_area(tile: Vector2i) -> bool:
	var area: int = field.area_at(tile)
	return str(field.settings.areas[area].kind) in ["alley","lot","warehouse","yard","workshop"] or field.settings.initial_dark_areas.has(float(area))

func _solid_block(tile: Vector2i,at: Vector2) -> void:
	draw_texture_rect(floors.wall,Rect2(at,Vector2(16,16)),false)
	# Raised parapets meet the exact occupied-cell boundary, not a hidden wall.
	for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var neighbor: Vector2i = tile+side
		if field.tile_kind(neighbor) in [".","L","W"]:
			var edge := Rect2(at,Vector2(16,3))
			if side == Vector2i.DOWN:
				edge = Rect2(at+Vector2(0,10),Vector2(16,6))
			elif side == Vector2i.LEFT:
				edge = Rect2(at,Vector2(3,16))
			elif side == Vector2i.RIGHT:
				edge = Rect2(at+Vector2(13,0),Vector2(3,16))
			draw_rect(edge,Color("202d41"))
			draw_rect(Rect2(edge.position,Vector2(edge.size.x,1)),Color("9eacba"))

func _draw() -> void:
	if field == null or art.is_empty():
		return
	draw_rect(Rect2(-4096,-4096,12288,12288),Color("111c30"))
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			var at := Vector2(tile*TILE)
			var kind := visual_kind(tile)
			if kind == "wall":
				_solid_block(tile,at)
				continue
			var cold := is_cold_area(tile)
			# Base paving is continuous across gameplay ownership borders.
			draw_texture_rect(floors.water if kind == "water" else floors.paving,Rect2(at,Vector2(16,16)),false)
			if kind == "water":
				if field.tile_kind(tile+Vector2i.UP) == ".":
					draw_rect(Rect2(at,Vector2(16,3)),Color("91a6ae"))
					draw_rect(Rect2(at+Vector2(0,3),Vector2(16,2)),Color("263d48"))
				continue
			if cold and kind == "road" and (x*7+y*11)%23 == 0:
				draw_line(at+Vector2(3,5),at+Vector2(7,9),Color("4c586e"))
				draw_line(at+Vector2(7,9),at+Vector2(12,7),Color("4c586e"))
			if kind == "lamp":
				draw_rect(Rect2(at,Vector2(16,16)),Color("263b4c"))
				draw_rect(Rect2(at+Vector2(1,1),Vector2(14,14)),Color("8c9b9e"))
				draw_rect(Rect2(at+Vector2(3,3),Vector2(10,10)),Color("4a626b"))
	# Inlaid plaza rings are flat paving, not obstacles.
	var center := Vector2(22,39.5)*TILE
	for radius in [44,48,68,71]:
		draw_arc(center,radius,0,TAU,96,Color("b2a3a5") if radius%2 == 0 else Color("66596e"),1.0)
	for item in infill + field.settings.decor:
		var rect := Rect2(float(item.x)*TILE,float(item.y)*TILE,float(item.w)*TILE,float(item.h)*TILE)
		# Solid curb/plinth closes transparent sprite corners over blocked cells.
		draw_rect(rect,Color("263444"))
		draw_rect(Rect2(rect.position+Vector2.ONE,rect.size-Vector2(2,2)),Color("687c89"))
		draw_rect(Rect2(rect.position+Vector2(1,1),Vector2(rect.size.x-2,2)),Color("a9b6b6"))
		draw_texture_rect(art[str(item.kind)],rect.grow(-2),false)
	for i in field.lamps.size():
		var at := Vector2(field.lamps[i]*TILE)+Vector2(8,8)
		draw_texture_rect(art.lamp,Rect2(at-Vector2(5,24),Vector2(10,28)),false,Color("b5bfc9") if not field.lit[i] else Color.WHITE)

