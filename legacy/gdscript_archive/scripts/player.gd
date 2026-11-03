extends CharacterBody2D

const ANIS_CHARACTER = preload("res://scripts/anis_character.gd")

signal died
signal shot_requested(position: Vector2, direction: float)
signal stomped
signal jumped(position: Vector2)
signal landed(position: Vector2)
signal trail_requested(position: Vector2)

const HITBOX_SIZE := Vector2(20.0, 28.0)
const HITBOX_OFFSET := Vector2(0, -2)
const FOOT_Y := 16.0
const LAND_POSE_SECONDS := 0.18

var alive := true
var facing := 1.0
var spawn_position := Vector2.ZERO
var coyote_time := 0.0
var jump_buffer := 0.0
var anim_time := 0.0
var touch_input: Node = null
var touch_jump_was_pressed := false
var was_on_floor := false
var land_pose_left := 0.0
var attack_cooldown_left := 0.0
var shot_flash := 0.0
var stomp_grace := 0.0
var trail_timer := 0.0
var suppress_actions_until_release := false
var anis_visual: Node2D
var death_count := 0

func _ready() -> void:
	add_to_group("transient_input")
	collision_layer = 2
	collision_mask = 1 | 4
	spawn_position = global_position
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = HITBOX_SIZE
	shape.shape = rect
	shape.position = HITBOX_OFFSET
	add_child(shape)
	anis_visual = ANIS_CHARACTER.new()
	anis_visual.name = "AnisVisual"
	anis_visual.reduced_motion = TuningStore.get_player_setting("reduced_motion") > 0.5
	add_child(anis_visual)
	queue_redraw()

func _physics_process(delta: float) -> void:
	stomp_grace = maxf(0.0, stomp_grace - delta)
	land_pose_left = maxf(0.0, land_pose_left - delta)
	attack_cooldown_left = maxf(0.0, attack_cooldown_left - delta)
	shot_flash = maxf(0.0, shot_flash - delta)
	var gravity := TuningStore.get_value("gravity")
	if not alive:
		velocity.y += gravity * delta
		move_and_slide()
		_sync_visual(ANIS_CHARACTER.State.DEATH)
		queue_redraw()
		return

	anim_time += delta
	if is_on_floor():
		coyote_time = TuningStore.get_value("coyote_time")
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
		velocity.y += gravity * delta

	var touch_vector := Vector2.ZERO
	if touch_input != null:
		touch_vector = touch_input.vector
	var touch_jump_pressed := touch_vector.y < -0.35
	if suppress_actions_until_release and not Input.is_action_pressed("jump") and not Input.is_action_pressed("attack"):
		suppress_actions_until_release = false
	var jump_started := not suppress_actions_until_release and (Input.is_action_just_pressed("jump") or (touch_jump_pressed and not touch_jump_was_pressed))
	var jump_released := Input.is_action_just_released("jump") or (not touch_jump_pressed and touch_jump_was_pressed)
	touch_jump_was_pressed = touch_jump_pressed

	if jump_started:
		jump_buffer = TuningStore.get_value("jump_buffer")
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)

	var direction := Input.get_axis("move_left", "move_right")
	if absf(direction) <= 0.05:
		direction = touch_vector.x
	if absf(direction) > 0.05:
		velocity.x = move_toward(velocity.x, direction * TuningStore.get_value("move_speed"), TuningStore.get_value("acceleration") * delta)
		facing = signf(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, TuningStore.get_value("friction") * delta)

	if not suppress_actions_until_release and Input.is_action_just_pressed("attack"):
		try_attack()

	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = -TuningStore.get_value("jump_power")
		jump_buffer = 0.0
		coyote_time = 0.0
		jumped.emit(global_position + Vector2(0, FOOT_Y))
	var jump_release_speed := TuningStore.get_value("jump_release_speed")
	if jump_released and velocity.y < -jump_release_speed:
		velocity.y = -jump_release_speed

	var feet_before_move := global_position.y + FOOT_Y
	var vertical_speed_before_move := velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor() and vertical_speed_before_move > 140.0:
		land_pose_left = LAND_POSE_SECONDS
		landed.emit(global_position + Vector2(0, FOOT_Y))
	was_on_floor = is_on_floor()
	trail_timer = maxf(0.0, trail_timer - delta)
	if is_on_floor() and absf(velocity.x) > 70.0 and trail_timer <= 0.0:
		trail_timer = 0.14
		trail_requested.emit(global_position + Vector2(0, FOOT_Y))

	var enemy_contacts: Array[KinematicCollision2D] = []
	var stomped_any := false
	for index in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var collider := hit.get_collider()
		if collider == null:
			continue
		if collider.is_in_group("enemy"):
			enemy_contacts.append(hit)
			if not bool(collider.get("alive")):
				continue
			var from_above := hit.get_normal().y < -0.45
			if collider.has_method("stomp_top_y"):
				from_above = from_above or feet_before_move <= float(collider.stomp_top_y()) + 6.0
			if vertical_speed_before_move >= 0.0 and from_above:
				collider.stomp()
				stomped.emit()
				stomped_any = true
		elif collider.is_in_group("question_block") and hit.get_normal().y > 0.55:
			if collider.has_method("activate"):
				collider.activate()
	if stomped_any:
		velocity.y = -TuningStore.get_value("stomp_bounce")
		stomp_grace = 0.12
	elif stomp_grace <= 0.0:
		for hit in enemy_contacts:
			var collider := hit.get_collider()
			if is_instance_valid(collider) and bool(collider.get("alive")):
				die()
				break

	if global_position.y > 820.0:
		die()
	_sync_visual(_visual_state())
	queue_redraw()

func _visual_state() -> int:
	if not alive:
		return ANIS_CHARACTER.State.DEATH
	if not is_on_floor():
		return ANIS_CHARACTER.State.JUMP if velocity.y < 0.0 else ANIS_CHARACTER.State.FALL
	if land_pose_left > 0.0:
		return ANIS_CHARACTER.State.LAND
	if absf(velocity.x) > 70.0:
		return ANIS_CHARACTER.State.RUN
	return ANIS_CHARACTER.State.IDLE

func _sync_visual(next_state: int) -> void:
	if is_instance_valid(anis_visual) and anis_visual.has_method("set_motion"):
		anis_visual.set_motion(next_state, velocity, facing, death_count)

func play_victory() -> void:
	if is_instance_valid(anis_visual):
		anis_visual.set_motion(ANIS_CHARACTER.State.WIN, Vector2.ZERO, facing, death_count)

func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED and is_instance_valid(anis_visual):
		anis_visual.reduced_motion = TuningStore.get_player_setting("reduced_motion") > 0.5

func die() -> void:
	if not alive:
		return
	alive = false
	death_count += 1
	collision_mask = 0
	velocity = Vector2(0, -430)
	died.emit()
	_sync_visual(ANIS_CHARACTER.State.DEATH)

func current_sprite_texture() -> Texture2D:
	return null

func sprite_pixel_scale() -> Vector2:
	return Vector2.ONE

func sprite_draw_rect() -> Rect2:
	return Rect2(-24, -38, 48, 38)

func _draw() -> void:
	# Rendering is delegated to AnisCharacter so physics never depends on cosmetics.
	pass

func try_attack() -> bool:
	if not alive or get_tree().paused or attack_cooldown_left > 0.0:
		return false
	TuningStore.apply_boundary("NEXT_ACTION")
	attack_cooldown_left = TuningStore.get_value("attack_cooldown")
	shot_flash = 0.12
	shot_requested.emit(global_position + Vector2(0, -8), facing)
	return true

func clear_input() -> void:
	jump_buffer = 0.0
	touch_jump_was_pressed = false
	suppress_actions_until_release = true
