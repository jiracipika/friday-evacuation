extends SceneTree
## Phase 7A headless test: with FE_TOUCH=1, verify MobileControls mounts in
## every mode, the virtual joystick drives the local PlayerChair, all three
## action buttons fire, boost lockout blocks re-fire during cooldown, and
## left-half touches only drive the joystick. Runs with the real autoloads
## (--path .) like MultiplayerSyncHost.

var checks: int = 0
var failures: int = 0

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] ", label)
	else:
		print("[FAIL] ", label)
		failures += 1

func _touch_at(pos: Vector2, index: int) -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.index = index
	t.position = pos
	return t

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("=== TOUCH CONTROLS SMOKE TEST (FE_TOUCH=1) ===")
	OS.set_environment("FE_TOUCH", "1")
	await _test_mount_and_joystick()
	await _test_secondary_modes_mount()
	if failures == 0:
		print("TOUCH_SMOKE_PASS")
	else:
		print("TOUCH_SMOKE_FAIL (%d/%d)" % [failures, checks])
	quit(failures)

func _test_mount_and_joystick() -> void:
	var mode_scene = load("res://scenes/Evacuation.tscn")
	check(mode_scene != null, "Evacuation scene loads")
	if mode_scene == null:
		return
	var ev: Node = mode_scene.instantiate()
	root.add_child(ev)
	await process_frame
	await process_frame
	var mc: Node = ev.get_node_or_null("MobileControls")
	check(mc != null, "MobileControls mounted in Evacuation")
	if mc == null:
		ev.queue_free()
		await process_frame
		return
	check(mc.touch_enabled == true, "FE_TOUCH=1 enables touch controls")

	# WEB TOUCH: preference modes persist and resolve sanely.
	var P2 = load("res://scripts/InputPrefs.gd")
	P2.set_touch_mode(P2.TOUCH_OFF)
	check(P2.touch_mode() == P2.TOUCH_OFF, "touch mode OFF persists")
	check(P2.touch_enabled() == true,
		"FE_TOUCH=1 env overrides OFF (test env precedence)")
	P2.set_touch_mode(P2.TOUCH_ON)
	check(P2.touch_enabled() == true, "ON pins touch on")
	P2.set_touch_mode(P2.TOUCH_AUTO)
	check(P2.touch_mode() == P2.TOUCH_AUTO, "touch mode AUTO persists")
	P2.set_touch_mode("bogus")
	check(P2.touch_mode() == P2.TOUCH_AUTO, "invalid touch mode rejected")
	var chair = mc.local_chair_ref
	check(chair != null and is_instance_valid(chair), "local chair bound for boost cooldown reflection")

	# The real mode starts with a 3-second countdown; enable movement here so
	# this input test measures chair response, not countdown gating.
	chair.set_can_move(true)
	var before: Vector3 = chair.global_position
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(200.0, 500.0)
	mc._input(touch)
	check(mc.active_touch == 0, "joystick captures left-half touch")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(330.0, 500.0)
	check(mc.move_vector == Vector2.ZERO, "pre-drag move_vector zero")
	mc._input(drag)
	check(absf(mc.move_vector.x - 1.0) < 0.01, "drag right => move_vector.x ~ +1")
	check(chair.has_method("set_mobile_input") and chair.mobile_input.x > 0.9, "move_changed wired: chair.mobile_input follows joystick")
	for i in 60:
		await process_frame
	var moved: float = chair.global_position.distance_to(before)
	check(moved > 0.3, "chair physically moved via touch input (%.2f units)" % moved)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.index = 0
	release.position = Vector2(330.0, 500.0)
	mc._input(release)
	check(mc.move_vector == Vector2.ZERO, "release zeroes move_vector")
	check(chair.mobile_input == Vector2.ZERO, "chair mobile_input cleared on release")

	# --- Action buttons at exact layout centers ---
	var size: Vector2 = mc.size
	var actions_seen: Array = []
	mc.action_pressed.connect(func(a: StringName): actions_seen.append(a))
	mc._input(_touch_at(size + Vector2(-130.0, -150.0), 1))
	check(actions_seen.has(&"boost"), "BOOST button fires boost")
	if chair.boost_cd_timer > 0.0:
		actions_seen.clear()
		mc._input(_touch_at(size + Vector2(-130.0, -150.0), 2))
		check(not actions_seen.has(&"boost"), "BOOST ignored while on cooldown")
		check(mc.boost_locked == true, "boost_locked mirrors chair cooldown")
	else:
		check(false, "boost consumed -> cooldown active (boost fired?)")
	mc._input(_touch_at(size + Vector2(-260.0, -100.0), 3))
	check(actions_seen.has(&"action"), "JUMP button fires action")
	mc._input(_touch_at(size + Vector2(-130.0, -290.0), 4))
	check(actions_seen.has(&"sabotage"), "TRAP button fires sabotage")
	actions_seen.clear()
	mc._input(_touch_at(Vector2(100.0, 100.0), 5))
	check(actions_seen.is_empty(), "left-half touch only drives joystick (no button)")

	ev.queue_free()
	await process_frame

func _test_secondary_modes_mount() -> void:
	for scene_path in ["res://scenes/Hauled.tscn", "res://scenes/ShopSeek.tscn", "res://scenes/PizzaColony.tscn"]:
		var scene = load(scene_path)
		if scene == null:
			check(false, "%s loads" % scene_path)
			continue
		var node: Node = scene.instantiate()
		root.add_child(node)
		await process_frame
		await process_frame
		var mc: Node = node.get_node_or_null("MobileControls")
		check(mc != null, "%s mounts MobileControls" % scene_path)
		node.queue_free()
		await process_frame
