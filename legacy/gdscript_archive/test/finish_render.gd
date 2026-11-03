extends SceneTree

var failed := false
var entities: Script
var output := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[FINISH_RENDER_FAIL] use a real renderer or Xvfb, not headless")
		quit(1)
		return
	entities = load("res://scripts/entities.gd")
	output = OS.get_environment("GAME_CAPTURE_DIR")
	if output.is_empty():
		output = "user://terrain-captures"
	DirAccess.make_dir_recursive_absolute(output)
	var padded := Image.create(80, 96, false, Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT)
	padded.fill_rect(Rect2i(13, 7, 32, 32), Color.WHITE)
	var opaque := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	var tall := Image.create(96, 112, false, Image.FORMAT_RGBA8)
	tall.fill(Color.TRANSPARENT)
	tall.fill_rect(Rect2i(17, 9, 24, 72), Color.WHITE)
	var tuning := root.get_node("TuningStore")
	var old_speed: float = tuning.get_value("enemy_speed")
	tuning.set_value("enemy_speed", 0.0)
	for floor_top in [180.0, 120.0]:
		for sample in [
			{"name": "robot", "texture": entities.Walker.TEXTURE},
			{"name": "opaque", "texture": ImageTexture.create_from_image(opaque)},
			{"name": "padded", "texture": ImageTexture.create_from_image(padded)},
			{"name": "tall", "texture": ImageTexture.create_from_image(tall)},
		]:
			await _check_enemy(sample.name, sample.texture, floor_top)
	await _check_frame_pivot()
	tuning.set_value("enemy_speed", old_speed)
	if not failed:
		print("[FINISH_RENDER_PASS] visible enemy pixels flush with ground/platform across alpha padding, aspect ratios, animation and stomp; authored torso pivot stable")
	quit(1 if failed else 0)


func _check_enemy(label: String, texture: Texture2D, floor_top: float) -> void:
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
	var enemy = entities.Walker.new()
	enemy.sprite_texture = texture
	enemy.position = Vector2(120, floor_top - 65.0)
	viewport.add_child(enemy)
	for frame in 45:
		await physics_frame
	_check(enemy.is_on_floor(), "render fixture enemy did not reach floor")
	enemy.set_physics_process(false)
	for phase in [0.0, PI / 24.0, PI / 8.0]:
		enemy.t = phase
		enemy.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		_check_pixels(viewport.get_texture().get_image(), floor_top, label + " phase " + str(phase))
	var normal := viewport.get_texture().get_image()
	_check(normal.save_png(output.path_join("enemy-%s-%d.png" % [label, int(floor_top)])) == OK, "cannot save normal enemy capture")
	enemy.stomp()
	await create_timer(0.14).timeout
	await RenderingServer.frame_post_draw
	var squashed := viewport.get_texture().get_image()
	_check_pixels(squashed, floor_top, label + " stomp")
	_check(squashed.get_used_rect().size.y < normal.get_used_rect().size.y * 0.3, "rendered stomp did not squash")
	_check(squashed.save_png(output.path_join("enemy-%s-%d-stomp.png" % [label, int(floor_top)])) == OK, "cannot save stomp capture")
	viewport.queue_free()
	await process_frame


func _check_frame_pivot() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 240)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var enemy = entities.Walker.new()
	enemy.position = Vector2(120, 150)
	viewport.add_child(enemy)
	enemy.set_physics_process(false)
	var first_torso := Rect2i()
	for arm_x in [8, 36]:
		var frame := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		frame.fill(Color.TRANSPARENT)
		frame.fill_rect(Rect2i(28, 20, 8, 24), Color.WHITE)
		frame.fill_rect(Rect2i(arm_x, 24, 20, 4), Color.RED)
		enemy.sprite_texture = ImageTexture.create_from_image(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var minimum := Vector2i(240, 240)
		var maximum := Vector2i(-1, -1)
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.a > 0.5 and pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9:
					minimum = minimum.min(Vector2i(x, y))
					maximum = maximum.max(Vector2i(x, y))
		var torso := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
		_check(torso.has_area(), "asymmetric frame torso is invisible")
		_check(absf(torso.get_center().x - 120.0) <= 1.0, "authored torso no longer meets the horizontal pivot")
		if first_torso.has_area():
			_check(torso == first_torso, "visible torso shifts when an arm changes alpha bounds")
		first_torso = torso
		_check(image.save_png(output.path_join("enemy-asymmetric-%d.png" % arm_x)) == OK, "cannot save frame pivot capture")
	viewport.queue_free()
	await process_frame


func _check_pixels(image: Image, floor_top: float, label: String) -> void:
	_check(image != null and not image.is_empty(), "missing image for " + label)
	if image == null or image.is_empty():
		return
	# This measures actual alpha, independently of the draw-rectangle calculation.
	var visible := image.get_used_rect()
	_check(visible.has_area(), "enemy invisible for " + label)
	_check(absf(float(visible.end.y) - floor_top) <= 1.0, "visible feet not flush for %s: bottom %s floor %s" % [label, visible.end.y, floor_top])
	var buried := 0
	for y in range(int(floor_top), image.get_height()):
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				buried += 1
	_check(buried == 0, "enemy pixels extend below ground for " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[FINISH_RENDER_FAIL] " + message)
