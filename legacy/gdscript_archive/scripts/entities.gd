extends Node

class Coin:
	extends Area2D
	signal collected(position: Vector2)
	var consumed := false
	var t := 0.0
	var base_y := 0.0
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		base_y = position.y
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14
		shape.shape = circle
		add_child(shape)
		body_entered.connect(_on_body)
		queue_redraw()
	func _process(delta: float) -> void:
		t += delta
		position.y = base_y + sin(t * 4.0) * 4.0
		queue_redraw()
	func _on_body(body: Node) -> void:
		if body.is_in_group("player") and body.alive and not consumed:
			consumed = true
			collected.emit(global_position)
			queue_free()
	func _draw() -> void:
		var pulse := 1.0 + sin(t * 5.0) * 0.08
		draw_circle(Vector2.ZERO, 14.0 * pulse, Color(0.86, 0.62, 0.2, 0.16))
		draw_circle(Vector2.ZERO, 9.0 * pulse, Color("#e0b13e"))
		draw_arc(Vector2.ZERO, 9.0 * pulse, 0, TAU, 24, Color("#fff0b0"), 2.0, true)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color("#8d6112"), 2.0, true)

class Walker:
	extends CharacterBody2D
	const HITBOX_SIZE := Vector2(52, 26)
	const HITBOX_OFFSET := Vector2(0, 6)
	var alive := true
	var t := 0.0
	var direction := -1.0
	var floor_probe: RayCast2D
	var visual_scale := Vector2.ONE:
		set(value):
			visual_scale = value
			queue_redraw()
	func _ready() -> void:
		add_to_group("enemy")
		collision_layer = 4
		collision_mask = 1
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = HITBOX_SIZE
		shape.shape = rect
		shape.position = HITBOX_OFFSET
		add_child(shape)
		floor_probe = RayCast2D.new()
		floor_probe.collision_mask = 1
		floor_probe.enabled = true
		floor_probe.target_position = Vector2(direction * 32.0, 42.0)
		add_child(floor_probe)
		velocity.x = direction * TuningStore.get_value("enemy_speed")
		queue_redraw()
	func _physics_process(delta: float) -> void:
		if not alive:
			return
		t += delta
		velocity.x = direction * TuningStore.get_value("enemy_speed")
		if not is_on_floor():
			velocity.y += TuningStore.get_value("enemy_gravity") * delta
		else:
			floor_probe.target_position.x = direction * 32.0
			floor_probe.force_raycast_update()
			if not floor_probe.is_colliding():
				direction *= -1.0
				velocity.x = direction * TuningStore.get_value("enemy_speed")
		move_and_slide()
		if is_on_wall():
			direction *= -1.0
		if global_position.y > 900.0:
			queue_free()
		queue_redraw()
	func stomp_top_y() -> float:
		return global_position.y + HITBOX_OFFSET.y - HITBOX_SIZE.y * 0.5
	func stomp() -> void:
		if not alive:
			return
		alive = false
		collision_layer = 0
		collision_mask = 0
		var tween := create_tween()
		tween.tween_property(self, "visual_scale", Vector2(1.3, 0.18), 0.12)
		tween.tween_interval(0.18)
		tween.tween_callback(queue_free)
	func _draw() -> void:
		draw_set_transform(Vector2(0, sin(t * 8.0) * 1.5), 0.0, visual_scale)
		var body := PackedVector2Array([Vector2(-22, 8), Vector2(-16, -8), Vector2(0, -16), Vector2(16, -8), Vector2(22, 8), Vector2(0, 15)])
		draw_colored_polygon(body, Color("#120d20"))
		draw_polyline(PackedVector2Array([Vector2(-22, 8), Vector2(-16, -8), Vector2(0, -16), Vector2(16, -8), Vector2(22, 8)]), Color("#ff3b3b"), 2.5, true)
		draw_line(Vector2(-7, -2), Vector2(7, -2), Color("#ff7b53"), 3.0, true)
		draw_circle(Vector2(0, -2), 2.2, Color("#fff0b0"))
		for x in [-15.0, 0.0, 15.0]:
			draw_line(Vector2(x, 9), Vector2(x + (4.0 if x >= 0 else -4.0), 16), Color("#e0b13e"), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

class QuestionBlock:
	extends StaticBody2D
	signal activated(position: Vector2)
	var active := true
	var bump_offset := 0.0:
		set(value):
			bump_offset = value
			queue_redraw()
	func _ready() -> void:
		add_to_group("question_block")
		collision_layer = 1
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(52, 52)
		shape.shape = rect
		add_child(shape)
		queue_redraw()
	func activate() -> void:
		if not active:
			return
		active = false
		activated.emit(global_position - Vector2(0, 54))
		var tween := create_tween()
		tween.tween_property(self, "bump_offset", -10.0, 0.08)
		tween.tween_property(self, "bump_offset", 0.0, 0.1)
		queue_redraw()
	func _draw() -> void:
		draw_set_transform(Vector2(0, bump_offset))
		var fill := Color("#211736") if active else Color("#171126")
		draw_style_box(_box(fill, Color("#d4af37")), Rect2(-26, -26, 52, 52))
		draw_line(Vector2(-9, 0), Vector2(9, 0), Color("#fff0b0"), 3.0, true)
		draw_line(Vector2(0, -9), Vector2(0, 9), Color("#fff0b0"), 3.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	func _box(fill: Color, edge: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = edge
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		return box

class GoalFlag:
	extends Area2D
	signal reached
	var t := 0.0
	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(70, 300)
		shape.shape = rect
		shape.position = Vector2(0, -120)
		add_child(shape)
		body_entered.connect(_on_body)
		queue_redraw()
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _on_body(body: Node) -> void:
		if body.is_in_group("player") and body.alive:
			reached.emit()
	func _draw() -> void:
		draw_line(Vector2(0, 0), Vector2(0, -290), Color("#fff0b0"), 5.0, true)
		draw_circle(Vector2(0, -294), 10, Color("#e0b13e"))
		var wave := sin(t * 4.0) * 4.0
		var flag := PackedVector2Array([Vector2(4, -270), Vector2(76, -250 + wave), Vector2(4, -216)])
		draw_colored_polygon(flag, Color("#d4af37"))
		draw_polyline(flag, Color("#fff0b0"), 2.0, true)
