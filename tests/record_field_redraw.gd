extends SceneTree
const OUT := "res://.godot/field-redraw-walk"
var frame_number := 0
var player: Node2D

func _initialize() -> void:
	call_deferred("run")

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/%04d.png" % frame_number)
	frame_number+=1

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node2D=load("res://scenes/main/main.tscn").instantiate()
	main.get_node("Field").test_grid=true
	root.add_child(main)
	await process_frame
	var tutorial:=root.get_node("Tutorial")
	tutorial.enabled=false
	tutorial.active=false
	tutorial.view.hide()
	paused=false
	main.get_node("Field").set_process(false)
	player=main.get_node("Player")
	player.set_process(false)
	root.get_node("EncounterManager").balance.encounter.safe_steps=1000
	player.warp_to(Vector2i(5,5))
	player.follower_grid=Vector2i(4,5)
	player.follower.position=Vector2(player.follower_grid*16)
	var camera: Camera2D=player.get_node("Camera2D")
	camera.top_level=true
	camera.position=Vector2(144,112)
	for i in 20:
		await capture()
	var seen: Dictionary={}
	for segment in [["right",6],["down",3],["left",6],["up",3]]:
		var action: String="ui_"+segment[0]
		Input.action_press(action)
		player._try_input_step()
		for sample in int(segment[1])*12:
			if sample==int(segment[1])*12-1:
				Input.action_release(action)
			player._advance_step(0.020001)
			if sample<int(segment[1])*12-1:
				assert(player.sprite.current_frame in [0,1,2],"Walking stays within the three complete new poses")
				seen[player.sprite.current_frame]=true
			await capture()
		assert(not player._moving)
	assert(seen.size()==3,"Held movement alternates both foot contacts through the neutral passing pose")
	assert(player.extra_followers.is_empty())
	for i in 20:
		await capture()
	print("FIELD REDRAW RECORD: ",frame_number," unmodified game frames, 20ms cadence; classic held-input walking passed")
	quit()
