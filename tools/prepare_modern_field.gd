extends SceneTree
## Import preparation only: shared scale, registered heads and native 64px cells.
const CELL := 64
const BODY_HEIGHT := 56
const FIXED_HEAD_ROWS := 26

func _initialize() -> void:
	for actor in ["chuheun", "yeonwoo"]:
		bake(actor)
	quit()

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
			bands.append(Vector2i(start, y))
			start = -1
	if start != -1:
		bands.append(Vector2i(start, source.get_height()))
	# Discard stray opaque specks, preserving the narrow gaps between poses.
	var rows: Array[Vector2i] = []
	for band in bands:
		if band.y - band.x > source.get_height() / 8:
			rows.append(band)
	print("SOURCE ROWS: ", rows)
	assert(rows.size() == 4, "Expected four direction rows")
	return rows

func bake(actor: String) -> void:
	var source := Image.load_from_file("res://assets/sprites/field/%s_modern_source.png" % actor)
	var rows := find_rows(source)
	var crops: Array[Image] = []
	var row_extents: Array[int] = [1, 1, 1, 1]
	var width := source.get_width() / 3
	for row_index in rows.size():
		var row := rows[row_index]
		for column in 3:
			var image := source.get_region(Rect2i(column * width, row.x, width, row.y - row.x))
			var bounds := foreground_bounds(image)
			crops.append(image.get_region(bounds))
			row_extents[row_index] = maxi(row_extents[row_index], maxi(bounds.size.x, bounds.size.y))
	# Correct mixed-facing source poses once, before animation registration.
	if actor == "chuheun":
		crops[5].flip_x() # Source row 2 stride faces right; neutral faces left.
		crops[4].flip_x()
		crops[8].flip_x() # Source row 3 final stride faces left.
	var frames: Array[Image] = []
	for index in crops.size():
		var crop := crops[index]
		# Register each view to the same height once; its three poses share one scale.
		var shared_scale := float(BODY_HEIGHT) / row_extents[index / 3]
		# Use the head center, not the changing arms/chain silhouette, as the anchor.
		var head_bounds := foreground_bounds(crop.get_region(Rect2i(0, 0, crop.get_width(), roundi(crop.get_height() * 0.42))))
		var head_center := head_bounds.position.x + head_bounds.size.x * 0.5
		crop.resize(maxi(1, roundi(crop.get_width() * shared_scale)), maxi(1, roundi(crop.get_height() * shared_scale)), Image.INTERPOLATE_NEAREST)
		var frame := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		frame.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(roundi(CELL * 0.5 - head_center * shared_scale), 60 - crop.get_height()))
		frames.append(frame)
	for row in 4:
		for pose in [1, 2]:
			frames[row * 3 + pose].blit_rect(frames[row * 3], Rect2i(0, 0, CELL, FIXED_HEAD_ROWS), Vector2i.ZERO)
	var atlas := Image.create(CELL * 3, CELL * 4, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		atlas.blit_rect(frames[index], Rect2i(0, 0, CELL, CELL), Vector2i(index % 3, index / 3) * CELL)
	assert(atlas.save_png("res://assets/sprites/field/%s_modern.png" % actor) == OK)
	atlas.resize(576, 768, Image.INTERPOLATE_NEAREST)
	assert(atlas.save_png("res://tests/preview-%s-modern.png" % actor) == OK)
	print("MODERN FIELD BAKED: ", actor, " 192x256 atlas, source row extents=", row_extents)
