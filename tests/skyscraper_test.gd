extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func press() -> void:
	var e:=InputEventKey.new()
	e.keycode=KEY_ENTER
	e.physical_keycode=KEY_ENTER
	e.pressed=true
	root.push_input(e)
	var up:=InputEventKey.new()
	up.keycode=KEY_ENTER
	up.physical_keycode=KEY_ENTER
	root.push_input(up)
	await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art-reviews/prologue-chapter/"+name+".png")
func run() -> void:
	var router: Node=root.get_node("StoryRouter")
	router.open_scene(router.MENU)
	for i in 3: await process_frame
	var menu: Control=current_scene
	menu.set_process(false)
	check(menu.start_button.disabled,"Menu starts with gradual reveal")
	await press()
	check(current_scene==menu,"Reveal Enter must not also start the game")
	check(menu.mark.modulate.a==1 and menu.start_button.modulate.a==1 and not menu.start_button.disabled,"Enter immediately reveals logo and start")
	await capture("14-skyscraper-menu")
	await press()
	for i in 3: await process_frame
	var chapter: Control=current_scene
	chapter.set_process(false)
	check(chapter!=menu and chapter.mode=="opening","Next Enter starts prologue")
	check(chapter.roof.resource_path.ends_with("skyscraper-roof.png"),"Opening uses tall tower")
	chapter.guide.index=7
	chapter.guide._set_line()
	for i in 120: chapter.advance_time(1.0/60)
	var earlier: float=chapter.scroll
	check(chapter.descent_speed>=180,"Descent accelerates")
	chapter.guide.index=9
	chapter.guide._set_line()
	for i in 240: chapter.advance_time(1.0/60)
	check(chapter.descent_speed>=2000 and chapter.scroll>earlier+4000,"Rapid descent is much faster")
	check(chapter.shaft_blend==1 and chapter.shaft_layer.visible,"Infinite facade replaces finite image")
	await capture("15-skyscraper-descent")
	var prior: float=chapter.scroll
	for i in 1800: chapter.advance_time(1.0/60)
	check(chapter.scroll>prior+60000,"Waiting thirty seconds never reaches a bottom or stops")
	await capture("16-skyscraper-late-descent")
	chapter.guide.index=10
	chapter.guide._set_line()
	chapter.advance_time(0)
	check(not chapter.shaft_layer.visible,"Blackout hides facade before scene change")
	await capture("17-skyscraper-blackout")
	print("SKYSCRAPER: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
