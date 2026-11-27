extends SceneTree
const OUT := "res://assets/character_overhaul/2026-11-24/legacy_retarget/review/"
const ROOT := "res://assets/character_overhaul/2026-11-23/v001/"
var screen: Control
var candidate_textures: Array[Texture2D] = []
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.content_scale_size = Vector2i(768,672)
	var manager := root.get_node("EncounterManager")
	screen = load("res://scripts/battle/battle_screen.gd").new()
	var random := RandomNumberGenerator.new()
	random.seed = 3
	var balance: Dictionary = manager.balance.duplicate(true)
	balance.monster_count = 1
	screen.setup(manager.party.duplicate(true),balance,random)
	root.add_child(screen)
	screen.set_process(false)
	screen.phase = screen.Phase.COMMAND
	await capture("battle-idle")
	for f in 56:
		screen.clock = f * 0.05
		screen.queue_redraw()
		await capture("idle-%02d"%f)
	for actor in 2:
		screen.hero_index = actor
		screen.action_index = actor
		screen.phase = screen.Phase.ATTACK_QTE
		screen.qte_elapsed = 0.3
		screen.queue_redraw()
		await capture("battle-windup-"+str(actor))
		screen.phase = screen.Phase.RESOLVE
		screen.action_kind = "attack"
		for f in 25:
			screen.fx_time = 0.8-f*0.8/24.0
			screen.clock = f/30.0
			screen.queue_redraw()
			await capture("attack-%d-%02d"%[actor,f])
		screen.fx_time = 0.52
		screen.queue_redraw()
		await capture("battle-strike-"+str(actor))
		screen.action_kind = "focus"
		screen.focus_elapsed = 0.45
		screen.queue_redraw()
		await capture("battle-focus-"+str(actor))
	screen.free()
	# Exercise the same skill renderers used by tutorial battles.
	for skill in ["timer","assassin","thunder","heal"]:
		screen = load("res://scripts/battle/battle_screen.gd").new()
		screen.setup(manager.party.duplicate(true),balance,random)
		root.add_child(screen)
		screen.set_process(false)
		screen.phase = screen.Phase.COMMAND
		screen.hero_index = 0 if skill in ["timer","thunder"] else 1
		screen.action_index = screen.hero_index
		for stack in ["attack_stacks","defense_stacks","focus_stacks"]:
			screen.party[screen.hero_index][stack] = 9
		if skill == "timer":
			screen._begin_timer()
			screen.timer_cast.stage = screen.TimerSkill.Stage.THROW
			screen.timer_cast.elapsed = 0.12
		elif skill == "assassin":
			screen._begin_assassin(screen.balance.special_skills.yeonwoo[0])
			screen.assassin_cast.stage = screen.AssassinSkill.Stage.MORPH
			screen.assassin_cast.elapsed = 0.45
		else:
			var definition: Dictionary
			for candidate in screen.balance.special_skills["chuheun" if screen.hero_index == 0 else "yeonwoo"]:
				if candidate.id == skill:
					definition = candidate
			screen._begin_support(definition)
			screen.support_cast.elapsed = 0.7
		screen.queue_redraw()
		await capture("skill-"+skill)
		screen.free()
	print("CHARACTER PREVIEWS: 5 field candidates, two real battle attack sequences")
	quit()


