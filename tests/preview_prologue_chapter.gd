extends SceneTree
const Chapter=preload("res://scripts/story/chapter/prologue_chapter.gd")
var c: Control
const OUT="res://art-reviews/prologue-chapter/"
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	c.queue_redraw()
	if c.guide.active: c.guide.tick(100)
	if is_instance_valid(c.battle):
		c.battle.queue_redraw()
		c.battle.guide.tick(100)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	c=Chapter.new()
	root.add_child(c)
	c.set_process(false)
	await capture("01-opening")
	c.guide.active=false
	c.guide.hide()
	c._fade_in()
	c.advance_time(2.3)
	await capture("02-confrontation")
	c.guide.active=false
	c.guide.hide()
	c.encounter_id=-1
	c._open_battle()
	c.battle.set_process(false)
	c.battle.advance(1.1)
	await capture("03-attack-lesson")
	c.battle.guide.active=false
	c.battle.guide.hide()
	c.battle.select_command(0)
	await capture("04-qte-lesson")
	c.battle.queue_free()
	c.battle=null
	await process_frame
	c.field.show()
	c.field.mode="chase"
	c.mode="field"
	c.field.interactive=true
	c.field.slime_positions[0]=c.field.position_px+Vector2(64,-32)
	c.field.tick(0)
	c.advance_time(0)
	await capture("05-field-lockon")
	c.field.interactive=false
	c.encounter_id=3
	c.packs_cleared=3
	c._open_battle()
	c.battle.set_process(false)
	c.battle.comic="focus"
	c.battle.comic_time=6.45
	await capture("06-flick")
	for moment in [4.4,5.9,6.3,6.7]:
		c.battle.comic_time=moment
		await capture("flick-%.1f" % moment)
	c.battle.comic=""
	c.battle._focus_lesson()
	await capture("07-focus-lesson")
	c.battle.queue_free()
	c.battle=null
	await process_frame
	c._ending()
	c.advance_time(1.1)
	await capture("08-ending")
	c.guide.active=false
	c.guide.hide()
	c._logo()
	c.advance_time(1.3)
	await capture("09-logo")
	c.guide.active=false
	c.guide.hide()
	c.field.show()
	c.mode="scene"
	c.field.begin_sequence("relax")
	c.advance_time(1.2)
	await capture("10-relax")
	c.field.begin_sequence("smile")
	c.advance_time(1.0)
	await capture("11-smile")
	c.field.end_sequence()
	c.lock_pending=false
	c.sight_pending=false
	c.lock_shown=true
	c.sight_shown=true
	c.mode="field"
	c.field.interactive=true
	c.field.request_chain()
	c.advance_time(0.43)
	await capture("12-homing-chain")
	c.hide()
	var menu=load("res://scripts/story/title_menu.gd").new()
	root.add_child(menu)
	menu.advance_intro(6.1)
	await capture("13-title")
	print("CHAPTER PREVIEW: 13 actual rendered scenes")
	quit()

