extends "res://tests/preview_oct20.gd"
const REVIEW := "res://art-reviews/character-refresh/"

func shot(name: String) -> void:
	screen.queue_redraw()
	await capture(REVIEW+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(REVIEW)
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var tutorial := root.get_node("Tutorial")
	tutorial.enabled = false
	tutorial.active = false
	tutorial.view.hide()
	paused = false
	main.get_node("Field").set_process(false)
	main.get_node("Player").set_process(false)
	await capture(REVIEW+"field.png")
	main.free()
	await process_frame
	new_battle()
	await shot("battle")
	screen.hero_index = 1
	await shot("portrait-yeonwoo")
	for actor in 2:
		screen.hero_index = actor
		screen.action_index = actor
		screen.phase = Screen.Phase.ATTACK_QTE
		for pose in 6:
			screen.qte_elapsed = (pose+0.1)/5.0
			await shot("windup-%d-%d" % [actor,pose])
		screen.phase = Screen.Phase.RESOLVE
		screen.action_kind = "attack"
		for pose in 6:
			screen.fx_time = 0.8 - [0.05,0.15,0.25,0.45,0.60,0.75][pose]
			await shot("attack-%d-%d" % [actor,pose])
		screen.action_kind = "focus"
		screen.focus_elapsed = 0.55
		await shot("focus-%d" % actor)
		screen.action_kind = ""
		screen.phase = Screen.Phase.COMMAND
		screen.fx_time = 0
		screen.special_actor = actor
		screen.special_elapsed = 1.1
		await shot("idle-special-%d" % actor)
		screen.special_actor = -1
		screen.party[actor].guarding = true
		await shot("guard-%d" % actor)
		screen.party[actor].guarding = false
		screen.hurt_hero = actor
		screen.fx_time = 0.4
		await shot("hurt-%d" % actor)
		screen.hurt_hero = -1
		screen.fx_time = 0
	screen.free()
	new_battle()
	screen.select_command(3)
	screen.select_skill(0)
	screen.confirm_target()
	for stage in [screen.TimerSkill.Stage.PREP,screen.TimerSkill.Stage.JUMP,screen.TimerSkill.Stage.MORPH,screen.TimerSkill.Stage.AIM,screen.TimerSkill.Stage.THROW,screen.TimerSkill.Stage.FLIGHT,screen.TimerSkill.Stage.LIGHTNING,screen.TimerSkill.Stage.LAND]:
		screen.timer_cast.stage = stage
		screen.timer_cast.elapsed = 0.12 if stage != screen.TimerSkill.Stage.MORPH else 0.7
		await shot("timer-%d" % stage)
	screen.free()
	new_battle()
	screen.hero_index = 1
	screen.select_command(3)
	screen.select_skill(0)
	for stage in [screen.AssassinSkill.Stage.MORPH,screen.AssassinSkill.Stage.VANISH,screen.AssassinSkill.Stage.RETURN,screen.AssassinSkill.Stage.YAWN,screen.AssassinSkill.Stage.EMBARRASSED]:
		screen.assassin_cast.stage = stage
		screen.assassin_cast.elapsed = 0.7 if stage == screen.AssassinSkill.Stage.EMBARRASSED else 0.12
		await shot("assassin-%d" % stage)
	screen.free()
	for target in [0,1]:
		new_battle()
		screen.hero_index = 1
		screen.party[target].hp = 20
		screen.select_command(3)
		screen.select_skill(1)
		screen.target_index = target
		screen.confirm_target()
		screen.advance(1.6)
		await shot("heal-%d" % target)
		screen.free()
	new_battle()
	screen.select_command(3)
	screen.select_skill(1)
	screen.advance(0.7)
	await shot("thunder")
	screen.free()
	print("REFRESH PREVIEW: field, both heroes, normal actions and all special skills")
	quit()
