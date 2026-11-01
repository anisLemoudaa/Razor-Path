extends SceneTree

const FINISH = preload("res://scripts/surface_finish.gd")
var failed := false
var entities: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	entities = load("res://scripts/entities.gd")
	for size in [Vector2(355, 34), Vector2(52, 52), Vector2(58, 275)]:
		_check(FINISH.perimeter(Rect2(Vector2.ZERO, size), 0.0).size() == 4, "unrounded surface contains duplicate vertices")
		var shape: PackedVector2Array = FINISH.perimeter(Rect2(Vector2.ZERO, size), 8.0)
		_check(not Geometry2D.is_point_in_polygon(Vector2(0.5, 0.5), shape), "sharp corner remains in finished perimeter")
		_check(Geometry2D.is_point_in_polygon(Vector2(size.x * 0.5, 0.5), shape), "walking surface no longer meets the collision top")
		for point in shape:
			_check(point.x >= -0.001 and point.y >= -0.001 and point.x <= size.x + 0.001 and point.y <= size.y + 0.001, "finished perimeter exceeds collision bounds")
	var tuning := root.get_node("TuningStore")
	var old_speed: float = tuning.get_value("enemy_speed")
	tuning.set_value("enemy_speed", 0.0)
	var opaque := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	opaque.fill(Color.WHITE)
	var padded := Image.create(80, 96, false, Image.FORMAT_RGBA8)
	padded.fill(Color.TRANSPARENT)
	padded.fill_rect(Rect2i(13, 7, 32, 32), Color.WHITE)
	var tall := Image.create(96, 112, false, Image.FORMAT_RGBA8)
	tall.fill(Color.TRANSPARENT)
	tall.fill_rect(Rect2i(17, 9, 24, 72), Color.WHITE)
	var frame_tall := Image.create(80, 96, false, Image.FORMAT_RGBA8)
	frame_tall.fill(Color.TRANSPARENT)
	frame_tall.fill_rect(Rect2i(13, 7, 32, 64), Color.WHITE)
	var animated = entities.Walker.new()
	animated.sprite_texture = ImageTexture.create_from_image(padded)
	var short_frame: Rect2 = animated.sprite_draw_rect()
	animated.sprite_texture = ImageTexture.create_from_image(frame_tall)
	var tall_frame: Rect2 = animated.sprite_draw_rect()
	_check(is_equal_approx(short_frame.size.x, tall_frame.size.x), "changing frame alpha bounds changes artwork scale")
	_check(is_equal_approx(tall_frame.size.y, short_frame.size.y * 2.0), "frame canvas no longer determines a stable scale")
	# The torso stays on the authored center while an arm changes the alpha extent.
	# Centering the cropped silhouette would translate the same torso between frames.
	for arm_x in [8, 36]:
		var asymmetric := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		asymmetric.fill(Color.TRANSPARENT)
		asymmetric.fill_rect(Rect2i(28, 20, 8, 24), Color.WHITE)
		asymmetric.fill_rect(Rect2i(arm_x, 24, 20, 4), Color.RED)
		animated.sprite_texture = ImageTexture.create_from_image(asymmetric)
		for stretch in [Vector2.ONE, Vector2(1.25, 0.2)]:
			animated.visual_scale = stretch
			var frame: Rect2 = animated.sprite_draw_rect()
			var torso_u: float = (32.0 - animated.sprite_region.position.x) / animated.sprite_region.size.x
			_check(is_zero_approx(frame.position.x + torso_u * frame.size.x), "asymmetric frame shifts the authored torso pivot")
	animated.free()
	for floor_top in [300.0, 180.0]:
		for texture in [entities.Walker.TEXTURE, ImageTexture.create_from_image(opaque), ImageTexture.create_from_image(padded), ImageTexture.create_from_image(tall)]:
			await _check_enemy(texture, floor_top)
	tuning.set_value("enemy_speed", old_speed)
	if not failed:
		print("[FINISH_PASS] rounded perimeter; opaque/padded/tall enemy feet on ground/platform, stable frame scale/pivot, animation and stomp")
	quit(1 if failed else 0)


func _check_enemy(texture: Texture2D, floor_top: float) -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var floor := StaticBody2D.new()
	floor.position = Vector2(300, floor_top + 20.0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(500, 40)
	collision.shape = rectangle
	floor.add_child(collision)
	arena.add_child(floor)
	var enemy = entities.Walker.new()
	enemy.sprite_texture = texture
	enemy.position = Vector2(300, floor_top - 75.0)
	arena.add_child(enemy)
	for frame in 45:
		await physics_frame
	_check(enemy.is_on_floor(), "enemy did not settle on supporting surface")
	enemy.set_physics_process(false)
	var hitbox: CollisionShape2D = enemy.get_child(0)
	var physical_bottom: float = enemy.position.y + hitbox.position.y + hitbox.shape.size.y * 0.5
	_check(absf(physical_bottom - floor_top) < 0.1, "enemy collider no longer rests on support")
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var alpha_bounds := image.get_used_rect()
	_check(enemy.sprite_region == Rect2(alpha_bounds), "sprite includes transparent canvas padding")
	for phase in [0.0, PI / 24.0, PI / 8.0]:
		enemy.t = phase
		var drawn: Rect2 = enemy.sprite_draw_rect()
		_check(absf(enemy.position.y + drawn.end.y - floor_top) < 0.1, "animated sprite feet move away from floor")
		_check(drawn.size.x <= 60.01 and drawn.size.y <= 61.51, "replacement sprite exceeds its visual size budget")
	var center_before: Vector2 = enemy.position
	enemy.stomp()
	await create_timer(0.14).timeout
	_check(enemy.scale.is_equal_approx(Vector2.ONE), "stomp scales the physics body about its origin")
	_check(enemy.position.is_equal_approx(center_before), "stomp moves the collision origin")
	_check(enemy.visual_scale.y < 0.25, "stomp visual squash was lost")
	_check(absf(enemy.position.y + enemy.sprite_draw_rect().end.y - floor_top) < 0.1, "stomp squash lifts sprite feet")
	arena.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[FINISH_FAIL] " + message)
