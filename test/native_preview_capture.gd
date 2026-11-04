extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed := load("res://scenes/native_main.tscn") as PackedScene
	assert(packed != null, "native main scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-home.png")

	game._on_ui_action("levels")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-level-select.png")
	game._on_ui_action("back")
	await process_frame
	game.test_open_shop()
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-shop.png")
	for pose_index in range(30):
		await create_timer(1.0 / 30.0).timeout
		_save_view("game-captures/shop-run-cycle/frame-%02d.png" % (pose_index + 1))
	game.test_back()
	await process_frame

	assert(game.start_test_stage(1), "stage 1 could not be opened for preview")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-01.png")
	assert(game.test_register_touch(707, 2), "right-move action should be held during the run-cycle preview")
	for frame_index in range(30):
		await create_timer(1.0 / 30.0).timeout
		_save_view("game-captures/run-cycle/frame-%02d.png" % (frame_index + 1))
	assert(game.test_release_touch(707), "run-cycle preview input should be released")
	game.test_complete_current_stage()
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-clear.png")

	assert(game.start_test_stage(16), "stage 16 could not be opened for preview")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-16.png")

	assert(game.start_test_stage(250), "stage 250 could not be opened for preview")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-250.png")
	game.test_complete_current_stage()
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-victory.png")

	print("native_preview_capture: saved home, selection, shop, gameplay, 30fps run cycles, stage clear and campaign victory")
	quit(0)


func _save_view(relative_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path("res://" + relative_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty(), "viewport screenshot is empty")
	var error := image.save_png(absolute_path)
	assert(error == OK, "failed to save screenshot: " + relative_path)
