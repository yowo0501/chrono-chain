extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	main.get_node("Field").test_grid = true
	root.add_child(main)
	await process_frame
	# This movement fixture drives input itself, independently of onboarding.
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	var player = main.get_node("Player")
	var manager = root.get_node("EncounterManager")
	manager.balance.encounter.safe_steps = 1000
	player.set_process(false)
	assert(player.follower_grid == Vector2i(10, 5))
	assert(player.TILE_SIZE == player.field.TILE_SIZE)
	assert(not player.field.is_blocked(Vector2i(3, 4)))
	assert(player.field.is_blocked(Vector2i(-1, 6)))
	for actor in [player.sprite, player.follower]:
		assert(actor.texture.get_size() == Vector2(192, 256), "Three DS-style 64px frames per direction")
		assert(actor.regions.size() == 12)
		for region in actor.regions:
			assert(actor.frame_rect(region) == Rect2(0, 0, 16, 16), "No per-pose scaling")
		var atlas: Image = actor.texture.get_image()
		for row in 4:
			var idle := atlas.get_region(Rect2i(0, row * 64, 64, 64))
			for pose in [1, 2]:
				var stride := atlas.get_region(Rect2i(pose * 64, row * 64, 64, 64))
				# Whole-body poses may turn their heads/shoulders. Check registration
				# and clipping instead of forcing the idle upper half onto every stride.
				var bounds := stride.get_used_rect()
				assert(bounds.position.x > 0 and bounds.end.x < 64, "Walking pose stays within its atlas cell")
				assert(bounds.position.y > 0 and bounds.end.y <= 63, "Head and feet are not clipped")
				assert(absi(bounds.end.y-idle.get_used_rect().end.y) <= 1, "Walking feet share the standing baseline")
				assert(idle.get_data() != stride.get_data(), "Stride differs from standing")
	for direction in ["right", "down", "left", "up", "up", "down"]:
		var previous: Vector2i = player.grid_pos
		var target: Vector2i = previous + player.DIR_VECTOR[direction]
		var old_pose: int = player.sprite.step_pose
		var start: Vector2 = player.position
		player._move_to(target)
		assert(player.position == start and player.grid_pos == previous, "Starting a step must not teleport")
		assert(player.sprite.step_pose != old_pose, "Alternate the leading foot each tile")
		assert(player.sprite.current_frame == 0, "Start with feet together")
		player._move_to(previous + Vector2i.RIGHT)
		assert(player._step_target == target, "Cannot redirect midway through a tile")
		var last: Vector2 = start
		for sample in range(1, 13):
			player._advance_step(player.MOVE_TIME / 12.0)
			assert(player.position.distance_to(last) <= 2.0, "Cross intermediate pixels without jumps")
			last = player.position
			if sample == 6:
				assert(player.position == start.lerp(Vector2(target * 16), 0.5), "Half-time means halfway across the tile")
				assert(player.sprite.current_frame == player.sprite.step_pose + 1, "Show extended foot during travel")
				assert(player.grid_pos == previous, "Commit logical position only on arrival")
		# Finish any floating-point remainder.
		if player._moving:
			player._advance_step(0.0001)
		assert(player.grid_pos == target and player.position == Vector2(target * 16))
		assert(player.sprite.current_frame == 0 and not player.sprite.walking, "Feet return to neutral on arrival")
		assert(player.follower_grid == previous and player.follower.position == Vector2(previous * 16))
		assert(not player.follower.walking)
	assert(manager.steps == 6, "Only completed leader steps trigger encounters")
	player._move_to(player.grid_pos + Vector2i(2, 0))
	assert(not player._moving, "Cannot skip a tile")
	# Exercise the real process/input loop and release while crossing a tile.
	player.set_process(true)
	Input.action_press("ui_right")
	await create_timer(0.10).timeout
	Input.action_release("ui_right")
	assert(player._moving, "A short press starts a smooth step")
	var destination: Vector2i = player._step_target
	await create_timer(0.22).timeout
	assert(player.grid_pos == destination and not player._moving, "Release finishes the current tile only")
	var before_hold: int = manager.steps
	Input.action_press("ui_down")
	await create_timer(0.55).timeout
	Input.action_release("ui_down")
	await create_timer(0.30).timeout
	assert(manager.steps >= before_hold + 2, "Holding input continues across tiles")
	assert(not player._moving and player.position == Vector2(player.grid_pos * 16))
	player.input_locked = true
	var stopped: Vector2 = player.position
	Input.action_press("ui_right")
	await create_timer(0.30).timeout
	Input.action_release("ui_right")
	assert(player.position == stopped)
	player.input_locked = false
	player.grid_pos = Vector2i(3, 1)
	player.position = Vector2(player.grid_pos * 16)
	var follower_stopped: Vector2 = player.follower.position
	var steps_before_wall: int = manager.steps
	Input.action_press("ui_up")
	await create_timer(0.30).timeout
	Input.action_release("ui_up")
	assert(player.position == Vector2(48, 16) and player.follower.position == follower_stopped)
	assert(manager.steps == steps_before_wall)
	player.grid_pos = Vector2i(10, 7)
	player.position = Vector2(160, 112)
	player.facing = "right"
	player._update_sprite(false)
	player.follower_grid = Vector2i(9, 7)
	player.follower.position = Vector2(144, 112)
	player.follower.facing = "right"
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/preview-field-grid.png")
	manager.start_battle(player)
	assert(player.input_locked)
	manager._finish_battle(true)
	assert(not player.input_locked)
	print("FIELD PARTY PASS: smooth intermediate positions, synchronized feet, fixed size, input release/hold, collision, follower, encounters, battle return")
	quit()
