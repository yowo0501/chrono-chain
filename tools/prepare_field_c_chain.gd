extends SceneTree
const BASE = "res://assets/character_overhaul/2026-11-23/field_c/"
func _initialize():
	var src = Image.load_from_file(BASE+"source/chuheun-chain.png")
	for y in src.get_height():
		for x in src.get_width():
			var c = src.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			src.set_pixel(x,y,c)
	var sw = src.get_width()/4
	var sh = src.get_height()/4
	var first = src.get_region(Rect2i(0,0,sw,sh)).get_used_rect()
	var factor = 256.0/first.size.y
	var out = Image.create(1024,4096,false,Image.FORMAT_RGBA8)
	var report = []
	var dirs = [Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]
	for f in 16:
		var cell = src.get_region(Rect2i(f%4*sw,f/4*sh,sw,sh))
		var bounds = cell.get_used_rect()
		var offset = Vector2(256,426.666667)-Vector2(bounds.position.x+bounds.size.x*0.5,bounds.end.y)*factor
		var crop = cell.get_region(bounds)
		crop.resize(roundi(crop.get_width()*factor),roundi(crop.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(f%2*512,f/2*512)+Vector2i((offset+Vector2(bounds.position)*factor).round()))
		var axis: Vector2 = dirs[f/2]
		var expected = Vector2(bounds.position)+Vector2(bounds.size)*Vector2(0.5+axis.x*0.38,0.48+axis.y*0.2)
		var best = 1.0e20
		var hand = expected
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				var c = cell.get_pixel(x,y)
				if c.a > 0.6 and c.r > 0.55 and c.g > 0.4 and c.b > 0.25 and c.r > c.g*1.05 and c.g > c.b*1.1:
					var d = expected.distance_squared_to(Vector2(x,y))
					if d < best:
						best = d
						hand = Vector2(x,y)
		hand = offset+hand*factor
		report.append({"tip":[hand.x,hand.y]})
	out.save_png(BASE+"runtime/chuheun-chain.png")
	var file = FileAccess.open(BASE+"metadata/chain_anchors.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
