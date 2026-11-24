extends SceneTree
const Battle=preload("res://scripts/story/chapter/lesson_battle.gd")
const Chapter=preload("res://scripts/story/chapter/prologue_chapter.gd")
const Field=preload("res://scripts/story/chapter/chase_field.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(text)
func clear(d: Control) -> void:
	for i in 100:
		if not d.active: return
		d.tick(100)
		d.advance_line()
func press(code: int) -> InputEventKey:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	return event
func run() -> void:
	var manager: Node=root.get_node("EncounterManager")
	root.get_node("Tutorial").enabled=false
	for attack_grade in ["perfect","normal","miss"]:
		for guard_grade in ["perfect","normal","miss"]:
			var party: Array=manager.party.duplicate(true)
			for i in 2:
				party[i].max_hp=500 if i==0 else 450
				party[i].hp=party[i].max_hp
				party[i].attack=90 if i==0 else 100
			var balance: Dictionary=manager.balance.duplicate(true)
			balance.monster_count=1
			balance.monster.max_hp=300
			balance.monster.attack=35
			var b:=Battle.new()
			b.setup(party,balance,RandomNumberGenerator.new())
			root.add_child(b)
			b.set_process(false)
			b.advance(1.1)
			clear(b.guide)
			b.select_command(3)
			check(b.phase==b.Phase.COMMAND,"Attack lesson blocks unrelated skills")
			b.select_command(0)
			var q: float=b.qte_elapsed
			b.advance(9)
			check(b.qte_elapsed==q,"Lesson does not consume attack time")
			b.guide.tick(100)
			b.guide.index=b.guide.lines.size()-1
			b.guide._set_line()
			b.guide.tick(100)
			b._input(press(KEY_SPACE))
			check(not b.guide.active and b.phase==b.Phase.ATTACK_QTE,"Dismiss key never submits the QTE too")
			b.qte_elapsed=float(balance.qte.duration)/8 if attack_grade=="perfect" else 0.0
			b._resolve_qte(attack_grade!="miss")
			check(b.last_grade==attack_grade,"Initial attack grading: "+attack_grade)
			if attack_grade=="normal": check(b.enemies[0].hp==210,"Ordinary hit deals exactly 90")
			for i in 150:
				if b.guide.active: break
				b.advance(0.1)
			check(b.guide.active and b.hero_index==1 and b.phase==b.Phase.COMMAND,"Guard highlight appears over the actual command button")
			check(b.guide.lines[0].source_paragraph==(91 if attack_grade=="miss" else 88),"Attack outcome selects correct script")
			clear(b.guide)
			b.select_command(1)
			clear(b.guide)
			for i in 150:
				if b.phase==b.Phase.GUARD_QTE: break
				b.advance(0.1)
			check(b.phase==b.Phase.GUARD_QTE and b.defending_index==1,"Opening enemy always attacks guarding Yeonwoo")
			b.qte_elapsed=float(balance.qte.duration)/8 if guard_grade=="perfect" else 0.0
			b._resolve_qte(guard_grade!="miss")
			check(b.last_grade==guard_grade,"Initial defense grading: "+guard_grade)
			for i in 150:
				if b.guide.active: break
				b.advance(0.1)
			var paragraphs: Array=[]
			for entry in b.guide.lines: paragraphs.append(int(entry.source_paragraph))
			if guard_grade=="miss":
				check(106 in paragraphs,"Guard failure includes embarrassed pose")
				check((109 in paragraphs)==(attack_grade=="miss"),"Comic angry branch only when both fail")
				check((111 in paragraphs)==(attack_grade!="miss"),"Successful attack has the other guard-failure branch")
			else: check(paragraphs==[115,116],"Successful defense proceeds without failure dialogue")
			b.free()
	var f:=Field.new()
	root.add_child(f)
	var visited: Dictionary={f.tile:true}
	var pending: Array[Vector2i]=[f.tile]
	while not pending.is_empty():
		var at: Vector2i=pending.pop_front()
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if not visited.has(at+d) and f.can_step(at,at+d):
				visited[at+d]=true
				pending.append(at+d)
	for home in f.homes: check(visited.has(home),"Every fleeing slime can be reached on foot")
	f.mode="chase"
	f.interactive=true
	Input.action_press("ui_right")
	f.tick(0)
	Input.action_release("ui_right")
	check(f.moving,"Actual arrow input starts a field step")
	f.tick(0.24)
	check(f.tile==Vector2i(20,16),"Field step reaches the adjacent tile")
	f.free()
	var c:=Chapter.new()
	root.add_child(c)
	c.set_process(false)
	c.guide.active=false
	c.guide.hide()
	c.mode="field"
	c.field.mode="chase"
	c.field.interactive=true
	c.field.slime_positions[0]=c.field.position_px+Vector2(64,-64)
	c.field.refresh_lock()
	c._input(press(KEY_ENTER))
	check(c.field.cast_time==0 and c.field.cast_target==0,"Enter launches the corner-of-5x5 locked target")
	c.field.tick(0.25)
	check(c.field.actor.action_progress>0 and c.field.actor.action_progress<1,"Homing chain uses the actual authored actor frames")
	c.field.tick(0.25)
	check(c.mode=="transition" and c.encounter_preemptive,"Cast opens a preemptive encounter")
	c.free()
	print("CHAPTER BRANCHES: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)


