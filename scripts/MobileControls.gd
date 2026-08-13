extends Control

var move_vector := Vector2.ZERO
var knob: Control
var active_touch := -1
var center := Vector2.ZERO
signal move_changed(value: Vector2)
signal action_pressed(action_name: StringName)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0 and event.position.x < size.x * 0.52:
			active_touch = event.index
			center = event.position
			_update_stick(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			move_vector = Vector2.ZERO
			move_changed.emit(move_vector)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_update_stick(event.position)

func _update_stick(position: Vector2) -> void:
	move_vector = (position - center).limit_length(92.0) / 92.0
	move_changed.emit(move_vector)
	queue_redraw()

func _draw() -> void:
	var base = Vector2(130, size.y - 130)
	if center == Vector2.ZERO:
		center = base
	draw_circle(base, 88.0, Color(0.04, 0.04, 0.08, 0.52))
	draw_arc(base, 88.0, 0.0, TAU, 32, Color(1, 0.6, 0.1, 0.5), 3.0)
	draw_circle(center + move_vector * 62.0, 34.0, Color(1, 0.6, 0.1, 0.72))
	var boost = Vector2(size.x - 130, size.y - 145)
	draw_circle(boost, 58.0, Color(1, 0.55, 0.08, 0.65))
	draw_string(ThemeDB.fallback_font, boost - Vector2(28, -7), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var jump = Vector2(size.x - 260, size.y - 100)
	draw_circle(jump, 42.0, Color(0.35, 0.7, 1.0, 0.62))
	draw_string(ThemeDB.fallback_font, jump - Vector2(18, -6), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if event.position.x > size.x * 0.8 and event.position.y > size.y * 0.65:
			action_pressed.emit(&"boost")
		elif event.position.x > size.x * 0.55 and event.position.y > size.y * 0.72:
			action_pressed.emit(&"action")
