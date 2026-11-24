extends RefCounted
const MATERIAL_SHADER = preload("res://assets/shaders/yeonwoo_gold.gdshader")
static func apply(item: CanvasItem) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = MATERIAL_SHADER
	item.material = mat
