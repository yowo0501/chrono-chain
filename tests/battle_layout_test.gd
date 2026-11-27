extends SceneTree
const Layout = preload("res://scripts/battle/battle_layout.gd")
const Screen = preload("res://scripts/battle/battle_screen.gd")
const Slime = preload("res://scripts/slime_visual.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Layout.ARENA.end.y <= 484,"22px clearance before bottom UI")
	var source := Rect2(10,20,200,100)
	for rect in [Rect2(-20,80,100,100),Rect2(700,450,100,100),Rect2(20,500,100,100),Rect2(800,500,-120,-100),Rect2(100,200,100,100)]:
		var clipped := Layout.clipped_regions(rect,source)
		if clipped.is_empty():
			check(not rect.abs().intersects(Layout.ARENA),"Only fully outside sprites disappear")
		else:
			check(Layout.ARENA.grow(0.01).encloses(clipped[0].abs()),"All texture pixels stay inside arena")
			check(source.grow(0.01).encloses(clipped[1]),"Cropping never reads another frame")
			check(is_equal_approx(clipped[1].size.x/clipped[0].size.abs().x,source.size.x/rect.size.abs().x),"Clipping preserves sprite scale")
	Slime.prepare_anchors()
	for frame in 16:
		var cell := Vector2(Slime.region_for(frame).size)
		for width in [90.0,112.0,200.0]:
			var size := Vector2(width,width*cell.y/cell.x)
			for foot in [Vector2(485,300),Vector2(630,440),Vector2(555,384),Vector2(760,520)]:
				var rect := Rect2(foot-size*Slime.anchors[frame],size)
				var clipped := Layout.clipped_regions(rect,Rect2(Slime.region_for(frame)))
				check(clipped.is_empty() or Layout.ARENA.grow(0.01).encloses(clipped[0].abs()),"All slime frames and sizes obey arena bounds")
	var manager = root.get_node("EncounterManager")
	manager.reset_party()
	var screen := Screen.new()
	var settings: Dictionary = manager.balance.duplicate(true)
	settings.monster_count = 5
	var rng := RandomNumberGenerator.new()
	screen.setup(manager.party.duplicate(true),settings,rng)
	for seed_value in 100:
		rng.seed = seed_value
		screen._place_enemies()
		for i in 5:
			var foot: Vector2 = screen.foe_position(i)
			check(Layout.ENEMY_FEET.grow(0.01).has_point(foot),"Every spawn remains on safe ground")
			check(foot.y+37 < 506,"Tutorial HP readout stays above commands")
			var marker: float = Screen.Rules.position_marker(foot.y)
			check(Screen.Rules.position_hit(marker,screen.enemy_positions,[0,1,2,3,4],0.04) == i,"Each confined enemy keeps a distinct timing target")
	screen.free()
	print("BATTLE LAYOUT: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
