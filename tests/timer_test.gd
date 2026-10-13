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
	var random := RandomNumberGenerator.new()
	random.seed = 71
	screen.setup(manager.party.duplicate(true), manager.balance, random, true)
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	return screen

func begin(screen: Control) -> void:
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.select_command(3)
	screen.select_skill(0)
	screen.confirm_target()

func run() -> void:
	manager = root.get_node("EncounterManager")
	for pattern in 8:
		var screen := fixture()
		begin(screen)
		check(screen.phase == Screen.Phase.TIMER, "cast enters timer")
		check(screen.party[0].attack_stacks == 0 and screen.party[0].focus_stacks == 0, "cost paid once at confirmation")
		var successes := 0
		for stage in 3:
			var success := bool(pattern & (1 << stage))
			if success:
				screen.advance(float(manager.balance.timer.qte_duration) * 0.5)
				successes += 1
			screen.timer_cast.press()
			check(screen.timer_cast.results.size() == stage + 1, "each press resolves exactly one segment")
			if stage == 0:
				screen.advance(0.48)
			elif stage == 1:
				screen.advance(0.88)
		check(screen.timer_cast.successes == successes, "success count")
		if successes == 0:
			check(screen.timer_cast.stage == Cast.Stage.CONFUSED, "zero successes starts comic miss")
			for i in 50:
				screen.advance(0.05)
			check(screen.enemies[0].hp == 480 and screen.enemies[1].hp == 480, "comic miss causes no damage")
		else:
			screen.advance(0.22)
			screen.advance(0.38)
			var primary_before: int = screen.enemies[0].hp
			check(primary_before < 480 and screen.enemies[1].hp == 480, "spear only hits selected enemy")
			screen.advance(0.99)
			check(screen.enemies[0].hp == primary_before and screen.enemies[1].hp == 480, "no lightning before one second")
			screen.advance(0.011)
			var splash := roundi(24 * float(manager.balance.timer.lightning_multipliers[successes]))
			check(screen.enemies[1].hp == 480 - splash, "lightning damages other enemy")
			check(screen.enemies[0].hp == primary_before - splash, "primary also receives lightning")
			check(screen.party[0].hp == 120 and screen.party[1].hp == 100, "lightning never damages allies")
			screen.advance(0.81)
			screen.advance(0.66)
		check(screen.hero_index == 1 and screen.phase == Screen.Phase.COMMAND, "cast ends with partner turn")
		screen.free()
	var screen := fixture()
	screen.select_command(3)
	screen.select_skill(0)
	check(screen.phase == Screen.Phase.SKILLS and screen.message == "스택이 부족합니다!", "insufficient stacks block skill")
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.select_skill(0)
	var cancel := InputEventKey.new()
	cancel.pressed = true
	cancel.physical_keycode = KEY_ESCAPE
	screen._input(cancel)
	check(screen.party[0].attack_stacks == 2 and screen.party[0].focus_stacks == 2, "cancel preserves cost")
	screen._input(cancel)
	check(screen.target_action == "attack", "cancel clears special target mode")
	screen.select_command(0)
	screen.confirm_target()
	check(screen.phase == Screen.Phase.ATTACK_QTE, "normal attack works after cancelling skill")
	screen.free()
	screen = fixture()
	begin(screen)
	for i in 3:
		screen.advance(1.09)
		if i == 0:
			screen.advance(0.48)
		elif i == 1:
			screen.advance(0.88)
	check(screen.timer_cast.successes == 0 and screen.timer_cast.stage == Cast.Stage.CONFUSED, "no-input timeout advances once per stage")
	screen.free()
	screen = fixture()
	begin(screen)
	var repeated := InputEventKey.new()
	repeated.pressed = true
	repeated.echo = true
	repeated.physical_keycode = KEY_SPACE
	screen._input(repeated)
	check(screen.timer_cast.results.is_empty(), "held key repeat cannot resolve QTE")
	screen.enemies[0].hp = 1
	for i in 3:
		screen.advance(0.9)
		screen.timer_cast.press()
		if i == 0:
			screen.advance(0.48)
		elif i == 1:
			screen.advance(0.88)
	screen.advance(0.22)
	screen.advance(0.38)
	check(screen.phase == Screen.Phase.TIMER and screen.enemies[0].hp == 0, "spear kill does not interrupt lightning")
	screen.advance(1.01)
	check(screen.enemies[1].hp == 360, "lightning lands even after primary dies")
	screen.advance(0.81)
	screen.advance(0.66)
	check(screen.phase == Screen.Phase.COMMAND, "turn resumes after primary kill")
	screen.free()
	screen = fixture()
	screen.enemies[0].hp = 1
	screen.enemies[1].hp = 1
	screen.enemies[2].hp = 1
	begin(screen)
	for i in 3:
		screen.advance(0.9)
		screen.timer_cast.press()
		if i == 0:
			screen.advance(0.48)
		elif i == 1:
			screen.advance(0.88)
	screen.advance(0.22)
	screen.advance(0.38)
	screen.advance(1.01)
	check(screen.enemies[0].hp == 0 and screen.enemies[1].hp == 0, "lightning can defeat the entire enemy team")
	check(screen.phase == Screen.Phase.TIMER, "victory waits for lightning animation")
	screen.advance(0.81)
	screen.advance(0.66)
	check(screen.phase == Screen.Phase.RESULT and screen.won, "cast finishes into victory without another enemy turn")
	screen.free()
	screen = fixture()
	# Actual four-turn preparation, including both enemy phases; no granted stacks.
	for round in 4:
		if round < 2:
			screen.select_command(0)
			screen.confirm_target()
			screen.qte_elapsed = 0.1
			screen._resolve_qte(true)
			screen.advance(0.81)
		else:
			screen.select_command(2)
			screen.advance(1.01)
		screen.select_command(1)
		for step in 150:
			if screen.phase == Screen.Phase.COMMAND and screen.hero_index == 0:
				break
			if screen.phase == Screen.Phase.GUARD_QTE:
				screen.qte_elapsed = 0.4
				screen._resolve_qte(true)
			screen.advance(0.1)
	check(screen.round_number == 5 and screen.can_use_timer(), "heavy encounter allows earning cost through four rounds")
	check(screen.party[0].hp > 0 and screen.enemies[0].hp > 0, "hero and target survive preparation")
	screen.free()
	check(manager.choose_armored(0.0) and manager.choose_armored(0.3333), "first third selects heavy")
	check(not manager.choose_armored(1.0 / 3.0) and not manager.choose_armored(0.999), "remaining two thirds select normal")
	print("TIMER TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
