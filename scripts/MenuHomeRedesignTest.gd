# MenuHomeRedesignTest.gd — S-B1 "After Hours" home column test.
#
# Boot Main.tscn at 1280x720, wait 2 frames, assert the redesigned home
# column (FINAL-SPEC.md section 3): GET OUT title, evacuation-notice kicker,
# departures ticker with 3 gate rows, EVACUATE CTA focused, version label,
# and a column minimum that still fits the ink field.
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
		print("[FAIL] %s" % label)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	var main = packed.instantiate()
	root.get_window().content_scale_size = Vector2i(1280, 720)
	root.add_child(main)
	for i in 4:
		await process_frame

	var title: Label = main.title_label
	check(title != null and title.text == "GET OUT", "title is GET OUT")

	var kicker: Label = main.kicker_label
	check(kicker != null and kicker.text.contains("EVACUATION NOTICE"),
		"kicker reads OFFICE EVACUATION NOTICE")

	var ticker: PanelContainer = main.nav_column.get_node_or_null("DeparturesTicker")
	var has_rows := false
	if ticker != null:
		var gates := 0
		for row in ticker.find_children("GateRow*", "HBoxContainer", true, false):
			gates += 1
		has_rows = gates == 3
	check(ticker != null and has_rows, "DeparturesTicker exists with 3 gate rows")

	var sub: Label = main.subtitle_label
	check(sub != null and sub.text.begins_with("4:59"), "subtitle is the 4:59 clock")

	var play: Button = main.play_button
	check(play != null and play.text == "EVACUATE", "EVACUATE button present")
	var focused := play != null and play.has_focus()
	check(focused, "EVACUATE button holds first focus")

	var version: Label = main.nav_column.get_node_or_null("VersionLabel")
	check(version != null and version.text.contains("v0.9"), "version label present")

	var col_min: Vector2 = main.nav_column.get_combined_minimum_size()
	check(col_min.x <= 470.0, "home column min width <= 470 (%.0f)" % col_min.x)

	main.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== MENU HOME REDESIGN TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== MENU HOME REDESIGN TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)
