extends Node
## Field symbols and completed steps in dark districts initiate encounters.
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
var encounter_context: Dictionary = {}
var encounter_symbol: Node2D
var encounter_field: Node2D
var encounter_balance: Dictionary

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
		hero.shield_turns = 0
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
	if walker.field != null:
		walker.field.player_step_completed(walker)

func start_symbol_battle(walker: Node2D, symbol: Node2D, source_field: Node2D, context: Dictionary) -> void:
	start_battle(walker, context, symbol, source_field)

func balance_for_context(context: Dictionary, map_settings: Dictionary) -> Dictionary:
	var result := balance.duplicate(true)
	var limits := enemy_count_limits(context)
	if context.is_empty():
		result.monster_count = rng.randi_range(limits.x, limits.y)
		return result
	result.monster_count = 1
	if context.get("boss", false):
		var factor := maxf(0.2, 1.0 - int(context.dark_lamps) * float(map_settings.boss_reduction_per_dark_lamp))
		result.armored_monster.name = "골목의 주인"
		result.armored_monster.max_hp = roundi(float(map_settings.boss_hp) * factor)
		result.armored_monster.attack = roundi(float(map_settings.boss_attack) * factor)
		result.armored_monster.action_interval = 1
	else:
		result.monster_count = clampi(int(context.get("enemy_count", limits.x)), limits.x, limits.y)
		var prefix := "light" if context.get("light", false) else "dark"
		result.monster.max_hp = roundi(float(balance.monster.max_hp) * float(map_settings[prefix + "_hp_multiplier"]))
		result.monster.attack = roundi(float(balance.monster.attack) * float(map_settings[prefix + "_attack_multiplier"]))
	return result

func enemy_count_limits(context: Dictionary) -> Vector2i:
	# Missing field progress uses the early-game limit, not the final stretch.
	return Vector2i(3, 5) if int(context.get("dark_lamps", 4)) <= 2 else Vector2i(2, 4)

func start_battle(walker: Node2D, context: Dictionary = {}, symbol: Node2D = null, source_field: Node2D = null) -> void:
	if active or (is_instance_valid(source_field) and source_field.boss_defeated):
		return
	active = true
	player = walker
	player.input_locked = true
	steps = 0
	encounters += 1
	encounter_context = context.duplicate(true)
	if source_field != null:
		encounter_context.dark_lamps = source_field.dark_count()
	if not encounter_context.is_empty() and not encounter_context.get("boss", false):
		var limits := enemy_count_limits(encounter_context)
		encounter_context.enemy_count = rng.randi_range(limits.x, limits.y)
	encounter_symbol = symbol
	encounter_field = source_field
	armored_encounter = bool(context.get("boss", false)) if not context.is_empty() else choose_armored(rng.randf())
	encounter_balance = balance_for_context(encounter_context, source_field.settings if source_field != null else {})
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
	screen.setup(party, encounter_balance, rng, armored_encounter)
	if not encounter_context.is_empty():
		screen.field_context = encounter_context
		if encounter_context.get("boss", false):
			screen.heading = "골목의 주인"
			screen.message = "도시의 모든 가로등이 밝혀졌다"
		else:
			screen.heading = "빛 속의 그림자" if encounter_context.light else "어둠 속의 습격"
			screen.message = "%s · %d마리 출현" % ["적 위치를 보고 타이밍을 맞추세요" if encounter_context.light else "적과 판정선이 어둠에 가려졌다", screen.enemies.size()]
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
	if not active:
		return
	# Recover HP and clear the temporary guard stance; unspent stacks carry over.
	for hero in party:
		hero.hp = hero.max_hp
		hero.guarding = false
		hero.shield_turns = 0
	if is_instance_valid(overlay):
		overlay.process_mode = Node.PROCESS_MODE_DISABLED
		overlay.queue_free()
	screen = null
	transition = null
	active = false
	if is_instance_valid(player):
		player.input_locked = false
	if is_instance_valid(encounter_field):
		encounter_field.battle_resolved(encounter_symbol, won)
		if won and encounter_context.get("boss", false):
			# The encounter context remains authoritative even if its symbol is gone.
			encounter_field.complete_boss()
			get_node("/root/Tutorial").show_clear(encounter_field)
		else:
			get_node("/root/Tutorial").battle_ended(encounter_context)
	encounter_symbol = null
	encounter_field = null
	encounter_context = {}

