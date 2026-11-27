extends SceneTree
var images=[]
var font=SystemFont.new()
func _initialize(): call_deferred("run")
func run():
	font.font_names=PackedStringArray(["Malgun Gothic"])
	root.content_scale_size=Vector2i(1050,650)
	var paths=["res://assets/sprites/battle/yeonwoo-motion-source.png","res://assets/character_overhaul/2026-11-24/legacy_retarget/runtime/yeonwoo-idle.png","res://assets/character_overhaul/2026-11-24/yeonwoo_a/runtime/yeonwoo-motion.png"]
	var grids=[Vector2i(4,4),Vector2i(4,2),Vector2i(4,4)]
	for i in 3:
		var im=Image.load_from_file(ProjectSettings.globalize_path(paths[i]))
		var cell=im.get_region(Rect2i(0,0,im.get_width()/4,340)) if i==0 else im.get_region(Rect2i(Vector2i.ZERO,im.get_size()/grids[i]))
		for y in cell.get_height():
			for x in cell.get_width():
				var c=cell.get_pixel(x,y)
				c.a=1.0 if c.a>=0.6 else 0.0
				cell.set_pixel(x,y,c)
		images.append(ImageTexture.create_from_image(cell.get_region(cell.get_used_rect())))
	var ui=Node2D.new()
	ui.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(ui)
	ui.draw.connect(func():
		ui.draw_rect(Rect2(0,0,1050,650),Color("202c3c"))
		var titles=["A · 검은 바지 시절 원본","B · 이전 적용본","C · A 기준 수정본"]
		for i in 3:
			ui.draw_string(font,Vector2(30+i*350,48),titles[i],HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
			var tex=images[i]
			var size=Vector2(tex.get_size())*(400.0/tex.get_height())
			ui.draw_texture_rect(tex,Rect2(Vector2(i*350+175-size.x/2,530-size.y),size),false)
			ui.draw_line(Vector2(i*350+35,531),Vector2(i*350+315,531),Color("7192a3"),1)
		ui.draw_string(font,Vector2(30,597),"A의 자세·비율 기준 / 현재 설정화 의상·표정 적용",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("e3c798"))
	)
	ui.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/character_overhaul/2026-11-24/yeonwoo_a/review/comparison.png")
	quit()
