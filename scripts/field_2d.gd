extends Node2D
## Every blocked cell has a solid visible footprint; roads use the collision grid.
const TILE := 16
const BASE := "res://assets/art_overhaul/2026-11-23/fields/style_c/runtime/"
var field: Node2D
var art := {}
var floors := {}
var prop_tiles := {}
var last_revision := -1
var infill: Array[Dictionary] = []
var cold_mix := {}
var floor_decals: Array[Dictionary] = []

func _ready() -> void:
	field = get_parent()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for kind in ["bakery","shop","house","warehouse","fountain","arch","crate","lamp","bench","tree","factory","workshop","servicehouse","junk","wall_dark","wall_warm","manhole","puddle","drain"]:
		art[kind] = load(BASE+kind+".png")
	for item in field.settings.decor:
		for y in range(int(item.y),int(item.y+item.h)):
			for x in range(int(item.x),int(item.x+item.w)):
				prop_tiles[Vector2i(x,y)] = true
	for kind in ["paving","cobble","asphalt","concrete","roof","water"]:
		floors[kind] = load(BASE+kind+".png")
	_build_surfaces()
	_build_infill()

func _build_surfaces() -> void:
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			var weight := 0.0
			var total := 0.0
			for dy in range(-3,4):
				for dx in range(-3,4):
					var k := exp(-float(dx*dx+dy*dy)/5.0)
					total += k
					if is_cold_area(tile+Vector2i(dx,dy)):
						weight += k
			cold_mix[tile] = weight/total
			if field.tile_kind(tile) != "." or not is_cold_area(tile):
				continue
			if x%7 == 2 and y%6 == 3:
				floor_decals.append({"kind":"manhole","rect":Rect2(Vector2(tile*TILE)+Vector2(2,2),Vector2(12,12))})
			elif (x*17+y*31)%47 == 0 and field.tile_kind(tile+Vector2i.RIGHT) == ".":
				floor_decals.append({"kind":"puddle","rect":Rect2(Vector2(tile*TILE),Vector2(30,13))})
			elif x%3 == 0 and field.tile_kind(tile+Vector2i.UP) == "#":
				floor_decals.append({"kind":"drain","rect":Rect2(Vector2(tile*TILE)+Vector2(2,1),Vector2(12,7))})

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
				var kind: String = ["factory","workshop","servicehouse"][(x+y)%3] if cold else ("house" if (x+y)%3 == 0 else "shop")
				if size.x == 2:
					kind = ("junk" if (x+y)%2 == 0 else "crate") if cold else "tree"
				infill.append({"kind":kind,"x":x,"y":y,"w":size.x,"h":size.y})
				for yy in range(y,y+size.y):
					for xx in range(x,x+size.x):
						occupied[Vector2i(xx,yy)] = true

func _process(_delta: float) -> void:
	if last_revision != field.lighting_revision:
		last_revision = field.lighting_revision
		queue_redraw()

func _surface(kind: String, tile: Vector2i, tint: Color = Color.WHITE) -> void:
	var at := Vector2(tile*TILE)
	# Eight-pixel stones match the actor scale; water keeps broader ripples.
	var period := 8 if kind == "water" else 4
	var sample_size: float = floors[kind].get_width()/float(period)
	var source := Rect2(posmod(tile.x,period)*sample_size,posmod(tile.y,period)*sample_size,sample_size,sample_size)
	draw_texture_rect_region(floors[kind],Rect2(at,Vector2(16,16)),source,tint)

func material_kind(tile: Vector2i) -> String:
	if field.tile_kind(tile) == "W":
		return "water"
	if field.tile_kind(tile) == "#":
		return "roof"
	return "asphalt" if is_cold_area(tile) else "paving"

func _road_surface(tile: Vector2i) -> void:
	var near_wall := false
	for side in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		near_wall = near_wall or field.tile_kind(tile+side) == "#"
	_surface("cobble" if near_wall else "paving",tile)
	var blend: float = cold_mix[tile]
	if blend > 0.001:
		_surface("concrete" if near_wall else "asphalt",tile,Color(1,1,1,blend))

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
	_surface("roof",tile,Color("aeb8be"))
	var wall: Texture2D = art.wall_dark if is_cold_area(tile) else art.wall_warm
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
			var source := Rect2(float(posmod(tile.x,4))*wall.get_width()/4.0,0,wall.get_width()/4.0,wall.get_height())
			draw_texture_rect_region(wall,edge,source)

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
			if kind == "water":
				_surface("water",tile)
			else:
				_road_surface(tile)
			if kind == "water":
				if field.tile_kind(tile+Vector2i.UP) == ".":
					draw_rect(Rect2(at,Vector2(16,3)),Color("91a6ae"))
					draw_rect(Rect2(at+Vector2(0,3),Vector2(16,2)),Color("263d48"))
				continue
			if kind == "lamp":
				draw_rect(Rect2(at,Vector2(16,16)),Color("263b4c"))
				draw_texture_rect(floors.concrete,Rect2(at+Vector2.ONE,Vector2(14,14)),false)
				draw_rect(Rect2(at+Vector2(3,3),Vector2(10,10)),Color(0.13,0.22,0.25,0.6))
	for decal in floor_decals:
		draw_texture_rect(art[decal.kind],decal.rect,false,Color(1,1,1,0.8))
	# Inlaid plaza rings are flat paving, not obstacles.
	var center := Vector2(22,39.5)*TILE
	for radius in [44,48,68,71]:
		draw_arc(center,radius,0,TAU,96,Color("b2a3a5") if radius%2 == 0 else Color("66596e"),1.0)
	for item in infill + field.settings.decor:
		var rect := Rect2(float(item.x)*TILE,float(item.y)*TILE,float(item.w)*TILE,float(item.h)*TILE)
		# Solid curb/plinth closes transparent sprite corners over blocked cells.
		draw_rect(rect,Color("263444"))
		draw_texture_rect(floors.concrete,rect.grow(-1),false)
		var kind: String = str(item.kind)
		if is_cold_area(Vector2i(int(item.x),int(item.y))):
			if kind == "warehouse":
				kind = "factory"
			elif kind == "house":
				kind = "servicehouse"
			elif kind == "shop":
				kind = "workshop"
		draw_texture_rect(art[kind],rect.grow(-1),false)
	for i in field.lamps.size():
		var at := Vector2(field.lamps[i]*TILE)+Vector2(8,8)
		draw_texture_rect(art.lamp,Rect2(at-Vector2(5,24),Vector2(10,28)),false,Color("b5bfc9") if not field.lit[i] else Color.WHITE)


