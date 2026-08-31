# SettingsRoundTripTest.gd — regression net for the Settings-zeroing bug.
#
# BUG HISTORY: opening Settings used to zero graphics quality + audio in
# user://settings.cfg via TWO stacked defects:
#   1. _notification(READY) fired before _ready() built the controls, so
#      persisted values were never restored into the sliders; the first
#      _apply_settings() then saved quality=0 / audio 0.0.
#   2. Even after restoring, _restore_persisted_values() wrote slider
#      values one at a time; each write fired value_changed ->
#      _apply_settings() -> cfg save with the NOT-YET-restored sliders
#      (music/sfx still 0). Master survived only by read order.
# Fix: _restore_persisted_values() runs in _ready() behind a _restoring
# reentrancy guard. This test pins BOTH defects:
#   - instantiate Settings over a known-good cfg, run frames, free it,
#     and assert the cfg is byte-equivalent on every audio/graphics key;
#   - assert the UI controls carry the persisted values after _ready.
# Run: godot --headless --path . --script scripts/SettingsRoundTripTest.gd
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

func _read_cfg() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	var out := {}
	for section in ["graphics", "audio", "accessibility", "input"]:
		for key in ["quality", "master", "music", "sfx", "screen_shake",
				"keyboard_sensitivity", "mouse_sensitivity", "control_scheme"]:
			if cfg.has_section_key(section, key):
				out["%s/%s" % [section, key]] = cfg.get_value(section, key)
	return out

func _run() -> void:
	var cfg_path := "user://settings.cfg"
	var real := ConfigFile.new()
	real.load(cfg_path)

	# Known-good baseline (the shipped defaults).
	real.set_value("graphics", "quality", 1)
	real.set_value("audio", "master", 1.0)
	real.set_value("audio", "music", 0.5)
	real.set_value("audio", "sfx", 0.8)
	real.set_value("accessibility", "screen_shake", true)
	real.set_value("input", "keyboard_sensitivity", 0.55)
	real.set_value("input", "mouse_sensitivity", 0.8)
	real.set_value("input", "control_scheme", "auto")
	real.save(cfg_path)
	var before := _read_cfg()
	check(before["audio/music"] != null and float(before["audio/music"]) == 0.5,
		"baseline cfg written (music=0.5)")

	# Mount Settings exactly like Main.gd does and let it run frames —
	# this is the exact sequence that used to zero the cfg.
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var settings = load("res://scripts/Settings.gd").new()
	main.add_child(settings)
	for i in 30:
		await process_frame

	# 1. UI controls carry the persisted values after restore.
	check(settings.quality_option.selected == 1, "quality dropdown restored to 1 (MEDIUM)")
	check(absf(float(settings.master_slider.value) - 100.0) < 0.01, "master slider restored to 100")
	check(absf(float(settings.music_slider.value) - 50.0) < 0.01, "music slider restored to 50")
	check(absf(float(settings.sfx_slider.value) - 80.0) < 0.01, "sfx slider restored to 80")

	# 2. Close the panel (the real user flow) and re-check the file.
	settings._close()
	await process_frame
	await process_frame
	var after := _read_cfg()
	var unchanged := true
	for key in before:
		if before[key] != after.get(key):
			unchanged = false
			printerr("  cfg drift at %s: %s -> %s" % [key, before[key], after.get(key)])
	check(unchanged, "opening + closing Settings leaves every cfg key unchanged")

	# 3. A real user change still persists (the guard must not block saves).
	var settings2 = load("res://scripts/Settings.gd").new()
	main.add_child(settings2)
	await process_frame
	await process_frame
	settings2.music_slider.value = 70.0  # user drags the slider
	await process_frame
	await process_frame
	var cfg3 := ConfigFile.new()
	cfg3.load(cfg_path)
	check(absf(float(cfg3.get_value("audio", "music", 0.0)) - 0.7) < 0.001,
		"real slider change still persists (music=0.7)")
	check(absf(float(cfg3.get_value("audio", "sfx", 0.0)) - 0.8) < 0.001,
		"unrelated sfx value untouched by the music change")
	settings2._close()
	await process_frame

	# Restore the real player's cfg (put back what we found).
	for section in real.get_sections():
		for key in real.get_section_keys(section):
			var original: Variant = real.get_value(section, key)
			if section == "audio" and key == "music":
				original = 0.5  # we deliberately changed it above
			cfg3.set_value(section, key, original)
	cfg3.save(cfg_path)

	main.free()
	check(failures.is_empty(), "no failures")
	print("SettingsRoundTripTest: %d/%d checks passed" % [checks_passed, checks_total])
	quit(0 if failures.is_empty() else 1)
