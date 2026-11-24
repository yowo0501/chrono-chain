extends RefCounted
const ROOT := "res://assets/character_overhaul/2026-11-23/v003/"
const CELL := Vector2(384,384)
const FOOT := Vector2(128,360)
const SCALE := 0.44
var textures: Array[Texture2D] = []
var metadata: Dictionary
func _init() -> void:
	for id in ["chuheun","yeonwoo"]:
		textures.append(load(ROOT+"runtime/"+id+"-battle.png"))
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"metadata/battle_frames.json"))
func draw(canvas: CanvasItem,index: int,frame: int,base: Vector2,tint: Color = Color.WHITE,_serious: bool = false) -> void:
	var source := Rect2(Vector2(frame%4,frame/4)*CELL,CELL)
	canvas.draw_texture_rect_region(textures[index],Rect2((base-FOOT*SCALE).round(),CELL*SCALE),source,tint)
func socket(index: int,frame: int,base: Vector2) -> Vector2:
	var pair: Array = metadata["chuheun" if index==0 else "yeonwoo"][frame].socket
	return base+(Vector2(pair[0],pair[1])-FOOT)*SCALE
func attack_frame(elapsed: float) -> int:
	if elapsed < 0.10: return 4
	if elapsed < 0.20: return 5
	if elapsed < 0.40: return 6
	if elapsed < 0.54: return 7
	if elapsed < 0.68: return 8
	return 0
func idle_frame(index: int,time: float) -> int:
	var cycle := fposmod(time + (0.0 if index == 0 else 0.45),2.8)
	# Authored inhale, exhale, weight transfer and blink with planted feet.
	var frames := [0,1,16,17,18,19,17,0]
	var ends := [0.45,0.9,1.25,1.65,1.78,2.15,2.5,2.8]
	for i in frames.size():
		if cycle < ends[i]: return frames[i]
	return 0

