# GamepadSupportTest.gd — Phase 7D controller input verification.
# Verifies (headless, real project autoloads):
#   1. All 8 gameplay actions exist in the InputMap.
#   2. Every gameplay action has at least one keyboard event.
#   3. Movement actions have joypad MOTION events; action buttons
#      (boost/action/sabotage/pause) have joypad BUTTON events.
#   4. The axis signs are correct: forward=-1 on axis 1 (left Y up),
#      back=+1, left=-1 on axis 0 (left X), right=+1.
#   5. Action ordering: parse InputMap at runtime rather than the file so
#      the test proves what the ENGINE loaded, not the text on disk.
#   6. A synthesized joypad motion through Input.parse_input_event drives
#      the real PlayerChair (move_forward registers as camera-forward).
# Run: godot --headless --path . --script scripts/GamepadSupportTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks_total += 1
	if cond:
		checks_passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _has_keyboard_event(action: String) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return true
	return false

func _joypad_motion_axis(action: String) -> Array:
	var found: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			found.append([ev.axis, ev.axis_value])
	return found

func _has_joypad_button(action: String, button_index: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button_index:
			return true
	return false

func _run() -> void:
	var actions := ["move_forward", "move_back", "move_left", "move_right",
		"boost", "action", "sabotage", "pause"]

	# 1+2. Actions exist with keyboard fallbacks
	for a in actions:
		check(InputMap.has_action(a), "action exists: %s" % a)
	for a in actions:
		check(_has_keyboard_event(a), "keyboard fallback: %s" % a)

	# 3+4. Joypad mappings and signs
	var fwd := _joypad_motion_axis("move_forward")
	check(fwd.size() > 0 and fwd[0][0] == 1 and fwd[0][1] < 0.0,
		"move_forward = left stick up (axis 1, negative)")
	var back := _joypad_motion_axis("move_back")
	check(back.size() > 0 and back[0][0] == 1 and back[0][1] > 0.0,
		"move_back = left stick down (axis 1, positive)")
	var left := _joypad_motion_axis("move_left")
	check(left.size() > 0 and left[0][0] == 0 and left[0][1] < 0.0,
		"move_left = left stick left (axis 0, negative)")
	var right := _joypad_motion_axis("move_right")
	check(right.size() > 0 and right[0][0] == 0 and right[0][1] > 0.0,
		"move_right = left stick right (axis 0, positive)")

	check(_has_joypad_button("boost", 0), "boost = joypad button 0 (A/Cross)")
	check(_has_joypad_button("action", 2), "action = joypad button 2 (X/Square)")
	check(_has_joypad_button("sabotage", 1), "sabotage = joypad button 1 (B/Circle)")
	check(_has_joypad_button("pause", 6), "pause = joypad button 6 (Start)")

	# 6. Synthesized gamepad input drives the real chair
	var test_root := Node3D.new()
	root.add_child(test_root)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 0.2, 30)
	col.shape = shape
	floor_body.add_child(col)
	test_root.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7, 10)
	test_root.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true

	var chair = load("res://scenes/PlayerChair.tscn").instantiate()
	chair.position = Vector3(0, 0.8, 0)
	test_root.add_child(chair)
	await process_frame
	await process_frame

	chair.set_can_move(true)
	var motion := InputEventJoypadMotion.new()
	motion.axis = 1
	motion.axis_value = -1.0  # stick up -> move_forward
	Input.parse_input_event(motion)
	await physics_frame
	await physics_frame
	await physics_frame
	var horizontal := Vector3(chair.velocity.x, 0, chair.velocity.z)
	var cam_fwd := -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	check(horizontal.dot(cam_fwd) > 1.0,
		"gamepad left-stick-up drives the chair along camera forward (speed %.2f)" % horizontal.length())

	# Button press path: boost via joypad button
	var press := InputEventJoypadButton.new()
	press.button_index = 0
	press.pressed = true
	Input.parse_input_event(press)
	await physics_frame
	await physics_frame
	check(chair.is_boosting, "gamepad A/Cross triggers boost")

	test_root.free()

	if failures.is_empty():
		print("=== GAMEPAD SUPPORT TEST PASSED (%d checks) ===" % checks_total)
		quit(0)
	else:
		printerr("=== GAMEPAD SUPPORT TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
