extends SceneTree
const OUT = "res://assets/art_overhaul/2026-11-23/fields/style_c/review/"
func _initialize():
	call_deferred("run")
func capture(name):
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run():
	root.get_node("StoryRouter").open_scene(root.get_node("StoryRouter").TUTORIAL)
	for i in 6: await process_frame
	assert(current_scene.scene_file_path == "res://scenes/main/main.tscn")
	var main = current_scene
	var tutorial = root.get_node("Tutorial")
	assert(tutorial.active)
	tutorial.active = false
	tutorial.enabled = false
	tutorial.view.hide()
	paused = false
	var field = main.get_node("Field")
	var player = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	for symbol in field.symbols: symbol.set_process(false)
	assert(player.sprite.texture.resource_path.contains("/field_c/"))
	assert(player.follower.texture.resource_path.contains("/field_c/"))
	assert(field.get_node("Town2D").art.shop.resource_path.contains("/style_c/"))
	assert(preload("res://scripts/battle/renewed_actor.gd").ROOT.ends_with("/v003/"))
	if DisplayServer.get_name() != "headless":
		player.warp_to(Vector2i(43,42))
		player.follower_grid = Vector2i(41,42)
		player.follower.position = Vector2(player.follower_grid*16)
		player.sprite.facing = "down"
		player.follower.facing = "down"
		await capture("08-style-c-street")
		for f in 24:
			player.sprite.walking = true
			player.follower.walking = true
			player.sprite.step_pose = (f/6)%2
			player.follower.step_pose = 1-(f/6)%2
			player.sprite.set_step_progress(float(f%6)/6.0)
			player.follower.set_step_progress(float(f%6)/6.0)
			await capture("walk-%02d"%f)
	print("REGISTERED TUTORIAL: C party + C map, battle rolled back to v003")
	quit()
