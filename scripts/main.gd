extends Node3D

const Piece = preload("res://scripts/destructible_piece.gd")
const Player = preload("res://scripts/player.gd")
const SiteArt = preload("res://scripts/site_art.gd")
const GameUI = preload("res://scripts/game_ui.gd")
const Save = preload("res://scripts/save_state.gd")
const TARGET := 0.72
const MAX_DEBRIS := 96
const MAX_RUBBLE := 2400
const Materials = preload("res://scripts/material_library.gd")
const House = preload("res://scripts/realistic_house.gd")
const DebrisSystem = preload("res://scripts/debris_system.gd")
const ImpactAudio = preload("res://scripts/impact_audio.gd")
const COSTS := {"hammer_upgrade": 450, "blast_upgrade": 700, "boots_upgrade": 350}

var state: Dictionary
var player: AbrissPlayer
var ui: AbrissUI
var sun: DirectionalLight3D
var building: Node3D
var effects: Node3D
var pieces: Array[AbrissPiece] = []
var debris: Array[RigidBody3D] = []
var charges: Array[Dictionary] = []
var supply: Array[int] = [0, 12, 6]
var materials: Dictionary = {}
var removed_count: int = 0
var paid: bool = false
var briefing: bool = true
var quality: bool = true
var quality_level: int = 1
var support_pending: bool = false
var completion_pending: bool = false
var job_generation: int = 0
var selected_tool: int = 0
var reward: int = 1200
var job_title: String = "01 · Haus Sonneneck"
var muted: bool = false
var sounds: Dictionary = {}
var stair_ids: Array[int] = []
var stair_ramp: StaticBody3D
var rubble: AbrissDebris
var collapse_queue: Array[Dictionary] = []
var fragment_queue: Array[Dictionary] = []
var _collapse_clock: float = 0.0
var _dust_texture: Texture2D

func _ready() -> void:
	state = Save.read_state()
	_make_materials()
	_make_world()
	effects = Node3D.new()
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects)
	rubble = DebrisSystem.new()
	rubble.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(rubble)
	debris = rubble.active
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.action_requested.connect(use_tool)
	player.detonate_requested.connect(detonate_charges)
	player.shop_requested.connect(open_shop)
	player.pause_requested.connect(toggle_pause)
	player.tool_requested.connect(select_tool)
	player.restart_requested.connect(restart_contract)
	ui = GameUI.new()
	add_child(ui)
	ui.tool_selected.connect(select_tool)
	ui.restart_requested.connect(restart_contract)
	ui.purchase_requested.connect(purchase)
	ui.continue_requested.connect(resume_game)
	ui.contract_requested.connect(next_contract)
	ui.sensitivity_changed.connect(func(value: float): player.sensitivity = value)
	ui.quality_changed.connect(set_quality)
	ui.quality_level_changed.connect(set_quality_level)
	ui.detonate_requested.connect(detonate_charges)
	_make_sounds()
	sounds.merge(ImpactAudio.build(), true)
	reset_contract()
	ui.show_briefing(job_title, reward)
	set_menu(true)
	if "--capture-preview" in OS.get_cmdline_user_args():
		call_deferred("_capture_preview")

func _make_world() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("397fb1")
	sky_material.sky_horizon_color = Color("bccfdb")
	sky_material.ground_horizon_color = Color("bec6b5")
	sky_material.ground_bottom_color = Color("748774")
	sky_material.sun_angle_max = 18.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5cddd")
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8cbd5")
	environment.fog_density = 0.0018
	environment_node.environment = environment
	add_child(environment_node)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -34, 0)
	sun.light_color = Color("fff2db")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	static_box(self, Vector3(0, -0.3, 0), Vector3(230, 0.6, 230), materials["grass"])
	static_box(self, Vector3(0, -0.08, 0), Vector3(45, 0.18, 43), materials["dirt"])
	static_box(self, Vector3(0, 0.01, 0), Vector3(12.5, 0.14, 10.1), materials["concrete"])
	var art := SiteArt.new()
	add_child(art)
	art.build_site()

func _make_materials() -> void:
	materials = Materials.build()

func reset_contract() -> void:
	job_generation += 1
	support_pending = false
	completion_pending = false
	if is_instance_valid(building):
		remove_child(building)
		building.queue_free()
	for item in debris:
		if is_instance_valid(item):
			item.queue_free()
	debris.clear()
	for item in charges:
		if is_instance_valid(item["node"]):
			item["node"].queue_free()
	charges.clear()
	for child in effects.get_children():
		child.queue_free()
	rubble.clear_all()
	collapse_queue.clear()
	fragment_queue.clear()
	_collapse_clock = 0.0
	pieces.clear()
	stair_ids.clear()
	stair_ramp = null
	removed_count = 0
	paid = false
	supply = [0, 12, 6]
	reward = 1200 + mini(int(state.completed), 8) * 100
	var names := ["Haus Sonneneck", "Villa Morgenrot", "Haus am Kran"]
	job_title = "%02d · %s" % [int(state.completed) + 1, names[int(state.completed) % names.size()]]
	building = Node3D.new()
	building.process_mode = Node.PROCESS_MODE_PAUSABLE
	building.name = "ZerstoerbaresHaus"
	add_child(building)
	_build_house()
	_connect_structure()
	for piece in pieces:
		piece.prewarm_fracture(0)
		piece.prewarm_fracture(1)
	player.position = Vector3(13, 0.25, 17)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.look_at(Vector3(0, 0.25, 0), Vector3.UP)
	player.head.rotation.x = -0.05
	apply_upgrades()
	select_tool(0)
	update_hud()

func _build_house() -> void:
	House.build(self)

func _table(at: Vector3) -> void:
	add_piece(at + Vector3(0, 0.95, 0), Vector3(2.2, 0.16, 1.2), "wood", "wood")
	for x in [-0.85, 0.85]:
		for z in [-0.4, 0.4]:
			add_piece(at + Vector3(x, 0.45, z), Vector3(0.12, 0.9, 0.12), "wood", "darkwood")

func add_piece(at: Vector3, size: Vector3, kind: String, material_name: String) -> AbrissPiece:
	var piece := Piece.new()
	piece.setup(pieces.size(), at, size, kind, materials[material_name])
	piece.core_material = materials["brick_core"] if kind == "brick" else materials.get(kind + "_core", materials[material_name])
	building.add_child(piece)
	pieces.append(piece)
	return piece

func _connect_structure() -> void:
	for i in range(pieces.size()):
		var a := pieces[i]
		for j in range(i + 1, pieces.size()):
			var b := pieces[j]
			var difference := (a.position - b.position).abs()
			var reach := (a.size + b.size) * 0.5 + Vector3.ONE * 0.095
			if difference.x <= reach.x and difference.y <= reach.y and difference.z <= reach.z:
				a.neighbors.append(j)
				b.neighbors.append(i)

func use_tool() -> void:
	if get_tree().paused:
		return
	var hit := player.aim(3.2 if selected_tool == 0 else 8.0)
	if hit.is_empty():
		ui.show_toast("Geh näher an das Haus und ziele auf ein Bauteil.")
		return
	var piece := hit["collider"] as AbrissPiece
	if piece == null or piece.removed or piece.pending_collapse:
		ui.show_toast("Ziele auf einen noch stehenden Bereich des Abrisshauses.")
		return
	player.swing()
	if selected_tool == 0:
		var force := 32.0 if state.owned.get("hammer_upgrade", false) else 20.0
		var point: Vector3 = hit["position"]
		var broken := piece.hit(force, point, hit["normal"])
		for chip in piece.take_eroded():
			queue_fragment(chip, piece, point, 0.35)
		if broken:
			remove_piece(piece, point, 0.5)
		request_support_check()
		_spawn_dust(point, Color("b5b1a6"), 9, 0.18)
		_play_sound("glass" if piece.kind == "glass" else piece.kind, point)
		player.shake = 0.045
	else:
		place_charge(piece, hit["position"], hit["normal"], selected_tool)
	update_hud()

func place_charge(piece: AbrissPiece, point: Vector3, normal: Vector3, type: int) -> void:
	if supply[type] <= 0:
		ui.show_toast("Vorrat aufgebraucht. Der Hammer bleibt kostenlos verfügbar.")
		return
	for charge in charges:
		if charge["node"].global_position.distance_to(point) < 0.6:
			ui.show_toast("Hier liegt bereits eine Ladung. Nutze ein anderes Bauteil.")
			return
	var gadget := Node3D.new()
	piece.add_child(gadget)
	gadget.global_position = point + normal * 0.13
	var color := Color("ff933d") if type == 1 else Color("a590ff")
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	visual_box(gadget, Vector3.ZERO, Vector3(0.26, 0.26, 0.26), materials["ink"])
	visual_box(gadget, Vector3(0, 0, 0.14), Vector3(0.18, 0.18, 0.04), material)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.6
	light.omni_range = 1.0
	gadget.add_child(light)
	charges.append({"node": gadget, "type": type, "piece": piece})
	supply[type] -= 1
	ui.show_toast("%s platziert · R zum Zünden · Noch %d im Vorrat" % ["Impulsladung" if type == 1 else "Wirbelladung", supply[type]])
	_play_sound("place", point)

func detonate_charges() -> void:
	if get_tree().paused:
		return
	if charges.is_empty():
		ui.show_toast("Erst mit 2 oder 3 ein Gerät wählen und mit Linksklick platzieren.")
		return
	var pending := charges.duplicate()
	charges.clear()
	for item in pending:
		var gadget: Node3D = item["node"]
		if not is_instance_valid(gadget):
			continue
		var point := gadget.global_position
		gadget.queue_free()
		blast(point, int(item["type"]))
	request_support_check()
	update_hud()

func blast(point: Vector3, type: int) -> void:
	var enhanced: bool = state.owned.get("blast_upgrade", false)
	var radius := (3.4 if type == 1 else 4.3) * (1.15 if enhanced else 1.0)
	var damage := (125.0 if type == 1 else 90.0) * (1.3 if enhanced else 1.0)
	for piece in pieces:
		if piece.removed or piece.pending_collapse:
			continue
		var distance := piece.global_position.distance_to(point)
		if distance < radius:
			var destroyed := piece.hit(damage * (1.0 - distance / (radius * 1.4)))
			if destroyed:
				remove_piece(piece, point, 1.6 if type == 1 else -0.9)
	_spawn_dust(point, Color("b8b2a6"), 40 if quality else 18, radius * 0.3)
	player.shake = minf(0.16, 0.5 / maxf(player.position.distance_to(point), 1.0))
	_play_sound("blast", point)
	request_support_check()
	update_hud()

func remove_piece(piece: AbrissPiece, origin: Vector3, force: float) -> void:
	if piece.removed:
		return
	var fragments := piece.remaining_fragments(0)
	if rubble.room() < fragments.size():
		if not piece.pending_collapse:
			piece.pending_collapse = true
			collapse_queue.append({"piece": piece, "origin": origin, "force": force, "due": _collapse_clock})
			collapse_queue.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.due) < float(b.due))
		return
	_break_now(piece, fragments, origin, force)

func _break_now(piece: AbrissPiece, fragments: Array[Dictionary], origin: Vector3, force: float) -> void:
	for charge in charges:
		if charge["piece"] == piece and is_instance_valid(charge["node"]):
			charge["node"].reparent(effects)
	var attached: Array[Node3D] = []
	for child in piece.get_children():
		if not child is Node3D or child is CollisionShape3D or child == piece.visual:
			continue
		if child is MeshInstance3D and (child in piece._chunk_visuals or child in piece.damage_marks):
			continue
		attached.append(child)
	if piece.piece_id in stair_ids and is_instance_valid(stair_ramp):
		stair_ramp.collision_layer = 0
	removed_count += 1
	var detail_body: RigidBody3D
	var largest_volume := 0.0
	for fragment in fragments:
		_emit_fragment(fragment, piece.global_transform, piece.kind, origin, force)
		if float(fragment.volume) > largest_volume:
			largest_volume = float(fragment.volume)
			detail_body = rubble.last_emitted
	if is_instance_valid(detail_body):
		for child in attached:
			child.set_meta("architectural_detail", true)
			child.reparent(detail_body, true)
	piece.deactivate()

func queue_fragment(fragment: Dictionary, piece: AbrissPiece, origin: Vector3, force: float) -> void:
	if rubble.room() > 0:
		_emit_fragment(fragment, piece.global_transform, piece.kind, origin, force)
	else:
		fragment_queue.append({"fragment": fragment, "pose": piece.global_transform, "kind": piece.kind, "origin": origin, "force": force})

func _emit_fragment(fragment: Dictionary, pose: Transform3D, kind: String, origin: Vector3, force: float) -> void:
	var center: Vector3 = pose * Vector3(fragment["offset"])
	var away := center - origin
	if away.length_squared() < 0.0001:
		away = Vector3.ZERO
	else:
		away = away.normalized()
	var velocity := away * clampf(force, -1.2, 1.8)
	velocity.y = minf(velocity.y, 0.45)
	rubble.emit_fragment(fragment, Transform3D(pose.basis, center), kind, velocity)

func _physics_process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(rubble):
		return
	_collapse_clock += delta
	var processed := 0
	# Budget-waiting sections already fall under gravity. They never remain hanging
	# merely because the pool of detailed rigid fragments is temporarily full.
	for waiting in collapse_queue:
		if float(waiting.due) > _collapse_clock:
			continue
		var section: AbrissPiece = waiting.piece
		if section.removed:
			continue
		if not waiting.has("fall_speed"):
			section.collision_layer = 0
			waiting["fall_speed"] = 0.0
			waiting["landing"] = rubble.landing_height(section.global_position) + section.size.y * 0.5 + 0.015
		waiting["fall_speed"] = float(waiting.fall_speed) + 9.81 * delta
		section.position.y = maxf(float(waiting.landing), section.position.y - float(waiting.fall_speed) * delta)
	while not fragment_queue.is_empty() and rubble.room() > 0:
		var item: Dictionary = fragment_queue.pop_front()
		_emit_fragment(item.fragment, item.pose, item.kind, item.origin, item.force)
	var index := 0
	while index < collapse_queue.size():
		if processed >= 5:
			break
		var item := collapse_queue[index]
		if float(item.due) > _collapse_clock:
			break
		var piece: AbrissPiece = item.piece
		if piece.removed:
			collapse_queue.remove_at(index)
			continue
		var fragments := piece.remaining_fragments(0)
		if rubble.room() < fragments.size():
			index += 1
			continue
		_break_now(piece, fragments, item.origin, float(item.force))
		collapse_queue.remove_at(index)
		processed += 1
		if processed % 3 == 0:
			_spawn_dust(piece.global_position, Color("b8b2a6"), 4, 0.4)
	if processed > 0:
		update_hud()
		check_completion()

func request_support_check() -> void:
	if support_pending:
		return
	support_pending = true
	var generation := job_generation
	get_tree().create_timer(0.12, false).timeout.connect(func():
		if generation != job_generation:
			return
		support_pending = false
		check_support()
	)

func check_support() -> int:
	var strengths: Dictionary = {}
	var queue: Array[int] = []
	for piece in pieces:
		if not piece.removed and not piece.pending_collapse and piece.anchored:
			strengths[piece.piece_id] = piece.structural_strength()
			queue.append(piece.piece_id)
	var cursor := 0
	while cursor < queue.size():
		var current := pieces[queue[cursor]]
		cursor += 1
		for neighbor in current.neighbors:
			var next := pieces[neighbor]
			if next.removed or next.pending_collapse:
				continue
			var height := next.position.y - current.position.y
			var transfer := 0.98 if height > 0.10 else (0.71 if absf(height) <= 0.10 else 0.36)
			var strength := float(strengths[current.piece_id]) * transfer * next.structural_strength()
			if strength > 0.12 and strength > float(strengths.get(neighbor, 0.0)) + 0.001:
				strengths[neighbor] = strength
				queue.append(neighbor)
	var fallen := 0
	for piece in pieces:
		if not piece.removed and not piece.pending_collapse and not strengths.has(piece.piece_id):
			piece.pending_collapse = true
			var delay := 0.12 + piece.position.y * 0.07 + float(piece.piece_id % 7) * 0.018
			collapse_queue.append({"piece": piece, "origin": piece.global_position, "force": 0.0, "due": _collapse_clock + delay})
			fallen += 1
	if fallen > 8:
		_play_sound("collapse", Vector3(0, 2, 0))
		ui.show_toast("Das Gebaeude gibt nach. Bauteile verlieren ihre Stuetzen.")
	collapse_queue.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.due) < float(b.due))
	update_hud()
	check_completion()
	return fallen

func check_completion() -> void:
	if paid or completion_pending or progress() < TARGET:
		return
	completion_pending = true
	var generation := job_generation
	get_tree().create_timer(2.6, false).timeout.connect(func():
		if generation == job_generation and not paid:
			complete_contract()
	)

func complete_contract() -> void:
	if paid or progress() < TARGET:
		return
	paid = true
	completion_pending = false
	var earned := reward + (supply[1] + supply[2]) * 10
	state.money = int(state.money) + earned
	state.completed = int(state.completed) + 1
	save_progress()
	update_hud()
	ui.show_result(earned, int(state.money))
	set_menu(true)

func purchase(id: String) -> void:
	if not COSTS.has(id) or state.owned.get(id, false):
		return
	var cost: int = COSTS[id]
	if int(state.money) < cost:
		ui.show_toast("Dafür reicht dein Guthaben noch nicht.")
		return
	state.money = int(state.money) - cost
	state.owned[id] = true
	apply_upgrades()
	save_progress()
	update_hud()
	ui.show_shop(int(state.money), state.owned)
	ui.show_toast("Verbesserung gekauft und gespeichert.")

func apply_upgrades() -> void:
	player.speed = 8.0 if state.owned.get("boots_upgrade", false) else 6.2

func select_tool(index: int) -> void:
	selected_tool = clampi(index, 0, 2)
	player.select_tool(selected_tool)
	update_hud()

func update_hud() -> void:
	if not is_instance_valid(ui):
		return
	ui.set_status(int(state.money), progress(), selected_tool, charges.size(), job_title)
	if selected_tool > 0:
		ui.charges_label.text = "%d platziert · %d im Vorrat · Ziel: 72 %% Abriss" % [charges.size(), supply[selected_tool]]
	else:
		ui.charges_label.text = "%d Ladungen platziert · Ziel: 72 %% Abriss" % charges.size()

func progress() -> float:
	return float(removed_count) / maxf(float(pieces.size()), 1.0)

func save_progress() -> void:
	if not Save.write_state(state):
		ui.show_toast("Spielstand konnte nicht geschrieben werden. Bitte Ordnerrechte prüfen.")

func set_menu(open: bool) -> void:
	get_tree().paused = open
	player.controls_enabled = not open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED

func resume_game() -> void:
	briefing = false
	ui.hide_panels()
	set_menu(false)

func toggle_pause() -> void:
	if ui.is_panel_open():
		resume_game()
	else:
		ui.show_pause()
		set_menu(true)

func open_shop() -> void:
	if ui.is_panel_open():
		return
	ui.show_shop(int(state.money), state.owned)
	set_menu(true)

func restart_contract() -> void:
	if paid:
		ui.show_toast("Der Auftrag ist bezahlt. Nimm im Shop den nächsten Auftrag an.")
		return
	reset_contract()
	resume_game()
	ui.show_toast("Auftrag neu gestartet · Werkzeugvorrat aufgefüllt.")

func next_contract() -> void:
	if briefing:
		resume_game()
		ui.show_toast("Willkommen! Erkunde das Haus. 1 Hammer · 2 Impuls · 3 Wirbel · R Zünden")
	elif paid:
		reset_contract()
		resume_game()
		ui.show_toast("Neuer Auftrag · Neues Werkzeugpaket · Viel Erfolg!")
	else:
		ui.show_toast("Schließe zuerst den laufenden Auftrag ab: 72 % Abriss.")

func set_quality(enabled: bool) -> void:
	set_quality_level(1 if enabled else 0)

func set_quality_level(level: int) -> void:
	quality_level = clampi(level, 0, 2)
	quality = quality_level > 0
	sun.shadow_enabled = quality
	sun.directional_shadow_max_distance = 100.0 if quality_level == 2 else 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality_level == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	player.camera.far = [110.0, 180.0, 240.0][quality_level]
	rubble.MAX_ACTIVE = [36, 72, 96][quality_level]
	ui._quality_level = quality_level

func _unhandled_input(event: InputEvent) -> void:
	# This node processes while paused so Escape can also close menus.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
			get_viewport().set_input_as_handled()

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _spawn_dust(at: Vector3, color: Color, count: int, spread: float) -> void:
	if _dust_texture == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var radius := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var alpha := pow(maxf(0.0, 1.0 - radius), 2.2)
				image.set_pixel(x, y, Color(1, 1, 1, alpha * 0.48))
		_dust_texture = ImageTexture.create_from_image(image)
	var particles := CPUParticles3D.new()
	particles.amount = count
	particles.one_shot = true
	particles.lifetime = 2.4
	particles.explosiveness = 0.85
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = spread
	particles.direction = Vector3.UP
	particles.spread = 60.0
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.65
	particles.gravity = Vector3(0, -0.05, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.8))
	gradient.add_point(0.25, Color(color, 0.65))
	gradient.set_color(1, Color(color, 0.0))
	particles.color_ramp = gradient
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.albedo_texture = _dust_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	particles.mesh = mesh
	particles.position = at
	effects.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _make_sounds() -> void:
	for type in ["hit", "brick", "concrete", "wood", "collapse", "blast", "glass", "place"]:
		var large: bool = type in ["blast", "collapse"]
		var duration := 1.8 if large else 0.28
		var samples := PackedByteArray()
		var rate := 22050
		var rng := RandomNumberGenerator.new()
		rng.seed = type.hash()
		var smooth_noise := 0.0
		for i in range(int(duration * rate)):
			var t := float(i) / rate
			var decay := 3.0 if large else (12.0 if type == "glass" else 25.0)
			var envelope := exp(-t * decay)
			var frequency: float = {"wood": 160.0, "concrete": 72.0, "brick": 115.0, "glass": 1730.0, "place": 900.0}.get(type, 48.0)
			var noise := rng.randf_range(-1, 1)
			smooth_noise = lerpf(smooth_noise, noise, 0.08 if large else 0.35)
			var texture := smooth_noise * 1.8 if large else noise * 0.4
			var wave := (sin(t * TAU * frequency) * 0.35 + texture + sin(t * TAU * frequency * 2.71) * 0.12) * envelope
			var value := int(clampf(wave * 18000, -32767, 32767))
			samples.append(value & 255)
			samples.append((value >> 8) & 255)
		var audio := AudioStreamWAV.new()
		audio.format = AudioStreamWAV.FORMAT_16_BITS
		audio.mix_rate = rate
		audio.data = samples
		sounds[type] = audio

func _play_sound(type: String, at: Vector3) -> void:
	if muted:
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = sounds[type]
	sound.position = at
	sound.max_distance = 65.0
	sound.volume_db = -7.0 if type == "blast" else -12.0
	sound.pitch_scale = randf_range(0.9, 1.1)
	effects.add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)

func visual_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = material
	parent.add_child(visual)
	return visual

func static_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	visual_box(body, Vector3.ZERO, size, material)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _capture_preview() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/startmenue.png")
	resume_game()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/spielansicht.png")
	open_shop()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/werkstatt.png")
	resume_game()
	select_tool(1)
	blast(Vector3(-4.8, 1.4, 4.5), 1)
	blast(Vector3(4.8, 1.4, 4.5), 1)
	request_support_check()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/abriss.png")
	get_tree().quit()

