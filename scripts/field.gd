extends Node2D

## Very basic field renderer: builds a grid of 16x16 tile sprites from a
## hardcoded ASCII map (no TileMap/TileSet resource — plain Sprite2D atlas
## regions, kept intentionally simple for this first pass). Movement
## blocking is a logical lookup (is_blocked), not physics collision.

const TILE_SIZE := 16

# tile code -> column index into assets/tilesets/night_city_tiles.png
# (order: road, sidewalk, wall, window_lit, window_dark, lamp)
const TILE_COLUMN := {
	".": 0, # road
	",": 1, # sidewalk
	"#": 2, # wall
	"L": 3, # window_lit
	"D": 4, # window_dark
	"P": 5, # lamp
}

const BLOCKED := ["#", "L", "D", "P"]

const MAP := [
	"####################",
	"#L##D##L##D##L##D###",
	"#L##D##L##D##L##D###",
	"####################",
	",,P,,,,,,,,,,,,,,P,,",
	"....................",
	"....................",
	"....................",
	"....................",
	",,,,,,,,,,,,,,,,,,,,",
	"####################",
	"#L##D##L##D##L##D###",
	"#L##D##L##D##L##D###",
	"####################",
]

var _tileset := preload("res://assets/tilesets/night_city_tiles.png")


func _ready() -> void:
	add_to_group("field")
	for y in range(MAP.size()):
		var row: String = MAP[y]
		for x in range(row.length()):
			var code := row.substr(x, 1)
			_add_tile(x, y, code)


func _add_tile(x: int, y: int, code: String) -> void:
	var col: int = TILE_COLUMN.get(code, 0)
	var sprite := Sprite2D.new()
	sprite.texture = _tileset
	sprite.region_enabled = true
	sprite.region_rect = Rect2(col * TILE_SIZE, 0, TILE_SIZE, TILE_SIZE)
	sprite.centered = false
	sprite.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
	add_child(sprite)


func width() -> int:
	return MAP[0].length()


func height() -> int:
	return MAP.size()


func is_blocked(grid_pos: Vector2i) -> bool:
	if grid_pos.y < 0 or grid_pos.y >= MAP.size():
		return true
	var row: String = MAP[grid_pos.y]
	if grid_pos.x < 0 or grid_pos.x >= row.length():
		return true
	return row.substr(grid_pos.x, 1) in BLOCKED
