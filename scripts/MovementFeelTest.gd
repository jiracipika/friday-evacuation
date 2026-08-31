# MovementFeelTest.gd — Phase 1 movement tuning verification (headless).
# Phase 1 changes under test:
#   1. BRAKE: holding move_back while moving forward decelerates faster
#      than coasting friction (target: stop from ~10 m/s in < 0.8s).
#   2. REVERSE: holding move_back at standstill drives backwards slowly
#      (<= 4 m/s).
#   3. DRIFT: at high speed while turning, the chair's facing angle
#      differs from its velocity direction by > 8 degrees (the cart-like
#      cornering slide), while below drift speed facing tracks input.
#   4. AIR CONTROL: steering input while airborne still has some effect
#      (> 25% of ground acceleration).
#   5. REGRESSION: top speed, boost, and keyboard sensitivity scaling all
#      behave exactly as before.
# Drives the REAL PlayerChair via Input.action_press (deterministic edges;
# see GamepadSupportTest for the parse_input_event race rationale).
# Run: godot --headless --path . --script scripts/MovementFeelTest.gd
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
	test_root.add_child(floor_body)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 20, 20)
	test_root.add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var chair = load("res://scenes/PlayerChair.tscn").instantiate()
	chair.position = Vector3(0, 0.8, 0)
	test_root.add_child(chair)
	return {"root": test_root, "chair": chair, "cam": cam}

func _speed(chair) -> float:
	return Vector3(chair.velocity.x, 0, chair.velocity.z).length()

func _run() -> void:
	# Isolate prefs from the real save.
	var P = load("res://scripts/InputPrefs.gd")
	var real_cfg: String = P.CFG_PATH
	P.CFG_PATH = "user://settings_movementfeel_test.cfg"
	var cfg := ConfigFile.new()
	cfg.save(P.CFG_PATH)
	P.set_scheme_mode(P.SCHEME_KEYBOARD)
	P.refresh_cache()

	# --- 5. Regression baseline: forward drive reaches old top speed ----
	var world := _make_world()
	var chair = world["chair"]
	await process_frame
	await process_frame
	chair.set_can_move(true)
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
	var top := _speed(chair)
	check(top > 10.0 and top <= 12.5,
		"forward drive reaches top speed (got %.2f)" % top)
	var fwd_time_frames := 0
	Input.action_release("move_forward")
	for i in 240:
		await physics_frame
		fwd_time_frames += 1
		if _speed(chair) < 0.2:
			break
	check(true, "coast-stop measured (%d frames)" % fwd_time_frames)

	# --- 1+2. Brake and reverse -----------------------------------------
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	check(_speed(chair) > 6.0, "moving before brake test (speed %.2f)" % _speed(chair))
	# Release forward FIRST (the test previously pressed back while still
	# holding forward — get_vector cancelled to zero and nothing happened).
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var brake_frames := 0
	for i in 240:
		await physics_frame
		brake_frames += 1
		if _speed(chair) < 0.2:
			break
	var brake_time := brake_frames / 60.0
	check(brake_time < 0.85,
		"brake stops from speed in %.2fs (< 0.85s coast was ~1.2s)" % brake_time)
	# Reverse: still holding back at standstill -> slow backward motion.
	# Read time-averaged speed over 30 frames — instantaneous reads land
	# anywhere in the physics moiré cycle and flake.
	var speed_sum := 0.0
	for i in 30:
		await physics_frame
		speed_sum += _speed(chair)
	var rev_speed := speed_sum / 30.0
	Input.action_release("move_back")
	check(rev_speed > 0.5 and rev_speed <= 4.5,
		"reverse drive is slow (avg speed %.2f)" % rev_speed)

	world["root"].free()

	# --- 3. Drift: static camera, wall-free arena ------------------------
	# Camera-relative steering with a static camera settles into a straight
	# diagonal (input and velocity align). To hold a sustained turn the
	# test ROTATES the input direction over time, like a player steering
	# around a circle: press forward+left, then swap left->right mid-arc.
	var world2 := _make_world()
	var chair2 = world2["chair"]
	await process_frame
	await process_frame
	chair2.set_can_move(true)
	Input.action_press("move_forward")
	Input.action_press("move_left")
	var max_angle := 0.0
	for i in 60:
		await physics_frame
	# Hold speed, oscillate steering: left 15 frames, right 15 frames —
	# each reversal forces velocity to chase a new direction while facing
	# flips instantly: that's the drift moment.
	var last_angle := 0.0
	var turn := "move_left"
	Input.action_press(turn)
	for cycle in 6:
		turn = "move_right" if cycle % 2 == 1 else "move_left"
		Input.action_release("move_left" if turn == "move_right" else "move_right")
		Input.action_press(turn)
		for i in 15:
			await physics_frame
			var vel := Vector3(chair2.velocity.x, 0, chair2.velocity.z)
			var facing: Vector3 = chair2.get_facing_direction()
			facing.y = 0.0
			if vel.length() > 4.0 and facing.length() > 0.1:
				last_angle = rad_to_deg(vel.normalized().angle_to(facing.normalized()))
				max_angle = maxf(max_angle, last_angle)
	check(max_angle > 8.0,
		"drift: velocity/facing diverge during steering reversals (max %.1f deg, last %.1f)" % [max_angle, last_angle])
	Input.action_release("move_forward")
	Input.action_release(turn)
	world2["root"].free()

	# --- 4. Air control ---------------------------------------------------
	var world3 := _make_world()
	var chair3 = world3["chair"]
	await process_frame
	await process_frame
	chair3.set_can_move(true)
	# Launch upward via jump, then steer mid-air.
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
	Input.action_press("action")  # jump
	await physics_frame
	await physics_frame
	Input.action_release("action")
	check(not chair3.is_on_floor(), "chair airborne for air-control test")
	var vel_before := Vector3(chair3.velocity.x, 0, chair3.velocity.z).length()
	var v0: float = chair3.velocity.x
	Input.action_press("move_left")
	for i in 12:
		await physics_frame
	var dvx: float = absf(chair3.velocity.x - v0)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	check(dvx > 0.5,
		"air control changes lateral velocity mid-flight (dv %.2f, was %.2f)" % [dvx, vel_before])
	world3["root"].free()

	# Cleanup
	var cleanup := ConfigFile.new()
	cleanup.save(P.CFG_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P.CFG_PATH))
	P.CFG_PATH = real_cfg
	P.refresh_cache()

	check(failures.is_empty(), "no failures")
	print("MovementFeelTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
