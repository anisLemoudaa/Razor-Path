extends Node
## Local-only bounded records. No network adapters or global submission path.

const SAVE_PATH := "user://save.json"
const SCHEMA_VERSION := 2
const TOP_N := 10
const NAME_LIMIT := 24
const NAME_BYTES := 96
const FONT = preload("res://assets/template/fonts/ui_regular.tres")
var data: Dictionary = _default_data()
var _replay_tutorial := false
var last_save_ok := true
signal save_failed

func _ready() -> void:
	load_save()

func _default_data() -> Dictionary:
	return {"version": SCHEMA_VERSION, "best_score": 0, "player_name": "Player", "records": [], "tutorial_version": 0}

func load_save() -> void:
	data = _default_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not _number(parsed.get("version")):
		return
	if int(parsed.version) < 1 or int(parsed.version) > SCHEMA_VERSION:
		return
	data.best_score = _safe_int(parsed.get("best_score", 0), 0, 99999999)
	var name_value: Variant = parsed.get("player_name", "Player")
	if name_value is String and valid_player_name(name_value):
		data.player_name = name_value.strip_edges()
	data.tutorial_version = _safe_int(parsed.get("tutorial_version", 0), 0, 1000)
	var records: Variant = parsed.get("records", [])
	if records is Array:
		var seen: Dictionary = {}
		for entry: Variant in records.slice(0, 100):
			var record := _sanitize_record(entry)
			if record.is_empty() or seen.has(record.run_id):
				continue
			seen[record.run_id] = true
			data.records.append(record)
	_sort_records()

func save() -> bool:
	var pending := SAVE_PATH + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		last_save_ok = false
		save_failed.emit()
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	last_save_ok = DirAccess.rename_absolute(pending, SAVE_PATH) == OK
	if not last_save_ok: save_failed.emit()
	return last_save_ok

func valid_player_name(value: String) -> bool:
	var clean := value.strip_edges()
	if clean.is_empty() or clean.length() > NAME_LIMIT or clean.to_utf8_buffer().size() > NAME_BYTES:
		return false
	for character in clean:
		var point := character.unicode_at(0)
		if point < 32 or point in [60, 62, 38, 127] or (point >= 128 and point <= 159) or point in [0x200b, 0x200c, 0x200d, 0x200e, 0x200f, 0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069, 0xfeff] or not FONT.has_char(point):
			return false
	return true

func set_player_name(value: String) -> bool:
	if not valid_player_name(value):
		return false
	data.player_name = value.strip_edges()
	return save()

func player_name() -> String:
	return str(data.player_name)

func leaderboard() -> Array:
	return data.records.duplicate(true)

func record_run(result: Dictionary) -> bool:
	var source := result.duplicate(true)
	source.player_name = player_name()
	var record := _sanitize_record(source)
	if record.is_empty():
		return false
	for existing: Dictionary in data.records:
		if existing.run_id == record.run_id:
			return false
	var is_best := int(record.score) > best_score()
	data.best_score = maxi(best_score(), int(record.score))
	data.records.append(record)
	_sort_records()
	save()
	return is_best

func _sort_records() -> void:
	data.records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score: return a.score > b.score
		if a.duration != b.duration: return a.duration < b.duration
		if a.timestamp != b.timestamp: return a.timestamp < b.timestamp
		return a.run_id < b.run_id)
	if data.records.size() > TOP_N:
		data.records.resize(TOP_N)

func _sanitize_record(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	for key in ["run_id", "stage", "outcome", "configuration", "player_name"]:
		if not value.get(key) is String or str(value[key]).is_empty():
			return {}
	if value.run_id.length() > 100 or value.stage.length() > 80 or value.configuration.length() > 128 or not valid_player_name(value.player_name):
		return {}
	if value.outcome not in ["victory", "defeat"] or not value.get("eligible") is bool:
		return {}
	for key in ["score", "duration", "timestamp"]:
		if not _number(value.get(key)) or float(value[key]) < 0.0:
			return {}
	return {"run_id": value.run_id, "player_name": value.player_name.strip_edges(), "score": _safe_int(value.score, 0, 99999999), "stage": value.stage, "outcome": value.outcome, "duration": clampf(float(value.duration), 0.0, 86400.0), "timestamp": _safe_int(value.timestamp, 0, 9999999999), "eligible": value.eligible, "configuration": value.configuration}

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _safe_int(value: Variant, minimum: int, maximum: int) -> int:
	return clampi(int(value), minimum, maximum) if _number(value) else minimum

func record_score(score: int) -> bool:
	# Retained for existing callers; full runs use record_run.
	var is_best := score > best_score()
	if is_best:
		data.best_score = clampi(score, 0, 99999999)
		save()
	return is_best

func best_score() -> int:
	return int(data.best_score)

func tutorial_completed(version: int = 1) -> bool:
	return int(data.tutorial_version) >= version

func complete_tutorial(version: int = 1) -> void:
	data.tutorial_version = version
	save()

func request_tutorial_replay() -> void:
	_replay_tutorial = true

func consume_tutorial_replay() -> bool:
	var requested := _replay_tutorial
	_replay_tutorial = false
	return requested
