extends SceneTree

const GAME_FONT_PATH := "res://assets/template/fonts/ui_regular.tres"
const REQUIRED_FONT_CHARACTERS := "中文游戏开始暂停继续返回分数时间胜利失败AaZz019，。！？：；（）→←↑↓"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Headless defaults to a 64x64 physical window; injected input uses pixels.
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	if not _verify_runtime_font():
		return
	var title_scene := load("res://scenes/title_screen.tscn") as PackedScene
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	if title_scene == null or game_scene == null:
		_fail("required scene failed to load")
		return

	var title := title_scene.instantiate()
	root.add_child(title)
	for i in 3:
		await process_frame
	title.queue_free()
	await process_frame

	var game := game_scene.instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	if not game.is_inside_tree():
		_fail("game scene left the tree")
		return

	var player := get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_fail("player was not created")
		return
	if get_nodes_in_group("enemy").is_empty():
		_fail("platformer world has no enemies")
		return
	if not InputMap.has_action("pause"):
		_fail("pause input action is missing")
		return
	var pause_menu := game.get_node_or_null("PauseMenu")
	var pause_button: Button = game.get("pause_button")
	if pause_menu == null or pause_button == null:
		_fail("pause menu or touch pause button was not created")
		return
	var visual_effects := game.get_node_or_null("VisualEffects")
	if visual_effects == null:
		_fail("visual effects system was not created")
		return
	var effect_samples := [
		{"name": "jump", "method": "spawn_jump_dust"},
		{"name": "land", "method": "spawn_land_dust"},
		{"name": "collect", "method": "spawn_collect_sparkle"},
		{"name": "stomp", "method": "spawn_stomp_impact"},
		{"name": "death", "method": "spawn_death_burst"},
		{"name": "checkpoint", "method": "spawn_checkpoint_burst"},
		{"name": "finish", "method": "spawn_finish_confetti"},
	]
	for sample: Dictionary in effect_samples:
		var effect_name := str(sample["name"])
		var previous_count := int(visual_effects.call("get_spawn_count", effect_name))
		visual_effects.call(str(sample["method"]), player.global_position + Vector2(0, -36))
		var spawned_particles := visual_effects.get_child(-1)
		if not spawned_particles is CPUParticles2D or not spawned_particles.emitting:
			_fail("particle preset did not create an emitting CPUParticles2D: " + effect_name)
			return
		await process_frame
		if int(visual_effects.call("get_spawn_count", effect_name)) != previous_count + 1:
			_fail("particle preset did not record its burst: " + effect_name)
			return
	pause_button.pressed.emit()
	await process_frame
	if not bool(pause_menu.get("is_open")) or not paused:
		_fail("touch pause button did not pause the game")
		return
	pause_menu.call("close_menu")
	await process_frame
	_send_physical_key(KEY_ESCAPE, true)
	await process_frame
	_send_physical_key(KEY_ESCAPE, false)
	if not bool(pause_menu.get("is_open")) or not paused:
		_fail("physical Escape did not open the pause menu")
		return
	_send_physical_key(KEY_ESCAPE, true)
	await process_frame
	_send_physical_key(KEY_ESCAPE, false)
	if bool(pause_menu.get("is_open")) or paused:
		_fail("physical Escape did not resume the game")
		return

	var action_start_x := player.position.x
	Input.action_press("move_right")
	await create_timer(0.35).timeout
	Input.action_release("move_right")
	if player.position.x - action_start_x < 30.0:
		_fail("player did not move on move_right")
		return

	player.velocity = Vector2.ZERO
	await process_frame
	var right_key_start_x := player.position.x
	_send_physical_key(KEY_RIGHT, true)
	await create_timer(0.35).timeout
	_send_physical_key(KEY_RIGHT, false)
	if player.position.x - right_key_start_x < 30.0:
		_fail("physical right arrow did not move the player")
		return

	player.velocity = Vector2.ZERO
	await process_frame
	var left_key_start_x := player.position.x
	_send_physical_key(KEY_LEFT, true)
	await create_timer(0.35).timeout
	_send_physical_key(KEY_LEFT, false)
	if left_key_start_x - player.position.x < 30.0:
		_fail("physical left arrow did not move the player")
		return

	player.velocity = Vector2.ZERO
	for i in 3:
		await process_frame
	var touch_start_x := player.position.x
	var touch_start_y := player.position.y
	var touch_min_y := touch_start_y
	var touch_start := InputEventScreenTouch.new()
	touch_start.index = 0
	touch_start.position = Vector2(120, 600)
	touch_start.pressed = true
	Input.parse_input_event(touch_start)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 0
	touch_drag.position = Vector2(210, 500)
	Input.parse_input_event(touch_drag)
	var touch_timer := create_timer(0.35)
	while touch_timer.time_left > 0.0:
		await process_frame
		touch_min_y = minf(touch_min_y, player.position.y)
	var touch_end := InputEventScreenTouch.new()
	touch_end.index = 0
	touch_end.position = touch_drag.position
	touch_end.pressed = false
	Input.parse_input_event(touch_end)
	if player.position.x - touch_start_x < 30.0:
		_fail("player did not move from touch drag input")
		return
	if touch_min_y > touch_start_y - 10.0:
		_fail("player did not jump from upward touch drag input")
		return

	var entities_script = load("res://scripts/entities.gd")
	var test_wall := StaticBody2D.new()
	test_wall.position = Vector2(520, 540)
	test_wall.collision_layer = 1
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 160)
	wall_shape.shape = wall_rect
	test_wall.add_child(wall_shape)
	game.add_child(test_wall)
	var wall_walker = entities_script.Walker.new()
	wall_walker.position = Vector2(460, 560)
	wall_walker.direction = 1.0
	game.add_child(wall_walker)
	await create_timer(1.0).timeout
	await process_frame
	if not is_instance_valid(wall_walker) or float(wall_walker.direction) >= 0.0:
		_fail("enemy did not reverse direction at a wall")
		return
	wall_walker.queue_free()
	test_wall.queue_free()
	await process_frame

	var edge_walker = entities_script.Walker.new()
	edge_walker.position = Vector2(1270, 560)
	edge_walker.direction = 1.0
	game.add_child(edge_walker)
	await create_timer(0.8).timeout
	await process_frame
	if not is_instance_valid(edge_walker) or float(edge_walker.direction) >= 0.0 or edge_walker.position.y > 700.0:
		_fail("enemy did not reverse direction at a platform edge")
		return
	edge_walker.queue_free()
	await process_frame

	var test_walker = entities_script.Walker.new()
	test_walker.position = Vector2(400, 560)
	game.add_child(test_walker)
	test_walker.set_physics_process(false)
	player.position = Vector2(400, 470)
	player.velocity = Vector2(0, 420)
	await create_timer(0.5).timeout
	await process_frame
	if not bool(player.get("alive")):
		_fail("player died during a valid enemy stomp")
		return
	if is_instance_valid(test_walker) and bool(test_walker.get("alive")):
		_fail("enemy was not stomped")
		return

	var tuning_store := root.get_node_or_null("TuningStore")
	if tuning_store == null:
		_fail("TuningStore autoload was not created")
		return
	var tuning_settings: Array = tuning_store.call("get_settings")
	var tuning_schema_version := int(tuning_store.call("get_schema_version"))
	if tuning_settings.is_empty() or tuning_schema_version <= 0:
		_fail("tuning schema did not load")
		return
	tuning_store.call("reset_defaults", false)
	var jump_apex_height := float(tuning_store.call("get_jump_apex_height"))
	var required_jump_height := float(game.REFERENCE_MAX_PLATFORM_RISE + game.MIN_JUMP_CLEARANCE)
	if jump_apex_height < required_jump_height:
		_fail("default jump cannot clear the reference platform rise with margin")
		return
	var jump_effects_before := int(visual_effects.call("get_spawn_count", "jump"))
	var land_effects_before := int(visual_effects.call("get_spawn_count", "land"))
	var measured_jump_rise := await _measure_full_jump_rise(player)
	if measured_jump_rise < required_jump_height - 4.0:
		_fail("measured full jump does not reach the reference platform route: %.1f < %.1f" % [measured_jump_rise, required_jump_height])
		return
	if int(visual_effects.call("get_spawn_count", "jump")) <= jump_effects_before or int(visual_effects.call("get_spawn_count", "land")) <= land_effects_before:
		_fail("player jump and landing signals did not spawn particles")
		return
	var original_speed := float(tuning_store.call("get_value", "move_speed"))
	tuning_store.call("set_value", "move_speed", original_speed + 20.0)
	if not is_equal_approx(float(tuning_store.call("get_value", "move_speed")), original_speed) or not is_equal_approx(float(tuning_store.call("get_requested_value", "move_speed")), original_speed + 20.0):
		_fail("tuning deferred value did not remain requested until next run")
		return
	tuning_store.call("apply_boundary", "NEXT_RUN")
	if not is_equal_approx(float(tuning_store.call("get_value", "move_speed")), original_speed + 20.0):
		_fail("tuning value did not apply at next run boundary")
		return
	if tuning_store.call("set_value", "move_speed", 10000.0):
		_fail("out-of-range tuning value was not rejected")
		return
	tuning_store.call("set_value", "move_speed", original_speed)
	tuning_store.call("apply_boundary", "NEXT_RUN")
	game.set("time_left", 12.0)
	player.die()
	await create_timer(1.0).timeout
	for i in 3:
		await process_frame
	var respawned_player := get_first_node_in_group("player") as CharacterBody2D
	if respawned_player == null or respawned_player == player or not bool(respawned_player.get("alive")):
		_fail("player did not respawn at the checkpoint")
		return
	if float(game.get("time_left")) > 2.0:
		_fail("death penalty increased the remaining time")
		return

	game.set("time_left", 0.0)
	game.call("_process", 0.0)
	await process_frame
	if not bool(game.get("finished")) or bool(game.get("resetting")):
		_fail("time expiry did not end the level")
		return
	if not is_zero_approx(float(game.get("time_left"))) or respawned_player.is_physics_processing():
		_fail("time expiry left an active player or nonzero timer")
		return

	current_scene = game
	pause_menu.call("open_menu")
	pause_menu.call("_request_main_menu")
	pause_menu.call("_confirm_loss")
	for i in 3:
		await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/title_screen.tscn":
		_fail("pause menu did not return to the title scene")
		return
	print("[SMOKE_PASS] platformer input, particles, pause/menu flow, reachable jump, patrol, stomp, local tuning, respawn, and time-up verified")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(0)


func _verify_runtime_font() -> bool:
	var label := Label.new()
	root.add_child(label)
	var font := label.get_theme_font("font")
	label.free()
	if font.resource_path != GAME_FONT_PATH:
		_fail("dynamic controls must inherit the Nunito UI font with bundled Noto Sans SC fallback")
		return false
	if font == null:
		_fail("Nunito UI font with bundled Noto Sans SC fallback did not load as the project font")
		return false
	if not font is FontVariation or not font.get_font_name().begins_with("Nunito"):
		_fail("project font must keep the Nunito primary family")
		return false
	# Noto Sans SC (FontVariation, matching weight) is the bundled Chinese fallback; every link stays bundled.
	var leaks_system := func(f: Font) -> bool: return (f.base_font if f is FontVariation else f).allow_system_fallback
	if font.base_font.allow_system_fallback or font.fallbacks.is_empty() or font.fallbacks.any(leaks_system):
		_fail("bundled font must disable system fallback for Web parity")
		return false
	for character in REQUIRED_FONT_CHARACTERS:
		if not font.has_char(character.unicode_at(0)):
			_fail("bundled font is missing required glyph U+%04X" % character.unicode_at(0))
			return false
	return true


func _measure_full_jump_rise(player: CharacterBody2D) -> float:
	player.global_position = Vector2(300, 500)
	player.velocity = Vector2.ZERO
	var settle_timer := create_timer(1.0)
	while settle_timer.time_left > 0.0 and not player.is_on_floor():
		await process_frame
	if not player.is_on_floor():
		return 0.0
	var start_y := player.global_position.y
	var minimum_y := start_y
	Input.action_press("jump")
	var jump_timer := create_timer(1.2)
	while jump_timer.time_left > 0.0:
		await process_frame
		minimum_y = minf(minimum_y, player.global_position.y)
	Input.action_release("jump")
	return start_y - minimum_y


func _send_physical_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _fail(message: String) -> void:
	push_error("[SMOKE_FAIL] " + message)
	quit(1)
