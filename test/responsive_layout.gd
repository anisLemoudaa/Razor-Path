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

func check_title(viewport_size: Vector2i) -> void:
	var title = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	var content: Control = title.get_node("ResponsiveCenter/Content")
	check_rect(content.get_global_rect(), title.get_viewport_rect().size, "title", viewport_size)
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
	check_rect(game.attack_button.get_global_rect(), logical_size, "attack button", viewport_size)
	var pixel_scale: float = root.get_final_transform().x.length()
	if game.attack_button.size.y * pixel_scale < 40 or game.score_label.get_theme_font_size("font_size") * pixel_scale < 14:
		failed = true
		push_error("physical mobile HUD text or target too small")
	var pause_button: Button = game.get("pause_button")
	if pause_button == null:
		failed = true
		push_error("pause button is missing at %s" % viewport_size)
	else:
		check_rect(pause_button.get_global_rect(), logical_size, "pause button", viewport_size)
	var pause_menu = game.get_node_or_null("PauseMenu")
	if pause_menu == null:
		failed = true
		push_error("pause menu is missing at %s" % viewport_size)
	else:
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
	for sprite in game.get_node("WorldArt").layer_sprites:
		var covered_height: float = sprite.texture.get_height() * sprite.scale.y
		if covered_height + 0.5 < logical_size.y:
			failed = true
			push_error("background does not cover %s at %s" % [logical_size, viewport_size])
	var sky: Sprite2D = game.get_node("WorldArt").layer_sprites[0]
	var sky_rect := sky.get_global_transform_with_canvas() * sky.get_rect()
	if sky_rect.position.y > 0.5 or sky_rect.end.y < logical_size.y - 0.5:
		failed = true
		push_error("sky does not cover the actual camera viewport at %s" % viewport_size)
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
	joystick._begin(7, logical_size * 0.5)
	joystick._update(logical_size * 0.5 + Vector2(80, -80))
	if joystick.vector.x < 0.3 or joystick.vector.y > -0.3:
		failed = true
		push_error("in-viewport touch drag did not move/jump")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = Vector2(-10, -10)
	joystick._unhandled_input(release)
	if joystick._active or joystick.vector != Vector2.ZERO:
		failed = true
		push_error("releasing in the letterbox left joystick stuck")
	joystick.queue_free()
	await process_frame
