extends "res://tests/new_party_test.gd"

func run() -> void:
	manager = root.get_node("EncounterManager")
	var screen := battle()
	screen.hero_index = 1
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	var cast = screen.assassin_cast
	screen.advance(0.65)
	check(cast.stage == cast.Stage.VANISH,"Morph proceeds straight to vanish with no cut-in")
	screen.advance(0.24)
	check(cast.is_qte(),"First QTE opens immediately after vanish")
	var standing_height: float = 162*screen.ACTOR_SCALE
	for pose in [0,7,8,9,10,11,12,13,14,15]:
		var region: Rect2 = cast.actor_region(pose)
		var image: Image = cast.texture.get_image().get_region(Rect2i(region))
		var rendered: Rect2 = cast.actor_rect(pose,screen.HERO_POS[1],screen.ACTOR_SCALE)
		var top := image.get_height()
		var bottom := 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a >= 0.5:
					top = mini(top,y)
					bottom = maxi(bottom,y)
		var height := (bottom-top+1)*rendered.size.y/region.size.y
		check(height <= standing_height*1.08,"Returning and reaction poses cannot grow beyond ordinary battle height")
	for strike in 4:
		cast.elapsed = Screen.Rules.position_marker(screen.foe_position(0).y)*float(screen.balance.assassin.qte_duration)
		cast.press()
		screen.advance(0.28)
	check(cast.stage == cast.Stage.RETURN and cast.marked.size() == 4,"All four positional strikes still resolve before return")
	screen.advance(0.28)
	check(cast.stage == cast.Stage.YAWN,"Successful return retains yawn")
	screen.queue_redraw()
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/preview-assassin-return-fixed.png")
	screen.advance(1.0)
	screen.advance(0.9)
	screen.advance(0.3)
	check(cast.stage == cast.Stage.DONE,"Skill still finishes normally after delayed slashes")
	screen.free()
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000
	check(not field.settings.lamp_break_enabled,"Prototype ships with lamp destruction disabled")
	var before: Array = field.lit.duplicate()
	for area in field.lamps.size():
		field._extinguish(area,player)
	check(field.lit == before,"Direct extinguish attempts preserve initial lit and dark states")
	var area: int = field.lit.find(true)
	var enemy: Node2D = field._spawn_symbol(field.object_edges(field.lamps[area])[0])
	enemy.siege_time = 100
	enemy.siege_area = area
	field._process(12)
	check(field.lit == before,"Enemy at a lamp cannot darken any district past old break threshold")
	check(enemy.siege_time == 0 and enemy.siege_area == -1,"Disabled siege clears progress and its indicator")
	var dark: int = field.lit.find(false)
	check(field.repair_lamp(dark,player),"Initially dark lamps can still be lit normally")
	field._extinguish(dark,player)
	check(field.lit[dark],"Newly repaired lamp also remains lit")
	main.free()
	print("PROTOTYPE FIXES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
