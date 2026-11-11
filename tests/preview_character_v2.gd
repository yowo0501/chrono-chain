extends "res://tests/preview_character_refresh.gd"

func capture(path: String) -> void:
	await super.capture(path.replace("art-reviews/character-refresh/","art-reviews/character-v2/"))

func shot(name: String) -> void:
	screen.queue_redraw()
	await capture("res://art-reviews/character-v2/"+name+".png")
