extends Control
const OpenSourceLicenses = preload("res://scripts/manus/open_source_licenses.gd")

const BACKGROUND = preload("res://assets/template/cat/title-key-art.webp")
const BACKDROP = preload("res://assets/template/cat/warm-background.webp")
const STYLE = preload("res://scripts/menu_style.gd")
const SETTINGS = preload("res://scripts/settings_panel.gd")
const LEADERBOARD = preload("res://scripts/leaderboard_panel.gd")
var starting := false
var _localized_labels: Array[Dictionary] = []
var _locale_buttons: Dictionary = {}
var _start_button: Button
var _name_entry: LineEdit
var _name_error: Label
var _modal: CanvasLayer
var _title_panel: PanelContainer
var _title_scroll: ScrollContainer
var _actions: GridContainer
var _language_caption: Label
var _brand: Label
var _title: Label
var _subtitle: Label
var _profile_caption: Label
var _body: VBoxContainer
var _lockup: VBoxContainer
var _brand_pill: PanelContainer
var _meta_row: HBoxContainer
var _best: Label
var _footer: HBoxContainer
var _licenses: Button
var _controls_pill: PanelContainer
var _controls: Label
var _subtitle_gap: Control
var _ambience: Control
var _cursor: Control
var _title_yarn: Control
var _divider: Control
var _veil: ColorRect
var _vignette: GradientTexture2D
var _intro := 0.0
var _lockup_top := 0.0
var _stagger: Array[Control] = []

func _ready() -> void:
	GameAudio.begin_title()
	build_ui()
	if FeltKit.reduced_motion(): _intro = 10.0
	_animate(0.0)
	I18n.locale_changed.connect(_refresh_locale)
	get_viewport().size_changed.connect(_layout)

func _draw() -> void:
	var size := get_viewport_rect().size
	var texture_size := BACKDROP.get_size()
	var scale_factor := maxf(size.x / texture_size.x, size.y / texture_size.y)
	var source_size := size / scale_factor
	draw_texture_rect_region(BACKDROP, Rect2(Vector2.ZERO, size), Rect2((texture_size - source_size) * 0.5, source_size))
	draw_texture_rect(BACKGROUND, key_art_rect(), false)
	# Warm felt vignette pulls the eye to the lockup and menu.
	if _vignette == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		gradient.colors = PackedColorArray([Color(0.3, 0.12, 0.04, 0.0), Color(0.3, 0.12, 0.04, 0.05), Color(0.26, 0.1, 0.03, 0.42)])
		_vignette = GradientTexture2D.new()
		_vignette.gradient = gradient
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.42)
		_vignette.fill_to = Vector2(1.08, 0.42)
		_vignette.width = 256
		_vignette.height = 256
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)

func key_art_rect() -> Rect2:
	var size := get_viewport_rect().size
	var texture_size := BACKGROUND.get_size()
	var art_size := texture_size * minf(size.x / texture_size.x, size.y / texture_size.y)
	return Rect2((size - art_size) * 0.5, art_size)

func _copy(key: String, font_size: int, placeholders: Dictionary = {}) -> Label:
	var label := STYLE.label(I18n.t(key, placeholders), font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_localized_labels.append({"control": label, "key": key, "placeholders": placeholders})
	return label

func _button(key: String, action: Callable, primary: bool = false) -> Button:
	var button := STYLE.button(I18n.t(key), primary)
	button.pressed.connect(action)
	_localized_labels.append({"control": button, "key": key, "placeholders": {}})
	return button

func _field_style(fill: Color) -> StyleBoxFlat:
	var style := STYLE.plate(fill, 0)
	style.set_corner_radius_all(14)
	style.border_color = Color(STYLE.STITCH, 0.5)
	style.set_border_width_all(0)
	style.border_width_bottom = 3
	style.content_margin_left = 44
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func build_ui() -> void:
	# Drifting wool fluff and felt fish live between the key art and the UI.
	_ambience = FeltKit.FeltAmbience.new()
	add_child(_ambience)
	# Title lockup sits in the open felt sky above the menu plaque, leaving the
	# calico, yarn and robot vacuum of the key art uncovered.
	_lockup = VBoxContainer.new()
	_lockup.name = "TitleLockup"
	_lockup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lockup.add_theme_constant_override("separation", 6)
	add_child(_lockup)
	_brand_pill = PanelContainer.new()
	_brand_pill.name = "BrandPill"
	_brand_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ribbon_box := StyleBoxEmpty.new()
	ribbon_box.content_margin_left = 40
	ribbon_box.content_margin_right = 40
	ribbon_box.content_margin_top = 5
	ribbon_box.content_margin_bottom = 7
	_brand_pill.add_theme_stylebox_override("panel", ribbon_box)
	_brand_pill.material = FeltKit.felt_material()
	_brand_pill.draw.connect(func():
		var tail := 26.0
		FeltKit.draw_ribbon(_brand_pill, Rect2(Vector2(tail, 0), _brand_pill.size - Vector2(tail * 2.0, 0)), Color("#7a4128")))
	_lockup.add_child(_brand_pill)
	_brand = _copy("title.brand", 14)
	_brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	_brand.add_theme_color_override("font_color", Color("#fff1d6"))
	_brand_pill.add_child(_brand)
	_title = _copy("title.name", 84)
	STYLE.display(_title, 84, Color("#fff6e2"), STYLE.COCOA, 18)
	_lockup.add_child(_title)
	# A loose yarn ball rolls into the lockup and leaves its thread under the title.
	_title_yarn = Control.new()
	_title_yarn.name = "TitleYarn"
	_title_yarn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_yarn.draw.connect(_draw_title_yarn)
	_title.add_child(_title_yarn)
	_title_yarn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_subtitle_gap = Control.new()
	var subtitle_gap := _subtitle_gap
	subtitle_gap.custom_minimum_size.y = 4
	subtitle_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lockup.add_child(subtitle_gap)
	_subtitle = _copy("title.subtitle", 20)
	_subtitle.add_theme_color_override("font_color", STYLE.INK)
	_subtitle.add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.84, 0.92))
	_subtitle.add_theme_constant_override("outline_size", 8)
	_lockup.add_child(_subtitle)

	var center := CenterContainer.new()
	center.name = "ResponsiveCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_title_panel = PanelContainer.new()
	_title_panel.name = "Content"
	STYLE.felt_card(_title_panel, Color(1, 0.955, 0.86, 0.97), 22)
	center.add_child(_title_panel)
	_title_scroll = ScrollContainer.new()
	_title_scroll.name = "TitleScroll"
	_title_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_title_scroll.follow_focus = true
	_title_panel.add_child(_title_scroll)
	var body := VBoxContainer.new()
	_body = body
	body.name = "TitleBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_title_scroll.add_child(body)
	var name_row := VBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	body.add_child(name_row)
	_profile_caption = _copy("profile.name", 13)
	_profile_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_profile_caption.add_theme_color_override("font_color", STYLE.MUTED)
	name_row.add_child(_profile_caption)
	_name_entry = LineEdit.new()
	_name_entry.name = "PlayerName"
	_name_entry.text = SaveStore.player_name()
	_name_entry.max_length = SaveStore.NAME_LIMIT
	_name_entry.add_theme_font_override("font", STYLE.BOLD)
	_name_entry.add_theme_font_size_override("font_size", 20)
	_name_entry.custom_minimum_size.y = 46
	_name_entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_entry.add_theme_color_override("font_color", STYLE.COCOA)
	_name_entry.add_theme_color_override("font_placeholder_color", Color(STYLE.MUTED, 0.7))
	_name_entry.add_theme_color_override("caret_color", STYLE.ACCENT)
	_name_entry.add_theme_color_override("selection_color", Color(STYLE.ACCENT, 0.3))
	_name_entry.add_theme_stylebox_override("normal", _field_style(Color("#f3dcb4")))
	_name_entry.add_theme_stylebox_override("focus", _field_style(Color("#f7e4c2")))
	_name_entry.material = FeltKit.felt_material()
	# A sewn-on name tag: a running stitch and a little felt button on the left.
	_name_entry.draw.connect(func():
		var focused := _name_entry.has_focus()
		FeltKit.draw_stitches(_name_entry, Rect2(Vector2.ZERO, _name_entry.size).grow(-5), 9, STYLE.COCOA if focused else Color(STYLE.STITCH, 0.95), 2.0 if focused else 1.6, 6, 4)
		FeltKit.draw_sewn_button(_name_entry, Vector2(24, _name_entry.size.y * 0.5), 9, FeltKit.TEAL))
	_name_entry.focus_entered.connect(_name_entry.queue_redraw)
	_name_entry.focus_exited.connect(_name_entry.queue_redraw)
	_name_entry.text_changed.connect(func(_value: String): _name_error.hide())
	_name_entry.text_submitted.connect(func(_value: String): start_game())
	name_row.add_child(_name_entry)
	_name_error = _copy("profile.invalid", 15)
	_name_error.add_theme_color_override("font_color", Color("#a22920"))
	_name_error.hide()
	body.add_child(_name_error)
	_start_button = _button("title.play", start_game, true)
	_start_button.name = "StartButton"
	_start_button.custom_minimum_size.y = 60
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.get_node("FeltFace").key_hint = "ENTER"
	body.add_child(_start_button)
	var actions := GridContainer.new()
	_actions = actions
	actions.columns = 3
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 2)
	body.add_child(actions)
	var badges := [FeltKit.MUSTARD, FeltKit.TEAL, FeltKit.ROSE]
	var pairs := [["title.leaderboard", _open_leaderboard], ["settings.title", _open_settings], ["title.tutorial", _replay_tutorial]]
	for index in pairs.size():
		var pair: Array = pairs[index]
		var button := _button(pair[0], pair[1])
		STYLE.menu_item(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 16)
		_bullet(button, badges[index])
		actions.add_child(button)
	# Running-stitch divider instead of a hairline rule.
	_divider = Control.new()
	_divider.name = "StitchDivider"
	_divider.custom_minimum_size.y = 8
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_divider.draw.connect(func(): FeltKit.draw_dashes(_divider, Vector2(4, 4), Vector2(_divider.size.x - 4, 4), Color(STYLE.STITCH, 0.8), 2.0, 8, 6))
	body.add_child(_divider)
	_meta_row = HBoxContainer.new()
	_meta_row.name = "MetaRow"
	_meta_row.add_theme_constant_override("separation", 12)
	body.add_child(_meta_row)
	build_language_selector(_meta_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta_row.add_child(spacer)
	var star := Control.new()
	star.name = "BestStar"
	star.custom_minimum_size = Vector2(24, 24)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.draw.connect(func(): FeltKit.draw_star(star, star.size * 0.5, 11, FeltKit.MUSTARD))
	_meta_row.add_child(star)
	_best = _copy("title.best", 20, {"score": "%06d" % SaveStore.best_score()})
	_best.name = "BestScore"
	_best.autowrap_mode = TextServer.AUTOWRAP_OFF
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_best.add_theme_font_override("font", STYLE.BOLD)
	_best.add_theme_font_size_override("font_size", 17)
	_best.add_theme_color_override("font_color", STYLE.COCOA)
	_meta_row.add_child(_best)

	_footer = HBoxContainer.new()
	_footer.name = "TitleFooter"
	_footer.add_theme_constant_override("separation", 16)
	_footer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)
	_licenses = STYLE.quiet_button(I18n.t("ui.open_source_licenses"))
	_licenses.pressed.connect(OpenSourceLicenses.open.bind(self))
	_localized_labels.append({"control": _licenses, "key": "ui.open_source_licenses", "placeholders": {}})
	_licenses.name = "OpenSourceLicensesButton"
	_licenses.size_flags_vertical = Control.SIZE_SHRINK_END
	_footer.add_child(_licenses)
	_controls_pill = PanelContainer.new()
	_controls_pill.name = "ControlsHint"
	_controls_pill.size_flags_vertical = Control.SIZE_SHRINK_END
	_controls_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_style := STYLE.pill(Color(0.3, 0.16, 0.09, 0.72), 22, 9)
	hint_style.set_corner_radius_all(16)
	_controls_pill.add_theme_stylebox_override("panel", hint_style)
	_controls_pill.set_meta("felt_thread", Color(1.0, 0.94, 0.82, 0.5))
	FeltKit.decorate_panel(_controls_pill, Color(1.0, 0.94, 0.82, 0.5), 4.0)
	add_child(_controls_pill)
	_controls = _copy("title.controls", 13)
	_controls.name = "ControlsText"
	_controls.add_theme_constant_override("line_spacing", 1)
	_controls_pill.add_child(_controls)
	# The yarn-ball selection cursor rolls between focused/hovered menu items.
	_cursor = FeltKit.YarnCursor.new()
	add_child(_cursor)
	for control: Control in [_start_button, _name_entry] + _actions.get_children() + _locale_buttons.values():
		_cursor.track(control)
	_veil = ColorRect.new()
	_veil.name = "FadeVeil"
	_veil.color = Color("#3a1d0f")
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	_stagger = [_name_entry, _start_button]
	_stagger.append_array(_actions.get_children())
	_stagger.append(_meta_row)
	_layout()
	_start_button.grab_focus()
	_reveal_start.call_deferred()

## Small sewn button bullet on menu items (drawn by the item's felt face).
func _bullet(button: Button, color: Color) -> void:
	var face := button.get_node("FeltFace")
	face.badge_color = color
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := button.get_theme_stylebox(state).duplicate() as StyleBoxEmpty
		box.content_margin_left = 30
		box.content_margin_right = 6
		button.add_theme_stylebox_override(state, box)

func _draw_title_yarn() -> void:
	var font := _title.get_theme_font("font")
	var font_size := _title.get_theme_font_size("font_size")
	var lines := _title.text.split("\n")
	var last := lines[lines.size() - 1]
	var width := font.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var line_h := _title.size.y / maxf(1.0, lines.size())
	var right := _title.size.x * 0.5 + width * 0.5
	var r := clampf(font_size * 0.22, 8.0, 22.0)
	var c := Vector2(right + r * 0.9, _title.size.y - line_h * 0.3)
	var roll := clampf((_intro - 0.55) / 0.6, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - roll, 3.0)
	var start := c + Vector2(r * 6.0, 0)
	var ball := start.lerp(c, eased)
	if roll <= 0.0: return
	var thread := PackedVector2Array()
	var left := _title.size.x * 0.5 - width * 0.5 + r
	var steps := 28
	for i in steps + 1:
		var t := float(i) / steps
		var x := lerpf(ball.x - r * 0.6, lerpf(ball.x, left, eased), t)
		var y := ball.y + r * 0.75 + sin(t * TAU * 1.5 + _intro * 1.2) * r * 0.22 * t
		thread.append(Vector2(x, y))
	_title_yarn.draw_polyline(thread, Color("#c8453a"), maxf(2.0, r * 0.16), true)
	FeltKit.draw_yarn(_title_yarn, ball, r, (1.0 - eased) * -6.0 + sin(_intro * 0.8) * 0.08)

func _process(delta: float) -> void:
	_intro += delta
	_animate(delta)

static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

static func _back(x: float) -> float:
	var k := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * k * k * k + 1.70158 * k * k

## Felt "plop": the lockup falls in and bounces twice before resting.
static func _plop(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x < 1.0 / 2.75: return 7.5625 * x * x
	if x < 2.0 / 2.75:
		x -= 1.5 / 2.75
		return 7.5625 * x * x + 0.75
	if x < 2.5 / 2.75:
		x -= 2.25 / 2.75
		return 7.5625 * x * x + 0.9375
	x -= 2.625 / 2.75
	return 7.5625 * x * x + 0.984375

## Entrance: veil fade, lockup plop, plaque settle, staggered items, footer;
## afterwards a slow idle bob. Reduced motion shows the settled layout at once.
func _animate(_delta: float) -> void:
	if _title_panel == null: return
	var still := FeltKit.reduced_motion()
	var t := 10.0 if still else _intro
	_veil.modulate.a = 1.0 - _ease_out(t / 0.4)
	_veil.visible = _veil.modulate.a > 0.001
	var drop := _plop((t - 0.08) / 0.95)
	var idle := 0.0 if still else clampf(t - 1.2, 0.0, 1.0)
	_lockup.pivot_offset = _lockup.size * Vector2(0.5, 0.45)
	_lockup.scale = Vector2.ONE * lerpf(0.9, 1.0, drop)
	_lockup.position.y = _lockup_top - (1.0 - drop) * 190.0 + sin(t * 1.7) * 3.0 * idle
	_lockup.rotation = sin(t * 0.8) * 0.01 * idle
	_lockup.modulate.a = clampf(t / 0.25, 0.0, 1.0)
	# The plaque fades in while its running stitch sews itself around the edge
	# (geometry stays put, so early clicks/taps land where they are drawn).
	var settle := _ease_out((t - 0.3) / 0.4)
	_title_panel.modulate.a = settle
	var sewn := _ease_out((t - 0.35) / 1.0)
	if not is_equal_approx(float(_title_panel.get_meta("stitch_progress", 1.0)), sewn):
		_title_panel.set_meta("stitch_progress", sewn)
		_title_panel.queue_redraw()
	for index in _stagger.size():
		var start := 0.5 + index * 0.07
		var item := _stagger[index]
		item.modulate.a = clampf((t - start) / 0.22, 0.0, 1.0)
		var face := item.get_node_or_null("FeltFace")
		if face != null and t < 2.0: face.pop = lerpf(0.72, 1.0, _back((t - start) / 0.4))
	_cursor.modulate.a = clampf((t - 0.8) / 0.3, 0.0, 1.0)
	var footer := clampf((t - 0.9) / 0.4, 0.0, 1.0)
	_footer.modulate.a = footer
	_controls_pill.modulate.a = footer
	_ambience.modulate.a = clampf(t / 1.2, 0.0, 1.0)
	if t < 3.0 or not still: _title_yarn.queue_redraw()

func _reveal_start() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	_layout()
	_title_scroll.ensure_control_visible(_start_button)

func _place(node: Control, parent: Node, index: int = -1) -> void:
	if node.get_parent() != parent:
		node.get_parent().remove_child(node)
		parent.add_child(node)
	if index >= 0: parent.move_child(node, mini(index, parent.get_child_count() - 1))

func _layout() -> void:
	queue_redraw()
	if _title_panel == null: return
	var size := get_viewport_rect().size
	var wide := size.x >= 960.0 and size.y >= 600.0
	var short := size.y < 360.0
	var compact := not wide
	# Wide layouts keep licenses and control hints in a quiet footer strip that
	# shares the Tweak Controls baseline; compact layouts fold them into the card.
	_place(_licenses, _footer if wide else _body)
	_place(_controls, _controls_pill if wide else _body, -1 if wide else _body.get_child_count())
	if not wide: _body.move_child(_licenses, _body.get_child_count() - 1)
	_footer.visible = wide
	_licenses.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_SHRINK_CENTER
	STYLE.quiet_on_card(_licenses, not wide)
	_controls.add_theme_color_override("font_color", Color("#fff1d6") if wide else STYLE.MUTED)
	_controls.add_theme_font_size_override("font_size", 13 if wide else 14)
	_controls.autowrap_mode = TextServer.AUTOWRAP_OFF if wide else TextServer.AUTOWRAP_WORD_SMART
	var footer_h := maxf(44.0, _controls_pill.get_combined_minimum_size().y) if wide else 0.0
	var reserved := maxf(12.0, footer_h + 16.0 if wide else 0.0)
	_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_left = 24
	_footer.offset_right = -24.0
	_footer.offset_bottom = -16
	_footer.offset_top = -60
	_controls_pill.visible = wide
	var hint_size := _controls_pill.get_combined_minimum_size()
	_controls_pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_pill.offset_left = -roundf(hint_size.x * 0.5)
	_controls_pill.offset_right = _controls_pill.offset_left + hint_size.x
	_controls_pill.offset_bottom = -16
	_controls_pill.offset_top = -16 - hint_size.y
	# Lockup: display title in the felt sky.
	var title_size := 28 if short else (50 if compact else clampi(roundi(size.y * 0.11), 64, 96))
	_title.text = I18n.t("title.name").replace("\n", " ") if short else I18n.t("title.name")
	STYLE.display(_title, title_size, Color("#fff6e2"), STYLE.COCOA, maxi(6, roundi(title_size * 0.2)))
	_title.add_theme_constant_override("line_spacing", roundi(title_size * 0.02))
	_brand_pill.visible = size.y >= 480.0
	_subtitle.visible = not short
	_subtitle_gap.visible = not short
	# Landscape phones: the card's Start must own the first fold.
	_lockup.visible = size.y >= 280.0
	_subtitle.add_theme_font_size_override("font_size", 16 if compact else 20)
	_brand.add_theme_font_override("font", STYLE.tracked(STYLE.BOLD, 3))
	_brand.add_theme_font_size_override("font_size", 13 if compact else 14)
	_lockup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_lockup.offset_left = 16
	_lockup.offset_right = -16
	_lockup.offset_top = 8.0 if short else (16.0 if compact else roundf(size.y * 0.036))
	_lockup.offset_bottom = _lockup.offset_top + _lockup.get_combined_minimum_size().y
	_lockup_top = _lockup.offset_top
	var center: Control = get_node("ResponsiveCenter")
	center.offset_top = (_lockup.offset_bottom + (4.0 if short else 12.0)) if _lockup.visible else 0.0
	center.offset_bottom = -reserved
	var available := Vector2(size.x - 24.0, size.y - center.offset_top - reserved - 8.0)
	var card_w := minf(460.0 if wide else 560.0, available.x)
	_title_panel.custom_minimum_size = Vector2(card_w, 0)
	var margin := 12 if short else (16 if compact else 20)
	_title_panel.add_theme_stylebox_override("panel", STYLE.card(Color(1, 0.955, 0.86, 0.97), margin))
	_title_panel.queue_redraw()
	var natural := _body.get_combined_minimum_size().y
	_title_scroll.custom_minimum_size = Vector2(0, clampf(natural, 12.0, maxf(12.0, available.y - margin * 2.0)))
	_actions.columns = 1 if available.x < 440.0 else 3
	if _language_caption != null: _language_caption.visible = available.x >= 520.0
	# The field placeholder names the field; compact folds spend the height on Start.
	_profile_caption.visible = size.y >= 480.0
	_start_button.custom_minimum_size.y = 48 if compact else 60
	_start_button.add_theme_font_override("font", STYLE.tracked(STYLE.BOLD, 2))
	_profile_caption.add_theme_font_override("font", STYLE.tracked(STYLE.BOLD, 2))
	if _language_caption != null: _language_caption.add_theme_font_override("font", STYLE.tracked(STYLE.BOLD, 2))
	_best.add_theme_font_override("font", STYLE.tracked(STYLE.BOLD, 1))
	var narrow := available.x < 380.0
	_best.add_theme_font_size_override("font_size", 17 if available.x >= 520.0 else (13 if narrow else 15))
	_meta_row.get_node("BestStar").visible = not narrow
	_meta_row.add_theme_constant_override("separation", 6 if narrow else 12)
	for button: Button in _locale_buttons.values(): button.custom_minimum_size.x = 50 if narrow else 60
	_keep_start_visible.call_deferred()

func _keep_start_visible() -> void:
	if not is_inside_tree() or _start_button == null: return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or focused == _start_button:
		_title_scroll.scroll_vertical = 0
		_title_scroll.ensure_control_visible(_start_button)

func build_language_selector(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "LanguageSelector"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	_language_caption = _copy("language.label", 13)
	_language_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_language_caption.add_theme_color_override("font_color", STYLE.MUTED)
	# Fixed caption slot keeps EN/CN in place when the locale (caption width) flips.
	_language_caption.custom_minimum_size.x = 92
	_language_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(_language_caption)
	var gap := Control.new()
	gap.custom_minimum_size.x = 4
	row.add_child(gap)
	var group := ButtonGroup.new()
	for locale: String in ["en", "zh-CN"]:
		var button := STYLE.button(I18n.t("language.short.en" if locale == "en" else "language.short.cn"))
		button.name = "LanguageEN" if locale == "en" else "LanguageCN"
		button.custom_minimum_size = Vector2(60, 44)
		button.add_theme_font_size_override("font_size", 16)
		button.toggle_mode = true
		button.button_group = group
		# Felt tab segments: the selected language is sewn down in cocoa felt.
		FeltKit.felt_button(button, &"tab", STYLE.WOOL, STYLE.STITCH, 14.0, 8.0)
		for key in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(key, Color("#fff4dd"))
		button.pressed.connect(func(): I18n.set_locale(locale))
		row.add_child(button)
		_locale_buttons[locale] = button
	_locale_buttons["en"].focus_neighbor_right = _locale_buttons["en"].get_path_to(_locale_buttons["zh-CN"])
	_locale_buttons["zh-CN"].focus_neighbor_left = _locale_buttons["zh-CN"].get_path_to(_locale_buttons["en"])
	_refresh_locale()

func _refresh_locale(_locale: String = "") -> void:
	for entry: Dictionary in _localized_labels:
		entry.control.text = I18n.t(entry.key, entry.placeholders)
		if entry.control is Button: entry.control.accessibility_name = entry.control.text
	_name_entry.placeholder_text = I18n.t("profile.placeholder")
	_name_entry.accessibility_name = I18n.t("profile.name")
	for locale: String in _locale_buttons:
		var button: Button = _locale_buttons[locale]
		button.set_pressed_no_signal(locale == I18n.get_locale())
		button.tooltip_text = I18n.t("language.english" if locale == "en" else "language.chinese")
		button.accessibility_name = button.tooltip_text
	if _title_panel != null and _start_button != null and _footer != null: _layout()

func _open_panel(script: Script) -> void:
	if is_instance_valid(_modal): return
	_modal = script.new()
	add_child(_modal)
	_modal.open_panel()

func _open_settings() -> void:
	_open_panel(SETTINGS)

func _open_leaderboard() -> void:
	_open_panel(LEADERBOARD)

func _replay_tutorial() -> void:
	SaveStore.request_tutorial_replay()
	start_game()

func start_game() -> void:
	if starting or get_tree().paused or is_instance_valid(_modal): return
	if not SaveStore.set_player_name(_name_entry.text):
		_name_error.text = I18n.t("profile.invalid" if not SaveStore.valid_player_name(_name_entry.text) else "profile.save_failed")
		_name_error.show()
		_name_entry.grab_focus()
		GameAudio.play_ui(&"invalid")
		return
	starting = true
	GameAudio.begin_game()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused: return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		var button := get_viewport().gui_get_focus_owner() as Button
		if button != null:
			button.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("start"):
		var focused := get_viewport().gui_get_focus_owner()
		if focused == null or focused == _start_button:
			start_game()
			get_viewport().set_input_as_handled()
