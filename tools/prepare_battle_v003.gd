extends SceneTree
const BASE := "res://assets/character_overhaul/2026-11-23/v003/"
const CELL := Vector2i(384,384)
const FOOT := Vector2i(128,360)
func _initialize() -> void:
	var report := {}
	for id in ["chuheun","yeonwoo"]:
		var src := Image.load_from_file(BASE+"source/"+id+"-battle.png")
		var sw := src.get_width()/4
		var sh := src.get_height()/5
		var first := opaque_bounds(src.get_region(Rect2i(0,0,sw,sh)))
		var factor := 256.0/first.size.y
		var atlas := Image.create(CELL.x*4,CELL.y*5,false,Image.FORMAT_RGBA8)
		var frames: Array = []
		var sockets := [Vector2(.70,.58),Vector2(.70,.58),Vector2(.61,.40),Vector2(.69,.55),Vector2(.70,.48),Vector2(.30,.46),Vector2(.60,.29),Vector2(.75,.34),Vector2(.66,.47),Vector2(.60,.34),Vector2(.63,.07),Vector2(.82,.19),Vector2(.34,.48),Vector2(.66,.86),Vector2(.64,.35),Vector2(.52,.87)]
		if id == "yeonwoo":
			sockets = [Vector2(.64,.58),Vector2(.64,.58),Vector2(.59,.39),Vector2(.71,.48),Vector2(.75,.53),Vector2(.79,.55),Vector2(.82,.30),Vector2(.88,.45),Vector2(.63,.49),Vector2(.56,.36),Vector2(.58,.07),Vector2(.77,.20),Vector2(.69,.56),Vector2(.62,.85),Vector2(.63,.34),Vector2(.51,.87)]
		for f in 20:
			if f >= 16: sockets.append(sockets[0])
			var rows: Array = [0,350,660,1005,1320,1717] if id == "chuheun" else [0,350,675,1035,1350,1717]
			var cols: Array = [0,229,458,687,916]
			if f/4 == 1: cols = [0,206,413,660,916] if id == "chuheun" else [0,220,448,685,916]
			if f/4 == 2 and id == "chuheun": cols = [0,229,450,667,916]
			var region := Rect2i(cols[f%4],rows[f/4],cols[f%4+1]-cols[f%4],rows[f/4+1]-rows[f/4])
			var cell := src.get_region(region)
			var bounds := opaque_bounds(cell)
			factor = 256.0 / (bounds.size.y if f >= 16 else first.size.y)
			var bottom := bounds.end.y
			var foot_band := cell.get_region(Rect2i(0,maxi(0,bottom-14),cell.get_width(),mini(14,bottom)))
			var feet := opaque_bounds(foot_band)
			var foot_x := feet.position.x+feet.size.x*0.5
			var offset := Vector2(FOOT)-Vector2(foot_x,bottom)*factor
			var resized := cell.get_region(bounds)
			resized.resize(roundi(bounds.size.x*factor),roundi(bounds.size.y*factor),Image.INTERPOLATE_NEAREST)
			hard_alpha(resized)
			var dst := Vector2i(f%4,f/4)*CELL+Vector2i((offset+Vector2(bounds.position)*factor).round())
			atlas.blit_rect(resized,Rect2i(Vector2i.ZERO,resized.get_size()),dst)
			var source_socket: Vector2 = Vector2(f%4*sw,f/4*sh)+sockets[f]*Vector2(sw,sh)
			var socket: Vector2 = offset+(source_socket-Vector2(region.position))*factor
			frames.append({"socket":[socket.x,socket.y],"offset":[offset.x,offset.y],"factor":factor})
		assert(atlas.save_png(BASE+"runtime/"+id+"-battle.png")==OK)
		report[id] = frames
		print(id+" atlas "+str(src.get_size())+" -> "+str(atlas.get_size()))
	var file := FileAccess.open(BASE+"metadata/battle_frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	quit()
func hard_alpha(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			im.set_pixel(x,y,c)
func opaque_bounds(im: Image) -> Rect2i:
	var left := im.get_width()
	var top := im.get_height()
	var right := 0
	var bottom := 0
	for y in im.get_height():
		for x in im.get_width():
			if im.get_pixel(x,y).a > 0.6:
				left = mini(left,x)
				right = maxi(right,x)
				top = mini(top,y)
				bottom = maxi(bottom,y)
	return Rect2i(left,top,right-left+1,bottom-top+1)




