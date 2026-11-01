extends CanvasLayer
## Nonblocking event-driven onboarding; Skip is reachable throughout every step.

const VERSION := 1
const MENU_STYLE = preload("res://scripts/menu_style.gd")
const STEPS := ["move", "jump", "attack", "hazard", "checkpoint", "pause"]
const COMPLETES := ["moved", "jumped", "shot", "damaged", "checkpoint", "paused"]
var step := 0
var active := false
var method := "keyboard"
var elapsed := 0.0
var seen: Dictionary = {}
var panel: PanelContainer
var title_label: Label
var body_label: Label
var skip_button: Button
var _header: HBoxContainer
var _content: VBoxContainer

func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	panel = PanelContainer.new()
	panel.name = "TutorialPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 24
	panel.offset_top = 112
	panel.offset_right = 584
	panel.offset_bottom = 244
	var style := MENU_STYLE.card(Color(1.0, 0.955, 0.86, 0.97), 14)
	style.set_corner_radius_all(20)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	FeltKit.decorate_panel(panel, MENU_STYLE.STITCH, 6.0)
	root_control.add_child(panel)
	var content := VBoxContainer.new()
	_content = content
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	var header := HBoxContainer.new()
	_header = header
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", MENU_STYLE.COCOA)
	header.add_child(title_label)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", MENU_STYLE.INK)
	body_label.add_theme_font_override("font", MENU_STYLE.MEDIUM)
	content.add_child(body_label)
	skip_button = MENU_STYLE.button(I18n.t("tutorial.skip"))
	skip_button.name = "SkipTutorial"
	skip_button.custom_minimum_size = Vector2(150, 44)
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_button.pressed.connect(skip)
	header.add_child(skip_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
	panel.hide()

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var narrow := size.x < 600.0
	var short := size.y < 340.0
	panel.offset_left = 12 if narrow else 24
	panel.offset_right = 222.0 if short else minf(size.x - 12.0, 584.0)
	panel.offset_top = 62 if size.y < 240.0 else 80 if short else 118 if narrow else 96
	panel.offset_bottom = panel.offset_top + (60.0 if short else 116.0)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_content_margin_all(8 if short else 12)
	title_label.visible = not short
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18 if narrow else 21)
	title_label.add_theme_font_override("font", MENU_STYLE.trimmed(MENU_STYLE.tracked(MENU_STYLE.SMALL_HEADING, 1), 21, 0.2, 0.28))
	_header.add_theme_constant_override("separation", 6 if short else 12)
	skip_button.custom_minimum_size.x = 104 if short else 138 if narrow else 150
	skip_button.add_theme_font_size_override("font_size", 14 if short else 16)
	body_label.add_theme_font_size_override("font_size", 16 if narrow else 17)
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if short and body_label.get_parent() != _header:
		body_label.reparent(_header)
		_header.move_child(body_label, 0)
	elif not short and body_label.get_parent() != _content:
		body_label.reparent(_content)
		_content.move_child(body_label, 1)
	if active: _refresh()

func begin() -> void:
	var replay := SaveStore.consume_tutorial_replay()
	if SaveStore.tutorial_completed(VERSION) and not replay:
		return
	step = 0
	elapsed = 0.0
	seen.clear()
	active = true
	panel.show()
	_refresh()

func notify(event: String) -> void:
	if not active:
		return
	seen[event] = true
	while active and seen.has(COMPLETES[step]):
		_next()

func _next() -> void:
	step += 1
	elapsed = 0.0
	if step >= STEPS.size():
		skip()
	else:
		_refresh()

func _refresh() -> void:
	if not active:
		return
	var key: String = STEPS[step]
	title_label.text = I18n.t("tutorial.%s.title" % key)
	var suffix := ".compact" if get_viewport().get_visible_rect().size.y < 340.0 else ""
	body_label.text = I18n.t("tutorial.%s.%s%s" % [key, method, suffix])
	skip_button.text = I18n.t("tutorial.skip")
	skip_button.accessibility_name = skip_button.text
	skip_button.tooltip_text = I18n.t("tutorial.skip_hint")

func skip() -> void:
	if not active:
		return
	active = false
	panel.hide()
	# No pause or input lock is acquired; dismissal never unpauses another modal.
	SaveStore.complete_tutorial(VERSION)
	if get_viewport().gui_get_focus_owner() == skip_button:
		skip_button.release_focus()

func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	elapsed += delta
	if elapsed >= 18.0:
		_next() # Never wait forever on an optional action, damage, or checkpoint.

func _input(event: InputEvent) -> void:
	if not active:
		return
	var next_method := method
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_method = "gamepad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		next_method = "touch"
	elif event is InputEventKey:
		next_method = "keyboard"
	if next_method != method:
		method = next_method
		_refresh()
	if event.is_action_pressed("skip_tutorial"):
		skip()
		get_viewport().set_input_as_handled()
