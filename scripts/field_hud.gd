extends Control
var field: Node2D
var font: SystemFont
const DESIGN := Vector2(768, 672)
const PAPER := Color("ecede6")
const GOLD := Color("f2d18b")
const MUTED := Color("a6b5b9")
var show_map := false
var minimap_texture: ImageTexture
var minimap_revision := -1

func minimap_point(tile: Vector2i) -> Vector2:
	return Vector2(648,5)+(Vector2(tile)+Vector2.ONE*0.5)*Vector2(108.0/field.width(),54.0/field.height())

func _draw_minimap(player: Node2D) -> void:
	if minimap_texture == null or minimap_revision != field.lighting_revision:
		var pixels := Image.create(field.width(),field.height(),false,Image.FORMAT_RGBA8)
		for y in field.height():
			for x in field.width():
				var tile := Vector2i(x,y)
				pixels.set_pixel(x,y,Color("182731") if field.is_blocked(tile) else Color("a88c55") if field.is_lit(tile) else Color("28476d"))
		minimap_texture = ImageTexture.create_from_image(pixels)
		minimap_revision = field.lighting_revision
	draw_texture_rect(minimap_texture,Rect2(648,5,108,54),false)
	for i in field.lamps.size():
		draw_circle(minimap_point(field.lamps[i]),1.5,GOLD if field.lit[i] else Color("6ba9ed"))
	draw_circle(minimap_point(player.grid_pos),2.3,Color("56f1ff"))
	draw_rect(Rect2(647,4,110,56),Color("738b98"),false,1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	scale = get_viewport_rect().size / DESIGN
	size = DESIGN

func _process(_delta: float) -> void:
	visible = not EncounterManager.active
	queue_redraw()

func _input(event: InputEvent) -> void:
	if EncounterManager.active or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_M:
		show_map = not show_map
		get_viewport().set_input_as_handled()

func label_at(text: String, point: Vector2, color: Color = PAPER, font_size: int = 18) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if field == null or font == null or field.walker() == null:
		return
	var player: Node2D = field.walker()
	var area: int = field.area_at(player.grid_pos)
	draw_rect(Rect2(0,0,768,64), Color("17252c"))
	label_at("밤의 도시", Vector2(22,27), GOLD, 21)
	label_at("%s  ·  %s" % [field.area_name(area), "빛" if field.lit[area] else "어둠"],Vector2(22,51),MUTED,15)
	var objective := "모든 가로등을 밝히세요"
	if field.boss_defeated:
		objective = "골목 정화 완료"
	elif field.boss_spawned:
		objective = "분수 광장  ·  보스 출현"
	label_at(objective,Vector2(228,28),PAPER,19)
	label_at("가로등 %d / %d 점등" % [field.lamps.size()-field.dark_count(), field.lamps.size()],Vector2(228,51),MUTED,15)
	_draw_minimap(player)
	draw_rect(Rect2(0,596,768,76), Color("17252c"))
	for i in EncounterManager.party.size():
		var hero: Dictionary = EncounterManager.party[i]
		var x := 22+i*187
		label_at("%s  %d/%d" % [hero.name,hero.hp,hero.max_hp],Vector2(x,618),PAPER,14)
		draw_rect(Rect2(x,624,157,4),Color("3b4b50"))
		draw_rect(Rect2(x,624,157*float(hero.hp)/hero.max_hp,4),Color("79c6ad"))
	var target: Dictionary = field.interaction_target(player)
	var hint := "방향키 이동   E 조사   M 지도"
	if not target.is_empty():
		if field.lit[field.lamps.find(target.tile)]:
			hint = "E  가로등 확인"
		else:
			hint = "E  가로등 복구 · 체력 소모 없음"
	label_at(hint,Vector2(22,651),GOLD,13)
	var message: String = field.notice if field.notice_time > 0 else ("중앙 광장에서 보스와 접촉하세요" if field.boss_spawned and not field.boss_defeated else "어둠 속 이동 중에는 반복해서 적과 조우합니다")
	label_at(message,Vector2(310,651),MUTED,12)
	if show_map:
		_draw_map(player)

func _draw_map(player: Node2D) -> void:
	draw_rect(Rect2(72,105,624,450),Color("101c23"))
	label_at("도시 지도 · 128 × 64",Vector2(96,139),GOLD,21)
	label_at("노랑: 켜진 등  ·  파랑: 꺼진 등  ·  하늘색: 현재 위치",Vector2(96,165),MUTED,15)
	var origin := Vector2(96,190)
	var cell := minf(576.0 / field.width(), 288.0 / field.height())
	for y in field.height():
		for x in field.width():
			var tile := Vector2i(x,y)
			var color := Color("111a2a") if field.is_blocked(tile) else Color("243449")
			if field.is_lit(tile):
				match field.tile_kind(tile):
					"#": color = Color("42545e")
					"L": color = GOLD
					_: color = Color.from_hsv(0.10+field.area_at(tile)*0.035,0.12,0.65+0.04*(field.area_at(tile)%3))
			draw_rect(Rect2(origin+Vector2(tile)*cell,Vector2.ONE*cell),color)
	for i in field.lamps.size():
		var at := origin+(Vector2(field.lamps[i])+Vector2.ONE*0.5)*cell
		draw_circle(at,4,GOLD if field.lit[i] else Color("6ba9ed"))
		label_at(str(i+1),at+Vector2(5,-3),PAPER,10)
	for symbol in field.symbols:
		if symbol.siege_area >= 0:
			draw_circle(origin+(Vector2(field.lamps[symbol.siege_area])+Vector2.ONE*0.5)*cell,7,Color("ef7767"),false,2)
	draw_circle(origin+(Vector2(player.grid_pos)+Vector2.ONE*0.5)*cell,6,Color("56d2ef"))
	if field.boss_spawned and not field.boss_defeated:
		draw_circle(origin+(Vector2(field.boss.grid_pos)+Vector2.ONE*0.5)*cell,7,Color("ed9484"))
	label_at("1 분수광장   2 빵집   3 상점거리   6–9 뒷골목   10 공터",Vector2(96,505),MUTED,13)
	label_at("M  지도 닫기",Vector2(96,532),MUTED,16)
