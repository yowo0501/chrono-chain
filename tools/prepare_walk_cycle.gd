extends SceneTree
const CELL := 16

func _initialize() -> void:
	for actor in ["chuheun", "yeonwoo"]:
		bake(actor)
	quit()

func find_rows(source: Image) -> Array[Vector2i]:
	var bands: Array[Vector2i] = []
	var start := -1
	for y in source.get_height():
		var count := 0
		for x in source.get_width():
			if source.get_pixel(x, y).a > 0.95:
				count += 1
		if count > 20 and start == -1:
			start = y
		elif count <= 20 and start != -1:
			if not bands.is_empty() and start - bands[-1].y < 8:
				bands[-1].y = y
			else:
				bands.append(Vector2i(start, y))
			start = -1
	assert(bands.size() == 4, "Four separated direction rows required")
	return bands

func foreground_bounds(image: Image) -> Rect2i:
	var bounds := Rect2i()
	var found := false
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.95:
				continue
			var pixel := Rect2i(x, y, 1, 1)
			bounds = bounds.merge(pixel) if found else pixel
			found = true
	assert(found)
	return bounds

func bake(actor: String) -> void:
	var source := Image.load_from_file("res://assets/sprites/field/%s_walk_cycle_source.png" % actor)
	var rows := find_rows(source)
	var crops: Array[Image] = []
	var largest := 1
	var cell_width := source.get_width() / 3
	for row in rows:
		for column in 3:
			var image := source.get_region(Rect2i(column * cell_width, row.x, cell_width, row.y - row.x))
			var bounds := foreground_bounds(image)
			crops.append(image.get_region(bounds))
			largest = maxi(largest, maxi(bounds.size.x, bounds.size.y))
	var shared_scale := 14.0 / largest
	var frames: Array[Image] = []
	for crop in crops:
		crop.resize(maxi(1, roundi(crop.get_width() * shared_scale)), maxi(1, roundi(crop.get_height() * shared_scale)), Image.INTERPOLATE_NEAREST)
		var frame := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		frame.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((CELL - crop.get_width()) / 2, 15 - crop.get_height()))
		frames.append(frame)
	for row in 4:
		for pose in [1, 2]:
			# Keep the exact same head/body registration throughout the cycle.
			frames[row * 3 + pose].blit_rect(frames[row * 3], Rect2i(0, 0, CELL, 11), Vector2i.ZERO)
	var atlas := Image.create(CELL * 3, CELL * 4, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		atlas.blit_rect(frames[index], Rect2i(0, 0, CELL, CELL), Vector2i(index % 3, index / 3) * CELL)
	assert(atlas.save_png("res://assets/sprites/field/%s_walk_cycle.png" % actor) == OK)
	atlas.resize(384, 512, Image.INTERPOLATE_NEAREST)
	assert(atlas.save_png("res://tests/preview-%s-walk-cycle.png" % actor) == OK)
	print("WALK CYCLE BAKED: ", actor, " rows=", rows)
