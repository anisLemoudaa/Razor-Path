extends CharacterBody2D

signal enemy_hit(position: Vector2)
signal bounced(count: int, position: Vector2)

const MAX_BOUNCES := 3
const TEXTURE = preload("res://assets/template/cat/yarn.webp")
var direction := 1.0
var speed := 620.0
var lifetime := 1.8
var gravity := 650.0
var launch_speed := 160.0
var vertical_speed := 0.0
var spent := false
var spin := 0.0
var bounce_count := 0


func _ready() -> void:
	vertical_speed = -launch_speed
	add_to_group("yarn_projectile")
	collision_layer = 0
	collision_mask = 1 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if spent:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	spin += direction * delta * 12.0
	# Swept motion catches thin walls and enemies even at higher Tweak speeds.
	var travel_y := vertical_speed * delta + 0.5 * gravity * delta * delta
	vertical_speed += gravity * delta
	var hit := move_and_collide(Vector2(direction * speed * delta, travel_y))
	if hit != null:
		var body := hit.get_collider()
		if body != null and body.is_in_group("enemy") and bool(body.get("alive")):
			body.stomp()
			enemy_hit.emit(global_position)
			_finish()
		elif hit.get_normal().y < -0.65 and vertical_speed > 0.0:
			if bounce_count >= MAX_BOUNCES:
				_finish()
			else:
				bounce_count += 1
				vertical_speed = -maxf(90.0, vertical_speed * 0.8)
				speed *= 0.8
				position += hit.get_normal() * 0.5
				# Give each of the three bounded hops time to land, even with a short TTL.
				lifetime = maxf(lifetime, 2.0 * absf(vertical_speed) / maxf(gravity, 1.0) + 0.3)
				bounced.emit(bounce_count, global_position)
		else:
			_finish()
	queue_redraw()


func _finish() -> void:
	if spent:
		return
	spent = true
	collision_mask = 0
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, spin)
	draw_texture_rect(TEXTURE, Rect2(-14, -14, 28, 28), false)
