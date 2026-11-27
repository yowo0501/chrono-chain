extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Lesson = preload("res://scripts/story/chapter/lesson_battle.gd")
const Field = preload("res://scripts/story/chapter/chase_field.gd")
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../battle-preview/slime-"+name+".png")
func run() -> void:
	root.size = Vector2i(768,672)
	root.content_scale_size = Vector2i(768,672)
	var manager = root.get_node("EncounterManager")
	manager.reset_party()
	for kind in [0,1,2,3]:
		var b = Screen.new() if kind in [0,3] else Lesson.new()
		if kind in [1,2]: b.lesson = 0 if kind == 1 else 1
		var config = manager.balance.duplicate(true)
		config.monster_count = 1 if kind == 1 else 5 if kind == 3 else 3
		var random = RandomNumberGenerator.new()
		random.seed = 33
		b.setup(manager.party.duplicate(true),config,random)
		root.add_child(b)
		b.set_process(false)
		b.advance(1.1)
		if kind in [1,2]:
			b.guide.active = false
			b.guide.hide()
		await capture(["battle","giant-battle","split-battle","five-battle"][kind])
		if kind == 0:
			b.action_index = 0
			b.action_kind = "enemy_attack"
			b.fx_time = 0.5
			b.queue_redraw()
			await capture("attack")
			b.hurt_enemy = 0
			b.queue_redraw()
			await capture("hit")
		b.free()
	var field = Field.new()
	root.add_child(field)
	field.set_process(false)
	field.tick(0)
	await capture("giant-field")
	field.mode = "chase"
	field.slime_positions[0] = field.position_px+Vector2(32,-64)
	field.tick(0)
	field.queue_redraw()
	await capture("split-field")
	field.free()
	print("SLIME PREVIEWS COMPLETE")
	quit()
