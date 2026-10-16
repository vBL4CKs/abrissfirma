extends Node3D
class_name AbrissSiteArt

## Rein prozedurale Kulisse. Kran und Lieferwagen sind in dieser Etappe Dekoration.
## Die Fläche x = -8…8 / z = -7…7 bleibt für das Abrisshaus frei.

var _sa_materials: Dictionary = {}
var _sa_built: bool = false


func build_site() -> void:
	if _sa_built:
		return
	_sa_built = true
	_sa_setup_materials()
	_sa_access_and_markings()
	_sa_perimeter()
	_sa_crane(Vector3(15.2, 0.0, -8.7))
	_sa_van(Vector3(-15.0, 0.0, 11.5))
	_sa_site_props()
	_sa_neighborhood()


func _sa_setup_materials() -> void:
	_sa_make_material("yellow", Color("f3ba32"), 0.69)
	_sa_make_material("yellow_dark", Color("bf861e"), 0.78)
	_sa_make_material("charcoal", Color("263b43"), 0.83)
	_sa_make_material("rubber", Color("263036"), 0.98)
	_sa_make_material("steel", Color("637d83"), 0.48, 0.45)
	_sa_make_material("wire", Color("9bafb0"), 0.7, 0.2)
	_sa_make_material("white", Color("f2f0df"), 0.84)
	_sa_make_material("orange", Color("ed793e"), 0.84)
	_sa_make_material("red", Color("bc5144"), 0.82)
	_sa_make_material("blue", Color("5d929f"), 0.83)
	_sa_make_material("glass", Color("80bbc5"), 0.2, 0.25)
	_sa_make_material("paving", Color("b9b7a4"), 0.96)
	_sa_make_material("wood", Color("b58251"), 0.93)
	_sa_make_material("wood_light", Color("d5ad75"), 0.95)
	_sa_make_material("trunk", Color("8d7054"), 1.0)
	_sa_make_material("leaf", Color("61936e"), 1.0)
	_sa_make_material("leaf_light", Color("8bb47b"), 1.0)
	_sa_make_material("leaf_dark", Color("3d7463"), 1.0)
	_sa_make_material("hill", Color("829e92"), 1.0)
	_sa_make_material("hill_far", Color("a9b9ac"), 1.0)
	_sa_make_material("cream", Color("e4d5ad"), 0.94)
	_sa_make_material("rose", Color("d4a28c"), 0.94)
	_sa_make_material("sage", Color("a5b9a2"), 0.94)
	_sa_make_material("roof", Color("766659"), 0.92)
	_sa_make_material("skin", Color("d9a882"), 0.95)
	_sa_make_material("navy", Color("35526b"), 0.95)


func _sa_make_material(key: String, color: Color, roughness: float, metallic: float = 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_sa_materials[key] = material


func _sa_box(parent: Node3D, at: Vector3, size: Vector3, material_key: String, solid: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _sa_materials[material_key] as Material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh_instance.add_child(body)
	return mesh_instance


func _sa_cylinder(parent: Node3D, at: Vector3, radius_bottom: float, radius_top: float, height: float, material_key: String, sides: int = 12) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = radius_bottom
	cylinder.top_radius = radius_top
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	mesh_instance.mesh = cylinder
	mesh_instance.material_override = _sa_materials[material_key] as Material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


func _sa_many_boxes(parent: Node3D, positions: Array[Vector3], size: Vector3, material_key: String) -> void:
	var box := BoxMesh.new()
	box.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = box
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _sa_materials[material_key] as Material
	parent.add_child(instance)


func _sa_sphere(parent: Node3D, at: Vector3, radius: float, material_key: String, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _sa_materials[material_key] as Material
	mesh_instance.position = at
	mesh_instance.scale = stretch
	parent.add_child(mesh_instance)
	return mesh_instance


func _sa_rod(parent: Node3D, a: Vector3, b: Vector3, thickness: float, material_key: String) -> MeshInstance3D:
	var distance: float = a.distance_to(b)
	var rod: MeshInstance3D = _sa_box(parent, (a + b) * 0.5, Vector3(thickness, distance, thickness), material_key)
	var direction: Vector3 = (b - a).normalized()
	var reference: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.96 else Vector3.RIGHT
	var axis_x: Vector3 = direction.cross(reference).normalized()
	var axis_z: Vector3 = axis_x.cross(direction).normalized()
	rod.basis = Basis(axis_x, direction, axis_z)
	return rod


func _sa_text(parent: Node3D, at: Vector3, wording: String, font_size: int, pixel_size: float, tint: Color = Color("f2f0df")) -> Label3D:
	var label := Label3D.new()
	label.text = wording
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = tint
	label.outline_size = 0
	label.position = at
	label.no_depth_test = false
	label.shaded = false
	parent.add_child(label)
	return label


func _sa_sign(at: Vector3, wording: String, width: float, height: float, color_key: String = "charcoal", face_yaw: float = 0.0) -> void:
	var sign_root := Node3D.new()
	sign_root.position = at
	sign_root.rotation.y = face_yaw
	add_child(sign_root)
	_sa_box(sign_root, Vector3(0.0, 0.75, 0.0), Vector3(0.11, 1.5, 0.11), "steel")
	_sa_box(sign_root, Vector3(0.0, 1.8, 0.0), Vector3(width, height, 0.12), color_key)
	_sa_box(sign_root, Vector3(0.0, 1.8 + height * 0.5 - 0.055, 0.069), Vector3(width - 0.1, 0.075, 0.015), "yellow")
	_sa_text(sign_root, Vector3(0.0, 1.78, 0.075), wording, 52, 0.0075)


func _sa_access_and_markings() -> void:
	# Großzügiger Weg zum Haus; alle Platten liegen außerhalb des Baufeldes.
	for row in range(6):
		for column in range(3):
			_sa_box(self, Vector3(9.35 + float(column) * 1.7, -0.018, 8.8 + float(row) * 1.95), Vector3(1.62, 0.045, 1.85), "paving")
	for index in range(8):
		_sa_box(self, Vector3(-11.0 + float(index) * 2.7, 0.006, 20.65), Vector3(1.25, 0.017, 0.12), "white")
	_sa_box(self, Vector3(8.2, 0.008, 10.0), Vector3(0.12, 0.02, 4.0), "yellow")
	_sa_box(self, Vector3(14.0, 0.008, 10.0), Vector3(0.12, 0.02, 4.0), "yellow")
	_sa_sign(Vector3(5.2, 0.0, 12.0), "ABRISSFIRMA\nDEIN ERSTER AUFTRAG", 3.8, 1.25, "charcoal", 0.2)
	_sa_sign(Vector3(-8.8, 0.0, 4.8), "BAUSTELLE\nHELM AUF!", 2.2, 1.1, "blue", 0.35)


func _sa_perimeter() -> void:
	_sa_fence_run(Vector3(-23.0, 0.0, -22.0), Vector3(23.0, 0.0, -22.0))
	_sa_fence_run(Vector3(-23.0, 0.0, -22.0), Vector3(-23.0, 0.0, 22.0))
	_sa_fence_run(Vector3(23.0, 0.0, -22.0), Vector3(23.0, 0.0, 22.0))
	_sa_fence_run(Vector3(-23.0, 0.0, 22.0), Vector3(8.0, 0.0, 22.0))
	_sa_fence_run(Vector3(16.0, 0.0, 22.0), Vector3(23.0, 0.0, 22.0))
	_sa_sign(Vector3(18.7, 0.0, 21.4), "BETRIEBSGELÄNDE\nZUTRITT FÜR PROFIS", 3.8, 1.1, "charcoal", 0.0)


func _sa_fence_run(start: Vector3, end: Vector3) -> void:
	var distance: float = start.distance_to(end)
	var sections: int = maxi(1, ceili(distance / 4.0))
	var posts: Array[Vector3] = []
	var feet: Array[Vector3] = []
	for index in range(sections + 1):
		var point: Vector3 = start.lerp(end, float(index) / float(sections))
		posts.append(point + Vector3(0.0, 1.05, 0.0))
		feet.append(point + Vector3(0.0, 0.045, 0.0))
	_sa_many_boxes(self, posts, Vector3(0.085, 2.1, 0.085), "steel")
	_sa_many_boxes(self, feet, Vector3(0.52, 0.09, 0.25), "charcoal")
	_sa_rod(self, start + Vector3(0.0, 1.96, 0.0), end + Vector3(0.0, 1.96, 0.0), 0.055, "wire")
	_sa_rod(self, start + Vector3(0.0, 0.22, 0.0), end + Vector3(0.0, 0.22, 0.0), 0.055, "wire")
	# Ein gemeinsames Liniennetz pro Zaunseite statt vieler einzelner Drahtobjekte.
	var wire_mesh := ImmediateMesh.new()
	wire_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _sa_materials["wire"] as Material)
	var steps: int = ceili(distance / 0.42)
	for index in range(steps + 1):
		var along: float = float(index) / float(steps)
		var point: Vector3 = start.lerp(end, along)
		wire_mesh.surface_add_vertex(point + Vector3(0.0, 0.24, 0.0))
		wire_mesh.surface_add_vertex(point + Vector3(0.0, 1.94, 0.0))
	for index in range(6):
		var height: float = 0.25 + float(index) * 0.33
		wire_mesh.surface_add_vertex(start + Vector3(0.0, height, 0.0))
		wire_mesh.surface_add_vertex(end + Vector3(0.0, height, 0.0))
	wire_mesh.surface_end()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = wire_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(distance, 2.1, 0.13)
	collision.shape = shape
	body.position = (start + end) * 0.5 + Vector3(0.0, 1.05, 0.0)
	body.rotation.y = -atan2(end.z - start.z, end.x - start.x)
	body.add_child(collision)
	add_child(body)


func _sa_crane(at: Vector3) -> void:
	var crane := Node3D.new()
	crane.name = "AusstellungsKran"
	crane.position = at
	add_child(crane)
	for side in [-1.0, 1.0]:
		_sa_box(crane, Vector3(0.0, 0.62, side * 1.45), Vector3(4.4, 1.1, 0.85), "rubber", true)
		_sa_box(crane, Vector3(0.0, 0.7, side * 1.9), Vector3(3.8, 0.16, 0.06), "steel")
		for wheel_index in range(5):
			var wheel: MeshInstance3D = _sa_cylinder(crane, Vector3(-1.55 + float(wheel_index) * 0.78, 0.6, side * 1.9), 0.3, 0.3, 0.085, "charcoal")
			wheel.rotation.x = PI * 0.5
	_sa_box(crane, Vector3(0.0, 1.34, 0.0), Vector3(3.5, 0.55, 2.8), "charcoal", true)
	_sa_cylinder(crane, Vector3(0.0, 1.75, 0.0), 1.02, 1.02, 0.32, "steel")
	_sa_box(crane, Vector3(0.25, 2.22, 0.0), Vector3(3.6, 0.7, 2.35), "yellow", true)
	_sa_box(crane, Vector3(1.6, 2.95, 0.0), Vector3(1.4, 1.0, 2.35), "yellow_dark", true)
	_sa_box(crane, Vector3(1.6, 3.49, 0.0), Vector3(1.5, 0.12, 2.44), "yellow")
	_sa_box(crane, Vector3(-1.0, 3.07, 0.68), Vector3(1.55, 1.5, 1.2), "yellow", true)
	_sa_box(crane, Vector3(-1.0, 3.25, 1.295), Vector3(1.24, 0.94, 0.035), "glass")
	_sa_box(crane, Vector3(-1.79, 3.25, 0.69), Vector3(0.035, 0.94, 0.94), "glass")
	_sa_box(crane, Vector3(-1.0, 3.91, 0.68), Vector3(1.8, 0.18, 1.42), "charcoal")
	_sa_box(crane, Vector3(0.85, 2.54, 1.19), Vector3(0.8, 0.18, 0.03), "white")
	_sa_text(crane, Vector3(0.8, 2.95, 1.2), "AF–01", 44, 0.009)
	# Leichter Fachwerkausleger mit sichtbaren gelben Kreuzstreben.
	var boom_start := Vector3(-0.35, 2.9, -0.15)
	var boom_tip := Vector3(-6.4, 13.6, -0.15)
	var half_width: float = 0.43
	for side in [-1.0, 1.0]:
		_sa_rod(crane, boom_start + Vector3(0.0, 0.0, side * half_width), boom_tip + Vector3(0.0, 0.0, side * half_width), 0.14, "yellow")
	for index in range(8):
		var lower: Vector3 = boom_start.lerp(boom_tip, float(index) / 8.0)
		var upper: Vector3 = boom_start.lerp(boom_tip, float(index + 1) / 8.0)
		_sa_rod(crane, lower + Vector3(0.0, 0.0, -half_width), upper + Vector3(0.0, 0.0, half_width), 0.07, "yellow")
		_sa_rod(crane, lower + Vector3(0.0, 0.0, half_width), upper + Vector3(0.0, 0.0, -half_width), 0.07, "yellow_dark")
		_sa_rod(crane, upper + Vector3(0.0, 0.0, -half_width), upper + Vector3(0.0, 0.0, half_width), 0.09, "yellow")
	_sa_rod(crane, Vector3(1.7, 3.4, 0.0), boom_tip, 0.038, "charcoal")
	_sa_cylinder(crane, Vector3(-6.4, 13.6, -0.15), 0.32, 0.32, 0.95, "charcoal").rotation.x = PI * 0.5
	_sa_rod(crane, boom_tip, Vector3(-6.4, 4.75, -0.15), 0.042, "charcoal")
	_sa_cylinder(crane, Vector3(-6.4, 4.65, -0.15), 0.13, 0.13, 0.35, "steel")
	_sa_sphere(crane, Vector3(-6.4, 3.62, -0.15), 1.0, "charcoal")
	_sa_rod(crane, Vector3(-6.4, 4.6, -0.15), Vector3(-6.4, 4.1, -0.15), 0.11, "steel")
	_sa_sign(at + Vector3(1.2, 0.0, 4.2), "KRAN · BALD VERFÜGBAR\nMASCHINENPARK", 4.6, 1.2, "charcoal", -0.15)
	_sa_barrier(at + Vector3(-5.5, 0.0, 2.8), 3.0, 0.0)
	_sa_barrier(at + Vector3(3.4, 0.0, 1.8), 2.8, PI * 0.5)


func _sa_van(at: Vector3) -> void:
	var van := Node3D.new()
	van.name = "Servicewagen"
	van.position = at
	van.rotation.y = 0.22
	add_child(van)
	_sa_box(van, Vector3(0.0, 0.58, 0.0), Vector3(2.4, 0.55, 5.0), "charcoal", true)
	_sa_box(van, Vector3(0.0, 1.64, -0.55), Vector3(2.3, 1.9, 3.7), "white", true)
	_sa_box(van, Vector3(0.0, 1.19, 1.8), Vector3(2.3, 0.8, 1.15), "white", true)
	_sa_box(van, Vector3(0.0, 1.94, 1.13), Vector3(2.15, 1.0, 0.045), "glass")
	_sa_box(van, Vector3(0.0, 1.39, 2.4), Vector3(1.3, 0.25, 0.05), "charcoal")
	for side in [-1.0, 1.0]:
		for axle_z in [-1.4, 1.5]:
			var wheel: MeshInstance3D = _sa_cylinder(van, Vector3(side * 1.17, 0.6, axle_z), 0.49, 0.49, 0.24, "rubber")
			wheel.rotation.z = PI * 0.5
			var hub: MeshInstance3D = _sa_cylinder(van, Vector3(side * 1.31, 0.6, axle_z), 0.24, 0.24, 0.025, "steel")
			hub.rotation.z = PI * 0.5
		_sa_box(van, Vector3(side * 1.16, 1.47, -0.25), Vector3(0.025, 0.37, 2.55), "yellow")
		_sa_box(van, Vector3(side * 1.16, 2.02, 0.48), Vector3(0.025, 0.76, 0.9), "glass")
		_sa_box(van, Vector3(side * 0.83, 1.22, 2.4), Vector3(0.38, 0.24, 0.045), "yellow")
		_sa_box(van, Vector3(side * 0.83, 1.37, -2.43), Vector3(0.2, 0.65, 0.045), "red")
	_sa_box(van, Vector3(0.0, 2.76, -0.6), Vector3(1.7, 0.15, 2.4), "steel")
	_sa_box(van, Vector3(0.0, 2.93, -0.6), Vector3(0.38, 0.18, 3.0), "wood_light")
	_sa_box(van, Vector3(0.0, 0.9, 2.48), Vector3(2.4, 0.22, 0.15), "charcoal")
	_sa_text(van, Vector3(0.0, 1.65, 2.414), "ABRISSFIRMA", 44, 0.007, Color("263b43"))


func _sa_barrier(at: Vector3, width: float, angle: float) -> void:
	var barrier := Node3D.new()
	barrier.position = at
	barrier.rotation.y = angle
	add_child(barrier)
	for side in [-1.0, 1.0]:
		_sa_box(barrier, Vector3(side * (width * 0.5 - 0.24), 0.6, 0.0), Vector3(0.1, 1.2, 0.11), "charcoal")
		_sa_box(barrier, Vector3(side * (width * 0.5 - 0.24), 0.07, 0.0), Vector3(0.5, 0.14, 0.65), "charcoal")
	_sa_box(barrier, Vector3(0.0, 0.95, 0.0), Vector3(width, 0.43, 0.17), "white", true)
	var stripes: int = maxi(2, int(width / 0.55))
	for index in range(stripes):
		var stripe: MeshInstance3D = _sa_box(barrier, Vector3(-width * 0.5 + 0.28 + float(index) * (width - 0.56) / float(maxi(1, stripes - 1)), 0.95, 0.093), Vector3(0.21, 0.37, 0.018), "orange")
		stripe.rotation.z = -0.32


func _sa_cone(at: Vector3) -> void:
	_sa_box(self, at + Vector3(0.0, 0.045, 0.0), Vector3(0.43, 0.09, 0.43), "charcoal")
	_sa_cylinder(self, at + Vector3(0.0, 0.34, 0.0), 0.17, 0.035, 0.56, "orange", 8)
	_sa_cylinder(self, at + Vector3(0.0, 0.4, 0.0), 0.109, 0.079, 0.13, "white", 8)


func _sa_crate(at: Vector3, size: Vector3) -> void:
	_sa_box(self, at + Vector3(0.0, size.y * 0.5, 0.0), size, "wood", true)
	for side in [-1.0, 1.0]:
		_sa_box(self, at + Vector3(side * size.x * 0.35, size.y * 0.5, size.z * 0.5 + 0.014), Vector3(0.1, size.y, 0.035), "wood_light")
	_sa_box(self, at + Vector3(0.0, size.y * 0.58, size.z * 0.5 + 0.04), Vector3(size.x * 0.68, 0.19, 0.03), "charcoal")


func _sa_site_props() -> void:
	_sa_barrier(Vector3(-9.6, 0.0, 9.2), 3.0, -0.2)
	_sa_barrier(Vector3(-8.9, 0.0, -9.0), 3.0, 0.1)
	_sa_crate(Vector3(-12.0, 0.0, -7.6), Vector3(1.5, 1.05, 1.25))
	_sa_crate(Vector3(-13.7, 0.0, -8.0), Vector3(1.25, 0.8, 1.2))
	_sa_crate(Vector3(-12.1, 1.05, -7.6), Vector3(1.05, 0.65, 0.95))
	for index in range(4):
		_sa_box(self, Vector3(-17.5, 0.12 + float(index) * 0.23, -4.0), Vector3(3.4, 0.18, 0.8), "wood_light")
	for at in [Vector3(8.0, 0.0, 17.0), Vector3(15.0, 0.0, 17.0), Vector3(8.0, 0.0, 20.2), Vector3(15.0, 0.0, 20.2), Vector3(-10.8, 0.0, 6.5), Vector3(12.0, 0.0, -4.5)]:
		_sa_cone(at)
	# Kleine Servicebox im Westen, fern vom begehbaren Haus.
	_sa_box(self, Vector3(-18.5, 1.4, -13.2), Vector3(4.0, 2.8, 3.0), "blue", true)
	_sa_box(self, Vector3(-18.5, 2.86, -13.2), Vector3(4.3, 0.18, 3.3), "white")
	_sa_box(self, Vector3(-19.25, 1.2, -11.68), Vector3(1.0, 2.3, 0.05), "charcoal")
	_sa_box(self, Vector3(-17.55, 1.77, -11.67), Vector3(1.1, 0.75, 0.04), "glass")
	_sa_text(self, Vector3(-18.5, 2.48, -11.64), "SERVICE", 48, 0.01)
	_sa_worker(Vector3(-12.3, 0.0, 13.5), -0.15)
	_sa_worker(Vector3(18.0, 0.0, 8.5), -0.65)


func _sa_worker(at: Vector3, angle: float) -> void:
	var worker := Node3D.new()
	worker.position = at
	worker.rotation.y = angle
	add_child(worker)
	for side in [-1.0, 1.0]:
		_sa_box(worker, Vector3(side * 0.14, 0.41, 0.0), Vector3(0.21, 0.7, 0.25), "navy")
		_sa_box(worker, Vector3(side * 0.14, 0.1, 0.075), Vector3(0.24, 0.2, 0.43), "charcoal")
	_sa_box(worker, Vector3(0.0, 1.02, 0.0), Vector3(0.6, 0.65, 0.34), "orange")
	_sa_box(worker, Vector3(0.0, 0.99, 0.18), Vector3(0.61, 0.1, 0.025), "yellow")
	_sa_box(worker, Vector3(0.0, 1.19, 0.18), Vector3(0.61, 0.05, 0.025), "white")
	_sa_rod(worker, Vector3(-0.37, 1.25, 0.0), Vector3(-0.4, 0.81, 0.12), 0.18, "navy")
	_sa_rod(worker, Vector3(0.37, 1.25, 0.0), Vector3(0.45, 0.91, 0.23), 0.18, "navy")
	_sa_sphere(worker, Vector3(0.0, 1.53, 0.0), 0.22, "skin", Vector3(0.88, 1.1, 0.9))
	_sa_sphere(worker, Vector3(0.0, 1.74, 0.0), 0.245, "yellow", Vector3(1.0, 0.65, 1.0))
	_sa_cylinder(worker, Vector3(0.0, 1.68, 0.025), 0.29, 0.29, 0.055, "yellow")
	_sa_box(worker, Vector3(0.45, 0.91, 0.32), Vector3(0.4, 0.48, 0.06), "wood")


func _sa_tree(at: Vector3, height: float, variation: int) -> void:
	_sa_cylinder(self, at + Vector3(0.0, height * 0.27, 0.0), 0.18, 0.12, height * 0.54, "trunk", 7)
	var tint: String = "leaf_light" if variation % 3 == 0 else ("leaf_dark" if variation % 3 == 1 else "leaf")
	_sa_sphere(self, at + Vector3(0.0, height * 0.75, 0.0), height * 0.34, tint, Vector3(1.0, 1.2, 0.95))
	_sa_sphere(self, at + Vector3(height * 0.2, height * 0.61, 0.04), height * 0.24, tint)


func _sa_background_house(at: Vector3, width: float, height: float, color_key: String) -> void:
	_sa_box(self, at + Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, 5.5), color_key)
	_sa_box(self, at + Vector3(0.0, height + 0.18, 0.0), Vector3(width + 0.6, 0.35, 6.1), "roof")
	for side in [-1.0, 1.0]:
		for floor_index in range(maxi(1, int(height / 2.6))):
			_sa_box(self, at + Vector3(side * width * 0.27, 1.4 + float(floor_index) * 2.4, 2.77), Vector3(1.05, 1.28, 0.045), "glass")
	_sa_box(self, at + Vector3(0.0, 1.08, 2.79), Vector3(0.95, 2.16, 0.055), "wood")


func _sa_neighborhood() -> void:
	_sa_background_house(Vector3(-28.0, 0.0, -35.0), 7.0, 5.8, "cream")
	_sa_background_house(Vector3(-15.0, 0.0, -34.0), 7.7, 7.8, "rose")
	_sa_background_house(Vector3(-2.0, 0.0, -36.0), 8.0, 5.6, "sage")
	_sa_background_house(Vector3(12.0, 0.0, -35.0), 7.2, 8.0, "cream")
	_sa_background_house(Vector3(28.0, 0.0, -33.0), 8.0, 5.9, "rose")
	_sa_background_house(Vector3(-34.0, 0.0, 0.0), 6.5, 5.8, "sage")
	_sa_background_house(Vector3(34.0, 0.0, 6.0), 7.0, 5.8, "cream")
	for index in range(11):
		var tree_x: float = -35.0 + float(index) * 7.0
		_sa_tree(Vector3(tree_x, 0.0, -26.5 - float(index % 3) * 1.7), 4.3 + float(index % 4) * 0.45, index)
	for index in range(5):
		_sa_tree(Vector3(-27.0 - float(index % 2), 0.0, -15.0 + float(index) * 9.0), 4.6 + float(index % 3) * 0.5, index + 1)
		_sa_tree(Vector3(27.5 + float(index % 2), 0.0, -15.0 + float(index) * 9.0), 4.4 + float(index % 3) * 0.6, index)
	# Sanfte, matte Hügel schließen den Horizont ohne Texturen ab.
	for index in range(5):
		_sa_sphere(self, Vector3(-68.0 + float(index) * 35.0, -8.0, -78.0 - float(index % 2) * 10.0), 24.0 + float(index % 3) * 4.0, "hill_far", Vector3(1.6, 0.85, 1.0))
	_sa_sphere(self, Vector3(-85.0, -9.0, -18.0), 32.0, "hill", Vector3(1.0, 0.7, 1.5))
	_sa_sphere(self, Vector3(86.0, -9.0, -18.0), 34.0, "hill", Vector3(1.0, 0.7, 1.5))
