extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DUO FAIL: "+label)

func run() -> void:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	var manager := root.get_node("EncounterManager")
	check(manager.party.size()==2,"Only Chuheun and Yeonwoo are playable")
	check(manager.party[0].id=="chuheun" and manager.party[1].id=="yeonwoo","Correct two heroes")
	check(manager.balance.special_skills.size()==2,"No removed-character skill menu")
	check(manager.enemy_count_limits({"dark_lamps":4})==Vector2i(1,2),"Early encounter 1–2 enemies")
	check(manager.enemy_count_limits({"dark_lamps":2})==Vector2i(2,3),"Late encounter 2–3 enemies")
	check(manager.balance.monster.max_hp==66 and manager.balance.monster.attack==12,"Normal enemy tuned for duo")
	check(field.settings.boss_hp==520 and field.settings.boss_attack==19,"Boss tuned for duo")
	check(field.settings.enemy_spawns.size()==3 and field.settings.max_active_symbols==9,"Lower field population")
	check(field.settings.layout_version=="duo-eight-way-1" and field.settings.routes.size()==30,"New diagonal city layout")
	check(field.lamps.size()==16 and field.dark_count()==4,"Lamp progression preserved")
	var seen := {field.start_tile():true}
	var queue: Array[Vector2i] = [field.start_tile()]
	var cursor := 0
	while cursor < queue.size():
		var tile := queue[cursor]
		cursor += 1
		for offset in field.OFFSETS:
			var next: Vector2i = tile+offset
			if not seen.has(next) and field.can_step(tile,next):
				seen[next] = true
				queue.append(next)
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			if not field.is_blocked(tile):
				check(seen.has(tile),"Walkable cell reachable without cutting corners")
	for lamp in field.lamps:
		var reachable := false
		for offset in field.OFFSETS:
			reachable = reachable or seen.has(lamp+offset)
		check(reachable,"Every lamp has an accessible interaction tile")
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()
	field.grace = 10000.0
	var home := Vector2i(26,45)
	for actor in [player.sprite,player.follower]:
		check(actor.regions.size()==12 and actor.texture.get_size()==Vector2(192,256),"Previous field art restored with eight-way movement")
		var atlas: Image = actor.texture.get_image()
		for region in actor.regions:
			var frame := atlas.get_region(Rect2i(region))
			var used := frame.get_used_rect()
			check(used.has_area() and used.position.x>0 and used.end.x<64 and used.end.y<=63,"Complete registered sprite with transparent safety border")
	for direction in player.DIR_VECTOR:
		player.warp_to(home)
		var offset: Vector2i = player.DIR_VECTOR[direction]
		player._move_to(home+offset)
		check(player._moving and player.facing==direction,"Start movement in "+direction)
		check(is_equal_approx(player._step_duration,0.24*Vector2(offset).length()),"Equal world speed for "+direction)
		player._advance_step(player._step_duration*0.5)
		check(player.position==Vector2(home*16+offset*8),"Continuous midpoint in "+direction)
		player._advance_step(player._step_duration)
		check(player.grid_pos==home+offset and player.follower_grid==home,"Follower follows exact eight-way path")
		Input.action_press("field_dash")
		player._move_to(home)
		check(player.sprite.dashing and player.follower.dashing,"Both heroes run")
		check(is_equal_approx(player._step_duration,0.12*Vector2(offset).length()),"Dash is twice speed")
		player._advance_step(player._step_duration)
		Input.action_release("field_dash")
	Input.action_press("ui_up")
	Input.action_press("ui_right")
	check(player._read_direction()=="up_right","Two direction keys produce a diagonal")
	Input.action_release("ui_up")
	Input.action_release("ui_right")
	player.warp_to(home)
	var wall := home+Vector2i.RIGHT
	var original: String = field.tiles[wall.y]
	field.tiles[wall.y] = original.substr(0,wall.x)+"#"+original.substr(wall.x+1)
	check(not field.can_step(home,home+Vector2i(1,-1)),"Diagonal cannot cut a blocked corner")
	player._move_to(home+Vector2i(1,-1))
	check(not player._moving,"Player respects corner collision")
	field.tiles[wall.y] = original
	player.facing = "up_right"
	player._update_sprite(false)
	check(player.request_chain(),"Diagonal chain begins")
	player._advance_chain(0.3)
	check(player.sprite.current_frame==1 and player.chain_extension(0.3)==0,"Deliberate draw-back without premature extension")
	player._advance_chain(0.5)
	check(player.sprite.current_frame==2 and is_equal_approx(player.chain_extension(0.8),1.0),"Release reaches full range after windup")
	player._advance_chain(0.2)
	check(player.sprite.current_frame==0 and is_equal_approx(player.chain_remaining(),0.25),"Standing during short recovery")
	player.reset_field_action()
	var symbol: Node2D = field._spawn_symbol(home+Vector2i(2,-2))
	check(field.chain_target(player,4.0)==symbol,"Diagonal chain reaches targets within four tile lengths")
	symbol.place(home+Vector2i(3,-3))
	check(field.chain_target(player,4.0)==null,"Diagonal chain does not gain extra length")
	field._tick_light_patrols(1.0,player)
	check(field.symbols.size()<=9,"Patrol spawning respects total population cap")
	for actor in [player.sprite,player.follower]:
		actor.end_step()
	main.free()
	await process_frame
	var screen := Screen.new()
	var settings: Dictionary = manager.balance.duplicate(true)
	settings.monster_count = 2
	var random := RandomNumberGenerator.new()
	random.seed = 79
	screen.setup(manager.party.duplicate(true),settings,random)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	check(screen.textures.size()==2 and screen.HERO_POS.size()==2,"Battle renders two heroes in two slots")
	for actor in 2:
		var poses := {}
		for sample in 12:
			poses[screen.idle_frame(actor,sample*0.25)] = true
		check(poses.size()>=3,"Previous continuous character idle retained")
		check(screen.motion_textures[actor].get_size()==Vector2(1536,960),"Previous battle animation atlas restored")
	screen.hero_index = 1
	screen._after_hero()
	check(screen.phase==screen.Phase.ENEMY,"Enemy turn begins after exactly two heroes")
	screen.party[0].hp = 0
	screen.party[1].hp = 0
	check(screen._check_end() and not screen.won,"Defeat checks both heroes")
	screen.free()
	print("DUO OVERHAUL: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
