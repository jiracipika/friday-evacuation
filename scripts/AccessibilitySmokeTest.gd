# AccessibilitySmokeTest.gd — verifies the Phase 8B accessibility slice:
#   1. Accessibility settings persist + defaults
#   2. SubtitleOverlay caption show/replace/cleanup lifecycle
#   3. Time scale clamps to supported options and reads 1.0 default
#   4. Captions no-op when subtitles are disabled
# Frame-driven state machine using REAL elapsed time (headless fps varies).
extends SceneTree

var checks: int = 0
var failures: int = 0
var state: int = 0
var wait_time: float = 0.0
var overlay: Control
var test_root: Control

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
			_run_static_checks()
			state = 1
			wait_time = 0.1
		1:
			_mount_overlay()
			state = 2
			wait_time = 0.1
		2:
			_overlay_checks_phase_1()
			state = 3
			wait_time = 1.0  # caption duration 0.3s + margin
		3:
			_overlay_checks_phase_2()
			state = 4
			wait_time = 0.2
		4:
			_overlay_checks_cleanup()
			state = 5
			wait_time = 0.3
		5:
			_finish()
			return true
	return false

func _run_static_checks() -> void:
	var Accessibility = load("res://scripts/Accessibility.gd")

	# Fresh test config so we never clobber the real player save
	var dir := DirAccess.open("user://")
	if dir.file_exists("settings_test_a11y.cfg"):
		dir.remove("settings_test_a11y.cfg")
	Accessibility.CFG_PATH = "user://settings_test_a11y.cfg"

	check(Accessibility.screen_shake_enabled() == true, "screen shake defaults on")
	check(Accessibility.flash_effects_enabled() == true, "flash effects defaults on")
	check(Accessibility.reduced_motion_enabled() == false, "reduced motion defaults off")
	check(Accessibility.high_contrast_enabled() == false, "high contrast defaults off")
	check(Accessibility.captions_enabled() == false, "subtitles default off")
	check(absf(Accessibility.get_time_scale() - 1.0) < 0.001, "time scale defaults 1.0 (no network)")

	Accessibility.set_setting(Accessibility.KEY_SUBTITLES, true)
	Accessibility.set_setting(Accessibility.KEY_TIME_SCALE, 0.75)
	check(Accessibility.captions_enabled() == true, "subtitles persist after save")
	check(absf(Accessibility.get_time_scale() - 0.75) < 0.001, "time scale persists 0.75")

	Accessibility.set_setting(Accessibility.KEY_TIME_SCALE, 9.9)
	var snapped: float = Accessibility.get_time_scale()
	check(snapped in Accessibility.TIME_SCALE_OPTIONS, "corrupt time scale snaps to supported option (got %s)" % snapped)

func _mount_overlay() -> void:
	var SubtitleOverlay = load("res://scripts/SubtitleOverlay.gd")
	var Accessibility = load("res://scripts/Accessibility.gd")

	test_root = Control.new()
	test_root.name = "A11yTestRoot"
	get_root().add_child(test_root)

	overlay = Control.new()
	overlay.set_script(SubtitleOverlay)
	test_root.add_child(overlay)

	check(overlay.is_in_group("caption_overlays"), "overlay joins caption_overlays group")
	check(overlay.caption_panel.visible == false, "caption hidden before first show")

	# Disabled -> no caption
	Accessibility.set_setting(Accessibility.KEY_SUBTITLES, false)
	Accessibility.caption("SHOULD NOT APPEAR", 0.3)
	check(overlay.caption_panel.visible == false, "no caption when subtitles disabled")

func _overlay_checks_phase_1() -> void:
	var Accessibility = load("res://scripts/Accessibility.gd")

	# Enabled -> caption appears
	Accessibility.set_setting(Accessibility.KEY_SUBTITLES, true)
	Accessibility.caption("BOOST!", 0.3)
	check(overlay.caption_panel.visible == true, "caption appears when enabled")
	check(overlay.caption_label.text == "BOOST!", "caption text matches")

	# Replacement: second caption wins
	Accessibility.caption("ELEVATOR", 0.3)
	check(overlay.caption_label.text == "ELEVATOR", "new caption replaces in-flight caption")

func _overlay_checks_phase_2() -> void:
	check(overlay.caption_panel.visible == false, "caption hides after duration")

func _overlay_checks_cleanup() -> void:
	overlay.queue_free()

func _finish() -> void:
	var Accessibility = load("res://scripts/Accessibility.gd")

	# Group cleanup after free
	var remaining := test_root.get_tree().get_nodes_in_group("caption_overlays").filter(func(n): return n != null and is_instance_valid(n))
	check(remaining.size() == 0, "overlay leaves group on free")

	# Remove test config
	var dir := DirAccess.open("user://")
	if dir.file_exists("settings_test_a11y.cfg"):
		dir.remove("settings_test_a11y.cfg")

	if failures == 0:
		print("=== ACCESSIBILITY SMOKE TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		print("=== ACCESSIBILITY SMOKE TEST FAILED (%d/%d) ===" % [failures, checks])
		quit(1)
