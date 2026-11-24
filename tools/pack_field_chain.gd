extends SceneTree
## Technical extraction only: preserve the generated complete poses and register feet.
const OUT := "res://assets/sprites/field-chain/"
# Chain-stub endpoints measured in the 256px source cells. They move with each pose.
const TIPS := [
	Vector2(72,211),Vector2(59,184),Vector2(53,139),Vector2(37,155),Vector2(56,210),Vector2(69,210),
	Vector2(170,200),Vector2(183,189),Vector2(65,130),Vector2(21,139),Vector2(59,208),Vector2(172,203),
	Vector2(87,204),Vector2(64,184),Vector2(65,126),Vector2(232,136),Vector2(195,205),Vector2(92,205),
	Vector2(185,207),Vector2(196,190),Vector2(197,128),Vector2(222,132),Vector2(207,204),Vector2(183,207)
]

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(OUT+"source/chuheun.png"))
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x,y)
			pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
			source.set_pixel(x,y,pixel)
	var frames: Array[Image] = []
	var heights: Array[int] = []
	for row in 4:
		for col in 6:
			var a := Vector2i(roundi(source.get_width()*col/6.0),roundi(source.get_height()*row/4.0))
			var b := Vector2i(roundi(source.get_width()*(col+1)/6.0),roundi(source.get_height()*(row+1)/4.0))
			var tile := source.get_region(Rect2i(a,b-a))
			frames.append(tile)
			if col == 0:
				heights.append(tile.get_used_rect().size.y)
	heights.sort()
	var factor := 56.0/heights[2]
	var atlas := Image.create(96*6,96*4,false,Image.FORMAT_RGBA8)
	var entries := []
	for i in frames.size():
		var tile := frames[i]
		var bounds := tile.get_used_rect()
		assert(bounds.has_area() and bounds.position.x>0 and bounds.end.x<tile.get_width())
		var feet := tile.get_region(Rect2i(0,bounds.end.y-12,tile.get_width(),12)).get_used_rect()
		var center := feet.position.x+feet.size.x*0.5
		var offset := Vector2i(48-roundi(center*factor),88-roundi(bounds.end.y*factor))
		var tip: Vector2 = TIPS[i]*Vector2(tile.get_size())/Vector2(256,256)*factor+Vector2(offset)
		tile.resize(roundi(tile.get_width()*factor),roundi(tile.get_height()*factor),Image.INTERPOLATE_NEAREST)
		var cell := Image.create(96,96,false,Image.FORMAT_RGBA8)
		cell.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),offset)
		var packed := cell.get_used_rect()
		assert(packed.position.x>0 and packed.end.x<96 and packed.position.y>0 and absi(packed.end.y-88)<=1,"Attack cell clipped")
		atlas.blit_rect(cell,Rect2i(0,0,96,96),Vector2i(i%6,i/6)*96)
		entries.append({"tip":[tip.x,tip.y],"bounds":[packed.position.x,packed.position.y,packed.size.x,packed.size.y]})
	atlas.save_png(OUT+"chuheun.png")
	FileAccess.open(OUT+"anchors.json",FileAccess.WRITE).store_string(JSON.stringify(entries,"\t"))
	print("FIELD CHAIN: 24 whole-body poses, original field scale, registered chain endpoints")
	quit()
