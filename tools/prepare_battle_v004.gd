extends SceneTree
const BASE = "res://assets/character_overhaul/2026-11-23/v004/"
const PREV = "res://assets/character_overhaul/2026-11-23/v003/"
const CELL = Vector2i(384,384)
const FOOT = Vector2(128,360)
func _initialize():
	var report = JSON.parse_string(FileAccess.get_file_as_string(PREV+"metadata/battle_frames.json"))
	for id in ["chuheun","yeonwoo"]:
		var src = Image.load_from_file(BASE+"source/"+id+"-motion.png")
		harden(src)
		var columns = 4 if id == "chuheun" else 2
		var rows = 3 if id == "chuheun" else 2
		var sw = src.get_width()/columns
		var sh = src.get_height()/rows
		var first = src.get_region(Rect2i(0,0,sw,sh)).get_used_rect()
		var factor = 256.0/first.size.y
		var atlas = Image.create(1536,3072,false,Image.FORMAT_RGBA8)
		var old = Image.load_from_file(PREV+"runtime/"+id+"-battle.png")
		atlas.blit_rect(old,Rect2i(Vector2i.ZERO,old.get_size()),Vector2i.ZERO)
		for f in columns*rows:
			var cell = src.get_region(Rect2i(f%columns*sw,f/columns*sh,sw,sh))
			var bounds = cell.get_used_rect()
			var offset = FOOT - Vector2(bounds.position.x+bounds.size.x*0.5,bounds.end.y)*factor
			var crop = cell.get_region(bounds)
			crop.resize(roundi(bounds.size.x*factor),roundi(bounds.size.y*factor),Image.INTERPOLATE_NEAREST)
			var target = f+20
			atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(target%4,target/4)*CELL+Vector2i((offset+Vector2(bounds.position)*factor).round()))
			var hand = Vector2(bounds.position.x+bounds.size.x*0.75,bounds.position.y+bounds.size.y*0.4)
			if id == "yeonwoo" or f >= 8:
				var top_skin = -1
				var total = Vector2.ZERO
				var count = 0
				for y in range(bounds.position.y,bounds.position.y+int(bounds.size.y*0.24)):
					for x in range(bounds.position.x,bounds.end.x):
						var c = cell.get_pixel(x,y)
						if c.a > 0.5 and c.r > 0.45 and c.r > c.g*1.08 and c.g > c.b*1.1:
							if top_skin < 0: top_skin = y
							if y < top_skin+12:
								total += Vector2(x,y)
								count += 1
				if count > 0: hand = total/count
			var socket = offset+hand*factor
			report[id].append({"socket":[socket.x,socket.y],"offset":[offset.x,offset.y],"factor":factor})
		atlas.save_png(BASE+"runtime/"+id+"-battle.png")
	var file = FileAccess.open(BASE+"metadata/battle_frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
func harden(im):
	for y in im.get_height():
		for x in im.get_width():
			var c = im.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			im.set_pixel(x,y,c)
