extends "res://scripts/story/story_screen.gd"
var rooftop: Texture2D = preload("res://assets/prologue/chapter/rooftop-pixel-v3.png")
var logo: Texture2D = preload("res://assets/prologue/logo-chain-lettering.png")
var elapsed := 0.0
var mark: TextureRect
var start_button: Button

func _ready() -> void:
	super._ready()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark = TextureRect.new()
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.texture = logo
	mark.position = Vector2(399,58)
	mark.size = Vector2(342,342)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mark.material = blend
	mark.modulate.a = 0
	add_child(mark)
	start_button = button_at("시 작",Rect2(284,552,200,52),_open_prologue)
	start_button.add_theme_stylebox_override("normal",box(Color(0.025,0.06,0.12,0.85),Color("708c9b")))
	start_button.add_theme_stylebox_override("hover",box(Color("172c42"),Color("e7ca89")))
	start_button.add_theme_stylebox_override("focus",box(Color(0.1,0.2,0.3,0.18),Color("e7ca89")))
	start_button.add_theme_stylebox_override("pressed",box(Color("24405a"),Color("f1dbad")))
	start_button.add_theme_color_override("font_color",Color("e7d7b0"))
	start_button.disabled = true
	start_button.modulate.a = 0
	start_button.hide()

func _process(delta: float) -> void:
	advance_intro(delta)

func advance_intro(delta: float) -> void:
	elapsed += delta
	mark.modulate.a = smoothstep(2.7,4.7,elapsed)
	start_button.modulate.a = smoothstep(5.0,6.0,elapsed)
	start_button.visible = elapsed>=5.0
	if elapsed>=6.0 and start_button.disabled:
		start_button.disabled = false
		start_button.grab_focus()
	queue_redraw()

func _open_prologue() -> void:
	if elapsed<6.0: return
	get_node("/root/StoryRouter").open_scene("res://scenes/prologue/prologue.tscn")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,DESIGN),Color.BLACK)
	draw_texture_rect_region(rooftop,Rect2(0,0,768,672),Rect2(0,0,rooftop.get_width(),rooftop.get_width()*672.0/768),Color(1,1,1,smoothstep(0,2.5,elapsed)))
