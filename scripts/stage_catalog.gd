extends RefCounted
## Add an entry here and a JSON definition; the session/router needs no changes.

const STAGES := ["sunlit_nook", "lofty_lounge"]
const PATH := "res://data/stages/%s.json"

static func stages() -> Array:
	return STAGES.duplicate()

static func load_stage(id: String) -> Dictionary:
	if id not in STAGES:
		return {}
	var file := FileAccess.open(PATH % id, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not validate(parsed):
		return {}
	return parsed

static func validate(stage: Dictionary) -> bool:
	for key in ["id", "name_key", "world_width", "spawn", "goal", "checkpoint", "grounds", "platforms", "trees", "blocks", "fish", "enemies", "required_fish"]:
		if not stage.has(key):
			return false
	if not stage.id is String or stage.id.is_empty() or not stage.name_key is String:
		return false
	if not _number(stage.world_width) or float(stage.world_width) < 1000.0 or float(stage.world_width) > 30000.0:
		return false
	for key in ["spawn", "goal", "checkpoint"]:
		if not _point(stage[key], float(stage.world_width)):
			return false
	for key in ["grounds", "platforms", "trees"]:
		if not stage[key] is Array:
			return false
		for entry: Variant in stage[key]:
			if not entry is Array or entry.size() != 2 or not _point(entry[0], float(stage.world_width)) or not _point(entry[1], float(stage.world_width)):
				return false
			if float(entry[1][0]) <= 0.0 or float(entry[1][1]) <= 0.0:
				return false
	if stage.grounds.is_empty():
		return false
	for key in ["fish", "blocks", "enemies"]:
		if not stage[key] is Array:
			return false
		for entry: Variant in stage[key]:
			if not _point(entry, float(stage.world_width)):
				return false
	if not _number(stage.required_fish) or int(stage.required_fish) < 0 or int(stage.required_fish) > stage.fish.size():
		return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _point(value: Variant, width: float) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and float(value[0]) >= 0.0 and float(value[0]) <= width and float(value[1]) >= -1000.0 and float(value[1]) <= 1000.0
