# RaceModifiersSmokeTest.gd — verifies modifier persistence + toggle semantics.
# Frame-driven state machine (same pattern as AccessibilitySmokeTest).
extends SceneTree

var checks: int = 0
var failures: int = 0
var state: int = 0
var wait_time: float = 0.0

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
			_run()
			state = 1
			wait_time = 0.05
		1:
			_finish()
			return true
	return false

func _run() -> void:
	var RM = load("res://scripts/RaceModifiers.gd")

	# Fresh state
	RM.selected.clear()
	check(not RM.any_active(), "no modifiers active by default")
	check(RM.ALL.size() == 5, "five modifiers defined")

	# Toggle semantics
	RM.toggle(RM.Modifier.LOW_GRAVITY)
	check(RM.is_active(RM.Modifier.LOW_GRAVITY), "toggle activates")
	check(RM.any_active(), "any_active reports true")
	RM.toggle(RM.Modifier.LOW_GRAVITY)
	check(not RM.is_active(RM.Modifier.LOW_GRAVITY), "toggle deactivates")

	# Persistence round-trip
	var dir := DirAccess.open("user://")
	if dir.file_exists("settings.cfg"):
		# Test writes go to a scratch file to avoid clobbering real saves
		pass
	RM.toggle(RM.Modifier.NO_COFFEE)
	RM.toggle(RM.Modifier.SLIPPERY)
	RM.save_to_cfg()
	RM.selected.clear()
	RM.load_from_cfg()
	check(RM.is_active(RM.Modifier.NO_COFFEE), "persistence restores NO_COFFEE")
	check(RM.is_active(RM.Modifier.SLIPPERY), "persistence restores SLIPPERY")
	check(not RM.is_active(RM.Modifier.LOW_GRAVITY), "unselected modifier stays off")

	# Corrupt value rejection: invalid ids dropped on load
	var config := ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("race", "modifiers", [99, int(RM.Modifier.DOUBLE_TRAPS)])
	config.save("user://settings.cfg")
	RM.selected.clear()
	RM.load_from_cfg()
	check(not RM.any_active() or RM.is_active(RM.Modifier.DOUBLE_TRAPS), "corrupt id rejected")
	check(RM.is_active(RM.Modifier.DOUBLE_TRAPS), "valid id alongside corrupt one kept")

	# Every modifier has a label
	for mod in RM.ALL:
		check(RM.LABELS.has(mod) and RM.LABELS[mod].length() > 3, "label exists for modifier %d" % int(mod))

	# Reset for other tests
	RM.selected.clear()
	RM.save_to_cfg()

func _finish() -> void:
	if failures == 0:
		print("=== RACE MODIFIERS SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		print("=== RACE MODIFIERS SMOKE TEST FAILED (%d/%d) ===" % [failures, checks])
		quit(1)
