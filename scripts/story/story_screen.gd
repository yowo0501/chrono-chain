extends Control
## A readable UI canvas over the project's unchanged 256 x 224 field viewport.
const DESIGN := Vector2(768, 672)
var story_font: SystemFont

func _ready() -> void:
	story_font = SystemFont.new()
	story_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	theme = Theme.new()
	theme.default_font = story_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	get_viewport().size_changed.connect(resize_view)
	resize_view()

func resize_view() -> void:
	size = DESIGN
	scale = get_viewport_rect().size / DESIGN
	queue_redraw()

func label_at(text: String, rect: Rect2, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func box(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func button_at(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color("f1f0eb"))
	button.add_theme_stylebox_override("normal", box(Color("080808"), Color("343434")))
	button.add_theme_stylebox_override("hover", box(Color("111111"), Color("cccccc")))
	button.add_theme_stylebox_override("pressed", box(Color("1a1a1a"), Color("eeeeee")))
	button.add_theme_stylebox_override("focus", box(Color(1,1,1,0.03), Color("aaaaaa")))
	button.pressed.connect(callback)
	add_child(button)
	return button
