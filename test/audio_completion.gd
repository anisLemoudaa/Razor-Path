extends SceneTree
## Final-file, menu/pause and settings coverage; isolated player storage required.

var failed := false
var old_settings: PackedByteArray
var had_settings := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not "Tests" in str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")):
		push_error("Audio completion test requires an isolated test user directory")
		quit(1)
		return
	var audio = root.get_node("GameAudio")
	had_settings = FileAccess.file_exists(audio.SETTINGS_PATH)
	if had_settings: old_settings = FileAccess.get_file_as_bytes(audio.SETTINGS_PATH)
	var catalog = load("res://scripts/audio_catalog.gd")
	var bank: Dictionary[StringName, AudioStream] = {}
	for cue in catalog.CUE_PATHS:
		var stream := load(catalog.CUE_PATHS[cue]) as AudioStreamOggVorbis
		_check(stream != null and stream.get_length() > 0.1, "final cue loads: " + str(cue))
		bank[cue] = stream
	var bgm := load(catalog.BGM_PATH) as AudioStreamOggVorbis
	_check(bgm != null and bgm.get_length() > 30.0, "supplied full music track loads")
	audio.configure(bgm, bank)
	for bus in [&"Master", &"Music", &"SFX", &"UI"]:
		_check(AudioServer.get_bus_index(audio.BUS_NAMES[bus]) >= 0, "audio bus exists: " + str(bus))
		audio.set_bus_volume(bus, 0.7)
		audio.set_bus_muted(bus, false)
		_check(is_equal_approx(audio.get_bus_volume(bus), 0.7), "bus volume applies")
		audio.set_bus_muted(bus, true)
		_check(audio.is_bus_muted(bus), "bus mute applies")
		audio.set_bus_muted(bus, false)
	var config := ConfigFile.new()
	_check(config.load(audio.SETTINGS_PATH) == OK, "audio settings persisted")
	for bus in [&"Master", &"Music", &"SFX", &"UI"]:
		_check(is_equal_approx(float(config.get_value(str(bus), "volume", 0)), 0.7), "persisted independent category")
	config.set_value("Master", "volume", "invalid")
	config.set_value("Music", "volume", NAN)
	config.set_value("UI", "muted", "invalid")
	config.save(audio.SETTINGS_PATH)
	audio._load_settings()
	_check(is_equal_approx(audio.volume, 0.7), "malformed saved master ignored")
	_check(is_equal_approx(audio.get_bus_volume(&"Music"), 0.7), "nonfinite saved music ignored")
	_check(not audio.is_bus_muted(&"UI"), "malformed saved mute ignored")
	audio.begin_title()
	_check(not audio.music.playing, "first title waits for gesture")
	var before: int = audio.get_play_count(&"ui_confirm")
	audio.play_ui(&"confirm")
	_check(audio.get_play_count(&"ui_confirm") == before, "boot has no gesture audio")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_ENTER
	audio._input(key)
	_check(audio.music.playing and not audio.enabled, "title gesture starts only selected music")
	var title_starts: int = audio.music_starts
	var button := Button.new()
	button.text = "audio test"
	root.add_child(button)
	button.pressed.emit()
	_check(audio.get_play_count(&"ui_confirm") == before + 1, "title UI auto hook after gesture")
	button.pressed.emit()
	_check(audio.get_play_count(&"ui_confirm") == before + 1, "UI repeat cooldown")
	paused = true
	audio.play_ui(&"back")
	_check(audio.get_play_count(&"ui_back") == 1, "pause menu UI cue remains available")
	var ui_voices := 0
	for voice in audio.voices:
		if voice.bus == audio.UI_BUS:
			ui_voices += 1
			_check(not voice.stream_paused, "UI voice is not paused with gameplay")
	_check(ui_voices > 0, "UI uses central voice pool")
	paused = false
	button.queue_free()
	audio.begin_game()
	_check(audio.music.playing, "music begins after activation")
	_check(audio.music_starts == title_starts, "title-to-game reuses playing music")
	var starts: int = audio.music_starts
	for frame in 120: audio._process(1.0 / 60.0)
	_check(is_equal_approx(audio.music.volume_db, audio.MUSIC_GAIN_DB), "short fade settles at reference level")
	_check(audio.music_starts == starts, "fade never restarts music")
	for cue in [&"jump", &"land", &"attack", &"coin", &"stomp", &"checkpoint", &"stage_clear", &"invalid", &"tutorial", &"death", &"success"]:
		audio.play(cue)
		_check(audio.get_play_count(cue) > 0, "game event semantic cue: " + str(cue))
	_check(audio.get_child_count() == 1 + audio.MAX_SFX_VOICES, "all semantic cues share bounded voices")
	for bus in [audio.SFX_BUS, audio.UI_BUS]:
		var effect := AudioServer.get_bus_effect(AudioServer.get_bus_index(bus), 0)
		_check(effect is AudioEffectHardLimiter, "overlap protection exists")
	audio.stop_game()
	if had_settings:
		var stream := FileAccess.open(audio.SETTINGS_PATH, FileAccess.WRITE)
		stream.store_buffer(old_settings)
		stream.close()
	else:
		DirAccess.remove_absolute(audio.SETTINGS_PATH)
	# The first SceneTree delta includes startup work, so a game-time timer can
	# expire before the native mixer has consumed the queued stop requests.
	OS.delay_msec(180)
	await process_frame
	if not failed: print("[AUDIO_COMPLETION_PASS] final cues, four categories, settings recovery, UI gesture/pause, bounded overlap, guarded fade")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("[AUDIO_COMPLETION_FAIL] " + message)
