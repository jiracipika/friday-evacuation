extends Control
## Each touch owns one control until release or cancellation.
const UI = preload("res://scripts/overhaul/OfficeUI.gd")
const RADIUS := 53.0
const BUTTON_RADIUS := 30.0

var driver: RefCounted
var labels := PackedStringArray(["BOOST", "BRAKE", "HOP", "ITEM"])
var held: Dictionary = {}
var stick := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(reset)

func update_labels(next: PackedStringArray) -> void:
	if next == labels:
		return
	labels = next
	queue_redraw()

func reset() -> void:
	held.clear()
	stick = -1
	driver.touch_move = Vector2.ZERO
	driver.touch_boost = false
	driver.touch_drift = false
	driver.touch_hop = false
	driver.touch_item = false
	queue_redraw()

func _center() -> Vector2:
	return Vector2(72, size.y - 70)

func _action_center(index: int) -> Vector2:
	return Vector2(size.x - 48 - (index % 2) * 68, size.y - 46 - (index / 2) * 68)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := make_input_local(event) as InputEventScreenTouch
		_touch(touch.index, touch.pressed and not touch.canceled, touch.position)
	elif event is InputEventScreenDrag and event.index == stick:
		var drag := make_input_local(event) as InputEventScreenDrag
		_steer(drag.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and driver:
		reset()

func _touch(index: int, pressed: bool, point: Vector2) -> void:
	if not pressed:
		if index == stick:
			stick = -1
			driver.touch_move = Vector2.ZERO
		elif held.has(index):
			held.erase(index)
			driver.touch_boost = held.values().has(0)
			driver.touch_drift = held.values().has(1)
		else:
			return
	elif stick == -1 and point.distance_to(_center()) <= RADIUS + 12:
		stick = index
		_steer(point)
	else:
		var action := -1
		for i in labels.size():
			if not labels[i].is_empty() and point.distance_to(_action_center(i)) <= BUTTON_RADIUS:
				action = i
				break
		if action < 0:
			return
		held[index] = action
		match action:
			0: driver.touch_boost = true
			1: driver.touch_drift = true
			2: driver.touch_hop = true
			3: driver.touch_item = true
	queue_redraw()
	get_viewport().set_input_as_handled()

func _steer(point: Vector2) -> void:
	driver.touch_move = ((point - _center()) / (RADIUS - 14)).limit_length()
	queue_redraw()

func _draw() -> void:
	var base := Color(UI.INK, 0.92)
	draw_circle(_center(), RADIUS, base, true, -1, true)
	draw_arc(_center(), RADIUS - 1, 0, TAU, 48, Color(UI.PAPER, 0.65), 1.5, true)
	draw_circle(_center() + driver.touch_move * 30, 19, UI.ORANGE, true, -1, true)
	for i in labels.size():
		if labels[i].is_empty():
			continue
		var center := _action_center(i)
		var filled := held.values().has(i) or i == 0
		draw_circle(center, BUTTON_RADIUS, UI.ORANGE if filled else base, true, -1, true)
		draw_arc(center, BUTTON_RADIUS - 1, 0, TAU, 36, Color(UI.PAPER, 0.65), 1.5, true)
		var width := UI.DISPLAY.get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(UI.DISPLAY, center + Vector2(-width / 2, 5), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.INK if filled else UI.PAPER)
