extends "res://tests/new_party_test.gd"

func run() -> void:
	manager = root.get_node("EncounterManager")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000
	field.rng.seed = 120
	field._tick_light_patrols(0.0,player)
	check(field.light_patrol_areas.size() == 4,"Exactly half of eight lit areas receive patrols")
	check(player.follower_grid-player.grid_pos == player.extra_grids[0]-player.follower_grid and player.extra_grids[0]-player.follower_grid == player.extra_grids[1]-player.extra_grids[0],"Initial party is one straight line")
	var residents: Array[Node2D] = []
	for area in field.light_patrol_areas:
		var count := 0
		for symbol in field.symbols:
			if symbol.patrol_area == area:
				count += 1
				residents.append(symbol)
				check(symbol.visible and field.is_lit(symbol.grid_pos),"Patrol appears in a lit district")
		check(count >= 1 and count <= 2,"Each selected light district has one or two patrols")
	var original_count: int = field.symbols.size()
	field._tick_light_patrols(31,player)
	check(field.symbols.size() == original_count,"Refresh cannot duplicate existing patrols")
	var patrol: Node2D = residents[0]
	var visited := {}
	for step in 80:
		field._decide(patrol,player)
		if patrol.moving:
			check(not player.occupies_tile(patrol.target),"Patrol avoids all four occupied party cells")
			patrol.advance(float(field.settings.enemy_step_seconds),float(field.settings.enemy_step_seconds))
		visited[patrol.grid_pos] = true
		check(field.area_at(patrol.grid_pos) == patrol.patrol_area,"Patrol stays within its own district")
	check(visited.size() > 2,"Patrol wanders instead of standing still")
	var district: int = patrol.patrol_area
	var candidates: Array[Vector2i] = field.object_edges(field.lamps[district])
	patrol.place(candidates[0])
	patrol.wait = 99
	var untouched: Array = field.lit.duplicate()
	for other in field.symbols:
		other.wait = 99
	field._process(0.5)
	check(patrol.siege_time == 0 and field.lit == untouched,"Light patrol does not attack a lamp")
	# Defeat one patrol: replacement waits for the patrol clock, not every frame.
	field.symbols.erase(patrol)
	patrol.free()
	field.patrol_refresh = 30
	field._tick_light_patrols(1,player)
	check(field.symbols.size() == original_count-1,"Defeated patrol is not replaced immediately")
	field._tick_light_patrols(30,player)
	check(field.symbols.size() == original_count,"Patrol population replenishes within its one-to-two limit")
	field.settings.lamp_break_enabled = true # Exercise patrol reconciliation under legacy darkness changes.
	field._extinguish(district,player)
	field._tick_light_patrols(0,player)
	check(not field.light_patrol_areas.has(district),"Darkened area is removed from light patrol selection")
	check(field.light_patrol_areas.size() == ceili((16-field.dark_count())/2.0),"Selection follows the current lit-area count")
	main.free()
	await process_frame
	var screen := battle()
	check(Screen.HERO_POS[1].y < Screen.HERO_POS[2].y and Screen.HERO_POS[2].y < Screen.HERO_POS[0].y and Screen.HERO_POS[0].y < Screen.HERO_POS[3].y,"User formation: Yeonwoo, Seola, Chuheun, Wiseong from top to bottom")
	check(Screen.HERO_POS[0].x == Screen.HERO_POS[1].x and Screen.HERO_POS[2].x == Screen.HERO_POS[3].x and Screen.HERO_POS[0].x > Screen.HERO_POS[2].x,"Front and rear columns follow user sketch")
	check(Screen.SHIELD_POS.x > Screen.HERO_POS[0].x and Screen.SHIELD_POS.y > Screen.HERO_POS[1].y and Screen.SHIELD_POS.y < Screen.HERO_POS[2].y,"Shield destination follows green circle")
	check(screen.seola_overhead_texture.get_size() == Vector2(768,256),"Three overhead transformation frames load")
	screen.hero_index = 2
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	screen.advance(0.65)
	check(screen.party[2].shield_turns == 0,"Moving forward does not apply shield early")
	screen.advance(1.99)
	check(screen.party[2].shield_turns == 0 and screen.phase == Screen.Phase.SUPPORT,"Two-second transformation blocks turn progression")
	screen.advance(0.42)
	check(screen.party[2].shield_turns == 1,"Shield takes effect exactly at the slam")
	check(screen.hero_position(2) == Screen.SHIELD_POS,"Deployed shield stays in forward center")
	screen.advance(0.8)
	check(screen.hero_index == 3 and screen.phase == Screen.Phase.COMMAND,"Next party member acts after deployment finishes")
	screen.party[2].shield_turns = 1
	screen.round_number = screen.shield_skip_round+2
	screen.enemy_index = screen.enemies.size()
	screen._enemy_action()
	check(screen.phase == Screen.Phase.SUPPORT and screen.action_kind == "shield_return","Expiry starts return cinematic before next party turn")
	var saved_round: int = screen.round_number
	screen.advance(1.39)
	check(screen.phase == Screen.Phase.SUPPORT,"Reversion and startled reaction finish before running")
	screen.advance(0.4)
	check(screen.phase == Screen.Phase.SUPPORT,"Running animation keeps battle input locked")
	screen.advance(0.5)
	check(screen.phase == Screen.Phase.COMMAND and screen.hero_index == 0,"Return resumes at Chuheun without skipping the next round")
	check(screen.round_number == saved_round and screen.hero_position(2) == Screen.HERO_POS[2],"Return restores original position without advancing extra round")
	check(not screen.party[2].guarding and screen.party[2].shield_turns == 0,"Shield and automatic guard end together")
	screen.free()
	print("SHIELD AND LIGHT PATROLS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
