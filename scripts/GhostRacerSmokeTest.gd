# GhostRacerSmokeTest.gd — verifies the ghost pacer course math + lifecycle.
extends SceneTree

var checks: int = 0
var failures: int = 0
var state: int = 0
var wait_time: float = 0.0
var ghost: Node3D

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		failures += 1
		print("[FAIL] %s" % label)

func _process(delta: float) -> bool:
	if wait_time > 0.0:
		wait_time -= delta
		if wait_time > 0.0:
			return false
	match state:
		0:
			_run_setup()
			state = 1
			wait_time = 0.05
		1:
			_run_motion()
			state = 2
			wait_time = 0.8
		2:
			_run_fast_forward()
			state = 3
			wait_time = 0.1
		3:
			_finish()
			return true
	return false

func _run_setup() -> void:
	var ghost_script = load("res://scripts/GhostRacer.gd")
	check(ghost_script != null, "GhostRacer script loads")
	if ghost_script == null:
		return
	ghost = Node3D.new()
	ghost.set_script(ghost_script)
	var course: Array[Vector3] = [
		Vector3(0, 1, 0),
		Vector3(10, 0.5, 8),
		Vector3(0, 19, 14.5),
	]
	ghost.setup(course, "TESTGHOST", 2.0)  # 2s pace for fast test
	get_root().add_child(ghost)
	check(ghost.position.is_equal_approx(Vector3(0, 1, 0)), "ghost starts at first waypoint")

func _run_motion() -> void:
	if ghost == null:
		return
	var p = ghost.get_progress()
	check(p > 0.0 and p < 1.0, "progress strictly between 0 and 1 mid-race")
	check(ghost.elapsed > 0.0, "elapsed accumulates")
	check(not ghost.finished, "not finished before target time")

func _run_fast_forward() -> void:
	if ghost == null:
		return
	# Jump to completion
	ghost.elapsed = ghost.target_time + 1.0
	var finished_fired: Array = []
	ghost.ghost_finished.connect(func(n, t): finished_fired.append([n, t]))
	# _process will see elapsed >= target on next frame; force by manual call
	if ghost.has_method("_process"):
		ghost._process(0.016)
	check(ghost.finished, "ghost marks finished after target time")
	check(finished_fired.size() == 1, "ghost_finished signal fired exactly once")

func _finish() -> void:
	if failures == 0:
		print("=== GHOST RACER SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		print("=== GHOST RACER SMOKE TEST FAILED (%d/%d) ===" % [failures, checks])
		quit(1)
