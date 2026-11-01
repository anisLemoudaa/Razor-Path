extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for enemy_first in [false, true]:
		for offset in [-30.0, 0.0, 30.0]:
			await _case(offset, enemy_first, false, false)
		await _case(0.0, enemy_first, true, false)
		await _case(0.0, enemy_first, false, true)
	if not failed:
		print("[STOMP_PASS] moving robots, edge landings, node order, adjacent robots and side damage")
	quit(1 if failed else 0)


func _case(offset: float, enemy_first: bool, pair: bool, side: bool) -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor := StaticBody2D.new()
	floor.position = Vector2(500, 330)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 60)
	shape.shape = rectangle
	floor.add_child(shape)
	arena.add_child(floor)
	var player = load("res://scripts/player.gd").new()
	player.add_to_group("player")
	player.position = Vector2(500 + offset, 215) if not side else Vector2(440, 276)
	player.velocity.y = 300.0 if not side else 0.0
	var robot = load("res://scripts/entities.gd").Walker.new()
	robot.position = Vector2(500, 281)
	robot.direction = -1.0 if offset <= 0 else 1.0
	if enemy_first:
		arena.add_child(robot)
		arena.add_child(player)
	else:
		arena.add_child(player)
		arena.add_child(robot)
	var hit_count := [0]
	player.stomped.connect(func(): hit_count[0] += 1)
	if pair:
		robot.position.x = 484
		robot.direction = 1
		var second = load("res://scripts/entities.gd").Walker.new()
		second.position = Vector2(516, 281)
		second.direction = -1
		arena.add_child(second)
	if side:
		Input.action_press("move_right")
	await create_timer(0.32).timeout
	Input.action_release("move_right")
	if side:
		_check(not player.alive, "side contact must still damage cat")
	else:
		_check(player.alive, "cat died after top contact (offset %s order %s pair %s)" % [offset, enemy_first, pair])
		_check(hit_count[0] >= 1, "top contact did not stomp")
	arena.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[STOMP_FAIL] " + message)
