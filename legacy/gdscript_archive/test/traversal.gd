extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _needs_jump(player: CharacterBody2D, stage: Dictionary) -> bool:
	var space := player.get_world_2d().direct_space_state
	var feet := player.position + Vector2(0, 24)
	var floor_query := PhysicsRayQueryParameters2D.create(feet + Vector2(22, -8), feet + Vector2(22, 90), 1)
	var obstacle_query := PhysicsRayQueryParameters2D.create(feet + Vector2(0, -25), feet + Vector2(85, -25), 1)
	for platform: Array in stage.platforms:
		var rise: float = feet.y - float(platform[0][1])
		var distance: float = float(platform[0][0]) - player.position.x
		if rise >= 60.0 and rise <= 170.0 and distance >= 90.0 and distance <= 115.0: return true
	return space.intersect_ray(floor_query).is_empty() or not space.intersect_ray(obstacle_query).is_empty()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var store := root.get_node("SaveStore")
	var original: Dictionary = store.data.duplicate(true)
	store.complete_tutorial()
	root.get_node("TuningStore").reset_defaults(false)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	for course in 2:
		var frames := 0
		var jump_frames := 0
		var deaths := 0
		var was_resetting := false
		var max_x := 0.0
		while not game.finished and frames < 12000:
			await physics_frame
			frames += 1
			if game.resetting:
				Input.action_release("move_right")
				Input.action_release("jump")
				if not was_resetting: deaths += 1
				was_resetting = true
				continue
			was_resetting = false
			var player: CharacterBody2D = game.player
			max_x = maxf(max_x, player.position.x)
			if player.position.x >= float(game.stage.goal[0]) - 100.0 and player.position.y < float(game.stage.goal[1]) - 230.0:
				Input.action_release("move_right")
			else:
				Input.action_press("move_right")
			if frames % 20 == 0: player.try_attack()
			if player.is_on_floor() and jump_frames == 0 and _needs_jump(player, game.stage):
				Input.action_press("jump")
				jump_frames = 29
			elif jump_frames > 0:
				jump_frames -= 1
				if jump_frames == 0: Input.action_release("jump")
			if frames % 1200 == 0:
				print("[TRAVERSAL_PROGRESS] stage=%d x=%.1f y=%.1f fish=%d time=%.1f deaths=%d" % [course+1, player.position.x, player.position.y, game.coins, game.time_left, deaths])
		Input.action_release("move_right")
		Input.action_release("jump")
		print("[TRAVERSAL_STAGE] stage=%d frames=%d duration=%.1f fish=%d deaths=%d max_x=%.1f result=%s" % [course+1, frames, frames / 60.0, game.coins, deaths, max_x, str(game.terminal_result)])
		if not game.finished or not game.terminal_result.is_empty() and game.terminal_result.outcome == "defeat":
			failed = true
			break
		if course == 0:
			game.next_stage()
			await process_frame
	store.data = original
	store.save()
	game.queue_free()
	await process_frame
	if not failed: print("[TRAVERSAL_PASS] both authored courses completed with actual movement, jump, yarn and collision events")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180) # Accelerated tests must let the real audio mixer drain.
	await process_frame
	quit(1 if failed else 0)
