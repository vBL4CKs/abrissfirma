extends StaticBody3D
class_name AbrissPiece

const Fracture = preload("res://scripts/fracture_mesh.gd")
static var _fracture_cache: Dictionary = {}
static var _paint_cache: Dictionary = {}
var piece_id: int = -1
var size: Vector3 = Vector3.ONE
var kind: String = "brick"
var health: float = 70.0
var max_health: float = 70.0
var anchored: bool = false
var removed: bool = false
var pending_collapse: bool = false
var neighbors: Array[int] = []
var visual: MeshInstance3D
var material: StandardMaterial3D
var core_material: StandardMaterial3D
var inside_material: StandardMaterial3D
var wall_normal := Vector3.ZERO
var damage_marks: Array[MeshInstance3D] = []
var fracture_chunks: Array[Dictionary] = []
var eroded_chunks: Array[int] = []
var _newly_eroded: Array[Dictionary] = []
var _chunk_visuals: Array[MeshInstance3D] = []
var _chunk_colliders: Array[CollisionShape3D] = []
var _primary_collision: CollisionShape3D

func setup(id: int, location: Vector3, dimensions: Vector3, surface: String, base_material: StandardMaterial3D) -> void:
	piece_id = id
	position = location
	size = dimensions
	kind = surface
	anchored = location.y < 0.85
	max_health = {"brick": 65.0, "concrete": 95.0, "wood": 42.0, "glass": 15.0}.get(kind, 65.0)
	health = max_health
	collision_layer = 2
	collision_mask = 0
	material = base_material
	core_material = base_material
	inside_material = base_material
	visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	_primary_collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_primary_collision.shape = box
	add_child(_primary_collision)

func configure_wall(interior: StandardMaterial3D, core: StandardMaterial3D, outward: Vector3) -> void:
	inside_material = interior
	core_material = core
	wall_normal = outward.normalized()
	visual.mesh = _paint_mesh(visual.mesh)
	visual.material_override = null

func hit(amount: float, world_point: Vector3 = Vector3.INF, world_normal: Vector3 = Vector3.ZERO) -> bool:
	if removed or pending_collapse:
		return false
	health -= amount
	if world_point.is_finite() and kind != "glass":
		_ensure_fracture()
		var target := to_local(world_point)
		var closest := -1
		var distance := INF
		for index in range(fracture_chunks.size()):
			if index in eroded_chunks:
				continue
			var local_center: Vector3 = fracture_chunks[index]["offset"]
			var candidate := local_center.distance_squared_to(target)
			if candidate < distance:
				distance = candidate
				closest = index
		if closest >= 0:
			eroded_chunks.append(closest)
			_newly_eroded.append(fracture_chunks[closest])
			_chunk_visuals[closest].hide()
			_chunk_colliders[closest].set_deferred("disabled", true)
		_add_cracks(target, world_normal)
	if health <= 0.0:
		return true
	if fracture_chunks.is_empty():
		var damaged := material.duplicate() as StandardMaterial3D
		damaged.albedo_color = material.albedo_color.darkened(0.045)
		if wall_normal == Vector3.ZERO:
			visual.material_override = damaged
	return not fracture_chunks.is_empty() and eroded_chunks.size() >= fracture_chunks.size()

func take_eroded() -> Array[Dictionary]:
	var result := _newly_eroded.duplicate()
	_newly_eroded.clear()
	return result

func remaining_fragments(detail: int = 0) -> Array[Dictionary]:
	_ensure_fracture(detail)
	var result: Array[Dictionary] = []
	for index in range(fracture_chunks.size()):
		if index not in eroded_chunks:
			result.append(fracture_chunks[index])
	return result

func structural_strength() -> float:
	var intact := 1.0 - float(eroded_chunks.size()) / maxf(float(fracture_chunks.size()), 1.0)
	return clampf(intact * 0.65 + maxf(health, 0.0) / max_health * 0.35, 0.05, 1.0)

func _fracture_templates(detail: int) -> Array:
	var cache_key := "%s_%s_%d_%d" % [kind, str(size), piece_id % 4, detail]
	if not _fracture_cache.has(cache_key):
		_fracture_cache[cache_key] = Fracture.chunks(size, kind, (piece_id % 4) * 71 + 19, detail)
	return _fracture_cache[cache_key]

func prewarm_fracture(detail: int = 0) -> void:
	# Populate reusable geometry/material variants while loading, without turning
	# intact walls into physics fragments or adding any scene-tree children.
	for template: Dictionary in _fracture_templates(detail):
		_paint_mesh(template["mesh"])

func _ensure_fracture(detail: int = 1) -> void:
	if not fracture_chunks.is_empty():
		return
	var templates: Array = _fracture_templates(detail)
	visual.hide()
	_primary_collision.set_deferred("disabled", true)
	for template: Dictionary in templates:
		var chunk := template.duplicate()
		chunk["mesh"] = _paint_mesh(chunk["mesh"])
		fracture_chunks.append(chunk)
		var fragment := MeshInstance3D.new()
		fragment.mesh = chunk["mesh"]
		fragment.position = chunk["offset"]
		add_child(fragment)
		_chunk_visuals.append(fragment)
		var collider := CollisionShape3D.new()
		collider.shape = chunk["shape"]
		collider.position = chunk["offset"]
		add_child(collider)
		_chunk_colliders.append(collider)

func _paint_mesh(source: Mesh) -> ArrayMesh:
	# Fracture templates share stable RIDs. Keeping their painted mesh identity
	# enables settled debris to batch; unique intact BoxMeshes are not cached.
	if source is ArrayMesh:
		var key := "%d_%d_%d_%d_%s" % [source.get_rid().get_id(), material.get_rid().get_id(), core_material.get_rid().get_id(), inside_material.get_rid().get_id(), str(wall_normal)]
		if not _paint_cache.has(key):
			_paint_cache[key] = _paint_mesh_uncached(source)
		return _paint_cache[key]
	return _paint_mesh_uncached(source)

func _paint_mesh_uncached(source: Mesh) -> ArrayMesh:
	if wall_normal == Vector3.ZERO:
		var plain := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.create_from(source, surface)
			tool.set_material(material if surface == 0 else core_material)
			var arrays := source.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_TEX_UV] != null and not arrays[Mesh.ARRAY_TEX_UV].is_empty():
				tool.generate_tangents()
			tool.commit(plain)
		return plain
	var tools: Array[SurfaceTool] = []
	var counts: Array[int] = [0, 0, 0]
	for index in range(3):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material([material, core_material, inside_material][index])
		tools.append(tool)
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for tri in range(0, count, 3):
			var first := indices[tri] if not indices.is_empty() else tri
			var normal := normals[first]
			var group := 1
			if surface == 0:
				if normal.dot(wall_normal) > 0.8:
					group = 0
				elif normal.dot(-wall_normal) > 0.8:
					group = 2
			for corner in range(3):
				var index := indices[tri + corner] if not indices.is_empty() else tri + corner
				tools[group].set_normal(normals[index])
				if not uvs.is_empty():
					tools[group].set_uv(uvs[index])
				else:
					tools[group].set_uv(Vector2(vertices[index].x, vertices[index].y))
				tools[group].add_vertex(vertices[index])
				counts[group] += 1
	var mesh := ArrayMesh.new()
	for index in range(3):
		if counts[index] > 0:
			tools[index].generate_tangents()
			tools[index].commit(mesh)
	return mesh

func _add_cracks(point: Vector3, world_normal: Vector3) -> void:
	var normal := global_basis.inverse() * world_normal
	if normal.length_squared() < 0.1:
		normal = wall_normal if wall_normal != Vector3.ZERO else Vector3.UP
	var across := normal.cross(Vector3.UP).normalized()
	if across.length_squared() < 0.1:
		across = Vector3.RIGHT
	var up := across.cross(normal).normalized()
	var immediate := ImmediateMesh.new()
	var crack_material := StandardMaterial3D.new()
	crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack_material.albedo_color = Color("463e35")
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, crack_material)
	for direction in [-1.0, 1.0]:
		var start := point + normal * 0.004
		for segment in range(3):
			var end: Vector3 = start + up * 0.08 * float(direction) + across * sin(float(segment + piece_id)) * 0.065
			immediate.surface_add_vertex(start)
			immediate.surface_add_vertex(end)
			start = end
	immediate.surface_end()
	var mark := MeshInstance3D.new()
	mark.mesh = immediate
	add_child(mark)
	damage_marks.append(mark)

func deactivate() -> void:
	removed = true
	pending_collapse = false
	visible = false
	collision_layer = 0
