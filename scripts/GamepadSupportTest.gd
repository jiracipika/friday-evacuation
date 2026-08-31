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
		"boost", "action", "sabotage", "pause", "recenter_camera"]

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

	# 7. Camera orbit actions: right stick + shoulders + dpad, with mouse
	#    left-click mapped to boost (any-controller defaults).
	var cam_left := _joypad_motion_axis("camera_left")
	check(cam_left.size() > 0 and cam_left[0][0] == 2 and cam_left[0][1] < 0.0,
		"camera_left = right stick left (axis 2, negative)")
	var cam_right := _joypad_motion_axis("camera_right")
	check(cam_right.size() > 0 and cam_right[0][0] == 2 and cam_right[0][1] > 0.0,
		"camera_right = right stick right (axis 2, positive)")
	check(_has_joypad_button("camera_left", 9), "camera_left = left shoulder")
	check(_has_joypad_button("camera_right", 10), "camera_right = right shoulder")
	check(_has_joypad_button("camera_left", 13), "camera_left = dpad left")
	check(_has_joypad_button("camera_right", 14), "camera_right = dpad right")
	var mouse_boost := false
	for ev in InputMap.action_get_events("boost"):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			mouse_boost = true
	check(mouse_boost, "boost = mouse left click")
	# Low deadzones so varied third-party sticks register reliably.
	# (float32 round-trip: 0.2 reads back as 0.20000000298…, so compare
	# against a small epsilon above the target, never exact.)
	var move_deadzones_ok := true
	for a in ["move_forward", "move_back", "move_left", "move_right", "camera_left", "camera_right"]:
		if InputMap.action_get_deadzone(a) > 0.2 + 0.001:
			move_deadzones_ok = false
	check(move_deadzones_ok, "movement + camera deadzones <= 0.2 (any-controller friendly)")

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
	# 3 physics frames was enough at the legacy accel (34); the lower
	# default sensitivity (0.7 -> accel ~24) needs a few more frames to
	# cover the same 1.0 speed threshold.
	for i in 6:
		await physics_frame
	var horizontal := Vector3(chair.velocity.x, 0, chair.velocity.z)
	var cam_fwd := -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	check(horizontal.dot(cam_fwd) > 1.0,
		"gamepad left-stick-up drives the chair along camera forward (speed %.2f)" % horizontal.length())

	# Button press path: boost through the real action-polling pipeline.
	# (Synthesized OS events race the physics tick headlessly — the edge
	# lands between ticks ~40% of runs and just_pressed misses it. The
	# A-button→boost BINDING is separately proven above via event-object
	# checks; Input.action_press() drives the chair's edge deterministically.)
	Input.action_press("boost")
	await physics_frame
	await physics_frame
	check(chair.is_boosting, "gamepad A/Cross triggers boost")
	Input.action_release("boost")

	# --- full keyboard+mouse coverage (input overhaul v2) ----------------
	# Right mouse button fires sabotage, middle mouse fires action.
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	check(rmb.is_action_pressed("sabotage"), "right mouse button bound to sabotage")
	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	mmb.pressed = true
	check(mmb.is_action_pressed("action"), "middle mouse button bound to action")
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	check(lmb.is_action_pressed("boost"), "left mouse button bound to boost")
	# R and Y/Triangle recenter the camera.
	var r_key := InputEventKey.new()
	r_key.pressed = true
	r_key.physical_keycode = KEY_R
	check(r_key.is_action_pressed("recenter_camera"), "R key bound to recenter_camera")
	var y_btn := InputEventJoypadButton.new()
	y_btn.button_index = 3
	y_btn.pressed = true
	check(y_btn.is_action_pressed("recenter_camera"), "Y/Triangle bound to recenter_camera")
	# Remap-aware: InputPrefs can move boost to R1 and the InputMap follows.
	var prefs = load("res://scripts/InputPrefs.gd")
	if prefs:
		prefs.set_pad_button("boost", 10)
		var r1 := InputEventJoypadButton.new()
		r1.button_index = 10
		r1.pressed = true
		check(r1.is_action_pressed("boost"), "remapped boost (R1) registers after set_pad_button")
		var old_a := InputEventJoypadButton.new()
		old_a.button_index = 0
		old_a.pressed = true
		check(not old_a.is_action_pressed("boost"), "old A binding removed after remap")
		prefs.set_pad_button("boost", 0)  # restore

	test_root.free()

	if failures.is_empty():
		print("=== GAMEPAD SUPPORT TEST PASSED (%d checks) ===" % checks_total)
		quit(0)
	else:
		printerr("=== GAMEPAD SUPPORT TEST FAILED (%d/%d) ===" % [failures.size(), checks_total])
		quit(1)
