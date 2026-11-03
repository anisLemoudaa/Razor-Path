extends SceneTree
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var store := root.get_node("TuningStore")
	store.player_values.clear()
	store.end_run()
	store.reset_defaults(false)
	var categories: Dictionary = {}
	for descriptor: Dictionary in store.get_settings():
		categories[descriptor.category] = true
		_check(descriptor.has("id") and descriptor.has("type") and descriptor.has("label_key") and descriptor.has("description_key") and descriptor.has("integrity") and descriptor.has("apply_mode"), "descriptor is incomplete")
	_check(categories.size() == 6, "all six categories must exist")
	if OS.get_cmdline_user_args().has("--release-profile"):
		_check(not ResourceLoader.exists("res://scripts/tuning_panel.gd"), "release retained the developer panel")
		_check(root.get_node_or_null("TuningBridge") == null, "release retained the Addon bridge")
		_check(not ResourceLoader.exists("res://scripts/manus/preview/tuning_transport.gd"), "release retained preview transport")
		# Editor-mounted PCKs retain the editor debug flag; only real release engines can test this gate.
		if not OS.is_debug_build():
			_check(not store.owner_preview_enabled() and not store.set_value("move_speed", 400), "release accepted debug setting")
		_check(store.set_player_setting("reduced_motion", 1), "release lost normal settings")
		for path in ["res://scenes/title_screen.tscn", "res://scenes/game.tscn"]:
			var scene = load(path).instantiate()
			root.add_child(scene)
			await process_frame
			_check(scene.find_child("TuningPanel", true, false) == null and scene.find_child("TuningButton", true, false) == null, "release exposed tuning navigation")
			_check(not scene.has_method("debug_tools_enabled") and not scene.has_method("_open_tuning_from_pause"), "release retained developer entry methods")
			scene.queue_free()
			await process_frame
		await _finish()
		return
	_check(store.owner_preview_enabled(), "debug preview gate failed")
	store.begin_run()
	_check(store.set_value("move_speed", 400), "valid requested value rejected")
	_check(store.get_value("move_speed") == 310 and store.get_requested_value("move_speed") == 400, "next run value applied too early")
	_check(not store.is_run_tainted(), "unapplied value tainted run")
	store.apply_boundary("NEXT_SPAWN")
	_check(store.get_value("move_speed") == 310, "wrong boundary applied value")
	store.begin_run()
	_check(store.get_value("move_speed") == 400 and store.is_run_tainted(), "next run application/taint failed")
	store.reset_defaults(false)
	store.apply_boundary("NEXT_RUN")
	_check(store.is_run_tainted(), "reset erased active run taint")
	store.end_run()
	store.reset_defaults(false)
	store.begin_run()
	_check(store.set_value("hud_opacity", .75) and not store.is_run_tainted(), "cosmetic setting taints run")
	var before: Dictionary = store.requested_values.duplicate(true)
	_check(not store.set_values({"gravity": 3500, "jump_power": 250}), "unplayable cross-field set accepted")
	_check(store.requested_values == before, "invalid set partially applied")
	_check(not store.set_value("move_speed", 315), "invalid step accepted")
	_check(not store.set_value("move_speed", NAN), "NaN accepted")
	_check(not store.set_player_setting("move_speed", 400), "normal player settings bypass integrity")
	_check(store.set_value("attack_cooldown", .4), "next action value rejected")
	_check(is_equal_approx(store.get_value("attack_cooldown"), .28), "next action changed early")
	store.apply_boundary("NEXT_ACTION")
	_check(is_equal_approx(store.get_value("attack_cooldown"), .4) and store.is_run_tainted(), "next action boundary failed")
	store.end_run()
	store.reset_defaults(false)
	store.set_value("enemy_count", 14)
	store.apply_boundary("NEXT_STAGE")
	_check(store.get_value("enemy_count") == 14, "next stage boundary failed")
	store.set_value("yarn_speed", 700)
	store.apply_boundary("NEXT_SPAWN")
	_check(store.get_value("yarn_speed") == 700, "next spawn boundary failed")
	store.end_run()
	store.player_values.clear()
	store.reset_defaults(false)
	await _finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[TWEAK_FAIL] " + message)


func _finish() -> void:
	root.get_node("GameAudio").stop_game()
	# The native mixer consumes queued stop requests on its audio thread.
	await create_timer(0.15).timeout
	if not failed:
		print("[TWEAK_PASS] schema, boundaries, integrity and release gate")
	quit(1 if failed else 0)

