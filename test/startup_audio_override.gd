extends SceneTree
var failed := false
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var audio := root.get_node("GameAudio")
	await process_frame
	var silent := AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.mix_rate = 22050
	silent.data = PackedByteArray([0, 0, 0, 0])
	var custom_cues: Dictionary[StringName, AudioStream] = { &"confirm": silent }
	audio.configure(null, custom_cues)
	for frame in 16:
		await process_frame
	_check(audio._catalog_configured, "explicit configuration was lost")
	_check(audio.music.stream == null, "warm-up replaced deliberately silent music")
	_check(audio._cues.size() == 1 and audio._cues[&"confirm"] == silent, "warm-up replaced custom cues")
	_check(not ResourceLoader.has_cached("res://assets/template/audio/bgm.ogg"), "canceled warm-up loaded music")
	print("STARTUP_AUDIO_OVERRIDE_OK" if not failed else "STARTUP_AUDIO_OVERRIDE_FAILED")
	quit(1 if failed else 0)
func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
