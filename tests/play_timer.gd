extends SceneTree
## Interactive special-skill demo with both characters' costs ready.
const Screen = preload("res://scripts/battle/battle_screen.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	var screen := Screen.new()
	screen.setup(manager.party, manager.balance, RandomNumberGenerator.new(), true)
	screen.party[0].attack_stacks = 2
	screen.party[0].focus_stacks = 2
	screen.party[1].attack_stacks = 1
	screen.party[1].defense_stacks = 2
	screen.party[1].focus_stacks = 1
	screen.battle_finished.connect(func(_won: bool): quit())
	root.add_child(screen)
