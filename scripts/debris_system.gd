extends Node3D
class_name AbrissDebris

var MAX_ACTIVE: int = 72
const MAX_RUBBLE: int = 2400
var active: Array[RigidBody3D] = []
var settled_count: int = 0
var batches: Dictionary = {}
var _settled_collisions: int = 0
var _clock: float = 0.0
var _batch_check: float = 0.0
var last_emitted: RigidBody3D

func room() -> int:
	return maxi(0, MAX_ACTIVE - active.size())

func emit_fragment(fragment: Dictionary, transform_at: Transform3D, kind: String, velocity: Vector3) -> bool:
	if room() <= 0:
		return false
	var body := RigidBody3D.new()
	body.name = "Bruchstueck_" + kind
	body.transform = transform_at
	var volume: float = fragment["volume"]
	var density: float = {"brick": 1650.0, "concrete": 2300.0, "wood": 540.0, "glass": 2400.0}.get(kind, 1600.0)
	body.mass = clampf(volume * density, 0.15, 1800.0)
	body.collision_layer = 8
	body.collision_mask = 1 | 2 | 8
	body.linear_damp = 0.08
	body.angular_damp = 0.18
	body.continuous_cd = volume < 0.025
	body.contact_monitor = true
	body.max_contacts_reported = 8
	var surface := PhysicsMaterial.new()
	surface.friction = 0.82 if kind != "glass" else 0.45
	surface.bounce = 0.015
	body.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var hull := fragment["shape"].duplicate() as ConvexPolygonShape3D
	var inset := hull.points
	for index in range(inset.size()):
		inset[index] *= 0.985
	hull.points = inset
	hull.margin = 0.004
	shape.shape = hull
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.mesh = fragment["mesh"]
	body.add_child(visual)
	body.set_meta("born", _clock)
	body.set_meta("quiet", 0.0)
	body.set_meta("mesh", fragment["mesh"])
	body.set_meta("shape", hull)
	body.set_meta("volume", volume)
	body.set_meta("kind", kind)
	add_child(body)
	body.linear_velocity = velocity.limit_length(2.2)
	active.append(body)
	last_emitted = body
	return true

func _physics_process(delta: float) -> void:
	_clock += delta
	_batch_check += delta
	if _batch_check < 0.12:
		return
	var interval := _batch_check
	_batch_check = 0.0
	for index in range(active.size() - 1, -1, -1):
		var body := active[index]
		if not is_instance_valid(body):
			active.remove_at(index)
			continue
		if body.position.y < -10.0:
			active.remove_at(index)
			body.queue_free()
			continue
		var slow := body.linear_velocity.length_squared() < 0.09 and body.angular_velocity.length_squared() < 0.25
		var touching := body.get_contact_count() > 0
		var quiet: float = float(body.get_meta("quiet")) + interval if slow and touching else 0.0
		body.set_meta("quiet", quiet)
		var founded := _grounded(body, {}, 0)
		if founded and (body.sleeping or (quiet > 0.48 and _clock - float(body.get_meta("born")) > 0.8)):
			_settle(body)
			active.remove_at(index)

func _grounded(body: RigidBody3D, visited: Dictionary, depth: int) -> bool:
	if depth > 10 or visited.has(body.get_instance_id()):
		return false
	visited[body.get_instance_id()] = true
	for contact in body.get_colliding_bodies():
		if contact is StaticBody3D and ((contact.collision_layer & 1) != 0 or contact.has_meta("grounded_rubble")):
			return true
		if contact is RigidBody3D and contact.linear_velocity.length_squared() < 0.16:
			if _grounded(contact, visited, depth + 1):
				return true
	return false

func landing_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 18.0, at.z), Vector3(at.x, -0.5, at.z), 1 | 32)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.08

func _settle(body: RigidBody3D) -> void:
	var mesh: Mesh = body.get_meta("mesh")
	var key := str(mesh.get_rid().get_id())
	if not batches.has(key):
		var instance := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = 16
		multimesh.visible_instance_count = 0
		instance.multimesh = multimesh
		add_child(instance)
		batches[key] = {"node": instance, "poses": []}
	var batch: Dictionary = batches[key]
	var poses: Array = batch["poses"]
	poses.append(body.transform)
	var multi: MultiMesh = batch["node"].multimesh
	if poses.size() > multi.instance_count:
		multi.instance_count *= 2
		for i in range(poses.size() - 1):
			multi.set_instance_transform(i, poses[i])
	multi.set_instance_transform(poses.size() - 1, body.transform)
	multi.visible_instance_count = poses.size()
	settled_count += 1
	# Retain attached window frames, trims and furniture details at the resting pose.
	for detail in body.get_children():
		if detail is Node3D and detail.has_meta("architectural_detail"):
			detail.reparent(self, true)
	if float(body.get_meta("volume")) > 0.013 and _settled_collisions < 400:
		var obstacle := StaticBody3D.new()
		obstacle.transform = body.transform
		obstacle.collision_layer = 8 | 32
		obstacle.collision_mask = 0
		obstacle.set_meta("grounded_rubble", true)
		var collision := CollisionShape3D.new()
		collision.shape = body.get_meta("shape")
		obstacle.add_child(collision)
		add_child(obstacle)
		_settled_collisions += 1
	body.collision_layer = 0
	body.collision_mask = 0
	body.queue_free()

func clear_all() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	active.clear()
	batches.clear()
	settled_count = 0
	_settled_collisions = 0
	_clock = 0.0
