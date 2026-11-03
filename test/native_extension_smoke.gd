extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _press_button_by_text(root_node: Node, expected_text: String) -> bool:
	for child in root_node.find_children("*", "Button", true, false):
		if child is Button and child.text == expected_text:
			child.emit_signal("pressed")
			return true
	return false


func _run() -> void:
	var save_path := "user://razor_path_save.cfg"
	var had_save := FileAccess.file_exists(save_path)
	var previous_save := FileAccess.get_file_as_bytes(save_path) if had_save else PackedByteArray()

	assert(ClassDB.class_exists("RazorPathGame"), "GDExtension did not register RazorPathGame")
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/native_main.tscn", "native scene is not the project entry point")
	var packed := load("res://scenes/native_main.tscn") as PackedScene
	assert(packed != null, "native main scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	assert(game.hero_frame_assets.size() == 8, "main scene should reference all eight hero frames")
	assert(game.interface_theme != null, "main scene should provide the Arabic UI theme")
	assert(game.test_frames_loaded(), "all eight hero textures should load")
	assert(game.test_screen() == 0, "new game should open on the main menu")
	assert(not game.test_stage_is_monochrome(), "stage 1 should use the warm palette")
	assert(is_equal_approx(game.test_stage_world_width(), 3900.0), "stage 1 should load its JSON width")

	game.test_set_unlocked_stage(1)
	assert(not game.test_try_start_stage(2), "stage 2 must stay locked before stage 1 is cleared")
	assert(game.test_try_start_stage(1), "stage 1 should start")
	assert(game.test_screen() == 2, "stage 1 should enter gameplay")
	assert(game.test_stage() == 1, "new run should begin at stage 1")

	assert(game.test_register_touch(11, 2), "register run finger")
	assert(game.test_register_touch(22, 3), "register jump finger")
	assert(game.test_has_touch_action(2), "run action should be held")
	assert(game.test_has_touch_action(3), "jump action should be held concurrently")
	assert(game.test_release_touch(11), "release run finger")
	assert(not game.test_has_touch_action(2), "released finger should clear only its run action")
	assert(game.test_has_touch_action(3), "releasing run must not clear the other finger's jump")
	assert(game.test_release_touch(22), "release jump finger")
	assert(not game.test_has_touch_action(3), "released jump finger should clear jump")

	game.test_open_shop()
	assert(game.test_screen() == 4, "shop should open from gameplay")
	assert(_press_button_by_text(game, "رجوع"), "shop should expose a visible back button")
	assert(game.test_screen() == 2, "visible shop back button should return to gameplay")
	game.test_open_settings()
	assert(game.test_screen() == 5, "settings should open")
	assert(_press_button_by_text(game, "رجوع"), "settings should expose a visible back button")
	assert(game.test_screen() == 2, "visible settings back button should return to gameplay")
	game.test_open_settings()
	game.test_back()
	assert(game.test_screen() == 2, "Android Back should return from settings to gameplay")

	game.test_complete_current_stage()
	assert(game.test_screen() == 6, "clearing stage 1 should show the stage-clear screen")
	assert(game.test_unlocked_stage() == 2, "clearing stage 1 should unlock exactly stage 2")
	var progress := ConfigFile.new()
	assert(progress.load(save_path) == OK, "clearing stage 1 should persist progress")
	assert(int(progress.get_value("progress", "unlocked_stage", 1)) == 2, "saved progress should unlock stage 2")
	assert(game.test_try_start_stage(2), "stage 2 should start after stage 1 is cleared")
	assert(game.test_stage() == 2, "the next stage should be stage 2")
	assert(game.start_test_stage(16), "stage 16 should load for the native acceptance check")
	assert(game.test_stage_is_monochrome(), "stage 16 should use the monochrome palette")
	assert(is_equal_approx(game.test_stage_world_width(), 3550.0), "stage 16 should load its JSON width")

	game.queue_free()
	if had_save:
		var restore_file := FileAccess.open(save_path, FileAccess.WRITE)
		assert(restore_file != null, "could not restore the pre-test save")
		restore_file.store_buffer(previous_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("native_extension_smoke: PASS")
	quit(0)
