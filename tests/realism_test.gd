extends SceneTree

## Regression checks for the realistic facade/fracture pass.
## This test never purchases or completes a contract. The original save is
## snapshotted and byte-compared, and restored on an unexpected write.
const SAVE_PATH := "user://abrissfirma_save.json"
const REPORT_PATH := "res://docs/realism-test-results.json"

var game: Variant
var results: Array[Dictionary] = []
var original_bytes := PackedByteArray()
var original_existed := false
var backup_ready := false
var finished := false
var started_at := 0


func _initialize() -> void:
	started_at = Time.get_ticks_msec()
	original_existed = FileAccess.file_exists(SAVE_PATH)
	if original_existed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			_check("Originalspielstand vor Test lesbar", false)
			_finish()
			return
		original_bytes = file.get_buffer(file.get_length())
		file.close()
	backup_ready = true
	create_timer(75.0, true).timeout.connect(func():
		if not finished:
			_check("Realismusprüfung beendet sich innerhalb von 75 Sekunden", false)
			_finish()
	)
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not _check("Hauptszene für Realismusprüfung lädt", scene != null):
		_finish()
		return
	game = scene.instantiate()
	game.muted = true
	root.add_child(game)
	await process_frame
	game.state = {"money": 0, "owned": {}, "completed": 0}
	_reset()
	await _frames(4)
	_check("Haus enthält Materialien Ziegel, Beton, Holz und Glas", _all_material_kinds())
	_check_facade_seams()
	_check_material_maps()
	_check_local_damage()
	await _check_fragments()
	await _check_progressive_collapse()
	_check("Realismusprüfung verändert kein Firmenkonto", game.state.money == 0 and game.state.completed == 0 and game.state.owned.is_empty())
	_finish()


func _reset() -> void:
	game.reset_contract()
	game.resume_game()
	# No completion or other path in this test is allowed to write user money.
	game.paid = true
	game.player.set_physics_process(false)


func _all_material_kinds() -> bool:
	var kinds: Dictionary = {}
	for part in game.pieces:
		kinds[part.kind] = true
	return kinds.has_all(["brick", "concrete", "wood", "glass"])


func _check_facade_seams() -> void:
	var tested := 0
	var gaps := 0
	var worst := 0.0
	for first in game.pieces:
		if first.kind != "brick" or first.size.x < 0.4 or absf(first.position.z) < 4.5:
			continue
		for second in game.pieces:
			if second.piece_id <= first.piece_id or second.kind != "brick":
				continue
			if absf(second.position.z - first.position.z) > 0.005 or absf(second.position.y - first.position.y) > 0.005:
				continue
			var separation: float = absf(second.position.x - first.position.x)
			if separation < 0.1 or separation > 1.5:
				continue
			var gap: float = separation - (first.size.x + second.size.x) * 0.5
			tested += 1
			worst = maxf(worst, gap)
			if gap > 0.003:
				gaps += 1
	_check("Unbeschädigte Fassade hat keine offenen Rasterfugen", tested > 0 and gaps == 0, "%d Anschlüsse, %d offene Fugen, größte %.4f m" % [tested, gaps, worst])


func _check_material_maps() -> void:
	var mapped := 0
	var normal_mapped := 0
	for key: String in ["brick", "concrete", "wood"]:
		if not game.materials.has(key):
			continue
		var material: StandardMaterial3D = game.materials[key]
		if material.albedo_texture != null and material.roughness_texture != null:
			mapped += 1
		if material.normal_enabled and material.normal_texture != null:
			normal_mapped += 1
	_check("Ziegel, Beton und Holz besitzen Albedo- und Rauheitstexturen", mapped == 3, "%d von 3" % mapped)
	_check("Ziegel, Beton und Holz besitzen Normalmaps", normal_mapped == 3, "%d von 3" % normal_mapped)


func _check_local_damage() -> void:
	var target: Variant = _nearest(Vector3(-5.4, 1.8, 4.8), "brick")
	if not _check("Lokaler Schadentest findet eine Ziegelwand", target != null):
		return
	var previous_health: float = target.health
	var point: Vector3 = target.global_position + Vector3(0.13, 0.08, target.size.z * 0.5)
	_hit(target, target.max_health * 0.28, point)
	var count_before := _mark_count(target)
	_hit(target, target.max_health * 0.28, point + Vector3(-0.12, 0.11, 0.0))
	_check("Mehrere lokale Treffer beschädigen eine Wand vor dem Ausbruch", not target.removed and target.health < previous_health and target.health > 0.0)
	_check("Treffer erzeugen örtliche Risse oder Abplatzungen", count_before > 0 and _mark_count(target) >= count_before, "%d Schadenselemente" % _mark_count(target))


func _check_fragments() -> void:
	_reset()
	await _frames(2)
	var found_kinds: Array[String] = []
	var closed := 0
	var irregular := 0
	var convex := 0
	var fragments := 0
	var max_initial_speed := 0.0
	for kind: String in ["brick", "concrete", "wood", "glass"]:
		var target: Variant = _nearest(Vector3(-4.0, 2.0, 4.8), kind)
		if target == null:
			continue
		var before: int = game.debris.size()
		game.remove_piece(target, target.global_position - Vector3.FORWARD, 1.8)
		var current: Array = game.debris.slice(before)
		if not current.is_empty():
			found_kinds.append(kind)
		for body: RigidBody3D in current:
			if not is_instance_valid(body):
				continue
			fragments += 1
			max_initial_speed = maxf(max_initial_speed, body.linear_velocity.length())
			for child in body.get_children():
				if child is MeshInstance3D:
					var shape_info := _mesh_info(child.mesh)
					closed += int(shape_info.closed)
					irregular += int(shape_info.irregular)
				if child is CollisionShape3D and child.shape is ConvexPolygonShape3D:
					convex += 1
	_check("Alle vier Materialien erzeugen Trümmer", found_kinds.size() == 4, ", ".join(found_kinds))
	_check("Bruchstücke sind geschlossene Meshes mit Innenflächen", fragments > 0 and closed >= fragments, "%d geschlossene Meshes / %d Körper" % [closed, fragments])
	_check("Bruchstücke verwenden unregelmäßige Geometrie statt BoxMesh", fragments > 0 and irregular >= fragments, "%d unregelmäßige Meshes / %d Körper" % [irregular, fragments])
	_check("Bruchstücke besitzen passende konvexe Kollisionen", fragments > 0 and convex >= fragments, "%d konvexe Formen / %d Körper" % [convex, fragments])
	_check("Abrissimpulse schleudern Trümmer nicht mit 9 m/s fort", max_initial_speed <= 2.4, "Direkt nach Erzeugung höchstens %.3f m/s" % max_initial_speed)
	_reset()
	await _frames(2)
	game.blast(Vector3(-4.8, 1.8, 4.2), 1)
	await _frames(1)
	var horizontal_speed := 0.0
	var blast_fragments := 0
	for body in game.debris:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			blast_fragments += 1
			var velocity: Vector3 = body.linear_velocity
			horizontal_speed = maxf(horizontal_speed, Vector2(velocity.x, velocity.z).length())
	_check("Echtes Impulsgerät erzeugt zurückhaltende seitliche Trümmerbewegung", blast_fragments > 0 and horizontal_speed < 3.2, "%d Trümmer, maximal %.3f m/s seitlich nach einem Physikschritt" % [blast_fragments, horizontal_speed])


func _check_progressive_collapse() -> void:
	_reset()
	await _frames(3)
	var initially_unsupported: int = game.check_support()
	_check("Intaktes Haus ist vollständig abgestützt", initially_unsupported == 0 and game.removed_count == 0)
	var anchors: Array = []
	var initial_heights: Dictionary = {}
	for part in game.pieces:
		initial_heights[part.piece_id] = part.position.y
		if part.anchored:
			anchors.append(part)
	for part in anchors:
		game.remove_piece(part, part.global_position, 0.0)
	var removed_before: int = game.removed_count
	var unsupported: int = game.check_support()
	var removed_immediately: int = game.removed_count - removed_before
	var queued := _queue_size()
	_check("Stützverlust wird als zeitlicher Einsturz vorgemerkt", unsupported > 0 and queued > 0 and removed_immediately < unsupported, "%d ungestützt, %d vorgemerkt, %d unmittelbar entfernt" % [unsupported, queued, removed_immediately])
	await create_timer(1.6, true).timeout
	_check("Vorgemerkter Einsturz schreitet über mehrere Frames fort", game.removed_count > removed_before, "%d → %d Bauteile" % [removed_before, game.removed_count])
	var waiting_fall := 0
	for part in game.pieces:
		if not part.removed and part.pending_collapse and part.position.y < float(initial_heights[part.piece_id]) - 0.05:
			waiting_fall += 1
	_check("Ungestützte Teile fallen auch bei vollem detailliertem Trümmerpool", waiting_fall > 0 or _queue_size() == 0, "%d wartende Bauteile bereits abgesackt, %d noch vorgemerkt" % [waiting_fall, _queue_size()])
	var started := Time.get_ticks_msec()
	while _queue_size() > 0 and Time.get_ticks_msec() - started < 25000:
		await create_timer(0.25, true).timeout
	await create_timer(2.0, true).timeout
	_check("Vollständiger Stützverlust wird innerhalb von 25 Sekunden abgearbeitet", _queue_size() == 0, "%d Bauteile noch vorgemerkt" % _queue_size())
	var live := 0
	var frozen_in_air := 0
	for body in game.debris:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			live += 1
			if body.freeze and body.position.y > 1.0:
				frozen_in_air += 1
	var limit: int = game.MAX_DEBRIS
	if _has_property(game, "rubble") and game.rubble is Node and _has_property(game.rubble, "MAX_ACTIVE"):
		limit = int(game.rubble.MAX_ACTIVE)
	_check("Anzahl lebender Trümmerphysikkörper bleibt begrenzt", live <= limit, "%d / %d" % [live, limit])
	_check("Keine Trümmer werden per Zeitschalter in der Luft eingefroren", frozen_in_air == 0, "%d eingefrorene Körper über 1 m" % frozen_in_air)
	var settled_count := _rubble_count()
	_check("Ruhende Trümmer bleiben als Schutthaufen erhalten", settled_count > 0, "%d verbleibende Schuttelemente" % settled_count)
	_reset()
	await _frames(2)
	_check("Auftragsneustart entfernt Altlasten des Einsturzes", game.removed_count == 0 and _queue_size() == 0 and _rubble_count() == 0)


func _mesh_info(mesh: Mesh) -> Dictionary:
	var edge_count: Dictionary = {}
	var unique: Dictionary = {}
	if mesh == null or mesh is BoxMesh:
		return {"closed": false, "irregular": false}
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for index in vertices.size():
				indices.append(index)
		for vertex in vertices:
			unique[_vertex_key(vertex)] = vertex
		for index in range(0, indices.size() - 2, 3):
			for side in range(3):
				var a := _vertex_key(vertices[indices[index + side]])
				var b := _vertex_key(vertices[indices[index + (side + 1) % 3]])
				if a == b:
					continue
				var key := a + ":" + b if a < b else b + ":" + a
				edge_count[key] = int(edge_count.get(key, 0)) + 1
	var is_closed := not edge_count.is_empty()
	for count: int in edge_count.values():
		is_closed = is_closed and count == 2
	var box_corners := 0
	var bounds := mesh.get_aabb()
	for vertex: Vector3 in unique.values():
		var at_x := minf(absf(vertex.x - bounds.position.x), absf(vertex.x - bounds.end.x)) < 0.0005
		var at_y := minf(absf(vertex.y - bounds.position.y), absf(vertex.y - bounds.end.y)) < 0.0005
		var at_z := minf(absf(vertex.z - bounds.position.z), absf(vertex.z - bounds.end.z)) < 0.0005
		if at_x and at_y and at_z:
			box_corners += 1
	return {"closed": is_closed, "irregular": unique.size() >= 4 and box_corners < unique.size()}


func _vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [roundi(vertex.x * 10000.0), roundi(vertex.y * 10000.0), roundi(vertex.z * 10000.0)]


func _hit(part: Object, amount: float, point: Vector3) -> void:
	for method in part.get_method_list():
		if method.name == "hit":
			var args: Array = [amount, point, Vector3.BACK]
			part.callv("hit", args.slice(0, mini(method.args.size(), 3)))
			return


func _mark_count(part: Object) -> int:
	if not _has_property(part, "damage_marks"):
		return 0
	var marks: Variant = part.get("damage_marks")
	if marks is Array:
		return marks.size()
	if marks is Node:
		return marks.get_child_count()
	return 0


func _queue_size() -> int:
	for key: String in ["collapse_queue", "pending_collapse", "collapse_pending"]:
		if _has_property(game, key):
			var queue: Variant = game.get(key)
			if queue is Array or queue is Dictionary:
				return queue.size()
	return 0


func _rubble_count() -> int:
	for key: String in ["rubble", "settled_rubble", "rubble_pieces"]:
		if _has_property(game, key):
			var value: Variant = game.get(key)
			if value is Array:
				return value.size()
			if value is Node:
				if _has_property(value, "settled_count"):
					return int(value.get("settled_count"))
				return value.get_child_count()
	return 0


func _has_property(object: Object, key: String) -> bool:
	for property in object.get_property_list():
		if property.name == key:
			return true
	return false


func _nearest(point: Vector3, kind: String) -> Variant:
	var nearest: Variant = null
	var distance := INF
	for part in game.pieces:
		if part.removed or part.kind != kind:
			continue
		var current: float = part.global_position.distance_squared_to(point)
		if current < distance:
			distance = current
			nearest = part
	return nearest


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _check(label: String, passed: bool, detail := "") -> bool:
	results.append({"name": label, "passed": passed, "detail": detail})
	print(("PASS" if passed else "FAIL") + " | " + label + (" | " + detail if not detail.is_empty() else ""))
	return passed


func _save_unchanged() -> bool:
	if not backup_ready:
		return true
	return FileAccess.get_file_as_bytes(SAVE_PATH) == original_bytes if original_existed else not FileAccess.file_exists(SAVE_PATH)


func _restore_if_needed() -> void:
	if not backup_ready or _save_unchanged():
		return
	if original_existed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(original_bytes)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _finish() -> void:
	if finished:
		return
	finished = true
	_check("Realismusprüfung lässt Originalspielstand bytegenau unverändert", _save_unchanged())
	_restore_if_needed()
	var failed := 0
	for result in results:
		failed += int(not result.passed)
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"godot_version": Engine.get_version_info().string, "timestamp_utc": Time.get_datetime_string_from_system(true), "duration_ms": Time.get_ticks_msec() - started_at, "checks": results.size(), "failed": failed, "passed": results.size() - failed, "results": results}, "\t"))
		report.close()
	print("ABRISSFIRMA REALISM SUMMARY | %d checks | %d failed" % [results.size(), failed])
	paused = false
	quit(0 if failed == 0 else 1)


func _finalize() -> void:
	_restore_if_needed()
