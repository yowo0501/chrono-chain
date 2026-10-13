extends Node
## All field players report completed, walkable steps here. No per-map exclusions.
const BattleScreen = preload("res://scripts/battle/battle_screen.gd")
const Transition = preload("res://scripts/battle/encounter_transition.gd")
var balance: Dictionary
var party: Array = []
var steps := 0
var active := false
var encounters := 0
var rng := RandomNumberGenerator.new()
var player: Node2D
var screen: Control
var overlay: CanvasLayer
var transition: Control
var armored_encounter := false

func choose_armored(roll: float) -> bool:
	return roll < 1.0 / 3.0

func _ready() -> void:
	rng.randomize()
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_balance.json"))
	reset_party()

func reset_party() -> void:
	party = balance.heroes.duplicate(true)
	for hero in party:
		hero.hp = hero.max_hp
		hero.guarding = false
		hero.attack_stacks = 0
		hero.defense_stacks = 0
		hero.focus_stacks = 0

func should_encounter(completed_steps: int, roll: float) -> bool:
	var settings: Dictionary = balance.encounter
	if completed_steps <= int(settings.safe_steps):
		return false
	return completed_steps >= int(settings.maximum_steps) or roll < float(settings.chance_per_step)

func step_completed(walker: Node2D) -> void:
	if active:
		return
	steps += 1
	if should_encounter(steps, rng.randf()):
		start_battle(walker)

func start_battle(walker: Node2D) -> void:
	if active:
		return
	active = true
	player = walker
	player.input_locked = true
	steps = 0
	encounters += 1
	armored_encounter = choose_armored(rng.randf())
	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	screen = null
	transition = Transition.new()
	transition.covered.connect(_on_transition_covered)
	transition.finished.connect(_on_transition_finished)
	overlay.add_child(transition)

func _on_transition_covered() -> void:
	if not active or not is_instance_valid(overlay):
		return
	screen = BattleScreen.new()
	screen.setup(party, balance, rng, armored_encounter)
	screen.battle_finished.connect(_finish_battle)
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	overlay.add_child(screen)

func _on_transition_finished() -> void:
	if is_instance_valid(screen):
		screen.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(transition):
		transition.queue_free()
	transition = null

func _finish_battle(won: bool) -> void:
	# Prototype recovery: both outcomes restore the party at the same field tile.
	# Explicit result text explains this; a future save/checkpoint system can replace it.
	if not won:
		reset_party()
	else:
		for hero in party:
			hero.hp = hero.max_hp
			hero.guarding = false
			hero.attack_stacks = 0
			hero.defense_stacks = 0
			hero.focus_stacks = 0
	if is_instance_valid(overlay):
		overlay.queue_free()
	screen = null
	transition = null
	active = false
	if is_instance_valid(player):
		player.input_locked = false

