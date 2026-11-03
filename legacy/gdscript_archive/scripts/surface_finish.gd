extends RefCounted
## Clip textured art to one rounded outer perimeter, keeping internal tile joins flat.

const CORNER_STEPS := 8


static func perimeter(bounds: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inset := clampf(radius, 0.0, minf(bounds.size.x, bounds.size.y) * 0.5)
	if inset <= 0.0:
		return PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	var centers := [
		Vector2(bounds.end.x - inset, bounds.position.y + inset),
		bounds.end - Vector2.ONE * inset,
		Vector2(bounds.position.x + inset, bounds.end.y - inset),
		bounds.position + Vector2.ONE * inset,
	]
	for corner in 4:
		for step in CORNER_STEPS + 1:
			var angle := (-0.5 + float(corner) * 0.5 + float(step) / CORNER_STEPS * 0.5) * PI
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * inset)
	return points


static func draw_texture(canvas: CanvasItem, texture: Texture2D, bounds: Rect2, radius: float, tint := Color.WHITE) -> void:
	_draw_polygon(canvas, texture, perimeter(bounds, radius), bounds, Rect2(Vector2.ZERO, texture.get_size()), tint)


static func draw_tiles(canvas: CanvasItem, texture: Texture2D, bounds: Rect2, source: Rect2, tile_size: float, radius: float) -> void:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or tile_size <= 0.0:
		return
	var outline := perimeter(bounds, radius)
	for row in ceili(bounds.size.y / tile_size):
		for column in ceili(bounds.size.x / tile_size):
			var origin := bounds.position + Vector2(column, row) * tile_size
			var size := (bounds.end - origin).min(Vector2.ONE * tile_size)
			var tile := Rect2(origin, size)
			var tile_corners := PackedVector2Array([tile.position, Vector2(tile.end.x, tile.position.y), tile.end, Vector2(tile.position.x, tile.end.y)])
			# Clip only against the whole surface; rounding each tile would create seams.
			for polygon in Geometry2D.intersect_polygons(outline, tile_corners):
				_draw_polygon(canvas, texture, polygon, Rect2(origin, Vector2.ONE * tile_size), source, Color.WHITE)


static func _draw_polygon(canvas: CanvasItem, texture: Texture2D, polygon: PackedVector2Array, destination: Rect2, source: Rect2, tint: Color) -> void:
	if polygon.size() < 3:
		return
	var uvs := PackedVector2Array()
	for point in polygon:
		uvs.append((source.position + (point - destination.position) / destination.size * source.size) / texture.get_size())
	canvas.draw_colored_polygon(polygon, tint, uvs, texture)
