class_name AbrissFracture
extends RefCounted
## Seeded, watertight fragments. Surface 0 is the original exterior; surface 1
## contains newly exposed fracture faces. Meshes are centered on their own volume.

static func chunks(size: Vector3, kind: String, seed_value: int, detail: int = 1) -> Array[Dictionary]:
	var dimensions := Vector3(maxf(size.x, 0.025), maxf(size.y, 0.025), maxf(size.z, 0.018))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var axis := _shortest_axis(dimensions)
	if kind == "wood":
		axis = _longest_axis(dimensions)
	var plane := _plane_dimensions(dimensions, axis)
	var thickness: float = dimensions[axis]
	var polygons: Array[PackedVector2Array] = []
	if kind == "glass":
		polygons = _glass_cells(plane, rng, detail)
	else:
		var count := 3 if detail <= 0 else 6
		if kind == "wood":
			count = 3 if detail <= 0 else 4
		elif kind == "plaster":
			count = 4 if detail <= 0 else 8
		polygons = _voronoi_cells(plane, rng, count)
	var result: Array[Dictionary] = []
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		var fragment := _extruded_fragment(polygon, plane, thickness, axis, kind, rng)
		if not fragment.is_empty():
			result.append(fragment)
	return result

static func single_fragment(size: Vector3, kind: String, seed_value: int) -> Dictionary:
	## Useful for a small decorative chip. Bulk fracture should use chunks().
	var pieces := chunks(size, kind, seed_value, 0)
	return pieces[0] if not pieces.is_empty() else {}

static func _shortest_axis(size: Vector3) -> int:
	if size.x <= size.y and size.x <= size.z:
		return 0
	return 1 if size.y <= size.z else 2

static func _longest_axis(size: Vector3) -> int:
	if size.x >= size.y and size.x >= size.z:
		return 0
	return 1 if size.y >= size.z else 2

static func _plane_dimensions(size: Vector3, axis: int) -> Vector2:
	if axis == 0:
		return Vector2(size.y, size.z)
	if axis == 1:
		return Vector2(size.z, size.x)
	return Vector2(size.x, size.y)

static func _point(point: Vector2, depth: float, axis: int) -> Vector3:
	# Cyclic axes preserve a right-handed U/V/extrusion coordinate system.
	if axis == 0:
		return Vector3(depth, point.x, point.y)
	if axis == 1:
		return Vector3(point.y, depth, point.x)
	return Vector3(point.x, point.y, depth)

static func _rectangle(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])

static func _voronoi_cells(size: Vector2, rng: RandomNumberGenerator, count: int) -> Array[PackedVector2Array]:
	var seeds: Array[Vector2] = []
	# Stratification prevents tiny slivers and keeps the chunk count predictable.
	var columns := clampi(int(round(sqrt(float(count) * size.x / maxf(size.y, 0.01)))), 1, count)
	var rows := int(ceil(float(count) / float(columns)))
	for row in range(rows):
		var row_count := mini(columns, count - row * columns)
		for column in range(row_count):
			var u := (float(column) + 0.5 + rng.randf_range(-0.24, 0.24)) / float(row_count)
			var v := (float(row) + 0.5 + rng.randf_range(-0.23, 0.23)) / float(rows)
			seeds.append(Vector2((u - 0.5) * size.x, (v - 0.5) * size.y))
	var cells: Array[PackedVector2Array] = []
	for i in range(seeds.size()):
		var polygon := _rectangle(size)
		for j in range(seeds.size()):
			if i == j:
				continue
			var normal := seeds[j] - seeds[i]
			var distance := 0.5 * (seeds[j].length_squared() - seeds[i].length_squared())
			polygon = _clip(polygon, normal, distance)
			if polygon.size() < 3:
				break
		if polygon.size() >= 3:
			cells.append(polygon)
	return cells

static func _clip(polygon: PackedVector2Array, normal: Vector2, distance: float) -> PackedVector2Array:
	var clipped := PackedVector2Array()
	if polygon.is_empty():
		return clipped
	for i in range(polygon.size()):
		var start := polygon[i]
		var end := polygon[(i + 1) % polygon.size()]
		var start_distance := normal.dot(start) - distance
		var end_distance := normal.dot(end) - distance
		var start_inside := start_distance <= 0.000001
		var end_inside := end_distance <= 0.000001
		if start_inside:
			_append_unique(clipped, start)
		if start_inside != end_inside:
			var t := start_distance / (start_distance - end_distance)
			_append_unique(clipped, start.lerp(end, clampf(t, 0.0, 1.0)))
	if clipped.size() > 1 and clipped[0].distance_squared_to(clipped[-1]) < 0.00000001:
		clipped.remove_at(clipped.size() - 1)
	return clipped

static func _append_unique(points: PackedVector2Array, point: Vector2) -> void:
	if points.is_empty() or points[-1].distance_squared_to(point) > 0.00000001:
		points.append(point)

static func _glass_cells(size: Vector2, rng: RandomNumberGenerator, detail: int) -> Array[PackedVector2Array]:
	var points := _rectangle(size)
	var interior := 1 if detail <= 0 else 3
	for i in range(interior):
		var u := (float(i) + 0.5) / float(interior) - 0.5
		points.append(Vector2((u + rng.randf_range(-0.08, 0.08)) * size.x, rng.randf_range(-0.28, 0.28) * size.y))
	var indices := Geometry2D.triangulate_delaunay(points)
	var result: Array[PackedVector2Array] = []
	for i in range(0, indices.size(), 3):
		var a := points[indices[i]]
		var b := points[indices[i + 1]]
		var c := points[indices[i + 2]]
		if (b - a).cross(c - a) < 0.0:
			var swap := b
			b = c
			c = swap
		result.append(PackedVector2Array([a, b, c]))
	return result

static func _centroid(polygon: PackedVector2Array) -> Vector2:
	var area_twice := 0.0
	var weighted := Vector2.ZERO
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var cross_value := a.cross(b)
		area_twice += cross_value
		weighted += (a + b) * cross_value
	if absf(area_twice) < 0.000001:
		return polygon[0]
	return weighted / (3.0 * area_twice)

static func _extruded_fragment(polygon: PackedVector2Array, plane: Vector2, thickness: float, axis: int, kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var center2 := _centroid(polygon)
	var offset := _point(center2, 0.0, axis)
	var half_depth := thickness * 0.5
	var exterior := SurfaceTool.new()
	var interior := SurfaceTool.new()
	exterior.begin(Mesh.PRIMITIVE_TRIANGLES)
	interior.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hull := PackedVector3Array()
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	var area_twice := 0.0
	for i in range(polygon.size()):
		front.append(_point(polygon[i] - center2, half_depth, axis))
		back.append(_point(polygon[i] - center2, -half_depth, axis))
		hull.append(front[-1])
		hull.append(back[-1])
		area_twice += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	# The two original faces remain unbroken until fragments separate.
	for i in range(1, polygon.size() - 1):
		_triangle(exterior, front[0], front[i], front[i + 1], offset)
		_triangle(exterior, back[0], back[i + 1], back[i], offset)
	var interior_faces := 0
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var outer := _is_outer_edge(polygon[i], polygon[j], plane)
		var target := exterior if outer else interior
		if outer or kind == "glass":
			_triangle(target, back[i], back[j], front[j], offset)
			_triangle(target, back[i], front[j], front[i], offset)
		else:
			# Recess the center slightly: a closed, coarse fractured face instead
			# of a perfectly machined plane. Adjacent chunks never overlap.
			var edge_normal := (back[j] - back[i]).cross(front[j] - back[i]).normalized()
			var center := (back[i] + back[j] + front[j] + front[i]) * 0.25
			var roughness := minf(thickness * 0.07, 0.016) * rng.randf_range(0.45, 1.0)
			center -= edge_normal * roughness
			_triangle(target, back[i], back[j], center, offset)
			_triangle(target, back[j], front[j], center, offset)
			_triangle(target, front[j], front[i], center, offset)
			_triangle(target, front[i], back[i], center, offset)
		if not outer:
			interior_faces += 1
	var mesh := exterior.commit()
	if interior_faces > 0:
		interior.commit(mesh)
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var volume := absf(area_twice) * 0.5 * thickness
	return {"mesh": mesh, "shape": shape, "offset": offset, "volume": volume,
		"small": volume < 0.018, "outer_surface": 0, "inner_surface": 1 if interior_faces > 0 else -1}

static func _is_outer_edge(a: Vector2, b: Vector2, size: Vector2) -> bool:
	var half := size * 0.5
	var epsilon := 0.0001
	return ((absf(a.x + half.x) < epsilon and absf(b.x + half.x) < epsilon)
		or (absf(a.x - half.x) < epsilon and absf(b.x - half.x) < epsilon)
		or (absf(a.y + half.y) < epsilon and absf(b.y + half.y) < epsilon)
		or (absf(a.y - half.y) < epsilon and absf(b.y - half.y) < epsilon))

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, offset: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.length_squared() < 0.1:
		return
	# Godot front faces use clockwise winding viewed from outside. Keep the
	# outward shading normal and reverse the mathematical CCW vertex order.
	for vertex in [a, c, b]:
		var point: Vector3 = vertex
		var world_point := point + offset
		var uv := Vector2(world_point.x, world_point.y)
		var absolute := normal.abs()
		if absolute.x > absolute.y and absolute.x > absolute.z:
			uv = Vector2(world_point.z, world_point.y)
		elif absolute.y > absolute.z:
			uv = Vector2(world_point.x, world_point.z)
		surface.set_normal(normal)
		surface.set_uv(uv)
		surface.add_vertex(point)
