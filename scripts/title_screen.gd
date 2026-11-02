extends Control

const BODY_FONT = preload("res://assets/template/fonts/ui_medium.tres")
const BOLD_FONT = preload("res://assets/template/fonts/ui_bold.tres")
const DISPLAY_FONT = preload("res://assets/template/fonts/display/display_title.tres")
const PREVIEW = preload("res://scripts/title_preview.gd")
const SETTINGS = preload("res://scripts/settings_panel.gd")
const LEADERBOARD = preload("res://scripts/leaderboard_panel.gd")

const BG := Color("#07040f")
const PANEL := Color("#120c20")
const PANEL_2 := Color("#1a1233")
const GOLD := Color("#e0b13e")
const GOLD_LIGHT := Color("#fff0b0")
const MUTED := Color("#a89a72")
const INK := Color("#241609")

var _notice: PanelContainer
var _start_button: Button
var _modal: CanvasLayer
var _margin_container: MarginContainer
var _hero_panel: PanelContainer
var _content_box: VBoxContainer
var _logo_label: Label
var _subtitle_label: Label
var _best_label: Label
var _hint_label: Label

func _ready() -> void:
	get_tree().paused = false
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	queue_redraw()
	_build_ui()
	get_viewport().size_changed.connect(queue_redraw)

func _draw() -> void:
	var s := size
	for i in 16:
		var t := float(i) / 15.0
		draw_rect(Rect2(0, s.y * t, s.x, s.y / 15.0 + 2), BG.lerp(Color("#24183d"), t * 0.72), true)
	var center := Vector2(s.x * 0.72, s.y * 0.44)
	for i in 5:
		draw_arc(center, 90.0 + i * 22.0, -1.1, 2.1, 42, Color(0.84, 0.62, 0.2, 0.16 - i * 0.025), 1.0, true)
	for i in 22:
		var x := fmod(36.0 + i * 113.0, s.x)
		var y := 24.0 + fmod(i * 47.0, maxf(120.0, s.y * 0.52))
		draw_circle(Vector2(x, y), 1.0 + float(i % 3), Color(1.0, 0.88, 0.52, 0.32 + float(i % 4) * 0.08))

func _build_ui() -> void:
	var margin := MarginContainer.new()
	_margin_container = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(row)

	var hero := PanelContainer.new()
	_hero_panel = hero
	hero.custom_minimum_size = Vector2(390, 0)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.045, 0.13, 0.74), Color(0.84, 0.62, 0.2, 0.48), 26))
	row.add_child(hero)
	var art := PREVIEW.new()
	art.custom_minimum_size = Vector2(320, 390)
	hero.add_child(art)

	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(500, 0)
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 26))
	row.add_child(content_panel)
	var content := VBoxContainer.new()
	_content_box = content
	content.add_theme_constant_override("separation", 12)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content_panel.add_child(content)

	var eyebrow := _label("لعبة منصات دقيقة · الفصل الأول", 16, MUTED)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var logo := _label("ASHEN\nGAUNTLET", 58, GOLD_LIGHT, DISPLAY_FONT)
	_logo_label = logo
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", Color("#5b3b0c"))
	logo.add_theme_constant_override("outline_size", 8)
	content.add_child(logo)
	var arabic_title := _label("ممر الرماد", 26, GOLD, BOLD_FONT)
	arabic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(arabic_title)
	var line := HSeparator.new()
	line.modulate = Color(0.84, 0.62, 0.2, 0.45)
	content.add_child(line)
	var subtitle := _label("اقرأ الفخ. لا تثق بالهدوء.\nكل موت يعلّمك طريقًا أقصر.", 20, Color("#f3e6c4"))
	_subtitle_label = subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(subtitle)
	var play := _button("ابدأ التحدي", _start_game, true)
	_start_button = play
	_start_button.name = "StartButton"
	play.custom_minimum_size.y = 62
	content.add_child(play)
	var level := _button("اختيار المرحلة", func(): _show_notice("المرحلة 01 جاهزة الآن — بقية العوالم ستُضاف تباعًا."))
	content.add_child(level)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 8)
	secondary.add_child(_button("الإعدادات", func(): _show_notice("الإعدادات الأساسية: اهتزاز، مؤثرات، جسيمات، وحجم التحكم.")))
	secondary.add_child(_button("المتجر", func(): _show_notice("المتجر غير مفعل في هذه الشريحة؛ لا توجد مشتريات قسرية.")))
	content.add_child(secondary)
	var best := _label("أفضل نتيجة محلية: %06d" % SaveStore.best_score(), 15, MUTED)
	_best_label = best
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(best)
	var hint := _label("التحكم: A / D أو الأسهم · Space للقفز · Esc للإيقاف\nعلى الهاتف: اسحب يسار الشاشة للحركة واضغط زر القفز", 14, MUTED)
	_hint_label = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	_layout_responsive()
	get_viewport().size_changed.connect(_layout_responsive)

func _layout_responsive() -> void:
	if not is_instance_valid(_hero_panel):
		return
	var viewport := get_viewport_rect().size
	var compact := viewport.x < 1040.0 or viewport.y < 600.0
	_hero_panel.visible = not compact
	_margin_container.add_theme_constant_override("margin_left", 12 if compact else 28)
	_margin_container.add_theme_constant_override("margin_right", 12 if compact else 28)
	_margin_container.add_theme_constant_override("margin_top", 10 if compact else 24)
	_margin_container.add_theme_constant_override("margin_bottom", 10 if compact else 24)
	_content_box.add_theme_constant_override("separation", 7 if compact else 12)
	_logo_label.add_theme_font_size_override("font_size", 43 if compact else 58)
	_subtitle_label.add_theme_font_size_override("font_size", 17 if compact else 20)
	_best_label.visible = not compact
	_hint_label.visible = not compact

func _label(text: String, font_size: int, color: Color, font: Font = BODY_FONT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

func _button(text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 19 if primary else 16)
	var normal := _button_style(Color("#e0b13e") if primary else Color("#1b1230"), Color("#fff0b0") if primary else Color("#8d6a24"))
	var hover := _button_style(Color("#fff0b0") if primary else Color("#2b1f52"), GOLD_LIGHT)
	var pressed := _button_style(Color("#b07d14") if primary else Color("#0e0919"), GOLD)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", INK if primary else Color("#f3e6c4"))
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.pressed.connect(action)
	return button

func _panel_style(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 8)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	return style

func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	return style

func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _open_settings() -> void:
	if is_instance_valid(_modal):
		return
	_modal = SETTINGS.new()
	add_child(_modal)
	_modal.open_panel()

func _open_leaderboard() -> void:
	if is_instance_valid(_modal):
		return
	_modal = LEADERBOARD.new()
	add_child(_modal)
	_modal.open_panel()

func _show_notice(text: String) -> void:
	if is_instance_valid(_notice):
		_notice.queue_free()
	_notice = PanelContainer.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notice.custom_minimum_size = Vector2(430, 0)
	_notice.add_theme_stylebox_override("panel", _panel_style(PANEL_2, GOLD, 18))
	add_child(_notice)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_notice.add_child(box)
	var label := _label(text, 18, Color("#f3e6c4"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var close := _button("حسنًا", func(): _notice.queue_free(), true)
	box.add_child(close)
	close.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_game()
