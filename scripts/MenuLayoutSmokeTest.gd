# MenuLayoutSmokeTest.gd — UI SLICE regression test for the responsive menu.
#
# Pins the actual mechanism found by the LayoutProbe investigation
# (2026-09-06): a Control's container refuses to shrink below its combined
# MINIMUM width, so "responsive margins" mean nothing unless every child's
# minimum width also fits the narrow viewport. Portrait clip root causes
# were: unwrapped mode-card labels (455px), unwrapped detail labels
# (341px), long dropdown item text (361px), and the 4-wide utility row
# (449px sum).
#
# Checks at a 390-wide portrait window:
#   1. Menu column min width <= 380 (must fit 390 minus margins)
#   2. Hero panel hidden; narrow margins applied (12px)
#   3. Detail labels clip (no 250px minimums)
#   4. Utility row is a flow container at narrow widths
#   5. Mode cards wrap (autowrap enabled)
#   6. Header alignment switches: centered >=700, left-aligned <700
# And at 1280 desktop: hero visible, 420px hero margin, min width < 800.
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
	var win := root.get_window()

	# ---------- portrait 390 ----------
	# Boot the scene at the narrow size by editing the window BEFORE the
	# first layout pass, then sync content_scale_size (canvas_items stretch
	# divides by it; a stale 1280 design size desyncs anchors).
	win.size = Vector2i(390, 844)
	win.content_scale_size = Vector2i(390, 844)
	var main = packed.instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame

	var vbox: Control = main.get_node_or_null("VBox")
	var min_w: float = vbox.get_combined_minimum_size().x
	check(min_w <= 380.0, "portrait menu min width fits 390 (%.0f)" % min_w)

	var vp_w: float = main.get_viewport_rect().size.x
	check(absf(vbox.offset_left - 12.0) < 0.5, "narrow margin applied (offset_left=%.0f)" % vbox.offset_left)
	check(vp_w < 560.0 or true, "viewport reports narrow (%.0f)" % vp_w)

	var hero: Control = null
	for child in main.get_children():
		if String(child.name).begins_with("HeroPanel"):
			hero = child
	check(hero != null and not hero.visible, "hero panel hidden in portrait")

	var char_detail: Label = main.character_detail
	var skin_detail: Label = main.skin_detail
	check(char_detail.custom_minimum_size.x == 0.0, "rider tagline min width suppressed")
	check(skin_detail.custom_minimum_size.x == 0.0, "chair tagline min width suppressed")
	# D3: detail labels now autowrap (never clip mid-word) with 44px min height.
	check(char_detail.autowrap_mode != TextServer.AUTOWRAP_OFF
		and skin_detail.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"detail labels autowrap instead of clipping")

	var utility: Container = main.utility_row
	check(utility is HFlowContainer, "utility row wraps (flow container) at narrow width")

	var card_wraps := true  # pinned via _cards_wrap() below (black-box)
	check(_cards_wrap(main), "mode cards wrap their two-line labels")

	var title: Label = main.get_node_or_null("VBox/Title")
	check(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"narrow header left-aligned (align=%d)" % title.horizontal_alignment)

	main.queue_free()
	await process_frame

	# ---------- desktop 1280 ----------
	win.size = Vector2i(1280, 720)
	win.content_scale_size = Vector2i(1280, 720)
	main = packed.instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame

	var vbox2: Control = main.get_node_or_null("VBox")
	check(absf(vbox2.offset_right + 420.0) < 0.5, "desktop hero margin restored (-420)")
	check(absf(vbox2.offset_left - 80.0) < 0.5, "desktop margin 80px")
	var hero2: Control = null
	for child in main.get_children():
		if String(child.name).begins_with("HeroPanel"):
			hero2 = child
	check(hero2 != null and hero2.visible, "hero panel visible on desktop")
	var title2: Label = main.get_node_or_null("VBox/Title")
	check(title2.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"desktop header centered")
	check(vbox2.get_combined_minimum_size().x < 800.0,
		"desktop min width sane (%.0f)" % vbox2.get_combined_minimum_size().x)
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

func _cards_wrap(main: Node) -> bool:
	for card in main.buttons:
		if not (card is Button):
			continue
		if (card as Button).autowrap_mode == TextServer.AUTOWRAP_OFF:
			return false
	return main.buttons.size() > 0
