extends SceneTree
## Bake generated art once into registered, native 16px animation cells.
const CELL := 16
const ACTORS := ["chuheun", "yeonwoo"]

func _initialize() -> void:
	for actor in ACTORS:
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
	assert(found, "Each source cell must contain a character")
	return bounds

func bake(actor: String) -> void:
	var source := Image.load_from_file("res://assets/sprites/field/%s_sd_tile_source.png" % actor)
	var cell := Vector2i(source.get_width() / 2, source.get_height() / 4)
	# Source gutters are not equal: cut only at the measured transparent gaps.
	var row_edges := [0, 473, 886, 1302, source.get_height()] if actor == "chuheun" else [0, 416, 761, 1105, source.get_height()]
	var crops: Array[Image] = []
	var largest := 1
	for row in 4:
		for column in 2:
			var image := source.get_region(Rect2i(column * cell.x, row_edges[row], cell.x, row_edges[row + 1] - row_edges[row]))
			var bounds := foreground_bounds(image)
			crops.append(image.get_region(bounds))
			largest = maxi(largest, maxi(bounds.size.x, bounds.size.y))
	# ONE scale for the entire sheet; never fit individual frames independently.
	var shared_scale := 14.0 / largest
	var frames: Array[Image] = []
	for crop in crops:
		crop.resize(maxi(1, roundi(crop.get_width() * shared_scale)), maxi(1, roundi(crop.get_height() * shared_scale)), Image.INTERPOLATE_NEAREST)
		var frame := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
		frame.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((CELL - crop.get_width()) / 2, 15 - crop.get_height()))
		frames.append(frame)
	for row in 4:
		var first := frames[row * 2]
		var second := frames[row * 2 + 1]
		# Register the head and torso exactly. Only the lower legs animate.
		second.blit_rect(first, Rect2i(0, 0, CELL, 11), Vector2i.ZERO)
		if row == 0 or row == 3:
			# Opposite feet in front/back views, without mirroring face or costume.
			var legs := first.get_region(Rect2i(0, 11, CELL, 5))
			legs.flip_x()
			second.blit_rect(legs, Rect2i(0, 0, CELL, 5), Vector2i(0, 11))
	var atlas := Image.create(CELL * 2, CELL * 4, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		atlas.blit_rect(frames[index], Rect2i(0, 0, CELL, CELL), Vector2i(index % 2, index / 2) * CELL)
	assert(atlas.save_png("res://assets/sprites/field/%s_sd_tile.png" % actor) == OK)
	# A readable contact sheet for checking registration at pixel scale.
	atlas.resize(256, 512, Image.INTERPOLATE_NEAREST)
	assert(atlas.save_png("res://tests/preview-%s-sd-tile.png" % actor) == OK)
	print("SD TILE BAKED: ", actor, " source=", source.get_size(), " shared scale=", shared_scale)
