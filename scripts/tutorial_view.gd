extends Control
const DESIGN := Vector2(768,672)
var tutorial: CanvasLayer
var title := ""
var body := ""
var font: SystemFont

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	get_viewport().size_changed.connect(resize_view)
	resize_view()

func resize_view() -> void:
	size = DESIGN
	scale = get_viewport_rect().size / DESIGN
	queue_redraw()

func _draw() -> void:
	# Cut actual command buttons out of the dim veil; all other input is consumed.
	var holes: Array[Rect2] = []
	for choice in tutorial.choices:
		if choice.existing:
			holes.append(choice.rect)
	var xs: Array[float] = [0.0,768.0]
	var ys: Array[float] = [0.0,672.0]
	for hole in holes:
		xs.append(hole.position.x)
		xs.append(hole.end.x)
		ys.append(hole.position.y)
		ys.append(hole.end.y)
	xs.sort()
	ys.sort()
	for x in range(xs.size()-1):
		for y in range(ys.size()-1):
			var cell := Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
			var highlighted := false
			for hole in holes:
				if hole.has_point(cell.get_center()):
					highlighted = true
			if not highlighted:
				draw_rect(cell,Color(0.02,0.04,0.08,0.84))
	draw_rect(Rect2(44,128,680,260),Color("152638"))
	draw_rect(Rect2(44,128,680,260),Color("6dcef3"),false,2)
	draw_string(font,Vector2(66,161),"튜토리얼 · 일시정지",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("6dcef3"))
	draw_string(font,Vector2(66,201),title,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.WHITE)
	var y := 244
	for line in body.split("\n"):
		draw_string(font,Vector2(66,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e2eaf4"))
		y += 30
	for i in tutorial.choices.size():
		var choice: Dictionary = tutorial.choices[i]
		if not choice.existing:
			draw_rect(choice.rect,Color("214557"))
			draw_string(font,choice.rect.position+Vector2(14,32),choice.label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		draw_rect(choice.rect.grow(3),Color("ffe099"),false,3 if i == tutorial.selected else 1.5)
