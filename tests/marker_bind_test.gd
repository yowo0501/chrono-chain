extends "res://tests/new_party_test.gd"

func press_at(screen: Control, index: int) -> void:
	screen.qte_elapsed = Screen.Rules.position_marker(screen.foe_position(index).y)*float(screen.balance.qte.duration)/(2*int(screen.balance.qte.round_trips))
	screen._resolve_qte(true)

func start_bind(screen: Control, boss: bool = false) -> void:
	screen.field_context = {"boss":boss,"light":false}
	screen.hero_index = 3
	screen.party[3].attack_stacks = 3
	screen.party[3].focus_stacks = 3
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(1)
	screen.advance(1.01)

func run() -> void:
	manager = root.get_node("EncounterManager")
	var screen := battle()
	screen.enemy_positions.assign([Vector2(480,240),Vector2(660,280),Vector2(480,330),Vector2(660,390),Vector2(480,440)])
	check(screen.marker_opacity(0) == 0,"Unknown enemy line starts hidden in darkness")
	screen.reveal(1)
	screen.hero_index = 0
	screen.select_command(0)
	press_at(screen,0)
	screen.reveal_remaining = 0
	check(screen.marker_opacity(0) == 1 and screen.marker_opacity(1) == 0,"Successful attack remembers only the hit enemy after light expires")
	check(screen.visibility_strength() == 0,"Remembering a line does not reveal enemy sprites or brighten the field")
	screen.enemy_index = 4
	screen.defending_index = 2
	screen.party[2].guarding = true
	screen.phase = Screen.Phase.GUARD_QTE
	var hp: int = screen.party[2].hp
	var enemy_hp: int = screen.enemies[4].hp
	press_at(screen,4)
	check(screen.party[2].hp == hp and screen.enemies[4].hp < enemy_hp,"Guard at attacker's off-center position counters without damage")
	check(screen.marker_opacity(4) == 1 and screen.marker_opacity(2) == 0,"Successful guard remembers only its attacker")
	screen.phase = Screen.Phase.GUARD_QTE
	screen.enemy_index = 1
	press_at(screen,0)
	check(screen.last_grade == "normal" and not screen.known_markers.has(1),"Guard on another enemy's line does not counter or reveal attacker")
	screen.phase = Screen.Phase.GUARD_QTE
	screen.qte_elapsed = float(screen.balance.qte.duration)
	screen._resolve_qte(false)
	check(screen.last_grade == "miss" and not screen.known_markers.has(1),"Timeout never records a marker")
	screen.field_context = {"boss":true,"light":false}
	screen.enemy_index = 0
	screen.round_number = 2
	var old: Vector2 = screen.foe_position(0)
	screen._enemy_action()
	check(screen.foe_position(0) != old and screen.marker_opacity(0) == 1,"Known boss marker follows boss relocation")
	screen.free()
	screen = battle()
	check(screen.known_markers.is_empty(),"New battle starts with no remembered enemies")
	start_bind(screen)
	check(screen.party[3].attack_stacks == 2 and screen.party[3].focus_stacks == 2,"Bind costs one attack and one focus")
	check(screen.marker_opacity(0,true) == 1 and screen.visibility_strength() == 0,"Bind exposes all markers without lighting the scene")
	for index in [0,2,4]:
		screen.bind_elapsed = Screen.Rules.position_marker(screen.foe_position(index).y)*screen._bind_duration()/4
		screen._press_bind()
		screen._press_bind()
	check(screen.bind_targets.size() == 3,"Repeated input cannot duplicate targets; multiple foes can be selected")
	check(screen.enemies[0].bind_turns == 0,"Enemies are not bound before staff slam")
	screen.advance(screen._bind_duration())
	screen.advance(0.81)
	for index in 5:
		check(screen.enemies[index].bind_turns == (2 if index in [0,2,4] else 0),"Only successful targets receive two-turn bind")
	screen.advance(0.81)
	for turns in [1,0]:
		screen.enemy_index = 0
		screen._enemy_action()
		check(screen.action_kind == "bound" and screen.enemies[0].bind_turns == turns,"Bound enemy skips one action and consumes one duration")
	screen.enemy_index = 0
	screen._enemy_action()
	check(screen.action_kind == "enemy_windup","Enemy attacks again after exactly two skipped actions")
	screen.free()
	for successful_trips in [2,3]:
		screen = battle(1)
		start_bind(screen,true)
		for trip in successful_trips:
			screen.bind_elapsed = trip*float(screen.balance.bind.boss_trip_duration)+Screen.Rules.position_marker(screen.foe_position(0).y)*float(screen.balance.bind.boss_trip_duration)/2
			screen._press_bind()
			screen._press_bind()
		check(screen.bind_trials.size() == successful_trips,"Boss accepts at most one attempt per round trip")
		screen.advance(screen._bind_duration())
		screen.advance(0.81)
		check(screen.enemies[0].bind_turns == (2 if successful_trips == 3 else 0),"Boss requires all three round trips, with no partial bind")
		screen.free()
	screen = battle(1)
	start_bind(screen,true)
	screen.bind_elapsed = 0
	screen._press_bind()
	for trip in 3:
		screen.bind_elapsed = trip*float(screen.balance.bind.boss_trip_duration)+Screen.Rules.position_marker(screen.foe_position(0).y)*float(screen.balance.bind.boss_trip_duration)/2
		screen._press_bind()
	screen.advance(screen._bind_duration())
	screen.advance(0.81)
	check(screen.enemies[0].bind_turns == 0,"Failed boss attempt cannot be retried within the same round trip")
	screen.free()
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	field.set_process(false)
	main.get_node("Player").set_process(false)
	var hud: Control = field.hud
	for i in field.lamps.size():
		var point: Vector2 = hud.minimap_point(field.lamps[i])
		check(Rect2(648,5,108,54).has_point(point),"Every actual lamp coordinate fits inside the minimap")
		for j in range(i+1,field.lamps.size()):
			var other: Vector2 = hud.minimap_point(field.lamps[j])
			check(signf(point.x-other.x) == signi(field.lamps[i].x-field.lamps[j].x) and signf(point.y-other.y) == signi(field.lamps[i].y-field.lamps[j].y),"Minimap preserves real east/west and north/south ordering")
	main.free()
	print("MARKERS, BIND AND MINIMAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
