class_name AbrissMaterials
extends RefCounted
## Shared, modest-resolution PBR surfaces. World projection keeps intact facade
## segments seamless; fracture meshes can switch to local projection when needed.

const ROOT := "res://assets/materials/"
static var _library: Dictionary = {}
static var _texture_sets: Dictionary = {}

static func build() -> Dictionary:
	if not _library.is_empty():
		return _library
	var plaster := _pbr("painted_plaster_wall", "diff", Color("f1ebe0"), 2.6, 0.92, 0.46)
	_library["plaster"] = plaster
	# Compatibility names deliberately use continuous render, not a brick grid.
	_library["brick"] = plaster
	_library["cream"] = plaster
	_library["sage"] = _tinted(plaster, Color("b2b7a6"))
	_library["blue"] = _tinted(plaster, Color("a7b4bb"))
	_library["rose"] = _tinted(plaster, Color("c9b7a9"))
	_library["interior"] = _tinted(plaster, Color("f2eee6"))
	_library["concrete"] = _pbr("concrete_wall_007", "diff", Color("d4d4cd"), 3.0, 0.94, 0.7)
	_library["concrete_core"] = _tinted(_library["concrete"], Color("c0bdb1"))
	_library["brick_core"] = _pbr("brick_wall_001", "diffuse", Color("d6b5a0"), 3.0, 0.96, 0.85)
	_library["wood"] = _pbr("wood_floor", "diff", Color("c6b49b"), 2.0, 0.84, 0.52)
	_library["darkwood"] = _tinted(_library["wood"], Color("6e5d4d"))
	_library["floor"] = _tinted(_library["wood"], Color("e4d5bc"))
	_library["door"] = _tinted(_library["wood"], Color("ac9580"))
	_library["trim"] = _micro(Color("ddd9cf"), "paint", 0.68)
	_library["white"] = _library["trim"]
	_library["steel"] = _micro(Color("667179"), "metal", 0.46, 0.72)
	_library["yellow"] = _micro(Color("c58b2b"), "paint", 0.57, 0.18)
	_library["ink"] = _micro(Color("242b2d"), "paint", 0.86)
	_library["roof"] = _micro(Color("454748"), "roof", 0.97)
	# Reuse irregular scanned mineral grain instead of periodic sine-wave ground.
	# A larger tile and restrained normals keep the construction yard understated.
	_library["dirt"] = _pbr("concrete_wall_007", "diff", Color("b4a58e"), 6.0, 0.99, 0.13)
	_library["grass"] = _pbr("painted_plaster_wall", "diff", Color("77816a"), 5.0, 0.99, 0.08)
	_library["gravel"] = _pbr("concrete_wall_007", "diff", Color("c0bcb0"), 2.8, 0.99, 0.22)
	_library["tile"] = _micro(Color("bebdb4"), "tile", 0.74)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "Window glass — subtle transparent tint"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.74, 0.85, 0.86, 0.2)
	glass.roughness = 0.14
	glass.metallic = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_library["glass"] = glass
	return _library

static func _pbr(asset: String, diffuse_suffix: String, tint: Color, tile_metres: float, roughness: float, normal_strength: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = asset
	result.albedo_color = tint
	result.roughness = roughness
	if not _texture_sets.has(asset):
		_texture_sets[asset] = [
			_load_map(asset + "_" + diffuse_suffix + "_1k.jpg"),
			_load_map(asset + "_nor_gl_1k.jpg"),
			_load_map(asset + "_rough_1k.jpg")
		]
	var maps: Array = _texture_sets[asset]
	result.albedo_texture = maps[0]
	result.normal_texture = maps[1]
	result.normal_enabled = maps[1] != null
	result.normal_scale = normal_strength
	result.roughness_texture = maps[2]
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_project(result, 1.0 / tile_metres)
	return result

static func _load_map(file_name: String) -> Texture2D:
	var path := ROOT + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Fresh check-only/headless sessions may precede editor texture import.
	var source := Image.new()
	if source.load(path) == OK:
		source.generate_mipmaps()
		return ImageTexture.create_from_image(source)
	push_warning("Missing material map: " + path)
	return null

static func _tinted(source: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var result := source.duplicate() as StandardMaterial3D
	result.albedo_color = tint
	return result

static func _project(surface: StandardMaterial3D, scale: float) -> void:
	surface.uv1_triplanar = true
	surface.uv1_world_triplanar = true
	surface.uv1_scale = Vector3.ONE * scale
	surface.uv1_triplanar_sharpness = 8.0
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func _micro(tint: Color, pattern: String, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.resource_name = "Procedural " + pattern
	surface.albedo_color = tint
	surface.roughness = roughness
	surface.metallic = metallic
	if not _texture_sets.has(pattern):
		_texture_sets[pattern] = _make_micro_maps(pattern)
	var maps: Array = _texture_sets[pattern]
	surface.albedo_texture = maps[0]
	surface.normal_texture = maps[1]
	surface.normal_enabled = true
	surface.normal_scale = 0.18 if pattern == "paint" or pattern == "metal" else 0.4
	surface.roughness_texture = maps[2]
	surface.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_project(surface, 1.0 if pattern == "earth" else 0.5)
	return surface

static func _make_micro_maps(pattern: String) -> Array:
	# Small reusable deterministic maps for secondary materials, not external assets.
	# A periodic combination avoids seams and adds subtle surface-scale variation.
	const RES := 128
	var height_values := PackedFloat32Array()
	height_values.resize(RES * RES)
	var albedo := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var normal := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var rough := Image.create(RES, RES, false, Image.FORMAT_L8)
	for y in range(RES):
		for x in range(RES):
			var u := float(x) / RES
			var v := float(y) / RES
			var grain := sin(TAU * (u * 31.0 + v * 19.0)) * cos(TAU * (v * 37.0 - u * 13.0))
			var broad := sin(TAU * (u * 3.0 + v * 2.0)) * cos(TAU * (u * 5.0 - v * 4.0))
			var height := 0.5 + grain * 0.035 + broad * 0.025
			if pattern == "earth":
				height = 0.5 + grain * 0.13 + broad * 0.12
			elif pattern == "roof":
				height = 0.5 + grain * 0.07 + broad * 0.055
			elif pattern == "tile":
				var joint := x % 32 < 1 or y % 32 < 1
				height = 0.17 if joint else 0.54 + grain * 0.02
			height_values[y * RES + x] = height
			var tone := clampf(0.9 + (height - 0.5) * (0.55 if pattern == "earth" else 0.27), 0.4, 1.0)
			albedo.set_pixel(x, y, Color(tone, tone, tone))
			var rough_value := clampf(0.88 + grain * 0.07 + broad * 0.035, 0.65, 1.0)
			rough.set_pixel(x, y, Color(rough_value, rough_value, rough_value))
	for y in range(RES):
		for x in range(RES):
			var dx := height_values[y * RES + (x + 1) % RES] - height_values[y * RES + (x + RES - 1) % RES]
			var dy := height_values[((y + 1) % RES) * RES + x] - height_values[((y + RES - 1) % RES) * RES + x]
			var direction := Vector3(-dx * 2.2, -dy * 2.2, 1.0).normalized()
			normal.set_pixel(x, y, Color(direction.x * 0.5 + 0.5, direction.y * 0.5 + 0.5, direction.z * 0.5 + 0.5))
	albedo.generate_mipmaps()
	normal.generate_mipmaps()
	rough.generate_mipmaps()
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(normal), ImageTexture.create_from_image(rough)]
