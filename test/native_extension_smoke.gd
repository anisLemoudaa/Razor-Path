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
	assert(ResourceLoader.exists("res://assets/ui/razor_path_menu_backdrop.png"), "illustrated menu background should be part of the project")
	assert(game.test_unlocked_stage() == 10, "the first ten stages should be open for a new campaign")
	var run_cycle := PackedInt32Array()
	for pose_index in range(8):
		run_cycle.append(game.test_animation_frame_at(float(pose_index) / 10.0))
	assert(run_cycle == PackedInt32Array([0, 1, 0, 1, 0, 1, 0, 1]), "the run cycle should alternate only the two authored running poses")
	assert(game.test_animation_frame_at(1.0 / 30.0) == 0, "each source pose should hold for three 30 Hz animation ticks")
	assert(game.test_animation_frame_at(3.0 / 30.0) == 1, "the next run pose should begin on the third tick")
	assert(game.test_animation_frame_at(6.0 / 30.0) == 0, "the two-pose run cycle should loop after six ticks")
	for stage_number in range(1, 251):
		assert(game.test_stage_loadable(stage_number), "stage %d should load with geometry, stars, checkpoint and exit" % stage_number)

	assert(not game.test_try_start_stage(11), "stage 11 should remain locked until the first group chest is complete")
	game._on_ui_action("levels")
	game._on_ui_action("stage:1")
	assert(game.test_screen() == 1, "the first tap on the preselected stage 1 should only confirm the selection")
	game._on_ui_action("stage:1")
	assert(game.test_screen() == 2 and game.test_stage() == 1, "the second tap on stage 1 should begin it")
	game._on_ui_action("home")
	game._on_ui_action("levels")
	game._on_ui_action("stage:2")
	assert(game.test_screen() == 1, "the first tap should select a different open stage without starting it")
	game._on_ui_action("stage:2")
	assert(game.test_screen() == 2 and game.test_stage() == 2, "the second tap on the selected stage should begin it")
	assert(game.test_try_start_stage(1), "stage 1 should start")
	assert(game.test_screen() == 2, "stage 1 should enter gameplay")
	assert(game.test_stage() == 1, "new run should begin at stage 1")
	assert(game.test_stage_star_count() == 3, "each loaded stage should expose three stars")

	var purchase_candidate := -1
	for skin_index in range(1, 9):
		if not game.test_skin_owned(skin_index):
			purchase_candidate = skin_index
			break
	if purchase_candidate >= 0:
		game.test_set_coins(1000)
		assert(game.test_purchase_skin(purchase_candidate), "an unowned skin should be purchasable with enough coins")
		assert(game.test_skin_owned(purchase_candidate), "successful purchase should persist ownership")
		assert(not game.test_purchase_skin(purchase_candidate), "a duplicate skin purchase must not charge twice")
	var future_claim := int(Time.get_unix_time_from_system()) + 200 * 365 * 24 * 60 * 60
	assert(game.test_claim_daily_gift_at(future_claim), "daily gift should be claimable when ready")
	assert(not game.test_claim_daily_gift_at(future_claim), "daily gift must reject a duplicate claim")
	assert(game.test_claim_daily_gift_at(future_claim + 24 * 60 * 60), "daily gift should reset after 24 hours")

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
	assert(_press_button_by_text(game, "‹ عودة"), "shop should expose a visible back button")
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
	assert(game.test_unlocked_stage() == 10, "clearing one stage should not open the next ten-level group")
	var progress := ConfigFile.new()
	assert(progress.load(save_path) == OK, "clearing stage 1 should persist progress")
	assert(int(progress.get_value("progress", "unlocked_stage", 1)) == 10, "saved progress should retain the open first group")
	for stage_number in range(2, 11):
		assert(game.test_try_start_stage(stage_number), "stage %d in the first group should be playable" % stage_number)
		game.test_complete_current_stage()
	assert(game.test_unlocked_stage() == 20, "completing all ten stages should open stages 11–20")
	assert(game.test_try_start_stage(11), "stage 11 should start after the first group chest is complete")
	assert(game.test_stage() == 11, "the next group should begin at stage 11")
	assert(not game.test_try_start_stage(21), "stage 21 should remain locked until the second group is complete")
	assert(progress.load(save_path) == OK, "completing the first group should persist progress")
	assert(int(progress.get_value("progress", "unlocked_stage", 1)) == 20, "saved progress should record the newly opened group")
	for stage_number in [11, 12, 13, 14, 15, 17, 18, 19, 20, 16]:
		assert(game.test_try_start_stage(stage_number), "stage %d in the second group should be playable" % stage_number)
		game.test_complete_current_stage()
	assert(game.test_unlocked_stage() == 30, "completing stage 16 last should still open stages 21–30")
	assert(progress.load(save_path) == OK, "completing the second group should persist progress")
	assert(int(progress.get_value("progress", "unlocked_stage", 1)) == 30, "saved progress should record the second group unlock")
	assert(game.test_try_start_stage(21), "stage 21 should start after the second group chest is complete")
	game._on_ui_action("home")
	game._on_ui_action("levels")
	game._on_ui_action("page_next")
	game._on_ui_action("stage:21")
	assert(game.test_screen() == 1, "the first tap on a page's preselected first level should only confirm it")
	game._on_ui_action("stage:21")
	assert(game.test_screen() == 2 and game.test_stage() == 21, "the second tap should begin the page's first level")
	assert(game.start_test_stage(16), "stage 16 should load for the native acceptance check")
	assert(game.test_stage_is_monochrome(), "stage 16 should use the monochrome palette")
	assert(is_equal_approx(game.test_stage_world_width(), 3550.0), "stage 16 should load its JSON width")
	assert(game.start_test_stage(250), "stage 250 should load for the native acceptance check")
	assert(game.test_stage() == 250, "the final generated stage should retain its index")
	assert(is_equal_approx(game.test_stage_world_width(), 615.8 * 64.0), "stage 250 should load its generated JSON world width")
	assert(game.test_stage_star_count() == 3, "the final stage should expose all three stars")
	game.test_complete_current_stage()
	assert(game.test_screen() == 7, "clearing stage 250 should produce the campaign victory screen")
	assert(game.test_unlocked_stage() == 250, "campaign progress should cap at stage 250")

	game.queue_free()
	if had_save:
		var restore_file := FileAccess.open(save_path, FileAccess.WRITE)
		assert(restore_file != null, "could not restore the pre-test save")
		restore_file.store_buffer(previous_save)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("native_extension_smoke: PASS")
	quit(0)
