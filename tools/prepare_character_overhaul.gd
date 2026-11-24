extends SceneTree
const BASE := "res://assets/character_overhaul/2026-11-23/v001/"
const CELL := Vector2i(192,160)
const FOOT := Vector2i(64,148)
func _initialize() -> void:
	var report := {}
	for id in ["chuheun","yeonwoo"]:
		var src := Image.load_from_file(BASE+"source/"+id+"-battle.png")
		var sw := src.get_width()/4
		var sh := src.get_height()/4
		var first := opaque_bounds(src.get_region(Rect2i(0,0,sw,sh)))
		var factor := 112.0/first.size.y
		var atlas := Image.create(CELL.x*4,CELL.y*4,false,Image.FORMAT_RGBA8)
		var frames: Array = []
		var sockets := [Vector2(.70,.58),Vector2(.70,.58),Vector2(.61,.40),Vector2(.69,.55),Vector2(.33,.55),Vector2(.68,.38),Vector2(.83,.36),Vector2(.80,.49),Vector2(.66,.47),Vector2(.60,.34),Vector2(.63,.07),Vector2(.82,.19),Vector2(.34,.48),Vector2(.66,.86),Vector2(.64,.35),Vector2(.52,.87)]
		if id == "yeonwoo":
			sockets = [Vector2(.64,.58),Vector2(.64,.58),Vector2(.59,.39),Vector2(.71,.48),Vector2(.42,.57),Vector2(.65,.36),Vector2(.79,.36),Vector2(.80,.46),Vector2(.63,.49),Vector2(.56,.36),Vector2(.58,.07),Vector2(.77,.20),Vector2(.69,.56),Vector2(.62,.85),Vector2(.63,.34),Vector2(.51,.87)]
		for f in 16:
			var cell := src.get_region(Rect2i((f%4)*sw,(f/4)*sh,sw,sh))
			var bounds := opaque_bounds(cell)
			var bottom := bounds.end.y
			var foot_band := cell.get_region(Rect2i(0,maxi(0,bottom-14),sw,mini(14,bottom)))
			var feet := opaque_bounds(foot_band)
			var foot_x := feet.position.x+feet.size.x*0.5
			var offset := Vector2(FOOT)-Vector2(foot_x,bottom)*factor
			var resized := cell.get_region(bounds)
			resized.resize(roundi(bounds.size.x*factor),roundi(bounds.size.y*factor),Image.INTERPOLATE_NEAREST)
			hard_alpha(resized)
			var dst := Vector2i(f%4,f/4)*CELL+Vector2i((offset+Vector2(bounds.position)*factor).round())
			atlas.blit_rect(resized,Rect2i(Vector2i.ZERO,resized.get_size()),dst)
			var socket: Vector2 = offset+sockets[f]*Vector2(sw,sh)*factor
			frames.append({"socket":[socket.x,socket.y],"offset":[offset.x,offset.y],"factor":factor})
		assert(atlas.save_png(BASE+"runtime/"+id+"-battle.png")==OK)
		report[id] = frames
		print(id+" atlas "+str(src.get_size())+" -> "+str(atlas.get_size()))
	var file := FileAccess.open(BASE+"metadata/battle_frames.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	for i in 5:
		var id: String = ["A","B","C","D","E"][i]
		var src := Image.load_from_file(BASE+"candidates/"+id+".png")
		var sw := src.get_width()/4
		var sh := src.get_height()/2
		var atlas := Image.create(96*4,96*2,false,Image.FORMAT_RGBA8)
		for hero in 2:
			var first := opaque_bounds(src.get_region(Rect2i(0,hero*sh,sw,sh)))
			var factor := float([24,28,32,36,40][i])/first.size.y
			for pose in 4:
				var cell := src.get_region(Rect2i(pose*sw,hero*sh,sw,sh))
				var bounds := opaque_bounds(cell)
				var crop := cell.get_region(bounds)
				crop.resize(maxi(1,roundi(bounds.size.x*factor)),maxi(1,roundi(bounds.size.y*factor)),Image.INTERPOLATE_NEAREST)
				hard_alpha(crop)
				var offset := Vector2i(36-crop.get_width()/2,80-crop.get_height())
				atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(pose*96,hero*96)+offset)
		atlas.save_png(BASE+"candidates/"+id+"-native.png")
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

