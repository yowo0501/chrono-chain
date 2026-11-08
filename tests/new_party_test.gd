extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var manager: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func battle(count: int = 5) -> Control:
	manager.reset_party()
	var config: Dictionary = manager.balance.duplicate(true)
	config.monster_count = count
	config.monster.max_hp = 5000
	for hero in manager.party:
		for key in ["attack_stacks","defense_stacks","focus_stacks"]:
			hero[key] = 3
	var random := RandomNumberGenerator.new()
	random.seed = 21
	var screen := Screen.new()
	screen.setup(manager.party,config,random)
	screen.field_context = {"light":false}
	root.add_child(screen)
	screen.set_process(false)
	screen.delay = 0
	screen.pending = Callable()
	screen.phase = Screen.Phase.COMMAND
	return screen

func cast(screen: Control) -> void:
	for i in 1000:
		if screen.phase not in [Screen.Phase.SUPPORT,Screen.Phase.TIMER,Screen.Phase.ASSASSIN]:
			break
		screen.advance(0.01)

func run() -> void:
	manager = root.get_node("EncounterManager")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var player: Node2D = main.get_node("Player")
	var field: Node2D = main.get_node("Field")
	player.set_process(false)
	field.set_process(false)
	field.grace = 999
	check(manager.party.size() == 4,"Four party members registered")
	check(player.extra_followers.size() == 2,"Three companions follow leader")
	for actor in [player.sprite,player.follower]+player.extra_followers:
		check(actor.texture.get_size() == Vector2(192,256),"Every field atlas has fixed 64px 3x4 frames")
	for step in [Vector2i.RIGHT,Vector2i.RIGHT,Vector2i.UP,Vector2i.UP,Vector2i.LEFT]:
		var old_leader: Vector2i = player.grid_pos
		var old_follower: Vector2i = player.follower_grid
		var old_extra: Vector2i = player.extra_grids[0]
		player._move_to(player.grid_pos+step)
		if not player._moving:
			continue
		player._advance_step(player.MOVE_TIME)
		check(player.follower_grid == old_leader and player.extra_grids[0] == old_follower and player.extra_grids[1] == old_extra,"All companions trace predecessor through turns")
	for area in field.lamps.size():
		if not field.lit[area]:
			check(field.repair_lamp(area,player),"Manual repair succeeds")
			field._extinguish(area,player)
			check(field.lit[area],"Repaired lamp cannot extinguish")
	for count in [3,4,5]:
		var config: Dictionary = manager.balance_for_context({"boss":false,"light":true,"dark_lamps":0,"enemy_count":count},field.settings)
		check(config.monster_count == count,"Normal encounter preserves 3–5 count")
	check(manager.balance_for_context({"boss":true,"dark_lamps":0},field.settings).monster_count == 1,"Boss is exactly one")
	main.free()
	await process_frame
	var screen := battle()
	check(screen.enemies.size() == 5 and screen.enemy_positions.size() == 5,"Five foes receive positions")
	for actor in 4:
		for kind in ["attack","defense","focus"]:
			screen._gain_stack(actor,kind)
			check(screen.party[actor][kind+"_stacks"] == 3,"Stack capped at three")
	screen.hero_index = 2
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	cast(screen)
	check(screen.party[2].shield_turns == 1 and screen.party[2].guarding,"Shield deployed for one future turn")
	check(screen.party[2].defense_stacks == 1,"Shield costs two defense")
	for round_id in [1,2]:
		screen.round_number = round_id
		for foe in 5:
			screen.enemy_index = foe
			screen._enemy_action()
			check(screen.defending_index == 2,"Every enemy targets living shield bearer")
		screen.enemy_index = 5
		screen._enemy_action()
		if round_id < 2:
			screen.hero_index = 2
			screen._next_hero()
			check(screen.phase == Screen.Phase.RESOLVE and screen.party[2].guarding,"Shield forces automatic guard")
			check(screen.party[2].defense_stacks == 1,"Automatic guard never earns stacks")
	check(screen.party[2].shield_turns == 0,"Shield expires after exactly one future turn")
	screen.hero_index = 2
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(1)
	cast(screen)
	check(screen.phase == Screen.Phase.ATTACK_QTE,"Heavy swing uses position QTE")
	check(screen.party[2].focus_stacks == 2,"Heavy swing costs one focus")
	var target_hp: int = screen.enemies[0].hp
	screen.qte_elapsed = Screen.Rules.position_marker(screen.foe_position(0).y)*float(screen.balance.qte.duration)/4.0
	screen._resolve_qte(true)
	screen.advance(0.71)
	check(screen.enemies[0].hp == target_hp-132,"Shield swing hits one foe for configured heavy damage")
	check(screen.party[2].attack_stacks == 3,"Special does not gain attack stack")
	screen.hero_index = 3
	screen.phase = Screen.Phase.SKILLS
	screen.select_skill(0)
	cast(screen)
	check(screen.reveal_remaining > 18.0,"Mage reveals darkness for twenty seconds minus animation tail")
	check(screen.party[3].focus_stacks == 2,"Mage illumination costs one focus")
	for target in 4:
		screen.party[target].hp = 1
		screen.party[1].defense_stacks = 3
		screen.hero_index = 1
		screen.phase = Screen.Phase.SKILLS
		screen.select_skill(1)
		screen.target_index = target
		screen.confirm_target()
		cast(screen)
		check(screen.party[target].hp > 1,"Heal works for every party member")
	check(screen.balance.timer.reveal_seconds == 20 and screen.balance.thunder.reveal_seconds == 10,"Chuheun reveal durations updated")
	screen.party[2].shield_turns = 2
	screen.party[2].hp = 0
	screen.enemy_index = 0
	screen._enemy_action()
	check(screen.defending_index != 2,"Defeated tank cannot attract attacks")
	var saved: Array = manager.party.duplicate(true)
	manager.active = true
	manager._finish_battle(false)
	for i in 4:
		for key in ["attack_stacks","defense_stacks","focus_stacks"]:
			check(manager.party[i][key] == saved[i][key],"Unspent stacks survive battle outcome")
		check(manager.party[i].shield_turns == 0,"Temporary shield clears after battle")
	screen.free()
	print("NEW PARTY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
