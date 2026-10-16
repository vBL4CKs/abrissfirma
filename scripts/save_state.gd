extends RefCounted
class_name AbrissSave

const SAVE_PATH := "user://abrissfirma_save.json"
const UPGRADE_IDS := ["hammer_upgrade", "blast_upgrade", "boots_upgrade"]


static func read_state() -> Dictionary:
	var clean: Dictionary = {"money": 0, "owned": {}, "completed": 0}
	if not FileAccess.file_exists(SAVE_PATH):
		return clean
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return clean
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK or not parser.data is Dictionary:
		return clean
	var saved: Dictionary = parser.data
	if _valid_nonnegative_number(saved.get("money")):
		clean["money"] = clampi(int(saved["money"]), 0, 999999999)
	if _valid_nonnegative_number(saved.get("completed")):
		clean["completed"] = clampi(int(saved["completed"]), 0, 999999)
	var saved_owned: Variant = saved.get("owned", {})
	if saved_owned is Dictionary:
		for upgrade_id: String in UPGRADE_IDS:
			if saved_owned.get(upgrade_id, false) is bool and saved_owned.get(upgrade_id, false):
				clean["owned"][upgrade_id] = true
	return clean


static func write_state(state: Dictionary) -> bool:
	var clean: Dictionary = {"money": 0, "owned": {}, "completed": 0}
	if _valid_nonnegative_number(state.get("money")):
		clean["money"] = clampi(int(state["money"]), 0, 999999999)
	if _valid_nonnegative_number(state.get("completed")):
		clean["completed"] = clampi(int(state["completed"]), 0, 999999)
	var upgrades: Variant = state.get("owned", {})
	if upgrades is Dictionary:
		for upgrade_id: String in UPGRADE_IDS:
			if upgrades.get(upgrade_id, false) is bool and upgrades.get(upgrade_id, false):
				clean["owned"][upgrade_id] = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(clean, "\t"))
	file.flush()
	var succeeded := file.get_error() == OK
	file.close()
	return succeeded


static func _valid_nonnegative_number(value: Variant) -> bool:
	if value is int:
		return value >= 0
	if value is float:
		return is_finite(value) and value >= 0.0
	return false
