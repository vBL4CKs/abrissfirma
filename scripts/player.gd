extends CharacterBody3D
class_name AbrissPlayer

signal action_requested
signal detonate_requested
signal shop_requested
signal pause_requested
signal tool_requested(index: int)
signal restart_requested

var camera: Camera3D
var head: Node3D
var tool_root: Node3D
var sensitivity: float = 0.002
var speed: float = 6.2
var selected_tool: int = 0
var shake: float = 0.0
var swing_time: float = 0.0
var action_delay: float = 0.0
var motion_time: float = 0.0
var controls_enabled: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 8 | 16
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.33
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.06
	camera.far = 260.0
	head.add_child(camera)
	camera.make_current()
	tool_root = Node3D.new()
	tool_root.position = Vector3(0.48, -0.43, -1.0)
	camera.add_child(tool_root)
	select_tool(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B: shop_requested.emit()
			KEY_R: detonate_requested.emit()
			KEY_F5: restart_requested.emit()
			KEY_1: tool_requested.emit(0)
			KEY_2: tool_requested.emit(1)
			KEY_3: tool_requested.emit(2)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * sensitivity
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, -1.48, 1.48)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and action_delay <= 0.0:
			action_requested.emit()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tool_requested.emit((selected_tool + 2) % 3)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tool_requested.emit((selected_tool + 1) % 3)

func _physics_process(delta: float) -> void:
	action_delay = maxf(0.0, action_delay - delta)
	var direction := Vector3.ZERO
	if controls_enabled:
		var input_vector := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
		if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
			velocity.y = 6.2
	var sprint := 1.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	velocity.x = move_toward(velocity.x, direction.x * speed * sprint, delta * 28.0)
	velocity.z = move_toward(velocity.z, direction.z * speed * sprint, delta * 28.0)
	if not is_on_floor():
		velocity.y -= 16.0 * delta
	move_and_slide()
	if position.y < -12.0:
		position = Vector3(13, 0.2, 17)
		velocity = Vector3.ZERO

func _process(delta: float) -> void:
	motion_time += delta * 8.0
	shake = move_toward(shake, 0.0, delta * 0.8)
	camera.h_offset = randf_range(-shake, shake) * 0.08
	camera.v_offset = randf_range(-shake, shake) * 0.07
	swing_time = maxf(0.0, swing_time - delta)
	var swing := sin((1.0 - swing_time / 0.38) * PI) if swing_time > 0.0 else 0.0
	tool_root.rotation = Vector3(-swing * 1.1, swing * 0.25, -swing * 0.4)
	tool_root.position.y = -0.43 + sin(motion_time) * minf(velocity.length() * 0.002, 0.014)

func swing() -> void:
	swing_time = 0.38
	action_delay = 0.42 if selected_tool == 0 else 0.3

func aim(distance: float) -> Dictionary:
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * distance, 1 | 2)
	return get_world_3d().direct_space_state.intersect_ray(query)

func select_tool(index: int) -> void:
	selected_tool = index
	if not is_instance_valid(tool_root):
		return
	for child in tool_root.get_children():
		tool_root.remove_child(child)
		child.queue_free()
	var surfaces: Dictionary = preload("res://scripts/material_library.gd").build()
	var steel := surfaces["steel"].duplicate() as StandardMaterial3D
	steel.albedo_color = Color("535b60")
	steel.uv1_world_triplanar = false
	steel.uv1_scale = Vector3.ONE * 3.0
	steel.roughness = 0.48
	var polished := _material(Color("9b9c94"), 0.86)
	polished.roughness = 0.34
	var grip := _material(Color("242728"), 0.0)
	grip.roughness = 0.94
	var timber := surfaces["wood"].duplicate() as StandardMaterial3D
	timber.albedo_color = Color("b5946b")
	timber.uv1_world_triplanar = false
	timber.uv1_scale = Vector3(1.3, 0.6, 1.3)
	timber.roughness = 0.72
	var glove := _material(Color("746345"), 0.0)
	glove.roughness = 0.95
	if index == 0:
		# Slender oval ash/fibreglass shaft, rubber grip, forged chamfered head.
		var handle := _tool_cylinder(0.016, 0.65, Vector3(0, -0.015, 0), timber)
		handle.scale.z = 0.82
		var rubber := _tool_cylinder(0.020, 0.25, Vector3(0, -0.215, 0), grip)
		rubber.scale.z = 0.87
		_tool_cylinder(0.023, 0.024, Vector3(0, -0.335, 0), grip)
		for ring in range(7):
			_tool_cylinder(0.0208, 0.004, Vector3(0, -0.30 + ring * 0.026, 0), grip)
		_tool_cylinder(0.023, 0.035, Vector3(0, 0.222, 0), steel)
		_tool_bevel_box(Vector3(0.27, 0.137, 0.140), Vector3(0, 0.300, 0), 0.013, steel)
		for side in [-1, 1]:
			_tool_bevel_box(Vector3(0.012, 0.108, 0.111), Vector3(side * 0.134, 0.300, 0), 0.004, polished)
		_tool_bevel_box(Vector3(0.025, 0.005, 0.019), Vector3(0, 0.371, 0), 0.002, timber)
		_tool_hand(Vector3(0.0, -0.18, 0.028), glove, grip)
	else:
		# Compact fictional industrial module. No oversized luminous front panel.
		var identification := _material(Color("b87a46") if index == 1 else Color("7a798c"), 0.15)
		var olive := _material(Color("545c54"), 0.22)
		olive.roughness = 0.80
		_tool_bevel_box(Vector3(0.18, 0.22, 0.085), Vector3(0, -0.025, 0), 0.012, grip)
		_tool_bevel_box(Vector3(0.158, 0.187, 0.090), Vector3(0, -0.025, 0), 0.009, olive)
		_tool_box(Vector3(0.13, 0.038, 0.004), Vector3(0, 0.017, 0.047), steel)
		_tool_box(Vector3(0.113, 0.009, 0.004), Vector3(-0.003, 0.018, 0.050), identification)
		for x in [-0.063, 0.063]:
			for y in [-0.095, 0.044]:
				var screw := _tool_cylinder(0.0052, 0.0035, Vector3(x, y, 0.049), polished)
				screw.rotation.x = PI * 0.5
				_tool_box(Vector3(0.0055, 0.0013, 0.001), Vector3(x, y, 0.051), grip)
		var indicator := _tool_cylinder(0.0038, 0.003, Vector3(0.040, -0.025, 0.050), _material(Color("7e9b72"), 0.0))
		indicator.rotation.x = PI * 0.5
		_tool_bevel_box(Vector3(0.038, 0.020, 0.007), Vector3(-0.032, -0.027, 0.050), 0.003, grip)
		for i in range(4):
			_tool_box(Vector3(0.047, 0.003, 0.002), Vector3(-0.024, -0.060 - i * 0.008, 0.048), grip)
		_tool_bevel_box(Vector3(0.195, 0.014, 0.096), Vector3(0, 0.067, 0), 0.004, steel)
		_tool_hand(Vector3(0.014, -0.160, 0.030), glove, grip)

func _tool_box(size: Vector3, location: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = location
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tool_root.add_child(mesh)
	return mesh

func _tool_cylinder(radius: float, height: float, location: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return _tool_geometry(shape, location, material)

func _tool_hand(location: Vector3, glove: StandardMaterial3D, rubber: StandardMaterial3D) -> void:
	var palm := CapsuleMesh.new()
	palm.radius = 0.034
	palm.height = 0.113
	palm.radial_segments = 12
	palm.rings = 4
	var hand := _tool_geometry(palm, location + Vector3(0.017, -0.013, 0.018), glove)
	hand.rotation.z = 0.35
	for finger in range(4):
		var joint := _tool_cylinder(0.010, 0.058, location + Vector3(0, 0.024 - finger * 0.019, 0.042), glove)
		joint.rotation.z = PI * 0.5
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.037
	sleeve.height = 0.27
	sleeve.radial_segments = 12
	sleeve.rings = 4
	var fabric := _material(Color("303b40"), 0.0)
	fabric.roughness = 0.98
	var forearm := _tool_geometry(sleeve, location + Vector3(0.087, -0.165, 0.070), fabric)
	forearm.rotation.z = 0.48
	_tool_cylinder(0.036, 0.027, location + Vector3(0.036, -0.066, 0.033), rubber).rotation.z = 0.42

func _tool_geometry(shape: Mesh, location: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = material
	instance.position = location
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tool_root.add_child(instance)
	return instance

func _tool_bevel_box(size: Vector3, location: Vector3, bevel: float, material: StandardMaterial3D) -> MeshInstance3D:
	var half := size * 0.5
	var b := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.72)
	var outer := _tool_octagon(Vector2(half.y, half.z), b)
	var inner := _tool_octagon(Vector2(half.y - b, half.z - b), b * 0.32)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var j := (i + 1) % 8
		var left := Vector3(-half.x + b, outer[i].x, outer[i].y)
		var right := Vector3(half.x - b, outer[i].x, outer[i].y)
		var left_next := Vector3(-half.x + b, outer[j].x, outer[j].y)
		var right_next := Vector3(half.x - b, outer[j].x, outer[j].y)
		_tool_triangle(surface, left, left_next, right_next)
		_tool_triangle(surface, left, right_next, right)
		var end_left := Vector3(-half.x, inner[i].x, inner[i].y)
		var end_right := Vector3(half.x, inner[i].x, inner[i].y)
		var end_left_next := Vector3(-half.x, inner[j].x, inner[j].y)
		var end_right_next := Vector3(half.x, inner[j].x, inner[j].y)
		_tool_triangle(surface, end_left, end_left_next, left_next)
		_tool_triangle(surface, end_left, left_next, left)
		_tool_triangle(surface, right, right_next, end_right_next)
		_tool_triangle(surface, right, end_right_next, end_right)
		_tool_triangle(surface, Vector3(-half.x, 0, 0), end_left_next, end_left)
		_tool_triangle(surface, Vector3(half.x, 0, 0), end_right, end_right_next)
	return _tool_geometry(surface.commit(), location, material)

func _tool_octagon(half: Vector2, bevel: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-half.x + bevel, -half.y), Vector2(half.x - bevel, -half.y),
		Vector2(half.x, -half.y + bevel), Vector2(half.x, half.y - bevel), Vector2(half.x - bevel, half.y),
		Vector2(-half.x + bevel, half.y), Vector2(-half.x, half.y - bevel), Vector2(-half.x, -half.y + bevel)])

func _tool_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex in [a, c, b]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x, vertex.y))
		surface.add_vertex(vertex)

func _material(color: Color, metallic: float, glow: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.55
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 1.4
	return result
