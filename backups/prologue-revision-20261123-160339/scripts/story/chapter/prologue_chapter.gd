extends "res://scripts/story/story_screen.gd"
signal finished
const Dialogue = preload("res://scripts/story/chapter/dialogue.gd")
const Field = preload("res://scripts/story/chapter/chase_field.gd")
const LessonBattle = preload("res://scripts/story/chapter/lesson_battle.gd")
const Transition = preload("res://scripts/battle/encounter_transition.gd")
var groups: Dictionary
var guide: Control
var field: Control
var battle: Control
var transition: Control
var mode := "opening"
var elapsed := 0.0
var scroll := 0.0
var movement_seconds := 0.0
var dash_shown := false
var sight_shown := false
var lock_shown := false
var sight_pending := false
var lock_pending := false
var packs_cleared := 0
var encounter_id := -1
var encounter_preemptive := false
var timed := Callable()
var timed_duration := 0.0
var party: Array = []
var completed := false
var roof: Texture2D
var ending: Texture2D
var logo: Texture2D
var footer: Label
var objective: Label

func _ready() -> void:
	super._ready()
	get_node("/root/Tutorial").enabled = false
	groups = JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue_chapter.json")).groups
	roof = load("res://assets/prologue/chapter/rooftop.png")
	ending = load("res://assets/prologue/chapter/ending.png")
	logo = load("res://assets/prologue/logo-chain-lettering.png")
	field = Field.new()
	add_child(field)
	field.hide()
	field.moved.connect(_moved)
	field.enemy_seen.connect(_seen)
	field.target_acquired.connect(_locked)
	field.encounter.connect(_encounter)
	guide = Dialogue.new()
	guide.z_index = 4000
	add_child(guide)
	footer = label_at("F10 메뉴로",Rect2(24,649,720,22),12,Color("aabaca"))
	footer.z_index = 4001
	objective = label_at("",Rect2(20,12,728,36),16,Color("eed295"))
	objective.z_index = 4001
	var objective_style := StyleBoxFlat.new()
	objective_style.bg_color = Color(0.025,0.045,0.085,0.9)
	objective_style.content_margin_left = 8
	objective_style.content_margin_right = 8
	objective.add_theme_stylebox_override("normal",objective_style)
	party = get_node("/root/EncounterManager").balance.heroes.duplicate(true)
	for i in 2:
		party[i].max_hp = 500 if i==0 else 450
		party[i].attack = 90 if i==0 else 100
		party[i].hp = party[i].max_hp
		party[i].level = "?"
		party[i].attack_stacks = 0
		party[i].defense_stacks = 0
		party[i].focus_stacks = 0
		party[i].guarding = false
		party[i].shield_turns = 0
	guide.play(groups.opening,_fade_in)

func _process(delta: float) -> void:
	advance_time(delta)

func advance_time(delta: float) -> void:
	elapsed += delta
	objective.visible = mode=="field"
	objective.text = "흩어진 슬라임  %d / 4  ·  방향키 이동 / Shift 달리기 / Enter 체인" % packs_cleared
	guide.tick(delta)
	if mode=="opening":
		var target := float(guide.index)/maxf(1,groups.opening.size()-2)
		scroll = move_toward(scroll,minf(1,target),delta*(0.035 if guide.index<7 else 0.22 if guide.index<9 else 1.2))
	elif mode=="field":
		if not guide.active and timed_duration<=0:
			field.interactive = true
			_flush_prompts()
		field.tick(delta if not guide.active else 0.0)
	elif mode=="fade":
		field.modulate.a = clampf(elapsed/2.2,0,1)
		field.tick(delta)
	elif mode=="scene":
		field.tick(delta)
	if timed_duration>0:
		timed_duration -= delta
		if timed_duration<=0:
			var callback := timed
			timed = Callable()
			if callback.is_valid(): callback.call()
	if mode=="scene" and guide.active and guide.current.get("source_paragraph",0)==41:
		field.facing = "right"
	elif mode=="scene" and guide.active and guide.current.get("source_paragraph",0)==53:
		field.facing = "up"
	queue_redraw()

func later(seconds: float, callback: Callable) -> void:
	timed_duration = seconds
	timed = callback
	elapsed = 0

func _fade_in() -> void:
	mode = "fade"
	elapsed = 0
	field.show()
	field.modulate.a = 0
	later(2.2,_conversation)

func _conversation() -> void:
	mode = "scene"
	field.modulate.a = 1
	guide.play(groups.confrontation.slice(0,1),func(): later(0.8,_conversation_rest))

func _conversation_rest() -> void:
	field.facing = "right"
	guide.play(groups.confrontation.slice(1,10),_draw_chains)

func _draw_chains() -> void:
	field.facing = "up"
	field.begin_sequence("draw")
	later(1.25,func(): guide.play(groups.confrontation.slice(10),_roar))

func _roar() -> void:
	field.begin_sequence("roar")
	later(1.0,func(): _encounter(-1,false))

func _encounter(id: int, preemptive: bool) -> void:
	if mode=="battle" or mode=="transition": return
	encounter_id = id
	encounter_preemptive = preemptive
	mode = "transition"
	field.interactive = false
	guide.hide()
	transition = Transition.new()
	var image: Image = null
	if DisplayServer.get_name()!="headless": image = get_viewport().get_texture().get_image()
	transition.configure(image,Vector2(0.5,0.42))
	transition.covered.connect(_open_battle)
	transition.finished.connect(func():
		if is_instance_valid(battle): battle.set_process(true)
		transition.queue_free()
		transition = null
		mode = "battle")
	add_child(transition)
	transition.size = DESIGN
	transition.z_index = 3900

func _open_battle() -> void:
	guide.active = false
	guide.hide()
	objective.hide()
	field.hide()
	field.end_sequence()
	for hero in party:
		hero.hp = hero.max_hp
		hero.guarding = false
	var balance: Dictionary = get_node("/root/EncounterManager").balance.duplicate(true)
	balance.monster_count = 1 if encounter_id<0 else [2,3,3,5][packs_cleared]
	balance.monster.name = "검은 액체 괴물" if encounter_id<0 else "흩어진 슬라임"
	balance.monster.attack = 35 if encounter_id<0 else 12
	balance.monster.max_hp = 300 if encounter_id<0 else 100
	if packs_cleared==3 and encounter_id>=0:
		party[0].focus_stacks = 0
		party[0].attack_stacks = maxi(2,int(party[0].attack_stacks))
	battle = LessonBattle.new()
	battle.lesson = 0 if encounter_id<0 else packs_cleared+1
	var random := RandomNumberGenerator.new()
	random.randomize()
	battle.setup(party,balance,random)
	battle.field_context = {"light":true,"initiative":"party" if encounter_preemptive else "normal"}
	battle.battle_finished.connect(_battle_finished)
	add_child(battle)
	battle.set_process(false)
	footer.hide()

func _battle_finished(won: bool) -> void:
	battle.set_process(false)
	battle.hide()
	battle.queue_free()
	battle = null
	footer.show()
	field.show()
	mode = "scene"
	if not won:
		guide.play([{"speaker":"안내","text":"다시 준비하고 도전해 봅시다. 체력을 모두 회복합니다."}],_retry)
		return
	if encounter_id<0:
		field.begin_sequence("roar")
		later(0.8,func():
			field.begin_sequence("split")
			later(2.2,_chase_start))
	else:
		field.defeated.append(encounter_id)
		field.locked = -1
		packs_cleared += 1
		if packs_cleared==4:
			guide.play(groups.victory,_relax)
		elif packs_cleared==1:
			guide.play(groups.next_pack,_resume_field)
		else: _resume_field()

func _retry() -> void:
	mode = "scene"
	_encounter(encounter_id,encounter_preemptive)

func _chase_start() -> void:
	field.end_sequence()
	field.mode = "chase"
	guide.play(groups.chase,_resume_field)

func _resume_field() -> void:
	mode = "field"
	field.interactive = true
	field.cast_time = -1
	field.refresh_lock()

func _moved(seconds: float) -> void:
	movement_seconds += seconds
	if movement_seconds>=3 and not dash_shown and not guide.active:
		dash_shown = true
		field.interactive = false
		guide.play(groups.dash,_resume_field)

func _seen() -> void:
	sight_pending = not sight_shown

func _locked() -> void:
	lock_pending = not lock_shown

func _flush_prompts() -> void:
	if field.moving: return
	if sight_pending:
		sight_pending = false
		sight_shown = true
		field.interactive = false
		guide.play(groups.sighting,_resume_field,Rect2(),false,true)
	elif lock_pending and field.locked>=0:
		lock_pending = false
		lock_shown = true
		field.interactive = false
		guide.play(groups.lockon,_cast_from_lesson,Rect2(),true)

func _cast_from_lesson() -> void:
	field.interactive = true
	field.request_chain()

func _relax() -> void:
	field.begin_sequence("relax")
	later(3.0,func():
		field.end_sequence()
		guide.play(groups.novel,_smile))

func _smile() -> void:
	field.begin_sequence("smile")
	later(2.0,_ending)

func _ending() -> void:
	field.hide()
	mode = "ending"
	elapsed = 0
	guide.play(groups.ending,_logo)

func _logo() -> void:
	mode = "logo"
	elapsed = 0
	later(1.2,func(): guide.play(groups.logo,_complete))

func _complete() -> void:
	completed = true
	var button := button_at("메인 화면으로",Rect2(224,555,320,56),return_to_menu)
	button.z_index = 4001
	button.grab_focus()
	finished.emit()

func return_to_menu() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/menu/title.tscn")

func _input(event: InputEvent) -> void:
	if mode in ["battle","transition"]: return
	if guide.accept(event):
		get_viewport().set_input_as_handled()
		return
	if mode=="field" and event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key in [KEY_ENTER,KEY_KP_ENTER]:
			field.request_chain()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0,0,768,672),Color("08111e"))
	if roof==null: return
	if mode=="opening":
		if guide.index<10:
			var h := float(roof.get_height())*768/roof.get_width()
			draw_texture_rect(roof,Rect2(0,-scroll*(h-672),768,h),false)
			if guide.index>=9:
				for i in 6: draw_texture_rect(roof,Rect2(0,-scroll*(h-672)+i*14,768,h),false,Color(1,1,1,0.07))
	elif mode=="ending":
		draw_texture_rect(ending,Rect2(0,65,768,432),false,Color(1,1,1,minf(1,elapsed)))
	elif mode=="logo":
		var zoom := lerpf(0.7,1.0,minf(1,elapsed/1.2))
		draw_texture_rect(logo,Rect2(Vector2(384,285)-Vector2(300,300)*zoom,Vector2(600,600)*zoom),false)
	if mode=="field":
		draw_rect(Rect2(0,0,768,50),Color("0b1727"))
		draw_string(story_font,Vector2(24,32),"흩어진 슬라임 추격  %d / 4   ·   방향키 이동 / Shift 달리기 / Enter 체인" % packs_cleared,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e4d3a6"))
