extends Node

# Runtime visual pass for the native C++ UI. Native screens rebuild their controls
# dynamically, so watch the scene tree and style each new control once.
var _refresh_queued := false

const INK := Color(0.035, 0.055, 0.09, 0.97)
const SURFACE := Color(0.075, 0.12, 0.19, 0.98)
const SURFACE_HOVER := Color(0.11, 0.20, 0.29, 1.0)
const CYAN := Color(0.30, 0.88, 0.91, 0.95)
const GOLD := Color(1.0, 0.76, 0.35, 1.0)
const PAPER := Color(0.94, 0.97, 1.0, 1.0)

func _ready() -> void:
    get_tree().tree_changed.connect(_queue_refresh)
    call_deferred("_refresh_controls")

func _queue_refresh() -> void:
    if _refresh_queued:
        return
    _refresh_queued = true
    call_deferred("_refresh_controls")

func _refresh_controls() -> void:
    _refresh_queued = false
    if not is_inside_tree():
        return
    _visit(get_tree().root)

func _visit(node: Node) -> void:
    if node is Button:
        _style_button(node)
    elif node is Label:
        _style_label(node)
    for child in node.get_children():
        _visit(child)

func _style_button(button: Button) -> void:
    if button.has_meta("razor_polished"):
        return
    button.set_meta("razor_polished", true)
    button.add_theme_font_size_override("font_size", 22)
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", GOLD)
    button.add_theme_color_override("font_disabled_color", Color(0.55, 0.63, 0.72, 1.0))

    var normal := _button_box(SURFACE, CYAN, Color(0.0, 0.0, 0.0, 0.32))
    var hover := _button_box(SURFACE_HOVER, Color(0.49, 0.96, 0.96, 1.0), Color(0.12, 0.65, 0.74, 0.22))
    var pressed := _button_box(INK, GOLD, Color(0.0, 0.0, 0.0, 0.25))
    var disabled := _button_box(Color(0.10, 0.13, 0.18, 1.0), Color(0.38, 0.45, 0.53, 0.7), Color.TRANSPARENT)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_stylebox_override("focus", hover)

func _button_box(fill: Color, edge: Color, shadow: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = edge
    box.set_border_width_all(2)
    box.set_corner_radius_all(15)
    box.content_margin_left = 16.0
    box.content_margin_right = 16.0
    box.content_margin_top = 10.0
    box.content_margin_bottom = 10.0
    box.shadow_color = shadow
    box.shadow_size = 8
    box.shadow_offset = Vector2(0, 3)
    return box

func _style_label(label: Label) -> void:
    if label.has_meta("razor_polished"):
        return
    label.set_meta("razor_polished", true)
    label.add_theme_color_override("font_color", PAPER)
    label.add_theme_color_override("font_outline_color", Color(0.025, 0.04, 0.075, 0.88))
    label.add_theme_constant_override("outline_size", 2)

    # Subtle glass-like plates improve readability against the animated world.
    if label.get_parent() is Control and label.size.x > 90.0 and label.size.y > 30.0:
        var plate := Panel.new()
        plate.name = "PolishedLabelPlate"
        plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
        plate.show_behind_parent = true
        var box := StyleBoxFlat.new()
        box.bg_color = Color(INK.r, INK.g, INK.b, 0.70)
        box.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.42)
        box.set_border_width_all(1)
        box.set_corner_radius_all(12)
        box.content_margin_left = 8.0
        box.content_margin_right = 8.0
        box.content_margin_top = 4.0
        box.content_margin_bottom = 4.0
        plate.add_theme_stylebox_override("panel", box)
        label.add_child(plate)
