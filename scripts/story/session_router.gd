extends Node
## Owns only scene navigation/reset; the original tutorial remains its own scene.
const MENU := "res://scenes/menu/title.tscn"
const PROLOGUE := "res://scenes/prologue/prologue.tscn"
const TUTORIAL := "res://scenes/main/main.tscn"
var changing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		open_scene(MENU)

func open_scene(path: String) -> void:
	if changing:
		return
	changing = true
	_change.call_deferred(path)

func _change(path: String) -> void:
	# Autoloads survive scene changes. Clear paused onboarding and live combat first.
	var tutorial := get_node("/root/Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.seen.clear()
	tutorial.choices.clear()
	tutorial.selected = 0
	tutorial.previous_pause = false
	tutorial.first_battle_done = false
	tutorial.night_battle_done = false
	tutorial.field = null
	tutorial.view.hide()
	var manager := get_node("/root/EncounterManager")
	manager.active = false
	for child in manager.get_children():
		manager.remove_child(child)
		child.queue_free()
	manager.screen = null
	manager.overlay = null
	manager.transition = null
	manager.player = null
	manager.encounter_field = null
	manager.encounter_symbol = null
	manager.encounter_context.clear()
	manager.steps = 0
	manager.encounters = 0
	manager.reset_party()
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Cannot open scene: %s (%s)" % [path, error])
	changing = false
