extends SceneTree

var player_script: Script
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	player_script = load("res://scripts/player.gd")
	for floor_top in [300.0, 180.0]:
		var arena := Node2D.new()
		root.add_child(arena)
		var floor := StaticBody2D.new()
		floor.position = Vector2(300, floor_top + 20.0)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(500, 40)
		collision.shape = shape
		floor.add_child(collision)
		arena.add_child(floor)
		var player = player_script.new()
		player.position = Vector2(300, floor_top - 75.0)
		arena.add_child(player)
		for frame in 45:
			await physics_frame
		_check(player.is_on_floor(), "player did not settle on support")
		player.set_physics_process(false)
		var hitbox: CollisionShape2D = player.get_child(0)
		var physical_bottom: float = player.position.y + hitbox.position.y + hitbox.shape.height * 0.5
		_check(absf(physical_bottom - floor_top) < 0.1, "player collider not touching support")
		for facing in [-1.0, 1.0]:
			player.facing = facing
			for recoil in [0.0, 0.12]:
				player.shot_flash = recoil
				player.velocity.x = 0.0
				_check_feet(player, floor_top, "idle")
				player.velocity.x = 160.0
				for index in player_script.RUN_FRAMES.size():
					for cycle in [0.0, 1.5, 3.0]:
						player.anim_time = (float(index) + 0.1) / 12.0 + cycle
						_check(player.current_sprite_texture() == player_script.RUN_FRAMES[index], "wrong run frame")
						_check_feet(player, floor_top, "run frame " + str(index))
		# Replacement art with varying padding must retain canvas scale and pivot.
		player.velocity.x = 0.0
		player.shot_flash = 0.0
		for bottom in [35, 70]:
			var image := Image.create(96, 112, false, Image.FORMAT_RGBA8)
			image.fill(Color.TRANSPARENT)
			image.fill_rect(Rect2i(41, 7, 14, bottom - 7), Color.WHITE)
			player.idle_texture = ImageTexture.create_from_image(image)
			_check_feet(player, floor_top, "padded replacement")
			var visible: Rect2 = player.sprite_draw_rect()
			_check(is_equal_approx(visible.size.x, 14.0 * player_script.SPRITE_SCALE), "alpha bounds changed character scale")
			_check(is_zero_approx(visible.get_center().x), "padded frame changed canvas pivot")
		# Intentional airborne movement remains in the physics body.
		player.idle_texture = player_script.HERO_TEXTURE
		player.alive = false
		_check_feet(player, floor_top, "death squash")
		arena.queue_free()
		await process_frame
	if not failed:
		print("[PLAYER_GROUNDING_PASS] player idle/run frames, facing, recoil, animation phases, ground/platform, replacements and squash share collider feet")
	quit(1 if failed else 0)


func _check_feet(player: CharacterBody2D, floor_top: float, label: String) -> void:
	var visible: Rect2 = player.sprite_draw_rect()
	_check(visible.has_area(), "invisible player " + label)
	_check(absf(player.position.y + visible.end.y - floor_top) < 0.1, "feet leave support: " + label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[PLAYER_GROUNDING_FAIL] " + message)
