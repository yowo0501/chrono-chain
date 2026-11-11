extends Control
## The cinematic has no Field, Player or encounter symbols: it cannot start combat.
const TILE := 48.0
const HERO_SIZE := Vector2(48,48)
const MONSTER_RECT := Rect2(312,118,TILE*3,TILE*3)
const STARTS := {"chuheun": Vector2(312,358), "yeonwoo": Vector2(408,358)}
const ROWS := {"down":0, "left":1, "right":2, "up":3}
var background: Texture2D = preload("res://assets/prologue/alley.png")
var monster: Texture2D = preload("res://assets/prologue/monster.png")
var heroes := {
	"chuheun": preload("res://assets/sprites/field/chuheun_night.png"),
	"yeonwoo": preload("res://assets/sprites/field/yeonwoo_night.png")
}
var facing := {"chuheun":"up", "yeonwoo":"up"}
var drawing_chains := false
var chain_progress := 0.0
var rushing := false
var rush_progress := 0.0
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(background, Rect2(0,0,768,672), false)
	draw_rect(Rect2(0,0,768,672),Color(0.01,0.02,0.06,0.13))
	# Narrow horizontal strips deform continuously rather than sliding one rigid image.
	var slices := 20
	for i in slices:
		var height := MONSTER_RECT.size.y / slices
		var wobble := sin(clock * 2.5 + i * 0.55) * 2.2
		var rect := Rect2(MONSTER_RECT.position + Vector2(wobble, i * height), Vector2(MONSTER_RECT.size.x, height + 0.4))
		var source := Rect2(0, float(i) * monster.get_height() / slices, monster.get_width(), float(monster.get_height()) / slices)
		draw_texture_rect_region(monster, rect, source)
	for id in ["chuheun", "yeonwoo"]:
		var point: Vector2 = STARTS[id]
		if rushing:
			point = point.lerp(Vector2(338 if id == "chuheun" else 390, 201), rush_progress)
			point.y -= sin(rush_progress * PI) * 13.0
		var frame := 0
		if rushing:
			frame = [1,0,2,0][int(clock*18.0)%4]
		var shadow := point + Vector2(24,43)
		draw_set_transform(shadow,0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,17,Color(0,0,0,0.35))
		draw_set_transform(Vector2.ZERO)
		var row: int = ROWS[facing[id]]
		# Same full-body atlas and ground anchor as field exploration.
		draw_texture_rect_region(heroes[id],Rect2(shadow-Vector2(32,62)*0.75,HERO_SIZE),Rect2(frame*64,row*64,64,64))
		if chain_progress > 0:
			_draw_chain(point, id)

func _draw_chain(point: Vector2, id: String) -> void:
	var side := -1.0 if id == "chuheun" else 1.0
	var hand := point + Vector2(24 + side * 14,29 - chain_progress * 9)
	var count := int(14 * chain_progress)
	for i in count:
		var progress := float(i) / 13.0
		var sway := sin(clock * 3.5 + progress * 4.0) * 3.0
		var link := hand + Vector2(side * progress * 27 + sway * progress, progress * 24 - sin(chain_progress * PI) * progress * 32)
		if rushing:
			link.y += progress * rush_progress * 26
		draw_arc(link,2.3,0,TAU,8,Color("33455d"),2.4)
		draw_arc(link,2.0,0,TAU,8,Color("c0d2e1"),1.0)
