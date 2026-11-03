extends Node2D

var size := Vector2(90, 160):
	set(value):
		size = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var base := h * 0.5
	var top := -h * 0.5
	var body := PackedVector2Array([Vector2(-w * 0.5, base), Vector2(-w * 0.35, top + 14), Vector2(0, top), Vector2(w * 0.35, top + 14), Vector2(w * 0.5, base)])
	draw_colored_polygon(body, Color("#120c20"))
	draw_polyline(PackedVector2Array([Vector2(-w * 0.5, base), Vector2(-w * 0.35, top + 14), Vector2(0, top), Vector2(w * 0.35, top + 14), Vector2(w * 0.5, base)]), Color("#6e4aa0"), 2.0, true)
	draw_line(Vector2(0, top + 8), Vector2(0, base - 12), Color("#d4af37"), 3.0, true)
	draw_line(Vector2(-w * 0.28, base - 18), Vector2(w * 0.28, base - 18), Color("#d4af37"), 2.0, true)
