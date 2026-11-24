extends SceneTree
# Fixed registration per row preserves the authored lean, flick and recoil.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/prologue/chapter/flick-v2-source.png")
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(1536,480,false,Image.FORMAT_RGBA8)
	for i in 8:
		var cell := source.get_region(Rect2i(i%4*384,i/4*512,384,512))
		cell.resize(154,205,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(cell,Rect2i(0,0,154,205),Vector2i(i%4*384+48,i/4*240+42))
	atlas.save_png("res://assets/prologue/chapter/flick-v2.png")
	print("Packed eight registered comic poses")
	quit()
