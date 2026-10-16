class_name AbrissImpactAudio
extends RefCounted
## Original Kenney CC0 impact/foley clips, with a small synchronized debris mix.
## The existing generated blast stays as fallback: this pack has no blast clip.

static func build() -> Dictionary:
	var loaded: Dictionary = {}
	for name in ["impactMining_000", "impactMining_001", "impactMining_002",
		"impactWood_heavy_000", "impactPlank_medium_000", "impactGlass_heavy_001",
		"impactGlass_medium_000", "impactGeneric_light_000"]:
		var path := "res://assets/audio/%s.ogg" % name
		var stream: AudioStreamOggVorbis
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStreamOggVorbis
		elif FileAccess.file_exists(path):
			# First headless run can precede editor imports. Exported projects
			# use ResourceLoader above, which respects imported-resource remaps.
			stream = AudioStreamOggVorbis.load_from_file(path)
		if stream != null:
			loaded[name] = stream
	var result: Dictionary = {}
	_assign(result, loaded, "brick", "impactMining_000")
	_assign(result, loaded, "concrete", "impactMining_001")
	_assign(result, loaded, "hit", "impactMining_002")
	_assign(result, loaded, "place", "impactGeneric_light_000")
	if loaded.has("impactWood_heavy_000"):
		result["wood"] = _variation(loaded, ["impactWood_heavy_000", "impactPlank_medium_000"])
	if loaded.has("impactGlass_heavy_001"):
		result["glass"] = _variation(loaded, ["impactGlass_heavy_001", "impactGlass_medium_000"])
	if loaded.has("impactMining_001") and loaded.has("impactPlank_medium_000"):
		var collapse := AudioStreamSynchronized.new()
		collapse.stream_count = 3 if loaded.has("impactGlass_medium_000") else 2
		collapse.set_sync_stream(0, loaded["impactMining_001"])
		collapse.set_sync_stream_volume(0, -1.0)
		collapse.set_sync_stream(1, loaded["impactPlank_medium_000"])
		collapse.set_sync_stream_volume(1, -7.0)
		if loaded.has("impactGlass_medium_000"):
			collapse.set_sync_stream(2, loaded["impactGlass_medium_000"])
			collapse.set_sync_stream_volume(2, -12.0)
		result["collapse"] = collapse
	return result

static func _assign(target: Dictionary, loaded: Dictionary, key: String, name: String) -> void:
	if loaded.has(name):
		target[key] = loaded[name]

static func _variation(loaded: Dictionary, names: Array) -> AudioStreamRandomizer:
	var stream := AudioStreamRandomizer.new()
	stream.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	stream.random_pitch = 1.025
	for name: String in names:
		if loaded.has(name):
			stream.add_stream(-1, loaded[name], 1.0)
	return stream
