extends RefCounted

# Cache decoded alpha geometry by texture resource, not by animation frame index.
# Keep texture resources in the cache so instance IDs cannot be reused underneath it.
var _regions: Dictionary = {}


func alpha_region(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	if _regions.has(texture):
		return _regions[texture]
	var region := Rect2()
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if not image.is_compressed() or image.decompress() == OK:
			region = Rect2(image.get_used_rect())
	_regions[texture] = region
	return region


func canvas_rect(texture: Texture2D, pixel_scale: Vector2, foot_y: float) -> Rect2:
	var region := alpha_region(texture)
	if not region.has_area():
		return Rect2()
	var canvas_size := texture.get_size()
	# Preserve the canvas pivot and scale when limbs change the alpha bounds.
	# One full-canvas quad avoids fractional nearest-neighbor seams between frames.
	return Rect2(Vector2(-canvas_size.x * 0.5 * pixel_scale.x, foot_y - region.end.y * pixel_scale.y), canvas_size * pixel_scale)


func visible_rect(texture: Texture2D, pixel_scale: Vector2, foot_y: float) -> Rect2:
	var region := alpha_region(texture)
	if not region.has_area():
		return Rect2()
	var canvas := canvas_rect(texture, pixel_scale, foot_y)
	return Rect2(canvas.position + region.position * pixel_scale, region.size * pixel_scale)
