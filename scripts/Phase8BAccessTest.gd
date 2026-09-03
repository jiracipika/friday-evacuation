# Phase8BAccessTest.gd — verifies the Phase 8B accessibility slice:
#   1. SabotageTrap shape cues: label + glyph billboard on every trap type,
#      and the four glyph silhouettes are pairwise DISTINCT (the whole point
#      of shape cues — banana and spill are both yellow).
#   2. Game-speed round trip: setting -> Accessibility.get_time_scale() ->
#      Engine.time_scale, corrupt-value snapping, reset, and the --test-mode
#      guard (ladder runs must never apply a real 0.75x save).
#   3. Dead-wiring detector: every mode script calls apply/reset and Settings
#      live-applies (this repo has shipped dead wiring before).
# Run: godot --headless --path . --script scripts/Phase8BAccessTest.gd
extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] " + label)
	else:
		failures.append(label)
		printerr("[FAIL] " + label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# This suite must exercise the REAL apply path even under --test-mode.
	var a11y = load("res://scripts/Accessibility.gd")
	a11y.TEST_MODE = false

	# Isolate the cfg so we never touch the real player save.
	var dir := DirAccess.open("user://")
	if dir.file_exists("settings_test_phase8b.cfg"):
		dir.remove("settings_test_phase8b.cfg")
	a11y.CFG_PATH = "user://settings_test_phase8b.cfg"

	# --- 1. trap shape cues ------------------------------------------------
	await _trap_cue_checks()

	# --- 2. game-speed round trip ------------------------------------------
	check(absf(a11y.get_time_scale() - 1.0) < 0.001, "time scale defaults 1.0 on fresh cfg")
	a11y.apply_time_scale()
	check(absf(Engine.time_scale - 1.0) < 0.001, "apply() with default drives Engine.time_scale=1.0")

	a11y.set_setting(a11y.KEY_TIME_SCALE, 0.75)
	check(absf(a11y.get_time_scale() - 0.75) < 0.001, "setting persists 0.75")
	a11y.apply_time_scale()
	check(absf(Engine.time_scale - 0.75) < 0.001, "ROUND TRIP: setting 0.75 -> Engine.time_scale 0.75")

	a11y.set_setting(a11y.KEY_TIME_SCALE, 9.9)
	var snapped: float = a11y.get_time_scale()
	check(snapped in a11y.TIME_SCALE_OPTIONS, "corrupt 9.9 snaps to supported option (got %s)" % snapped)
	a11y.apply_time_scale()
	check(Engine.time_scale in a11y.TIME_SCALE_OPTIONS, "apply() of corrupt value lands on a supported option")

	a11y.reset_time_scale()
	check(absf(Engine.time_scale - 1.0) < 0.001, "reset() restores neutral 1.0")

	# --- test-mode guard ----------------------------------------------------
	a11y.TEST_MODE = true
	a11y.set_setting(a11y.KEY_TIME_SCALE, 1.25)
	a11y.apply_time_scale()
	check(absf(Engine.time_scale - 1.0) < 0.001, "TEST_MODE guard: apply() is a no-op under --test-mode")
	a11y.TEST_MODE = false

	# --- 3. dead-wiring detector -------------------------------------------
	for mode_script in ["Evacuation", "Hauled", "ShopSeek", "PizzaColony"]:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % mode_script)
		check("apply_time_scale" in src, "%s calls apply_time_scale (wired, not dead)" % mode_script)
		check("reset_time_scale" in src, "%s calls reset_time_scale on teardown" % mode_script)
	var settings_src := FileAccess.get_file_as_string("res://scripts/Settings.gd")
	check("apply_time_scale" in settings_src, "Settings live-applies game speed")

	# --- cleanup -------------------------------------------------------------
	a11y.reset_time_scale()
	dir.remove("settings_test_phase8b.cfg")
	print("")
	if failures.is_empty():
		print("=== PHASE 8B ACCESS TEST PASSED (%d checks) ===" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("[FAILED] " + f)
		print("=== PHASE 8B ACCESS TEST FAILED (%d/%d) ===" % [failures.size(), checks])
		quit(1)

func _trap_cue_checks() -> void:
	var trap_scene = load("res://scenes/objects/SabotageTrap.tscn")
	check(trap_scene != null, "SabotageTrap scene loads")
	if trap_scene == null:
		return
	var a11y = load("res://scripts/Accessibility.gd")
	var expected := {
		"water": "WATER",
		"banana": "BANANA PEEL",
		"stapler": "STAPLES",
		"spill": "SLIPPERY SPILL",
	}
	# Signature = 1024-bit glyph mask per type; cues are only colorblind-useful
	# if every pair of silhouettes differs.
	var signatures := {}
	for trap_type in expected.keys():
		var trap = trap_scene.instantiate()
		trap._set_forced_type(trap_type)
		root.add_child(trap)
		trap.position = Vector3(1000, 0, 1000)  # off in the boonies, no physics contact
		await process_frame
		await process_frame

		var label: Label3D = null
		var sprite: Sprite3D = null
		for child in trap.get_children():
			if child is Label3D and label == null:
				label = child
			elif child is Sprite3D and sprite == null:
				sprite = child
		check(label != null, "%s trap has name label" % trap_type)
		check(label != null and label.text == expected[trap_type],
			"%s label reads '%s'" % [trap_type, expected[trap_type]])
		check(sprite != null and sprite.texture != null, "%s trap has glyph billboard" % trap_type)
		if sprite and sprite.texture:
			var img: Image = sprite.texture.get_image()
			check(img.get_width() == 32 and img.get_height() == 32,
				"%s glyph is 32x32" % trap_type)
			# Mask from the RENDERED texture alpha (black-box: what the
			# player actually sees must differ, not just the predicates).
			var bits := PackedByteArray()
			bits.resize(128)
			for y in 32:
				for x in 32:
					if img.get_pixel(x, y).a > 0.5:
						bits.set(y * 4 + x / 8, bits[y * 4 + x / 8] | (1 << (x % 8)))
			signatures[trap_type] = bits
		trap.queue_free()
		await process_frame

	# Pairwise distinctness — the actual colorblind requirement.
	var types := signatures.keys()
	for i in types.size():
		for j in range(i + 1, types.size()):
			var a: PackedByteArray = signatures[types[i]]
			var b: PackedByteArray = signatures[types[j]]
			var distinct := false
			for k in a.size():
				if a[k] != b[k]:
					distinct = true
					break
			check(distinct, "%s glyph shape differs from %s (not color-only)" % [types[i], types[j]])
