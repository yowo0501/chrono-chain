extends SceneTree
## Import-only atlas registration. Original generated art is kept under source/.
const ROOT := "res://assets/characters/duo/"
var report := {}

func _initialize() -> void:
	for id in ["chuheun", "yeonwoo"]:
		pack(id + "-field", 8, 8, Vector2i(64,64), 52.0, 60)
		pack(id + "-battle", 6, 4, Vector2i(160,160), 124.0, 150)
	pack("standing", 4, 2, Vector2i(192,384), 350.0, 374)
	var file := FileAccess.open(ROOT + "atlas-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("DUO ART IMPORT: 128 field poses, 48 battle poses, 8 standing expressions")
	quit()

func pack(id: String, columns: int, rows: int, cell: Vector2i, body_height: float, baseline: int) -> void:
	var source := Image.load_from_file(ROOT + "source/" + id + ".png")
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	# Remove low-alpha matte residue from transparent exports, preserving solid pixels.
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x,y)
			if color.a < 0.5:
				source.set_pixel(x,y,Color.TRANSPARENT)
			else:
				color.a = 1.0
				source.set_pixel(x,y,color)
	var frames: Array[Image] = []
	var heights: Array[int] = []
	for row in rows:
		for col in columns:
			var start := Vector2i(roundi(float(col) * source.get_width() / columns), roundi(float(row) * source.get_height() / rows))
			var end := Vector2i(roundi(float(col+1) * source.get_width() / columns), roundi(float(row+1) * source.get_height() / rows))
			var frame := isolate_sprite(source.get_region(Rect2i(start, end-start)))
			frames.append(frame)
			if (columns == 8 and col == 0) or (columns == 6 and row == 0) or columns == 4:
				heights.append(frame.get_used_rect().size.y)
	heights.sort()
	var ratio := body_height / float(heights[heights.size()/2])
	var atlas := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var entries: Array = []
	for i in frames.size():
		var frame := frames[i]
		var bounds := frame.get_used_rect()
		assert(bounds.has_area(), "Missing sprite: " + id + "/" + str(i))
		var crop := frame.get_region(bounds)
		var dimensions := Vector2i(maxi(1,roundi(bounds.size.x*ratio)),maxi(1,roundi(bounds.size.y*ratio)))
		assert(dimensions.x < cell.x-2 and dimensions.y <= baseline, "Atlas cell too small: " + id + "/" + str(i))
		# Register the feet, not the outstretched weapon or hair, on the shared pivot.
		var foot_sum := 0.0
		var foot_count := 0
		for y in range(maxi(0, crop.get_height()-12),crop.get_height()):
			for x in crop.get_width():
				if crop.get_pixel(x,y).a > 0.5:
					foot_sum += x
					foot_count += 1
		var foot_x := foot_sum / maxf(1.0,foot_count)
		crop.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_NEAREST)
		var x := clampi(roundi(cell.x*0.5-foot_x*ratio),1,cell.x-dimensions.x-1)
		var at := Vector2i(x,baseline-dimensions.y)
		atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,dimensions),Vector2i(i%columns,i/columns)*cell+at)
		entries.append({"frame":i,"bounds":[at.x,at.y,dimensions.x,dimensions.y]})
	atlas.save_png(ROOT + id + ".png")
	report[id] = {"columns":columns,"rows":rows,"cell":[cell.x,cell.y],"baseline":baseline,"frames":entries}

func isolate_sprite(frame: Image) -> Image:
	# Generated grids can contain a disconnected sliver from an adjacent pose.
	# Keep the complete connected character cluster, including nearby chain links.
	var width := frame.get_width()
	var height := frame.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var groups: Array = []
	for y in height:
		for x in width:
			var key := y*width+x
			if visited[key] or frame.get_pixel(x,y).a < 0.5:
				continue
			var points: Array[Vector2i] = [Vector2i(x,y)]
			visited[key] = 1
			var bounds := Rect2i(x,y,1,1)
			var cursor := 0
			while cursor < points.size():
				var point := points[cursor]
				cursor += 1
				bounds = bounds.expand(point)
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = point+offset
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
						continue
					var next_key: int = next.y*width+next.x
					if not visited[next_key] and frame.get_pixelv(next).a >= 0.5:
						visited[next_key] = 1
						points.append(next)
			groups.append({"points":points,"bounds":bounds,"keep":false})
	groups.sort_custom(func(a,b): return a.points.size()>b.points.size())
	assert(not groups.is_empty())
	groups[0].keep = true
	var cluster: Rect2i = groups[0].bounds
	for pass_index in 8:
		for group in groups:
			if not group.keep and group.points.size() >= 4 and cluster.grow(6).intersects(group.bounds):
				group.keep = true
				cluster = cluster.merge(group.bounds)
	var result := Image.create(width,height,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for group in groups:
		if group.keep:
			for point in group.points:
				result.set_pixelv(point,frame.get_pixelv(point))
	return result
