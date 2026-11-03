class_name AnisCharacter
extends Node2D

## Runtime character presentation for Razor Path.
## Simulation remains owned by player.gd; this node only renders cosmetics.

enum State { IDLE, RUN, JUMP, FALL, LAND, WALL_SLIDE, DASH, DEATH, WIN }

const SKINS := {
	"default": {"name": "الافتراضي", "primary": Color("#171126"), "accent": Color("#d4af37"), "scarf": Color("#b07d14"), "rarity": "مملوك"},
	"ruby": {"name": "الياقوت", "primary": Color("#32152b"), "accent": Color("#f05b68"), "scarf": Color("#b82f4d"), "rarity": "200"},
	"emerald": {"name": "الزمرد", "primary": Color("#102c2c"), "accent": Color("#54d6a0"), "scarf": Color("#178d75"), "rarity": "200"},
	"diamond": {"name": "الماسي", "primary": Color("#1b2945"), "accent": Color("#8be5ff"), "scarf": Color("#4388d4"), "rarity": "350 · نادر"},
	"gold": {"name": "الذهبي", "primary": Color("#32220e"), "accent": Color("#fff0a8"), "scarf": Color("#e0a928"), "rarity": "مجهز"},
	"legend": {"name": "الأسطورة", "primary": Color("#29123f"), "accent": Color("#e78cff"), "scarf": Color("#8735bd"), "rarity": "500 · أسطوري"},
}

var state: State = State.IDLE
var skin_id := "default"
var facing := 1.0
var velocity := Vector2.ZERO
var anim_time := 0.0
var deaths := 0
var reduced_motion := false
var _state_time := 0.0

func configure(selected_skin: String, face_direction: float = 1.0) -> void:
	skin_id = selected_skin if SKINS.has(selected_skin) else "default"
	facing = -1.0 if face_direction < 0.0 else 1.0
	queue_redraw()

func set_motion(next_state: State, next_velocity: Vector2, face_direction: float, death_count: int = 0) -> void:
	if state != next_state:
		_state_time = 0.0
	state = next_state
	velocity = next_velocity
	facing = -1.0 if face_direction < 0.0 else 1.0
	deaths = death_count
	queue_redraw()

func _process(delta: float) -> void:
	if reduced_motion:
		return
	anim_time += delta
	_state_time += delta
	queue_redraw()

func _draw() -> void:
	var palette: Dictionary = SKINS[skin_id]
	var accent: Color = palette.accent
	var primary: Color = palette.primary
	var scarf: Color = palette.scarf
	var bob := 0.0
	var stretch := Vector2.ONE
	var lean := 0.0
	var step := 0.0 if reduced_motion else sin(anim_time * (10.0 if state == State.RUN else 3.0))
	match state:
		State.IDLE:
			bob = 0.0 if reduced_motion else sin(anim_time * 2.2) * 1.2
		State.RUN:
			bob = absf(step) * 3.0
			lean = -0.14
		State.JUMP:
			stretch = Vector2(0.88, 1.12)
			lean = -0.04
		State.FALL:
			stretch = Vector2(1.08, 0.94)
		State.LAND:
			var settle := smoothstep(0.0, 0.18, _state_time)
			stretch = Vector2(lerpf(1.2, 1.0, settle), lerpf(0.78, 1.0, settle))
		State.WALL_SLIDE:
			lean = -0.18
		State.DASH:
			lean = -0.38
		State.DEATH:
			stretch = Vector2(1.1, 0.9)
		State.WIN:
			bob = -absf(sin(anim_time * 8.0)) * 5.0
			stretch = Vector2(0.92, 1.08)
	var transform_scale := Vector2(facing * stretch.x, stretch.y)
	draw_set_transform(Vector2(0, bob), lean, transform_scale)
	if state == State.DEATH:
		_draw_body(primary.darkened(0.25), accent, scarf, 0.0)
		_draw_death(accent, scarf)
	else:
		_draw_body(primary, accent, scarf, step)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_body(primary: Color, accent: Color, scarf: Color, step: float) -> void:
	# Twelve-part 2D rig: head, torso, upper/lower arms, upper/lower legs.
	var leg_a := 9.0 + (step * 7.0 if state == State.RUN else 0.0)
	var leg_b := 9.0 - (step * 7.0 if state == State.RUN else 0.0)
	var arm_a := -10.0 - (step * 6.0 if state == State.RUN else 0.0)
	var arm_b := -10.0 + (step * 6.0 if state == State.RUN else 0.0)
	if state == State.JUMP or state == State.WIN:
		arm_a = -17.0; arm_b = -17.0
	# scarf trails with secondary spring-like motion
	var scarf_wave := 0.0 if reduced_motion else sin(anim_time * 12.0) * (3.0 if state != State.IDLE else 1.0)
	draw_line(Vector2(-5, -10), Vector2(-19 - absf(velocity.x) * 0.015, 2 + scarf_wave), scarf, 3.5, true)
	# torso / cloak
	var cloak := PackedVector2Array([Vector2(-13, 2), Vector2(-10, -22), Vector2(0, -30), Vector2(11, -22), Vector2(14, 2), Vector2(0, 8)])
	draw_colored_polygon(cloak, primary)
	draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[3], cloak[4]]), accent, 2.5, true)
	# legs, knees and shoes
	draw_line(Vector2(-5, 0), Vector2(-7, leg_a), accent, 4.0, true)
	draw_line(Vector2(5, 0), Vector2(7, leg_b), accent, 4.0, true)
	draw_circle(Vector2(-7, leg_a), 2.2, accent)
	draw_circle(Vector2(7, leg_b), 2.2, accent)
	draw_line(Vector2(-7, leg_a), Vector2(-11, leg_a + 7), accent, 4.0, true)
	draw_line(Vector2(7, leg_b), Vector2(11, leg_b + 7), accent, 4.0, true)
	# arms, elbows and hands
	draw_line(Vector2(-8, -12), Vector2(-12, arm_a), accent, 3.5, true)
	draw_line(Vector2(8, -12), Vector2(12, arm_b), accent, 3.5, true)
	draw_circle(Vector2(-12, arm_a), 2.0, accent)
	draw_circle(Vector2(12, arm_b), 2.0, accent)
	# head and expressive eye slit
	draw_circle(Vector2(0, -29), 9, primary.lightened(0.12))
	draw_arc(Vector2(0, -29), 9, PI, TAU, 16, accent, 1.5, true)
	var eye_y := -29.0 + (0.0 if reduced_motion else sin(anim_time * 1.7) * 0.5)
	draw_line(Vector2(-5, eye_y), Vector2(5, eye_y), Color("#fff0b0"), 2.5, true)
	draw_circle(Vector2(3, eye_y), 1.4, Color("#fff8d7"))
	if state == State.RUN and absf(velocity.x) > 70.0:
		draw_line(Vector2(-15, -2), Vector2(-25, 4), Color(accent, 0.42), 2.0, true)

func _draw_death(accent: Color, scarf: Color) -> void:
	var phase := clampf(_state_time / 0.4, 0.0, 1.0)
	draw_circle(Vector2(-10 - phase * 18.0, -12 - phase * 22.0), 5.0, accent)
	draw_circle(Vector2(10 + phase * 13.0, -24 - phase * 14.0), 4.0, scarf)
	draw_line(Vector2(-15, -4), Vector2(15, -36), Color("#f2c35b"), 3.0, true)
	for i in 4:
		var p := Vector2(-22 + i * 15, -4 - fmod(_state_time * 50.0 + i * 8.0, 34.0))
		draw_circle(p, 1.5, Color(accent, 0.75 - phase * 0.5))

static func skin_catalog() -> Dictionary:
	return SKINS.duplicate(true)
