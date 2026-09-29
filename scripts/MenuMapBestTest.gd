# MenuMapBestTest.gd — per-layout PB readout under the menu map picker.
#
# The map picker is where you choose the course, so it now shows your best
# on THAT course (results + the in-race chip cover the other moments).
# Pins: label exists, ORANGE formatted time when a layout best exists,
# muted "NO FINISH YET" when the sentinel stands, and refresh follows the
# selected option. Stats state is injected IN-MEMORY (direct var set, no
# save call) — the user's real save.cfg is never written.
extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("[PASS] %s" % label)
	else:
		failures.append(label)
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	var win := root.get_window()
	win.size = Vector2i(1280, 720)
	win.content_scale_size = Vector2i(1280, 720)
	var stats = root.get_node("/root/StatsManager")
	var original_layouts: Dictionary = stats.best_time_by_layout.duplicate()

	# Inject layout bests in memory (no save_stats call -> no disk write).
	stats.best_time_by_layout = {"open_plan": 42.5, "executive": 61.0}

	var main = packed.instantiate()
	main._block_navigation = true
	root.add_child(main)
	for i in 8:
		await process_frame

	# The MAP picker lives in the LAZY OFFICE SETUP subview — open it first.
	main.office_button.pressed.emit()
	await process_frame
	check(main.office_subview != null and main.office_subview.visible,
		"office subview opens (lazy builder runs)")
	var label: Label = main.find_child("MapBestLabel", true, false)
	check(label != null, "MapBestLabel exists under the map picker")
	if label == null:
		quit(1)
		return

	# OPEN PLAN (index 0) has the injected 42.5s best.
	main.layout_option.select(0)
	main._refresh_map_best_label()
	check(label.text == "YOUR BEST ON THIS MAP: 42.5s",
		"open_plan shows the injected PB (%s)" % label.text)
	check(label.get_theme_color("font_color").is_equal_approx(
		Color("ff9a1a")), "PB readout is orange")

	# EXECUTIVE (index 2) has 61.0s.
	main.layout_option.select(2)
	main._refresh_map_best_label()
	check(label.text == "YOUR BEST ON THIS MAP: 61.0s",
		"executive shows its own PB, not open_plan's (%s)" % label.text)

	# CUBICLE MAZE (index 1) has no finish -> muted sentinel line.
	main.layout_option.select(1)
	main._refresh_map_best_label()
	check(label.text == "NO FINISH YET ON THIS MAP",
		"no-finish maps show the sentinel (%s)" % label.text)
	check(label.get_theme_color("font_color") != Color("ff9a1a"),
		"sentinel readout is not orange")

	# Restore the injected autoload state (in-memory; nothing was saved).
	stats.best_time_by_layout = original_layouts

	main._close_subview()
	main.queue_free()
	await process_frame

	if failures.is_empty() and checks > 0:
		print("=== MENU MAP BEST TEST PASS (%d/%d) ===" % [checks, checks])
		quit(0)
	else:
		print("=== MENU MAP BEST TEST FAILED (%d/%d) ===" % [checks - failures.size(), checks])
		for f in failures:
			print("  - %s" % f)
		quit(1)
