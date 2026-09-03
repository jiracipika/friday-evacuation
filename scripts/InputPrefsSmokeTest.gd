# InputPrefsSmokeTest.gd — input prefs verification (sensitivity, scheme
# memory, pad remap, invert, migration). Runs standalone (raw SceneTree,
# no autoloads needed):
#   1. Script compiles + all typed getters return in-range defaults.
#   2. CFG_PATH is a mutable static var (test seam works).
#   3. Persistence round-trip: set -> fresh cfg read -> clamped getters.
#   4. Corrupt-value guards: out-of-range cfg values clamp, wrong types
#      fall back to defaults (no crash).
#   5. Yaw math: mouse motion accumulates, stick applies per-second rate,
#      wrapped_yaw stays in [-PI, PI], reset zeroes; invert flips signs.
#   6. Sensitivity contract: keyboard default 0.35 (lowered THREE times from
#      the legacy 1.0/0.7/0.55 feel), bounds 0.15..1.5; camera default 0.8.
#   7. Vibration guard: rumble() no-ops safely with zero pads (headless).
#   8. refresh_cache() syncs all cached values.
#   9. Control scheme: default AUTO, device tracking flips which_scheme,
#      persisted across cache refresh; manual pin overrides.
#  10. Pad remap: set_pad_button rewrites InputMap live; pad_button_map
#      round-trips through the cfg and clamps garbage.
#  11. Migration: old-default sens values (0.7/1.0/1.0) migrate to the
#      new defaults once; personalized values are untouched.
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
	P.refresh_cache()

	# 1. Defaults (v3: lowered a third time)
	check(absf(float(P.keyboard_sensitivity()) - 0.35) < 0.001,
		"keyboard default 0.35 (lowered from 0.55, legacy 1.0)")
	check(absf(float(P.mouse_sensitivity()) - 0.8) < 0.001, "mouse sens default 0.8")
	check(absf(float(P.stick_sensitivity()) - 0.8) < 0.001, "stick sens default 0.8")
	check(P.mouse_look_enabled() == true, "mouse look default ON")
	check(P.stick_look_enabled() == true, "stick look default ON")
	check(P.vibration_enabled() == true, "vibration default ON")
	check(absf(float(P.acceleration_multiplier()) - 0.35) < 0.001,
		"acceleration_multiplier returns cached 0.35 scale (keyboard)")

	# 6. Range contract
	check(P.KEYBOARD_MIN == 0.15 and P.KEYBOARD_MAX == 1.5, "kb slider bounds 0.15..1.5")
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
	#    leak into these expectations — test-order coupling guard).
	# KEY_MIGRATED + KEY_MIGRATED_V3 are pinned so refresh_cache's
	# (correct) one-time migrations of old defaults don't rewrite these
	# explicit values.
	var cfg4 := ConfigFile.new()
	cfg4.set_value("input", P.KEY_MIGRATED, true)
	cfg4.set_value("input", P.KEY_MIGRATED_V3, true)
	cfg4.set_value("input", P.KEY_MOUSE_SENS, 1.0)
	cfg4.set_value("input", P.KEY_MOUSE_LOOK, true)
	cfg4.set_value("input", P.KEY_STICK_SENS, 1.0)
	cfg4.set_value("input", P.KEY_STICK_LOOK, true)
	cfg4.set_value("input", P.KEY_INVERT, false)
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

	# 5b. Invert flips both mouse and stick camera direction.
	P.set_invert_camera_x(true)
	P.set_setting(P.KEY_MOUSE_LOOK, true)
	P.set_setting(P.KEY_STICK_LOOK, true)
	P.refresh_cache()
	check(P.camera_x_sign() == -1.0, "camera_x_sign -1 when inverted")
	var before_yaw: float = P.camera_yaw_offset
	P.apply_mouse_motion(mm)
	check(P.camera_yaw_offset < before_yaw, "inverted mouse pans the other way")
	before_yaw = P.camera_yaw_offset
	P.apply_stick(1.0, 0.5)
	check(P.camera_yaw_offset < before_yaw, "inverted stick pans the other way")
	P.set_invert_camera_x(false)
	P.refresh_cache()
	check(P.camera_x_sign() == 1.0, "camera_x_sign back to +1")
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

	# 9. Control scheme: AUTO follows last device, manual pins
	var cfg5 := ConfigFile.new()
	cfg5.save(TEST_CFG)  # wipe section
	P.refresh_cache()
	check(P.scheme_mode() == P.SCHEME_AUTO, "default scheme mode AUTO")
	check(P.which_scheme() == P.SCHEME_KEYBOARD, "fresh save assumes keyboard device")
	check(P.is_controller_active() == false, "keyboard scheme active by default")
	# Simulate touching a controller (stick past deadzone threshold).
	var stick := InputEventJoypadMotion.new()
	stick.axis = 0
	stick.axis_value = 0.8
	P.note_device(stick)
	check(P.which_scheme() == P.SCHEME_CONTROLLER, "stick input flips AUTO to controller")
	check(P.is_controller_active() == true, "controller scheme active after stick")
	check(absf(float(P.acceleration_multiplier()) - 1.0) < 0.0001,
		"controller scheme runs FULL acceleration (stick = finesse)")
	# Persisted across a cache refresh (simulated restart).
	P.refresh_cache()
	check(P.which_scheme() == P.SCHEME_CONTROLLER, "last device persists through refresh_cache")
	# Sub-deadzone jitter must NOT flip it back (drift filter).
	var drift := InputEventJoypadMotion.new()
	drift.axis = 1
	drift.axis_value = 0.1
	P.note_device(drift)
	check(P.which_scheme() == P.SCHEME_CONTROLLER, "sub-threshold stick drift ignored")
	# Keyboard key flips back to keyboard under AUTO.
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_W
	P.note_device(key)
	check(P.which_scheme() == P.SCHEME_KEYBOARD, "key press flips AUTO back to keyboard")
	check(absf(float(P.acceleration_multiplier()) - 0.35) < 0.001,
		"keyboard scheme restores the 0.35 scale")
	# Manual pin: controller stays controller even on key input.
	P.set_scheme_mode(P.SCHEME_CONTROLLER)
	P.note_device(key)
	check(P.which_scheme() == P.SCHEME_CONTROLLER, "manual CONTROLLER pin ignores key input")
	P.set_scheme_mode(P.SCHEME_AUTO)

	# 10. Pad remap: live InputMap rewrite + persistence + garbage clamp
	check(P.pad_button_for("boost") == 0, "default boost pad button A/Cross")
	check(P.pad_button_for("recenter_camera") == 3, "default recenter pad button Y/Triangle")
	check(P.pad_button_name("boost") == "A / CROSS", "pad_button_name friendly label")
	P.set_pad_button("boost", 10)
	check(P.pad_button_for("boost") == 10, "remap persists through cfg")
	var boost_events := InputMap.action_get_events("boost")
	var found10 := false
	var found0 := false
	for ev in boost_events:
		if ev is InputEventJoypadButton:
			if ev.button_index == 10:
				found10 = true
			if ev.button_index == 0:
				found0 = true
	check(found10 and not found0, "InputMap boost action rewritten live (10 in, 0 out)")
	check(InputMap.has_action("recenter_camera"), "recenter_camera action registered")
	var rc_key := false
	for ev in InputMap.action_get_events("recenter_camera"):
		if ev is InputEventKey and ev.physical_keycode == KEY_R:
			rc_key = true
	check(rc_key, "recenter_camera has R keyboard binding")
	# Garbage map (wrong types) falls back to defaults, clamped range.
	var cfg6 := ConfigFile.new()
	cfg6.set_value("input", P.KEY_PAD_MAP, {"boost": "banana", "action": 999})
	cfg6.save(TEST_CFG)
	var garbage_map: Dictionary = P.pad_button_map()
	check(int(garbage_map["boost"]) == 0, "garbage pad map value falls back to default")
	check(int(garbage_map["action"]) == 30, "out-of-range pad index clamps to 30")
	# Restore defaults for cleanliness.
	var cfg7 := ConfigFile.new()
	cfg7.save(TEST_CFG)
	P.refresh_cache()
	P.apply_pad_map_to_input_map()
	check(P.pad_button_for("boost") == 0, "pad map restored to defaults")

	# 11. Migration: old defaults move once, personalized values stay.
	var cfg8 := ConfigFile.new()
	cfg8.set_value("input", P.KEY_KB_SENS, 0.7)      # old default
	cfg8.set_value("input", P.KEY_MOUSE_SENS, 1.0)   # old default
	cfg8.set_value("input", P.KEY_STICK_SENS, 1.0)   # old default
	cfg8.save(TEST_CFG)
	P.migrate_defaults()
	var cfg9 := ConfigFile.new()
	cfg9.load(TEST_CFG)
	check(absf(float(cfg9.get_value("input", P.KEY_KB_SENS, 0.0)) - 0.35) < 0.001,
		"old kb default 0.7 migrates through to 0.35 (v2 then v3)")
	check(absf(float(cfg9.get_value("input", P.KEY_MOUSE_SENS, 0.0)) - 0.8) < 0.001,
		"old mouse default 1.0 migrates to 0.8")
	check(absf(float(cfg9.get_value("input", P.KEY_STICK_SENS, 0.0)) - 0.8) < 0.001,
		"old stick default 1.0 migrates to 0.8")
	# Personalized values survive migration untouched.
	var cfg10 := ConfigFile.new()
	cfg10.set_value("input", P.KEY_KB_SENS, 1.2)     # player's own value
	cfg10.set_value("input", P.KEY_MIGRATED, false)
	cfg10.save(TEST_CFG)
	P.migrate_defaults()
	var cfg11 := ConfigFile.new()
	cfg11.load(TEST_CFG)
	check(absf(float(cfg11.get_value("input", P.KEY_KB_SENS, 0.0)) - 1.2) < 0.001,
		"personalized kb sens NOT migrated")
	check(bool(cfg11.get_value("input", P.KEY_MIGRATED, false)) == true,
		"migration flag set after first run")

	# --- 12. Stick response curves (Phase 3) ------------------------------
	check(P.stick_curve() == P.CURVE_EXPO, "default stick curve is expo")
	check(absf(P.apply_stick_curve(1.0) - 1.0) < 0.001, "curve(1.0) == 1.0 (full throw)")
	check(absf(P.apply_stick_curve(0.0)) < 0.001, "curve(0.0) == 0.0")
	check(P.apply_stick_curve(0.5) < 0.5,
		"expo curve pulls center down (0.5 -> %.2f)" % P.apply_stick_curve(0.5))
	P.set_stick_curve(P.CURVE_PRECISION)
	check(P.apply_stick_curve(0.5) > 0.5,
		"precision curve pushes center up (0.5 -> %.2f)" % P.apply_stick_curve(0.5))
	P.set_stick_curve(P.CURVE_LINEAR)
	check(absf(P.apply_stick_curve(0.5) - 0.5) < 0.001, "linear curve passes through")
	P.set_stick_curve("bogus")  # invalid -> silently keeps linear
	check(P.stick_curve() == P.CURVE_LINEAR, "invalid curve rejected")
	P.set_stick_curve(P.CURVE_EXPO)
	check(P.stick_curve() == P.CURVE_EXPO, "curve persisted after set")

	# --- 13. Rumble vocabulary entry points exist + envelope gate ---------
	# (No pad headless: _vibrate no-ops after pad check — just verify the
	# API surface and that clear_cache resets the gate state.)
	P.rumble_hum(0.5)
	P.rumble_thump(0.8)
	P.rumble_sputter()
	P.rumble_chirp()
	P.rumble(0.7)  # legacy -> thump
	check(true, "rumble vocabulary callable headless (no pad no-op)")
	P.clear_cache()
	check(P._rumble_until_ms == 0 and P._rumble_peak == 0.0,
		"clear_cache resets rumble envelope state")

	# Cleanup + restore
	var cleanup := ConfigFile.new()
	cleanup.save(TEST_CFG)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	P.CFG_PATH = real_cfg
	P.reset_yaw()
	P.set_invert_camera_x(false)
	P.set_scheme_mode(P.SCHEME_AUTO)

	check(failures.is_empty(), "no failures")
	print("InputPrefsSmokeTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
