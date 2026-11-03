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

	assert(game.start_test_stage(1), "stage 1 could not be opened for preview")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-01.png")

	assert(game.start_test_stage(16), "stage 16 could not be opened for preview")
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	_save_view("game-captures/razor-path-stage-16.png")

	print("native_preview_capture: saved home, stage 1 and stage 16 screenshots")
	quit(0)


func _save_view(relative_path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path("res://" + relative_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	assert(image != null and not image.is_empty(), "viewport screenshot is empty")
	var error := image.save_png(absolute_path)
	assert(error == OK, "failed to save screenshot: " + relative_path)
