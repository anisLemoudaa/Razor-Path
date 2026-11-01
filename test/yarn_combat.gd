extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	for enemy in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await process_frame
	var player = game.player
	player.position = Vector2(300, 596)
	for i in 5:
		await physics_frame
	player.facing = 1.0
	_send_key(KEY_J, true)
	for i in 3:
		await physics_frame
	_send_key(KEY_J, false)
	var balls := get_nodes_in_group("yarn_projectile")
	_check(balls.size() == 1, "J must fire one yarn ball")
	_check(not player.try_attack(), "cooldown permits immediate duplicate shot")
	if balls.is_empty():
		quit(1)
		return
	var ball = balls[0]
	_check(ball.direction > 0.0, "right facing does not shoot right")
	paused = true
	var position_before: Vector2 = ball.position
	var lifetime_before: float = ball.lifetime
	await create_timer(0.08).timeout
	_check(ball.position == position_before and is_equal_approx(ball.lifetime, lifetime_before), "paused projectile keeps moving or expiring")
	_check(not player.try_attack(), "paused player can attack")
	paused = false
	await _clear_balls()
	player.facing = -1.0
	player.attack_cooldown_left = 0.0
	_send_key(KEY_X, true)
	for i in 3:
		await physics_frame
	_send_key(KEY_X, false)
	balls = get_nodes_in_group("yarn_projectile")
	_check(balls.size() == 1 and balls[0].direction < 0.0, "X must shoot left when facing left")
	await _clear_balls()
	player.facing = 1.0
	player.attack_cooldown_left = 0.0
	game.attack_button.pressed.emit()
	_check(get_nodes_in_group("yarn_projectile").size() == 1, "touch attack button is not wired")
	await _clear_balls()
	# Static fixture enemy isolates swept projectile collision from enemy AI.
	var robot = load("res://scripts/entities.gd").Walker.new()
	robot.position = Vector2(430, 596)
	game.add_child(robot)
	robot.set_physics_process(false)
	player.attack_cooldown_left = 0.0
	var score_before: int = game.score
	player.try_attack()
	await create_timer(0.25).timeout
	_check(not is_instance_valid(robot) or not robot.alive, "yarn did not knock out robot")
	_check(game.score == score_before + 250, "projectile hit must score exactly once")
	await create_timer(0.15).timeout
	_check(game.score == score_before + 250, "dead robot can score twice")
	await _clear_balls()
	var wall := StaticBody2D.new()
	wall.position = Vector2(365, 596)
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 100)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	robot = load("res://scripts/entities.gd").Walker.new()
	robot.position = Vector2(430, 596)
	game.add_child(robot)
	robot.set_physics_process(false)
	await physics_frame
	player.attack_cooldown_left = 0.0
	player.try_attack()
	await create_timer(0.3).timeout
	_check(robot.alive, "yarn passes through a wall")
	_check(get_nodes_in_group("yarn_projectile").is_empty(), "wall hit leaves a projectile alive")
	wall.queue_free()
	robot.queue_free()
	await process_frame
	var shot = load("res://scripts/yarn_ball.gd").new()
	shot.position = Vector2(300, 100)
	shot.lifetime = 0.05
	game.add_child(shot)
	await create_timer(0.1).timeout
	_check(not is_instance_valid(shot), "missed projectile does not expire")
	var arc = load("res://scripts/yarn_ball.gd").new()
	arc.position = Vector2(300, 100)
	game.add_child(arc)
	await create_timer(0.15).timeout
	_check(arc.position.y < 100 and arc.vertical_speed < 0, "yarn must initially rise")
	await create_timer(0.5).timeout
	_check(arc.position.y > 100 and arc.vertical_speed > 0, "yarn must fall after the apex")
	await _clear_balls()
	for i in 30:
		game._on_shot_requested(Vector2(300, 100), 1.0)
	_check(get_nodes_in_group("yarn_projectile").size() == game.MAX_YARN_BALLS, "projectile cap is not enforced")
	player.alive = false
	player.attack_cooldown_left = 0.0
	_check(not player.try_attack(), "dead cat can shoot")
	game.queue_free()
	await process_frame
	_check(get_nodes_in_group("yarn_projectile").is_empty(), "scene teardown leaks projectiles")
	if not failed:
		print("[YARN_PASS] J/X, touch, facing, cooldown, pause, hit, wall, lifetime and cleanup")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(1 if failed else 0)


func _clear_balls() -> void:
	for ball in get_nodes_in_group("yarn_projectile"):
		ball.queue_free()
	await process_frame


func _send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[YARN_FAIL] " + message)
