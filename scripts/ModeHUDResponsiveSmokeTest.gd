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
	var hud_script = load("res://scripts/ModeHUD.gd")
	check(hud_script != null, "shared mode HUD script loads")
	if hud_script == null:
		_report()
		return

	root.size = Vector2i(390, 844)
	var hud := CanvasLayer.new()
	hud.set_script(hud_script)
	root.add_child(hud)
	await process_frame
	hud.configure("SHOP & SEEK", "SHOPPER ROUND — GRAB YOUR LIST", 90.0)
	await process_frame

	var panel := hud.get("panel") as PanelContainer
	var visible := root.get_visible_rect()
	var rect := panel.get_global_rect()
	check(rect.position.x >= 0.0 and rect.end.x <= visible.size.x, "HUD panel stays within a 390px viewport")
	check(rect.position.x == 12.0, "HUD keeps its touch-safe side inset")

	var timer := hud.get("timer_label") as Label
	var progress := hud.get("progress_bar") as ProgressBar
	hud.update_state(17.0, 0.8, "LIST 4/5  •  CAUGHT 1/3", Color("ffcf55"))
	check(timer.text == "TIME  0:17" and timer.get_theme_color("font_color") == Color("ff7070"), "low-time warning is coral and readable")
	var fill := progress.get_theme_stylebox("fill") as StyleBoxFlat
	check(fill.bg_color == Color("ff7070"), "progress bar joins the low-time warning")
	hud.update_state(45.0, 0.5, "SHOPPING", Color("ffcf55"))
	check(timer.get_theme_color("font_color") != Color("ff7070") and fill.bg_color != Color("ff7070"), "timer styling resets outside the warning window")

	if failures.is_empty():
		print("ModeHUDResponsiveSmokeTest: %d/%d checks passed" % [checks, checks])
		quit(0)
	else:
		printerr("ModeHUDResponsiveSmokeTest: %d/%d checks failed — %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)

func _report() -> void:
	if failures.is_empty():
		print("ModeHUDResponsiveSmokeTest: %d/%d checks passed" % [checks, checks])
		quit(0)
	else:
		printerr("ModeHUDResponsiveSmokeTest: %d/%d checks failed — %s" % [failures.size(), checks, ", ".join(failures)])
		quit(1)
