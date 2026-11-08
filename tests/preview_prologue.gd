extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art-reviews/prologue/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://art-reviews/prologue")
	var menu: Control = load("res://scenes/menu/title.tscn").instantiate()
	root.add_child(menu)
	await capture("menu")
	menu.free()
	var story: Control = load("res://scenes/prologue/prologue.tscn").instantiate()
	root.add_child(story)
	story.set_process(false)
	story.advance_time(20)
	await capture("narration")
	for i in 80:
		if story.completed:
			break
		if story.waiting_for_text:
			story.advance_time(20)
			if story.event_index == 4:
				await capture("long-narration")
			if story.event_index == 9:
				await capture("field")
			if story.event_index == 13:
				await capture("dialogue")
			if story.event_index == 24:
				await capture("chains")
			story.advance_dialogue()
		else:
			if story.current.type == "rush":
				story.advance_time(0.4)
				await capture("rush")
			story.advance_time(10)
	await capture("ending")
	quit()
