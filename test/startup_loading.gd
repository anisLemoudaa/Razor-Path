extends SceneTree
var failed := false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var audio := root.get_node("GameAudio")
	_check(not ResourceLoader.has_cached("res://assets/template/audio/bgm.ogg"), "music was eagerly loaded before title")
	var title: Node = load("res://scenes/title_screen.tscn").instantiate()
	root.add_child(title)
	_check(not audio._catalog_configured, "catalog completed before title presentation")
	var pause_during_warmup := OS.get_cmdline_user_args().has("--pause-warmup")
	var early_start := OS.get_cmdline_user_args().has("--early-start") or pause_during_warmup
	if early_start:
		audio.begin_game()
		_check(not audio._catalog_configured, "early Start synchronously loaded the entire bank")
		_check(audio.music.stream == null, "early Start synchronously loaded music")
		_check(audio.get_play_count(&"confirm") == 1, "early Start lost its confirmation cue")
	if pause_during_warmup:
		paused = true
	var previous_count: int = audio._cues.size()
	for index in 16:
		await process_frame
		var next_count: int = audio._cues.size()
		_check(next_count - previous_count <= 1, "audio warm-up loaded more than one cue per frame")
		previous_count = next_count
	_check(audio._catalog_configured, "bounded warm-up did not finish")
	_check(audio.music.stream != null, "music did not become available")
	if pause_during_warmup:
		_check(not audio.music.playing and audio.music_starts == 0, "warm-up started audible music while paused")
		paused = false
		await process_frame
	if not early_start:
		_check(not audio.music.playing and not audio.enabled, "title warm-up autoplayed")
		audio.begin_game()
	_check(audio.music_starts == 1, "first Start failed to begin cached music")
	_check(audio.get_play_count(&"confirm") == 1, "Start lost its confirmation cue")
	audio.stop_game()
	title.queue_free()
	await create_timer(0.15).timeout
	print("STARTUP_AUDIO_OK" if not failed else "STARTUP_AUDIO_FAILED")
	quit(1 if failed else 0)
func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
