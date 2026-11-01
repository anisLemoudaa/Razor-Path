extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[TERRAIN_RENDER_FAIL] use a real renderer or Xvfb, not headless")
		quit(1)
		return
	root.get_node("TuningStore").set_value("display_mode", 1)
	var output := OS.get_environment("GAME_CAPTURE_DIR")
	if output.is_empty():
		output = "user://terrain-captures"
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.collision_layer = 0
	game.camera.position_smoothing_enabled = false
	for sample in [
		{"name": "square", "size": Vector2i(720, 720), "position": Vector2(2130, 366)},
		{"name": "landscape", "size": Vector2i(1280, 720), "position": Vector2(3160, 250)},
		{"name": "square-zoom-out", "size": Vector2i(720, 720), "position": Vector2(2130, 366), "zoom": 0.65},
		{"name": "wide-zoom-out", "size": Vector2i(1536, 576), "position": Vector2(2130, 366), "zoom": 0.65},
		{"name": "square-zoom-in", "size": Vector2i(720, 720), "position": Vector2(2130, 366), "zoom": 1.5},
		{"name": "wide", "size": Vector2i(1536, 576), "position": Vector2(2130, 366)},
	]:
		root.size = sample.size
		game.camera.zoom = Vector2.ONE * float(sample.get("zoom", 1.0))
		game.update_camera_bounds()
		game.player.position = sample.position
		for i in 8:
			await process_frame
		game.camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "viewport image is missing")
		# The reported gap used the default grey clear color across the upper view.
		var grey := 0
		for y in range(image.get_height() / 6, image.get_height() / 2, 3):
			for x in range(0, image.get_width(), 3):
				var pixel := image.get_pixel(x, y)
				if absf(pixel.r - 0.3) < 0.01 and absf(pixel.g - 0.3) < 0.01 and absf(pixel.b - 0.3) < 0.01:
					grey += 1
		_check(grey == 0, "clear-color gap visible in " + sample.name)
		_check(image.save_png(output.path_join("terrain-" + sample.name + ".png")) == OK, "cannot save capture")
	game.queue_free()
	await process_frame
	# Render partial tiles and row/column joins with an intentionally rounded perimeter.
	for size in [Vector2i(355, 34), Vector2i(355, 195), Vector2i(58, 275)]:
		await _check_surface(size, output)
	await _check_blocks(output)
	if not failed:
		print("[TERRAIN_RENDER_PASS] square/landscape/wide backgrounds; rounded surfaces/boxes with no interior seams or overflow")
	quit(1 if failed else 0)


func _check_surface(size: Vector2i, output: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = size + Vector2i(60, 60)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(viewport.size)
	backdrop.color = Color.MAGENTA
	viewport.add_child(backdrop)
	var bricks = load("res://scripts/brick_surface.gd").new()
	bricks.position = Vector2(30, 30)
	bricks.surface_size = Vector2(size)
	viewport.add_child(bricks)
	await process_frame
	await RenderingServer.frame_post_draw
	var tile_image := viewport.get_texture().get_image()
	var bounds := Rect2i(Vector2i(30, 30), size)
	var gaps := 0
	var overflow := 0
	for y in viewport.size.y:
		for x in viewport.size.x:
			var is_backdrop := tile_image.get_pixel(x, y).is_equal_approx(Color.MAGENTA)
			if bounds.has_point(Vector2i(x, y)):
				# Only the four corner squares may contain deliberate cutouts.
				var local := Vector2i(x, y) - bounds.position
				var corner := (local.x < 8 or local.x >= size.x - 8) and (local.y < 8 or local.y >= size.y - 8)
				if is_backdrop and not corner:
					gaps += 1
			elif not is_backdrop:
				overflow += 1
	_check(gaps == 0, "brick tiling has transparent seams")
	_check(overflow == 0, "bricks draw beyond platform bounds")
	for point in [bounds.position, bounds.position + Vector2i(size.x - 1, 0), bounds.end - Vector2i.ONE, bounds.position + Vector2i(0, size.y - 1)]:
		_check(tile_image.get_pixelv(point).is_equal_approx(Color.MAGENTA), "surface still has a sharp opaque corner")
	_check(tile_image.save_png(output.path_join("finished-terrain-%dx%d.png" % [size.x, size.y])) == OK, "cannot save terrain finish capture")
	viewport.queue_free()
	await process_frame


func _check_blocks(output: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 100)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(viewport.size)
	backdrop.color = Color.MAGENTA
	viewport.add_child(backdrop)
	var blocks: Array = []
	for index in 3:
		var block = load("res://scripts/entities.gd").QuestionBlock.new()
		block.position = Vector2(40 + index * 80, 55)
		block.active = index == 0
		block.bump_offset = -10.0 if index == 2 else 0.0
		viewport.add_child(block)
		blocks.append(block)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	for block in blocks:
		var center: Vector2 = block.position + Vector2(0, block.bump_offset)
		_check(not image.get_pixelv(Vector2i(center)).is_equal_approx(Color.MAGENTA), "finished box texture is missing")
		for offset in [Vector2i(-26, -26), Vector2i(25, -26), Vector2i(-26, 25), Vector2i(25, 25)]:
			_check(image.get_pixelv(Vector2i(center) + offset).is_equal_approx(Color.MAGENTA), "active/used/bumped box still has a sharp corner")
	_check(image.save_png(output.path_join("finished-boxes.png")) == OK, "cannot save box finish capture")
	viewport.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[TERRAIN_RENDER_FAIL] " + message)
