extends SceneTree
## Test-only silent streams exercise lifecycle without shipping placeholder audio.

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio = root.get_node_or_null("GameAudio")
	if audio == null:
		_check(false, "GameAudio autoload is missing")
		quit(1)
		return
	_check(not audio.enabled and not audio.music.playing, "boot must not autoplay")
	_check(audio.music.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "BGM must stream")
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = PackedByteArray()
	var samples := PackedByteArray()
	samples.resize(44100)
	stream.data = samples
	stream.loop_end = 22050
	var cues: Dictionary[StringName, AudioStream] = {}
	for cue in [&"confirm", &"jump", &"land", &"coin", &"stomp", &"checkpoint", &"death", &"success"]:
		cues[cue] = stream
	audio.configure(stream, cues)
	var music_id: int = audio.music.get_instance_id()
	var resource_id: int = audio.music.stream.get_instance_id()
	var children: int = audio.get_child_count()
	var buses := AudioServer.bus_count
	_check(children == 1 + audio.MAX_SFX_VOICES, "audio player count must be fixed")
	audio.begin_game()
	var starts: int = audio.music_starts
	var before: int = audio.pause_state_changes
	for i in 10000:
		audio._process(1.0 / 60.0)
		audio.begin_game()
	_check(audio.pause_state_changes == before, "idle repeatedly writes pause state")
	_check(audio.music_starts == starts and starts == 1, "begin_game restarts active BGM")
	_check(audio.get_play_count(&"confirm") == 1, "repeated begin repeats confirmation")
	paused = true
	for i in 10000:
		audio._process(1.0 / 60.0)
	_check(audio.pause_state_changes == before + 1 and audio.music.stream_paused, "pause must write once")
	var jumps: int = audio.get_play_count(&"jump")
	audio.play(&"jump")
	_check(audio.get_play_count(&"jump") == jumps, "paused gameplay emits new SFX")
	paused = false
	for i in 10000:
		audio._process(1.0 / 60.0)
	_check(audio.pause_state_changes == before + 2 and not audio.music.stream_paused, "resume must write once")
	for i in 1000:
		audio.play(&"coin")
	_check(audio.get_child_count() == children, "SFX burst allocates players")
	for voice in audio.voices:
		_check(voice.max_polyphony == 1, "voice exceeds polyphony limit")
	audio.set_volume(2.0)
	_check(is_equal_approx(audio.volume, 1.0), "volume must clamp")
	audio.set_muted(true)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(audio.MUSIC_BUS)), "mute must reach bus")
	audio.set_muted(false)
	audio.set_volume(0.8)
	paused = true
	audio._process(0.0)
	audio.stop_game()
	paused = false
	audio.begin_game()
	_check(audio.music.playing and not audio.music.stream_paused, "restart from paused menu stays paused")
	audio.stop_game()
	for i in 5:
		audio.configure(stream, cues)
		audio.begin_game()
		audio.stop_game()
	_check(audio.music.stream.get_instance_id() == resource_id, "same catalog reallocates BGM")
	# Exercise real title -> gameplay -> death/respawn -> menu transitions.
	for cycle in 3:
		change_scene_to_file("res://scenes/title_screen.tscn")
		await process_frame
		await process_frame
		_check(audio.music.playing and not audio.enabled, "return title reuses selected music after prior gesture")
		current_scene._name_entry.text = "AudioTest"
		current_scene.start_game()
		await process_frame
		await process_frame
		var game = current_scene
		var cycle_starts: int = audio.music_starts
		var cue_before: int = audio.get_play_count(&"coin")
		game._on_coin_collected(Vector2(160, 500))
		_check(audio.get_play_count(&"coin") == cue_before + 1, "coin cue is not wired")
		var pause_menu = game.get_node("PauseMenu")
		pause_menu.open_menu()
		await process_frame
		await process_frame
		_check(audio.music.stream_paused, "real pause menu must pause BGM")
		pause_menu.close_menu()
		await process_frame
		await process_frame
		await game._on_player_died()
		_check(audio.music_starts == cycle_starts, "respawn restarts BGM")
		_check(audio.get_child_count() == children, "respawn allocates audio players")
		game.return_to_main_menu()
		await process_frame
		await process_frame
		_check(not audio.enabled and audio.music.playing, "main menu keeps only selected music after prior gesture")
		for voice in audio.voices:
			_check(not voice.playing, "main menu leaks SFX playback")
	_check(audio.music.get_instance_id() == music_id, "scene changes replace music player")
	_check(AudioServer.bus_count == buses, "scene changes accumulate buses")
	_check(audio.get_child_count() == children, "scene changes accumulate audio nodes")
	# Audio-free games and unknown cues must remain safe without per-frame writes.
	audio.configure(null, cues)
	audio.begin_game()
	audio.play(&"unknown")
	audio.play(&"jump")
	before = audio.pause_state_changes
	paused = true
	for i in 10000:
		audio._process(0.0)
	_check(audio.pause_state_changes == before, "empty BGM receives repeated pause writes")
	for voice in audio.voices:
		if voice.playing or voice.stream_paused:
			_check(voice.stream_paused, "SFX-only game does not pause")
	paused = false
	audio.stop_game()
	# Allow the mixer to consume stop requests before engine shutdown.
	await create_timer(0.15).timeout
	if not failed:
		print("[AUDIO_IDLE_PASS] idempotent pause/start, bounded SFX, real respawn/menu cycles")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[AUDIO_IDLE_FAIL] " + message)
