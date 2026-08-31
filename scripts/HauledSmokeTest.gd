# HauledSmokeTest.gd — Phase 6A physics-delivery vertical-slice test.
# Exercises the actual runtime scene: cargo creation, grab/carry penalties,
# throw release, delivery scoring, and the next-round reset.
extends SceneTree

var checks := 0
var passed := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		passed += 1
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed = load("res://scenes/Hauled.tscn")
	check(packed != null, "Hauled scene resource loads")
	if packed == null:
		_report()
		return
	# PreMatchModal pauses the tree on mount — suppressed for this harness.
	load("res://scripts/PreMatchModal.gd").suppress_next()
	var mode: Node3D = packed.instantiate()
	root.add_child(mode)
	await process_frame
	await process_frame

	check(mode.CARGO_TYPES.size() == 6, "six hostile cargo types configured")
	check(mode.TERRAIN_KINDS.size() == 4, "four terrain gauntlets configured")
	check(mode.round_active, "first delivery round starts active")
	check(mode.cargo != null and is_instance_valid(mode.cargo), "round spawns physical cargo")
	check(mode.player != null and is_instance_valid(mode.player), "round spawns hauler chair")
	check(mode.player.suppress_action_jump, "E is repurposed from jump for grab/throw")
	check(mode.mode_hud != null and is_instance_valid(mode.mode_hud), "mode HUD mounted with timer configuration")

	# Grab at point-blank range applies every carry constraint.
	mode.player.global_position = mode.cargo.global_position
	mode._try_grab_or_throw()
	await process_frame
	check(mode.held_by == mode.player, "E grabs nearby cargo")
	check(mode.cargo.freeze, "carried cargo becomes kinematic")
	check(is_equal_approx(mode.player.carry_slowdown, 0.7), "carrying applies 30 percent movement penalty")
	check(mode.player.boost_locked, "carrying locks boost")

	# Throw returns it to physics and restores chair controls.
	mode._try_grab_or_throw()
	await process_frame
	check(mode.held_by == null, "second E releases carried cargo")
	check(not mode.cargo.freeze, "thrown cargo resumes physics")
	check(is_equal_approx(mode.player.carry_slowdown, 1.0), "throw restores movement speed")
	check(not mode.player.boost_locked, "throw restores boost")

	# Score a delivery directly: validates scoring + transition scheduling.
	mode.cargo.global_position = Vector3(0, 1.2, mode.DELIVERY_Z)
	mode._score_delivery()
	check(mode.delivered_this_round, "delivery marks cargo delivered")
	check(not mode.round_active, "delivery ends current round")
	check(mode.total_score > 0 and mode.round_scores.size() == 1, "delivery awards and records score")
	check(mode._next_round_timer > 0.0, "delivery schedules next round")

	# Direct next-round start avoids a real-time 3 second sleep in the test.
	mode._start_round(1)
	await process_frame
	check(mode.round_active and mode.round_index == 1, "next round resets active match state")
	check(mode.cargo != null and is_instance_valid(mode.cargo), "next round replaces cargo")

	mode.queue_free()
	await process_frame
	_report()

func _report() -> void:
	if failures.is_empty():
		print("=== HAULED SMOKE TEST PASSED (%d checks) ===" % passed)
		quit(0)
	else:
		printerr("=== HAULED SMOKE TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)
