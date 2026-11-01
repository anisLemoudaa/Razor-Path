extends SceneTree

var player_script: Script
var failed := false
var output := ""
var samples := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	player_script = load("res://scripts/player.gd")
	if DisplayServer.get_name() == "headless":
		push_error("[PLAYER_GROUNDING_RENDER_FAIL] use a real renderer or Xvfb, not headless")
		quit(1)
		return
	output = OS.get_environment("GAME_CAPTURE_DIR")
	if output.is_empty():
		output = "user://grounding-captures"
	DirAccess.make_dir_recursive_absolute(output)
	for floor_top in [180.0, 120.0]:
		await _check_player(floor_top)
	if not failed:
		print("[PLAYER_GROUNDING_RENDER_PASS] %d rendered samples: all player frames, facings, recoil/phases, ground/platform and padded replacements touch support" % samples)
	quit(1 if failed else 0)


func _check_player(floor_top: float) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 240)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var floor := StaticBody2D.new()
	floor.position = Vector2(120, floor_top + 20.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240, 40)
	collision.shape = shape
	floor.add_child(collision)
	viewport.add_child(floor)
	var player = player_script.new()
	player.position = Vector2(120, floor_top - 75.0)
	viewport.add_child(player)
	for frame in 45:
		await physics_frame
	_check(player.is_on_floor(), "player did not reach support")
	player.set_physics_process(false)
	for facing in [-1.0, 1.0]:
		player.facing = facing
		for recoil in [0.0, 0.12]:
			player.shot_flash = recoil
			player.velocity.x = 0.0
			await _sample(viewport, player, floor_top, "idle-facing-%d-recoil-%s" % [int(facing), str(recoil)], true)
			player.velocity.x = 160.0
			for index in player_script.RUN_FRAMES.size():
				for cycle in [0.0, 1.5, 3.0]:
					player.anim_time = (float(index) + 0.1) / 12.0 + cycle
					_check(player.current_sprite_texture() == player_script.RUN_FRAMES[index], "fixture did not select real run frame")
					var label := "run-%02d-facing-%d-cycle-%s-recoil-%s" % [index, int(facing), str(cycle), str(recoil)]
					await _sample(viewport, player, floor_top, label, cycle == 0.0 and recoil == 0.0 and index in [0, 9, 17])
		player.velocity.x = 0.0
		player.shot_flash = 0.0
		for bottom in [35, 70]:
			var image := Image.create(96, 112, false, Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			image.fill_rect(Rect2i(41, 7, 14, bottom - 7), Color.WHITE)
			player.idle_texture = ImageTexture.create_from_image(image)
			await _sample(viewport, player, floor_top, "padded-%d-facing-%d" % [bottom, int(facing)], true)
		var opaque := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		opaque.fill(Color.WHITE)
		player.idle_texture = ImageTexture.create_from_image(opaque)
		await _sample(viewport, player, floor_top, "opaque-facing-%d" % int(facing), true)
		player.idle_texture = player_script.HERO_TEXTURE
	viewport.queue_free()
	await process_frame


func _sample(viewport: SubViewport, player: CharacterBody2D, floor_top: float, label: String, capture: bool) -> void:
	player.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	# Measure actual rendered alpha independently of the anchor/helper geometry.
	var visible := image.get_used_rect()
	_check(visible.has_area(), "invisible player " + label)
	_check(absf(float(visible.end.y) - floor_top) <= 1.0, "floating feet %s: alpha bottom %s, support %s" % [label, visible.end.y, floor_top])
	var buried := 0
	for y in range(int(floor_top), image.get_height()):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				buried += 1
	_check(buried == 0, "player pixels below support " + label)
	samples += 1
	if capture:
		_check(image.save_png(output.path_join("player-%d-%s.png" % [int(floor_top), label])) == OK, "cannot save player capture")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[PLAYER_GROUNDING_RENDER_FAIL] " + message)
