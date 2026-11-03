extends Node2D

var surface_size := Vector2.ZERO

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if surface_size.x <= 0.0 or surface_size.y <= 0.0:
		return
	var r := Rect2(Vector2.ZERO, surface_size)
	draw_rect(r, Color("#100b1c"), true)
	draw_rect(Rect2(0, 0, surface_size.x, 9), Color("#2b1f52"), true)
	draw_line(Vector2(0, 2), Vector2(surface_size.x, 2), Color("#fff0b0"), 2.0, true)
	draw_line(Vector2(0, 10), Vector2(surface_size.x, 10), Color("#d4af37"), 2.0, true)
	draw_line(Vector2(0, surface_size.y - 3), Vector2(surface_size.x, surface_size.y - 3), Color("#05030a"), 4.0, true)
	var columns := maxi(2, int(surface_size.x / 90.0))
	for i in columns:
		var x := (float(i) + 0.5) * surface_size.x / float(columns)
		draw_line(Vector2(x, 18), Vector2(x - 8, surface_size.y - 10), Color(0.35, 0.25, 0.54, 0.32), 1.0, true)
		if i % 2 == 0:
			draw_circle(Vector2(x + 12, 28), 2.0, Color(0.84, 0.68, 0.24, 0.35))
