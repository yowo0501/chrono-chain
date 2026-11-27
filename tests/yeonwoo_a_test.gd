extends SceneTree
var checks=0
func _initialize(): call_deferred("run")
func verify(ok,label):
	checks+=1
	assert(ok,label)
func run():
	var s=load("res://scripts/battle/battle_screen.gd").new()
	var manager=root.get_node("EncounterManager")
	manager.reset_party()
	var rng=RandomNumberGenerator.new()
	s.setup(manager.party.duplicate(true),manager.balance.duplicate(true),rng)
	root.add_child(s)
	s.set_process(false)
	for pair in [[0.0,0],[0.69,0],[0.71,1],[0.91,2],[1.29,2],[1.31,3],[1.59,3],[1.61,0]]:
		verify(s.idle_frame(1,pair[0])==pair[1],"A-era 1.6s standing cadence")
	verify(s.motion_textures[1].resource_path.contains("/yeonwoo_a/"),"A-era motion source is live")
	verify(s.textures[1].resource_path.contains("/yeonwoo_a/"),"A-era base is live")
	verify(s.expressive_textures[1].resource_path.contains("/yeonwoo_a/"),"A-era attacks are live")
	verify(s.fixed_windup_body.resource_path.contains("/yeonwoo_a/"),"A-era fixed windup is live")
	verify(s.motion_textures[0].resource_path.contains("/legacy_retarget/"),"Chuheun retained")
	var im=s.motion_textures[1].get_image()
	verify(im.get_size()==Vector2i(3072,1920),"16 full resolution motion frames")
	for i in 16:
		var box=im.get_region(Rect2i(i%4*768,i/4*480,768,480)).get_used_rect()
		verify(box.position.x>0 and box.position.y>0 and box.end.x<768 and box.end.y<480,"Motion frame not clipped")
	for t in [0.0,0.1,0.3,0.5,0.7]:
		verify(s.attack_frame(t) in [0,2,3,4,6,7],"Original attack phases")
	s.free()
	print("YEONWOO A: %d checks passed"%checks)
	quit()
