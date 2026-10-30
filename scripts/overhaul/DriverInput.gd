extends RefCounted
const Command = preload("res://scripts/overhaul/DrivingCommand.gd")
const Prefs = preload("res://scripts/InputPrefs.gd")
var sequence := 0
var touch_move := Vector2.ZERO
var touch_boost := false
var touch_drift := false
var touch_hop := false
var touch_item := false

func read(camera: Camera3D, blocked := false) -> Dictionary:
	sequence += 1
	if blocked:
		return Command.make(Vector2.ZERO, false, false, false, false, sequence)
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Prefs.is_controller_active() and raw.length() > 0:
		raw = raw.normalized() * Prefs.apply_stick_curve(raw.length())
	if touch_move.length() > 0.05:
		raw = touch_move
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0
	right = right.normalized()
	var world := right * raw.x - forward * raw.y
	var cmd := Command.make(Vector2(world.x, world.z), Input.is_action_pressed("boost") or touch_boost, Input.is_action_pressed("brake_drift") or touch_drift, Input.is_action_just_pressed("action") or touch_hop, Input.is_action_just_pressed("sabotage") or touch_item, sequence)
	touch_hop = false
	touch_item = false
	return cmd
