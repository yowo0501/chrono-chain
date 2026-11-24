extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var main := load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	var manager: Node = root.get_node("EncounterManager")
	field.set_process(false)
	player.set_process(false)
	check(not main.has_node("Diorama"),"Main scene has no 3D renderer")
	var pending: Array[Node] = [main]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		check(not node is Node3D and not node is SubViewport,"Every live field node is 2D")
		for child in node.get_children():
			pending.append(child)
	check(field.has_node("Town2D"),"2D town is attached to the simulation grid")
	check(field.get_node("Town2D").art.size() == 9,"Nine detailed night-city assets load")
	check(field.width() == 128 and field.height() == 64,"Enlarged layout retained")
	check(player.sprite.visible and player.follower.visible,"Native 2D party sprites render")
	check(field.symbols.size() == 5 and field.lamps.size() == 16,"Encounter count and districts preserved")
	for y in field.height():
		for x in field.width():
			check(field.tile_kind(Vector2i(x,y)) != "F","No flowerbed tiles remain")
	var camera: Camera2D = player.get_node("Camera2D")
	check(camera.rotation == 0 and camera.zoom == Vector2.ONE,"Unrotated 2D camera")
	check(camera.limit_right == 2048 and camera.limit_bottom == 1050,"Camera follows full enlarged map with HUD room")
	var start := player.position
	player._move_to(player.grid_pos+Vector2i.RIGHT)
	player._advance_step(player.MOVE_TIME*0.5)
	check(player.position == start+Vector2(8,0),"Half-time reaches half a tile")
	check(player.sprite.current_frame > 0,"Walking pose follows travel")
	player._advance_step(player.MOVE_TIME*0.5)
	check(player.position == start+Vector2(16,0) and player.sprite.current_frame == 0,"No teleport or per-frame resize")
	main.free()
	print("PURE 2D FIELD: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
