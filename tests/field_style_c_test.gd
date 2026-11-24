extends SceneTree
const OUT := "res://assets/art_overhaul/2026-11-23/fields/style_c/review/"
var field: Node2D
var player: Node2D
var light: Node2D
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func capture(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	field = main.get_node("Field")
	player = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000
	for symbol in field.symbols:
		symbol.set_process(false)
	for child in field.get_children():
		if child.get_script() == load("res://scripts/field_darkness.gd"):
			light = child
	var town: Node2D = field.get_node("Town2D")
	var mismatch := 0
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			if (town.visual_kind(tile) != "road") != field.is_blocked(tile):
				mismatch += 1
	check(mismatch == 0,"Every blocked tile must have a visible obstacle category")
	var occupied := {}
	var bad_infill := 0
	for prop in town.infill:
		for y in range(int(prop.y),int(prop.y+prop.h)):
			for x in range(int(prop.x),int(prop.x+prop.w)):
				var tile := Vector2i(x,y)
				if field.tile_kind(tile) != "#" or town.prop_tiles.has(tile) or occupied.has(tile):
					bad_infill += 1
				occupied[tile] = true
	check(bad_infill == 0,"New buildings and trees never occupy a road or an existing object")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art_overhaul/2026-11-23/fields/style_c/metadata/night_layout_snapshot.json"))
	check(field.settings == snapshot,"Terrain, object coordinates and gameplay rules unchanged")
	check(town.material_kind(Vector2i(25,44)) == "paving","Warm plaza uses new stone material")
	check(town.material_kind(Vector2i(80,24)) == "asphalt","Dark alley actually uses asphalt, not shared plaza paving")
	check(town.floors.paving.resource_path.ends_with("/style_c/runtime/paving.png") and town.floors.asphalt.resource_path.ends_with("/style_c/runtime/asphalt.png"),"Both ground materials are new authored assets")
	check(town.art.factory.resource_path.ends_with("/style_c/runtime/factory.png") and not town.floor_decals.is_empty(),"Industrial architecture and road details are active")
	var area := 8
	var lamp: Vector2i = field.lamps[area]
	field.lit[area] = false
	var before: Color = light.raw_light(lamp)
	field.lit[area] = true
	var after: Color = light.raw_light(lamp)
	check(after.b > after.r*1.5,"Activated dark district stays blue")
	check(after.get_luminance() > before.get_luminance()*3,"Activation reveals terrain")
	check(after.get_luminance() < 0.8,"Activation never becomes daylight")
	field.lit[area] = false
	var mask: Image = light.build_light_image()
	var max_jump := 0.0
	for y in field.height()-1:
		for x in field.width()-1:
			var c := mask.get_pixel(x,y)
			max_jump = maxf(max_jump,absf(c.get_luminance()-mask.get_pixel(x+1,y).get_luminance()))
			max_jump = maxf(max_jump,absf(c.get_luminance()-mask.get_pixel(x,y+1).get_luminance()))
	check(max_jump < 0.16,"No hard single-tile illumination cut")
	print("OVERHAUL CHECKS: %d / %d passed; max neighbor brightness change %.3f" % [checks-failures,checks,max_jump])
	if DisplayServer.get_name() == "headless":
		main.free()
		quit(failures)
		return
	player.warp_to(Vector2i(25,44))
	await capture("01-plaza")
	player.warp_to(field.object_edges(lamp).back())
	field.lighting_revision += 1
	light._process(1.0)
	await capture("02-dark-off")
	field.lit[area] = true
	field.lighting_revision += 1
	light._process(1.0)
	await capture("03-dark-on")
	field.lit[area] = false
	field.lighting_revision += 1
	light._process(1.0)
	player.warp_to(Vector2i(66,23))
	await capture("04-boundary")
	var industrial := 9
	var industrial_lit: bool = field.lit[industrial]
	player.warp_to(Vector2i(103,10))
	field.lit[industrial] = false
	field.lighting_revision += 1
	light._process(1.0)
	await capture("06-industrial-off")
	field.lit[industrial] = true
	field.lighting_revision += 1
	light._process(1.0)
	await capture("07-industrial-on")
	field.lit[industrial] = industrial_lit
	field.lighting_revision += 1
	light._process(1.0)
	field.hud.set_process(false)
	field.hud.hide()
	var camera: Camera2D = player.get_node("Camera2D")
	camera.reparent(main)
	camera.limit_left = -4096
	camera.limit_top = -4096
	camera.limit_right = 8192
	camera.limit_bottom = 8192
	camera.position = Vector2(1024,512)
	camera.zoom = Vector2(0.125,0.125)
	await capture("05-overview")
	main.free()
	quit(failures)


