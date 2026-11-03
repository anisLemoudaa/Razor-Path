extends Node2D

const BACKGROUND = preload("res://scripts/background_art.gd")

var background_canvas: CanvasLayer
var foreground_canvas: CanvasLayer
var world_width := 7800.0
var background: Control
var foreground: Control

func _ready() -> void:
	background_canvas = CanvasLayer.new()
	background_canvas.name = "ObsidianBackground"
	background_canvas.layer = -50
	background_canvas.follow_viewport_enabled = false
	add_child(background_canvas)
	background = BACKGROUND.new()
	background.name = "DuskLayers"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_canvas.add_child(background)

	foreground_canvas = CanvasLayer.new()
	foreground_canvas.name = "ObsidianForeground"
	foreground_canvas.layer = -2
	foreground_canvas.follow_viewport_enabled = false
	add_child(foreground_canvas)
	foreground = BACKGROUND.new()
	foreground.name = "SilhouetteLayer"
	foreground.foreground = true
	foreground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground_canvas.add_child(foreground)
