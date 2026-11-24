extends SceneTree
const OLD = "res://assets/character_overhaul/2026-11-23/v001/runtime/chuheun-battle.png"
const BASE = "res://assets/character_overhaul/2026-11-23/v002/"
func _initialize():
	var old = Image.load_from_file(OLD)
	var src = Image.load_from_file(BASE+"source/chuheun-gentle-generated.png")
	for y in src.get_height():
		for x in src.get_width():
			var c = src.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			src.set_pixel(x,y,c)
	var out = old.duplicate()
	var board = Image.create(640,400,false,Image.FORMAT_RGBA8)
	board.fill(Color("#263141"))
	var frames = [0,1,2,4,5,6,7,8,14]
	for i in frames.size():
		var f = frames[i]
		var pos = Vector2i(f%4*192,f/4*160)
		var original = old.get_region(Rect2i(pos,Vector2i(192,160)))
		var generated = src.get_region(Rect2i(f%4*(src.get_width()/4),f/4*(src.get_height()/4),src.get_width()/4,src.get_height()/4))
		var bounds = original.get_used_rect()
		var crop = generated.get_region(generated.get_used_rect())
		crop.resize(bounds.size.x,bounds.size.y,Image.INTERPOLATE_NEAREST)
		var aligned = original.duplicate()
		aligned.fill(Color.TRANSPARENT)
		aligned.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),bounds.position)
		var rect = Rect2i(48,45,42,32)
		if f == 4: rect = Rect2i(54,45,42,32)
		if f == 6 or f == 7: rect = Rect2i(55,45,42,32)
		var before = original.get_region(rect)
		var after = aligned.get_region(rect)
		before.resize(126,96,Image.INTERPOLATE_NEAREST)
		after.resize(126,96,Image.INTERPOLATE_NEAREST)
		board.blit_rect(before,Rect2i(0,0,126,96),Vector2i(i%5*128,i/5*200))
		board.blit_rect(after,Rect2i(0,0,126,96),Vector2i(i%5*128,i/5*200+100))
		aligned.save_png(BASE+"source/aligned-%d.png"%f)
		var faces = [Rect2i(58,53,24,18),Rect2i(58,53,24,18),Rect2i(58,56,24,18),Rect2i(64,54,24,18),Rect2i(55,55,24,18),Rect2i(65,54,24,18),Rect2i(64,55,24,18),Rect2i(58,55,24,18),Rect2i(55,53,24,18)]
		var face: Rect2i = faces[i]
		for y in range(face.position.y,face.end.y):
			for x in range(face.position.x,face.end.x):
				if original.get_pixel(x,y).a > 0.6:
					var c = aligned.get_pixel(x,y+2)
					if c.a > 0.6:
						out.set_pixelv(pos+Vector2i(x,y),c)
	board.save_png(BASE+"review/face-alignment.png")
	out.save_png(BASE+"runtime/chuheun-battle.png")
	var preview = Image.create(576,320,false,Image.FORMAT_RGBA8)
	preview.fill(Color("#263141"))
	for i in 3:
		var f = [0,6,10][i]
		var im = out.get_region(Rect2i(f%4*192+32,f/4*160+28,96,128))
		im.resize(192,256,Image.INTERPOLATE_NEAREST)
		preview.blend_rect(im,Rect2i(0,0,192,256),Vector2i(i*192,32))
	preview.save_png(BASE+"review/chuheun-gentle-preview.png")
	quit()
