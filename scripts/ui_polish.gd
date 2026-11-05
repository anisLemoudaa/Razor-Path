extends Node

# Premium presentation layer for the native C++ UI. Native screens rebuild controls
# dynamically, so style each screen as it is created without changing game logic.
var _refresh_queued := false
var _is_mobile := false

const INK := Color(0.025, 0.045, 0.078, 0.97)
const SURFACE := Color(0.065, 0.105, 0.17, 0.98)
const SURFACE_HOVER := Color(0.105, 0.19, 0.28, 1.0)
const CYAN := Color(0.30, 0.88, 0.91, 0.98)
const GOLD := Color(1.0, 0.76, 0.35, 1.0)
const PAPER := Color(0.94, 0.97, 1.0, 1.0)

func _ready() -> void:
    _is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
    get_tree().tree_changed.connect(_queue_refresh)
    get_viewport().size_changed.connect(_queue_refresh)
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
    button.pivot_offset = button.size * 0.5
    button.add_theme_font_size_override("font_size", 24 if _is_mobile else 22)
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", GOLD)
    button.add_theme_color_override("font_disabled_color", Color(0.55, 0.63, 0.72, 1.0))
    if _is_mobile:
        # Increase touch hit targets while preserving the native screen layout.
        button.custom_minimum_size = Vector2(0.0, 64.0)

    var normal := _button_box(SURFACE, CYAN, Color(0.0, 0.0, 0.0, 0.36))
    var hover := _button_box(SURFACE_HOVER, Color(0.49, 0.96, 0.96, 1.0), Color(0.12, 0.65, 0.74, 0.25))
    var pressed := _button_box(INK, GOLD, Color(0.0, 0.0, 0.0, 0.28))
    var disabled := _button_box(Color(0.10, 0.13, 0.18, 1.0), Color(0.38, 0.45, 0.53, 0.7), Color.TRANSPARENT)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_stylebox_override("focus", hover)
    button.button_down.connect(_animate_button.bind(button, 0.97))
    button.button_up.connect(_animate_button.bind(button, 1.0))

    # Keep the pause affordance clear of rounded screen corners and camera cutouts.
    if _is_mobile and button.text == "إيقاف":
        button.position.y = maxf(button.position.y, 26.0)
        button.position.x = minf(button.position.x, 1280.0 - button.size.x - 26.0)

func _animate_button(button: Button, target_scale: float) -> void:
    if not is_instance_valid(button):
        return
    button.pivot_offset = button.size * 0.5
    var tween := button.create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", Vector2.ONE * target_scale, 0.11)

func _button_box(fill: Color, edge: Color, shadow: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = edge
    box.set_border_width_all(2)
    box.set_corner_radius_all(16)
    box.content_margin_left = 18.0
    box.content_margin_right = 18.0
    box.content_margin_top = 12.0
    box.content_margin_bottom = 12.0
    box.shadow_color = shadow
    box.shadow_size = 8
    box.shadow_offset = Vector2(0, 3)
    return box

func _style_label(label: Label) -> void:
    if label.has_meta("razor_polished"):
        return
    label.set_meta("razor_polished", true)
    label.add_theme_color_override("font_color", PAPER)
    label.add_theme_color_override("font_outline_color", Color(0.025, 0.04, 0.075, 0.94))
    label.add_theme_constant_override("outline_size", 3 if _is_mobile else 2)

    # Floating glass plates are limited to large headings and the gameplay HUD.
    if label.size.x >= 500.0 and label.size.y >= 48.0:
        _add_glass_plate(label)

func _add_glass_plate(label: Label) -> void:
    var parent := label.get_parent()
    if not parent is Control or parent.has_node("PlateFor_" + str(label.get_instance_id())):
        return
    var plate := Panel.new()
    plate.name = "PlateFor_" + str(label.get_instance_id())
    plate.position = label.position - Vector2(8.0, 5.0)
    plate.size = label.size + Vector2(16.0, 10.0)
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var box := StyleBoxFlat.new()
    box.bg_color = Color(INK.r, INK.g, INK.b, 0.66)
    box.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.40)
    box.set_border_width_all(1)
    box.set_corner_radius_all(14)
    box.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
    box.shadow_size = 6
    box.shadow_offset = Vector2(0, 2)
    plate.add_theme_stylebox_override("panel", box)
    parent.add_child(plate)
    parent.move_child(plate, label.get_index())
