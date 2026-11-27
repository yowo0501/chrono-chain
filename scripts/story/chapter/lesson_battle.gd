extends "res://scripts/battle/battle_screen.gd"
## Scripted lessons share the actual battle commands, damage, QTE and skill animations.
const Dialogue = preload("res://scripts/story/chapter/dialogue.gd")
var lesson := 0 # 0 opening, 1/2/3 pursuit, 4 focus/timer finale.
var guide: Control
var groups: Dictionary
var lesson_step := "start"
var required_command := -1
var attack_succeeded := false
var attack_feedback_pending := false
var guard_feedback_pending := false
var guard_failed := false
var multi_explained := false
var comic := ""
var comic_time := 0.0
var comic_poses: Texture2D
var flick_poses: Texture2D

func _ready() -> void:
	super._ready()
	groups = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue_chapter.json")).groups
	guide = Dialogue.new()
	add_child(guide)
	flick_poses = load("res://assets/prologue/chapter/flick-v2.png")
	comic_poses = load("res://assets/prologue/chapter/comic-poses.png")
	if lesson == 0:
		enemy_positions[0] = Vector2(555,340) + ENEMY_OFFSET
	preload("res://scripts/story/chapter/gold_palette.gd").apply(self)

func _resize() -> void:
	# This battle is already inside the chapter's 768x672 design canvas.
	scale = Vector2.ONE
	size = DESIGN
	queue_redraw()

func say(id: String, callback: Callable = Callable(), focus: Rect2 = Rect2()) -> void:
	guide.play(groups[id],callback,focus,false,id == "multi_qte" or id == "focus_after")

func advance(delta: float) -> void:
	if not is_instance_valid(guide): return
	guide.tick(delta)
	if guide.active:
		queue_redraw()
		return
	if comic != "":
		comic_time += delta
		clock += delta
		if comic == "focus" and comic_time >= 7.6:
			comic = "hold"
			say("flick_after",_return_from_flick)
		elif comic == "return" and comic_time >= 1.5:
			comic = ""
			_focus_lesson()
		queue_redraw()
		return
	super.advance(delta)
	if phase == Phase.COMMAND:
		if lesson_step == "start":
			if lesson == 0:
				lesson_step = "attack"
				required_command = 0
				say("attack_intro",Callable(),_command_rect(0))
			elif lesson == 4:
				lesson_step = "comic"
				say("final_intro",_start_comic)
			else: lesson_step = "free"
		elif lesson == 4 and lesson_step == "wait_next_turn" and hero_index == 0:
			lesson_step = "special"
			required_command = 3
			say("special_intro",Callable(),_command_rect(3))

func _start_comic() -> void:
	comic = "focus"
	comic_time = 0.0

func _return_from_flick() -> void:
	comic = "return"
	comic_time = 0.0

func _focus_lesson() -> void:
	lesson_step = "focus"
	required_command = 2
	command_index = 2
	say("focus_intro",Callable(),_command_rect(2))

func select_command(index: int) -> void:
	if guide.active or comic != "": return
	if required_command >= 0 and index != required_command:
		message = "강조된 행동으로 먼저 연습해 봅시다"
		command_index = required_command
		queue_redraw()
		return
	var step_before := lesson_step
	super.select_command(index)
	if phase == Phase.ATTACK_QTE:
		if step_before == "attack":
			lesson_step = "attack_timing"
			say("attack_qte",Callable(),Rect2(52,550,664,60))
		elif lesson == 1 and not multi_explained:
			multi_explained = true
			say("multi_qte",Callable(),Rect2(52,550,664,60))
	elif index == 1 and step_before == "guard":
		lesson_step = "guard_timing"
		required_command = -1
		say("guard_qte",Callable(),Rect2(52,550,664,60))
	elif index == 2 and step_before == "focus":
		party[0].focus_stacks = mini(3,int(balance.stack_cap))
		lesson_step = "wait_next_turn"
		required_command = -1
		say("focus_after")
	elif index == 3 and step_before == "special":
		lesson_step = "timer"
		required_command = -1
		say("timer_intro",Callable(),_skill_rect(0))

func select_skill(index: int) -> void:
	if guide.active: return
	if lesson_step == "timer" and (index >= skills().size() or str(skills()[index].id) != "timer"):
		message = "이번에는 타이머를 사용해 봅시다"
		return
	super.select_skill(index)
	if phase == Phase.TIMER: lesson_step = "free"

func _back_to_commands() -> void:
	if lesson_step == "timer": return
	super._back_to_commands()

func _resolve_qte(pressed: bool) -> void:
	if guide.active: return
	var attack := phase == Phase.ATTACK_QTE
	var guard := phase == Phase.GUARD_QTE
	# The single-enemy introduction teaches normal hit vs centre critical.
	var normal_hit := false
	var prior_hp := int(enemies[0].hp) if lesson == 0 else 0
	if lesson == 0 and attack and pressed and qte_elapsed < float(balance.qte.duration):
		normal_hit = Rules.grade(qte_elapsed,float(balance.qte.duration),true,float(balance.qte.perfect_half_width),2) == "normal"
		if normal_hit: qte_elapsed = float(balance.qte.duration)/8.0
	super._resolve_qte(pressed)
	if normal_hit:
		enemies[0].hp = maxi(0,prior_hp-int(party[hero_index].attack))
		last_grade = "normal"
		message = "HIT · %d" % int(party[hero_index].attack)
		float_text = str(party[hero_index].attack)
	if lesson == 0 and attack and lesson_step == "attack_timing":
		attack_succeeded = last_grade != "miss"
		attack_feedback_pending = true
	if lesson == 0 and guard and lesson_step == "guard_timing":
		guard_failed = last_grade == "miss"
		guard_feedback_pending = true

func _after_hero() -> void:
	if attack_feedback_pending:
		attack_feedback_pending = false
		lesson_step = "guard"
		required_command = 1
		var lines: Array = groups["attack_hit" if attack_succeeded else "attack_miss"].duplicate(true)
		lines.append_array(groups.guard_intro)
		super._after_hero()
		command_index = 1
		guide.play(lines,Callable(),_command_rect(1))
		return
	super._after_hero()

func _enemy_action() -> void:
	super._enemy_action()
	if lesson == 0 and lesson_step == "guard_timing" and action_kind == "enemy_windup":
		defending_index = 1
		message = "김연우에게 공격!"

func _after_enemy() -> void:
	if guard_feedback_pending:
		guard_feedback_pending = false
		lesson_step = "free"
		var lines: Array = []
		if guard_failed: lines.append_array(groups["guard_miss_only" if attack_succeeded else "guard_miss_both"])
		lines.append_array(groups.free_battle)
		guide.play(lines,_continue_after_guard)
		return
	super._after_enemy()

func _continue_after_guard() -> void:
	super._after_enemy()

func _timer_lightning_hit() -> void:
	super._timer_lightning_hit()
	if lesson == 4:
		for enemy in enemies: enemy.hp = 0

func _input(event: InputEvent) -> void:
	if is_instance_valid(guide) and guide.accept(event):
		get_viewport().set_input_as_handled()
		return
	if comic != "": return
	super._input(event)

func _comic_frame(frame: int, at: Vector2) -> void:
	_frame(comic_poses,frame,4,2,Rect2(at-FOOT_ANCHOR*ACTOR_SCALE,ANIMATION_CELL*ACTOR_SCALE))

func _draw_hero(index: int) -> void:
	if comic != "":
		var at: Vector2 = HERO_POS[index]
		if index == 0:
			var pose := 1 if comic_time<6.4 else 2
			if comic in ["hold","return"] or comic_time>=7.1: pose = 3
			if comic=="focus" and comic_time>=6.4 and comic_time<6.75:
				at += Vector2(sin((comic_time-6.4)*PI/0.35)*8,-sin((comic_time-6.4)*PI/0.35)*3)
			_draw_ground_shadow(at,68.0)
			_comic_frame(pose,at)
			if comic=="focus" and comic_time<2.0: _label("번쩍!",at+Vector2(15,-115),ORANGE,18)
		else:
			var near := HERO_POS[0]+Vector2(-59,0)
			if comic=="focus" and comic_time<2:
				_draw_ground_shadow(at,68.0)
				_draw_yeonwoo_idle(0,at,Color.WHITE)
			elif comic=="focus" and comic_time<4:
				_draw_ground_shadow(at,68.0)
				_comic_frame(4,at)
				_label("하아…",at+Vector2(30,-115),MUTED,18)
			else:
				var frame := 7
				var flip := false
				if comic=="return":
					var p := smoothstep(0,1.5,comic_time)
					at = near.lerp(at,p)
					frame = int(comic_time/0.16)%2
					at.y -= absf(sin(comic_time*PI/0.16))*1.2
					flip = HERO_POS[1].x<near.x
				elif comic=="hold":
					at = near
				elif comic_time<5.6:
					var p := smoothstep(4,5.6,comic_time)
					at = at.lerp(near,p)
					frame = int((comic_time-4)/0.16)%2
					at.y -= absf(sin((comic_time-4)*PI/0.16))*1.2
					flip = near.x<HERO_POS[1].x
				else:
					at = near
					frame = 2 if comic_time<5.85 else 3 if comic_time<6.2 else 4 if comic_time<6.4 else 5 if comic_time<6.58 else 6 if comic_time<7.1 else 7
				_draw_ground_shadow(at,68.0)
				var rect := Rect2(at-FOOT_ANCHOR*ACTOR_SCALE,ANIMATION_CELL*ACTOR_SCALE)
				if flip:
					rect.position.x = at.x+FOOT_ANCHOR.x*ACTOR_SCALE
					rect.size.x = -rect.size.x
				_frame(flick_poses,frame,4,2,rect)
				if comic=="focus" and comic_time>=6.4 and comic_time<6.58:
					var hit := HERO_POS[0]+Vector2(-2,-96)
					for ray in 5:
						var d := Vector2.from_angle(ray*TAU/5)
						draw_line(hit+d*3,hit+d*10,Color("f2d7a0"),1.5)
					_label("딱!",hit+Vector2(12,-14),ORANGE,21)
		return
	if index == 1 and is_instance_valid(guide) and guide.active and guide.current.has("expression"):
		_draw_ground_shadow(HERO_POS[1],68.0)
		_comic_frame(6 if guide.current.expression == "embarrassed" else 7,HERO_POS[1])
		return
	super._draw_hero(index)

func _draw_enemy(index: int) -> void:
	var dim := Vector2(200,144) if lesson == 0 else Vector2(90,58)
	_draw_slime_body(index,dim.x)
	if int(enemies[index].hp)<=0: return
	_hp(enemies[index],foe_position(index)+Vector2(-42,10),Color("d2a1b4"))
	_label(str(index+1),foe_position(index)+Vector2(-4,-dim.y-9),PAPER,14)

func _draw_qte() -> void:
	if lesson != 0 or phase != Phase.ATTACK_QTE:
		super._draw_qte()
		return
	_panel(Rect2(24,506,720,129))
	_label("Space / Enter · 가운데에 맞추면 크리티컬!",Vector2(48,535),BLUE,18)
	var cursor := Rules.cursor_at(qte_elapsed,float(balance.qte.duration),int(balance.qte.round_trips))
	draw_position_bar(cursor,Rect2(52,562,664,36),true)
	_label("중앙: 크리티컬 · 그 외: 일반 공격 · 두 번 왕복 후: 실패",Vector2(49,622),MUTED,13)

func _draw() -> void:
	super._draw()
	if guide == null: return
	if guide.active and lesson_step == "guard_timing" and phase != Phase.GUARD_QTE:
		draw_position_bar(0.0,Rect2(52,562,664,36),true,[0])
	if not guide.active and required_command>=0 and phase == Phase.COMMAND:
		draw_rect(_command_rect(required_command).grow(3),Color("f5d477"),false,3)
	if guide.active and lesson_step == "focus" and guide.index == 2:
		draw_rect(_command_rect(3).grow(4),Color("f5d477"),false,3)
