extends SceneTree
const MAP = "res://assets/art_overhaul/2026-11-23/fields/style_c/"
const ACTORS = "res://assets/character_overhaul/2026-11-23/field_c/"
func _initialize():
	for id in ["chuheun","yeonwoo"]:
		var src = Image.load_from_file(ACTORS+"source/"+id+"-walk.png")
		harden(src)
		var sw = src.get_width()/3
		var sh = src.get_height()/4
		var first = src.get_region(Rect2i(0,0,sw,sh)).get_used_rect()
		var scale = 256.0/first.size.y
		var atlas = Image.create(960,1280,false,Image.FORMAT_RGBA8)
		for f in 12:
			var cell = src.get_region(Rect2i(f%3*sw,f/3*sh,sw,sh))
			var bounds = cell.get_used_rect()
			var crop = cell.get_region(bounds)
			crop.resize(maxi(1,roundi(crop.get_width()*scale)),maxi(1,roundi(crop.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
			assert(crop.get_width()<320 and crop.get_height()<310)
			atlas.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(f%3*320+(320-crop.get_width())/2,f/3*320+310-crop.get_height()))
		atlas.save_png(ACTORS+"runtime/"+id+"-walk.png")
	var props = Image.load_from_file(MAP+"source/props.png")
	harden(props)
	var names = ["bakery","shop","house","warehouse","fountain","arch","crate","lamp","bench","tree","factory","workshop","servicehouse","junk","wall_dark","wall_warm","manhole","puddle","drain","planter"]
	var sw = props.get_width()/4
	var sh = props.get_height()/5
	for f in 20:
		var xs = [0,291,565,842,1122]
		var ys = [0,307,589,884,1167,1402]
		var cell = props.get_region(Rect2i(xs[f%4],ys[f/4],xs[f%4+1]-xs[f%4],ys[f/4+1]-ys[f/4]))
		var crop = cell.get_region(cell.get_used_rect())
		crop.save_png(MAP+"runtime/"+names[f]+".png")
	var floors = Image.load_from_file(MAP+"source/floors.png")
	sw = floors.get_width()/3
	sh = floors.get_height()/2
	var materials = ["paving","cobble","asphalt","concrete","roof","water"]
	for f in 6:
		# Exclude atlas divider pixels; they must not become repeated road grid lines.
		var crop = floors.get_region(Rect2i(f%3*sw+4,f/3*sh+4,sw-8,sh-8))
		crop.save_png(MAP+"runtime/"+materials[f]+".png")
	quit()
func harden(im):
	for y in im.get_height():
		for x in im.get_width():
			var c = im.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			im.set_pixel(x,y,c)
