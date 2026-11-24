extends SceneTree
const OUT := "res://art-reviews/duo-overhaul/"
const Screen = preload("res://scripts/battle/battle_screen.gd")
var screen: Control
var manager: Node

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func battle() -> void:
	if is_instance_valid(screen):
		screen.free()
	manager.reset_party()
	screen = Screen.new()
	var config: Dictionary = manager.balance.duplicate(true)
	config.monster_count = 2
	var random := RandomNumberGenerator.new()
	random.seed = 33
	screen.setup(manager.party.duplicate(true),config,random)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)

func run() -> void:
	for folder in ["", "walk", "run", "idle", "attack"]:
		DirAccess.make_dir_recursive_absolute(OUT+folder)
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	root.add_child(main)
	await process_frame
	field.set_process(false)
	player.set_process(false)
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	manager = root.get_node("EncounterManager")
	field.grace = 10000
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()
	player.warp_to(Vector2i(28,45))
	player.facing = "down"
	player._update_sprite(false)
	await capture("01-field")
	field.hud.show_map = true
	await capture("02-city-map")
	field.hud.show_map = false
	for mode in ["walk","run"]:
		var frame := 0
		if mode == "run":
			Input.action_press("field_dash")
		for direction in ["right","up_right","up","up_left","left","down_left","down","down_right"]:
			player._move_to(player.grid_pos+player.DIR_VECTOR[direction])
			assert(player._moving,"Preview route cannot be blocked")
			var samples := ceili(player._step_duration*30)
			var delta: float = player._step_duration/samples
			for sample in samples:
				player._advance_step(delta)
				await capture("%s/%03d" % [mode,frame])
				frame += 1
			if player._moving:
				player._advance_step(0.001)
		Input.action_release("field_dash")
	player.warp_to(Vector2i(28,45))
	player.facing = "up_right"
	player._update_sprite(false)
	player.request_chain()
	player._advance_chain(0.03)
	await capture("03-chain-windup")
	player._advance_chain(0.07)
	await capture("04-chain-release")
	player.reset_field_action()
	main.free()
	await process_frame
	# Enlarged eight-direction contact sheet, rendered by the same field actors.
	root.content_scale_size = Vector2i(768,672)
	var gallery := Node2D.new()
	root.add_child(gallery)
	var backdrop := ColorRect.new()
	backdrop.color = Color("172532")
	backdrop.size = Vector2(768,672)
	gallery.add_child(backdrop)
	for row in 8:
		for hero in 2:
			for col in 4:
				var actor := load("res://scripts/field_actor.gd").new() as Node2D
				actor.configure(load("res://assets/characters/duo/"+["chuheun","yeonwoo"][hero]+"-field.png"))
				actor.position = Vector2(36+hero*384+col*88,48+row*78)
				actor.scale = Vector2(2,2)
				actor.facing = ["down","down_left","left","up_left","up","up_right","right","down_right"][row]
				actor.current_frame = [0,1,4,7][col]
				gallery.add_child(actor)
	await capture("05-eight-directions")
	gallery.free()
	root.content_scale_size = Vector2i(256,224)
	battle()
	await capture("06-battle")
	for frame in 30:
		screen.advance(0.1)
		await capture("idle/%03d" % frame)
	for hero in 2:
		battle()
		screen.hero_index = hero
		screen.action_index = hero
		screen.phase = screen.Phase.ATTACK_QTE
		screen.qte_elapsed = 0.7
		await capture("07-windup-%d" % hero)
		screen.phase = screen.Phase.RESOLVE
		screen.action_kind = "attack"
		screen.target_index = 0
		for frame in 24:
			screen.fx_time = 0.8-frame/30.0
			screen.queue_redraw()
			await capture("attack/%03d" % (hero*24+frame))
		await capture("08-recover-%d" % hero)
	battle()
	screen.party[0].attack_stacks = 3
	screen.party[0].focus_stacks = 3
	screen.skill_index = 0
	screen._begin_timer()
	screen.timer_cast.stage = screen.TimerSkill.Stage.AIM
	await capture("09-timer")
	battle()
	screen.hero_index = 1
	screen.party[1].attack_stacks = 3
	screen._begin_assassin(screen.skills()[0])
	screen.assassin_cast.stage = screen.AssassinSkill.Stage.YAWN
	screen.assassin_cast.elapsed = 0.4
	await capture("10-yeonwoo-yawn")
	screen.assassin_cast.stage = screen.AssassinSkill.Stage.EMBARRASSED
	screen.assassin_cast.elapsed = 0.8
	await capture("11-yeonwoo-miss")
	battle()
	screen.hero_index = 1
	screen.party[1].defense_stacks = 3
	screen.target_index = 0
	screen._begin_support(screen.skills()[1])
	screen.support_cast.elapsed = 1.6
	await capture("12-heal")
	screen.free()
	screen = null
	var story: Control = load("res://scenes/prologue/prologue.tscn").instantiate()
	root.add_child(story)
	story.set_process(false)
	while story.current.type != "dialogue":
		story.next_event()
	story.stage.show()
	story.stage.modulate.a = 1.0
	story.body.visible_characters = -1
	await capture("13-standing-dialogue")
	story.free()
	await process_frame
	print("DUO PREVIEW: all eight directions, walk/run recordings, continuous idles, both attacks and every active skill")
	quit()
