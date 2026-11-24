extends SceneTree
func _initialize() -> void:
	var image := Image.load_from_file("res://assets/prologue/chapter/event-poses-source.png")
	image.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(320,128,false,Image.FORMAT_RGBA8)
	for i in 10:
		var left := roundi(float(i%5)*image.get_width()/5)
		var right := roundi(float(i%5+1)*image.get_width()/5)
		var cell := image.get_region(Rect2i(left,(i/5)*image.get_height()/2,right-left,image.get_height()/2))
		var box := cell.get_used_rect()
		var body := cell.get_region(box)
		var width := roundi(body.get_width()*55.0/body.get_height())
		body.resize(width,55,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i(i%5*64+(64-width)/2,i/5*64+7))
	atlas.save_png("res://assets/prologue/chapter/event-poses.png")
	print("Packed ten whole-body event poses")
	quit()
