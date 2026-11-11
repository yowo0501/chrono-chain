extends SceneTree
## Atlas packing only: all drawing comes from the supplied image-generation outputs.
const SOURCE := "res://assets/sprites/refresh-2026-11/source/"
const BATTLE := "res://assets/sprites/battle/"
const CELL := Vector2i(384, 240)
const ANCHOR := Vector2i(128, 232)
var catalog := {}
var chain_joins := {}

func _initialize() -> void:
	if "--field-only" in OS.get_cmdline_user_args():
		for id in ["chuheun", "yeonwoo"]:
			pack_field(id)
		print("FIELD REFRESH: packed 24 intact full-body poses")
		quit()
		return
	for id in ["chuheun", "yeonwoo"]:
		pack_field(id)
		var male: bool = id == "chuheun"
		var feet: Array = [193,193,193,193,180,182,178,148,155,178,190,185,184,181,189,191] if male else [195,195,195,195,190,180,180,167,180,184,198,185,194,194,194,194]
		var core := normalize(id+"-core", 0.70 if male else 0.685, feet)
		var utility := normalize(id+"-utility", 0.69 if male else 0.685, [193,193,193,193,193,193,193,193,193,193,193,193,193,193,193,193])
		catalog[id+"-core"] = core
		catalog[id+"-utility"] = utility
		var motion: Array = []
		for frame in [0,1,2,3,0,1,2,3,12,13,14,15,12,13,14,15]:
			motion.append(core[frame])
		save_atlas(motion,4,CELL,BATTLE+id+"-motion.png")
		var expressive: Array = []
		for frame in [4,6,5,7,8,8,9,0]:
			expressive.append(core[frame])
		for frame in [0,1,2,3,3,4,4,5]:
			expressive.append(utility[frame])
		save_atlas(expressive,4,CELL,BATTLE+id+"-expressive.png")
		chain_joins[id] = {}
		for frame in [3,4]:
			# Attach to the actual final painted link, including the atlas offset.
			var tip := rightmost_opaque(expressive[frame]) - ANCHOR
			chain_joins[id][str(frame)] = [tip.x,tip.y]
		var base: Array = []
		for frame in [0,1,2,3,10,11,9,0]:
			base.append(core[frame].get_region(Rect2i(32,40,192,200)))
		save_atlas(base,4,Vector2i(192,200),BATTLE+id+".png")
		if male:
			var idle: Array = []
			for frame in [0,1,2,3,1,0]:
				idle.append(core[frame])
			save_atlas(idle,3,CELL,BATTLE+"chuheun-idle-calm.png")
	var focus: Array = []
	for id in ["chuheun", "yeonwoo"]:
		for frame in [6,7,8,9]:
			focus.append(catalog[id+"-utility"][frame])
	save_atlas(focus,4,CELL,BATTLE+"focus.png")
	var support: Array = []
	# Separate the generated airborne sandwich from its throwing actor cell.
	# The runtime moves this independent prop along the existing throw trajectory.
	var toss: Image = catalog["yeonwoo-utility"][15]
	var food := toss.get_region(Rect2i(200,0,184,240))
	food = food.get_region(food.get_used_rect())
	food.save_png(BATTLE+"recovery-food.png")
	catalog["yeonwoo-utility"][15] = actor_only(toss,200)
	for frame in [10,11,12,13]:
		support.append(catalog["chuheun-utility"][frame])
	for frame in [10,11,12,13,14,15]:
		support.append(catalog["yeonwoo-utility"][frame])
	for frame in [14,15]:
		support.append(catalog["chuheun-utility"][frame])
	save_atlas(support,4,CELL,BATTLE+"support-skills.png")
	var timer := normalize("chuheun-timer",0.70,[185,185,185,185,145,145,145,145,145,165,185,195,145,145,145,192])
	# The released spear is a separate moving projectile, never duplicated in the body.
	timer[7] = actor_only(timer[7],187)
	# Center the isolated projectile; actor cells use the shared feet anchor.
	var spear_source := Image.load_from_file(SOURCE+"chuheun-timer.png").get_region(Rect2i(1152,768,384,256))
	var spear_box := spear_source.get_used_rect()
	var spear := spear_source.get_region(spear_box)
	var factor := 300.0 / spear.get_width()
	spear.resize(300,roundi(spear.get_height()*factor),Image.INTERPOLATE_LANCZOS)
	timer[15] = Image.create_empty(384,240,false,Image.FORMAT_RGBA8)
	timer[15].blit_rect(spear,Rect2i(Vector2i.ZERO,spear.get_size()),Vector2i(42,(240-spear.get_height())/2))
	save_atlas(timer,4,CELL,BATTLE+"chuheun-timer.png")
	var morph: Array = []
	for frame in [0,1,2,3,4,4,12,12,5,13,14,6,7,8,9,10]:
		morph.append(timer[frame])
	save_atlas(morph,4,CELL,BATTLE+"chuheun-timer-v2.png")
	var assassin := normalize("yeonwoo-assassin",0.685,[195,195,195,195,195,185,195,195,195,195,195,195,195,195,195,195])
	save_atlas(assassin,4,CELL,BATTLE+"yeonwoo-assassin.png")
	FileAccess.open(BATTLE+"chain-joins.json",FileAccess.WRITE).store_string(JSON.stringify(chain_joins,"\t"))
	print("CHARACTER REFRESH: packed 24 field poses and 96 battle source poses; shared feet anchors")
	quit()

func normalize(name: String, factor: float, feet_x: Array) -> Array:
	var source := Image.load_from_file(SOURCE+name+".png")
	var size := Vector2i(source.get_width()/4,source.get_height()/4)
	var frames: Array = []
	for frame in 16:
		var tile := source.get_region(Rect2i(Vector2i(frame%4,frame/4)*size,size))
		var used := tile.get_used_rect()
		assert(used.has_area(),"Empty generated cell: "+name+" "+str(frame))
		var feet := Vector2(float(feet_x[frame]),float(used.end.y))
		tile.resize(roundi(size.x*factor),roundi(size.y*factor),Image.INTERPOLATE_LANCZOS)
		var output := Image.create_empty(CELL.x,CELL.y,false,Image.FORMAT_RGBA8)
		output.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),ANCHOR-Vector2i((feet*factor).round()))
		frames.append(output)
	return frames

func pack_field(id: String) -> void:
	var source := Image.load_from_file(SOURCE+id+"-field-v2.png")
	# Follow the actual transparent gutters, including the first row's lower feet.
	var xs := [0,380,710,source.get_width()]
	var ys := [0,380,730,1090,source.get_height()]
	var frames: Array = []
	# A single scale for the entire sheet preserves anatomy across every stride.
	var first := source.get_region(Rect2i(0,0,xs[1],ys[1])).get_used_rect()
	var factor := 58.0 / first.size.y
	for frame in 12:
		var col := frame % 3
		var row := int(frame / 3)
		var size := Vector2i(xs[col+1]-xs[col],ys[row+1]-ys[row])
		var tile := source.get_region(Rect2i(xs[col],ys[row],size.x,size.y))
		var box := tile.get_used_rect()
		var head := tile.get_region(Rect2i(0,box.position.y,size.x,roundi(box.size.y*0.45))).get_used_rect()
		var feet := Vector2(head.position.x+head.size.x*0.5,box.end.y)
		tile.resize(roundi(size.x*factor),roundi(size.y*factor),Image.INTERPOLATE_LANCZOS)
		var output := Image.create_empty(64,64,false,Image.FORMAT_RGBA8)
		var anchor := Vector2i(roundi(feet.x*factor),tile.get_used_rect().end.y)
		output.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(32,62)-anchor)
		frames.append(output)
	# Keep each pose intact. Splicing the idle head onto an independently drawn
	# walking torso creates a visible horizontal seam when the shoulders turn.
	save_atlas(frames,3,Vector2i(64,64),"res://assets/sprites/field/"+id+"_night.png")

func rightmost_opaque(image: Image) -> Vector2i:
	for x in range(image.get_width()-1,-1,-1):
		var total := 0
		var count := 0
		for y in image.get_height():
			if image.get_pixel(x,y).a >= 0.5:
				total += y
				count += 1
		if count > 0:
			return Vector2i(x,roundi(float(total)/count))
	return Vector2i.ZERO

func actor_only(tile: Image, width: int) -> Image:
	var actor := Image.create_empty(CELL.x,CELL.y,false,Image.FORMAT_RGBA8)
	actor.blit_rect(tile,Rect2i(0,0,width,CELL.y),Vector2i.ZERO)
	return actor

func save_atlas(frames: Array, columns: int, cell: Vector2i, path: String) -> void:
	var atlas := Image.create_empty(columns*cell.x,ceili(float(frames.size())/columns)*cell.y,false,Image.FORMAT_RGBA8)
	for i in frames.size():
		atlas.blit_rect(frames[i],Rect2i(Vector2i.ZERO,cell),Vector2i(i%columns,i/columns)*cell)
	assert(atlas.save_png(path)==OK,"Cannot write "+path)
