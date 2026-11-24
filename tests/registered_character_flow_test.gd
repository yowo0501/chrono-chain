extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for i in 6:
		await process_frame
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await settle()
	# Current title is a separate prologue-only revision. Preserve its one-button UI.
	var router := root.get_node("StoryRouter")
	router.open_scene(router.TUTORIAL)
	await settle()
	assert(current_scene.name=="Main")
	var tutorial := root.get_node("Tutorial")
	assert(tutorial.active)
	tutorial.active = false
	tutorial.enabled = false
	tutorial.view.hide()
	paused = false
	var field: Node2D = current_scene.get_node("Field")
	var player: Node2D = current_scene.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	var manager := root.get_node("EncounterManager")
	manager.start_battle(player,{"light":true,"boss":false},null,field)
	manager.transition.set_process(false)
	manager._on_transition_covered()
	manager._on_transition_finished()
	await settle()
	assert(manager.screen.renewed_actor.textures[0].resource_path.contains("/character_overhaul/"))
	assert(manager.screen.renewed_actor.textures[1].resource_path.contains("/character_overhaul/"))
	manager.screen.set_process(false)
	manager.screen.phase = manager.screen.Phase.COMMAND
	manager.screen.queue_redraw()
	if DisplayServer.get_name() != "headless":
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://assets/character_overhaul/2026-11-23/v001/review/menu-tutorial-battle.png")
	print("REGISTERED TUTORIAL -> BATTLE: new duo atlases loaded from "+ProjectSettings.globalize_path("res://"))
	quit()

