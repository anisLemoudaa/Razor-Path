extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var output_dir := _output_directory()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_fail("could not create capture directory: %s" % output_dir)
		return

	var tuning_store := get_node_or_null("/root/TuningStore")
	if tuning_store == null:
		_fail("TuningStore autoload was not created")
		return
	tuning_store.call("reset_defaults", false)

	var title_scene := load("res://scenes/title_screen.tscn") as PackedScene
	if title_scene == null:
		_fail("title scene failed to load")
		return
	var title := title_scene.instantiate()
	add_child(title)
	for i in 3:
		await get_tree().process_frame
	var title_result := get_viewport().get_texture().get_image().save_png(output_dir.path_join("platformer-title.png"))
	title.queue_free()
	await get_tree().process_frame

	var game_scene := load("res://scenes/game.tscn") as PackedScene
	if game_scene == null:
		_fail("game scene failed to load")
		return
	var game := game_scene.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		_fail("player was not created")
		return

	Input.action_press("move_right")
	for i in 20:
		await get_tree().process_frame
	Input.action_press("jump")
	for i in 4:
		await get_tree().process_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	for i in 8:
		await get_tree().process_frame
	var visual_effects := game.get_node_or_null("VisualEffects")
	if visual_effects == null:
		_fail("visual effects system was not created")
		return
	var collect_effects_before := int(visual_effects.get_spawn_count("collect"))
	var finish_effects_before := int(visual_effects.get_spawn_count("finish"))
	visual_effects.spawn_collect_sparkle(player.global_position + Vector2(70, -30))
	visual_effects.spawn_finish_confetti(player.global_position + Vector2(140, -90))
	if int(visual_effects.get_spawn_count("collect")) != collect_effects_before + 1 or int(visual_effects.get_spawn_count("finish")) != finish_effects_before + 1:
		_fail("particle effects were not prepared for the gameplay capture")
		return
	for i in 3:
		await get_tree().process_frame

	var gameplay_result := get_viewport().get_texture().get_image().save_png(output_dir.path_join("platformer-gameplay.png"))
	var pause_menu := game.get_node_or_null("PauseMenu")
	if pause_menu == null:
		_fail("pause menu was not created")
		return
	pause_menu.open_menu()
	for i in 3:
		await get_tree().process_frame
	var pause_result := get_viewport().get_texture().get_image().save_png(output_dir.path_join("platformer-pause.png"))
	pause_menu.close_menu()

	if title_result != OK or gameplay_result != OK or pause_result != OK:
		_fail("one or more screenshots could not be saved")
		return
	print("[DEBUG_CAPTURE_PASS] screenshots saved to %s" % output_dir)
	get_tree().quit(0)


func _output_directory() -> String:
	var configured := OS.get_environment("GAME_CAPTURE_DIR")
	if configured.is_empty():
		return ProjectSettings.globalize_path("user://captures")
	if configured.is_absolute_path():
		return configured
	return ProjectSettings.globalize_path("res://" + configured)


func _fail(message: String) -> void:
	push_error("[DEBUG_CAPTURE_FAIL] " + message)
	get_tree().quit(1)
