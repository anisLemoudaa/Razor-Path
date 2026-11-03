extends SceneTree

const LANGUAGE_SERVICE := preload("res://autoload/i18n.gd")
const FONT := preload("res://assets/template/fonts/ui_regular.tres")
var failures: Array[String] = []
var _original_preference := ""
var _had_preference := false


class PinnedSystemLanguageService:
	extends "res://autoload/i18n.gd"
	var system := "en_US"

	func _system_locale() -> String:
		return system


class MirroredLanguageService:
	extends "res://autoload/i18n.gd"
	var mirrored: Variant = null
	var synced := ""
	var system := "en_US"

	func _read_web_locale() -> Variant:
		return mirrored

	func _system_locale() -> String:
		return system

	func _sync_web_locale() -> void:
		synced = get_locale()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# These checks write preferences; callers must isolate user:// before launch.
	print("LOCALIZATION_USER_DATA=", OS.get_user_data_dir())
	if not OS.get_user_data_dir().get_file().begins_with("PlatformerLocalizationTests-"):
		push_error("Use an isolated PlatformerLocalizationTests- user directory for this test.")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	var i18n := root.get_node("I18n")
	_had_preference = FileAccess.file_exists(LANGUAGE_SERVICE.PREFERENCE_PATH)
	if _had_preference:
		_original_preference = FileAccess.get_file_as_string(LANGUAGE_SERVICE.PREFERENCE_PATH)
	var english: Dictionary = i18n.catalog("en")
	var chinese: Dictionary = i18n.catalog("zh-CN")
	_check(english.keys() == chinese.keys(), "catalog keys must match")
	var token_pattern := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for key: String in english:
		var en_tokens: Array[String] = []
		var cn_tokens: Array[String] = []
		for token: RegExMatch in token_pattern.search_all(english[key]): en_tokens.append(token.get_string(1))
		for token: RegExMatch in token_pattern.search_all(chinese[key]): cn_tokens.append(token.get_string(1))
		en_tokens.sort()
		cn_tokens.sort()
		_check(en_tokens == cn_tokens, "placeholder parity: " + key)
		for copy: String in [english[key], chinese[key]]:
			for character: String in copy:
				if character not in ["\n", "\r", "\t"]:
					_check(FONT.has_char(character.unicode_at(0)), "bundled glyph missing: " + character + " (" + key + ")")
	_check(FONT.get_font_name().begins_with("Nunito"), "Latin UI font is Nunito")
	# Noto Sans SC (FontVariation) is the bundled Chinese fallback; every link must stay bundled.
	var leaks_system := func(f: Font) -> bool: return (f.base_font if f is FontVariation else f).allow_system_fallback
	_check(not FONT.base_font.allow_system_fallback and not FONT.fallbacks.any(leaks_system), "no hidden system font fallback")
	for saved: String in ["en", "zh-CN", "unsupported", ""]:
		var config := ConfigFile.new()
		if not saved.is_empty(): config.set_value("language", "locale", saved)
		_check(config.save(LANGUAGE_SERVICE.PREFERENCE_PATH) == OK, "write preference fixture")
		for system: String in ["en_US", "zh_CN"]:
			var restarted := PinnedSystemLanguageService.new()
			restarted.system = system
			root.add_child(restarted)
			var fallback := "zh-CN" if system == "zh_CN" else "en"
			_check(restarted.get_locale() == (saved if saved in ["en", "zh-CN"] else fallback), "valid preference survives startup; invalid follows the system language")
			restarted.free()
	# First-launch detection maps any zh* system/browser language to Simplified Chinese, everything else to EN.
	for pair: Array in [["zh_CN", "zh-CN"], ["zh-TW", "zh-CN"], ["zh", "zh-CN"], ["ZH_hans", "zh-CN"], ["en_US", "en"], ["en", "en"], ["fr_FR", "en"], ["ja", "en"], ["", "en"]]:
		_check(LANGUAGE_SERVICE.locale_for_system(pair[0]) == pair[1], "system locale %s maps to %s" % pair)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LANGUAGE_SERVICE.PREFERENCE_PATH))
	for system: String in ["zh_CN", "en_GB"]:
		var fresh := PinnedSystemLanguageService.new()
		fresh.system = system
		root.add_child(fresh)
		_check(fresh.get_locale() == LANGUAGE_SERVICE.locale_for_system(system), "first launch without a saved choice follows the system language: " + system)
		fresh.free()
	# Exercise the real startup resolver while substituting only the browser boundary.
	# A valid cfg wins; missing/invalid cfg permits a valid mirror, then falls back to EN.
	for saved: Variant in [null, "", "unsupported", "en", "zh-CN"]:
		for mirrored: Variant in [null, "", "unsupported", false, 7, "en", "zh-CN"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LANGUAGE_SERVICE.PREFERENCE_PATH))
			if saved != null:
				var config := ConfigFile.new()
				if saved != "": config.set_value("language", "locale", saved)
				_check(config.save(LANGUAGE_SERVICE.PREFERENCE_PATH) == OK, "write mirror precedence fixture")
			var restarted := MirroredLanguageService.new()
			restarted.mirrored = mirrored
			root.add_child(restarted)
			var expected := "en"
			if mirrored is String and mirrored in LANGUAGE_SERVICE.SUPPORTED_LOCALES: expected = mirrored
			if saved is String and saved in LANGUAGE_SERVICE.SUPPORTED_LOCALES: expected = saved
			_check(restarted.get_locale() == expected, "startup cfg/mirror precedence: %s / %s" % [str(saved), str(mirrored)])
			_check(restarted.synced == expected, "startup must sync the resolved choice without overwriting a valid mirror")
			restarted.free()
	for locale: String in ["en", "zh-CN"]:
		i18n.set_locale(locale)
		var title = load("res://scenes/title_screen.tscn").instantiate()
		root.add_child(title)
		await process_frame
		await process_frame
		var en: Button = title.find_child("LanguageEN", true, false)
		var cn: Button = title.find_child("LanguageCN", true, false)
		_check(en != null and cn != null, "title must expose both language choices")
		_check(en.button_pressed == (locale == "en") and cn.button_pressed == (locale == "zh-CN"), "active language feedback")
		# Real mouse and touch events exercise Control consumption before title start.
		await _click(cn, false)
		_check(i18n.get_locale() == "zh-CN" and not title.starting, "mouse selects CN without starting")
		await _click(en, true)
		_check(i18n.get_locale() == "en" and not title.starting, "touch selects EN without starting")
		cn.grab_focus()
		await _key(KEY_SPACE)
		_check(i18n.get_locale() == "zh-CN" and not title.starting, "keyboard selects CN without starting")
		await _joy_button(JOY_BUTTON_DPAD_LEFT)
		_check(root.gui_get_focus_owner() == en, "controller D-pad can reach the English selector")
		await _joy_button(JOY_BUTTON_A)
		_check(i18n.get_locale() == "en" and not title.starting, "controller selects EN without starting")
		i18n.set_locale(locale)
		_check(title.find_child("StartButton", true, false).text == i18n.t("title.play"), "title updates immediately")
		title.queue_free()
		await process_frame
		var game = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		await process_frame
		_check(game.score_label.text == i18n.t("hud.score", {"score": "000000"}), "game HUD retains chosen locale")
		game.pause_menu.open_menu()
		_check(game.pause_menu.resume_button.text == i18n.t("pause.resume"), "pause uses chosen locale")
		game.pause_menu.close_menu()
		game.show_message(i18n.t("result.victory"), i18n.t("result.score", {"score": "001234"}))
		var result_heading: Label = game.message_panel.find_child("ResultHeading", true, false)
		_check(result_heading != null and result_heading.text == i18n.t("result.victory"), "results use chosen locale")
		game.queue_free()
		await process_frame
		var returned = load("res://scenes/title_screen.tscn").instantiate()
		root.add_child(returned)
		await process_frame
		_check(returned.find_child("StartButton", true, false).text == i18n.t("title.play"), "return to title retains chosen locale")
		returned.queue_free()
		await process_frame
	_check(not i18n.set_locale("unsupported") and i18n.get_locale() == "zh-CN", "unsupported manual choice preserves active locale")
	if _had_preference:
		var file := FileAccess.open(LANGUAGE_SERVICE.PREFERENCE_PATH, FileAccess.WRITE)
		file.store_string(_original_preference)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LANGUAGE_SERVICE.PREFERENCE_PATH))
	for failure: String in failures: push_error(failure)
	if failures.is_empty(): print("[LOCALIZATION_PASS] catalogs, glyphs, saved cfg/browser choice and precedence, title mouse/touch/keyboard/controller input, HUD/pause/tuning/results and return")
	root.get_node("GameAudio").stop_game()
	OS.delay_msec(180)
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _click(button: Button, touch: bool) -> void:
	var position := root.get_final_transform() * button.get_global_rect().get_center()
	if touch:
		for pressed: bool in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = position
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
	else:
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _joy_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
