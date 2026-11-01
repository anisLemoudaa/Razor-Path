extends SceneTree
var output := OS.get_environment("GAME_CAPTURE_DIR")
var prefix := ""
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if output.is_empty():
		push_error("Set GAME_CAPTURE_DIR outside the project")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.get_node("TuningStore").reset_defaults(false)
	root.get_node("TuningStore").set_player_setting("display_mode", 1)
	var saves = root.get_node("SaveStore")
	saves.data.records = []
	saves.data.best_score = 0
	for index in 10:
		saves.set_player_name("Jun小猫" if index % 2 == 0 else "Calico 猫咪")
		saves.record_run({"run_id": "capture-%d" % index, "stage": "lofty_lounge", "outcome": "victory" if index % 2 == 0 else "defeat", "configuration": "capture-fixture", "score": 9800 - index * 450, "duration": 65 + index * 5, "timestamp": 1 + index, "eligible": index % 3 != 0})
	saves.set_player_name("Jun小猫")
	for locale in ["en", "zh-CN"]:
		root.get_node("I18n").set_locale(locale)
		for display in [{"size": Vector2i(1280, 720), "mode": 0, "name": "landscape"}, {"size": Vector2i(480, 800), "mode": 1, "name": "portrait"}, {"size": Vector2i(480, 800), "mode": 0, "name": "portrait-fixed"}]:
			root.get_node("TuningStore").set_player_setting("display_mode", display.mode)
			root.size = display.size
			prefix = locale + "-" + display.name
			await process_frame
			await process_frame
			var title = load("res://scenes/title_screen.tscn").instantiate()
			root.add_child(title)
			await shot("title")
			title._open_settings()
			await shot("settings")
			title._modal.close_panel()
			await process_frame
			title._open_leaderboard()
			await shot("leaderboard")
			title._modal.close_panel()
			await process_frame
			title.queue_free()
			await process_frame
			root.get_node("SaveStore").request_tutorial_replay()
			var game = load("res://scenes/game.tscn").instantiate()
			root.add_child(game)
			for i in 30: await physics_frame
			await shot("gameplay")
			game.pause_menu.open_menu()
			await shot("pause")
			game.pause_menu.close_menu()
			game._on_time_up()
			await shot("debrief")
			game.queue_free()
			await process_frame
			paused = false
	print("[ACCEPTANCE_CAPTURE_PASS] EN/CN landscape/portrait title, settings, standings, gameplay, pause, tuning, results")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(0)
func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var file := output.path_join(prefix + "-" + name + ".png")
	if root.get_texture().get_image().save_png(file) != OK:
		push_error("Capture failed: " + file)
		quit(1)
