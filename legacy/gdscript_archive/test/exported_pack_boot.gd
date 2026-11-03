extends SceneTree
# Boot check for the EXPORTED pack: unlike editor/headless runs of the project
# directory, this sees only the resources that actually made it into
# dist/index.pck — exactly what the browser will load. It boots the project's
# configured main scene generically, so it keeps working after the game is
# rewritten. It is invoked by scripts/check-exported-pack.mjs.

const SETTLE_FRAMES := 5
const GAME_FONT_PATH := "res://assets/template/fonts/ui_regular.tres"
const REQUIRED_FONT_CHARACTERS := "中文游戏暂停AaZz019，。！？→←↑↓"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for required_path in [
		"res://config/tuning.json",
		"res://autoload/i18n.gd",
		"res://localization/en.json",
		"res://localization/zh-CN.json",
		"res://scripts/viewport_policy.gd",
		"res://scripts/game_audio.gd",
		"res://scripts/yarn_ball.gd",
		"res://scripts/audio_catalog.gd",
		GAME_FONT_PATH,
		"res://scenes/game.tscn",
		"res://scripts/pause_menu.gd",
		"res://scripts/visual_effects.gd",
		"res://scripts/tuning_store.gd",
	]:
		if not FileAccess.file_exists(required_path) and not ResourceLoader.exists(required_path):
			_fail("required game infrastructure missing from the exported PCK: " + required_path)
			return
	var release_profile := OS.get_cmdline_user_args().has("--release-profile")
	var has_tuning := ResourceLoader.exists("res://scripts/tuning_panel.gd")
	if has_tuning:
		_fail("native Tweak UI must be absent from every pack")
		return
	var has_bridge := ResourceLoader.exists("res://scripts/manus/preview/tuning_transport.gd")
	if has_bridge == release_profile:
		_fail("preview must include the Addon bridge; release must exclude it")
		return
	for image_path in ["cat/title-key-art.webp", "cat/warm-background.webp", "cat/cat-tree.webp", "cat/idle.webp", "cat/fish.webp", "cat/robot.webp", "cat/yarn.webp", "cat/felt-ground.webp", "cat/felt-special-block.webp", "cat/run/frame_17.webp"]:
		var image := load("res://assets/template/" + image_path) as Texture2D
		if image == null or image.get_width() <= 0:
			_fail("reference image missing from PCK: " + image_path)
			return
	var catalog = load("res://scripts/audio_catalog.gd")
	var bgm := load(catalog.BGM_PATH) as AudioStream
	if bgm == null or bgm.get_length() <= 0.0:
		_fail("reference BGM is missing or empty")
		return
	for cue in [&"confirm", &"jump", &"land", &"coin", &"stomp", &"checkpoint", &"death", &"success"]:
		var stream := load(catalog.CUE_PATHS[cue]) as AudioStream
		if stream == null or stream.get_length() <= 0.0:
			_fail("reference SFX is missing or empty: " + str(cue))
			return
	var label := Label.new()
	root.add_child(label)
	var font := label.get_theme_font("font")
	label.free()
	if font.resource_path != GAME_FONT_PATH:
		_fail("exported controls do not inherit the bundled CJK font")
		return
	if font == null:
		_fail("exported project did not load the bundled CJK font")
		return
	if not font is FontVariation or not font.get_font_name().begins_with("Nunito"):
		_fail("project font must keep the Nunito primary family")
		return
	var leaks_system := func(f: Font) -> bool: return (f.base_font if f is FontVariation else f).allow_system_fallback
	if font.base_font.allow_system_fallback or font.fallbacks.is_empty() or font.fallbacks.any(leaks_system):
		_fail("exported project font still allows system fallback")
		return
	for character in REQUIRED_FONT_CHARACTERS:
		if not font.has_char(character.unicode_at(0)):
			_fail("exported font is missing required glyph U+%04X" % character.unicode_at(0))
			return
	if font.fallbacks[0].data.size() > 1000000:
		_fail("exported Chinese font exceeds the 1 MB limit")
		return
	var i18n := root.get_node_or_null("I18n")
	if i18n == null:
		_fail("localization autoload missing from the exported PCK")
		return
	var english: Dictionary = i18n.catalog("en")
	var chinese: Dictionary = i18n.catalog("zh-CN")
	if english.is_empty() or english.keys() != chinese.keys():
		_fail("exported localization catalogs are missing or have different keys")
		return
	var previous_locale: String = i18n.get_locale()
	i18n.set_locale("zh-CN")
	if i18n.t("title.play") != "开始游戏" or i18n.t("hud.score", {"score": "123"}) != "分数\n123":
		_fail("exported Chinese title/HUD localization is unavailable")
		return
	i18n.set_locale("en")
	if i18n.t("title.play") != "LET'S PLAY":
		_fail("exported English title localization is unavailable")
		return
	i18n.set_locale(previous_locale)
	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path.is_empty():
		_fail("no main scene configured in project settings")
		return
	if not ResourceLoader.exists(main_scene_path):
		_fail("main scene missing from the exported PCK: " + main_scene_path)
		return
	var packed: PackedScene = load(main_scene_path) as PackedScene
	if packed == null:
		_fail("main scene did not load from the exported PCK: " + main_scene_path)
		return
	var node: Node = packed.instantiate()
	if node == null:
		_fail("main scene did not instantiate: " + main_scene_path)
		return
	root.add_child(node)
	for i in SETTLE_FRAMES:
		await process_frame
	if not node.is_inside_tree():
		_fail("main scene left the tree during boot")
		return
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	if game_scene == null:
		_fail("game scene did not load from the exported PCK")
		return
	var game := game_scene.instantiate()
	root.add_child(game)
	for i in SETTLE_FRAMES:
		await process_frame
	if game.get_node_or_null("PauseMenu") == null or game.get("pause_button") == null or game.get_node_or_null("VisualEffects") == null:
		_fail("pause navigation or visual effects were not created by the exported game scene")
		return
	if root.get_node_or_null("ViewportPolicy") == null:
		_fail("viewport policy autoload is missing from the exported PCK")
		return
	root.size = Vector2i(400, 800)
	var store := root.get_node("TuningStore")
	store.persistence_enabled = false
	for mode in [0, 1]:
		store.set_player_setting("display_mode", mode)
		for i in SETTLE_FRAMES:
			await process_frame
		var viewport_size := root.get_visible_rect().size
		var expected := 16.0 / 9.0 if mode == 0 else 1.0
		if absf(viewport_size.x / viewport_size.y - expected) > 0.002:
			_fail("exported viewport did not apply Display mode %d" % mode)
			return
	game.queue_free()
	node.queue_free()
	await process_frame
	root.get_node("GameAudio").stop_game()
	# Let the native mixer consume stopped voices before engine teardown.
	await create_timer(0.15).timeout
	print("[PCK_BOOT_PASS] main scene booted: " + main_scene_path)
	quit(0)


func _fail(message: String) -> void:
	push_error("[PCK_BOOT_FAIL] " + message)
	quit(1)
