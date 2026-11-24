extends Node
## Presentation only: the original grid remains the authority for movement and encounters.
## One logical 16px tile maps to one metre on X/Z; actors use fixed-size 32px atlases.
const TILE := 16.0
const RENDER_SIZE := Vector2i(960, 840)
var field: Node2D
var player: Node2D
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var presentation: CanvasLayer
var image: TextureRect
var actors: Dictionary = {}
var lamp_views: Array = []
var area_views: Array[Node3D] = []
var last_lights: Array = []
var materials: Dictionary = {}
var shaded_materials: Array[ShaderMaterial] = []
var shadows: Dictionary = {}
var static_batches := 0
var focus := Vector3.ZERO
var initialized := false
var random := RandomNumberGenerator.new()

func _ready() -> void:
	call_deferred("build")

func build() -> void:
	field = get_parent().get_node("Field")
	player = get_parent().get_node("Player")
	if field.test_grid:
		set_process(false)
		return
	random.seed = 7121454
	presentation = CanvasLayer.new()
	presentation.name = "DioramaPresentation"
	presentation.layer = -5
	add_child(presentation)
	viewport = SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.size = RENDER_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	image = TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(image)
	get_viewport().size_changed.connect(_resize)
	_resize()
	world = Node3D.new()
	world.name = "LanternGarden"
	viewport.add_child(world)
	_environment()
	_make_materials()
	_make_ground()
	_make_town()
	_make_backdrop()
	for i in field.lamps.size():
		_make_lamp(i)
	for tile in field.flowers:
		_make_flowerbed(tile)
	_apply_surface_shader()
	_batch_static_meshes()
	# Expand the same architecture horizontally, leaving the actors at one-tile scale.
	for child in world.get_children():
		if child is Node3D and not child is Light3D and not child is WorldEnvironment:
			child.position *= Vector3(field.map_scale,1,field.map_scale)
			child.scale *= Vector3(field.map_scale,1,field.map_scale)
	for i in 12:
		var area := Node3D.new()
		area.name = "LightDistrict%02d" % (i + 1)
		world.add_child(area)
		area_views.append(area)
	camera = Camera3D.new()
	camera.name = "ObliqueCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.4
	camera.near = 0.1
	camera.far = 150
	world.add_child(camera)
	camera.current = true
	focus = _camera_target()
	_position_camera()
	# Keep simulation nodes and their visibility flags intact for encounter rules.
	field.self_modulate.a = 0.0
	for child in field.get_children():
		if child.get_script() == load("res://scripts/field_darkness.gd"):
			child.hide()
	player.sprite.hide()
	player.follower.hide()
	for symbol in field.symbols:
		symbol.self_modulate.a = 0.0
	initialized = true
	_sync_lights()
	_sync_actors()

func _resize() -> void:
	image.size = get_viewport().get_visible_rect().size
	viewport.size = Vector2i(roundi(RENDER_SIZE.y * image.size.x / maxf(image.size.y, 1)), RENDER_SIZE.y)

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("73828b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9fbbc8")
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color("879a9a")
	env.fog_density = 0.003
	var environment := WorldEnvironment.new()
	environment.environment = env
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -32, 0)
	sun.light_color = Color("ffe4b6")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	world.add_child(sun)

func _material(key: String, color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	if texture:
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	materials[key] = mat
	return mat

func _surface_texture(base: Color, pattern: String) -> ImageTexture:
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var noise := random.randf_range(-0.075, 0.075)
			var color := base.lightened(noise) if noise > 0 else base.darkened(-noise)
			if pattern == "stone":
				var seam := y % 16 == 0 or (x + (16 if (y / 16) % 2 else 0)) % 32 == 0
				if seam:
					color = base.darkened(0.30)
				elif y % 16 == 1:
					color = base.lightened(0.14)
			elif pattern == "roof":
				if y % 8 < 2:
					color = base.darkened(0.27)
				elif x % 8 == 0:
					color = base.lightened(0.22)
			elif pattern == "wood":
				if x % 10 == 0 or (x + y / 8) % 17 == 0:
					color = base.darkened(0.25)
			pixels.set_pixel(x, y, color)
	return ImageTexture.create_from_image(pixels)

func _make_materials() -> void:
	_material("paving", Color.WHITE, _surface_texture(Color("8f9687"), "stone"))
	_material("stone", Color.WHITE, _surface_texture(Color("737e74"), "stone"))
	_material("plaster", Color.WHITE, _surface_texture(Color("c8bfa0"), "plaster"))
	_material("roof", Color.WHITE, _surface_texture(Color("385c60"), "roof"))
	_material("roof_red", Color.WHITE, _surface_texture(Color("8e5c48"), "roof"))
	_material("timber", Color.WHITE, _surface_texture(Color("534b3b"), "wood"))
	_material("soil", Color("3d3b2d"))
	_material("leaves", Color("46684c"))
	_material("leaves_light", Color("7e9262"))
	_material("metal", Color("303d3a"))
	var glow := _material("lantern_glow", Color("ffe5a0"))
	glow.emission_enabled = true
	glow.emission = Color("ffb95b")
	glow.emission_energy_multiplier = 0.6
	_material("lantern_off", Color("283343"))

func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func _round(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func _make_ground() -> void:
	_box(world, Vector3(12.5, -0.30, 7.5), Vector3(29, 0.55, 19), materials.stone)
	_box(world, Vector3(12.5, -0.66, 7.5), Vector3(29.4, 0.2, 19.4), materials.timber)
	for y in field.settings.tiles.size():
		for x in str(field.settings.tiles[0]).length():
			var p := Vector3(x + 0.5, -0.04, y + 0.5)
			_box(world, p, Vector3(0.98, 0.08, 0.98), materials.paving)
			var tile := Vector2i(x, y)
			if str(field.settings.tiles[y]).substr(x,1) != "#":
				continue
			# Low garden walls mark the exact blocked cells without concealing paths.
			if y <= 1 or y >= 13:
				continue
			_box(world, p + Vector3(0, 0.28, 0), Vector3(0.94, 0.56, 0.94), materials.stone)
			_box(world, p + Vector3(0, 0.59, 0), Vector3(1.0, 0.09, 1.0), _material("capstone", Color("acae94")))
			if x % 4 == 0:
					_bush(world, p + Vector3(0, 0.67, 0), 0.39)
	# Inlaid brass compass marks the boss's actual, walkable plaza.
	var center := Vector3(12.5, 0.015, 7.5)
	for i in 4:
		var trim := _box(world, center, Vector3(2.4, 0.018, 0.035), _material("brass", Color("beab79")))
		trim.rotation.y = i * PI / 4
	for x in range(1, 25):
		_box(world, Vector3(x, 0.012, 4.5), Vector3(0.045, 0.018, 0.7), materials.stone)
		_box(world, Vector3(x, 0.012, 10.5), Vector3(0.045, 0.018, 0.7), materials.stone)

func _make_town() -> void:
	for i in 6:
		_make_house(Vector3(2.4 + i * 4, 0, 0.55), i)
	# Foreground boundary is a low balustrade, keeping the party visible.
	for x in range(0, 26):
		_box(world, Vector3(x, 0.35, 14), Vector3(0.17, 0.7, 0.22), materials.stone)
	_box(world, Vector3(12.5, 0.68, 14), Vector3(25.6, 0.12, 0.34), materials.stone)
	for x in [0.5, 24.5]:
		for z in [3.5, 11.5]:
			_tree(Vector3(x, 0.6, z), 0.60)
	# Benches sit on the blocked outer border, never on walkable cells.
	for x in [2.5, 6.5, 10.5, 14.5, 18.5, 22.5]:
		_box(world, Vector3(x, 0.36, 13.5), Vector3(1.3, 0.13, 0.45), materials.timber)
		_box(world, Vector3(x, 0.65, 13.69), Vector3(1.3, 0.48, 0.10), materials.timber)
		for dx in [-0.48, 0.48]:
			_box(world, Vector3(x+dx, 0.18, 13.5), Vector3(0.10, 0.36, 0.35), materials.metal)

func _make_house(at: Vector3, variant: int) -> void:
	var house := Node3D.new()
	house.name = "GardenHouse%02d" % variant
	house.position = at
	world.add_child(house)
	var h := 2.3 + (variant % 3) * 0.22
	_box(house, Vector3(0, 0.2, 0), Vector3(3.45, 0.4, 2.15), materials.stone)
	_box(house, Vector3(0, h/2 + 0.25, 0), Vector3(3.3, h, 1.95), materials.plaster)
	for x in [-1.62, 0.0, 1.62]:
		_box(house, Vector3(x, h/2 + 0.25, 1.0), Vector3(0.12, h, 0.12), materials.timber)
	for y in [0.5, 1.55, h + 0.15]:
		_box(house, Vector3(0, y, 1.01), Vector3(3.45, 0.12, 0.13), materials.timber)
	_box(house, Vector3(0, 0.82, 1.02), Vector3(0.68, 1.2, 0.12), materials.timber)
	_round(house, Vector3(0.2, 0.85, 1.1), 0.04, 0.06, materials.brass)
	for x in [-1.0, 1.0]:
		_box(house, Vector3(x, 1.55, 1.035), Vector3(0.73, 0.83, 0.10), materials.timber)
		_box(house, Vector3(x, 1.55, 1.10), Vector3(0.59, 0.66, 0.025), materials.lantern_glow)
		_box(house, Vector3(x, 1.55, 1.13), Vector3(0.045, 0.71, 0.04), materials.timber)
		_box(house, Vector3(x, 1.55, 1.13), Vector3(0.64, 0.045, 0.04), materials.timber)
		_box(house, Vector3(x, 1.08, 1.19), Vector3(0.84, 0.17, 0.32), materials.timber)
		for j in 4:
			_flower(house, Vector3(x - 0.28 + j * 0.18, 1.20, 1.20), variant + j)
	# Thick gabled roof slabs with tiled texture, layered eaves and ridge.
	var roof: Material = materials.roof_red if variant % 3 == 1 else materials.roof
	for side in [-1, 1]:
		var slab := _box(house, Vector3(0, h + 0.66, side * 0.65), Vector3(3.85, 0.16, 1.65), roof)
		slab.rotation.x = side * deg_to_rad(28)
		_box(house, Vector3(0, h + 0.28, side * 1.4), Vector3(4.0, 0.13, 0.18), materials.timber)
	_box(house, Vector3(0, h + 1.04, 0), Vector3(3.95, 0.14, 0.18), roof)
	_box(house, Vector3(1.05, h + 0.98, -0.55), Vector3(0.43, 1.1, 0.46), materials.stone)
	_box(house, Vector3(1.05, h + 1.57, -0.55), Vector3(0.55, 0.12, 0.58), materials.stone)
	# Fabric awning breaks up the facade silhouette.
	var awning := _box(house, Vector3(0, 1.75, 1.28), Vector3(0.94, 0.06, 0.65), _material("awning", Color("697d66")))
	awning.rotation.x = deg_to_rad(12)

func _flower(parent: Node3D, at: Vector3, variant: int) -> void:
	_round(parent, at + Vector3(0, 0.10, 0), 0.018, 0.23, materials.leaves)
	_box(parent, at + Vector3(-0.05, 0.09, 0), Vector3(0.12, 0.025, 0.06), materials.leaves_light)
	var palette := [Color("dfb383"), Color("c37b88"), Color("a89ac3"), Color("e1dcb4")]
	var petal := _material("petal%d" % (variant % 4), palette[variant % 4])
	_round(parent, at + Vector3(0, 0.23, 0), 0.075, 0.065, petal)
	_round(parent, at + Vector3(0, 0.27, 0), 0.025, 0.015, materials.brass)

func _make_flowerbed(tile: Vector2i) -> void:
	var bed := Node3D.new()
	bed.name = "Flowerbed_%d_%d" % [tile.x, tile.y]
	bed.position = Vector3(floorf(float(tile.x)/field.map_scale) + 0.5, 0, floorf(float(tile.y)/field.map_scale) + 0.5)
	world.add_child(bed)
	_box(bed, Vector3(0, 0.14, 0), Vector3(0.92, 0.28, 0.92), materials.stone)
	_box(bed, Vector3(0, 0.285, 0), Vector3(0.72, 0.025, 0.72), materials.soil)
	for side in [-1, 1]:
		_box(bed, Vector3(side * 0.43, 0.3, 0), Vector3(0.1, 0.1, 0.96), _material("bed_rim", Color("b2ac8c")))
		_box(bed, Vector3(0, 0.3, side * 0.43), Vector3(0.96, 0.1, 0.1), materials.bed_rim)
	for i in 9:
		_flower(bed, Vector3(-0.27 + (i % 3) * 0.27, 0.30, -0.27 + (i / 3) * 0.27), tile.x + tile.y + i)

func _make_lamp(index: int) -> void:
	var tile: Vector2i = field.lamps[index]
	var lamp := Node3D.new()
	lamp.name = "Lantern%02d" % (index + 1)
	lamp.position = Vector3(floorf(float(tile.x)/field.map_scale) + 0.5, 0, floorf(float(tile.y)/field.map_scale) + 0.5)
	world.add_child(lamp)
	_round(lamp, Vector3(0, 0.10, 0), 0.24, 0.2, materials.stone)
	_round(lamp, Vector3(0, 0.85, 0), 0.055, 1.6, materials.metal)
	_round(lamp, Vector3(0, 1.6, 0), 0.22, 0.12, materials.metal)
	var glass := _box(lamp, Vector3(0, 1.85, 0), Vector3(0.25, 0.40, 0.25), materials.lantern_glow)
	for x in [-0.15, 0.15]:
		for z in [-0.15, 0.15]:
			_box(lamp, Vector3(x, 1.85, z), Vector3(0.035, 0.43, 0.035), materials.metal)
	_round(lamp, Vector3(0, 2.12, 0), 0.31, 0.23, materials.metal, 0.07)
	var light := OmniLight3D.new()
	light.position.y = 1.75
	light.light_color = Color("ffca7b")
	light.light_energy = 0.65
	light.omni_range = 3.5
	lamp.add_child(light)
	lamp_views.append({"glass": glass, "light": light})

func _bush(parent: Node3D, at: Vector3, radius: float) -> void:
	for i in 3:
		var mesh := SphereMesh.new()
		mesh.radius = radius * (0.8 if i == 1 else 0.65)
		mesh.height = radius * 1.1
		mesh.radial_segments = 8
		mesh.rings = 4
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = materials.leaves_light if i == 1 else materials.leaves
		node.position = at + Vector3((i - 1) * radius * 0.7, radius * 0.2, 0)
		parent.add_child(node)

func _tree(at: Vector3, size: float) -> void:
	_round(world, at + Vector3(0, size, 0), size * 0.12, size * 2, materials.timber)
	for i in 3:
		_bush(world, at + Vector3((0.25 if i == 1 else -0.1) * size, size * (1.25 + i * 0.38), 0), size * (1.1 - i * 0.19))

func _make_backdrop() -> void:
	_box(world, Vector3(12, -0.9, 5), Vector3(100, 0.3, 80), _material("land", Color("516b62")))
	# A shallow canal and stepped banks frame the playable garden.
	var water := _material("water", Color("426e78"))
	water.roughness = 0.3
	_box(world, Vector3(12.5, -0.60, 18.2), Vector3(33, 0.05, 4.8), water)
	_box(world, Vector3(-3.2, -0.60, 7.5), Vector3(2.4, 0.05, 25), water)
	_box(world, Vector3(28.2, -0.60, 7.5), Vector3(2.4, 0.05, 25), water)
	for i in 45:
		_box(world, Vector3(random.randf_range(-2, 28), -0.565, random.randf_range(16, 20)), Vector3(random.randf_range(0.15, 0.9), 0.008, 0.025), _material("ripple", Color("789c9c")))
	for x in range(-3, 30, 2):
		_round(world, Vector3(x, -0.38, 20.4), 0.6, 0.6, materials.stone)
	for i in 35:
		_tree(Vector3(-12 + i * 1.5, -0.6, -7 - random.randf() * 8), random.randf_range(1.2, 2.7))
	for i in 14:
		_tree(Vector3(-4 - random.randf() * 4, -0.6, i * 1.8), random.randf_range(1.2, 2.0))
		_tree(Vector3(29 + random.randf() * 4, -0.6, i * 1.8), random.randf_range(1.2, 2.0))
	for i in 9:
		_round(world, Vector3(-12 + i * 7, 1, -24), 7, 13 + random.randf() * 8, _material("hills", Color("718d86")), 0.4)

func _camera_target() -> Vector3:
	return Vector3(clampf(player.position.x / TILE + 0.5, 5.5, field.width()-5.0), 0.65, clampf(player.position.y / TILE + 0.5, 5.8, field.height()-5.0))

func _position_camera() -> void:
	camera.position = focus + Vector3(2.6, 10, 12)
	camera.look_at(focus, Vector3.UP)

func _sync_lights() -> void:
	if last_lights == field.lit:
		return
	last_lights = field.lit.duplicate()
	var values := PackedFloat32Array()
	for light_on in field.lit:
		values.append(1.0 if light_on else 0.0)
	for material in shaded_materials:
		material.set_shader_parameter("district_light", values)
	for i in lamp_views.size():
		lamp_views[i].glass.material_override = materials.lantern_glow if field.lit[i] else materials.lantern_off
		lamp_views[i].glass.visible = field.lit[i]
		lamp_views[i].light.visible = field.lit[i]
		area_views[i].visible = not field.lit[i]

func _apply_surface_shader() -> void:
	# Tint actual surfaces by world-space district, including flowers and walls.
	# This preserves relief and shadows instead of covering the scene with black rectangles.
	var cache: Dictionary = {}
	var pending: Array[Node] = [world]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D:
			continue
		var base: StandardMaterial3D = node.material_override as StandardMaterial3D
		if base == null:
			continue
		if not cache.has(base):
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/shaders/field_surface.gdshader")
			material.set_shader_parameter("base_color", base.albedo_color)
			material.set_shader_parameter("map_scale",float(field.map_scale))
			if base.emission_enabled:
				material.set_shader_parameter("emission_color",base.emission)
				material.set_shader_parameter("emission_energy",base.emission_energy_multiplier)
			if base.albedo_texture:
				material.set_shader_parameter("albedo_texture", base.albedo_texture)
			cache[base] = material
			shaded_materials.append(material)
		node.material_override = cache[base]

func _actor_view(actor: Node2D) -> Sprite3D:
	if actors.has(actor):
		return actors[actor]
	var sprite := Sprite3D.new()
	sprite.name = actor.name + "Billboard"
	sprite.texture = actor.texture
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.pixel_size = 1.344 / float(actor.FRAME_SIZE)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.3
	sprite.no_depth_test = false
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sprite)
	actors[actor] = sprite
	var shadow_mat := _material("actor_shadow", Color(0.04, 0.06, 0.08, 0.30))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var shadow := _round(world, Vector3.ZERO, 0.27, 0.008, shadow_mat)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadows[actor] = shadow
	return sprite

func _batch_static_meshes() -> void:
	# Thousands of petals, bricks and timbers share instanced unit meshes.
	# Live lamp glass and animated actors stay independent.
	var groups: Dictionary = {}
	var pending: Array[Node] = [world]
	var live_glass: Array = []
	for lamp in lamp_views:
		live_glass.append(lamp.glass)
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D or node in live_glass:
			continue
		var source: Mesh = node.mesh
		var unit: Mesh
		var dimensions := Vector3.ONE
		var kind := ""
		if source is BoxMesh:
			unit = BoxMesh.new()
			unit.size = Vector3.ONE
			dimensions = source.size
			kind = "box"
		elif source is CylinderMesh:
			unit = CylinderMesh.new()
			unit.bottom_radius = 1.0
			unit.top_radius = source.top_radius / source.bottom_radius
			unit.height = 1.0
			unit.radial_segments = source.radial_segments
			dimensions = Vector3(source.bottom_radius, source.height, source.bottom_radius)
			kind = "cylinder_%.4f" % unit.top_radius
		elif source is SphereMesh:
			unit = SphereMesh.new()
			unit.radius = 1.0
			unit.height = 2.0
			unit.radial_segments = source.radial_segments
			unit.rings = source.rings
			dimensions = Vector3(source.radius, source.height / 2.0, source.radius)
			kind = "sphere"
		else:
			continue
		var key := "%s_%d" % [kind, node.material_override.get_instance_id()]
		if not groups.has(key):
			groups[key] = {"mesh": unit, "material": node.material_override, "transforms": []}
		groups[key].transforms.append(node.global_transform * Transform3D(Basis.from_scale(dimensions), Vector3.ZERO))
		node.get_parent().remove_child(node)
		node.free()
	for key in groups:
		var group: Dictionary = groups[key]
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = group.mesh
		mesh.instance_count = group.transforms.size()
		for i in mesh.instance_count:
			mesh.set_instance_transform(i, group.transforms[i])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = mesh
		batch.material_override = group.material
		batch.name = "Static_" + str(key)
		world.add_child(batch)
		static_batches += 1

func _sync_actor(actor: Node2D, logical: Vector2, shown: bool, party_member: bool = false) -> void:
	var sprite := _actor_view(actor)
	sprite.position = Vector3(logical.x / TILE + 0.5, 0.59, logical.y / TILE + 0.5)
	sprite.frame = int(actor.DIRECTIONS[actor.facing]) * 3 + actor.current_frame
	sprite.visible = shown
	var tile := Vector2i(floori(logical.x / TILE), floori(logical.y / TILE))
	sprite.modulate = Color.WHITE if field.is_lit(tile) else Color("a3adc4")
	if not party_member and not field.is_lit(tile):
		sprite.visible = actor.get("is_boss") == true and shown
	shadows[actor].position = Vector3(sprite.position.x, 0.014, sprite.position.z)
	shadows[actor].visible = sprite.visible

func _sync_actors() -> void:
	_sync_actor(player.sprite, player.position, true, true)
	_sync_actor(player.follower, player.follower.position, true, true)
	for symbol in field.symbols:
		_sync_actor(symbol, symbol.position, symbol.visible and not symbol.defeated)
	if field.boss_spawned:
		field.boss.self_modulate.a = 0.0
		_sync_actor(field.boss, field.boss.position, not field.boss_defeated)

func _process(delta: float) -> void:
	if not initialized:
		return
	_sync_lights()
	_sync_actors()
	# Frame-rate independent tracking, with no perspective scale changes per tile.
	focus = focus.lerp(_camera_target(), 1.0 - exp(-9.0 * delta))
	_position_camera()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if EncounterManager.active else SubViewport.UPDATE_ALWAYS
