extends SceneTree
## Import generated sprite art into fixed native 32px atlas cells.
const CELL := 32

func _initialize() -> void:
	for id in ["chuheun", "yeonwoo", "shadow", "boss"]:
		bake(id)
	quit()

func bake(id: String) -> void:
	var source := Image.load_from_file("res://assets/sprites/field/%s_hg_source.png" % id)
	var width := source.get_width() / 3
	var height := source.get_height() / 4
	var crops: Array[Image] = []
	var extent := 1
	for row in 4:
		for column in 3:
			var cell := source.get_region(Rect2i(column*width,row*height,width,height))
			# Preserve the tool's alpha; discard only antialiasing fringe at import.
			for y in cell.get_height():
				for x in cell.get_width():
					var color := cell.get_pixel(x,y)
					color.a = 1.0 if color.a >= 0.5 else 0.0
					cell.set_pixel(x,y,color)
			var bounds := cell.get_used_rect()
			assert(bounds.has_area())
			crops.append(cell.get_region(bounds))
			extent = maxi(extent, maxi(bounds.size.x,bounds.size.y))
	var factor := 28.0 / extent
	var frames: Array[Image] = []
	for crop in crops:
		crop.resize(maxi(1,roundi(crop.get_width()*factor)),maxi(1,roundi(crop.get_height()*factor)),Image.INTERPOLATE_NEAREST)
		var frame := Image.create(CELL,CELL,false,Image.FORMAT_RGBA8)
		frame.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i((CELL-crop.get_width())/2,30-crop.get_height()))
		frames.append(frame)
	# Same registered head for all three poses prevents face/size jitter.
	for row in 4:
		for pose in [1,2]:
			frames[row*3+pose].blit_rect(frames[row*3],Rect2i(0,0,CELL,16),Vector2i.ZERO)
	var atlas := Image.create(CELL*3,CELL*4,false,Image.FORMAT_RGBA8)
	for i in frames.size():
		atlas.blit_rect(frames[i],Rect2i(0,0,CELL,CELL),Vector2i(i%3,i/3)*CELL)
	assert(atlas.save_png("res://assets/sprites/field/%s_hg.png" % id) == OK)
	atlas.resize(384,512,Image.INTERPOLATE_NEAREST)
	atlas.save_png("res://tests/preview-%s-hg.png" % id)
	print("HG ATLAS: ",id," 96x128, registered 32px frames")
