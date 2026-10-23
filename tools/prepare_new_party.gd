extends SceneTree

func _initialize() -> void:
	var source := Image.load_from_file("res://assets/sprites/field/new-party-source.png")
	var rows := [0,282,515,751,1024]
	for actor in 2:
		var atlas := Image.create(192,256,false,Image.FORMAT_RGBA8)
		for row in 4:
			var factor := 0.225
			if actor == 1:
				var standing := source.get_region(Rect2i(768,rows[row],256,rows[row+1]-rows[row]))
				clean_alpha(standing)
				factor = float([53,55,58,53][row]) / standing.get_used_rect().size.y
			for col in 3:
				var cell := source.get_region(Rect2i((actor*3+col)*256,rows[row],256,rows[row+1]-rows[row]))
				clean_alpha(cell)
				var crop := cell.get_region(cell.get_used_rect())
				crop.resize(maxi(1,roundi(crop.get_width()*factor)),maxi(1,roundi(crop.get_height()*factor)),Image.INTERPOLATE_NEAREST)
				atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(col*64+(64-crop.get_width())/2,row*64+62-crop.get_height()))
		atlas.save_png("res://assets/sprites/field/%s_night.png" % ["seola","wiseong"][actor])
	source = Image.load_from_file("res://assets/sprites/battle/new-party-source.png")
	rows = [0,325,635,925,source.get_height()]
	var width := source.get_width()/4
	for actor in 2:
		var atlas := Image.create(768,400,false,Image.FORMAT_RGBA8)
		for pose in 8:
			var row := actor*2+pose/4
			var col := pose%4
			var cell := source.get_region(Rect2i(col*width,rows[row],width,rows[row+1]-rows[row]))
			clean_alpha(cell)
			var crop := cell.get_region(cell.get_used_rect())
			crop.resize(maxi(1,roundi(crop.get_width()*0.55)),maxi(1,roundi(crop.get_height()*0.55)),Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(col*192+(192-crop.get_width())/2,(pose/4)*200+192-crop.get_height()))
		atlas.save_png("res://assets/sprites/battle/%s.png" % ["seola","wiseong"][actor])
	source = Image.load_from_file("res://assets/sprites/battle/seola-shield-source.png")
	var shield_atlas := Image.create(672,672,false,Image.FORMAT_RGBA8)
	for pose in 9:
		var row := pose / 3
		var col := pose % 3
		var top := row*source.get_height()/3
		var bottom := (row+1)*source.get_height()/3
		var cell := source.get_region(Rect2i(col*512,top,512,bottom-top))
		clean_alpha(cell)
		var crop := cell.get_region(cell.get_used_rect())
		crop.resize(roundi(crop.get_width()*0.51),roundi(crop.get_height()*0.51),Image.INTERPOLATE_NEAREST)
		shield_atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(col*224+(224-crop.get_width())/2,row*224+216-crop.get_height()))
	shield_atlas.save_png("res://assets/sprites/battle/seola-shield.png")
	preload("res://tools/seola_atlas_baker.gd").bake()
	quit()

func clean_alpha(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var color := img.get_pixel(x,y)
			color.a = 1.0 if color.a >= 0.5 else 0.0
			img.set_pixel(x,y,color)
