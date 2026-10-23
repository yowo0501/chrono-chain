extends SceneTree
# Bake generated town objects into fixed 64px cells for nearest-neighbor 2D drawing.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/tilesets/hg_town_source.png")
	var regions := [Rect2i(50,130,500,420),Rect2i(560,130,500,420),Rect2i(1120,150,350,400),Rect2i(80,700,450,190),Rect2i(590,695,450,200),Rect2i(1200,600,160,315)]
	var sizes := [Vector2i(64,54),Vector2i(64,54),Vector2i(32,36),Vector2i(32,12),Vector2i(32,14),Vector2i(14,32)]
	var atlas := Image.create(192,128,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for i in regions.size():
		var cut := source.get_region(regions[i])
		for y in cut.get_height():
			for x in cut.get_width():
				var color := cut.get_pixel(x,y)
				color.a = 1.0 if color.a >= 0.5 else 0.0
				cut.set_pixel(x,y,color)
		cut = cut.get_region(cut.get_used_rect())
		var ratio := minf(float(sizes[i].x)/cut.get_width(),float(sizes[i].y)/cut.get_height())
		cut.resize(maxi(1,roundi(cut.get_width()*ratio)),maxi(1,roundi(cut.get_height()*ratio)),Image.INTERPOLATE_NEAREST)
		var origin := Vector2i((i%3)*64+(64-cut.get_width())/2,(i/3)*64+64-cut.get_height())
		atlas.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),origin)
	atlas.save_png("res://assets/tilesets/hg_town.png")
	print("2D TOWN: six fixed-cell pixel assets")
	quit()
