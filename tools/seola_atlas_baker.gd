extends RefCounted
## Extract connected sprite silhouettes; generated sheets have uneven gutters.
static func bake() -> void:
	var source := Image.load_from_file("res://assets/sprites/battle/seola-cohesive-source.png")
	var pieces := silhouettes(source)
	assert(pieces.size() == 20,"Unified Seola sheet must contain twenty separate silhouettes")
	pieces.sort_custom(func(a, b):
		var ar := int((a.rect.end.y-170)/300)
		var br := int((b.rect.end.y-170)/300)
		return ar < br if ar != br else a.rect.position.x < b.rect.position.x)
	for group in 3:
		var cell := Vector2i(192,200) if group == 0 else Vector2i(224,224) if group == 1 else Vector2i(256,256)
		var columns := 4 if group == 0 else 3
		var rows := 2 if group == 0 else 3 if group == 1 else 1
		var count := 8 if group == 0 else 9 if group == 1 else 3
		var first := 0 if group == 0 else 8 if group == 1 else 17
		var atlas := Image.create(cell.x*columns,cell.y*rows,false,Image.FORMAT_RGBA8)
		for pose in count:
			var piece: Dictionary = pieces[first+pose]
			var rect: Rect2i = piece.rect
			var crop := Image.create(rect.size.x,rect.size.y,false,Image.FORMAT_RGBA8)
			for point in piece.pixels:
				var color := source.get_pixelv(point)
				color.a = 1
				crop.set_pixelv(point-rect.position,color)
			crop.resize(roundi(crop.get_width()*0.62),roundi(crop.get_height()*0.62),Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(pose%columns*cell.x+(cell.x-crop.get_width())/2,pose/columns*cell.y+cell.y-8-crop.get_height()))
		atlas.save_png("res://assets/sprites/battle/%s.png" % ["seola","seola-shield","seola-overhead"][group])

static func silhouettes(source: Image) -> Array:
	var width := source.get_width()
	var height := source.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var result: Array = []
	for y in height:
		for x in width:
			var start := y*width+x
			if visited[start] or source.get_pixel(x,y).a < 0.5:
				continue
			var pending: Array[int] = [start]
			var pixels: Array[Vector2i] = []
			var low := Vector2i(x,y)
			var high := low
			visited[start] = 1
			while not pending.is_empty():
				var index: int = pending.pop_back()
				var point := Vector2i(index%width,index/width)
				pixels.append(point)
				low = low.min(point)
				high = high.max(point)
				for step in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
					var next: Vector2i = point+step
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
						continue
					var next_index := next.y*width+next.x
					if visited[next_index]:
						continue
					visited[next_index] = 1
					if source.get_pixelv(next).a >= 0.5:
						pending.append(next_index)
			if pixels.size() > 2000:
				result.append({"rect":Rect2i(low,high-low+Vector2i.ONE),"pixels":pixels})
	return result
