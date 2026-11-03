extends SceneTree
var failed := false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var store := root.get_node("TuningStore")
	var old_mode: float = store.get_player_setting("display_mode")
	for mode in [0, 1]:
		store.set_player_setting("display_mode", mode)
		for physical in [Vector2i(400, 800), Vector2i(720, 720), Vector2i(1280, 720), Vector2i(1920, 720)]:
			root.size = physical
			await process_frame
			await process_frame
			var title = load("res://scenes/title_screen.tscn").instantiate()
			root.add_child(title)
			await process_frame
			await process_frame
			var viewport_rect: Rect2 = title.get_viewport_rect()
			_check(viewport_rect.encloses(title.key_art_rect()), "title key art remains contained")
			var content: Control = title.get_node("ResponsiveCenter/Content")
			_check(viewport_rect.encloses(content.get_global_rect()), "title UI fits supported viewports")
			var language: Control = content.find_child("LanguageSelector", true, false)
			_check(language.size.y <= 64.0, "language caption must not expand the row vertically")
			if physical.x == 400:
				_check(title._title_scroll.get_global_rect().encloses(title._start_button.get_global_rect()), "compact first fold must show Start")
			var plate: PanelContainer = content as PanelContainer
			_check(plate.get_theme_stylebox("panel").bg_color.a >= 0.9, "copy has opaque contrast backing")
			for control in content.find_children("*", "Control", true, false):
				if control is Button:
					_check(control.size.y >= 44, "minimum touch target")
				if control is Label:
					_check(control.get_theme_font("font").get_font_name().begins_with("Nunito"), "Nunito UI face on title body text")
			title.queue_free()
			await process_frame
	store.set_player_setting("display_mode", old_mode)
	if not failed: print("[TITLE_PRESENTATION_PASS] responsive title, focusable controls and UI-font contrast")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(1 if failed else 0)
func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
