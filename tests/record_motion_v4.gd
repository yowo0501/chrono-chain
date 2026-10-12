extends SceneTree
const Screen = preload("res://scripts/battle/battle_screen.gd")
const STEP := 0.05
var screen: Control
var folder := ""
var frame_number := 0

func _initialize() -> void:
	call_deferred("run")

func capture(path: String = "") -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path if path != "" else folder.path_join("%03d.png" % frame_number))
	if path == "":
		frame_number += 1

func clip(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		screen.advance(STEP)
		await capture()

func run() -> void:
	folder = ProjectSettings.globalize_path("res://../battle-preview/v4/frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var manager: Node = root.get_node("EncounterManager")
	manager.reset_party()
	screen = Screen.new()
	screen.setup(manager.party, manager.balance, RandomNumberGenerator.new())
	root.add_child(screen)
	screen.set_process(false)
	screen.advance(1.1)
	await clip(3.2)
	screen.select_command(0)
	screen.confirm_target()
	await clip(2.4)
	screen.qte_elapsed = 0.4
	screen._resolve_qte(true)
	await clip(0.85)
	screen.select_command(0)
	screen.target_index = 1
	screen.confirm_target()
	await clip(2.8)
	# Capture several positions around a full rotation for pixel-level head/feet QA.
	for i in 6:
		screen.qte_elapsed = i * Screen.YEONWOO_SPIN_CYCLE / 6.0
		screen.queue_redraw()
		await capture(folder.get_base_dir().path_join("fixed-%d.png" % i))
	screen.qte_elapsed = 0.4
	screen._resolve_qte(true)
	await clip(0.85)
	print("V4 motion capture: %d frames" % frame_number)
	quit()
