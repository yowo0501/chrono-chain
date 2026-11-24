extends SceneTree
const Chain = preload("res://scripts/chain_visual.gd")
const Actor = preload("res://scripts/battle/renewed_actor.gd")
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
	var actor := Actor.new()
	for index in 2:
		var im: Image = actor.textures[index].get_image()
		check(im.get_size()==Vector2i(1536,1920),"Registered 20-pose detailed battle atlas")
		var unique := {}
		for f in 20:
			var region := im.get_region(Rect2i((f%4)*384,(f/4)*384,384,384))
			var bounds := region.get_used_rect()
			check(bounds.has_area() and bounds.position.x>=0 and bounds.end.x<384 and bounds.end.y<=362,"Pose inside anchored battle cell")
			unique[hash(region.get_data())] = true
			var socket := actor.socket(index,f,Vector2.ZERO)
			check(socket.is_finite(),"Finite wrist socket")
		check(unique.size()>=14,"Distinct authored body poses")
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.active = false
	tutorial.enabled = false
	tutorial.view.hide()
	paused = false
	var field: Node2D = main.get_node("Field")
	var player: Node2D = main.get_node("Player")
	field.set_process(false)
	player.set_process(false)
	field.grace = 10000.0
	for symbol in field.symbols:
		symbol.free()
	field.symbols.clear()
	for direction in player.DIR_VECTOR:
		var delta: Vector2i = player.DIR_VECTOR[direction]
		var expected := Vector2(delta).normalized()
		check(Chain.axis8(Vector2(delta)).distance_to(expected)<0.00001,"Quantize exact "+direction)
		player.facing = direction
		player.sprite.facing = direction
		player.chain_victim = null
		for t in [0.35,0.5,0.64,0.8,0.94]:
			player.sprite.set_chain_progress(t)
			var points: PackedVector2Array = player.chain_geometry(t)
			check(points.size()==2,"Chain has fixed straight axis")
			check(absf((points[1]-points[0]).normalized().cross(expected))<0.00001,"No lateral snake bend "+direction)
			check(points[0].distance_to(player.sprite.chain_socket())<0.001,"Chain starts at animated wrist")
	check(player.chain_extension(0.2)==0 and player.chain_extension(0.64)>0.99 and player.chain_extension(1.0)==0,"Anticipate, full contact, recover")
	main.free()
	print("CHARACTER OVERHAUL: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

