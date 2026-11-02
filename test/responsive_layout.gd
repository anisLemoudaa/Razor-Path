extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(320, 640), Vector2i(480, 800), Vector2i(400, 800), Vector2i(720, 720), Vector2i(960, 720),
	Vector2i(1280, 720), Vector2i(1680, 720), Vector2i(1920, 720),
	Vector2i(2400, 600), Vector2i(320, 960), Vector2i(1280, 720),
]

var failed := false

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	check_android_preset()
	var store := root.get_node("TuningStore")
	var old_mode: float = store.get_value("display_mode")
	for display_mode in [0, 1]:
		store.set_value("display_mode", display_mode)
		for viewport_size in VIEWPORT_SIZES:
			paused = true
			root.size = viewport_size
			await process_frame
			await process_frame
			check_aspect(viewport_size)
			paused = false
			await check_touch_bounds()
			await check_title(viewport_size)
			await check_game(viewport_size)
	store.set_value("display_mode", old_mode)
	if not failed:
		print("[RESPONSIVE_PASS] bounded viewport, UI, camera and backgrounds")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(1 if failed else 0)

func check_android_preset() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		failed = true
		push_error("Android export preset cannot be loaded")
		return
	if int(config.get_value("preset.1.options", "screen/orientation", -1)) != 0:
		failed = true
		push_error("Android build is not configured for landscape orientation")
	if not bool(config.get_value("preset.1.options", "screen/immersive_mode", false)):
		failed = true
		push_error("Android immersive fullscreen is disabled")

func check_title(viewport_size: Vector2i) -> void:
	var title = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	var content: Control = title._content_panel
	check_rect(content.get_global_rect(), title.get_viewport_rect().size, "title panel", viewport_size)
	title.queue_free()
	await process_frame

func check_game(viewport_size: Vector2i) -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var top_bar: Control = game.get_node("HudLayer/ResponsiveHud/TopBar")
	var logical_size: Vector2 = game.get_viewport_rect().size
	check_rect(top_bar.get_global_rect(), logical_size, "hud", viewport_size)
	var pixel_scale: float = root.get_final_transform().x.length()
	var touch_controls: Array[Control] = [game.left_button, game.right_button, game.jump_button, game.attack_button]
	for index in touch_controls.size():
		var control := touch_controls[index]
		check_rect(control.get_global_rect(), logical_size, control.name, viewport_size)
		if control.size.x * pixel_scale < 48.0 or control.size.y * pixel_scale < 48.0:
			failed = true
			push_error("touch target smaller than 48 physical pixels: %s at %s" % [control.name, viewport_size])
		for other_index in range(index + 1, touch_controls.size()):
			if control.get_global_rect().intersects(touch_controls[other_index].get_global_rect()):
				failed = true
				push_error("touch targets overlap: %s and %s at %s" % [control.name, touch_controls[other_index].name, viewport_size])
	if game.score_label.get_theme_font_size("font_size") * pixel_scale < 14:
		failed = true
		push_error("physical mobile HUD text too small")
	var pause_button: Button = game.get("pause_button")
	if pause_button == null:
		failed = true
		push_error("pause button is missing at %s" % viewport_size)
	else:
		check_rect(pause_button.get_global_rect(), logical_size, "pause button", viewport_size)
	var back_button: Button = game.get("back_button")
	if back_button == null or not back_button.visible:
		failed = true
		push_error("visible back button is missing at %s" % viewport_size)
	var pause_menu = game.get_node_or_null("PauseMenu")
	if pause_menu == null:
		failed = true
		push_error("pause menu is missing at %s" % viewport_size)
	else:
		game._handle_system_back()
		if not pause_menu.is_open:
			failed = true
			push_error("system Back did not open pause menu")
		game._handle_system_back()
		if pause_menu.is_open:
			failed = true
			push_error("system Back did not close pause menu")
		game._request_return_to_menu()
		if not pause_menu.is_open or not pause_menu._confirm.visible:
			failed = true
			push_error("visible Back control did not request return confirmation")
		pause_menu._cancel_loss()
		pause_menu.close_menu()
		await process_frame
		pause_menu.open_menu()
		await process_frame
		var pause_panel_rect: Rect2 = pause_menu.panel.get_global_rect()
		check_rect(pause_panel_rect, logical_size, "pause panel", viewport_size)

		pause_menu.close_menu()
		await process_frame
	if game.get_node_or_null("TuningPanel") != null:
		failed = true
		push_error("native tuning panel must be absent")
	var vertical_extra := maxf(0.0, logical_size.y / game.camera.zoom.y - game.BASE_VIEWPORT_HEIGHT)
	var expected_top := -ceili(vertical_extra * 0.5)
	var expected_bottom := ceili(game.BASE_VIEWPORT_HEIGHT + vertical_extra * 0.5)
	if game.camera.limit_top != expected_top or game.camera.limit_bottom != expected_bottom:
		failed = true
		push_error("camera bounds do not match %s at %s" % [logical_size, viewport_size])
	var art: Node = game.get_node("WorldArt")
	for layer: Control in [art.background, art.foreground]:
		check_rect(layer.get_global_rect(), logical_size, "background layer", viewport_size)
	game.queue_free()
	await process_frame

func check_rect(rect: Rect2, viewport_size: Vector2, label: String, physical_size: Vector2i) -> void:
	if rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > viewport_size.x + 0.5 or rect.end.y > viewport_size.y + 0.5:
		failed = true
		push_error("%s is outside %s at %s: %s" % [label, viewport_size, physical_size, rect])


func check_rect_matches(rect: Rect2, expected: Rect2, label: String, physical_size: Vector2i) -> void:
	if not rect.position.is_equal_approx(expected.position) or not rect.size.is_equal_approx(expected.size):
		failed = true
		push_error("%s does not match responsive margins at %s: %s != %s" % [label, physical_size, rect, expected])


func check_aspect(physical_size: Vector2i) -> void:
	var logical_size := root.get_visible_rect().size
	var aspect := logical_size.x / logical_size.y
	var expected := clampf(float(physical_size.x) / physical_size.y, 1.0, 16.0 / 6.0)
	if root.get_node("TuningStore").get_value("display_mode") == 0:
		expected = 16.0 / 9.0
	if absf(aspect - expected) > 0.002 or root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP:
		failed = true
		push_error("viewport aspect is not clamped at %s: %s" % [physical_size, logical_size])
	var transform := root.get_final_transform()
	if absf(transform.x.length() - transform.y.length()) > 0.002:
		failed = true
		push_error("viewport is stretched non-uniformly at %s" % physical_size)
	var displayed_size := logical_size * transform.x.length()
	var expected_margin := (Vector2(physical_size) - displayed_size) * 0.5
	if transform.origin.distance_to(expected_margin) > 1.0 or expected_margin.x < -0.5 or expected_margin.y < -0.5:
		failed = true
		push_error("game surface is not centered and contained at %s" % physical_size)



func check_touch_bounds() -> void:
	var joystick = load("res://scripts/touch_input.gd").new()
	root.add_child(joystick)
	var logical_size := root.get_visible_rect().size
	for position in [Vector2(-10, 10), Vector2(10, -10), logical_size + Vector2(10, 10)]:
		var touch := InputEventScreenTouch.new()
		touch.index = 7
		touch.pressed = true
		touch.position = position
		joystick._unhandled_input(touch)
		if joystick._active:
			failed = true
			push_error("letterbox press activated joystick")
	var center := logical_size * 0.5
	joystick._begin(7, center)
	joystick._update(center + Vector2(80, 0), 7)
	joystick._begin(11, center + Vector2(0, 80))
	joystick._update(center + Vector2(0, 0), 11)
	if joystick.vector.x < 0.3 or joystick.vector.y > -0.3:
		failed = true
		push_error("independent touch drags did not combine movement and jump")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = Vector2(-10, -10)
	joystick._unhandled_input(release)
	if not joystick._active or absf(joystick.vector.x) > 0.05 or joystick.vector.y > -0.3:
		failed = true
		push_error("releasing one finger cancelled the other active touch")
	var final_release := InputEventScreenTouch.new()
	final_release.index = 11
	final_release.position = Vector2(-10, -10)
	joystick._unhandled_input(final_release)
	if joystick._active or joystick.vector != Vector2.ZERO:
		failed = true
		push_error("releasing the final finger left touch input stuck")
	joystick.queue_free()
	await process_frame
