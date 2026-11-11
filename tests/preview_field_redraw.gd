extends SceneTree
const OUT := "res://art-reviews/field-redraw"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.content_scale_size = Vector2i(768,672)
	var gallery := Node2D.new()
	root.add_child(gallery)
	var backdrop := ColorRect.new()
	backdrop.color = Color("354352")
	backdrop.size = Vector2(768,672)
	gallery.add_child(backdrop)
	for hero in 2:
		var id: String = ["chuheun","yeonwoo"][hero]
		for row in 4:
			for pose in 3:
				var actor: Node2D = load("res://scripts/field_actor.gd").new()
				actor.configure(load("res://assets/sprites/field/"+id+"_night.png"))
				actor.facing = ["down","left","right","up"][row]
				actor.position = Vector2(24+hero*384+pose*112,48+row*148)
				actor.scale = Vector2(6,6)
				gallery.add_child(actor)
				if pose > 0:
					actor.step_pose = 2-pose
					actor.begin_step()
					actor.set_step_progress(0.5)
				var label := Label.new()
				label.position = actor.position+Vector2(0,102)
				label.text = "%s / %s" % [["DOWN","LEFT","RIGHT","UP"][row],["IDLE","STEP 1","STEP 2"][pose]]
				label.add_theme_font_size_override("font_size",12)
				gallery.add_child(label)
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/all-directions.png")
	gallery.free()
	root.content_scale_size = Vector2i(256,224)
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	main.get_node("Field").test_grid = true
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	var player: Node2D = main.get_node("Player")
	player.set_process(false)
	main.get_node("Field").set_process(false)
	root.get_node("EncounterManager").balance.encounter.safe_steps = 1000
	player.grid_pos = Vector2i(7,6)
	player.position = Vector2(player.grid_pos*16)
	player.follower_grid = Vector2i(6,6)
	player.follower.position = Vector2(player.follower_grid*16)
	for direction in ["right","down","left","up"]:
		for stride in 2:
			player._move_to(player.grid_pos+player.DIR_VECTOR[direction])
			assert(player._moving,"Preview route must exercise real movement")
			for sample in 12:
				player._advance_step(player.MOVE_TIME/12.0)
				if sample == 5:
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OUT+"/walk-%s-%d.png" % [direction,stride])
			if player._moving:
				player._advance_step(0.0001)
	main.free()
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.get_node("Player").set_process(false)
	main.get_node("Field").set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/field.png")
	main.free()
	print("FIELD ART PREVIEW: 24 whole-body poses and 8 real movement midpoints")
	quit()
