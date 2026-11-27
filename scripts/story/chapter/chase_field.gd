extends Control
signal moved(seconds: float)
signal enemy_seen
signal target_acquired
signal encounter(id: int, preemptive: bool)
const Lockon = preload("res://scripts/field_lockon.gd")
const TILE := 32.0
const WORLD := Vector2i(40,26)
const BASE := "res://assets/art_overhaul/2026-11-23/fields/style_c/runtime/"
var actor: Node2D
var partner: Node2D
var tile := Vector2i(19,16)
var follower_tile := Vector2i(20,16)
var position_px := Vector2(tile)*TILE
var partner_px := Vector2(follower_tile)*TILE
var facing := "up"
var moving := false
var move_time := 0.0
var duration := 0.24
var from := Vector2.ZERO
var destination := Vector2i.ZERO
var partner_from := Vector2.ZERO
var partner_to := Vector2.ZERO
var camera := Vector2.ZERO
var clock := 0.0
var interactive := false
var mode := "confrontation"
var sequence := ""
var sequence_time := 0.0
var monster: Texture2D
var floor_art: Texture2D
var props: Array = []
var slime_positions: Array[Vector2] = []
var slime_from: Array[Vector2] = []
var slime_to: Array[Vector2] = []
var slime_step: Array[float] = [1.0,1.0,1.0,1.0]
var homes := [Vector2i(9,7),Vector2i(31,6),Vector2i(8,21),Vector2i(32,21)]
var defeated: Array[int] = []
var locked := -1
var cast_target := -1
var cast_time := -1.0
var run_time := 0.0
var ai_time := 0.0
var rng := RandomNumberGenerator.new()
var saw_enemy := false
var drew_chains := false
var cast_frame := 0
var font: SystemFont
var expressions: Array[Texture2D] = []
var event_poses: Texture2D
var chain_layer: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rng.randomize()
	chain_layer = Node2D.new()
	chain_layer.z_index = 1000
	chain_layer.draw.connect(_draw_chain)
	add_child(chain_layer)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	floor_art = load(BASE+"paving.png")
	monster = load("res://assets/prologue/monster.png")
	event_poses = load("res://assets/prologue/chapter/event-poses.png")
	for id in ["chuheun","yeonwoo"]:
		expressions.append(load("res://assets/sprites/battle/"+id+"-expressive.png"))
	var Actor = load("res://scripts/field_actor.gd")
	actor = Actor.new()
	add_child(actor)
	actor.scale = Vector2(2,2)
	actor.configure(load("res://assets/character_overhaul/2026-11-23/field_c/runtime/chuheun-walk.png"))
	partner = Actor.new()
	add_child(partner)
	partner.scale = Vector2(2,2)
	partner.configure(load("res://assets/character_overhaul/2026-11-23/field_c/runtime/yeonwoo-walk.png"))
	for spec in [["shop",2,2,5,3],["house",13,2,5,3],["bakery",24,1,5,3],["warehouse",33,11,5,4],["workshop",2,12,4,4],["shop",11,9,5,3],["house",24,8,5,3],["lamp",16,12,1,2],["lamp",24,12,1,2],["tree",26,16,2,2],["bench",18,22,3,1],["house",15,22,3,2]]:
		props.append({"art":load(BASE+spec[0]+".png"),"rect":Rect2i(spec[1],spec[2],spec[3],spec[4])})
	for home in homes:
		slime_positions.append(Vector2(home)*TILE)
		slime_from.append(Vector2(home)*TILE)
		slime_to.append(Vector2(home)*TILE)
	preload("res://scripts/story/chapter/gold_palette.gd").apply(self)
	_update_camera()
	_update_actors()

func blocked(at: Vector2i) -> bool:
	if at.x<1 or at.y<1 or at.x>=WORLD.x-1 or at.y>=WORLD.y-1: return true
	for prop in props:
		if prop.rect.has_point(at): return true
	return false

func can_step(at: Vector2i, target: Vector2i) -> bool:
	var d := target-at
	if d==Vector2i.ZERO or absi(d.x)>1 or absi(d.y)>1 or blocked(target): return false
	return d.x==0 or d.y==0 or (not blocked(at+Vector2i(d.x,0)) and not blocked(at+Vector2i(0,d.y)))

func begin_move(d: Vector2i, dash: bool) -> bool:
	if not interactive or moving or cast_time>=0 or not can_step(tile,tile+d): return false
	destination = tile+d
	from = position_px
	partner_from = partner_px
	partner_to = position_px
	facing = direction(d)
	partner.facing = direction(Vector2i((partner_to-partner_from)/TILE))
	duration = 0.24*Vector2(d).length()/(2.0 if dash else 1.0)
	move_time = 0.0
	moving = true
	actor.dashing = dash
	partner.dashing = dash
	actor.begin_step()
	partner.begin_step()
	return true

func direction(d: Vector2i) -> String:
	if d.x != 0: return "right" if d.x>0 else "left"
	return "down" if d.y>0 else "up"

func tick(delta: float) -> void:
	clock += delta
	if sequence != "":
		sequence_time += delta
		if sequence == "draw":
			actor.set_chain_progress(minf(0.3,sequence_time*0.25))
			partner.action_offset = Vector2(0,-sin(minf(1,sequence_time/1.25)*PI)*0.7)
		elif sequence == "split":
			for i in 4: slime_positions[i] = (Vector2(19,13)*TILE).lerp(Vector2(homes[i])*TILE,clampf((sequence_time-0.5)/1.5,0,1))
		_update_actors()
		queue_redraw()
		return
	if interactive:
		if cast_time>=0:
			cast_time += delta
			actor.set_chain_progress(clampf(cast_time/0.5,0,1))
			if cast_time>=0.5:
				var target := cast_target
				cast_time = -1
				actor.set_chain_progress(1)
				interactive = false
				encounter.emit(target,true)
		elif moving:
			move_time = minf(move_time+delta,duration)
			var p := move_time/duration
			position_px = from.lerp(Vector2(destination)*TILE,p)
			partner_px = partner_from.lerp(partner_to,p)
			actor.set_step_progress(p)
			partner.set_step_progress(p)
			moved.emit(delta)
			if p>=1:
				follower_tile = tile
				tile = destination
				moving = false
				actor.end_step()
				partner.end_step()
		else:
			var d := Vector2i(int(Input.is_action_pressed("ui_right"))-int(Input.is_action_pressed("ui_left")),int(Input.is_action_pressed("ui_down"))-int(Input.is_action_pressed("ui_up")))
			if d!=Vector2i.ZERO: begin_move(d,Input.is_physical_key_pressed(KEY_SHIFT))
		if mode == "chase":
			for i in 4:
				if slime_step[i]<1.0:
					slime_step[i] = minf(1.0,slime_step[i]+delta/0.28)
					slime_positions[i] = slime_from[i].lerp(slime_to[i],smoothstep(0,1,slime_step[i]))
			_update_camera()
			ai_time += delta
			if ai_time>=0.65 and not moving and cast_time<0:
				ai_time = 0
				for i in 4:
					if i in defeated: continue
					var at := Vector2i((slime_positions[i]/TILE).round())
					if Vector2(at-tile).length()>6: continue
					var d := Vector2i(signi(at.x-tile.x),signi(at.y-tile.y))
					var next := at+d
					if can_step(at,next) and Vector2(next-homes[i]).length()<3:
						slime_from[i] = slime_positions[i]
						slime_to[i] = Vector2(next)*TILE
						slime_step[i] = 0.0
			refresh_lock()
			if interactive and not moving and cast_time<0:
				for i in 4:
					if i not in defeated and position_px.distance_to(slime_positions[i])<TILE*0.65:
						interactive = false
						encounter.emit(i,false)
						break
	_update_camera()
	_update_actors()
	chain_layer.queue_redraw()
	queue_redraw()

func refresh_lock() -> void:
	var candidates: Array = []
	for i in 4:
		if i in defeated: continue
		var at := slime_positions[i]-camera
		if Rect2(0,60,768,420).has_point(at) and not saw_enemy:
			saw_enemy = true
			enemy_seen.emit()
		if Lockon.in_range(Vector2i((position_px/TILE).round()),Vector2i((slime_positions[i]/TILE).round())):
			candidates.append(i)
	var chosen: Variant = Lockon.choose(candidates,locked if locked>=0 else null,rng)
	var old := locked
	locked = int(chosen) if chosen!=null else -1
	if locked>=0 and old<0: target_acquired.emit()

func request_chain() -> bool:
	if not interactive or moving or cast_time>=0 or locked<0 or locked in defeated: return false
	cast_target = locked
	cast_time = 0
	facing = direction(Vector2i(slime_positions[locked]/TILE)-tile)
	actor.facing = facing
	actor.set_chain_progress(0)
	return true

func begin_sequence(id: String) -> void:
	sequence = id
	sequence_time = 0
	interactive = false
	if id == "draw": drew_chains = true
	if id in ["relax","smile"]: facing = "down"
	queue_redraw()

func end_sequence() -> void:
	sequence = ""
	actor.set_chain_progress(1.0)
	partner.action_offset = Vector2.ZERO
	actor.show()
	partner.show()
	queue_redraw()

func _update_camera() -> void:
	camera = position_px-Vector2(368,330)
	camera.x = clampf(camera.x,0,WORLD.x*TILE-768)
	camera.y = clampf(camera.y,-40,WORLD.y*TILE-480)

func _update_actors() -> void:
	actor.position = (position_px-camera+Vector2(-16,-32)).round()
	partner.position = (partner_px-camera+Vector2(-16,-32)).round()
	actor.facing = facing
	if mode == "confrontation": partner.facing = "up"
	if sequence in ["relax","smile"]:
		actor.hide()
		partner.hide()

func _draw() -> void:
	if floor_art==null: return
	for y in WORLD.y:
		for x in WORLD.x:
			var at := Vector2(x,y)*TILE-camera
			if at.x< -TILE or at.y< -TILE or at.x>768 or at.y>672: continue
			draw_texture_rect_region(floor_art,Rect2(at,Vector2.ONE*TILE),Rect2(Vector2(x%4,y%4)*floor_art.get_width()/4.0,Vector2.ONE*floor_art.get_width()/4.0),Color("788ca6"))
	for prop in props:
		var r: Rect2i = prop.rect
		draw_texture_rect(prop.art,Rect2(Vector2(r.position)*TILE-camera,Vector2(r.size)*TILE),false)
	if mode == "confrontation" and sequence != "split":
		var pos := Vector2(19,13)*TILE-camera-Vector2(32,64)
		var amp := 5.0 if sequence=="roar" else 1.5
		for i in 12:
			draw_texture_rect_region(monster,Rect2(pos+Vector2(sin(clock*4+i)*amp,i*8),Vector2(96,8.4)),Rect2(0,i*monster.get_height()/12.0,monster.get_width(),monster.get_height()/12.0))
	if mode=="chase" or sequence=="split":
		for i in 4:
			if i in defeated: continue
			var pos := slime_positions[i]-camera
			var pulse := sin(clock*4+i)*1.5
			draw_texture_rect(monster,Rect2(pos+Vector2(-4, -12-pulse),Vector2(40,40+pulse)),false)
			if locked==i:
				var marker := pos+Vector2(16,-22)
				draw_arc(marker,9,0,TAU,20,Color("f4d07a"),2)
				draw_line(marker-Vector2(13,0),marker+Vector2(13,0),Color("f4d07a"),1)
				draw_line(marker-Vector2(0,13),marker+Vector2(0,13),Color("f4d07a"),1)
	if sequence=="split" and sequence_time<0.6:
		var centre := Vector2(19,13)*TILE-camera+Vector2(16,0)
		var burst := sequence_time/0.6
		for i in 12:
			var ray := Vector2.from_angle(i*TAU/12.0)
			draw_circle(centre+ray*(12+burst*54),4*(1-burst),Color(0.2,0.22,0.38,1-burst))
	if drew_chains and mode=="confrontation":
		for pos in [position_px,partner_px]:
			var hand: Vector2 = pos-camera+Vector2(25,18)
			for i in (mini(6,int(sequence_time*6)) if sequence=="draw" else 6):
				draw_arc(hand+Vector2(i*1.5,i*2.0),2,0,TAU,8,Color("8bb6df"),1)
	if sequence in ["relax","smile"]:
		for i in 2:
			var pos: Vector2 = (position_px if i==0 else partner_px)-camera
			var frame := (3 if sequence_time<2.0 else 4) if sequence=="relax" else (0 if i==0 else 4)
			draw_texture_rect_region(event_poses,Rect2(pos+Vector2(-8,-16),Vector2(48,48)),Rect2(frame*64,i*64,64,64))
		if sequence=="smile": draw_string(font,partner_px-camera+Vector2(22,-18),"훗",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e4c57e"))

func _draw_chain() -> void:
	if cast_time>=0:
		var start: Vector2 = actor.position+actor.chain_socket()*actor.scale
		var target: Vector2 = slime_positions[cast_target]-camera+Vector2(16,8)
		var t := smoothstep(0.20,0.44,cast_time)
		var end := start.lerp(target,t)
		for i in maxi(1,int(start.distance_to(end)/5)):
			var p := float(i)/maxf(1,start.distance_to(end)/5)
			var pos := start.lerp(end,p)+Vector2(0,-sin(p*PI)*14*(1-t))
			chain_layer.draw_arc(pos,2.2,0,TAU,8,Color(0.25,0.55,1.0,0.3),4)
			chain_layer.draw_arc(pos,2,0,TAU,8,Color("b3d5f2"),1.5)
