extends SceneTree
const Chapter = preload("res://scripts/story/chapter/prologue_chapter.gd")
const Lockon = preload("res://scripts/field_lockon.gd")
var checks := 0
var failures := 0
var chapter: Control
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func clear_text(d: Control) -> void:
	for i in 160:
		if not d.active: return
		d.tick(100)
		d.advance_line()
func reach_battle() -> void:
	for i in 80:
		if is_instance_valid(chapter.battle):
			if is_instance_valid(chapter.transition): chapter.transition.advance(3)
			chapter.battle.set_process(false)
			return
		if chapter.guide.active: clear_text(chapter.guide)
		elif is_instance_valid(chapter.transition): chapter.transition.advance(3)
		else: chapter.advance_time(3)
	check(false,"Chapter reaches battle")
func fight(miss_attack: bool=false, miss_guard: bool=false) -> void:
	var b: Control = chapter.battle
	b.set_process(false)
	for safety in 1800:
		if b.guide.active:
			var before: float = b.qte_elapsed
			b.advance(5)
			check(is_equal_approx(before,b.qte_elapsed),"Dialogue freezes the QTE")
			clear_text(b.guide)
		elif b.comic != "": b.advance(7.1)
		elif b.phase == b.Phase.COMMAND:
			b.advance(0)
			if b.guide.active: continue
			b.select_command(b.required_command if b.required_command>=0 else 0)
		elif b.phase == b.Phase.SKILLS: b.select_skill(0)
		elif b.phase in [b.Phase.ATTACK_QTE,b.Phase.GUARD_QTE]:
			var attack: bool = b.phase==b.Phase.ATTACK_QTE
			var miss: bool = (attack and miss_attack and b.lesson_step=="attack_timing") or (not attack and miss_guard and b.lesson_step=="guard_timing")
			var target: int = b.Rules.living(b.enemies)[0] if attack else b.enemy_index
			b.qte_elapsed = b.Rules.position_marker(b.foe_position(target).y)*float(b.balance.qte.duration)/4
			b._resolve_qte(not miss)
		elif b.phase == b.Phase.RESULT:
			check(b.won,"Tutorial battle can be won")
			chapter._battle_finished(b.won)
			return
		else: b.advance(0.1)
	check(false,"Battle completes without a softlock")
func run() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 90
	var selected := {}
	for y in range(-4,5):
		for x in range(-4,5): check(Lockon.in_range(Vector2i.ZERO,Vector2i(x,y))==(absi(x)<=2 and absi(y)<=2),"Exact 5x5 lock-on boundary")
	for i in 100: selected[Lockon.choose([1,2,3],null,random)] = true
	check(selected.size()==3,"All eligible enemies can be chosen randomly")
	check(Lockon.choose([1,2,3],2,random)==2,"Lock remains stable while target is eligible")
	check(Lockon.choose([],2,random)==null,"Lock clears on leaving range")
	chapter = Chapter.new()
	root.add_child(chapter)
	chapter.set_process(false)
	check(chapter.party[0].max_hp==500 and chapter.party[0].attack==90 and chapter.party[1].max_hp==450 and chapter.party[1].attack==100,"Dedicated tutorial party values")
	reach_battle()
	check(chapter.battle.enemies.size()==1 and chapter.battle.enemies[0].max_hp==300 and chapter.battle.enemies[0].attack==35,"Opening monster stats")
	fight(true,true)
	chapter.advance_time(0.9)
	chapter.advance_time(2.3)
	clear_text(chapter.guide)
	check(chapter.mode=="field" and chapter.field.slime_positions.size()==4,"Boss splits into four field symbols")
	chapter._moved(3.01)
	check(chapter.dash_shown and chapter.guide.active,"Three seconds of movement prompts dash")
	clear_text(chapter.guide)
	for pack in 4:
		chapter.field.position_px = chapter.field.slime_positions[pack]+Vector2(64,64)
		chapter.field.tile = Vector2i(chapter.field.position_px/32)
		chapter.field.refresh_lock()
		chapter._flush_prompts()
		clear_text(chapter.guide)
		chapter._flush_prompts()
		clear_text(chapter.guide)
		chapter.field.interactive = true
		if chapter.field.cast_time<0: check(chapter.field.request_chain(),"Enter casts at acquired target")
		chapter.field.tick(0.5)
		reach_battle()
		check(chapter.battle.enemies.size()==[2,3,3,5][pack],"Pursuit encounter count %d" % pack)
		check(chapter.battle.field_context.initiative=="party","Homing chain grants preemptive battle")
		fight()
		clear_text(chapter.guide)
	check(chapter.packs_cleared==4,"All four packs completed")
	for i in 20:
		if chapter.completed: break
		if chapter.guide.active: clear_text(chapter.guide)
		else: chapter.advance_time(4)
	check(chapter.completed and chapter.mode=="logo","Ending dialogue and logo reach menu button")
	check(root.get_node("EncounterManager").party[0].max_hp==120,"Tutorial stats never overwrite normal party")
	chapter.queue_free()
	await process_frame
	print("PROLOGUE CHAPTER: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)

