# ModeSelectRedesignTest.gd — S-C "PICK YOUR EXIT" mode select test.
#
# Boot Main.tscn at 1280x720, open the modes subview, assert the F2 redesign
# (FINAL-SPEC.md section 4): shell title, per-card grid (IconGlyph + MetaBox
# with correct 2-line data), hard selected state (ORANGE border + SELECTED
# pill), desc panel (FORM EX-01 stamp + caution chips on EVACUATION), CLOCK
# OUT CTA, and card fit at 390px portrait (min width <= 366).
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

	# ---- shell title --------------------------------------------------------
	main.other_modes_button.pressed.emit()
	await process_frame
	check(main.modes_subview != null and main.modes_subview.visible,
		"modes subview opens")
	var header_label := _find_heading(main.modes_subview.get_node("Field/Content"))
	check(header_label != null and header_label.text == "PICK YOUR EXIT",
		"shell title is PICK YOUR EXIT")

	# ---- cards: grid structure + meta data ---------------------------------
	check(main.buttons.size() == 4, "four mode cards")
	var meta_ok := true
	var glyph_ok := true
	var expected_cat := ["PRIMARY", "VERSUS", "SOCIAL", "CO-OP"]
	var expected_crew := ["1-4 PLAYERS", "TEAMS OF 2+", "1 SEEKER · 3+ HIDERS", "2-4 PLAYERS"]
	for i in range(4):
		var card: Button = main.buttons[i]
		var glyph: Control = card.get_node_or_null("CardRow/IconGlyph")
		var meta: VBoxContainer = card.get_node_or_null("CardRow/MetaBox")
		if glyph == null or meta == null:
			glyph_ok = false
			meta_ok = false
			continue
		var labels: Array[Label] = []
		for child in meta.get_children():
			if child is Label:
				labels.append(child)
		if labels.size() != 2:
			meta_ok = false
			continue
		if labels[0].text != expected_cat[i] or labels[1].text != expected_crew[i]:
			meta_ok = false
		if card.custom_minimum_size.y < 78.0:
			meta_ok = false
	check(glyph_ok, "every card has an IconGlyph control")
	check(meta_ok, "every card has MetaBox with 2 correct labels + min height 78")

	# ---- selected state: ORANGE border + SELECTED pill ---------------------
	main._select_mode(0)
	await process_frame
	var sel_card: Button = main.buttons[0]
	var sel_sb: StyleBoxFlat = sel_card.get_theme_stylebox("normal")
	check(sel_sb != null and sel_sb.border_color.is_equal_approx(Color("ff9a1a"))
		and sel_sb.border_width_left == 2,
		"selected card stylebox has ORANGE 2px border")
	var pill_anchor: Control = sel_card.get_node_or_null("SelectedPillAnchor")
	var pill := pill_anchor.get_node_or_null("SelectedPill") if pill_anchor else null
	check(pill != null and pill.is_visible_in_tree(),
		"selected card shows the SELECTED pill")
	var un_sel: Button = main.buttons[1]
	var unsel_pill: Control = un_sel.get_node_or_null("SelectedPillAnchor/SelectedPill")
	check(unsel_pill != null and not unsel_pill.is_visible_in_tree(),
		"unselected card hides the SELECTED pill")
	var unsel_sb: StyleBoxFlat = un_sel.get_theme_stylebox("normal")
	check(unsel_sb != null and not unsel_sb.border_color.is_equal_approx(Color("ff9a1a")),
		"unselected card does not use the ORANGE border")

	# ---- desc panel: FORM stamp + desc + caution chips ---------------------
	var desc_panel := _find_desc_panel(main.modes_subview.get_node("Field/Content"))
	check(desc_panel != null, "desc panel exists in the subview footer")
	if desc_panel != null:
		var stamp: Label = desc_panel.find_child("FormStamp", true, false)
		check(stamp != null and stamp.text == "FORM EX-01"
			and absf(stamp.rotation_degrees + 4.0) < 0.01,
			"FORM EX-01 stamp present, rotated -4deg")
		var caution: HFlowContainer = desc_panel.find_child("CautionRow", true, false)
		check(caution != null and caution.get_child_count() == 3 and caution.visible,
			"CautionRow has 3 chips, visible on EVACUATION")
		check(main.modes_desc_label.text.contains("5:00 PM sharp")
			and main.modes_desc_label.text.contains("[color=#f2c230][b]"),
			"desc carries the yellow bold 5:00 PM sharp emphasis")
		var play_meta: Button = main.modes_subview.get_meta("play_button")
		check(play_meta.text == "CLOCK OUT", "CTA reads CLOCK OUT")

	# ---- caution chips hide on non-EVACUATION ------------------------------
	main._select_mode(1)
	await process_frame
	var caution2: HFlowContainer = desc_panel.find_child("CautionRow", true, false) if desc_panel else null
	check(caution2 != null and not caution2.visible,
		"CautionRow hidden when a non-EVACUATION mode is selected")

	# ---- 390px portrait fit ------------------------------------------------
	root.get_window().content_scale_size = Vector2i(390, 844)
	await process_frame
	for i in range(4):
		var card2: Button = main.buttons[i]
		check(card2.get_combined_minimum_size().x <= 366.0,
			"card %d min width fits 390px (%.0f)" % [i, card2.get_combined_minimum_size().x])

	main.queue_free()
	await process_frame

	if failures.is_empty() and checks_total > 0:
		print("=== MODE SELECT REDESIGN TEST PASS (%d/%d) ===" % [checks_passed, checks_total])
		quit(0)
	else:
		print("=== MODE SELECT REDESIGN TEST FAILED (%d/%d) ===" % [checks_passed, checks_total])
		for f in failures:
			print("  - %s" % f)
		quit(1)

func _find_heading(content: Control) -> Label:
	var found := content.find_children("*", "Label", true, false)
	for child in found:
		if child.text == "PICK YOUR EXIT":
			return child
	return null

func _find_desc_panel(content: Control) -> Control:
	for child in content.get_children():
		if child.name == "DescPanel":
			return child
	return null
