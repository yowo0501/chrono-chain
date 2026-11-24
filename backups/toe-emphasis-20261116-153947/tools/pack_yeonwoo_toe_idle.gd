extends SceneTree
const ROOT := "res://assets/sprites/yeonwoo-toe-idle/"

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(ROOT+"source.png"))
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x,y)
			color.a = 1.0 if color.a>=0.5 else 0.0
			source.set_pixel(x,y,color)
	var size := Vector2i(source.get_width()/4,source.get_height()/2)
	var neutral := source.get_region(Rect2i(Vector2i.ZERO,size))
	var box := neutral.get_used_rect()
	var old := load("res://assets/sprites/battle/yeonwoo-motion.png").get_image().get_region(Rect2i(0,0,384,240)) as Image
	var factor := float(old.get_used_rect().size.y)/box.size.y
	var head := neutral.get_region(Rect2i(0,box.position.y,size.x,roundi(box.size.y*0.22))).get_used_rect()
	var offset := Vector2i(128-roundi((head.position.x+head.size.x*0.5)*factor),232-roundi(box.end.y*factor))
	var atlas := Image.create(1536,480,false,Image.FORMAT_RGBA8)
	for pose in 8:
		var cell := source.get_region(Rect2i(Vector2i(pose%4,pose/4)*size,size))
		cell.resize(roundi(size.x*factor),roundi(size.y*factor),Image.INTERPOLATE_NEAREST)
		var output := Image.create(384,240,false,Image.FORMAT_RGBA8)
		# One common transform preserves the supporting heel and authored toe lift.
		output.blit_rect(cell,Rect2i(Vector2i.ZERO,cell.get_size()),offset)
		var bounds := output.get_used_rect()
		assert(bounds.position.x>0 and bounds.end.x<384 and bounds.position.y>0 and bounds.end.y<240)
		atlas.blit_rect(output,Rect2i(0,0,384,240),Vector2i(pose%4,pose/4)*Vector2i(384,240))
	atlas.save_png(ROOT+"toe-tap.png")
	FileAccess.open(ROOT+"registration.json",FileAccess.WRITE).store_string(JSON.stringify({"scale":factor,"offset":[offset.x,offset.y],"cell":[384,240],"columns":4,"rows":2,"cycle_seconds":1.6},"\t"))
	print("YEONWOO IDLE: 8 toe-tap poses, common scale and ground anchor")
	quit()
