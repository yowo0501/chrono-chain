extends SceneTree
## Offline atlas extraction. Preserve generated alpha and nearest-neighbor pixels.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/tilesets/night_town_source.png")
	var names := ["bakery","shop","house","warehouse","fountain","arch","crate","lamp","bench"]
	var cells := [
		Rect2i(0,0,480,485),Rect2i(480,0,355,485),Rect2i(835,0,419,485),
		Rect2i(0,485,497,425),Rect2i(497,485,345,415),Rect2i(842,485,412,425),
		Rect2i(0,910,480,344),Rect2i(586,902,94,338),Rect2i(800,910,454,344)
	]
	for i in names.size():
		var cell := source.get_region(cells[i])
		var bounds := cell.get_used_rect()
		var cropped := cell.get_region(bounds)
		var size := 192.0 if i < 6 else 96.0
		var factor := size / maxi(cropped.get_width(),cropped.get_height())
		cropped.resize(maxi(1,roundi(cropped.get_width()*factor)),maxi(1,roundi(cropped.get_height()*factor)),Image.INTERPOLATE_NEAREST)
		assert(cropped.save_png("res://assets/tilesets/night_%s.png" % names[i]) == OK)
	quit()
