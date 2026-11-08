extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func press(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event

func run() -> void:
	var manager: Node = root.get_node("EncounterManager")
	var tutorial: Node = root.get_node("Tutorial")
	for code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		var event := press(code)
		check(InputMap.event_is_action(event, "ui_accept"), "Native title buttons accept confirm key")
		manager.reset_party()
		var battle := Screen.new()
		battle.setup(manager.party.duplicate(true), manager.balance, RandomNumberGenerator.new())
		root.add_child(battle)
		battle.set_process(false)
		battle.advance(1.1)
		battle._input(event)
		check(battle.phase == Screen.Phase.ATTACK_QTE and battle.qte_elapsed == 0, "Confirm starts attack without also submitting QTE")
		var repeat := press(code)
		repeat.echo = true
		battle._input(repeat)
		check(battle.phase == Screen.Phase.ATTACK_QTE, "Held key repeat does not submit QTE")
		battle._input(event)
		check(battle.phase == Screen.Phase.RESOLVE, "Second press submits attack QTE")
		battle.phase = Screen.Phase.GUARD_QTE
		battle.qte_elapsed = 0
		battle._input(event)
		check(battle.phase == Screen.Phase.RESOLVE and battle.last_grade == "normal", "Confirm submits defense instead of timing out")
		battle.phase = Screen.Phase.COMMAND
		battle.hero_index = 1
		battle.command_index = 3
		battle.party[1].attack_stacks = 3
		battle._input(event)
		check(battle.phase == Screen.Phase.SKILLS, "Confirm opens skill menu")
		battle._input(event)
		check(battle.phase == Screen.Phase.ASSASSIN, "Confirm selects skill")
		battle.advance(0.65)
		battle.advance(0.24)
		battle._input(event)
		check(battle.assassin_cast.results.size() == 1, "Confirm submits assassin QTE")
		battle.phase = Screen.Phase.BIND
		battle.field_context = {"boss":true}
		battle.bind_stage = 1
		battle.bind_elapsed = 0
		battle._input(event)
		check(battle.bind_trials.size() == 1, "Confirm submits bind QTE")
		var finished := [0]
		battle.battle_finished.connect(func(_won): finished[0] += 1)
		battle.phase = Screen.Phase.RESULT
		battle._input(event)
		check(finished[0] == 1, "Confirm closes result once")
		battle.free()
		tutorial.enabled = true
		for required in [KEY_SPACE, KEY_ENTER]:
			tutorial.show_step("key_%d_%d" % [code,required], "확인", "입력 검사", [tutorial.option("확인",Rect2(224,450,320,50),required)])
			tutorial._input(event)
			check(not tutorial.active and not paused, "Both confirm bindings dismiss tutorial")
		tutorial.show_step("map_%d" % code, "지도", "M 입력", [tutorial.option("M",Rect2(224,450,320,50),KEY_M)])
		tutorial._input(event)
		check(tutorial.active, "Confirm does not bypass specific tutorial action keys")
		tutorial._input(press(KEY_M))
		tutorial.enabled = false
	print("CONFIRM INPUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
