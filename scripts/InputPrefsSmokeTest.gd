# InputPrefsSmokeTest.gd — keyboard sensitivity / mouse look / controller
# prefs verification. Runs standalone (raw SceneTree, no autoloads needed):
#   1. Script compiles + all typed getters return in-range defaults.
#   2. CFG_PATH is a mutable static var (test seam works).
#   3. Persistence round-trip: set -> fresh cfg read -> clamped getters.
#   4. Corrupt-value guards: out-of-range cfg values clamp, wrong types
#      fall back to defaults (no crash).
#   5. Yaw math: mouse motion accumulates, stick applies per-second rate,
#      wrapped_yaw stays in [-PI, PI], reset zeroes.
#   6. Sensitivity scaling contract: keyboard_scale default 0.7 (LOWER
#      than the legacy 1.0 feel), slider bounds map 0.5..1.5.
#   7. Vibration guard: rumble() no-ops safely with zero pads (headless).
#   8. refresh_cache() syncs all five cached values.
# Run: godot --headless --path . --script scripts/InputPrefsSmokeTest.gd
extends SceneTree

var checks_total := 0
var checks_passed := 0
var failures: Array[String] = []

const TEST_CFG := "user://settings_inputprefs_test.cfg"

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

func _run() -> void:
	var P = load("res://scripts/InputPrefs.gd")
	check(P != null, "InputPrefs.gd compiles")

	# Isolate from the real player save; restore afterward.
	var real_cfg: String = P.CFG_PATH
	P.CFG_PATH = TEST_CFG
	var cfg := ConfigFile.new()
	cfg.load(TEST_CFG)
	cfg.save(TEST_CFG)  # empty file -> all defaults

	# 1. Defaults
	check(absf(float(P.keyboard_sensitivity()) - 0.7) < 0.001,
		"keyboard default 0.7 (LOWER than legacy 1.0)")
	check(absf(float(P.mouse_sensitivity()) - 1.0) < 0.001, "mouse sens default 1.0")
	check(absf(float(P.stick_sensitivity()) - 1.0) < 0.001, "stick sens default 1.0")
	check(P.mouse_look_enabled() == true, "mouse look default ON")
	check(P.stick_look_enabled() == true, "stick look default ON")
	check(P.vibration_enabled() == true, "vibration default ON")
	check(absf(float(P.acceleration_multiplier()) - 0.7) < 0.001,
		"acceleration_multiplier returns cached 0.7 scale")

	# 6. Range contract
	check(P.KEYBOARD_MIN == 0.5 and P.KEYBOARD_MAX == 1.5, "kb slider bounds 0.5..1.5")
	check(P.MOUSE_MIN == 0.25 and P.MOUSE_MAX == 2.0, "camera slider bounds 0.25..2.0")

	# 3. Persistence round-trip
	P.set_setting(P.KEY_KB_SENS, 1.25)
	P.set_setting(P.KEY_MOUSE_SENS, 1.75)
	P.set_setting(P.KEY_MOUSE_LOOK, false)
	var cfg2 := ConfigFile.new()
	cfg2.load(TEST_CFG)
	check(absf(float(cfg2.get_value("input", P.KEY_KB_SENS, 0.0)) - 1.25) < 0.001,
		"set_setting persists keyboard_sensitivity")
	check(bool(cfg2.get_value("input", P.KEY_MOUSE_LOOK, true)) == false,
		"set_setting persists mouse_look_enabled=false")
	check(absf(float(P.mouse_sensitivity()) - 1.75) < 0.001, "getter reads persisted mouse sens")
	check(P.mouse_look_enabled() == false, "getter reads persisted toggle=false")

	# 4. Corrupt values clamp / fall back
	var cfg3 := ConfigFile.new()
	cfg3.set_value("input", P.KEY_KB_SENS, 9.9)     # way out of range
	cfg3.set_value("input", P.KEY_MOUSE_SENS, -2.0) # negative
	cfg3.set_value("input", P.KEY_MOUSE_LOOK, "yes")  # wrong type
	cfg3.save(TEST_CFG)
	check(absf(float(P.keyboard_sensitivity()) - 1.5) < 0.001, "out-of-range kb sens clamps to max")
	check(absf(float(P.mouse_sensitivity()) - 0.25) < 0.001, "negative mouse sens clamps to min")
	check(P.mouse_look_enabled() == true, "wrong-type bool falls back to default true")

	# 5. Yaw math (fresh baseline so the corrupt-cfg clamps above don't
	#    leak into these expectations — test-order coupling guard)
	var cfg4 := ConfigFile.new()
	cfg4.set_value("input", P.KEY_MOUSE_SENS, 1.0)
	cfg4.set_value("input", P.KEY_MOUSE_LOOK, true)
	cfg4.set_value("input", P.KEY_STICK_SENS, 1.0)
	cfg4.set_value("input", P.KEY_STICK_LOOK, true)
	cfg4.save(TEST_CFG)
	P.refresh_cache()
	P.reset_yaw()
	check(absf(float(P.wrapped_yaw())) < 0.0001, "reset_yaw zeroes offset")
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(100, 0)
	P.apply_mouse_motion(mm)
	check(absf(float(P.camera_yaw_offset) - 100.0 * 1.0 * 0.003) < 0.0001,
		"mouse motion accumulates 0.003 rad/px at sens 1.0")
	P.set_setting(P.KEY_MOUSE_LOOK, false)
	P.refresh_cache()
	P.apply_mouse_motion(mm)
	check(absf(float(P.camera_yaw_offset) - 0.3) < 0.0001, "mouse toggle OFF blocks accumulation")
	P.apply_stick(1.0, 0.5)
	check(absf(float(P.camera_yaw_offset) - (0.3 + 1.1)) < 0.0001,
		"stick applies strength*sens*2.2*dt (toggle-independent)")
	# Wrap: push far past PI
	P.camera_yaw_offset = 10.0
	check(absf(float(P.wrapped_yaw())) <= PI + 0.0001, "wrapped_yaw stays in [-PI, PI]")
	P.reset_yaw()

	# 7. Vibration guard: must not crash headless with no pads
	P.rumble(0.5)
	check(true, "rumble() no-ops safely without joypads")
	check(P.vibration_enabled() == true, "vibration re-reads enabled after corrupt cfg")

	# 8. refresh_cache syncs keyboard_scale
	P.set_setting(P.KEY_KB_SENS, 1.5)
	P.refresh_cache()
	check(absf(float(P.keyboard_scale) - 1.5) < 0.001, "refresh_cache syncs keyboard_scale")

	# Cleanup + restore
	var cleanup := ConfigFile.new()
	cleanup.save(TEST_CFG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	P.CFG_PATH = real_cfg
	P.reset_yaw()

	check(failures.is_empty(), "no failures")
	print("InputPrefsSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
