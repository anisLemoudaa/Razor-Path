extends Node2D
## Finish the outer edge while keeping texture joins and the walking surface flat.

const TEXTURE = preload("res://assets/template/cat/felt-ground.webp")
const SURFACE_FINISH = preload("res://scripts/surface_finish.gd")
const SOURCE_RECT := Rect2(0, 0, 256, 256)
const TILE_SIZE := 168.0
const EDGE_RADIUS := 8.0
var surface_size := Vector2.ZERO


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func _draw() -> void:
	SURFACE_FINISH.draw_tiles(self, TEXTURE, Rect2(Vector2.ZERO, surface_size), SOURCE_RECT, TILE_SIZE, EDGE_RADIUS)
