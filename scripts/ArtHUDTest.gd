extends SceneTree
var checks: int = 0
var failures: int = 0
func _init() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
func _run() -> void:
	for viewport_size: Vector2i in [Vector2i(1280,720), Vector2i(640,360)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		var hud: CanvasLayer = load("res://scripts/HUD.gd").new()
		root.add_child(hud)
		await process_frame
		await process_frame
		var instrument: PanelContainer = hud.find_child("Instruments", true, false)
		# D2: player state is one panel; "Abilities" is the boost/item
		# sub-stack inside it (name kept addressable per migration contract).
		var abilities: Control = hud.find_child("Abilities", true, false)
		check(instrument != null and abilities != null, "speed/abilities grouped on readable panels at %s" % viewport_size)
		if instrument != null:
			var style: StyleBoxFlat = instrument.get_theme_stylebox("panel")
			check(is_equal_approx(style.bg_color.a, 1.0), "opaque panel isolates text from noisy world")
			var rect: Rect2 = instrument.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= viewport_size.x+1 and rect.position.y >= 0 and rect.end.y <= viewport_size.y+1,
				"HUD panel remains within %s: %s" % [viewport_size,rect])
		hud.set_speed(10.0, 12.0)
		hud.set_timer_text("1:23")
		hud.set_floor(3)
		hud.set_boost(0.0, 1.0, true)
		hud.set_item(&"stapler", 2)
		check(hud.speed_label.text.contains("36") and hud.timer_label.text == "1:23" and hud.floor_label.text.contains("3"), "live speed/timer/floor still update")
		check(hud.boost_label.text.contains("ACTIVE") and hud.item_label.text.contains("2"), "boost/item readouts still update")
		var fill: StyleBoxFlat = hud.boost_bar.get_theme_stylebox("fill")
		check(fill.bg_color.r > fill.bg_color.b, "boost meter uses warm identity, not engine default grey")
		hud.queue_free()
		await process_frame
	print("ArtHUDTest: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
