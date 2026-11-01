extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var title = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	title._start_button.grab_focus()
	title._open_settings()
	_check(paused, "Settings pauses through existing tree owner")
	_check(title._modal.panel.find_children("", "HSlider", true, false).size() == 4, "four independent audio controls")
	title._modal.get_node(".").chrome.get_node("CloseButton").grab_focus()
	await _joy(JOY_BUTTON_A)
	await process_frame
	_check(not paused and root.gui_get_focus_owner() == title._start_button, "Settings restores title focus and pause")
	title._open_leaderboard()
	_check(paused, "standings modal owns pause")
	await _joy(JOY_BUTTON_B)
	_check(not paused, "controller B closes standings")
	await process_frame
	title.queue_free()
	await process_frame
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.pause_button.grab_focus()
	game.pause_menu.open_menu()
	game.pause_menu._open_settings()
	_check(paused and game.pause_menu.is_open, "settings nests inside pause")
	game.pause_menu._settings.close_panel()
	await process_frame
	_check(paused and game.pause_menu.is_open, "settings returns to pause")
	game.pause_menu._request_main_menu()
	_check(game.pause_menu._confirm.visible, "discarding a run requires confirmation")
	game.pause_menu._cancel_loss()
	_check(paused and game.pause_menu.is_open, "cancel preserves run")
	game.pause_menu.resume_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(not paused and root.gui_get_focus_owner() == game.pause_button, "resume restores gameplay focus")
	game._on_goal_reached()
	var next_button: Button = game.message_panel.find_children("", "Button", true, false)[0]
	next_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(game.stage_index == 1 and not game.finished, "controller A selects Next Course")
	game._on_time_up()
	current_scene = game
	await _joy(JOY_BUTTON_B)
	for frame in 3: await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/title_screen.tscn", "controller B returns to title from debrief")
	if current_scene != null: current_scene.queue_free()
	await process_frame
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("[UI_CONTRACT_PASS] title/standings/settings, nested pause/focus, discard confirmation")
	quit(0 if failures.is_empty() else 1)
func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
