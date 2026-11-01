extends Node2D

const SKY_TEXTURE = preload("res://assets/template/cat/warm-background.webp")
const FOREGROUND_TEXTURE = preload("res://assets/template/generated/foliage_near.webp")

var world_width := 7800.0
var parallax_layers: Array[Parallax2D] = []
var layer_sprites: Array[Sprite2D] = []
var background_canvas: CanvasLayer
var foreground: Parallax2D
var foreground_sprite: Sprite2D


func _ready() -> void:
	# Screen-space background does not shrink when the world camera zooms out.
	background_canvas = CanvasLayer.new()
	background_canvas.layer = -50
	background_canvas.follow_viewport_enabled = false
	add_child(background_canvas)
	var parallax := Parallax2D.new()
	parallax.ignore_camera_scroll = true
	parallax.follow_viewport = false
	parallax.repeat_times = 3
	background_canvas.add_child(parallax)
	var sprite := Sprite2D.new()
	sprite.texture = SKY_TEXTURE
	# Dim only the scenery, not the cat, terrain, projectiles or HUD.
	sprite.self_modulate = Color(0.84, 0.84, 0.84, 1.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parallax.add_child(sprite)
	parallax_layers.append(parallax)
	layer_sprites.append(sprite)
	var foreground_canvas := CanvasLayer.new()
	foreground_canvas.name = "ScenicForeground"
	foreground_canvas.layer = 5
	foreground_canvas.follow_viewport_enabled = false
	add_child(foreground_canvas)
	foreground = Parallax2D.new()
	foreground.ignore_camera_scroll = true
	foreground.follow_viewport = false
	foreground_canvas.add_child(foreground)
	foreground_sprite = Sprite2D.new()
	foreground_sprite.texture = FOREGROUND_TEXTURE
	foreground_sprite.centered = false
	foreground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	foreground.add_child(foreground_sprite)
	get_viewport().size_changed.connect(layout_layers)
	layout_layers()


func layout_layers() -> void:
	var viewport_size := get_viewport_rect().size
	var sprite := layer_sprites[0]
	var texture_size := sprite.texture.get_size()
	var scale_factor := maxf(1.0, viewport_size.y / texture_size.y)
	var repeat_width := texture_size.x * scale_factor
	sprite.scale = Vector2.ONE * scale_factor
	sprite.position = Vector2(repeat_width * 0.5, viewport_size.y * 0.5)
	parallax_layers[0].repeat_size = Vector2(repeat_width, 0)
	# Low scenic strip stays below traversal and touch targets at every aspect.
	var foreground_scale := 0.22 * ViewportPolicy.world_scale()
	var foreground_size := FOREGROUND_TEXTURE.get_size() * foreground_scale
	foreground_sprite.scale = Vector2.ONE * foreground_scale
	foreground_sprite.position.y = viewport_size.y - foreground_size.y + 20.0
	foreground.repeat_size = Vector2(foreground_size.x, 0)
	foreground.repeat_times = ceili(viewport_size.x / foreground_size.x) + 2


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		# Only horizontal world travel contributes to the screen-space parallax.
		parallax_layers[0].scroll_offset = Vector2(-camera.get_screen_center_position().x * 0.08, 0)
		foreground.scroll_offset = Vector2(-camera.get_screen_center_position().x * 0.16, 0)

