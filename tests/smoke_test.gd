extends SceneTree

const Save = preload("res://scripts/save_state.gd")
const Piece = preload("res://scripts/destructible_piece.gd")
const SAVE_PATH := "user://abrissfirma_save.json"
const REPORT_PATH := "res://docs/test-results.json"

var game: Variant
var results: Array[Dictionary] = []
var _saved_bytes := PackedByteArray()
var _save_existed := false
var _backup_ready := false
var _restored := false
var _finished := false
var _started_at := 0


func _initialize() -> void:
	_started_at = Time.get_ticks_msec()
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	if _save_existed:
		var original := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if original == null:
			_check("Originalspielstand vor Test lesbar", false, "Test abgebrochen, ohne den Spielstand zu verändern.")
			_finish()
			return
		_saved_bytes = original.get_buffer(original.get_length())
		original.close()
	_backup_ready = true
	create_timer(90.0, true).timeout.connect(func():
		if not _finished:
			_check("Testlauf beendet sich innerhalb von 90 Sekunden", false, "Watchdog hat den Lauf beendet.")
			_finish()
	)
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if not _check("Hauptszene kann geladen werden", scene != null):
		_finish()
		return
	game = scene.instantiate()
	game.muted = true
	root.add_child(game)
	await process_frame
	_check("Spiel startet mit Briefing und pausierter Welt", paused and game.ui.is_panel_open() and game.briefing)
	_check("Begehbares Haus, Spielfigur und HUD vorhanden", game.pieces.size() > 300 and is_instance_valid(game.player.camera) and is_instance_valid(game.ui.progress_bar), "%d Bauteile" % game.pieces.size())
	# Every test uses an independent account. The original bytes remain in memory.
	game.state = {"money": 0, "owned": {}, "completed": 0}
	game.reset_contract()
	game.next_contract()
	_check("Auftrag annehmen setzt Spiel fort", not paused and not game.ui.is_panel_open() and not game.briefing)
	await _frames(40)
	_check_hud_geometry()
	_check("Spieler kollidiert mit dem Baustellenboden", game.player.is_on_floor() and game.player.position.y > -0.05 and game.player.position.y < 0.2, "Y=%.3f" % game.player.position.y)

	var unsupported: int = game.check_support()
	_check("Neues Haus vollständig abgestützt", unsupported == 0 and game.removed_count == 0, "%d anfänglich ungestützte Teile" % unsupported)
	if unsupported > 0:
		game.reset_contract()
	await _check_movement()
	await _check_menu_and_tools()
	await _check_hammer_and_materials()
	await _check_charges()
	await _check_restart()
	await _check_collapse_and_payment()
	await _check_shop_and_save()
	_check_next_contract()
	_check_save_validation()
	_finish()


func _check_movement() -> void:
	game.player.position = Vector3(0, 0.12, 8)
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.head.rotation = Vector3.ZERO
	await _frames(3)
	_key(KEY_W, true)
	var synthetic_input := Input.is_physical_key_pressed(KEY_W)
	_check("Synthetisches WASD erreicht die Eingabeabfrage", synthetic_input)
	await _frames(40)
	_key(KEY_W, false)
	_check("Spieler läuft durch die vordere Haustür", game.player.position.z < 4.8 and game.player.position.z > -1.0, "Z=%.3f" % game.player.position.z)
	# Enter slightly to the left of the interior partition, within the wide front door.
	game.player.position = Vector3(-0.65, 0.12, 6.8)
	game.player.velocity = Vector3.ZERO
	await _frames(3)
	_key(KEY_W, true)
	await _frames(50)
	_key(KEY_W, false)
	_check("Hausinneres vom Eingang aus erreichbar", game.player.position.z < 3.0 and game.player.position.y > -0.05, "Position %s" % game.player.position)
	game.player.position = Vector3(4.45, 0.12, 4.3)
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	await _frames(3)
	_key(KEY_W, true)
	await _frames(95)
	_key(KEY_W, false)
	_check("Treppe führt ohne Springen ins Obergeschoss", game.player.position.y > 3.2 and game.player.position.z < -1.7, "Position %s" % game.player.position)
	game.reset_contract()
	await _frames(2)


func _check_menu_and_tools() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check("Escape pausiert nach vollständiger Eingabeverarbeitung", paused and game.ui.is_panel_open())
	_check("Pausierte Spielfigur wird nicht weiter verarbeitet", paused and not game.player.can_process() and game.ui.can_process())
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await process_frame
	_check("Zweites Escape setzt das Spiel fort", not paused and not game.ui.is_panel_open())
	if paused:
		game.resume_game()
	game.toggle_pause()
	_check("Pause öffnet Menü und hält Welt an", paused and game.ui.is_panel_open())
	game.ui.sensitivity_changed.emit(0.0031)
	_check("Mauseinstellung mit Spielfigur verbunden", is_equal_approx(game.player.sensitivity, 0.0031))
	game.ui.quality_changed.emit(false)
	_check("Grafikeinstellung schaltet Schatten ab", not game.sun.shadow_enabled and not game.quality)
	game.ui.quality_changed.emit(true)
	game.ui.continue_requested.emit()
	_check("Menüfortsetzung hebt Pause auf", not paused and not game.ui.is_panel_open())
	game.ui.tool_selected.emit(2)
	_check("Werkzeugauswahl mit Spielfigur verbunden", game.selected_tool == 2 and game.player.selected_tool == 2)
	game.open_shop()
	_check("Werkstatt öffnet während einer Spielrunde", paused and game.ui.is_panel_open())
	game.resume_game()
	await process_frame


func _check_hud_geometry() -> void:
	var viewport: Rect2 = game.ui.get_viewport().get_visible_rect()
	var crosshair_rect: Rect2 = game.ui.crosshair.get_global_rect()
	_check("Fadenkreuz liegt sichtbar in der Viewportmitte", game.ui.crosshair.is_visible_in_tree() and crosshair_rect.get_center().distance_to(viewport.get_center()) < 2.0, "Fadenkreuz %s, Viewport %s" % [crosshair_rect, viewport])
	var toolbar: Control = game.ui.tool_buttons[0].get_parent().get_parent()
	var toolbar_rect := toolbar.get_global_rect()
	_check("Werkzeugleiste vollständig am unteren Bildschirmrand", toolbar.is_visible_in_tree() and viewport.encloses(toolbar_rect) and toolbar_rect.position.y > viewport.size.y * 0.65, "%s" % toolbar_rect)
	var job_card: Control = game.ui.contract_label.get_parent().get_parent()
	var job_rect := job_card.get_global_rect()
	_check("Auftragskarte vollständig rechts oben sichtbar", viewport.encloses(job_rect) and job_rect.position.x > viewport.size.x * 0.5 and job_rect.position.y >= 0.0, "%s" % job_rect)
	var caption: Label = game.ui.cash_label.get_parent().get_child(0)
	_check("Firmenkontobeschriftung bleibt horizontal lesbar", caption.text == "FIRMENKONTO" and caption.size.x >= 100.0 and caption.size.y < 45.0, "Beschriftungsgröße %s" % caption.size)


func _check_hammer_and_materials() -> void:
	var expected := {"glass": 15.0, "wood": 42.0, "brick": 65.0, "concrete": 95.0}
	var health_correct := true
	var survives := {"glass": false, "wood": true, "brick": true, "concrete": true}
	for kind: String in expected:
		var sample := Piece.new()
		sample.setup(-1, Vector3(80, 1, 80), Vector3.ONE, kind, game.materials["wood"])
		root.add_child(sample)
		health_correct = health_correct and is_equal_approx(sample.max_health, expected[kind])
		health_correct = health_correct and (not sample.hit(38.0, sample.global_position + Vector3(0.0, 0.0, 0.5), Vector3.BACK)) == survives[kind]
		if survives[kind]:
			health_correct = health_correct and (not sample.damage_marks.is_empty() or not sample.eroded_chunks.is_empty())
		sample.queue_free()
	_check("Materialien besitzen unterschiedliche Härte und sichtbaren Schaden", health_correct)
	game.player.set_physics_process(false)
	game.player.position = Vector3(-5.4, 0.1, 7.0)
	game.player.rotation = Vector3.ZERO
	game.player.head.rotation = Vector3.ZERO
	game.select_tool(0)
	await _frames(3)
	var hit: Dictionary = game.player.aim(3.6)
	if _check("Hammer zielt per Physikstrahl auf die Hauswand", not hit.is_empty() and hit.get("collider") is AbrissPiece):
		var target: AbrissPiece = hit["collider"]
		var previous_health := target.health
		game.use_tool()
		_check("Erster Hammerschlag beschädigt die Wand", target.health < previous_health and not target.removed)
		for strike in range(3):
			if not target.removed:
				game.use_tool()
		_check("Mehrere Hammerschläge erzeugen örtliche Ausbrüche und Trümmer", target.removed and game.removed_count > 0 and game.debris.size() > 0)
	game.player.set_physics_process(true)
	game.reset_contract()
	await _frames(3)


func _check_charges() -> void:
	var first: Variant = _nearest_piece(Vector3(-5.4, 0.65, 4.8))
	var second: Variant = _nearest_piece(Vector3(5.4, 0.65, -4.8))
	game.place_charge(first, first.global_position, Vector3.FORWARD, 1)
	game.place_charge(second, second.global_position, Vector3.BACK, 2)
	_check("Beide Gerätetypen lassen sich platzieren", game.charges.size() == 2 and game.supply[1] == 11 and game.supply[2] == 5)
	game.place_charge(first, first.global_position, Vector3.FORWARD, 1)
	_check("Doppelte Platzierung verbraucht keinen Vorrat", game.charges.size() == 2 and game.supply[1] == 11)
	game.detonate_charges()
	_check("Fernzündung verbraucht platzierte Geräte und zerstört Bauteile", game.charges.is_empty() and game.removed_count > 0)
	await _frames(12)
	game.reset_contract()
	var center := Vector3(-4, 1.3, 4)
	game.blast(center, 1)
	var impulse_removed: int = game.removed_count
	game.reset_contract()
	game.blast(center, 2)
	var vortex_removed: int = game.removed_count
	_check("Beide Explosionstypen haben wirksame, unterschiedliche Profile", impulse_removed > 0 and vortex_removed > 0 and impulse_removed != vortex_removed, "Impuls=%d, Wirbel=%d Bauteile" % [impulse_removed, vortex_removed])
	game.reset_contract()
	await _frames(3)


func _check_restart() -> void:
	game.blast(Vector3(-5, 1, 4), 1)
	game.request_support_check()
	var previous_generation: int = game.job_generation
	game.supply[1] = 3
	game.restart_contract()
	_check("Neustart setzt Schaden und Vorrat zurück", game.removed_count == 0 and game.supply[1] == 12 and game.supply[2] == 6 and game.job_generation > previous_generation)
	await _frames(15)
	_check("Alte Einsturzprüfung verändert neuen Auftrag nicht", game.removed_count == 0 and not game.paid and game.state.money == 0)


func _check_collapse_and_payment() -> void:
	var roof: Array[AbrissPiece] = []
	var anchors: Array[AbrissPiece] = []
	for part: AbrissPiece in game.pieces:
		if part.position.y > 7.0:
			roof.append(part)
		if part.anchored:
			anchors.append(part)
	for anchor in anchors:
		game.remove_piece(anchor, anchor.global_position, 0.0)
	var fallen: int = game.check_support()
	var collapse_start := Time.get_ticks_msec()
	while not game.paid and Time.get_ticks_msec() - collapse_start < 25000:
		await create_timer(0.2, true).timeout
	var roof_fallen := false
	for part in roof:
		roof_fallen = roof_fallen or part.removed
	_check("Fehlende Stützen lösen einen fortschreitenden Einsturz bis zum Abrissziel aus", roof_fallen and fallen > 50 and game.progress() >= game.TARGET, "%d vorgemerkte Teile; %.1f %% abgerissen" % [fallen, game.progress() * 100.0])
	await _frames(3)
	var live_debris := 0
	for body in game.debris:
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			live_debris += 1
	_check("Trümmerzahl bleibt begrenzt", game.debris.size() <= game.MAX_DEBRIS and live_debris <= game.MAX_DEBRIS, "%d aktive Trümmer" % live_debris)
	var expected_reward: int = game.reward + (game.supply[1] + game.supply[2]) * 10
	# Exercise the delayed completion path, rather than granting the reward directly.
	await create_timer(2.85, true).timeout
	_check("72-%-Ziel löst Auszahlung und Auswertung aus", game.paid and game.state.money == expected_reward and game.state.completed == 1 and paused and game.ui.is_panel_open(), "Erwartete Auszahlung: %d €" % expected_reward)
	var paid_money: int = game.state.money
	game.complete_contract()
	_check("Abgeschlossener Auftrag wird nur einmal bezahlt", game.state.money == paid_money and game.state.completed == 1)
	game.restart_contract()
	_check("Neustart eines bezahlten Auftrags verhindert doppelte Auszahlung", game.paid and game.state.money == paid_money and game.state.completed == 1)
	var loaded := Save.read_state()
	_check("Auszahlung wird auf Datenträger gespeichert", loaded.money == paid_money and loaded.completed == 1)


func _check_shop_and_save() -> void:
	var before: int = game.state.money
	game.purchase("hammer_upgrade")
	_check("Shop kauft Hammerverbesserung zum richtigen Preis", game.state.owned.get("hammer_upgrade", false) and game.state.money == before - 450)
	var after: int = game.state.money
	game.purchase("hammer_upgrade")
	game.purchase("unknown_upgrade")
	_check("Doppelte und unbekannte Käufe werden abgelehnt", game.state.money == after and game.state.owned.size() == 1)
	game.purchase("boots_upgrade")
	_check("Arbeitsstiefel erhöhen Bewegungstempo", game.state.owned.get("boots_upgrade", false) and is_equal_approx(game.player.speed, 8.0))
	var balance_before: int = game.state.money
	game.purchase("blast_upgrade")
	_check("Kauf ohne ausreichendes Geld wird abgelehnt", game.state.money == balance_before and not game.state.owned.get("blast_upgrade", false))
	# Seed a known balance to cover the remaining purchase independently of reward tuning.
	game.state.money = 1000
	game.purchase("blast_upgrade")
	_check("Impulsverbesserung ist kaufbar", game.state.money == 300 and game.state.owned.get("blast_upgrade", false))
	var reloaded := Save.read_state()
	_check("Geld und alle drei Verbesserungen werden neu geladen", reloaded.money == 300 and reloaded.owned.size() == 3 and reloaded.completed == 1)
	game.state = reloaded
	game.apply_upgrades()
	_check("Geladene Verbesserungen wirken auf die Spielfigur", is_equal_approx(game.player.speed, 8.0))
	await process_frame


func _check_next_contract() -> void:
	var previous_title: String = game.job_title
	game.next_contract()
	_check("Nächster Auftrag startet mit neuem Titel und frischem Haus", not paused and not game.paid and game.removed_count == 0 and game.supply[1] == 12 and game.supply[2] == 6 and game.job_title != previous_title)
	_check("Firmenfortschritt überlebt den Auftragswechsel", game.state.money == 300 and game.state.completed == 1 and game.state.owned.size() == 3)


func _check_save_validation() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not _check("Testspielstand kann geschrieben werden", file != null):
		return
	file.store_string("{invalid json")
	file.close()
	var corrupted := Save.read_state()
	_check("Beschädigter Spielstand wird sicher zurückgesetzt", corrupted.money == 0 and corrupted.completed == 0 and corrupted.owned.is_empty())
	file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_check("Validierungstest kann geschrieben werden", false)
		return
	file.store_string('{"money":-100,"completed":"wrong","owned":{"hammer_upgrade":true,"blast_upgrade":"true","unknown":true}}')
	file.close()
	var sanitized := Save.read_state()
	_check("Ungültige Geld-, Zähler- und Upgrade-Werte werden gefiltert", sanitized.money == 0 and sanitized.completed == 0 and sanitized.owned.size() == 1 and sanitized.owned.get("hammer_upgrade", false))


func _nearest_piece(location: Vector3) -> Variant:
	var nearest: Variant = game.pieces[0]
	var shortest := INF
	for part in game.pieces:
		var distance: float = part.global_position.distance_squared_to(location)
		if not part.removed and distance < shortest:
			shortest = distance
			nearest = part
	return nearest


func _key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
		await process_frame


func _check(name: String, passed: bool, detail := "") -> bool:
	results.append({"name": name, "passed": passed, "detail": detail})
	print(("PASS" if passed else "FAIL") + " | " + name + (" | " + detail if not detail.is_empty() else ""))
	return passed


func _restore_save() -> bool:
	if _restored or not _backup_ready:
		return _restored
	if _save_existed:
		var original := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if original == null:
			return false
		original.store_buffer(_saved_bytes)
		original.flush()
		var successful := original.get_error() == OK
		original.close()
		_restored = successful and FileAccess.get_file_as_bytes(SAVE_PATH) == _saved_bytes
	else:
		var exact_test_save := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			_restored = DirAccess.remove_absolute(exact_test_save) == OK
		else:
			_restored = true
	return _restored


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_key(KEY_W, false)
	_check("Originalspielstand bytegenau wiederhergestellt", _restore_save(), "Vorher vorhanden: %s" % _save_existed)
	var failures := 0
	for result in results:
		if not result.passed:
			failures += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs"))
	var report := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report != null:
		report.store_string(JSON.stringify({"godot_version": Engine.get_version_info().string, "timestamp_utc": Time.get_datetime_string_from_system(true), "duration_ms": Time.get_ticks_msec() - _started_at, "checks": results.size(), "passed": results.size() - failures, "failed": failures, "original_save_restored": _restored, "results": results}, "\t"))
		report.close()
	else:
		failures += 1
		print("FAIL | Testbericht konnte nicht geschrieben werden")
	print("ABRISSFIRMA TEST SUMMARY | %d checks | %d failed" % [results.size(), failures])
	paused = false
	if is_instance_valid(game):
		game.queue_free()
	quit(0 if failures == 0 else 1)


func _finalize() -> void:
	# Also restore on engine shutdown, even if a script error interrupted the coroutine.
	_restore_save()
