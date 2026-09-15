# MenuLayoutSmokeTest.gd — UI SLICE regression test for the responsive menu.
#
# Rewritten for the superseding departure-board design (Main.gd + Main.tscn
# + code-built subviews), keeping the original intent of the LayoutProbe
# findings (2026-09-06): containers refuse to shrink below their combined
# MINIMUM width, so every column/content minimum must fit the narrowest
# supported window and the hero must only exist where there is room.
#
# Checks at 390x844 portrait:
#   1. Home nav column min width <= viewport minus margins (no overflow).
#   2. Hero panel hidden; full-width ink field minus margins.
#   3. Detail labels (rider/chair taglines) wrap, min width suppressed.
#   4. OptionButtons do not force min width from their longest item.
#   5. Mode cards in the OTHER MODES subview wrap/trim (no 455px rows).
#   6. All visible action controls >= 48px; essential text >= 14px.
# And at 1280x720 desktop: hero visible inside the right field, nav column
# inside the 40% ink field, min width sane.
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

func _set_size(win: Window, size: Vector2i) -> void:
	win.size = size
	win.content_scale_size = size

func _run() -> void:
	var packed := load("res://scenes/Main.tscn")
	var win := root.get_window()

	# ---------- portrait 390x844 ----------
	# Boot the scene at the narrow size by editing the window BEFORE the
	# first layout pass, then sync content_scale_size (canvas_items stretch
	# divides by it; a stale 1280 design size desyncs anchors).
	_set_size(win, Vector2i(390, 844))
	var main = packed.instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame

	var vp_w: float = main.get_viewport_rect().size.x
	var col: Control = main.nav_column
	var col_min_w: float = col.get_combined_minimum_size().x
	check(col_min_w <= vp_w - 24.0,
		"portrait menu min width fits 390 minus margins (%.0f vs %.0f)" % [col_min_w, vp_w - 24.0])
	check(col.size.x <= vp_w + 1.0, "portrait column does not overflow viewport (%.0f)" % col.size.x)
	check(col.global_position.x >= 14.0,
		"narrow margin applied (x=%.0f)" % col.global_position.x)

	# Full-width ink field minus margins under 960 (not a 56% rule).
	var field_w: float = main.nav_field.size.x
	check(absf(field_w - (vp_w - 32.0)) < 2.0,
		"ink field is full viewport minus margins (w=%.0f)" % field_w)

	# Hero panel hidden in portrait.
	check(main.hero_panel != null and not main.hero_panel.visible,
		"hero panel hidden in portrait")

	# Detail labels: suppressed min width + autowrap (stacked under the row).
	# The selectors are lazy-built — open CUSTOMIZE RIDE first.
	main.customize_button.pressed.emit()
	await process_frame
	var char_detail: Label = main.character_detail
	var skin_detail: Label = main.skin_detail
	check(char_detail != null and char_detail.custom_minimum_size.x == 0.0,
		"rider tagline min width suppressed")
	check(skin_detail != null and skin_detail.custom_minimum_size.x == 0.0,
		"chair tagline min width suppressed")
	check(char_detail != null and char_detail.autowrap_mode != TextServer.AUTOWRAP_OFF
		and skin_detail != null and skin_detail.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"detail labels autowrap instead of clipping")
	check(main.character_select.fit_to_longest_item == false
		and main.skin_select.fit_to_longest_item == false,
		"OptionButtons do not size to longest item")
	var row_min: float = main.character_row.get_combined_minimum_size().x
	check(row_min <= vp_w + 1.0, "rider selector row fits portrait (%.0f)" % row_min)

	# OTHER MODES subview at portrait: opaque ink field full-width minus
	# margins, mode cards trimmed (no 455px minimum rows), footer reachable.
	main.other_modes_button.pressed.emit()
	await process_frame
	check(main.modes_subview.visible, "modes subview opens in portrait")
	var sub_field: ColorRect = main.modes_subview.get_node("Field")
	check(absf(sub_field.size.x - (vp_w - 32.0)) < 2.0,
		"modes subview field full-width minus margins (%.0f)" % sub_field.size.x)
	check(main.modes_subview.size.y <= 844.0 + 1.0 and sub_field.size.y <= 844.0 + 1.0,
		"modes subview inside viewport height at portrait")
	var cards_wrap := true
	for card in main.buttons:
		var b := card as Button
		if b == null:
			continue
		if b.get_combined_minimum_size().x > vp_w + 1.0:
			cards_wrap = false
			print("    wide card min: %s %.0f" % [b.text, b.get_combined_minimum_size().x])
	check(cards_wrap and main.buttons.size() > 0, "mode cards fit portrait width")
	var play_sel: Button = main.modes_subview.get_meta("play_button")
	check(play_sel != null and play_sel.custom_minimum_size.y >= 48.0,
		"PLAY SELECTED stays a >=48px target in portrait")
	var scroll_sub: ScrollContainer = main.modes_subview.get_node("Field/Content/ScrollSub")
	check(scroll_sub != null and scroll_sub.get_v_scroll_bar() != null,
		"modes subview scrolls (content reachable)")

	# Action targets + essential text at portrait.
	var targets_ok := true
	var text_ok := true
	for node in main.find_children("*", "Button", true, false):
		var b := node as Button
		if b == null or not b.is_visible_in_tree():
			continue
		if b.custom_minimum_size.y < 48.0:
			targets_ok = false
			print("    tiny target: %s h=%.0f" % [b.text, b.custom_minimum_size.y])
		if b.get_theme_font_size("font_size") < 14:
			text_ok = false
	check(targets_ok, "all action targets >= 48px in portrait")
	check(text_ok, "essential button text >= 14px in portrait")

	main.queue_free()
	await process_frame

	# ---------- desktop 1280x720 ----------
	_set_size(win, Vector2i(1280, 720))
	main = packed.instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame

	var field_w2: float = main.nav_field.size.x
	check(absf(field_w2 - 512.0) < 2.0, "desktop ink field is 512px (w=%.0f)" % field_w2)
	var col2: Control = main.nav_column
	var col2_min: float = col2.get_combined_minimum_size().x
	check(col2_min <= 512.0 - 48.0,
		"desktop nav column min fits the ink field (%.0f)" % col2_min)
	check(main.hero_panel != null and main.hero_panel.visible,
		"hero panel visible on desktop")
	var hero_rect := Rect2(main.hero_panel.global_position, main.hero_panel.size)
	check(hero_rect.position.x >= field_w2 and hero_rect.end.x <= 1280.0 + 1.0
		and hero_rect.position.y >= 0.0 and hero_rect.end.y <= 720.0 + 1.0,
		"hero panel inside right field + viewport (%s)" % hero_rect)
	check(main.get_viewport_rect().size == Vector2(1280, 720),
		"desktop viewport reports 1280x720")

	main.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== MENU LAYOUT SMOKE TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== MENU LAYOUT SMOKE TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)
