extends SceneTree

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("[FAIL] %s" % label)

func _run() -> void:
	var results_script = load("res://scripts/ModeResults.gd")
	check(results_script != null, "shared results script loads")
	if results_script == null:
		_report()
		return

	var host := Node.new()
	root.add_child(host)
	var overlay: CanvasLayer = results_script.mount(host, "TEST COMPLETE", "3 ITEMS  •  1 CATCH", true)
	await process_frame
	await process_frame

	var title := overlay.get("title_label") as Label
	var detail := overlay.get("detail_label") as Label
	var rematch := overlay.get("rematch_button") as Button
	var menu := overlay.get("menu_button") as Button
	check(title != null and title.text == "TEST COMPLETE", "result headline is shown")
	check(detail != null and detail.text == "3 ITEMS  •  1 CATCH", "result detail is shown")
	check(rematch != null and rematch.text == "PLAY AGAIN", "replay action is available")
	check(menu != null and menu.text == "MAIN MENU", "menu action is available")
	if overlay.get("panel") is PanelContainer:
		var rect := (overlay.get("panel") as PanelContainer).get_global_rect()
		var viewport := root.get_visible_rect()
		check(rect.position.x >= 0.0 and rect.end.x <= viewport.size.x, "results panel stays within viewport width")
	else:
		check(false, "results panel exists")

	# P3 contract: D5 accent rules on the shared mode results.
	var UIT = load("res://scripts/UITheme.gd")
	check(title != null
		and title.get_theme_color("font_color").is_equal_approx(UIT.color(UIT.LIME)),
		"win headline uses the LIME token")
	check(rematch != null and rematch.custom_minimum_size.y >= 52.0,
		"replay action is a 52px primary target")
	check(menu != null and menu.custom_minimum_size.y >= 52.0,
		"menu action is a 52px target")
	if menu != null:
		var msb: StyleBoxFlat = menu.get_theme_stylebox("normal")
		# apply_secondary draws the accent at 28% alpha on "normal".
		check(msb != null and msb.border_color.is_equal_approx(Color(UIT.color(UIT.VIOLET), 0.28)),
			"menu action carries the VIOLET secondary accent")
	# Entrance motion settles (real-time wait; headless frames are ~instant).
	await create_timer(0.7).timeout
	if overlay.get("panel") is PanelContainer:
		var pnl := (overlay.get("panel") as PanelContainer)
		check(is_equal_approx(pnl.modulate.a, 1.0) and pnl.scale.is_equal_approx(Vector2.ONE),
			"entrance animation settles to identity")

	if failures.is_empty():
		print("ModeResultsSmokeTest: %d/%d checks passed" % [checks, checks])
		quit(0)
	else:
		printerr("ModeResultsSmokeTest: %d/%d checks failed — %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)

func _report() -> void:
	if failures.is_empty():
		print("ModeResultsSmokeTest: %d/%d checks passed" % [checks, checks])
		quit(0)
	else:
		printerr("ModeResultsSmokeTest: %d/%d checks failed — %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)
