extends SceneTree
const ROOT = "res://assets/character_overhaul/2026-11-24/legacy_retarget/"
var report = {}
var joins = {}
func clean(path):
	var im = Image.load_from_file(ProjectSettings.globalize_path(path))
	im.convert(Image.FORMAT_RGBA8)
	for y in im.get_height():
		for x in im.get_width():
			var c = im.get_pixel(x,y)
			c.a = 1.0 if c.a >= 0.6 else 0.0
			im.set_pixel(x,y,c)
	return im
func foot(im):
	var b = im.get_used_rect()
	var left = im.get_width()
	var right = 0
	for y in range(b.end.y-8,b.end.y):
		for x in im.get_width():
			if im.get_pixel(x,y).a > 0.5:
				left = mini(left,x)
				right = maxi(right,x)
	return Vector2((left+right)/2.0,b.end.y)
func _initialize():
	for id in ["chuheun","yeonwoo"]:
		pack(id+"-base",4,2,false)
		pack(id+"-expressive",4,4,false)
		pack(id+"-idle",3 if id == "chuheun" else 4,2,false)
	pack("chuheun-motion",4,4,false)
	fixed()
	FileAccess.open(ROOT+"metadata/registration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	FileAccess.open(ROOT+"metadata/chain-joins.json",FileAccess.WRITE).store_string(JSON.stringify(joins,"  "))
	quit()
func pack(id,cols,rows,base):
	var src = clean(ROOT+"source/"+id+".png")
	var sw = src.get_width()/cols
	var sh = src.get_height()/rows
	var cells = grid_cells(src,cols,rows)
	var first = cells[8] if id.ends_with("expressive") else cells[0]
	var factor = 320.0/first.get_used_rect().size.y
	var size = Vector2i(384,400) if base else Vector2i(768,480)
	var anchor = Vector2(192,384) if base else Vector2(256,464)
	var out = Image.create(size.x*cols,size.y*rows,false,Image.FORMAT_RGBA8)
	var frames = []
	var actor = id.split("-")[0]
	if id.ends_with("expressive"): joins[actor] = {}
	for f in cols*rows:
		var cell = cells[f]
		var feet = foot(cell)
		# All poses use the same scale. Only ground registration changes, never anatomy.
		var offset = anchor-feet*factor
		var bounds = cell.get_used_rect()
		var crop = cell.get_region(bounds)
		crop.resize(roundi(crop.get_width()*factor),roundi(crop.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		var pos = Vector2i((offset+Vector2(bounds.position)*factor).round())
		assert(pos.x>=0 and pos.y>=0 and pos.x+crop.get_width()<=size.x and pos.y+crop.get_height()<=size.y,"Clipped "+id+str(f))
		out.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(f%cols,f/cols)*size+pos)
		frames.append({"frame":f,"source_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"source_foot":[feet.x,feet.y],"offset":[offset.x,offset.y]})
		if id.ends_with("expressive") and f in [2,3,4,5]:
			var tip = Vector2.ZERO
			for y in range(bounds.position.y,int(bounds.position.y+bounds.size.y*0.65)):
				for x in cell.get_width():
					var c = cell.get_pixel(x,y)
					if c.a>0.5 and c.b>c.r*1.05 and c.b>0.25 and x>tip.x: tip=Vector2(x,y)
			var socket = (offset+tip*factor-anchor)/2.0
			joins[actor][str(f)] = [socket.x,socket.y]
	out.save_png(ROOT+"runtime/"+id+".png")
	report[id] = {"cell":[size.x,size.y],"anchor":[anchor.x,anchor.y],"scale":factor,"frames":frames}
func fixed():
	var src = clean(ROOT+"source/yeonwoo-fixed.png")
	var factor = 320.0/1380.0
	var feet = Vector2(565,1454)
	var polygon = PackedVector2Array([Vector2(282,731),Vector2(346,755),Vector2(335,803),Vector2(335,854),Vector2(309,891),Vector2(283,923),Vector2(255,988),Vector2(235,1003),Vector2(211,990),Vector2(213,952),Vector2(251,887),Vector2(239,859),Vector2(240,827),Vector2(273,765)])
	for part in ["body","wrist"]:
		var cut = src.duplicate()
		for y in cut.get_height():
			for x in cut.get_width():
				var is_wrist = Geometry2D.is_point_in_polygon(Vector2(x,y),polygon)
				if is_wrist != (part == "wrist"): cut.set_pixel(x,y,Color.TRANSPARENT)
		cut.resize(roundi(src.get_width()*factor),roundi(src.get_height()*factor),Image.INTERPOLATE_LANCZOS)
		var out = Image.create(768,480,false,Image.FORMAT_RGBA8)
		out.blit_rect(cut,Rect2i(Vector2i.ZERO,cut.get_size()),Vector2i((Vector2(256,464)-feet*factor).round()))
		out.save_png(ROOT+"runtime/yeonwoo-windup-"+part+".png")

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

