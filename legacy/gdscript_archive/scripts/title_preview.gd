extends Control

var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var bob := sin(t * 1.8) * 4.0
	for i in 3:
		draw_circle(c + Vector2(0, bob), 120.0 - i * 24.0, Color(0.82, 0.62, 0.2, 0.05 - i * 0.01))
	var body := PackedVector2Array([c + Vector2(-50, 80 + bob), c + Vector2(-38, -12 + bob), c + Vector2(0, -55 + bob), c + Vector2(38, -12 + bob), c + Vector2(50, 80 + bob), c + Vector2(0, 100 + bob)])
	draw_colored_polygon(body, Color("#171126"))
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4]]), Color("#d4af37"), 4.0, true)
	draw_circle(c + Vector2(0, -55 + bob), 30, Color("#2b1f52"))
	draw_arc(c + Vector2(0, -55 + bob), 30, PI, TAU, 24, Color("#fff0b0"), 3.0, true)
	draw_line(c + Vector2(-15, -55 + bob), c + Vector2(15, -55 + bob), Color("#fff0b0"), 4.0, true)
	draw_circle(c + Vector2(10, -55 + bob), 3, Color("#fff8d7"))
	draw_line(c + Vector2(-18, 68 + bob), c + Vector2(-34, 97 + bob), Color("#e0b13e"), 8.0, true)
	draw_line(c + Vector2(18, 68 + bob), c + Vector2(34, 97 + bob), Color("#e0b13e"), 8.0, true)
