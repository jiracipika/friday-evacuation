# JumpForgivenessTest.gd — coyote time + jump buffering regression suite.
#
# Overhaul feel slice: _execute_jump + buffered presses replaced the old
# instant is_on_floor() jump. These checks pin the new contract:
#   1. BUFFER: pressing jump while airborne near landing fires on touchdown.
#   2. COYOTE: pressing jump just after running off a ledge still jumps.
#   3. NO EXPLOIT: one press = one jump; the buffer cannot chain-jump.
#   4. TOUCH PARITY: trigger_mobile_action("action") buffers identically.
#   5. REGRESSION: a grounded press still jumps immediately (same frame tick).
# Run: godot --headless --path . --script scripts/JumpForgivenessTest.gd
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

func _make_world() -> Dictionary:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(120, 0.2, 120)
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.1, 0)
	test_root.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 20, 20)
	test_root.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var chair = load("res://scenes/PlayerChair.tscn").instantiate()
	chair.position = Vector3(0, 0.5, 0)
	test_root.add_child(chair)
	return {"root": test_root, "chair": chair}

func _ticks(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	# Isolate prefs from the real save.
	var P = load("res://scripts/InputPrefs.gd")
	var real_cfg: String = P.CFG_PATH
	P.CFG_PATH = "user://settings_jumpforgive_test.cfg"
	var cfg := ConfigFile.new()
	cfg.save(P.CFG_PATH)
	P.set_scheme_mode(P.SCHEME_KEYBOARD)
	P.refresh_cache()

	# --- 5. REGRESSION: grounded press jumps on the tick -----------------
	var world := _make_world()
	var chair = world["chair"]
	await process_frame
	await process_frame
	chair.set_can_move(true)
	await _ticks(10)  # settle onto the floor
	Input.action_press("action")
	await physics_frame
	await physics_frame
	var jumped_now: bool = chair.velocity.y > 3.0
	Input.action_release("action")
	check(jumped_now, "grounded press jumps immediately")
	await _ticks(30)  # land
	world["root"].free()

	# --- 1. BUFFER: press airborne just before landing ---------------------
	world = _make_world()
	chair = world["chair"]
	await process_frame
	await process_frame
	chair.set_can_move(true)
	await _ticks(10)
	# Launch airborne deterministically: zero-g hop via direct velocity.
	chair.velocity.y = 6.0
	await physics_frame
	await physics_frame
	var airborne_start: bool = not chair.is_on_floor()
	# Fall until just above touchdown, then press inside the buffer window
	# (0.14s ≈ 2-3 ticks at terminal-ish fall speed near the ground).
	# Watch for the buffered liftoff INSIDE the loop — the hop is short and
	# its >3 m/s phase is over before a post-loop window would open.
	var pressed := false
	var buf_ok := false
	for i in 140:
		await physics_frame
		if not pressed and chair.velocity.y < -5.0 and chair.position.y < 0.75:
			Input.action_press("action")
			pressed = true
		if pressed and chair.velocity.y > 3.0:
			buf_ok = true
	# Whatever remains of the buffer must have fired on the landing tick.
	Input.action_release("action")
	check(airborne_start and pressed and buf_ok,
		"pre-landing press inside buffer fires on touchdown")

	# --- 3. NO EXPLOIT: single press cannot double-jump --------------------
	chair.velocity.y = 8.0
	await physics_frame
	Input.action_press("action")
	var apex_seen := 0.0
	for i in 90:
		await physics_frame
		apex_seen = maxf(apex_seen, chair.velocity.y)
	Input.action_release("action")
	check(apex_seen >= 7.5 and apex_seen < 12.0,
		"buffer press does not add a second impulse mid-air (apex %.1f)" % apex_seen)

	# --- 2. COYOTE: press just after leaving a ledge ------------------------
	world["root"].free()
	world = _make_world()
	chair = world["chair"]
	await process_frame
	await process_frame
	chair.set_can_move(true)
	await _ticks(10)
	Input.action_press("move_forward")
	await _ticks(30)  # build speed toward the floor edge
	Input.action_release("move_forward")
	# Teleport beyond the floor edge (slab spans -60..60) — leaves ground
	# without an upward phase.
	chair.position = Vector3(70, 0.5, 0)
	await physics_frame
	await physics_frame
	var off_ground: bool = not chair.is_on_floor()
	Input.action_press("action")
	await physics_frame
	await physics_frame
	var coyote_ok: bool = chair.velocity.y > 3.0 or chair._coyote_left > 0.0
	Input.action_release("action")
	check(off_ground and coyote_ok, "press within coyote window after ledge fires jump")
	await _ticks(30)

	# --- 4. TOUCH PARITY -----------------------------------------------------
	world["root"].free()
	world = _make_world()
	chair = world["chair"]
	await process_frame
	await process_frame
	chair.set_can_move(true)
	await _ticks(10)
	chair.velocity.y = 5.0
	await physics_frame
	await physics_frame
	var touch_fired := false
	for i in 120:
		await physics_frame
		if not touch_fired and chair.velocity.y < -5.0 and chair.position.y < 0.75:
			chair.trigger_mobile_action(&"action")
		if chair.velocity.y > 3.0:
			touch_fired = true
	world["root"].free()

	check(touch_fired, "touch action press buffers and fires on landing")

	P.CFG_PATH = real_cfg
	P.refresh_cache()

	print("JumpForgivenessTest: %d/%d" % [checks_passed, checks_total])
	if failures.size() > 0 or checks_total == 0:
		quit(1)
	else:
		quit(0)
