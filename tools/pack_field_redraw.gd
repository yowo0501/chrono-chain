extends SceneTree
## Extraction/registration only: all twelve complete poses are newly drawn.
const SOURCE := "res://assets/sprites/field-redraw/source/"

func _initialize() -> void:
	var report: Dictionary={}
	for id in ["chuheun","yeonwoo"]:
		var source:=Image.load_from_file(ProjectSettings.globalize_path(SOURCE+id+".png"))
		source.convert(Image.FORMAT_RGBA8)
		for y in source.get_height():
			for x in source.get_width():
				var c:=source.get_pixel(x,y)
				c.a=1.0 if c.a>=0.5 else 0.0
				source.set_pixel(x,y,c)
		var tiles: Array[Image]=[]
		var largest_height:=0
		for row in 4:
			for col in 3:
				var x0:=roundi(source.get_width()*col/3.0)
				var y0:=roundi(source.get_height()*row/4.0)
				var x1:=roundi(source.get_width()*(col+1)/3.0)
				var y1:=roundi(source.get_height()*(row+1)/4.0)
				var tile:=source.get_region(Rect2i(x0,y0,x1-x0,y1-y0))
				var bounds:=tile.get_used_rect()
				assert(bounds.position.x>1 and bounds.end.x<tile.get_width()-1 and bounds.position.y>1 and bounds.end.y<tile.get_height()-1,"Source pose crosses cell boundary")
				largest_height=maxi(largest_height,bounds.size.y)
				tiles.append(tile)
		var factor:=58.0/largest_height
		var atlas:=Image.create_empty(192,256,false,Image.FORMAT_RGBA8)
		var bounds_report: Array=[]
		for i in tiles.size():
			var tile:=tiles[i]
			var bounds:=tile.get_used_rect()
			# Register the whole pose on the head/torso center. Never splice the
			# standing head onto a different torso or use a foot as the x anchor.
			var head:=tile.get_region(Rect2i(0,bounds.position.y,tile.get_width(),roundi(bounds.size.y*0.43))).get_used_rect()
			var center_x:=head.position.x+head.size.x*0.5
			tile.resize(roundi(tile.get_width()*factor),roundi(tile.get_height()*factor),Image.INTERPOLATE_NEAREST)
			var foot_y:=tile.get_used_rect().end.y
			var output:=Image.create_empty(64,64,false,Image.FORMAT_RGBA8)
			output.blit_rect(tile,Rect2i(Vector2i.ZERO,tile.get_size()),Vector2i(32-roundi(center_x*factor),62-foot_y))
			var box:=output.get_used_rect()
			assert(box.position.x>0 and box.end.x<64 and box.position.y>0 and box.end.y==62,"Packed pose clipped or baseline changed")
			atlas.blit_rect(output,Rect2i(0,0,64,64),Vector2i(i%3,i/3)*64)
			bounds_report.append([box.position.x,box.position.y,box.size.x,box.size.y])
		assert(atlas.save_png("res://assets/sprites/field/"+id+"_night.png")==OK)
		report[id]={"scale":factor,"frame_bounds":bounds_report,"new_source":SOURCE+id+".png"}
	FileAccess.open("res://assets/sprites/field-redraw/packing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FIELD REDRAW PACKED: 24 new complete poses, fixed 64px cells and foot baseline")
	quit()
