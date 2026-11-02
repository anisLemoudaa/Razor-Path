extends Node
## Floating virtual joystick for touch devices (and mouse drag).
## Each contact owns its own vector so lifting one finger never cancels another.

const MAX_RADIUS := 96.0
const DEAD_ZONE := 0.15
const ALL_POINTERS := -2147483648
const UNSPECIFIED_POINTER := -2147483647

var vector: Vector2 = Vector2.ZERO
var _active := false
var _pointer_index := -1 # compatibility/debug: first active pointer
var _touches: Dictionary = {}

func _ready() -> void:
	add_to_group("transient_input")
	get_viewport().size_changed.connect(clear_input)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		clear_input()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin(touch.index, touch.position)
		else:
			_end(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_update(drag.position, drag.index)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin(-1, mb.position)
			else:
				_end(-1)
	elif event is InputEventMouseMotion and _touches.has(-1):
		_update((event as InputEventMouseMotion).position, -1)

func _begin(index: int, position: Vector2) -> void:
	if not get_viewport().get_visible_rect().has_point(position) or _touches.has(index):
		return
	_touches[index] = {"origin": position, "vector": Vector2.ZERO}
	_refresh_vector()

func _update(position: Vector2, index: int = UNSPECIFIED_POINTER) -> void:
	if index == UNSPECIFIED_POINTER:
		if _touches.size() != 1:
			return
		index = int(_touches.keys()[0])
	if not _touches.has(index):
		return
	var point: Dictionary = _touches[index]
	var radius := clampf(get_viewport().get_visible_rect().size.x * 0.15, 48.0, MAX_RADIUS)
	var offset: Vector2 = (position - point.origin) / radius
	point.vector = Vector2.ZERO if offset.length() < DEAD_ZONE else offset.limit_length(1.0)
	_touches[index] = point
	_refresh_vector()

func _end(index: int = ALL_POINTERS) -> void:
	if index == ALL_POINTERS:
		_touches.clear()
	else:
		_touches.erase(index)
	_refresh_vector()

func _refresh_vector() -> void:
	var combined := Vector2.ZERO
	for point: Dictionary in _touches.values():
		combined += point.vector
	vector = combined.limit_length(1.0)
	_active = not _touches.is_empty()
	_pointer_index = int(_touches.keys()[0]) if _active else -1

func clear_input() -> void:
	_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_input()
