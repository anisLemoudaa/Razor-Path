extends Control

var foreground := false
var drift := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(delta: float) -> void:
	drift += delta
	if not foreground:
		queue_redraw()

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	if foreground:
		var base := s.y * 0.78
		var near := PackedVector2Array([Vector2(0, s.y), Vector2(0, base + 28), Vector2(s.x * 0.15, base - 8), Vector2(s.x * 0.28, base + 18), Vector2(s.x * 0.46, base - 22), Vector2(s.x * 0.63, base + 10), Vector2(s.x * 0.78, base - 14), Vector2(s.x, base + 18), Vector2(s.x, s.y)])
		draw_colored_polygon(near, Color("#090611"))
		draw_polyline(near.slice(1, near.size() - 1), Color(0.45, 0.31, 0.74, 0.2), 2.0, true)
		return
	# Layered dusk gradient: dark values preserve hazard readability.
	var bands := 14
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color := Color("#07040f").lerp(Color("#24183d"), t * 0.82)
		draw_rect(Rect2(0, s.y * t, s.x, s.y / bands + 2), color, true)
	# Obsidian moon and haze.
	var moon := Vector2(s.x * 0.76, s.y * 0.25)
	draw_circle(moon, minf(s.x, s.y) * 0.17, Color(0.84, 0.67, 0.28, 0.10))
	draw_circle(moon, minf(s.x, s.y) * 0.12, Color(0.96, 0.84, 0.48, 0.12))
	# Quiet stars and parallax shards.
	for i in 18:
		var x := fmod(48.0 + float(i) * 137.0, s.x + 70.0) - 35.0
		var y := 38.0 + fmod(float(i) * 61.0, maxf(80.0, s.y * 0.45))
		var twinkle := 0.45 + 0.25 * sin(drift * 1.5 + float(i))
		draw_circle(Vector2(x, y), 1.2 + float(i % 3) * 0.7, Color(1.0, 0.88, 0.52, twinkle))
	var far := PackedVector2Array([Vector2(0, s.y * 0.74), Vector2(s.x * 0.18, s.y * 0.57), Vector2(s.x * 0.35, s.y * 0.71), Vector2(s.x * 0.54, s.y * 0.5), Vector2(s.x * 0.7, s.y * 0.7), Vector2(s.x * 0.86, s.y * 0.56), Vector2(s.x, s.y * 0.7), Vector2(s.x, s.y)])
	draw_colored_polygon(far, Color(0.06, 0.035, 0.13, 0.9))
	draw_polyline(far.slice(0, far.size() - 1), Color(0.38, 0.25, 0.58, 0.24), 2.0, true)
	for i in 7:
		var x := s.x * (0.08 + float(i) * 0.14)
		var h := 24.0 + float(i % 3) * 18.0
		draw_line(Vector2(x, s.y * 0.72), Vector2(x + 10, s.y * 0.72 - h), Color(0.74, 0.52, 0.2, 0.16), 2.0, true)
