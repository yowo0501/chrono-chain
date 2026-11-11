extends SceneTree
## Mechanical extraction only. Every pose is a complete ImageGen drawing.
const SOURCE := "res://assets/sprites/character-v2/source/"
const BATTLE := "res://assets/sprites/battle/"
const CELL := Vector2i(384,240)
const ANCHOR := Vector2i(128,232)
var report := {}

func _initialize() -> void:
	for id in ["chuheun","yeonwoo"]:
		pack_field(id)
	if not "--field-only" in OS.get_cmdline_user_args():
		pack_battle()
	FileAccess.open("res://assets/sprites/character-v2/packing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CHARACTER V2 PACKED: 64 intact field poses")
	quit()

func load_source(id: String) -> Image:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE+id+".png"))
	assert(source != null,"Missing generated source "+id)
	source.convert(Image.FORMAT_RGBA8)
	# Remove export noise below half opacity; retain opaque pixel-art edges.
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x,y)
			color.a = 1.0 if color.a>=0.5 else 0.0
			source.set_pixel(x,y,color)
	return source

func grid_cells(source: Image, columns: int, rows: int, row_cuts: Array = []) -> Array:
	# Generated sheets have imperfect gutters. Find transparent cuts near each
	# expected boundary instead of cutting a foot/head on a nominal grid line.
	var ys: Array[int] = [0]
	for row in range(1,rows):
		ys.append(find_cut(source,false,roundi(float(source.get_height())*row/rows),roundi(float(source.get_height())/rows*0.16),0,source.get_width()))
	ys.append(source.get_height())
	if not row_cuts.is_empty():
		ys.assign(row_cuts)
	var result: Array = []
	for row in rows:
		var xs: Array[int] = [0]
		for column in range(1,columns):
			xs.append(find_cut(source,true,roundi(float(source.get_width())*column/columns),roundi(float(source.get_width())/columns*0.16),ys[row],ys[row+1]))
		xs.append(source.get_width())
		for column in columns:
			result.append(source.get_region(Rect2i(xs[column],ys[row],xs[column+1]-xs[column],ys[row+1]-ys[row])))
	return result

func find_cut(source: Image, vertical: bool, center: int, radius: int, start: int, end: int) -> int:
	var best := center
	var best_score := INF
	for candidate in range(center-radius,center+radius+1):
		var score := absf(candidate-center)*0.001
		for cross in range(start,end):
			var alpha := source.get_pixel(candidate,cross).a if vertical else source.get_pixel(cross,candidate).a
			if alpha > 0.1:
				score += alpha
		if score < best_score:
			best_score = score
			best = candidate
	return best

func pack_field(id: String) -> void:
	var front_back := grid_cells(load_source(id+"-field-front-back"),4,4)
	var sides := grid_cells(load_source(id+"-field-sides"),4,4)
	var poses: Array = front_back.slice(0,8)+sides.slice(0,8)+sides.slice(8,16)+front_back.slice(8,16)
	var front_factor := 108.0/float(front_back[0].get_used_rect().size.y)
	var side_factor := 108.0/float(sides[0].get_used_rect().size.y)
	var atlas := Image.create_empty(768,512,false,Image.FORMAT_RGBA8)
	var bounds: Array = []
	for index in poses.size():
		var factor := front_factor if index<8 or index>=24 else side_factor
		var pose: Image = poses[index]
		var used := pose.get_used_rect()
		var foot := feet_anchor(pose)
		# Register the head/torso axis, not the forward foot: anchoring a passing
		# foot makes the entire body jump sideways when the support foot changes.
		var head := pose.get_region(Rect2i(used.position.x,used.position.y,used.size.x,roundi(used.size.y*0.22))).get_used_rect()
		foot.x = used.position.x+head.position.x+head.size.x*0.5
		pose.resize(roundi(pose.get_width()*factor),roundi(pose.get_height()*factor),Image.INTERPOLATE_NEAREST)
		var offset := Vector2i(48,124)-Vector2i((foot*factor).round())
		var tile := Image.create_empty(96,128,false,Image.FORMAT_RGBA8)
		tile.blit_rect(pose,Rect2i(Vector2i.ZERO,pose.get_size()),offset)
		var box := tile.get_used_rect()
		assert(box.position.x>0 and box.end.x<96 and box.position.y>0 and box.end.y<=125,"Clipped field pose "+id+str(index))
		atlas.blit_rect(tile,Rect2i(0,0,96,128),Vector2i(index%8,index/8)*Vector2i(96,128))
		bounds.append([used.position.x,used.position.y,used.size.x,used.size.y,foot.x,foot.y])
	atlas.save_png("res://assets/sprites/field/"+id+"_night.png")
	report[id] = {"front_scale":front_factor,"side_scale":side_factor,"cells":bounds,"gait":[1,5,2,3,6,4]}

func feet_anchor(pose: Image) -> Vector2:
	var used := pose.get_used_rect()
	var min_x := used.end.x
	var max_x := used.position.x
	for y in range(used.end.y-maxi(3,roundi(used.size.y*0.07)),used.end.y):
		for x in range(used.position.x,used.end.x):
			if pose.get_pixel(x,y).a>0.2:
				min_x = mini(min_x,x)
				max_x = maxi(max_x,x)
	return Vector2((min_x+max_x)*0.5,used.end.y)

func normalized(id: String, cols: int, rows: int, factor: float, row_cuts: Array = []) -> Array:
	var source := load_source(id)
	var poses := connected_poses(source,cols,rows,row_cuts) if id.ends_with("expressive") else grid_cells(source,cols,rows,row_cuts)
	var result: Array = []
	for pose: Image in poses:
		result.append(registered(pose,feet_anchor(pose),factor,CELL,ANCHOR))
	return result

func connected_poses(source: Image, cols: int, rows: int, row_cuts: Array = []) -> Array:
	# Some original poses (notably the overhead stretch) cross a nominal row
	# boundary. Extract each connected drawing intact rather than slicing it.
	var width := source.get_width()
	var height := source.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var groups: Array = []
	for i in cols*rows:
		groups.append([])
	for y in height:
		for x in width:
			var seed := y*width+x
			if visited[seed] or source.get_pixel(x,y).a<0.5:
				continue
			var pixels := PackedInt32Array([seed])
			visited[seed]=1
			var cursor := 0
			var total := Vector2.ZERO
			while cursor<pixels.size():
				var p: int=pixels[cursor]
				cursor+=1
				var px: int=p%width
				var py: int=p/width
				total+=Vector2(px,py)
				for dy in range(-1,2):
					for dx in range(-1,2):
						var nx:=px+dx
						var ny:=py+dy
						if nx<0 or ny<0 or nx>=width or ny>=height:
							continue
						var n:=ny*width+nx
						if not visited[n] and source.get_pixel(nx,ny).a>=0.5:
							visited[n]=1
							pixels.append(n)
			if pixels.size()<50:
				continue
			var center:=total/pixels.size()
			var column:=mini(cols-1,int(center.x/width*cols))
			var row:=mini(rows-1,int(center.y/height*rows))
			if not row_cuts.is_empty():
				for r in rows:
					if center.y>=row_cuts[r] and center.y<row_cuts[r+1]:
						row=r
			groups[row*cols+column].append(pixels)
	var result: Array=[]
	for group: Array in groups:
		assert(not group.is_empty(),"Missing connected pose")
		var canvas:=Image.create_empty(width,height,false,Image.FORMAT_RGBA8)
		for component: PackedInt32Array in group:
			for p in component:
				canvas.set_pixel(p%width,p/width,source.get_pixel(p%width,p/width))
		result.append(canvas.get_region(canvas.get_used_rect()))
	return result

func registered(source: Image, foot: Vector2, factor: float, cell: Vector2i, anchor: Vector2i) -> Image:
	var pose := source.duplicate() as Image
	pose.resize(roundi(pose.get_width()*factor),roundi(pose.get_height()*factor),Image.INTERPOLATE_NEAREST)
	var result := Image.create_empty(cell.x,cell.y,false,Image.FORMAT_RGBA8)
	result.blit_rect(pose,Rect2i(Vector2i.ZERO,pose.get_size()),anchor-Vector2i((foot*factor).round()))
	return result

func save_atlas(poses: Array, cols: int, cell: Vector2i, file: String) -> void:
	var atlas := Image.create_empty(cols*cell.x,ceili(float(poses.size())/cols)*cell.y,false,Image.FORMAT_RGBA8)
	for i in poses.size():
		atlas.blit_rect(poses[i],Rect2i(Vector2i.ZERO,cell),Vector2i(i%cols,i/cols)*cell)
	atlas.save_png(BATTLE+file+".png")

func pack_battle() -> void:
	var joins := {}
	for id in ["chuheun","yeonwoo"]:
		var source := load_source(id+"-expressive")
		var poses := normalized(id+"-expressive",4,4,0.53*1254.0/source.get_width())
		save_atlas(poses,4,CELL,id+"-expressive")
		joins[id] = {}
		for frame in [2,3,4,5]:
			var tip := right_tip(poses[frame])-ANCHOR
			joins[id][str(frame)] = [tip.x,tip.y]
		var base_source := load_source(id+"-base")
		var base_cells := grid_cells(base_source,4,2)
		var factor := 162.0/float(base_cells[0].get_used_rect().size.y)
		var bases: Array = []
		for cell: Image in base_cells:
			bases.append(registered(cell,feet_anchor(cell),factor,Vector2i(192,200),Vector2i(96,192)))
		save_atlas(bases,4,Vector2i(192,200),id)
		if id == "yeonwoo":
			# Calm planted idle; the independent wrist rig handles attack preparation.
			var idle := registered(base_cells[0],feet_anchor(base_cells[0]),factor,CELL,ANCHOR)
			var motion: Array = []
			for i in 16:
				motion.append(idle)
			save_atlas(motion,4,CELL,"yeonwoo-motion")
	save_atlas(normalized("chuheun-motion",4,4,0.55),4,CELL,"chuheun-motion")
	var calm := load_source("chuheun-idle")
	var calm_cells := grid_cells(calm,3,2)
	var calm_factor := 162.0/float(calm_cells[0].get_used_rect().size.y)
	save_atlas(normalized("chuheun-idle",3,2,calm_factor),3,CELL,"chuheun-idle-calm")
	var timer := normalized("chuheun-timer",4,4,0.66)
	# Last source cell is a standalone flying lance, centered independently.
	var projectile: Image = grid_cells(load_source("chuheun-timer"),4,4)[15]
	projectile = projectile.get_region(projectile.get_used_rect())
	projectile.resize(300,roundi(projectile.get_height()*300.0/projectile.get_width()),Image.INTERPOLATE_NEAREST)
	timer[15] = Image.create_empty(384,240,false,Image.FORMAT_RGBA8)
	timer[15].blit_rect(projectile,Rect2i(Vector2i.ZERO,projectile.get_size()),Vector2i(42,(240-projectile.get_height())/2))
	save_atlas(timer,4,CELL,"chuheun-timer")
	save_atlas(normalized("chuheun-timer-morph",4,4,0.66),4,CELL,"chuheun-timer-v2")
	save_atlas(normalized("yeonwoo-assassin",4,4,0.65),4,CELL,"yeonwoo-assassin")
	save_atlas(normalized("focus",4,2,0.40),4,CELL,"focus")
	var support: Array=[]
	var support_source:=load_source("support")
	var ys: Array[int]=[0,474,796,1086]
	for row in 3:
		# The thrown can belongs to frame 6 even though it crosses the nominal
		# column boundary. Include the whole prop in that frame, not the yawn.
		var xs: Array=[0,362,724,1152,1448] if row==1 else [0,370,740,1100,1448]
		for col in 4:
			var pose:=support_source.get_region(Rect2i(xs[col],ys[row],xs[col+1]-xs[col],ys[row+1]-ys[row]))
			support.append(registered(pose,feet_anchor(pose),0.48,CELL,ANCHOR))
	save_atlas(support,4,CELL,"support-skills")
	var food:=support_source.get_region(Rect2i(263,850,62,66))
	food=food.get_region(food.get_used_rect())
	food.save_png(BATTLE+"recovery-food.png")
	pack_wrist_rig()
	FileAccess.open(BATTLE+"chain-joins.json",FileAccess.WRITE).store_string(JSON.stringify(joins,"\t"))

func right_tip(pose: Image) -> Vector2i:
	var max_x := 0
	var sum_y := 0
	var count := 0
	# Ignore boots. The attack's final links are its farthest upper-body pixels.
	for y in range(25,190):
		for x in range(128,384):
			if pose.get_pixel(x,y).a<0.5:
				continue
			if x>max_x:
				max_x=x
				sum_y=y
				count=1
			elif x==max_x:
				sum_y+=y
				count+=1
	return Vector2i(max_x,roundi(float(sum_y)/maxi(count,1)))

func pack_wrist_rig() -> void:
	var source := load_source("yeonwoo-fixed")
	var body := source.duplicate() as Image
	var wrist := Image.create_empty(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	var polygon := PackedVector2Array([Vector2(282,731),Vector2(367,750),Vector2(337,783),Vector2(332,830),Vector2(332,873),Vector2(312,895),Vector2(289,890),Vector2(275,925),Vector2(249,984),Vector2(222,984),Vector2(223,952),Vector2(260,892),Vector2(239,870),Vector2(238,824),Vector2(271,769)])
	for y in range(710,1000):
		for x in range(210,380):
			if Geometry2D.is_point_in_polygon(Vector2(x,y),polygon):
				wrist.set_pixel(x,y,source.get_pixel(x,y))
				# Cuff overlap closes the rotating joint; never split head or torso.
				if y>755:
					body.set_pixel(x,y,Color.TRANSPARENT)
	var foot := feet_anchor(source)
	var factor := 162.0/source.get_used_rect().size.y
	registered(body,foot,factor,CELL,ANCHOR).save_png(BATTLE+"yeonwoo-windup-body.png")
	registered(wrist,foot,factor,CELL,ANCHOR).save_png(BATTLE+"yeonwoo-windup-wrist.png")
	var pivot := (Vector2(318,747)-foot)*factor
	var tip := (Vector2(238,975)-foot)*factor
	FileAccess.open(BATTLE+"yeonwoo-windup-rig.json",FileAccess.WRITE).store_string(JSON.stringify({"pivot":[pivot.x,pivot.y],"tip":[tip.x,tip.y]},"\t"))
