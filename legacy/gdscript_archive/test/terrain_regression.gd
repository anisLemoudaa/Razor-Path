extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(900, 900)
	await process_frame
	await process_frame
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await process_frame
	var player = game.player
	player.set_physics_process(false)
	game.set_process(false)
	var player_shape: CapsuleShape2D = player.get_child(0).shape
	var pairs: Array = []
	for block in get_nodes_in_group("question_block"):
		var block_bottom: float = block.position.y + 26.0
		var support_top := INF
		for body in game.get_children():
			if not body is StaticBody2D or body == block or body.is_in_group("question_block"):
				continue
			var collision := body.get_child(0) as CollisionShape2D
			if collision == null or not collision.shape is RectangleShape2D:
				continue
			var size: Vector2 = collision.shape.size
			var rect := Rect2(body.position - size * 0.5, size)
			if block.position.x >= rect.position.x and block.position.x <= rect.end.x and rect.position.y > block_bottom:
				support_top = minf(support_top, rect.position.y)
		_check(support_top < INF, "question block has no supporting surface")
		_check(support_top - block_bottom >= player_shape.height + 16.0, "box corridor is shorter than player plus clearance")
		pairs.append([block, support_top])
		var before: Vector2 = block.position
		block.activate()
		await create_timer(0.09).timeout
		_check(block.position.is_equal_approx(before), "box bump moves its collider into player")
		await create_timer(0.12).timeout
	# Move through every box corridor in both directions using real physics.
	for pair in pairs:
		var block: StaticBody2D = pair[0]
		var top: float = pair[1]
		for direction in [-1.0, 1.0]:
			player.position = Vector2(block.position.x - direction * 75.0, top - 26.0)
			player.velocity = Vector2.ZERO
			player.set_physics_process(true)
			var action := "move_right" if direction > 0 else "move_left"
			Input.action_press(action)
			await create_timer(0.6).timeout
			Input.action_release(action)
			player.set_physics_process(false)
			_check((player.position.x - block.position.x) * direction > 35.0, "player cannot cross box corridor")
	# A height-only check misses camera-relative gaps; check transformed bounds.
	for size in [Vector2i(900, 900), Vector2i(1280, 720), Vector2i(1536, 576)]:
		root.size = size
		await process_frame
		await process_frame
		game.camera.position_smoothing_enabled = false
		for point in [Vector2(160, 540), Vector2(2130, 366), Vector2(3160, 270), Vector2(7560, 540)]:
			player.position = point
			game.camera.force_update_scroll()
			for i in 4:
				await process_frame
			var sky: Sprite2D = game.get_node("WorldArt").layer_sprites[0]
			var screen_rect := sky.get_global_transform_with_canvas() * sky.get_rect()
			var height := root.get_visible_rect().size.y
			_check(screen_rect.position.y <= 0.5 and screen_rect.end.y >= height - 0.5, "sky leaves a screen-space gap after camera move/resize")
	game.queue_free()
	await process_frame
	if not failed:
		print("[TERRAIN_PASS] box clearance, bidirectional passage, stable colliders and screen-space sky coverage")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[TERRAIN_FAIL] " + message)
