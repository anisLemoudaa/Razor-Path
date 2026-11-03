extends SceneTree
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var store := root.get_node("TuningStore")
	store.persistence_enabled = false
	store.player_values.clear()
	store.end_run()
	store.reset_defaults(false)
	var effects = load("res://scripts/visual_effects.gd").new()
	root.add_child(effects)
	for index in 100:
		effects.spawn_collect_sparkle(Vector2(index, 40))
	_check(effects.active_bursts.size() == effects.MAX_ACTIVE_BURSTS, "bursts are not bounded")
	for burst in effects.active_bursts:
		_check(burst.amount <= effects.MAX_PARTICLES_PER_BURST, "particle budget exceeded")
	effects.reset_effects()
	await process_frame
	effects.spawn_run_dust(Vector2.ZERO)
	_check(effects.get_spawn_count("trail") == 1, "running trail missing")
	effects.reset_effects()
	await process_frame
	store.set_player_setting("reduced_motion", 1)
	effects.spawn_run_dust(Vector2.ZERO)
	_check(effects.active_bursts.is_empty(), "reduced motion retained trail")
	effects.spawn_stomp_impact(Vector2.ZERO)
	_check(effects.active_bursts.size() == 1, "reduced motion removed all useful feedback")
	var quiet: CPUParticles2D = effects.active_bursts[0]
	_check(quiet.initial_velocity_max == 0 and quiet.gravity == Vector2.ZERO and quiet.amount <= 4, "reduced feedback is not static/bounded")
	store.set_player_setting("filter_enabled", 0)
	_check(not effects.filter_rect.visible, "filter toggle ignored")
	store.set_player_setting("filter_enabled", 1)
	store.set_player_setting("filter_intensity", .2)
	_check(effects.filter_rect.visible and is_equal_approx(effects.filter_rect.color.a, .2), "filter intensity ignored")
	effects.reset_effects()
	_check(effects.active_bursts.is_empty() and effects.feedback_time == 0, "effects leaked across reset")
	effects.queue_free()
	store.player_values.clear()
	store.reset_defaults(false)
	await process_frame
	if not failed:
		print("[VFX_PASS] bounded burst/trail, reduced motion, filter and reset")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[VFX_FAIL] " + message)
