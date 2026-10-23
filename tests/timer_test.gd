extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Cast = preload("res://scripts/battle/timer_skill.gd")
var checks := 0
var failures := 0
var manager: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fixture() -> Control:
	manager.reset_party()
	var screen := Screen.new()
	screen.setup(manager.party.duplicate(true),manager.balance,RandomNumberGenerator.new(),true)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	return screen

func begin(screen: Control) -> void:
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.select_command(3)
	screen.select_skill(0)

func reach(screen: Control, stage: int) -> void:
	for i in 1000:
		if screen.timer_cast.stage == stage:
			return
		screen.advance(0.01)
	check(false,"Timer reached expected stage")

func run() -> void:
	manager = root.get_node("EncounterManager")
	for noisy_input in [false,true]:
		var screen := fixture()
		begin(screen)
		check(screen.phase == Screen.Phase.TIMER,"Selecting timer starts automatic area cast")
		check(screen.party[0].attack_stacks == 0 and screen.party[0].focus_stacks == 0,"Cost charged once")
		for i in 600:
			if screen.timer_cast.stage == Cast.Stage.WAIT:
				break
			check(not screen.timer_cast.is_qte(),"Every stage is automatic")
			if noisy_input:
				screen.timer_cast.press()
			screen.advance(0.01)
		for enemy in screen.enemies:
			check(enemy.hp == enemy.max_hp,"Spear planting does not add a separate single-target attack")
		screen.advance(0.99)
		check(screen.timer_cast.stage == Cast.Stage.WAIT,"Lightning waits a full second")
		screen.advance(0.011)
		for enemy in screen.enemies:
			check(enemy.hp == enemy.max_hp-120,"All enemies receive the same 5x lightning")
		check(screen.party[0].hp == 120 and screen.party[1].hp == 100,"No friendly fire")
		check(is_equal_approx(screen.reveal_remaining,20),"Reveal starts at lightning impact")
		screen.advance(0.81)
		screen.advance(0.66)
		check(screen.hero_index == 1 and screen.phase == Screen.Phase.COMMAND,"Landing hands turn to partner")
		screen.timer_cast.advance(10)
		for enemy in screen.enemies:
			check(enemy.hp == enemy.max_hp-120,"Completed cast cannot emit twice")
		screen.free()
	var screen := fixture()
	screen.select_command(3)
	screen.select_skill(0)
	check(screen.phase == Screen.Phase.SKILLS and screen.message == "스택이 부족합니다!","Insufficient stacks leave menu open")
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.physical_keycode = KEY_ESCAPE
	screen._input(cancel)
	check(screen.phase == Screen.Phase.COMMAND and screen.party[0].attack_stacks == 2,"Cancel before selecting spell preserves stacks")
	begin(screen)
	screen._input(cancel)
	check(screen.phase == Screen.Phase.TIMER and screen.party[0].attack_stacks == 0,"Committed spell cannot be cancelled")
	screen.free()
	screen = fixture()
	for enemy in screen.enemies:
		enemy.hp = 1
	begin(screen)
	reach(screen,Cast.Stage.LIGHTNING)
	check(screen.phase == Screen.Phase.TIMER,"Victory waits for animation")
	for enemy in screen.enemies:
		check(enemy.hp == 0,"Whole enemy group defeated")
	screen.advance(0.81)
	screen.advance(0.66)
	check(screen.phase == Screen.Phase.RESULT and screen.won,"Victory resolves after landing")
	screen.free()
	# Earn the cost through real turns rather than granted stacks.
	screen = fixture()
	for round in 4:
		if round < 2:
			screen.select_command(0)
			screen.qte_elapsed = 0.0
			screen._resolve_qte(true)
			screen.advance(0.81)
		else:
			screen.select_command(2)
			screen.advance(1.01)
		screen.select_command(1)
		for step in 150:
			if screen.phase == Screen.Phase.COMMAND and screen.hero_index == 0:
				break
			if screen.phase == Screen.Phase.COMMAND and screen.hero_index != 0:
				screen.select_command(1)
			if screen.phase == Screen.Phase.GUARD_QTE:
				screen.qte_elapsed = 0.4
				screen._resolve_qte(true)
			screen.advance(0.1)
	check(screen.round_number == 5 and screen.can_use_timer(),"Four rounds can earn timer cost")
	check(screen.party[0].hp > 0 and screen.enemies[0].hp > 0,"Preparation leaves living caster and targets")
	screen.free()
	print("TIMER TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
