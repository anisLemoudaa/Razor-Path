extends SceneTree

const SCORE = preload("res://scripts/run_score.gd")
const STAGES = preload("res://scripts/stage_catalog.gd")
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var store := root.get_node("SaveStore")
	var original: Dictionary = store.data.duplicate(true)
	var tuning := root.get_node("TuningStore")
	tuning.reset_defaults(false)
	_test_score()
	_test_stages()
	_test_save(store)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for frame in 4: await process_frame
	_check(game.stage.id == "sunlit_nook", "first stage loaded")
	_check(game.score == 0 and game.coins == 0, "fresh run resets rewards")
	_check(InputMap.action_get_events("move_right").any(func(event): return event is InputEventJoypadMotion), "gamepad movement missing")
	_check(not InputMap.action_get_events("jump").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_W), "W must not jump")
	_test_tutorial(game, store)
	await _test_gamepad(game)
	# Terminal guard rejects goal contact from an already dying player.
	game.resetting = true
	game.player.alive = false
	game._on_goal_reached()
	_check(not game.finished and game.run_score.result.is_empty(), "death and goal race finalized victory")
	game.resetting = false
	game.player.alive = true
	game._on_goal_reached()
	_check(game.finished and game.terminal_result.is_empty(), "first-stage clear should await next stage")
	var stage_clear_score: int = game.score
	game._on_coin_collected(Vector2.ZERO)
	game._on_enemy_stomped()
	game._on_block_activated(Vector2.ZERO)
	game._on_goal_reached()
	_check(game.score == stage_clear_score, "late or duplicate reward changed cleared-stage score")
	game.next_stage()
	await process_frame
	_check(game.stage.id == "lofty_lounge" and not game.finished, "second stage route")
	_check(game.coins == 0 and game.score == stage_clear_score, "stage transition preserves run score, resets objective")
	_check(get_nodes_in_group("player").size() == 1, "stage transition duplicated player")
	game._on_goal_reached()
	_check(not game.finished, "goal ignored fish requirement")
	for item in int(game.stage.required_fish): game._on_coin_collected(Vector2.ZERO)
	game._on_goal_reached()
	_check(game.finished and game.terminal_result.outcome == "victory", "final victory route")
	var frozen: Dictionary = game.terminal_result.duplicate(true)
	game._on_time_up()
	game._on_yarn_hit(Vector2.ZERO)
	_check(game.terminal_result == frozen and game.score == frozen.score, "result changed after finalization")
	_check(not game.player.is_physics_processing(), "terminal player still simulates")
	game.queue_free()
	await process_frame
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.time_left = 0.0
	game._process(0.0)
	_check(game.finished and game.terminal_result.outcome == "defeat", "timeout defeat route")
	_check(game.message_panel.find_children("", "Button", true, false).size() >= 2, "terminal lacks pointer/gamepad retry/title controls")
	var prior_run_id: String = game.run_score.run_id
	game.restart_run()
	for frame in 4: await process_frame
	game = current_scene
	_check(game != null and game.stage.id == "sunlit_nook", "Retry did not return to Stage 1")
	_check(game.score == 0 and game.coins == 0 and game.time_left > 179.0, "Retry retained score/objective/timer")
	_check(game.run_score.run_id != prior_run_id and not game.finished, "Retry reused finalized run")
	_check(get_nodes_in_group("player").size() == 1 and get_nodes_in_group("yarn_projectile").is_empty(), "Retry leaked actors/projectiles")
	_check(not game.tutorial.active, "Retry replayed dismissed tutorial")
	for frame in 32: await process_frame
	_check(root.get_node("GameAudio").music.playing, "Retry failed to resume the music lifecycle")
	store.data = original
	store.save()
	game.queue_free()
	await process_frame
	if not failed: print("[GAMEPLAY_CONTRACT_PASS] stage registry, scoring, terminal guards, two-stage route, local standings and tutorial")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180) # Accelerated tests must let the real audio mixer drain.
	await process_frame
	quit(1 if failed else 0)

func _test_gamepad(game: Node) -> void:
	await create_timer(0.5).timeout
	var start_x: float = game.player.position.x
	var move := InputEventJoypadMotion.new()
	move.axis = JOY_AXIS_LEFT_X
	move.axis_value = 1.0
	Input.parse_input_event(move)
	await create_timer(0.2).timeout
	move.axis_value = 0.0
	Input.parse_input_event(move)
	_check(game.player.position.x > start_x + 20.0, "joypad stick did not move the cat")
	var jump := InputEventJoypadButton.new()
	jump.button_index = JOY_BUTTON_A
	jump.pressed = true
	Input.parse_input_event(jump)
	await create_timer(0.1).timeout
	_check(game.player.velocity.y < -100.0, "joypad A did not jump")
	jump.pressed = false
	Input.parse_input_event(jump)
	var pause := InputEventJoypadButton.new()
	pause.button_index = JOY_BUTTON_START
	pause.pressed = true
	Input.parse_input_event(pause)
	await process_frame
	_check(paused and game.pause_menu.is_open, "joypad Menu did not pause")
	pause.pressed = false
	Input.parse_input_event(pause)
	await process_frame
	pause.pressed = true
	Input.parse_input_event(pause)
	await process_frame
	_check(not paused and not game.pause_menu.is_open, "joypad Menu did not resume")
	pause.pressed = false
	Input.parse_input_event(pause)

func _test_score() -> void:
	var score = SCORE.new()
	score.begin()
	_check(score.award("unknown") == 0 and score.award("fish", -1) == 0, "invalid score event")
	# Authored upper bound: all fish/blocks, 11 robots, and at most 180 time seconds per stage.
	var ceiling := 0
	for id in STAGES.stages():
		var stage: Dictionary = STAGES.load_stage(id)
		var stage_ceiling: int = (stage.fish.size() + stage.blocks.size()) * 100 + stage.blocks.size() * 50 + 11 * 250 + 180 * 10
		ceiling += stage_ceiling
		score.award("fish", stage.fish.size() + stage.blocks.size())
		score.award("block", stage.blocks.size())
		score.award("robot", 11)
		score.award("time_second", 180)
	_check(score.total == ceiling and ceiling == 19650, "authored maximum score changed")
	score.tick(12.5)
	var result: Dictionary = score.finalize("lofty_lounge", "victory", true, {"speed": 310})
	score.award("fish")
	score.tick(5)
	var second: Dictionary = score.finalize("sunlit_nook", "defeat", false)
	_check(second == result, "finalization is not immutable/once-only")
	result.score = -1
	_check(score.result.score == ceiling, "caller mutates authoritative result")

func _test_stages() -> void:
	for id in STAGES.stages():
		_check(STAGES.validate(STAGES.load_stage(id)), "authored stage invalid: " + id)
	var synthetic: Dictionary = STAGES.load_stage("sunlit_nook").duplicate(true)
	synthetic.id = "synthetic_third"
	synthetic.name_key = "stage.synthetic.name"
	_check(STAGES.validate(synthetic), "stage schema rejects a new definition")
	synthetic.required_fish = 1000
	_check(not STAGES.validate(synthetic), "unwinnable objective accepted")

func _test_save(store: Node) -> void:
	store.data = store._default_data()
	_check(store.set_player_name("Jun小猫"), "supported mixed name rejected")
	for value in ["", "<b>", "a\nb", "🦄", "a".repeat(25)]:
		_check(not store.valid_player_name(value), "unsupported name accepted: " + value)
	for index in 15:
		store.record_run({"run_id": "test-%02d" % index, "score": 100 + index, "stage": "sunlit_nook", "outcome": "victory", "duration": 50.0, "timestamp": 100, "eligible": true, "configuration": "baseline"})
	var records: Array = store.leaderboard()
	_check(records.size() == 10 and records[0].score == 114 and records[9].score == 105, "top-N ordering/bounds")
	_check(records[0].player_name == "Jun小猫", "mixed name not saved")
	store.load_save()
	_check(store.leaderboard() == records, "local records did not persist")
	var path: String = store.SAVE_PATH
	var malformed := FileAccess.open(path, FileAccess.WRITE)
	malformed.store_string('{"version":2,"best_score":"broken","records":[null,{"score":20}]}')
	malformed.close()
	store.load_save()
	_check(store.leaderboard().is_empty() and store.best_score() == 0, "malformed data did not recover safely")

func _test_tutorial(game: Node, store: Node) -> void:
	for step in game.tutorial.STEPS.size():
		store.request_tutorial_replay()
		game.tutorial.begin()
		for event_index in step:
			game.tutorial.notify(game.tutorial.COMPLETES[event_index])
		_check(game.tutorial.active and game.tutorial.step == step, "event callout did not progress")
		paused = step % 2 == 0
		game.tutorial.skip_button.pressed.emit()
		_check(not game.tutorial.active and store.tutorial_completed(), "Skip did not persist at step %d" % step)
		_check(paused == (step % 2 == 0), "Skip changed pause owner")
		paused = false
	game.tutorial.begin()
	_check(not game.tutorial.active, "completed tutorial replayed without request")
	store.request_tutorial_replay()
	game.tutorial.begin()
	_check(game.tutorial.active and game.tutorial.step == 0, "explicit tutorial replay failed")
	game.tutorial.skip()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[GAMEPLAY_CONTRACT_FAIL] " + message)
