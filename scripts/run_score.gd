extends RefCounted
## One run owns score; presentation only reads it. Finalization is idempotent.

const POINTS := {"fish": 100, "robot": 250, "block": 50, "time_second": 10}
const MAX_SCORE := 99999999
var total := 0
var duration := 0.0
var events: Dictionary = {}
var result: Dictionary = {}
var run_id := ""

func begin() -> void:
	total = 0
	duration = 0.0
	events.clear()
	result.clear()
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), Time.get_ticks_usec()]

func tick(delta: float) -> void:
	if result.is_empty() and is_finite(delta) and delta > 0.0:
		duration += delta

func award(event: String, count: int = 1) -> int:
	if not result.is_empty() or not POINTS.has(event) or count <= 0:
		return 0
	var points := clampi(count, 0, 100000) * int(POINTS[event])
	var previous := total
	total = clampi(total + points, 0, MAX_SCORE)
	events[event] = int(events.get(event, 0)) + count
	return total - previous

func finalize(stage: String, outcome: String, eligible: bool, configuration: Dictionary = {}) -> Dictionary:
	if result.is_empty():
		result = {
			"run_id": run_id, "score": total, "stage": stage,
			"outcome": outcome, "duration": snappedf(duration, 0.001),
			"timestamp": int(Time.get_unix_time_from_system()),
			"eligible": eligible, "configuration": JSON.stringify(configuration).sha256_text(),
			"events": events.duplicate(true),
		}
	return result.duplicate(true)
