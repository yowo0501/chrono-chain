extends SceneTree
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		push_error(label)
		quit(1)
func run() -> void:
	var menu=load("res://scripts/story/title_menu.gd").new()
	root.add_child(menu)
	menu.set_process(false)
	check(menu.start_button.disabled and not menu.start_button.visible,"Start hidden during night fade")
	check(menu.mark.modulate.a==0,"Logo initially hidden")
	menu.advance_intro(2.5)
	check(menu.mark.modulate.a==0,"Night appears before logo")
	menu.advance_intro(1.2)
	check(menu.mark.modulate.a>0 and menu.mark.modulate.a<1 and not menu.start_button.visible,"Logo fades before button")
	menu.advance_intro(2.4)
	check(not menu.start_button.disabled and menu.start_button.visible,"Start becomes available last")
	var buttons:=0
	for child in menu.get_children():
		if child is Button: buttons+=1
	check(buttons==1,"Only one start button")
	menu.free()
	var chapter=load("res://scripts/story/chapter/prologue_chapter.gd").new()
	root.add_child(chapter)
	chapter.set_process(false)
	check(chapter.groups.victory.size()==1,"Removed both requested victory lines")
	check(chapter.groups.ending[2].text=="과거를 잃어버린 소년과,","Revised boy narration")
	check(chapter.groups.ending[3].text=="미래를 잃어버린 소녀의…라고 하면 될 것 같아요.","Revised girl narration")
	check(chapter.groups.logo[-1].text.ends_with("시작됩니다…"),"Final ellipsis")
	chapter._ending()
	chapter.guide.index=chapter.guide.lines.size()-1
	chapter.guide._set_line()
	chapter.advance_time(0)
	check(chapter.mode=="blackout" and chapter.guide.current.text=="로, 로고 띄워!","Blackout on logo-cue line")
	chapter.advance_time(10)
	check(chapter.mode=="blackout","Logo does not appear on a timer")
	chapter.guide.tick(100)
	var key:=InputEventKey.new()
	key.keycode=KEY_ENTER
	key.pressed=true
	chapter._input(key)
	check(chapter.mode=="logo" and chapter.guide.index==0 and chapter.timed_duration<=0,"Next input reveals full logo immediately")
	chapter.free()
	print("PROLOGUE REVISION: %d checks / 0 failures" % checks)
	quit()
