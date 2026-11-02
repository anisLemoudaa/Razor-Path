extends Control

func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.31
	draw_circle(c, r + 4, Color(0.84, 0.62, 0.2, 0.16))
	draw_circle(c, r, Color("#e0b13e"))
	draw_arc(c, r, 0, TAU, 24, Color("#fff0b0"), 2.0, true)
	draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.55), Color("#8d6112"), 2.0, true)
