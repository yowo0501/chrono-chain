extends "res://scripts/story/story_screen.gd"
var logo: Texture2D = preload("res://assets/prologue/logo-chain-lettering.png")

func _ready() -> void:
	super._ready()
	var first := button_at("프롤로그 실행", Rect2(224,481,320,54), _open_prologue)
	button_at("튜토리얼 실행", Rect2(224,551,320,54), _open_tutorial)
	var hint := label_at("↑ ↓ 선택   ·   Space / Enter 실행   ·   F10 메뉴로", Rect2(0,628,768,26), 13, Color("888888"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first.grab_focus()

func _open_prologue() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/prologue/prologue.tscn")

func _open_tutorial() -> void:
	get_node("/root/StoryRouter").open_scene("res://scenes/main/main.tscn")

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color.BLACK)
	draw_texture_rect(logo, Rect2(84,-40,600,600), false)
