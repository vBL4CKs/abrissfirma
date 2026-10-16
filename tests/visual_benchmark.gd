extends SceneTree

## Execute with the regular rendering backend, never --headless, for real GPU
## measurements. The test save is only read, never awarded or purchased from.
const SAVE_PATH := "user://abrissfirma_save.json"
const REPORT_PATH := "res://docs/visual-benchmark.json"
const CAPTURE_DIR := "res://docs/realismus"
const SAMPLE_SECONDS := 4.0

var game: Variant
var camera: Camera3D
var original_bytes := PackedByteArray()
var original_existed := false
var backup_ready := false
var finished := false
var report: Dictionary = {}


func _initialize() -> void:
	original_existed = FileAccess.file_exists(SAVE_PATH)
	if original_existed:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file == null:
			push_error("Benchmark abgebrochen: Originalspielstand nicht lesbar.")
			quit(1)
			return
		original_bytes = file.get_buffer(file.get_length())
		file.close()
	backup_ready = true
	create_timer(120.0, true).timeout.connect(func():
		if not finished:
			push_error("Benchmark-Watchdog hat den Lauf beendet.")
			_finish(1)
	)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU-Benchmark benötigt sichtbares Rendering. Headless-FPS werden nicht als Grafikleistung ausgegeben.")
		_finish(2)
		return
	root.size = Vector2i(1280, 800)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		_finish(1)
		return
	game = scene.instantiate()
	game.muted = true
	root.add_child(game)
	await process_frame
	game.state = {"money": 0, "owned": {}, "completed": 0}
	game.reset_contract()
	game.resume_game()
	game.paid = true
	game.player.set_physics_process(false)
	game.player.tool_root.visible = false
	game.player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game.has_method("set_quality_level"):
		game.set_quality_level(1)
	# Without a level API, retain the production default instead of quietly
	# turning the benchmark into a different quality preset.
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.06
	camera.far = 160.0
	game.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	report = {
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info().string,
		"display_server": DisplayServer.get_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"resolution": [1280, 800],
		"quality": "Mittel (Stufe 1)" if game.has_method("set_quality_level") else "Produktionsstandard (Schatten an, 72 aktive Trümmer)",
		"vsync": "aus", "fps_limit": "unbegrenzt", "sample_seconds": SAMPLE_SECONDS,
		"method": "Monotone Time.get_ticks_usec() zwischen tatsächlich gerenderten Frames; Aufwärmphase vor Messung. 1-%-Low = 1000 / Mittelwert der langsamsten 1 % der Framezeiten."
	}
	_view(Vector3(14.0, 6.5, 17.5), Vector3(0, 2.8, 0))
	await _warmup(1.0)
	await _capture("01_fassade_unbeschaedigt")
	report["before"] = await _measure(SAMPLE_SECONDS)
	var target: Variant = _nearest_brick(Vector3(-5.4, 1.8, 4.8))
	if target != null:
		var point: Vector3 = target.global_position + Vector3(0.05, 0.06, target.size.z * 0.5)
		_view(point + Vector3(1.5, 0.5, 4.0), point)
		await _warmup(0.25)
		await _capture("01b_fassadendetail_unbeschaedigt")
		_hit(target, target.max_health * 0.28, point)
		_hit(target, target.max_health * 0.28, point + Vector3(-0.12, 0.1, 0))
	await _warmup(0.4)
	await _capture("02_fassade_lokaler_schaden")
	_view(Vector3(-4.7, 1.72, 2.7), Vector3(-1.3, 1.6, -3.1))
	await _warmup(0.4)
	await _capture("03_innenraum")
	_view(Vector3(14.0, 6.5, 17.5), Vector3(0, 2.8, 0))
	await _warmup(0.4)
	# Remove supports at once to make the following interval comparable. The
	# subsequent failure is the game's progressive collapse implementation.
	var anchors: Array = []
	for part in game.pieces:
		if part.anchored:
			anchors.append(part)
	for part in anchors:
		game.remove_piece(part, part.global_position, 0.0)
	game.check_support()
	report["collapse"] = await _measure(SAMPLE_SECONDS, true)
	var collapse_start := Time.get_ticks_msec()
	while not game.collapse_queue.is_empty() and Time.get_ticks_msec() - collapse_start < 25000:
		await _warmup(0.25)
	await _warmup(1.5)
	await _capture("05_schutthaufen")
	report["removed_pieces"] = game.removed_count
	report["total_pieces"] = game.pieces.size()
	report["active_rigidbodies"] = _rigid_count()
	report["remaining_queue"] = game.collapse_queue.size()
	report["pending_fragments"] = game.fragment_queue.size()
	report["settled_count"] = game.rubble.settled_count
	report["original_save_unchanged"] = _save_unchanged()
	_finish(0 if report.original_save_unchanged else 1)


func _view(position: Vector3, target: Vector3) -> void:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)


func _warmup(seconds: float) -> void:
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await RenderingServer.frame_post_draw
		await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(CAPTURE_DIR + "/" + name + ".png")
	if result != OK:
		push_error("Aufnahme konnte nicht gespeichert werden: " + name)
	print("CAPTURE | " + name)


func _measure(seconds: float, capture_collapse := false) -> Dictionary:
	var frame_times: Array[float] = []
	await RenderingServer.frame_post_draw
	var start := Time.get_ticks_usec()
	var previous := start
	var captured := false
	var peak_bodies := 0
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - previous) / 1000.0)
		previous = now
		peak_bodies = maxi(peak_bodies, _rigid_count())
		if capture_collapse and not captured and now - start > 1100000:
			root.get_texture().get_image().save_png(CAPTURE_DIR + "/04_einsturz.png")
			captured = true
			# Screenshot readback is intentionally excluded from measured samples.
			await process_frame
			await RenderingServer.frame_post_draw
			previous = Time.get_ticks_usec()
	var total := 0.0
	for duration in frame_times:
		total += duration
	frame_times.sort()
	var slow_count := maxi(1, ceili(frame_times.size() * 0.01))
	var slow_total := 0.0
	for index in range(frame_times.size() - slow_count, frame_times.size()):
		slow_total += frame_times[index]
	var result := {
		"frames": frame_times.size(), "sampled_seconds": total / 1000.0,
		"average_fps": snappedf(frame_times.size() * 1000.0 / maxf(total, 0.001), 0.1),
		"one_percent_low_fps": snappedf(1000.0 / maxf(slow_total / slow_count, 0.001), 0.1),
		"mean_frame_ms": snappedf(total / maxf(frame_times.size(), 1.0), 0.01),
		"p99_frame_ms": snappedf(frame_times[mini(frame_times.size() - 1, floori(frame_times.size() * 0.99))], 0.01),
		"max_frame_ms": snappedf(frame_times.back(), 0.01),
		"peak_live_rigidbodies": peak_bodies,
		"visible_draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"visible_primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	}
	print("BENCHMARK | " + JSON.stringify(result))
	return result


func _rigid_count() -> int:
	var count := 0
	for child in game.debris:
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			count += 1
	return count


func _nearest_brick(point: Vector3) -> Variant:
	var nearest: Variant = null
	var distance := INF
	for part in game.pieces:
		if part.kind != "brick" or part.removed:
			continue
		var current: float = part.global_position.distance_squared_to(point)
		if current < distance:
			distance = current
			nearest = part
	return nearest


func _hit(part: Object, amount: float, point: Vector3) -> void:
	for method in part.get_method_list():
		if method.name == "hit":
			var args: Array = [amount, point, Vector3.BACK]
			part.callv("hit", args.slice(0, mini(method.args.size(), 3)))
			# Mirror the live tool path: eroded chunks become falling debris,
			# rather than merely being hidden by the piece's local damage mesh.
			if part.has_method("take_eroded"):
				for fragment in part.call("take_eroded"):
					game.queue_fragment(fragment, part, point, 0.25)
			return


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


func _finish(code: int) -> void:
	if finished:
		return
	finished = true
	_restore_if_needed()
	if not report.is_empty():
		var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	paused = false
	quit(code)


func _finalize() -> void:
	_restore_if_needed()
