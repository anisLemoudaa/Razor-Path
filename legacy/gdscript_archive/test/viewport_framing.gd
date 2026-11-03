extends SceneTree
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var store := root.get_node("TuningStore")
	store.persistence_enabled = false
	store.end_run()
	store.reset_defaults(false)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for mode in [0, 1]:
		store.set_player_setting("display_mode", mode)
		for physical in [Vector2i(320, 640), Vector2i(480, 800), Vector2i(800, 480), Vector2i(1280, 720), Vector2i(1920, 720)]:
			root.size = physical
			await process_frame
			await process_frame
			var logical := root.get_visible_rect().size
			var aspect := 16.0 / 9.0 if mode == 0 else clampf(float(physical.x) / physical.y, 1.0, 16.0 / 6.0)
			var expected := Vector2(1280, 1280 / aspect) if aspect < 16.0 / 9.0 else Vector2(720 * aspect, 720)
			var visible_world: Vector2 = logical / game.camera.zoom
			_check(visible_world.distance_to(expected) < 2.0, "mobile resized authored camera view")
			_check(logical.x <= physical.x + 1 and logical.y <= physical.y + 1, "logical canvas is larger than available physical content")
			var physical_scale: float = root.get_final_transform().x.length()
			_check(game.pause_button.size.y * physical_scale >= 40, "mobile pause target is too small")
			_check(game.score_label.get_theme_font_size("font_size") * physical_scale >= 14, "mobile HUD type is too small")
			var top: PanelContainer = game.hud_root.get_node("TopBar")
			_check(is_equal_approx(top.size.x, logical.x - 24), "HUD panel does not span its intended width")
			_check(top.size.y <= top.get_combined_minimum_size().y + 1, "HUD background stretches below its content")
			_check(game.get_node_or_null("TuningPanel") == null, "native tuning panel must be absent")
			_check(store.get_jump_apex_height() >= 174, "viewport changed jump clearance")
	game.pause_menu.open_menu()
	_check(not game.attack_button.visible, "paused Yarn control remains visible")
	game.pause_menu.close_menu()
	_check(game.attack_button.visible, "Yarn control did not return after resume")
	game._on_goal_reached()
	_check(not game.attack_button.visible, "debrief Yarn control remains visible")
	game.next_stage()
	_check(game.attack_button.visible, "Yarn control did not return for next stage")
	game.queue_free()
	await process_frame
	root.get_node("GameAudio").stop_game()
	await create_timer(.15).timeout
	if not failed:
		print("[VIEWPORT_FRAMING_PASS] physical UI sizes and original authored camera/jump view at320..1920")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[VIEWPORT_FRAMING_FAIL] " + message)
