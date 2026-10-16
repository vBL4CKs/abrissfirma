class_name AbrissHouse
extends RefCounted
## All architectural details belong to a breakable host. There is no second,
## indestructible facade left behind when the structural building is removed.

static func build(game: Variant) -> void:
	_prepare_materials(game)
	var outside := "cream" if int(game.state.completed) % 2 == 0 else "sage"
	for level in range(2):
		var base_y := float(level) * 3.7
		for row in range(3):
			var y := base_y + 0.6 + float(row) * 1.2
			for column in range(10):
				var x := -5.4 + float(column) * 1.2
				for face in [-1, 1]:
					if face == 1 and level == 0 and column in [4, 5] and row < 2:
						continue
					if row == 1 and column in [1, 2, 7, 8]:
						continue
					var normal := Vector3(0, 0, face)
					var wall: Node3D = _piece(game, Vector3(x, y, face * 4.8), Vector3(1.2, 1.2, 0.36), "brick", outside)
					_configure_wall(game, wall, "interior_warm" if x < 0 else "interior_sage", normal)
					_wall_finish(game, wall, level, row, normal)
					if row == 2:
						_gutter(game, wall, normal)
			for column in range(8):
				var z := -4.2 + float(column) * 1.2
				for face in [-1, 1]:
					if row == 1 and column in [2, 5]:
						continue
					var normal := Vector3(face, 0, 0)
					var wall: Node3D = _piece(game, Vector3(face * 6.0, y, z), Vector3(0.36, 1.2, 1.2), "brick", outside)
					_configure_wall(game, wall, "interior_warm" if face < 0 else "interior_sage", normal)
					_wall_finish(game, wall, level, row, normal)
		# The partition is deliberately open in the hall and at the stair access.
		for z in [-3.6, -2.4, 2.4, 3.6]:
			for row in range(3):
				var wall: Node3D = _piece(game, Vector3(0, base_y + 0.6 + row * 1.2, z), Vector3(0.16, 1.2, 1.2), "wood", "interior_warm")
				if row == 0:
					_box(game, wall, Vector3(-0.10, -0.48, 0), Vector3(0.045, 0.12, 1.2), "trim")
					_box(game, wall, Vector3(0.10, -0.48, 0), Vector3(0.045, 0.12, 1.2), "trim")
		_build_floor(game, level)
		for x in [-3.6, 3.6]:
			for face in [-1, 1]:
				_window(game, Vector3(x, base_y + 1.8, face * 4.8), 2.4, Vector3(0, 0, face))
		for z in [-1.8, 1.8]:
			for face in [-1, 1]:
				_window(game, Vector3(face * 6.0, base_y + 1.8, z), 1.2, Vector3(face, 0, 0))
	_entry(game)
	_stairs(game)
	_furnish(game)
	_downpipe(game, Vector3(-5.65, 3.67, 5.05))
	_downpipe(game, Vector3(5.65, 3.67, -5.05))
	var host := _nearest(game, Vector3(1.8, 3.0, 4.8))
	var number := Label3D.new()
	number.text = "17"
	number.font_size = 64
	number.pixel_size = 0.0035
	number.modulate = Color("243238")
	number.no_depth_test = false
	number.position = Vector3(1.78, 2.7, 5.004) - host.position
	host.add_child(number)

static func _piece(game: Variant, at: Vector3, size: Vector3, kind: String, material_name: String) -> Node3D:
	game.add_piece(at, size, kind, material_name)
	return game.pieces[-1] as Node3D

static func _configure_wall(game: Variant, wall: Node3D, inside: String, normal: Vector3) -> void:
	if wall.has_method("configure_wall"):
		wall.call("configure_wall", game.materials[inside], game.materials["brick_core"], normal)

static func _prepare_materials(game: Variant) -> void:
	var palette := {"interior_warm": Color("d6cfc0"), "interior_sage": Color("a8b4ae"),
		"trim": Color("d0ccc2"), "roof": Color("343b39"), "fabric": Color("566a69"),
		"cushion": Color("9d9c88"), "porcelain": Color("d9dedb"), "walnut": Color("71533e")}
	for key in palette:
		if game.materials.has(key):
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = palette[key]
		material.roughness = 0.87
		if key in ["interior_warm", "interior_sage"]:
			var source: StandardMaterial3D = game.materials["cream"]
			material = source.duplicate() as StandardMaterial3D
			material.albedo_color = palette[key]
		game.materials[key] = material

static func _wall_finish(game: Variant, wall: Node3D, level: int, row: int, normal: Vector3) -> void:
	var tangent := Vector3(normal.z, 0, -normal.x)
	# Front/back wall runs terminate at x=6, while the transverse masonry is
	# 18 cm farther out. These thin plaster returns close that exposed core.
	if normal.z != 0 and absf(wall.position.x) > 5.0:
		var corner := signf(wall.position.x)
		var finish := "cream" if int(game.state.completed) % 2 == 0 else "sage"
		_box(game, wall, Vector3(corner * 0.692, 0, normal.z * 0.193), Vector3(0.204, 1.2, 0.026), finish)
		_box(game, wall, Vector3(corner * 0.793, 0, normal.z * 0.095), Vector3(0.026, 1.2, 0.222), finish)
		if row == 0:
			_box(game, wall, Vector3(corner * 0.69, -0.45, normal.z * 0.205), Vector3(0.20, 0.22, 0.045), "concrete")
			_box(game, wall, Vector3(corner * 0.807, -0.45, normal.z * 0.10), Vector3(0.045, 0.22, 0.23), "concrete")
		if row == 2:
			_box(game, wall, Vector3(corner * 0.70, 0.48, normal.z * 0.205), Vector3(0.22, 0.10, 0.055), "trim")
			_box(game, wall, Vector3(corner * 0.81, 0.48, normal.z * 0.10), Vector3(0.055, 0.10, 0.24), "trim")
	if row == 0:
		# The plinth and skirting are split at host boundaries, with flush seams.
		var length_axis := Vector3(1.2, 0.22, 0.045) if normal.z != 0 else Vector3(0.045, 0.22, 1.2)
		_box(game, wall, normal * 0.197 + Vector3(0, -0.45, 0), length_axis, "concrete")
		var inside_size := Vector3(1.2, 0.11, 0.035) if normal.z != 0 else Vector3(0.035, 0.11, 1.2)
		var raised := 0.14 if level > 0 else 0.02
		_box(game, wall, -normal * 0.198 + Vector3(0, -0.52 + raised, 0), inside_size, "trim")
	if row == 2:
		# A narrow plaster cornice gives the facade a readable floor division.
		var band_size := Vector3(1.2, 0.10, 0.055) if normal.z != 0 else Vector3(0.055, 0.10, 1.2)
		_box(game, wall, normal * 0.20 + Vector3(0, 0.48, 0), band_size, "trim")
	# Tiny facade seams are neither geometry gaps nor mortar on finished plaster.
	if level == 0 and row == 2 and normal.z > 0 and absf(wall.position.x) < 2.0:
		_box(game, wall, tangent * 0.0 + normal * 0.20 + Vector3(0, -0.49, 0), Vector3(1.2, 0.13, 0.05), "trim")

static func _window(game: Variant, at: Vector3, width: float, outward: Vector3) -> void:
	var side_wall := outward.x != 0
	var size := Vector3(0.035, 1.08, width - 0.12) if side_wall else Vector3(width - 0.12, 1.08, 0.035)
	_piece(game, at, size, "glass", "glass")
	var sill_size := Vector3(0.53, 0.11, width + 0.14) if side_wall else Vector3(width + 0.14, 0.11, 0.53)
	var host := _piece(game, at + Vector3(0, -0.585, 0) + outward * 0.045, sill_size, "concrete", "concrete")
	var basis := Basis.IDENTITY
	if side_wall:
		basis = Basis(Vector3.UP, PI * 0.5)
	var assembly := Node3D.new()
	assembly.position = at - host.position
	assembly.basis = basis
	host.add_child(assembly)
	# Rebated frame, a separate inner sash, and thin mullions on wide windows.
	for x in [-width * 0.5 + 0.045, width * 0.5 - 0.045]:
		_box(game, assembly, Vector3(x, 0, 0), Vector3(0.09, 1.2, 0.20), "trim")
	for y in [-0.555, 0.555]:
		_box(game, assembly, Vector3(0, y, 0), Vector3(width, 0.09, 0.20), "trim")
	for y in [-0.485, 0.485]:
		_box(game, assembly, Vector3(0, y, 0.024), Vector3(width - 0.17, 0.035, 0.065), "white")
	if width > 1.5:
		_box(game, assembly, Vector3.ZERO, Vector3(0.065, 1.1, 0.15), "trim")
		_box(game, assembly, Vector3(0.10, -0.12, -0.11), Vector3(0.025, 0.11, 0.025), "steel")
	else:
		_box(game, assembly, Vector3(width * 0.5 - 0.13, -0.12, -0.11), Vector3(0.025, 0.11, 0.025), "steel")
	# Window reveals are the full 36 cm structural wall thickness. Interior
	# jamb strips make the recess readable even under subdued indoor light.
	for x in [-width * 0.5 + 0.03, width * 0.5 - 0.03]:
		_box(game, assembly, Vector3(x, 0, 0), Vector3(0.045, 1.12, 0.35), "interior_warm")

static func _build_floor(game: Variant, level: int) -> void:
	var floor_y := 3.7 * float(level + 1)
	for x in range(10):
		for z in range(8):
			if level == 0 and x >= 7 and z >= 1:
				continue
			var host := _piece(game, Vector3(-5.4 + x * 1.2, floor_y, -4.2 + z * 1.2), Vector3(1.2, 0.23, 1.2), "concrete", "concrete")
			if level == 0:
				_box(game, host, Vector3(0, 0.128, 0), Vector3(1.2, 0.026, 1.2), "wood")
				_box(game, host, Vector3(0, -0.12, 0), Vector3(1.2, 0.012, 1.2), "interior_warm")
			else:
				_box(game, host, Vector3(0, 0.13, 0), Vector3(1.2, 0.03, 1.2), "roof")
				if x in [0, 9]:
					var sign_x := -1.0 if x == 0 else 1.0
					_box(game, host, Vector3(sign_x * 0.61, 0.20, 0), Vector3(0.30, 0.20, 1.2), "concrete")
					_box(game, host, Vector3(sign_x * 0.61, 0.31, 0), Vector3(0.34, 0.035, 1.2), "steel")
				if z in [0, 7]:
					var sign_z := -1.0 if z == 0 else 1.0
					_box(game, host, Vector3(0, 0.20, sign_z * 0.61), Vector3(1.2, 0.20, 0.30), "concrete")
					_box(game, host, Vector3(0, 0.31, sign_z * 0.61), Vector3(1.2, 0.035, 0.34), "steel")
	# Ground finish uses hosts in the perimeter: every strip disappears with a
	# nearby foundation wall rather than leaving an indestructible floating floor.
	if level == 0:
		for x in range(10):
			var center_x := -5.4 + float(x) * 1.2
			var host := _nearest(game, Vector3(center_x, 0.6, -4.8))
			_box(game, host, Vector3(center_x, 0.10, 0) - host.position, Vector3(1.2, 0.03, 9.2), "wood")

static func _gutter(game: Variant, host: Node3D, normal: Vector3) -> void:
	if host.position.y < 6.0:
		return
	var center := normal * 0.30 + Vector3(0, 0.52, 0)
	_box(game, host, center, Vector3(1.2, 0.035, 0.17), "steel")
	_box(game, host, center + normal * 0.075 + Vector3(0, 0.05, 0), Vector3(1.2, 0.10, 0.025), "steel")

static func _downpipe(game: Variant, at: Vector3) -> void:
	var host := _nearest(game, Vector3(at.x, 6.7, signf(at.z) * 4.8))
	_cylinder(game, host, at - host.position, 0.055, 6.78, "steel")
	for y in [0.7, 3.0, 5.5, 6.8]:
		_box(game, host, Vector3(at.x, y, at.z) - host.position, Vector3(0.15, 0.04, 0.12), "steel")

static func _entry(game: Variant) -> void:
	var top := _piece(game, Vector3(0, 2.38, 4.8), Vector3(2.4, 0.16, 0.30), "wood", "darkwood")
	for x in [-1.15, 1.15]:
		_box(game, top, Vector3(x, -1.15, 0), Vector3(0.10, 2.30, 0.30), "darkwood")
		var leaf := Node3D.new()
		leaf.position = Vector3(x, -2.30, -0.04)
		leaf.rotation.y = -signf(x) * deg_to_rad(84.0)
		top.add_child(leaf)
		var direction := -signf(x)
		_box(game, leaf, Vector3(direction * 0.53, 1.11, 0), Vector3(1.06, 2.22, 0.065), "darkwood")
		for y in [0.62, 1.62]:
			_box(game, leaf, Vector3(direction * 0.53, y, 0.037), Vector3(0.85, 0.81, 0.025), "walnut")
		_box(game, leaf, Vector3(direction * 0.92, 1.06, 0.065), Vector3(0.13, 0.035, 0.035), "steel")

static func _stairs(game: Variant) -> void:
	for step in range(18):
		game.stair_ids.append(game.pieces.size())
		var host := _piece(game, Vector3(4.45, 0.106 + step * 0.212, 4.1 - step * 0.44), Vector3(2.0, 0.212, 0.46), "wood", "wood")
		_box(game, host, Vector3(0, 0.11, 0.018), Vector3(2.04, 0.035, 0.48), "darkwood")
		if step % 3 == 0:
			_box(game, host, Vector3(1.02, 0.58, 0), Vector3(0.045, 0.94, 0.045), "steel")
			var handrail := _box(game, host, Vector3(1.02, 1.05 + 0.318, -0.66), Vector3(0.065, 0.065, 1.47), "darkwood")
			handrail.rotation.x = atan2(0.212, 0.44)
	game.stair_ramp = StaticBody3D.new()
	game.stair_ramp.name = "BegehbareTreppenrampe"
	game.stair_ramp.collision_layer = 16
	game.stair_ramp.collision_mask = 0
	game.stair_ramp.position = Vector3(4.45, 0, 0)
	var collision := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([
		Vector3(-1, -0.12, 4.85), Vector3(1, -0.12, 4.85), Vector3(-1, 0, 4.85), Vector3(1, 0, 4.85),
		Vector3(-1, -0.12, -3.65), Vector3(1, -0.12, -3.65), Vector3(-1, 4.06, -3.65), Vector3(1, 4.06, -3.65)])
	collision.shape = wedge
	game.stair_ramp.add_child(collision)
	game.building.add_child(game.stair_ramp)

static func _furnish(game: Variant) -> void:
	# Kitchen: a breakable carcass carries recessed fronts, worktop and fittings.
	var kitchen := _piece(game, Vector3(-4.38, 0.56, -4.05), Vector3(2.55, 0.90, 0.64), "wood", "interior_sage")
	_box(game, kitchen, Vector3(0, 0.48, 0), Vector3(2.64, 0.07, 0.74), "concrete")
	_box(game, kitchen, Vector3(0, -0.39, 0.34), Vector3(2.3, 0.11, 0.025), "darkwood")
	for x in [-0.84, 0.0, 0.84]:
		_box(game, kitchen, Vector3(x, 0.015, 0.337), Vector3(0.79, 0.72, 0.035), "trim")
		_box(game, kitchen, Vector3(x, 0.25, 0.366), Vector3(0.23, 0.026, 0.026), "steel")
	_box(game, kitchen, Vector3(-0.76, 0.523, 0), Vector3(0.70, 0.018, 0.47), "steel")
	_box(game, kitchen, Vector3(-0.76, 0.535, 0), Vector3(0.56, 0.012, 0.34), "ink")
	_cylinder(game, kitchen, Vector3(-0.76, 0.65, -0.20), 0.018, 0.25, "steel")
	var stove := _piece(game, Vector3(-2.35, 0.58, -4.04), Vector3(0.65, 0.93, 0.68), "steel", "white")
	_box(game, stove, Vector3(0, -0.05, 0.353), Vector3(0.49, 0.48, 0.018), "ink")
	_box(game, stove, Vector3(0, 0.26, 0.37), Vector3(0.43, 0.035, 0.045), "steel")
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			_cylinder(game, stove, Vector3(x, 0.48, z), 0.105, 0.016, "ink")
	# Ground-floor sofa with a readable seat, back, cushions, feet and arms.
	var sofa := _piece(game, Vector3(-4.25, 0.38, 2.28), Vector3(2.40, 0.42, 0.94), "wood", "fabric")
	_box(game, sofa, Vector3(0, 0.43, 0.37), Vector3(2.4, 0.70, 0.18), "fabric")
	for x in [-1.10, 1.10]:
		_box(game, sofa, Vector3(x, 0.25, 0), Vector3(0.20, 0.49, 1.0), "fabric")
	for x in [-0.55, 0.55]:
		_box(game, sofa, Vector3(x, 0.26, -0.05), Vector3(0.99, 0.13, 0.71), "cushion")
		_box(game, sofa, Vector3(x, 0.54, 0.23), Vector3(0.94, 0.39, 0.14), "fabric")
	for x in [-0.95, 0.95]:
		for z in [-0.32, 0.32]:
			_box(game, sofa, Vector3(x, -0.23, z), Vector3(0.07, 0.18, 0.07), "darkwood")
	_table(game, Vector3(-3.55, 0.12, 0.15))
	# Radiator under the rear window, attached to its sill rather than floating.
	var radiator_host := _nearest(game, Vector3(-3.6, 1.215, -4.8))
	for i in range(11):
		_box(game, radiator_host, Vector3(-4.34 + i * 0.145, 0.67, -4.46) - radiator_host.position, Vector3(0.09, 0.70, 0.13), "white")
	# Upstairs bed and bedside cabinet, kept on the west side of the stair void.
	var bed := _piece(game, Vector3(-3.50, 4.08, 1.80), Vector3(2.25, 0.40, 1.65), "wood", "darkwood")
	_box(game, bed, Vector3(0, 0.28, 0), Vector3(2.18, 0.20, 1.58), "porcelain")
	_box(game, bed, Vector3(-0.30, 0.405, 0), Vector3(1.55, 0.05, 1.60), "fabric")
	_box(game, bed, Vector3(1.03, 0.50, 0), Vector3(0.10, 0.95, 1.70), "walnut")
	for z in [-0.39, 0.39]:
		_box(game, bed, Vector3(0.66, 0.43, z), Vector3(0.53, 0.12, 0.64), "cushion")
	var cabinet := _piece(game, Vector3(-2.31, 4.11, 0.49), Vector3(0.56, 0.55, 0.53), "wood", "walnut")
	for y in [-0.14, 0.10]:
		_box(game, cabinet, Vector3(0, y, 0.28), Vector3(0.49, 0.21, 0.025), "darkwood")
		_box(game, cabinet, Vector3(0, y, 0.30), Vector3(0.13, 0.025, 0.025), "steel")

static func _table(game: Variant, at: Vector3) -> void:
	# One structural host, four separately modeled legs and a chamfer-like rim.
	var host := _piece(game, at + Vector3(0, 0.66, 0), Vector3(1.80, 0.09, 0.95), "wood", "walnut")
	for x in [-0.76, 0.76]:
		for z in [-0.34, 0.34]:
			_box(game, host, Vector3(x, -0.32, z), Vector3(0.075, 0.63, 0.075), "darkwood")
	_box(game, host, Vector3(0, -0.11, 0), Vector3(1.61, 0.15, 0.78), "darkwood")

static func _nearest(game: Variant, at: Vector3) -> Node3D:
	var best: Node3D = game.pieces[0]
	var distance := INF
	for candidate in game.pieces:
		var next_distance: float = candidate.position.distance_squared_to(at)
		if next_distance < distance:
			distance = next_distance
			best = candidate
	return best

static func _box(game: Variant, parent: Node3D, at: Vector3, size: Vector3, material_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = game.materials[material_name] as Material
	instance.position = at
	parent.add_child(instance)
	return instance

static func _cylinder(game: Variant, parent: Node3D, at: Vector3, radius: float, height: float, material_name: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = game.materials[material_name] as Material
	instance.position = at
	parent.add_child(instance)
	return instance
