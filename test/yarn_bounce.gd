extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor := StaticBody2D.new()
	floor.position = Vector2(1500, 330)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3000, 60)
	collision.shape = rectangle
	floor.add_child(collision)
	arena.add_child(floor)
	var ball = load("res://scripts/yarn_ball.gd").new()
	ball.position = Vector2(200, 210)
	ball.lifetime = 1.8
	var counts: Array[int] = []
	ball.bounced.connect(func(count: int, _position: Vector2): counts.append(count))
	arena.add_child(ball)
	await create_timer(3.6).timeout
	_check(counts == [1, 2, 3], "missed yarn must bounce exactly three times")
	_check(not is_instance_valid(ball), "yarn did not disappear after third bounce landed")
	# A rebound remains lethal; landing is not equivalent to spending the shot.
	ball = load("res://scripts/yarn_ball.gd").new()
	ball.position = Vector2(200, 291)
	ball.launch_speed = 0.0
	ball.gravity = 650.0
	var hits := [0]
	ball.enemy_hit.connect(func(_position: Vector2): hits[0] += 1)
	arena.add_child(ball)
	await create_timer(0.08).timeout
	_check(is_instance_valid(ball) and ball.bounce_count == 1, "ground contact did not rebound")
	var robot = load("res://scripts/entities.gd").Walker.new()
	robot.position = Vector2(ball.position.x + 60, 281)
	arena.add_child(robot)
	robot.set_physics_process(false)
	await create_timer(0.25).timeout
	_check(hits[0] == 1, "bounced yarn did not hit exactly once")
	_check(not is_instance_valid(ball), "hit yarn was not consumed")
	arena.queue_free()
	await process_frame
	if not failed:
		print("[YARN_BOUNCE_PASS] exactly three visible bounces, cleanup and rebound hits")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[YARN_BOUNCE_FAIL] " + message)
