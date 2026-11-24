extends SceneTree
const OUT := "res://art-reviews/yeonwoo-personality-idle/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	var manager := root.get_node("EncounterManager")
	manager.reset_party()
	var screen := load("res://scripts/battle/battle_screen.gd").new() as Control
	var random := RandomNumberGenerator.new()
	random.seed = 33
	screen.setup(manager.party.duplicate(true),manager.balance.duplicate(true),random)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	screen.hero_index = 1
	screen.heading = "아군 턴 / 김연우"
	screen.special_wait = 100.0
	screen.clock = -0.4
	# First a full quiet loop, then two explicitly staged gesture previews.
	# Gameplay spacing is tested separately; it is NOT shortened in the game.
	for frame in 288:
		if frame == 168 or frame == 228:
			screen.special_actor = 1
			screen.special_elapsed = 0.0
			screen.yeonwoo_special_kind = "yawn" if frame == 168 else "chain"
		screen.advance(1.0/24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image()
		captured.save_png(OUT+"frames/%03d.png" % frame)
		if frame in [0,130,192,247]:
			captured.save_png(OUT+"pose-%d.png" % frame)
	print("YEONWOO PERSONALITY PREVIEW: calm loop, yawn, chain correction at real motion speed; waits shortened for review only")
	quit()
