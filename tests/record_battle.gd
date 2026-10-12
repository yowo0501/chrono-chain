extends SceneTree
## Deterministic rendering capture for reviewing the transition and both action sets.
var folder := ""
var frame_number := 0
const STEP := 0.06

func _initialize() -> void:
	call_deferred("run")

func capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("%03d.png" % frame_number))
	frame_number += 1

func action_clip(screen: Control) -> void:
	screen.select_command(0)
	screen.target_index = screen.hero_index
	screen.confirm_target()
	for i in 18:
		screen.advance(STEP)
		await capture()
	screen.qte_elapsed = 0.4
	screen._resolve_qte(true)
	for i in 14:
		screen.advance(STEP)
		await capture()

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../battle-preview/v3/frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.15).timeout
	for i in 6:
		await capture()
	var manager: Node = root.get_node("EncounterManager")
	manager.start_battle(main.get_node("Player"))
	manager.transition.set_process(false)
	while is_instance_valid(manager.transition):
		manager.transition.advance(STEP)
		if is_instance_valid(manager.screen):
			manager.screen.set_process(false)
		await capture()
	var screen: Control = manager.screen
	screen.set_process(false)
	screen.advance(1.1)
	for i in 32:
		screen.advance(STEP)
		await capture()
	await action_clip(screen)
	await action_clip(screen)
	# A separate continuous idle capture shows the shared alternating scheduler.
	folder = ProjectSettings.globalize_path("res://../battle-preview/v3/idle")
	DirAccess.make_dir_recursive_absolute(folder)
	frame_number = 0
	screen.phase = screen.Phase.COMMAND
	screen.pending = Callable()
	screen.delay = 0
	screen.action_kind = ""
	screen.hero_index = 0
	screen.special_actor = -1
	screen.next_special_actor = 0
	screen.special_wait = 0.5
	screen.heading = "아군 턴  /  강추흔"
	screen.message = "행동을 선택하세요"
	for i in 175:
		screen.advance(STEP)
		await capture()
	print("Captured %d animation frames to %s" % [frame_number, folder])
	quit()
